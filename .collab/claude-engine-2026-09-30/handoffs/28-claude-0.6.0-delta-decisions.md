# The 0.6.0 delta - decisions after astra's HOLD (handoff 27, F27-1..F27-4)

Astra on handoff 26 (2026-10-07, n=19, fork of her acceptance lineage, range 95d9be2..a75ccbf): HOLD - two blockers
in E1's scope and re-check, two minors (the fold's write order, the non-Windows tolerance). The coordinator is the
judge; E1-E4 of handoff 56 (companions-2026-09-26) stand as amended here.

E18. (F27-1, blocker) **A kill keeps its recovery record when EITHER survivors[] OR unverified[] is non-empty.** E1's
     "survivors case only" scope is withdrawn: a timeout kill with unverified descendants and no confirmed survivor
     writes the record in state `survivors` with an empty `survivors[]` and the `unverified[]` entries; the next
     run treats it exactly as a record with survivors.
E19. (F27-2, blocker) **The re-check is fail-closed on the evidence.** An unverified pid whose start time is readable
     now is dropped only when it is proven unrelated: it started before the record's `started`, or its command
     line was READ and `Get-CodexRule` does not match it (and it is no child of a recorded pid). A process whose
     command line cannot be read counts as running and blocks the task like a survivor, with the reason named
     (`command line not readable - counted as running (fail-closed)`).
E20. (F27-3, minor) **The fold saves before it deletes.** The flush writes the new `.last` first (the folded note, the
     new `not_spooled_seen` baseline, and `not_spooled_folded[]` - the folded producer files' names), then deletes
     the files; a file `.last` already names is deleted without being counted again (idempotent after a crash
     between the save and the delete); a failed `.last` write leaves the files and the old baseline, with a warning.
E21. (F27-4, minor) **Documented, not fixed:** outside Windows .NET reports a process start time at one-second
     resolution, so no finer identity exists; the forgetting marker's owner check there is pid + start second
     (a recycled pid within the same second passes as the owner; a `-Forget -Local` that did not finish is
     finished by the next one). The bridge's tested host is Windows. F27-4 is `wontfix` with this note.

Verification: RC1 and RC2 of handoff 27 as fixtures of `tests/harness-fixes28e.ps1`; RC3 = the full suite on the
final candidate (the second full suite of the day) before the tag; astra's second round on the delta decides.

Addendum after the worker's report (f215cdb, 2026-10-07 evening):

E19a. E19 covers EVERY re-check of a recorded pid: the survivors' `Test-RecordedProcess` (a survivor recorded
      without a start time, or whose start time cannot be read now) applies the same keep/drop order and messages
      as `Test-UnverifiedProcess` (the worker's follow-up commit).
E22.  Documented limits, not code: (a) a kill whose root exited and whose child enumeration was denied has neither
      survivors nor unverified pids and keeps no record - its warning names the denial; (b) should the final `.last`
      rewrite that drops the deleted names fail, a later file with the LEGACY name would be deleted without being
      counted (the per-producer names carry a pid and start ticks and cannot recur). Astra's second round (29) is
      asked whether either needs code before the tag.

Addendum 2 after astra's second round (30, F30-1 blocker, F30-2 minor; 2026-10-07 night):

E23. (F30-1) **An unconfirmed kill keeps its record too.** E22(a) is withdrawn: a tree kill with `Confirmed=false` and
     neither survivors nor unverified pids (child enumeration denied, the fallback failed) writes the record in
     state `survivors` with empty `survivors[]` and `unverified[]` and `kill_unconfirmed: "<why>"`. The next run
     scans with the existing by-parent rule (`Find-CodexProcesses -BridgePid <the record's writer> -Since <started>`,
     the record's `child_pid` as a second parent): the scan fails -> refused (fail-closed); a codex-like process
     found -> refused, named; a clean scan -> the record is released with a note. Where the by-parent rule is not
     available (not Windows) the record is released only by the operator.
E24. (F30-2) **The fold is generation-aware by length.** `not_spooled_folded[]` entries are `{name, bytes}`; on the
     replay a named file of that length is deleted without counting, a longer one has its tail (complete lines)
     counted as new, a shorter or missing one is dropped from the list; `-Status` counts only the tail of a named
     file. E22(b) is withdrawn.

Addendum 3 after astra's third round (32, F32-1 blocker, F32-2 minor):

E25. (F32-1) **A panel record's unknown tree is released only when both scans are clean** - the by-parent scan AND the
     machine-wide "looks like codex" check, exactly as a non-panel record; a sibling member's live codex process
     postpones the release (named in the refusal). Nothing is released on a direct-child scan alone.
E26. (F32-2) **The legacy file is staged, never folded under its own name:** under the telemetry lock the fold renames
     `telemetry-not-spooled.ndjson` atomically to `telemetry-not-spooled-legacy-<utc ticks>.ndjson` before counting
     (a move that fails on a held handle is retried briefly, then skipped this flush with a note); staged names never
     recur, so `{name, bytes}` identifies a file exactly; a writer that recreates the legacy name writes a new
     generation. `-Status` counts the legacy file's complete lines as not yet flushed.

Addendum 4 after the final full suite (RC3, 2026-10-07 23:10; harness-fixes F04-10 failed with the Codex desktop app open):

E27. **The "looks like codex" rule ignores the Codex desktop app's servers.** The machine-wide scan matched the app's
     `codex.exe ... app-server`, `codex.exe exec-server --remote ...` and `codex-computer-use-swift.exe --parent-pid`
     as "task not verifiable", so with the app open an interrupted consultation whose survivors are gone stayed
     refused and (E23/E25) an unknown tree was never released. A reviewer run is always `codex exec` (or the launcher
     shim): a codex-named process whose command line shows a subcommand `app-server`, `exec-server`, `mcp-server`,
     `login` or `app`, or a `codex-computer-use*` executable, is not a reviewer; `codex exec`, the recorded launcher
     path, `@openai/codex` and a codex-named process whose command line cannot be read still match (fail-closed).
     The exclusion is named in the match text. Checks in harness-fixes; the recovery harnesses rerun with the app
     open; astra's fifth round on the one-function diff decides.
