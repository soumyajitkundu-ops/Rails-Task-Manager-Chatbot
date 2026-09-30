require "concurrent"

# In-memory, single-process only. Swap STORE for Redis (SETEX jti ttl 1 /
# EXISTS jti) once you run more than one worker/instance.
class TokenBlacklist
  STORE = Concurrent::Map.new

  class << self
    def revoke(jti, exp)
      STORE[jti] = true
      ttl = exp - Time.now.to_i
      return if ttl <= 0

      Concurrent::ScheduledTask.execute(ttl) { 
        STORE.delete(jti) 
        puts "Token with jti #{jti} has been removed from the blacklist after #{ttl} seconds."
    }
    end

    def revoked?(jti)
      STORE.key?(jti)
    end
  end
end