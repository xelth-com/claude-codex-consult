# Handoff 04 - Codex: glm-diff-review

Date: 2026-09-24 05:21 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI/glm-5.3 (provider from -Provider, model from -Model; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Effort: high sent (requested high, mapping zai-v1, by host api.z.ai; not confirmed by the provider). Consultation id: f7c9a770-196a-4c1a-9159-596273db5036.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-73f70482921e46f78a6a718da44d2fe5.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage ZAI/glm-5.3 in this task's ledger; 1 thread(s) recorded before 0.3.0 have unknown provenance and are never automatic parents). Result thread: `01a0d16e-5780-73d3-b462-9d5bc8465d9e` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/03-claude-glm-diff-review.md` (sha256 c8ff9cbcbfed). Reviewed: 68353d7 + uncommitted, base 68353d756cbb581700a0be3d4338cd32a43a1950, tree sha256 b1a9b68973a4, 11 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 611.4 s. Tokens: in 1725053 (cached 1608000), out 24552, reasoning 19953.
Structured reply: INVALID (not valid JSON: Ungültiger JSON-Primitiv: .) - raw text kept; no findings recorded. Raw last message: `handoffs/04-codex-glm-diff-review.reply.json`.
Raw event stream: `handoffs/04-codex-glm-diff-review.events.jsonl`.
Verbatim reply follows.

---

**1** (Q1). Two candidate wrong-identity shapes, both hinging on Codex semantics the repo asserts but does not prove: (a) a user‑defined `[model_providers.openai]` table — the builtin branch at `codex-consult-common.ps1:1950` never reads it; if Codex merges user tables over the built‑in (as codex‑rs historically does), the run is routed to the table's `base_url` while the ledger records `builtin:openai`, and two different overrides collapse to one fingerprint (finding #1). (b) a custom provider table with **no** `wire_api` — line 1988 assumes the default is `responses`; if Codex defaults custom providers to `chat`, the recorded protocol is wrong (finding #2). Everything else I tried (quoted/literal keys, dotted keys, inline tables, duplicate tables/keys, arrays-of-tables, profiles, empty values, unreadable file) degrades to `unknown`/refusal, not a wrong identity.

**2** (Q2). Within its own model of identity, `Select-ParentThread` is tight: `-Thread` requires a same‑lineage, same‑fingerprint, post‑0.3.0 verified thread; legacy entries, unresolved identities and rollout candidates are refused explicitly; automatic selection is lineage‑scoped and drift refuses rather than falls back. The cross‑boundary sequences that remain run through a wrong identity itself (findings #1/#2), plus a narrow thread‑provenance hole: `Get-ThreadIdFromEvents` drift net 1 accepts any top‑level `session_id`/`conversation_id` from any event line, so a future stream echoing a parent id before `thread.started` would be recorded as this run's thread with source `events` (finding #3 — same lineage, so corruption, not crossing).

**3** (Q3). `medium→high`, `xhigh→max` is a sound monotone policy for the z.ai `low|high|max` vocabulary; nothing equivalent to "medium" exists, so collapsing to `high` is the right conservative choice. Nothing in my integration path errored or made `model_reasoning_effort` a no‑op that I can observe: this very run was launched with it (diff‑review preset `high` → `high`, `zai-v1`). Caveat honestly handled by the code: the event stream carries no effort confirmation, so `effort_confirmed: null` is correct; I cannot introspect the wire from inside.

**4** (Q4). I received the full brief, the six open findings, the complete output‑schema block (including the `## Requested checks` convention), the read‑only constraints, and the final line `Consultation id: f7c9a770-196a-4c1a-9159-596273db5036`. My own event stream (`04-codex-glm-diff-review.events.jsonl`) starts with `thread.started` (id `01a0d16e-5780-73d3-b462-9d5bc8465d9e`). Nothing about the z.ai route is missing that I could perceive; the one thing the bridge cannot capture is provider‑side confirmation of model/effort — already recorded as null rather than guessed.

**5** (Q5). **HOLD**, not REJECT: the lineage core is well built and all six prior findings are credibly addressed, but two unverified identity assumptions sit exactly on the claimed invariant "a changed endpoint or protocol refuses reuse", and the 127/127 harness is not in the tree (finding #4), so the claimed coverage is unauditable. First‑run checklist for this consultation, on disk after exit 0: `sessions.json` n=2 with `lineage "ZAI/glm-5.3"`, `reviewer.provider_source "-Provider"`, non‑empty `provider_fingerprint`, `mode "new"` and empty `parent_thread` (legacy n=1 refused), `thread_source "events"` matching the id above, `effort_sent "high"` / `effort_mapping "zai-v1"`, non‑null `usage` from `turn.completed`, `reply_json` byte‑identical to my final message, parsed and schema‑validated locally with all six prior‑finding ids present.

Prior findings: F02‑1 fixed (residual split into finding #1), F02‑2, F02‑3, F02‑4, F02‑5, F02‑9 fixed.

## Requested checks

- **RC1** — In a clone of `github.com/openai/codex` at v0.155.1 (working dir: the clone; read‑only; ~20 min): locate where config `model_providers` are merged with built‑ins (does `[model_providers.openai]` override the built‑in?) and the serde default for `wire_api` on user‑defined providers. Settles findings #1 and #2.
- **RC2** — Working dir: repo root; workspace‑write (scratch `CODEX_HOME` + local request‑logging listener); ~15 min: run `codex-consult.ps1 -DryRun` and one live `codex exec --json` with (a) an `[model_providers.openai]` override table and (b) a table lacking `wire_api`; compare the recorded `provider_config`/fingerprint with the endpoint and wire actually contacted.
- **RC3** — Working dir: repo root; read‑only (temp file); ~5 min: dot‑source the scripts and call `Get-ThreadIdFromEvents` on a file whose first line is `{"type":"turn.started","session_id":"<foreign-uuid>"}`; observation: the foreign uuid is returned (finding #3).
