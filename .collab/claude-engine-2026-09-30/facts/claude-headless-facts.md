# Claude Code headless as a reviewer engine - facts observed on 2026-09-30 (Claude Code 2.1.285, Windows)

Probe: a scratch directory, a tiny prompt, the smallest model, read-only tools, a JSON schema.

## What works

```
claude -p "<prompt>" --restricted --strict-mcp-config --disable-slash-commands \
  --model <alias or id> --effort <level> \
  --tools "Glob,Read,Grep" --permission-mode dontAsk \
  --output-format stream-json --verbose --json-schema '<schema>' \
  --no-session-persistence            (or: --session-id <uuid> / --resume <id> [--fork-session])
```

- exit 0; the subscription login is used (`apiKeySource: none` in the init event) - no API key needed.
- The init event lists exactly what the session has: `tools: [Glob, Grep, Read, StructuredOutput]`,
  `mcp_servers: []`, `skills: []`, `slash_commands: []`, `permissionMode: dontAsk`, the resolved model id,
  the cwd, `plugins:` only the two built-in ones (`cc-plugin-agents-md`, `cc-plugin-telemetry`), `agents:`
  the built-in agent types (the Agent tool is not among the tools, so none can be started).
- Events of the stream (one JSON object per line): `system` (`init`, `thinking_tokens`), `assistant` (content
  blocks `thinking`, `text`, `tool_use`), `user` (content block `tool_result`), `rate_limit_event`, and the last
  line `result` with `subtype: success`, `is_error`, `num_turns`, `duration_ms`, `session_id`,
  `total_cost_usd`, `usage`, `modelUsage`, `permission_denials`, `stop_reason`, `result` (text) and
  `structured_output` (the object that satisfies the schema).
- `--restricted` (its help text): removes the built-in tools that run commands or code (Bash, PowerShell, REPL
  and the other code-running tools) and WebFetch unless `--tools` names them; ignores user, project and local
  settings files (managed settings and `--settings` still apply); confines the file tools to the working
  directories (`--add-dir` included).

## What does not work

- `--bare` with the subscription login: `result: "Not logged in · Please run /login"`, exit 1. Its help text
  says why: in the minimal mode the authentication is strictly `ANTHROPIC_API_KEY` or an `apiKeyHelper`; the
  login of the subscription is not read. So `--bare` is for API-key users only.

## Not known yet (questions for the design review)

- Does a restricted session still load `CLAUDE.md` / `AGENTS.md` of the repository and of the home directory
  (the built-in plugin `cc-plugin-agents-md` is listed)? A reviewer must not receive the coordinator's
  instructions.
- What a denied tool call looks like in the stream (`permission_denials` of the result; the agy engine once
  returned an empty success after a denial).
- Whether `--resume <id> --fork-session` keeps the restricted tool set, and where the session files live
  (the lineage of a reviewer).
- What the stream looks like when the subscription's limit is reached (`rate_limit_event`), and the exit code.
- Whether `--max-budget-usd` applies to a subscription login.
- How a timeout kill leaves the session (can the continuation turn resume it).

## Answered on 2026-09-30 (probes with a CLAUDE.md and an AGENTS.md in the working directory that name a code word)

- `--restricted` does NOT load the repository's `CLAUDE.md` / `AGENTS.md` (the reviewer answered "none");
  without `--restricted` the same run answered the code word and named the file. So the restricted mode alone
  keeps the coordinator's instructions out of a reviewer; `--safe-mode` (which disables every customisation)
  gave the same result and is not needed.
- `claude auth status` exists (`claude auth [login|logout|status]`) and prints JSON without spending tokens:
  `loggedIn`, `authMethod` (`claude.ai` for the subscription), `apiProvider`, `projectsDirectory` - the
  preflight of the engine.
- `claude -p` with no prompt argument reads the WHOLE stdin as the prompt: a 52 KB prompt of 401 lines was
  counted correctly by the reviewer (18013 tokens written to the cache). The upper bound was not probed.

## Probes after the design review (2026-09-30) - see handoff 05, P1-P7

- A denied Read (outside the working directories) gives an error `tool_result`, a `permission_denials` entry in
  the result and a normal success; `--max-turns` is accepted; the home `CLAUDE.md` is not loaded under
  `--restricted`; `modelUsage` has one key; `claude auth status` exits 0 when signed in; a session killed in
  the middle of a turn resumes with `--resume <id>` under the same session id; two runs at once both succeed.
