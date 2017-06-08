require 'rails_helper'
require 'imap_sync'

RSpec.describe "ImapSync" do
  describe '{for previously run on folder} get only the latest messages in folder for search term from when the job last ran on that folder' do
    before do
      @user = create(:user, token_expires_at: (Time.now + 1.day).to_i)
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
    it 'can extract category (datetime or sale keyword) from subject' do

    end

    it 'can extract category (datetime or sale keyword) from body' do

    end


    it 'should categorize message as an offer if there is a date/time in subject' do

    end

    it 'should categorize message as an offer if there is a %/$ off keyword in subject' do

    end

    it 'should try to extract date/time if there is a %/$ off keyword in subject' do

    end

    it 'should categorize message as information if no date/time or %/$ off keyword in subject' do

    end

  end

  def net_imap_init_and_auth(imap)
    allow(Net::IMAP).to receive(:new).and_return(imap)
    allow(imap).to receive(:authenticate)
    imap_folders = [{name: "INBOX"}, {name: "ALL MAIL"}]
    allow(imap).to receive(:list).with("", "*").and_return(imap_folders)
  end
end
