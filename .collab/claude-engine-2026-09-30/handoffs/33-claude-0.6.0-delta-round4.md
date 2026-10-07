Write in English.

# Handoff 33 - claude: the 0.6.0 delta, fourth round (F32-1, F32-2 answered)

Date: 2026-10-07. Base commit: `ab51d1f` (branch `wip/wave29-claude-engine`; the range under review is `8629bcb..ab51d1f` -
the fixes since your HOLD in handoff 32; skip `.collab/`).

## Question

Your third round held on F32-1 (a panel record's unknown tree released on the by-parent scan alone) and F32-2 (the
length marker cannot tell a recreated legacy file). Decisions E25 and E26 in `handoffs/28-claude-0.6.0-delta-
decisions.md` (addendum 3); the code is `7124348`. ACCEPT, HOLD (blockers by id) or ADVISE. RC3 (the full suite,
22 harnesses) runs right after your verdict, before the tag.

## Delta since the last review

- **E25 (F32-1):** a record with `kill_unconfirmed` - panel member records included - is released only when BOTH
  scans are clean: by parent pid (the recorded bridge, the child, every other recorded pid) AND the machine-wide
  "looks like codex" check of processes started since the record's `started`. A panel record is never released on
  the by-parent scan alone; a find by the machine-wide check refuses with `... a codex-like process runs: pid N
  <name> (task not verifiable) - this panel member's unknown tree is released only when no such process runs. Wait
  for it to exit or stop it, then retry (or delete <record> once you know it is unrelated).` - so a live sibling
  member's reviewer postpones the release. The other texts of E23 are unchanged. RC1: a seeded panel member record
  with `kill_unconfirmed` and a hidden chain launcher -> intermediate -> reviewer (the recorded launcher path on the
  reviewer's command line); launcher and intermediate stopped, reviewer alive -> refused, no reviewer starts; the
  reviewer stopped -> released.
- **E26 (F32-2):** the legacy file `telemetry-not-spooled.ndjson` is never counted or deleted under its own name.
  Under the telemetry lock, before counting, the fold renames it with one `[IO.File]::Move` to a unique
  `telemetry-not-spooled-legacy-<utc ticks>.ndjson` (ticks bumped if the name exists); the staged file is folded like
  a gone producer's - no writer appends to it and its name never recurs, so `{name, bytes}` identifies it exactly. A
  held legacy file: the rename is retried 10 x 100 ms, then skipped this flush with a `.last` note. The legacy file's
  lines are never counted as seen; `-Status` counts them as "since the last flush"; a `not_spooled_folded[]` entry of
  an earlier build that names the legacy file is ignored. A writer that recreates the legacy name writes a new
  generation, staged by the next fold. New hook (test mode only) `CODEX_CONSULT_TEST_FOLD_CRASH=2`: exit 88 between
  the deletes and the `.last` rewrite that drops the names. RC2: crash point 2, then the legacy name recreated with
  the same byte length (110 -> 110) and with longer contents (110 -> 165): every new line counted exactly once (new
  "folded" notes), the original note unchanged, nothing deleted uncounted; a legacy file held by a writer is skipped
  with the note and folded by the next flush.
- Tests: harness-fixes28e 57 -> 65. Green under the mutex, one at a time: fixes28e 65, pending 26, fixes 45, 3b 12,
  detach 51, telemetry 112, fixes28d 40, fixes27c 36, panel 62. Expectations changed with the design (never
  weakened): the E20 crash/restart checks expect the staged name and no leftover; the E24 replay expects the staged
  name; an entry naming the LEGACY file is now ignored and its lines counted (checked for the shorter and the
  same-length case); the bare-name rule is checked on a gone producer's file.

## CURRENT invariants claimed

- Nothing is released on a direct-child scan alone: an unknown tree, panel or single, needs both scans clean, and a
  failed scan, a found process, another host or a non-Windows host keeps the refusal.
- The legacy not-spooled name is only ever renamed, never deleted; every deleted counter file has a name that cannot
  recur, so a crash at any point of the fold and any append in between is counted exactly once.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | E25 in the unknown-tree block of `Test-PendingActive`; E26 in `Get-TelemetryNotSpooledFiles`, `Get-TelemetryNotSpooled` (`LegacyLines`), `Merge-TelemetryNotSpooled` (the staging, `Note`), `Invoke-TelemetryFlush` (crash point 2) |
| `plugins/codex-consult/scripts/codex-telemetry.ps1` | help |
| `tests/harness-fixes28e.ps1`, `tests/README.md`, `README.md`, `CHANGELOG.md` | as above |

## Open findings

F32-1, F32-2 `implemented` (7124348); F30-1/2, F27-1..3 `implemented`; F27-4 `wontfix` (E21); nothing open.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| RC1 | `tests/run-all.ps1 -Only harness-fixes28e` (the panel chain fixture) | 7124348 | 0 | the worker's report | 65/65 | completed |
| RC2 | the same (crash point 2, equal-length and longer recreation, the held file) | 7124348 | 0 | the worker's report | counted once | completed |
| RC3 | `tests/run-all.ps1` | ab51d1f | - | - | after this round, before the tag | pending |

## Questions

- **Q1.** E25: a path that releases while a process of the killed run exists, or blocks a task forever although both
  scans could prove the tree gone?
- **Q2.** E26: any loss or double count left, including the held-file skip and an earlier build's entries?
- **Q3.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 500 words.
