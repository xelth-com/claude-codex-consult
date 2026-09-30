# Wave 28c - re-acceptance brief

Commit under review: fc6978a (main, 0.5.0 candidate; range e5c6992..fc6978a). The previous review was of
e5c6992 (handoffs 40-44 of this task: glm and muse ACCEPT; mimo HOLD on F42-1..6 major; qwen HOLD on F43-1
major). Binding decisions: `handoffs/45-claude-wave28c-decisions.md` (D1-D14). The CHANGELOG `[0.5.0]` entry
"Wave 28c" is the report of the implementer: what, where, deviations, counts.

## What wave 28c claims

1. D1 (F42-1, F43-2): the model name in a telemetry event comes from a CLOSED list per vendor class (exact
   match after lower-casing), else `other`.
2. D2 (F42-2, F43-1, F44-4): `-Forget -PublicRef <ref> -Local` deletes locally only after the intake confirmed
   the DELETE; any other answer leaves the salt, the spool and the counters untouched and exits non-zero;
   `-Forget -Local` alone says that the intake still holds what was sent and asks unless `-Yes`.
3. D3 (F42-3): one telemetry lock and a `forgetting` marker; a producer that meets either drops and counts
   its event instead of recreating the salt or the spool.
4. D4 (F42-7, F43-5, F44-2): a flush lock with a living owner is never taken over; every sender checks its
   token before each send and each spool rewrite. Deviation: a lock that names no owner and is not held open
   is taken over at once.
5. D5-D7 (F42-8, F41-1, F42-9, F43-4): the 60 s deadline covers the local steps of a flush; the sender's allow
   list gains the proxy and trust variables; the spool append waits at most 1 s inside the task write lock and
   retries after it (a final failure is on the console and in the status record, the ledger entry being
   committed already).
6. D8, D9 (F42-4, F42-5): a descendant whose start time cannot be read is neither killed by pid nor counted as
   gone - the kill is unconfirmed; a `pgrep` error is a failed enumeration, not an empty child set.
7. D10 (F42-6, F44-1): unreadable lines of the health journal go to `<journal>.bad`, are counted in a warning,
   and the journal is truncated only by what was applied or moved.
8. D11 (F43-3, F44-6): the installed codex reports no compaction event in `exec --json`, so a member with
   `context_tokens` records `compactions: unknown`, and its prompt ends with a line that names the brief again.
9. D12-D14: the test-mode line also in the dry run; the CHANGELOG states the runs as they were; the idle
   watchdog rule revision 6 (warm while work runs or is awaited; when idle the handover and the wake removed).
10. Tests: nineteen harnesses, `0 failed` on Windows PowerShell 5.1 AND on PowerShell 7.6.6, both full suites on
    the final code (0.3 229, roster 119, format 37, engines 97, muse 74, panel 54, pending 26, fixes 45, lock2
    11, 3b 12, visibility 121, detach 51, companions 42, fixes26b 51, host 65, telemetry 92, fixes27c 36,
    fixes28b 20, fixes28c 15).

## The ask

1. F41-1, F42-1..9, F43-1..7 and F44-1..6: fixed / still open / accepted limitation, with the code location in
   the commit (F43-6 and F44-3 were accepted as limitations: confirm that the README says so).
2. New defects in this wave. Look at: the closed model list (is any path left by which text outside the list
   reaches `details.model`, `tags` or `title`); `-Forget` (every exit path - is the salt ever removed without a
   confirmed DELETE when `-PublicRef` was given; the marker left behind after a crash); the telemetry lock
   (a producer that holds it while `-Forget` starts; the deviation of D4: can a lock without an owner belong to
   a sender that is still starting); the deadline (a rewrite cut in the middle - is the spool still valid);
   the process tree (does "unconfirmed" ever leave a child of the bridge running without a warning); the health
   journal (two repositories moving lines to `.bad` at once); the prompt line that names the brief again (does
   it change the prompt hash or the reviewer's lineage).
   Cite lines. Say what you verified in code and what you inferred. Budget your time: a review of one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
