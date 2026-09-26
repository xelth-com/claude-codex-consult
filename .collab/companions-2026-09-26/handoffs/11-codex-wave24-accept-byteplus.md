# Handoff 11 - Codex: wave24-accept-byteplus

Date: 2026-09-26 17:11 local. Author: Codex (model kimi-k2.5, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: kimi-k2.5 (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave23-accept.json - position 8 of 10, panel 40ea8da3 member 5 of 7; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, kimi-k2.5; not confirmed by the provider). Consultation id: d2be1e86-59db-48c3-bf8b-5a20d9ae6bfb.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m kimi-k2.5 -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-922f619c8a594380b641f1d76dc4e088.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage byteplus :: kimi-k2.5 in this task's ledger; other lineage(s): alibaba :: qwen3.8-max, kimi :: k3, mimo :: mimo-v2.6-pro). Result thread: `01a0de45-e3d7-7b00-b34a-274edf3d5730` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/06-claude-wave24-acceptance.md` (sha256 e7c48ed71df5). Reviewed: 75cfd47, base 75cfd479f82a76fe01f4b94356af7967add0bb3a, tree sha256 2e28b2f55572, 0 changed files.
Bridge outcome: usable reply. Wall time: 438.5 s. Tokens: in 714028 (cached 380296), out 8195, reasoning 2071.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s.
Verdict: ACCEPT - All wave 24 requirements are implemented correctly; no blocker or major defects found in the diff review. Findings: none. Structured reply (prompt-only transport): `handoffs/11-codex-wave24-accept-byteplus.reply.json`.
WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).
Raw event stream: `handoffs/11-codex-wave24-accept-byteplus.events.jsonl`.
Verbatim reply follows.

---

# Wave 24 Acceptance Review (commit 65f5649)

## Summary
All wave 24 changes are implemented correctly and match the design brief. No blocker or major defects were found in this diff review.

## Addressed Wave 24 Findings
| ID | Status | Note |
|----|--------|------|
| F02-9 | Fixed | Quota without known reset is now consistently marked out for 60 minutes across all surfaces (roster walk, providers listing, hook) |
| F02-10 | Fixed | codex-providers now walks every roster entry, not just provider labels; hook correctly displays per-entry availability |
| F02-11 | Fixed | Endpoint groups are computed over all roster entries; outages propagate across shared credentials/quota even for unselected entries |
| F03-4 | Fixed | Hook no longer uses regex parsing; reads full availability line directly from codex-providers -Short -Json output |
| F03-5 | Fixed | codex-providers now uses the same roster walk verdict logic; 60 minute rule applies uniformly everywhere |
| F04-9 | Fixed | Select-PanelMembers has -NoNetwork parameter; used by codex-providers and hook to get per-entry verdicts without network calls |
| F04-10 | Fixed | Availability line no longer truncates reasons; correctly counts all three states (available/out/not checked) |

## Verified Implementations
1. **Timeout continuation**: One continuation turn after timeout kill, same thread, finish-now prompt, -ContinueSec min(timeout, 900), usable reply ingested normally
2. **Partial salvage**: Writes `NN-<engine>-<slug>.partial.md` with event stream, tool calls, and exact resume command
3. **Per-purpose timeouts**: Correct defaults (chore 600, checkpoint 900, framing 1800, diff-review 2400, acceptance 3600); -TimeoutSec overrides
4. **-Range support**: Git diff --shortstat, size warning >1500 lines with timeout <2400s, unknown range refused before start
5. **F15-1**: Muse billing guard re-reads auth.json right before launch with -Fresh flag
6. **Availability one truth**: All surfaces use same verdict logic; 60 minute rule for unknown resets; health source displayed; endpoint grouping works correctly

## First Run Checklist
- Observe `timeout_continue` ledger record after a timeout kill
- Verify partial reply file is created when continuation fails or is disabled
- Confirm per-purpose timeouts are correctly inherited by panel members
- Check that -Range warning appears for large diffs with short timeouts
- Validate hook availability line correctly groups endpoint outages and shows reset times

---

### Findings

_(none)_

### Prior findings

- F02-1 - not-checked - Companions wave, not implemented in wave 24
- F02-2 - not-checked - Companions wave, not implemented in wave 24
- F02-3 - not-checked - Companions wave, not implemented in wave 24
- F02-4 - not-checked - Companions wave, not implemented in wave 24
- F02-5 - not-checked - Companions wave, not implemented in wave 24
- F02-6 - not-checked - Companions wave, not implemented in wave 24
- F02-7 - not-checked - Companions wave, not implemented in wave 24
- F02-8 - not-checked - Companions wave, not implemented in wave 24
- F02-9 - fixed - Quota without reset is now 60 minutes out consistently across all surfaces
- F02-10 - fixed - codex-providers now walks all roster entries, hook uses this output
- F02-11 - fixed - Endpoint groups computed over all entries; outages propagate across shared credentials
- F02-12 - not-checked - Companions wave, not implemented in wave 24
- F02-13 - not-checked - Companions wave, not implemented in wave 24
- F02-14 - not-checked - Companions wave, not implemented in wave 24
- F02-15 - not-checked - Companions wave, not implemented in wave 24
- F03-1 - not-checked - Companions wave, not implemented in wave 24
- F03-2 - not-checked - Companions wave, not implemented in wave 24
- F03-3 - not-checked - Companions wave, not implemented in wave 24
- F03-4 - fixed - Hook no longer uses regex parsing, reads line directly from JSON output
- F03-5 - fixed - codex-providers now uses roster walk logic, 60 minute rule applies everywhere
- F03-6 - not-checked - Companions wave, not implemented in wave 24
- F03-7 - not-checked - Companions wave, not implemented in wave 24
- F03-8 - not-checked - Companions wave, not implemented in wave 24
- F03-9 - not-checked - Companions wave, not implemented in wave 24
- F03-10 - not-checked - Companions wave, not implemented in wave 24
- F03-11 - not-checked - Companions wave, not implemented in wave 24
- F03-12 - not-checked - Companions wave, not implemented in wave 24
- F04-1 - not-checked - Companions wave, not implemented in wave 24
- F04-2 - not-checked - Companions wave, not implemented in wave 24
- F04-3 - not-checked - Companions wave, not implemented in wave 24
- F04-4 - not-checked - Companions wave, not implemented in wave 24
- F04-5 - not-checked - Companions wave, not implemented in wave 24
- F04-6 - not-checked - Companions wave, not implemented in wave 24
- F04-7 - not-checked - Companions wave, not implemented in wave 24
- F04-8 - not-checked - Companions wave, not implemented in wave 24
- F04-9 - fixed - Select-PanelMembers has -NoNetwork, used by providers and hook for per-entry verdicts
- F04-10 - fixed - Availability line no longer truncates, correctly counts all three states
- F04-11 - not-checked - Companions wave, not implemented in wave 24
- F04-12 - not-checked - Companions wave, not implemented in wave 24
- F04-13 - not-checked - Companions wave, not implemented in wave 24
- F04-14 - not-checked - Companions wave, not implemented in wave 24
- F04-15 - not-checked - Companions wave, not implemented in wave 24
- F04-16 - not-checked - Companions wave, not implemented in wave 24
- F04-17 - not-checked - Companions wave, not implemented in wave 24
- F04-18 - not-checked - Companions wave, not implemented in wave 24

## Verdict: ACCEPT

All wave 24 requirements are implemented correctly; no blocker or major defects found in the diff review.

**WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).**

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

_(none)_

### First-run checklist (observable)

- [ ] Observe timeout_continue ledger record after a timeout kill
- [ ] Verify partial reply file is created when continuation fails or is disabled
- [ ] Confirm per-purpose timeouts are correctly inherited by panel members
- [ ] Check that -Range warning appears for large diffs with short timeouts
- [ ] Validate hook availability line correctly groups endpoint outages and shows reset times
