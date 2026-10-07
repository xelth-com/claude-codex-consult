# Handoff 24 - Codex: wave29-acceptance-astra3

Date: 2026-10-07 04:38 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - entry 1 of 10 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: ba79de07-094c-4ed9-bb5f-00bc3f587aeb.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-bcc57152a9994e5cb183b90d6d644aa3.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a113af-e854-7c30-8034-4ad268f4a5f8 -` (prompt on stdin).
Parent thread: `01a113af-e854-7c30-8034-4ad268f4a5f8`. Result thread: `01a11439-faa4-7962-9c20-84c2ee77571d` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/14-claude-wave29-acceptance.md` (sha256 328de0ee6a81). Reviewed: b5f1225, base b5f12252eb1c509c778baaf13fcf53b89d060221, tree sha256 654fa37be3ab, 0 changed files.
Bridge outcome: usable reply. Wall time: 405.3 s. Tokens: in 7073281 (cached 5931904), out 45858, reasoning 11963.
Timeout: 3600 s (-TimeoutSec); continuation after a timeout kill: up to 900 s. Range: `main..HEAD` - the range changes 71 files, 36218 lines (35969 insertions, 249 deletions).
Verdict: HOLD - The previous turn-validation blockers are fixed, but machine-health deduplication can discard a successful turn's quota mark and defeat cross-repository plan propagation. Findings: 0 blocker, 1 major, 0 minor, 0 note (F24-1, tracked in `findings.json`). Structured reply: `handoffs/24-codex-wave29-acceptance-astra3.reply.json`.
Raw event stream: `handoffs/24-codex-wave29-acceptance-astra3.events.jsonl`.
Verbatim reply follows.

---

**Q1.** The previous failures are fixed at `b5f1225`. In-memory replays confirmed that prohibited init evidence on a timeout sets `ProofProblem`, foreign assistant models fail with `capability`, missing tools fail, and missing `apiKeySource` fails under subscription/API-key but remains permitted under endpoint. Alias resolution still passes. The caller explicitly blocks continuation after a proof failure.

I found no new demonstrated path accepting a prohibited tool, inherited routing variable or foreign assistant model. Non-authoring auxiliary `modelUsage` entries remain warnings by the amended D4 contract. Read E17 as overriding the brief’s stale four-tool statement; the implementation checks permitted tools and required field presence, rather than unconditional four-tool equality.

**Q2.** E11 and the existing environment/launch checks remain adequate for the admitted third-party model IDs under the tested CLI contract. I inspected the new bad-token stream: model `glm-5.3`, terminal `is_error=true`, and the handoff records 401/auth failure without subscription fallback. This corroborates P11. It does not independently establish network destinations or authentication headers for every provider/version; `apiKeySource: none` alone still proves neither.

**Q3.** Ordinary propagation and same-plan running counts now work in read-only replays. A recovered quota rejection produces a warning and mark; both ledger and machine-health conversion retain the quota and reset. An external running row with another fingerprint but the same plan is counted.

However, **finding #1 blocks acceptance**: marked and unmarked successful records from the same repository, route and second have identical deduplication keys. When the unmarked record arrives first, the marked record is discarded. My replay retained one unmarked record and left another repository unblocked.

No new non-quota propagation or intrinsic merged-group deadlock was demonstrated. E16 remains a panel-side, best-effort check: documentation explicitly says single runs do not wait. Simultaneous admission and starvation freedom were not established.

**Q4.** The roster validator is unchanged since the previous successful mixed-roster and malformed-shape replays. Those checks remain applicable: valid endpoint entries coexist with Codex entries; invalid entries intentionally refuse the entire roster. This is sampled validation, not exhaustive proof of every JSON shape.

**Q5.** The telemetry classifier/event builder is unchanged since the previous sentinel checks. Host-first classification, unknown-host `other/other`, universal `[1m]` normalization and omission of URL/label/key name remain supported by those results. The new quota mark is not copied into telemetry’s allowlisted details.

**Q6.** I independently inspected MiMo’s continuation stream and confirmed a successful `structured_output` on the same session. That closes the earlier absence of native-schema evidence for MiMo. The bad-token evidence also improved. Fake fixtures still do not prove all-provider authentication compatibility, wire-level credential attribution, actual quota-event variants, arbitrary kill-point durability, managed-hook behavior outside monitored paths, or sustained concurrent-state integrity. Full harnesses were reported by the coordinator; I did not rerun them because they write files. The common script passed a read-only syntax parse.

**Q7.** **HOLD for finding #1.** E12–E14/A4 close the previous validation blockers; E15/A1–A3 and E16 substantially address the quota/concurrency concerns. Fix quota-mark deduplication before accepting the claimed cross-repository propagation. F07-4 and F10-5 remain qualification/retention work outside the demonstrated provider scope, not additional blockers for the tested adapter scope.

Review coverage reused the previous implementation review and examined the seven changed non-collaboration files since `c92c30e`—464 insertions and 69 deletions—plus targeted live evidence. No files were written.

## Requested checks

- **RC1:** CWD repository root; **workspace-write**. Add an ACCEPT fixture submitting an unmarked successful machine-health record followed by a marked success with the same route, repository and timestamp; read health from a second repository, then run `powershell -NoProfile -File tests/harness-claude.ps1 -Only ACCEPT`. Require the mark/reset to survive, same-plan routes to be unavailable, and replaying the identical marked record to remain idempotent. Budget: one fixture, ten minutes; settles finding #1.

---

### Findings

- **F24-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:6481`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6577`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6671`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6061` - Machine-health deduplication can silently discard a quota mark added by E15: successful records with and without quota_mark have the same identity when their route, repository and second-resolution timestamp match. Trigger: Two consultations on the same route in one repository complete within the same second, for example with parallelism raised. An unmarked successful record is stored before a successful record carrying a rejecting rate-limit mark. Evidence: read-code: Format-OffsetIso drops subsecond precision. Both successful record variants have class ok and empty kind; Get-MachineHealthRecordKey uses endpoint, class, kind, repo and timestamp, excluding quota_mark. Update-MachineHealth drops records whose key already exists.; ran-command: Constructed marked and unmarked successful records with the same timestamp and applied the production key/HashSet admission logic. Two submitted records became one retained record with zero quota marks; Get-EndpointHealth for another repository returned no blocking quota.; ran-command: The marked record alone correctly preserved the quota and reset through machine-health conversion, isolating the loss to deduplication. Verify: Run RC1 and require both correct cross-repository quota propagation and idempotence when the identical marked record is replayed. Remedy: Give each consultation's health record a stable unique identity, or extend deduplication to distinguish quota-mark content and conservatively merge collisions. Preserve identical-record idempotence without dropping a newly observed or longer-lived quota mark. Supersedes: F20-4.

### Prior findings

- F02-1 - fixed - Strict tree failure and WriteDisabled=false remain unchanged; this detects monitored writes rather than preventing all hooks.
- F02-2 - fixed - Previously verified environment allowlist remains unchanged.
- F02-3 - fixed - Shared model table and suffix normalization remain; alias-resolution replay passed again.
- F02-4 - fixed - Default panel serialization is implemented; broader concurrency guarantees remain explicitly limited.
- F02-5 - fixed - Denial, quota and continuation rules are now explicit; quota persistence has the narrower defect in finding #1.
- F03-1 - fixed - Claude still uses strict tree failure rather than WriteDisabled attribution.
- F03-2 - fixed - Previously verified API-key environment isolation remains unchanged.
- F03-3 - fixed - Authentication probes and reviewer launches still share the environment builder.
- F03-4 - fixed - History-suppression variable remains excluded.
- F03-5 - fixed - Inherited effort override remains excluded.
- F03-6 - fixed - Foreign assistant-model replay now fails with capability; init and main usage checks remain.
- F03-7 - fixed - Auth-mode/model-family health identities remain separate.
- F03-8 - fixed - MaxModelSteps still maps to --max-turns.
- F03-9 - fixed - Signed-out JSON handling remains ahead of exit-code uncertainty.
- F04-1 - not-checked - No sustained shared-state integrity test was run; P7 supplies a bounded successful-concurrency observation.
- F04-2 - not-checked - New MiMo evidence confirms another successful timeout continuation, not durability at arbitrary kill points.
- F07-1 - fixed - Credit-based measurement correction remains; account reconciliation is separate.
- F07-2 - fixed - Kimi Code versus Moonshot endpoint distinction remains documented.
- F07-3 - fixed - Canonical route/credential scope and separate plan identity remain implemented.
- F07-4 - still-open - Bearer-only compatibility remains unqualified for every documented provider, including Kimi Code.
- F07-5 - fixed - Previously executed vendor/model telemetry fixtures remain applicable to unchanged helpers.
- F07-6 - fixed - Blanket eligibility assertion remains withdrawn; account-specific operator decisions are not verified here.
- F07-7 - fixed - The claim remains scoped to inference/billing, without a zero-Anthropic-egress guarantee.
- F08-1 - fixed - Host-first telemetry remains unchanged.
- F08-2 - fixed - Universal suffix normalization remains unchanged.
- F08-3 - fixed - Route-specific labels share plan health and scheduling; machine running rows now carry plan too.
- F08-4 - fixed - Endpoint-local preflight and observed source semantics remain implemented; new invalid-token evidence corroborates failure without fallback.
- F08-5 - fixed - Retention measurement uses credits rather than inferred prompt counts.
- F08-6 - fixed - Bounded API_TIMEOUT_MS injection remains implemented.
- F09-1 - fixed - Previously verified endpoint telemetry dispatch remains unchanged.
- F09-2 - fixed - Endpoint coordinator matching retains the documented route-label/model contract.
- F09-3 - fixed - Observed none, E11 restrictions and inspected invalid-token failure address the original ambiguity.
- F09-4 - fixed - Endpoint model suffix normalization remains implemented.
- F10-1 - fixed - Route lineage and plan quota identities remain distinct; finding #1 concerns persistence rather than identity.
- F10-2 - fixed - Endpoint environment and revised billing evidence remain implemented.
- F10-3 - fixed - Host-first classification, MiniMax row and suffix handling remain unchanged.
- F10-4 - fixed - E16 adds plan to running records and panel counts; cross-route counting replay passed. This is not atomic machine-wide admission or a single-run wait guarantee.
- F10-5 - still-open - Native MiMo evidence improved, but all-provider qualification and statistically supported retention remain deferred.
- F16-1 - fixed - E11 endpoint Anthropic-model refusals remain unchanged.
- F18-1 - fixed - E11 excludes the identified same-model subscription fallback scope; new 401 evidence corroborates tested routing.
- F18-2 - fixed - Assistant-model drift now fails; non-authoring auxiliary usage remains intentionally permitted under amended D4.
- F20-1 - fixed - Prohibited-init timeout replay sets ProofProblem; caller explicitly prevents continuation.
- F20-2 - fixed - The original Sonnet-100/Opus-10 assistant-drift replay now fails with capability.
- F20-3 - fixed - Parser preserves missing/type-invalid capability evidence; missing-tools replay fails with capability.
- F20-4 - still-open - Outcome warning and quota mark are fixed under amended A1, but end-to-end persistence remains incomplete; finding #1 replaces the claim with the deduplication defect.
- F22-1 - fixed - A1 explicitly amends D6 to usable reply plus warning/health mark after successful recovery.
- F22-2 - fixed - A2 specifies the init-resolved ID; alias-resolution replay passed.
- F22-3 - fixed - A3 withdraws the ten-minute burst promise and documents reset-or-sixty-minute behavior.
- F22-4 - fixed - A4 is implemented; missing-key replays fail under subscription/API-key and pass only under endpoint.
- F22-5 - fixed - A5 corrects auth classification wording and documents the additional plan parallelism cap.

## Verdict: HOLD

The previous turn-validation blockers are fixed, but machine-health deduplication can discard a successful turn's quota mark and defeat cross-repository plan propagation.

### Blockers

_(none)_

### Unproven scenarios

- Full write-producing harnesses were not independently rerun; reported suite results were assessed alongside code and read-only replays.
- Actual authentication headers, destination attribution and account billing across every documented provider and CLI version.
- Kimi Code and other untested endpoints' bearer-authentication and native-schema compatibility.
- Real quota-event variants, multiple overlapping quota windows and recovery behavior beyond the supplied fixtures.
- Sustained shared-state integrity, arbitrary hard-kill points, simultaneous panel admission and starvation freedom.
- Managed-hook effects outside monitored paths and large-prompt behavior near the configured bound.
- Account-specific terms decisions, dashboard credit reconciliation and statistically reliable route-retention evidence.

### First-run checklist (observable)

- [ ] Launcher version, auth mode, endpoint and route fingerprint match the selected roster entry.
- [ ] Every init explicitly carries valid capability fields, dontAsk, no MCP servers and only permitted tools; native schema runs include StructuredOutput.
- [ ] Every assistant model matches the init-resolved pin, including continuation and repair turns.
- [ ] A failed init/model proof produces a failed consultation and an explicit 'not attempted: the killed turn failed its proof' continuation record.
- [ ] Subscription/API-key runs show the required apiKeySource; endpoint launches show the intended environment names without competing credentials.
- [ ] Native-schema success contains validated structured_output; MiMo-style continuation returns the same session ID and exposes its own usage.
- [ ] A recovered quota rejection emits a warning and quota_mark, survives persistence, and makes same-plan routes unavailable from a second repository.
- [ ] A pre-existing same-plan run on another route produces a waiting message; the waiting panel proceeds after that running row is removed.
- [ ] Tree check is clean and telemetry contains closed classifications without endpoint URL, label, key name or secret.
