require 'rails_helper'
require 'imap_sync'

RSpec.describe 'ImapSync' do
  before do
    Timecop.freeze(Time.now)
    @user = create(:user, email: 'exampleuser@gmail.com', token_expires_at: (Time.now + 1.day).to_i)
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
      create(:folder, name: 'test folder', uid_validity_number: '123', user: @user)
    end

    it 'should create new folder if one doesnt exist for that uid validity number and name' do
      expect(Folder.count).to eq(1)

      imap = double('imap', responses: { 'UIDVALIDITY' => [321] })

      net_imap_init_and_auth(imap)

      current_folder = double('current_folder', name: 'different name folder')
      expect(imap).to receive(:examine).with(current_folder.name)

      imap_sync = ImapSync.new(@user)
      imap_sync.examine_folder(current_folder.name)

      expect(Folder.count).to eq(2)
    end

    it 'should create new folder if the uid validity number has changed//one doesnt exist for that uid validity number' do
      expect(Folder.count).to eq(1)

      imap = double('imap', responses: { 'UIDVALIDITY' => [321] })

      net_imap_init_and_auth(imap)

      current_folder = double('current_folder', name: 'test folder')
      expect(imap).to receive(:examine).with(current_folder.name)

      imap_sync = ImapSync.new(@user)
      imap_sync.examine_folder(current_folder.name)

      expect(Folder.count).to eq(2)
    end

    it 'should find already existing folder if uid validity number is the same' do
      expect(Folder.count).to eq(1)
      imap = double('imap', responses: { 'UIDVALIDITY' => [123] })

      net_imap_init_and_auth(imap)

      current_folder = double('current_folder', name: 'test folder')
      expect(imap).to receive(:examine).with(current_folder.name)

      imap_sync = ImapSync.new(@user)
      imap_sync.examine_folder(current_folder.name)

      expect(Folder.count).to eq(1)
    end

    it 'should only pull messages with uid numbers more than the last highest uid number stored on folder' do
      # folder object with last highest uid number of 50
      # find emails method should do uid_search with ['UID', '50:9223372036854775807', 'TEXT', 'unsubscribe']

      folder = create(:folder, user: @user, last_highest_uid_number: 50)
      imap = double('imap')

      net_imap_init_and_auth(imap)
      expect(imap).to receive(:uid_search).with(['UID', '51:2147483647', 'TEXT', 'unsubscribe', 'SINCE', 1.year.ago.strftime('%-d-%b-%Y')])

      imap_sync = ImapSync.new(@user)
      imap_sync.search_folder(folder)
    end
  end

  describe 'analyze message' do
    before do
      @mail = Mail.new(from: 'sender@sendermail.com', date: Time.now)
      @folder = create(:folder, name: 'test folder', uid_validity_number: '123', user: @user)
    end

    it 'as an offer if there is a %/$ off keyword in subject' do
      @mail.subject = '$100 off iPads'
      @mail.body = 'Nothing to see here'
      net_imap_init_and_auth

      imap_sync = ImapSync.new(@user)
      category, extracted_datetime = imap_sync.analyze_and_extract(@mail.subject, @mail.body.decoded, Time.now)

      expect(category).to eq('Offer')
      expect(extracted_datetime).to be_blank
    end

    it 'as an offer with datetime if there is a date/time in subject' do
      @mail.subject = 'Only 3 hours left!'
      @mail.body = 'Nothing to see here'
      net_imap_init_and_auth

      imap_sync = ImapSync.new(@user)
      category, extracted_datetime = imap_sync.analyze_and_extract(@mail.subject, @mail.body.decoded, Time.now)

      expect(category).to eq('Offer')
      expect(extracted_datetime.to_i).to eq((DateTime.now.utc + 3.hours).to_i)
    end

    it 'as an offer with datetime from body if there is a %/$ off keyword in subject' do
      @mail.subject = '$100 off iPads'
      @mail.body = "The best offer ever! Valid through #{(DateTime.now + 3.days).strftime('%B %d, %Y')}"
      net_imap_init_and_auth

      imap_sync = ImapSync.new(@user)
      category, extracted_datetime = imap_sync.analyze_and_extract(@mail.subject, @mail.body.decoded, Time.now)

      expect(category).to eq('Offer')
      expect(extracted_datetime.to_i).to eq((DateTime.now + 3.days).middle_of_day.utc.to_i)
    end

    it 'as information if no keywords indicating offer in subject or body' do
      @mail.subject = 'The new iPads are out!'
      @mail.body = 'Nothing to see here'
      net_imap_init_and_auth

      imap_sync = ImapSync.new(@user)
      category, extracted_datetime = imap_sync.analyze_and_extract(@mail.subject, @mail.body.decoded, Time.now)

      expect(category).to eq('Informational')
      expect(extracted_datetime).to be_blank
    end
  end

  describe 'sync new messages' do
    it 'iterates over each folder' do
      net_imap_init_and_auth

      imap_sync = ImapSync.new(@user)
      db_folder = double('db_folder')

      expect(imap_sync).to receive(:examine_folder).with('INBOX').and_return(db_folder)
      expect(imap_sync).to receive(:examine_folder).with('ALL MAIL').and_return(db_folder)

      expect(imap_sync).to receive(:search_folder).with(db_folder, 'unsubscribe').and_return([1, 2, 3]).twice
      expect(imap_sync).to receive(:fetch_and_save_msgs_by_uid_nums).with([1, 2, 3]).twice
      expect(db_folder).to receive(:update).with(last_highest_uid_number: 3).twice

      imap_sync.sync_new_messages('unsubscribe')
    end

    it 'skips a non-responsive folder' do
      net_imap_init_and_auth

      imap_sync = ImapSync.new(@user)
      db_folder = double('db_folder')

      expect(imap_sync).to receive(:examine_folder).with('INBOX').and_return(false)
      expect(imap_sync).to receive(:examine_folder).with('ALL MAIL').and_return(db_folder)

      expect(imap_sync).to receive(:search_folder).with(db_folder, 'unsubscribe').and_return([1, 2, 3]).once
      expect(imap_sync).to receive(:fetch_and_save_msgs_by_uid_nums).with([1, 2, 3]).once
      expect(db_folder).to receive(:update).with(last_highest_uid_number: 3).once

      imap_sync.sync_new_messages
    end
  end

  def net_imap_init_and_auth(imap = double('imap'))
    allow(Net::IMAP).to receive(:new).and_return(imap)
    allow(imap).to receive(:authenticate)
    imap_folders = [Net::IMAP::MailboxList.new([:Hasnochildren], '/', 'INBOX'), Net::IMAP::MailboxList.new([:Hasnochildren], '/', 'ALL MAIL')]
    allow(imap).to receive(:list).with('', '*').and_return(imap_folders)
  end
end
