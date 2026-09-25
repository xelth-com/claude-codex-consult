# Roadmap

Features the bridge should grow. Each entry names the problem it solves; the order is the
order we would build them. Agreed on 2026-09-23 between the Claude Code coordinator and the
Codex reviewer after a seven-wave implementation task with three consultations (framing,
acceptance, re-acceptance), and merged with the earlier help-wanted list.

## Review workflow

- **R1 — Core-contract checkpoint preset.** A review mode meant to run BEFORE dependent
  implementation starts (once the core interfaces, recovery and persistence paths exist) and to
  be re-triggered by changes to recovery, persistence or interfaces. Rationale: on the task that
  motivated this list every acceptance HOLD cost a full fix wave, because the core had been
  built on and the state-machine defects were found only at the end. Reviewing every mechanical
  wave is not the answer; reviewing contract boundaries is.
  **Status (0.2.0): shipped** — `-Purpose core-contract` (xhigh effort, 900-word preset),
  narrowed by amendment to the interfaces and state machines named in the brief rather than
  the whole system, to fit the word budget.
- **R2 — Brief template.** A skeleton the coordinator fills for a checkpoint or acceptance:
  delta since the last review, the invariants claimed, changed files, unresolved findings,
  evidence paths, and the decision requested. Small critical executable files (a boot hook, an
  install script) go inline; everything else by exact path and revision. Rationale: a spec-only
  brief hid a one-character glob bug in a 100-line hook that a code reader would have seen.
  **Status (0.2.0): shipped** — `templates/brief-framing.md` and `templates/brief-review.md`.
- **R3 — Structured findings companion.** Beside the Markdown reply, a machine-readable list
  (via Codex `--output-schema`, already on the help-wanted list): finding id, severity,
  file:line, claim, trigger, evidence level, verification step, proposed remedy. Rationale: the
  coordinator verifies every finding before acting; a parseable list makes that step and the
  later "verified" bookkeeping (see TECH_DEBT T1) mechanical. Structure is not proof; the
  verification step stays.
  **Status (0.2.0): shipped**, revised beyond the original proposal after a design-review
  HOLD: `evidence` became an array of `{kind, reference, observation}` (what was already
  checked, not just a level), `locations[]` replaced a `"path:line"` string, and every reply
  is locally validated against the schema (see TECH_DEBT T1 status).
- **R4 — Acceptance output standard.** Every acceptance reply ends with four fixed blocks:
  verdict, blockers, unproven scenarios, and an OBSERVABLE first-run checklist (what must be
  in the logs before an exit code 0 is believed). Rationale: "what would justify acceptance?"
  was the most useful thing the reviewer produced, and it should not depend on being asked.
  **Status (0.2.0): shipped** — the four blocks are rendered LAST in the reply file (after
  the verbatim prose, findings and prior findings), per the design-review amendment.
- **R5 — Review-purpose presets with measurements.** Presets for framing / checkpoint /
  acceptance / diff review with default effort levels, and a ledger record of effort, latency
  and the rework each review triggered. Rationale: a medium-effort checkpoint may be the right
  trade for quota, but today there is no comparison that proves it; measure first.
  **Status (0.2.0): shipped** — the preset table plus `codex-findings.ps1 -Stats`, joining
  findings to the consultation that produced them via `source.consult`.
- **R6 — Role-split guidance.** Document primary (not exclusive) responsibilities when two
  reviewers exist: a fresh-context verifier of the same model family for mechanics (lint,
  interpreter compatibility, build, test wiring) and the Codex reviewer for protocol, state
  machines and "what the evidence does not show". Either may challenge anything. Rationale: on
  the motivating task the two found mostly different defects; together they were the coverage.
  **Status (0.2.0): shipped** — a "Role split" section in the skill and the README; no
  tooling enforces it, it is guidance for the coordinator.

## Additional reviewers (planned for 0.3.0)

Agreed on 2026-09-23 from one brief answered independently by the Codex reviewer and by
GLM-5.3 (`.collab/multi-model-2026-09-23/`). Facts that shaped it: Codex CLI runs GLM-5.3 as
its model through the z.ai devpack provider (`-c model_provider=ZAI -m glm-5.3`) and the bridge
already works that way end to end; `--output-schema` is NOT enforced server-side on that route
(the reply came back as a fenced JSON block, field-complete, which the 0.2.0 parser accepts and
validates locally); a Codex thread cannot be resumed under another provider once it holds
OpenAI compaction items. Both reviewers agreed that an additional model is a measured,
optional participant whose "done" is never trusted and who never closes a finding.

- **R7 — Provider support with reviewer lineages.** `-Provider <name>` on the bridge (a
  `model_providers` entry from the user's Codex config), with every thread bound to
  provider + model + harness (+ a config fingerprint); the parent thread for `fork`/`resume`
  chosen from the latest thread WITHIN that lineage, never the task's latest thread globally;
  fork/resume across lineages refused; the resolved model recorded instead of "config default";
  per-provider effort mapping (Codex `low|medium|high|xhigh`, GLM `low|high|max`) with requested
  and effective values in the ledger; a provider allowlist; a peak-hour warning with optional
  off-peak-only enforcement and per-consult credit estimates (the tariff calendar is not
  hard-coded — it changes). Only supported-tool routes (Codex CLI, Claude Code) ever carry plan
  credentials; the bridge never makes a direct HTTP call. Until R7 exists, a second model is
  consulted through the Claude Code worker wire and its reply saved as a handoff by hand.
  **Status (0.3.0): shipped**, after a design-review round
  (`.collab/bridge-0.3-2026-09-24/`, findings `F02-1`..`F02-9`) that amended the design
  before implementation: provider identity is read from the Codex config (or given
  explicitly) rather than assumed `openai`, via a constrained TOML scanner that refuses
  (naming the line) any construct it does not understand rather than guessing; the
  compatibility identity gating `fork`/`resume` across a lineage is narrowed to
  `base_url` + `wire_api` only (a canonicalised fingerprint), so comments, key order and
  secret rotation never break a lineage while an endpoint or protocol change does; a
  per-run `consult_id` in the prompt makes the rollout-file thread fallback verified
  rather than a best guess (an unverified candidate is kept only as a diagnostic, never
  as a parent); effort vocabularies are keyed by the provider's endpoint host (with
  no model-prefix fallback since F02-4: only models declared for the host) instead of by alias, `-NativeEffort` as the escape hatch, and
  `effort_requested`/`effort_sent`/`effort_mapping`/`effort_confirmed` (the last always
  `null` — not observable) replace a single `-Effort` value; peak-hour handling got exact
  semantics (fixed offset, inclusive start/exclusive end, overnight windows, exception
  dates; checked early and again immediately before launch - the launch-time result governs) and `-OffPeakOnly` refuses on an unknown schedule as well as
  on peak. Legacy (pre-0.3.0) ledger entries are unknown provenance and are never
  automatic parents — the first 0.3.0 consultation on an old task always starts a new
  thread. Not adopted: per-consult credit estimates (the tariff calendar is not
  hard-coded and estimating it well is its own project) and a provider allowlist beyond
  "must be a table the scanner can read".
- **R8 — Requested checks.** A reviewer may list `requested_checks[]`: one command or
  procedure + expected observation each, tied to a finding or invariant, capped per brief; the
  coordinator chooses the executor (a cheaper model or a worker) and records completion
  separately with revision, log, exit status and observed result. `unproven[]` keeps the
  uncertainty, `requested_checks[]` says how to resolve it. First a brief/reply convention,
  then a schema field once it has been used a few times.
  **Status (0.3.0): shipped as a convention, not a schema field** — the structured-mode
  prompt asks Codex to end `reply_markdown` with a `## Requested checks` section
  (`RC1..RCn`, at most 5, each one command/procedure with cwd, permission, expected
  observation and budget) when it has evidence it cannot obtain read-only; the schema
  stays v1 and the bridge renders nothing extra. `templates/brief-review.md` gained a
  "Requested checks run" table for the coordinator to fill in the next brief. A schema
  field remains for later, once the convention has real usage to generalise from.
- **R9 — Review groups for fan-out.** One revision-bound brief to two reviewers in fresh
  threads, neither seeing the other's answer first, at contract boundaries and acceptance only.
  Their findings keep separate ids; the coordinator links them to a canonical issue with
  `corroborates` / `contradicts` / `duplicates` under a review-group id. Agreement prioritises
  investigation and may lighten a spot-check; it never replaces verification. Measured by
  unique verified defects, false positives, coordinator verification minutes and avoided
  rework; routine fan-out stops when the margin is poor.
  **Status: partially shipped in 0.3.0, the rest deferred to 0.4.0.** The reviewer
  roster (`CODEX_CONSULT_ROSTER`, an ordered list of reviewers with credential/panel
  metadata) and the review **panel** (`-Panel`/`-PanelAll`: the same brief sent to every
  available roster entry, sequentially, each its own consultation in its own lineage,
  own reply file and own ledger `panel` record) shipped, along with the per-reviewer
  **scoreboard** (`codex-findings.ps1 -Stats`: raised/verified/implemented/proposed/
  rejected/wontfix/superseded per lineage) — see the README's "Reviewer roster and
  panel" section. What did NOT ship, and stays deferred to 0.4.0
  (`.collab/bridge-0.3-2026-09-24/state.md`; findings `F02-6`/`F02-7`/`F02-8` recorded
  `wontfix` in the 0.3.0 task with a pointer here): the panel is explicitly **NOT blind
  between waves** — every member of one panel run sees the same open-findings snapshot
  taken when the panel started, which is a real improvement over ad hoc sequential
  fan-out, but a later panel on the same task still sees the earlier panel's findings,
  so cross-wave independence still does not exist; there is still no `corroborates`/
  `contradicts`/`duplicates` relation tooling (`-Link`), no canonical-issue id, and no
  grouped stats beyond the per-lineage scoreboard. Before that ships it still needs: an
  immutable group manifest (brief hash, source/artifact fingerprints, purpose, shared
  instructions, frozen baseline findings, member attempts); genuine blind baseline
  isolation across waves; canonical-issue membership and report-validity adjudication
  kept distinct from fix status; verification-time records; nullable avoided-rework
  estimates; idempotent atomic relations (`-Link` must not create duplicate or
  asymmetric edges on a retry); and failed attempts recorded, not only successful ones.
- **R10 — Engines: each provider through its own official protocol (planned for 0.4.0).**
  Today every reviewer is reached through `codex exec`, whose only structured-output path is
  the Responses API `json_schema` response format — ignored by some third-party endpoints and
  rejected by others, which is why 0.3.0 needed the contract-first prompt and the one
  format-repair turn. The same models answer with native structured output when consulted
  through the CLI their provider officially supports: Claude Code headless
  (`claude -p --json-schema <schema> --output-format json`, an Anthropic-compatible endpoint
  in the child process only; `--resume`/`--fork-session` for lineage) and Google's
  Antigravity CLI (`agy -p --json-schema ... --output-format json`, `--conversation <id>`),
  which share one flag surface — verified live on 2026-09-25 with a GLM route, a MiMo route
  and a Gemini model, each returning `structured_output` on the first turn. R10 adds a roster
  field `engine` = `codex` (default) | `claude` | `agy`, one headless adapter for the
  Claude-Code-style CLIs (argv, JSON envelope, session id as the thread, usage), the same
  ledger, findings, panel, scoreboard and preflight (credential = the CLI's own login or the
  endpoint's env key; a CLI that reports `authentication required` is `unavailable`), and
  caps-v1 entries per engine (effort vocabulary, schema transport `native`). Non-goals: any
  direct HTTP client with a subscription key (the plans forbid it), a gateway/proxy between
  Codex and a provider, and mixing engines inside one lineage (a thread belongs to one
  engine as it belongs to one provider). Measured by first-turn structured rate per route
  and by the scoreboard's hit rate per (engine, provider, purpose).
  **Status (0.4.0 candidate, wave 17): `agy` shipped, `claude` next.** The engine table
  (`$script:Engines`) with its first row `agy` - after a design round with a panel (GLM,
  MiMo) and Gemini itself (`.collab/engines-0.4-2026-09-25/`), whose amendments A1-A20 are in
  the code: stdin stream-json transport (one NDJSON line), default mode `new`, the
  conversation-id rules (a resume, repair or retry that lands in another conversation
  fails), exactly one `result` event, the F11 denial retry, the `permission` failure class
  and Google's error/retry wordings, `agy models` as the sign-in check (never in the hook),
  and - because agy's `--sandbox` does not block writes (F12) - the bridge's tree check
  failing any agy run that changed the working tree or (wave 18) anything in the collab
  directory; wave 18 also records the retry turns' event streams in the ledger, rejects
  trailing garbage after exit 0, warns on a non-unique `-Provider` label and gives the
  sign-in check 45 s plus a ledger short-circuit (a usable agy reply within 60 minutes).
  Gitignored paths, submodules and files outside the repository stay unmonitored. The `claude`
  engine is the next row of the same table (argv, stdin, event parser, turn rules,
  credential) without touching the run block again. Open: TECH_DEBT T7 (an agy lineage binds
  engine + label + model, not the signed-in account).
- **R11 — Parallel panel (0.4.x wave 21 - implemented in the 0.4.0 candidate; first live run
  2026-09-26: 8 members, at most 7 at a time, 30 min wall clock against about 107 min summed).** A `-Panel` run consults its
  members one after another (README, "Reviewer roster and panel"), so its wall clock is the
  SUM of the members' times (a two-member framing panel today: 8-12 minutes). The members are
  already independent — each gets the same brief and the same snapshot of the findings that
  were open when the panel started, never another member's reply — so nothing in the review
  itself needs the order; what forces it is the machinery: one task lock (`.consult.lock`)
  and one recovery record per task, the ledger appended under that lock, handoff numbers
  taken at each member's start, and a survivor scan that looks for codex-like processes by
  NAME and would take a sibling member's process for an orphan. R11 runs the members
  concurrently: a panel-level lock that owns the task for the whole panel, `n` and `NN`
  assigned to every member when the panel starts (so the files and ledger entries keep the
  roster order whatever finishes first), one recovery record per member (`.consult.pending-
  <member>.json`, the recovery path checks all of them), the survivor scan by the recorded
  pid + start time only, and one summary written after the last member. Invariants kept: the
  members stay blind to each other inside a wave; the same open-findings snapshot; exit 0
  only when every member produced a usable reply; nothing already written is lost when one
  member dies. The agy engine's collab-root snapshot (0.4.0, wave 18) must then exclude the
  sibling members' own files, or every concurrent member would fail the others' tree check. Non-goals: concurrent consultations OUTSIDE a panel (two `-Panel` runs or a
  single run beside a panel on one task are still refused by the lock), and any change to
  what a member sees. Measured by the panel's wall clock (max of the members instead of
  their sum) and by an unchanged per-member result set against the sequential harness cases.
  **Status (wave 21, fakes only):** built per the design round
  `.collab/parallel-panel-2026-09-25/` (decisions D1-D13): members in parallel across
  endpoints (one after another within one; roster `"parallel"`, `-PanelConcurrency`), the
  panel run holding the task lock, n/NN and one `reserved` record per member up front,
  the member's proof of its parent, writer liveness for every record, the commit write lock
  with re-read and own delta (single runs and `codex-findings.ps1` too), `finished_at` for
  endpoint health; `tests/harness-panel.ps1`. Next: a live parallel panel reviews the wave.
- **R12 — Non-blocking consultation (planned for 0.4.x, with or after R11).** Today a
  consultation or a panel holds the coordinator's turn until the last reply is in (a
  two-member framing panel: 8-12 minutes; three members: 20+). The coordinator should be
  able to put a question to the panel, go on with other work, and come back to THAT question
  when the panel has finished. Pieces: a `-Detach` switch that validates, locks and
  launches exactly as today but returns immediately with the panel id and the path of a
  status file (`<task>/.panel-<id>.status.json`: members, state per member, the summary
  once written) instead of waiting; a `codex-panel.ps1 -Status <id>` (or
  `codex-findings.ps1 -List`) that prints the state and, when done, the same summary block a
  blocking run prints; the reservation and recovery record unchanged, so a detached run that
  dies is recovered like any other; a note in the consult-codex skill telling the coordinator
  how to park the question (the brief's path and the panel id in `state.md`) and when to
  revisit it (never before every member is `usable` or `failed`). Non-goals: a daemon, a
  queue of consultations, notifications through anything but the status file and the
  hooks a host already runs (a SessionStart/Stop hook may print "panel <id> finished").
  Measured by the coordinator's blocked time per consultation (from the panel's wall clock
  to seconds) with unchanged ledger, findings and recovery semantics.
- **R13 — Host invariance: the same bridge for a Codex-first (or any) coordinator (planned
  for 0.5).** The bridge scripts already run from any coordinator - a Codex CLI session, Cursor,
  a shell - and a reviewer needs no ChatGPT plan (a provider table with an `env_key`
  authenticates on its own; the preflight checks `codex login status` only for `openai`).
  What is Claude-Code-specific is the packaging: the `.claude-plugin` manifest, `hooks.json`,
  `claude plugin eval`, the `${CLAUDE_PLUGIN_ROOT}` paths inside the two skills, and wording
  that names Claude as the judge. R13 makes the host a parameter: (a) the skills reference
  the bridge through one documented root variable with a plain-path fallback, so the same
  SKILL.md files (they already follow the open Agent Skills format) install into
  `~/.codex/skills`, Cursor or any host that reads SKILL.md; (b) an `install.ps1` that copies
  the skills and prints the host-specific lines (Claude Code: enable the plugin; Codex: an
  AGENTS.md snippet with the one command and the process; others: the SKILL.md path); (c)
  the council text says "the coordinator" where it says "Claude" - the judge is whoever runs
  the bridge, and the roster must then avoid consulting the coordinator's own model as a
  reviewer (a lineage equal to the coordinator's model is a warning); (d) the SessionStart
  availability line for hosts without hooks becomes a documented one-liner
  (`codex-consult-hook.ps1`) the coordinator runs at the start of a session. Non-goals: a
  second packaging format per host, a rename of the plugin or marketplace ids (installed
  copies key on them); the short name **CCC** (Claude Codex Consult) is used in the docs until
  1.0.0, which will be released under the name **C3** (the same three words, and a nod to a
  certain protocol droid that translates between parties and never stops advising) - the
  plugin and marketplace ids change only then, with a migration note for installed copies.
  Measured by one fresh Codex-CLI-coordinated consultation from the README alone.
- **R14 — Adaptive companions: panel size and diversity follow the stakes (planned for 0.5).**
  The coordinator never takes a non-trivial step alone, and a panel grows with the stakes instead of
  always taking every available reviewer. This project's own evidence: in the R11 design review
  (`.collab/parallel-panel-2026-09-25/`, three reviewers from three labs) the most serious hole - a
  member's recovery record reading inactive while it commits - was found independently by all three,
  and each of them also found something the other two missed (atomic-write temp files; endpoint
  health ordering and per-endpoint concurrency; commits of other tasks failing an agy member).
  Pieces: (a) a default panel size per purpose (checkpoint 1; framing and decision 2-3;
  core-contract and acceptance 3-5; stuck: every available reviewer), overridable with
  `-PanelSize <n>`; (b) diversity first: members from different labs before a second model of one
  lab (an optional roster field `lab`, defaulting to the provider label); (c) a floor of one
  companion on framing and decision, so a design is never reviewed only by its author - the
  consult-codex skill states it as a rule; (d) diminishing returns documented: past about five
  diverse members, extra reviewers mostly repeat findings while costing quota and wall clock.
  Non-goals: majority voting on verdicts (the coordinator weighs evidence, not votes) and members
  seeing each other inside a wave (blindness stays). When every model shares a blind spot a
  unanimous panel is confidently wrong; the remedy is evidence - findings say what was verified in
  code and what was inferred, and the coordinator checks them (R9) - not more votes.
- **R15 — Telemetry routing: companions chosen by their track record, with exploration (planned
  for 0.5, after R14).** The scoreboard (`codex-scoreboard.ps1`, the `-Rate` usefulness marks,
  reviewer x purpose) becomes the router's input. Selection is a weighted draw, not a fixed order: a
  reviewer's weight grows with its rated usefulness on this purpose - and on topic tags a brief
  carries (`-Topic concurrency,powershell`) - while a small exploration share keeps less-used or
  newly updated models in rotation (a new model id starts with a neutral prior; old marks decay).
  Availability comes first: the draw is only among entries the preflight, quota and peak rules
  allow. Pieces: `-Topic`, a routing record in the ledger (weights, the draw, why each member was
  picked), `codex-scoreboard.ps1 -By topic`. Measured by the share of findings the coordinator rates
  useful per consultation, before and after.
- **R16 — Companion roles (idea).** Besides a general review a companion can take one narrow role:
  edge-case hunter, security reviewer, test designer who proposes failing tests as text, docs
  checker. Expressed as brief templates and purpose presets; members stay read-only and the
  coordinator applies what survives verification.
- **A fourth seat (e.g. MiMo-V2.6)** only after a capped project-local evaluation (seeded
  historical defects plus clean controls at a fixed budget) on an officially supported route;
  leaderboard rank is not that evidence. Consider replacing a role before adding a reviewer.

## Bridge features (earlier help-wanted list)

- **A bash port**, so macOS/Linux users need no `pwsh` at all.
- **A `UserPromptSubmit` hook injector**: inject the last Codex reply into the next turn, or
  detect an `@codex` trigger token and launch a consult. The hook budget is ~30 s by default,
  so a synchronous consult does not fit: inject stored context or fire detached.
- **The reverse direction**: a Codex-side tool that consults Claude.
- **An MCP server variant** with background jobs, so a long consult does not block the turn.
- **Tests on macOS** (Linux via WSL and PowerShell 7 are exercised by `tests/run-all.ps1`; macOS is not).
- ~~**`--output-schema` support** (the substrate for R3).~~ **Shipped in 0.2.0** as the
  substrate of R3 (structured findings).

Issues and PRs welcome for any of these.
