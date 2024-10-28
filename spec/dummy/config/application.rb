require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require "scrabble_with_friends"

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    if Rails::VERSION::STRING.to_f >= 5.1
      config.load_defaults(Rails::VERSION::STRING.to_f)
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.eager_load = true ### to catch more bugs in development/test environments

    if Rails.env.development?
      ScrabbleWithFriends.config.web_push_vapid_public_key = "BBj2BQJdncdLjKbnYqWue5KffyeGlidA1Bt1YBR8ecEn-IIwVVt1ybD61YWtEgNykbEAuJhMJENVLj1GDDu71V8".freeze
      ScrabbleWithFriends.config.web_push_vapid_private_key = "sqqwmD4JEb9pjB29NHqwBOnj2bmQ_wyY-DmO9lO2XTk=".freeze
    end
  end
end
