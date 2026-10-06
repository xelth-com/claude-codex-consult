Write in English.

# Handoff 06 - claude: the `claude` engine on third-party Anthropic-compatible endpoints (reversing D10)

Date: 2026-10-06. Base commit: `8b11591` (the branch `wip/wave29-claude-engine` after `main` was merged into it).

## Question

Should the `claude` engine (wave 29: Claude Code headless `claude -p` as a reviewer engine, written for the Claude
subscription and the Anthropic API key, decisions D1-D12 in `handoffs/05-claude-claude-engine-decisions.md`) ALSO
carry roster entries whose endpoint is a third-party Anthropic-compatible API - z.ai GLM Coding Plan, Xiaomi MiMo
Token Plan, Kimi Code, Alibaba Model Studio, MiniMax Token Plan - through `ANTHROPIC_BASE_URL` and
`ANTHROPIC_AUTH_TOKEN` in the child environment only? If yes, what is the right shape: roster entry, reviewer
identity and lineage, preflight and health, model table, telemetry classification, lab (vendor) attribution,
concurrency? This is expensive to change later: the ledger's reviewer identity (`provider_fingerprint`,
`provider_config`) and the telemetry's closed lists are append-only contracts, the roster is validated fail-closed
(an unknown key refuses EVERY run), and a thread belongs to one engine and one endpoint for its whole life.

## Task state

- Done: the engine for `auth: subscription | api-key` (D1-D12), merged with `main` (0.5.1, R24, the first-run docs).
  `tests/harness-claude.ps1` (a fake CLI, `tests/fake-claude.ps1`) ran for the first time today: 55 passed, 0 failures (the first run failed 5 checks, all defects of the fake CLI and two checks, fixed in 55f5c0b; no engine code changed); harness-engines 97, harness-muse 74, harness-telemetry 112 passed.
- Open: this design; the A/B measurement (below, Q6); the verification plan of the new route.
- Not in scope: a direct HTTP client to any provider (the plans forbid it, ROADMAP R10); mixing engines or endpoints
  inside one lineage; Bedrock, Vertex, Foundry; making the operator's own chore skill part of the plugin.

## Evidence

- Motive. Anthropic announced that from 2026-06-15 `claude -p` and Agent SDK usage would leave the Pro/Max limits for
  a separate monthly credit (the subscription fee) with overage at API rates; the support article says the change is
  PAUSED as of today. If it goes live, the subscription route of this engine becomes API-billed in practice. A
  third-party route bills that provider's plan and never touches Anthropic: Claude Code is only the client.
- Volume. This repository's ledgers (112 consultations) through the codex engine: `ZAI :: glm-5.3` n=20, mean 17.75M
  input tokens per consultation, 90 % cached (1.74M uncached), 68.6k output, 790 s wall; `mimo :: mimo-v2.6-pro`
  n=16, 13.76M input, 68 % cached (4.35M uncached), 63.4k output, 953 s. The volume is the agentic read loop
  re-sending the context on every tool call, not a fixed system prompt. z.ai meters PROMPTS (one model call = one
  prompt of the 5-hour quota); MiMo meters credits per token with a cache discount of 2.5 vs 300 credits per input
  token (hit vs miss). A route wins only by fewer model calls (z.ai) or a better cache-hit rate (MiMo).
- R10 live check (2026-09-25, ROADMAP R10): GLM and MiMo through Claude Code headless with `--json-schema` returned
  `structured_output` on the first turn. The codex route to z.ai needs the contract-first prompt and a format-repair
  turn in part of the runs (`format_retry` in the ledgers).
- The operator already runs Claude Code on these plans for chores (a user skill outside the plugin): GLM with
  `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`, `ANTHROPIC_AUTH_TOKEN=$ZAI_API_KEY`, `API_TIMEOUT_MS=3000000`,
  `ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.3[1m]"` (z.ai's documented alias mapping) and `--model sonnet`; MiMo with
  `ANTHROPIC_BASE_URL=https://token-plan-ams.xiaomimimo.com/anthropic` and `--model mimo-v2.6-pro` (the id straight).
  Per the provider documents, Kimi Code (`https://api.moonshot.ai/anthropic`), Alibaba Model Studio
  (`https://coding-intl.dashscope.aliyuncs.com/apps/anthropic`, Token Plan
  `https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic`) and MiniMax (`https://api.minimax.io/anthropic`)
  expose the same shape. Each plan's terms allow coding tools (Claude Code named), not a generic HTTP client.
- Code (the branch): `plugins/codex-consult/scripts/codex-consult-common.ps1` - `$script:ClaudeModels` (the closed
  model table of D4; the roster validator and the telemetry's anthropic list share it), `Test-ClaudeChildEnvName` /
  `Get-ClaudeChildEnvironment` (D2: an ALLOW list; every `ANTHROPIC_*` is absent except `ANTHROPIC_API_KEY` under
  `auth: api-key`; every `CLAUDE_*` absent), `Get-ClaudeSignIn` (D3: `claude auth status` in that same environment;
  `loggedIn`, `authMethod`, `apiProvider`), `Get-ClaudeIdentityConfig` (`credential_mechanism`, `auth_method`,
  `api_provider`), the fingerprint `cc-engine-v1|claude|<auth>|<model family>` (D7: health per auth mode and family),
  `Get-ClaudeInitProblem` / `Get-ClaudeTurnOutcome` (D4: the init event's model and `modelUsage` must name the pinned
  id; `[1m]` stripped), D5 (claude members one at a time, `parallel` raises it), D10 (`ANTHROPIC_BASE_URL` routes
  out of scope). README "Engines (wave 29)"; `tests/harness-claude.ps1`.
- The codex route to the same plans exists and stays: `[model_providers.ZAI|mimo|kimi|alibaba|byteplus]` tables in
  the Codex config (OpenAI-compatible base URLs such as `https://api.z.ai/api/v1`), `env_key` names, caps-v1 rows
  per endpoint host (effort vocabulary, schema transport), the telemetry's vendor class by endpoint host. The roster
  today refuses `codex_config` and `auth` on an engine entry other than `claude`'s two auth modes.

## Alternatives weighed

1. **Keep D10** (Anthropic only through `claude`). Nothing new to carry; the plans stay on the codex route. Fails the
   operator's goal if the subscription route is billed; leaves the native-schema advantage of R10 unused for the
   plans where the codex route needs the repair turn.
2. **A third auth mode of the same engine, `auth: "endpoint"`**: the roster entry names the provider label and the
   Anthropic-flavoured endpoint, e.g. `{ "provider": "ZAI", "engine": "claude", "model": "glm-5.3", "auth":
   "endpoint", "endpoint": { "base_url": "https://api.z.ai/api/anthropic", "env_key": "ZAI_API_KEY" } }` - or the
   entry references the existing `[model_providers.<label>]` table for its `env_key` and adds only the Anthropic path.
   The child gets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN` (from the named variable, read at launch, never
   logged) and nothing else of `ANTHROPIC_*`; no `claude auth` login is required or consulted. Identity:
   `cc-engine-v1|claude|endpoint|<base_url host+path>`; `provider_config` `{engine, launcher, credential_mechanism:
   endpoint, base_url, env_key name}`; the model table is OPEN for this mode (any id, as for a codex custom
   provider); health per endpoint (and, Q3, shared with the codex route of the same plan?); telemetry: the vendor
   class and model list by endpoint host, exactly as the codex route classifies `api.z.ai`.
3. **A separate engine name `claude-compat`** on the same adapter and a caps-v1 row of its own, keeping `claude`
   pure (subscription and API key only). Clear separation in every table and in telemetry; one more engine name in
   the roster validator, the `-Engine` vocabulary, the README and the hook.
4. **Not in the roster at all**: the operator's own skill keeps running Claude Code on the plans for chores; reviews
   stay on codex. No bridge change; no ledger, no panel, no measurement.

Current preference: 2 (one engine, one adapter, a third credential mechanism), with the endpoint spelled out in the
roster entry (no implicit derivation from the OpenAI-compatible table: the Anthropic path differs per provider),
`--model <id>` sent straight (no alias mapping variables in the child), the model table open for this mode, and the
A/B of Q6 deciding whether the route is kept in the roster after the first wave.

## Questions

- **Q1.** Shape: 2, 3, or 2 with the entry referencing the codex table for `env_key`? Which identity key per
  endpoint keeps lineage, health and the roster walk correct when the same plan is reachable on two routes?
- **Q2.** Model: `--model glm-5.3` straight vs the provider's alias mapping (`--model sonnet` +
  `ANTHROPIC_DEFAULT_SONNET_MODEL`). D4 requires one resolved model per thread proven by the init event and
  `modelUsage`: what does the init event report on each variant, and what must the adapter compare against?
- **Q3.** Preflight and health: credential = the named variable set (as for a codex table) - is a cheap live probe
  worth a request? Should a usage-limit failure on `api.z.ai` through `claude` mark the codex route's `ZAI` out too
  (same plan, same quota) - one health key per plan, or per route?
- **Q4.** Child environment: the exact `ANTHROPIC_*` set to pass (`BASE_URL`, `AUTH_TOKEN`; `API_TIMEOUT_MS`?
  `ANTHROPIC_MODEL`? the `DEFAULT_*_MODEL` trio?), the rule that `ANTHROPIC_API_KEY` is ABSENT, and how to prove from
  the init event (`apiKeySource`?) that the subscription login was not used when a base URL is set.
- **Q5.** Telemetry: classify by endpoint host as the codex route does (`glm-5.3` is in the zai list), the ledger
  keeping the real names - any gap?
- **Q6.** The A/B that decides whether the route stays: the same brief through `codex exec` (ZAI) and through
  `claude -p` (z.ai Anthropic endpoint, `--tools Read,Grep,Glob`, `--json-schema`), comparing model calls, uncached
  input, first-turn structured rate, wall time and verdict quality. Which thresholds would you set (for z.ai:
  prompts; for MiMo: credits), and what sample size is honest?
- **Q7.** Concurrency: D5 runs claude members one at a time engine-wide. With endpoint entries, is the group per
  endpoint (a GLM-via-claude and an Anthropic-via-claude member at once), and does the machine-wide endpoint limit of
  the codex route (`parallel`) apply across routes to the same plan?
- **Q8.** Risks not listed here: the plans' terms for a reviewer that only reads; Claude Code flag drift across
  versions (`--restricted`, `--json-schema`, `--max-turns`) hitting a third-party endpoint differently; z.ai's alias
  mapping changing under us; the 1M-context suffix on these ids.

Answer by number. Rank the alternatives. Keep it under 700 words.
