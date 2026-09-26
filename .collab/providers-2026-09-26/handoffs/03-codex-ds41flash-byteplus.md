# Handoff 03 - Codex: ds41flash-byteplus

Date: 2026-09-26 02:21 local. Author: Codex (model deepseek-v4.1-flash, effort medium), Codex CLI 0.155.1.
Reviewer: byteplus :: deepseek-v4.1-flash (provider from -Provider, model from -Model; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Effort: medium sent (requested medium, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, deepseek-v4.1-flash; not confirmed by the provider). Consultation id: 210b0e8e-dc7d-4c65-976a-3511e1699d60.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m deepseek-v4.1-flash -c model_reasoning_effort="medium" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-1c2f219bd0394cac9d6d732035ebda01.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage byteplus :: deepseek-v4.1-flash in this task's ledger; other lineage(s): alibaba :: deepseek-v4.1-flash, alibaba :: qwen3.8-max). Result thread: `01a0db16-82de-70b2-bd88-2365300f5c66` (source: events).
Brief: (none, prompt only). Reviewed: 1ff7d88 + uncommitted, base 1ff7d88485591acecb462bea4d43f20fd73cf170, tree sha256 81676f178c36, 2 changed files.
Bridge outcome: usable reply. Wall time: 58.2 s. Tokens: in 406906 (cached 393600), out 3971, reasoning 2696.
Verdict: ADVISE - The new alibaba host entry matches the caps-v1 table shape and vocabulary/declared-model conventions, but the `auto` router member and the stale prose header keep two open drifts. Findings: none. Structured reply (prompt-only transport): `handoffs/03-codex-ds41flash-byteplus.reply.json`.
Raw event stream: `handoffs/03-codex-ds41flash-byteplus.events.jsonl`.
Verbatim reply follows.

---

**Checkpoint: alibaba host entry (caps-v1)**

1. Yes, structurally consistent: the key at `codex-consult-common.ps1:2590` has the same `{ Vocabulary; Models; SchemaTransport }` shape as every other host, `alibaba` is declared in `$script:EffortVocabularies` (`:2555`, mapping `alibaba-v1`, all four levels mapped), the declared-model list at `:2568` holds exactly 12 ids, and `prompt-only` matches ark/kimi/mimo (`:2583`, `:2586`).
2. One concrete risk: `auto` (`:2568`) is the plan's own router, so the endpoint decides which model runs and the verbatim `low|medium|high|xhigh` claim for it is unestablished (F01-1, still-open). No other host declares a non-concrete model id.
3. Documented drift: the caps-v1 prose header (`:2523`-`:2543`) still has no alibaba, ark or kimi entry, so the "authoritative" comment disagrees with the table (F01-2, still-open).

---

### Findings

_(none)_

### Prior findings

- F01-1 - still-open - Reconfirmed from the table: `auto` at :2568 is in the declared list, so Resolve-EffortPlan sends the verbatim mapped value for a router-chosen model; nothing in the read scope establishes that capability.
- F01-2 - still-open - Reconfirmed: the caps-v1 comment block (:2523-:2543) documents builtin:openai, zai, mimo and engine:agy only; EffortCaps keys at :2574-:2592 include ark, kimi and alibaba with no prose entry.

## Verdict: ADVISE

The new alibaba host entry matches the caps-v1 table shape and vocabulary/declared-model conventions, but the `auto` router member and the stale prose header keep two open drifts.

### Blockers

_(none)_

### Unproven scenarios

- Whether the Alibaba Token Plan endpoint accepts low|medium|high|xhigh for `auto` (or the routed model) - not verifiable read-only from these blocks.
- Whether the 12 declared alibaba ids match the subscription page, and whether the undated `deepseek-v4-flash` (declared on ark at :2565) is also valid here; list membership is exact and case-sensitive.

### First-run checklist (observable)

_(none)_
