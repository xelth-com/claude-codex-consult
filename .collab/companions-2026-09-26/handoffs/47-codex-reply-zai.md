# Handoff 47 - Codex: reply-zai

Date: 2026-09-30 15:47 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 2 of 10, panel 2087691d member 1 of 4.
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 2adab35c-d478-4311-a4fa-cb0eff4534e7.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-e428b739d62d45be89436603a76b11ac.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a0f13d-5a33-7983-af29-51df3dae9a37 -` (prompt on stdin).
Parent thread: `01a0f13d-5a33-7983-af29-51df3dae9a37`. Result thread: `01a0f291-ae6a-70a3-b7f3-3ff5586c9c37` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/46-claude-wave28c-acceptance.md` (sha256 eba6cda05101). Reviewed: 9657cf9, base 9657cf9d6b3f00c985379f52bece5f81606fefc0, tree sha256 9f073e0b355d, 0 changed files.
Bridge outcome: usable reply. Wall time: 426.3 s. Tokens: in 61066318 (cached 54187904), out 150572, reasoning 71252.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `e5c6992..fc6978a` - the range changes 50 files, 15019 lines (14623 insertions, 396 deletions).
Verdict: ACCEPT - All nineteen re-acceptance findings are fixed as decided (F43-6/F44-3 documented as limitations), the closed model list, -Forget sequencing, telemetry locking, bounded flush, pid-identity and journal handling all verify in code, and no new blocker or major defect was found. Findings: none. Structured reply: `handoffs/47-codex-reply-zai.reply.json`.
WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).
Raw event stream: `handoffs/47-codex-reply-zai.events.jsonl`.
Verbatim reply follows.

---

# Wave 28c acceptance (e5c6992..fc6978a) — ACCEPT

## 1. F41-1, F42-1..9, F43-1..7, F44-1..6
All **fixed** except the two accepted limitations, which are documented:

- **F42-1, F43-2 / D1 fixed** — the vendor table's `Models` is now a CLOSED list per class (9330-9339); `Get-TelemetryModelToken` returns a table entry only on exact equality after lower-casing, else `other` (9619-9626). No pattern, no wildcard; `title` stays the closed outcome and `tags` carry the class plus the closed token (9403-9419) — I found no path by which operator text reaches `details.model`, `tags` or `title`: the complaint's `context.consultation` uses the same allowlist.
- **F42-2, F43-1, F44-4 / D2 fixed** — `-Forget -PublicRef -Local` takes the telemetry lock and marker, holds the sender lock, DELETEs first and deletes locally ONLY after `Delivered`; any other answer undoes the marker, keeps salt/spool/counters, exits 3 and says the command can be repeated (10602-10637). `-Local` alone prints the intake-still-holds line and asks `remove locally? [y/N]` unless `-Yes` (10584-10592).
- **F42-3 / D3 fixed** — producers, salt creation and `-Forget` share `Enter-TelemetryLock`; the `forgetting` marker makes a producer drop and count its event (9395-9424, 9962-9986); the marker is removed last and survives a crashed deletion so producers keep dropping.
- **F42-7, F43-5, F44-2 / D4 fixed** — a lock is taken over only when its owner pid+start-time is gone; a living owner is reported however old (`sender busy since <t> ... its owner lives: left alone`, 10245-10253); every sender re-checks its token before each send/rewrite (`Test-TelemetryFlushLockMine`, 10267-10285). The deviation (empty lock, not held open, no owner) can only be a writer that died between create and write — its identity is gone, so the takeover is sound; a starting sender still holds the handle, and an opener then fails with `its lock is held`.
- **F42-8 / D5 fixed** — the 60 s deadline covers enumeration and every local step, checked before each step (10326-10363); a rewrite cut by the deadline completes atomically under its exclusive handle, so the spool stays valid.
- **F41-1, F42-9 / D6 fixed** — the allow list gains both-case proxy variables and the five trust inputs (9789-9795).
- **F43-4 / D7 fixed** — the commit's append waits at most 1 s inside the task write lock and retries up to 5 s after it (9938, 9972-9986); a final failure warns and counts as not spooled.
- **F42-4 / D8 fixed** — a descendant with an unreadable start time is neither killed nor counted gone; the kill is `not confirmed: start time of pid <n> unreadable` with a warning and no continuation (9088-9150).
- **F42-5 / D9 fixed** — pgrep exit 1 is an empty child set; any other exit or timeout is a failed enumeration that falls through to `ps` then `/proc` (8672-8704).
- **F42-6, F44-1 / D10 fixed** — unreadable journal lines are moved to `<journal>.bad` with a timestamp, counted in a warning, and the journal is truncated only by the bytes applied or moved (5332-5365); when the move fails the lines stay in the journal. Two repositories cannot race the move: it runs under the health lock's exclusive journal handle.
- **F43-3, F44-6 / D11 fixed** — the ledger records `compactions` (n, or `unknown` for a member with `context_tokens` whose installed codex reports no compaction event) and the prompt of such a member ends with `Before you answer, re-read the brief: <path>` (4024, 5321-5331, 4221). The extra line changes only `prompt_chars`; the routing seed hashes the brief, so neither the seed nor the lineage changes.
- **F44-5 / D12 fixed** — the dry run prints ALL runWarnings (4259), which includes the test-mode line (3292); a refused run still keeps its refusal first (named deviation).
- **F43-7 / D13 fixed** — the CHANGELOG states both full-suite runs on the final code, each `19 harness(es), 0 failed` (1370-1378).
- **F43-6, F44-3 accepted limitations** — one sentence each in README (2795-2796) and CHANGELOG (1381-1383): the class comes from the host name only.

## 2. New defects
None found. I specifically verified: no path outside the closed lists reaches the event (complaint context included); every `-Forget` exit path — token refusal (exit 1, "nothing removed"), failed DELETE with `-Local` (undo marker, exit 3, salt kept), failed DELETE without `-Local` (exit 3, nothing local touched), sender lock held (nothing removed) — and the crash-left marker makes producers drop events rather than recreate state; the empty-lock takeover deviation is safe (a live starter holds the handle); the deadline cannot corrupt the spool; an unconfirmed kill always warns and skips the continuation; the journal `.bad` move is lock-serialised. Inferred only: both-host suite green (counts read from the CHANGELOG) and the live intake's behaviour.

## 3. Verdict
**ACCEPT** — no blocker or major remains; the two documented limitations are accepted as decided.

## Requested checks
- RC1 — `powershell -NoProfile -File tests/run-all.ps1` then `pwsh -NoProfile -File tests/run-all.ps1` (repo root; workspace-write; ~2×20 min): 19 harnesses, 0 failed, on the final code.
- RC2 — with `CODEX_CONSULT_TELEMETRY_URL` at a closed loopback port in test mode, run `codex-telemetry.ps1 -Forget -PublicRef ref1 -Local` (workspace-write; ~2 min): exit 3, salt/spool/counters intact; repeat with a working intake mock: local files removed after the confirmation; then `-Forget -Local` alone asks and prints the intake reminder.
- RC3 — seed a spool with a model outside the closed list plus one inside (workspace-write; ~5 min): the event's model is `other` for the outside one and the exact table entry for the inside one; `tags` match.
- RC4 — append a torn line and a valid line to `<health>.journal`, trigger any health update (read-only for the journal, workspace-write for the run): the torn line lands in `.journal.bad` with a timestamp and the warning counts it.

---

### Findings

_(none)_

### Prior findings

- F41-1 - fixed - proxy + trust variables in the sender's allow list (9789-9795)
- F42-1 - fixed - closed per-vendor model list, exact match only (9619-9626, 9330-9339)
- F42-2 - fixed - local deletion only after a confirmed DELETE (10627-10637)
- F42-3 - fixed - telemetry lock + forgetting marker; producers drop and count
- F42-4 - fixed - unreadable start time -> neither killed nor counted gone; unconfirmed with a warning
- F42-5 - fixed - pgrep errors are failed enumerations, falling through to ps and /proc
- F42-6 - fixed - unreadable journal lines moved to .journal.bad, counted, prefix-only truncation
- F42-7 - fixed - takeover only from a dead owner; token re-checked before each send/rewrite
- F42-8 - fixed - the 60 s deadline covers the whole flush including local steps
- F42-9 - fixed - SSL_CERT_FILE/DIR, REQUESTS_CA_BUNDLE, CURL_CA_BUNDLE, NODE_EXTRA_CA_CERTS added
- F43-1 - fixed - salt kept on any unconfirmed DELETE; the command is repeatable
- F43-2 - fixed - same as F42-1
- F43-3 - fixed - ledger compactions (or 'unknown') + the re-read-the-brief prompt line
- F43-4 - fixed - 1 s in-lock append, retry after the lock, warn + count on final failure
- F43-5 - fixed - same as F42-7
- F43-6 - still-open - accepted limitation, documented in README 2795-2796 and CHANGELOG 1381-1383
- F43-7 - fixed - CHANGELOG states both final full-suite runs, 19 harnesses 0 failed each
- F44-1 - fixed - same as F42-6
- F44-2 - fixed - same as F42-7
- F44-3 - still-open - accepted limitation, documented (host-name-derived class)
- F44-4 - fixed - intake-still-holds line + confirmation on -Local alone
- F44-5 - fixed - dry run prints all runWarnings incl. the test-mode line (4259)
- F44-6 - fixed - same as F43-3
- F19-1 - not-checked - size code untouched in this range
- F22-6 - not-checked - rating reader untouched
- F02-1 - not-checked - score untouched
- F02-2 - not-checked - reader untouched
- F02-3 - not-checked - reader untouched
- F02-4 - not-checked - topic scoring untouched
- F02-5 - not-checked - draw untouched
- F02-6 - not-checked - size semantics untouched
- F02-7 - not-checked - seed untouched
- F02-8 - not-checked - fallback untouched
- F02-12 - not-checked - -Require untouched
- F02-13 - not-checked - roles untouched
- F02-14 - not-checked - suites not executed in this read-only review
- F02-15 - not-checked - UNIQ untouched
- F03-1 - not-checked - formula untouched
- F03-2 - not-checked - labs untouched
- F03-3 - not-checked - role slugs untouched
- F03-6 - not-checked - fallback untouched
- F03-7 - not-checked - seed untouched
- F03-8 - not-checked - role assignment untouched
- F03-9 - not-checked - required-failure paths untouched
- F03-10 - not-checked - allowlists unchanged
- F03-11 - not-checked - topics untouched
- F03-12 - not-checked - no-backfill unchanged
- F04-1 - not-checked - draw untouched
- F04-2 - not-checked - reader untouched
- F04-3 - not-checked - labs untouched
- F04-4 - not-checked - score untouched
- F04-5 - not-checked - seed untouched
- F04-6 - not-checked - draw untouched
- F04-7 - not-checked - -Require untouched
- F04-8 - not-checked - matcher untouched
- F04-11 - not-checked - not-picked untouched
- F04-12 - not-checked - suites not executed
- F04-13 - not-checked - allowlists unchanged
- F04-14 - not-checked - eligible gate untouched
- F04-15 - not-checked - exit codes unchanged
- F04-16 - not-checked - roles untouched
- F04-17 - not-checked - OffPeakOnly untouched
- F04-18 - not-checked - telemetry schema unchanged beyond the model list
- F15-1 - not-checked - wave 24c
- F15-2 - not-checked - wave 24c
- F15-3 - not-checked - wave 24c
- F15-4 - not-checked - wave 24c
- F15-5 - not-checked - serializer untouched here
- F15-6 - not-checked - wave 24c

## Verdict: ACCEPT

All nineteen re-acceptance findings are fixed as decided (F43-6/F44-3 documented as limitations), the closed model list, -Forget sequencing, telemetry locking, bounded flush, pid-identity and journal handling all verify in code, and no new blocker or major defect was found.

**WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).**

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- Both-host full suites green on the final code (CHANGELOG's counts read, not executed).
- The live intake's DELETE confirmation semantics and the forget marker against a real crashed deletion (logic read; not exercised).
- That the closed model lists cover every model the operator's rosters actually run (lists read; new models read 'other' by design until a release adds them).
- The empty-lock takeover deviation against a real writer crash between create and write (reasoned safe from the FileShare.None handle; not reproduced).
- Compaction observation on a real codex stream (the installed CLI reports no event; 'unknown' is the documented fallback).

### First-run checklist (observable)

- [ ] First telemetry event after this wave: details.model is either an exact entry of the README's closed vendor table or 'other', tags carry the same two closed values, and title is only the closed outcome vocabulary.
- [ ] codex-telemetry.ps1 -Forget -PublicRef <wrong> -Local exits 3 with 'NOTHING was deleted - not there and not here', and the salt, spool and not-spooled counters are still present; the same command with the right ref deletes remotely first, then locally.
- [ ] -Forget -Local alone prints 'the intake still holds what was sent' with the -PublicRef-first advice and asks 'remove locally? [y/N]' unless -Yes.
- [ ] A run while -Forget holds the telemetry lock or leaves the forgetting marker drops its event with a counted 'not spooled' reason instead of recreating the salt or spool.
- [ ] A flush over a spool with a living owner reports 'sender busy since <t> ... its owner lives: left alone'; a sender whose lock was taken over stops before its next send/rewrite without touching the spool; every flush ends within ~60 s including local steps.
- [ ] A health journal with a torn line moves it to <journal>.journal.bad with a timestamp and warns 'health journal: N unreadable line(s) kept in ...'; the journal loses only the applied/moved prefix.
- [ ] A killed tree whose descendant start time cannot be read records kill_confirmed false with 'start time of pid <n> unreadable', warns, and starts no continuation; pgrep failures fall through to ps and /proc.
- [ ] A member with context_tokens records ledger compactions ('unknown' with the installed codex) and its prompt ends with 'Before you answer, re-read the brief: <path>'; the routing seed and lineage are unchanged.
- [ ] A dry run with CODEX_CONSULT_TEST_MODE=1 prints 'WARNING: test mode is ON: test hooks are honoured' among its warnings; a refused run keeps its refusal as the first line.
