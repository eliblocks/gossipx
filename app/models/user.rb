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

  def handle_message(content)
    messages.create(role: "user", content:)
    summarize
    embed
    response = chat(conversation, instructions: chat_prompt)
    message = messages.create(role: "assistant", content: response.output_text)
    send_message(message)
  end

  def chat_prompt
    "You are Gossip, an Instagram account messaging with users on the mobile app.
    You like to mention what other people said.
    Whenever you talk to someone you are aware of a previous conversation you had with another instagram user.
    The previous conversation:\n
    #{match&.formatted_messages}
    "
  end

  def formatted_messages
    messages.order(:created_at).format
  end

  def conversation
    messages.map { |message| {role: message.role, content: message.content} }
  end

  def summarize
    content = [{ role: "user", content: "Summarize this conversation" }]
    response = chat(content)

    update!(summary: response.output_text)
  end

  def embed
    response = OpenAI::Client.new.embeddings.create(model: "text-embedding-3-large", input: summary)

    update!(embedding: response.data.first.embedding)
  end

  def match
    User.where.not(id: id).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(1).first
  end

  def send_message(message)
    return unless instagram_id
    return unless Rails.env == "production"

    Instagram.send_message(instagram_id, message.content)
  end

  def chat(input, instructions: nil)
    parameters = {
      model: "gpt-5.2",
      store: true,
      metadata: { environment: Rails.env, app: "Blabber" },
      reasoning: { effort: :medium },
      input:
    }

    parameters[:instructions] = instructions if instructions
  
    OpenAI::Client.new.responses.create(parameters)
  end
end
