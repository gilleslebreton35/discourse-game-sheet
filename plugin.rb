# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux
# version: 0.1
# authors: Toi
# url: https://...

enabled_site_setting :game_sheet_enabled

after_initialize do
  require_dependency "application_controller"

  class ::GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"
    before_action :ensure_logged_in
    before_action :ensure_allowed_group, except: [:index]

    # La méthode index est cruciale pour afficher le layout Discourse
    def index
      render html: "", layout: true
    end

    def search
      params.require(:q)
      render json: DiscourseGameSheet::BggClient.search(params[:q])
    end

    def details
      params.require(:id)
      data = DiscourseGameSheet::BggClient.game_details(params[:id])
      data[:description_fr] = DiscourseGameSheet::DeeplClient.translate(data[:description])
      render json: data
    end

    def create_topic
      p = params.permit(:game_id, :category_id, :include_image, selected_videos: [])
      p.require([:game_id, :category_id])

      game = DiscourseGameSheet::BggClient.game_details(p[:game_id])
      game[:description_fr] = DiscourseGameSheet::DeeplClient.translate(game[:description])

      raw_body = String.new
      if p[:include_image] == "true" && game[:image].present?
        raw_body << "![#{game[:name]}](#{game[:image]})\n\n"
      end

      raw_body << "### Description\n#{Search.clean_html(game[:description_fr])}\n\n"
      raw_body << "### Informations Techniques\n"
      raw_body << "* **Année de sortie :** #{game[:yearpublished]}\n"
      raw_body << "* **Nombre de joueurs :** #{game[:minplayers]} à #{game[:maxplayers]}\n"
      raw_body << "* **Durée d'une partie :** #{game[:playingtime]} minutes\n"
      raw_body << "* **Âge recommandé :** #{game[:minage]}+\n\n"

      if p[:selected_videos].present?
        raw_body << "### Vidéos Sélectionnées\n"
        p[:selected_videos].each { |v| raw_body << "#{v}\n" }
      end

      post_creator = PostCreator.new(
        current_user,
        title: "Fiche de jeu : #{game[:name]}",
        raw: raw_body,
        category: p[:category_id],
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

    def ensure_allowed_group
      allowed_group = SiteSetting.game_sheet_allowed_group
      return if current_user.staff?
      if allowed_group.present?
        group = Group.find_by(name: allowed_group)
        if group.blank? || !group.users.where(id: current_user.id).exists?
          raise Discourse::InvalidAccess.new("Cet espace est réservé aux abonnés.")
        end
      end
    end
  end

  Discourse::Application.routes.append do
    get "/game-sheet" => "game_sheet#index"
    
    # Routes API
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    post "/game-sheet-api/create_topic" => "game_sheet#create_topic"
  end
end
