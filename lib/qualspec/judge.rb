# frozen_string_literal: true

module Qualspec
  class Judge
    DEFAULT_SYSTEM_PROMPT = <<~PROMPT
      You are an evaluation judge. You will be given a response and one or more evaluation criteria.
      Your job is to score how well the response meets the criteria.

      Scoring:
      - 0: Completely fails to meet the criteria
      - 1-3: Mostly fails, with minor positive elements
      - 4-6: Partially meets criteria, significant room for improvement
      - 7-8: Mostly meets criteria with minor issues
      - 9: Meets criteria well
      - 10: Perfectly meets all criteria

      Be strict but fair. Consider each criterion carefully.

      You MUST respond with valid JSON in this exact format:
      {"score": <0-10>, "reasoning": "Brief explanation of the score"}

      Your reasoning should be concise (1-2 sentences max).
    PROMPT

    COMPARISON_SYSTEM_PROMPT = <<~PROMPT
      You are an evaluation judge comparing multiple AI responses to the same prompt.
      Score each response on how well it meets the criteria.

      Scoring (0-10):
      - 0: Completely fails
      - 1-3: Mostly fails
      - 4-6: Partially meets criteria
      - 7-8: Mostly meets criteria
      - 9-10: Excellent

      Be strict but fair. Compare responses relative to each other.

      IMPORTANT: Use the EXACT candidate names as given in the prompt.

      You MUST respond with valid JSON with scores for each candidate AND declare a winner.
      Example format (use actual names from prompt, not these placeholders):
      {
        "actual-name-1": {"score": 8, "reasoning": "..."},
        "actual-name-2": {"score": 6, "reasoning": "..."},
        "winner": "actual-name-1"
      }

      Use "winner": "tie" if scores are equal or too close to call.
    PROMPT

    DEFAULT_PASS_THRESHOLD = 7

    def initialize(client: nil, model: nil, system_prompt: nil, pass_threshold: nil)
      @client = client || Qualspec.client
      @model = model || Qualspec.configuration.judge_model
      @system_prompt = system_prompt || Qualspec.configuration.judge_system_prompt || DEFAULT_SYSTEM_PROMPT
      @pass_threshold = pass_threshold || DEFAULT_PASS_THRESHOLD
    end

    # Evaluate a single response
    def evaluate(response:, criterion:, context: nil, pass_threshold: nil)
      threshold = pass_threshold || @pass_threshold
      user_prompt = build_user_prompt(response, criterion, context)

      result = @client.chat(
        model: @model,
        messages: [
          { role: 'system', content: @system_prompt },
          { role: 'user', content: user_prompt }
        ],
        json_mode: true
      )

      parse_result(result, criterion, threshold)
    rescue Client::RequestError => e
      Evaluation.new(
        criterion: criterion,
        score: 0,
        pass: false,
        reasoning: nil,
        error: e.message
      )
    end

    # Evaluate multiple candidate responses together (comparative judging)
    def evaluate_comparison(responses:, criteria:, context: nil, pass_threshold: nil)
      threshold = pass_threshold || @pass_threshold

      criteria_text = Array(criteria).map.with_index { |c, i| "#{i + 1}. #{c}" }.join("\n")

      user_prompt = build_comparison_prompt(responses, criteria_text, context)

      result = @client.chat(
        model: @model,
        messages: [
          { role: 'system', content: COMPARISON_SYSTEM_PROMPT },
          { role: 'user', content: user_prompt }
        ],
        json_mode: true
      )

      parse_comparison_result(result, criteria_text, threshold, responses.keys)
    rescue Client::RequestError => e
      # Return error evaluations for all candidates
      responses.keys.to_h do |candidate|
        [candidate, Evaluation.new(
          criterion: criteria_text,
          score: 0,
          pass: false,
          reasoning: nil,
          error: e.message
        )]
      end
    end

    def evaluate_rubric(response:, rubric:, context: nil, pass_threshold: nil)
      rubric_obj = rubric.is_a?(Symbol) ? Rubric.find(rubric) : rubric
      criteria_text = rubric_obj.criteria.map.with_index { |c, i| "#{i + 1}. #{c}" }.join("\n")

      evaluate(response: response, criterion: criteria_text, context: context, pass_threshold: pass_threshold)
    end

    private

    def build_user_prompt(response, criterion, context)
      parts = []
      parts << "## Response to evaluate:\n#{response}"
      parts << "## Additional context:\n#{context}" if context
      parts << "## Evaluation criteria:\n#{criterion}"
      parts << 'Score this response from 0-10. Respond with JSON only.'
      parts.join("\n\n")
    end

    def build_comparison_prompt(responses, criteria, context)
      candidate_names = responses.keys.map { |k| "\"#{k}\"" }.join(', ')

      parts = []
      parts << "## Evaluation criteria:\n#{criteria}"
      parts << "## Context:\n#{context}" if context
      parts << "## Candidates to evaluate: #{candidate_names}"
      parts << '## Responses:'

      responses.each do |candidate, response|
        parts << "\n### #{candidate}:\n#{response}"
      end

      parts << "\nScore each candidate (#{candidate_names}) from 0-10."
      parts << 'Use these EXACT names in your JSON response. Declare a winner.'
      parts.join("\n")
    end

    def parse_result(result, criterion, threshold)
      json = JSON.parse(result)
      score = json['score'].to_i.clamp(0, 10)

      Evaluation.new(
        criterion: criterion,
        score: score,
        pass: score >= threshold,
        reasoning: json['reasoning']
      )
    rescue JSON::ParserError
      Evaluation.new(
        criterion: criterion,
        score: 0,
        pass: false,
        reasoning: nil,
        error: "Judge returned invalid JSON: #{result[0..200]}"
      )
    end

    def parse_comparison_result(result, criterion, threshold, candidates)
      json = JSON.parse(result)
      winner = json['winner']

      evals = candidates.to_h do |candidate|
        candidate_result = json[candidate] || json[candidate.to_s]

        if candidate_result
          score = candidate_result['score'].to_i.clamp(0, 10)
          is_winner = winner == candidate || winner == candidate.to_s

          [candidate, Evaluation.new(
            criterion: criterion,
            score: score,
            pass: score >= threshold,
            reasoning: candidate_result['reasoning'],
            scenario_winner: is_winner
          )]
        else
          [candidate, Evaluation.new(
            criterion: criterion,
            score: 0,
            pass: false,
            reasoning: nil,
            error: 'No result for candidate in judge response'
          )]
        end
      end

      # Store tie info
      evals.each_value { |e| e.scenario_winner = :tie } if winner == 'tie'

      evals
    rescue JSON::ParserError
      candidates.to_h do |candidate|
        [candidate, Evaluation.new(
          criterion: criterion,
          score: 0,
          pass: false,
          reasoning: nil,
          error: "Judge returned invalid JSON: #{result[0..200]}"
        )]
      end
    end
  end
end
