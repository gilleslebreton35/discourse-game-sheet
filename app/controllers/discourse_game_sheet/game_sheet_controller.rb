# frozen_string_literal: true

module DiscourseGameSheet
  class GameSheetController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_allowed_group

    def search
      params.require(:q)
      render json: DiscourseGameSheet::BggClient.search(params[:q])
    end

    def details
      params.require(:id)
      data = DiscourseGameSheet::BggClient.game_details(params[:id])
      
      # Traduction magique de la description via DeepL
      data[:description_fr] = DiscourseGameSheet::DeeplClient.translate(data[:description])
      
      render json: data
    end

    def create_topic
      p = params.permit(:game_id, :category_id, :include_image, selected_videos: [])
      p.require([:game_id, :category_id])

      game = DiscourseGameSheet::BggClient.game_details(p[:game_id])
      game[:description_fr] = DiscourseGameSheet::DeeplClient.translate(game[:description])

      # Construction du Markdown du sujet
      raw_body = String.new
      if p[:include_image] == "true" && game[:image].present?
        raw_body << "![#{game[:name]}]({#game[:image]})\n\n"
      end

      raw_body << "### Description\n#{Search.clean_html(game[:description_fr])}\n\n"
      raw_body << "### Informations Techniques\n"
      raw_body << "* **Année de sortie :** #{game[:yearpublished]}\n"
      raw_body << "* **Nombre de joueurs :** #{game[:minplayers]} à #{game[:maxplayers]}\n"
      raw_body << "* **Durée d'une partie :** #{game[:playingtime]} minutes\n"
      raw_body << "* **Âge recommandé :** #{game[:minage]}+\n\n"

      if p[:selected_videos].present?
        raw_body << "### Vidéos Sélectionnées\n"
        p[:selected_videos].each do |video_url|
          raw_body << "#{video_url}\n" # Discourse intègre automatiquement les lecteurs YouTube/Vimeo via l'URL brute
        end
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
      return if current_user.staff? # Les admins/modos ont toujours accès

      if allowed_group.present?
        group = Group.find_by(name: allowed_group)
        if group.blank? || !group.users.where(id: current_user.id).exists?
          raise Discourse::InvalidAccess.new("Cet espace est réservé aux abonnés.")
        end
      end
    end
  end
end
