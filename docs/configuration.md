# Configuration

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `QUALSPEC_API_KEY` | API key (required) | - |
| `QUALSPEC_API_URL` | API endpoint | `https://openrouter.ai/api/v1` |
| `QUALSPEC_MODEL` | Default model for candidates | `google/gemini-3-flash-preview` |
| `QUALSPEC_JUDGE_MODEL` | Model for judging | Same as `QUALSPEC_MODEL` |
| `QUALSPEC_SSL_VERIFY` | SSL verification (disable with `false`) | `true` |

### Required Setup

```bash
export QUALSPEC_API_KEY=your_openrouter_api_key
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
  config.api_key = ENV["MY_API_KEY"]

  # Models
  config.default_model = "google/gemini-2.5-flash-preview"
  config.judge_model = "openai/gpt-4"

  # Timeouts
  config.request_timeout = 120  # seconds

  # Custom judge prompt (optional)
  config.judge_system_prompt = <<~PROMPT
    You are a strict evaluator...
  PROMPT
end
```

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
