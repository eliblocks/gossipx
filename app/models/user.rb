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

  def handle_message(content, now = false)
    messages.create!(role: "user", content:)

    now ? ReplyJob.perform_now(id) : ReplyJob.perform_later(id)
  end

  def route
    prompt = ROUTING_PROMPT.sub("{{current_user_conversation}}", formatted_messages)
    Ai.chat(prompt)
  end

  def share
    prompt = RESPONSE_PROMPT.sub("{{current_user_conversation}}", formatted_messages).sub("{{similar_conversations}}", formatted_similar)
    Ai.chat(prompt)
  end

  def collect
    prompt = COLLECTION_PROMPT.sub("{{current_user_conversation}}", formatted_messages)
    Rails.logger.info(prompt)
    Ai.chat(prompt)
  end

  def reply
    status = route

    if status == "share"
      Rails.logger.info("\nSHARE\n")
      embed
      res = share
    else
      Rails.logger.info("\nCOLLECT\n")
      res = collect
    end

    message = messages.create(role: "assistant", content: res)
    send_message(message)
  end

  def formatted_messages
    messages.where(tool_call_id: nil).order(:created_at).format
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
