Write in English.

# Handoff 01 - Z Code (zai :: glm-5.3): r13 host-invariance checkpoint

Date: 2026-09-29. Base commit: `ab479c8` + uncommitted (collab artifacts of wave 27b only, no source changes).

## Question

Live host-invariance check for ROADMAP R13 / wave 27b: the bridge (plugin 0.5.0) is being driven
for the first time in this task from the Z Code host, coordinator `ZAI :: glm-5.3`, reviewer
`byteplus :: deepseek-v4.1-flash` (roster position 6). The concrete ask is Q1 below.

## Delta since the last review

First review of this task. Context: wave 27b (commit `c6f6966`) made the bridge host-neutral —
`Hide-HostMarkers` around engine child starts, ledger `child_env_scrubbed`,
`-BriefPrefix` / `CODEX_CONSULT_BRIEF_PREFIX`, host hint order codex/zcode/claude-code/unknown.
This consultation exercises that work from a real Z Code session rather than a harness.

## CURRENT invariants claimed

- A consultation launched from Z Code behaves as from any host: same brief rules, same ledger
  entry, same reply files under `.collab/r13-host/`.
- The engine child environment is scrubbed of host markers before the reviewer runs; the ledger
  records which names were scrubbed (`child_env_scrubbed`), names only, never values.
- The coordinator identity (`CODEX_CONSULT_COORDINATOR`) is parsed, recorded in the ledger with
  the inferred host, and warned about (never refused) when it collides with the seated reviewer.

## Changed files

Base commit `ab479c8`, fingerprint `not computed` (no source files changed by this task; only
this brief and the bridge's own outputs under `.collab/r13-host/` are new).

| File | Change |
|---|---|
| `.collab/r13-host/handoffs/01-zcode-checkpoint.md` | this brief (only hand-written file of the task) |

## Open findings

From `codex-findings.ps1 -Task r13-host -List`: _(none open — first consultation of the task)._

## Evidence

- `codex-providers.ps1 -Provider byteplus` (run 2026-09-29 16:20, this repo): `available`,
  credentials `ok: env BYTEPLUS_API_KEY set`, endpoint `ark`, roster positions 6,7.
- Roster `~/.codex/codex-consult-roster.json`: entry 6 is `byteplus :: deepseek-v4.1-flash`
  (non-weighty, `model_supports_reasoning_summaries=true`).

## Questions

- **Q1.** In three sentences: what must a coordinator verify before trusting a reviewer reply?

Answer by number. Keep it under 500 words.
