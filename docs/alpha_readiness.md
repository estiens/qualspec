# Qualspec — Alpha Readiness Findings & Plan

_Assessment date: 2026-06-26. Status snapshot before first alpha use cases._

> **Update 2026-06-28 (v0.2.0):** Several items below are now DONE:
> - **Cost tracking fixed** (item 1) — now opt-in via `track_cost`; `Client` sends
>   `usage: {include: true}` and reads `usage.cost`. Verified live + unit-tested.
> - **API key configurable** — `Qualspec.configure { c.api_key = ... }` wins over
>   `QUALSPEC_API_KEY` → `OPEN_ROUTER_API_KEY` (resolved lazily at read time).
> - Added named model registry (`Qualspec.model`), `Recorder.use_cassette`, and a
>   `Configuration` spec. Test count is now 74.
> Still open: items 2–4 below (Client network-boundary spec, more pure units,
> RSpec-integration spec) and the consistency pass for `api_url`/`default_model`.

## TL;DR

- **Tests: green** — `bundle exec rake spec` → 44 examples, 0 failures. RuboCop clean except 10 cosmetic offenses.
- **No failing tests, no structural problems.** Architecture is clean (core / suite-DSL / rspec surfaces well separated).
- **One real dead-code bug:** cost tracking never fires.
- **~half of `lib/` has zero direct test coverage**, including the entire network boundary (`Client`) and the entire RSpec public surface.
- **Open integration question:** we run a custom OpenRouter gem — `Client` currently talks to `chat/completions` via raw Faraday. Need to decide whether `Client` should delegate to our gem and confirm cost/header shapes line up.

> Setup note: repo was locked to gems not installed for Ruby 3.4.9; ran `bundle install` to get green. Confirm alpha testers' Ruby matches `Gemfile.lock`.

---

## START HERE TOMORROW (ordered)

### 0. Custom OpenRouter gem sync (do first — it changes item 1)
The whole cost/metadata story depends on how our gem surfaces data, so resolve this before wiring cost.

- `lib/qualspec/client.rb` is a self-contained Faraday client posting to `chat/completions`. Decide:
  - **(a)** Keep `Client` as-is and just make sure our gem isn't double-wrapping requests, **or**
  - **(b)** Have `Client` delegate to our OpenRouter gem.
- Confirm the cost extraction in `Client#extract_cost` matches reality from our gem:
  - currently reads header `x-openrouter-cost`, then falls back to body `usage.total_cost` / `cost` (`client.rb:110-117`).
  - Verify our gem/endpoint actually returns one of these, and in what shape (header string vs. nested JSON).
- Confirm token extraction keys (`prompt_tokens`/`completion_tokens`/`total_tokens`, `client.rb:119-128`) match.
- Confirm auth headers (`config.api_headers`) and `response_format: { type: 'json_object' }` are honored by our endpoint (see item 4).

### 1. Fix cost tracking (dead code) — depends on item 0
**Bug:** `Candidate#generate_response` (`candidate.rb:22`) calls `Qualspec.client.chat(...)` **without** `with_metadata: true`, so `chat` always returns a `String`, never a `Client::Response`. Every `response.is_a?(Client::Response)` check in the runner (`runner.rb:72,82,83`) is permanently false. Result:
- `cost:` always `nil` → `Results#costs` always empty
- both reporters show cost as blank/`-` (`reporter.rb:147`, `html_reporter.rb:367`)
- the `Response#duration_ms` path is dead (runner's own monotonic timer feeds timing, so timing itself is fine)

**Fix:** thread `with_metadata: true` through `Candidate#generate_response` and have the runner consume the `Response` (cost + duration). Plumbing already exists in `Client#extract_cost`/`extract_tokens`. Alternative: remove the cost UI until wired. **Recommend wiring it.** (~30 min once item 0 is settled.)

### 2. Add a `Client` spec (highest real-world risk) — ~1 hr
The network boundary has **zero tests**. Use WebMock. Cover:
- success path returns content
- non-2xx → `Client::RequestError` (`handle_response`, `client.rb:85`)
- `with_metadata: true` → builds `Response` with cost/tokens/duration
- `extract_cost` header vs. body fallback
- `validate_api_key!` raises when unset, skips during VCR playback
- SSL toggle via `QUALSPEC_SSL_VERIFY=false`

### 3. Pure-unit specs (high coverage-per-effort) — ~1 hr
All currently untested, all pure/branchy:
- `Candidate#normalize_temperature` — Anthropic clamps 0–1, others 0–2 (`candidate.rb:33`)
- `Scenario#compose_prompt` / `compose_system_prompt` — priority merge `full_prompt > base_prompt > credential-prefix`; `variant > scenario > candidate` (`scenario.rb:60,84`)
- `VariantsConfig#build_variants` / `#trait_matrix` — cartesian product, name dedup, **FactoryBot-absent fallback** (`dsl.rb:100,111`)
- `PromptVariant` — `temperature=` range validation, `variant_key`, `customized?`, `to_h.compact` (`prompt_variant.rb:55,71`)

### 4. One RSpec-integration spec — ~30 min
Entire RSpec public surface (`helpers`, `matchers`, `evaluation_result`, `rspec/configuration`) is untested. Stub `Qualspec.judge`, exercise `qualspec_evaluate` + a couple matchers (`be_passing`, `have_score_above`). Also covers the symbol/string key fallback in `wrap_comparison_results` (`helpers.rb:143`).

### 5. Small cleanups / docs
- Drop duplicate `finish!` (called in `runner.rb:40` AND `qualspec.rb:81`).
- Document in README: **scoring is comparative for 2+ candidates, absolute for 1** (`runner.rb:125`) — single-candidate and multi-candidate scores are NOT apples-to-apples.
- `chmod +x` the two example files flagged by RuboCop.

---

## Full findings reference

### Bugs / behavior gaps
| # | Item | Location | Severity |
|---|------|----------|----------|
| 1 | Cost/metadata never captured (`with_metadata` never passed) | `candidate.rb:22` → `runner.rb:72,82,83` | **High** (dead feature) |
| 2 | `finish!` called twice | `runner.rb:40`, `qualspec.rb:81` | Low |
| 3 | Judge JSON-parse failure returns score 0 — indistinguishable from a genuinely bad response. Cross-provider endpoints that don't honor `json_object` will look like "model failed." | `judge.rb:162` | Medium (provider alpha) |
| 4 | Comparative (2+) vs absolute (1) scoring — cross-run scores not comparable | `runner.rb:125` | Doc note |

### Test coverage map
**Has coverage:** `Judge` (happy + error), `Results`/`Runner` aggregation, `HtmlReporter`, top-level registry methods.

**Zero coverage — ranked:**
- **High:** `Client` (network boundary); entire RSpec integration (`helpers`/`matchers`/`evaluation_result`/`rspec/configuration`); `VariantsConfig` (headline feature); `Scenario#compose_prompt`.
- **Medium:** `Candidate#normalize_temperature`; `PromptVariant` validation/keys; `Judge` untested branches (`winner: "tie"` `judge.rb:202`, `clamp(0,10)`, missing-candidate `judge.rb:190`).
- **Low:** `Reporter` (stdout/json); CLI `exe/qualspec` smoke test; `Recorder`; builtin rubric/behavior content.

### Effort estimate
Items 0–5 ≈ **half a day to a day**. Items 1–4 take coverage from ~half to most of the meaningful surface and close the one real bug.
