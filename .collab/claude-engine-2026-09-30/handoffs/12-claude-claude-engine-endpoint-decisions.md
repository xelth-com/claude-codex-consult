# The `claude` engine on third-party Anthropic-compatible endpoints - decisions after the panel (handoffs 07-11)

Panel of 4 on handoff 06 (2026-10-06, detach 8ea7b0af, 1807 s): 07 gpt-6-astra ADVISE, 08 glm-5.3 via codex ADVISE,
09 kimi-k3 ADVISE, 10 mimo-v2.6-pro ADVISE; plus 11 glm-5.3 via Claude Code headless (the route under decision,
run by hand). Ranking: alternative 2 first for 07, 09, 10, 11; alternative 3 first for 08. The coordinator is the
judge; D1-D12 of handoff 05 stand where not amended here. D10 is REVERSED by E1.

Probes run by the coordinator after the panel (2026-10-06, Claude Code 2.1.291, Windows; outputs under the
coordinator's scratch directory, `probes/`):

P8.  `--model glm-5.3` straight against `https://api.z.ai/api/anthropic` with `ANTHROPIC_AUTH_TOKEN` (subscription
     login present on the machine): init `model=glm-5.3`, `apiKeySource=none`, `permissionMode=dontAsk`; result
     `modelUsage` has the one key `glm-5.3` (`canonicalModel glm-5.3`, `provider firstParty`). stderr:
     `[claude-code:unrecognized_model] {"model":"glm-5.3"}` - a notice, not a failure.
P9.  The alias variant (`--model sonnet` + `ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5.3`): init `model=glm-5.3` too -
     the CLI resolves the alias before the init event. Same `modelUsage`.
P10. `--model mimo-v2.6-pro` against `https://token-plan-ams.xiaomimimo.com/anthropic`: init and `modelUsage`
     `mimo-v2.6-pro`, `apiKeySource=none`.
P11. A wrong token against z.ai: `result` `subtype success`, `is_error true`, text `Failed to authenticate. API
     Error: 401 ...`, no `modelUsage`, exit 1 - NO fallback to the subscription login; the CLI retried for 187 s
     before giving up.
P12. `claude auth status` with `ANTHROPIC_BASE_URL` and the token set: `loggedIn true, authMethod oauth_token,
     apiProvider firstParty` in 2 s - it reads the local login and ignores the base URL; it proves nothing about
     an endpoint route.
P13. The A/B pair on handoff 06 (same brief, glm-5.3): codex route 34 model calls, 2.33M input (157k uncached),
     19.5k output, 687 s; Claude Code route 24 calls, 466k input (57k uncached), 19.4k output, 351 s; both
     structured on the first turn. z.ai credits by its published formula (GLM-5.3: 6.9 input, 1.7 cached, 24
     output per 10,000 tokens): ~524 vs ~155.

Corrections to handoff 06 accepted from the panel: z.ai meters TOKEN-WEIGHTED CREDITS (5-hour and weekly
pools, multipliers per model), not prompts (07 #1; verified on docs.z.ai/devpack/overview). Kimi Code's
Anthropic endpoint is `https://api.kimi.ai/coding/` (overseas; `api.kimi.com/coding/` domestic), models
`k3`, `k3-256k`, `kimi-for-coding`; `api.moonshot.ai` is the pay-as-you-go platform, a different product
(07 #2; verified on kimi.com/code/docs). Alibaba's Coding Plan and Token Plan are "for interactive AI coding
tools (Claude Code, Codex) only - not for backend services" (07 #6; verified on the base-url page).

Decisions:

E1. **Alternative 2: a third credential mechanism of the `claude` engine, `auth: "endpoint"`**, the endpoint
    spelled out in the roster entry, never derived from a Codex `[model_providers]` table (the Anthropic path
    differs per provider). Entry shape:
    `{ "provider": "ZAI-claude", "engine": "claude", "model": "glm-5.3", "auth": "endpoint",
       "endpoint": { "base_url": "https://api.z.ai/api/anthropic", "env_key": "ZAI_API_KEY", "timeout_ms": 3000000 },
       "plan": "zai" }`.
    `endpoint` is REQUIRED with `auth: endpoint` and REFUSED with the other two modes; `base_url` must be an
    absolute https URL (a wrong shape refuses the roster, fail-closed as every roster error); `env_key` the NAME
    of a variable (`^[A-Z][A-Z0-9_]{2,}$`); `timeout_ms` optional, default 3000000, 60000..7200000. The
    provider label is the operator's and distinct per route (the validator's "one label names one engine" and
    "one (provider, model) once" rules stand unchanged - `ZAI` stays the codex entry, `ZAI-claude` the endpoint
    entry). Alternative 3 (`claude-compat`) is rejected: one adapter, one engine name; every `engine -eq
    'claude'` lookup becomes mode-aware instead (E5, E6).
E2. **The model goes straight: `--model <id>`**, the id as the provider publishes it, optionally `[1m]`. For
    `auth: endpoint` the closed table `$script:ClaudeModels` does NOT apply; the id must match
    `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}(\[1m\])?$`. No alias mapping variable (`ANTHROPIC_MODEL`,
    `ANTHROPIC_DEFAULT_*_MODEL`, `ANTHROPIC_SMALL_FAST_MODEL`) ever reaches the child (P9 shows the alias
    variant works, but it smuggles a model override into the child, which D2 forbids). D4's proof stands:
    the init event's `model` and the main `modelUsage` key must equal the pinned id after the `[1m]` strip
    (P8, P10), else class `capability`.
E3. **Preflight is local**: the launcher is found, `endpoint.base_url` parses, the variable `env_key` names is
    set and non-empty (the credential result `ok: env <NAME> set`, as for a codex table; never the value).
    NO `claude auth status` for this mode (P12: it ignores the base URL) and NO live request (it spends the
    plan's credits). The billing proof per turn: `apiKeySource` is `none` on this route too (P8, P10), so it
    proves nothing - the proof is `init.model == pinned id` (a subscription turn cannot serve `glm-5.3`) plus
    the ledger's `child_env_allowed` names (`ANTHROPIC_AUTH_TOKEN` present, `ANTHROPIC_API_KEY` absent).
    `apiKeySource` is recorded raw; a value `ANTHROPIC_API_KEY` on an endpoint turn FAILS the turn (class
    `auth`: a competing credential reached the child).
E4. **Child environment** (D2's allow list plus, for this mode only): `ANTHROPIC_BASE_URL` = `endpoint.base_url`,
    `ANTHROPIC_AUTH_TOKEN` = the value of the variable `env_key` names, read at launch, never logged;
    `API_TIMEOUT_MS` = `endpoint.timeout_ms`. `ANTHROPIC_API_KEY` is absent (precedence) - also under this
    mode's preflight. `child_env_allowed` lists the names. A 401/403 on this route is class `auth` (P11's text
    `Failed to authenticate` / `API Error: 401` joins the regexes); a 429 whose text matches no Anthropic quota
    wording is class `quota` when the status is 429, else `unknown`, the raw text kept in
    `engine_run.rate_limit` as today (07 #7, 10 #8 - extend after first sightings).
E5. **Two identities.** The ROUTE identity (lineage, parenting, the health of auth, transport and capability
    failures): fingerprint `SHA-256("cc-engine-v1|claude|endpoint|<canonical base_url>|<env_key name>")`,
    canonical = lower-case scheme and host, the explicit port if any, the path without a trailing slash;
    `provider_config` `{engine, launcher, credential_mechanism: "endpoint", base_url, env_key, plan}` (the
    base_url is not a secret; the token never appears). Health key `claude/endpoint/<host>`. The lab of an
    endpoint entry comes from the telemetry vendor table by HOST (`api.z.ai` -> zhipu, `xiaomimimo.com` ->
    xiaomi, `api.kimi.ai` -> moonshot), never hardcoded `anthropic`; `Get-CoordinatorMatch` compares an
    endpoint entry as it compares a codex entry (label and model), the hardcoded anthropic branch applies to
    `subscription` and `api-key` only (09 #2). The PLAN identity (quota): the optional entry key `plan`
    (`^[a-z][a-z0-9-]{1,31}$`), allowed on every entry of every engine. A QUOTA-class failure (usage limit,
    429 with a window) recorded on any entry marks every entry with the same `plan` out for the same reset
    time (the roster walk and `codex-providers.ps1` show `out: plan <slug> (usage limit on <label> until ...)`);
    auth, transport and capability failures stay route-local. Without `plan` nothing propagates (today's
    behaviour).
E6. **Telemetry**: `Get-TelemetryVendor` classifies by `provider_config.base_url` HOST FIRST whenever the entry
    has one, the engine row only as the fallback; the `[1m]` strip applies to every vendor's model token; a row
    for MiniMax (`api.minimax.io`, `api.minimax.cn`; the published id `MiniMax-M3`) is added; `glm-5.3` and
    `mimo-v2.6-pro` already sit in the zai and xiaomi lists. The ledger keeps the real label, id and base URL;
    the event never carries the URL, the label or the key name - exactly as today for codex tables.
E7. **Concurrency**: claude members keep ONE engine-wide scheduling group by default (D5: shared `~/.claude`
    state; the roster's `parallel` on a label raises it, two at once observed to work - P7). In addition every
    `plan` is a scheduling group across engines: a `ZAI`-via-codex member and a `ZAI-claude` member serialize
    (the existing group merge by shared keys: the member's key set gains `plan:<slug>`), raised by
    `"parallel": {"<plan slug>": n}`.
E8. **The route stays in the roster only on evidence** (wave 29c, after the operator's go): paired, order-
    randomised runs of the same briefs through both routes, at least 12 pairs per provider; z.ai measured in
    its credits (6.9/1.7/24 for GLM-5.3), MiMo in its credits (300 miss, 2.5 hit, 600 output per token);
    keep the route when the median credits are at most 0.8x the codex route AND the first-turn structured
    rate is not lower AND the median wall time is at most 1.25x AND the blind `-Rate` marks are not worse.
    P13 is ONE pair (anecdote: credits 0.30x, wall 0.51x, both structured).
E9. **Terms**: the engine ships with z.ai and MiMo as the documented examples (both name Claude Code; the
    operator decides whether a read-only reviewer is within their plan's terms and records that decision in
    `state.md`); Kimi Code with its `api.kimi.ai/coding/` endpoint as a third; Alibaba's plans are NOT
    documented for this route ("interactive ... only - not for backend services" - and the same wording
    applies to the codex route: TECH_DEBT); MiniMax documented as "shape known, not run".
E10. **Scope of wave 29b** (this implementation): E1-E7 in the common script, the roster validator, the dry
    run, `codex-providers.ps1`, the hook line; `tests/fake-claude.ps1` learns the endpoint mode (reads
    `ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN`, emits the init model = `--model`, `apiKeySource none`, a 401
    when `FAKE_CLAUDE_TOKEN_EXPECT` mismatches); `tests/harness-claude.ps1` gains an ENDPOINT category (roster
    shapes accepted and refused, the child environment exact, the preflight without auth status, identity
    and health keys, plan propagation, telemetry host-first, the panel plan group, the dry-run lines);
    README "Engines (wave 29)" + the roster table + the first-run prompt and setup-providers step 0 / 3g
    (endpoint route per plan, Kimi Code endpoint, the Alibaba terms note); CHANGELOG Unreleased. The live
    A/B run book is wave 29c.
