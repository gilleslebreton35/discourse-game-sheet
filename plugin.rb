# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux
# version: 0.1
# authors: Toi

enabled_site_setting :game_sheet_enabled

after_initialize do
  require_dependency "application_controller"

  # Structure du module pour tes services API
  module DiscourseGameSheet
    class BggClient
      def self.search(query)
        # REMPLACE CE CODE PAR TA LOGIQUE BGG (Faraday, XML, etc.)
        { bgg: [{ id: 1, name: "Catan (Test)", thumbnail: "", yearpublished: "1995" }] }
      end

      def self.game_details(id)
        # REMPLACE CE CODE PAR TA LOGIQUE BGG
        { id: id, name: "Catan", description: "Jeu de stratégie...", image: "", minplayers: 3, maxplayers: 4, playingtime: 60, minage: 10 }
      end
    end

    class DeeplClient
      def self.translate(text)
        # REMPLACE CE CODE PAR TA LOGIQUE DEEPL
        text
      end
    end
  end

  class ::GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"
    before_action :ensure_logged_in
    before_action :ensure_allowed_group, except: [:index]

    def index
      render html: "", layout: true
    end

    def search
      begin
        params.require(:q)
        render json: DiscourseGameSheet::BggClient.search(params[:q])
      rescue => e
        render_error(e)
      end
    end

    def details
      begin
        params.require(:id)
        data = DiscourseGameSheet::BggClient.game_details(params[:id])
        data[:description_fr] = DiscourseGameSheet::DeeplClient.translate(data[:description])
        render json: data
      rescue => e
        render_error(e)
      end
    end

    def create_topic
      begin
        p = params.permit(:game_id, :category_id, :include_image, selected_videos: [])
        p.require([:game_id, :category_id])

        game = DiscourseGameSheet::BggClient.game_details(p[:game_id])
        game[:description_fr] = DiscourseGameSheet::DeeplClient.translate(game[:description])

        raw_body = "### Description\n#{game[:description_fr]}\n\n"
        # ... (ajoute ici le reste de ta logique de formatage)

        post_creator = PostCreator.new(current_user, title: "Fiche de jeu : #{game[:name]}", raw: raw_body, category: p[:category_id], skip_validations: true)
        post = post_creator.create

        if post_creator.errors.present?
          render json: { error: post_creator.errors.full_messages.join(", ") }, status: 422
        else
          render json: { topic_url: post.topic.url }
        end
      rescue => e
        render_error(e)
      end
    end

    private

    def render_error(e)
      Rails.logger.error("#{e.class}: #{e.message}")
      render json: { error: e.message }, status: 500
    end

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
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
  end
end
