# frozen_string_literal: true

require 'qualspec'

RSpec.describe Qualspec::Suite::Runner do
  before { Qualspec.reset! }

  # Minimal double for the Qualspec client
  def stub_client(response_text: 'A fine response')
    client = instance_double(Qualspec::Client)
    allow(client).to receive(:chat).and_return(response_text)
    client
  end

  # Minimal judge that always returns a passing evaluation
  def stub_judge(score: 8)
    judge = instance_double(Qualspec::Judge)
    evaluation = Qualspec::Evaluation.new(criterion: 'criterion', score: score, pass: score >= 7)
    allow(judge).to receive(:evaluate).and_return(evaluation)
    allow(judge).to receive(:evaluate_comparison).and_return(
      # comparison returns a hash keyed by candidate name
      Hash.new { evaluation }
    )
    judge
  end

  # Build a minimal Definition without running IO
  def build_definition(name: 'Runner Test Suite')
    Qualspec.evaluation(name) do
      candidates do
        candidate 'model-a', model: 'provider/model-a'
        candidate 'model-b', model: 'provider/model-b'
      end

      scenario 'Basic Scenario' do
        prompt 'Tell me a joke.'
        criterion 'is funny'
      end
    end

    Qualspec::Suite.find(name)
  end

  describe '#initialize' do
    it 'populates candidate_models on Results from the definition' do
      definition = build_definition
      client = stub_client
      judge = stub_judge

      allow(Qualspec).to receive(:client).and_return(client)
      allow(Qualspec).to receive(:judge).and_return(judge)

      runner = Qualspec::Suite::Runner.new(definition)

      expect(runner.results.candidate_models).to eq(
        'model-a' => 'provider/model-a',
        'model-b' => 'provider/model-b'
      )
    end

    it 'initializes an empty prompts hash on Results' do
      definition = build_definition
      allow(Qualspec).to receive(:client).and_return(stub_client)
      allow(Qualspec).to receive(:judge).and_return(stub_judge)

      runner = Qualspec::Suite::Runner.new(definition)
      expect(runner.results.prompts).to eq({})
    end
  end

  describe '#run' do
    let(:definition) { build_definition }
    let(:client) { stub_client }
    let(:judge) do
      j = instance_double(Qualspec::Judge)
      eval_a = Qualspec::Evaluation.new(criterion: 'is funny', score: 8, pass: true, scenario_winner: true)
      eval_b = Qualspec::Evaluation.new(criterion: 'is funny', score: 6, pass: false, scenario_winner: false)
      allow(j).to receive(:evaluate_comparison).and_return({ 'model-a' => eval_a, 'model-b' => eval_b })
      j
    end

    before do
      allow(Qualspec).to receive(:client).and_return(client)
      allow(Qualspec).to receive(:judge).and_return(judge)
    end

    it 'populates prompts during the run' do
      runner = Qualspec::Suite::Runner.new(definition)
      results = runner.run(progress: false)

      expect(results.prompts['Basic Scenario']).to eq('Tell me a joke.')
    end

    it 'returns Results with candidate_models still populated after run' do
      runner = Qualspec::Suite::Runner.new(definition)
      results = runner.run(progress: false)

      expect(results.candidate_models['model-a']).to eq('provider/model-a')
      expect(results.candidate_models['model-b']).to eq('provider/model-b')
    end

    it 'records responses in the nested 4-level structure' do
      runner = Qualspec::Suite::Runner.new(definition)
      results = runner.run(progress: false)

      # responses[candidate][scenario][variant][temperature]
      expect(results.responses.keys).to include('model-a', 'model-b')
      expect(results.responses['model-a'].keys).to include('Basic Scenario')
    end

    it 'evaluations reference the scenario by name' do
      runner = Qualspec::Suite::Runner.new(definition)
      results = runner.run(progress: false)

      scenarios_in_evals = results.evaluations.map { |e| e[:scenario] }.uniq
      expect(scenarios_in_evals).to include('Basic Scenario')
    end
  end

  describe 'scores_by_scenario aggregation via Runner' do
    it 'averages scores across temperatures when multiple temperatures are configured' do
      Qualspec.evaluation('Temp Test') do
        candidates do
          candidate 'model-a', model: 'provider/model-a'
        end

        temperatures [0.0, 1.0]

        scenario 'Q1' do
          prompt 'Test prompt'
          criterion 'is correct'
        end
      end

      definition = Qualspec::Suite.find('Temp Test')

      call_count = 0
      client = instance_double(Qualspec::Client)
      allow(client).to receive(:chat) { 'response' }

      judge = instance_double(Qualspec::Judge)
      scores = [4, 10]
      allow(judge).to receive(:evaluate) do
        score = scores[call_count % 2]
        call_count += 1
        Qualspec::Evaluation.new(criterion: 'is correct', score: score, pass: score >= 7)
      end

      allow(Qualspec).to receive(:client).and_return(client)
      allow(Qualspec).to receive(:judge).and_return(judge)

      runner = Qualspec::Suite::Runner.new(definition)
      results = runner.run(progress: false)

      # Average of 4 and 10 = 7.0
      avg = results.scores_by_scenario['Q1']['model-a'][:score]
      expect(avg).to eq(7.0)
    end
  end
end
