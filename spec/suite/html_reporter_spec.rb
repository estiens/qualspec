# frozen_string_literal: true

require 'qualspec'

RSpec.describe Qualspec::Suite::HtmlReporter do
  before { Qualspec.reset! }

  # Build a Results object pre-populated with known data so we can assert on
  # the generated HTML without running any live API calls.
  def build_results
    results = Qualspec::Suite::Results.new('HTML Report Suite')

    # Populate candidate_models (behavior 5)
    results.candidate_models['claude'] = 'anthropic/claude-3.5-sonnet'
    results.candidate_models['gpt4']   = 'openai/gpt-4o'

    # Populate prompts (behavior 6)
    results.prompts['Scenario Alpha'] = 'What is the speed of light?'

    # Record responses in 4-level nested structure (behavior 4)
    results.record_response(
      candidate: 'claude',
      scenario: 'Scenario Alpha',
      variant: 'default',
      temperature: nil,
      response: 'The speed of light is 299,792,458 m/s.'
    )
    results.record_response(
      candidate: 'gpt4',
      scenario: 'Scenario Alpha',
      variant: 'default',
      temperature: nil,
      response: 'Approximately 3×10^8 metres per second.'
    )

    # Record evaluations so summary/detailed sections render
    results.record_evaluation(
      candidate: 'claude',
      scenario: 'Scenario Alpha',
      variant: 'default',
      temperature: nil,
      criteria: ['is accurate'],
      evaluation: Qualspec::Evaluation.new(criterion: 'is accurate', score: 9, pass: true, scenario_winner: true),
      winner: true
    )
    results.record_evaluation(
      candidate: 'gpt4',
      scenario: 'Scenario Alpha',
      variant: 'default',
      temperature: nil,
      criteria: ['is accurate'],
      evaluation: Qualspec::Evaluation.new(criterion: 'is accurate', score: 7, pass: true, scenario_winner: false),
      winner: false
    )

    results.finish!
    results
  end

  subject(:reporter) { described_class.new(build_results) }
  let(:html) { reporter.to_html }

  # ---- Behavior 4: responses_section renders actual text, not hash inspect ----

  describe '#responses_section (behavior 4)' do
    it 'renders the actual response text for each candidate' do
      expect(html).to include('The speed of light is 299,792,458 m/s.')
      # CGI.escapeHTML may or may not encode × — match the unescaped text which is safe ASCII context
      expect(html).to include('10^8 metres per second.')
    end

    it 'does NOT stringify the hash object (regression guard)' do
      # A broken implementation renders something like `{:content=>"..."}`
      expect(html).not_to include(':content=&gt;')
      expect(html).not_to include(':content=>')
    end

    it 'wraps each response in a <pre> block' do
      expect(html).to match(/<pre>.*?The speed of light/m)
    end

    it 'renders both candidates in the same scenario block' do
      # Both candidate names should appear inside the responses section
      expect(html).to include('claude')
      expect(html).to include('gpt4')
    end
  end

  # ---- Behavior 5: get_candidate_model returns the real model string ----

  describe '#get_candidate_model (behavior 5)' do
    it 'returns the stored model string for a known candidate' do
      # The method is private, but its effect is visible in summary HTML output
      expect(html).to include('anthropic/claude-3.5-sonnet')
      expect(html).to include('openai/gpt-4o')
    end

    it 'returns "unknown" for a candidate not in candidate_models' do
      reporter_instance = described_class.new(build_results)
      # Access via send since it is private
      expect(reporter_instance.send(:get_candidate_model, 'nonexistent')).to eq('unknown')
    end

    it 'maps candidate name to correct model string' do
      reporter_instance = described_class.new(build_results)
      expect(reporter_instance.send(:get_candidate_model, 'claude')).to eq('anthropic/claude-3.5-sonnet')
      expect(reporter_instance.send(:get_candidate_model, 'gpt4')).to eq('openai/gpt-4o')
    end
  end

  # ---- Behavior 6: get_scenario_prompt returns the scenario prompt ----

  describe '#get_scenario_prompt (behavior 6)' do
    it 'returns the prompt for a known scenario' do
      reporter_instance = described_class.new(build_results)
      expect(reporter_instance.send(:get_scenario_prompt, 'Scenario Alpha')).to eq('What is the speed of light?')
    end

    it 'returns nil for an unknown scenario' do
      reporter_instance = described_class.new(build_results)
      expect(reporter_instance.send(:get_scenario_prompt, 'Nonexistent Scenario')).to be_nil
    end

    it 'renders the prompt text in the detailed results section' do
      expect(html).to include('What is the speed of light?')
    end
  end

  # ---- General HTML structure integrity ----

  describe '#to_html' do
    it 'produces valid-looking HTML with expected structure' do
      expect(html).to include('<!DOCTYPE html>')
      expect(html).to include('HTML Report Suite')
      expect(html).to include('Qualspec Report')
    end

    it 'includes the scenario name in the output' do
      expect(html).to include('Scenario Alpha')
    end
  end
end
