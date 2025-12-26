class MessagesController < ApplicationController
  def create
    @user = User.find(params[:user_id])
    @user.handle_message(params[:message][:content])

    redirect_to user_path(@user)
  end

  def destroy
    @user = User.find(params[:user_id])
    @message = @user.messages.find(params[:id])
    @message.destroy

    redirect_to user_path(@user)
  end
end
