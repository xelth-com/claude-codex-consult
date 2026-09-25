# Wave 21 - the parallel panel (R11): acceptance brief

Commit under review: 2de15e9 (main), on top of d6f3514 (design + decisions). Design:
handoffs/01-claude-r11-design.md. Binding decisions: handoffs/05-claude-r11-decisions.md (D1-D13).
This very review runs through the new code: the members of this panel run concurrently.

## What wave 21 implements (per the implementer's report)

- `codex-consult-common.ps1`: new `Get-PanelPlan` (endpoint groups: labels sharing a provider
  fingerprint or the agy sign-in are merged, a merged group takes the smallest `parallel` limit),
  `Get-PanelIgnorePrefixes` (D7, incl. Write-TextAtomic temp names), `Enter-WriteLock` /
  `Get-WriteLockTimeout`, the single store-commit routine `Enter-StoreCommit` /
  `Complete-StoreCommit` / `Exit-StoreCommit`, `Add-LedgerEntry` (insert by n),
  `Get-MemberPendingPath`, `Get-PendingPaths`, `Read-TaskPendingRecords`. Changed:
  `Get-NextNumbers` (array of leftovers), `Add-ReplyFindings` (findings kept in id order),
  `Get-EndpointHealth` (`finished_at`, else `when` + `wall_seconds`, ties by n),
  `Read-ReviewerRoster` (top-level `parallel`), `Enter-TaskLock -Panel`, `New-PendingRecord`
  (`start_time`, `panel`), `Test-PendingActive` (live writer = active; member records never use the
  name rule; state `committing`).
- `codex-consult.ps1`: `-PanelConcurrency`; member proof and record rewrite (D6/D1); members skip
  the lock, the recovery pass and numbering; parent re-check before `launching`; the panel parent
  rewritten (lock held throughout, all records judged, numbers up front, records before launch,
  Start-Process + 500 ms polling, guard, cleanup, summary with the panel's wall clock); commit
  restructured (`committing`, give-up path, ingest and render inside the lock, `finished_at`);
  `sessions.json` is no longer created at run start (the commit creates it).
- `codex-findings.ps1`: lists every record; `-Status` checks all records; `-Status` and `-Rate`
  write through the store commit.
- Tests: new `tests/harness-panel.ps1` (48 assertions: plan, overlap, order by n, no lost update
  under contention, in-flight refusals, member timeout, sequential cap, agy sibling writes,
  parent killed, spec proof, commit blocked, ORPHAN on a kill inside the commit, guard kill); the
  full suite is green under Windows PowerShell 5.1, harness-panel also under pwsh 7.6.6.

## Deviations the implementer declared

1. Labels resolving to one provider fingerprint (and all agy labels) form one sequential group.
2. `sessions.json` is created by the first commit, not at run start.
3. `findings.json` is kept in id order.
4. Ledger `panel.concurrency` = the most members the plan lets run at once; `limits` per label.
5. The member's record rewrite happens after in-memory validation, roster read and repo-root
   resolution (nothing touches the task before it).
6. "Descendants of the writer" is the existing ppid rule over the writer and recorded pids; outside
   Windows member records are judged by recorded pids only.
7. Test hooks `CODEX_CONSULT_TEST_WRITE_LOCK_SEC`, `_COMMIT_PAUSE_MS`, `_PANEL_GUARD_SEC`.

## Residuals the implementer declared

- If the parent dies between a member's parent check and its record rewrite, a new run may consume
  that record; the member recreates it and runs beside the new run with distinct numbers (commits
  stay safe under the write lock).
- Outside Windows, a member record whose recorded pids are all dead cannot find an orphaned
  reviewer (no ppid rule there, and D1 forbids the name rule).
- A guard-killed member's short-lived orphan child (e.g. git) can make the next run refuse briefly.
- The member spec is still base64 on the command line (32767-character limit on long prompts).

## The ask

1. For every open finding listed in your prompt (F02-*, F03-*, F04-*): fixed / still open /
   accepted limitation per the decisions - with the code location that shows it.
2. New defects in the implemented concurrency, recovery and commit paths, the plan, the member
   proof, the agy ignore list, `codex-findings.ps1` and the tests' ability to catch regressions.
   Cite lines of 2de15e9. Say what you verified in code and what you inferred.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
