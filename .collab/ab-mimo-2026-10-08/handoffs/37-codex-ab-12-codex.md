# Handoff 37 - Codex: ab-12-codex

Date: 2026-10-08 10:17 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 84b03b51-8655-405a-8ca5-7ec02b73ad59.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-c1d03abf64ba46f5bf656ebdbfe65a84.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a11a96-c78b-7963-b71b-7764add6199b` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/12-claude-ab-glm-diff-review.md` (sha256 f1a6117ca5bc). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 498.1 s. Tokens: in 1115226 (cached 245760), out 17539, reasoning 12334.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - ADVISE per the output contract; the diff itself should be HOLD until the identity and z.ai effort/schema claims are corrected or proven. Findings: 0 blocker, 1 major, 0 minor, 0 note (F37-1, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/37-codex-ab-12-codex.reply.json`.
Raw event stream: `handoffs/37-codex-ab-12-codex.events.jsonl`.
Verbatim reply follows.

---

## Current invariant drift
The brief is stale: base 68353d7/0.3.0 and ZAI/glm-5.3 do not describe this tree (v0.6.0-1-g65380b2) or this MiMo run.

**Q1.** Yes. `Resolve-ReviewerIdentity` treats a readable top-level `profile` as a note but still fills provider/model from `-Provider`/`-Model` or unprofiled `model_provider`/`model`; Codex may run the profile while the ledger records the unprofiled identity. A user-defined `[model_providers.openai]` table is also marked resolved although Codex may ignore it. These record wrong identity, not `unknown` (F36-1/F36-2).

**Q2.** No cross-lineage fork/resume sequence found. `Select-ParentThread`/`Find-ThreadEntry` require exact provider, model, engine and fingerprint; legacy, unresolved and rollout candidates are never automatic parents. The non-codex `partial_reply` exception is still lineage-checked.

**Q3.** `zai-v1` maps `medium->high`, `xhigh->max`; the codex path sends `-c model_reasoning_effort=...`, and `-NativeEffort` bypasses mapping. The harness proves only mapping and command construction. Nothing proves GLM-5.3 accepts or applies those values. `effort_confirmed` is always `$null`, so an ignored value is invisible; a rejected value can still fail the run.

**Q4.** I received the output schema and the final `Consultation id:` line. No explicit effort value was visible in the prompt. The bridge should record route-side proof that effort was accepted/applied and whether `--output-schema` was enforced; today it records `effort_sent`, `effort_confirmed=null` and `schema_transport` only.

**Q5.** Diff verdict: **HOLD**. Blockers: the two wrong-identity paths above and unverified z.ai effort/schema behavior. Unproven: profile merge semantics, z.ai wire acceptance/application of effort, and schema enforcement. First-run check: a ledger entry for `84b03b51-8655-405a-8ca5-7ec02b73ad59` with the actual lineage/engine, `effort_requested/sent/mapping`, `schema_transport`, `usage`, `thread_source`, and a reply object parsed and validated against `consult-reply v1`; if the intended run is truly ZAI/glm-5.3, require `ZAI :: glm-5.3`, `effort_mapping zai-v1`, and z.ai usage instead.

## Requested checks
- **RC1** (workspace-write, 10 min): run one real `ZAI/glm-5.3` consultation with `-Effort medium` and one with `-Effort xhigh`; inspect the ledger/route response for accepted/applied `model_reasoning_effort`, `usage`, and schema enforcement. Settles finding #1.

---

### Findings

- **F37-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:2755`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2790`, `plugins/codex-consult/scripts/codex-consult.ps1:4239`, `plugins/codex-consult/scripts/codex-consult.ps1:4335` - The zai-v1 effort mapping and output-schema route are declared and sent, but the bridge has no evidence that GLM-5.3 accepts or applies `medium->high` or `xhigh->max`, and it cannot distinguish an ignored effort setting from an applied one because `effort_confirmed` is always null; schema enforcement is likewise not recorded. Trigger: A real ZAI/glm-5.3 run using -Effort medium or -Effort xhigh. Evidence: read-code: zai-v1 is declared with medium->high and xhigh->max, and api.z.ai is marked output-schema.; read-code: The codex argv sends model_reasoning_effort and the ledger always writes effort_confirmed = null.; read-code: Tests assert the mapped value and generated command only; no live route acceptance or application is checked. Verify: Run RC1 and inspect the route response and ledger for accepted/applied effort and schema enforcement. Remedy: Add route-level effort/schema confirmation, or explicitly record the values as unverified and do not treat the mapping as proven until live wire evidence exists.

### Prior findings

- F13-1 - still-open - Listed open; retained, not re-run here.
- F13-2 - still-open - Listed open; retained, not re-run here.
- F13-3 - still-open - Listed open; retained, not re-run here.
- F13-4 - still-open - Listed open; retained, not re-run here.
- F13-5 - still-open - Listed open; retained, not re-run here.
- F15-1 - still-open - Listed open; retained, not re-run here.
- F15-2 - still-open - Listed open; retained, not re-run here.
- F15-3 - still-open - Listed open; retained, not re-run here.
- F18-1 - still-open - Listed open; retained, not re-run here.
- F18-2 - still-open - Listed open; retained, not re-run here.
- F20-1 - still-open - Listed open; retained, not re-run here.
- F20-2 - still-open - Listed open; retained, not re-run here.
- F20-3 - still-open - Listed open; retained, not re-run here.
- F20-4 - still-open - Listed open; retained, not re-run here.
- F20-5 - still-open - Listed open; retained, not re-run here.
- F21-1 - still-open - Listed open; retained, not re-run here.
- F21-2 - still-open - Listed open; retained, not re-run here.
- F21-3 - still-open - Listed open; retained, not re-run here.
- F22-1 - still-open - Listed open; retained, not re-run here.
- F23-1 - still-open - Listed open; retained, not re-run here.
- F23-2 - still-open - Listed open; retained, not re-run here.
- F23-3 - still-open - Listed open; retained, not re-run here.
- F25-1 - still-open - Listed open; retained, not re-run here.
- F25-2 - still-open - Listed open; retained, not re-run here.
- F25-3 - still-open - Listed open; retained, not re-run here.
- F28-1 - still-open - Listed open; retained, not re-run here.
- F28-2 - still-open - Listed open; retained, not re-run here.
- F29-1 - still-open - Listed open; retained, not re-run here.
- F30-1 - still-open - Listed open; retained, not re-run here.
- F30-2 - still-open - Listed open; retained, not re-run here.
- F30-3 - still-open - Listed open; retained, not re-run here.
- F30-4 - still-open - Listed open; retained, not re-run here.
- F30-5 - still-open - Listed open; retained, not re-run here.
- F32-1 - still-open - Listed open; retained, not re-run here.
- F32-2 - still-open - Listed open; retained, not re-run here.
- F32-3 - still-open - Listed open; retained, not re-run here.
- F32-4 - still-open - Listed open; retained, not re-run here.
- F34-1 - still-open - Listed open; retained, not re-run here.
- F35-1 - still-open - Listed open; retained, not re-run here.
- F35-2 - still-open - Listed open; retained, not re-run here.
- F36-1 - still-open - Verified: a top-level profile still records unprofiled identity values.
- F36-2 - still-open - Verified: a user-defined openai provider table still resolves with only an info note.
- F36-3 - still-open - Verified: thread extraction accepts more session-start events than the invariant claims.
- F36-4 - still-open - Verified: the engine branch exists; the invariant describes codex only.
- F36-5 - still-open - Verified: 0.2.0 mechanisms are extended, not unchanged.
- F36-6 - still-open - Verified: the brief framing is stale versus v0.6.0 and the current MiMo lineage.
- F36-7 - still-open - Verified: the named design ids belong to the earlier bridge-0.3 namespace.

## Verdict: ADVISE

ADVISE per the output contract; the diff itself should be HOLD until the identity and z.ai effort/schema claims are corrected or proven.

### Blockers

_(none)_

### Unproven scenarios

- Codex profile merge semantics for provider/model/effort.
- Whether z.ai accepts and applies the zai-v1 effort mapping for GLM-5.3.
- Whether z.ai enforces the supplied output schema.

### First-run checklist (observable)

- [ ] Ledger entry exists for consultation id 84b03b51-8655-405a-8ca5-7ec02b73ad59.
- [ ] Reviewer lineage and engine match the actual run, not the stale ZAI/glm-5.3 framing.
- [ ] effort_requested, effort_sent, effort_mapping and schema_transport are present.
- [ ] usage and thread_source are populated from the route/events.
- [ ] The reply object parses and validates against consult-reply v1.
