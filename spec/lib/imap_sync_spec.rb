require 'rails_helper'
require 'imap_sync'

RSpec.describe "ImapSync" do
  before do
    Timecop.freeze(Time.now)
    @user = create(:user, email: "exampleuser@gmail.com", token_expires_at: (Time.now + 1.day).to_i)
  end

  it 'refreshes user token if it has expired' do
    one_hour_ago = (Time.now - 1.hour).to_i
    user = create(:user, token_expires_at: one_hour_ago)
    net_imap_init_and_auth

    expect(user).to receive(:refresh_user_token)

    ImapSync.new(user)
  end

  it 'does not refresh user token if it has not expired' do
    one_hour_from_now = (Time.now + 1.hour).to_i
    user = create(:user, token_expires_at: one_hour_from_now)
    net_imap_init_and_auth

    expect(user).not_to receive(:refresh_user_token)

    ImapSync.new(user)
  end
  describe 'examine folder' do
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
      @mail = Mail.new(from: "sender@sendermail.com", date: Time.now)
    end

    it 'as an offer if there is a %/$ off keyword in subject' do
      @mail.subject = "$100 off iPads"
      @mail.body = "Nothing to see here"
      net_imap_init_and_auth
      create(:message, uid_number: 51)

      imap_sync = ImapSync.new(@user)
      imap_sync.categorize_and_save_message(@mail, 51)

      message = Message.find_by_uid_number(51)

      expect(message.category).to eq("Offer")
    end

    it 'as an offer with datetime if there is a date/time in subject' do
      @mail.subject = "Only 3 hours left!"
      @mail.body = "Nothing to see here"
      net_imap_init_and_auth
      create(:message, uid_number: 51)

      imap_sync = ImapSync.new(@user)
      imap_sync.categorize_and_save_message(@mail, 51)

      message = Message.find_by_uid_number(51)

      expect(message.category).to eq("Offer")
      expect(message.extracted_datetime.to_i).to eq((DateTime.now.utc + 3.hours).to_i)
    end

    it 'as an offer with datetime from body if there is a %/$ off keyword in subject' do
      @mail.subject = "$100 off iPads"
      @mail.body = "The best offer ever! Valid through #{(DateTime.now + 3.days).strftime("%B %d, %Y")}"
      net_imap_init_and_auth
      create(:message, uid_number: 51)

      imap_sync = ImapSync.new(@user)
      imap_sync.categorize_and_save_message(@mail, 51)

      message = Message.find_by_uid_number(51)

      expect(message.category).to eq("Offer")
      expect(message.extracted_datetime.to_i).to eq((DateTime.now + 3.days).middle_of_day.utc.to_i)
    end

    it 'as information if no keywords indicating offer in subject or body' do
      @mail.subject = "The new iPads are out!"
      @mail.body = "Nothing to see here"
      net_imap_init_and_auth
      create(:message, uid_number: 51)

      imap_sync = ImapSync.new(@user)
      imap_sync.categorize_and_save_message(@mail, 51)

      message = Message.find_by_uid_number(51)

      expect(message.category).to eq("Informational")
      expect(message.extracted_datetime).to be_nil
    end

  end

  def net_imap_init_and_auth(imap = double("imap"))
    allow(Net::IMAP).to receive(:new).and_return(imap)
    allow(imap).to receive(:authenticate)
    imap_folders = [{name: "INBOX"}, {name: "ALL MAIL"}]
    allow(imap).to receive(:list).with("", "*").and_return(imap_folders)
  end
end
