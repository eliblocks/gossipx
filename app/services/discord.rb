class Discord
  BASE_URL = "https://discord.com/api/v10"

  class << self
    def http
      HTTP
        .auth("Bot #{ENV['DISCORD_TOKEN']}")
        .headers({ "Content-Type" => "application/json" })
    end

    def start_typing(channel_id)
      http.post("#{BASE_URL}/channels/#{channel_id}/typing")
    end

    def send_message(channel_id, text)
      http.post("#{BASE_URL}/channels/#{channel_id}/messages", json: {
        content: text,
        flags: 1 << 2
      })
    end
  end
end
