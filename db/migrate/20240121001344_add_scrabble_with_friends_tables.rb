class AddScrabbleWithFriendsTables < ActiveRecord::Migration[6.0]
  def change
    create_table :scrabble_with_friends_games do |t|
      t.string :public_id, index: true, unique: true
      t.string :name
      t.timestamps
    end

    create_table :scrabble_with_friends_players do |t|
      t.references :game, null: false
      t.string :username, unique: [:game_id], null: false
      t.boolean :forfeitted, default: false, null: false
      t.json :tiles
      t.integer :score, null: false, default: 0
      t.timestamps
    end

    create_table :scrabble_with_friends_turns do |t|
      t.references :game, null: false
      t.references :player, null: false
      t.json :tiles_played, null: false
      t.boolean :forfeitted, default: false, null: false
      t.integer :score, null: false
      t.timestamps
    end
  end
end
