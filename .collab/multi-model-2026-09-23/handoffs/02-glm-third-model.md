# Handoff 02 - GLM-5.3: third-model

Date: 2026-09-23 local. Author: GLM-5.3 (z.ai GLM Coding Plan), run as a Claude Code worker: `claude -p --model glm-5.3 --allowedTools Read,Glob,Grep --output-format json` with the z.ai Anthropic-compatible endpoint set in the child process only.
Brief: `.collab/multi-model-2026-09-23/handoffs/01-claude-third-model.md`. Wall time: 36.5 s. Turns: 2. Tokens: in 30306 (cache read 28416), out 2008. Session: `7c1197c5-b1d3-41c0-aff8-52054025f753`.
Not produced by the bridge (the bridge has no GLM provider yet - that is what this consultation is about); saved by the coordinator verbatim.
Verbatim reply follows.

---

I read the brief. Answers by number (I am the GLM-5.3 instance it describes — a Claude Code worker on z.ai's Anthropic-compatible endpoint).

**Q1. Role.** GLM fits cheap, parallel, fresh-context work: `diff-review`, `refuter` (its best fit — adversarial breaking of claimed invariants has a crisp success criterion), and idea generation as brainstorming only. Test execution (option B) works only with evidence-first briefs: require exit codes and artifact paths, never trust "done" — the A/B calibration showed my self-reported completion is the weak point. GLM must NOT: be final arbiter (policy already says Claude has the final word), share thread lineage with Codex-model threads, or own multi-day stateful debugging.

**Q2. Fan-out.** Worth it only for high-stakes briefs (invariant checks, pre-release diffs), not routine consults — otherwise it doubles verification load for marginal gain. Ledger: record `reported_by` per finding id plus a cross-review status (`both` / `codex-only` / `glm-only` / `disagree`). Agreement should *downgrade* verification (lighter spot-check), never eliminate it — two models share training-corpus biases and can share a blind spot. `glm-only` findings get verified before action; explicit disagreement is itself a signal worth surfacing to the coordinator.

**Q3. delegations[].** Yes, the right mechanism. It converts "unproven" into a runnable check with an expected observation, keeps the reviewer pure, and keeps the coordinator as executor of record — which matters for the sandbox/ledger story. Constraint: a delegation must be one command + expected observation, capped per brief; open-ended "investigate this" must be refused, or GLM's tendency to wander re-enters.

**Q4. Mechanics.** Provider per thread + refusing fork/resume across providers is correct and necessary (the compaction issue, fact 2). Record provider *and* model per thread, since provider≠model pairs will grow. Keep both wires for different roles: the Codex wire for consult/diff-review with the findings schema; the Claude-Code-worker wire for workspace-write test execution, which the read-only Codex sandbox cannot do. The `--output-schema` + GLM combination is untested — smoke-test it before relying on it; fallback is JSON-in-prompt plus coordinator-side validation against `plugins/codex-consult/schemas/`.

**Q5. MiMo-V2.6.** Later, not now. Adding a seat requires: (a) an officially supported Claude-Code- or Codex-compatible integration path (OpenRouter generic access doesn't satisfy the same policy logic that constrains z.ai keys to supported tools, and the `responses`-wire compatibility is unverified), and (b) a project-local eval: it catches a seeded bug or breaks an invariant the existing seats miss, at acceptable cost. Leaderboard rank is not evidence about reliability inside *this* agent harness.

**Q6. Quota/policy.** The bridge should: record per-consult credit estimates in the ledger (model, reasoning level, token usage from `turn.completed` — it's already emitted); enforce a `-Provider` allowlist in config rather than CLI convention; emit an advisory peak-hour warning (Mon–Fri 14:00–18:00 SGT), possibly nudging toward Flash for low-stakes purposes. The "supported tools only" rule is structural, not a runtime check: the bridge must only ever shell out to `codex`/`claude` binaries, never an HTTP client — worth one assertion/test that no direct SDK path exists. Off-peak scheduling itself belongs to the operator, not the bridge.

**Q7. My integration paths.** Confirmations from inside: I am running with the full Claude Code tool loop through z.ai's Anthropic-compatible endpoint — this very consultation (I read the handoff from disk) shows the worker wire supports multi-turn agentic work, not just single-turn Q&A; the stale MCP single-turn picture (fact 4) undersells the current path. What I cannot verify from in here and the brief should treat as unknown: my true effective context limit (1M is the spec I can't introspect), how Codex's reasoning `low/high/max` maps onto my actual inference budget, per-account rate limits, and whether structured output survives the `responses` wire — the planned smoke test is the only ground truth, and `plugins/codex-consult/schemas/` being still untracked makes validating it the natural next step. I also can't see my own serving config or whether this endpoint differs from the Codex-facing one; I won't guess.

*(~660 words; no files written.)*
