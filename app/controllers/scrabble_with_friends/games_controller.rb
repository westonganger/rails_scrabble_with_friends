require_dependency "scrabble_with_friends/application_controller"

module ScrabbleWithFriends
  class GamesController < ApplicationController
    before_action do
      if !signed_in?
        if request.method == "GET" && params[:id].present?
          session[:scrabble_with_friends_return_to] = request.path
        end

        redirect_to sign_in_path
      end

      if @game && @game.started? && @game.players.map(&:username).exclude?(current_username)
        redirect_to(action: :index)
      end
    end

    def index
      _fetch_your_games
    end

    def new
    end

    def create
      (ScrabbleWithFriends::Game.inactive_games.to_a + ScrabbleWithFriends::Game.orphaned_games.to_a).each do |game|
        game.destroy!
      end

      game_saved = false

      @game = ScrabbleWithFriends::Game.new(name: params[:name])

      game_saved = false

      ActiveRecord::Base.transaction do
        game_saved = @game.save

        if game_saved
          @game.players.create!(username: current_username)
        end
      end

      if game_saved
        redirect_to(action: :show, id: @game.to_param)
      elsif @game.errors[:name].present?
        flash.alert = "Game not saved. Please choose a different name."
        redirect_to(action: :index)
      else
        flash.alert = "Game not saved."
        redirect_to(action: :index)
      end
    end

    def show
      begin
        @game = ScrabbleWithFriends::Game.includes(:players, :turns).find_by!(public_id: params[:id])
      rescue ActiveRecord::RecordNotFound
        flash[:alert] = "Game not found or expired."
        redirect_to(action: :index)
        return
      end

      _add_to_your_games

      @is_current_player = @game.active_players.map(&:username).include?(current_username) && !@game.game_over? && (!@game.started? || (_game_current_player.username == current_username))

      respond_to do |f|
        f.html
        f.json {
          render json: {
            game: {
              board: @game.board,
              updated_at: @game.updated_at.utc.iso8601,
            }
          }
        }
      end
    end

    def restart
      @game = ScrabbleWithFriends::Game.includes(:players, :turns).find_by!(public_id: params[:id])

      @game.restart!

      _broadcast_changes

      redirect_to(action: :show)
    end

    def forfeit
      @game = ScrabbleWithFriends::Game.includes(:players).find_by!(public_id: params[:id])

      _user_current_player.update!(forfeitted: true, tiles: [])

      if @game.game_over?
        ScrabbleWithFriends::ApplicationMailer.game_over(
          game_url: game_url(@game),
          emails: (@game.players.select(&:has_email?).map(&:username) - [current_username]),
          winning_player_username: @game.players.max_by(&:score).username,
        ).deliver_later
      elsif @game.current_player&.has_email? && @game.current_player.username != current_username
        ScrabbleWithFriends::ApplicationMailer.its_your_turn(
          game_url: game_url(@game),
          email: @game.current_player.username,
        ).deliver_later
      end

      _broadcast_changes

      redirect_to(action: :show)
    end

    def undo_turn
      @game = ScrabbleWithFriends::Game.find_by!(public_id: params[:id])

      last_turn = @game.last_turn

      last_player = last_turn.player

      if last_player.forfeitted?
        raise "Cannot undo"
      end

      tiles = last_player.tiles.dup

      tiles.pop(last_turn.letters_played.size)

      last_turn.letters_played.each do |letter|
        tiles << letter
      end

      ActiveRecord::Base.transaction do
        last_player.update!(
          score: (last_player.score - last_turn.score),
          tiles: tiles,
        )

        last_turn.destroy!
      end

      if last_player&.has_email? && last_player.username != current_username
        ScrabbleWithFriends::ApplicationMailer.its_your_turn(
          game_url: game_url(@game),
          email: last_player.username,
        ).deliver_later
      end

      _broadcast_changes

      flash.notice = "Successfully reverted last turn."

      redirect_to(action: :show)
    end

    def validate_turn
      @game = ScrabbleWithFriends::Game.includes(:players, :turns).find_by!(public_id: params[:id])

      _validate_turn_only

      if @errors.any?
        render json: {errors: @errors}
      else
        render json: {words: @words}
      end
    end

    def take_turn
      @game = ScrabbleWithFriends::Game.includes(:players, :turns).find_by!(public_id: params[:id])

      _validate_turn_only

      if @errors.any?
        flash[:alert] = "Turn failed"
        redirect_to(action: :show)
      else
        ActiveRecord::Base.transaction do
          @game.save!

          @game.create_turn!(
            player: _user_current_player,
            tiles_played: _tiles_played,
            score: @words.sum{|h| h.fetch(:points) },
          )
        end

        if @game.game_over?
          ScrabbleWithFriends::ApplicationMailer.game_over(
            game_url: game_url(@game),
            emails: (@game.players.select(&:has_email?).map(&:username) - [current_username]),
            winning_player_username: @game.players.max_by(&:score).username,
          ).deliver_later
        elsif @game.current_player&.has_email? && @game.current_player.username != current_username
          ScrabbleWithFriends::ApplicationMailer.its_your_turn(
            game_url: game_url(@game),
            email: @game.current_player.username,
          ).deliver_later
        end

        _broadcast_changes

        redirect_to(action: :show)
      end
    end

    def add_player
      @game = ScrabbleWithFriends::Game.includes(:turns).find_by!(public_id: params[:id])

      if @game.started?
        flash.alert = "Cannot add player when game is started"
        redirect_to(action: :show)
        return
      end

      @game.players.create!(
        username: current_username,
        tiles: @game.tiles_in_bag.sample(ScrabbleWithFriends::Player::MAX_TILES),
      )

      _broadcast_changes

      redirect_to(action: :show)
    end

    def remove_player
      @game = ScrabbleWithFriends::Game.includes(:players).find_by!(public_id: params[:id])

      if @game.players.size == 1
        flash.alert = "Cannot remove player. Game must have at least one player."
        redirect_to(action: :show)
        return
      end

      @game.players.find_by!(id: params.require(:player_id)).destroy!

      _broadcast_changes

      redirect_to(action: :show)
    end

    def destroy
      @game = ScrabbleWithFriends::Game.find_by!(public_id: params[:id])

      @game.destroy!

      redirect_to(action: :index)
    end

    private

    def _game_current_player
      return @game_current_player if defined?(@game_current_player)

      @game_current_player ||= @game.current_player

      if @game.started? && current_username != @game_current_player.username && request.method != "GET"
        raise "Not this users turn, cannot perform this action"
      end

      @game_current_player
    end

    def _user_current_player
      @game.players.detect{|x| x.username == current_username }
    end

    def _broadcast_changes
      ActionCable.server.broadcast(
        "game_#{@game.public_id}",
        {
          action: "reload",
          identifier: current_username,
        }
      )
    end

    def _add_to_your_games
      game_ids = session[YOUR_GAMES_SESSION_KEY] || []

      return if game_ids.include?(@game.public_id)
      return if @game.players.none?{|x| x.username == current_username }

      game_ids << @game.public_id

      session[YOUR_GAMES_SESSION_KEY] = game_ids
    end

    def _tiles_played
      return @tiles_played if defined?(@tiles_played)

      if params[:game].blank?
        return []
      end

      @tiles_played = params
        .require(:game)
        .permit(
          tiles_played: [
            :letter,
            cell: [],
          ],
        )
        .fetch(:tiles_played)
        .values

      @tiles_played = @tiles_played.map(&:presence).compact

      @tiles_played = @tiles_played.map do |x|
        x[:cell] = x.fetch(:cell).map(&:to_i)
        x
      end
    end

    def _invalid_placement?
      cells = _tiles_played.map{|x| x.fetch(:cell) }

      valid = true

      ### If first turn, check if played tiles exist on the center square
      if @game.turns.first.nil? && cells.exclude?([7,7])
        @errors << "Must start the game by playing on the center square"
        valid = false
      end

      ### If first turn, check if more than 1 tile played
      if @game.turns.first.nil? && cells.include?([7,7]) && cells.size == 1
        ### provide helpful error if is single letter word
        @errors << "Must be at least a 2 letter word"
        valid = false
      end

      ### Check if played tiles overlap existing tiles on the game
      cells.each_with_index do |(row_index, col_index), i|
        if @game.board[row_index][col_index].present?
          valid = false
          break
        end
      end

      ### Check if played tiles overlap eachother
      cells.each_with_index do |(row_index, col_index), i|
        if cells != cells.uniq
          valid = false
        end
      end

      if @game.turns.first.present?
        beside_another_tile = false
        ### Check if tiles beside at least one existing
        cells.each_with_index do |cell|
          row_index, col_index = cell

          tile_above = (row_index != 0) && @game.board[row_index-1][col_index].present?
          tile_below = (row_index != ScrabbleWithFriends::Game::BOARD_SIZE-1) && @game.board[row_index+1][col_index].present?
          tile_to_left = (col_index != 0) && @game.board[row_index][col_index-1].present?
          tile_to_right = (col_index != ScrabbleWithFriends::Game::BOARD_SIZE-1) && @game.board[row_index][col_index+1].present?

          beside_another_tile = tile_above || tile_below || tile_to_left || tile_to_right

          if beside_another_tile
            break
          end
        end

        if !beside_another_tile
          valid = false
        end
      end

      ### Check if all played tiles beside eachother
      updated_board = @game.board

      _tiles_played.each do |h|
        letter = h.fetch(:letter)
        cell = h.fetch(:cell)
        row_index, col_index = cell

        updated_row = updated_board[row_index]

        updated_row[col_index] = letter

        updated_board[row_index] = updated_row
      end

      played_row_indexes = cells.map{|row_index, col_index| row_index }
      played_col_indexes = cells.map{|row_index, col_index| col_index }

      if played_row_indexes.uniq.size == 1
        first_index = played_col_indexes.sort.first
        last_index = played_col_indexes.sort.last

        (first_index..last_index).each_with_index do |col_index, i|
          if played_col_indexes.exclude?(col_index) && updated_board[played_row_indexes.first][col_index].blank?
            @errors << "Played tiles are not all beside eachother"
            valid = false
            break
          end
        end
      elsif played_col_indexes.uniq.size == 1
        first_index = played_row_indexes.first
        last_index = played_row_indexes.last

        (first_index..last_index).each_with_index do |row_index, i|
          if played_row_indexes.exclude?(row_index) && updated_board[row_index][played_col_indexes.first].blank?
            @errors << "Played tiles are not all beside eachother"
            valid = false
            break
          end
        end
      else
        @errors << "Played tiles are not on one line"
        valid = false
      end

      return !valid
    end

    def _letters_played_valid_for_player?
      letters_played = _tiles_played.map{|x| x.fetch(:letter) }

      valid = true

      players_tiles = _user_current_player.tiles.dup

      letters_played.each_with_index.each do |letter, i|
        if players_tiles.include?(letter)
          players_tiles.delete_at(players_tiles.index(letter))
        else
          valid = false
        end
      end

      return valid
    end

    def _validate_turn_only
      @errors = []

      if _invalid_placement?
        @errors << "Invalid tile placement"
      elsif !_letters_played_valid_for_player?
        @errors << "Invalid letters provided"
      end

      if @errors.none?
        _get_words
      end
    end

    def _get_words
      @words = []

      updated_board = @game.board

      _tiles_played.each do |h|
        letter = h.fetch(:letter)
        cell = h.fetch(:cell)
        row_index, col_index = cell

        updated_row = updated_board[row_index]

        updated_row[col_index] = letter

        updated_board[row_index] = updated_row
      end

      ### Check words
      _tiles_played.each do |h|
        row_index, col_index = h.fetch(:cell)

        tile_above = (row_index != 0) && updated_board[row_index-1][col_index].present?
        tile_below = (row_index != ScrabbleWithFriends::Game::BOARD_SIZE-1) && updated_board[row_index+1][col_index].present?

        if tile_above || tile_below
          col_letters = updated_board.map{|row| row[col_index] }

          start_index = nil
          col_letters.to_enum.with_index.reverse_each do |letter, i|
            next if i >= row_index
            next if letter.present?

            start_index = i+1
            break
          end
          start_index ||= 0

          end_index = nil
          col_letters.each_with_index do |letter, i|
            next if i <= row_index
            next if letter.present?

            end_index = i-1
            break
          end
          end_index ||= ScrabbleWithFriends::Game::BOARD_SIZE-1

          cells = (start_index..end_index).map{|i| [i, col_index] }

          word = col_letters[start_index..end_index].join("")

          if !@words.map{|x| x.fetch(:cells) }.include?(cells) && word.size >= 2
            @words << {
              word: word,
              cells: cells,
              points: _get_points_for_word(cells, updated_board),
            }
          end
        end

        tile_to_left = (col_index != 0) && updated_board[row_index][col_index-1].present?
        tile_to_right = (col_index != ScrabbleWithFriends::Game::BOARD_SIZE-1) && updated_board[row_index][col_index+1].present?

        if tile_to_left || tile_to_right
          row_letters = updated_board[row_index]

          start_index = nil
          row_letters.to_enum.with_index.reverse_each do |letter, i|
            next if i >= col_index
            next if letter.present?

            start_index = i+1
            break
          end
          start_index ||= 0

          end_index = nil
          row_letters.each_with_index do |letter, i|
            next if i <= col_index
            next if letter.present?

            end_index = i-1
            break
          end
          end_index ||= ScrabbleWithFriends::Game::BOARD_SIZE-1

          cells = (start_index..end_index).map{|i| [row_index, i] }

          word = row_letters[start_index..end_index].join("")

          if !@words.map{|x| x.fetch(:cells) }.include?(cells) && word.size >= 2
            @words << {
              word: word,
              cells: cells,
              points: _get_points_for_word(cells, updated_board),
            }
          end
        end
      end

      @words
    end

    def _get_points_for_word(word_cells, updated_board)
      word_points = 0

      word_multiplier = nil

      word_cells.each do |cell|
        row_index, col_index = cell

        letter = updated_board[row_index][col_index]

        tile_points = ScrabbleWithFriends::Game::TILE_SCORES.fetch(letter)

        if _tiles_played.any?{|x| x[:cell] == cell }
          if ScrabbleWithFriends::Game::DOUBLE_LETTER_CELLS.include?(cell)
            tile_points = tile_points * 2
          elsif ScrabbleWithFriends::Game::TRIPLE_LETTER_CELLS.include?(cell)
            tile_points = tile_points * 3
          elsif ScrabbleWithFriends::Game::DOUBLE_WORD_CELLS.include?(cell)
            if word_multiplier
              word_multiplier = word_multiplier * 2
            else
              word_multiplier = 2
            end
          elsif ScrabbleWithFriends::Game::TRIPLE_WORD_CELLS.include?(cell)
            if word_multiplier
              word_multiplier = word_multiplier * 3
            else
              word_multiplier = 3
            end
          end
        end

        word_points += tile_points
      end

      if word_multiplier
        word_points = word_points * word_multiplier
      end

      word_points
    end

    def _fetch_your_games
      @your_games = []

      game_ids = session[YOUR_GAMES_SESSION_KEY]

      return if game_ids.blank?

      @your_games = ScrabbleWithFriends::Game
        .for_user(current_username)
        .where(public_id: game_ids)
        .includes(:players, :turns)
        .order(updated_at: :desc)

      session[YOUR_GAMES_SESSION_KEY] = @your_games.map(&:public_id)
    end

    YOUR_GAMES_SESSION_KEY = :scrabble_with_friends_your_game_ids
  end
end
