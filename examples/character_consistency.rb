#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Rank models on multi-turn character consistency (lower-level API)
# ------------------------------------------------------------------------
# Use case: "Which model role-plays a game NPC most convincingly over several
# turns?"
#
# The suite DSL is single-prompt per scenario, so this multi-turn workflow drops
# down to qualspec's building blocks directly:
#   - Qualspec.client : raw chat with a running message history (the conversation)
#   - Qualspec.judge  : evaluate_comparison to rank the full transcripts
#
# This is the pattern for evaluating an *agent* or a *conversation* rather than a
# single reply — a good template for a script that vets a new model.
#
# Run it (replays from cassette, no credits needed):
#
#     bundle exec ruby examples/character_consistency.rb

require 'bundler/setup'
require 'qualspec'

CHARACTER_SYSTEM = <<~PROMPT
  You are Grimble, a grumpy but secretly kind-hearted dwarf blacksmith in a
  fantasy RPG. You distrust strangers, grumble about "surface-dwellers", take
  pride in your craft, and never break character. Keep replies to 2-3 sentences.
PROMPT

# The same three things the player says to every candidate, in order.
PLAYER_TURNS = [
  'Hello there! Can you make me a sword?',
  'I do not have much gold. Could you give me a discount?',
  'Why do you even bother with your work if you hate visitors so much?'
].freeze

MODELS = {
  gemini_flash: Qualspec.model(:gemini_flash),
  deepseek_flash: Qualspec.model(:deepseek_flash),
  glm: Qualspec.model(:glm)
}.freeze

# Run the full conversation against one model and return the transcript text.
def role_play(model)
  messages = [{ role: 'system', content: CHARACTER_SYSTEM }]
  transcript = []

  PLAYER_TURNS.each do |player_line|
    messages << { role: 'user', content: player_line }
    reply = Qualspec.client.chat(model: model, messages: messages, json_mode: false).to_s.strip
    messages << { role: 'assistant', content: reply }
    transcript << "Player: #{player_line}\nGrimble: #{reply}"
  end

  transcript.join("\n\n")
end

if __FILE__ == $PROGRAM_NAME
  Qualspec::Recorder.setup(cassette_dir: File.expand_path('cassettes', __dir__))

  ranking = Qualspec::Recorder.use_cassette('character_consistency') do
    transcripts = MODELS.transform_values { |model| role_play(model) }

    Qualspec.judge.evaluate_comparison(
      responses: transcripts.transform_keys(&:to_s),
      criteria: [
        'Maintains a consistent personality across all three turns',
        'Stays fully in character as Grimble the grumpy dwarf blacksmith',
        'Feels distinctive and memorable rather than generic'
      ]
    )
  end

  puts
  puts '=== Character consistency ranking ==='
  ranking
    .sort_by { |_, evaluation| -evaluation.score }
    .each do |model, evaluation|
      crown = evaluation.scenario_winner == true ? ' 👑 winner' : ''
      puts "#{model}: #{evaluation.score}/10#{crown}"
      puts "  #{evaluation.reasoning}"
    end
end
