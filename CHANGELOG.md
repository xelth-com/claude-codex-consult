# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

The first wave of the 0.6.0 candidate: wave 29, the `claude` engine - ROADMAP R10 with R22. Design:
`.collab/claude-engine-2026-09-30/handoffs/01-claude-claude-engine-design.md`; decisions D1-D12 of
`.collab/claude-engine-2026-09-30/handoffs/05-claude-claude-engine-decisions.md`. The plugin and marketplace
manifests are not bumped yet (the version stays 0.5.1 until the release).

### Added

- **The `claude` engine's endpoint mode (wave 29b)** (2026-10-06). A third credential mechanism, `auth: "endpoint"`:
  a roster entry runs Claude Code against a third-party Anthropic-compatible endpoint (a coding plan: z.ai GLM, Xiaomi
  MiMo, Kimi Code). Decisions E1-E7 of
  `.collab/claude-engine-2026-09-30/handoffs/12-claude-claude-engine-endpoint-decisions.md` (D10 reversed for this
  explicit route only; an inherited `ANTHROPIC_BASE_URL`, Bedrock, Vertex and Foundry stay out): E1 the entry key
  `endpoint` `{base_url, env_key, timeout_ms}` and the optional `plan` slug (a roster entry key of every engine); E2 the
  model sent straight as the provider publishes it, proved by the init event (E11: an endpoint entry cannot carry an Anthropic model id - the billing proof); E3 a local preflight (`ok: env <NAME>
  set`, no `claude auth status`, no live request); E4 the child environment (`ANTHROPIC_BASE_URL`,
  `ANTHROPIC_AUTH_TOKEN`, `API_TIMEOUT_MS`, never `ANTHROPIC_API_KEY`; a 401/403 is class auth, a 429 class quota);
  E5 two identities, the route (fingerprint, health) and the plan (a quota failure marks every entry of the plan out);
  E6 telemetry by the base URL's host first for every engine, the `[1m]` strip for every vendor, the vendor class
  `minimax`; E7 the plan as a scheduling group across engines, and `parallel` keys that may name a plan. README
  "Engines (wave 29)" "Endpoint mode", the roster table, the first-run prompt and `setup-providers` step 0 / 3g
  document it (z.ai, MiMo and Kimi Code as examples; Alibaba's plans are not documented for this route - their terms
  say "for interactive AI coding tools (Claude Code, Codex) only - not for backend services"; whether the route stays
  is decided by the wave 29c A/B). harness-claude 75 (its new ENDPOINT category 20 checks, against the fake CLI's endpoint mode).
- **First run: the operator's prompt and the interview** (2026-10-06). The plugin ships no
  subscription, so a fresh installation needs a conversation before a roster. README gains the
  section "First run: the prompt for the operator": one host-agnostic prompt the operator pastes
  into Claude Code, Codex CLI, Z Code, Kimi Code, Qwen Code, OpenCode, Muse Code or a plain shell
  after the install commands (check first, ask which subscriptions the operator holds, wire each
  per its section, the roster, the verification, the record; keys and logins stay the operator's
  own actions). The `setup-providers` skill gains **step 0**: run the checks and the preflight
  first, then ask the operator which of the known plans they hold - ChatGPT plan, z.ai GLM, Xiaomi
  MiMo, Google Antigravity, BytePlus, Kimi Code, Alibaba, Meta Muse Code, another Responses-API
  provider, none - with a table mapping each to its section, and go on to the roster, the
  verification and the record; its description and argument hint say so, and a provider-name
  argument still skips straight to that provider's section. The hook's line for a machine without
  the Codex CLI points at step 0; the plugin's short README names the first-run route.
- **The `claude` engine - Claude Code headless (`claude -p`) as a fourth reviewer engine** beside codex, agy and
  muse, for the Claude subscription or an API key.
  - Roster entry `{ "provider": "anthropic", "engine": "claude", "model": "claude-opus-5-5", "auth":
    "subscription", ... }` or `-Engine claude -Model sonnet` (the label defaults to `anthropic`). `model` is
    REQUIRED and one of the engine's table: the aliases `opus`, `sonnet`, `haiku`, `fable` and the ids
    `claude-fable-5-1`, `claude-fable-5`, `claude-opus-5-5`, `claude-opus-5`, `claude-opus-4-8`,
    `claude-opus-4-7`, `claude-opus-4-6`, `claude-sonnet-5-5`, `claude-sonnet-5`, `claude-sonnet-4-6`,
    `claude-haiku-4-5`, each optionally ending in `[1m]`. Roster `auth` for claude entries only:
    `subscription` (default) or `api-key`; `codex_config` and `auth: none` are refused. Lab: `claude`, `opus`,
    `sonnet`, `haiku`, `fable` prefixes -> `anthropic`. Reply files `NN-claudecode-<slug>.*` (the prefix
    `claude` stays the coordinator's default brief prefix). Modes `new`, `resume` and `fork`; read-only sandbox
    only; schema transport `native` (`--json-schema` with the schema text) or `prompt-only`; a denial retry on
    evidence, as agy.
  - Invocation from the repository root, the prompt on stdin: `claude -p --output-format stream-json --verbose
    --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk
    --model <m> [--effort <e>] [--json-schema <text>] [--max-turns <n>] [--add-dir <dir>...] (--session-id
    <uuid> | --resume <thread> [--fork-session])`. Launcher: `-EngineExe`, `CODEX_CONSULT_CLAUDE_EXE`,
    `claude.exe` / `claude.cmd` / `claude` on PATH, then `%USERPROFILE%\.local\bin\claude.exe`. Harness string
    `claude-cli <ProductVersion>`.
  - Lineage: a new thread's session id is minted by the bridge (`--session-id`); resume sends `--resume
    <thread>` (the same id must come back); fork sends `--resume <parent> --fork-session` (a new uuid); every
    secondary turn (denial retry, format repair, timeout continuation) resumes the thread. A `CLAUDE_CONFIG_DIR`
    or a projects directory inside the repository under review refuses the run.
  - Per-turn proof from every init event: tools only Read, Grep, Glob and StructuredOutput, no MCP server,
    `permissionMode` `dontAsk` (else class `permission`); billing `apiKeySource` `none` for auth
    `subscription`, `ANTHROPIC_API_KEY` set for `api-key` (else class `auth`). Ledger `engine_run` for claude:
    `{turns, max_model_steps, msp_schema_version (null), auth, init_tools, mcp_servers, permission_mode,
    api_key_source, model_resolved, other_models, permission_denials, denied_tools, rate_limit, cost_usd,
    child_env_allowed, switched_off}`; `reviewer.provider_config` gains `credential_mechanism` (the roster
    auth), `auth_method` and `api_provider` (never the account's e-mail or organisation).
  - D4, one resolved model per thread: the roster model goes to `--model` on a new thread, the init event's
    model is the resolved id, and every later turn (secondary turns and later `-Mode resume` / `fork`
    consultations, from the parent entry's `engine_run.model_resolved`) sends that id; the init model and the
    result's `modelUsage` main model must match it (else class `capability`); a second `modelUsage` key is a
    warning; an alias in a run warns that it floats.
  - D2/D3, the child environment is an ALLOW list (system variables, proxy and trust variables, a few prefixes,
    `CLAUDE_CONFIG_DIR`, and `ANTHROPIC_API_KEY` only with auth `api-key`); every other `ANTHROPIC_*` /
    `CLAUDE_*` variable, host marker and test-mode variable is absent, `DISABLE_AUTOUPDATER=1` is set; the SAME
    environment serves the preflight, the version probe and every turn. Ledger `engine_run.child_env_allowed`
    lists names only. Test hook `CODEX_CONSULT_TEST_CHILD_ENV_PASS=<prefix>` (test mode only; never a prefix of
    ANTHROPIC, CLAUDE or CODEX_CONSULT).
  - D1, the STRICT tree check as for agy: any change of the working tree or the collab directory during a claude
    turn fails the run (class `permission`); R22 switches off user, project and local settings, instruction
    files, MCP servers, skills, slash commands, code, web and write tools, the autoupdater
    (`engine_run.switched_off`).
  - Preflight `Get-ClaudeSignIn`: `claude auth status` (local, 15 s, JSON read before the exit code) -> `ok:
    signed in (claude.ai subscription)`; an `authMethod` other than `claude.ai` for a subscription, or an
    `apiProvider` other than `firstParty` (gateway, Bedrock, Vertex, Foundry - D10) is unavailable; `not
    checked` under `-NoNetwork`.
  - D5, the members of the claude engine in one panel run one at a time by default; `"parallel": {"anthropic":
    2}` raises it. D7, the health fingerprint is engine + auth + model family (`cc-engine-v1|claude|<auth>|<family>`).
    D9, a prompt over 1 MiB is refused before the start.
  - Failure classes: not logged in -> `auth`; a rejecting `rate_limit_event` or limit wording -> `quota` with the
    reset time as `retry_after`; `error_max_turns`, `error_max_structured_output_retries`, a model drift -> `capability`;
    a malformed stream -> `transport`. Usage maps `input_tokens` = input + cache read + cache creation;
    `total_cost_usd` stays local as `engine_run.cost_usd`.
  - Coordinator rule (item 9): a Claude Code coordinator sets `CODEX_CONSULT_COORDINATOR="anthropic :: <its model
    id>"`; for a claude reviewer the engine fixes the vendor, compared with `anthropic` whatever the roster label;
    the models after normalising (`[1m]` stripped, an alias equal to any id of its family); a warning, never a
    refusal.
  - Telemetry: vendor class `anthropic` for engine claude; the model is sent only when it equals an entry of the
    model table above (`[1m]` stripped, lower-cased), else `other`.
  - Tests: `tests/fake-claude.cmd` + `tests/fake-claude.ps1` (driven by `FAKE_CLAUDE_*`) and
    `tests/harness-claude.ps1`, registered in `tests/run-all.ps1` as the twenty-first harness; its GUARD section keeps
    the real `claude` from ever starting.

### Changed

- The `-MaxModelSteps` message: `-MaxModelSteps is for an engine with a model-step cap (muse --max-model-steps,
  claude --max-turns); the <engine> engine has none.` (claude sends `--max-turns <n>`).
- The panel's `-MaxModelSteps` refusal: `-MaxModelSteps applies to the members of a panel whose engine has a
  model-step cap (muse --max-model-steps, claude --max-turns); no member of this panel runs such an engine.`
- The `-SchemaTransport` messages now name claude beside agy and muse (`native` for the engines that have it).
- An engine's adapter may name a `LocalCheck` that runs BEFORE the 60-minute ledger short-circuit of the
  sign-in check (claude auth `api-key`: `ANTHROPIC_API_KEY` must be set now - a usable reply an hour ago proves
  nothing about this process's environment), and a `ChildEnv`; the `Outcome` of every engine takes `-Turn` (the
  turn's options: mode, threads, the minted id, the pinned model, the auth - agy and muse ignore it).
- The harnesses that enumerate the engines know claude: `harness-muse` and `harness-engines` (the engine lists of
  the messages), `harness-roster` (two claude refusals), `harness-visibility` (the claude salvage reader),
  `harness-telemetry` (the vendor class `anthropic`, `[1m]`, the README row), `harness-detach` (the claude
  launcher names are kept off its PATH).
- `Hide-HostMarkers` takes `-ChildEnv` (the allow-listed child environment of the claude engine) and a new
  `ConvertTo-CrtArg` quotes an argument by the C runtime rules, because the claude schema text travels in argv.
- Docs: README (the section "Engines (wave 29)", the roster, ledger, effort, options and environment tables, the
  telemetry vendor table, "Tested on" - the live verification is pending), the `setup-providers` skill (section 3g),
  `tests/README.md`.

## [0.5.1] - 2026-10-06

A patch release: the bridge's half of ROADMAP R24. A rating now reaches the telemetry intake, the
marks given before this release can be sent once with `-BackfillRatings`, and the maintainer's page
`/C3/` computes its reviewer-usefulness table from those events (the site's half lives in the site's
repository and is live since 2026-10-06).

### Added

- **R24 (the bridge's half) - a rating reaches the intake.** `codex-findings.ps1 -Rate <n>
  -Useful yes|partly|no`, once the mark is committed and both task locks are released, spools ONE
  anonymised telemetry event of `event_type` `rating` (`severity` `info`, `title` the mark,
  `tags` `[provider, model]`, the consultation event's top level) whose `details` are exactly
  `engine`, `provider`, `model`, `purpose`, `mark`, `age_days`, `bridge_version`, `os`,
  `ps_version` - the vendor class and the closed-list model through the consultation event's own
  code path (`Get-TelemetryReviewerClass`, factored out of `ConvertTo-TelemetryDetails`), never the
  note, the topics, the task, the consultation's id or the roster label - and starts the detached
  sender. It honours `CODEX_CONSULT_TELEMETRY` and the new `codex-findings.ps1 -Telemetry on|off`
  (with `-Rate` only); a telemetry failure warns and is counted, never failing the rating.
  `harness-telemetry` RATE covers it.
- **R24 - the earlier marks, once.** `codex-telemetry.ps1 -BackfillRatings [-DryRun]` sends every
  mark of the current repository's tasks that has no `telemetry_sent` as a `rating` event
  (`client_time` = the mark's `when`; a mark whose ledger entry is missing is skipped and counted)
  and writes `telemetry_sent` (unix seconds) into it, so a second run sends nothing; `-Rate` now
  spools its event at the mark's commit and sets the same field. `harness-telemetry` BACKFILL.

## [0.5.0] - 2026-09-30

The next candidate. Wave 24 (the "operator visibility" wave, ROADMAP T1-T3 and the
availability decisions D14-D17 of the companions design review,
`.collab/companions-2026-09-26/handoffs/05-claude-companions-decisions.md`), wave 25
(non-blocking consultation, ROADMAP R12, decisions D1-D12 of
`.collab/nonblocking-2026-09-26/handoffs/05-claude-r12-decisions.md`; and T4) and wave 26
(adaptive companions, telemetry routing and roles - ROADMAP R14-R16, decisions D1-D12 of the
companions design review; and the wave 25 acceptance's carry-overs) are in, and wave 26b (the wave
26 acceptance's decisions D1-D14 of
`.collab/companions-2026-09-26/handoffs/23-claude-wave26-acceptance-decisions.md` - ROADMAP R18,
R20 - and the supervisor's addenda D15, D16), wave 26c (the wave 26b re-acceptance's decisions D1-D6
of `.collab/companions-2026-09-26/handoffs/27-claude-wave26c-decisions.md`) and wave 27 (host
invariance and the coordinator's manual - ROADMAP R13, R19, decisions D1-D9 of
`.collab/host-2026-09-26/handoffs/05-claude-r13-decisions.md`), wave 27c (the fix round of their
acceptance, decisions D1-D24 of `.collab/companions-2026-09-26/handoffs/33-claude-wave27c-decisions.md`),
wave 28 (telemetry and complaints to the maintainer's intake, on by default - ROADMAP R17), wave 27d
(documentation only: waiting without losing the prompt cache, and three more coordinator hosts
documented but not run live), wave 28b (the fix round of their acceptance, decisions D1-D19 of
`.collab/companions-2026-09-26/handoffs/39-claude-wave28b-decisions.md`), wave 28c (the second
fix round, decisions D1-D14 of `.collab/companions-2026-09-26/handoffs/45-claude-wave28c-decisions.md`)
and wave 28d (the third fix round, decisions D1-D8 of
`.collab/companions-2026-09-26/handoffs/51-claude-wave28d-decisions.md`).

### Added

- **Wave 24 - a timeout never throws the reviewer's work away (T1).**
  - Per-purpose default timeouts: `-TimeoutSec` unset -> chore 600, checkpoint and no purpose
    900, framing and decision 1800, diff-review, core-contract and stuck 2400, acceptance
    3600 s; an explicit `-TimeoutSec` always wins. Ledger `timeout_sec`, `timeout_source`
    (`purpose` | `explicit`), `continue_sec` (after `sandbox`); the dry run's `timeout     :`
    line and the handoff header's `Timeout:` line say which applied; a `-Panel` resolves it
    once (`Timeout: ... per member`) and its members inherit it.
  - The timeout continuation: when the bridge kills the MAIN turn on its timeout and the
    turn's thread is known (codex `thread.started`; agy the init event's conversation; muse
    the session stream), ONE more turn continues that thread - codex `exec ... resume
    <thread> -` with the main turn's exec options (`--output-schema` included), agy
    `--conversation`, muse `--session-id` (through the engine adapter; its own prompt file) -
    with "Your previous turn was stopped by a time limit after N s. Do not start over and do
    not read more files than you must: finish now and output your final answer in the
    required format." (plus the output contract and the consultation id), within
    `-ContinueSec` s (new; default min(timeout, 900); 0 = off), under the same lock and
    recovery record (`Invoke-EngineTurn`, now also for codex). A usable reply is ingested like
    a first-turn reply: `bridge_outcome` `usable reply (after a timeout continuation)` - a
    usable reply for the endpoint health, the scoreboard and a panel's exit code
    (`Test-UsableOutcome`) - ledger `timeout_continue {thread, wall_seconds, outcome, events,
    usage}` (after `denial_retry`; `outcome` `not attempted: <why>` when none ran), the
    continuation's stream kept as `handoffs/NN-<engine>-<slug>.continue.events.jsonl`, the
    summary line `continued  : the main turn was killed at <t> s of <T> s; one continuation
    turn on thread <id> answered in <w> s`, the header line `Timeout continuation:`. Never more
    than one per consultation; never after a quota or auth failure named in the killed turn's
    own stream, never after a billing refusal (muse's guard is read afresh right before it),
    not when processes survived the kill, the run changed files (an engine's tree check) or
    the thread is unknown. A panel member continues inside its own process; its kill guard
    grows by `-ContinueSec` (`Get-PanelMemberGuard`).
  - The salvage: a turn killed on its timeout - the main turn without a usable continuation,
    the continuation, a denial retry, a format repair - leaves
    `handoffs/NN-<engine>-<slug>.partial.md`: the reply's header, then per turn every agent
    message and reasoning text of its event stream in order and its tool calls (codex items
    `agent_message`, `reasoning`, `command_execution` with its command line, `web_search`,
    `mcp_tool_call`; agy `text_delta` steps and tool steps, `run_command` with its command
    line; muse `run.output.delta` texts and `tool.*` tasks - the adapters' new `Salvage`),
    then the footer ``killed at <t> s of <T> s; thread <id> - continue with `-Task <t> -Mode
    resume -Thread <id> [-Purpose <p>] -Prompt "finish your review"` ``. Ledger `partial_reply`
    (after `events`), the header line `Partial reply:`, the summary lines `partial    :` and
    `resume     : <the exact command>`; `bridge_outcome` stays `failed: timeout ...`; a
    panel's summary row names the partial file. `-Thread` takes the conversation of an agy or
    muse run the bridge killed (a candidate only - its entry names the partial reply;
    `Find-ThreadEntry`), so the printed command works for every engine.
  - `-Range <revision range>` (diff-review and acceptance): `git diff --shortstat <range> --`
    once (`Get-RangeStat`; a panel measures once for all members) - "Review range: `<range>`
    - the range changes N files, M lines (...)" in the prompt, ledger `range {spec, files,
    insertions, deletions, lines}` (after `brief`), and a WARNING (console, handoff header,
    ledger `warnings[]`) when more than 1500 lines meet a timeout below 2400 s: "a range of M
    lines with a T s timeout: pass -TimeoutSec or a reading plan in the brief". An unknown
    range, an option-like or spaced argument, or another purpose is refused before anything
    starts.
- **Wave 24 - one truth about availability (T2, T3; D14-D17).**
  - `Get-RosterAvailability`: every roster entry judged by the roster walk's own verdict
    (`Select-PanelMembers -All`, which gains `-NoNetwork` and per-entry `Verdict`, `Health`
    and `Block`), each a record `{position, provider, model, engine, lineage, group, state
    available | out | not checked, kind, reason, short, hit, until}`; the endpoint groups over
    ALL resolved entries (`Get-EndpointGroups`, extracted from `Get-PanelPlan`, which keeps
    its plan): an outage recorded on an endpoint marks every entry of its group.
  - `codex-providers.ps1 -Short`: ONE line - `codex-consult: out - openai :: gpt-6-astra
    (until Sun 20:35, in 2d 10h), gemini :: * (until Sun 21:30, in 2d 11h); 9 of 11 reviewers
    available`, `codex-consult: all 11 reviewers available`; entries of one group sharing the
    state collapse to `<label> :: *`; reset times in LOCAL time (`ToLocalTime`) with a rounded
    relative hint; no reason is cut; "..., <o> out, <c> not checked" when an entry was not
    checked; without a roster the providers ("... (no reviewer roster)"). `-Short -Json`: the
    line and every entry's record. The table gains `endpoint health: <collab dir> (<k> task
    ledgers, <m> consultations), read at <local time> - the ledgers of THIS repository` and
    `availability: <the -Short line>`; JSON rows gain `health_source`.
  - The SessionStart hook prints that line (`codex-providers.ps1 -Short -Json -NoNetwork`,
    the `line` of its object; the old per-provider parser and its 60-character cut are gone).
- F15-1 (the muse acceptance): `Get-MuseCredentialInfo -Fresh`, `Get-MuseLaunchBlock -Fresh`,
  `Get-EngineLaunchBlock -Fresh`: the launch guard right before every Start-Process of an
  engine turn (the main turn, a denial retry, a format repair, the continuation) reads
  `auth.json` again; listings and the preflight keep the cache.
- `tests/harness-visibility.ps1` (registered in `run-all.ps1`): 76 assertions - see
  `tests/README.md`. Fake knobs: `FAKE_CODEX_HANG_NEW`, `FAKE_CODEX_ITEMS`, `FAKE_AGY_HANG=new`,
  `FAKE_AGY_TEXT`, `FAKE_MUSE_HANG=new|resume`, `FAKE_MUSE_TEXT`.
- **Wave 25 - non-blocking consultation (ROADMAP R12)**, per the design round recorded in
  `.collab/nonblocking-2026-09-26/` (design 01, the glm-5.3 review F02-1..11, decisions D1-D12):
  - `-Detach` (a single run or `-Panel`; refused with `-DryRun`, `-Status`, `-Wait` and the
    internal `-PanelSpec`): the FOREGROUND makes every check a real run makes before its task
    lock - the dry run's checks, and the refusals a dry run only reports (D2, F02-2): the
    launcher of every engine that will run, an ACTIVE recovery record, the preflight, (a single
    run) a `.cmd` launcher's `%` hazard; for a panel also the artifacts - exit 1, nothing
    written. Then it picks the detach id (a guid whose first 8 hex digits, the `id8`, name no
    status or log file of the task yet; D7), writes `<task>/.consult.detached-<id8>.status.json`
    ONCE, state `starting`, no pid (D5, F02-5), starts the BACKGROUND and exits 0 printing three
    lines: `Detached <id8>: <what runs> - it runs in the background (detach id <guid>; budget <s>
    s).`, the status file and the log, the come-back commands. Not checked there: the task lock
    and the time-dependent health/peak selection - a benign window the background's status
    reports.
  - The background: `<the same host> -File codex-consult.ps1 -Task <t> -CollabDir <absolute>
    -DetachId <guid>` in the caller's working directory, `-Brief` / `-Artifact` / `-CollabDir`
    absolute (D8, F02-11); the other arguments in the `starting` record's `args` (base64 of UTF-8
    PowerShell CLIXML - no command-line quoting; `ConvertTo-DetachArgs` / `ConvertFrom-DetachArgs`).
    Windows: `cmd.exe /d /v:off /s /c "... <NUL 1>"<log>" 2>&1"` through ShellExecute, hidden - it
    inherits none of the caller's handles, so the caller's capture ends when the foreground exits
    (a Start-Process with redirection would hold the caller's pipe until the background ended);
    a path with `%` is refused. macOS/Linux: `/bin/sh -c 'exec nohup <pwsh> ... </dev/null
    >log 2>&1'`. Its first action is the self-report `running` {pid, start_time, host} (D5), then
    `[Console]::OutputEncoding` and `$OutputEncoding` UTF-8 (D10, F02-8), then the run IN THE
    SAME PROCESS (`& codex-consult.ps1 @args -DetachId`) inside a try/finally that writes the final
    status - `done`, the run's exit code, the summary - on every exit path (D3, F02-3):
    `Stop-WithError` records its refusal line first (`$script:StopWithErrorHook`), an error is
    caught (`codex-consult: the detached run stopped on an error: ...`), a normal end writes the
    summary block it printed (`Write-Summary`: a panel's `Panel <id8>: ...` block, a single run's
    outcome lines up to `events file:`). Members (D11, F02-9): `pending | running | usable |
    failed | skipped | killed | blocked | commit_blocked | orphan` with the `outcome` phrase
    (`Get-PanelMemberStatus`), `wall_seconds`, `n`, `handoff`, `reply` - updated as they start and
    finish; a member never started ends `skipped` "not started: <why>". The console output
    (stdout and stderr) goes to `<task>/.consult.detached-<id8>.log`.
  - `-Status [-Id <id>] [-Prune]`: every detached run of the task, newest first, or one by its id
    or a prefix - the state, one line per member and, once done, the summary block verbatim; exit
    0 all done and usable, 1 a failure (a died run, never started, an unusable file too), 2 still
    running - the worst state decides (D7, F02-10) -, 4 the query refused (an id prefix of several
    runs, naming them; an unknown id; other options; a `-CollabDir` that does not exist - an id
    given without `-Id` lands there). Liveness (D6, F02-6): a record that is not done is judged by
    `Test-PidAlive(pid, start_time)` - gone = `died` (its recovery records are judged by the next
    run as usual); `starting` without a pid reads "starting" for 60 s, then `never started`; a
    background on another host is never judged (D11). `-Prune`, the one writing form (D8),
    deletes the status file and the log of runs done or died more than 7 days ago (D6).
  - `-Wait [-Id <id>] [-WaitTimeoutSec <s>]`: checks every 2 s until the run(s) are done or their
    background is gone, then prints as `-Status`; the default limit is the run's `budget_sec`
    (D4, F02-4: per endpoint group ceil(members / limit) x the member guard, the largest; with
    `-PanelConcurrency` also ceil(N / cap) x the guard; + 120 s - `Get-DetachedBudget`); still
    running after it: exit 3, the run untouched.
  - The status file (`status_version` 1): `id, id8, task, kind, state, exit, started, updated,
    finished, wall_seconds, pid, start_time, host, budget_sec, purpose, reply_name, brief,
    members[], summary, log, args` (README "Non-blocking consultation"). New in
    `codex-consult-common.ps1`: `Get-DetachedPaths`, `New-DetachedMember`,
    `ConvertTo-DetachedRecord`, `Read-DetachedStatus`, `Write-DetachedStatus`,
    `Read-DetachedRuns`, `Get-DetachedJudgement`, `Get-DetachedBudget`,
    `Complete-DetachedRecord`, `Format-DetachedListLine`, `Get-DetachedPhrase`.
  - `codex-findings.ps1 -List` prints one line per detached run of the task that is not done
    (`detached <id8>: running since <t> (<s>), k of N members finished (codex-consult.ps1 -Task
    <t> -Status -Id <id8>)`, or the died / starting / never-started / other-host wording); the
    SessionStart hook adds one phrase for the repository (`; 1 detached consultation running
    (task t)`, `... finished` in the last 24 h, `... died`; several kinds: `; detached
    consultations: 1 running (task a), 1 died (task b)`) - status files only (D6).
  - `.gitignore`: `.consult.detached-*` (D1, F02-1). The status file and the log start with
    `.consult.`: an agy or muse member's collab snapshot leaves them out (F02-7; the per-task
    files stay, D9).
  - The consult-codex skill: "Parking a consultation" - park the id, the brief and the come-back
    command in `state.md`, no second consultation of the task meanwhile, come back after `done`
    only, `-Wait` below the tool's own timeout; and (D12) the acceptance of a big change writes
    `-TimeoutSec 3600` into the brief's command.
  - `tests/harness-detach.ps1` (registered in `run-all.ps1`): 46 assertions - see
    `tests/README.md`. Test hook `CODEX_CONSULT_TEST_DETACH_GUIDS=<guid>[,<guid>]` (the detach ids
    tried first).
- **Wave 25 - T4 (ROADMAP): the harnesses under another scripts directory.** Every harness and
  `tests/run-all.ps1` take `-ScriptsDir <dir>` - else `CODEX_CONSULT_SCRIPTS_DIR`, else the
  checkout's `plugins/codex-consult/scripts` (no change without it); the schema follows the
  scripts (`<dir>/../schemas`); `run-all.ps1` passes it to every harness and names it on its
  first line and in its summary line (`run-all: 12 harness(es), 0 failed; scripts: <dir>`).
  `harness-detach` proves it with a marked copy of the scripts (run-all, the variable, neither).

- **Wave 26 - companions: size by stakes, telemetry routing, required reviewers, roles (ROADMAP
  R14-R16; decisions D1-D12).**
  - Size (D6): a `-Panel` starts as many members as its purpose needs - chore, no purpose and
    checkpoint 1, diff-review 2, framing and decision 3, core-contract and acceptance 4, stuck
    every eligible member; `-PanelSize <n>` (new, `-Panel` only, n >= 1; refused with
    `-PanelAll`) overrides; `-PanelAll` seats every eligible member. Eligible = available by the
    roster walk's verdict, past the weighty gate, matching `-Engine`/`-Model` - one set for the
    size, the ranking, the draw and the exploration (D1, D11). The size bounds the members
    STARTED (no backfill). An eligible entry without a seat is the new member state `not-picked`
    (`not picked: panel size k`; never in `roster.skipped` or a skip line). The summary reads
    `Panel <id8>: j of M entries ran (asked k, started j, usable i; wall clock ...)` plus `not
    picked (panel size k): ...`; every member's ledger `panel` record gains `asked`, `started` and
    `usable` (the last two written into the members' entries when the panel ends). A framing or
    decision panel that seats fewer than 2 members warns (`panel floor: ...`; console, ledger
    `warnings[]`) unless `-PanelSize` was given.
  - Routing (R15; D2-D5): `-PanelOrder routed|roster` (new; default `routed`). The routing score
    (`Get-RoutingScore` in `codex-consult-common.ps1`, shared with the scoreboard) reads the
    judge's marks of EVERY task of the repository (`Read-AllTaskRatings`, keyed by `consult_id`,
    the latest mark of a consultation wins, no join by `n`) from the last 90 days by the
    CONSULTATION's time: `w = (yes + 0.5 partly + 2p) / (n + 4p)`, p = 0.5, scaled `0.25 + 1.75 w`
    into [0.25, 2] (neutral 1.125); per (lineage, purpose, topics) with >= 3 marks (a mark credits
    each of its t topics 1/t, the counts pooled), else (lineage, purpose) >= 3, else the
    all-purpose rate >= 3, else neutral. While NO eligible reviewer has 3 marks the panel keeps the
    roster order (`routing.fallback: "no ratings"`). The draw (D4) is exact and portable: seed =
    SHA-256 of `<task>|<purpose>|<brief sha256>|<sorted eligible lineages>|<nonce>` (nonce:
    `-PanelSeed` - new -, else `CODEX_CONSULT_TEST_PANEL_SEED`, else the UTC date: a dry run and
    the real run of the same day seat the same members); per seat SHA-256(seed || seat, 4 bytes
    big-endian) - the top 53 bits of bytes 0..7 pick by weight, of bytes 8..15 explore (< 0.2: a
    uniform pick from the same pool). Lab diversity is a reserve (D1): while fewer than min(k, labs
    with an entry >= neutral) labs are seated, a seat draws only from labs not yet seated whose
    entries score >= neutral. Members get n and NN in seat order. Ledger `panel.routing {mode,
    order, fallback, seed, nonce, nonce_source, size, size_source, eligible[{position, lineage,
    lab, lab_source, score, basis, ratings, required}], picked[{slot, position, lineage, lab, rule}],
    explored[], required[]}`; the panel run and its dry run print it (`Routing: ...`).
  - Labs (D1): roster entries gain an optional `lab` (canonical lowercase); without it the lab is
    the vendor of the model id's prefix (qwen alibaba, deepseek, kimi/k3 moonshot, glm zhipu,
    dola/seed bytedance, mimo xiaomi, gemini google, muse meta, gpt openai) - never the provider
    label - else a lab of its own (a routed panel warns: `routing: no lab known for ...`).
  - `-Topic a,b` (new; any run): lowercase slugs, ledger `topics[]` (after `purpose`), copied onto
    the rating; a routed panel scores on them.
  - Required reviewers (D7): `-Require <reviewer>[,...]` (new; `-Panel`, or a single run with
    `-Provider`) - a roster position `#5`, a provider label (every entry of it) or `<provider> ::
    <model>` with an optional ` [<engine>]`, compared on the roster's provider, model and engine;
    the roster's top-level `"require": {"<purpose>": [...]}` is a panel's default (every matcher
    must name an entry at load, else the roster is unusable); `-Require none` drops it. A required
    reviewer is judged with the roster walk's verdict; one that is out refuses the run BEFORE
    anything starts with **exit 5** (the dry run too), naming who, why and when it is back
    (`Format-RequiredOutage`). In a panel the required take the first seats (a weighty one on a
    light purpose included), and a required member without a usable reply stops the panel at the
    next member (no further member starts), exit 5. `Stop-WithError -Code` (default 1).
  - Roles (R16; D8): `-Role <name>` (a single run; a panel: every member) and `-Roles a,b` (a panel
    only; not with `-Role`) - by SCORE RANK among the seated members, each role to the best-ranked
    member left that is willing to take it (the roster entry's new `roles: [...]`) when one is;
    more roles than members is refused. The role file: `<CollabDir>/roles/<name>.md` of the
    repository, else the plugin's new `templates/role-<name>.md` (`edge-cases`, `security`,
    `tests`, `docs`); names are slugs checked before any path is built; an unknown role refuses
    the run. The block goes into the prompt after the ask and before the brief (never inside the
    output contract); ledger `role` (after `topics`).
  - The roster extension point (D12): an optional `ext` object at the top level and in any entry,
    validated as an object only, never read or written; `roster_version` stays 1.
  - `codex-findings.ps1 -Rate` (D2): the mark is keyed by the consultation's `consult_id` (re-rating
    replaces by it; a pre-wave-26 mark without one by n) and carries `engine`, `topics` and
    `consult_when` (the consultation's own time) besides the old fields: `{n, consult_id, lineage,
    provider, model, engine, purpose, topics, consult_when, useful, note, when}`.
  - `codex-scoreboard.ps1`: `SCORE` (the routing score of the row's purpose; a lineage's total row
    its all-purpose score; JSON `score`), `UNIQ` (D10: findings a reviewer raised as a panel member
    that no other member of the same panel raised at the same location, of all it raised in
    panels; JSON `unique`, `panel_raised`) and `-By purpose|topic` (rows per topic; a consultation
    counts once on its lineage's total row); marks join their consultation by `consult_id`.
  - Docs: README "Companions (0.5.0, wave 26)" (size, routing, topics, required reviewers, roles;
    "about five members" labelled an operational heuristic), the roster table, the ledger fields,
    the options, a new exit-code table (`0`, `1`, `5`, `6`); both skills (consult-codex: the
    framing/decision floor, rating every consultation, exit 5 and asking the operator before going
    on without a required reviewer; setup-providers: `lab`, `roles`, `require`, `ext`).
  - `tests/harness-companions.ps1` (registered in `run-all.ps1`): 42 assertions - see
    `tests/README.md`; the draw's golden sequences come from an independent reference
    implementation. Rewritten for the smaller default panels and the seat order (D9): the panel
    cases of `harness-roster` (+1: the ledger order is `panel.routing.picked`), `harness-panel` (+1),
    `harness-engines`, `harness-muse`, `harness-visibility` and `harness-detach` pass `-PanelSize`
    where they mean every member; the summary line's `(asked k, started j, usable i; ...)`; the
    ledger field order (`topics`, `role`) in `harness-0.3`, `harness-engines`, `harness-muse`; the
    rating record in `harness-roster` and `harness-engines`; the scoreboard's header (`SCORE`,
    `UNIQ`) in `harness-roster`. Assertions (Windows PowerShell 5.1): `harness-roster` 119,
    `harness-panel` 54, `harness-detach` 51, `harness-companions` 42; the others unchanged.
- **Wave 26b - what the wave 26 acceptance and the day's live use asked for (decisions D9-D14 of
  handoff 23; the supervisor's addenda D15, D16; ROADMAP R18, R20).** The findings it fixes (D1-D7)
  are under Fixed.
  - `-Kick -Member <NN> [-Id <id8>]` (D10; `codex-consult.ps1`, the handler before `-Status`;
    `Get-KickPath`, `Wait-EngineProcess` in `codex-consult-common.ps1`): from another shell, stop
    ONE running member of a panel (or a single run) of `-Task` by its handoff number - a detached
    panel with `-Id` (the member must be one of its running members), a foreground panel without.
    `-Kick` writes `<task>/.consult.kick-<NN>`; the member polls it every second while its engine
    turn runs (the main turn, a continuation, a denial retry, a format repair), stops its process
    tree, deletes the file (the acknowledgement `-Kick` waits up to 60 s for), salvages its partial
    output (`.partial.md`) and records `failed: stopped by the operator (-Kick)` with
    `provider_failure.class` `operator` (never read as an endpoint outage); no continuation; the
    panel goes on with the others; `-Status` shows the member `failed: stopped by the operator
    (-Kick)`. Exit `0` done, `1` no such member or not running (no recovery record names it, not
    running, not taken within 60 s - the kick file is then removed), `4` refused. A stale kick file
    of the same number is removed when a run starts.
  - Roster `timeout_sec` (D11): an entry's optional integer (60-86400) replaces the purpose's
    default for that reviewer - a panel member (per slot: timeout, its guard, its continuation
    budget `min(timeout, 900)` unless `-ContinueSec`) or a single run of the entry (`roster.applied`
    names `timeout_sec`); an explicit `-TimeoutSec` still wins for all. Ledger `timeout_source`
    gains `roster`; the panel's `Timeout:` line lists the exceptions (`Timeout: 900 s per member
    (the default of purpose checkpoint); #2 ZAI :: glm-5.3 120 s (roster); ...`), the single run's
    `timeout     :` line says `(the roster entry's timeout_sec)` (`Format-TimeoutSource`).
  - The stall cut (D12, ROADMAP R18): `-StallSec <s>` (new, at the end of the parameter list;
    default 900, a roster entry's `stall_sec` 0-86400 overrides it for that reviewer, an explicit
    value wins; `0` = off). `Wait-EngineProcess` replaces the main turn's `WaitForExit`: every second
    it reads the lines appended to the turn's event stream (`Read-StreamGrowth` - codex `--json`,
    agy stream-json, muse MSP all go there line by line); no complete line for the threshold while
    the process lives -> the tree is stopped like a timeout: the continuation turn ("Your previous
    turn was stopped after N s without any output. ...") and the salvage; `bridge_outcome`
    `failed: stalled after N s without an event (process tree killed)`; ledger `stall {seconds,
    last_event}` (new, after `timeout_continue`; `last_event` the time the last line was seen,
    `null` for none). A panel resolves it per member (`stall_sec` in the member spec).
  - Machine-wide endpoint health (D13, ROADMAP R20; `codex-consult-common.ps1` section
    "machine-wide endpoint health"): `<codex home>/codex-consult-health.json`
    (`CODEX_CONSULT_HEALTH=<path>` another, `none` off) - `endpoints[]` `{endpoint, class, kind,
    until, retry_after, repo, when, message}` written by every run that records a usable reply
    (class `ok`) or a provider failure (not `operator`; `Add-MachineHealthRecord` after the
    commit), `running[]` `{endpoint, label, pid, start_time, repo, task, nn, panel, since}` while a
    run's turns run (`Register-MachineRunning` at the main turn's start, `Unregister-...` after the
    commit and in the finally); every write under `<file>.lock` (exclusive, 10 s, else not written)
    and pruned (a record older than 24 h whose until passed; a running row whose pid + start time is
    gone). `Get-EndpointHealth` reads the file's records beside the ledgers (`-NoMachine` for the
    ledgers alone) - every roster walk, panel selection, `-Require`, `codex-providers.ps1`; the
    panel scheduler counts `Get-MachineRunningCount` (other repositories', panels', single runs'
    rows on the group's endpoints) against the group's parallel limit and says `panel member k of
    n waits: <count> run(s) elsewhere on this machine use its endpoint (parallel limit L): ...`.
    Absent, unreadable or unparseable = as before.
  - The salvage of any failed run with content (D15, the supervisor's addendum): the wave 24
    `.partial.md` (ledger `partial_reply`, the `partial    :` summary line, the handoff header's
    `Partial reply:`) is written for ANY failed run whose event streams (the main turn, a
    continuation, a denial retry, a repair) hold at least one agent message, reasoning text or tool
    call - a provider failure mid-run, a denial, a tree-check failure; the main turn's heading says
    `it ended at <t> s: <why>` and the footer `the run ended: <why>; thread <id> - continue with
    ...` instead of `killed at`; a stream without content (a 401 on the first request) leaves
    nothing. Same for a turn stopped by the stall cut or `-Kick`.
  - The reviewer's context window (D16, the supervisor's addendum): a roster entry's optional
    `context_tokens` (32000-100000000). (a) A fork/resume of that reviewer whose thread last
    carried (the continued thread's ledger `usage.input_tokens`, else its codex events' last
    usage) plus this prompt's estimate ((composed prompt + brief) / 4) more than 80% of it becomes
    a NEW thread: ledger `mode_fallback {from, to, reason}` (new, after `mode`; `null` otherwise),
    a console line and a summary line (`mode       : fork -> new (...)`), and the prompt names the
    reviewer's previous reply file to re-read. (b) A brief whose estimate alone ((ask + brief) / 4,
    computed before any reviewer is chosen) exceeds 80% skips the entry before its start - `brief
    too large for this reviewer's context (est. N of M tokens)` in the panel's list and summary, the
    ledger's skipped lists, a roster walk's `roster.skipped`; an explicit `-Provider` run of it is
    refused (exit 1). (c) The prompt of a reviewer with `context_tokens` says, after the ask, `Your
    context window is M tokens: read only what the brief points to; prefer targeted reads.`
  - The skill rules and templates (D14): consult-codex gains a standalone **Language** rule
    (briefs, prompts, follow-ups, handoff titles in English; the operator's language only in the
    conversation; source material translated, never pasted) and a standalone **Live members** rule
    (while an agy or muse member runs, nothing written under the collab directory or the working
    tree - `state.md` included - and no git command; notes queued until the panel closes), plus the
    panel notes for the stall cut, `-Kick`, the machine-wide limit and a reduced panel;
    setup-providers documents `timeout_sec`, `stall_sec`, `context_tokens`, the delimiter refusals
    and the health file. Every template's first line is `Write in English.` (the two briefs, the
    four roles).
  - Docs: README (the options, exit-code and environment tables - `-StallSec`, `-Kick`, `-Member`,
    `CODEX_CONSULT_HEALTH`; the ledger's `mode_fallback`, `stall`, `tree_check` in their positions,
    `panel.asked`, `routing.size_asked`/`reserve`, `panel.roles_note`, `timeout_source` `roster`,
    class `operator`, the new warnings; the roster table's `timeout_sec`, `stall_sec`,
    `context_tokens` and the delimiter refusals; "Timeouts" - the stall cut, `-Kick`, the D15
    salvage; "Preflight and endpoint health" - the machine-wide file; "Companions" - D1-D5; muse's
    tree check; `UNIQ`), the script's help text, `tests/README.md`.
  - Tests: `tests/harness-fixes26b.ps1` (new, registered in `run-all.ps1`): 39 assertions on
    Windows PowerShell 5.1 (ROLEFILE, SIZE, SEED, ROLES, RESERVE, JOIN, UNIQ, TIMEOUT, STALL, KICK,
    SALVAGE, CONTEXT, HEALTH, GUARD); D9 in `harness-muse.ps1` TREE (+2: the HARNESS writes
    `.collab/t/state.md` during a muse run - a warning - and during an agy run - a failure; the two
    wave 23 D12 muse cases rewritten). `tests/reference-draw.py` (new): the independent reference
    implementation of the draw (it reproduces every wave 26 golden value with the old seed text and
    gives the new ones). `fake-codex3.ps1`: `FAKE_CODEX_FAIL_EVENT` (an error event mid-run) and
    `FAKE_CODEX_ITEMS=2` (a second agent message). Every harness sets `CODEX_CONSULT_HEALTH=none`.
- **Wave 27 - the host is a parameter; the coordinator's manual ships with the plugin (ROADMAP
  R13, R19; decisions D1-D9 of `.collab/host-2026-09-26/handoffs/05-claude-r13-decisions.md`, the
  design review's findings F02-1..4, F03-1..7, F04-1..11).**
  - D1 (F04-1, F04-2, F03-1, F04-9, F02-1, F02-3): README "## Install" for three hosts - Claude
    Code (the plugin, unchanged), Codex CLI (the SAME plugin through Codex's own plugin system:
    the operator runs `codex plugin marketplace add xelth-com/claude-codex-consult` and `codex
    plugin add codex-consult@claude-codex-consult`; update, removal, the plugin cache path, the
    sandbox a real consultation needs), any shell (a clone, `CODEX_CONSULT_ROOT=<clone>/plugins/
    codex-consult`). No install script, no copies of skills, nothing the bridge writes into
    `$HOME`. "Setup on a new machine" step 0 finds the plugin in either host's cache or a clone.
  - D2 (F02-2, F04-3): the first line after each skill's title (`consult-codex`,
    `setup-providers`, `coordinate`): "`${CLAUDE_PLUGIN_ROOT}` is the plugin directory; from a
    plain shell set `CODEX_CONSULT_ROOT` to it and use that instead." Every invocation keeps
    `${CLAUDE_PLUGIN_ROOT}`; the `<skill dir>/../..` fallback is documented nowhere.
  - D3 (F03-2, F03-3, F04-4, F04-5, F04-10): `CODEX_CONSULT_COORDINATOR` (optional) - the
    coordinator's own model: `<provider> :: <model>` [` [<engine>]`], a roster position `#<n>` or a
    provider label. `codex-consult-common.ps1`: the reviewer matcher split into its one parser
    `ConvertFrom-ReviewerMatcher` and its one comparison `Test-ReviewerMatch`
    (`Resolve-ReviewerMatcher`, i.e. `-Require`, now built on them - same results, same messages);
    `Resolve-CoordinatorIdentity` (a value that does not parse, a position the roster lacks, a
    provider that is not a label or a model with white space is refused - "CODEX_CONSULT_COORDINATOR=
    '...' cannot be used: ...; nothing was started.", exit 1, the dry run too),
    `Get-CoordinatorHost` (the host as a HINT: `codex` - CODEX_SESSION_ID / CODEX_THREAD_ID -,
    `claude-code` - CLAUDECODE, CLAUDE_CODE_ENTRYPOINT, AI_AGENT claude-code* -, else `unknown`;
    no warning from it), `Test-CoordinatorReviewer` (the RESOLVED identity field by field, an
    explicit identity only), `Format-CoordinatorText`, `Format-CoordinatorWarning`.
    `codex-consult.ps1` resolves it ONCE, right after the roster is read; a panel member takes its
    panel run's (PanelSpec `coordinator`), a detached run its foreground's (status record
    `coordinator`) - never inferred downstream. A seated reviewer that is the coordinator's own
    model warns "coordinator: <lineage> is the coordinator's own model (CODEX_CONSULT_COORDINATOR) -
    a second opinion from the coordinator's own model, not an independent one" (the run's
    warnings: console, dry run, handoff header, ledger `warnings[]`; a panel's plan warns per
    seated member - not through `panel_warnings`, each member warns in its own entry). Ledger
    `coordinator {provider, model, engine, host, source: explicit | inferred | none}` right after
    `lineage` - a NEW key; `host` of the lock, recovery and status records stays the machine name
    (README field table). The dry run prints `coordinator : ...`.
  - D4 (F04-7): every engine child starts WITHOUT the coordinator's host markers -
    `CODEX_SESSION_ID`, `CODEX_THREAD_ID`, `CODEX_CI`, every `CODEX_SANDBOX*`, `CLAUDECODE`,
    `CLAUDE_CODE_ENTRYPOINT`, `AI_AGENT`; everything else kept (`CODEX_HOME`, the keys, `PATH`,
    `CODEX_CONSULT_*`). `Hide-HostMarkers` / `Restore-HostMarkers` around `Start-EngineProcess`
    (the main turn, a denial retry, a format repair, the continuation - every turn), the detached
    background's start (`Start-DetachedRun`) and `codex --version`; `Remove-HostMarkersFromStartInfo`
    in the probes (`Get-CodexLoginStatus`, `Get-AgyModelsStatus`, `Invoke-LauncherCapture`). Ledger
    `child_env_scrubbed` (the NAMES captured once, sorted; never a value) right after `command`;
    the status record and the PanelSpec carry it. The dry run prints `child env   : ...`.
  - D5 (F04-6, F03-7, F04-8): the SessionStart hook prints a second line, always:
    `codex-consult: coordinator rules - skill codex-consult:coordinate (or codex-consult.ps1
    -Explain coordinate)`. `codex-consult.ps1 -Explain coordinate|consult|providers` (the one form
    without `-Task`): one line naming the SKILL.md and the plugin
    directory, then the skill without its front matter, as UTF-8 bytes; read-only, exit 0; an
    unknown name or another parameter exit 1. README "Hooks on each host" documents the one-liner
    with `-ExecutionPolicy Bypass`.
  - D6 (F03-4, F02-4): host-neutral wording - the script synopsis ("from any coordinator"), the
    hook header, both skills (`the coordinator`, "restart the coordinator's session"), the README
    outside its host sections, the plugin and marketplace descriptions. `-BriefPrefix <slug>` /
    `CODEX_CONSULT_BRIEF_PREFIX` (default `claude`): the coordinator's brief prefix
    (`handoffs/<NN>-<prefix>-<slug>.md`); a reply prefix (`codex`, `agy`, `muse`) or a non-slug is
    refused before anything starts (exit 1); the dry run prints `brief prefix: ...`; a panel
    passes it to its members.
  - D7 (F03-5, F03-6, F04-11; Q4-Q6): the skill `coordinate` (host-neutral, English: the
    invariants, the bridge's own means `-Detach`/`-Status`/`-Wait`/`-Kick`, the worker tier
    CONTRACT - deep reasoning, default execution, cheap read-only recon - then "Means per host":
    Claude Code, Codex CLI, a plain shell). `agents/opus-worker.md`, `agents/sonnet-worker.md`,
    `agents/haiku-worker.md` (model aliases `opus`, `sonnet`, `haiku`; written from the tier
    contract; the recon tier has no Edit/Write tool). `install/examples/codex-agents/{opus,sonnet,
    haiku}-worker.toml` (`name`, `description`, `developer_instructions`, no model key) - EXAMPLES,
    never installed. `consult-codex` links `coordinate`; the README carries the three AGENTS.md
    lines the operator pastes on the Codex host.
  - D8: README "## For the coordinator" - the coordinator's identity, brief prefix and rules, and
    the migration of a private CLAUDE.md delegation block to a pointer; the plugin never edits a
    CLAUDE.md or an AGENTS.md.
  - D9: `tests/harness-host.ps1` (new, registered in `tests/run-all.ps1` - fifteen harnesses; the
    runner clears `CODEX_CONSULT_COORDINATOR` and `CODEX_CONSULT_BRIEF_PREFIX` for its children):
    GREP (D2/D6 over the skills, the README and the scripts), MATCHER, REFUSE, WARN, ENV (a fake
    engine that writes what it inherited - `fake-codex3.ps1` `FAKE_CODEX_ENV_DUMP` - for the main
    turn, a format repair, the timeout continuation, the launcher probes, a detached run and a
    panel's members), EXPLAIN, HOOK, PREFIX, SKILL, AGENTS, README. The live verification (the
    operator installs on the Codex host, one `codex exec` coordinator session runs a checkpoint
    with `mimo :: mimo-v2.6-pro` on task `r13-host`) is the supervisor's.
  - Deviations from the decisions, said here: (1) the host hint looks at the codex markers FIRST
    (D3 lists claude-code first) - a codex session started from a claude-code session inherits
    CLAUDECODE / AI_AGENT, and D9 expects `codex` exactly there; (2) the coordinator value is
    checked beyond the matcher's parse (a label, a model without white space, an existing `#n`) -
    a typo would otherwise name nobody silently; (3) the scrub covers the launcher probes too;
    (4) the Codex agent examples live under the PLUGIN directory
    (`plugins/codex-consult/install/examples/codex-agents/`) so an installed plugin carries them;
    (5) the bridge names no briefs, so `-BriefPrefix` is validated, shown and passed on, nothing
    more; (6) the hook's pointer is a second line, not appended to the availability line; (7)
    README's Codex sandbox flags (`workspace-write`, `sandbox_workspace_write.network_access`,
    `--add-dir <codex home>`) and whether Codex runs the plugin's SessionStart hook (hook trust)
    are unverified until the D9 run.
  - Wave 27b - two more coordinator hosts and the completed scrub list:
    - Hosts: README "## Install" gains "### Z Code" (a Claude-layout plugin host: its plugin
      manager or its CLI - `plugins marketplace add xelth-com/claude-codex-consult`, `plugins
      install codex-consult@claude-codex-consult`; on Windows the CLI is the desktop app's
      `resources\glm\zcode.cjs` run with `node`; it substitutes both `${CLAUDE_PLUGIN_ROOT}` and
      `${ZCODE_PLUGIN_ROOT}`, so the skills and the SessionStart hook work unchanged; it reads
      `AGENTS.md`) and "### Kimi Code" (no plugin system: a clone, `--skills-dir
      <clone>/plugins/codex-consult/skills`, `CODEX_CONSULT_ROOT` - it does not substitute the plugin
      root -, the AGENTS.md lines in the PROJECT's `AGENTS.md`, no hooks - the hook one-liner or
      `-Explain coordinate` -, `CODEX_CONSULT_COORDINATOR` since it sets no marker of its own).
      "Hooks on each host", "For the coordinator", the `coordinate` skill's "Means per host" and
      the plugin and marketplace descriptions name both hosts.
    - Host hint: `Get-CoordinatorHost` returns `zcode` when `ZCODE_SESSION_ID` or
      `ZCODE_PROJECT_DIR` is set - order: the codex markers, then zcode, then claude-code, else
      `unknown`. The ledger's `coordinator.host` values are `codex`, `zcode`, `claude-code`,
      `unknown` (README field table, `consult-codex`).
    - Scrub list (D4 completed): observed from inside a child of a host session, the session hands
      its children far more than the three names wave 27 scrubbed - its session ids, its MESSAGING
      SOCKET and TOKEN, its attendance, its executable path, its pid and effort -, so a reviewer
      child still inherited the coordinator's session channel. `$script:HostMarkerNames` gains
      `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_BRIDGE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION`,
      `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDE_CODE_MESSAGING_TOKEN`, `CLAUDE_CODE_SESSION_ATTENDED`,
      `CLAUDE_CODE_EXECPATH`, `CLAUDE_PID`, `CLAUDE_EFFORT`, `ZCODE_SESSION_ID`,
      `ZCODE_PROJECT_DIR`; `$script:HostMarkerPrefixes` gains `ZCODE_PLUGIN` (every
      `ZCODE_PLUGIN*`). EXACT names, never the whole `CLAUDE_CODE_` prefix: the operator's own
      settings (`CLAUDE_CODE_USE_BEDROCK` and the like) must still reach an engine (a future
      claude engine included); `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` are kept. The README's
      two lists (the `child_env_scrubbed` row, the variables table) and the script synopsis say so.
    - Tests: `harness-host.ps1` - the marker set holds every new name and `ZCODE_PLUGIN_ROOT` (set
      in the parent, absent from every engine child's dump, listed in `child_env_scrubbed`; no
      value in the ledger), `CLAUDE_CODE_USE_BEDROCK` and `CLAUDE_PLUGIN_ROOT` survive (the main
      turn, the repair, the probes, `Hide-HostMarkers`); MATCHER the zcode hint and its order
      (codex over zcode, zcode over claude-code; a plugin root is no hint); WARN a Z Code dry run
      (`host zcode`, the four `ZCODE_*` names scrubbed); README the host sections in order and the
      documented lists against the script's own; SKILL the two new hosts, the idle watchdog's
      items 1-7 and the COMPACT line of each host, README's sentences on it. `fake-codex3.ps1`'s
      environment dump includes `ZCODE_*`. `harness-detach` SINGLE no longer races a loaded
      machine (its "while it runs" checks failed in 3 of 4 full runs when every script call took
      7-9 s): the fake reviewer HOLDS until a release file exists (`fake-codex3.ps1`
      `FAKE_CODEX_HOLD_FILE`, at most `FAKE_CODEX_HOLD_SEC`, default 120 s), `-Wait` is started
      without blocking and the reviewer is released once `-Wait` says it waits; the assertions are
      unchanged. `harness-panel` RUN (the panel's wall clock vs the members' walls) and GUARD (a
      15 s guard vs a normal member's run) stay timing cases: they measure the bridge's own start
      overhead against fixed budgets, which no release file removes - re-run them alone.
    - The idle watchdog (the operator's specification, revision 2): the `coordinate` skill's rule 3
      replaces "a watchdog wake shorter than the prompt-cache lifetime" with seven items - ONE
      recurring wake (30 minutes, off the round minutes) armed at the FIRST delegation and kept
      when the work ends; the idle clock from the LAST activity of any kind; small reads on every
      wake; a background `-Wait` as the notification of a detached panel; nothing running: idle
      wake 2 - handover, COMPACT, remove the wake; something running: idle wake 3; where the agent
      cannot compact (Claude Code, verified 2026-09-29: a scheduled `/compact` arrives as ordinary
      text) the handover and one line to the operator, or the wake kept while the wait is under
      about nine hours - and the why (a wake costs a cache read of the whole context, a compaction
      about one). "Means per host" gives each host's COMPACT; README "For the coordinator" names
      the rule and the operator's lever, the host's auto-compact threshold.
    - Live coordinator run on Kimi Code 0.27.0 (2026-09-29, headless `-p`, a scratch repository,
      the README, the three `AGENTS.md` lines and the skills alone): one checkpoint consultation,
      reviewer `mimo :: mimo-v2.6-pro`, usable reply in 143 s, brief `01-kimi-<slug>.md`
      (`-BriefPrefix kimi`), ledger `coordinator {source: explicit, host: unknown}`,
      `child_env_scrubbed: []`. Two remarks of that coordinator were taken: the `consult-codex`
      skill says to leave `-Mode` out on the first consultation of a task (its example shows
      `-Mode fork`, which is refused without a thread), and the third `AGENTS.md` line and the
      skill say to KEEP the operator's `CODEX_CONSULT_COORDINATOR` when it is set (the coordinator
      had replaced `kimi :: k3` by a guess of its own name).
    - Assertions (waves 26c, 27, 27b; the final `tests/run-all.ps1` runs of 2026-09-29, Windows
      PowerShell 5.1 and PowerShell 7.6.6 - the same counts on both): `harness-0.3` 229,
      `harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74,
      `harness-panel` 54, `harness-pending` 26, `harness-fixes` 43 + the 2 environmental F04-10
      cases (the operator's own codex.exe runs; never killed), `harness-lock2` 11, `harness-3b` 12,
      `harness-visibility` 121, `harness-detach` 51, `harness-companions` 42, `harness-fixes26b` 51
      (+12, wave 26c), `harness-host` 50 (new: 44 in wave 27, +6 in wave 27b). The suites
      themselves printed `15 harness(es), 3 failed` (5.1) and `2 failed` (7): besides F04-10, another
      session's release builds ran during them, and `harness-panel` RUN/GUARD (5.1) and
      `harness-detach` SINGLE (both) failed on timing - panel 54/54 alone on the idle machine;
      SINGLE was then made independent of machine speed (above) and `harness-detach` passed 51/51
      alone on both hosts. The suites ran `harness-host` at 48 (before the idle watchdog); the final
      50 ran alone on both hosts, as did `harness-engines` TREE and `harness-visibility` UNIT24C
      (they read the README).
- **Wave 28 - telemetry and complaints to the maintainer's intake, ON by default (ROADMAP R17).**
  Installing the plugin means accepting its terms (README "Telemetry (on by default)").
  - The switch: `CODEX_CONSULT_TELEMETRY` (unset or empty, `on`, `1`, `true`, `yes` - on; `off`,
    `0`, `false`, `no`, `none` - off; any other value counts as OFF: a switch that cannot be read
    never sends) and `codex-consult.ps1 -Telemetry on|off` for one run (a panel passes it to its
    members in the PanelSpec; a detached background gets it with its arguments).
    `Get-TelemetrySwitch` lives in `codex-consult-detached.ps1` so the SessionStart hook can print
    it. Off writes nothing of telemetry: no spool line, no salt, no notice marker.
  - The event (`codex-consult-common.ps1`, section "telemetry"): after EVERY ledger commit - a
    usable or a failed run, each panel member - `Submit-TelemetryEvent` builds ONE event from the
    COMMITTED entry through the closed allowlist `ConvertTo-TelemetryDetails` / `New-TelemetryEvent`
    (`app_id` codex-consult, `app_version` from `plugin.json`, `instance_id` = sha256(the 32 salt
    bytes of `<codex home>/telemetry-salt` || the UTF-8 machine name), `event_type` consultation,
    `severity` info | warning (quota, auth, the operator's -Kick) | error, `title` = the outcome
    class `usable` | `usable-after-continuation` | `failed:<class>`, `details` {engine, provider,
    model, purpose, outcome, wall_seconds, tokens {in, cached, out}, findings {blocker, major,
    minor, note}, structured, format_retry, denial_retry, timeout_continue, panel_size, ps_version,
    os, bridge_version}, `tags` [engine, provider], `client_time` (UTC), `os`, `runtime`) and
    appends it as ONE NDJSON line `{v, kind, queued_unix, body}` to `<codex
    home>/telemetry-spool/<utc yyyy-mm-dd>.ndjson` - the body a JSON STRING, so the sender posts
    the exact bytes built. The provider label and the model id go through patterns (a path shape
    becomes `other`), the purpose and the failure class through closed sets.
  - The send: `Start-TelemetrySender` starts `scripts/codex-telemetry.ps1 -Flush -Telemetry on`
    (new) detached - the same PowerShell, a hidden window through ShellExecute (no inherited
    handle), in the temp directory, through `Hide-HostMarkers` like every engine child (the
    coordinator's session markers, the messaging socket and token among them, never reach it) -
    and never waits for it. A panel member only spools; its panel run starts ONE sender after the
    members' counts are committed; a run that keeps its recovery record starts none.
    `Invoke-TelemetryFlush`: the sender lock `<spool>/.flush.lock` (held open exclusively; a
    concurrent sender exits 2), the spool oldest first, lines older than 7 days and lines that are
    no spool line dropped, events in batches of at most 100 (`{"events": [...]}` to
    `<intake>/v2/events`), complaint lines one by one (`<intake>/v2/complaints`), a 3 s connect
    probe and 5 s in all per request (`Invoke-TelemetryPost`), delivered only on a 2xx JSON object
    with `"ok": true`; a 429 with `Retry-After` of at most 60 s is waited for and resent once
    (`Invoke-TelemetrySend`), nothing else is retried; the first failure ends the flush; delivered
    and dropped lines are removed as a multiset of exact lines under the file's exclusive handle
    (lines appended meanwhile stay); `<spool>/.last` {time, result, delivered, kept, dropped,
    http}. The intake: `CODEX_CONSULT_TELEMETRY_URL`, else `https://xelth.com/T`; https only -
    plain http only for a loopback host (`Get-TelemetryUrl`).
  - The notice: the first real run after an install or an update (no marker `<codex
    home>/telemetry-notice-<version>`) - a run the coordinator started or a `-Detach` foreground,
    never a dry run, a panel member or a detached background - prints five lines (what is sent,
    what never is, the switch, `-Complain` and `-Status`, the terms and the README section) while
    telemetry is on. The dry run prints `telemetry   : on (<source>) - ...` / `telemetry   : off
    (<source>) - nothing is spooled or sent`; the SessionStart hook's pointer line ends with `;
    telemetry: on|off`.
  - `-Complain "<text>" [-Contact <c>] [-Yes]` (`codex-consult.ps1 -Task <t>`, or
    `codex-telemetry.ps1` with an optional `-Task`): the payload {app_id, app_version,
    instance_id, text (at most 8 KiB of UTF-8), context {consultation - the task's last ledger
    entry through the same allowlist, or null; bridge_version; os; runtime}, contact} printed in
    full - exactly the body sent -, `send? [y/N]` unless `-Yes` (a redirected stdin is read as the
    answer; no answer is no), sent synchronously (10 s); `public_ref` printed, or the payload kept
    in the spool as a complaint line the sender retries. Exit 0 delivered, 1 refused or not
    confirmed, 3 not delivered (kept). Independent of the switch (an explicit, confirmed send).
  - `codex-telemetry.ps1 -Status`: the switch and its source, the intake URL, the spool's counts
    (events, complaints, unreadable lines, the oldest), the last flush's result (the ONE line an
    undeliverable intake - today's HTML page - ever costs), the instance id, the notice's state.
    Reads only.
  - Docs: README "## Telemetry (on by default)" (the terms line, the exact payload and a key
    table, what is never sent, how it travels, the intake, `-Complain`, `-Status`, your data), the
    installer's bullet, the options (`-Telemetry`, `-Complain`), the variables
    (`CODEX_CONSULT_TELEMETRY`, `CODEX_CONSULT_TELEMETRY_URL`, the test hook
    `CODEX_CONSULT_TEST_TELEMETRY_ENV`), the ledger note (the fields the event reads), the hook
    and component rows, "How it works"; one paragraph each in the `consult-codex` and
    `setup-providers` skills; the plugin and marketplace descriptions name the opt-out telemetry.
  - Tests: `tests/harness-telemetry.ps1` (new, the sixteenth in `tests/run-all.ps1`) - UNIT,
    SPOOL, NOTICE (+ DRYRUN), SEND (+ ENV), FLUSH (R429, NONJSON, DROP, LOCK, BATCH, URL),
    COMPLAIN, STATUS, HOOK, DOCS, GUARD; the intake is a local `System.Net.HttpListener` on
    127.0.0.1 or a closed loopback port, never the real one. Every OTHER harness sets
    `CODEX_CONSULT_TELEMETRY=off` and `CODEX_CONSULT_TELEMETRY_URL=http://127.0.0.1:9/` at its top,
    and so does `run-all.ps1` for its children; `harness-host` HOOK expects the pointer line with
    `; telemetry: off`.
  - Deviations and open points: (1) the hook's `telemetry: on|off` is appended to the POINTER
    line (the availability line is asserted verbatim by three harnesses); (2) the ledger gets no
    telemetry field (its field order is asserted by five harnesses; the event is derived from the
    committed entry, README's ledger note lists the fields it reads); (3) severity `warning` also
    covers `failed:operator` (a `-Kick` is neither a limit nor a bridge failure); (4) the notice is
    printed only while telemetry is on; (5) a complaint does not depend on the switch; (6) the
    intake's own delete endpoint is not in the v2 contract this client was built against - README
    "Your data" asks for deletion through `-Complain` (the payload carries the instance id) and
    says so; (7) the connect timeout is a TCP probe of the host (or of the system proxy for the
    URL) before the request, since `HttpWebRequest` has no connect timeout of its own.
  - Assertions (with wave 27c in the same runs): `harness-telemetry` 55 (new); the final `tests/run-all.ps1` runs of 2026-09-29 (Windows PowerShell 5.1, then PowerShell 7.6.6 from 20:29 to 22:19), the same counts on both, `17 harness(es), 0 failed`: `harness-0.3` 229, `harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74, `harness-panel` 54, `harness-pending` 26, `harness-fixes` 45 (the two F04-10 cases passed this time), `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121, `harness-detach` 51, `harness-companions` 42, `harness-fixes26b` 51, `harness-host` 52, `harness-telemetry` 55, `harness-fixes27c` 36.
- **Wave 27d - documentation: waiting without losing the prompt cache, and three more coordinator
  hosts, documented and not run live.** No script under `plugins/codex-consult/scripts/` changed.
  - The waiting rule, revision 5 (the operator's, 2026-09-29): the `coordinate` skill's rule 3 is now
    "Wait without blocking; keep the cache warm or compact (the idle watchdog)" - the goal (a large
    context never loses its prompt cache by oversight: a cold resume writes the whole context, a
    refresh reads it), the six cases of RUNNING WORK that keep the wake armed and the idle count at
    zero (a worker or subagent that has not reported, a detached panel or consultation, a shell job,
    a window given to another session, an operator step with a named end, a cooldown with a named
    end), the wake (one every 30 minutes, armed at the first delegation or WAIT, kept; a wake close
    to other activity answers in one line without a tool call), the rule's seven items (keep the
    wake, no compaction mid-wave; compact or start fresh at a wave boundary; a wait of known length
    against the boundary; idle wakes 1 and 2; no means to compact - say it in one line, keep the wake,
    remove it after half the refreshes a cold resume is worth: 40 / 20 / 10 wakes on Claude Fable
    5.1 / Claude Opus 5.5 / Claude Sonnet 5.5; compact only while warm; the auto-compact threshold),
    the boundary table in a compact form and the pointer to the README. Gone from revision 2: the
    idle wake 3 while something runs (running work keeps the idle count at zero) and "keep the wake
    under about nine hours" (now the 40 / 20 / 10 wakes). "Means per host" keeps its COMPACT lines.
  - README "## Waiting: keep the prompt cache or compact" (new, after "For the coordinator"), for a
    reader who never thought about prompt caching: the cache and its lifetime (one hour in the
    coordinator sessions measured, five minutes by default on the API), the three prices and their
    table, the refresh (the recurring wake; on the API a request with `max_tokens: 0`) and the six
    cases of running work, compaction and the compact window, the formulas, the boundary table (five
    context sizes, three models; one wake, compact and let-it-expire for Claude Fable 5.1), what the
    table shows, a worked example (8 hours at 850K on Claude Fable 5.1: keep about 4.2 USD, compact
    1.71 USD, let it expire 17 USD), what the money does not show, the rule in seven lines, what was
    measured, taken and estimated, the caveats and the vendor's pricing page. "For the coordinator"
    describes revision 5 and points at the section; the plugin's own README names it.
  - Every number recomputed from the rule file's formula and the API prices; where the result
    differs, the documentation uses the recomputed one: (1) the boundary counts the one read of the
    large context on BOTH sides - keeping reads it at the resume, compacting reads it to compact - so
    it is (S x Pout + w x P x C2) / one wake; the rule file divided (r x P x C + S x Pout + w x P x
    C2) by one wake and so overstated every boundary by just under one wake (Claude Fable 5.1 at
    1M: 1.50 / 0.285 = 5.26 wakes = 2.6 hours, not 1.75 / 0.285 = 6.14 wakes = 3.1 hours); (2) the
    wake's turn is 1K new input written to the cache at the write price plus 300 output (Claude
    Fable 5.1: 0.020 + 0.015 = 0.035 USD); the rule file's rows were not all computed with one
    value - with its own formula its Claude Fable 5.1 150K row gives 10.6 hours (it said 11.5), its
    Claude Sonnet 5.5 rows 1.2 at 1M and 4.5 at 150K (it said 1.5 and 4); (3) the boundaries now
    (hours at 1M, 850K, 500K, 300K, 150K): Claude Fable 5.1 2.6, 3.0, 4.7, 6.8, 10.3 (was 3, 3.5, 5,
    7, 11.5), Claude Opus 5.5 1.4, 1.6, 2.6, 4.1, 6.8 (was 2, 2, 3, 4.5, 7), Claude Sonnet 5.5 0.7,
    0.8, 1.4, 2.2, 4.1 (was 1.5, 1.5, 2, 2.5, 4); the one-wake and compact columns are unchanged but
    for rounding (1M: 0.285 prints 0.29); (4) the worked example keeps for 16 x 0.2475 = 3.96 USD
    plus the resume's read of 0.21 USD, about 4.2 USD (was "about 3.9"); (5) "letting a LARGE
    context expire without compaction is never the cheap way for a wait under a day" became "above
    about 80K tokens, compacting is cheaper than letting the cache expire, however long the wait" -
    compacting wins above (S x Pout + w x P x C2) / ((w - r) x P) = 76K, 77K, 79K tokens, and the
    length of the wait does not enter (keeping, by contrast, does lose to expiry on a long enough
    wait: 48 hours at 1M on Claude Sonnet 5.5 cost 96 x 0.207 + 0.20 = 20.07 USD against 4 USD); (6)
    the third way (compact, then refresh the compact window) pays on Claude Fable 5.1 only for waits
    under about eight to ten hours, not "about nine": 8.3 hours when the host's instructions (about
    40K) are still cached and the 10K summary is written at the first wake, 10.4 hours when the whole
    compact window is already cached - the saving stays under one USD (at most 0.94).
  - Three more coordinator hosts, documented and NOT run live (the operator's decision: each needs a
    setup of its own on the maintainer's machine): README "## Install" gains "### Qwen Code" (0.15.6:
    `qwen extensions install https://github.com/xelth-com/claude-codex-consult:codex-consult
    --consent` installs the plugin from the repository's Claude marketplace into
    `~/.qwen/extensions/codex-consult`, the plugin root substituted in the skill text,
    `hooks/hooks.json` copied but no hook listed; update and removal; the three lines in the
    project's `AGENTS.md` or `~/.qwen/QWEN.md`; not run live: the free Qwen OAuth quota ended on
    2026-04-15), "### OpenCode" (1.17.18: no Claude-layout plugins; one directory LINK per skill into
    `~/.config/opencode/skills/<name>` - a junction on Windows, a symbolic link elsewhere, never a
    copy - after the skill directories of its documentation; `CODEX_CONSULT_ROOT`; the project's
    `AGENTS.md` or `~/.config/opencode/AGENTS.md`; not run live: the provider configured on the
    machine refused the authentication) and "### Muse Code" (1.4.0: `muse skills
    install|update|list|import`; the skills at PROJECT scope, since Muse Code is also a reviewer
    engine and user-scope skills reach the reviewer sessions; `CODEX_CONSULT_ROOT`; the PowerShell
    shell tool, 10 s by default, 300 s at most; not run live as a coordinator: its shell tool needs
    the one-time elevated sandbox setup on Windows). "Hooks on each host", "For the coordinator",
    "Tested on" (one row each, "live coordinator run: none (<reason>)") and the `coordinate` skill's
    "Means per host" (one paragraph each: `-Detach` for an unknown or short tool limit, COMPACT not
    verified) name them. The context files (Qwen Code reads the project's `AGENTS.md` beside
    `QWEN.md`; OpenCode's global `AGENTS.md`; Muse Code's `AGENTS.md`) come from the documentation
    bundled with Qwen Code 0.15.6 and the text of the installed OpenCode and Muse Code binaries - not
    checked live.
  - Tests: `harness-host.ps1` - GREP: a model name ("Claude Fable 5.1") names no host in the skills,
    and "Waiting" joins the README sections that may say "Claude"; SKILL: rule 3 revision 5 (its
    needles, the order of its parts and seven items, COMPACT for all seven hosts), the skill's
    boundary rows and model line recomputed from the formula in `[decimal]` (`Get-WaitNumbers`,
    `Format-Dec`), the three new hosts in "Means per host", "For the coordinator" and the plugin
    README pointing at the section; README: the host sections in order with the three new ones and
    their contents, the three "Tested on" rows, the waiting section (its place, terms, both tables,
    the rule's seven lines, what was measured, the caveats) and every number of it recomputed from
    the formula and the prices.
  - Assertions (each harness alone, Windows PowerShell 5.1 and PowerShell 7.6.6, 2026-09-29 23:09 to
    2026-09-30 00:31, the same counts on both): `harness-host` 58 (+6); the harnesses that read the
    changed documents, unchanged: `harness-telemetry` 55, `harness-fixes27c` 36, `harness-engines` 97,
    `harness-visibility` 121. No full suite: no script changed.

### Changed

- (wave 26) Panels are smaller by default: a `-Panel` without `-PanelSize` now starts the
  purpose's size (see Added) instead of every available entry - pass `-PanelAll` (or `-PanelSize
  <n>`) for the old "everyone" panel. Members are numbered in seat order (the roster order unless
  the panel is routed with evidence). The roster validator's allowlists gain `lab`, `roles`,
  `ext` (entry) and `require`, `ext` (top level): a roster that uses them is refused by an older
  bridge (fail-closed, as always).
- (wave 26b, D2) The ledger's `panel.asked` and the summary's `asked k` are the size REQUESTED (the
  purpose's, `-PanelSize`; `-PanelAll`/`stuck`: every eligible member) - they were the seats after
  the cap.
- (wave 26b, D3) The routing seed's text is length-prefixed (`<len>:<value>` per field and per
  lineage), so the seeds - and the seats a given nonce draws - differ from wave 26's: the golden
  sequences of `harness-companions.ps1` were regenerated with the new reference implementation
  `tests/reference-draw.py` (DRAW: the seed `7469dd58...` of `1:t|7:framing|3:abc|26:6:a :: x,6:b
  :: y,6:c :: z|2:42`, the four-candidate sequences, the exploration count 408 of 2000 (was 419);
  ROUTED: `-PanelSeed 15` seats #2 #4 #1, `CODEX_CONSULT_TEST_PANEL_SEED 18` #1 #4 #5).
- (wave 26b, D9 - supersedes wave 23 D12 for muse) A muse run whose tree check finds a change is
  no longer failed as class `permission`: the bridge runs muse write-disabled
  (`--disable-write --disable-shell`), so the change is not the reviewer's - a warning (`the
  collab directory changed during the run (1 file: .collab/t/state.md) - muse ran write-disabled,
  the change is not the reviewer's`; console, handoff header, the summary, `warnings[]`), the
  reply stays usable, a run failed for its own reason keeps its class. agy keeps the failure
  (F12). `Get-EngineTreeCheck` (new; `Get-EngineTreeProblem` wraps it) and the engine spec's
  `WriteDisabled`; ledger `tree_check {outcome: clean|warned|failed, files[]}` (new, after
  `artifacts_changed_during_review`; `null` for codex).
- (wave 26b) The roster validator's entry allowlist gains `timeout_sec`, `stall_sec` and
  `context_tokens` (an older bridge refuses a roster that uses them - fail-closed, as always).
  `Get-EndpointHealth` also reads the machine-wide health file (D13); ties of the newest record go
  to the later `until`. The main turn's wait is `Wait-EngineProcess` (1 s polls; TEST HOOK
  `CODEX_CONSULT_TEST_WAIT_TICK_MS`) - same timeout as before.
- (wave 26b) New ledger fields, in order: `mode_fallback` (after `mode`), `stall` (after
  `timeout_continue`), `tree_check` (after `artifacts_changed_during_review`); `panel.roles_note`
  (after `routing`); `panel.routing.size_asked` (after `size`) and `reserve` (after
  `size_source`).
- (wave 26, F07-3) The detached-run readers (`Read-DetachedRuns`, `Get-DetachedJudgement`,
  `Get-DetachedPhrase` & co.) and the small helpers they need moved to the new
  `codex-consult-detached.ps1`, which `codex-consult-common.ps1` dot-sources; the SessionStart
  hook dot-sources that file alone instead of the whole common script.
- `Get-PreflightVerdict` gains `Kind`, `Hit`, `Until`, `Credential` and a new order: a
  recorded auth failure or usage limit now outranks a credential that could not be checked
  (an agy entry under `-NoNetwork` with a recorded limit is out, not "not checked"). A quota
  failure without a reset time is out for 60 minutes after it was HIT (the failure's own
  `provider_failure.when`, else the entry's `when`; a time in the future counts as now);
  the roster walk's reason reads `usage limit hit <iso>, reset unknown; retry after <iso + 60
  min>` (was `usage limit <n> min ago, no reset time given`). (Wave 24b, F08-7: an explicit
  `-Provider` run is refused by it too - see Fixed.)
- `codex-providers.ps1` rows are the roster walk's verdict (T3: a quota without a reset time
  now reads `unavailable (usage limit hit ..., reset unknown; retry after ...)` and
  `-Provider` exits 2; an unresolved identity reads `unknown (...)`); `LAST FAILURE` (was
  `LAST FAILURE (24 h)`) also shows an older usage limit that still blocks the endpoint
  (`Get-EndpointHealth` `LastFailure` / `LastLimit`); `-Short` with `-Provider` is refused.
- `Get-EndpointHealth` counts `usable reply (after a timeout continuation)` as a success and
  records `Hit` / `HitIso`; `Until` of a failure without a reset time is `Hit + 60 min`.
- `codex-scoreboard.ps1`: USABLE counts a reply after a timeout continuation.
- `Invoke-GitCapture` returns git's stderr too (`Err`).
- (wave 25) `Stop-WithError` runs `$script:StopWithErrorHook` (when a caller set one) with its
  refusal line before it exits. The summary blocks of a single run and a panel are printed
  through `Write-Summary` (same output). The artifact splitting of `-Artifact` is
  `Split-ArtifactArgument` (same rule). The panel poll loop's member-status variable is
  `$memberStatus` (`$status` is now the `-Status` switch). New parameters at the end of the
  parameter list, so no positional binding moved: `-Detach`, `-Status`, `-Id`, `-Wait`,
  `-WaitTimeoutSec`, `-Prune`, `-DetachId` (internal).
- (wave 27) The ledger entry gains `coordinator` (after `lineage`) and `child_env_scrubbed` (after
  `command`); the field-order checks of `harness-0.3`, `harness-engines` and `harness-muse` follow.
  The SessionStart hook prints TWO lines (the availability line first); `harness-visibility`,
  `harness-detach` and `harness-engines` compare the first. `codex-consult.ps1`: `-Task` is no
  longer a Mandatory parameter (a missing `-Task` is refused - "-Task <id> is required ...", exit 1 -
  instead of PowerShell's prompt; parameter sets were tried and dropped: they end the automatic
  positional binding, which `-Status <id>` bound to `-CollabDir` relies on); two new parameters at the
  END of the list (`-BriefPrefix`, `-Explain`), so no positional binding moved. The dry run prints three
  more lines (`coordinator :`, `child env   :`, `brief prefix:`). The README intro, the plugin's
  and the marketplace's descriptions are host-neutral; a duplicated README paragraph is gone.
- (wave 26c) `-Kick` waits up to 10 s for an acknowledgement (was 60 s for the kick file to
  vanish) and exits `3` when none came; the machine-wide health record of a run is written before
  its ledger entry (was after); the stall cut reads bytes (was complete lines); `Read-StreamGrowth`
  is replaced by `Read-StreamChunk`.

- **Wave 28b - what behaves differently** (details under "Fixed", "Wave 28b"): the telemetry event's
  `provider` is a vendor class and its `model` a name of that vendor's pattern (else `other`),
  `tags` `[provider, model]` (D1); the spool file is named by the LOCAL date and the event is spooled
  AT the commit, a failure being a warning (D6, D16); plain-http intakes need test mode (D4); the
  sender has a 60 s / 8 s deadline, a marker-file lock and an allow-listed environment (D2, D3);
  `codex-telemetry.ps1 -Forget` (D9); every run in test mode warns `test mode is ON: test hooks are
  honoured` and no engine child gets a test variable (D10); the host hint by path only under a host's
  plugin directory of the home, with the new value `qwen-code` (D11); a tool call no longer holds off
  the stall cut past 2 x `-StallSec` of silence (D12); the machine-health retry goes through the
  journal and its outcome is in the summary (D13); the ledger gains `context_window` and codex the two
  `-c` window options (D15); the README host blocks use `CODEX_CONSULT_ROOT` (D17).

- **Wave 28c - what behaves differently** (details under "Fixed", "Wave 28c"): the telemetry
  event's `model` is an entry of a CLOSED list per vendor class, else `other` - no pattern (D1);
  `-Forget -PublicRef <ref> -Local` deletes locally only after the intake confirmed, `-Forget -Local`
  alone asks unless `-Yes` (D2); producers, the salt and `-Forget` share the telemetry lock and the
  forgetting marker (D3); the flush lock is taken over only from a dead owner and carries a token
  checked before each send and rewrite (D4); the flush deadline covers the local steps (D5); the
  sender keeps the proxy and CA-trust variables (D6); the commit's spool append waits at most 1 s
  and is retried after the write lock - its failure is no longer in `warnings[]` (D7); a descendant
  whose start time cannot be read is never killed by pid (D8); a failing `pgrep` falls back to `ps`
  and `/proc` (D9); unreadable health-journal lines go to `<journal>.bad` (D10); the ledger gains
  `compactions` after `usage`, and the prompt of a member with `context_tokens` names the brief again
  (D11); the waiting rule's no-means branch is revision 6 (D14).

- **Wave 28d - what behaves differently** (details under "Fixed", "Wave 28d"): a spool rewrite writes
  `<spool file>.tmp` and replaces the file in one step (D1); the forgetting marker is removed in
  `finally` and a marker whose owner is gone is removed by the next producer or sender, with a line
  in `.last` `notes` (D2); the flush lock is born with its owner record, an ownerless lock is held
  for 30 s, a living owner's lock older than 30 minutes is reported `sender stuck` (D3); the
  not-spooled count is append-only and written without the telemetry lock, `.last` gains
  `not_spooled_seen` and `notes` (D4); a kill with survivors and unverified descendants names both
  (D5); the telemetry model comparison lower-cases both sides (D6); a `context_tokens` member
  without a brief gets its ask repeated at the end of the prompt (D7), and that line stays out of
  the context estimate (D8).

### Fixed

- **Wave 24b - the wave 24 acceptance panel's findings** (`.collab/companions-2026-09-26/`
  F07-1..3, F08-1..8, F13-1/2, and two facts of its ledger):
  - F08-1 (blocker): the MAIN turn started without the fresh launch guard - only the later
    turns re-read the muse sign-in. Every Start-Process of an engine turn now goes through ONE
    guarded start (`Start-EngineProcess`: `Get-EngineLaunchBlock -Fresh`, then the `.cmd`
    %-hazard, right before the start) - the main turn, a denial retry, the continuation, a
    format repair, codex and every engine. A refusal of the main turn withdraws the
    reservation: `the muse run is refused before launch: ...; nothing was started.` Test hook
    `CODEX_CONSULT_TEST_LAUNCH_PAUSE_MS` (a pause between the `launching` record and the start).
  - F08-2: the "no continuation after a changed tree" gate saw only an engine's tree check; a
    codex `-Sandbox workspace-write` run that changed files was continued. ONE tree check for
    every engine (the fingerprints, the brief, the artifacts; an engine's collab directory):
    `not attempted: files changed during the run (the working tree | the collab directory | the
    brief | artifact(s))`.
  - F08-3: the "no continuation after a quota/auth/billing failure" gate scanned a keyword
    filter of stderr and ignored the adapter's class and texts - billing wording (`Insufficient
    balance`, `Payment required`) slipped through. `Get-KilledTurnFailure` runs every candidate
    (the adapter's class and texts, the event error, EVERY stderr line, an SSE payload lifted)
    through the one classifier.
  - F08-4: a failure DURING the continuation (a 429, an auth error) was not the run's
    `provider_failure` (built from the main turn's evidence), so the endpoint health could call
    the reviewer available right after its continuation hit a limit. A continuation that FAILED
    now supplies it - its stderr, its event error, its adapter's class, its `retry_after`.
  - F08-5: any non-empty continuation counted before the substantive and schema checks - a
    `Done.` threw the salvage away while `timeout_continue.outcome` said usable. The
    continuation now counts only after a first reply's checks (`Test-ContinuationReply`: a
    valid object, else substantive prose; `-Raw` / chore: substantive prose); otherwise
    `failed: not a usable reply - <why>` and the salvage is kept.
  - F08-7: the 60-minute rule for a quota without a reset time depended on `-RosterWalk`; an
    explicit `-Provider` run said available with a warning. `Get-PreflightVerdict` applies it
    for every caller (`... named no reset time - out for 60 minutes, until <iso>; nothing was
    started (pass -SkipPreflight to launch anyway)`); `Format-QuotaWarning` warns only under
    `-SkipPreflight` (`... (reset unknown; out until <iso>): <message>`).
  - F07-1: on a prompt-only transport the continuation prompt re-sends the reply format and the
    JSON Schema (as the denial retry does).
  - F07-2: `Read-CodexSalvage` listed a tool item without an id twice (started + completed); an
    id-less item.completed now closes the open item of the same command, else the oldest.
  - F08-6: the printed resume command omitted the run's options; it now carries every
    replay-relevant one (`-TimeoutSec` when explicit, `-ContinueSec` when not the default,
    `-Effort` / `-NativeEffort`, `-MaxWords`, `-SchemaTransport`, `-CodexConfig`, `-Artifact`
    with its resolved paths, `-Range`, `-Sandbox`, `-MaxModelSteps`, `-FormatRetry 0`,
    `-DenialRetry 0`, `-OffPeakOnly`, `-CodexExe` / `-EngineExe`), double-quoting a value with
    other characters than `[A-Za-z0-9._:/\=+@~-]`.
  - F08-8: `-Range` accepted a single revision, which measures the working tree; only
    `base..head` / `base...head` is measured now (`-Range 'HEAD' is not a range of two
    revisions: ...`).
  - F13-1: `codex-providers.ps1 -Json` rows gain `roster_positions` (every position of the
    label) beside `roster_position` (the first).
  - F13-2: `Test-UsableOutcome` matches the two known outcomes exactly (a future `usable reply
    (<x>)` fails closed).
  - F07-3: one listing resolves each entry's identity and each endpoint's health once
    (`Get-CachedReviewerIdentity`, `Get-CachedEndpointHealth`; `-Cache` on
    `Select-RosterReviewer`, `Select-PanelMembers`, `Get-RosterAvailability`); `codex login
    status` already ran once per listing.
  - The ledger's kimi :: k3 failure `unexpected status 401 Unauthorized: Your current plan
    supports only k3 up to 256K context ...` was recorded as `auth` (a 24-hour refusal of the
    endpoint). A context-window limit of the plan or the model is class `capability` now
    (`$script:ContextOverflowPattern`, tried before auth; a text that names a usage limit stays
    quota), an entry recorded as auth with such a text is read as capability, and the summary
    (`hint       : context too long for this plan/model - narrow the brief ... or choose a model
    with a larger context window`) and the handoff header (`Hint:`) say what to do
    (`Get-FailureHint`). The byteplus 429 of the same ledger (`exceeded retry limit, last
    status: 429 Too Many Requests, request id: ...`) names no reset time - quota, the 60-minute
    rule; an echoed `Retry-After: N` was already read.
  - Tests: `harness-visibility.ps1` sections `UNIT24B` and `GATES` (fake knobs
    `FAKE_CODEX_WRITE`, `FAKE_CODEX_STDERR_FIRST`, `FAKE_CODEX_RESUME_FAIL`); the "only warns"
    cases of `harness-0.3.ps1` and `harness-roster.ps1` now expect the refusal and the
    `-SkipPreflight` warning; the CONT case whose killed turn names a usage limit runs in a
    repository of its own (that limit now keeps the endpoint out for every later run there).
    Assertions (Windows PowerShell 5.1): `harness-visibility` 100 (was 76), `harness-0.3` 229
    (227), `harness-roster` 118 (117); the other harnesses unchanged.
- **Wave 24c - the wave 24b re-acceptance panel's findings** (`.collab/companions-2026-09-26/`
  F15-1..6, the F08-4 residual and the F08-2 ruling) **and two defects of the same panel's live
  ledger**:
  - F15-1 (major): the context-overflow exception (a 401/403 whose text names a context window ->
    capability) excluded only the usage-limit wording; billing, payment, an insufficient balance,
    credits or a token plan next to a context window was forced to capability - a continuation
    after a billing failure, the endpoint left available. `Test-ContextOverflow` now excludes the
    COMPLETE quota pattern (quota wins); an entry wave 24b recorded as capability with such a text
    is read as quota.
  - F15-2 (major): the listing's identity/health cache was a case-insensitive `@{}` - `ZAI ::
    glm-5.3` and `zai :: GLM-5.3` shared one slot (identity, fingerprint, health). `New-ListingCache`
    makes an ORDINAL hashtable, the keys are case-preserving and length-prefixed
    (`Get-ListingCacheKey`), and only such a cache is used (a plain hashtable is ignored: the
    identity is then resolved every time); `codex-providers.ps1` uses it.
  - F15-3: `Get-KilledTurnFailure` classified EVERY stderr line - an informational line with
    `auth`, `billing` or `429` in it blocked a permitted continuation. Structured evidence first
    (the adapter's class, the event stream's error, the adapter's texts, a provider error payload
    on stderr - `ConvertFrom-ProviderErrorText` now says `Found`), then only DIAGNOSTIC stderr
    lines (`$script:DiagnosticStderrRe`: ERROR/FATAL level, or an HTTP status with its message),
    never a known informational engine message (`$script:InfoStderrRe`: codex's models refresh -
    logged at ERROR level with the whole models list in it -, its fallback-metadata notice,
    `Reading prompt from stdin`; muse's notices); an agy stderr tail copied into the adapter's
    texts is judged as that line.
  - F15-4: the context hint was re-derived from the stored message (cut to 200 characters, without
    the code) - a code-only `context_length_exceeded` lost it. `New-ProviderFailure` decides it at
    classification from the code and the FULL message and stores it (`provider_failure.hint`,
    `Get-ClassHint`); `Get-FailureHint` reads it (an entry recorded before: from its code +
    message).
  - F15-5: the printed resume command also carries `-ReplyName` (when given; a panel member's own
    `<name>-<provider>`) and `-SkipPreflight`.
  - F15-6: `Invoke-EngineTurn` restored the recovery record after a launch refusal only; a
    Start-Process error (a launcher gone) left it `launching`. Every path that starts nothing now
    gives it its previous state back (on disk and in memory; a failed record write too), and so
    does the codex format repair's start.
  - F08-4 residual: a continuation reply the checks REJECTED (not a provider failure) was
    discarded. The partial file keeps it after the turns under `## continuation reply (rejected:
    <why>)`, and `timeout_continue.outcome` ends `; its text is kept in
    handoffs/<NN>-<engine>-<slug>.partial.md under "continuation reply (rejected)"`.
  - F08-2 ruling: `.collab` changes stay outside a codex run's continuation gate - by design (the
    codex engine never snapshots the collab directory: it cannot tell its own writes from others');
    the README says so (`Residual (codex)`). No code change.
  - The tree check fired with ZERO changed files (companions n=13, a muse member: `the working tree
    changed during the run ...: 0 files:`): the coordinator committed the collab files while it
    ran (HEAD moved, no file changed), and the fingerprint has HEAD (and the staged state) in it. The
    tree check now compares file CONTENTS (`Get-RevisionInfo` `content_sha256`: every tracked
    file's blob from `git ls-files -s`, the worktree's blob for a path git status lists, every
    untracked file's; never HEAD, the commit id or the index's metadata; `Compare-TreeContent`) -
    for the engines' tree check, the continuation gate and `tree_changed_during_review`. A moved
    HEAD is ledger `revision_moved` (`"<old base_commit> -> <new>"`, else `null`; right after
    `tree_changed_during_review`) and a `Note: HEAD moved during the review (<old> -> <new>) - no
    file content changed: not a tree change.` header line; `tree_sha256` (the review binding),
    `base_commit` and `reviewed_revision` are unchanged.
  - A burst 429 is not a 5-hour quota: ModelArk (BytePlus) answers `exceeded retry limit, last
    status: 429 Too Many Requests, request id: ...` for burst/concurrency limits that recover
    within minutes (nonblocking n=2, companions n=6 and n=12), and every 429 without a reset time
    was out for 60 minutes. `provider_failure.kind` (right after `class`; `Get-FailureKind`):
    `burst` when a quota 429's text names no usage window or quota - out for 10 minutes (the walk:
    `burst limit (429) hit <iso>, reset unknown; retry after <iso + 10 min>`; the refusal `... it hit
    a burst limit at <iso> (<message> - a 429 that names no usage limit or quota) and named no reset
    time - out for 10 minutes, until <iso>; ...`; the one-line view `burst limit hit <t>, ...`); a
    429 that names a usage limit, a quota, a balance, credits, billing, a token plan, an
    hour/day/week/month window or a reset keeps the 60-minute rule; an entry recorded without
    `kind` is judged from its message (`Get-EndpointHealth` `FailureKind`, `OutMinutes`).
    `provider_failure` is now `{class, kind, code, message, when, retry_after, hint}`.
  - Tests: `harness-visibility.ps1` sections `UNIT24C` (in-process; F15-6 runs `Invoke-EngineTurn`
    taken from the AST of `codex-consult.ps1`), `GATES24C` and `BURST` (end to end; fake knobs
    `FAKE_CODEX_COMMIT`, `FAKE_MUSE_COMMIT`) and two F08-4 residual checks in `GATES`; the
    60-minute cases of `UNIT`, `AVAIL` and `QUOTA60` use a 429 that names a usage limit (a bare 429
    is a burst now); the F08-3 cases put the billing line on an ERROR-level stderr line; the resume
    commands of `CONT`, `CONTAGY`, `PANEL` and `GATES` F08-6 carry `-ReplyName`; the ledger field
    order (`revision_moved`) in `harness-0.3`, `harness-engines` and `harness-muse`, the
    provider_failure field order in `harness-roster`. Assertions (Windows PowerShell 5.1):
    `harness-visibility` 121 (was 100); the other harnesses unchanged.
- T2 (the providers view disagreed with the roster walk): the listing read the endpoint
  health of the repository it ran in - silently - and its rows used a second implementation
  of the verdict (a quota without a reset time read `available`; a usage limit hit days ago
  showed `LAST FAILURE -`). Run in another repository, it saw none of the failures the panels
  had recorded and printed `available`, `-` and `would select`. Now the rows, `-Short`, the
  hook and the walk share one verdict, the listing names its health source, and LAST FAILURE
  shows a still-blocking limit.
- T3: the SessionStart line and the listing said available after a 429 without a reset time.

- **Wave 26 - the wave 25 acceptance's carry-overs** (`.collab/nonblocking-2026-09-26/`, findings
  F07-1..3, F08-1..2, F11-1..2):
  - F07-1, F08-1, F11-1: an unreadable status file (empty, unparseable, no id, bad state) was never
    pruned and failed every aggregate `-Status`/`-Wait`, `-List` and the hook forever. `-Status
    -Prune` now removes it (and its log) once the FILE was last written more than 7 days ago; for
    a younger one `-Status` prints the command that removes it by hand.
  - F07-2: the never-started judgement no longer says `nothing was run`: "... if one starts late it
    still reports and the run reads running again (its log may say why)"; `-Prune` removes a
    never-started run only when its log was not written in the last 7 days either.
  - F08-2: the background's final status write (and the run's own final write) is retried 3 x 250
    ms; when it still fails the background prints "... its status file could not be made final -
    the result exists only in this log (<log>) ..." and exits 6 (a distinct code).
  - F11-2: a never-started `starting` record kept an inline `-Prompt` in its `args`: the prompt now
    goes to `<task>/.consult.detached-<id8>.prompt.txt` (git-ignored), the record's args name only
    that file (`PromptFile`); the background reads and removes it; `-Prune` removes a left-over one.
  - Tests: `harness-detach.ps1` section `CARRY` (6 assertions).
  - F10-1 (killing only the background panel parent leaves its members running) stays an accepted
    residual (Known limitations).
- **Wave 26b - the wave 26 acceptance's findings** (`.collab/companions-2026-09-26/`, handoffs
  18-22, decisions D1-D8 of handoff 23):
  - D1, F22-1 (major - a role file could follow a symlink or junction out of the roles
    directory, and its text goes to external reviewers): `Resolve-RoleFile` accepts only a
    regular file - no reparse point on the file or on any directory from the roles directory down
    to it, the roles directory included (`Get-RoleFileProblem`; attributes read without following
    links; a dangling link is refused too) - whose full path lies inside `<CollabDir>/roles`; the
    plugin's `templates/role-<name>.md` likewise inside `templates`. Anything else refuses the run
    (`-Role: role file refused: <why>` / `-Roles: ...`) before any prompt, handoff, ledger entry,
    recovery record or process exists - with no fallback to the plugin's template.
  - D2, F19-1 (the clamped panel size was recorded silently): `Select-PanelRouting` returns
    `SizeAsked` and the ledger keeps `panel.routing.size_asked` beside `size`; fewer eligible than
    asked warns `panel size reduced: asked k, eligible m` (console, every member's handoff header
    and `warnings[]`); the summary's `asked k` is the request (see Changed).
  - D3, F22-2 and F22-4 (the matcher's and the seed's delimiters inside roster strings): the
    validator refuses a provider label or model with surrounding blanks (as before) or containing
    `::`, `[`, `]`, `|`, `,` or `#` (`roster entry #n: provider must not contain '::'`;
    `Get-RosterStringProblem`; an engine is one of the known names already); the seed text
    length-prefixes every field (`ConvertTo-LengthPrefixed`) - see Changed.
  - D4, F22-3 (greedy role assignment could break a willingness a full assignment honours):
    `Select-RoleAssignment` is an exact matching (`Test-RoleMatching`, `Find-RoleAugment`): a role a
    seated member is willing to take goes to a willing member, each role in order to the
    best-ranked member possible; only when no such assignment exists the wave 26 greedy order, and
    the run says so (`Note` -> a warning and the ledger's `panel.roles_note`). Deviation: the
    decision's "small exhaustive matching (<= 8 x 8)" is realised with augmenting paths - the same
    (lexicographically best) assignment for any size, no enumeration bound.
  - D5, F22-5 (required pins consumed seats before the lab reserve): `Invoke-PanelDraw` states the
    reserve over the seats left after the pins - `min(K - the pinned, labs >= neutral the pins did
    not seat)`; the draw is unchanged (the harness compares 360 draws with the wave 26
    formulation: identical); `panel.routing.reserve` records the reserve seats applied.
  - D6, F22-6 (a legacy rating with a provider but no model or purpose was not completed):
    `Read-AllTaskRatings` joins by `consult_id` when ANY of provider, model, purpose, engine,
    consult_when (or topics) is missing.
  - D7, F22-7 (UNIQ location keys were case- and prefix-sensitive): `codex-scoreboard.ps1`
    `ConvertTo-LocationPath` - `\` -> `/`, runs of `/` collapsed, a leading `./` dropped, lowercase
    on Windows; the line exact; keys compared ordinally.
  - D8, F19-2: wontfix by design (a routed panel reads the findings stores once per run).
  - Deviations and interpretations (the rest are as written): D1 - this account cannot create file
    symlinks, so the harness's first case is the decision's fallback, a directory junction named
    like a role file (the code refuses either by the reparse attribute). D10 - the MEMBER polls its
    kick file (the panel parent cannot stop a member's engine tree without killing the member's own
    bridge, which must salvage and record); `-Kick` also stops a single run by its number. D12 - the
    cut watches the main turn (the secondary turns have their own budgets); `last_event` is when the
    bridge saw the last complete line. D13 - "the later until wins" is one record set (file +
    ledgers) in which the newest record decides, as within a ledger, same-time ties by the later
    `until`; records also carry `retry_after` so a failure without a named reset keeps its 60/10
    minute window; only a panel waits on the machine-wide count (a single run's row counts for
    panels). D16 - the skip's estimate is (ask + brief) / 4 before any reviewer is chosen; an
    explicit `-Provider` run is refused instead of skipped.
  - Assertions (Windows PowerShell 5.1): the final `tests/run-all.ps1` run - `harness-0.3` 229, `harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74 (+2), `harness-panel` 54, `harness-pending` 26, `harness-fixes` 43 + the 2 environmental F04-10 cases (the user's own codex.exe runs; never killed), `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121, `harness-detach` 51, `harness-companions` 42, `harness-fixes26b` 39 (`run-all: 14 harness(es), 1 failed` - that one F04-10). Updated for the new behaviour: the ledger field order in `harness-0.3`, `harness-engines`, `harness-muse`, `harness-format`; `harness-visibility` GATES24C (a muse content change is now a warning); `harness-companions` (the goldens, the allowlist message, the floor case's size warning). PowerShell 7: `harness-0.3` 229, `harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74, `harness-panel` 54, `harness-pending` 26, `harness-fixes` 43 + the 2 environmental F04-10 cases (the user's own codex.exe runs; never killed), `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121, `harness-detach` 51, `harness-companions` 42, `harness-fixes26b` 39 (its KICK section rerun alone after a pwsh-only fix: `-Kick` compares the recorded child start time as `ConvertTo-StartIso`).
- **Wave 26c - the wave 26b re-acceptance's findings** (`.collab/companions-2026-09-26/`, panel
  a011f18e: F25-1/2, F26-1..6; decisions D1-D6 of handoff 27; implemented in the wave 27 worktree):
  - D1, F26-1 (major - a kick written in the instant a member finished was never consumed and
    stayed for the next run), F25-2 (note - a kick between two turns overwrote a usable reply):
    `Wait-EngineProcess` checks the kick file BEFORE its wait loop (a live turn only), on every
    poll, and ONCE MORE after the process exited - a kick found then is taken LATE (`KickLate`):
    `warnings[]` `kick_late: the member had already finished (<the turn>) - the kick changed
    nothing`, the outcome unchanged. Every taken kick is acknowledged by `Confirm-Kick`:
    `<task>/.consult.kick-<NN>.ack` (`kicked` | `late`), the kick file removed; a run removes a
    stale ack with a stale kick file at its start. `-Kick` waits up to 10 s for the
    acknowledgement: exit 0 acknowledged (the message says which), 1 no such running member (a
    kick file of that number is removed), 3 none in time (the kick file stays for the member's next
    poll). A kick that stops only the FORMAT REPAIR leaves an earlier usable reply usable
    (`$script:KickedTurn`; `warnings[]` `kick: the operator stopped the format repair (-Kick); the
    first reply stands, not converted`; no operator class); a kicked main turn, continuation or
    denial retry fails the run as before. `.gitignore` (and the README's list): `.consult.kick-*`.
  - D2, F26-2 (major - a machine-wide health update could be lost silently, and the stored `until`
    did not take part in the tie-break): `Update-MachineHealth` waits for `<file>.lock` in three
    attempts of 5 s (TEST HOOK `CODEX_CONSULT_TEST_HEALTH_LOCK_SEC`) and records why it did not
    write (`$script:MachineHealthLastError` = `lock timeout`); a run writes its outcome record
    BEFORE its ledger entry, retries a lock timeout once at the ledger commit, and if that fails
    too warns `machine-wide health not updated (lock timeout)` (`warnings[]`, the summary) - the
    repository ledger keeps the truth. `ConvertTo-MachineHealthEntries` carries the stored `until`
    (and `retry_after`); `Get-EndpointHealth` uses it as the record's `until`, so two records at
    the same moment are decided by the later `until`.
  - D3, F26-3 (major - one long silent tool call was cut as a stall), F25-1 (minor):
    `Wait-EngineProcess -Engine`: the silent timer resets on ANY growth of the stream
    (`Read-StreamChunk`: bytes; the complete lines decoded as UTF-8 with the unfinished last line
    carried over) and is SUSPENDED while a tool call is in flight (`Update-ToolFlight`: codex
    `item.started` of `command_execution`, `mcp_tool_call`, `web_search` until its
    `item.completed`; an agy `tool` step `ACTIVE` until another state; a muse task proposed as
    `tool.*` until its `task.lifecycle` end); the timeout stays the hard bound. The continuation
    prompt says "Your previous turn was stopped after no output for N s outside a tool call.".
  - D4, F26-4 (minor): `Read-AllTaskRatings` counts a rating's field as missing when it is absent
    OR empty / white space (an empty `topics` list too - `Test-BlankField`), joins the ledger by
    `consult_id` for any missing one and takes the entry's value for it.
  - D5, F26-5 (minor): more required reviewers than the size asked raise it and say so - `panel size
    raised: asked k, required r` (console, handoff header, `warnings[]`),
    `panel.routing.size_source` `required`, `size_asked` the request; the dry run's `Routing:` line
    says `size r (required; asked k)` (and `; asked k` for a reduced size too).
  - D6, F26-6 (note, wontfix): README "Roles" says it - a hard link is indistinguishable from the
    file, the check and the read are separate steps; the check defends against reparse points and
    paths outside the roles directory, not against a hostile repository.
  - Tests: `harness-fixes26b.ps1` + KICKACK (4: a late kick, a kick before the loop, `-Kick` exit 3
    then 1 against a fabricated running record, a kick of the format repair only), HEALTHLOCK (2:
    the stored-until tie-break, the lock held elsewhere), STALLTOOL (4: the flight tracker for the
    three engines, an 8 s silent tool call, a 7 s byte drip, the continuation's wording), JOINBLANK
    (1), SIZERAISE (1). `fake-codex3.ps1`: `FAKE_CODEX_TOOL_OPEN`, `FAKE_CODEX_DRIP`.
- **Wave 27c - the fix round of the waves 26c/27/27b acceptance** (panel 222af1cb on c6f6966: glm
  ACCEPT, mimo HOLD, dola-seed ACCEPT, qwen3.8-max ACCEPT; findings F29-1..2, F30-1..9, F32-1..11;
  the live host checks H1-H4 and the Z Code run; decisions D1-D24 of
  `.collab/companions-2026-09-26/handoffs/33-claude-wave27c-decisions.md`). Code in
  `codex-consult-common.ps1` (C) and `codex-consult.ps1` (B) unless named.
  - D1 (F30-1 major, F29-2, F32-1, F30-6) the kick per request: `Read-KickRecord`,
    `New-KickRequest` (a `{id, when, pid}` record written to a temporary file and renamed only when
    absent - a second caller JOINS it), `Clear-StaleKickAck` (an acknowledgement older than 60 s of
    another id: swept by any `-Kick` and by the member's run start), `Confirm-Kick` (the
    acknowledgement `{id, result: stopped | late, when, pid}`, atomic) (C); the `-Kick` caller waits
    for ITS id, only the creator retires the acknowledgement (after a 1 s grace for joiners), none
    removes one before writing (B, the `-Kick` block; the run start's sweep). The acknowledgement's
    result word is `stopped` (was `kicked`).
  - D2 (F30-5) a kick of the TIMEOUT CONTINUATION keeps the timeout outcome and its salvage (no
    provider failure from the cancelled turn), `warnings[]` `kick: the operator stopped the timeout
    continuation (-Kick); ...` (B, `$kickedContinuation` before the provider failure) - a small code
    alignment beside the documentation, since the code replaced the outcome by the operator's.
  - D3 (F30-2 major) `Hide-HostMarkers` is transactional - the snapshot first, the removals in
    `try`, a failing removal puts everything back and throws `host markers could not be hidden
    (<name>: <why>)`; `Invoke-WithoutHostMarkers` (C). `Start-EngineProcess` refuses the start with
    `bridge failure: host markers could not be hidden (...)`; the detached background, the version
    probe and (wave 28) `Start-TelemetrySender` go through it too. Test hook
    `CODEX_CONSULT_TEST_HIDE_FAIL`.
  - D4 (F30-4) `Remove-HostMarkersFromStartInfo` returns why a block is not clean; `Start-ProbeProcess`
    / `New-ProbeStartInfo` (C): the start-info path, else a FRESH start info while the markers are
    hidden from the process environment, else the probe is skipped - `codex login status`, `agy
    models`, `Invoke-LauncherCapture` read `not checked - ... was skipped: ...` and the run's
    `warnings[]` says why (`$script:ProbeWarnings`). Test hook `CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL`.
  - D5 (F30-3 major, F32-8) `Read-StreamChunk` scans only the new bytes (`[Array]::IndexOf`), keeps a
    carry of at most 1 MiB, skips a longer line to its end and counts it (`Discarding`, `Oversized`);
    `Wait-EngineProcess` reports `Oversized`, the run warns once `oversized_lines: N ...` (C, B).
  - D6 (F32-7) the tool-call suspension of the stall cut ends after max(3 x `-StallSec`, 1800 s)
    (test hook `CODEX_CONSULT_TEST_TOOL_CAP_SEC`); the silent time then counts from the last byte and
    the outcome says `- no output for N s (a tool call open for M s)` (`Wait-EngineProcess` ToolOpen;
    B's stall text).
  - D7 (F30-7, F29-1, F32-3) `Update-MachineHealth` names EVERY failure (`lock timeout`, `the directory
    ... does not exist`, `write failed: <why>`) and every failure is retried (B: `$machineHealthCause`).
  - D8 (F32-2) `Update-MachineHealth -Attempts -AttemptSec` (C); inside the write lock ONE attempt of
    at most 1 s, the ledger warning `machine-wide health not updated at the commit (<cause>); retried
    after it`; the full retry (3 x 5 s) after `Exit-StoreCommit`, the summary line `warning    :
    machine-wide health not updated (<cause>)` when it fails again (B).
  - D9 (F30-8, F32-6) `Resolve-CoordinatorIdentity -Defaults` (`Get-CodexConfigDefaults`) resolves a
    TRIPLE; `Get-CoordinatorMatch` (own | provider | ''), `Format-CoordinatorWarning -Kind provider`
    ("a reviewer from the coordinator's own provider (model not named)") (C); both warning sites (B).
  - D10 (F30-9) `Get-IdentityStringProblem` - the one character rule of the roster's provider and
    model strings and of the coordinator value (C; the roster validator calls it).
  - D11 (F32-4) `coordinator.in_roster`; the console line and the dry run's `(not in the roster - no
    reviewer can match it)` (`Format-CoordinatorText`, `Format-CoordinatorId`; B after the resolution).
  - D12 (F32-5) `#n` naming no position: `coordinator.unresolved`, the warning `CODEX_CONSULT_COORDINATOR
    '#n' names no roster position here ...` in every entry of the run; only an unparseable value is
    refused.
  - D13 (F32-9) the hook's pointer line carries the full `-Explain coordinate` command with the
    script's own path (`codex-consult-hook.ps1`); `-Explain` replaces `${CLAUDE_PLUGIN_ROOT}` by the
    plugin directory (B, the `-Explain` block).
  - D14 (F32-10) `Test-TestMode`, `Get-TestHookValue`, `Get-IgnoredTestHooks` (C): every
    `CODEX_CONSULT_TEST_*` read (and `CODEX_CONSULT_NOW` - an extension: it is a test hook too) goes
    through the gate; without `CODEX_CONSULT_TEST_MODE=1` it is ignored and the run warns once
    (`test hook(s) ignored - ...`). Every harness and `run-all.ps1` set `CODEX_CONSULT_TEST_MODE=1`.
  - D15 (F32-11) `-Explain` disposes its output stream (`try`/`finally`).
  - D16 (H4 major) `Get-DescendantTree` (the enumeration and whether it was denied),
    `Invoke-TaskKillTree`, `Stop-ProcessTreeChecked` (C; `Stop-ProcessTree` stays its wrapper); the
    three turn kills (main, `Invoke-EngineTurn`, the codex repair) use it through `Add-KillCheck` /
    `Format-KillText` (B): `(process tree killed)` only when confirmed, else `(kill not confirmed:
    <why>; pid <n> may still run)`, a warning, NO continuation (`timeout_continue.outcome` `not
    attempted: the kill of the main turn was not confirmed ...`), ledger `kill_confirmed` (a NEW key
    right after `stall`: `null` no kill, `true`, `false`). Test hook `CODEX_CONSULT_TEST_KILL_DENIED`
    (the enumeration and taskkill denied).
  - D17 (H1) `plugins/codex-consult/README.md` (new, short); the skills define "the README" as the
    repository README with its URL. D18 (H2) `powershell` on Windows, `pwsh` elsewhere and the
    WindowsApps alias - README, the three skills. D19 (H3) README "Codex CLI": what was observed in the
    sandbox. D20 any `ZCODE_` variable is the `zcode` hint (after the codex markers, before
    claude-code), else the install path (`Get-CoordinatorHostHint`; `coordinator.host_by`). D21 the
    WHOLE prefix `ZCODE_` is scrubbed (the names read inside a Z Code session, 2026-09-29, desktop
    3.14.3; the exact `CLAUDE_CODE_` names stay exact). D22 the brief templates say `# Handoff <NN> -
    <coordinator>: <slug>`; harness-host's D6 grep covers `templates/`. D23 README: where the three
    `AGENTS.md` lines go per host (`~/.codex/AGENTS.md`, `~/.zcode/AGENTS.md`, Kimi Code the project
    file only); `consult-codex`'s first section: no `codex-consult:` line - run the hook one-liner.
    D24 `consult-codex` and `coordinate`: a shell tool whose limit is shorter than the purpose's
    timeout, or unknown - `-Detach`, then `-Wait` / `-Status`; the limits seen (Kimi Code 300 s, Z
    Code 600 s, 2026-09-29).
  - Tests: `tests/harness-fixes27c.ps1` (new, registered in `run-all.ps1` after `harness-telemetry`):
    TESTMODE, HIDE, STREAM, HEALTH, COORD, POINTER, KILL, KICK, ZCODE, DOCS. Changed expectations:
    `harness-host` (the record's keys and resolved triples, the refusals of an unparseable value only,
    `#5` no refusal, the pointer line, `-Explain`'s substitution, the ZCODE_ hint and two observed
    names in its marker set, the templates grep), `harness-fixes26b` (KICKACK: the JSON
    acknowledgement; HEALTHLOCK: the commit's wording), the ledger field order (`kill_confirmed`) in
    `harness-0.3`, `harness-engines`, `harness-format`, `harness-muse`.
  - Deviations: (1) D16's `pid <n>` is the root's pid - when the root exited and its children could
    not be enumerated, the why says "the root exited, its children may not have"; (2) the D11 console
    line is printed for a run the coordinator started (and the `-Detach` foreground), not by a panel
    member or a detached background; (3) `oversized_lines` is a warning, not a ledger key (the
    ledger's field order is asserted by five harnesses); (4) D14 covers `CODEX_CONSULT_NOW` too; (5)
    D20's path hint needs `<dir>/plugins/` under `.zcode`, `.codex` or `.claude` (a checkout under
    `.claude/worktrees/` is no install); (6) the shell tool limits of Claude Code and Codex CLI are
    listed as not measured.
  - Assertions: `harness-fixes27c` 36 (new), `harness-host` 52 (+2); the final `tests/run-all.ps1` runs of 2026-09-29 (Windows PowerShell 5.1, then PowerShell 7.6.6 from 20:29 to 22:19), the same counts on both, `17 harness(es), 0 failed`: `harness-0.3` 229, `harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74, `harness-panel` 54, `harness-pending` 26, `harness-fixes` 45 (the two F04-10 cases passed this time), `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121, `harness-detach` 51, `harness-companions` 42, `harness-fixes26b` 51, `harness-host` 52, `harness-telemetry` 55, `harness-fixes27c` 36.

- **Wave 28b - the fix round of the waves 27c/28/27d acceptance** (panel a0d1d2a5 on 1de388e: glm
  and qwen ACCEPT, mimo HOLD on F36-1..5; decisions D1-D19 of
  `.collab/companions-2026-09-26/handoffs/39-claude-wave28b-decisions.md`):
  - D1 (F36-1, major): the telemetry event carried the roster label and the model as typed. Now
    `provider` is the VENDOR CLASS of the endpoint's host (or of the engine) from ONE table in
    `codex-consult-common.ps1` (`$script:TelemetryVendors`: `openai`, `zai`, `xiaomi`,
    `byteplus`, `moonshot`, `alibaba`, `google`, `meta`, else `other`), and `model` is the name
    only when that vendor is known and the name follows its pattern (else `other`); the `tags`
    carry the same two values (`[provider, model]`, before `[engine, provider label]`). The ledger
    and every local file keep the real label.
  - D2 (F36-2, major): the sender had no deadline. One flush ends after 60 s, one request
    (connect, send, read) after 8 s - HttpClient with the answer buffered inside its timeout, a
    cancel at the bound and a hard wait (test hooks `CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS`,
    `..._FLUSH_MS`); a 429 is waited for only when its `Retry-After` fits the deadline. The lock
    `<spool>/.flush.lock` is a marker file `{pid, start_time, token, since}` released in `finally`;
    one older than 5 minutes, or whose owner is gone, is taken over (under an exclusive handle).
  - D3 (F36-3, major): the sender inherited the bridge's environment. It now starts with an ALLOW
    list (`Get-TelemetrySenderEnvironment`: the system, locale and proxy variables, `CODEX_HOME`,
    `CODEX_CONSULT_TELEMETRY`, `CODEX_CONSULT_TELEMETRY_URL`, in test mode the test mode and the
    sender's own hooks) built into the `ProcessStartInfo` after clearing it; on Windows it is
    created by `CreateProcessW` without handle inheritance (`Start-NoInheritProcess`, compiled once
    per process) - the bridge's own environment is never changed for it. The hook
    `CODEX_CONSULT_TEST_TELEMETRY_ENV` now dumps every variable NAME of the sender.
  - D4 (F36-9, F37-4): plain http to a loopback intake only with `CODEX_CONSULT_TEST_MODE=1`.
  - D5 (F36-9): the salt is created atomically - a temporary file moved without overwriting, the
    loser reads the winner's salt, a salt that parses is never deleted; one that does not parse is
    moved aside (`telemetry-salt.bad-<guid>`), and moved back when it turns out to parse.
  - D6 (F35-1, F36-8, F37-6): an event that could not be spooled was dropped silently. The event
    is now spooled AT the commit (inside the write lock, right before the entry is added), the
    append waits up to 5 s, and a failure puts `telemetry event not spooled (<why>)` into the
    entry's `warnings[]` and onto the console; `-Status` counts the events not spooled since the
    last flush (`<codex home>/telemetry-not-spooled.ndjson`, reset by every flush).
  - D7 (F36-7, F37-5): a complaint kept in the spool is the EXACT text that was shown and sent at
    once; the deferred send posts those bytes.
  - D8: the sender against the intake as it is built - `400` `events[i]: <reason>`: event i
    dropped (a line in `.last` `rejected`), the rest resent, at most three times per flush; `413`:
    the batch halved (an event refused alone dropped); `403`: the flush stops, the spool kept, the
    reason said; any other 4xx: the spool kept, the reason said.
  - D9: delete my data - `codex-telemetry.ps1 -Forget -PublicRef <ref>` (`DELETE
    <intake>/v2/instances/<instance id>?public_ref=<ref>`) and `-Forget -Local` (the spool, the
    salt, the not-spooled count); the README says the intake is live.
  - D10 (F36-5, major): test mode could leak or stay unnoticed. A run with
    `CODEX_CONSULT_TEST_MODE=1` says `test mode is ON: test hooks are honoured` (console,
    `warnings[]`; a panel run's plan too); `Hide-HostMarkers -TestVars` (every engine turn, the
    version probe) and the probes' start info drop `CODEX_CONSULT_TEST_MODE` and every
    `CODEX_CONSULT_TEST_*`; a panel member and the detached background (the bridge itself) keep
    them (`Remove-HostMarkersFromStartInfo -KeepTestVars`). No fake relied on a test variable.
  - D11 (F36-4, major): the host hint by path matched `.claude`/`.codex`/`.zcode` anywhere in the
    path. It is now anchored at the hosts' plugin directories of the home (`Get-HostPluginRoots`:
    `~/.claude/plugins/cache`, `~/.codex/plugins/cache`, `<codex home>/plugins/cache`,
    `~/.zcode/cli/plugins/cache`, `~/.qwen/extensions` - a new hint value `qwen-code`).
  - D12 (F36-11, F32-7): an open tool call suspended the stall cut until the 1800 s floor. The
    suspension now ends after 2 x `-StallSec` without growth of the stream (no floor, no completion
    event needed), and the cut names the open call (`Wait-EngineProcess` `OpenTools`,
    `Update-ToolFlight -Labels`).
  - D13 (F36-6, F37-1): the machine-health update lived only in memory between the commit and the
    retry, and the ledger never said how the retry ended. At the commit the record goes into the
    journal `<health file>.journal` (a local append); the warning says `a retry follows the
    commit`; the retry after the lock - or the next run of any repository - applies the journal
    (idempotently) and empties it; the summary (and a detached run's status record) carries the
    retry's outcome. The one in-lock attempt of wave 27c is gone. Test hook
    `CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST`.
  - D14 (F37-2, F37-3): the kill check counted a recycled pid as a survivor, and a host without
    `pgrep` could not enumerate children. The enumeration records each descendant's start time
    (the check and the kill use it), and falls back to `ps -A -o pid=,ppid=`, then `/proc`
    (`ConvertFrom-ProcessTable`, `Get-TreeFromPairs`).
  - D15: a roster `context_tokens` never reached the engine (the k3 member failed with 401 in the
    middle of a review). A codex reviewer now gets `-c model_context_window=<n>` and `-c
    model_auto_compact_token_limit=<0.8 n>` on every turn (both keys verified in the installed
    codex-cli 0.155.1 binary; a value in `-CodexConfig`/`codex_config` wins); ledger
    `context_window` (after `extra_config_source`).
  - D16: days are LOCAL - the rollout search (`Get-LocalDayDirs`: every local day from the start to
    now, invariant digits - the old `'{0:yyyy}' -f` followed the culture's calendar) and the spool
    file name (`Get-TelemetrySpoolName`). The health file names no day.
  - D17, D18 (F36-10): the host sections' command blocks use ONE name for the plugin directory,
    `CODEX_CONSULT_ROOT`, defined in the same block; the hook block works copied as written (it
    finds the newest install when the variable is unset). The waiting section names a full wake and
    a cache read apart, and a compaction after the expiry costs a cold resume PLUS the summary.
  - D19: `harness-pending` (e) injects the registration failure through the new hook
    `CODEX_CONSULT_TEST_REGISTER_FAIL` (never a patched copy); (e) and `harness-fixes` F04-11 report
    FAIL rows instead of stopping with an exception.
  - Deviations: D10 - the sender keeps `CODEX_CONSULT_TEST_MODE` and its own
    `CODEX_CONSULT_TEST_TELEMETRY_*` hooks in test mode (D3's "in a harness the test mode
    variables"; D4 needs test mode in the sender to reach a harness's local intake), and
    `child_env_scrubbed` keeps naming the host markers only. D16 - the panel's routing nonce stays
    the UTC date (a documented seed, not a location an engine writes). D2 - a lock whose owner
    process is gone is taken over at once (besides the 5-minute rule), so a killed sender does not
    block for 5 minutes.
  - Also fixed during the runs: the vendor table knows `open.bigmodel.cn` (Z.ai's other host in the
    effort table) as `zai`; `Get-HostPluginRoots` builds its paths without `Join-Path` (which wants the
    drive to exist); `harness-fixes26b` STALLTOOL's silent tool call is 5 s (under D12's 2 x 3 s bound;
    `harness-fixes28b` STALL covers the cut); `harness-detach` SINGLE expects the test-mode line after
    the three detach lines.
  - Counts (2026-09-30; every new and changed harness first alone on both hosts). The runs as they
    were (corrected in wave 28c, F43-7): `tests/run-all.ps1` on Windows PowerShell 5.1 ended
    `18 harness(es), 1 failed` - `harness-detach` SINGLE, whose check was then fixed and
    `harness-detach` run ALONE on both hosts (51 passed); the full suite was NOT run again on 5.1, so
    e5c6992 has no clean full-suite run on Windows PowerShell 5.1 (wave 28c's suites cover its
    successor). On PowerShell 7.6.6, after the fix: `18 harness(es), 0 failed`. The counts of that
    PowerShell 7 suite: `harness-0.3` 229, `harness-roster` 119, `harness-format` 37,
    `harness-engines` 97, `harness-muse` 74, `harness-panel` 54, `harness-pending` 26, `harness-fixes`
    45, `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121, `harness-detach` 51,
    `harness-companions` 42, `harness-fixes26b` 51, `harness-host` 62 (+4), `harness-telemetry` 79
    (+24), `harness-fixes27c` 36, `harness-fixes28b` 20 (new).
- **Wave 28c - the second fix round** (the wave 28b re-acceptance, panel 8937563b on e5c6992: glm,
  muse ACCEPT; mimo HOLD on F42-1..6, qwen HOLD on F43-1; decisions D1-D14 of
  `.collab/companions-2026-09-26/handoffs/45-claude-wave28c-decisions.md`):
  - D1 (F42-1, F43-2) The telemetry model is a CLOSED list: each vendor class of
    `$script:TelemetryVendors` carries `Models`, the published names the README documents (its
    effort table, its roster examples) and the rosters have run; `details.model` and the tag carry a
    name only when it EQUALS a list entry after lower-casing (and then the list's own text), anything
    else - `gpt-al1ce-code`, `glm-4.5acmecorp`, a future `glm-5.4` - is `other`. The word list and
    the version pattern are gone. The README lists every name and says that an unlisted model reads
    `other` until a release adds it.
  - D2 (F42-2, F43-1, F44-4) `-Forget -PublicRef <ref> -Local` asks the intake FIRST and deletes
    locally only after a 2xx `"ok": true`; any other answer (a wrong reference, an unreachable
    intake) deletes nothing here either - the salt, the spool and the counters stay, the reason is
    printed, exit 3, and the command can be repeated. `-Forget -Local` alone says in one line that
    the intake still holds what was sent and how to remove it (`-Forget -PublicRef <ref>` BEFORE
    `-Local`: the instance id dies with the salt), then asks `remove locally? [y/N]` unless `-Yes`
    (`codex-telemetry.ps1 -Forget` takes `-Yes`).
  - D3 (F42-3) THE telemetry lock `<codex home>/telemetry.lock` (an open handle, released by the OS
    when its holder dies) is taken by every producer's spool append, the salt's creation and
    `-Forget -Local`; `-Forget -Local` writes `<codex home>/telemetry-forgetting` while it deletes and
    removes it last; a producer that meets the marker (or the lock busy past its short wait) drops its
    event and counts it - it never recreates the salt or the spool. A complaint kept in the spool
    checks that its instance id is still the salt's. `-Status` shows a marker left by a `-Forget` that
    died; `-Forget -Local` finishes it. With `-PublicRef` the lock and the marker are held across the
    DELETE, so nothing is spooled or sent in between.
  - D4 (F42-7, F43-5, F44-2) The flush lock is taken over ONLY when its owner process (pid and start
    time) is gone; a living owner's lock is left alone however old and reported `another flush is
    running: sender busy since <t> (...)`; the 5-minute age rule is gone; a lock that names no owner
    and is not held open is taken over (every sender writes its identity inside the handle that
    creates the lock, so no living sender is behind it).
    Every sender checks its token in the lock before each send and each spool rewrite
    (`Test-TelemetryFlushLockMine`) and stops without rewriting when it lost the lock.
  - D5 (F42-8) The 60 s cover the whole flush: the watch starts before the lock, the enumeration,
    each file's read (its busy wait bounded by what is left), each request (only while 1.5 s are left,
    1 s kept for the rewrite) and each rewrite count; the rewrite of delivered lines is always tried
    with a wait of at most what is left; the final counts are skipped when time is out (`kept ?`).
  - D6 (F41-1, F42-9) The sender's allow list: the proxy variables in both cases (they were already
    matched ignoring case; outside Windows both spellings are now kept - the environment is built
    with an ordinal comparer there) and the trust inputs `SSL_CERT_FILE`, `SSL_CERT_DIR`,
    `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`; the README lists the whole list.
  - D7 (F43-4) At the commit the append waits at most 1 s (the telemetry lock and the spool file
    together); a failure is retried for up to 5 s after the write lock is released, and only then
    warned about (console, the detached status record: `... - at the commit (<why>) and for 5 s after
    it`) and counted; an event met by the forgetting marker is dropped at once (`... - dropped`).
  - D8 (F42-4) `Get-PidIdentity` (alive / gone / unknown); `Stop-ProcessTreeChecked` kills a
    descendant by pid only when its identity is confirmed and never counts an unknown one as gone:
    `Unverified`, `Confirmed` false, `Why` `start time of pid <n> unreadable`; the outcome and the
    warning name that pid (`Get-KillMayRunPids`). `Test-PidAlive` keeps counting unknown as alive (a
    lock holder is never taken over on a guess). TEST HOOKS: `CODEX_CONSULT_TEST_START_UNREADABLE`,
    `CODEX_CONSULT_TEST_KILL_DENIED=taskkill`.
  - D9 (F42-5) `Get-UnixDescendantTree` (injectable runner and /proc root): pgrep exit 1 is an empty
    child set; any other exit, a 5 s timeout (`Invoke-CapturedCommand`), output that is not a pid or a
    pgrep that cannot run is a failed enumeration and goes to `ps`, then `/proc`; denied only when all
    fail.
  - D10 (F42-6, F44-1) `Update-MachineHealth` reads the journal as bytes: an unparsable line is moved
    to `<journal>.bad` (the time, a tab, its exact bytes) and counted in `health journal: <n>
    unreadable line(s) kept in <file>` (the run's `warnings[]` before its commit, its summary after
    it); the journal loses exactly the applied or moved prefix - a line that cannot be moved stays,
    with what follows it.
  - D11 (F43-3, F44-6) Looked up first: the installed codex-cli 0.155.1's `exec --json` item types
    (read from the binary's strings: agent_message, reasoning, command_execution, file_change,
    mcp_tool_call, collab_tool_call, web_search, todo_list) include no compaction, although its
    protocol knows `context_compacted` and a `context_compaction` item. `Get-CompactionCount` counts
    those names in every turn's event stream; the ledger's `compactions` is n (with the warning `the
    reviewer compacted its context <n> time(s) - the reply may rest on a summary of the brief`),
    `unknown` for a member with `context_tokens` when none was reported - with the installed codex
    that is every such member -, else `null`. The prompt of a member with `context_tokens` and a
    brief ends with ``Before you answer, re-read the brief: `<path>`.`` - the last line before the
    consultation id, which stays last (it ties the rollout to the run).
  - D12 (F44-5) The dry run already printed the test-mode line with its run warnings (and the
    preview's `warnings[]` held it); now checked (`harness-host` TESTLINE) and documented: the line
    appears on a committed run, a dry run, a panel run and a detached run, NOT on a refused run.
  - D13 (F43-7) The wave 28b counts above state the runs as they were; wave 28c ends with one clean
    full suite on EACH host for its final code (below).
  - D14 The waiting rule, revision 6 (the operator's decision of 2026-09-30): until a host lets the
    agent compact itself there are two states - while work runs or is awaited the context is kept
    warm always; when idle the handover at idle wake 2, the wake removed, one line to the operator
    with the cheap ways back. The "keep the wake for half the refreshes a cold resume is worth
    (40 / 20 / 10)" branch is removed from the coordinate skill and the README (and from
    `harness-host`'s recomputation; the boundary tables and their recomputation stay); the README
    and the skill name the launch option `--autocompact <tokens>` (Claude Code 2.1.285 `--help`,
    checked 2026-09-30).
  - Accepted limitations, documented: F43-6 and F44-3 - the vendor class is derived from the host
    name only; a private gateway or relay under a vendor's domain reads as that vendor.
  - Deviations: D11 - the re-read line is the last line BEFORE the `Consultation id` line (that line
    stays last); the continuation prompt, which asks the reviewer to read no more files, does not
    repeat it. D7 - an event that finally fails is no longer in the entry's `warnings[]` (the entry is
    committed before the retry): console and status record only.
  - Also changed during the runs: a flush lock that names no owner and is not held open is taken
    over at once (a first draft waited 5 minutes for it; `harness-telemetry` LOCK showed that a
    released empty lock then blocked the next sender); the coordinate skill names `--autocompact`
    without a host name outside "Means per host" (`harness-host` GREP).
  - Counts (2026-09-30; every new and changed harness first alone on both hosts - `harness-fixes28c`,
    `harness-telemetry`, `harness-host`, and `harness-0.3`, `harness-engines`, `harness-muse` for the
    ledger key order -, then `tests/run-all.ps1` for the final code on Windows PowerShell 5.1 and on
    PowerShell 7.6.6, each `19 harness(es), 0 failed`, the same counts on both): `harness-0.3` 229,
    `harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74,
    `harness-panel` 54, `harness-pending` 26, `harness-fixes` 45, `harness-lock2` 11, `harness-3b` 12,
    `harness-visibility` 121, `harness-detach` 51, `harness-companions` 42, `harness-fixes26b` 51,
    `harness-host` 65 (+3), `harness-telemetry` 92 (+13), `harness-fixes27c` 36, `harness-fixes28b`
    20, `harness-fixes28c` 15 (new).
- **Wave 28d - the third fix round** (the wave 28c re-acceptance, panel 7e4efeb8 on fc6978a: glm,
  qwen, muse ACCEPT; mimo HOLD on F48-1..3; decisions D1-D8 of
  `.collab/companions-2026-09-26/handoffs/51-claude-wave28d-decisions.md`):
  - D1 (F48-1, F49-3) The spool is rewritten ATOMICALLY (`Remove-TelemetrySpoolLines`): under the
    telemetry lock (no producer appends meanwhile) the file is read, the kept lines go to
    `<spool file>.tmp` in the same directory, are flushed to disk (`Flush($true)`), and the temporary
    file replaces the spool file in one step - `[IO.File]::Move` with overwrite, on Windows
    PowerShell 5.1 `MoveFileEx(REPLACE_EXISTING | WRITE_THROUGH)` as `Write-TextAtomic` does.
    Nothing truncates the spool in place any more (no `SetLength(0)`): a crash leaves the old file
    or the new one; a `.tmp` a crash left behind is replaced by the next rewrite; a replace that
    keeps failing leaves the spool as it was (its delivered lines are sent again - at least once).
    The deadline bounds the waits for the lock and the file BEFORE the rewrite starts, never the
    rewrite itself. TEST HOOK (test mode only): `CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH=1` - the
    process exits (86) between the temporary file and the replace.
  - D2 (F48-2) The forgetting marker heals itself: it names its owner `{pid, start_time, since}`;
    `-Forget` removes it in `finally` - a local deletion that fails halfway says `run
    codex-telemetry.ps1 -Forget -Local again to finish it` and blocks nothing; a producer or a sender
    that meets a marker whose owner is gone - or that names none (`-Forget` writes it under the
    telemetry lock, so nobody is writing it while the lock is held) - removes it under the telemetry
    lock (`Resolve-TelemetryForgetting`), writes one line into `.last` `notes` and goes on. A marker
    whose owner lives (`Test-PidAlive`: an identity that cannot be confirmed counts as living) blocks
    as before; the sender then stops before sending anything. `-Status` names the owner (`forgetting
    : the marker ... - its owner pid <n> lives` / `... is gone`) and prints the notes.
  - D3 (F48-3, F49-4) The flush lock is BORN WITH ITS OWNER (`Enter-TelemetryFlushLock`): the record
    `{pid, start_time, token, since}` is written to `<lock>.<guid>.tmp` and moved into place WITHOUT
    overwriting, so a healthy sender never leaves an ownerless lock and two senders never both
    create one. A lock that names no owner or cannot be read counts as HELD while it is younger than
    30 s; after that - and a dead owner's lock at once - it is removed under an exclusive handle and
    the sender starts over (no more rewriting a lock in place). A lock with a living owner is never
    taken over; older than 30 minutes it is `sender stuck since <t> (pid <n>)`: the refused sender
    writes that into `.last` `notes` (once, however often it is refused; the next sender that holds
    the lock drops it) and `-Status` prints `sender     : sender stuck since <t> (pid <n>) - ... stop
    pid <n> if it hangs, or delete the lock when no such process runs`.
  - D4 (F49-2) The not-spooled count cannot be lost: `<codex home>/telemetry-not-spooled.ndjson` is
    append-only and written WITHOUT the telemetry lock (retried up to 5 s against another append);
    no flush deletes it - each flush records the lines it saw in `.last` `not_spooled_seen` and
    `-Status` counts the complete lines after them (`-Forget -Local` still removes the file).
  - D5 (F49-1) A kill that leaves survivors AND descendants whose identity could not be read names
    both groups: the warning `kill not confirmed (<turn>): <n> processes survived: pid <a>, <b>; start
    time of pid <u> unreadable; pid <u> may still run - check them, and stop them by hand if they do`
    and the outcome text `(process tree killed; <n> processes survived: pid <a>, <b>; start time of pid
    <u> unreadable; pid <u> may still run)` (a turn, the main turn and the format repair;
    `Get-KillUnverifiedText`). The recovery record is unchanged.
  - D6 (F50-1) `Get-TelemetryModelToken` lower-cases both sides: a table entry with an upper-case
    letter matches (and the event carries the table's own text).
  - D7 (F50-2) A member with `context_tokens` that runs without a brief file gets the one-line ask
    repeated as the last line before the consultation id: `Before you answer, re-read the ask: <the
    ask, whitespace folded>` (cut at 500 characters, pointing to the top of the prompt).
  - D8 (F48-4) What the audit found: no hash of the prompt text exists anywhere. Thread reuse is
    decided by the reviewer's identity (provider, model, engine - compared field by field), the
    endpoint fingerprint (a SHA-256 of the provider's configuration) and a thread verified by the
    event stream or by a rollout that contains the consultation id (the prompt's last line, still
    last); lineage is the same identity; finding ids and consultation numbers are counters from the
    ledger, the findings store and the handoff names; the panel seed hashes the task, the purpose,
    the brief FILE's SHA-256, the lineages and a nonce; the other hashes are of the reviewed tree and
    the telemetry salt. The one place where the appended line took part in a reuse decision was the
    context estimate of a fork or resume on a `context_tokens` member (`(prompt + brief) / 4`
    against 80% of the window, `mode_fallback`): the re-read line (D7's too) is now subtracted there,
    so the same prompt decides the same way with or without it. `prompt_chars` in the ledger still
    counts the prompt as sent.
  - Harnesses: `harness-fixes28d` (new): REWRITE, MARKER, LOCK (four processes racing for the lock),
    NOTSPOOLED, KILL, MODEL, REREAD (D8: a window chosen so that the estimate without the line just
    fits and with it would not - the fork is kept; three tokens smaller the fallback happens), DOCS.
    `harness-telemetry`: the forgetting-marker cases use a marker of a LIVING owner (a dead owner's
    marker now heals), an ownerless flush lock is held while young and removed at 40 s, LOCK releases
    the held lock by deleting it (as its owner does - an empty lock left behind now counts as held for
    30 s), and SEND expects `.last`'s two new keys.
  - Also changed during the runs: the README keeps `5-minute age rule` on one line (the
    `harness-telemetry` DOCS check reads the section unfolded); `harness-fixes28d` pins every restore to a SCRATCH codex
    home and ends with GUARD - its first draft restored the operator's own `CODEX_HOME` after a child
    run, and two of its in-process flushes then wrote that home's `telemetry-spool/.last` once
    (`nothing to send`: its spool was empty, the intake a closed loopback port - nothing was sent).
  - Counts (2026-09-30; `harness-fixes28d`, `harness-telemetry` and `harness-fixes28c` first alone on
    both hosts, then `tests/run-all.ps1` for the final code): Windows PowerShell 5.1 `20 harness(es), 0
    failed`; PowerShell 7.6.6 `20 harness(es), 1 failed` - `harness-fixes26b` GUARD only, environmental: the operator's Codex desktop app rewrote `~/.codex/config.toml` at 20:33 while that harness ran (the guard compares the file's hash before and after); by the operator's decision the suite was not run again. The counts, the same on both hosts: `harness-0.3`
    229, `harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74,
    `harness-panel` 54, `harness-pending` 26, `harness-fixes` 45, `harness-lock2` 11, `harness-3b`
    12, `harness-visibility` 121, `harness-detach` 51, `harness-companions` 42, `harness-fixes26b`
    51 (on PowerShell 7: 50 passed, the GUARD row failed), `harness-host` 65, `harness-telemetry` 92 (cases changed, none added), `harness-fixes27c` 36,
    `harness-fixes28b` 20, `harness-fixes28c` 15, `harness-fixes28d` 40 (new).
### Known limitations

- (wave 28c) The telemetry vendor class is derived from the endpoint's host NAME only (F43-6,
  F44-3): a private gateway, relay or proxy under a vendor's domain reads as that vendor. A reviewer's
  compaction is seen only when its engine reports it in the event stream: the installed codex-cli
  0.155.1's `exec --json` reports none, so a member with `context_tokens` records `compactions`
  `unknown` (F43-3, F44-6).

- (wave 26b; wave 26c) The stall cut reads the growth of the event stream and the tool calls it
  names, not their meaning: an engine that wrote keep-alive bytes would never stall, a tool call
  whose end event never comes suspends the cut until the timeout; a turn that thinks silently
  for longer than `-StallSec` outside a tool call is stopped (raise the entry's `stall_sec`, or
  `0`).
- (wave 27) The coordinator's host is a hint read from environment markers the host sets and its
  children inherit - a session started inside another host's session may be named by the inner
  one's markers only; the identity (`CODEX_CONSULT_COORDINATOR`) is the coordinator's word, never
  checked. The scrub removes the markers from what the bridge starts; an engine CLI sets its own
  for its own tools. Whether Codex CLI runs the plugin's SessionStart hook (it trusts a plugin's
  hooks first) and substitutes `${CLAUDE_PLUGIN_ROOT}` in the skills is checked by the live D9 run,
  not by a harness (the fallbacks: the AGENTS.md lines, `CODEX_CONSULT_ROOT`, `-Explain`).
  (wave 27b) The scrub list is exact names from what the hosts set on 2026-09-29: a variable a
  later host version adds is inherited until it is listed. A host that sets no marker (Kimi Code)
  is `unknown`; a claude-code session started inside a Z Code session is named `zcode`. The Z Code
  install and the Kimi Code skills directory are verified; their live coordinator runs are pending.
- (wave 26b) The machine-wide health file is per user profile (`<codex home>`): runs under another
  account or `CODEX_HOME` do not see each other; a `running[]` row of a bridge killed hard stays
  until the next write prunes it (its pid is then gone); two panels that check the count at the
  same instant can both start a member (no reservation - the count is advisory).
- (wave 26b; wave 26c) `-Kick` reaches a member only while one of its engine turns runs or right
  after it exited (it polls there); between turns (the tree check, the commit) a kick waits for the
  next turn or the next run of that number, and `-Kick` exits 3 after 10 s without an
  acknowledgement.
- (wave 26) A panel's size bounds the members STARTED; a member that fails, is refused at launch
  (its peak window, a limit hit meanwhile) or is killed is not replaced (no backfill).
- (wave 26) The routing score depends on the marks recorded with `-Rate`: an unrated consultation
  counts nothing, and marks are missing-not-at-random (a structured reviewer is easier to rate).
  Reproducibility of a draw holds for the same eligible set and scores - a new mark changes the
  weights, so the same seed may seat differently later (the ledger's `panel.routing` records what
  was used).
- (wave 26) `-Require` on a single run is a gate only (the run is still the `-Provider`'s); a
  roster walk (no `-Provider`) refuses `-Require`.
- (wave 26) `panel.started`/`panel.usable` are written by the panel run after the last member; a
  panel run that dies first leaves them `null`.
- A continuation only follows the MAIN turn's kill; a killed denial retry or format repair is
  salvaged and names the resume command, but gets no continuation of its own.
- No continuation when the thread of the killed turn is unknown (a codex stream without
  `thread.started` whose rollout does not name the consultation id).
- The salvage reads what the event stream holds: codex emits a reasoning or message item only
  when it completes, so text of an item in flight at the kill is not in it.
- The listing, `-Short` and the hook read the ledgers of the repository they run in (now
  said on the `endpoint health:` line); a limit recorded in another repository stays invisible
  there until a run in this one hits it.
- (wave 24c) The tree check compares file contents: a file-mode change (chmod) or a change that
  is only staged during a run is not a tree change (`tree_sha256`, the review binding, still
  moves with both).
- (wave 24c) Whether a 429 is a burst is read from its text: a real quota whose 429 names nothing
  but the status is out for 10 minutes only - the next run after that hits it again and records
  it again.
- (wave 25) `-Detach` does not probe the task lock or re-run the time-dependent health/peak
  selection in the foreground: a consultation that takes the task in between makes the
  background refuse (its status: `done`, exit 1, the refusal line) - the foreground's exit 0
  means "started", not "usable".
- (wave 25) The macOS/Linux background (`/bin/sh -c 'exec nohup ...'`) is not exercised by the
  Windows-only harnesses.
- (wave 25) Killing only a detached panel's background process (not its tree) leaves its members
  running to their end; `-Status` says `died` meanwhile and the task stays refused until their
  records clear, as after any killed panel run.
- (wave 25) A single run's summary in the status file stops at `events file:`; the reply itself
  is in the reply file and the log. `-Status` prints non-ASCII text through the console's code
  page, as every bridge output does; the status file and the log are UTF-8.


## [0.4.0] - 2026-09-26

Implements ROADMAP R10 (engines) with its first engine besides Codex, `agy` (Google's
Antigravity CLI for the Gemini models), per the design round recorded in
`.collab/engines-0.4-2026-09-25/` (`handoffs/01` the design D1-D12 and facts F1-F10,
`handoffs/02`/`04`/`05` the panel's and Gemini's reviews, `handoffs/06` the judge's
amendments A1-A20 and the facts F11/F12).

### Added

- **Wave 17 — the `agy` engine (R10).**
  - An engine table (`$script:Engines` in `codex-consult-common.ps1`): one row per CLI with
    its launcher names, handoff prefix, modes, sandboxes, schema transports, caps-v1 host and
    adapter functions (argv, stdin, event parser, turn rules, credential check). `codex`
    stays the default and its path is unchanged; the next engine (`claude`) is one more row.
  - Roster field `engine` (`codex` | `agy`): for agy the provider is a free label, the
    model is required, `codex_config` and `auth` are refused, one label names one engine;
    the entries carry it through the walk, `-Provider`, `-Thread` and `-Panel`
    (`roster.skipped[].engine`, `roster.applied` `engine`).
  - Bridge parameters `-Engine codex|agy` (default: the roster entry's, the thread's, else
    codex; with a roster it filters the walk and the panel), `-EngineExe` /
    `CODEX_CONSULT_AGY_EXE`, `-DenialRetry 0|1`. Refused for agy with one message each:
    `-Mode fork`, `-Sandbox workspace-write`, `-CodexConfig`, `-SchemaTransport
    output-schema`.
  - Invocation `agy -p= --input-format stream-json --output-format stream-json --model <m>
    [--json-schema <schema>] --print-timeout 0 --sandbox --disable-slash-commands
    [--conversation <thread>] [--effort <v>]` from the repository root, the prompt as ONE
    NDJSON line on stdin (UTF-8, no BOM), plus a prompt line that forbids commands and file
    changes. Default mode `new`; `-Mode resume` / `-Thread` resume a conversation.
  - Identity: provider = the label, fingerprint SHA-256 of `cc-engine-v1|agy`,
    `provider_config {engine, launcher}`, harness `agy-cli <version>`; caps-v1 entry
    `engine:agy` (effort mapping `model-tier`, nothing sent; schema transport `native`).
  - The reply is the single `result` event's `structured_output`, extracted to
    `handoffs/NN-agy-<slug>.reply.json` before validation; a `response` text alone goes
    through the prose gate and the format repair on `--conversation`. Usage maps
    `cache_read_tokens` and `thinking_tokens`.
  - Failure rules: exit != 0, a malformed stream (not exactly one result), no result, init
    and result ids that differ, `status` != `SUCCESS`, on resume the not-found warning or
    another id (the new conversation is never a parent), a non-uuid id, partial output, an
    empty reply; the same id checks on a repair or retry turn.
  - F11: a turn that ends empty because a tool was auto-denied fails with the new class
    `permission`; with `-DenialRetry 1` ONE more turn on the same conversation tells the
    model not to call it again (ledger `denial_retry`, after `format_retry`).
  - F12: agy's `--sandbox` does not block writes, so an agy run whose working tree, brief,
    artifacts or task handoffs changed FAILS (class `permission`; the reply kept, nothing
    ingested; ledger `sandbox` says how read-only is enforced).
  - Preflight: `agy models` (15 s, cached per listing) as the sign-in check;
    `codex-providers.ps1` lists one engine row per agy roster label (JSON rows gain
    `engine`) and has `-NoNetwork`, which the SessionStart hook now uses (`gemini not
    checked (launcher present)`); endpoint health by the engine's fingerprint.
  - Scoreboards: `codex-scoreboard.ps1`, `codex-findings.ps1 -Stats`/`-Rate`, the panel
    summary and the roster lines show an agy lineage as `<label> :: <model> [agy]`.
  - `tests/harness-engines.ps1` (81 assertions, Windows PowerShell 5.1 and pwsh) with
    `tests/fake-agy.cmd` / `fake-agy.ps1`; `run-all.ps1` runs it.
- **Wave 18 — fixes after the wave-17 diff-review panel** (GLM `F09-1..3`, MiMo `F10-1..3`,
  the judge's F13).
  - Tree check scope (F09-1, F10-1): an agy turn now snapshots the WHOLE collab directory
    (every file under `-CollabDir`, recursively - every task's `findings.json` /
    `sessions.json` / `state.md` and handoffs; `.consult.*` files and the run's own
    `NN-agy-<slug>.*` files excepted) instead of the task's handoffs only, and fails a run
    that changed anything there. Gitignored paths, submodules and files outside the
    repository stay unmonitored and are documented as such: "enforced by evidence for
    tracked and untracked files and the collab directory; not for gitignored paths,
    submodules or files outside the repository" (README "Engines", the ledger `sandbox`
    text, the skills; TECH_DEBT T8).
  - Retry event streams in the ledger (F09-2): `denial_retry` and `format_retry` gain
    `events`, the handoffs-relative path of that turn's event stream (`null` when no turn
    ran; `null` for a codex format repair, whose stream stays a temp file).
  - Wording (F09-3): `failed: the working tree changed during the run (by the reviewer or
    anyone else): <n> files: ...` and `the collab directory changed during the run (by the
    reviewer or anyone else): <n> files: .collab/...` (the brief and the artifacts likewise);
    the README keeps "do not edit during an agy run" and adds "run no other consultation
    here".
  - Trailing garbage (F10-2): `Read-AgyEvents -AllowPartialLast`; the last line counts as a
    partial line only when the bridge killed the process or it exited non-zero - after
    exit 0 a malformed last line fails the run (class `transport`).
  - Non-unique label (F10-3): `-Provider <label>` without `-Model` on a roster with several
    entries of that label still takes the first entry (the 0.3.0 rule) but warns on the
    console and in `warnings[]`: `roster: label gemini names 2 entries; the first (gemini ::
    gemini-3.8-flash-high [agy]) is used - pass -Model for another`.
  - Sign-in timing (F13): the `agy models` timeout is 45 s (was 15 s; live it took 1.7 s,
    7.7 s, 13.8 s and once more than 15 s, which refused a real run) in the preflight and
    `codex-providers.ps1`; test hook `CODEX_CONSULT_TEST_LOGIN_TIMEOUT`. And a ledger
    short-circuit: a usable reply on the agy endpoint in THIS repository's ledgers within
    the last 60 minutes (consult clock) makes the credential `ok: signed in (usable reply
    <m> min ago)` without running `agy models` (preflight, listing, hook); the endpoint
    health's auth and quota rules stay in front of it.
  - `harness-engines.ps1` 95 assertions (+14: the collab snapshot, another task and a task
    store written, the gitignored blind spot and the README sentence, the retry streams,
    trailing garbage on exit 0 and after a kill, the label warning, the sign-in
    short-circuit at 5 and 61 minutes, auth / quota still refusing, the hanging `agy
    models`); `harness-format`'s `format_retry` field assertion includes `events` (`null`
    for codex).
- **Live evidence** (the judge's runs through the bridge, task `engines-0.4-2026-09-25`):
  - first run n=3 (`gemini-3.8-flash-low`, checkpoint): 118 s, a structured first turn;
  - panel `2d8d5f25` n=4-6: ZAI ACCEPT, mimo HOLD, `gemini-3.8-flash-high [agy]` ACCEPT
    (605 s, usage 1.6M input / 5.9M cached tokens);
  - resume n=7: the same conversation id, and the model quoted the previous consultation
    id;
  - denial check n=8 (gemini-3.8-flash-low asked to run `git --version`): the prompt's tools
    line held - the model refused the command and filed it as a requested check (RC1), so
    the F11 path did not fire live; the denial retry stays verified by the harness and by
    the round-1 manual turn (handoff 04).

- **Wave 19 — BytePlus ModelArk Coding Plan declared in caps-v1.** The host
  `ark.ap-southeast.bytepluses.com` (the plan's Codex base URL `/api/coding/v3`) gets the
  vocabulary `ark` (`low | medium | high`, `xhigh` -> `high`, mapping `ark-v1`; the plan's
  Codex doc names those three values for `model_reasoning_effort`), the 12 model names of
  its quick-start guide (exact) and schema transport `prompt-only`, so plan entries can be
  roster and panel members without `-NativeEffort`. `setup-providers` gains the recipe
  (section 3c: table, key set by the user, `/api/coding/v3` vs `/api/v3`, quota, the
  training-data term); README's caps-v1 and provider tables gain the rows.
  Live (task `engines-0.4-2026-09-25`, the user's Lite plan): `kimi-k2.5` n=10 (25 s), `deepseek-v4.1-flash`
  n=12 (13 s, effort high) and `dola-seed-2.0-pro` n=13 (36 s) each returned the JSON object on the
  first turn under prompt-only transport (~55k input tokens per checkpoint run); `kimi-k3` n=11 is
  refused by the plan (`404 The requested model does not support the coding plan feature`, class
  capability); a wrong key n=9 was `401 The API key format is incorrect` (class auth) and the
  fail-closed preflight refused the next runs until `-SkipPreflight` with the corrected key.

- **Wave 20 — Kimi Code declared in caps-v1.** The host `api.kimi.ai` (the Kimi Code membership's
  Codex base URL `/coding/v1`, Responses API per Moonshot's Codex doc) gets the vocabulary `kimi`
  (`low | high | max`, `medium` -> `high`, `xhigh` -> `max`, mapping `kimi-v1`), the four model
  names of that doc (`k3`, `k3-256k`, `kimi-for-coding`, `kimi-for-coding-highspeed`; the
  membership tier decides which are unlocked - Plus: K3 at 256K) and schema transport
  `prompt-only`. `setup-providers` 3d and the README tables gain the recipe. Live evidence
  (task `engines-0.4-2026-09-25`, n=14): `kimi :: k3`, preflight `ok: env KIMI_API_KEY set`,
  effort medium -> high, structured on the first turn, ADVISE, 198 s wall; the reviewer walked
  the tree with read-only tool calls to confirm six prior findings fixed, which cost 515k input
  tokens (410k of them cached) - a per-request plan pays for that loop in tokens, not calls.

- **Wave 21 — the parallel panel (ROADMAP R11)**, per the design round recorded in
  `.collab/parallel-panel-2026-09-25/` (`handoffs/01` the design, `02`-`04` the reviews by
  kimi k3, deepseek-v4.1-flash and glm-5.3, `05` the decisions D1-D13).
  - A `-Panel` run's members run IN PARALLEL, each a bridge process of its own
    (`Start-Process` with its console output in a temp directory, polled; no runspaces or
    jobs). The plan is endpoint-aware (D8): the members of one endpoint - one provider
    label, or labels on one provider fingerprint (every agy label: one Google sign-in) - run
    one after another, different endpoints at once; the roster's new optional top-level
    `"parallel": {"<provider label>": n}` raises a label's limit (validated: integers >= 1,
    labels the roster uses); the new `-PanelConcurrency <n>` caps the total (0 = no cap, the
    default; 1 = strictly one after another). The first line, a `Concurrency:` line and the
    dry run show the plan; one progress line per finished member; the members' console
    output in roster order; the summary gains the panel's wall clock.
  - The panel run holds the task lock for the whole panel (its record names the panel,
    D12), judges every recovery record first, assigns n and NN to every member up front in
    roster order, and writes one recovery record per member,
    `<task>/.consult.pending-<NN>.json` (state `reserved`, with a `panel` object), before
    any member starts; it removes the records of members that never started anything (D5).
  - A member accepts its spec only when its record names the same panel, n, NN and parent
    pid + start time and the parent is alive (D6); it rewrites the record with its own pid +
    start time as its first act and re-checks the parent right before it starts its
    reviewer (D1). The parent stops a member that outlives its guard (timeout + repair /
    denial-retry budgets + 60 s + 120 s, D11): summary "killed by the panel after N s".
  - Recovery records carry the writer's `start_time`; a live writer makes a record active
    in every state (D1). A panel member's record is judged by its recorded pids + start
    times and, on Windows, their children only - never by the machine-wide name rule. New
    state `committing`. `Get-NextNumbers` takes several leftover records; every reader
    (`codex-consult.ps1`, `codex-findings.ps1 -List/-Stats/-Status`) enumerates
    `.consult.pending*.json` (D5).
  - The commit write lock `<task>/.consult.write.lock` (D2): an OS-held handle like
    `.consult.lock`, waited for up to 60 s; ONE routine (`Enter-StoreCommit` -> delta on the
    RE-READ stores -> `Complete-StoreCommit` -> `Exit-StoreCommit`) for single runs, panel
    members and `codex-findings.ps1 -Status`/`-Rate`. The ingest and the handoff's rendered
    section happen inside it (D4); the ledger entry is inserted by n (D10). Not acquired in
    60 s: the stores are not touched, the record stays `committing` naming the kept reply,
    exit 1 "commit blocked", the next run consumes it (D3).
  - agy member (D7): its collab comparison also leaves out the task's two stores and the
    sibling members' handoffs, each with its Write-TextAtomic temp variant, while members
    run at the same time.
  - Ledger `finished_at` (after `wall_seconds`); `Get-EndpointHealth` orders by completion
    (`finished_at`, else `when` + `wall_seconds`), ties by n (D9). Ledger `panel` gains
    `concurrency` and `limits`.
  - Fakes (D13): `FAKE_CODEX_DELAY_MS` and `FAKE_CODEX_REPLY_MAP` keyed by the `-m` model,
    `FAKE_CODEX_LOGIN_DELAY_MS`, `FAKE_AGY_DELAY_MS`; the fakes' log and pid writes retry on a
    sharing violation. Test hooks `CODEX_CONSULT_TEST_WRITE_LOCK_SEC`,
    `CODEX_CONSULT_TEST_COMMIT_PAUSE_MS`, `CODEX_CONSULT_TEST_PANEL_GUARD_SEC`.
  - `tests/harness-panel.ps1` (new; `run-all.ps1` runs it), see "Tests" in the README.
  - Live evidence (panel 46393649, 2026-09-26, reviewing this wave at 2de15e9): 8 of 9 roster
    entries (openai skipped on its usage limit), at most 7 at a time with three BytePlus models
    at once; wall clock 1823 s against about 6430 s summed. glm-5.3, deepseek-v4.1-flash and
    dola-seed-2.0-pro: ACCEPT with 0 blockers and 0 majors; kimi-k2.5 answered in prose; k3 and
    gemini-3.1-pro-high stopped on plan quotas, gemini-3.8-flash-high on an API error, mimo on
    the 1800 s timeout - each with a ledger entry of its own. Afterwards the ledger held n 1..11
    in order with `finished_at` and the panel plan on every entry, findings stayed in id order and
    no recovery record was left.
  - Follow-up round (findings F07-1, F11-1..6 of that panel and two defects its ledger showed):
    a member now rewrites its record with its own pid BEFORE it checks the parent and withdraws
    the record when the parent is gone, so a record can no longer read inactive while its member
    lives (F07-1, F11-6); ledger field `commit_wait_ms` (after `finished_at`) and a console line
    when a commit waited for the write lock (F11-3); a record entering `committing` names the
    kept reply, and a member stopped inside its commit is summarised as such, apart from
    "commit blocked" (F11-2); `codex-findings.ps1 -Rate` refuses while a recovery record is
    active (F11-4); comments (F11-1, F11-5). Provider failures: a usage-limit, quota or
    rate-limit text classifies as `quota` even on 401/403 - Kimi Code's 5-hour limit arrives as
    403 and was recorded as `auth` - and endpoint health reads older `auth` entries with such a
    text as quota; `retry_after` also parses relative resets ("Resets in 68h58m18s", "in 2d3h")
    and the rolling-window wording "reset when the current N-hour window ends" (failure time + N,
    an upper bound). harness-roster 117, harness-panel 52; full suite green.

- **Wave 22 — Alibaba Cloud Model Studio Token Plan declared in caps-v1.** The host
  `token-plan.ap-southeast-1.maas.aliyuncs.com` (the plan's Codex base URL `/compatible-mode/v1`,
  Responses API, Singapore only) gets the vocabulary `alibaba` (`low | medium | high | xhigh` as
  is, mapping `alibaba-v1`), the plan's 11 text models (Qwen 3.8 Max and Flash, 3.7 Max and Plus,
  3.6 Flash, four DeepSeek, GLM-5.3 and 5.2; the `auto` router is left out - its target model
  and so the effort it accepts is chosen by the endpoint) and schema transport `prompt-only`.
  The refusal for an undeclared host lists the declared hosts in ordinal order, the same on
  Windows PowerShell 5.1 and pwsh 7; the caps-v1 header comment now also describes the BytePlus
  and Kimi hosts. `setup-providers` 3e and the README tables gain the recipe and its key
  pitfalls (the plan's own `sk-sp-` key; never an AccessKey pair, a general Model Studio key or
  `OPENAI_API_KEY`). Live evidence (task `providers-2026-09-26`, the same narrow checkpoint):
  qwen3.8-max 158 s and deepseek-v4.1-flash 213 s through the plan, structured on the first turn,
  about 1.7% of the Lite month together at daytime rates; deepseek-v4.1-flash through the
  BytePlus plan 58 s. qwen3.8-max's own review found the `auto` router and the stale header
  comment (F01-1, F01-2), both fixed in this wave.

- **Wave 23 — the `muse` engine (Meta's Muse Code CLI; R10, the third engine)**, per the design
  round recorded in `.collab/muse-engine-2026-09-26/` (`handoffs/01` the design and the verified
  CLI facts, `02`-`04` the reviews by glm-5.3, deepseek-v4.1-flash and dola-seed-2.0-pro,
  `handoffs/05` the decisions D1-D16). The Muse Code subscription works only through Meta's own
  CLI signed in by browser, so the bridge drives `muse exec` headless:
  - **Engine row `muse`** (label `Meta Muse (muse)`, prefix `muse`, command `muse`,
    `CODEX_CONSULT_MUSE_EXE`, launchers `muse.cmd`/`muse.exe`/`muse`, fingerprint
    `cc-engine-v1|muse`, default label `meta`, modes new/resume, transports native/prompt-only);
    the roster accepts `"engine": "muse"` (D13). Argv (D1): `muse exec --json --prompt-file <P>
    [--output-schema <S>] --model <m> [--reasoning-effort <e>] --no-foreign-personal-context
    --disable-web-tools --disable-write --disable-shell --approval-mode never [--max-model-steps
    <n>] [--session-id <thread>]` in the repository root; the prompt in the turn's own prompt
    file, an empty stdin.
  - **The adapter contract (D1).** An engine's `Argv` now receives ONE turn-options object
    (`New-EngineTurnOptions`: Model, Mode, Thread, PromptFile, Schema, Effort, NativeEffort,
    MaxSteps); every turn - main, denial retry, format repair - writes and passes its own prompt
    file; agy keeps its NDJSON stdin through the same contract. New optional adapter entries:
    `Harness`, `IdentityConfig`, `LaunchBlock`.
  - **MSP parsing and the turn rules (D6, D7):** `Read-MuseEvents` / `Get-MuseTurnOutcome`.
    Every record's `schema_version` must be 1 (`unsupported MSP version N`, fail closed);
    exactly one session stream id (UUID) and one `run_terminal` record, on the session stream;
    `run.model.configured` must name the requested model (`model drift: asked X, served Y`,
    class capability); on resume and repair the session must be the requested one. Exit 2 ->
    capability (the `error:` line), 130/143 -> transport, a step-cap reason -> capability
    (`max model steps reached`), any other failure reason verbatim through the shared
    classifier (quota wording -> quota with `retry_after`). The two informational stderr lines
    every `muse exec` prints never become a failure's detail.
  - **Billing is a launch invariant (D4):** `META_API_KEY` or `MODEL_API_KEY` in the
    environment, or a credential mechanism other than `oauth`, refuses a muse run (fail-closed
    since wave 23b: no ESTABLISHED oauth sign-in refuses it too, see below) - also under
    `-SkipPreflight`; the roster walk and `-Panel` skip the entry (`refused: ...`), it is
    checked again right before every launch (the main turn and `Invoke-EngineTurn`), and
    `codex-providers.ps1` shows the row `unavailable (refused: ...)`. Names only, never a value.
    Ledger `reviewer.provider_config.credential_mechanism`.
  - **Sign-in (D5):** with `TBH_CREDENTIAL_BACKEND=file` the preflight reads
    `~/.config/muse/auth.json` for `providers.meta` and its `mechanism` only (ok / missing /
    unknown; the keychain backend is "not checkable"; since wave 23b missing and unknown refuse
    the launch itself, `-SkipPreflight` included); the
    check is local, so it also runs under `-NoNetwork` (the SessionStart hook).
  - **Launcher (D3):** `-EngineExe` is bound to the SELECTED engine other than codex (-Engine's,
    else the -Provider's roster entry's, else the only such engine of the roster; ambiguous or
    codex -> refused), in `codex-consult.ps1` and `codex-providers.ps1` alike; after PATH the
    vendor install location `%LOCALAPPDATA%\Programs\muse\muse.cmd` (Windows). A `.cmd`
    launcher whose arguments contain `%` (cmd.exe would expand it) is refused before launch
    (F02-14).
  - **Version (D8):** `reviewer.harness` = `muse-cli <version>` from `.muse-version` next to the
    launcher, else `.muse-release-info.json`, else `muse --version`; ledger
    `engine_run.msp_schema_version`.
  - **`-MaxModelSteps` (D9):** optional, positive, muse only (`--max-model-steps`), carried
    through the dry run, the panel spec (to the muse members; refused when a panel has none)
    and the ledger (`engine_run.max_model_steps`).
  - **caps-v1 (D10):** vocabulary `muse` (mapping `muse-v1`: low, medium, high, xhigh as is) for
    the live-verified `muse-spark-1.3` and `muse-spark-1.3-contributor`, SchemaTransport
    `native`; a caps row naming an undeclared vocabulary is now a loud plan error.
  - **Engine wording from the row (D11):** the prompt's tools line, the transport and
    reply-source lines of the dry run, the `-Sandbox` refusal, the ledger `sandbox`, the tree
    check's closing words and the handoff's prompt transport come from the engine row (agy's
    unchanged).
  - **No denial retry for muse (D2);** a format repair continues the session at most once; each
    muse turn is one subscription prompt - ledger `engine_run.turns` counts them.
  - **Tests (D15):** `tests/fake-muse.ps1` + `.cmd` (MSP records shaped like a sanitized real
    probe; strict about the real flags; knobs for reply, failed/cancelled terminals, exits 1/2/
    130, a usage error, a file write, hang, two terminals, two sessions, a wrong model, no
    model, schema_version 2, a partial last line, a terminal off the session stream) and
    `tests/harness-muse.ps1` (65 assertions, registered in `run-all.ps1`): argv against the real
    flags, paths with spaces through the `.cmd` chain and the `%` refusal, the billing guard
    (with `-SkipPreflight`, the walk, a panel member, the mechanism, the listing), the three
    sign-in states, the extraction invariants and failure classes end to end, D14's shared
    endpoint, the tree check and D12 for muse and agy, resume and a session mismatch, the
    format repair served through the muse adapter, `-MaxModelSteps` in the panel spec,
    `-EngineExe` bound to muse, the dry-run text, the providers listing. It never lets a real
    muse resolve (scratch home, LOCALAPPDATA and PATH for every child; it refuses to run
    otherwise).
  - Docs: README ("Engines (wave 23)", the ledger, preflight, providers, caps-v1, roster and
    options tables, the D12 boundary), `setup-providers` 3f.

- **Wave 23b — fixes from the muse engine's acceptance panel** (task `muse-engine-2026-09-26`,
  round 3: panel df203d79 on f2c219a; mimo-v2.6-pro's HOLD with F09-1..3):
  - **F09-1 (major) — the billing guard is fail-closed.** `Get-MuseLaunchBlock` refused only a
    KNOWN mechanism other than `oauth`: with the keychain backend, or a `providers.meta` without
    a `mechanism`, the mechanism was empty, nothing was refused, and `-SkipPreflight` could
    launch a run that might bill per token. A muse launch now requires an ESTABLISHED oauth
    sign-in: the keychain backend, no home, no or an unreadable `auth.json`, no
    `providers.meta` or no `mechanism` refuse it, naming the cause and the remedy (`` the Muse
    sign-in is not established as oauth (<cause>): a muse run might bill per token instead of
    the Muse Code subscription; set TBH_CREDENTIAL_BACKEND=file and run `muse login` ``) - under
    `-SkipPreflight`, in a dry run, in the roster walk, in panel members and in
    `codex-providers.ps1`'s listing (`unavailable (refused: ...)`), exactly like the API-key
    refusal. No override flag. `Get-MuseCredentialInfo` gains `Cause` (the reason without its
    remedy); ledger `credential_mechanism` is `oauth` in every entry now.
  - **F09-2 (major) — the secondary turns keep the main turn's schema transport.** An engine's
    format-repair turn passed the schema natively (`--output-schema` for muse, `--json-schema`
    for agy) even on a `prompt-only` run; it now uses the main turn's transport (prompt-only: no
    schema flag, the schema travels in the repair prompt, as in the main turn's). agy's
    denial-retry turn had the same defect and is fixed the same way (its prompt then carries the
    schema). Ledger `format_retry.schema_transport` (new, after `events`) states the repair
    turn's transport: codex `prompt-only` (its repair never passes `--output-schema`,
    unchanged), an engine the main turn's.
  - **F09-3 (minor) — MSP evidence provenance.** `Read-MuseEvents` binds the evidence: the
    session is the ONE stream of kind `session`; its run is the ONE run stream the
    `session.run.linked` records on that stream name (new field `RunStream`); every
    `run.model.configured` record must sit on the session stream and name that run in
    `payload.run_stream`, and so must a completed `run_terminal`. A link off the session stream
    or naming no run, two linked runs, a model record on a sub-stream, of another run or with no
    run linked, a reply of another run -> `malformed event stream: ambiguous provenance: ...`
    (class transport, fail closed; the session a candidate only). These are the real CLI's
    shapes (every record on the session stream, the run named in the payload): the three probe
    streams and both live streams of the task (214 and 1762 records) parse unchanged.
  - **A member's timeout kill leaves nothing behind:** harness-panel TIMEOUT now also asserts
    the plain case (no survivors): no orphan fake codex (every exec turn's pid, checked with its
    start time - fake-codex3's new `FAKE_CODEX_PIDDIR`) and no recovery record.
  - **A latent harness flake fixed:** harness-muse's scratch home had no `AppData\Local`, so
    Windows PowerShell 5.1's `GetFolderPath(LocalApplicationData)` was empty there and a
    long-lived 5.1 process wrote its `ModuleAnalysisCache` relative to its working directory -
    into the test repository, where a muse panel member's tree check failed (seen once in this
    wave's first run, the PANEL case).
  - Tests: harness-muse 72 (+7: F09-1 in-process for every sign-in state, end to end for a
    `providers.meta` without a mechanism under `-SkipPreflight` and in the dry run, for the
    keychain backend in the roster walk and a real panel, and in the listing; F09-2 a prompt-only
    run's repair; F09-3 in-process and end to end through the fake's new `FAKE_MUSE_LINK`,
    `FAKE_MUSE_MODEL_STREAM`, `FAKE_MUSE_MODEL_RUN`, `FAKE_MUSE_TERMINAL_RUN`), harness-engines 97
    (+2: agy's prompt-only repair and denial retry), harness-panel 53 (+1). Existing assertions
    changed where the output legitimately changed: the PREFLIGHT cases of the missing and
    keychain states (now the launch refusal - the keychain case used to run under
    `-SkipPreflight` with `credential_mechanism` null), the UNIT MSP fixtures (the real shape:
    `session.run.linked`, `payload.run_stream`), and the `format_retry` field lists of
    harness-format (REPAIR) and harness-engines (PROSE), which gain `schema_transport`.
  - Docs: README (muse billing, sign-in, reply and failure rules, agy's secondary turns, the
    listing, the ledger and environment tables, the install checklist), the help of
    `codex-consult.ps1` and `codex-providers.ps1`, `consult-codex`, `setup-providers` 3f,
    `tests/README.md`.

### Changed

- Wave 21: the panel is parallel (see "Added"); `sessions.json` is no longer created at a
  run's start (the commit creates it); `findings.json` keeps its findings in id order;
  `consults` stays sorted by n; the F15-3 rule ("later members are not started" after a
  member left survivors) applies to `-PanelConcurrency 1` only. Existing assertions changed
  where the output legitimately changed: the ledger field order (`harness-0.3`,
  `harness-engines`: `finished_at` last), the F15-3 case of `harness-roster` (now with
  `-PanelConcurrency 1`, the record named `.consult.pending-<NN>.json`), the description of
  `harness-engines`' mixed panel case.
- Ledger: `reviewer.engine` (written as `codex` for codex runs; an absent field reads as
  codex), `denial_retry` after `format_retry`, `warnings[]` after `provider_failure` - for
  every engine (`null` / `[]` for codex). `harness-0.3`'s field-order assertion and
  `harness-format`'s `format_retry` position assertion were updated to the new order.
- The recovery record gains `engine` and `events` (the running turn's event stream, for
  both engines); every message about an interrupted run's reservation names it: "the raw
  event stream of that run is at <path> (it may hold a usable reply); no ledger entry was
  written". The process rule also matches the recorded launcher's file name (`agy.exe`).
- Failure classes: `permission` first; Google's codes and wordings added to capability
  (`INVALID_ARGUMENT`, `invalid model selection`, `conflicts with --effort`), auth
  (`PERMISSION_DENIED`, `UNAUTHENTICATED`, `not signed in`, `login required`, `sign in
  to`), quota (`RESOURCE_EXHAUSTED`, `rate_limit_exceeded`) and transport (`UNAVAILABLE`,
  `DEADLINE_EXCEEDED`). `Get-RetryAfter` reads `retry in 32s`, `retry in 1m5.3s`, `retry in
  90 seconds` and gRPC `retryDelay` (`{"seconds":N}` or `"32s"`, also from an error
  payload's details).
- Wave 23 (D2): the denial-retry and format-repair turns of an engine parse their streams
  through `$engineSpec.Adapter.Events` / `.Outcome` (and build their argv through `.Argv`),
  never agy's functions by name - `codex-consult.ps1` names no engine's function any more (a
  static check in `harness-muse`). The panel's kill guard adds the denial-retry budget only for
  an engine that has one.
- Wave 23 (D12): a change detected by the tree check forces class `permission` for agy AND muse
  even when the run had already failed for another reason (that reason stays the provider
  failure's message; the outcome adds `; also: <the change>`) - before, an already failed run
  kept its first class.
- Wave 23: ledger `engine_run` after `usage` for every entry (`null` for codex;
  `{turns, max_model_steps, msp_schema_version}` for an engine). Existing assertions changed
  where the output legitimately changed: the ledger field order (`harness-0.3` LEDGER,
  `harness-engines` RUN: `engine_run` after `usage`), the roster's engine list (`harness-engines`
  ROSTER: "codex, agy, muse"), and `-SchemaTransport native` for codex now says "is for the agy
  and muse engines" (`harness-engines` DRYRUN).
- Wave 23: `codex-providers.ps1` engine rows take their effort vocabulary, declared models and
  schema transport from caps-v1 (agy's row is unchanged: `agy (tier in the model id)`); the
  handoff's Author line shows a mapped effort for an engine that sends one.
- Handoff names, the handoff header (`# Handoff NN - Gemini (agy): <slug>`), the ledger
  `command` (`agy ...`), the pending-record notes and the `.original.md` of a format repair
  take the engine's prefix and label instead of a literal `codex`.

### Known limitations

- TECH_DEBT T7: an agy lineage binds engine + label + model, not the signed-in Google
  account (nothing local exposes it).
- TECH_DEBT T8: agy's read-only rule is enforced by evidence (the tree check), which does
  not see gitignored paths, submodules or files outside the repository and cannot tell who
  changed a file.
- agy has no version flag; `reviewer.harness` is `agy-cli (version unknown)` unless the
  launcher's file metadata names one.
- The harness runs against the fake only; the live runs are listed under "Live evidence"
  above (the F11 denial retry has not fired live through the bridge yet).
- Wave 23 (muse): every case runs against the fake only - the real `muse.cmd` ->
  `.muse-launcher.ps1` -> binary chain (its quoting of paths with spaces, its reaction to an
  empty stdin) is not covered. A resume whose CLI silently started a fresh session under the
  requested `--session-id` cannot be told from a real resume (the stream echoes the id).
  Meta's quota and step-cap wordings are unknown: they are recorded verbatim, classified by
  the shared patterns (a step cap by "max ... steps"). `read_file` is not confined to the
  repository (reads are outside the tree check's evidence). A keychain sign-in cannot be
  checked or its mechanism read (the file backend is required: since wave 23b no muse run
  launches without a readable oauth sign-in). One Meta
  sign-in is one endpoint; a lineage does not bind the signed-in account (T7).
- Wave 23 live evidence (task `muse-engine-2026-09-26`, n=4): `meta ::
  muse-spark-1.3-contributor [muse]` through the Muse Code subscription - usable, structured on
  the first turn, 76.7 s; harness `muse-cli 1.4.0-R4161.1`, the launcher found at the vendor
  install path, sign-in checked (mechanism oauth), one turn, MSP schema 1, tree unchanged. This
  covers the real `muse.cmd` -> launcher -> binary chain the fake cannot.
- Wave 21 (accepted in the decisions): an agy panel member does not catch its own
  reviewer writing its task's `findings.json`/`sessions.json` while members run at the same
  time (F02-2's other half: a consultation on ANOTHER task committing during an agy run
  fails that run - run nothing else beside a panel with agy members); a kill inside a
  commit can leave ORPHAN findings (F03-11); the panel holds the task lock for its whole
  wall clock, so `codex-findings.ps1` writes wait for it (F03-8, relaxable with R12). The
  parallel panel has not run live yet.

## [0.3.0] - 2026-09-24

Implements ROADMAP R7 (provider support with reviewer lineages) and ships R8 as a
convention rather than a schema change, per the design-review round recorded in
`.collab/bridge-0.3-2026-09-24/` (`handoffs/01` the design, `handoffs/02` the Codex
reviewer's findings `F02-1..F02-9`, `state.md` the decisions and amendments). R9
(review groups, findings relations, group stats) is deferred to 0.4.0 — see below and
ROADMAP.md.

### Added

- **R7 — provider support with reviewer lineages.**
  - `-Provider <name>` (requires `-Model`): validated against `[model_providers.<name>]`
    in the Codex config, read with a constrained TOML scanner
    (`Read-CodexConfigSubset`) that understands comments, table headers, bare/quoted
    keys and string/bool/number values, and refuses (naming the line) any table
    containing a construct it does not understand — multi-line strings, arrays, inline
    tables, dotted keys, array-of-tables.
  - Provider identity resolved from the config when `-Provider`/`-Model` are omitted
    (`model_provider`, default `openai`; `model`); unresolvable identity is recorded as
    `unknown` and disallows automatic `fork`/`resume` (`-Mode` defaults to `new`).
  - `reviewer{provider, provider_source, model, model_source, harness,
    provider_fingerprint, provider_config, identity_note}` and `lineage`
    (`<provider>/<model>`) recorded per consult. `provider_source` is one of
    `-Provider`/`config`/`codex default`/`unknown`; `identity_note` explains why
    identity was left unresolved (a `profile` key in the config, an unreadable file, an
    unusable table), empty when identity resolved. Compatibility fingerprint (what must
    match for `fork`/`resume`) is the SHA-256 of `base_url` + `wire_api` only,
    canonicalised — comments, ordering, secret rotation and a table's `name` never
    change it; an endpoint or protocol change does, and refuses fork/resume onto that
    lineage's older threads (`-Mode new` unaffected) — the run is always refused, never
    silently switched to a new thread. A top-level `profile` key in the config leaves
    identity unresolved even when `-Provider`/`-Model` are both given, since a profile
    can override the provider and the effort behind the bridge's back.
  - Parent-thread selection is now scoped to the CURRENT run's lineage: the newest
    ledger entry with a non-empty `thread` and the same lineage, never the task's
    newest thread overall. `-Thread` is validated against the run's lineage and refused
    across lineages, for an unknown uuid, or together with `-Mode new`.
  - A per-run `consult_id` in the prompt, so the rollout-file thread-id fallback only
    records a thread when the candidate rollout file actually contains this run's id
    (`thread_source = 'rollout (verified by consultation id)'`); otherwise the
    candidate uuid is kept only as a diagnostic `thread_candidate`, never as a parent.
  - Effort vocabularies are DECLARED per endpoint, not inferred (capability table
    `caps-v1`, ledger `effort_caps`): built-in `openai` (no user table, no
    `OPENAI_BASE_URL`) keeps `low|medium|high|xhigh` for any model; `api.z.ai` /
    `open.bigmodel.cn` map `low|high|max` (`medium`->`high`, `xhigh`->`max`) for 11
    declared GLM models only; MiMo hosts map `none|low|medium|high` (`xhigh`->`high`)
    for 5 declared models only. `-NativeEffort <value>` sends a value verbatim when no
    vocabulary is declared for the endpoint/model (there is no model-prefix fallback).
    Ledger: `effort_requested`, `effort_sent`, `effort_mapping`
    (`openai`|`zai-v1`|`mimo-v1`|`native`), `effort_caps`, `effort_confirmed` (always
    `null` — Codex's event stream does not report the effort it used).
  - Peak-hour tariff windows: `CODEX_CONSULT_PEAK_<PROVIDER>` (`"<days> <HH:MM>-<HH:MM>
    <+HH:MM|-HH:MM>"`, start inclusive/end exclusive, overnight windows keyed to their
    start day) and `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` (all-day exception
    dates/ranges, evaluated as intervals of any length). `-OffPeakOnly` refuses the run
    when the window is active OR unknown; the window is checked once early and again
    immediately before launch, and it is the launch-time result that is recorded and
    that governs `-OffPeakOnly` (a run entering the window during preparation is
    withdrawn at launch, no ledger entry). Ledger: `peak` (`true`/`false`/`null`),
    `peak_schedule`, `peak_source` (`env`/`env (CODEX_CONSULT_NOW)`/`none`),
    `peak_evaluated_at` (ISO with offset).
  - **Availability preflight and `codex-providers.ps1`.** Before the lock is taken, the
    resolved provider's credentials are checked locally (the same check
    `codex-providers.ps1` uses): missing credentials refuse the run outright, before
    anything is written (`-SkipPreflight` bypasses this; ledger `preflight: "skipped"`).
    Ledger `preflight` = `ok: <detail>` | `unknown: <reason>` | `skipped`; a usage-limit
    failure recorded for the same provider within the last hour adds a console
    `WARNING:` and ledger `preflight_warning`, without refusing. New script
    `scripts/codex-providers.ps1 [-Provider <name>] [-Json] [-CollabDir] [-CodexExe]`
    lists the built-in `openai` and every `[model_providers.*]` table with its verdict
    (`available`/`unavailable (<reason>)`/`unknown (<reason>)`), kind, endpoint,
    credentials, declared effort vocabulary, and the newest usage-limit failure in this
    repository's ledgers within 24 h; writes nothing, takes no lock, makes no network
    call; exit code with `-Provider` is the verdict (`0`/`2`/`3`/`1`).
  - **`-CodexConfig key=value[,…]`**: extra `-c` overrides passed to `codex exec`
    verbatim, after the bridge's own and before `-o`; refuses keys the bridge already
    owns (`model`, `model_provider`, `model_reasoning_effort`, `profile`,
    `model_providers(.*)`); a leading `~/` is expanded to the home directory (Codex on
    Windows does not expand it itself — verified, `os error 123`). Ledger
    `extra_config`. Motivating case: a `[model_providers.mimo]` (Xiaomi MiMo) entry
    whose model catalog must be supplied per run (`-CodexConfig
    model_catalog_json=~/.codex/model-catalogs.json`), since a GLOBAL
    `model_catalog_json` replaces Codex's own catalog and was observed, live, to
    degrade the default `openai` model on an unrelated run ("Model metadata not found,
    fallback").
  - README "Setup on a new machine" (the MiMo-style provider step) documenting the `mimo` provider shape
    generically (Token Plan endpoint, `env_key`, per-run catalog, `mimo` effort
    vocabulary).
  - **Per-host schema transport.** caps-v1 now also declares, per host, whether
    `--output-schema` is passed at all: `output-schema` for built-in `openai`
    (enforced server-side) and the z.ai hosts (accepted but not enforced); `prompt-only`
    for the MiMo hosts and any undeclared host (the bridge never passes the flag; the
    prompt still asks for the JSON object, parsed leniently — bare or fenced). Found by
    the first live MiMo consultation through the bridge, which failed outright at the
    first request because that endpoint REJECTS `--output-schema`
    (`responses_feature_not_supported: text.format type 'json_schema' is not supported,
    only 'text' and 'json_object' are allowed`) — the bridge recorded it correctly
    (preflight ok, lineage, `extra_config`, the error lifted into `bridge_outcome`, exit
    1, no findings) and the fix followed from that failure. Ledger `schema_transport`
    (`output-schema`|`prompt-only`), right after `schema`; `-DryRun` shows it; the reply
    header's `Structured reply:` line gets `(prompt-only transport)` appended when
    applicable. On a `prompt-only` route the prompt appends the schema file itself as a
    final `JSON Schema of the reply:` section (about 2 KB) with a matching format
    instruction; `output-schema` hosts keep the unchanged 0.2.0 prompt.
    `codex-providers.ps1 -Json` reports `schema_transport` per provider too.
  - **Provider failure classification and endpoint health**, from the MiMo review
    (third reviewer, first live consultation on a prompt-only route,
    `.collab/bridge-0.3-2026-09-24/handoffs/09-...`, `F09-1`..`F09-4`). Every failed
    consultation is classified: ledger `provider_failure` (right after
    `bridge_outcome`), `null` on success, else `{class, code, message (<=200 chars),
    when}`; `class` is `auth`/`quota`/`capability`/`transport`/`unknown` by word-bounded
    keyword match; an SSE-style `data:{"error":{...}}` payload on stderr is parsed for
    `error.message`/`error.code` first (this is how the MiMo endpoint reported its
    schema rejection); a bridge-internal failure such as a timeout kill is `transport`.
    The reply header gets a `Provider failure:` line. Endpoint health is now computed
    from ALL task ledgers in the repository, keyed by the endpoint fingerprint (never
    the alias), newest entry wins. `codex-providers.ps1`'s table column is now
    `LAST FAILURE (24 h)` (`<class>: <when> - <message>`); its JSON gains
    `last_failure {class, code, when, message}`.
- **R8 — requested checks (convention).** The structured-mode prompt asks Codex to end
  `reply_markdown`, when useful, with a `## Requested checks` section (`RC1..RCn`, at
  most 5, each one runnable command/procedure with its cwd, permission, expected
  observation and budget, referencing a finding by position/id/invariant). No schema
  change — schema stays v1, the bridge renders nothing extra, `.reply.json` and
  `findings.json` are untouched. `templates/brief-review.md` gains a
  "## Requested checks run" table for the coordinator to fill and cite in the next brief.
- README sections "Reviewer identity and lineage" and "Preflight and endpoint health"; SKILL.md options and a
  manual fan-out note for the second reviewer until R9 exists.
- `tests/`: scripted harnesses (`run-all.ps1` plus `harness-0.3`, `harness-pending`,
  `harness-fixes`, `harness-lock2`, `harness-3b`) that run against a fake `codex` shim —
  no real `codex`, no quota, your own Codex config never touched. Not part of the
  installed plugin package; see README "Tests" and `tests/README.md`.
- **Wave 10 — R9 (partial): reviewer roster, review panel and the scoreboard.**
  - **Reviewer roster.** A JSON file (`CODEX_CONSULT_ROSTER`, else `<codex
    home>/codex-consult-roster.json`; `CODEX_CONSULT_ROSTER=none` disables it, the
    default file included) naming the reviewers the operator is willing to use, first
    choice first: `{roster_version: 1, reviewers: [{provider, model?, codex_config?,
    auth?: "none", panel?: "always"|"weighty"}]}`. An unusable roster (unknown key,
    `roster_version` != 1, an empty/non-array `reviewers`, a duplicate `(provider,
    model)`, anything that does not parse) refuses every run naming the path, `-DryRun`
    included — an existing roster is never silently ignored. `-Provider` still selects
    the reviewer directly, but the matching roster entry supplies its `model` (when
    `-Model` is empty) and `codex_config` (when `-CodexConfig` is empty); `-Thread`
    still fixes the reviewer from its ledger entry, its roster entry supplying
    `codex_config`; otherwise the bridge walks the roster in order and runs the first
    entry whose credentials are present and whose endpoint health allows a run right
    now, recording every skipped entry with its reason (none available = refused,
    naming every entry). `-Model` without `-Provider` narrows the walk to entries of
    that model. `auth: "none"` declares an endpoint that needs no credential at all
    (ignored for `openai`/`requires_openai_auth` providers). Ledger `roster =
    {path, position, skipped: [{provider, model, reason}], applied: []}`, right after
    `preflight_warning`; console/handoff line `Roster: <path> - position 2 of 3;
    skipped openai :: gpt-5.1 (usage limit until <iso>)`. `codex-providers.ps1` gained a
    `ROSTER` column, a closing `roster: <path> -> would select ...` line, and JSON
    `roster_position`/`roster_selected`.
  - **`provider_failure.retry_after`.** A quota failure's reset time, parsed from the
    message (never guessed): Codex's own wording ("try again at Sep 28th, 2026 8:35
    PM."), a bare ISO-8601 timestamp, or a duration including days/weeks. A quota
    failure whose reset time lies in the future makes the endpoint `unavailable: usage
    limit until <iso>` — refused before the lock unless `-SkipPreflight`, and skipped
    outright in a roster walk. A quota failure with no reset time still only warns for
    60 minutes with an explicit `-Provider` (unchanged from before), but a roster walk
    skips it too ("usage limit N min ago, no reset time given"). `codex-providers.ps1`:
    verdict `unavailable (usage limit until <iso>)`, `LAST FAILURE` column `quota until
    <iso>: ...`, JSON `last_failure`/`last_limit.retry_after`.
  - **The review panel (`-Panel`/`-PanelAll`).** Sends the same brief to every available
    roster entry, sequentially, each a complete consultation in its own lineage — own
    preflight, own lock/pending record, own parent thread, own consultation id, own
    reply file (`handoffs/NN-codex-<ReplyName>-<provider lowercased>.md`) and own ledger
    entry. Every member sees only the findings open when the panel started. A
    `"weighty"` roster entry joins only the weighty purposes (`framing`, `decision`,
    `core-contract`, `acceptance`, `stuck`) unless `-PanelAll` is given. Refused with
    `-Provider`, `-Thread`, `-Mode resume`, or without a roster. Ledger `panel = {id,
    position, of, members: [{provider, model, state: "run"|"skipped", reason}]}`, right
    after `roster`. Members run as child bridge processes (internal `-PanelSpec`, never
    a documented user option). A summary block closes the run; exit `0` only when every
    member produced a usable reply.
  - **`-SchemaTransport output-schema|prompt-only`** overrides caps-v1's declared
    transport for one run (not with `-Raw`); ledger `schema_transport_source`
    (`caps-v1`|`-SchemaTransport`|`''`).
  - **New purpose `chore`** (effort `low`, 400 words): a plain-text reply like `-Raw` —
    no schema, no findings — for bounded search/extraction work handed to a cheap
    reviewer, with a purpose paragraph asking for facts with file paths and line
    numbers, not a verdict.
  - **`codex-findings.ps1 -Stats` per-reviewer scoreboard**: one line per lineage
    (raised, verified, implemented, proposed, rejected, wontfix, superseded), based on
    the reviewer of the ledger entry each finding was ingested from; a finding from
    before 0.3.0, or with no ledger entry, counts as `unknown provenance`.
  - **`extra_config_source`** (right after `extra_config`): `''`, `-CodexConfig`, or
    `roster`, mirroring `model_source`'s new `"roster"` value.
- **Wave 12 — usefulness telemetry (the operator's idea: record which reviewer was
  useful on which kind of question).**
  - **`codex-findings.ps1 -Rate <n> -Useful yes|partly|no [-Note "<why>"]`**: the
    judge's own mark of consultation `n` (a ledger entry number). `findings.json`
    gains a top-level `ratings` array of `{n, consult_id, lineage, provider, model,
    purpose, useful, note, when}` (`lineage`/`provider`/`model`/`purpose` copied from
    that ledger entry); rating the same `n` again replaces its record; `-Note` is
    required for `no`. Takes the task lock exactly like a status change.
    `codex-findings.ps1 -Stats`'s per-reviewer scoreboard gains yes/partly/no columns
    from these marks.
  - **New script `codex-scoreboard.ps1 [-CollabDir <path>] [-Task <task>] [-Json]`**:
    reads every task's ledger and findings store (or one task's with `-Task`) and
    prints one row per `(reviewer lineage, purpose)`, a total row per lineage and a
    grand total — `CONSULTS`, `USABLE`, `PROSE`, `FAILED`, `RAISED`, `VERIFIED`,
    `REJECTED`, `WONTFIX`, `SUPERSEDED`, `OPEN`, `HIT%` (`verified /
    (verified + rejected)`), `A/H/R/D` verdict counts, `Y/P/N` rating counts,
    `MEDIAN_S` (median wall time) and `TOKENS` (uncached input / output); a lineage
    with no reviewer field (pre-0.3.0 entries) is `unknown provenance`. Writes
    nothing, takes no lock, makes no network call; `-Json` gives the same rows with
    numeric fields plus `kind`: `purpose`|`lineage`|`total`.
  - SKILL.md step 3 (read, verify, record) now closes with rating the consultation,
    including a prose reply that raised no findings — otherwise the scoreboard only
    ever counts structured reviewers — and the council rules point at
    `codex-scoreboard.ps1` for choosing a panel or a judge on a hard question.
- `tests/harness-roster.ps1` (113 cases) added, covering all of the above; runs under
  Windows PowerShell 5.1 and pwsh 7.6 like `harness-0.3.ps1`.
- **Wave 14 — contract-first prompt and format-repair retry.** Live use on a
  `prompt-only` route surfaced reviewers answering in prose even with the schema in the
  prompt, because the output-contract instruction sat mid-prompt, after the schema, and
  the older wording ("write it exactly as you would a normal reply") implicitly licensed
  prose. Two independently-consulted cheap reviewers converged on the same diagnosis and
  the same fix.
  - **Contract-first prompt.** Every structured prompt now OPENS with the "FINAL OUTPUT
    CONTRACT" paragraph, before the ask and the brief, replacing the 0.2.0/0.3.0
    contract text that could be buried past the schema section on a `prompt-only` route.
  - **`-FormatRetry 0|1`** (default `1`; refused for any other value): when the run is
    structured (not `-Raw`, not `chore`), the bridge got a usable reply (exit 0, no
    timeout, no provider failure) that fails to parse or validate as the schema, the
    thread is verified (from the event stream or a verified rollout), and the prose is
    substantive (≥120 words, or ≥40 with a numbered answer at a line start) — the bridge
    fires ONE repair turn: `codex exec ... resume <thread> -`, read-only, the route's
    lowest effort, no `--output-schema`, a prompt asking to convert the previous message
    verbatim into the one JSON object (schema and consultation id in the prompt, never
    the brief), within `min(-TimeoutSec, 300)` s, under the same lock and recovery
    record. A wrong-but-valid verdict is never retried — only a reply that fails to
    parse or validate at all.
  - On success the repaired object is ingested as the reply (`.reply.json` holds it,
    findings and verdict included); the original prose is kept byte for byte as
    `handoffs/NN-codex-<slug>.original.md` and rendered after the structured section
    under `## Original reply (prose, before format repair)`. On failure the prose is
    kept as before (`structured: false`) and `validation_error` gets ` (format repair
    failed: <why>)` appended.
  - **Drift notes** (warnings, never refusals) compare the repaired object against the
    original prose: differing requested checks, differing numbered answers, a finding id
    named in prose but missing from the object, a differing verdict, the longest prose
    sentences not carried into `reply_markdown`, and a repair turn that resumed a
    different thread (recorded in `format_retry.thread`, with the entry's own `thread`
    left unchanged).
  - Ledger `format_retry`, right after `validation_error`: `null` when repair was not
    attempted or is off, otherwise `{attempted, reason, succeeded, thread, wall_seconds,
    usage, drift, original}`. Console: `format repair: <succeeded|failed> in <s> s;
    drift: <n> note(s)`, one `  drift:` line per note; `-DryRun` prints `format retry :
    1 attempt if the reply is not valid JSON` or `format retry : 0 (off)`. Panel members
    inherit `-FormatRetry` from the main run.
  - `tests/harness-format.ps1` (23 cases) added: the contract-first prompt, the repair
    turn's command and prompt, success and failure ingestion, drift detection, and the
    cases that must NOT trigger a repair (a wrong-but-valid verdict, `-Raw`, `chore`, an
    unverified thread, non-substantive prose). Runs under Windows PowerShell 5.1 and
    pwsh 7.6.
- **Wave 15 — the repair path under review (F20-1..3 / F21-1..3, from the first panel
  that answered the contract-first prompt structured on the first turn on both cheap
  routes).** Drift check 5 now compares EVERY prose sentence of ≥60 characters (the 40
  longest at most) with `reply_markdown`, not the five longest, so a remedy replaced or a
  severity softened in one short sentence is caught. A bridge killed during the repair
  turn no longer leaves the usable first-turn prose as an unnamed orphan: the recovery
  record is rewritten BEFORE the repair process starts with `original` (the
  `.original.md` path) and `first_reply`, every refusal/recovery/`-List` message built
  from it adds `a usable prose reply of that run exists at <path>; no ledger entry was
  written for it`, the fields are cleared once the ledger entry exists, and every run
  that consumed or cleared a record gets a `Recovery record:` header line. The
  substantive-prose gate (`Get-ProseGate`) refuses to spend a repair turn on a refusal
  (leading or dominant "I cannot / I'm sorry / I am unable / As an AI ..." with no
  numbered answer, finding id, `RC` id or verdict), accepts the numbered-answer styles
  `**Q1.**`, `Q1.`, `Q1:`, `1.`, `1)`, `**1.**`, `### Q1`, and uses the floors ≥25 words
  with two answers / ≥40 with one / ≥120 otherwise; a declined repair is recorded in
  `validation_error` as ` (format repair not attempted: <reason>)`. `harness-format`
  grows to 37 cases (GATE, DRIFT5, ORPHAN sections).
- The 0.2.0 contract "a structural error means no verdict and no automatic retry — the
  raw text is kept as the reply body" now has one exception: with `-FormatRetry 1` (the
  default) a substantive prose reply on a verified thread gets exactly one recorded
  repair turn, as above; the original prose is always kept alongside the outcome, win or
  lose.

### Changed

- The default provider is now resolved from the Codex config and always recorded — the
  ledger's `model` field never reads `"config default"` again; it holds the actually
  resolved model (or `unknown` when the config could not be read and no `-Model` was
  given).
- Ledger entries written before 0.3.0 (no `reviewer`/`lineage` field) are treated as
  **unknown provenance**: they are never chosen as an automatic parent, and `-Thread`
  naming one of their threads is refused. Practical consequence: the first 0.3.0
  consultation on a task whose ledger predates 0.3.0 always starts a new thread, no
  matter which provider or model it uses.
- `effort` now equals `effort_sent` (the value actually placed in argv), kept for
  readers of 0.2 ledgers and for `-Stats`; the requested/sent/mapping distinction lives
  in the three new fields above.
- The rollout-file thread-id fallback no longer records a thread on the strength of
  "newest candidate file" alone — it now records one only when that file is verified to
  contain the run's `consult_id`; otherwise the run's `thread` is empty and the
  candidate is kept only as a diagnostic.
- A usable, user-defined `[model_providers.openai]` table now DEFINES the `openai`
  identity (its own `base_url`/`wire_api` become the fingerprint, `identity_note`
  records that the table was used, and `OPENAI_BASE_URL` is then ignored); an unusable
  such table leaves the default `openai` identity unresolved (an explicit `-Provider
  openai` naming it is refused outright); with no table at all, `OPENAI_BASE_URL`
  remains part of the built-in identity as before. Found by the second reviewer
  (GLM-5.3) in the first live consultation run through `-Provider`
  (`.collab/bridge-0.3-2026-09-24/handoffs/04-...`).
- An absent `wire_api` in a provider table is now canonicalised as `wire_api=default`
  (no protocol asserted) rather than assuming `responses`; `provider_config` then has no
  `wire_api` key, and the header/console show `wire_api: (default)`. A later config edit
  that adds an explicit `wire_api` value now correctly counts as an endpoint change and
  refuses `fork`/`resume` onto the older thread. Same source as above.
- Thread-id extraction from the event stream now consults only `thread.started` and the
  session-start events `session.started`/`session_configured` (top-level or
  msg-wrapped); any other event line, including a `turn.started` carrying a foreign
  `session_id`, is ignored for thread purposes — such a line could previously have been
  recorded as this run's thread. Same source as above.
- `lineage` now displays as `<provider> :: <model>` (was `<provider>/<model>`) — display
  only. Parent-thread selection was changed to compare `reviewer.provider` and
  `reviewer.model` separately, ordinally, plus the fingerprint, rather than the
  `lineage` string; an entry whose `lineage` still reads the old slash form matches
  correctly for that reason. The cross-identity refusal message reflects the new
  display form.
- Peak evaluation moved from once-at-launch to twice: an early check and a second,
  decisive one immediately before launch (hashing the tree/brief takes real time and can
  itself cross a window boundary); see "Added" above for what changed in the ledger.
- **Preflight now fails CLOSED** (MiMo review, `F09-1`): an `unknown` verdict — an
  unresolved reviewer identity, or `codex login status` failing to run at all or timing
  out after 15 s — used to be treated as harmless and let the run proceed; it now
  refuses the same as a missing credential, with a distinct message ("availability
  could not be established (...); pass -SkipPreflight to launch anyway, or fix the
  check"). `-DryRun` still only prints the verdict on all three checks.

- **Wave 16 — the plugin as an installable unit.** README rewritten for the AI agent
  that installs, wires and uses the plugin (prerequisites as commands with expected
  output, install, verification, first consultation, a numbered setup procedure, then
  one-fact-in-one-place reference sections; fifteen stale claims fixed — among them the
  false "repeatable `-Artifact`/`-CodexConfig`": one comma-separated string only). New
  skill `setup-providers`: the agent-facing procedure to wire third-party plans
  (config table, `env_key` set by the user only, per-run model catalog, roster,
  verification, invariants). New `SessionStart` hook (`hooks/hooks.json` →
  `scripts/codex-consult-hook.ps1`): one context line per session naming which reviewers
  are usable and what the roster would pick (local checks only, exit 0 always, 30 s
  timeout). New `evals/` suite for `claude plugin eval`: `dry-run-consultation` and
  `providers-listing` as the install test (`tool_used`, `regex`, `file_exists`, `llm`
  graders) plus the read-only `command-plan` case (no shell grant, runs on every platform);
  the two shell cases need `--allow-tools Bash` AND a sandbox backend, which Windows does not
  have yet (the runner refuses to run a shell unconfined), so on Windows only `command-plan`
  runs; `evals/results/` ignored. Manifest descriptions made agent-facing;
  `claude plugin validate` passes; `claude plugin details` lists 2 skills and 1 hook.

### Deferred

- **R9 — review groups and relations** (`-Group`, `codex-findings.ps1 -Link`,
  `relations[]`, `-Stats -Group`) is deferred to 0.4.0 — the reviewer roster, the
  `-Panel`/`-PanelAll` review panel and the `codex-findings.ps1 -Stats` scoreboard
  shipped instead in wave 10 (see "Added" above); a panel's members are still not blind
  ACROSS waves (a later panel on the same task sees an earlier panel's findings). The
  design review
  (`.collab/bridge-0.3-2026-09-24/state.md`) requires, before it ships: an immutable
  group manifest (brief hash, source/artifact fingerprints, purpose, shared
  instructions, frozen baseline findings, member attempts); blind baseline isolation (a
  later group member must not see an earlier member's findings through the prompt — the
  live open-findings block makes sequential members non-blind today); canonical-issue
  membership and report-validity adjudication kept distinct from fix status;
  verification-time records; nullable avoided-rework estimates; idempotent atomic
  relations; failed attempts recorded, not just successful ones. See
  `.collab/bridge-0.3-2026-09-24/` for the full findings trail (`F02-6`, `F02-7`,
  `F02-8`).

### Fixed

- **Atomic store writes on Windows were not atomic under a hard kill.** `Write-TextAtomic`
  replaced the store with `File.Replace` (Win32 `ReplaceFile`), which is documented to
  leave the replaced file gone and the replacement under its temp name when interrupted
  between its steps; the hard-kill harness (`F04-1`) caught exactly that once in a slow
  run (store missing, three stray temp files). The final step is now one rename that
  replaces the target: `MoveFileEx(MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)`
  via P/Invoke on Windows PowerShell 5.1 (compiled once per process; falls back to the
  old path only if `Add-Type` fails), `File.Move(tmp, dst, true)` on PowerShell 7,
  `rename(2)` on Unix (unchanged). The test now re-seeds the store after a failed kill so
  one event counts once, with the assertion kept strict.
- `Stop-ProcessTree` counted a process still shutting down as a survivor (it checked
  descendants right after the kill); it now waits up to 3 s for the killed pids to exit
  before judging survivors — a false survivors record would have kept
  `.consult.pending.json` and blocked the task until the next scan.
- Acceptance-round findings (`F06-1`..`F06-4`, `.collab/bridge-0.3-2026-09-24/`):
  - `F06-1` — the built-in `openai` identity was used whenever no
    `[model_providers.openai]` table was FOUND at the expected spot, which missed a
    declaration hidden by a construct at `model_providers` itself or by an `openai`
    entry written inline inside `[model_providers]`. The scanner now establishes
    whether such a declaration COULD exist before falling back to the built-in identity;
    when it cannot be established, identity is unresolved with a note naming the file
    and the reason, `fork`/`resume` are refused, `-Mode new` still works. A construct
    under an unrelated provider no longer affects the `openai` identity.
  - `F06-2` — parent-thread matching compared the `lineage` DISPLAY string, which is
    fragile against a provider or model name containing `/`. It now compares
    `reviewer.provider` and `reviewer.model` separately (ordinal) plus the fingerprint;
    the display form changed to `<provider> :: <model>` as a consequence (see "Changed").
  - `F06-3` — peak was evaluated once, before the run's own file hashing, which could
    let a long preparation step cross into (or out of) the window unnoticed by the time
    Codex was actually launched. It is now re-evaluated immediately before launch, and
    `-OffPeakOnly` acts on that result: a run that enters the window during preparation
    is withdrawn at launch with no ledger entry. Test hook `CODEX_CONSULT_NOW` added to
    make both evaluations reproducible in the harnesses.
  - `F06-4` — `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` ranges longer than a few days were
    rejected as malformed; they are now accepted as intervals of any length, and only
    `end < start` is refused.
- A pwsh `[DateTimeOffset]`/`[datetime]` normalisation gap in the usage-limit scan
  (`Find-UsageLimitFailure`) that could misjudge a ledger entry's age under PowerShell 7
  the same way the 0.2.0 lock/recovery comparisons once did (see 0.2.0 Fixed) is closed
  by parsing `when` through the same tolerant path.
- MiMo-review findings (`F09-1`..`F09-4`, third reviewer, first live consultation on a
  `prompt-only` route, `.collab/bridge-0.3-2026-09-24/handoffs/09-...`): preflight's
  `unknown` verdict silently proceeding (see "Changed" above, `F09-1`); a failed
  consultation carrying no structured record of WHY it failed, which endpoint health now
  needs (`provider_failure`, `F09-2`); endpoint health being scoped to one task's ledger
  and to a provider ALIAS rather than every ledger and the actual endpoint fingerprint,
  which let the same endpoint under two names hide a real auth failure from each other
  (`F09-3`); no distinct refusal for a recently-auth-failed endpoint, which used to look
  identical to a routine missing-credential refusal (`F09-4`).
- **`F12-2`.** The failure-class order was not deterministic against a message
  matching more than one keyword set, and `auth`'s keywords were not word-bounded (a
  message containing "text authored by" could misclassify as `auth`). Failure classes
  are now tried in a fixed order — `capability`, `auth`, `quota`, `transport` — so "your
  token plan does not support response_format" is always `capability`, never `quota`;
  `auth` now matches whole words only; `capability` also matches "does not support" (not
  just "not supported"/"unsupported"); `quota` also matches `rate_limit`/`usage_limit`
  (underscore form, as some endpoints spell it) alongside the existing keywords.
- `codex login status`'s output is now decoded as UTF-8 (it was read with the console's
  default codepage before), matching Codex's stderr and event stream, which were already
  UTF-8; a non-ASCII line in the login status (a non-English account name, for instance)
  no longer risks a garbled credential check.
- **Wave 11 — four defects found by the first live review panel**
  (`F15-1`..`F15-4`, `.collab/bridge-0.3-2026-09-24/`, fixing wave 10's own design):
  - **`F15-1` (blocker).** A reset time parsed from a wall-clock message (e.g. "try
    again at Oct 26th, 2026 8:35 PM") is now interpreted with the recording machine's
    time-zone rules (`[TimeZoneInfo]::Local`) **at write time**, DST included — an
    invalid hour (a spring-forward gap) takes the post-transition offset, an ambiguous
    hour (a fall-back overlap) the pre-transition one — and stored as an instant,
    `provider_failure.retry_after`, carrying that offset. A legacy entry with no
    `retry_after` falls back to reparsing its message using the failure's own `when`
    offset as the reference zone, labelled internally `RetryAfterBasis
    "message (reference offset)"` (a fresh write's is `"ledger"`). Residual: such a
    legacy entry, read on a machine in a different zone than the one that recorded it,
    can still be off by the zone difference, since no zone was ever stored for it; every
    entry written from now on is a true instant.
  - **`F15-2` (major).** Ledgers are now parsed with `ConvertFrom-Json -DateKind
    Offset` when the cmdlet has that parameter (pwsh >= 7.5), so `when` keeps its
    recorded offset instead of being silently converted to a local `[datetime]`;
    Windows PowerShell 5.1, which has no such parameter, keeps reading these fields as
    plain strings, unchanged.
  - **`F15-3` (major) — the panel contract is narrowed.** A member's failure no
    longer unconditionally leaves the others running: when it leaves surviving
    processes behind (the task's `.consult.pending.json` reservation stays active),
    the remaining members are not started at all and are recorded `skipped` with
    reason `not started: the previous member (<lineage>) left surviving processes
    (.consult.pending.json state survivors); recover the task first` (summary
    `skipped  not started: ...`, exit 1) — the one-consultation-per-task rule stays
    absolute, even inside a panel run.
  - **`F15-4` (minor).** Endpoint-health records dated in the future are no longer
    ignored; their age clamps to 0 ("counts as now"), so a skewed clock can no longer
    hide a fresh auth or quota failure behind an apparently ancient timestamp.

### Known limitations

- Codex profiles selected via the CLI (`-p`/`--profile`) are never passed by the bridge;
  a `profile` key in the Codex config IS detected (it leaves reviewer identity
  unresolved and disables automatic fork/resume), but the bridge still cannot know what
  that profile would do to the provider, model or effort before the fact.
- The TOML scanner is a constrained subset (see "A second reviewer through the same
  bridge" in the README) — it refuses rather than guesses, but it is not a TOML parser.
- Other built-in Codex providers (`oss`, `ollama`, `lmstudio`, …) are not recognised —
  only the built-in `openai` identity and `[model_providers.<name>]` tables are.
- TOML 1.1 unicode bare keys make the file unusable to the scanner (it only accepts
  ASCII bare keys); quote the key as a workaround.
- `openai`'s auth mode (API key vs ChatGPT sign-in) is not part of the provider
  fingerprint — switching auth mode does not start a new lineage.
- Peak-hour windows are re-checked immediately before launch (see `F06-3` above), but
  a long consultation can still cross into a peak window after that point — there is no
  third, mid-run check.
- `CODEX_CONSULT_NOW` is a TEST HOOK for the harnesses (successive comma-separated ISO
  timestamps stand in for the system clock across a run's peak evaluations); it should
  never be set in normal use.
- `effort_confirmed` is not observable through Codex's event stream and is always
  `null`.
- The credential preflight (and `codex-providers.ps1`) can only see what is LOCALLY
  present — an `env_key` set, a bearer token in the config, a ChatGPT login. It cannot
  see actual quota or rate-limit state; the "last limit"/"last failure" it reports is the
  newest past failure recorded in this repository's own ledgers, not a live check. A
  credential's validity is only ever learned from a failed run — the bridge records and
  reacts to that failure, it cannot probe.
- MiMo's exact wording for exhausted credits is unverified (the quota keyword list
  includes `credits`/`token plan`/`payment required` as a best guess, not a confirmed
  message).
- macOS is still not exercised for 0.3.0's provider/config-reading paths.
- What Codex itself does with a user-defined `[model_providers.openai]` table, and with
  a provider table's default `wire_api`, were not verified against the Codex source;
  both rules are conservative either way.

## [0.2.0] - 2026-09-24

Implements ROADMAP R1–R6 and TECH_DEBT T1–T4, agreed between the Claude Code coordinator
and the Codex reviewer on 2026-09-23 after a seven-wave task with three consultations,
then refined through a design-review round (`.collab/bridge-0.2-2026-09-23/`) that put a
HOLD on the first design and adopted the schema, locking and revision-binding contracts
below before implementation started. The implementation itself then went through two
live `-Purpose acceptance` rounds: the first came back **HOLD, 11 findings**, and the
re-acceptance round that followed it raised four more (`F06-1`, `F06-2`, `F06-3`,
`F04-10`) that led to the final ownership/recovery split described under T3; a second
re-acceptance narrowed the HOLD to `F04-10` alone (recovery must not trust a dead launcher
or elapsed time), and the third re-acceptance on 2026-09-24 returned **ACCEPT** with one
informational note (`F10-1`, the documented conservative-refusal trade-off). Every finding
was fixed and verified, or recorded as an accepted limitation, before this release. Full
trail in `.collab/bridge-0.2-2026-09-23/` (`handoffs/04`, `06`, `08`, `10` are the four
acceptance replies; `state.md` is the record).

### Added

- `ROADMAP.md` and `TECH_DEBT.md`, each with a per-item **Status (0.2.0)** line recording
  what shipped, what is partial, and what is deferred and why.
- **R1 — core-contract checkpoint** (`-Purpose core-contract`): a review meant to run
  before dependent work is built on the core, re-triggered by changes to recovery,
  persistence or interfaces; xhigh effort, 900-word preset.
- **R2 — brief templates**: `templates/brief-framing.md` (framing/decision/stuck) and
  `templates/brief-review.md` (checkpoint/core-contract/acceptance/diff-review), covering
  delta-since-last-review, CURRENT invariants, changed files with fingerprint, open
  findings, evidence paths, and small critical executables inline.
- **R3 — structured findings** via Codex `--output-schema` (schema v1,
  `schemas/consult-reply.schema.json`): every reply is parsed and validated by default;
  findings carry `severity`, `locations[]`, `claim`, `trigger`, `evidence[]`
  (`kind`/`reference`/`observation`), `verification`, `remedy`, `supersedes[]`. `-Raw`
  opts back into the 0.1 plain-text mode.
- **R4 — acceptance output standard**: every structured reply's rendered file ends with
  `### Findings`, `### Prior findings`, `## Verdict`, `### Blockers`,
  `### Unproven scenarios`, `### First-run checklist (observable)`.
- **R5 — review-purpose presets with measurements**: `-Purpose framing|decision|
  checkpoint|core-contract|acceptance|diff-review|stuck`, each with a default effort and
  word cap; `codex-findings.ps1 -Stats` reports effort, wall time, tokens and finding
  counts per consultation.
- **R6 — role-split guidance**: a "Role split" section in the skill and the README
  documenting primary (not exclusive) responsibilities between a same-family verifier and
  Codex.
- **T1 — findings tracked by id**: `<task>/findings.json`, ids `F<NN>-<k>`, status
  lifecycle `proposed → implemented → verified` with `rejected`/`wontfix`/`superseded`
  and an explicit reopen; new script `scripts/codex-findings.ps1` (`-List`, `-All`,
  `-Stats`, `-Id … -Status … -Note … -Evidence …`).
- **T2 — revision and artifact binding**: `tree_sha256` (a deterministic manifest
  fingerprint over `<XY> <mode> <blob|deleted|dir> <path>`, before and after the run —
  the `<mode>` field, from `git diff --raw HEAD`, was added after the live acceptance
  review found a file-mode-only change did not move the fingerprint; **values of
  `tree_sha256` from before this field are not comparable with values computed after**),
  `base_commit`, `brief_sha256`/`brief_sha256_after`/`brief_changed_during_review`, and
  `-Artifact <path>` (repeatable, or comma-separated) hashed into the ledger as
  `artifacts[].{path, sha256, sha256_after}` with an `artifacts_changed_during_review`
  flag — the brief and every artifact are now fingerprinted before and after the run,
  independently of the tree, so an edit to either during a long consult is caught even
  when the tree itself never moved. `fingerprint_note` records every omission (untracked
  file modes not recorded, submodules not recursed, collab dir excluded, no git).
- **T3 — outcome/verdict separation and an active-session guard**: `bridge_outcome`
  (did the bridge produce a usable reply) is now separate from `verdict` (what the
  reviewer decided). Ownership and recovery ended up as **two separate, permanent
  files**, the design settled by the re-acceptance round: `<task>/.consult.lock` is
  never deleted and its content is purely informational — ownership is holding it open
  (Windows `FileShare.Read`, elsewhere an advisory `flock`), and release is just closing
  the handle, so there is nothing left to "unlock" and no pid/start-time/nonce heuristic
  to get wrong. `<task>/.consult.pending.json` is the actual recovery record (states
  `reserved → launching → running → survivors`), read and judged by the next run before
  it writes anything: a live codex process named in it (found by pid for
  `running`/`survivors`, or by a process scan for `launching`) refuses the new run;
  otherwise the interrupted run's reservation is consumed and the record replaced, and
  numbering skips past it. Both `.consult.lock` and `.consult.pending.json` are
  git-ignored. `sessions.json` and `findings.json` are now replaced atomically (temp
  file + rename) and an existing store that fails to parse is treated as corruption and
  refused, never silently replaced. Artifacts and the brief are now re-hashed after the
  run by the exact resolved path recorded at the first hash, not by name.
- **T4 — brief hygiene**: the review templates are delta-plus-pointers by design, with an
  explicit CURRENT-invariants section so a resumed thread's brief does not have to retell
  its own history.
- `scripts/codex-consult-common.ps1`: shared helpers dot-sourced by both scripts.
- `ROADMAP.md` "Additional reviewers" (R7 provider support with reviewer lineages, R8
  requested checks, R9 review groups), agreed from one brief answered independently by the
  Codex reviewer and by GLM-5.3 (`.collab/multi-model-2026-09-23/`), with the facts that
  shaped it: the bridge already runs a second model through a Codex `model_providers`
  entry, `--output-schema` is not enforced server-side on that route (the reply comes back
  as a fenced JSON block, which the 0.2.0 parser accepts and validates locally), and a Codex
  thread cannot change provider once it holds compaction items.
- This repository's own consultations under `.collab/` (the 0.2.0 design review that put a
  HOLD on the first design, and the additional-reviewers brief), committed as the first
  real examples of the file trail the bridge produces.
- `examples/`: the fabricated example brought up to the 0.2.0 shapes (`sessions.json`
  entry fields, `.reply.json`, `findings.json`, rendered reply sections).

### Changed

- **Breaking:** the ledger field `outcome` is renamed to `bridge_outcome`. Existing
  `sessions.json` files are left untouched — the loader only reads `thread` back — but
  any tooling reading `outcome` from new entries must be updated.
- `-Effort` and `-MaxWords` no longer have fixed defaults (`high`/`700`); with no value
  given, they resolve from the `-Purpose` preset (`high`/`700` when no purpose is given
  either, so an unqualified call behaves as before).
- The reply file's `NN-` prefix matcher now accepts three or more digits, so a
  handoffs directory past `99-` numbers correctly (`100-…` → next is `101-…`).
- Write order per consult is now `.reply.json` (byte-for-byte, before parsing) → `.md`
  → `findings.json` → `sessions.json`; a failed copy of the raw reply is itself a bridge
  failure (`bridge_outcome = "failed: could not preserve the raw reply (…)"`) rather than
  proceeding to parse a reply that was never safely captured.
- Verdict validation now also checks that the verdict fits the purpose
  (`ACCEPT`/`HOLD`/`REJECT` for `acceptance`/`diff-review`, `ADVISE` otherwise) and that
  `ACCEPT` does not contradict a prior open blocker reported `still-open`; an `ACCEPT`
  next to a prior blocker reported `not-checked`/`unknown-id`/unmentioned is kept but
  recorded in the new `unchecked_prior_blockers` ledger field with a console warning.

### Removed

None.

### Fixed

- PowerShell 7 only: `ConvertFrom-Json` in pwsh converts ISO-8601 strings to `[datetime]`,
  so the recorded start time of a lock holder or codex child no longer compared equal to
  the live process's start time and a live holder was reported as "a live process" instead
  of by pid (and, in the recovery check, could be mistaken for a reused pid). The four
  affected reads now normalise the value back to JSON text. Found by the first pwsh run
  of the harnesses (2026-09-24); Windows PowerShell 5.1 was never affected.
- Linux only (first run on WSL Ubuntu 24.04 with pwsh 7.6, 2026-09-24): a process start
  time read through .NET on Linux can differ by under a second between readers, so the
  exact comparison declared a live codex child a reused pid and let a second consultation
  start beside it (now a one-second tolerance off Windows, exact on Windows); the holder's
  own lock file could not be read back through a shared `FileStream` because the advisory
  lock blocked it, so refusals named "a live process" instead of the pid (read via `cat`
  off Windows); the timeout kill stopped children before the root, leaving the root a
  window to spawn more (root first now).

- Recovery no longer treats a dead launcher, or elapsed time, as proof that the codex
  tree is gone (second re-acceptance, F04-10): when every pid a `running`/`survivors`
  record names has exited, and for a `launching` record, the next run scans for children
  of the dead bridge or of a dead recorded pid and then for any codex-looking process
  started after the record; the earlier thirty-minute cut-off on that fallback is gone.
  A refusal names the process and the record; deleting `.consult.pending.json` is the
  deliberate way to clear a refusal you know is unrelated.

### Known limitations

- Cross-host lock takeover is not implemented — a lock left by another host that names
  a live codex process is always refused, and can only be cleared by hand once you know
  that process is dead; a same-host leftover recovers automatically and needs no manual
  deletion.
- Thread-scoped exclusion (one Codex thread resumed from two task directories) is
  documented as a constraint, not enforced.
- No immutable snapshot of the reviewed tree; the before/after fingerprint (now also
  taken for the brief and every artifact) flags a changed input instead of preventing
  the race.
- macOS is not exercised; the Linux run (WSL Ubuntu, pwsh 7.6) covers the same pwsh
  code paths (`flock` share mode, `ps` scan, `pgrep` tree kill), but no macOS machine
  was available.
- On Unix the atomic replace of a store resets its permission bits to the default;
  messages render dates in an invariant format on every platform.

## [0.1.1] - 2026-09-23

### Added

- Project-isolation guarantees written down (README "Project isolation", skill
  invariant 5): the ledger, the `fork`/`resume` parent thread and Codex's working
  directory are all scoped to the git repository the bridge runs from, so one
  user-scope install serves many projects; a repository with no ledger starts a fresh
  thread. Verified with a throwaway repository. Also spelled out what is *not*
  enforced: the read-only sandbox blocks writes, not reads, so briefs must stay inside
  the repository and a `-Thread` id must never be borrowed from another project.

### Changed

- No script changes. Version bump only, so installed copies pick up the new skill text.

## [0.1.0] - 2026-09-22

First public release.

### Added

- `codex-consult` plugin, installable from the `claude-codex-consult` marketplace.
- Skill `consult-codex`: when to consult Codex, how to write a one-page brief with
  numbered questions and a word cap, the one command to run, and the read-verify-record
  loop that follows.
- `scripts/codex-consult.ps1`, a dependency-free bridge to `codex exec`:
  - `-Mode new|resume|fork` with automatic thread continuity per `-Task` id;
  - `-Model` optional — with no `-Model`, Codex uses the model from the user's
    `~/.codex/config.toml`;
  - read-only sandbox by default, `danger-full-access` refused with no override;
  - exec-level options emitted before the `fork`/`resume` subcommand;
  - the prompt delivered on stdin via `-`, so the Windows `codex.cmd` shim cannot
    expand `%VAR%` patterns inside a brief;
  - thread id parsed from the first `--json` `thread.started` event, with a
    `$CODEX_HOME/sessions/**/rollout-*.jsonl` fallback and a `thread_source` field
    recording which one was used;
  - failure detail lifted from the JSON event stream (`error` / `turn.failed`), where
    Codex reports quota and auth failures — stderr is only a fallback;
  - reply written as header + `---` + the verbatim reply, next to the raw
    `.events.jsonl` event stream;
  - every call appended to `<CollabDir>/<task>/sessions.json`, failures included;
  - `-DryRun`, `-CollabDir`, `-CodexExe` / `CODEX_CONSULT_EXE`, `-TimeoutSec`,
    `-MaxWords`, `-Effort`, `-ReplyName`.
- `examples/` with a fabricated brief, reply and ledger showing the produced layout.

### Known limitations

- Exercised on Windows PowerShell 5.1 with Codex CLI 0.155.1. PowerShell 7 and
  macOS/Linux are written for but not yet verified.
- No bash port yet, so macOS/Linux currently needs `pwsh`.

[0.3.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.3.0
[0.2.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.2.0
[0.1.1]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.1
[0.1.0]: https://github.com/xelth-com/claude-codex-consult/releases/tag/v0.1.0
