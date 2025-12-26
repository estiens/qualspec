# frozen_string_literal: true

require 'json'

module Qualspec
  module Suite
    class Reporter
      def initialize(results, show_responses: false)
        @results = results
        @show_responses = show_responses
      end

      def to_stdout
        output = []
        output << header
        output << ''
        output << summary_table
        output << ''
        output << variant_summary if has_variants?
        output << ''
        output << timing_section if timing?
        output << ''
        output << scenario_breakdown
        output << ''
        output << responses_section if @show_responses
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
        lines << '=' * 60
        lines << @results.suite_name.center(60)
        lines << '=' * 60
        lines.join("\n")
      end

      def summary_table
        scores = @results.scores_by_candidate
        return 'No results' if scores.empty?

        candidates = scores.keys
        max_name = [candidates.map(&:length).max, 10].max

        # Count scenario wins
        wins = count_wins

        lines = []
        lines << '## Summary'
        lines << ''

        header = "| #{'Candidate'.ljust(max_name)} | Score |  Wins | Pass Rate |"
        lines << header
        lines << "|#{'-' * (max_name + 2)}|-------|-------|-----------|"

        sorted = scores.sort_by { |_, v| -v[:avg_score] }

        sorted.each do |candidate, stats|
          score = stats[:avg_score].to_s.rjust(5)
          win_count = (wins[candidate] || 0).to_s.rjust(5)
          pass_rate = "#{stats[:pass_rate]}%".rjust(8)

          lines << "| #{candidate.ljust(max_name)} | #{score} | #{win_count} | #{pass_rate} |"
        end

        lines.join("\n")
      end

      def count_wins
        wins = Hash.new(0)
        @results.evaluations.each do |eval|
          wins[eval[:candidate]] += 1 if eval[:winner] == true
        end
        wins
      end

      def timing?
        !@results.timing.empty?
      end

      def has_variants?
        by_variant = @results.scores_by_variant
        return false if by_variant.empty?
        return false if by_variant.size == 1 && by_variant.keys.first == 'default'

        true
      end

      def variant_summary
        by_variant = @results.scores_by_variant
        return nil if by_variant.empty?

        variants = by_variant.keys
        max_name = [variants.map(&:length).max, 10].max

        lines = []
        lines << '## By Variant'
        lines << ''

        header = "| #{'Variant'.ljust(max_name)} | Score | Pass Rate |"
        lines << header
        lines << "|#{'-' * (max_name + 2)}|-------|-----------|"

        sorted = by_variant.sort_by { |_, v| -v[:avg_score] }

        sorted.each do |variant, stats|
          score = stats[:avg_score].to_s.rjust(5)
          pass_rate = "#{stats[:pass_rate]}%".rjust(8)

          lines << "| #{variant.ljust(max_name)} | #{score} | #{pass_rate} |"
        end

        lines.join("\n")
      end

      def timing_section
        timing = @results.timing_by_candidate
        return nil if timing.empty?

        costs = @results.costs

        lines = []
        lines << '## Performance'
        lines << ''

        sorted = timing.sort_by { |_, v| v[:avg_ms] }

        sorted.each do |candidate, stats|
          line = "  #{candidate}: #{format_duration(stats[:avg_ms])} avg"
          line += " (#{format_duration(stats[:total_ms])} total)"

          line += " - $#{format_cost(costs[candidate])}" if costs[candidate]&.positive?

          lines << line
        end

        lines.join("\n")
      end

      def format_duration(milliseconds)
        if milliseconds >= 1000
          "#{(milliseconds / 1000.0).round(2)}s"
        else
          "#{milliseconds}ms"
        end
      end

      def format_cost(cost)
        if cost < 0.01
          format('%.4f', cost)
        else
          format('%.2f', cost)
        end
      end

      def scenario_breakdown
        by_scenario = @results.scores_by_scenario
        return '' if by_scenario.empty?

        candidates = @results.scores_by_candidate.keys

        lines = []
        lines << '## By Scenario'
        lines << ''

        by_scenario.each do |scenario, candidate_scores|
          # Find winner for this scenario
          winner = find_scenario_winner(scenario)
          winner_label = if winner == :tie
                           ' [TIE]'
                         else
                           winner ? " [Winner: #{winner}]" : ''
                         end

          lines << "### #{scenario}#{winner_label}"

          candidates.each do |candidate|
            stats = candidate_scores[candidate]
            next unless stats

            score_bar = score_visualization(stats[:score])
            timing_info = format_scenario_timing(candidate, scenario)
            win_marker = winner == candidate ? ' *' : ''

            line = "  #{candidate}: #{score_bar} #{stats[:score]}/10#{win_marker}"
            line += " #{timing_info}" if timing_info

            lines << line
          end

          lines << ''
        end

        lines.join("\n")
      end

      def find_scenario_winner(scenario)
        scenario_evals = @results.evaluations.select { |e| e[:scenario] == scenario }
        winner_eval = scenario_evals.find { |e| e[:winner] == true }
        return winner_eval[:candidate] if winner_eval

        tie_eval = scenario_evals.find { |e| e[:winner] == :tie }
        return :tie if tie_eval

        nil
      end

      def format_scenario_timing(candidate, scenario)
        duration = @results.timing.dig(candidate, scenario)
        return nil unless duration

        "[#{format_duration(duration)}]"
      end

      def score_visualization(score)
        filled = score.to_f.round
        empty = 10 - filled
        "[#{'█' * filled}#{'░' * empty}]"
      end

      def responses_section
        responses = @results.responses
        return nil if responses.empty?

        lines = []
        lines << '## Detailed Responses'
        lines << ''

        # Navigate the nested structure: candidate -> scenario -> variant -> temp
        responses.each do |candidate, scenarios|
          scenarios.each do |scenario, variants|
            variants.each do |variant, temps|
              temps.each do |temp, data|
                # Build section header
                header_parts = ["#{candidate} / #{scenario}"]
                header_parts << "[#{variant}]" if variant && variant != 'default'
                header_parts << "@temp=#{temp}" if temp
                lines << "### #{header_parts.join(' ')}"
                lines << ''

                # Show variant info if present
                if data[:variant_data]
                  vd = data[:variant_data]
                  lines << "**Credential:** #{vd[:credential]}" if vd[:credential] && !vd[:credential].to_s.empty?
                  lines << "**Stance:** #{vd[:stance]}" if vd[:stance] && vd[:stance] != :neutral
                  if vd[:full_prompt] && !vd[:full_prompt].to_s.empty?
                    lines << ''
                    lines << '**Prompt:**'
                    lines << '```'
                    lines << vd[:full_prompt].to_s.strip
                    lines << '```'
                  end
                  lines << ''
                end

                # Show timing if available
                timing_key = "#{scenario}/#{variant}"
                duration = @results.timing.dig(candidate, timing_key)
                if duration
                  lines << "**Time:** #{format_duration(duration)}"
                  lines << ''
                end

                # Show response
                content = data[:content] || data
                content_str = content.to_s.strip
                lines << '**Response:**'
                lines << '```'
                if content_str.length > 1000
                  lines << content_str[0..1000]
                  lines << "... [truncated, #{content_str.length} chars total]"
                else
                  lines << content_str
                end
                lines << '```'
                lines << ''
                lines << '-' * 40
                lines << ''
              end
            end
          end
        end

        lines.join("\n")
      end

      def winner_announcement
        scores = @results.scores_by_candidate
        return '' if scores.empty?

        wins = count_wins
        sorted = scores.sort_by { |_, v| -v[:avg_score] }
        winner = sorted.first
        runner_up = sorted[1]

        lines = []
        lines << '-' * 60

        if sorted.size == 1
          lines << "Result: #{winner[0]} scored #{winner[1][:avg_score]}/10"
        elsif winner[1][:avg_score] == runner_up&.dig(1, :avg_score)
          tied = sorted.take_while { |_, v| v[:avg_score] == winner[1][:avg_score] }
          lines << "Result: TIE between #{tied.map(&:first).join(', ')}"
          lines << "        All scored #{winner[1][:avg_score]}/10 average"
        else
          margin = (winner[1][:avg_score] - runner_up[1][:avg_score]).round(2)
          win_count = wins[winner[0]] || 0
          lines << "Winner: #{winner[0]}"
          avg_score = winner[1][:avg_score]
          pass_rate = winner[1][:pass_rate]
          lines << "        #{avg_score}/10 avg | #{win_count} scenario wins | #{pass_rate}% pass rate"
          lines << "        Beat #{runner_up[0]} by #{margin} points"
        end

        timing = @results.timing_by_candidate
        if timing.size > 1
          fastest = timing.min_by { |_, v| v[:avg_ms] }
          slowest = timing.max_by { |_, v| v[:avg_ms] }
          if fastest[0] != slowest[0]
            speedup = (slowest[1][:avg_ms].to_f / fastest[1][:avg_ms]).round(1)
            lines << ''
            lines << "Fastest: #{fastest[0]} (#{format_duration(fastest[1][:avg_ms])} avg)"
            lines << "         #{speedup}x faster than #{slowest[0]}"
          end
        end

        lines.join("\n")
      end
    end
  end
end
