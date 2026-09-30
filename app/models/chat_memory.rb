# app/models/chat_memory.rb
require "concurrent"
require "json"

# In-process working memory (fast path) backed by ChatMemorySnapshot (durable copy).
#
# Lifecycle per user:
#   request        -> fetch_or_load (map -> DB snapshot -> fresh) -> ChatMemoryJobs.schedule
#   snapshot job   -> persist to DB (debounced, replaced by every new request)
#   evict job      -> persist to DB, then drop from the map (after 2 idle minutes)
class ChatMemory
  STORE = Concurrent::Map.new
  LOCKS = Concurrent::Map.new
  MAX_MEMORY_LENGTH = 2000 # Prevents token limits from being exceeded

  class << self
    # Per-user, NON-reentrant lock. Never call with_lock from inside with_lock.
    def with_lock(user_id, &block)
      LOCKS.compute_if_absent(user_id) { Mutex.new }.synchronize(&block)
    end

    def read(user_id)
      STORE[user_id]
    end

    # Single source of truth for the "core data" snapshot injected into the prompt
    def build_core_data(user)
      {
        name: user.name,
        age: user.age,
        role: user.role,
        todos: user.todos.select(:id, :task, :priority, :description)
      }.to_json
    end

    # Map first, then DB snapshot, else a brand-new session.
    # Returns a copy of the state so callers never touch the live arrays.
    def fetch_or_load(user)
      with_lock(user.id) do
        state = STORE[user.id] || load_from_db(user) || create_fresh(user)
        view_of(state)
      end
    end

    def setup(user_id, core_data)
      puts "\n" + "-"*50
      puts "[CHAT MEMORY] 🆕 Initializing new session for User ID: #{user_id}"
      puts "-"*50

      STORE[user_id] = {
        core_data: core_data,
        summary: "This is the very beginning of the conversation. No topics have been discussed yet.",
        learned_facts: [],
        recent_turns: [],  # STRICTLY CHRONOLOGICAL (Max 5)
        priority_turns: [] # UNORDERED IMPORTANT MEMORIES (Max 5)
      }

      print_state_dump(user_id)
    end

    def update_interaction(user_id, user_msg, assistant_msg, new_summary, score, new_facts)
      with_lock(user_id) do
        state = STORE[user_id]
        next unless state

        score = score.to_f
        puts "\n" + "="*50
        puts "[CHAT MEMORY] 📥 New turn saved | User ID: #{user_id} | Priority Score: #{sprintf('%.2f', score)}/10.0"

        # 1. Save permanent facts to Long-Term Memory
        if new_facts.is_a?(Array) && new_facts.any?
          puts "[CHAT MEMORY] 🧠 Extracted #{new_facts.size} new permanent facts."
          state[:learned_facts].concat(new_facts)
          state[:learned_facts].uniq!
        end

        # 2. Create the new turn object with TRUNCATED safe text
        new_turn = {
          user: safe_truncate(user_msg),
          assistant: safe_truncate(assistant_msg),
          score: score
        }

        # 3. Add to BOTH Queues simultaneously from request 1
        state[:recent_turns] << new_turn
        state[:priority_turns] << new_turn

        # 4. Chronological Queue Eviction Strategy (Max 5, FIFO)
        if state[:recent_turns].size > 5
          puts "[CHAT MEMORY] ⏱️ Chronological limit exceeded (5). Evicting oldest turn..."
          state[:recent_turns].shift # FIFO: Drops the oldest turn
        end

        # 5. Priority Queue Eviction Strategy (Max 5, Lowest Score)
        if state[:priority_turns].size > 5
          puts "[CHAT MEMORY] ⚠️ Priority limit exceeded (5). Initiating lowest-score eviction..."
          state[:priority_turns].sort_by! { |turn| turn[:score] }
          evicted_turn = state[:priority_turns].shift # Drops the lowest score
          puts "[CHAT MEMORY] 🗑️  Evicted lowest priority turn (Score: #{sprintf('%.2f', evicted_turn[:score])})."
        end

        # 6. Update the self-contained comprehensive summary (also truncated just in case)
        state[:summary] = safe_truncate(new_summary, 1000)

        print_state_dump(user_id)
        puts "="*50 + "\n"
      end
    end

    # Formats ONLY the chronological recent_turns for the Groq API messages array
    def formatted_recent_history(user_id)
      with_lock(user_id) do
        state = STORE[user_id]
        next [] unless state

        state[:recent_turns].flat_map do |turn|
          [
            { role: "user", content: turn[:user] },
            { role: "assistant", content: turn[:assistant] }
          ]
        end
      end
    end

    # Full manual wipe: pending jobs, the map entry AND the durable snapshot
    def clear(user_id)
      ChatMemoryJobs.cancel(user_id)

      with_lock(user_id) do
        removed = STORE.delete(user_id)
        ChatMemorySnapshot.where(user_id: user_id).delete_all
        puts "\n[CHAT MEMORY] 🧹 Memory manually wiped for User ID: #{user_id}\n" if removed
      end
    end

    # Refreshes ONLY the todo/user snapshot; conversation state is left intact
    def refresh_core_data(user)
      with_lock(user.id) do
        state = STORE[user.id]
        next unless state

        state[:core_data] = build_core_data(user)

        puts "\n[CHAT MEMORY] 🔄 Silent Reload: Core data refreshed for User ID: #{user.id}"
        print_state_dump(user.id)
      end
    end

    # Writes the conversation state to the DB. Caller MUST already hold the user's lock.
    # Raises on DB errors so the calling job can decide whether to retry.
    def persist(user_id)
      state = STORE[user_id]
      return false unless state

      ChatMemorySnapshot.persist!(
        user_id,
        summary: state[:summary],
        learned_facts: state[:learned_facts],
        recent_turns: state[:recent_turns],
        priority_turns: state[:priority_turns]
      )

      puts "[CHAT MEMORY] 💾 Snapshot saved to DB | User ID: #{user_id}"
      true
    end

    # Drops the session from the map. Caller MUST already hold the user's lock.
    def evict(user_id)
      puts "[CHAT MEMORY] 📤 Evicted from map (idle) | User ID: #{user_id}" if STORE.delete(user_id)
    end

    # Best-effort persist of every live session (used on process shutdown)
    def flush_all
      STORE.each_key do |user_id|
        with_lock(user_id) { persist(user_id) }
      rescue StandardError => e
        Rails.logger.error("[CHAT MEMORY] flush failed for user #{user_id}: #{e.class} #{e.message}")
      end
    end

    private

    def view_of(state)
      {
        core_data: state[:core_data],
        summary: state[:summary],
        learned_facts: state[:learned_facts].dup,
        recent_turns: state[:recent_turns].dup,
        priority_turns: state[:priority_turns].dup
      }
    end

    def create_fresh(user)
      setup(user.id, build_core_data(user))
      STORE[user.id]
    end

    # Rebuilds the map entry from the DB row. core_data is always regenerated from
    # live users/todos so it can never be stale. Returns nil when no snapshot exists.
    def load_from_db(user)
      record = ChatMemorySnapshot.find_by(user_id: user.id)
      return nil unless record

      puts "\n[CHAT MEMORY] 📂 Restored session from DB snapshot | User ID: #{user.id}"

      STORE[user.id] = {
        core_data: build_core_data(user),
        summary: record.summary,
        learned_facts: Array(record.learned_facts),
        recent_turns: symbolize_turns(record.recent_turns),
        priority_turns: symbolize_turns(record.priority_turns)
      }

      print_state_dump(user.id)
      STORE[user.id]
    end

    # JSON round-trips turn keys as strings; the rest of the code expects symbols
    def symbolize_turns(turns)
      Array(turns).map { |turn| turn.to_h.symbolize_keys }
    end

    # Truncates text so massive lists don't permanently break the API token limits
    def safe_truncate(text, max_length = MAX_MEMORY_LENGTH)
      return text unless text.is_a?(String)
      if text.length > max_length
        "#{text[0...max_length]}\n\n... [Content truncated to save memory limit]"
      else
        text
      end
    end

    def print_state_dump(user_id)
      state = STORE[user_id]
      return unless state

      puts "\n[CHAT MEMORY] 🧠 CURRENT MEMORY STATE DUMP:"

      puts "\n  🔹 LONG-TERM MEMORY (Facts):"
      if state[:learned_facts].empty?
        puts "     (None yet)"
      else
        state[:learned_facts].each { |f| puts "     ✅ #{f}" }
      end

      puts "\n  🔹 SELF-CONTAINED SUMMARY:"
      puts "     #{state[:summary]}"

      puts "\n  🔹 CHRONOLOGICAL QUEUE (Immediate Context - Max 5):"
      if state[:recent_turns].empty?
        puts "     (Empty)"
      else
        state[:recent_turns].each_with_index do |turn, index|
          u_msg = turn[:user].length > 40 ? "#{turn[:user][0..37].gsub("\n", ' ')}..." : turn[:user].gsub("\n", " ")
          a_msg = turn[:assistant].length > 40 ? "#{turn[:assistant][0..37].gsub("\n", ' ')}..." : turn[:assistant].gsub("\n", " ")
          puts "     #{index + 1}. [Score: #{sprintf('%.2f', turn[:score])}] 👤 #{u_msg} ➡️ 🤖 #{a_msg}"
        end
      end

      puts "\n  🔹 PRIORITY QUEUE (Older Important Context - Max 5):"
      if state[:priority_turns].empty?
        puts "     (Empty)"
      else
        state[:priority_turns].each_with_index do |turn, index|
          u_msg = turn[:user].length > 40 ? "#{turn[:user][0..37].gsub("\n", ' ')}..." : turn[:user].gsub("\n", " ")
          a_msg = turn[:assistant].length > 40 ? "#{turn[:assistant][0..37].gsub("\n", ' ')}..." : turn[:assistant].gsub("\n", " ")
          puts "     #{index + 1}. [Score: #{sprintf('%.2f', turn[:score])}] 👤 #{u_msg} ➡️ 🤖 #{a_msg}"
        end
      end
    end
  end
end
