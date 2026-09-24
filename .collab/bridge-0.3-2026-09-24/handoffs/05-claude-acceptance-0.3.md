# Handoff 05 - Claude: acceptance of codex-consult 0.3.0 (R7 + R8 convention)

Date: 2026-09-24. Base commit: `68353d7` (tag `v0.2.0`) + uncommitted 0.3.0 work. This consultation runs on a
NEW thread in lineage `openai/gpt-6-astra`: under the 0.3.0 rule the design-review thread (handoff 02) has
legacy provenance and is never an automatic parent - the migration consequence, exercised on this very task.

## Question

Can 0.3.0 be accepted as implementing R7 (provider identity, lineages, effort, peak) and R8 as a convention,
with R9 deferred to 0.4.0 - under the contracts you set in the design review (F02-1..F02-5, F02-9 adopted;
F02-6/7/8 deferred with their requirements recorded)? Report each F02 id in `prior_findings`.

## Delta since the last review

Follows: `handoffs/02-codex-design-0.3.md` (ADVISE, three blockers on the design) and
`handoffs/04-codex-glm-diff-review.md` (the second reviewer's diff review, prose only).

- **F02-1**: the provider and model Codex will use are resolved from the config (`model_provider`, default
  `openai`; `model`) or from `-Provider`/`-Model`, pinned on the command line (`-m`, `-c model_provider`) and
  recorded as `reviewer{provider, provider_source, model, model_source, harness, provider_fingerprint,
  provider_config, identity_note}` + `lineage`. A top-level `profile` key, an unreadable config or an unusable
  provider table -> unresolved identity: automatic fork/resume disallowed, `new` allowed.
- **F02-2**: constrained TOML scanner (`Read-CodexConfigSubset`): basic/literal strings, quoted keys, numbers,
  booleans; arrays, inline tables and multi-line strings mark only that key (and a provider table containing
  one) unusable; dotted keys, `[[tables]]`, sub-tables and duplicates reject the table; unknown syntax
  rejects the file; never guesses. Compatibility identity = `cc-provider-v1|base_url=<canonical>|wire_api=
  <value|default>` hashed; comments, ordering, secret rotation, `name`, headers do not change it; endpoint or
  protocol change refuses fork/resume ("start a new thread"); harness version is audit metadata only.
  Legacy 0.1/0.2 entries = unknown provenance, never parents, refused as `-Thread`.
- **F02-3**: the prompt ends with `Consultation id: <guid>` (also in the ledger and the pending record). Without
  `thread.started`, a rollout counts only if it contains that id (`thread_source: rollout (verified by
  consultation id)`); otherwise `thread ''` and a diagnostic `thread_candidate`, never a parent. The drift nets
  of the events parser are restricted to `thread.started` / `session.started` / `session_configured`.
- **F02-4**: effort vocabulary by endpoint host (`api.openai.com`/builtin -> openai; `api.z.ai`,
  `open.bigmodel.cn` -> zai: medium->high, xhigh->max), then by model prefix (`glm-`, `gpt-`/`o<digit>`), else
  `-NativeEffort` required; ledger `effort_requested`, `effort_sent`, `effort_mapping` (openai|zai-v1|native),
  `effort_confirmed` (null); `-Effort` and `-NativeEffort` exclude each other.
- **F02-5**: requested checks are a convention: an `## Requested checks` section at the end of `reply_markdown`
  (RC1..RCn, at most 5, one command each, references by position/id/invariant); the review template has a
  "Requested checks run" table (command, revision, exit status, log reference, observation, state).
- **F02-9**: `CODEX_CONSULT_PEAK_<PROVIDER>` = `"<days> <HH:MM>-<HH:MM> <+HH:MM|-HH:MM>"` and `_EXCEPT` dates;
  start inclusive, end exclusive, overnight windows, exception dates all-day off-peak, evaluated at launch
  only; `peak` true/false/null, `peak_schedule`, `peak_source`; `-OffPeakOnly` refuses on peak AND on unknown;
  malformed -> refused naming the variable and token.
- **From the second reviewer (GLM-5.3, wave 5)**: a usable user-defined `[model_providers.openai]` table now
  defines the openai identity (unusable -> unresolved); an absent `wire_api` is canonicalised as `default`
  and no protocol is asserted; the events-parser drift nets restricted as above; and the harnesses moved
  into the tree: `tests/run-all.ps1` + five harnesses + fake shims (no real codex).
- Also: `Stop-ProcessTree` waits up to 3 s for killed pids before judging survivors (a pre-existing race).
- Not shipped: R9 (`-Group`, relations, blind fan-out) - requirements recorded in ROADMAP; schema stays v1.

## CURRENT invariants claimed

- Every 0.2.0 invariant holds (atomic stores, held-handle lock, pending record, validation, fingerprints).
- The ledger names the provider and model Codex actually used, or says unknown; a thread never changes
  provider, model, endpoint or protocol through fork/resume; unknown provenance is never reused.
- The bridge makes no HTTP call; plan credentials are only ever used by the Codex CLI it launches.

## Changed files

`plugins/codex-consult/scripts/codex-consult-common.ps1`, `codex-consult.ps1` (new sections), schema and
`codex-findings.ps1` unchanged; new `tests/`; README, CHANGELOG, ROADMAP, skill, templates, examples,
manifests (0.3.0).

## Open findings

F02-1, F02-2, F02-3, F02-4, F02-5, F02-9 - all `proposed` (design findings; the implementation is the fix;
your disposition plus the harness is the evidence for `verified`). F02-6/7/8 `wontfix` (deferred R9).

## Evidence

- `tests/run-all.ps1` on Windows PowerShell 5.1 from a foreign working directory: harness-0.3 152/152,
  harness-pending 26/26, harness-fixes 45/45, harness-lock2 11/11, harness-3b 12/12; harness-0.3 152/152 on
  pwsh 7.6. Cases include: config `model_provider="ZAI"` without `-Provider` -> ledger ZAI (source config);
  unreadable config -> unknown, fork refused; the real config's arrays rejected per key while its ZAI table is
  usable; fingerprint invariance under reordering/comments/secret rotation/name/trailing slash/host case and
  change under path/host/wire_api; two openai override tables fingerprint differently; absent vs explicit
  wire_api differ; lineage-scoped parents with two lineages, cross-lineage and unknown/legacy/candidate
  `-Thread` refusals, drift refusal; rollout correlation by consultation id (own older vs foreign newer);
  effort by alias host / bigmodel host / model prefix / native; peak boundaries, overnight, exceptions,
  malformed, unknown; foreign `session_id` on `turn.started` ignored; KILL 5/5.
- Live: `handoffs/04-codex-glm-diff-review.md` - the first consultation through `-Provider ZAI -Model
  glm-5.3`: own lineage, `mode new` (legacy design thread not a parent), thread from `thread.started`, usage
  from the z.ai route, effort `high`/`zai-v1`; GLM returned plain Markdown, so the bridge recorded `structured
  false` with the validation error, no verdict, no findings, `.reply.json` = raw text - the documented
  degradation on that route.
- Coordinator dry runs on the real config (`ZAI/glm-5.3` with `max` for `xhigh`; default
  `openai/gpt-6-astra`; legacy `-Thread` refused).
- Not verified: what Codex does with a user-defined openai table and its default wire_api (both rules are
  conservative either way); RC2 of the GLM review (live wire capture) not run; macOS.

## Questions

- **Q1.** For F02-1, F02-2, F02-3, F02-4, F02-5, F02-9: fixed, still-open or not-checked, with the concrete
  gap if still-open. Read `Resolve-ReviewerIdentity`, `Read-CodexConfigSubset`, `Get-ProviderTable`,
  `Resolve-EffortPlan`, `Get-PeakStatus`, `Select-ParentThread`, `Get-ThreadIdFromEvents` and the run
  section of `codex-consult.ps1`.
- **Q2.** The second reviewer's review was recorded as an invalid structured reply (plain Markdown on the
  z.ai route). Is "prose kept, no verdict, no findings" the right contract for a reviewer whose route does
  not enforce the schema, or should the bridge retry once with a stricter instruction before giving up?
- **Q3.** Verdict on 0.3.0: ACCEPT, HOLD or REJECT, with blockers, unproven scenarios and the observable
  first-run checklist for this consultation (a `new` thread in lineage `openai/gpt-6-astra`, six prior ids fed
  back, `provider_source "codex default"`, `model_source "config"`, builtin fingerprint).

Answer by number. Keep it under 800 words.
