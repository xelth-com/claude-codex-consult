# Handoff 11 - Gemini (agy): wave17-review-gemini

Date: 2026-09-25 14:10 local. Author: Gemini (agy) (model gemini-3.8-flash-high, effort tier in the model id), agy-cli (version unknown).
Reviewer: gemini :: gemini-3.8-flash-high [agy] (provider from roster, model from roster; engine agy (C:\Users\Dmytro\AppData\Local\Microsoft\WinGet\Packages\Google.AntigravityCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\agy.exe); provider fingerprint a612ba12e63e; harness agy-cli (version unknown)).
Preflight: ok: signed in (14 models).
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-0.4.json - position 4 of 5, panel 2d8d5f25 member 3 of 3; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.1-pro-high [agy] (weighty reviewer; purpose diff-review is light (use -PanelAll)).
Effort: nothing sent (requested high, mapping model-tier, by caps-v1: engine agy, the tier is part of the model id; not confirmed by the provider). Consultation id: 29e49e48-824e-4a28-87ef-3302c42a88e8.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; enforced by tree check, agy --sandbox restricts the terminal only), purpose: diff-review). Argv: `agy -p= --input-format stream-json --output-format stream-json --model gemini-3.8-flash-high --json-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json --print-timeout 0 --sandbox --disable-slash-commands` (prompt on stdin as one NDJSON line).
Parent thread: (none - new thread; no thread of lineage gemini :: gemini-3.8-flash-high [agy] in this task's ledger; other lineage(s): mimo :: mimo-v2.6-pro, ZAI :: glm-5.3, gemini :: gemini-3.8-flash-low [agy]). Result thread: `aa5da77b-fa11-4c61-aeb8-e5c3e9e3e8af` (source: events).
Brief: `.collab/engines-0.4-2026-09-25/handoffs/08-claude-wave17-review.md` (sha256 91c25c225d47). Reviewed: a320844 + uncommitted, base a320844989f75989a670c3d0c292929999a4a11d, tree sha256 a3cf3dbbd383, 23 changed files.
Bridge outcome: usable reply. Wall time: 604.8 s. Tokens: in 1615296 (cached 5888962), out 33086, reasoning 25157.
Verdict: ACCEPT - Wave 17 cleanly integrates the agy engine, enforces fail-closed thread identity and evidence-based read-only guarantees, and leaves the codex path completely regression-free. Findings: none. Structured reply: `handoffs/11-agy-wave17-review-gemini.reply.json`.
Raw event stream: `handoffs/11-agy-wave17-review-gemini.events.jsonl`.
Verbatim reply follows.

---

### Wave 17 Diff Review: `agy` Engine (0.4.0 Candidate)

**Q1. Events parser and stream validation:**
No real agy stream is misjudged.
- In `04-agy-engine-design.events.jsonl` (handoff 04 attempt 2), exactly one `init` and one `result` event exist with identical UUIDs (`a538c8df-9cb6-4191-be17-268e3f43b67e`). Although `result.response` contains multi-turn JSON concatenations, `result.structured_output` contains the clean object and is prioritized (`HasStructured = $true`).
- In `handoff 04 attempt 1` (F11 auto-denial empty run), `Get-AgyTurnOutcome` catches empty structured/response output with the stderr denial pattern (`no output produced|auto-denied`), setting `DeniedEmpty = $true` and class `permission`. This correctly fails the turn and enables the denial retry.
- In `07-agy-smoke.events.jsonl`, a single `init` and single `result` event share identical UUIDs, status is `SUCCESS`, and the reply is ingested cleanly.
Across all task streams, "exactly one result" (`ResultCount -eq 1`) and `init == result` hold.

**Q2. Denial retry (A3):**
The denial retry is gated by `$DenialRetry -eq 1 -and $agyTurn.DeniedEmpty -and $threadId -and -not $treeProblem`.
- `DeniedEmpty` strictly requires no structured output, empty response, and stderr matching `no output produced|auto-denied`. It cannot fire on tree check failures, quota errors, exit != 0, or non-empty output.
- It cannot loop: it executes as a single follow-up turn (`Invoke-EngineTurn`) on the existing thread with a fixed prompt; its result is recorded in `$denialRetryRecord` without recursion.
- Provenance is preserved: the raw first turn is archived at `${handoffBase}.denial-retry.events.jsonl`, handoff markdown notes `Denial retry: <reason>`, and the ledger records `denial_retry = @{ attempted = $true; reason = ...; outcome = ... }`.

**Q3. Tree check (A17):**
`Get-EngineTreeProblem` compares:
1. Working tree git status (`git status --porcelain=v1 -uall -z`, `RevBefore` vs `RevAfter`).
2. Brief file SHA-256 (`BriefShaBefore` vs `After`).
3. Resolved artifacts SHA-256 (`ResolvedArtifactsShaBefore` vs `After`).
4. Task handoffs directory snapshot, ignoring the run's own prefix.
Blind spots: files modified outside the repository root, files inside `<CollabDir>` (`.collab/`, explicitly excluded from git status), and git-ignored files.
Failing the run with class `permission` is the correct severity: under agy, `--sandbox` does not prevent file writes (F12). Treating writes as a drift warning would degrade a guaranteed read-only review contract into mere detection.

**Q4. Codex path regression:**
Diffing codex invocation before and after wave 17 reveals zero regression. Codex argv construction, prompt assembly, and execution are identical to 0.3.0. Ledger schema additions are strictly additive (`reviewer.engine = "codex"`, `warnings = []`, `denial_retry = $null`). All existing test suites pass unchanged (227 assertions in `harness-0.3.ps1`).

**Q5. Hook and listing (A4):**
- Hook output: `codex-consult-hook.ps1` runs `codex-providers.ps1 -Json -NoNetwork`. Agy entries output `<label> not checked (launcher present; run codex-providers.ps1)`.
- Full listing: `codex-providers.ps1` runs `agy models` (15s timeout, cached) and outputs `available ... ok: signed in (N models)`.
- Roster walk: the hook evaluates providers with `-NoNetwork`, where agy status is `unknown (sign-in not checked)`. `Select-RosterReviewer` requires `available`, so it skips agy. It never selects an unchecked entry.

**Q6. Roster and lineage (weighty pattern):**
With two `gemini` entries (entry 1: `flash-high`, entry 2: `pro-high` `panel: weighty`):
- `-Provider gemini` without `-Model`: `Find-RosterEntry` returns the first match (entry 1).
- `-Panel` on light purpose: entry 2 is skipped (`weighty reviewer; purpose ... is light`).
- `-Panel` on weighty purpose: both run sequentially in separate handoffs (`01-...-gemini.md` and `02-...-gemini.md`).
- `-Thread <uuid>`: thread lookup restores provider and exact model; `Find-RosterEntry` resolves the specific model without ambiguity.

**Q7. Documentation for installing agent:**
README "Engines" and `setup-providers/SKILL.md` provide complete, actionable instructions covering installation (`winget`), user sign-in (`agy`), model discovery (`agy models`), model reasoning tier naming, two-entry roster configuration, verification commands (`codex-providers.ps1`, `-DryRun`), token costs (13-25k token overhead, conversation replay on resume), and F11/F12 caveats.

**Q8. Verdict and live check:**
Verdict: **ACCEPT** for 0.4.0 candidate.

## Requested checks
RC1: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/codex-consult/scripts/codex-consult.ps1 -Task accept-0.4 -Prompt "Confirm readiness for 0.4.0 in one sentence." -Purpose acceptance -Engine agy -Model gemini-3.8-flash-low`

---

### Findings

_(none)_

### Prior findings

- F02-1 - fixed - Implemented in Get-AgyTurnOutcome: resume mismatch ($resId -ne $ExpectThread) and conversation-not-found warnings fail closed with class unknown; never downgraded to warnings.
- F02-2 - fixed - Implemented: codex-consult-hook.ps1 invokes codex-providers.ps1 with -NoNetwork, bypassing agy models network calls and returning 'not checked (launcher present)'.
- F02-3 - fixed - Implemented via Get-EngineTreeProblem: A17 tree check monitors git status, brief, artifacts, and handoffs, failing runs with class permission if files are modified.
- F02-4 - fixed - Implemented in Read-AgyEvents: parses init conversation_id as fallback ThreadCandidate on missing result; enforces exactly one result and init == result.
- F02-5 - fixed - Implemented: Get-ProviderFailureClass and Get-RetryAfter support Google SCREAMING_SNAKE codes, 'not signed in', 'invalid model selection', and 'retry in 32s' / gRPC retryDelay.
- F02-6 - fixed - Implemented: parameterised engine properties ($engineSpec.Command, $engineSpec.Label, $engineSpec.Prefix); Get-ProcessDescendants uses recorded launcher path.
- F02-7 - fixed - Implemented in codex-consult.ps1: format repair turn runs with --conversation and validates returned thread against ExpectThread; mismatch fails the run.
- F05-1 - fixed - Implemented: tree check detects workspace writes and fails run with class permission; auto-denial stderr messages trigger class permission.
- F05-2 - fixed - Implemented: structured_output is extracted and written to .reply.json before validation; recovery record names the events file.
- F05-4 - fixed - Implemented: default mode for agy is 'new'; 'resume' is explicit opt-in via -Mode resume.

## Verdict: ACCEPT

Wave 17 cleanly integrates the agy engine, enforces fail-closed thread identity and evidence-based read-only guarantees, and leaves the codex path completely regression-free.

### Blockers

_(none)_

### Unproven scenarios

_(none)_

### First-run checklist (observable)

- [ ] Verify agy models runs during preflight and reports signed in with model catalog
- [ ] Verify event stream parses single result with matching init/result conversation_id
- [ ] Verify token usage (input/output) is captured in ledger record
- [ ] Verify tree check confirms working tree and handoffs directory remain unmodified
- [ ] Verify ledger record contains reviewer.engine = 'agy' and denial_retry = null
