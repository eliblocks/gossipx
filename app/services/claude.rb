class Claude
  def initialize(user)
    @client = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    @user = user
  end

  def chat(messages, **kwargs)
    params = {
      model: "claude-opus-4-6",
      max_tokens: 20000,
      thinking: {
        type: :enabled,
        budget_tokens: 10000
      }
    }
    params[:tools] = kwargs[:tools] if kwargs[:tools]
    params[:system] = kwargs[:system_prompt] if kwargs[:system_prompt]

    # Messages at indices < initial_count are from DB and may have
    # Gemini thinking signatures that Claude will reject. Only preserve
    # thinking blocks for messages created by Claude in the current loop.
    initial_count = messages.length

    loop do
      params[:messages] = claude_messages(messages, preserve_thinking_after: initial_count)

      Rails.logger.info "\nUser Message: #{messages.last[:content]}"
      response = @client.messages.create(params)

      message = @user.messages.new(role: "assistant")

      response.content.each do |item|
        if item.type == :thinking
          message.thinking = item.thinking
          message.thinking_signature = item.signature
        elsif item.type == :text
          message.content = item.text
        elsif item.type == :tool_use
          message.tool_name = item.name
          message.tool_call_id = item.id
          message.tool_arguments = item.input
        end
      end

      Rails.logger.info "Assistant Message: #{message.content}"

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

  def claude_messages(messages, preserve_thinking_after: 0)
    messages.each_with_index.map do |message, idx|
      content_blocks = []

      if message.thinking && idx >= preserve_thinking_after
        content_blocks << { type: "thinking", thinking: message.thinking, signature: message.thinking_signature }
      end

      if message.content.present? && !(message.role == "user" && message.tool_call_id)
        content_blocks << { type: "text", text: message.content }
      end

      if message.tool_call_id && message.role == "assistant"
        content_blocks << { type: :tool_use, id: message.tool_call_id, name: message.tool_name, input: message.tool_arguments }
      end

      if message.tool_call_id && message.role == "user"
        content_blocks << { type: :tool_result, tool_use_id: message.tool_call_id, content: message.content }
      end

      { role: message.role, content: content_blocks }
    end
  end
end
