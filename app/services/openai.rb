class Openai
  class NoResponseError < StandardError; end

  MODEL = "gpt-5.5"

  def initialize(user)
    @client = OpenAI::Client.new
    @user = user
  end

  def chat(messages, **kwargs)
    params = {
      model: MODEL,
      store: true,
      metadata: { environment: Rails.env, app: "Gossipx" },
      reasoning: { effort: :medium }
    }
    params[:instructions] = kwargs[:system_prompt] if kwargs[:system_prompt]
    params[:tools] = openai_tools(kwargs[:tools]) if kwargs[:tools]

    tool_results = []

    loop do
      params[:input] = openai_input(messages)

      Rails.logger.info "User Message: #{messages.last&.content}"
      response = @client.responses.create(params)

      if response.output.blank?
        Rails.logger.info response
        raise NoResponseError
      end

      message = @user.messages.new(role: "assistant", provider: "openai")

      response.output.each do |item|
        case item.type
        when :reasoning
          message.thinking_signature = item.id
          message.thinking = reasoning_text(item)
        when :message
          text = item.content.find { |part| part.type == :output_text }&.text
          message.content = text if text
        when :function_call
          message.tool_name = item.name
          message.tool_call_id = item.call_id
          message.tool_arguments = item.parsed || JSON.parse(item.arguments)
        end
      end

      Rails.logger.info "Assistant Message: #{message.content}"
      message.save!
      messages << message

      break unless message.tool_call_id

      result = call_tool(message.tool_name, message.tool_arguments)
      tool_msg = @user.messages.create!(role: "user", tool_name: message.tool_name, tool_call_id: message.tool_call_id, content: result)
      tool_results << { message: tool_msg, truncated: truncated_tool_result(message.tool_name, message.tool_arguments, result) }
      messages << tool_msg
    end

    tool_results.each { |t| t[:message].update!(content: t[:truncated]) }

    messages.last
  end

  private

  def openai_tools(tools)
    tools.map do |tool|
      {
        type: :function,
        name: tool[:name],
        description: tool[:description],
        parameters: tool[:input_schema],
        strict: false
      }
    end
  end

  def call_tool(name, arguments)
    case name
    when "reflect"
      @user.reflect
    when "search_similar_conversations"
      @user.search_similar_conversations.to_json
    when "open_conversation"
      @user.open_conversation(arguments&.dig("twitter_username"))
    else
      "Unknown tool: #{name}"
    end
  end

  def truncated_tool_result(name, arguments, result)
    case name
    when "search_similar_conversations"
      "Searched #{(JSON.parse(result).length rescue 0)} conversations"
    when "open_conversation"
      "Opened @#{arguments&.dig('twitter_username')}'s conversation"
    else
      result
    end
  end

  def reasoning_text(item)
    item.content&.map(&:text)&.join("\n").presence ||
      item.summary&.map(&:text)&.join("\n")
  end

  def openai_input(messages)
    messages.flat_map { |message| openai_items(message) }
  end

  def openai_items(message)
    if message.tool_call_id && message.role == "user"
      return [ { type: :function_call_output, call_id: message.tool_call_id, output: message.content } ]
    end

    if message.role == "assistant"
      items = []

      if message.thinking && message.provider == "openai"
        items << {
          type: :reasoning,
          id: message.thinking_signature,
          summary: [],
          content: message.thinking.present? ? [ { type: :reasoning_text, text: message.thinking } ] : []
        }
      end

      if message.tool_call_id
        items << {
          type: :function_call,
          call_id: message.tool_call_id,
          name: message.tool_name,
          arguments: (message.tool_arguments || {}).to_json
        }
      elsif message.content.present?
        items << { role: :assistant, content: message.content }
      end

      return items
    end

    [ { role: :user, content: message.content } ]
  end
end
