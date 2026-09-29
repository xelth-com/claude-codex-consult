# Handoff 30 - Codex: reply-mimo

Date: 2026-09-29 15:53 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 10, panel 10667beb member 2 of 4.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 5634bee3-2884-4bac-9358-baac55ddf342.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-d2afbd52c90f430eb459d1d80535c82a.md fork 01a0e627-a22d-7681-be3b-6250f9fad1f4 -` (prompt on stdin).
Parent thread: `01a0e627-a22d-7681-be3b-6250f9fad1f4`. Result thread: `01a0ed71-2dd1-7081-a9e8-98503575ca6e` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/28-claude-wave27-acceptance.md` (sha256 d0cf1c977922). Reviewed: ab479c8, base ab479c81942ebd88c28c8206b3e64ec579f81f1b, tree sha256 d4485dee9d29, 0 changed files.
Bridge outcome: usable reply. Wall time: 1917 s. Tokens: in 44165180 (cached 33517824), out 146711, reasoning 87473.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `35d4a32..c6f6966` - the range changes 40 files, 5642 lines (5408 insertions, 234 deletions).
Verdict: HOLD - Wave 26c fixes the named races and stall cases, but concurrent kicks, partial-line scanning, and exception-safe host scrubbing still leave major defects. Findings: 0 blocker, 3 major, 6 minor, 0 note (F30-1..F30-9, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/30-codex-reply-mimo.reply.json`.
Raw event stream: `handoffs/30-codex-reply-mimo.events.jsonl`.
Verbatim reply follows.

---

## 1. F26-1..5 and F25-1..2
F25-1 is fixed: byte growth resets the stall timer, tool-flight suspends it, and `TimeoutSec` remains a hard bound (`codex-consult-common.ps1:8213-8275`). F25-2 is fixed: post-exit kicks become `kick_late`, and a repair-only kick preserves the first reply (`codex-consult-common.ps1:8246-8251`; `codex-consult.ps1:5004-5007`). F26-1 is fixed for one caller by pre-loop, poll and post-exit checks plus acknowledgement (`codex-consult-common.ps1:8216-8251`); concurrent callers remain defective. F26-2 is fixed for lock timeouts and tie-breaking: three 5-second attempts, stored `until`, the later-until sort and a ledger-commit retry (`codex-consult-common.ps1:4989-4999,5125-5141`; `codex-consult.ps1:5039,5491-5497`); non-lock failures remain unreported. F26-3 is fixed for long tool calls and complete-line silence; partial-line processing remains defective. F26-4 and F26-5 are fixed: empty legacy fields count as missing, and a required-size increase records `size_asked`, `size_source: required` and warns.

## 2. New defects
Finding #1 is major: simultaneous `-Kick` callers delete or recreate one another's acknowledgement. Finding #2 is major: `Hide-HostMarkers` is not transactional, so an exception can permanently remove coordinator markers. Finding #3 is major: an ever-growing partial line is rescanned every tick, causing quadratic work and unbounded memory. Findings #4-#9 are minor risks in probe scrubbing, inter-turn kicks, acknowledgement cleanup, health error reporting, model-less coordinator matching and otherwise-valid coordinator strings. I verified the cited code and binding decisions at `c6f6966`; timing and exception behavior are inferred because no harness was run.

## 3. Acceptance decision
HOLD. Make kick requests tokenized and idempotent, make host-marker hiding transactional and probe scrubbing fail closed, and parse partial lines incrementally with bounded memory. Then run the checklist under Windows PowerShell 5.1 and PowerShell 7.

## Requested checks
RC1 — `C:\Users\Dmytro\claude-codex-consult`; workspace-write; 10 minutes. Start one fake member and invoke `-Kick` twice concurrently; finding #1 requires one authoritative acknowledgement, no stale kick/ack, and deterministic exits.
RC2 — Same directory; workspace-write; 5 minutes. Force the second marker removal to throw; finding #2 requires all markers restored and no child launched.
RC3 — Same directory; workspace-write; 5 minutes. Grow one 50 MB partial JSON line one kilobyte per tick; finding #3 requires bounded memory/CPU while timeout and kick polling remain responsive.
RC4 — Same directory; workspace-write; 5 minutes. Force health lock and write failures separately; findings #6/#7 require accurate warnings and retries for each failure class.
RC5 — Same directory; read-only; 5 minutes. Run `-Explain` for all three keys and inspect the fixed skill paths; no traversal or unrelated file may be returned.

---

### Findings

- **F30-1** [major] `plugins/codex-consult/scripts/codex-consult.ps1:1180`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8104` - Concurrent `-Kick` callers corrupt one shared acknowledgement protocol: each deletes `<kick>.ack` before writing the kick and deletes it after reading, while the member writes one shared ack and removes the kick. One caller can erase another's acknowledgement or recreate a consumed kick, producing false success, exit 3, or a stale request. Trigger: Two operators invoke `-Kick -Member NN` for the same running member at nearly the same time. Evidence: read-code: both callers use and delete the same kick and ack paths without request identity.; read-code: Confirm-Kick writes one unkeyed acknowledgement and deletes the shared kick. Verify: Race two kick invocations repeatedly and assert every caller receives the same idempotent terminal result and no kick or ack remains. Remedy: Write kick requests atomically with unique request tokens and store acknowledgement per token; never let one caller delete another request's state.
- **F30-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5515`, `plugins/codex-consult/scripts/codex-consult.ps1:1050` - Host-marker removal is not transactional. Hide-HostMarkers mutates variables one at a time and returns its saved map only after all removals; if an environment mutation throws midway, callers hold `$null` and cannot restore already-removed session markers. Trigger: The second marker removal throws while starting an engine child, probe, or detached background. Evidence: read-code: the saved map is returned only after the mutation loop completes.; read-code: callers receive no partial snapshot when Hide-HostMarkers itself throws. Verify: Force SetEnvironmentVariable to fail on the second marker and inspect the coordinator environment after the exception path. Remedy: Snapshot all values first, then scrub inside a transaction with a finally-based rollback covering partial success.
- **F30-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:8115`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8125` - The new stall reader retains an unbounded incomplete line and reconstructs and rescans the entire carry every poll. A stream producing one huge partial line causes quadratic CPU growth and unbounded memory, delaying timeout and kick handling. Trigger: An engine emits a single partial JSON line continuously for longer than the polling interval, without a newline. Evidence: read-code: each tick prepends the full carry to all newly read bytes and scans the combined buffer.; inferred: carry length grows with the stream while the combined buffer is copied each second. Verify: Feed a 50 MB partial line incrementally and measure memory and polling latency while the hard timeout and kick remain active. Remedy: Scan only new bytes for line endings and retain a bounded tail, or stream-parse incrementally without rebuilding the carry.
- **F30-4** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:5533`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3013` - Probe scrubbing fails open: Remove-HostMarkersFromStartInfo suppresses every exception and callers still start the probe, allowing host session markers into launcher checks without warning. Trigger: EnvironmentVariables.Remove throws while preparing `codex login status`, `agy models`, or a launcher probe. Evidence: read-code: the function catches all errors and returns no status.; read-code: probe callers proceed regardless of scrub success. Verify: Make one environment-key removal fail and inspect the fake probe's inherited environment and caller diagnostics. Remedy: Verify the final start-info block is marker-free and fail closed or record an explicit warning before starting.
- **F30-5** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:8242`, `plugins/codex-consult/scripts/codex-consult.ps1:4168` - A kick created after one turn's post-exit check but before the next turn begins is treated as live by that next turn, so an otherwise late kick can stop a repair or continuation and change the run's outcome. Trigger: `-Kick` lands between a usable main turn's exit and the start of its format repair or another secondary turn. Evidence: read-code: kick freshness is inferred from the current process state, not the kick's intended turn or creation time. Verify: Create the kick in the inter-turn gap and inspect whether it is recorded as kick_late or stops the next turn. Remedy: Bind kick requests to the target child pid/start-time or turn id and classify stale-target requests as late.
- **F30-6** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:8107`, `plugins/codex-consult/scripts/codex-consult.ps1:4170` - After `-Kick` exits 3, a later acknowledgement is left on disk until the next same-number run, leaving stale protocol state and confusing later callers. Trigger: The member acknowledges just after the 10-second caller timeout. Evidence: read-code: the member writes the ack but has no acknowledgement-retirement window.; read-code: ack cleanup occurs only at the next run's startup. Verify: Force an acknowledgement at 10.1 seconds and inspect the task directory after completion. Remedy: Retire acknowledgement state after a bounded window or keep one atomic request/status record.
- **F30-7** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:5039`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5164` - Health persistence retries only lock timeouts. Other write failures are silently dropped, and a failed retry is always labelled `lock timeout`, obscuring the real cause. Trigger: The health file write fails because of permissions, disk full, or another I/O error. Evidence: read-code: non-IO exceptions return false without setting MachineHealthLastError.; read-code: retry selection and warning text are tied only to lock timeout. Verify: Force lock and write failures separately and inspect retry behavior and warnings[]. Remedy: Classify all update failures, retry transient failures, and report the actual terminal cause.
- **F30-8** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:5575`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5600` - A roster-position coordinator whose entry has no model becomes a provider-wide wildcard, so it warns for every model under that provider although only one resolved identity is the coordinator. Trigger: `CODEX_CONSULT_COORDINATOR=#1` names a model-less entry and the panel seats another model of the same provider. Evidence: read-code: the model-less position is converted to provider plus null model.; inferred: a null model matches every model of that provider. Verify: Run the trigger and count coordinator warnings for unrelated models. Remedy: Preserve roster-position identity or require a model-bearing coordinator matcher for model-specific warnings.
- **F30-9** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:5585`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5762` - The roster accepts provider and model strings with interior spaces, but coordinator parsing rejects them, so some valid reviewer identities cannot be named in `CODEX_CONSULT_COORDINATOR`. Trigger: A roster uses provider `Acme Lab` and model `model v2`, then the coordinator names that exact identity. Evidence: read-code: coordinator validation forbids whitespace in models and restrictive provider syntax.; read-code: roster validation permits non-empty strings with interior spaces. Verify: Load that roster and set the exact coordinator identity; observe refusal before any run. Remedy: Align coordinator parsing with roster identity grammar or restrict roster identities to the same portable grammar.

### Prior findings

- F02-1 - not-checked - Companions-wave scoring work is outside this wave's ruling scope.
- F02-2 - not-checked - Companions-wave telemetry work is outside this wave.
- F02-3 - not-checked - Companions-wave telemetry work is outside this wave.
- F02-4 - not-checked - Topic scoring is outside this wave.
- F02-5 - not-checked - Diversity behavior is outside this wave.
- F02-6 - not-checked - Panel-size semantics are outside this wave.
- F02-7 - not-checked - Routing seed behavior is outside this wave.
- F02-8 - not-checked - Routing fallback behavior is outside this wave.
- F02-12 - not-checked - -Require is outside this wave.
- F02-13 - not-checked - Roles are outside this wave.
- F02-14 - not-checked - Companions tests are outside this wave.
- F02-15 - not-checked - Documentation evidence is outside this wave.
- F03-1 - not-checked - R15 scoring is outside this wave.
- F03-2 - not-checked - R14 diversity is outside this wave.
- F03-3 - not-checked - R16 role safety is outside this wave.
- F03-6 - not-checked - R15 fallback is outside this wave.
- F03-7 - not-checked - R15 seed portability is outside this wave.
- F03-8 - not-checked - R16 role assignment is outside this wave.
- F03-9 - not-checked - -Require behavior is outside this wave.
- F03-10 - not-checked - Roster schema behavior is outside this wave.
- F03-11 - not-checked - Topic telemetry is outside this wave.
- F03-12 - not-checked - Panel sizing is outside this wave.
- F04-1 - not-checked - R14/R15 selection is outside this wave.
- F04-2 - not-checked - Telemetry joins are outside this wave.
- F04-3 - not-checked - Lab grouping is outside this wave.
- F04-4 - not-checked - R15 scoring is outside this wave.
- F04-5 - not-checked - R15 seeding is outside this wave.
- F04-6 - not-checked - R15 portability is outside this wave.
- F04-7 - not-checked - -Require availability is outside this wave.
- F04-8 - not-checked - -Require matching is outside this wave.
- F04-11 - not-checked - Panel state modeling is outside this wave.
- F04-12 - not-checked - R14/R15 test compatibility is outside this wave.
- F04-13 - not-checked - Roster schema behavior is outside this wave.
- F04-14 - not-checked - Exploration gates are outside this wave.
- F04-15 - not-checked - Exit-code documentation is outside this wave.
- F04-16 - not-checked - R16 roles are outside this wave.
- F04-17 - not-checked - Panel sizing and peak behavior are outside this wave.
- F04-18 - not-checked - Telemetry details are outside this wave.
- F15-1 - not-checked - Failure classification is outside this wave.
- F15-2 - not-checked - Identity caching is outside this wave.
- F15-3 - not-checked - Killed-turn classification is outside this wave.
- F15-4 - not-checked - Failure hints are outside this wave.
- F15-5 - not-checked - Resume serialization is outside this wave.
- F15-6 - not-checked - Recovery restoration is outside this wave.
- F19-1 - fixed - Wave 26c D5 records size_asked and warns when required reviewers raise the panel size.
- F22-6 - fixed - Wave 26c D4 treats empty legacy fields as missing during completion.
- F25-1 - fixed - Byte growth and tool-flight suspension prevent long silent tool calls from triggering the stall cut.
- F25-2 - fixed - Post-exit kicks are recorded late and repair-only kicks preserve the first reply.
- F26-1 - fixed - Pre-loop, poll and post-exit checks plus acknowledgement fix the original single-caller race; concurrency is a new finding.
- F26-2 - fixed - Lock retries, stored until and the tie-break fix the original claim; non-lock failures are a new finding.
- F26-3 - fixed - Long tool calls and complete-line silence are handled; partial-line complexity is a new finding.
- F26-4 - fixed - Legacy completion now treats empty or whitespace fields as missing.
- F26-5 - fixed - Required-size increases record size_asked, size_source and a warning.

## Verdict: HOLD

Wave 26c fixes the named races and stall cases, but concurrent kicks, partial-line scanning, and exception-safe host scrubbing still leave major defects.

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- No harness or timing test was executed during this read-only review.
- Concurrent kick behavior and the inter-turn kick gap were inferred from file protocol ordering.
- The partial-line performance issue was derived from repeated buffer reconstruction rather than measured.
- Environment-mutation and probe-scrub exceptions were not injected.
- Coordinator wildcard and whitespace-identity cases were reasoned from matcher semantics, not run.
- The documented Codex, Z Code and Kimi Code commands were not executed against live hosts.

### First-run checklist (observable)

- [ ] Run two concurrent kicks against one member and observe one idempotent acknowledgement, no stale `.consult.kick-*` or `.ack`, and deterministic caller exits.
- [ ] Force an environment mutation failure while hiding markers and observe every marker restored with no child process launched.
- [ ] Grow one long partial event line while exercising timeout and kick polling; observe bounded resources and responsive termination controls.
- [ ] Force separate health lock and write failures; observe the correct retry policy and exact failure in warnings[].
- [ ] Exercise model-less `#n`, provider-label and spaced-identity coordinator cases and observe precise own-model warnings or documented refusals.
- [ ] Run `-Explain coordinate|consult|providers` and the documented host entry points; observe only intended skill text and no path outside the plugin skill directories.
