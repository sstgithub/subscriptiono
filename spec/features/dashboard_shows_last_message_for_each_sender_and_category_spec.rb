require 'rails_helper'

feature 'User dashboard renders with last message received for each sender email and category combination' do
  before do
    Timecop.freeze
    OmniAuth.config.test_mode = true

    @google_auth_data = OmniAuth::AuthHash.new(Faker::Omniauth.google)
    OmniAuth.config.mock_auth[:google_oauth2] = @google_auth_data

    user = create(:user, email: @google_auth_data.info.email, uid: @google_auth_data.uid)

    #create two folders for user with messages by sender 1 and sender 2 and with category 'Offer' or 'Informational'
    folder = create(:folder, user: user, last_highest_uid_number: 5)
    create(:message, folder: folder, category: 'Informational', sender_email: 'sender1@sender1email.com', received_at: (Time.now - 1.month), subject: 'Some info by Sender 1', uid_number: 1)
    create(:message, folder: folder, category: 'Offer', sender_email: 'sender1@sender1email.com', received_at: (Time.now - 1.day), subject: 'New offer by Sender 1!', extracted_datetime: (Time.now), uid_number: 2)
    #Sender 1: last received offer
    create(:message, folder: folder, category: 'Offer', sender_email: 'sender1@sender1email.com', received_at: (Time.now - 1.hour), subject: 'New offer by Sender 1!', extracted_datetime: (Time.now + 4.days), uid_number: 3)
    create(:message, folder: folder, category: 'Informational', sender_email: 'sender2@sender2email.com', received_at: (Time.now - 1.day), subject: 'Some info by Sender 2', uid_number: 4)
    #Sender 2: last received offer
    create(:message, folder: folder, category: 'Offer', sender_email: 'sender2@sender2email.com', received_at: (Time.now - 1.minute), subject: 'New offer by Sender 2!', uid_number: 5)

    folder = create(:folder, user: user, last_highest_uid_number: 2)
    #Sender 1: last received information
    create(:message, folder: folder, category: 'Informational', sender_email: 'sender1@sender1email.com', received_at: Time.now, subject: 'Some info by Sender 1', uid_number: 1)
    create(:message, folder: folder, category: 'Offer', sender_email: 'sender1@sender1email.com', received_at: (Time.now - 2.days), subject: 'New offer by Sender 1!', uid_number: 2)
    #Sender 2: last received information
    create(:message, folder: folder, category: 'Informational', sender_email: 'sender2@sender2email.com', received_at: (Time.now - 1.hour), subject: 'Some info by Sender 2', uid_number: 3)
  end

  after do
    OmniAuth.config.test_mode = false
  end

  scenario 'renders' do
    visit root_path
    click_link 'Sign in with Google'

    expect(page).to have_table(:messages_by_sender_and_category)

    within('table#messages_by_sender_and_category') do
      within('thead') do
        #one  row with expected headers
        expect(all('tr').length).to eq(1)
        header_columns = first('tr').all('th')

        expect(header_columns[0].text).to eq('Sender category')
        expect(header_columns[1].text).to eq('Sender email')
        expect(header_columns[2].text).to eq('Received')
        expect(header_columns[3].text).to eq('Subject')
        expect(header_columns[4].text).to eq('Extracted datetime')
      end

      within('tbody') do
        #4 content rows with latest relevant message in informational and offer category for both senders, sorted by received_at datetime
        expect(all('tr').length).to eq(4)
        all('tr').each_with_index do |row, index|
          columns = row.all('td')
          case index
          when 0
            expect(columns[0].text).to eq('Informational')
            expect(columns[1].text).to eq('sender1@sender1email.com')
            expect(columns[2].text).to eq('less than a minute ago')
            expect(columns[3].text).to eq('Some info by Sender 1')
            expect(columns[4].text).to be_empty
          when 1
            expect(columns[0].text).to eq('Offer')
            expect(columns[1].text).to eq('sender2@sender2email.com')
            expect(columns[2].text).to eq('1 minute ago')
            expect(columns[3].text).to eq('New offer by Sender 2!')
            expect(columns[4].text).to be_empty
          when 2
            expect(columns[0].text).to eq('Offer')
            expect(columns[1].text).to eq('sender1@sender1email.com')
            expect(columns[2].text).to eq('about 1 hour ago')
            expect(columns[3].text).to eq('New offer by Sender 1!')
            expect(columns[4].text).to eq('4 days left')
          when 3
            expect(columns[0].text).to eq('Informational')
            expect(columns[1].text).to eq('sender2@sender2email.com')
            expect(columns[2].text).to eq('about 1 hour ago')
            expect(columns[3].text).to eq('Some info by Sender 2')
            expect(columns[4].text).to be_empty
          end
        end
      end
    end
  end
end
