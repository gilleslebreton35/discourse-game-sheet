# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.8
# authors: Toi

enabled_site_setting :game_sheet_enabled

register_site_setting :game_sheet_bgg_api_key, default: "", validator: "NoOptionsValidator"
register_site_setting :game_sheet_allowed_category_ids, default: "", validator: "NoOptionsValidator"

after_initialize do
  require_dependency "application_controller"
  require 'nokogiri'
  require 'net/http'
  require 'uri'
  require 'erb'

  module ::DiscourseGameSheet
    class BggClient
      BASE_URL = "https://boardgamegeek.com/xmlapi2"

      def self.api_key
        SiteSetting.game_sheet_bgg_api_key.presence
      end

      def self.request_bgg(path)
        sleep 1
        uri = URI.parse("#{BASE_URL}/#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Discourse-GameSheet/1.0"
        
        # Ajout du token si présent
        if api_key
          request["Authorization"] = "Bearer #{api_key}"
        end
        
        begin
          response = http.request(request)
          response
        rescue => e
          Rails.logger.error("BGG ERROR: #{e.message}")
          nil
        end
      end

      def self.search(query)
        return { bgg: [] } if query.blank?
        
        begin
          encoded_query = ERB::Util.url_encode(query.to_s.strip)
          resp = request_bgg("search?query=#{encoded_query}&type=boardgame")
          
          if resp.nil? || !resp.is_a?(Net::HTTPSuccess)
             Rails.logger.warn("BGG SEARCH: Erreur réseau ou API - Code: #{resp&.code}")
             return { bgg: [] }
          end

          doc = Nokogiri::XML(resp.body)
          items = doc.xpath('//item')
          
          if items.empty?
            Rails.logger.warn("BGG SEARCH: Aucun item trouvé")
            return { bgg: [] }
          end

          results = items.first(10).map do |item|
            {
              id: item['id'],
              name: item.at_xpath('name')&.[]('value'),
              yearpublished: item.at_xpath('yearpublished')&.[]('value'),
              thumbnail: item.at_xpath('thumbnail')&.text
            }
          end
          { bgg: results }
        rescue => e
          Rails.logger.error("BGG SEARCH CRASH: #{e.message}")
          { bgg: [] }
        end
      end

      def self.game_details(id)
        resp = request_bgg("thing?id=#{id}&stats=1")
        return { error: "Non trouvé" } if resp.nil? || !resp.is_a?(Net::HTTPSuccess)
        
        doc = Nokogiri::XML(resp.body)
        item = doc.at_xpath('//item')
        return { error: "Non trouvé" } unless item
        
        {
          id: id,
          name: item.at_xpath('name')&.[]('value'),
          description: item.at_xpath('description')&.text&.gsub(/&amp;/, '&')&.gsub(/&quot;/, '"'),
          image: item.at_xpath('image')&.text,
          minplayers: item.at_xpath('minplayers')&.[]('value'),
          maxplayers: item.at_xpath('maxplayers')&.[]('value'),
          playingtime: item.at_xpath('playingtime')&.[]('value'),
          minage: item.at_xpath('minage')&.[]('value'),
          images: [],
          videos: []
        }
      end
    end
  end

  class ::GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"
    before_action :ensure_logged_in

    def index
      render html: "", layout: true
    end

    def search
      render json: DiscourseGameSheet::BggClient.search(params[:q])
    end

    def details
      render json: DiscourseGameSheet::BggClient.game_details(params[:id])
    end

    def categories
      allowed_ids = SiteSetting.game_sheet_allowed_category_ids.split('|').map(&:to_i)
      render json: Category.where(id: allowed_ids).map { |c| { id: c.id, name: c.name } }
    end

    def create_topic
      game = DiscourseGameSheet::BggClient.game_details(params[:game_id])
      return render json: { error: game[:error] }, status: 400 if game[:error]
      
      raw = String.new
      
      if params[:include_image] == "true" && game[:image].present?
        raw << "![#{game[:name]}|600](#{game[:image]})\n\n"
      end
      
      if params[:selected_images].present?
        raw << "### 🖼️ Images du jeu\n\n"
        JSON.parse(params[:selected_images]).each do |img_url|
          raw << "![Image](#{img_url})\n"
        end
        raw << "\n"
      end
      
      if params[:selected_videos].present?
        raw << "### 🎬 Vidéos\n\n"
        params[:selected_videos].split('|').each do |video_url|
          raw << "#{video_url}\n"
        end
        raw << "\n"
      end
      
      raw << "# #{game[:name]}\n\n"
      raw << "👤 **Joueurs :** #{game[:minplayers]}-#{game[:maxplayers]} | ⏳ **Durée :** #{game[:playingtime]} min | 🎂 **Âge :** #{game[:minage]}+\n\n"
      raw << "[Voir sur BoardGameGeek](https://boardgamegeek.com/boardgame/#{game[:id]})\n\n"
      raw << "## 📖 Description\n#{game[:description]}\n"
      
      post = PostCreator.new(
        current_user,
        title: "Fiche : #{game[:name]}",
        raw: raw,
        category: params[:category_id]
      ).create
      
      if post&.persisted?
        render json: { topic_url: post.topic.url }
      else
        render json: { error: "Erreur lors de la création du sujet" }, status: 422
      end
    end
  end

  Discourse::Application.routes.append do
    get "/game-sheet" => "game_sheet#index"
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    get "/game-sheet-api/categories" => "game_sheet#categories"
    post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
  end
end
