# Handoff 54 - Codex: reply-mimo

Date: 2026-09-30 21:40 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 10, panel 393a81ca member 2 of 3; skipped openai :: gpt-6-astra (usage limit until 2026-10-01T01:51:00+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: a830d2df-2bd5-48d8-90f5-25170c423e8c.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-134be11f84244efca64d9c402cf2b5fc.md fork 01a0f291-ac87-78e2-85cb-efd65a13016e -` (prompt on stdin).
Parent thread: `01a0f291-ac87-78e2-85cb-efd65a13016e`. Result thread: `01a0f3d5-3fcb-71c1-ba6a-0bd8845b9f69` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/52-claude-wave28d-acceptance.md` (sha256 0dba6c7a68b4). Reviewed: acdc218, base acdc218ee800cf9f3b830eeb2aa05406e2e9f62a, tree sha256 1f5563cf4a6b, 0 changed files.
Bridge outcome: usable reply. Wall time: 675.7 s. Tokens: in 69971710 (cached 49608960), out 243466, reasoning 142539.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `fc6978a..d65e2e9` - the range changes 25 files, 10561 lines (10191 insertions, 370 deletions).
Verdict: HOLD - Wave 28d fixes most prior defects but leaves unverified kill pids out of recovery and can lose not-spooled counts under concurrent appends. Findings: 0 blocker, 2 major, 2 minor, 0 note (F54-1..F54-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/54-codex-reply-mimo.reply.json`.
Raw event stream: `handoffs/54-codex-reply-mimo.events.jsonl`.
Verbatim reply follows.

---

## 1. Prior findings

F48-1 and F49-3 are fixed: Remove-TelemetrySpoolLines writes `<spool>.tmp`, flushes it and replaces the spool with one move (common.ps1:10227-10270), with a crash hook and stale-tmp cleanup. F48-2 is fixed: the marker records pid/start/since, is removed in `finally`, and Resolve-TelemetryForgetting removes a dead owner's marker (common.ps1:9449-9475). F48-3 is fixed: the flush lock is created with its owner record; an ownerless lock is held 30 s, a living owner is never taken over, and a 30-minute stuck line is recorded (common.ps1:10312-10380). F48-4 is fixed: no prompt hash exists and the re-read line is subtracted from the fork/resume estimate (codex-consult.ps1:4071-4075). F49-2 is fixed: the not-spooled file is append-only and written without the telemetry lock (common.ps1:9977-9995). F49-4 is an accepted limitation: a living owner is never taken over; the stuck-sender remedy is now documented. F50-1 is fixed: Get-TelemetryModelToken lower-cases both sides (common.ps1:9662-9668). F50-2 is fixed: an inline `-Prompt` with `context_tokens` gets a repeated, folded ask line (codex-consult.ps1:4039-4046).

F49-1 remains open in part: D5 names unverified descendants in the warning and outcome text (codex-consult.ps1:1749, 1760-1772, 1862), but the recovery record is explicitly unchanged and still stores only confirmed survivors (codex-consult.ps1:1865-1866, 4551-4555).

## 2. New defects

**#1 (major) - unverified descendants remain invisible to recovery.** After a kill with survivors, the pending record's `survivors` list is built only from alive pids; an unreadable-start pid is named on the console but absent from the recovery record, so the next run cannot know to check it. Trigger: one survivor plus one unreadable descendant. Supersedes F49-1.

**#2 (major) - the lock-free not-spooled counter can still lose counts.** Add-TelemetryNotSpooled uses `[IO.File]::AppendAllText` with retries but no mutual exclusion; under sustained contention on Windows PowerShell 5.1 it gives up after 5 s and returns silently (common.ps1:9977-9985), losing exactly the drop it is meant to count. Supersedes F49-2's residual.

**#3 (minor) - marker owner identity can collide.** Get-TelemetryForgettingOwner trusts pid plus a start-time string (common.ps1:9449-9462). A recycled pid with the same start-time resolution reads as a living owner, so a dead -Forget marker can block producers indefinitely.

**#4 (minor) - the inline re-read anchor folds multi-line prompts.** ConvertTo-OneLine collapses a multi-line `-Prompt` and truncates at 500 characters (codex-consult.ps1:4041-4044), so distinct numbered asks can become an ambiguous one-line anchor.

## 3. Verdict

**HOLD.** Fix #1 and #2 before acceptance; #3 and #4 are minor hardening. The atomic rewrite, marker healing, lock ownership, model case-folding and inline re-read are otherwise implemented as claimed.

## Requested checks

- RC1 (workspace-write, 5 min): fake a kill with one survivor and one unreadable descendant; inspect the pending record's survivors (#1).
- RC2 (workspace-write, 5 min): hold the telemetry lock and force two concurrent failed commits; compare `-Status` counts with the warnings (#2).
- RC3 (workspace-write, 5 min): kill -Forget, recycle its pid with the same start-time value, then commit (#3).
- RC4 (read-only, 2 min): run a multi-line `-Prompt` context member and inspect the folded re-read line (#4).

---

### Findings

- **F54-1** [major] `plugins/codex-consult/scripts/codex-consult.ps1:1865` - A kill with survivors and an unreadable-start descendant names the unverified pid only on the console; the recovery record's survivors list still contains only confirmed alive pids, so the next run cannot check the unverified process. Trigger: A timeout kill leaves one confirmed survivor and one descendant whose start time cannot be read. Evidence: read-code: Warning and outcome include Unverified; pendingRecord.survivors is built from $surv alone. Verify: Fake the mixed kill and inspect the pending record. Remedy: Add unverified pids (with their reason) to the recovery record and require the next run to check them. Supersedes: F49-1.
- **F54-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9977` - Add-TelemetryNotSpooled appends without a lock and silently stops retrying after 5 s, so concurrent producers can lose not-spooled counts despite the append-only design. Trigger: Two failed commits append while another writer holds the file on Windows PowerShell 5.1. Evidence: read-code: AppendAllText is retried 100 times then the function returns with no error. Verify: Hold the file open and force concurrent failed commits; compare -Status with console warnings. Remedy: Serialize appends with a named mutex or an exclusive append lock and surface a warning when the count cannot be written. Supersedes: F49-2.
- **F54-3** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:9449` - Forgetting-marker liveness uses pid plus a start-time string; a recycled pid with identical start-time resolution is treated as a living owner and can block telemetry indefinitely. Trigger: -Forget is killed and its pid is reused with the same recorded start time. Evidence: read-code: Get-TelemetryForgettingOwner delegates liveness to Test-PidAlive with the stored start time. Verify: Recycle the pid with the same start-time value and attempt a commit. Remedy: Include a creation nonce or finer-resolution process identity in the marker.
- **F54-4** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:4041` - The inline re-read anchor folds a multi-line -Prompt to one whitespace-collapsed, possibly truncated line, which can make distinct asks indistinguishable. Trigger: A context_tokens member runs with a multi-line prompt longer than 500 characters. Evidence: read-code: ConvertTo-OneLine then Substring(0,500) builds the repeated anchor. Verify: Inspect the final prompt for a multi-line prompt. Remedy: Hash or excerpt each line, or point to stable offsets instead of one folded line.

### Prior findings

- F02-1 - not-checked - Outside wave 28d scope.
- F02-2 - not-checked - Outside wave 28d scope.
- F02-3 - not-checked - Outside wave 28d scope.
- F02-4 - not-checked - Outside wave 28d scope.
- F02-5 - not-checked - Outside wave 28d scope.
- F02-6 - not-checked - Outside wave 28d scope.
- F02-7 - not-checked - Outside wave 28d scope.
- F02-8 - not-checked - Outside wave 28d scope.
- F02-12 - not-checked - Outside wave 28d scope.
- F02-13 - not-checked - Outside wave 28d scope.
- F02-14 - not-checked - Outside wave 28d scope.
- F02-15 - not-checked - Outside wave 28d scope.
- F03-1 - not-checked - Outside wave 28d scope.
- F03-2 - not-checked - Outside wave 28d scope.
- F03-3 - not-checked - Outside wave 28d scope.
- F03-6 - not-checked - Outside wave 28d scope.
- F03-7 - not-checked - Outside wave 28d scope.
- F03-8 - not-checked - Outside wave 28d scope.
- F03-9 - not-checked - Outside wave 28d scope.
- F03-10 - not-checked - Outside wave 28d scope.
- F03-11 - not-checked - Outside wave 28d scope.
- F03-12 - not-checked - Outside wave 28d scope.
- F04-1 - not-checked - Outside wave 28d scope.
- F04-2 - not-checked - Outside wave 28d scope.
- F04-3 - not-checked - Outside wave 28d scope.
- F04-4 - not-checked - Outside wave 28d scope.
- F04-5 - not-checked - Outside wave 28d scope.
- F04-6 - not-checked - Outside wave 28d scope.
- F04-7 - not-checked - Outside wave 28d scope.
- F04-8 - not-checked - Outside wave 28d scope.
- F04-11 - not-checked - Outside wave 28d scope.
- F04-12 - not-checked - Outside wave 28d scope.
- F04-13 - not-checked - Outside wave 28d scope.
- F04-14 - not-checked - Outside wave 28d scope.
- F04-15 - not-checked - Outside wave 28d scope.
- F04-16 - not-checked - Outside wave 28d scope.
- F04-17 - not-checked - Outside wave 28d scope.
- F04-18 - not-checked - Outside wave 28d scope.
- F15-1 - not-checked - Outside wave 28d scope.
- F15-2 - not-checked - Outside wave 28d scope.
- F15-3 - not-checked - Outside wave 28d scope.
- F15-4 - not-checked - Outside wave 28d scope.
- F15-5 - not-checked - Outside wave 28d scope.
- F15-6 - not-checked - Outside wave 28d scope.
- F19-1 - not-checked - Outside wave 28d scope.
- F22-6 - not-checked - Outside wave 28d scope.
- F48-1 - fixed - Atomic tmp-and-replace rewrite.
- F48-2 - fixed - Marker owner record and self-healing.
- F48-3 - fixed - Owner-bearing lock and 30 s ownerless rule.
- F48-4 - fixed - No prompt hash; estimate excludes the line.
- F49-1 - still-open - Unverified pids omitted from the recovery record (finding #1).
- F49-2 - fixed - Append-only counter without the lock; contention residual is finding #2.
- F49-3 - fixed - Atomic rewrite.
- F49-4 - fixed - Accepted limitation: living owner never taken over; remedy documented.
- F50-1 - fixed - Both model sides lower-cased.
- F50-2 - fixed - Inline ask repeated for context members.

## Verdict: HOLD

Wave 28d fixes most prior defects but leaves unverified kill pids out of recovery and can lose not-spooled counts under concurrent appends.

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- Atomic replace behavior when native move is unavailable.
- PID/start-time collision probability on each OS.
- Windows PowerShell 5.1 concurrent AppendAllText semantics.
- Stuck-sender behavior with a hung but living owner.

### First-run checklist (observable)

- [ ] Rewrite crash hook leaves either the old or new spool file and no truncated file.
- [ ] A dead owner's forgetting marker is removed with a .last note; a living owner's marker blocks and is named.
- [ ] Young ownerless flush locks are held 30 s; older ones are removed with TookOver noted.
- [ ] A living lock older than 30 minutes prints sender stuck and a .last note.
- [ ] not_spooled_seen and the append-only counter reconcile with console warnings under contention.
- [ ] Mixed survivor/unverified kills name both groups AND persist unverified pids in the pending record.
- [ ] Model names differing only in case resolve to the same token.
- [ ] context_tokens inline prompts end with the folded re-read ask before the consultation id.
