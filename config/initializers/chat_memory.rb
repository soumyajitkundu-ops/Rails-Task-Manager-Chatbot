# config/initializers/chat_memory.rb
#
# Best-effort: on graceful shutdown (deploy, SIGTERM) write every live chat session to the DB
# so the debounce window doesn't cost any turns. A hard crash (kill -9) can still lose up to
# ChatMemoryJobs::SNAPSHOT_DELAY seconds of the latest turns.
at_exit do
  begin
    Rails.application.executor.wrap { ChatMemory.flush_all }
  rescue StandardError => e
    warn "[CHAT MEMORY] shutdown flush failed: #{e.class} #{e.message}"
  end
end
