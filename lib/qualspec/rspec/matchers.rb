# frozen_string_literal: true

require 'rspec/expectations'

module Qualspec
  module RSpec
    # Custom RSpec matchers for qualspec evaluations
    #
    # These matchers work with EvaluationResult objects returned by qualspec_evaluate
    #
    # @example
    #   result = qualspec_evaluate(response, "is helpful")
    #   expect(result).to be_passing
    #   expect(result).to have_score_above(7)
    #
    module Matchers
      extend ::RSpec::Matchers::DSL

      # Matcher for checking if evaluation passed
      #
      # @example
      #   expect(result).to be_passing
      #
      matcher :be_passing do
        match do |result|
          result.respond_to?(:passing?) && result.passing?
        end

        failure_message do |result|
          if result.respond_to?(:failure_message)
            result.failure_message
          else
            "expected #{result.inspect} to be passing"
          end
        end

        failure_message_when_negated do |result|
          if result.respond_to?(:failure_message_when_negated)
            result.failure_message_when_negated
          else
            "expected #{result.inspect} not to be passing"
          end
        end
      end

      # Matcher for checking if evaluation failed
      #
      # @example
      #   expect(result).to be_failing
      #
      matcher :be_failing do
        match do |result|
          result.respond_to?(:failing?) && result.failing?
        end

        failure_message do |result|
          "expected evaluation to fail, but it passed with score #{result.score}/10"
        end

        failure_message_when_negated do |result|
          "expected evaluation not to fail, but it failed with score #{result.score}/10"
        end
      end

      # Matcher for checking exact score
      #
      # @example
      #   expect(result).to have_score(10)
      #
      matcher :have_score do |expected|
        match do |result|
          result.respond_to?(:score) && result.score == expected
        end

        failure_message do |result|
          "expected score to be #{expected}, but was #{result.score}"
        end
      end

      # Matcher for checking score is above threshold
      #
      # @example
      #   expect(result).to have_score_above(7)
      #
      matcher :have_score_above do |threshold|
        match do |result|
          result.respond_to?(:score) && result.score > threshold
        end

        failure_message do |result|
          "expected score > #{threshold}, but was #{result.score}"
        end
      end

      # Matcher for checking score is at or above threshold
      #
      # @example
      #   expect(result).to have_score_at_least(7)
      #
      matcher :have_score_at_least do |threshold|
        match do |result|
          result.respond_to?(:score) && result.score >= threshold
        end

        failure_message do |result|
          "expected score >= #{threshold}, but was #{result.score}"
        end
      end

      # Matcher for checking score is below threshold
      #
      # @example
      #   expect(result).to have_score_below(5)
      #
      matcher :have_score_below do |threshold|
        match do |result|
          result.respond_to?(:score) && result.score < threshold
        end

        failure_message do |result|
          "expected score < #{threshold}, but was #{result.score}"
        end
      end

      # Matcher for comparison winner
      #
      # @example
      #   expect(comparison).to have_winner(:claude)
      #
      matcher :have_winner do |expected_winner|
        match do |result|
          result.respond_to?(:winner?) && result.winner?(expected_winner)
        end

        failure_message do |result|
          "expected winner to be #{expected_winner}, but was #{result.winner}"
        end
      end

      # Matcher for comparison tie
      #
      # @example
      #   expect(comparison).to be_a_tie
      #
      matcher :be_a_tie do
        match do |result|
          result.respond_to?(:tie?) && result.tie?
        end

        failure_message do |result|
          "expected a tie, but winner was #{result.winner}"
        end
      end
    end
  end
end

# Auto-include matchers when RSpec is loaded
if defined?(RSpec) && RSpec.respond_to?(:configure)
  RSpec.configure do |config|
    config.include Qualspec::RSpec::Matchers
  end
end
