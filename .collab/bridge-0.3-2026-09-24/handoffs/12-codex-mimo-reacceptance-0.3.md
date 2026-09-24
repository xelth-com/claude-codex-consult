# Handoff 12 - Codex: mimo-reacceptance-0.3

Date: 2026-09-24 12:55 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from -Model; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 06bc1a8d-c17c-4b49-852f-05ad518893a2.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-f90e7d63bb4c4e048c9c4016a0d2cd09.md fork 01a0d2e9-072f-7f61-9934-d99b31fa6a86 -` (prompt on stdin).
Parent thread: `01a0d2e9-072f-7f61-9934-d99b31fa6a86`. Result thread: `01a0d30e-4128-77d1-bc53-c0d8bd5df63b` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/10-claude-reacceptance-0.3.md` (sha256 e5157afbc0bd). Reviewed: 68353d7 + uncommitted, base 68353d756cbb581700a0be3d4338cd32a43a1950, tree sha256 4bd375344489, 23 changed files.
Bridge outcome: usable reply. Wall time: 276.5 s. Tokens: in 1732720 (cached 552704), out 22385, reasoning 11861.
Verdict: ACCEPT - All nine prior defects are addressed by focused implementation and fixtures, with no remaining acceptance blocker; the residuals are non-blocking preflight ergonomics and classifier precision. Findings: 0 blocker, 0 major, 2 minor, 0 note (F12-1..F12-2, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/12-codex-mimo-reacceptance-0.3.reply.json`.
Raw event stream: `handoffs/12-codex-mimo-reacceptance-0.3.events.jsonl`.
Verbatim reply follows.

---

**Q1.**

- **F06-1: fixed.** `Get-ProviderSetProblem` rejects hidden or unsupported declarations at `model_providers` and `model_providers.openai`; `Resolve-ReviewerIdentity` then leaves identity unresolved instead of claiming builtin provenance. The harness covers inline, dotted, multi-line and deep-dotted forms plus fork/resume refusal.
- **F06-2: fixed.** `Test-SameReviewer` compares provider and model separately and parent selection also requires the endpoint fingerprint. The `a/b :: c` versus `a :: b/c` fixtures refuse both automatic and explicit cross-identity reuse.
- **F06-3: fixed.** Peak status is recomputed immediately before `Start-Process`; `-OffPeakOnly` aborts at that point and removes the reservation. The controlled-clock boundary fixture proves no child or ledger entry is produced.
- **F06-4: fixed.** Exception intervals are compared directly rather than iterated with a day guard. The 2026-01-01..2037-12-31 fixture evaluates correctly at 2037-01-01 and only reversed ranges fail.
- **F02-4: fixed.** `caps-v1` keys capabilities by canonical endpoint host and exact declared model, not provider alias. ZAI/Z.ai aliases and all MiMo hosts have matching preset mapping fixtures; undeclared combinations refuse unless `-NativeEffort` is explicit.
- **F09-1: fixed.** Unresolved identity and failed or timed-out `login status` now refuse before launch unless `-SkipPreflight`. Fixtures require no Codex child, pending file or ledger entry.
- **F09-2: fixed.** Failed runs record `provider_failure`; endpoint health consumes it and a later dry run reports the endpoint unavailable after an auth failure. Credential rotation residual is finding #1, not the original missing-health-state claim.
- **F09-3: fixed.** SSE `data:{"error":...}` payloads are parsed and failures are classified into auth/quota/capability/transport/unknown. Fixtures cover invalid keys, credit exhaustion and the real MiMo json_schema rejection.
- **F09-4: fixed.** `Get-EndpointHealth` reads every task ledger and keys results by `provider_fingerprint`, so aliases share health. Cross-alias, cross-task auth/quota fixtures exercise refusal and warning behavior.

**Q2.** A legitimate credential-free endpoint is blocked: for example `[model_providers.local] base_url = "http://localhost:8080/v1"` with neither `env_key` nor a bearer token. `Get-ProviderCredential` reports `missing: no env_key/bearer token in the table`. There is no `auth_mode=none` declaration or narrow anonymous-access option; the only documented route is `-SkipPreflight`, which bypasses all refusals. The same broad bypass is required after rotating a credential that previously failed authentication.

**Q3.** Verdict: **ACCEPT**. Blockers: none. Finding #1 is a minor usability gap and finding #2 a minor classification risk; neither invalidates provenance, availability refusal or ledger integrity. Unproven: live subscription/plan validity; production error variants beyond the fixtures; independent rerun of the claimed PowerShell 5.1 and 7.6 suites; behavior when another task's ledger is corrupt and silently omitted from health.

## Requested checks
- RC1 (finding #1): repository root, workspace-write, 5 minutes: run a fixture provider with no credential declaration and confirm whether any non-`-SkipPreflight` route exists.
- RC2 (acceptance invariant): repository root, workspace-write, 20 minutes: run `powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-all.ps1` and require every harness to report zero failures.

---

### Findings

- **F12-1** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2424`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2526`, `plugins/codex-consult/scripts/codex-consult.ps1:574`, `README.md:654` - The fail-closed preflight has no narrow declaration for anonymous endpoints or one-time retry with a rotated credential; both legitimate cases require `-SkipPreflight`, which bypasses every refusal together. Trigger: Use a local provider with no `env_key`/bearer token, or rotate an API key less than 24 hours after an auth failure on the same endpoint fingerprint. Evidence: read-code: A provider without credential material is classified missing; no anonymous-auth mode exists.; read-code: Both credential-free endpoints and rotated credentials are documented as requiring `-SkipPreflight`. Verify: Configure `base_url=http://localhost:8080/v1` with no credentials and search the CLI/config surface for any accepted authentication-mode declaration besides `-SkipPreflight`. Remedy: Add a provider declaration such as `auth_mode="none"` and a one-shot `-RetryCredential`/failure override that records why the old health state was bypassed.
- **F12-2** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2530`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2539` - Failure classification checks broad quota/auth phrases before capability terms, so provider messages containing `token plan`, `billing`, or `auth` can be misclassified and create false warnings or auth refusals. Trigger: A capability error says `Your token plan does not support response_format`, or unrelated text contains `authored`. Evidence: read-code: `quota` includes `token plan|billing` and is evaluated before `capability`; `auth` matches the unanchored fragment `auth`. Verify: Pass both sample messages to `Get-ProviderFailureClass`; the first currently returns quota and the second auth rather than capability/unknown. Remedy: Classify structured provider codes first, prioritize explicit capability phrases, and anchor sensitive auth/billing patterns.

### Prior findings

- F06-1 - fixed - Unsupported provider-set declarations now force unresolved identity; fixtures cover both requested override forms and fork/resume refusal.
- F06-2 - fixed - Provider and model are compared separately with endpoint fingerprint; ambiguous-lineage cross-reuse fixtures pass.
- F06-3 - fixed - Peak is re-evaluated immediately before launch and the boundary fixture prevents OffPeakOnly launch.
- F06-4 - fixed - Long exception intervals are evaluated directly; the 2026-2037 and 8000-year fixtures cover the old truncation.
- F02-4 - fixed - caps-v1 maps by endpoint host and exact model; alias, preset and MiMo-host fixtures cover the prior claim.
- F09-1 - fixed - Unknown availability now refuses before launch; hang and unresolved-identity fixtures prove fail-closed behavior.
- F09-2 - fixed - Structured provider failures and endpoint health now persist and affect subsequent preflights.
- F09-3 - fixed - SSE and event/stderr failures are parsed and classified, including invalid-key and credit-exhaustion samples.
- F09-4 - fixed - Health is read across all task ledgers and keyed by endpoint fingerprint, covering alias and cross-task propagation.

## Verdict: ACCEPT

All nine prior defects are addressed by focused implementation and fixtures, with no remaining acceptance blocker; the residuals are non-blocking preflight ergonomics and classifier precision.

### Blockers

_(none)_

### Unproven scenarios

- Actual subscription, expiry, revocation, billing and endpoint-region validity without network probes.
- Provider error wording outside the representative fixtures, especially MiMo plan exhaustion variants.
- Independent execution results for PowerShell 5.1 and PowerShell 7.6 harnesses.
- Whether silently skipped corrupt task ledgers can hide a recent endpoint auth failure.

### First-run checklist (observable)

- [ ] Console and ledger show `preflight` available from `codex login status`, with any endpoint-health warning preserved.
- [ ] The ledger records `mode=resume`, `parent_thread=01a0d28a-804b-7672-930f-92c70d35a165`, lineage `openai :: gpt-6-astra`, and the matching builtin provider fingerprint with no drift warning.
- [ ] `effort_mapping` is `openai`, `effort_sent` is `high`, and `effort_confirmed` remains null.
- [ ] `bridge_outcome` is `usable reply`, `provider_failure` is null, `schema_transport` is `output-schema`, `structured` is true, and `validation_error` is empty.
- [ ] The parsed reply reports all nine prior ids F06-1..4, F02-4 and F09-1..4 with their final statuses, and any new finding is ingested.
- [ ] `usage` is non-null and exit code 0 is observed only after JSON/schema validation and ledger persistence.
