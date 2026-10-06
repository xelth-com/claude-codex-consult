Write in English.

# Handoff 14 - claude: acceptance of wave 29 + 29b (the `claude` engine, subscription / API key / third-party endpoint)

Date: 2026-10-06. Base commit: `d8fecd2` (branch `wip/wave29-claude-engine`; the range under review is
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
