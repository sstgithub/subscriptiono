class User < ApplicationRecord
  has_many :folders
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  after_create do
    ImapSyncJob.perform_later(self)
  end


   def self.find_for_google(auth)
     data = auth.info
     user = User.where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
       user.provider = auth.provider
       user.uid = auth.uid
       user.email = auth.info.email
       user.password = Devise.friendly_token[0,20]
     end
     user.token = auth.credentials.token
     user.refresh_token = auth.credentials.refresh_token
     user.token_expires_at = auth.credentials.expires_at #integer
     user.save
     user
   end

   def refresh_user_token
     options = {
       client_id: ENV["GOOGLE_CLIENT_ID"],
       client_secret: ENV["GOOGLE_CLIENT_SECRET"],
       refresh_token: self.refresh_token,
       grant_type: "refresh_token"
     }
     response = HTTParty.post("https://www.googleapis.com/oauth2/v4/token", body: options)
     refreshed_access_token = response.parsed_response['access_token']
     expiration_time = Time.now.to_i + response.parsed_response['expires_in'].to_i
     self.update(token: refreshed_access_token, token_expires_at: expiration_time)
   end

end
