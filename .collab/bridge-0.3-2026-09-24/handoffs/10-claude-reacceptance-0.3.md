# Handoff 10 - Claude: re-acceptance of codex-consult 0.3.0 after waves 6-9

Date: 2026-09-24. Base commit: `68353d7` (tag `v0.2.0`) + uncommitted 0.3.0 work. This consultation is a
`resume` of your acceptance thread - the first resume under the 0.3.0 provenance rules (lineage
`openai :: gpt-6-astra`, builtin fingerprint, matched by provider and model separately).

## Question

Can 0.3.0 be accepted now? Your HOLD (handoff 06) named F06-1, F06-2 (blockers), F06-3, F06-4 and left
F02-4 open; all were reproduced and fixed. Since then two more waves came from the operator's requirement
and from the third reviewer's live review. Report F06-1..F06-4, F02-4 and F09-1..F09-4 in `prior_findings`.

## Delta since the last review

Follows: `handoffs/06-codex-acceptance-0.3.md` (HOLD).

- **F06-1**: the builtin openai identity is used only when the scanner can establish that no
  `model_providers.openai` declaration exists: an unsupported construct at `model_providers` itself, an
  `openai` entry inside `[model_providers]`, or anything unsupported below `model_providers.openai` ->
  identity unresolved (note names the construct and line), fork/resume refused, `new` allowed;
  unsupported constructs under other providers do not affect openai.
- **F06-2**: every parent-selection path compares `reviewer.provider` and `reviewer.model` separately
  (ordinal) plus the fingerprint; `lineage` is display only and now reads `<provider> :: <model>`.
- **F06-3**: peak is re-evaluated immediately before `Start-Process`; that result and `peak_evaluated_at`
  go to the ledger; under `-OffPeakOnly` a peak result at launch withdraws the reservation, starts nothing
  and writes no ledger entry. Test hook `CODEX_CONSULT_NOW` (comma-separated timestamps used in order).
- **F06-4**: exception ranges are evaluated as intervals of any length; only end < start is refused.
- **F02-4**: declared capability table `caps-v1` (`effort_caps` in the ledger): builtin openai (no user
  table, no `OPENAI_BASE_URL`) -> any model; z.ai hosts -> vocabulary zai for eleven declared GLM models;
  MiMo hosts -> vocabulary mimo (none|low|medium|high, `mimo-v1`, xhigh->high) for five declared models;
  everything else needs `-NativeEffort`; the model-prefix rule is gone.
- **Wave 6 (operator rule: never call or plan on a model whose subscription cannot be established)**:
  `codex-providers.ps1` (verdict per provider from credentials, table usability, caps, endpoint health;
  exit 0/2/3) and an in-bridge preflight before the lock (`preflight`, `preflight_warning` in the ledger,
  `-SkipPreflight`).
- **Wave 8**: `schema_transport` per host in caps-v1 - `output-schema` for builtin and z.ai, `prompt-only`
  for MiMo and any undeclared host (no `--output-schema`; the schema file appended to the prompt; the reply
  parsed leniently and validated locally). Found by the first MiMo run: its endpoint rejects json_schema.
- **Wave 9 (third reviewer's findings F09-1..4)**: preflight FAILS CLOSED on `unknown` unless
  `-SkipPreflight`; provider failures classified (`provider_failure {class auth|quota|capability|
  transport|unknown, code, message, when}`, SSE `data:{"error":...}` payloads parsed); endpoint health read
  across ALL task ledgers keyed by the endpoint fingerprint (newest wins): an auth failure within 24 h ->
  unavailable / refused ("if you rotated the credential, pass -SkipPreflight once"), quota within 60 min ->
  warning.
- **`-CodexConfig`**: extra `-c` items (tilde expanded, non-literals quoted, identity keys refused,
  ledger `extra_config`) - needed because a global `model_catalog_json` replaces Codex's catalog.
- `tests/` at the repo root: `run-all.ps1`, five harnesses, fake shims; 5.1: harness-0.3 226/226,
  pending 26, fixes 45, lock2 11, 3b 12; pwsh 7.6: harness-0.3 226/226.

## CURRENT invariants claimed

- All 0.2.0 invariants; the ledger names the provider and model Codex used or says unknown; a thread never
  changes provider, model, endpoint or protocol; unknown provenance is never reused; no model is launched
  without an established credential (or an explicit `-SkipPreflight`); the bridge makes no HTTP call.

## Live evidence

- `handoffs/04` (GLM, z.ai route): plain-Markdown reply kept, no verdict - the degradation path.
- `handoffs/08` (MiMo, first attempt): endpoint rejected `--output-schema`; error lifted into
  `bridge_outcome`, no findings, pending cleared - the failure path.
- `handoffs/09` (MiMo, after wave 8): `prompt-only` transport, BARE JSON reply validated, HOLD with
  F09-1..4 ingested, five prior ids reported fixed, `mode fork` of its own lineage, usage from the MiMo route,
  preflight `ok: env MIMO_API_KEY set`, `extra_config` with the expanded catalog path.
- `codex-providers.ps1` on the real config: openai, ZAI and mimo `available` (with the key in the
  environment); without it, mimo `unavailable (missing: env MIMO_API_KEY not set)`.

## Open findings

F06-1..F06-4, F02-4, F09-1..F09-4 - `implemented`; F02-1/3/5 `verified`; F02-2/9 `superseded`; F02-6/7/8
`wontfix` (R9 deferred).

## Questions

- **Q1.** For each of F06-1..4, F02-4, F09-1..4: fixed, still-open or not-checked, with the concrete gap if
  still-open. Read `Resolve-ReviewerIdentity`, `Get-ProviderSetProblem`, `Select-ParentThread` (or the
  parent-selection block), `Get-PeakStatus`, `Resolve-EffortPlan`, the preflight and health functions
  (`Get-EndpointHealth`, `Get-ProviderFailureClass`), and the run section of `codex-consult.ps1`.
- **Q2.** The fail-closed preflight refuses on `unknown`. Name a legitimate setup this now blocks without a
  documented way out other than `-SkipPreflight`.
- **Q3.** Verdict on 0.3.0: ACCEPT, HOLD or REJECT, with blockers, unproven scenarios and the observable
  first-run checklist for this consultation (`resume`, parent = your acceptance thread, nine prior ids).

Answer by number. Keep it under 800 words.
