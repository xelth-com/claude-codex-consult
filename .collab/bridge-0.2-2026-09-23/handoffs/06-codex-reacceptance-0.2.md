# Handoff 06 - Codex: reacceptance-0.2

Date: 2026-09-24 00:29 local. Author: Codex (model config default, effort high), Codex CLI 0.155.1.
Invocation: `codex-consult.ps1` (mode: resume, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -c model_reasoning_effort="high" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-d322f03a97d34a62a09da2b7bad72755.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json resume 01a0d01e-242c-7220-acb8-c5ce6ee72fc4 -` (prompt on stdin).
Parent thread: `01a0d01e-242c-7220-acb8-c5ce6ee72fc4`. Result thread: `01a0d01e-242c-7220-acb8-c5ce6ee72fc4` (source: events).
Brief: `.collab/bridge-0.2-2026-09-23/handoffs/05-claude-reacceptance-0.2.md` (sha256 bfd706ec9ea6). Reviewed: 6483ec4 + uncommitted, base 6483ec4a4bf67587be1d98b0cdc98c595ab3454d, tree sha256 a5d2c8522c73, 18 changed files.
Bridge outcome: usable reply. Wall time: 392.6 s. Tokens: in 2479012 (cached 2292608), out 20520, reasoning 4236.
Verdict: HOLD - The original fixes substantially improve the bridge, but recovery metadata can still be destroyed during lock acquisition, child registration remains unsafe across crashes, and artifact rechecking conflates case-distinct paths. Findings: 1 blocker, 2 major, 0 minor, 0 note (F06-1..F06-3, tracked in `findings.json`). Structured reply: `handoffs/06-codex-reacceptance-0.2.reply.json`.
Raw event stream: `handoffs/06-codex-reacceptance-0.2.events.jsonl`.
Verbatim reply follows.

---

**Q1. HOLD; eight findings are fixed, three remain open.** “Fixed” here describes the inspected implementation and stated probes, not coordinator verification or untested platforms.

| ID | Assessment |
|---|---|
| F04-1 | Fixed: stores use flushed temporary files and atomic replacement; empty existing stores are refused. |
| F04-2 | Fixed for the original stale-lock takeover race: ownership now uses a held handle. A separate Unix release race is recorded below. |
| F04-3 | Still open, with a changed recovery gap: reviewer-check and Raw numbering are corrected, but acquiring the lock destroys its previous reservation before safely consuming it. The replacement finding below describes this. |
| F04-4 | Fixed: ACCEPT plus an explicitly still-open prior blocker loses its verdict and renders that blocker. |
| F04-5 | Fixed: the original `1e30` input becomes a validation error without throwing; raw copying precedes parsing. |
| F04-6 | Fixed: purpose/verdict mismatches invalidate the verdict. |
| F04-7 | Fixed for the tracked executable-mode trigger; untracked-mode omissions are explicit. |
| F04-8 | Fixed: the source fingerprint uses ordinal path dictionaries. |
| F04-9 | Still open for case-distinct artifacts: the after-hash lookup uses case-insensitive `-eq`, so it can hash the wrong file. |
| F04-10 | Still open: the child starts before its identity is persisted, and failures writing child/survivor metadata are swallowed. |
| F04-11 | Fixed by inspection: raw-copy failure fails the bridge, prevents ingestion, and retains the original. |

The three scripts parse on PowerShell 5.1. Memory-only probes confirmed corrected numbering, distinct dictionary keys, validation behavior, and the artifact lookup defect. Two source samples matched `a5d2c8522c73…`.

The remaining child gap is concrete: kill the bridge after `Start-Process` but before `Update-TaskLock`. Its child continues, while the leftover record contains no child PID and the next invocation proceeds. A failed metadata write has the same consequence because its exception is ignored. Persist a conservative launch/quarantine state before spawning, and require successful registration or confirmed termination before allowing recovery.

**Q2. The held handle improves normal contention, but its lifecycle still has defects.** On Windows, an incompatible reader or scanner can cause a safe temporary refusal or replacement failure; it does not justify bypassing exclusion. The bridge’s own store readers share deletion, so normal `-List` reading does not prevent atomic replacement.

The serious new boundary is acquisition: `Enter-TaskLock` overwrites the old record with empty reservation/child fields before parsing and checking it. A crash in that interval loses the recovery information. `Write-LockRecord` also truncates that record in place. Refusing a surviving child therefore temporarily destroys the very evidence needed to refuse it after another crash.

On Unix, unlinking the lock pathname is unsafe with descriptor-based locking: a contender paused between opening the old inode and acquiring its lock can later own that unlinked inode while another contender locks a newly created pathname. Keep a permanent lock file and separate durable recovery metadata from ownership.

**Q3. Blockers:** the destructive recovery-record transition and unresolved F04-10 prevent acceptance. The Unix release and artifact-binding defects also require correction or an explicit supported-platform scope.

**Unproven:** I did not rerun writing harnesses, inject real crashes, or terminate processes. PowerShell 7/Unix behavior, scanner interference, unkillable descendants, and this consultation’s final persistence remain unverified. Reported harness successes do not cover the interleavings identified here.

**Observable first-run checklist:** inspect the three `06-codex-reacceptance-0.2` artifacts and consultation `n=3`. Confirm resume of `01a0d01e-242c-7220-acb8-c5ce6ee72fc4`, structured HOLD with no validation error, all eleven prior dispositions, three new findings, matching reviewer checks, unchanged coordinator statuses, and preserved earlier entries. Source and brief before/after hashes should match; artifact comparisons must identify the correct files. Confirm the final four review blocks, usage matching the completion event, and clean lock release. Exit code 0 establishes delivery of this HOLD, not release acceptance.

---

### Findings

- **F06-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:1447`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1542`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1547`, `plugins/codex-consult/scripts/codex-findings.ps1:256` - Lock acquisition destructively replaces the previous recovery record before validating or durably transferring its reservation and child information, so another crash can erase a reserved consultation number or a surviving-child quarantine. Trigger: A previous run leaves a reservation or live-child record; a consultation or status updater acquires the handle and crashes after Write-LockRecord replaces that record but before the old record is consumed or restored. Interruption during the in-place truncation is another loss window. Evidence: read-code: The new record initializes n and child_pid to null, nn to empty, and survivors to an empty array. Enter-TaskLock writes it at line 1542 before parsing the previous text or checking previous children. The old information exists only in memory during that interval.; read-code: Write-LockRecord truncates the held file before rewriting it. The status updater restores a previous reservation only on normal finally execution.; ran-command: Replacing a record containing n=9, nn=20, child_pid=12345 and survivors with the acquisition record produced null reservation/child fields and an empty survivors array. No filesystem writes were performed.; inferred: After that crash, the next invocation cannot recover the erased reservation or detect the previously recorded live child. Correct scanning of persisted reviewer checks does not recover a reservation that had no other durable reference. Verify: In an isolated fixture, seed an uncommitted reservation and a live-child quarantine separately, pause acquisition immediately after the replacement write, kill the acquiring process, and verify that the next invocation still preserves the reservation and refuses the live child. Remedy: Separate the permanent ownership lock from atomically persisted recovery metadata. Validate the previous record before changing it, transfer reservations durably, preserve quarantine until child termination is established, and refuse corrupt recovery metadata rather than treating it as absent. Supersedes: F04-3.
- **F06-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:1501`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1627` - The Unix release path can split task ownership across an unlinked lock inode and a newly created lock file because it deletes the pathname used for descriptor-based exclusion. Trigger: A contender opens the existing lock inode and pauses before acquiring its advisory lock; the owner unlinks and closes it; that contender then acquires the old inode while another invocation creates and locks the pathname's replacement. Evidence: read-code: The documented Unix mechanism is advisory flock through FileShare.None. Acquisition opens the pathname, while release unlinks that pathname before disposing the held stream.; inferred: A descriptor already referring to the old inode is not redirected to the replacement pathname. Under the stated descriptor-locking mechanism, the two contenders can therefore lock different files for the same task. Verify: On a supported Unix runtime, use an instrumented opener or syscall barriers to pause a contender between opening the old lock file and acquiring its lock, release the owner, start another contender, and assert that simultaneous ownership is impossible. Remedy: Keep the ownership lock file permanently at a stable pathname and inode; release ownership by closing the handle rather than unlinking it. Store recoverable run metadata separately.
- **F06-3** [major] `plugins/codex-consult/scripts/codex-consult.ps1:826` - Artifact after-hashing selects paths case-insensitively, so case-distinct artifacts can be bound to the wrong after-review bytes and an actual artifact change can go undetected. Trigger: Both a.bin and A.bin are supplied on a case-sensitive filesystem. They initially have identical bytes, and only A.bin changes during the review. The after-hash lookup selects a.bin for both entries. Evidence: read-code: For every initial artifact hash, the code resolves its full path using Where-Object with PowerShell's case-insensitive -eq and Select-Object -First 1.; ran-command: With a.bin mapped to lower and A.bin mapped to upper, the exact lookup selected lower as the rehash target for both artifacts.; inferred: Both after hashes can still equal the initial hash because the unchanged lowercase file is read twice, leaving artifacts_changed_during_review false. Verify: In a case-sensitive fixture, supply two case-distinct artifacts with identical initial contents, modify only the second during a delayed review, and verify its own sha256_after changes and artifact drift is reported. Remedy: Carry each artifact's resolved full path alongside its initial hash and rehash that exact object, or use an ordinal case-sensitive lookup without selecting the first case-insensitive match. Supersedes: F04-9.

### Prior findings

- F04-1 - fixed - Write-JsonFile now uses flushed same-directory temporary files and atomic replacement; Read-JsonStore refuses empty or unparseable existing stores. Confirmed by code inspection; real crash injection was not repeated.
- F04-2 - fixed - The original stale-record reread/delete takeover has been removed. Ownership is held through the stream for the critical section. A distinct Unix unlink/recreate release defect is reported as a new finding.
- F04-3 - still-open - Reviewer-check scanning, orphan reporting, and Raw-mode numbering are corrected; a memory-only numbering probe passed. However, the new lock reservation is overwritten before safe recovery and can be erased by a second crash. The new recovery-metadata finding supersedes this claim.
- F04-4 - fixed - Memory-only parsing and rendering confirmed that ACCEPT with a still-open prior blocker produces an empty verdict and validation error, renders the retained blocker, and changes neither its identity nor coordinator status.
- F04-5 - fixed - The original line=1e30 probe now returns a bounded-line validation error without throwing. Validation and normalization are caught, and raw copying precedes parsing.
- F04-6 - fixed - The resolved purpose is supplied to semantic validation. Memory-only ADVISE/acceptance and ACCEPT/framing probes returned empty verdicts with purpose-specific validation errors.
- F04-7 - fixed - Tracked manifest entries now incorporate modes from git diff --raw HEAD, addressing the original already-modified tracked-file trigger. Untracked and no-HEAD mode omissions are explicit; native Unix execution was not tested here.
- F04-8 - fixed - Source fingerprint path maps use ordinal dictionaries. A memory-only probe retained a.txt and A.txt as two distinct keys with their respective values.
- F04-9 - still-open - Brief and artifact hashes are now collected under the lock and repeated afterward, fixing ordinary single-path drift. Case-distinct artifact lookup still rehashes the wrong file; the new artifact-binding finding supersedes this claim.
- F04-10 - still-open - The normal survivor branch retains the lock record, but codex-consult.ps1:786 launches the child before registration at :796; a crash between them leaves a live child without a recorded identity. Child and survivor metadata write failures at :796 and :807 are swallowed. Persist a conservative launch/quarantine state before spawning and require successful registration or confirmed termination; test these exact boundaries.
- F04-11 - fixed - Copy failure now sets keepLastMsg, changes bridge_outcome to failure, prevents ingestion, and leads to exit 1 while retaining the original. Confirmed by inspection; filesystem copy-failure injection was not repeated.

## Verdict: HOLD

The original fixes substantially improve the bridge, but recovery metadata can still be destroyed during lock acquisition, child registration remains unsafe across crashes, and artifact rechecking conflates case-distinct paths.

### Blockers

- **F06-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:1447`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1542`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1547`, `plugins/codex-consult/scripts/codex-findings.ps1:256` - Lock acquisition destructively replaces the previous recovery record before validating or durably transferring its reservation and child information, so another crash can erase a reserved consultation number or a surviving-child quarantine. Verify: In an isolated fixture, seed an uncommitted reservation and a live-child quarantine separately, pause acquisition immediately after the replacement write, kill the acquiring process, and verify that the next invocation still preserves the reservation and refuses the live child. Remedy: Separate the permanent ownership lock from atomically persisted recovery metadata. Validate the previous record before changing it, transfer reservations durably, preserve quarantine until child termination is established, and refuse corrupt recovery metadata rather than treating it as absent.
- **F04-3** (prior, still-open) `plugins/codex-consult/scripts/codex-consult.ps1:503`, `plugins/codex-consult/scripts/codex-consult.ps1:538`, `plugins/codex-consult/scripts/codex-consult-common.ps1:918`, `plugins/codex-consult/scripts/codex-findings.ps1:157` - Recovery does not detect or reserve consultation numbers belonging only to persisted reviewer checks, allowing a later consultation to reuse a number and misattribute the earlier check; Raw mode also ignores orphan finding-source reservations. Verify: Seed a committed finding, persist a checks-only consultation, interrupt before the sessions write, then run List and another consultation; verify orphan detection and that the consultation number is not reused, including a Raw rerun. Remedy: Persist a consultation reservation or pending receipt before execution, detect incomplete consultations independently of new findings, and account for every audit reference when allocating numbers. Apply reservation rules in Raw mode too.

### Unproven scenarios

- The reported writing harnesses and crash/timeout fixtures were not rerun during this read-only review.
- Actual process death during lock-record replacement, child registration, survivor recording, and reservation restoration remains untested here.
- PowerShell 7 and Unix lock, rename, mode, and process-tree behavior were not executed; the Unix unlink race is inferred from the implemented ownership mechanism.
- Antivirus or incompatible-reader interference and cross-host shares were not tested; cross-host use is explicitly outside the stated scope.
- The final artifacts, ingestion, ledger commit, and lock release for this consultation occur after this response and cannot yet be verified.

### First-run checklist (observable)

- [ ] Observe handoffs/06-codex-reacceptance-0.2.md, .reply.json, and .events.jsonl; the raw companion must contain this complete schema-version-1 response independently of Markdown rendering.
- [ ] Observe consultation n=3 with mode resume, parent and resulting thread 01a0d01e-242c-7220-acb8-c5ce6ee72fc4 as confirmed by thread.started, purpose acceptance, structured=true, empty validation_error, and verdict HOLD.
- [ ] Observe all eleven F04 IDs in the ledger prior_findings and in their reviewer_checks for consultation 3: eight fixed; F04-3, F04-9, and F04-10 still-open. Coordinator statuses must remain implemented until separately changed.
- [ ] Observe three new proposed findings F06-1 through F06-3, with one blocker and two majors, matching this response. Preserve supersedes links to F04-3 and F04-9 without automatically changing their coordinator statuses.
- [ ] Observe the final Markdown blocks Verdict, Blockers, Unproven scenarios, and First-run checklist. The retained still-open blocker F04-3 and the new blocker must remain visible until coordinator reconciliation.
- [ ] Observe matching source before/after hashes and matching brief before/after hashes, or explicit drift warnings. This review sampled source fingerprint a5d2c8522c7366c4ccbdd10324aaf1fb04513f528028217e1c50a452b369a666 twice.
- [ ] Compare usage fields against turn.completed and confirm prior ledger entries and finding histories remain intact; List -All should report no new orphan findings or reviewer checks after completion.
- [ ] Confirm normal completion releases ownership. Before release acceptance, additionally prove safe recovery when acquisition dies after reading a leftover, when a child starts before registration, and when child/survivor metadata persistence fails.
- [ ] Exit code 0 proves successful delivery of this HOLD only; it does not establish release acceptance.
