# Handoff 02 - Codex: reply-byteplus

Date: 2026-09-29 16:23 local. Author: Codex (model deepseek-v4.1-flash, effort medium), Codex CLI 0.155.1.
Reviewer: byteplus :: deepseek-v4.1-flash (provider from -Provider, model from -Model; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - entry 6 of 10 for -Provider byteplus (codex_config applied).
Effort: medium sent (requested medium, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, deepseek-v4.1-flash; not confirmed by the provider). Consultation id: 11ed9d0b-0acb-4d54-87ab-a59a7014892d.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m deepseek-v4.1-flash -c model_reasoning_effort="medium" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-e4403cc18c0944a2a60e5a48d4d074ff.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a0ed8c-a072-7ae3-bea0-e91b02e6c69c` (source: events).
Brief: `.collab/r13-host/handoffs/01-zcode-checkpoint.md` (sha256 3f819b4736fa). Reviewed: ab479c8, base ab479c81942ebd88c28c8206b3e64ec579f81f1b, tree sha256 d4485dee9d29, 0 changed files.
Bridge outcome: usable reply. Wall time: 597.5 s. Tokens: in 1914526 (cached 1773952), out 22496, reasoning 16592.
Timeout: 900 s (the default of purpose checkpoint); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Every invariant the brief claims still holds in the code at HEAD ab479c8; the only drift found is a minor misstatement of the uncommitted baseline, and the run's own outputs are not written yet. Findings: 0 blocker, 0 major, 1 minor, 0 note (F02-1, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/02-codex-reply-byteplus.reply.json`.
Raw event stream: `handoffs/02-codex-reply-byteplus.events.jsonl`.
Verbatim reply follows.

---

**Q1 - what a coordinator must verify before trusting a reviewer reply**

Verify provenance first: the reply belongs to the run the coordinator started - consultation id and thread match, the seated identity is the reviewer `-Require`/the roster resolved (no silently substituted model), the exit code is 0 with a complete reply plus its `.reply.json` (not a `.partial.md` after a timeout kill, not a stale file from an earlier wave), and no launch refusal or salvage path fired. Verify blindness second: the brief carried only the question and evidence (no hint of the coordinator's own conclusion), the reviewer's child environment was scrubbed of the coordinator's host markers (the ledger's `child_env_scrubbed`, names only), `CODEX_CONSULT_COORDINATOR` did not reach that child, and no "second opinion from the coordinator's own model" warning appeared. Verify the content third: it parses against the reply schema, answers every numbered question by number inside the word limit, and each assertion survives the coordinator's own reading of the code - anything the reviewer marked `assumed`/`unproven` stays unchecked, and the verdict text alone is never trusted.

**Invariants checked against the code now**

- Host hint order codex/zcode/claude-code/unknown - holds (`Get-CoordinatorHost`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5547`). Z Code's own bundle (`C:\Program Files\ZCode\resources\glm\zcode.cjs`) assigns `ZCODE_SESSION_ID`/`ZCODE_PROJECT_DIR` for session-context children and never `CODEX_SESSION_ID`/`CLAUDECODE`/`AI_AGENT`/`CLAUDE_CODE_ENTRYPOINT`, so a Z Code coordinator does resolve to `zcode`.
- Scrubbed child, names-only ledger - holds: `Start-EngineProcess` wraps the one guarded start in `Hide-HostMarkers` with `finally Restore-HostMarkers` (`codex-consult.ps1:1600-1614`), and `child_env_scrubbed` is `Get-HostMarkerNames` (names, never values) in every ledger write (`1041`, `2399`, `3934`, `5405`).
- Coordinator identity parsed, recorded with the inferred host, warned never refused - holds: `Resolve-CoordinatorIdentity` (`codex-consult-common.ps1:5564`); a collision only appends `Format-CoordinatorWarning` (`codex-consult.ps1:3282`, `2576`); only an unparseable value refuses.
- `-BriefPrefix` / `CODEX_CONSULT_BRIEF_PREFIX`, default `claude`, reply-prefix refusal - holds (`codex-consult.ps1:1954-1969`); this brief's `zcode` prefix is legal (reply prefixes are codex/agy/muse only).

**Drift**

The baseline claim does not describe the tree: `git status` shows uncommitted changes outside `.collab/r13-host/` (see finding #1). No source file is modified, so the code invariants above are unaffected.

**Requested checks**

- RC1. After this run finishes, read `.collab/r13-host/sessions.json` and the consultation's ledger entry (repo root, read-only, ~1 min): the observation that settles it is `coordinator.host == "zcode"`, `coordinator.source == "explicit"` and a non-empty `child_env_scrubbed` naming `ZCODE_SESSION_ID`/`ZCODE_PROJECT_DIR`/`CLAUDE_CODE_SESSION_ID`. If `host` reads `unknown`, finding #1's neighbour risk is real.
- RC2. In the Z Code session's own shell (not this engine child) run `Get-ChildItem env: | Where-Object Name -match '^(ZCODE|CODEX|CLAUDE)'` (read-only, seconds): confirm `ZCODE_SESSION_ID`/`ZCODE_PROJECT_DIR`/`ZCODE_PLUGIN_ROOT` are present and `CODEX_SESSION_ID`/`CLAUDECODE` are absent - that is what makes the hint `zcode` and gives the scrub something to remove.
- RC3. Run `git status --porcelain` and `git diff --stat` in the repo root (read-only, seconds) and compare against the brief's "Changed files" table - settles finding #1.


---

### Findings

- **F02-1** [minor] `.collab/r13-host/handoffs/01-zcode-checkpoint.md:5`, `.collab/companions-2026-09-26/findings.json`, `.collab/companions-2026-09-26/sessions.json` - The brief says the base is `ab479c8` + uncommitted "collab artifacts of wave 27b only" and that "only this brief and the bridge's own outputs under `.collab/r13-host/` are new"; the tree actually carries uncommitted work of a different task - modified `.collab/companions-2026-09-26/findings.json` and `sessions.json` (2190 insertions across the two) plus nine untracked files under `.collab/companions-2026-09-26/handoffs/`. The "Changed files" table lists only the brief. Trigger: Anyone using the brief to decide exactly what is new under review, or running `git status` in the repo root. Evidence: ran-command: ` M .collab/companions-2026-09-26/findings.json`, ` M .collab/companions-2026-09-26/sessions.json`, nine `??` files under `.collab/companions-2026-09-26/handoffs/`, and `?? .collab/r13-host/`; no source file appears as modified. HEAD is ab479c8.; read-code: The brief claims the uncommitted set is wave 27b artifacts only and that the brief is the only hand-written new file. Verify: Run `git status --porcelain` and `git diff --stat` in the repo root and compare the output with the brief's "Changed files" table. Remedy: Commit or stash the companions-task artifacts before the checkpoint run, or rewrite the baseline line and the "Changed files" table to name every uncommitted path.

### Prior findings

_(none)_

## Verdict: ADVISE

Every invariant the brief claims still holds in the code at HEAD ab479c8; the only drift found is a minor misstatement of the uncommitted baseline, and the run's own outputs are not written yet.

### Blockers

_(none)_

### Unproven scenarios

- Invariant 1's "same ledger entry, same reply files" is not yet observable for this run: `.collab/r13-host/` holds only `.consult.lock`, `.consult.pending.json` (state: running) and this consultation's `.events.jsonl` - the reply `.md`/`.reply.json` and any `r13-host` ledger entry are still to be written.
- The coordinator's own environment was not read (it is the parent of this engine child, and its markers are scrubbed from this process), so `coordinator.host == "zcode"` is inferred from Z Code's bundle, not observed in the ledger.
- The brief's Evidence bullet (`codex-providers.ps1 -Provider byteplus`: available, `ok: env BYTEPLUS_API_KEY set`, endpoint `ark`) was not re-run - it needs credentials and, for endpoint health, network access that is restricted here.

### First-run checklist (observable)

_(none)_
