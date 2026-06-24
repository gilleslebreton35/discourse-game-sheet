# frozen_string_literal: true

module ::DiscourseGameSheet
  class GameSheetController < ::ApplicationController
    requires_plugin DiscourseGameSheet::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_enabled

    # Recherche de jeux (accessible à tous les membres connectés)
    def search
      term = (params[:query] || params[:q]).to_s.strip
      raise Discourse::InvalidParameters.new(:query) if term.blank?

      result = DiscourseGameSheet::BggClient.search(term)
      render json: result
    end

    # Récupération des détails d'un jeu
    def game
      id = params.require(:id).to_s
      result = DiscourseGameSheet::BggClient.game(id)
      render json: result
    end

    # Création du sujet avec les choix de l'utilisateur
    def create_topic
      category_id = params.require(:category_id).to_i
      category = Category.find_by(id: category_id)
      raise Discourse::InvalidParameters.new(:category_id) if category.blank?

      # Vérification de sécurité native : l'utilisateur a-t-il le droit de poster ici ?
      guardian.ensure_can_create_topic!(category)

      # Récupération des données brutes depuis BGG pour des raisons de sécurité (évite l'injection de markdown)
      game_id = params.require(:game_id).to_s
      game = DiscourseGameSheet::BggClient.game(game_id)
      raise Discourse::InvalidParameters.new(:game_id) if game.blank?

      # Traduction via DeepL (uniquement la description/champs textuels)
      translated = translate_game(game)

      # Récupération des listes filtrées par l'utilisateur depuis le front-end
      selected_images = params[:selected_images] || []
      selected_videos = params[:selected_videos] || []

      # Création du sujet via le TopicBuilder en lui passant TOUTES les billes
      result = DiscourseGameSheet::TopicBuilder.create!(
        current_user: current_user,
        game: game,
        translated: translated,
        category_id: category_id,
        selected_images: selected_images,
        selected_videos: selected_videos
      )

      render json: success_json.merge(
        topic_id: result.topic.id,
        topic_url: result.topic.relative_url
      )
    rescue => e
      Rails.logger.warn("[discourse-game-sheet] create_topic error: #{e.class} #{e.message}")
      render_json_error(e.message)
    end

    private

    def ensure_enabled
      raise Discourse::InvalidAccess.new unless SiteSetting.game_sheet_enabled
    end

    def translate_game(game)
      api_key = SiteSetting.game_sheet_deepl_api_key.to_s.strip
      return game if api_key.blank?

      # Utilise le code de langue cible ou 'FR' par défaut
      target_lang = SiteSetting.try(:game_sheet_target_locale) || "FR"

      DiscourseGameSheet::DeeplClient.translate_game(
        game,
        api_key: api_key,
        target_lang: target_lang
      )
    end
  end
end
