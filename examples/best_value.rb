#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Best response-per-dollar (cost/value trade-off)
# -------------------------------------------------------
# Use case: "Is the expensive model actually worth it for this task?"
#
# Enables `track_cost`, which makes qualspec capture per-call cost from
# OpenRouter's usage accounting. It then reports both the quality winner and the
# value winner (avg score per dollar), so you can decide whether a pricier model
# earns its keep.
#
# Run it (replays from cassette, no credits needed):
#
#     bundle exec ruby examples/best_value.rb

require 'bundler/setup'
require 'qualspec'

Qualspec.define_rubric :reasoning_quality do
  criterion 'Reaches the correct conclusion'
  criterion 'Shows clear, valid step-by-step reasoning'
  criterion 'Does not pad with irrelevant filler'
end

Qualspec.evaluation 'Best Value' do
  track_cost # <-- capture per-call cost so value_ranking works

  candidates do
    candidate :flash, model: Qualspec.model(:deepseek_flash) # cheap
    candidate :glm,   model: Qualspec.model(:glm)            # mid
    candidate :pro,   model: Qualspec.model(:deepseek_pro)   # pricey
  end

  scenario 'Word problem' do
    prompt 'A bat and a ball cost $1.10 total. The bat costs $1.00 more than the ball. ' \
           'How much does the ball cost? Explain your reasoning.'
    rubric :reasoning_quality
  end

  scenario 'Logic puzzle' do
    prompt 'If all Bloops are Razzies and all Razzies are Lazzies, are all Bloops definitely Lazzies? ' \
           'Explain.'
    rubric :reasoning_quality
  end
end

if __FILE__ == $PROGRAM_NAME
  Qualspec::Recorder.setup(cassette_dir: File.expand_path('cassettes', __dir__))

  results = Qualspec::Recorder.use_cassette('best_value') do
    Qualspec.run('Best Value', progress: true, output: :stdout)
  end

  puts
  puts '=== Value ranking (quality per dollar) ==='
  printf("%-8s %8s %12s %14s\n", 'model', 'score', 'cost', 'score/$')
  results.value_ranking.each do |candidate, v|
    printf("%-8s %8.2f %12.6f %14s\n", candidate, v[:avg_score], v[:cost], v[:score_per_dollar] || 'n/a')
  end

  best_quality = results.scores_by_candidate.max_by { |_, s| s[:avg_score] }&.first
  best_value   = results.value_ranking.keys.first
  puts
  puts "Highest quality: #{best_quality}"
  puts "Best value:      #{best_value}"
end
