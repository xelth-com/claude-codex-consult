# Handoff 01 - Claude: a third (and fourth) model in the loop

Date: 2026-09-23. Repository: `xelth-com/claude-codex-consult` (the bridge; 0.2.0 in progress, see
`.collab/bridge-0.2-2026-09-23/`). This brief goes to TWO reviewers with the same text: Codex
(gpt-6-astra, through the bridge) and GLM-5.3 (as a Claude Code worker through z.ai). Each of you
answers alone; the coordinator (Claude) compares.

## Question

The operator has a z.ai GLM Coding Plan whose quota mostly goes unused. Should GLM-5.3 join the
loop as a cheap "fresh eyes" reviewer/tester for both the Claude coordinator and the Codex
reviewer? Would it make the Claude<->Codex collaboration tighter if BOTH had the strongest GLM
on call? And should Xiaomi's MiMo-V2.6, released yesterday, be a fourth seat?

## Facts verified today

1. **Codex CLI runs GLM-5.3 as its model** through the z.ai devpack: `[model_providers.ZAI]`
   (`base_url https://api.z.ai/api/v1`, `wire_api = "responses"`), reasoning low/high/max,
   1M-token context. Smoke test from this repository:
   `codex exec -c model_provider=ZAI -m glm-5.3 --sandbox read-only --json -` produced
   `thread.started`, a read-only command execution, `turn.completed` with usage, and the last
   message. So the bridge can consult GLM with ONE new option (`-Provider ZAI`), reusing the
   ledger, the thread machinery and (untested with GLM) the `--output-schema` findings schema.
2. **Cross-provider resume/fork is fragile**: a Codex thread that contains OpenAI `compaction`
   items cannot be resumed under a third-party provider (openai/codex#45393). A GLM thread must
   therefore be its own lineage; never fork a Codex-model thread into GLM or back.
3. **Claude Code runs GLM-5.3 as a worker** (`claude -p --model glm-5.3` against z.ai's
   Anthropic-compatible endpoint, credentials only in the child process, tools restricted by an
   allowlist). Operator policy since 2026-08: GLM = idea generator and reviewer, the final word is
   Claude's. Calibration from one A/B: GLM produced correct code on a well-scoped task but
   abandoned its own test run; its "done" was unverified.
4. An older MCP worker (single-turn GLM-4.7 with role personas, no agent loop) exists and is stale.
5. **z.ai usage policy**: plan keys may only be used inside officially supported tools (Claude
   Code, Codex, OpenCode, ...); direct SDK/HTTP use risks rate limits or account freezing. Every
   GLM call therefore goes through Claude Code or Codex CLI, never a plain HTTP client.
6. **Quota**: Lite tier about 2,000 credits per 5-hour window; peak Mon-Fri 14:00-18:00 Singapore
   time at the standard rate, off-peak at half. GLM-5.3-Flash costs about a third of the flagship.
7. **MiMo-V2.6** (Xiaomi, 2026-09-22): Pro (1T MoE, 42B active) and Flash, open weights, 1M
   context, top open-weights score on the Artificial Analysis index, an agent harness "MiMo Code".
   Reachable via OpenRouter; NO devpack-style Claude Code / Codex integration and no coding-plan
   subscription found. Whether Codex's `responses` wire works against OpenRouter is unverified.
8. Codex 0.155 has no per-subagent model provider (`collaboration_modes` removed), so "Codex
   having GLM on call" cannot be a Codex-internal delegation today; it would be the coordinator
   running GLM on Codex's request.

## Options on the table

- **A. GLM through the bridge** (`-Provider ZAI -Model glm-5.3`, own thread lineage, same
  `findings.json`): purposes `diff-review`, `checkpoint`, maybe a "refuter" preset (try to break
  the claimed invariants). The coordinator may fan ONE brief to Codex and GLM and compare
  findings by id (both report / only one reports).
- **B. GLM as the Claude Code worker** (existing recipe): the R6 "fresh-context verifier" for
  mechanics - run the build and the tests in `workspace-write`, report evidence paths.
- **C. A `delegations[]` field in the reply schema**: the reviewer names checks it wants run by a
  cheap executor (command, expected observation); the coordinator runs them on GLM (or a Claude
  worker) and feeds the evidence back in the next brief. This is the only realistic form of
  "Codex has GLM on call".
- **D. MiMo-V2.6 as a fourth seat**: later, once an official Claude-Code- or Codex-compatible
  endpoint exists; or now via OpenRouter as a Codex `model_providers` entry if the wire works.

## Questions (answer by number, under 700 words)

- **Q1.** Role: what should GLM-5.3 do in this loop that neither Claude nor Codex should spend
  effort on, and what must it NOT do? Which purposes fit it: checkpoint, diff-review, test
  execution, refuter, idea generation?
- **Q2.** Fanning one brief to two reviewers and comparing findings by id: worth it, or does it
  double the coordinator's verification cost for little gain? If worth it, how should the
  ledger record cross-reviewer agreement, and does agreement change how much verification a
  finding needs?
- **Q3.** Is `delegations[]` (option C) the right mechanism for a reviewer to get cheap
  evidence, or should the reviewer stay a pure reviewer and simply list "unproven" scenarios
  for the coordinator to prove?
- **Q4.** Mechanics: `-Provider` on the bridge with the provider recorded per thread and
  fork/resume refused across providers - anything wrong or missing? Any reason to prefer the
  Claude-Code-worker wire for GLM over the Codex wire, or to keep both for different roles?
- **Q5.** MiMo-V2.6 as a fourth seat: now, later or never, and on what evidence would you add a
  seat at all (leaderboards are not that evidence)?
- **Q6.** Quota and policy: what should the bridge enforce or record so GLM use stays inside
  supported tools and off-peak (per-consult credit estimate, a `-Provider` allowlist, a
  peak-hour warning)?
- **Q7.** (GLM only) You are the model under discussion. What do you know about your own
  integration paths that the facts above get wrong or miss - endpoints, reasoning levels,
  structured output support through Codex, context limits, rate limits?
