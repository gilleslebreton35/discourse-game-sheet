# frozen_string_literal: true

# name: discourse-game-sheet
# about: Create board game topics from BGG + DeepL
# version: 0.3
# authors: Gilles
# url: https://github.com/gilleslebreton35/discourse-game-sheet

enabled_site_setting :game_sheet_enabled

register_asset "stylesheets/common/game-sheet.scss"

register_page "game-sheet", {
  route: { path: "/game-sheet" }
}

after_initialize do
  require_relative "app/services/discourse_game_sheet/bgg_client"
  require_relative "app/services/discourse_game_sheet/deepl_client"
  require_relative "app/services/discourse_game_sheet/topic_builder"
  require_relative "app/controllers/discourse_game_sheet/game_sheet_controller"

  Discourse::Application.routes.prepend do
    # Route pour la page principale (accessible aux membres connectés)
    get "/game-sheet" => "discourse_game_sheet/game_sheet#index", constraints: ->(req) { req.session[:current_user_id].present? }
    
    # Routes API (accessibles aux membres connectés)
    get "/game-sheet/search" => "discourse_game_sheet/game_sheet#search", constraints: ->(req) { req.session[:current_user_id].present? }, defaults: { format: :json }
    get "/game-sheet/game/:id" => "discourse_game_sheet/game_sheet#game", constraints: ->(req) { req.session[:current_user_id].present? }, defaults: { format: :json }
    post "/game-sheet/create-topic" => "discourse_game_sheet/game_sheet#create_topic", constraints: ->(req) { req.session[:current_user_id].present? }, defaults: { format: :json }
  end

  # Ajouter un lien dans le menu utilisateur
  add_to_serializer(:current_user, :game_sheet_path) { "/game-sheet" }
end
