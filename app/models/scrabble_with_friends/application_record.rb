module ScrabbleWithFriends
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.hash_id_salt
      # Override this if you want
      "scrabble_with_friends"
    end

    def self.hash_id_length
      # Override this if you want
      8
    end

    def self.generate_public_id(id)
      salt = self.hash_id_salt
      pepper = self.table_name

      Hashids.new(
        "#{salt}_#{pepper}",
        self.hash_id_length,
      ).encode(id)
    end
  end
end
