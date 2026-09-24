# Handoff 09 - Codex: mimo-preflight-review

Date: 2026-09-24 12:14 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from -Model; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: eb0f1e9e-4078-4d02-ac07-1bcc0e85320b.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-9967278d539f41ce820945ef0f4ec13f.md fork 01a0d2d6-057f-7cf3-98d5-cc9650495292 -` (prompt on stdin).
Parent thread: `01a0d2d6-057f-7cf3-98d5-cc9650495292`. Result thread: `01a0d2e9-072f-7f61-9934-d99b31fa6a86` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/07-claude-mimo-preflight-review.md` (sha256 ceb7883b95b2). Reviewed: 68353d7 + uncommitted, base 68353d756cbb581700a0be3d4338cd32a43a1950, tree sha256 99e8a3502a23, 23 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 388 s. Tokens: in 843196 (cached 162560), out 13025, reasoning 6889.
Verdict: HOLD - Unknown preflight states launch fail-open, and dead-credential outcomes are neither classified reliably nor carried into subsequent availability checks. Findings: 1 blocker, 2 major, 1 minor, 0 note (F09-1..F09-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/09-codex-mimo-preflight-review.reply.json`.
Raw event stream: `handoffs/09-codex-mimo-preflight-review.events.jsonl`.
Verbatim reply follows.

---

**Q1.** Locally the bridge can prove only credential-material presence and source: `codex login status` for OpenAI-style authentication, or a non-empty `env_key` variable/config bearer token. It cannot prove validity, expiry, remaining plan, revocation, or region. It can also infer negative health from prior local failures. The ledger should record provider fingerprint, model, credential source plus a salted credential hash, `preflight_state=present|missing|unknown`, and `observed_at`; request failures should add structured `provider_failure` records containing `class=auth|quota|capability|transport`, provider code, retry time, first/last seen, message hash and the event-log path. Preflight and `codex-providers.ps1` should surface that record. Today's free-text `preflight` and task-local regex warning do not prevent counting a dead credential twice.

**Q2.** I do not know Xiaomi MiMo Token Plan's exact production wording. Likely invalid-key responses contain `401`, `Unauthorized`, `invalid API key`, or `authentication_error`; exhaustion may say `quota`, `429`, or `insufficient balance`, which match. `credits exhausted`, `credit balance depleted`, `payment required`, `402`, or `token plan exhausted` are not guaranteed to match; invalid-key errors do not match at all.

**Q3.** The completed run writes a ledger entry whose `preflight` still says `ok: env MIMO_API_KEY set`; `bridge_outcome` becomes `failed: codex exit 1 - <last error message or last stderr line>`, `usage` is null, and `structured` is false. The pending record is removed. A later preflight warns only when that text matches the regex, is under one hour old, and has the exact provider name. An authentication rejection therefore produces no warning, so this is insufficient.

**Q4.** Verdict: **HOLD**. Blockers: finding #1; major gaps: findings #2 and #3. Unproven: exact MiMo credit/key error strings; whether Codex emits parseable `error`/`turn.failed` messages or only SSE text on stderr; actual subscription/plan validity. First run must show the requested `preflight`, lineage, `mimo-v1`, catalog `extra_config`, non-null usage, `bridge_outcome=usable reply`, and successful JSON ingestion.

## Requested checks
- RC1 (finding #3): from the repository root, workspace-write, 10 minutes: extend the PREFLIGHT fixture with `FAKE_CODEX_FAIL='401 Unauthorized: invalid API key'`, run two consultations, and observe that the second has no warning.
- RC2 (finding #1): from the repository root, workspace-write, 5 minutes: make fake `login status` fail to start or time out, run `codex-consult.ps1`, and observe whether Codex still launches.

---

### Findings

- **F09-1** [blocker] `plugins/codex-consult/scripts/codex-consult.ps1:532`, `plugins/codex-consult/scripts/codex-consult.ps1:544`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2484` - Preflight fails open when provider identity is unresolved or `codex login status` cannot run, so Codex can be called without proving that a credential exists. Trigger: Use a config selecting a profile or an unsupported provider override, or make `codex login status` unavailable or time out. Evidence: read-code: Only `missing` calls Stop-WithError; unresolved identity and `unknown` continue into launch.; read-code: Launcher/start failures and timeout return state `unknown` rather than unavailable. Verify: Run the bridge with a fake launcher whose `login status` subcommand hangs past the timeout and assert that no Codex consultation process starts without `-SkipPreflight`. Remedy: Fail closed on unknown unless `-SkipPreflight` is explicit; record the unknown reason before refusing.
- **F09-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:2522`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2532`, `plugins/codex-consult/scripts/codex-consult.ps1:1361` - `available` proves only that a non-empty credential variable exists; expired, revoked, wrong-region, and exhausted credentials remain reusable and later checks have no structured negative-health state. Trigger: Set `MIMO_API_KEY` to a syntactically non-empty invalid value and run twice after the provider rejects it. Evidence: read-code: Custom credentials are accepted solely by variable/token presence; history is searched only through regexed `bridge_outcome` text.; read-code: The ledger records `preflight` and `preflight_warning` but no credential identity or structured provider-health record. Verify: Run once with `MIMO_API_KEY=invalid`, then run a dry run and confirm it still reports `available (env MIMO_API_KEY set)` with no durable failure state. Remedy: Record credential source/hash and structured observed provider failures, and consume them in later preflights.
- **F09-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:2427`, `plugins/codex-consult/scripts/codex-consult.ps1:230`, `plugins/codex-consult/scripts/codex-consult.ps1:1180` - First-request authentication and MiMo credit failures are not reliably extracted or classified, so the next preflight may not warn. Trigger: The provider returns `401 Unauthorized: invalid API key`, `credits exhausted`, or an SSE `data:{"error":...}` payload rather than the two event shapes recognized. Evidence: read-code: The regex has no authentication, 401, credit, or payment terms.; read-code: Only top-level `error.message` and `turn.failed.error.message` are lifted; other error shapes fall back to one stderr line.; read-code: The real MiMo failure arrived as raw SSE-like `data:{"error":...}` text in `bridge_outcome`. Verify: Feed representative 401 and credit-exhaustion event/stderr fixtures through the failure path and require the next preflight to surface structured auth/credit warnings. Remedy: Parse more error shapes and maintain explicit provider-failure classifiers rather than one prose regex.
- **F09-4** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2540`, `plugins/codex-consult/scripts/codex-consult.ps1:758` - Availability history is keyed by exact provider alias and, for preflight warnings, only the current task, hiding failures of the same endpoint or shared credential. Trigger: A quota failure occurs under provider alias `mimo-token-plan`; the next call uses alias `mimo`, or another task in the repository observes the failure. Evidence: read-code: Entries are filtered with case-sensitive equality on `reviewer.provider`. Verify: Seed equivalent provider aliases with one failed ledger entry and verify that the other alias receives the warning. Remedy: Key health by provider fingerprint plus credential hash, while retaining the alias as provenance.

### Prior findings

- F02-4 - fixed - Effort caps now resolve by endpoint hostname and declared model; fixtures cover ZAI aliases and all MiMo hosts.
- F06-1 - fixed - Provider-set scan failures now prevent resolved builtin provenance; fixtures require unresolved identity and fork/resume refusal.
- F06-2 - fixed - Provider and model are compared separately; the a/b+c versus a+b/c fixtures refuse cross-identity reuse.
- F06-3 - fixed - Peak status is re-evaluated immediately before launch; the boundary fixture aborts without a child or ledger entry.
- F06-4 - fixed - The exception-range fixture covers 2026-01-01 through 2037-12-31 at 2037-01-01 and rejects only reversed ranges.

## Verdict: HOLD

Unknown preflight states launch fail-open, and dead-credential outcomes are neither classified reliably nor carried into subsequent availability checks.

### Blockers

- **F09-1** `plugins/codex-consult/scripts/codex-consult.ps1:532`, `plugins/codex-consult/scripts/codex-consult.ps1:544`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2484` - Preflight fails open when provider identity is unresolved or `codex login status` cannot run, so Codex can be called without proving that a credential exists. Verify: Run the bridge with a fake launcher whose `login status` subcommand hangs past the timeout and assert that no Codex consultation process starts without `-SkipPreflight`. Remedy: Fail closed on unknown unless `-SkipPreflight` is explicit; record the unknown reason before refusing.

### Unproven scenarios

- Exact Xiaomi MiMo Token Plan wording for exhausted credits and invalid keys.
- Whether every Codex/provider failure shape reaches `Get-ErrorFromEvents` in parseable form.
- Actual subscription, expiry, revocation, and endpoint-region validity without a network probe.

### First-run checklist (observable)

- [ ] Ledger `preflight` is exactly `ok: env MIMO_API_KEY set` and lineage is `mimo :: mimo-v2.6-pro`.
- [ ] `effort_mapping` is `mimo-v1` and `extra_config` contains `model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json"`.
- [ ] `usage` is non-null with route token counts, not unknown.
- [ ] `bridge_outcome` is `usable reply`, `structured` is true, and `validation_error` is empty.
- [ ] The reply is ingested as one JSON object and the verdict is recorded.
