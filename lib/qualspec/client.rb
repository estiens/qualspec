# frozen_string_literal: true

require "faraday"
require "json"

module Qualspec
  class Client
    class RequestError < Qualspec::Error; end

    # Response with metadata
    class Response
      attr_reader :content, :duration_ms, :cost, :model, :tokens

      def initialize(content:, duration_ms: nil, cost: nil, model: nil, tokens: nil)
        @content = content
        @duration_ms = duration_ms
        @cost = cost
        @model = model
        @tokens = tokens
      end

      # Allow using response as a string
      def to_s
        @content
      end

      def to_str
        @content
      end
    end

    def initialize(config = Qualspec.configuration)
      @config = config

      @conn = Faraday.new(url: config.api_url) do |f|
        f.request :json
        f.response :json
        f.headers = config.api_headers
        f.options.timeout = config.request_timeout
        f.options.open_timeout = 10

        # SSL verification - disabled by default to avoid CRL issues
        unless ENV["QUALSPEC_SSL_VERIFY"] == "true"
          f.ssl.verify = false
        end

        f.adapter Faraday.default_adapter
      end
    end

    def chat(model:, messages:, json_mode: true, with_metadata: false)
      payload = {
        model: model,
        messages: messages
      }

      # Request structured JSON output
      payload[:response_format] = { type: "json_object" } if json_mode

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      response = @conn.post("chat/completions", payload)

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      handle_response(response, duration_ms, with_metadata)
    end

    private

    def handle_response(response, duration_ms, with_metadata)
      unless response.success?
        raise RequestError, "API request failed (#{response.status}): #{response.body}"
      end

      data = response.body
      data = JSON.parse(data) if data.is_a?(String)

      content = data.dig("choices", 0, "message", "content")

      raise RequestError, "No content in response: #{data}" if content.nil?

      return content unless with_metadata

      # Extract metadata
      cost = extract_cost(response, data)
      tokens = extract_tokens(data)
      model_name = data["model"]

      Response.new(
        content: content,
        duration_ms: duration_ms,
        cost: cost,
        model: model_name,
        tokens: tokens
      )
    end

    def extract_cost(response, data)
      # OpenRouter includes cost in response or headers
      header_cost = response.headers["x-openrouter-cost"]
      return header_cost.to_f if header_cost

      # Check response body (some providers include it)
      data.dig("usage", "total_cost") || data.dig("cost")
    end

    def extract_tokens(data)
      usage = data["usage"]
      return nil unless usage

      {
        prompt: usage["prompt_tokens"],
        completion: usage["completion_tokens"],
        total: usage["total_tokens"]
      }
    end
  end
end
