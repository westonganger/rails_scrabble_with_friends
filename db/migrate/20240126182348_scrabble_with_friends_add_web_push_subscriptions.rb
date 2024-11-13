class ScrabbleWithFriendsAddWebPushSubscriptions < ActiveRecord::Migration[6.0]
  def change
    create_table :scrabble_with_friends_web_push_subscriptions do |t|
      t.string :auth, :p256dh, :endpoint, null: false
      t.references :game, null: false
      t.references :player, null: false
    end
  end
end
