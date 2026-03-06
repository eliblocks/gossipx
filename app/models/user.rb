class User < ApplicationRecord
  # :confirmable, :lockable, :timeoutable, :trackable, :omniauthable, :registerable,
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :messages, dependent: :destroy
  has_neighbors :embedding

  validates :instagram_id, uniqueness: true, allow_nil: true
  validates :instagram_username, uniqueness: true, allow_nil: true
  validates :phone, uniqueness: true, allow_nil: true

  include Prompts

  def full_name
    "#{first_name} #{last_name}"
  end

  DAILY_MESSAGE_LIMIT = 50
  MONTHLY_MESSAGE_LIMIT = 500
  MAX_CONVERSATION_LENGTH = 30_000

  def system_prompt
    "You are an Instagram account called Gossip and you are Direct Messaging a user.
    Unlike a regular chatbot, you mention your previous conversations with other people, just like a real person would.
    So if someone tells you something interesting you can call reflect to bring up something relevant that someone else said.
    Try to create fun and interesting mentions by getting the user to tell you stuff!
    When you reflect, another model will evaluate the current conversation and may direct you to collect more information from the user.
    Its kind of a give to get system."
  end

  def handle_message(content, now = false)
    messages.create!(role: "user", content:)

    now ? ReplyJob.new.perform(id) : ReplyJob.perform_async(id)
  end

  def daily_messages
    messages.where("created_at >= ?", 1.day.ago).count
  end

  def monthly_messages
    messages.where("created_at >= ?", 1.month.ago).count
  end

  def rate_limited?
    daily_messages > DAILY_MESSAGE_LIMIT || monthly_messages > MONTHLY_MESSAGE_LIMIT
  end

  def route
    prompt = ROUTING_PROMPT.sub("{{current_user_conversation}}", formatted_messages)
    Ai.chat(prompt)
  end

  def share
    prompt = RESPONSE_PROMPT.sub("{{current_user_conversation}}", formatted_messages).sub("{{similar_conversations}}", formatted_similar)
    Rails.logger.info(prompt)
    Ai.chat(prompt)
  end

  def collect
    prompt = COLLECTION_PROMPT.sub("{{current_user_conversation}}", formatted_messages)
    Rails.logger.info(prompt)
    Ai.chat(prompt)
  end

  def chat_response
    if rate_limited?
      return "I can't chat all day! Let's talk more later"
    end

    if route == "share"
      Rails.logger.info("SHARE")
      embed
      share
    else
      Rails.logger.info("COLLECT")
      collect
    end
  end

  def reflect_tool
    {
      name: "reflect",
      description: "Recall something relevant from one of your previous conversations with other people.",
      input_schema: {
        type: "object",
        properties: {}
      }
    }
  end

  def reflect
    content = "Collect more information"

    if route == "share"
      Rails.logger.info("SHARE")
      embed

      prompt = AGENT_RESPONSE_PROMPT.sub("{{current_user_conversation}}", formatted_messages).sub("{{similar_conversations}}", formatted_similar)
      Rails.logger.info(prompt)
      content = Ai.chat(prompt)
    end

    content
  end

  def agent_reply
    message = Gemini.new(self).chat(messages.order(:created_at).to_a, tools: [ reflect_tool ], system_prompt:)
    send_message(message)
  end

  def reply
    message = messages.create(role: "assistant", content: chat_response)
    send_message(message)
  end

  def formatted_messages
    messages.where(tool_call_id: nil).order(:created_at).format.last(MAX_CONVERSATION_LENGTH)
  end

  def embed
    response = OpenAI::Client.new.embeddings.create(model: "text-embedding-3-large", input: formatted_messages)

    update!(embedding: response.data.first.embedding)
  end

  def similar
    User.where.not(id: id).where.not(instagram_username: nil).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(20)
  end

  def formatted_similar
    similar.map(&:formatted_messages).join("\n")
  end

  def send_message(message)
    return unless Rails.env.production?

    Instagram.send_message(instagram_id, message.content)
  end
end
