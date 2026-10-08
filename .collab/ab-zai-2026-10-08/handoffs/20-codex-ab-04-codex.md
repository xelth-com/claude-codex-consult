# Handoff 20 - Codex: ab-04-codex

Date: 2026-10-08 01:58 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 4929e037-879e-4fdb-933a-b0df2295d158.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-aca1b981df4243b5b16d43dfd8444038.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118cd-ce54-7fa1-8d03-24c326a9517f` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md` (sha256 105cd6dbd192). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 189.4 s. Tokens: in 671904 (cached 566080), out 9431, reasoning 6209.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint: the wave-24 invariants still hold in the current code and every remaining drift is an already-filed stale count or wording, so no new blocker or major exists. Findings: none. Structured reply: `handoffs/20-codex-ab-04-codex.reply.json`.
Raw event stream: `handoffs/20-codex-ab-04-codex.events.jsonl`.
Verbatim reply follows.

---

## Answers

**Preamble note.** HEAD is `b0fa03c` (wave 29c), not the brief's `65f5649`; per the brief's header I answered against the current tree.

**1. Ruling of the listed open findings.** All ten are still-open and unchanged in the current code (per-entry notes in `prior_findings`):

- **F13-1** — 22 `tests/harness-*.ps1` files exist (`harness-claude`, `harness-fixes28e` included); `harness-fixes28d.ps1` still has exactly 40 `Check` calls.
- **F13-2** — `Open-TelemetrySpoolFile` returns `$null` for a missing file (common.ps1:11867), yet `Remove-TelemetrySpoolLines` reports "stayed busy" (12579).
- **F14-1** — the flush checks only lock ownership before the delivered-line rewrite and passes `Math.Max(100, remaining)` (12922), so a rewrite can start after the deadline.
- **F15-1 / F16-3** — `Wait-EngineProcess` cuts a turn with an open tool after 2×`StallSec` without stream growth (~11023); the wave-26c comment "never cut" (~10959) still contradicts the D12 note (~10972).
- **F16-1** — `-Kick` acknowledges only via `<kick file>.ack` with its id, waiting up to 10 s (codex-consult.ps1:1287-1298); no pending-record state `kicked` exists.
- **F16-2** — the literal old warning is gone; current texts carry a cause plus journal note (codex-consult.ps1:6076, 6122).
- **F17-1** — not-spooled is per-producer files plus the flush fold (`not_spooled_seen`/`not_spooled_folded`, common.ps1:12096-12196); the reread line repeats the ask's first line + "(+n more lines)", cut at 300 (codex-consult.ps1:~4143).
- **F17-2** — tests/README.md:23 still says "twentieth harness"; run-all.ps1 registers 22.
- **F19-1** — `harness-visibility.ps1` has 122 `Check` calls, not the brief's 76.

**2. Wave-24 surface on the current tree.** Verified by reading code:

- **Continuation** (codex-consult.ps1 ~5002-5080): one turn on the same thread (codex resume / agy conversation / muse session), finish-now prompt, `-ContinueSec` default `min(timeout, 900)`; not attempted for `-ContinueSec 0`, unknown thread, survivors, unconfirmed kill, changed tree/brief/artifacts, quota/billing/auth failure (and agy proof failure); ledger `timeout_continue {thread, wall_seconds, outcome, events, usage}`; `bridge_outcome "usable reply (after a timeout continuation)"`; the panel-member guard includes `ContinueSec` (2912/4277).
- **Salvage**: `.partial.md` from the captured stream (5614-5651), ledger `partial_reply`, the summary names it, resume command supplied (~5719).
- **Timeouts / -Range**: per-purpose defaults incl. acceptance 3600 s (2024-2027), `timeout_source` in the ledger, `git diff --shortstat` numbers, >1500 lines with timeout <2400 s warns (2030-2033).
- **Availability**: `Select-PanelMembers -NoNetwork`, providers rows/`-Short`/`-Short -Json`/hook on the walk's verdict, `endpoint health:` source line (codex-providers.ps1:464), `LAST FAILURE` column (465), reset-less usage limit blocks exactly 60 minutes.
- **F15-1**: muse `auth.json` re-read `-Fresh` right before launch (common.ps1 3590-3597, 3915+).

Claim 6's counts are stale (F19-1, F13-1, F17-2). No new blocker or major defect in the wave-24 surface itself.

**3.** ADVISE — the wave-24 invariants still hold; the only drift is the already-filed stale counts/wordings (documentation-level).

## Requested checks

- **RC1** — Command: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1`; working directory: repository root; permission: read-only (writes logs only under `%TEMP%`); observation: 22 `ok` summary lines including `harness-fixes28e` and `harness-claude`, exit 0; budget: ~15 min.
- **RC2** — Command: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-visibility.ps1 -ScriptsDir plugins/codex-consult/scripts` then count `^PASS` lines; working directory: repository root; permission: read-only (%TEMP% only); observation: 122 PASS lines, exit 0 — settles F19-1's current pass state; budget: ~3 min.

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - 22 harness-*.ps1 files counted (harness-claude and harness-fixes28e present); harness-fixes28d.ps1 still has exactly 40 Check calls.
- F13-2 - still-open - Open-TelemetrySpoolFile returns $null for a missing file (common.ps1:11867) and Remove-TelemetrySpoolLines still returns 'stayed busy' (common.ps1:12579).
- F14-1 - still-open - Flush rewrite still starts on lock ownership only, with WaitMs Math.Max(100, remaining) at common.ps1:12922, so it can begin after the deadline.
- F15-1 - still-open - Wait-EngineProcess still cuts a tool-open turn after 2 x StallSec without stream growth (~common.ps1:11023), matching the finding; not run.
- F16-1 - still-open - -Kick waits only for <kick file>.ack with its id, up to 10 s (codex-consult.ps1:1287-1298); no pending-record state 'kicked' is used.
- F16-2 - still-open - Old literal warning absent; current cause-bearing texts plus journal at codex-consult.ps1:6076 and 6122.
- F16-3 - still-open - The 'never cut' comment (~10959) still contradicts the D12 note (~10972) and the stall-cut body.
- F17-1 - still-open - Per-producer not-spooled files plus flush fold (not_spooled_seen/not_spooled_folded, common.ps1:12096-12196) and the '(+n more lines)' 300-char reread line (codex-consult.ps1 ~4143) confirmed present.
- F17-2 - still-open - tests/README.md:23 still says 'twentieth harness'; tests/run-all.ps1 registers 22 harnesses, harness-claude last.
- F19-1 - still-open - 122 Check calls counted in tests/harness-visibility.ps1 vs the brief's 76.

## Verdict: ADVISE

Checkpoint: the wave-24 invariants still hold in the current code and every remaining drift is an already-filed stale count or wording, so no new blocker or major exists.

### Blockers

_(none)_

### Unproven scenarios

- No harness was executed in this read-only consultation, so the current pass/fail state of the 22 harnesses is unverified.
- Runtime behavior of the timeout continuation, salvage and availability paths was verified by reading code only, not by driving a run.

### First-run checklist (observable)

_(none)_
