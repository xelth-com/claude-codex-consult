# Handoff 13 - Meta Muse (muse): wave24-accept-meta

Date: 2026-09-26 17:12 local. Author: Meta Muse (muse) (model muse-spark-1.3-contributor, effort high), muse-cli 1.4.0-R4161.1.
Reviewer: meta :: muse-spark-1.3-contributor [muse] (provider from roster, model from roster; engine muse (C:\Users\Dmytro\AppData\Local\Programs\muse\muse.cmd); provider fingerprint 1c6f62bb040d; harness muse-cli 1.4.0-R4161.1).
Preflight: ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth).
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave23-accept.json - position 10 of 10, panel 40ea8da3 member 7 of 7; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping muse-v1, by caps-v1: engine:muse, muse-spark-1.3-contributor; not confirmed by the provider). Consultation id: 572b023a-fa2d-4d93-9b30-54f8d4bab7d1.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads), purpose: acceptance). Argv: `muse exec --json --prompt-file C:\Users\Dmytro\AppData\Local\Temp\codex-consult-prompt-5c9d5e9320fa4387bbc672281d430797.txt --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json --model muse-spark-1.3-contributor --reasoning-effort high --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never` (prompt from a file: --prompt-file).
Parent thread: (none - new thread; no thread of lineage meta :: muse-spark-1.3-contributor [muse] in this task's ledger; other lineage(s): alibaba :: qwen3.8-max, kimi :: k3, mimo :: mimo-v2.6-pro). Result thread: `01a0de46-4549-7962-aaf7-0bbfda6e3bd0` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/06-claude-wave24-acceptance.md` (sha256 e7c48ed71df5). Reviewed: 75cfd47, base 75cfd479f82a76fe01f4b94356af7967add0bb3a, tree sha256 2e28b2f55572, 0 changed files.
Bridge outcome: usable reply. Wall time: 692.3 s. Tokens: not reported by muse.
Engine turns: 1 (each one a Muse Code subscription prompt); MSP schema_version 1.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s.
Verdict: ACCEPT - Wave-24 scope (D14-D17, T1-T3, F15-1) is implemented, documented and harnessed with no remaining blocker or major; the two residuals are minor/note. Findings: 0 blocker, 0 major, 1 minor, 1 note (F13-1..F13-2, tracked in `findings.json`). Structured reply: `handoffs/13-muse-wave24-accept-meta.reply.json`.
WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).
Raw event stream: `handoffs/13-muse-wave24-accept-meta.events.jsonl`.
Verbatim reply follows.

---

## 1. Ruling the open findings

Wave 24's seven are all **fixed** (verified in code at 65f5649):

- **F02-9 / F03-5**: `Get-PreflightVerdict -RosterWalk` refuses quota-without-reset (`common.ps1:5052-61`); both providers row kinds use it (`codex-providers.ps1:305,349`); `-Short`/hook read the walk (`providers.ps1:394-427`, `hook.ps1:55-66`). The explicit single `-Provider` run still warns-and-launches — deliberate, README-documented (`README.md:1038-42`) and harness-pinned (`harness-visibility.ps1:428`), inside D14's enumerated surfaces.
- **F02-10**: the hook reads per-entry `-Short -Json` entries with model/lineage/group (`providers.ps1:411-423`); the text table's ROSTER column lists all positions (440). Residual singular `roster_position` filed as new finding #1.
- **F02-11**: groups computed over ALL entries (`common.ps1:5438-40`) with whole-group outage propagation (5446-52).
- **F03-4**: hook parses `-Short -Json`'s `line`; no verdict regex remains (`hook.ps1:59-66`).
- **F04-9**: `Select-PanelMembers` has `-NoNetwork` (5160) and judges every entry (5178-86).
- **F04-10**: nothing cut (5472); three counts with not-checked named (5505-07); unknown maps to not-checked (5412); local time plus relative hint (5418-20).

All other listed findings are companions-wave scope, not implemented here: **not-checked**, no time spent.

## 2. New defects in what wave 24 built

Read-only review; only two sub-major items (see `findings`): #1 (minor) `-Json` rows report the first roster position per label only; #2 (note) `Test-UsableOutcome` prefix-matches any future `'usable reply (...)'` into usable. Everything else matched the brief: continuation skip rules (`consult.ps1:3002-19`) and fresh billing-guard re-read at every turn launch (666) and pre-launch (2621, F15-1); same-thread resume via mode-agnostic adapters; `provider_failure` computed before the outcome rewrite (3379-90); salvage file, footer resume command and ledger `partial_reply` (3412-56, 3698); per-purpose defaults incl. acceptance 3600 (788-98); `-Range` shell-safe validation (`common.ps1:330-50`) and the 1500-line/2400-s warning (1060); 60-minute rule as Hit+60 with LAST FAILURE fallback (4688, 4725, 4746-49); health-source line (`providers.ps1:435`). The harness covers CONT/CONTAGY/CONTMUSE, QUOTA60, HOOK, DEFAULTS, RANGE — read, not executed.

## 3. Verdict: ACCEPT

No blocker or major remains; D14-D17, T1-T3 and F15-1 are implemented, documented and harnessed. The two residuals are minor/note and need not gate acceptance.

## Requested checks

- RC1: `pwsh -NoProfile -File tests/harness-visibility.ps1 -Only QUOTA60,HOOK` from the repo root (needs shell; test temp dirs are created and removed by the harness). Settles finding-adjacent F02-9/F04-10 behavior. Budget ~10 min.
- RC2: `pwsh -NoProfile -File tests/harness-visibility.ps1 -Only CONT,CONTAGY,CONTMUSE` from the repo root (needs shell; uses fake engines with short sleeps). Settles the continuation/salvage claims end to end. Budget ~20 min.
- RC3: `pwsh -NoProfile -File tests/harness-visibility.ps1 -Only DEFAULTS,RANGE,GUARD,PANEL` from the repo root (needs shell). Settles timeout-default, range-stat and guard-growth claims. Budget ~10 min.
- RC4: in a scratch repo with a seeded quota-without-reset ledger entry, run `codex-providers.ps1 -Short -NoNetwork` and the hook script, then again with the clock +61 min (needs shell, read-only). Settles the exact 60-minute boundary both findings rely on. Budget ~10 min.

---

### Findings

- **F13-1** [minor] `plugins/codex-consult/scripts/codex-providers.ps1:328`, `plugins/codex-consult/scripts/codex-providers.ps1:384` - The machine-readable providers rows (-Json without -Short) report `roster_position` as the FIRST roster position of a provider label only, so a JSON consumer cannot enumerate the entries of a multi-model label; the human-readable table's ROSTER column lists every position. Trigger: A roster with two entries on one provider label (e.g. gemini pro + flash); read `codex-providers.ps1 -Json` and compare `roster_position` with the entry count. Evidence: read-code: Line 314 collects ALL matching positions into $rosterPositions, but line 328 emits only the first ([int]$rosterPositions[0]); the engine-label loop repeats this at line 384, while the text table joins every position at line 440. Verify: Point CODEX_CONSULT_ROSTER at a two-models-one-label roster, run `-Json`, and confirm `roster_position` covers only the first entry while `-Short -Json` entries cover both. Remedy: Emit `roster_positions` (array) alongside `roster_position` (first, for compatibility), or document that per-entry enumeration lives only in `-Short -Json` entries.
- **F13-2** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:4616` - Test-UsableOutcome accepts ANY bridge_outcome with the prefix 'usable reply (' as a usable reply, so any future outcome string with that shape silently inherits health-clearing, RecentUsable sign-in evidence, and scoreboard-usable counting. Trigger: A future code path records an outcome such as 'usable reply (draft)' or 'usable reply (partial)'. Evidence: read-code: The function returns true for exact 'usable reply' or any string starting with 'usable reply ('; today only line 3390 of codex-consult.ps1 produces such a string, and the predicate feeds Get-EndpointHealth (Ok records) and RecentUsable. Verify: Grep producers of outcomes starting with 'usable reply (' and confirm the set is closed to line 3390, or add a unit case asserting 'usable reply (draft)' is not usable. Remedy: Match the two known outcome strings exactly (or centralize an outcome enum) so new suffixed outcomes fail closed.

### Prior findings

- F02-1 - not-checked - Companions wave, not implemented here.
- F02-2 - not-checked - Companions wave, not implemented here.
- F02-3 - not-checked - Companions wave, not implemented here.
- F02-4 - not-checked - Companions wave, not implemented here.
- F02-5 - not-checked - Companions wave, not implemented here.
- F02-6 - not-checked - Companions wave, not implemented here.
- F02-7 - not-checked - Companions wave, not implemented here.
- F02-8 - not-checked - Companions wave, not implemented here.
- F02-9 - fixed - Fixed: walk, rows, -Short and hook all use the -RosterWalk verdict (quota-unknown out for 60 min); the explicit single-run warn-and-launch is a documented, harness-pinned exception (README 1038-42, harness-visibility QUOTA60).
- F02-10 - fixed - Fixed: the hook reads per-entry -Short -Json entries, not label rows; residual singular roster_position in -Json rows filed as new finding #1.
- F02-11 - fixed - Fixed: groups computed over ALL entries with whole-group outage propagation (Get-RosterAvailability).
- F02-12 - not-checked - Companions wave, not implemented here.
- F02-13 - not-checked - Companions wave, not implemented here.
- F02-14 - not-checked - Companions wave, not implemented here.
- F02-15 - not-checked - Companions wave, not implemented here.
- F03-1 - not-checked - Companions wave, not implemented here.
- F03-2 - not-checked - Companions wave, not implemented here.
- F03-3 - not-checked - Companions wave, not implemented here.
- F03-4 - fixed - Fixed: the hook reads the -Short -Json `line`; no verdict-regex parsing remains.
- F03-5 - fixed - Fixed: provider rows now use the roster-walk verdict, so the quota-unknown rule shows on the display surfaces.
- F03-6 - not-checked - Companions wave, not implemented here.
- F03-7 - not-checked - Companions wave, not implemented here.
- F03-8 - not-checked - Companions wave, not implemented here.
- F03-9 - not-checked - Companions wave, not implemented here.
- F03-10 - not-checked - Companions wave, not implemented here.
- F03-11 - not-checked - Companions wave, not implemented here.
- F03-12 - not-checked - Companions wave, not implemented here.
- F04-1 - not-checked - Companions wave, not implemented here.
- F04-2 - not-checked - Companions wave, not implemented here.
- F04-3 - not-checked - Companions wave, not implemented here.
- F04-4 - not-checked - Companions wave, not implemented here.
- F04-5 - not-checked - Companions wave, not implemented here.
- F04-6 - not-checked - Companions wave, not implemented here.
- F04-7 - not-checked - Companions wave, not implemented here.
- F04-8 - not-checked - Companions wave, not implemented here.
- F04-9 - fixed - Fixed: Select-PanelMembers gained -NoNetwork and judges every entry; hook/listing build from the full member list.
- F04-10 - fixed - Fixed: no truncation in the short line, three counts with not-checked named, unknown mapped to not-checked, local times with relative hints.
- F04-11 - not-checked - Companions wave, not implemented here.
- F04-12 - not-checked - Companions wave, not implemented here.
- F04-13 - not-checked - Companions wave, not implemented here.
- F04-14 - not-checked - Companions wave, not implemented here.
- F04-15 - not-checked - Companions wave, not implemented here.
- F04-16 - not-checked - Companions wave, not implemented here.
- F04-17 - not-checked - Companions wave, not implemented here.
- F04-18 - not-checked - Companions wave, not implemented here.

## Verdict: ACCEPT

Wave-24 scope (D14-D17, T1-T3, F15-1) is implemented, documented and harnessed with no remaining blocker or major; the two residuals are minor/note.

**WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).**

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- harness-visibility (UNIT/AVAIL/AGREE/QUOTA60/HOOK/DEFAULTS/RANGE/CONT/CONTAGY/CONTMUSE/PANEL/GUARD) was read but not executed — shell is disabled in this consultation.
- Live timeout-kill wall-clock behavior: kill timing, survivor detection, and continuation latency on a real machine.
- Hook output inside a real Claude Code SessionStart session (only the JSON contract was verified).
- Windows PowerShell 5.1 vs PowerShell 7 parity run of the new harness groups.

### First-run checklist (observable)

- [ ] `-Purpose acceptance -DryRun` prints `timeout : 3600 s (the default of purpose acceptance...)` plus the continuation budget, with `timeout_source: purpose` in the ledger preview.
- [ ] Seeded quota-without-reset: `-Short` prints `out - <label> :: ... (limit hit ..., reset unknown; retry after ...)` with out/not-checked counts; the table row reads `unavailable (...)`; `codex-providers -Provider <label>` exits 2.
- [ ] Same setup at +61 min (or after a later success on the endpoint): the line reads `all N reviewers available`.
- [ ] The listing prints `endpoint health: <collab dir> ... - the ledgers of THIS repository`.
- [ ] A real timeout kill prints `the main turn was killed at ...; one continuation turn on thread ...`; the ledger entry carries `timeout_continue` and `partial_reply`, and the summary shows the `partial :` and `resume :` lines.
- [ ] `-Range HEAD~1..HEAD -DryRun` prints the `range :` line with files/lines; an unknown range is refused with `nothing was started` and no ledger entry.
- [ ] Believe exit code 0 only after the ledger entry (sessions.json) shows the fields above with the expected values.
