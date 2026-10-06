# Handoff 10 - Codex: third-party-routes-mimo

Date: 2026-10-06 20:56 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 10, panel 6a852ab7 member 4 of 4.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 1f7b8aff-db72-4838-997c-67f485e5b6a9.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: decision). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-862af483e02140a9bdb112054693acd5.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage mimo :: mimo-v2.6-pro in this task's ledger; other lineage(s): gemini :: gemini-3.1-pro-high [agy], openai :: gpt-6-astra, meta :: muse-spark-1.3-contributor [muse]). Result thread: `01a11292-c41c-7a43-8918-52e5a2ca793c` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md` (sha256 6dc51ced0b13). Reviewed: 8b11591, base 8b115918d16f4d56f0e630b89984ce1e18322bbc, tree sha256 60b1ad75f290, 0 changed files.
Bridge outcome: usable reply. Wall time: 1794.6 s. Tokens: in 5669358 (cached 3006464), out 22751, reasoning 13201.
Timeout: 1800 s (the default of purpose decision); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Adopt alternative 2 only after route versus plan identity, endpoint authentication proof, telemetry, and cross-route concurrency contracts are defined and smoke-tested. Findings: 0 blocker, 5 major, 0 minor, 0 note (F10-1..F10-5, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/10-codex-third-party-routes-mimo.reply.json`.
Raw event stream: `handoffs/10-codex-third-party-routes-mimo.events.jsonl`.
Verbatim reply follows.

---

## Decision
1. **Alternative 2 with an explicit endpoint object** - deciding factor: one tested Claude adapter and native schema with an auditable route. Failure mode: Claude assumptions leak into endpoint mode.
2. **Alternative 2 referencing `[model_providers]` only for `env_key`** - deciding factor: less duplication. Failure mode: wrong OpenAI URL or wire derivation and hidden config coupling.
3. **Alternative 3 `claude-compat`** - deciding factor: clean separation. Failure mode: duplicated adapter, caps, hooks, and telemetry drift.
4. **Alternative 1 keep D10** - deciding factor: zero bridge risk. Failure mode: loses native-schema and cost advantages.
5. **Alternative 4 outside the roster** - deciding factor: no code change. Failure mode: no ledger, panel, telemetry, or A/B evidence.

**Q1.** Use alternative 2 with explicit `base_url`, `env_key`, and `plan_key` under `engine: claude`, `auth: endpoint`; never derive the Anthropic URL from the OpenAI-compatible table. Keep route identity `cc-engine-v1|claude|endpoint|base_url=<canonical>|wire_api=anthropic|credential=<env-key name>` for lineage and parenting, separate from quota identity `cc-plan-v1|<plan_key>`. Require distinct provider labels per route.

**Q2.** Send `--model <provider-id>` directly. Do not pass `ANTHROPIC_MODEL` or `ANTHROPIC_DEFAULT_*_MODEL`. The straight variant should report the exact ID in `init.model` and dominant `modelUsage`; compare after stripping only terminal `[1m]`, while retaining the raw suffix. The alias variant is provider-dependent and may report `sonnet` or the mapped ID; capture this before allowing it. Reject alias mapping initially; if retained, require an explicit alias-to-ID map and compare against the mapped ID, never Claude family matching.

**Q3.** Preflight locally: credential variable present plus launcher/version checks. Do not spend a live request because z.ai meters prompts and MiMo charges tokens. Propagate auth and quota failures through `plan_key` across codex and claude routes; keep transport and capability failures route-scoped.

**Q4.** Pass exactly `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and fixed or bounded `API_TIMEOUT_MS`. Keep `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_*_MODEL`, `ANTHROPIC_SMALL_FAST_MODEL`, custom headers, Bedrock/Vertex/Foundry variables, and other `CLAUDE_*` variables absent except `CLAUDE_CONFIG_DIR`. Every init must name the captured AUTH_TOKEN source; `none`, `claude.ai`, OAuth, or `ANTHROPIC_API_KEY` fails closed.

**Q5.** Classify endpoint entries by base_url host first, then engine fallback. Keep raw ID, resolved ID, and endpoint in the ledger but never send the URL. Current gaps: the claude shortcut forces `anthropic`, MiniMax has no telemetry class, and `[1m]` normalization differs by vendor.

**Q6.** Run paired, order-randomized identical briefs. Use 30 paired runs per provider as a pilot and about 100 pairs before claiming quality parity. z.ai gate: at least 20% fewer prompts per usable verdict, uncached input at most 110%, first-turn schema-valid rate no worse than 5 points, wall median at most 120%, and no blocker or major quality regression. MiMo gate: at least 20% lower credits using `300*uncached + 2.5*cached`, cache creation priced conservatively, cache-hit rate +10 points, and the same quality and wall gates.

**Q7.** Keep claude children serialized engine-wide while sharing `~/.claude`; per-endpoint parallelism requires isolated `CLAUDE_CONFIG_DIR` plus race testing. Apply machine-wide parallel and quota limits across codex and claude by `plan_key`; current route fingerprints differ, so the limit is not shared.

**Q8.** Additional risks: provider terms and data handling for automated review, CLI flag drift, mutable aliases, `[1m]` pricing or quota differences, endpoint URL canonicalization, provider-specific usage and rate-limit fields, schema-validity weaker than `structured_output`, and transcript corruption after arbitrary hard kills. Add capability smoke tests and a dated terms attestation before roster enablement.

## Requested checks
- **RC1** (finding #2), repository root, workspace-write, 20 minutes: run the fake-claude environment/init matrix for endpoint mode with `ANTHROPIC_AUTH_TOKEN`; observe the exact accepted `apiKeySource`, expected environment names, and absence of secrets, `ANTHROPIC_API_KEY`, and model overrides.
- **RC2** (finding #1, finding #4), repository root, workspace-write, 45 minutes: run one codex ZAI and one claude z.ai member sharing `plan_key`, reject quota on one route, and observe shared health and concurrency while lineage remains separate.
- **RC3** (finding #3, finding #5), repository root, workspace-write plus provider quota, 60 minutes: run one disposable Claude Code capability smoke per endpoint and capture flag acceptance, schema validation, model reporting, usage fields, and rate-limit shape.

---

### Findings

- **F10-1** [major] `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:74`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2573`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5861` - Endpoint mode needs two identities: a route fingerprint containing canonical base_url and credential scope for lineage, and a separate plan or quota key shared by codex and claude routes using the same plan. The current engine fingerprint omits endpoint identity and health is keyed only by provider_fingerprint, so same-plan routes cannot reliably share quota health or preserve one-endpoint lineage. Trigger: The same provider plan and key are reachable through codex on the OpenAI-compatible URL and through claude on the Anthropic URL, and one route reaches its quota. Evidence: read-code: Engine identity is cc-engine-v1|claude|<auth>|<model family> with no endpoint URL or credential scope.; read-code: Endpoint health is looked up by provider_fingerprint alone.; read-code: The proposed identity names base_url but explicitly leaves shared health with the codex route unresolved. Verify: Create two entries for one declared plan, one codex and one endpoint-mode claude route; require distinct route fingerprints, reject resume across them, and replay a quota failure on one so the shared plan becomes unavailable while the other route remains lineage-distinct. Remedy: Add an explicit endpoint object and plan_key. Fingerprint the canonical endpoint route for lineage; use plan_key as a separate quota and health scope shared only when explicitly declared. Keep route-specific failures scoped to the route.
- **F10-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:4371`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4485`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4883`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:100` - Endpoint authentication cannot safely reuse the current claude env and billing proof. The child builder strips ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN, while init validation accepts only apiKeySource none or ANTHROPIC_API_KEY. The exact source value emitted for AUTH_TOKEN is unknown and must be captured before acceptance. Trigger: A roster entry uses auth endpoint with ANTHROPIC_AUTH_TOKEN and a third-party base URL. Evidence: read-code: The allowlist passes ANTHROPIC_API_KEY only for api-key mode and removes every other ANTHROPIC variable.; read-code: Billing proof requires apiKeySource none for subscription or ANTHROPIC_API_KEY for api-key; no AUTH_TOKEN case exists.; assumed: The exact apiKeySource token for an auth-token endpoint has not been captured. Verify: Run a fake endpoint-mode child with AUTH_TOKEN and record argv environment names plus init apiKeySource; accept only the observed token-source value and fail closed on none, claude.ai, OAuth, or ANTHROPIC_API_KEY. Remedy: Add endpoint auth mode, inject only BASE_URL, AUTH_TOKEN, and bounded API_TIMEOUT_MS, and extend init proof to the captured token source while logging names only.
- **F10-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:4308`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10388`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:77` - Telemetry cannot represent third-party claude routes correctly today. The engine vendor shortcut classifies every claude run as anthropic, the closed Claude model table makes GLM and MiMo IDs other, MiniMax has no vendor row or host, and [1m] normalization is inconsistent. Trigger: Claude Code sends glm-5.3[1m] or mimo-v2.6-pro through api.z.ai, xiaomimimo.com, or api.minimax.io and telemetry is emitted. Evidence: read-code: Host rows cover z.ai, xiaomimimo, moonshot, and alibaba, but no minimax row exists and the claude row has an empty host list.; read-code: Claude models are a closed Anthropic table and [1m] is stripped for model validation.; inferred: A host-based third-party route on engine claude needs host-first classification; otherwise provider becomes anthropic and model becomes other. Verify: Unit-test telemetry for z.ai, MiMo, Moonshot, Alibaba, and MiniMax endpoint URLs with raw and [1m] models; require the correct vendor class and closed-list model while the ledger retains the raw name. Remedy: Classify endpoint entries by base_url host first, add the missing MiniMax class and models, normalize suffixes consistently for lookup, and keep raw IDs and endpoint metadata locally.
- **F10-4** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:3327`, `plugins/codex-consult/scripts/codex-consult-common.ps1:8284`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6374`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:109` - Concurrency needs two separate scopes. Shared Claude global state requires engine-wide serialization unless config directories are isolated, while provider quota and machine-wide endpoint limits must be shared across codex and claude routes through the same plan_key. Current grouping cannot enforce both. Trigger: A panel runs GLM through claude and the same z.ai plan through codex concurrently, or roster parallel raises claude concurrency. Evidence: read-code: Scheduling merges claude labels with a synthetic engine:claude scope, while other endpoint grouping merges provider fingerprints.; read-code: Machine-wide running counts are keyed by exact endpoint state, not a shared plan scope.; inferred: Different endpoint URLs do not isolate shared ~/.claude state and do not prove shared quota limits are coordinated. Verify: Run two claude children with raised parallel and inspect shared config integrity, then run codex and claude routes sharing plan_key while one is at the provider limit and require one shared waiting group. Remedy: Keep engine-wide claude serialization until per-entry CLAUDE_CONFIG_DIR isolation passes race tests; add plan_key to scheduling and machine health so route limits apply across routes.
- **F10-5** [major] `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:105`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4578`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4618` - The retention gate needs honest power and compatibility checks. Thirty paired runs can detect gross cost effects but cannot establish five-point quality or structured-output non-inferiority, and the adapter records CLI version without proving that flags, schema output, usage fields, or rate-limit shapes still work on each third-party endpoint. Trigger: The A/B difference is marginal, or a Claude Code or provider update changes flag support or event fields. Evidence: inferred: Thirty pairs are suitable for large cost effects, not tight quality parity.; read-code: Harness detection records version only, while argv hardcodes restricted, schema, and max-turns flags.; assumed: Current terms, retention rules, aliases, and provider event shapes are not verified in this read-only review. Verify: Run a versioned capability smoke per CLI and endpoint before the A/B, then run 30 paired trials and extend toward 100 pairs whenever cost or quality confidence intervals cross the gate. Remedy: Treat 30 pairs as a pilot, pre-register thresholds, extend marginal cases, validate structured output locally, add capability smoke tests, and record a dated terms and data-handling attestation.

### Prior findings

- F02-1 - fixed - Strict tree failure and WriteDisabled=false replace init-only attribution; the harness simulates a write but not a real managed hook.
- F02-2 - fixed - The child allowlist removes inherited routing and override variables and is checked through the fake CLI.
- F02-3 - fixed - Roster and telemetry share one model table with [1m] normalization and drift tests.
- F02-4 - still-open - Default scheduling is serial, but roster parallel can recreate shared ~/.claude concurrency and real state integrity is untested.
- F02-5 - fixed - Denial, quota, subtype, stdin, and resume behavior are defined and tested defensively; real quota payloads remain external.
- F03-1 - fixed - Tree changes fail the run and are not attributed from init evidence; managed-hook execution remains documented rather than tested.
- F03-2 - fixed - The allowlist excludes inherited gateway routing and competing Anthropic credentials.
- F03-3 - fixed - Auth preflight and turn launch share one child-environment builder.
- F03-4 - fixed - CLAUDE_CODE_SKIP_PROMPT_HISTORY and other CLAUDE_CODE variables are removed.
- F03-5 - fixed - CLAUDE_CODE_EFFORT_LEVEL is removed and repair effort is explicit.
- F03-6 - fixed - Init and dominant modelUsage drift fail; a secondary model is still recorded and warned rather than failed.
- F03-7 - fixed - Health is separated by auth mode and model family, though live quota replay is not tested.
- F03-8 - fixed - MaxModelSteps maps to --max-turns and the real CLI probe accepted it.
- F03-9 - fixed - Valid loggedIn=false JSON is treated as signed out before the exit code.
- F04-1 - still-open - No serialization or isolation of shared ~/.claude state exists when concurrency is raised.
- F04-2 - still-open - One real kill/resume succeeded, but arbitrary hard-kill transcript corruption is neither prevented nor exhaustively tested.

## Verdict: ADVISE

Adopt alternative 2 only after route versus plan identity, endpoint authentication proof, telemetry, and cross-route concurrency contracts are defined and smoke-tested.

### Blockers

_(none)_

### Unproven scenarios

- The exact init apiKeySource value emitted for ANTHROPIC_AUTH_TOKEN.
- Whether the alias-mapped z.ai variant reports sonnet or the mapped provider ID in init.model and modelUsage.
- Current provider terms, retention rules, alias mappings, and model availability.
- Real concurrent ~/.claude integrity and transcript recovery after arbitrary hard kills.
- Third-party schema validity, usage/cache accounting, and rate_limit_event shapes.

### First-run checklist (observable)

_(none)_
