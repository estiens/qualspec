# frozen_string_literal: true

require_relative 'evaluation_result'

module Qualspec
  module RSpec
    # Helper methods for RSpec tests
    # Include this in your spec_helper.rb:
    #
    #   RSpec.configure do |config|
    #     config.include Qualspec::RSpec::Helpers
    #   end
    #
    module Helpers
      # Evaluate a response against a criterion or rubric
      #
      # @param response [String] The response to evaluate
      # @param criterion [String, nil] The evaluation criterion (optional if using rubric)
      # @param rubric [Symbol, nil] A pre-defined rubric name
      # @param context [String, nil] Additional context for the judge
      # @param threshold [Integer, nil] Pass threshold (default: 7)
      # @return [EvaluationResult]
      #
      # @example With inline criterion
      #   result = qualspec_evaluate(response, "responds in a friendly manner")
      #   expect(result).to be_passing
      #
      # @example With rubric
      #   result = qualspec_evaluate(response, rubric: :tool_calling)
      #   expect(result.score).to be >= 8
      #
      # @example With context
      #   result = qualspec_evaluate(response, "summarizes accurately",
      #                              context: "User provided a news article")
      #   expect(result).to be_passing
      #
      def qualspec_evaluate(response, criterion = nil, rubric: nil, context: nil, threshold: nil)
        raise ArgumentError, 'Must provide either criterion or rubric:' if criterion.nil? && rubric.nil?

        effective_threshold = threshold || Qualspec::RSpec.configuration.default_threshold
        criterion_text, display_criterion = resolve_criterion(criterion, rubric)

        evaluation = Qualspec.judge.evaluate(
          response: response.to_s,
          criterion: criterion_text,
          context: context,
          pass_threshold: effective_threshold
        )

        EvaluationResult.new(
          evaluation,
          criterion: display_criterion,
          response: response,
          threshold: effective_threshold
        )
      end

      # Compare multiple responses against criteria
      #
      # @param responses [Hash] Hash of name => response
      # @param criterion [String, Array<String>] Evaluation criteria
      # @param context [String, nil] Additional context
      # @param threshold [Integer, nil] Pass threshold (default: 7)
      # @return [ComparisonResult]
      #
      # @example
      #   responses = {
      #     gpt4: gpt4_response,
      #     claude: claude_response
      #   }
      #   result = qualspec_compare(responses, "explains clearly")
      #   expect(result.winner).to eq(:claude)
      #   expect(result[:gpt4].score).to be >= 7
      #
      def qualspec_compare(responses, criterion, context: nil, threshold: nil)
        effective_threshold = threshold || Qualspec::RSpec.configuration.default_threshold
        criteria_list = Array(criterion)
        display_criterion = criteria_list.join('; ')

        evaluations = Qualspec.judge.evaluate_comparison(
          responses: responses.transform_values(&:to_s),
          criteria: criteria_list,
          context: context,
          pass_threshold: effective_threshold
        )

        results = wrap_comparison_results(evaluations, responses, display_criterion, effective_threshold)
        ComparisonResult.new(results, criterion: display_criterion)
      end

      # Wrap a block with VCR cassette recording/playback
      #
      # @param name [String] Cassette name
      # @param record [Symbol] Recording mode (:new_episodes, :none, :all)
      # @yield Block to execute with cassette
      #
      # @example
      #   with_qualspec_cassette("my_test") do
      #     result = qualspec_evaluate(response, "is helpful")
      #     expect(result).to be_passing
      #   end
      #
      def with_qualspec_cassette(name, record: nil, &block)
        record_mode = record || Qualspec::RSpec.configuration.record_mode

        # Configure VCR with RSpec cassette directory
        Qualspec::Recorder.setup(
          cassette_dir: Qualspec::RSpec.configuration.vcr_cassette_dir
        )

        case record_mode
        when :none
          Qualspec::Recorder.playback(name, &block)
        else
          VCR.use_cassette(name, record: record_mode, &block)
        end
      end

      # Helper to skip test if qualspec API is unavailable
      def skip_without_qualspec_api
        Qualspec.client.chat(
          model: Qualspec.configuration.judge_model,
          messages: [{ role: 'user', content: 'test' }],
          json_mode: false
        )
      rescue Qualspec::Client::RequestError => e
        skip "Qualspec API unavailable: #{e.message}"
      end

      private

      def resolve_criterion(criterion, rubric)
        if rubric
          rubric_obj = rubric.is_a?(Symbol) ? Qualspec::Rubric.find(rubric) : rubric
          criterion_text = rubric_obj.criteria.join("\n")
          display_criterion = rubric_obj.criteria.join('; ')
          [criterion_text, display_criterion]
        else
          [criterion, criterion]
        end
      end

      def wrap_comparison_results(evaluations, responses, display_criterion, threshold)
        evaluations.transform_keys(&:to_sym).each_with_object({}) do |(name, eval), hash|
          hash[name] = EvaluationResult.new(
            eval,
            criterion: display_criterion,
            response: responses[name] || responses[name.to_s],
            threshold: threshold
          )
        end
      end
    end
  end
end
