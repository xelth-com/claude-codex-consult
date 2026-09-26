# Handoff 15 - Codex: wave23-accept-zai-continued

Date: 2026-09-26 13:10 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from -Model; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: c1d97b0f-ad6d-4d7c-8b4e-fb1f1fb35296.
Invocation: `codex-consult.ps1` (mode: resume, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-4b71340eb03d40d2b4eaa20a454e0e15.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json resume 01a0dcb3-1de5-7f20-80a9-b5313e215e7e -` (prompt on stdin).
Parent thread: `01a0dcb3-1de5-7f20-80a9-b5313e215e7e`. Result thread: `01a0dcb3-1de5-7f20-80a9-b5313e215e7e` (source: events).
Brief: `.collab/muse-engine-2026-09-26/handoffs/07-claude-wave23-acceptance.md` (sha256 0836c73ccb2b). Reviewed: 23843df, base 23843dfed323678b6230c08e4957c2618b7a96c7, tree sha256 9af745409676, 0 changed files.
Bridge outcome: usable reply. Wall time: 148.1 s. Tokens: in 14170399 (cached 13307904), out 43513, reasoning 21738.
Verdict: ACCEPT - The post-fix wave has no remaining blocker or major in the reviewed code and tests; only a narrow cache-hardening note and acceptance-SHA bookkeeping remain. Findings: 0 blocker, 0 major, 1 minor, 1 note (F15-1..F15-2, tracked in `findings.json`). Structured reply: `handoffs/15-codex-wave23-accept-zai-continued.reply.json`.
Raw event stream: `handoffs/15-codex-wave23-accept-zai-continued.events.jsonl`.
Verbatim reply follows.

---

## Q1 — ruling on every listed prior finding

**Fixed:** F02-1, F02-2, F03-2 and F03-3. `New-EngineTurnOptions` now carries model, mode, thread, per-turn prompt file, schema, effort, native effort and max steps (`codex-consult-common.ps1:3294-3303`); main, denial-retry and repair turns all call `$engineSpec.Adapter` (`codex-consult.ps1:2219-2220, 2764-2774, 2958-2969`).

**Fixed:** F02-3 and F02-5 by the binding subscription-only decision: `muse` is a valid engine, there is deliberately no billing roster key, and every muse entry shares the one Meta sign-in endpoint (`codex-consult-common.ps1:3061, 2471-2472`; decisions D4/D14).

**Fixed:** F02-4. Billing is an engine launch invariant checked during roster/panel selection, before the run, in provider listings and again before every engine turn (`codex-consult-common.ps1:3305-3313, 4763-4767, 4824-4826`; `codex-consult.ps1:1681-1685, 602-606`; `codex-providers.ps1:294-296`).

**Fixed:** F02-6 and F02-7, with the D5 residual accepted. Keychain/no-mechanism states are `unknown` and refuse ordinary preflight; the file check reads only structural fields plus the non-secret mechanism and does not log the parsed credential (`codex-consult-common.ps1:3613-3677, 4680-4704`). Shape still cannot prove token validity; a real run classifies that failure.

**Fixed:** F02-9 and F02-10. A detected mutation forces `provider_failure.class = permission` even after another failure, and muse has engine-specific sandbox, tree and tools wording (`codex-consult.ps1:2729-2740, 3015-3035, 692-694`; `codex-consult-common.ps1:3101-3107`).

**Fixed:** F02-11 and F02-12. MSP parsing enforces schema version 1, one session, one on-session terminal, UUID shape, requested-model equality and explicit exit/step-cap classes (`codex-consult-common.ps1:3794-3864, 3867-3983`). The later F09-3 fix addresses stream provenance.

**Fixed:** F02-13 and F03-10. Muse harness version comes from `.muse-version`, release metadata or `--version`; the ledger also records MSP schema version (`codex-consult-common.ps1:3715-3749`; `codex-consult.ps1:2703, 3044-3050`).

**Fixed:** F02-16 and F02-17. `-MaxModelSteps` is muse-only, panel-carried and ledger-recorded (`codex-consult.ps1:386-390, 770, 1211-1213, 1670-1679, 3044-3050`); `-EngineExe` binds to the selected engine in both CLIs (`codex-consult-common.ps1:3153-3179`; `codex-consult.ps1:911-918`; `codex-providers.ps1:143-147`).

**Fixed:** F02-18, F02-20 and F03-13. `tests/harness-muse.ps1` and `fake-muse.ps1` cover the adapter, argv, malformed/partial MSP, sessions, model drift, exits, billing, preflight, tree, resume, repair, panel, launcher and listing branches; caps declares only the two live-verified 1.3 models (`codex-consult-common.ps1:2598-2602, 2625-2626`; `tests/README.md:31`).

**Fixed:** F03-1, F03-4 and F03-5. Resolution includes the vendor install location, explicit binding is engine-aware, and `muse-v1` exists with a loud missing-vocabulary error (`codex-consult-common.ps1:3092-3098, 3119-3149, 3153-3179, 2583-2585, 2674-2679`).

**Fixed:** F03-6, F03-9 and F03-12 through the muse credential states and engine-row wording for prompt transport, reply source, sandbox and tools (`codex-consult-common.ps1:3632-3687, 3092-3108`).

**Fixed with an accepted account residual:** F03-8. A resumed session must equal the parent (`codex-consult-common.ps1:3941-3948`); one account per endpoint remains D14/TECH_DEBT T7.

**Fixed in the follow-up commit:** F09-1, F09-2 and F09-3, per the coordinator note. I saw their pre-fix shapes in the read snapshot, but did not reread the later patch.

## Q2 — new defects and test assessment

No new blocker or major remains in what I read. Finding #1 notes a narrow credential-cache race. Finding #2 records an acceptance-process risk: the reviewed SHA `f2c219a` predates the F09 fixes, so acceptance should cite and preserve the final fix SHA. The harness source is unusually comprehensive and would catch the intended regressions, but I could not execute it under this read-only constraint.

Verified: code paths above, decisions D1-D16, test/fake source, and the reported live success. Inferred: actual future MSP drift, real launcher update behavior, Meta quota wording beyond the tested synthetic sentence, and out-of-tree filesystem confinement.

## Q3 — verdict

**ACCEPT** for the post-F09-fix state, provided the accepted commit is advanced to the SHA containing those fixes and the first-run checklist below is observed.

## Requested checks

- **RC1** — Working directory: repository root; permission: workspace-write. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\harness-muse.ps1`. Observe zero failures after the F09 fixes. Budget: 10-15 minutes.
- **RC2** — Working directory: repository root; permission: read-only. Run `git log --oneline --decorate f2c219a..HEAD`. Identify the exact F09 fix SHA to record as accepted. Budget: one minute.

---

### Findings

- **F15-1** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:3622`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3676`, `plugins/codex-consult/scripts/codex-consult.ps1:1684`, `plugins/codex-consult/scripts/codex-consult.ps1:602` - Muse credential information is cached for the lifetime of the bridge process, so the second billing-guard call immediately before launch can reuse an earlier mechanism result instead of rereading auth.json. Trigger: auth.json changes from an oauth mechanism to an API-key mechanism after the early muse identity/billing check but before a secondary turn or process launch. Evidence: read-code: Get-MuseCredentialInfo keys MuseCredentialCache by backend and path and returns the cached info before reading the file.; read-code: The run and every engine turn call Get-MuseLaunchBlock, which delegates to the cached credential-info reader. Verify: Dot-source the common script against a scratch auth file, read an oauth result, replace only the mechanism with api_key, and call Get-MuseLaunchBlock again; it should refuse, but the observed cache returns the stale oauth result. Remedy: Add a no-cache/fresh-read parameter for launch invariants, or clear the credential cache before every pre-Start-Process guard while retaining cache only for provider listings/preflight.
- **F15-2** [note] `.collab/muse-engine-2026-09-26/handoffs/07-claude-wave23-acceptance.md:5` - The acceptance artifact names f2c219a as the commit under review even though F09-1 through F09-3 were fixed only in a later commit, so citing only f2c219a would accept a SHA known to lack three reviewed fixes. Trigger: Recording f2c219a, rather than the follow-up F09 fix SHA, as the accepted wave-23 commit. Evidence: read-code: The brief explicitly names f2c219a as the commit under review.; assumed: The coordinator states F09-1 through F09-3 were fixed in a later commit. Verify: Run `git log --oneline f2c219a..HEAD` and confirm which descendant contains the F09 fixes before recording acceptance. Remedy: Advance the reviewed/accepted commit reference to the descendant containing F09-1 through F09-3 and retain its harness result.

### Prior findings

- F02-1 - fixed - Turn options and adapter-routed retry/repair are implemented at codex-consult-common.ps1:3294-3303 and codex-consult.ps1:2219,2764-2774,2958-2969.
- F02-2 - fixed - The turn-options object carries prompt file, effort and max steps into New-MuseArgv.
- F02-3 - fixed - muse is accepted by EngineNames/roster validation; the billing key is intentionally absent under D4.
- F02-4 - fixed - Billing is checked in roster walk, panel, run and every launch; -SkipPreflight does not bypass it.
- F02-5 - fixed - Subscription-only muse removes mixed billing routes; shared one-sign-in health is D14.
- F02-6 - fixed - Keychain/no-mechanism is unknown and refused by ordinary preflight.
- F02-7 - fixed - Mechanism is inspected without logging secrets; inability to prove token validity is the accepted D5 residual.
- F02-9 - fixed - Tree mutations force class permission even when another failure preceded them.
- F02-10 - fixed - Muse sandbox, tree and prompt wording comes from the engine row.
- F02-11 - fixed - MSP version, session, terminal, UUID and model invariants are enforced; F09-3 later adds provenance hardening.
- F02-12 - fixed - Exit 2, signals, step cap and terminal failures have explicit classes.
- F02-13 - fixed - Harness version and MSP schema version are recorded.
- F02-16 - fixed - MaxModelSteps is validated, panel-propagated and ledger-recorded.
- F02-17 - fixed - codex-providers EngineExe now binds through Resolve-EngineExeBinding.
- F02-18 - fixed - harness-muse.ps1 and fake-muse.ps1 cover the declared high-risk matrix.
- F02-20 - fixed - Only the two live-verified muse-spark-1.3 models are declared.
- F03-1 - fixed - The Windows vendor install path is checked after explicit/env/PATH resolution.
- F03-2 - fixed - Each secondary turn passes its own PromptFile through the common options object.
- F03-3 - fixed - All engine turns dispatch Events/Outcome through the adapter.
- F03-4 - fixed - EngineExe is bound to the selected non-codex engine in both CLIs.
- F03-5 - fixed - muse-v1 exists and a missing vocabulary is a loud plan error.
- F03-6 - fixed - The keychain backend returns unknown/refusal rather than a warning-only state.
- F03-8 - fixed - Resume session equality is enforced; shared account identity remains the accepted D14/T7 limitation.
- F03-9 - fixed - Prompt transport, reply source and sandbox text are engine-specific.
- F03-10 - fixed - Muse version is read from version metadata or a free version command.
- F03-12 - fixed - The prompt uses Muse's read_file/disable-write/disable-shell wording.
- F03-13 - fixed - The new fake and dedicated harness pin MSP/argv and the changed secondary-turn paths.
- F09-1 - fixed - Fixed in the later commit named by the coordinator; the fail-open keychain shape was visible in the snapshot I read.
- F09-2 - fixed - Fixed in the later commit named by the coordinator; the read snapshot still passed a native schema on prompt-only repair.
- F09-3 - fixed - Fixed in the later commit named by the coordinator; the read snapshot accepted model/session evidence without provenance checks.

## Verdict: ACCEPT

The post-fix wave has no remaining blocker or major in the reviewed code and tests; only a narrow cache-hardening note and acceptance-SHA bookkeeping remain.

### Blockers

_(none)_

### Unproven scenarios

- tests/harness-muse.ps1 was inspected but not executed because this consultation is read-only.
- The later F09-1 through F09-3 fix commit was not reread after the coordinator notification.
- A real Muse auto-update between version capture and exec, and an MSP schema-2 stream, are covered by design/tests but not observed live.
- Muse resume after clearing or moving the CLI session store, and behavior after switching Meta accounts, were not live-tested.
- Native read_file confinement to the repository and Meta's exact future quota wording remain documented residuals.

### First-run checklist (observable)

- [ ] Console and ledger command begin `muse exec --json --prompt-file <temp-file>`, include the selected model and mapped `--reasoning-effort`, and include all five read-only flags with `--approval-mode never`; `--max-model-steps` appears exactly when requested.
- [ ] The resolved launcher is the intended muse.cmd/exe, and `reviewer.harness` names a concrete CLI version rather than `version unknown`.
- [ ] Preflight reports providers.meta with mechanism oauth; `reviewer.provider_config.credential_mechanism` is oauth; neither META_API_KEY nor MODEL_API_KEY is set.
- [ ] The saved MSP stream has schema_version 1, exactly one UUID session stream, the terminal on that stream, terminal completed, and run.model.configured exactly equal to the requested model.
- [ ] For a new run the ledger thread is that session UUID; for resume it equals the parent thread. A mismatch produces exit 1, never an ingested reply.
- [ ] `engine_run.turns` is 1 unless a permitted format repair actually ran, `msp_schema_version` is 1, usage is null, and the raw terminal text plus extracted reply.json preserve the same JSON object.
- [ ] Local schema validation succeeds, the consultation id remains in the prompt/reply provenance, and findings/verdict are committed only from that valid object.
- [ ] The post-run tree/collab/brief/artifact check is clean; any detected mutation yields provider_failure.class permission and nothing is ingested. No credential value appears in console, handoffs or ledger.
