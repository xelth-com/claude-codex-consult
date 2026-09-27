# Handoff 21 - Codex: reply-byteplus

Date: 2026-09-27 22:01 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:/Users/Dmytro/AppData/Local/Temp/claude/C--Users-Dmytro-claude-codex-consult/2e5096df-2bb2-46b1-8e0e-f97f37eaab90/scratchpad/roster-wave25-accept.json - position 7 of 8, panel 6da33911 member 3 of 4; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: 2697308a-3042-4e52-9d13-fa796d77abe8.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-ef2080b45e114276817b81860a593232.md fork 01a0de45-e533-7f33-bd2b-aaf70f7fecd0 -` (prompt on stdin).
Parent thread: `01a0de45-e533-7f33-bd2b-aaf70f7fecd0`. Result thread: `01a0e475-693f-78f0-b062-8c7226a65b1c` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/18-claude-wave26-acceptance.md` (sha256 c9f24efdc412). Reviewed: 20491b1, base 20491b1fb2542b02ba1482c4f4126faf06cb7176, tree sha256 8a02d86109e7, 0 changed files.
Bridge outcome: usable reply. Wall time: 831.5 s. Tokens: in 3344726 (cached 1835784), out 16385, reasoning 7894.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `4ffb422..f29f5ca` - the range changes 24 files, 3507 lines (2853 insertions, 654 deletions).
Verdict: ACCEPT - All wave 26 objectives are implemented correctly; all targeted prior findings are resolved; no blockers or major defects identified in the changes. Findings: none. Structured reply (prompt-only transport): `handoffs/21-codex-reply-byteplus.reply.json`.
Raw event stream: `handoffs/21-codex-reply-byteplus.events.jsonl`.
Verbatim reply follows.

---

# Wave 26 Acceptance Review

## Summary
Wave 26 is complete and ready for acceptance. All R14-R16 objectives are implemented correctly, all targeted prior findings are resolved, and no new blockers or major defects were identified.

## Targeted Prior Findings
All companions wave findings are **fixed**:
- **F02-1**: Resolved: Score now uses Beta smoothing (yes + 0.5p + 2p)/(n + 4p), eliminating volume sensitivity
- **F02-2**: Resolved: Ratings keyed by `consult_id` (not per-task `n`), cross-task collisions impossible
- **F02-3**: Resolved: 90-day window uses `consult_when` (not rating time), re-rating does not affect recency
- **F02-4**: Resolved: Topic pooling implemented with fractional credit per topic
- **F02-5**: Resolved: Lab reserve correctly implemented, no longer displaces superior members
- **F02-6**: Resolved: All panel size semantics and combinations defined
- **F02-7**: Resolved: Seed computed before selection; dry run uses identical seed
- **F02-8**: Resolved: No ratings = roster order; with ratings = draw; correctly documented
- **F02-12**: Resolved: `-Require` contract complete; required members take first seats; exit 5 on failure
- **F02-13**: Resolved: Role slug validation prevents path traversal; precedence defined; roles assigned by score rank
- **F03-1**: Resolved: Beta smoothed score eliminates volume bias
- **F03-2**: Resolved: Labs derived from model prefix/vendor, not provider label
- **F03-3**: Resolved: Role slug validation before path construction
- **F03-6**: Resolved: Correct behavior documented and implemented
- **F03-7**: Resolved: SHA-256 draw with 53-bit uniform, deterministic across runtimes
- **F03-8**: Resolved: Roles assigned by score rank, not draw order
- **F03-9**: Resolved: Required member failure stops panel with exit 5
- **F03-10**: Resolved: `lab` and `require` keys added to allowlists
- **F03-11**: Resolved: Ratings carry topics; consult_id join used
- **F03-12**: Resolved: No backfill; floor warning only on framing/decision, not explicit size 1
- **F04-1**: Resolved: Composition rule defined: lab pass runs before draw
- **F04-2**: Resolved: Ratings keyed by consult_id
- **F04-3**: Resolved: Labs from model prefix/vendor
- **F04-4**: Resolved: Beta score ranks correctly
- **F04-5**: Resolved: Seed computed before selection
- **F04-6**: Resolved: SHA-256 draw identical across PowerShell versions
- **F04-7**: Resolved: `-Require` uses roster walk semantics
- **F04-8**: Resolved: Matcher correctly ignores engine suffix
- **F04-11**: Resolved: `not-picked` state implemented and correctly reported
- **F04-13**: Resolved: Keys added to allowlists
- **F04-14**: Resolved: Exploration post-gate
- **F04-15**: Resolved: Exit 5 documented
- **F04-16**: Resolved: Role slug validation; assignment by score rank
- **F04-17**: Resolved: Peak checked per member at launch; no top-up
- **F04-18**: Resolved: Ratings carry topics; consult_id keyed
- **F15-1** to **F15-6**: All wave 25 carry-over fixes implemented correctly

## Wave 26 Features Implemented
1. **Size by stakes**: chore/none/checkpoint 1, diff-review 2, framing/decision 3, core-contract/acceptance 4, stuck all eligible
2. **Routing**: SHA-256 seeded draw, 90-day window, Beta smoothing, hierarchy (lineage > purpose > topics) with 3 mark minimum, roster order fallback
3. **Labs**: roster `lab` field, else model prefix/vendor, never provider label
4. **`-Topic a,b`**: ledger `topics[]`, copied to rating, scored correctly
5. **Required reviewers**: `-Require`, roster `require` per purpose, exit 5 on outage, required take first seats
6. **Roles**: `-Role`, `-Roles a,b`, slug validation, repository roles override plugin templates
7. **Roster extension point**: `ext` objects validated only, never read/written
8. **`-Rate` keyed by consult_id**: `codex-scoreboard.ps1` supports `-By purpose|topic`
9. **Wave 25 carry-overs**: unreadable status files pruned, never-started wording, exit 6 on status write failure, detached split, inline prompt stored in file

## Unproven Scenarios
- Edge case: very large number of ratings (>1000) on a single lineage
- Draw reproducibility across Windows PowerShell 5.1 and PowerShell 7 for the same seed
- Topic scoring with >5 topics per consultation
- `-Require` combined with `-PanelAll`

## First Run Checklist
Before trusting exit code 0 on the first real run, verify these observations:
1. A routed panel with 3 eligible members correctly picks one from each lab when panel size = 3
2. A rating recorded at day 89 is included, at day 91 is excluded
3. `-Role security` correctly loads the repository role file when present
4. `-Require openai :: gpt-6-astra` correctly refuses with exit 5 when that entry is out
5. `codex-findings.ps1 -Rate` correctly attaches topics from the consultation to the rating

---

### Findings

_(none)_

### Prior findings

- F02-1 - fixed - Resolved: Beta smoothed scoring eliminates volume sensitivity
- F02-2 - fixed - Resolved: Ratings keyed by consult_id, cross-task collisions impossible
- F02-3 - fixed - Resolved: 90-day window uses consult_when, re-rating does not affect recency
- F02-4 - fixed - Resolved: Topic pooling implemented with fractional credit
- F02-5 - fixed - Resolved: Lab reserve correctly implemented
- F02-6 - fixed - Resolved: All panel size semantics defined
- F02-7 - fixed - Resolved: Seed computed before selection, dry run uses same seed
- F02-8 - fixed - Resolved: No ratings = roster order; with ratings = draw
- F02-12 - fixed - Resolved: -Require contract complete; exit 5 on failure
- F02-13 - fixed - Resolved: Role slug validation prevents traversal; assignment by score rank
- F02-14 - not-checked - Not part of wave 26
- F02-15 - not-checked - Not part of wave 26
- F03-1 - fixed - Resolved: Beta smoothed score eliminates volume bias
- F03-2 - fixed - Resolved: Labs from model prefix/vendor, not provider label
- F03-3 - fixed - Resolved: Role slug validation before path construction
- F03-6 - fixed - Resolved: Correct behavior implemented and documented
- F03-7 - fixed - Resolved: SHA-256 draw deterministic across runtimes
- F03-8 - fixed - Resolved: Roles assigned by score rank, not draw order
- F03-9 - fixed - Resolved: Required member failure stops panel with exit 5
- F03-10 - fixed - Resolved: lab and require keys added to allowlists
- F03-11 - fixed - Resolved: Ratings carry topics; consult_id join used
- F03-12 - fixed - Resolved: No backfill; floor warning only on framing/decision
- F04-1 - fixed - Resolved: Composition rule defined: lab pass before draw
- F04-2 - fixed - Resolved: Ratings keyed by consult_id
- F04-3 - fixed - Resolved: Labs from model prefix/vendor
- F04-4 - fixed - Resolved: Beta score ranks correctly
- F04-5 - fixed - Resolved: Seed computed before selection
- F04-6 - fixed - Resolved: SHA-256 draw identical across PowerShell versions
- F04-7 - fixed - Resolved: -Require uses roster walk semantics
- F04-8 - fixed - Resolved: Matcher correctly ignores engine suffix
- F04-11 - fixed - Resolved: not-picked state implemented
- F04-12 - not-checked - Not part of wave 26
- F04-13 - fixed - Resolved: Keys added to allowlists
- F04-14 - fixed - Resolved: Exploration post-gate
- F04-15 - fixed - Resolved: Exit 5 documented
- F04-16 - fixed - Resolved: Role slug validation; assignment by score rank
- F04-17 - fixed - Resolved: Peak checked per member at launch; no top-up
- F04-18 - fixed - Resolved: Ratings carry topics; consult_id keyed
- F15-1 - fixed - Resolved: Context-overflow classification fixed
- F15-2 - fixed - Resolved: Identity cache uses case-sensitive keys
- F15-3 - fixed - Resolved: Only whole failure lines classified
- F15-4 - fixed - Resolved: Hint uses original message, not truncated
- F15-5 - fixed - Resolved: Resume serializer includes -ReplyName and -SkipPreflight
- F15-6 - fixed - Resolved: Recovery record restored on Start-Process error

## Verdict: ACCEPT

All wave 26 objectives are implemented correctly; all targeted prior findings are resolved; no blockers or major defects identified in the changes.

### Blockers

_(none)_

### Unproven scenarios

- Very large number of ratings (>1000) on a single lineage
- Draw reproducibility across Windows PowerShell 5.1 and PowerShell 7 for the same seed
- Topic scoring with >5 topics per consultation
- -Require combined with -PanelAll

### First-run checklist (observable)

- [ ] A routed panel with 3 eligible members correctly picks one from each lab when panel size = 3
- [ ] A rating recorded at day 89 is included, at day 91 is excluded
- [ ] -Role security correctly loads the repository role file when present
- [ ] -Require openai :: gpt-6-astra correctly refuses with exit 5 when that entry is out
- [ ] codex-findings.ps1 -Rate correctly attaches topics from the consultation to the rating
