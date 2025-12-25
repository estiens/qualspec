# Recording and Playback

Qualspec integrates with VCR to record API calls and replay them later. This enables:

- **Reproducible tests** - Same results every time
- **Fast CI** - No API calls during playback
- **Cost savings** - Don't pay for repeated API calls
- **Offline development** - Work without internet

## CLI Recording

### Record a Run

```bash
qualspec --record my_session eval/suite.rb
```

This creates `.qualspec_cassettes/my_session.yml` containing all API interactions.

### Playback

```bash
qualspec --playback my_session eval/suite.rb
```

Replays from the cassette with no network calls. Fails if a request isn't in the cassette.

## RSpec Recording

### Per-Test Recording

```ruby
it "evaluates consistently" do
  with_qualspec_cassette("greeting_test") do
    result = qualspec_evaluate(response, "is friendly")
    expect(result).to be_passing
  end
end
```

### Recording Modes

```ruby
# Record new, replay existing (default)
with_qualspec_cassette("test", record: :new_episodes) { ... }

# Playback only - fail if not recorded
with_qualspec_cassette("test", record: :none) { ... }

# Always record fresh
with_qualspec_cassette("test", record: :all) { ... }

# Record once, never update
with_qualspec_cassette("test", record: :once) { ... }
```

### Configure Default Mode

```ruby
Qualspec::RSpec.configure do |config|
  config.record_mode = :new_episodes
  config.vcr_cassette_dir = "spec/cassettes/qualspec"
end
```

### Environment-Based Mode

```ruby
# In spec_helper.rb
Qualspec::RSpec.configure do |config|
  config.record_mode = ENV["CI"] ? :none : :new_episodes
end
```

## Cassette Files

Cassettes are YAML files containing HTTP interactions:

```yaml
# .qualspec_cassettes/my_test.yml
---
http_interactions:
- request:
    method: post
    uri: https://openrouter.ai/api/v1/chat/completions
    body:
      string: '{"model":"google/gemini-2.5-flash","messages":[...]}'
    headers:
      Authorization:
      - Bearer <API_KEY>
  response:
    status:
      code: 200
    body:
      string: '{"choices":[{"message":{"content":"..."}}]}'
```

## Security

API keys are automatically filtered:

```ruby
# Keys are replaced with <API_KEY> in cassettes
config.filter_sensitive_data("<API_KEY>") { Qualspec.configuration.api_key }
```

## Request Matching

Requests are matched by:
- HTTP method
- URI
- Request body

This means the same prompt to the same model will replay the same response.

## Cassette Directory

### CLI

Cassettes are stored in `.qualspec_cassettes/` by default.

### RSpec

Configure the directory:

```ruby
Qualspec::RSpec.configure do |config|
  config.vcr_cassette_dir = "spec/fixtures/qualspec_cassettes"
end
```

## Best Practices

### 1. Commit Cassettes

Add cassettes to version control for reproducible CI:

```bash
git add .qualspec_cassettes/
git add spec/cassettes/qualspec/
```

### 2. Use Descriptive Names

```ruby
with_qualspec_cassette("greeting_friendly_response") { ... }
with_qualspec_cassette("safety_refuses_harmful") { ... }
```

### 3. Re-record Periodically

Models change over time. Re-record cassettes when:
- Updating model versions
- Changing prompts
- Debugging unexpected behavior

```bash
# Delete and re-record
rm .qualspec_cassettes/my_test.yml
qualspec --record my_test eval/suite.rb
```

### 4. Separate CI Cassettes

```ruby
# Different cassettes for different environments
cassette_name = "test_#{ENV['CI'] ? 'ci' : 'local'}"
with_qualspec_cassette(cassette_name) { ... }
```

## Troubleshooting

### "Real HTTP connections are disabled"

You're in playback mode but the request isn't recorded:

```bash
# Re-record the cassette
qualspec --record my_test eval/suite.rb
```

### Cassette Not Created

Check the cassette directory exists and is writable:

```bash
ls -la .qualspec_cassettes/
```

### Request Not Matching

VCR matches on method, URI, and body. If your request body changes (timestamps, random IDs), the cassette won't match. Consider filtering dynamic content.
