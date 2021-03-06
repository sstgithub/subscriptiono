class ImapSyncJob < ApplicationJob
  queue_as :default
  require 'imap_sync'

  after_perform do |job|
    # queue to run again tomorrow with same user
    ImapSyncJob.set(wait_until: 1.day).perform_later(job.arguments.first)
  end

  def perform(user_id)
    user = User.find(user_id)
    imap_sync = ImapSync.new(user, ['[Gmail]/All Mail'])
    # for gmail only need to examine the '[Gmail]All Mail' folder
    # #this folder has all mail and cannot be renamed or deleted by user
    imap_sync.sync_new_messages('unsubscribe')
  end
end
