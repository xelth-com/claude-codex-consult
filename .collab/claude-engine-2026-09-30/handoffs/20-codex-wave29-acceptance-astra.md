# Handoff 20 - Codex: wave29-acceptance-astra

Date: 2026-10-07 02:07 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - entry 1 of 10 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: c68f20e2-0da5-4f55-a281-9d23d8242c7f.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-40ec28fa596b46359dc3484444cdc690.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a11376-3712-74f3-9196-d719f21b11d6 -` (prompt on stdin).
Parent thread: `01a11376-3712-74f3-9196-d719f21b11d6`. Result thread: `01a113af-e854-7c30-8034-4ad268f4a5f8` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/14-claude-wave29-acceptance.md` (sha256 cd968b1d09db). Reviewed: c92c30e, base c92c30e238d42f89c1d681fce58a7324874ef24f, tree sha256 3d9f9f2a9811, 0 changed files.
Bridge outcome: usable reply. Wall time: 324.5 s. Tokens: in 5175493 (cached 4240896), out 37108, reasoning 10148.
Timeout: 3600 s (-TimeoutSec); continuation after a timeout kill: up to 900 s. Range: `main..HEAD` - the range changes 58 files, 15086 lines (14865 insertions, 221 deletions).
Verdict: HOLD - E11 closes the identified same-model endpoint ambiguity, but timeout recovery can bypass capability failures and model enforcement can accept a different model's answer. Findings: 2 blocker, 2 major, 0 minor, 0 note (F20-1..F20-4, tracked in `findings.json`). Structured reply: `handoffs/20-codex-wave29-acceptance-astra.reply.json`.
Raw event stream: `handoffs/20-codex-wave29-acceptance-astra.events.jsonl`.
Verbatim reply follows.

---

**Q1.** No. At HEAD `c92c30e`, read-only, in-memory replays reproduced three invariant gaps:

- A timed-out init advertising Bash and an MCP server returns no capability failure; continuation can subsequently make the consultation usable (finding #1).
- An Opus assistant answer passes when Sonnet remains the largest-output `modelUsage` entry (finding #2). D4’s helper exception does not establish that a top-level assistant response is a helper.
- Missing `tools` and `mcp_servers` fields pass as empty arrays (finding #3).

The environment allowlist, E11 refusal, strict-tree policy and distinct route identities are implemented. The brief’s unconditional requirement for four tools also needs correction: the recorded prompt-only smoke lists three; `StructuredOutput` should depend on the transport.

**Q2.** E11 adequately addresses F16-1/F18-1 within the documented CLI contract: Anthropic IDs and aliases are refused, endpoint models require equality, missing tokens prevent launch, and P11 records invalid-token failure without fallback. I found no demonstrated subscription-fallback path for the admitted third-party IDs. However, `apiKeySource: none` and environment-name logging are not independent proof of the destination or credential sent. Qualification remains specific to the tested CLI/provider combinations.

**Q3.** Recorded quota failures propagate through the plan’s route fingerprints; ordinary auth/transport/capability failures are excluded. A later successful record deliberately clears aggregated plan health. However, a rejecting rate-limit event followed by successful output loses its quota classification (finding #4).

F10-4 remains open: machine-wide running records and counting use route fingerprints, without engine/plan keys. A panel does not count another route of its plan when that route is absent from its selected members. Within one panel, grouping terminates and preserves roster order; transitive merging conservatively serializes additional members. I found no intrinsic local deadlock, but did not establish starvation freedom under external load.

**Q4.** Sampled validation passes: a valid mixed Codex/endpoint roster loads both entries; Anthropic endpoint models, missing endpoint objects, null auth, string timeouts and unknown endpoint keys produce entry-specific refusals. Invalid entries intentionally invalidate the whole roster. This is sampled coverage, not proof over every malformed shape.

**Q5.** The inspected event builder uses closed classifications. Executed fixtures for z.ai, MiMo, Kimi, MiniMax and an unknown host emitted neither URL, label nor key-name sentinels. Unknown hosts produced `other/other`; `[1m]` normalization worked. Consultation and rating classification share the helper.

**Q6.** Fake tests do not establish actual credential headers, provider billing, native schema compatibility, real quota/recovery sequences, managed-hook behavior, or durability across arbitrary kill points and concurrent sessions. Handoff 13’s actual result has no `structured_output`; it is not native-schema evidence. P6/P7 and P8–P11 provide bounded observations, not guarantees across versions. I did not run the write-producing harnesses. Statistical retention evidence remains deferred, and F10-5 remains open.

**Q7.** **HOLD.** Acceptance blockers are findings #1 and #2. Address #3/#4 and resolve the claimed machine-wide scope in F10-4 before treating the listed invariants as verified. No files were written.

## Requested checks

- **RC1:** CWD repository root; **workspace-write**. Add fake-stream cases for findings #1–#4, including prohibited-init timeout followed by a valid continuation, then run `powershell -NoProfile -File tests/harness-claude.ps1`. Require invariant violations to remain failed and rejecting quota evidence to survive. Budget: four fixtures, 15 minutes.
- **RC2:** CWD two disposable repositories sharing one roster/health store; **workspace-write**. Hold a fake Codex route active, then start a panel selecting only its same-plan Claude route at limit one. Require the second run to wait until the first unregisters, settling F10-4. Budget: two processes, five minutes.
- **RC3:** CWD disposable repository; **workspace-write**. For each supported endpoint/CLI version, run one native-schema consultation and an invalid-token attempt with local login present, recording destination and credential-source labels without secret values. Require `structured_output` on success and endpoint-only authentication failure on rejection. Budget: two attempts per provider, ten minutes each.

---

### Findings

- **F20-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:5174`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5589`, `plugins/codex-consult/scripts/codex-consult.ps1:4976`, `plugins/codex-consult/scripts/codex-consult.ps1:5083` - Timeout handling bypasses init capability validation, allowing a later successful continuation to erase evidence that an earlier turn advertised prohibited tools or MCP servers. Trigger: The main turn emits an init containing Bash or an MCP server, makes no monitored tree changes, then times out; its continuation emits an otherwise valid answer. Evidence: ran-command: An init with tools Read,Bash and MCP server rogue, evaluated with a timeout Pre value, returned an empty failure Class and a resumable ThreadCandidate.; read-code: The Pre branch returns before Get-ClaudeInitProblem runs.; read-code: Continuation eligibility uses the killed-turn classifier; successful continuation replaces the outcome and clears prior failure fields. That classifier explicitly preserves only auth/quota adapter classes. Verify: Run RC1's prohibited-init timeout case and assert that no continuation launches and the consultation remains failed despite a prepared valid continuation response. Remedy: Validate available init/model evidence before the timeout return, preserve invariant failures across turns, and explicitly prohibit continuation after permission, capability or credential-proof violations.
- **F20-2** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:5030`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5257`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5265` - The largest-output-token heuristic does not enforce one primary model per thread: a different model can produce the final assistant answer while the turn is accepted under the pinned model. Trigger: Init names claude-sonnet-5-5, a top-level assistant answer names claude-opus-5-5, and result.modelUsage reports Sonnet outputTokens 100 and Opus outputTokens 10. Evidence: ran-command: Get-ClaudeTurnOutcome returned Ok=true, Outcome='usable reply', ModelResolved='claude-sonnet-5-5', and OtherModels containing claude-opus-5-5.; read-code: MainModel is selected by maximum outputTokens; differing assistant models are only reported as possible helpers. Verify: Replay a matching init followed by a different top-level assistant model with fewer output tokens and require a capability failure. Remedy: Validate primary assistant events against the resolved pin. Permit helper models only when event provenance identifies them as helpers; do not infer primary-model identity from token volume. Supersedes: F03-6.
- **F20-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:4940`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5066` - Missing capability fields are accepted as proof of an allowed toolset and no MCP servers, so an incomplete or changed init schema can produce a usable consultation without the claimed evidence. Trigger: An otherwise valid init omits tools and mcp_servers, followed by a successful result. Evidence: ran-command: Removing both fields produced Ok=true and Outcome='usable reply'.; read-code: Missing fields default to empty arrays; validation checks only for extra tools and nonempty MCP lists. Verify: Replay missing, null and wrongly typed capability fields on each init and require an explicit proof failure. Remedy: Preserve field presence and types for every init, require valid capability arrays, and check the expected tools for the selected transport. Treat absent evidence differently from an explicitly empty MCP list.
- **F20-4** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5150`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5232`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5278` - A rejecting rate-limit event is discarded from the outcome when the terminal result is successful, contrary to the stated rejection rule; the resulting usable record cannot propagate that quota rejection to its plan. Trigger: A stream contains rate_limit_info.status='rejected' with a reset time, followed by subtype success, is_error=false and nonempty output. Evidence: ran-command: The adapter returned Ok=true, an empty Class and 'usable reply' despite parsing the rejecting event.; read-code: Quota evidence selects a failure class only on failure branches; the success branch neither fails nor warns for rejected status.; read-code: Health selection treats the latest usable record as clearing quota evidence. Verify: Replay the rejection-plus-success stream through outcome and health classification and assert the documented quota behavior, including its reset time. Remedy: Either make rejecting events terminal as D6 specifies, or define and validate an explicit recovery rule while preserving unresolved quota evidence independently of reply usability. Supersedes: F02-5.

### Prior findings

- F02-1 - fixed - WriteDisabled is false; monitored tree changes fail. This is detection, not prevention of all hook writes.
- F02-2 - fixed - Allowlist replaces ambient inheritance; inspected and exercised relevant name filtering.
- F02-3 - fixed - Validator/telemetry share the Claude table and suffix handling; actual context capacity remains unproven.
- F02-4 - fixed - D5 panel serialization is implemented; broader machine-wide scope remains under F10-4.
- F02-5 - still-open - Denial and resume rules are implemented, but finding #4 replaces the broad quota concern with a reproduced defect; live boundary coverage remains incomplete.
- F03-1 - fixed - Claude uses strict tree failure rather than WriteDisabled attribution.
- F03-2 - fixed - API-key child environment excludes inherited endpoint tokens, base URLs and provider selectors.
- F03-3 - fixed - Authentication probes and reviewer launches use the shared child-environment builder.
- F03-4 - fixed - CLAUDE_CODE_SKIP_PROMPT_HISTORY is excluded; name-filter replay returned false.
- F03-5 - fixed - CLAUDE_CODE_EFFORT_LEVEL is excluded; name-filter replay returned false.
- F03-6 - still-open - Superseded by finding #2: modelUsage checking was added, but the token-volume heuristic still accepts primary-model drift.
- F03-7 - fixed - Subscription/API-key fingerprints distinguish auth mode and model family.
- F03-8 - fixed - MaxModelSteps maps to --max-turns; P2 records CLI support.
- F03-9 - fixed - Parsed loggedIn=false is handled before exit-code-based uncertainty.
- F04-1 - not-checked - P7 records two successful concurrent runs; no sustained shared-state integrity test was executed here.
- F04-2 - not-checked - P6 records one successful interrupted-session resume; arbitrary kill-point durability was not tested.
- F07-1 - fixed - Decisions and README use token-weighted credits; account-level reconciliation remains unproven.
- F07-2 - fixed - Documentation distinguishes api.kimi.ai/coding from Moonshot pay-as-you-go.
- F07-3 - fixed - Canonical URL, port and credential-variable name define route identity; plan is separate. Identity replay confirmed distinct fingerprints.
- F07-4 - still-open - AUTH_TOKEN-only implementation remains; recorded live qualification covers z.ai/MiMo, not every documented provider.
- F07-5 - fixed - Executed endpoint telemetry fixtures returned correct closed vendor/model classifications.
- F07-6 - fixed - Blanket eligibility claim is withdrawn; documentation requires an operator decision and excludes Alibaba examples.
- F07-7 - fixed - Current endpoint claim concerns inference/billing rather than guaranteed absence of all Anthropic traffic; egress was not measured.
- F08-1 - fixed - Host-first classification replay returned zai for Claude on api.z.ai.
- F08-2 - fixed - glm-5.3[1m] replay classified as zai/glm-5.3.
- F08-3 - fixed - Distinct route labels can share plan health and a local panel scheduling group.
- F08-4 - fixed - Endpoint preflight is local; P8/P10 establish observed source none, and E11 restricts the admitted model set.
- F08-5 - fixed - Retention measurement now uses token-weighted credits rather than inferring billed prompt counts from num_turns.
- F08-6 - fixed - Bounded endpoint.timeout_ms supplies API_TIMEOUT_MS; actual delayed-provider behavior was not exercised.
- F09-1 - fixed - Executed ledger-shaped telemetry fixture returned provider zai and model glm-5.3.
- F09-2 - fixed - Endpoint mode bypasses the hardcoded Anthropic branch and uses the documented exact route-label/model contract.
- F09-3 - fixed - Observed none replaces the incorrect token-source expectation; P11 and E11 address the identified fallback ambiguity.
- F09-4 - fixed - Suffix normalization applies to all vendor rows and passed replay.
- F10-1 - fixed - Route fingerprints remain distinct while plan quota aggregates their health records.
- F10-2 - fixed - Endpoint environment injection is implemented; observed source none is handled under the revised E11 model restriction.
- F10-3 - fixed - Host-first dispatch, MiniMax coverage and universal suffix normalization are implemented and sampled successfully.
- F10-4 - still-open - Local groups merge engine/plan keys, but machine running records store only route fingerprints and panels count only selected routes; external same-plan routes can escape the limit.
- F10-5 - still-open - E8 still uses a small empirical retention gate without uncertainty bounds; native-schema and versioned endpoint qualification remain incomplete.
- F16-1 - fixed - E11 rejects closed-table aliases and all claude-* endpoint IDs; direct and mixed-roster refusal replays passed.
- F18-1 - fixed - E11 removes subscription-servable model IDs from the admitted endpoint scope; independent wire-level credential verification remains unproven.

## Verdict: HOLD

E11 closes the identified same-model endpoint ambiguity, but timeout recovery can bypass capability failures and model enforcement can accept a different model's answer.

### Blockers

- **F20-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:5174`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5589`, `plugins/codex-consult/scripts/codex-consult.ps1:4976`, `plugins/codex-consult/scripts/codex-consult.ps1:5083` - Timeout handling bypasses init capability validation, allowing a later successful continuation to erase evidence that an earlier turn advertised prohibited tools or MCP servers. Verify: Run RC1's prohibited-init timeout case and assert that no continuation launches and the consultation remains failed despite a prepared valid continuation response. Remedy: Validate available init/model evidence before the timeout return, preserve invariant failures across turns, and explicitly prohibit continuation after permission, capability or credential-proof violations.
- **F20-2** `plugins/codex-consult/scripts/codex-consult-common.ps1:5030`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5257`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5265` - The largest-output-token heuristic does not enforce one primary model per thread: a different model can produce the final assistant answer while the turn is accepted under the pinned model. Verify: Replay a matching init followed by a different top-level assistant model with fewer output tokens and require a capability failure. Remedy: Validate primary assistant events against the resolved pin. Permit helper models only when event provenance identifies them as helpers; do not infer primary-model identity from token volume.

### Unproven scenarios

- Full harness results at c92c30e were not independently rerun because the harnesses write scratch files.
- Actual destination, authentication header and account billing across every documented endpoint and CLI version.
- Native structured_output compatibility: the inspected handoff 13 result contains no structured_output.
- Real rejecting quota events, recovery sequences and reset-field variations beyond synthetic replay.
- Managed-hook writes outside monitored paths, including ignored files, submodules and external directories.
- Transcript integrity across varied hard-kill points and sustained concurrency with an external coordinator.
- Large-prompt behavior near the 1 MiB bound and actual provider context capacity.
- Account-specific plan eligibility, dashboard credit reconciliation and statistically reliable route-retention results.

### First-run checklist (observable)

- [ ] The launcher version, endpoint/auth mode and route fingerprint match the intended roster entry; no unexpected test-mode warning appears.
- [ ] Every turn's init explicitly reports the expected tool array, an empty MCP array, dontAsk, the intended session and the pinned model.
- [ ] Primary assistant events and terminal model usage agree with the pin; unexplained other_models prevents acceptance.
- [ ] Endpoint child_env_allowed contains AUTH_TOKEN, BASE_URL and API_TIMEOUT_MS, excludes ANTHROPIC_API_KEY and model/effort/history overrides, and the provider-side request uses the intended account.
- [ ] A native-schema run contains structured_output that passes reply validation; usable prose or exit code zero alone is insufficient.
- [ ] The tree check is clean, denials are visible, and a timeout continuation cannot conceal an earlier invariant violation.
- [ ] A quota rejection retains its class/reset and makes the other same-plan route unavailable; an auth failure remains route-local.
- [ ] A competing same-plan run produces an observable waiting state until capacity is released, including across repositories.
- [ ] The emitted telemetry contains only closed vendor/model classes and no endpoint URL, roster label, key name or secret.
