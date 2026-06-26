# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.1
# authors: Toi

enabled_site_setting :game_sheet_enabled

after_initialize do

  require_dependency "application_controller"
  require 'nokogiri'
  require 'net/http'
  require 'uri'

  # 2. Logiciel d'interaction API (BGG Client)
  module DiscourseGameSheet
    class BggClient
      # Recherche les jeux par nom
      def self.search(query)
        return { bgg: [] } if query.blank?

        encoded_query = ERB::Util.url_encode(query)
        uri = URI.parse("https://boardgamegeek.com/xmlapi2/search?query=#{encoded_query}&type=boardgame")
        
        # On utilise Net::HTTP pour pouvoir envoyer un faux User-Agent de navigateur
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Discourse-GameSheet"

        begin
          response = http.request(request)
          
          if response.is_a?(Net::HTTPSuccess)
            doc = Nokogiri::XML(response.body)
            
            # Mapping du XML vers un objet Ruby avec protections
            results = doc.xpath('//item').map do |item|
              name_node = item.at_xpath('name')
              year_node = item.at_xpath('yearpublished')
              
              {
                id: item['id'],
                name: name_node ? name_node['value'] : "Inconnu",
                yearpublished: year_node ? year_node['value'] : "N/A"
              }
            end
            
            { bgg: results.first(10) }
          else
            Rails.logger.error("Erreur BGG Search HTTP: #{response.code}")
            { bgg: [] }
          end
        rescue => e
          Rails.logger.error("Erreur BGG Search Crash: #{e.message}")
          { bgg: [] }
        end
      end

      # Récupère les détails d'un jeu
      def self.game_details(id)
        uri = URI.parse("https://boardgamegeek.com/xmlapi2/thing?id=#{id}&stats=1")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Discourse-GameSheet"

        begin
          response = http.request(request)
          
          if response.is_a?(Net::HTTPSuccess)
            doc = Nokogiri::XML(response.body)
            item = doc.at_xpath('//item')
            
            return { error: "Jeu non trouvé" } unless item

            name_node = item.at_xpath('name')
            desc_node = item.at_xpath('description')
            img_node = item.at_xpath('image')
            year_node = item.at_xpath('yearpublished')

            {
              id: id,
              name: name_node ? name_node['value'] : "Inconnu",
              description: desc_node ? desc_node.text.gsub(/&amp;/, '&') : "",
              image: img_node ? img_node.text : nil,
              yearpublished: year_node ? year_node['value'] : "N/A"
            }
          else
            { error: "BGG indisponible" }
          end
        rescue => e
          Rails.logger.error("Erreur BGG Details Crash: #{e.message}")
          { error: "Erreur serveur" }
        end
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
      
      return render json: { error: "Impossible de récupérer les détails du jeu" }, status: 400 if game[:error]
      
      # Exemple de corps de message (si pas d'image, on l'omet pour éviter un affichage cassé)
      image_markdown = game[:image] ? "![image|600](#{game[:image]})\n\n" : ""
      raw = "#{image_markdown}### Description\n#{game[:description]}"
      
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
        render json: { error: post_creator.errors.full_messages.join(', ') }, status: 422
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
