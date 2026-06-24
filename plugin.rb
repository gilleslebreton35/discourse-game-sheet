# frozen_string_literal: true

# name: discourse-game-sheet
# about: Create board game topics from BGG + DeepL
# version: 0.3
# authors: Gilles
# url: https://github.com/gilleslebreton35/discourse-game-sheet

enabled_site_setting :game_sheet_enabled

register_asset "stylesheets/common/game-sheet.scss"

after_initialize do
  require_relative "app/services/discourse_game_sheet/bgg_client"
  require_relative "app/services/discourse_game_sheet/deepl_client"
  require_relative "app/services/discourse_game_sheet/topic_builder"
  require_relative "app/controllers/discourse_game_sheet/game_sheet_controller"

  Discourse::Application.routes.prepend do
    # Route pour la page principale (accessible aux membres connectés)
    get "/game-sheet" => "discourse_game_sheet/game_sheet#index"
    
    # Routes API (accessibles aux membres connectés)
    get "/game-sheet/search" => "discourse_game_sheet/game_sheet#search", defaults: { format: :json }
    get "/game-sheet/game/:id" => "discourse_game_sheet/game_sheet#game", defaults: { format: :json }
    post "/game-sheet/create-topic" => "discourse_game_sheet/game_sheet#create_topic", defaults: { format: :json }
  end
end
