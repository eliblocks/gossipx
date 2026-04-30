class SummarizeJob < ApplicationJob
  def perform(user_id)
    User.find(user_id).summarize
  end
end
