module ScrabbleWithFriends
  class Config
    attr_accessor :web_push_vapid_public_key, :web_push_vapid_private_key

    def web_push_enabled?
      web_push_vapid_public_key.present? && web_push_vapid_private_key.present?
    end
  end
end
