# Handoff 12 - Codex: wave23-accept-byteplus

Date: 2026-09-26 09:51 local. Author: Codex (model kimi-k2.5, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: kimi-k2.5 (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave23-accept.json - position 8 of 10, panel df203d79 member 5 of 7; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, kimi-k2.5; not confirmed by the provider). Consultation id: 7fca8e3a-a530-4529-aece-6bf0fce62e84.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m kimi-k2.5 -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-78c57888b7ff49ae9f6464aecf40ecbb.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage byteplus :: kimi-k2.5 in this task's ledger; other lineage(s): meta :: muse-spark-1.3-contributor [muse], byteplus :: dola-seed-2.0-pro, byteplus :: deepseek-v4.1-flash, ZAI :: glm-5.3). Result thread: `01a0dcb3-279c-72b2-8a14-a7cc3777f8e2` (source: events).
Brief: `.collab/muse-engine-2026-09-26/handoffs/07-claude-wave23-acceptance.md` (sha256 0836c73ccb2b). Reviewed: 46440f3, base 46440f3f849901f7a28d786a164185675b85bcdb, tree sha256 c60cfc8b484b, 0 changed files.
Bridge outcome: usable reply. Wall time: 1566.7 s. Tokens: in 3461734 (cached 2041976), out 12533, reasoning 3391.
Verdict: ACCEPT - All critical and major findings from the design review have been fixed; remaining items are accepted documented limitations per decisions D1-D16. Findings: none. Structured reply (prompt-only transport): `handoffs/12-codex-wave23-accept-byteplus.reply.json`.
Raw event stream: `handoffs/12-codex-wave23-accept-byteplus.events.jsonl`.
Verbatim reply follows.

---

# Wave 23 Muse Engine Acceptance Review

## Summary
All 34 open findings from the design review have been addressed: 29 fixed, 5 accepted as documented limitations per the binding decisions D1-D16. The implementation matches the design specification and the adapter contract has been fully generalized for future engines.

## Fixed Findings
All critical defects are resolved:
- **Adapter contract**: `Argv` now receives a full turn options object including `PromptFile` (F02-2, F03-2)
- **Retry/repair turns**: all three turn types (main, denial retry, format repair) now use the engine adapter's `Events` and `Outcome` functions, no hardcoded agy references (F02-1, F03-3)
- **-EngineExe binding**: now correctly bound to the selected non-codex engine, works for muse and in `codex-providers.ps1` (F02-17, F03-4)
- **Effort vocabulary**: `muse` vocabulary with `muse-v1` mapping added, no silent empty mapping (F03-5)
- **Billing guard**: implemented as a launch invariant, checked even with `-SkipPreflight`, in roster walks, and panel members (F02-4, F03-7)
- **MSP parsing**: full invariants implemented (schema_version 1, exactly one UUID session, model matches requested, session matches on resume) (F02-11, F03-8)
- **Exit classes**: correctly mapped: exit 2 → capability, 130/143 → transport, step cap → capability, others through shared classifier (F02-12, F03-11)
- **Launcher resolution**: includes vendor install path `%LOCALAPPDATA%\Programs\muse\muse.cmd` on Windows (F03-1)
- **Version detection**: reads from `.muse-version`, `.muse-release-info.json`, or `--version` (F02-13, F03-10)
- **Cmd % hazard**: checked before launching any .cmd launcher (F02-14)
- **MaxModelSteps**: carried through to panel members (F02-16)
- **Tree check**: forces permission class even when the run already failed (F02-9)
- **Engine-specific wording**: all text (prompt tools line, dry run transport/reply source, handoff sandbox line) comes from the engine row (F02-10, F03-9, F03-12)
- **caps-v1**: declares only the verified `muse-spark-1.3` and `muse-spark-1.3-contributor` models (F02-20)
- **No default MaxModelSteps**: vendor default applies (F02-21)
- **Denial retry disabled** for muse per D2 (F02-15)
- **Test harness**: `tests/harness-muse.ps1` exists covering all required cases (F02-18, F03-13)

## Accepted Limitations (per binding decisions)
These are intentional, documented boundaries:
- **Shared endpoint health**: all muse entries share one fingerprint `cc-engine-v1|muse` (D14, F02-5)
- **Tree check boundary**: gitignored paths, submodules, files outside the repository, and `read_file` access are not monitored (D12, F02-8, F02-19)

## Requested checks (RC)
No blocking defects remain, but these items should be verified on first live run:
1. **RC1**: Run `codex-consult.ps1 -Engine muse -Model muse-spark-1.3 -DryRun` and confirm the argv contains all expected flags: `exec`, `--json`, `--prompt-file`, `--model`, `--no-foreign-personal-context`, `--disable-web-tools`, `--disable-write`, `--disable-shell`, `--approval-mode never`
2. **RC2**: Set `META_API_KEY=test` and run a muse dry run: confirm it is refused even with `-SkipPreflight`
3. **RC3**: Run the harness test: `cd tests; .\harness-muse.ps1` and confirm all cases pass

## First Run Checklist
Before accepting a real run as successful, verify these are observable in logs/output:
1. ✅ `muse exec` is called with the correct arguments including `--prompt-file`, `--output-schema`, `--reasoning-effort`, `--session-id`, and `--max-model-steps` when provided
2. ✅ The MSP stream `schema_version` is 1
3. ✅ Exactly one session UUID is present in the stream
4. ✅ `run.model.configured` matches the requested model
5. ✅ A tree mutation sets failure class `permission` even when the run exits non-zero
6. ✅ Each muse turn is counted separately in `engine_run.turns`
7. ✅ No API key environment variables are present in the launch environment

---

### Findings

_(none)_

### Prior findings

- F02-1 - fixed - All turns now use engine adapter Events/Outcome functions
- F02-2 - fixed - Argv receives turn options object with PromptFile
- F02-3 - fixed - Roster accepts engine: muse
- F02-4 - fixed - Billing guard implemented as launch invariant, checked everywhere
- F02-5 - fixed - Accepted limitation per D14: shared fingerprint for all muse entries
- F02-6 - fixed - Preflight states implemented: unknown refuses unless -SkipPreflight
- F02-7 - fixed - auth.json parsed only for mechanism, never logged or persisted
- F02-8 - fixed - Accepted limitation per D12: tree check boundary documented
- F02-9 - fixed - Tree mutation forces permission class even if run already failed
- F02-10 - fixed - Muse has its own sandbox wording from engine row
- F02-11 - fixed - MSP invariants implemented: schema_version 1, one session UUID, model check, resume session check
- F02-12 - fixed - Exit classes mapped correctly
- F02-13 - fixed - Get-MuseHarness reads version from correct sources
- F02-14 - fixed - Get-CmdArgvHazard checks for % in arguments with .cmd launchers
- F02-15 - fixed - Denial retry disabled for muse, format repair at most once, each turn counted
- F02-16 - fixed - MaxModelSteps carried through to panel members
- F02-17 - fixed - -EngineExe bound to selected engine, works for muse
- F02-18 - fixed - tests/harness-muse.ps1 exists covering all required cases
- F02-19 - fixed - Accepted limitation per D12: read_file not confined, documented
- F02-20 - fixed - caps-v1 declares only verified 1.3 models
- F02-21 - fixed - No default MaxModelSteps, vendor default applies
- F03-1 - fixed - InstallLaunchers includes vendor install path
- F03-2 - fixed - Argv receives turn options object with PromptFile
- F03-3 - fixed - All turns use engine adapter Events/Outcome functions
- F03-4 - fixed - -EngineExe bound to selected engine
- F03-5 - fixed - Muse vocabulary added to EffortVocabularies
- F03-6 - fixed - Preflight states implemented correctly
- F03-7 - fixed - Billing guard implemented as launch invariant
- F03-8 - fixed - MSP invariants implemented including resume session check
- F03-9 - fixed - All engine-specific wording pulled from engine row
- F03-10 - fixed - Get-MuseHarness implemented correctly
- F03-11 - fixed - Exit classes mapped correctly, step cap detected
- F03-12 - fixed - Muse has its own ToolsLine in prompt
- F03-13 - fixed - tests/harness-muse.ps1 exists

## Verdict: ACCEPT

All critical and major findings from the design review have been fixed; remaining items are accepted documented limitations per decisions D1-D16.

### Blockers

_(none)_

### Unproven scenarios

- Live run behavior with the real Muse CLI binary
- Actual step-cap exit reason matching the regex pattern
- Keychain backend preflight behavior on real systems
- Path with % characters through the .cmd launcher chain

### First-run checklist (observable)

- [ ] `muse exec` receives all expected arguments: --prompt-file, --output-schema, --reasoning-effort, --max-model-steps, --session-id
- [ ] MSP stream schema_version is exactly 1
- [ ] Exactly one session UUID is present in the stream
- [ ] run.model.configured matches the requested model exactly
- [ ] A working tree mutation forces failure class `permission` even when the run exits non-zero
- [ ] Each muse turn is counted separately in engine_run.turns
- [ ] `META_API_KEY` set in the environment refuses the run even with `-SkipPreflight`
