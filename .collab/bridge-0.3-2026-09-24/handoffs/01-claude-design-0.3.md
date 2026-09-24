# Handoff 01 - Claude: design of codex-consult 0.3.0 (R7-R9: a second reviewer through the same bridge)

Date: 2026-09-24. Base commit: `68353d7` (= tag `v0.2.0`, clean tree). This thread is a fork of the one in
which you and GLM-5.3 agreed R7-R9 (`.collab/multi-model-2026-09-23/`); ROADMAP.md "Additional reviewers"
is the agreed text. Judge the concrete design below BEFORE I build it. Read `ROADMAP.md`, the 0.2.0 README
sections "The ledger", "Structured reply and findings", "The lock", and the scripts as needed.

## Facts that constrain the design

- Codex CLI runs a second model through `-c model_provider="<name>"` (a `[model_providers.<name>]` entry in
  `$CODEX_HOME/config.toml`) plus `-m <model>`; verified end to end with GLM-5.3 (z.ai). `--output-schema` is
  not enforced on that route (fenced JSON comes back; the 0.2.0 parser strips fences and validates).
- A Codex thread that holds OpenAI compaction items cannot be resumed under another provider; lineages
  must not cross providers.
- The task lock serialises consultations, so fan-out to two reviewers is sequential by construction.
- Effort vocabularies differ: OpenAI `low|medium|high|xhigh`; z.ai `low|high|max`.
- The bridge never makes an HTTP call itself; every provider is reached only through the Codex CLI.

## Design

**R7 - `-Provider <name>` and reviewer lineages.**
- `-Provider` names a `model_providers.<name>` table in the Codex config (`$CODEX_HOME/config.toml`, else
  `~/.codex/config.toml`); the bridge scans the file for that header (no full TOML parser, headers and the
  table's simple `key = "value"` lines only) and refuses an unknown name - the config IS the allowlist.
  `-Provider` requires `-Model` (the config's default model belongs to the default provider). The default
  (no `-Provider`) stays "whatever Codex does": provider `openai`, model = `-Model` or the config's `model`
  line, recorded as such instead of "config default".
- Argv: `-c model_provider="<name>"` before the subcommand, next to the other `-c`. Nothing else changes.
- **Lineage** = `provider/model` plus a `provider_fingerprint` = SHA-256 of the provider table's text
  (`base_url`, `wire_api`, `name` - never `env_key`/tokens, which are excluded before hashing). Every ledger
  entry records `reviewer: {provider, model, model_source: "-Model"|"config", harness: "codex-cli <ver>",
  provider_fingerprint}` and `lineage: "<provider>/<model>"`.
- **Parent selection**: the newest thread in this task's ledger WITHIN the same lineage; none -> `new`.
  `-Thread` given: it must appear in this task's ledger under the same lineage, else refused ("thread X
  belongs to lineage A, this run is lineage B" / "unknown provenance"). A lineage whose provider fingerprint
  changed since the parent thread (base_url edited) is refused for fork/resume with a message; `new` is fine.
- **Effort**: `-Effort` keeps the OpenAI vocabulary; per-provider mapping table (`ZAI`: medium->high,
  xhigh->max; others: pass-through) with `effort_requested` and `effort` (effective) in the ledger. The
  preset defaults are unchanged.
- **Peak hours** (warning only, optional enforcement): env `CODEX_CONSULT_PEAK_<PROVIDER>` =
  `"Mon-Fri 14:00-18:00 +08:00"` (days, window, fixed UTC offset - no tz database on PS 5.1). Inside the
  window the run prints a warning and records `peak: true`; `-OffPeakOnly` refuses instead. No credit
  estimate (no pricing data); `usage` tokens are the measure.
- Until R9, a second reviewer simply consults the same task with `-Provider ZAI -Model glm-5.3` and its own
  lineage; findings get ids from the same sequence.

**R8 - `requested_checks[]`.** Schema v2 = v1 plus a required array `requested_checks[]` of
`{related: string (finding id or invariant), command: string, cwd: string, permissions: "read-only"|
"workspace-write", expected: string, budget: string}`; the validator accepts v1 (field absent) and v2. The
prompt explains it (one runnable check + expected observation each; at most 5; open-ended investigation is
not a check). Rendered as `### Requested checks` before `## Verdict`; ledger `requested_checks` count. The
review template gains a "Requested checks run" section (command, revision, exit status, observation) for
the coordinator's next brief. Not tracked by id in `findings.json` (they are requests, not findings).

**R9 - review groups.** `-Group <id>` tags a consultation; two consultations with the same brief hash and
group id from different lineages form a group (the ledger records `review_group`; `-Stats -Group <id>`
prints them side by side). Cross-reviewer links live in `findings.json`:
`codex-findings.ps1 -Task t -Link F04-1 F06-2 -Relation corroborates|contradicts|duplicates -Note "..."`
appends to each finding's `relations[]` (`{with, relation, note, when, by}`); `-List` shows relations.
No automatic matching; the coordinator links after comparing claim, trigger and invariant. The skill says:
fan out only at contract boundaries and acceptance, identical revision-bound briefs, fresh threads, neither
sees the other's answer; agreement lightens a spot-check, never replaces verification.

**Out of scope for 0.3.0**: Codex-internal delegation to another provider (no such feature), automatic
credit estimates, a fourth model, cross-host anything.

## Questions (answer by number, under 700 words)

- **Q1.** Lineage binding: provider + model + provider fingerprint (config table text minus secrets) + harness.
  Right set? Should a changed fingerprint refuse fork/resume, or only warn?
- **Q2.** Effort mapping per provider with requested/effective recorded - anything wrong with mapping
  `medium->high` and `xhigh->max` for z.ai, and with pass-through for unknown providers?
- **Q3.** `requested_checks[]` as a schema v2 field with a v1-compatible validator, capped at 5, not tracked by
  id - or should they be tracked (ids, completion records) from day one?
- **Q4.** Review groups: is `-Group` + coordinator-made `relations[]` enough for R9's measurement (unique
  verified defects, false positives, verification minutes, avoided rework), or must the ledger carry more?
- **Q5.** The peak-hour env format and warning-only default - adequate, or should the bridge refuse by default
  for a non-default provider inside its peak window?
- **Q6.** What would make you HOLD the acceptance of 0.3.0 - the first-run checklist for a GLM consultation
  through the bridge (fenced JSON, `usage` from the z.ai route, lineage recorded, a refused cross-lineage fork)?
