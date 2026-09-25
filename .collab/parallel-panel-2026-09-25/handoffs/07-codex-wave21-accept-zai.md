# Handoff 07 - Codex: wave21-accept-zai

Date: 2026-09-26 00:19 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave21-live.json - position 2 of 9, panel 46393649 member 1 of 8; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: d73aaeca-2d6f-4c71-bc1b-991420c58771.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-62836c4cfdcd4f5bb896733b93dbc9bc.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a0da1f-5e20-7d93-8d95-afa660fd5417 -` (prompt on stdin).
Parent thread: `01a0da1f-5e20-7d93-8d95-afa660fd5417`. Result thread: `01a0daa6-fbb6-7490-a496-2ec2985476aa` (source: events).
Brief: `.collab/parallel-panel-2026-09-25/handoffs/06-claude-wave21-acceptance.md` (sha256 8ee810642cf3). Reviewed: 2de15e9, base 2de15e98fe5b490575ff1bdfd8ae76a102c01793, tree sha256 d78eb77b4aea, 0 changed files.
Bridge outcome: usable reply. Wall time: 1217.8 s. Tokens: in 6453215 (cached 5966528), out 62605, reasoning 46642.
Verdict: ACCEPT - All 24 open findings are fixed in code with tests or accepted/documented per decisions D1-D13, and the new-defect hunt found no blocker or major — only one narrow, data-safe, declared TOCTOU residual filed as a note. Findings: 0 blocker, 0 major, 0 minor, 1 note (F07-1, tracked in `findings.json`). Structured reply: `handoffs/07-codex-wave21-accept-zai.reply.json`.
Raw event stream: `handoffs/07-codex-wave21-accept-zai.events.jsonl`.
Verbatim reply follows.

---

## Q1 — Ruling on every open finding

**Fixed in code at 2de15e9:**

- **F02-1 / F03-1** (inactive record during the commit window): records now carry the writer's `pid`+`start_time`, and `Test-PendingActive` treats a live writer as ACTIVE in every state, `reserved` included (common.ps1:5140-5154); a member rewrites its record with its own pid as its first act (codex-consult.ps1:858-893) and re-checks its parent before `launching` (2321-2326). The PARENT harness case kills the panel run mid-panel and asserts the next single run is refused by the live members' records (harness-panel.ps1:460-478).
- **F02-3 / F03-7** (multiple leftovers; abandoned `reserved` records): `Get-NextNumbers` takes an array of leftovers with per-record `Recovered` (common.ps1:758-818); `Get-PendingPaths`/`Read-TaskPendingRecords` enumerate every record (4793-4824); the single run (codex-consult.ps1:1853-1951) and the panel parent (1128-1140, 1210-1222) consume them all; the parent removes records of members it never launched or that stayed `reserved` (1296-1310).
- **F02-4 / F04-2** (self-contradictory give-up): the give-up path touches no store — record stays `committing` naming the kept reply files, exit 1, "commit blocked" (codex-consult.ps1:2869-2893); BLOCKED harness case covers members, a single run and `codex-findings` (harness-panel.ps1:532-560).
- **F02-5 / F03-3** (health ordering): `finished_at` recorded at commit (codex-consult.ps1:3101); `Get-EndpointHealth` orders by completion, older entries by `when`+`wall_seconds`, ties by n (common.ps1:3703-3748); unit case hA/hB/hC is exactly the F03-3 scenario (harness-panel.ps1:256-259).
- **F03-2 / F04-5** (name rule takes a sibling for an orphan): panel member records never use the machine-wide name scan (common.ps1:5184-5212); unit case with a live codex-lookalike (harness-panel.ps1:270-277).
- **F03-4 / F04-8** (endpoint key, not a count): `Get-PanelPlan` groups labels by shared fingerprint (all agy labels share one), a merged group takes the smallest limit, roster `parallel` validated ≥1 (common.ps1:4187-4249, 3945-3956); `-PanelConcurrency` caps on top (validated, 705-710); ENDPOINT harness case asserts ZAI members serialize while mimo overlaps.
- **F03-5a/b**: `.consult.write.lock` is an OS-held handle with backoff retry (common.ps1:4654-4705; killed holder releases it — unit case 294-310); the member proof is the per-member record, not the lock file (codex-consult.ps1:858-893).
- **F03-6** (render vs committed store): ingest runs on the fresh store inside the lock and the handoff is rendered from that ingest (codex-consult.ps1:2894-2919, 3013-3018).
- **F03-9 / F04-7** (order invariant): `Add-LedgerEntry` inserts by n (common.ps1:4762-4775), findings stay in id order (1417-1431), documented (README:355) and asserted with the slowest-member-first case (harness-panel.ps1:366).
- **F03-10** (fakes): per-model delay and reply maps for fake-codex3, delay map for fake-agy, sharing-violation retries for shared log/pid files (fake-codex3.ps1:25-46, 126-131; fake-agy.ps1:48-50, 104-114).
- **F04-1** (atomic-write temp files): `Get-PanelIgnorePrefixes` ignores each path's dot-temp variant (common.ps1:4257-4264), applied at codex-consult.ps1:2306-2310; AGY harness case has a codex sibling committing during the agy member's run.
- **F04-3** (every writer re-reads): one commit routine — members/single runs (codex-consult.ps1:2873) and `codex-findings` -Status/-Rate both go through `Enter-StoreCommit` (codex-findings.ps1:369-377, 442-460).
- **F04-4** (record lifecycle holes): both windows closed by the writer-liveness rule plus the record rewrite and the pre-launch parent re-check (locations above).
- **F04-6** (guard arithmetic): guard = timeout + 60 s write lock + 120 s slack + repair/denial budgets when enabled (codex-consult.ps1:1157-1163); GUARD harness case.

**Accepted limitations per the decisions (documented):**

- **F02-2** (cross-task agy failures): D7 keeps the whole-collab scope; documented at README:1205 and CHANGELOG:229-230 ("run nothing else beside a panel with agy members").
- **F03-8** (task lock for the whole panel): D12; documented at README:1168, CHANGELOG:152.
- **F03-11** (ORPHAN on a kill inside the commit): D4 accepts the two-file window; now covered by the ORPHAN harness case (562-576), which also asserts the write lock is released by the kill.

## Q2 — New defects

I hunted the concurrency, recovery, commit, plan, proof, ignore-list, `codex-findings` and test paths and found no new blocker or major. Lock ordering is consistent (task→write only; members take write only; the parent task only), so no deadlock; numbering cannot collide (member numbers are allocated under the parent's lock past every on-disk artifact and every enumerated record); the summary and `Find-PanelEntry` read only after a member exits. One note-level residual, newly visible in code and declared by the implementer but not in D1-D13, is filed as finding #1: if the parent dies in the milliseconds between a member's parent check and its record rewrite, a new run may consume that record and briefly run beside the member — stores stay safe under the write lock, numbers stay distinct, and the member still stops before launching anything if its parent is gone (2321-2326).

**Verified:** all code locations above, read at 2de15e9 (panel parent 1074-1402, member proof 658-709/858-893, run/commit 1800-1990/2297-2331/2857-3214, common 758-818/3687-3760/4187-4284/4587-4900/5100-5230, codex-findings diff, fakes diff, harness-panel). **Inferred, not run:** the harness suite's green claim (read-only consultation — see RC1) and real-CLI concurrency behaviour.

## Q3 — Verdict

**ACCEPT.** Every listed finding is fixed or an explicitly decided, documented limitation; the new code implements D1-D13 faithfully, and the one new residual (finding #1) is narrow, data-safe and already guarded. No blocker or major remains.

---

### Findings

- **F07-1** [note] `plugins/codex-consult/scripts/codex-consult.ps1:881`, `plugins/codex-consult/scripts/codex-consult.ps1:888`, `plugins/codex-consult/scripts/codex-consult-common.ps1:5146` - Residual TOCTOU (declared by the implementer, not named in D1-D13): if the panel parent dies in the window between a member's parent-liveness check (881-883) and its record rewrite (888-891), the record still names the dead parent as writer and reads inactive, so a new run may consume it and start while the member is still in preflight; the member then recreates the record and runs beside the new run with distinct n/NN. Stores remain consistent (both commit via the re-read+re-apply write lock), and the member still refuses to launch anything if the parent is gone (codex-consult.ps1:2321-2326), so nothing is started twice and no numbers collide. Trigger: Parent is killed exactly between the member's Test-PidAlive check and its Write-PendingFile rewrite; a new single run starts in that window. Evidence: read-code: The proof (record match + parent alive) and the rewrite are two steps; nothing holds a lock between them (members take no task lock).; read-code: Activity by writer pid+start time only applies once the record names the member; before the rewrite the writer is the (dead) parent.; read-code: The implementer declared this exact residual under 'Residuals'. Verify: Kill the parent between the member's check and rewrite (instrument the gap with a delay in a fork), start a single run, and confirm both runs commit with distinct n/NN and neither store loses an entry. Remedy: Accept and document it in README alongside the other residuals (it is data-safe and self-limiting); optionally have the member re-verify the record still names itself as writer right before writing `launching`, refusing if a new run consumed it.

### Prior findings

- F02-1 - fixed - Writer pid+start_time liveness makes a member record active through its whole life (common.ps1:5140-5154; member rewrite codex-consult.ps1:858-893); PARENT harness case proves a new run is refused while orphaned members commit (harness-panel.ps1:460-478).
- F02-2 - fixed - Accepted limitation per D7: whole-collab scope stays; documented README:1205, CHANGELOG:229-230.
- F02-3 - fixed - Get-NextNumbers takes a leftover array with per-record Recovered (common.ps1:758-818); every reader enumerates records (4793-4824).
- F02-4 - fixed - D3 give-up path touches no store, keeps the `committing` record naming the reply files (codex-consult.ps1:2869-2893); BLOCKED harness case.
- F02-5 - fixed - Health orders by finished_at with ties by n (common.ps1:3703-3748); unit case harness-panel.ps1:256-259.
- F03-1 - fixed - Same mechanism as F02-1; additionally every reader skips past member records' n/NN, so no NN reuse.
- F03-2 - fixed - Panel records never use the machine-wide name scan (common.ps1:5184-5212); unit case 270-277.
- F03-3 - fixed - D9 finished_at (codex-consult.ps1:3101; common.ps1:3703-3748); the hA/hB/hC unit case is exactly this scenario.
- F03-4 - fixed - Get-PanelPlan endpoint groups, merged fingerprints, roster `parallel`, -PanelConcurrency cap (common.ps1:4187-4249, 3945-3956); ENDPOINT harness case.
- F03-5 - fixed - (a) Enter-WriteLock is an OS-held handle, killed holder releases it (common.ps1:4654-4705, unit case 294-310); (b) member proof is the per-member record, not the lock file (codex-consult.ps1:858-893).
- F03-6 - fixed - Ingest and render both happen inside the lock on the fresh store (codex-consult.ps1:2894-2919, 3013-3018).
- F03-7 - fixed - Parent cleanup removes never-launched/`reserved` records (codex-consult.ps1:1296-1310); all readers enumerate them, so NNs are never retaken.
- F03-8 - fixed - Accepted limitation per D12; documented README:1168, CHANGELOG:152.
- F03-9 - fixed - D10: consults sorted by n via Add-LedgerEntry (common.ps1:4762-4775), Select-ParentThread unchanged, documented and harness-asserted (harness-panel.ps1:366).
- F03-10 - fixed - Per-model delay/reply maps in fake-codex3, delay map in fake-agy, shared-file write retries.
- F03-11 - fixed - Accepted per D4; ORPHAN harness case kills inside the commit and asserts the flag, the kept record and the released write lock (harness-panel.ps1:562-576).
- F04-1 - fixed - Get-PanelIgnorePrefixes covers the dot-prefixed temp variants of stores and sibling handoffs (common.ps1:4257-4264).
- F04-2 - fixed - Same as F02-4.
- F04-3 - fixed - Enter-StoreCommit is the one writer path for members, single runs and codex-findings -Status/-Rate (common.ps1:4716-4756; codex-findings.ps1:369-377, 442-460).
- F04-4 - fixed - Both windows closed: record rewrite with own pid (858-893), writer liveness (common.ps1:5140-5154), pre-launch parent re-check (codex-consult.ps1:2321-2326).
- F04-5 - fixed - Panel records: recorded pids + descendants of the writer only (common.ps1:5184-5212); non-panel records intentionally keep the old rules.
- F04-6 - fixed - Guard computed from the member's own budgets incl. 60 s write lock + 120 s slack (codex-consult.ps1:1157-1163); GUARD harness case.
- F04-7 - fixed - Sort-by-n mandated and implemented (common.ps1:4762-4775, 1417-1431); harness asserts order with out-of-order finishing.
- F04-8 - fixed - D8 endpoint groups serialize same-plan members (common.ps1:4187-4249); later members' preflights see earlier members' committed failures.

## Verdict: ACCEPT

All 24 open findings are fixed in code with tests or accepted/documented per decisions D1-D13, and the new-defect hunt found no blocker or major — only one narrow, data-safe, declared TOCTOU residual filed as a note.

### Blockers

_(none)_

### Unproven scenarios

- The full test suite (48 harness-panel assertions plus the older harnesses) is green — claimed by the implementer, not run by this read-only review (RC1).
- Real-CLI behaviour of several concurrent codex launcher shims and two agy processes on one machine and one sign-in (fakes only in tests).
- Non-Windows behaviour of member-record recovery (no ppid rule there; declared deviation 6) — not exercised on this Windows machine.
- A member spec approaching the 32767-character command-line limit on a very long prompt (declared residual).

### First-run checklist (observable)

- [ ] Panel summary shows a wall clock strictly below the sum of the members' wall_seconds, with one progress line per member in finish order and full member output in roster order.
- [ ] Every member's ledger entry carries the same panel id, its roster position, panel.concurrency and per-label limits, and consults stays sorted by n with handoffs NN in roster order.
- [ ] findings.json contains every member's F<NN>-k ids in id order, and any reviewer_checks on pre-panel findings name each member's own consult n (no lost update).
- [ ] After exit 0, no .consult.pending*.json remains in the task directory and neither .consult.lock nor .consult.write.lock is held (files exist, handles free).
- [ ] Any agy member reports 'usable reply' — no spurious 'the collab directory changed' from siblings' commits; a deliberately blocked commit shows 'commit blocked' with its record in state committing and the reply files kept.
