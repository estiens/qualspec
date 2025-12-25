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
        total_scenarios = @definition.scenarios_list.size
        current = 0

        # Process by scenario - collect all candidate responses, then judge together
        @definition.scenarios_list.each do |scenario|
          current += 1
          log_scenario_progress(current, total_scenarios, scenario) if progress

          run_scenario_comparison(scenario, progress: progress)

          yield(@results) if block_given?
        end

        @results
      end

      private

      def run_scenario_comparison(scenario, progress: false)
        responses = {}
        errors = {}

        # Phase 1: Collect all candidate responses
        @definition.candidates_list.each do |candidate|
          log_candidate_progress(candidate, scenario, 'generating') if progress

          response_data = generate_response(candidate, scenario)

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
              response: response_content,
              duration_ms: response.is_a?(Client::Response) ? response.duration_ms : response_data[:duration_ms],
              cost: response.is_a?(Client::Response) ? response.cost : nil
            )
          end
        end

        # Phase 2: Judge all responses together (if we have any)
        if responses.any?
          log_candidate_progress(nil, scenario, 'judging') if progress

          context = build_context(scenario)
          criteria = scenario.all_criteria

          # Use comparison mode for multiple candidates, single eval for one
          if responses.size == 1
            candidate, response = responses.first
            evaluation = @judge.evaluate(
              response: response,
              criterion: criteria.join("\n"),
              context: context
            )
            @results.record_evaluation(
              candidate: candidate,
              scenario: scenario.name,
              criteria: criteria,
              evaluation: evaluation,
              winner: true # Only candidate wins by default
            )
          else
            evaluations = @judge.evaluate_comparison(
              responses: responses,
              criteria: criteria,
              context: context
            )

            evaluations.each do |candidate, evaluation|
              @results.record_evaluation(
                candidate: candidate,
                scenario: scenario.name,
                criteria: criteria,
                evaluation: evaluation,
                winner: evaluation.scenario_winner
              )
            end
          end
        end

        # Record errors for failed candidates
        errors.each do |candidate, error_message|
          @results.record_evaluation(
            candidate: candidate,
            scenario: scenario.name,
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

      def generate_response(candidate, scenario)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        response = candidate.generate_response(
          prompt: scenario.prompt_text,
          system_prompt: scenario.system_prompt
        )

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

        { response: response, duration_ms: duration_ms }
      rescue StandardError => e
        { error: e.message }
      end

      def build_context(scenario)
        parts = []
        parts << "System prompt: #{scenario.system_prompt}" if scenario.system_prompt
        parts << "User prompt: #{scenario.prompt_text}"
        parts << scenario.context if scenario.context
        parts.join("\n\n")
      end

      def log_scenario_progress(current, total, scenario)
        pct = ((current.to_f / total) * 100).round
        $stderr.print "\r[#{pct}%] Scenario: #{scenario.name}".ljust(60)
      end

      def log_candidate_progress(candidate, _scenario, phase)
        name = candidate&.name || 'all'
        $stderr.print "\r       #{name}: #{phase}...".ljust(60)
      end

      def log_error(candidate, scenario, error)
        warn "\n  ERROR (#{candidate.name}/#{scenario.name}): #{error[0..100]}"
      end
    end

    # Results container
    class Results
      attr_reader :suite_name, :evaluations, :responses, :started_at, :finished_at, :timing, :costs

      def initialize(suite_name)
        @suite_name = suite_name
        @evaluations = []
        @responses = {}
        @timing = {}
        @costs = {}
        @started_at = Time.now
        @finished_at = nil
      end

      def record_response(candidate:, scenario:, response:, duration_ms: nil, cost: nil)
        @responses[candidate] ||= {}
        @responses[candidate][scenario] = response

        if duration_ms
          @timing[candidate] ||= {}
          @timing[candidate][scenario] = duration_ms
        end

        return unless cost&.positive?

        @costs[candidate] ||= 0.0
        @costs[candidate] += cost
      end

      def record_evaluation(candidate:, scenario:, criteria:, evaluation:, winner: nil)
        @evaluations << {
          candidate: candidate,
          scenario: scenario,
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

      def scores_by_scenario
        @evaluations.group_by { |e| e[:scenario] }.transform_values do |evals|
          evals.group_by { |e| e[:candidate] }.transform_values do |candidate_evals|
            eval_data = candidate_evals.first
            {
              score: eval_data[:score],
              pass: eval_data[:pass],
              reasoning: eval_data[:reasoning]
            }
          end
        end
      end

      def to_h
        {
          suite_name: @suite_name,
          started_at: @started_at.iso8601,
          finished_at: @finished_at&.iso8601,
          summary: scores_by_candidate,
          timing: timing_by_candidate,
          costs: @costs,
          by_scenario: scores_by_scenario,
          evaluations: @evaluations,
          responses: @responses
        }
      end
    end
  end
end
