# R12 - non-blocking consultation (`-Detach`): design for review (wave 24) (base 46440f3)

Goal (ROADMAP R12): the coordinator puts a question to one reviewer or to a panel, goes on with
other work, and comes back to THAT question when the replies are in. Today a run holds the
coordinator's turn for its whole wall clock (a parallel acceptance panel: 15-30 minutes).

## Code facts the design builds on (0.4.0 candidate after wave 23)

- A single run: validates, takes `<task>/.consult.lock` (OS-held handle, released when the
  process ends), reads the recovery records, allocates n/NN, writes its record, launches the
  reviewer, waits, commits under `.consult.write.lock`, prints a summary block, exits 0/1.
- A `-Panel` run (wave 21): the parent process holds the task lock for the whole panel, writes
  one record per member, launches the members as child bridge processes (`-PanelSpec`), polls
  them every 500 ms, enforces a kill guard, prints one line per finished member and the summary.
  Everything a later reader needs is in `sessions.json` (the `panel` object on each member's
  entry) and the handoff files; nothing summarises the panel as a whole on disk.
- `codex-findings.ps1 -List/-Status` read the task's recovery records and refuse writes while a
  record is active (wave 21b). The SessionStart hook prints one availability line.
- `Get-CollabSnapshot` (agy and muse tree check) ignores names starting with `.consult.` - any
  new file under the collab root with another name fails a running agy/muse member.

## Design

1. `-Detach` on `codex-consult.ps1`, valid with a single run and with `-Panel`, refused with
   `-DryRun`, `-Status`, `-Wait`. The FOREGROUND process does everything a dry run does (roster,
   preflight, brief and prompt checks, the plan) - so a run that would be refused is refused
   now, in the coordinator's turn - then starts one BACKGROUND bridge process with the same
   arguments minus `-Detach` plus the internal `-DetachId <guid>`, and exits 0 printing three
   lines: the detach id, the status file path and how to come back (`-Status <id>` / `-Wait`).
   The foreground takes no lock and writes only the status file's first version (state
   `starting`), so a foreground failure leaves nothing to recover.
2. The background process is an ordinary bridge run (lock, records, numbering, members, kill
   guard, commit, summary) that ALSO maintains `<task>/.consult.detached-<id8>.status.json`
   (atomic replace): `{ id, started, state: starting|running|done, exit, task, kind: run|panel,
   members: [{position, lineage, state: pending|running|usable|failed|skipped, wall_seconds,
   n, handoff}], summary: <the same text a blocking run prints>, log }` - updated when the run
   starts, when each member finishes, and at the end. Its console output goes to
   `<task>/.consult.detached-<id8>.log`. Both names start with `.consult.` (ignored by the
   collab snapshot and gitignored by the existing patterns' extension `.consult.detached-*`).
3. Coming back: `codex-consult.ps1 -Task <t> -Status [<id8>]` prints the status of one detached
   run, or of every status file of the task without an id (newest first): the state, one line
   per member, and - when done - the exact summary block a blocking run prints, then exits 0
   (done, all usable), 1 (done with failures) or 2 (still running). `-Wait [-WaitTimeoutSec n]`
   polls the status file (2 s) until done and then behaves like `-Status`; the default wait
   timeout is the run's own budget (timeout + retries + 120 s), after which it exits 3 "still
   running" without touching the run. Neither command takes a lock or writes anything.
4. Liveness: the status file records the background pid + start time. `-Status` on a file whose
   state is not `done` but whose process is gone says "the detached run died; recovery records
   are judged by the next run as usual" (the existing recovery path applies: its member records
   and the task lock are the background process's, released with it). `-Wait` stops waiting
   when the process is gone.
5. `codex-findings.ps1 -List` gains one line per detached run of the task that is not yet done
   (`detached <id8>: running since <t>, k of N members finished`) and the SessionStart hook one
   phrase (`; 1 detached consultation running` / `finished`) for the current repository - both
   read status files only.
6. Retention: status and log files of done runs stay (they are small and gitignored); a new
   detached run with the same task leaves older ones alone; `-Status -Prune` deletes done ones
   older than 7 days.
7. The consult-codex skill: how to park a question (write the detach id and the brief path into
   the task's `state.md`, continue other work, never a second consultation on the same task
   until `-Status` says done - the task lock refuses it anyway), and when to revisit (after
   `done`, never before). Non-goals kept: no daemon, no queue, no notification channel beyond
   the status file, `-List` and the hook.

## Tests (fakes only)

A detached single run and a detached panel with delayed fakes: the foreground returns within
~5 s while the members run; `-Status` shows `running` and per-member states; `-Wait` returns the
blocking summary verbatim (compare with a blocking run of the same fakes); exit codes 0/1/2/3; a
refused run (missing brief, unavailable reviewer) is refused in the foreground with no status
file; the background process killed mid-panel -> `-Status` reports it died and the next run
recovers as today; `-Detach -DryRun` refused; `-List` and the hook lines; the status file name
is ignored by the collab snapshot (an agy member of a detached panel does not fail on it).

## Questions for the reviewers

Q1. Foreground validation "everything a dry run does" then a second, real run in the background:
    any check that can pass in the foreground and fail in the background (or vice versa) so the
    coordinator is misled?
Q2. Is a per-run status file under `<task>/` (ignored by the snapshot through the `.consult.`
    prefix) the right place, or should detached runs live under the collab root's own
    directory so `-List` across tasks is cheap?
Q3. `-Wait`'s default timeout: the run's own budget, or unbounded with a heartbeat?
Q4. Anything in the wave-21 panel parent that assumes an attached console (Write-Host to a
    console, the console encoding switch, Ctrl-C handling) and would misbehave when the parent
    itself is a detached background process?
