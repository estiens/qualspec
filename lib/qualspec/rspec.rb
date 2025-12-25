# frozen_string_literal: true

# RSpec integration for Qualspec
#
# Add to your spec_helper.rb:
#
#   require "qualspec/rspec"
#
#   RSpec.configure do |config|
#     config.include Qualspec::RSpec::Helpers
#   end
#
#   # Optional: Configure qualspec-specific settings
#   Qualspec::RSpec.configure do |config|
#     config.default_threshold = 7
#     config.vcr_cassette_dir = "spec/cassettes/qualspec"
#   end
#
# Then in your specs:
#
#   describe "MyAgent" do
#     it "responds helpfully" do
#       response = my_agent.call("Hello")
#
#       result = qualspec_evaluate(response, "responds in a friendly manner")
#       expect(result).to be_passing
#       expect(result.score).to be >= 8
#     end
#
#     it "uses tools correctly" do
#       response = my_agent.call("What's the weather?")
#
#       result = qualspec_evaluate(response, rubric: :tool_calling)
#       expect(result).to be_passing
#     end
#   end
#

require "qualspec"
require_relative "rspec/configuration"
require_relative "rspec/evaluation_result"
require_relative "rspec/helpers"
require_relative "rspec/matchers"

module Qualspec
  module RSpec
    class << self
      # Setup RSpec integration with sensible defaults
      #
      # @example
      #   Qualspec::RSpec.setup!
      #
      def setup!
        # Load builtin rubrics if configured
        if configuration.load_builtins
          Qualspec::BuiltinRubrics.load!
        end

        # Configure RSpec if available
        if defined?(::RSpec) && ::RSpec.respond_to?(:configure)
          ::RSpec.configure do |config|
            config.include Qualspec::RSpec::Helpers
          end
        end
      end
    end
  end
end
