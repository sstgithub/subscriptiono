class ImapSync
  require 'net/imap'
  require 'mail'
  require 'chronic'

  # fastmail max is 8 bytes but gmail max is 4 so go with 4 (normal int in PG)
  MAX_INT = 2_147_483_647

  def initialize(user)
    @user = user
    @imap = Net::IMAP.new('imap.gmail.com', 993, usessl = true, certs = nil, verify = false)
    @user.refresh_user_token if @user.token_expires_at < Time.now.to_i
    @imap.authenticate('XOAUTH2', @user.email, @user.token)
  end

  def examine_folder(current_imap_folder_name)
    @imap.examine(current_imap_folder_name)
    uid_validity_number = @imap.responses['UIDVALIDITY'][-1]
    Folder.find_or_create_by(user: @user, uid_validity_number: uid_validity_number, name: current_imap_folder_name)
  end

  def find_and_save_new_emails(search_term = 'unsubscribe', imap_folder_names = @imap.list('', '*').map(&:name))
    imap_folder_names.each do |current_imap_folder_name|
      begin
        current_db_folder = examine_folder(current_imap_folder_name)
      rescue Net::IMAP::NoResponseError => e
        Rails.logger.debug e.message
        next
      end
      # returns sorted
      new_uid_numbers = find_emails(current_db_folder, search_term)
      new_uid_numbers.each do |uid_number|
        imap_message = Mail.read_from_string(@imap.uid_fetch(uid_number, 'RFC822')[0].attr['RFC822'])
        group_and_save_message(imap_message, uid_number, current_db_folder.id)
      end
      # update last highest uid number in db for folder
      current_db_folder.update(last_highest_uid_number: new_uid_numbers.last)
    end
  end

  def group_and_save_message(imap_message, uid_number, folder_id)
    decoded_body = get_parsed_message_body_text(imap_message)
    category, relevant_datetime = get_category_and_relevant_datetime(
      imap_message.subject,
      decoded_body.downcase,
      imap_message.date
    )

    # Rails conv from/to Time UTC when reading/writing extracted_datetime to PG
    # #(extracted_datetime is datetime col in Rails which maps to PG timestamp)
    message = Message.find_or_create_by(folder_id: folder_id, uid_number: uid_number)

    message.update(
      category: category,
      received_at: imap_message.date,
      body: decoded_body,
      subject: imap_message.subject,
      # Rails conv from/to Time UTC when reading/writing extracted_datetime to PG
      # #(extracted_datetime is datetime col in Rails which maps to PG timestamp)
      extracted_datetime: relevant_datetime,
      sender_email: imap_message.from.first
    )
  end

  def find_emails(folder, search_term = 'unsubscribe')
    last_highest_uid_number = folder.last_highest_uid_number + 1
    @imap.uid_search([
                       'UID',
                       "#{last_highest_uid_number}:#{MAX_INT}",
                       'TEXT',
                       search_term,
                       'SINCE',
                       1.year.ago.strftime('%-d-%b-%Y')
                     ])
  end

  private

  def get_category_and_relevant_datetime(subject, body, time_received)
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

  def get_parsed_message_body_text(mail)
    mail.decoded
  rescue NoMethodError => e
    # This is a bug in mail gem. Calling decoded should parse body to UTF8
    if e.message == 'Can not decode an entire message, try calling #decoded '\
      'on the various fields and body or parts if it is a multipart message.'
      mail.body.decoded
    else
      raise e
    end
  end
end
