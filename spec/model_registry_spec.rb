# frozen_string_literal: true

require 'qualspec'
require 'tempfile'

RSpec.describe Qualspec::ModelRegistry do
  def registry_for(yaml)
    file = Tempfile.new(['models', '.yml'])
    file.write(yaml)
    file.close
    described_class.new(path: file.path)
  ensure
    file&.unlink
  end

  describe '#resolve' do
    let(:registry) do
      registry_for(<<~YAML)
        default: openrouter/auto
        models:
          glm: z-ai/glm-5.2
          deepseek_flash: deepseek/deepseek-v4-flash
      YAML
    end

    it 'resolves a known name to its slug' do
      expect(registry.resolve(:glm)).to eq('z-ai/glm-5.2')
    end

    it 'accepts string names too' do
      expect(registry.resolve('deepseek_flash')).to eq('deepseek/deepseek-v4-flash')
    end

    it 'falls back to the default for unknown names' do
      expect(registry.resolve(:nope)).to eq('openrouter/auto')
    end

    it 'returns the default when given nil' do
      expect(registry.resolve).to eq('openrouter/auto')
    end

    it 'returns the default for an empty string' do
      expect(registry.resolve('')).to eq('openrouter/auto')
    end
  end

  describe 'default fallback' do
    it 'uses Configuration::DEFAULT_MODEL when no file and no default given' do
      registry = described_class.new(path: '/nonexistent/models.yml')
      expect(registry.resolve(:anything)).to eq(Qualspec::Configuration::DEFAULT_MODEL)
      expect(registry.default).to eq('openrouter/auto')
    end

    it 'does not raise on a malformed config file' do
      expect { registry_for("\tnot: valid: yaml:\n  - [") }.not_to raise_error
    end
  end

  describe '#all' do
    it 'exposes the full name => slug map' do
      registry = registry_for("models:\n  glm: z-ai/glm-5.2\n")
      expect(registry.all).to eq('glm' => 'z-ai/glm-5.2')
    end
  end

  describe 'Qualspec.model / Qualspec.models' do
    before { Qualspec.reset! }

    it 'resolves names from the shipped config/models.yml' do
      expect(Qualspec.model(:glm)).to eq('z-ai/glm-5.2')
      expect(Qualspec.model(:deepseek_pro)).to eq('deepseek/deepseek-v4-pro')
    end

    it 'defaults to openrouter/auto' do
      expect(Qualspec.model).to eq('openrouter/auto')
      expect(Qualspec.model(:unknown_model)).to eq('openrouter/auto')
    end
  end

  describe 'Candidate default model' do
    before { Qualspec.reset! }

    it 'defaults to the configured default model when none is given' do
      candidate = Qualspec::Suite::Candidate.new(:c)
      expect(candidate.model).to eq('openrouter/auto')
    end
  end
end
