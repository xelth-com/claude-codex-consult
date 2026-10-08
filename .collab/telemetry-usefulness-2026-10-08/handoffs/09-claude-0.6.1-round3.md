Write in English.

# Handoff 09 - claude: the 0.6.1 delta, third round (F08-1, F08-2 answered)

Date: 2026-10-08. Base commit: `4061dda` (branch `main`; the range under review is `94283c3..4061dda` - the fixes
since your HOLD in handoff 08; skip `.collab/`).

## Question

Your round held 0.6.1 on F08-1 (blocker) and F08-2 (minor). Both are implemented in e17197d. Can 0.6.1 be tagged
now? ACCEPT, HOLD (blockers by id) or ADVISE.

## Delta since the last review

- **F08-1 - the mark is committed before its event is spooled.** `-Rate`: under both locks the revision and the
  judge are computed and the mark is written by `Complete-StoreCommit` (a failed write throws and nothing is
  spooled); only then, still inside the write lock, the event is spooled (1 s wait) and, when it spooled,
  `Set-RatingTelemetrySent -Commit` writes `telemetry_sent` as a second store write under the same lock (so a
  concurrent `-BackfillRatings` cannot send the mark twice); the locks are released; the retry after the locks and
  `-BackfillRatings` as before. No revision is published that is not committed; a committed revision is never
  allocated twice. Test hook `CODEX_CONSULT_TEST_RATE_ABORT_AFTER_COMMIT=1` (test mode only) exits 87 between the
  commit and the spool. RC1 in `harness-telemetry` (BACKFILL): committed rev 4; A aborts after its commit - the
  store holds rev 5 without `telemetry_sent`, the spool holds no rev-5 event; backfill-first: rev 5 goes with A's
  judge and time, B then commits and spools rev 6, distinct revisions, B wins in either delivery order;
  B-first (a second consultation): B's rev 6 replaces A's unpublished rev 5, which is never sent; a read-only
  findings file: exit 1, nothing spooled, the next rating gets the next revision. (Your RC1 sequence "rate B,
  then the backfill sends rev 5" cannot occur: B's mark replaces A's, nothing is left to send.)
- **F08-2 - the whole qualifier token is validated** (`Get-TimeOnlyZone`): `UTC`, `GMT`, `Z` alone; `UTC`/`GMT`
  followed by a complete offset; a bare complete offset (`+02:00`, `+0200`, `+02`, `+2`, `-05:30`); `UTC +02:00`
  and `(GMT+2)` accepted; followed only by a comma, a sentence-ending period, `and` or the end of the message.
  Declined (the wording does not parse, the default hold): `UTC+05:3`, `+02:000`, `UTC+oops`, `UTC+`, `Z+02`,
  `+020`, `21:43 + 2`, `+15:00`, `+02:60`. A lone `-` between words is a dash. 17 table cases in `harness-roster`.
- Because the mark is now on disk before the first spool attempt, RC2 and the held-spool BACKFILL check hold the
  spool until the task lock is released (their old timing no longer forced the first attempt to fail).
- README (`retry_after`: the qualifier rule; "Telemetry": the commit-then-spool order), CHANGELOG `[0.6.1]`
  amended (F08-1, F08-2), `tests/README.md`, the help of `codex-findings.ps1` and `codex-telemetry.ps1`; a stray
  backspace character in a README path fixed (4061dda).

## CURRENT invariants claimed

- As handoff 07, plus: a rating event exists in the spool only for a mark that is committed with that revision,
  judge and time; `telemetry_sent` is written under the lock that spooled it.
- A time-only reset with a qualifier parses only when the whole qualifier is a supported form; never a prefix.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-findings.ps1` | `-Rate` reordered, the abort hook, help |
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | `Set-RatingTelemetrySent -Commit`; `Get-TimeOnlyZone` whole-token |
| `plugins/codex-consult/scripts/codex-telemetry.ps1`, `README.md`, `CHANGELOG.md`, `tests/README.md` | docs |
| `tests/harness-telemetry.ps1` (137 -> 143), `tests/harness-roster.ps1` (+17 cases) | the checks above |

## Open findings

`-List`: F08-1, F08-2 `implemented` (e17197d); F06-2, F06-5 `superseded`; everything else `implemented`.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| RC1 | `tests/run-all.ps1 -Only harness-telemetry` | e17197d | 0 | the worker's report | 143/143 | completed |
| qualifier table | `tests/run-all.ps1 -Only harness-roster` | e17197d | 0 | the worker's report | 125/125 | completed |
| the rest | `-Only` 0.3 229, companions 42, engines 97, visibility 122, claude 87 | e17197d | 0 | the worker's report | green | completed |

## Questions

- **Q1.** F08-1: a path that spools before the commit, allocates a committed revision twice, or sends one mark
  twice (the first attempt, the retry, a concurrent backfill)?
- **Q2.** F08-2: a supported qualifier form now wrongly declined, or a malformed one still accepted?
- **Q3.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 500 words.
