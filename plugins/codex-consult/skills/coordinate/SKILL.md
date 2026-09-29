---
name: coordinate
description: The coordinator's rules for running workers and consultations well with the codex-consult bridge - one objective per worker, a fresh worker per wave with its state on disk, waiting without blocking (poll a state file; -Detach, -Status, -Wait, -Kick), compaction at wave boundaries, never redoing a worker's work, English to reviewers, the live-member rule, rating every consultation, asking the operator before going on without a required reviewer - then the means each host offers for them and the worker tier contract. Use when you plan waves, delegate to workers, wait on a panel or a worker, or coordinate consultations.
argument-hint: "[what you are coordinating]"
allowed-tools: Bash(powershell:*), Bash(pwsh:*), Read, Glob, Grep
disable-model-invocation: false
---

# Coordinate

`${CLAUDE_PLUGIN_ROOT}` is the plugin directory; from a plain shell set `CODEX_CONSULT_ROOT` to it and use that instead.

You are the **coordinator**: the session that plans the work, hands chunks to workers, consults
reviewers through the bridge and keeps the final word on every reply (the judge). Workers
execute, reviewers advise, you decide. These rules hold on every host; the means differ, and
"Means per host" below maps them. The consultation procedure itself is the `consult-codex` skill
(`${CLAUDE_PLUGIN_ROOT}/skills/consult-codex/SKILL.md`); wiring reviewers is `setup-providers`.

## Invariants

1. **One objective per worker.** Brief a worker precisely the first time: the one objective, the
   exact files and context it needs, the reference numbers its result is measured against (test
   counts, the checks that must stay green), what it must not touch, and the shape of its report.
   A launch, a wait and a re-brief cost more than a brief written once.
2. **A fresh worker per wave, its state on disk.** A worker keeps a `STATE.md` (done, decided,
   next), writes logs and bulky output to files, and its report IS its written artifact (the
   CHANGELOG entry of the wave, or a report file). A worker never resumes a full context: the
   next wave starts a fresh worker that reads the files.
3. **Wait without blocking; the idle watchdog.** Poll a state file - the worker's `STATE.md`, the
   bridge's `-Status` - instead of a blocking wait; message a worker or `-Kick` a member that hangs.
   1. *Arming.* At your FIRST delegation of the session (a worker, a panel, a long shell job) arm
      ONE recurring wake, every 30 minutes, off the round minutes. It stays armed when the work
      ends - that is how idleness is noticed; only items 5 and 6 remove it, the next delegation
      arms it again.
   2. *Idle clock.* It counts from the LAST activity of any kind: the operator's last message, your
      own last action, the last worker, shell or panel that finished or reported. A worker running
      for two hours does not make the session idle when another finished ten minutes ago.
   3. *Every wake:* small reads only (a state file's tail, a log's tail). Anything finished or
      needing action is activity: act, and the idle count restarts at zero.
   4. *Something must wake you when work ends:* the host's completion notification (a worker, a
      background shell). A detached panel notifies nobody - start a background `-Wait` for it;
      its exit is the notification.
   5. *Nothing runs, nothing can be done without the operator:* idle wake 1 - one line in the state
      file ("idle since <time>"; the first may come sooner than 30 minutes); idle wake 2 - write
      the handover, COMPACT, remove the wake.
   6. *Something still runs, its remaining time unknown:* idle wakes 1 and 2 - check and note;
      idle wake 3 - write the handover, COMPACT, remove the wake (item 4 wakes you at its end). A
      job with a known end is waited for without compaction.
   7. *COMPACT is the host's means* ("Means per host"). Where the agent has none: at item 5's wake
      2 write the handover, remove the wake and tell the operator in ONE line ("idle <n> min;
      state in <file>; on return start fresh from it or compact first"); at item 6 KEEP the wake
      while the expected wait is under about nine hours (about twenty wakes cost one cold resume),
      past that write the handover and remove it. The operator's lever: the host's auto-compact
      threshold keeps every wake and every cold resume small.

   Why: a wake costs a cache read of the whole context, while a compaction costs about one such
   read and makes everything after it nearly free - so it must happen while the cache is warm.
4. **Compaction or a fresh session at wave boundaries**, not in the middle of a wave: the state
   files make the boundary loss-free, a mid-wave compaction does not.
5. **Never redo a worker's work.** Once a worker reports, read the report and verify in your own
   loop; do not re-derive, re-run or rewrite what it did. What still needs checking is a new,
   scoped task.
6. **English to reviewers and workers.** Briefs, prompts, follow-ups and handoff titles are in
   English; the operator's language belongs only in the conversation with the operator. Source
   material in another language is translated or summarised in English, never pasted.
7. **The live-member rule.** While an agy or muse member runs (a single run or a panel member,
   detached or not), NOTHING is written under the collab directory or the working tree - state
   files, notes and findings stores included - and no git command runs (commit, checkout, stash,
   pull). That binds your workers too: hold a writing worker until `-Status` says the panel is
   done, then write what you queued.
8. **Rate every consultation** once its reply is read:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-findings.ps1" -Task <task> -Rate <n> -Useful yes|partly|no -Note "<why>"`.
   A routed panel draws its seats from these marks.
9. **Ask the operator before going on without a required reviewer.** When a reviewer the topic
   needs is out (`codex-providers.ps1`), or `-Require` refuses the run (exit 5), tell the operator
   who is out and until when and ask whether to wait or to proceed; `-Require none` only after
   the operator agreed.
10. **Name your own model.** Set `CODEX_CONSULT_COORDINATOR` to `<provider> :: <model>` (or a
    roster position `#<n>`): the bridge then warns when it seats your own model as a reviewer - a
    second opinion from the coordinator's own model is not an independent one.

## The bridge's own means (every host)

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. On Windows use `powershell` (always present - `pwsh` there may be
only the WindowsApps alias, which a host's sandbox can refuse to execute); on macOS, Linux and a real
PowerShell 7 install use `pwsh -NoProfile -File` in place of `powershell -NoProfile -ExecutionPolicy Bypass -File`.

**Your shell tool's time limit (wave 27c).** A blocking bridge call is cut when the shell tool of your
host has a limit shorter than the run's timeout (a checkpoint run has 900 s, an acceptance 3600 s):
when that limit is shorter than the timeout of the purpose, or unknown, start the run with `-Detach`
and come back with `-Wait` or `-Status`. The limits seen are listed under "Means per host".

- `-Detach` - check a run (or `-Panel`) like a real run, park it in a background process and
  return at once with its id, its status file and the come-back commands.
- `-Status [-Id <id8>]` - read the status files only: exit `0` done and usable, `1` a failure,
  `2` still running, `4` the query is refused. The poll of rule 3.
- `-Wait [-Id <id8>]` - block until done (default: the run's budget). Only when there is nothing
  else to do.
- `-Kick -Member <NN> [-Id <id8>]` - stop ONE member that hangs (its handoff number); its partial
  output is salvaged and the panel goes on.

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" -Task <task> -Panel -Purpose acceptance -Brief <brief> -ReplyName <slug> -Detach
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" -Task <task> -Status -Id <id8>
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" -Task <task> -Kick -Member <NN> -Id <id8>
```

A host without skills reads this text and the other skills with
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" -Explain coordinate`
(`consult`, `providers`). The session-start line (which reviewers are out, until when) comes from
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult-hook.ps1"`
when the host runs no plugin hooks.

## Worker tiers (the contract)

Pick the tier by what the task needs; the tier names stay, the models behind them change.

| Tier | For | Writes | Report |
|---|---|---|---|
| **deep reasoning** (`opus-worker`) | a self-contained chunk that needs real reasoning: novel code, multi-file debugging, build-and-fix loops, design judgment inside a fixed objective | yes | files changed (one line each), the verification run and its result, what the coordinator must know to continue |
| **default execution** (`sonnet-worker`) | well-specified, pattern-following work: a known change across files, tests to an existing pattern, doc updates, running a suite and reporting | yes | the same |
| **cheap read-only recon** (`haiku-worker`) | locating code, mapping a surface, log and output analysis, running a command and reporting what it printed | never - it edits nothing | what it found, with `file:line` and the commands it ran |

Delegate a chunk when it is self-contained, heavy or noisy (many reads, bulky output), or one of
several independent pieces - fan those out in ONE turn. Keep one-liners and quick lookups: a
worker is a cold start. A worker never starts or finishes the overall task and never commits
unless its brief says so.

## Means per host

**Claude Code.** Workers are subagents by tier: the plugin ships `agents/opus-worker.md`,
`agents/sonnet-worker.md` and `agents/haiku-worker.md` (`codex-consult:opus-worker` and so on)
with the model aliases `opus`, `sonnet`, `haiku` - stable aliases, never versions; a
same-named agent of your own (`~/.claude/agents/`, the project's `.claude/agents/`) is yours to
keep. Run workers in the background; the watchdog of rule 3 is a scheduled wake (a timed
wake-up or a monitor on the state file). COMPACT: the agent has no means (verified 2026-09-29 -
a scheduled prompt `/compact` arrives as ordinary text), so rule 3's no-means branch applies;
`/compact` and the auto-compaction threshold (`/autocompact`) are the operator's. The plugin's
SessionStart hook prints the availability line and the pointer to these rules.

**Codex CLI.** Workers are agent files the OPERATOR keeps in `~/.codex/agents/<tier>.toml`, each
with `name`, `description` and `developer_instructions` and NO model key (the host picks the
model): the plugin ships examples to copy in `${CLAUDE_PLUGIN_ROOT}/install/examples/codex-agents/`
and never writes an agent file itself. Wave boundaries: the `SubagentStop` and `PreCompact`
hooks; the watchdog: a background shell that sleeps, then reads the worker's `STATE.md` or runs
`-Status`. COMPACT: an operator command, not verified for a scheduled prompt - until it is, use
rule 3's no-means branch. The plugin's SessionStart hook runs when the host runs plugin hooks
(trusted); when no `codex-consult:` line is in your context at the start, run the hook one-liner
above.

**Z Code.** It installs this plugin with its own plugin manager (a Claude-layout plugin) and
substitutes the plugin root in the skills and the hook, so these texts and the SessionStart line
work unchanged; it reads `AGENTS.md`. The bridge infers your host as `zcode`; still set
`CODEX_CONSULT_COORDINATOR` to the model the app runs. COMPACT: an operator command, not
verified for a scheduled prompt (rule 3's no-means branch until it is). Shell tool limit: 600 s (seen
2026-09-29) - a run with a longer timeout goes with `-Detach`. Its shell tool carries ZCODE_APP_VERSION and
ZCODE_PROCESS_LABEL (the hint `zcode`), not ZCODE_SESSION_ID; no `codex-consult:` session-start line
reached a desktop session (2026-09-29) - the second `AGENTS.md` line (the hook one-liner) covers it.

**Kimi Code.** No plugin system and no hooks: the operator starts `kimi` with
`--skills-dir <clone>/plugins/codex-consult/skills` and sets `CODEX_CONSULT_ROOT` - it does not
substitute the plugin root, so the first sentence of this skill applies (its shell tool on
Windows is Git Bash). Run the hook one-liner at the start; `AGENTS.md` is read from the working
directory only. It sets no host marker (`coordinator.host` stays `unknown`): name yourself in
`CODEX_CONSULT_COORDINATOR`. A headless `-p` run takes neither `--yolo` nor `--auto`. Shell tool limit: 300 s in the foreground (seen
2026-09-29) - a run with a longer timeout goes with `-Detach`. COMPACT: an operator command, not
verified for a scheduled prompt (rule 3's no-means branch until it is).

The shell tool limits of Claude Code and Codex CLI were not measured in the checks of 2026-09-29: when
yours is unknown, the `-Detach` rule above applies.

**A plain shell or any other host.** The watchdog is cron or a scheduled task that runs `-Status`;
the skill texts come from `codex-consult.ps1 -Explain coordinate|consult|providers`; the
session-start line from the hook one-liner.
