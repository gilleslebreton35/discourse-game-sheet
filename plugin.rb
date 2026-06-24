# frozen_string_literal: true

# name: discourse-game-sheet
# about: Create board game topics from BGG + DeepL
# version: 0.2
# authors: Gilles
# url: https://github.com/gilleslebreton35/discourse-game-sheet

enabled_site_setting :game_sheet_enabled

# Ajoute l'onglet dans le panneau d'administration
add_admin_route "game_sheet.title", "game-sheet"

module ::DiscourseGameSheet
  PLUGIN_NAME = "discourse-game-sheet"
end

after_initialize do
  # 1. Définition essentielle de l'Engine Rails
  module ::DiscourseGameSheet
    class Engine < ::Rails::Engine
      engine_name "discourse_game_sheet"
      isolate_namespace DiscourseGameSheet
    end
  end

  # 2. Chargement des services et du contrôleur
  require_relative "app/services/discourse_game_sheet/bgg_client"
  require_relative "app/services/discourse_game_sheet/deepl_client"
  require_relative "app/services/discourse_game_sheet/topic_builder"
  require_relative "app/controllers/discourse_game_sheet/game_sheet_controller"

  # 3. Chargement de tes routes personnalisées (une fois l'Engine bien en place)
  require_relative "config/routes"

  # 4. Injection des routes dans l'application principale Discourse
  Discourse::Application.routes.append do
    get "/admin/plugins/game-sheet" => "admin/plugins#index", constraints: StaffConstraint.new
    mount ::DiscourseGameSheet::Engine, at: "/game-sheet"
  end
end
