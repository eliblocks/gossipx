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
    previous_messages = messages.order(:created_at).to_a
    message = claude.chat(previous_messages, system_prompt: system_prompt, tools: [reflect_tool], type: "conversation")
    send_message(message)
  end

  def reflect_tool
    {
      name: "reflect",
      description: "Search for related content",
      input_schema: {
        type: "object",
        properties: {},
      }
    }
  end

  def system_prompt
    "You are Gossip, an Instagram account messaging with users on the mobile app.
    You're nosy, you use creative conversational skills to get people to open up and share something like whats going on with them, what they are interested in.
    Prompt people to say something substantive, be highly engaging. But be concise, you are chatting on mobile. When a user has added information to the conversation, call reflect.
    The function will respond with information from a related conversation that you can share to keep up your end."
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

  def reflect
    embed
    best_match = find_match
    extract_content(best_match)
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
    response = OpenAI::Client.new.embeddings.create(model: "text-embedding-3-large", input: formatted_messages)

    update!(embedding: response.data.first.embedding)
  end

  def similar
    User.where.not(id: id).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(20)
  end

  def formatted_similar
    similar.map(&:formatted_messages).split("\n")
  end

  def extraction_prompt(matching_user)
     <<~HEREDOC
      For the current user conversation, consider the matching conversation and extract something relevant in the form of @so-and-so said ...

      This conversation:
      #{formatted_messages}

      =====================
      #{matching_user.formatted_messages}
    HEREDOC
  end

  def extract_content(matching_user)
    contents = [{ role: "user", content: extraction_prompt(matching_user) }]
    Ai.chat(contents)
  end


  def best_match_prompt
    <<~HEREDOC
      For the current user conversation, find the single best matching user conversation.
      The best matching conversation is the one we would most want to refer to when speaking with the current user.
      The best matching conversation could be interesting or funny or relevant or useful in some way.

      This user conversation:
      #{formatted_messages}

      =====================

      Other user conversations:
      #{formatted_similar}

      Return only the username of the best conversation.
    HEREDOC
  end

  def find_match
    contents = [{ role: "user", content: best_match_prompt }]
    match_username = Ai.chat(contents).gsub("@", "")
    User.find_by(instagram_username: match_username)
  end

  def send_message(message)
    return unless instagram_id
    return unless Rails.env == "production"

    Instagram.send_message(instagram_id, message.content)
  end

  def claude
    Claude.new(self)
  end
end
