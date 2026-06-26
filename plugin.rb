# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.4
# authors: Toi

enabled_site_setting :game_sheet_enabled

after_initialize do
  require_dependency "application_controller"
  require 'nokogiri'
  require 'net/http'
  require 'uri'

  module DiscourseGameSheet
    class BggClient
      BGG_TOKEN = "a904f3bf-f154-4890-9618-4dc3835e40c7"

      def self.search(query)
        return { bgg: [], debug_msg: "Recherche vide" } if query.blank?

        encoded_query = ERB::Util.url_encode(query.to_s.strip)
        uri = URI.parse("https://boardgamegeek.com/xmlapi2/search?query=#{encoded_query}&type=boardgame")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Mozilla/5.0 (Discourse-GameSheet)"
        request["Authorization"] = "Bearer #{BGG_TOKEN}"

        begin
          response = http.request(request)
          if response.is_a?(Net::HTTPSuccess)
            doc = Nokogiri::XML(response.body)
            results = doc.xpath('//item').map do |item|
              # On récupère l'année pour l'affichage dans le frontend
              year_node = item.at_xpath('yearpublished')
              { 
                id: item['id'], 
                name: item.at_xpath('name')&.[]('value'),
                yearpublished: year_node ? year_node['value'] : "N/A"
              }
            end
            { bgg: results.first(10) }
          else
            { bgg: [], debug_msg: "Erreur BGG #{response.code}" }
          end
        rescue => e
          { bgg: [], debug_msg: "Crash: #{e.message}" }
        end
      end

      def self.game_details(id)
        uri = URI.parse("https://boardgamegeek.com/xmlapi2/thing?id=#{id}&stats=1")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Mozilla/5.0 (Discourse-GameSheet)"
        request["Authorization"] = "Bearer #{BGG_TOKEN}"

        begin
          response = http.request(request)
          if response.is_a?(Net::HTTPSuccess)
            doc = Nokogiri::XML(response.body)
            item = doc.at_xpath('//item')
            return { error: "Non trouvé" } unless item

            {
              id: id,
              name: item.at_xpath('name')&.[]('value'),
              description: item.at_xpath('description')&.text&.gsub(/&amp;/, '&'),
              image: item.at_xpath('image')&.text
            }
          else
            { error: "Erreur BGG #{response.code}" }
          end
        rescue => e
          { error: "Crash: #{e.message}" }
        end
      end
    end
  end

  class ::GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"
    before_action :ensure_logged_in
    skip_before_action :check_xhr, only: [:index, :search, :details, :categories]

    def index
      render html: "", layout: true
    end

    def search
      render json: DiscourseGameSheet::BggClient.search(params[:q] || params[:query])
    end

    def details
      render json: DiscourseGameSheet::BggClient.game_details(params[:id])
    end

    # NOUVEAU : Endpoint pour lister les catégories disponibles
    def categories
      render json: Category.listable_categories(current_user).map { |c| { id: c.id, name: c.name } }
    end

    def create_topic
      game = DiscourseGameSheet::BggClient.game_details(params[:game_id])
      return render json: { error: game[:error] }, status: 400 if game[:error]
      
      image_markdown = game[:image].present? ? "![image|600](#{game[:image]})\n\n" : ""
      raw = "#{image_markdown}### Description\n#{game[:description]}"
      
      post = PostCreator.new(current_user, title: "Fiche : #{game[:name]}", raw: raw, category: params[:category_id]).create
      post&.persisted? ? render(json: { topic_url: post.topic.url }) : render(json: { error: "Erreur lors de la création du sujet" }, status: 422)
    end
  end

  Discourse::Application.routes.append do
    get "/game-sheet" => "game_sheet#index"
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    get "/game-sheet-api/categories" => "game_sheet#categories" # Nouvelle route
    post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
  end
end
