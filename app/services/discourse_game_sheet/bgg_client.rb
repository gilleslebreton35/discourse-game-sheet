# frozen_string_literal: true

require "net/http"
require "uri"
require "cgi"
require "rexml/document"

module ::DiscourseGameSheet
  class BggClient
    BASE_URL = "https://boardgamegeek.com/xmlapi2"

    def self.search(query)
      uri = URI("#{BASE_URL}/search?query=#{CGI.escape(query)}&type=boardgame")
      response = get(uri)

      doc = REXML::Document.new(response.body)
      items = []

      doc.elements.each("items/item") do |item|
        name = item.elements["name"]&.attributes&.fetch("value", nil)
        year = item.elements["yearpublished"]&.attributes&.fetch("value", nil)

        items << {
          id: item.attributes["id"],
          name: name,
          yearpublished: year
        }
      end

      { results: items.first(10) }
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
