# Handoff 28 - Codex: ab-08-codex

Date: 2026-10-08 02:30 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 3d92ccd1-c907-4e9b-9e23-5f1b7c6e2f76.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-c2b92cafc6444b5096925aee267fdd3a.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118eb-5694-7590-b5e3-f6da89216a97` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/08-claude-ab-format-compliance.md` (sha256 cb29ed8dce03). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 346.5 s. Tokens: in 1549207 (cached 1492992), out 11661, reasoning 6690.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The brief's proposal is already fully implemented and shipping as the default; only minor documentation drift remains. Findings: 0 blocker, 0 major, 1 minor, 0 note (F28-1, tracked in `findings.json`). Structured reply: `handoffs/28-codex-ab-08-codex.reply.json`.
Raw event stream: `handoffs/28-codex-ab-08-codex.events.jsonl`.
Verbatim reply follows.

---

**Checkpoint.** The brief is a verbatim 2026-09-24 copy and its "open proposal" is already implemented in full (F27-1): `-FormatRetry 1` is the default; one repair turn per consultation on the same verified thread at lowest effort; `Get-ProseGate` eligibility; `Get-FormatRepairDrift` drift notes; ledger `format_retry {attempted, reason, succeeded, thread, wall_seconds, usage, drift, original, events, schema_transport}`; the original prose saved verbatim as `handoffs/NN-<engine>-<slug>.original.md` before the repair starts (codex-consult.ps1:5221-5433, codex-consult-common.ps1:1718-1835). The brief also predates the agy, muse and claude engines, for which the repair runs through the engine adapters; its "system prompt Codex adds" clause is void for them. One new drift: the prompt no longer has the order the brief describes — it now OPENS with the FINAL OUTPUT CONTRACT before the ask (finding #1).

**Q1 (claude route).** The claude engine did not exist when the brief was written; today it runs `claude -p --output-format stream-json --restricted --tools Read,Grep,Glob --permission-mode dontAsk` with the schema passed natively via `--json-schema` and the prompt on stdin (codex-consult-common.ps1:4805-4822). What still pulls toward prose: the word "Markdown" inside `reply_markdown`, the numbered questions, and the long field-meanings block between the contract and the end. But `--json-schema` constrains the final message to the schema, and the contract-first opening is exactly the single order change I would recommend — it is already in place. Confidence: high for schema-constrained turns; the residual risk is a valid object whose substance is prose (everything in `reply_markdown`, empty `findings`), which wording alone cannot prevent.

**Q2.** Implemented: resume the same thread with "Your last message was prose, not the required JSON… Convert, do not re-answer: copy your previous content unchanged… add or omit nothing", plus the schema and the consultation id (codex-consult.ps1:5253-5254). Cheap drift detection (Get-FormatRepairDrift): RC-id set equality, numbered-answer count, every F-id named in the prose present in `prior_findings`/`findings`, verdict-token equality, and containment of every prose sentence of ≥60 characters (40 longest) in `reply_markdown`. The ledger records the fields above; the original is written before the repair process exists, so a stopped run keeps it. Residual gap: findings[]-field-only edits (severity, short remedy, locations) pass undetected — F25-2 remains open.

**Q3.** The implemented rule: one attempt, on by default (`-FormatRetry 0` opts out; never with `-Raw` or chore); it fires only when a usable reply (exit 0, no timeout, no provider failure) on a verified thread fails JSON validation AND passes Get-ProseGate — not a refusal, and above the word floors (≥25 words with ≥2 numbered answers, ≥40 with one, ≥120 otherwise). The case it must never fire on — a refusal or a too-short reply — is precisely what the gate blocks, with the reason recorded in `validation_error`.

**Q4.** ADVISE. (a) First turn: keep the current opening — "FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON object (schema_version \"1\") - no code fence, no text before or after it. The Markdown answer lives only inside its reply_markdown string…" (b) Repair: "Your last message was prose, not the required JSON. Reply with exactly one bare JSON object satisfying the JSON Schema below - no fence, nothing before or after it. Convert, do not re-answer: copy your previous content unchanged…; add or omit nothing." Both are under 80 words and already shipping.

All 23 listed prior findings were re-checked against the current tree: every one is still open (details in `prior_findings`); none changed claim, so none is refiled.

---

### Findings

- **F28-1** [minor] `.collab/ab-zai-2026-10-08/handoffs/08-claude-ab-format-compliance.md:14`, `plugins/codex-consult/scripts/codex-consult.ps1:4054` - The brief's description of the prompt order is stale: it says the prompt is 'the ask, the brief path, the purpose paragraph, the open findings, then the Reply format section, then the schema, then Constraints, and the very last line Consultation id', but the current structured prompt OPENS with the FINAL OUTPUT CONTRACT paragraph before the ask (added after handoffs 17/18), and also carries role, context-window, review-range, tools and re-read-brief blocks the brief does not mention. Substance of the format ask is unchanged. Trigger: Reading the brief's 'The problem' paragraph against Build- of the prompt in codex-consult.ps1 (promptParts order around lines 4050-4148). Evidence: read-code: The first promptPart added in structured mode is the FINAL OUTPUT CONTRACT line, before $Prompt, role, brief ref, purpose, open findings, Reply format section, schema, constraints, reread line and Consultation id last.; read-code: The brief describes the prompt as starting with the ask and placing the format instruction after the open findings. Verify: Open codex-consult.ps1 at the promptParts construction (~4050) and confirm the contract paragraph is the first part added when -not $Raw. Remedy: Note the drift in the checkpoint record (the brief is a frozen verbatim copy); optionally add a one-line correction in the task's decisions note rather than editing the handoff.

### Prior findings

- F13-1 - still-open - Counted 22 harness-*.ps1 files and 40 Check calls in harness-fixes28d.ps1; run-all.ps1 itself now says twenty-two.
- F13-2 - still-open - Open-TelemetrySpoolFile still returns $null for a missing file and Remove-TelemetrySpoolLines still reports 'stayed busy'.
- F14-1 - still-open - Flush still calls Remove-TelemetrySpoolLines with Math.Max(100, remaining) after only the lock-ownership check.
- F15-1 - still-open - Wait-EngineProcess still cuts at 2 x StallSec without stream growth while a tool is open; brief 02 D3 wording unchanged.
- F16-1 - still-open - Kick acknowledgement is still only <kick file>.ack with a 10 s wait; no 'kicked' pending state exists.
- F16-2 - still-open - Warning texts at codex-consult.ps1:6076/6122 are the cause-bearing retry wordings, not the brief's literal string.
- F16-3 - still-open - The wave-26c 'never cut' comment still sits above the wave-28b D12 comment in Wait-EngineProcess.
- F17-1 - still-open - Add-TelemetryNotSpooled writes per-producer files (NotSpooledOwn) with a flush fold; brief 03 D4/D7 wordings predate 28e.
- F17-2 - still-open - tests/README.md:23 still says 'twentieth harness'; run-all.ps1 registers 22 with harness-claude last.
- F19-1 - still-open - Counted 122 Check calls in harness-visibility.ps1 vs the brief's 76.
- F21-1 - still-open - Get-EndpointHealth still selects only Ok-or-auth and Ok-or-quota records; an 'unknown'-class failure is ignored.
- F21-2 - still-open - A still-blocking usage limit still refuses the run (7818/7832); Format-QuotaWarning requires -SkipPreflight.
- F21-3 - still-open - Get-EndpointHealth still merges machine-wide health entries and cross-route plan quotas.
- F22-1 - still-open - Classification is still payload-first over the ordered FailureClassPatterns table with the extended quota pattern.
- F23-1 - still-open - Counted 51 Check calls in harness-detach.ps1 vs the brief's 46.
- F23-2 - still-open - -Prune still also removes never-started and unreadable status files older than 7 days (1376-1384).
- F24-1 - still-open - Inline prompts still travel via .consult.detached-<id8>.prompt.txt with PromptFile in the record (1096-1107, 1484-1489).
- F25-1 - still-open - Counted 37 Check calls in harness-format.ps1 vs the brief's 23 cases.
- F25-2 - still-open - Get-FormatRepairDrift still compares only RC ids, Q counts, F-ids, verdict and >=60-char sentences against reply_markdown; findings[]-field edits pass.
- F25-3 - still-open - Numbered-style reasons ('1.', '2.') or any marker word still suppress the refusal test in Get-ProseGate.
- F25-4 - still-open - A short complete answer with unrecognized numbering (e.g. 'A1:') still fails the word floors as 'reply too short'.
- F27-1 - still-open - Verified: the repair is fully implemented (5221-5433, common 1718-1835) with ledger format_retry and .original.md; the brief still frames it as an open proposal.

## Verdict: ADVISE

The brief's proposal is already fully implemented and shipping as the default; only minor documentation drift remains.

### Blockers

_(none)_

### Unproven scenarios

- No harness or live engine was run (read-only consultation): runtime behaviour of the repair turn and the STALL/CARRY/NOTSPOOLED checks is verified by code reading only.

### First-run checklist (observable)

_(none)_
