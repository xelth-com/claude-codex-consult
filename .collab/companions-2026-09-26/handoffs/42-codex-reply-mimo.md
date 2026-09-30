# Handoff 42 - Codex: reply-mimo

Date: 2026-09-30 09:35 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 10, panel 487a27ee member 2 of 4.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 2edabe6c-c3f8-400f-929f-0e8e4faa5790.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8faf9ad17db5455f9cdeb4c8d5166faa.md fork 01a0ef4e-e4bf-7083-ab35-391f19b63316 -` (prompt on stdin).
Parent thread: `01a0ef4e-e4bf-7083-ab35-391f19b63316`. Result thread: `01a0f13d-5245-7320-b62a-0f5b3df4bdad` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/40-claude-wave28b-acceptance.md` (sha256 e08488b2f57e). Reviewed: 2adef35, base 2adef3513e2f3775752bed91a7a2add04426c375, tree sha256 2cf9646c29f1, 0 changed files.
Bridge outcome: usable reply (after a timeout continuation). Wall time: 3601.6 s. Tokens: unknown.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `1de388e..e5c6992` - the range changes 43 files, 9583 lines (8924 insertions, 659 deletions).
Timeout continuation: the main turn was killed at 3601.6 s of 3600 s; one continuation turn on thread `01a0f13d-5245-7320-b62a-0f5b3df4bdad` answered in 272.5 s. Tokens of that turn: in 66019734 (cached 48171904), out 179196, reasoning 102247.
Verdict: HOLD - Wave 28b closes the named crash and spool gaps, but telemetry privacy/deletion races and process-tree identity failures still include major defects. Findings: 0 blocker, 6 major, 3 minor, 0 note (F42-1..F42-9, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/42-codex-reply-mimo.reply.json`.
Raw event stream: `handoffs/42-codex-reply-mimo.events.jsonl`; further turns: `handoffs/42-codex-reply-mimo.continue.events.jsonl`.
Verbatim reply follows.

---

## 1. F35-1, F36-1..11, F37-1..6
F35-1 is fixed: failed spooling becomes a ledger/console warning and a `-Status` count (`codex-consult.ps1:5775-5779`; `codex-consult-common.ps1:9633-9679`). F36-1 remains open because the model grammar still admits operator text (finding #1). F36-2 remains open because the 60-second bound omits local spool work and stale-lock takeover lacks fencing (findings #7-#8). F36-3 is fixed as scoped by the sender environment allowlist (`common.ps1:9488-9525`). F36-4 is fixed by anchored host-plugin-root comparison (`:5654-5664`). F36-5 is fixed: test state is hidden from engine children and visibly announced. F36-6 is fixed for the commit/retry crash window by the journal, though a torn tail remains (finding #6). F36-7 is fixed: immediate and deferred complaints preserve identical bytes (`:10137-10158`). F36-8 is fixed by visible spool-loss diagnostics. F36-9 is fixed by atomic salt creation and test-gated loopback HTTP. F36-10 is fixed in the host command and waiting-cost documentation. F36-11 is fixed with the bounded `2 x StallSec` tool suspension (`:8794-8800,8852-8859`). F37-1 is fixed for the stated crash-loss claim by journaling. F37-2 and F37-3 remain open through findings #4-#5. F37-4 is fixed by HTTPS/test-mode gating. F37-5 is fixed byte-for-byte. F37-6 is fixed by visible spool contention diagnostics.

## 2. New defects
Findings #1-#6 are major: model strings can leak operator text; `-Forget -Local` can destroy its deletion-retry handle and race producers; process-tree identity is unsafe when start times are unknown or `pgrep` fails; and a torn journal tail is deleted. Findings #7-#9 are minor lock, deadline and Unix trust-environment gaps. The planned 400/413/403 handling is sound, provided 413 halving bottoms out and reports a single permanently oversized body.

## 3. Acceptance decision
HOLD. Replace model regexes with a closed enum or keyed hash; make `-Forget` transactional and producer-safe; require verified descendant identity and successful process enumeration; preserve torn journal tails; and fence sender leases while enforcing one total flush deadline. Then run the checks below.

## Requested checks
RC1 — `C:/Users/Dmytro/claude-codex-consult`; workspace-write; 10 minutes. Submit hostile model strings and inspect captured telemetry; finding #1 requires no operator text.
RC2 — Same directory; workspace-write; 10 minutes. Race `-Forget -Local` with commits and retry a wrong `public_ref`; findings #2-#3 require a reusable instance id and no resurrection.
RC3 — Same directory; workspace-write; 15 minutes. Recycle descendant PIDs with unreadable start times and force `pgrep` failure; findings #4-#5 require safe non-confirmation and ps/proc fallback.
RC4 — Same directory; workspace-write; 5 minutes. Interrupt a journal append, then apply health updates; finding #6 requires the tail to survive until parsed.

---

### Findings

- **F42-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9118`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9339` - Telemetry's model vocabulary is still a permissive pattern rather than a closed published-model set. Version-like operator text can pass and leave in details.model and tags, defeating the promise that operator text and user/project names never leave the machine. Trigger: A known-vendor endpoint uses model `gpt-al1ce-code` or `glm-acm1ecorp-fast`. Evidence: read-code: the regex permits arbitrary alphanumeric version segments and returns the lower-cased operator string. Verify: Call the telemetry conversion with hostile model names and inspect the captured request body. Remedy: Use explicit model enums or keyed stable hashes; never emit arbitrary operator model text. Supersedes: F36-1.
- **F42-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:10176`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10188` - `-Forget -PublicRef <wrong> -Local` destroys the salt after failed remote deletion, so the old instance id cannot be reconstructed and deletion cannot be retried with the correct public reference. Trigger: The intake rejects the supplied public_ref and the operator also requests local deletion. Evidence: read-code: local deletion proceeds after the remote delete returns failure. Verify: Make DELETE return an invalid-reference response with -Local and then attempt a corrected retry. Remedy: Abort local deletion after remote failure, or retain a deletion journal containing the salt and instance id until remote deletion succeeds.
- **F42-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:9455`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10190` - `-Forget -Local` excludes only senders. A concurrent telemetry producer can append after enumeration or recreate the salt while local deletion reports success, so removed-local state is not atomic across producers. Trigger: A panel member commits while `-Forget -Local` deletes spool files and the salt. Evidence: read-code: spool append and salt creation do not participate in the deletion lock. Verify: Race a fake commit with local deletion and inspect for recreated salt or spool files. Remedy: Use one producer/consumer lease, quiesce writers, and verify salt and spool remain absent after deletion.
- **F42-4** [major] `plugins/codex-consult/scripts/codex-consult-detached.ps1:128`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8543` - Descendants with unreadable start times fall back to pid-only identity. A recycled PID whose new process also has an unreadable start time can be killed as part of the tree or counted as a survivor, potentially terminating unrelated work or wedging recovery. Trigger: A descendant PID is reused during or after enumeration and the replacement process's StartTime is inaccessible. Evidence: read-code: an empty start time disables start-time comparison while kill and liveness still accept the PID. Verify: Recycle a descendant PID with unreadable identity during the confirmation window and inspect kill/survivor results. Remedy: Treat unknown start identity as unverified: never kill it or claim confirmation solely from PID liveness. Supersedes: F37-2.
- **F42-5** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:8505`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8511` - The pgrep process-tree path does not distinguish an empty child set from failed enumeration. A restricted pgrep can report no descendants and allow a false confirmed kill even though children remain. Trigger: On Unix, `pgrep` exists but `pgrep -P` exits nonzero or cannot inspect the process tree. Evidence: read-code: pgrep exceptions and empty output become no children; fallback runs only when pgrep is absent. Verify: Install a failing pgrep shim and force a timeout kill with an enumerable child. Remedy: Check pgrep exit status and fall back to ps/proc on any failure; report Denied if all methods fail. Supersedes: F37-3.
- **F42-6** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5276`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5299` - The health journal silently destroys an unparsable tail. A process killed during append can leave a partial record which the next successful update skips and then truncates, recreating cross-repository health loss. Trigger: The bridge dies mid-journal append and another repository later applies the journal. Evidence: read-code: invalid lines are ignored and the whole journal is cleared after a successful health write. Verify: Append a deliberately partial final record, run an update, and inspect whether the tail remains. Remedy: Retain unparsable tails or use checksum/length-framed records; never delete unconsumed bytes. Supersedes: F36-6.
- **F42-7** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:9920`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9854` - Stale flush-lock takeover has no fencing token. A suspended sender older than five minutes can resume after takeover and concurrently send or rewrite the same spool. Trigger: One sender stalls past five minutes and another takes over, then the first resumes. Evidence: read-code: takeover rewrites ownership without invalidating the previous owner before each mutation. Verify: Resume a stale sender after takeover and inspect concurrent requests and spool consistency. Remedy: Use heartbeat leases and an epoch/token recheck before every send and spool mutation. Supersedes: F36-2.
- **F42-8** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:10012`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10074` - The 60-second flush deadline covers request iterations but not local spool enumeration, reads and rewrites, so a busy or very large spool can exceed the advertised bound while holding the sender lock. Trigger: A large spool or slow filesystem makes local reads and rewrites exceed 60 seconds. Evidence: read-code: local spool operations have retry waits but no total deadline check. Verify: Measure a flush over a huge/busy spool and compare total duration with 60 seconds. Remedy: Enforce the deadline around all flush work and cap per-file work. Supersedes: F36-2.
- **F42-9** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:9493`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9543` - The sender environment allowlist omits Unix custom trust inputs, so HTTPS can fail behind a private CA even when the coordinator's network works. Trigger: A Unix sender runs with `SSL_CERT_FILE` or `SSL_CERT_DIR` pointing at a private CA. Evidence: read-code: the allowlist includes platform and proxy basics but not the standard certificate trust variables. Verify: Run the sender against a private-CA HTTPS intake with only `SSL_CERT_FILE` set. Remedy: Add narrowly required certificate/loader variables while continuing to exclude credentials and test hooks.

### Prior findings

- F02-1 - not-checked - Companions scoring work is outside this wave's assigned scope.
- F02-2 - not-checked - Companions telemetry joins are outside scope.
- F02-3 - not-checked - Companions rating windows are outside scope.
- F02-4 - not-checked - Topic scoring is outside scope.
- F02-5 - not-checked - Diversity behavior is outside scope.
- F02-6 - not-checked - Panel-size semantics are outside scope.
- F02-7 - not-checked - Routing seeding is outside scope.
- F02-8 - not-checked - Routing fallback is outside scope.
- F02-12 - not-checked - -Require is outside scope.
- F02-13 - not-checked - Roles are outside scope.
- F02-14 - not-checked - Companions tests are outside scope.
- F02-15 - not-checked - Companions documentation is outside scope.
- F03-1 - not-checked - R15 scoring is outside scope.
- F03-2 - not-checked - R14 diversity is outside scope.
- F03-3 - not-checked - R16 role safety is outside scope.
- F03-6 - not-checked - R15 fallback is outside scope.
- F03-7 - not-checked - R15 seeding is outside scope.
- F03-8 - not-checked - R16 role assignment is outside scope.
- F03-9 - not-checked - -Require behavior is outside scope.
- F03-10 - not-checked - Roster schema is outside scope.
- F03-11 - not-checked - Topic telemetry is outside scope.
- F03-12 - not-checked - Panel sizing is outside scope.
- F04-1 - not-checked - R14/R15 selection is outside scope.
- F04-2 - not-checked - Telemetry joins are outside scope.
- F04-3 - not-checked - Lab grouping is outside scope.
- F04-4 - not-checked - R15 scoring is outside scope.
- F04-5 - not-checked - R15 seeding is outside scope.
- F04-6 - not-checked - R15 portability is outside scope.
- F04-7 - not-checked - -Require availability is outside scope.
- F04-8 - not-checked - -Require matching is outside scope.
- F04-11 - not-checked - Panel state modeling is outside scope.
- F04-12 - not-checked - R14/R15 test compatibility is outside scope.
- F04-13 - not-checked - Roster schema is outside scope.
- F04-14 - not-checked - Exploration gates are outside scope.
- F04-15 - not-checked - Exit-code documentation is outside scope.
- F04-16 - not-checked - R16 roles are outside scope.
- F04-17 - not-checked - Panel sizing and peak behavior are outside scope.
- F04-18 - not-checked - Telemetry details are outside scope.
- F15-1 - not-checked - Failure classification is outside scope.
- F15-2 - not-checked - Identity caching is outside scope.
- F15-3 - not-checked - Killed-turn classification is outside scope.
- F15-4 - not-checked - Failure hints are outside scope.
- F15-5 - not-checked - Resume serialization is outside scope.
- F15-6 - not-checked - Recovery restoration is outside scope.
- F19-1 - not-checked - Panel-size reporting is outside scope.
- F22-6 - not-checked - Legacy-rating completion is outside scope.
- F35-1 - fixed - Spool failure is visible in ledger, console and -Status.
- F36-1 - still-open - Model grammar still leaks operator text; finding #1 supersedes it.
- F36-2 - still-open - Flush bounds and lock takeover remain incomplete; findings #7-#8 supersede it.
- F36-3 - fixed - The sender uses an environment allowlist excluding credentials, host markers and test state.
- F36-4 - fixed - Host-path inference is anchored to resolved host plugin roots.
- F36-5 - fixed - Test state is hidden transactionally from engine children and visibly announced.
- F36-6 - fixed - The journal closes the commit/retry crash window; torn-tail loss is finding #6.
- F36-7 - fixed - Complaint preview, immediate send and deferred retry preserve identical bytes.
- F36-8 - fixed - Spool loss and contention are surfaced in diagnostics.
- F36-9 - fixed - Salt creation is atomic and loopback HTTP requires test mode.
- F36-10 - fixed - Host command blocks use one defined plugin-root name and the waiting costs distinguish wake/read/compaction terms.
- F36-11 - fixed - Tool suspension ends after twice the stall interval without growth.
- F37-1 - fixed - The journal preserves the health record across the post-commit crash window.
- F37-2 - still-open - Unknown descendant start identity restores PID-reuse risk; finding #4 supersedes it.
- F37-3 - still-open - Failed pgrep enumeration can still confirm a tree kill falsely; finding #5 supersedes it.
- F37-4 - fixed - Loopback HTTP is permitted only in test mode.
- F37-5 - fixed - The exact complaint serialization is retained for deferred delivery.
- F37-6 - fixed - Spool contention produces visible ledger/console diagnostics.

## Verdict: HOLD

Wave 28b closes the named crash and spool gaps, but telemetry privacy/deletion races and process-tree identity failures still include major defects.

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- No harness, race test, or live intake request was executed in this read-only review.
- Actual Unix sender behavior behind a private CA and required loader variables was not measured.
- Windows and Unix descendant PID-reuse timing, inaccessible StartTime behavior, and failing pgrep behavior were not reproduced.
- Torn journal appends and concurrent -Forget producer races were not executed.
- The context-window auto-compaction and brief-binding lifecycle was reviewed only through code and harness assertions.
- DST transitions for local spool-day naming and the host command blocks were not run on all documented hosts.

### First-run checklist (observable)

- [ ] Submit hostile model labels and inspect the captured event: only a closed vendor/model vocabulary may leave the machine.
- [ ] Run wrong-ref deletion with -Local and a concurrent commit: retain a retryable instance identity and leave no recreated spool or salt after successful local removal.
- [ ] Force inaccessible descendant start times, PID reuse, and failing pgrep: never kill an unverified PID and never claim an unconfirmed tree kill.
- [ ] Interrupt journal append at a record boundary and then apply updates: retain and apply every complete record without deleting a torn tail.
- [ ] Hold a sender past lease expiry while another takes over, and run a huge spool behind a private-CA intake: observe one fenced owner, a true 60-second bound, and successful HTTPS trust.
