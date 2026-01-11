class ReplyJob < ApplicationJob
  def perform(user_id)
    User.find(user_id).reply_alternate
  end
end