# Handoff 18 - Meta Muse (muse): wave29-acceptance-meta

Date: 2026-10-06 23:57 local. Author: Meta Muse (muse) (model muse-spark-1.3-contributor, effort high), muse-cli 1.4.3-R5018.1.
Reviewer: meta :: muse-spark-1.3-contributor [muse] (provider from roster, model from roster; engine muse (C:\Users\Dmytro\AppData\Local\Programs\muse\muse.cmd); provider fingerprint 1c6f62bb040d; harness muse-cli 1.4.3-R5018.1).
Preflight: ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth).
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 10 of 10, panel 063f14c7 member 4 of 4.
Effort: high sent (requested high, mapping muse-v1, by caps-v1: engine:muse, muse-spark-1.3-contributor; not confirmed by the provider). Consultation id: 07f1a083-f57b-4585-be49-1554cef5282f.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads), purpose: acceptance). Argv: `muse exec --json --prompt-file C:\Users\Dmytro\AppData\Local\Temp\codex-consult-prompt-fbccfa72c3834c638726957e1912efed.txt --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json --model muse-spark-1.3-contributor --reasoning-effort high --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never` (prompt from a file: --prompt-file).
Parent thread: (none - new thread). Result thread: `01a11339-1391-7e00-bbab-5e6b9bf4b383` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/14-claude-wave29-acceptance.md` (sha256 2f1d2d89caa2). Reviewed: bef3b08, base bef3b083a39eaafd8c1b6646a5af46b78900c845, tree sha256 c34be8e6886f, 0 changed files.
Bridge outcome: usable reply. Wall time: 302.2 s. Tokens: not reported by muse.
Engine turns: 1 (each one a Muse Code subscription prompt); MSP schema_version 1.
Timeout: 3600 s (-TimeoutSec); continuation after a timeout kill: up to 900 s. Range: `main..HEAD` - the range changes 44 files, 9561 lines (9342 insertions, 219 deletions).
Verdict: HOLD - The endpoint route cannot prove it did not bill the local subscription when the same model id is served (finding #1). Findings: 1 blocker, 1 major, 0 minor, 0 note (F18-1..F18-2, tracked in `findings.json`). Structured reply: `handoffs/18-muse-wave29-acceptance-meta.reply.json`.
Raw event stream: `handoffs/18-muse-wave29-acceptance-meta.events.jsonl`.
Verbatim reply follows.

---

**Verdict: HOLD — one blocker (finding #1).**

**Q1. Invariants.** The adapter holds them in code with two gaps. Every init is checked (union of tools against Read/Grep/Glob/StructuredOutput, no MCP servers, dontAsk), and model drift is checked over all init models plus the main modelUsage key. Child env is a true allow-list (endpoint adds only BASE_URL/AUTH_TOKEN/API_TIMEOUT_MS; API_KEY stays absent). Gaps: (a) non-main models (assistant message.model, secondary modelUsage keys) only become an OtherModels *warning* (finding #2); (b) managed enterprise settings/hooks remain the F02-1/F03-1 residual — --restricted is claimed to disable them but no --settings pin was found, so only the fail-closed tree check protects the run.

**Q2. Endpoint proof: not sufficient.** The code admits apiKeySource none "proves nothing" on this route and fails only on ANTHROPIC_API_KEY. P11 (401, no fallback on a wrong token) is good evidence but does not cover the dangerous case: valid token + live login serving the *same* model id, which passes both the key-source and the exact-model checks. Finding #1 (blocker) requires a recorder proof per CLI version.

**Q3. Plan quota/groups.** Correct scope in code: plan records are read as one set and only quota/burst marks the whole plan out until reset; auth/transport/capability stay route-local. Panel limits take the min of label and plan caps (default 1 serializes a shared plan) — no deadlock shape found; fairness/starvation under contention is unproven live.

**Q4. Roster refusals.** Yes: unknown keys refuse the whole roster (fail-closed by design), endpoint is required iff auth is endpoint and refused otherwise, messages name the rule without echoing secrets, and a valid endpoint entry cannot refuse an unrelated codex entry (separate branches; dup check is same provider+model only).

**Q5. Telemetry.** No leak on the code path: the event allow-list carries only vendor class + closed-list model; label/URL/key name are never read. Host-first with unknown host → other is correct; the known limitation is a vendor-domain relay misattributing (documented).

**Q6. What the harness does not prove.** All live-CLI behavior: same-model subscription fallback, background destinations, per-provider quota/auth texts, two-claude ~/.claude races, hard-kill transcript resume, managed-hook writes, >1 MiB stdin, --max-turns semantics on 2.1.292, Kimi/Alibaba/MiniMax smoke (only z.ai + MiMo run), and the billing unit (deferred to 29c). The fake CLI + test-prefix hook also bypasses part of the env scrub.

**Q7. Verdict: HOLD** on finding #1; otherwise the wave 29+29b code matches its claimed invariants.

## Requested checks
RC1 (workspace-write, ~30 min): run the real CLI against a local Anthropic-compatible recorder with endpoint token/base-url plus a signed-in CLAUDE_CONFIG_DIR; capture init apiKeySource and the Authorization header. Settles finding #1. Budget: one endpoint smoke.
RC2 (read-only, ~15 min): unit-feed a stream with matching init/main model plus a foreign assistant message.model; require capability failure. Settles finding #2.
RC3 (workspace-write, ~30 min): run two concurrent claude turns plus coordinator load; check transcripts, exit codes, ~/.claude.json integrity. Settles F02-4/F04-1 live.
RC4 (workspace-write, ~20 min): configure a managed write-hook sentinel in a scratch CLAUDE_CONFIG_DIR and run a restricted turn; check tree + hook log. Settles F02-1/F03-1.
RC5 (workspace-write, ~20 min): taskkill a live turn mid-stream, then resume the minted id. Settles F04-2 live.

---

### Findings

- **F18-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:5065`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5126` - Endpoint-mode turns cannot prove they did not bill the local subscription: init apiKeySource 'none' is the expected value on the endpoint route (P8/P10) and also the subscription's value, and the adapter explicitly records it raw and fails only on ANTHROPIC_API_KEY — so a silent same-model fallback to the signed-in login is indistinguishable in the ledger. Trigger: A machine with an active claude.ai login runs an endpoint roster entry and the CLI silently prefers the login while serving the same model id. Evidence: read-code: Endpoint branch returns early: only an init apiKeySource of ANTHROPIC_API_KEY fails the turn; any other source (including 'none') passes, with the comment that 'none' on this route 'proves nothing'.; read-code: Turn-outcome model proof for endpoint uses exact equality against the pinned id, so a fallback serving the same model id passes the model check too.; read-code: Endpoint credential check is local-only (variable set + URL parses); no per-turn network or header proof exists. The live smoke (ledger n=8) shows apiKeySource none with the token env present, which is consistent with both routes. Verify: Run RC1 and require the recorder to show the request carried the endpoint token (never the OAuth token) with the observed apiKeySource value. Remedy: Before acceptance, run one local Anthropic-compatible recorder proof per CLI version (token + base_url alongside a signed-in config; capture the Authorization header and init apiKeySource), and either fail closed on the ambiguous source or require an endpoint model id that the subscription cannot serve. Record the observed source value as the only accepted one. Supersedes: F08-4, F09-3, F10-2.
- **F18-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5259` - A turn that does auxiliary work under a different model can still be accepted as usable: models appearing in assistant events or as non-main modelUsage keys are collected into OtherModels and demoted to a warning, while only init models and the main modelUsage key fail the turn. Trigger: A turn whose assistant events or secondary modelUsage keys name a model outside the pinned id/family but whose init and main model match. Evidence: read-code: Init-model drift over all init models and main-model mismatch both fail as capability, but the combined list of remaining modelUsage keys plus assistant models is assigned to OtherModels and only appended to Warnings before Ok=true. Verify: Feed the adapter a stream with matching init/main model plus an assistant message.model of another family and require a capability failure (RC2-adjacent unit check). Remedy: Fail the turn (class capability) on any model outside the pinned match (exact for endpoint, family for subscription/api-key), or document the helper-model allowlist with evidence that helpers cannot bill or act outside the pinned route.

### Prior findings

- F02-1 - still-open - Managed-hooks write path still depends on --restricted disabling enterprise policy; tree check fail-closes but attribution wording unchanged.
- F02-2 - fixed - Child env is now an allow-list; ANTHROPIC_*/CLAUDE_* absent except per-auth additions.
- F02-3 - fixed - Closed model table + [1m] strip + host-first telemetry implemented.
- F02-4 - fixed - Engine-wide claude scheduling group in panel plan; live two-child race still unproven.
- F02-5 - fixed - Denial/quota/resume taxonomy now defined in turn outcome.
- F03-1 - still-open - Same root as F02-1: init tool list cannot attribute tree writes under managed hooks.
- F03-2 - fixed - Allow-list plus apiProvider firstParty gate implemented.
- F03-3 - fixed - One builder serves preflight and turns.
- F03-4 - fixed - Allow-list drops persistence/model overrides.
- F03-5 - fixed - Allow-list drops inherited effort override.
- F03-6 - fixed - Every init model plus main modelUsage checked; assistant-model remainder is new finding #2.
- F03-7 - fixed - Per-route fingerprint plus plan-level quota group implemented.
- F03-8 - fixed - --max-turns mapping implemented.
- F03-9 - fixed - JSON read before exit code; loggedIn false means missing.
- F04-1 - fixed - Engine-wide serialization group; live parallel integrity still unproven.
- F04-2 - fixed - Timeout kill resumes minted id; hard-kill corruption path handled as failure.
- F07-1 - fixed - Token-weighted billing corrections recorded in handoff 12.
- F07-2 - fixed - Kimi endpoint corrected to api.kimi.ai/coding/ per brief.
- F07-3 - fixed - Canonical base_url + env-key fingerprint plus plan key implemented.
- F07-4 - fixed - AUTH_TOKEN-only endpoint contract implemented; per-provider live auth still unproven.
- F07-5 - fixed - Host-first vendor plus per-vendor [1m] handling implemented.
- F07-6 - fixed - Plan-terms corrections recorded; operator-scoped acceptance remains.
- F07-7 - still-open - Background-traffic isolation still needs destination-only network logs; code cannot prove it.
- F08-1 - fixed - Host-first classification returns endpoint vendor before engine fallback.
- F08-2 - fixed - [1m] stripped for every vendor.
- F08-3 - fixed - Route fingerprint plus shared plan key implemented.
- F08-4 - still-open - Replaced by finding #1 (token-source proof still ambiguous).
- F08-5 - fixed - Billed-unit caveat documented; A/B deferred to wave 29c.
- F08-6 - fixed - API_TIMEOUT_MS in endpoint child env with bounds.
- F09-1 - fixed - Host-first reviewer class implemented.
- F09-2 - fixed - Endpoint entries compare as codex entries (label + model).
- F09-3 - still-open - Replaced by finding #1.
- F09-4 - fixed - [1m] stripped for vendor zai; open endpoint pattern documents suffix.
- F10-1 - fixed - Distinct route fingerprints with shared plan quota key.
- F10-2 - still-open - Replaced by finding #1.
- F10-3 - fixed - Host-first table with zai/MiMo/Moonshot/Alibaba/MiniMax rows and per-vendor [1m].
- F10-4 - fixed - Engine group plus plan group scopes implemented.
- F10-5 - fixed - Versioned smoke + paired-trial gate; full power caveat accepted as 29c.

## Verdict: HOLD

The endpoint route cannot prove it did not bill the local subscription when the same model id is served (finding #1).

### Blockers

- **F18-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:5065`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5126` - Endpoint-mode turns cannot prove they did not bill the local subscription: init apiKeySource 'none' is the expected value on the endpoint route (P8/P10) and also the subscription's value, and the adapter explicitly records it raw and fails only on ANTHROPIC_API_KEY — so a silent same-model fallback to the signed-in login is indistinguishable in the ledger. Verify: Run RC1 and require the recorder to show the request carried the endpoint token (never the OAuth token) with the observed apiKeySource value. Remedy: Before acceptance, run one local Anthropic-compatible recorder proof per CLI version (token + base_url alongside a signed-in config; capture the Authorization header and init apiKeySource), and either fail closed on the ambiguous source or require an endpoint model id that the subscription cannot serve. Record the observed source value as the only accepted one.
- **F08-4** (prior, still-open) `plugins/codex-consult/scripts/codex-consult-common.ps1:4496`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4888`, `.collab/claude-engine-2026-09-30/handoffs/06-claude-claude-engine-third-party-routes.md:73` - Endpoint credential semantics are neither implemented nor proven: current preflight still expects Claude sign-in/API-key state, and per-turn proof accepts only apiKeySource none or ANTHROPIC_API_KEY, not an AUTH_TOKEN/base-URL route. Verify: Run the real CLI against a local Anthropic-compatible recorder with token/base-url environment and a signed-in config; capture init apiKeySource and the Authorization header. Remedy: Implement endpoint-specific local preflight and require per-turn evidence that the named token and base URL were used; fail closed if the stream cannot prove it.

### Unproven scenarios

- Silent same-model fallback to the signed-in login on an endpoint route
- Managed enterprise settings/hooks writing despite --restricted
- Two concurrent claude children sharing one ~/.claude config
- Hard-kill transcript corruption and resume
- Per-provider live auth forms (x-api-key vs AUTH_TOKEN) for Kimi/Alibaba/MiniMax
- Background non-inference traffic destinations
- Provider-dashboard billed unit vs CLI usage fields
- Kimi Code / Alibaba / MiniMax capability smoke (only z.ai and MiMo run)
- Harness fake-CLI coverage vs real CLI init/result shapes on 2.1.292

### First-run checklist (observable)

- [ ] Ledger engine_run shows exactly tools Read/Grep/Glob (+StructuredOutput), permissionMode dontAsk, no MCP servers, and the pinned model id on every init; any deviation fails as capability/permission, not usable.
- [ ] engine_run.child_env_allowed for endpoint lists ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, API_TIMEOUT_MS and no ANTHROPIC_API_KEY; subscription/api-key runs list no endpoint variables.
- [ ] A launch with the endpoint variable unset is refused before start, even with -SkipPreflight.
- [ ] Fingerprint differs per route (canonical base_url + env key name for endpoint) while a quota failure on one plan route marks every same-plan entry out until its reset; auth/transport/capability failures stay route-local.
- [ ] Telemetry event carries only vendor class + closed-list model (never URL, label, or key name); unknown host reads other.
- [ ] Working tree and collab directory unchanged across the turn; any change fails the run.
- [ ] Timeout kill resumes the minted session id; denial-with-usable-reply warns, denied-empty fails as DeniedEmpty.
