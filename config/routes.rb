# config/routes.rb
DiscourseGameSheet::Engine.routes.draw do
  get "/game-sheet" => "game_sheet#index"
  get "/game-sheet-api/search" => "game_sheet#search"
  get "/game-sheet-api/details/:id" => "game_sheet#details"
  get "/game-sheet-api/categories" => "game_sheet#categories"
  post "/game-sheet-api/create-topic" => "game_sheet#create_topic"
end

Discourse::Application.routes.append do
  mount ::DiscourseGameSheet::Engine, at: "/game-sheet"
end
