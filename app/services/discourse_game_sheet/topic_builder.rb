# frozen_string_literal: true

module ::DiscourseGameSheet
  class TopicBuilder
    def self.create!(current_user:, game:, translated:, category_id:)
      title = build_title(game, translated)
      raw = build_raw(game, translated)

      creator = PostCreator.create!(
        current_user,
        title: title,
        raw: raw,
        category: category_id
      )

      creator
    end

    def self.build_title(game, translated)
      translated_name = translated["name"] || translated[:name] || game[:name] || game["name"]
      year = game[:yearpublished] || game["yearpublished"]

      year.present? ? "#{translated_name} (#{year})" : translated_name.to_s
    end

    def self.build_raw(game, translated)
      original_name = game[:name] || game["name"]
      description = translated["description"] || translated[:description]
      minplayers = game[:minplayers] || game["minplayers"]
      maxplayers = game[:maxplayers] || game["maxplayers"]
      playingtime = game[:playingtime] || game["playingtime"]
      minage = game[:minage] || game["minage"]
      image = game[:image] || game["image"]
      bgg_url = game[:bgg_url] || game["bgg_url"]

      categories = Array(translated["categories"] || translated[:categories])
      mechanics = Array(translated["mechanics"] || translated[:mechanics])

      lines = []
      lines << "# #{original_name}"
      lines << ""
      lines << "![image|690xauto](#{image})" if image.present?
      lines << ""
      lines << "**BGG**: #{bgg_url}" if bgg_url.present?
      lines << ""
      lines << "## Description"
      lines << ""
      lines << description.to_s
      lines << ""
      lines << "## Details"
      lines << ""
      lines << "- Players: #{minplayers}–#{maxplayers}" if minplayers.present? || maxplayers.present?
      lines << "- Playing time: #{playingtime} min" if playingtime.present?
      lines << "- Minimum age: #{minage}+" if minage.present?
      lines << ""
      lines << "## Categories"
      lines << ""
      lines << categories.map { |c| "- #{c}" } if categories.present?
      lines << ""
      lines << "## Mechanics"
      lines << ""
      lines << mechanics.map { |m| "- #{m}" } if mechanics.present?
      lines << ""
      lines << "---"
      lines << "Generated automatically from BoardGameGeek + DeepL."

      lines.flatten.join("\n")
    end
  end
end
