# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.1
# authors: Toi

enabled_site_setting :game_sheet_enabled

after_initialize do

  require_dependency "application_controller"

  # 2. Logiciel d'interaction API (BGG Client)
  module DiscourseGameSheet
    class BggClient
      require 'nokogiri'
      require 'open-uri'

      # Recherche les jeux par nom
      def self.search(query)
        # Appel API BGG XML
        encoded_query = ERB::Util.url_encode(query)
        url = "https://boardgamegeek.com/xmlapi2/search?query=#{encoded_query}&type=boardgame"
        
        doc = Nokogiri::XML(URI.open(url).read)
        
        # Mapping du XML vers un objet Ruby
        results = doc.xpath('//item').map do |item|
          {
            id: item['id'],
            name: item.at_xpath('name')['value'],
            yearpublished: item.at_xpath('yearpublished') ? item.at_xpath('yearpublished')['value'] : "N/A"
          }
        end
        { bgg: results.first(10) }
      rescue => e
        Rails.logger.error("Erreur BGG Search: #{e.message}")
        { bgg: [] }
      end

      # Récupère les détails d'un jeu
      def self.game_details(id)
        url = "https://boardgamegeek.com/xmlapi2/thing?id=#{id}&stats=1"
        doc = Nokogiri::XML(URI.open(url).read)
        item = doc.at_xpath('//item')
        
        {
          id: id,
          name: item.at_xpath('name')['value'],
          description: item.at_xpath('description').text.gsub(/&amp;/, '&'), # Nettoyage HTML
          image: item.at_xpath('image') ? item.at_xpath('image').text : nil,
          yearpublished: item.at_xpath('yearpublished')['value']
        }
      end
    end
  end

  # 3. Contrôleur de l'API
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

    def create_topic
      # Logique de création de sujet
      game = DiscourseGameSheet::BggClient.game_details(params[:game_id])
      
      # Exemple de corps de message
      raw = "![image|600](#{game[:image]})\n\n### Description\n#{game[:description]}"
      
      post_creator = PostCreator.new(
        current_user, 
        title: "Fiche : #{game[:name]}", 
        raw: raw, 
        category: params[:category_id]
      )
      
      post = post_creator.create
      
      if post.persisted?
        render json: { topic_url: post.topic.url }
      else
        render json: { error: "Erreur lors de la création" }, status: 422
      end
    end
  end

  # 4. Routes
  Discourse::Application.routes.append do
    get "/game-sheet" => "game_sheet#index"
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
  end
end
