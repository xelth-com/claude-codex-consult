# Handoff 22 - Claude (claude): ab-05-claude

Date: 2026-10-08 02:59 local. Author: Claude (claude) (model mimo-v2.6-pro, effort medium), claude-cli 2.1.293.0.
Reviewer: mimo-claude :: mimo-v2.6-pro [claude] (provider from -Provider, model from roster; engine claude (C:\users\dmytro\.local\bin\claude.exe), endpoint https://token-plan-ams.xiaomimimo.com/anthropic (token from env MIMO_API_KEY); provider fingerprint f615a41b2fe4; harness claude-cli 2.1.293.0).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 12 of 12 for -Provider mimo-claude (engine, model applied).
Effort: medium sent (requested medium, mapping claude-v1, by caps-v1: engine:claude, any model; not confirmed by the provider). Consultation id: f64fe439-5f31-4cde-8766-11d032313507.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn's init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply), purpose: checkpoint). Argv: `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model mimo-v2.6-pro --effort medium --json-schema "{"$schema":"http://json-schema.org/draft-07/schema#","title":"codex-consult reply v1","type":"object","additionalProperties":false,"required":["schema_version","verdict","verdict_reason","reply_markdown","findings","prior_findings","unproven","first_run_checklist"],"properties":{"schema_version":{"type":"string","enum":["1"]},"verdict":{"type":"string","enum":["ACCEPT","HOLD","REJECT","ADVISE"]},"verdict_reason":{"type":"string"},"reply_markdown":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["severity","locations","claim","trigger","evidence","verification","remedy","supersedes"],"properties":{"severity":{"type":"string","enum":["blocker","major","minor","note"]},"locations":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line"],"properties":{"path":{"type":"string"},"line":{"type":["integer","null"]}}}},"claim":{"type":"string"},"trigger":{"type":"string"},"evidence":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["kind","reference","observation"],"properties":{"kind":{"type":"string","enum":["read-code","ran-command","inferred","assumed"]},"reference":{"type":"string"},"observation":{"type":"string"}}}},"verification":{"type":"string"},"remedy":{"type":"string"},"supersedes":{"type":"array","items":{"type":"string"}}}}},"prior_findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["id","status","note"],"properties":{"id":{"type":"string"},"status":{"type":"string","enum":["fixed","still-open","not-checked","unknown-id"]},"note":{"type":"string"}}}},"unproven":{"type":"array","items":{"type":"string"}},"first_run_checklist":{"type":"array","items":{"type":"string"}}}}" --session-id 2ad11a65-dc4a-494d-b3c5-c19b5386e765` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `2ad11a65-dc4a-494d-b3c5-c19b5386e765` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md` (sha256 08f0b7610c02). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 584.6 s. Tokens: in 475058 (cached 406784), out 23324, reasoning ?.
Engine turns: 1 (claude -p, auth endpoint; model mimo-v2.6-pro; init tools Glob, Grep, Read, StructuredOutput; permission denials 0).
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint of brief 05 against the current tree: its preflight description is stale in one more way (unknown now refuses, finding #1), F21-1/F21-2/F21-3 all remain accurate, and Q1-Q4 are answered on the current code. Findings: 0 blocker, 0 major, 1 minor, 0 note (F22-1, tracked in `findings.json`). Structured reply: `handoffs/22-claudecode-ab-05-claude.reply.json`.
Raw event stream: `handoffs/22-claudecode-ab-05-claude.events.jsonl`.
Verbatim reply follows.

---

Checkpoint at the current tree (v0.6.0, wave 29c). The brief's `68353d7`/0.3.0 framing is stale (F21-3).

**Drift (brief lines)**
- L7, L19: base commit / "codex-providers.ps1 (new)" - tree is v0.6.0-1-g65380b2; the script is long past 0.3.0 (engine rows, roster, -Short/-Json). Filed: F21-3.
- L19-24: not "builtin openai + [model_providers.*]" alone and not "no network call": agy/muse/claude engine rows exist, and an agy row calls `agy models` (a network round-trip, codex-providers.ps1:116-119). The verdict also reads recorded failures, plan limits and the roster walk; a usage limit older than 24 h still blocks. Under F21-3.
- L25-28, L36-38: a recent usage limit is not warning-only - recorded auth and blocking quota REFUSE unless -SkipPreflight (warning only then); the scan is structured `provider_failure` first (common:5748-65), the `bridge_outcome` regex only for older entries (common:6274-80), with broader quota/auth patterns (common:5751-52). Filed: F21-2.
- L28 "unknown, not refused": inverted now - the code fails closed (finding #1).

**Q1.** Inferable without a network call: credential presence (env_key / bearer / `codex login status`), table usability, effort vocabulary (caps-v1), and endpoint history from this repository's ledgers plus `codex-consult-health.json` - recorded auth (24 h), a quota with `retry_after` or the 60/10-minute windows, a recent usable reply. Not inferable: an expired-but-present key, a revoked token, a wrong-region endpoint - only a real call reveals those. So every failed run must leave `provider_failure {class, kind, code, message<=200, when, retry_after, hint}` on the ledger entry and in the machine-health file, and the coordinator must not count an endpoint whose newest failure is `unknown`/`transport` as usable until a later usable reply. The ledger side exists today; only auth/quota gate the next preflight (common:6312-22) - F21-1's hole.

**Q2.** I do not know Xiaomi MiMo Token Plan's exact live error wordings. The bridge lifts MiMo's SSE `data:{"error":{...}}` rejection shape (common:5821-44) and classifies the message (common:5748-53): "credits exhausted | credit balance | token plan | plan exhausted | insufficient balance | quota | usage limit | 429/402 | billing | resource_exhausted" -> quota; "invalid api key | 401/403 | unauthorized | forbidden | api key | not signed in" -> auth. A bare "invalid credential" or "no credits left" classifies `unknown`. No fixture uses real MiMo wording (tests use "credits exhausted for this token plan").

**Q3.** `error`/`turn.failed` are still lifted into `bridge_outcome` ("failed: codex exit N - <msg>", codex-consult.ps1:1586-1612 and 4824-32) and now also classified into `provider_failure` plus the machine-health record (5561-64, 5597). Enough to block the next preflight only when the message classes as auth or quota - and those refuse rather than warn (F21-2). An `unknown`-class rejection leaves the next preflight "available": not enough (F21-1).

**Q4.** HOLD on the preflight as a diff: the operator's "if no credential, neither call nor count" holds (fail-closed, nothing started, no ledger entry), but a dead-but-present credential is counted on twice whenever its rejection classifies `unknown` (F21-1 - the one item to fix). Unproven: MiMo's real rejection wordings. First-run checklist for THIS consultation: ledger `preflight "ok: env MIMO_API_KEY set"`, lineage `mimo :: mimo-v2.6-pro`, `effort_mapping mimo-v1`, `extra_config` with the catalog path, `usage` from the mimo route, and a parseable schema-v1 JSON reply.

## Requested checks
- **RC1** (finding #1) - working dir: repository root; permission: workspace-write (scratch CODEX_HOME + scratch repo). Run `pwsh -NoProfile -File plugins/codex-consult/scripts/codex-consult.ps1 -Task t -Prompt x -ReplyName r -Provider mimo -Model mimo-v2.6-pro -TimeoutSec 5` with `MIMO_API_KEY` set and `CODEX_CONSULT_EXE` pointing at a missing file. Observe exit 1 with "availability could not be established ... a real run is refused" and no ledger entry - i.e. unknown refuses. Budget: ~2 min.
- **RC2** (F21-1) - working dir: repository root; permission: workspace-write. Fake turn emitting `data:{"error":{"message":"invalid credential"}}` with exit 1 (harness-0.3.ps1 quota-fail case style), then run Get-EndpointHealth/Get-PreflightVerdict over that ledger. Observe provider_failure.class `unknown` and a second preflight still "available". Budget: ~5 min, one harness case.
- **RC3** (F21-2) - working dir: repository root; permission: workspace-write. Seed a ledger quota failure without reset time; run codex-consult.ps1 without -SkipPreflight. Observe a refusal ("usage limit hit <iso>, reset unknown; retry after <iso>"), not warning-only behavior. Budget: ~3 min.

---

### Findings

- **F22-1** [minor] `.collab/ab-mimo-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md:28`, `plugins/codex-consult/scripts/codex-consult-common.ps1:7834`, `plugins/codex-consult/scripts/codex-consult.ps1:3650`, `plugins/codex-consult/scripts/codex-consult.ps1:67` - Brief 05's preflight description says a `login status` that cannot run yields `unknown` and is 'not refused'; the current code fails closed: Get-PreflightVerdict sets a non-empty Refusal for every unknown state (unresolved identity at common:7772-7780, cred.State unknown at common:7834-7838, each labelled 'a real run is refused') and codex-consult.ps1:3650 calls Stop-WithError on any non-empty refusal, so such a run exits 1 with nothing started unless -SkipPreflight. The behaviour is safer than the brief claims; the claim-vs-code drift is the defect - a distinct sentence of the brief from F21-2's items (usage-limit warning-only, scan structure). Trigger: A run whose provider credentials are present but `codex login status` cannot run (launcher missing or non-runnable), without -SkipPreflight. Evidence: read-code: The unknown branches (identity unresolved 7772-7780; cred.State -eq 'unknown' 7834-7838) both set $v.Refusal and a Label ending 'a real run is refused'.; read-code: if ($preflightRefusal -and (-not $DryRun -or $detachForeground)) { Stop-WithError $preflightRefusal } - any non-empty refusal, including unknown, stops the run.; read-code: Header documents 'Preflight (fails CLOSED): ... its availability must be establishable (a resolved identity, a `login status` that answers) ... otherwise the run is refused'.; read-code: The brief still claims 'a `login status` that cannot run -> `unknown`, not refused'. Verify: RC1: run codex-consult.ps1 with a present env key but CODEX_CONSULT_EXE naming a missing file and observe exit 1 with the 'availability could not be established' refusal and no ledger entry. Remedy: Correct handoff 05 line 28 (and anything quoting it) to 'unknown refuses the run - fails closed - unless -SkipPreflight'; leave the code as is.

### Prior findings

- F13-1 - not-checked - Outside brief 05's preflight scope; marker/flush-lock identity code not re-read here. No fix evidence seen.
- F13-2 - not-checked - Outside this preflight checkpoint; Remove-TelemetrySpoolLines not re-read here.
- F13-3 - not-checked - Outside this preflight checkpoint; Exit-TelemetryFlushLock not re-read here.
- F13-4 - not-checked - Outside this preflight checkpoint; repeated-ask truncation not re-read here.
- F13-5 - not-checked - Concerns handoff 01's claims; not re-read in this checkpoint of brief 05.
- F15-1 - not-checked - Kick-ack drift; outside this preflight checkpoint.
- F15-2 - not-checked - Health-warning wording drift; outside this preflight checkpoint.
- F15-3 - not-checked - Stall/tool-cap drift; outside this preflight checkpoint.
- F18-1 - not-checked - Concerns handoff 03's spool claims; not re-read here.
- F18-2 - not-checked - Suite-run claim of handoff 03; no suite run in this read-only checkpoint.
- F20-1 - not-checked - timeout_source roster drift; outside this preflight checkpoint.
- F20-2 - not-checked - harness-visibility suite-count drift; not recounted here.
- F20-3 - not-checked - Commit-framing drift of handoff 04; outside this checkpoint.
- F20-4 - not-checked - Burst-10-minute wording; outside this preflight checkpoint.
- F20-5 - not-checked - Finding-id collision claim; not re-examined here (its ids belong to another task).
- F21-1 - still-open - Re-confirmed on this read: Get-EndpointHealth promotes only Ok/auth (common:6312-13) and Ok/quota (6314-22); Get-PreflightVerdict reads only Health.Auth/Health.Quota (7803, 7811, 7820), so an unknown-class rejection never affects the next preflight. No MiMo-route rejection fixture (tests use generic 'credits exhausted for this token plan'). Not refiled - Q3 restates it.
- F21-2 - still-open - Re-confirmed: Get-PreflightVerdict refuses quota with or without reset (7811-7833) and Format-QuotaWarning is 'with -SkipPreflight only' (7922-7933); the scan is structured provider_failure first (6242-6280). The one item F21-2 did not assert - unknown no longer 'not refused' - is filed separately as finding #1.
- F21-3 - still-open - Re-confirmed: brief line 7 still names 68353d7 (v0.2.0) + uncommitted 0.3.0 while the tree is 0.6.0 wave 29c (codex-providers.ps1 is 0.4.0+, with agy/muse/claude engine rows and a network `agy models` call at its lines 116-119). Not refiled.

## Verdict: ADVISE

Checkpoint of brief 05 against the current tree: its preflight description is stale in one more way (unknown now refuses, finding #1), F21-1/F21-2/F21-3 all remain accurate, and Q1-Q4 are answered on the current code.

### Blockers

_(none)_

### Unproven scenarios

- Xiaomi MiMo Token Plan's exact live rejection wordings for exhausted credits and an invalid key - no live ledger entry or fixture carries them; the classifier's coverage of them is inferred from the quota/auth pattern lists (common:5751-52) and the SSE error-payload lift (common:5821-44).
- Whether a class `unknown` MiMo rejection actually occurs in practice - F21-1's silent hole needs one live case (e.g. 'invalid credential' without a 401/403 marker) to matter.
- The PS 5.1-only fallbacks and the pid-reuse / lock races of F13-1..F13-3 were not exercised in this read-only preflight checkpoint.

### First-run checklist (observable)

_(none)_
