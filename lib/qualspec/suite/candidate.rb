# frozen_string_literal: true

module Qualspec
  module Suite
    class Candidate
      attr_reader :name, :model, :system_prompt, :options

      def initialize(name, model:, system_prompt: nil, **options)
        @name = name.to_s
        @model = model
        @system_prompt = system_prompt
        @options = options
      end

      def generate_response(prompt:, system_prompt: nil, temperature: nil)
        messages = []

        sys = system_prompt || @system_prompt
        messages << { role: 'system', content: sys } if sys
        messages << { role: 'user', content: prompt }

        Qualspec.client.chat(
          model: @model,
          messages: messages,
          json_mode: false, # We want natural responses, not JSON
          temperature: normalize_temperature(temperature)
        )
      end

      private

      # Normalize temperature for different providers
      def normalize_temperature(temp)
        return nil if temp.nil?

        case @model
        when /anthropic/
          temp.clamp(0.0, 1.0)
        when /openai/, /gpt/, /grok/
          temp.clamp(0.0, 2.0)
        else
          temp.clamp(0.0, 2.0)
        end
      end
    end
  end
end
