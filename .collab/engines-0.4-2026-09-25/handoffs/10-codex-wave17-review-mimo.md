# Handoff 10 - Codex: wave17-review-mimo

Date: 2026-09-25 14:03 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-0.4.json - position 3 of 5, panel 2d8d5f25 member 2 of 3; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.1-pro-high [agy] (weighty reviewer; purpose diff-review is light (use -PanelAll)).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: a7e543e9-296d-4e6b-a537-fa4310d1f204.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-b4d589a7601c42e7a2570f6307d2bac5.md fork 01a0d7cc-107c-7172-80e7-1a20119c4305 -` (prompt on stdin).
Parent thread: `01a0d7cc-107c-7172-80e7-1a20119c4305`. Result thread: `01a0d873-1534-7881-84ca-2a2bc7038ae7` (source: events).
Brief: `.collab/engines-0.4-2026-09-25/handoffs/08-claude-wave17-review.md` (sha256 91c25c225d47). Reviewed: a320844 + uncommitted, base a320844989f75989a670c3d0c292929999a4a11d, tree sha256 a3cf3dbbd383, 23 changed files.
Bridge outcome: usable reply. Wall time: 391 s. Tokens: in 2127541 (cached 759040), out 21656, reasoning 11124.
Verdict: HOLD - The implementation fixes the listed findings and preserves the codex path, but the agy read-only evidence check has material blind spots that make its safety claim too broad. Findings: 0 blocker, 1 major, 2 minor, 0 note (F10-1..F10-3, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/10-codex-wave17-review-mimo.reply.json`.
Raw event stream: `handoffs/10-codex-wave17-review-mimo.events.jsonl`.
Verbatim reply follows.

---

**Q1.** None of the three real streams is misjudged. `04-agy-engine-design.attempt1.events.jsonl` has one init/result pair with matching UUIDs and correctly fails as the F11 empty denial; handoffs 04 and 07 each have exactly one result, matching init/result ids, and are correctly usable. The parser's "last malformed line ignored" escape is broader than killed-run recovery and could accept a valid result followed by corruption, but no real file demonstrates it.

**Q2.** The retry fires only for `DeniedEmpty`, a verified thread, and no tree problem; quota errors and tree failures cannot trigger it, and `-DenialRetry` permits at most one turn. The empty first result remains in the primary events file and the retry stream is separately named, but `denial_retry` records only the retry thread and truncated reason, not the first result's id/path.

**Q3.** It compares the git status manifest before/after, brief and artifact hashes, and a snapshot of the task's handoffs. It misses ignored files, other collaboration-root locations, submodules beyond directory entries, and anything outside the repository. Failing the run is correct: writing violates the consultation contract even when the prose is valid.

**Q4.** No codex-visible regression found: argv construction remains `codex exec ...`; the agy tools line is conditional on `-not $isCodex`; the prompt, repair path and codex events parsing are unchanged. The explicit additions are `reviewer.engine`, `warnings`, and `denial_retry`, matching the claimed three fields.

**Q5.** With an agy roster entry the hook prints `gemini not checked (launcher present)` and calls `codex-providers.ps1 -Json -NoNetwork`; the unchecked agy entry is skipped by the walk, so it cannot be selected. Without `-NoNetwork`, the listing makes one `agy models` call and reports available/unavailable/unknown, potentially selecting the agy entry.

**Q6.** `-Provider gemini` without `-Model` deterministically takes the first `gemini` entry, so the low-tier entry wins over a later weighty pro entry. A light panel runs only the `always` entry; a weighty purpose or `-PanelAll` runs both. `-Thread` recovers the exact provider/model/engine tuple and is unambiguous. The provider-only case is documented but still easy to misuse.

**Q7.** Yes. README “Engines” and setup-providers cover installation, user-run sign-in, full model ids, roster shape, `agy models` expected output, verification commands, cost, and F11/F12 behavior. An agent can wire Gemini without guessing.

**Q8.** HOLD. First live acceptance check: run the full Windows PowerShell and pwsh harnesses, requiring all engine assertions and the unchanged legacy counts, then one real agy smoke run whose ledger shows structured output, thread provenance, and a clean tree check.

## Requested checks
RC1 (finding #1): from `C:\Users\Dmytro\claude-codex-consult`, workspace-write, 10 minutes: run a real agy consultation whose prompt asks it to create a file at an ignored path such as `.collab/probe.txt`; settle whether the run remains `usable reply` despite the write.
RC2 (finding #2): from the repository root, read-only, 5 minutes: append malformed text after a valid fake-agy result and run `Read-AgyEvents`; settle whether the stream is still accepted.

---

### Findings

- **F10-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:465`, `plugins/codex-consult/scripts/codex-consult-common.ps1:472`, `plugins/codex-consult/scripts/codex-consult.ps1:2118` - The agy tree check does not enforce read-only across ignored files, the collaboration root outside the task's handoffs, submodules, or paths outside the repository, so its claimed evidence-based guarantee is incomplete. Trigger: An agy reviewer writes an ignored file, another collab directory, or an external path while returning a schema-valid reply. Evidence: read-code: The manifest explicitly excludes ignored files and the collaboration directory; submodules are not recursed.; read-code: Only the revision manifest, brief, artifacts, and one handoffs directory snapshot are compared. Verify: Run an agy review that writes `.collab/probe.txt`; confirm whether the run is still marked usable. Remedy: Snapshot the full collaboration root and recurse submodules, or narrow the invariant and docs to the paths actually checked; reject writes outside monitored scope when detectable. Supersedes: F02-3, F05-1.
- **F10-2** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:3122` - Read-AgyEvents exempts the final non-empty line from malformed-stream detection regardless of exit status, so a completed run with a valid result plus trailing corruption can be ingested. Trigger: A fake or real agy stream has one valid result followed by a truncated or non-JSON final line while the process exits 0. Evidence: read-code: The parser skips malformed parsing for the last non-empty line without checking whether the run was killed.; ran-command: All real streams contain exactly one result and matching init/result conversation ids; the edge is not represented. Verify: Append garbage after a valid fake-agy result and assert that Read-AgyEvents reports malformed. Remedy: Ignore a trailing partial line only when a timeout/pre-failure is present; otherwise reject the stream.
- **F10-3** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:3705`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3833` - When several roster entries share one provider label, `-Provider <label>` without `-Model` silently selects the first entry, which can choose the wrong tier. Trigger: A roster contains `gemini` low-tier and `gemini` weighty high-tier entries and the caller passes only `-Provider gemini`. Evidence: read-code: The documented selection rule is the first entry of that provider.; read-code: The listing test intentionally creates two gemini entries with different models. Verify: Dry-run `-Provider gemini` with that roster and inspect the selected model. Remedy: Require `-Model` when a label is non-unique, or record and display a prominent first-entry selection warning.

### Prior findings

- F02-1 - fixed - Get-AgyTurnOutcome hard-fails not-found warnings and any resume id mismatch, including repair turns.
- F02-2 - fixed - The hook calls codex-providers.ps1 with -NoNetwork and reports unchecked engine credentials.
- F02-3 - fixed - Tree/handoff changes now fail agy runs with class permission; remaining scope gap is filed separately.
- F02-4 - fixed - Read-AgyEvents records init ids as candidates and fails missing-result streams; timeout tests cover it.
- F02-5 - fixed - Google codes and retry wordings, including retryDelay payloads, are implemented and unit-tested.
- F02-6 - fixed - Engine table and recorded launcher replace codex-only naming and recovery assumptions.
- F02-7 - fixed - Repair and denial turns use ExpectThread and reject a replacement conversation.
- F05-1 - fixed - Read-only is detected and fails the run, with the monitoring-scope limitation newly filed.
- F05-2 - fixed - Structured output is written to .reply.json before validation and recovery names event streams.
- F05-4 - fixed - The engine default is new; resume is explicit.

## Verdict: HOLD

The implementation fixes the listed findings and preserves the codex path, but the agy read-only evidence check has material blind spots that make its safety claim too broad.

### Blockers

_(none)_

### Unproven scenarios

- Behavior of real agy streams with multiple results or trailing corruption.
- Writes to ignored files, other collab directories, submodules, and external paths.
- Whether duplicate provider labels are intentional in operator rosters.
- Full live codex regression beyond the unchanged harness counts.

### First-run checklist (observable)

_(none)_
