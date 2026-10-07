Write in English.

# Handoff 31 - claude: the 0.6.0 delta, third round (F30-1, F30-2 answered)

Date: 2026-10-07. Base commit: `8629bcb` (branch `wip/wave29-claude-engine`; the range under review is `da4aac2..8629bcb` -
the fixes since your HOLD in handoff 30; skip `.collab/`).

## Question

Your second round held on F30-1 (an unconfirmed tree kill with neither survivors nor unverified pids kept no
record) and asked for a generation-aware fold (F30-2). Decisions E23 and E24 in `handoffs/28-claude-0.6.0-delta-
decisions.md` (addendum 2); the code is `3869bbd`. Can the candidate be tagged 0.6.0 now? ACCEPT, HOLD (blockers
by id) or ADVISE. RC3 (the full suite, 22 harnesses) runs right after your verdict, before the tag.

## Delta since the last review

- **E23 (F30-1):** a kill with `Confirmed=false` and neither survivors nor unverified pids keeps its record in state
  `survivors` with `survivors: []`, `unverified: []` and `kill_unconfirmed: "<why>"` (the three kill sites). The next
  run (`Test-PendingActive`) scans by parent pid under the recorded bridge pid, then the recorded child (and every
  other recorded pid), since the record's `started`; for a NON-panel record the release also needs the machine-wide
  "looks like codex" check clean (a grandchild whose own parent died is invisible to the by-parent scan; every other
  non-panel record already gets that check) - panel records stay by-parent only. Texts: released - `unknown tree
  after an unconfirmed kill: the scan found no codex-like process under pid <bridge>, <child> since <started> -
  released (<the scans run>)`; a failed scan - refused, `... and the scan for its processes failed: <check>. Make
  sure no codex process of that run still runs, then delete <record> to release it.`; a process found - refused,
  `... a codex-like process of it may still run: pid N <name> [child of the interrupted bridge (ppid M)], found by
  <check>. Wait for it to exit or stop it, then retry (...)`; not Windows, or another host - refused with the reason
  (outside Windows an orphan is reparented; another host cannot be checked from here). `codex-findings.ps1 -List`
  names such a record and why. No new hook: `CODEX_CONSULT_TEST_KILL_DENIED=1` already yields a denied enumeration
  with a failed taskkill and an orphan; RC1 keeps the record, is refused while the orphan runs under the recorded
  child pid (no reviewer starts), releases it once the orphan is stopped. harness-fixes27c's KILL case now leaves a
  record that its next run releases (36 green).
- **E24 (F30-2):** `not_spooled_folded[]` entries are `{name, bytes}` (the length counted under the exclusive handle).
  Replay: same length - deleted uncounted; longer - the complete lines beyond the recorded bytes counted as new, then
  deleted; shorter - another file under that name, folded afresh; missing - leaves the list; a bare name of the E20
  build - deleted uncounted. `-Status` counts only the complete lines beyond the recorded bytes of a named file (a
  named file with nothing new is not a file). RC2: the exit-87 crash replay with one legacy line appended between the
  crash and the restarted flush counts it exactly once, the folded count unchanged.
- Tests: harness-fixes28e 48 -> 57 (RC1, RC2, the E18 code check with the three `kill_unconfirmed` writes, the E20
  crash check comparing `{name, bytes}` with the real lengths). Green under the mutex, one at a time: fixes28e 57,
  pending 26, fixes 45, 3b 12, detach 51, telemetry 112, fixes28d 40, fixes27c 36.

## CURRENT invariants claimed

- A task whose last kill was not confirmed refuses every new consultation until a scan proves no codex-like process
  of that run exists (by parent, plus machine-wide for a non-panel record) - never on elapsed time, never on a
  failed scan, never from another host.
- The not-spooled accounting survives a crash anywhere in the fold, with any append to the legacy name in between,
  counted exactly once.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult.ps1` | E23 at the three kill sites |
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | `Get-KillUnconfirmedWhy`, the unknown-tree check in `Test-PendingActive`; `Get-TelemetryFoldedMap`, `Read-SharedTextFrom`, the fold functions |
| `plugins/codex-consult/scripts/codex-findings.ps1`, `codex-telemetry.ps1` | the `-List` pending line; help |
| `tests/harness-fixes28e.ps1`, `tests/README.md`, `README.md`, `CHANGELOG.md` | as above |

## Open findings

F30-1, F30-2 `implemented` (3869bbd); F27-1..3 `implemented`; F27-4 `wontfix` (E21); nothing else open.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| RC1 | `tests/run-all.ps1 -Only harness-fixes28e` (the unknown-tree fixture) | 3869bbd | 0 | the worker's report | 57/57 | completed |
| RC2 | the same (the legacy append between the crash and the replay) | 3869bbd | 0 | the worker's report | counted once | completed |
| RC3 | `tests/run-all.ps1` | 8629bcb | - | - | after this round, before the tag | pending |

## Questions

- **Q1.** E23: a path where the release is granted while a process of the killed run still exists (the by-parent
  scan's blind spots, the machine-wide rule's "task not verifiable" matches, a panel record), or where a task is
  blocked forever although the scan could prove the tree gone?
- **Q2.** E24: any loss or double count across the save, the deletes, the second rewrite and a legacy append at
  any point in between?
- **Q3.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 600 words.
