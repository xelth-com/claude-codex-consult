# Handoff 29 - Codex: ab-08-codex

Date: 2026-10-08 09:06 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: a104092f-6b5c-4a97-b00d-1729e54f750d.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-88e3630ad19441309a9fb35a58fc8511.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a11a55-a33f-7a30-898f-603c16ecdddb` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/08-claude-ab-format-compliance.md` (sha256 cb29ed8dce03). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 555.1 s. Tokens: in 509579 (cached 0), out 14166, reasoning 10615.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Brief 08's prompt-order and bridge framing claims are stale (F28-1/F28-2, both still open) and one cheap-drift gap remains (finding #1); the format-repair flow otherwise already implements and exceeds the proposal. Findings: 0 blocker, 0 major, 1 minor, 0 note (F29-1, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/29-codex-ab-08-codex.reply.json`.
Raw event stream: `handoffs/29-codex-ab-08-codex.events.jsonl`.
Verbatim reply follows.

---

## Drift vs the brief (current tree)
- Prompt order (brief line 15-17) is stale — F28-1: the prompt now opens with a `FINAL OUTPUT CONTRACT` bare-JSON paragraph (codex-consult.ps1:4054) before the ask; context-window/role/range/engine-tools paragraphs sit between ask and brief (4058-76), and a brief/ask re-read line precedes the last `Consultation id` (4136-48). The tail (Reply format -> prompt-only schema -> Constraints -> id last) still matches.
- Bridge framing (brief line 7) is stale — F28-2: the bridge is four-engine (codex/agy/muse/claude); the repair turn is engine-generic (5367-95), not just `codex exec resume`.
- The proposed retry already exists, richer than proposed: one turn (`-FormatRetry 1` default), substantive-prose gate, original prose kept verbatim (`.original.md`, also appended to the handoff), and ledger `format_retry {attempted, reason, succeeded, thread, wall_seconds, usage, drift, original, events, schema_transport}` (5420-31).

**Q1.** My route is MiMo on prompt-only. Prose risk today: the full JSON Schema sits mid-prompt after the long brief, `reply_markdown` is glossed as "your full answer in Markdown", and the brief's numbered questions invite Markdown answers. The highest-value fix — the output contract before the ask — is already in the tree, and this consultation returned bare JSON on the first turn. Single further change: move the prompt-only JSON Schema directly after the contract, before the ask, so output shape precedes content. Confidence ~80% (one data point).

**Q2.** Cheap drift detection exists (Get-FormatRepairDrift, common:1793-1835): RC-id set, Q-answer count, F-id existence, verdict token, and the 40 longest >=60-char prose sentences found in reply_markdown. Two gaps: findings[]/prior_findings content (F25-2) and renumbered Q-answers (finding #1). Ledger record: the current superset above (proposed drift_note -> drift[]) is sufficient; the original prose is kept byte-for-byte in `NN-*.original.md` and after the structured section (5893-98, 5927).

**Q3.** One attempt, on by default, every route — the current rule (5234-42): only a usable reply, invalid structure, verified thread, and substantive prose. It must never fire on a refusal, nor on any provider failure (quota/auth/billing).

**Q4.** (a) First turn, keep as-is: "FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON object... The Markdown answer lives only inside its reply_markdown string; each defect goes in findings[]. A prose final message cannot be ingested." (b) Repair, keep as-is: "Your last message was prose, not the required JSON. Reply with exactly one bare JSON object satisfying the JSON Schema below... Convert, do not re-answer: copy your previous content unchanged...; add or omit nothing."

---

### Findings

- **F29-1** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:1806` - Get-FormatRepairDrift's numbered-answer check extracts the Q-numbers but compares only the counts of the two lists (common:1803-07), so a format repair that renumbers or swaps which questions are answered while keeping the same count produces zero drift notes - the 'renumbered' drift class named in Q2 is undetected. Trigger: A format-repair turn whose prose answers Q1..Q4 but whose reply_markdown answers Q2..Q5 (or duplicates a number), with all other checks clean. Evidence: read-code: $qOf captures the Q-numbers of prose and reply_markdown, but the comparison is only `$qProse.Count -ne $qMd.Count`; differing number sets with equal cardinality pass silently. Verify: Call Get-FormatRepairDrift with Prose containing Q1., Q2., Q3., Q4. headings and a Reply whose reply_markdown contains Q2., Q3., Q4., Q5.; expect an empty notes array despite the renumbering. Remedy: Compare the sorted Q-number sequences (or sets) of prose and reply_markdown and add a drift note when they differ, not just when their counts differ.

### Prior findings

- F13-1 - not-checked - Race scenario needing process-spawning runs; not re-verified in this read-only checkpoint.
- F13-2 - not-checked - PS 5.1 File.Replace fallback not re-read here; out of this brief's scope.
- F13-3 - not-checked - Two-process race; cannot be settled read-only.
- F13-4 - still-open - Verified unchanged: codex-consult.ps1:4136-45 still repeats only the first ask line (300-char cut) plus a remaining-line count.
- F13-5 - not-checked - Handoff 01 claims not re-read in this checkpoint.
- F15-1 - still-open - Verified: no pending-record `kicked` state (grep shows only RunKicked vars and a legacy plain-text ack parser at common:10752-53); ack channel is the ack file only, and -Status/-Wait refuses with exit 4 (codex-consult.ps1:1181-85).
- F15-2 - not-checked - Warning-string and health-journal claims not re-read here.
- F15-3 - not-checked - Stall/tool-cap behavior not re-read here.
- F18-1 - not-checked - Spool tmp/per-producer claims not re-read here.
- F18-2 - not-checked - Needs fresh suite runs under both PowerShell hosts; read-only.
- F20-1 - not-checked - timeout_source roster claim not re-read here.
- F20-2 - still-open - Recounted tests/harness-visibility.ps1: 122 Check calls, 16 Want suites (UNIT..PANEL), no GUARD - claim holds.
- F20-3 - not-checked - Commit-framing drift not re-run (git commands not run).
- F20-4 - not-checked - Burst 429 constant not re-read here.
- F20-5 - not-checked - Id-namespace claim not re-grepped here.
- F21-1 - not-checked - Provider_failure classifier not re-read here.
- F21-2 - not-checked - Preflight behavior not re-read here.
- F21-3 - not-checked - Version framing not re-run.
- F22-1 - not-checked - Preflight unknown-state refusal not re-read here.
- F23-1 - still-open - Recounted tests/harness-detach.ps1: 51 Check calls (including CARRY) vs the claimed 46 - claim holds.
- F23-2 - not-checked - Wave 25 brief wording not re-read here.
- F23-3 - not-checked - Foreign findings-namespace claim not re-grepped here.
- F25-1 - still-open - Verified the cited code: drift = 40 longest >=60-char sentences (common:1824-31), gate (1753-54), format_retry carries events and schema_transport (codex-consult.ps1:5427-30), codex repair stays prompt-only (5261).
- F25-2 - still-open - Verified: drift check 3 only tests F-id existence (common:1809-16) and check 5 only matches sentences against reply_markdown (1824-31); findings[] content edits stay invisible.
- F25-3 - still-open - Verified Get-ProseGate (common:1737-56) retains both blind corners: head-only refusal phrases and word floors that reject terse complete numbered answers.
- F28-1 - still-open - Verified against codex-consult.ps1:4050-4148: contract-first paragraph and interposed context/role/range/tools plus re-read line are exactly the claimed drift.
- F28-2 - still-open - Verified the bridge is engine-generic beyond codex (repair via engine adapters, codex-consult.ps1:5367-95), so the brief's a743d81 / 0.3.0 / codex-only framing remains stale.

## Verdict: ADVISE

Brief 08's prompt-order and bridge framing claims are stale (F28-1/F28-2, both still open) and one cheap-drift gap remains (finding #1); the format-repair flow otherwise already implements and exceeds the proposal.

### Blockers

_(none)_

### Unproven scenarios

- Whether contract-first ordering reliably yields first-turn bare JSON on MiMo beyond this single run.
- The race and PS 5.1 scenarios behind F13-1/F13-2/F13-3 and the stale-suite claims of F18-2 - none can be settled read-only.
- That a real repair turn's findings[] edits pass undetected (F25-2) - deduced from the drift checks' code paths, not executed.

### First-run checklist (observable)

_(none)_
