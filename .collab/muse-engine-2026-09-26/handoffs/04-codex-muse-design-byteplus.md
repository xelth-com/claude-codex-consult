# Handoff 04 - Codex: muse-design-byteplus

Date: 2026-09-26 02:45 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-muse-design.json - position 3 of 3, panel 0168bb07 member 3 of 3.
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: 89f74a9a-f6d7-48c3-93b2-ec0523bf3a64.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8dd5f6e7233c405880f580c026086b15.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a0db2c-70c9-75d1-bd91-0a97d36fa4ba` (source: events).
Brief: `.collab/muse-engine-2026-09-26/handoffs/01-claude-muse-engine-design.md` (sha256 b545ca3849fa). Reviewed: 37b98b4, base 37b98b4f7a006902a08e4be6fa228388db367c19, tree sha256 d00fa16a06d4, 0 changed files.
Bridge outcome: usable reply. Wall time: 351.3 s. Tokens: in 1074054 (cached 648040), out 9578, reasoning 3598.
Verdict: ADVISE - Design follows the agy precedent closely, with several unimplemented components and tradeoffs to resolve. Findings: 0 blocker, 5 major, 1 minor, 1 note (F04-1..F04-7, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/04-codex-muse-design-byteplus.reply.json`.
Raw event stream: `handoffs/04-codex-muse-design-byteplus.events.jsonl`.
Verbatim reply follows.

---

## Q1. Read-only enforcement
The `--disable-shell` + `--disable-write` + tree check pattern is identical to what is used for the agy engine today. This is considered acceptable for read-only reviewers in the current codebase, but has known limitations:
- It only detects writes to tracked/untracked files and the collab directory
- It cannot prevent or detect reads (including files outside the repo, gitignored paths, or submodules)
- The brief confirms muse still uses its native `read_file` tool even with these flags

A separate scratch workspace would eliminate write risk entirely, but would be a departure from the established pattern and require additional implementation. This choice is consistent with existing engine safety.

## Q2. Billing guard behavior
Refusing the run is the safer default:
- Failing closed avoids silent unexpected behavior if the user explicitly set those variables intending API key billing
- Stripping would require knowing all possible environment variables that could trigger per-token billing, which is fragile
- The current codebase does not strip environment variables for any engine today; all engine processes inherit the full parent environment

If stripping is desired, it should be implemented as an explicit engine-specific configuration, not a default.

## Q3. Preflight credential check
Reading only the auth.json key names is acceptable as a low-cost preflight, but has tradeoffs:
- It does not verify credentials are actually valid (expired, revoked, or corrupted credentials will still pass preflight and waste quota)
- The agy engine uses a live `agy models` call for preflight, which is cached for 60 minutes
- Given the very low quota (10-50 prompts per 5 hours), wasting one prompt on a preflight check may not be worth it

Recommendation: use the auth.json check with a warning that it does not verify validity, and fall back to live checking only after a failure.

## Q4. MSP record handling and CLI updates
Several points of fragility:
1. **Schema version**: The design mentions `schema_version` in MSP records, but does not specify checking it. The parser should fail hard on unsupported schema versions.
2. **Record structure**: If Meta changes the location of `run.terminal.completed`, the `stream.id` thread ID, or other record fields, the parser will break.
3. **Auto-updates**: The launcher updates automatically with no version pinning or checking.

Mitigations:
- Check the CLI version with `muse --version` before running, and fail or warn on untested versions
- Make the parser lenient to extra fields, but strict on required fields
- Include schema version checks in the event parser

## Requested checks
RC1. Run `muse exec --help` to confirm all proposed arguments are supported, working directory: repository root, permission: read-only, observation: verifies the exact argv flags exist.
RC2. Test if `muse exec` can read files outside the repository, working directory: repository root, permission: read-only, observation: confirms the read scope of the native read_file tool.
RC3. Check if `META_API_KEY` actually overrides the CLI's logged-in state, working directory: repository root, permission: read-only, observation: verifies the billing guard's premise is correct.

---

### Findings

- **F04-1** [major] (no location) - No existing environment variable guard logic for non-codex engines. All engine processes inherit the full parent environment. Trigger: Any API_KEY environment variable set in the bridge process will be passed to the muse child process, potentially triggering per-token billing. Evidence: read-code: Start-Process is called without modifying EnvironmentVariables; no filtering or checking of environment variables exists for non-codex engines. Verify: Run codex-consult -Engine agy with an API_KEY variable set and inspect the agy process environment. Remedy: Add engine-specific environment variable filtering logic that checks for and either refuses or strips configured variables before launching the child process.
- **F04-2** [note] (no location) - The tree check only monitors writes, not reads. It cannot prevent or detect file reads by the engine. Trigger: Muse can read any file accessible to the user (including outside the repository, gitignored files, etc.) even with --disable-write and --disable-shell, and this will not be detected. Evidence: read-code: The tree check compares before/after working tree fingerprints, but has no visibility into read operations. This is identical to the agy engine's behavior. Verify: Run a muse prompt asking to read a file outside the repository; it will succeed and the tree check will not flag it. Remedy: This is the established safety model for all external engines. To restrict reads, a scratch workspace with restricted filesystem access would be required.
- **F04-3** [major] (no location) - No MSP record parser exists for muse. The existing Read-AgyEvents parser is specific to agy's stream-json format. Trigger: Any muse run will fail to extract the reply, thread ID, or failure information. Evidence: read-code: Only Read-AgyEvents and Get-AgyTurnOutcome exist for non-codex engine event parsing. Verify: Attempt to run muse through the bridge; it will attempt to use the agy parser which will not recognize MSP records. Remedy: Implement Read-MuseEvents and Get-MuseTurnOutcome adapter functions following the MSP format specification, equivalent to the agy implementations.
- **F04-4** [major] (no location) - No preflight credential check logic exists for muse. Trigger: The preflight step for muse will not verify if the user is signed in. Evidence: read-code: Only Get-AgyModelsStatus exists for non-codex engine credential checks. Verify: Run codex-consult -Engine muse; the preflight will have no way to check sign-in status. Remedy: Implement Get-MuseModelsStatus that checks ~/.config/muse/auth.json exists and has the providers.meta entry.
- **F04-5** [minor] (no location) - No CLI version checking or pinning exists for auto-updating engines. Trigger: An automatic update to the muse CLI could break argument parsing, event format, or behavior with no warning. Evidence: read-code: No --version check exists for agy or any other external engine. Verify: Run agy --version; the bridge does not verify or pin the version before launching. Remedy: Add version checking for muse that runs --version before each launch, and fail or warn on untested versions.
- **F04-6** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1` - The engine table does not contain an entry for muse. Trigger: Any attempt to use -Engine muse will fail with 'unknown engine'. Evidence: read-code: $script:Engines only contains entries for 'codex' and 'agy'. Verify: Run codex-consult -Engine muse; it will error immediately. Remedy: Add a muse entry to $script:Engines following the agy pattern, with the appropriate adapter function names.
- **F04-7** [major] (no location) - No thread resume logic exists for muse. Trigger: Attempting to resume a muse thread will not pass the --session-id argument correctly. Evidence: read-code: Only New-AgyArgv implements thread resume logic for external engines. Verify: Run codex-consult -Engine muse -Mode resume -Thread <id>; the argument will not be included in the muse argv. Remedy: Implement New-MuseArgv that handles new/resume modes and passes --session-id when resuming, and refuses fork mode.

### Prior findings

_(none)_

## Verdict: ADVISE

Design follows the agy precedent closely, with several unimplemented components and tradeoffs to resolve.

### Blockers

_(none)_

### Unproven scenarios

- Whether META_API_KEY actually overrides the logged-in subscription state
- Whether --max-model-steps is actually supported by the muse CLI
- Whether the tree check correctly detects changes made by muse's native write tools
- Exact behavior of muse's exit codes under failure conditions

### First-run checklist (observable)

_(none)_
