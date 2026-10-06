# Handoff 08 - Codex: third-party-routes-zai

Date: 2026-10-06 20:56 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 2 of 10, panel 6a852ab7 member 2 of 4.
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 8ca7b54c-efff-4ebb-b5c7-9192cb7f77a0.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: decision). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-1d7e6828024b4fb19c9ef74779d9024a.md --output-schema C:\Users\Dmytro\.claude\plugins\cache\claude-codex-consult\codex-consult\0.5.1\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage ZAI :: glm-5.3 in this task's ledger; other lineage(s): gemini :: gemini-3.1-pro-high [agy], openai :: gpt-6-astra, meta :: muse-spark-1.3-contributor [muse]). Result thread: `01a11292-c6fa-73a0-b398-06a62a1cd691` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md` (sha256 6dc51ced0b13). Reviewed: 8b11591, base 8b115918d16f4d56f0e630b89984ce1e18322bbc, tree sha256 60b1ad75f290, 0 changed files.
Bridge outcome: usable reply. Wall time: 686.7 s. Tokens: in 2328668 (cached 2172032), out 19542, reasoning 11619.
Timeout: 1800 s (the default of purpose decision); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The route is plausible, but it should be a separate compatible engine and must first close credential-proof, plan-health, telemetry and measurement contracts. Findings: 1 blocker, 4 major, 1 minor, 0 note (F08-1..F08-6, tracked in `findings.json`). Structured reply: `handoffs/08-codex-third-party-routes-zai.reply.json`.
Raw event stream: `handoffs/08-codex-third-party-routes-zai.events.jsonl`.
Verbatim reply follows.

---

## Decision
Rank: **3 > 2 with an explicit endpoint > 1 > 4**.

- **3, `claude-compat`** — deciding factor: durable semantic isolation of an append-only engine contract. Failure mode: duplicated engine vocabulary or divergent copies of the same adapter.
- **2, explicit endpoint** — deciding factor: one adapter and no new engine name. Failure mode: contaminates `claude`’s Anthropic-only model, telemetry, auth and capability invariants.
- **1, keep D10** — deciding factor: zero new contract risk. Failure mode: forfeits the observed first-turn native-schema advantage and billing hedge.
- **4, outside roster** — deciding factor: no bridge change. Failure mode: ungoverned usage, no lineage, health, telemetry or comparable A/B.

**Q1.** Choose 3, with an explicit endpoint object; do not derive it from the OpenAI-compatible Codex table. Use route labels such as `ZAI` and `ZAI_CLAUDE`, but record an operator-defined `plan_id`. Route fingerprint: `cc-engine-v1|claude-compat|<canonical scheme+host+path>`; `provider_config` records engine, launcher, `credential_mechanism: env-token`, canonical base URL, env-key name and `plan_id`—never the token. This keeps lineage route-specific while quota/scheduling can merge on plan.

**Q2.** Send the provider id straight: `--model glm-5.3`; do not pass `ANTHROPIC_MODEL` or `DEFAULT_*_MODEL`. What init reports for straight versus alias mapping is unmeasured. Compare roster id against every init model and the main `modelUsage` key after only the explicitly supported `[1m]` normalization; alias-to-provider-id fuzzy matching must fail closed.

**Q3.** Preflight locally: URL parses, env variable is nonempty, launcher/version known. No live probe in the roster walk; it spends quota and proves little. A manual one-request capability probe per CLI/endpoint is useful. Keep health route-specific for auth/transport/capability, but propagate only quota-class failures through `plan_id` so z.ai exhaustion marks both routes; do not propagate route-specific failures.

**Q4.** Set exactly `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` from the named variable, plus existing system/proxy allowlist entries. `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, the `DEFAULT_*` trio and every inherited `ANTHROPIC_*`/`CLAUDE*` must be absent. Add `API_TIMEOUT_MS` only as a validated endpoint field, not inherited. Subscription non-use is proven only if captured init/request evidence identifies the token route; `apiKeySource: none` is insufficient.

**Q5.** Yes: classify from endpoint host, with the ledger retaining real provider/model/id. Current code cannot: non-codex engine classification precedes base URL, and `[1m]` is stripped only for Anthropic. Add all documented hosts and closed model lists before release.

**Q6.** Paired, randomized, same brief/model/CLI version; at least 12 pairs, preferably 16; fewer is anecdote. z.ai: keep only at ≤0.90× codex prompts/consultation, ≥95% first-turn structured rate, noninferior blind verdict quality and ≤1.25× wall time. MiMo: keep only at ≤0.90× provider-reported credits/consultation with the same quality/time gates. Use provider quota deltas or a local recorder for call counts; CLI usage alone does not count z.ai prompts.

**Q7.** Keep all Claude-compatible children serialized engine-wide unless each route gets an isolated config directory; shared `~/.claude` state remains the hazard. The machine-wide plan limit must apply across Codex and Claude routes through the same `plan_id`; current fingerprint grouping cannot do that.

**Q8.** Also audit: provider terms for automated review and data retention; CLI flag/event drift pinned by version; third-party quota/error schemas; alias and `[1m]` semantics; credential precedence; account sharing with chores; canonical URL aliases; and model-specific limits.

## Requested checks
- **RC1** From repo root, run Claude Code against a local Anthropic-compatible recorder with base URL/token and a logged-in scratch config; capture request headers, init and result (workspace-write, 15 min). Observation settles Q4 and finding #4.
- **RC2** Run the existing R10 probe twice—straight id versus alias mapping—and save streams (workspace-write, 2 model calls). Observation settles Q2.

---

### Findings

- **F08-1** [major] `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:77`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10701` - Alternative 2 cannot deliver endpoint-host telemetry under the current classifier: a non-codex engine is mapped to its engine vendor before provider_config.base_url is read, so GLM through engine claude would emit provider anthropic and model other. Trigger: Commit a z.ai endpoint run under engine claude with the proposed provider_config.base_url. Evidence: read-code: Get-TelemetryVendor returns the engine-mapped row immediately for every engine other than codex and never reaches base-url host matching.; read-code: z.ai models are in the zai host-based row, while engine claude is bound to the anthropic row and its closed Claude model table. Verify: Call Get-TelemetryVendor with engine claude and base_url https://api.z.ai/api/anthropic; it must return zai, not anthropy. Remedy: Use a separate claude-compat engine with host classification, or make an explicit endpoint base_url take precedence over the engine vendor row.
- **F08-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:10725`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:43` - Telemetry strips the 1M-context suffix only for the anthropic vendor, so a z.ai model such as glm-5.3[1m] would classify as other even after host classification is fixed. Trigger: Send glm-5.3[1m] through the z.ai Anthropic endpoint and telemetry-classify it as zai. Evidence: read-code: The [1m] suffix is removed only when Vendor.Class is exactly anthropic.; read-code: The operator’s documented z.ai mapping uses glm-5.3[1m]. Verify: Unit-test Get-TelemetryModelToken with the zai row and glm-5.3[1m]; it must return glm-5.3. Remedy: Move suffix normalization to the endpoint/vendor capability row, or disallow suffixes not explicitly listed for that vendor.
- **F08-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:7281`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8284`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8314` - The roster and scheduling model cannot represent one plan on two routes: a provider label may name only one engine, and endpoint groups merge only by provider fingerprint, with no plan-level alias. Trigger: Add ZAI through codex and ZAI through claude or claude-compat and expect a shared quota or parallel limit. Evidence: read-code: The roster rejects one provider label used by two engines and identifies duplicate reviewers only by label plus model.; read-code: Get-EndpointGroups starts from labels and merges labels only when they share a fingerprint; no plan identifier exists. Verify: Create route-specific labels for one plan, force a quota failure on one route, and inspect Get-EndpointGroups plus health selection for the other. Remedy: Use distinct route labels and add provider_config.plan_id; merge quota-class health and machine-wide scheduling by plan_id independently of fingerprint.
- **F08-4** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:4496`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4888`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:73` - Endpoint credential semantics are neither implemented nor proven: current preflight still expects Claude sign-in/API-key state, and per-turn proof accepts only apiKeySource none or ANTHROPIC_API_KEY, not an AUTH_TOKEN/base-URL route. Trigger: Launch an endpoint entry while a subscription login exists in CLAUDE_CONFIG_DIR and ANTHROPIC_AUTH_TOKEN plus ANTHROPIC_BASE_URL are set. Evidence: read-code: Get-ClaudeSignIn runs auth status and accepts only subscription or API-key modes.; read-code: Get-ClaudeInitProblem accepts only none or ANTHROPIC_API_KEY as apiKeySource.; read-code: The current allowlist has no endpoint auth mode and excludes base URL and auth token. Verify: Run the real CLI against a local Anthropic-compatible recorder with token/base-url environment and a signed-in config; capture init apiKeySource and the Authorization header. Remedy: Implement endpoint-specific local preflight and require per-turn evidence that the named token and base URL were used; fail closed if the stream cannot prove it.
- **F08-5** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:4823`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4852`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:36` - The Claude event fields currently captured do not measure z.ai’s billed unit: num_turns, aggregate usage and modelUsage do not report the number of model calls/prompts, so the proposed A/B cannot decide from CLI output alone. Trigger: Two routes make different numbers of API calls while producing the same num_turns and aggregate token totals. Evidence: read-code: The parser records num_turns, aggregate usage and modelUsage keys, but no API-call count.; read-code: z.ai meters one model call as one quota prompt. Verify: Run one controlled consultation while recording provider-dashboard prompt delta and compare it with the CLI result fields. Remedy: Use provider-reported prompt/credit deltas or a local recorder as the A/B cost metric; store the count as local engine_run evidence without expanding telemetry secrets.
- **F08-6** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:4381`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:43` - The proposed endpoint environment omits API_TIMEOUT_MS even though the operator’s working z.ai setup sets it, so long provider calls may hit the CLI default or tempt operators into global environment changes. Trigger: An endpoint model call exceeds Claude Code’s default API timeout while the child allowlist contains only base URL and token. Evidence: read-code: API_TIMEOUT_MS is not on the Claude child allowlist or set list.; read-code: The operator’s known-good GLM route sets API_TIMEOUT_MS=3000000. Verify: Use a local delayed Anthropic-compatible endpoint and compare turns with and without a bounded API_TIMEOUT_MS. Remedy: Add an endpoint-level timeout_ms field, set API_TIMEOUT_MS only from it, and bound it by the bridge turn timeout.

### Prior findings

- F02-1 - fixed - WriteDisabled is false and the strict tree check fails changes; managed-hook non-guarantee is documented.
- F02-2 - fixed - The claude child now uses a case-insensitive allowlist, not an incomplete scrub list.
- F02-3 - fixed - Roster and telemetry share the Claude model table and normalize [1m]; live alias drift remains a future risk.
- F02-4 - fixed - Claude panel members are serialized engine-wide by ParallelScope engine; two-run probe P7 passed.
- F02-5 - still-open - Denial and resume were probed, but the exact rate-limit payload remains defensively parsed and the true stdin ceiling is unknown.
- F03-1 - fixed - Init evidence no longer claims hooks cannot write; tree changes fail.
- F03-2 - fixed - The allowlist removes inherited routing and competing Anthropic credentials for the current two auth modes.
- F03-3 - fixed - One child-environment builder serves preflight, version probe and turns.
- F03-4 - fixed - CLAUDE_CODE_SKIP_PROMPT_HISTORY cannot pass to the child.
- F03-5 - fixed - CLAUDE_CODE_EFFORT_LEVEL cannot override the requested effort.
- F03-6 - fixed - All init models and the main modelUsage model are checked; other assistant models are warned.
- F03-7 - fixed - Health fingerprints include auth mode and model family for the existing engine.
- F03-8 - fixed - --max-turns was observed and MaxModelSteps maps to it.
- F03-9 - fixed - loggedIn false is classified before the nonzero exit code.
- F04-1 - fixed - Default serialization addresses the defect; concurrency is observed, not guaranteed.
- F04-2 - fixed - Probe P6 resumed a hard-killed open session successfully.

## Verdict: ADVISE

The route is plausible, but it should be a separate compatible engine and must first close credential-proof, plan-health, telemetry and measurement contracts.

### Blockers

- **F08-4** `plugins/codex-consult/scripts/codex-consult-common.ps1:4496`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4888`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:73` - Endpoint credential semantics are neither implemented nor proven: current preflight still expects Claude sign-in/API-key state, and per-turn proof accepts only apiKeySource none or ANTHROPIC_API_KEY, not an AUTH_TOKEN/base-URL route. Verify: Run the real CLI against a local Anthropic-compatible recorder with token/base-url environment and a signed-in config; capture init apiKeySource and the Authorization header. Remedy: Implement endpoint-specific local preflight and require per-turn evidence that the named token and base URL were used; fail closed if the stream cannot prove it.

### Unproven scenarios

- Actual init.model, apiKeySource and request authentication for straight-id and alias endpoint variants.
- Real provider quota/error payloads and whether every listed plan shares limits across routes.
- Whether API_TIMEOUT_MS is required for long z.ai or MiMo calls.
- The proposed A/B cost and quality results.
- Endpoint-entry concurrency safety without isolated Claude configuration directories.
- Provider terms for automated reviewer use and data retention.

### First-run checklist (observable)

_(none)_
