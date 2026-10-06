class ReadersWritersService
  class Conflict < StandardError; end

  def self.stream_name(user_id)
    "readers_writers:user:#{user_id}"
  end

  def self.state(user)
    store[:monitor].synchronize { state_unlocked(user.id) }
  end

  def self.connect(user)
    store[:monitor].synchronize do
      participant = participants[user.id] ||= { user_id: user.id, name: user.name, connections: 0, mode: nil }
      participant[:connections] += 1
    end

    broadcast_state
    state(user)
  end

  def self.acquire(user, mode)
    raise ArgumentError, "Mode must be reader or writer" unless %w[reader writer].include?(mode)

    store[:monitor].synchronize do
      participant = participants[user.id]
      raise Conflict, "Connect to the room before acquiring a lock" unless participant

      if mode == "reader"
        if participants.values.any? { |entry| entry[:mode] == "writer" }
          raise Conflict, "A writer currently holds the lock"
        end
      elsif participant[:mode] == "reader" || participants.any? do |user_id, entry|
        user_id != user.id && entry[:mode]
      end
        raise Conflict, "The write lock requires zero readers and no other writer"
      end

      participant[:mode] = mode
    end

    broadcast_state
    state(user)
  end

  def self.release(user)
    store[:monitor].synchronize do
      participant = participants[user.id]
      participant[:mode] = nil if participant
    end

    broadcast_state
    state(user)
  end

  def self.disconnect(user)
    store[:monitor].synchronize do
      participant = participants[user.id]
      if participant
        participant[:connections] -= 1
        participants.delete(user.id) if participant[:connections] <= 0
      end
    end

    broadcast_state
  end

  def self.reset!
    store[:monitor].synchronize { participants.clear }
  end

  def self.broadcast_state
    snapshots = store[:monitor].synchronize do
      participants.keys.map do |user_id|
        [ user_id, state_unlocked(user_id) ]
      end
    end

    snapshots.each do |user_id, snapshot|
      ActionCable.server.broadcast(stream_name(user_id), snapshot)
    end
  end

  def self.state_unlocked(user_id)
    current = participants[user_id]
    readers = participants.values.select { |participant| participant[:mode] == "reader" }
    writer = participants.values.find { |participant| participant[:mode] == "writer" }

    {
      reader_count: readers.length,
      readers: readers.map { |participant| participant[:name] },
      writer: writer&.fetch(:name),
      active_users: participants.values.map do |participant|
        { id: participant[:user_id], name: participant[:name], mode: participant[:mode] }
      end,
      session_mode: current&.fetch(:mode)
    }
  end

  def self.store
    Rails.application.config.x.readers_writers_state
  end
  private_class_method :store

  def self.participants
    store[:participants]
  end
  private_class_method :participants
end
