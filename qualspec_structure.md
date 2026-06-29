# Qualspec - Key Structure

## Repository: estiens/qualspec

### Description
LLM-judged qualitative testing for Ruby. Evaluate AI agents, compare models, and test subjective qualities that traditional assertions can't capture.

### Core Library Files (lib/qualspec/)
- **builtin_rubrics.rb** - Built-in evaluation criteria
- **client.rb** - API client for LLM interactions (cost/token metadata optional)
- **configuration.rb** - Configuration management
- **evaluation.rb** - Core evaluation logic
- **judge.rb** - LLM judge implementation
- **model_registry.rb** - Named models from `config/models.yml` (`Qualspec.model`)
- **prompt_variant.rb** - Variant value object (FactoryBot target)
- **recorder.rb** - VCR integration for recording
- **rspec.rb** - RSpec integration entry point
- **rubric.rb** - Custom rubric definitions
- **version.rb** - Version info

### Subdirectories
- **rspec/** - RSpec helpers and matchers
- **suite/** - Evaluation suite components

### Configuration Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| QUALSPEC_API_KEY | API key (falls back to OPEN_ROUTER_API_KEY) | - |
| QUALSPEC_API_URL | API endpoint | https://openrouter.ai/api/v1 |
| QUALSPEC_MODEL | Default model for candidates | openrouter/auto |
| QUALSPEC_JUDGE_MODEL | Model used as judge | Same as QUALSPEC_MODEL |
| QUALSPEC_MODELS_FILE | Named-models YAML | config/models.yml |

### Key Features
1. **Model Comparison CLI** - Compare multiple models on the same prompts
2. **LLM Judge** - Use an LLM to evaluate responses qualitatively
3. **RSpec Integration** - Test your agents with qualitative assertions
4. **Built-in Rubrics** - Pre-defined evaluation criteria
5. **Custom Rubrics** - Define your own evaluation criteria
6. **VCR Recording** - Record and replay API calls for testing
7. **HTML Reports** - Generate visual comparison reports
8. **Named Model Registry** - Reference curated models by name (`Qualspec.model`)
9. **Cost Tracking** - Opt-in per-call cost + quality-per-dollar `value_ranking`
10. **Variant & Temperature Matrix** - Combinatorial prompt testing via FactoryBot

### Example: Model Comparison
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

### Example: RSpec Integration
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

### CLI Usage
```shell
# Run comparison
qualspec eval/comparison.rb

# Generate HTML report
qualspec --html report.html eval/comparison.rb
```
