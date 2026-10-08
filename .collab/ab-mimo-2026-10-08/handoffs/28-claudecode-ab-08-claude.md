# Handoff 28 - Claude (claude): ab-08-claude

Date: 2026-10-08 08:55 local. Author: Claude (claude) (model mimo-v2.6-pro, effort medium), claude-cli 2.1.294.0.
Reviewer: mimo-claude :: mimo-v2.6-pro [claude] (provider from -Provider, model from roster; engine claude (C:\users\dmytro\.local\bin\claude.exe), endpoint https://token-plan-ams.xiaomimimo.com/anthropic (token from env MIMO_API_KEY); provider fingerprint f615a41b2fe4; harness claude-cli 2.1.294.0).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 12 of 12 for -Provider mimo-claude (engine, model applied).
Effort: medium sent (requested medium, mapping claude-v1, by caps-v1: engine:claude, any model; not confirmed by the provider). Consultation id: 7c78f97c-bfcf-4571-a594-babe29b0631c.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn's init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply), purpose: checkpoint). Argv: `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model mimo-v2.6-pro --effort medium --json-schema "{"$schema":"http://json-schema.org/draft-07/schema#","title":"codex-consult reply v1","type":"object","additionalProperties":false,"required":["schema_version","verdict","verdict_reason","reply_markdown","findings","prior_findings","unproven","first_run_checklist"],"properties":{"schema_version":{"type":"string","enum":["1"]},"verdict":{"type":"string","enum":["ACCEPT","HOLD","REJECT","ADVISE"]},"verdict_reason":{"type":"string"},"reply_markdown":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["severity","locations","claim","trigger","evidence","verification","remedy","supersedes"],"properties":{"severity":{"type":"string","enum":["blocker","major","minor","note"]},"locations":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line"],"properties":{"path":{"type":"string"},"line":{"type":["integer","null"]}}}},"claim":{"type":"string"},"trigger":{"type":"string"},"evidence":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["kind","reference","observation"],"properties":{"kind":{"type":"string","enum":["read-code","ran-command","inferred","assumed"]},"reference":{"type":"string"},"observation":{"type":"string"}}}},"verification":{"type":"string"},"remedy":{"type":"string"},"supersedes":{"type":"array","items":{"type":"string"}}}}},"prior_findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["id","status","note"],"properties":{"id":{"type":"string"},"status":{"type":"string","enum":["fixed","still-open","not-checked","unknown-id"]},"note":{"type":"string"}}}},"unproven":{"type":"array","items":{"type":"string"}},"first_run_checklist":{"type":"array","items":{"type":"string"}}}}" --session-id ff0d8afe-777d-4c1a-a241-668e4f11426d` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `ff0d8afe-777d-4c1a-a241-668e4f11426d` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/08-claude-ab-format-compliance.md` (sha256 cb29ed8dce03). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 618.7 s. Tokens: in 256118 (cached 203008), out 21777, reasoning ?.
Engine turns: 1 (claude -p, auth endpoint; model mimo-v2.6-pro; init tools Glob, Grep, Read, StructuredOutput; permission denials 0).
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint/format-design consult: the brief's prompt-order and bridge-framing claims have drifted from the tree (findings #1-#2), the repair mechanics it proposes are already implemented as a superset, and the advice rests on code read here plus the brief's historical route runs. Findings: 0 blocker, 0 major, 1 minor, 1 note (F28-1..F28-2, tracked in `findings.json`). Structured reply: `handoffs/28-claudecode-ab-08-claude.reply.json`.
Raw event stream: `handoffs/28-claudecode-ab-08-claude.events.jsonl`.
Verbatim reply follows.

---

Brief 08 is verbatim bridge-0.3 handoff 16 (base `a743d81`, 0.3.0); this tree is 0.6.0. Its still-true route facts are caps-v1 invariants now (common:2784-95). Drift: findings #1-#2.

**Q1 (mimo-v2.6-pro, prompt-only).** Prose pullers: `reply_markdown: your full answer in Markdown, answering every numbered question by number` (codex-consult.ps1:4105) invites a visible Q-essay; the schema text sits late (4122-26), far from the contract; numbered brief questions make a Q-first answer natural. The leading FINAL OUTPUT CONTRACT (4054) postdates the brief and is the right fix. Single change: repeat that contract as the last content line before `Consultation id:` (4148) - long prompts erode end-weight. Confidence ~70% (MiMo already complied in the brief's n=5/7/9).

**Q2.** Implemented cheap checks (common:1793-1835): RC-id sets; Q-number count; prose-named F-ids present in the object; verdict token; 40 longest prose sentences >=60 chars in reply_markdown. Ledger `format_retry {attempted, reason, succeeded, thread, wall_seconds, usage, drift[], original, events, schema_transport}` (5420-31) - a superset of your `drift_note` shape; original prose kept verbatim at `handoffs/NN-*.original.md` (5248-51). Gap (F25-2, still-open): findings[] content drifts silently - add a severity/remedy match per prose-named F-id.

**Q3.** Keep the current rule: one attempt, default on (`-FormatRetry 1`, 714), every engine, substantive prose on a verified thread only (5234-43); never -Raw/-chore; never a refusal or under-floor reply (Get-ProseGate, common:1753-55). Never fire on a refusal - repairing one launders it into an ingested review (F25-3 corners remain).

**Q4.** (a) First turn (keep 4054, also as last content line):

> FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON object (schema_version "1") - no code fence, no text before or after it. The Markdown answer lives only inside its reply_markdown string; each defect goes in findings[]. A prose final message cannot be ingested, however good the answer is.

(b) Repair (keep 5253):

> Your last message was prose, not the required JSON. Reply with exactly one bare JSON object satisfying the JSON Schema below - no fence, nothing before or after it. Convert, do not re-answer: copy your previous content unchanged (the same Q1..Qn answers verbatim inside reply_markdown, the same findings, the same Requested checks, the same prior-finding statuses and the same verdict); add or omit nothing.

## Requested checks
- **RC1** (finding #2): from the repository root run `git describe --tags --always --dirty` (read-only, 10 s); expect `v0.6.0-*`, not `a743d81`/0.3.0.
- **RC2** (F25-2): in PowerShell, dot-source codex-consult-common.ps1, call `Get-FormatRepairDrift` with prose naming F21-1 as blocker+remedy and a Reply whose findings[] F21-1 is `minor` with another remedy (reply_markdown echoes prose); empty notes confirms F25-2 (read-only, 2 min).
- **RC3** (Q1): n=3 MiMo runs with/without the end-restated contract (`-FormatRetry 0`); count turn-1 bare JSON (workspace-write, 20 min).

---

### Findings

- **F28-1** [minor] `.collab/ab-mimo-2026-10-08/handoffs/08-claude-ab-format-compliance.md:15`, `.collab/ab-mimo-2026-10-08/handoffs/08-claude-ab-format-compliance.md:16`, `plugins/codex-consult/scripts/codex-consult.ps1:4054`, `plugins/codex-consult/scripts/codex-consult.ps1:4050` - Brief 08's description of the consultation prompt's assembly order has drifted: the prompt now opens with a 'FINAL OUTPUT CONTRACT' bare-JSON paragraph before the ask (added because a reviewer reading a long brief first tends to answer in prose), and the ask and the brief path are separated by context-window, role, review-range and engine-tools paragraphs, with a brief/ask re-read line just before the Consultation id; the tail the brief describes (Reply format -> prompt-only JSON Schema -> Constraints -> Consultation id last) still matches. Trigger: Reading brief lines 14-17 against the prompt builder in codex-consult.ps1. Evidence: read-code: promptParts order: FINAL OUTPUT CONTRACT (4054), ask (4056), context/role (4058-62), brief path (4065), review range + engine tools (4067-75), purpose + open findings (4082-97), Reply format field meanings (4103-21), prompt-only schema 'JSON Schema of the reply:' (4122-26), Constraints (4127), re-read line (4136-46), Consultation id last (4148).; read-code: Comment records the contract-first order as a deliberate change (handoffs 17/18) that postdates brief 08's source text. Verify: Re-read codex-consult.ps1:4050-4148 (or print one built prompt from a prompt-only dry run) and compare the part order with brief lines 14-17. Remedy: Update the brief's prompt description to the current order (contract first; role/range/tools paragraphs; re-read line before the consultation id), or record this drift in the handoff notes if the brief stays verbatim history.
- **F28-2** [note] `.collab/ab-mimo-2026-10-08/handoffs/08-claude-ab-format-compliance.md:7`, `.collab/ab-mimo-2026-10-08/handoffs/08-claude-ab-format-compliance.md:27`, `plugins/codex-consult/scripts/codex-consult.ps1:3508`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2784` - Brief 08's framing is stale: base `a743d81` (0.3.0 candidate) no longer describes the tree (0.6.0, waves 24-29c in between), and 'the bridge is dependency-free PowerShell around codex exec' is now a four-engine bridge (codex/agy/muse/claude; the repair turn is engine-generic). The route facts the brief observed (z.ai accepts json_schema without enforcing; MiMo rejects it) still hold and are codified in caps-v1 (common:2784-95). Trigger: Treating the brief's commit and bridge framing as the state of the reviewed code. Evidence: read-code: Engine set is codex/agy/muse/claude with per-engine transports (codex: output-schema|prompt-only; the others: native|prompt-only).; read-code: The repair turn is engine-generic (repairTransport: codex never passes --output-schema; an engine uses the main turn's transport).; read-code: caps-v1 codifies the brief's route facts: z.ai 'accepts it without enforcing', MiMo 'rejects a json_schema response format: the schema travels in the prompt only'.; inferred: HEAD is 65380b2 (wave 29c) at 0.6.0; a743d81/0.3.0 cannot describe this tree. Verify: Run `git describe --tags --always --dirty` from the repository root (expect v0.6.0-*, not a743d81/0.3.0) - RC1. Remedy: Treat the brief as historical and answer on the current tree (done here), or restate its base commit and engine set when it is re-issued.

### Prior findings

- F13-1 - not-checked - Marker/flush-lock pid-reuse; outside brief 08's format-compliance scope, not re-read here.
- F13-2 - not-checked - PS 5.1 spool File.Replace path; outside this checkpoint.
- F13-3 - not-checked - Exit-TelemetryFlushLock delete window; outside this checkpoint.
- F13-4 - still-open - Re-confirmed while reading the prompt builder: a multi-line ask is still first-line-only + '(+n more lines)', cut at 300 (codex-consult.ps1:4136-45). Unchanged; not refiled.
- F13-5 - not-checked - Drift claims against handoffs/01; outside this checkpoint.
- F15-1 - not-checked - Kick-ack drift; outside this checkpoint.
- F15-2 - not-checked - Health warning wording drift; outside this checkpoint.
- F15-3 - not-checked - Stall-cut/engine-set drift; outside this checkpoint.
- F18-1 - not-checked - Spool tmp / per-producer not-spooled drift; outside this checkpoint.
- F18-2 - not-checked - Suite-run claim; outside this checkpoint.
- F20-1 - not-checked - timeout_source roster value; outside this checkpoint.
- F20-2 - not-checked - harness-visibility inventory; outside this checkpoint.
- F20-3 - not-checked - Stale commit framing of brief 04; same class as finding #2 here but not re-verified.
- F20-4 - not-checked - Burst 429 10-minute window; outside this checkpoint.
- F20-5 - not-checked - Finding-id namespace collision in brief 04; outside this checkpoint.
- F21-1 - not-checked - unknown provider_failure class and endpoint health; outside this checkpoint.
- F21-2 - not-checked - Preflight description drift of brief 05; outside this checkpoint.
- F21-3 - not-checked - Stale base commit of brief 05; same class as finding #2 here but not re-verified.
- F22-1 - not-checked - Preflight fail-closed drift of brief 05; outside this checkpoint.
- F23-1 - not-checked - harness-detach inventory; outside this checkpoint.
- F23-2 - not-checked - Detach claim wording drift; outside this checkpoint.
- F23-3 - not-checked - Foreign finding ids in brief 06; outside this checkpoint.
- F25-1 - still-open - Code items re-confirmed at this tree: 40 longest >=60-char sentences (common:1824-31), refusal-aware floors (1753-54), format_retry carries events+schema_transport (5429-30), codex-only no-schema repair (5261). harness-format check count not recounted.
- F25-2 - still-open - Re-read Get-FormatRepairDrift (common:1793-1835): check 3 tests only F-id presence and check 5 matches prose sentences only against reply_markdown - findings[] content drift stays invisible. Not refiled (see Q2).
- F25-3 - still-open - Re-read Get-ProseGate (common:1739-56): refusal detection is first-200-chars startsWith or >=2 phrase hits ('i will not' still absent) and short complete answers still fail the word floors.

## Verdict: ADVISE

Checkpoint/format-design consult: the brief's prompt-order and bridge-framing claims have drifted from the tree (findings #1-#2), the repair mechanics it proposes are already implemented as a superset, and the advice rests on code read here plus the brief's historical route runs.

### Blockers

_(none)_

### Unproven scenarios

- The brief's live-endpoint observations (z.ai prose both runs n=2/n=8; MiMo bare JSON on prompt-only n=5/7/9; MiMo rejecting a json_schema response format) are historical runs of the earlier task and cannot be reproduced read-only.
- Whether the end-restated contract (Q1's single change) actually raises first-turn bare-JSON rate on MiMo or z.ai - no A/B runs were possible here.
- F25-2/F25-3 blind spots are asserted from code reading only; no fixture or harness run in this consultation.

### First-run checklist (observable)

_(none)_
