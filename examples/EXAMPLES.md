# Qualspec Examples

Runnable scripts that show different ways to use qualspec. Each one **records a
VCR cassette** to `examples/cassettes/`, so they replay for free — no API key,
no credits, no network:

```bash
bundle exec ruby examples/customer_service_comparison.rb
```

To run against the **live API** instead, delete the cassette and provide a key
(the examples read `OPEN_ROUTER_API_KEY` / `QUALSPEC_API_KEY`):

```bash
rm examples/cassettes/customer_service_comparison.yml
OPEN_ROUTER_API_KEY=sk-... bundle exec ruby examples/customer_service_comparison.rb
```

Cassettes are recorded with API keys filtered out (`<API_KEY>`). Models are
referenced by name from `config/models.yml` via `Qualspec.model(:name)`.

## The showcase

| Example | Use case | What it demonstrates |
|---------|----------|----------------------|
| [`customer_service_comparison.rb`](customer_service_comparison.rb) | Pick the best model for a support agent | Suite DSL, multi-candidate **comparative judging**, per-scenario winners, custom rubric |
| [`date_awareness_gate.rb`](date_awareness_gate.rb) | CI gate: fail if a model hallucinates | **Pass/fail thresholding** + non-zero exit code as a regression gate |
| [`best_value.rb`](best_value.rb) | "Is the pricey model worth it?" | **Cost tracking** (`track_cost`) and `value_ranking` — quality per dollar |
| [`character_consistency.rb`](character_consistency.rb) | Rank models on a multi-turn role-play | The **lower-level API** (`Qualspec.client` + `Qualspec.judge`) for multi-turn / agent evaluation |

## What each one shows

### `customer_service_comparison.rb` — compare models, find the best
Three models answer the same support scenarios (an angry refund demand, an
ambiguous discount question) under one system prompt. The judge compares them
head-to-head and declares a per-scenario winner. This is the core
"which model is best for this job?" workflow, driven entirely by the suite DSL
and a custom `Qualspec.define_rubric`.

### `date_awareness_gate.rb` — pass/fail gate for CI
A single criterion: a model should *not* confidently assert today's date (it has
no real-time clock). The script judges each model and **exits non-zero if any
fails**, so you can drop it into CI as a guard when swapping models. In the
recorded run, one model correctly declines while two confidently hallucinate a
date — the gate fails (exit 1), as intended.

### `best_value.rb` — best response per dollar
Enables `track_cost`, which makes qualspec request OpenRouter usage accounting
and capture real per-call cost. It then reports both the **quality winner** and
the **value winner** via `results.value_ranking` (avg score ÷ cost). The
recorded run shows a cheap model winning on value while the pro model costs
several times more for a marginal quality gain.

> Cost analysis requires `track_cost`. Calling `value_ranking` / `cost_by_candidate`
> without it raises a clear error telling you to enable it.

### `character_consistency.rb` — multi-turn ranking via the building blocks
The suite DSL is single-prompt per scenario, so evaluating a *conversation* drops
down to qualspec's primitives: `Qualspec.client.chat` with a running message
history to role-play a game NPC over several turns, then
`Qualspec.judge.evaluate_comparison` to rank the full transcripts on persona
consistency. A good template for vetting an agent or a new model with a custom
harness.

## Other examples in this directory

- `simple_variant_comparison.rb`, `variant_comparison.rb`,
  `prompt_variants_factory.rb` — the **variant + temperature matrix** feature
  (FactoryBot-backed prompt permutations).
- `rspec_example_spec.rb` — using qualspec **inside RSpec** (`qualspec_evaluate`,
  `qualspec_compare`, matchers, VCR).
- `comparison.rb`, `model_comparison.rb`, `persona_test.rb`, `quick_test.rb` —
  smaller/older one-off snippets.
