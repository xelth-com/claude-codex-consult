---
name: consult-codex
description: Consult OpenAI Codex as a second reasoning partner through the bundled bridge script - at task framing, before a major decision, at a progress checkpoint, before accepting a substantial result, for a diff review, or when stuck. Runs one command, keeps the Codex thread alive across consultations, and records the brief, the verbatim reply and a ledger entry as files.
argument-hint: <task-id> [what you want Codex to judge]
allowed-tools: Bash(powershell:*), Bash(pwsh:*), Bash(codex:*), Read, Write, Glob, Grep
disable-model-invocation: false
---

# Consult Codex

Codex is a reasoning partner here, not an executor. **You keep the final word.**
It runs read-only by default: it reads the repository and answers, it does not edit.

Every consultation leaves two files you can commit — your brief and Codex's
verbatim reply — plus one entry in a JSON ledger. A `<task-id>` groups one
conversation: reuse the same id and the thread continues.

## When to consult

- **Framing** — before committing to an approach, to surface options you did not list.
- **Decision** — when weighing architectures, a fix order, or a trade-off with no obvious winner.
- **Checkpoint** — at a meaningful milestone, to catch drift early rather than at the end.
- **Core-contract checkpoint** — before dependent work builds on the core: once the
  interfaces, recovery and persistence paths exist, but before anything is built on top
  of them. Re-run it whenever recovery, persistence or an interface changes — a mechanical
  wave downstream of the core does not need its own review, but a change to the core does.
- **Acceptance** — before declaring a substantial result done.
- **Diff review** — an adversarial read of a change before it lands.
- **Stuck** — a different model often has the angle you are missing.

Several of these can be merged into one brief when they coincide. Skip the consult
for one-liners; the round trip costs more than the answer is worth.

## 0. Before a review brief: reconcile

Before a checkpoint, core-contract, acceptance or diff-review brief, run
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-findings.ps1" -Task <task> -List`
and read the current findings. Fix any drift
between what your own summary claims and what the tool actually shows — a coordinator's
"fixed" that has not been marked `verified`, a status that no longer matches the code —
before you write the handoff. A brief built on a drifted summary makes the reviewer
re-derive state that should already have been settled.

## 1. Write the brief

Write it yourself, in English, to
`.collab/<task>/handoffs/<NN>-claude-<slug>.md` — `<NN>` is the next free 2-digit
prefix in that `handoffs/` directory (the script picks the next one for its reply).
Create the directory if it does not exist. Start from a template:
`${CLAUDE_PLUGIN_ROOT}/templates/brief-framing.md` for framing, decision or stuck;
`${CLAUDE_PLUGIN_ROOT}/templates/brief-review.md` for checkpoint, core-contract,
acceptance or diff-review. Keep it to **one page**. When the thread is being resumed,
write the brief as a **delta since the last review** plus pointers, not a retelling —
but state the CURRENT invariants explicitly; history is not an authoritative
current-state record, and a delta-only brief hides anything that was already true and
still matters.

Do not paste the brief body into the prompt: Codex reads the file from the
repository; the prompt only points at it.

## 2. Run one command

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" -Task <task> -Mode fork -Purpose <purpose> -Brief .collab/<task>/handoffs/<NN>-claude-<slug>.md -Prompt "<one-line ask>" -ReplyName <slug>
```

On macOS and Linux (and on Windows with PowerShell 7 installed), use `pwsh -NoProfile -File` instead.

`-Purpose` selects the prompt paragraph Codex is asked to answer under, and its default
effort and word cap:

| `-Purpose` | Effort | Max words |
|---|---|---|
| *(none)* | high | 700 |
| `framing` | high | 700 |
| `decision` | high | 700 |
| `checkpoint` | medium | 500 |
| `core-contract` | xhigh | 900 |
| `acceptance` | high | 900 |
| `diff-review` | high | 700 |
| `stuck` | xhigh | 700 |

`-Effort` and `-MaxWords` override the preset when given. Options:

- `-Mode new` — no thread to build on yet. This is the default for a fresh task id.
- `-Mode fork` — branch from the last thread. The default once a thread exists, and
  the right choice whenever another client (Codex CLI, the desktop app) might still
  be appending to that thread.
- `-Mode resume` — sequential continuation of one thread, when nothing else writes to it.
- `-Thread <uuid>` — pick a specific parent. Omitted, the script takes the newest
  `codex.consults[].thread` from `.collab/<task>/sessions.json`.
- `-Model <name>` — omit it and Codex uses the model from the user's
  `~/.codex/config.toml`. Only pass it when the user asked for a specific model.
- `-Purpose <purpose>` (see table above), `-Effort low|medium|high|xhigh`,
  `-MaxWords <n>` (both override the preset), `-TimeoutSec <n>` (default 900),
  `-Sandbox read-only|workspace-write` (default `read-only`).
- `-Artifact <path>` — hash a built artifact (an executable, a bundle) into the ledger
  so the review is bound to it, not just to the source tree. Repeatable, or one
  comma-separated string (`-Artifact a.exe,b.dll`). A missing path refuses the run
  rather than silently skipping the binding.
- `-Raw` — 0.1-style plain-text reply: no structured schema, no findings bookkeeping.
  Use it for a quick informal ask that is not going into the findings ledger.
- `-CollabDir <path>` (default `.collab`), `-CodexExe <path>` if `codex` is not on `PATH`.
- `-DryRun` — print the argv, the resolved paths and the planned ledger entry without
  calling Codex. Use it when a call fails and you need to see what would be sent.

The script creates `handoffs/` and `sessions.json` when missing, and writes:

- `handoffs/<NN>-codex-<slug>.md` — header, the verbatim reply, and (unless `-Raw`)
  the rendered findings/verdict/blockers/unproven/first-run-checklist sections;
- `handoffs/<NN>-codex-<slug>.reply.json` — the raw structured reply, byte for byte
  (structured mode only);
- `handoffs/<NN>-codex-<slug>.events.jsonl` — the raw event stream;
- `findings.json` — every finding from this reply, appended (structured mode only,
  only when there is at least one finding);
- `sessions.json` — one ledger entry appended, the commit point for this consult.

It exits non-zero on failure and records the failure as an entry too, so the ledger
is a complete history and not just a success log.

## 3. Read, verify, record

Read the reply file. **Verify every finding yourself** before acting on it — open the
cited location, run the build, run the test. Codex proposes; you verify and decide.

Then record the outcome with the findings tool, not by paraphrasing it into a summary:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-findings.ps1" -Task <task> -Id F04-1 -Status implemented|verified|rejected|wontfix|superseded -Note "<why>" -Evidence "<what you ran / where the proof is>"
```

`verified` requires `-Evidence` — what you ran and what it showed, not just that you
believe it; `rejected` and a reopen (`-Status proposed` on a non-`proposed` finding)
require `-Note`; `superseded` requires neither. A reviewer reporting a finding "fixed"
in a later reply's `prior_findings` is evidence you can cite, never a status change by
itself: the coordinator still moves the status. A **still-open prior blocker** Codex
reports as `still-open` while itself answering `ACCEPT` invalidates that ACCEPT — the
script drops the verdict and records the contradiction, so an ACCEPT on a task with a
known open blocker is never quietly taken at face value. `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-findings.ps1" -Task <task> -Stats` prints effort, wall time, tokens
and finding counts per consultation — the R5 measurement of what each review purpose
actually cost and produced.

`-Id`/`-Status` holds the same task lock as a running consultation and is **refused**
while one is in progress for that task (under the same live-process rules, without ever
modifying the recovery record); `-List` (which flags `[ORPHAN]` findings — a crash
between the findings write and the ledger write) and `-Stats` only read and never take
the lock. `.consult.lock` is permanent and git-ignored — deleting it does nothing useful.
`.consult.pending.json` means an interrupted run; the next consultation recovers it
automatically unless a codex process from it is still alive, in which case it is
refused and the message says which pid.

## Role split

When a fresh-context verifier of the same model family (Claude) is also reviewing,
these are primary, not exclusive, responsibilities — either may challenge anything the
other says:

- **The verifier** is best used for mechanics: lint, interpreter/version compatibility,
  build correctness, test wiring, whether the code does what a summary claims it does.
- **Codex** is best used for protocol and state-machine correctness, and for naming
  what the evidence does not show — the failure modes a mechanical read does not surface.

On a real multi-wave task the two typically find mostly different defects; treat both
as required coverage, not as a redundant second look.

## Invariants

1. **Read-only by default.** Use `-Sandbox workspace-write` only when the user has
   explicitly made Codex the author of a stage. `danger-full-access` is refused by
   the script and there is no flag to force it.
2. **Exec options before the subcommand.** `codex exec [options] fork|resume <id>` —
   `--sandbox`, `--json`, `-o`, `-m`, `-c` and `--color` placed *after* `fork` fail
   with "unexpected argument". The script already gets this right; keep it that way
   if you edit the command.
3. **The prompt goes on stdin.** The script pipes it via `-`. A prompt passed as a
   positional argument is re-expanded by the Windows `codex.cmd` shim, which eats
   `%VAR%` patterns.
4. **Claude keeps the final word.** A consultation is evidence, not an instruction.
5. **Project isolation.** Everything is scoped to the git repository you run from:
   the ledger lives under `<repo>/<CollabDir>/<task>/`, the parent thread for
   `fork`/`resume` comes only from *that* repository's `sessions.json`, and a
   repository with no ledger starts a fresh thread. Never pass `-Thread <uuid>` taken
   from another project's ledger, and never point a brief at files outside the
   repository — the read-only sandbox blocks writes, not reads, so the brief is what
   keeps projects apart.
6. **One Codex thread belongs to one task directory.** Not enforced by the script —
   resuming the same thread from two different task directories is on you to avoid.
7. **A verdict is not an outcome.** `bridge_outcome` says the bridge worked — a reply
   came back and was written to disk. `verdict` says what the reviewer decided. A
   delivered HOLD is a success of the bridge: the run worked exactly as intended.
