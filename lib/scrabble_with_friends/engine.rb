require 'slim'
require 'hashids'
require "web-push"

module ScrabbleWithFriends
  class Engine < ::Rails::Engine
    isolate_namespace ScrabbleWithFriends

    initializer "scrabble_with_friends.assets.precompile" do |app|
      # this initializer is only called when sprockets is in use

      app.config.assets.precompile << "scrabble_with_friends_manifest.js" ### manifest file required
      app.config.assets.precompile << "scrabble_with_friends/favicon.ico"
      app.config.assets.precompile << "rails-ujs" # provided by activesupport

      ### Automatically precompile assets in specified folders
      ["app/assets/images/"].each do |folder|
        dir = app.root.join(folder)

        if Dir.exist?(dir)
          Dir.glob(File.join(dir, "**/*")).each do |f|
            asset_name = f.to_s
              .split(folder).last # Remove fullpath
              .sub(/^\/*/, '') ### Remove leading '/'

            app.config.assets.precompile << asset_name
          end
        end
      end
    end

    initializer "scrabble_with_friends.load_static_assets" do |app|
      ### Expose static assets
      app.middleware.use ::ActionDispatch::Static, "#{root}/public"
    end

  end
end
