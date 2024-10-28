class ScrabbleWithFriendsAddWebPushSubscriptions < ActiveRecord::Migration[6.0]
  def change
    create_table :scrabble_with_friends_web_push_subscriptions do |t|
      t.string :auth, :p256dh, :endpoint
      t.references :game
      t.references :player
    end
  end
end
