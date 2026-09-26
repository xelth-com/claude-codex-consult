# Handoff 09 - Codex: wave23-accept-mimo

Date: 2026-09-26 09:51 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave23-accept.json - position 3 of 10, panel df203d79 member 2 of 7; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 1517a95e-5571-434e-9382-20827fa4034c.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-07f88d1e0b804bfeb237fa45ba5f3138.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage mimo :: mimo-v2.6-pro in this task's ledger; other lineage(s): meta :: muse-spark-1.3-contributor [muse], byteplus :: dola-seed-2.0-pro, byteplus :: deepseek-v4.1-flash, ZAI :: glm-5.3). Result thread: `01a0dcb3-1b19-7700-8787-a87bd01e9413` (source: events).
Brief: `.collab/muse-engine-2026-09-26/handoffs/07-claude-wave23-acceptance.md` (sha256 0836c73ccb2b). Reviewed: 46440f3, base 46440f3f849901f7a28d786a164185675b85bcdb, tree sha256 c60cfc8b484b, 0 changed files.
Bridge outcome: usable reply. Wall time: 1581.8 s. Tokens: in 2096829 (cached 859904), out 28231, reasoning 18245.
Verdict: HOLD - HOLD: two new major defects remain, and F03-11 still leaves Meta quota failures without a reliable blocking class. Findings: 0 blocker, 2 major, 1 minor, 0 note (F09-1..F09-3, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/09-codex-wave23-accept-mimo.reply.json`.
Raw event stream: `handoffs/09-codex-wave23-accept-mimo.events.jsonl`.
Verbatim reply follows.

---

## 1. Prior findings
All F02-1..F02-21 and F03-1..F03-13 are ruled in `prior_findings` with code locations. The turn-options contract, adapter dispatch, launcher binding, billing guard, MSP checks, exit classes, version recording, effort vocabulary, wording, tree boundary, roster handling and tests are implemented at `codex-consult-common.ps1:3014-3314,3632-3983,4590-4608` and `codex-consult.ps1:2215-2220,2701-2774,2958-2969,3017-3060`, with coverage in `tests/harness-muse.ps1:222-681`.
F03-11 remains open: max-step wording is handled, but Meta quota wording is still only classified through generic patterns at `codex-consult-common.ps1:3998-4015`; the reset parser is at `:4170+`. F02-4/F03-7 leave the narrowed billing residual in finding #1. F02-11 leaves the stream-provenance residual in finding #3. F02-7, F02-8, F02-19 and F03-8 are accepted limitations under D5, D12 and the documented account/session boundary.

## 2. New defects
Finding #1 is a major billing-safety hole: unknown credential mechanism is treated as launch-safe under `-SkipPreflight`. Finding #2 is a major transport mismatch: prompt-only structured runs send the native schema on format repair. Finding #3 is a minor MSP provenance gap: session/model evidence is not bound to expected stream provenance.

## 3. Acceptance decision
HOLD. Fix findings #1 and #2 and resolve or explicitly downgrade F03-11 before acceptance. The successful live run demonstrates viability but does not cover the real launcher chain, quota wording, auto-update behavior or the prompt-only repair path.

## Requested checks
RC1: With `TBH_CREDENTIAL_BACKEND` unset and a fake credential containing `providers.meta.api_key` but no `mechanism`, run `codex-consult.ps1 -Engine muse -Model muse-spark-1.3 -Prompt x -SkipPreflight`; observe whether launch is refused before `Start-Process`. Budget: 5 minutes, workspace-write.
RC2: Run fake-muse with `-SchemaTransport prompt-only`, a prose first reply and `-FormatRetry 1`; inspect the second argv and ledger. It must not silently change transport. Budget: 10 minutes, workspace-write.
RC3: Run fake-MSP with one nested session stream and model evidence on another stream; inspect thread/model acceptance. Budget: 5 minutes, workspace-write.
RC4: On the first real Muse run, verify launcher/harness, exact argv, MSP schema/session/model/terminal invariants, `engine_run`, tree result and validated reply before trusting exit code 0. Budget: 10 minutes, workspace-write.

---

### Findings

- **F09-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:3637`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3665`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3705`, `plugins/codex-consult/scripts/codex-consult.ps1:1684` - The Muse billing launch invariant is not fail-closed when the credential mechanism cannot be read: the keychain or a credential without providers.meta.mechanism leaves Mechanism empty, Get-MuseLaunchBlock returns no refusal, and -SkipPreflight can launch a potentially API-key-billed run. Trigger: TBH_CREDENTIAL_BACKEND is not file or auth.json has providers.meta without a readable mechanism, META_API_KEY and MODEL_API_KEY are unset, and the run passes -SkipPreflight. Evidence: read-code: Non-file backend is recorded as keychain with State unknown and Mechanism empty.; read-code: Missing mechanism does not set a refusal; launch block only rejects a nonempty mechanism other than oauth.; read-code: -SkipPreflight reaches the same launch-block check, but an empty block allows the run. Verify: Run the fake keychain/no-mechanism credential with -SkipPreflight and assert that no Muse process starts and no ledger entry is written. Remedy: Refuse launch whenever oauth billing cannot be established, including unknown/keychain state, even under -SkipPreflight; or require a separate explicit override and record it. Supersedes: F02-4, F03-7.
- **F09-2** [major] `plugins/codex-consult/scripts/codex-consult.ps1:2215`, `plugins/codex-consult/scripts/codex-consult.ps1:2958`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3759` - A structured run with schema transport prompt-only silently switches the format-repair turn to native schema, so the repair can be rejected by the endpoint or contradict the recorded transport. Trigger: Run with -SchemaTransport prompt-only, receive substantive prose, and let -FormatRetry 1 attempt repair. Evidence: read-code: Main turn passes Schema only when schemaTransport is native.; read-code: Repair options always pass schemaPath, independent of schemaTransport.; read-code: New-MuseArgv emits --output-schema whenever Schema is nonempty. Verify: Use fake-muse with prompt-only transport and a prose first reply; inspect the repair argv and ledger schema_transport for a mismatch. Remedy: Pass no schema flag on repair when transport is prompt-only, or explicitly record and validate a separate repair transport.
- **F09-3** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:3823`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3961` - MSP session and model evidence are collected from any matching stream records without checking stream provenance, so a nested or substream record can become the accepted session or model evidence. Trigger: A CLI update emits one nested/substream session record and model evidence on a different stream. Evidence: read-code: Any stream.kind=session id is collected; no record-type or parent-stream provenance is required.; read-code: Configured model values are compared globally, not bound to the session stream. Verify: Feed fake MSP with nested session provenance and model evidence off the session stream; inspect whether it is accepted. Remedy: Bind session and run.model.configured evidence to the expected run/session stream or fail closed on ambiguous provenance. Supersedes: F02-11.

### Prior findings

- F02-1 - fixed - Adapter Events/Outcome dispatch is used for main, denial and repair turns: codex-consult.ps1:2701-2702,2773-2774,2967-2969.
- F02-2 - fixed - New-EngineTurnOptions includes PromptFile and every turn passes its own file: codex-consult-common.ps1:3300-3303; codex-consult.ps1:2219,2764,2958.
- F02-3 - fixed - Roster accepts engine muse and intentionally rejects unsupported billing keys: codex-consult-common.ps1:4589-4608.
- F02-4 - fixed - Billing block is checked under -SkipPreflight, in the walk, panel and listing; residual unknown-mechanism case is finding #1.
- F02-5 - fixed - Shared muse endpoint identity is explicit per D14: codex-consult-common.ps1:2461-2472; accepted limitation.
- F02-6 - fixed - Keychain state is unknown and refuses unless -SkipPreflight: codex-consult-common.ps1:3637-3641,4701-4704.
- F02-7 - fixed - Accepted limitation per D5: local shape/mechanism check at codex-consult-common.ps1:3647-3670; values are not logged.
- F02-8 - fixed - Boundary is documented and coded: codex-consult.ps1:668-695; accepted limitation for gitignored/submodule/external paths.
- F02-9 - fixed - Tree mutation forces permission even after another failure: codex-consult.ps1:2730-2740.
- F02-10 - fixed - Engine-specific TreeNote/SandboxRecord wording is used: codex-consult-common.ps1:3104-3107; codex-consult.ps1:692-694.
- F02-11 - fixed - D6 one-session, UUID, terminal-stream and model checks are implemented at codex-consult-common.ps1:3839-3863,3945-3973; residual split to finding #3.
- F02-12 - fixed - Exit 2 capability, 130/143 transport and step-cap capability are mapped at codex-consult-common.ps1:3922-3927,3950-3955.
- F02-13 - fixed - Version is recorded from .muse-version/release info/--version at codex-consult-common.ps1:3721-3749; pinning is not required by D8.
- F02-14 - fixed - Spaces are tested and percent arguments are refused before launch: codex-consult-common.ps1:3319-3325; tests/harness-muse.ps1:482-506.
- F02-15 - fixed - Muse denial retry is off, repair is once, and turns are counted: codex-consult-common.ps1:3100; codex-consult.ps1:2748,2958,3046-3050.
- F02-16 - fixed - -MaxModelSteps is carried into panel specs and members: codex-consult.ps1:1137,1211-1213,1670-1675.
- F02-17 - fixed - codex-providers.ps1 binds -EngineExe to the selected non-codex engine at lines 143-148.
- F02-18 - fixed - harness-muse covers argv, paths, billing, preflight, MSP, failure classes, tree, repair, panel and listing cases at tests/harness-muse.ps1:222-681.
- F02-19 - fixed - Accepted limitation per D12: reads and external paths are explicitly outside the evidence boundary at codex-consult.ps1:668-678.
- F02-20 - fixed - Only live-verified muse-spark-1.3 models are declared at codex-consult-common.ps1:2598-2601.
- F02-21 - fixed - -MaxModelSteps has no bridge default; vendor default applies at codex-consult.ps1:1670-1675.
- F03-1 - fixed - Vendor install fallback is implemented at codex-consult-common.ps1:3095-3097,3124-3150.
- F03-2 - fixed - PromptFile is part of the turn-options object and all three turns pass distinct files: codex-consult.ps1:2219,2764,2958.
- F03-3 - fixed - No literal agy parser calls remain on engine retry/repair paths; adapter dispatch is at codex-consult.ps1:2701-2702,2773-2774,2967-2969.
- F03-4 - fixed - -EngineExe is bound to the selected engine in codex-consult.ps1:911-918 and codex-providers.ps1:143-148.
- F03-5 - fixed - muse-v1 is declared and a missing vocabulary is a plan error: codex-consult-common.ps1:2583-2585,2674-2679.
- F03-6 - fixed - Keychain unknown is refused by preflight unless -SkipPreflight: codex-consult-common.ps1:3637-3641,4701-4704.
- F03-7 - fixed - Mechanism is read and non-oauth refuses; residual unreadable-mechanism bypass is finding #1: codex-consult-common.ps1:3665-3671,3705-3712.
- F03-8 - fixed - Resume mismatch is rejected by ExpectThread at codex-consult-common.ps1:3945-3948; account binding and echoed-id freshness remain accepted limitations.
- F03-9 - fixed - Engine row supplies prompt transport, reply source and sandbox wording: codex-consult-common.ps1:3099-3108.
- F03-10 - fixed - muse-cli version comes from .muse-version/release metadata or --version: codex-consult-common.ps1:3721-3749.
- F03-11 - still-open - Step-cap classification is fixed at codex-consult-common.ps1:3888,3908,3952, but Meta quota wording is not known to the generic patterns at :3998-4015.
- F03-12 - fixed - Muse tools line names read_file and the disabled tools at codex-consult-common.ps1:3107.
- F03-13 - fixed - harness-muse adds the missing cases at tests/harness-muse.ps1:222-681; the real launcher chain remains unproven.

## Verdict: HOLD

HOLD: two new major defects remain, and F03-11 still leaves Meta quota failures without a reliable blocking class.

### Blockers

_(none)_

### Unproven scenarios

- The real muse.cmd to .muse-launcher.ps1 to muse-bin chain, including empty stdin and quoting behavior.
- Actual Meta quota and max-step wording and whether Get-RetryAfter can extract a reset.
- Auto-update changing the binary after .muse-version is read.
- Whether Muse can echo a requested session id while starting a fresh session.
- Whether Muse read_file can access files outside the repository.

### First-run checklist (observable)

- [ ] Log or output identifies launcher and harness as muse-cli with a concrete version.
- [ ] Command/argv shows muse exec --json --prompt-file, the intended schema/model/effort, read-only flags, and --max-model-steps only when requested.
- [ ] MSP stream has schema_version 1, exactly one UUID session stream, one run_terminal completed record, and run.model.configured equals the requested model.
- [ ] Ledger records usable reply, thread equal to the MSP session, engine_run turns/max_model_steps/msp_schema_version, usage null, and a validated reply JSON.
- [ ] tree_changed_during_review is false with no monitored tree or collab changes; otherwise the run must fail class permission.
- [ ] If a repair occurs, engine_run.turns is 2 and the repair events file exists; otherwise it is 1 and no retry consumed an extra prompt.
