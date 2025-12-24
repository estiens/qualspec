# frozen_string_literal: true

module Qualspec
  class Rubric
    attr_reader :name, :criteria

    def initialize(name, &block)
      @name = name
      @criteria = []
      instance_eval(&block) if block_given?
    end

    def criterion(description)
      @criteria << description
    end

    def to_s
      @criteria.join("\n")
    end

    class << self
      def registry
        @registry ||= {}
      end

      def define(name, &block)
        registry[name.to_sym] = new(name, &block)
      end

      def find(name)
        registry[name.to_sym] || raise(Error, "Rubric '#{name}' not found")
      end

      def defined?(name)
        registry.key?(name.to_sym)
      end

      def clear!
        @registry = {}
      end
    end
  end
end
