class Twitter
  BASE_URL = "https://api.x.com/2"

  class << self
    def send_message(id, text)
      response = oauth1_post("#{BASE_URL}/dm_conversations/with/#{id}/messages", { text: }.to_json)
      Rails.logger.info "Twitter DM response: #{response.status}"
      response
    end

    private

    def oauth1_post(url, body)
      oauth_params = {
        oauth_consumer_key: ENV["TWITTER_CONSUMER_KEY"],
        oauth_token: ENV["TWITTER_ACCESS_TOKEN"],
        oauth_signature_method: "HMAC-SHA1",
        oauth_version: "1.0",
        oauth_nonce: SecureRandom.hex,
        oauth_timestamp: Time.now.to_i.to_s
      }

      signing_key = "#{percent_encode(ENV["TWITTER_CONSUMER_SECRET"])}&#{percent_encode(ENV["TWITTER_ACCESS_TOKEN_SECRET"])}"
      base_string = "POST&#{percent_encode(url)}&#{percent_encode(normalize_params(oauth_params))}"
      signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", signing_key, base_string))
      oauth_params[:oauth_signature] = signature

      header = "OAuth " + oauth_params.map { |k, v| "#{k}=\"#{percent_encode(v)}\"" }.join(", ")

      HTTP.headers("Authorization" => header, "Content-Type" => "application/json").post(url, body:)
    end

    def normalize_params(params)
      params.sort.map { |k, v| "#{percent_encode(k)}=#{percent_encode(v)}" }.join("&")
    end

    def percent_encode(val)
      ERB::Util.url_encode(val.to_s)
    end
  end
end
