# Handoff 03 - Claude: acceptance of codex-consult 0.2.0

Date: 2026-09-23. Base commit: `6483ec4` + uncommitted (the whole 0.2.0 change set is the working tree).

## Question

Can 0.2.0 be accepted as implementing R1-R6 and T1-T4 under the contracts you asked for in
handoff 02, or what still blocks it? This consultation is itself the first live run of the
structured path (`--output-schema`, fork, findings ingestion, lock, fingerprint).

## Delta since the last review

Follows: `handoffs/02-codex-design-0.2.md` (HOLD on the design as written).

- Every adopted amendment from that HOLD was written into the implementation spec before code
  was written: `evidence[]` of `{kind, reference, observation}`, `locations[]` with nullable
  line, `schema_version`, local validation (structural errors = no verdict and no ingestion;
  ACCEPT with a blocker = invalid verdict, findings still ingested), the raw response copied
  byte for byte, R4 blocks rendered last, `supersedes[]`, explicit reopen, `verified` needing
  `-Evidence`, trigger + verification fed back with prior findings, unreported ids ->
  `not-checked`, unknown ids ignored, ids allocated under the lock, `^(\d{2,})-` matcher.
- Fingerprint: a deterministic manifest (`base <sha>` + one `<XY> <blob|deleted|dir> <path>`
  line per `git status --porcelain=v1 -uall -z` entry, sorted, paths escaped, rename source
  after a TAB), hashed as `tree_sha256`; collab dir excluded; ignored files excluded;
  submodules not recursed; omissions in `fingerprint_note`; computed before and after the run
  with `tree_changed_during_review`. `brief_sha256` and `-Artifact` hashes recorded.
- Lock: `FileMode.CreateNew`, `{pid, start_time, nonce, host, task, started}`, taken before the
  ledger is read and before NN is allocated; same-host dead pid or mismatched start time =
  stale (deleted only if unchanged on re-read); foreign host or empty lock = refused; released
  only if our nonce is still inside; both scripts participate; timeout kills the process tree.
- Rejected/deferred, as recorded in `state.md`: cross-host takeover (cut), thread-scoped
  exclusion (documented), immutable snapshot (deferred), journaling (write order + orphan
  detection instead), test-result-to-tested-revision field (coordinator names it in `-Evidence`).

## CURRENT invariants claimed

- Read-only sandbox by default; `danger-full-access` refused; exec options before
  `fork|resume`; prompt on stdin; thread id from `thread.started` with the rollout fallback.
- `-DryRun` writes nothing: no directory, no lock, no ledger.
- Write order per consult: reply `.md`, `.reply.json`, `findings.json`, `sessions.json` (the
  commit point). A crash before the ledger write leaves an orphan that `-List` flags; the next
  consult numbers past every ledger `n`, every `source.consult` and every `F<NN>` id.
- Status is moved only by `codex-findings.ps1`; a reviewer's `prior_findings` verdict is stored
  as a `reviewer_checks[]` record with the tree it saw, never as a status change.
- `bridge_outcome` and `verdict` are separate; an invalid structured reply keeps the text,
  records `validation_error`, and yields no verdict.
- Every file written is UTF-8 without BOM, LF only; the scripts are ASCII and parse on
  Windows PowerShell 5.1; PowerShell 7 paths are written but not run (no `pwsh` here).

## Changed files

Base commit `6483ec4`, fingerprint `77898e4cee67` (before this consultation).

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult.ps1` | 709 -> 1038 lines: purposes, structured mode, fingerprint, lock, findings ingestion, rendering |
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | new, 1243 lines: shared helpers, `Get-RevisionInfo`, lock, validation, rendering, findings I/O |
| `plugins/codex-consult/scripts/codex-findings.ps1` | new, 271 lines: `-List`, `-Stats`, `-Id/-Status/-Note/-Evidence` |
| `plugins/codex-consult/schemas/consult-reply.schema.json` | new, schema v1 exactly as amended |
| `plugins/codex-consult/templates/brief-*.md`, `skills/consult-codex/SKILL.md` | R2/T4 templates; skill steps 0-3, role split, invariants 6-7 |
| `README.md`, `CHANGELOG.md`, `ROADMAP.md`, `TECH_DEBT.md`, `examples/` | 0.2.0 documentation and fabricated examples in the new shapes |

## Open findings

_(none open - the design review ran on the 0.1 bridge, which recorded no findings by id)_

## Evidence

- The implementer's harness run on PowerShell 5.1 (fake `codex` shim, no quota spent): every
  item of the verification plan passed - argv shape, presets, `-Raw`, refusals, structured
  parse (valid / non-JSON / fenced / wrong enum / ACCEPT-with-blocker), singleton arrays kept
  as arrays in the written JSON, not-checked and unknown-id handling, fingerprint (stable;
  changes on an untracked rename and on a tracked edit; unchanged for `.collab/` additions and
  ignored files; `no git` case), lock (live pid refused, dead pid and wrong start time taken
  over, foreign host refused, foreign nonce survives our release, empty lock refused),
  numbering past `100-`, timeout killing the process tree, lock released on `Stop-WithError`.
- `handoffs/02-codex-design-0.2.md` - the contracts this build claims to satisfy.
- `.collab/multi-model-2026-09-23/state.md` - a side fact: on a third-party provider route
  `--output-schema` is not enforced server-side (fenced JSON came back); the parser tolerates
  a fence, the validator does the rest.

## Questions

- **Q1.** Read `plugins/codex-consult/scripts/codex-consult-common.ps1` `Get-RevisionInfo` and
  the lock functions, and `codex-consult.ps1` from the run section down. Does the code hold the
  invariants claimed above? Name every place where it does not.
- **Q2.** The parse/validate/ingest path: is there an input (a reply shape, an id, a prior
  finding) that produces a verdict or a finding it should not, or loses one it should keep?
- **Q3.** The recovery story (write order + orphan detection + numbering past orphans): what
  concrete crash or concurrent sequence still corrupts `sessions.json` or `findings.json`?
- **Q4.** Verdict on 0.2.0: ACCEPT, HOLD or REJECT, with blockers, unproven scenarios and the
  observable first-run checklist - what must this very consultation have produced on disk
  (files, ledger fields, findings ids) before its exit code 0 is believed?

Answer by number. Keep it under 900 words.
