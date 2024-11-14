module ScrabbleWithFriends
  class PwaController < ApplicationController
    skip_forgery_protection

    def service_worker
      render template: "scrabble_with_friends/pwa/service-worker", layout: false
    end

    def manifest
      render template: "scrabble_with_friends/pwa/manifest", layout: false
    end
  end
end
