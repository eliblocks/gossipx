class Ai
  PROVIDER = :gemini

  class << self
    def chat(content, instructions: nil)
      messages = [ { role: "user", content: } ]

      if PROVIDER == :anthropic
        anthropic_chat(messages, instructions:)
      elsif PROVIDER == :openai
        openai_chat(messages, instructions:)
      elsif PROVIDER == :gemini
        gemini_chat(messages, instructions:)
      end
    end

    def openai_chat(messages, instructions: nil)
      parameters = {
        model: "gpt-5.2",
        store: true,
        metadata: { environment: Rails.env, app: "Blabber" },
        reasoning: { effort: :medium },
        input: messages
      }

      parameters[:instructions] = instructions if instructions

      OpenAI::Client.new.responses.create(parameters).output_text
    end

    def anthropic_chat(messages, instructions: nil)
      params = {
        model: "claude-opus-4-5",
        max_tokens: 8000,
        thinking: {
          type: :enabled,
          budget_tokens: 4000
        },
        messages:
      }

      params[:system] = instructions if instructions

      response = Anthropic::Client.new.messages.create(params)
      response.content.find { |item| item.type == :text }.text
    end

    def gemini_chat(messages, instructions: nil)
      url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview:generateContent"
      client = HTTP.headers(
        "x-goog-api-key" => ENV.fetch("GEMINI_API_KEY"),
        "Content-Type" => "application/json"
      )

      contents = messages.map { |message| { role: message[:role], parts: { text: message[:content] } } }
      payload = { contents: contents }
      payload[:system_instruction] = { parts: [ { text: instructions } ] } if instructions

      response = client.post(url, json: payload)
      parts = response.parse.dig("candidates", 0, "content", "parts")

      parts.find { |part| part["text"] }["text"]
    end
  end
end
