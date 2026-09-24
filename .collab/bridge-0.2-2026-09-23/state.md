# Task: bridge-0.2-2026-09-23 - implement ROADMAP R1-R6 and TECH_DEBT T1-T4 as codex-consult 0.2.0

Base commit: `6483ec4`. Coordinator: Claude Code. Reviewer: Codex (thread `01a0cff8-4583-7110-8730-5fda5333d388`, new, this repository only).

## Round 1 - framing (design review before implementation)

- `handoffs/01-claude-design-0.2.md` (the design) -> `handoffs/02-codex-design-0.2.md`: **HOLD the design as written**;
  scope coherent, but revision binding, locking and crash recovery need explicit contracts first.

### Adopted (all go into 0.2.0)

- Q1 schema: `evidence` becomes an array of `{kind, reference, observation}` (what was already done), `verification`
  stays prospective; `locations[]` of `{path, line|null}` instead of a `"path:line"` string; `schema_version`;
  local validation of shape and semantics (ACCEPT with a blocker finding = invalid verdict); an invalid reply keeps
  the raw text, records the validation error, gives NO verdict and ingests NO findings; the raw response is stored
  byte for byte; the four R4 blocks are the LAST sections of the reply file.
- Q2 identity: reviewer verdicts on prior findings are evidence only; `supersedes` relationship for splits/merges/
  corrected claims; explicit reopen; `verified` requires `-Evidence`, not just a note; the trigger and the
  verification criterion are fed back with the claim; ids listed but not reported -> `not-checked`; unknown ids
  create nothing; ids allocated under the lock; the `NN-` filename matcher fixed for handoff >= 100.
- Q3 revision binding: a deterministic manifest (status, blob hash, PATH per entry of `git status -uall`) hashed
  as `tree_sha256`, so a rename is distinguishable; the collab directory excluded; the brief hashed separately;
  omissions (submodules, ignored files, no git) recorded in `fingerprint_note`; fingerprint taken before AND after
  the review, a difference is flagged.
- Q4 defaults: structured on, `-Raw` opt-out; core-contract narrowed to the interfaces and state machines named in
  the brief; the word cap applies to prose only; R5 rework measure = coordinator-recorded finding statuses joined
  to the consultation that produced them (`codex-findings.ps1 -Stats`); absent usage fields stay null.
- Q5 lock: atomic create (`FileMode.CreateNew`), owner nonce + process start time (PID reuse), release only our
  own lock, acquire before reading the ledger or allocating names, both scripts participate; timeout kills the
  process TREE; no automatic cross-host takeover.
- Q6: the acceptance checklist becomes the test plan for this release (failure paths never produce a verdict;
  concurrency; singleton arrays; handoff 100+; dry-run writes nothing; existing ledgers still load).

### Rejected or deferred (with reason)

- Cross-host lock takeover: CUT from 0.2.0 (no lease/fencing); a foreign-host lock is refused and must be removed
  by a human who knows the owner is dead.
- Thread-scoped exclusion (one thread resumed from two task directories): documented as a constraint, not enforced.
- Immutable snapshot of the reviewed tree: deferred; the before/after fingerprint flags a changed tree instead.
- A full commit/recovery journal: partial - fixed write order (reply, reply.json, findings.json, sessions.json as
  the commit point) plus orphan detection in `-List`; a crash leaves nothing overwritten.
- Binding quoted test results to their own tested revision: the status-change record carries the fingerprint of
  the moment it is made; the coordinator names the tested revision in `-Evidence`. No separate field yet.

## Round 2 - acceptance (first live run of the structured path)

- `handoffs/03-claude-acceptance-0.2.md` -> `handoffs/04-codex-acceptance-0.2.md` (+ `.reply.json`, `.events.jsonl`),
  fork of the design thread -> `01a0d01e-242c-7220-acb8-c5ce6ee72fc4`, 390.9 s, 1.21M input tokens (1.07M cached),
  11.7k output. **Verdict: HOLD** - 4 blockers, 7 majors, F04-1..F04-11 in `findings.json`.
- The bridge itself behaved as specified on this run, checked against the reviewer's own first-run checklist:
  ledger entry n=2 with `structured=true`, empty `validation_error`, `verdict=HOLD`, counts 4/7/0/0, eleven ids in
  order; the 0.1-shaped entry n=1 untouched; `.reply.json` is bare JSON, schema v1 (on the OpenAI route the schema
  IS enforced server-side); the Markdown ends with Findings, Prior findings, Verdict, Blockers, Unproven, First-run
  checklist; `tree_changed_during_review=true` was correctly raised (the docs worker edited README during the
  review); `brief_sha256` recorded; usage copied from `turn.completed`; lock removed; `-List` shows 11 open, 0
  orphans; `-Stats` shows both consultations.
- Reviewer's findings, all adopted as a fix wave before release (design choices are the coordinator's):
  F04-1 atomic store replacement, empty/unparseable store = corruption; F04-2 + F04-10 held-handle lock ownership
  (FileShare.None for the whole critical section, no reread-then-delete, `child_pid`/`survivors` recorded so a
  surviving codex process blocks the next run); F04-3 the lock content is the consultation reservation (n, nn,
  reply) and numbering scans `reviewer_checks[].consult` and findings.json in `-Raw` too; F04-4 ACCEPT with a
  still-open prior blocker is a validation error, unchecked prior blockers a warning, retained prior blockers
  rendered; F04-5 raw reply copied before parsing, `line` bounded to int32, normalization failures become
  validation errors; F04-6 verdict validated against the purpose; F04-7 mode column in the manifest (tracked
  entries via `git diff --raw`, untracked recorded as unknown); F04-8 ordinal path dictionary; F04-9 brief and
  artifacts hashed under the lock and again after the run, drift flagged; F04-11 a failed raw-reply copy is a
  bridge failure that keeps the original.
- Not adopted from the unproven list: PowerShell 7 / non-Windows execution (no `pwsh` on this machine - stays a
  documented limitation); fault-injection of a real crash between writes (simulated in the harness instead).

## Fix wave (2026-09-24, between rounds 2 and 3)

- Implementer (Opus worker, same context as the build): every F04 id reproduced against a kept copy of the pre-fix
  scripts (`verify-v1.ps1`), then fixed as decided above; regression on PowerShell 5.1: 46/46 fix assertions,
  12 hard kills mid-write with 0 corrupt stores, 8 simultaneous lock contenders with exactly one owner, all
  earlier items green. Deviations accepted: Windows share mode `Read` (a refused contender can read the record),
  `child_start_time` in the lock record, refused contenders name a pid only if alive, `-Status` puts a found
  reservation back, `unknown-id` counts as not-checked, retained prior blockers rendered for every verdict.
- Fresh-context verifier (Sonnet worker, R6 role: mechanics): re-ran both harnesses itself (`harness-fixes.ps1`
  46 PASS / 0 FAIL; `harness-lock2.ps1` 9 PASS / 0 FAIL) and re-derived F04-1/2/4/5/6/7/8/9/11 with its own
  fixtures (whitespace-only store refused byte-for-byte unchanged; in-flight lock refuses a second consult and a
  `-Status`, `-List` works, lock gone afterwards; ACCEPT + still-open prior blocker -> verdict '' and the exact
  validation_error, rendered `(prior, still-open)`; not-checked -> WARNING + `unchecked_prior_blockers`; line 1e30
  -> validation error with `.reply.json` SHA-256-identical; purpose/verdict mismatches; chmod +x changes the
  fingerprint; `a.txt`/`A.txt` distinct on a case-sensitive folder; brief edited mid-run flagged; blocked
  `.reply.json` -> exit 1 with the original kept; dry runs write nothing; the 0.1 example ledger still resolves).
  Reviewer's-eye pass: nothing beyond the eleven; one nit - an explicit `-CodexExe`/`CODEX_CONSULT_EXE` that does
  not resolve fell through silently to PATH. Fixed by the coordinator (refused with the source named), re-tested.
- All eleven findings moved to `implemented` (2026-09-24); `verified` waits for round 3 plus the coordinator's own
  evidence, per the skill's rule that a reviewer's "fixed" is evidence, not a status change.

## Round 3 - re-acceptance (first live run of the prior-findings path)

- `handoffs/05-claude-reacceptance-0.2.md` -> `handoffs/06-codex-reacceptance-0.2.md`, `-Mode resume` of the HOLD
  thread `01a0d01e-...`, 392.6 s. **Verdict: HOLD** - eight of eleven fixed, three still open, three new findings.
- Bridge behaviour on this run, checked against the reviewer's checklist: ledger n=3, resume, same thread as
  parent, structured, no validation error; all eleven F04 ids in `prior_findings` (8 fixed, F04-3/9/10
  still-open) and as `reviewer_checks` on consult 3; F06-1..F06-3 ingested with `supersedes` F04-3 / F04-9
  recorded on both sides; coordinator statuses untouched by the run; the retained still-open prior blocker F04-3
  rendered under Blockers; source and brief fingerprints identical before and after (stable tree this time);
  lock released. The live lock record during the run showed the reservation (n=3, nn=06, reply) and the codex
  child pid.
- Statuses moved by the coordinator after the run: F04-1/2/4/5/6/7/8/11 -> `verified` (evidence: the reviewer's
  re-review, the fresh-context verifier's own fixtures, the implementer's harness); F04-3 -> `superseded` by
  F06-1, F04-9 -> `superseded` by F06-3 (the numbering and before/after-hashing parts are fixed; what remains is
  the new claim); F04-10 stays `implemented` (still-open: the child starts before it is registered, and a failed
  registration write is swallowed).
- New findings, all adopted for a third, narrow wave: **F06-1** (blocker) lock acquisition overwrote the previous
  recovery record before consuming it, so a second crash could erase a reservation or a live-child quarantine;
  **F06-2** (major) on Unix, unlinking the lock path breaks descriptor-based exclusion; **F06-3** (major) artifact
  re-hashing looked the path up case-insensitively. Design for the wave: ownership (`.consult.lock`, permanent
  path, held handle, release = close, never unlinked, informational content only) is separated from recovery
  metadata (`.consult.pending.json`, atomic writes, states reserved -> launching -> running -> survivors, read and
  consumed before it is replaced, `launching` treated conservatively, registration failure kills the child and
  fails the run); artifacts and the brief re-hashed by their resolved full paths.

## Wave 3 (2026-09-24, between rounds 3 and 4)

- Implementer: F06-1/F06-2/F06-3/F04-10 reproduced on a kept copy of the reviewed scripts (`verify-v2.ps1`), then
  fixed with the ownership/recovery split: `.consult.lock` permanent (held handle, release = close, never
  unlinked, informational content), `.consult.pending.json` atomic recovery record (reserved -> launching ->
  running -> survivors; read and judged before it is replaced; corrupt = refused; `launching` judged by a codex
  process scan; registration failure kills the child, fails the run, leaves `launching`); artifacts and the brief
  re-hashed by resolved full path. `harness-pending.ps1` 26/26, `harness-fixes.ps1` 45/45, `harness-lock2.ps1`
  10/10, 22 e2e runs clean. Deviations accepted: `launcher` stored in the record; the launching scan matches
  codex/codex.exe or the launcher path / `@openai/codex` in the command line (never a bare "codex" substring);
  the record is kept only after a failed registration or with survivors.
- Fresh-context verifier (Sonnet, own fixtures under a scratchpad collab dir): 26/26, 45/45, 10/10 re-run;
  running record with a live child refuses a consult and a `-Status` while `-List` prints the `pending:` line;
  lock creation time identical before and after a run; reserved n=9/nn=20 recovered as n=10/`21-`; live / reused
  / dead child pid judged correctly; `launching` recovered, refused with the shim running, recovered again;
  corrupt record refused by both scripts and byte-identical afterwards; case-distinct `A.bin` drift flagged
  alone; dry runs write nothing; the 0.1 example ledger still resolves. Two new defects (fixed in wave 3b):
  survivors recorded without start times (a reused pid would block the task until the record is deleted), and
  the `launching` scan's launcher-path rule could attribute another task's codex process to this task
  (fix: match the dead bridge pid as ParentProcessId on Windows first; the command-line rule stays the
  non-Windows fallback and says so).
- Statuses: F06-1, F06-2, F06-3, F04-10 -> `implemented`. `.consult.lock` and `.consult.pending.json` are
  git-ignored (coordinator); an unresolvable explicit `-CodexExe`/`CODEX_CONSULT_EXE` is refused (coordinator).

## Wave 3b (2026-09-24, the verifier's two defects)

- The implementer worker hit its session limit mid-wave; the coordinator finished it. Survivors are recorded
  as `{pid, start_time, name}` (`New-SurvivorEntries`) and judged by `Test-RecordedProcess`: alive only with a
  matching start time and name; a bare-pid entry (older record) or an unreadable start time is judged by the
  "looks like codex" rule, never by pid alone. The `launching` scan on Windows attributes a process to this
  run only as a direct child of the record's dead bridge pid (children created after that pid was reused are
  excluded); if that finds nothing and the record is younger than 30 minutes it falls back to the name /
  launcher / `@openai/codex` command-line rule with matches labelled "task not verifiable" (the npm shim is
  the direct child; if it died but its own child lives, ppid alone would miss it); an older record with no
  direct child is dead. The refusal message keeps the `(pid N)` form; the check text carries the reason.
- Own harness `harness-3b.ps1` (8 cases): reused pid not active; correct pid + start time active; bare pid on a
  plain sleeper not active; wrong recorded name not active; dead-bridge grandchild found by ppid; unrelated
  dead pid none; launcher-path process with a different ppid not attributed; no-bridge-pid fallback labelled.
  Existing harnesses re-run ALONE after updating their survivor seeds to the entry shape: `harness-pending.ps1`
  0 failures, `harness-fixes.ps1` 0 failures, `harness-lock2.ps1` all PASS. Running the harnesses
  concurrently produces false refusals in `launching` cases - the fake codex processes of one harness match
  the other's command-line fallback - which is the documented cross-task limitation of that fallback, not a
  defect of the sequential runs.
- No status change: F06-1/2/3 and F04-10 stay `implemented` until round 4.

## Platform verification (2026-09-24, after commit 9e2a970)

- **PowerShell 7.6 on Windows** (installed via winget): all four harnesses green under pwsh (3b 9/9, fixes 45/45,
  pending 26/26, lock2 10/10) after one PS7-only fix - pwsh's `ConvertFrom-Json` turns ISO-8601 strings into
  `[datetime]`, so a recorded start time no longer compared equal to the live one and a live lock holder was
  reported as "a live process" instead of by pid; four reads in the common library now normalise through the
  JSON-text helper. 5.1 re-run: no regression.
- **Linux (WSL Ubuntu 24.04, pwsh 7.6, native ext4, bash fake codex)**: dry run, full structured run, flock
  contention (second consult and `-Status` refused, `-List` works, lock inode unchanged), timeout with the tree
  killed and no survivors, `launching`/`survivors` recovery through the `ps` scan, `chmod +x` changing the
  fingerprint, `$HOME/.codex`, atomic findings replacement - all pass after three Linux-only fixes: start-time
  comparison with a one-second tolerance off Windows (a live codex child was being declared a reused pid and a
  second consultation started beside it), the holder's own lock file read via `cat` off Windows (the advisory
  lock blocked a shared FileStream read), and the timeout kill taking the root before the children. Left as
  known: atomic replace resets Unix permission bits; invariant date format in messages. macOS not exercised.
- Both fix sets landed in `codex-consult-common.ps1` concurrently in different functions; the merged file
  parses on 5.1 and 7, and the Windows harnesses were re-run on 5.1 afterwards (see the commit that records
  this section).

## Round 4 - second re-acceptance after waves 3, 3b and the platform fixes (2026-09-24 03:20)

- Postponed at ~02:00 (reviewer unavailable), run at 03:20: `handoffs/07-claude-reacceptance-2-0.2.md` ->
  `handoffs/08-codex-reacceptance-2-0.2.md`, `resume` of the HOLD thread, 207.7 s, source inspected at commit
  `ca9decc`. **Verdict: HOLD, narrowed to F04-10.** F06-1, F06-2, F06-3 reported fixed; no new findings.
- Bridge behaviour, checked against the reviewer's checklist: ledger n=4, resume, structured, no validation
  error, four prior dispositions as `reviewer_checks` on consult 4, `finding_ids` empty, source and brief
  fingerprints identical before and after, pending record removed after the ledger commit, permanent lock
  file still present with its handle released. The live `.consult.pending.json` during the run showed
  `state: running`, the reservation n=4/nn=08, the registered codex child and the launcher path.
- Statuses: F06-1, F06-2, F06-3 -> `verified` (reviewer + verifier fixtures + harnesses on 5.1, 7 and Linux).
  F04-10 stays `implemented`.
- F04-10, what remained: a `running` record whose only recorded pid is the dead launcher (survivor
  persistence failed, or the bridge crashed and the shim died) was judged inactive because the recorded
  pid was gone, never checking descendants; and the `launching` command-line fallback stopped after thirty
  minutes although a grandchild may live. The reviewer's rule: neither a dead root nor elapsed time proves
  the tree ended; conservative false refusals are acceptable with a documented way to clear them.

## Wave 4 (2026-09-24, F04-10 - coordinator)

- `Test-PendingActive`: when every recorded pid is gone (running/survivors) - and for `launching` - the run
  scans for children of the dead bridge AND of every dead recorded pid (the launcher shim, the survivors;
  Windows keeps an orphan's parent id), then for any codex-looking process started at or after the record
  (labelled "task not verifiable"); the thirty-minute cut-off is removed. A refusal names the process and
  the record; deleting `.consult.pending.json` is the deliberate way to clear an unrelated match.
- Harness `harness-3b.ps1` + 3 cases: a `running` record naming a dead launcher whose child lives -> active
  by the descendant rule; a dead child with no descendants and nothing codex-like -> inactive; a 32-minute-old
  `launching` record with a live launcher-path process -> active, task not verifiable. Full harness set re-run
  on 5.1 (results in the commit that records this section). README lock section and CHANGELOG updated.

## Round 5 - third re-acceptance after wave 4 (2026-09-24 03:35) - ACCEPT

- `handoffs/09-claude-reacceptance-3-0.2.md` -> `handoffs/10-codex-reacceptance-3-0.2.md`, `resume` of the same
  thread, 148.1 s, source fingerprint `9f3d93488b4a...` over `ca9decc`. **Verdict: ACCEPT** "within its
  documented platform and recovery scope"; blockers none; F04-10 reported fixed (mocks: dead-launcher/live-
  descendant running and survivors records, 32-minute launching with a live grandchild, no match ->
  recovery, scan failure -> refusal); one informational note F10-1: the command-line fallback can refuse
  indefinitely while an unrelated codex-looking process started after the record exists - accepted as the
  documented availability trade-off, with the explicit instruction never to reintroduce an age-based expiry.
- Bridge behaviour on this run, per the reviewer's checklist: ledger n=5, resume, structured, no validation
  error, `verdict=ACCEPT`, findings 0/0/0/1 with `F10-1`, F04-10 `fixed` as a reviewer check on consult 5 with
  the coordinator status untouched by the run, source and brief fingerprints identical before and after,
  usage copied, pending record removed after the ledger commit, permanent lock present with the handle
  released, no orphans.
- Statuses (coordinator, after the run): F04-10 -> `verified` (evidence: the reviewer's round-5 disposition,
  harness-3b cases c1-c3, the full harness set green on 5.1 after the change); F10-1 -> `wontfix` (accepted
  limitation, documented in README "The lock" and CHANGELOG).
- Final ledger: 15 findings - 12 verified, 2 superseded, 1 wontfix, 0 open. `-Stats` (the R5 measurement):
  five consultations, 80.7 / 390.9 / 392.6 / 207.7 / 148.1 s, verdicts - / HOLD / HOLD / HOLD / ACCEPT.

## Closed

0.2.0 accepted on 2026-09-24 after one design review, one acceptance and three re-acceptances, four fix waves
(the last by the coordinator), one fresh-context verification per wave, and first runs on PowerShell 7 and
Linux. Unproven and left documented: a real timeout combining a failed survivor write with a surviving native
descendant (mocked only); macOS; the atomic replace resetting Unix permission bits; the fallback's
indefinite conservative refusal (F10-1). Tag `v0.2.0` on the commit that records this section.
