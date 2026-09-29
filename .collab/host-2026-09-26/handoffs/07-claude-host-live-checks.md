# R13 live coordinator checks (D9 of 05) - 2026-09-29, commit c6f6966

Each check: a scratch git repository, the three `AGENTS.md` lines of the README with `<plugin>` replaced, one
fresh headless session of the host as the coordinator, one checkpoint consultation on task `r13-host` from
the README, the `AGENTS.md` lines and the skills alone. The session markers of the supervising host were
removed from the environment of the session under test.

## Kimi Code 0.27.0 (`kimi -p`, `--skills-dir`, `CODEX_CONSULT_ROOT`)

Reviewer `mimo :: mimo-v2.6-pro`: usable reply in 143.2 s (verdict ADVISE, no finding). Brief
`01-kimi-trust-verify.md` (`-BriefPrefix kimi`). Ledger: `coordinator {provider: moonshot, model: kimi-code,
host: unknown, source: explicit}`, `child_env_scrubbed: []` (the host sets no marker). The coordinator
reconciled findings, ran the preflight and rated the consultation as the skill says. Its remarks: the example
of the skill shows `-Mode fork`, refused on the first consultation of a task; it replaced the value of
`CODEX_CONSULT_COORDINATOR` given by the operator (`kimi :: k3`) with a guess of its own name; the host is
recorded `unknown`. The first two were fixed in c6f6966 (skill text, the third `AGENTS.md` line).

## Codex CLI 0.155.1 (`codex exec --sandbox workspace-write`, network access enabled, the codex home added)

The operator installed the plugin with the two documented commands (marketplace clone at ab479c8). The session
saw a `codex-consult:` line at its start and the skills `codex-consult:consult-codex`, `:coordinate`,
`:setup-providers`. Reviewer `kimi :: k3` (mimo was a member of a running panel). Ledger:
`coordinator {provider: openai, model: gpt-6-astra, host: codex, source: explicit}` (the value of the operator
was kept), `child_env_scrubbed: [CODEX_CI, CODEX_SESSION_ID, CODEX_THREAD_ID]`. The consultation FAILED:

H1. The installed plugin directory holds no README although the skills refer to it.
H2. `pwsh` resolved to the WindowsApps alias, which the sandbox refused to execute; Windows PowerShell worked.
H3. Inside the sandbox the reviewer child had no network connection although network access was enabled for
    `workspace-write`: no reply, `failed: timeout after 900 s (process tree killed)`.
H4. The process tree was NOT killed: process inspection is denied inside the sandbox, the reviewer (`codex
    exec -m k3`) was still running 20 minutes later and the continuation turn failed with "the thread already
    has an active writer". The outcome text claimed a kill that had not happened. The supervisor stopped the
    orphan by hand.

Decisions: D16-D19 of `.collab/companions-2026-09-26/handoffs/33-claude-wave27c-decisions.md`.

Second run, outside the sandbox (`codex exec --dangerously-bypass-approvals-and-sandbox`, approved by the
operator for this check, a fresh scratch repository): reviewer `mimo :: mimo-v2.6-pro`, usable reply in
502.1 s, brief `01-coordinator-reviewer-trust.md` (`-BriefPrefix coordinator`), the same ledger values
(`host: codex`, `source: explicit`, the three CODEX names scrubbed), the consultation rated `partly` by the
coordinator: the reply was generic and the event stream of the reviewer showed two `wait` calls of the
multi-agent tool and no command that read the brief. Remarks of the coordinator: the placeholders and the
template naming of the skills are written for another host (D13, D22); the session has no recurring wake of
its own, it polled in bounded steps. Candidate for the roadmap: reviewer children run with the multi-agent
tools of the engine switched off (a reviewer has nobody to wait for).

## Z Code (desktop 3.14.3, CLI 0.16.9)

Install and update through its plugin manager verified (three skills, the SessionStart hook). The live
session inside the app was run by the operator in this repository (task `r13-host`, its files are under
`.collab/r13-host/`): coordinator `ZAI :: glm-5.3`, reviewer `byteplus :: deepseek-v4.1-flash`, usable reply
in 597.5 s (verdict ADVISE, one minor finding on the wording of the brief, closed by the coordinator), brief
`01-zcode-checkpoint.md` (`-BriefPrefix zcode`), the consultation rated, `state.md` written. Ledger:
`coordinator {provider: ZAI, model: glm-5.3, host: unknown, source: explicit}`, `child_env_scrubbed: []`.
Observations of that coordinator, checked against the source: the shell tool of Z Code carries neither
ZCODE_SESSION_ID nor ZCODE_PROJECT_DIR, so the host hint `zcode` was not given and nothing was scrubbed; no
`codex-consult:` session-start line reached the context of the session. Decisions: D20, D21 of the wave 27c
decisions.
