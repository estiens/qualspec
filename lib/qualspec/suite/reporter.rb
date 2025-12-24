# frozen_string_literal: true

require "json"

module Qualspec
  module Suite
    class Reporter
      def initialize(results)
        @results = results
      end

      def to_stdout
        output = []
        output << header
        output << ""
        output << summary_table
        output << ""
        output << timing_section if has_timing?
        output << ""
        output << scenario_breakdown
        output << ""
        output << winner_announcement

        output.compact.join("\n")
      end

      def to_json(pretty: true)
        if pretty
          JSON.pretty_generate(@results.to_h)
        else
          JSON.generate(@results.to_h)
        end
      end

      def write_json(path)
        File.write(path, to_json)
      end

      private

      def header
        lines = []
        lines << "=" * 60
        lines << @results.suite_name.center(60)
        lines << "=" * 60
        lines.join("\n")
      end

      def summary_table
        scores = @results.scores_by_candidate
        return "No results" if scores.empty?

        # Calculate column widths
        candidates = scores.keys
        max_name = [candidates.map(&:length).max, 10].max

        lines = []
        lines << "## Summary"
        lines << ""

        # Header row
        header = "| #{"Candidate".ljust(max_name)} | Pass Rate |  Avg  | Passed | Total |"
        lines << header
        lines << "|#{"-" * (max_name + 2)}|-----------|-------|--------|-------|"

        # Sort by avg_score descending
        sorted = scores.sort_by { |_, v| -v[:avg_score] }

        sorted.each do |candidate, stats|
          pass_rate = "#{stats[:pass_rate]}%".rjust(8)
          avg = stats[:avg_score].to_s.rjust(5)
          passed = stats[:passed].to_s.rjust(6)
          total = stats[:total].to_s.rjust(5)

          lines << "| #{candidate.ljust(max_name)} | #{pass_rate} | #{avg} | #{passed} | #{total} |"
        end

        lines.join("\n")
      end

      def has_timing?
        !@results.timing.empty?
      end

      def timing_section
        timing = @results.timing_by_candidate
        return nil if timing.empty?

        costs = @results.costs

        lines = []
        lines << "## Performance"
        lines << ""

        # Sort by avg response time
        sorted = timing.sort_by { |_, v| v[:avg_ms] }

        sorted.each do |candidate, stats|
          line = "  #{candidate}: #{format_duration(stats[:avg_ms])} avg"
          line += " (#{format_duration(stats[:total_ms])} total)"

          # Add cost if available
          if costs[candidate] && costs[candidate] > 0
            line += " - $#{format_cost(costs[candidate])}"
          end

          lines << line
        end

        lines.join("\n")
      end

      def format_duration(ms)
        if ms >= 1000
          "#{(ms / 1000.0).round(2)}s"
        else
          "#{ms}ms"
        end
      end

      def format_cost(cost)
        if cost < 0.01
          "%.4f" % cost
        else
          "%.2f" % cost
        end
      end

      def scenario_breakdown
        by_scenario = @results.scores_by_scenario
        return "" if by_scenario.empty?

        candidates = @results.scores_by_candidate.keys

        lines = []
        lines << "## By Scenario"
        lines << ""

        by_scenario.each do |scenario, candidate_scores|
          lines << "### #{scenario}"

          candidates.each do |candidate|
            stats = candidate_scores[candidate]
            next unless stats

            score_bar = score_visualization(stats[:avg_score])
            timing_info = format_scenario_timing(candidate, scenario)

            line = "  #{candidate}: #{score_bar} #{stats[:avg_score]}/10 (#{stats[:passed]}/#{stats[:total]} passed)"
            line += " #{timing_info}" if timing_info

            lines << line
          end

          lines << ""
        end

        lines.join("\n")
      end

      def format_scenario_timing(candidate, scenario)
        duration = @results.timing.dig(candidate, scenario)
        return nil unless duration

        "[#{format_duration(duration)}]"
      end

      def score_visualization(score)
        filled = (score.to_f).round
        empty = 10 - filled
        "[#{"█" * filled}#{"░" * empty}]"
      end

      def winner_announcement
        scores = @results.scores_by_candidate
        return "" if scores.empty?

        sorted = scores.sort_by { |_, v| -v[:avg_score] }
        winner = sorted.first
        runner_up = sorted[1]

        lines = []
        lines << "-" * 60

        if sorted.size == 1
          lines << "Result: #{winner[0]} scored #{winner[1][:avg_score]}/10"
        elsif winner[1][:avg_score] == runner_up&.dig(1, :avg_score)
          tied = sorted.take_while { |_, v| v[:avg_score] == winner[1][:avg_score] }
          lines << "Result: TIE between #{tied.map(&:first).join(", ")}"
          lines << "        All scored #{winner[1][:avg_score]}/10 average"
        else
          margin = (winner[1][:avg_score] - runner_up[1][:avg_score]).round(2)
          lines << "Winner: #{winner[0]}"
          lines << "        #{winner[1][:avg_score]}/10 avg (#{winner[1][:pass_rate]}% pass rate)"
          lines << "        Beat #{runner_up[0]} by #{margin} points"
        end

        # Add timing comparison if available
        timing = @results.timing_by_candidate
        if timing.size > 1
          fastest = timing.min_by { |_, v| v[:avg_ms] }
          slowest = timing.max_by { |_, v| v[:avg_ms] }
          if fastest[0] != slowest[0]
            speedup = (slowest[1][:avg_ms].to_f / fastest[1][:avg_ms]).round(1)
            lines << ""
            lines << "Fastest: #{fastest[0]} (#{format_duration(fastest[1][:avg_ms])} avg)"
            lines << "         #{speedup}x faster than #{slowest[0]}"
          end
        end

        lines.join("\n")
      end
    end
  end
end
