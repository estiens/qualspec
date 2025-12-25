# Changelog

## [0.0.1] - 2025-12-25

Initial release.

### Features

- DSL for defining evaluation suites to compare LLM responses
- RSpec integration with custom matchers (`be_passing`, `have_score_above`, etc.)
- LLM-as-judge scoring system (0-10 scale)
- Built-in rubrics: `tool_calling`, `helpful`, `concise`, `in_character`, `safety`, and more
- Shared behaviors for reusable test scenarios
- VCR-based recording/playback for deterministic tests
- HTML and JSON report generation
- OpenRouter API support with configurable models
