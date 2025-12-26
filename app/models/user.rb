class User < ApplicationRecord
  # :confirmable, :lockable, :timeoutable, :trackable, :omniauthable, :registerable,
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :messages

  def full_name
    "#{first_name} #{last_name}"
  end

  def handle_message(content)
    messages.create(role: "user", content:)
    messages.create(role: "assistant", content: chat.output_text)
  end

  def instructions
    "Encourage the user to share something about themselves"
  end

  def conversation
    messages.map { |message| {role: message.role, content: message.content} }
  end

  def chat
    parameters = {
      model: "gpt-5.2",
      store: true,
      metadata: { environment: Rails.env, app: "Blabber" },
      reasoning: { effort: :medium },
      instructions: instructions,
      input: conversation
    }
  
    OpenAI::Client.new.responses.create(parameters)
  end
end
