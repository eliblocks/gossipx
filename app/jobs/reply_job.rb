class ReplyJob < ApplicationJob
  def perform(user_id)
    User.find(user_id).reply  
  end
end