# Wave 25 - acceptance brief: non-blocking consultation (R12) and the harness scripts override (T4)

Commit under review: 53de158 (main, 0.5.0 candidate). Design: handoffs/01-claude-r12-design.md;
binding decisions D1-D12: handoffs/05-claude-r12-decisions.md (F02-1..11 of this task). The CHANGELOG
`[0.5.0]` wave 25 entry and README "Non-blocking consultation" are the implementer's report.

## What wave 25 claims

1. `-Detach` (single run or `-Panel`): the foreground runs the dry-run checks PLUS every refusal a
   real run makes before the lock (launchers, active recovery record, preflight, roster, the `.cmd`
   `%` hazard), resolves brief/artifacts/collab dir to absolute paths, writes the `starting` status
   record (no pid), and starts one hidden background bridge process (ShellExecute of cmd, stdout+
   stderr to the log; the arguments travel inside the `starting` record as base64 CLIXML, only
   -Task/-CollabDir/-DetachId on the command line). The background self-reports {running, pid,
   start_time, host, budget_sec}, runs the consultation in-process, updates members as they
   start/finish/are blocked, and writes a terminal status on every exit path (`Stop-WithError`
   hook + the script-scope finally).
2. `-Status [-Id <id8>]` (0 done ok, 1 done with failures, 2 running, 3 wait timeout, 4 ambiguous
   or unknown id / refused option), `-Wait [-WaitTimeoutSec]` (default: the recorded budget),
   `-Prune` (done and died older than 7 days); liveness by Test-PidAlive(pid, start_time) with
   the host check; `codex-findings.ps1 -List` lines and the SessionStart phrase (running /
   finished in 24 h / died).
3. Files `<task>/.consult.detached-<id8>.status.json` and `.log`, gitignored (`.consult.detached-*`),
   ignored by the agy/muse collab snapshot through the `.consult.` prefix; UTF-8 log and status.
4. T4: `-ScriptsDir` / `CODEX_CONSULT_SCRIPTS_DIR` on run-all.ps1 and every harness.
5. Tests: `harness-detach` 46 (UNIT, IGNORE, REFUSE, SINGLE, PANEL, WAITTIME, AGY, REFUSEDBG,
   KILL, FABRIC, OUTER, COLLIDE, CWD, ENC, T4, GUARD).

## Declared deviations and residuals (judge them)

- `-Status -Id <id8>` instead of a positional id (a bare id would bind to -CollabDir; caught with
  exit 4). The background arguments in the status record, not on the command line (8191-char
  limit, quoting, pwsh date coercion). Launch via cmd ShellExecute because Start-Process with
  redirection held the caller's pipe (13 s for a 12 s child). Exit 4 also covers "no such id".
  "Died" also covers never-started and unreadable files. The foreground does not probe the task
  lock (D2's benign window: exit 0 = started, not usable). Killing only the background process
  leaves members running while -Status says died. macOS/Linux background (`nohup`) untested.

## The ask

1. F02-1..11: fixed / still open / accepted limitation, with the code location in 53de158.
2. New defects in the foreground validation, the background launch and its argument transport,
   the status record's lifecycle (every exit path), liveness and the died/never-started
   judgement, the exit codes, the log/summary equivalence, the panel member updates, the T4
   plumbing. Cite lines. Say what you verified in code and what you inferred. Budget your time:
   a review of one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
