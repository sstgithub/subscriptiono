class ImapSync
  require 'net/imap'
  require 'mail'
  require 'chronic'

  #fastmail max is 8 bytes but gmail max is 4 so go with 4 (normal int in PG)
  MAX_INT = 2147483647

  def initialize(user)
    @user = user
    @imap = Net::IMAP.new("imap.gmail.com", 993, usessl = true, certs = nil, verify = false)
    #TODO: refresh everytime so always have maximum time to complete sync? Currently could start job with only seconds left before expiration and dont know exactly how long the job will take.
    if @user.token_expires_at < Time.now.to_i
      @user.refresh_user_token
    end
    @imap.authenticate("XOAUTH2", @user.email, @user.token)
    @imap_folders = @imap.list("", "*")
  end

  def examine_folder(current_imap_folder = @imap_folders.first)
    @imap.examine(current_imap_folder.name)
    uid_validity_number = @imap.responses["UIDVALIDITY"][-1]
    Folder.find_or_create_by(user: @user, uid_validity_number: uid_validity_number, name: current_imap_folder.name)
  end

  def find_and_save_new_emails(search_term = "unsubscribe")
    @imap_folders.each do |current_imap_folder|
      begin
        current_activerecord_folder = examine_folder(current_imap_folder)
      rescue Net::IMAP::NoResponseError => e
        puts e.message
        next
      end
      new_uid_numbers = find_emails(current_activerecord_folder, search_term) #returns sorted
      new_uid_numbers.each do |uid_number|
        mail = Mail.read_from_string(@imap.uid_fetch(uid_number,'RFC822')[0].attr['RFC822'])
        if mail.date > (Time.now - 1.year)
          categorize_and_save_message(mail, uid_number)
        end
      end
      current_activerecord_folder.update(last_highest_uid_number: new_uid_numbers.last) if new_uid_numbers.last
    end
  end

  def find_emails(folder, search_term = "unsubscribe")
    last_highest_uid_number = folder.last_highest_uid_number + 1
    @imap.uid_search(["UID", "#{last_highest_uid_number}:#{MAX_INT}", "TEXT", search_term])
  end

  def categorize_and_save_message(mail, uid_number)
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

      message = Message.where(uid_number: uid_number).first_or_create
      #relevant_datetime is a Time object converted to DateTime UTC by Rails before saving to PG
      message.update(category: category, received_at: time_received, body: decoded_body, subject: mail.subject, extracted_datetime: relevant_datetime, sender_email: mail.from)

      last_highest_uid_number = uid_number
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
    # Chronic.parse(body.scan(/(ends |expires )(.*?)at/).first)
    hits = body.scan(/(ends at|expires at|valid through) (.*?)(,)/)
    if !hits.blank?
      #parse extracted time based on when messaged was received
      Chronic.parse(hits.first[1], now: time_received, context: :future) #Time obj
    end
  end
end
