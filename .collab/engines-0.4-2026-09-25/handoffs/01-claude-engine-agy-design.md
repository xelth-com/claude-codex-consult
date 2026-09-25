# Handoff 01 - Claude: design of the `agy` engine (ROADMAP R10, first engine besides Codex)

Date: 2026-09-25. Base commit: `7f46fe4` (0.3.0 candidate, nothing uncommitted). Panel consultation
before anything is built. Purpose: framing. Every design point below is a PROPOSAL; the facts marked
"verified" were observed on this machine today with Antigravity CLI `agy` 1.2.11 (Windows 11).

## Why

Every reviewer is reached through `codex exec` today, whose only structured-output path is the
Responses-API `json_schema` response format: ignored by some third-party endpoints, rejected by
others (hence the contract-first prompt and the format-repair turn of 0.3.0). Google's Antigravity
CLI (`agy`) is the official headless client of the Gemini models under the user's Google AI Pro plan
and enforces a JSON schema natively (`--json-schema`). R10 adds a roster field `engine` so that a
roster entry can name which CLI carries the consultation; the ledger, findings, panel, scoreboard,
preflight and recovery record stay the same. This wave builds the `agy` engine only; the `claude`
engine (Claude Code headless for GLM / MiMo routes) is the next wave and must fit the same adapter.

## Facts verified today (agy 1.2.11)

- F1. `agy -p <text>` puts the prompt in argv (no stdin). `agy -p= --input-format stream-json
  --output-format stream-json ...` reads ONE NDJSON line `{"event":"user","message":{"content":
  "<prompt>"}}` from stdin, runs one turn and exits 0 when stdin is closed. The empty `-p=` is
  required to enter print mode; `--print` alone swallows the next argument as the prompt.
- F2. Through stdin a prompt containing `"`, `\`, `%APPDATA%` came back byte for byte (echo test);
  argv on Windows has the 32 KB command-line limit and cmd-style quoting, stdin has neither.
- F3. stdout with `--output-format stream-json` is JSONL: `init` {conversation_id, model, cwd, tools,
  permission_mode "request-review", json_schema}, `step_update` {... usage ...}, and one `result`
  {conversation_id, status, response, error?, duration_seconds, num_turns, structured_output?,
  usage {input_tokens, output_tokens, thinking_tokens, cache_read_tokens, total_tokens}}. With
  `--output-format json` the same `result` object is the whole stdout. Status values documented:
  SUCCESS, ERROR, CANCELED, INTERRUPTED, INVALID, WAITING, RUNNING.
- F4. `structured_output` is the schema-conforming object; the `response` text of the same run
  carried two extra keys (`toolAction`, `toolSummary`) - the text is not the object.
- F5. `--effort max` with `--model gemini-3.8-flash-low` fails before any call: status ERROR,
  `error: invalid model selection (...) --model gemini-3.8-flash-low conflicts with --effort=max`,
  exit 1. The reasoning tier is part of the model id (`gemini-3.8-flash-{high,medium,low}`,
  `gemini-3.1-pro-{high,low}`).
- F6. `--conversation <unknown id>` prints `warning: conversation "<id>" not found` on stderr and
  starts a NEW conversation; exit 0; the result's conversation_id is the new one.
- F7. `--print-timeout 20s` on a running turn printed `[agy] print timeout after 20s with turn in
  progress; returning partial output` and a result with status SUCCESS and an empty response.
  The docs say a run waits five minutes by default; `--help` says `0` waits until the turn completes.
- F8. `--sandbox` (terminal restrictions) still lets the model read a file in the working directory;
  print mode has no permission prompt: a tool that needs approval is "soft-denied: the run continues,
  exits 0, and prints a notice" (docs).
- F9. Credentials live in the OS keyring (Windows Credential Manager) after an interactive login;
  no `agy` target is visible through `cmdkey /list`; there is no `auth status` subcommand.
  `agy models` fetches the model list over the network in about 2.3 s and exits 0 when signed in.
- F10. The launcher is a native `agy.exe` (winget package `Google.AntigravityCLI`, also the official
  installer under `%LOCALAPPDATA%\agy\bin`), not a cmd/npm shim.

## Proposed design (D1-D12)

- **D1 Roster and CLI.** Roster entry field `engine`: `"codex"` (default, current behaviour) or
  `"agy"`. For `agy`: `model` required (the full id including its tier); `codex_config` and `auth`
  refused; one provider label maps to exactly one engine across the roster (the label is free text,
  e.g. `gemini`; it is the lineage's provider). Bridge parameter `-Engine codex|agy` (default: the
  roster entry's engine, else codex); with `-Engine agy` and no roster entry, `-Provider` is the
  label (default `gemini`) and `-Model` is required. `-EngineExe` / env `CODEX_CONSULT_AGY_EXE`
  override the launcher (`agy.exe` on PATH otherwise; a missing launcher is `unknown`, refused).
- **D2 Invocation.** `agy -p= --input-format stream-json --output-format stream-json --model <model>
  --json-schema <plugin>/schemas/consult-reply.schema.json --print-timeout 0 --sandbox
  --disable-slash-commands [--conversation <thread>]`, from the repository root, the prompt as one
  NDJSON line on stdin (F1, F2). `--print-timeout 0` is pinned because an agy-side timeout looks like
  success (F7): the bridge's `-TimeoutSec` process-tree kill stays the only timeout. `--effort` is
  never sent (F5): the ledger records `effort_requested` as today, `effort_sent` null,
  `effort_mapping` "model-tier", basis "caps-v1: engine agy, the tier is part of the model id";
  `-NativeEffort <v>` sends `--effort <v>` verbatim and agy's own conflict check applies.
  `--sandbox` always; `-Sandbox workspace-write` is refused for agy (reviews are read-only; F8).
- **D3 Output.** stdout is saved as `handoffs/NN-agy-<slug>.events.jsonl`, stderr as today. The
  reply object is `result.structured_output` (never `response`, F4); when it is absent the
  `response` text goes through the prose gate and the format repair exactly as a codex reply does.
  A run is failed when the exit code is not 0, `result.status` is not SUCCESS, there is no `result`
  event, or both `structured_output` and `response` are empty; `provider_failure` is classified
  from `result.error` + stderr with the current classifier plus Google's wording
  (RESOURCE_EXHAUSTED / "quota" / 429 -> quota, with "retry in 32s"-style durations parsed into
  `retry_after`; PERMISSION_DENIED / UNAUTHENTICATED / "not signed in" -> auth). A `warning:` or
  soft-denial notice on stderr becomes a ledger warning, never a refusal. Usage: input_tokens,
  cache_read_tokens -> cached_input_tokens, output_tokens, thinking_tokens ->
  reasoning_output_tokens, total_tokens.
- **D4 Threads.** `thread` = `result.conversation_id` (`thread_source` "events"). Modes: `new` and
  `resume` (`--conversation <thread>`); `fork` is refused for agy (the CLI has no fork). Default
  mode for agy: `resume` when a thread of the lineage exists, else `new`. On resume the result's
  conversation_id MUST equal the parent; otherwise (F6) the run is recorded as failed
  (`bridge_outcome` "failed: parent conversation <id> not found, agy started <new id>"), the
  reply text is kept as a file and named in the entry, nothing is ingested, and the new
  conversation is never a parent.
- **D5 Identity and lineage.** `reviewer` gains `engine` ("codex" when absent in older entries);
  for agy: provider = the label, model, `provider_fingerprint` = sha256("cc-engine-v1|agy"),
  `provider_config` {engine, launcher, cli_version?}. Parents need the same provider, model AND
  fingerprint, so a codex thread and an agy thread never mix. `Format-Lineage` unchanged
  (`gemini :: gemini-3.8-flash-high`); listings that show the lineage add ` [agy]` for a non-codex
  engine.
- **D6 Preflight.** Launcher present; credential = `agy models` (exit 0 and at least one
  `<id>\t<name>` line -> ok "signed in (N models)"; output mentioning login / sign in / auth ->
  missing; no answer within 15 s -> unknown), cached per listing like `codex login status`;
  endpoint health by fingerprint as today (auth failure <= 24 h, usage limit with a reset time).
  This is ONE network round-trip (~2 s); the hook and `codex-providers.ps1` currently promise "no
  network call" - the promise would become "no network call for codex providers; one `agy models`
  call per agy engine".
- **D7 Schema transport.** New value `native` (the schema is passed as `--json-schema`; the prompt
  says "matching the output schema you were given", as for output-schema). `-SchemaTransport`
  accepts native | prompt-only for agy, output-schema | prompt-only for codex. The format-repair
  turn for agy is `--conversation <thread>` with the same repair prompt and `--json-schema`.
- **D8 Panel.** A member with engine agy runs like any member (child bridge process; `-PanelSpec`
  carries the engine); handoff `NN-agy-<ReplyName>-<provider>.md`; ledger `command` starts with
  `agy `. Findings, ratings and the scoreboard are keyed as today (lineage, purpose).
- **D9 Listing and hook.** `codex-providers.ps1` gets one row per engine provider label declared in
  the roster: kind `engine agy`, endpoint `agy (<launcher>)`, table `n/a`, credentials (D6), effort
  `agy (tier in the model id)`, schema transport `native`, health, roster columns, verdict; JSON
  rows gain `engine`. Without a roster there are no engine rows. The hook line lists them like any
  provider (`gemini available`).
- **D10 Tests.** `tests/fake-agy.ps1` + `fake-agy.cmd` (scripted init / step_update / result events
  from `FAKE_AGY_*` variables: reply object file, STATUS + error text, CONVERSATION=notfound,
  MODELS=out|hang, HANG, EXIT, LOG of argv and stdin) and `tests/harness-engines.ps1`: roster
  validation (each refusal), dry-run argv, a full run's ledger fields, resume matched / not found,
  each failure class with `retry_after`, a prose reply repaired through `--conversation`, the
  timeout kill, a mixed panel (codex + agy members), providers listing and hook rows, scoreboard
  rows. A `.cmd` fake cannot carry `%VAR%` (cmd expands it) - covered by today's live probe (F2).
- **D11 Docs and version.** README (engines section, roster field, agy setup), setup-providers
  skill (winget / official installer, the USER runs `agy` once interactively to sign in - the
  bridge never handles a login, `agy models` as the check), consult-codex skill, CHANGELOG
  [0.4.0] wave 17, ROADMAP R10 (agy shipped, claude next), examples roster; plugin version 0.4.0
  candidate.
- **D12 Non-goals of this wave.** The `claude` engine; `GEMINI_API_KEY` mode (not the user's plan;
  the plan terms allow only the official clients); multi-turn stream-json input; `--add-dir`,
  projects, `--continue`.

## CURRENT invariants (0.3.0) the design must keep

- Preflight fails closed; nothing is locked or started for an unavailable or unknown reviewer.
- A thread belongs to one reviewer on one endpoint; legacy entries are never parents.
- Nothing already written is silently lost (a usable reply is always named by the ledger or the
  recovery record); one atomic rename per store write.
- A panel's exit code is 0 only when every member produced a usable reply.

## Questions (answer by number, under 900 words)

- **Q1.** stdin stream-json (D2) versus `-p <text>` argv: name a reason to prefer argv, or a risk of
  the stream path (e.g. a run where the `result` event lacks `structured_output` although the
  schema was honoured, or print-mode differences between the two paths).
- **Q2.** Effort (D2): is "record requested, send nothing, mapping model-tier" right, or should
  the bridge map its effort onto a tier suffix (rejected here because the model id is the
  lineage)? Is the roster's `panel: weighty` enough to route weighty asks to `gemini-3.1-pro-high`?
- **Q3.** Resume mismatch (D4, F6): fail closed as proposed, or ingest the reply flagged as a new
  conversation? Give the failure that each choice hides.
- **Q4.** Default mode `resume` for agy (no fork): the conversation grows with every consultation
  of the lineage. Better default `new` with `-Mode resume` opt-in? What does each cost the judge?
- **Q5.** Credential check by `agy models` (D6): acceptable network call in the preflight and the
  hook, or should the hook skip it and print "gemini: not checked"? Any local, network-free
  evidence of a signed-in agy you know of?
- **Q6.** Failure classification (D3): which agy / Google error texts must map to quota, auth,
  capability, transport; which retry wordings should `Get-RetryAfter` learn?
- **Q7.** Verification of a usable agy reply (D3): are "exit 0 + status SUCCESS + structured_output
  object + conversation_id uuid" the right conditions? Which stderr notices (soft-denial,
  conversation not found, partial output) must fail the run rather than warn?
- **Q8.** Handoff naming `NN-agy-<slug>` (D3/D8): anything in findings, `-List`, `-Stats` or the
  scoreboard that assumes `codex` in file names or in `command`?
- **Q9.** Tests (D10): which case would you add first; how would you test quoting through a fake
  when the fake is a `.cmd` shim?
- **Q10.** Which of D1-D12 breaks a listed invariant, or a 0.3.0 behaviour you rely on?
