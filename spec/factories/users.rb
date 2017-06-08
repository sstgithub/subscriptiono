FactoryGirl.define do
  factory :user do
    email "user@gmail.com"
    password "password"
    password_confirmation "password"
    refresh_token "abc123"
    provider "google_oauth2"
    uid "116579183604953849999"
  end
end
