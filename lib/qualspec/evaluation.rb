# frozen_string_literal: true

module Qualspec
  class Evaluation
    attr_reader :criterion, :score, :pass, :reasoning
    attr_reader :model, :candidate, :scenario
    attr_reader :error

    def initialize(criterion:, score:, pass:, reasoning: nil, model: nil, candidate: nil, scenario: nil, error: nil)
      @criterion = criterion
      @score = score
      @pass = pass
      @reasoning = reasoning
      @model = model
      @candidate = candidate
      @scenario = scenario
      @error = error
    end

    def pass?
      @pass == true
    end

    def fail?
      !pass?
    end

    def error?
      !@error.nil?
    end

    # Score as percentage (0-100)
    def score_pct
      (@score.to_f / 10 * 100).round
    end

    def to_h
      {
        criterion: @criterion,
        score: @score,
        pass: @pass,
        reasoning: @reasoning,
        model: @model,
        candidate: @candidate,
        scenario: @scenario,
        error: @error
      }.compact
    end
  end
end
