# Handoff 26 - Codex: ab-07-codex

Date: 2026-10-08 02:24 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 8121a8fd-4d07-4101-af01-155a4909e27e.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-11805b3eeae24c35930e626550bd9a82.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118e5-463c-7941-8ea2-5168d764aae1` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/07-claude-ab-wave14-review.md` (sha256 1b05147c21a3). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 227.4 s. Tokens: in 950386 (cached 901568), out 10605, reasoning 6868.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint review: the wave-14 format-repair invariants hold on the current tree; only previously filed gate/drift gaps (F25-1..F25-4) remain, unchanged. Findings: none. Structured reply: `handoffs/26-codex-ab-07-codex.reply.json`.
Raw event stream: `handoffs/26-codex-ab-07-codex.events.jsonl`.
Verbatim reply follows.

---

## Current invariants
1. **Provenance unchanged** — holds: the repair resumes `resume $threadId` under the same identity, the prompt repeats the same consultation id, the raw prose is written to `handoffs/NN-…original.md` before the repair process exists and is rendered after the structured section; a codex reply on a different thread yields a drift note, an engine reply on a different thread fails the turn (`-ExpectThread`), so nothing foreign is ingested.
2. **Never fires on** failed run/timeout/provider failure (`bridgeOutcome -ne 'usable reply'`), short reply (`Get-ProseGate`), unverified thread (`threadSource` must be events or rollout-verified), `-Raw`, `chore` (sets Raw, codex-consult.ps1:2195), `-FormatRetry 0` — all hold at codex-consult.ps1:5234.
3. **Unfit verdict not repaired** — holds: `ConvertFrom-StructuredReply` returns `Valid=$true, VerdictInvalid=$true` for a wrong verdict, and repair requires `-not $parse.Valid`.

## Answers
**Q1.** Copy reply_markdown verbatim but soften a finding's severity (blocker→major), replace a remedy/trigger/verification phrased in sentences under 60 characters, or change a location line: findings[] is never compared with the prose, so all six checks pass and the edited object is ingested (F25-2, still open). Recommendation: keep the rule — drift notes are warnings and the byte-exact original stays the evidence of record; token-level findings comparisons would be noisy (severity words occur in ordinary prose). A marginal cheap add would compare an explicit "N findings" count with findings.length; not required.

**Q2.** Killed mid-repair: the record is `running` with `child_pid` = the repair process and — written before that process exists — `original` = the saved prose path plus `first_reply` = "usable prose (format repair in progress)". The next run: writer pid gone, then the recorded repair pid — alive ⇒ the run is refused as an interrupted consultation, with `Get-PendingOriginalNote` naming the prose; gone ⇒ the orphan scan releases the record and the recovery line / `codex-findings -List` still names the path. The first turn's usable reply is kept, never lost (ORPHAN cases cover this).

**Q3.** Wrongly accepted: a refusal of ≥40 words whose reasons are numbered `1.` `2.` — or containing "verdict", an F-id or RC<n> anywhere — markers suppress the refusal test and the numbered floors pass, wasting one repair turn (F25-3, codex-consult-common.ps1:1752-1754). Wrongly rejected: a complete ~90-word answer numbered `A1:`, `Answer 1:` or `**Q1** -` — no recognized numbering and <120 words ⇒ "reply too short", no repair turn runs (F25-4, :1738).

**Q4.** ACCEPT as a wave-14 diff. Blockers: none. Unproven: live-route behavior (harnesses use fake codex). First-run success: `structured true` with `format_retry null`; `format_retry.attempted true` means the contract failed on the route — then require `succeeded true`, drift read, `.original.md` present.

Note: the brief's "23 cases" is stale — harness-format.ps1 now has 37 checks over CONTR/REPAIR/TWICE/DRIFT/DRIFT5/NONE/PANEL/GATE/ORPHAN (F25-1).

## Requested checks
- RC1: From the repository root run `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-format.ps1` (workspace-write; ~3 min): expect 37 PASS lines and the nine case names above — settles that the current repair/gate/orphan behavior matches this reading.

---

### Findings

_(none)_

### Prior findings

- F13-1 - not-checked - Outside this brief's scope; not re-verified.
- F13-2 - not-checked - Outside this brief's scope; not re-verified.
- F14-1 - not-checked - Outside this brief's scope; not re-verified.
- F15-1 - not-checked - Outside this brief's scope; not re-verified.
- F16-1 - not-checked - Outside this brief's scope; not re-verified.
- F16-2 - not-checked - Outside this brief's scope; not re-verified.
- F16-3 - not-checked - Outside this brief's scope; not re-verified.
- F17-1 - not-checked - Outside this brief's scope; not re-verified.
- F17-2 - not-checked - Outside this brief's scope; not re-verified.
- F19-1 - not-checked - Outside this brief's scope; not re-verified.
- F21-1 - not-checked - Outside this brief's scope; not re-verified.
- F21-2 - not-checked - Outside this brief's scope; not re-verified.
- F21-3 - not-checked - Outside this brief's scope; not re-verified.
- F22-1 - not-checked - Outside this brief's scope; not re-verified.
- F23-1 - not-checked - Outside this brief's scope; not re-verified.
- F23-2 - not-checked - Outside this brief's scope; not re-verified.
- F24-1 - not-checked - Outside this brief's scope; not re-verified.
- F25-1 - still-open - Verified: 37 Check calls (CONTR 5, REPAIR 10, TWICE 2, DRIFT 2, DRIFT5 2, NONE 2, PANEL 2, GATE 5, ORPHAN 7) against the brief's 23 cases; claim unchanged, not re-filed.
- F25-2 - still-open - Get-FormatRepairDrift (codex-consult-common.ps1:1793-1835) still never compares findings[] fields with the prose; answered as Q1; claim unchanged.
- F25-3 - still-open - Markers (numbered lines, F-id, RC<n>, 'verdict') still suppress the refusal test at :1752-1753; answered as Q3; claim unchanged.
- F25-4 - still-open - NumberedAnswerRe (:1738) still recognizes only Q<n>./:, <n>./), **<n>.** and Q<n> headings; 'A1:'/'Answer 1:'/'**Q1** -' still fall to the 120-word floor; answered as Q3.

## Verdict: ADVISE

Checkpoint review: the wave-14 format-repair invariants hold on the current tree; only previously filed gate/drift gaps (F25-1..F25-4) remain, unchanged.

### Blockers

_(none)_

### Unproven scenarios

- Live-route first-turn contract behavior: only code and fake-codex harness fixtures were read; no harness was executed in this read-only review.
- The engine (agy/muse) repair path was read but not exercised.

### First-run checklist (observable)

_(none)_
