FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.email }
    instagram_username { Faker::Internet.username }
    password { SecureRandom.hex }
  end
end