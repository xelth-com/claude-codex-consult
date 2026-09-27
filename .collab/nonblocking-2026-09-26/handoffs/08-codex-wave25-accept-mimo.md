# Handoff 08 - Codex: wave25-accept-mimo

Date: 2026-09-27 12:29 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\AppData\Local\Temp\claude\C--Users-Dmytro-claude-codex-consult\2e5096df-2bb2-46b1-8e0e-f97f37eaab90\scratchpad\roster-wave25-accept.json - position 3 of 8, panel 61db2121 member 2 of 5; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00), gemini :: gemini-3.8-flash-high [agy] (usage limit until 2026-09-28T21:30:55+02:00), gemini :: gemini-3.1-pro-high [agy] (usage limit until 2026-09-28T21:30:55+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 07eb1b48-4e5b-43a6-8c26-20a63ee76bf4.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-6df24f21c29a46d981a08652ff9f805c.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage mimo :: mimo-v2.6-pro in this task's ledger; other lineage(s): byteplus :: dola-seed-2.0-pro, byteplus :: deepseek-v4.1-flash, ZAI :: glm-5.3). Result thread: `01a0e269-c565-7253-aace-62a766d55fcc` (source: events).
Brief: `.collab/nonblocking-2026-09-26/handoffs/06-claude-wave25-acceptance.md` (sha256 c967403ebf8b). Reviewed: 00aebad, base 00aebadbf94d2d35388630cac50e1394ded8e287, tree sha256 8eb895998aeb, 0 changed files.
Bridge outcome: usable reply. Wall time: 1989.8 s. Tokens: in 1175955 (cached 445824), out 15917, reasoning 7856.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s.
Verdict: ACCEPT - Wave 25 fixes F02-1 through F02-11 and the remaining defects are minor robustness issues, not blockers or majors. Findings: 0 blocker, 0 major, 2 minor, 0 note (F08-1..F08-2, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/08-codex-wave25-accept-mimo.reply.json`.
Raw event stream: `handoffs/08-codex-wave25-accept-mimo.events.jsonl`.
Verbatim reply follows.

---

## 1. Prior findings

- **F02-1 fixed:** `.gitignore:26` adds `.consult.detached-*`, covering both status and log files.
- **F02-2 fixed:** foreground-only enforcement exists for codex and other launchers (`codex-consult.ps1:1926`, `2678`), preflight (`2555`), active panel/single recovery records (`1975`, `2775`) and the `.cmd` `%` hazard (`3044`). Not probing the task lock is the documented D2 limitation: exit 0 means started, not yet usable.
- **F02-3 fixed:** `Stop-WithError` records terminal state (`986-992`), while the background wraps argument decoding and the run in `try/finally` (`966-978`) and confirms the final record (`codex-consult-common.ps1:7262`).
- **F02-4 fixed:** `Get-DetachedBudget` covers serialized endpoint groups and `PanelConcurrency`, plus 120 seconds (`codex-consult-common.ps1:7184-7202`); `-Wait` reads `budget_sec` (`codex-consult.ps1:891`).
- **F02-5 fixed:** the foreground writes `starting` once before launch and never afterwards (`744-759`); the background self-reports `running` with pid, start time and host (`948-958`); pid-less `starting` becomes `never-started` after 60 seconds (`codex-consult-common.ps1:7161-7166`).
- **F02-6 fixed:** `Format-DetachedListLine` and `Get-DetachedPhrase` both use `Get-DetachedJudgement`, including `Test-PidAlive` (`codex-consult-common.ps1:7139-7176`, `7208-7254`; `codex-findings.ps1:172-175`; hook `91`).
- **F02-7 fixed/avoided:** D9 keeps per-task `.consult.`-prefixed files; the unsafe collab-root alternative is not implemented.
- **F02-8 fixed:** the background sets console and pipeline encodings to UTF-8 before its first output (`codex-consult.ps1:959-962`); `ENC` checks non-ASCII equivalence (`tests/harness-detach.ps1:645-663`).
- **F02-9 fixed:** member states include killed, blocked, commit_blocked and orphan with outcome text (`codex-consult.ps1:1889-1909`); the record includes host (`codex-consult-common.ps1:7055-7057`).
- **F02-10 fixed:** aggregate status is worst-state 2 > 1 > 0 (`codex-consult.ps1:919-925`); ambiguous prefixes refuse with exit 4 (`857-865`), and new ids avoid occupied id8 filenames (`719-725`).
- **F02-11 fixed:** `-Prune` is the only writing query form (`830`, `866-880`); `-Detach` rejects `-PanelSpec` (`998`); paths become absolute and the background receives the caller's working directory (`706-708`, `759`, `766`).

## 2. New defects

Two minor issues are recorded in `findings`: unreadable status files can never be pruned, and terminal status persistence is best-effort. Neither changes normal success semantics.

## 3. Acceptance

Accept. There is no blocker or major. The declared residuals are coherent: the lock/health race remains observable through `-Status`; killing only the background can leave members running; macOS/Linux detachment is untested. The harness covers single and panel lifecycles, budgets, waits, collisions, cwd, encoding, kills, outer failures and T4.

Verified by reading `git show 53de158:...` for the implementation and `tests/harness-detach.ps1`, plus repository metadata. Dynamic harness execution was outside this read-only consultation.

---

### Findings

- **F08-1** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:7141`, `plugins/codex-consult/scripts/codex-consult.ps1:872` - Unreadable detached status files are reported as failures but are excluded from every pruneable state, so corrupt or truncated status and log files accumulate forever even though the declared deviation groups unreadable files under the died/never-started family. Trigger: A detached status file becomes empty, truncated or invalid JSON, then ages past seven days and -Status -Prune runs. Evidence: read-code: Problems produce judgement state unreadable with exit 1.; read-code: Prune deletes only done, died and never-started; unreadable is skipped and cannot supply timestamps anyway. Verify: Create a `.consult.detached-aaaaaaaa.status.json` containing invalid JSON, backdate both files by eight days, then run `-Status -Prune` and observe that neither file is removed. Remedy: Let prune handle unreadable files by file timestamps after seven days, or add an explicit corrupt-state policy and document its retention rule.
- **F08-2** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:621`, `plugins/codex-consult/scripts/codex-consult.ps1:664` - Status persistence is deliberately best-effort and both intermediate and final write errors are swallowed, so a successful detached run can exit 0 while its status remains running or starting and later appears died. Trigger: The status path becomes read-only, locked, full or otherwise unwritable after the background self-report but before a member or terminal update. Evidence: read-code: Save-DetachedRun catches every update failure and continues.; read-code: Complete-DetachedRun catches the terminal write failure and does not change the process exit code. Verify: Run a faked detached consultation to completion while denying writes to its status file after self-report; compare the background exit 0 and complete log summary against a non-done status record. Remedy: Retry terminal writes with bounded backoff and, if persistence still fails, return a distinct non-zero exit while printing that the completed result exists only in the log.

### Prior findings

- F02-1 - fixed - `.gitignore:26` ignores `.consult.detached-*`.
- F02-2 - fixed - Launchers, preflight and active recovery records are enforced in the foreground; the lock race remains the accepted D2 limitation.
- F02-3 - fixed - Stop-WithError plus the background finally write terminal state.
- F02-4 - fixed - Panel serialization and concurrency are included in budget_sec.
- F02-5 - fixed - Foreground writes once before launch; background self-reports atomically; no-pid startup expires after 60 seconds.
- F02-6 - fixed - List and hook use the same pid/start-time liveness judgement as Status.
- F02-7 - fixed - The unsafe alternative was rejected; per-task prefixed runtime files remain.
- F02-8 - fixed - Background output encoding is UTF-8 before the first line.
- F02-9 - fixed - Distinct panel outcomes and host liveness metadata are represented.
- F02-10 - fixed - Worst-state aggregation and ambiguous-prefix refusal are implemented.
- F02-11 - fixed - Query writing rules, mutual exclusions, absolute paths and caller cwd are implemented.

## Verdict: ACCEPT

Wave 25 fixes F02-1 through F02-11 and the remaining defects are minor robustness issues, not blockers or majors.

### Blockers

_(none)_

### Unproven scenarios

- The harness was reviewed but not executed in this read-only consultation.
- macOS/Linux nohup detachment remains untested as declared.
- Real cmd.exe ShellExecute behavior with deeply nested quotes and unusually long absolute paths is covered only indirectly by the harness.

### First-run checklist (observable)

- [ ] The foreground returns exit 0 with exactly the detach id8, status/log paths and comeback commands, before the reviewer completes.
- [ ] The status changes from starting to running and records the background pid, start_time, host and budget_sec; args disappears after self-report.
- [ ] The log begins with the detached-run self-report and ends with the same summary block stored in the terminal status.
- [ ] -Wait exits 0 only after state=done and exit=0; every member is usable with n, handoff and wall_seconds, and no recovery record remains.
- [ ] -Status, codex-findings -List and the SessionStart hook agree on running, finished or died, and git status shows neither detached runtime file.
