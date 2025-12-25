# frozen_string_literal: true

module Qualspec
  module Suite
    class Behavior
      attr_reader :name, :scenarios_list

      def initialize(name, &block)
        @name = name
        @scenarios_list = []

        instance_eval(&block) if block_given? # rubocop:disable Style/EvalWithLocation -- DSL pattern requires eval
      end

      def scenario(name, &block)
        @scenarios_list << Scenario.new(name, &block)
      end

      class << self
        def registry
          @registry ||= {}
        end

        def define(name, &block)
          registry[name.to_sym] = new(name, &block)
        end

        def find(name)
          registry[name.to_sym] || raise(Qualspec::Error, "Behavior '#{name}' not found")
        end

        def clear!
          @registry = {}
        end
      end
    end
  end

  # Top-level convenience method
  def self.define_behavior(name, &block)
    Suite::Behavior.define(name, &block)
  end
end
