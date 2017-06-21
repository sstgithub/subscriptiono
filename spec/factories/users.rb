FactoryGirl.define do
  factory :user do
    email Faker::Internet.email
    password "password"
    password_confirmation "password"
    token "abc123"
    refresh_token "abc123"
    provider "google_oauth2"
    uid "116579183604953849999"
    token_expires_at Time.now.to_i
  end
end
