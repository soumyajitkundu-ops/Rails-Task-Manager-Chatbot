# app/services/chat_memory_jobs.rb
require "concurrent"

# Two timers per user, both killed and replaced on every request:
#   snapshot: SNAPSHOT_DELAY after the last request -> write state to the DB
#   evict:    EVICT_DELAY after the last request    -> write state to the DB, then drop it from the map
#
# Timers are in-process (same approach as TokenBlacklist). A generation number guards
# against a job that is already running when a newer request replaces it: the stale job
# sees its generation is no longer current and does nothing.
class ChatMemoryJobs
  SNAPSHOT_DELAY = 60   # seconds: debounce window for DB writes (set to 0 for near-immediate)
  EVICT_DELAY    = 120 # seconds: idle time before persist + eviction (2 minutes)
  RETRY_DELAY    = 30  # seconds: retry interval when the eviction write fails

  ENTRIES = Concurrent::Map.new # user_id => { gen:, snapshot:, evict: }
  SCHEDULE_LOCK = Mutex.new

  class << self
    # Called on every request: kills the user's pending jobs and creates fresh ones.
    def schedule(user_id)
      SCHEDULE_LOCK.synchronize do
        old = ENTRIES[user_id]
        cancel_tasks(old)
        gen = next_gen(old)

        ENTRIES[user_id] = {
          gen: gen,
          snapshot: start(SNAPSHOT_DELAY) { run_snapshot(user_id, gen) },
          evict: start(EVICT_DELAY) { run_evict(user_id, gen) }
        }
      end
    end

    # Kills pending jobs and invalidates any job that is mid-run (used by ChatMemory.clear)
    def cancel(user_id)
      SCHEDULE_LOCK.synchronize do
        old = ENTRIES[user_id]
        cancel_tasks(old)
        ENTRIES[user_id] = { gen: next_gen(old) }
      end
    end

    private

    def start(delay, &block)
      Concurrent::ScheduledTask.execute(delay, &block)
    end

    def cancel_tasks(entry)
      return unless entry

      %i[snapshot evict].each { |key| entry[key]&.cancel }
    end

    def next_gen(entry)
      (entry ? entry[:gen] : 0) + 1
    end

    def current?(user_id, gen)
      entry = ENTRIES[user_id]
      !entry.nil? && entry[:gen] == gen
    end

    def run_snapshot(user_id, gen)
      Rails.application.executor.wrap do
        ChatMemory.with_lock(user_id) do
          next unless current?(user_id, gen) # a newer request replaced this job

          ChatMemory.persist(user_id)
        end
      end
    rescue StandardError => e
      # The eviction job (and the next request's snapshot job) will try again
      Rails.logger.error("[CHAT MEMORY] snapshot failed for user #{user_id}: #{e.class} #{e.message}")
    end

    def run_evict(user_id, gen)
      retry_needed = false

      Rails.application.executor.wrap do
        ChatMemory.with_lock(user_id) do
          next unless current?(user_id, gen) # a newer request replaced this job

          begin
            ChatMemory.persist(user_id) # write first...
            ChatMemory.evict(user_id)   # ...then drop from the map
          rescue ActiveRecord::InvalidForeignKey
            ChatMemory.evict(user_id)   # user no longer exists; nothing to save
          rescue StandardError => e
            # Keep the session in memory rather than lose data; try again shortly
            retry_needed = true
            Rails.logger.error("[CHAT MEMORY] evict failed for user #{user_id}: #{e.class} #{e.message}")
          end
        end
      end

      reschedule_evict(user_id, gen) if retry_needed
    rescue StandardError => e
      Rails.logger.error("[CHAT MEMORY] evict job crashed for user #{user_id}: #{e.class} #{e.message}")
    end

    def reschedule_evict(user_id, gen)
      SCHEDULE_LOCK.synchronize do
        entry = ENTRIES[user_id]
        next unless entry && entry[:gen] == gen

        ENTRIES[user_id] = entry.merge(evict: start(RETRY_DELAY) { run_evict(user_id, gen) })
      end
    end
  end
end
