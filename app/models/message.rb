class Message < ApplicationRecord
  belongs_to :user

  ROLES = [ "user", "assistant" ]

  validates :role, inclusion: { in: ROLES }

  def self.format
    all.map(&:format).join("\n")
  end

  def format
    label = (role == "user" ? "@#{user.instagram_username}" : "bot")
    "#{label}: #{content}"
  end
end
