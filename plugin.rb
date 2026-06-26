# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.2
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
        # On ajoute un message de débug pour savoir ce qui se passe
        return { bgg: [], debug_msg: "Le terme de recherche reçu par le serveur est vide." } if query.blank?

        encoded_query = ERB::Util.url_encode(query.to_s.strip)
        uri = URI.parse("https://boardgamegeek.com/xmlapi2/search?query=#{encoded_query}&type=boardgame")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Discourse-GameSheet"

        begin
          response = http.request(request)
          
          if response.is_a?(Net::HTTPSuccess)
            doc = Nokogiri::XML(response.body)
            
            results = doc.xpath('//item').map do |item|
              name_node = item.at_xpath('name')
              year_node = item.at_xpath('yearpublished')
              
              {
                id: item['id'],
                name: name_node ? name_node['value'] : "Inconnu",
                yearpublished: year_node ? year_node['value'] : "N/A"
              }
            end
            
            { bgg: results.first(10), debug_msg: "Succès : #{results.size} jeux trouvés." }
          else
            { bgg: [], debug_msg: "BGG a rejeté la connexion avec l'erreur HTTP: #{response.code}" }
          end
        rescue => e
          { bgg: [], debug_msg: "Le serveur Ruby a crashé : #{e.message}" }
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
            { error: "BGG indisponible (#{response.code})" }
          end
        rescue => e
          { error: "Erreur serveur : #{e.message}" }
        end
      end
    end
  end

  # 3. Contrôleur de l'API
  class ::GameSheetController < ::ApplicationController
    requires_plugin "discourse-game-sheet"
    before_action :ensure_logged_in
    
    # CRUCIAL : Empêche Discourse de bloquer ta requête JSON si elle ne contient pas les bons en-têtes
    skip_before_action :check_xhr, only: [:index, :search, :details]

    def index
      render html: "", layout: true
    end

    def search
      # CRUCIAL : On accepte "q" OU "query" pour être sûr de ne rien rater
      term = params[:q].presence || params[:query].presence
      render json: DiscourseGameSheet::BggClient.search(term)
    end

    def details
      render json: DiscourseGameSheet::BggClient.game_details(params[:id])
    end

    def create_topic
      game = DiscourseGameSheet::BggClient.game_details(params[:game_id])
      
      return render json: { error: game[:error] }, status: 400 if game[:error]
      
      image_markdown = game[:image].present? ? "![image|600](#{game[:image]})\n\n" : ""
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
