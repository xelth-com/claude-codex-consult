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
3. **Wait without blocking; keep the cache warm or compact (the idle watchdog).** Poll a state file -
   the worker's `STATE.md`, the bridge's `-Status` - instead of a blocking wait; message a worker or
   `-Kick` a member that hangs. The goal: a large context never loses its prompt cache by oversight.
   After the cache's lifetime the next request pays a cache WRITE of the whole context (a cold
   resume); a request inside the lifetime - a refresh - pays one cache read.
   - *Running work* keeps the wake armed and the idle count at zero: a worker or subagent of yours
     that has not reported; a detached panel or consultation (start a background `-Wait` - its exit
     is the notification); a long shell job you started (a suite, a build); a window you gave
     ANOTHER session, or a step of another session you depend on, until it says it is done; a step
     of the operator with a named end ("I install it and come back"); a cooldown with a named end
     (a provider's `retry_after`, a quota window) before a run you will repeat. Idle is only: none
     of these, and nothing can be done without the operator.
   - *The wake:* ONE recurring wake every 30 minutes (two marks an hour, off the round minutes),
     armed at the FIRST delegation or wait of the session and kept when the work ends. Every wake:
     small reads only (a state file's tail, a log's tail); a wake within a few minutes of any other
     activity answers in one line without a tool call. Anything finished or needing action is
     activity: act, and the idle count restarts at zero.
   - *The rule:*
     1. While running work goes on: keep the wake. No compaction in the middle of a wave.
     2. At a wave boundary (the report is read, the state is on disk): compact, or start a fresh
        session from the state file, before the next wave.
     3. A wait of known length: shorter than the boundary below - refresh; longer - compact first
        (while the cache is warm), then remove the wake and let something wake you at the end.
     4. Idle: idle wake 1 - one line in the state file ("idle since <time>"); idle wake 2 - write
        the handover, COMPACT, remove the wake.
     5. *No means to compact* (COMPACT is the host's means - "Means per host"; revision 6, the
        operator's decision of 2026-09-30): until the host lets the agent compact itself there are
        TWO states only. While work runs or is awaited (the running work above): keep the context
        warm ALWAYS, however long the wait. Idle: idle wake 1 - the note; idle wake 2 - write the
        handover on disk, REMOVE the wake, and tell the operator in one line the cheap ways back: a
        fresh session from the state file; or, to keep the conversation, a cheaper model whose
        window holds the context -> compact there -> back; and the launch option that bounds the
        context at the next start (`--autocompact <tokens>` where the host has it - "Means per
        host").
     6. Compact only while the cache is warm: after it expired a compaction costs a cold resume
        PLUS the summary (and the compact window's cold write at the resume).
     7. The operator's lever: the host's auto-compact threshold keeps the context small all the
        time.
     8. The moment was missed and the cache is cold: the context is read once at full price
        whatever comes next. Tell the operator the cheap ways: a fresh session from the state file,
        or switching the session to a cheaper model whose window holds the whole context,
        compacting there and switching back (README "Waiting", "a cold cache"). With a warm cache
        never switch the model.
   - *The boundary* (API prices of 2026-09, a wake every 30 minutes). Compact = one read of the
     context, a summary of about 10K output tokens and, at the resume, a cold write of the compact
     window of about 50K; keeping reads the context once too, at the resume - so keeping is cheaper
     while its wakes cost less than the summary and that cold write:

     | Context | Claude Fable 5.1: keep is cheaper up to | one wake | compact |
     |---|---|---|---|
     | 1M | 2.6 hours | 0.29 USD | 1.75 USD |
     | 850K | 3.0 hours | 0.25 USD | 1.71 USD |
     | 500K | 4.7 hours | 0.16 USD | 1.63 USD |
     | 300K | 6.8 hours | 0.11 USD | 1.58 USD |
     | 150K | 10.3 hours | 0.07 USD | 1.54 USD |

     The same rows on Claude Opus 5.5: 1.4, 1.6, 2.6, 4.1, 6.8 hours; on Claude Sonnet 5.5: 0.7,
     0.8, 1.4, 2.2, 4.1 hours. The reasons, the prices and the arithmetic: the repository README
     (<https://github.com/xelth-com/claude-codex-consult/blob/main/README.md>), section "Waiting:
     keep the prompt cache or compact".
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
   (Wave 29) The rule covers a `claude` member as well: the bridge fails a claude run when the working tree or the collab directory changed during it, as for agy.
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
`/compact` and the auto-compaction threshold (`/autocompact`; at launch `--autocompact <tokens>`,
`auto` or 100k to 1M - Claude Code 2.1.285 `--help`, checked 2026-09-30) are the operator's. The plugin's
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

**Qwen Code.** Documented, not run live. It installs this plugin as an extension and replaces the
plugin root in the skill text at the install, so these commands run as written; it lists no hook for
the extension - run the hook one-liner at the start. It reads the project's `AGENTS.md` beside its
`QWEN.md`. Shell tool limit: unknown - start a run with `-Detach`, then `-Wait` / `-Status`. COMPACT:
not verified (rule 3's no-means branch until it is).

**OpenCode.** Documented, not run live. No Claude-layout plugins: the operator links each skill
directory of a clone into `~/.config/opencode/skills/<name>`; it does not substitute the plugin root,
so the first sentence of this skill applies (`CODEX_CONSULT_ROOT`). No hooks: run the hook one-liner
at the start. Shell tool limit: unknown - `-Detach`, then `-Wait` / `-Status`. COMPACT: not verified
(rule 3's no-means branch until it is).

**Muse Code.** Documented, not run live as a coordinator. The operator installs each skill with
`muse skills install <path>` at PROJECT scope: Muse Code is also a reviewer engine of the bridge, and
a skill at user scope would reach the reviewer sessions too. Set `CODEX_CONSULT_ROOT` (the plugin
root is not known to be substituted) and run the hook one-liner at the start. Its shell tool is
PowerShell with a default wait of 10 s and at most 300 s: a run with a longer timeout goes with
`-Detach`, then `-Wait` / `-Status`. COMPACT: not verified (rule 3's no-means branch until it is).

The shell tool limits of Claude Code, Codex CLI, Qwen Code and OpenCode were not measured in the checks
of 2026-09-29: when yours is unknown, the `-Detach` rule above applies.

**A plain shell or any other host.** The watchdog is cron or a scheduled task that runs `-Status`;
the skill texts come from `codex-consult.ps1 -Explain coordinate|consult|providers`; the
session-start line from the hook one-liner.
