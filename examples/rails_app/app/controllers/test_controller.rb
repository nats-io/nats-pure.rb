class TestController < ApplicationController
  def index
    @messages = Message.all
  end

  def publish
    $nats.publish('messages', params.require(:message))
    redirect_back fallback_location: root_path
  end
end
