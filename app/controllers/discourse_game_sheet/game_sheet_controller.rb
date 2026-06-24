# frozen_string_literal: true

module DiscourseGameSheet
  class GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"

    # Vérifier que l'utilisateur est connecté
    before_action :ensure_logged_in

    def index
      render html: "", layout: true
    end

    def search
      params.require(:q)
      result = BggClient.search(params[:q])
      render json: result
    end

    def game
      params.require(:id)
      game_data = BggClient.game(params[:id])
      render json: game_data
    end

    def create_topic
      params.require(:game_id)
      params.require(:category_id)

      game_data = BggClient.game(params[:game_id])

      description_fr = DeeplClient.translate(game_data[:description]) if game_data[:description].present?

      markdown = build_game_markdown(game_data, description_fr, params)

      topic_opts = {
        title: game_data[:name],
        raw: markdown,
        category: params[:category_id].to_i,
        skip_validations: true
      }

      creator = PostCreator.new(current_user, topic_opts)
      post = creator.create

      if post.present?
        render json: { topic_url: post.topic.url }
      else
        render json: { errors: creator.errors.full_messages }, status: 422
      end
    end

    private

    def build_game_markdown(game_data, description_fr, params)
      markdown = ""

      markdown += "![#{game_data[:name]}](#{game_data[:image]})\n\n" if game_data[:image].present?

      markdown += "> **Note BGG :** #{game_data[:rating] || "N/A"} ⭐  \n"
      markdown += "> **Joueurs :** #{game_data[:minplayers] || "?"} - #{game_data[:maxplayers] || "?"}  \n"
      markdown += "> **Durée :** #{game_data[:playingtime] || "?"} min  \n"
      markdown += "> **Âge :** #{game_data[:minage] || "?"}+\n\n"

      markdown += "---\n\n"
      markdown += (description_fr || game_data[:description] || "")
      markdown += "\n\n---\n\n"

      if game_data[:categories].present? && game_data[:categories].any?
        markdown += "**Catégories :** #{game_data[:categories].join(", ")}\n\n"
      end
      if game_data[:mechanics].present? && game_data[:mechanics].any?
        markdown += "**Mécanismes :** #{game_data[:mechanics].join(", ")}\n\n"
      end

      if params[:selected_images].present? && params[:selected_images].any?
        markdown += "## 🖼️ Galerie d'images\n\n"
        params[:selected_images].each do |img_url|
          markdown += "![Image](#{img_url})\n"
        end
        markdown += "\n"
      end

      if params[:selected_videos].present? && params[:selected_videos].any?
        markdown += "## 🎬 Vidéos\n\n"
        params[:selected_videos].each do |video_id|
          markdown += "https://www.youtube.com/watch?v=#{video_id}\n"
        end
        markdown += "\n"
      end

      markdown += "---\n\n"
      markdown += "[📖 Voir la fiche complète sur BoardGameGeek](https://boardgamegeek.com/boardgame/#{params[:game_id]})"

      markdown
    end
  end
end
