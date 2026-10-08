# Handoff 10 - Codex: 0.6.1-round3

Date: 2026-10-08 16:44 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 1 of 12 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: 1372d8e7-7f1d-45c9-8ad9-500d7aa3fc44.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-2a57aabb126440df9fea94d2f93e137e.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a11b84-6379-7950-bfcd-ff2d560415fd -` (prompt on stdin).
Parent thread: `01a11b84-6379-7950-bfcd-ff2d560415fd`. Result thread: `01a11bf9-73b8-7dd1-aa90-eebf46e14499` (source: events).
Brief: `.collab/telemetry-usefulness-2026-10-08/handoffs/09-claude-0.6.1-round3.md` (sha256 c71f3951f8d8). Reviewed: 4061dda, base 4061ddab2d81c562b6cfc2c9ee6dcfd1ebed5e96, tree sha256 2bf14bdd3ec3, 0 changed files.
Bridge outcome: usable reply. Wall time: 240.5 s. Tokens: in 4561060 (cached 3836288), out 27668, reasoning 7009.
Timeout: 2400 s (the default of purpose diff-review); continuation after a timeout kill: up to 900 s. Range: `94283c3..4061dda` - the range changes 8 files, 357 lines (292 insertions, 65 deletions).
Verdict: ACCEPT - The reviewed bridge delta fixes both remaining findings; the residual duplicate-delivery caveat does not invalidate committed revision ordering. Findings: 0 blocker, 0 major, 0 minor, 1 note (F10-1, tracked in `findings.json`). Structured reply: `handoffs/10-codex-0.6.1-round3.reply.json`.
Raw event stream: `handoffs/10-codex-0.6.1-round3.events.jsonl`.
Verbatim reply follows.

---

**Q1. Commit and publication.** F08-1 is fixed. The mark is saved before the first spool attempt, and the store lock remains held through that attempt and the subsequent `telemetry_sent` write. A failed initial commit therefore publishes nothing. An interruption after commit leaves a recoverable mark; subsequent ratings allocate above its saved revision. Backfill preserves the saved judge, revision, and timestamp.

The new fixtures cover interruption before spooling, both backfill/re-rating orders, and an initial store-write failure. A read-only probe of `Set-RatingTelemetrySent -Commit`, with storage operations mocked, confirmed that it writes the marker without releasing the caller's lock.

**Physical delivery remains at least once.** After a failed first spool attempt, backfill can publish the mark while the post-lock retry waits; that retry then publishes the same revision again. An interruption between spooling and saving `telemetry_sent` can likewise permit a duplicate. These are duplicate events for one committed mark, not conflicting revision allocations. Modern `consult_ref` aggregation should collapse them under the documented rule. Finding #1 records the nonblocking caveat and a misleading diagnostic in this race.

**Q2. Qualifiers.** F08-2 is fixed for the specified grammar. I directly executed all **69 reset samples** read-only: all passed. Additional direct probes accepted the listed supported forms, including `UTC +02:00`, `(GMT+2)`, compact offsets, and negative half-hour offsets, while rejecting the previously accepted malformed prefixes and the added invalid forms. I found no regression in those forms. This does not establish support for arbitrary localized or named timezone syntax; dated qualifiers remain the documented T9 limitation.

**Q3. Verdict: ACCEPT** for the bridge delta `94283c3..4061dda`. Neither F08-1 nor F08-2 remains a release blocker. The filesystem-writing crash/concurrency harnesses were inspected, not independently rerun; their reported results come from the handoff. Site ranking, aggregation, and deployment are outside this acceptance. Their prior findings remain explicitly unverified rather than silently closed.

---

### Findings

- **F10-1** [note] `plugins/codex-consult/scripts/codex-findings.ps1:577`, `plugins/codex-consult/scripts/codex-findings.ps1:585`, `plugins/codex-consult/scripts/codex-consult-common.ps1:13723`, `plugins/codex-consult/scripts/codex-consult-common.ps1:13830` - A post-lock retry can duplicate an event already published by backfill, and its marker update then incorrectly reports that the consultation was re-rated even when the same revision remains current. Trigger: The first spool attempt fails; while the retry waits outside the task/store locks, backfill sends the committed mark and saves telemetry_sent; the retry resumes without rechecking that marker. Evidence: read-code: The retry spools before acquiring the store lock through Set-RatingTelemetrySent and does not first check whether backfill already sent the mark.; read-code: Backfill can spool and mark the same committed revision. Set-RatingTelemetrySent skips marks already carrying telemetry_sent, then returns the same reason used for a replaced mark.; ran-command: The first call succeeded and retained the caller's lock. A second call for the unchanged, already-marked revision returned 'the mark is no longer in findings.json (rated again meanwhile)'. Verify: Use the existing retry gate to pause a rating after its first spool failure, run backfill for that mark, then release the retry; inspect duplicate revisions and the resulting diagnostic. Remedy: Document delivery as at least once and distinguish an already-sent mark from a replaced mark in the diagnostic. Optionally recheck the marker under the store lock before retry publication; retain intake idempotency for interruption windows regardless.

### Prior findings

- F02-1 - not-checked - The site ranking implementation and empirical judge calibration were not inspected in this bridge review.
- F02-2 - fixed - The raw-model regex proposal remains rejected; the previously inspected closed-list serialization is unchanged.
- F02-5 - not-checked - The site's aggregation window, overflow behavior, and truncation reporting were not independently checked.
- F02-6 - still-open - The dedicated coordinator classifier addresses missing provider_config. Public model recognition behind unknown endpoints remains vendor-gated by the chosen policy; this is not a regression or blocker for this delta.
- F03-1 - not-checked - The decisions reject recursively derived judge weights, but the site implementation was not inspected.
- F06-1 - fixed - The committed mark retains its sanitized judge, and retry/backfill continue using that saved identity.
- F06-3 - fixed - The minute-boundary allowance remains intact; the half-second, 30-second, and midnight cases passed direct execution.
- F06-4 - fixed - The repeated-hour candidate handling remains intact; the second-occurrence and spring-gap cases passed direct execution.
- F06-6 - fixed - The documentation continues to describe consult_ref as pseudonymous and explicitly acknowledges linkage through a shared ledger.
- F08-1 - fixed - The initial store commit now precedes publication. The supplied-commit marker path preserves lock ownership, and the added fixtures cover interrupted publication and failed initial persistence.
- F08-2 - fixed - Whole-token offset validation rejects the reported malformed prefixes while preserving supported forms; all 69 reset samples passed read-only execution.

## Verdict: ACCEPT

The reviewed bridge delta fixes both remaining findings; the residual duplicate-delivery caveat does not invalidate committed revision ordering.

### Blockers

_(none)_

### Unproven scenarios

- The full filesystem-writing telemetry, crash, and concurrency harnesses were not independently rerun; their green results are reported by the handoff.
- The retry-versus-backfill duplicate sequence was inferred from source; its diagnostic behavior was reproduced with a read-only mocked-store probe.
- The deployed intake's deduplication and revision ordering, and the site's ranking and aggregation behavior, were not independently inspected.
- Arbitrary localized timezone syntax and the documented T9 dated-qualifier limitation are outside the demonstrated parser coverage.

### First-run checklist (observable)

_(none)_
