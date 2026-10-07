Write in English.

# Handoff 26 - claude: acceptance of the 0.6.0 candidate's delta since your ACCEPT (wave 28e, roster `panel: light`)

Date: 2026-10-07. Base commit: `a75ccbf` (branch `wip/wave29-claude-engine`; the range under review is
`95d9be2..a75ccbf`, `-Range` on the command - the delta since the state you accepted in handoff 25; skip the
`.collab/` files, they are the record).

## Question

Your fourth round (handoff 25) accepted wave 29 + 29b as the reviewed engine candidate. Since then two small
pieces were added to the same 0.6.0 candidate: **wave 28e** (the four items of the 0.5.0 verdict, handoff 56 of
companions-2026-09-26, decisions E1-E4 there) and the roster value **`panel: light`**. Can the candidate be
tagged 0.6.0 with them? ACCEPT, HOLD (blockers by id) or ADVISE. Nothing of wave 29/29b changed.

## Delta since the last review

- `119008b` wave 28e (E1-E4 of handoff 56; findings F54-1..F54-4 and F53-1 of mimo's reply 54, now `implemented`):
  - E1 (F54-1): a timeout kill with survivors AND descendants whose start time could not be read writes
    `unverified: [{pid, why}]` beside `survivors[]` into the recovery record. The next run names them and re-checks
    each: gone -> dropped; start time still unreadable -> counted as running (fail-closed, blocks the task like a
    survivor); readable and started before the record -> dropped (not a descendant); readable otherwise -> blocks
    only when it looks like codex (`Get-CodexRule`). Unverified pids also serve as parents in the orphan scan. A
    kill with unverified pids but NO survivor keeps no record, as before (E1 covers the survivors case only).
  - E2 (F54-2, F53-1): one not-spooled file per producer process, `telemetry-not-spooled-<pid>-<start ticks>.ndjson`,
    appended without contention; `-Status` sums the complete lines of every such file plus the legacy file, minus
    `.last`'s `not_spooled_seen`; at the end of a flush (under the telemetry lock) the files of gone producers and
    the legacy file are folded into ONE `.last` note (`folded <n> not-spooled line(s) of <m> gone producer(s)`) and
    removed; `not_spooled_seen` becomes the line count of the kept (live producers') files; `-Forget -Local` removes
    them all. `Add-TelemetryNotSpooled` returns why a line could not be written; the callers' warnings carry it.
  - E3 (F54-3): the forgetting marker records `start_ticks`; the owner is compared on pid AND that value - exactly on
    Windows, within 1 s elsewhere (.NET's start-time resolution on Linux); an older marker without the field is judged
    as before.
  - E4 (F54-4): the inline re-read anchor repeats the FIRST line of a multi-line ask whole (whitespace inside folded,
    cut at 300 characters with the existing marker) plus `(+<n> more lines)`; a one-line ask is cut at 300, not 500.
  - `tests/harness-fixes28e.ps1` (31 checks: RECORD, NOTSPOOLED, MARKER, ANCHOR, DOCS, GUARD), registered in
    `run-all.ps1` before harness-claude; harness-fixes28d (NOTSPOOLED reads the producer file; REREAD cut 300) and
    harness-telemetry (line 665: no `telemetry-not-spooled*` file at all) updated.
- `563043a (merged 0886bd3)` roster `panel: light` (an operator request of 2026-10-07: Kimi Code's `k3` (256K, weighty) and
  `kimi-for-coding` (K2.8 Preview, 1M) on one plan):
  `panel` accepts `always` | `weighty` | `light` (the validator's message names all three). A light entry
  runs on a light purpose like `always`. On a weighty purpose without `-PanelAll` it is held back after every
  other check (refused, unavailable, context) with `SkipKind` `light` (`light reviewer; purpose <p> is weighty - it
  stands in only when no entry of its label runs`); a second pass in roster order seats a held-back light entry when
  no other member of the same provider label (compared `-ceq`) is in state `run` - reason `stands in for #<n>
  (<that sibling's skip reason>)` (the first skipped sibling that is not itself a held-back light entry), `stands in
  (no other entry of label <label>)` without a sibling, `stands in (no other entry of label <label> runs)` when every
  sibling is a held-back light entry; one stand-in per label (a second light entry sees the first running). The
  listing and the ledger's `panel.members` carry the reason. `-PanelAll` seats light entries on any purpose; a
  required light entry (`-Require`) is un-skipped like a required weighty one and never triggers exit 5. The
  single-reviewer walk is unchanged. Known limit: the stand-in decision precedes the panel-size pick, so when the
  weighty sibling is eligible but not picked by the size, the label has nobody in the panel. Docs: README section 7
  and the roster table, `-PanelAll`, "Size by stakes", `-Require`; setup-providers 3d (K2.8 Preview = `kimi-for-coding`
  since 2026-09-11, thinking low/high/max; its window per tier is stated as unverified - `context_tokens` is set to
  what one long brief proves); the consult-codex skill's three weight sentences; CHANGELOG. Tests: harness-panel
  LIGHT (8 checks: the two purposes, the context stand-in, `-PanelAll`, the ledger reason), harness-roster WEIGHT
  (`lite` refused, `light` accepted; the message for `sometimes`).
- The full suite on Windows PowerShell 5.1 after wave 29 + 29b (before these two commits): 21 harnesses, 20 green
  (harness-claude 87/87); harness-panel 53/54 - its check "the panel's wall clock is below the sum of the members'
  own wall times" failed twice under load (22 s vs 21.9 s; 22.9 s vs 20.3 s), once together with a SPEC race
  (the parent's death vs the member's phase), while two worker sessions ran harnesses and parse checks on the same
  machine; the harness passed 54/54 on 2026-10-06. harness-panel then passed 62/62 alone on the quiet machine after a TEST fix (a75ccbf): the D1 check "its panel run dies during its preflight" killed the parent right after observing the record rewrite, which races the member's early parent check (a member runs no login status of its own, the fake's `FAKE_CODEX_LOGIN_DELAY_MS` never existed, and the launcher probe runs with the FAKE_* variables hidden); the bridge gains the test-mode hook `CODEX_CONSULT_TEST_MEMBER_LAUNCH_MARK` / `_PAUSE_MS` (a mark and a pause right before the launch-time parent check) and the harness kills the parent only after the mark. A second full suite runs on this head right after this round, before the tag.

## CURRENT invariants claimed

- Everything in handoff 14 (as amended by E11-E17, A1-A6) stands unchanged: no file of the claude engine's adapter,
  the roster validator's claude/endpoint/plan branches, the plan quota, the telemetry vendor table or the panel plan
  groups changed in this delta, except the seating function's new `light` pass and the validator's `panel` values.
- Recovery (E1): a record in state `survivors` blocks the task until every survivor AND every unverified pid is
  gone or proven unrelated; an unreadable identity never unblocks.
- Telemetry (E2): no event is ever lost by the fold - the not-spooled files count events that were ALREADY dropped
  (best-effort telemetry); the fold only moves their count into `.last`.
- Panel seating: `always` joins every purpose; `weighty` joins the weighty purposes (framing, decision,
  core-contract, acceptance, stuck) or `-PanelAll`; `light` joins the light purposes, and a weighty purpose only as
  the stand-in of its label (no other entry of the same provider label in state run), or under `-PanelAll`. The
  single-reviewer walk ignores `panel`; its context skip (`context_tokens`, 80%) moves it to the next entry.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | E1 re-check in `Test-PendingActive`, the `unverified` record field; E2 per-producer files and the fold; E3 marker ticks; the `light` validator value and seating pass |
| `plugins/codex-consult/scripts/codex-consult-detached.ps1` | `Get-ProcessStartTicks`, `Get-PidIdentityTicks` |
| `plugins/codex-consult/scripts/codex-consult.ps1` | `unverified[]` at the three places that record survivors; test hooks `CODEX_CONSULT_TEST_UNVERIFIED` (main turn only) and `CODEX_CONSULT_TEST_MEMBER_LAUNCH_MARK` / `_PAUSE_MS` (test mode only); the E4 anchor; the not-spooled caller |
| `plugins/codex-consult/scripts/codex-findings.ps1`, `codex-telemetry.ps1` | the not-spooled caller; `-Status` sum line and help |
| `plugins/codex-consult/scripts/codex-providers.ps1` | unchanged - it never prints the weight |
| `tests/harness-fixes28e.ps1` (new), `tests/harness-fixes28d.ps1`, `tests/harness-telemetry.ps1`, `tests/harness-panel.ps1`, `tests/run-all.ps1`, `tests/README.md` | the checks named above |
| `README.md`, `CHANGELOG.md`, `plugins/codex-consult/skills/setup-providers/SKILL.md` | E1-E4 documented; the roster `panel` row and example; the Kimi two-entry pattern; the Unreleased entries |

## Open findings

`codex-findings.ps1 -Task companions-2026-09-26 -List`: F53-1, F54-1..F54-4 `implemented` (note: commit 119008b);
`-Task claude-engine-2026-09-30 -List`: 50 verified, 2 superseded, none open.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| wave 28e harnesses (8) | `tests/run-all.ps1 -Only harness-fixes28e` (31), `-fixes28d` (40), `-fixes28c` (15), `-telemetry` (112, one rerun after a 3 s flush deadline under load), `-pending` (26), `-fixes` (45), `-3b` (12), `-detach` (51) | 119008b | 0 | the worker's report | all green | completed |
| `panel: light` harnesses | `tests/run-all.ps1 -Only harness-roster` (120), `-Only harness-visibility` (122), `-Only harness-panel` (62: the 8 LIGHT checks green in both runs; the SPEC race and the wall-clock check failed under load, see above) | 563043a (merged 0886bd3) | 0 | the worker's report | all green | completed |
| the full suite | `tests/run-all.ps1` | 95d9be2 | 1 | run-all-20261007-094800 | 21 harnesses, 1 failed (harness-panel timing, above) | completed |

## Questions

- **Q1.** E1: is the re-check's rule set complete - a path where an unverified descendant of the killed tree is
  dropped although it still runs codex, or where the task stays blocked forever by a pid that can never be judged?
  Is "no record for a kill with unverified pids but no survivor" acceptable, or does E1 require the record there too?
- **Q2.** E2: can the fold or the per-producer files make `-Status`'s "since the last flush" count wrong (double
  count, negative, a live producer's file folded, a line lost between the read and the delete)? Is the legacy file's
  handling safe on an upgrade in place?
- **Q3.** E3: does the ticks comparison close F54-3 (a recycled pid with the same coarse start time) on Windows and
  on Linux, and does an older marker still get removed when its owner is gone?
- **Q4.** `panel: light`: a path where a light entry sits beside its weighty sibling in one weighty panel, or never
  seats when the sibling was skipped for context; the interplay with `-Require`, `-PanelAll`, the per-label limit,
  the plan group and the ledger's `panel.routing`.
- **Q5.** Anything in this delta that touches the accepted wave 29/29b invariants?
- **Q6.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 900 words.
