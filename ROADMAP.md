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
- **R8 — Requested checks.** A reviewer may list `requested_checks[]`: one command or
  procedure + expected observation each, tied to a finding or invariant, capped per brief; the
  coordinator chooses the executor (a cheaper model or a worker) and records completion
  separately with revision, log, exit status and observed result. `unproven[]` keeps the
  uncertainty, `requested_checks[]` says how to resolve it. First a brief/reply convention,
  then a schema field once it has been used a few times.
- **R9 — Review groups for fan-out.** One revision-bound brief to two reviewers in fresh
  threads, neither seeing the other's answer first, at contract boundaries and acceptance only.
  Their findings keep separate ids; the coordinator links them to a canonical issue with
  `corroborates` / `contradicts` / `duplicates` under a review-group id. Agreement prioritises
  investigation and may lighten a spot-check; it never replaces verification. Measured by
  unique verified defects, false positives, coordinator verification minutes and avoided
  rework; routine fan-out stops when the margin is poor.
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
- **Tests on macOS and Linux**, and on PowerShell 7 generally.
- ~~**`--output-schema` support** (the substrate for R3).~~ **Shipped in 0.2.0** as the
  substrate of R3 (structured findings).

Issues and PRs welcome for any of these.
