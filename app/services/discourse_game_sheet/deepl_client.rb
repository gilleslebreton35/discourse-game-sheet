# frozen_string_literal: true
require "net/http"
require "json"

module ::DiscourseGameSheet
  class DeeplClient
    def self.translate(text)
      api_key = SiteSetting.game_sheet_deepl_api_key.to_s.strip
      return text if api_key.blank? || text.blank?

      # Détection automatique de l'API gratuite ou payante de DeepL via le suffixe :fx
      url = api_key.end_with?(":fx") ? "https://api-free.deepl.com/v2/translate" : "https://api.deepl.com/v2/translate"
      uri = URI(url)

      response = Net::HTTP.post_form(uri, {
        "text" => text,
        "target_lang" => "FR",
        "auth_key" => api_key
      })

      if response.is_a?(Net::HTTPSuccess)
        json = JSON.parse(response.body)
        json.dig("translations", 0, "text") || text
      else
        Rails.logger.error("[Game Sheet] Échec DeepL : #{response.body}")
        text
      end
    end
  end
end
