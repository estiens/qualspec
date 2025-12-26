# frozen_string_literal: true

require 'time'

module Qualspec
  module Suite
    class Runner
      attr_reader :definition, :results

      def initialize(definition)
        @definition = definition.is_a?(String) ? Suite.find(definition) : definition
        @results = Results.new(@definition.name)
        @judge = Qualspec.judge
      end

      def run(progress: true)
        variants = build_variants
        temperatures = @definition.temperature_list

        total_iterations = @definition.scenarios_list.size * variants.size * temperatures.size
        current = 0

        @definition.scenarios_list.each do |scenario|
          variants.each do |variant|
            temperatures.each do |temperature|
              current += 1
              log_iteration_progress(current, total_iterations, scenario, variant, temperature) if progress

              run_scenario_with_variant(scenario, variant, temperature, progress: progress)

              yield(@results) if block_given?
            end
          end
        end

        @results.finish!
        $stderr.puts if progress # Clear progress line
        @results
      end

      private

      def build_variants
        if @definition.variants_config
          @definition.variants_config.build_variants
        else
          [nil] # No variants configured - run scenarios as-is
        end
      end

      def run_scenario_with_variant(scenario, variant, temperature, progress: false)
        responses = {}
        errors = {}

        # Phase 1: Collect all candidate responses
        @definition.candidates_list.each do |candidate|
          log_candidate_progress(candidate, scenario, 'generating') if progress

          response_data = generate_response_with_variant(candidate, scenario, variant, temperature)

          if response_data[:error]
            log_error(candidate, scenario, response_data[:error])
            errors[candidate.name] = response_data[:error]
          else
            response = response_data[:response]
            response_content = response.is_a?(Client::Response) ? response.content : response

            responses[candidate.name] = response_content

            @results.record_response(
              candidate: candidate.name,
              scenario: scenario.name,
              variant: variant&.variant_key || 'default',
              temperature: temperature,
              response: response_content,
              duration_ms: response.is_a?(Client::Response) ? response.duration_ms : response_data[:duration_ms],
              cost: response.is_a?(Client::Response) ? response.cost : nil,
              variant_data: variant&.to_h
            )
          end
        end

        # Phase 2: Judge all responses together
        judge_responses(responses, scenario, variant, temperature, progress: progress) if responses.any?

        # Record errors
        record_errors(errors, scenario, variant, temperature)
      end

      def generate_response_with_variant(candidate, scenario, variant, temperature)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # Compose prompt with variant
        final_prompt = scenario.compose_prompt(variant)
        final_system_prompt = scenario.compose_system_prompt(variant, candidate.system_prompt)

        # Use variant temperature if no explicit temperature and variant has one
        effective_temperature = temperature || variant&.temperature

        response = candidate.generate_response(
          prompt: final_prompt,
          system_prompt: final_system_prompt,
          temperature: effective_temperature
        )

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

        { response: response, duration_ms: duration_ms }
      rescue StandardError => e
        { error: e.message }
      end

      def judge_responses(responses, scenario, variant, temperature, progress: false)
        log_candidate_progress(nil, scenario, 'judging') if progress

        context = build_context(scenario, variant)
        criteria = scenario.all_criteria

        if responses.size == 1
          judge_single_response(responses, scenario, variant, temperature, criteria, context)
        else
          judge_comparison(responses, scenario, variant, temperature, criteria, context)
        end
      end

      def judge_single_response(responses, scenario, variant, temperature, criteria, context)
        candidate, response = responses.first
        evaluation = @judge.evaluate(
          response: response,
          criterion: criteria.join("\n"),
          context: context
        )
        @results.record_evaluation(
          candidate: candidate,
          scenario: scenario.name,
          variant: variant&.variant_key || 'default',
          temperature: temperature,
          criteria: criteria,
          evaluation: evaluation,
          winner: true
        )
      end

      def judge_comparison(responses, scenario, variant, temperature, criteria, context)
        evaluations = @judge.evaluate_comparison(
          responses: responses,
          criteria: criteria,
          context: context
        )

        evaluations.each do |candidate, evaluation|
          @results.record_evaluation(
            candidate: candidate,
            scenario: scenario.name,
            variant: variant&.variant_key || 'default',
            temperature: temperature,
            criteria: criteria,
            evaluation: evaluation,
            winner: evaluation.scenario_winner
          )
        end
      end

      def build_context(scenario, variant = nil)
        parts = []

        # Include variant context if available
        if variant
          parts << "Variant: #{variant.name}" if variant.name && variant.name != 'default'
          cred = variant.credential.to_s.strip
          parts << "User credential: #{cred}" unless cred.empty?
          parts << "User stance: #{variant.stance}" if variant.stance && variant.stance != :neutral
        end

        sys = scenario.compose_system_prompt(variant)
        parts << "System prompt: #{sys}" if sys
        parts << "User prompt: #{scenario.compose_prompt(variant)}"
        parts << scenario.context if scenario.context

        parts.join("\n\n")
      end

      def record_errors(errors, scenario, variant, temperature)
        errors.each do |candidate, error_message|
          @results.record_evaluation(
            candidate: candidate,
            scenario: scenario.name,
            variant: variant&.variant_key || 'default',
            temperature: temperature,
            criteria: scenario.all_criteria,
            evaluation: Evaluation.new(
              criterion: scenario.all_criteria.join("\n"),
              score: 0,
              pass: false,
              error: error_message
            )
          )
        end
      end

      def log_iteration_progress(current, total, scenario, variant, temperature)
        pct = ((current.to_f / total) * 100).round
        variant_str = variant && variant.name != 'default' ? " [#{variant.name}]" : ''
        temp_str = temperature ? " @#{temperature}" : ''
        $stderr.print "\r[#{pct}%] #{scenario.name}#{variant_str}#{temp_str}".ljust(70)
      end

      def log_candidate_progress(candidate, _scenario, phase)
        name = candidate&.name || 'all'
        $stderr.print "\r       #{name}: #{phase}...".ljust(70)
      end

      def log_error(candidate, scenario, error)
        warn "\n  ERROR (#{candidate.name}/#{scenario.name}): #{error[0..100]}"
      end
    end

    # Results container with multi-dimensional support
    class Results
      attr_reader :suite_name, :evaluations, :responses, :started_at, :finished_at, :timing, :costs

      def initialize(suite_name)
        @suite_name = suite_name
        @evaluations = []
        @responses = {} # Nested: {candidate => {scenario => {variant => {temp => response}}}}
        @timing = {}
        @costs = {}
        @started_at = Time.now
        @finished_at = nil
      end

      def record_response(candidate:, scenario:, response:, variant: 'default', temperature: nil, duration_ms: nil, cost: nil, variant_data: nil)
        # Store in nested structure
        @responses[candidate] ||= {}
        @responses[candidate][scenario] ||= {}
        @responses[candidate][scenario][variant] ||= {}
        @responses[candidate][scenario][variant][temperature] = {
          content: response,
          variant_data: variant_data
        }

        if duration_ms
          @timing[candidate] ||= {}
          @timing[candidate]["#{scenario}/#{variant}"] = duration_ms
        end

        return unless cost&.positive?

        @costs[candidate] ||= 0.0
        @costs[candidate] += cost
      end

      def record_evaluation(candidate:, scenario:, criteria:, evaluation:, variant: 'default', temperature: nil, winner: nil)
        @evaluations << {
          candidate: candidate,
          scenario: scenario,
          variant: variant,
          temperature: temperature,
          criteria: criteria,
          criteria_count: Array(criteria).size,
          score: evaluation.score,
          pass: evaluation.pass?,
          reasoning: evaluation.reasoning,
          error: evaluation.error,
          winner: winner
        }
      end

      def finish!
        @finished_at = Time.now
      end

      # Group scores by candidate, aggregating across all variants
      def scores_by_candidate
        @evaluations.group_by { |e| e[:candidate] }.transform_values do |evals|
          passed = evals.count { |e| e[:pass] }
          total = evals.size
          avg_score = total.positive? ? evals.sum { |e| e[:score] }.to_f / total : 0

          {
            passed: passed,
            total: total,
            pass_rate: total.positive? ? (passed.to_f / total * 100).round(1) : 0,
            avg_score: avg_score.round(2)
          }
        end
      end

      # Group scores by variant
      def scores_by_variant
        @evaluations.group_by { |e| e[:variant] }.transform_values do |evals|
          passed = evals.count { |e| e[:pass] }
          total = evals.size
          avg_score = total.positive? ? evals.sum { |e| e[:score] }.to_f / total : 0

          {
            passed: passed,
            total: total,
            pass_rate: total.positive? ? (passed.to_f / total * 100).round(1) : 0,
            avg_score: avg_score.round(2)
          }
        end
      end

      # Temperature sensitivity analysis
      def scores_by_temperature
        by_temp = @evaluations.group_by { |e| e[:temperature] }
        by_temp.transform_values do |evals|
          {
            avg_score: (evals.sum { |e| e[:score] }.to_f / evals.size).round(2),
            pass_rate: (evals.count { |e| e[:pass] }.to_f / evals.size * 100).round(1)
          }
        end
      end

      def timing_by_candidate
        @timing.transform_values do |scenarios|
          total_ms = scenarios.values.sum
          avg_ms = !scenarios.empty? ? total_ms / scenarios.size : 0
          {
            total_ms: total_ms,
            avg_ms: avg_ms.round,
            count: scenarios.size
          }
        end
      end

      # Detailed breakdown by scenario + variant
      def scores_by_scenario
        @evaluations.group_by { |e| e[:scenario] }.transform_values do |evals|
          evals.group_by { |e| e[:candidate] }.transform_values do |candidate_evals|
            eval_data = candidate_evals.first
            {
              score: eval_data[:score],
              pass: eval_data[:pass],
              reasoning: eval_data[:reasoning],
              variant: eval_data[:variant],
              temperature: eval_data[:temperature]
            }
          end
        end
      end

      # Cross-tabulation: scenario × variant
      def scores_by_scenario_variant
        @evaluations.group_by { |e| [e[:scenario], e[:variant]] }.transform_values do |evals|
          evals.group_by { |e| e[:candidate] }.transform_values do |candidate_evals|
            eval_data = candidate_evals.first
            {
              score: eval_data[:score],
              pass: eval_data[:pass],
              reasoning: eval_data[:reasoning],
              temperature: eval_data[:temperature]
            }
          end
        end
      end

      def to_h
        {
          suite_name: @suite_name,
          started_at: @started_at.iso8601,
          finished_at: @finished_at&.iso8601,
          summary: {
            by_candidate: scores_by_candidate,
            by_variant: scores_by_variant,
            by_temperature: scores_by_temperature
          },
          timing: timing_by_candidate,
          costs: @costs,
          by_scenario: scores_by_scenario,
          by_scenario_variant: scores_by_scenario_variant,
          evaluations: @evaluations,
          responses: @responses
        }
      end
    end
  end
end
