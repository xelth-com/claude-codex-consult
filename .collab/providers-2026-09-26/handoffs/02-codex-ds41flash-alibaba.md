# Handoff 02 - Codex: ds41flash-alibaba

Date: 2026-09-26 02:17 local. Author: Codex (model deepseek-v4.1-flash, effort medium), Codex CLI 0.155.1.
Reviewer: alibaba :: deepseek-v4.1-flash (provider from -Provider, model from -Model; endpoint https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1, wire_api: responses; provider fingerprint 347c995d4325; harness codex-cli 0.155.1).
Preflight: ok: env ALIBABA_API_KEY set.
Effort: medium sent (requested medium, mapping alibaba-v1, by caps-v1: token-plan.ap-southeast-1.maas.aliyuncs.com, deepseek-v4.1-flash; not confirmed by the provider). Consultation id: 14570946-09af-4d52-af6c-7d244f5a4cb9.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m deepseek-v4.1-flash -c model_reasoning_effort="medium" -c model_provider="alibaba" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-f0d27aef587e48128d7386b0c3fbd8a2.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage alibaba :: deepseek-v4.1-flash in this task's ledger; other lineage(s): alibaba :: qwen3.8-max). Result thread: `01a0db13-4630-7d33-928c-bf4266d81f37` (source: events).
Brief: (none, prompt only). Reviewed: 1ff7d88 + uncommitted, base 1ff7d88485591acecb462bea4d43f20fd73cf170, tree sha256 81676f178c36, 2 changed files.
Bridge outcome: usable reply. Wall time: 212.8 s. Tokens: in 344396 (cached 286080), out 7098, reasoning 5850.
Verdict: ADVISE - The alibaba entry matches the table's shape and vocabulary invariants; the only concrete risk is the pre-existing open F01-1 about the 'auto' router, so this is a checkpoint note, not a block. Findings: none. Structured reply (prompt-only transport): `handoffs/02-codex-ds41flash-alibaba.reply.json`.
Raw event stream: `handoffs/02-codex-ds41flash-alibaba.events.jsonl`.
Verbatim reply follows.

---

## Answers
**1. Consistent?** Yes, structurally. `codex-consult-common.ps1:2590` has the same shape as ark/kimi/mimo (`Vocabulary`/`Models`/`SchemaTransport`); `alibaba` exists in `$script:EffortVocabularies` (`:2555`) with all four keys mapped (low/medium/high/xhigh, verbatim `alibaba-v1`), and `$script:AlibabaTokenPlanDeclaredModels` (`:2568`) holds exactly 12 names, `auto` included. `prompt-only` matches every other plan host (mimo/ark/kimi), and host-scoped declaration plus the `-NativeEffort` escape is honoured.
**2. Concrete risk.** `auto` is declared as accepting `xhigh`, but the routed model is endpoint-chosen, so a request may silently be ignored or rejected — unchanged F01-1. Also, the caps-v1 prose (`:2523`) still omits ark, kimi, alibaba (F01-2).

## Requested checks
RC1 — `pwsh plugins/codex-consult/scripts/consult-codex.ps1 -Provider alibaba -Model auto -Effort xhigh -Prompt "ping"` from the repo root; needs workspace-write and network; observe 400 vs silently-applied tier; scope: one run.

---

### Findings

_(none)_

### Prior findings

- F01-1 - still-open - 'auto' is still in $script:AlibabaTokenPlanDeclaredModels (:2568) and the alibaba-v1 vocabulary (:2555) is verbatim, so a declared effort for the endpoint-chosen model remains unestablished; code unchanged since the claim.
- F01-2 - still-open - The caps-v1 comment block (:2523-:2543) still enumerates only builtin:openai, api.z.ai/open.bigmodel.cn, the three xiaomimimo hosts and engine:agy; ark.ap-southeast.bytepluses.com, api.kimi.ai and token-plan.ap-southeast-1.maas.aliyuncs.com have no prose entry, and neither do the ark-v1/kimi-v1/alibaba-v1 mapping names.

## Verdict: ADVISE

The alibaba entry matches the table's shape and vocabulary invariants; the only concrete risk is the pre-existing open F01-1 about the 'auto' router, so this is a checkpoint note, not a block.

### Blockers

_(none)_

### Unproven scenarios

- Whether token-plan.ap-southeast-1.maas.aliyuncs.com accepts xhigh for 'auto', or for any listed model (no endpoint call made).
- Whether prompt-only is actually required on this route, or a json_schema response format would work (not documented in the read block).
- Whether the 12 declared names match the current Personal Edition subscription list (comment cites a 2026-09-26 doc, not verifiable here).

### First-run checklist (observable)

_(none)_
