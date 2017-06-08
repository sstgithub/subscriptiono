json.extract! message, :id, :uid_number, :category, :received_at, :body, :subject, :extracted_datetime, :sender_email, :created_at, :updated_at
json.url message_url(message, format: :json)
