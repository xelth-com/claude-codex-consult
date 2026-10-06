# Handoff 50 - Meta Muse (muse): reply-meta

Date: 2026-09-30 15:47 local. Author: Meta Muse (muse) (model muse-spark-1.3-contributor, effort high), muse-cli 1.4.1-R4503.1.
Reviewer: meta :: muse-spark-1.3-contributor [muse] (provider from roster, model from roster; engine muse (C:\Users\Dmytro\AppData\Local\Programs\muse\muse.cmd); provider fingerprint 1c6f62bb040d; harness muse-cli 1.4.1-R4503.1).
Preflight: ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth).
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 10 of 10, panel 2087691d member 4 of 4.
Effort: high sent (requested high, mapping muse-v1, by caps-v1: engine:muse, muse-spark-1.3-contributor; not confirmed by the provider). Consultation id: 8ae95b99-b3fc-4b20-b306-340980570cdf.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads), purpose: acceptance). Argv: `muse exec --json --prompt-file C:\Users\Dmytro\AppData\Local\Temp\codex-consult-prompt-76dcf1f2126e442592ce4bb4113484cb.txt --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json --model muse-spark-1.3-contributor --reasoning-effort high --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never` (prompt from a file: --prompt-file).
Parent thread: (none - new thread). Result thread: `01a0f292-5d6c-7871-88ac-d6cb1d1cd91e` (source: events).
Brief: `.collab/companions-2026-09-26/handoffs/46-claude-wave28c-acceptance.md` (sha256 eba6cda05101). Reviewed: 9657cf9, base 9657cf9d6b3f00c985379f52bece5f81606fefc0, tree sha256 9f073e0b355d, 0 changed files.
Bridge outcome: usable reply. Wall time: 421.3 s. Tokens: not reported by muse.
Engine turns: 1 (each one a Muse Code subscription prompt); MSP schema_version 1.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `e5c6992..fc6978a` - the range changes 50 files, 15019 lines (14623 insertions, 396 deletions).
Verdict: ACCEPT - All wave-28c decisions D1-D14 verified in code with no blocker or major remaining; residuals are one minor and one note. Findings: 0 blocker, 0 major, 1 minor, 1 note (F50-1..F50-2, tracked in `findings.json`). Structured reply: `handoffs/50-muse-reply-meta.reply.json`.
WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).
Raw event stream: `handoffs/50-muse-reply-meta.events.jsonl`.
Verbatim reply follows.

---

## 1. Wave-28b findings in this commit

All verified read-only (code read at the cited lines; harnesses read, not executed):

- **F42-1 / F43-2 (D1) fixed.** `Get-TelemetryModelToken` returns the table text only on exact match after lower-casing, else `other` (`codex-consult-common.ps1:9619`); version pattern gone; `tags` reuse the same two closed values (`:9683`). Residual `-ceq` fragility: finding #1.
- **F42-2 / F43-1 / F44-4 (D2) fixed.** `-PublicRef -Local` DELETEs first and on any non-confirmation runs the undo path (marker removed only if new), keeps salt/spool/counters, exits 3 (`:10627-10636`); `-Local` alone prints the intake-still-holds line and asks unless `-Yes` (`:10582-10592`).
- **F42-3 (D3) fixed.** One telemetry lock for appends, salt creation and `-Forget`, marker written first and removed last, producers drop-and-count on marker or busy lock (`:9384-9392`, `:9734-9749`, `:10604-10617`).
- **F42-7 / F43-5 / F44-2 (D4) fixed.** Takeover only when owner pid gone (unknown counts as living), `sender busy since` otherwise; token re-checked before each send and rewrite (`:10219-10264`, `:10270-10284`, `:10391-10340`). The no-owner deviation is safe: a starting sender holds the file open (`Share.None`), so an empty unheld lock has no living writer.
- **F42-8 (D5) fixed.** The watch starts before the lock; enumeration, reads, sends, rewrites each check the clock with bounded waits; rewrite always attempted for delivered lines (`:10339-10341`, `:10363-10374`, `:10436-10340`). Spool stays valid (exclusive handle, whole-file rewrite).
- **F41-1 / F42-9 (D6) fixed.** Allow list gains `HTTP(S)_PROXY`, `ALL_PROXY`, `NO_PROXY` and five trust vars; ordinal comparer off-Windows so both cases survive (`:9785-9811`).
- **F43-4 (D7) fixed** with documented deviation (failure leaves `warnings[]`; console + status only): 1 s append in-lock, retry after release (`codex-consult.ps1:5858`).
- **F42-4 / F42-5 (D8/D9) fixed.** `Get-PidIdentity` alive/gone/unknown (`codex-consult-detached.ps1:168`); unknown pids never killed, never counted gone, kill `Unverified` with warning (`codex-consult-common.ps1:9111-9116`, `:9136-148`); pgrep exit 1 empty, else fall through ps/`/proc`.
- **F42-6 / F44-1 (D10) fixed.** Journal read as bytes; torn lines appended to `.bad` with timestamp, counted (`health journal: N unreadable line(s)`), truncation only by applied/moved prefix; unwritable `.bad` keeps line plus suffix (`:5288-560`). Concurrent writers serialize on the machine lock, so no joint `.bad` race.
- **F43-3 / F44-6 (D11) fixed** with stated deviations (re-read line before, not after, the id; continuation exempt). `Get-CompactionCount` counts reported events (`:8523`); ledger `unknown` for `context_tokens` with none reported; warning text as specified (`codex-consult.ps1:5326-5331`).
- **F44-5 (D12) fixed.** Line on committed/dry/panel/detached runs, not refused (README + `harness-host` TESTLINE; code path partly read).
- **F43-7 (D13) fixed as wording** (CHANGELOG states runs as they were and claims 19/0 both hosts); counts themselves are unproven here, see RC1.
- **F43-6 / F44-3 accepted limitations confirmed documented**: vendor-from-host-name (README vendor table; CHANGELOG `Known limitations`), compactions `unknown` on installed codex.

## 2. New defects in this wave

- **Closed list:** no path left for outside-list text into `details.model`, `tags` (both via the token fn) or `title` (closed `usable`/`failed:<class>` outcome, `:9573`). `ps_version`/`bridge_version` echo through a tight pattern but are machine values, not operator text.
- **`-Forget`:** no exit path removes the salt after an unconfirmed DELETE when `-PublicRef` was given (failure returns before any deletion, `:10631-10634`); crash marker drops events until re-run by design, surfaced in `-Status`.
- **Telemetry lock:** a producer holding it while `-Forget` starts only delays `-Forget` (5 s wait); `-Forget` holding it across the DELETE makes producers drop-and-count, which is the documented D2/D3 behavior.
- **D4 deviation:** safe (see §1); no live sender can sit behind an unheld ownerless lock.
- **Deadline:** a cut mid-rewrite cannot corrupt the spool (exclusive handle, atomic whole-file rewrite; worst case lines stay and resend).
- **Process tree:** `Unverified` always flips `Confirmed=false` with a naming warning; no silent orphan (warning text asserted by `harness-fixes28c`).
- **Journal:** two repositories serialize on the same machine lock; `.bad` append failure degrades to keep-in-journal, never silent loss.
- **Prompt line:** changes prompt bytes (any prompt hash differs from pre-28c) but not lineage (roster identity). Gap: inline `-Prompt` members get `unknown` with no re-read line — finding #2 (note).

Two residuals filed: finding #1 (minor, `-ceq` fragility), finding #2 (note, inline-prompt gap).

## 3. Verdict

**ACCEPT** — D1–D14 verified in code as written; no blocker or major remains; residuals are one minor and one note. Suite counts and live-network paths rely on the implementer's claim until RC1 runs.

## Requested checks

- **RC1** (repo root; needs shell): `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1` under Windows PowerShell 5.1 and `pwsh -NoProfile -File tests/run-all.ps1` under PowerShell 7; settle: both print `19 harness(es), 0 failed`. Budget: ~30 min. Settles F43-7 and finding-count claims.
- **RC2** (repo root + temp home; read-only code, workspace-write for fake home): point `CODEX_CONSULT_TELEMETRY_URL` at a closed loopback port in test mode, run `-Forget -PublicRef ref1 -Local` then `-Forget -PublicRef ref1`; settle: exit 3 with salt intact, then repeatable. Budget: 15 min. Settles F43-1 (finding: fixed).
- **RC3** (repo root; read-only): dot-source common script, call `Get-TelemetryModelToken` with `glm-4.5acmecorp`, `gpt-al1ce-code`, `K3-ULTRA`; settle: all `other` today, and re-test after finding #1 fix. Budget: 10 min.
- **RC4** (temp homes; workspace-write): hold the spool file open 3 s while a fake consultation commits with telemetry on; settle: `write lock : waited N ms` line plus commit wall time (D7 cost). Budget: 15 min.
- **RC5** (Unix or fake runner; workspace-write): force pgrep exit 2 with a live child during a timeout kill; settle: kill reported unconfirmed, child untouched, fallback attempted. Budget: 15 min.

---

### Findings

- **F50-1** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:9624` - Get-TelemetryModelToken compares the lower-cased input against the raw table entry with case-sensitive -ceq, so any future table entry containing an upper-case character silently never matches and reads `other`. Trigger: A release adds a model name with an upper-case character (e.g. `K3-Ultra`) to a vendor Models list; events for it read `other` despite being listed. Evidence: read-code: Line 9621 lower-cases the input ($m); line 9624 matches `[string]$known -ceq $m` without lower-casing the table entry.; read-code: All current Models entries (openai/zai/xiaomi/byteplus/moonshot/alibaba/google/meta) are lower-case, so the bug is latent today. Verify: Dot-source the common script with a test table containing `K3-Ultra` and call Get-TelemetryModelToken with `k3-ultra`; expect the table text, currently `other`. Remedy: Compare lower-cased to lower-cased (or store a parallel lower-case set) and add a harness check with a mixed-case table entry.
- **F50-2** [note] `plugins/codex-consult/scripts/codex-consult.ps1:4024` - The D11 re-read mitigation only applies when the prompt has a brief reference ($briefRef); a member with context_tokens run via inline -Prompt (no brief file) still records `compactions: unknown` with no re-read line, which is the highest-risk shape for brief loss. Trigger: A context_tokens member runs with an inline -Prompt long enough to compact; the ledger says `unknown` and the prompt has no re-read anchor. Evidence: read-code: The re-read line is gated by `if ($contextTokens -gt 0 -and $briefRef)`; the unknown record is gated by contextTokens alone.; read-code: README documents the line as applying to a member with context_tokens `and a -Brief`, confirming the inline-prompt gap is real and undisclosed as a residual. Verify: Fake-run a context_tokens member with -Prompt text (no -Brief) and inspect the sent prompt for the re-read line and the ledger `compactions` value. Remedy: Either extend the re-read line to inline prompts (naming the consultation instead) or document the gap in one sentence next to `compactions`.

### Prior findings

- F02-1 - not-checked - Outside wave-28c scope; not re-examined.
- F02-2 - not-checked - Outside wave-28c scope; not re-examined.
- F02-3 - not-checked - Outside wave-28c scope; not re-examined.
- F02-4 - not-checked - Outside wave-28c scope; not re-examined.
- F02-5 - not-checked - Outside wave-28c scope; not re-examined.
- F02-6 - not-checked - Outside wave-28c scope; not re-examined.
- F02-7 - not-checked - Outside wave-28c scope; not re-examined.
- F02-8 - not-checked - Outside wave-28c scope; not re-examined.
- F02-12 - not-checked - Outside wave-28c scope; not re-examined.
- F02-13 - not-checked - Outside wave-28c scope; not re-examined.
- F02-14 - not-checked - Outside wave-28c scope; not re-examined.
- F02-15 - not-checked - Outside wave-28c scope; not re-examined.
- F03-1 - not-checked - Outside wave-28c scope; not re-examined.
- F03-2 - not-checked - Outside wave-28c scope; not re-examined.
- F03-3 - not-checked - Outside wave-28c scope; not re-examined.
- F03-6 - not-checked - Outside wave-28c scope; not re-examined.
- F03-7 - not-checked - Outside wave-28c scope; not re-examined.
- F03-8 - not-checked - Outside wave-28c scope; not re-examined.
- F03-9 - not-checked - Outside wave-28c scope; not re-examined.
- F03-10 - not-checked - Outside wave-28c scope; not re-examined.
- F03-11 - not-checked - Outside wave-28c scope; not re-examined.
- F03-12 - not-checked - Outside wave-28c scope; not re-examined.
- F04-1 - not-checked - Outside wave-28c scope; not re-examined.
- F04-2 - not-checked - Outside wave-28c scope; not re-examined.
- F04-3 - not-checked - Outside wave-28c scope; not re-examined.
- F04-4 - not-checked - Outside wave-28c scope; not re-examined.
- F04-5 - not-checked - Outside wave-28c scope; not re-examined.
- F04-6 - not-checked - Outside wave-28c scope; not re-examined.
- F04-7 - not-checked - Outside wave-28c scope; not re-examined.
- F04-8 - not-checked - Outside wave-28c scope; not re-examined.
- F04-11 - not-checked - Outside wave-28c scope; not re-examined.
- F04-12 - not-checked - Outside wave-28c scope; not re-examined.
- F04-13 - not-checked - Outside wave-28c scope; not re-examined.
- F04-14 - not-checked - Outside wave-28c scope; not re-examined.
- F04-15 - not-checked - Outside wave-28c scope; not re-examined.
- F04-16 - not-checked - Outside wave-28c scope; not re-examined.
- F04-17 - not-checked - Outside wave-28c scope; not re-examined.
- F04-18 - not-checked - Outside wave-28c scope; not re-examined.
- F15-1 - not-checked - Outside wave-28c scope; not re-examined.
- F15-2 - not-checked - Outside wave-28c scope; not re-examined.
- F15-3 - not-checked - Outside wave-28c scope; not re-examined.
- F15-4 - not-checked - Outside wave-28c scope; not re-examined.
- F15-5 - not-checked - Outside wave-28c scope; not re-examined.
- F15-6 - not-checked - Outside wave-28c scope; not re-examined.
- F19-1 - not-checked - Outside wave-28c scope; not re-examined.
- F22-6 - not-checked - Outside wave-28c scope; not re-examined.
- F41-1 - fixed - Allow list now carries proxy (both cases) and trust vars; ordinal comparer off-Windows. Read-only; egress not executed.
- F42-1 - fixed - Closed exact-match list per vendor class; hostile names read `other`. Latent -ceq fragility filed as finding #1.
- F42-2 - fixed - DELETE-first ordering; salt/spool/counters kept, exit 3, repeatable; marker removed when it was not pre-existing.
- F42-3 - fixed - Shared telemetry lock + forgetting marker; producers drop and count; crash marker finished by re-run.
- F42-4 - fixed - Get-PidIdentity alive/gone/unknown; unknown never killed by pid, never counted gone; kill warning names pids.
- F42-5 - fixed - pgrep exit 1 is empty, any other failure falls to ps then /proc; denied only when all fail.
- F42-6 - fixed - Torn lines moved to .bad with timestamp, counted in warning; journal truncated only by applied/moved prefix.
- F42-7 - fixed - Takeover only from dead owner; unknown identity counts as living; token checked before each send/rewrite. No-owner deviation reasoned safe (Share.None guard).
- F42-8 - fixed - Clock checked before enumeration, reads, sends, rewrites; bounded waits; counts skipped when out of time.
- F42-9 - fixed - Same evidence as F41-1; README lists the whole list.
- F43-1 - fixed - Same evidence as F42-2.
- F43-2 - fixed - Version pattern gone; same evidence as F42-1.
- F43-3 - fixed - Compaction counting + unknown + re-read line (before consultation id); continuation exempt by design. Inline-prompt gap filed as finding #2.
- F43-4 - fixed - 1 s append in lock, 5 s retry after; failure leaves warnings[] (deviation documented). Retry body partly read; rest via harness.
- F43-5 - fixed - Same evidence as F42-7; 5-minute rule gone.
- F43-7 - fixed - CHANGELOG states runs as they were and claims clean suites both hosts; counts not re-executed here (see unproven/RC1).
- F44-1 - fixed - Same evidence as F42-6; .bad-unwritable path keeps line plus suffix.
- F44-2 - fixed - Same evidence as F42-7.
- F44-4 - fixed - -Local alone prints intake-still-holds line with order warning and asks unless -Yes.
- F44-5 - fixed - Line on committed/dry/panel/detached runs, not refused; README states it; harness TESTLINE asserts it.
- F44-6 - fixed - Same evidence as F43-3.

## Verdict: ACCEPT

All wave-28c decisions D1-D14 verified in code with no blocker or major remaining; residuals are one minor and one note.

**WARNING: ACCEPT with 5 unchecked prior blocker(s) (F02-2, F02-7, F02-12, F04-1, F04-2).**

### Blockers

- **F02-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `plugins/codex-consult/scripts/codex-scoreboard.ps1:119` - Ratings and consultation numbers are task-scoped, so joining cross-task telemetry by `n` alone can attach a rating to the wrong consultation and therefore the wrong topics or lineage. Verify: Create two temporary task ledgers with n=1 and different topics, rate one, then run a prototype aggregate and inspect attribution. Remedy: Key evidence by `(task, n)` or consult_id everywhere; retain task identity in the aggregate input and validate rating.consult_id as well as n.
- **F02-7** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult.ps1:1237` - Seeding with the panel id cannot reproduce a draw as specified because the id is generated after selection and afresh for every invocation, including dry runs; no user-supplied seed exists. Verify: Invoke identical fake dry runs twice and compare printed routing picks for equal inputs. Remedy: Generate or accept the routing seed before selection, record it, and define an exact portable PRNG and canonical candidate ordering; use the resulting panel id only as identity.
- **F02-12** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4616`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4635`, `plugins/codex-consult/scripts/codex-consult.ps1:1221` - `-Require` and roster `require` lack a complete contract and can silently proceed: required available members can lose their seats to size/diversity draws, matching and precedence are unspecified, and current fail-closed roster validation rejects the new keys. Verify: Dry-run cases where a required available reviewer falls below the panel cap and where CLI and roster requirements conflict; assert exit 5 and no writes. Remedy: Pin required eligible members before filling seats; define canonical lineage matching including engine, wildcard policy, union/override precedence, all invocation modes, exit 5 and dry-run behavior; bump/extend roster validation.
- **F04-1** (prior, not-checked) `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md`, `plugins/codex-consult/scripts/codex-consult-common.ps1:4380` - R14 item 2 (deterministic: best-ranked per lab, then the rest by rank) and R15 item 6 (weighted random draw without replacement plus 0.2 exploration per slot) are two mutually exclusive selection rules, and the design never states how they compose, so the feature is unimplementable as written. Verify: Write the composition rule as pseudo-code and check one worked example: 2 labs (A: a1 score 3, a2 score 2; B: b1 score 1), k=2, seed that explores slot 2 — state which members run and whether the lab guarantee held. Remedy: Pin one rule: fill slot 1..k by the weighted draw, but restrict the draw for the first min(k, distinctLabs) slots to entries whose lab is not yet represented (an explored slot draws uniformly from that same restricted pool), then fill any remaining slots from all eligible entries. Record per slot in `routing.picked` which rule filled it (`lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`).
- **F04-2** (prior, not-checked) `plugins/codex-consult/scripts/codex-consult-common.ps1:4380`, `plugins/codex-consult/scripts/codex-findings.ps1:402`, `.collab/companions-2026-09-26/handoffs/01-claude-companions-design.md` - The brief's code fact invites a cross-task rating join by `n`, but `n` is unique only within a task and `Read-AllTaskConsults` flattens every task's consults and drops the task, so a repository-wide score joined on `n` mis-attributes ratings between tasks. Verify: Grep two different tasks' findings.json for the same rating `n` and confirm both exist, then confirm Read-AllTaskConsults returns both consults indistinguishably. Remedy: Score from the denormalised rating fields (provider, model, purpose, useful, when) with no join; where a join is unavoidable (topics), use `consult_id`. Extend Read-AllTaskConsults (or add a sibling) to carry the task slug if a join is ever needed.

### Unproven scenarios

- Full suite `19 harness(es), 0 failed` on BOTH hosts for the final code (CHANGELOG claim read, not executed: shell disabled).
- Live-intake DELETE confirm/refuse paths and proxy-egress behavior of the detached sender (no network use in this consultation).
- A genuine compaction event from an engine (installed codex reports none; counting logic read, harness-fed only).
- Real pgrep failure / unreadable-start-time kill on a live tree (harness fakes read, not executed).

### First-run checklist (observable)

- [ ] tests/run-all.ps1 on 5.1 and 7.6.6 both print `19 harness(es), 0 failed` on the final code.
- [ ] A dry run with CODEX_CONSULT_TEST_MODE=1 prints `WARNING: test mode is ON` once; a refused run prints none.
- [ ] A context_tokens member's ledger entry carries `compactions` (`unknown` on installed codex) right after `usage`, and its prompt ends `Before you answer, re-read the brief` before `Consultation id:`.
- [ ] `-Forget -PublicRef <wrong> -Local` exits 3, prints `NOTHING was deleted`, salt/spool byte-identical, no marker left.
- [ ] `-Forget -Local` prints the intake-still-holds line and asks `remove locally? [y/N]` unless `-Yes`.
- [ ] A flush log shows the 60 s bound covering local steps and `sender busy since` (never a takeover from a living owner).
- [ ] A torn journal line produces `health journal: N unreadable line(s) kept in <journal>.bad` in warnings[].
