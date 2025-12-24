# frozen_string_literal: true

require "httpx"
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

      options = {
        timeout: { operation_timeout: config.request_timeout },
        headers: config.api_headers
      }

      # SSL verification - disabled by default to avoid CRL issues, enable with QUALSPEC_SSL_VERIFY=true
      unless ENV["QUALSPEC_SSL_VERIFY"] == "true"
        options[:ssl] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      end

      @http = HTTPX.with(**options)
    end

    def chat(model:, messages:, json_mode: true, with_metadata: false)
      payload = {
        model: model,
        messages: messages
      }

      # Request structured JSON output
      payload[:response_format] = { type: "json_object" } if json_mode

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      response = @http.post(
        "#{@config.api_url}/chat/completions",
        json: payload
      )

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      handle_response(response, duration_ms, with_metadata)
    end

    private

    def handle_response(response, duration_ms, with_metadata)
      # HTTPX returns ErrorResponse for connection/timeout errors
      if response.is_a?(HTTPX::ErrorResponse)
        raise RequestError, "Request failed: #{response.error.message}"
      end

      unless response.status == 200
        raise RequestError, "API request failed (#{response.status}): #{response.body}"
      end

      data = JSON.parse(response.body.to_s)
      content = data.dig("choices", 0, "message", "content")

      raise RequestError, "No content in response: #{data}" if content.nil?

      return content unless with_metadata

      # Extract metadata
      cost = extract_cost(response, data)
      tokens = extract_tokens(data)
      model = data["model"]

      Response.new(
        content: content,
        duration_ms: duration_ms,
        cost: cost,
        model: model,
        tokens: tokens
      )
    end

    def extract_cost(response, data)
      # OpenRouter includes cost in response or headers
      # Check x-openrouter-cost header first
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
