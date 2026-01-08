require "rails_helper"

RSpec.describe "Matching", type: :model do
  it "matchers users up well" do
    user1 = create(:user)
    user2 = create(:user)

    user1.messages.create(role: "user", content: "hello")
    user2.messages.create(role: "user", content: "Hi there")

    user1.embed
    user2.embed

    expect(user1.find_match).to eq user2
  end
end
