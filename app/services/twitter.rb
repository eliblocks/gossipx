class Twitter
  BASE_URL = "https://api.x.com/2"

  class << self
    def http
      HTTP
        .auth("Bearer #{ENV["X_API_KEY"]}")
        .headers({ "Content-Type" => "application/json" })
    end

    def send_message(id, text)
      http.post("/dm_conversations/with/#{id}/messages", json: { text: })
    end
  end
end
