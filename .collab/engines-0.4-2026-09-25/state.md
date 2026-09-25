# Task engines-0.4-2026-09-25 - ROADMAP R10: the `agy` engine (0.4.0 candidate)

Coordinator: Claude (judge). Reviewers: the roster (openai gpt-6-astra weighty - at its usage limit
until 2026-09-28 20:35 Berlin, skipped by the roster; ZAI glm-5.3; mimo mimo-v2.6-pro) plus Gemini
consulted directly through `agy` (the engine under design does not exist yet, so its reply is
saved by hand as handoff 04 and rated here, not in findings.json).

## Round 1 - design review before building (2026-09-25 10:50-11:25)

- `handoffs/01-claude-engine-agy-design.md`: facts F1-F10 verified on agy 1.2.11, proposals D1-D12,
  questions Q1-Q10. Panel `a243bb61` (`-Panel -Purpose framing`): n=1 `ZAI :: glm-5.3` (567 s,
  ADVISE, F02-1..7, structured on the first turn, handoff 02), n=2 `mimo :: mimo-v2.6-pro` (574 s,
  ADVISE, F05-1..5, handoff 05 - number 04 was taken by the Gemini files meanwhile, 03 unused).
  Gemini `gemini-3.1-pro-high` direct (handoff 04): attempt 1 ended with NO output (see F11),
  attempt 2 on the same conversation answered in full (194 s, 66k tokens, ADVISE, 5 findings).
- New facts from the round (verified live):
  - **F11** a tool call that needs a permission print mode cannot grant (`run_command`) ends the run
    with exit 0, status SUCCESS, an empty response and the stderr line `jetski: no output produced -
    a tool required the "command" permission that headless mode cannot prompt for, so it was
    auto-denied ...`; one more turn on the same conversation ("do not run commands, answer from what
    you read") produced the full object.
  - **F12** (GLM's RC1) `--sandbox` does NOT block file writes: `write_to_file` created a file in the
    working directory with no prompt and no notice; `--mode plan` changes nothing (permission_mode
    stays request-review; with `--disable-slash-commands` agy warns "--mode plan has no effect").
- Agreement of all three (independently): stdin stream-json (Q1); effort recorded, not sent (Q2);
  fail closed on a resume mismatch (Q3); default mode `new` (Q4 - all three against my `resume`);
  no network call in the hook (Q5); the Google error codes and "retry in 32s" (Q6); partial output /
  no output / not-found must FAIL, not warn (Q7); parameterise every hardcoded `codex` (Q8).
- Judge's decisions -> amendments A1-A20 of the worker brief (scratchpad; copied into the wave's
  CHANGELOG entry when built): default `new`; failed-run rules incl. class `permission`; ONE denial
  retry on the same conversation (`-DenialRetry`); `agy models` only in the per-run preflight and in
  codex-providers.ps1, the hook runs with `-NoNetwork` and prints "not checked"; conversation-id
  rules (result authoritative, init must match, missing result -> candidate only, resume and repair
  turns verified); classifier + retry wordings; hardcoded-codex sites; two-entry roster pattern
  for a weighty Gemini model; read-only enforced by the tree check (F12) with a failed run on a
  changed tree; the recovery record names the events file (both engines); exactly one result.
  Wontfix: F05-3 (account not observable locally -> TECH_DEBT T7), F05-5 (two entries instead of
  `weighty_model`), local `-NativeEffort` conflict check.
- Ratings: n=1 yes (7 findings, 6 adopted, RC1 confirmed F12), n=2 yes (F05-2 and F05-1 adopted;
  the blocker verdict overstated - the codex path has the same shape and the events file is
  written by the process itself). Gemini (not in the ledger): yes - confirmed A1/A2/A3 and the
  F11 remedy from the inside; its hook point duplicated GLM's.
- Cost of the round: ZAI 2.3M tokens in (2.2M cached), MiMo similar; agy 24k + 66k (the resume
  replays the conversation: 54k input) + RC1 probes 3 x ~27k.

## Round 2 - wave 17 built, reviewed and live-tested (2026-09-25 12:00-15:10)

- Wave 17 (Opus worker, brief = handoff 06; the worker hit its session limit once and was resumed):
  engine table, roster `engine`, `-Engine`/`-EngineExe`/`-DenialRetry`, stdin stream-json, events
  parser, failure rules, denial retry, tree check, `-NoNetwork` hook, classifier, `tests/fake-agy.*`,
  `tests/harness-engines.ps1` 81; existing counts unchanged (5.1: 227/113/37/26/45/11/12; pwsh:
  227/113/37/81); docs, CHANGELOG [0.4.0] wave 17, ROADMAP R10, TECH_DEBT T7, version 0.4.0.
- Live, through the new bridge (scratch roster via CODEX_CONSULT_ROSTER; the user's roster keeps no
  `engine` field until the installed plugin is 0.4.0, because the installed 0.3.0 would refuse it):
  - n=3 `07-agy-smoke`: first real run (gemini-3.8-flash-low, checkpoint, no brief): exit 0,
    structured on the first turn, 118 s, 17k tokens.
  - Panel `2d8d5f25` (`-Panel -Purpose diff-review`, brief 08): 3 of 5 entries ran - n=4 `ZAI ::
    glm-5.3` ACCEPT (F09-1 major, F09-2 minor, F09-3 note; 673 s), n=5 `mimo :: mimo-v2.6-pro` HOLD
    (F10-1 major, F10-2/3 minor; 391 s), n=6 `gemini :: gemini-3.8-flash-high [agy]` ACCEPT, 0
    findings (605 s; usage 1.6M input + 5.9M cached - a flash diff review reads the tree); openai
    skipped (usage limit), gemini pro skipped (weighty, light purpose). All ten round-1 findings
    confirmed `fixed` by their authors from the code (ZAI ran the parser on the real streams).
  - n=7 `12-agy-resume-check`: `-Mode resume -Thread` of n=3's conversation: same conversation id
    back, the model quoted the previous consultation id verbatim.
  - n=8 `13-agy-denial-check`: asked to run `git --version`; the tools line held, the model refused
    and filed RC1; F11 did not fire live (the retry path stays verified by the harness and by the
    round-1 manual turn). Its first attempt was REFUSED by the preflight: "`agy models` did not
    finish within 15 s" - measured afterwards 1.7 / 7.7 / 13.8 s -> **F13** (judge): timeout 45 s
    and a ledger short-circuit (a usable agy reply on the endpoint within 60 min = signed in).
  - Hook with an agy roster entry: `gemini not checked (launcher present)`, 2.5 s, no network.
- Judge's verdict on the panel: ACCEPT with fixes. Wave 18 (worker brief in the scratchpad):
  collab-root snapshot for the tree check + explicit residual (F09-1/F10-1), retry event paths in
  the ledger (F09-2), wording (F09-3), trailing garbage on exit 0 (F10-2), non-unique label warning
  (F10-3), F13. Ratings: n=4 yes, n=5 yes, n=6 partly (nothing new, costly), n=3/7/8 partly
  (operational checks).

## Round 3 - wave 18 (fixes after the panel) and the judge's acceptance of the candidate (2026-09-25 15:30-16:30)

- Wave 18 (Opus worker, brief = handoff 14; resumed once after a session limit): collab-root
  snapshot for the agy tree check with the residual stated (T8), `events` in `denial_retry` /
  `format_retry`, "changed during the run (by the reviewer or anyone else)", `Read-AgyEvents
  -AllowPartialLast` only after a kill or a non-zero exit, the non-unique-label warning, F13 (45 s
  `agy models` timeout + the 60-minute ledger short-circuit "signed in (usable reply <m> min ago)").
  harness-engines 95 (+14), every other count unchanged on 5.1 and pwsh; CHANGELOG wave 18 + live
  evidence; `claude plugin validate` passes.
- Judge's decisions on the worker's two open points: (1) the 60-minute shortcut applies under
  `-NoNetwork` too (it reads only the ledger), so the hook may say `gemini available` after a
  recent agy run - accepted; (2) another task's consultation running in the same repo during an
  agy run trips the collab snapshot and fails the agy run - accepted for 0.4.0 (documented, T8);
  R11 (parallel panel) must exclude sibling members' files from the snapshot.
- Live after wave 18: hook with the scratch roster 2.3 s, `gemini not checked (launcher present)`;
  dry run `-Provider gemini` picks roster entry 4 (flash-high), warns about the non-unique label,
  preflight `signed in (14 models)`, sandbox text with the residual.
- F09-1..3, F10-1..3 -> implemented (their authors' confirmation comes with the next panel; the
  openai reviewer's acceptance of 0.3.0 AND 0.4.0 is due after its reset on 2026-09-28 20:35).
- Next: commit + push as the 0.4.0 candidate; update the installed plugin; add the two gemini
  entries to the user's roster (only after the update - the installed 0.3.0 would refuse the
  `engine` field).
