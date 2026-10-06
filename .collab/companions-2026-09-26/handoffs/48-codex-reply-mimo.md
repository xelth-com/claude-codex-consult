# Handoff 48 - Codex: reply-mimo

Date: 2026-09-30 15:47 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 10, panel 2087691d member 2 of 4.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 1ca72e5c-aa2c-438d-862c-1402363c05f0.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8eab23a80e6047cdb6533f763ba10bed.md fork 01a0f13d-5245-7320-b62a-0f5b3df4bdad -` (prompt on stdin).
Parent thread: `01a0f13d-5245-7320-b62a-0f5b3df4bdad`. Result thread: `01a0f291-ac87-78e2-85cb-efd65a13016e` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/46-claude-wave28c-acceptance.md` (sha256 eba6cda05101). Reviewed: 9657cf9, base 9657cf9d6b3f00c985379f52bece5f81606fefc0, tree sha256 9f073e0b355d, 0 changed files.
Bridge outcome: usable reply. Wall time: 1116.5 s. Tokens: in 68298298 (cached 48675072), out 224055, reasoning 130965.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `e5c6992..fc6978a` - the range changes 50 files, 15019 lines (14623 insertions, 396 deletions).
Verdict: HOLD - Wave 28c fixes prior findings but leaves crash-unsafe spool rewriting, a wedging forgetting marker and ownerless flush-lock takeover. Findings: 0 blocker, 3 major, 1 minor, 0 note (F48-1..F48-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/48-codex-reply-mimo.reply.json`.
Raw event stream: `handoffs/48-codex-reply-mimo.events.jsonl`.
Verbatim reply follows.

---

## 1. Prior findings

Wave 28c fixes the listed wave-28b defects. F41-1 is fixed (proxy variables are in the sender allow list). F42-1..F42-9 are fixed by the exact-match closed model list, confirmed-DELETE ordering, telemetry lock/forgetting marker, unconfirmed treatment of unreadable descendant start times, pgrep fall-through to ps//proc, journal quarantine to .bad, owner-checked token-fenced lock takeover, a deadline covering local spool work, and Unix trust variables in the sender allow list. F43-1..F43-5 and F43-7 are fixed by the same changes and the corrected CHANGELOG counts. F43-6 is an accepted limitation and the README documents host-name-derived vendor classification and the private-gateway caveat. F44-1, F44-2, F44-4, F44-5 and F44-6 are fixed; F44-3 is an accepted limitation documented in that README paragraph. F35-1, F36-3..F36-11, F37-1 and F37-4..F37-6 are fixed; F36-1, F36-2, F37-2 and F37-3 remain open but are outside this wave. Older F02/F03/F04/F15/F19/F22 items are not re-checked here.

## 2. New defects in this wave

**#1 (major) - crash-unsafe spool rewrite.** Remove-TelemetrySpoolLines truncates with SetLength(0) and rewrites retained lines in place (common.ps1:9700 area); a kill or power loss between the two loses every queued event. Remedy: temp file plus atomic rename.

**#2 (major) - forgetting marker wedges telemetry.** Invoke-TelemetryForget writes telemetry-forgetting first and deletes it last (common.ps1:10188-10200). A crash leaves the marker forever; producers then drop events indefinitely with no owner-based recovery. Remedy: owner pid/start in the marker and self-heal or expiry.

**#3 (major) - ownerless flush lock is stealable.** Enter-TelemetryFlushLock treats a lock with no parseable owner as stale immediately (common.ps1:9854-9894). A sender whose CreateNew succeeded but whose identity write failed can be overtaken, allowing concurrent flushes. Remedy: create the lock with owner metadata atomically or impose a grace period.

**#4 (minor) - prompt hash changes.** The brief re-read line appended for context_tokens members (codex-consult.ps1:3927) changes the prompt hash and can fork thread reuse. Remedy: exclude the line from the hash or version the template.

## 3. Verdict

**HOLD.** Acceptance requires crash-safe spool rewriting, owner-scoped forgetting-marker recovery, and safe ownerless lock handling; #4 is minor.

## Requested checks

- RC1 (workspace-write, 5 min): fault-inject after SetLength(0) in Remove-TelemetrySpoolLines; inspect the spool (#1).
- RC2 (workspace-write, 5 min): kill -Forget after the marker write, then commit; confirm unbounded drops (#2).
- RC3 (workspace-write, 5 min): create an ownerless flush lock and race two senders (#3).
- RC4 (read-only, 2 min): hash prompts with and without the brief line (#4).

---

### Findings

- **F48-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9700` - Remove-TelemetrySpoolLines rewrites the spool in place with SetLength(0) followed by a non-atomic write, so a crash mid-rewrite loses every queued line. Trigger: The sender is killed or power is lost between truncation and rewrite. Evidence: read-code: The function truncates and then writes retained lines to the same stream. Verify: Fault-inject after SetLength(0) and inspect the spool. Remedy: Write retained lines to a temp file and atomically rename it over the spool.
- **F48-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:10188` - A forgetting marker written by -Forget is deleted only at the end, so a crash leaves it permanently blocking telemetry producers. Trigger: Invoke-TelemetryForget is killed after writing telemetry-forgetting. Evidence: read-code: The marker is written first and removed last; producers refuse while it exists. Verify: Leave the marker and run a fake commit. Remedy: Store owner pid/start in the marker and self-heal or expire it.
- **F48-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9854` - Enter-TelemetryFlushLock immediately takes over an ownerless lock, allowing concurrent flushes when a sender's identity write fails. Trigger: CreateNew succeeds but the owner write fails. Evidence: read-code: Ownerless locks are classified stale without a grace period. Verify: Create an empty lock and race two flushes. Remedy: Create the lock with owner metadata atomically or refuse ownerless locks briefly.
- **F48-4** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:3927` - The brief re-read line appended for context_tokens members changes the prompt hash and can fork thread reuse. Trigger: Resuming a thread created before wave 28c. Evidence: inferred: The line is appended before hash consumers. Verify: Compare prompt hashes with and without the line. Remedy: Exclude the line from the hash or version the template.

### Prior findings

- F02-1 - not-checked - Outside wave 28c scope.
- F02-2 - not-checked - Outside wave 28c scope.
- F02-3 - not-checked - Outside wave 28c scope.
- F02-4 - not-checked - Outside wave 28c scope.
- F02-5 - not-checked - Outside wave 28c scope.
- F02-6 - not-checked - Outside wave 28c scope.
- F02-7 - not-checked - Outside wave 28c scope.
- F02-8 - not-checked - Outside wave 28c scope.
- F02-12 - not-checked - Outside wave 28c scope.
- F02-13 - not-checked - Outside wave 28c scope.
- F02-14 - not-checked - Outside wave 28c scope.
- F02-15 - not-checked - Outside wave 28c scope.
- F03-1 - not-checked - Outside wave 28c scope.
- F03-2 - not-checked - Outside wave 28c scope.
- F03-3 - not-checked - Outside wave 28c scope.
- F03-6 - not-checked - Outside wave 28c scope.
- F03-7 - not-checked - Outside wave 28c scope.
- F03-8 - not-checked - Outside wave 28c scope.
- F03-9 - not-checked - Outside wave 28c scope.
- F03-10 - not-checked - Outside wave 28c scope.
- F03-11 - not-checked - Outside wave 28c scope.
- F03-12 - not-checked - Outside wave 28c scope.
- F04-1 - not-checked - Outside wave 28c scope.
- F04-2 - not-checked - Outside wave 28c scope.
- F04-3 - not-checked - Outside wave 28c scope.
- F04-4 - not-checked - Outside wave 28c scope.
- F04-5 - not-checked - Outside wave 28c scope.
- F04-6 - not-checked - Outside wave 28c scope.
- F04-7 - not-checked - Outside wave 28c scope.
- F04-8 - not-checked - Outside wave 28c scope.
- F04-11 - not-checked - Outside wave 28c scope.
- F04-12 - not-checked - Outside wave 28c scope.
- F04-13 - not-checked - Outside wave 28c scope.
- F04-14 - not-checked - Outside wave 28c scope.
- F04-15 - not-checked - Outside wave 28c scope.
- F04-16 - not-checked - Outside wave 28c scope.
- F04-17 - not-checked - Outside wave 28c scope.
- F04-18 - not-checked - Outside wave 28c scope.
- F15-1 - not-checked - Outside wave 28c scope.
- F15-2 - not-checked - Outside wave 28c scope.
- F15-3 - not-checked - Outside wave 28c scope.
- F15-4 - not-checked - Outside wave 28c scope.
- F15-5 - not-checked - Outside wave 28c scope.
- F15-6 - not-checked - Outside wave 28c scope.
- F19-1 - not-checked - Outside wave 28c scope.
- F22-6 - not-checked - Outside wave 28c scope.
- F35-1 - fixed - Implemented in wave 28b.
- F36-1 - still-open - Open from wave 28b; out of scope here.
- F36-2 - still-open - Open from wave 28b; out of scope here.
- F36-3 - fixed - Implemented in wave 28b.
- F36-4 - fixed - Implemented in wave 28b.
- F36-5 - fixed - Implemented in wave 28b.
- F36-6 - fixed - Implemented in wave 28b.
- F36-7 - fixed - Implemented in wave 28b.
- F36-8 - fixed - Implemented in wave 28b.
- F36-9 - fixed - Implemented in wave 28b.
- F36-10 - fixed - Implemented in wave 28b.
- F36-11 - fixed - Implemented in wave 28b.
- F37-1 - fixed - Implemented in wave 28b.
- F37-2 - still-open - Open from wave 28b; out of scope here.
- F37-3 - still-open - Open from wave 28b; out of scope here.
- F37-4 - fixed - Implemented in wave 28b.
- F37-5 - fixed - Implemented in wave 28b.
- F37-6 - fixed - Implemented in wave 28b.
- F41-1 - fixed - Proxy variables are allow-listed.
- F42-1 - fixed - Exact-match closed model list.
- F42-2 - fixed - Confirmed-DELETE ordering.
- F42-3 - fixed - Telemetry lock and forgetting marker.
- F42-4 - fixed - Unreadable start times are unconfirmed.
- F42-5 - fixed - pgrep failures fall through.
- F42-6 - fixed - Journal .bad quarantine.
- F42-7 - fixed - Owner-checked token-fenced lock.
- F42-8 - fixed - Deadline covers local steps.
- F42-9 - fixed - Unix trust variables allow-listed.
- F43-1 - fixed - Confirmed-DELETE ordering.
- F43-2 - fixed - Closed model vocabulary.
- F43-3 - fixed - Compactions unknown plus brief line.
- F43-4 - fixed - One-second append and retry.
- F43-5 - fixed - Owner-only lock takeover.
- F43-6 - fixed - Accepted limitation; README documents it.
- F43-7 - fixed - CHANGELOG corrected.
- F44-1 - fixed - Journal .bad quarantine.
- F44-2 - fixed - Owner-only lock takeover.
- F44-3 - fixed - Accepted limitation; README documents it.
- F44-4 - fixed - Intake reminder implemented.
- F44-5 - fixed - Test-mode line on dry runs.
- F44-6 - fixed - Compaction detection and brief line.

## Verdict: HOLD

Wave 28c fixes prior findings but leaves crash-unsafe spool rewriting, a wedging forgetting marker and ownerless flush-lock takeover.

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- Crash windows during spool rewrite and -Forget handling.
- Concurrent sender takeover with a partially written lock.
- Prompt-hash/thread-reuse impact across versions.
- Two repositories concurrently applying the health journal.

### First-run checklist (observable)

- [ ] Unlisted models emit model 'other' with no raw label in tags or title.
- [ ] -Forget -PublicRef bad -Local exits 3 with salt, spool and counters intact; the corrected retry succeeds.
- [ ] No forgetting marker survives a completed run; a crashed -Forget is surfaced by -Status.
- [ ] Unknown-start descendants produce an unconfirmed warning and no unrelated pid is signalled.
- [ ] Torn journal lines appear in <journal>.bad with a warning.
- [ ] Spool counts reconcile delivered plus dropped plus remaining after each flush.
- [ ] context_tokens members record compactions: unknown and the brief re-read line.
- [ ] The test-mode line appears on dry runs and dropped telemetry events are reported.
