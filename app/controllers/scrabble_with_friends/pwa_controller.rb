module ScrabbleWithFriends
  class PwaController < ApplicationController
    skip_forgery_protection

    def service_worker
      if !ScrabbleWithFriends.config.web_push_enabled?
        render_404
        return
      end

      render template: "pwa/service-worker", layout: false
    end

    def manifest
      if !ScrabbleWithFriends.config.web_push_enabled?
        render_404
        return
      end

      render template: "pwa/manifest", layout: false
    end
  end
end
