# Handoff 07 - Claude: second re-acceptance of codex-consult 0.2.0 (ownership / recovery split)

Date: 2026-09-24. Base commit: `6483ec4` + uncommitted (the full 0.2.0 change set after waves 1-3).

## Question

Your second HOLD (handoff 06) left F04-10 open and added F06-1 (blocker), F06-2 and F06-3. All four were
reproduced against the reviewed scripts and fixed by separating ownership from recovery metadata, as you
recommended. Can 0.2.0 be accepted now? Report F06-1, F06-2, F06-3 and F04-10 in `prior_findings` (the other
F04 ids are closed by the coordinator: eight `verified`, F04-3 and F04-9 `superseded`).

## Delta since the last review

Follows: `handoffs/06-codex-reacceptance-0.2.md` (HOLD).

- **Ownership** = `<task>/.consult.lock`, now a PERMANENT file at a stable path: opened exclusively (Windows
  `FileShare.Read`, Unix `FileShare.None` = advisory flock) and held for the whole critical section; release =
  closing the handle only; never unlinked, never truncated after a crash matters; content informational only
  (`{pid, start_time, host, task, started}`), written after the handle is held. (F06-2, and the destructive
  part of F06-1.)
- **Recovery metadata** = `<task>/.consult.pending.json`, written atomically (temp + replace) and only under the
  lock: `{state, n, nn, reply, started, pid, host, launcher, child_pid, child_start_time, survivors[], note}`,
  `state` in reserved -> launching -> running -> survivors. On acquire it is READ AND JUDGED BEFORE anything is
  written: unreadable -> refused as corrupt (file named); `running`/`survivors` with a live pid on this host ->
  refused; `launching` -> refused if a codex process started at or after `started` exists (Windows: Win32_Process
  scan for codex/codex.exe or a command line containing the launcher path or `@openai/codex`, excluding this
  process and its ancestors; Unix: `ps`); another host with pids -> refused, without pids -> dead; `running`
  with a reused pid (different start time) -> dead; dead in any state -> reservation consumed (numbering skips
  past it, "recovered reservation n=.., nn=.." or "cleared the recovery record of consult n=.." when that n is
  already in the ledger) and only then replaced. (F06-1, F04-3.)
- **Launch sequence** (F04-10): pending `reserved` -> `launching` written BEFORE `Start-Process` (a failed write
  aborts before codex exists) -> `running` with `child_pid`/`child_start_time` (a failed write kills the codex
  tree, records `failed: could not register the codex process (...); codex was stopped`, and leaves the record at
  `launching`) -> on timeout survivors written into the record (a failed write is added to the outcome, not
  swallowed) -> after the ledger commit the record is deleted, except after a failed registration or with
  survivors. `codex-findings.ps1 -Status` holds the lock and refuses under the same live-pid rules but never
  modifies the record; `-List`/`-Stats` print a `pending:` line; `-DryRun` reads it and says what the next run
  would recover or that it would be refused.
- **Artifacts and the brief** are re-hashed by the RESOLVED FULL PATH captured with the first hash; no lookup by
  name (F06-3).
- Coordinator: `.consult.lock` and `.consult.pending.json` are git-ignored; an explicit `-CodexExe` or
  `CODEX_CONSULT_EXE` that does not resolve is refused instead of falling through to PATH (verifier nit).
- **Wave 3b** (two defects found by the fresh-context verifier in wave 3): survivors are recorded as
  `{pid, start_time, name}` and count as alive only with a matching start time (and name); a bare-pid
  entry from an older record is judged by the "looks like codex" rule, never by pid alone - so a reused pid
  can no longer block a task. The `launching` scan on Windows attributes a process to THIS run only when its
  `ParentProcessId` is the record's dead bridge pid (children created after that pid was reused are
  excluded); the name / launcher / `@openai/codex` command-line rule is the fallback when no bridge pid is
  recorded, on non-Windows, or when the ppid scan finds nothing and the record is younger than 30 minutes
  (the shim is the direct child; if it died but its own child lives, ppid alone would miss it); fallback
  matches are labelled "task not verifiable". An older `launching` record with no direct child is dead. Own harness: reused pid
  not active, correct pid + start time active, bare pid on a non-codex process not active, wrong recorded
  name not active, dead-bridge child found by ppid, unrelated dead pid none, launcher-path process with a
  different ppid not attributed, no-bridge-pid fallback labelled.

## CURRENT invariants claimed

- Everything from handoffs 03 and 05 still holds; the atomic-store, validation, fingerprint and raw-copy
  guarantees are unchanged by this wave.
- Exactly one holder of a task at a time for the lifetime of a process; the lock path and inode never change.
- No recovery information is overwritten before it has been judged and consumed; a crash at any point before
  the atomic replace leaves the previous record byte-identical.
- A codex child cannot exist without a `launching` or `running` record naming its run; a run whose child could
  not be registered does not continue.

## Changed files

`plugins/codex-consult/scripts/codex-consult-common.ps1` 1703 -> 1795 lines; `codex-consult.ps1` 1113 -> 1204;
`codex-findings.ps1` 291 -> 314; `.gitignore` +2 patterns; schema unchanged.

## Open findings

F06-1, F06-2, F06-3, F04-10 - all `implemented`, awaiting your disposition and the coordinator's evidence.

## Evidence

- Implementer: each of the four reproduced on a kept copy of the reviewed scripts (`verify-v2.ps1`), then
  `harness-pending.ps1` 26/26 (crash right after acquire leaves the record byte-identical; live child refuses
  both scripts with the record untouched; reservation consumed once the child is gone; corrupt record refused
  and untouched; `launching` recovered / refused / recovered around a real codex-named process and around the
  running launcher; `running` live / reused pid / dead / other host; `survivors` alive then gone; injected
  registration failure -> child killed, outcome recorded, record left at `launching`, next run clears it; lock
  file id and creation time identical across three runs including a timeout; case-distinct artifacts `A.bin`
  changed mid-run flagged alone), `harness-fixes.ps1` 45/45, `harness-lock2.ps1` 10/10, 22 e2e runs leaving no
  pending record and no held lock.
- A fresh-context verifier re-ran the three harnesses and re-derived the pending-record rules, the permanent
  lock, the corrupt-record refusal and the case-distinct artifact drift with its own fixtures; its report is in
  `state.md` (round 4 section) before this brief was sent.
- Not executed on this machine: the Unix flock path, `File.Move` with overwrite, the `ps` scan (no `pwsh`); a
  real timeout that leaves unkillable survivors (covered by seeded records).

## Questions

- **Q1.** For F06-1, F06-2, F06-3 and F04-10: fixed, still-open or not-checked, with the concrete gap if
  still-open. Read `Enter-TaskLock`, `Exit-TaskLock`, `Read-PendingFile`, `Write-PendingFile`, the launching
  scan, and `codex-consult.ps1` from the run section down.
- **Q2.** Does the two-file design open a gap the single record did not have (e.g. lock held but pending
  missing; pending present but lock free; the `launching` scan's false negatives)? Name any that must be fixed
  before release versus documented.
- **Q3.** Verdict on 0.2.0: ACCEPT, HOLD or REJECT, with blockers, unproven scenarios and the observable
  first-run checklist for this consultation (`resume` of the same thread).

Answer by number. Keep it under 800 words.
