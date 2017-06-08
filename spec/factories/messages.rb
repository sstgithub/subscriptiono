FactoryGirl.define do
  factory :message do
    uid_number ""
    category "MyString"
    received_at "2017-06-04 23:34:30"
    body "MyText"
    subject "MyString"
    extracted_datetime "2017-06-04 23:34:30"
    sender_email "MyString"
  end
end
