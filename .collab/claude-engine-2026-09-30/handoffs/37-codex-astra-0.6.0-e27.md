# Handoff 37 - Codex: astra-0.6.0-e27

Date: 2026-10-08 00:46 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 1 of 12 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: 7675f76d-9cb2-4efb-9ef4-39818a869934.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-43da454d2c674462b8d4384f01c52f42.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a117e5-a98b-79f0-8687-247a6f7beec6 -` (prompt on stdin).
Parent thread: `01a117e5-a98b-79f0-8687-247a6f7beec6`. Result thread: `01a1188c-1205-7041-acca-b9cfc8a89a80` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/36-claude-0.6.0-e27.md` (sha256 5e232b2c9839). Reviewed: 8083ae0, base 8083ae02170f4f543b25e4b6606099aa892dd843, tree sha256 2bf39b51a50d, 0 changed files.
Bridge outcome: usable reply. Wall time: 281.6 s. Tokens: in 14520549 (cached 11831168), out 79496, reasoning 20345.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `ab51d1f..b4b4e67` - the range changes 17 files, 1177 lines (1142 insertions, 35 deletions).
Verdict: HOLD - E27 can misparse an escaped configuration value as a server subcommand and release recovery protection while a reviewer remains alive. Findings: 1 blocker, 0 major, 0 minor, 0 note (F37-1, tracked in `findings.json`). Structured reply: `handoffs/37-codex-astra-0.6.0-e27.reply.json`.
Raw event stream: `handoffs/37-codex-astra-0.6.0-e27.events.jsonl`.
Verbatim reply follows.

---

1. **E27 can hide a real reviewer — finding #1 blocks acceptance.** The tokenizer toggles quoting at every double quote, including Windows backslash-escaped quotes. A reviewer launched with a quoted global `-c` value containing `app-server` can therefore be excluded even though its actual subcommand is `exec`. In a read-only mocked process scan, this propagated through `Test-PendingActive`: an unknown-tree panel record returned `Active=false` and reported the reviewer as an excluded app server. The same fixture returned `Active=true` for ordinary `exec` and an unreadable command line. Thus those fail-closed cases hold, but readable command lines are not necessarily parsed safely. Exact recorded PID/start-time protection remains intact; the demonstrated failure concerns an orphan beneath a dead, unrecorded intermediate process.

2. **Fix the parser and add the missing regression before tagging.** Both changed PowerShell files parsed without errors, and the non-`.collab` diff passed whitespace checks. Direct checks accepted both Haiku 5.5 model spellings and classified their telemetry as `anthropic / claude-haiku-5-5`. These checks establish local consistency, not live model availability or context entitlement.

   The reported previous full-suite run plus focused reruns are a reasonable scope for this delta; another complete suite is not required solely because of E27. However, the existing tests do not cover escaped quotes inside global option values. After fixing that case, rerun the affected recovery harnesses with the desktop app open. I did not execute writing harnesses during this read-only review.

3. **HOLD**, with finding #1 as the blocker. Acceptance requires preserving recovery protection for the escaped-argument reviewer while retaining the intended desktop-server exclusions. First-run observations are listed in `first_run_checklist`.

## Requested checks

- **RC1:** Working directory: repository root. Permission: workspace-write. Extend the E27 fixture with a Windows reviewer command whose global configuration argument is `developer_instructions="please app-server check"`, encoded with backslash-escaped embedded quotes, followed by `exec --json -`; place it beneath a dead, unrecorded intermediate process and exercise unknown-tree recovery. Require refusal and retention of the pending record while it lives, then release after exit; retain desktop-server and unreadable-command controls. Budget: one fixture, 10 minutes. Settles finding #1.
- **RC2:** Working directory: repository root. Permission: workspace-write. After RC1 passes, run `harness-fixes.ps1`, `harness-pending.ps1`, `harness-fixes28e.ps1`, `harness-fixes27c.ps1`, and `harness-3b.ps1` sequentially from `tests/` with the desktop app open. Require zero failures and explicit server exclusions without reviewer exclusions. Budget: one pass, 30 minutes.

---

### Findings

- **F37-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:9794`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9825`, `tests/harness-fixes.ps1:401` - The server-exclusion tokenizer does not handle Windows backslash-escaped quotes, so text inside a global configuration value can become the apparent subcommand. This can exclude a real exec reviewer and cause unknown-tree recovery to release its pending record. Trigger: A surviving reviewer has the Windows command line `codex.exe -c "developer_instructions=\"please app-server check\"" exec --json -`, and its parent is a dead, unrecorded intermediate process, leaving the machine-wide scan responsible for detecting it. Evidence: read-code: Split-CommandLineTokens toggles quote state on every double quote without considering preceding backslashes. Get-CodexServerExclusion treats the first resulting non-option token as sufficient evidence for exclusion.; ran-command: The configuration value split into separate tokens including app-server; Get-CodexMatch returned an empty Rule and Excluded='codex app-server'.; ran-command: For an unknown-tree panel record and the surviving orphan, Active was false and Check reported release with that PID excluded as an app server. Ordinary exec and unreadable-command controls returned Active=true; the desktop app-server control returned Active=false.; read-code: The E27 cases cover simple global configuration values and quoted executable paths, but omit embedded escaped quotes in global option values. Verify: Run RC1 after adding the escaped-configuration regression; require the live orphan to keep recovery active and prevent another launch. Remedy: Use Windows-compatible argument parsing for Windows process command lines, and retain reviewer protection whenever parsing or option interpretation is ambiguous. Add the escaped-value case at both matcher and unknown-tree recovery levels.

### Prior findings

_(none)_

## Verdict: HOLD

E27 can misparse an escaped configuration value as a server subcommand and release recovery protection while a reviewer remains alive.

### Blockers

- **F37-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:9794`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9825`, `tests/harness-fixes.ps1:401` - The server-exclusion tokenizer does not handle Windows backslash-escaped quotes, so text inside a global configuration value can become the apparent subcommand. This can exclude a real exec reviewer and cause unknown-tree recovery to release its pending record. Verify: Run RC1 after adding the escaped-configuration regression; require the live orphan to keep recovery active and prevent another launch. Remedy: Use Windows-compatible argument parsing for Windows process command lines, and retain reviewer protection whenever parsing or option interpretation is ambiguous. Add the escaped-value case at both matcher and unknown-tree recovery levels.

### Unproven scenarios

- The writing harnesses and real-process regression were not executed during this read-only review; reported reruns come from handoff 36.
- The escaped-argument failure was reproduced through mocked process enumeration, not a newly launched native reviewer.
- Live Haiku 5.5 availability, account eligibility, and support for the [1m] context request were not established.
- Arbitrary launcher shims, older CLI option layouts, and non-Windows command-line representations were not exhaustively tested.

### First-run checklist (observable)

- [ ] With only desktop servers remaining, recovery output names their PIDs and exclusion reasons, then reports the interrupted reservation recovered.
- [ ] A live exec reviewer, including the escaped-global-configuration case, causes refusal and leaves the pending record present; its PID must not appear as an excluded server.
- [ ] An unreadable codex.exe command line causes refusal and retains recovery protection.
- [ ] After the reviewer exits, recovery proceeds while desktop servers remain alive.
- [ ] For a Haiku 5.5 consultation, the recorded served model matches the requested pin, the result is nonempty and usable, and telemetry records anthropic / claude-haiku-5-5.
