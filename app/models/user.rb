class User < ApplicationRecord
  # :confirmable, :lockable, :timeoutable, :trackable, :omniauthable, :registerable,
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :messages, dependent: :destroy
  has_neighbors :embedding

  validates :instagram_id, uniqueness: true, allow_nil: true
  validates :instagram_username, uniqueness: true, allow_nil: true

  include Prompts

  def full_name
    "#{first_name} #{last_name}"
  end

  def handle_message(content, now=false)
    messages.create!(role: "user", content:)

    now ? ReplyJob.perform_now(id) : ReplyJob.perform_later(id)
  end

  def reply
    previous_messages = messages.order(:created_at).to_a
    message = claude.chat(previous_messages, system_prompt: DEFAULT_SYSTEM_PROMPT, tools: [reflect_tool], type: "conversation")
    send_message(message)
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
    Ai.chat(prompt)
  end

  def reply_alternate
    status = route

    res = ""

    if status == "share"
      embed
      res = share
    else
      res = collect
    end

    message = messages.create(role: "assistant", content: res)
    send_message(message)
  end

  def make_response_prompt(prompt)
    prompt.sub("{{current_user_conversation}}", formatted_messages).sub("{{similar_conversations}}", formatted_similar)
  end

  def make_response(prompt)
    Ai.chat(make_response_prompt(prompt))
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

  def reflect
    embed
    make_response(RESPONSE_PROMPT)
    # best_match = find_match(MATCHING_DEFAULT_PROMPT)
    # extract_content(EXTRACTION_DEFAULT_PROMPT, best_match)
  end

  def formatted_messages
    messages.where(tool_call_id: nil).order(:created_at).format
  end

  def filtered_messages
    formatted_messages.gsub(/@\w+/, "@********")
  end

  def conversation
    messages.map { |message| {role: message.role, content: message.content} }
  end

  def embed
    response = OpenAI::Client.new.embeddings.create(model: "text-embedding-3-large", input: formatted_messages)

    update!(embedding: response.data.first.embedding)
  end

  def similar
    User.where.not(id: id).nearest_neighbors(:embedding, embedding, distance: "euclidean").first(20)
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
    return unless instagram_id
    return unless Rails.env == "production"

    Instagram.send_message(instagram_id, message.content)
  end

  def claude
    Claude.new(self)
  end
end
