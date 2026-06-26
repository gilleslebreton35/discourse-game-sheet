# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ::DiscourseGameSheet
  class DeeplClient
    FREE_API = "https://api-free.deepl.com/v2/translate"
    PRO_API  = "https://api.deepl.com/v2/translate"

    def self.translate(text)
      api_key = SiteSetting.game_sheet_deepl_api_key.to_s.strip
      return text if api_key.blank? || text.blank?

      # Clé se terminant par ":fx" → API gratuite, sinon API Pro
      endpoint = api_key.end_with?(":fx") ? FREE_API : PRO_API
      uri      = URI(endpoint)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "DeepL-Auth-Key #{api_key}"
      request["Content-Type"]  = "application/json"
      request.body = {
        text:              [text],
        target_lang:       "FR",
        preserve_formatting: true
      }.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        json = JSON.parse(response.body)
        json.dig("translations", 0, "text") || text
      else
        Rails.logger.error("[DeeplClient] Échec : #{response.code} — #{response.body.first(200)}")
        text   # On retourne le texte original si la traduction échoue
      end
    rescue StandardError => e
      Rails.logger.error("[DeeplClient] Erreur : #{e.message}")
      text
    end
  end
end
