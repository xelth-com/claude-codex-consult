# Handoff 01 - Codex: qwen38max-smoke

Date: 2026-09-26 02:15 local. Author: Codex (model qwen3.8-max, effort medium), Codex CLI 0.155.1.
Reviewer: alibaba :: qwen3.8-max (provider from -Provider, model from -Model; endpoint https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1, wire_api: responses; provider fingerprint 347c995d4325; harness codex-cli 0.155.1).
Preflight: ok: env ALIBABA_API_KEY set.
Effort: medium sent (requested medium, mapping alibaba-v1, by caps-v1: token-plan.ap-southeast-1.maas.aliyuncs.com, qwen3.8-max; not confirmed by the provider). Consultation id: fe2107ae-5748-4f71-8ffd-5a75290facec.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m qwen3.8-max -c model_reasoning_effort="medium" -c model_provider="alibaba" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-cc708d00fc8f48c9b184448b54d1545d.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a0db10-c3f4-7423-82b2-bc949f86c370` (source: events).
Brief: (none, prompt only). Reviewed: 1ff7d88 + uncommitted, base 1ff7d88485591acecb462bea4d43f20fd73cf170, tree sha256 81676f178c36, 2 changed files.
Bridge outcome: usable reply. Wall time: 157.7 s. Tokens: in 217478 (cached 113664), out 4147, reasoning 2597.
Verdict: ADVISE - The new host entry follows the existing caps-v1 shape exactly; the only real exposure is the `auto` router model under a verbatim `xhigh` identity map. Findings: 0 blocker, 0 major, 1 minor, 1 note (F01-1..F01-2, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/01-codex-qwen38max-smoke.reply.json`.
Raw event stream: `handoffs/01-codex-qwen38max-smoke.events.jsonl`.
Verbatim reply follows.

---

**1. Consistency**
- Matches the other plan hosts: vocabulary `alibaba` exists in `$script:EffortVocabularies` (mapping `alibaba-v1`), models come from a dedicated list (`$script:AlibabaTokenPlanDeclaredModels`, exactly 12 names), and `SchemaTransport = 'prompt-only'` like mimo/ark/kimi. Host-keyed, models exact, nothing inferred.

**2. Concrete risk**
- `auto` is a router, not a model, so caps-v1's "capability declared per model" rule is unenforceable for it, and `alibaba` maps `xhigh -> xhigh` verbatim. An `-Effort xhigh` run on `auto` can be refused or silently downgraded by whichever model the router picks, while the ledger records `effort_sent = xhigh` (`effort_confirmed` is always null).

**Drift**
- The caps-v1 comment enumerates openai/zai/mimo/agy but not alibaba (ark and kimi are missing too).

---

### Findings

- **F01-1** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2568`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2590`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2555` - The alibaba entry declares `auto` — the plan's router — as a model with a known effort vocabulary, but the router's target model is chosen by the endpoint, so the declared capability (`low|medium|high|xhigh`, mapped verbatim) is not actually established for the model that runs. Trigger: A consult with `-Provider alibaba -Model auto -Effort xhigh` (or high): the bridge sends `xhigh` because `auto` is in the declared list, and the routed model may reject or ignore it. Evidence: read-code: `$script:AlibabaTokenPlanDeclaredModels` = 12 names, including `auto`, with the comment "`auto` is the plan's own router".; read-code: Vocabulary `alibaba` maps low/medium/high/xhigh to themselves, justified by a blanket doc claim ("every text model takes low|medium|high|xhigh").; read-code: caps-v1 states capability is DECLARED per model and that `effort_confirmed` is always null, so a wrong tier cannot be detected at runtime. Verify: Run one consult with `-Provider alibaba -Model auto -Effort xhigh` and a trivial prompt; observe whether the endpoint returns a 400/validation error or applies a different tier than requested. Remedy: Either drop `auto` from `$script:AlibabaTokenPlanDeclaredModels`, or cap it explicitly (e.g. keep `auto` only for low/medium/high) and record in the caps-v1 comment that the router's effort capability is unverified.
- **F01-2** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:2523`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2590` - The caps-v1 header comment (the authoritative prose description of the table) was not extended for the new alibaba host, so the documented table and the code table disagree. Trigger: A reader or reviewer checking a host against the caps-v1 comment finds no alibaba entry (same for ark and kimi, which are pre-existing omissions). Evidence: read-code: The comment lists only builtin openai, api.z.ai/open.bigmodel.cn, the three xiaomimimo hosts and engine:agy; ark, kimi and alibaba appear only in the hashtable below. Verify: Diff the host names in the caps-v1 comment against the keys of `$script:EffortCaps`; three keys (ark, kimi, alibaba) have no prose entry. Remedy: Add one comment line per undocumented host family (ark, kimi, alibaba) with its vocabulary, declared-model source and schema transport.

### Prior findings

_(none)_

## Verdict: ADVISE

The new host entry follows the existing caps-v1 shape exactly; the only real exposure is the `auto` router model under a verbatim `xhigh` identity map.

### Blockers

_(none)_

### Unproven scenarios

- Whether host resolution elsewhere in the file normalises the configured base URL to exactly `token-plan.ap-southeast-1.maas.aliyuncs.com` (only the `Get-SchemaTransport` lookup head was in scope).
- Whether the Model Studio doc's "every text model" effort claim really covers the non-Qwen names in the list (`deepseek-v4*`, `glm-5.3`, `glm-5.2`).
- Whether `alibaba-v1` is consumed anywhere that expects a non-identity mapping.

### First-run checklist (observable)

_(none)_
