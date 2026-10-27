Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "test#index"
  post "test/publish" => "test#publish", as: :test_publish
end
