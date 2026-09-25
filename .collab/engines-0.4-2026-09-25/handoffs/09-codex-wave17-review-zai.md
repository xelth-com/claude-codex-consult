# Handoff 09 - Codex: wave17-review-zai

Date: 2026-09-25 13:52 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-0.4.json - position 2 of 5, panel 2d8d5f25 member 1 of 3; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.1-pro-high [agy] (weighty reviewer; purpose diff-review is light (use -PanelAll)).
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 7a1bdfd4-7baf-4dcc-b2af-faa26389f187.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8f945dd0bcf942d79c623f7945d2b014.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a0d7c3-343a-7510-801c-e5a7912799a5 -` (prompt on stdin).
Parent thread: `01a0d7c3-343a-7510-801c-e5a7912799a5`. Result thread: `01a0d868-c704-7fa1-b6e4-aa4c71307931` (source: events).
Brief: `.collab/engines-0.4-2026-09-25/handoffs/08-claude-wave17-review.md` (sha256 91c25c225d47). Reviewed: a320844 + uncommitted, base a320844989f75989a670c3d0c292929999a4a11d, tree sha256 a3cf3dbbd383, 23 changed files.
Bridge outcome: usable reply. Wall time: 672.7 s. Tokens: in 9654190 (cached 9253888), out 40531, reasoning 23193.
Verdict: ACCEPT - All ten prior findings are verifiably implemented, the parser was confirmed correct against both real agy streams, the codex path is unchanged, and the remaining tree-check blind spots are a major follow-up, not an acceptance blocker. Findings: 0 blocker, 1 major, 1 minor, 1 note (F09-1..F09-3, tracked in `findings.json`). Structured reply: `handoffs/09-codex-wave17-review-zai.reply.json`.
Raw event stream: `handoffs/09-codex-wave17-review-zai.events.jsonl`.
Verbatim reply follows.

---

## Q1 — parser and failure rules

No misjudgment on the real streams. I executed `Read-AgyEvents` + `Get-AgyTurnOutcome` against both real files: handoff 04 (304 lines) and handoff 07 each yield exactly one `result`, `init` id == `result` id, SUCCESS, structured output, outcome "usable reply" (04: fdc21ce2…, 07: 53705f4d…). The parser reads the id from the correct places (init top-level, nested `result`). A killed run (04's original 3-line stream) would fail with the init id as candidate only — correct. Residual edge, benign: a truncated line flushed mid-stream (not at EOF) reports "malformed event stream" (transport) instead of the kill; both fail closed.

## Q2 — denial retry

Trigger is tight: `$DenialRetry -eq 1 -and $agyTurn.DeniedEmpty -and $threadId -and -not $treeProblem`; `DeniedEmpty` is set only in the empty-reply+denial branch, so quota (status ERROR), tree failures and non-empty replies cannot fire it; one retry maximum (parameter validated 0|1; a denied retry fails, no loop; at most main + retry + repair turns). The retry prompt is contract + denial sentence + field meanings + consultation id, never the brief (test-asserted). Provenance is visible: the empty first turn stays in the main events file, `denial_retry.reason` carries the stderr line, `warnings[]` names it, the handoff names the retry's events file. Gap: the ledger row itself names only the main stream (finding #2).

## Q3 — tree check

It compares the git-status manifest (tracked + untracked, NOT ignored; the collab root is excluded), the task's handoffs directory snapshot, and the brief/artifact hashes — re-run after any retry/repair turn, and it fails the run before ingestion. Blind spots: gitignored paths, the task store outside handoffs (findings.json, sessions.json, state.md), other tasks' dirs, and anything outside the repo (finding #1). Failing is the right severity — attribution is impossible — but the text says "the reviewer changed" when anyone's edit fires it, and a coordinator adding the next brief during a long run fails a valid reply (README documents this; finding #3).

## Q4 — codex regression

Codex argv, prompt (the Tools line is `-not $isCodex`), stdin, thread/usage parse, harness string and handoff header are unchanged; I found no codex ledger change beyond `reviewer.engine`, `warnings`, `denial_retry`. Codex-visible elsewhere: providers JSON rows all gain `engine`; `codex-providers.ps1` without `-NoNetwork` now makes one `agy models` call when an agy roster entry exists (documented); pending records gain `engine`/`events`. Harness counts updated, not re-run by me.

## Q5 — hook and listing

Hook line: `gemini not checked (launcher present)` (verdict unknown, launcher missing still "unavailable"); it runs `-NoNetwork`, never touches the network. Providers without `-NoNetwork`: one `agy models` (~2 s, 15 s cap, cached per listing). The roster walk under `-NoNetwork` gets State unknown → refused, so the hook can never select an agy entry it did not check. Edge: with no codex CLI the hook still prints the codex-not-found line only.

## Q6 — roster and lineage

Two `gemini` agy entries (flash always + pro weighty) are legal (duplicate rule is provider+model). `-Provider gemini` without `-Model` takes the first entry in roster order — flash; the weighty model needs `-Model` (documented). `-Panel` light purpose: flash runs, pro skipped; weighty purpose: both. `-Thread` of a gemini thread fixes engine+provider+model and picks the matching entry; engine mismatch is refused. One subtlety: a solo walk past a quota-blocked flash falls through to the weighty pro entry — same as 0.3.0 codex behavior, worth a doc line.

## Q7 — docs

Yes: install (winget/installer, PATH, `-EngineExe`/env), user-performed sign-in, `agy models` check with expected output, roster snippets including the weighty pattern, cost notes (13-25k CLI tokens, 54k resume replay), F11 (denial retry) and F12 (tree check, "do not edit during a run") caveats, recovery listing. No guessing needed.

## Q8 — verdict

**ACCEPT** as the 0.4.0 candidate: every listed prior finding is verifiably implemented, the real streams parse correctly, and the codex path is untouched. First live check: reproduce F11 through the new bridge (denial → retry on the same conversation id, `denial_retry` ledger record, retry events file kept), then one real resume of handoff 07's conversation.

---

### Findings

- **F09-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:491`, `plugins/codex-consult/scripts/codex-consult-common.ps1:620`, `plugins/codex-consult/scripts/codex-consult.ps1:559`, `README.md:1213` - The read-only tree check has blind spots that the 'enforced by evidence' claim and the README wording ('tracked or untracked files') do not cover: gitignored files are invisible to `git status --porcelain=v1 -uall` (the code's own comment at line 465 admits this), the task store outside the handoffs directory (findings.json, sessions.json, state.md) is excluded from the tree fingerprint as collab root and not in the handoffs snapshot, and writes outside the repository are undetectable — so a writing reviewer can defeat the check by writing to an ignored path or tamper with the findings/sessions stores without failing the run. Trigger: During an agy consultation, the reviewer (or a tool it calls) writes to a .gitignored path such as a build output, or edits .collab/<task>/findings.json or sessions.json. Evidence: read-code: The manifest is built from git status porcelain v1 -uall (no --ignored; the comment says ignored files are not listed) with the collab root excluded; Get-DirectorySnapshot hashes only files directly in the handoffs directory.; read-code: Get-EngineTreeProblem compares only the manifest, the handoffs snapshot, the brief and artifact hashes. Verify: In a fake-agy run, write once to a .gitignored path and once to the task's findings.json during the turn; assert that neither produces a treeProblem today. Remedy: Add ignored files to the manifest (git status --ignored=matching, or hash the store files findings.json/sessions.json before and after like the brief), and state the outside-the-repo residual explicitly in the README invariant. Supersedes: F02-3, F05-1.
- **F09-2** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:2150`, `plugins/codex-consult/scripts/codex-consult.ps1:2335`, `plugins/codex-consult/scripts/codex-consult.ps1:2515`, `plugins/codex-consult/scripts/codex-consult.ps1:2589` - The ledger row names only the main event stream: the denial-retry and format-repair event files are recorded in the handoff header ('further turns') and in the transient pending record, but not in sessions.json, so machine readers of the ledger cannot find a retry's provenance without parsing the handoff Markdown. Trigger: A denial-retry or repair turn runs; a coordinator or tool later audits the consultation from sessions.json alone. Evidence: read-code: extraEvents feeds only the handoff header; the ledger entry's events field is the main stream and denial_retry/format_retry records carry no events path. Verify: Inspect a ledger entry produced by the DENIAL harness case; confirm no field names handoffs/NN-agy-*.denial-retry.events.jsonl. Remedy: Add the extra event-stream paths to the ledger entry (e.g. an extra_events array, or an events field inside denial_retry/format_retry).
- **F09-3** [note] `plugins/codex-consult/scripts/codex-consult.ps1:567`, `README.md:1216` - The tree-check failure text attributes any change to 'the reviewer changed the working tree / handoffs', but the check cannot distinguish who changed a file; in the documented judge workflow (preparing the next handoff while a long agy run is in flight) the coordinator's own write fails an otherwise valid reply. Trigger: The coordinator saves a new brief into the task's handoffs directory while an agy consultation is running. Evidence: read-code: The reason strings name the reviewer; the comparison is time-based with no attribution.; read-code: The README warns 'A file changed by YOU during the run fails it too - do not edit the repository while an agy consultation runs', so the behavior is documented, only the wording misattributes. Verify: Add a file to handoffs mid-run via the fake; observe the failure message naming the reviewer. Remedy: Word the failure as 'changed during the run (the reviewer or anyone else)' and keep the README warning; optionally re-check after a short settle delay before failing.

### Prior findings

- F02-1 - fixed - Get-AgyTurnOutcome hard-fails on the not-found warning, a missing or mismatched result id under ExpectThread, and any init/result id mismatch (common.ps1 3190-3279); RESUME tests cover it.
- F02-2 - fixed - Hook runs codex-providers.ps1 -Json -NoNetwork and prints 'gemini not checked (launcher present)'; unknown sign-in refuses the roster walk.
- F02-3 - fixed - The tree check now FAILS an agy run whose tree/handoffs/brief/artifacts changed (class permission), re-run after retry/repair turns; residual blind spots filed as finding #1.
- F02-4 - fixed - Parser reads the init id top-level and the result id nested, requires exactly one result, keeps the init id as thread_candidate on a missing result; verified live on handoffs 04 and 07.
- F02-5 - fixed - permission class added first; RESOURCE_EXHAUSTED/rate_limit_exceeded in quota, PERMISSION_DENIED/UNAUTHENTICATED/'not signed in' in auth, INVALID_ARGUMENT/'invalid model selection' in capability, UNAVAILABLE/DEADLINE_EXCEEDED in transport; 'retry in 32s', Go durations and gRPC retryDelay parsed.
- F02-6 - fixed - Engine table drives prefix, header label, command word, pending record engine/events, and Get-CodexRule now matches the recorded launcher's base name (agy).
- F02-7 - fixed - The agy repair turn is verified with ExpectThread; a repair landing in a new conversation fails and nothing is ingested (harness PROSE case).
- F05-1 - fixed - Tree check fails the run and soft denials with a usable reply become ledger warnings; superseded for the residual blind spots by finding #1.
- F05-2 - fixed - structured_output is atomically written to .reply.json before validation; the pending record names the running turn's events path and every recovery message points at it.
- F05-4 - fixed - agy DefaultMode is 'new'; resume only via -Mode resume or -Thread.

## Verdict: ACCEPT

All ten prior findings are verifiably implemented, the parser was confirmed correct against both real agy streams, the codex path is unchanged, and the remaining tree-check blind spots are a major follow-up, not an acceptance blocker.

### Blockers

_(none)_

### Unproven scenarios

- I did not execute tests/harness-engines.ps1 (81 assertions) or run-all.ps1 myself; I verified syntax of all new/changed scripts (0 parse errors) and read the assertions.
- The denial-retry and format-repair paths have not yet run against the real agy CLI through the new bridge (only the fake and handoff 07's plain first turn).
- agy behavior on versions other than 1.2.11 is untested.

### First-run checklist (observable)

- [ ] A real agy denial (F11) through the new bridge: exactly one retry turn on the SAME conversation id, ledger denial_retry {attempted, reason, succeeded, thread}, the .denial-retry.events.jsonl file kept and named.
- [ ] A real resume of handoff 07's conversation: result.conversation_id equals the parent, ledger reviewer.engine 'agy', warnings array present.
- [ ] Hook line at session start shows 'gemini not checked (launcher present)' and completes without network delay.
