# app/services/search_client.rb
require "net/http"
require "uri"
require "json"
require "cgi"
require "digest"
# Thin client over Scrape.do's Google Search API plugins (structured JSON, no HTML parsing).
#
#   SearchClient.search(query)         -> [{ title:, url:, snippet: }, ...]   (SERP, 10 credits)
#   SearchClient.ai_mode_answer(query) -> "first 50 words of Google's AI Mode answer" or nil (10 credits)
#
# Both are independent and both are called for a single search (20 credits total); each has
# its own cache so a repeated query doesn't re-charge either one.
#
# Credentials (bin/rails credentials:edit):
#   scrape_do:
#     token: YOUR_SCRAPE_DO_TOKEN
#
# Rails.cache must be a real store (not :null_store); in development run `bin/rails dev:cache`
# once to switch caching on.
class SearchClient
  ENDPOINT          = "https://api.scrape.do/plugin/google/search"
  AI_MODE_ENDPOINT  = "https://api.scrape.do/plugin/google/search/ai-mode"
  RESULT_COUNT      = 4
  SNIPPET_MAX       = 500      # characters kept per SERP snippet
  AI_MODE_WORDS     = 50       # words kept from the AI Mode answer
  CACHE_TTL         = 1.hour   # repeat questions cost nothing
  OPEN_TIMEOUT      = 5        # seconds
  READ_TIMEOUT      = 30       # seconds (Google via proxies is slower than a plain search API)
  LANGUAGE          = "en"     # Google hl parameter
  COUNTRY           = "us"     # Google gl parameter
  MAX_ATTEMPTS      = 2        # the docs say to retry a 502 "request failed"

  class << self
    def enabled?
      token.present?
    end

    # Returns [{ title:, url:, snippet: }, ...]. Returns [] on ANY failure, never raises.
    def search(query)
      return [] unless enabled?

      key = "search_client/serp/#{Digest::SHA256.hexdigest(query.downcase.strip)}"
      cached = true

      results = Rails.cache.fetch(key, expires_in: CACHE_TTL, skip_nil: true) do
        cached = false
        fetch_serp(query)
      end

      Rails.logger.info("[SEARCH] SERP #{cached ? 'cache hit' : 'live (10 credits)'} | #{Array(results).size} results | query=#{query.inspect}")
      results || []
    rescue StandardError => e
      Rails.logger.error("[SEARCH] SERP failed: #{e.class} #{e.message}")
      []
    end

    # Returns the first AI_MODE_WORDS words of Google's AI Mode answer as a plain string,
    # or nil if AI Mode returned nothing usable or the request failed. Never raises.
    def ai_mode_answer(query)
      return nil unless enabled?

      key = "search_client/ai_mode/#{Digest::SHA256.hexdigest(query.downcase.strip)}"
      cached = true

      answer = Rails.cache.fetch(key, expires_in: CACHE_TTL, skip_nil: true) do
        cached = false
        fetch_ai_mode(query)
      end

      Rails.logger.info("[SEARCH] AI Mode #{cached ? 'cache hit' : 'live (10 credits)'} | present=#{answer.present?} query=#{query.inspect}")
      answer
    rescue StandardError => e
      Rails.logger.error("[SEARCH] AI Mode failed: #{e.class} #{e.message}")
      nil
    end

    private

    def token
      Rails.application.credentials.dig(:scrape_do, :token)
    end

    # ---- SERP ----

    # Returns nil (not cached) on failure or when nothing usable comes back
    def fetch_serp(query)
      response = get_with_retry(ENDPOINT, query)
      return nil unless response

      data = JSON.parse(response.body)
      items = data["organic_results"]

      unless items.is_a?(Array) && items.any?
        Rails.logger.warn("[SEARCH] no organic_results in response; top-level keys: #{data.keys.first(15).inspect}")
        return nil
      end

      results = items.first(RESULT_COUNT).map do |item|
        {
          title: clean(item["title"], 150),
          url: (item["link"] || item["url"]).to_s,
          snippet: clean(item["snippet"] || item["description"], SNIPPET_MAX)
        }
      end

      results.select { |r| r[:url].start_with?("http") && r[:snippet].present? }.presence
    end

    # ---- AI Mode ----

    def fetch_ai_mode(query)
      response = get_with_retry(AI_MODE_ENDPOINT, query)
      return nil unless response

      data = JSON.parse(response.body)
      text = blocks_to_text(data["text_blocks"])
      return nil if text.blank?

      first_words(text, AI_MODE_WORDS)
    end

    # Flattens AI Mode's text_blocks (paragraphs, headings, lists) into plain text
    def blocks_to_text(blocks)
      return "" unless blocks.is_a?(Array)

      lines = []

      blocks.each do |block|
        next unless block.is_a?(Hash)

        case block["type"]
        when "paragraph", "heading"
          lines << clean(block["snippet"], 2000)
        when "list", "ordered_list"
          Array(block["list"]).each do |item|
            lines << clean(item["snippet"], 400) if item.is_a?(Hash)
          end
        end
      end

      lines.reject(&:blank?).join(" ")
    end

    def first_words(text, count)
      text.to_s.split(/\s+/).first(count).join(" ")
    end

    # ---- Shared HTTP with the retry-once pattern ----

    # Returns the HTTP response on success (200), or nil on any permanent failure.
    # Retries once on a 502, per Scrape.do's "Transient Errors" guidance.
    def get_with_retry(endpoint, query)
      uri = URI(endpoint)
      uri.query = URI.encode_www_form(token: token, q: query, hl: LANGUAGE, gl: COUNTRY)

      response = nil
      MAX_ATTEMPTS.times do |attempt|
        response = Net::HTTP.start(
          uri.hostname, uri.port,
          use_ssl: true,
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT
        ) { |http| http.request(Net::HTTP::Get.new(uri)) }

        break unless response.code == "502"

        Rails.logger.warn("[SEARCH] 502 from #{endpoint} (attempt #{attempt + 1}/#{MAX_ATTEMPTS})")
      end

      unless response.is_a?(Net::HTTPSuccess)
        # Errors look like { "error": "...", "message": "..." }. The token is never logged.
        Rails.logger.error("[SEARCH] HTTP #{response.code} from #{endpoint}: #{response.body.to_s.truncate(200)}")
        return nil
      end

      response
    end

    # Search text is untrusted: decode entities, strip every tag, collapse whitespace
    def clean(text, max)
      CGI.unescapeHTML(text.to_s)
         .gsub(/<[^>]*>/, " ")
         .gsub(/\s+/, " ")
         .strip
         .truncate(max)
    end
  end
end
