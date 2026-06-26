# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.8.2
# authors: Toi

enabled_site_setting :game_sheet_enabled

after_initialize do
  require_dependency "application_controller"
  require 'nokogiri'
  require 'net/http'
  require 'uri'
  require 'erb'

  # Ajout des settings personnalisés
  SiteSetting.refresh!
  
  unless SiteSetting.where(name: "game_sheet_bgg_token").exists?
    SiteSetting.create!(name: "game_sheet_bgg_token", data_type: 1, value: "a904f3bf-f154-4890-9618-4dc3835e40c7")
  end
  
  unless SiteSetting.where(name: "game_sheet_allowed_category_ids").exists?
    SiteSetting.create!(name: "game_sheet_allowed_category_ids", data_type: 1, value: "")
  end

  unless SiteSetting.where(name: "game_sheet_allowed_group").exists?
    SiteSetting.create!(name: "game_sheet_allowed_group", data_type: 1, value: "")
  end

  module ::DiscourseGameSheet
  class BggClient
      BASE_URL = "https://boardgamegeek.com/xmlapi2"

      def self.request_bgg(path)
        sleep 1
        uri = URI.parse("#{BASE_URL}/#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Discourse-GameSheet/1.0"
        # request["Authorization"] = "Bearer #{SiteSetting.game_sheet_bgg_token}"
        
        begin
          response = http.request(request)
          Rails.logger.warn("BGG REQUEST: #{uri} | Status: #{response.code}")
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
            return { bgg: [] }
          end

          doc = Nokogiri::XML(resp.body)
          # CORRECTION 1 : On prend les 30 premiers pour que le bouton "Afficher plus" (limite 10) apparaisse
          items = doc.xpath('//item').first(30) 
          
          return { bgg: [] } if items.empty?

          # CORRECTION 2 : On fait une requête /thing pour obtenir les miniatures (images)
          ids = items.map { |i| i['id'] }.join(',')
          resp_details = request_bgg("thing?id=#{ids}")
          
          return { bgg: [] } if resp_details.nil? || !resp_details.is_a?(Net::HTTPSuccess)

          details_doc = Nokogiri::XML(resp_details.body)
          
          results = details_doc.xpath('//item').map do |item|
            {
              id: item['id'],
              name: item.at_xpath('name')&.[]('value') || "Inconnu",
              yearpublished: item.at_xpath('yearpublished')&.[]('value'),
              thumbnail: item.at_xpath('thumbnail')&.text # Maintenant on a la miniature !
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
        
        image_url = item.at_xpath('image')&.text
        
        {
          id: id,
          name: item.at_xpath('name')&.[]('value'),
          description: item.at_xpath('description')&.text&.gsub(/&amp;/, '&')&.gsub(/&quot;/, '"'),
          image: image_url,
          minplayers: item.at_xpath('minplayers')&.[]('value'),
          maxplayers: item.at_xpath('maxplayers')&.[]('value'),
          playingtime: item.at_xpath('playingtime')&.[]('value'),
          minage: item.at_xpath('minage')&.[]('value'),
          yearpublished: item.at_xpath('yearpublished')&.[]('value'),
          # CORRECTION 3 : L'API standard ne donne qu'une image, on l'ajoute au tableau pour la galerie
          images: image_url.present? ? [image_url] : [], 
          videos: []
        }
      end
    end
  end

  # Chargement du contrôleur depuis le fichier dédié
  load File.expand_path("../app/controllers/discourse_game_sheet/game_sheet_controller.rb", __FILE__)

  # Routes corrigées avec le bon namespace
  Discourse::Application.routes.append do
    get "/game-sheet" => "discourse_game_sheet/game_sheet#index"
    get "/game-sheet-api/search" => "discourse_game_sheet/game_sheet#search"
    get "/game-sheet-api/details/:id" => "discourse_game_sheet/game_sheet#details"
    get "/game-sheet-api/categories" => "discourse_game_sheet/game_sheet#categories"
    post "/game-sheet-api/create-topic" => "discourse_game_sheet/game_sheet#create_topic"
  end
end
