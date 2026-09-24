# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-23

Implements ROADMAP R1–R6 and TECH_DEBT T1–T4, agreed between the Claude Code coordinator
and the Codex reviewer on 2026-09-23 after a seven-wave task with three consultations,
then refined through a design-review round (`.collab/bridge-0.2-2026-09-23/`) that put a
HOLD on the first design and adopted the schema, locking and revision-binding contracts
below before implementation started. The implementation itself then went through two
live `-Purpose acceptance` rounds: the first came back **HOLD, 11 findings**, and the
re-acceptance round that followed it raised four more (`F06-1`, `F06-2`, `F06-3`,
`F04-10`) that led to the final ownership/recovery split described under T3. Every
finding across both rounds was fixed and verified before this release. Full trail in
`.collab/bridge-0.2-2026-09-23/` (see `handoffs/06-…` for the re-acceptance round).

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
- The Unix branch of the recovery check (the `flock`-based lock share mode, and the
  `ps` scan `Find-CodexProcesses` falls back to for a `launching`-state record) is
  unexercised: the development machine has no `pwsh` install to run it on. Windows
  (`Win32_Process`) is exercised.

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

[0.2.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.2.0
[0.1.1]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.1
[0.1.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.0
