class Message < ApplicationRecord
  belongs_to :user

  ROLES = [ "user", "assistant" ]

  validates :role, inclusion: { in: ROLES }

  def self.format
    all.map(&:format).join("\n")
  end

  def format
    label = ""

    if role == "assistant"
      label = "bot"
    elsif user.instagram_username
      label = "@#{user.instagram_username}"
    elsif user.phone
      label = "<#{user.phone}> #{user.full_name}"
    end

    "#{label}: #{content}"
  end
end
