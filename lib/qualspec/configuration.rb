# frozen_string_literal: true

module Qualspec
  class Configuration
    attr_accessor :api_url, :default_model, :judge_model, :cache_enabled, :cache_dir, :judge_system_prompt,
                  :request_timeout
    attr_writer :api_key

    DEFAULT_API_URL = 'https://openrouter.ai/api/v1'
    # Universal fallback. `openrouter/auto` routes to a sensible model for any
    # request, so qualspec works even with no model configured anywhere.
    DEFAULT_MODEL = 'openrouter/auto'

    def initialize
      @api_url = ENV.fetch('QUALSPEC_API_URL', DEFAULT_API_URL)
      # Default nil: set explicitly via Qualspec.configure { |c| c.api_key = ... }.
      # When unset, #api_key falls back to env vars (see reader below).
      @api_key = nil
      @default_model = ENV.fetch('QUALSPEC_MODEL', DEFAULT_MODEL)
      @judge_model = ENV.fetch('QUALSPEC_JUDGE_MODEL') { @default_model }
      @cache_enabled = false
      @cache_dir = '.qualspec_cache'
      @judge_system_prompt = nil # Uses default if nil
      @request_timeout = 120
    end

    # Explicitly configured key wins; otherwise fall back to env vars.
    # Prefer QUALSPEC_API_KEY, then OPEN_ROUTER_API_KEY (default backend is
    # OpenRouter). The env vars are a convenience fallback, not a requirement —
    # pass api_key in Qualspec.configure to avoid relying on them.
    def api_key
      @api_key || ENV['QUALSPEC_API_KEY'] || ENV['OPEN_ROUTER_API_KEY']
    end

    def api_headers
      headers = { 'Content-Type' => 'application/json' }
      headers['Authorization'] = "Bearer #{api_key}" unless api_key.to_s.empty?
      headers
    end

    def api_key_configured?
      !api_key.to_s.empty?
    end
  end
end
