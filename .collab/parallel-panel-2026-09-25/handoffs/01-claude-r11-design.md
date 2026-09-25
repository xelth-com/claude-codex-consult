# R11 - parallel panel: design for review (0.4.x, wave 21)

Base: main 3bd8a83 (0.4.0 candidate). ROADMAP R11 is the goal; this note turns it into concrete
changes. Review the DESIGN against the current code - nothing below is implemented yet.

## Why the panel is sequential today (code facts)

- `codex-consult.ps1` panel section (~lines 830-1080): the parent selects members, then runs each
  as a CHILD of this script (`-PanelSpec <base64 json>`), synchronously, one after another. The
  parent takes no lock and writes nothing; it prints a summary. Between members it reads
  `.consult.pending.json` and stops starting members when a previous one left survivors (F15-3).
- Each child is a full single run (~lines 1457-1620, 2580-2680): `Enter-TaskLock` holds
  `<task>/.consult.lock` open (exclusive) for the WHOLE run; it reads the one recovery record
  `.consult.pending.json`; reads `sessions.json` and `findings.json` into memory at the START;
  `Get-NextNumbers` allocates n and NN; writes the record `reserved -> launching -> running ->
  (survivors)`; runs the reviewer (Start-Process, stdin/stdout/stderr redirected to files,
  WaitForExit with the timeout, Stop-ProcessTree on timeout); then writes reply.json, the
  handoff .md, `findings.json` (the in-memory store after `Add-ReplyFindings`) and
  `sessions.json` (the in-memory consults + its entry) - whole-file atomic replaces of stores
  that were read minutes earlier.
- agy members (wave 18): `Get-EngineTreeProblem` compares a snapshot of the WHOLE collab root
  (`Get-CollabSnapshot`, which already skips names starting with `.consult.`) before and after the
  run; any change fails the run (F12).

Run concurrently as they are, members would (a) refuse each other on the lock, (b) clobber one
recovery record, (c) race on numbering, (d) lose each other's ledger entries and findings (last
writer wins), (e) fail each other's agy tree check.

## Design

1. Parent owns the task. A `-Panel` run (not `-DryRun`) takes `.consult.lock` itself before any
   numbering and holds it until the last member has exited and the summary is printed. The lock's
   informational record gains `panel: <id>`. Other single runs and panels are refused as today.
2. Recovery first, in the parent. The parent reads EVERY recovery record of the task
   (`.consult.pending.json` and `.consult.pending-*.json`), refuses when any is active
   (`Test-PendingActive`), and consumes inactive ones exactly like a single run (numbering skips
   past them). Single runs and `codex-findings.ps1` also look at all `.consult.pending*.json`.
3. Numbers assigned up front, in roster order. Under the lock the parent calls `Get-NextNumbers`
   once and gives running member k (1-based, roster order) n = N0 + k - 1 and NN = NN0 + k - 1;
   both travel in the member spec. Members never allocate. A member that writes no ledger entry
   (refused by its own preflight, say) leaves its n unused; the summary names it.
4. One recovery record per member: `.consult.pending-<NN>.json` (same states and fields as today,
   plus `panel`). The parent writes every member's `reserved` record BEFORE launching any member,
   so a parent that dies early still leaves one record per planned member.
5. Members do not take the task lock. A member spec carries the panel id and the parent's pid and
   start time; the member refuses unless `.consult.lock`'s record names that pid + start time +
   panel id and that process is alive (`Read-LockContent`, `Test-PidAlive`). A member is thus
   never running without a live parent owning the task.
6. Commit = re-read + re-apply under a short write lock. Members still read the stores at start
   (for the prompt; `listed_ids` already pins the prompt to the panel's open-findings snapshot).
   At commit a member opens `<task>/.consult.write.lock` exclusively (retry with backoff, give up
   after 60 s -> the run is recorded as a bridge failure, reply files kept), RE-READS
   `findings.json` and `sessions.json`, re-applies its own delta - `Add-ReplyFindings` on the
   fresh store (ids F<NN>-k are deterministic given NN and the reply; the bridge asserts the new
   ids equal the ones rendered in the handoff) and its ledger entry inserted at its position by n
   (the consults array stays sorted by n whatever finishes first) - writes both atomically, and
   releases the write lock. Single runs take the same write lock at commit (one code path; it is
   uncontended for them). Write order stays reply.json -> handoff .md -> findings.json ->
   sessions.json.
7. agy tree check ignores siblings only. For a member of a panel with concurrency > 1, the collab
   comparison additionally ignores `<task>/sessions.json`, `<task>/findings.json` and
   `<task>/handoffs/<NN>-*` for every OTHER member's NN of this panel (from the spec). The repo
   tree fingerprint outside the collab dir stays strict; every other collab path (other tasks,
   state.md, briefs) stays monitored. Residual, documented: during a concurrent panel an agy
   reviewer that edits the task's own two stores is not caught by the tree check (the commit's
   re-read still refuses a store that no longer parses).
8. The parent launches and waits. Members start as `Start-Process` children with stdout/stderr
   redirected to per-member console files in a temp dir (`codex-consult-panel-<id>/<NN>.out|.err`,
   outside the repo), up to `-PanelConcurrency` at a time: 0 (default) = all at once, 1 = one after
   another (today's order under the new protocol), k = at most k. The parent polls about once a
   second and prints one line per finished member (lineage, outcome, wall seconds). Guard: a member
   still alive after its own timeout plus the retry allowances plus 120 s is stopped with
   `Stop-ProcessTree` and summarised as killed by the panel. After the last member it prints the
   members' console output in roster order, then today's summary plus the panel's wall clock.
9. Survivors and blocked members. A member that leaves survivors keeps its own record (state
   `survivors` / `launching`); the other members are unaffected (their processes are theirs), so
   the F15-3 rule "later members are not started" applies only with `-PanelConcurrency 1`. After
   the panel, a kept member record blocks the TASK for later runs until recovered, as today.
10. Exit 0 only when every member produced a usable reply (unchanged). Ledger `panel` record gains
    `concurrency` (the effective value). Dry run: lists the pre-assigned n/NN per member and says
    "at once" / "one after another" / "at most k at a time".

Invariants kept: members blind to each other inside a wave; the same open-findings snapshot;
nothing already written is lost when one member dies; one consultation per task outside a panel.

## Tests (Windows harness, fakes only)

A per-model delay and per-model reply for the fakes (e.g. `FAKE_CODEX_DELAY_MS` keyed by the
`-m` model, `FAKE_AGY_DELAY_MS`). Cases: three members of 4 s finish in well under 12 s (overlap);
the slowest member first in roster order -> ledger still sorted by n, handoffs NN in roster order;
findings of all members present with their F<NN>-k ids and every member's reviewer_check on a
prior finding present (no lost update); per-member records removed after success; one member
timing out keeps its record while the others commit; `-PanelConcurrency 1` runs strictly one after
another; a single run started during the panel is refused on the lock; an agy member does not fail
on its siblings' writes but still fails when the fake writes elsewhere in the collab root; the
parent killed mid-panel leaves per-member records and the next run refuses while a member process
lives, then recovers; a member launched with a spec whose parent is dead refuses; dry run output.

## Questions for the reviewers

Q1. Is "re-read + re-apply own delta under a short write lock" sound for `findings.json`
    (new findings, reviewer_checks on prior findings) and `sessions.json`, or is staging per member
    and one ordered commit by the parent after the last member safer? What breaks in each?
Q2. Is ignoring the task's two stores and the siblings' handoffs in an agy member's collab
    comparison an acceptable residual, or is there a cheap way to keep them monitored?
Q3. Parent death mid-panel: members keep running and commit; the lock is released with the parent.
    Is "a new run refuses while any member record is active" enough, or must members stop when
    their parent dies?
Q4. Default concurrency: all at once, or a cap per provider/engine (three members on one plan, two
    agy members sharing one sign-in)?
Q5. Anything in the code that assumes the consults array is in append order or that the last entry
    is the newest (Select-ParentThread, scoreboards, Read-AllTaskConsults, endpoint health)?
