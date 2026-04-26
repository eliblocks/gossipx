class ReplyJob
  def self.perform_async(user_id)
    Thread.new { new.perform(user_id) }
  end

  def perform(user_id)
    User.find(user_id).reply
  end
end
