# Handoff 30 - Codex: astra-0.6.0-delta-2

Date: 2026-10-07 19:33 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 1 of 12 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: 3287f0d3-e596-4741-ab7d-e0625b864a0d.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8816a137fb814afebc4b4ef975ede52c.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a11723-f13a-74d0-b2b9-8bc2c4d45a40 -` (prompt on stdin).
Parent thread: `01a11723-f13a-74d0-b2b9-8bc2c4d45a40`. Result thread: `01a1176d-eb75-7fe3-a490-aecbc326c0b1` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/29-claude-0.6.0-delta-round2.md` (sha256 b1ac6ca12389). Reviewed: 6b05d4c, base 6b05d4c95ceb7a1892066cd074bfad91ddb59586, tree sha256 de4f622a5cd4, 0 changed files.
Bridge outcome: usable reply. Wall time: 305.3 s. Tokens: in 10852286 (cached 8957312), out 65817, reasoning 17063.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `a75ccbf..da4aac2` - the range changes 15 files, 1248 lines (1185 insertions, 63 deletions).
Verdict: HOLD - E22(a) still releases recovery protection after an unconfirmed tree kill, allowing another consultation while an undiscovered descendant may remain alive. Findings: 1 blocker, 0 major, 1 minor, 0 note (F30-1..F30-2, tracked in `findings.json`). Structured reply: `handoffs/30-codex-astra-0.6.0-delta-2.reply.json`.
Raw event stream: `handoffs/30-codex-astra-0.6.0-delta-2.events.jsonl`.
Verbatim reply follows.

---

1. **Q1 — The original E19 defect is fixed.** Read-only replays confirmed that both unverified and recorded-process checks retain unreadable command lines, bare runtimes and children of recorded PIDs. A readable, nonmatching process with an unrelated parent is dropped. E18 also retains unverified-only records at all three kill sites. Unknown identity can intentionally block until exit or informed operator intervention; elapsed time is not evidence of unrelated identity. These checks do not establish exhaustive correctness under real PID reuse or changing OS inspection permissions.

2. **Q2 — E20 fixes the original save-order defect, but filename-only replay is insufficient for the legacy file.** Immutable, dead-producer files now have the correct order: save accounting, delete, then clear committed names. Failed initial saves preserve the sources. However, after a crash following the first save, an older producer can append to the legacy file before recovery. Its filename remains marked as folded, so status ignores the new lines and replay schedules the entire file for deletion without counting them. An in-memory replay with one accounted line plus one new line returned `StatusTotal=0`, `NewlyFoldedLines=0`, and held the legacy file for deletion (finding #2). This requires neither deletion nor failure of the second rewrite.

3. **Q3 — E22(a) needs code before tagging.** Denied enumeration plus an unsuccessful tree-kill fallback is unknown tree state, not an empty tree. My replay returned `Confirmed=false`, empty survivor/unverified arrays, and a false E18 persistence predicate. A warning does not protect the next invocation (finding #1).

   E22(b) understates the legacy limitation. Prefer a uniquely identified staged file or another generation-aware protocol. If diagnostic loss is deliberately accepted, document the broader crash-and-append case and narrow the unconditional crash-safety claim. This concerns dropped-event accounting, not loss of queued telemetry payloads. E21’s explicitly accepted non-Windows limitation is unchanged.

4. **Q4 — HOLD on finding #1.** F27-1, F27-2 and the original F27-3 ordering defect are fixed within their stated triggers; the findings below describe remaining cases. All five changed PowerShell files parsed without errors, and `git diff --check` passed. I read the new fixtures but did not run writing harnesses. The reported targeted passes and pending final full-suite run remain distinct from my read-only checks.

## Requested checks

- **RC1:** Working directory: repository root; permission: workspace-write; procedure: add a timeout fixture with denied descendant enumeration, failed tree-kill fallback and a surviving hidden descendant; retry the same task. Require an explicit unknown-tree recovery record and no second reviewer launch until the uncertainty is resolved (finding #1). Budget: one fixture, 10 minutes execution.
- **RC2:** Working directory: repository root; permission: workspace-write; procedure: extend the fold-crash fixture to append one legacy counter line after exit 87 but before the restarted flush. Require that additional line to be counted exactly once, with the original folded count unchanged (finding #2). Budget: one fixture, 5 minutes execution.
- **RC3:** Working directory: repository root; permission: workspace-write; command: `powershell -NoProfile -File tests/run-all.ps1`. Require all 22 harnesses passing on the final candidate before tagging. Budget: one quiet-machine run, 45 minutes.

---

### Findings

- **F30-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:10878`, `plugins/codex-consult/scripts/codex-consult.ps1:1897`, `plugins/codex-consult/scripts/codex-consult.ps1:4715`, `plugins/codex-consult/scripts/codex-consult.ps1:5332`, `plugins/codex-consult/scripts/codex-consult.ps1:6099` - When descendant enumeration fails and tree termination cannot be confirmed, empty survivor and unverified arrays still cause recovery protection to be removed, allowing a subsequent consultation despite an unknown live descendant. Trigger: The root exits, descendant enumeration is denied, and the tree-kill fallback fails or cannot establish that its children terminated. Evidence: read-code: Denied enumeration and failed taskkill produce Confirmed=false without necessarily populating Survivors or Unverified.; read-code: Recovery retention tests only the two PID arrays; normal post-commit cleanup removes the pending record otherwise.; ran-command: The result had Confirmed=false, Survivors=[], Unverified=[], and the E18 persistence predicate evaluated false. Verify: Run a timeout fixture with denied enumeration and an unsuccessful tree-kill fallback; require persistent unknown-tree recovery state and refusal of the next consultation. Remedy: Persist explicit unresolved-tree state whenever termination remains unconfirmed, even without identified descendant PIDs. Require a sufficient subsequent check or informed operator clearance before releasing it.
- **F30-2** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:11900`, `plugins/codex-consult/scripts/codex-consult-common.ps1:11944`, `plugins/codex-consult/scripts/codex-consult-common.ps1:11952`, `plugins/codex-consult/scripts/codex-consult-common.ps1:11978`, `.collab/claude-engine-2026-09-30/handoffs/28-claude-0.6.0-delta-decisions.md` - Legacy counter lines appended after a fold's first committed save can be silently discarded during recovery because folded status identifies only the reusable filename, not the accounted contents or file generation. Trigger: A flush crashes after saving not_spooled_folded but before deletion; an older producer appends to telemetry-not-spooled.ndjson before the next flush. Recreating that filename while its marker remains has the same problem. Evidence: read-code: Status skips marked filenames entirely. Merge assigns zero newly counted lines to an already-folded filename and holds its current contents for deletion.; ran-command: With one previously accounted line and one appended line, StatusCount and StatusTotal were zero, NewlyFoldedLines was zero, and the legacy filename was held for deletion.; inferred: The loss can occur immediately after the first-save crash, so it is broader than the documented failed-final-rewrite scenario. Verify: Append one legacy line between the existing exit-87 crash fixture and its restarted flush; require that line to be accounted exactly once. Remedy: Give folded legacy contents a unique staged identity or track committed contents safely across appends and recreation. Alternatively, explicitly accept the broader diagnostic-loss limitation and withdraw the unconditional crash-safety claim.

### Prior findings

- F27-1 - fixed - All three kill sites now retain records when Unverified is nonempty even without survivors; the new end-to-end fixture covers retention and next-run refusal. Finding #1 concerns denied enumeration with neither array populated.
- F27-2 - fixed - Both process recheck functions now retain unreadable command lines and bare runtimes; read-only replays confirmed these cases and recorded-parent handling.
- F27-3 - fixed - The original delete-before-save ordering is corrected, with committed folded names supporting replay. Finding #2 concerns mutable legacy contents under that filename-based protocol.

## Verdict: HOLD

E22(a) still releases recovery protection after an unconfirmed tree kill, allowing another consultation while an undiscovered descendant may remain alive.

### Blockers

- **F30-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:10878`, `plugins/codex-consult/scripts/codex-consult.ps1:1897`, `plugins/codex-consult/scripts/codex-consult.ps1:4715`, `plugins/codex-consult/scripts/codex-consult.ps1:5332`, `plugins/codex-consult/scripts/codex-consult.ps1:6099` - When descendant enumeration fails and tree termination cannot be confirmed, empty survivor and unverified arrays still cause recovery protection to be removed, allowing a subsequent consultation despite an unknown live descendant. Verify: Run a timeout fixture with denied enumeration and an unsuccessful tree-kill fallback; require persistent unknown-tree recovery state and refusal of the next consultation. Remedy: Persist explicit unresolved-tree state whenever termination remains unconfirmed, even without identified descendant PIDs. Require a sufficient subsequent check or informed operator clearance before releasing it.

### Unproven scenarios

- The filesystem-writing harnesses and final full suite were not executed during this read-only review.
- Actual denied-enumeration orphan survival was not exercised; the kill result and persistence decision were reproduced with mocks.
- Concurrent legacy appends across a real fold crash were not exercised; the resulting replay state was reproduced in memory.
- Real PID reuse, changing inspection permissions and non-Windows process reparenting were not exhaustively tested.

### First-run checklist (observable)

- [ ] The final candidate revision has a complete passing report for all 22 harnesses.
- [ ] Unverified-only and unknown-tree kills retain recovery state; the next invocation names the uncertainty and produces no reviewer-launch event.
- [ ] Unreadable command lines and bare runtimes remain blocking, while confirmed exits allow recovery to clear.
- [ ] A failed initial .last save emits the warning and leaves counter files and the previous baseline intact.
- [ ] Crash replay preserves the original folded count exactly once and accounts for a legacy line appended after the crash rather than deleting it silently.
