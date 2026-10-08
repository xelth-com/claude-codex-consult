# Handoff 21 - Codex: ab-05-codex

Date: 2026-10-08 02:49 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 540deac1-f1fd-4df2-8566-4b1acccb1875.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-e8c6db4aa2514c988edcac5e7cdeddc4.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118fc-7875-7ac2-8b1d-e6c2d4904d1d` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md` (sha256 08f0b7610c02). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 574.2 s. Tokens: in 747117 (cached 98304), out 13506, reasoning 7373.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The current preflight is stronger than the stale brief, but unrecognized provider failures can still leave a dead endpoint available. Findings: 0 blocker, 1 major, 1 minor, 1 note (F21-1..F21-3, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/21-codex-ab-05-codex.reply.json`.
Raw event stream: `handoffs/21-codex-ab-05-codex.events.jsonl`.
Verbatim reply follows.

---

## Q1
The bridge can infer only local credential presence/shape (`MIMO_API_KEY` set, table usability, `caps-v1`) and prior endpoint behavior keyed by `reviewer.provider_fingerprint`; it cannot prove plan value, revocation, or region. The ledger should retain `preflight` with its evidence source/check time and, after failures, `bridge_outcome` plus `provider_failure {class, code, kind, when, retry_after, message}`. Current entries do this after a run (`codex-consult.ps1:5957-6043`); a structured `credential_probe` would also record that local presence is not proof of value.

## Q2
I do not know Xiaomi MiMo Token Plan's exact rejection strings; this tree contains no MiMo failure fixture. The current classifier catches `usage limit`, quota, rate limit, 429, insufficient balance, too many requests, `credits exhausted`, `credit balance`, `payment required`, `402`, `token plan`, `plan exhausted`, `billing`, and `resource_exhausted` (`codex-consult-common.ps1:5748-5753`). Invalid keys should match 401/403, `invalid api key`, unauthorized, or auth wording. A novel phrase without such text/status becomes `unknown`. The brief's single `bridge_outcome` regex is stale: `provider_failure` is primary and `bridge_outcome` is the older fallback.

## Q3
`Get-ErrorFromEvents` lifts `error`/`turn.failed` messages (`codex-consult.ps1:1586-1608`). The failure path then records `bridge_outcome: failed...` and `provider_failure` from SSE, event error, stderr, and outcome (`5549-5565`, `6029-6030`). If classified `auth`, the next preflight refuses for 24 hours with `auth failed`, rather than merely warning; quota refuses until reset, 60 minutes, or 10 for a burst. Thus it is sufficient for recognized auth errors, not unrecognized ones (finding #1).

## Q4
**HOLD.** Missing credentials and recognized auth/quota failures satisfy the operator rule. Blocker to accepting the evidence: MiMo-specific rejection wording is unverified, and `unknown` provider failures do not affect endpoint health (finding #1). The brief is also stale about warning-only limits and its scan (finding #2), and its v0.2.0 framing no longer describes `v0.6.0-1-g65380b2` (finding #3).

Unproven: exact MiMo exhausted-credit/invalid-key strings; expired, revoked, or wrong-region credentials before a run; whether `-SkipPreflight` after rotation clears recorded auth state.

First run checklist: `Preflight: ok: env MIMO_API_KEY set` with no warning/refusal; ledger `lineage` `mimo :: mimo-v2.6-pro`, `effort_mapping` `mimo-v1`, `extra_config` containing the catalog path and its source, and non-null route `usage`; valid structured JSON with `bridge_outcome` `usable reply` and exit 0.

## Requested checks
- **RC1** (finding #1): from `C:\Users\Dmytro\cc-ab-mimo`, workspace-write plus network/MiMo credentials, run `codex-consult.ps1` once with an invalid `MIMO_API_KEY` and once against an exhausted Token Plan, then run `-DryRun`; observe exact `provider_failure` messages and whether the second preflight refuses or remains available. Budget: 15 minutes.
- **RC2** (finding #2): from `C:\Users\Dmytro\cc-ab-mimo`, workspace-write, run `tests/harness-visibility.ps1` after adding one fake `turn.failed` case with a novel MiMo rejection phrase; observe its class and the following preflight verdict. Budget: 10 minutes.

---

### Findings

- **F21-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5758`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6312`, `plugins/codex-consult/scripts/codex-consult-common.ps1:7803` - An endpoint rejection whose wording yields provider_failure class `unknown` is recorded but never affects endpoint health: Get-EndpointHealth promotes only auth and quota records and Get-PreflightVerdict reads only those states. The next preflight can therefore return available and the coordinator can count on a dead MiMo provider again. No route-specific MiMo rejection fixture exists to prove the classifier covers its exhausted-credit or invalid-key messages. Trigger: A MiMo Token Plan rejection whose message has no recognized auth/quota/status wording, for example `invalid credential` without a 401/403 marker. Evidence: read-code: Get-ProviderFailureClass returns `unknown` for unmatched text; Get-EndpointHealth builds Auth/Quota only; Get-PreflightVerdict gates only credential, Auth, and Quota.; ran-command: No MiMo-specific exhausted-credit or invalid-key fixture/message was found. Verify: RC1 or RC2: emit a novel MiMo rejection through a fake turn, inspect provider_failure.class, then run a second preflight and observe whether it is still available. Remedy: Record route-specific MiMo rejection fixtures, extend auth/quota classification from observed codes/messages, and make a first-turn provider rejection without a usable classification produce `unknown` availability or a short fail-closed cooldown instead of remaining available.
- **F21-2** [minor] `.collab/ab-mimo-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md:25`, `.collab/ab-mimo-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md:36`, `plugins/codex-consult/scripts/codex-consult.ps1:3615`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5748` - The brief's preflight description is stale: a recent usage limit is no longer warning-only; recorded auth and blocking quota failures refuse the run unless -SkipPreflight. The scan is also no longer only a bridge_outcome regex: structured provider_failure is primary, its quota/auth patterns are broader, and bridge_outcome is the fallback for older entries. Trigger: Comparing brief lines 25-28 and 36-38 with the current preflight and failure classifier. Evidence: read-code: Comments and code say recorded auth and usage limits refuse, with -SkipPreflight as the override.; read-code: provider_failure is classified first with broader auth/quota patterns; older entries fall back to bridge_outcome. Verify: Seed a ledger quota failure without reset, run codex-consult.ps1 without -SkipPreflight, and observe refusal rather than warning-only behavior. Remedy: Update the brief to describe fail-closed auth/quota refusals and the provider_failure-first classifier.
- **F21-3** [note] `.collab/ab-mimo-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md:7`, `.collab/ab-mimo-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md:19` - The brief's base `68353d7` (v0.2.0) plus uncommitted 0.3.0 framing and description of codex-providers.ps1 as new do not describe the current tree, which is v0.6.0-1-g65380b2 and includes later roster, plan, burst-limit, and engine behavior. Trigger: Treating the brief's commit framing as the reviewed state. Evidence: ran-command: HEAD was 65380b2 `ab: the 12 briefs of wave 29c for plan mimo`, described as v0.6.0-1-g65380b2.; read-code: The current help documents roster/plan, burst limits, and agy/muse/claude engine rows beyond the brief's 0.3.0 description. Verify: Run `git describe --tags --always --dirty` from the repository root and compare it with brief line 7. Remedy: Re-frame the handoff on the current release and current codex-providers behavior.

### Prior findings

- F13-1 - still-open - No fix evidence in this checkpoint; not refiled.
- F13-2 - still-open - No fix evidence in this checkpoint; not refiled.
- F13-3 - still-open - No fix evidence in this checkpoint; not refiled.
- F13-4 - still-open - No fix evidence in this checkpoint; not refiled.
- F13-5 - still-open - The same claim-versus-tree drift class remains relevant; not refiled.
- F15-1 - still-open - No fix evidence in this checkpoint; not refiled.
- F15-2 - still-open - No fix evidence in this checkpoint; not refiled.
- F15-3 - still-open - No fix evidence in this checkpoint; not refiled.
- F18-1 - still-open - No fix evidence in this checkpoint; not refiled.
- F18-2 - still-open - A fresh dual-host suite result is still absent; not refiled.
- F20-1 - still-open - No fix evidence in this checkpoint; not refiled.
- F20-2 - still-open - No fix evidence in this checkpoint; not refiled.
- F20-3 - still-open - Stale commit framing remains the same drift class; not refiled.
- F20-4 - still-open - No fix evidence in this checkpoint; not refiled.
- F20-5 - still-open - No fix evidence in this checkpoint; not refiled.

## Verdict: ADVISE

The current preflight is stronger than the stale brief, but unrecognized provider failures can still leave a dead endpoint available.

### Blockers

_(none)_

### Unproven scenarios

- Exact Xiaomi MiMo Token Plan messages for exhausted credits and invalid or revoked keys.
- Whether expired, revoked, or wrong-region credentials can be detected before the first request without a network probe.
- Whether every listed prior finding remains open; their race and suite verification procedures were not rerun in this read-only checkpoint.

### First-run checklist (observable)

_(none)_
