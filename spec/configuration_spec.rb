# frozen_string_literal: true

require 'qualspec'

RSpec.describe Qualspec::Configuration do
  around do |example|
    saved = ENV.values_at('QUALSPEC_API_KEY', 'OPEN_ROUTER_API_KEY')
    ENV.delete('QUALSPEC_API_KEY')
    ENV.delete('OPEN_ROUTER_API_KEY')
    example.run
    ENV['QUALSPEC_API_KEY'], ENV['OPEN_ROUTER_API_KEY'] = saved
  end

  describe '#api_key' do
    it 'is nil when nothing is set' do
      expect(described_class.new.api_key).to be_nil
    end

    it 'uses an explicitly configured key' do
      config = described_class.new
      config.api_key = 'sk-explicit'
      expect(config.api_key).to eq('sk-explicit')
    end

    it 'falls back to QUALSPEC_API_KEY when not configured' do
      ENV['QUALSPEC_API_KEY'] = 'sk-from-qualspec-env'
      expect(described_class.new.api_key).to eq('sk-from-qualspec-env')
    end

    it 'falls back to OPEN_ROUTER_API_KEY when QUALSPEC_API_KEY is absent' do
      ENV['OPEN_ROUTER_API_KEY'] = 'sk-from-openrouter-env'
      expect(described_class.new.api_key).to eq('sk-from-openrouter-env')
    end

    it 'prefers an explicit key over env vars' do
      ENV['QUALSPEC_API_KEY'] = 'sk-env'
      config = described_class.new
      config.api_key = 'sk-explicit'
      expect(config.api_key).to eq('sk-explicit')
    end

    it 'prefers QUALSPEC_API_KEY over OPEN_ROUTER_API_KEY' do
      ENV['QUALSPEC_API_KEY'] = 'sk-qualspec'
      ENV['OPEN_ROUTER_API_KEY'] = 'sk-openrouter'
      expect(described_class.new.api_key).to eq('sk-qualspec')
    end
  end

  describe '#api_headers' do
    it 'omits Authorization when no key is available' do
      expect(described_class.new.api_headers).not_to have_key('Authorization')
    end

    it 'includes a Bearer header from an explicitly configured key' do
      config = described_class.new
      config.api_key = 'sk-abc'
      expect(config.api_headers['Authorization']).to eq('Bearer sk-abc')
    end
  end

  describe '#api_key_configured?' do
    it 'is false with no key' do
      expect(described_class.new.api_key_configured?).to be(false)
    end

    it 'is true once a key is set via config' do
      config = described_class.new
      config.api_key = 'sk-abc'
      expect(config.api_key_configured?).to be(true)
    end
  end
end
