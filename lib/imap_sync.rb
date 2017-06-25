# Syncs new messages from folder(s) in user's email based on search term
# # Uses UID number in messages and UIDValidity from folders to ensure only
# # new messages are synced
class ImapSync
  require 'net/imap'
  require 'mail'
  require 'chronic'
  # require 'imap_sync/folder'

  # fastmail max is 8 bytes but gmail max is 4 so go with 4 (normal int in PG)
  MAX_INT = 2_147_483_647

  def initialize(*args)
    @user, @imap_folder_names = args
    # params: host, port/options, usessl?, certificates file or dir, verify?
    # #Hardcoded to Gmail for now
    @imap = Net::IMAP.new('imap.gmail.com', 993, true, nil, false)
    @user.refresh_user_token if @user.token_expires_at < Time.now.to_i
    @imap.authenticate('XOAUTH2', @user.email, @user.token)
    @imap_folder_names ||= @imap.list('', '*').map(&:name)
  end

  def sync_new_messages(search_term = 'unsubscribe')
    @imap_folder_names.each do |imap_folder_name|
      db_folder = examine_folder(imap_folder_name)
      # Go to next folder if this one returns an IMAP NoResponseError
      next unless db_folder
      sorted_uid_nums = search_folder(db_folder, search_term)
      sorted_uid_nums.each do |uid_num|
        msg = fetch_imap_msg(uid_num)
        # Get category & offer date, if any. Later this will get prices and
        # names of products offered as well
        msg[:category], msg[:extracted_datetime] = analyze_and_extract(
          msg[:subject], msg[:body], msg[:received_at]
        )

        save_msg(db_folder.id, uid_num, msg)
      end
      # update last highest uid number in db for folder
      db_folder.update(last_highest_uid_number: new_uid_numbers.last)
    end
  end

  def search_folder(folder, search_term = 'unsubscribe')
    last_highest_uid_number = folder.last_highest_uid_number + 1
    @imap.uid_search([
                       'UID', "#{last_highest_uid_number}:#{MAX_INT}",
                       'TEXT', search_term,
                       'SINCE', 1.year.ago.strftime('%-d-%b-%Y')
                     ])
  end

  def fetch_imap_msg(uid_num)
    imap_msg = @imap.uid_fetch(uid_num, 'RFC822')[0].attr['RFC822']
    parsed_imap_msg = Mail.read_from_string(imap_msg)
    parsed_body = parse_msg_body(parsed_imap_msg)
    {
      body: parsed_body, sender_email: parsed_imap_msg.from.first,
      subject: parsed_imap_msg.subject, received_at: parsed_imap_msg.date
    }
  end

  def save_msg(folder_id, uid_num, msg_params)
    db_msg = Message.find_or_create_by(
      folder_id: folder_id, uid_number: uid_num
    )
    db_msg.update(msg_params)
  end

  def examine_folder(imap_folder_name)
    @imap.examine(imap_folder_name)
    uid_validity_number = @imap.responses['UIDVALIDITY'][-1]
    Folder.find_or_create_by(
      user: @user,
      uid_validity_number: uid_validity_number,
      name: imap_folder_name
    )
  rescue Net::IMAP::NoResponseError => e
    Rails.logger.debug e.message
    false
  end

  def analyze_and_extract(subject, body, time_received)
    body = body.downcase
    # extracted_datetime is Rails datetime col which maps to PG timestamp
    # Rails converts this from/to Time UTC when reading/writing to PG
    datetime = extract_relevant_datetime_from_subject(subject, time_received)

    if datetime.present?
      ['Offer', datetime]
    # if any $... or ...% in subject line.
    elsif subject.scan(/(\$\d+|\d+\%)/).present?
      # determine offer expiration if any from email body
      ['Offer', extract_relevant_datetime_from_body(body, time_received)]
    else
      'Informational'
    end
  end

  private

  def extract_relevant_datetime_from_subject(subject, time_received)
    time_till_expiration = subject.downcase.scan(/(\d+ hour|\d+ day)/)
    return time_till_expiration if time_till_expiration.blank?
    # Get string from first result array from returned array of arrays
    # # Turn string into array of two words
    # Example: [["3 hour"], ["2 day"]] => ["3", "hour"]
    amount_of_time_unit, time_unit = time_till_expiration.first.last.split(' ')
    begin
      # Rails time parsing. Example: 3.hour or 2.day. Will be Time obj
      extracted_time_left = amount_of_time_unit.to_i.send(time_unit)
      # date from imap (time_received) is already Time obj
      time_received + extracted_time_left
    rescue ArgumentError => e
      raise e unless e.message == 'invalid date'
    end
  end

  def extract_relevant_datetime_from_body(body, time_received)
    hits = body.scan(/(ends at|expires at|valid through) (.*?)(,)/)
    return hits if hits.blank?
    # parse extracted time based on when messaged was received
    # # creates a Time obj
    Chronic.parse(hits.first[1], now: time_received, context: :future)
  end

  def parse_msg_body(mail)
    mail.decoded
  rescue NoMethodError => e
    # Due to bug in mail gem. Calling decoded should always parse body to UTF8
    if e.message == 'Can not decode an entire message, try calling #decoded '\
      'on the various fields and body or parts if it is a multipart message.'
      mail.body.decoded
    else
      raise e
    end
  end
end
