# Handoff 32 - Codex: astra-0.6.0-delta-3

Date: 2026-10-07 20:27 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 1 of 12 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: c882f784-cca9-4410-b51f-c4780e373614.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-77a8bf70981144f68baa2c09aa7349ff.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a1176d-eb75-7fe3-a490-aecbc326c0b1 -` (prompt on stdin).
Parent thread: `01a1176d-eb75-7fe3-a490-aecbc326c0b1`. Result thread: `01a1179e-e5b7-7ea3-a56e-c611d5acf0ef` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/31-claude-0.6.0-delta-round3.md` (sha256 89d338ca567e). Reviewed: 2bd8dfb, base 2bd8dfb2396195fd4fc384063ff2b5dd1bd1f928, tree sha256 49cd9281eb1d, 0 changed files.
Bridge outcome: usable reply. Wall time: 176 s. Tokens: in 12121075 (cached 10195840), out 70912, reasoning 18355.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `da4aac2..8629bcb` - the range changes 15 files, 1089 lines (1033 insertions, 56 deletions).
Verdict: HOLD - E23 can release an unknown panel tree while a reviewer survives, and E24 still mistakes recreated legacy files for previously accounted contents. Findings: 1 blocker, 0 major, 1 minor, 0 note (F32-1..F32-2, tracked in `findings.json`). Structured reply: `handoffs/32-codex-astra-0.6.0-delta-3.reply.json`.
Raw event stream: `handoffs/32-codex-astra-0.6.0-delta-3.events.jsonl`.
Verbatim reply follows.

---

1. **Q1 — E23 fixes persistence, but panel release remains unsafe (finding #1).** A surviving grandchild whose unrecorded intermediate parent has exited matches neither recorded parent PID. Panel recovery omits the machine-wide check and releases the record. Using the actual scan logic with a mocked Windows process table, the panel record returned `Active=false` despite a live `codex.exe`; the identical non-panel record returned `Active=true`.

   A clean direct-child scan therefore cannot prove an unknown panel tree is gone. Retain that uncertainty until stronger ownership evidence or informed operator clearance resolves it. Non-panel “task not verifiable” matches can conservatively block unrelated activity; the named ambiguity and manual-clearance path are preferable to guessing. Cross-host and non-Windows refusal are deliberate limits, not evidence of a dead tree.

2. **Q2 — Length tracks an append offset, not file identity (finding #2).** The same-file append replay works: one appended line was counted once. But consider a crash after deletion and before the second `.last` rewrite, followed by an older writer recreating the legacy filename. If the new file has the recorded length, its entire contents are skipped; if longer, its initial recorded-length bytes are skipped. My in-memory tests reproduced both: a one-line replacement counted zero, and a two-line replacement counted only one; both were scheduled for deletion.

   The save-before-delete ordering still fixes F27-3. E24 needs a unique staged generation or equivalent reliable identity to close F30-2. A shorter-file check alone cannot provide the claimed crash guarantee.

3. **Q3 — HOLD on finding #1; F30-2 also remains unresolved.** The fixes improve both paths, but the release and accounting claims exceed the evidence. All five changed PowerShell files parsed successfully, and `git diff --check` passed. I read the added fixtures and ran read-only mock replays; I did not execute filesystem-writing harnesses. The final 22-harness run remains required before tagging.

## Requested checks

- **RC1:** Working directory: repository root; permission: workspace-write; procedure: extend the unknown-tree fixture to a panel member with launcher → intermediate → reviewer, terminate the launcher and intermediate while leaving the reviewer alive, then retry the task. Require retained recovery state and no new reviewer launch (finding #1). Budget: one fixture, 10 minutes execution.
- **RC2:** Working directory: repository root; permission: workspace-write; procedure: interrupt a fold after deletion but before clearing its committed metadata, recreate the legacy filename with equal-length and longer new contents, then restart the flush. Require every new line counted exactly once (finding #2). Budget: two cases, 5 minutes execution.
- **RC3:** Working directory: repository root; permission: workspace-write; command: `powershell -NoProfile -File tests/run-all.ps1`. Require all 22 harnesses passing on the final candidate. Budget: one quiet-machine run, 45 minutes.

---

### Findings

- **F32-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:9981`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10207`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10217` - Unknown-tree recovery releases a panel member when a live reviewer descends through a dead, unrecorded intermediate process, because direct-parent scans cannot find it and the panel path omits the machine-wide scan. Trigger: After denied enumeration and an unconfirmed kill, the recorded bridge and launcher are gone, an unrecorded intermediate parent has exited, and its reviewer child remains alive. Evidence: read-code: The by-parent scan matches only processes whose current ParentProcessId equals the supplied recorded PID.; read-code: Panel records omit the machine-wide scan and return inactive after the recorded-parent scans find nothing.; ran-command: A live codex.exe with a dead, unrecorded parent produced Active=false for a panel record. Removing the panel field produced Active=true for the same process table. Verify: Run a panel recovery fixture containing a surviving reviewer beneath a dead, unrecorded intermediate parent; require recovery to remain active and prevent another launch. Remedy: Do not release an unknown panel tree solely from clean direct-parent scans. Preserve the uncertainty until reliable ownership tracking establishes termination or the operator explicitly clears it; merely adding a global scan must also account for live sibling reviewers. Supersedes: F30-1.
- **F32-2** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:11960`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12061`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12103` - The {name, bytes} fold marker cannot distinguish a recreated legacy file whose length equals or exceeds the deleted generation, so new diagnostic counter lines can still be skipped and deleted. Trigger: A fold deletes the legacy file, then crashes before clearing its committed marker; an older producer recreates that filename with at least the recorded byte length before recovery. Evidence: read-code: Only shorter files are treated as replacements. Equal or longer files are treated as already accounted through the recorded offset.; ran-command: An equal-length replacement containing one new line returned Status=0 and NewlyFolded=0. A longer replacement containing two new lines returned Status=1 and NewlyFolded=1. Both were held for deletion; the same-file append control correctly counted one appended line. Verify: Interrupt after legacy-file deletion but before marker cleanup, recreate the filename with equal-length and longer new contents, then require all replacement lines to be accounted exactly once. Remedy: Use a unique staged filename or another reliable generation identity for committed fold contents. Do not infer generation identity from length; retain offset handling only after establishing that it is the same generation. Supersedes: F30-2.

### Prior findings

- F27-1 - fixed - Unverified-only kills retain recovery records at all three kill sites; E23 preserves that behavior.
- F27-2 - fixed - The previously verified fail-closed command-line checks remain unchanged in this delta.
- F27-3 - fixed - Accounting is still saved before source deletion; the remaining replacement-file defect is covered by finding #2.
- F30-1 - fixed - Unknown-tree records are now persisted. Finding #1 replaces the original persistence concern with a reproduced unsafe-release case.
- F30-2 - still-open - Same-generation appends are handled, but equal-length and longer replacement generations still lose counts; finding #2 narrows and supersedes the earlier claim.

## Verdict: HOLD

E23 can release an unknown panel tree while a reviewer survives, and E24 still mistakes recreated legacy files for previously accounted contents.

### Blockers

- **F32-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:9981`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10207`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10217` - Unknown-tree recovery releases a panel member when a live reviewer descends through a dead, unrecorded intermediate process, because direct-parent scans cannot find it and the panel path omits the machine-wide scan. Verify: Run a panel recovery fixture containing a surviving reviewer beneath a dead, unrecorded intermediate parent; require recovery to remain active and prevent another launch. Remedy: Do not release an unknown panel tree solely from clean direct-parent scans. Preserve the uncertainty until reliable ownership tracking establishes termination or the operator explicitly clears it; merely adding a global scan must also account for live sibling reviewers.

### Unproven scenarios

- The added writing harnesses and final full suite were not executed during this read-only review.
- The panel orphan case used a mocked Windows process table rather than actual process termination.
- Replacement-file accounting was reproduced with in-memory streams rather than a real crash between filesystem operations.
- Actual cross-host recovery, non-Windows behavior and changing process-inspection permissions were not exercised.

### First-run checklist (observable)

- [ ] The final candidate revision has a complete passing report for all 22 harnesses.
- [ ] An unconfirmed panel kill retains recovery protection while any reviewer survives through an unrecorded intermediate parent; retry produces no new reviewer-launch event.
- [ ] Recovery output distinguishes confirmed termination from unresolved ownership and names any required operator clearance.
- [ ] A failed initial .last save preserves source files and the old baseline and emits its warning.
- [ ] Fold replay counts same-file appends and recreated legacy-file contents exactly once, including equal-length replacements after deletion.
