# Handoff 21 - Codex: wave14-mimo

Date: 2026-09-25 07:20 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 3, panel 18b99832 member 2 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 253c5515-3572-4248-b412-aae3ca98a21d.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-3f8fe0a45c80439d861836b73e2b7466.md fork 01a0d4e7-5341-7111-96f1-c477b2b11ba6 -` (prompt on stdin).
Parent thread: `01a0d4e7-5341-7111-96f1-c477b2b11ba6`. Result thread: `01a0d701-f396-7491-b01d-5bdeb383ef3a` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/19-claude-wave14-review.md` (sha256 693fe587ddef). Reviewed: a743d81 + uncommitted, base a743d81627efefa7201eef2af68734c95db6d5cc, tree sha256 17933633535b, 12 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 305.8 s. Tokens: in 5474284 (cached 2646144), out 48313, reasoning 26223.
Verdict: HOLD - Wave 14 implements the contract and repair path, but repair crashes can orphan evidence and drift checks can miss semantic changes to findings. Findings: 0 blocker, 2 major, 1 minor, 0 note (F21-1..F21-3, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/21-codex-wave14-mimo.reply.json`.
Raw event stream: `handoffs/21-codex-wave14-mimo.events.jsonl`.
Verbatim reply follows.

---

**Q1.** One blind path is a severity or remedy change. The prose can name F18-1 as major with remedy “add a retry credential”; the repaired JSON can retain F18-1, the same Q/RC counts, the same verdict, and the same long sentences while changing its severity to note or replacing the remedy. The six checks do not compare finding tuples, locations, claims, evidence, verification, remedies, prior statuses, `verdict_reason`, `unproven`, or checklist content. A seventh cheap check is worthwhile: hash normalized `(id,severity,path:line,claim,remedy)` and prior `(id,status)` tuples and compare them, while keeping drift warnings non-fatal and preserving the original prose as the evidence of record.

**Q2.** During repair, `.consult.pending.json` remains `state=running` with `child_pid` set to the repair process. `Test-PendingActive` checks that pid/start time and scans descendants. If the bridge dies while the repair child is alive, the next run refuses until it exits. If the child is gone, the next run treats the reservation as inactive, consumes it, and continues numbering. The first prose message survives byte-for-byte in the pre-repair `.original.md`, but if the bridge dies before the final ledger commit, there is no `format_retry` entry or handoff association; the repaired artifact and outcome are also lost unless already copied.

**Q3.** Wrong acceptance: a 130-word refusal beginning “I cannot assist with that request” passes solely because `words >= 120`. Wrong rejection: a complete 35-word answer beginning `Q1.` and `Q2.` is rejected because it is below both thresholds.

**Q4.** **HOLD.** No blocker is proven, but the two evidence risks above should be fixed before relying on repaired findings. Unproven: process-kill timing during repair, semantic-drift recall, and whether the 120/40 thresholds match real refusals. First-run success is `structured=true`, empty `validation_error`, and `format_retry=null` on the first turn; `format_retry.attempted=true` means the contract still failed on this route.

---

### Findings

- **F21-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:1517`, `plugins/codex-consult/scripts/codex-consult.ps1:1931` - Format-repair drift checks can miss semantic changes to findings, prior statuses, remedies, locations, evidence, and verdict rationale, allowing a changed repaired object to be ingested without a drift note. Trigger: The prose reports F18-1 as major with a specific remedy; the repaired JSON keeps F18-1 and all counted IDs but changes its severity, location, or remedy. Evidence: read-code: Checks cover RC IDs, Q counts, named finding IDs, verdict token, and five longest sentences only. Verify: Add a repair fixture that preserves IDs and counts but changes one finding's severity, location, and remedy and require a drift note. Remedy: Compare normalized finding and prior-finding tuples and flag any changed severity, path/line, claim, remedy, evidence, or status.
- **F21-2** [major] `plugins/codex-consult/scripts/codex-consult.ps1:1845`, `plugins/codex-consult/scripts/codex-consult.ps1:1878`, `plugins/codex-consult/scripts/codex-consult.ps1:1937`, `plugins/codex-consult/scripts/codex-consult.ps1:1253` - If the bridge is killed during format repair after the original prose copy but before ledger commit, the prose survives as an orphan `.original.md` while `format_retry`, the handoff linkage, and the repaired outcome are lost. Trigger: Terminate the bridge after line 1848 and before the final sessions.json write while the repair child is running or has just completed. Evidence: read-code: The original is copied before the repair process starts.; read-code: `format_retry` is created only after the repair finishes.; read-code: A later run recovers the reservation but cannot reconstruct the missing ledger entry. Verify: Kill the bridge during the repair fixture and inspect whether the next run records the original prose and repair outcome in sessions.json. Remedy: Persist a repair journal or commit the original/repaired artifacts and format_retry atomically before releasing recovery state.
- **F21-3** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:1482` - The substantive-prose heuristic accepts long refusals and rejects short complete answers. Trigger: A 130-word safety refusal or a 35-word complete Q1/Q2 answer reaches the parser. Evidence: read-code: The function uses only word count and a numbered-line regex. Verify: Run both sample texts through Test-SubstantiveProse and compare the expected repair decision. Remedy: Detect refusal/safety language and require answer structure rather than word count alone.

### Prior findings

- F02-4 - fixed - Endpoint-host and exact-model effort mapping remains implemented.
- F06-1 - fixed - Unsupported provider-set declarations still prevent false builtin provenance.
- F06-2 - fixed - Provider and model remain compared separately with endpoint fingerprint.
- F06-3 - fixed - Peak status is still checked immediately before launch.
- F06-4 - fixed - Long exception ranges remain interval-based.
- F12-1 - still-open - Anonymous access has `auth: none`, but rotated-credential recovery still requires broad `-SkipPreflight`.
- F15-1 - fixed - Reset wall times now use daylight-saving-aware zone conversion.
- F15-2 - fixed - Legacy reset parsing uses the recorded failure reference offset.
- F15-3 - fixed - The panel explicitly stops later members on persistent survivors and reports the reason.
- F15-4 - fixed - Future-stamped failures are clamped to age zero rather than skipped.
- F18-1 - fixed - The JSON-only contract is now the first structured prompt paragraph.

## Verdict: HOLD

Wave 14 implements the contract and repair path, but repair crashes can orphan evidence and drift checks can miss semantic changes to findings.

### Blockers

_(none)_

### Unproven scenarios

- Whether semantic drift detection catches paraphrased or reordered findings.
- Whether repair-process crashes leave recoverable artifacts in all process-tree cases.
- Whether the substantive thresholds behave correctly on real refusal and short-answer traffic.
- Whether the contract-first prompt reliably produces first-turn JSON across routes.

### First-run checklist (observable)

- [ ] The first turn records `structured=true`, empty `validation_error`, and `format_retry=null`.
- [ ] The prompt opens with the FINAL OUTPUT CONTRACT paragraph.
- [ ] If `format_retry.attempted=true`, inspect `reason`, `succeeded`, `thread`, `usage`, `drift`, and `original` before trusting the repaired findings.
- [ ] The original prose and any repaired object remain byte-for-byte available as separate artifacts.
