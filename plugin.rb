# name: discourse-game-sheet
# about: Crée des fiches de jeux de société via BGG et DeepL
# version: 2.0.0
# authors: Ton Nom
# url: https://github.com/ton-pseudo/discourse-game-sheet

# On commente ceci temporairement pour forcer Discourse à charger le JS du plugin
# enabled_site_setting :game_sheet_enabled

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

  # On ne met PLUS de route pour /game-sheet ici, Rails laissera Discourse gérer le catch-all
  Discourse::Application.routes.append do
    mount ::DiscourseGameSheet::Engine, at: "/game-sheet-api"
  end
end
