# name: discourse-game-sheet
# about: Plugin pour créer des fiches de jeux avec sélection de médias
# version: 0.6

enabled_site_setting :game_sheet_enabled
enabled_site_setting :game_sheet_allowed_category_ids

after_initialize do
  require_dependency "application_controller"
  require 'nokogiri'
  require 'net/http'
  require 'uri'

  # Définition du paramètre admin pour filtrer les catégories
  register_editable_site_setting :game_sheet_allowed_category_ids, default: "1|2|3"

  module DiscourseGameSheet
    class BggClient
      BGG_TOKEN = "a904f3bf-f154-4890-9618-4dc3835e40c7"

      def self.request_bgg(path)
        uri = URI.parse("https://boardgamegeek.com/xmlapi2/#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Discourse-GameSheet"
        http.request(request)
      end

      def self.search(query)
        resp = request_bgg("search?query=#{ERB::Util.url_encode(query)}&type=boardgame")
        return { bgg: [] } unless resp.is_a?(Net::HTTPSuccess)
        
        doc = Nokogiri::XML(resp.body)
        ids = doc.xpath('//item').map { |i| i['id'] }.first(5)
        return { bgg: [] } if ids.empty?

        resp_details = request_bgg("thing?id=#{ids.join(',')}")
        doc_details = Nokogiri::XML(resp_details.body)
        
        results = doc_details.xpath('//item').map do |item|
          { id: item['id'], name: item.at_xpath('name')&.[]('value'), image: item.at_xpath('thumbnail')&.text }
        end
        { bgg: results }
      end

      def self.game_details(id)
        resp = request_bgg("thing?id=#{id}&stats=1&videos=1")
        doc = Nokogiri::XML(resp.body)
        item = doc.at_xpath('//item')

        {
          id: id,
          name: item.at_xpath('name')&.[]('value'),
          description: item.at_xpath('description')&.text,
          images: doc.xpath('//image').map(&:text).first(5),
          videos: doc.xpath('//video').select { |v| v['language'] == 'French' }.map { |v| { link: v['link'], title: v['title'] } }
        }
      end
    end
  end

  class ::GameSheetController < ::ApplicationController
    before_action :ensure_logged_in

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
      data = params.permit(:game_id, :category_id, images: [], videos: [:link, :title])
      game = DiscourseGameSheet::BggClient.game_details(data[:game_id])
      
      # Construction du Markdown
      raw = ""
      data[:images]&.each { |img| raw << "![image|600](#{img})\n\n" }
      data[:videos]&.each { |vid| raw << "[Vidéo : #{vid[:title]}](#{vid[:link]})\n\n" }
      raw << "### Description\n#{game[:description]}"
      
      post = PostCreator.new(current_user, title: "Fiche : #{game[:name]}", raw: raw, category: data[:category_id]).create
      post&.persisted? ? render(json: { topic_url: post.topic.url }) : render(json: { error: "Erreur" }, status: 422)
    end
  end

  Discourse::Application.routes.append do
    get "/game-sheet-api/search" => "game_sheet#search"
    get "/game-sheet-api/details/:id" => "game_sheet#details"
    get "/game-sheet-api/categories" => "game_sheet#categories"
    post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
  end
end
