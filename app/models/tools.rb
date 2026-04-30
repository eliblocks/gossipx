module Tools
  REFLECT = {
    name: "reflect",
    description: "Recall something relevant from one of your previous conversations with other people.",
    input_schema: {
      type: "object",
      properties: {}
    }
  }.freeze

  SEARCH_SIMILAR_CONVERSATIONS = {
    name: "search_similar_conversations",
    description: "Get summaries of related conversations with other people",
    input_schema: {
      type: "object",
      properties: {}
    }
  }.freeze

  OPEN_CONVERSATION = {
    name: "open_conversation",
    description: "Open the full conversation history with a specific user",
    input_schema: {
      type: "object",
      properties: {
        instagram_username: { type: "string", description: "The username of the person whose conversation to open" }
      },
      required: [ "instagram_username" ]
    }
  }.freeze
end
