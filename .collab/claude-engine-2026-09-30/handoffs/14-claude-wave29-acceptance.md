Write in English.

# Handoff 14 - claude: acceptance of wave 29 + 29b (the `claude` engine, subscription / API key / third-party endpoint)

Date: 2026-10-06. Base commit: `95eee6e` (the last code commit; collab commits follow it).
`main..HEAD`, `-Range` on the command: 41 files, about 8.8k insertions, of which about 3k are `.collab`
handoffs and ledgers - skip those files, they are the record of this task, not code).

## Question

Can wave 29 (handoffs 01-05: Claude Code headless as a reviewer engine for the Claude subscription or an
Anthropic API key, decisions D1-D12) together with wave 29b (handoffs 06-13: the third credential mechanism
`auth: endpoint` for third-party Anthropic-compatible endpoints, decisions E1-E10, D10 reversed) be accepted
as the 0.6.0 candidate's engine work? ACCEPT, HOLD (with the blockers), or ADVISE.

## Delta since the last review

Follows: `handoffs/06-claude-claude-engine-third-party-routes.md` (the decision panel, replies 07-11) and,
for the subscription/api-key engine, `handoffs/05-claude-claude-engine-decisions.md` (no review of its code
had happened before today).

- `main` (0.5.1, R24, the first-run docs) merged into the branch (dea37d8); the first run of
  `tests/harness-claude.ps1` failed 5 checks, all defects of the fake CLI and two checks (55f5c0b), no engine
  code changed; 55/55.
- Wave 29b (ee03701 engine, 431ab31 fake + harness, 03ff742 docs, 4c46cdf harness-host): E1-E7 as
  decided in handoff 12. harness-claude 75/75 (ENDPOINT category: 20 checks), harness-roster 119,
  harness-telemetry 112, harness-engines 97, harness-companions 42, harness-visibility 122, harness-panel 54,
  harness-host 65 - all 0 failures on Windows PowerShell 5.1; harness-claude ENDPOINT,UNIT,ROSTER
  39/39 on pwsh 7.6.
- The first live consultation on the endpoint route (ledger n=8, `handoffs/13-claudecode-smoke-endpoint.md`):
  `ZAI-claude :: glm-5.3 [claude]`, 15.4 s, usable; `provider_config {engine, launcher, credential_mechanism
  endpoint, base_url, env_key, plan}`, fingerprint `944a94557723...`, `engine_run.model_resolved glm-5.3`,
  `api_key_source none`, `child_env_allowed` with ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, API_TIMEOUT_MS and
  no ANTHROPIC_API_KEY; the telemetry event delivered.

- **After the first acceptance panel (replies 16 kimi, 17 dola-seed, 18 muse - all HOLD; astra out on the ChatGPT
  limit, handoff 15 is her partial):** E11 (d8fecd2) closes their common blocker - with `auth: endpoint` the roster
  validator and the `-Model` check refuse any Anthropic model id (the closed table, the four aliases, any
  `claude-*` id), so the init-model equality is a billing proof on this route; harness-claude ENDPOINT 41/41,
  harness-roster 119/119. F17-1/F17-2 superseded by F02-4/F04-1 and F04-2 (D5, D6); F18-2 wontfix (D4).

- **After handoff 20 (astra alone, HOLD: F20-1..4) - decisions E12-E17 in `handoffs/21-claude-claude-engine-acceptance-decisions.md`,
  implemented in 450fcf4 (engine), 93c8463 (fixtures: the ACCEPT category), 4aca34d (docs), and the amendments A1-A5
  of handoff 21 (after the RC3 smoke 22: F22-1..5) in 3ed1f6d (A4: apiKeySource required under subscription and
  api-key, class auth when missing).** E12: a killed turn's init is judged, a failed proof blocks the continuation;
  E13: every assistant message's model must equal the init-resolved id (F18-2 implemented by it); E14/A4: the init
  fields model, permissionMode, tools, mcp_servers required, apiKeySource required except under endpoint; E15/A1:
  D6 amended - a rejecting rate_limit_event with a successful result keeps the reply usable, is warned about and
  marks the route's health (engine_run.quota_mark) so the plan propagation sees it; E16: the machine-wide running
  record carries the plan, same-plan runs of any engine or repository count against parallel.<plan> (default 1;
  a label with a plan needs parallel.<plan> raised too); E17: StructuredOutput only under the native transport.
  Harnesses after E12-E16 (all 0 failures, Windows PowerShell 5.1, one at a time): claude 85, panel 54,
  companions 42, detach 51, engines 97, visibility 122, roster 119, telemetry 112, fixes26b 51, host 65 (GREP/README
  20 after the README edits); after A4: claude -Only ACCEPT,BILLING,UNIT 29/29 (the full run is repeated before this
  brief's run).
- **RC3 of handoff 20 through the bridge** (temporary roster, 2026-10-07): 22 `mimo-claude :: mimo-v2.6-pro [claude]`
  checkpoint on handoff 21, schema transport native, structured reply (ADVISE, 5 wording findings on the decision
  record, all taken: A1-A5) after a timeout continuation (the main turn killed at 900 s - the MiMo route is slow on
  both engines); 23 `ZAI-bad` (an endpoint entry whose env_key holds an invalid token, the subscription login present):
  `failed: claude exit 1 - Failed to authenticate. API Error: 401 token expired or incorrect`, class auth, 185 s, no
  fallback to the login, the partial kept. Known limitation, not of this wave: a reply delivered by a continuation
  turn has ledger `usage` null (the killed main turn has no result event); the continuation's own tokens are in
  the handoff header.

- **After handoff 24 (astra's third round, HOLD on F24-1 only):** A6 (95eee6e) - the machine-health record key
  includes the quota mark's reset, so a marked and an unmarked success of one route, repository and second are two
  records; the replay is idempotent; a second repository sees the route out until the reset and the same-plan codex
  entry out through the plan. 24-RC1 fixture in ACCEPT: harness-claude -Only ACCEPT 12/12, harness-fixes26b -Only
  HEALTH 6/6 (the full harnesses were last run complete before A4; the machine's memory guard stops long background
  runs - the full rerun is pending the operator's go).

## CURRENT invariants claimed

- A claude reviewer runs `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config
  --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model <id> [--effort] [--json-schema]
  (--session-id <minted> | --resume <thread> [--fork-session])`, the prompt on stdin (<= 1 MiB); EVERY turn's
  init event must show exactly the tools Read, Grep, Glob, StructuredOutput, no MCP server, permissionMode
  dontAsk, and the pinned model id (after the `[1m]` strip), else the turn fails (class capability); the main
  `modelUsage` key must be the pinned id too. (D1, D4)
- The child environment is an ALLOW list (system, proxy and trust variables, CLAUDE_CONFIG_DIR,
  DISABLE_AUTOUPDATER=1); `auth: api-key` adds ANTHROPIC_API_KEY; `auth: endpoint` adds ANTHROPIC_BASE_URL,
  ANTHROPIC_AUTH_TOKEN (the value of the roster's `env_key` variable, read at launch, never logged) and
  API_TIMEOUT_MS; every other ANTHROPIC_* and CLAUDE_* variable is absent. The ledger records the NAMES
  (`engine_run.child_env_allowed`). One builder serves the preflight, the version probe and every turn. (D2, D3, E4)
- Preflight: subscription and api-key modes run `claude auth status` in that same environment (loggedIn,
  authMethod, apiProvider firstParty); endpoint mode runs NO auth status and NO live request - the credential
  is `ok: env <NAME> set`; a launch with the variable unset is refused even under -SkipPreflight. (D3, E3)
- Identity: `cc-engine-v1|claude|<auth>|<model family>` for subscription/api-key; `cc-engine-v1|claude|endpoint|
  <canonical base_url>|<env_key name>` for endpoint; health keyed by the fingerprint; lineage per route (a
  plan's codex and claude routes are distinct reviewers). The optional entry key `plan` (any engine) is a
  quota group: a QUOTA-class failure on one route marks every entry of the plan out until its reset; auth,
  transport and capability failures stay route-local. (D7, E5)
- Roster: `auth` of engine claude is subscription (default) | api-key | endpoint; `endpoint {base_url https,
  env_key NAME, timeout_ms 60000..7200000}` required with endpoint and refused otherwise; the model table is
  closed (aliases + published ids) for subscription/api-key and an open id pattern for endpoint; one label
  names one engine, one (provider, model) once; `codex_config` refused on engine entries; an unknown key refuses
  EVERY run. (E1, E2)
- Concurrency: claude members form one engine-wide scheduling group (`parallel` on a label raises it); every
  `plan` is a group across engines (`"parallel": {"<plan>": n}` raises it). (D5, E7)
- The strict tree check: a change of the working tree or the collab directory during a claude turn fails the
  run; transcripts live in Claude Code's projects directory, never inside the repository (CLAUDE_CONFIG_DIR or
  a projectsDirectory inside the repository refuses the run). (D1)
- Telemetry: the vendor class by the endpoint HOST first when the entry has a base_url, else by the engine
  (anthropic); the `[1m]` suffix stripped for every vendor; MiniMax row (api.minimax.io/.cn, minimax-m3); the
  event never carries the URL, the label or the key name; the ledger keeps the real names. (E6)
- Reply files `handoffs/NN-claudecode-<slug>.*`; `-Sandbox workspace-write` refused; `-MaxModelSteps n` ->
  `--max-turns n`; a denial with a usable reply is a warning, a denied empty success is `DeniedEmpty`; quota
  by a result `is_error` / `rate_limit_event`, raw in `engine_run.rate_limit`; a timeout kill resumes the
  minted session id. (D6, D8)

## Changed files

Base commit `bef3b08` (the range `main..HEAD`). Reading plan: start with `plugins/codex-consult/scripts/
codex-consult-common.ps1` (the `*-Claude*` functions - the model table, child environment, probe, sign-in,
identity, args, stdin, events, init problem, turn outcome, salvage -, the `engine:claude` caps-v1 row, the
roster validator's claude/endpoint/plan branches, the panel groups, `Get-TelemetryVendor`,
`Get-CoordinatorMatch`), then `codex-consult.ps1` (the engine dispatch, dry-run lines), `codex-providers.ps1`,
then `tests/fake-claude.ps1` and `tests/harness-claude.ps1` (what the checks actually prove), then README
"Engines (wave 29)" and the roster table, the setup-providers skill 3g. Skip `.collab/`.

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | the claude engine adapter (wave 29) + endpoint mode, plan quota, host-first telemetry, coordinator match (29b) |
| `plugins/codex-consult/scripts/codex-consult.ps1` | engine dispatch, auth/endpoint pass-through, dry-run lines, the unset-variable refusal |
| `plugins/codex-consult/scripts/codex-providers.ps1` | the claude rows (sign-in / endpoint columns), plan verdicts |
| `plugins/codex-consult/scripts/codex-consult-hook.ps1` | comments |
| `tests/fake-claude.ps1`, `tests/fake-claude.cmd` | the fake CLI: auth status modes, stream-json init/result, endpoint mode, 401 on a token mismatch |
| `tests/harness-claude.ps1` | 75 checks (UNIT, ROSTER, ENGINEEXE, BILLING, PREFLIGHT, FAIL, TOOLSET, FORK, PANEL, LISTING, GUARD, ENDPOINT) |
| `tests/harness-{roster,telemetry,engines,companions,visibility,panel,host,muse,detach}.ps1`, `tests/run-all.ps1`, `tests/README.md` | registrations and expectation updates |
| `README.md`, `plugins/codex-consult/README.md`, `plugins/codex-consult/skills/*/SKILL.md`, `CHANGELOG.md`, `TECH_DEBT.md` | the engine's documentation, the roster rows, the first-run docs, 3g |

## Open findings

From `codex-findings.ps1 -Task claude-engine-2026-09-30 -List`: every finding of handoffs 02-04 (design review)
and 07-10 (the endpoint panel) is `implemented` with its decision and commit in the note; none is `verified`
yet - this acceptance is the verification. _(no `proposed` finding open)_

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| 07-RC1, 08-RC2, 09-RC1, 09-RC2 (init apiKeySource and model: straight id vs alias, z.ai and MiMo, invalid token) | `claude -p ... --model glm-5.3` / `--model sonnet + ANTHROPIC_DEFAULT_SONNET_MODEL` / `--model mimo-v2.6-pro` / a wrong token; `claude auth status` with the base URL (coordinator's scratch, 2026-10-06) | Claude Code 2.1.291 | 0/0/0/1 | handoff 12, P8-P12 | init model = the real id in every variant; apiKeySource `none`; wrong token -> 401, no fallback; auth status ignores the base URL | completed |
| 09-RC3, 10-RC1 (fake env/init matrix, apiKeySource acceptance) | `tests/harness-claude.ps1` ENDPOINT | 431ab31 | 0 | the harness summary | 75/75 | completed |
| 20-RC1 (fixtures E12-E15: prohibited init on a timed-out turn + valid continuation stays failed; foreign assistant model; init without tools; rejecting rate limit + success) | `tests/harness-claude.ps1` ACCEPT | 93c8463, 3ed1f6d | 0 | the harness summary | 85/85 full, 29/29 ACCEPT,BILLING,UNIT after A4 | completed |
| 20-RC2 (a held codex route of plan zai makes a panel's same-plan claude member wait at limit 1) | `tests/harness-claude.ps1` ACCEPT (E16) | 93c8463 | 0 | the harness summary | waits, proceeds after the hold; the message names the plan | completed |
| 24-RC1 (unmarked then marked success, same route/repo/second; read from a second repository; replay) | `tests/harness-claude.ps1 -Only ACCEPT` | 95eee6e | 0 | the harness summary | 2 records kept, route and plan out until the reset, replay adds nothing | completed |
| 20-RC3 (per-provider native-schema consultation + invalid token with the login present) | the bridge, temporary roster: handoffs 22 (MiMo native), 23 (z.ai invalid token); z.ai native = handoff 11 / P8 | 11af9bc | 0 / 1 | handoffs 22, 23 | structured_output on MiMo and z.ai; 401 class auth, no fallback | completed (Kimi Code not run) |
| 10-RC2 (plan propagation codex+claude, lineage separate) | `tests/harness-claude.ps1` ENDPOINT (quota on a codex entry marks the same-plan claude entry out; auth does not) | 431ab31 | 0 | the harness summary | passes | completed |
| 10-RC3 (capability smoke per endpoint) | P8, P10 and the live run n=8 | 2.1.291 / 2.1.292 | 0 | handoff 13 | flags accepted, structured output, model reported, usage fields present | completed (z.ai, MiMo; Kimi Code not run) |
| 07-RC2 (plan terms) | the providers' pages read 2026-10-06 | - | - | handoff 12 (corrections) | z.ai token-weighted credits; Kimi Code endpoint api.kimi.ai/coding/; Alibaba "interactive ... only" | completed |
| 07-RC3 / 08-Q6 (the paired pilot) | - | - | - | - | wave 29c, after the operator's go (spends plan credits) | skipped |

## Evidence

- `handoffs/12-claude-claude-engine-endpoint-decisions.md` - the probes P8-P13 and the decisions.
- `handoffs/13-claudecode-smoke-endpoint.md` + ledger n=8 - the live endpoint run and its identity fields.
- `tests/harness-claude.ps1` - the 75 checks; the worker's report named two test-only fixes of the first run.
- `handoffs/11-glm-third-party-routes-claudecode.md` - the A/B pair (one pair: 0.30x credits, 0.51x wall).

## Questions

- **Q1.** Does the code hold the invariants above? Name any path where a claude turn can run with a tool, a
  variable or a model other than the pinned ones without failing the run.
- **Q2.** Endpoint mode: is the proof of non-use of the subscription (init model = pinned id, ANTHROPIC_API_KEY
  absent, the unset-variable refusal) sufficient, or is there a path where the CLI falls back to the local
  login? P11 showed a 401 with no fallback on a wrong token.
- **Q3.** Plan quota propagation and the panel plan groups: any way a quota-class failure fails to propagate,
  or a non-quota failure propagates? Any deadlock or starvation in a merged group?
- **Q4.** The roster validator's new refusals: is every bad shape refused with a clear text, and does a valid
  endpoint entry never refuse an unrelated codex entry?
- **Q5.** Telemetry: can an endpoint run leak the URL, the label or the key name into the event? Is the
  host-first classification correct for a host not in the table (`other`)?
- **Q6.** What do the harness checks NOT prove that a live run would (beyond the paired pilot of wave 29c)?
- **Q7.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 900 words.
