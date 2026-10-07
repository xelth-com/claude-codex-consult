# Handoff 22 - Claude (claude): smoke-mimo-native

Date: 2026-10-07 04:06 local. Author: Claude (claude) (model mimo-v2.6-pro, effort medium), claude-cli 2.1.292.0.
Reviewer: mimo-claude :: mimo-v2.6-pro [claude] (provider from -Provider, model from roster; engine claude (C:\users\dmytro\.local\bin\claude.exe), endpoint https://token-plan-ams.xiaomimimo.com/anthropic (token from env MIMO_API_KEY); provider fingerprint f615a41b2fe4; harness claude-cli 2.1.292.0).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/AppData/Local/Temp/claude/C--Users-Dmytro-claude-codex-consult/3e7ca0bd-b95a-43fd-96e9-33788e0af7a8/scratchpad/roster-endpoint.json - entry 12 of 13 for -Provider mimo-claude (engine, model applied).
Effort: medium sent (requested medium, mapping claude-v1, by caps-v1: engine:claude, any model; not confirmed by the provider). Consultation id: d7f9556d-ea3c-4539-ac26-c18eed12f5c2.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn's init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply), purpose: checkpoint). Argv: `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model mimo-v2.6-pro --effort medium --json-schema "{"$schema":"http://json-schema.org/draft-07/schema#","title":"codex-consult reply v1","type":"object","additionalProperties":false,"required":["schema_version","verdict","verdict_reason","reply_markdown","findings","prior_findings","unproven","first_run_checklist"],"properties":{"schema_version":{"type":"string","enum":["1"]},"verdict":{"type":"string","enum":["ACCEPT","HOLD","REJECT","ADVISE"]},"verdict_reason":{"type":"string"},"reply_markdown":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["severity","locations","claim","trigger","evidence","verification","remedy","supersedes"],"properties":{"severity":{"type":"string","enum":["blocker","major","minor","note"]},"locations":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line"],"properties":{"path":{"type":"string"},"line":{"type":["integer","null"]}}}},"claim":{"type":"string"},"trigger":{"type":"string"},"evidence":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["kind","reference","observation"],"properties":{"kind":{"type":"string","enum":["read-code","ran-command","inferred","assumed"]},"reference":{"type":"string"},"observation":{"type":"string"}}}},"verification":{"type":"string"},"remedy":{"type":"string"},"supersedes":{"type":"array","items":{"type":"string"}}}}},"prior_findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["id","status","note"],"properties":{"id":{"type":"string"},"status":{"type":"string","enum":["fixed","still-open","not-checked","unknown-id"]},"note":{"type":"string"}}}},"unproven":{"type":"array","items":{"type":"string"}},"first_run_checklist":{"type":"array","items":{"type":"string"}}}}" --session-id a9e70e3c-8cb5-4581-9519-c8bfd93757d7` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage mimo-claude :: mimo-v2.6-pro [claude] in this task's ledger; other lineage(s): openai :: gpt-6-astra, meta :: muse-spark-1.3-contributor [muse], byteplus :: dola-seed-2.0-pro, kimi :: k3, ZAI-claude :: glm-5.3 [claude], mimo :: mimo-v2.6-pro, ZAI :: glm-5.3, gemini :: gemini-3.1-pro-high [agy]). Result thread: `a9e70e3c-8cb5-4581-9519-c8bfd93757d7` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md` (sha256 02c75199ae43). Reviewed: 11af9bc, base 11af9bc1e6e56d66aabd362c83a0b2e5e6270429, tree sha256 5fccf28ff1a0, 0 changed files.
Bridge outcome: usable reply (after a timeout continuation). Wall time: 901.3 s. Tokens: unknown.
Engine turns: 2 (claude -p, auth endpoint; model mimo-v2.6-pro; init tools Glob, Grep, Read, StructuredOutput; permission denials 0).
Timeout: 900 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Timeout continuation: the main turn was killed at 901.3 s of 900 s; one continuation turn on thread `a9e70e3c-8cb5-4581-9519-c8bfd93757d7` answered in 223.9 s. Tokens of that turn: in 259700 (cached 245760), out 18727, reasoning ?.
Verdict: ADVISE - E12-E16 are largely consistent with D1-D12 and E1-E11 and match the code, but E15 contradicts D6 outright and four smaller wording/behavior mismatches should be corrected in the decision record. Findings: 0 blocker, 1 major, 3 minor, 1 note (F22-1..F22-5, tracked in `findings.json`). Structured reply: `handoffs/22-claudecode-smoke-mimo-native.reply.json`.
Raw event stream: `handoffs/22-claudecode-smoke-mimo-native.events.jsonl`; further turns: `handoffs/22-claudecode-smoke-mimo-native.continue.events.jsonl`.
Verbatim reply follows.

---

**Brief shape.** Handoff 21 contains no Q-numbered questions; its numbered items are decisions E12-E17. Checkpoint answers by id, then contradictions by decision id.

**E12** - consistent in substance with D1/D6 (proof judged even on a kill, salvage kept, summary names the init problem). Two wording gaps: it calls an apiKeySource problem a "capability or permission problem" although that class is `auth` (E3), and it restricts D6's continuation rule without declaring D6 amended (E13 declares its D4 amendment explicitly). Code matches: `Get-ClaudeInitProblem` runs in the `$Pre` branch and `ProofProblem` blocks continuation.

**E13** - consistent with D4's helper-model reservation and F18-2's verify. Its wording contradicts D4/E2: "equal the pinned id after the `[1m]` strip" is unsatisfiable for an alias pin (`sonnet` vs `claude-sonnet-5-5`); the code correctly compares to the init's resolved id.

**E14** - matches the parser (`InitLacks` over model/permissionMode/tools/mcp_servers; apiKeySource absent -> null). Tension with E3: on api-key/subscription turns a missing apiKeySource removes the very billing proof those modes rely on, yet is not a failure.

**E15** - **contradicts D6.** D6 makes a rejecting `rate_limit_event` class `quota` (a failed turn); E15 keeps the reply usable with only a warning plus a health mark, and does not amend D6 by name. Its "burst 429 -> 10 minutes" clause is also unreachable on this path: the mark text always contains "usage limit", so `Get-FailureKind` never returns `burst`.

**E16** - consistent with E7 and the code (`plan` on running rows, `Get-MachineRunningCount -Plans`, wait message names the plan). Residual: a plan's default limit 1 silently caps D5's label `parallel` raise unless `parallel.<plan>` is also raised.

**E17** - a correction of brief 14, consistent with D1; `$ClaudeTools` includes `StructuredOutput` and the argv sends three tools.

**Contradictions by id: E15<->D6 (real); E13<->D4 (alias wording); E12<->E3 (class labels); E14<->E3 (missing apiKeySource accepted); E16<->D5 (parallel raise ineffective for planned entries).**

## Requested checks
- **RC1:** CWD repository root; **workspace-write**. Run `powershell -NoProfile -File tests/harness-claude.ps1` and require the E12-E16 ACCEPT section green (F20-1..4, F18-2, F10-4). Budget: one run, 15 minutes.
- **RC2:** CWD repository root; **read-only**. In a PowerShell session dot-source `plugins/codex-consult/scripts/codex-consult-common.ps1` and print `New-ProviderFailure -Texts @('usage limit reached (claude rate_limit_event rejected, five_hour); resets at <future ISO>') -Class 'quota'` (finding #3). Expect `kind` empty and a 60-minute out, contradicting E15's burst clause. Budget: 5 minutes.

---

### Findings

- **F22-1** [major] `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md:27`, `.collab/claude-engine-2026-09-30/handoffs/05-claude-claude-engine-decisions.md:50` - E15 contradicts D6: D6 classifies any rate_limit_event whose status rejects the request as class quota (a failed turn), while E15 keeps the reply usable and records only a warning plus a health mark; E15 never declares D6 amended, unlike E13 which explicitly amends D4. Trigger: A turn emits rate_limit_info.status='rejected' and then a successful nonempty result (the F20-4 scenario). Evidence: read-code: D6: 'a rate_limit_event whose status rejects the request is class quota'.; read-code: E15: 'The reply stays usable' with a warning and a health mark; no amendment of D6 named.; read-code: Code follows E15 on the success path (warning + QuotaMark), while comments still cite D6 for quota evidence at 5202. Verify: Replay the rejection-plus-success fixture and confirm the decision record names one rule: either D6 is amended to 'rejecting event on a failed turn is quota; on a usable turn it is a warning + mark', or E15 is reverted. Remedy: Amend D6 explicitly in E15's text ("D6 is amended accordingly") to scope class quota to failing turns and define the usable-turn behavior as the sole rule.
- **F22-2** [minor] `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md:18`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5129` - E13's rule that every assistant message.model must equal 'the pinned id after the [1m] strip' contradicts D4/E2's alias resolution: an alias pin (e.g. sonnet) can never equal the served full id, so literal E13 would fail every alias-pinned turn. The code compares against the init's resolved id instead. Trigger: A subscription turn pinned to an alias whose init resolves to claude-sonnet-5-5 and whose assistant events carry that full id. Evidence: read-code: E13 wording: 'must equal the pinned id after the [1m] strip'.; read-code: Implementation compares AssistantModels to $Events.InitModel (the init's id) with exact match, not to the raw pin. Verify: Unit-check Get-ClaudeServedModelProblem with Pinned 'sonnet', init model claude-sonnet-5-5 and assistant model claude-sonnet-5-5; it must pass, which the literal E13 text forbids. Remedy: Reword E13 to 'the init event's resolved id (the pin after alias resolution and the [1m] strip)'.
- **F22-3** [minor] `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md:30`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5801` - E15's promised health mark 'a burst 429 -> 10 minutes' cannot occur on the E15 path: QuotaMark text always begins 'usage limit reached/usage limit:', which matches QuotaWindowPattern, so Get-FailureKind never returns burst and the mark runs the full 60 minutes. Trigger: A rejecting rate_limit_event of burst type (no usage window) followed by a successful result. Evidence: read-code: quotaText always contains 'usage limit reached (claude rate_limit_event ...)'.; read-code: QuotaWindowPattern matches 'usage[ _]?limit', excluding the burst branch at 5801. Verify: Run RC2 (New-ProviderFailure on the E15 mark text) and observe kind '' and a 60-minute out. Remedy: Classify burst from RateLimitType/raw event before synthesizing the text, or drop the burst clause from E15.
- **F22-4** [minor] `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md:26`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5102` - E14 makes a missing apiKeySource a non-failure (older CLIs), but for auth api-key and subscription the per-turn billing proof IS apiKeySource; with the field absent those modes pass with no proof of what billed the turn, undercutting E3's proof model. Trigger: An older CLI emits init without apiKeySource on an api-key roster entry. Evidence: read-code: E14: 'apiKeySource missing is recorded as null (older CLIs) - not a failure'.; read-code: InitKeySources empty yields no badKey, so the want-check passes silently. Verify: Replay an init without apiKeySource under auth api-key and confirm the turn is accepted with no auth evidence recorded. Remedy: Either require apiKeySource on subscription/api-key turns (endpoint keeps the null rule), or record the proof gap as a warning and exclude such turns from billing claims.
- **F22-5** [note] `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md:12`, `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md:35` - Two wording defects in the decision record: E12 labels an apiKeySource problem 'a capability or permission problem' although that class is auth (E3), and E16's plan default 1 silently caps D5's label parallel raise, so D5's 'the roster's parallel may raise it' is ineffective for entries that carry a plan unless parallel.<plan> is also raised. Trigger: An operator raises parallel on two claude labels of one plan, or reads E12's class list against E3. Evidence: read-code: E12 groups 'a wrong apiKeySource' under capability/permission, then says 'with that class'.; read-code: Get-PanelPlan: a label's parallel value is then capped by each plan's limit (default 1 at 8831). Verify: Build a panel of two same-plan claude labels with parallel raised on both labels only; the plan group must still serialize at 1. Remedy: Fix E12's class wording to name auth for apiKeySource, and state in E16 that parallel.<plan> is required to raise a planned entry.

### Prior findings

- F02-1 - not-checked - Collab tracker marks implemented (D1 strict tree); not re-verified in this checkpoint.
- F02-2 - not-checked - Allowlist per D2; not re-read in this checkpoint.
- F02-3 - not-checked - Shared model table/telemetry claim; not re-verified here.
- F02-4 - fixed - Panel serialization (D5) plus machine-wide plan/fingerprint counting (E16) close the scheduling half; residual kill/concurrency durability under F04-1/2.
- F02-5 - fixed - Quota half superseded by F20-4 and closed by E15; denial/resume rules per D6/P1/P6. Live boundary shapes remain unproven.
- F03-1 - not-checked - Strict-tree attribution; carried from handoff 20, not re-verified here.
- F03-2 - not-checked - Env allowlist for api-key mode; not re-read here.
- F03-3 - not-checked - Shared child-env builder for preflight; not re-read here.
- F03-4 - not-checked - CLAUDE_CODE_SKIP_PROMPT_HISTORY exclusion; not re-read here.
- F03-5 - not-checked - CLAUDE_CODE_EFFORT_LEVEL exclusion; not re-read here.
- F03-6 - fixed - Superseded by F20-2; closed by E13's assistant-message model proof.
- F03-7 - not-checked - Health key per auth mode/family (D7); not re-verified here.
- F03-8 - not-checked - MaxModelSteps -> --max-turns (D8/P2); not re-verified here.
- F03-9 - not-checked - Preflight loggedIn=false precedence (D3); not re-verified here.
- F04-1 - not-checked - Shared ~/.claude races; P7 observation only, no sustained integrity test.
- F04-2 - not-checked - Kill-point transcript durability; P6 one observation only.
- F07-1 - not-checked - Token-weighted z.ai credits correction; not re-verified here.
- F07-2 - not-checked - Kimi endpoint correction; not re-verified here.
- F07-3 - not-checked - Route fingerprint vs plan key (E5); not re-verified here.
- F07-4 - still-open - AUTH_TOKEN-only contract is unproven for every documented provider; E12-E16 do not address it.
- F07-5 - not-checked - Endpoint telemetry classification (E6); not re-verified here.
- F07-6 - not-checked - Terms eligibility per account (E9); not re-verified here.
- F07-7 - not-checked - Non-inference egress claim; not re-verified here.
- F08-1 - not-checked - Telemetry host-first classification (E6); not re-verified here.
- F08-2 - not-checked - [1m] strip for all vendors (E6); not re-verified here.
- F08-3 - not-checked - One plan on two routes (E5/E7); partially covered by E16 but not re-tested here.
- F08-4 - fixed - Endpoint mode is implemented (E1/E3/E4/E11: local preflight, apiKeySource none accepted, ANTHROPIC_API_KEY fails). Wire-level credential proof remains unproven (RC3).
- F08-5 - not-checked - Prompt-count billing measurement; not re-verified here.
- F08-6 - not-checked - API_TIMEOUT_MS in endpoint env (E4); not re-verified here.
- F09-1 - not-checked - Engine-vendor shortcut in telemetry; not re-verified here.
- F09-2 - not-checked - Get-CoordinatorMatch hardcoded anthropic; not re-verified here.
- F09-3 - fixed - Closed by E11 (endpoint refuses Anthropic ids) plus observed apiKeySource none; wire capture still open in unproven.
- F09-4 - not-checked - [1m] strip under vendor zai (E6); not re-verified here.
- F10-1 - fixed - E5's two identities implemented (plan excluded from route fingerprint; plan propagation via Get-PlanQuotaVerdict).
- F10-2 - fixed - Endpoint env injection (E4) plus E11 model refusal close the auth-reuse hole; observed source none accepted.
- F10-3 - not-checked - Telemetry third-party coverage (E6); not re-verified here.
- F10-4 - fixed - E16 adds plan to running rows and Get-MachineRunningCount -Plans; engine-wide claude group kept (E7/D5). Residual: shared-state durability under F04-1.
- F10-5 - still-open - Retention-gate power and per-version/endpoint capability smoke are still deferred; E12-E16 do not address them.
- F16-1 - fixed - E11 refusal present in Get-ClaudeModelProblem (claude-* and closed-table ids refused on endpoint).
- F18-1 - fixed - E11 removes subscription-servable ids from the endpoint scope; independent wire-level credential proof remains unproven.
- F18-2 - fixed - Assistant-message half closed by E13 (capability failure); the non-main modelUsage half is deliberately kept as a warning by E13 (helper model).
- F20-1 - fixed - E12 implemented: init/model proof runs in the Pre branch (5231-5244) and ProofProblem blocks continuation.
- F20-2 - fixed - E13 implemented: foreign assistant message.model fails with class capability (5129-5130).
- F20-3 - fixed - E14 implemented: InitLacks over model/permissionMode/tools/mcp_servers fails the turn (4944-4953, 5088-5089).
- F20-4 - fixed - E15 implemented: rejecting event warns, QuotaMark recorded, health quota_mark applied (5354-5360, 6663-6671). Decision-level conflict with D6 filed as finding #1.

## Verdict: ADVISE

E12-E16 are largely consistent with D1-D12 and E1-E11 and match the code, but E15 contradicts D6 outright and four smaller wording/behavior mismatches should be corrected in the decision record.

### Blockers

_(none)_

### Unproven scenarios

- All E12-E15 fixtures are fake-stream only; no live CLI turn has demonstrated the killed-init judgment or the rejecting rate_limit_event path.
- Wire-level endpoint credential proof (token actually sent, login never billed) is still only P8-P11 plus E11's model restriction (RC3 outstanding).
- Real rate_limit_event field shapes and burst typing are unobserved; the burst mark path is theoretical (finding #3).
- F04-1/F04-2 concurrency and kill-point durability remain single-observation (P6/P7).

### First-run checklist (observable)

_(none)_
