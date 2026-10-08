# Handoff 08 - Codex: 0.6.1-round2

Date: 2026-10-08 14:37 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 1 of 12 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: c10d9ddd-178c-4943-97c0-9c3507a41e3c.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-9f944ff9e5b14037b7f9829ae8ed89fb.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a11b28-ab5f-7891-ad09-8087331d938a -` (prompt on stdin).
Parent thread: `01a11b28-ab5f-7891-ad09-8087331d938a`. Result thread: `01a11b84-6379-7950-bfcd-ff2d560415fd` (source: events).
Brief: `.collab/telemetry-usefulness-2026-10-08/handoffs/07-claude-0.6.1-round2.md` (sha256 d0ce23290cf7). Reviewed: 94283c3, base 94283c3236cc593f105d99fc4bb5c27e84bb6ca0, tree sha256 d80d90a30509, 0 changed files.
Bridge outcome: usable reply. Wall time: 516.6 s. Tokens: in 3226870 (cached 2706304), out 22934, reasoning 5494.
Timeout: 2400 s (the default of purpose diff-review); continuation after a timeout kill: up to 900 s. Range: `e4b687f..94283c3` - the range changes 12 files, 668 lines (557 insertions, 111 deletions).
Verdict: HOLD - The ordinary recovery paths are fixed, but publishing before the local rating commit allows an uncommitted revision to escape and subsequently be reused. Findings: 1 blocker, 0 major, 1 minor, 0 note (F08-1..F08-2, tracked in `findings.json`). Structured reply: `handoffs/08-codex-0.6.1-round2.reply.json`.
Raw event stream: `handoffs/08-codex-0.6.1-round2.events.jsonl`.
Verbatim reply follows.

---

**Q1. Judge, time, and revisions.** The normal paths now preserve the mark's sanitized judge, revision, and timestamp. Two successful `-Rate` processes serialize allocation under the task/store locks. Backfill reads the saved mark under the store lock and does not allocate a revision or adopt its process's coordinator. The new RC1/RC2 fixtures exercise the previously identified recovery paths.

One durability gap remains: `Add-TelemetryEvent` spools the new revision **before** `Complete-StoreCommit` saves the mark. If that save fails or the process stops between those operations, the spool contains an event absent from the committed store. The next rating reads the old revision and allocates the same successor. Locks do not prevent this across a failed commit. With the documented receipt-time tiebreaker, delivery order can then select the wrong mark. **R1 / finding #1** replaces the remaining F06-2 concern.

My read-only allocation probe confirmed that an unchanged committed revision 4 produces revision 5 for both attempts. The actual interruption path still needs the fault-injection check below.

**Q2. Reset rule.** I executed all **52 existing reset samples directly**, without running the filesystem-writing harness; all passed. Separate probes confirmed the half-second boundary, previous-day midnight allowance, second DST occurrence, spring gap, UTC, and numeric-offset handling. I found no additional candidate-selection failure in those cases.

The qualifier parser still accepts incomplete prefixes: `UTC+05:3` becomes `UTC+05`, `+02:000` becomes `+02`, and `UTC+oops` becomes UTC. These should be declined rather than interpreted as valid qualified resets. **R2 / finding #2** is a smaller remaining F06-5 issue. The tests cover supported offsets and uppercase unknown abbreviations, but not malformed offset continuations.

The five-minute allowance is now an explicit policy rather than an accidental precision error. Dated qualifiers remain the separately documented T9 limitation.

**Q3. Verdict: HOLD on R1.** F06-1, F06-3, F06-4, and the documentation remedy for F06-6 are fixed on the inspected evidence. F06-2 remains open at the publication/commit boundary; F06-5 has the narrower parsing remainder above. Site-only findings remain unverified because the intake implementation was not part of this checkout review. I inspected the changed implementation and tests and ran read-only function probes; the reported full harness and intake runs were not independently rerun.

## Requested checks

- **RC1:** Working directory: repository root; permission: workspace-write. In an isolated telemetry fixture, seed committed revision 4, allow rating A's revision-5 spool append, then inject failure immediately before its findings save. Rate B from the unchanged store and replay captured events in both orders through the intake fixture. Observe whether revision 5 is reused and an uncommitted mark can win; after the fix, no uncommitted mark may be published. Settles finding #1. Budget: one consultation, two attempts, 15 minutes; local fixtures only.

---

### Findings

- **F08-1** [blocker] `plugins/codex-consult/scripts/codex-findings.ps1:477`, `plugins/codex-consult/scripts/codex-findings.ps1:505`, `plugins/codex-consult/scripts/codex-findings.ps1:527`, `plugins/codex-consult/scripts/codex-consult-common.ps1:13620` - R1: A rating revision can be published before its mark is durably committed and then reused after a failed save, defeating revision-based replacement ordering. Trigger: The initial telemetry spool append succeeds, but Complete-StoreCommit fails or the process terminates before persisting the new mark; a subsequent rating allocates from the unchanged findings store. Evidence: read-code: The revision is calculated from committed ratings, the event is spooled at line 505, and the replacement mark is not saved until line 527.; read-code: Complete-StoreCommit performs the findings write. Get-NextRatingRev derives the successor exclusively from stored marks; no durable reservation precedes publication.; ran-command: Two allocations against the unchanged committed state both returned 5, modeling the state retained when the intervening save does not persist.; read-code: The documented intake rule selects the highest revision and breaks equal revisions by receipt time, so conflicting reused revisions are delivery-order dependent.; read-code: RC1 and RC2 cover failed spool writes and delayed retries after successful local commits; they do not cover a successful spool append followed by a failed local commit. Verify: Execute RC1 with fault injection between the successful spool append and the findings save, then inspect revision reuse and aggregation under both delivery orders. Remedy: Durably commit the mark, judge, timestamp, and revision before making its event available to the sender. Publish afterward and record telemetry_sent separately; an interrupted publish can be recovered from the committed mark through backfill. Supersedes: F06-2.
- **F08-2** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:5922`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6060` - R2: Time-only timezone parsing can accept a valid prefix of a malformed qualifier and silently compute a reset using a different offset. Trigger: A time-only message contains an incomplete or malformed offset continuation, such as UTC+05:3, +02:000, or UTC+oops. Evidence: read-code: The optional offset groups and terminal alphanumeric boundary allow matching to stop before a colon or plus sign. Get-TimeOnlyZone accepts the captured prefix without validating the remaining qualifier.; ran-command: 'resets at 21:43 UTC+05:3' returned 18:43+02:00, interpreting +05; '+02:000' returned 21:43+02:00; 'UTC+oops' returned 23:43+02:00, interpreting plain UTC.; read-code: The qualifier samples test complete supported offsets and uppercase unknown zone words, but not malformed numeric continuations. Verify: Add table-driven malformed-qualifier cases and require a null result for each, while retaining the existing supported-offset results. Remedy: Validate the entire qualifier token before accepting it; reject dangling signs, incomplete minutes, excess digits, and trailing offset syntax rather than falling back to a shorter prefix. Supersedes: F06-5.

### Prior findings

- F02-1 - not-checked - The site ranking implementation and judge-weight calibration were not inspected; the previously read decisions specify an unweighted primary score.
- F02-2 - fixed - The raw-model regex proposal remains rejected; outbound reviewer and judge model values remain constrained to closed lists.
- F02-5 - not-checked - The site's window aggregation and overflow fixture were not inspected in this bridge-only range.
- F02-6 - still-open - The dedicated coordinator classifier addresses missing provider_config, but endpoint-independent public model recognition remains absent by policy. A read-only probe still returned other for gpt-6-astra with no recognized vendor.
- F03-1 - not-checked - The decisions reject recursively derived judge weights, but the site implementation was not independently checked.
- F06-1 - fixed - The mark now saves the sanitized judge even with telemetry off; retries and backfill use that saved value. Source inspection, the added RC1 fixture, and a read-only serialization probe support the fix.
- F06-2 - still-open - Successful commits, delayed retries, and backfill now preserve revisions and mark timestamps. Finding #1 narrows the remaining defect to publication before durable commit and consequent revision reuse.
- F06-3 - fixed - The five-minute allowance preserves just-passed resets, including across midnight. The original half-second case and all 52 reset samples passed read-only execution.
- F06-4 - fixed - Both offsets are considered in the repeated hour. The original second-02:15 case now returns the same day's second 02:30; the spring-gap sample also passed.
- F06-5 - still-open - The original UTC case and supported complete numeric offsets now work. Finding #2 replaces the broad claim with the narrower malformed-qualifier prefix acceptance issue.
- F06-6 - fixed - README now explicitly describes consult_ref as pseudonymous, explains the ledger join, and disclaims unlinkability after ledger sharing; this implements the requested documentation remedy.

## Verdict: HOLD

The ordinary recovery paths are fixed, but publishing before the local rating commit allows an uncommitted revision to escape and subsequently be reused.

### Blockers

- **F08-1** `plugins/codex-consult/scripts/codex-findings.ps1:477`, `plugins/codex-consult/scripts/codex-findings.ps1:505`, `plugins/codex-consult/scripts/codex-findings.ps1:527`, `plugins/codex-consult/scripts/codex-consult-common.ps1:13620` - R1: A rating revision can be published before its mark is durably committed and then reused after a failed save, defeating revision-based replacement ordering. Verify: Execute RC1 with fault injection between the successful spool append and the findings save, then inspect revision reuse and aggregation under both delivery orders. Remedy: Durably commit the mark, judge, timestamp, and revision before making its event available to the sender. Publish afterward and record telemetry_sent separately; an interrupted publish can be recovered from the committed mark through backfill.
- **F06-2** (prior, still-open) `plugins/codex-consult/scripts/codex-findings.ps1:487`, `plugins/codex-consult/scripts/codex-findings.ps1:537`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12075`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12086` - R2: consult_ref supplies identity but not reliable replacement ordering: delayed retries acquire a fresh timestamp, and distinct ratings within one second become indistinguishable by client_time. Verify: Execute RC2 and confirm the aggregation retains the last committed mark regardless of retry or delivery order. Remedy: Persist an ordering token with each mark, preferably a monotonic per-consultation revision allocated under the lock, and preserve it across every send path. Pass the original rating timestamp as well; define the intake's replacement rule explicitly.

### Unproven scenarios

- The successful-spool/failed-local-commit path was established by source order and an allocation probe, not a full process-level fault-injection run.
- Filesystem-writing harnesses and the reported intake tests were not independently rerun; only the 52 reset samples and additional pure-function probes were executed.
- The deployed intake's grouping key, revision comparison, tiebreakers, and additive-field handling were not independently inspected.
- Dated timezone qualifiers remain documented as T9; this review did not establish a fix for that separate limitation.

### First-run checklist (observable)

_(none)_
