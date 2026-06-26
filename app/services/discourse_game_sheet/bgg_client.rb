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
      response = Net::HTTP.get_response(uri)
      return { results: [] } unless response.is_a?(Net::HTTPSuccess)

      doc = REXML::Document.new(response.body)
      ids = []
      doc.elements.each("items/item") { |item| ids << item.attributes["id"] }
      return { results: [] } if ids.empty?

      # Combo pour récupérer les thumbnails dès la recherche
      thing_uri = URI("#{BASE_URL}/thing?id=#{ids.first(10).join(',')}")
      thing_response = Net::HTTP.get_response(thing_uri)
      thing_doc = REXML::Document.new(thing_response.body)

      items = []
      thing_doc.elements.each("items/item") do |item|
        primary_name = item.elements["name[@type='primary']"]&.attributes&.fetch("value", "")
        year = item.elements["yearpublished"]&.attributes&.fetch("value", "")
        thumbnail = item.elements["thumbnail"]&.text.to_s

        items << {
          id: item.attributes["id"],
          name: CGI.unescapeHTML(primary_name),
          yearpublished: year,
          thumbnail: thumbnail
        }
      end
      { results: items }
    end

    def self.game_details(id)
      uri = URI("#{BASE_URL}/thing?id=#{CGI.escape(id)}&videos=1")
      response = Net::HTTP.get_response(uri)
      raise "Jeu introuvable" unless response.is_a?(Net::HTTPSuccess)

      doc = REXML::Document.new(response.body)
      item = doc.elements["items/item"]
      raise "Données invalides" if item.nil?

      # Extraction des vidéos
      videos = []
      item.elements.each("videos/video") do |v|
        videos << {
          title: v.attributes["title"],
          link: v.attributes["link"]
        } if v.attributes["language"] == "English" || v.attributes["language"] == "French"
      end

      {
        id: id,
        name: item.elements["name[@type='primary']"]&.attributes&.fetch("value", ""),
        description: item.elements["description"]&.text.to_s,
        image: item.elements["image"]&.text.to_s,
        yearpublished: item.elements["yearpublished"]&.attributes&.fetch("value", ""),
        minplayers: item.elements["minplayers"]&.attributes&.fetch("value", ""),
        maxplayers: item.elements["maxplayers"]&.attributes&.fetch("value", ""),
        playingtime: item.elements["playingtime"]&.attributes&.fetch("value", ""),
        minage: item.elements["minage"]&.attributes&.fetch("value", ""),
        videos: videos.first(5) # On limite aux 5 premières vidéos pertinentes
      }
    end
  end
end
