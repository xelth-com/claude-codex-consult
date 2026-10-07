# Handoff 25 - Codex: wave29-acceptance-astra4

Date: 2026-10-07 04:56 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - entry 1 of 10 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: e18cb7f9-9b0b-4aee-8c0e-f677290b5837.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8c1e7c92cef94bb9b9cd7e6966d7cd5b.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a11439-faa4-7962-9c20-84c2ee77571d -` (prompt on stdin).
Parent thread: `01a11439-faa4-7962-9c20-84c2ee77571d`. Result thread: `01a1144a-956f-7941-bfd8-4fb00114b99f` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/14-claude-wave29-acceptance.md` (sha256 c4d59bb1ce2f). Reviewed: 3f4d0e6, base 3f4d0e6b5e10edad0f3f8cd9c55114362ef6da33, tree sha256 516305377661, 0 changed files.
Bridge outcome: usable reply. Wall time: 100.9 s. Tokens: in 7745187 (cached 6375808), out 50234, reasoning 12276.
Timeout: 3600 s (-TimeoutSec); continuation after a timeout kill: up to 900 s. Range: `main..HEAD` - the range changes 74 files, 37605 lines (37355 insertions, 250 deletions).
Verdict: ACCEPT - A6 fixes the last reproduced acceptance blocker, and the targeted replays found no regression in quota retention, ordering or idempotence. Findings: none. Structured reply: `handoffs/25-codex-wave29-acceptance-astra4.reply.json`.
Raw event stream: `handoffs/25-codex-wave29-acceptance-astra4.events.jsonl`.
Verbatim reply follows.

---

**Q1.** The amended implementation is acceptable at `3f4d0e6`. Earlier verified fixes remain unchanged: prohibited init evidence blocks timeout continuation; foreign assistant models fail; required capability fields and subscription/API-key billing evidence are enforced; inherited routing, effort and persistence overrides are excluded. I found no new demonstrated bypass. E17 supersedes the brief’s stale unconditional four-tool wording; non-authoring auxiliary model usage remains permitted by amended D4.

**Q2.** The endpoint checks remain sufficient for the admitted third-party model IDs under the tested CLI contract: E11 rejects subscription-servable Anthropic IDs, missing tokens refuse launch, and recorded invalid-token attempts fail without subscription fallback. This is bounded evidence for the tested routes and versions, not independent wire-level attribution for every provider.

**Q3.** **F24-1 is fixed.** Independent read-only replays confirmed:

- Unmarked then marked success retains two records and the quota reset.
- Reversing insertion order preserves the same result.
- Replaying an identical marked record adds nothing.
- A different, longer reset remains distinct and governs health selection.
- Legacy unmarked record keys are unchanged.

The added harness fixture also exercises actual persistence and second-repository route/plan availability; the brief reports it passing. Earlier quota classification and same-plan running-count checks remain applicable. No new non-quota propagation or intrinsic merged-group deadlock was found. Scheduling remains the documented panel-side check, not atomic admission for all processes; single runs do not wait.

**Q4.** Roster validation is unchanged from the earlier successful mixed-roster and malformed-shape checks. Valid endpoint entries coexist with Codex entries; malformed entries intentionally refuse the entire roster with entry-specific diagnostics. Exhaustive validation of every possible JSON shape is not claimed.

**Q5.** Telemetry code is unchanged. Previous sentinel tests support omission of endpoint URLs, labels and key names, host-first classification, unknown-host `other/other`, and `[1m]` normalization. Quota marks remain outside the telemetry details allowlist.

**Q6.** Fake checks do not establish every provider’s authentication compatibility, actual billing attribution, real quota-event variants, arbitrary kill-point durability, sustained shared-state integrity or effects outside monitored paths. The previously inspected MiMo stream supplies native structured-output and continuation evidence; z.ai supplies invalid-token failure evidence. Full suites were not rerun here because they write files. The brief reports ACCEPT 12/12 and HEALTH 6/6 after A6; the complete rerun remains pending. Both changed PowerShell files passed independent syntax parsing.

**Q7.** **ACCEPT wave 29/29b as the reviewed engine candidate. No acceptance blockers remain.** F07-4 and F10-5 remain nonblocking provider-qualification and retention work; this verdict does not qualify untested providers or establish the deferred cost/quality decision.

The large range was reviewed cumulatively. This round inspected all four changed non-collaboration files since `b5f1225`—34 insertions and three deletions—and replayed the affected health logic. No files were written.

---

### Findings

_(none)_

### Prior findings

- F02-1 - fixed - Strict tree failure and WriteDisabled=false remain unchanged; monitored-write detection is not universal hook prevention.
- F02-2 - fixed - Previously verified child-environment allowlist remains unchanged.
- F02-3 - fixed - Shared model table, suffix normalization and tested alias resolution remain unchanged.
- F02-4 - fixed - Default panel serialization implements D5; broader shared-state guarantees remain limited.
- F02-5 - fixed - Explicit denial, quota and continuation rules remain implemented; A6 closes the identified quota-persistence defect.
- F03-1 - fixed - Claude retains strict tree failure rather than WriteDisabled attribution.
- F03-2 - fixed - API-key environment isolation remains unchanged from the verified implementation.
- F03-3 - fixed - Authentication probes and reviewer launches retain the shared environment builder.
- F03-4 - fixed - Inherited history-suppression variable remains excluded.
- F03-5 - fixed - Inherited effort override remains excluded.
- F03-6 - fixed - Previously replayed assistant-model drift fails with capability; enforcement is unchanged.
- F03-7 - fixed - Auth-mode/model-family health identities remain separate.
- F03-8 - fixed - MaxModelSteps retains its --max-turns mapping.
- F03-9 - fixed - Signed-out JSON handling remains ahead of exit-code uncertainty.
- F04-1 - not-checked - No sustained shared-state integrity test was performed; recorded successful concurrency remains bounded evidence.
- F04-2 - not-checked - Recorded successful interrupted-session resumes do not establish durability at arbitrary kill points.
- F07-1 - fixed - Credit-based measurement correction remains; account reconciliation is separate qualification work.
- F07-2 - fixed - Kimi Code and Moonshot endpoint/product distinctions remain documented.
- F07-3 - fixed - Canonical route/credential scope and separate plan identity remain implemented.
- F07-4 - still-open - Bearer-only compatibility is not qualified for every documented provider; this does not block the tested adapter scope.
- F07-5 - fixed - Previously executed endpoint telemetry fixtures remain applicable to unchanged code.
- F07-6 - fixed - Blanket eligibility assertion remains withdrawn; account-specific operator decisions are not verified here.
- F07-7 - fixed - Current claims concern inference/billing rather than guaranteed absence of all Anthropic traffic.
- F08-1 - fixed - Verified host-first telemetry classification remains unchanged.
- F08-2 - fixed - Verified universal model-suffix normalization remains unchanged.
- F08-3 - fixed - Route labels share plan health and scheduling; machine running records carry plan identity.
- F08-4 - fixed - Endpoint-local preflight and observed source semantics remain implemented, with recorded invalid-token failure evidence.
- F08-5 - fixed - Retention measurement uses credits rather than inferred prompt counts.
- F08-6 - fixed - Bounded API_TIMEOUT_MS injection remains implemented.
- F09-1 - fixed - Previously verified endpoint telemetry dispatch remains unchanged.
- F09-2 - fixed - Endpoint coordinator matching retains the documented route-label/model contract.
- F09-3 - fixed - Observed source semantics, E11 restrictions and invalid-token failure evidence address the original ambiguity.
- F09-4 - fixed - Endpoint suffix normalization remains implemented.
- F10-1 - fixed - Route lineage and plan quota identities remain distinct; A6 preserves marked health records.
- F10-2 - fixed - Endpoint environment injection and revised billing evidence remain implemented.
- F10-3 - fixed - Host-first classification, MiniMax coverage and suffix handling remain unchanged.
- F10-4 - fixed - E16 implements plan-aware panel counts across routes/repositories; atomic global admission and single-run waiting are not claimed.
- F10-5 - still-open - All-provider qualification and statistically supported retention remain deferred, outside this engine acceptance.
- F16-1 - fixed - E11 endpoint refusals for Anthropic IDs and aliases remain unchanged.
- F18-1 - fixed - E11 excludes the identified same-model subscription fallback scope; tested invalid-token behavior remains corroborating evidence.
- F18-2 - fixed - Assistant-model drift fails; non-authoring auxiliary usage remains intentionally permitted under amended D4.
- F20-1 - fixed - Verified ProofProblem handling and continuation refusal remain unchanged.
- F20-2 - fixed - The original foreign-assistant replay fails with capability; enforcement is unchanged.
- F20-3 - fixed - Required capability field presence/type checks remain unchanged.
- F20-4 - fixed - Recovered rejection retains warning and quota mark under A1; A6 closes the previously identified persistence loss.
- F22-1 - fixed - A1 explicitly amends D6 for successful recovery with warning and health mark.
- F22-2 - fixed - A2 specifies comparison against the init-resolved ID; previous alias replay passed.
- F22-3 - fixed - A3 documents reset-or-sixty-minute behavior and withdraws the burst-duration promise.
- F22-4 - fixed - A4 requires billing evidence under subscription/API-key; earlier missing-field replays passed.
- F22-5 - fixed - A5 corrects auth classification wording and documents the plan parallelism cap.
- F24-1 - fixed - Independent replays retained marked/unmarked records in both orders, preserved the longer reset, and deduplicated identical marked replays; legacy unmarked keys are unchanged.

## Verdict: ACCEPT

A6 fixes the last reproduced acceptance blocker, and the targeted replays found no regression in quota retention, ordering or idempotence.

### Blockers

_(none)_

### Unproven scenarios

- Full harness suites were not independently rerun; the brief reports targeted ACCEPT and HEALTH passes after A6, with a complete rerun pending.
- Authentication headers, destination attribution and actual account billing across every documented provider and CLI version.
- Kimi Code and other untested endpoints' bearer-authentication and native-schema compatibility.
- Real quota-event variants and overlapping provider limits beyond recorded and synthetic cases.
- Sustained shared-state integrity, arbitrary kill points, simultaneous panel admission and starvation freedom.
- Managed-hook effects outside monitored paths and large-prompt behavior near the configured bound.
- Account-specific terms decisions, dashboard credit reconciliation and statistically reliable route-retention results.

### First-run checklist (observable)

- [ ] Launcher version, auth mode, endpoint and route fingerprint match the selected roster entry.
- [ ] Every init carries valid capability fields, dontAsk, no MCP servers and only permitted tools; native-schema runs expose StructuredOutput.
- [ ] Assistant models match the init-resolved pin across main, continuation and repair turns.
- [ ] A failed init/model proof remains a failed consultation, with continuation explicitly marked not attempted.
- [ ] Subscription/API-key runs report the required apiKeySource; endpoint environment names show the intended routing variables without competing credentials.
- [ ] Native-schema success contains validated structured_output; continuation returns the expected session ID and exposes its own usage.
- [ ] Recovered quota rejection produces a warning and quota_mark; another repository observes the route and same-plan routes unavailable until the recorded reset.
- [ ] Replaying a marked health record does not increase its count, while a same-second unmarked success does not erase it.
- [ ] A pre-existing same-plan run on another route produces a panel waiting message, followed by progress after release.
- [ ] The tree check is clean and telemetry contains closed classifications without URL, label, key name or secret.
