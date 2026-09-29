# Waves 27c, 28 and 27d - acceptance brief

Commit under review: 1de388e (main, 0.5.0 candidate; range c6f6966..1de388e). The previous review was of
c6f6966 (handoffs 28-32 of this task: glm, dola and qwen ACCEPT; mimo HOLD on F30-1..3 major). Binding
decisions: `handoffs/33-claude-wave27c-decisions.md` (D1-D24); the live host checks behind D16-D24:
`.collab/host-2026-09-26/handoffs/07-claude-host-live-checks.md`; wave 28 is ROADMAP R17. The CHANGELOG `[0.5.0]`
entries "Wave 27c", "Wave 28" and "Wave 27d" are the reports of the implementers: what, where, deviations, counts.

## What the waves claim

1. 27c D1: a kick request carries an id, is written atomically, a second caller joins it; the acknowledgement
   carries the id and the result; only the creator removes it; stale acknowledgements are swept. D2: a kick
   between two turns cancels the repair (the first reply stays usable) or the continuation (the timeout outcome
   stays) - a code change, not only documentation.
2. D3, D4: hiding the host markers is transactional (snapshot, remove in `try`, restore in `finally`), a failed
   removal refuses the engine start; probes never start with the markers silently.
3. D5, D6: the stream reader scans only new bytes, the carry is capped at 1 MiB (`oversized_lines`); an open tool
   call suspends the stall timer for at most max(3 x stall seconds, 1800 s).
4. D7, D8: every failure of the machine-wide health update is retried and named; inside the task write lock
   one attempt of at most 1 s, the full retry after the lock is released.
5. D9-D12: the coordinator identity is a resolved triple; `coordinator.in_roster`, `coordinator.unresolved`,
   `coordinator.host_by: markers | path | none`; only a value that cannot be parsed is refused.
6. D13-D15: the pointer line of the hook prints the full path; `-Explain` substitutes the plugin root and disposes
   its stream; a `CODEX_CONSULT_TEST_*` variable is honoured only with `CODEX_CONSULT_TEST_MODE=1`.
7. D16: every process tree kill is confirmed; `kill_confirmed`, the outcome `(kill not confirmed: <why>; pid <n>
   may still run)`, no continuation turn after an unconfirmed kill.
8. D17-D24: a short README in the plugin directory; `powershell` on Windows; the Codex CLI sandbox paragraph as
   observed; the whole `ZCODE_` prefix scrubbed and the host hint `zcode` from any `ZCODE_` variable; templates
   name no host; where the `AGENTS.md` lines go per host; the tool time limits of the hosts.
9. 28 (R17): telemetry on by default, the switch `CODEX_CONSULT_TELEMETRY` / `-Telemetry on|off`; one
   allowlisted event per ledger commit into `<codex home>/telemetry-spool/`; a detached sender
   (`codex-telemetry.ps1 -Flush`: 3 s connect, 5 s per request, at most 100 events per request, a lock file, the
   7-day drop, one retry after a 429 with `Retry-After` of at most 60 s); `-Complain` (the payload shown, `-Yes`,
   the `public_ref`); `-Status`; the notice once per version; every harness runs with telemetry off.
10. 27d (documentation): README "Waiting: keep the prompt cache or compact" and rule revision 5 in the
    `coordinate` skill; the hosts Qwen Code, OpenCode and Muse Code documented as not run live.
11. Tests: seventeen harnesses, 0 failed on Windows PowerShell 5.1 and on PowerShell 7.6.6 (new:
    harness-telemetry 55, harness-fixes27c 36; harness-host grew with waves 27c and 27d).

## Known gaps - decided for the next wave (28b); do not report them again, but say if the planned fix is wrong

- The intake is live (`GET https://xelth.com/T/health` answers JSON) and rejects a batch WHOLE when one event
  is invalid (400, `events[i]: reason`), answers 403 for an unknown `app_id` and 413 for a body over 64 KiB.
  The sender keeps the whole spool on any 4xx. Planned: drop the invalid event and resend the rest; halve the
  batch on 413; stop the flush on 403 and say why.
- The intake has delete-my-data (`DELETE /T/v2/instances/{id}?public_ref=`); the client has no command for it
  and the README says the contract has none. Planned: a command, and the README corrected.
- Two harnesses stop instead of reporting when the program under test did not write what they expect
  (harness-pending section (e), harness-fixes F04-11). Planned: guard both.

## The ask

1. F29-1..2, F30-1..9 and F32-1..11: fixed / still open / accepted limitation, with the code location in the
   commit (F30-5 was accepted as designed: confirm that the documentation says what the code does).
2. New defects in these waves. Look at: the kick request (a kick file without an id from an older caller; the
   joiner when the creator dies; the sweep racing a slow member); the transactional hiding (nested use; the
   detached background; the start of the telemetry sender); the bounded reader (a multibyte character split at
   a chunk boundary; a line that ends exactly at the cap); the health retry after the lock (a crash between
   the commit and the retry; the wording of the warning against what happened); the host hint by path (a user
   name or a repository path that contains `.claude`, `.codex` or `.zcode`); the test-mode gate (a test hook
   still honoured without it; whether `CODEX_CONSULT_TEST_MODE` itself can reach a reviewer child or open the
   plain-http intake URL in an operator's environment); the confirmed kill (the process id reused between the
   kill and the check; hosts that are not Windows).
   TELEMETRY, the part that leaves the machine - be strict: can a path, a task name, a prompt, a thread id, a
   user name, the machine name or an operator-chosen text reach an event through `title`, `tags` or `details`
   (the roster LABEL of a provider is text the operator typed; failure classes may quote messages); the salt
   file and the instance id; the spool when four panel members commit at once; the sender (the lock, a sender
   that never ends, what it inherits); whether the payload `-Complain` shows is byte for byte what it sends;
   whether the switch is read the same way everywhere (the run, the panel member, the hook, the sender).
   DOCUMENTATION: README "Waiting: keep the prompt cache or compact" - check the formula, recompute two cells
   of each table; the host sections - a command that cannot work as written.
   Cite lines. Say what you verified in code and what you inferred. Budget your time: a review of one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
