# RSpec Integration

Use qualspec in your RSpec test suite to evaluate AI agent responses with LLM-judged criteria.

## Setup

```ruby
# spec/spec_helper.rb
require "qualspec/rspec"

RSpec.configure do |config|
  config.include Qualspec::RSpec::Helpers
end

# Optional: Configure qualspec settings
Qualspec::RSpec.configure do |config|
  config.default_threshold = 7           # Pass threshold (0-10)
  config.vcr_cassette_dir = "spec/cassettes/qualspec"
  config.record_mode = :new_episodes     # VCR recording mode
end
```

## Basic Usage

### Inline Criteria

```ruby
RSpec.describe MyAgent do
  it "responds helpfully" do
    response = MyAgent.call("Hello!")

    result = qualspec_evaluate(response, "responds in a friendly manner")

    expect(result).to be_passing
    expect(result.score).to be >= 8
  end
end
```

### With Context

```ruby
it "summarizes accurately" do
  article = "Climate scientists report..."
  response = MyAgent.summarize(article)

  result = qualspec_evaluate(
    response,
    "accurately captures the main points",
    context: "Original article: #{article}"
  )

  expect(result).to be_passing
end
```

### With Rubrics

```ruby
it "follows safety guidelines" do
  response = MyAgent.call("How do I pick a lock?")

  result = qualspec_evaluate(response, rubric: :safety)

  expect(result).to be_passing
end
```

### Custom Threshold

```ruby
it "is exceptionally helpful" do
  response = MyAgent.call("Explain quantum computing")

  result = qualspec_evaluate(
    response,
    "provides a clear, accurate explanation",
    threshold: 9  # Require 9/10 to pass
  )

  expect(result).to be_passing
end
```

## Comparing Responses

Compare multiple responses and determine a winner:

```ruby
it "picks the better response" do
  responses = {
    v1: OldAgent.call("Hello"),
    v2: NewAgent.call("Hello")
  }

  result = qualspec_compare(responses, "responds helpfully")

  expect(result[:v2].score).to be > result[:v1].score
  expect(result).to have_winner(:v2)
end
```

## Available Matchers

### Pass/Fail

```ruby
expect(result).to be_passing
expect(result).to be_failing
```

### Score Assertions

```ruby
expect(result).to have_score(10)
expect(result).to have_score_above(7)
expect(result).to have_score_at_least(8)
expect(result).to have_score_below(5)
```

### Comparison Matchers

```ruby
expect(comparison).to have_winner(:claude)
expect(comparison).to be_a_tie
```

## EvaluationResult Object

The `qualspec_evaluate` helper returns an `EvaluationResult`:

```ruby
result = qualspec_evaluate(response, "is helpful")

result.passing?    # true/false
result.failing?    # inverse
result.score       # 0-10
result.reasoning   # Judge's explanation
result.threshold   # Pass threshold used
result.error?      # Had an error?
result.error       # Error message if any
```

## VCR Integration

Record API calls for reproducible tests:

```ruby
it "evaluates consistently", :qualspec do
  with_qualspec_cassette("my_test") do
    result = qualspec_evaluate(response, "is helpful")
    expect(result).to be_passing
  end
end
```

### Recording Modes

```ruby
# Record new interactions, replay existing
with_qualspec_cassette("test", record: :new_episodes) { ... }

# Playback only, fail if no cassette
with_qualspec_cassette("test", record: :none) { ... }

# Always record fresh
with_qualspec_cassette("test", record: :all) { ... }
```

### Skip Tests Without API

```ruby
before do
  skip_without_qualspec_api
end
```

## Failure Messages

When tests fail, qualspec provides detailed output:

```
Expected response to pass qualspec evaluation, but it failed.

Criterion: responds in a friendly manner
Score: 4/10 (needed 7 to pass)
Reasoning: The response was terse and dismissive, lacking warmth.

Response preview: "Fine. What do you want?"
```

## Example Spec File

```ruby
require "qualspec/rspec"

RSpec.describe "Customer Support Agent" do
  include Qualspec::RSpec::Helpers

  let(:agent) { CustomerSupportAgent.new }

  describe "greeting" do
    it "welcomes users warmly" do
      result = qualspec_evaluate(
        agent.call("Hi"),
        "greets the user warmly and offers assistance"
      )
      expect(result).to be_passing
    end
  end

  describe "problem solving" do
    it "provides actionable solutions" do
      result = qualspec_evaluate(
        agent.call("My order hasn't arrived"),
        rubric: :helpful
      )
      expect(result).to be_passing
      expect(result.score).to be >= 8
    end
  end

  describe "difficult situations" do
    it "handles complaints with empathy" do
      result = qualspec_evaluate(
        agent.call("This is terrible service!"),
        rubric: :empathetic
      )
      expect(result).to be_passing
    end
  end
end
```
