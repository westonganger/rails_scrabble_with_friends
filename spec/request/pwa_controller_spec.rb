require 'spec_helper'

RSpec.describe ScrabbleWithFriends::PwaController, type: :request do
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

  context "service_worker" do
    it "renders" do
      get "/service-worker.js"
      expect(response.status).to eq(200)

      expect(response.body).to include("/update_web_push_subscription")
    end

    it "404 on non-js request" do
      get "/service-worker"
      expect(response.status).to eq(404)
    end
  end

  context "manifest" do
    it "renders" do
      get "/manifest.json"
      expect(response.parsed_body).to be_present
    end

    it "404 on non-js request" do
      get "/manifest"
      expect(response.status).to eq(404)
    end
  end

  context "update_web_push_subscription" do
    before do
      sign_in
    end

    it "doesnt allow non-logged in users" do
      logout
      post "/update_web_push_subscription.json"
      expect(response.status).to eq(302)
      expect(response).to redirect_to(scrabble_with_friends.sign_in_path)
    end

    it "updates an existing subscription" do
      game = ScrabbleWithFriends::Game.create!(name: :foo_name)
      player = game.players.create!(username: session[:scrabble_with_friends_username])

      subscription = ScrabbleWithFriends::WebPushSubscription.create!(
        game_id: game.id,
        player_id: player.id,
        endpoint: "some-old-endpoint",
        p256dh: "some-old-p-key",
        auth: "some-old-auth-value",
      )

      post "/update_web_push_subscription.json", params: {
        old_endpoint: "some-old-endpoint",
        endpoint: "some-new-endpoint",
        p256dh: "some-new-p-key",
        auth: "some-new-auth-key",
      }
      expect(response.status).to eq(200)

      subscription.reload

      expect(subscription.endpoint).to eq("some-new-endpoint")
      expect(subscription.p256dh).to eq("some-new-p-key")
      expect(subscription.auth).to eq("some-new-auth-key")
    end

    it "renders 404 on non-json request" do
      post "/update_web_push_subscription"
      expect(response.status).to eq(404)
    end
  end
end
