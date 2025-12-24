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

    DEFAULT_PASS_THRESHOLD = 7

    def initialize(client: nil, model: nil, system_prompt: nil, pass_threshold: nil)
      @client = client || Qualspec.client
      @model = model || Qualspec.configuration.judge_model
      @system_prompt = system_prompt || Qualspec.configuration.judge_system_prompt || DEFAULT_SYSTEM_PROMPT
      @pass_threshold = pass_threshold || DEFAULT_PASS_THRESHOLD
    end

    def evaluate(response:, criterion:, context: nil, pass_threshold: nil)
      threshold = pass_threshold || @pass_threshold
      user_prompt = build_user_prompt(response, criterion, context)

      result = @client.chat(
        model: @model,
        messages: [
          { role: "system", content: @system_prompt },
          { role: "user", content: user_prompt }
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
      parts << "Score this response from 0-10. Respond with JSON only."
      parts.join("\n\n")
    end

    def parse_result(result, criterion, threshold)
      json = JSON.parse(result)
      score = json["score"].to_i.clamp(0, 10)

      Evaluation.new(
        criterion: criterion,
        score: score,
        pass: score >= threshold,
        reasoning: json["reasoning"]
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
  end
end
