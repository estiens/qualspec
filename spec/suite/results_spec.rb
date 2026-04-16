# frozen_string_literal: true

require 'qualspec'

RSpec.describe Qualspec::Suite::Results do
  before { Qualspec.reset! }

  def build_results(suite_name = 'Test Suite')
    Qualspec::Suite::Results.new(suite_name)
  end

  describe '#candidate_models' do
    it 'starts as an empty hash' do
      results = build_results
      expect(results.candidate_models).to eq({})
    end

    it 'allows storing candidate model strings by name' do
      results = build_results
      results.candidate_models['claude'] = 'anthropic/claude-3.5-sonnet'
      results.candidate_models['gpt4'] = 'openai/gpt-4o'
      expect(results.candidate_models['claude']).to eq('anthropic/claude-3.5-sonnet')
      expect(results.candidate_models['gpt4']).to eq('openai/gpt-4o')
    end
  end

  describe '#prompts' do
    it 'starts as an empty hash' do
      results = build_results
      expect(results.prompts).to eq({})
    end

    it 'allows storing prompt text keyed by scenario name' do
      results = build_results
      results.prompts['Scenario A'] = 'What is the capital of France?'
      expect(results.prompts['Scenario A']).to eq('What is the capital of France?')
    end
  end

  describe '#scores_by_scenario' do
    it 'returns aggregated average score across multiple variants/temperatures' do
      results = build_results

      # Record three evaluations for the same scenario + candidate, varying variant/temperature
      [
        { variant: 'default', temperature: 0.0, score: 6 },
        { variant: 'default', temperature: 0.7, score: 8 },
        { variant: 'expert',  temperature: 0.0, score: 10 }
      ].each do |row|
        results.record_evaluation(
          candidate: 'claude',
          scenario: 'Question 1',
          criteria: ['is helpful'],
          variant: row[:variant],
          temperature: row[:temperature],
          evaluation: Qualspec::Evaluation.new(
            criterion: 'is helpful',
            score: row[:score],
            pass: row[:score] >= 7
          )
        )
      end

      by_scenario = results.scores_by_scenario
      expect(by_scenario.keys).to eq(['Question 1'])

      claude_stats = by_scenario['Question 1']['claude']
      # Average of 6, 8, 10 = 8.0
      expect(claude_stats[:score]).to eq(8.0)
    end

    it 'does NOT take only the first evaluation (regression guard)' do
      results = build_results

      results.record_evaluation(
        candidate: 'model-a',
        scenario: 'Scenario',
        criteria: ['criterion'],
        variant: 'v1',
        temperature: 0.0,
        evaluation: Qualspec::Evaluation.new(criterion: 'criterion', score: 2, pass: false)
      )
      results.record_evaluation(
        candidate: 'model-a',
        scenario: 'Scenario',
        criteria: ['criterion'],
        variant: 'v2',
        temperature: 0.0,
        evaluation: Qualspec::Evaluation.new(criterion: 'criterion', score: 10, pass: true)
      )

      by_scenario = results.scores_by_scenario
      # If .first were used we'd get 2.0; the average should be 6.0
      expect(by_scenario['Scenario']['model-a'][:score]).to eq(6.0)
    end

    it 'marks pass true only when all evaluations pass' do
      results = build_results

      results.record_evaluation(
        candidate: 'model-a',
        scenario: 'Scenario',
        criteria: ['criterion'],
        variant: 'v1',
        temperature: nil,
        evaluation: Qualspec::Evaluation.new(criterion: 'criterion', score: 8, pass: true)
      )
      results.record_evaluation(
        candidate: 'model-a',
        scenario: 'Scenario',
        criteria: ['criterion'],
        variant: 'v2',
        temperature: nil,
        evaluation: Qualspec::Evaluation.new(criterion: 'criterion', score: 5, pass: false)
      )

      stats = results.scores_by_scenario['Scenario']['model-a']
      expect(stats[:pass]).to eq(false)
    end

    it 'separates multiple scenarios independently' do
      results = build_results

      [
        { scenario: 'S1', score: 9 },
        { scenario: 'S2', score: 3 }
      ].each do |row|
        results.record_evaluation(
          candidate: 'model-a',
          scenario: row[:scenario],
          criteria: ['c'],
          variant: 'default',
          temperature: nil,
          evaluation: Qualspec::Evaluation.new(criterion: 'c', score: row[:score], pass: row[:score] >= 7)
        )
      end

      by_scenario = results.scores_by_scenario
      expect(by_scenario['S1']['model-a'][:score]).to eq(9.0)
      expect(by_scenario['S2']['model-a'][:score]).to eq(3.0)
    end
  end

  describe '#record_response' do
    it 'stores response content in the nested 4-level hash' do
      results = build_results
      results.record_response(
        candidate: 'claude',
        scenario: 'Q1',
        variant: 'default',
        temperature: 0.7,
        response: 'Hello from claude'
      )

      data = results.responses.dig('claude', 'Q1', 'default', 0.7)
      expect(data).not_to be_nil
      expect(data[:content]).to eq('Hello from claude')
    end

    it 'accumulates multiple candidates and variants without collision' do
      results = build_results

      results.record_response(candidate: 'a', scenario: 'Q1', variant: 'v1', temperature: nil, response: 'resp-a-v1')
      results.record_response(candidate: 'b', scenario: 'Q1', variant: 'v1', temperature: nil, response: 'resp-b-v1')
      results.record_response(candidate: 'a', scenario: 'Q1', variant: 'v2', temperature: nil, response: 'resp-a-v2')

      expect(results.responses.dig('a', 'Q1', 'v1', nil, :content)).to eq('resp-a-v1')
      expect(results.responses.dig('b', 'Q1', 'v1', nil, :content)).to eq('resp-b-v1')
      expect(results.responses.dig('a', 'Q1', 'v2', nil, :content)).to eq('resp-a-v2')
    end
  end
end
