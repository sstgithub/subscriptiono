require 'rails_helper'

RSpec.describe User, type: :model do
  it 'can refresh token' do
    Timecop.freeze(Time.now)
    user = create(:user, token_expires_at: Time.now)
    stub_request(:post, "https://www.googleapis.com/oauth2/v4/token").to_return(body: '{"access_token": "123", "expires_in": "3600"}', headers: {"content-type": "application/json"})

    user.refresh_user_token

    expect(user.token).to eq("123")
    expect(user.token_expires_at).to eq(Time.now.to_i + 3600)
  end
end
