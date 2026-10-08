# Handoff 27 - Claude (claude): ab-08-claude

Date: 2026-10-08 02:28 local. Author: Claude (claude) (model glm-5.3, effort medium), claude-cli 2.1.293.0.
Reviewer: ZAI-claude :: glm-5.3 [claude] (provider from -Provider, model from roster; engine claude (C:\users\dmytro\.local\bin\claude.exe), endpoint https://api.z.ai/api/anthropic (token from env ZAI_API_KEY); provider fingerprint 944a94557723; harness claude-cli 2.1.293.0).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 11 of 12 for -Provider ZAI-claude (engine, model applied).
Effort: medium sent (requested medium, mapping claude-v1, by caps-v1: engine:claude, any model; not confirmed by the provider). Consultation id: f9be3273-3ce6-4e24-abab-a1f341ef652c.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn's init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply), purpose: checkpoint). Argv: `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model glm-5.3 --effort medium --json-schema "{"$schema":"http://json-schema.org/draft-07/schema#","title":"codex-consult reply v1","type":"object","additionalProperties":false,"required":["schema_version","verdict","verdict_reason","reply_markdown","findings","prior_findings","unproven","first_run_checklist"],"properties":{"schema_version":{"type":"string","enum":["1"]},"verdict":{"type":"string","enum":["ACCEPT","HOLD","REJECT","ADVISE"]},"verdict_reason":{"type":"string"},"reply_markdown":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["severity","locations","claim","trigger","evidence","verification","remedy","supersedes"],"properties":{"severity":{"type":"string","enum":["blocker","major","minor","note"]},"locations":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line"],"properties":{"path":{"type":"string"},"line":{"type":["integer","null"]}}}},"claim":{"type":"string"},"trigger":{"type":"string"},"evidence":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["kind","reference","observation"],"properties":{"kind":{"type":"string","enum":["read-code","ran-command","inferred","assumed"]},"reference":{"type":"string"},"observation":{"type":"string"}}}},"verification":{"type":"string"},"remedy":{"type":"string"},"supersedes":{"type":"array","items":{"type":"string"}}}}},"prior_findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["id","status","note"],"properties":{"id":{"type":"string"},"status":{"type":"string","enum":["fixed","still-open","not-checked","unknown-id"]},"note":{"type":"string"}}}},"unproven":{"type":"array","items":{"type":"string"}},"first_run_checklist":{"type":"array","items":{"type":"string"}}}}" --session-id d3255f4d-c607-4b5a-89a8-4a2f4fa2ef2a` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `d3255f4d-c607-4b5a-89a8-4a2f4fa2ef2a` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/08-claude-ab-format-compliance.md` (sha256 cb29ed8dce03). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 139.1 s. Tokens: in 320077 (cached 290688), out 8529, reasoning ?.
Engine turns: 1 (claude -p, auth endpoint; model glm-5.3; init tools Glob, Grep, Read, StructuredOutput; permission denials 0).
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint of brief 08: the prompt structure it describes still matches the tree, the repair proposal it debates is already fully implemented, and the only open defects in this area are the known F25-2/3/4 gate and drift gaps. Findings: 0 blocker, 0 major, 0 minor, 1 note (F27-1, tracked in `findings.json`). Structured reply: `handoffs/27-claudecode-ab-08-claude.reply.json`.
Raw event stream: `handoffs/27-claudecode-ab-08-claude.events.jsonl`.
Verbatim reply follows.

---

**Checkpoint drift.** The prompt structure the brief describes still holds on the current tree: `Reply format:` section, prompt-only schema dump (codex-consult.ps1:4104-4126), Constraints, and `Consultation id` last (4148) - with newer additions between (role line, review range, open findings, the wave-28c/e re-read line at 4136-4145). But the repair the brief debates as a proposal **is already implemented** (waves 23+): one turn, default on, gate, drift notes, ledger `format_retry`, original prose saved verbatim. Answers below describe the code as it is.

**Q1 (claude route).** Prose risk factors today: the format instruction sits mid-prompt (before Constraints, before the schema on prompt-only routes); the gloss "your full answer in Markdown" inside `reply_markdown` primes Markdown-as-message; the brief's numbered questions invite numbered prose; the long in-prompt schema dilutes recency; the last line is `Consultation id`, not the format rule. Single change: make a one-line hard contract the true last line - "Your ENTIRE final message must be exactly one bare JSON object (schema_version "1") - no fence, no text before or after; the Markdown answer lives only inside reply_markdown." Fairly sure (high): recency dominates, and this very consultation carries such a line and returned bare JSON.

**Q2.** Implemented drift detection (Get-FormatRepairDrift, codex-consult-common.ps1:1793): compare RC-id sets, numbered-answer counts, every F-id named in prose appearing in prior_findings/findings, the prose verdict token vs JSON verdict, and every prose sentence ≥60 chars (40 longest) appearing in reply_markdown; plus a codex thread-id check. Ledger: `format_retry {attempted, reason, succeeded, thread, wall_seconds, usage, drift, original, events, schema_transport}`; the original prose is kept byte-for-byte at `handoffs/NN-<engine>-<slug>.original.md`. Known gap (F25-2): edits confined to findings[] fields (e.g. severity softened) still pass.

**Q3.** The shipped rule: one attempt, on by default (`-FormatRetry` defaults to 1; 0 off; never with -Raw/chore), for **every** route - not gated on declared transport - but only after a usable reply (exit 0, no timeout/provider failure) on a VERIFIED thread, and only when Get-ProseGate calls the prose substantive (refusals excluded; floors 25 words/2 numbered, 40/1, 120/none). The case it never fires on: a short or marker-free refusal.

**Q4.** ADVISE. (a) "Reply format contract: your final message is exactly one bare JSON object (schema_version "1") satisfying the schema - no code fence, no text before or after. The Markdown answer lives only inside its reply_markdown string; answer the numbered questions there, by number." (b) "Your previous message was prose. Reply now with exactly one bare JSON object satisfying the schema below - nothing else. Convert, do not re-answer: copy your earlier content unchanged into reply_markdown (same Q1..Qn answers, findings, Requested checks, prior-finding statuses, verdict); add, drop and change nothing."

## Requested checks
- RC1: From the repository root run `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-format.ps1` (read-only): expect 37 PASS lines covering the repair/gate/drift cases on the current tree.

---

### Findings

- **F27-1** [note] `.collab/ab-zai-2026-10-08/handoffs/08-claude-ab-format-compliance.md:29` - The brief frames the format-repair retry as an open operator proposal and asks how it should work, but the current tree already implements it in full (one repair turn per consultation, default on, Get-ProseGate eligibility, Get-FormatRepairDrift drift notes, ledger format_retry {attempted, reason, succeeded, thread, wall_seconds, usage, drift, original, events, schema_transport}, and the verbatim original prose saved as handoffs/NN-<engine>-<slug>.original.md); the brief also predates the non-codex engines (agy, muse, claude), for which the repair runs through the engine adapters, and its 'system prompt Codex adds' clause is void for them. Trigger: Reading the brief's 'The operator's proposal' section against codex-consult.ps1:5221-5433 and codex-consult-common.ps1:1718-1835. Evidence: read-code: Full repair-turn implementation: eligibility (usable reply, verified thread, -FormatRetry 1 default at line 714), guarded start, Wait-EngineProcess, re-validation, drift list, format_retry record with original/events/schema_transport, original prose copied byte-for-byte to handoffs/NN-...original.md.; read-code: Get-ProseGate (refusal/word floors) and Get-FormatRepairDrift (RC ids, numbered counts, F-ids, verdict, >=60-char sentences) plus a codex thread-id check. Verify: Run a structured consultation in test mode against a fake engine that answers in prose and confirm the ledger entry carries format_retry with attempted=true and original pointing at the saved .original.md. Remedy: Treat the brief as answered-by-code: record in the wave notes that Q2/Q3 are descriptions of the shipped mechanism, not new design.

### Prior findings

- F13-1 - still-open - Glob confirms 22 tests/harness-*.ps1 files (harness-claude and harness-fixes28e among them); the 'twenty harnesses' wording in the older brief remains stale.
- F13-2 - not-checked - Telemetry spool code not re-read in this consultation.
- F14-1 - not-checked - Flush deadline logic not re-read.
- F15-1 - not-checked - Wait-EngineProcess stall behaviour not re-read this time.
- F16-1 - not-checked - -Kick implementation not re-read.
- F16-2 - not-checked - Health warning strings not re-read.
- F16-3 - not-checked - Wait-EngineProcess comment blocks not re-read.
- F17-1 - not-checked - Brief 03 not re-read; the code side (multi-line ask '+n more lines' at codex-consult.ps1:4136-4145) matches the finding's description.
- F17-2 - still-open - tests/README.md:23 still says 'the twentieth harness of run-all.ps1' while run-all.ps1 registers 22 harnesses with harness-claude last (and its own header says twenty-two).
- F19-1 - still-open - Grep counts 122 'Check ' calls in tests/harness-visibility.ps1, matching the finding; the 76-check claim stays stale.
- F21-1 - not-checked - Provider failure classification not re-read.
- F21-2 - not-checked - Quota preflight refusal not re-run.
- F21-3 - not-checked - Machine-wide health merge not re-read.
- F22-1 - not-checked - Classifier code not re-read.
- F23-1 - still-open - Grep counts 51 'Check ' calls in tests/harness-detach.ps1, matching the finding's 51.
- F23-2 - not-checked - -Prune behaviour not re-read.
- F24-1 - still-open - The F11-2 prompt-file transport is present (codex-consult.ps1:467, 1096: <task>/.consult.detached-<id8>.prompt.txt), so the brief's inline-Prompt-in-record sentence stays stale.
- F25-1 - still-open - Grep counts 37 'Check ' calls in tests/harness-format.ps1, matching the finding's 37; brief 07's '23 cases' stays stale.
- F25-2 - still-open - Get-FormatRepairDrift (codex-consult-common.ps1:1793-1835) still compares only RC ids, numbered-answer counts, F-ids, the verdict token and >=60-char prose sentences; a softened severity or a rephrased short remedy/trigger/location in findings[] still passes undetected.
- F25-3 - still-open - codex-consult-common.ps1:1752-1753: numbered answers, F-ids, RC ids or the word 'verdict' still suppress the refusal test, so an enumerated or marker-bearing long refusal is still accepted as substantive.
- F25-4 - still-open - codex-consult-common.ps1:1738+1754: numbering styles outside NumberedAnswerRe (e.g. 'A1:', '**Q1** -') still count as numbered=0, so a complete 80-110-word reply is rejected as 'reply too short'.

## Verdict: ADVISE

Checkpoint of brief 08: the prompt structure it describes still matches the tree, the repair proposal it debates is already fully implemented, and the only open defects in this area are the known F25-2/3/4 gate and drift gaps.

### Blockers

_(none)_

### Unproven scenarios

- Live-run behaviour of the repair turn on each real route (only the code and the harness fixtures were read, no engine was started).
- Whether the z.ai endpoint still ignores --output-schema as the brief's n=2/n=8 history claims; not retested.

### First-run checklist (observable)

_(none)_
