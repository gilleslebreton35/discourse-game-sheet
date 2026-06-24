# frozen_string_literal: true

# name: discourse-game-sheet
# about: Create board game topics from BGG + DeepL
# version: 0.2
# authors: Gilles
# url: https://github.com/gilleslebreton35/discourse-game-sheet

enabled_site_setting :game_sheet_enabled

# Ajoute l'onglet dans le panneau d'administration
add_admin_route "game_sheet.title", "game-sheet"

# 1. Définition essentielle de l'Engine Rails (EN DEHORS DU after_initialize)
module ::DiscourseGameSheet
  PLUGIN_NAME = "discourse-game-sheet"

  class Engine < ::Rails::Engine
    engine_name "discourse_game_sheet"
    isolate_namespace DiscourseGameSheet
  end
end

after_initialize do
  # 2. Chargement de tes services et de ton contrôleur
  require_relative "app/services/discourse_game_sheet/bgg_client"
  require_relative "app/services/discourse_game_sheet/deepl_client"
  require_relative "app/services/discourse_game_sheet/topic_builder"
  require_relative "app/controllers/discourse_game_sheet/game_sheet_controller"

  # 3. Injection de la route de l'onglet admin
  Discourse::Application.routes.append do
    get "/admin/plugins/game-sheet" => "admin/plugins#index", constraints: StaffConstraint.new
  end
end
