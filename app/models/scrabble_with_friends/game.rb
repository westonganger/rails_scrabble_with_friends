module ScrabbleWithFriends
  class Game < ApplicationRecord
    has_many :players, class_name: "ScrabbleWithFriends::Player", dependent: :destroy
    has_many :turns, class_name: "ScrabbleWithFriends::Turn", dependent: :destroy

    validate do
      if new_record? && password.present? && self.class.find_by("public_id = :password OR password = :password", password: password)
        self.errors.add(:password, "password already taken, please use a different one")
      end
    end
    validates :public_id, uniqueness: {case_sensitive: true, allow_blank: true}

    def password=(val)
      self[:password] = val&.downcase
    end

    before_create do
      if password.present?
        self.password = password.strip
      else
        self.password = nil
      end
    end

    after_create do
      self.update_columns(public_id: ApplicationRecord.generate_public_id(id))
    end

    def name
      self.password
    end

    def to_param
      public_id
    end

    def started?
      !!turns.first
    end

    def game_over?
      active_players.none?
    end

    def restart!
      ActiveRecord::Base.transaction do
        self.turns.each do |turn|
          turn.destroy!
        end

        self.players.each do |player|
          player.update!(tiles: [], forfeitted: false, score: 0)
        end

        self.reload

        self.players.shuffle.each do |player|
          new_tiles = tiles_in_bag.sample(ScrabbleWithFriends::Player::MAX_TILES)
          player.update!(tiles: new_tiles)
        end
      end
    end

    def create_turn!(player:, tiles_played:, score:)
      letters_played = tiles_played.map{|x| x.fetch(:letter) }

      ### Ensure letters played are valid
      players_tiles = player.tiles.dup

      letters_played.each do |letter|
        if players_tiles.include?(letter)
          players_tiles.delete_at(players_tiles.index(letter))
        else
          raise "Invalid letters played #{letters_played}"

        end
      end

      self.turns.create!(player: player, tiles_played: tiles_played, score: score)

      player.score += score

      player.tiles = players_tiles

      player.save!

      players.reload
      more_tiles = tiles_in_bag.sample(ScrabbleWithFriends::Player::MAX_TILES - players_tiles.size)
      if more_tiles.any?
        player.update!(tiles: (player.tiles + more_tiles))
      end
    end

    def active_players
      players.reject { |x| x.forfeitted? || x.tiles.empty? }
    end

    def last_turn
      self.turns.last
    end

    def current_player
      return nil if game_over?

      if last_turn.nil?
        return nil
      end

      last_player_id = last_turn.player_id

      last_player_index = player_ids.index(last_player_id)

      players.each_with_index do |player, i|
        next if i <= last_player_index
        next if !player.active?
        return player
      end

      return active_players.first
    end

    def tiles_in_bag
      tiles_on_game = board.flatten.compact
      tiles_in_hand = players.flat_map(&:tiles)

      bag_tiles = ALL_TILES.shuffle

      tiles_on_game.each do |letter|
        i = bag_tiles.index(letter)
        if i
          bag_tiles.delete_at(i)
        else
          # this shouldnt happen but lets allow broken games to continue
          Rails.logger.debug("tiles in game dont exist in bag possibilities")
        end
      end

      tiles_in_hand.each do |letter|
        i = bag_tiles.index(letter)
        if i
          bag_tiles.delete_at(i)
        else
          # this shouldnt happen but lets allow broken games to continue
          Rails.logger.debug("tiles in hand dont exist in bag possibilities")
        end
      end

      bag_tiles.shuffle
    end

    def load_board
      tiles_played_by_cell = turns
        .flat_map(&:tiles_played)
        .map{|x| [x.fetch(:cell), x.fetch(:letter)]}
        .to_h

      BOARD_SIZE.times.map do |row_index|
        BOARD_SIZE.times.map do |col_index|
          cell = [row_index, col_index]
          tiles_played_by_cell[cell]
        end
      end
    end

    def board
      @board ||= load_board
    end

    BOARD_SIZE = 15
    WILDCARD = "*".freeze

    TILE_COUNTS = {
      "A" => 9,
      "B" => 2,
      "C" => 2,
      "D" => 4,
      "E" => 12,
      "F" => 2,
      "G" => 3,
      "H" => 2,
      "I" => 9,
      "J" => 1,
      "K" => 1,
      "L" => 4,
      "M" => 2,
      "N" => 6,
      "O" => 8,
      "P" => 2,
      "Q" => 1,
      "R" => 6,
      "S" => 4,
      "T" => 6,
      "U" => 4,
      "V" => 2,
      "W" => 2,
      "X" => 1,
      "Y" => 2,
      "Z" => 1,
      WILDCARD => 2,
    }.freeze

    ALL_TILES = TILE_COUNTS.flat_map.each do |letter, num|
      tiles = []
      num.times.each do
        tiles << letter
      end
      tiles
    end.freeze

    TILE_SCORES = {
      "A" => 1,
      "B" => 3,
      "C" => 3,
      "D" => 2,
      "E" => 1,
      "F" => 4,
      "G" => 2,
      "H" => 4,
      "I" => 1,
      "J" => 8,
      "K" => 5,
      "L" => 1,
      "M" => 3,
      "N" => 1,
      "O" => 1,
      "P" => 3,
      "Q" => 10,
      "R" => 1,
      "S" => 1,
      "T" => 1,
      "U" => 1,
      "V" => 4,
      "W" => 4,
      "X" => 8,
      "Y" => 4,
      "Z" => 10,
      WILDCARD => 0,
    }.freeze

    CENTER_CELL = [7, 7].freeze

    DOUBLE_WORD_CELLS = [
      [1, 1],
      [1, 13],
      [2, 2],
      [2, 12],
      [3, 3],
      [3, 11],
      [4, 4],
      [4, 10],
      [5, 5],
      [5, 9],
      [9, 5],
      [9, 9],
      [10, 4],
      [10, 10],
      [11, 3],
      [11, 11],
      [12, 2],
      [12, 12],
      [13, 1],
      [13, 13],
    ].freeze

    TRIPLE_WORD_CELLS = [
      [0, 0],
      [0, 7],
      [0, 14],
      [7, 0],
      [7, 14],
      [14, 0],
      [14, 7],
      [14, 14],
    ].freeze

    DOUBLE_LETTER_CELLS = [
      [0, 3],
      [0, 11],
      [2, 6],
      [2, 8],
      [3, 0],
      [3, 7],
      [3, 14],
      [6, 2],
      [6, 6],
      [6, 8],
      [6, 12],
      [7, 3],
      [7, 11],
      [8, 2],
      [8, 6],
      [8, 8],
      [8, 12],
      [11, 0],
      [11, 7],
      [11, 14],
      [12, 6],
      [12, 8],
      [14, 3],
      [14, 11],
    ].freeze

    TRIPLE_LETTER_CELLS = [
      [1, 5],
      [1, 9],
      [5, 1],
      [5, 5],
      [5, 9],
      [5, 13],
      [9, 1],
      [9, 5],
      [9, 9],
      [9, 13],
      [13, 5],
      [13, 9],
    ].freeze
  end
end
