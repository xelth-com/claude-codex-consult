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
