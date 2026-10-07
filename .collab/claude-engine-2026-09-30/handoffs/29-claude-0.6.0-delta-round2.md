Write in English.

# Handoff 29 - claude: the 0.6.0 delta, second round (F27-1..F27-4 answered)

Date: 2026-10-07. Base commit: `da4aac2` (branch `wip/wave29-claude-engine`; the range under review is
`a75ccbf..da4aac2` - the fixes since your HOLD in handoff 27; skip `.collab/`).

## Question

Your round on handoff 26 held the 0.6.0 delta on F27-1 and F27-2 (blockers) and asked for a disposition of
F27-3 and F27-4. The decisions are E18-E22 in `handoffs/28-claude-0.6.0-delta-decisions.md`; the code is in
`da4aac2`. Can the candidate be tagged 0.6.0 now? ACCEPT, HOLD (blockers by id) or ADVISE. RC3 (the full suite on
the final candidate) runs right after your verdict, before the tag, and is reported with it.

## Delta since the last review

- **E18 (F27-1):** a timeout kill keeps its recovery record (state `survivors`) when EITHER `survivors[]` OR
  `unverified[]` is non-empty - the three kill sites (a turn, the main turn, the codex format repair). With only
  unverified pids the outcome reads `(kill not confirmed: <why>; pid <u> may still run; the next run for this task
  is refused until it exits)`.
- **E19 (F27-2):** the re-check of a recorded pid - `Test-UnverifiedProcess` AND (follow-up commit) the survivors'
  `Test-RecordedProcess` - decides in this order: no such process -> dropped (`gone`); start time still unreadable
  -> running (fail-closed); started before the record's `started` -> dropped; `Get-CodexRule` matches -> running;
  command line NOT readable (empty = access denied, ps's `[name]`, or a generic runtime - node, bun, deno, cmd,
  powershell, pwsh, sh, bash, python - with nothing after the executable) -> running, `command line not readable -
  counted as running (fail-closed)`; a child of a recorded pid (writer, child, survivors, other unverified) ->
  running; otherwise (command line read, not codex-like) -> dropped, `not codex`. `-Kick`'s check that an engine turn runs uses the same `Test-RecordedProcess`: in the uncertain cases a kick request is now written where it used to be refused. Test hook (test mode only)
  `CODEX_CONSULT_TEST_CMDLINE_UNREADABLE=<pid>[,<pid>]`; the bare-runtime case is a real hidden `cmd.exe`.
- **E20 (F27-3):** the fold saves before it deletes: the gone producers' files (and the legacy file) are opened
  exclusively (share-delete) and counted, `.last` is saved with the folded note, the new `not_spooled_seen` and
  `not_spooled_folded[]` (the files' names), only then are the files deleted under the held handles, then `.last`
  is written once more without the names. A file `not_spooled_folded[]` already names is deleted without being
  counted again; `-Status` skips such files. A failed `.last` save deletes nothing and warns (`nothing was
  folded`). Test hook `CODEX_CONSULT_TEST_FOLD_CRASH=1` (exit 87 between the save and the deletes); the read-only
  `.last` case uses a real read-only file.
- **E21 (F27-4, wontfix):** outside Windows .NET reports a process start at one-second resolution; the marker's
  owner check there is pid + start second, documented; the bridge's tested host is Windows.
- **E22 (documented limits, from the worker's report):** (a) a kill whose root exited and whose child enumeration
  was denied has neither survivors nor unverified pids and keeps no record (its warning names the denial); (b) if
  the final `.last` rewrite that drops the deleted names fails, a later file with the LEGACY name would be deleted
  without being counted (the per-producer names carry a pid and start ticks and cannot recur).
- Tests: `harness-fixes28e` 31 -> 48 (the survivors' two cases included; `harness-3b` 12 green as the bare-pid case) (RC1: zero survivors + one unverified descendant kept and refused; a
  generic runtime with an unreadable command line counted as running; a readable non-codex command line dropped;
  the survivors' re-check with the same two cases; RC2: the fold crash replay, the read-only `.last`);
  `harness-telemetry` 112 (its exact `.last` field list now includes `not_spooled_folded`). Green under the mutex:
  fixes28e, pending 26, fixes 45, detach 51, telemetry 112, fixes28d 40.

## CURRENT invariants claimed

- As handoff 26, plus: a task with a recovery record in state `survivors` refuses every new consultation until
  every survivor and every unverified pid is gone or PROVEN unrelated (started before the record, or its command
  line was read and is not codex-like and it is no child of a recorded pid); nothing is released on a guess.
- The not-spooled count can never be lost by a crash inside the fold: either the files are still there, or `.last`
  names them as folded.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult.ps1` | E18 at the three kill sites |
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | E19 (`Get-ProcessInfo`, `Get-CommandLineGap`, `Test-UnverifiedProcess`, `Test-RecordedProcess`, `Test-PendingActive`); E20 (`Get-TelemetryNotSpooled`, `Merge-TelemetryNotSpooled`, `Complete-TelemetryNotSpooledFold`, `Invoke-TelemetryFlush`) |
| `plugins/codex-consult/scripts/codex-telemetry.ps1` | the `.last` field list in the help |
| `tests/harness-fixes28e.ps1`, `tests/harness-telemetry.ps1`, `tests/README.md` | the checks above |
| `README.md`, `CHANGELOG.md` | E18-E20 in the wave 28e text |

## Open findings

`-Task claude-engine-2026-09-30 -List`: F27-1, F27-2, F27-3 `implemented` (f215cdb, c74b297), F27-4 `wontfix`
(E21); nothing else open.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| RC1 | `tests/run-all.ps1 -Only harness-fixes28e` (RECORD fixtures) | da4aac2 | 0 | the worker's report | 48/48 | completed |
| RC2 | the same (NOTSPOOLED fold crash, read-only `.last`) | da4aac2 | 0 | the worker's report | green | completed |
| RC3 | `tests/run-all.ps1` (all 22 harnesses) | da4aac2 | - | - | runs after this round, before the tag | pending |

## Questions

- **Q1.** E19's order: a path that still drops a process the task's reviewer could be, or that blocks forever on
  a process that is provably unrelated?
- **Q2.** E20: any way the count is lost or doubled across the save, the deletes and the second rewrite?
- **Q3.** E22 (a) and (b): acceptable as documented limits, or does either need code before the tag?
- **Q4.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 700 words.
