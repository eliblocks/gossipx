class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  def index
    if current_user
      redirect_to users_path
    else
      redirect_to new_user_session_path
    end
  end

  def authorize_admin!
    redirect_to root_path unless current_user&.admin?
  end
end
