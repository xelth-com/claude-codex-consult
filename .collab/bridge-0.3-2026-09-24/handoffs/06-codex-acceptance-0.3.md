# Handoff 06 - Codex: acceptance-0.3

Date: 2026-09-24 10:31 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai/gpt-6-astra (provider from codex default, model from config; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Effort: high sent (requested high, mapping openai, by host builtin:openai; not confirmed by the provider). Consultation id: 901785be-78fc-420e-8755-24113e0dee62.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-286a3ffbd1de41f4aca82133cd5054b5.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage openai/gpt-6-astra in this task's ledger; 1 thread(s) recorded before 0.3.0 have unknown provenance and are never automatic parents; other lineage(s): ZAI/glm-5.3). Result thread: `01a0d28a-804b-7672-930f-92c70d35a165` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/05-claude-acceptance-0.3.md` (sha256 d9ed3a496299). Reviewed: 68353d7 + uncommitted, base 68353d756cbb581700a0be3d4338cd32a43a1950, tree sha256 7da4b991fb6d, 22 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 334 s. Tokens: in 885870 (cached 815360), out 6587, reasoning 661.
Verdict: HOLD - Provider resolution can incorrectly authorize builtin provenance, and ambiguous lineage strings permit cross-provider/model reuse. Findings: 2 blocker, 1 major, 1 minor, 0 note (F06-1..F06-4, tracked in `findings.json`). Structured reply: `handoffs/06-codex-acceptance-0.3.reply.json`.
Raw event stream: `handoffs/06-codex-acceptance-0.3.events.jsonl`.
Verbatim reply follows.

---

**Q1. Prior findings.**

- **F02-1 — fixed for the original trigger:** the configured default provider/model are resolved and pinned in argv. Residual identity defects appear in findings #1 and #2.
- **F02-2 — still-open:** formatting-independent fingerprints and quoted/literal strings are implemented, but unsupported ancestor declarations can hide an OpenAI override and receive a resolved builtin fingerprint (finding #1).
- **F02-3 — fixed:** unrelated rollouts remain diagnostic candidates; reusable fallback threads require the consultation ID. Event extraction is restricted to session-start events.
- **F02-4 — still-open:** alias handling and requested/sent/confirmed bookkeeping are improved, but capabilities remain inferred from entire hosts or model prefixes. Read-only calls mapped both an unlisted model on `api.z.ai` and `glm-unknown` on an unknown host to `max`. The earlier requirement for model-specific declared capabilities remains unmet.
- **F02-5 — fixed within the agreed convention:** finding positions identify new findings; handoff-qualified RC numbers distinguish requests; the completion table records revision, logs, status and observation. This is a manual convention, without machine enforcement.
- **F02-9 — still-open:** ordinary boundaries, overnight windows, exceptions and unknown schedules are defined. However, eligibility is evaluated before potentially lengthy preparation, and long exception ranges silently truncate (findings #3–#4).

R9 remains deferred appropriately: ROADMAP records the F02-6/7/8 requirements and explicitly describes current sequential comparisons as non-blind.

**Q2. Invalid structured replies.** Keep the existing contract: preserve the exact response, record the validation error, and ingest neither verdict nor findings. Exit code 0 means a reply was delivered; it does not establish a valid acceptance review. A mandatory retry is unnecessary. Any later retry should be an explicit, separately recorded attempt that preserves the first response and its revision bindings.

**Q3. Acceptance.** **HOLD.** Findings #1 and #2 block acceptance because reusable provenance is the central R7 invariant. Address the remaining F02-4 capability gap and peak defects before closing their prior findings.

I read the changed scripts, relevant harnesses, template and roadmap. Both scripts parsed without errors; `git diff --check` passed. Read-only in-memory probes reproduced the identity and lineage defects, confirmed ordinary peak boundaries, and exposed exception truncation. The full harness totals remain coordinator-reported: those harnesses write fixtures and logs, so I did not execute them. Actual CLI routing, provider-applied effort, and this consultation’s final persisted artifacts remain unproven.

Before trusting this run’s exit 0, observe a new `openai/gpt-6-astra` thread with no parent; matching event/ledger thread IDs and consultation ID; the expected provider/model sources and builtin fingerprint; pinned argv; a locally validated structured reply with all six prior dispositions; unchanged revision bindings; persisted findings/reviewer checks; and completed pending-record cleanup. The detailed checklist below specifies the observable fields.

## Requested checks

- **RC1** — Working directory: repository root; permission: workspace-write; budget: 30 minutes. Extend the existing harness with findings #1–#2 and F02-4 fixtures, then run it under Windows PowerShell 5.1 and PowerShell 7. Observe hidden overrides becoming unresolved, colliding identity tuples refusing automatic fork and explicit resume, and undeclared capabilities requiring an explicit policy/native value.
- **RC2** — Working directory: repository root; permission: workspace-write; budget: 15 minutes. Use a controlled-clock fake-launch fixture that crosses into peak during preparation, plus the exception interval in finding #4. Observe no child launch after the boundary and either complete exception handling or an explicit range-limit error.
- **RC3** — Working directory: repository root; permission: workspace-write; budget: two local request-capture runs. With a scratch Codex configuration and local logging endpoint, exercise an OpenAI override and a provider without `wire_api`; compare the CLI’s actual destination/protocol with recorded identity. Preserve redacted evidence establishing agreement or unresolved provenance.

---

### Findings

- **F06-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:1774`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1789`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1822`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1998` - An unsupported ancestor declaration containing an OpenAI provider override is treated as absence of that override, producing resolved and reusable builtin provenance instead of unknown identity. Trigger: A configuration with model="gpt-6-astra" defines either model_providers = { openai = { base_url="https://proxy.example/v1", wire_api="responses" } } or model_providers.openai = { base_url="https://proxy.example/v1", wire_api="responses" }. Evidence: read-code: The scanner marks the ancestor model_providers unsupported; exact provider lookup ignores unsupported ancestors, and the missing exact openai table selects the builtin branch.; ran-command: Both fixtures returned Resolved=true, an empty note, and CompatString=cc-provider-v1|builtin:openai with fingerprint 56d97b6ece36e75295a290d931ca6bbe2dd0b1f0807454b21a63a6fd17b32d7c. Verify: Add both configurations to the existing harness and require unresolved identity, an empty compatibility fingerprint, and fork/resume refusal. Remedy: Propagate unsupported ancestor state into provider lookup; permit builtin fallback only when the scanner can establish that an override is absent. Supersedes: F02-2.
- **F06-2** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:2050`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2329`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2358` - Concatenating provider and model with '/' creates ambiguous lineage identities, allowing a thread to change both provider and model when endpoint fingerprints match. Trigger: Provider a/b with model c and provider a with model b/c use identical endpoint/protocol configurations; both serialize as lineage a/b/c. Evidence: read-code: Parent selection compares the concatenated lineage and endpoint fingerprint rather than the stored provider/model tuple.; ran-command: The two distinct identities produced the same lineage; explicit resume returned the first identity's thread as parent with an empty error. Verify: Create these two identities in a ledger fixture and test automatic fork and explicit resume; both must refuse cross-identity reuse. Remedy: Compare reviewer.provider and reviewer.model separately using ordinal comparisons in every parent-selection path; retain lineage as display metadata or encode it unambiguously.
- **F06-3** [major] `plugins/codex-consult/scripts/codex-consult.ps1:487`, `plugins/codex-consult/scripts/codex-consult.ps1:820`, `plugins/codex-consult/scripts/codex-consult.ps1:957` - OffPeakOnly authorizes launch using a stale preflight decision, so a consultation can start inside peak hours while recording peak=false. Trigger: Preflight runs just before a peak boundary, then artifact hashing, revision fingerprinting or other preparation crosses the boundary before Start-Process. Evidence: read-code: Peak status is calculated once before preparation; child launch does not refresh it, and the ledger stores the earlier result.; inferred: The documented launch-time gate does not hold when preparation crosses the schedule boundary. Verify: Run a controlled-clock fixture that advances from off-peak to peak during revision fingerprinting and assert that no child launches under OffPeakOnly. Remedy: Re-evaluate eligibility immediately before launching, use that evaluation for the ledger, and record its timestamp; retain early validation for malformed schedules. Supersedes: F02-9.
- **F06-4** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2219` - Exception ranges longer than 3,700 days silently lose their remaining dates, causing peak decisions to disagree with the recorded schedule. Trigger: An exception interval exceeds the loop guard, for example 2026-01-01..2037-12-31, and evaluation occurs on 2037-01-01. Evidence: read-code: Date expansion stops at 3,700 iterations and returns success without reporting truncation.; ran-command: The read-only probe returned peak=true, no error, and detail 'inside the peak window' despite the date being inside the declared exception interval. Verify: Add the stated range and evaluation date to the peak fixtures; require peak=false or an explicit unsupported-range error. Remedy: Evaluate exception intervals directly or reject oversized ranges explicitly instead of truncating them. Supersedes: F02-9.

### Prior findings

- F02-1 - fixed - The original configured-ZAI/no-Provider trigger is addressed by resolving the configured provider/model and pinning them in argv. This does not establish correctness for every configuration shape; findings #1 and #2 identify separate remaining identity failures.
- F02-2 - still-open - Canonical fingerprints and supported quoted/literal syntax improve the implementation, but unsupported ancestor declarations fail open. Finding #1 replaces the broad design concern with a reproduced implementation defect.
- F02-3 - fixed - Read code and fixture assertions confirm that unrelated newest rollouts remain candidates rather than reusable threads; fallback attribution requires the consultation ID, and event parsing is limited to session-start types. The writing harness was not rerun.
- F02-4 - still-open - Endpoint aliases now map consistently and effort_confirmed correctly remains null, but model-specific capabilities are still assumed. Read-only probes accepted an unlisted model on api.z.ai and glm-unknown on an unknown host without an explicit capability declaration.
- F02-5 - fixed - Within the agreed convention, local finding positions and handoff-qualified RC identifiers provide unambiguous references; the completion template supplies revision, exit status, log reference, observation and state. Automated schema enforcement remains deferred.
- F02-9 - still-open - Schedule semantics and ordinary boundary/exception behavior are implemented and selected helper cases passed. Findings #3 and #4 replace the broad design concern with stale launch eligibility and silent exception truncation defects.

## Verdict: HOLD

Provider resolution can incorrectly authorize builtin provenance, and ambiguous lineage strings permit cross-provider/model reuse.

### Blockers

- **F06-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:1774`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1789`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1822`, `plugins/codex-consult/scripts/codex-consult-common.ps1:1998` - An unsupported ancestor declaration containing an OpenAI provider override is treated as absence of that override, producing resolved and reusable builtin provenance instead of unknown identity. Verify: Add both configurations to the existing harness and require unresolved identity, an empty compatibility fingerprint, and fork/resume refusal. Remedy: Propagate unsupported ancestor state into provider lookup; permit builtin fallback only when the scanner can establish that an override is absent.
- **F06-2** `plugins/codex-consult/scripts/codex-consult-common.ps1:2050`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2329`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2358` - Concatenating provider and model with '/' creates ambiguous lineage identities, allowing a thread to change both provider and model when endpoint fingerprints match. Verify: Create these two identities in a ledger fixture and test automatic fork and explicit resume; both must refuse cross-identity reuse. Remedy: Compare reviewer.provider and reviewer.model separately using ordinal comparisons in every parent-selection path; retain lineage as display metadata or encode it unambiguously.

### Unproven scenarios

- The full Windows PowerShell 5.1 and PowerShell 7 harness results were reported by the coordinator, not rerun during this read-only review.
- Actual Codex routing for user-defined OpenAI overrides and the protocol selected when wire_api is absent remain unverified against request capture.
- Provider-applied effort and model-specific supported effort vocabularies are not established by argv or effort_confirmed=null.
- Configuration layering outside the scanned config file and authentication-dependent builtin routing were not established.
- The preparation-to-launch peak transition was established by code ordering, not an end-to-end controlled-clock run.
- This consultation's final persisted reply, ledger entry and finding ingestion cannot be verified before the bridge processes this response.
- macOS execution remains unverified.

### First-run checklist (observable)

- [ ] The persisted entry has consult_id 901785be-78fc-420e-8755-24113e0dee62, lineage openai/gpt-6-astra, mode new and an empty parent_thread; legacy and ZAI threads were not selected.
- [ ] reviewer.provider is openai with provider_source 'codex default'; reviewer.model is gpt-6-astra with model_source 'config'; provider_config identifies builtin openai and provider_fingerprint is 56d97b6ece36e75295a290d931ca6bbe2dd0b1f0807454b21a63a6fd17b32d7c for the claimed configuration without an endpoint override.
- [ ] Recorded argv contains -m gpt-6-astra and model_provider="openai"; effort_requested and effort_sent match the invocation, effort_mapping is openai, and effort_confirmed remains null.
- [ ] The events contain thread.started with the exact UUID stored in thread, thread_source is events, and thread_candidate is empty; any fallback instead has observable consultation-ID correlation.
- [ ] The raw final response is preserved in reply.json, local validation reports structured=true with no validation_error, and the recorded verdict is HOLD.
- [ ] All six prior IDs have the dispositions in this response; every new finding receives a persisted ID, and supersedes references point to the intended earlier findings.
- [ ] Before/after tree and brief hashes match, artifact drift flags are false, and the reply header and ledger bind the same reviewed revision.
- [ ] A successful turn.completed event is present; reported usage matches it, while unavailable usage fields remain null.
- [ ] Peak metadata accurately records the evaluated schedule and status; an unset schedule is null rather than false.
- [ ] The reply, findings and sessions stores are readable after completion, the pending record has been removed, and no survivor or registration warning appears. Exit 0 alone does not establish acceptance.
