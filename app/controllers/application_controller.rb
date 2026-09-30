class ApplicationController < ActionController::API
  include ActionController::Cookies
  private
  def current_user
    @current_user ||= User.find_by(id: decoded_token[:user_id]) if decoded_token
  end

  def authenticate_user!
    render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
  end

  def decoded_token
    return @decoded_token if defined?(@decoded_token)

    token = cookies.signed[:jwt]
    payload = token && JsonWebToken.decode(token)

    @decoded_token = if payload.nil? || TokenBlacklist.revoked?(payload[:jti])
      nil
    else
      payload
    end
  end
end
