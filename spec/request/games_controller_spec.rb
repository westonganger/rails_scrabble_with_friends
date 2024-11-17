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

    create_player(username: session[:scrabble_with_friends_username])

    @game
  end

  def create_player(username: nil, notify_with: nil)
    player = @game.players.create!(
      username: username || SecureRandom.hex(6),
      notify_with: notify_with,
    )

    player
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

  def assert_action_denied_because_user_not_in_game
    @game.players.destroy_all

    player_2 = create_player

    create_turn(player: player_2)

    expect {
      post scrabble_with_friends.take_turn_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(flash.alert).to match(/not a part of this game/)
    }.not_to change { @game.reload.updated_at }
  end

  def create_subscription(player: nil, game: nil)
    game ||= @game
    player ||= game.players.first

    ### https://github.com/pushpad/web-push/blob/537267741b8b8cdd4ecedeb3f2da82e1145566d8/spec/web_push/encryption_spec.rb#L12
    p256dh = Base64.urlsafe_encode64(
      OpenSSL::PKey::EC
        .generate('prime256v1')
        .public_key
        .to_bn
        .to_s(2)
    )

    @game.web_push_subscriptions.create!(
      player_id: player.id,
      endpoint: WEB_PUSH_ENDPOINT,
      p256dh: p256dh,
      auth: Base64.urlsafe_encode64("some-auth-value"),
    )
  end

  WEB_PUSH_ENDPOINT = "https://localhost/some-endpoint".freeze

  before do
    sign_in

    stub_request(:post, WEB_PUSH_ENDPOINT).to_return(
      status: 201,
      body: '',
      headers: {},
    )
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
      game = assigns(:game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(game))
    end

    it "creates a new game with name" do
      post scrabble_with_friends.games_path, params: {name: "some-name"}
      game = assigns(:game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(game))
      expect(game.name).to eq("some-name")
    end

    it "finds existing game and renders errors" do
      name = "foo"

      post scrabble_with_friends.games_path, params: {name: name}
      expect(response).to redirect_to(scrabble_with_friends.game_path(assigns(:game)))

      post scrabble_with_friends.games_path, params: {name: name}
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
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      expect(@game.turns.reload.size).to eq(0)
    end

    it "responds to success" do
      player = @game.players.first

      player.update_columns(tiles: ["F","O","O"])

      expect(@game.turns.size).to eq(0)

      expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:game_email).and_call_original
      expect(WebPush).not_to receive(:payload_send).and_call_original

      post scrabble_with_friends.take_turn_game_path(@game), params: {
        game: {
          tiles_played: {
            "0" => {letter: "F", cell: [7,7]},
            "1" =>{letter: "O", cell: [7,8]},
            "2" =>{letter: "O", cell: [7,9]},
          },
        }
      }
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      expect(@game.turns.reload.size).to eq(1)
    end

    it "sends email when username is email address" do
      player_1 = @game.players.first
      player_1.update_columns(tiles: ["F","O","O","S"])

      player_2 = create_player(notify_with: "foo@bar.com")

      expect(@game.turns.size).to eq(0)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_email).with(subject: /Its your turn/, game_url: anything, email_addresses: [player_2.notify_with]).and_call_original
      expect(WebPush).not_to receive(:payload_send).and_call_original

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

      player_2 = create_player(notify_with: "foo@bar.com")

      allow_any_instance_of(ScrabbleWithFriends::Game).to receive(:game_over?).and_return(true)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_email).with(
        subject: "#{player_1.username} has won your #{ScrabbleWithFriends::APP_NAME} game",
        game_url: anything,
        email_addresses: [player_2.notify_with],
      ).and_call_original

      expect(WebPush).not_to receive(:payload_send).and_call_original

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

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
    end

    it "allows only the game current player to take turn when game started" do
      player_1 = @game.players.first
      player_2 = create_player

      create_turn(player: player_1)

      expect {
        post scrabble_with_friends.take_turn_game_path(@game)
        expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
        expect(flash.alert).to match(/not your turn/)
      }.not_to change { @game.reload.updated_at }
    end
  end

  context "undo_turn" do
    before do
      create_game
    end

    it "deletes the turn" do
      create_turn
      expect(@game.turns.size).to eq(1)

      expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:game_email).and_call_original
      expect(WebPush).not_to receive(:payload_send).and_call_original

      post scrabble_with_friends.undo_turn_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.turns.reload.size).to eq(0)
    end

    it "sends email" do
      player_1 = @game.players.first

      player_2 = create_player(notify_with: "foo@bar.com")

      create_turn(player: player_2)

      expect(@game.turns.size).to eq(1)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_email).with(subject: /Its your turn/, game_url: anything, email_addresses: [player_2.notify_with]).and_call_original

      expect(WebPush).not_to receive(:payload_send).and_call_original

      post scrabble_with_friends.undo_turn_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end

    it "sends webpush" do
      player_1 = @game.players.first

      player_2 = create_player(notify_with: "webpush")
      create_subscription(player: player_2)

      create_turn(player: player_2)

      expect(@game.turns.size).to eq(1)

      expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:game_email).and_call_original

      expect(WebPush).to receive(:payload_send).and_call_original

      post scrabble_with_friends.undo_turn_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end

    it "removes the score from the player" do
      create_turn
      player = @game.turns.last.player
      expect(player.score).not_to eq(0)
      post scrabble_with_friends.undo_turn_game_path(@game)
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
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      player.reload
      expect(player.tiles.sort).to eq(orig_player_tiles.sort)
      expect(player.tiles.size).to eq(7)
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
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
      expect(response.parsed_body.with_indifferent_access).to match({
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
      expect(response.parsed_body.with_indifferent_access).to match({
        words: [
          {
            word: "FOO",
            cells: [[7,7], [7,8], [7,9]],
            points: 6,
          }
        ],
      })
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
    end
  end

  context "forfeit_turn" do
    before do
      create_game
    end

    it "forfeits if current player" do
      expect(@game.players.first.forfeitted).to eq(false)

      expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:game_email).and_call_original

      expect(WebPush).not_to receive(:payload_send).and_call_original

      post scrabble_with_friends.forfeit_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      expect(@game.players.first.reload.forfeitted).to eq(true)
    end

    it "sends email when username is email address" do
      player_2 = create_player

      player_3 = create_player(notify_with: "player3@foo.com")

      create_turn

      logout
      sign_in(player_2.username)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_email).with(subject: /Its your turn/, game_url: anything, email_addresses: [player_3.notify_with]).and_call_original

      expect(WebPush).not_to receive(:payload_send).and_call_original

      post scrabble_with_friends.forfeit_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end

    it "sends email when game over" do
      player_1 = @game.players.first
      player_1.update_columns(notify_with: "foo@bar.com")

      player_2 = create_player(notify_with: "player2@foo.com")

      create_turn(player: player_1)

      logout
      sign_in(player_2.username)

      expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_email).with(
        subject: "#{player_1.username} has won your #{ScrabbleWithFriends::APP_NAME} game",
        game_url: anything,
        email_addresses: [player_1.notify_with],
      ).and_call_original

      expect(WebPush).not_to receive(:payload_send).and_call_original

      post scrabble_with_friends.forfeit_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
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
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.players.reload.size).to eq(2)
    end

    it "blocks when game started" do
      create_turn
      expect(@game.players.size).to eq(1)
      logout
      sign_in("some-other-username")
      post scrabble_with_friends.add_player_game_path(@game)
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
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.players.reload.size).to eq(1)
    end

    it "blocks when only one player" do
      expect(@game.players.size).to eq(1)
      post scrabble_with_friends.remove_player_game_path(@game), params: {player_id: @game.players.last.id}
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.players.reload.size).to eq(1)
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
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
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      expect(@game.turns.reload.size).to eq(0)
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
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

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
    end
  end

  context "web_push_subscribe" do
    before do
      create_game
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
    end

    it "creates a subscription record when no match found" do
      player = @game.players.first
      create_subscription

      expect {
        post scrabble_with_friends.web_push_subscribe_game_path(@game, format: :json), params: {
          endpoint: "some-endpoint",
          keys: {
            p256dh: "some-p-key",
            auth: "some-auth-key",
          },
        }
        expect(response.status).to eq(200)
        expect(player.web_push_subscriptions.reload.size).to eq(2)
      }.to change { player.web_push_subscriptions.reload.size }.by(1)
    end

    it "when subscription already exists just changes the subscription updated_at" do
      player = @game.players.first

      expect {
        post scrabble_with_friends.web_push_subscribe_game_path(@game, format: :json), params: {
          endpoint: "some-endpoint",
          keys: {
            p256dh: "some-p-key",
            auth: "some-auth-key",
          },
        }
        expect(response.status).to eq(200)
      }.to change { player.web_push_subscriptions.reload.size }.by(1)

      expect {
        post scrabble_with_friends.web_push_subscribe_game_path(@game, format: :json), params: {
          endpoint: "some-endpoint",
          keys: {
            p256dh: "some-p-key",
            auth: "some-auth-key",
          },
        }
        expect(response.status).to eq(200)
      }.not_to change { player.web_push_subscriptions.reload.size }
    end
  end

  context "email_subscribe" do
    before do
      create_game
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
    end

    it "updates notify_with with valid email" do
      player = @game.players.first

      expect(player.notify_with).to eq(nil)

      post scrabble_with_friends.email_subscribe_game_path(@game, format: :json), params: {email: "foo@bar"}
      expect(response.status).to eq(200)

      player.reload

      expect(player.notify_with).to eq("foo@bar")
      expect(player.notification_type).to eq("email")
    end

    it "doesnt save invalid email" do
      player = @game.players.first

      expect(player.notify_with).to eq(nil)

      expect {
        post scrabble_with_friends.email_subscribe_game_path(@game, format: :json), params: {email: "foo"}
        expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      }.to raise_error(ActiveRecord::RecordInvalid)

      player.reload

      expect(player.notify_with).to eq(nil)
      expect(player.notification_type).to eq(nil)

      expect {
        post scrabble_with_friends.email_subscribe_game_path(@game, format: :json), params: {email: ""}
        expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
      }.to raise_error(ActionController::ParameterMissing)

      player.reload

      expect(player.notify_with).to eq(nil)
      expect(player.notification_type).to eq(nil)
    end
  end

  context "notifications_unsubscribe" do
    before do
      create_game
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
    end

    it "deletes all web push subscriptions" do
      player = @game.players.first

      create_subscription

      expect(player.web_push_subscriptions.empty?).to eq(false)

      post scrabble_with_friends.notifications_unsubscribe_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      expect(player.web_push_subscriptions.empty?).to eq(true)
    end

    it "works when no subscriptions" do
      player = @game.players.first

      expect(player.web_push_subscriptions.empty?).to eq(true)

      post scrabble_with_friends.notifications_unsubscribe_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
    end

    it "clears player.notify_with" do
      player = @game.players.first
      player.update_columns(notify_with: "foo")

      post scrabble_with_friends.notifications_unsubscribe_game_path(@game)
      expect(response).to redirect_to(scrabble_with_friends.game_path(@game))

      player.reload

      expect(player.notify_with).to eq(nil)
    end
  end

  context "trigger_turn_notification" do
    before do
      create_game
    end

    it "does not perform action when user not in game" do
      assert_action_denied_because_user_not_in_game
    end

    context "email" do
      before do
        @player = @game.players.first
        @player.update_columns(notify_with: "foo@bar.com")

        expect(WebPush).not_to receive(:payload_send).and_call_original
      end

      it "sends reminder" do
        create_turn

        expect(ScrabbleWithFriends::ApplicationMailer).to receive(:game_email).and_call_original

        post scrabble_with_friends.trigger_turn_notification_game_path(@game)
        expect(response.status).to eq(200)
      end

      it "does not send reminder if no email" do
        create_turn

        @player.update_columns(notify_with: nil)

        expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:game_email).and_call_original

        post scrabble_with_friends.trigger_turn_notification_game_path(@game)
        expect(response.status).to eq(200)
      end

      it "does not send reminder if no game_current_user" do
        expect(@game.started?).to eq(false)

        expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:game_email).and_call_original

        post scrabble_with_friends.trigger_turn_notification_game_path(@game)
        expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
        expect(flash.alert).to match(/Action not permitted, its not anyones turn/)
      end
    end

    context "webpush" do
      before do
        @player = @game.players.first
        @player.update_columns(notify_with: "webpush")
        create_subscription

        expect(ScrabbleWithFriends::ApplicationMailer).not_to receive(:game_email).and_call_original
      end

      it "sends reminder when subscriptions exist" do
        create_turn

        expect(WebPush).to receive(:payload_send).and_call_original

        post scrabble_with_friends.trigger_turn_notification_game_path(@game)
        expect(response.status).to eq(200)
      end

      it "does not send reminder if no subscriptions" do
        create_turn

        @player.web_push_subscriptions.destroy_all

        expect(WebPush).not_to receive(:payload_send).and_call_original

        post scrabble_with_friends.trigger_turn_notification_game_path(@game)
        expect(response.status).to eq(200)
      end

      it "does not send reminder if no game_current_user" do
        expect(@game.started?).to eq(false)

        expect(WebPush).not_to receive(:payload_send).and_call_original

        post scrabble_with_friends.trigger_turn_notification_game_path(@game)
        expect(response).to redirect_to(scrabble_with_friends.game_path(@game))
        expect(flash.alert).to match(/Action not permitted, its not anyones turn/)
      end
    end
  end
end
