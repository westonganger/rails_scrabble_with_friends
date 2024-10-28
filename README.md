# Rails Scrabble With Friends

<a href='https://github.com/westonganger/rails_scrabble_with_friends/actions' target='_blank'><img src="https://github.com/westonganger/rails_scrabble_with_friends/actions/workflows/test.yml/badge.svg?branch=master" style="max-width:100%;" height='21' style='border:0px;height:21px;' border='0' alt="CI Status"></a>

Simple web-based scrabble for you and your friends with zero friction authentication.

Features:
- Zero friction authentication
- Fully usable on Mobile and Desktop
- Does not attempt to validate or spellcheck any words for you. You are provided a simple search input which links to a dictionary.

## Screenshots

<img src="/screenshots/screenshot_desktop.png" alt="Screenshot: Desktop" width="500px" /> <img src="/screenshots/screenshot_mobile.png" alt="Screenshot: Mobile" width="200px" align="top" />

<img src="/screenshots/screenshot_sign_in.png" alt="Screenshot: Sign In" width="500px" />

<img src="/screenshots/screenshot_start_new_game.png" alt="Screenshot: Start New Game" width="500px" />

<img src="/screenshots/screenshot_games_index.png" alt="Screenshot: Find or create game" width="500px" />

<img src="/screenshots/screenshot_waiting_to_start_game.png" alt="Screenshot: Waiting to Start Game" width="500px" />


## Demo / Play

Demo or play at https://scrabble.westonganger.com

## How Authentication Works

Authentication is designed to be zero friction and works as follows:

1. User chooses any username
2. Username is stored in session
3. User can then create or join any game given a Game ID or Game Name

## Setup

Developed as a Rails engine. So you can add to any existing app or create a brand new app with the functionality.

First add the gem to your Gemfile

```ruby
### Gemfile
gem "scrabble_with_friends", git: "https://github.com/westonganger/scrabble_with_friends.git"
```

Then install and run the database migrations

```sh
bundle install
bundle exec rake scrabble_with_friends:install:migrations
bundle exec rake db:migrate
```

#### Option A: Mount as a subdomain

```ruby
### config/routes.rb

scrabble_with_friends_subdomain = "scrabble_with_friends"

mount ScrabbleWithFriends::Engine,
  at: "/", as: "scrabble_with_friends",
  constraints: Proc.new{|request| request.subdomain == scrabble_with_friends_subdomain }

not_engine = Proc.new{|request| request.subdomain != scrabble_with_friends_subdomain }

constraints not_engine do
  # your app routes here...
end
```

#### Option B: Mount to a path

```ruby
### config/routes.rb

### As sub-path
mount ScrabbleWithFriends::Engine, at: "/scrabble_with_friends", as: "scrabble_with_friends"

### OR as root-path
mount ScrabbleWithFriends::Engine, at: "/", as: "scrabble_with_friends"
```

## Web push notifications

Web push notifications are available and can be enabled by setting the vapid public/private keys in the config

```
# config/initializers/scrabble_with_friends.rb

ScrabbleWithFriends.config do |config|
  config.web_push_vapid_public_key = "some-vapid-public-key"
  config.web_push_vapid_private_key = "some-vapid-private-key"
end
```

You can generate the web_push vapid keys using the following:

```
require 'web-push'

generated_vapid_key = WebPush.generate_key

public_key = generated_vapid_key.public_key.delete("=")
# => "BC1mp...HQ"

private_key = generated_vapid_key.private_key
# => "XhGUr...Kec"
```

## Development

Run migrations using: `rails db:migrate`

Run server using: `bin/dev` or `rails s`

## Testing

```
bundle exec rspec
```

We can locally test different versions of Rails using `ENV['RAILS_VERSION']`

```
export RAILS_VERSION=7.0
bundle install
bundle exec rspec
```

# Credits

Created & Maintained by [Weston Ganger](https://westonganger.com) - [@westonganger](https://github.com/westonganger)
