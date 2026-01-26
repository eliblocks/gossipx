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
    prompt = routing_prompt.sub("{{current_user_conversation}}", formatted_messages)
    Ai.chat(prompt)
  end

  def share
    prompt = response_prompt.sub("{{current_user_conversation}}", formatted_messages).sub("{{similar_conversations}}", formatted_similar)
    Ai.chat(prompt)
  end

  def collect
    prompt = collection_prompt.sub("{{current_user_conversation}}", formatted_messages)
    Ai.chat(prompt)
  end

  def routing_prompt
    instagram_id ? ROUTING_PROMPT : WHATSAPP_ROUTING_PROMPT
  end

  def response_prompt
    instagram_id ? RESPONSE_PROMPT : WHATSAPP_RESPONSE_PROMPT
  end

  def collection_prompt
    instagram_id ? COLLECTION_PROMPT : WHATSAPP_COLLECTION_PROMPT
  end

  def reply_alternate
    status = route

    res = ""

    if status == "share"
      embed
      res = share

      if phone
        number_str = res.match(/<\d+>/).to_s
        contact_phone = number_str.delete("<>")
        res.sub!(number_str, "")

        Rails.logger.info("PHONE: #{contact_phone}")
      end
    else
      res = collect
    end

    message = messages.create(role: "assistant", content: res)
    send_message(message)

    if status == "share" && phone && Rails.env.production?
      Whatsapp.send_contact(phone, contact_phone)
    end
  end

  def make_response_prompt(prompt)
    prompt.sub("{{current_user_conversation}}", formatted_messages).sub("{{similar_conversations}}", formatted_similar)
  end

  def make_response(prompt)
    Ai.chat(make_response_prompt(prompt))
  end

  def formatted_messages
    messages.where(tool_call_id: nil).order(:created_at).format
  end

  def filtered_messages
    formatted_messages.gsub(/@\w+/, "@********")
  end

  def conversation
    messages.map { |message| { role: message.role, content: message.content } }
  end

  def embed
    response = OpenAI::Client.new.embeddings.create(model: "text-embedding-3-large", input: formatted_messages)

    update!(embedding: response.data.first.embedding)
  end

  def similar
    if phone
      User.where.not(id: id).where.not(phone: nil).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(20)
    elsif instagram_username
      User.where.not(id: id).where.not(instagram_username: nil).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(20)
    end
  end

  def formatted_similar
    similar.map(&:formatted_messages).join("\n")
  end

  def extraction_prompt(prompt, matching_user)
    prompt.sub("{{current_user_conversation}}", formatted_messages).sub("{{matching_conversation}}", matching_user.formatted_messages)
  end

  def extract_content(prompt, matching_user)
    Ai.chat(extraction_prompt(prompt, matching_user))
  end

  def best_match_prompt(prompt)
    prompt.sub("{{current_user_conversation}}", formatted_messages).sub("{{similar_conversations}}", formatted_similar)
  end

  def find_match(prompt)
    match_username = Ai.chat(best_match_prompt(prompt)).gsub("@", "")
    User.find_by(instagram_username: match_username)
  end

  def send_message(message)
    return unless Rails.env.production?

    if instagram_id
      Instagram.send_message(instagram_id, message.content)
    elsif phone
      Whatsapp.send_message(phone, message.content)
    end
  end

  def claude
    Claude.new(self)
  end
end
