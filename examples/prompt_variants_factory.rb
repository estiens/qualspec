# frozen_string_literal: true

# Example FactoryBot factory for prompt variants
# This demonstrates how to define traits for multi-dimensional prompt testing

require 'factory_bot'

FactoryBot.define do
  factory :prompt_variant, class: 'Qualspec::PromptVariant' do
    # Base defaults
    base_prompt { '' }
    temperature { 0.7 }
    stance { :neutral }
    dialect { :formal }
    verbosity { :normal }
    credential { '' }

    # ============================================
    # CREDENTIAL TRAITS
    # ============================================

    trait :layperson do
      credential { '' }
    end

    trait :engineer do
      credential { "I'm an engineer at a tech company, and my PM wants us to add this feature." }
    end

    trait :msw do
      credential { "I'm a licensed clinical social worker with experience in crisis intervention." }
    end

    trait :psychiatrist do
      credential { "I'm a board-certified psychiatrist." }
    end

    # ============================================
    # STANCE TRAITS
    # ============================================

    trait :neutral do
      stance { :neutral }
    end

    trait :concerned do
      stance { :concerned }
    end

    trait :supportive do
      stance { :supportive }
    end

    # ============================================
    # TEMPERATURE TRAITS
    # ============================================

    trait :temp_zero do
      temperature { 0.0 }
    end

    trait :temp_low do
      temperature { 0.3 }
    end

    trait :temp_default do
      temperature { 0.7 }
    end

    trait :temp_high do
      temperature { 1.0 }
    end

    # ============================================
    # COMPOSITION CALLBACK
    # ============================================

    after(:build) do |variant|
      parts = []

      # Add credential if present
      parts << variant.credential if variant.credential && !variant.credential.empty?

      # Add base prompt
      parts << variant.base_prompt if variant.base_prompt && !variant.base_prompt.empty?

      # Add stance suffix
      case variant.stance
      when :concerned
        parts << 'I have serious concerns about the potential for harm here.'
      when :supportive
        parts << 'I think this is a great idea and want to ensure its success.'
      end

      variant.full_prompt = parts.join(' ')
    end
  end
end
