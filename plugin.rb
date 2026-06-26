# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG avec authentification
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
      # Ton Token BGG
      BGG_TOKEN = "a904f3bf-f154-4890-9618-4dc3835e40c7"
      BASE_URL = "https://boardgamegeek.com/xmlapi2"

      def self.request_bgg(endpoint, params = {})
        uri = URI("#{BASE_URL}/#{endpoint}")
        uri.query = URI.encode_www_form(params)
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Discourse-GameSheet-Plugin"
        request["Authorization"] = "Bearer #{BGG_TOKEN}"
        request["Accept"] = "application/xml"

        http.request(request)
      end

      def self.search(query)
        return { bgg: [], error: "Terme vide" } if query.blank?

        response = request_bgg("search", { query: query, type: "boardgame" })
        
        if response.is_a?(Net::HTTPSuccess)
          doc = Nokogiri::XML(response.body)
          results = doc.xpath('//item').map do |item|
            { 
              id: item['id'], 
              name: item.at_xpath('name')&.[]('value') 
            }
          end
          { bgg: results.first(10) }
        else
          { bgg: [], error: "BGG Error #{response.code}: #{response.body}" }
        end
      end

      def self.game_details(id)
        response = request_bgg("thing", { id: id, stats: 1 })
        
        if response.is_a?(Net::HTTPSuccess)
          doc = Nokogiri::XML(response.body)
          item = doc.at_xpath('//item')
          return { error: "Jeu introuvable" } unless item

          {
            id: id,
            name: item.at_xpath('name')&.[]('value'),
            description: item.at_xpath('description')&.text&.gsub(/&amp;/, '&'),
            image: item.at_xpath('image')&.text
          }
        else
          { error: "BGG Error #{response.code}" }
        end
      end
    end
  end

  class ::GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"
    before_action :ensure_logged_in
    skip_before_action :check_xhr, only: [:search, :details]

    def search
      render json: DiscourseGameSheet::BggClient.search(params[:q] || params[:query])
    end

    def details
      render json: DiscourseGameSheet::BggClient.game_details(params[:id])
    end

    def create_topic
      game = DiscourseGameSheet::BggClient.game_details(params[:game_id])
      return render json: { error: game[:error] }, status: 400 if game[:error]
      
      raw = "#{game[:image] ? "![image|600](#{game[:image]})\n\n" : ""}### Description\n#{game[:description]}"
      
      post = PostCreator.new(current_user, title: "Fiche : #{game[:name]}", raw: raw, category: params[:category_id]).create
      
      post&.persisted? ? render(json: { topic_url: post.topic.url }) : render(json: { error: "Erreur création" }, status: 422)
    end
  end

  Discourse::Application.routes.append do
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
  end
end
