# Task: bridge-0.3-2026-09-24 - implement ROADMAP R7-R9 as codex-consult 0.3.0

Base: tag `v0.2.0` (commit `68353d7`). Coordinator: Claude Code. Reviewer: Codex, thread forked from the
multi-model discussion (`.collab/multi-model-2026-09-23/`, thread `01a0d00a-...`) so the R7-R9 agreement is
in context. Scope: R7 `-Provider` with reviewer lineages, effort mapping and peak-hour warning; R8
`requested_checks[]` (schema v2); R9 `-Group`, `-Link` relations, `-Stats -Group`. Out of scope: a fourth
model, credit estimates, Codex-internal delegation, cross-host anything.

## Round 1 - design review before implementation

- `handoffs/01-claude-design-0.3.md` (the design) -> `handoffs/02-codex-design-0.3.md` (fork of the multi-model
  thread -> `01a0d125-634f-7e20-87c4-b27d2e24ac49`, 237.5 s): **ADVISE** - direction sound, three blockers
  and five majors on the contracts; F02-1..F02-9 in `findings.json`. Strategic advice adopted: the three
  capabilities need not ship together.

### Decisions (coordinator)

- **Scope**: 0.3.0 = R7 (provider, lineages, effort, peak) + R8 as a CONVENTION (no schema change). **R9 is
  deferred to 0.4.0** with the reviewer's requirements recorded in ROADMAP: an immutable group manifest
  (brief hash, source/artifact fingerprints, purpose, shared instructions, frozen baseline findings, member
  attempts), blind isolation (a later member must not receive an earlier member's findings through the
  prompt - the live open-findings block makes sequential members non-blind today), canonical-issue
  membership and report-validity adjudication distinct from fix status, verification-time records,
  nullable avoided-rework estimates, idempotent atomic relations. F02-6, F02-7, F02-8 -> `wontfix` in this
  task with that note (they are R9 findings).
- **F02-1** adopted: the default provider is resolved from the Codex config (`model_provider`, default
  `openai`; `model`), never assumed; unresolvable -> `unknown` provenance, automatic fork/resume disallowed.
- **F02-2** adopted: the constrained TOML scanner rejects unsupported constructs per table instead of
  guessing; compatibility identity = base_url + wire_api only (canonicalised, versioned string, hashed);
  audit metadata (non-secret table values, harness version) recorded separately and never compared;
  legacy entries = unknown provenance (never automatic parents).
- **F02-3** adopted: a consultation id goes into the prompt; the rollout fallback yields a thread only when
  the rollout file contains that id, otherwise the uuid is recorded as a diagnostic candidate only.
- **F02-4** adopted: effort vocabularies keyed by endpoint host (and model prefix as a fallback), not by
  provider alias; unknown -> `-NativeEffort` required; ledger records requested / sent / mapping / confirmed
  (null - not observable through Codex events).
- **F02-5** adopted by NOT shipping the schema field: requested checks live in `reply_markdown` as an
  `## Requested checks` section (RC1..RCn, at most 5, references by finding position / id / invariant); the
  review template gains a "Requested checks run" table with revision, exit status, log reference and state.
- **F02-9** adopted: peak semantics defined (fixed offset, inclusive start / exclusive end, overnight windows,
  exception dates, launch-time only), `peak` true/false/null, `-OffPeakOnly` refuses on unknown, warning-only
  default kept.
- Not adopted: bridge-owned reviewer profiles (a config resolver subset with refusal on unsupported syntax
  is enough for 0.3.0; profiles noted for later); provider-confirmed effort (not observable).

## Implementation (2026-09-24, waves 1-4 of 0.3.0 in one go)

- Opus worker from `spec-0.3.0.md` + amendments: R7 complete (config scanner with per-key granularity, identity
  resolution incl. `profile` -> unknown and `OPENAI_BASE_URL` in the builtin identity, fingerprint
  `cc-provider-v1|base_url|wire_api`, lineage-scoped parents, legacy = unknown provenance, consultation id in
  the prompt + rollout correlation, effort by host/prefix + `-NativeEffort`, peak env semantics), R8 prompt
  paragraph; `Stop-ProcessTree` now waits up to 3 s before judging survivors (a pre-existing race found by the
  worker's regression run). `harness-0.3.ps1` 127/127 on 5.1 and pwsh 7.6, KILL 5/5, 0.2 harnesses 26/26,
  45/45, 10/10, 12/12. Deviations accepted (see the worker's list in the commit message / README).
- Coordinator dry runs on the real config: `-Provider ZAI -Model glm-5.3` -> lineage `ZAI/glm-5.3`, argv with
  `-m glm-5.3 -c model_reasoning_effort="max" -c model_provider="ZAI"` for `-Effort xhigh`; default ->
  `openai/gpt-6-astra` from the config; the legacy design thread refused as `-Thread` ("recorded before
  0.3.0; use -Mode new") - the migration consequence, as designed.

## Round 1b - the second reviewer, live, through the feature under review (2026-09-24 05:21)

- `handoffs/03-claude-glm-diff-review.md` -> `handoffs/04-codex-glm-diff-review.md`: `-Provider ZAI -Model
  glm-5.3 -Purpose diff-review`, own lineage, `mode new` (the legacy design thread correctly not a parent),
  thread `01a0d16e-...` from `thread.started`, 611.4 s, usage 1.73M in (1.61M cached) / 24.6k out from the
  z.ai route. GLM did NOT return the JSON object this time (plain Markdown): the bridge recorded `structured
  false`, `validation_error "not valid JSON: ..."`, no verdict, no findings, `.reply.json` = the raw Markdown
  byte for byte - the degradation path working as designed; its verdict (HOLD) is prose only.
- Substance adopted for wave 5: (1) a user-defined `[model_providers.openai]` table was ignored by the builtin
  identity branch -> it now defines the identity when usable, unknown when not; (2) an absent `wire_api` must
  not be assumed `responses` -> canonical `wire_api=default`, no protocol asserted; (3) the events parser's
  drift net accepted a top-level `session_id`/`conversation_id` from ANY event -> restricted to
  thread.started / session.started / session_configured; (4) the harnesses were not in the tree ->
  `tests/` with `run-all.ps1`, the fake shims and the five harnesses, paths relative to the script.
  Its requested checks RC1 (read the codex source for provider merging and the wire_api default) is answered
  conservatively by (1) and (2) instead of asserting Codex semantics; RC2 (live wire capture) not run; RC3 is
  the harness case of (3).
- Not adopted: nothing; all four points were valid.

## Wave 5 (GLM review) and wave 6 (operator requirement), 2026-09-24

- Wave 5 done: user-defined `[model_providers.openai]` table defines the identity when usable (unresolved
  when not); absent `wire_api` canonicalised as `default` (no protocol asserted); events-parser drift nets
  restricted to session-start events; `tests/` at the repo root with `run-all.ps1`, five harnesses and the
  fake shims, paths relative to the script - 5.1: 152/26/45/11/12, pwsh: harness-0.3 152/152.
- Wave 6, from the operator during the acceptance run: "the script must detect by itself whether a GLM or GPT
  subscription exists; if not, neither call nor count on that model". Design: `codex-providers.ps1` lists
  every provider with a verdict (available / unavailable / unknown) from credentials only - builtin openai via
  `codex login status` (`Logged in using ChatGPT`, exit 0 here), custom providers via the table's `env_key`
  variable or a bearer token in the table - plus table usability, effort vocabulary and the newest
  usage-limit failure recorded in this repository's ledgers within 24 h; exit codes 0/2/3 with `-Provider`
  so the skill can branch. The bridge runs the same check as a PREFLIGHT before the lock: missing credentials
  refuse the run with nothing started and no ledger entry (`-SkipPreflight` to bypass, recorded); a usage
  limit hit within the last hour on this task warns. No network call is ever made for the check; quota
  itself is only learned from a failed run (the `error` event), which the ledger already records.

## Round 2 - acceptance (2026-09-24 06:50) - HOLD

- `handoffs/05-claude-acceptance-0.3.md` -> `handoffs/06-codex-acceptance-0.3.md`: a NEW thread
  `01a0d28a-...` in lineage `openai/gpt-6-astra` (the design thread is legacy provenance under the 0.3.0
  rule - the migration consequence, exercised live), 334 s. **HOLD**: F06-1 (blocker) an unsupported
  ancestor declaration (`model_providers = {...}` inline, `model_providers.openai = {...}` dotted) hides an
  openai override and the builtin branch resolves a reusable identity; F06-2 (blocker) the concatenated
  `provider/model` lineage string is ambiguous, so parent selection can cross provider and model; F06-3
  (major) `-OffPeakOnly` decides from a stale pre-preparation evaluation; F06-4 (minor) exception ranges over
  3,700 days silently truncate. Prior: F02-1/3/5 fixed; F02-2 -> superseded by F06-1; F02-9 -> superseded by
  F06-3/F06-4; F02-4 still open (capabilities inferred from host/prefix, not declared per model). Q2: the
  invalid-structured-reply contract (prose kept, no verdict, no findings) is right; no automatic retry.
- Bridge behaviour on this run, per the reviewer's checklist: consult_id matches, lineage/mode/parent as
  expected, `provider_source "codex default"`, `model_source "config"`, builtin fingerprint `56d97b6e...`,
  argv pins `-m gpt-6-astra` and `model_provider="openai"`, effort high/high/openai/null, thread from
  `thread.started`, structured with no error, six prior dispositions ingested, F06 ids with `supersedes` on
  both sides, peak null/none, pending removed, lock present; the tree changed during the review (the docs
  and scripts workers were editing) - flagged.
- Statuses: F02-1, F02-3, F02-5 -> `verified`; F02-2, F02-9 -> `superseded`; F02-4 stays `proposed` until wave 7.
- Wave 7 (queued after wave 6): F06-1 - the builtin fallback only when the scanner can establish that no
  `model_providers.openai` declaration exists at any depth; F06-2 - compare provider and model as a tuple
  everywhere, lineage displayed as `<provider> :: <model>`; F06-3 - peak re-evaluated immediately before
  launch (`peak_evaluated_at`), test hook `CODEX_CONSULT_NOW`; F06-4 - exception intervals evaluated directly;
  F02-4 - declared capability table `caps-v1` (builtin openai: any model; z.ai hosts: the declared GLM list
  only), model-prefix inference removed, `-NativeEffort` otherwise.

## Waves 6-7 done (2026-09-24 ~12:00) and the third reviewer wired

- Preflight: `codex-providers.ps1` (verdict per provider from credentials, table usability, caps, last
  usage-limit failure; exit 0/2/3) and the in-bridge preflight before the lock (`preflight`,
  `preflight_warning` in the ledger, `-SkipPreflight`). Wave 7: F06-1 (provider set must be establishable
  before the builtin fallback), F06-2 (parent selection by provider+model tuple; lineage display
  `<provider> :: <model>`), F06-3 (peak re-evaluated at launch, `peak_evaluated_at`, test hook
  `CODEX_CONSULT_NOW`), F06-4 (exception intervals of any length), F02-4 (`caps-v1`: declared models per host,
  prefix inference removed, `effort_caps`), plus `-CodexConfig` (extra `-c`, tilde expanded, identity keys
  refused, ledger `extra_config`). `tests/run-all.ps1`: 202/26/45/11/12 on 5.1; harness-0.3 202/202 on pwsh.
  All five F06/F02-4 findings CONFIRMED before fixing; statuses -> `implemented`.
- Xiaomi MiMo (operator subscribed to the Token Plan; key set by the operator as `MIMO_API_KEY`): Codex
  provider `mimo` (env_key, wire_api responses, dedicated base_url), model catalog kept OUT of the global
  config (a global `model_catalog_json` replaces Codex's catalog - gpt-6-astra ran with "metadata not
  found, fallback"; verified and reverted) and passed per run via `-CodexConfig`; caps-v1 declares the five
  MiMo models with vocabulary none|low|medium|high (`mimo-v1`, xhigh->high). `codex-providers.ps1` on the
  real config: openai, ZAI and mimo all `available`. Smoke through `codex exec`: ok.
- First MiMo consultation THROUGH the bridge (`handoffs/07-claude-mimo-preflight-review.md` ->
  `handoffs/08-codex-mimo-preflight-review.md`): FAILED at the first request - the MiMo endpoint rejects
  `--output-schema` (`responses_feature_not_supported: text.format type 'json_schema' is not supported,
  only 'text' and 'json_object'`). The bridge did everything right: preflight `ok: env MIMO_API_KEY set`,
  lineage `mimo :: mimo-v2.6-pro`, `extra_config` with the expanded catalog path, the error lifted into
  `bridge_outcome`, exit 1, no findings, pending record cleared. Lesson for the design: the schema
  transport is a per-host capability - z.ai accepts and ignores it, MiMo refuses it. Wave 8: caps-v1 gains
  `schema_transport` (`output-schema` for builtin/z.ai, `prompt-only` for MiMo and unknown hosts: no
  `--output-schema`, JSON asked for in the prompt and parsed leniently), ledger `schema_transport`.

- Wave 8 done: caps-v1 declares `schema_transport` per host (builtin and z.ai `output-schema`; MiMo hosts and
  every undeclared host `prompt-only`: no `--output-schema`, the schema file appended to the prompt, the
  reply parsed leniently and validated locally); ledger `schema_transport` after `schema`; dry run prints a
  `transport` line; `codex-providers.ps1 -Json` reports it. `tests/run-all.ps1`: 208/26/45/11/12 on 5.1,
  harness-0.3 208/208 on pwsh.

## Round 1c - the third reviewer (MiMo), live, through the bridge (2026-09-24 ~13:00)

- `handoffs/07-claude-mimo-preflight-review.md` -> `handoffs/09-codex-mimo-preflight-review.md`:
  `-Provider mimo -Model mimo-v2.6-pro -CodexConfig model_catalog_json=~/...`, lineage `mimo :: mimo-v2.6-pro`,
  `mode fork` of its own lineage's earlier thread (the failed run's), 388 s, usage 843k in / 13k out from the
  MiMo route, `schema_transport prompt-only` (no `--output-schema` in argv), the reply came back as BARE JSON
  and validated: **HOLD**, F09-1 (blocker) .. F09-4, and all five prior ids (F02-4, F06-1..4) reported fixed.
  Preflight `ok: env MIMO_API_KEY set`, `extra_config` expanded, pending cleared - MiMo's own first-run
  checklist satisfied field by field. Three reviewers now share one ledger: openai, ZAI and mimo lineages.
- MiMo's findings, all adopted for wave 9: F09-1 preflight fails OPEN on `unknown` (unresolved identity or a
  `login status` that cannot run) - the operator's rule wants fail-closed unless `-SkipPreflight`; F09-3
  provider failures are not classified (auth vs quota vs capability vs transport) and the SSE
  `data:{"error":...}` shape on stderr was not parsed, so a dead key would not warn the next preflight;
  F09-2 no structured negative-health state (`available` = presence only); F09-4 health keyed by alias and
  by the current task only, not by endpoint fingerprint across the repository's ledgers. Wave 9 design:
  fail-closed on unknown; `Get-ProviderFailureClass` + SSE parsing -> ledger `provider_failure {class, code,
  message, when}`; `codex-providers.ps1` and the preflight read ALL task ledgers keyed by endpoint
  fingerprint: an auth failure within 24 h -> unavailable / refused (a later success on the endpoint clears
  it; `-SkipPreflight` once after rotating a key), quota within 60 min -> warning.

## Round 3 - re-acceptance after waves 6-9 (2026-09-24 12:52) - the Codex reviewer is rate-limited

- `handoffs/10-claude-reacceptance-0.3.md` -> `handoffs/11-codex-reacceptance-0.3.md`: the `resume` of the
  acceptance thread was accepted by the provenance rules (lineage `openai :: gpt-6-astra`, builtin
  fingerprint), preflight `ok: Logged in using ChatGPT`, but Codex's own plan refused the turn: "You've hit
  your usage limit ... try again at Sep 28th, 2026 8:35 PM" (the weekly cap). The bridge recorded
  `bridge_outcome failed`, `provider_failure {class: quota, when: 12:54}`; `codex-providers.ps1` now shows
  openai `available` with `quota: 12:52 - You've hit your usage limit ...` in LAST FAILURE, and the next
  default dry run prints `WARNING: provider openai hit a usage limit 2 min ago` with `preflight_warning`
  set - the operator's requirement, demonstrated on a real failure the same day it was built.
- Decision: the Codex reviewer's round 3 waits for Sep 28 (`resume` of `01a0d28a-...` with the same brief).
  Meanwhile the third reviewer (MiMo) judges the same brief as a stand-in (`-Purpose acceptance`, its own
  lineage), and 0.3.0 is committed as a candidate WITHOUT the `v0.3.0` tag; the tag follows the Codex
  reviewer's ACCEPT. The last wave (9) closed MiMo's own findings, so its re-review is also the natural check
  of those fixes.

## Round 3b - stand-in re-acceptance by the third reviewer (MiMo) (2026-09-24 12:55-12:59)

- Same brief (`handoffs/10-claude-reacceptance-0.3.md`) -> `handoffs/12-codex-mimo-reacceptance-0.3.md`:
  `-Provider mimo -Model mimo-v2.6-pro -Purpose acceptance`, ledger n=7, lineage `mimo :: mimo-v2.6-pro`,
  `mode fork` of its own thread (n=5), `schema_transport prompt-only`, structured reply validated, preflight
  `ok: env MIMO_API_KEY set`, tree and brief unchanged during the review, usage 1.73M in / 22k out, 277 s.
- Verdict **ACCEPT**: all nine prior ids (F06-1..4, F02-4, F09-1..4) reported fixed with the function or
  fixture that closes each; no blocker. Two minor findings ingested: F12-1 (the fail-closed preflight has no
  narrow way out for an endpoint that needs no credential, nor for a rotated key within the 24 h auth
  window - only `-SkipPreflight`, which bypasses everything) and F12-2 (failure classification tries the
  broad quota/auth phrases before capability terms; `auth` matches "authored"). Unproven, as stated: live
  plan validity, error wording beyond the fixtures, an independent rerun of the harnesses.
- MiMo's first-run checklist in the reply describes the Codex reviewer's consultation (resume, openai
  lineage, `output-schema`) because the brief was written for that run; the observable facts of THIS run
  are the ones above (fork, mimo lineage, prompt-only) and match the ledger field by field.
- Disposition: F09-1..4 -> `verified` (their author confirms the fixes). F06-1..4 and F02-4 stay
  `implemented`: the third reviewer's "fixed" is recorded in the ledger's `prior_findings`, the authoring
  reviewer's confirmation waits for its plan to reset (Sep 28). The v0.3.0 tag waits with it; the candidate
  is committed and pushed.
- Operator's clarification (13:05): GLM and MiMo are not a REPLACEMENT for the Codex reviewer - the rule is
  simply not to use a provider while it has no tokens, exactly as when it has no key. Wave 10 therefore adds
  a reviewer ROSTER (an ordered list; the bridge picks the first entry whose credentials and endpoint health
  allow a run, records the skipped ones with their reason) and reads the reset time out of a usage-limit
  message ("try again at Sep 28th, 2026 8:35 PM" -> `provider_failure.retry_after`; a known future reset
  makes the endpoint `unavailable` until then, not a 60-minute warning). F12-1 gets its narrow declaration
  (`"auth": "none"` on a roster entry); F12-2 is fixed by reordering the classifier.

## Wave 10 - reviewer roster, panel, known reset times (2026-09-24 13:10-16:40)

- Operator's council model (13:05-13:40): the coordinator is an equal participant and the judge by
  default; the judge role can be handed to one reviewer per question explicitly; every brief goes to the
  panel - the cheap members always, the weighty member (`openai :: gpt-6-astra`, `"panel": "weighty"`)
  only on framing, decision, core-contract, acceptance, stuck, because tokens are finite for everyone;
  chores go to cheap members (`-Purpose chore`), large inputs are pre-digested before a weighty brief.
- Implemented (one Opus worker, spec in the transcript): roster file (`CODEX_CONSULT_ROSTER`, default
  `<codex home>/codex-consult-roster.json`, `none` switches it off; entries provider/model/codex_config/
  auth none/panel always|weighty; fail-closed on an unusable or a named-but-missing file), the three
  selection rules (`-Provider` explicit -> entry defaults only; `-Thread` -> the thread's reviewer; else
  first available), `provider_failure.retry_after` parsed from the message (Codex "try again at <date>",
  ISO, durations incl. days/weeks) -> `unavailable: usage limit until <iso>`, `-Panel`/`-PanelAll`
  (members as sequential child runs with an internal `-PanelSpec`, one findings snapshot for all, summary
  block, exit 0 only if every member replied), `-SchemaTransport`, `-Purpose chore`, per-reviewer
  scoreboard in `codex-findings.ps1 -Stats`, F12-2 classifier order, UTF-8 `login status`. Tests:
  `tests/harness-roster.ps1` 97; run-all on 5.1: 227/97/26/45/11/12; pwsh: 227/97. Docs by a Sonnet
  worker (README "Reviewer roster and panel", CHANGELOG, ROADMAP R9 partial, TECH_DEBT T5, SKILL council
  rules, examples/codex-consult-roster.json).

## Round 4 - the first live PANEL (2026-09-24 16:50-17:14)

- `handoffs/13-claude-wave10-panel-review.md` -> `-PanelAll -Purpose diff-review -SchemaTransport
  prompt-only` on the real roster: panel `6710207b`, `openai :: gpt-6-astra` SKIPPED by the bridge itself
  with `usage limit until 2026-09-28T20:35:00+02:00` (the reset time read out of the n=6 failure message -
  nobody switched anything by hand), then `ZAI :: glm-5.3` (n=8, fork of its own thread, 547 s, 4.5M in /
  46k out - prose again even with the schema in the prompt: INVALID JSON, text kept) and
  `mimo :: mimo-v2.6-pro` (n=9, 267 s, structured HOLD). Both entries carry the same `panel.id`, the
  `roster.skipped` list and `provider_source roster`; the catalog came from the roster entry
  (`extra_config_source roster`). Exit 0 (both replies usable). The tree changed during GLM's review
  (README/CHANGELOG count fixes) - recorded, harmless.
- The two reviewers found the SAME defects independently (they saw the same snapshot, not each other):
  **F15-1** (blocker) reset wall-clock times are attached to the failure's offset, wrong across a DST
  change (Berlin Oct 25 -> Oct 26 example: one hour early); **F15-2** legacy entries without `retry_after`
  read on pwsh in another zone get the reader's offset (pwsh materializes ISO strings as local
  `[datetime]`); **F15-3** a member whose timeout leaves surviving processes keeps the task's pending
  reservation, so later members are refused - the "one member's failure does not stop the others" claim
  is false in that case; **F15-4** records dated >5 min in the future are ignored, so a skewed clock hides
  a fresh auth failure. GLM's RC1 (read Codex's formatter to learn which zone rule it prints) is not run:
  the fix does not depend on it - the reset is computed with the recording machine's zone rules at write
  time, whatever Codex meant, and the legacy fallback is labelled as such.
- Judge's decision (Claude): all four adopted for wave 11 - F15-1 write-time `[TimeZoneInfo]::Local` rules
  (`-TimeZone` for tests), read-time fallback labelled `message (reference offset)`; F15-2 `ConvertFrom-Json
  -DateKind Offset` where the cmdlet has it (pwsh >= 7.5); F15-3 the contract is NARROWED, not patched
  around: after survivors the remaining members are recorded `skipped: not started ...`, exit 1 - one
  consultation per task at a time stays absolute; F15-4 future ages clamp to 0. F12-2 -> verified (its
  author confirms); F12-1 -> the anonymous half is `"auth": "none"`, the rotation half is TECH_DEBT T5.
- Scoreboard so far: the third reviewer (MiMo) raised F09-1..4 (all verified) and F12-1..2, F15-1..4; GLM's
  prose has matched MiMo's structured findings twice but never entered the ledger as ids - the z.ai route
  ignores the schema in both transports (open item: a GLM-specific prompt, or accept prose there).

## Waves 11-13 - the panel's findings, usefulness telemetry, an atomic-write gap (2026-09-24 17:20-21:00)

- Wave 11 (F15-1..4, the same Opus worker; it hit its session limit once mid-wave and was resumed after the
  reset): reset wall-clock times are converted with the recording machine's zone rules at write time
  (`Get-RetryAfter -TimeZone`, spring gap -> post-transition offset, autumn overlap -> pre-transition;
  legacy entries fall back to the `when` offset and are labelled `RetryAfterBasis "message (reference
  offset)"`); ledgers are parsed with `ConvertFrom-Json -DateKind Offset` where the cmdlet has it (pwsh
  >= 7.5) so `when` keeps its recorded offset; the panel contract is NARROWED - after a member leaves
  surviving processes the remaining members are not started (`skipped  not started: the previous member
  (...) left surviving processes ...; recover the task first`, exit 1; test hook
  `CODEX_CONSULT_TEST_SURVIVORS`); future-dated health records count as now (age clamped to 0). Ledger
  `panel.members` is fixed at panel start, so a not-started member still reads `run` there - only the
  summary shows the skip (recorded deviation).
- Wave 12 (operator's idea, 19:05: "keep telemetry on which questions which model was useful"):
  `codex-findings.ps1 -Rate <n> -Useful yes|partly|no [-Note]` -> `ratings[]` in findings.json; `-Stats`
  scoreboard gains yes/partly/no; new `codex-scoreboard.ps1` (reviewer x purpose across every task: consults,
  usable/prose/failed, raised/verified/rejected/wontfix/superseded/open, HIT%, verdicts, ratings, median
  wall, tokens). The nine consultations of this task are rated (n=1,3,5,7,9 yes; n=2,8 partly - GLM prose
  matched but produced no ids; n=4,6 no - endpoint capability failure, usage limit). Across the three tasks
  of this repository: MiMo 10 raised / 5 verified / 100% hit, ZAI 0 ids in 2 prose replies, openai 4 raised
  (awaiting its author's confirmation), pre-0.3.0 entries as unknown provenance.
- Wave 13: a slow harness run exposed a REAL pre-existing gap (0.2.0's `Write-TextAtomic`, F04-1's hard-kill
  case): on Windows `File.Replace` (Win32 ReplaceFile) is not one rename - a hard kill inside its window
  leaves the store missing and the temp file behind (seen once: `atomic-store.json` not found, 3 stray temp
  files, then counted nine times because the writer child read the missing store). Fix: a single atomic
  rename with replace (`File.Move(tmp, dst, true)` on pwsh, `MoveFileExW(REPLACE_EXISTING|WRITE_THROUGH)` via
  P/Invoke on 5.1; Unix rename unchanged); the test re-seeds after a failed kill so one hit counts once.
- Docs (Sonnet worker): README (narrowed panel, zone rules, "Usefulness telemetry"), CHANGELOG waves 11-12,
  SKILL step 3 "rate every consultation", TECH_DEBT T6 (legacy reset-time residual), examples `ratings`.
- Harness counts after waves 11-12 on 5.1: harness-0.3 227, harness-roster 113, pending 26, fixes 45,
  lock2 11, 3b 12; pwsh 7.6: 227 / 113.

## Round 5 - the format question, and each provider's own protocol (2026-09-24 21:30 - 2026-09-25 01:30)

- Operator (21:20): retry the model with a request to reformat when it answers in prose; then (22:40) "use each
  provider's own protocol" and add the Gemini subscription. Research: Codex CLI can only send `text.format
  json_schema` (z.ai ignores it, MiMo rejects it), `wire_api = "chat"` no longer starts (Feb 2026), and both
  plans forbid plain HTTP clients with the plan key - so no direct chat-API adapter (the operator agreed).
- `handoffs/16-claude-format-compliance.md` -> panel `9e96bc8f` (`-Purpose checkpoint`, prompt-only):
  `ZAI :: glm-5.3` answered as BARE JSON for the first time (n=10, ADVISE, 0 findings, 9 prior ids fixed /
  F12-1 still-open) and `mimo :: mimo-v2.6-pro` (n=11, ADVISE, F18-1..3 minor). Same diagnosis from both:
  the output contract sits mid-prompt after the brief and the open findings, and "write it exactly as you
  would a normal reply" licenses prose; put a hard contract FIRST; one gated repair turn on the same thread
  at low effort, convert-not-re-answer, cheap drift checks (RC ids, numbered answers, prior ids, verdict
  token, longest sentences), never on a failed run / short reply / unverified thread; keep the prose verbatim.
  Both rated `yes`. F18-1 adopted (wave 14); F18-2 = the wave-11 narrowing (wontfix, documented); F18-3 =
  T5 (wontfix here).
- Own protocol, verified live: Claude Code `claude -p --json-schema` returned `structured_output` on the z.ai
  GLM route AND on the MiMo route (the schema travels as a forced tool call, which both endpoints honour) -
  the prose problem is specific to the Codex wrapper's response-format path, not to the models. Gemini: the
  installed `gemini` CLI 0.32.1 is dead for individuals (IneligibleTierError, OAuth discontinued 2026-06-18);
  Google's successor is the Antigravity CLI `agy` (winget `Google.AntigravityCLI` 1.2.10, installed 2026-09-25
  on the operator's request; logged in through the Antigravity IDE; headless `-p --output-format json
  --json-schema` verified on gemini-3.8-flash-high; models incl. gemini-3.1-pro). Plan for 0.4.0 (R10): a
  roster field `engine` = codex | claude | agy, one headless adapter for the Claude-Code-style CLIs, common
  ledger/findings/panel.
- Wave 14 (Opus worker): `FINAL OUTPUT CONTRACT` as the prompt's first paragraph; `-FormatRetry 0|1`
  (default 1) - one repair turn `resume <thread>` at the route's lowest effort, no `--output-schema`, the
  original prose kept as `.original.md` and rendered after the structured section, ledger `format_retry
  {attempted, reason, succeeded, thread, wall_seconds, usage, drift[], original}`; `tests/harness-format.ps1`
  23. Counts: 5.1 227/113/23/26/45/11/12; pwsh 227/113/23. Round 6 (handoff 19) = the live test of the
  contract on both cheap routes.

## Round 6 - wave 14 under review, and the contract works (2026-09-25 01:40-01:55)

- `handoffs/19-claude-wave14-review.md` -> panel `18b99832` (`-Panel -Purpose diff-review`): BOTH cheap routes
  returned the bare JSON object on the FIRST turn - `structured true`, `format_retry null` - n=12
  `ZAI :: glm-5.3` (190 s, ACCEPT, F20-1..3) and n=13 `mimo :: mimo-v2.6-pro` (306 s, HOLD, F21-1..3); the
  openai entry skipped by the roster as before. The z.ai route, prose twice under the old prompt, is now
  structured three times in a row (n=10, 12 and the contract-first n=12 is the first under wave 14).
- The same three gaps from both, independently: (1) the drift checks compare only the five longest prose
  sentences, so a softened severity or a replaced remedy in a short sentence ingests with zero notes
  (F20-1 minor / F21-1 major) - adopt GLM's cheap widening: ALL prose sentences >= 60 chars (capped), not a
  severity parser (prose severities are unstructured); (2) a bridge killed during the repair turn leaves the
  usable first-turn prose as an orphaned `.original.md` that no ledger entry or recovery message names
  (F20-2 minor / F21-2 major) - adopt GLM's remedy: the pending record carries the original's path and
  "repair in progress", and the next run's recovery message says a usable prose reply exists there; MiMo's
  journal/atomic-commit remedy is heavier than the gap; (3) `Test-SubstantiveProse` accepts a 130-word
  refusal and rejects a terse complete `Q1./Q2.` answer (F20-3 note / F21-3 minor) - adopt: refusal gate on
  leading "I cannot / I'm sorry / I am unable" content, accept `Q1:`, `1)`, `**1.**` styles, lower floor with
  numbered answers. Both rated `yes`. -> wave 15.
- Verdict on the disagreement (ACCEPT vs HOLD on the same facts): the judge sides with HOLD for the orphaned
  original - a usable answer the coordinator is never told about violates "nothing already written is
  silently lost" - and treats the other two as minor. Checkpoint commit before wave 15.

- Wave 15 done (2026-09-25 02:30): drift check 5 over every prose sentence >= 60 chars (40 longest); the
  recovery record is rewritten before the repair process starts with `original` + `first_reply`, every
  refusal/recovery/-List message names the orphaned prose, fields cleared once the ledger entry exists,
  `Recovery record:` header line; `Get-ProseGate` (refusal detection, all numbered styles, floors 25/40/120,
  reason recorded in `validation_error`). harness-format 37; run-all 5.1: 227/113/37/26/45/11/12; pwsh
  227/37. F20-1..3 and F21-1..3 -> implemented; their authors' confirmation comes with the next panel.
