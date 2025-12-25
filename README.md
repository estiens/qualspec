# Qualspec

LLM-judged qualitative testing for Ruby. Evaluate AI agents, compare models, and test subjective qualities that traditional assertions can't capture.

## Installation

```ruby
gem "qualspec"
```

## Configuration

Set your API key (required):

```bash
export QUALSPEC_API_KEY=your_openrouter_key
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `QUALSPEC_API_KEY` | API key (required) | - |
| `QUALSPEC_API_URL` | API endpoint | `https://openrouter.ai/api/v1` |
| `QUALSPEC_MODEL` | Default model for candidates | `google/gemini-3-flash-preview` |
| `QUALSPEC_JUDGE_MODEL` | Model used as judge | Same as `QUALSPEC_MODEL` |

## Quick Start

### Compare Models (CLI)

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

```bash
# Run comparison
qualspec eval/comparison.rb

# Generate HTML report
qualspec --html report.html eval/comparison.rb
```

### Test Your Agent (RSpec)

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

## Documentation

- [Getting Started](docs/getting-started.md)
- [Evaluation Suites](docs/evaluation-suites.md) - CLI for model comparison
- [RSpec Integration](docs/rspec-integration.md) - Testing your agents
- [Rubrics](docs/rubrics.md) - Builtin and custom evaluation criteria
- [Configuration](docs/configuration.md) - All options
- [Recording](docs/recording.md) - VCR integration

## License

MIT
