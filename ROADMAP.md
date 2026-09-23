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
- **R2 — Brief template.** A skeleton the coordinator fills for a checkpoint or acceptance:
  delta since the last review, the invariants claimed, changed files, unresolved findings,
  evidence paths, and the decision requested. Small critical executable files (a boot hook, an
  install script) go inline; everything else by exact path and revision. Rationale: a spec-only
  brief hid a one-character glob bug in a 100-line hook that a code reader would have seen.
- **R3 — Structured findings companion.** Beside the Markdown reply, a machine-readable list
  (via Codex `--output-schema`, already on the help-wanted list): finding id, severity,
  file:line, claim, trigger, evidence level, verification step, proposed remedy. Rationale: the
  coordinator verifies every finding before acting; a parseable list makes that step and the
  later "verified" bookkeeping (see TECH_DEBT T1) mechanical. Structure is not proof; the
  verification step stays.
- **R4 — Acceptance output standard.** Every acceptance reply ends with four fixed blocks:
  verdict, blockers, unproven scenarios, and an OBSERVABLE first-run checklist (what must be
  in the logs before an exit code 0 is believed). Rationale: "what would justify acceptance?"
  was the most useful thing the reviewer produced, and it should not depend on being asked.
- **R5 — Review-purpose presets with measurements.** Presets for framing / checkpoint /
  acceptance / diff review with default effort levels, and a ledger record of effort, latency
  and the rework each review triggered. Rationale: a medium-effort checkpoint may be the right
  trade for quota, but today there is no comparison that proves it; measure first.
- **R6 — Role-split guidance.** Document primary (not exclusive) responsibilities when two
  reviewers exist: a fresh-context verifier of the same model family for mechanics (lint,
  interpreter compatibility, build, test wiring) and the Codex reviewer for protocol, state
  machines and "what the evidence does not show". Either may challenge anything. Rationale: on
  the motivating task the two found mostly different defects; together they were the coverage.

## Bridge features (earlier help-wanted list)

- **A bash port**, so macOS/Linux users need no `pwsh` at all.
- **A `UserPromptSubmit` hook injector**: inject the last Codex reply into the next turn, or
  detect an `@codex` trigger token and launch a consult. The hook budget is ~30 s by default,
  so a synchronous consult does not fit: inject stored context or fire detached.
- **The reverse direction**: a Codex-side tool that consults Claude.
- **An MCP server variant** with background jobs, so a long consult does not block the turn.
- **Tests on macOS and Linux**, and on PowerShell 7 generally.
- **`--output-schema` support** (the substrate for R3).

Issues and PRs welcome for any of these.
