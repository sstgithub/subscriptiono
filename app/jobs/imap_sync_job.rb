class ImapSyncJob < ApplicationJob
  queue_as :default
  require 'imap_sync'

  def perform(user)
    imap_sync = ImapSync.new(user)
    imap_sync.find_and_save_new_emails
  end
end
