# Handoff 16 - Codex: ab-02-codex

Date: 2026-10-08 01:57 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 4aaf48eb-5e48-433b-a4d4-52fab795f2f4.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-22c96b24b37e475cb41ac9875b2d91df.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118cd-63ee-7123-a8f5-c1648942e715` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/02-claude-ab-wave26c-decisions.md` (sha256 087f36fa4147). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 765.3 s. Tokens: in 1033889 (cached 146304), out 20248, reasoning 17083.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint review: the current tree matches D4-D6 and the behavioural parts of D1-D3, but the brief's wording for D1-D3 is stale. Findings: none. Structured reply (prompt-only transport): `handoffs/16-codex-ab-02-codex.reply.json`.
Raw event stream: `handoffs/16-codex-ab-02-codex.events.jsonl`.
Verbatim reply follows.

---

Checked current tree (post-wave-29c); the brief's wave-26/27 references are historical.

D1. Kick acknowledgement — behaviour holds (kick checked before the wait, on each poll, and after exit; late kick recorded `kick_late`; `-Kick` waits 10 s). Drift: acknowledgement is only `<kick file>.ack {id, result: stopped|late}`; there is no pending-record `kicked` state. Exit codes are 0/1/3, plus 4 for a refused status query (F15-1).

D2. Health update loss — 5 s x 3 attempts and one retry at ledger commit hold; `until`/`retry_after` are preserved and ties resolve to newest `when`, then later `until`. Drift: warnings read `machine-wide health not updated at the commit (...)` or `... by the retry after the commit (...)`, not `machine-wide health not updated (lock timeout)`; the health journal now keeps the record too (F15-2).

D3. Stall detection — byte-growth reset and tool suspension hold, and the continuation says `no output for N s outside a tool call`. Drift: suspension is capped at 2 x `-StallSec` of no stream growth and then the stall cut fires naming the open call, so `one long command is never cut` is conditional; `claude` `tool_use`/`tool_result` is also supported (F15-3).

D4. Legacy rating completion — holds: `Test-BlankField` treats absent, null, empty, whitespace and blank lists as missing; `JOINBLANK` covers an empty `model`.

D5. Size raised by required reviewers — holds: `panel size raised: asked k, required r`, `size_asked`, `size_source: required`, and the dry-run Routing line show the request.

D6. F26-6 — holds as documented in README `Roles`: hard links remain indistinguishable; the check covers reparse points and containment, not a hostile repository.

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - Partly fixed: the marker now records full-resolution `start_ticks`; the flush-lock record still stores only pid+start_time, so the pid-reuse risk remains.
- F13-2 - still-open - PS 5.1 `File.Replace` fallback still lacks a missing-destination branch.
- F13-3 - still-open - `Exit-TelemetryFlushLock` still deletes after the read handle is disposed.
- F13-4 - still-open - Multi-line inline asks still repeat only the first line plus a line count.
- F13-5 - still-open - The checkpoint drift persists: spool files are per-producer, harness count is 22, and the old commit references are stale.
- F15-1 - still-open - Kick ack is `.ack` only; no `kicked` state, and exit 4 exists for refused queries.
- F15-2 - still-open - Health warning wording changed and the journal keeps the record.
- F15-3 - still-open - `never cut` is conditional on the tool cap, and `claude` tool events are supported.

## Verdict: ADVISE

Checkpoint review: the current tree matches D4-D6 and the behavioural parts of D1-D3, but the brief's wording for D1-D3 is stale.

### Blockers

_(none)_

### Unproven scenarios

- The pid-reuse and lock-delete race cases in F13-1/F13-3 were not executed here.

### First-run checklist (observable)

_(none)_
