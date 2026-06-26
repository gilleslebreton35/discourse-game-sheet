# frozen_string_literal: true

require "net/http"
require "uri"
require "cgi"
require "rexml/document"

module ::DiscourseGameSheet
  class BggClient
    BASE_URL = "https://boardgamegeek.com/xmlapi2"

    # ── Recherche ─────────────────────────────────────────────────────────────
    def self.search(query)
      uri = URI("#{BASE_URL}/search?query=#{CGI.escape(query)}&type=boardgame")
      response = fetch(uri)
      return { results: [] } unless response

      doc = REXML::Document.new(response)
      ids = []
      doc.elements.each("items/item") { |item| ids << item.attributes["id"] }
      return { results: [] } if ids.empty?

      # On récupère les thumbnails en une seule requête (10 premiers)
      thing_uri = URI("#{BASE_URL}/thing?id=#{ids.first(10).join(",")}")
      thing_body = fetch(thing_uri)
      return { results: [] } unless thing_body

      thing_doc = REXML::Document.new(thing_body)
      items = []

      thing_doc.elements.each("items/item") do |item|
        primary_name = item.elements["name[@type='primary']"]
                           &.attributes&.fetch("value", "") || ""
        year      = item.elements["yearpublished"]&.attributes&.fetch("value", "")
        thumbnail = item.elements["thumbnail"]&.text.to_s.strip
        thumbnail = "https:#{thumbnail}" if thumbnail.start_with?("//")

        items << {
          id:            item.attributes["id"],
          name:          CGI.unescapeHTML(primary_name),
          yearpublished: year,
          thumbnail:     thumbnail.presence
        }
      end

      { results: items }
    end

    # ── Détails d'un jeu ──────────────────────────────────────────────────────
    def self.game_details(id)
      uri  = URI("#{BASE_URL}/thing?id=#{CGI.escape(id.to_s)}&videos=1")
      body = fetch(uri, retries: 5, wait: 2)
      raise "Jeu introuvable (BGG)" unless body

      doc  = REXML::Document.new(body)
      item = doc.elements["items/item"]
      raise "Données BGG invalides" if item.nil?

      image = item.elements["image"]&.text.to_s.strip
      image = "https:#{image}" if image.start_with?("//")

      # Vidéos en anglais ou français uniquement
      videos = []
      item.elements.each("videos/video") do |v|
        lang = v.attributes["language"].to_s
        next unless lang == "English" || lang == "French" || lang == "french" || lang == "english"
        link = v.attributes["link"].to_s
        next if link.blank?
        videos << {
          title: v.attributes["title"],
          link:  link
        }
      end

      {
        id:            id,
        name:          CGI.unescapeHTML(
                         item.elements["name[@type='primary']"]
                             &.attributes&.fetch("value", "") || ""
                       ),
        description:   item.elements["description"]&.text.to_s,
        image:         image.presence,
        yearpublished: item.elements["yearpublished"]&.attributes&.fetch("value", ""),
        minplayers:    item.elements["minplayers"]&.attributes&.fetch("value", ""),
        maxplayers:    item.elements["maxplayers"]&.attributes&.fetch("value", ""),
        playingtime:   item.elements["playingtime"]&.attributes&.fetch("value", ""),
        minage:        item.elements["minage"]&.attributes&.fetch("value", ""),
        videos:        videos.first(5)
      }
    end

    private

    # Fetch HTTP avec retry (BGG répond parfois 202 "en traitement")
    def self.fetch(uri, retries: 3, wait: 1)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = (uri.scheme == "https")
      http.read_timeout = 15
      http.open_timeout = 10

      retries.times do |attempt|
        response = http.get(uri.request_uri, { "User-Agent" => "DiscourseGameSheet/2.0" })

        return response.body if response.is_a?(Net::HTTPSuccess)

        if response.code == "202"
          # BGG traite la requête, on attend puis on réessaie
          sleep(wait * (attempt + 1))
          next
        end

        Rails.logger.warn("[BggClient] HTTP #{response.code} pour #{uri}")
        return nil
      end

      nil
    rescue StandardError => e
      Rails.logger.error("[BggClient] Erreur réseau : #{e.message}")
      nil
    end
  end
end
