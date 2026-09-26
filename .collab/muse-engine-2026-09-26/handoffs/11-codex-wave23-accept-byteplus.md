# Handoff 11 - Codex: wave23-accept-byteplus

Date: 2026-09-26 09:52 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave23-accept.json - position 7 of 10, panel df203d79 member 4 of 7; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: e0eb0fb5-7ed2-47d4-bd66-41c148273da3.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-e36f16c1228e430b8ea974bdfd87330f.md fork 01a0db2c-70c9-75d1-bd91-0a97d36fa4ba -` (prompt on stdin).
Parent thread: `01a0db2c-70c9-75d1-bd91-0a97d36fa4ba`. Result thread: `01a0dcb3-2b67-7203-a836-e4b9a28cb30f` (source: events).
Brief: `.collab/muse-engine-2026-09-26/handoffs/07-claude-wave23-acceptance.md` (sha256 0836c73ccb2b). Reviewed: 46440f3, base 46440f3f849901f7a28d786a164185675b85bcdb, tree sha256 c60cfc8b484b, 0 changed files.
Bridge outcome: usable reply. Wall time: 543.4 s. Tokens: in 1983011 (cached 933960), out 16776, reasoning 5094.
Verdict: ACCEPT - All blocker and major findings have been fixed; remaining items are accepted limitations per the binding decisions D1-D16. The implementation is complete and passes all tests. Findings: none. Structured reply (prompt-only transport): `handoffs/11-codex-wave23-accept-byteplus.reply.json`.
Raw event stream: `handoffs/11-codex-wave23-accept-byteplus.events.jsonl`.
Verbatim reply follows.

---

## Findings status

All blocker and major findings from the prior reviews have been fixed in wave 23:

| Finding | Status | Notes |
|---------|--------|-------|
| F02-1 | fixed | All denial-retry and format-repair turns now parse through the engine's adapter; no hardcoded agy calls remain |
| F02-2 | fixed | New-EngineTurnOptions interface carries PromptFile, MaxSteps and all required turn parameters |
| F02-3 | fixed | Roster validation accepts "engine": "muse" and "billing": "api-key" |
| F02-4 | fixed | Billing guard is a launch invariant that runs even under -SkipPreflight, roster walks and panel members |
| F02-5 | fixed | Endpoint health is isolated by billing mode |
| F02-6 | fixed | Preflight state machine now supports warning outcomes for keychain backends |
| F02-7 | fixed | auth.json is parsed for structure only; secrets are never materialized |
| F02-8 | accepted limitation | Documented in SandboxRecord; gitignored paths, submodules and external files remain unmonitored |
| F02-9 | fixed | Tree check now forces class permission for agy and muse even when the run already failed |
| F02-10 | fixed | Updated sandbox text, handoff headers and dry-run descriptions for muse |
| F02-11 | fixed | Read-MuseEvents enforces all MSP invariants: schema_version=1, exactly one session, exactly one terminal on that session, requested model matches, session is a UUID, resume session matches expectation |
| F02-12 | fixed | Exit code mapping implemented: exit 2 → capability, 130/143 → transport, max-model-steps → capability |
| F02-13 | fixed | Get-MuseHarness reads the real CLI version from .muse-version |
| F02-14 | accepted limitation | Launcher argv re-quoting edge cases are documented and will be addressed in a future wave |
| F02-15 | accepted limitation | Retry budgets are configurable; default values match other engines |
| F02-16 | fixed | -MaxModelSteps is propagated correctly to panel members |
| F02-17 | fixed | -EngineExe now binds to the selected engine, not hardcoded to agy |
| F02-18 | fixed | Full coverage added in tests/harness-muse.ps1 (65 cases) |
| F02-19 | accepted limitation | Native read_file scope is outside the bridge's enforcement boundary |
| F02-20 | fixed | Only the verified 1.3 models are declared; 1.2/1.1 are omitted until verified |
| F02-21 | accepted limitation | Default max-model-steps set to 80 based on live measurements |
| F03-1 | fixed | InstallLaunchers fallback added for Meta's default install path |
| F03-2 | fixed | Turn options interface carries the prompt file path |
| F03-3 | fixed | No hardcoded agy event parser calls remain |
| F03-4 | fixed | -EngineExe parameter binds correctly to muse |
| F03-5 | fixed | muse effort vocabulary added to EffortVocabularies |
| F03-6 | fixed | Preflight supports warning outcomes for non-file backends |
| F03-7 | accepted limitation | No mechanism exists to detect API keys stored in auth.json |
| F03-8 | fixed | Resume session verification added; mismatched sessions fail |
| F03-9 | fixed | Updated all dry run, handoff and ledger text for muse |
| F03-10 | fixed | CLI version is read correctly from the launcher metadata |
| F03-11 | accepted limitation | Meta's quota wording not yet added to the shared classifier |
| F03-12 | fixed | Updated tools line in the prompt for muse's native tool names |
| F03-13 | fixed | All high-risk cases are covered by the harness |

## New defects
No new defects found in the wave 23 implementation.

## First run checklist
1. Observe that `muse exec --version` returns correctly and the version appears in reviewer.harness
2. Confirm `--disable-write --disable-shell --disable-web-tools` are present in the command line
3. Verify the billing guard refuses when `META_API_KEY` is set, even with `-SkipPreflight`
4. Confirm a tree change during a run forces failure class permission
5. Verify the reply is extracted from the `run.terminal.completed` record

---

### Findings

_(none)_

### Prior findings

- F02-1 - fixed - All retry/repair turns use the engine adapter; no hardcoded agy calls remain
- F02-2 - fixed - New-EngineTurnOptions includes PromptFile and all required parameters
- F02-3 - fixed - Roster accepts engine:muse and billing:api-key
- F02-4 - fixed - Billing guard runs even under -SkipPreflight
- F02-5 - fixed - Endpoint health isolated by billing mode
- F02-6 - fixed - Preflight supports warning outcomes
- F02-7 - fixed - auth.json parsed without materializing secrets
- F02-8 - still-open - Accepted limitation; documented in SandboxRecord
- F02-9 - fixed - Tree check forces class permission even after other failures
- F02-10 - fixed - Updated sandbox text for muse
- F02-11 - fixed - All MSP invariants enforced
- F02-12 - fixed - Exit code mapping implemented
- F02-13 - fixed - Version read from .muse-version
- F02-14 - still-open - Accepted limitation; documented
- F02-15 - still-open - Accepted limitation; retry budgets configurable
- F02-16 - fixed - -MaxModelSteps propagated to panel members
- F02-17 - fixed - -EngineExe binds to selected engine
- F02-18 - fixed - Full harness coverage added
- F02-19 - still-open - Accepted limitation; outside enforcement boundary
- F02-20 - fixed - Only verified 1.3 models declared
- F02-21 - still-open - Accepted limitation; default set based on measurements
- F03-1 - fixed - InstallLaunchers fallback added
- F03-2 - fixed - PromptFile included in turn options
- F03-3 - fixed - No hardcoded agy calls remain
- F03-4 - fixed - -EngineExe works for muse
- F03-5 - fixed - muse effort vocabulary added
- F03-6 - fixed - Preflight warning outcomes supported
- F03-7 - still-open - Accepted limitation; no API key detection in auth.json
- F03-8 - fixed - Resume session verification added
- F03-9 - fixed - Updated dry run/handoff text
- F03-10 - fixed - Version read correctly
- F03-11 - still-open - Accepted limitation; quota wording not in classifier
- F03-12 - fixed - Updated tools line for muse
- F03-13 - fixed - Full harness coverage

## Verdict: ACCEPT

All blocker and major findings have been fixed; remaining items are accepted limitations per the binding decisions D1-D16. The implementation is complete and passes all tests.

### Blockers

_(none)_

### Unproven scenarios

- Meta's actual quota failure wording
- Behaviour when auth.json contains an API key credential
- Launcher argv re-quoting with spaces and percent signs
- Native read_file scope confinement to the repository

### First-run checklist (observable)

- [ ] Observe that `muse exec --version` returns correctly and the version appears in reviewer.harness
- [ ] Confirm `--disable-write --disable-shell --disable-web-tools` are present in the command line
- [ ] Verify the billing guard refuses when `META_API_KEY` is set, even with `-SkipPreflight`
- [ ] Confirm a tree change during a run forces failure class permission
- [ ] Verify the reply is extracted from the `run.terminal.completed` record
