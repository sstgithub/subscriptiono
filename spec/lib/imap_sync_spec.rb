require 'rails_helper'
require 'imap_sync'

RSpec.describe "ImapSync" do
  before do
    @user = create(:user, email: "exampleuser@gmail.com", token_expires_at: (Time.now + 1.day).to_i)
  end
  it 'refreshes user token if it has expired' do
    Timecop.freeze(Time.now)
    one_hour_ago = (Time.now - 1.hour).to_i
    user = create(:user, token_expires_at: one_hour_ago)
    net_imap_init_and_auth

    expect(user.token_expires_at).to eq(one_hour_ago)

    stub_request(:post, "https://www.googleapis.com/oauth2/v4/token").to_return(body: '{"access_token": "123", "expires_in": "3600"}', headers: {"content-type": "application/json"})

    ImapSync.new(user)

    expect(user.token_expires_at).to eq(Time.now.to_i + 3600)
  end

  it 'does not refresh user token if it has not expired' do
    Timecop.freeze(Time.now)
    one_hour_from_now = (Time.now + 1.hour).to_i
    user = create(:user, token_expires_at: one_hour_from_now)
    net_imap_init_and_auth

    expect(user.token_expires_at).to eq(one_hour_from_now)

    ImapSync.new(user)

    expect(user.token_expires_at).to eq(one_hour_from_now)
  end
  describe '{for previously run on folder} get only the latest messages in folder for search term from when the job last ran on that folder' do
    before do
      create(:folder, name: "test folder", uid_validity_number: "123", user: @user)
    end


    it 'should create new folder if one doesnt exist for that uid validity number and name' do
      expect(Folder.count).to eq(1)

      imap = double("imap", responses: {"UIDVALIDITY" => [321]})


      net_imap_init_and_auth(imap)

      current_folder = double("current_folder", {name: "different name folder"})
      expect(imap).to receive(:examine).with(current_folder.name)

      imap_sync = ImapSync.new(@user)
      imap_sync.examine_folder(current_folder)

      expect(Folder.count).to eq(2)
    end

    it 'should create new folder if the uid validity number has changed//one doesnt exist for that uid validity number' do
      expect(Folder.count).to eq(1)

      imap = double("imap", responses: {"UIDVALIDITY" => [321]})


      net_imap_init_and_auth(imap)

      current_folder = double("current_folder", {name: "test folder"})
      expect(imap).to receive(:examine).with(current_folder.name)

      imap_sync = ImapSync.new(@user)
      imap_sync.examine_folder(current_folder)

      expect(Folder.count).to eq(2)
    end

    it 'should find already existing folder if uid validity number is the same' do
      expect(Folder.count).to eq(1)
      imap = double("imap", responses: {"UIDVALIDITY" => [123]})

      net_imap_init_and_auth(imap)


      current_folder = double("current_folder", {name: "test folder"})
      expect(imap).to receive(:examine).with(current_folder.name)

      imap_sync = ImapSync.new(@user)
      imap_sync.examine_folder(current_folder)

      expect(Folder.count).to eq(1)
    end

    it 'should only pull messages with uid numbers more than the last highest uid number stored on folder' do
      #folder object with last highest uid number of 50
      #find emails method should do uid_search with ["UID", "50:9223372036854775807", "TEXT", "unsubscribe"]

      folder = create(:folder, user: @user, last_highest_uid_number: 50)
      imap = double("imap")

      net_imap_init_and_auth(imap)
      expect(imap).to receive(:uid_search).with(["UID", "51:2147483647", "TEXT", "unsubscribe"])

      imap_sync = ImapSync.new(@user)
      imap_sync.find_emails(folder)
    end
  end

  describe "categorize and save message" do
    before do
      @mail = Mail.new(from: "sender@sendermail.com", date: (Time.now - 1.hour))
    end
    it 'can extract category (datetime or sale keyword) from subject' do
      # imap_fetched_message = ...
      # mail = Mail.read_from_string()...
      #
      # expect(Message).to receive(:create).with()
      #
      # imap_sync = ImapSync.new(@user)
      # imap_sync.categorize_and_save_message(Mail.new(), 55)


      #TODO: easiest way for now, but later more comprehensive mock class for this mail class?
      #TODO: make sure types are correct
      # mail = double("mail", decoded: "", date: (Time.now - 1.hour).to_i, )
      # @mail.subject = "Only 3 hours left!"


    end

    it 'can extract category (datetime or sale keyword) from body' do

    end


    it 'should categorize message as an offer and extract datetime if there is a date/time in subject' do
      @mail.subject = "Only 3 hours left!"
      net_imap_init_and_auth
      expect(Message).to receive(:create_with).with(category: "offer")

      imap_sync = ImapSync.new(@user)
      
      imap_sync.categorize_and_save_message(@mail, 51)
    end

    it 'should categorize message as an offer if there is a %/$ off keyword in subject' do

    end

    it 'should try to extract date/time if there is a %/$ off keyword in subject' do

    end

    it 'should categorize message as information if no date/time or %/$ off keyword in subject' do

    end

  end

  def net_imap_init_and_auth(imap = double("imap"))
    allow(Net::IMAP).to receive(:new).and_return(imap)
    allow(imap).to receive(:authenticate)
    imap_folders = [{name: "INBOX"}, {name: "ALL MAIL"}]
    allow(imap).to receive(:list).with("", "*").and_return(imap_folders)
  end
end
