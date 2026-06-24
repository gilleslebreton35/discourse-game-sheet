# frozen_string_literal: true

require "net/http"
require "uri"
require "cgi"
require "rexml/document"

module ::DiscourseGameSheet
  class BggClient
    BASE_URL = "https://boardgamegeek.com/xmlapi2"

    def self.search(query)
      # 1. On fait la recherche initiale
      uri = URI("#{BASE_URL}/search?query=#{CGI.escape(query)}&type=boardgame")
      response = get(uri)
      doc = REXML::Document.new(response.body)

      ids = []
      doc.elements.each("items/item") do |item|
        ids << item.attributes["id"]
      end

      return { results: [] } if ids.empty?

      # 2. On prend les 10 premiers résultats et on demande leurs détails (images incluses)
      top_ids = ids.first(10).join(",")
      thing_uri = URI("#{BASE_URL}/thing?id=#{top_ids}")
      thing_response = get(thing_uri)
      thing_doc = REXML::Document.new(thing_response.body)

      items = []
      thing_doc.elements.each("items/item") do |item|
        primary_name = nil
        item.elements.each("name") do |n|
          primary_name = n.attributes["value"] if n.attributes["type"] == "primary"
        end

        year = item.elements["yearpublished"]&.attributes&.fetch("value", nil)
        thumbnail = item.elements["thumbnail"]&.text.to_s

        items << {
          id: item.attributes["id"],
          # CGI.unescapeHTML permet de transformer les &#039; en de vraies apostrophes !
          name: CGI.unescapeHTML(primary_name.to_s), 
          yearpublished: year,
          thumbnail: thumbnail
        }
      end

      { results: items }
    end

    def self.game(id)
      uri = URI("#{BASE_URL}/thing?id=#{CGI.escape(id)}&stats=1")
      response = get(uri)

      doc = REXML::Document.new(response.body)
      item = doc.elements["items/item"]
      raise "Game not found" if item.nil?

      names = []
      primary_name = nil

      item.elements.each("name") do |n|
        value = n.attributes["value"]
        names << value if value.present?
        primary_name = value if n.attributes["type"] == "primary"
      end

      description = item.elements["description"]&.text.to_s
      year = item.elements["yearpublished"]&.attributes&.fetch("value", nil)
      minplayers = item.elements["minplayers"]&.attributes&.fetch("value", nil)
      maxplayers = item.elements["maxplayers"]&.attributes&.fetch("value", nil)
      playingtime = item.elements["playingtime"]&.attributes&.fetch("value", nil)
      minage = item.elements["minage"]&.attributes&.fetch("value", nil)
      image = item.elements["image"]&.text.to_s
      thumbnail = item.elements["thumbnail"]&.text.to_s

      categories = []
      mechanics = []

      item.elements.each("link") do |link|
        type = link.attributes["type"]
        value = link.attributes["value"]

        categories << value if type == "boardgamecategory" && value.present?
        mechanics << value if type == "boardgamemechanic" && value.present?
      end

      {
        id: id,
        name: primary_name || names.first,
        alternate_names: names.uniq,
        description: description,
        yearpublished: year,
        minplayers: minplayers,
        maxplayers: maxplayers,
        playingtime: playingtime,
        minage: minage,
        image: image,
        thumbnail: thumbnail,
        categories: categories.uniq,
        mechanics: mechanics.uniq,
        bgg_url: "https://boardgamegeek.com/boardgame/#{id}"
      }
    end

    def self.get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      token = SiteSetting.game_sheet_bgg_token.to_s.strip

      request["Authorization"] = "Bearer #{token}" if token.present?

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "BGG request failed: #{response.code}"
      end

      response
    end
  end
end
