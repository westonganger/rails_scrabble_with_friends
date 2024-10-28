module ScrabbleWithFriends
  class WebPushSubscription < ApplicationRecord
    belongs_to :game, class_name: "ScrabbleWithFriends::Game"
    belongs_to :player, class_name: "ScrabbleWithFriends::Player"

    validates :endpoint, presence: true
    validates :p256dh, presence: true
    validates :auth, presence: true
    validates :game, presence: true
    validates :player, presence: true
  end
end
