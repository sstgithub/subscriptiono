class User < ApplicationRecord
  has_many :folders, dependent: :destroy
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  after_create do
    ImapSyncJob.perform_later(id)
  end

  def self.find_for_google(auth)
    user = User.find_or_create_by(provider: auth.provider, uid: auth.uid)

    user.update(
      provider: auth.provider, uid: auth.uid, email: auth.info.email,
      password: Devise.friendly_token[0, 20], token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      token_expires_at: auth.credentials.expires_at
    )
    user
  end

  def refresh_user_token
    options = {
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      refresh_token: refresh_token,
      grant_type: 'refresh_token'
    }
    response = HTTParty.post('https://www.googleapis.com/oauth2/v4/token', body: options)
    refreshed_access_token = response.parsed_response['access_token']
    expiration_time = Time.now.to_i + response.parsed_response['expires_in'].to_i
    update(token: refreshed_access_token, token_expires_at: expiration_time)
  end
end
