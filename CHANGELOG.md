# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `ROADMAP.md` and `TECH_DEBT.md`: the review-workflow improvements (R1–R6) and the known
  protocol weaknesses (T1–T4) agreed between the Claude Code coordinator and the Codex reviewer
  on 2026-09-23 after a seven-wave task with three consultations; the README roadmap section
  now points at them.

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

[0.1.1]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.1
[0.1.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.0
