require "test_helper"

class ReadersWritersControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    ReadersWritersService.reset!
    @user = User.create!(name: "rw-#{SecureRandom.hex(4)}", age: 30, password: "password")
    sign_in(@user)
    ReadersWritersService.connect(@user)
  end

  teardown do
    ReadersWritersService.reset!
  end

  test "allows multiple readers and reports the reader count" do
    post "/readers_writers/lock", params: { mode: "reader" }, as: :json

    assert_response :success
    assert_equal 1, response.parsed_body.fetch("reader_count")

    another_user = User.create!(name: "rw-#{SecureRandom.hex(4)}", age: 30, password: "password")
    ReadersWritersService.connect(another_user)
    sign_in(another_user)
    post "/readers_writers/lock", params: { mode: "reader" }, as: :json

    assert_response :success
    assert_equal 2, response.parsed_body.fetch("reader_count")
  end

  test "denies a writer while readers hold the lock and allows it after release" do
    post "/readers_writers/lock", params: { mode: "reader" }, as: :json

    writer_user = User.create!(name: "rw-#{SecureRandom.hex(4)}", age: 30, password: "password")
    ReadersWritersService.connect(writer_user)
    sign_in(writer_user)
    post "/readers_writers/lock", params: { mode: "writer" }, as: :json
    assert_response :conflict

    sign_in(@user)
    delete "/readers_writers/lock", as: :json
    assert_response :success

    sign_in(writer_user)
    post "/readers_writers/lock", params: { mode: "writer" }, as: :json
    assert_response :success
    assert_equal 0, response.parsed_body.fetch("reader_count")
    assert_equal writer_user.name, response.parsed_body.fetch("writer")
  end

  test "denies a reader while a writer holds the lock" do
    post "/readers_writers/lock", params: { mode: "writer" }, as: :json

    reader_user = User.create!(name: "rw-#{SecureRandom.hex(4)}", age: 30, password: "password")
    ReadersWritersService.connect(reader_user)
    sign_in(reader_user)
    post "/readers_writers/lock", params: { mode: "reader" }, as: :json

    assert_response :conflict
  end

  test "returns unauthorized without a signed-in user" do
    delete logout_url, as: :json
    get "/readers_writers/state"

    assert_response :unauthorized
  end

  private

  def sign_in(user)
    post login_url, params: { name: user.name, password: "password" }, as: :json
    assert_response :success
  end
end
