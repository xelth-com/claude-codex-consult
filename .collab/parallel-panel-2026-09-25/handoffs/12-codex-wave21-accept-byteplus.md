# Handoff 12 - Codex: wave21-accept-byteplus

Date: 2026-09-26 00:19 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave21-live.json - position 7 of 9, panel 46393649 member 6 of 8; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: 9d2e9ebd-82fa-4373-b780-d97a31b854ce.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8aa5758b68e441aba480068e15ac16da.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage byteplus :: dola-seed-2.0-pro in this task's ledger; other lineage(s): ZAI :: glm-5.3, byteplus :: deepseek-v4.1-flash, kimi :: k3). Result thread: `01a0daa6-feb8-7812-b5fa-d2ec5cfa67af` (source: events).
Brief: `.collab/parallel-panel-2026-09-25/handoffs/06-claude-wave21-acceptance.md` (sha256 8ee810642cf3). Reviewed: 2de15e9, base 2de15e98fe5b490575ff1bdfd8ae76a102c01793, tree sha256 d78eb77b4aea, 0 changed files.
Bridge outcome: usable reply. Wall time: 447.4 s. Tokens: in 637937 (cached 192936), out 4868, reasoning 1509.
Verdict: ACCEPT - All blocker and major findings are fixed; remaining items are accepted documented limitations per the binding decisions. Findings: none. Structured reply (prompt-only transport): `handoffs/12-codex-wave21-accept-byteplus.reply.json`.
Raw event stream: `handoffs/12-codex-wave21-accept-byteplus.events.jsonl`.
Verbatim reply follows.

---

## Wave 21 R11 Acceptance Review

All blocker and major findings from the earlier consultation have been addressed in commit 2de15e9. The implementation matches the design and binding decisions D1-D13.

### Prior findings status

- ✅ **F02-1**: Fixed. Parent holds task lock until all members exit; write lock is OS-held, released on process death.
- ⚠️ **F02-2**: Accepted limitation (D7). Cross-task concurrency failure mode documented as residual.
- ✅ **F02-3**: Fixed. `Get-NextNumbers` accepts array of leftovers; all readers enumerate all pending records.
- ✅ **F02-4**: Fixed (D3). Write lock give-up keeps the member record, no store writes attempted.
- ✅ **F02-5**: Fixed (D9). Health sorted by `finished_at`, ties broken by `n`.
- ✅ **F03-1**: Fixed. `Test-PendingActive` now checks writer pid liveness directly; new `committing` state.
- ✅ **F03-2**: Fixed (D1). Panel records never use the machine-wide name scan.
- ✅ **F03-3**: Fixed (D9). Health uses completion time, not start time.
- ✅ **F03-4**: Fixed (D8). Endpoint-aware concurrency groups labels by provider fingerprint.
- ✅ **F03-5**: Fixed. Write lock is OS-held (D2); member proof uses per-member records (D6).
- ✅ **F03-6**: Fixed (D4). Ingest and handoff rendered inside the write lock after re-read.
- ✅ **F03-7**: Fixed (D5). Parent cleans up unused reserved records at summary.
- ⚠️ **F03-8**: Accepted limitation (D12). Task lock held for whole panel duration; documented.
- ✅ **F03-9**: Fixed (D10). Ledger entries sorted by `n`, not finish time.
- ✅ **F03-10**: Fixed. `tests/harness-panel.ps1` exists with 48 assertions including concurrency cases.
- ⚠️ **F03-11**: Accepted and documented. Kill inside commit may leave ORPHAN findings; harness case added.
- ✅ **F04-1**: Fixed (D7). Ignore prefixes include temp file patterns for atomic writes.
- ✅ **F04-2**: Fixed (D3). Give-up path never touches stores; record kept for recovery.
- ✅ **F04-3**: Fixed (D2). Single store commit routine used by members, single runs and `codex-findings.ps1`.
- ✅ **F04-4**: Fixed. Parent holds task lock; writer pid liveness check covers commit window.
- ✅ **F04-5**: Fixed (D1). Panel records never use fallback name scan.
- ✅ **F04-6**: Fixed (D11). Guard calculation includes all phases plus slack.
- ✅ **F04-7**: Fixed (D10). Entries inserted by `n`, preserving order invariant.
- ✅ **F04-8**: Fixed (D8). Sequential execution per provider endpoint avoids correlated failures.

### Unproven scenarios
- Parent death between member parent check and record rewrite (declared residual)
- Orphaned reviewer detection outside Windows (declared residual)
- Short-lived orphan child processes keeping records active briefly (declared residual)

### First run checklist
1.  Panel summary shows correct concurrency limits per provider
2.  All members report "bridge acquired write lock after X s" in logs
3.  No member reports "collab directory changed" when siblings commit
4.  `codex-findings.ps1 -Status` runs without error immediately after panel exit
5.  Ledger entries appear in roster order regardless of finish order

---

### Findings

_(none)_

### Prior findings

- F02-1 - fixed - Parent holds task lock through commit; write lock is OS-held
- F02-2 - still-open - Accepted limitation per D7; documented residual
- F02-3 - fixed - Get-NextNumbers takes array of leftovers; all readers enumerate all pending records
- F02-4 - fixed - Give-up never touches stores; record kept in committing state
- F02-5 - fixed - Get-EndpointHealth sorts by finished_at, ties by n
- F03-1 - fixed - Test-PendingActive checks writer pid liveness; new committing state
- F03-2 - fixed - Panel records never use machine-wide name scan
- F03-3 - fixed - Get-EndpointHealth uses completion time, not start time
- F03-4 - fixed - Get-PanelPlan implements endpoint-aware concurrency groups
- F03-5 - fixed - Write lock is OS-held; member proof uses per-member records
- F03-6 - fixed - Ingest and handoff rendered inside write lock
- F03-7 - fixed - Parent removes unused reserved records at summary
- F03-8 - still-open - Accepted limitation per D12; documented
- F03-9 - fixed - Ledger kept sorted by n regardless of finish order
- F03-10 - fixed - tests/harness-panel.ps1 with 48 assertions exists
- F03-11 - still-open - Accepted and documented; harness case added
- F04-1 - fixed - Get-PanelIgnorePrefixes includes temp file patterns
- F04-2 - fixed - Give-up path never attempts to write stores
- F04-3 - fixed - Single store commit routine used by all writers
- F04-4 - fixed - Parent holds task lock; writer pid checked for liveness
- F04-5 - fixed - Panel records never use fallback name scan
- F04-6 - fixed - Guard calculation includes all phases plus slack
- F04-7 - fixed - Entries inserted by n preserving order invariant
- F04-8 - fixed - Sequential execution per endpoint avoids correlated quota failures

## Verdict: ACCEPT

All blocker and major findings are fixed; remaining items are accepted documented limitations per the binding decisions.

### Blockers

_(none)_

### Unproven scenarios

- Parent death between member parent check and record rewrite
- Orphaned reviewer detection outside Windows
- Short-lived orphan child processes keeping records active briefly

### First-run checklist (observable)

- [ ] Panel summary shows correct concurrency limits per provider
- [ ] All members report 'bridge acquired write lock after X s' in logs
- [ ] No member reports 'collab directory changed' when siblings commit
- [ ] codex-findings.ps1 -Status runs without error immediately after panel exit
- [ ] Ledger entries appear in roster order regardless of finish order
