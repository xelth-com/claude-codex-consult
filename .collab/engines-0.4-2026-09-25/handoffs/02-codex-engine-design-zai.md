# Handoff 02 - Codex: engine-design-zai

Date: 2026-09-25 10:51 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 2 of 3, panel a243bb61 member 1 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 6ccd8be1-af20-4c4a-b3e1-fc0125efa323.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-7cd2b4f0791146dd8d5488922cadce44.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a0d7c3-343a-7510-801c-e5a7912799a5` (source: events).
Brief: `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md` (sha256 687ddade26c4). Reviewed: 7f46fe4, base 7f46fe49e2c26f9d650fad63e7063ce612b122f1, tree sha256 4c9d0f35d4ce, 0 changed files.
Bridge outcome: usable reply. Wall time: 567.2 s. Tokens: in 2338417 (cached 2201280), out 19519, reasoning 11665.
Verdict: ADVISE - This is a pre-build framing consultation, so the verdict is advice: adopt the design with the listed fixes to D3/D6/D2/D7 before implementation. Findings: 0 blocker, 3 major, 4 minor, 0 note (F02-1..F02-7, tracked in `findings.json`). Structured reply: `handoffs/02-codex-engine-design-zai.reply.json`.
Raw event stream: `handoffs/02-codex-engine-design-zai.events.jsonl`.
Verbatim reply follows.

---

## Framing first

The brief frames "engine" as a roster property and preflight as a network question. Two unlisted options: (a) a hybrid transport — `--input-format stream-json` on stdin (no 32 KB argv limit, no cmd quoting) with `--output-format json` (one result object, no JSONL parser); you lose init/step diagnostics and the init conversation_id cross-check, so stream-json output is still the better default; (b) skip the credential preflight entirely and let the first real turn prove auth (the classifier already handles auth failures) — that keeps the hook network-free but weakens fails-closed. To choose between these I would need: whether `--sandbox` blocks writes (not just terminal/reads), whether `--print-timeout 0` really means infinite, whether `result` ever omits `structured_output`/`conversation_id` on SUCCESS, and how fast a resumed conversation's input tokens grow.

Live evidence in this task: `handoffs/04-agy-engine-design.events.jsonl` (a real agy 1.2.11 run) shows `conversation_id` at the top level of `init` but nested inside `step_update`, and no `result` event until completion — pin which event the parser reads.

## Q1

Stream on stdin is right (argv: 32 KB limit, quoting, and `--print` swallows the next token — a silent mis-prompt risk). Stream-path risks: the bridge must serialize the prompt into ONE NDJSON `user` line itself (PS 5.1 `ConvertTo-Json`, no BOM, CRLF escaped); `result` may be absent (kill/crash) while `init` already names the conversation; and `structured_output` can be absent with a non-empty `response` (F4), so the prose gate must stay mandatory.

## Q2

Record requested, send nothing, map to model-tier: correct. Rewriting the model id by effort would mutate the lineage and break parent matching. `panel: weighty` is not enough — it only affects panels; a solo `-Provider gemini` acceptance consult still lands on whatever model the entry pins. Add a second roster entry (e.g. `gemini-pro`) or purpose-based model selection.

## Q3

Fail closed, as proposed. Ingest-flagged hides a silent lineage break: the "new" conversation has no memory of the parent, yet would become the next parent. Fail-closed hides only the paid-for answer, and the design already keeps it named — correct trade.

## Q4

Default `new`, opt-in `resume`. The prompt already carries open findings and the brief, so `new` costs the judge little; resume buys continuity but grows the conversation (tokens, latency, contamination) with every consultation in the lineage, and panel members append asymmetrically versus codex members that fork.

## Q5

`agy models` in preflight: acceptable (one round-trip, fail-closed). In the hook: no — print `gemini: not checked` or use a TTL cache; the hook currently promises "no network call, about one second". I checked: no `cmdkey` target matching agy/google, no credentials file under `~/.antigravity` or `%LOCALAPPDATA%\agy` — I know of no network-free sign-in proof.

## Q6

Add to the classifier: `RESOURCE_EXHAUSTED`, `rate_limit_exceeded` → quota; `UNAUTHENTICATED`, `PERMISSION_DENIED`, "not signed in", "login required" → auth; `INVALID_ARGUMENT`, "invalid model selection", "conflicts with --effort" → capability; `UNAVAILABLE`, `DEADLINE_EXCEEDED`, 5xx → transport. Note the current regexes match NONE of the SCREAMING_SNAKE codes, and `Get-RetryAfter` misses Google's "retry in 32s" (it knows "retry after" and "try again in") and gRPC `retryDelay {seconds}`.

## Q7

Conditions are right, plus: schema-validate the object (presence ≠ validity); require the resume conversation_id check; FAIL (not warn) on the conversation-not-found warning and on "partial output"/empty-response SUCCESS (F7); soft-denial can stay a warning but its text belongs in the ledger.

## Q8

`codex-findings -List`/`-Stats` and the scoreboard read the ledger's `reply` path and lineage — safe. Hardcoded: the repair original `$nn-codex-….original.md`, the header "# Handoff NN - Codex:", `$commandStr = 'codex ' + …`, pending-record notes, and `Get-CodexRule`'s name rule (`^codex(\.exe)?$`) which won't match `agy.exe` — recovery then depends entirely on the recorded launcher path.

## Q9

First: resume-mismatch (fake emits the not-found warning plus a new conversation_id; assert failed outcome, reply kept and named, nothing ingested, new id never parentable). Quoting: never pass the prompt through the `.cmd`; the `.cmd` only execs PowerShell, and `fake-agy.ps1` logs its raw stdin bytes; assert the logged NDJSON line, JSON-parsed, equals the composed prompt byte for byte (quotes, backslashes, `%APPDATA%`, newlines).

## Q10

D3 breaks the thread invariant as written (see finding #1); D6 breaks the hook's no-network behaviour (#2); D2's read-only claim is unverified (#3); D7's repair turn can silently land in a fresh conversation (#7). D4/D8 preserve all four invariants.

## Requested checks

- **RC1** (finding #3): in a scratch dir (workspace-write, 5 min): `agy -p= --input-format stream-json --output-format stream-json --sandbox` with a prompt "create file probe.txt"; the file's absence/presence settles whether `--sandbox` blocks writes.
- **RC2** (Q1/Q7): run 5 schema-bound agy turns (read-only, ~10 min); any SUCCESS `result` lacking `structured_output` or `conversation_id` forces the fallback conditions into D3.
- **RC3** (Q4): resume one conversation 3 times (read-only, ~10 min); record `input_tokens`/`cache_read_tokens` growth per turn to price default-resume.

---

### Findings

- **F02-1** [major] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:77`, `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:84` - D3's rule that any `warning:` or soft-denial stderr notice 'becomes a ledger warning, never a refusal' contradicts D4's fail-closed resume-mismatch rule: the F6 conversation-not-found signal arrives exactly as a `warning:` line, so any path that does not compare conversation ids (a result without one, or the D7 repair turn) would downgrade a lineage break to a warning and could ingest a reply from a brand-new conversation as if it continued the parent thread. Trigger: A resume-mode agy run whose stored conversation was expired server-side: agy prints the not-found warning, answers from a fresh conversation, and the result's conversation_id differs from the parent. Evidence: read-code: D3 mandates warning-never-refusal for stderr `warning:` lines; D4 fails the run only on the conversation_id comparison; F6 shows the not-found case is reported as a stderr warning and still exits 0. Verify: With a fake agy that emits the not-found warning but a result whose conversation_id equals the parent, confirm the implementation still hard-fails (i.e. the warning, not only the id, gates resume runs). Remedy: In resume mode, hard-fail on the conversation-not-found warning, on a missing result conversation_id, and on any id mismatch; keep other warnings as ledger warnings.
- **F02-2** [major] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:98`, `plugins/codex-consult/scripts/codex-consult-hook.ps1:16` - D6 puts an `agy models` network round-trip (up to the proposed 15 s timeout) into codex-providers.ps1, which the SessionStart hook runs at every session start; this breaks the hook's documented 0.3.0 contract 'No network call, no lock, nothing written ... about one second' and can stall session startup when the network is slow. Trigger: The plugin hook enabled and a roster entry with engine agy present, on a machine where api.googleapis.com is slow or blocked. Evidence: read-code: The hook's header promises no network call and ~1 s cost, and it shells out to codex-providers.ps1 -Json, which D9 extends with agy credential rows.; read-code: D6 plans `agy models` with a 15 s timeout inside the providers listing, and D9 makes the hook list agy rows like any provider. Verify: Time the hook with an agy roster entry and a blocked network (e.g. firewall rule); observe the session-start line arriving only after the timeout. Remedy: Run `agy models` only in the consultation preflight; the hook and providers listing print 'gemini: not checked' (or a short-TTL cached result) for engine rows.
- **F02-3** [major] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:69`, `plugins/codex-consult/scripts/codex-consult.ps1:2028` - D2 asserts 'reviews are read-only' under agy `--sandbox`, but F8 verified only that reads still work; agy's sandbox is documented as terminal restrictions, and in 0.3.0 a working-tree change during a review is only a drift WARNING, so an agy reviewer that writes files would still produce a 'usable reply' — the read-only guarantee degrades from enforcement to detection. Trigger: An agy reviewer whose tools write a file during a consultation (e.g. a 'helpful' fix) while --sandbox permits writes. Evidence: read-code: Only file reads under --sandbox were verified; write behaviour is untested.; read-code: tree_changed_during_review only adds a WARNING drift line; it does not fail the run. Verify: RC1 in reply_markdown: run agy under --sandbox with a prompt asking it to create probe.txt in a scratch directory and observe whether the file appears. Remedy: Verify and document write behaviour; if writes are not blocked, fail agy runs whose tree fingerprint changed (or record sandbox:'unverified' and keep the drift warning explicit in the handoff header).
- **F02-4** [minor] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:81`, `.collab/engines-0.4-2026-09-25/handoffs/04-agy-engine-design.events.jsonl:1` - D4/D3 do not specify which event supplies the conversation_id or how to parse agy's inconsistent placement: in a real run the id sits at the top level of the init event but nested inside step_update, and a killed run has no result event at all, so the parser needs fixed rules and should salvage the init id as a never-parent diagnostic. Trigger: A timeout-killed agy run: the events file contains init/step_update but no result, and recovery wants to name which conversation was live. Evidence: ran-command: Line 1 is {"event":"init","conversation_id":"fdc21ce2-...","init":{...}} while step_update nests conversation_id under step_update; the file has no result event. Verify: Feed the real events file to the new parser; assert the thread is captured from init for diagnostics and that the run is failed for the missing result. Remedy: Specify: result.conversation_id is authoritative for the thread; init.conversation_id must equal it (mismatch = failure); on a missing result, record the init id as thread_candidate, never a parent.
- **F02-5** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:2762`, `plugins/codex-consult/scripts/codex-consult-common.ps1:2833`, `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:76` - The current failure-class regexes match none of Google's SCREAMING_SNAKE codes (RESOURCE_EXHAUSTED, UNAUTHENTICATED, PERMISSION_DENIED, INVALID_ARGUMENT), 'not signed in', or 'invalid model selection', so those failures land in 'unknown'; and Get-RetryAfter's wordings miss 'retry in 32s' (it knows 'retry after N' and 'try again/resets in N') and gRPC retryDelay {"seconds":N} payloads. Trigger: An agy quota rejection phrased 'RESOURCE_EXHAUSTED: Retry in 32s' — classified unknown with no retry_after, so endpoint health never records the reset window. Evidence: read-code: capability/auth/quota/transport patterns contain none of the Google codes; the After regex requires 'retry[- ]after', the In regex requires 'try again|resets' before 'in'. Verify: Unit-test Get-ProviderFailureClass and Get-RetryAfter with the Google wordings from Q6; all must classify and the retry ones must yield a reset time. Remedy: Add the Google codes and wordings to the class patterns and a 'retry in <dur>' / retryDelay branch to Get-RetryAfter, per the Q6 list.
- **F02-6** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:1858`, `plugins/codex-consult/scripts/codex-consult.ps1:2035`, `plugins/codex-consult/scripts/codex-consult.ps1:1463`, `plugins/codex-consult/scripts/codex-consult-common.ps1:3838` - Beyond the D3/D8 file-naming list, several code paths hardcode 'codex': the format-repair original is always handoffs/NN-codex-<slug>.original.md, the handoff header reads '# Handoff NN - Codex:', $commandStr is prefixed 'codex ', pending-record notes say 'codex is being started', and Get-CodexRule's name rule (^codex(\.exe)?$) will not match agy.exe, so recovery of an interrupted agy run depends solely on the launcher-in-command-line rule. Trigger: An agy run that is interrupted between the 'launching' and 'running' pending states: the next run's descendant scan finds nothing named codex and must fall back to the recorded launcher path. Evidence: read-code: All four sites embed the literal engine string 'codex'; Get-CodexRule matches only the process name codex/codex.exe, the recorded launcher substring, or @openai/codex.; read-code: -List/-Stats resolve replies through the ledger entry's reply path, and the scoreboard keys by lineage — these are engine-neutral and safe. Verify: Grep the scripts for the literal 'codex' in composed strings (filenames, headers, command prefix, pending notes, process rules) and run the interrupted-launching recovery test with fake agy. Remedy: Parameterize the engine token in every composed name/message; extend the process rule to agy.exe (or match the recorded launcher generically) and always record the resolved launcher in the pending record.
- **F02-7** [minor] `.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:104` - D7's format-repair turn rides `--conversation <thread>`, but by F6 an expired conversation makes agy silently start a NEW conversation whose only context is the repair prompt — there is no 'last message' to convert, so the model will fabricate an object from the schema alone and the repair can 'succeed' with invented content. Trigger: A resume-mode agy reply that needs format repair after the stored conversation expired server-side. Evidence: read-code: The repair prompt asks the model to convert 'your last message'; F6 shows a not-found conversation silently starts a new one with exit 0.; inferred: The codex repair path is only eligible on a VERIFIED thread; the agy variant must add the same id verification after the repair result. Verify: Fake an agy repair turn that returns a new conversation_id; assert the repaired object is rejected and recorded as a failed repair, not ingested. Remedy: After the repair turn, require result.conversation_id == the repaired thread and no not-found warning; otherwise fail the repair and keep the prose original only.

### Prior findings

_(none)_

## Verdict: ADVISE

This is a pre-build framing consultation, so the verdict is advice: adopt the design with the listed fixes to D3/D6/D2/D7 before implementation.

### Blockers

_(none)_

### Unproven scenarios

- Whether agy `--sandbox` blocks file writes (only reads were verified, F8).
- Whether `--print-timeout 0` waits indefinitely as --help claims versus the documented five-minute default.
- How often a SUCCESS result omits structured_output or conversation_id in real runs (F4 observed response/structured_output divergence once).
- How resumed-conversation token counts grow per turn, which decides the default mode in Q4.

### First-run checklist (observable)

_(none)_
