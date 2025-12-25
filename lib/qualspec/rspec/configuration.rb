# frozen_string_literal: true

module Qualspec
  module RSpec
    # RSpec-specific configuration
    #
    # @example Configure in spec_helper.rb
    #   Qualspec::RSpec.configure do |config|
    #     config.default_threshold = 7
    #     config.vcr_cassette_dir = "spec/cassettes/qualspec"
    #     config.record_mode = :new_episodes
    #   end
    #
    class Configuration
      # Default pass threshold for evaluations (0-10)
      attr_accessor :default_threshold

      # Directory for VCR cassettes
      attr_accessor :vcr_cassette_dir

      # VCR recording mode (:new_episodes, :none, :all, :once)
      attr_accessor :record_mode

      # Whether to load builtin rubrics automatically
      attr_accessor :load_builtins

      def initialize
        @default_threshold = 7
        @vcr_cassette_dir = 'spec/cassettes/qualspec'
        @record_mode = :new_episodes
        @load_builtins = true
      end
    end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = nil
      end
    end
  end
end
