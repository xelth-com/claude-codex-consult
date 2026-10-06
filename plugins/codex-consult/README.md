# codex-consult

A dependency-free PowerShell bridge for the agent that coordinates the work - the coordinator - to
consult reviewers (the Codex CLI, and per roster entry Google's Antigravity CLI `agy` or Meta's Muse
Code CLI `muse`) and to record every consultation as files: the brief, the verbatim reply, a JSON
ledger and the findings tracked by id. Needs Windows PowerShell 5.1 or PowerShell 7, git and a
signed-in Codex CLI (or a `[model_providers]` table whose key the operator sets).

The full reference - install per host, setup, every option, the ledger, the engines, telemetry,
troubleshooting - is the repository README:
<https://github.com/xelth-com/claude-codex-consult/blob/main/README.md>.

## The three skills

| Skill | What it is for |
|---|---|
| `consult-codex` | the consultation: when to consult, the brief, the one command, reading and recording the reply and its findings, rating it |
| `coordinate` | the coordinator's rules: workers and waves, waiting without blocking (`-Detach`, `-Status`, `-Wait`, `-Kick`), compaction, the worker tiers, the means per host |
| `setup-providers` | wiring reviewers on a machine: step 0 checks the machine and asks the operator which subscriptions they hold, then the Codex login, provider tables, the roster, the `agy` and `muse` engines, verification (wave 29: and the `claude` engine, Claude Code headless) |

The plugin ships no subscription: on a fresh machine the operator pastes the first-run prompt from
the repository README (section "First run: the prompt for the operator") into their host, and the
agent runs `setup-providers` from step 0.

Why `coordinate` keeps a recurring wake while it waits, and when it compacts instead (the prompt
cache, its prices, the boundary, a worked example): the repository README, section "Waiting: keep
the prompt cache or compact".

`${CLAUDE_PLUGIN_ROOT}` in the skills is this directory; from a plain shell set `CODEX_CONSULT_ROOT`
to it and use that instead.

## A host without skills

The bridge prints each skill itself, with this directory filled in for the variable:

```powershell
# Windows (Windows PowerShell is always present)
powershell -NoProfile -ExecutionPolicy Bypass -File "<this directory>/scripts/codex-consult.ps1" -Explain coordinate
powershell -NoProfile -ExecutionPolicy Bypass -File "<this directory>/scripts/codex-consult.ps1" -Explain consult
powershell -NoProfile -ExecutionPolicy Bypass -File "<this directory>/scripts/codex-consult.ps1" -Explain providers
# macOS, Linux, or a real PowerShell 7 install
pwsh -NoProfile -File "<this directory>/scripts/codex-consult.ps1" -Explain coordinate
```

The SessionStart hook (`scripts/codex-consult-hook.ps1`) prints which reviewers are out and the full
`-Explain coordinate` command for this installation.

## Telemetry

On by default: after every consultation ONE anonymised event goes to the maintainer's intake;
`CODEX_CONSULT_TELEMETRY=off` switches it off. What is sent and what never is: the repository README,
section "Telemetry (on by default)".
