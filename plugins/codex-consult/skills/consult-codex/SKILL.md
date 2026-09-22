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
- **Acceptance** — before declaring a substantial result done.
- **Diff review** — an adversarial read of a change before it lands.
- **Stuck** — a different model often has the angle you are missing.

Several of these can be merged into one brief when they coincide. Skip the consult
for one-liners; the round trip costs more than the answer is worth.

## 1. Write the brief

Write it yourself, in English, to
`.collab/<task>/handoffs/<NN>-claude-<slug>.md` — `<NN>` is the next free 2-digit
prefix in that `handoffs/` directory (the script picks the next one for its reply).
Create the directory if it does not exist. Keep it to **one page**:

- **Question** — the decision or judgement you need, in one or two sentences.
- **Task state** — base commit, what is done, what is open.
- **Evidence** — the relevant diff and `file:line` references. Name the base commit;
  do not commit or stash unrelated work just to produce a clean diff.
- **Alternatives** — the options you already weighed, and your current preference.
- **Numbered questions** — Q1, Q2, … Codex answers them by number.
- **Word cap** — say how long the answer may be.

Do not paste the brief body into the prompt: Codex reads the file from the
repository; the prompt only points at it.

## 2. Run one command

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" -Task <task> -Mode fork -Brief .collab/<task>/handoffs/<NN>-claude-<slug>.md -Prompt "<one-line ask>" -ReplyName <slug>
```

On macOS and Linux (and on Windows with PowerShell 7 installed), use `pwsh -NoProfile -File` instead.

Options:

- `-Mode new` — no thread to build on yet. This is the default for a fresh task id.
- `-Mode fork` — branch from the last thread. The default once a thread exists, and
  the right choice whenever another client (Codex CLI, the desktop app) might still
  be appending to that thread.
- `-Mode resume` — sequential continuation of one thread, when nothing else writes to it.
- `-Thread <uuid>` — pick a specific parent. Omitted, the script takes the newest
  `codex.consults[].thread` from `.collab/<task>/sessions.json`.
- `-Model <name>` — omit it and Codex uses the model from the user's
  `~/.codex/config.toml`. Only pass it when the user asked for a specific model.
- `-Effort low|medium|high|xhigh` (default `high`), `-MaxWords <n>` (default 700),
  `-TimeoutSec <n>` (default 900), `-Sandbox read-only|workspace-write` (default `read-only`).
- `-CollabDir <path>` (default `.collab`), `-CodexExe <path>` if `codex` is not on `PATH`.
- `-DryRun` — print the argv, the resolved paths and the planned ledger entry without
  calling Codex. Use it when a call fails and you need to see what would be sent.

The script creates `handoffs/` and `sessions.json` when missing, writes
`handoffs/<NN>-codex-<slug>.md` (header + verbatim reply) and
`handoffs/<NN>-codex-<slug>.events.jsonl` (raw event stream), appends one entry to
`codex.consults[]` with the parent and result thread ids, and prints the reply.
It exits non-zero on failure and records the failure as an entry too, so the ledger
is a complete history and not just a success log.

## 3. Read, verify, record

Read the reply file. Then write down — in the task's own notes, a commit message, or
`.collab/<task>/state.md` — what you adopted, what you rejected and why, and any open
disagreement.

**Never act on a Codex suggestion without verifying it yourself.** Open the cited
`file:line`, run the build, run the test. Codex proposes; you verify and decide.

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
