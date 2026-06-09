class WebhooksController < ActionController::API
  def verify_twitter
    crc_token = params[:crc_token]
    return head :bad_request unless crc_token

    hash = OpenSSL::HMAC.digest("sha256", ENV["TWITTER_CONSUMER_SECRET"], crc_token)
    response_token = "sha256=#{Base64.strict_encode64(hash)}"

    render json: { response_token: }
  end

  def twitter
    payload = params.dig(:data, :payload) || params
    bot_id = params.dig(:data, :filter, :user_id) || params[:for_user_id]
    events = payload[:direct_message_events]
    users = payload[:users]

    return head :ok unless events

    events.each do |event|
      next unless event["type"] == "message_create"

      sender_id = event.dig("message_create", "sender_id")
      text = event.dig("message_create", "message_data", "text")

      next unless text
      next if sender_id == bot_id

      profile = users&.dig(sender_id, "data") || users&.dig(sender_id)

      user = User.find_or_initialize_by(twitter_id: sender_id) do |u|
        u.email = "#{sender_id}@example.com"
        u.password = SecureRandom.hex
      end

      if profile
        user.twitter_username = profile["username"] || profile["screen_name"]
        names = profile["name"]&.split(" ")
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
