# Handoff 36 - Codex: reply-mimo

Date: 2026-09-30 00:35 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 10, panel a0199558 member 2 of 4.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 9dbd280a-8001-46db-af93-58e2c191b3fb.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-9a9c70f21cfb41eebe7e4cd159818388.md fork 01a0ed71-2dd1-7081-a9e8-98503575ca6e -` (prompt on stdin).
Parent thread: `01a0ed71-2dd1-7081-a9e8-98503575ca6e`. Result thread: `01a0ef4e-e4bf-7083-ab35-391f19b63316` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/34-claude-wave28-acceptance.md` (sha256 894b55c3dbab). Reviewed: 062af37, base 062af37f4c0db8af3a422233688ba240280d94fc, tree sha256 6885ea1982d3, 0 changed files.
Bridge outcome: usable reply (after a timeout continuation). Wall time: 3604.6 s. Tokens: unknown.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `c6f6966..1de388e` - the range changes 62 files, 12210 lines (11766 insertions, 444 deletions).
Timeout continuation: the main turn was killed at 3604.6 s of 3600 s; one continuation turn on thread `01a0ef4e-e4bf-7083-ab35-391f19b63316` answered in 629.5 s. Tokens of that turn: in 54116060 (cached 40304256), out 164108, reasoning 94254.
Verdict: HOLD - Wave 27c fixes the listed control defects, but telemetry can transmit operator-chosen text and its sender remains unbounded and over-privileged. Findings: 0 blocker, 5 major, 6 minor, 0 note (F36-1..F36-11, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/36-codex-reply-mimo.reply.json`.
Raw event stream: `handoffs/36-codex-reply-mimo.events.jsonl`; further turns: `handoffs/36-codex-reply-mimo.continue.events.jsonl`.
Verbatim reply follows.

---

## 1. F29-1..2, F30-1..9, F32-1..11
All are fixed at `1de388e`. Kick requests now have atomic ids, joiners and id-specific acknowledgements (`codex-consult-common.ps1:8409-8424`); inter-turn kicks cancel only the pending secondary turn and preserve the prior outcome; host-marker hiding is transactional and probes fail closed (`:5562-5635`); the stream reader scans new bytes and caps the carry (`:8427-8483`); health failures are classified and retried outside the task lock (`:5145-5238`; `codex-consult.ps1:5255-5257,5715-5721`); coordinator resolution records `in_roster`, `unresolved`, and `host_by` (`common.ps1:5722-5805`); test hooks require `CODEX_CONSULT_TEST_MODE=1`; kill confirmation is recorded; and the documented commands and waiting arithmetic were added. F30-5 is an accepted limitation and the README/member-control text matches the code: a kick addresses the run, not one turn.

## 2. New defects
Finding #1 is major: provider labels and model ids are operator-controlled text and can carry user, customer or project names into telemetry despite the anonymisation claim. Findings #2-#4 are major: the sender has neither a total deadline nor a minimal environment, the test-mode gate itself reaches reviewer children, and path-based host inference false-positives on ordinary repository/user paths. Findings #5-#11 cover health retry durability, complaint retry bytes, spool loss, salt races, plaintext loopback intake, an unusable documented hook command, and cache-cost wording. Code behavior was verified by reading `1de388e`; timing, crash, and environment outcomes are inferred.

## 3. Acceptance decision
HOLD. Canonicalize or hash provider/model telemetry, bound the complete sender with a minimal allowlisted environment, require test mode for loopback HTTP and warn/scrub test mode itself, fix host-path ancestry matching, and repair the listed durability/documentation edges. The planned 28b changes are directionally correct; batch halving on 413 works only while every individual event and complaint stays below 64 KiB.

## Requested checks
RC1 — `C:\Users\Dmytro\claude-codex-consult`; workspace-write; 10 minutes. Use hostile provider/model labels and inspect the captured intake event; finding #1 requires no operator-chosen text.
RC2 — Same directory; workspace-write; 15 minutes. Use a hanging local intake and a large spool while exporting credentials and test hooks; findings #2-#3 require a bounded sender and a minimal inherited environment.
RC3 — Same directory; workspace-write; 5 minutes. Run from paths containing `.codex`, `.claude`, and `.zcode` with no host markers; finding #4 requires `host_by=none`.
RC4 — Same directory; workspace-write; 5 minutes. Force health write failure, crash before the post-commit retry, and complaint delivery failure; findings #5-#8 require durable, byte-stable, non-lossy behavior.
RC5 — Same directory; read-only; 5 minutes. Copy the Kimi/OpenCode/Muse hook block verbatim and recompute the documented cache thresholds; findings #10-#11 require runnable commands and consistent arithmetic.

---

### Findings

- **F36-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9006`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9062` - Telemetry transmits operator-controlled provider and model strings through details and tags. These are not a closed vocabulary or stable hashes, so usernames, customer/project names, or private model labels leave the machine despite the documented promise never to send a user name or operator text. Trigger: A roster or CLI invocation uses provider `alice.smith` and model `customer-secret-project` or `alice:private-model`, then telemetry is enabled. Evidence: read-code: provider and model use permissive syntax checks and provider is repeated in tags.; read-code: the surrounding contract says the event never carries a user name or operator-chosen text. Verify: Submit a hostile provider/model through a fake run and inspect the captured request body. Remedy: Use a canonical provider/model catalog, or salted stable hashes, and explicitly document any remaining free-text fields in the consent notice.
- **F36-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9373`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9227` - The telemetry sender has no end-to-end deadline. It holds the flush lock while draining every batch and complaint, and its advertised per-request timeout does not bound request-stream and response-read time together, so one slow intake can occupy the sender indefinitely and block later flushes. Trigger: A large spool or complaint backlog meets an intake that accepts the request but never finishes the response. Evidence: read-code: the lock spans the complete drain with no global cap.; read-code: request and response operations do not share one total cancellation budget. Verify: Run a large backlog against a deliberately hanging local intake and measure lock duration and later sender availability. Remedy: Add a global flush deadline, bounded work per invocation, and one monotonic timeout budget covering connect, request body, response and body read.
- **F36-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9135`, `plugins/codex-consult/scripts/codex-consult-common.ps1:280` - The detached telemetry sender inherits the coordinator's complete environment: provider credentials, test hooks, and `CODEX_CONSULT_TEST_MODE=1` survive host-marker scrubbing into a long-lived network process. The test hook can also cause that process to write environment marker names to a file. Trigger: A real run with telemetry on starts the sender while API keys and test-mode variables are present. Evidence: read-code: the sender is scrubbed only of host markers, not credentials or test state.; read-code: the sender can use a test environment-dump hook inherited from its parent. Verify: Start the sender with sentinel credential and test variables and inspect its environment through the test hook. Remedy: Launch it with a minimal allowlist such as CODEX_HOME, intake URL and telemetry switch; drop all credentials and test variables.
- **F36-4** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5654`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5661` - Path-based host inference matches `.codex`, `.claude`, or `.zcode` followed by `plugins/` anywhere in the full script path. Ordinary clone or user paths containing those segments falsely report the wrong coordinator host and `host_by=path`. Trigger: A Kimi or plain-shell installation runs from `C:\work\.codex\plugins\mirror\claude-codex-consult\plugins\codex-consult\scripts`. Evidence: read-code: the regex is unanchored and scans the complete path rather than actual plugin-cache ancestry. Verify: Run without host markers from such a path and inspect `coordinator.host` and `host_by`. Remedy: Match only canonical plugin-cache ancestry of the resolved script, or reject ambiguous embedded matches.
- **F36-5** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:283`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5507` - `CODEX_CONSULT_TEST_MODE=1` is itself retained in reviewer children and excluded from ignored-hook warnings. A value left in an operator shell silently authorizes every test hook in production and propagates test state across the network sender and reviewer processes. Trigger: A harness or prior test session exports `CODEX_CONSULT_TEST_MODE=1`, after which the operator runs a real consultation from that shell. Evidence: read-code: the mode enables hooks but is never reported as an ignored hook.; read-code: host scrubbing retains CODEX_CONSULT_* variables, including test mode. Verify: Export test mode and several hooks, then inspect both the run warning and the fake reviewer/sender environments. Remedy: Warn whenever test mode is present outside an explicit harness, and scrub test mode plus test hooks from reviewer and sender children. Supersedes: F32-10.
- **F36-6** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:5715`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5145` - Machine-health persistence has a crash window after the ledger commit and before the post-lock retry. The update exists only in memory, so a crash loses cross-repository health evidence despite the committed ledger retaining the truth. Trigger: The process exits between the ledger commit and the full health retry after write-lock release. Evidence: read-code: the retry is a later in-process call with no durable pending-health record. Verify: Crash at that boundary and inspect the machine health file after restart. Remedy: Write a durable pending health record before commit and replay it on startup, or move the sole update before commit under an idempotent record key.
- **F36-7** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:9470`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9487` - `-Complain` promises to print exactly the bytes sent, but immediate delivery sends the pretty JSON while a failed delivery spools a different compressed serialization for the later sender. Trigger: The first complaint request fails, so the queued retry sends the complaint later. Evidence: read-code: preview and immediate request use one serialization; retry storage uses another. Verify: Compare the printed payload with the eventual retry request byte for byte. Remedy: Spool the already previewed serialization unchanged and resend those exact bytes.
- **F36-8** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:9071`, `plugins/codex-consult/scripts/codex-consult.ps1:5761` - Concurrent spool writes can be lost silently. The append gives up after roughly two seconds and the bridge reports the failure only at verbose level, violating the one-event-per-commit objective under simultaneous panel commits or sender rewrites. Trigger: Four panel members commit while the sender rewrites the spool. Evidence: read-code: busy spool files return failure after a short retry.; read-code: Submit-TelemetryEvent failure is not surfaced as a run warning. Verify: Race four committers and inspect event count against committed consultations. Remedy: Use per-process append shards or a durable queue, retry longer, and expose dropped telemetry in status/warnings.
- **F36-9** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:8914`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8889` - Salt creation has a stale-read delete race, and loopback plaintext intake is allowed without test mode. Concurrent creators can lose a valid salt or a normal operator can silently send telemetry and complaint text to an arbitrary local listener over HTTP. Trigger: Panel members create the first instance concurrently, or `CODEX_CONSULT_TELEMETRY_URL=http://127.0.0.1:...` is set without test mode. Evidence: read-code: invalid salt deletion is not synchronized with atomic creation.; read-code: the HTTP loopback exception is unconditional. Verify: Race first-event creation and run a loopback HTTP intake without test mode. Remedy: Create salt atomically without stale deletes and gate plaintext loopback on explicit test mode.
- **F36-10** [minor] `README.md:250`, `README.md:399` - Host instructions remain inconsistent: Kimi/OpenCode/Muse set `CODEX_CONSULT_ROOT`, but the hook block uses `$P`; copied verbatim it runs `\scripts\codex-consult-hook.ps1`. The cache rule also mixes full-wake and cache-read costs and understates post-expiry compaction cost. Trigger: A host without plugin-root substitution copies the hook block, or an operator applies the wake threshold literally. Evidence: read-code: the hook block assumes `$P`, and the threshold/cost prose does not consistently include all wake and compact terms. Verify: Copy the documented commands verbatim and recompute both tables and threshold sentences from the stated formula. Remedy: Use `$env:CODEX_CONSULT_ROOT` in the block and state one cost model consistently in formula, tables and rule text. Supersedes: F32-9.
- **F36-11** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:8485`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8555` - Tool-flight suspension still depends on recognized completion events. An aborted or unrecognized tool with a leaked open key reaches the new maximum suspension and can hide ordinary inactivity until the hard timeout instead of allowing a bounded stall cut. Trigger: A tool-start event has no recognized completion and the turn then remains silent. Evidence: read-code: open-tool keys are only removed by recognized terminal events; the cap merely bounds the delay. Verify: Emit one tool-start without completion and silence beyond StallSec but below TimeoutSec. Remedy: Expire individual tool keys with independent activity evidence and report unmatched tool state. Supersedes: F32-7.

### Prior findings

- F02-1 - not-checked - Companions-wave scoring finding outside this acceptance scope.
- F02-2 - not-checked - Companions-wave telemetry finding outside this scope.
- F02-3 - not-checked - Companions-wave telemetry finding outside this scope.
- F02-4 - not-checked - Topic scoring outside this scope.
- F02-5 - not-checked - Diversity behavior outside this scope.
- F02-6 - not-checked - Panel sizing outside this scope.
- F02-7 - not-checked - Routing seed behavior outside this scope.
- F02-8 - not-checked - Routing fallback outside this scope.
- F02-12 - not-checked - -Require outside this scope.
- F02-13 - not-checked - Roles outside this scope.
- F02-14 - not-checked - Companions tests outside this scope.
- F02-15 - not-checked - Documentation evidence outside this scope.
- F03-1 - not-checked - R15 scoring outside this scope.
- F03-2 - not-checked - R14 diversity outside this scope.
- F03-3 - not-checked - R16 role safety outside this scope.
- F03-6 - not-checked - R15 fallback outside this scope.
- F03-7 - not-checked - R15 seed portability outside this scope.
- F03-8 - not-checked - R16 role assignment outside this scope.
- F03-9 - not-checked - -Require behavior outside this scope.
- F03-10 - not-checked - Roster schema outside this scope.
- F03-11 - not-checked - Topic telemetry outside this scope.
- F03-12 - not-checked - Panel sizing outside this scope.
- F04-1 - not-checked - R14/R15 selection outside this scope.
- F04-2 - not-checked - Telemetry joins outside this scope.
- F04-3 - not-checked - Lab grouping outside this scope.
- F04-4 - not-checked - R15 scoring outside this scope.
- F04-5 - not-checked - R15 seeding outside this scope.
- F04-6 - not-checked - R15 portability outside this scope.
- F04-7 - not-checked - -Require availability outside this scope.
- F04-8 - not-checked - -Require matching outside this scope.
- F04-11 - not-checked - Panel state modeling outside this scope.
- F04-12 - not-checked - R14/R15 tests outside this scope.
- F04-13 - not-checked - Roster schema outside this scope.
- F04-14 - not-checked - Exploration gates outside this scope.
- F04-15 - not-checked - Exit-code documentation outside this scope.
- F04-16 - not-checked - R16 roles outside this scope.
- F04-17 - not-checked - Panel sizing and peak behavior outside this scope.
- F04-18 - not-checked - Telemetry details outside this scope.
- F15-1 - not-checked - Failure classification outside this scope.
- F15-2 - not-checked - Identity caching outside this scope.
- F15-3 - not-checked - Killed-turn classification outside this scope.
- F15-4 - not-checked - Failure hints outside this scope.
- F15-5 - not-checked - Resume serialization outside this scope.
- F15-6 - not-checked - Recovery restoration outside this scope.
- F19-1 - not-checked - Panel-size reporting outside this scope.
- F22-6 - not-checked - Legacy rating completion outside this scope.
- F29-1 - fixed - Every machine-health failure is named and retried; crash durability is finding #7.
- F29-2 - fixed - Kick requests are id-keyed, atomic and joinable.
- F30-1 - fixed - Concurrent kick callers now share one request id and acknowledgement protocol.
- F30-2 - fixed - Host hiding snapshots first and rolls back partial removal.
- F30-3 - fixed - The stream reader scans new bytes and caps unfinished carry at 1 MiB.
- F30-4 - fixed - Probe scrubbing no longer fails open silently.
- F30-5 - fixed - Accepted limitation as designed: a kick addresses the run; documentation matches the code.
- F30-6 - fixed - Stale acknowledgements are request-scoped and swept.
- F30-7 - fixed - All health update failures are named and retried.
- F30-8 - fixed - Coordinator matching uses a resolved triple and a weaker provider-only warning.
- F30-9 - fixed - Roster and coordinator identity share one character grammar.
- F32-1 - fixed - Concurrent kick callers join one atomic request.
- F32-2 - fixed - The short in-lock health attempt and full post-lock retry avoid extending task-lock hold.
- F32-3 - fixed - Non-lock health failures are classified and reported.
- F32-4 - fixed - Accepted limitation: out-of-roster identities cannot be validated, but are explicitly reported rather than silently disabling warnings.
- F32-5 - fixed - Missing `#n` positions warn and continue without refusing unrelated repositories.
- F32-6 - fixed - A bare provider label emits only the provider-level warning.
- F32-7 - fixed - Tool suspension is capped; residual leaked tool keys are finding #11.
- F32-8 - fixed - Partial-line carry is bounded and only new bytes are scanned.
- F32-9 - fixed - Hook/skill paths are made runnable; the remaining `$P` command defect is finding #10.
- F32-10 - fixed - Individual test hooks now require test mode; leakage of test mode itself is finding #5.
- F32-11 - fixed - -Explain flushes and disposes its standard-output stream.

## Verdict: HOLD

Wave 27c fixes the listed control defects, but telemetry can transmit operator-chosen text and its sender remains unbounded and over-privileged.

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- No harness or live intake test was executed during this read-only review.
- Actual provider/model naming distributions and operator expectations for the anonymisation claim were not measured.
- Sender lock duration under a hanging or very slow intake was inferred from code.
- The post-commit machine-health crash window and concurrent spool/salt races were not reproduced.
- Multibyte chunk-boundary and exactly-at-cap line behavior were inspected conceptually, not stress-tested.
- Host command behavior on Qwen Code, OpenCode and Muse Code was not run live.

### First-run checklist (observable)

- [ ] Send one hostile provider/model event to a capture intake and inspect every request key and tag; no task, path, prompt, thread, user, machine or operator text may appear.
- [ ] Start a sender with credential and test variables against a hanging intake and observe a bounded stop, minimal inherited environment, and a lock released before later flushes.
- [ ] Run from paths containing `.codex`, `.claude`, and `.zcode` without host markers and observe `host_by=none`, not a false host.
- [ ] Force test-mode leakage, health write failure, process crash before health retry, spool contention and salt creation races and observe warnings, stable instance identity and no lost committed telemetry.
- [ ] Compare the printed `-Complain` payload byte-for-byte with both immediate and queued retry requests.
- [ ] Copy every Kimi/OpenCode/Muse command verbatim and recompute both waiting tables and threshold statements from their formula before believing exit code 0.
