module ScrabbleWithFriends
  class PwaController < ApplicationController
    skip_forgery_protection

    before_action do
      if !ScrabbleWithFriends.config.web_push_enabled?
        render_404
      end
    end

    def service_worker
      render template: "scrabble_with_friends/pwa/service-worker", layout: false
    end

    def manifest
      render template: "scrabble_with_friends/pwa/manifest", layout: false
    end
  end
end
