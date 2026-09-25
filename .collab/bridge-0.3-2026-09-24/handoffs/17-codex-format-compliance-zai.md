# Handoff 17 - Codex: format-compliance-zai

Date: 2026-09-24 21:28 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 2 of 3, panel 9e96bc8f member 1 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 55cc73c4-8077-45b7-a774-2f2cf406db0f.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-92618ff663ba426d98854273867aa1ee.md fork 01a0d3f7-1cb2-71e2-8fed-29a3aa9fd408 -` (prompt on stdin).
Parent thread: `01a0d3f7-1cb2-71e2-8fed-29a3aa9fd408`. Result thread: `01a0d4e3-a0de-7d81-a8d5-562d0435acb3` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/16-claude-format-compliance.md` (sha256 d7be7ff3ecf2). Reviewed: a743d81, base a743d81627efefa7201eef2af68734c95db6d5cc, tree sha256 0e0f47f40965, 0 changed files.
Bridge outcome: usable reply. Wall time: 237.8 s. Tokens: in 5645496 (cached 4943232), out 55922, reasoning 44808.
Verdict: ADVISE - The diagnosis is wording/position, not transport, and a single gated one-turn resume retry with cheap drift checks is safe and sufficient. Findings: none. Structured reply (prompt-only transport): `handoffs/17-codex-format-compliance-zai.reply.json`.
Raw event stream: `handoffs/17-codex-format-compliance-zai.events.jsonl`.
Verbatim reply follows.

---

**Q1.** On the z.ai/GLM route the envelope ask is buried: it sits at `codex-consult.ps1:1364` mid-prompt, followed by ~25 lines of field semantics, the full JSON Schema (prompt-only), then "Constraints: … keep reply_markdown under N words", then the id footer. The prompt's end — the strongest attention position — is all about producing a normal Markdown answer; the one-machine-readable-object rule is ~40 lines earlier. The decisive sentence is "write it exactly as you would a normal reply. This is what people read": it authorizes normal-reply behavior, and both my failures complied with it at the wrong layer — n=2 (with `--output-schema`) and n=8 (prompt-only) each emitted the "normal reply" as the entire final message, complete with a `## Requested checks` section, instead of embedding it in `reply_markdown`. The brief reinforces it ("answer by number, under 700 words" reads as chat), the schema text is noise, and Codex's system prompt frames the turn as an agent report, not machine output. Transport is not the variable — both transports failed identically. Single change: delete "as you would a normal reply" and move a hard imperative to the very end, just before the Consultation id: "FINAL MESSAGE: exactly one bare JSON object — no fence, no prose before or after. The Markdown answer goes only inside its reply_markdown string." Confidence ~85%: wording and position explain both failures; a guarantee still needs the retry.

**Q2.** Retry = one `codex exec resume <thread> -` turn, effort low, schema text only, never re-sending the brief (the thread already holds it; re-answering invites drift). Cheap drift checks before ingest: (1) the RC id set/count from the prose's `## Requested checks` equals the JSON's; (2) the count of numbered Q-answers matches the brief's questions; (3) every prior-finding id → status pair mentioned in prose appears identically; (4) the verdict token, if the prose stated one, matches; (5) the five longest whitespace-normalized sentences of the prose appear inside `reply_markdown`. Any mismatch → `drift_note`, `structured` stays false, the prose remains the reply of record. Ledger, on the SAME entry: `format_retry {attempted, succeeded, thread, wall_seconds, drift_note}`; keep the first-turn `validation_error`; `reply_json` = the repaired object byte-for-byte; the handoff `.md` keeps the ORIGINAL prose verbatim with a "format-repaired (turn 2)" header line.

**Q3.** One attempt, default-on, on every route — not only `prompt-only` (my n=2 failed under `--output-schema`) — gated on: not `-Raw`/chore; `bridge_outcome` already "usable reply"; JSON/schema validation failed; and the prose is substantive (≥ ~40 words and at least one numbered answer). The case it must NEVER fire on: a provider-level failure (codex exit 1 — quota, auth, timeout): there is nothing to convert, and a retry burns another call against an endpoint preflight just learned is dead.

**Q4.** ADVISE. (a) First-turn: "Your ENTIRE final message must be exactly one bare JSON object (schema_version \"1\") — no code fence, no text before or after. The Markdown answer lives only inside its reply_markdown string; each defect goes in findings[]. A prose final message cannot be ingested, however good the answer is." (b) Repair: "Your last message was prose, not the required JSON. Reply with exactly one bare JSON object satisfying the schema below — no fence, nothing before or after. Convert, do not re-answer: copy your previous content unchanged (same Q1..Qn answers, same findings, severities and RC ids; nothing added, dropped, softened or renumbered). Output only the JSON object."

## Requested checks

- **RC1** — Working dir: repo root; read-only; 2 min: after this consultation, read this run's `sessions.json` entry (`structured`, `validation_error`, reply path). Observation: whether this very reply ingests as bare JSON under the current prompt settles the wording diagnosis on my route.
- **RC2** — Working dir: repo root; workspace-write (scratch harness fixture); ~30 min: fake codex returns prose on turn 1 and JSON on `resume`; assert `format_retry` fields recorded, original prose preserved verbatim, and a dropped finding is caught by the drift checks.

---

### Findings

_(none)_

### Prior findings

- F02-4 - fixed - caps-v1 keys effort by endpoint host with a per-host model allowlist; undeclared model/host refuses without -NativeEffort (verified in the wave-10 review of this code).
- F06-1 - fixed - A usable user [model_providers.openai] table is now read for identity; an unusable ancestor leaves identity unresolved.
- F06-2 - fixed - Reviewer identity compared field-by-field (provider, model, ordinal); the ' :: ' string is display only.
- F06-3 - fixed - Peak re-evaluated at launch, before Start-Process; the reservation is withdrawn when OffPeakOnly crosses into peak.
- F06-4 - fixed - Exceptions stored as date intervals, no enumeration guard, no silent truncation.
- F12-1 - still-open - Anonymous limb fixed by roster "auth": "none"; the rotated-credential limb still has only -SkipPreflight (now named in the refusal) — a grep of the CLI/providers surface found no narrower declaration.
- F15-1 - fixed - Wall times resolved through TimeZoneInfo transition rules (ConvertTo-WallOffset); README/tests claim DST fixtures; not rerun by me.
- F15-2 - fixed - Legacy re-parse pinned with -ReferenceOffset and README/tests claim pwsh timestamps keep their offset; mechanism not independently rerun.
- F15-3 - fixed - Invariant formally narrowed and tested: surviving processes stop later members (state 'survivors' refuses), with a TEST hook for it.
- F15-4 - fixed - Future-stamped records have their age clamped to 0 instead of being skipped (F15-4 note in code).

## Verdict: ADVISE

The diagnosis is wording/position, not transport, and a single gated one-turn resume retry with cheap drift checks is safe and sufficient.

### Blockers

_(none)_

### Unproven scenarios

- F15-* fixed statuses rest on code reading plus README/harness claims (227/227, 113/113); I did not rerun the harness read-only.
- Whether the recommended first-turn wording actually fixes my route is untested until this consultation and one more are ingested.
- The repair-retry design and its drift checks are proposed only — nothing is implemented to observe.

### First-run checklist (observable)

_(none)_
