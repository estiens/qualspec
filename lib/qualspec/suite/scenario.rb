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

        instance_eval(&block) if block_given? # rubocop:disable Style/EvalWithLocation -- DSL pattern requires eval
      end

      # DSL methods
      def prompt(text)
        @prompt_text = text
      end

      def system(text)
        @system_prompt = text
      end

      # DSL method to add evaluation criteria
      def criterion(text)
        @evaluations << text
      end

      # Alias for backwards compatibility
      alias evaluate criterion

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

      # Compose the final prompt with variant modifications
      #
      # @param variant [PromptVariant, nil] The variant to apply
      # @return [String] The composed prompt
      def compose_prompt(variant = nil)
        return @prompt_text unless variant

        # If variant has a full_prompt (composed by FactoryBot callback), use it
        if variant.full_prompt && !variant.full_prompt.empty?
          variant.full_prompt
        elsif variant.base_prompt && !variant.base_prompt.empty?
          # Variant provides its own base prompt
          variant.base_prompt
        else
          # Compose: credential prefix + scenario prompt
          parts = []
          parts << variant.credential if variant.credential && !variant.credential.empty?
          parts << @prompt_text
          parts.join(' ')
        end
      end

      # Compose system prompt with variant and candidate overrides
      # Priority: variant > scenario > candidate
      #
      # @param variant [PromptVariant, nil] The variant
      # @param candidate_system_prompt [String, nil] The candidate's system prompt
      # @return [String, nil] The composed system prompt
      def compose_system_prompt(variant = nil, candidate_system_prompt = nil)
        variant&.system_prompt || @system_prompt || candidate_system_prompt
      end
    end
  end
end
