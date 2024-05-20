module ScrabbleWithFriends
  class ApplicationMailer < ActionMailer::Base
    layout 'mailer'

    def its_your_turn(game_url:, email:)
      subject = "Its your turn to play on your Scrabble with Friends game"

      hostname = game_url.split("://").last.split("/").first

      mail(to: email, subject: subject, from: "no-reply@#{hostname}") do |f|
        f.html do
          <<~STR
            <h2>#{subject}</h2>

            <a href="#{game_url}">#{game_url}</a>
          STR
        end

        f.text do
          <<~STR
            #{subject}

            #{game_url}
          STR
        end
      end
    end

    def game_over(email_addresses:, game_url:, winning_player_username:)
      subject = "#{winning_player_username} has won your Scrabble with Friends game"

      hostname = game_url.split("://").last.split("/").first

      mail(to: email_addresses, subject: subject, from: "no-reply@#{hostname}") do |f|
        f.html do
            <<~STR
            <h2>#{subject}</h2>

            <a href="#{game_url}">#{game_url}</a>
          STR
        end

        f.text do
          <<~STR
            #{subject}

            #{game_url}
          STR
        end
      end
    end

  end
end
