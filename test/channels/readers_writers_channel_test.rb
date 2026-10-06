require "test_helper"

class ReadersWritersChannelTest < ActionCable::Channel::TestCase
  self.fixture_table_names = []
  tests ReadersWritersChannel

  setup do
    ReadersWritersService.reset!
  end

  teardown do
    ReadersWritersService.reset!
  end

  test "tracks an authenticated user on their private stream and releases their lock on unsubscribe" do
    user = User.create!(name: "rw-channel-#{SecureRandom.hex(4)}", age: 30, password: "password")
    stub_connection current_user: user

    subscribe

    assert subscription.confirmed?
    assert_has_stream ReadersWritersService.stream_name(user.id)
    ReadersWritersService.acquire(user, "reader")
    assert_equal 1, ReadersWritersService.state(user).fetch(:reader_count)

    subscription.unsubscribed

    assert_equal 0, ReadersWritersService.state(user).fetch(:reader_count)
    assert_empty ReadersWritersService.state(user).fetch(:active_users)
  end
end
