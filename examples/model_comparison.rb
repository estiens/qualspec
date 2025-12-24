# frozen_string_literal: true

# Example: Comparing models for customer support quality
#
# Run with:
#   QUALSPEC_API_URL=https://openrouter.ai/api/v1 \
#   QUALSPEC_API_KEY=your_key \
#   bundle exec qualspec examples/model_comparison.rb

require "qualspec"

Qualspec.evaluation "Customer Support Model Comparison" do
  candidates do
    candidate "minimax-m2", model: "minimax/minimax-m2"
    candidate "grok-flash", model: "x-ai/grok-4.1-fast"
    candidate "gemini-flash", model: "google/gemini-3-flash-preview"
  end

  # Use the built-in customer support behavior
  behaves_like :customer_support_agent

  # Add custom scenarios
  scenario "handles refund request" do
    prompt "I want a refund. The product arrived broken and I'm very disappointed."

    eval "acknowledges the problem"
    eval "apologizes appropriately"
    eval "offers clear next steps for the refund"
  end

  scenario "technical troubleshooting" do
    prompt "The app keeps crashing when I try to upload photos. I've tried restarting."

    eval "asks clarifying questions about device/version"
    eval "provides systematic troubleshooting steps"
    eval "doesn't assume user error"
  end
end
