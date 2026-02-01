class Facebook
  BASE_URL = "https://graph.facebook.com/v24.0"

  class << self
    def http
      HTTP
        .auth("Bearer #{ENV["FACEBOOK_ACCESS_TOKEN"]}")
        .headers({ "Content-Type" => "application/json" })
    end

    def profile(id)
      http.get("#{BASE_URL}/#{id}", params: { fields: "name,username" })
    end

    def send_message(id, text)
      http.post("#{BASE_URL}/me/messages", json: {
        recipient: { id: },
        message: { text: }
      })
    end
  end
end
