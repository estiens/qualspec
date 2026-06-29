#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Simple Model Comparison with Variants (No FactoryBot required)
#
# This example demonstrates qualspec's multi-dimensional testing using
# explicit variant definitions instead of FactoryBot.
#
# Models: Gemini 3 Flash, Grok 4.1 Fast, DeepSeek V3.2
# Variants: engineer vs msw credentials
# Scenarios: 1 evaluation question
#
# Total: 3 × 2 × 1 = 6 evaluations

require 'bundler/setup'
require 'qualspec'

# Define a simple rubric
Qualspec.define_rubric :balanced_analysis do
  criterion 'Discusses potential benefits or positive aspects'
  criterion 'Discusses potential risks or concerns'
  criterion 'Provides balanced, nuanced analysis'
end

# Define the evaluation suite
Qualspec.evaluation 'Simple Variant Demo' do
  candidates do
    candidate :gemini_flash, model: 'google/gemini-3-flash-preview'
    candidate :grok_fast, model: 'x-ai/grok-4.1-fast'
    candidate :deepseek, model: 'deepseek/deepseek-v3.2'
  end

  # Explicit variant definitions (no FactoryBot needed)
  variants do
    variant :engineer, traits: [], credential: "I'm an engineer at a tech company building this feature."
    variant :msw, traits: [], credential: "I'm a licensed clinical social worker with crisis intervention experience."
  end

  scenario 'Crisis Feature Evaluation' do
    prompt 'Should we add a modal encouraging distressed users to call 988?'
    rubric :balanced_analysis
  end
end

# Run the evaluation
if __FILE__ == $PROGRAM_NAME
  require 'fileutils'
  FileUtils.mkdir_p('examples/results')

  puts 'Running simple variant comparison...'
  puts 'Models: Gemini 3 Flash, Grok 4.1 Fast, DeepSeek V3.2'
  puts 'Variants: engineer, msw'
  puts "Total API calls: #{3 * 2 * 1} (3 models × 2 variants × 1 scenario)"
  puts
  puts '=' * 60

  Qualspec.run(
    'Simple Variant Demo',
    progress: true,
    output: :stdout,
    show_responses: true,
    json_path: 'examples/results/simple_variant_comparison.json'
  )

  puts
  puts '=' * 60
  puts 'Results saved to examples/results/simple_variant_comparison.json'
end
