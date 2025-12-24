# frozen_string_literal: true

module Qualspec
  module Suite
    class Runner
      attr_reader :definition, :results

      def initialize(definition)
        @definition = definition.is_a?(String) ? Suite.find(definition) : definition
        @results = Results.new(@definition.name)
        @judge = Qualspec.judge
      end

      def run(progress: true, &block)
        total = @definition.candidates_list.size * @definition.scenarios_list.size
        current = 0

        @definition.candidates_list.each do |candidate|
          @definition.scenarios_list.each do |scenario|
            current += 1
            log_progress(current, total, candidate, scenario) if progress

            run_scenario(candidate, scenario)

            yield(@results) if block_given?
          end
        end

        @results
      end

      private

      def run_scenario(candidate, scenario)
        # Generate response from candidate with timing
        response_data = generate_response(candidate, scenario)

        if response_data[:error]
          record_error(candidate, scenario, response_data[:error])
          return
        end

        response = response_data[:response]
        response_content = response.is_a?(Client::Response) ? response.content : response

        # Record the response with metadata
        @results.record_response(
          candidate: candidate.name,
          scenario: scenario.name,
          response: response_content,
          duration_ms: response.is_a?(Client::Response) ? response.duration_ms : response_data[:duration_ms],
          cost: response.is_a?(Client::Response) ? response.cost : nil
        )

        # Evaluate each criterion
        context = build_context(candidate, scenario)

        scenario.all_criteria.each do |criterion|
          evaluation = @judge.evaluate(
            response: response_content,
            criterion: criterion,
            context: context
          )

          @results.record_evaluation(
            candidate: candidate.name,
            scenario: scenario.name,
            criterion: criterion,
            evaluation: evaluation
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

      def build_context(candidate, scenario)
        parts = []
        parts << "System prompt: #{scenario.system_prompt}" if scenario.system_prompt
        parts << "User prompt: #{scenario.prompt_text}"
        parts << scenario.context if scenario.context
        parts.join("\n\n")
      end

      def record_error(candidate, scenario, error_message)
        scenario.all_criteria.each do |criterion|
          @results.record_evaluation(
            candidate: candidate.name,
            scenario: scenario.name,
            criterion: criterion,
            evaluation: Evaluation.new(
              criterion: criterion,
              score: 0,
              pass: false,
              error: error_message
            )
          )
        end
      end

      def log_progress(current, total, candidate, scenario)
        pct = ((current.to_f / total) * 100).round
        $stderr.print "\r[#{pct}%] #{candidate.name}: #{scenario.name}".ljust(60)
        $stderr.print "\n" if current == total
      end
    end

    # Results container
    class Results
      attr_reader :suite_name, :evaluations, :responses, :started_at, :finished_at
      attr_reader :timing, :costs

      def initialize(suite_name)
        @suite_name = suite_name
        @evaluations = []
        @responses = {}
        @timing = {}    # candidate => { scenario => duration_ms }
        @costs = {}     # candidate => total_cost
        @started_at = Time.now
        @finished_at = nil
      end

      def record_response(candidate:, scenario:, response:, duration_ms: nil, cost: nil)
        @responses[candidate] ||= {}
        @responses[candidate][scenario] = response

        # Track timing
        if duration_ms
          @timing[candidate] ||= {}
          @timing[candidate][scenario] = duration_ms
        end

        # Track costs
        if cost && cost > 0
          @costs[candidate] ||= 0.0
          @costs[candidate] += cost
        end
      end

      def record_evaluation(candidate:, scenario:, criterion:, evaluation:)
        @evaluations << {
          candidate: candidate,
          scenario: scenario,
          criterion: criterion,
          score: evaluation.score,
          pass: evaluation.pass?,
          reasoning: evaluation.reasoning,
          error: evaluation.error
        }
      end

      def finish!
        @finished_at = Time.now
      end

      # Aggregate scores by candidate
      def scores_by_candidate
        @evaluations.group_by { |e| e[:candidate] }.transform_values do |evals|
          passed = evals.count { |e| e[:pass] }
          total = evals.size
          avg_score = evals.sum { |e| e[:score] }.to_f / total

          {
            passed: passed,
            total: total,
            pass_rate: (passed.to_f / total * 100).round(1),
            avg_score: avg_score.round(2)
          }
        end
      end

      # Aggregate timing by candidate
      def timing_by_candidate
        @timing.transform_values do |scenarios|
          total_ms = scenarios.values.sum
          avg_ms = total_ms / scenarios.size
          {
            total_ms: total_ms,
            avg_ms: avg_ms.round,
            count: scenarios.size
          }
        end
      end

      # Aggregate scores by scenario
      def scores_by_scenario
        @evaluations.group_by { |e| e[:scenario] }.transform_values do |evals|
          evals.group_by { |e| e[:candidate] }.transform_values do |candidate_evals|
            avg_score = candidate_evals.sum { |e| e[:score] }.to_f / candidate_evals.size
            {
              avg_score: avg_score.round(2),
              passed: candidate_evals.count { |e| e[:pass] },
              total: candidate_evals.size
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
