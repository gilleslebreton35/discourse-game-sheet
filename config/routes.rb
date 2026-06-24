# frozen_string_literal: true

DiscourseGameSheet::Engine.routes.draw do
  get "/search" => "game_sheet#search"
  get "/game/:id" => "game_sheet#game"
  post "/create-topic" => "game_sheet#create_topic"
end
