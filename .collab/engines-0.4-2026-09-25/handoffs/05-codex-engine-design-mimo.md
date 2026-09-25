# Handoff 05 - Codex: engine-design-mimo

Date: 2026-09-25 11:01 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 3, panel a243bb61 member 2 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: be01fdc4-473f-4a3c-9e66-bb9c2bdf4580.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-eba6650fc9594c73b8911cb727f4855d.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage mimo :: mimo-v2.6-pro in this task's ledger; other lineage(s): ZAI :: glm-5.3). Result thread: `01a0d7cc-107c-7172-80e7-1a20119c4305` (source: events).
Brief: `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md` (sha256 687ddade26c4). Reviewed: 7f46fe4, base 7f46fe49e2c26f9d650fad63e7063ce612b122f1, tree sha256 4c9d0f35d4ce, 0 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 573.5 s. Tokens: in 707432 (cached 136448), out 11211, reasoning 6549.
Verdict: ADVISE - The adapter direction is sound, but four design gaps threaten read-only execution, reply preservation, thread identity, and review independence before implementation begins. Findings: 1 blocker, 4 major, 0 minor, 0 note (F05-1..F05-5, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/05-codex-engine-design-mimo.reply.json`.
Raw event stream: `handoffs/05-codex-engine-design-mimo.events.jsonl`.
Verbatim reply follows.

---

## Framing first
The brief conflates an engine adapter, an identity policy, and a conversation policy. Unlisted options are: a generic `EngineAdapter` boundary with per-engine argv/parse/failure hooks rather than `agy` branches throughout; `new`/`resume`/`append-to-named-thread` as explicit policies per purpose; a cached availability result with TTL and `not checked`; and treating `native` schema as a guarantee versus a hint that still requires local validation. I would need a real agy error corpus, observed `structured_output` edge cases, a stable account/auth identifier, measured resume token growth, and denial semantics before choosing.

**Q1.** Prefer stdin: it removes Windows argv quoting and 32 KB limits. The stream risk is that malformed NDJSON, premature EOF, or a `result` lacking `structured_output` can look like a prose reply; argv is simpler and acceptable only for bounded smoke tests. Pin UTF-8 NDJSON, one event, explicit EOF, and exactly one `result`.

**Q2.** Recording requested effort with `sent=null` and `model-tier` is right: model id is lineage identity. Mapping effort onto suffixes would silently change reviewer identity. `-NativeEffort` should be refused when it conflicts with the tier, not delegated to agy. `panel: weighty` only selects participation; it does not route to `gemini-3.1-pro-high`. Add `weighty_model` or purpose-to-model mapping.

**Q3.** Fail closed. Ingesting a replacement conversation hides that the answer was produced in a different context and breaks lineage provenance. Failure hides usable content, but D4's explicit saved-file-plus-ledger reference preserves it. Do not make the new id a parent.

**Q4.** Default `new`, with explicit `-Mode resume`. Resume saves prompt/history cost and preserves continuity, but grows context, leaks prior consultations into later judgments, and makes repeated reviews non-independent. Framing and acceptance should normally be fresh; resume is appropriate only for deliberate follow-ups.

**Q5.** `agy models` is acceptable for a real preflight but too slow/stateful for the hook. The hook should say `not checked` and optionally use a short-TTL cache. I know no reliable network-free signed-in evidence: `agy --help` has no auth status, and Credential Manager visibility is unproven.

**Q6.** Quota: `RESOURCE_EXHAUSTED`, 429, quota/usage limit/credits exhausted. Auth: `UNAUTHENTICATED`, `PERMISSION_DENIED` only when authorization-related, not signed in/login required/invalid credential. Capability: unknown model, invalid model selection, unsupported effort/schema/argument. Transport: `UNAVAILABLE`, `DEADLINE_EXCEEDED`, DNS/TLS/reset/EOF, malformed JSONL. Learn `retry in 32s`, `try again in/after`, `available again in`, `resets at`, `until`, ISO timestamps, and numeric `Retry-After`.

**Q7.** Require exit 0, `SUCCESS`, exactly one result, nonempty `structured_output`, local schema validation, and a nonempty stable conversation id; require UUID only if observed as guaranteed. Fail resume-not-found, partial/empty output, duplicate/missing results, and JSON parse errors. Content-affecting soft-denials must fail or invalidate evidence; harmless notices may warn.

**Q8.** `-List`, `-Stats`, findings, and scoreboard consume ledger identity/reply fields, not filenames. However current code hardcodes `NN-codex-...` for reply/events/reply.json and `.original.md`; parameterize the engine token. `command` is display/audit only, so `agy ...` is safe.

**Q9.** First add the case where schema is honoured but `structured_output` is absent while `response` contains extra keys. For quoting, feed the `.cmd` fake a file over stdin containing quotes, backslashes, `%VAR%`, newline, and Unicode; hash stdin bytes and compare with the source file while asserting the prompt is absent from argv.

**Q10.** D3/D7 risk the nothing-lost invariant unless raw output is materialized and named before parsing; D5 weakens one-reviewer/one-endpoint identity; D2 loses the 0.3.0 read-only sandbox guarantee; D4 changes fresh-review behaviour. D6 preserves fail-closed only if cached unknown never becomes available.

---

### Findings

- **F05-1** [major] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:61`, `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:69`, `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:77` - D2's `--sandbox` does not establish the 0.3.0 read-only review guarantee, and D3 turns potentially content-affecting soft-denials into warnings. Trigger: An agy run attempts an approval-required tool or workspace write while producing a schema-valid answer. Evidence: read-code: `--sandbox` permits workspace reads and soft-denies approval-required tools while exiting 0.; ran-command: Help describes `--sandbox` only as terminal restrictions; no read-only sandbox value is shown.; read-code: The codex route sends sandbox `read-only`, so agy would weaken an existing review guarantee. Verify: Run agy with the design argv and a prompt requesting a workspace write; inspect stderr and compare repository hashes before and after. Remedy: Combine plan mode with sandbox, reject write-capable modes, hash the workspace, and fail any soft-denial that affects evidence.
- **F05-2** [blocker] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:70`, `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:101`, `plugins/codex-consult/scripts/codex-consult.ps1:1776` - D3/D7 do not specify artifact-first preservation, so a crash can leave a usable agy reply only inside events output while the recovery record names a nonexistent reply file, breaking the nothing-lost invariant. Trigger: The bridge crashes after agy writes a result but before reply extraction and the ledger commit. Evidence: read-code: Only stdout events are guaranteed saved; byte-for-byte reply preservation is specified only for the resume-mismatch case.; read-code: Current code copies the raw reply before parsing and names it in the ledger.; read-code: Current repair flow saves the original prose and updates the recovery record before starting repair. Verify: Kill the bridge immediately after a fake agy result, then inspect `.consult.pending.json` and every referenced handoff path. Remedy: Extract `structured_output` or response to atomic reply artifacts first, update the recovery record with their real paths, then parse, repair, and commit the ledger.
- **F05-3** [major] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:88`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2298` - A constant `sha256("cc-engine-v1|agy")` fingerprint proves only the engine; it does not bind the Google account, credential, or launcher, so the one-reviewer/one-endpoint invariant is not enforced across account changes. Trigger: The same roster label and model resume a thread after the keyring credential or launcher identity changes. Evidence: read-code: The fingerprint is constant for all agy entries while credentials live in the OS keyring.; read-code: Lineage display omits engine and identity matching relies on provider, model, and fingerprint. Verify: Create a parent under one agy account, switch accounts, and run resume; acceptance would demonstrate mixed endpoint history. Remedy: Include a stable auth subject or credential fingerprint when observable; otherwise bind launcher/version and refuse resume when identity evidence changes.
- **F05-4** [major] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:81`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3536` - Defaulting agy to `resume` makes repeated consultations context-dependent and non-independent, unlike the current fresh-thread default. Trigger: Two consultations of one lineage cover different briefs or purposes. Evidence: read-code: Resume is automatic whenever a lineage thread exists.; read-code: Current automatic selection starts `new` unless fork/resume is requested and a verified parent exists. Verify: Compare two agy consultations on the same lineage and inspect whether the second prompt/history contains the first consultation. Remedy: Default to `new`; make resume explicit and optionally purpose-scoped for deliberate follow-ups.
- **F05-5** [major] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:66`, `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:105`, `README.md:1038` - `panel: weighty` controls panel membership only and cannot route weighty reviews to a high-tier Gemini model. Trigger: A weighty roster entry names `gemini-3.8-flash-low` for a framing or acceptance panel. Evidence: read-code: The roster `panel` field only decides always versus weighty-purpose participation.; read-code: Model remains the full tier-bearing id and no purpose-to-model routing is proposed. Verify: Dry-run a weighty panel and confirm the planned argv still names the low-tier model. Remedy: Add a validated `weighty_model` or purpose-to-model mapping and reject incompatible effort/model combinations before launch.

### Prior findings

_(none)_

## Verdict: ADVISE

The adapter direction is sound, but four design gaps threaten read-only execution, reply preservation, thread identity, and review independence before implementation begins.

### Blockers

- **F05-2** `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:70`, `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:101`, `plugins/codex-consult/scripts/codex-consult.ps1:1776` - D3/D7 do not specify artifact-first preservation, so a crash can leave a usable agy reply only inside events output while the recovery record names a nonexistent reply file, breaking the nothing-lost invariant. Verify: Kill the bridge immediately after a fake agy result, then inspect `.consult.pending.json` and every referenced handoff path. Remedy: Extract `structured_output` or response to atomic reply artifacts first, update the recovery record with their real paths, then parse, repair, and commit the ledger.

### Unproven scenarios

- Whether agy can return SUCCESS with `structured_output` absent despite schema enforcement.
- Whether agy exposes a stable account or credential identity locally.
- The complete Google/agy error and retry wording corpus.
- Whether all soft-denial notices are distinguishable from content-affecting denials.
- Measured token and latency growth of lineage-wide resume.

### First-run checklist (observable)

_(none)_
