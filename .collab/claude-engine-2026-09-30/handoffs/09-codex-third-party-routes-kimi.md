# Handoff 09 - Codex: third-party-routes-kimi

Date: 2026-10-06 20:56 local. Author: Codex (model k3, effort high), Codex CLI 0.155.1.
Reviewer: kimi :: k3 (provider from roster, model from roster; endpoint https://api.kimi.ai/coding/v1, wire_api: responses; provider fingerprint 8f7901d404b5; harness codex-cli 0.155.1).
Preflight: ok: env KIMI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 8 of 10, panel 6a852ab7 member 3 of 4.
Effort: high sent (requested high, mapping kimi-v1, by caps-v1: api.kimi.ai, k3; not confirmed by the provider). Consultation id: f5667b8c-95a2-46ab-a06d-1fd66d7317ae.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: decision). Argv: `codex exec --sandbox read-only --color never --json -m k3 -c model_reasoning_effort="high" -c model_provider="kimi" -c model_context_window=256000 -c model_auto_compact_token_limit=204800 -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-e690cd6a37454fa68ebbdef42d03a42a.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage kimi :: k3 in this task's ledger; other lineage(s): gemini :: gemini-3.1-pro-high [agy], openai :: gpt-6-astra, meta :: muse-spark-1.3-contributor [muse]). Result thread: `01a11292-c8dc-7bd0-bf36-119c61f7a248` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md` (sha256 6dc51ced0b13). Reviewed: 8b11591, base 8b115918d16f4d56f0e630b89984ce1e18322bbc, tree sha256 60b1ad75f290, 0 changed files.
Bridge outcome: usable reply. Wall time: 397.8 s. Tokens: in 362446 (cached 246784), out 9119, reasoning 4907.
Timeout: 1800 s (the default of purpose decision); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Adopt alternative 2 (a third credential mechanism `endpoint` of the claude engine with the endpoint spelled out in the roster entry), gated on the billing-attribution probe and four engine-keyed table fixes named below. Findings: 0 blocker, 3 major, 1 minor, 0 note (F09-1..F09-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/09-codex-third-party-routes-kimi.reply.json`.
Raw event stream: `handoffs/09-codex-third-party-routes-kimi.events.jsonl`.
Verbatim reply follows.

---

## Ranking
1. **Alt 2** - one engine, third credential mechanism, endpoint explicit in the entry. Deciding factor: the adapter, argv and the thread-endpoint invariant already exist; only the credential source and engine-keyed closed tables change. Failure mode: every `engine = claude` lookup assumes Anthropic (telemetry vendor, coordinator match, model table, apiKeySource check); one missed branch silently mislabels lineage and telemetry.
2. **Alt 3** - separate `claude-compat`. Deciding factor: cleanest closed-list separation. Failure mode: doubles the vocabulary surface (roster validator, `-Engine`, README, hook, caps rows) without new capability; lineage still needs a shared endpoint key across engines.
3. **Alt 1** - keep D10. Deciding factor: zero contract change. Failure mode: if Anthropic unpauses the credit split the subscription route becomes API-billed and R10's first-turn schema advantage for the plans is never harvested; codex keeps paying repair turns.
4. **Alt 4** - nothing in the roster. Failure mode: no ledger, no A/B data; the decision can never be revisited on evidence.

**Q1.** Shape 2, endpoint spelled out in the roster entry (no derivation from the codex table: the Anthropic path differs per provider; reusing only the `env_key` name is fine). Identity: fingerprint `cc-engine-v1|claude|endpoint|<host+path>`; lineage carries engine+auth+base_url so ZAI-via-codex and ZAI-via-claude are distinct reviewers of one plan. `endpoint` appends to `$script:ClaudeAuthModes`; the roster stays fail-closed.

**Q2.** Send `--model glm-5.3` straight, never the alias mapping. D4 pins one resolved model per thread proven by init.model and `modelUsage`; the alias variant pins `sonnet` while the provider serves `glm-5.3`, so the proof is unenforceable and z.ai can re-point the mapping under you. The adapter compares init.model and the main `modelUsage` key against the roster id verbatim (finding #3, RC2).

**Q3.** Credential check = the named variable is set; no live probe - on z.ai one probe costs one prompt of the 5-hour quota. Health per route, not per plan: key `claude/endpoint/<host>/<model>`. A usage-limit rejection through claude is also evidence about that route's shape (flags, schema), so it must not mark the codex `ZAI` entry out; at most de-prioritise the sibling route when the rejection is provably plan-level.

**Q4.** Pass exactly `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `API_TIMEOUT_MS` (operator evidence: slow plans need it). Absent: `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, the `DEFAULT_*_MODEL` trio, everything else. Proof the subscription was not billed: init `apiKeySource` must equal the auth-token source; what the CLI reports with a base URL plus a stored OAuth login is unknown (finding #3) - until RC1 observes it, fail closed on any value that is not the auth-token source.

**Q5.** Classify by endpoint host as codex does - but two gaps (findings #1, #4): `Get-TelemetryVendor` short-circuits non-codex engines to the engine-keyed row before host matching, so endpoint turns read `anthropic`; and `[1m]` is stripped only for class anthropic, so `glm-5.3[1m]` buckets `other` under zai. `glm-5.3`/`mimo-v2.6-pro` already sit in the zai/xiaomi lists; the ledger keeps real names regardless.

**Q6.** Paired A/B, same briefs through both routes. z.ai: keep if prompts/consultation <= the codex-route mean (n=20 baseline) AND first-turn structured rate >= 95% vs the codex route's observed `format_retry` share. MiMo: keep if credits/consultation (2.5 vs 300 hit/miss) <= parity with the codex 68%-cache baseline at equal verdict quality. Honest n: >=12 paired briefs (24 runs); smaller samples detect only huge effects - report them as anecdote, not decision.

**Q7.** Concurrency group = endpoint host, not engine-wide: GLM-via-claude and Anthropic-via-claude may run together (P7). The plan is one quota across routes: effective parallelism per plan = min over its routes' `parallel`, keyed per endpoint host and shared with the codex route.

**Q8.** Added risks: plan terms name Claude Code but meter the agentic read loop (17.75M input tokens/consultation - a reviewer's cost profile dwarfs chores); flag drift - pin the CLI version per endpoint in the caps-v1 row and re-run the R10 probes on upgrade; forbid `[1m]` in endpoint roster ids (finding #4); Claude Code may prefer a stored OAuth login over `ANTHROPIC_AUTH_TOKEN` (finding #3) - the init proof is load-bearing.

## Requested checks
- RC1: cwd scratch; workspace-write (network + real credentials). Run `claude -p` against z.ai with `ANTHROPIC_BASE_URL`+`ANTHROPIC_AUTH_TOKEN` set AND a live subscription login in `CLAUDE_CONFIG_DIR`; capture the init event's `apiKeySource` and `model`. Settles finding #3. Budget: one prompt.
- RC2: same setup; two runs, `--model glm-5.3` vs `--model sonnet` + `ANTHROPIC_DEFAULT_SONNET_MODEL`; diff init.model and `modelUsage` keys. Settles Q2. Budget: two prompts.
- RC3: cwd repo root; read-only. Extend `tests/fake-claude.ps1` to emit `apiKeySource: "ANTHROPIC_AUTH_TOKEN"` plus a mismatched value and assert the adapter accepts one and classes the other `auth`. Settles the validator shape before the real route exists. Budget: 30 min.

---

### Findings

- **F09-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:10700`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10398` - Get-TelemetryVendor short-circuits any non-codex engine to the engine-keyed vendor row before endpoint-host matching, so a claude reviewer on a third-party Anthropic-compatible endpoint (auth: endpoint) would classify as provider anthropic and its model (e.g. glm-5.3) would bucket `other` against the ClaudeModels list instead of zai/glm-5.3. Trigger: Alternative 2 is adopted and a consultation runs with engine claude on https://api.z.ai/api/anthropic. Evidence: read-code: For engine != codex the function returns the row whose Engine equals the engine name (anthropic for claude); host matching on provider_config.base_url happens only for the codex engine. Verify: After adding the endpoint mode, build a ledger-shaped reviewer object {engine: claude, provider_config.base_url: https://api.z.ai/api/anthropic, model: glm-5.3} and assert Get-TelemetryReviewerClass returns provider zai, model glm-5.3. Remedy: For the claude engine, resolve the vendor from provider_config.base_url host first (as for codex); fall back to the anthropic engine row only when no base_url is recorded.
- **F09-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:7015` - Get-CoordinatorMatch hardcodes that a claude-engine reviewer's vendor is anthropic (coordinator provider must equal 'anthropic', models compared via Test-ClaudeModelMatch); a coordinator running GLM through Claude Code can never be recognised as 'own'/'provider' relative to a GLM-via-claude reviewer, and an Anthropic coordinator compared against glm-5.3 silently falls to no-match. Trigger: A Claude Code coordinator on a third-party plan (CODEX_CONSULT_COORDINATOR="zai :: glm-5.3") panels a claude-endpoint reviewer of the same plan. Evidence: read-code: The claude branch requires the coordinator provider to equal anthropic and uses Test-ClaudeModelMatch, which only knows claude-* ids and the four Anthropic aliases. Verify: Unit-test Get-CoordinatorMatch with coordinator 'zai :: glm-5.3' against reviewer {engine claude, model glm-5.3, base_url api.z.ai}; require 'own'. Remedy: When the reviewer carries an endpoint base_url, compare coordinator provider and model against the endpoint host's vendor class and the raw model id instead of the anthropic branch.
- **F09-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:4886` - Billing attribution for the endpoint mode is unverified: the adapter's auth check knows apiKeySource 'none' (subscription) and 'ANTHROPIC_API_KEY' (api-key), but what the init event reports when ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN are set alongside a stored OAuth login is unknown - if the CLI prefers the login, endpoint turns silently bill the Anthropic subscription, reversing the route's purpose. Trigger: A machine with an active claude.ai login runs an endpoint roster entry. Evidence: read-code: The apiKeySource comparison has only the two Anthropic credential shapes; no branch covers ANTHROPIC_AUTH_TOKEN.; assumed: Not checked which credential wins when both an OAuth login and ANTHROPIC_AUTH_TOKEN are present. Verify: RC1: run claude -p against z.ai with base_url+token and a live login in CLAUDE_CONFIG_DIR; require init apiKeySource to name the auth-token source. Remedy: Extend the check: endpoint mode requires apiKeySource to equal the observed auth-token value and fails closed (class auth) on 'none', 'ANTHROPIC_API_KEY' or any unknown value.
- **F09-4** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:10730` - The [1m] suffix is stripped only for vendor class anthropic, but z.ai documents the alias 'glm-5.3[1m]'; if such an id ever reaches telemetry under class zai it buckets 'other', and the roster's open endpoint table has no stated rule for the suffix. Trigger: An operator copies z.ai's documented 'glm-5.3[1m]' into an endpoint roster entry. Evidence: read-code: `if ($Vendor.Class -ceq 'anthropic') { $m = $m -replace '\[1m\]$', '' }` - other classes compare the name verbatim. Verify: Unit-test Get-TelemetryModelToken with vendor zai and model 'glm-5.3[1m]'; require glm-5.3. Remedy: State in the endpoint contract that roster ids are sent verbatim and [1m] is forbidden on endpoint entries; strip the suffix per vendor (zai) in telemetry as defence.

### Prior findings

- F02-1 - fixed - D1 (handoff 05): strict tree check fails the run on any change; WriteDisabled stays false; init_tools kept as evidence.
- F02-2 - fixed - D2: ALLOW-list child environment, verified in code (Get-ClaudeChildEnvironment / Test-ClaudeChildEnvName).
- F02-3 - fixed - D4: one shared $script:ClaudeModels table for validator and telemetry, [1m] stripped, alias float pinned per thread via init + modelUsage - seen in code.
- F02-4 - fixed - D5 + probe P7: engine parallel limit 1 by default; two concurrent runs observed working, documented as observed-not-guaranteed.
- F02-5 - fixed - D6 + probes P1/P6: denial taxonomy, quota classes, resume-after-kill semantics defined.
- F03-1 - fixed - Same fix as F02-1 (D1 strict tree check).
- F03-2 - fixed - D2 allow list removes inherited gateway routing and competing credentials; ANTHROPIC_API_KEY only under auth api-key - seen in code.
- F03-3 - fixed - D3: preflight builds the same child environment as a turn (Invoke-ClaudeProbe uses Get-ClaudeChildEnvironment) - seen in code.
- F03-4 - fixed - D2: every CLAUDE_* variable absent from the child, including CLAUDE_CODE_SKIP_PROMPT_HISTORY.
- F03-5 - fixed - D2: CLAUDE_CODE_EFFORT_LEVEL absent from the child environment.
- F03-6 - fixed - D4: per-turn proof via init model and modelUsage main key, class capability on mismatch - matching helpers seen in code.
- F03-7 - fixed - D7: health key engine + auth mode + model family (claude/subscription/opus).
- F03-8 - fixed - D8 + probe P2: --max-turns accepted (exit 0) despite absence from --help; MaxModelSteps maps to it.
- F03-9 - fixed - D3: JSON read before exit code; loggedIn:false => out regardless of exit code.
- F04-1 - fixed - D5 serialisation plus P7 evidence; same as F02-4.
- F04-2 - fixed - D6 + probe P6: hard-killed session resumes with the same session_id and a usable structured reply.

## Verdict: ADVISE

Adopt alternative 2 (a third credential mechanism `endpoint` of the claude engine with the endpoint spelled out in the roster entry), gated on the billing-attribution probe and four engine-keyed table fixes named below.

### Blockers

_(none)_

### Unproven scenarios

- What claude init reports (apiKeySource, model) with ANTHROPIC_BASE_URL+ANTHROPIC_AUTH_TOKEN set, with and without a stored OAuth login - RC1/RC2.
- Whether third-party endpoints accept --max-turns, --json-schema and --restricted identically to api.anthropic.com across CLI versions.
- Whether a usage-limit rejection on one route of a plan implies the sibling route is also exhausted (plan-level vs route-level accounting).
- Verdict-quality parity of the two routes - the Q6 A/B has not run.

### First-run checklist (observable)

_(none)_
