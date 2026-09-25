# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-24

Implements ROADMAP R7 (provider support with reviewer lineages) and ships R8 as a
convention rather than a schema change, per the design-review round recorded in
`.collab/bridge-0.3-2026-09-24/` (`handoffs/01` the design, `handoffs/02` the Codex
reviewer's findings `F02-1..F02-9`, `state.md` the decisions and amendments). R9
(review groups, findings relations, group stats) is deferred to 0.4.0 — see below and
ROADMAP.md.

### Added

- **R7 — provider support with reviewer lineages.**
  - `-Provider <name>` (requires `-Model`): validated against `[model_providers.<name>]`
    in the Codex config, read with a constrained TOML scanner
    (`Read-CodexConfigSubset`) that understands comments, table headers, bare/quoted
    keys and string/bool/number values, and refuses (naming the line) any table
    containing a construct it does not understand — multi-line strings, arrays, inline
    tables, dotted keys, array-of-tables.
  - Provider identity resolved from the config when `-Provider`/`-Model` are omitted
    (`model_provider`, default `openai`; `model`); unresolvable identity is recorded as
    `unknown` and disallows automatic `fork`/`resume` (`-Mode` defaults to `new`).
  - `reviewer{provider, provider_source, model, model_source, harness,
    provider_fingerprint, provider_config, identity_note}` and `lineage`
    (`<provider>/<model>`) recorded per consult. `provider_source` is one of
    `-Provider`/`config`/`codex default`/`unknown`; `identity_note` explains why
    identity was left unresolved (a `profile` key in the config, an unreadable file, an
    unusable table), empty when identity resolved. Compatibility fingerprint (what must
    match for `fork`/`resume`) is the SHA-256 of `base_url` + `wire_api` only,
    canonicalised — comments, ordering, secret rotation and a table's `name` never
    change it; an endpoint or protocol change does, and refuses fork/resume onto that
    lineage's older threads (`-Mode new` unaffected) — the run is always refused, never
    silently switched to a new thread. A top-level `profile` key in the config leaves
    identity unresolved even when `-Provider`/`-Model` are both given, since a profile
    can override the provider and the effort behind the bridge's back.
  - Parent-thread selection is now scoped to the CURRENT run's lineage: the newest
    ledger entry with a non-empty `thread` and the same lineage, never the task's
    newest thread overall. `-Thread` is validated against the run's lineage and refused
    across lineages, for an unknown uuid, or together with `-Mode new`.
  - A per-run `consult_id` in the prompt, so the rollout-file thread-id fallback only
    records a thread when the candidate rollout file actually contains this run's id
    (`thread_source = 'rollout (verified by consultation id)'`); otherwise the
    candidate uuid is kept only as a diagnostic `thread_candidate`, never as a parent.
  - Effort vocabularies are DECLARED per endpoint, not inferred (capability table
    `caps-v1`, ledger `effort_caps`): built-in `openai` (no user table, no
    `OPENAI_BASE_URL`) keeps `low|medium|high|xhigh` for any model; `api.z.ai` /
    `open.bigmodel.cn` map `low|high|max` (`medium`->`high`, `xhigh`->`max`) for 11
    declared GLM models only; MiMo hosts map `none|low|medium|high` (`xhigh`->`high`)
    for 5 declared models only. `-NativeEffort <value>` sends a value verbatim when no
    vocabulary is declared for the endpoint/model (there is no model-prefix fallback).
    Ledger: `effort_requested`, `effort_sent`, `effort_mapping`
    (`openai`|`zai-v1`|`mimo-v1`|`native`), `effort_caps`, `effort_confirmed` (always
    `null` — Codex's event stream does not report the effort it used).
  - Peak-hour tariff windows: `CODEX_CONSULT_PEAK_<PROVIDER>` (`"<days> <HH:MM>-<HH:MM>
    <+HH:MM|-HH:MM>"`, start inclusive/end exclusive, overnight windows keyed to their
    start day) and `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` (all-day exception
    dates/ranges, evaluated as intervals of any length). `-OffPeakOnly` refuses the run
    when the window is active OR unknown; the window is checked once early and again
    immediately before launch, and it is the launch-time result that is recorded and
    that governs `-OffPeakOnly` (a run entering the window during preparation is
    withdrawn at launch, no ledger entry). Ledger: `peak` (`true`/`false`/`null`),
    `peak_schedule`, `peak_source` (`env`/`env (CODEX_CONSULT_NOW)`/`none`),
    `peak_evaluated_at` (ISO with offset).
  - **Availability preflight and `codex-providers.ps1`.** Before the lock is taken, the
    resolved provider's credentials are checked locally (the same check
    `codex-providers.ps1` uses): missing credentials refuse the run outright, before
    anything is written (`-SkipPreflight` bypasses this; ledger `preflight: "skipped"`).
    Ledger `preflight` = `ok: <detail>` | `unknown: <reason>` | `skipped`; a usage-limit
    failure recorded for the same provider within the last hour adds a console
    `WARNING:` and ledger `preflight_warning`, without refusing. New script
    `scripts/codex-providers.ps1 [-Provider <name>] [-Json] [-CollabDir] [-CodexExe]`
    lists the built-in `openai` and every `[model_providers.*]` table with its verdict
    (`available`/`unavailable (<reason>)`/`unknown (<reason>)`), kind, endpoint,
    credentials, declared effort vocabulary, and the newest usage-limit failure in this
    repository's ledgers within 24 h; writes nothing, takes no lock, makes no network
    call; exit code with `-Provider` is the verdict (`0`/`2`/`3`/`1`).
  - **`-CodexConfig key=value[,…]`**: extra `-c` overrides passed to `codex exec`
    verbatim, after the bridge's own and before `-o`; refuses keys the bridge already
    owns (`model`, `model_provider`, `model_reasoning_effort`, `profile`,
    `model_providers(.*)`); a leading `~/` is expanded to the home directory (Codex on
    Windows does not expand it itself — verified, `os error 123`). Ledger
    `extra_config`. Motivating case: a `[model_providers.mimo]` (Xiaomi MiMo) entry
    whose model catalog must be supplied per run (`-CodexConfig
    model_catalog_json=~/.codex/model-catalogs.json`), since a GLOBAL
    `model_catalog_json` replaces Codex's own catalog and was observed, live, to
    degrade the default `openai` model on an unrelated run ("Model metadata not found,
    fallback").
  - README "Third example: Xiaomi MiMo" documenting the `mimo` provider shape
    generically (Token Plan endpoint, `env_key`, per-run catalog, `mimo` effort
    vocabulary).
  - **Per-host schema transport.** caps-v1 now also declares, per host, whether
    `--output-schema` is passed at all: `output-schema` for built-in `openai`
    (enforced server-side) and the z.ai hosts (accepted but not enforced); `prompt-only`
    for the MiMo hosts and any undeclared host (the bridge never passes the flag; the
    prompt still asks for the JSON object, parsed leniently — bare or fenced). Found by
    the first live MiMo consultation through the bridge, which failed outright at the
    first request because that endpoint REJECTS `--output-schema`
    (`responses_feature_not_supported: text.format type 'json_schema' is not supported,
    only 'text' and 'json_object' are allowed`) — the bridge recorded it correctly
    (preflight ok, lineage, `extra_config`, the error lifted into `bridge_outcome`, exit
    1, no findings) and the fix followed from that failure. Ledger `schema_transport`
    (`output-schema`|`prompt-only`), right after `schema`; `-DryRun` shows it; the reply
    header's `Structured reply:` line gets `(prompt-only transport)` appended when
    applicable. On a `prompt-only` route the prompt appends the schema file itself as a
    final `JSON Schema of the reply:` section (about 2 KB) with a matching format
    instruction; `output-schema` hosts keep the unchanged 0.2.0 prompt.
    `codex-providers.ps1 -Json` reports `schema_transport` per provider too.
  - **Provider failure classification and endpoint health**, from the MiMo review
    (third reviewer, first live consultation on a prompt-only route,
    `.collab/bridge-0.3-2026-09-24/handoffs/09-...`, `F09-1`..`F09-4`). Every failed
    consultation is classified: ledger `provider_failure` (right after
    `bridge_outcome`), `null` on success, else `{class, code, message (<=200 chars),
    when}`; `class` is `auth`/`quota`/`capability`/`transport`/`unknown` by word-bounded
    keyword match; an SSE-style `data:{"error":{...}}` payload on stderr is parsed for
    `error.message`/`error.code` first (this is how the MiMo endpoint reported its
    schema rejection); a bridge-internal failure such as a timeout kill is `transport`.
    The reply header gets a `Provider failure:` line. Endpoint health is now computed
    from ALL task ledgers in the repository, keyed by the endpoint fingerprint (never
    the alias), newest entry wins. `codex-providers.ps1`'s table column is now
    `LAST FAILURE (24 h)` (`<class>: <when> - <message>`); its JSON gains
    `last_failure {class, code, when, message}`.
- **R8 — requested checks (convention).** The structured-mode prompt asks Codex to end
  `reply_markdown`, when useful, with a `## Requested checks` section (`RC1..RCn`, at
  most 5, each one runnable command/procedure with its cwd, permission, expected
  observation and budget, referencing a finding by position/id/invariant). No schema
  change — schema stays v1, the bridge renders nothing extra, `.reply.json` and
  `findings.json` are untouched. `templates/brief-review.md` gains a
  "## Requested checks run" table for the coordinator to fill and cite in the next brief.
- README section "A second reviewer through the same bridge"; SKILL.md options and a
  manual fan-out note for the second reviewer until R9 exists.
- `tests/`: scripted harnesses (`run-all.ps1` plus `harness-0.3`, `harness-pending`,
  `harness-fixes`, `harness-lock2`, `harness-3b`) that run against a fake `codex` shim —
  no real `codex`, no quota, your own Codex config never touched. Not part of the
  installed plugin package; see README "Tests" and `tests/README.md`.
- **Wave 10 — R9 (partial): reviewer roster, review panel and the scoreboard.**
  - **Reviewer roster.** A JSON file (`CODEX_CONSULT_ROSTER`, else `<codex
    home>/codex-consult-roster.json`; `CODEX_CONSULT_ROSTER=none` disables it, the
    default file included) naming the reviewers the operator is willing to use, first
    choice first: `{roster_version: 1, reviewers: [{provider, model?, codex_config?,
    auth?: "none", panel?: "always"|"weighty"}]}`. An unusable roster (unknown key,
    `roster_version` != 1, an empty/non-array `reviewers`, a duplicate `(provider,
    model)`, anything that does not parse) refuses every run naming the path, `-DryRun`
    included — an existing roster is never silently ignored. `-Provider` still selects
    the reviewer directly, but the matching roster entry supplies its `model` (when
    `-Model` is empty) and `codex_config` (when `-CodexConfig` is empty); `-Thread`
    still fixes the reviewer from its ledger entry, its roster entry supplying
    `codex_config`; otherwise the bridge walks the roster in order and runs the first
    entry whose credentials are present and whose endpoint health allows a run right
    now, recording every skipped entry with its reason (none available = refused,
    naming every entry). `-Model` without `-Provider` narrows the walk to entries of
    that model. `auth: "none"` declares an endpoint that needs no credential at all
    (ignored for `openai`/`requires_openai_auth` providers). Ledger `roster =
    {path, position, skipped: [{provider, model, reason}], applied: []}`, right after
    `preflight_warning`; console/handoff line `Roster: <path> - position 2 of 3;
    skipped openai :: gpt-5.1 (usage limit until <iso>)`. `codex-providers.ps1` gained a
    `ROSTER` column, a closing `roster: <path> -> would select ...` line, and JSON
    `roster_position`/`roster_selected`.
  - **`provider_failure.retry_after`.** A quota failure's reset time, parsed from the
    message (never guessed): Codex's own wording ("try again at Sep 28th, 2026 8:35
    PM."), a bare ISO-8601 timestamp, or a duration including days/weeks. A quota
    failure whose reset time lies in the future makes the endpoint `unavailable: usage
    limit until <iso>` — refused before the lock unless `-SkipPreflight`, and skipped
    outright in a roster walk. A quota failure with no reset time still only warns for
    60 minutes with an explicit `-Provider` (unchanged from before), but a roster walk
    skips it too ("usage limit N min ago, no reset time given"). `codex-providers.ps1`:
    verdict `unavailable (usage limit until <iso>)`, `LAST FAILURE` column `quota until
    <iso>: ...`, JSON `last_failure`/`last_limit.retry_after`.
  - **The review panel (`-Panel`/`-PanelAll`).** Sends the same brief to every available
    roster entry, sequentially, each a complete consultation in its own lineage — own
    preflight, own lock/pending record, own parent thread, own consultation id, own
    reply file (`handoffs/NN-codex-<ReplyName>-<provider lowercased>.md`) and own ledger
    entry. Every member sees only the findings open when the panel started. A
    `"weighty"` roster entry joins only the weighty purposes (`framing`, `decision`,
    `core-contract`, `acceptance`, `stuck`) unless `-PanelAll` is given. Refused with
    `-Provider`, `-Thread`, `-Mode resume`, or without a roster. Ledger `panel = {id,
    position, of, members: [{provider, model, state: "run"|"skipped", reason}]}`, right
    after `roster`. Members run as child bridge processes (internal `-PanelSpec`, never
    a documented user option). A summary block closes the run; exit `0` only when every
    member produced a usable reply.
  - **`-SchemaTransport output-schema|prompt-only`** overrides caps-v1's declared
    transport for one run (not with `-Raw`); ledger `schema_transport_source`
    (`caps-v1`|`-SchemaTransport`|`''`).
  - **New purpose `chore`** (effort `low`, 400 words): a plain-text reply like `-Raw` —
    no schema, no findings — for bounded search/extraction work handed to a cheap
    reviewer, with a purpose paragraph asking for facts with file paths and line
    numbers, not a verdict.
  - **`codex-findings.ps1 -Stats` per-reviewer scoreboard**: one line per lineage
    (raised, verified, implemented, proposed, rejected, wontfix, superseded), based on
    the reviewer of the ledger entry each finding was ingested from; a finding from
    before 0.3.0, or with no ledger entry, counts as `unknown provenance`.
  - **`extra_config_source`** (right after `extra_config`): `''`, `-CodexConfig`, or
    `roster`, mirroring `model_source`'s new `"roster"` value.
- **Wave 12 — usefulness telemetry (the operator's idea: record which reviewer was
  useful on which kind of question).**
  - **`codex-findings.ps1 -Rate <n> -Useful yes|partly|no [-Note "<why>"]`**: the
    judge's own mark of consultation `n` (a ledger entry number). `findings.json`
    gains a top-level `ratings` array of `{n, consult_id, lineage, provider, model,
    purpose, useful, note, when}` (`lineage`/`provider`/`model`/`purpose` copied from
    that ledger entry); rating the same `n` again replaces its record; `-Note` is
    required for `no`. Takes the task lock exactly like a status change.
    `codex-findings.ps1 -Stats`'s per-reviewer scoreboard gains yes/partly/no columns
    from these marks.
  - **New script `codex-scoreboard.ps1 [-CollabDir <path>] [-Task <task>] [-Json]`**:
    reads every task's ledger and findings store (or one task's with `-Task`) and
    prints one row per `(reviewer lineage, purpose)`, a total row per lineage and a
    grand total — `CONSULTS`, `USABLE`, `PROSE`, `FAILED`, `RAISED`, `VERIFIED`,
    `REJECTED`, `WONTFIX`, `SUPERSEDED`, `OPEN`, `HIT%` (`verified /
    (verified + rejected)`), `A/H/R/D` verdict counts, `Y/P/N` rating counts,
    `MEDIAN_S` (median wall time) and `TOKENS` (uncached input / output); a lineage
    with no reviewer field (pre-0.3.0 entries) is `unknown provenance`. Writes
    nothing, takes no lock, makes no network call; `-Json` gives the same rows with
    numeric fields plus `kind`: `purpose`|`lineage`|`total`.
  - SKILL.md step 3 (read, verify, record) now closes with rating the consultation,
    including a prose reply that raised no findings — otherwise the scoreboard only
    ever counts structured reviewers — and the council rules point at
    `codex-scoreboard.ps1` for choosing a panel or a judge on a hard question.
- `tests/harness-roster.ps1` (113 cases) added, covering all of the above; runs under
  Windows PowerShell 5.1 and pwsh 7.6 like `harness-0.3.ps1`.
- **Wave 14 — contract-first prompt and format-repair retry.** Live use on a
  `prompt-only` route surfaced reviewers answering in prose even with the schema in the
  prompt, because the output-contract instruction sat mid-prompt, after the schema, and
  the older wording ("write it exactly as you would a normal reply") implicitly licensed
  prose. Two independently-consulted cheap reviewers converged on the same diagnosis and
  the same fix.
  - **Contract-first prompt.** Every structured prompt now OPENS with the "FINAL OUTPUT
    CONTRACT" paragraph, before the ask and the brief, replacing the 0.2.0/0.3.0
    contract text that could be buried past the schema section on a `prompt-only` route.
  - **`-FormatRetry 0|1`** (default `1`; refused for any other value): when the run is
    structured (not `-Raw`, not `chore`), the bridge got a usable reply (exit 0, no
    timeout, no provider failure) that fails to parse or validate as the schema, the
    thread is verified (from the event stream or a verified rollout), and the prose is
    substantive (≥120 words, or ≥40 with a numbered answer at a line start) — the bridge
    fires ONE repair turn: `codex exec ... resume <thread> -`, read-only, the route's
    lowest effort, no `--output-schema`, a prompt asking to convert the previous message
    verbatim into the one JSON object (schema and consultation id in the prompt, never
    the brief), within `min(-TimeoutSec, 300)` s, under the same lock and recovery
    record. A wrong-but-valid verdict is never retried — only a reply that fails to
    parse or validate at all.
  - On success the repaired object is ingested as the reply (`.reply.json` holds it,
    findings and verdict included); the original prose is kept byte for byte as
    `handoffs/NN-codex-<slug>.original.md` and rendered after the structured section
    under `## Original reply (prose, before format repair)`. On failure the prose is
    kept as before (`structured: false`) and `validation_error` gets ` (format repair
    failed: <why>)` appended.
  - **Drift notes** (warnings, never refusals) compare the repaired object against the
    original prose: differing requested checks, differing numbered answers, a finding id
    named in prose but missing from the object, a differing verdict, the longest prose
    sentences not carried into `reply_markdown`, and a repair turn that resumed a
    different thread (recorded in `format_retry.thread`, with the entry's own `thread`
    left unchanged).
  - Ledger `format_retry`, right after `validation_error`: `null` when repair was not
    attempted or is off, otherwise `{attempted, reason, succeeded, thread, wall_seconds,
    usage, drift, original}`. Console: `format repair: <succeeded|failed> in <s> s;
    drift: <n> note(s)`, one `  drift:` line per note; `-DryRun` prints `format retry :
    1 attempt if the reply is not valid JSON` or `format retry : 0 (off)`. Panel members
    inherit `-FormatRetry` from the main run.
  - `tests/harness-format.ps1` (23 cases) added: the contract-first prompt, the repair
    turn's command and prompt, success and failure ingestion, drift detection, and the
    cases that must NOT trigger a repair (a wrong-but-valid verdict, `-Raw`, `chore`, an
    unverified thread, non-substantive prose). Runs under Windows PowerShell 5.1 and
    pwsh 7.6.
- The 0.2.0 contract "a structural error means no verdict and no automatic retry — the
  raw text is kept as the reply body" now has one exception: with `-FormatRetry 1` (the
  default) a substantive prose reply on a verified thread gets exactly one recorded
  repair turn, as above; the original prose is always kept alongside the outcome, win or
  lose.

### Changed

- The default provider is now resolved from the Codex config and always recorded — the
  ledger's `model` field never reads `"config default"` again; it holds the actually
  resolved model (or `unknown` when the config could not be read and no `-Model` was
  given).
- Ledger entries written before 0.3.0 (no `reviewer`/`lineage` field) are treated as
  **unknown provenance**: they are never chosen as an automatic parent, and `-Thread`
  naming one of their threads is refused. Practical consequence: the first 0.3.0
  consultation on a task whose ledger predates 0.3.0 always starts a new thread, no
  matter which provider or model it uses.
- `effort` now equals `effort_sent` (the value actually placed in argv), kept for
  readers of 0.2 ledgers and for `-Stats`; the requested/sent/mapping distinction lives
  in the three new fields above.
- The rollout-file thread-id fallback no longer records a thread on the strength of
  "newest candidate file" alone — it now records one only when that file is verified to
  contain the run's `consult_id`; otherwise the run's `thread` is empty and the
  candidate is kept only as a diagnostic.
- A usable, user-defined `[model_providers.openai]` table now DEFINES the `openai`
  identity (its own `base_url`/`wire_api` become the fingerprint, `identity_note`
  records that the table was used, and `OPENAI_BASE_URL` is then ignored); an unusable
  such table leaves the default `openai` identity unresolved (an explicit `-Provider
  openai` naming it is refused outright); with no table at all, `OPENAI_BASE_URL`
  remains part of the built-in identity as before. Found by the second reviewer
  (GLM-5.3) in the first live consultation run through `-Provider`
  (`.collab/bridge-0.3-2026-09-24/handoffs/04-...`).
- An absent `wire_api` in a provider table is now canonicalised as `wire_api=default`
  (no protocol asserted) rather than assuming `responses`; `provider_config` then has no
  `wire_api` key, and the header/console show `wire_api: (default)`. A later config edit
  that adds an explicit `wire_api` value now correctly counts as an endpoint change and
  refuses `fork`/`resume` onto the older thread. Same source as above.
- Thread-id extraction from the event stream now consults only `thread.started` and the
  session-start events `session.started`/`session_configured` (top-level or
  msg-wrapped); any other event line, including a `turn.started` carrying a foreign
  `session_id`, is ignored for thread purposes — such a line could previously have been
  recorded as this run's thread. Same source as above.
- `lineage` now displays as `<provider> :: <model>` (was `<provider>/<model>`) — display
  only. Parent-thread selection was changed to compare `reviewer.provider` and
  `reviewer.model` separately, ordinally, plus the fingerprint, rather than the
  `lineage` string; an entry whose `lineage` still reads the old slash form matches
  correctly for that reason. The cross-identity refusal message reflects the new
  display form.
- Peak evaluation moved from once-at-launch to twice: an early check and a second,
  decisive one immediately before launch (hashing the tree/brief takes real time and can
  itself cross a window boundary); see "Added" above for what changed in the ledger.
- **Preflight now fails CLOSED** (MiMo review, `F09-1`): an `unknown` verdict — an
  unresolved reviewer identity, or `codex login status` failing to run at all or timing
  out after 15 s — used to be treated as harmless and let the run proceed; it now
  refuses the same as a missing credential, with a distinct message ("availability
  could not be established (...); pass -SkipPreflight to launch anyway, or fix the
  check"). `-DryRun` still only prints the verdict on all three checks.

### Deferred

- **R9 — review groups and relations** (`-Group`, `codex-findings.ps1 -Link`,
  `relations[]`, `-Stats -Group`) is deferred to 0.4.0 — the reviewer roster, the
  `-Panel`/`-PanelAll` review panel and the `codex-findings.ps1 -Stats` scoreboard
  shipped instead in wave 10 (see "Added" above); a panel's members are still not blind
  ACROSS waves (a later panel on the same task sees an earlier panel's findings). The
  design review
  (`.collab/bridge-0.3-2026-09-24/state.md`) requires, before it ships: an immutable
  group manifest (brief hash, source/artifact fingerprints, purpose, shared
  instructions, frozen baseline findings, member attempts); blind baseline isolation (a
  later group member must not see an earlier member's findings through the prompt — the
  live open-findings block makes sequential members non-blind today); canonical-issue
  membership and report-validity adjudication kept distinct from fix status;
  verification-time records; nullable avoided-rework estimates; idempotent atomic
  relations; failed attempts recorded, not just successful ones. See
  `.collab/bridge-0.3-2026-09-24/` for the full findings trail (`F02-6`, `F02-7`,
  `F02-8`).

### Fixed

- **Atomic store writes on Windows were not atomic under a hard kill.** `Write-TextAtomic`
  replaced the store with `File.Replace` (Win32 `ReplaceFile`), which is documented to
  leave the replaced file gone and the replacement under its temp name when interrupted
  between its steps; the hard-kill harness (`F04-1`) caught exactly that once in a slow
  run (store missing, three stray temp files). The final step is now one rename that
  replaces the target: `MoveFileEx(MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)`
  via P/Invoke on Windows PowerShell 5.1 (compiled once per process; falls back to the
  old path only if `Add-Type` fails), `File.Move(tmp, dst, true)` on PowerShell 7,
  `rename(2)` on Unix (unchanged). The test now re-seeds the store after a failed kill so
  one event counts once, with the assertion kept strict.
- `Stop-ProcessTree` counted a process still shutting down as a survivor (it checked
  descendants right after the kill); it now waits up to 3 s for the killed pids to exit
  before judging survivors — a false survivors record would have kept
  `.consult.pending.json` and blocked the task until the next scan.
- Acceptance-round findings (`F06-1`..`F06-4`, `.collab/bridge-0.3-2026-09-24/`):
  - `F06-1` — the built-in `openai` identity was used whenever no
    `[model_providers.openai]` table was FOUND at the expected spot, which missed a
    declaration hidden by a construct at `model_providers` itself or by an `openai`
    entry written inline inside `[model_providers]`. The scanner now establishes
    whether such a declaration COULD exist before falling back to the built-in identity;
    when it cannot be established, identity is unresolved with a note naming the file
    and the reason, `fork`/`resume` are refused, `-Mode new` still works. A construct
    under an unrelated provider no longer affects the `openai` identity.
  - `F06-2` — parent-thread matching compared the `lineage` DISPLAY string, which is
    fragile against a provider or model name containing `/`. It now compares
    `reviewer.provider` and `reviewer.model` separately (ordinal) plus the fingerprint;
    the display form changed to `<provider> :: <model>` as a consequence (see "Changed").
  - `F06-3` — peak was evaluated once, before the run's own file hashing, which could
    let a long preparation step cross into (or out of) the window unnoticed by the time
    Codex was actually launched. It is now re-evaluated immediately before launch, and
    `-OffPeakOnly` acts on that result: a run that enters the window during preparation
    is withdrawn at launch with no ledger entry. Test hook `CODEX_CONSULT_NOW` added to
    make both evaluations reproducible in the harnesses.
  - `F06-4` — `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` ranges longer than a few days were
    rejected as malformed; they are now accepted as intervals of any length, and only
    `end < start` is refused.
- A pwsh `[DateTimeOffset]`/`[datetime]` normalisation gap in the usage-limit scan
  (`Find-UsageLimitFailure`) that could misjudge a ledger entry's age under PowerShell 7
  the same way the 0.2.0 lock/recovery comparisons once did (see 0.2.0 Fixed) is closed
  by parsing `when` through the same tolerant path.
- MiMo-review findings (`F09-1`..`F09-4`, third reviewer, first live consultation on a
  `prompt-only` route, `.collab/bridge-0.3-2026-09-24/handoffs/09-...`): preflight's
  `unknown` verdict silently proceeding (see "Changed" above, `F09-1`); a failed
  consultation carrying no structured record of WHY it failed, which endpoint health now
  needs (`provider_failure`, `F09-2`); endpoint health being scoped to one task's ledger
  and to a provider ALIAS rather than every ledger and the actual endpoint fingerprint,
  which let the same endpoint under two names hide a real auth failure from each other
  (`F09-3`); no distinct refusal for a recently-auth-failed endpoint, which used to look
  identical to a routine missing-credential refusal (`F09-4`).
- **`F12-2`.** The failure-class order was not deterministic against a message
  matching more than one keyword set, and `auth`'s keywords were not word-bounded (a
  message containing "text authored by" could misclassify as `auth`). Failure classes
  are now tried in a fixed order — `capability`, `auth`, `quota`, `transport` — so "your
  token plan does not support response_format" is always `capability`, never `quota`;
  `auth` now matches whole words only; `capability` also matches "does not support" (not
  just "not supported"/"unsupported"); `quota` also matches `rate_limit`/`usage_limit`
  (underscore form, as some endpoints spell it) alongside the existing keywords.
- `codex login status`'s output is now decoded as UTF-8 (it was read with the console's
  default codepage before), matching Codex's stderr and event stream, which were already
  UTF-8; a non-ASCII line in the login status (a non-English account name, for instance)
  no longer risks a garbled credential check.
- **Wave 11 — four defects found by the first live review panel**
  (`F15-1`..`F15-4`, `.collab/bridge-0.3-2026-09-24/`, fixing wave 10's own design):
  - **`F15-1` (blocker).** A reset time parsed from a wall-clock message (e.g. "try
    again at Oct 26th, 2026 8:35 PM") is now interpreted with the recording machine's
    time-zone rules (`[TimeZoneInfo]::Local`) **at write time**, DST included — an
    invalid hour (a spring-forward gap) takes the post-transition offset, an ambiguous
    hour (a fall-back overlap) the pre-transition one — and stored as an instant,
    `provider_failure.retry_after`, carrying that offset. A legacy entry with no
    `retry_after` falls back to reparsing its message using the failure's own `when`
    offset as the reference zone, labelled internally `RetryAfterBasis
    "message (reference offset)"` (a fresh write's is `"ledger"`). Residual: such a
    legacy entry, read on a machine in a different zone than the one that recorded it,
    can still be off by the zone difference, since no zone was ever stored for it; every
    entry written from now on is a true instant.
  - **`F15-2` (major).** Ledgers are now parsed with `ConvertFrom-Json -DateKind
    Offset` when the cmdlet has that parameter (pwsh >= 7.5), so `when` keeps its
    recorded offset instead of being silently converted to a local `[datetime]`;
    Windows PowerShell 5.1, which has no such parameter, keeps reading these fields as
    plain strings, unchanged.
  - **`F15-3` (major) — the panel contract is narrowed.** A member's failure no
    longer unconditionally leaves the others running: when it leaves surviving
    processes behind (the task's `.consult.pending.json` reservation stays active),
    the remaining members are not started at all and are recorded `skipped` with
    reason `not started: the previous member (<lineage>) left surviving processes
    (.consult.pending.json state survivors); recover the task first` (summary
    `skipped  not started: ...`, exit 1) — the one-consultation-per-task rule stays
    absolute, even inside a panel run.
  - **`F15-4` (minor).** Endpoint-health records dated in the future are no longer
    ignored; their age clamps to 0 ("counts as now"), so a skewed clock can no longer
    hide a fresh auth or quota failure behind an apparently ancient timestamp.

### Known limitations

- Codex profiles selected via the CLI (`-p`/`--profile`) are never passed by the bridge;
  a `profile` key in the Codex config IS detected (it leaves reviewer identity
  unresolved and disables automatic fork/resume), but the bridge still cannot know what
  that profile would do to the provider, model or effort before the fact.
- The TOML scanner is a constrained subset (see "A second reviewer through the same
  bridge" in the README) — it refuses rather than guesses, but it is not a TOML parser.
- Other built-in Codex providers (`oss`, `ollama`, `lmstudio`, …) are not recognised —
  only the built-in `openai` identity and `[model_providers.<name>]` tables are.
- TOML 1.1 unicode bare keys make the file unusable to the scanner (it only accepts
  ASCII bare keys); quote the key as a workaround.
- `openai`'s auth mode (API key vs ChatGPT sign-in) is not part of the provider
  fingerprint — switching auth mode does not start a new lineage.
- Peak-hour windows are re-checked immediately before launch (see `F06-3` above), but
  a long consultation can still cross into a peak window after that point — there is no
  third, mid-run check.
- `CODEX_CONSULT_NOW` is a TEST HOOK for the harnesses (successive comma-separated ISO
  timestamps stand in for the system clock across a run's peak evaluations); it should
  never be set in normal use.
- `effort_confirmed` is not observable through Codex's event stream and is always
  `null`.
- The credential preflight (and `codex-providers.ps1`) can only see what is LOCALLY
  present — an `env_key` set, a bearer token in the config, a ChatGPT login. It cannot
  see actual quota or rate-limit state; the "last limit"/"last failure" it reports is the
  newest past failure recorded in this repository's own ledgers, not a live check. A
  credential's validity is only ever learned from a failed run — the bridge records and
  reacts to that failure, it cannot probe.
- MiMo's exact wording for exhausted credits is unverified (the quota keyword list
  includes `credits`/`token plan`/`payment required` as a best guess, not a confirmed
  message).
- macOS is still not exercised for 0.3.0's provider/config-reading paths.
- What Codex itself does with a user-defined `[model_providers.openai]` table, and with
  a provider table's default `wire_api`, were not verified against the Codex source;
  both rules are conservative either way.

## [0.2.0] - 2026-09-24

Implements ROADMAP R1–R6 and TECH_DEBT T1–T4, agreed between the Claude Code coordinator
and the Codex reviewer on 2026-09-23 after a seven-wave task with three consultations,
then refined through a design-review round (`.collab/bridge-0.2-2026-09-23/`) that put a
HOLD on the first design and adopted the schema, locking and revision-binding contracts
below before implementation started. The implementation itself then went through two
live `-Purpose acceptance` rounds: the first came back **HOLD, 11 findings**, and the
re-acceptance round that followed it raised four more (`F06-1`, `F06-2`, `F06-3`,
`F04-10`) that led to the final ownership/recovery split described under T3; a second
re-acceptance narrowed the HOLD to `F04-10` alone (recovery must not trust a dead launcher
or elapsed time), and the third re-acceptance on 2026-09-24 returned **ACCEPT** with one
informational note (`F10-1`, the documented conservative-refusal trade-off). Every finding
was fixed and verified, or recorded as an accepted limitation, before this release. Full
trail in `.collab/bridge-0.2-2026-09-23/` (`handoffs/04`, `06`, `08`, `10` are the four
acceptance replies; `state.md` is the record).

### Added

- `ROADMAP.md` and `TECH_DEBT.md`, each with a per-item **Status (0.2.0)** line recording
  what shipped, what is partial, and what is deferred and why.
- **R1 — core-contract checkpoint** (`-Purpose core-contract`): a review meant to run
  before dependent work is built on the core, re-triggered by changes to recovery,
  persistence or interfaces; xhigh effort, 900-word preset.
- **R2 — brief templates**: `templates/brief-framing.md` (framing/decision/stuck) and
  `templates/brief-review.md` (checkpoint/core-contract/acceptance/diff-review), covering
  delta-since-last-review, CURRENT invariants, changed files with fingerprint, open
  findings, evidence paths, and small critical executables inline.
- **R3 — structured findings** via Codex `--output-schema` (schema v1,
  `schemas/consult-reply.schema.json`): every reply is parsed and validated by default;
  findings carry `severity`, `locations[]`, `claim`, `trigger`, `evidence[]`
  (`kind`/`reference`/`observation`), `verification`, `remedy`, `supersedes[]`. `-Raw`
  opts back into the 0.1 plain-text mode.
- **R4 — acceptance output standard**: every structured reply's rendered file ends with
  `### Findings`, `### Prior findings`, `## Verdict`, `### Blockers`,
  `### Unproven scenarios`, `### First-run checklist (observable)`.
- **R5 — review-purpose presets with measurements**: `-Purpose framing|decision|
  checkpoint|core-contract|acceptance|diff-review|stuck`, each with a default effort and
  word cap; `codex-findings.ps1 -Stats` reports effort, wall time, tokens and finding
  counts per consultation.
- **R6 — role-split guidance**: a "Role split" section in the skill and the README
  documenting primary (not exclusive) responsibilities between a same-family verifier and
  Codex.
- **T1 — findings tracked by id**: `<task>/findings.json`, ids `F<NN>-<k>`, status
  lifecycle `proposed → implemented → verified` with `rejected`/`wontfix`/`superseded`
  and an explicit reopen; new script `scripts/codex-findings.ps1` (`-List`, `-All`,
  `-Stats`, `-Id … -Status … -Note … -Evidence …`).
- **T2 — revision and artifact binding**: `tree_sha256` (a deterministic manifest
  fingerprint over `<XY> <mode> <blob|deleted|dir> <path>`, before and after the run —
  the `<mode>` field, from `git diff --raw HEAD`, was added after the live acceptance
  review found a file-mode-only change did not move the fingerprint; **values of
  `tree_sha256` from before this field are not comparable with values computed after**),
  `base_commit`, `brief_sha256`/`brief_sha256_after`/`brief_changed_during_review`, and
  `-Artifact <path>` (repeatable, or comma-separated) hashed into the ledger as
  `artifacts[].{path, sha256, sha256_after}` with an `artifacts_changed_during_review`
  flag — the brief and every artifact are now fingerprinted before and after the run,
  independently of the tree, so an edit to either during a long consult is caught even
  when the tree itself never moved. `fingerprint_note` records every omission (untracked
  file modes not recorded, submodules not recursed, collab dir excluded, no git).
- **T3 — outcome/verdict separation and an active-session guard**: `bridge_outcome`
  (did the bridge produce a usable reply) is now separate from `verdict` (what the
  reviewer decided). Ownership and recovery ended up as **two separate, permanent
  files**, the design settled by the re-acceptance round: `<task>/.consult.lock` is
  never deleted and its content is purely informational — ownership is holding it open
  (Windows `FileShare.Read`, elsewhere an advisory `flock`), and release is just closing
  the handle, so there is nothing left to "unlock" and no pid/start-time/nonce heuristic
  to get wrong. `<task>/.consult.pending.json` is the actual recovery record (states
  `reserved → launching → running → survivors`), read and judged by the next run before
  it writes anything: a live codex process named in it (found by pid for
  `running`/`survivors`, or by a process scan for `launching`) refuses the new run;
  otherwise the interrupted run's reservation is consumed and the record replaced, and
  numbering skips past it. Both `.consult.lock` and `.consult.pending.json` are
  git-ignored. `sessions.json` and `findings.json` are now replaced atomically (temp
  file + rename) and an existing store that fails to parse is treated as corruption and
  refused, never silently replaced. Artifacts and the brief are now re-hashed after the
  run by the exact resolved path recorded at the first hash, not by name.
- **T4 — brief hygiene**: the review templates are delta-plus-pointers by design, with an
  explicit CURRENT-invariants section so a resumed thread's brief does not have to retell
  its own history.
- `scripts/codex-consult-common.ps1`: shared helpers dot-sourced by both scripts.
- `ROADMAP.md` "Additional reviewers" (R7 provider support with reviewer lineages, R8
  requested checks, R9 review groups), agreed from one brief answered independently by the
  Codex reviewer and by GLM-5.3 (`.collab/multi-model-2026-09-23/`), with the facts that
  shaped it: the bridge already runs a second model through a Codex `model_providers`
  entry, `--output-schema` is not enforced server-side on that route (the reply comes back
  as a fenced JSON block, which the 0.2.0 parser accepts and validates locally), and a Codex
  thread cannot change provider once it holds compaction items.
- This repository's own consultations under `.collab/` (the 0.2.0 design review that put a
  HOLD on the first design, and the additional-reviewers brief), committed as the first
  real examples of the file trail the bridge produces.
- `examples/`: the fabricated example brought up to the 0.2.0 shapes (`sessions.json`
  entry fields, `.reply.json`, `findings.json`, rendered reply sections).

### Changed

- **Breaking:** the ledger field `outcome` is renamed to `bridge_outcome`. Existing
  `sessions.json` files are left untouched — the loader only reads `thread` back — but
  any tooling reading `outcome` from new entries must be updated.
- `-Effort` and `-MaxWords` no longer have fixed defaults (`high`/`700`); with no value
  given, they resolve from the `-Purpose` preset (`high`/`700` when no purpose is given
  either, so an unqualified call behaves as before).
- The reply file's `NN-` prefix matcher now accepts three or more digits, so a
  handoffs directory past `99-` numbers correctly (`100-…` → next is `101-…`).
- Write order per consult is now `.reply.json` (byte-for-byte, before parsing) → `.md`
  → `findings.json` → `sessions.json`; a failed copy of the raw reply is itself a bridge
  failure (`bridge_outcome = "failed: could not preserve the raw reply (…)"`) rather than
  proceeding to parse a reply that was never safely captured.
- Verdict validation now also checks that the verdict fits the purpose
  (`ACCEPT`/`HOLD`/`REJECT` for `acceptance`/`diff-review`, `ADVISE` otherwise) and that
  `ACCEPT` does not contradict a prior open blocker reported `still-open`; an `ACCEPT`
  next to a prior blocker reported `not-checked`/`unknown-id`/unmentioned is kept but
  recorded in the new `unchecked_prior_blockers` ledger field with a console warning.

### Removed

None.

### Fixed

- PowerShell 7 only: `ConvertFrom-Json` in pwsh converts ISO-8601 strings to `[datetime]`,
  so the recorded start time of a lock holder or codex child no longer compared equal to
  the live process's start time and a live holder was reported as "a live process" instead
  of by pid (and, in the recovery check, could be mistaken for a reused pid). The four
  affected reads now normalise the value back to JSON text. Found by the first pwsh run
  of the harnesses (2026-09-24); Windows PowerShell 5.1 was never affected.
- Linux only (first run on WSL Ubuntu 24.04 with pwsh 7.6, 2026-09-24): a process start
  time read through .NET on Linux can differ by under a second between readers, so the
  exact comparison declared a live codex child a reused pid and let a second consultation
  start beside it (now a one-second tolerance off Windows, exact on Windows); the holder's
  own lock file could not be read back through a shared `FileStream` because the advisory
  lock blocked it, so refusals named "a live process" instead of the pid (read via `cat`
  off Windows); the timeout kill stopped children before the root, leaving the root a
  window to spawn more (root first now).

- Recovery no longer treats a dead launcher, or elapsed time, as proof that the codex
  tree is gone (second re-acceptance, F04-10): when every pid a `running`/`survivors`
  record names has exited, and for a `launching` record, the next run scans for children
  of the dead bridge or of a dead recorded pid and then for any codex-looking process
  started after the record; the earlier thirty-minute cut-off on that fallback is gone.
  A refusal names the process and the record; deleting `.consult.pending.json` is the
  deliberate way to clear a refusal you know is unrelated.

### Known limitations

- Cross-host lock takeover is not implemented — a lock left by another host that names
  a live codex process is always refused, and can only be cleared by hand once you know
  that process is dead; a same-host leftover recovers automatically and needs no manual
  deletion.
- Thread-scoped exclusion (one Codex thread resumed from two task directories) is
  documented as a constraint, not enforced.
- No immutable snapshot of the reviewed tree; the before/after fingerprint (now also
  taken for the brief and every artifact) flags a changed input instead of preventing
  the race.
- macOS is not exercised; the Linux run (WSL Ubuntu, pwsh 7.6) covers the same pwsh
  code paths (`flock` share mode, `ps` scan, `pgrep` tree kill), but no macOS machine
  was available.
- On Unix the atomic replace of a store resets its permission bits to the default;
  messages render dates in an invariant format on every platform.

## [0.1.1] - 2026-09-23

### Added

- Project-isolation guarantees written down (README "Project isolation", skill
  invariant 5): the ledger, the `fork`/`resume` parent thread and Codex's working
  directory are all scoped to the git repository the bridge runs from, so one
  user-scope install serves many projects; a repository with no ledger starts a fresh
  thread. Verified with a throwaway repository. Also spelled out what is *not*
  enforced: the read-only sandbox blocks writes, not reads, so briefs must stay inside
  the repository and a `-Thread` id must never be borrowed from another project.

### Changed

- No script changes. Version bump only, so installed copies pick up the new skill text.

## [0.1.0] - 2026-09-22

First public release.

### Added

- `codex-consult` plugin, installable from the `claude-codex-consult` marketplace.
- Skill `consult-codex`: when to consult Codex, how to write a one-page brief with
  numbered questions and a word cap, the one command to run, and the read-verify-record
  loop that follows.
- `scripts/codex-consult.ps1`, a dependency-free bridge to `codex exec`:
  - `-Mode new|resume|fork` with automatic thread continuity per `-Task` id;
  - `-Model` optional — with no `-Model`, Codex uses the model from the user's
    `~/.codex/config.toml`;
  - read-only sandbox by default, `danger-full-access` refused with no override;
  - exec-level options emitted before the `fork`/`resume` subcommand;
  - the prompt delivered on stdin via `-`, so the Windows `codex.cmd` shim cannot
    expand `%VAR%` patterns inside a brief;
  - thread id parsed from the first `--json` `thread.started` event, with a
    `$CODEX_HOME/sessions/**/rollout-*.jsonl` fallback and a `thread_source` field
    recording which one was used;
  - failure detail lifted from the JSON event stream (`error` / `turn.failed`), where
    Codex reports quota and auth failures — stderr is only a fallback;
  - reply written as header + `---` + the verbatim reply, next to the raw
    `.events.jsonl` event stream;
  - every call appended to `<CollabDir>/<task>/sessions.json`, failures included;
  - `-DryRun`, `-CollabDir`, `-CodexExe` / `CODEX_CONSULT_EXE`, `-TimeoutSec`,
    `-MaxWords`, `-Effort`, `-ReplyName`.
- `examples/` with a fabricated brief, reply and ledger showing the produced layout.

### Known limitations

- Exercised on Windows PowerShell 5.1 with Codex CLI 0.155.1. PowerShell 7 and
  macOS/Linux are written for but not yet verified.
- No bash port yet, so macOS/Linux currently needs `pwsh`.

[0.3.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.3.0
[0.2.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.2.0
[0.1.1]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.1
[0.1.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.0
