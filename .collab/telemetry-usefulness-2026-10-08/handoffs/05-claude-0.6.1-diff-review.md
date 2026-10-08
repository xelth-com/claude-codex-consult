Write in English.

# Handoff 05 - claude: the 0.6.1 delta (the bridge half of the usefulness table, the time-only reset)

Date: 2026-10-08. Base commit: `e4b687f` (branch `main`; the range under review is `890fc9e..e4b687f` - the delta
since the 0.6.0 tag; skip `.collab/` and `tests/ab/`).

## Question

0.6.1 implements the bridge half of decisions U3 and U5 of `handoffs/04-claude-usefulness-decisions.md` (your
framing reply 02 shaped them) plus the parse fix for a reset time without a date. The intake and the public page
(xelth.com/C3/) already read both new keys. Is 0.6.1 taggable? ACCEPT, HOLD (blockers by id) or ADVISE.

## Delta since 0.6.0

- **`consult_ref` (U5, F02-4):** every consultation mints a second random GUID (`[guid]::NewGuid()`, unrelated to
  the `consult_id` the reviewer sees), stored in the ledger entry after `consult_id` (a panel member its own) and
  sent as the last key of the consultation event's `details` and of every rating event of that entry (`-Rate`,
  `-BackfillRatings`); a pre-0.6.1 entry sends no such key; a complaint's context never carries it.
- **The rating event's `judge` (U3, F02-3, F02-6):** `{provider, model, source}` resolved AT RATING TIME:
  `CODEX_CONSULT_COORDINATOR` of the `-Rate` process (parsed as the coordinator warning parses it; an unparseable
  value rates as `other/other`) with source `rating_actor`; unset -> the ledger entry's consult-time coordinator
  (`consult_coordinator`); else `{other, other, unknown}`. `-BackfillRatings` never takes its own process's
  coordinator. Classifier `Get-TelemetryJudgeClass`: `openai` -> openai, `anthropic` -> anthropic, a roster label ->
  the vendor class of that entry's endpoint host (`Get-TelemetryRosterVendor`), another name -> its engine's class
  (agy google, muse meta, claude anthropic) else other; no provider -> anthropic for host `claude-code`, else other;
  the model through the same closed lists (`[1m]` stripped) else other. Never the label, never the host
  (`ConvertTo-TelemetryJudge` re-checks every value).
- **Time-only reset:** `try again at 9:43 PM.` (also `21:43`, after `resets at`/`available at`/`until`) parses as
  today at that local time, tomorrow when already past at the moment of parsing; the dated form wins; a re-read of
  an old entry uses the failure's own `when`. The 60-minute default hold no longer applies to it.
- Manifests 0.6.1, CHANGELOG `[0.6.1]`, README (ledger table, Telemetry payload and key table, "Never sent",
  `retry_after`), the `consult-codex` and `coordinate` skills, TECH_DEBT entry removed.

## CURRENT invariants claimed

- Telemetry sends classes and numbers only: no task, brief, prompt, path, name, roster label, host or coordinator
  identity string; `consult_ref` is a random id derived from nothing local and appears only in the consultation
  event and that entry's rating events.
- A 0.6.0 ledger and roster work unchanged; the intake accepts both keys additively (events without them still
  count, every rating counts when no `consult_ref` is present).

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | `Get-TelemetryConsultRef`, `Get-TelemetryRatingActor`, `Resolve-TelemetryJudge`, `Get-TelemetryJudgeClass`, `Get-TelemetryRosterVendor`, `ConvertTo-TelemetryJudge`, `ConvertTo-TelemetryDetails -NoConsultRef`; `Get-RetryAfter` wording 1b |
| `plugins/codex-consult/scripts/codex-consult.ps1` | `consult_ref` minted and written (two ledger sites, the dry run) |
| `plugins/codex-consult/scripts/codex-findings.ps1` | `-Rate` reads the actor before the lock, passes the judge |
| `plugins/codex-consult/scripts/codex-telemetry.ps1` | backfill help, the dry-run judge line |
| `tests/harness-telemetry.ps1` 112 -> 127, `tests/harness-roster.ps1` 120 -> 124; ledger field order in `harness-0.3`, `harness-engines`, `harness-muse`, `harness-companions` | |

## Open findings

`-Task telemetry-usefulness-2026-10-08 -List`: F02-1..F02-6, F03-1 `implemented` (the bridge ones in 50054a9, the
site ones in xelth.com 776cc3a); nothing else open.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| the worker's set | `tests/run-all.ps1 -Only <name>` x8 (telemetry 127, roster 124, claude 87, 0.3 229, engines 97, muse 74, companions 42, visibility 122), Windows PowerShell 5.1 | 50054a9 | 0 | the worker's report | all green | completed |

## Questions

- **Q1.** The judge: a path by which a roster label, a host string or the raw `CODEX_CONSULT_COORDINATOR` value
  can reach the event; and is `rating_actor` over `consult_coordinator` the right precedence for a site that weighs
  marks by the judge's tier?
- **Q2.** `consult_ref`: any linkability back to a task or a person from the two events that carry it?
- **Q3.** The time-only reset: a wording or a clock case (DST, a past time, a foreign locale's PM) that now holds
  too short or too long?
- **Q4.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 600 words.
