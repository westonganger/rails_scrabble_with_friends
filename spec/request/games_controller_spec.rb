require 'spec_helper'

RSpec.describe ScrabbleWithFriends::GamesController, type: :request do
  def sign_in(username="some-username")
    post scrabble_with_friends.sign_in_path, params: {username: username}
    expect(response.status).to eq(302)
    expect(response).to redirect_to(scrabble_with_friends.games_path)
  end

  def logout
    get scrabble_with_friends.sign_out_path
    expect(response.status).to eq(302)
    expect(response).to redirect_to(scrabble_with_friends.sign_in_path)
  end

  def create_game
    @game = ScrabbleWithFriends::Game.create!(name: :foo_name)
    @game.players.create!(username: session[:scrabble_with_friends_username])
    @game
  end

  def create_player(username: nil)
    @game.players.create!(
      username: username || SecureRandom.hex(6),
    )
  end

  def create_turn(player: nil)
    player ||= @game.players.first

    @game.create_turn!(
      player: player,
      tiles_played: [
        {letter: player.tiles.first, cell: [7,7]},
        {letter: player.tiles.second, cell: [7,8]},
        {letter: player.tiles.third, cell: [7,9]},
      ],
      score: 10,
    )
  end

  before do
    sign_in
  end

  context "index" do
    it "renders" do
      get scrabble_with_friends.games_path
      expect(response.status).to eq(200)
    end

    it "renders game list" do
      create_game

      get scrabble_with_friends.games_path
      expect(response.status).to eq(200)
      expect(response.body).to include("Your Games")
      expect(response.body).not_to include(scrabble_with_friends.game_path(@game))

      get scrabble_with_friends.game_path(@game)
      expect(response.status).to eq(200)

      get scrabble_with_friends.games_path
      expect(response.status).to eq(200)
      expect(response.body).to include("Your Games")
      expect(response.body).to include(scrabble_with_friends.game_path(@game))
    end
  end

  context "new" do
    it "renders" do
      get scrabble_with_friends.new_game_path
      expect(response.status).to eq(200)
    end
  end

  context "create" do
    it "creates a new game without name" do
      post scrabble_with_friends.games_path, params: {}
      expect(response.status).to eq(302)
      @game = assigns(:game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end

    it "creates a new game with name" do
      post scrabble_with_friends.games_path, params: {name: "some-name"}
      expect(response.status).to eq(302)
      @game = assigns(:game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.name).to eq("some-name")
    end

    it "finds existing game and renders errors" do
      name = "foo"

      post scrabble_with_friends.games_path, params: {name: name}
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(assigns(:game)))

      post scrabble_with_friends.games_path, params: {name: name}
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.games_path)
      expect(flash[:alert]).to include("Game not saved. Please choose a different name.")
    end
  end

  context "show" do
    before do
      create_game
    end

    it "renders waiting for game" do
      get scrabble_with_friends.game_path(@game)
      expect(response.status).to eq(200)
      expect(response.body).to include("board-square")
      expect(response.body).to include("Waiting to Start Game")
    end

    it "renders game started" do
      create_turn
      get scrabble_with_friends.game_path(@game)
      expect(response.status).to eq(200)
      expect(response.body).to include("board-square")
      expect(response.body).to include("Current Player")
    end
  end

  context "take_turn" do
    before do
      create_game
    end

    it "responds to errors" do
      @game.players.first.update_columns(tiles: ["F","O","O"])

      expect(@game.turns.size).to eq(0)

      post scrabble_with_friends.take_turn_game_path(@game), params: {
        game: {
          tiles_played: {
            "0" => {letter: "F", cell: [7,7]},
            "1" =>{letter: "O", cell: [7,9]},
          },
        }
      }
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      expect(@game.turns.reload.size).to eq(0)
    end

    it "responds to success" do
      player = @game.players.first

      player.update_columns(tiles: ["F","O","O"])

      expect(@game.turns.size).to eq(0)

      expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:its_your_turn).and_call_original

      post scrabble_with_friends.take_turn_game_path(@game), params: {
        game: {
          tiles_played: {
            "0" => {letter: "F", cell: [7,7]},
            "1" =>{letter: "O", cell: [7,8]},
            "2" =>{letter: "O", cell: [7,9]},
          },
        }
      }
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      expect(@game.turns.reload.size).to eq(1)
    end

    it "sends email when username is email address" do
      player_1 = @game.players.first
      player_1.update_columns(tiles: ["F","O","O","S"])

      player_2 = create_player(username: "foo@bar.com")

      expect(@game.turns.size).to eq(0)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:its_your_turn).with(game_url: anything, email: player_2.username).and_call_original

      post scrabble_with_friends.take_turn_game_path(@game), params: {
        game: {
          tiles_played: {
            "0" => {letter: "F", cell: [7,7]},
            "1" =>{letter: "O", cell: [7,8]},
            "2" =>{letter: "O", cell: [7,9]},
          },
        }
      }
    end

    it "sends email when game over" do
      player_1 = @game.players.first
      player_1.update_columns(tiles: ["F","O","O"])

      player_2 = create_player(username: "foo@bar.com")

      expect(@game.turns.size).to eq(0)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_over).with(game_url: anything, emails: [player_2.username], winning_player_username: player_1.username).and_call_original

      post scrabble_with_friends.take_turn_game_path(@game), params: {
        game: {
          tiles_played: {
            "0" => {letter: "F", cell: [7,7]},
            "1" =>{letter: "O", cell: [7,8]},
            "2" =>{letter: "O", cell: [7,9]},
          },
        }
      }
    end
  end

  context "undo_turn" do
    before do
      create_game
    end

    it "deletes the turn" do
      create_turn
      expect(@game.turns.size).to eq(1)

      expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:its_your_turn).and_call_original

      post scrabble_with_friends.undo_turn_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.turns.reload.size).to eq(0)
    end

    it "sends email if username is an email address" do
      player_1 = @game.players.first
      player_1.update_columns(username: "foo@bar.com")

      player_2 = create_player

      create_turn

      expect(@game.turns.size).to eq(1)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:its_your_turn).with(game_url: anything, email: player_1.username).and_call_original

      post scrabble_with_friends.undo_turn_game_path(@game)
    end

    it "removes the score from the player" do
      create_turn
      player = @game.turns.last.player
      expect(player.score).not_to eq(0)
      post scrabble_with_friends.undo_turn_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(player.reload.score).to eq(0)
    end

    it "returns the same tiles to the player" do
      player = @game.players.first
      orig_player_tiles = player.tiles

      create_turn

      player.reload
      expect(player.id).to eq(@game.turns.last.player_id)
      expect(player.tiles.sort).not_to eq(orig_player_tiles.sort)

      post scrabble_with_friends.undo_turn_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      player.reload
      expect(player.tiles.sort).to eq(orig_player_tiles.sort)
      expect(player.tiles.size).to eq(7)
    end
  end

  context "validate_turn" do
    before do
      create_game
    end

    it "returns errors" do
      @game.players.first.update_columns(tiles: ["F","O","O"])

      post scrabble_with_friends.validate_turn_game_path(@game), params: {
        game: {
          tiles_played: {
            "0" => {letter: "F", cell: [7,7]},
            "1" =>{letter: "O", cell: [7,9]},
          },
        }
      }
      expect(response.status).to eq(200)
      expect(response.parsed_body).to match({
        errors: [
          "Played tiles are not all beside eachother",
          "Invalid tile placement",
        ],
      })
    end

    it "returns words" do
      @game.players.first.update_columns(tiles: ["F","O","O"])

      post scrabble_with_friends.validate_turn_game_path(@game), params: {
        game: {
          tiles_played: {
            "0" => {letter: "F", cell: [7,7]},
            "1" =>{letter: "O", cell: [7,8]},
            "2" =>{letter: "O", cell: [7,9]},
          },
        }
      }
      expect(response.status).to eq(200)
      expect(response.parsed_body).to match({
        words: [
          {
            word: "FOO",
            cells: [[7,7], [7,8], [7,9]],
            points: 6,
          }
        ],
      })
    end
  end

  context "forfeit_turn" do
    before do
      create_game
    end

    it "forfeits if current player" do
      expect(@game.players.first.forfeitted).to eq(false)

      expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:its_your_turn).and_call_original

      post scrabble_with_friends.forfeit_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      expect(@game.players.first.reload.forfeitted).to eq(true)
    end

    it "sends email when username is email address" do
      player_2 = create_player

      player_3 = create_player(username: "player3@foo.com")

      create_turn

      logout
      sign_in(player_2.username)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:its_your_turn).with(game_url: anything, email: player_3.username).and_call_original

      post scrabble_with_friends.forfeit_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end

    it "sends email when game over" do
      player_1 = @game.players.first
      player_1.update_columns(username: "foo@bar.com")

      player_2 = create_player(username: "player2@foo.com")

      create_turn(player: player_1)

      logout
      sign_in(player_2.username)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_over).with(game_url: anything, emails: [player_1.username], winning_player_username: player_1.username).and_call_original

      post scrabble_with_friends.forfeit_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end
  end

  context "add_player" do
    before do
      create_game
    end

    it "allows when game not started" do
      expect(@game.players.size).to eq(1)
      logout
      sign_in("some-other-username")
      post scrabble_with_friends.add_player_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.players.reload.size).to eq(2)
    end

    it "blocks when game started" do
      create_turn
      expect(@game.players.size).to eq(1)
      logout
      sign_in("some-other-username")
      post scrabble_with_friends.add_player_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.players.reload.size).to eq(1)
    end
  end

  context "remove_player" do
    before do
      create_game
    end

    it "allows when game not started" do
      create_player
      expect(@game.players.size).to eq(2)
      post scrabble_with_friends.remove_player_game_path(@game), params: {player_id: @game.players.last.id}
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.players.reload.size).to eq(1)
    end

    it "blocks when only one player" do
      expect(@game.players.size).to eq(1)
      post scrabble_with_friends.remove_player_game_path(@game), params: {player_id: @game.players.last.id}
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.players.reload.size).to eq(1)
    end
  end

  context "restart" do
    before do
      create_game
    end

    it "deletes all turns" do
      create_turn
      expect(@game.turns.size).to eq(1)
      post scrabble_with_friends.restart_game_path(@game)
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.turns.reload.size).to eq(0)
    end
  end

  context "destroy" do
    before do
      create_game
    end

    it "deletes the game" do
      delete scrabble_with_friends.game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.games_path)
      expect(ScrabbleWithFriends::Game.find_by(id: @game.id)).to eq(nil)
    end
  end
end
