# Handoff 06 - Claude: worker brief for the `agy` engine (ROADMAP R10), amended after round 1

Repository: C:\Users\Dmytro\claude-codex-consult (branch main, base 7f46fe4, tree clean apart from
.collab/engines-0.4-2026-09-25/ which you must not touch). Plugin: plugins/codex-consult/.

Read first (in this order): .collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md
(facts F1-F10, design D1-D12), then the panel replies 02-codex-engine-design-ZAI.md,
03-codex-engine-design-mimo.md and 04-agy-engine-design.md, then the "Amendments" section at the end
of this brief (the judge's decisions - they override D1-D12 where they differ). Then
plugins/codex-consult/scripts/codex-consult.ps1 (the run block: prompt assembly ~1340-1470, launch
~1640-1700, parse ~1700-1830, format repair ~1835-1900, ledger record), codex-consult-common.ps1
(Resolve-ReviewerIdentity 2150, caps-v1 2362-2460, Resolve-CodexLauncher / Get-CodexLoginStatus /
Get-ProviderCredential 2653-2770, roster 3146-3330, Select-PanelMembers 3393, parent threads 3444-
3640), codex-providers.ps1, codex-consult-hook.ps1, codex-scoreboard.ps1, codex-findings.ps1,
tests/README.md, tests/fake-codex3.ps1 + .cmd, tests/harness-roster.ps1 (the harness style).

## Objective

A roster entry `{ "provider": "gemini", "engine": "agy", "model": "gemini-3.8-flash-high" }` (and the
CLI form `-Engine agy -Provider gemini -Model gemini-3.8-flash-high`) consults Gemini through the
Antigravity CLI `agy` with the SAME ledger, handoff files, findings, ratings, panel, scoreboard,
preflight, lock and recovery record as a codex reviewer. Nothing changes for codex reviewers
(every existing harness keeps its count). The engine is table-driven so that a `claude` engine
(Claude Code headless, next wave) can be added as a second row without touching the run block again.

## Hard constraints

- NEVER call a real model or the real `agy`/`codex` CLI from tests; the harness uses fakes only.
  You may run `agy --help` and `agy models` once to see the surface; you may NOT run `agy -p...`.
  The judge runs the live acceptance.
- Never create, print or paste an API key or token; never handle a login.
- Run harnesses ONE AT A TIME (tests/run-all.ps1 does that); never start a harness while a live
  consultation runs (ask the judge if unsure - none runs while you work).
- No bash `2>nul` (it creates a file named nul). Use PowerShell for everything.
- Keep the plugin generic: no private project names, no personal paths in committed files
  (the fake and harness use $env:TEMP).
- Do not commit. Report the diff summary, the harness counts and what you could not verify.

## Implementation (D1-D12 of the design brief, as amended)

1. Engine table in codex-consult-common.ps1 (`$script:Engines`): one entry per engine with the
   launcher names, the argv builder inputs, the events parser, the credential check, the caps entry
   (vocabulary, schema transport 'native'), the handoff prefix ('agy'), the supported modes
   (new, resume) and sandboxes (read-only). `codex` stays the default and its code path must not
   change behaviour (same argv, same events, same ledger).
2. Roster: field `engine` (codex | agy; anything else refused with the allowed list); for agy:
   model required, codex_config and auth refused, one provider label -> one engine across the
   roster; the entry object gains Engine; Find-RosterEntry / Select-RosterReviewer /
   Select-PanelMembers / -PanelSpec carry it; ledger roster.skipped/applied entries gain engine.
3. Bridge parameters: `-Engine` (codex | agy; default from the roster entry, else codex),
   `-EngineExe` (+ env CODEX_CONSULT_AGY_EXE). `-Sandbox workspace-write`, `-Mode fork`,
   `-CodexConfig`, `-SchemaTransport output-schema` are refused for agy with one clear message each.
4. Identity: Resolve-ReviewerIdentity gets an engine branch (no Codex config lookup): Provider =
   label, Model = required, HostName = 'engine:agy', CompatString 'cc-engine-v1|agy', Fingerprint
   its sha256, ProviderConfig { engine, launcher }, Display 'engine agy (<launcher>)'. reviewer
   record gains `engine` (also written as "codex" for codex runs from now on; readers treat an
   absent field as codex).
5. Invocation (D2): `-p=` `--input-format stream-json` `--output-format stream-json` `--model <m>`
   `--json-schema <schema>` (structured mode; prompt-only transport omits it) `--print-timeout 0`
   `--sandbox` `--disable-slash-commands` [`--conversation <thread>`] [`--effort <v>` only with
   -NativeEffort]; stdin = ONE NDJSON line {"event":"user","message":{"content":"<prompt>"}} + "\n"
   written UTF-8 without BOM to the prompt file the bridge already redirects; working directory =
   repo root; Start-Process exactly as for codex (same pending record, kill, survivors).
   The ledger `command` is the argv rendered by Format-Argv with 'agy' first.
6. Parse (D3): events file = handoffs/NN-agy-<slug>.events.jsonl; the LAST `result` event gives
   status, conversation_id, response, error, usage, structured_output. Reply object =
   structured_output (serialised compact, then through the existing validation exactly like a codex
   reply: Test-StructuredReply etc.); absent -> rawReply = response text -> prose gate / format
   repair. Failure rules and provider_failure classification per D3 + amendments; usage mapping per
   D3; stderr `warning:`/soft-denial lines -> ledger `warnings[]` (new field only for agy? -> see
   amendments).
7. Threads (D4): thread = result.conversation_id when it is a uuid; thread_source 'events'; resume
   mismatch rule per amendments; Select-ParentThread unchanged (fingerprint keeps engines apart).
8. Effort (D2): effort_sent null, effort_mapping 'model-tier', effort_basis text; caps-v1 gains an
   engine entry so Resolve-EffortPlan and Get-SchemaTransport answer for HostName 'engine:agy'.
9. Format repair (D7): `--conversation <thread>` + the same repair prompt as stdin NDJSON +
   `--json-schema`; everything else (timeouts, original kept, drift notes, ledger format_retry) as
   for codex.
10. Preflight (D6, amended): launcher (Get-Command agy.exe / agy; -EngineExe / env), credential =
    `agy models` with a 15 s timeout (ok: exit 0 and >= 1 line matching '^\S+\t'; missing: text
    matching login|sign in|auth|unauthenticated; unknown otherwise), cached per listing; health by
    fingerprint unchanged.
11. codex-providers.ps1 (D9): engine rows from the roster; JSON rows gain `engine`; the hook line
    unchanged in form. codex-scoreboard.ps1 and codex-findings.ps1 -Stats/-List: lineage shows
    ' [agy]' for engine != codex; nothing assumes 'codex' in file names (verify; fix if it does).
12. Tests: tests/fake-agy.ps1 + tests/fake-agy.cmd (FAKE_AGY_REPLY=<json file with the object>,
    FAKE_AGY_STATUS=SUCCESS|ERROR|..., FAKE_AGY_ERROR=<text>, FAKE_AGY_STDERR=<text>,
    FAKE_AGY_CONVERSATION=notfound (warning + new id) | <uuid> (echo the requested one),
    FAKE_AGY_MODELS=ok|out|hang, FAKE_AGY_HANG=1, FAKE_AGY_EXIT=<n>, FAKE_AGY_LOG=<path> (argv +
    stdin), FAKE_AGY_NOSTRUCTURED=1 (result with response text only), FAKE_AGY_PIDFILE); the fake
    prints init / step_update / result events shaped exactly like F3 of the design brief.
    tests/harness-engines.ps1 with sections (each PASS/FAIL line with evidence, `-Only` support,
    scratch dirs under $env:TEMP\codex-consult-tests\harness-engines\<guid>, CODEX_HOME and
    CODEX_CONSULT_ROSTER pointed at scratch files, CODEX_CONSULT_AGY_EXE at the fake, CODEX_CONSULT_EXE
    at fake-codex3.cmd for the mixed panel): ROSTER (validation refusals: unknown engine, agy without
    model, agy with codex_config, agy with auth none, one label two engines, a valid mixed roster),
    DRYRUN (argv shape, no --effort, --effort with -NativeEffort, --conversation on resume, fork
    refused, workspace-write refused, -SchemaTransport prompt-only omits --json-schema and puts the
    schema in the prompt, output-schema refused), RUN (full fake run: ledger fields engine /
    fingerprint / thread / usage mapping / schema_transport native / handoff names / command starts
    with agy / findings ingested), RESUME (matched conversation id; not found -> the amended rule),
    FAIL (ERROR status with auth text -> provider_failure.class auth; quota text with "retry in 32s"
    -> quota + retry_after; transport; exit != 0; no result event; empty reply), PROSE (response
    text only -> prose gate -> repair turn via --conversation, drift notes; FormatRetry 0), TIMEOUT
    (hang -> tree killed, ledger timeout outcome, no survivors), PANEL (mixed roster codex + agy:
    both members run, handoff names, panel summary, exit code), LISTING (codex-providers.ps1 rows
    and -Json engine field; the hook line names the agy provider), SCOREBOARD (rows show [agy]).
    Add the harness to tests/run-all.ps1 and tests/README.md. Run harness-engines on 5.1 and pwsh;
    then run-all.ps1 once on 5.1 (all harnesses, one at a time) and report every count.
13. Docs (a separate sonnet-worker may do these after you report; do them yourself if time
    allows): README (a new "Engines" section under the roster section + the agy setup + the
    listing columns), skills/setup-providers/SKILL.md (agy install: winget Google.AntigravityCLI or
    the official installer; the USER signs in by running `agy` once; `agy models` as the check;
    the roster entry), skills/consult-codex/SKILL.md (engine mention where -Provider is explained),
    CHANGELOG [0.4.0] wave 17, ROADMAP R10 status, TECH_DEBT if anything is left, examples/
    codex-consult-roster.json (+ a gemini entry), plugin.json + marketplace.json version 0.4.0.

## Acceptance (what the judge checks)

- `powershell -File tests/run-all.ps1`: every existing count unchanged (harness-0.3 227, roster 113,
  format 37, pending 26, fixes 45, lock2 11, 3b 12) + harness-engines N; pwsh: 0.3 / roster / format /
  engines pass.
- Dry run: `codex-consult.ps1 -Task x -DryRun -Engine agy -Provider gemini -Model gemini-3.8-flash-high
  -Prompt "..."` prints the argv of D2 and the identity/preflight lines.
- Live (judge): a real consultation with the user's roster (a gemini entry appended) and a panel.
- `claude plugin validate .` passes.

## Amendments after the panel (the judge's decisions; they override D1-D12 where they differ)

New fact **F11** (observed twice today, handoff 04 attempt 1): when the model calls a tool that needs a
permission print mode cannot grant (it ran `run_command agy --version`), agy ends the run with exit 0,
status SUCCESS, an EMPTY response, no structured_output and this stderr line:
`jetski: no output produced — a tool required the "command" permission that headless mode cannot
prompt for, so it was auto-denied. Add an allow-rule under permissions.allow in settings.json (e.g.
command(<target>)). Alternatively, re-run with --dangerously-skip-permissions to auto-approve all tools.`
A second turn on the same conversation (`--conversation <id>`) with "do not run commands, answer from
what you read" then produced the full object (handoff 04 attempt 2: 194 s, 66k tokens).

- **A1 (Q4) Default mode.** For agy the default mode is `new`. `-Mode resume` (or `-Thread`) opts into
  `--conversation <thread>`; `fork` is refused ("the agy engine has no fork; use -Mode resume or new").
- **A2 (Q7, F11) Failed-run rules.** A run is FAILED (bridge_outcome, provider_failure, no ingestion)
  when: exit != 0; no `result` event; result.status != SUCCESS; result has neither a structured_output
  object nor a non-empty response; stderr contains `returning partial output` or `print timeout`
  (partial); stderr contains `no output produced` / `auto-denied` AND the reply is empty
  (class `permission`, new class; message = that stderr line). A denial notice WITH a usable reply is
  ingested with a ledger `warnings[]` entry (new array field, present for every engine, [] when none)
  and a "Warnings" line in the handoff header. `warning: conversation "<id>" not found` on a resume
  -> failed as in D4 (class `unknown`, message = the line).
- **A3 (F11 remedy) Denial retry.** `-DenialRetry 0|1` (default 1; agy only for now): after a run
  failed with class `permission` on a verified conversation id, ONE extra turn `--conversation <id>`
  with the output contract, the sentence "Your previous turn produced no output: the tool <name> was
  auto-denied (headless print mode has no <permission> permission). Do NOT call it again; answer
  from what you have read, as the JSON object.", the field-meaning lines and the consultation id
  (never the brief), `--json-schema`, same timeout rule as the format repair (min(-TimeoutSec, 300)),
  same lock and pending record. A usable result is ingested as the reply; ledger `denial_retry
  {attempted, reason, succeeded, thread, wall_seconds, usage}` (null when not attempted), placed
  after `format_retry`. The tool name comes from the last `step_update` with step_type "tool" in the
  events (`tool_name`), the permission from the stderr line (`"command"`), both optional in the text.
- **A4 (Q5) Sign-in check.** Per-run preflight and `codex-providers.ps1`: `agy models` (network,
  ~2 s, 15 s timeout, cached per listing). The HOOK must not call the network: it runs
  `codex-providers.ps1 -Json -NoNetwork`; with -NoNetwork an agy row's credential text is
  "not checked (launcher present; run codex-providers.ps1)" and its verdict `unknown (sign-in not
  checked)`, the roster walk records it as skipped with that reason, and the hook prints e.g.
  `gemini not checked (launcher present)`; a missing launcher stays `unavailable (agy CLI not
  found on PATH)`; a recorded auth failure / usage limit from the ledgers still shows. Update the
  hook's and the listing's docs: "no network call for codex providers; one `agy models` call per agy
  engine in codex-providers.ps1 and in the preflight; none in the hook".
- **A5 (Q6) Classifier and reset times.** Add to `$script:FailureClassPatterns` (keep the order
  capability, auth, quota, transport; add `permission` FIRST): permission = `no output produced|
  auto-denied|permission that headless mode`; capability += `invalid model selection`; auth +=
  `permission_denied|unauthenticated|not signed in|sign in to`; quota += `resource_exhausted`.
  `Get-RetryAfter` learns `retry in 32s`, `retry in 1m5.3s`, `retry after 2h`, `retry in 90
  seconds` (duration forms with s/m/h and decimals).
- **A6 (Q1) Transport stays stdin stream-json** (F1-F3; verified again in handoff 04 attempt 2 with
  `--conversation`). The `result` event is taken as the LAST event of that kind; nothing is read
  from `response` when `structured_output` is present (F4).
- **A7 (Q8) Naming.** Handoffs `NN-agy-<slug>...`, `command` begins with `agy`. Before writing code,
  grep codex-findings.ps1, codex-scoreboard.ps1, codex-consult.ps1 (recovery / -List messages),
  the skills and the harnesses for `-codex-`, `codex-<`, `'codex '`, `^codex` assumptions and make
  every reader engine-aware (a table `engine -> prefix`); list what you changed in the report.
- **A8 (Q9) Fake.** `fake-agy.cmd` -> `fake-agy.ps1` is fine: the prompt travels on STDIN for agy, so
  cmd's %VAR% expansion never touches it; the fake logs stdin byte for byte (FAKE_AGY_LOG) and the
  harness checks a prompt with `"`, `\`, `%APPDATA%` and a newline. First case to write: F11
  (FAKE_AGY_DENIED=1 -> the stderr line above + result SUCCESS with empty response; then the denial
  retry turn answered from FAKE_AGY_RESUME_REPLY with the same conversation id).
- **A9 Prompt line for agy.** In structured and chore modes the agy prompt gets, right after the
  brief line: "Tools: you may read files of the repository; you have NO permission to run commands
  in this consultation - never call run_command; a check that needs a command belongs under
  `## Requested checks`." (prevents F11 at the source).
- **A10 Effort/tier.** As D2 (effort_sent null, mapping `model-tier`); `panel: weighty` on the
  `gemini-3.1-pro-high` entry routes weighty asks (confirmed by Gemini, Q2).
- **A12 (GLM F02-1, F02-4, F02-7) Conversation-id rules.** `result.conversation_id` is the thread;
  `init.conversation_id` must equal it (mismatch = failed run, class unknown); on a missing `result`
  the init id is recorded as `thread_candidate` only (never a parent, exactly like the rollout
  candidate). In resume mode the run FAILS on any of: the not-found warning, a missing result
  conversation_id, an id different from the parent. The same three checks apply AFTER a format-repair
  or denial-retry turn: a repair whose result id is not the repaired thread (or with the not-found
  warning) is a FAILED repair - the original prose stays the reply of record, nothing from the repair
  is ingested (a fresh conversation has no "last message" to convert and would invent one).
- **A13 (GLM F02-5) Classifier, extended.** quota += `resource_exhausted|rate_limit_exceeded`;
  auth += `unauthenticated|permission_denied|not signed in|login required|sign in to`; capability +=
  `invalid_argument|invalid model selection|conflicts with --effort`; transport += `\bunavailable\b|
  deadline_exceeded` (keep `\b50[234]\b`); permission (new, first) = `no output produced|auto-denied|
  permission that headless mode`. `Get-RetryAfter`: `retry in 32s`, `retry in 1m5.3s`, `retry after
  2h`, `retry in 90 seconds`, and the gRPC payload `"retryDelay":{"seconds":N}` / `retryDelay: 32s`.
  Unit-test every wording in the harness (class AND retry_after).
- **A14 (GLM F02-6) Hardcoded 'codex' sites to parameterise** (found by GLM, verify by grep): the
  format-repair original name `handoffs/NN-codex-<slug>.original.md` (codex-consult.ps1 ~1858), the
  handoff header `# Handoff NN - Codex:` (~2035) -> `# Handoff NN - <Engine label>:` where the label
  is `Codex` / `Gemini (agy)`, `$commandStr = 'codex ' + ...` (~1463), the pending-record notes
  ("codex is being started" etc.), and `Get-CodexRule`'s name rule `^codex(\.exe)?$`
  (codex-consult-common.ps1 ~3838): extend it to the recorded launcher's file name generically (so
  `agy.exe` is found by name AND by the recorded launcher path); always record the resolved launcher
  in the pending record. `-List` / `-Stats` / the scoreboard resolve replies through the ledger's
  `reply` path and the lineage - engine-neutral, keep them so.
- **A15 (GLM Q2) Solo runs on the weighty model.** No new mechanism: a second roster entry with the
  same label and another model (`gemini` / `gemini-3.1-pro-high`, `panel: weighty`) is legal (the
  duplicate rule is provider+model); a solo `-Provider gemini -Model gemini-3.1-pro-high` picks it
  (Find-RosterEntry's exact-model rule). Document it in the README's agy section.
- **A16 (GLM Q1) NDJSON line.** The bridge serialises the prompt itself: one JSON object
  `{"event":"user","message":{"content":"<prompt>"}}` built with ConvertTo-Json -Compress -Depth 5 on
  BOTH hosts (PS 5.1 escapes non-ASCII as \uXXXX - fine), written UTF-8 without BOM, one trailing
  LF; the harness parses the fake's logged stdin as JSON and compares `content` to the composed
  prompt byte for byte.
- **A17 (F12, GLM F02-3, MiMo F05-1) Read-only is NOT enforced by agy.** Verified today (RC1): under
  `--sandbox` the `write_to_file` tool created a file with no prompt and no notice; `--mode plan`
  changes nothing (permission_mode stays request-review; with --disable-slash-commands agy even
  warns "--mode plan has no effect"). So for the agy engine: (a) the prompt line of A9 also says
  "make NO file changes"; (b) the bridge's existing before/after tree fingerprint decides: an agy run
  whose tree changed (tracked or untracked files, `tree_changed`) or whose brief/artifacts changed
  is a FAILED run - `bridge_outcome` "failed: the reviewer changed the working tree (<n> files:
  <list>) - agy's sandbox does not block writes", reply kept and named, nothing ingested, class
  `permission`; (c) additionally list the task's handoffs directory before and after (the collab
  root is outside the tree fingerprint) and treat a new or changed file there the same way; (d)
  README documents F12 and the rule; `sandbox` in the ledger records "read-only (requested;
  enforced by tree check, agy --sandbox restricts the terminal only)".
- **A18 (MiMo F05-2) Nothing lost before the ledger entry.** The events file in handoffs/ is the raw
  artifact and holds the reply (structured_output) for agy; the recovery record must name it: add
  `events` (path) to the pending record when the process is registered (state running), for BOTH
  engines, and every recovery / refusal / -List message about an interrupted run says "the raw
  event stream of that run is at <path> (it may hold a usable reply); no ledger entry was written".
  Keep the current order for agy: save stdout/stderr (done by redirection), extract
  structured_output to `NN-agy-<slug>.reply.json` atomically BEFORE validation, then validate,
  repair, ledger.
- **A19 (MiMo Q7) Exactly one result.** More than one `result` event, a malformed JSONL line inside
  the events (not the last one), or an unparsable result -> failed run (class transport, message
  "malformed event stream: ..."). The conversation id must match the uuid regex (all observed ids
  do); a SUCCESS result whose id is not a uuid fails the run.
- **A20 Decisions recorded as wontfix (do NOT implement):** MiMo F05-3 (bind the Google account into
  the fingerprint - nothing local exposes it; recorded as TECH_DEBT T7: "an agy lineage binds
  engine + label + model, not the signed-in account"); MiMo F05-5 / GLM Q2 `weighty_model` (the
  two-entry pattern of A15 does it without a new field); MiMo Q2 refusing `-NativeEffort` locally
  (agy's own conflict check fails fast and is classified capability).
- **A11 Usage cost note (docs).** Every agy call carries ~13-25k tokens of the CLI's own prompt and
  tools; a resume replays the conversation (attempt 2 above: 54k input). Say so in the README's
  agy section and in setup-providers ("Google AI Pro: quota refreshed every five hours until the
  weekly limit; the CLI cannot show the remaining quota; the bridge records usage per run").
