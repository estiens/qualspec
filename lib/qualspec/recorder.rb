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

        recorder = self
        VCR.configure do |config|
          config.cassette_library_dir = cassette_dir
          config.hook_into :faraday
          config.default_cassette_options = {
            record: :new_episodes,
            match_requests_on: %i[method uri body_without_model]
          }
          # Filter out API keys — guard against adding duplicate filters
          unless @api_key_filter_registered
            config.filter_sensitive_data('<API_KEY>') { Qualspec.configuration.api_key }
            @api_key_filter_registered = true
          end
        end

        # Register custom matcher once — ignores the `model` field so cassettes
        # recorded with one model work in CI where a different model is configured.
        unless @matcher_registered
          VCR.configure do |config|
            config.register_request_matcher(:body_without_model) do |r1, r2|
              recorder.send(:normalize_body_for_match, r1.body) == recorder.send(:normalize_body_for_match, r2.body)
            end
          end
          @matcher_registered = true
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

      # Replay a cassette if it already exists (no API key required), otherwise
      # record a fresh one. Ideal for examples that ship a committed cassette so
      # they run for free, but still record on first run.
      def use_cassette(name, &block)
        setup unless configured?
        mode = cassette_exists?(name) ? :none : :new_episodes
        VCR.use_cassette(name, record: mode, &block)
      end

      def cassette_exists?(name)
        require_vcr!
        File.exist?(File.join(VCR.configuration.cassette_library_dir, "#{name}.yml"))
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

      def normalize_body_for_match(body)
        parsed = JSON.parse(body)
        parsed.delete('model')
        JSON.generate(parsed)
      rescue JSON::ParserError
        body
      end
    end
  end
end
