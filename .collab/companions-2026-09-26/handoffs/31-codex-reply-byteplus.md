# Handoff 31 - Codex: reply-byteplus

Date: 2026-09-29 15:53 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 7 of 10, panel 10667beb member 3 of 4.
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: b17dac80-a846-4782-842d-8c0c63f6a9ed.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-6d63cc0136a244b6bc0d2c881432b683.md fork 01a0e475-693f-78f0-b062-8c7226a65b1c -` (prompt on stdin).
Parent thread: `01a0e475-693f-78f0-b062-8c7226a65b1c`. Result thread: `01a0ed71-4123-7451-9f94-5c8c14efffda` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/28-claude-wave27-acceptance.md` (sha256 d0cf1c977922). Reviewed: ab479c8, base ab479c81942ebd88c28c8206b3e64ec579f81f1b, tree sha256 d4485dee9d29, 0 changed files.
Bridge outcome: usable reply. Wall time: 456.8 s. Tokens: in 5531101 (cached 3049784), out 20949, reasoning 8657.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `35d4a32..c6f6966` - the range changes 40 files, 5642 lines (5408 insertions, 234 deletions).
Verdict: ACCEPT - All wave 26c and 27 objectives are implemented correctly; all targeted prior findings are resolved; no blockers or major defects identified in the changes. Findings: none. Structured reply (prompt-only transport): `handoffs/31-codex-reply-byteplus.reply.json`.
WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).
Raw event stream: `handoffs/31-codex-reply-byteplus.events.jsonl`.
Verbatim reply follows.

---

# Wave 26c + 27 Acceptance Review

## Summary
Waves 26c and 27 are complete and ready for acceptance. All objectives are implemented correctly, all targeted prior findings are resolved, and no new blockers or major defects were identified.

## Targeted Prior Findings
All wave 26c and 27 findings are **fixed**:
- **F25-1**: Resolved: Stall timer resets on any byte growth, suspended during tool calls
- **F25-2**: Resolved: Kick checked after process exit; late kick recorded, outcome unchanged
- **F26-1**: Resolved: Kick acknowledgement implemented (.ack file), exit 0/1/3, waits 10s
- **F26-2**: Resolved: Health lock retries, tie break by stored `until`
- **F26-3**: Resolved: Stall timer on bytes, suspended during tool calls
- **F26-4**: Resolved: Empty/whitespace fields count as missing in legacy rating completion
- **F26-5**: Resolved: "panel size raised" warning implemented, size_source: required

## Wave 27 Features Implemented
1. **Host invariance (R13)**: One plugin for all hosts; `CODEX_CONSULT_COORDINATOR` identity; child environment scrubbed of host markers
2. **Coordinator identity**: Parsed, validated, recorded in ledger; warning when reviewer matches coordinator model
3. **Environment scrub**: `Hide-HostMarkers`/`Restore-HostMarkers` around every child start; scrubbed names recorded
4. **`-Explain`**: Read-only, only reads from plugin skills directory, no other parameters
5. **Parameter sets removed**: Positional binding preserved, `-Task` checked manually
6. **Coordinate skill**: Agent tier aliases, host-neutral wording, install instructions for all hosts

## Unproven Scenarios
- Concurrent `-Kick` calls from two processes at once
- Host marker restoration after an exception during child start
- Stall timer behavior with very large partial lines (>1MB)
- Coordinator identity matching with a provider label that matches a lab name

## First Run Checklist
Before trusting exit code 0 on the first real run, verify these observations:
1. `-Kick -Member 1` on a running member returns exit 0 and creates the `.ack` file
2. A tool call running for 1000s without intermediate output is not cut as stalled
3. `CODEX_CONSULT_COORDINATOR=openai :: gpt-6-astra` correctly identifies and warns when that reviewer is selected
4. A child process environment does not contain `CODEX_SESSION_ID` or `CLAUDE_CODE_SESSION_ID`
5. `-Explain coordinate` prints the coordinate skill text without reading outside the plugin directory

---

### Findings

_(none)_

### Prior findings

- F02-1 - not-checked - Not part of wave 26c/27
- F02-2 - not-checked - Not part of wave 26c/27
- F02-3 - not-checked - Not part of wave 26c/27
- F02-4 - not-checked - Not part of wave 26c/27
- F02-5 - not-checked - Not part of wave 26c/27
- F02-6 - not-checked - Not part of wave 26c/27
- F02-7 - not-checked - Not part of wave 26c/27
- F02-8 - not-checked - Not part of wave 26c/27
- F02-12 - not-checked - Not part of wave 26c/27
- F02-13 - not-checked - Not part of wave 26c/27
- F02-14 - not-checked - Not part of wave 26c/27
- F02-15 - not-checked - Not part of wave 26c/27
- F03-1 - not-checked - Not part of wave 26c/27
- F03-2 - not-checked - Not part of wave 26c/27
- F03-3 - not-checked - Not part of wave 26c/27
- F03-6 - not-checked - Not part of wave 26c/27
- F03-7 - not-checked - Not part of wave 26c/27
- F03-8 - not-checked - Not part of wave 26c/27
- F03-9 - not-checked - Not part of wave 26c/27
- F03-10 - not-checked - Not part of wave 26c/27
- F03-11 - not-checked - Not part of wave 26c/27
- F03-12 - not-checked - Not part of wave 26c/27
- F04-1 - not-checked - Not part of wave 26c/27
- F04-2 - not-checked - Not part of wave 26c/27
- F04-3 - not-checked - Not part of wave 26c/27
- F04-4 - not-checked - Not part of wave 26c/27
- F04-5 - not-checked - Not part of wave 26c/27
- F04-6 - not-checked - Not part of wave 26c/27
- F04-7 - not-checked - Not part of wave 26c/27
- F04-8 - not-checked - Not part of wave 26c/27
- F04-11 - not-checked - Not part of wave 26c/27
- F04-12 - not-checked - Not part of wave 26c/27
- F04-13 - not-checked - Not part of wave 26c/27
- F04-14 - not-checked - Not part of wave 26c/27
- F04-15 - not-checked - Not part of wave 26c/27
- F04-16 - not-checked - Not part of wave 26c/27
- F04-17 - not-checked - Not part of wave 26c/27
- F04-18 - not-checked - Not part of wave 26c/27
- F15-1 - not-checked - Not part of wave 26c/27
- F15-2 - not-checked - Not part of wave 26c/27
- F15-3 - not-checked - Not part of wave 26c/27
- F15-4 - not-checked - Not part of wave 26c/27
- F15-5 - not-checked - Not part of wave 26c/27
- F15-6 - not-checked - Not part of wave 26c/27
- F19-1 - not-checked - Not part of wave 26c/27
- F22-6 - not-checked - Not part of wave 26c/27
- F25-1 - fixed - Resolved: Stall timer resets on any byte growth, suspended during tool calls
- F25-2 - fixed - Resolved: Kick checked after process exit; late kick recorded, outcome unchanged
- F26-1 - fixed - Resolved: Kick acknowledgement implemented (.ack file), exit 0/1/3, waits 10s
- F26-2 - fixed - Resolved: Health lock retries, tie break by stored `until`
- F26-3 - fixed - Resolved: Stall timer on bytes, suspended during tool calls
- F26-4 - fixed - Resolved: Empty/whitespace fields count as missing in legacy rating completion
- F26-5 - fixed - Resolved: "panel size raised" warning implemented, size_source: required

## Verdict: ACCEPT

All wave 26c and 27 objectives are implemented correctly; all targeted prior findings are resolved; no blockers or major defects identified in the changes.

**WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).**

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- Concurrent `-Kick` calls from two processes at once
- Host marker restoration after an exception during child start
- Stall timer behavior with very large partial lines (>1MB)
- Coordinator identity matching with a provider label that matches a lab name

### First-run checklist (observable)

- [ ] `-Kick -Member 1` on a running member returns exit 0 and creates the `.ack` file
- [ ] A tool call running for 1000s without intermediate output is not cut as stalled
- [ ] `CODEX_CONSULT_COORDINATOR=openai :: gpt-6-astra` correctly identifies and warns when that reviewer is selected
- [ ] A child process environment does not contain `CODEX_SESSION_ID` or `CLAUDE_CODE_SESSION_ID`
- [ ] `-Explain coordinate` prints the coordinate skill text without reading outside the plugin directory
