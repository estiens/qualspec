# Configuration

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `QUALSPEC_API_KEY` | API key (falls back to `OPEN_ROUTER_API_KEY`) | - |
| `QUALSPEC_API_URL` | API endpoint | `https://openrouter.ai/api/v1` |
| `QUALSPEC_MODEL` | Default model for candidates | `openrouter/auto` |
| `QUALSPEC_JUDGE_MODEL` | Model for judging | Same as `QUALSPEC_MODEL` |
| `QUALSPEC_MODELS_FILE` | Path to the named-models YAML | `config/models.yml` |
| `QUALSPEC_SSL_VERIFY` | SSL verification (disable with `false`) | `true` |

### Required Setup

Provide an API key via env var (or set it programmatically — see below):

```bash
export QUALSPEC_API_KEY=your_openrouter_api_key
# or, equivalently for OpenRouter:
export OPEN_ROUTER_API_KEY=sk-or-...
```

### Using Different Providers

**OpenRouter (default):**
```bash
export QUALSPEC_API_KEY=sk-or-...
# API URL defaults to https://openrouter.ai/api/v1
```

**OpenAI:**
```bash
export QUALSPEC_API_KEY=sk-...
export QUALSPEC_API_URL=https://api.openai.com/v1
```

**Ollama (local):**
```bash
export QUALSPEC_API_URL=http://localhost:11434/v1
# No API key needed for local Ollama
```

## Programmatic Configuration

```ruby
Qualspec.configure do |config|
  # API settings
  config.api_url = "https://openrouter.ai/api/v1"
  config.api_key = ENV["MY_API_KEY"]  # wins over QUALSPEC_API_KEY / OPEN_ROUTER_API_KEY

  # Models
  config.default_model = "openrouter/auto"
  config.judge_model = "openai/gpt-4"

  # Timeouts
  config.request_timeout = 120  # seconds

  # Custom judge prompt (optional)
  config.judge_system_prompt = <<~PROMPT
    You are a strict evaluator...
  PROMPT
end
```

## Models

The default model everywhere is `openrouter/auto`, which routes to a sensible
model for any request — so qualspec works even with nothing configured. A
`candidate` with no `model:` uses this default.

Curated models live in `config/models.yml` and are referenced by name:

```yaml
# config/models.yml
default: openrouter/auto
models:
  glm:            z-ai/glm-5.2
  deepseek_flash: deepseek/deepseek-v4-flash
  deepseek_pro:   deepseek/deepseek-v4-pro
```

```ruby
Qualspec.model(:glm)      # => "z-ai/glm-5.2"
Qualspec.model(:unknown)  # => "openrouter/auto"  (falls back to default)
Qualspec.model            # => "openrouter/auto"
Qualspec.models.all       # => { "glm" => "z-ai/glm-5.2", ... }

candidate :flash, model: Qualspec.model(:deepseek_flash)
```

Point `QUALSPEC_MODELS_FILE` at a different YAML to use your own list.

## Cost Tracking

Cost capture is **opt-in**. Enable `track_cost` in a suite to have qualspec
request OpenRouter usage accounting and record per-call cost + tokens:

```ruby
Qualspec.evaluation "Best Value" do
  track_cost
  # ...
end
```

Then `results.value_ranking` (quality per dollar) and `results.cost_by_candidate`
become available. Calling them without `track_cost` raises a clear error. See
[Evaluation Suites](evaluation-suites.md#cost-tracking) for details.

## RSpec Configuration

Additional configuration for RSpec integration:

```ruby
Qualspec::RSpec.configure do |config|
  # Default pass threshold (0-10)
  config.default_threshold = 7

  # VCR cassette directory
  config.vcr_cassette_dir = "spec/cassettes/qualspec"

  # VCR recording mode (:new_episodes, :none, :all, :once)
  config.record_mode = :new_episodes

  # Auto-load builtin rubrics
  config.load_builtins = true
end
```

## CLI Options

Override configuration via command line:

```bash
# Override judge model
qualspec -m openai/gpt-4 eval/suite.rb

# Override API URL
qualspec -u https://api.openai.com/v1 eval/suite.rb

# Override API key
qualspec -k sk-xxx eval/suite.rb
```

## Configuration Precedence

1. CLI options (highest)
2. Programmatic configuration
3. Environment variables
4. Defaults (lowest)

## Supported Providers

Any OpenAI-compatible API works:

| Provider | API URL |
|----------|---------|
| OpenRouter | `https://openrouter.ai/api/v1` |
| OpenAI | `https://api.openai.com/v1` |
| Ollama | `http://localhost:11434/v1` |
| Azure OpenAI | `https://YOUR.openai.azure.com/openai/deployments/YOUR_DEPLOYMENT` |
| Together AI | `https://api.together.xyz/v1` |
| Groq | `https://api.groq.com/openai/v1` |

## SSL Configuration

SSL verification is enabled by default. Disable it if you encounter certificate issues:

```bash
export QUALSPEC_SSL_VERIFY=false
```

## Accessing Configuration

```ruby
config = Qualspec.configuration

config.api_url       # Current API URL
config.judge_model   # Current judge model
config.api_headers   # Headers sent with requests
```
