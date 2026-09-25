# Handoff 14 - Claude: worker brief for wave 18 - fixes after the wave-17 diff-review panel (codex-consult 0.4.0 candidate)

Repository: C:\Users\Dmytro\claude-codex-consult (branch main, base a320844 + the uncommitted wave 17 -
do not revert anything; never touch .collab/; do not commit). Read first:
.collab/engines-0.4-2026-09-25/handoffs/06-claude-worker-brief-agy-engine.md (what wave 17 is),
09-codex-wave17-review-zai.md (F09-1..3), 10-codex-wave17-review-mimo.md (F10-1..3), then the code.
Rules as in handoff 06: no real model calls (fake + harness only; `agy models` once is fine), no keys,
harnesses one at a time, PowerShell only, plugin stays generic. Every existing count must hold
(harness-0.3 227, roster 113, format 37, pending 26, fixes 45, lock2 11, 3b 12 on 5.1; engines 81 +
whatever you add; 0.3 / roster / format / engines also on pwsh).

## Fixes (each with a harness case in tests/harness-engines.ps1 unless stated)

1. **F09-1 / F10-1 - tree-check scope.** Extend the agy tree check: snapshot the WHOLE collab root
   (every file under <CollabDir>, recursively: all task stores findings.json / sessions.json /
   state.md, every task's handoffs, .consult.* files excluded) before the turn and compare after
   (the current handoffs-only snapshot becomes this). Ignored paths, submodules and files outside
   the repository stay unmonitored: say so in the README invariant text ("enforced by evidence for
   tracked and untracked files and the collab directory; not for gitignored paths, submodules or
   files outside the repository") and in the ledger `sandbox` text. Harness: a fake-agy turn that
   writes .collab/<other-task>/x.md -> failed run; one that writes an ignored path -> documented
   blind spot (assert the run is usable and the README sentence exists, so the limitation is a
   recorded fact, not an accident).
2. **F09-2 - retry event streams in the ledger.** `denial_retry` and `format_retry` records gain
   `events` (the handoffs-relative path of that turn's event stream, `null` when no turn ran);
   for codex the format_retry `events` is the repair's event file if one is kept, else null (do not
   change codex file layout). Harness: the DENIAL and PROSE cases assert the paths.
3. **F09-3 - wording.** The tree-check failure text: "the working tree changed during the run (by
   the reviewer or anyone else): <n> files ..." and the same for the collab snapshot; README keeps
   the "do not edit during an agy run" warning. Harness: assert the new wording.
4. **F10-2 - trailing garbage.** `Read-AgyEvents`: the last non-empty line may be skipped as a
   partial line ONLY when the run was killed (timeout) or exited non-zero; on exit 0 a malformed
   last line makes the stream malformed (failed run, class transport). Harness: valid result +
   garbage line + exit 0 -> failed; the same with a timeout kill -> the timeout outcome.
5. **F10-3 - non-unique label.** `-Provider <label>` without `-Model` when the roster has several
   entries with that label: proceed with the first entry (0.3.0 rule) but print a console warning
   "roster: label gemini names 2 entries; the first (gemini :: gemini-3.8-flash-high [agy]) is
   used - pass -Model for another" and record it in `warnings[]`. Harness: dry-run assertion.
6. **F13 (judge) - sign-in check timing.** Live today `agy models` took 1.7 s, 7.7 s, 13.8 s and once
   > 15 s, so the 15 s preflight timeout refused a real run ("`agy models` did not finish within
   15 s"). Two changes: (a) the timeout becomes 45 s (preflight and codex-providers.ps1; the hook
   is -NoNetwork and unaffected); (b) a ledger short-circuit: when THIS repository's ledgers hold a
   usable reply on the same agy endpoint (fingerprint) within the last 60 minutes (consult clock),
   the credential verdict is `ok: signed in (usable reply <m> min ago)` without running `agy
   models`; the listing shows the same text. The endpoint health's auth/quota rules stay in front
   of it (a recorded auth failure or a usage limit still refuses). Harness: a scratch ledger with a
   usable agy reply 5 min ago -> no `agy models` call (the fake logs calls; assert none), 61 min
   ago -> the call happens; the fake's MODELS=hang case -> unknown after the timeout (use a short
   test hook for the timeout value, e.g. env CODEX_CONSULT_TEST_LOGIN_TIMEOUT, so the harness does
   not wait 45 s).
7. **Docs.** CHANGELOG [0.4.0]: add a "Wave 18" bullet list for 1-6 and a "Live evidence" bullet:
   first run n=3 (gemini-3.8-flash-low, checkpoint, 118 s, structured first turn), panel 2d8d5f25
   n=4-6 (ZAI ACCEPT, mimo HOLD, gemini-3.8-flash-high [agy] ACCEPT, 605 s, usage 1.6M in / 5.9M
   cached), resume n=7 (same conversation id, the model quoted the previous consultation id),
   the denial check n=8 (result to be filled by the judge - leave the line "denial check: <judge
   fills in>"). README: the agy section's cost line gets the panel numbers (a diff review on
   flash-high read the tree: 1.6M input + 5.9M cached tokens, 605 s). Update the sandbox wording
   per item 1 everywhere it appears (README, skills, ledger examples).

## Report

Files changed (one line each); harness counts on 5.1 and pwsh with any failure verbatim; the new
assertions per item; anything you could not do.
