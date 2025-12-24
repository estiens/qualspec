# frozen_string_literal: true

# Quick test to verify the gem works with OpenRouter
#
# Run with:
#   QUALSPEC_API_URL=https://openrouter.ai/api/v1 \
#   QUALSPEC_API_KEY=your_key \
#   bundle exec qualspec examples/quick_test.rb

require "qualspec"

Qualspec.evaluation "Quick Test" do
  candidates do
    candidate "gemini-flash", model: "google/gemini-3-flash-preview"
  end

  scenario "basic greeting" do
    prompt "Hello! How are you today?"
    eval "responds in a friendly manner"
    eval "is appropriate in length"
  end

  scenario "simple math" do
    prompt "What is 7 times 8?"
    eval "provides the correct answer (56)"
    eval "doesn't over-explain"
  end
end
