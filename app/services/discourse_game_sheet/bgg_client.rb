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

      ids = []
      doc.elements.each("items/item") do |item|
        ids << item.attributes["id"]
      end

      return { results: [] } if ids.empty?

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

      # Collecter toutes les images disponibles
images = []
images << image if image.present?

# Essayer de récupérer des images supplémentaires depuis les versions (API v2)
begin
  versions_uri = URI("#{BASE_URL}/thing?id=#{CGI.escape(id)}&type=boardgame&versions=1")
  versions_response = get(versions_uri)
  versions_doc = REXML::Document.new(versions_response.body)

  versions_doc.elements.each("items/item") do |version_item|
    version_item.elements.each("image") do |img|
      url = img.text.to_s.strip
      images << url if url.present? && !images.include?(url)
    end
  end
rescue StandardError
end

# Essayer de récupérer des images supplémentaires via l'API v1 (gallery)
begin
  # L'API v1 BGG a parfois plus d'images
  gallery_uri = URI("https://boardgamegeek.com/boardgame/#{id}/images?ajax=1")
  gallery_response = get(gallery_uri)
  
  # On extrait les URLs d'images de la réponse HTML/JSON
  # Les images BGG sont généralement au format https://cf.geekdo-images.com/...
  image_urls = gallery_response.body.scan(%r{https?://cf\.geekdo-images\.com/[^"'\s]+})
  
  image_urls.uniq.each do |url|
    images << url if !images.include?(url)
  end
rescue StandardError => e
  Rails.logger.warn "[GameSheet] Erreur récupération galerie BGG: #{e.message}"
end

# Alternative plus simple : utiliser boardgamegeek.com directement pour les images
# Méthode la plus fiable : parser la page du jeu sur BGG
begin
  page_uri = URI("https://boardgamegeek.com/boardgame/#{id}")
  page_response = get(page_uri)
  
  # Chercher les images dans le HTML de la page
  # La galerie d'images est souvent dans des éléments avec classe "carousel"
  img_urls = page_response.body.scan(%r{https?://cf\.geekdo-images\.com/[^"'\s]+(?:png|jpg|jpeg|gif)}i)
  
  img_urls.uniq.each do |url|
    images << url if !images.include?(url)
  end
rescue StandardError => e
  Rails.logger.warn "[GameSheet] Erreur récupération page BGG: #{e.message}"
end

# Récupérer les vidéos
videos = []
begin
  videos_uri = URI("#{BASE_URL}/thing?id=#{CGI.escape(id)}&videos=1")
  videos_response = get(videos_uri)
  videos_doc = REXML::Document.new(videos_response.body)

  videos_doc.elements.each("items/item/videos/video") do |v|
    language = v.attributes["language"].to_s.downcase
    
    # Ne garder que les vidéos en français
    next unless language == "fr" || language == "french"
    
    video = {
      id: v.attributes["id"],
      title: v.attributes["title"],
      author: v.attributes["author"],
      category: v.attributes["category"],
      language: language,
      thumbnail: v.attributes["thumbnail"] || "https://img.youtube.com/vi/#{v.attributes['id']}/mqdefault.jpg",
      url: "https://www.youtube.com/watch?v=#{v.attributes['id']}"
    }
    videos << video
  end
rescue StandardError => e
  Rails.logger.warn "[GameSheet] Erreur récupération vidéos BGG: #{e.message}"
end

      rating = item.elements["statistics/ratings/average"]&.attributes&.fetch("value", nil)

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
        images: images.uniq,
        categories: categories.uniq,
        mechanics: mechanics.uniq,
        rating: rating,
        videos: videos,
        bgg_url: "https://boardgamegeek.com/boardgame/#{id}"
      }
    end

    def self.get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      token = SiteSetting.game_sheet_bgg_token.to_s.strip
      request["Authorization"] = "Bearer #{token}" if token.present?
      request["User-Agent"] = "DiscourseGameSheet/1.0"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "BGG request failed: #{response.code}"
      end

      response
    end
  end
end
