module ScrabbleWithFriends
  class ApplicationMailer < ActionMailer::Base
    layout 'mailer'

    def game_email(subject:, game_url:, email_addresses:)
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
