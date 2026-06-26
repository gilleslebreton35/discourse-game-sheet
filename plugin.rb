# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.6
# authors: Toi

enabled_site_setting :game_sheet_enabled

after_initialize do
  require_dependency "application_controller"
  require 'nokogiri'
  require 'net/http'
  require 'uri'

  # 1. Module de logique BGG
  module ::DiscourseGameSheet
    class BggClient
      BASE_URL = "https://boardgamegeek.com/xmlapi2"

      def self.request_bgg(path)
        uri = URI.parse("#{BASE_URL}/#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Discourse-GameSheet"
        
        response = http.request(request)
        # Log pour débogage
        Rails.logger.warn("BGG REQUEST: #{uri} | STATUS: #{response.code}")
        response
      end

      def self.search(query)
        return { bgg: [] } if query.blank?
        
        encoded_query = ERB::Util.url_encode(query.to_s.strip)
        resp = request_bgg("search?query=#{encoded_query}&type=boardgame")
        
        return { bgg: [] } unless resp.is_a?(Net::HTTPSuccess)
        
        doc = Nokogiri::XML(resp.body)
        ids = doc.xpath('//item').map { |i| i['id'] }.first(10)
        
        Rails.logger.warn("BGG SEARCH: Found IDs: #{ids.join(', ')}")
        return { bgg: [] } if ids.empty?

        # Récupération des détails pour afficher les vignettes
        resp_details = request_bgg("thing?id=#{ids.join(',')}")
        return { bgg: [] } unless resp_details.is_a?(Net::HTTPSuccess)
        
        details_doc = Nokogiri::XML(resp_details.body)
        results = details_doc.xpath('//item').map do |item|
          {
            id: item['id'],
            name: item.at_xpath('name')&.[]('value'),
            yearpublished: item.at_xpath('yearpublished')&.[]('value'),
            image: item.at_xpath('thumbnail')&.text
          }
        end
        { bgg: results }
      end

      def self.game_details(id)
        resp = request_bgg("thing?id=#{id}&stats=1")
        return { error: "Non trouvé" } unless resp.is_a?(Net::HTTPSuccess)
        
        doc = Nokogiri::XML(resp.body)
        item = doc.at_xpath('//item')
        return { error: "Non trouvé" } unless item
        
        {
          id: id,
          name: item.at_xpath('name')&.[]('value'),
          description: item.at_xpath('description')&.text&.gsub(/&amp;/, '&'),
          image: item.at_xpath('image')&.text,
          videos: item.xpath('.//video').map { |v| { title: v['title'], link: v['link'] } }
        }
      end
    end
  end

  # 2. Contrôleur
  class ::GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"
    before_action :ensure_logged_in
    skip_before_action :check_xhr, only: [:index]

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
      
      image_markdown = game[:image].present? ? "![image|600](#{game[:image]})\n\n" : ""
      raw = "#{image_markdown}### Description\n#{game[:description]}"
      
      post = PostCreator.new(current_user, title: "Fiche : #{game[:name]}", raw: raw, category: params[:category_id]).create
      post&.persisted? ? render(json: { topic_url: post.topic.url }) : render(json: { error: "Erreur" }, status: 422)
    end
  end

  # 3. Routes
  Discourse::Application.routes.append do
    get "/game-sheet" => "game_sheet#index"
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    get "/game-sheet-api/categories" => "game_sheet#categories"
    post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
  end
end
