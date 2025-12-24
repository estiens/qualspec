# frozen_string_literal: true

module Qualspec
  class Configuration
    attr_accessor :api_url, :api_key, :default_model, :judge_model
    attr_accessor :cache_enabled, :cache_dir
    attr_accessor :judge_system_prompt
    attr_accessor :request_timeout

    # Common OpenAI-compatible API URLs
    KNOWN_PROVIDERS = {
      openrouter: "https://openrouter.ai/api/v1",
      openai: "https://api.openai.com/v1",
      ollama: "http://localhost:11434/v1"
    }.freeze

    def initialize
      # Try multiple env var names for flexibility
      @api_url = detect_api_url
      @api_key = detect_api_key
      @default_model = ENV.fetch("QUALSPEC_MODEL", "google/gemini-3-flash-preview")
      @judge_model = ENV.fetch("QUALSPEC_JUDGE_MODEL") { @default_model }
      @cache_enabled = false
      @cache_dir = ".qualspec_cache"
      @judge_system_prompt = nil # Uses default if nil
      @request_timeout = 120
    end

    def api_headers
      headers = { "Content-Type" => "application/json" }
      headers["Authorization"] = "Bearer #{@api_key}" unless @api_key.to_s.empty?
      headers
    end

    private

    def detect_api_url
      ENV["QUALSPEC_API_URL"] ||
        ENV["OPENROUTER_API_URL"] ||
        (ENV["OPENROUTER_API_KEY"] ? KNOWN_PROVIDERS[:openrouter] : nil) ||
        (ENV["OPENAI_API_KEY"] ? KNOWN_PROVIDERS[:openai] : nil) ||
        KNOWN_PROVIDERS[:ollama]
    end

    def detect_api_key
      ENV["QUALSPEC_API_KEY"] ||
        ENV["OPENROUTER_API_KEY"] ||
        ENV["OPENAI_API_KEY"] ||
        ""
    end
  end
end
