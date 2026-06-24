# frozen_string_literal: true

module DiscourseGameSheet
  class GameSheetController < ::ApplicationController
    before_action :ensure_admin # Sécurité d'accès au niveau du contrôleur

    # GET /game-sheet/search?q=catan
    def search
      params.require(:q)
      
      # TODO: Remplacer par ton vrai appel BGG pour la recherche
      # Exemple : results = BggApiService.search(params[:q])
      
      # En attendant que tu branches BGG, on renvoie un faux résultat pour valider que le lien passe bien :
      render json: { success: true, message: "La route search fonctionne !", query: params[:q] }
    end

    # GET /game-sheet/details?id=123
    def details
      params.require(:id)
      
      # Logique d'interrogation de l'API BGG Thing v2
      game_details = BggApiService.fetch_thing_details(params[:id])
      
      if game_details
        render json: game_details 
      else
        render_json_error "Impossible d'extraire les données depuis BoardGameGeek.", status: 422
      end
    end

    # POST /game-sheet/create-topic
    def create_topic
      # Validation stricte des données entrantes (Strong Parameters)
      clean_params = params.permit(:game_id, :category_id, selected_images: [])
      
      clean_params.require(:game_id)
      clean_params.require(:category_id)

      # Récupération des détails (idéalement mis en cache ou relus)
      game = BggApiService.fetch_thing_details(clean_params[:game_id])
      return render_json_error "Jeu introuvable.", status: 404 if game.blank?

      # Construction du corps Markdown
      raw_body = String.new
      
      # 1. Injection des illustrations sélectionnées en tête d'article
      if clean_params[:selected_images].present?
        raw_body << "<div class='bgg-topic-gallery'>\n\n"
        clean_params[:selected_images].each do |img_url|
          # Correction de la syntaxe d'interpolation Ruby : #{variable}
          raw_body << "![Illustration](#{img_url})\n\n"
        end
        raw_body << "</div>\n\n"
      end

      # 2. Injection de la fiche technique
      raw_body << "## #{game[:name]}\n\n"
      raw_body << "* **Note BGG :** #{game[:rating]}/10\n"
      raw_body << "* **Joueurs :** #{game[:min_players]} à #{game[:max_players]}\n"
      raw_body << "* **Durée :** #{game[:playing_time]} minutes\n\n"
      raw_body << "### Description\n\n"
      
      # Utilisation du helper Discourse pour nettoyer le HTML de BGG avant insertion
      raw_body << Search.clean_html(game[:description])

      # 3. Appel à l'orchestrateur natif Discourse PostCreator
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
