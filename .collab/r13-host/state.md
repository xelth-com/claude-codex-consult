# r13-host - live host-invariance check from Z Code

Opened 2026-09-29. One checkpoint consultation, coordinator `ZAI :: glm-5.3` (explicit),
reviewer `byteplus :: deepseek-v4.1-flash` (roster entry 6), brief
`handoffs/01-zcode-checkpoint.md`, reply `handoffs/02-codex-reply-byteplus.md`.
Outcome: usable reply, verdict ADVISE, F02-1 (minor, brief wording) recorded wontfix,
consultation 1 rated useful.

Observations for the maintainer (both confirmed against the plugin source, not just inferred):

- `coordinator.host` resolved `unknown`, not `zcode`: `Get-CoordinatorHost`
  (codex-consult-common.ps1:5547) probes `ZCODE_SESSION_ID` / `ZCODE_PROJECT_DIR`, and this
  ZCode build sets neither in a Bash-tool shell (it sets thirteen other `ZCODE_*` vars:
  APP_VERSION, ENV, PROCESS_LABEL, ...). The wave 27b acceptance claim "a Z Code coordinator
  resolves to zcode" holds only for launch paths that carry those two names.
- `child_env_scrubbed` is `[]`: correct-as-written for the same reason — the scrub list
  (`HostMarkerNames` + prefixes `CODEX_SANDBOX*`, `ZCODE_PLUGIN*`, common.ps1:5479-5487)
  matched nothing present. A wider `ZCODE_*` prefix is NOT wanted wholesale (APP_VERSION etc.
  are harmless), but `ZCODE_PLUGIN*`-style plugin leakage via other names would go unscrubbed
  only if a future ZCode build renames them; re-check per build.
- No `codex-consult:` SessionStart line reached this session's context (outages / detached-run
  notices are invisible on this host as wired today).
