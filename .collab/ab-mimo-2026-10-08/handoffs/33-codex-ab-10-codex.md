# Handoff 33 - Codex: ab-10-codex

Date: 2026-10-08 09:47 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: d825aaae-7d53-4f24-b3d1-2cb8d6dcc6a0.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-140d51b0e4a74dbb93f7f1f3806b6cec.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a11a7a-fd45-70f1-9f21-bf32bd254cec` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/10-claude-ab-wave28c-acceptance.md` (sha256 b14bbba7c8b8). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 215 s. Tokens: in 313453 (cached 0), out 4488, reasoning 2292.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Current-tree checkpoint confirms most wave-28c behavior but the brief has several claim-versus-code drifts and prior findings remain open. Findings: none. Structured reply (prompt-only transport): `handoffs/33-codex-ab-10-codex.reply.json`.
Raw event stream: `handoffs/33-codex-ab-10-codex.events.jsonl`.
Verbatim reply follows.

---

## 1-10 (claims)
1. Drift: model matching lower-cases and strips a trailing `[1m]`; an empty model is `unknown` (common.ps1:11689-11715).
2. Holds: `-Forget -PublicRef` removes local data only after an intake DELETE; other answers preserve salt/spool/counters; `-Local` warns unless `-Yes` (common.ps1:13126-13227).
3. Holds: one telemetry lock plus `telemetry-forgetting`; producers drop/count events rather than recreate state (common.ps1:11398-11445).
4. Partial drift: living owners are never taken over and tokens are checked before sends/rewrites, but an ownerless lock is refused for 30 s before takeover, not taken over immediately (common.ps1:12654-12700).
5. Holds: 60 s flush deadline, proxy/trust allow-list additions, and bounded/retried spool append with console/status failure reporting (common.ps1:12354-12362).
6. Holds: unreadable descendant start times are unconfirmed (not killed/counted gone); `pgrep` errors are failed enumerations.
7. Holds: unreadable journal lines go to `.bad`, are warned/counted, and truncation follows applied/moved lines.
8. Drift: `compactions: unknown` remains, but the brief-naming prompt tail exists only with a brief file; without one the ask is repeated (codex-consult.ps1:4137).
9. Partial drift: test-mode dry-run behavior holds; the idle watchdog wording is superseded by current revision 6 wording.
10. Stale inventory: 22 harness files exist, with several counts changed (tests/).

## Ask 1
F41-1, F42-1..9, F43-1..7, F44-1..6 are earlier-task ids and are **unknown-id** in this task ledger; current behavior is covered above. F43-6 and F44-3 remain accepted limitations: README:3212-3215 says vendor class derives from host name and can misclassify proxies/relays.

## Ask 2
No new defect beyond the open findings below was established by this read-only pass. In particular, crash-left forgetting markers self-heal, ownerless locks are protected, and journal/spool paths are guarded; the drifts listed in claims 1, 4, 8, 9 and 10 are the actionable discrepancies.

## Ask 3
ADVISE, not ACCEPT: resolve the stale brief/test inventory and wording drifts before acceptance.

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - start_ticks adds no resolution; lock identity remains coarse.
- F13-2 - still-open - PS 5.1 File.Replace fallback remains non-atomic and lacks missing-destination handling.
- F13-3 - still-open - Exit-TelemetryFlushLock delete-after-dispose race remains.
- F13-4 - still-open - REREAD prompt truncation limitation remains.
- F13-5 - still-open - Historical brief wording/count/commit drift remains documented.
- F15-1 - still-open - Kick acknowledgement wording drifted; only id-matched .ack exists.
- F15-2 - still-open - Health warning wording drift remains.
- F15-3 - still-open - Tool-call suspension cap and extra claude engine remain.
- F18-1 - still-open - Spool tmp and per-producer not-spooled wording drift remains.
- F18-2 - still-open - Suite claim is stale and unrerun on current tree.
- F20-1 - still-open - timeout_source roster is a third value.
- F20-2 - still-open - harness-visibility inventory is stale.
- F20-3 - still-open - Commit framing no longer matches tree.
- F20-4 - still-open - Burst 429 ten-minute rule qualifies the 60-minute claim.
- F20-5 - still-open - Finding-id namespace collision remains.
- F21-1 - still-open - unknown provider_failure does not affect endpoint health.
- F21-2 - still-open - Preflight description stale; quota/auth failures now refuse.
- F21-3 - still-open - Version/commit framing stale.
- F22-1 - still-open - Unreadable login status fails closed, contrary to brief.
- F23-1 - still-open - harness-detach inventory stale.
- F23-2 - still-open - Background/file/deviation wording drift remains.
- F23-3 - still-open - Earlier-task finding ids are foreign to this ledger.
- F25-1 - still-open - Repair drift details differ from current implementation.
- F25-2 - still-open - Format-repair drift blind spot for findings[] remains.
- F25-3 - still-open - Prose gate blind corners remain.
- F28-1 - still-open - Prompt assembly order has drifted.
- F28-2 - still-open - Bridge/version framing stale.
- F29-1 - still-open - Renumbered answers evade drift detection.
- F30-1 - still-open - Scrub scope now covers all ZCODE_ variables.
- F30-2 - still-open - Host detection closed set expanded.
- F30-3 - still-open - harness-panel RUN/GUARD description stale.
- F30-4 - still-open - Coordinate rule 3 supersedes addendum clauses 6-7.
- F30-5 - still-open - Verification framing stale.
- F32-1 - still-open - Commit framing stale (git describe v0.6.0-1-g65380b2).
- F32-2 - still-open - Nineteen-harness/count inventory stale; 22 files exist.
- F32-3 - still-open - Ownerless lock is protected for 30 s before takeover.
- F32-4 - still-open - Model-token and prompt-tail wording drift confirmed.

## Verdict: ADVISE

Current-tree checkpoint confirms most wave-28c behavior but the brief has several claim-versus-code drifts and prior findings remain open.

### Blockers

_(none)_

### Unproven scenarios

- Full harness suites were not executed read-only.
- Timing/race scenarios in F13-1..3 were not reproduced.

### First-run checklist (observable)

_(none)_
