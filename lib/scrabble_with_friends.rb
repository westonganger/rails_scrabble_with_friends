require "scrabble_with_friends/engine"
require "scrabble_with_friends/config"

module ScrabbleWithFriends
  @@config = Config.new

  def self.config(&block)
    if block_given?
      block.call(@@config)
    else
      return @@config
    end
  end

  APP_NAME = "Scrabble With Friends".freeze
  DESCRIPTION = "Simple web-based scrabble".freeze
end
