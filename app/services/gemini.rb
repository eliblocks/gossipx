class Gemini
  URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview:generateContent"

  def initialize(user)
    @user = user
  end

  def chat(messages, **kwargs)
    body = {}
    body[:systemInstruction] = { parts: [{ text: kwargs[:system_prompt] }] } if kwargs[:system_prompt]
    body[:tools] = [{ functionDeclarations: kwargs[:tools].map { |t| { name: t[:name], description: t[:description], parameters: t[:input_schema] } } }] if kwargs[:tools]

    loop do
      body[:contents] = gemini_contents(messages)

      puts "\nUser Message: #{messages.last[:content]}"
      data = HTTP.post("#{URL}?key=#{ENV.fetch('GEMINI_API_KEY')}", json: body).parse

      parts = data.dig("candidates", 0, "content", "parts")
      message = @user.messages.new(role: "assistant")

      parts.each do |part|
        message.thinking_signature = part["thoughtSignature"] if part["thoughtSignature"]

        if part["thought"]
          message.thinking = part["text"]
        elsif part["text"]
          message.content = part["text"]
        elsif part["functionCall"]
          message.tool_name = part["functionCall"]["name"]
          message.tool_call_id = SecureRandom.uuid
          message.tool_arguments = part["functionCall"]["args"]
        end
      end

      puts "Assistant Message: #{message.content}"
      message.save!
      messages << message

      break unless message.tool_call_id

      messages << @user.messages.create!(
        role: "user",
        tool_name: message.tool_name,
        tool_call_id: message.tool_call_id,
        content: @user.reflect
      )
    end

    messages.last
  end

  private

  def gemini_contents(messages)
    messages.map do |message|
      parts = []

      if message.thinking
        parts << { text: message.thinking, thought: true }
      end

      if message.content.present? && !(message.role == "user" && message.tool_call_id)
        parts << { text: message.content }
      end

      if message.tool_call_id && message.role == "assistant"
        parts << { functionCall: { name: message.tool_name, args: message.tool_arguments || {} } }
      end

      if message.tool_call_id && message.role == "user"
        parts << { functionResponse: { name: message.tool_name, response: { result: message.content } } }
      end

      if message.thinking_signature && message.role == "assistant" && parts.any?
        parts.last[:thoughtSignature] = message.thinking_signature
      end

      { role: message.role == "assistant" ? "model" : "user", parts: }
    end
  end
end
