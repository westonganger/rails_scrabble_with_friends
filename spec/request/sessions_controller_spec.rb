require 'spec_helper'

RSpec.describe ScrabbleWithFriends::SessionsController, type: :request do
  def logout
    get scrabble_with_friends.sign_out_path
    assert_equal(response.status, 302)
    assert_redirected_to scrabble_with_friends.sign_in_path
  end

  def sign_in
    post scrabble_with_friends.sign_in_path, params: {username: "some-username"}
    assert_equal(response.status, 302)
  end

  context "sign_in" do
    it "redirects to games index when already signed in" do
      sign_in

      get scrabble_with_friends.sign_in_path
      assert_equal(response.status, 302)
      assert_redirected_to scrabble_with_friends.games_path
    end

    it "allows sign in" do
      get scrabble_with_friends.sign_in_path
      assert_equal(response.status, 200)
    end

    it "redirects to requested game" do
      @game = ScrabbleWithFriends::Game.create!(name: "foo")
      get scrabble_with_friends.game_path("foo")
      assert_equal(response.status, 302)
      assert_redirected_to scrabble_with_friends.sign_in_path

      sign_in
      assert_redirected_to scrabble_with_friends.game_path("foo")
    end
  end

  context "sign_out" do
    it "signs out" do
      sign_in

      get scrabble_with_friends.sign_out_path
      assert_equal(response.status, 302)
      assert_redirected_to scrabble_with_friends.sign_in_path
    end

    it "redirects when already signed out" do
      get scrabble_with_friends.sign_out_path
      assert_equal(response.status, 302)
      assert_redirected_to scrabble_with_friends.sign_in_path
    end
  end

end
