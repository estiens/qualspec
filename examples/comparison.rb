# frozen_string_literal: true

# Example comparison suite
# Run with: bundle exec qualspec --html report.html examples/comparison.rb

Qualspec.evaluation 'Model Comparison' do
  candidates do
    candidate 'gemini-flash', model: 'google/gemini-2.0-flash-001'
    candidate 'gemini-pro', model: 'google/gemini-2.5-pro-preview'
  end

  scenario 'greeting' do
    prompt 'Say hello in a friendly way!'
    eval 'responds in a friendly and welcoming manner'
  end

  scenario 'explanation' do
    prompt 'Explain why the sky is blue in one sentence.'
    eval 'provides a correct scientific explanation'
    eval 'is concise'
  end
end

# rubocop:enable Style/EvalWithLocation
