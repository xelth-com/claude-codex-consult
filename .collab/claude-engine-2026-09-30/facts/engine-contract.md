# Engine contract of the codex-consult bridge (as of HEAD 0555eca)

Paths: C = `plugins/codex-consult/scripts/codex-consult-common.ps1`, M = `.../codex-consult.ps1`, P = `.../codex-providers.ps1`. Facts only; `file:line` are approximate to the function.
Key point: C:3092-3130 (header) and C:3175-3230 already say "a further engine (e.g. `claude`) is one more row plus its adapter functions". codex is NOT an adapter engine: it is the inline `$isCodex` path in M.

## 1. Where code branches on the engine name

| Place | Function / line | What differs |
|---|---|---|
| Engine table | `$script:EngineNames`, `$script:Engines` C:3175-3230 | one row per engine; codex row has `Adapter = $null` |
| Roster validation | roster parser C:6008-6020 | `engine` must be in `EngineNames`; non-codex needs `model`; `codex_config` and `auth` refused; one label = one engine |
| Selection / refusals | M:3251-3345 (engineName from -Engine, roster entry, thread's reviewer), M:3400-3440 | non-codex: no `fork`, only `-Sandbox read-only`, no `-CodexConfig`, `-SchemaTransport` limited to `spec.Transports`, `-MaxModelSteps` only if `StepsFlag` |
| Launcher | `Resolve-EngineLauncher` C:3243, `Resolve-EngineExeBinding` C:3277, `Get-EngineLauncher` C:3303 | codex: `-CodexExe`/`CODEX_CONSULT_EXE`; others: `-EngineExe` (bound to ONE selected engine), `spec.ExeEnv`, `LauncherNames`, `InstallLaunchers` |
| Harness string | `Get-EngineHarness` C:3315 | `<engine>-cli <ProductVersion>` from file metadata, or `Adapter.Harness` (muse) |
| Identity | `Resolve-EngineIdentity` C:2541 | HostName `engine:<n>`, CompatString `cc-engine-v1\|<n>`, fingerprint = SHA-256 of it, `provider_config {engine, launcher, + Adapter.IdentityConfig}`; provider = free label (`DefaultProvider`), model REQUIRED |
| Caps / effort / transport | `$script:EffortCaps` C:2727 (`engine:agy`, `engine:muse`), `$script:EffortVocabularies` C:2685, `Resolve-EffortPlan` C:2735+ | agy: vocabulary `model-tier` (nothing sent); muse: `muse-v1`, only for declared models (`$script:MuseDeclaredModels` C:2708); schema transport `native` |
| Preflight | `Get-EngineCredential` C:3383, `Get-PreflightVerdict` C:6110, P:348-364 (engine rows) | `Adapter.Credential`; ledger short-circuit; `LocalSignIn` under -NoNetwork |
| Launch invariant | `Get-EngineLaunchBlock` C:3424 | only muse has one (billing) |
| Prompt | M:3919-3924 | non-codex appends `spec.ToolsLine`; codex gets none |
| Argv / stdin | M:4016-4060 | codex inline argv (M:4030-4051); others `Adapter.Argv`, `Adapter.Stdin`; `%` hazard `Get-CmdArgvHazard` C:3436 |
| Process start | `Start-EngineProcess` M:1695, `Invoke-EngineTurn` M:1757 | all turns of all engines; launch block re-read fresh; `%` hazard only non-codex; host markers hidden (`Hide-HostMarkers` C:5562) |
| Wait / stall / tool flight | `Wait-EngineProcess` C:8555, `Update-ToolFlight` C:8485 | per-engine event shapes for "tool in flight" |
| Event parse + outcome | M:4560-4640 (codex: `Get-ThreadIdFromEvents` M:1521, `Get-UsageFromEvents` M:1594, `Get-ErrorFromEvents` M:1565, `-o` last-message file); non-codex `Adapter.Events` + `Adapter.Outcome` | see 3 |
| Tree check | `Get-EngineTreeCheck` M:1871 | non-codex only; codex only warns (M:5478 header line, `treeChanged`) |
| Denial retry | M:4670 (`spec.DenialRetry`) | agy only |
| Timeout continuation | M:4736-4900 | all engines; argv built inline for codex (M:4809), `Adapter.Argv` otherwise (M:4827) |
| Format repair | M:4985-5135 | codex: `exec resume <thread> -` with `--sandbox read-only`, prompt-only, effort via `Get-RepairEffort` C:1729; others: `Adapter.Argv`, main turn's transport |
| Salvage | `Read-TurnSalvage` C:4340, `Read-CodexSalvage` C:4201, `Read-AgySalvage` C:4257, `Read-MuseSalvage` C:4304 | `.partial.md` after a kill |
| Failure of killed turn | `Get-KilledTurnFailure` C:4410, `Test-InformationalStderr` C:4384 | quota/auth forbids a continuation; known info lines are never evidence |
| Ledger / header | M:5197 (`engine_run`), M:5487-5503, M:4098-4171 (dry-run shape of the entry) | see 7 |
| Thread lineage | `Select-ParentThread` C:7422, `Test-SameReviewer` C:7367, `Get-EntryEngine` C:2528 | reviewer identity includes engine |
| Labs | `$script:LabVendors` C:5340 (prefix of MODEL id; no `claude=` entry today) | roster `lab` overrides |
| Reply file prefix | `$replyPrefixes` M:2093, `spec.Prefix` | handoff names `NN-<prefix>-<slug>.*` |
| Host markers | `$script:HostMarkerNames` C:5522 | already scrubs `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT/SESSION_ID/EXECPATH/MESSAGING_*/...`, `CLAUDE_PID`, `CLAUDE_EFFORT`, `AI_AGENT` from every child; keeps `CLAUDE_PLUGIN_ROOT`, `CLAUDE_CODE_USE_*` |
| Detached / scoreboard / findings / hook | no engine branch found (only `Get-EngineSpec` in P:349) | none |

## 2. The three engines

### codex (M inline; no Adapter)
- Cmd (M:4030-4051): `codex exec --sandbox <read-only|workspace-write> --color never --json [-m <model>] -c model_reasoning_effort="<e>" [-c model_provider="<p>"] [-c <codex_config>...] -o <last-msg file> [--output-schema <schema>] [fork <thread> | resume <thread>] -`. Exec-level options MUST precede `fork|resume`.
- Prompt: STDIN (`-`), never argv (cmd.exe `%VAR%` expansion through the npm shim, F02-14). Reply: the `-o` file, copied byte for byte to `.reply.json` (M:4581).
- Model/effort: `-m` and `-c model_reasoning_effort` always; provider via `-c model_provider`; transport `output-schema` or `prompt-only` per host (caps-v1).
- Read-only: `--sandbox read-only` (codex's OS sandbox). `workspace-write` is allowed; then a tree change is only a header WARNING (M:5478), never a failure.
- Threads: `Mode` new / resume / fork (default automatic: fork of the last matching lineage entry); thread id from the `thread.started` event, fallback = rollout scan `Find-ThreadInRollouts` M:1624, verified by the consultation id (last prompt line). Session files: `<CODEX_HOME>/sessions/YYYY/MM/DD/rollout-*-<uuid>.jsonl`.
- Context guard: roster `context_tokens` -> mode fallback to new (M:3995-4013).

### agy (Google Antigravity CLI; Gemini)
- Cmd (`New-AgyArgv` C:3484): `agy -p= --input-format stream-json --output-format stream-json --model <full id incl. tier> [--json-schema <S>] --print-timeout 0 --sandbox --disable-slash-commands [--conversation <thread>] [--effort <v>]`.
- Prompt: STDIN, ONE NDJSON line `{"event":"user","message":{"content":<prompt>}}` + LF (`ConvertTo-AgyStdin` C:3498).
- Model: the tier is in the model id; effort is sent ONLY with `-NativeEffort` (`--effort`); vocabulary `model-tier`.
- Read-only: NOT enforced (`--sandbox` restricts the terminal only, F12); the bridge tree check FAILS the run (`WriteDisabled=$false`). Print mode auto-denies a tool it cannot grant and ends the turn with an empty SUCCESS (F11) -> `DenialRetry`. The prompt's ToolsLine forbids `run_command`.
- Threads: `new` (default) or `resume` via `--conversation <id>`; NO fork. Thread = `result.conversation_id` (must equal the init id, be a uuid, and equal the parent on resume; a `warning: conversation ... not found` starts a NEW conversation that is only a candidate). Session store: agy's own (never read by the bridge).
- Harness: no `--version` (the CLI rejects unknown flags) -> file metadata.

### muse (Meta Muse Code CLI)
- Cmd (`New-MuseArgv` C:3887): `muse exec --json --prompt-file <P> [--output-schema <S>] --model <m> [--reasoning-effort <e>] --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never [--max-model-steps <n>] [--session-id <thread>]`.
- Prompt: FILE (`--prompt-file`, the turn's own prompt file, written per turn by `Invoke-EngineTurn`); stdin EMPTY (`ConvertTo-MuseStdin` returns '').
- Effort: mapped (`low/medium/high/xhigh` as is) only for declared models, else `-NativeEffort`. The repair turn sends `low`.
- Read-only: enforced by the bridge's own flags (`WriteDisabled=$true`): a tree change is a WARNING (`tree_check.outcome warned`), the reply stays usable. Reads (`read_file`), gitignored paths, submodules and outside-repo files stay unmonitored.
- Threads: `new` or `resume` via `--session-id`; no fork. Thread = the ONE stream id of kind `session`. Sign-in file `~/.config/muse/auth.json` (`TBH_CREDENTIAL_BACKEND=file` required).
- Billing invariant `Get-MuseLaunchBlock` C:3832: `META_API_KEY`/`MODEL_API_KEY` set, or no ESTABLISHED oauth sign-in -> the launch is refused (never bypassed by -SkipPreflight; re-read before every turn).

## 3. Event stream, reply, repair
- codex (`--json` items): `thread.started` (thread), `item.started/completed` (types `agent_message`, `reasoning`, `command_execution`, `mcp_tool_call`, `web_search`), `turn.completed.usage` (input/cached/output/reasoning). Reply = `-o` file. Structured via `--output-schema` or prompt-only; local validation always.
- agy (`Read-AgyEvents` C:3524): `init{conversation_id}`, `step_update{step_type agent_response|tool, state ACTIVE|..., tool_name, text_delta}`, exactly ONE `result{conversation_id,status,response,structured_output,usage,denied_actions,error}`. Reply = `structured_output` serialized (else `response`). Usage map: `cache_read_tokens`, `thinking_tokens`. A partial last line is tolerated only after a kill or non-zero exit (`-AllowPartialLast`).
- muse (`Read-MuseEvents` C:3934): MSP JSONL `{schema_version (1 only), stream{kind,id}, record_type, payload_type, payload}`; `session.run.linked`, `run.model.configured{model_id}`, `run.output.delta{text}`, `task.lifecycle.proposed/completed/...{task_kind tool.*}`, ONE `run_terminal` (`run.terminal.completed{text}`). Reply = terminal text. NO usage (`HasUsage=$false`). Model drift check: `ExpectModel` must equal `run.model.configured`. Provenance bound to one session and one run (F09-3).
- Adapter turn record (C:3618, C:4084): `Ok, Outcome ('usable reply'|'failed: ...'), Class, Texts, Thread, ThreadCandidate, Reply, Structured, DeniedEmpty, DenialLine, Permission, NotFound, Warnings`; called with `-Events -ExitCode -StderrText -Pre -ExpectThread -ExpectModel`. Event parser returns at least `Thread, Usage, Error, ToolName, DeniedAction, Malformed, HasResult/HasTerminal`.
- Format repair (M:4985): one turn on the SAME thread, only after a usable prose reply and never after quota/auth/billing failure; codex always prompt-only; engines reuse the main turn's transport (F09-2: a native schema flag on a prompt-only run was a bug). The repair must come back on the same thread.
- Denial retry (agy only, M:4670): on `DeniedEmpty` + verified thread + no tree problem, one turn on the same conversation, timeout min(T,300).
- Failure `Class` values: '' (classify the texts), quota, auth, capability, transport, unknown, permission (the tree check forces `permission`, M:4640).

## 4. Safety checks around a run
- Working tree, collab directory, brief, artifacts: `Get-EngineTreeCheck` M:1871 (`Compare-TreeContent` C:725 by CONTENT; `Get-CollabSnapshot` C:761 over the whole collab dir, the run's own `NN-<prefix>-<slug>.*` and `.consult.*` excepted). agy -> `failed` (class permission, reply kept, not ingested); muse -> `warned`. codex: no such check (fingerprints only, warning M:5478). Blind spots: gitignored paths, submodules, files outside the repo, reads.
- Tree kill: `Stop-ProcessTreeChecked` C:8652 (taskkill /T /F on Windows, pgrep -P elsewhere; `Confirmed`, `Survivors`, `Why`); "(process tree killed)" only when confirmed (`Format-KillText` M:1737); ledger `kill_confirmed`; survivors or an unconfirmed kill block the continuation.
- Stall: `Wait-EngineProcess` C:8555 (`-StallSec`, default 900, roster `stall_sec`, 0 = off): the silent timer resets on any byte growth of the events file and is SUSPENDED while `Update-ToolFlight` (C:8485) reports an open tool call (codex `command_execution|mcp_tool_call|web_search` started..completed; agy `step_update` with `step_type tool` state ACTIVE until another state; muse `task.lifecycle.proposed` with `task_kind tool.*` until completed/failed/cancelled/rejected); suspension cap max(3 x stall, 1800 s). Also the `-Kick` file and the hard timeout. Poll 1 s.
- Timeout continuation (M:4736): ONE more turn on the known thread within `-ContinueSec` (default min(timeout, 900)), all engines; skipped when the thread is unknown, survivors, kill unconfirmed, files changed (tree check), or the killed turn shows quota/auth (`Get-KilledTurnFailure`); the result must pass `Test-ContinuationReply`.
- Run lock + recovery record `.consult.pending.json` around EVERY turn (`Invoke-EngineTurn`); launch guard right before each `Start-Process`.

## 5. Preflight / sign-in
- codex/openai: `Get-CodexLoginStatus` (`codex login status`); custom providers: `env_key`/bearer (`Get-ProviderCredential` C:3089).
- agy: `Get-AgyModelsStatus` C:3334: `agy models`, 45 s (hook `CODEX_CONSULT_TEST_LOGIN_TIMEOUT`); exit 0 + `<id>\t<name>` lines = ok; text mentioning login/auth = missing; anything else or timeout = unknown. Needs the network -> "not checked" under `-NoNetwork` (SessionStart hook).
- muse: `Get-MuseSignIn` C:3806 reads `auth.json` key names only (`LocalSignIn=$true`, runs under -NoNetwork); missing/unknown ALSO refuse the launch.
- Common (`Get-EngineCredential` C:3383): missing launcher = missing; a usable reply in THIS repo's ledger within 60 min = `ok: signed in (usable reply N min ago)`; then `Get-PreflightVerdict` adds endpoint health (auth failure 24 h, quota reset, burst 10 min). Health is keyed by the engine fingerprint: all labels of one engine share it.

## 6. Roster keys (parser C:5930-5960; allowed set at C:5930)
`provider` (free label for engines), `model` (REQUIRED for engines), `engine` (in `EngineNames`), `codex_config` and `auth` (REFUSED for engines), `panel` always|weighty, `lab` (string), `roles`, `timeout_sec` 60-86400, `stall_sec` 0-86400, `context_tokens` 32000-100000000 (mode-fallback guard), `ext` (object). Top level: `roster_version`, `reviewers`, `parallel`, `require`, `ext`; anything else makes the roster unusable (fail-closed). `-Engine` is validated at M:2211.

## 7. Engine-specific ledger fields
`reviewer.engine`, `reviewer.harness`, `reviewer.provider_config{engine, launcher, [credential_mechanism]}`, `sandbox` (= `spec.SandboxRecord`), `thread_source` (`events|unknown`; codex adds rollout), `thread_candidate`, `tree_check {outcome, files[]}` (null for codex), `engine_run {turns, max_model_steps, msp_schema_version}` (null for codex), `denial_retry`, `format_retry.schema_transport`, `timeout_continue`, `stall`, `kill_confirmed`, `usage` (muse: none), `child_env_scrubbed`, `effort_mapping` (`model-tier` | `native` | vocabulary), `provider_failure.class`, `command` starts with `spec.Command`. Handoff header (M:5487-5503) uses `Label`, `PromptVia`, `HasUsage`.

## 8. Harness requirements
- A fake CLI `tests/fake-<engine>.cmd` + `.ps1` (patterns: `fake-agy.ps1` 181 lines, `fake-muse.ps1` 268 lines) driven by `FAKE_<ENGINE>_*` env vars: reply file, resume reply, status/error/stderr, exit, session/conversation modes (notfound, other, mismatch, notuuid), hang + pidfile, partial/garbage lines, write probe (`FAKE_*_WRITE`), models/login (`FAKE_AGY_MODELS`), version log. Launcher via `CODEX_CONSULT_<ENGINE>_EXE` (`spec.ExeEnv`).
- A new `tests/harness-<engine>.ps1` (patterns: `harness-engines.ps1` 755 lines, sections DRYRUN RUN DENIAL ROSTER PROSE LISTING TREE SIGNIN RESUME PANEL FAIL SCOREBOARD RECOVER TIMEOUT GUARD UNIT; `harness-muse.ps1` 834 lines: UNIT RUN BILLING DRYRUN TREE FAIL REPAIR RESUME PANEL LISTING ENGINEEXE ROSTER PREFLIGHT GUARD), registered in the list at `tests/run-all.ps1:20` (17 harnesses today).
- Other harnesses that enumerate engines: `harness-visibility.ps1` (rosters L242-252, `Read-TurnSalvage` L319-322, launch block L354, `Invoke-EngineTurn` from AST L488-509, availability L574, hook L664), `harness-detach.ps1:102` (`$launcherNames` list of codex/agy/muse launcher names), `harness-panel.ps1` (mixed panel L215, AGY case L482), `harness-host.ps1` (marker scrubbing), `harness-roster.ps1` (engine key validation), `harness-fixes27c.ps1`, `harness-telemetry.ps1` (C:9062 tags the engine).
- Harnesses must never resolve the real CLI (harness-muse refuses to run when a real launcher is reachable; scratch USERPROFILE/HOME/LOCALAPPDATA; `CODEX_CONSULT_TEST_MODE=1`, `CODEX_CONSULT_HEALTH=none`, telemetry off).
- Docs to update: README "Engines" sections (agy L2292, muse L2437), "Tested on" L2918, `skills/setup-providers/SKILL.md` (agy 3b, muse 3f; the `allowed-tools` line 5 lists `Bash(agy models)`, `Bash(muse --version)`), plugin/marketplace descriptions.

## 9. Questions a design for the `claude` engine must answer
1. Prompt transport: stdin (`claude -p` reads stdin; stream-json input?), file, or argv; where `%`/quoting hazards apply for a `.cmd` shim vs a native `.exe`.
2. Read-only: which flags make writes, shell and web impossible (`--allowedTools`/`--disallowedTools`/`--permission-mode`)? `WriteDisabled=$true` (warn) or false (fail)? What stays unmonitored (Read outside the repo, MCP tools)?
3. Denial behavior: does `claude -p` auto-deny a tool and end empty like agy F11 (needs `DenialRetry`), or report denials in the result (MSP-like evidence)?
4. Event stream: `--output-format stream-json --verbose` shape; which record is the final result (session id, `is_error`), which are tool start/end for `Update-ToolFlight` and `Read-*Salvage`, which carries usage (`HasUsage`).
5. Schema: native `--json-schema` or prompt-only; effect on repair and the prose gate; the `engine:claude` caps-v1 row (`SchemaTransport`).
6. Model and effort: alias vs full id, effort vocabulary (declared models vs `-NativeEffort` only); `LabVendors` needs a `claude=anthropic` prefix or the lab is unknown.
7. Threads: new / `--resume` / fork; does `-p` mint a new id on resume; not-found and mismatch rules; where session files live and whether persistence can be off; fork supported or refused like agy/muse?
8. Sign-in check without spending a prompt (no `models` command): `claude auth status`, a credentials file, or env tokens; `LocalSignIn` true or false; mapping to available / not checked / out; is there a billing invariant like muse's (API key vs subscription) needing a `LaunchBlock`?
9. Recursion: a `claude -p` child of a Claude Code coordinator. Host markers are already scrubbed (C:5522), but the child also loads user settings, plugins, hooks (this plugin's SessionStart hook), CLAUDE.md and MCP servers; which flags keep it a clean reviewer; which auth variables must still reach it (`CLAUDE_CODE_USE_*`, plugin dirs are kept; `CLAUDE_CODE_EXECPATH` is scrubbed).
10. ToolsLine wording (Read/Grep/Glob allowed; no Bash/Edit/Write) and the child's own system-prompt overhead (agy costs 13-25k tokens per call).
11. Turn cap: `--max-turns` as `StepsFlag` (today `-MaxModelSteps` is muse-only and refused elsewhere, M:3419) and its failure wording (class capability).
12. Failure classification: exit codes, `is_error`, stderr wording for quota/auth/overload, informational lines (`Test-InformationalStderr` C:4384), `retry_after`.
13. Timeout/stall: does the stream emit anything during long thinking; are tool calls start/end pairs; behavior on kill (partial line); the salvage reader for `.partial.md`.
14. Harness/version: `claude --version` (local, free) as `Adapter.Harness`; `InstallLaunchers` (npm shim vs native install dirs); `LauncherNames`.
15. Coordinator equals reviewer: `Get-CoordinatorMatch` (M:3455) warns when the reviewer is the coordinator's own model; a Claude coordinator consulting the `claude` engine on the same model is the common case.
16. Pain points of the first two engines to design against: F11 (empty SUCCESS on denied tool), F12 (sandbox does not block writes), F09-1 (billing guard must be fail-closed), F09-2 (secondary turns keep the main transport), F09-3 (evidence provenance), F10-2 (partial last line), F13 (sign-in check timing 1.7-15+ s), Windows keychain unreadable, `.cmd` `%` expansion, one events file read by three consumers (stall watcher, salvage, adapter parser).
