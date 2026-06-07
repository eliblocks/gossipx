class WebhooksController < ActionController::API
  def verify_instagram
    render json: params["hub.challenge"]
  end

  def instagram
    messaging = params.dig("entry", 0, "messaging", 0)
    instagram_id = messaging.dig("sender", "id")
    text = messaging.dig("message", "text")

    return head :ok unless text
    return head :ok if instagram_id == ENV["INSTAGRAM_PROFILE_ID"]

    user = User.find_or_initialize_by(instagram_id:) do |user|
      user.email = "#{instagram_id}@example.com"
      user.password = SecureRandom.hex
    end

    profile = JSON.parse(Instagram.profile(instagram_id))
    user.instagram_username = profile["username"]
    names = profile["name"]&.split(" ")

    if names
      user.last_name = names.pop
      user.first_name = names.join(" ")
    end

    user.save!

    user.handle_message(text)

    head :ok
  end

  def verify_whatsapp
    render json: params["hub.challenge"]
  end

  def whatsapp
    entry = params.dig("entry", 0, "changes", 0, "value")
    name = entry.dig("contacts", 0, "profile", "name")
    message = entry.dig("messages", 0)

    return head :ok unless message.present?

    phone = message.dig("from")
    text = message.dig("text", "body")

    return head :ok unless text.present?

    user = User.find_or_initialize_by(phone:) do |user|
      user.email = "#{phone}@example.com"
      user.password = SecureRandom.hex
    end

    if name
      names = name.split(" ")
      user.last_name = names.pop
      user.first_name = names.join(" ")
    end

    user.save!

    user.handle_message(text)

    head :ok
  end

  def verify_messenger
    render json: params["hub.challenge"]
  end

  def messenger
    messaging = params.dig("entry", 0, "messaging", 0)
    facebook_id = messaging.dig("sender", "id")
    text = messaging.dig("message", "text")

    return head :ok unless text
    return head :ok if facebook_id == ENV["FACEBOOK_PROFILE_ID"]

    user = User.find_or_initialize_by(facebook_id:) do |user|
      user.email = "#{facebook_id}@example.com"
      user.password = SecureRandom.hex
    end

    profile = JSON.parse(Facebook.profile(facebook_id))
    user.facebook_username = profile["username"]
    names = profile["name"]&.split(" ")

    if names
      user.last_name = names.pop
      user.first_name = names.join(" ")
    end

    user.save!

    user.handle_message(text)

    head :ok
  end

  def verify_twitter
    crc_token = params[:crc_token]
    return head :bad_request unless crc_token

    hash = OpenSSL::HMAC.digest("sha256", ENV["TWITTER_CONSUMER_SECRET"], crc_token)
    response_token = "sha256=#{Base64.strict_encode64(hash)}"

    render json: { response_token: }
  end

  def twitter
    bot_id = params[:for_user_id]
    events = params[:direct_message_events]
    users = params[:users]

    return head :ok unless events

    events.each do |event|
      next unless event["type"] == "message_create"

      sender_id = event.dig("message_create", "sender_id")
      text = event.dig("message_create", "message_data", "text")

      next unless text
      next if sender_id == bot_id

      sender = users&.dig(sender_id)

      user = User.find_or_initialize_by(twitter_id: sender_id) do |u|
        u.email = "#{sender_id}@example.com"
        u.password = SecureRandom.hex
      end

      if sender
        user.twitter_username = sender["screen_name"]
        names = sender["name"]&.split(" ")
        if names
          user.last_name = names.pop
          user.first_name = names.join(" ")
        end
      end

      user.save!
      user.handle_message(text)
    end

    head :ok
  end
end
