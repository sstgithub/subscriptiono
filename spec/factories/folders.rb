FactoryGirl.define do
  factory :folder do
    name Faker::Name.unique
    uid_validity_number Faker::Lorem.unique.characters(10)
    last_highest_uid_number 0
    user

    # factory :folder_with_messages do
    #   transient do
    #     offers_count last_highest_uid_number
    #   end
    #
    #   after(:create) do |folder, evaluator|
    #     folder.last_highest_uid_number.times do |n|
    #       create(:message, folder: folder, uid_number: (n+1))
    #     end
    #   end
    # end

  end
end
