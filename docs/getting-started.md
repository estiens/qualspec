# Getting Started

Qualspec is a Ruby gem for running qualitative tests judged by an LLM. Use it to evaluate AI agents, compare models, or test subjective qualities that traditional assertions can't capture.

## Installation

Add to your Gemfile:

```ruby
gem "qualspec"
```

Then run:

```bash
bundle install
```

## Configuration

Qualspec auto-detects your API configuration from environment variables:

```bash
# OpenRouter (recommended)
export OPENROUTER_API_KEY=your_key

# Or OpenAI
export OPENAI_API_KEY=your_key

# Or custom endpoint
export QUALSPEC_API_URL=http://localhost:11434/v1
export QUALSPEC_API_KEY=your_key
```

You can also configure programmatically:

```ruby
Qualspec.configure do |config|
  config.api_url = "https://openrouter.ai/api/v1"
  config.api_key = ENV["MY_API_KEY"]
  config.judge_model = "google/gemini-2.5-flash-preview"
  config.request_timeout = 120
end
```

## Two Ways to Use Qualspec

### 1. Evaluation Suites (CLI)

For comparing multiple models or running standalone evaluations:

```ruby
# eval/comparison.rb
Qualspec.evaluation "Model Comparison" do
  candidates do
    candidate "gpt4", model: "openai/gpt-4"
    candidate "claude", model: "anthropic/claude-3-sonnet"
  end

  scenario "helpfulness" do
    prompt "How do I center a div in CSS?"
    eval "provides a working solution"
    eval "explains the approach"
  end
end
```

Run with:

```bash
qualspec eval/comparison.rb
```

### 2. RSpec Integration

For testing your own AI agents in your test suite:

```ruby
require "qualspec/rspec"

RSpec.describe MyAgent do
  include Qualspec::RSpec::Helpers

  it "responds helpfully" do
    response = MyAgent.call("Hello")

    result = qualspec_evaluate(response, "responds in a friendly manner")
    expect(result).to be_passing
  end
end
```

## Next Steps

- [Evaluation Suites](evaluation-suites.md) - Full CLI DSL documentation
- [RSpec Integration](rspec-integration.md) - Testing your agents
- [Rubrics](rubrics.md) - Builtin and custom evaluation criteria
- [Configuration](configuration.md) - All configuration options
- [Recording](recording.md) - VCR integration for reproducible tests
