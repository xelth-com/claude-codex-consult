# Handoff 08 - Codex: reacceptance-2-0.2

Date: 2026-09-24 03:19 local. Author: Codex (model config default, effort high), Codex CLI 0.155.1.
Invocation: `codex-consult.ps1` (mode: resume, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -c model_reasoning_effort="high" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-20360b46d1d043db8c8e279280ab6c1d.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json resume 01a0d01e-242c-7220-acb8-c5ce6ee72fc4 -` (prompt on stdin).
Parent thread: `01a0d01e-242c-7220-acb8-c5ce6ee72fc4`. Result thread: `01a0d01e-242c-7220-acb8-c5ce6ee72fc4` (source: events).
Brief: `.collab/bridge-0.2-2026-09-23/handoffs/07-claude-reacceptance-2-0.2.md` (sha256 0371f7c6ea5e). Reviewed: ca9decc, base ca9decc508b805ff70a537c6a26db95574ad4f71, tree sha256 7820e2f92d5a, 0 changed files.
Bridge outcome: usable reply. Wall time: 207.7 s. Tokens: in 3769702 (cached 3544576), out 24792, reasoning 5101.
Verdict: HOLD - F06-1, F06-2, and F06-3 are fixed, but F04-10 still allows recovery to admit another consultation while a previous Codex descendant remains alive. Findings: none. Structured reply: `handoffs/08-codex-reacceptance-2-0.2.reply.json`.
Raw event stream: `handoffs/08-codex-reacceptance-2-0.2.events.jsonl`.
Verbatim reply follows.

---

**Q1. Three findings are fixed; F04-10 remains open.** I reviewed the clean source at commit `ca9decc508b805ff70a537c6a26db95574ad4f71`.

- **F06-1 — fixed.** Recovery data now lives in an atomically replaced pending file. Both writers inspect it under the ownership lock before proceeding. Acquiring or releasing ownership no longer destroys reservations or child metadata; status updates leave the pending record unchanged.
- **F06-2 — fixed.** The ownership file remains permanently at its pathname. Release only disposes the stream, removing the unlink/recreate race.
- **F06-3 — fixed.** Each artifact carries its resolved full path into after-hashing. A memory-only probe confirmed that case-distinct artifact entries retain separate targets.
- **F04-10 — still open.** Persisting `launching` before spawning and handling registration failure explicitly are improvements, but recovery still mistakes a dead launcher for a dead process tree.

Two concrete paths remain:

1. **Survivor persistence fails.** `codex-consult.ps1:883–885` leaves the previous `running` record naming only the launcher. If termination killed that launcher but a native Codex descendant survived, `Test-PendingActive` checks the recorded PID and returns inactive at `codex-consult-common.ps1:1846`. It never checks descendants. The next consultation can overwrite the pending record and proceed. A bridge crash followed by launcher death can produce the same state.
2. **An unresolved launch exceeds thirty minutes.** The Windows fallback scan at `codex-consult-common.ps1:1860` is disabled once the record is old enough. If the direct shim died but its Codex child survives, age alone changes the recovery decision to inactive.

Memory-only process mocks reproduced both decisions. With a live Codex process beneath a dead shim, an otherwise equivalent 29-minute-old launch was active while a 32-minute-old launch was inactive. A `running` record naming the dead shim was also inactive. These probes test recovery decisions, not actual process termination.

**Q2. The two-file design is appropriate; the remaining gap is its liveness decision.** A held lock without pending metadata is legitimate before launch preparation. Pending metadata with a free lock is the expected interrupted-run state. Atomic replacement and checking before replacement address the previous destructive transition.

Before release, stop treating root exit or elapsed time as proof that the process tree ended. Preserve an unresolved quarantine when descendant identity or termination cannot be established, including failed survivor persistence. Alternatively, use lifecycle containment that reliably owns the entire tree. An uncertain record must not authorize another run merely because its known launcher disappeared.

Conservative false refusals from the cross-task fallback can be documented with deliberate recovery instructions. False negatives permitting overlapping consultations must be fixed. The reported PowerShell 7/Linux runs improve platform evidence, but do not establish these two failure paths.

**Q3. HOLD.** **Release blocker: F04-10.** I have not duplicated it as a new finding; `findings` is empty.

**Unproven scenarios:** real survivor-write failure with a surviving descendant; recovery after the thirty-minute boundary; actual process-tree containment; and this consultation’s final persistence. I did not rerun writing harnesses or terminate processes. The three scripts parsed successfully on PowerShell 5.1; platform harness outcomes are reported evidence from the brief and state record.

**Observable first-run checklist:** this consultation should produce the three `08-codex-reacceptance-2-0.2` artifacts and ledger consultation `n=4`, recording resume of the existing thread, structured HOLD, and no validation error. All four prior dispositions must become reviewer checks without changing coordinator statuses or creating duplicate findings. Confirm matching source/brief fingerprints, correct artifact bindings, completion-event usage, preserved history, and the final four review blocks. After normal delivery, the permanent lock file must remain with its handle released, and pending metadata should be removed after ledger commit. Exit code 0 demonstrates successful delivery of HOLD, not release acceptance.

---

### Findings

_(none)_

### Prior findings

- F04-10 - still-open - Launch-before-registration is now covered by a durable launching state, and registration errors trigger termination. However, codex-consult.ps1:883-885 can fail to persist surviving descendants and leave a running record naming a dead launcher; codex-consult-common.ps1:1831-1846 then returns inactive without descendant recovery. The Windows launching fallback at :1860 also stops after thirty minutes despite a potentially surviving grandchild. Memory-only mocked process snapshots reproduced inactive recovery for both a dead-root running record and a 32-minute-old launch with a live Codex descendant; the equivalent 29-minute launch was active. Preserve unresolved quarantine or prove whole-tree termination. Verify with an isolated survivor-write-failure fixture and recovery beyond thirty minutes; both consultation and status update must refuse while the descendant lives.
- F06-1 - fixed - Ownership metadata is informational only. Read-PendingFile and Test-PendingActive run under the held lock before reservation replacement; Write-PendingFile uses atomic JSON replacement; numbering consumes the previous reservation first. Status updates inspect but do not modify pending metadata. The original destructive acquisition transition is removed. Incorrect child-liveness decisions remain tracked under F04-10.
- F06-2 - fixed - Enter-TaskLock opens a permanent ownership file, and Exit-TaskLock only disposes its stream. No release-path unlink remains, removing the old-inode/new-pathname ownership split. Confirmed by source inspection; Linux execution evidence is reported in state.md rather than rerun here.
- F06-3 - fixed - Get-ArtifactHashes carries full alongside the initial hash, and codex-consult.ps1:902-903 rehashes that exact full path. The case-insensitive lookup is gone. A memory-only probe retained distinct before/after targets for a.bin and A.bin.

## Verdict: HOLD

F06-1, F06-2, and F06-3 are fixed, but F04-10 still allows recovery to admit another consultation while a previous Codex descendant remains alive.

### Blockers

_(none)_

### Unproven scenarios

- Real timeout or registration failure that leaves a surviving descendant, especially when persisting the survivor record also fails.
- Actual process termination behavior at the thirty-minute recovery boundary; the incorrect decision paths were reproduced with memory-only mocks.
- The reported PowerShell 7 and Linux writing harnesses were not rerun during this read-only review; macOS remains unexercised.
- This consultation's final response preservation, prior-finding ingestion, ledger commit, pending cleanup, and handle release occur after this response.

### First-run checklist (observable)

- [ ] Observe handoffs/08-codex-reacceptance-2-0.2.md, its .reply.json companion, and its .events.jsonl file. The raw companion must preserve this complete schema-version-1 response.
- [ ] Observe ledger consultation n=4 with purpose acceptance, mode resume, parent/result thread 01a0d01e-242c-7220-acb8-c5ce6ee72fc4 matching thread.started, structured=true, empty validation_error, and verdict HOLD.
- [ ] Observe F06-1, F06-2, and F06-3 reported fixed and F04-10 reported still-open in both ledger prior_findings and reviewer_checks for consultation 4. Coordinator statuses must remain unchanged.
- [ ] Observe no new findings or F08 IDs: finding_ids must be empty and new-finding counts zero. The reply prose must clearly identify existing F04-10 as the release blocker.
- [ ] Compare source fingerprints before and after, brief hashes, artifact full-path bindings, and usage against the completion event. The inspected clean source fingerprint was 7820e2f92d5a9284c724720a9003eb0b4dfcef815605473325872daf9f532295 at commit ca9decc508b805ff70a537c6a26db95574ad4f71.
- [ ] Confirm earlier ledger entries and finding histories remain intact, and the Markdown ends with Verdict, Blockers, Unproven scenarios, and First-run checklist.
- [ ] After normal delivery, confirm .consult.lock still exists with ownership released and .consult.pending.json has been removed after ledger commit. List/Stats should show no unresolved pending record or new orphan checks.
- [ ] Before accepting the release, inject survivor-record persistence failure after the launcher dies while Codex survives, then attempt both another consultation and a status update. Both must refuse without consuming the pending record. Repeat for a launching record older than thirty minutes.
- [ ] Treat exit code 0 as successful delivery of this HOLD, not release approval.
