# Handoff 25 - Claude (claude): ab-07-claude

Date: 2026-10-08 02:21 local. Author: Claude (claude) (model glm-5.3, effort medium), claude-cli 2.1.293.0.
Reviewer: ZAI-claude :: glm-5.3 [claude] (provider from -Provider, model from roster; engine claude (C:\users\dmytro\.local\bin\claude.exe), endpoint https://api.z.ai/api/anthropic (token from env ZAI_API_KEY); provider fingerprint 944a94557723; harness claude-cli 2.1.293.0).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 11 of 12 for -Provider ZAI-claude (engine, model applied).
Effort: medium sent (requested medium, mapping claude-v1, by caps-v1: engine:claude, any model; not confirmed by the provider). Consultation id: da48d0b1-4e27-4c4b-ab0a-bb66e619107c.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn's init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply), purpose: checkpoint). Argv: `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model glm-5.3 --effort medium --json-schema "{"$schema":"http://json-schema.org/draft-07/schema#","title":"codex-consult reply v1","type":"object","additionalProperties":false,"required":["schema_version","verdict","verdict_reason","reply_markdown","findings","prior_findings","unproven","first_run_checklist"],"properties":{"schema_version":{"type":"string","enum":["1"]},"verdict":{"type":"string","enum":["ACCEPT","HOLD","REJECT","ADVISE"]},"verdict_reason":{"type":"string"},"reply_markdown":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["severity","locations","claim","trigger","evidence","verification","remedy","supersedes"],"properties":{"severity":{"type":"string","enum":["blocker","major","minor","note"]},"locations":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line"],"properties":{"path":{"type":"string"},"line":{"type":["integer","null"]}}}},"claim":{"type":"string"},"trigger":{"type":"string"},"evidence":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["kind","reference","observation"],"properties":{"kind":{"type":"string","enum":["read-code","ran-command","inferred","assumed"]},"reference":{"type":"string"},"observation":{"type":"string"}}}},"verification":{"type":"string"},"remedy":{"type":"string"},"supersedes":{"type":"array","items":{"type":"string"}}}}},"prior_findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["id","status","note"],"properties":{"id":{"type":"string"},"status":{"type":"string","enum":["fixed","still-open","not-checked","unknown-id"]},"note":{"type":"string"}}}},"unproven":{"type":"array","items":{"type":"string"}},"first_run_checklist":{"type":"array","items":{"type":"string"}}}}" --session-id 1de46f1e-6c02-48a8-8c0f-46829529973b` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `1de46f1e-6c02-48a8-8c0f-46829529973b` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/07-claude-ab-wave14-review.md` (sha256 1b05147c21a3). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 150.9 s. Tokens: in 257289 (cached 227840), out 8043, reasoning ?.
Engine turns: 1 (claude -p, auth endpoint; model glm-5.3; init tools Glob, Grep, Read, StructuredOutput; permission denials 0).
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint review of the wave-14 format-repair invariants against the current tree: all three claimed invariants verified in code; only stale counts and two design gaps found. Findings: 0 blocker, 0 major, 2 minor, 2 note (F25-1..F25-4, tracked in `findings.json`). Structured reply: `handoffs/25-claudecode-ab-07-claude.reply.json`.
Raw event stream: `handoffs/25-claudecode-ab-07-claude.events.jsonl`.
Verbatim reply follows.

---

Checkpoint of the wave-14 format-repair invariants against the current tree. Where the brief's file/counts no longer match: `tests/harness-format.ps1` now has **37 Check calls** across CONTR/REPAIR/TWICE/DRIFT/DRIFT5/NONE/PANEL/GATE/ORPHAN, not the brief's "23 cases" (finding #1); base commit `a743d81` predates many later waves, but the repair block, prose gate and drift checks still live where the brief says.

The three CURRENT invariants all hold in the code: repair eligibility at `codex-consult.ps1:5234` requires `-not $parse.Valid`, `bridgeOutcome 'usable reply'`, a non-bridge-bug parse, a thread id with source `events` or `rollout (verified by consultation id)`, and `$repairEnabled` (FormatRetry 1 and `-not $Raw`; chore sets `$Raw = $true` at `codex-consult.ps1:2195`); `ConvertFrom-StructuredReply` leaves `Valid = $true` for a schema-valid object whose verdict fits no purpose (`codex-consult-common.ps1:1382-1393`), so a wrong-verdict object is never repaired; the original prose is written before the repair process exists and named in the pending record.

**Q1.** The blind path: the repaired object's `findings[]` fields. Check 5 only tests whether prose *sentences* >= 60 chars appear in `reply_markdown`; a softened severity (`blocker` -> `major`), a swapped `trigger`/`verification`/`remedy` phrased in < 60-char sentences, or a changed location line `path:123` -> `path:456` pass all six checks untouched. Recommendation: one cheap seventh check is worth it — compare the severity tokens (blocker|major|minor|note) counted in the prose against `findings[].severity` — because severity drives acceptance; everything else should stay under the rule "drift notes are warnings; the coordinator reads the original", which the always-kept `.original.md` makes sound.

**Q2.** The record was flipped to `running` with `child_pid` = the repair pid and `original`/`first_reply` naming the saved prose *before* launch (`codex-consult.ps1:5285-5318`). `Test-PendingActive` (`codex-consult-common.ps1:10254`) then: writer pid gone, and if the orphaned repair codex still runs the next run refuses with "…still running… a usable prose reply of that run exists at <original>; no ledger entry was written for it"; when every pid is gone (descendant scan clean) the record releases and the next run recovers the reservation naming the path. The first reply is **kept** (`.original.md` on disk, plus the raw last message) but never converted — no ledger entry; the ORPHAN checks (harness-format 312-351) pin exactly this.

**Q3.** Wrongly accepted: a long refusal that enumerates its reasons as `1.`, `2.` (>= 40 words) — numbered markers suppress the refusal gate (`common.ps1:1752-1753`), so a repair turn is spent asking a refusing model to convert its refusal. Wrongly rejected: a complete ~90-word answer whose numbered style is unrecognized (e.g. `A1:` or `**Q1** -` without a period) — floors fail, "reply too short", no repair.

**Q4.** ACCEPT for wave 14 as a diff: the invariants hold, no blockers; findings #2/#3 are minor gate/drift gaps, unproven scenarios below.

## Requested checks
- RC1: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-format.ps1` (repo root, read-only): expect 37 PASS lines incl. REPAIR/ORPHAN (finding #1).

---

### Findings

- **F25-1** [minor] `.collab/ab-zai-2026-10-08/handoffs/07-claude-ab-wave14-review.md:29`, `tests/harness-format.ps1` - The brief's 'tests/harness-format.ps1 (23 cases)' is stale: the current harness has 37 Check calls across CONTR/REPAIR/TWICE/DRIFT/DRIFT5/NONE/PANEL/GATE/ORPHAN; the wave-14 substance (repair, gate, drift, orphan handling) is unchanged and still covered. Trigger: Counting Check calls and case names in tests/harness-format.ps1 against the brief's parenthetical. Evidence: read-code: Grep for "Check '" shows 37 checks with case labels CONTR, REPAIR, TWICE, DRIFT, DRIFT5, NONE, PANEL, GATE, ORPHAN; the brief says 23 cases. Verify: Run tests/harness-format.ps1 and count PASS lines (expect 37). Remedy: Update the brief's parenthetical to the current count (or drop the count, as waves keep adding checks - the same staleness as F13-1/F17-2/F19-1).
- **F25-2** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:1793` - The six drift checks cannot see changes confined to findings[] fields: a softened severity (blocker -> major), a replaced remedy/trigger/verification phrased in sentences under 60 characters, or a changed location line all pass undetected, yet the repaired object is ingested. Trigger: A repair turn that converts the prose faithfully into reply_markdown but edits a finding's severity or a short-sentence field. Evidence: read-code: Checks 1-6 cover RC ids, numbered counts, F-ids, a verdict token, >= 60-char prose sentences vs reply_markdown, and (in codex-consult.ps1:5408) the thread id; findings[] fields are only scanned to collect known F-ids, never compared with the prose.; read-code: When no repairProblem, the repaired object is ingested ($parse = $repairParse) regardless of drift notes - warnings only. Verify: In test mode, feed a repair fixture that changes a finding's severity while copying reply_markdown verbatim; expect format_retry.drift to be empty. Remedy: Add a seventh cheap check: count severity tokens (blocker|major|minor|note) in the prose and compare with findings[].severity counts; keep it a warning like the other six.
- **F25-3** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:1752` - Get-ProseGate wrongly accepts a long refusal that lists its reasons in a numbered style ('1.', '2.') or contains any marker word ('verdict', an F-id, RC<n>): markers suppress the refusal test and the word floors pass, so a repair turn is spent trying to convert a refusal. Trigger: A reviewer refuses with >= 40 words and enumerated reasons, or >= 120 words containing the word 'verdict' anywhere. Evidence: read-code: ($startsRefusal -or $hits -ge 2) -and -not $markers gates the refusal; $markers is true whenever numbered > 0 or the text mentions verdict/F-id/RC, so a numbered refusal bypasses it and then satisfies the floors. Verify: Call Get-ProseGate on a 60-word refusal that starts 'I cannot...' and continues '1. ... 2. ...'; expect Substantive true despite Reason-worthy refusal phrasing. Remedy: Require the refusal lead to also be absent (or keep the refusal verdict when $startsRefusal and numbered < 1), or at minimum treat 'starts with refusal phrasing' as not substantive regardless of markers except an explicit verdict token.
- **F25-4** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:1738` - Get-ProseGate wrongly rejects a short but complete answer whose numbered style is not one of the recognized forms (e.g. 'A1:', 'Answer 1:', '**Q1** -' without a period): numbered = 0 and words < 120 yield 'reply too short', so no repair turn runs and the usable prose is never converted. Trigger: A complete 80-100 word prose reply that answers every question but uses an unrecognized numbering style. Evidence: read-code: NumberedAnswerRe matches only Q<n>.[:], <n>[.)], **<n>.**, ### Q<n> styles; with no match the sole substantive path is words >= 120. Verify: Call Get-ProseGate on a 90-word reply headed 'A1: ... A2: ...'; expect Substantive false with 'reply too short (90 words)'. Remedy: Acceptable as-is (the first reply is kept and named in the pending record); optionally add 'A<n>:' / 'Answer <n>:' to NumberedAnswerRe.

### Prior findings

- F13-1 - not-checked - Harness-count claim; not re-verified in this checkpoint (out of this brief's scope).
- F13-2 - not-checked - Spool 'stayed busy' wording; not re-verified.
- F14-1 - not-checked - Flush deadline wording; not re-verified.
- F15-1 - not-checked - Stall-cut vs D3 invariant; not re-verified.
- F16-1 - not-checked - Kick acknowledgement wording; not re-verified.
- F16-2 - not-checked - Health warning string; not re-verified.
- F16-3 - not-checked - Wait-EngineProcess comment contradiction; not re-verified.
- F17-1 - not-checked - D4/D7 wording vs wave 28e; not re-verified.
- F17-2 - not-checked - tests/README.md 'twentieth harness'; not re-verified.
- F19-1 - not-checked - harness-visibility check count; not re-verified.
- F21-1 - not-checked - unknown failure class ignored by health; not re-verified.
- F21-2 - not-checked - Usage-limit 'warning only' staleness; not re-verified.
- F21-3 - not-checked - Usage-limit scan scope; not re-verified.
- F22-1 - not-checked - Q2 classifier description staleness; not re-verified.
- F23-1 - not-checked - harness-detach check count; not re-verified.
- F23-2 - not-checked - -Prune superset behaviour; not re-verified.
- F24-1 - not-checked - Prompt-file transport staleness; not re-verified.

## Verdict: ADVISE

Checkpoint review of the wave-14 format-repair invariants against the current tree: all three claimed invariants verified in code; only stale counts and two design gaps found.

### Blockers

_(none)_

### Unproven scenarios

- No engine or harness was run (read-only consultation): the 37 harness-format checks are asserted from code reading only (RC1 settles it).
- Live behavior of the repair on this route (GLM) - Q4's first-turn contract is untested here; the checklist covers it.
- The Q1 drift-blind severity-softening scenario is deduced from the checks' code, not demonstrated with a fixture.

### First-run checklist (observable)

- [ ] This consultation's ledger entry: structured true on the first turn with format_retry null - that is the observable success of the wave-14 contract on this route.
- [ ] If format_retry.attempted is true, the first-turn contract still failed on this route: read format_retry.reason and drift, and the .original.md must exist and match the first reply byte for byte.
- [ ] handoff markdown: when a repair ran, the 'Original reply (prose, before format repair)' section appears after the structured section; when none ran, it must be absent.
