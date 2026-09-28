# Handoff 26 - Codex: reply-mimo

Date: 2026-09-28 05:55 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/AppData/Local/Temp/claude/C--Users-Dmytro-claude-codex-consult/2e5096df-2bb2-46b1-8e0e-f97f37eaab90/scratchpad/roster-wave25-accept.json - position 3 of 8, panel a011f18e member 2 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 32739c73-9a54-40bd-9b15-1377e585ab02.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-71aa418e5d3447da9ecb1d4a5a3ba663.md fork 01a0e475-5a51-7963-8365-e341cfd32148 -` (prompt on stdin).
Parent thread: `01a0e475-5a51-7963-8365-e341cfd32148`. Result thread: `01a0e627-a22d-7681-be3b-6250f9fad1f4` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/24-claude-wave26b-reacceptance.md` (sha256 65b6a66ee54d). Reviewed: e868859, base e86885902470d8f046bcaa66fdea437830dc8411, tree sha256 8f4f3c592c0e, 0 changed files.
Bridge outcome: usable reply (after a timeout continuation). Wall time: 2411.4 s. Tokens: unknown.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `f29f5ca..35d4a32` - the range changes 63 files, 10064 lines (9808 insertions, 256 deletions).
Timeout continuation: the main turn was killed at 2411.4 s of 3600 s; one continuation turn on thread `01a0e627-a22d-7681-be3b-6250f9fad1f4` answered in 176 s. Tokens of that turn: in 31643397 (cached 23991040), out 126952, reasoning 75847.
Verdict: HOLD - Wave 26b fixes the targeted findings, but kick acknowledgment races, silent health-merge update loss, and false stall kills remain major defects. Findings: 0 blocker, 3 major, 2 minor, 1 note (F26-1..F26-6, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/26-codex-reply-mimo.reply.json`.
Raw event stream: `handoffs/26-codex-reply-mimo.events.jsonl`; further turns: `handoffs/26-codex-reply-mimo.continue.events.jsonl`.
Verbatim reply follows.

---

## 1. F22-1..7 and F19-1
F22-1 is fixed for the stated symlink/junction threat: `Get-RoleFileProblem` checks containment, rejects a reparse point on the file and every directory component, and `Resolve-RoleFile` also rejects a linked roles root (`codex-consult-common.ps1:6391-6434`). Hard links and replacement after the checks remain an accepted limitation. F22-2 is fixed by delimiter/whitespace rejection and field-wise matching (`:5339-5368,5429-5435,5487-5493`). F22-3 is fixed by feasibility-checked role matching (`:6457-6545`). F22-4 is fixed by length-prefixed seed fields (`:6139-6157`). F22-5 is fixed per D5: reserve is computed after required pins and recorded (`:6188-6217,6339`). F22-6 is still open in narrowed form: property presence, rather than field validity, controls legacy completion (`:6029-6057`). F22-7 is fixed for the stated normalization contract (`codex-scoreboard.ps1:165-183`). F19-1 is still open in narrowed form: `size_asked` is recorded, but increasing the size for required reviewers remains silent (`codex-consult-common.ps1:6291-6319`; `codex-consult.ps1:2835-2836`).

## 2. New defects
Finding #1 is major: the kick protocol races a natural or timeout exit and can leave a stale kick file while `-Kick` waits for acknowledgement. Finding #2 is major: machine-health ties do not implement the promised later-`until` rule and a timed-out lock silently drops an update. Finding #3 is major: the stall detector treats a long silent tool call as a stalled member. Finding #4 is the narrowed legacy-rating defect. Finding #5 is the residual F19-1 size warning. Finding #6 records the accepted role-file TOCTOU/hard-link limitation. `partialOnFailure` writes nothing for an empty first-request failure, and the write-disabled warning is capability-gated rather than applied to agy.

## 3. Acceptance decision
HOLD. Make kick handling consume or reject a kick atomically even when the member exits or times out concurrently; make health updates fail visibly or retry without dropping records, including the specified tie-break; and prevent stall kills during a known long-running tool call or make the detector activity-aware. Then run the checklist below.

## Requested checks
RC1 — Working directory `C:\Users\Dmytro\claude-codex-consult`; workspace-write; 10 minutes. Create a fake member that exits as `-Kick` writes its file, and one where timeout and kick coincide. Finding #1 is settled if `-Kick` terminates without a stale file and reports a deterministic outcome.
RC2 — Same directory; workspace-write; 10 minutes. Concurrently add quota and `ok` health records with equal `when` and different `until`, plus a forced 10-second lock contention. Finding #2 is settled if the later `until` wins and neither writer's row disappears.
RC3 — Same directory; workspace-write; 5 minutes. Let a fake tool call emit no event for longer than `-StallSec` while making progress. Finding #3 is settled if the member survives or reports an explicit configurable no-output policy.

---

### Findings

- **F26-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:7895`, `plugins/codex-consult/scripts/codex-consult-common.ps1:7896` - The kick protocol has no atomic acknowledgement: Wait-EngineProcess checks process exit before checking the kick file, so a member that exits after `-Kick` creates the file but before the next poll never consumes it. The kick command then waits for deletion and the stale file remains for the next run with the same handoff number. Trigger: `-Kick -Member NN` is issued during the instant when the member finishes naturally or reaches its timeout. Evidence: read-code: the loop returns on WaitForExit success before examining KickPath; only a detected kick removes the file.; inferred: a file created after the last successful poll can remain while -Kick waits for acknowledgement. Verify: Race a fake member's exit against kick creation repeatedly and assert every invocation reaches a deterministic acknowledged or no-longer-running result without leaving `.consult.kick-*`. Remedy: Use an atomic claim token or acknowledgement file, and have member finalization consume any kick addressed to it; make `-Kick` distinguish consumed, superseded and already-finished outcomes.
- **F26-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5094`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5107`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5071` - The machine-wide health update can silently lose records when lock acquisition times out, and the promised same-instant tie-break by later `until` is not represented: machine records expose retry_after but not their stored `until`, then merge by timestamp and n without an `until` comparison. Trigger: Two repositories write conflicting records at the same timestamp, or a writer cannot acquire `<health>.lock` for 10 seconds. Evidence: read-code: lock timeout returns false without persisting or surfacing the pending update.; read-code: conversion does not carry the record's stored until or provide the declared later-until tie-break. Verify: Concurrently write equal-time conflicting records and separately hold the lock for 11 seconds; inspect final health and caller-visible errors. Remedy: Queue or retry updates with an explicit failure signal, and merge records with keys `(when, until)` or explicitly implement the declared tie-break.
- **F26-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:7873`, `plugins/codex-consult/scripts/codex-consult-common.ps1:7897` - The stall detector measures only complete newline-delimited stream output, so a healthy member executing one long tool call is killed after `stall_sec` even though its process is actively working and may emit no complete event until the call returns. Trigger: A reviewer starts a tool call that runs longer than the default 900-second stall window without intermediate complete event lines. Evidence: read-code: only newline growth resets the silent timer; process CPU, child activity and an open tool-call state are ignored.; inferred: tool implementations need not emit complete event lines while executing. Verify: Run a fake tool call that writes no complete line for longer than StallSec and verify whether it survives while visibly active. Remedy: Reset the timer for recognized tool-start/activity events and child-process activity, or require explicit idleness before cutting; keep a hard overall timeout as the safety bound.
- **F26-4** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:6029`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6052` - Legacy-rating completion checks property presence rather than required-field validity, so a mark containing empty `purpose`, `topics`, or `engine` fields bypasses ledger completion and can route under an empty purpose or lose topic credit. Trigger: A legacy rating has consult_id and provider/model but carries `purpose:""`, `topics:[]`, or `engine:""`. Evidence: read-code: needJoin omits empty-value checks for these fields, while later replacement occurs only when a property is absent. Verify: Feed such a mark with a matching ledger entry and inspect the normalized purpose, topics and engine. Remedy: Treat missing or invalid values uniformly, join the ledger for every incomplete field, and discard records still unresolvable. Supersedes: F22-6.
- **F26-5** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:6295`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6318`, `plugins/codex-consult/scripts/codex-consult.ps1:2836` - Panel size is still adjusted silently in the upward direction: required reviewers raise the seat count above `size_asked`, but the warning covers only a downward clamp and the dry-run summary omits `asked`. Trigger: `-PanelSize 2 -Require a,b,c` has three required eligible reviewers and seats three. Evidence: read-code: the required-count raise precedes the warning, which compares only against the reduced case.; read-code: the dry-run summary does not state the requested count. Verify: Dry-run the trigger and inspect warnings and summary wording for both size directions. Remedy: Warn whenever effective size differs from requested size and show `asked/effective` in both dry-run and real summaries. Supersedes: F19-1.
- **F26-6** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:6398`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6433` - Role containment proves absence of reparse points but not stable final-target identity: a hard link or replacement between validation and reading can still expose another file. Trigger: A privileged or concurrent actor replaces a validated role file or supplies a hard-link alias before Read-SharedText. Evidence: read-code: checks and the later read are separate filesystem operations; no file handle is opened and validated atomically. Verify: Replace a role file between validation and read under a test hook and observe which contents enter the prompt. Remedy: Open once with no-follow semantics, validate the opened handle's final path and metadata, then read that handle; otherwise document hard links and TOCTOU as accepted. Supersedes: F22-1.

### Prior findings

- F02-1 - not-checked - Companions-wave scoring work is outside the assigned F22/F19 ruling scope.
- F02-2 - not-checked - Companions-wave telemetry work is outside the assigned ruling scope.
- F02-3 - not-checked - Companions-wave telemetry work is outside the assigned ruling scope.
- F02-4 - not-checked - Topic scoring is outside the assigned ruling scope.
- F02-5 - not-checked - Diversity behavior is outside the assigned ruling scope.
- F02-6 - not-checked - Panel-size semantics are outside the assigned ruling scope.
- F02-7 - not-checked - Routing seed behavior is outside the assigned ruling scope.
- F02-8 - not-checked - Routing fallback behavior is outside the assigned ruling scope.
- F02-12 - not-checked - -Require is outside the assigned ruling scope.
- F02-13 - not-checked - Roles are outside the assigned ruling scope.
- F02-14 - not-checked - Companions-wave tests are outside the assigned ruling scope.
- F02-15 - not-checked - Documentation evidence is outside the assigned ruling scope.
- F03-1 - not-checked - R15 scoring is outside the assigned ruling scope.
- F03-2 - not-checked - R14 diversity is outside the assigned ruling scope.
- F03-3 - not-checked - R16 role traversal is outside the assigned ruling scope.
- F03-6 - not-checked - R15 fallback is outside the assigned ruling scope.
- F03-7 - not-checked - R15 seed portability is outside the assigned ruling scope.
- F03-8 - not-checked - R16 role assignment is outside the assigned ruling scope.
- F03-9 - not-checked - -Require behavior is outside the assigned ruling scope.
- F03-10 - not-checked - Roster schema work is outside the assigned ruling scope.
- F03-11 - not-checked - Topic telemetry is outside the assigned ruling scope.
- F03-12 - not-checked - Panel sizing is outside the assigned ruling scope.
- F04-1 - not-checked - R14/R15 selection is outside the assigned ruling scope.
- F04-2 - not-checked - Telemetry joins are outside the assigned ruling scope.
- F04-3 - not-checked - Lab grouping is outside the assigned ruling scope.
- F04-4 - not-checked - R15 scoring is outside the assigned ruling scope.
- F04-5 - not-checked - R15 seeding is outside the assigned ruling scope.
- F04-6 - not-checked - R15 portability is outside the assigned ruling scope.
- F04-7 - not-checked - -Require availability is outside the assigned ruling scope.
- F04-8 - not-checked - -Require matching is outside the assigned ruling scope.
- F04-11 - not-checked - Panel state modeling is outside the assigned ruling scope.
- F04-12 - not-checked - R14/R15 test compatibility is outside the assigned ruling scope.
- F04-13 - not-checked - Roster schema work is outside the assigned ruling scope.
- F04-14 - not-checked - Exploration gates are outside the assigned ruling scope.
- F04-15 - not-checked - Exit-code documentation is outside the assigned ruling scope.
- F04-16 - not-checked - R16 roles are outside the assigned ruling scope.
- F04-17 - not-checked - Panel sizing and peak behavior are outside the assigned ruling scope.
- F04-18 - not-checked - Telemetry details are outside the assigned ruling scope.
- F15-1 - not-checked - Failure-classification work is outside the assigned ruling scope.
- F15-2 - not-checked - Identity-cache work is outside the assigned ruling scope.
- F15-3 - not-checked - Killed-turn classification is outside the assigned ruling scope.
- F15-4 - not-checked - Failure hints are outside the assigned ruling scope.
- F15-5 - not-checked - Resume serialization is outside the assigned ruling scope.
- F15-6 - not-checked - Recovery-record restoration is outside the assigned ruling scope.
- F19-1 - still-open - size_asked and a down-clamp warning were added, but the required-pin increase remains silent; narrowed by finding #5.
- F22-1 - fixed - File and directory reparse checks plus containment reject the stated symlink/junction threat at common.ps1:6391-6434; hard links/TOCTOU are finding #6.
- F22-2 - fixed - Reserved delimiters and edge whitespace are rejected and matchers compare fields.
- F22-3 - fixed - Exact feasibility-checked role matching replaces greedy willingness violations.
- F22-4 - fixed - Seed fields are length-prefixed.
- F22-5 - fixed - The lab reserve is computed after required pins and recorded.
- F22-6 - still-open - Missing properties are completed, but present empty fields still bypass completion; narrowed by finding #4.
- F22-7 - fixed - UNIQ paths normalize separators, case, repeated separators and leading `./`.

## Verdict: HOLD

Wave 26b fixes the targeted findings, but kick acknowledgment races, silent health-merge update loss, and false stall kills remain major defects.

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- No harness or race test was executed during this read-only review.
- Kick exit/timeout races were inferred from control-flow ordering.
- Machine-health same-timestamp conflicts and lock starvation were not reproduced.
- Long tool calls may emit adapter-specific activity absent from the inspected generic stream logic.
- Hard-link and replace-after-check role-file behavior was not exercised.
- The write-disabled warning was traced as engine-capability-gated, but agy and muse behavior was not run live.
- Context estimates using real tokenizers and multi-megabyte histories were not benchmarked.

### First-run checklist (observable)

- [ ] Kick a member immediately before its natural exit and during a timeout boundary; observe a deterministic terminal result, no stale `.consult.kick-*`, correct partial salvage, and class `operator`.
- [ ] Force one stall interval inside a long tool call while it makes observable child-process progress; observe no false kill, or an explicit documented no-output cut with salvage and continuation behavior.
- [ ] Write conflicting machine-health records concurrently and hold the health lock past its timeout; observe the declared tie-break and no silently lost endpoint or running row.
- [ ] Run a first-request refusal with an empty stream and one with genuine content; observe no artifact in the first case and exactly one partial salvage in the second.
- [ ] Use muse with write disabled and agy normally while external files change; observe `tree_check.outcome=warned` only for muse and a usable reply, never a downgraded agy result.
- [ ] Exercise fork fallback and brief-size refusal with low/high context windows; observe estimates, `mode_fallback`, the previous-reply prompt, and no member started after the oversized refusal.
