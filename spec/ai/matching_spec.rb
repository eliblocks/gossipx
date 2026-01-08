require "rails_helper"

RSpec.describe "Matching", type: :model do
  it "matchers users up well" do
    user1 = create(:user)
    user2 = create(:user)

    user1.messages.create(role: "user", content: "hello")
    user2.messages.create(role: "user", content: "Hi there")

    user1.embed
    user2.embed

    MATCHING_DEFAULT_PROMPT =
      <<~HEREDOC
        For the current user conversation, find the single best matching user conversation.
        The best matching conversation is the one we would most want to refer to when speaking with the current user.
        The best matching conversation could be interesting or funny or relevant or useful in some way.

        ---

        Current user conversation:
        {{current_user_conversation}}

        ---

        Other user conversations:
        {{similar_conversations}}

        Return only the username of the best conversation.
      HEREDOC

    expect(user1.find_match(MATCHING_DEFAULT_PROMPT)).to eq user2
  end
end
