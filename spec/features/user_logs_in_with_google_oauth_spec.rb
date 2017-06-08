require "rails_helper"

feature "User logs in with google oauth" do
  before do
    OmniAuth.config.test_mode = true

    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "116579183604953849999",
      info: {
        name: "Google User",
        email: "user@gmail.com",
        first_name: "Google",
        last_name: "User",
        image: ""
      },
      credentials: {
        token: "token",
        refresh_token: "another_token",
        expires_at: 1354920555,
        expires: true
      },
      extra: {
        id_token: "string"*1000, #test for CookieOverflow exception
        raw_info: OmniAuth::AuthHash.new(
          email: "user@gmail.com",
          email_verified:"true",
          kind:"plus#personOpenIdConnect"
        )
      }
    })
  end

  after do
    OmniAuth.config.test_mode = false
  end

  scenario "existing user" do
    user = create(:user)

    expect(User.count).to eq(1)
    expect(User.first).to eq(user)

    visit root_path
    click_link "Sign in with Google"

    expect(User.count).to eq(1)
    expect(User.first).to eq(user)

    expect(page).to have_content "Logout"
  end

  scenario "new user" do
    expect(User.count).to eq(0)

    visit root_path
    click_link "Sign in with Google"

    expect(User.count).to eq(1)
    expect(page).to have_content "Logout"
  end
end
