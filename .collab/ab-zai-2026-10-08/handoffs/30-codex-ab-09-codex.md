# Handoff 30 - Codex: ab-09-codex

Date: 2026-10-08 02:38 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: e19dc76f-bc98-4289-b33b-c2c5f9b81c63.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-d666fc367e8545e8877a810085c53a80.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118f2-89f1-73b0-8f3c-f4ce0cb73cef` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/09-claude-ab-wave27b-addendum.md` (sha256 dd8a19c11bc7). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 275.7 s. Tokens: in 1284732 (cached 1216192), out 9538, reasoning 5191.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint: B1-B3 and B8 hold, B9's clauses (6)-(7) and B1/B2's letter are stale exactly as prior findings F29-1/F29-2 record, and all 25 prior findings remain open unchanged. Findings: none. Structured reply: `handoffs/30-codex-ab-09-codex.reply.json`.
Raw event stream: `handoffs/30-codex-ab-09-codex.events.jsonl`.
Verbatim reply follows.

---

## Answers to the brief's numbered items

**F1 (inherited Claude markers)** — Holds and is fully covered today: `$script:HostMarkerNames` (codex-consult-common.ps1:7024-7030) lists every name the fact names, exact only — not the whole `CLAUDE_CODE_` prefix; `CLAUDE_PLUGIN_ROOT`/`CLAUDE_PLUGIN_DATA` are not scrubbed, as decided.

**F2 (Z Code)** — Substance holds, letter drifted (F29-1): wave 27c (D20/D21) widened the scrub and the host hint from the exact `ZCODE_SESSION_ID`/`ZCODE_PROJECT_DIR`/`ZCODE_PLUGIN*` names to the whole `ZCODE_` prefix and any set `ZCODE_` variable (common.ps1:7031, 7241), because the Z Code shell tool carries neither of the two exact names.

**F3 (Kimi Code)** — Holds: README's Install section documents the `--skills-dir` clone, Git Bash shell, no hooks, and AGENTS.md read from the working directory only (README.md:169-189).

**F4 (no self-compact on Claude Code)** — Still recorded: the coordinate skill's "Means per host" says COMPACT has no agent means (verified 2026-09-29, `/compact` arrives as text).

**B1** — Holds as a superset of the decision: exact Claude names plus the whole `ZCODE_` prefix; `CODEX_SANDBOX` is also scrubbed (added later). Letter drift is prior finding F29-1, not re-filed.

**B2** — Order codex → zcode → claude-code → unknown holds, but detection is wider than the decision's two names (any `ZCODE_` variable) and the `unknown` fallback gained a path-anchored hint (wave 28b D11) including `~/.zcode/cli/plugins/cache/` and `~/.qwen/extensions/` (qwen-code). Covered by F29-1.

**B3** — Holds: README Install has "Z Code" (:144) and "Kimi Code" (:169) sections (plus Qwen/OpenCode/Muse added later); "Hooks on each host" names Kimi Code's lack of hooks (:306); the coordinate skill's "Means per host" names both.

**B8** — Holds: harness-detach SINGLE holds the fake reviewer on `FAKE_CODEX_HOLD_FILE` with `FAKE_CODEX_HOLD_SEC` 120 (harness-detach.ps1:436-439); assertions were extended (test-mode warning line) but the release mechanism is intact.

**B9** — Clauses (1)-(5) hold in substance. Clauses (6)-(7) are stale (F29-2): the current rule 3 has eight numbered rules; there is no wake-3 handover for unknown-end work (running work keeps the wake armed), and revision 6 (operator decision 2026-09-30) replaced the ~9-hour cutoff with "keep the cache warm always while work runs" plus a per-context/model price table; the auto-compact lever is unchanged.

## Prior findings

All 25 listed ids were re-checked read-only against the current tree; every one remains present, none fixed. No new findings: every defect seen is an already-listed one whose claim is unchanged.

## Requested checks

- RC1: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1` (repo root, read-only would need workspace-write for TEMP logs, ~30-60 min) — confirms the 22-harness suite and the PASS counts behind F13-1/F17-2/F19-1/F23-1/F25-1.
- RC2: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-host.ps1` (repo root, workspace-write, ~5 min) — confirms the widened ZCODE_ marker scrub and host hint (F29-1).
- RC3: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28e.ps1` (repo root, workspace-write, ~10 min) — confirms the per-producer not-spooled fold (F17-1).

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - 22 harness-*.ps1 in tests/; harness-fixes28d has exactly 40 Check calls; run-all registers 22.
- F13-2 - still-open - Open-TelemetrySpoolFile returns $null for a missing file (common.ps1:11867); Remove-TelemetrySpoolLines then reports 'stayed busy' (:12579).
- F14-1 - still-open - Flush checks only lock ownership, then calls the rewrite with Math.Max(100, remaining) (common.ps1:12918-12922).
- F15-1 - still-open - Wait-EngineProcess cuts at 2 x StallSec of no stream growth while a tool is open (D12 block, common.ps1:10960+).
- F16-1 - still-open - -Kick acknowledges only via <kick file>.ack within 10 s; no 'kicked' pending state (codex-consult.ps1:1277).
- F16-2 - still-open - Current warnings are the cause-bearing journal texts at the commit and after the retry (codex-consult.ps1:6076, 6122).
- F16-3 - still-open - Header comment still says 'never cut' five lines above the D12 2 x StallSec note.
- F17-1 - still-open - Per-producer telemetry-not-spooled-<pid>-<ticks>.ndjson plus flush fold confirmed (common.ps1:12096+).
- F17-2 - still-open - tests/README.md:23 still says 'twentieth harness'; run-all.ps1 registers 22 and its own header says twenty-two.
- F19-1 - still-open - harness-visibility.ps1 has 122 Check calls, not 76.
- F21-1 - still-open - Get-EndpointHealth selects Auth/Quota only for classes auth/quota; 'unknown' failures set LastFailure but never block (common.ps1:6310-6326).
- F21-2 - still-open - Format-QuotaWarning warns only with -SkipPreflight; a blocking usage limit refuses (common.ps1:7926).
- F21-3 - still-open - Get-EndpointHealth merges machine-wide entries and cross-route fingerprints (wave 29b E5).
- F22-1 - still-open - ConvertFrom-ProviderErrorText lifts SSE/JSON payloads first; quota pattern covers credits/402/billing/resource_exhausted/rate_limit_exceeded etc.
- F23-1 - still-open - harness-detach.ps1 has 51 Check calls (CARRY case present).
- F23-2 - still-open - -Prune also removes never-started/unreadable files older than 7 days (codex-consult.ps1:1367+).
- F24-1 - still-open - Inline -Prompt goes to .consult.detached-<id8>.prompt.txt; record args name only PromptFile (codex-consult.ps1:1101+).
- F25-1 - still-open - harness-format.ps1 has 37 Check calls.
- F25-2 - still-open - Get-FormatRepairDrift checks ids/numbers/verdict/>=60-char sentences only; findings[] field edits pass undetected.
- F25-3 - still-open - Numbered-style reasons ('1.', '2.') or marker words ('verdict', F-ids, RC<n>) suppress the refusal test.
- F25-4 - still-open - 'A1:'/'Answer 1:' styles match no NumberedAnswerRe alternative; <120 words is 'reply too short'.
- F27-1 - still-open - Repair turn fully implemented: eligibility via Get-ProseGate, .original.md copy, drift notes, ledger format_retry (codex-consult.ps1:5221+).
- F28-1 - still-open - Structured prompt opens with the FINAL OUTPUT CONTRACT before the ask (codex-consult.ps1:4054+).
- F29-1 - still-open - B1/B2 widened: whole ZCODE_ prefix scrub, any ZCODE_ var hints, anchored path fallback incl. qwen-code.
- F29-2 - still-open - B9 (6)/(7) replaced by revision 6: keep warm always while work runs; price table; no wake-3 clause, no 'nine hours'.

## Verdict: ADVISE

Checkpoint: B1-B3 and B8 hold, B9's clauses (6)-(7) and B1/B2's letter are stale exactly as prior findings F29-1/F29-2 record, and all 25 prior findings remain open unchanged.

### Blockers

_(none)_

### Unproven scenarios

- No harness or script was executed (read-only session); all PASS-count and runtime-behaviour claims rest on code reading.
- The '(+n more lines)' cut of multi-line inline asks (F17-1's second half) was inferred from wave-28e comments, not executed.
- Get-ProseGate edge cases (F25-3/F25-4) were verified by reading the regex and floors, not by calling the function.

### First-run checklist (observable)

_(none)_
