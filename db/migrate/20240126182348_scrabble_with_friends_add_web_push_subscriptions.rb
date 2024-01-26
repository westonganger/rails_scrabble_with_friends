class ScrabbleWithFriendsAddWebPushSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :web_push_subscriptions do |t|
      t.string :auth, :p256dh, :endpoint

      t.references :game
      t.string :username
    end
  end
end
