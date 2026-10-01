module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      token = cookies.signed[:jwt]
      payload = token && JsonWebToken.decode(token)

      reject_unauthorized_connection unless payload && !TokenBlacklist.revoked?(payload[:jti])

      self.current_user = User.find_by(id: payload[:user_id])
      reject_unauthorized_connection unless current_user
    end
  end
end
