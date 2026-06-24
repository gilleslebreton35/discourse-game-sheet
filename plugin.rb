# frozen_string_literal: true

# name: discourse-game-sheet
# about: Create board game topics from BGG + DeepL
# version: 0.2
# authors: Gilles
# url: https://github.com/gilleslebreton35/discourse-game-sheet

enabled_site_setting :game_sheet_enabled

# Ajoute l'onglet dans le panneau d'administration
add_admin_route "game_sheet.title", "game-sheet"

after_initialize do
  # 1. Chargement de tes services et de ton contrôleur
  require_relative "app/services/discourse_game_sheet/bgg_client"
  require_relative "app/services/discourse_game_sheet/deepl_client"
  require_relative "app/services/discourse_game_sheet/topic_builder"
  require_relative "app/controllers/discourse_game_sheet/game_sheet_controller"

  # 2. Injection directe de TOUTES les routes dans l'application Discourse
  Discourse::Application.routes.append do
    # Route pour l'affichage du panneau dans l'administration
    get "/admin/plugins/game-sheet" => "admin/plugins#index", constraints: StaffConstraint.new

    # Routes de l'API pour ton script JavaScript (Accessibles uniquement par le staff)
    get "/game-sheet/search" => "discourse_game_sheet/game_sheet#search", constraints: StaffConstraint.new
    get "/game-sheet/details" => "discourse_game_sheet/game_sheet#details", constraints: StaffConstraint.new
    post "/game-sheet/create-topic" => "discourse_game_sheet/game_sheet#create_topic", constraints: StaffConstraint.new
  end
end
