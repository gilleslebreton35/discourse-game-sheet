# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux depuis BGG
# version: 0.9
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
        # Utilisation d'un User-Agent de navigateur pour éviter les blocages robots
        request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        # --- CORRECTION : Suppression du Header Authorization ---
        # L'API XML2 de recherche BGG ne nécessite pas de token et le rejette (Erreur 401).

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
          
          return { bgg: [], error: "BGG a répondu avec l'erreur : #{resp&.code}" } if resp.nil? || !resp.is_a?(Net::HTTPSuccess)

          doc = Nokogiri::XML(resp.body)
          items = doc.xpath('//item').first(30)
          return { bgg: [] } if items.empty?

          ids = items.map { |i| i['id'] }.join(',')
          resp_details = request_bgg("thing?id=#{ids}")
          
          return { bgg: [] } if resp_details.nil? || !resp_details.is_a?(Net::HTTPSuccess)

          details_doc = Nokogiri::XML(resp_details.body)
          results = details_doc.xpath('//item').map do |item|
            {
              id: item['id'],
              name: item.at_xpath('name')&.[]('value'),
              yearpublished: item.at_xpath('yearpublished')&.[]('value'),
              thumbnail: item.at_xpath('thumbnail')&.text
            }
          end
          { bgg: results }
        rescue => e
          { bgg: [], error: e.message }
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
          images: image_url.present? ? [image_url] : [],
          videos: []
        }
      end
    end
  end

  # Chargement des composants et routes
  load File.expand_path("../app/controllers/discourse_game_sheet/game_sheet_controller.rb", __FILE__)

  Discourse::Application.routes.append do
    get "/game-sheet" => "discourse_game_sheet/game_sheet#index"
    get "/game-sheet-api/search" => "discourse_game_sheet/game_sheet#search"
    get "/game-sheet-api/details/:id" => "discourse_game_sheet/game_sheet#details"
    get "/game-sheet-api/categories" => "discourse_game_sheet/game_sheet#categories"
    post "/game-sheet-api/create-topic" => "discourse_game_sheet/game_sheet#create_topic"
  end
end
