class ReadersWritersChannel < ApplicationCable::Channel
  def subscribed
    stream_from ReadersWritersService.stream_name(current_user.id)
    ReadersWritersService.connect(current_user)
  end

  def unsubscribed
    ReadersWritersService.disconnect(current_user)
  end
end
