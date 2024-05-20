require 'spec_helper'

RSpec.describe ScrabbleWithFriends::ApplicationMailer, type: :model do

  context "its_your_turn" do
    it "sends correctly" do
      expect {
        described_class.its_your_turn(
          game_url: "https://scrabble.example.com/games/123",
          email: "foo@bar.com",
        ).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  context "game_over" do
    it "sends correctly" do
      expect {
        described_class.game_over(
          game_url: "https://scrabble.example.com/games/123",
          email_addresses: ["foo@example.com", "bar@example.com"],
          winning_player_username: "bar@example.com",
        ).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

end
