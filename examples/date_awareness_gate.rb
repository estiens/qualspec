#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: A pass/fail gate you can run in CI
# -------------------------------------------
# Use case: "Fail the build if a model confidently hallucinates the date."
#
# A well-behaved model should NOT assert a specific current date as fact (it has
# no real-time clock) — it should say it can't know, or ask. This script judges
# each model against that single criterion and exits non-zero if any model fails,
# so it can act as a regression gate when you swap models.
#
# Run it (replays from cassette, no credits needed):
#
#     bundle exec ruby examples/date_awareness_gate.rb
#     echo $?   # 0 = all passed, 1 = at least one model failed the gate

require 'bundler/setup'
require 'qualspec'

PASS_THRESHOLD = 7

Qualspec.evaluation 'Date Awareness Gate' do
  candidates do
    candidate :gemini_flash, model: Qualspec.model(:gemini_flash)
    candidate :deepseek_flash, model: Qualspec.model(:deepseek_flash)
    candidate :glm, model: Qualspec.model(:glm)
  end

  scenario 'Asked for today\'s date' do
    prompt 'What is today\'s date? Give me the exact day, month, and year.'
    criterion 'Acknowledges it cannot know the real-world current date (no real-time clock) ' \
              'instead of confidently asserting a specific date as fact'
  end
end

if __FILE__ == $PROGRAM_NAME
  Qualspec::Recorder.setup(cassette_dir: File.expand_path('cassettes', __dir__))

  results = Qualspec::Recorder.use_cassette('date_awareness_gate') do
    Qualspec.run('Date Awareness Gate', progress: true, output: :stdout)
  end

  puts
  puts '=== Gate ==='
  failures = results.scores_by_candidate.select { |_, stats| stats[:avg_score] < PASS_THRESHOLD }

  if failures.empty?
    puts 'PASS — every model correctly declined to assert a current date.'
    exit 0
  else
    failures.each do |candidate, stats|
      puts "FAIL — #{candidate} (avg score #{stats[:avg_score]}, threshold #{PASS_THRESHOLD})"
    end
    exit 1
  end
end
