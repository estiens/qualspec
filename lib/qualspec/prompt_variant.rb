# frozen_string_literal: true

module Qualspec
  # PromptVariant holds the configuration for a single test permutation.
  # This class is the target for FactoryBot factory definitions, allowing
  # traits to compose multi-dimensional prompt variations.
  #
  # @example Basic usage
  #   variant = PromptVariant.new
  #   variant.credential = "I'm a licensed social worker."
  #   variant.stance = :concerned
  #   variant.base_prompt = "Should we implement this feature?"
  #
  # @example With FactoryBot
  #   variant = FactoryBot.build(:prompt_variant, :msw, :concerned)
  #
  class PromptVariant
    # Default values as constants
    DEFAULT_TEMPERATURE = 0.7
    DEFAULT_STANCE = :neutral
    DEFAULT_DIALECT = :formal
    DEFAULT_VERBOSITY = :normal
    TEMPERATURE_RANGE = (0.0..2.0)

    # Core variant dimensions
    attr_accessor :credential, :stance, :dialect, :verbosity
    attr_reader :temperature

    # Prompt composition
    attr_accessor :base_prompt, :full_prompt, :system_prompt

    # Context/history for multi-turn scenarios
    attr_accessor :context_history

    # Output format requirements
    attr_accessor :output_schema, :schema_instruction

    # Metadata for tracking
    attr_accessor :name, :traits_applied

    # Response storage (populated during test run)
    attr_accessor :response, :evaluation

    def initialize
      @temperature = DEFAULT_TEMPERATURE
      @stance = DEFAULT_STANCE
      @dialect = DEFAULT_DIALECT
      @verbosity = DEFAULT_VERBOSITY
      @credential = nil
      @context_history = []
      @output_schema = :free
      @traits_applied = []
    end

    def temperature=(value)
      return @temperature = value if value.nil?

      raise ArgumentError, "Temperature must be between 0.0 and 2.0, got #{value.inspect}" unless value.is_a?(Numeric) && TEMPERATURE_RANGE.cover?(value)

      @temperature = value
    end

    # Check if this variant has non-default settings
    def customized?
      @credential.to_s.strip != '' ||
        @stance != DEFAULT_STANCE ||
        (!@temperature.nil? && @temperature != DEFAULT_TEMPERATURE)
    end

    # Generate a unique key for this variant configuration
    def variant_key
      return 'default' if @traits_applied.empty? && @name.nil?

      @name || @traits_applied.sort.join('_')
    end

    # Convert to hash for results tracking
    def to_h
      {
        name: @name,
        variant_key: variant_key,
        traits: @traits_applied,
        credential: @credential,
        stance: @stance,
        dialect: @dialect,
        temperature: @temperature,
        verbosity: @verbosity,
        full_prompt: @full_prompt,
        system_prompt: @system_prompt,
        output_schema: @output_schema
      }.compact
    end
  end
end
