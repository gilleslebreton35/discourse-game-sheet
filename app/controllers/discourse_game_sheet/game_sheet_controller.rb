# frozen_string_literal: true

module DiscourseGameSheet
  class GameSheetController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_allowed_group

    # GET /game-sheet-api/search?q=…
    def search
      params.require(:q)
      render json: DiscourseGameSheet::BggClient.search(params[:q])
    end

    # GET /game-sheet-api/details?id=…
    def details
      params.require(:id)
      data = DiscourseGameSheet::BggClient.game_details(params[:id])
      data[:description_fr] = DiscourseGameSheet::DeeplClient.translate(data[:description])
      render json: data
    end

    # POST /game-sheet-api/create-topic
    def create_topic
      p = params.permit(:game_id, :category_id, :include_image, selected_videos: [])
      p.require([:game_id, :category_id])

      game = DiscourseGameSheet::BggClient.game_details(p[:game_id])
      game[:description_fr] = DiscourseGameSheet::DeeplClient.translate(game[:description])

      # Description nettoyée (supprime les balises HTML/BBCode de BGG)
      clean_description = CGI.unescapeHTML(game[:description_fr].to_s)
                             .gsub(/&#10;/, "\n")
                             .gsub(/<[^>]+>/, "")
                             .strip

      raw_body = +""

      # ── Image principale ──────────────────────────────────────────────────
      # BUG CORRIGÉ : l'original avait {#game[:image]} au lieu de #{game[:image]}
      if p[:include_image] == "true" && game[:image].present?
        raw_body << "![#{game[:name]}](#{game[:image]})\n\n"
      end

      # ── Description ───────────────────────────────────────────────────────
      raw_body << "### Description\n\n#{clean_description}\n\n"

      # ── Informations techniques ───────────────────────────────────────────
      raw_body << "### Informations techniques\n\n"
      raw_body << "| Critère | Valeur |\n"
      raw_body << "|---|---|\n"
      raw_body << "| **Année de sortie** | #{game[:yearpublished]} |\n"       if game[:yearpublished].present?
      raw_body << "| **Nombre de joueurs** | #{game[:minplayers]}–#{game[:maxplayers]} |\n" if game[:minplayers].present?
      raw_body << "| **Durée d'une partie** | #{game[:playingtime]} min |\n"  if game[:playingtime].present?
      raw_body << "| **Âge recommandé** | #{game[:minage]}+ |\n"              if game[:minage].present?
      raw_body << "\n"

      # ── Vidéos sélectionnées ──────────────────────────────────────────────
      if p[:selected_videos].present?
        raw_body << "### Vidéos\n\n"
        p[:selected_videos].each do |video_url|
          raw_body << "#{video_url}\n\n"
        end
      end

      # ── Création ──────────────────────────────────────────────────────────
      post_creator = PostCreator.new(
        current_user,
        title:             "Fiche de jeu : #{game[:name]}",
        raw:               raw_body,
        category:          p[:category_id],
        skip_validations:  false          # laisser Discourse valider normalement
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
      return if current_user.staff?

      allowed_group = SiteSetting.game_sheet_allowed_group
      return if allowed_group.blank?

      group = Group.find_by(name: allowed_group)
      unless group && group.users.exists?(id: current_user.id)
        raise Discourse::InvalidAccess.new("Cet espace est réservé aux abonnés.")
      end
    end
  end
end
