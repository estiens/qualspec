# frozen_string_literal: true

require 'qualspec'

RSpec.describe 'cost tracking' do
  before { Qualspec.reset! }

  def fake_faraday_response(body:, headers: {}, status: 200)
    instance_double(Faraday::Response, success?: status < 400, status: status, body: body, headers: headers)
  end

  describe Qualspec::Client do
    let(:conn) { instance_double(Faraday::Connection) }
    let(:client) do
      Qualspec.configure { |c| c.api_key = 'sk-test' }
      c = described_class.new
      c.instance_variable_set(:@conn, conn)
      c
    end

    let(:body_with_usage) do
      {
        'choices' => [{ 'message' => { 'content' => 'hello' } }],
        'model' => 'google/gemini-3-flash-preview',
        'usage' => { 'prompt_tokens' => 2, 'completion_tokens' => 10, 'total_tokens' => 12, 'cost' => 0.000031 }
      }
    end

    it 'does NOT request usage accounting when with_metadata is false' do
      captured = nil
      allow(conn).to receive(:post) do |_path, payload|
        captured = payload
        fake_faraday_response(body: body_with_usage)
      end

      client.chat(model: 'm', messages: [{ role: 'user', content: 'hi' }], with_metadata: false)
      expect(captured).not_to have_key(:usage)
    end

    it 'requests usage accounting and returns a Response with cost when with_metadata is true' do
      captured = nil
      allow(conn).to receive(:post) do |_path, payload|
        captured = payload
        fake_faraday_response(body: body_with_usage)
      end

      result = client.chat(model: 'm', messages: [{ role: 'user', content: 'hi' }], with_metadata: true)

      expect(captured[:usage]).to eq(include: true)
      expect(result).to be_a(Qualspec::Client::Response)
      expect(result.content).to eq('hello')
      expect(result.cost).to eq(0.000031)
      expect(result.tokens).to eq(prompt: 2, completion: 10, total: 12)
    end

    it 'reads cost from usage.cost (not the legacy total_cost field)' do
      allow(conn).to receive(:post).and_return(fake_faraday_response(body: body_with_usage))
      result = client.chat(model: 'm', messages: [{ role: 'user', content: 'hi' }], with_metadata: true)
      expect(result.cost).to eq(0.000031)
    end
  end

  describe Qualspec::Suite::Definition do
    it 'defaults track_cost? to false' do
      defn = described_class.new('S')
      expect(defn.track_cost?).to be(false)
    end

    it 'enables it via the track_cost DSL method' do
      defn = described_class.new('S') { track_cost }
      expect(defn.track_cost?).to be(true)
    end

    it 'aliases capture_metadata' do
      defn = described_class.new('S') { capture_metadata }
      expect(defn.track_cost?).to be(true)
    end
  end

  describe Qualspec::Suite::Results do
    it 'raises a helpful error for value_ranking when cost was not tracked' do
      results = described_class.new('S')
      expect { results.value_ranking }.to raise_error(Qualspec::Error, /track_cost/)
    end

    it 'raises for cost_by_candidate when cost was not tracked' do
      results = described_class.new('S')
      expect { results.cost_by_candidate }.to raise_error(Qualspec::Error, /track_cost/)
    end

    it 'ranks candidates by score-per-dollar when cost was tracked' do
      results = described_class.new('S')
      results.metadata_captured = true
      results.record_response(candidate: 'cheap', scenario: 'x', response: 'a', cost: 0.001)
      results.record_response(candidate: 'pricey', scenario: 'x', response: 'b', cost: 0.01)
      results.record_evaluation(candidate: 'cheap', scenario: 'x', criteria: ['c'],
                                evaluation: Qualspec::Evaluation.new(criterion: 'c', score: 8, pass: true))
      results.record_evaluation(candidate: 'pricey', scenario: 'x', criteria: ['c'],
                                evaluation: Qualspec::Evaluation.new(criterion: 'c', score: 9, pass: true))

      ranking = results.value_ranking
      expect(ranking.keys.first).to eq('cheap') # 8/0.001 = 8000 beats 9/0.01 = 900
      expect(ranking['cheap'][:score_per_dollar]).to eq(8000)
    end
  end
end
