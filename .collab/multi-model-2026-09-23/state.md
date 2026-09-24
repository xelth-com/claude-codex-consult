# Task: multi-model-2026-09-23 - should a third (GLM-5.3) and fourth (MiMo-V2.6) model join the loop?

Coordinator: Claude Code. Two reviewers on ONE brief (`handoffs/01-claude-third-model.md`), answering independently:
Codex (gpt-6-astra, thread `01a0d00a-392b-7fe1-9f46-e89d96ecfdde`, fork of the 0.2 design thread) ->
`handoffs/02-codex-third-model.md`; GLM-5.3 (Claude Code worker through z.ai) -> `handoffs/02-glm-third-model.md`.
Both handoffs carry the same number because the bridge wrote one and the coordinator saved the other by hand.

## Facts established today (beyond the brief)

- `codex exec -c model_provider=ZAI -m glm-5.3` works end to end from this repository (thread.started, read-only
  command execution, turn.completed with usage). Thread `01a0d008-39d3-7751-bed0-24e2aa908004`.
- `--output-schema` with GLM through Codex is NOT enforced server-side: the final message came back as a
  ```json fenced block, field-complete against schema v1 (all eight top-level fields, the finding shape correct).
  The 0.2.0 parser strips a fence and validates locally, so GLM replies are usable, but validity is not guaranteed.
  Thread `01a0d00b-dba4-7e03-be83-771532d748eb`.
- Three `GET .../models` calls were made with the plan key by a plain HTTP client while establishing the model
  list. The z.ai policy restricts plan keys to supported tools; no further direct calls will be made - the model
  list is also available through the Codex wire (`api/v1/models` is what Codex itself queries).

## Where the two reviewers agree

- GLM joins NOW as an optional, measured participant; MiMo-V2.6 gets a seat LATER, after a capped project-local
  evaluation (seeded historical defects + clean controls at a fixed budget); leaderboards are not the evidence.
- GLM's roles: bounded diff review, counterexamples to specific invariants ("refuter" = seek reproducible
  counterexamples, "none found" allowed), test-case proposals, alternative designs, idea generation. Selective
  checkpoints, not every one. It must NOT certify its own "done", close findings, or arbitrate.
- Test execution by GLM only with evidence-first briefs: captured commands, exit codes, logs, tested revision,
  explicit incomplete status (the abandoned-test-run calibration).
- Fan-out of one brief to two reviewers: worth it at contract boundaries and acceptance, not routinely; identical
  revision-bound briefs, fresh threads, neither sees the other's answer first. Agreement prioritises
  investigation and may lighten the spot-check; it never replaces verification. Measure it (unique verified
  defects, false positives, coordinator verification minutes, avoided rework) and stop routine fan-out if the
  margin is poor.
- Reviewer requests for evidence are the right mechanism; name them `requested_checks[]` (Codex), one command +
  expected observation each, capped per brief (GLM), coordinator chooses the executor. `unproven[]` keeps the
  uncertainty, `requested_checks[]` says how to resolve it. First as a brief convention, not a schema change.
- `-Provider` alone is insufficient: bind a thread lineage to provider + model + harness (+ config fingerprint),
  select the latest thread WITHIN a reviewer lineage (never the task's latest thread globally), refuse fork/resume
  across lineages, record the resolved model rather than "config default", map efforts per provider (GLM:
  low/high/max; Codex: low/medium/high/xhigh) and record requested vs effective, never log credentials.
- Keep both wires: Codex transport for standardised reviews with the findings schema; the Claude Code worker
  wire for bounded workspace-write execution. Distinguish harness from model identity in headers.
- Quota/policy: only configured supported-tool routes, no direct-HTTP fallback with plan credentials; record UTC
  time, Singapore tariff class, model, usage, retries, estimated vs observed credits; peak-hour warning with
  optional off-peak-only enforcement; do not hard-code one schedule (z.ai changes it, e.g. 2026-09-25..10-07
  all-day off-peak).

## Where they differ

- Findings from two reviewers: GLM proposed `reported_by` + a cross-review status per id; Codex points out the
  ids cannot match (each reviewer's findings get their own ids) and the coordinator must link them to a canonical
  issue with relationships (corroborates / contradicts / duplicates) plus a review-group id. Codex's version is
  adopted; it is consistent with the 0.2.0 id scheme.
- Timing: Codex says integrate provider support AFTER the 0.2.0 persistence and locking contracts are stable;
  GLM did not object. Adopted: this is 0.3.0 work (ROADMAP R7-R9), not a late addition to 0.2.0.

## Decision (coordinator)

1. 0.2.0 ships without provider support. R7 (provider + reviewer lineage), R8 (`requested_checks[]` convention,
   then schema), R9 (review groups for fan-out) go into the ROADMAP with the facts above.
2. Until R7 exists, GLM is consulted through the Claude Code worker wire (existing recipe) and the reply is
   saved by hand as a handoff, exactly as done here.
3. MiMo-V2.6: no seat; re-evaluate when an officially supported Claude Code / Codex route exists or after a capped
   OpenRouter evaluation (OpenRouter documents the Codex `responses` wire).
