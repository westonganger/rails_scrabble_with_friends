module ScrabbleWithFriends
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    helper_method :signed_in?
    helper_method :current_username

    before_action do
      Current.username = session[:scrabble_with_friends_username].presence
    end

    def robots
      str = <<~STR
        User-agent: *
        Disallow: /
      STR

      render plain: str, layout: false, content_type: 'text/plain'
    end

    def render_404
      if request.format.html?
        render "scrabble_with_friends/exceptions/show", status: 404
      else
        render plain: "404 Not Found", status: 404
      end
    end

    private

    def signed_in?
      Current.username.present?
    end

    def current_username
      Current.username
    end

  end
end
