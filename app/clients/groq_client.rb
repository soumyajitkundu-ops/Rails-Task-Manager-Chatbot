# app/services/groq_client.rb
require "net/http"
require "uri"
require "json"

class GroqClient
  BASE_URL = "https://api.groq.com/openai/v1/chat/completions"
  OPEN_TIMEOUT = 5  # seconds
  READ_TIMEOUT = 30 # seconds; keeps a request well inside the 2-minute idle window

  def initialize
    @api_key = Rails.application.credentials.dig(:groq, :api_key)
  end

  def chat(messages_array)
    uri = URI(BASE_URL)
    request = Net::HTTP::Post.new(uri)

    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"

    request.body = {
      model: "openai/gpt-oss-120b", # Or your preferred Groq model
      messages: messages_array,
      response_format: { type: "json_object" } # Force JSON output
    }.to_json

    response = Net::HTTP.start(
      uri.hostname, uri.port,
      use_ssl: true,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    ) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end
