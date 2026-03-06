class ReplyJob
  include Sidekiq::Job

  def perform(user_id)
    User.find(user_id).agent_reply
  end
end
