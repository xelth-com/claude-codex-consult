# Handoff 10 - Codex: wave24-accept-byteplus

Date: 2026-09-26 17:11 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave23-accept.json - position 7 of 10, panel 40ea8da3 member 4 of 7; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: afed25fb-58d4-48da-9c1c-4c885a91f397.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-af00685ce3524b6bb5369a716dc6fdcf.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage byteplus :: dola-seed-2.0-pro in this task's ledger; other lineage(s): alibaba :: qwen3.8-max, kimi :: k3, mimo :: mimo-v2.6-pro). Result thread: `01a0de45-e533-7f33-bd2b-aaf70f7fecd0` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/06-claude-wave24-acceptance.md` (sha256 e7c48ed71df5). Reviewed: 75cfd47, base 75cfd479f82a76fe01f4b94356af7967add0bb3a, tree sha256 2e28b2f55572, 0 changed files.
Bridge outcome: usable reply. Wall time: 767.1 s. Tokens: in 1943771 (cached 1486376), out 11013, reasoning 6430.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s.
Verdict: ACCEPT - All wave 24 objectives are implemented correctly; all targeted prior findings are resolved; no blockers or major defects identified in the changes. Findings: none. Structured reply (prompt-only transport): `handoffs/10-codex-wave24-accept-byteplus.reply.json`.
WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).
Raw event stream: `handoffs/10-codex-wave24-accept-byteplus.events.jsonl`.
Verbatim reply follows.

---

# Wave 24 Acceptance Review

## Summary
Wave 24 is complete and ready for acceptance. All objectives are implemented correctly, all targeted prior findings are resolved, and no new blockers or major defects were identified.

## Targeted Prior Findings (Wave 24)
All wave 24 findings are **fixed**:
- **F02-9**: Quota failures without known reset are now consistently marked as out for 60 minutes across all surfaces (roster walk, codex-providers, hook).
- **F02-10**: The hook now uses `codex-providers.ps1 -Short -Json` which returns per-roster-entry records; multi-model provider entries are no longer lost.
- **F02-11**: Endpoint group availability is now computed over ALL roster entries; outages propagate correctly across all entries sharing an endpoint.
- **F03-4**: The hook no longer uses regex parsing of provider text output; it reads structured JSON directly, avoiding truncation issues.
- **F03-5**: `codex-providers` now uses the same `Get-PreflightVerdict -RosterWalk` logic as the panel selection, so it correctly shows unknown-reset quota failures as out for 60 minutes.
- **F04-9**: `Select-PanelMembers` now supports `-NoNetwork`, and `Get-RosterAvailability` uses it to walk every entry (not just stop at the first available) without network calls.
- **F04-10**: `Format-AvailabilityLine` correctly counts `available`, `out`, and `not checked` entries; the hook uses the full untruncated line from JSON output.

## Wave 24 Features Implemented
1. **Timeout continuation**: One additional turn on the same thread after a timeout kill, with a finish-now prompt and configurable `-ContinueSec` (default `min(timeout, 900)`). Skipped correctly if processes survived, tree changed, or quota/auth failure occurred.
2. **Partial salvage**: Killed turns write `<NN>-<engine>-<slug>.partial.md` with captured agent messages, reasoning, and tool calls; exact resume command provided.
3. **Per-purpose default timeouts**: chore 600s, checkpoint 900s, framing/decision 1800s, diff-review/core-contract/stuck 2400s, acceptance 3600s.
4. **`-Range <git range>`**: For diff-review/acceptance, runs `git diff --shortstat` once, includes line count in prompt/ledger, warns when >1500 lines with timeout <2400s.
5. **F15-1**: Muse billing guard re-reads `auth.json` immediately before every launch via `-Fresh` flag.
6. **One truth about availability**: All surfaces use the same verdict logic; endpoint groups are computed over all roster entries; 60-minute rule for unknown-reset quotas; hook uses structured JSON output.

## Unproven Scenarios
- Edge case: Timeout continuation when the thread ID is present but the external engine has already expired the session
- Edge case: Partial salvage for very large event streams (>10MB)
- Behavior when a continuation turn itself times out

## First Run Checklist
Before trusting exit code 0 on the first real run, verify these observations:
1. A timeout-killed agy run correctly continues the existing conversation and delivers a usable reply
2. `codex-providers.ps1 -Short` correctly shows a multi-model provider as `gemini :: *` when one entry is out
3. A quota failure without Retry-After is shown as out for exactly 60 minutes in both `codex-providers` and the panel selection
4. `-Range HEAD~1` correctly prints the line count in the prompt header and ledger
5. The muse launch guard correctly detects a change to `auth.json` made after the preflight check

---

### Findings

_(none)_

### Prior findings

- F02-1 - not-checked - Not part of wave 24
- F02-2 - not-checked - Not part of wave 24
- F02-3 - not-checked - Not part of wave 24
- F02-4 - not-checked - Not part of wave 24
- F02-5 - not-checked - Not part of wave 24
- F02-6 - not-checked - Not part of wave 24
- F02-7 - not-checked - Not part of wave 24
- F02-8 - not-checked - Not part of wave 24
- F02-9 - fixed - Resolved: 60-minute rule applied consistently across all surfaces
- F02-10 - fixed - Resolved: Hook uses per-entry JSON output; multi-model entries no longer lost
- F02-11 - fixed - Resolved: Endpoint groups computed over all roster entries; outages propagate correctly
- F02-12 - not-checked - Not part of wave 24
- F02-13 - not-checked - Not part of wave 24
- F02-14 - not-checked - Not part of wave 24
- F02-15 - not-checked - Not part of wave 24
- F03-1 - not-checked - Not part of wave 24
- F03-2 - not-checked - Not part of wave 24
- F03-3 - not-checked - Not part of wave 24
- F03-4 - fixed - Resolved: Hook uses structured JSON output, no regex parsing
- F03-5 - fixed - Resolved: codex-providers uses same verdict logic as roster walk
- F03-6 - not-checked - Not part of wave 24
- F03-7 - not-checked - Not part of wave 24
- F03-8 - not-checked - Not part of wave 24
- F03-9 - not-checked - Not part of wave 24
- F03-10 - not-checked - Not part of wave 24
- F03-11 - not-checked - Not part of wave 24
- F03-12 - not-checked - Not part of wave 24
- F04-1 - not-checked - Not part of wave 24
- F04-2 - not-checked - Not part of wave 24
- F04-3 - not-checked - Not part of wave 24
- F04-4 - not-checked - Not part of wave 24
- F04-5 - not-checked - Not part of wave 24
- F04-6 - not-checked - Not part of wave 24
- F04-7 - not-checked - Not part of wave 24
- F04-8 - not-checked - Not part of wave 24
- F04-9 - fixed - Resolved: Select-PanelMembers now has -NoNetwork; Get-RosterAvailability walks all entries
- F04-10 - fixed - Resolved: Format-AvailabilityLine correctly counts all states; hook uses full untruncated line
- F04-11 - not-checked - Not part of wave 24
- F04-12 - not-checked - Not part of wave 24
- F04-13 - not-checked - Not part of wave 24
- F04-14 - not-checked - Not part of wave 24
- F04-15 - not-checked - Not part of wave 24
- F04-16 - not-checked - Not part of wave 24
- F04-17 - not-checked - Not part of wave 24
- F04-18 - not-checked - Not part of wave 24

## Verdict: ACCEPT

All wave 24 objectives are implemented correctly; all targeted prior findings are resolved; no blockers or major defects identified in the changes.

**WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).**

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- Timeout continuation when external engine session has expired
- Partial salvage for very large event streams (>10MB)
- Behavior when a continuation turn itself times out

### First-run checklist (observable)

- [ ] A timeout-killed agy run correctly continues the existing conversation and delivers a usable reply
- [ ] codex-providers.ps1 -Short correctly shows a multi-model provider as '<label> :: *' when one entry is out
- [ ] A quota failure without Retry-After is shown as out for exactly 60 minutes in both codex-providers and panel selection
- [ ] -Range HEAD~1 correctly prints the line count in the prompt header and ledger
- [ ] Muse launch guard correctly detects a change to auth.json made after the preflight check
