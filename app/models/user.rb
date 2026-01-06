class User < ApplicationRecord
  # :confirmable, :lockable, :timeoutable, :trackable, :omniauthable, :registerable,
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :messages
  has_neighbors :embedding

  validates :instagram_id, uniqueness: true, allow_nil: true
  validates :instagram_username, uniqueness: true, allow_nil: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def handle_message(content, now=false)
    messages.create!(role: "user", content:)

    now ? ReplyJob.perform_now(id) : ReplyJob.perform_later(id)
  end

  def reply
    summarize
    embed
    match = find_match
    system_prompt = (match ? match_prompt(match) : no_match_prompt)
    response = Ai.chat(conversation, instructions: system_prompt)
    message = messages.create!(role: "assistant", content: response)
    send_message(message)
  end

  def no_match_prompt
    "You are Gossip, an Instagram account messaging with users on the mobile app.
    You're nosy, you use creative conversational skills to get people to open up and share something like whats going on with them, what they are interested in.
    Prompt people to say something substantive, be highly engaging."
  end

  def match_prompt(match)
    "You are Gossip, an Instagram account messaging with users on the mobile app.
    You're nosy, you use creative conversational skills to get people to open up and share something like whats going on with them, what they are interested in.
    Prompt people to say something substantive, be highly engaging. But be concise, you are chatting on mobile.

    Now here's a twist: You have context into a related conversation you previously had with a different user. You do not hallucinate, you only refer to the actual conversation.
    You prefer if possible to find a natural way to refer to this other user.

    Your previous conversation with @#{match.instagram_username}:
    #{match.filtered_messages}
    "
  end

  def summary_prompt
    <<~HEREDOC
     "Summarize the following conversation by rewriting it as though it were written all at once by the user.
     The summary should not include any information about other people mentioned by the bot,
     but it should take into account the entire conversation to most accurately frame it as a message or post from the user

     Conversation:

     \n<#{formatted_messages}>"


     Return the summary directly
    HEREDOC
  end

  def formatted_messages
    messages.order(:created_at).format
  end

  def filtered_messages
    formatted_messages.gsub(/@\w+/, "@********")
  end

  def conversation
    messages.map { |message| {role: message.role, content: message.content} }
  end

  def summarize
    new_summary = ""

    if messages.where(role: "user").count > 1
      contents = [{ role: "user", content: summary_prompt }]
      new_summary = Ai.chat(contents)
    else
      new_summary = messages.where(role: "user").first.content
    end

    update!(summary: new_summary)
  end

  def embed
    response = OpenAI::Client.new.embeddings.create(model: "text-embedding-3-large", input: summary)

    update!(embedding: response.data.first.embedding)
  end

  def similar
    User.where.not(id: id).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(20)
  end

  def formatted
    "#{id} - #{summary}"
  end

  def formatted_similar
    similar.map(&:formatted).split("\n")
  end

  def best_match_prompt
    <<~HEREDOC
      For the current user summary, find the single best matching user summary.
      The best matching summary is the one we would most want to refer to when speaking with the current user.
      The best matching summary could be interesting or funny or relevant or useful in some way.

      This user summary:
      #{summary}

      =====================

      Other user summaries:
      #{formatted_similar}

      Return only the id of the best user summary.
    HEREDOC
  end

  def find_match
    contents = [{ role: "user", content: best_match_prompt }]
    user_id = Ai.chat(contents)
    User.find_by(id: user_id)
  end

  def send_message(message)
    return unless instagram_id
    return unless Rails.env == "production"

    Instagram.send_message(instagram_id, message.content)
  end
end
