# Handoff 06 - Meta Muse (muse): muse-smoke

Date: 2026-09-26 09:47 local. Author: Meta Muse (muse) (model muse-spark-1.3-contributor, effort medium), muse-cli 1.4.0-R4161.1.
Reviewer: meta :: muse-spark-1.3-contributor [muse] (provider from -Provider, model from -Model; engine muse (C:\Users\Dmytro\AppData\Local\Programs\muse\muse.cmd); provider fingerprint 1c6f62bb040d; harness muse-cli 1.4.0-R4161.1).
Preflight: ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth).
Effort: medium sent (requested medium, mapping muse-v1, by caps-v1: engine:muse, muse-spark-1.3-contributor; not confirmed by the provider). Consultation id: aacaf328-a702-4945-aa07-32eaea54b1c8.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads), purpose: checkpoint). Argv: `muse exec --json --prompt-file C:\Users\Dmytro\AppData\Local\Temp\codex-consult-prompt-41deff272fa74754812c002b676f6f88.txt --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json --model muse-spark-1.3-contributor --reasoning-effort medium --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never` (prompt from a file: --prompt-file).
Parent thread: (none - new thread; no thread of lineage meta :: muse-spark-1.3-contributor [muse] in this task's ledger; other lineage(s): byteplus :: dola-seed-2.0-pro, byteplus :: deepseek-v4.1-flash, ZAI :: glm-5.3). Result thread: `01a0dcaf-128c-7690-8463-4fcd6a109382` (source: events).
Brief: (none, prompt only). Reviewed: f2c219a, base f2c219a901162917acc38a9eee712d81cb99fa36, tree sha256 c287328b76ba, 0 changed files.
Bridge outcome: usable reply. Wall time: 76.7 s. Tokens: not reported by muse.
Engine turns: 1 (each one a Muse Code subscription prompt); MSP schema_version 1.
Verdict: ADVISE - Bridge argv spellings match the verified facts; no flag drift found in this scope. Findings: none. Structured reply: `handoffs/06-muse-muse-smoke.reply.json`.
Raw event stream: `handoffs/06-muse-muse-smoke.events.jsonl`.
Verbatim reply follows.

---

## 1. Do the bridge flags match the verified CLI facts?

Yes. `New-MuseArgv` emits `exec --json --prompt-file --output-schema --model --reasoning-effort --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never [--max-model-steps] [--session-id]`, matching every verified spelling and order. Conditionals (`--output-schema`, `--reasoning-effort`, `--max-model-steps`, `--session-id`) are the expected transport/effort/resume options, not drift.

---

### Findings

_(none)_

### Prior findings

- F02-1 - not-checked - outside this checkpoint's two read scopes
- F02-2 - fixed - New-MuseArgv now takes Turn.PromptFile/Schema/Model/Effort/MaxSteps/Thread; argv contract extended
- F02-3 - not-checked - outside this checkpoint's two read scopes
- F02-4 - not-checked - outside this checkpoint's two read scopes
- F02-5 - not-checked - outside this checkpoint's two read scopes
- F02-6 - not-checked - outside this checkpoint's two read scopes
- F02-7 - not-checked - outside this checkpoint's two read scopes
- F02-8 - not-checked - outside this checkpoint's two read scopes
- F02-9 - not-checked - outside this checkpoint's two read scopes
- F02-10 - not-checked - outside this checkpoint's two read scopes
- F02-11 - not-checked - outside this checkpoint's two read scopes
- F02-12 - not-checked - outside this checkpoint's two read scopes
- F02-13 - not-checked - outside this checkpoint's two read scopes
- F02-14 - not-checked - quoting/percent-sign handling not examined read-only
- F02-15 - not-checked - outside this checkpoint's two read scopes
- F02-16 - not-checked - outside this checkpoint's two read scopes
- F02-17 - not-checked - outside this checkpoint's two read scopes
- F02-18 - not-checked - outside this checkpoint's two read scopes
- F02-19 - not-checked - outside this checkpoint's two read scopes
- F02-20 - not-checked - outside this checkpoint's two read scopes
- F02-21 - not-checked - outside this checkpoint's two read scopes
- F03-1 - not-checked - outside this checkpoint's two read scopes
- F03-2 - fixed - New-MuseArgv param is Turn with PromptFile; three prompt-file paths now reachable
- F03-3 - not-checked - outside this checkpoint's two read scopes
- F03-4 - not-checked - outside this checkpoint's two read scopes
- F03-5 - not-checked - outside this checkpoint's two read scopes
- F03-6 - not-checked - outside this checkpoint's two read scopes
- F03-7 - not-checked - outside this checkpoint's two read scopes
- F03-8 - not-checked - outside this checkpoint's two read scopes
- F03-9 - not-checked - outside this checkpoint's two read scopes
- F03-10 - not-checked - outside this checkpoint's two read scopes
- F03-11 - not-checked - outside this checkpoint's two read scopes
- F03-12 - not-checked - outside this checkpoint's two read scopes
- F03-13 - not-checked - outside this checkpoint's two read scopes

## Verdict: ADVISE

Bridge argv spellings match the verified facts; no flag drift found in this scope.

### Blockers

- **F02-1** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:2562`, `plugins/codex-consult/scripts/codex-consult.ps1:2628`, `plugins/codex-consult/scripts/codex-consult.ps1:2818`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3206`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3300` - The generic non-codex denial-retry and format-repair paths hardcode the agy event parser and outcome, so a newly added muse adapter would work only on the first turn and misparse every retry or repair turn. Verify: Run a fake-muse prose reply with -FormatRetry 1 and inspect whether the second MSP stream is parsed and committed as a muse reply. Remedy: Route every turn through engineSpec.Adapter.Events/Outcome, or explicitly disable denial and format retries for muse and test that policy.
- **F02-4** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4074`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4116`, `plugins/codex-consult/scripts/codex-consult.ps1:2383`, `plugins/codex-consult/scripts/codex-consult.ps1:293` - The billing guard has no defined integration point; if it is treated as an ordinary preflight check, -SkipPreflight can bypass it, roster walking may not skip subscription muse entries, and panel children may repeat the decision inconsistently. Verify: Set each key and run muse with -SkipPreflight, as a roster walk, and as a panel member; every subscription attempt must refuse before launch and fallback behavior must be explicit. Remedy: Make billing an independent fail-closed launch invariant evaluated for the selected entry and again immediately before Start-Process; expose it in provider listings and never allow -SkipPreflight to override it.
- **F03-1** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:3032`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3047`, `.collab/muse-engine-2026-09-26/handoffs/01-claude-muse-engine-design.md` - Item 1 cannot find the launcher on the machine the design was verified on: muse.cmd lives in %LOCALAPPDATA%\Programs\muse, that directory is absent from the bridge process's Path and from both the User and the Machine Path, and `Get-Command muse` returns nothing. Resolve-EngineLauncher only consults -EngineExe, the ExeEnv variable and PATH lookup, so the preflight reports 'muse CLI not found on PATH' and item 11's install story never says the override is mandatory. Verify: Run RC1 in a fresh bridge shell and confirm that no muse launcher resolves and that the install directory is not on the PATH the bridge sees. Remedy: Make the override explicit in item 1/5/11 (add the directory to PATH and restart the bridge, or set CODEX_CONSULT_MUSE_EXE), and optionally probe %LOCALAPPDATA%\Programs\muse as a last resort. Requires finding #4 so -EngineExe can name Muse.

### Unproven scenarios

_(none)_

### First-run checklist (observable)

_(none)_
