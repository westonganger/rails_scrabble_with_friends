module ScrabbleWithFriends
  class Turn < ApplicationRecord
    belongs_to :game, class_name: "ScrabbleWithFriends::Turn", touch: true
    belongs_to :player, class_name: "ScrabbleWithFriends::Player"

    validates :tiles_played, presence: true

    # self.tiles_played = [
    #   {letter: "A", cell: [3,2]},
    #   {letter: "S", cell: [3,3]},
    # ]

    def tiles_played
      self[:tiles_played].map(&:with_indifferent_access)
    end

    def letters_played
      tiles_played.map{|x| x.fetch(:letter) }
    end
  end
end
