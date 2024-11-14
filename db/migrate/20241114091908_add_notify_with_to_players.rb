class AddNotifyWithToPlayers < ActiveRecord::Migration[6.0]
  def change
    add_column :scrabble_with_friends_players, :notify_with, :string
  end
end
