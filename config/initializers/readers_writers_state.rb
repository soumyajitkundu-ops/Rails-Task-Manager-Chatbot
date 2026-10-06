require "monitor"

Rails.application.config.x.readers_writers_state = {
  monitor: Monitor.new,
  participants: {}
}
