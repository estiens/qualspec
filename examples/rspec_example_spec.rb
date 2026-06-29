# frozen_string_literal: true

# Example RSpec integration with Qualspec
#
# Run with:
#   bundle exec rspec examples/rspec_example_spec.rb
#
# Cassettes auto-detected: uses playback if cassettes exist, otherwise records.
#
# Force re-record:
#   QUALSPEC_RECORD_MODE=all bundle exec rspec examples/rspec_example_spec.rb

require 'qualspec/rspec'

# Configure cassette directory for examples
Qualspec::RSpec.configure do |config|
  config.vcr_cassette_dir = 'examples/cassettes'

  # Auto-detect: use :none if cassettes exist, otherwise :new_episodes
  # Can override with QUALSPEC_RECORD_MODE env var
  config.record_mode = if ENV['QUALSPEC_RECORD_MODE']
                         ENV['QUALSPEC_RECORD_MODE'].to_sym
                       elsif Dir.exist?('examples/cassettes') && Dir.glob('examples/cassettes/*.yml').any?
                         :none
                       else
                         :new_episodes
                       end
end

RSpec.configure do |config|
  config.include Qualspec::RSpec::Helpers

  # Wrap all qualspec examples in cassettes automatically
  config.around(:each) do |example|
    # Generate cassette name from example description
    cassette_name = example.full_description
                           .gsub(/[^a-zA-Z0-9\s]/, '')
                           .gsub(/\s+/, '_')
                           .downcase[0, 100]

    with_qualspec_cassette(cassette_name) do
      example.run
    end
  end
end

# Load builtin rubrics
Qualspec::BuiltinRubrics.load!

RSpec.describe 'Qualspec RSpec Integration' do
  # Simple mock agent for demo
  let(:mock_agent) do
    lambda { |prompt|
      case prompt
      when /hello/i
        "Hello! I'm doing great, thanks for asking. How can I help you today?"
      when /weather/i
        "I'd be happy to help with weather information! However, I don't have access to " \
        'real-time weather data. You could check a weather service like weather.com or ' \
        "your phone's weather app for accurate forecasts."
      when /7.*8|8.*7/
        '7 times 8 equals 56.'
      else
        "I'm not sure how to help with that, but I'd be happy to try if you can give me more details!"
      end
    }
  end

  describe 'basic evaluation' do
    it 'evaluates responses with inline criteria' do
      response = mock_agent.call('Hello!')

      result = qualspec_evaluate(response, 'responds in a friendly and welcoming manner')

      expect(result).to be_passing
      expect(result.score).to be >= 7
    end

    it 'provides detailed feedback on failure' do
      response = 'no' # Intentionally terse/unfriendly

      result = qualspec_evaluate(response, 'responds in a friendly and welcoming manner')

      expect(result).to be_failing
      expect(result.reasoning).to be_a(String)
      expect(result.reasoning.length).to be_positive
    end
  end

  describe 'with context' do
    it 'uses context in evaluation' do
      response = mock_agent.call("What's the weather?")

      result = qualspec_evaluate(
        response,
        'appropriately handles the request given limitations',
        context: 'This agent does not have access to real-time data'
      )

      expect(result).to be_passing
    end
  end

  describe 'with rubrics' do
    it 'evaluates using builtin rubrics' do
      response = mock_agent.call('Hello!')

      # The :concise rubric checks if response is appropriately brief
      result = qualspec_evaluate(response, rubric: :concise)

      expect(result).to be_passing
    end
  end

  describe 'score matchers' do
    it 'supports score comparisons' do
      response = mock_agent.call('Hello!')

      result = qualspec_evaluate(response, 'is a reasonable response')

      expect(result).to have_score_at_least(5)
      expect(result).to have_score_above(4)
    end
  end

  describe 'comparative evaluation' do
    it 'compares multiple responses' do
      responses = {
        friendly: 'Hello! Great to meet you! How can I brighten your day?',
        terse: 'Hi.',
        rude: 'What do you want?'
      }

      result = qualspec_compare(responses, 'responds in a friendly manner')

      expect(result[:friendly].score).to be > result[:terse].score
      expect(result[:friendly].score).to be > result[:rude].score
    end
  end

  describe 'VCR integration' do
    it 'records and plays back API calls automatically' do
      # All tests in this file are automatically wrapped with cassettes
      # via the around(:each) hook in RSpec.configure
      # This test verifies the integration works
      response = mock_agent.call('Hello!')

      result = qualspec_evaluate(response, 'is a greeting response')

      expect(result).to be_passing
    end
  end
end
