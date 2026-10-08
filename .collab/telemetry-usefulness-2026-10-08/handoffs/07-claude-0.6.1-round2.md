Write in English.

# Handoff 07 - claude: the 0.6.1 delta, second round (F06-1..F06-6 answered)

Date: 2026-10-08. Base commit: `94283c3` (branch `main`; the range under review is `e4b687f..94283c3` - the fixes
since your HOLD in handoff 06; skip `.collab/`).

## Question

Your round held 0.6.1 on F06-1..F06-4 (blockers), F06-5 (major) and the note F06-6. All six are implemented in
19f3888 (the fixes below); the site side of F06-2 (the intake's replacement rule) is xelth.com 4ca4894, deployed
with the tag. Can 0.6.1 be tagged now? ACCEPT, HOLD (blockers by id) or ADVISE.

## Delta since the last review

- **F06-1:** the rating commit saves the sanitized `judge {provider, model, source}` INSIDE the mark
  (`Get-RatingMarkJudge`); the retry after the locks and `-BackfillRatings` take the judge from the mark; the
  consult-time coordinator (`consult_coordinator`) or `{other, other, unknown}` only for marks saved before this
  change. RC1 is a harness check (consult under A, rate under B with both spool attempts failing - the day's spool
  file held open -, backfill: judge B / `rating_actor`, the mark carries it).
- **F06-2:** every mark gets `rating_rev` (1 + the entry's highest, allocated under the task lock in the mark's
  commit; `Get-NextRatingRev`); the rating event sends `rating_rev` after `judge` and before `consult_ref` on
  every path, always the mark's own value; `client_time` is the mark's own `when` on every path (the first send,
  the retry, the backfill). `Test-RatingMarkSame` compares `rating_rev` too; a late retry whose mark was re-rated
  meanwhile says so (no longer "backfill sends it again"). RC2 (bridge half): test hook
  `CODEX_CONSULT_TEST_RATE_RETRY_GATE` holds the retry while a newer mark commits - the events carry rev 1 and rev
  2 with their own times. The intake (xelth.com 4ca4894, 28 tests): per (reviewer, consult_ref) the highest
  `rating_rev` wins (missing = 0), then the latest `created`, then the less favourable mark.
- **F06-3, F06-4, F06-5 - the time-only reset rewritten** (`Select-TimeOnlyReset`, `Get-WallClockCandidates`,
  `Get-TimeOnlyZone`): candidates are the clock time on the day before, the day of and the day after the
  reference date, at the zone's offset(s) - both offsets in the repeated fall-back hour, a time inside the
  spring-forward gap becomes the first valid instant after it - or at the offset the message names; the earliest
  candidate not before (reference - 5 min) wins: a reset that just passed counts as passed (the hold ends at once;
  `23:59` parsed at 00:02 too). `UTC`/`GMT`/`Z` means UTC, a numeric offset (`+02:00`, `-0500`, `+2`) that
  offset; any other 2-5 capital-letter zone word (PST, CET) means the time-only wording is NOT parsed (the default
  hold). The dated wordings keep their rule; a DATED wording with a trailing qualifier is still local time -
  TECH_DEBT T9 (no provider seen printing it).
- **F06-6:** README "Telemetry" says `consult_ref` is a pseudonymous correlation key - a reader holding both the
  telemetry and a shared ledger joins them on it; no unlinkability promised after a ledger is shared.
- Tests: `harness-telemetry` 127 -> 137, `harness-roster` 124 -> 125 (52 reset samples), the mark/event shapes
  in `harness-companions` and `harness-engines`. README, CHANGELOG `[0.6.1]` amended (F06-1..F06-6 named),
  `tests/README.md`, the `consult-codex` skill, the help of `codex-findings.ps1` and `codex-telemetry.ps1`.

## CURRENT invariants claimed

- As handoff 05, plus: a mark carries its own judge and revision from its commit; every send path of a rating
  event uses the mark's judge, revision and time, never the sending process's; the intake replaces a rating only
  by a higher revision.
- A time-only reset never holds an endpoint past the next occurrence of that wall time; a reset within the
  last 5 minutes is over.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | the reset rewrite; `ConvertTo-RatingRev`, `Get-NextRatingRev`, `Get-RatingMarkJudge`; `-RatingRev` through the event; the backfill's judge from the mark |
| `plugins/codex-consult/scripts/codex-findings.ps1` | `-Rate`: rev and judge saved in the mark; the first send and the retry use the mark's values and time; the retry gate hook |
| `plugins/codex-consult/scripts/codex-telemetry.ps1`, `README.md`, `CHANGELOG.md`, `TECH_DEBT.md`, `tests/README.md`, the `consult-codex` skill | docs |
| `tests/harness-telemetry.ps1`, `tests/harness-roster.ps1`, `tests/harness-companions.ps1`, `tests/harness-engines.ps1` | the checks above |

## Open findings

`-List`: F06-1..F06-6 `implemented` (19f3888); F02-3, F02-4 `superseded`; the rest `implemented`.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| RC1, RC2 (bridge half) | `tests/run-all.ps1 -Only harness-telemetry` | 19f3888 | 0 | the worker's report | 137/137 | completed |
| the reset samples | `tests/run-all.ps1 -Only harness-roster` | 19f3888 | 0 | the worker's report | 125/125 | completed |
| the rest | `-Only` companions 42, engines 97, 0.3 229, visibility 122, claude 87 | 19f3888 | 0 | the worker's report | green | completed |
| RC2 (intake half) | `cargo test -p telemetry --lib` | xelth.com 4ca4894 | 0 | - | 28/28 | completed |

## Questions

- **Q1.** F06-1/F06-2: a send path that can still take the process's judge or "now", or a revision that can
  repeat or go backwards (two `-Rate` processes, a backfill racing a rating)?
- **Q2.** The reset rule: a wording or a clock case the three-day candidate set with the 5-minute allowance
  gets wrong?
- **Q3.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 600 words.
