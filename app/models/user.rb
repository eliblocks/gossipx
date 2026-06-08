class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :messages, dependent: :destroy
  has_neighbors :embedding

  validates :twitter_id, uniqueness: true, allow_nil: true
  validates :twitter_username, uniqueness: true, allow_nil: true

  include Prompts
  include Tools

  def full_name
    "#{first_name} #{last_name}"
  end

  DAILY_MESSAGE_LIMIT = 50
  MONTHLY_MESSAGE_LIMIT = 500
  MAX_CONVERSATION_LENGTH = 25_000

  def username
    twitter_username
  end

  def handle_message(content, now = false)
    if rate_limited?
      send_message(Message.new(content: "Thanks for chatting with me, but I've got to take a break! Try again tomorrow!"))

      return
    end

    messages.create!(role: "user", content:)

    now ? ReplyJob.perform_now(id) : ReplyJob.perform_later(id)
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

  def search_similar_conversations
    embed
    similar.as_json(only: [ :twitter_username, :summary ])
  end

  def open_conversation(twitter_username)
    formatted_messages
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

  def reply
    message = Gemini.new(self).chat(messages.order(:created_at).to_a, tools: [ REFLECT ], system_prompt: SYSTEM_PROMPT)
    send_message(message)
  end

  def search_reply
    message = Gemini.new(self).chat(messages.order(:created_at).to_a, tools: [ SEARCH_SIMILAR_CONVERSATIONS, OPEN_CONVERSATION ], system_prompt: SEARCH_SYSTEM_PROMPT)
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
    if username
      User.where.not(id: id).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(20)
    end
  end

  def formatted_similar
    similar.map(&:formatted_messages).join("\n")
  end

  def send_message(message)
    if twitter_id.present?
      Twitter.send_message(twitter_id, message.content)
    end
  end

  def summarize
    prompt = SUMMARIZE_PROMPT.sub("{{current_user_conversation}}", formatted_messages)
    update(summary: Ai.chat(prompt))
  end
end
