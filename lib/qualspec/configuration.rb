# frozen_string_literal: true

module Qualspec
  class Configuration
    attr_accessor :api_url, :api_key, :default_model, :judge_model, :cache_enabled, :cache_dir, :judge_system_prompt,
                  :request_timeout

    DEFAULT_API_URL = 'https://openrouter.ai/api/v1'
    DEFAULT_MODEL = 'google/gemini-3-flash-preview'

    def initialize
      @api_url = ENV.fetch('QUALSPEC_API_URL', DEFAULT_API_URL)
      @api_key = ENV['QUALSPEC_API_KEY']
      @default_model = ENV.fetch('QUALSPEC_MODEL', DEFAULT_MODEL)
      @judge_model = ENV.fetch('QUALSPEC_JUDGE_MODEL') { @default_model }
      @cache_enabled = false
      @cache_dir = '.qualspec_cache'
      @judge_system_prompt = nil # Uses default if nil
      @request_timeout = 120
    end

    def api_headers
      headers = { 'Content-Type' => 'application/json' }
      headers['Authorization'] = "Bearer #{@api_key}" unless @api_key.to_s.empty?
      headers
    end

    def api_key_configured?
      !@api_key.to_s.empty?
    end
  end
end
