# Handoff 07 - Codex: wave25-accept-zai

Date: 2026-09-27 12:29 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave25-accept.json - position 2 of 8, panel 61db2121 member 1 of 5; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 760ca854-45fa-409c-b261-e4fa1e30719f.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-26a5581615314c79abd9320a948c3846.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a0dcd1-4094-7fb1-b667-bc0301007f74 -` (prompt on stdin).
Parent thread: `01a0dcd1-4094-7fb1-b667-bc0301007f74`. Result thread: `01a0e269-c793-7dc1-9470-d64c06ad11be` (source: events).
Brief: `.collab/nonblocking-2026-09-26/handoffs/06-claude-wave25-acceptance.md` (sha256 c967403ebf8b). Reviewed: 00aebad, base 00aebadbf94d2d35388630cac50e1394ded8e287, tree sha256 8eb895998aeb, 0 changed files.
Bridge outcome: usable reply. Wall time: 1015.1 s. Tokens: in 5635818 (cached 5158208), out 65101, reasoning 39700.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s.
Verdict: ACCEPT - All eleven prior findings are implemented with code and tests at 53de158, the declared deviations are reasonable, and only minor residuals remain - no blocker or major. Findings: 0 blocker, 0 major, 2 minor, 1 note (F07-1..F07-3, tracked in `findings.json`). Structured reply: `handoffs/07-codex-wave25-accept-zai.reply.json`.
Raw event stream: `handoffs/07-codex-wave25-accept-zai.events.jsonl`.
Verbatim reply follows.

---

## 1. F02-1..11 at 53de158
- **F02-1 fixed** - .gitignore:26 `.consult.detached-*`; I ran `git check-ignore` here: status and log ignored, sessions.json still not.
- **F02-2 fixed** - `$detachForeground` (codex-consult.ps1:996-1004) makes the launcher checks (1926, 1941, 2675-2678), the preflight refusal (2555), the ACTIVE-record refusal (1975, 2775) and the `.cmd` % hazard (3044) refuse in the foreground; the lock and time-dependent selection remain a documented benign window (CHANGELOG 108-110). The REFUSE tests cover exactly the cases a dry run only reports.
- **F02-3 fixed** - outer try/finally 966-979 plus `$script:StopWithErrorHook` 986-992 (Stop-WithError honours it, common 261-263); Complete-DetachedRecord (7262-7282) is idempotent; OUTER/REFUSEDBG cover a thrown run and a refusal after start.
- **F02-4 fixed** - budget_sec computed at detach (2023-2025 panel, 3045-3046 single) by Get-DetachedBudget (common 7184-7203): max(group waves x group guard, ceil(N/cap) x longest guard) + 120 - both terms relax the real schedule, so the maximum upper-bounds the makespan; -Wait defaults to it (889-894, fallback 3600).
- **F02-5 fixed** - `starting` written once, before launch (744-752), never after; the background self-reports {running, pid, start_time, host} first (948-958); -Status reads starting under the 60 s grace, then never-started (7161-7166).
- **F02-6 fixed** - the -List line (Format-DetachedListLine 7208-7213) and the hook phrase (Get-DetachedPhrase 7219-7254) both judge liveness via Get-DetachedJudgement/Test-PidAlive; -Prune removes died too (872). KILL asserts all three surfaces say died.
- **F02-7 fixed as decided (D9)** - per-task prefixed files; the snapshot prefix rule verified in code (common 649-651) and by the AGY test (status file, log and atomic temp never enter the snapshot).
- **F02-8 fixed** - `[Console]::OutputEncoding` and `$OutputEncoding` UTF-8 before the first output (960-961); the ENC case runs under PS 5.1 and pwsh.
- **F02-9 fixed** - the full member enum incl. killed/blocked/commit_blocked/orphan (common 6989; Get-PanelSlotDetachState 1892-1909) plus the outcome phrase; the record carries host (7057); another host is never judged (7168-7171).
- **F02-10 fixed** - worst-state aggregate (919-925); an ambiguous -Id prefix refused with exit 4 naming the matches (864); an id8 is taken only when free (719-726) - COLLIDE.
- **F02-11 fixed** - the option matrix enforced (826-842, 927-929, 998-999); Brief/Artifact/CollabDir absolute and WorkingDirectory = the foreground cwd (706-708, 759/766) - CWD test; and `-Task` is slug-validated (1509, 835), so the unquoted `-Task` on the cmd line cannot carry a space, `%` or quote.

## 2. New defects
No blocker or major found. Three small ones:
- **finding #1 (minor)**: an unreadable status file is never pruned (-Status -Prune skips `unreadable`, codex-consult.ps1:872) while the hook counts it as died forever (common 7230).
- **finding #2 (minor)**: after the 60 s grace the never-started wording asserts `nothing was run` (common 7166) - a background that is merely slow (>60 s cold start, AV scan) can still self-report later and flip the record to running, so the transient claim can be wrong.
- **finding #3 (note)**: the hook now dot-sources the whole ~7,100-line common file (hook 89-93) on every session start, on top of its codex-providers child process.

Verified in code: the foreground/background split (597-1004), the launch lines and the % guard (727-773), the -Status/-Wait/-Prune flow (817-929), the judgement/budget/record/args helpers (common 6953-7313), every member-update site (2040-2047, 2133-2164, 2271-2277, 2911, 3355, 4250-4252, 4588-4632), the -List/hook/.gitignore/T4 diffs, and harness-detach's 46 assertions (counted). Ran: `git check-ignore` only. Inferred: the cmd ShellExecute launch and the harness's runtime pass (not executable read-only); the macOS/Linux nohup branch is untested by the implementer's own declaration.

## 3. Verdict
ACCEPT - every prior finding is implemented with a test, the declared deviations are sound, and only minor residuals remain.

## Requested checks
- RC1: repo root (workspace-write): `powershell -NoProfile -ExecutionPolicy Bypass -File tests\harness-detach.ps1`, then the same under `pwsh`; observation: 46/46 pass under both hosts, settling the runtime claims (launch, encoding, OUTER, budget); budget ~10 min each.
- RC2 (first real run, workspace-write): run the documented `-Detach` acceptance-panel command on a live task; observation: foreground back in seconds, -Status 2 then done, -Wait's summary identical to the log; settles the real-reviewer path the fakes cannot; budget one run.

---

### Findings

- **F07-1** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:872`, `plugins/codex-consult/scripts/codex-consult-common.ps1:7230` - An unreadable status file (present but empty, unparseable, no id, bad state) is never pruned - -Status -Prune skips the `unreadable` judgement - and the SessionStart hook counts it in the died phrase indefinitely, so one corrupted file permanently degrades -Status (exit 1), -List and the hook with no cleanup path. Trigger: A .consult.detached-<id8>.status.json corrupted or truncated by an external writer, then more than 7 days later -Status -Prune. Evidence: read-code: The prune loop continues past every run whose judgement is not done/died/never-started; `unreadable` is not in the list, and its Record is null so no age is even computed.; read-code: Get-DetachedPhrase maps died, never-started AND unreadable into the permanent `died` category. Verify: Fabricate an unparseable .consult.detached-deadbeef.status.json with an old file time, run -Status -Prune, and observe the file still present and still counted by the hook phrase. Remedy: Treat `unreadable` as prunable after the same 7-day window (using the file's last-write time, as Read-DetachedRuns already records), or add -Prune -Force for unreadable files.
- **F07-2** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:7166`, `plugins/codex-consult/scripts/codex-consult-common.ps1:6985` - After the 60-second grace a `starting` record without a pid is reported as never started with the categorical wording `nothing was run`, but a slow background (cold start, antivirus, >60 s host spin-up) may still self-report afterwards and turn the record into running - the transient judgement can state a falsehood and, in -Prune's view, mark the run prunable as never-started 7 days later even though it ran. Trigger: A machine where spawning the hidden host plus parsing the 4,600-line script takes more than the fixed 60 s grace between the foreground's write and the background's self-report. Evidence: read-code: The grace is a fixed $script:DetachedStartGraceSec = 60; past it the text asserts nothing was run.; read-code: The self-report happens only after the host started, resolved the repo/collab roots and read the status file - measurable delay on a cold machine.; inferred: Spin-up beyond 60 s is plausible; not measured here. Verify: Suspend the background process at start (or add a test hook delaying the self-report), run -Status after 61 s, then resume: observe never-started wording followed by a record that becomes running. Remedy: Word the never-started text conditionally (`no background process reported within 60 s ... its log may say why` already helps; drop `nothing was run` or add `if it started at all`), and let -Prune also require the log to be absent or empty before treating never-started as never having run.
- **F07-3** [note] `plugins/codex-consult/scripts/codex-consult-hook.ps1:90` - The SessionStart hook now dot-sources the entire codex-consult-common.ps1 (~7,100 lines) in its own process on every session start, in addition to spawning codex-providers.ps1 - a small but permanent latency addition to every session for one phrase. Trigger: Every Claude Code session start in a repository with the plugin enabled. Evidence: read-code: The new try block dot-sources common and calls Get-DetachedPhrase; before wave 25 the hook started no other PowerShell parsing beyond its child process.; inferred: Parsing 7,100 lines typically costs a few hundred ms; not measured here. Verify: Time the hook (`Measure-Command` around its invocation) at HEAD and at c4cb428 in the same repo; compare. Remedy: Accept the cost, or split the detached-run readers (Read-DetachedRuns, Get-DetachedJudgement, Get-DetachedPhrase) into a small file the hook can dot-source alone.

### Prior findings

- F02-1 - fixed - .gitignore:26 `.consult.detached-*`; verified by running git check-ignore on both names (ignored) and on sessions.json (not).
- F02-2 - fixed - $detachForeground makes launchers (1926, 1941, 2675-2678), preflight (2555), the active record (1975, 2775) and the % hazard (3044) refuse in the foreground; lock and time-dependent selection are the documented benign window.
- F02-3 - fixed - Outer try/finally 966-979, StopWithErrorHook 986-992 + common 261-263, idempotent Complete-DetachedRecord 7262-7282; OUTER/REFUSEDBG tests.
- F02-4 - fixed - budget_sec at detach (2023-2025, 3045-3046) via Get-DetachedBudget (7184-7203), -Wait default 889-894; the bound is mathematically sound.
- F02-5 - fixed - starting once before launch (744-752), background self-report first (948-958), 60 s grace then never-started (7161-7166).
- F02-6 - fixed - -List (7208-7213) and the hook (7219-7254) judge liveness via Test-PidAlive; -Prune removes died (872); KILL asserts all three surfaces.
- F02-7 - fixed - Per-task prefixed files kept (D9); snapshot prefix rule confirmed in code (common 649-651) and by the AGY harness case.
- F02-8 - fixed - UTF-8 console and output encoding before first output (960-961); ENC case under PS 5.1 and pwsh.
- F02-9 - fixed - Full member enum + outcome (common 6989, 1892-1909); host on the record (7057); elsewhere never judged (7168-7171).
- F02-10 - fixed - Worst-state aggregate (919-925), ambiguous prefix exit 4 naming matches (864), free-id8 pick (719-726) + COLLIDE test.
- F02-11 - fixed - Option matrix (826-842, 927-929, 998-999), absolute Brief/Artifact/CollabDir and WorkingDirectory = callerCwd (706-708, 759/766), CWD test; -Task slug-validated (1509, 835) so the unquoted cmd-line -Task is safe.

## Verdict: ACCEPT

All eleven prior findings are implemented with code and tests at 53de158, the declared deviations are reasonable, and only minor residuals remain - no blocker or major.

### Blockers

_(none)_

### Unproven scenarios

- The harness's runtime pass (46 assertions under Windows PowerShell 5.1 and pwsh) - read only, not executed in this read-only consultation.
- The Windows cmd.exe ShellExecute launch line (`/d /v:off /s /c` with the nested quotes and `<NUL 1>log 2>&1`) on hosts other than this one - accepted on the harness's design plus the implementer's report.
- A detached run against real reviewers (all tests use fakes).
- The macOS/Linux `/bin/sh -c 'exec nohup ...'` branch - declared untested by the implementer.
- SessionStart hook latency with many task directories after the common dot-source - inferred small, not measured.

### First-run checklist (observable)

- [ ] The first real -Detach foreground returns within seconds printing the three `Detached <id8>` lines, and `git status` afterwards shows no .consult.detached-* entry.
- [ ] While it runs, `-Status` exits 2 with `running since ..., k of N members finished`, the background pid and host shown, and the .log grows as valid UTF-8 (no mojibake).
- [ ] At completion `-Wait` exits 0 and its printed summary block matches the log's summary byte-for-byte (modulo panel id and times), with ledger entries and handoffs exactly as a blocking run's.
- [ ] With the task lock deliberately held, a -Detach background's status reaches done with exit 1 and the refusal line as its summary (so -Status exits 1, not a stuck starting or a false died).
- [ ] After killing the background mid-run, -Status, codex-findings -List and the SessionStart hook all say died within one poll cycle, and the next run of the task consumes the recovery records.
- [ ] The SessionStart hook still exits 0 with the detached phrase appended and no noticeable extra startup delay.
