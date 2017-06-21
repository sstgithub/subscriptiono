class ImapSync
  require 'net/imap'
  require 'mail'
  require 'chronic'

  #fastmail max is 8 bytes but gmail max is 4 so go with 4 (normal int in PG)
  MAX_INT = 2147483647

  def initialize(user)
    @user = user
    @imap = Net::IMAP.new("imap.gmail.com", 993, usessl = true, certs = nil, verify = false)
    if @user.token_expires_at < Time.now.to_i
      @user.refresh_user_token
    end
    @imap.authenticate("XOAUTH2", @user.email, @user.token)
  end

  def examine_folder(current_imap_folder_name)
    @imap.examine(current_imap_folder_name)
    uid_validity_number = @imap.responses["UIDVALIDITY"][-1]
    Folder.find_or_create_by(user: @user, uid_validity_number: uid_validity_number, name: current_imap_folder_name)
  end

  def find_and_save_new_emails(search_term = "unsubscribe", imap_folder_names = @imap.list("", "*").map(&:name))
    imap_folder_names.each do |current_imap_folder_name|
      begin
        current_activerecord_folder = examine_folder(current_imap_folder_name)
      rescue Net::IMAP::NoResponseError => e
        Rails.logger.debug e.message
        next
      end
      new_uid_numbers = find_emails(current_activerecord_folder, search_term) #returns sorted
      new_uid_numbers.each do |uid_number|
        mail = Mail.read_from_string(@imap.uid_fetch(uid_number,'RFC822')[0].attr['RFC822'])
        if mail.date > (Time.now - 1.year)
          last_highest_uid_number = categorize_and_save_message(mail, uid_number, current_activerecord_folder.id)
        end
      end
      #update last highest uid number in db for folder
      if last_higest_uid_number
        current_activerecord_folder.update(last_highest_uid_number: last_higest_uid_number)
      end
    end
  end

  def find_emails(folder, search_term = "unsubscribe")
    last_highest_uid_number = folder.last_highest_uid_number + 1
    @imap.uid_search(["UID", "#{last_highest_uid_number}:#{MAX_INT}", "TEXT", search_term])
  end

  def categorize_and_save_message(mail, uid_number, folder_id)
      begin
        decoded_body = mail.decoded
      rescue NoMethodError => e
        #This is a bug in mail gem. Calling decoded should parse body to UTF8
        if e.message == "Can not decode an entire message, try calling #decoded on the various fields and body or parts if it is a multipart message."
          decoded_body = mail.body.decoded
        else
          raise e
        end
      end
      # time_received = Time.at(mail.date.to_i)
      time_received = mail.date #mail date is already Time object
      category, relevant_datetime = get_category_and_relevant_datetime(mail.from, mail.subject, decoded_body.downcase, time_received)

      message = Message.where(folder_id: folder_id, uid_number: uid_number).first_or_create
      #NOTE: Rails converts from/to Time UTC when reading/writing extracted_datetime to PG
      ##(extracted_datetime is datetime col in Rails which maps to PG timestamp)
      message.update(category: category, received_at: time_received, body: decoded_body, subject: mail.subject, extracted_datetime: relevant_datetime, sender_email: mail.from.first)

      uid_number
  end

  private

  def get_category_and_relevant_datetime(sender_email, subject, body, time_received)
    relevant_datetime = extract_relevant_datetime_from_subject(subject, time_received)

    if relevant_datetime
      category = "Offer"
    else
      #if any $... or ...% in subject line. typically wont spell out word since limited characters available
      if !subject.scan(/(\$\d+|\d+\%)/).blank?
        category = "Offer"
        #determine offer expiration if any from email body
        relevant_datetime = extract_relevant_datetime_from_body(body, time_received)
      else
        category = "Informational"
      end
    end

    [category, relevant_datetime]
  end

  def extract_relevant_datetime_from_subject(subject, time_received)
    time_till_expiration = subject.downcase.scan(/(\d+ hour|\d+ day)/)
    if !time_till_expiration.blank?
      time_till_expiration_to_use = time_till_expiration.first.last.split(" ")
      begin
        extracted_time_left = (time_till_expiration_to_use[0].to_i).send(time_till_expiration_to_use[1])
        time_received + extracted_time_left
      rescue ArgumentError => e
        unless e.message == "invalid date"
          raise e
        end
      end
    end
  end

  def extract_relevant_datetime_from_body(body, time_received)
    hits = body.scan(/(ends at|expires at|valid through) (.*?)(,)/)
    if !hits.blank?
      #parse extracted time based on when messaged was received
      Chronic.parse(hits.first[1], now: time_received, context: :future) #Time obj
    end
  end
end
