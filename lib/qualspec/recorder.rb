# frozen_string_literal: true

module Qualspec
  class Recorder
    class << self
      def available?
        require 'vcr'
        true
      rescue LoadError
        false
      end

      def setup(cassette_dir: '.qualspec_cassettes')
        require_vcr!

        VCR.configure do |config|
          config.cassette_library_dir = cassette_dir
          config.hook_into :faraday
          config.default_cassette_options = {
            record: :new_episodes,
            match_requests_on: %i[method uri body]
          }
          # Filter out API keys
          config.filter_sensitive_data('<API_KEY>') { Qualspec.configuration.api_key }
        end
        @configured = true
      end

      def configured?
        @configured == true
      end

      def record(name, &block)
        setup unless configured?
        VCR.use_cassette(name, &block)
      end

      def playback(name, &block)
        setup unless configured?
        VCR.use_cassette(name, record: :none, &block)
      end

      private

      def require_vcr!
        require 'vcr'
      rescue LoadError
        raise Qualspec::Error, <<~MSG.strip
          VCR gem is required for recording/playback features.
          Add to your Gemfile: gem 'vcr'
        MSG
      end
    end
  end
end
