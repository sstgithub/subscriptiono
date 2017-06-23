require 'rails_helper'
require 'faker'

feature 'User logs in with google oauth' do
  before do
    OmniAuth.config.test_mode = true

    @google_auth_data = OmniAuth::AuthHash.new(Faker::Omniauth.google)
    OmniAuth.config.mock_auth[:google_oauth2] = @google_auth_data
  end

  after do
    OmniAuth.config.test_mode = false
  end

  scenario 'existing user' do
    user = create(:user, email: @google_auth_data.info.email, uid: @google_auth_data.uid)

    expect(User.count).to eq(1)
    expect(User.first).to eq(user)

    visit root_path
    click_link 'Sign in with Google'

    expect(User.count).to eq(1)
    expect(User.first).to eq(user)

    expect(page).to have_content 'Logout'
  end

  scenario 'new user' do
    expect(User.count).to eq(0)

    visit root_path
    click_link 'Sign in with Google'

    expect(User.count).to eq(1)
    expect(page).to have_content 'Logout'
  end
end
