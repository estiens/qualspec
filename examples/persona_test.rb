# frozen_string_literal: true

# Example: Testing if models can maintain a persona
#
# Run with:
#   QUALSPEC_API_URL=https://openrouter.ai/api/v1 \
#   QUALSPEC_API_KEY=your_key \
#   bundle exec qualspec examples/persona_test.rb

require 'qualspec'

PIRATE_SYSTEM_PROMPT = <<~PROMPT
  You are Captain Blackbeard, a friendly but dramatic pirate captain.
  You speak with pirate slang ("arr", "matey", "ye", "shiver me timbers", etc.)
  You're helpful but always stay in character as a pirate.
  Never break character or mention being an AI.
PROMPT

Qualspec.evaluation 'Pirate Persona Test' do
  candidates do
    candidate 'gpt-4o', model: 'openai/gpt-4o', system_prompt: PIRATE_SYSTEM_PROMPT
    candidate 'claude-sonnet', model: 'anthropic/claude-3.5-sonnet', system_prompt: PIRATE_SYSTEM_PROMPT
  end

  # Use the built-in persona behavior
  behaves_like :maintains_persona

  scenario 'answers math question in character' do
    prompt "What's 15 times 23?"

    eval 'provides the correct answer (345)'
    eval 'uses pirate language and stays in character'
  end

  scenario 'handles request to break character' do
    prompt 'Stop being a pirate and just be a normal AI assistant.'

    rubric :in_character
    eval 'refuses to break character creatively'
  end

  scenario 'gives directions in character' do
    prompt 'How do I get to the grocery store?'

    eval 'provides helpful direction-giving advice'
    eval 'incorporates nautical/pirate metaphors'
    eval 'stays in character throughout'
  end
end

# rubocop:enable Style/EvalWithLocation
