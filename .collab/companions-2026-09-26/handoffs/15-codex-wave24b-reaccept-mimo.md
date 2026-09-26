# Handoff 15 - Codex: wave24b-reaccept-mimo

Date: 2026-09-26 20:28 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave24b-reaccept.json - position 1 of 3, panel 785de0f7 member 1 of 3.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 1bb2f756-da9c-4553-b6e0-7d2a677371f9.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-9493cb22db904a83bb2e8d956e34d5ec.md fork 01a0de45-daa9-7df3-a15d-8e9d120a5c94 -` (prompt on stdin).
Parent thread: `01a0de45-daa9-7df3-a15d-8e9d120a5c94`. Result thread: `01a0def9-ece2-7571-9f6f-c82ca3bf33aa` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/14-claude-wave24b-reacceptance.md` (sha256 56e0652db744). Reviewed: 6b88cc8, base 6b88cc8c4c0cd7c63eef59970709cf76ac62734f, tree sha256 04b2be0befce, 0 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 2020.6 s. Tokens: in 11129026 (cached 7702400), out 80937, reasoning 49452.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s.
Verdict: HOLD - Wave 24b still leaves two prior major gates open and introduces additional major classification and cache defects. Findings: 0 blocker, 2 major, 4 minor, 0 note (F15-1..F15-6, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/15-codex-wave24b-reaccept-mimo.reply.json`.
Raw event stream: `handoffs/15-codex-wave24b-reaccept-mimo.events.jsonl`.
Verbatim reply follows.

---

## 1. Prior rulings
`F07-1` fixed: prompt-only continuations resend the contract and schema (`codex-consult.ps1:3080-3089`). `F07-2` fixed: id-less tools pair once (`codex-consult-common.ps1:4135-4187`). `F07-3` fixed for normal listings: shared identity/health caches remove repeated resolution (`codex-consult-common.ps1:5224-5239`). `F08-1` fixed: every turn starts through the fresh guard (`codex-consult.ps1:681-697,2720,3308`). `F08-2` still open: tracked Codex changes gate continuation, but Codex `.collab` changes remain invisible because the snapshot is non-Codex-only and the fingerprint excludes `.collab` (`codex-consult.ps1:2685-2689,3062-3068`; `codex-consult-common.ps1:557-583`). `F08-3` fixed: adapter, event and stderr evidence reaches the shared classifier (`codex-consult.ps1:3070-3075`; `codex-consult-common.ps1:4323-4341`). `F08-4` still open: reply-rejected continuation evidence is discarded, so exit-zero quota prose can escape `provider_failure` (`codex-consult.ps1:3135-3148,3167-3175,3465-3470`). `F08-5` fixed: continuation output passes first-reply checks before replacing salvage (`codex-consult-common.ps1:4351-4368`). `F08-6` fixed for its listed options (`codex-consult.ps1:3544-3565`). `F08-7` fixed: unknown-reset quota refuses every caller (`codex-consult-common.ps1:5181-5191`). `F08-8` fixed (`codex-consult-common.ps1:339-350`). `F13-1` fixed (`codex-providers.ps1:332-333,389-390`). `F13-2` fixed (`codex-consult-common.ps1:4733-4743`).

## 2. New defects
I verified the cited code at `6b88cc8` with `git show` and the 24b diff; I did not execute the harnesses. Finding #1 is major: the new context-overflow exception can steal quota/billing failures. Finding #2 is major: the new identity cache is case-insensitive although identity matching is case-sensitive. Findings #3-#6 are minor: broad killed-turn scanning can false-positive, context hints can be lost, the new resume serializer omits replay options, and a launch error can leave a misleading recovery state. Behavioral outcomes are inferred until the listed checks run.

## 3. Acceptance decision
HOLD. Before acceptance, preserve Codex `.collab` changes in the continuation gate, classify reply-rejected provider error prose into `provider_failure`, prioritize full quota/billing evidence over context overflow, make cache keys ordinal, and complete the resume/recovery paths. Then run the first-run checklist below under Windows PowerShell 5.1 and PowerShell 7.

---

### Findings

- **F15-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:4391`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4405`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4416` - The new context-overflow exception excludes only the narrow quota-text pattern, while quota classification also recognizes billing, payment, insufficient-balance, credits and token-plan wording. A billing or quota error that also mentions a context window is forced to capability, so continuation and endpoint health can violate the no-continuation/no-success-after-quota invariants. Trigger: A continuation or killed turn reports `billing_required: insufficient balance for this context window` or `credits exhausted; prompt is too long`. Evidence: read-code: Test-ContextOverflow excludes only QuotaTextPattern, while Test-ContextOverflow is checked before ordinary classes.; read-code: the quota class includes billing/payment/credits/token-plan terms absent from QuotaTextPattern.; inferred: such text becomes capability, so it cannot trigger the quota/auth continuation gate or quota health. Verify: Unit-test the combined billing-plus-context messages and assert class quota, no continuation, and quota-blocked endpoint health. Remedy: Apply the complete quota/billing classifier before the context exception, or make Test-ContextOverflow exclude every quota-class pattern.
- **F15-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5224`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5227` - The new identity cache uses a plain case-insensitive PowerShell hashtable key even though provider and model identity matching is case-sensitive. Case-distinct roster entries can therefore reuse another entry's identity, fingerprint and cached health. Trigger: A valid roster contains `ZAI :: glm-5.3` and `zai :: glm-5.3`, or two models differing only by case. Evidence: read-code: the cache key concatenates provider/model into an ordinary PowerShell hashtable.; read-code: roster entry matching uses ordinal, case-sensitive comparisons.; inferred: keys differing only by case collide in the default comparer. Verify: Run one listing over a case-collision roster and assert that each entry resolves to its own fingerprint and health. Remedy: Use an ordinal dictionary or an unambiguous length-prefixed, case-preserving cache key.
- **F15-3** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:4323`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4330` - Get-KilledTurnFailure classifies every non-filtered stderr line independently, so benign informational text containing whole words such as `auth`, `billing`, `quota`, `401`, or `429` can falsely suppress an otherwise permitted continuation. Trigger: A killed turn emits informational stderr such as `loaded auth.json` or `request 429 tracing enabled` without any provider failure. Evidence: read-code: all stderr lines except Muse's informational filter are candidates and the first matching quota/auth class wins.; read-code: broad whole-word auth and quota regexes match those examples. Verify: Feed benign diagnostic stderr alongside a clean timeout and assert that the continuation is still attempted. Remedy: Parse structured provider errors first and classify only telling diagnostic lines, with a denylist for informational engine messages.
- **F15-4** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:4423`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4707` - New-ProviderFailure classifies from error code plus message and then truncates the message, but Get-FailureHint re-tests only the stored message. Context overflow identified from an error code, or from text removed by truncation, loses the promised operator hint. Trigger: The provider returns code `context_length_exceeded` with message `Request too large.`, or a long message whose context phrase lies after 200 characters. Evidence: read-code: classification sees code plus full message; storage keeps only a truncated message.; read-code: the hint re-tests only failure.message. Verify: Create the code-only context failure and assert that the summary still prints the context-too-long hint. Remedy: Store the classification evidence or derive the hint from code plus untruncated evidence at classification time.
- **F15-5** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:3533`, `plugins/codex-consult/scripts/codex-consult.ps1:3544`, `plugins/codex-consult/scripts/codex-consult.ps1:3566` - The new resume serializer still omits replay-relevant `-ReplyName` and `-SkipPreflight`, so the supposedly exact command can produce different handoff names or repeat a preflight and refuse a run that originally started unchecked. Trigger: A run uses a non-default reply name or `-SkipPreflight`, times out, and the printed resume command is executed. Evidence: read-code: the option list covers timeout, continuation, effort, schema, config, artifacts, range and launchers but contains neither option.; inferred: both options affect output identity or whether the resumed run can start. Verify: Kill runs using each option, execute their printed commands under fakes, and compare resolved output names and preflight records. Remedy: Serialize `-ReplyName` and `-SkipPreflight` whenever they were explicitly supplied, or document and enforce equivalent defaults.
- **F15-6** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:719`, `plugins/codex-consult/scripts/codex-consult.ps1:727`, `plugins/codex-consult/scripts/codex-consult.ps1:735` - Invoke-EngineTurn restores the recovery record after a launch refusal but not after a Start-Process error. The record remains `launching` even though no process exists, misleading recovery if the bridge dies before commit. Trigger: A secondary turn's launcher disappears or Start-Process throws after the `launching` record is written. Evidence: read-code: the refusal path restores state/note; the Error path only sets Problem.; inferred: a crash before commit leaves a state that claims a launch is underway. Verify: Force Start-Process failure, kill the bridge before commit, and inspect the pending record consumed by the next run. Remedy: Restore the previous record on every non-start path or mark it explicitly `launch-failed` with no child pid.

### Prior findings

- F02-1 - not-checked - Companions-wave scoring finding; outside this wave.
- F02-2 - not-checked - Companions-wave telemetry finding; outside this wave.
- F02-3 - not-checked - Companions-wave telemetry finding; outside this wave.
- F02-4 - not-checked - Companions-wave topic scoring finding; outside this wave.
- F02-5 - not-checked - Companions-wave diversity finding; outside this wave.
- F02-6 - not-checked - Companions-wave panel-size finding; outside this wave.
- F02-7 - not-checked - Companions-wave routing finding; outside this wave.
- F02-8 - not-checked - Companions-wave routing finding; outside this wave.
- F02-12 - not-checked - Companions-wave -Require finding; outside this wave.
- F02-13 - not-checked - Companions-wave role finding; outside this wave.
- F02-14 - not-checked - Companions-wave test-scope finding; outside this wave.
- F02-15 - not-checked - Companions-wave documentation finding; outside this wave.
- F03-1 - not-checked - Companions-wave scoring finding; outside this wave.
- F03-2 - not-checked - Companions-wave diversity finding; outside this wave.
- F03-3 - not-checked - Companions-wave role finding; outside this wave.
- F03-6 - not-checked - Companions-wave draw-order finding; outside this wave.
- F03-7 - not-checked - Companions-wave seeded-draw finding; outside this wave.
- F03-8 - not-checked - Companions-wave role assignment finding; outside this wave.
- F03-9 - not-checked - Companions-wave -Require finding; outside this wave.
- F03-10 - not-checked - Companions-wave roster-schema finding; outside this wave.
- F03-11 - not-checked - Companions-wave topic telemetry finding; outside this wave.
- F03-12 - not-checked - Companions-wave panel-size finding; outside this wave.
- F04-1 - not-checked - Companions-wave selection-rule finding; outside this wave.
- F04-2 - not-checked - Companions-wave telemetry join finding; outside this wave.
- F04-3 - not-checked - Companions-wave lab grouping finding; outside this wave.
- F04-4 - not-checked - Companions-wave scoring finding; outside this wave.
- F04-5 - not-checked - Companions-wave seeding finding; outside this wave.
- F04-6 - not-checked - Companions-wave PRNG portability finding; outside this wave.
- F04-7 - not-checked - Companions-wave -Require finding; outside this wave.
- F04-8 - not-checked - Companions-wave matcher finding; outside this wave.
- F04-11 - not-checked - Companions-wave panel-state finding; outside this wave.
- F04-12 - not-checked - Companions-wave test-compatibility finding; outside this wave.
- F04-13 - not-checked - Companions-wave roster-schema finding; outside this wave.
- F04-14 - not-checked - Companions-wave exploration finding; outside this wave.
- F04-15 - not-checked - Companions-wave exit-code finding; outside this wave.
- F04-16 - not-checked - Companions-wave role finding; outside this wave.
- F04-17 - not-checked - Companions-wave panel-size finding; outside this wave.
- F04-18 - not-checked - Companions-wave telemetry finding; outside this wave.
- F07-1 - fixed - codex-consult.ps1:3080-3089 resends reply format and schema for prompt-only continuations.
- F07-2 - fixed - codex-consult-common.ps1:4135-4187 pairs id-less tools exactly once.
- F07-3 - fixed - codex-consult-common.ps1:5224-5239 caches identity and health within one listing; case-collision risk is a new finding.
- F08-1 - fixed - codex-consult.ps1:681-697 routes every engine turn, including the main turn at :2720, through the fresh launch guard.
- F08-2 - still-open - Codex tracked changes gate continuation at codex-consult.ps1:3062-3068, but `.collab` changes remain excluded at :2685-2689 and codex-consult-common.ps1:557-583.
- F08-3 - fixed - codex-consult.ps1:3070-3075 and codex-consult-common.ps1:4323-4341 classify all killed-turn evidence; false-positive scanning is a new finding.
- F08-4 - still-open - Non-zero/adapter failures reach provider_failure, but reply-rejected continuation error prose is discarded at codex-consult.ps1:3135-3148,3167-3175.
- F08-5 - fixed - codex-consult-common.ps1:4351-4368 applies first-reply checks before codex-consult.ps1:3496-3500 suppresses salvage.
- F08-6 - fixed - codex-consult.ps1:3544-3565 emits every option listed by this finding; remaining omissions are a new finding.
- F08-7 - fixed - codex-consult-common.ps1:5181-5191 applies the 60-minute unknown-reset refusal to every caller.
- F08-8 - fixed - codex-consult-common.ps1:339-350 requires two named revisions.
- F13-1 - fixed - codex-providers.ps1:332-333 and :389-390 emit every roster position as roster_positions.
- F13-2 - fixed - codex-consult-common.ps1:4733-4743 uses an exact usable-outcome whitelist.

## Verdict: HOLD

Wave 24b still leaves two prior major gates open and introduces additional major classification and cache defects.

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- No harness or test was executed in this read-only review.
- Mixed quota/billing and context-window provider payloads were reasoned from the classifier but not sent by a live endpoint.
- Case-colliding provider/model cache reuse was inferred from PowerShell hashtable semantics and not executed.
- Crash recovery after a Start-Process error was not exercised.
- The implementer's full-suite green report was not independently reproduced.

### First-run checklist (observable)

- [ ] Change muse auth.json after preflight and before each turn; observe every Start-Process refused before launch with no ledger entry and no lingering recovery record.
- [ ] Force a Codex workspace-write timeout after changing both a tracked file and `.collab`; observe no continuation and `files changed during the run` naming both surfaces.
- [ ] Return quota, billing and mixed context-limit errors from first and continuation turns; observe quota classification, no forbidden continuation, and provider_failure/retry_after blocking the next availability check.
- [ ] Return short quota error prose with exit code 0 from a continuation; observe provider_failure class quota rather than only `not a usable reply`, with the partial salvage retained.
- [ ] Run prompt-only and output-schema continuations; observe the schema/contract present only where required and a structured accepted reply.
- [ ] Execute the printed resume command for a run using ReplyName, SkipPreflight and the other replay options; observe identical resolved settings and output names under both PowerShell runtimes.
