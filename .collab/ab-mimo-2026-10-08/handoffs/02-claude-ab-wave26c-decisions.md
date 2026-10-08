Write in English.

_A/B pair 02 (wave 29c): this brief is a verbatim copy of `.collab/companions-2026-09-26/handoffs/27-claude-wave26c-decisions.md` of an earlier task, re-asked against the CURRENT tree. Answer its numbered questions against the code as it is now; where the brief names a commit range or a file that no longer matches, say so and answer on the current code._

# Wave 26b re-acceptance (handoffs 24-26) - decisions for wave 26c

Panel a011f18e on 35d4a32, required members glm-5.3 and mimo-v2.6-pro: glm ACCEPT (F22-1's containment
verified in code; 27 prior findings checked fixed; F25-1 minor, F25-2 note), mimo HOLD (F22-1..5 and F22-7
fixed; F19-1 and F22-6 narrowed into F26-5 and F26-4; three majors on the day's additions: F26-1 kick
acknowledgement, F26-2 health-merge loss, F26-3 false stall; F26-4/5 minor, F26-6 note). Verdict: F22-1..5
and F22-7 verified; the rest is wave 26c, implemented in the wave 27 worktree with its own CHANGELOG entry
and re-accepted with wave 27 by mimo.

D1. Kick acknowledgement (F26-1, F25-2): the member checks its kick file before the wait loop, on every
    poll, and ONCE MORE after `WaitForExit` returns; a kick found after a normal exit is consumed and
    recorded as `kick_late: the member had already finished` without changing the outcome (an earlier
    usable reply stays usable). `-Kick` waits up to 10 s for the acknowledgement (the pending record's
    state `kicked`, or the member's `<kick file>.ack`): exit 0 acknowledged, exit 1 no such running
    member (the file is removed), exit 3 no acknowledgement in time (the file stays for the next poll).
D2. Health update loss (F26-2): the lock wait becomes 5 s with three attempts; a failed update is retried
    once at the run's ledger commit; if it still fails the run warns (`warnings[]`: `machine-wide health
    not updated (lock timeout)`), the summary says so, and the repository ledger keeps the truth. The
    record conversion carries the stored `until` and `retry_after`, and the merge applies the documented
    tie-break (the newest `when`, ties to the later `until`).
D3. Stall detection (F26-3, F25-1): the silent timer resets on ANY growth of the stream (bytes, not
    complete lines) and is SUSPENDED while a tool call is in flight - codex `item.started` of
    `command_execution`, `mcp_tool_call` or `web_search` until its `item.completed`; agy tool steps until
    their result; muse `tool.*` tasks until they end - so a member running one long command is never
    cut. The continuation prompt says "no output for N s outside a tool call".
D4. Legacy rating completion (F26-4, F22-6): a field counts as missing when it is absent OR empty or
    whitespace; the harness case covers an empty `model`.
D5. Size raised by required reviewers (F26-5, F19-1): when the required set exceeds the size the run
    warns `panel size raised: asked k, required r` (console, handoff header, ledger `warnings[]`), records
    `size_asked` and `size_source: required`, and the dry-run summary states the requested count.
D6. F26-6: accepted limitation (wontfix) - a hard link is indistinguishable from the file itself and the
    role-file check defends against reparse points and containment, not against a hostile repository;
    one sentence in README "Roles".

Re-acceptance: with wave 27, by mimo (F26-1..5, F25-1..2) and glm.
