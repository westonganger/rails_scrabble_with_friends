ScrabbleWithFriends::Engine.routes.draw do
  get :sign_in, to: "sessions#sign_in"
  post :sign_in, to: "sessions#sign_in"
  get :sign_out, to: "sessions#sign_out"

  resources :games, controller: :games, except: [:edit, :update] do
    member do
      post :restart

      post :forfeit
      post :validate_turn
      post :take_turn
      post :undo_turn

      post :add_player
      post :remove_player
    end
  end

  get '/robots', to: 'application#robots', constraints: ->(req){ req.format == :text }

  match '*a', to: 'application#render_404', via: :get

  get "/", to: "games#index"

  root "games#index"
end
