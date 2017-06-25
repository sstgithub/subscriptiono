require 'rails_helper'

RSpec.describe ImapSyncJob, type: :job do
  before do
    Timecop.freeze
    @user = build(:user, id: 1)
    # stub out user create callback
    expect(ImapSyncJob).to receive(:perform_later).with(@user.id).exactly(:once)
    @user.save!
  end

  it 'performs imap sync and requeues job for tomorrow' do
    imap_sync = double('imap_sync')
    expect(ImapSync).to receive(:new).with(@user, ['[Gmail]/All Mail']).and_return(imap_sync)
    expect(imap_sync).to receive(:sync_new_emails)
    ImapSyncJob.perform_now(@user.id)

    expect(ImapSyncJob).to have_been_enqueued.with(@user.id).exactly(:once).at(1.day)
  end
end
