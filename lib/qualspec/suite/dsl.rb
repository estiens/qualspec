# frozen_string_literal: true

module Qualspec
  module Suite
    class Definition
      attr_reader :name, :candidates_list, :scenarios_list

      def initialize(name, &block)
        @name = name
        @candidates_list = []
        @scenarios_list = []

        instance_eval(&block) if block_given? # rubocop:disable Style/EvalWithLocation -- DSL pattern requires eval
      end

      # DSL: define candidates
      def candidates(&block)
        instance_eval(&block) # rubocop:disable Style/EvalWithLocation -- DSL pattern requires eval
      end

      def candidate(name, model:, system_prompt: nil, **options)
        @candidates_list << Candidate.new(name, model: model, system_prompt: system_prompt, **options)
      end

      # DSL: define scenarios
      def scenario(name, &block)
        @scenarios_list << Scenario.new(name, &block)
      end

      # DSL: include shared behaviors
      def behaves_like(behavior_name)
        behavior = Behavior.find(behavior_name)
        @scenarios_list.concat(behavior.scenarios_list)
      end

      # Alias for readability
      alias it_behaves_like behaves_like
      alias include_behavior behaves_like
    end

    class << self
      def registry
        @registry ||= {}
      end

      def define(name, &block)
        registry[name] = Definition.new(name, &block)
      end

      def find(name)
        registry[name] || raise(Qualspec::Error, "Evaluation suite '#{name}' not found")
      end

      def clear!
        @registry = {}
      end
    end
  end

  # Top-level convenience method
  def self.evaluation(name, &block)
    Suite.define(name, &block)
  end
end
