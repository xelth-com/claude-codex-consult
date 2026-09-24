# Handoff 15 - Codex: wave10-mimo

Date: 2026-09-24 17:18 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 3, panel 6710207b member 2 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 24e58794-e32a-4c3c-a179-9368e98afbe5.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-06bf1a7688cb4686aae9104976b7924e.md fork 01a0d30e-4128-77d1-bc53-c0d8bd5df63b -` (prompt on stdin).
Parent thread: `01a0d30e-4128-77d1-bc53-c0d8bd5df63b`. Result thread: `01a0d3ff-7dd5-7b92-be1f-b4220c3e59d2` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/13-claude-wave10-panel-review.md` (sha256 77b703a4e500). Reviewed: 68353d7 + uncommitted, base 68353d756cbb581700a0be3d4338cd32a43a1950, tree sha256 c4981ee3dd15, 27 changed files.
Bridge outcome: usable reply. Wall time: 266.8 s. Tokens: in 2904128 (cached 1253248), out 31341, reasoning 15941.
Verdict: HOLD - Wave 10 is structurally sound, but reset-time parsing can authorize a still-limited reviewer across DST or cross-zone legacy data, and timeout survivors can prevent later panel members from running. Findings: 1 blocker, 2 major, 1 minor, 0 note (F15-1..F15-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/15-codex-wave10-mimo.reply.json`.
Raw event stream: `handoffs/15-codex-wave10-mimo.events.jsonl`.
Verbatim reply follows.

---

**Q1.** `Get-RetryAfter` handles no-year dates at lines 2689-2690 and AM/PM at 2679-2683. It treats an unspecified time as 24-hour by design (2634-2650): `try again at Sep 28th, 2026 8:35` becomes 08:35, twelve hours early if 20:35 was meant. The larger failure is DST: lines 2687 and 2689 attach `$Reference.Offset` to the reset wall time. A Berlin failure at `2026-10-25T01:00:00+02:00` saying `try again at Oct 26th, 2026 8:35 PM` is parsed as `20:35+02:00` (18:35Z), although post-transition CET means 19:35Z; the roster can launch one hour early. A recorded `retry_after` containing an offset is safe as an instant. Legacy messages without `retry_after` are not safe across machines: when PowerShell materializes `when` as `[datetime]`, line 2779 re-labels its wall time with the reader's offset. A `-05:00` failure read in `+08:00` shifts the reference and reset by thirteen hours (finding #2).

**Q2.** Task A contains an old entry without `provider_failure.retry_after`, with `when=2026-09-24T12:54:23-05:00` and message `try again at Sep 28th, 2026 8:35 PM`; task B has no newer record for that endpoint. Read in `+08:00`, the failure becomes `12:54+08:00` and the reset `2026-09-28T20:35:00+08:00` (12:35Z), not 2026-09-29 01:35Z. At Sep 28 13:00Z the walk selects entry 1 although its quota is still active. A second mis-pick is line 2816: an auth failure timestamped six minutes in the future is ignored, so its roster entry is selected.

**Q3.** Member 2's timeout is handled inside its child bridge: it records `bridge_outcome="failed: timeout ..."` and normally removes `.consult.pending.json`, allowing member 3 to run; the panel still exits 1 and summarizes member 2 failed. If killed processes survive, lines 1602-1613 leave the pending record in state `survivors`. Member 3 then finds an active reservation at lines 1183-1188 and refuses before writing its ledger entry; `Find-PanelEntry` returns null and the summary marks it failed. The loop continues but later members are equally blocked, contradicting the claim that one member's failure does not stop the others.

**Q4.** **HOLD.** Blockers: finding #1. Major: findings #2 and #3. F12-1 remains open for rotated credentials. Unproven: Codex's actual timezone convention for printed reset dates, cross-host JSON date behavior, and timeout/survivor behavior mid-panel. First run must show the openai roster entry skipped with exactly `usage limit until 2026-09-28T20:35:00+02:00`, this member's `panel.id`, position and members list, `provider_source=roster`, host-correct `schema_transport`, and a reply named `handoffs/14-codex-wave10-<provider>.md` or `15-...`.

## Requested checks
- RC1 (finding #1): repository root, workspace-write, 5 minutes: add the Berlin DST fixture and require reset `2026-10-26T19:35:00+01:00`.
- RC2 (finding #2): repository root, workspace-write, 5 minutes: read the stated `-05:00` ledger fixture under `+08:00` and compare the resulting UTC reset.
- RC3 (finding #3): repository root, workspace-write, 15 minutes: time out member 2 with surviving children and observe whether member 3 starts.

---

### Findings

- **F15-1** [blocker] `plugins/codex-consult/scripts/codex-consult-common.ps1:2687`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2689`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2852` - Reset wall times are interpreted with the failure moment's fixed offset, so a reset after a DST transition has the wrong instant and the roster can select a reviewer whose tokens have not reset. Trigger: A Berlin failure at 2026-10-25T01:00:00+02:00 reports `try again at Oct 26th, 2026 8:35 PM`; evaluation occurs between the computed and actual reset instants. Evidence: read-code: Both dated forms construct DateTimeOffset with `$Reference.Offset`, never the reset date's zone offset.; read-code: Health authorizes the endpoint as soon as the computed RetryAfter is past. Verify: Run Get-RetryAfter with the stated Berlin input and require 2026-10-26T19:35:00+01:00 rather than 18:35Z. Remedy: Parse local wall dates with the recording machine's IANA zone and DST rules, or require provider reset messages to carry an offset.
- **F15-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:2776`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2837` - Legacy failures lacking `retry_after` can be reinterpreted in the reading machine's zone, shifting their quota window by hours. Trigger: Read a pre-wave-10 ledger written at offset -05:00 on a PowerShell host whose local offset is +08:00. Evidence: read-code: A DateTime value is converted with the reader's local offset; offset information is not reconstructed.; read-code: The harness itself notes that pwsh reads ISO ledger timestamps back as local DateTime. Verify: Seed the stated cross-zone legacy entry, read it from +08:00, and compare `RetryAfter` UTC with the original recording-zone value. Remedy: Preserve offset-bearing timestamps as strings/instants and record the producer's time zone for offset-less local reset text.
- **F15-3** [major] `plugins/codex-consult/scripts/codex-consult.ps1:1604`, `plugins/codex-consult/scripts/codex-consult.ps1:1613`, `plugins/codex-consult/scripts/codex-consult.ps1:748` - A member timeout that leaves surviving processes blocks every later panel member through the shared pending reservation, despite the invariant that one member's failure does not stop the others. Trigger: Member 2 exceeds `-TimeoutSec` and `Stop-ProcessTree` reports survivors, leaving `.consult.pending.json` in state `survivors`. Evidence: read-code: The timeout path keeps a `survivors` pending record.; read-code: The panel continues spawning members, but each later child encounters the shared active pending record and fails without an entry. Verify: Make member 2 time out with a surviving child and assert that member 3 either runs after cleanup or the invariant is formally narrowed. Remedy: Quarantine and terminate/recover the failed member's reservation before continuing, or make the panel contract explicitly stop on persistent survivors.
- **F15-4** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2816` - Endpoint-health records dated more than five minutes in the future are silently ignored, allowing a roster walk to select a provider with a recent auth or quota failure. Trigger: A ledger entry has `when` six minutes ahead because of clock skew or timezone reinterpretation. Evidence: read-code: `age < -5` skips the record entirely rather than treating it as current or unknown. Verify: Seed a future auth failure six minutes ahead and verify the roster currently selects that endpoint. Remedy: Clamp small future skew to age zero and treat larger future timestamps as unknown health, not absent health.

### Prior findings

- F02-4 - fixed - caps-v1 remains endpoint-host and exact-model based, including aliases and MiMo hosts.
- F06-1 - fixed - Unsupported OpenAI provider-set declarations still force unresolved identity and refuse reuse.
- F06-2 - fixed - Provider and model remain separately compared with endpoint fingerprint.
- F06-3 - fixed - Peak status remains re-evaluated immediately before launch.
- F06-4 - fixed - Long exception ranges remain interval-based rather than loop-truncated.
- F12-1 - still-open - Anonymous endpoints now use roster `auth: none`, but retrying with a rotated credential still requires broad `-SkipPreflight`.
- F12-2 - fixed - Classifier order is now capability, auth, quota, transport and sensitive auth terms are word-anchored.

## Verdict: HOLD

Wave 10 is structurally sound, but reset-time parsing can authorize a still-limited reviewer across DST or cross-zone legacy data, and timeout survivors can prevent later panel members from running.

### Blockers

- **F15-1** `plugins/codex-consult/scripts/codex-consult-common.ps1:2687`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2689`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2852` - Reset wall times are interpreted with the failure moment's fixed offset, so a reset after a DST transition has the wrong instant and the roster can select a reviewer whose tokens have not reset. Verify: Run Get-RetryAfter with the stated Berlin input and require 2026-10-26T19:35:00+01:00 rather than 18:35Z. Remedy: Parse local wall dates with the recording machine's IANA zone and DST rules, or require provider reset messages to carry an offset.

### Unproven scenarios

- Whether Codex formats reset wall times with the failure-moment offset or the reset-instant offset.
- PowerShell 5.1 and 7 JSON materialization of offset-bearing ledger timestamps across time zones.
- Panel continuation and recovery when a timed-out member leaves surviving processes.
- Provider formats that omit AM/PM from otherwise twelve-hour reset times.

### First-run checklist (observable)

- [ ] The roster record lists openai as skipped with reason exactly `usage limit until 2026-09-28T20:35:00+02:00`.
- [ ] `panel` contains one stable `id`, this member's position and of-count, and the complete members list.
- [ ] `provider_source` is `roster`, with the roster entry's provider/model and separate lineage.
- [ ] `schema_transport` matches this endpoint's caps-v1 host policy and its source is recorded.
- [ ] The reply is persisted as `handoffs/14-codex-wave10-<provider>.md` or `handoffs/15-codex-wave10-<provider>.md`.
- [ ] The panel summary reports every available member and exits 0 only if each produced a usable reply.
