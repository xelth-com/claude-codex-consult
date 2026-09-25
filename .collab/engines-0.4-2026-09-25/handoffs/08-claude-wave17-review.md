# Handoff 08 - Claude: diff review of wave 17 (the `agy` engine, ROADMAP R10)

Date: 2026-09-25. Base commit: `a320844` + the uncommitted wave 17 (the working tree you are reading).
Panel consultation; for the roster members this is also the first consultation carried by the NEW
bridge code, and for the Gemini member it is the first review carried by the engine under review.
Your findings from round 1 (F02-*, F05-*) are listed as prior findings with status `implemented`:
confirm or refute each from the code, not from the amendments text.

## What changed (read these; the design and the judge's decisions are handoffs 01 and 06)

- `plugins/codex-consult/scripts/codex-consult-common.ps1`: an engine table (`codex`, `agy`) with
  the launcher names, handoff prefix, label, command word, supported modes/sandboxes; agy adapter
  functions (argv, the NDJSON stdin line, the events parser: last `result` event, `init` id must
  equal it, exactly one result, conversation-id rules of A12); engine-aware identity (HostName
  `engine:agy`, compat `cc-engine-v1|agy`), roster (`engine` field: model required, codex_config /
  auth refused, one label -> one engine), roster walks, panel members, preflight (`agy models`, 15 s,
  cached per listing), classifier (`permission` class first; Google codes), `Get-RetryAfter`
  (`retry in 32s`, `1m5.3s`, gRPC `retryDelay`), the pending record (`events` path, the CLI's
  name), the process rule (the recorded launcher's file name), tree-diff helpers (A17).
- `plugins/codex-consult/scripts/codex-consult.ps1`: `-Engine codex|agy`, `-EngineExe`,
  `-DenialRetry 0|1`; refusals for agy (`-Mode fork`, `-Sandbox workspace-write`, `-CodexConfig`,
  `-SchemaTransport output-schema`); argv `agy -p= --input-format stream-json --output-format
  stream-json --model <m> --json-schema <schema> --print-timeout 0 --sandbox
  --disable-slash-commands [--conversation <thread>]`, the prompt as ONE NDJSON line on stdin, the
  tools line ("never call run_command, make NO file changes") after the ask; parse and failure
  rules (A2, A12, A19); the denial retry (A3: one `--conversation` turn after the F11 "no output
  produced" case; `.denial-retry.events.jsonl` kept); the format repair on `--conversation`
  with the id verified after it; the tree check that FAILS an agy run whose tree or handoffs
  directory changed (class `permission`); ledger fields `reviewer.engine`, `warnings[]`,
  `denial_retry` (after `format_retry`), `sandbox` text; the header/author/command word from the
  engine table; `[agy]` in lineage displays; the engine-aware panel.
- `codex-providers.ps1` (agy rows from the roster, `engine` in JSON, `-NoNetwork`, `-EngineExe`),
  `codex-consult-hook.ps1` (`-NoNetwork`; prints `<label> not checked (launcher present)`),
  `codex-scoreboard.ps1` / `codex-findings.ps1` (`[agy]` lineage).
- `tests/fake-agy.cmd` + `tests/fake-agy.ps1`, `tests/harness-engines.ps1` (81 assertions: UNIT,
  ROSTER, DRYRUN, RUN, RESUME, DENIAL, FAIL, PROSE, TREE, TIMEOUT/RECOVER, PANEL, LISTING incl. the
  hook, SCOREBOARD); `tests/run-all.ps1`, `tests/README.md`; two pinned field lists updated in
  `tests/harness-0.3.ps1` and `tests/harness-format.ps1` (counts unchanged: 227 / 113 / 37 / 26 /
  45 / 11 / 12 on 5.1; 227 / 113 / 37 / 81 on pwsh).
- Docs: README ("Engines" section, ledger, roster, preflight, listing, options, hook, tests),
  `skills/setup-providers/SKILL.md` (agy: install, the USER signs in, `agy models`, roster entries,
  cost), `skills/consult-codex/SKILL.md`, CHANGELOG [0.4.0] wave 17, ROADMAP R10 status, TECH_DEBT
  T7 (an agy lineage does not bind the signed-in account), `examples/codex-consult-roster.json`;
  version 0.4.0 in `plugin.json` and `marketplace.json`.
- Live evidence in this task: handoff 07 (`07-agy-smoke.md`, ledger n=3) is the first real run of
  the engine (gemini-3.8-flash-low, checkpoint, no brief): exit 0, structured reply on the first
  turn, prior findings tracked. Round-1 facts F11 (a denied tool call ends the run with an empty
  SUCCESS) and F12 (`--sandbox` does not block writes, `--mode plan` changes nothing) are in
  `state.md`.

## CURRENT invariants claimed

- Nothing changes for a codex reviewer: same argv, same events, same ledger apart from three new
  fields (`reviewer.engine` = "codex", `warnings` = [], `denial_retry` = null); every existing
  harness keeps its count.
- Preflight fails closed for agy too: no launcher / no sign-in / recorded auth failure / usage
  limit with a reset time -> refused before anything is locked; the hook never touches the network.
- A thread belongs to one reviewer on one endpoint: the agy fingerprint keeps codex and agy
  lineages apart; a resume whose conversation id does not come back is a failed run; a repair or
  denial turn is verified the same way; a new conversation started by agy is never a parent.
- Nothing already written is lost: the events file holds the reply and the recovery record names
  it; `structured_output` is written to `.reply.json` before validation.
- Read-only is enforced by evidence, not by agy: a changed tree or handoffs directory fails the run.

## Questions (answer by number, under 700 words)

- **Q1.** Read the agy events parser and the failure rules: name one real agy stream (from F3 /
  handoff 04 attempt 1 / handoff 07 events) that the rules misjudge - a failed run ingested, or a
  usable reply failed. Check the "exactly one result" and the `init` = `result` id rules against
  the real files in this task's handoffs.
- **Q2.** The denial retry (A3): read the trigger condition and the prompt it sends. Can it fire on
  a run that was NOT the F11 case (e.g. a tree-check failure, a quota error) or loop? Is the
  original empty result recorded so the retry's provenance is visible?
- **Q3.** The tree check (A17): what does it compare, and what can a writing reviewer change that it
  does not see (files outside the repo, the collab root, ignored files)? Is failing the run the
  right severity when the reply is otherwise valid?
- **Q4.** Codex path regression: diff the codex argv, prompt and ledger of a codex run before and
  after this wave (the harnesses claim identity). Name any codex-visible change beyond the three
  new fields.
- **Q5.** The hook and the listing (A4): with an agy roster entry, what does the hook line say, what
  does `codex-providers.ps1` (without -NoNetwork) say, and can the roster walk in the hook pick an
  agy entry it never checked?
- **Q6.** Roster and lineage: two entries with the same label `gemini` and different models (the
  documented weighty pattern) - trace `-Provider gemini` without `-Model`, `-Panel` on a light and
  on a weighty purpose, and `-Thread` of a gemini thread. Any ambiguity or a wrong entry?
- **Q7.** Docs for the installing agent: does the README "Engines" section + setup-providers give
  an agent on a fresh machine everything to wire Gemini (install, sign-in by the user, roster,
  verification command, expected output, the cost note, F11/F12 caveats) without guessing?
- **Q8.** Verdict on the wave as an 0.4.0 candidate: ACCEPT, HOLD or REJECT, and the one check you
  would run first on the live acceptance.
