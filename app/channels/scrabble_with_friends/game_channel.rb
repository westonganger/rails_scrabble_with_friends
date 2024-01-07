module ScrabbleWithFriends
  class GameChannel < ApplicationCable::Channel
    def subscribed
      stream_from "game_#{params[:id]}"
    end
  end
end
