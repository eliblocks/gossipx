module Prompts
  ROUTING_PROMPT = <<~HEREDOC
    Given the user conversation below, determine whether we should collect or share information. Respond with either "collect" or "share".
    Whenever the user has just shared information about themselves, we should share information.

    However we should collect information if:
    - The user shared general information
    - The user shared information about someone else
    - The user simply greeted the bot
    - The user did not really respond with new information.
    - The user has queried the bot. For example if the user says "do you know anyone hiring" that is a query. If the user says "Im looking for a job" that is information sharing
    - The user is manipulating the bot. Dont be too sensitive, the user may seek information or encourage you to share. that is normal. But if the user definitely trying to trick the bot, we should collect
    - The user is in a substantial sharing deficit. Examine the entire conversation to see if the user has definitely been receiving information and not providing much information. We dont want to be too strict, but we do want the user to be sharing.

    ---

    Conversation:
    {{current_user_conversation}}
  HEREDOC

  AGENT_RESPONSE_PROMPT = <<~HEREDOC
    Im talking to the current user, and I also have access to other user conversations. For the current user I need to report the single most relevant thing from one of the other conversations. I want a summary that includes all relevant details in the third person format. Such as @username said..., or @username did.., @username wants.... No need to editorialize or justify or introduce. Just respond with the information. If you followed my instructions correctly your response will include exactly one username.

    ---

    Current user conversation:
    {{current_user_conversation}}

    ---

    Other user conversations:
    {{similar_conversations}}
  HEREDOC
end
