# frozen_string_literal: true

module DiscourseGameSheet
  class GameSheetController < ::ApplicationController
    before_action :ensure_logged_in

    # GET /game-sheet/search?q=catan
    def search
      params.require(:q)

      data = DiscourseGameSheet::BggClient.search(params[:q])
      render json: data
    end
    # GET /game-sheet/game/123
    def game
      id = params.require(:id)

      begin
        game_details = DiscourseGameSheet::BggClient.game(id)

        # Ajouter les images supplémentaires
        game_details[:images] = fetch_additional_images(game_details)

        # Traduire si DeepL est configuré
        api_key = SiteSetting.game_sheet_deepl_api_key.to_s.strip
        if api_key.present?
          target_lang = SiteSetting.try(:game_sheet_target_locale) || "FR"
          game_details = DiscourseGameSheet::DeeplClient.translate_game(
            game_details,
            api_key: api_key,
            target_lang: target_lang
          )
        end

        render json: game_details
      rescue StandardError => e
        render_json_error "Erreur BGG : #{e.message}", status: 422
      end
    end

    # POST /game-sheet/create-topic
    def create_topic
      clean_params = params.permit(:game_id, :category_id, selected_images: [], selected_videos: [])

      clean_params.require(:game_id)
      clean_params.require(:category_id)

      begin
        game = DiscourseGameSheet::BggClient.game(clean_params[:game_id])
      rescue StandardError
        return render_json_error "Jeu introuvable sur BoardGameGeek.", status: 404
      end

      # Construction du corps Markdown
      raw_body = String.new

      # 1. Injection des illustrations sélectionnées
      if clean_params[:selected_images].present?
        raw_body << "<div class='bgg-topic-gallery'>\n\n"
        clean_params[:selected_images].each do |img_url|
          raw_body << "![Illustration](#{img_url})\n\n"
        end
        raw_body << "</div>\n\n"
      end

      # 2. Traduction si DeepL configuré
      api_key = SiteSetting.game_sheet_deepl_api_key.to_s.strip
      if api_key.present?
        target_lang = SiteSetting.try(:game_sheet_target_locale) || "FR"
        game = DiscourseGameSheet::DeeplClient.translate_game(
          game,
          api_key: api_key,
          target_lang: target_lang
        )
      end

      # 3. Injection de la fiche technique
      raw_body << "## #{game[:name]}\n\n"
      raw_body << "* **Année :** #{game[:yearpublished]}\n"
      raw_body << "* **Joueurs :** #{game[:minplayers]} à #{game[:maxplayers]}\n"
      raw_body << "* **Durée :** #{game[:playingtime]} minutes\n"
      raw_body << "* **Âge minimum :** #{game[:minage]} ans\n\n"

      if game[:categories].present?
        raw_body << "* **Catégories :** #{game[:categories].join(', ')}\n"
      end
      if game[:mechanics].present?
        raw_body << "* **Mécanismes :** #{game[:mechanics].join(', ')}\n"
      end

      raw_body << "\n### Description\n\n"
      raw_body << Search.clean_html(game[:description].to_s)

      # 4. Création du Post
      post_creator = PostCreator.new(
        current_user,
        title: "Fiche de jeu : #{game[:name]}",
        raw: raw_body,
        category: clean_params[:category_id],
        skip_validations: true
      )
      post = post_creator.create

      if post_creator.errors.present?
        render_json_error post_creator.errors.full_messages.join(", "), status: 422
      else
        render json: { topic_url: post.topic.url }
      end
    end

    private

    def fetch_additional_images(game_details)
      images = []
      images << game_details[:image] if game_details[:image].present?

      # Tentative de récupération d'images supplémentaires via BGG
      begin
        id = game_details[:id]
        uri = URI("https://boardgamegeek.com/xmlapi2/thing?id=#{CGI.escape(id.to_s)}&type=boardgame&versions=1")
        response = DiscourseGameSheet::BggClient.get(uri)
        doc = REXML::Document.new(response.body)

        doc.elements.each("items/item/image") do |img|
          url = img.text.to_s.strip
          images << url if url.present? && !images.include?(url)
        end
      rescue StandardError
        # Silently fail, on a au moins l'image principale
      end

      images.uniq
    end
  end
end
