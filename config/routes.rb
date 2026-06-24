DiscourseGameSheet::Engine.routes.draw do
  get "/search" => "game_sheet#search"
  get "/details" => "game_sheet#details"
  post "/create-topic" => "game_sheet#create_topic"
end

Discourse::Application.routes.append do
  mount ::DiscourseGameSheet::Engine, at: "/game-sheet"
end
