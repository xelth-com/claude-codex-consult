# Handoff 05 - Claude: re-acceptance of codex-consult 0.2.0 after the fix wave

Date: 2026-09-24. Base commit: `6483ec4` + uncommitted (the full 0.2.0 change set, now including the fix wave).

## Question

Your HOLD (handoff 04) named four blockers and seven majors, F04-1..F04-11. All eleven were reproduced
against the pre-fix scripts, fixed, and covered by harness assertions. Can 0.2.0 now be accepted, or
what still blocks it? Report each F04 id in `prior_findings`.

## Delta since the last review

Follows: `handoffs/04-codex-acceptance-0.2.md` (HOLD).

- **F04-1** stores are written to a temp file in the same directory and replaced atomically
  (`File.Replace` / `File.Move`); an existing store that is empty, unparseable, not an object, or a
  `findings.json` without `findings` is refused as corruption, naming the file, in every mode incl.
  `-DryRun`, `-List` and `-Raw`. 12 hard kills mid-write: 0 corrupt stores.
- **F04-2 / F04-10** lock ownership is a HELD HANDLE: `.consult.lock` opened exclusively (Windows
  `FileShare.Read` so a refused contender can read the record; Unix `FileShare.None` = advisory
  flock) and kept open for the whole run; no reread-then-delete, no pid/start-time takeover. The
  record `{pid, start_time, nonce, host, task, started, n, nn, reply, child_pid, child_start_time,
  survivors}` is written before codex starts; `child_pid` after launch; `survivors` when a timeout
  kill could not stop the tree (file then kept). A leftover names a live codex pid -> refused until it
  exits; a foreign-host leftover with pids -> refused; otherwise reopened. 8 simultaneous contenders
  over a stale leftover -> exactly one owner.
- **F04-3** the lock record is the consultation reservation; a leftover reservation is skipped past
  ("recovered reservation n=.., nn=.."); numbering scans ledger `n`, `source.consult`,
  `reviewer_checks[].consult`, existing `F<NN>` ids and the reservation, in `-Raw` too; `-List` flags
  orphan reviewer checks as well as orphan findings.
- **F04-4** semantic validation knows the open prior findings: ACCEPT with a prior blocker reported
  `still-open` -> verdict '' + `validation_error`; `not-checked`/`unknown-id`/omitted -> verdict kept,
  `WARNING: ACCEPT with N unchecked prior blocker(s)`, ledger `unchecked_prior_blockers[]`; retained
  prior blockers rendered `(prior, still-open|not-checked)` under `### Blockers`, no duplicate records.
- **F04-5** `.reply.json` is copied byte for byte BEFORE parsing (write order now reply.json, md,
  findings, sessions); `line` bounded to 1..2147483647; normalization and semantics in try/catch ->
  validation error, never a throw; any bridge bug in parse/ingest becomes
  `bridge could not process the reply: ...` with no ingestion.
- **F04-6** verdict validated against the resolved purpose (acceptance/diff-review: ACCEPT|HOLD|REJECT;
  else ADVISE); mismatch -> validation error, findings kept.
- **F04-7** manifest lines carry a mode column from `git diff --raw HEAD` (`100644`, `100644>100755`,
  `=` tracked-unchanged-mode, `u` untracked with a fingerprint_note). Earlier `tree_sha256` values are
  therefore not comparable with new ones (pre-release, documented).
- **F04-8** every path-keyed map is an ordinal `Dictionary[string,string]`; verified on a
  case-sensitive folder (`fsutil setCaseSensitiveInfo`).
- **F04-9** brief and artifacts hashed under the lock before the run and again after; ledger
  `brief_sha256_after`, `brief_changed_during_review`, `artifacts[].sha256_after`,
  `artifacts_changed_during_review`; header WARNING on either drift.
- **F04-11** a failed raw-reply copy is a bridge failure (`failed: could not preserve the raw reply
  (...); original kept at <temp>`), exit 1, temp kept, no findings, no verdict, ledger entry appended.

## CURRENT invariants claimed

- All invariants from handoff 03 still hold (read-only default, exec options before the subcommand,
  stdin prompt, thread id from `thread.started`, `-DryRun` writes nothing, statuses moved only by
  `codex-findings.ps1`, `bridge_outcome` separate from `verdict`, UTF-8/LF outputs, ASCII scripts).
- Single writer per task directory is guaranteed by the held handle for the lifetime of the process;
  a crashed run's leftover is safe and self-recovering; only a live codex process blocks.
- No store is ever truncated in place; a kill mid-write leaves at most one stray `.<name>.<guid>.tmp`.
- The raw reply is durable before anything fallible runs on it.

## Changed files

Base commit `6483ec4`. `plugins/codex-consult/scripts/codex-consult-common.ps1` 1243 -> 1703 lines;
`codex-consult.ps1` 1038 -> 1113; `codex-findings.ps1` 271 -> 291; schema unchanged.

## Open findings

F04-1..F04-11, all `implemented` (fix attempted and covered by the implementer's harness; a
fresh-context verifier re-ran the harness and re-derived F04-1/2/4/5/6/7/8/9/11 with its own
fixtures - its report is recorded in `state.md` round 3 before this brief was sent). None `verified`
yet: that status is reserved for after your re-review plus the coordinator's own evidence.

## Evidence

- Implementer's regression on PowerShell 5.1: 46/46 fix assertions, 12/12 lock cases, all earlier
  items green (`harness-fixes.ps1`, `harness-lock2.ps1`, `verify-v1.ps1` against the pre-fix copy).
- Deviations chosen by the implementer and accepted: Windows share mode `Read` not `None`;
  `child_start_time` added; refused contenders re-read for ~1 s and name a pid only if alive;
  `codex-findings -Status` puts a found reservation back; `unknown-id` counts as not-checked;
  retained prior blockers rendered for every verdict.
- Not verified, still: PowerShell 7 / Unix paths (`File.Move` overwrite, flock, delete-before-close,
  `pgrep` tree kill); a real timeout with unkillable survivors in the full script (lock tests cover
  the branch); cross-host shares (out of scope).

## Questions

- **Q1.** Re-read the changed regions (`Enter-TaskLock`/`Exit-TaskLock`, `Write-JsonFile`,
  `Get-RevisionInfo`, `Test-StructuredReply`, and `codex-consult.ps1` from the run section down).
  For each F04 id: fixed, still-open, or not-checked - with the concrete gap if still-open.
- **Q2.** Does the held-handle lock introduce a new failure mode the old scheme did not have
  (e.g. a reader holding `FileShare.Read` on Windows, antivirus scanners, `-List` during a run)?
- **Q3.** Verdict on 0.2.0 now: ACCEPT, HOLD or REJECT, with blockers, unproven scenarios and the
  observable first-run checklist for this consultation (it runs as `resume` of your HOLD thread,
  with the eleven ids fed back as prior findings).

Answer by number. Keep it under 800 words.
