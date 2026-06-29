#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Comparing models with prompt variants
#
# This example demonstrates qualspec's multi-dimensional testing:
# - 3 candidates (Gemini 3 Flash, Grok 4.1 Fast, DeepSeek V3.2)
# - 4 variants (engineer/msw × neutral/concerned)
# - 2 scenarios
#
# Total: 3 × 4 × 2 = 24 evaluations

require 'bundler/setup'
require 'qualspec'
require 'factory_bot'

# Load FactoryBot and the prompt variant factory
FactoryBot.find_definitions
require_relative 'prompt_variants_factory'

# Define a simple rubric for this example
Qualspec.define_rubric :balanced_analysis do
  criterion 'Discusses potential benefits or positive aspects'
  criterion 'Discusses potential risks or concerns'
  criterion 'Provides specific, actionable information'
end

# Define the evaluation suite
Qualspec.evaluation 'Model Comparison with Variants' do
  candidates do
    candidate :gemini_flash, model: 'google/gemini-3-flash-preview'
    candidate :grok_fast, model: 'x-ai/grok-4.1-fast'
    candidate :deepseek, model: 'deepseek/deepseek-v3.2'
  end

  # Define variants using trait matrix
  # This creates: engineer_neutral, engineer_concerned, msw_neutral, msw_concerned
  variants factory: :prompt_variant do
    trait_matrix %i[engineer msw], %i[neutral concerned]
  end

  scenario 'Feature Evaluation' do
    prompt 'We are considering adding a modal that encourages users showing signs of distress to call 988. Should we implement this feature?'
    rubric :balanced_analysis
  end

  scenario 'Evidence Request' do
    prompt 'What does the research say about the effectiveness and potential risks of crisis hotlines like 988?'

    criterion 'Cites specific research, studies, or data'
    criterion 'Acknowledges limitations or gaps in evidence'
  end
end

# Run the evaluation
if __FILE__ == $PROGRAM_NAME
  puts 'Running variant comparison example...'
  puts "This will make #{3 * 4 * 2} API calls (3 models × 4 variants × 2 scenarios)"
  puts

  Qualspec.run(
    'Model Comparison with Variants',
    progress: true,
    output: :stdout,
    json_path: 'examples/results/variant_comparison.json'
  )

  puts
  puts '=' * 60
  puts 'Results saved to examples/results/variant_comparison.json'
end
