class ReadersWritersController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: ReadersWritersService.state(current_user)
  end

  def create
    render json: ReadersWritersService.acquire(current_user, params[:mode])
  rescue ReadersWritersService::Conflict => error
    render json: { error: error.message }, status: :conflict
  rescue ArgumentError => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def destroy
    render json: ReadersWritersService.release(current_user)
  end
end
