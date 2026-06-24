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

      # Collecter les images
      images = []
      images << image if image.present?

      # Récupérer les images des versions (BGG v2)
      begin
        versions_uri = URI("#{BASE_URL}/thing?id=#{CGI.escape(id)}&versions=1")
        versions_response = get(versions_uri)
        versions_doc = REXML::Document.new(versions_response.body)

        versions_doc.elements.each("items/item") do |version_item|
          version_item.elements.each("image") do |img|
            url = img.text.to_s.strip
            images << url if url.present? && !images.include?(url)
          end
        end
      rescue StandardError => e
        Rails.logger.warn "[GameSheet] Erreur récupération images versions BGG: #{e.message}"
      end

      # Si moins de 5 images, essayer de récupérer les images des expansions et accessoires
      if images.length < 5
        begin
          # Récupérer les IDs des expansions et accessoires
          expansions_ids = []
          item.elements.each("link") do |link|
            type = link.attributes["type"]
            if ["boardgameexpansion", "boardgameaccessory"].include?(type)
              expansions_ids << link.attributes["id"]
            end
          end

          # Récupérer leurs infos par lots de 10
          expansions_ids.each_slice(10) do |batch_ids|
            batch_uri = URI("#{BASE_URL}/thing?id=#{batch_ids.join(',')}")
            batch_response = get(batch_uri)
            batch_doc = REXML::Document.new(batch_response.body)

            batch_doc.elements.each("items/item") do |sub_item|
              sub_item.elements.each("image") do |img|
                url = img.text.to_s.strip
                images << url if url.present? && !images.include?(url)
              end
            end
          end
        rescue StandardError => e
          Rails.logger.warn "[GameSheet] Erreur récupération images expansions: #{e.message}"
        end
      end

      # Récupérer les vidéos (sans filtre de langue pour le test)
      videos = []
      begin
        videos_uri = URI("#{BASE_URL}/thing?id=#{CGI.escape(id)}&videos=1")
        videos_response = get(videos_uri)
        videos_doc = REXML::Document.new(videos_response.body)

        videos_doc.elements.each("items/item/videos/video") do |v|
          language = (v.attributes["language"] || "").to_s.downcase

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
