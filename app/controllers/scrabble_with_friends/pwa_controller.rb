module ScrabbleWithFriends
  class PwaController < ApplicationController
    skip_forgery_protection

    before_action :authenticate_user!, only: [:update_web_push_subscription]

    def service_worker
      if !request.format.js?
        render_404
        return
      end

      render template: "scrabble_with_friends/pwa/service-worker", layout: false
    end

    def manifest
      if !request.format.json?
        render_404
        return
      end

      render json: {
        "name": ScrabbleWithFriends::APP_NAME,
        "description": ScrabbleWithFriends::DESCRIPTION,
        "icons": [
          {
            "src": "/icon.png",
            "type": "image/png",
            "sizes": "512x512"
          },
          {
            "src": "/icon.png",
            "type": "image/png",
            "sizes": "512x512",
            "purpose": "maskable"
          }
        ],
        "scope": "/",
        "start_url": "/",
        "theme_color": "red",
        "background_color": "red",
        "display": "standalone"
      }
    end

    def update_web_push_subscription
      if !request.format.json?
        render_404
        return
      end

      # Update expired subscriptions, etc.
      # finds subscription by old endpoint and update with new endpoint and keys

      ScrabbleWithFriends::WebPushSubscription
        .find_by!(endpoint: params[:old_endpoint])
        .update!(
          endpoint: params.require(:endpoint),
          p256dh: params.require(:p256dh),
          auth: params.require(:auth),
        )

      head :ok
    end
  end
end
