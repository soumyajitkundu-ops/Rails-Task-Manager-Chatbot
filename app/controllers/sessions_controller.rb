class SessionsController < ApplicationController
  before_action :authenticate_user!, only: [ :logout ]

  def register
    user = User.new(user_params)

    if user.save
      token = JsonWebToken.encode(user_id: user.id, role: user.role)
      set_jwt_cookie(token)

      render json: {
        message: "Registered successfully",
        user: user_payload(user)
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(name: params[:name])

    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(user_id: user.id, role: user.role)
      set_jwt_cookie(token)
      render json: { message: "Logged in successfully", user: user_payload(user) }
    else
      render json: { error: "Invalid name or password" }, status: :unauthorized
    end
  end

  def logout
    cookies.delete(:jwt)
    TokenBlacklist.revoke(decoded_token[:jti], decoded_token[:exp])
    render json: { message: "Logged out successfully" }
  end

  private

  def set_jwt_cookie(token)
    cookies.signed[:jwt] = {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      expires: 2.hours.from_now
    }
  end

  def user_payload(user)
    { id: user.id, name: user.name, age: user.age, role: user.role }
  end

  def user_params
    params.permit(:name, :age, :password, :password_confirmation)
  end
end
