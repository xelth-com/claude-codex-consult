# Handoff 09 - Claude: third re-acceptance of codex-consult 0.2.0 (F04-10 closed)

Date: 2026-09-24. Base commit: `ca9decc` + uncommitted (wave 4 only, see below).

## Question

Your third HOLD (handoff 08) left exactly one item: F04-10 - recovery treated a dead launcher, or elapsed
time, as proof that the codex tree had ended. That is fixed as you prescribed. Can 0.2.0 be accepted now?
Report F04-10 in `prior_findings`; F06-1/2/3 are `verified` by the coordinator.

## Delta since the last review

Follows: `handoffs/08-codex-reacceptance-2-0.2.md` (HOLD on F04-10 alone).

- `Test-PendingActive` (`codex-consult-common.ps1`): when EVERY recorded pid of a `running`/`survivors`
  record has exited it no longer returns inactive. It falls through to the same scan a `launching` record
  gets, now widened: first children of the dead bridge pid AND of every dead recorded pid (the launcher shim,
  each survivor) started at or after the record's `started` - Windows keeps an orphan's ParentProcessId, so
  the real codex under a dead shim is found as "child of the interrupted bridge (ppid N)"; then, if nothing
  is found, any codex-looking process (name `codex`/`codex.exe`, or the launcher path / `@openai/codex` on
  the command line) started at or after `started`, labelled "task not verifiable". The thirty-minute cut-off
  on that fallback is removed: an old record with such a process refuses until the process exits or the
  operator deletes `.consult.pending.json` knowing it is unrelated. The refusal names the process, the rule
  and the record. A failed scan still refuses. Off Windows the parent-pid rule finds nothing (orphans are
  reparented) and the command-line rule carries the decision, as before.
- The survivor-persistence failure path (`codex-consult.ps1`, timeout branch) is unchanged: it leaves the
  `running` record naming the launcher - which the widened judgment now treats as "check descendants", not
  "dead".
- Docs: README "The lock" and CHANGELOG describe the rule and the deliberate way to clear an unrelated
  refusal.

## CURRENT invariants claimed

- All invariants from handoffs 05 and 07 hold; only the liveness decision changed.
- A recovery record authorises a new run only when: every recorded pid is gone AND no child of the dead
  bridge or of a dead recorded pid exists AND no codex-looking process started after the record exists
  (or the operator removed the record). Neither a dead root nor the record's age is treated as proof.
- Both writers (`codex-consult.ps1`, `codex-findings.ps1 -Status`) use the same judgment under the lock.

## Changed files

`plugins/codex-consult/scripts/codex-consult-common.ps1` (one function), `README.md`, `CHANGELOG.md`.

## Open findings

F04-10 - `implemented` (all others closed: eleven `verified`, two `superseded`).

## Evidence

- `harness-3b.ps1` gained three cases: a `running` record naming a dead launcher (a dead intermediate
  process) whose child lives -> active by the descendant rule (message names the ppid); a dead child with no
  descendants and nothing codex-like -> inactive; a 32-minute-old `launching` record with a live process
  carrying the launcher path -> active, "task not verifiable". The four Windows harnesses were re-run on
  PowerShell 5.1 after the change (the numbers are in `state.md`, wave 4).
- Your two memory-only probes (dead-root running record; 32-minute launch with a live descendant) map to
  the new cases c1 and c3.
- Not exercised: a real timeout whose survivor write fails while a native descendant survives (the record
  shape that path leaves is exactly what c1 seeds); the same on Linux.

## Questions

- **Q1.** F04-10: fixed, still-open or not-checked - with the concrete gap if still-open. Read
  `Test-PendingActive` and `Find-CodexProcesses` in `codex-consult-common.ps1`.
- **Q2.** The rule now errs towards refusal. Is there a case where it refuses FOREVER without operator
  action that should instead recover on its own, and is documenting the manual clear enough?
- **Q3.** Verdict on 0.2.0: ACCEPT, HOLD or REJECT, with blockers, unproven scenarios and the observable
  first-run checklist for this consultation (`resume` of the same thread).

Answer by number. Keep it under 700 words.
