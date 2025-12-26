# frozen_string_literal: true

module Qualspec
  module Suite
    class Definition
      attr_reader :name, :candidates_list, :scenarios_list, :variants_config, :temperature_list

      def initialize(name, &block)
        @name = name
        @candidates_list = []
        @scenarios_list = []
        @variants_config = nil
        @temperature_list = [nil] # nil means use model default

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

      # DSL: configure variants using FactoryBot
      #
      # @example Using trait matrix for combinatorial testing
      #   variants factory: :prompt_variant do
      #     trait_matrix [:msw, :layperson], [:neutral, :concerned]
      #   end
      #
      # @example Using explicit variant definitions
      #   variants do
      #     variant :expert_concerned, traits: [:msw, :concerned]
      #     variant :naive_neutral, traits: [:layperson, :neutral]
      #   end
      def variants(factory: :prompt_variant, &block)
        @variants_config = VariantsConfig.new(factory: factory, &block)
      end

      # DSL: define temperatures to test across
      #
      # @example
      #   temperatures [0.0, 0.7, 1.0]
      def temperatures(temps)
        temps = Array(temps)
        temps.each do |t|
          next if t.nil?
          raise ArgumentError, "Temperature must be numeric, got #{t.inspect}" unless t.is_a?(Numeric)
          raise ArgumentError, "Temperature #{t} outside valid range 0.0-2.0" unless (0.0..2.0).cover?(t)
        end
        @temperature_list = temps
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

    # Configuration for variant generation
    class VariantsConfig
      attr_reader :factory_name, :variant_definitions, :trait_combinations

      def initialize(factory: :prompt_variant, &block)
        @factory_name = factory
        @variant_definitions = []
        @trait_combinations = nil

        instance_eval(&block) if block_given? # rubocop:disable Style/EvalWithLocation -- DSL pattern
      end

      # DSL: Define an individual named variant
      def variant(name, traits: [], **attributes)
        @variant_definitions << {
          name: name,
          traits: Array(traits),
          attributes: attributes
        }
      end

      # DSL: Define a trait matrix for combinatorial testing
      # Each argument is an array of traits for that dimension.
      #
      # @example
      #   trait_matrix [:msw, :layperson], [:neutral, :concerned]
      #   # Generates: msw_neutral, msw_concerned, layperson_neutral, layperson_concerned
      def trait_matrix(*dimensions)
        raise ArgumentError, 'trait_matrix requires at least 1 dimension' if dimensions.empty?

        dimensions.each_with_index do |dim, i|
          raise ArgumentError, "trait_matrix dimension #{i} must be a non-empty array" unless dim.is_a?(Array) && !dim.empty?
        end

        @trait_combinations = dimensions.first.product(*dimensions[1..])
      end

      # Build all variant instances
      def build_variants
        variants = []

        # Build explicitly defined variants
        @variant_definitions.each do |defn|
          variants << build_variant(defn[:name], defn[:traits], defn[:attributes])
        end

        # Build matrix variants if defined
        @trait_combinations&.each do |trait_combo|
          name = trait_combo.join('_')
          variants << build_variant(name, trait_combo, {})
        end

        # Default to a single empty variant if nothing defined
        variants << build_default_variant if variants.empty?

        # Deduplicate by name, preserving first occurrence
        seen = {}
        variants.select { |v| !seen.key?(v.name) && (seen[v.name] = true) }
      end

      private

      def build_default_variant
        variant = PromptVariant.new
        variant.name = 'default'
        variant
      end

      def build_variant(name, traits, attributes)
        variant = if traits.any? && factory_bot_available?
                    FactoryBot.build(@factory_name, *traits, **attributes)
                  else
                    v = PromptVariant.new
                    attributes.each { |k, val| v.public_send("#{k}=", val) }
                    v
                  end

        variant.name = name.to_s
        variant.traits_applied = traits.map(&:to_s)
        variant
      end

      def factory_bot_available?
        return false unless defined?(FactoryBot)
        return false unless FactoryBot.respond_to?(:build)

        true
      rescue StandardError
        false
      end
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
