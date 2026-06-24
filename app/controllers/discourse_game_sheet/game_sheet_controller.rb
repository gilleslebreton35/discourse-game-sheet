# frozen_string_literal: true

module DiscourseGameSheet
  class GameSheetController < ::ApplicationController
    before_action :ensure_admin # Sécurité d'accès au niveau du contrôleur

    # GET /game-sheet/search?q=catan
    def search
      params.require(:q)
      
      # On appelle ton client BGG
      data = DiscourseGameSheet::BggClient.search(params[:q])
      
      # Ton client renvoie { results: [...] }, on le transmet directement au Javascript
      render json: data
    end

    # GET /game-sheet/details?id=123
    def details
      params.require(:id)
      
      begin
        # Utilisation de la méthode "game" de ton client
        game_details = DiscourseGameSheet::BggClient.game(params[:id])
        render json: game_details 
      rescue StandardError => e
        render_json_error "Erreur BGG : #{e.message}", status: 422
      end
    end

    # POST /game-sheet/create-topic
    def create_topic
      clean_params = params.permit(:game_id, :category_id, selected_images: [])
      
      clean_params.require(:game_id)
      clean_params.require(:category_id)

      begin
        # Utilisation de la méthode "game" de ton client
        game = DiscourseGameSheet::BggClient.game(clean_params[:game_id])
      rescue StandardError
        return render_json_error "Jeu introuvable sur BoardGameGeek.", status: 404
      end

      # Construction du corps Markdown
      raw_body = String.new
      
      # 1. Injection des illustrations
      if clean_params[:selected_images].present?
        raw_body << "<div class='bgg-topic-gallery'>\n\n"
        clean_params[:selected_images].each do |img_url|
          raw_body << "![Illustration](#{img_url})\n\n"
        end
        raw_body << "</div>\n\n"
      end

      # 2. Injection de la fiche technique
      raw_body << "## #{game[:name]}\n\n"
      raw_body << "* **Année :** #{game[:yearpublished]}\n"
      raw_body << "* **Joueurs :** #{game[:minplayers]} à #{game[:maxplayers]}\n"
      raw_body << "* **Durée :** #{game[:playingtime]} minutes\n"
      raw_body << "* **Âge minimum :** #{game[:minage]} ans\n\n"
      raw_body << "### Description\n\n"
      
      raw_body << Search.clean_html(game[:description])

      # 3. Création du Post
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
  end
end
