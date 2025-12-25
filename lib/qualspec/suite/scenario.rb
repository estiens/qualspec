# frozen_string_literal: true

module Qualspec
  module Suite
    class Scenario
      attr_reader :name, :prompt_text, :system_prompt, :evaluations, :rubric_name, :context

      def initialize(name, &block)
        @name = name
        @prompt_text = nil
        @system_prompt = nil
        @evaluations = []
        @rubric_name = nil
        @context = nil

        instance_eval(&block) if block_given? # rubocop:disable Style/EvalWithLocation
      end

      # DSL methods
      def prompt(text)
        @prompt_text = text
      end

      def system(text)
        @system_prompt = text
      end

      # rubocop:disable Naming/AccessorMethodName - DSL method, not a getter
      def eval(criterion)
        @evaluations << criterion
      end
      # rubocop:enable Naming/AccessorMethodName

      def rubric(name)
        @rubric_name = name
      end

      def with_context(text)
        @context = text
      end

      # Get all criteria to evaluate (from explicit evals + rubric)
      def all_criteria
        criteria = @evaluations.dup

        if @rubric_name
          rubric_obj = Rubric.find(@rubric_name)
          criteria.concat(rubric_obj.criteria)
        end

        criteria
      end
    end
  end
end
