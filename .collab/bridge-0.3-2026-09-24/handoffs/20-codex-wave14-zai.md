# Handoff 20 - Codex: wave14-zai

Date: 2026-09-25 07:17 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 2 of 3, panel 18b99832 member 1 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 182f195c-c913-4405-ac1e-e74f85c1d39d.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-487073511e23464ab3526551c665d937.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a0d4e3-a0de-7d81-a8d5-562d0435acb3 -` (prompt on stdin).
Parent thread: `01a0d4e3-a0de-7d81-a8d5-562d0435acb3`. Result thread: `01a0d6ff-0235-7161-bd56-32dcb6743097` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/19-claude-wave14-review.md` (sha256 693fe587ddef). Reviewed: a743d81 + uncommitted, base a743d81627efefa7201eef2af68734c95db6d5cc, tree sha256 2b69286da97f, 7 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 189.8 s. Tokens: in 6702006 (cached 5616960), out 63943, reasoning 49653.
Verdict: ACCEPT - Wave 14 is provenance-safe, correctly gated, honestly recorded and well fixture-tested; what remains are minor blind spots that the warnings-plus-original-prose design already mitigates. Findings: 0 blocker, 0 major, 2 minor, 1 note (F20-1..F20-3, tracked in `findings.json`). Structured reply: `handoffs/20-codex-wave14-zai.reply.json`.
Raw event stream: `handoffs/20-codex-wave14-zai.events.jsonl`.
Verbatim reply follows.

---

**Q1.** Concrete blind path: the prose carries the disputed content in SHORT sentences. Suppose the prose says 'F15-1 is a blocker; it must be fixed before release.' and the repaired JSON files it as severity minor with a reworded remedy. Check 5 compares only the five longest prose sentences of at least 60 characters (whitespace-normalized) against reply_markdown; a severity statement under 60 chars, or one ranked below the top five, is never compared, findings[] severities have no prose counterpart check, and RC ids, Q-count, F-ids and verdict can all match. The softened object ingests with zero drift notes. A seventh check is worth it, but the cheap one is widening check 5: compare ALL prose sentences >= 60 chars (or the top ~12) instead of five — it mechanically catches replaced remedies and changed location line numbers, since any changed character breaks containment. A severity-specific check is not worth it (prose severities are unstructured); keep 'drift notes are warnings; the coordinator reads the original', with the original prose the evidence of record.

**Q2.** Test-PendingActive (codex-consult-common.ps1:3958+) treats the record like any running turn: pending stays state 'running' with child_pid = the repair process. If the bridge is killed during the repair, the next run either refuses while the recorded repair pid is alive, or — once it is gone and the descendant scan finds nothing — consumes the reservation: numbering skips past nn and NO ledger entry is ever written for the consultation. The first turn's prose is not lost as a file: .original.md is copied before the repair process starts (codex-consult.ps1:1846-1848). But it is an ORPHAN — the ledger never references it, the pending record names only the planned reply path, and recovery silently skips past it, so the coordinator is not told a usable answer exists (finding #2).

**Q3.** Wrongly accepted: any >= 120-word refusal or safety message ('I cannot comply with this request because ...' padded past 120 words, or a long meta-apology about not reading files) — substantive by word count alone, so a repair turn is spent converting an apology. Wrongly rejected: a complete terse answer whose markers miss the regex — '**Q1:**' (colon, not period), '**1)**', or any numbered answer under 40 words ('**Q1.** Handled. **Q2.** Agree.') — no repair despite being perfectly convertible (finding #3).

**Q4.** **ACCEPT.** No blocker: the repair never changes provenance (same thread, reviewer and consultation id; the entry keeps the first thread), the gates match the claimed invariants exactly (usable reply, verified thread, substantive prose, not Raw/chore/-FormatRetry 0; a valid object with a wrong verdict is not repaired), the prose is preserved byte-for-byte, and harness-format.ps1 covers faithful repair, drift notes, prose-twice, the never-repair cases and panel members. Unproven: the real-route first-turn contract (this very reply is the test), real-route repair behavior beyond fake codex, and the mid-repair kill path, which has no fixture. First-run checklist for THIS consultation: sessions.json entry with structured true and format_retry null (attempted true means the contract failed on my route); verdict present; no handoffs/NN-codex-<slug>.original.md; the dry-run/prompt check that the prompt's first paragraph is the FINAL OUTPUT CONTRACT; and the reply parsed as bare JSON on the first turn.

## Requested checks

- **RC1** — Working dir: repo root; read-only; 2 min: after this consultation, inspect this run's sessions.json entry (structured, format_retry, validation_error). Observation: structured true with format_retry null settles the first-turn contract on the z.ai route.
- **RC2** — Working dir: repo root; workspace-write (scratch harness); ~15 min: add a fixture that kills the bridge between the original.md copy and repair completion, then run the next consultation; observation: whether recovery surfaces or silently orphans the .original.md (finding #2).
- **RC3** — Same harness; ~10 min: feed Test-SubstantiveProse a 130-word refusal and a 12-word '**Q1.** ... **Q2.** ...' answer; observation: first accepted, second rejected (finding #3).

---

### Findings

- **F20-1** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:1568` - The format-repair drift checks cannot see severity changes or edits confined to prose sentences outside the five longest >=60-character sentences, so a softened or reworded finding ingests with zero drift notes. Trigger: The first-turn prose states a severity or remedy in short sentences and the repaired object downgrades the severity or replaces the remedy while RC ids, Q-count, F-ids and verdict match. Evidence: read-code: Check 5 selects only the five longest >=60-char sentences; no check compares findings[] severities or short-sentence content to the prose. Verify: Craft a prose/JSON pair with a downgraded severity in a <60-char sentence and run Get-FormatRepairDrift; expect an empty note list. Remedy: Widen check 5 to all (or the top ~12) prose sentences >=60 chars; keep drift as warnings with the original prose as evidence of record.
- **F20-2** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:1846`, `plugins/codex-consult/scripts/codex-consult.ps1:1881` - If the bridge is killed during the repair turn, the already-usable first-turn prose survives only as an orphaned .original.md that no ledger entry or recovery message references, and the reservation is consumed silently. Trigger: The bridge process dies after Start-Process of the repair codex turn and before the ledger write. Evidence: read-code: The original is copied before the repair starts, but the ledger entry is written only at the end; the pending record names only the planned reply path.; read-code: Recovery checks pid liveness and consumes the reservation without mentioning any preserved reply file. Verify: Kill a bridge fixture mid-repair and run the next consultation; observe that nothing in its output or the ledger points at the orphaned .original.md. Remedy: Record the original path (and 'repair in progress') in the pending record, so recovery can report 'a usable prose reply exists at <path>; no ledger entry was written'.
- **F20-3** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:1482` - Test-SubstantiveProse accepts long non-answers (>=120-word refusals or apologies) and rejects short complete answers (under 40 words, or numbered with 'Q1:'/'1)' styles the regex misses), both deciding the repair turn wrongly. Trigger: A 130-word safety refusal arrives as the reply, or a 12-word '**Q1.** Handled. **Q2.** Agree.' answer arrives as the reply. Evidence: read-code: The test is word count plus one narrow line-start regex; no refusal detection, no colon/list-marker styles. Verify: Run Test-SubstantiveProse on the two inputs from Q3; expect true for the refusal and false for the short answer. Remedy: Cheap gate on leading refusal phrasing ('I cannot', 'I'm sorry' as the dominant content) and accept any numbered style (Q1:, 1), **1.**) with a lower word floor.

### Prior findings

- F02-4 - fixed - caps-v1 keys effort by endpoint host with per-host model allowlists; verified while reviewing this tree in the wave-13 checkpoint.
- F06-1 - fixed - A usable [model_providers.openai] table is read for identity; an unusable ancestor leaves identity unresolved.
- F06-2 - fixed - Reviewer identity compared field-by-field; the display string is never compared.
- F06-3 - fixed - Peak re-evaluated at launch before Start-Process; the reservation is withdrawn.
- F06-4 - fixed - Exceptions stored as date intervals; no enumeration guard.
- F12-1 - still-open - Anonymous limb fixed via roster auth 'none'; the rotated-credential limb still has only -SkipPreflight, now named in the refusal - no narrower declaration was added in waves 13-14.
- F15-1 - fixed - Wall times resolved through TimeZoneInfo transition rules; DST fixtures claimed by README/tests.
- F15-2 - fixed - Legacy re-parse pinned to the reference offset; pwsh offset-preservation covered by the harness per README.
- F15-3 - fixed - Formally narrowed and fixture-tested: surviving processes stop later members (state 'survivors' refuses).
- F15-4 - fixed - Future-stamped records clamp their age to 0 instead of being skipped.
- F18-1 - fixed - The FINAL OUTPUT CONTRACT paragraph is now the first prompt part (codex-consult.ps1:1369, structured mode only) and the reply_markdown wording no longer says 'write it exactly as you would a normal reply'; harness CONTR checks confirm both.

## Verdict: ACCEPT

Wave 14 is provenance-safe, correctly gated, honestly recorded and well fixture-tested; what remains are minor blind spots that the warnings-plus-original-prose design already mitigates.

### Blockers

_(none)_

### Unproven scenarios

- Whether the first-turn contract makes the z.ai route emit bare JSON is proven only by this very consultation, not yet observable from inside it.
- Real-route repair behavior (the harness uses a fake codex resume reply).
- No fixture kills the bridge during the repair turn (finding #2's orphan path).
- Effectiveness of the widened containment check is asserted, not measured.

### First-run checklist (observable)

- [ ] This run's sessions.json entry: structured true, format_retry null, validation_error empty, verdict recorded (format_retry.attempted true would mean the contract failed on my route).
- [ ] No handoffs/NN-codex-<slug>.original.md is created for this consultation.
- [ ] The prompt's first paragraph is the FINAL OUTPUT CONTRACT and the last line is the consultation id.
