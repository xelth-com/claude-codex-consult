# Handoff 07 - Claude: diff review of the availability preflight, for the third reviewer (MiMo)

Date: 2026-09-24. Base commit: `68353d7` (tag `v0.2.0`) + uncommitted 0.3.0 work. You are consulted through
the bridge with `-Provider mimo -Model mimo-v2.6-pro -CodexConfig model_catalog_json=...` - the first
consultation on your route, in your own lineage `mimo :: mimo-v2.6-pro`.

## Question

An adversarial read of the new availability preflight: the operator's rule is "the bridge must detect by
itself whether a subscription/credential for a model exists; if not, neither call nor count on it". Does
the implementation satisfy that rule, and where does it fail silently?

## What to read

- `plugins/codex-consult/scripts/codex-providers.ps1` (new): lists the builtin `openai` and every
  `[model_providers.*]` table of the Codex config with a verdict available / unavailable / unknown from
  credentials only (builtin: `codex login status`; custom: the table's `env_key` variable or a bearer token
  in the table), table usability, effort vocabulary (`caps-v1`), and the newest usage-limit failure found in
  this repository's ledgers within 24 h. Exit codes with `-Provider`: 0 available, 2 unavailable, 3 unknown.
  No network call, no lock, writes nothing.
- `plugins/codex-consult/scripts/codex-consult.ps1`, the preflight block (search `preflight`): the same
  check after identity/effort resolution and before the peak check and the lock; missing credentials ->
  refusal, nothing started, no ledger entry; `-SkipPreflight` bypasses (recorded); a usage limit hit within
  the last hour on this task -> warning only; a `login status` that cannot run -> `unknown`, not refused.
- `plugins/codex-consult/scripts/codex-consult-common.ps1`, section "provider availability".

## Questions (answer by number, under 600 words)

- **Q1.** A credential can exist and still be worthless (expired key, exhausted plan, revoked token, wrong
  endpoint region). Without any network call, what can the bridge still infer, and what should it record
  so the coordinator does not "count on" a dead provider twice? Be concrete about the ledger.
- **Q2.** The usage-limit scan matches `bridge_outcome` text against a regex (usage limit | quota | rate
  limit | 429 | insufficient balance | too many requests). For your route (Xiaomi MiMo Token Plan): what do
  the error messages look like when credits run out or the key is invalid, so the regex catches them?
  If you do not know exactly, say so.
- **Q3.** Sequence: preflight ok -> lock -> pending record -> codex starts -> the provider rejects the key at
  the first request. What does the bridge record today (read the failure path: `error` / `turn.failed`
  events lifted into `bridge_outcome`), and is that enough for the next preflight to warn?
- **Q4.** Verdict (ACCEPT/HOLD/REJECT) on the preflight as a diff, with blockers, unproven scenarios and the
  first-run checklist for THIS consultation (ledger: `preflight "ok: env MIMO_API_KEY set"`, lineage
  `mimo :: mimo-v2.6-pro`, `effort_mapping mimo-v1`, `extra_config` with the catalog path, `usage` from
  your route; reply parsed as JSON if you return the object).

Please return the JSON object described in the instructions (schema v1) - your previous route (GLM) returned
plain Markdown, which the bridge keeps but cannot ingest as findings.
