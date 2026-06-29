# Changelog

## [0.2.0] - 2026-06-28

### Added

- **Named model registry** — curated models in `config/models.yml`, resolved via
  `Qualspec.model(:name)` / `Qualspec.models`. Unknown/blank names fall back to
  the default. Override the file with `QUALSPEC_MODELS_FILE`.
- **Cost tracking (opt-in)** — `track_cost` in the suite DSL captures per-call
  cost + tokens via OpenRouter usage accounting. `Results#value_ranking` and
  `Results#cost_by_candidate` expose quality-per-dollar analysis (and raise a
  helpful error if cost tracking wasn't enabled).
- `Recorder.use_cassette` — replays an existing cassette (no API key needed),
  records a fresh one when missing. Used by the new examples.
- API key is now configurable via `Qualspec.configure { |c| c.api_key = ... }`,
  falling back to `QUALSPEC_API_KEY` then `OPEN_ROUTER_API_KEY`.
- New runnable examples: `customer_service_comparison`, `date_awareness_gate`,
  `best_value`, `character_consistency` — each ships a committed VCR cassette.

### Changed

- Default model is now `openrouter/auto` (was `google/gemini-3-flash-preview`),
  so qualspec works with nothing configured.
- `candidate` no longer requires `model:` — it defaults to the configured model.
- `Client#chat` requests usage accounting and reads cost from `usage.cost` when
  `with_metadata: true` (previously cost was never captured).

### Fixed

- Cost data was never populated (metadata was never requested); cost reporting
  now works when `track_cost` is enabled.

## [0.1.0] - 2025-12-26

### Added

- **FactoryBot integration** for multi-dimensional prompt variant testing
- `PromptVariant` class as target for FactoryBot factories
- `variants` DSL block with `trait_matrix` for combinatorial testing
- `temperatures` DSL block for testing across temperature ranges
- Temperature validation (0.0-2.0 range) with clear error messages
- Variant summary section in reporter output
- Detailed responses section showing prompts, credentials, timing per call
- `variant_key` in PromptVariant#to_h for easier result correlation

### Changed

- Runner now iterates: scenarios × variants × temperatures × candidates
- Results include `scores_by_variant` and `scores_by_temperature` aggregations
- Candidate#generate_response accepts temperature parameter
- Client#chat accepts temperature parameter

### Fixed

- FactoryBot availability check now uses `respond_to?(:build)` for robustness
- Credential checks use `.to_s.strip` to handle non-string values
- Progress output clears line properly after completion
- Variant names deduplicated when using both explicit and matrix definitions

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
