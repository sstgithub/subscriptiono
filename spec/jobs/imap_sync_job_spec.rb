require 'rails_helper'

RSpec.describe ImapSyncJob, type: :job do
  before do
    Timecop.freeze
    @user = build(:user)
    #stub out user create callback. TODO: better way to do this?
    expect(ImapSyncJob).to receive(:perform_later).with(@user).exactly(:once)
    @user.save!
  end

  it 'performs imap sync and requeues job for tomorrow' do
    imap_sync = double("imap_sync")
    expect(ImapSync).to receive(:new).with(@user).and_return(imap_sync)
    expect(imap_sync).to receive(:find_and_save_new_emails)
    ImapSyncJob.perform_now(@user)

    expect(ImapSyncJob).to have_been_enqueued.with(@user).exactly(:once).at(1.day)
  end
end
