require "rails_helper"

feature "User dashboard renders with last message received for each sender email and category combination" do
  #create user
  #create two folders for user
  #create 10 messages for folder one and 15 messages for folder 2
  #5 senders, 4 of those senders have both informational and offer emails and one has just informational email
  before do
    Timecop.freeze
    OmniAuth.config.test_mode = true

    @google_auth_data = OmniAuth::AuthHash.new(Faker::Omniauth.google)
    OmniAuth.config.mock_auth[:google_oauth2] = @google_auth_data

    user = create(:user, email: @google_auth_data.info.email, uid: @google_auth_data.uid)

    #create folders with messages with two different senders with Offer or Informational categories, received at different times
    folder = create(:folder, user: user, last_highest_uid_number: 5)
    create(:message, folder: folder, category: "Informational", sender_email: "sender1@sender1email.com", received_at: (Time.now - 1.month), uid_number: 1)
    create(:message, folder: folder, category: "Offer", sender_email: "sender1@sender1email.com", received_at: (Time.now - 1.day), uid_number: 2)
    create(:message, folder: folder, category: "Offer", sender_email: "sender1@sender1email.com", received_at: (Time.now - 1.hour), uid_number: 3)
    create(:message, folder: folder, category: "Informational", sender_email: "sender2@sender2email.com", received_at: (Time.now - 1.day), uid_number: 4)
    create(:message, folder: folder, category: "Offer", sender_email: "sender2@sender2email.com", received_at: (Time.now - 1.day), uid_number: 5)

    folder = create(:folder, user: user, last_highest_uid_number: 2)
    create(:message, folder: folder, category: "Informational", sender_email: "sender1@sender1email.com", received_at: Time.now, uid_number: 1)
    create(:message, folder: folder, category: "Offer", sender_email: "sender1@sender1email.com", received_at: (Time.now - 2.days), uid_number: 2)
    create(:message, folder: folder, category: "Informational", sender_email: "sender2@sender2email.com", received_at: (Time.now - 1.hour), uid_number: 3)

    # create(:folder_with_messages, user: user, last_highest_uid_number: 15)
    # create(:folder_with_messages, user: user, last_highest_uid_number: 10)
  end

  after do
    OmniAuth.config.test_mode = false
  end

  scenario 'renders' do
    visit root_path
    click_link "Sign in with Google"

    expect(page).to have_table(:messages_by_sender_and_category)
  end
end
