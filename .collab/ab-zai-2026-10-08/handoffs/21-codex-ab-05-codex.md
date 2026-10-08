# Handoff 21 - Codex: ab-05-codex

Date: 2026-10-08 02:01 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 40e4e358-36b1-43dc-a310-f971f70442d7.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-f98ed78d6303402d917bfe8a20dbf290.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118d0-d834-7a42-a8a7-f8ed0900c09c` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md` (sha256 08f0b7610c02). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 294.9 s. Tokens: in 1569423 (cached 1509632), out 9947, reasoning 4880.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint preflight review: the mechanism is sound and fail-closed, with two documentation drifts and one inherent silent-unknown edge reported as findings. Findings: 0 blocker, 0 major, 1 minor, 2 note (F21-1..F21-3, tracked in `findings.json`). Structured reply: `handoffs/21-codex-ab-05-codex.reply.json`.
Raw event stream: `handoffs/21-codex-ab-05-codex.events.jsonl`.
Verbatim reply follows.

---

## Answers

**Q1.** Without network the bridge infers: credential *presence* only — `env_key` set and non-empty or `experimental_bearer_token`; builtin/`requires_openai_auth` via local `codex login status` (15 s); engines via `agy models` (45 s, skipped after a usable reply ≤ 60 min), claude/muse local checks. Everything else comes from records: per-`provider_fingerprint` health from all task ledgers **plus the machine-wide health file/journal** — auth failure ≤ 24 h, quota with reset ahead, quota without reset hit < 60 min (burst < 10 min), cross-route plan quotas (wave 29b E5), and `engine_run.quota_mark` on usable replies (E15). The ledger stores `preflight`, `preflight_warning`, `provider_failure {class, kind, code, message ≤200, when, retry_after, hint}`; a dead provider refuses the next run until a newer usable reply clears it — the coordinator cannot count on it twice.

**Q2.** I do not know MiMo's exact credit-exhaustion/invalid-key wording; this repository's 24 MiMo ledger entries contain no such failure (only feature-not-supported, timeout, model-name errors). Confirmed: MiMo rejects via SSE `data:{"error":{code,message,...}}`, which `ConvertFrom-ProviderErrorText` lifts (common.ps1:5805). It is then caught only if the message matches the quota/auth regexes; other wording → `unknown`.

**Q3.** Today: `bridge_outcome = "failed: codex exit N - <tail>"`; `provider_failure = New-ProviderFailure` over (last SSE data line, event error, stderr tail, outcome) at codex-consult.ps1:5564, written to `sessions.json` and the machine-wide record before commit (journal + retry). Next preflight reads all of that and refuses on auth/quota. It is enough **iff** the text classifies; a bare exit code with no payload classifies `unknown`, which `Get-EndpointHealth` ignores — the endpoint silently stays "available" (finding #1).

**Q4.** ACCEPT as a diff, no blockers. Ordering holds (effort at :3591, preflight :3634–3650, peak/lock after; refusal exits before any ledger entry). Drift vs the brief: the scan is no longer "this repository's ledgers within 24 h" (machine-wide + plan quotas; exit 1 added); a usage limit is no longer "warning only" — it refuses unless `-SkipPreflight` (finding #2/#3). Unproven: real MiMo quota/auth wording; no harness run (read-only). First real run should show `preflight "ok: ..."`, the MiMo lineage, effort mapping, extra_config, usage, and a parsed JSON reply.

---

### Findings

- **F21-1** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:5564`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5758` - A first-request rejection whose evidence matches none of the failure-class patterns (e.g. a bare non-zero exit with no SSE payload, no event error, no diagnostic stderr) is recorded as provider_failure class 'unknown', which Get-EndpointHealth ignores, so the next preflight still reports the endpoint available — the silent-failure case the review asks about. Trigger: Provider rejects a key with wording outside the quota/auth regexes and no JSON error payload. Evidence: read-code: provider_failure is built only from SSE data lines, eventError, stderrTail and bridge_outcome via New-ProviderFailure.; read-code: Get-EndpointHealth only marks Auth (class auth) and Quota (class quota) records; 'unknown' never makes the endpoint out. Verify: Force a fake codex to exit 1 printing only a plain line, then run codex-providers.ps1 -Provider <name> and confirm the verdict stays available with last_failure.class unknown. Remedy: Keep the newest 'unknown' failure per endpoint in the machine-wide health as a soft signal surfaced by preflight/codex-providers (a warning, not a refusal), so an unclassifiable dead provider is at least visible.
- **F21-2** [note] `.collab/ab-zai-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md:26`, `plugins/codex-consult/scripts/codex-consult-common.ps1:7926` - The brief's claim that a usage limit hit within the last hour yields 'warning only' is stale: since wave 24b (F08-7) every still-blocking usage limit refuses the run; Format-QuotaWarning emits a warning only under -SkipPreflight. Trigger: Preflight with a recorded usage limit still in force and no -SkipPreflight. Evidence: read-code: Format-QuotaWarning returns '' unless SkipPreflight; Get-PreflightVerdict refuses on a blocking quota. Verify: Record a quota failure in a test ledger and run without -SkipPreflight: the run is refused, not warned. Remedy: Update the handoff wording to the current fail-closed behavior.
- **F21-3** [note] `.collab/ab-zai-2026-10-08/handoffs/05-claude-ab-mimo-preflight-review.md:21`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6186`, `plugins/codex-consult/scripts/codex-providers.ps1:120` - The brief's claim that the usage-limit scan reads 'this repository's ledgers within 24 h' is stale: Get-EndpointHealth also merges the machine-wide health file/journal (all repositories, wave 26b D13) and cross-route plan quotas (wave 29b E5), and codex-providers adds exit code 1 for usage errors. Trigger: A quota recorded in the machine-wide health or on another route of the same plan. Evidence: read-code: Get-EndpointHealth appends ConvertTo-MachineHealthEntries for every fingerprint; plan quotas via Get-PlanQuotaVerdict.; read-code: Exit codes now document 1 usage error in addition to 0/2/3. Verify: Record a quota only in the machine-wide health file and confirm codex-providers -Provider reports it. Remedy: Refresh the handoff description to the current sources and exit codes.

### Prior findings

- F13-1 - still-open - 22 harness-*.ps1 files counted; harness-fixes28d still has exactly 40 Check calls.
- F13-2 - still-open - Open-TelemetrySpoolFile returns $null for a missing FileMode.Open file; Remove-TelemetrySpoolLines still reports 'stayed busy'.
- F14-1 - still-open - The flush still calls Remove-TelemetrySpoolLines with Math.Max(100, remaining) after only the lock check; no literal deadline check before the rewrite.
- F15-1 - still-open - Wait-EngineProcess still cuts after 2 x StallSec without stream growth while a tool is open (D12 ToolOpen/OpenTools), contradicting the stale 'never cut' invariant.
- F16-1 - still-open - -Kick still waits only on <kick file>.ack {id, result} for up to 10 s; no 'kicked' pending-record state exists.
- F16-2 - still-open - The old literal warning is gone; the cause-bearing commit/retry texts are present at codex-consult.ps1:6076 and :6122.
- F16-3 - still-open - The Wait-EngineProcess header still says 'never cut' five lines above the wave-28b D12 note describing the 2 x StallSec cut.
- F17-1 - still-open - Add/Get/Merge-TelemetryNotSpooled per-producer files still exist (12096/12196/12267); the old handoff's D4/D7 single-file wording remains stale.
- F17-2 - still-open - tests/README.md line 23 still calls harness-claude the twentieth harness while 22 exist.
- F19-1 - still-open - harness-visibility.ps1 has 122 Check calls, not 76.

## Verdict: ADVISE

Checkpoint preflight review: the mechanism is sound and fail-closed, with two documentation drifts and one inherent silent-unknown edge reported as findings.

### Blockers

_(none)_

### Unproven scenarios

- Exact Xiaomi MiMo credit-exhaustion and invalid-key error wording was not verifiable from this repository's ledgers or code comments.
- No harness or preflight script was executed (read-only consultation); code paths were verified by reading only.

### First-run checklist (observable)

_(none)_
