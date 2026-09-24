# Tech debt

Known weaknesses of the bridge and of the collaboration protocol around it, as observed in
use. Agreed on 2026-09-23 between the Claude Code coordinator and the Codex reviewer after a
seven-wave task with three consultations. Ordered by the damage they did.

- **T1 — Findings are not tracked by identity.** A finding lives only as prose in a reply and
  as a line in the coordinator's fix list; "DONE" in a worker's report means "implementation
  attempted", and nothing records whether the invariant was then VERIFIED. On the motivating
  task, restoration and backup invariants were reported done while still broken, which the
  next review caught. Fix: give every finding a stable id and track it through
  proposed → implemented → verified, with the trigger, the source evidence and the regression
  result, in the ledger (`sessions.json` or a `findings.json` beside it).
  **Status (0.2.0): shipped** — `findings.json`, ids `F<NN>-<k>`, `codex-findings.ps1` with a
  full status lifecycle (`proposed → implemented → verified`, plus `rejected`/`wontfix`/
  `superseded` and an explicit reopen) and an audit-trail `history[]` per finding. `verified`
  requires `-Evidence`, not just a note, per the design-review amendment.
- **T2 — Reviews are not bound to what was reviewed.** The ledger records "commit + uncommitted",
  which cannot distinguish two successive reviewed trees. Fix: record the base commit, a hash
  of the diff or of the reviewed files, and the hash of any built artifact, for every review
  and every test result quoted in a brief.
  **Status (0.2.0): shipped**, revised from a diff hash to a manifest hash (`tree_sha256`) after
  the design review: a diff hash cannot represent a rename, a tree manifest (status + blob hash
  + path per `git status -uall`) can, and it is taken before and after the run to catch a tree
  that changed mid-review. `-Artifact` binds built artifacts. Deferred: binding a quoted test
  result to its own tested revision has no dedicated field yet — the coordinator names the
  tested revision in `codex-findings.ps1 -Evidence`, and the status-change record still carries
  the fingerprint of the moment it was made. An immutable snapshot of the reviewed tree was
  also deferred; the before/after fingerprint flags drift instead of preventing it.
- **T3 — Execution outcome and review verdict are conflated; state can drift.** "usable reply"
  in the ledger means the bridge worked, not that the work was approved; a delivered HOLD looks
  like any other entry. Coordinator-written summaries also drifted from the reply they
  paraphrased (two cases in one day: a changed backup-replacement claim, a stale "unproven"
  entry). Fix: separate `bridge_outcome` from `verdict` in the ledger entry; link findings
  verbatim rather than paraphrasing; reconcile the task state before every handoff; record
  task/thread parentage; add an active-session guard so two coordinators cannot resume the
  same thread concurrently.
  **Status (0.2.0): shipped** — `bridge_outcome` and `verdict` are separate ledger fields;
  the skill's step 0 requires reconciling `codex-findings.ps1 -List` before a review brief;
  `.consult.lock` (atomic create, pid + start-time + nonce, process-tree timeout kill) blocks
  concurrent consultations on one task from the same host. Deferred: cross-host lock takeover
  is cut entirely (a foreign-host lock is always refused, removed by hand once its owner is
  confirmed dead), and thread-scoped exclusion (one thread, one task directory) is documented
  as a constraint rather than enforced by the script.
- **T4 — Briefs repeat what the resumed thread already holds.** A `resume` carries the
  history, yet briefs re-told it at 500–1000 words. Fix: with R2's template, a checkpoint
  brief is the delta plus pointers. History is not an authoritative current-state record,
  though, so the delta must state the CURRENT invariants, not only what changed.
  **Status (0.2.0): shipped** — `templates/brief-review.md` has a dedicated "Delta since the
  last review" section and a separate "CURRENT invariants claimed" section, so a checkpoint
  brief cannot collapse into a changelog.
- **T5 — F12-1 residual: a rotated credential inside the 24 h auth window still needs
  `-SkipPreflight` once.** An `auth` failure on an endpoint refuses every run against it
  for 24 hours (endpoint health, see the README), even once the credential has been
  fixed — the bridge cannot distinguish "still broken" from "fixed since" without
  actually trying, so it fails closed either way. The 0.3.0 wave-10 reviewer roster does
  not add a way to record "this credential was just rotated, trust it again"; the
  operator still has to pass `-SkipPreflight` once to clear the flagged window, exactly
  as before. What DID ship in wave 10 alongside this: `"auth": "none"` in a roster entry,
  for an endpoint that genuinely needs no credential at all, so that case at least never
  needs `-SkipPreflight` in the first place. Fix (not yet designed): a way to mark a
  specific past auth failure as resolved (by whom, when) without disabling the 24 h
  window for every OTHER failure on that endpoint.
- **T6 — F15-1 residual: a legacy `retry_after`-less ledger entry can still be off by a
  zone difference.** Wave 11 fixed the forward case: a reset time is now parsed with the
  recording machine's zone rules at WRITE time and stored as a true instant
  (`provider_failure.retry_after`, offset included). An entry written before that fix has
  no `retry_after` at all, so a read now reparses its message using the failure's own
  `when` offset as the reference zone (labelled `RetryAfterBasis "message (reference
  offset)"`) — correct only if read on a machine in the same zone that recorded it; read
  elsewhere, it can be off by the zone difference, since no zone was ever stored for such
  an entry. Not fixable after the fact without guessing; the residual only shrinks as old
  entries age out. Fix (not planned): none — flagged so a future investigation of a
  seemingly-wrong `retry_after` on an old entry checks this before assuming a bug.
