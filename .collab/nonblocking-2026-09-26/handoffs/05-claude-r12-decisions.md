# R12 - decisions after the design review (round 1)

Reviews: 02 ZAI :: glm-5.3 (ADVISE, F02-1..11). The two BytePlus members failed on the plan's
request limit (429) and gave nothing. The design in 01 stands where not overridden here.

D1. `.gitignore` gains `.consult.detached-*` (F02-1); a harness case asserts it through
    `git check-ignore`.
D2. Foreground validation = the dry-run checks PLUS the checks a real run makes before the lock
    that a dry run skips or only reports: launcher presence for every engine that will run, an
    active recovery record (refused, exit 1), a usable roster and preflight (F02-2). Not
    attempted in the foreground: the task lock and the time-dependent health/peak selection -
    documented as a benign window resolved by `-Status`.
D3. A terminal status on every background exit path (F02-3): the background main runs inside a
    script-scope try/finally that writes `{state: done, exit, summary}` idempotently; the
    summary is the run's summary block when it got that far, else the last error line.
    `Stop-WithError` honours `-DetachId` (writes the terminal status before exiting).
D4. Budget (F02-4): computed at detach time from the plan - for each endpoint group
    ceil(members / limit) x the member guard, the maximum over groups; with a global
    `-PanelConcurrency` cap also ceil(N / cap) x guard; the larger of the two, plus 120 s -
    stored as `budget_sec` in the status file; `-Wait` defaults to it (`-WaitTimeoutSec`
    overrides).
D5. Status file ownership (F02-5): the foreground writes `starting` (no pid) once, BEFORE
    launching, never after; the background's first action after parsing `-DetachId` is an
    atomic self-report `{state: running, pid, start_time, host}`; `-Status` treats `starting`
    without a pid as "just started" for 60 s, then as "the background never started".
D6. Liveness everywhere (F02-6): `-Status`, `-List` and the hook phrase judge a non-done file by
    `Test-PidAlive(pid, start_time)`; a dead background reads "died" (its records are judged by
    the next run as usual). `-Prune` removes done AND died files older than 7 days.
D7. `-Status` without an id (F02-10): every file of the task, newest first; the exit code is the
    worst state (2 running > 1 failed > 0 ok). An `id8` prefix that matches several files is
    refused with exit 4 naming them.
D8. Writing forms and cwd (F02-11): `-Prune` is the one writing form of `-Status`; `-Detach` is
    refused with `-PanelSpec`, `-DryRun`, `-Status`, `-Wait`; the foreground resolves `-Brief`,
    `-Artifact` and `-CollabDir` to absolute paths before spawning and starts the background
    with `-WorkingDirectory` = its own cwd.
D9. Per-task prefixed files stay (F02-7 verified the alternative unsafe).
D10. Encoding (F02-8): the background sets `[Console]::OutputEncoding` and `$OutputEncoding` to
     UTF-8 before its first output; a non-ASCII summary case under Windows PowerShell 5.1.
D11. Status schema (F02-9): member `state` mirrors `Get-PanelMemberStatus` (pending | running |
     usable | failed | skipped | killed | blocked | commit_blocked | orphan) plus an `outcome`
     text; the record carries `host`; liveness on another host is "cannot be checked from this
     host" (never judged).
D12. Timeouts: an acceptance of a big wave uses `-TimeoutSec 3600` in the brief's command (a
     coordinator rule, consult-codex skill), after three 1800 s timeouts on wave 23.
