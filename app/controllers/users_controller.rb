class UsersController < ApplicationController
    def index
    @users = User.where(role: "user")
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    @user = User.new
  end

  def edit
    @user = User.find(params[:id])
  end

  def create
    @user = User.new(user_params)
    @user.password = "password"
    @user.save!

    redirect_to users_path
  end

  def generate
    username = Faker::Internet.username
    User.create!(email: "#{username}@example.com", instagram_username: username, password: SecureRandom.hex)

    redirect_to users_path
  end

  def update
    @user = User.find(params[:id])
    @user.assign_attributes(user_params)

    @user.instagram_id = @user.instagram_id.presence
    @user.instagram_username = @user.instagram_username.presence
    @user.phone = @user.phone.presence

    @user.save!

    redirect_to users_path
  end

  def reset
    @user = User.find(params[:user_id])
    @user.messages.each(&:destroy!)
    @user.update!(summary: nil, embedding: nil)

    redirect_to users_path
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy

    redirect_to users_path
  end

  private

  def user_params
    params.require(:user).permit(:email, :phone, :first_name, :last_name, :instagram_id, :instagram_username, :role)
  end
end
