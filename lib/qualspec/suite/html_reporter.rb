# frozen_string_literal: true

require 'cgi'

module Qualspec
  module Suite
    class HtmlReporter
      def initialize(results)
        @results = results
      end

      def to_html
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{h(@results.suite_name)} - Qualspec Report</title>
            #{styles}
          </head>
          <body>
            <div class="container">
              #{header_section}
              #{config_section}
              #{summary_section}
              #{performance_section}
              #{detailed_results_section}
              #{responses_section}
              #{winner_section}
              #{footer_section}
            </div>
          </body>
          </html>
        HTML
      end

      def write(path)
        File.write(path, to_html)
      end

      private

      def h(text)
        CGI.escapeHTML(text.to_s)
      end

      def styles
        <<~CSS
          <style>
            :root {
              --bg: #0d1117;
              --card-bg: #161b22;
              --border: #30363d;
              --text: #c9d1d9;
              --text-muted: #8b949e;
              --accent: #58a6ff;
              --success: #3fb950;
              --warning: #d29922;
              --danger: #f85149;
              --purple: #a371f7;
            }

            * { box-sizing: border-box; margin: 0; padding: 0; }

            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
              background: var(--bg);
              color: var(--text);
              line-height: 1.6;
              padding: 2rem;
            }

            .container { max-width: 1400px; margin: 0 auto; }

            header {
              text-align: center;
              margin-bottom: 2rem;
              padding-bottom: 1.5rem;
              border-bottom: 1px solid var(--border);
            }

            header h1 { font-size: 2.5rem; font-weight: 600; margin-bottom: 0.5rem; }
            header .subtitle { color: var(--text-muted); font-size: 0.9rem; }

            .card {
              background: var(--card-bg);
              border: 1px solid var(--border);
              border-radius: 6px;
              padding: 1.5rem;
              margin-bottom: 1.5rem;
            }

            .card h2 {
              font-size: 1.25rem;
              font-weight: 600;
              margin-bottom: 1rem;
              display: flex;
              align-items: center;
              gap: 0.5rem;
            }

            .card h2 .icon { font-size: 1.1rem; }

            .config-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
              gap: 1rem;
            }

            .config-item { padding: 0.75rem; background: var(--bg); border-radius: 4px; }
            .config-item .label {
              color: var(--text-muted);
              font-size: 0.75rem;
              text-transform: uppercase;
              letter-spacing: 0.05em;
            }
            .config-item .value { font-weight: 500; margin-top: 0.25rem; word-break: break-all; }

            table { width: 100%; border-collapse: collapse; }
            th, td { text-align: left; padding: 0.75rem 1rem; border-bottom: 1px solid var(--border); }
            th {
              color: var(--text-muted);
              font-weight: 500;
              font-size: 0.85rem;
              text-transform: uppercase;
              letter-spacing: 0.05em;
            }
            tr:last-child td { border-bottom: none; }

            .score-bar { display: flex; align-items: center; gap: 0.75rem; }
            .score-bar .bar {
              flex: 1;
              height: 8px;
              background: var(--border);
              border-radius: 4px;
              overflow: hidden;
              max-width: 150px;
            }
            .score-bar .bar .fill { height: 100%; border-radius: 4px; }
            .score-bar .value { font-weight: 600; min-width: 3.5rem; }

            .badge {
              display: inline-block;
              padding: 0.25rem 0.5rem;
              border-radius: 4px;
              font-size: 0.75rem;
              font-weight: 600;
            }
            .badge-success { background: rgba(63, 185, 80, 0.2); color: var(--success); }
            .badge-warning { background: rgba(210, 153, 34, 0.2); color: var(--warning); }
            .badge-danger { background: rgba(248, 81, 73, 0.2); color: var(--danger); }
            .badge-winner { background: rgba(163, 113, 247, 0.2); color: var(--purple); }
            .badge-info { background: rgba(88, 166, 255, 0.2); color: var(--accent); }

            .scenario-card {
              margin-bottom: 1.5rem;
              padding: 1.25rem;
              background: var(--bg);
              border-radius: 6px;
              border: 1px solid var(--border);
            }
            .scenario-card:last-child { margin-bottom: 0; }
            .scenario-header {
              display: flex;
              justify-content: space-between;
              align-items: center;
              margin-bottom: 1rem;
              padding-bottom: 0.75rem;
              border-bottom: 1px solid var(--border);
            }
            .scenario-header h3 { font-size: 1.1rem; font-weight: 600; }
            .scenario-prompt {
              background: var(--card-bg);
              padding: 1rem;
              border-radius: 4px;
              margin-bottom: 1rem;
              border-left: 3px solid var(--accent);
            }
            .scenario-prompt .label {
              color: var(--text-muted);
              font-size: 0.75rem;
              text-transform: uppercase;
              margin-bottom: 0.5rem;
            }

            .eval-grid { display: grid; gap: 1rem; }
            .eval-card {
              background: var(--card-bg);
              border-radius: 6px;
              padding: 1rem;
              border: 1px solid var(--border);
            }
            .eval-card.winner { border-color: var(--purple); box-shadow: 0 0 0 1px var(--purple); }
            .eval-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; }
            .eval-header .candidate { font-weight: 600; font-size: 1rem; }
            .eval-criteria { margin-top: 0.75rem; padding-top: 0.75rem; border-top: 1px solid var(--border); }
            .eval-criteria .criterion { padding: 0.5rem 0; border-bottom: 1px solid var(--border); }
            .eval-criteria .criterion:last-child { border-bottom: none; }
            .eval-criteria .criterion-text { color: var(--text-muted); font-size: 0.85rem; margin-bottom: 0.25rem; }
            .eval-criteria .reasoning { font-size: 0.9rem; color: var(--text); font-style: italic; }
            .eval-timing { color: var(--text-muted); font-size: 0.8rem; margin-top: 0.5rem; }

            .response-card { margin-bottom: 1rem; }
            .response-card h4 {
              font-size: 0.9rem;
              color: var(--accent);
              margin-bottom: 0.5rem;
              display: flex;
              align-items: center;
              gap: 0.5rem;
            }
            .response-card pre {
              background: var(--bg);
              border: 1px solid var(--border);
              border-radius: 4px;
              padding: 1rem;
              overflow-x: auto;
              font-size: 0.85rem;
              white-space: pre-wrap;
              word-wrap: break-word;
              max-height: 400px;
              overflow-y: auto;
            }

            .winner-box { text-align: center; padding: 2.5rem; }
            .winner-box .crown { font-size: 4rem; margin-bottom: 1rem; }
            .winner-box h2 { font-size: 2rem; margin-bottom: 0.75rem; justify-content: center; }
            .winner-box .stats { color: var(--text-muted); font-size: 1rem; }
            .winner-box .comparison {
              margin-top: 1.5rem;
              padding-top: 1.5rem;
              border-top: 1px solid var(--border);
              font-size: 0.9rem;
              color: var(--text-muted);
            }

            .perf-row {
              display: flex;
              justify-content: space-between;
              align-items: center;
              padding: 0.75rem 0;
              border-bottom: 1px solid var(--border);
            }
            .perf-row:last-child { border-bottom: none; }
            .perf-row .name { font-weight: 500; }
            .perf-row .metrics { display: flex; gap: 2rem; color: var(--text-muted); font-size: 0.9rem; }
            .perf-row .metrics span { display: flex; align-items: center; gap: 0.5rem; }

            .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
            @media (max-width: 900px) { .two-col { grid-template-columns: 1fr; } }

            footer {
              text-align: center;
              padding-top: 1.5rem;
              margin-top: 1rem;
              border-top: 1px solid var(--border);
              color: var(--text-muted);
              font-size: 0.8rem;
            }
            footer a { color: var(--accent); text-decoration: none; }
            footer a:hover { text-decoration: underline; }

            .collapsible { cursor: pointer; user-select: none; }
            .collapsible:hover { opacity: 0.8; }
            .collapsible::after { content: " ▼"; font-size: 0.7rem; }
            .collapsed::after { content: " ▶"; }
          </style>
        CSS
      end

      def header_section
        <<~HTML
          <header>
            <h1>#{h(@results.suite_name)}</h1>
            <p class="subtitle">Generated #{Time.now.strftime('%B %d, %Y at %H:%M:%S')}</p>
          </header>
        HTML
      end

      def config_section
        config = Qualspec.configuration
        candidates = @results.scores_by_candidate.keys

        <<~HTML
          <div class="card">
            <h2><span class="icon">⚙️</span> Configuration</h2>
            <div class="config-grid">
              <div class="config-item">
                <div class="label">Judge Model</div>
                <div class="value">#{h(config.judge_model)}</div>
              </div>
              <div class="config-item">
                <div class="label">API Endpoint</div>
                <div class="value">#{h(config.api_url)}</div>
              </div>
              <div class="config-item">
                <div class="label">Candidates</div>
                <div class="value">#{candidates.size} models</div>
              </div>
              <div class="config-item">
                <div class="label">Scenarios</div>
                <div class="value">#{@results.scores_by_scenario.size} total</div>
              </div>
            </div>
          </div>
        HTML
      end

      def summary_section
        scores = @results.scores_by_candidate
        return '' if scores.empty?

        wins = count_wins
        sorted = scores.sort_by { |_, v| -v[:avg_score] }
        top_score = sorted.first[1][:avg_score]

        rows = sorted.map do |candidate, stats|
          # Use round(2) comparison to avoid float precision issues
          is_winner = stats[:avg_score].round(2) == top_score.round(2) &&
                      sorted.count { |_, v| v[:avg_score].round(2) == top_score.round(2) } == 1
          winner_badge = is_winner ? '<span class="badge badge-winner">WINNER</span>' : ''
          model = get_candidate_model(candidate)

          <<~ROW
            <tr>
              <td>
                <strong>#{h(candidate)}</strong> #{winner_badge}<br>
                <span style="color: var(--text-muted); font-size: 0.8rem;">#{h(model)}</span>
              </td>
              <td>#{score_bar(stats[:avg_score])}</td>
              <td style="text-align: center;">#{wins[candidate] || 0}</td>
              <td>#{pass_rate_badge(stats[:pass_rate])}</td>
            </tr>
          ROW
        end.join

        <<~HTML
          <div class="card">
            <h2><span class="icon">📊</span> Summary</h2>
            <table>
              <thead>
                <tr>
                  <th>Candidate</th>
                  <th>Average Score</th>
                  <th style="text-align: center;">Scenario Wins</th>
                  <th>Pass Rate</th>
                </tr>
              </thead>
              <tbody>
                #{rows}
              </tbody>
            </table>
          </div>
        HTML
      end

      def performance_section
        timing = @results.timing_by_candidate
        return '' if timing.empty?

        costs = @results.costs
        sorted = timing.sort_by { |_, v| v[:avg_ms] }
        fastest = sorted.first

        rows = sorted.map do |candidate, stats|
          cost_str = costs[candidate]&.positive? ? "$#{format_cost(costs[candidate])}" : '-'
          speedup = (stats[:avg_ms].to_f / fastest[1][:avg_ms]).round(1)
          speedup_badge = if (speedup - 1.0).abs < 0.01
                            '<span class="badge badge-success">Fastest</span>'
                          else
                            "<span class=\"badge badge-info\">#{speedup}x slower</span>"
                          end

          <<~ROW
            <div class="perf-row">
              <span class="name">#{h(candidate)} #{speedup_badge}</span>
              <div class="metrics">
                <span>⏱️ #{format_duration(stats[:avg_ms])} avg</span>
                <span>📊 #{format_duration(stats[:total_ms])} total</span>
                <span>💰 #{cost_str}</span>
              </div>
            </div>
          ROW
        end.join

        <<~HTML
          <div class="card">
            <h2><span class="icon">⚡</span> Performance</h2>
            #{rows}
          </div>
        HTML
      end

      def detailed_results_section
        by_scenario = @results.scores_by_scenario
        return '' if by_scenario.empty?

        candidates = @results.scores_by_candidate.keys
        evaluations = @results.evaluations

        scenarios = by_scenario.map do |scenario, candidate_scores|
          winner = find_scenario_winner(scenario)
          winner_label = case winner
                         when :tie then '<span class="badge badge-warning">TIE</span>'
                         when nil then ''
                         else '<span class="badge badge-winner">WINNER</span>'
                         end

          # Get the prompt for this scenario
          prompt = get_scenario_prompt(scenario)

          # Get evaluations for this scenario
          scenario_evals = evaluations.select { |e| e[:scenario] == scenario }

          eval_cards = candidates.map do |candidate|
            stats = candidate_scores[candidate]
            next unless stats

            is_winner = winner == candidate
            timing_info = format_scenario_timing(candidate, scenario)
            candidate_evals = scenario_evals.select { |e| e[:candidate] == candidate }

            criteria_html = candidate_evals.map do |eval|
              <<~CRITERION
                <div class="criterion">
                  <div class="criterion-text">#{h(eval[:criterion])}</div>
                  <div style="display: flex; align-items: center; gap: 0.5rem; margin-top: 0.25rem;">
                    #{score_bar(eval[:score])}
                    #{eval[:pass] ? '<span class="badge badge-success">PASS</span>' :
                                    '<span class="badge badge-danger">FAIL</span>'}
                  </div>
                  #{eval[:reasoning] ? "<div class=\"reasoning\">\"#{h(eval[:reasoning])}\"</div>" : ''}
                </div>
              CRITERION
            end.join

            <<~CARD
              <div class="eval-card#{is_winner ? ' winner' : ''}">
                <div class="eval-header">
                  <span class="candidate">#{h(candidate)} #{is_winner ? '⭐' : ''}</span>
                  #{score_bar(stats[:score])}
                </div>
                <div class="eval-criteria">
                  #{criteria_html}
                </div>
                #{timing_info ? "<div class=\"eval-timing\">Response time: #{timing_info}</div>" : ''}
              </div>
            CARD
          end.compact.join

          <<~SCENARIO
            <div class="scenario-card">
              <div class="scenario-header">
                <h3>#{h(scenario)} #{winner_label}</h3>
              </div>
              #{prompt ? "<div class=\"scenario-prompt\"><div class=\"label\">Prompt</div>#{h(prompt)}</div>" : ''}
              <div class="eval-grid">
                #{eval_cards}
              </div>
            </div>
          SCENARIO
        end.join

        <<~HTML
          <div class="card">
            <h2><span class="icon">🎯</span> Detailed Results by Scenario</h2>
            #{scenarios}
          </div>
        HTML
      end

      def responses_section
        responses = @results.responses
        return '' if responses.empty?

        scenarios = responses.values.first&.keys || []

        scenario_blocks = scenarios.map do |scenario|
          response_cards = responses.map do |candidate, candidate_responses|
            response = candidate_responses[scenario]
            next unless response

            response_text = response.to_s.strip

            <<~CARD
              <div class="response-card">
                <h4>#{h(candidate)}</h4>
                <pre>#{h(response_text)}</pre>
              </div>
            CARD
          end.compact

          # Use two columns if we have exactly 2 responses
          grid_class = response_cards.size == 2 ? 'two-col' : ''

          <<~SCENARIO
            <div class="scenario-card">
              <div class="scenario-header">
                <h3>#{h(scenario)}</h3>
              </div>
              <div class="#{grid_class}">
                #{response_cards.join}
              </div>
            </div>
          SCENARIO
        end.join

        <<~HTML
          <div class="card">
            <h2><span class="icon">💬</span> Full Responses</h2>
            #{scenario_blocks}
          </div>
        HTML
      end

      def winner_section
        scores = @results.scores_by_candidate
        return '' if scores.empty?

        wins = count_wins
        sorted = scores.sort_by { |_, v| -v[:avg_score] }
        winner = sorted.first
        runner_up = sorted[1]

        if sorted.size == 1
          content = <<~HTML
            <div class="crown">🏆</div>
            <h2>#{h(winner[0])}</h2>
            <p class="stats">#{winner[1][:avg_score]}/10 average score</p>
          HTML
        elsif winner[1][:avg_score] == runner_up&.dig(1, :avg_score)
          tied = sorted.take_while { |_, v| v[:avg_score] == winner[1][:avg_score] }
          content = <<~HTML
            <div class="crown">🤝</div>
            <h2>It's a Tie!</h2>
            <p class="stats">#{tied.map(&:first).join(' vs ')} tied at #{winner[1][:avg_score]}/10</p>
          HTML
        else
          margin = (winner[1][:avg_score] - runner_up[1][:avg_score]).round(2)
          win_count = wins[winner[0]] || 0
          content = <<~HTML
            <div class="crown">👑</div>
            <h2>#{h(winner[0])} Wins!</h2>
            <p class="stats">
              #{winner[1][:avg_score]}/10 avg &nbsp;•&nbsp;
              #{win_count} scenario wins &nbsp;•&nbsp;
              #{winner[1][:pass_rate]}% pass rate
            </p>
            <p class="comparison">Beat #{h(runner_up[0])} by #{margin} points</p>
          HTML
        end

        timing = @results.timing_by_candidate
        speed_note = ''
        if timing.size > 1
          fastest = timing.min_by { |_, v| v[:avg_ms] }
          slowest = timing.max_by { |_, v| v[:avg_ms] }
          if fastest[0] != slowest[0]
            speedup = (slowest[1][:avg_ms].to_f / fastest[1][:avg_ms]).round(1)
            speed_note = <<~HTML
              <p class="comparison">
                ⚡ #{h(fastest[0])} was #{speedup}x faster than #{h(slowest[0])}
              </p>
            HTML
          end
        end

        <<~HTML
          <div class="card winner-box">
            #{content}
            #{speed_note}
          </div>
        HTML
      end

      def footer_section
        <<~HTML
          <footer>
            Generated by <a href="https://github.com/estiens/qualspec">Qualspec</a> v#{Qualspec::VERSION}
          </footer>
        HTML
      end

      def score_bar(score)
        percentage = (score.to_f / 10 * 100).round
        color = if score >= 8
                  'var(--success)'
                elsif score >= 6
                  'var(--warning)'
                else
                  'var(--danger)'
                end

        <<~HTML
          <div class="score-bar">
            <div class="bar">
              <div class="fill" style="width: #{percentage}%; background: #{color};"></div>
            </div>
            <span class="value">#{score}/10</span>
          </div>
        HTML
      end

      def pass_rate_badge(rate)
        badge_class = if rate >= 80
                        'badge-success'
                      elsif rate >= 50
                        'badge-warning'
                      else
                        'badge-danger'
                      end

        %(<span class="badge #{badge_class}">#{rate}%</span>)
      end

      def count_wins
        wins = Hash.new(0)
        @results.evaluations.each do |eval|
          wins[eval[:candidate]] += 1 if eval[:winner] == true
        end
        wins
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

        format_duration(duration)
      end

      def format_duration(milliseconds)
        if milliseconds >= 1000
          "#{(milliseconds / 1000.0).round(2)}s"
        else
          "#{milliseconds.round}ms"
        end
      end

      def format_cost(cost)
        if cost < 0.01
          format('%.4f', cost)
        else
          format('%.2f', cost)
        end
      end

      def get_candidate_model(candidate)
        # Try to find the model from the suite
        @results.evaluations.find { |e| e[:candidate] == candidate }&.dig(:model) || 'unknown'
      end

      def get_scenario_prompt(_scenario)
        # This would need to be stored in results - for now return nil
        nil
      end
    end
  end
end
