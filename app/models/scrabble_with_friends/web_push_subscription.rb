module ScrabbleWithFriends
  class WebPushSubscription < ApplicationRecord
    validates :endpoint, presence: true
    validates :p256dh, presence: true
    validates :auth, presence: true

    validates :game_id, presence: true
    validates :username, presence: true

    def send_push_notification(data)
      ### Example
      # data = {
      #   title: push_notification.title,
      #   body: push_notification.body,
      #   icon: ActionController::Base.helpers.image_url("note.png"),
      # }

      WebPush.payload_send(
        message: JSON.generate(data),
        endpoint: self.endpoint,
        p256dh: self.p256dh,
        auth: self.auth,
        vapid: VAPID_DETAILS,
      )
    end

    VAPID_DETAILS = {
      subject: "mailto:#{ENV['VAPID_EMAIL']}",
      public_key: ENV["VAPID_SERVER_KEY"],
      private_key: ENV["VAPID_PRIVATE_KEY"],
    }.freeze
  end
end
