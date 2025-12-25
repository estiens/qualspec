# frozen_string_literal: true

module Qualspec
  module RSpec
    # Wrapper around Qualspec::Evaluation with RSpec-friendly interface
    # Provides clean methods and good failure message formatting
    class EvaluationResult
      attr_reader :evaluation, :criterion, :response, :threshold

      def initialize(evaluation, criterion:, response:, threshold: nil)
        @evaluation = evaluation
        @criterion = criterion
        @response = response
        @threshold = threshold || Qualspec::RSpec.configuration.default_threshold
      end

      # Core result methods
      def passing?
        evaluation.pass?
      end

      def failing?
        !passing?
      end

      def score
        evaluation.score
      end

      def reasoning
        evaluation.reasoning
      end

      def error?
        !evaluation.error.nil?
      end

      def error
        evaluation.error
      end

      # Comparison support
      def winner?
        evaluation.scenario_winner == true
      end

      def tie?
        evaluation.scenario_winner == :tie
      end

      # Nice output for RSpec failure messages
      def inspect
        status = passing? ? 'PASS' : 'FAIL'
        lines = [
          "#<Qualspec::RSpec::EvaluationResult #{status}>",
          "  Criterion: #{criterion}",
          "  Score: #{score}/10 (threshold: #{threshold})",
          "  Reasoning: #{reasoning}"
        ]
        lines << "  Error: #{error}" if error?
        lines << "  Response (first 200 chars): #{response.to_s[0, 200]}..."
        lines.join("\n")
      end

      # RSpec failure message formatting
      def failure_message
        <<~MSG
          Expected response to pass qualspec evaluation, but it failed.

          Criterion: #{criterion}
          Score: #{score}/10 (needed #{threshold} to pass)
          Reasoning: #{reasoning}
          #{"Error: #{error}" if error?}
          Response preview: #{response.to_s[0, 300]}#{'...' if response.to_s.length > 300}
        MSG
      end

      def failure_message_when_negated
        <<~MSG
          Expected response to fail qualspec evaluation, but it passed.

          Criterion: #{criterion}
          Score: #{score}/10 (threshold: #{threshold})
          Reasoning: #{reasoning}
        MSG
      end
    end

    # Result for comparative evaluations
    class ComparisonResult
      attr_reader :results, :winner, :criterion

      def initialize(results, criterion:)
        @results = results # Hash of name => EvaluationResult
        @criterion = criterion
        @winner = determine_winner
      end

      def [](name)
        results[name.to_sym]
      end

      def tie?
        winner == :tie
      end

      def winner?(name)
        winner.to_s == name.to_s
      end

      def scores
        results.transform_values(&:score)
      end

      def inspect
        lines = ['#<Qualspec::RSpec::ComparisonResult>']
        lines << "  Criterion: #{criterion}"
        lines << "  Winner: #{winner}"
        results.each do |name, result|
          marker = winner?(name) ? '*' : ' '
          lines << "  #{marker} #{name}: #{result.score}/10 - #{result.reasoning}"
        end
        lines.join("\n")
      end

      private

      def determine_winner
        # Check if any result has winner flag set
        results.each do |name, result|
          return name if result.winner?
          return :tie if result.tie?
        end

        # Fallback: highest score wins
        max_score = results.values.map(&:score).max
        winners = results.select { |_, r| r.score == max_score }
        winners.size == 1 ? winners.keys.first : :tie
      end
    end
  end
end
