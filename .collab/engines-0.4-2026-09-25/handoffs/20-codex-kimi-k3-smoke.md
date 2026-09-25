# Handoff 20 - Codex: kimi-k3-smoke

Date: 2026-09-25 20:45 local. Author: Codex (model k3, effort high), Codex CLI 0.155.1.
Reviewer: kimi :: k3 (provider from -Provider, model from -Model; endpoint https://api.kimi.ai/coding/v1, wire_api: responses; provider fingerprint 8f7901d404b5; harness codex-cli 0.155.1).
Preflight: ok: env KIMI_API_KEY set.
Effort: high sent (requested medium, mapping kimi-v1, by caps-v1: api.kimi.ai, k3; not confirmed by the provider). Consultation id: ccd490f5-b70e-4322-8616-91223634ee5d.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m k3 -c model_reasoning_effort="high" -c model_provider="kimi" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-89d694236cf24821bc7030b79aa5a2c8.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage kimi :: k3 in this task's ledger; other lineage(s): byteplus :: dola-seed-2.0-pro, byteplus :: deepseek-v4.1-flash, byteplus :: kimi-k3, byteplus :: kimi-k2.5, gemini :: gemini-3.8-flash-low [agy], gemini :: gemini-3.8-flash-high [agy], mimo :: mimo-v2.6-pro, ZAI :: glm-5.3). Result thread: `01a0d9e3-2ad1-7f83-889a-65e0e8cc736d` (source: events).
Brief: (none, prompt only). Reviewed: cfd7eef + uncommitted, base cfd7eefa3932753c452f173ec4279e062719ee9b, tree sha256 0e5fb5001cfd, 6 changed files.
Bridge outcome: usable reply. Wall time: 198.3 s. Tokens: in 515430 (cached 409600), out 4617, reasoning 2087.
Verdict: ADVISE - All six prior findings verified fixed in the current code (wave 18); the three questions answered with one behavioral caution on effort mapping. Findings: 0 blocker, 0 major, 0 minor, 1 note (F20-1, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/20-codex-kimi-k3-smoke.reply.json`.
Raw event stream: `handoffs/20-codex-kimi-k3-smoke.events.jsonl`.
Verbatim reply follows.

---

## 1. Identity
I cannot introspect my serving. Given caps-v1 (host api.kimi.ai, vocabulary kimi) and this checkpoint requesting medium → mapped high, I believe I am `k3` at high effort; only the provider response and ledger confirm it.

## 2. medium→high risk
On a per-request plan, reasoning tokens ride inside the request: high effort multiplies latency and token throughput per call, so rate-limit/quota burn and timeout risk grow invisibly — a budgeted "medium" checkpoint can stall or fail, and sent effort no longer matches what the caller planned.

## 3. Schema transport
Prompt-only is the right default for an untrusted endpoint: native-first risks silent non-enforcement discovered only when a prose reply arrives, costing a repair turn. Prompt-only fails loudly and deterministically, and the bridge already has format repair.

## Prior findings
All six verified fixed in code (wave 18); residuals now documented (README F12).

---

### Findings

- **F20-1** [note] `plugins/codex-consult/scripts/codex-consult.ps1:1153` - F10-3's underlying behavior is unchanged: -Provider with several same-label entries still selects the first entry; only a run warning was added, so an inattentive caller can still get the wrong tier. Trigger: A roster with two entries under one provider label and a caller passing only -Provider. Evidence: read-code: First entry of the label is used; a warning 'label X names N entries; the first (...) is used - pass -Model for another' is added to runWarnings, not an error. Verify: Dry-run -Provider with a two-entry label and confirm the selected model plus the warning text in output. Remedy: Optional: refuse ambiguous -Provider without -Model, or surface the warning in the ledger/preflight line where coordinators audit.

### Prior findings

- F09-1 - fixed - Get-CollabSnapshot now covers the whole collab root recursively (every task's findings.json/sessions.json/state.md and handoffs, wave 18 comment at codex-consult-common.ps1:617); Get-EngineTreeProblem compares it. Gitignored/submodule/outside-repo blind spots remain but are now explicitly documented (common comment F12, README:1219-1234 'not for gitignored paths, submodules or files outside the repository').
- F09-2 - fixed - sessions.json entry now carries format_retry and denial_retry records (codex-consult.ps1:2639-2640), each with an events field naming the retry/repair event file (lines 2205, 2424); machine readers no longer need the handoff Markdown.
- F09-3 - fixed - Get-EngineTreeProblem text now reads 'changed during the run (by the reviewer or anyone else)' for tree, collab, brief and artifacts (codex-consult.ps1:579-586); it no longer attributes the change to the reviewer.
- F10-1 - fixed - Same wave-18 widening as F09-1: collab-root snapshot comparison added to the tree check; the remaining unmonitored classes (ignored files, submodules, external paths) are documented in the code comment and README F12 instead of being claimed as enforced.
- F10-2 - fixed - Read-AgyEvents takes -AllowPartialLast; the caller passes it only when the process was killed or exited non-zero (codex-consult.ps1:2126-2127, comment 'after exit 0 trailing garbage makes the stream malformed'; retry path line 2193 mirrors it).
- F10-3 - fixed - Ambiguous -Provider still picks the first entry but is no longer silent: codex-consult.ps1:1152-1156 emits a run warning naming the count, the chosen entry and the -Model remedy.

## Verdict: ADVISE

All six prior findings verified fixed in the current code (wave 18); the three questions answered with one behavioral caution on effort mapping.

### Blockers

_(none)_

### Unproven scenarios

- My actual served model and effort (question 1) — no self-introspection possible; only the provider response/ledger can confirm k3 at high.
- F10-2's malformed-on-exit-0 behavior was verified by reading code and both call sites, not by feeding a corrupted stream to Read-AgyEvents.
- F09-2's ledger shape was verified from record construction (lines 2205, 2424, 2639-2640), not from an actual denial-retry ledger row.

### First-run checklist (observable)

_(none)_
