# Handoff 35 - Codex: ab-12-codex

Date: 2026-10-08 03:13 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 3da2eea5-1dc2-4c88-b764-b814abba99f5.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-08d166e550d648beb2b070ecce364702.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a11912-93ae-7aa0-9760-06d2169b132e` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/12-claude-ab-glm-diff-review.md` (sha256 f1a6117ca5bc). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 861.8 s. Tokens: in 2486808 (cached 2398720), out 20266, reasoning 13319.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: (invalid: ACCEPT not allowed for purpose checkpoint). Findings: 0 blocker, 0 major, 2 minor, 0 note (F35-1..F35-2, tracked in `findings.json`). Structured reply: `handoffs/35-codex-ab-12-codex.reply.json`.
Raw event stream: `handoffs/35-codex-ab-12-codex.events.jsonl`.
Verbatim reply follows.

---

**Q1.** No shape found that records a wrong identity through the constrained scanner: anything it cannot prove (profile key, dotted keys, arrays/inline tables, duplicate keys, unreadable file) adds a note, `Resolved` flips false, the fingerprint stays empty and the run is never a parent (codex-consult-common.ps1 2396-2546, Get-ProviderSetProblem 2294). The one residual is a user-defined `[model_providers.openai]` table: the code states Codex's merge-over-builtin is unverified (2386-2389) yet uses the table (2520-2530, noted in identity_note); if Codex ignores it, the ledger records the table's endpoint — wrong, not unknown — though the differing fingerprint still blocks reuse with builtin-openai threads (finding #2).

**Q2.** No crossing sequence found. `-Thread` and automatic selection both require an entry with `reviewer` + `provider_fingerprint` (legacy, unresolved and rollout-candidate entries excluded, Find-ThreadEntry 9186-9219), then Test-SameReviewer (provider+model+engine, ordinal, 9162-9168), then an equal fingerprint — endpoint/protocol drift refuses reuse (9244, 9278). The wave-24 exception (killed non-codex run's `thread_candidate` + `partial_reply`) is `-Thread`-only and passes the same gates; codex candidates never count. Secrets and key order never enter the fingerprint (2366-2368).

**Q3.** The mapped value is sent as `-c model_reasoning_effort=` on every codex turn (4239; continuation 5080; repair re-maps to the vocabulary's lowest value, 5270 + 1767-1774) — nothing in the path makes it a no-op. medium→high collapses medium/high by design; xhigh→max assumes z.ai accepts `max`, unverifiable from inside; `effort_confirmed` stays null (2749). This reply completing is weak evidence the sent value did not error.

**Q4.** I received the FINAL OUTPUT CONTRACT paragraph first, the brief path, the open-findings list, the closing `Consultation id: 3da2eea5-…` line, and the read-only/word-limit constraints. Not visible from my side: the effort actually applied (no confirmation event) and whether z.ai enforced the JSON schema (its transport is accept-without-enforce) — the bridge records neither.

**Q5.** **ACCEPT.** The claimed invariants hold on the current tree (identity/lineage/fingerprint; thread provenance via thread.started or a rollout containing the consult id, 1671; atomic writes 194; held-handle lock 9301+; pending record and validation present). Drift: the brief's 127/127 for harness-0.3.ps1 is stale — 183 Check calls now (finding #1); lineage displays `ZAI :: glm-5.3`, not `ZAI/glm-5.3`. All 31 prior findings re-checked read-only: every one still-open, none fixed (22 harnesses, visibility 122, detach 51, format 37, panel 62; README still says "twentieth").

## Requested checks
- RC1: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-0.3.ps1` (repo root, workspace-write, ~10 min): all 183 checks pass, including scanner/identity cases.
- RC2: scratch-task structured consult `-Provider ZAI -Model glm-5.3 -Effort xhigh` (workspace-write): usable reply with ledger `effort_sent max`, `effort_mapping zai-v1` — settles whether z.ai accepts `max`.
- RC3: with a usable user `[model_providers.openai]` table, run one codex consult and inspect the endpoint Codex actually contacted (rollout config/traffic) — settles finding #2.

---

### Findings

- **F35-1** [minor] `.collab/ab-zai-2026-10-08/handoffs/12-claude-ab-glm-diff-review.md:49`, `tests/harness-0.3.ps1:1` - The brief's evidence claim 'harness-0.3.ps1: 127/127' is stale: the current harness has 183 Check calls after later waves extended it; the 0.3 substance (config resolution, scanner, fingerprint, parent selection, rollout correlation, effort, peak) is unchanged. Trigger: Counting Check calls in tests/harness-0.3.ps1 against the brief's Evidence section. Evidence: ran-command: 183 matches. Verify: Run tests/harness-0.3.ps1 and confirm 183 PASS lines. Remedy: Update the brief's count (or annotate that later waves grew the harness).
- **F35-2** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2386`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2487`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2529` - A user-defined [model_providers.openai] table is used as the resolved identity although Codex's precedence over the built-in openai provider is unverified (acknowledged only in a comment and an identity_note); if Codex ignores the table, the ledger records a wrong endpoint instead of unknown, though the differing fingerprint still prevents reuse with builtin-openai threads. Trigger: A config with a usable [model_providers.openai] table while Codex routes the built-in endpoint. Evidence: read-code: Comment admits the merge is unverified; the code takes the table's endpoint and marks the identity resolved (infos do not force unresolved). Verify: With such a table, run one consult and compare the endpoint Codex actually contacted with reviewer.provider_config. Remedy: Verify the precedence once; if unknown, treat a user [model_providers.openai] table as unresolved (never a parent) rather than resolved.

### Prior findings

- F13-1 - still-open - Re-verified: 22 harness-*.ps1 files; harness-fixes28d has exactly 40 Check calls.
- F13-2 - still-open - Line 12579 still returns 'stayed busy' when Open-TelemetrySpoolFile yields no handle (missing file).
- F14-1 - still-open - Line 12922 still passes Math.Max(100, remaining) after only the lock check; no literal deadline re-check.
- F15-1 - still-open - Wait-EngineProcess cuts at 2 x StallSec without stream growth while a tool is open (11030-11037).
- F16-1 - still-open - No 'kicked' pending-record state exists; only <kick file>.ack with the 10 s wait (850, 1277-1281).
- F16-2 - still-open - New cause-bearing warning texts at 6076/6122; the brief's literal string is gone.
- F16-3 - still-open - Header comment at 10960-10962 still says 'never cut', contradicting D12 at 10973-10978 and the code.
- F17-1 - still-open - Per-producer not-spooled files plus fold (12148+, 12982, 12999) and '(+n more lines)' reread (4135) confirmed.
- F17-2 - still-open - tests/README.md:23 still says 'twentieth' while run-all.ps1 registers 22.
- F19-1 - still-open - harness-visibility.ps1 has 122 Check calls, not 76.
- F21-1 - still-open - Get-EndpointHealth marks availability only from auth/quota records (6312-6321); class unknown only reaches LastFailure.
- F21-2 - still-open - Format-QuotaWarning returns '' unless -SkipPreflight (7926-7928); a blocking limit refuses the run.
- F21-3 - still-open - Machine-wide records merge into Get-EndpointHealth (6194-6198); codex-providers exit 1 for usage errors (120-121).
- F22-1 - still-open - Payload-first classifier (5562-5564, 5662, 5748-5753) with the widened quota pattern confirmed.
- F23-1 - still-open - harness-detach.ps1 has 51 Check calls.
- F23-2 - still-open - -Prune also removes never-started/unreadable files older than 7 days (1376-1387).
- F24-1 - still-open - Inline prompt travels via .consult.detached-<id8>.prompt.txt; record args name only PromptFile (1096-1107).
- F25-1 - still-open - harness-format.ps1 has 37 Check calls.
- F25-2 - still-open - Get-FormatRepairDrift never compares findings[] fields (1793-1834).
- F25-3 - still-open - Markers (numbered lines, F-ids, RC, 'verdict') still suppress the refusal test (1752-1753).
- F25-4 - still-open - Unrecognized numbering styles with <120 words still yield 'reply too short' (1738, 1754-1755).
- F27-1 - still-open - Format-repair retry fully implemented (1720-1724, format_retry ledger fields).
- F28-1 - still-open - Prompt opens with the FINAL OUTPUT CONTRACT paragraph before the ask (4054).
- F29-1 - still-open - Whole ZCODE_ prefix scrubbed (7031, 7241).
- F29-2 - still-open - No wake-3 or nine-hours clause; revision 6 cache-warm rule and auto-compact lever (29, 54, 65).
- F31-1 - still-open - run-all.ps1 registers 22 harnesses; visibility has 122 Check calls.
- F31-2 - still-open - Ownerless flush lock counts as held under 30 s (12654, 12698-12699).
- F31-3 - still-open - Closing line repeats the one-line ask / first line plus '(+n more lines)' (4135-4136).
- F33-1 - still-open - harness-panel.ps1 has 62 Check calls.
- F33-2 - still-open - Get-PanelPlan caps groups by their plan's parallel value (8866, 8886).
- F33-3 - still-open - Get-PanelMemberGuard adds -Repair/-DenialRetry (min 300 s) and -ContinueSec (8934-8942).

## Verdict: (invalid: ACCEPT not allowed for purpose checkpoint)

Codex answered ACCEPT (The re-asked invariants hold on the current tree; only stale evidence counts and one documented openai-table precedence uncertainty remain.); no verdict was recorded: verdict ACCEPT is not allowed for purpose checkpoint (expected ADVISE).

### Blockers

_(none)_

### Unproven scenarios

- z.ai accepts model_reasoning_effort 'max' for glm-5.3 (the xhigh mapping); no confirmation event exists and effort_confirmed is null.
- Codex honors a user-defined [model_providers.openai] table over its built-in endpoint (finding #2).
- No harness was executed in this read-only consultation; all check counts cited are static Check-call counts, not PASS-line counts.

### First-run checklist (observable)

- [ ] Ledger entry for consultation 3da2eea5-1dc2-4c88-b764-b814abba99f5 with reviewer provider ZAI, model glm-5.3, engine codex, non-empty provider_fingerprint, lineage 'ZAI :: glm-5.3'.
- [ ] effort_requested/effort_sent/effort_mapping recorded (zai-v1; sent 'max' if xhigh was asked) with effort_confirmed null.
- [ ] usage non-null from a turn.completed event on the z.ai route.
- [ ] thread recorded from thread.started or from a rollout file containing this consultation id.
- [ ] This reply present as exactly one bare JSON object, parsed and validated locally against the reply schema.
