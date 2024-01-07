require 'spec_helper'

RSpec.describe ScrabbleWithFriends, type: :model do

  context "version" do
    it "exposes a version" do
      expect(ScrabbleWithFriends::VERSION).to eq("0.9.0")
    end
  end

end
