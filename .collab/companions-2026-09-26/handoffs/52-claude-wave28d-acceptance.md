# Wave 28d - re-acceptance brief

Commit under review: d65e2e9 (main, 0.5.0 candidate; range fc6978a..d65e2e9). The previous review was of
fc6978a (handoffs 46-50 of this task: glm, qwen and muse ACCEPT; mimo HOLD on F48-1..3 major, F48-4 minor).
Binding decisions: `handoffs/51-claude-wave28d-decisions.md` (D1-D8). The CHANGELOG `[0.5.0]` entry "Wave 28d"
is the report of the implementer.

## What wave 28d claims

1. D1 (F48-1): the spool is rewritten through `<spool file>.tmp` and one atomic replace; nothing truncates it
   in place; a leftover `.tmp` is removed by the next rewrite; the deadline is checked before a rewrite.
2. D2 (F48-2): the forgetting marker names its owner (pid, start time, time); `-Forget` removes it in
   `finally`; a producer or sender that meets a marker of a dead owner removes it and goes on.
3. D3 (F48-3, F49-4): a flush lock is created together with its owner record; an ownerless or unreadable lock
   counts as held while younger than 30 s, then it is removed; a lock with a living owner is never taken over,
   and after 30 minutes `.last` and `-Status` say the sender is stuck.
4. D4 (F49-2): the not-spooled count is an append-only file written without the lock.
5. D5 (F49-1): unverified descendants are named beside survivors in the warning and the outcome text.
6. D6, D7 (F50-1, F50-2): the model comparison lower-cases both sides; a member with `context_tokens` that
   runs without a brief file gets the inline ask repeated at the end of the prompt.
7. D8 (F48-4): no prompt hash exists; the only place the appended line fed into was the fork/resume context
   estimate, where it is now subtracted.
8. Tests: twenty harnesses; Windows PowerShell 5.1 `0 failed`; PowerShell 7.6.6 `1 failed` = the
   `harness-fixes26b` GUARD row, environmental (the operator's Codex desktop application rewrote
   `~/.codex/config.toml` at 20:33 while the harness ran); new `harness-fixes28d` 40 on both hosts.

## The ask

1. F48-1..4, F49-1..4, F50-1..2: fixed / still open / accepted limitation, with the code location in the commit.
2. New defects in this wave. Look at: the atomic replace (a `.tmp` from another sender; a spool file that does
   not exist yet); the marker's owner record (a pid reused by another process with the same start-time
   resolution); the 30 s rule for an ownerless lock (two senders starting together); the stuck-sender line
   (does anything ever recover it); the lock-free counter (two producers appending at once on Windows PowerShell
   5.1); the repeated inline ask (a multi-line `-Prompt`).
   Cite lines. Say what you verified in code and what you inferred. Budget your time: a review of one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
