# frozen_string_literal: true

require 'yaml'

module Qualspec
  # Loads a curated list of named models from a YAML config file and resolves
  # names to their full provider slugs. Unknown/blank names fall back to the
  # configured default (ultimately Configuration::DEFAULT_MODEL, openrouter/auto),
  # so model lookups always return something usable.
  #
  # @example config/models.yml
  #   default: openrouter/auto
  #   models:
  #     glm: z-ai/glm-5.2
  #
  # @example
  #   Qualspec.model(:glm)      # => "z-ai/glm-5.2"
  #   Qualspec.model(:nope)     # => "openrouter/auto"
  #   Qualspec.model            # => "openrouter/auto"
  class ModelRegistry
    DEFAULT_CONFIG_PATH = 'config/models.yml'

    def initialize(path: nil, default: nil)
      @models = {}
      @default = default
      load_file(path || ENV['QUALSPEC_MODELS_FILE'] || DEFAULT_CONFIG_PATH)
    end

    # Resolve a model name to its slug, falling back to the default.
    #
    # @param name [Symbol, String, nil] the configured name (or nil for default)
    # @return [String] a model slug
    def resolve(name = nil)
      return default if name.nil? || name.to_s.empty?

      @models.fetch(name.to_s, default)
    end

    # @return [Hash{String=>String}] all configured name => slug pairs
    def all
      @models.dup
    end

    # @return [String] the universal fallback model
    def default
      @default || Configuration::DEFAULT_MODEL
    end

    private

    def load_file(path)
      return unless path && File.exist?(path)

      data = YAML.safe_load_file(path) || {}
      @default ||= data['default']
      (data['models'] || {}).each { |name, slug| @models[name.to_s] = slug }
    rescue StandardError
      # A malformed config file should never break a run; defaults still apply.
      nil
    end
  end
end
