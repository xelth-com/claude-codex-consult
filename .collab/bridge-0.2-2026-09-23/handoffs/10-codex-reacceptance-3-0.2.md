# Handoff 10 - Codex: reacceptance-3-0.2

Date: 2026-09-24 03:31 local. Author: Codex (model config default, effort high), Codex CLI 0.155.1.
Invocation: `codex-consult.ps1` (mode: resume, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -c model_reasoning_effort="high" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-cc8390e45d4847ffbbd24baca3e750b8.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json resume 01a0d01e-242c-7220-acb8-c5ce6ee72fc4 -` (prompt on stdin).
Parent thread: `01a0d01e-242c-7220-acb8-c5ce6ee72fc4`. Result thread: `01a0d01e-242c-7220-acb8-c5ce6ee72fc4` (source: events).
Brief: `.collab/bridge-0.2-2026-09-23/handoffs/09-claude-reacceptance-3-0.2.md` (sha256 a2379f1001ec). Reviewed: ca9decc + uncommitted, base ca9decc508b805ff70a537c6a26db95574ad4f71, tree sha256 9f3d93488b4a, 3 changed files.
Bridge outcome: usable reply. Wall time: 148.1 s. Tokens: in 4818802 (cached 4576512), out 28704, reasoning 6010.
Verdict: ACCEPT - The revised recovery decision closes both demonstrated F04-10 gaps, and no release-blocking defect remains in the reviewed change. Findings: 0 blocker, 0 major, 0 minor, 1 note (F10-1, tracked in `findings.json`). Structured reply: `handoffs/10-codex-reacceptance-3-0.2.reply.json`.
Raw event stream: `handoffs/10-codex-reacceptance-3-0.2.events.jsonl`.
Verbatim reply follows.

---

**Q1. F04-10 is fixed.** I re-read both functions and reproduced the previous failure cases using memory-only process mocks on PowerShell 5.1.

The observed results were:

- `running` record with a dead launcher and live descendant: **active**, recovery refused.
- `survivors` record with a dead recorded PID and live descendant: **active**.
- 32-minute-old `launching` record with a live Codex grandchild: **active**, with “task not verifiable” attribution.
- No remaining matching processes: **inactive**, recovery allowed.
- Process scan failure: **active**, recovery refused.

The dead-PID branch now checks children of the bridge and recorded processes before using the broader fallback. The age cutoff is gone. Both consultation and status-update scripts invoke this judgment under the ownership lock. The changed script parses successfully.

Two source samples matched `9f3d93488b4a…`, covering the three-file change over `ca9decc`.

**Q2. Indefinite conservative refusal remains possible and is acceptable as documented.** An unrelated long-lived Codex process started after the interrupted record can keep matching the fallback. Continually overlapping unrelated processes can likewise prevent automatic recovery. Recovery resumes automatically once no match remains; persistent scan failure also requires environmental repair or operator intervention.

The README now explains the attribution limitation, names the recovery file, and permits deliberate clearance after establishing that the matching process is unrelated. That is sufficient for this release. Do not reintroduce an age-based expiry: time does not establish termination. Manual clearance should happen with task writers stopped and after inspecting the reported process identities. This is an operational limitation, not a release blocker.

**Q3. ACCEPT the reviewed 0.2.0 implementation within its documented platform and recovery scope.** **Blockers: none.** The remaining note records the intentional availability tradeoff above.

**Unproven scenarios:** I did not execute a real timeout with both survivor-persistence failure and a surviving native descendant. The resulting recovery decisions were tested with mocks. This latest change was not executed on Linux or macOS during my review; earlier platform runs remain reported evidence. This consultation’s final persistence happens after the response returns.

**Observable first-run checklist:** verify the three `10-codex-reacceptance-3-0.2` artifacts and consultation `n=5`. The ledger must show resume of the existing thread, `structured=true`, empty validation error, and `verdict=ACCEPT`. F04-10 must receive a `fixed` reviewer check without an automatic coordinator-status change. This response contributes one informational note, no blockers or majors. Confirm matching source/brief hashes, completion-event usage, preserved history, and the final four review blocks. After commit, pending metadata should be removed while the permanent lock file remains with its handle released. The coordinator can then record F04-10 as verified using the review and regression evidence.

---

### Findings

- **F10-1** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:1881`, `README.md:346` - The intentional fallback can prevent automatic recovery indefinitely while unrelated matching Codex processes remain present; this is an accepted, documented availability tradeoff. Trigger: An interrupted pending record exists and an unrelated long-lived or continuously overlapping Codex-looking process started after that record matches the fallback. Evidence: read-code: Fallback matching does not establish task identity, has no age cutoff, and refuses while a match exists. The README documents the limitation and deliberate pending-record clearance.; ran-command: A matching process without a recorded parent relationship produced Active=true and a refusal explicitly labelled 'task not verifiable'. Verify: In an isolated recovery fixture, confirm an unrelated matching process causes a labelled refusal and that recovery succeeds after the match disappears. Remedy: Accept as the documented operational limitation; retain explicit manual clearance after process inspection with task writers stopped. No release-blocking code change is required.

### Prior findings

- F04-10 - fixed - Test-PendingActive now scans descendants after recorded PIDs disappear and always runs the broader fallback when needed, without the thirty-minute cutoff. Memory-only probes confirmed refusal for dead-launcher/live-descendant running and survivors records, refusal for a 32-minute-old launch with a live Codex grandchild, recovery when no matching processes remain, and refusal on scan failure. Both writers use this judgment under the lock. Real timeout plus failed survivor persistence was not executed in this read-only review.

## Verdict: ACCEPT

The revised recovery decision closes both demonstrated F04-10 gaps, and no release-blocking defect remains in the reviewed change.

### Blockers

_(none)_

### Unproven scenarios

- A real timeout combining survivor-record persistence failure with a surviving native Codex descendant; the resulting recovery states were exercised with memory-only mocks.
- Execution of this latest recovery change on Linux and macOS during this review; earlier platform results were read as reported evidence.
- Final response preservation, ledger commit, reviewer-check ingestion, pending cleanup, and ownership release for this consultation.

### First-run checklist (observable)

- [ ] Observe handoffs/10-codex-reacceptance-3-0.2.md, its .reply.json companion, and its .events.jsonl file; the raw companion must preserve the complete schema-version-1 response.
- [ ] Observe consultation n=5 with purpose acceptance, mode resume, parent/result thread 01a0d01e-242c-7220-acb8-c5ce6ee72fc4 matching thread.started, structured=true, empty validation_error, and verdict ACCEPT.
- [ ] Observe F04-10 reported fixed in ledger prior_findings and its reviewer_checks for consultation 5; its coordinator status must remain unchanged until explicitly updated.
- [ ] Observe one new informational note F10-1, with zero blockers, majors, and minors; no duplicate F04-10 finding should be created.
- [ ] Confirm matching before/after source and brief hashes. The reviewed source fingerprint was 9f3d93488b4a742364ae499e7c507178e04a0c33f426a4ea9f05866b2206e581 over base ca9decc508b805ff70a537c6a26db95574ad4f71.
- [ ] Compare usage with turn.completed, preserve all earlier ledger entries and finding histories, and confirm the final Markdown review blocks show ACCEPT and no blockers.
- [ ] After ledger commit, confirm .consult.pending.json is absent and the permanent .consult.lock remains with its handle released; List/Stats should show no new orphan checks.
