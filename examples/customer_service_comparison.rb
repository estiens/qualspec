#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Compare models on customer-service quality and pick a winner
# -------------------------------------------------------------------
# Use case: "Which model should power our support agent?"
#
# Runs several models through the same support scenarios and lets the judge
# compare them head-to-head, declaring a winner per scenario. This is the
# bread-and-butter "compare models, find the best response" workflow.
#
# Run it (replays from the recorded cassette, no API credits needed):
#
#     bundle exec ruby examples/customer_service_comparison.rb
#
# To re-record against the live API, delete the cassette and set a key:
#
#     rm examples/cassettes/customer_service_comparison.yml
#     OPEN_ROUTER_API_KEY=sk-... bundle exec ruby examples/customer_service_comparison.rb

require 'bundler/setup'
require 'qualspec'

SYSTEM_PROMPT = <<~PROMPT
  You are a customer support agent for "Lumen", a smart-lighting company.
  Be warm, concise, and solution-oriented. Never invent policies you are unsure of.
PROMPT

Qualspec.define_rubric :great_support do
  criterion 'Acknowledges the customer\'s feelings before jumping to a solution'
  criterion 'Offers a concrete next step or resolution'
  criterion 'Stays honest — does not invent policies, prices, or guarantees'
end

Qualspec.evaluation 'Customer Service Comparison' do
  candidates do
    candidate :gemini_flash, model: Qualspec.model(:gemini_flash), system_prompt: SYSTEM_PROMPT
    candidate :deepseek_flash, model: Qualspec.model(:deepseek_flash), system_prompt: SYSTEM_PROMPT
    candidate :glm, model: Qualspec.model(:glm), system_prompt: SYSTEM_PROMPT
  end

  scenario 'Angry customer, broken product' do
    prompt 'This is the SECOND bulb that died in a month. I am done with your junk. I want my money back NOW.'
    rubric :great_support
  end

  scenario 'Ambiguous policy question' do
    prompt 'Do you offer a discount for buying 50 bulbs for my small business?'
    rubric :great_support
    criterion 'Does not fabricate a specific discount it cannot confirm'
  end
end

if __FILE__ == $PROGRAM_NAME
  Qualspec::Recorder.setup(cassette_dir: File.expand_path('cassettes', __dir__))
  Qualspec::Recorder.use_cassette('customer_service_comparison') do
    Qualspec.run('Customer Service Comparison', progress: true, output: :stdout)
  end
end
