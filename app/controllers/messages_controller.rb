class MessagesController < ApplicationController
  def index
    @messages = Message.where(role: "user", tool_name: nil).includes(:user).order(created_at: :desc).limit(200)
  end
  def create
    @user = User.find(params[:user_id])
    @user.handle_message(params[:message][:content], true)

    redirect_to user_path(@user)
  end

  def destroy
    @user = User.find(params[:user_id])
    @message = @user.messages.find(params[:id])
    @message.destroy

    redirect_to user_path(@user)
  end
end
