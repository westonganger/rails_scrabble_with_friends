require 'spec_helper'

RSpec.describe ScrabbleWithFriends::ApplicationMailer, type: :model do

  context "game_email" do
    it "sends correctly" do
      expect {
        described_class.game_email(
          subject: "foo",
          game_url: "https://scrabble.example.com/games/123",
          email_addresses: ["foo@example.com", "bar@example.com"],
        ).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

end
