# Handoff 02 - Codex: third-model

Date: 2026-09-23 22:52 local. Author: Codex (model config default, effort high), Codex CLI 0.155.1.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only). Argv: `codex exec --sandbox read-only --color never --json -c model_reasoning_effort="high" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-d6ae61850ada424489d03005fd0f5d4f.md fork 01a0cff8-4583-7110-8730-5fda5333d388 -` (prompt on stdin).
Parent thread: `01a0cff8-4583-7110-8730-5fda5333d388`. Result thread: `01a0d00a-392b-7fe1-9f46-e89d96ecfdde` (source: events).
Brief: `.collab/multi-model-2026-09-23/handoffs/01-claude-third-model.md`. Reviewed revision: 6483ec4 + uncommitted. Outcome: usable reply. Wall time: 84.1 s.
Raw event stream: `handoffs/02-codex-third-model.events.jsonl`.
Verbatim reply follows.

---

**Recommendation: add GLM as an optional, measured participant now; defer MiMo’s permanent seat.** Keep the coordinator responsible for acceptance. Integrate provider support after the 0.2.0 persistence and locking contracts are stable.

**Q1. Role**

Use GLM for bounded diff reviews, counterexamples to specific invariants, test-case proposals, and alternative designs. Selective checkpoints fit; routine duplication of every checkpoint does not.

For test execution, deterministic commands should run directly where possible. GLM adds value when selecting tests, reproducing failures, or interpreting logs. Given the reported abandoned test run, require captured commands, exit codes, logs, tested revision, and explicit incomplete status.

It must not certify its own unsupported “done,” close findings, or overrule unresolved evidence. “Refuter” should mean *seek reproducible counterexamples*, with “none found” allowed—not a quota for objections. These roles are economically motivated hypotheses, not established model specializations.

**Q2. Dual review**

Worth trying at contract boundaries and acceptance, with identical revision-bound briefs and neither reviewer seeing the other’s answer initially. Fresh threads provide cleaner independence than accumulated review histories.

You cannot match independently discovered findings by ID: each receives a different ID. Preserve both reports and let the coordinator link them to a canonical issue after comparing claim, trigger, and affected invariant.

Record review-group ID, brief/revision hashes, reviewer/model/provider/harness, source finding IDs, and relationships such as corroborates, contradicts, or duplicates. Agreement prioritizes investigation; it never substitutes for verification. Silence is not disagreement.

Measure unique verified defects, false positives, coordinator verification minutes, and avoided rework. Stop routine fan-out if marginal value is poor.

**Q3. Delegations**

Useful, but name them `requested_checks[]`: they are requests for evidence, not execution authority.

Include ID, related finding/invariant, proposed command or procedure, working directory, required permissions, expected observation, and budget. The coordinator chooses the executor and validates scope. Record completion separately with revision, logs, exit status, and observed result.

Keep `unproven[]` for the uncertainty; requested checks describe how to resolve it. Bound follow-up rounds to prevent recursive consultation loops. Initially, this can be a brief convention rather than another mandatory schema expansion.

**Q4. Mechanics**

`-Provider` is necessary but insufficient:

- Select the latest thread within an explicit reviewer lineage, never the task’s latest thread globally.
- Bind lineage to provider, endpoint/config fingerprint, model, and harness; refuse incompatible or unknown provenance on resume/fork.
- Record resolved configuration, not merely “config default”; never log credentials.
- Validate provider-specific efforts. The bridge currently accepts `medium/xhigh` and rejects `max`, while GLM documents `low/high/max`. Use explicit mappings and record requested/effective values. [Z.ai integration](https://docs.z.ai/devpack/tool/codex)
- Test schema enforcement, tools, streaming, cancellation, usage, and long-history behavior independently.

Keep Codex transport for standardized reviews and the existing Claude worker for bounded execution. Distinguish harness from model identity in headers. For initial fan-out, serialize persistence under the task lock; true concurrency needs separate run records and atomic ingestion.

**Q5. MiMo**

Later as a standing participant; a capped evaluation now is reasonable. The integration premise needs updating: OpenRouter already documents Codex using `wire_api="responses"`. That establishes a route, not MiMo-specific reliability. [OpenRouter guide](https://openrouter.ai/blog/tutorials/codex-cli-openrouter/)

Evaluate representative historical defects and clean controls at fixed budgets. Require incremental verified findings, tolerable false positives, completed execution, reliable tool/schema behavior, and lower total coordination cost. Consider replacing an existing role before adding another permanent reviewer.

**Q6. Quota and policy**

Under the stated policy, allow only configured supported-tool routes; prohibit direct-HTTP fallback with plan credentials. Validate endpoints as well as provider aliases. Bound retries, concurrency, and wall time.

Record UTC timestamps, Asia/Singapore tariff classification, model, usage, retries, pricing-policy version, and estimated versus observed credits. Reconcile estimates with provider billing; other tools consume the same quota.

Use a peak warning plus optional off-peak-only enforcement. Do not hard-code one perpetual schedule: Z.ai currently specifies both five-hour and weekly limits, plus September 25–October 7 all-day off-peak pricing. [Quota rules](https://docs.z.ai/devpack/overview)
