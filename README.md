# Qualspec

LLM-judged qualitative testing for Ruby. Evaluate AI agents, compare models, and test subjective qualities that traditional assertions can't capture.

## Installation

```ruby
gem "qualspec"
```

## Configuration

Set your API key (`OPEN_ROUTER_API_KEY` also works as a fallback):

```bash
export QUALSPEC_API_KEY=your_openrouter_key
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `QUALSPEC_API_KEY` | API key (required; falls back to `OPEN_ROUTER_API_KEY`) | - |
| `QUALSPEC_API_URL` | API endpoint | `https://openrouter.ai/api/v1` |
| `QUALSPEC_MODEL` | Default model for candidates | `openrouter/auto` |
| `QUALSPEC_JUDGE_MODEL` | Model used as judge | Same as `QUALSPEC_MODEL` |
| `QUALSPEC_MODELS_FILE` | Path to the named-models YAML | `config/models.yml` |

### Models

The default model everywhere is `openrouter/auto`, which routes to a sensible
model for any request — so qualspec works even with nothing configured. A
candidate with no `model:` uses this default too.

Curated models live in `config/models.yml` and can be referenced by name:

```ruby
candidate :flash, model: Qualspec.model(:deepseek_flash)

Qualspec.model(:glm)      # => "z-ai/glm-5.2"
Qualspec.model(:unknown)  # => "openrouter/auto"  (falls back to default)
Qualspec.model            # => "openrouter/auto"
Qualspec.models.all       # => { "glm" => "z-ai/glm-5.2", ... }
```

Edit `config/models.yml` to add/rename models, or point `QUALSPEC_MODELS_FILE`
at your own. Override the process-wide default with `QUALSPEC_MODEL`.

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
- [Evaluation Suites](docs/evaluation-suites.md) - CLI for model comparison (incl. cost/value tracking)
- [RSpec Integration](docs/rspec-integration.md) - Testing your agents
- [Rubrics](docs/rubrics.md) - Builtin and custom evaluation criteria
- [Configuration](docs/configuration.md) - All options, models, cost tracking
- [Recording](docs/recording.md) - VCR integration
- [Examples](examples/EXAMPLES.md) - Runnable scripts (replay free from cassettes)

## License

MIT
