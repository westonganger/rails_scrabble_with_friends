module ScrabbleWithFriends
  class Player < ApplicationRecord
    MAX_TILES = 7

    belongs_to :game, class_name: "ScrabbleWithFriends::Game", touch: true

    validates :username, presence: true, uniqueness: {scope: :game_id, case_sensitive: false}

    before_create do
      self.tiles = game.tiles_in_bag.sample(MAX_TILES)
    end

    def active?
      !forfeitted? && !tiles.empty?
    end
  end
end
