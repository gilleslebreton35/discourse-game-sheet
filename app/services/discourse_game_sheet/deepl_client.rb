# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module ::DiscourseGameSheet
  class DeeplClient
    API_URL = "https://api-free.deepl.com/v2/translate"

    def self.translate_game(game, api_key:, target_lang:)
      translated = game.deep_dup

      translated["description"] = translate_text(
        game[:description] || game["description"],
        api_key: api_key,
        target_lang: target_lang
      )

      translated["categories"] = Array(game[:categories] || game["categories"]).map do |c|
        translate_text(c, api_key: api_key, target_lang: target_lang)
      end

      translated["mechanics"] = Array(game[:mechanics] || game["mechanics"]).map do |m|
        translate_text(m, api_key: api_key, target_lang: target_lang)
      end

      translated
    end

    def self.translate_text(text, api_key:, target_lang:)
      return text if text.blank?

      uri = URI(API_URL)
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "DeepL-Auth-Key #{api_key}"

      req.set_form_data({
        "text" => text,
        "target_lang" => target_lang
      })

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(req)

      unless response.is_a?(Net::HTTPSuccess)
        raise "DeepL request failed: #{response.code}"
      end

      parsed = JSON.parse(response.body)
      parsed.dig("translations", 0, "text") || text
    end
  end
end
