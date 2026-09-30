# Handoff 01 - the coordinator: the `claude` engine (R10, wave 29) - design for review

Write in English.

# R10 - the `claude` engine: Claude Code headless as a reviewer (design for review, wave 29)

Goal (ROADMAP R10, with R22): a fourth reviewer engine beside `codex`, `agy` and `muse` - Claude Code in print
mode (`claude -p`), read-only file tools, the bridge's reply schema natively, one Claude Code session per thread.
It is one more row of `$script:Engines` (`codex-consult-common.ps1`) plus its adapter functions, as the table's
header already announces; the run block gains one small hook only (the child's environment, item 5).

Markers: (obs) observed on this machine on 2026-09-30 with Claude Code 2.1.285 - the probe of the facts file,
the launcher on disk, or the coordinator's own session; (help) the text of `claude --help` 2.1.285; (assumed)
neither - to be confirmed by the reviewers or by the verification run.

## Context

- `Start-EngineProcess` starts every engine with `-WorkingDirectory $repoRoot` inside `Hide-HostMarkers`. The
  reply schema `plugins/codex-consult/schemas/consult-reply.schema.json` (2.2 KB) reaches an adapter as a PATH
  (`New-EngineTurnOptions -Schema`); `claude --json-schema` takes the schema TEXT (help; obs probe).
- The launcher here is the native `%USERPROFILE%\.local\bin\claude.exe`, file metadata ProductVersion 2.1.285.0,
  no npm `.cmd` shim; the updater leaves `claude.exe.old.*` files beside it (obs).
- An unrestricted session in the repository receives the user's `CLAUDE.md`, an `AGENTS.md` of a parent
  directory and the project's auto-memory (obs: the coordinator's own session). With `--restricted`, a code word
  in the working directory's `CLAUDE.md` and `AGENTS.md` did not reach the model; without it, it did (obs).
  Transcripts live in `~/.claude/projects/<working-directory slug>/<session id>.jsonl` (obs).

## Design

1. **Command line.** One turn is `claude -p --output-format stream-json --verbose --restricted
   --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model <m>
   [--effort <e>] [--json-schema <schema text>] [--add-dir <dir>...] (--session-id <new uuid> | --resume
   <thread> [--fork-session])`, working directory = the repository root (as every engine; `Start-EngineProcess`
   unchanged), prompt on stdin as plain UTF-8 text. It is the observed set (obs) minus the argv prompt (a brief
   exceeds the command line; stdin since F02-14); `-p` reading all of stdin: assumed - Q1.
   - `--add-dir` only for a rooted `-CollabDir` outside the repository (`Resolve-CollabRoot` keeps it) and the
     directory of a `-Brief` or `-Artifact` outside it (the prompt carries its absolute path); usually none.
   - Tools: `--tools` REMOVES the rest (init lists Glob, Grep, Read, StructuredOutput - obs); `--allowedTools`
     would only pre-approve. `dontAsk` worked (obs); that it denies whatever is not pre-approved without
     waiting is (assumed); `--permission-prompts none` (help) stays out until Q2 shows it adds something.
   - Schema: the adapter reads the file named by `$Turn.Schema` and passes its one-line text (`ConvertTo-ProcArg`);
     caps-v1 row `engine:claude` = { Vocabulary `claude`; Models `$null`; SchemaTransport `native` }, prompt-only
     still selectable. Reply = `structured_output` (obs), else the `result` text (prose -> format repair).
   - Model: the roster `model` goes to `--model` on a new thread. Aliases float (help: "an alias for the latest
     model"), so every later turn of the thread sends the RESOLVED id its first init event reported (obs: init
     carries it). `reviewer.model` keeps the roster string; `engine_run.model_resolved` is added; an init model
     that differs from a sent full id fails the turn, class capability (muse's drift rule).
   - Effort: vocabulary `claude`, mapping `claude-v1`: low, medium, high, xhigh as is (help adds `max`, sent only
     via `-NativeEffort`); repair turns send `low`; `effort_confirmed` null. Models `$null`: the CLI accepted
     `--effort` with the smallest model (obs); applied there? - Q3. No `--no-session-persistence` (every
     secondary turn resumes); `--max-turns` is not in `--help`, so StepsFlag '' and `-MaxModelSteps` refused.

2. **Lineage.** Modes new, resume, fork; DefaultMode `new` (as agy and muse: the reviewer reads the brief without
   a grown context; codex's automatic fork is not copied - Q4).
   - new: the bridge mints a uuid for `--session-id` (help: must be a valid UUID). The thread is known before the
     first byte, so a turn killed before its `result` still has a thread its init event confirmed.
   - resume: `--resume <thread>` keeps the id (help: only `--fork-session` creates a new one); init and result
     `session_id` must equal the parent, else the turn fails (agy's rule for secondary turns).
   - fork: `--resume <parent> --fork-session`; new id = init `session_id`, a uuid, not the parent, equal to the
     result's; pinning it with `--session-id` - Q5. Item 4's init check proves the tool set per turn.
   - Ledger: thread = result `session_id` (the init id when killed), `thread_source` events, `thread_candidate`
     on disagreement. Transcripts go to `projectsDirectory` of `claude auth status` (obs; `~/.claude/projects/
     <repository slug>/`), outside the repository: the tree check ignores nothing new; a `projectsDirectory` inside
     the repository refuses the launch. They sit beside the operator's own sessions of that repository (accepted).
     `--resume` finding a session only from the same working directory: assumed; the repository root is stable.

3. **Event stream** (`Read-ClaudeEvents`, `Get-ClaudeTurnOutcome`), one JSON object per line (obs).
   - `system`/`init`: `session_id`, `model`, `tools`, `mcp_servers`, `permissionMode`, `apiKeySource`, `cwd`,
     `plugins` (obs) -> thread, `model_resolved`, the checks of items 4 and 6.
   - `assistant` blocks `text` (agent message, salvage), `thinking` (salvage), `tool_use` {id, name}; `user`
     blocks `tool_result` {tool_use_id} (obs). `Update-ToolFlight`: a tool is in flight while a `tool_use` id
     has no `tool_result`. `system`/`thinking_tokens` (obs) grows the file; during one long block? - Q6.
   - `result`, exactly one, last line (obs): usable = `subtype` success, `is_error` false, `structured_output`
     (native) or `result` text (prose). HasUsage: `usage` input, cache read (cached), cache creation, output;
     the `modelUsage` keys are recorded; `total_cost_usd` stays local as `engine_run.cost_usd` (notional on a
     subscription). Partial last line only after a kill or non-zero exit; garbage after exit 0 fails (agy rules).
   - Format repair: one `--resume <thread>` turn, the main transport, effort low, the pinned model, same id.
   - Denial: DenialRetry `$true`, but `DeniedEmpty` only on evidence - success, no reply, `permission_denials`
     not empty (the F11 shape). With read tools only a denial is a Read outside the working directories; that
     it returns a `tool_result` error and the model goes on is (assumed) - Q2. Denials beside a usable reply
     are recorded (count, tool names) as a warning.
   - Classes: exit 1 with `Not logged in · Please run /login` -> auth (obs); `is_error` with limit wording or a
     rejecting `rate_limit_event` -> quota; other exit codes, subtypes and wordings - Q7.

4. **Read-only enforcement.** Guaranteed: only Read, Grep, Glob and StructuredOutput exist (obs); `--restricted`
   removes code-running tools and WebFetch, confines file tools to the working directories (`--add-dir`
   included), refuses bypassPermissions, ignores user, project and local settings and so their hooks (help);
   `mcp_servers: []` (obs). No write tool exists at all (agy's writes came through a granted tool, F12). Not
   guaranteed: managed settings and `--settings` still apply (help) - a managed hook could write; gitignored
   files inside the repository (a `.env`) are readable, as with every engine. Therefore `WriteDisabled = $true`
   (a tree change warns, the muse rule) on condition that the capability is PROVEN per turn: an init listing a
   tool outside that set, any MCP server or a mode other than `dontAsk` fails the turn with class `permission`
   whatever the tree shows (evidence first, F09-3); the SandboxRecord says "verified by each turn's init event".

5. **Reviewer child hygiene (R22).** A restricted session still lists the built-in plugins `cc-plugin-agents-md`
   and `cc-plugin-telemetry` and the built-in agent types, without the Agent tool (obs). Decisions:
   - `--restricted` alone keeps the repository's `CLAUDE.md` and `AGENTS.md` out: a code word in both files did
     not reach a restricted reviewer and did reach an unrestricted one (obs). It also ignores user, project and
     local settings, so their plugins and hooks (help); MCP and skills are off by item 1's flags. Still open: the
     home directory's `~/.claude/CLAUDE.md` (likewise a parent `AGENTS.md`, the auto-memory) - Q8. `--safe-mode`
     gave the same result on the repository files (obs); it is not in the argv - an operator may add it.
   - Working directory: the repository root, as for every engine. ToolsLine: "Tools: you may read files of the
     repository (Read, Grep, Glob); no shell, web or write tool exists in this consultation; make NO file
     changes; a check that needs a command belongs under `## Requested checks`."
   - Not used: `--setting-sources` (restricted ignores the three sources already - help); `--system-prompt` (drops
     the tool guidance; CLAUDE.md is not part of the system prompt - assumed); `--bare` (API key only - obs).
   - Environment: the wave 27 scrub already removes the Claude Code session markers. In subscription mode the
     claude child also loses every `ANTHROPIC_*` variable (key, auth token, base URL, headers, model overrides),
     `CLAUDE_CODE_USE_BEDROCK|VERTEX|FOUNDRY` and `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD`, and gets
     `DISABLE_AUTOUPDATER=1` - a reviewer must not replace the binary the coordinator runs (names assumed);
     `CLAUDE_CONFIG_DIR` stays (the login lives there). `Adapter.ChildEnv` { Remove; Set } runs inside the
     `Hide-HostMarkers` transaction; `child_env_scrubbed` lists names; `engine_run.switched_off` what R22 asks.

6. **Authentication and preflight.** The subscription login works without a key, `apiKeySource: none` (obs).
   - Roster `auth` (refused for engines today) is allowed for claude only: `subscription` (default) or `api-key`.
     subscription: the child loses the `ANTHROPIC_*` variables and a turn whose init reports another
     `apiKeySource` fails, class auth - muse's fail-closed billing rule (F09-1), on evidence. api-key:
     `ANTHROPIC_API_KEY` must be set and passes. `provider_config.credential_mechanism` records which.
   - `Get-ClaudeSignIn` never spends a request: `claude auth status` (obs: local, free, JSON with `loggedIn`,
     `authMethod` - `claude.ai` for the subscription -, `apiProvider`, `projectsDirectory`), 15 s. No launcher ->
     missing; `loggedIn` true -> available (subscription also wants `authMethod` `claude.ai`; api-key wants
     `ANTHROPIC_API_KEY` set); `loggedIn` false -> out; command missing, non-zero exit, malformed JSON or timeout
     -> not checked. No credentials-file fallback. LocalSignIn `$true`; `authMethod`, `apiProvider` -> ledger.
   - Harness: the default file-metadata path gives `claude-cli 2.1.285.0` (obs); an npm shim uses `--version`.
   - Limits: a rejecting `rate_limit_event` -> class quota with its reset time -> the health record; a warning
     status -> a ledger note; field names assumed - Q10. All claude labels share the engine's health (one plan).

7. **Timeouts and kills.** The child is the native `claude.exe` (obs), its children the search helper of Grep and
   Glob (assumed); an npm install runs `claude.cmd` -> node (assumed), where the `%` hazard hits argv only.
   `Stop-ProcessTreeChecked` (taskkill /T /F, confirmed as in wave 27c) is unchanged. LauncherNames `claude.exe`,
   `claude.cmd`, `claude`; InstallLaunchers `%USERPROFILE%\.local\bin\claude.exe` (obs); ExeEnv
   `CODEX_CONSULT_CLAUDE_EXE`. `Read-ClaudeSalvage` writes the last `text`, then `thinking` blocks to `.partial.md`.
   The continuation resumes the minted thread with the pinned model; whether a session killed mid-turn resumes
   - unknown - Q11; a failed resume is an ordinary continuation failure, never a silent new thread.

8. **Roster.** `{ "provider": "anthropic", "engine": "claude", "model": "claude-opus-5-5", "auth": "subscription",
   "panel": "weighty", "lab": "anthropic", "context_tokens": 1000000, "timeout_sec": 1800 }`. `LabVendors` gains
   `claude=`, `opus=`, `sonnet=`, `haiku=`, `fable=anthropic` (the prefix match covers aliases and full ids).
   `context_tokens`: 1,000,000 for Opus, Sonnet and Fable, 200,000 for Haiku (the window a plan grants per model
   - assumed); the engine compacts on its own, the guard only decides the fallback to `new`. Validator for
   engine claude: `model` required, matching `^(opus|sonnet|haiku|fable)$` or `^claude-[a-z0-9][a-z0-9.-]*
   (\[1m\])?$` (other vendors' models through this engine are out of scope); `auth` only `subscription` |
   `api-key`; `codex_config` refused; an alias warns "the alias floats; each thread is pinned to the resolved id".

9. **The coordinator's own model.** A claude reviewer is spelled `anthropic :: <roster model> [claude]`
   (`Format-CoordinatorText`). For this engine `Get-CoordinatorMatch` compares the coordinator's provider with
   `anthropic` whatever the roster label (the engine fixes the vendor), and the model after normalising: `[1m]`
   stripped, an alias `a` equal to any `claude-a-*`. After the run `model_resolved` is compared again and the
   ledger's coordinator line updated. A Claude Code coordinator sets `CODEX_CONSULT_COORDINATOR=anthropic :: <its
   model id>`; the result is the R13 warning, never a refusal.

10. **Telemetry.** Vendor class: engine claude -> `anthropic` (as agy -> google, muse -> meta), whatever the label
    and the auth. Model: after stripping `[1m]`, sent only when it matches `^(opus|sonnet|haiku|fable)$|^claude-
    (opus|sonnet|haiku|fable)-[0-9]+(-[0-9]+)?(-[0-9]{8})?$`, else `other`. `claude` joins `$script:EngineNames`,
    so `ConvertTo-TelemetryDetails` stops mapping it to `other`. No `result`, denial, path or cost leaves.

11. **Tests.** `tests/fake-claude.cmd` + `fake-claude.ps1`, modelled on `fake-agy.ps1` (one-result stream,
    conversation modes, denial) and `fake-muse.ps1` (sign-in file, version log), driven by `FAKE_CLAUDE_*` (REPLY,
    PROSE, IS_ERROR, EXIT, SESSION modes, INIT_TOOLS, INIT_MODEL, APIKEYSOURCE, DENIALS, RATE_LIMIT, HANG, TOOL_OPEN,
    PARTIAL, WRITE, AUTH_STATUS, ARGV_LOG with argv, stdin length, working directory and env names).
    `tests/harness-claude.ps1`: the `harness-muse.ps1` sections (UNIT ROSTER DRYRUN ENGINEEXE RUN BILLING PREFLIGHT
    FAIL TREE RESUME+FORK REPAIR PANEL LISTING) plus TOOLSET, TIMEOUT, STALL, HYGIENE, GUARD. GUARD differs: on a
    Claude Code host a real `claude.exe` is always reachable, so the harness strips PATH directories holding one,
    uses a scratch USERPROFILE/HOME/LOCALAPPDATA, pins `CODEX_CONSULT_CLAUDE_EXE` to the fake and fails on a child
    without an argv log. Existing: `run-all.ps1` (18th), `harness-engines`, `harness-visibility` (rosters, salvage,
    launch block, availability), `harness-detach:102` (`$launcherNames`), `harness-panel` (a claude member),
    `harness-host`, `harness-roster` (`auth`), `harness-telemetry` (vendor, pattern, `[1m]`). Docs: README
    "Engines" and "Tested on", `setup-providers` step 3g and `Bash(claude auth status)` in its `allowed-tools`.

12. **Deliberately not done.** The Agent tool and subagents; MCP servers; web tools; Bash, any write tool and
    `workspace-write`; `--bare` and an API-key-only mode; other vendors' models (`ANTHROPIC_BASE_URL` routes),
    Bedrock, Vertex, Foundry; stream-json input; `--include-partial-messages` (unless Q6 needs it);
    `--max-budget-usd` (unknown on a subscription); `--fallback-model`; `--bg`, `--worktree`, `--agents`.

## Invariants

- A claude turn runs with exactly Read, Grep, Glob (and StructuredOutput), no MCP server, mode `dontAsk` -
  proven by its own init event, or it fails with class `permission`.
- A thread is one session id and one resolved model; a secondary turn that lands elsewhere fails.
- Subscription billing is checked on evidence (`apiKeySource: none`); the child never sees an `ANTHROPIC_*` key.
- The reviewer runs without the repository's CLAUDE.md and AGENTS.md, plugins, hooks, skills and MCP servers.
- No preflight spends a request; the prompt never travels in argv; no harness starts the real `claude`.
- Telemetry carries `claude`, `anthropic` and a pattern-checked model name, nothing else of the run.

## Open questions for the reviewers

Q1. ANSWERED (obs, 2026-09-30): `claude -p` without a prompt argument read a 52 KB, 401-line prompt from stdin
    whole (the reviewer counted the lines; `cache_creation_input_tokens` 18013). OPEN only for the upper bound:
    is there a size at which stdin is cut (a 200 KB brief)?
Q2. Under `dontAsk`, is a Read outside the working directories a `tool_result` error plus a `permission_denials`
    entry, or can it end the turn with an empty success (agy F11)? Does `--permission-prompts none` add anything?
Q3. `--effort` on a model without adaptive reasoning (Haiku): applied, clamped, ignored or an error?
Q4. Default mode `new`, or codex's automatic fork of the last matching lineage entry?
Q5. Does `--session-id` pin the new id of `--resume <p> --fork-session`; does a fork repeat or inherit the tools?
Q6. Is anything streamed during one long thinking block, or does the 900 s stall timer need partial messages?
Q7. Exit codes, `result.subtype` values and wordings for quota, overload and a failed structured output?
Q8. ANSWERED for the repository: `--restricted` keeps its CLAUDE.md and AGENTS.md out (obs). OPEN for the home
    directory: does `~/.claude/CLAUDE.md` still reach a restricted `-p` reviewer?
Q9. ANSWERED: `claude auth status` exists, is local and free, and prints `loggedIn`, `authMethod`, `apiProvider`.
Q10. The `rate_limit_event` payload, the stream when the subscription's limit is reached, and the exit code?
Q11. Does `--resume` continue a session killed by taskkill /T /F mid-turn (open `tool_use`, thinking); which id?
Q12. Are two claude children of one panel plus the coordinator safe together (the shared `~/.claude.json` and
    `~/.claude` state), or must a panel run its claude members one at a time?

## Verification

One live checkpoint consultation with a roster entry `anthropic :: claude-sonnet-<id> [claude]`. The ledger shows
`reviewer.engine` claude, `reviewer.harness` `claude-cli 2.1.285.0`, `provider_config.credential_mechanism`
subscription, `thread` = the minted uuid = `result.session_id` (`thread_source` events), `tree_check` clean, `usage`
with cached tokens, `effort_mapping` claude-v1, `schema_transport` native and no repair, `child_env_scrubbed`,
`engine_run` {turns 1, init tools [Glob, Grep, Read, StructuredOutput], mcp_servers 0, api_key_source none,
model_resolved, permission_denials 0, switched_off}, `bridge_outcome` usable. A `-Mode resume` consultation keeps
the id and `model_resolved`; `provider_config` carries `authMethod` `claude.ai`; the reviewer's transcript
contains no heading of `~/.claude/CLAUDE.md` or of the repository's CLAUDE.md.

## Requested checks

1. Home-directory instructions: a code word in `~/.claude/CLAUDE.md` (a reviewer's own install, restored after);
   does `claude -p --restricted` in another directory answer it or "none"?
2. The denied-tool stream: ask for a Read outside the working directories; keep the full stream, `subtype`,
   `permission_denials` and the exit code.
3. The resume of a killed session: kill `claude -p --session-id <u>` during a tool call and during thinking, then
   `claude -p --resume <u>`; the result's `session_id` and whether the transcript needed repair.
4. `claude auth status` beyond the signed-in subscription case: its JSON and exit code when signed out and with
   `ANTHROPIC_API_KEY` set (`authMethod`, `apiProvider` values), and its time on a cold start.
