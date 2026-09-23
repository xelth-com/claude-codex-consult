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
- **T2 — Reviews are not bound to what was reviewed.** The ledger records "commit + uncommitted",
  which cannot distinguish two successive reviewed trees. Fix: record the base commit, a hash
  of the diff or of the reviewed files, and the hash of any built artifact, for every review
  and every test result quoted in a brief.
- **T3 — Execution outcome and review verdict are conflated; state can drift.** "usable reply"
  in the ledger means the bridge worked, not that the work was approved; a delivered HOLD looks
  like any other entry. Coordinator-written summaries also drifted from the reply they
  paraphrased (two cases in one day: a changed backup-replacement claim, a stale "unproven"
  entry). Fix: separate `bridge_outcome` from `verdict` in the ledger entry; link findings
  verbatim rather than paraphrasing; reconcile the task state before every handoff; record
  task/thread parentage; add an active-session guard so two coordinators cannot resume the
  same thread concurrently.
- **T4 — Briefs repeat what the resumed thread already holds.** A `resume` carries the
  history, yet briefs re-told it at 500–1000 words. Fix: with R2's template, a checkpoint
  brief is the delta plus pointers. History is not an authoritative current-state record,
  though, so the delta must state the CURRENT invariants, not only what changed.
