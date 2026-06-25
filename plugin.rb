# name: discourse-game-sheet
# about: Crée des fiches de jeux de société via BGG et DeepL
# version: 2.0.0
# authors: Ton Nom
# url: https://github.com/ton-pseudo/discourse-game-sheet

enabled_site_setting :game_sheet_enabled

# register_asset "stylesheets/game-sheet.scss" # Commenté pour éviter l'erreur de compilation au rebuild

after_initialize do
  module ::DiscourseGameSheet
    class Engine < ::Rails::Engine
      engine_name "discourse_game_sheet"
      isolate_namespace DiscourseGameSheet
    end
  end

  # Chargement des fichiers manuellement
  load File.expand_path("../app/services/discourse_game_sheet/bgg_client.rb", __FILE__)
  load File.expand_path("../app/services/discourse_game_sheet/deepl_client.rb", __FILE__)
  load File.expand_path("../app/controllers/discourse_game_sheet/game_sheet_controller.rb", __FILE__)

  DiscourseGameSheet::Engine.routes.draw do
    get "/search" => "game_sheet#search"
    get "/details" => "game_sheet#details"
    post "/create-topic" => "game_sheet#create_topic"
  end

  # On dit à Discourse : 
  # 1. De charger la coquille vide pour /game-sheet (Ember prendra le relais pour l'affichage)
  # 2. De monter notre API backend sous /game-sheet-api
  Discourse::Application.routes.append do
    get "/game-sheet" => "default#empty"
    mount ::DiscourseGameSheet::Engine, at: "/game-sheet-api"
  end
end
