class ReplyJob < ApplicationJob
  def perform(user_id)
    User.find(user_id).search_reply
  end
end
