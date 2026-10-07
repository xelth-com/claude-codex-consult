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
