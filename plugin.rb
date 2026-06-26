# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.7
# authors: Toi

enabled_site_setting :game_sheet_enabled

after_initialize do
  require_dependency "application_controller"
  require 'nokogiri'
  require 'net/http'
  require 'uri'
  require 'erb'

  module ::DiscourseGameSheet
 class BggClient
      BASE_URL = "https://boardgamegeek.com/xmlapi2"

      def self.request_bgg(path)
        sleep 1
        uri = URI.parse("#{BASE_URL}/#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Discourse-GameSheet"
        
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
          
          return { bgg: [] } if resp.nil? || !resp.is_a?(Net::HTTPSuccess)
          
          doc = Nokogiri::XML(resp.body)
          items = doc.xpath('//item')
          return { bgg: [] } if items.empty?

          # On prend les 10 premiers résultats
          results = items.first(10).map do |item|
            {
              id: item['id'],
              name: item.at_xpath('name')&.[]('value'),
              yearpublished: item.at_xpath('yearpublished')&.[]('value')
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
          min_players: item.at_xpath('minplayers')&.[]('value'),
          max_players: item.at_xpath('maxplayers')&.[]('value'),
          playing_time: item.at_xpath('playingtime')&.[]('value'),
          min_age: item.at_xpath('minage')&.[]('value'),
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
      # Utilise le setting enregistré
      allowed_ids = SiteSetting.game_sheet_allowed_category_ids.split('|').map(&:to_i)
      render json: Category.where(id: allowed_ids).map { |c| { id: c.id, name: c.name } }
    end

    def create_topic
      game = DiscourseGameSheet::BggClient.game_details(params[:game_id])
      return render json: { error: game[:error] }, status: 400 if game[:error]
      
      # Template Markdown
      raw = <<~MARKDOWN
        # #{game[:name]}
        ![#{game[:name]}|600](#{game[:image]})

        👤 **Joueurs :** #{game[:min_players]}-#{game[:max_players]} | ⏳ **Durée :** #{game[:playing_time]} min | 🎂 **Âge :** #{game[:min_age]}+
        [Voir sur BoardGameGeek](https://boardgamegeek.com/boardgame/#{game[:id]})

        ## 📖 Description
        #{game[:description]}
        —description fournie par l’éditeur
      MARKDOWN
      
      post = PostCreator.new(current_user, title: "Fiche : #{game[:name]}", raw: raw, category: params[:category_id]).create
      post&.persisted? ? render(json: { topic_url: post.topic.url }) : render(json: { error: "Erreur" }, status: 422)
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
