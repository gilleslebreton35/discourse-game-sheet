# name: discourse-game-sheet
# about: Crée des fiches de jeux de société via BGG et DeepL
# version: 2.0.0
# authors: Ton Nom
# url: https://github.com/ton-pseudo/discourse-game-sheet

# Ce paramètre lie ton plugin à la configuration active dans l'admin
enabled_site_setting :game_sheet_enabled

# Enregistrement de la feuille de style
register_asset "stylesheets/game-sheet.scss"

after_initialize do
  # 1. Définition du module pour l'API
  module ::DiscourseGameSheet
    class Engine < ::Rails::Engine
      engine_name "discourse_game_sheet"
      isolate_namespace DiscourseGameSheet
    end
  end

  # 2. Chargement des fichiers serveurs
  load File.expand_path("../app/services/discourse_game_sheet/bgg_client.rb", __FILE__)
  load File.expand_path("../app/services/discourse_game_sheet/deepl_client.rb", __FILE__)
  load File.expand_path("../app/controllers/discourse_game_sheet/game_sheet_controller.rb", __FILE__)

  # 3. Routes de l'API (montées sous /game-sheet-api/...)
  DiscourseGameSheet::Engine.routes.draw do
    get "/search" => "game_sheet#search"
    get "/details" => "game_sheet#details"
    post "/create-topic" => "game_sheet#create_topic"
  end

  # 4. Route principale (SPA)
  # 'list#index' est le contrôleur standard qui charge l'application Ember (Discourse).
  # Ensuite, ton routeur Ember prendra le relais pour afficher ton composant.
  Discourse::Application.routes.append do
    get "/game-sheet" => "list#index"
    mount ::DiscourseGameSheet::Engine, at: "/game-sheet-api"
  end
end
