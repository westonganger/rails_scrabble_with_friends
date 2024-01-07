require_dependency "scrabble_with_friends/application_controller"

module ScrabbleWithFriends
  class SessionsController < ApplicationController

    def sign_in
      if request.method == "GET"
        if signed_in?
          redirect_to games_path
        end

      elsif request.method == "POST"
        if params[:honeypot] != "the-expected-value" && !Rails.env.test?
          raise "Bot login prevented"
        end

        if params[:username]
          session[:scrabble_with_friends_username] = params[:username].downcase.strip

          path = session.delete(:scrabble_with_friends_return_to).presence || games_path
          redirect_to path
        end
      end
    end

    def sign_out
      if !signed_in?
        redirect_to action: :sign_in
      else
        session.delete(:scrabble_with_friends_username)
        flash.notice = "Signed out"
        redirect_to sign_in_path
      end
    end

  end
end
