# Handoff 02 - Codex: design-0.2

Date: 2026-09-23 22:32 local. Author: Codex (model config default, effort high), Codex CLI 0.155.1.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only). Argv: `codex exec --sandbox read-only --color never --json -c model_reasoning_effort="high" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-aa85c0fb7b9946d8b2658a5630485089.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a0cff8-4583-7110-8730-5fda5333d388` (source: events).
Brief: `.collab/bridge-0.2-2026-09-23/handoffs/01-claude-design-0.2.md`. Reviewed revision: 6483ec4 + uncommitted. Outcome: usable reply. Wall time: 80.7 s.
Raw event stream: `handoffs/02-codex-design-0.2.events.jsonl`.
Verbatim reply follows.

---

**Verdict: HOLD the design as written.** The scope is coherent, but revision binding, locking, and crash recovery need explicit contracts before implementation.

**Q1. Schema**

The core fields work. Change `evidence` into an array of `{kind, reference, observation}`: one finding can combine code inspection, command results, and inference. “Ran-command” alone says nothing about what the command proved. Keep `verification` explicitly prospective; evidence records what already happened.

Add a schema version. Prefer nullable `{path, line}` over `"path:line"`; some findings concern several files or a missing interface.

Validate schema and semantics locally, including verdict/blocker contradictions. Parseable JSON is insufficient. Malformed output may count as delivered text, but must have an unavailable verdict, a recorded validation error, and no findings ingestion. Preserve the original response without trimming or newline normalization.

Make the four R4 blocks the final sections; your proposed ordering puts additional sections after them.

**Q2. Finding identity**

The ownership split is right. Reviewer claims should never close findings automatically.

Add explicit reopening and optional `supersedes`/`duplicate_of` relationships for splits, merges, and corrected claims. Preserve original findings rather than rewriting their history. Require verification evidence for `verified`; a nonempty note alone does not resolve T1.

Feed back the trigger and verification criterion too: location plus claim can lose the invariant being checked. Missing prior IDs should become `not-checked`; unknown IDs must not create records.

Allocate IDs under the shared write lock and make recovery idempotent. Fix the baseline’s two-digit filename matcher before handoff 100; otherwise numbering can repeat.

**Q3. Revision binding**

Not yet. Hashing untracked blob hashes without their paths cannot distinguish renaming an untracked file while retaining its contents. Use a deterministic manifest containing paths, types/modes, and content hashes, with unambiguous framing and safe filename handling.

Define coverage for dirty submodules, ignored inputs, external briefs, Git filters, and unavailable Git. Record omissions explicitly. Exclude generated consultation output from the source fingerprint, while hashing briefs and evidence separately.

Fingerprint before and after review; changes invalidate a stable-revision claim. An immutable snapshot provides stronger assurance. Bind each quoted test result to its actual tested revision and artifact, not merely the coordinator’s revision when recording a status change.

**Q4. Defaults**

Keep structured output on and retain `-Raw`. The mechanism is supported by local CLI help and [official OpenAI documentation](https://learn.chatgpt.com/docs/non-interactive-mode). Check compatibility before launching and test new/resume/fork separately.

The effort defaults are reasonable hypotheses. Narrow core-contract scope to affected interfaces and their dependency boundaries; “every state machine” conflicts with 900 words. Apply the word budget to prose without truncating findings.

R5 remains incomplete: tokens and latency do not measure rework. Add coordinator-recorded follow-up outcomes linked to consultation IDs. Preserve absent usage fields as unknown.

**Q5. Lock**

A check-then-create lock races. Acquire atomically before reading ledgers or allocating filenames; both scripts must participate. Include an ownership nonce and process start identity to address PID reuse, and release only your own lock.

Age alone cannot prove a remote owner is dead. Cut automatic cross-host takeover from 0.2.0 unless you implement a lease with fencing.

The baseline kills only the launcher process; descendants may survive and continue writing after unlock. Terminate and confirm the process tree. `finally` cannot recover from forced termination.

A task lock also misses the same thread resumed from different task directories. Add thread-scoped exclusion or explicitly constrain that usage.

**Q6. Acceptance checklist**

Require observable evidence that:

- New/resume/fork produce validated responses, correct parentage, verdicts, IDs, and usage.
- Malformed JSON, wrong types, unknown IDs, refusal, empty output, CLI failure, and timeout never produce approval.
- Concurrent consultations and status updates lose no records; stale cleanup cannot remove another owner’s lock.
- Injected crashes between writes recover consistently across replies, findings, and sessions through an explicit commit/recovery protocol.
- Fingerprints distinguish renames, binary/untracked edits, artifacts, and mid-review changes.
- Existing ledgers migrate safely; Unicode, singleton arrays, handoff 100+, and PowerShell 5.1/7 work.
- Dry-run writes nothing; verification survives restart; re-review preserves identity and evidence.

One successful live consultation cannot establish these failure-path guarantees.
