class Whatsapp
  BASE_URL = "https://graph.facebook.com/v24.0"

  class << self
    def http
      HTTP
        .auth("Bearer #{ENV["WHATSAPP_ACCESS_TOKEN"]}")
        .headers({ "Content-Type" => "application/json" })
    end

    def send_message(phone_number, text)
      http.post("#{BASE_URL}/#{ENV["WHATSAPP_PHONE_ID"]}/messages", json: {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: phone_number,
        type: "text",
        text: { "body": text }
      })
    end
  end
end
