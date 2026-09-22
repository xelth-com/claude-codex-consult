# claude-codex-consult

Claude Code coordinates; **Codex is a standing reasoning partner you can call mid-task**.
This plugin adds one skill and one small PowerShell bridge so Claude can hand Codex a
one-page brief and get a judgement back — over your existing ChatGPT subscription, with
no API key. The same `<task-id>` keeps the Codex thread alive across consultations
(`fork` to branch, `resume` to continue), Codex runs in a **read-only sandbox** by
default, and every consultation lands on disk as a file pair — your brief and Codex's
verbatim reply — plus a JSON ledger entry. Consultations become reviewable history you
can commit next to the code they were about, instead of chat you lose.

Any Codex model works. Leave the model unset and Codex uses whatever is in your
`~/.codex/config.toml`; pass `-Model <name>` when you want a specific one.

---

## Install

```
/plugin marketplace add OWNER/claude-codex-consult
/plugin install codex-consult@claude-codex-consult
```

Then just ask Claude to consult Codex, or invoke the skill directly:

```
/codex-consult:consult-codex my-task should we cache at the edge or in the worker?
```

### Requirements

| | |
|---|---|
| Claude Code | any recent version with plugin support |
| [Codex CLI](https://github.com/openai/codex) | **≥ 0.148** — `codex exec fork` landed there. Developed against 0.155.1 |
| Codex auth | signed in with your ChatGPT account (`codex login`). No API key needed |
| Shell | Windows PowerShell 5.1 (preinstalled on Windows) **or** PowerShell 7 (`pwsh`) on macOS/Linux/Windows |
| git | optional — used to locate the project root and stamp the reviewed revision |

---

## Usage

**1. Claude writes a brief** to `.collab/<task>/handoffs/<NN>-claude-<slug>.md`:
question, task state, evidence with `file:line`, the alternatives already weighed,
numbered questions Q1…Qn, and a word cap. One page.

**2. One command** (Claude runs this for you):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" `
    -Task my-task -Mode fork `
    -Brief .collab/my-task/handoffs/03-claude-invalidation.md `
    -Prompt "Judge the invalidation strategy." -ReplyName invalidation
```

On macOS/Linux, `pwsh -NoProfile -File …` with the same arguments.

**3. The reply** is written to `.collab/<task>/handoffs/<NN>-codex-<slug>.md` — a header
(date, model, effort, Codex version, mode, parent thread, result thread, argv, outcome,
wall time) then `---` then the reply **verbatim**, nothing paraphrased. The raw event
stream goes next to it as `<NN>-codex-<slug>.events.jsonl`.

### The ledger

`.collab/<task>/sessions.json` records every call, including the ones that failed —
so the file is a history, not a success log:

```json
{
  "task_id": "my-task",
  "cwd": "/home/you/project",
  "codex": {
    "tool": "codex-cli 0.155.1",
    "consults": [
      {
        "n": 3,
        "when": "2026-09-22T11:24:27+02:00",
        "parent_thread": "01a0c839-48ba-7182-8d15-fdc13dd17193",
        "thread": "01a0c86e-5193-7d70-a644-63a5c3f224b3",
        "thread_source": "events",
        "mode": "fork",
        "command": "codex exec --sandbox read-only --color never --json …",
        "brief": ".collab/my-task/handoffs/03-claude-invalidation.md",
        "prompt_chars": 212,
        "reply": "handoffs/04-codex-invalidation.md",
        "events": "handoffs/04-codex-invalidation.events.jsonl",
        "model": "config default",
        "effort": "high",
        "sandbox": "read-only",
        "reviewed_revision": "4e9cc4f + uncommitted",
        "outcome": "usable reply",
        "wall_seconds": 11.1
      }
    ]
  }
}
```

`thread_source` tells you where the thread id came from (`events`, the `rollout` file
fallback, or `unknown`), and `outcome` is either `usable reply` or `failed: …`.

### Options

| Option | Default | |
|---|---|---|
| `-Task <id>` | *required* | Groups one conversation under `<CollabDir>/<id>/` |
| `-Mode new\|resume\|fork` | `fork` if a thread is known, else `new` | `fork` branches, `resume` appends |
| `-Thread <uuid>` | newest thread in the ledger | Pick a specific parent |
| `-Brief <path>` / `-Prompt <text>` | — | At least one is required |
| `-Model <name>` | *none* → your `config.toml` | Only passes `-m` when given |
| `-Effort low\|medium\|high\|xhigh` | `high` | |
| `-Sandbox read-only\|workspace-write` | `read-only` | `danger-full-access` is refused |
| `-MaxWords <n>` | `700` | Asked of Codex in the prompt |
| `-TimeoutSec <n>` | `900` | The process is killed past this |
| `-CollabDir <path>` | `.collab` | Relative to the git repo root |
| `-ReplyName <slug>` | `reply` | Names the reply file |
| `-CodexExe <path>` | auto | Env override: `CODEX_CONSULT_EXE` |
| `-DryRun` | | Print argv, paths and the planned ledger entry; call nothing |

`-DryRun` is the first thing to reach for when a call misbehaves — it shows the exact
argv, the resolved launcher, the prompt that would go on stdin, and where every file
would land.

---

## How it works

Four things took real trial and error to get right. They are the substance of this
plugin; the rest is bookkeeping.

**1. Exec options must precede the subcommand.** `codex exec fork --help` has no
`--sandbox` or `--color`: those are options of `exec`, not of `fork`. The working form
is `codex exec --sandbox read-only --json -o <file> fork <thread> -`. Put `--sandbox`
after `fork` and Codex fails with *unexpected argument*.

**2. The prompt travels on stdin, never as an argument.** On Windows, `codex` is an npm
shim (`codex.cmd`), and `cmd.exe` still expands `%VAR%` inside double-quoted arguments.
A brief that mentions `%APPDATA%` would be silently rewritten. Passing the final `-`
and piping the prompt in avoids the shim's expansion entirely.

**3. The thread id comes from the first `--json` event.** Every run — `new`, `resume`
and `fork` alike — emits `{"type":"thread.started","thread_id":"…"}` as its first JSONL
line, and that id is the *resulting* thread, which is what you must record to continue
later. If the parse ever fails (version drift), the script falls back to the newest
`rollout-*-<uuid>.jsonl` under `$CODEX_HOME/sessions/<y>/<m>/<d>/` created after the run
started, and says so via `thread_source`.

**4. Two `Start-Process` traps on Windows PowerShell 5.1.** `-PassThru` returns an empty
`.ExitCode` unless you touch `.Handle` before the child exits, and the redirection
handles stay locked briefly after it exits, so reading the captured stdout right away
throws *the process cannot access the file*. The script caches the handle and reads with
`FileShare.ReadWrite` plus a short retry.

Everything else follows from those: failed runs are recorded as ledger entries too,
`danger-full-access` is refused with no flag to force it, and the reply file is written
even when the run failed (with the stderr tail as its body), so a failure is as
inspectable as a success.

---

## Why not X

Prior art exists. None of it was shaped like a *standing advisor thread with
fork + resume, a read-only sandbox, a committed file trail, and Windows support*, which
is why this plugin exists. All of these are worth a look if your shape is different.

| Project | Shape | Continuity | Why not here |
|---|---|---|---|
| [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) (official) | Claude Code plugin: `/codex:review`, `/codex:adversarial-review`, `/codex:rescue` + session hooks | resumes only its own latest thread; no chosen thread, no fork | Review/rescue shaped rather than an advisor you brief. Open Windows sandbox issue [#349](https://github.com/openai/codex-plugin-cc/issues/349) (sandbox modes fail, reviews come back empty) |
| [parisbs/codex-subagent-mcp](https://github.com/parisbs/codex-subagent-mcp) | MCP server: `codex_delegate`, `codex_follow_up`, background jobs | `resume` only, no `fork` | Closest fit, and the background-job model is genuinely nice. Delegation verified on macOS; no brief/reply file trail |
| [newtro/mcp-codex-bridge](https://github.com/newtro/mcp-codex-bridge) | MCP server: `codex_ask`, `codex_review`, `codex_implement` | none | No thread continuity at all — every call starts cold |
| [xihuai18/codex-mcp](https://github.com/xihuai18/codex-mcp) | MCP server: `codex_session` (with fork) + `codex_reply` | fork + reply | The only one with fork, but unmaintained for months while the Codex app-server protocol moved |
| [j-token/codex-mcp](https://github.com/j-token/codex-mcp) | MCP server over the Codex SDK | resume, no fork | Requires Bun; lightly maintained |
| [masuP9/agent-dialectics](https://github.com/masuP9/agent-dialectics) | Claude Code plugin: strong-inference / devil's-advocate skills | deliberately none — a fresh thread each time | A different and defensible philosophy; the opposite of a continuing thread |

Note: `codex mcp-server` was removed in Codex 0.154, and `codex app-server` is an
experimental JSON-RPC surface — which is part of why several MCP wrappers above drifted.
A thin wrapper around the documented `codex exec` CLI is the stable surface today.

---

## Tested on

| | |
|---|---|
| Windows 11 + Windows PowerShell 5.1 + Codex CLI 0.155.1 | dry-runs for `new` / `resume` / `fork`, every refusal path, brief resolution, and one live `new` consultation. The live call reached Codex and was rejected by the account's usage limit, which exercised the whole failure path: the thread id was still parsed from the live `thread.started` event, the error message was lifted from the event stream, the reply file and the ledger entry were written, and the script exited non-zero |
| PowerShell 7 (`pwsh`) | **not yet exercised** — `pwsh` was not installed on the development machine |
| macOS / Linux | **not yet exercised** — written for portability (no Windows-only APIs on the hot path, `Join-Path` everywhere, `$CODEX_HOME`/`$HOME` resolution, UTF-8 without BOM, platform-agnostic launcher lookup), but unverified |

Reports from a `pwsh` or macOS/Linux run are the single most useful contribution right now.

### Troubleshooting

A failing consultation is still a written record: read `.collab/<task>/handoffs/<NN>-codex-<slug>.md`
and the `outcome` field of the ledger entry. Codex reports quota, auth and turn failures
on the **JSON event stream**, not on stderr, so the script lifts the message from there —
e.g. `failed: codex exit 1 - You've hit your usage limit. … try again at 12:21 PM.`
For anything else, rerun with `-DryRun` and compare the argv.

---

## Roadmap / help wanted

- **A bash port**, so macOS/Linux users need no `pwsh` at all.
- **A `UserPromptSubmit` hook injector**: inject the last Codex reply into the next turn
  automatically, and/or detect an `@codex` trigger token in a prompt and launch a consult.
  Note the hook budget is ~30 s by default, so a synchronous 2-minute consult does not
  fit — it has to inject stored context or fire detached.
- **The reverse direction**: a Codex-side tool that consults Claude, for symmetric sessions.
- **An MCP server variant** with background jobs, so a long consult does not block the turn.
- **Tests on macOS and Linux**, and on PowerShell 7 generally.
- **`--output-schema` support**, for structured replies that can be parsed rather than read.

Issues and PRs welcome for any of these.

---

## Contributing

Keep the script dependency-free and dual-shell (5.1 and 7). If you change the `codex`
invocation, re-check the four gotchas above — they are load-bearing. Please include the
`-DryRun` output for any argv change, and say which shells and platforms you exercised.

## License

MIT — see [LICENSE](LICENSE). Author: xelth.com
