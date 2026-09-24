# claude-codex-consult

Claude Code coordinates; **Codex is a standing reasoning partner you can call mid-task**.
This plugin adds one skill and one small PowerShell bridge so Claude can hand Codex a
one-page brief and get a judgement back — over your existing ChatGPT subscription, with
no API key. The same `<task-id>` keeps the Codex thread alive across consultations
(`fork` to branch, `resume` to continue), Codex runs in a **read-only sandbox** by
default, and every consultation lands on disk as a file pair — your brief and Codex's
verbatim reply — plus a JSON ledger entry. Consultations become reviewable history you
can commit next to the code they were about, instead of chat you lose. By default the
reply is structured — a verdict plus a list of findings with severity, location and
evidence — and every finding gets a stable id you track from proposed through verified.

Any Codex model works. Leave the model unset and Codex uses whatever is in your
`~/.codex/config.toml`; pass `-Model <name>` when you want a specific one.

---

## Install

```
/plugin marketplace add xelth-com/claude-codex-consult
/plugin install codex-consult@claude-codex-consult
```

Then just ask Claude to consult Codex, or invoke the skill directly:

```
/codex-consult:consult-codex my-task should we cache at the edge or in the worker?
```

### Requirements

| | |
|---|---|
| Claude Code | any recent version with plugin support |
| [Codex CLI](https://github.com/openai/codex) | **≥ 0.148** — `codex exec fork` landed there. Developed against 0.155.1 |
| Codex auth | signed in with your ChatGPT account (`codex login`). No API key needed |
| Shell | Windows PowerShell 5.1 (preinstalled on Windows) **or** PowerShell 7 (`pwsh`) on macOS/Linux/Windows |
| git | optional — used to locate the project root and stamp the reviewed revision |

---

## Usage

**1. Claude writes a brief** to `.collab/<task>/handoffs/<NN>-claude-<slug>.md`, starting
from `templates/brief-framing.md` or `templates/brief-review.md`. One page: question,
task state (or delta since the last review, plus the CURRENT invariants — history is not
an authoritative current-state record), evidence with `file:line`, alternatives weighed,
numbered questions Q1…Qn, a word cap.

**2. One command** (Claude runs this for you):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" `
    -Task my-task -Mode fork -Purpose diff-review `
    -Brief .collab/my-task/handoffs/03-claude-invalidation.md `
    -Prompt "Judge the invalidation strategy." -ReplyName invalidation
```

On macOS/Linux, `pwsh -NoProfile -File …` with the same arguments. `-Purpose` picks the
prompt paragraph and the default effort/word cap (see "Review purposes" below).

**3. The reply** is written to `.collab/<task>/handoffs/<NN>-codex-<slug>.md` — a header
(date, model, effort, Codex version, mode, purpose, parent thread, result thread, argv,
bridge outcome, verdict, findings summary, wall time) then `---` then the reply
**verbatim**, nothing paraphrased, then (unless `-Raw`) the rendered findings, prior
findings, verdict, blockers, unproven scenarios and first-run checklist. Next to it:
`<NN>-codex-<slug>.reply.json` (the raw structured reply) and
`<NN>-codex-<slug>.events.jsonl` (the raw event stream). See "Structured reply and
findings" below.

### The ledger

`.collab/<task>/sessions.json` records every call, including the ones that failed —
so the file is a history, not a success log. As of 0.2.0 the entry separates the
**bridge outcome** (did a usable reply come back) from the **verdict** (what Codex
decided), and carries the revision fingerprint and the findings summary:

```json
{
  "task_id": "my-task",
  "cwd": "/home/you/project",
  "codex": {
    "tool": "codex-cli 0.155.1",
    "consults": [
      {
        "n": 4,
        "when": "2026-09-22T11:24:27+02:00",
        "purpose": "diff-review",
        "parent_thread": "01a0c839-48ba-7182-8d15-fdc13dd17193",
        "thread": "01a0c86e-5193-7d70-a644-63a5c3f224b3",
        "thread_source": "events",
        "mode": "fork",
        "command": "codex exec --sandbox read-only --output-schema … --color never --json …",
        "brief": ".collab/my-task/handoffs/03-claude-invalidation.md",
        "prompt_chars": 212,
        "reply": "handoffs/04-codex-invalidation.md",
        "reply_json": "handoffs/04-codex-invalidation.reply.json",
        "events": "handoffs/04-codex-invalidation.events.jsonl",
        "model": "config default",
        "effort": "high",
        "max_words": 700,
        "sandbox": "read-only",
        "structured": true,
        "schema": "consult-reply v1",
        "validation_error": "",
        "base_commit": "4e9cc4f0…",
        "reviewed_revision": "4e9cc4f + uncommitted",
        "tree_sha256": "9c2a…",
        "tree_sha256_after": "9c2a…",
        "tree_changed_during_review": false,
        "changed_files": 3,
        "brief_sha256": "7b31…",
        "brief_sha256_after": "7b31…",
        "brief_changed_during_review": false,
        "fingerprint_note": "collab dir '.collab' excluded (2 entries); ignored files excluded; untracked file modes not recorded; submodules not recursed",
        "artifacts": [],
        "artifacts_changed_during_review": false,
        "bridge_outcome": "usable reply",
        "verdict": "HOLD",
        "verdict_reason": "one blocker in the invalidation path",
        "findings": { "blocker": 1, "major": 2, "minor": 0, "note": 1 },
        "finding_ids": ["F04-1", "F04-2", "F04-3", "F04-4"],
        "prior_findings": [{ "id": "F02-3", "status": "fixed" }],
        "unchecked_prior_blockers": [],
        "usage": { "input_tokens": 18400, "cached_input_tokens": 12000, "output_tokens": 900, "reasoning_output_tokens": 400 },
        "wall_seconds": 11.1
      }
    ]
  }
}
```

`thread_source` tells you where the thread id came from (`events`, the `rollout` file
fallback, or `unknown`). `bridge_outcome` is either `usable reply` or `failed: …` and
says only that the bridge worked; `verdict` (`ACCEPT`/`HOLD`/`REJECT`/`ADVISE`, empty
when unavailable) is what the reviewer decided — see "Role split" for why the two are
kept apart. `outcome` was renamed to `bridge_outcome` in 0.2.0; older entries with
`outcome` are left as written and only their `thread` field is read back.

The brief and every `-Artifact` are hashed under the lock **before and after** the run,
just like the tree (see "Binding a review to a revision"): `brief_sha256_after` and
`brief_changed_during_review`, and each `artifacts[]` entry's `sha256_after` plus the
overall `artifacts_changed_during_review`, catch a brief or artifact edited out from
under a long-running consult, independently of tree drift. `unchecked_prior_blockers`
lists the ids of open prior blockers Codex did not check while still answering ACCEPT
(see "Structured reply and findings").

### Review purposes

`-Purpose` selects the prompt paragraph Codex answers under, and the default effort and
word cap (`-Effort`/`-MaxWords` override either):

| `-Purpose` | Effort | Max words | Asks Codex to… |
|---|---|---|---|
| *(none)* | high | 700 | answer the brief with no preset framing |
| `framing` | high | 700 | surface options the brief did not list; challenge the framing |
| `decision` | high | 700 | rank the alternatives, name the deciding factor and each one's failure mode |
| `checkpoint` | medium | 500 | verify the CURRENT invariants the brief claims against the code as it is now |
| `core-contract` | xhigh | 900 | cover the interfaces, recovery/persistence paths and state machines named in the brief: states, transitions, the failure at each transition |
| `acceptance` | high | 900 | decide ACCEPT/HOLD/REJECT, with blockers, unproven scenarios and an observable first-run checklist |
| `diff-review` | high | 700 | an adversarial read: what breaks, what is not covered, what the tests do not prove |
| `stuck` | xhigh | 700 | find the angle the coordinator is missing; question assumptions before proposing fixes |

`acceptance` and `diff-review` ask for a verdict of `ACCEPT`/`HOLD`/`REJECT`; every
other purpose (and no purpose) asks for `ADVISE`. The word cap applies to the prose
(`reply_markdown`) only — findings are never truncated to fit it.

### Structured reply and findings

By default (unless `-Raw`) the script passes `--output-schema` and asks Codex for one
JSON object per the schema in `schemas/consult-reply.schema.json` (schema v1). Three
files record it per consult: the raw `.reply.json` (Codex's last message copied byte for
byte, never re-serialized), the rendered `.md`, and `<task>/findings.json` (only written
when at least one finding exists). Copying the raw reply happens FIRST, before it is
even parsed: if that copy fails, it is a bridge failure in its own right —
`bridge_outcome = "failed: could not preserve the raw reply (<error>); original kept at
<temp path>"` — the run exits non-zero with no verdict and no findings ingested, but the
ledger entry is still appended so the failure itself is on record.

Reply fields: `verdict`, `verdict_reason`, `reply_markdown` (the full prose answer),
`findings[]`, `prior_findings[]`, `unproven[]`, `first_run_checklist[]`. Each finding
carries `severity` (`blocker`/`major`/`minor`/`note`), `locations[]` (`{path, line}`,
empty when not tied to a place), `claim`, `trigger`, `evidence[]` (`{kind, reference,
observation}` — what Codex already checked; `kind` is `read-code`/`ran-command`/
`inferred`/`assumed`), `verification` (what you run next to confirm it), `remedy`, and
`supersedes[]` (ids of earlier findings this one replaces).

**Validation.** The script checks the parsed reply's exact shape against the schema:
every required field, legal enum values, `additionalProperties: false`, and `line`
either `null` or an integer in `1..2147483647` (an out-of-range or fractional value is a
validation error, never a crash). A structural error (not valid JSON, an unknown field,
a bad enum, a `null` where an array is required, a `line` out of range, …) means no
verdict and **no findings ingestion** — the raw text is kept as the reply body.
`Structured reply: INVALID (…) — raw text kept; no findings recorded.` is the header
line for that case; a JSON parse failure's `(…)` is the underlying .NET exception
message verbatim, so its wording follows the machine's UI language. A bridge-side bug
while parsing or ingesting an otherwise-valid reply (not the reviewer's fault) is
reported separately as `bridge could not process the reply: …`, also with no ingestion.

On top of shape, three semantic rules apply, and their messages are joined with `; ` in
`validation_error` when more than one fires:

- **the verdict must fit the purpose** — `ACCEPT`/`HOLD`/`REJECT` for `acceptance` and
  `diff-review`, `ADVISE` for every other purpose (and for no purpose). A mismatch is a
  validation error and the verdict is dropped (`''`), but findings are still ingested.
- **`ACCEPT` next to a new `blocker` finding is a contradiction** — findings are still
  ingested (a blocker is real evidence even when the reviewer's own verdict disagrees),
  verdict becomes `''`, `validation_error = "verdict ACCEPT contradicts N blocker
  finding(s)"`, header `Verdict: (invalid: ACCEPT contradicts N blocker)`.
- **`ACCEPT` next to a prior open blocker Codex reports `still-open`** is the same kind
  of contradiction — `validation_error` includes `"verdict ACCEPT contradicts still-open
  prior blocker F02-1"` and the verdict is dropped. But `ACCEPT` next to a prior open
  blocker reported `not-checked`, `unknown-id`, or simply not mentioned at all, is
  **not** a validation error — the verdict is kept, a `WARNING: ACCEPT with N unchecked
  prior blocker(s) (F02-1, …).` line is printed, and those ids are recorded in the
  ledger's `unchecked_prior_blockers`.

None of the three is a bridge failure by itself; `bridge_outcome` stays `usable reply`
whenever the text is non-empty. The rendered `### Blockers` section lists both new
blocker findings and retained prior blockers — the latter marked `(prior, still-open)`
or `(prior, not-checked)` — for every verdict, without creating a duplicate finding
record for a prior one.

**Finding ids and status.** Each finding gets `F<NN>-<k>` — `NN` the two-digit (or more)
handoff number of the reply that raised it, `k` its 1-based position in that reply's
`findings[]`. The stored record carries `id`, `status`, `severity`, `locations[]`,
`claim`, `trigger`, `evidence[]`, `verification`, `remedy`, `supersedes[]`,
`superseded_by[]` (filled on the OLD finding when a later one names it — bookkeeping,
not a status change), `source` (`{consult, reply, thread, base_commit, tree_sha256}`),
`history[]` (one entry per status change: `{when, status, by, note, evidence,
base_commit, tree_sha256}`), and `reviewer_checks[]` (one entry per later reply that
reported on it: `{consult, when, status, note, base_commit, tree_sha256}` — `status`
here is the reviewer's own `fixed`/`still-open`/`not-checked`, never the coordinator's
tracked status). Track it with `codex-findings.ps1`:

```
codex-findings.ps1 -Task <task> -List [-All]
codex-findings.ps1 -Task <task> -Stats
codex-findings.ps1 -Task <task> -Id F04-1 -Status implemented|verified|rejected|wontfix|superseded|proposed -Note "…" -Evidence "…"
```

`-List` shows open findings (`proposed`/`implemented`) by default, `-All` includes the
rest, and flags `[ORPHAN]` on a finding whose `source.consult` has no entry in
`sessions.json` or whose entry's `reply` file does not match, AND on a finding whose
`reviewer_checks[]` names a `consult` with no ledger entry — either is the signature of
a crash between a findings write and the ledger write (see "write order" below). A
closed finding that carries an orphan reviewer check is shown even without `-All`, since
the orphan itself is still open business. `-Stats` prints one line per consultation —
purpose, effort, wall time, output tokens, verdict, and a proposed/implemented/verified/
rejected count — the R5 measurement of what each review purpose costs and produces.
`-List` and `-Stats` only read and never take the lock; a status change (`-Id`/
`-Status`) does, so it is **refused** while a consultation for the same task is running
(see "The lock").

Status moves `proposed → implemented → verified`, with `rejected`, `wontfix` and
`superseded` as terminal-ish alternatives and `-Status proposed` on a non-`proposed`
finding as an explicit reopen — any status may follow any other, the history is the
audit trail. `verified` requires `-Evidence` (what you ran, not just that you believe
it); `rejected` and a reopen require `-Note`; `superseded` requires neither. A later
reply's `prior_findings` entry saying a finding is "fixed" is evidence you cite with
`-Evidence`, never a status change by itself — the coordinator moves the status. Every
status change is appended to the finding's `history[]`, never overwritten, with the
revision fingerprint of the moment it was made.

Write order per consult: `.reply.json` FIRST (the byte-for-byte copy, before the reply
is even parsed — see above), then the rendered `.md`, then `findings.json`, then
`sessions.json` last (the commit point). A crash between the findings write and the
ledger write leaves an orphan that `-List` flags rather than silently losing. A rerun's
next consult number and next handoff number are allocated past every existing ledger
`n`, every finding's `source.consult` and every `reviewer_checks[].consult`, every
existing `F<NN>` id, and any reservation left in `.consult.pending.json` by an
interrupted run (see "The lock") — in `-Raw` mode too — so nothing already written or
reserved is ever overwritten.

Both `sessions.json` and `findings.json` are written to a temp file in the same
directory and replaced atomically, so a kill mid-write leaves at worst a stray
`.<name>.<guid>.tmp` beside the store, never a truncated one. An *existing* store that
is empty, unparseable, not a JSON object, or (for `findings.json`) missing its
`findings` array, is treated as corruption and the run refuses — in every mode,
including `-DryRun` and `-List` — naming the file; it is never silently replaced with a
fresh, empty store, which would drop history.

### Binding a review to a revision

Every consult records `base_commit` (full SHA, or `unknown` without git),
`reviewed_revision` (short SHA, `+ uncommitted` when the tree is dirty — for humans),
and `tree_sha256`: the SHA-256 of a deterministic manifest built from
`git status --porcelain=v1 -uall -z` — one line per changed/untracked entry,
`<XY> <mode> <blob|deleted|dir> <path>[<TAB><rename source>]`, sorted by path (ordinal,
case-sensitive — `a.txt` and `A.txt` are distinct entries even on a case-insensitive
filesystem), so a rename changes the fingerprint and so does editing tracked content,
and so now does a file-mode change. `<mode>` comes from `git diff --raw HEAD`: `=` when
a tracked path's worktree content matches HEAD, `100644`/`100755`-style values (e.g.
`100644>100755`, `000000>100644` for a path new since HEAD) when it differs, and `u` for
an untracked entry, since git does not report a mode for those (`fingerprint_note` says
`untracked file modes not recorded`). **Values of `tree_sha256` computed before this
mode field was added are not comparable with values computed after** — treat a manifest
change across that boundary as expected, not as drift.

Paths under `<CollabDir>` are excluded from the manifest entirely — not just from the
hash, but from `changed_files` and from whether the tree counts as dirty at all, so a
tree whose only changes are under `.collab/` reads as clean and gets no `+ uncommitted`
suffix; the consultation's own output must not move the fingerprint of what it reviewed.
Submodule contents are not recursed (recorded as a `dir` entry). Every exclusion is
spelled out in `fingerprint_note`, e.g. `collab dir '.collab' excluded (2 entries);
ignored files excluded; untracked file modes not recorded; submodules not recursed` —
emitted whenever git is present, even on a fully clean tree; with no git at all,
`tree_sha256` is `""` and `fingerprint_note` is `"no git"`.

The brief and every `-Artifact` are hashed the same way, independently of the tree:
`brief_sha256` / each `artifacts[]` entry's `sha256` are taken **before** the run,
`brief_sha256_after` / `sha256_after` **after** it, all three under the same lock as the
tree fingerprint. A difference sets `brief_changed_during_review` or
`artifacts_changed_during_review` and prints its own header `WARNING: …` line,
independently of `tree_changed_during_review` — a brief or artifact edited out from
under a long-running consult is caught even when the rest of the tree never moved.

`-Artifact <path>` (repeatable, or one comma-separated string — `-Artifact a.exe,b.dll`
works the same as passing it twice, since `powershell -File` collapses a repeated
argument into a single string) hashes a built artifact into the ledger's `artifacts[]`
(`{path, sha256, sha256_after}`), so a review can be bound to what was actually built
and tested, not just to the source tree. A missing artifact path refuses the run rather
than silently reviewing without it.

### The lock

Ownership and recovery are two separate files, so ownership never needs deleting and
recovery never depends on a pid/start-time heuristic.

`<task>/.consult.lock` is a **permanent** file: created the first time a task is used
and never deleted afterwards. Owning it means holding it **open** — `codex-consult.ps1`
and `codex-findings.ps1 -Id/-Status` open it exclusively (Windows: `FileShare.Read`, so a
refused contender can still read who holds it; elsewhere: `FileShare.None`, which .NET
turns into an advisory `flock`) for the whole run, and release is just closing the
handle. Its content — `{pid, start_time, host, task, started}` — is informational only,
for the message a refused contender sees; nothing recoverable lives in it, so deleting
this file never "unlocks" anything and is pointless. `-List`/`-Stats` never open it. A
task directory always ends up with a `.consult.lock`; it is git-ignored.

`<task>/.consult.pending.json` is the recovery record, and exists only during a run or
after one that was interrupted — a clean run deletes it once its ledger entry is
committed. It moves through `reserved` (written before Codex starts) → `launching` →
`running` (once the child process is registered) → `survivors` (if a `-TimeoutSec` kill
could not stop the whole process tree). The **next** run reads and judges it before
writing anything: unreadable or malformed is refused as corruption, naming the file;
`running`/`survivors` naming a pid still alive on this host is refused
("a previous consultation's codex process (pid N) is still running…"); `launching` is
refused if a codex-looking process started at or after its `started` time is found (a
process scan, not a stored pid — the message says what was checked); a record from
another host naming pids is refused since they cannot be checked from here. Otherwise
the interrupted run is dead: its reservation is consumed (console line
`recovered reservation n=…, nn=…`, or `cleared the recovery record of consult n=…` when
that consult already reached the ledger) and only then is the file replaced. `-List`/
`-Stats` print a `pending: state=…, n=…, nn=…` line when it exists but take no lock;
`-DryRun` reports what the next run would recover, or that it would be refused and why.
This file is also git-ignored.

The user-facing rule is short: one consultation runs per task at a time; an interrupted
run leaves `.consult.pending.json` and the next consultation recovers it automatically
unless a codex process from it is still alive; never delete `.consult.lock` — it does
nothing useful and is not a recovery mechanism.

Documented but not enforced: one Codex thread belongs to one task directory — resuming
the same thread from two different task directories is on you to avoid.

### Role split

When a fresh-context verifier of the same model family is also reviewing, treat the
two as primary, not exclusive, responsibilities — either may challenge anything the
other says. The verifier is best used for mechanics: lint, interpreter/version
compatibility, build correctness, test wiring. Codex is best used for protocol and
state-machine correctness, and for naming what the evidence does not show. On a real
multi-wave task the two typically find mostly different defects.

### Project isolation

One user-scope install serves every project on the machine without mixing them,
because everything the bridge touches is scoped to the git repository it runs from:

- the ledger and every brief/reply pair live under `<repo>/<CollabDir>/<task>/`,
  where `<repo>` is `git rev-parse --show-toplevel` of the current directory (the
  current directory itself when it is not a git checkout);
- the parent thread for `fork`/`resume` is taken only from **that** repository's
  `sessions.json` — a repository with no ledger starts a fresh Codex thread;
- `codex` runs with the repository root as its working directory.

Verified 2026-09-23 with a throwaway repository: a `-Mode new` call produced a thread
with no parent, and Codex reported no context from any other project.

What the bridge cannot enforce: Codex's read-only sandbox blocks *writes*, not
*reads*, so a brief that cites a path outside the repository will be read. Keep briefs
inside the repository and never pass a `-Thread` id taken from another project's
ledger. Codex's own `memories` feature (see `codex features list`), if you enable it,
is a Codex-side channel across all your threads; the bridge neither reads nor writes it.

### Options

| Option | Default | |
|---|---|---|
| `-Task <id>` | *required* | Groups one conversation under `<CollabDir>/<id>/` |
| `-Mode new\|resume\|fork` | `fork` if a thread is known, else `new` | `fork` branches, `resume` appends |
| `-Thread <uuid>` | newest thread in the ledger | Pick a specific parent |
| `-Brief <path>` / `-Prompt <text>` | — | At least one is required |
| `-Model <name>` | *none* → your `config.toml` | Only passes `-m` when given |
| `-Purpose <purpose>` | *(none)* | Selects the prompt paragraph and the preset effort/words — see "Review purposes" |
| `-Effort low\|medium\|high\|xhigh` | preset default (`high` with no purpose) | Overrides the purpose's preset |
| `-Sandbox read-only\|workspace-write` | `read-only` | `danger-full-access` is refused |
| `-MaxWords <n>` | preset default (`700` with no purpose) | Overrides the purpose's preset; applies to prose only |
| `-Artifact <path>` | — | Repeatable; hashes a built artifact into the ledger. Missing path refuses the run |
| `-Raw` | off | 0.1-style plain-text reply: no schema, no findings bookkeeping |
| `-TimeoutSec <n>` | `900` | The process TREE is killed past this |
| `-CollabDir <path>` | `.collab` | Relative to the git repo root |
| `-ReplyName <slug>` | `reply` | Names the reply file |
| `-CodexExe <path>` | auto | Env override: `CODEX_CONSULT_EXE` |
| `-DryRun` | | Print argv, paths and the planned ledger entry; call nothing |

`-DryRun` is the first thing to reach for when a call misbehaves — it shows the exact
argv, the resolved launcher, the prompt that would go on stdin, and where every file
would land.

---

## How it works

Four things took real trial and error to get right. They are the substance of this
plugin; the rest is bookkeeping.

**1. Exec options must precede the subcommand.** `codex exec fork --help` has no
`--sandbox` or `--color`: those are options of `exec`, not of `fork`. The working form
is `codex exec --sandbox read-only --json -o <file> fork <thread> -`. Put `--sandbox`
after `fork` and Codex fails with *unexpected argument*.

**2. The prompt travels on stdin, never as an argument.** On Windows, `codex` is an npm
shim (`codex.cmd`), and `cmd.exe` still expands `%VAR%` inside double-quoted arguments.
A brief that mentions `%APPDATA%` would be silently rewritten. Passing the final `-`
and piping the prompt in avoids the shim's expansion entirely.

**3. The thread id comes from the first `--json` event.** Every run — `new`, `resume`
and `fork` alike — emits `{"type":"thread.started","thread_id":"…"}` as its first JSONL
line, and that id is the *resulting* thread, which is what you must record to continue
later. If the parse ever fails (version drift), the script falls back to the newest
`rollout-*-<uuid>.jsonl` under `$CODEX_HOME/sessions/<y>/<m>/<d>/` created after the run
started, and says so via `thread_source`.

**4. Two `Start-Process` traps on Windows PowerShell 5.1.** `-PassThru` returns an empty
`.ExitCode` unless you touch `.Handle` before the child exits, and the redirection
handles stay locked briefly after it exits, so reading the captured stdout right away
throws *the process cannot access the file*. The script caches the handle and reads with
`FileShare.ReadWrite` plus a short retry.

Everything else follows from those: failed runs are recorded as ledger entries too,
`danger-full-access` is refused with no flag to force it, and the reply file is written
even when the run failed (with the stderr tail as its body), so a failure is as
inspectable as a success.

---

## Why not X

Prior art exists. None of it was shaped like a *standing advisor thread with
fork + resume, a read-only sandbox, a committed file trail, and Windows support*, which
is why this plugin exists. All of these are worth a look if your shape is different.

| Project | Shape | Continuity | Why not here |
|---|---|---|---|
| [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) (official) | Claude Code plugin: `/codex:review`, `/codex:adversarial-review`, `/codex:rescue` + session hooks | resumes only its own latest thread; no chosen thread, no fork | Review/rescue shaped rather than an advisor you brief. Open Windows sandbox issue [#349](https://github.com/openai/codex-plugin-cc/issues/349) (sandbox modes fail, reviews come back empty) |
| [parisbs/codex-subagent-mcp](https://github.com/parisbs/codex-subagent-mcp) | MCP server: `codex_delegate`, `codex_follow_up`, background jobs | `resume` only, no `fork` | Closest fit, and the background-job model is genuinely nice. Delegation verified on macOS; no brief/reply file trail |
| [newtro/mcp-codex-bridge](https://github.com/newtro/mcp-codex-bridge) | MCP server: `codex_ask`, `codex_review`, `codex_implement` | none | No thread continuity at all — every call starts cold |
| [xihuai18/codex-mcp](https://github.com/xihuai18/codex-mcp) | MCP server: `codex_session` (with fork) + `codex_reply` | fork + reply | The only one with fork, but unmaintained for months while the Codex app-server protocol moved |
| [j-token/codex-mcp](https://github.com/j-token/codex-mcp) | MCP server over the Codex SDK | resume, no fork | Requires Bun; lightly maintained |
| [masuP9/agent-dialectics](https://github.com/masuP9/agent-dialectics) | Claude Code plugin: strong-inference / devil's-advocate skills | deliberately none — a fresh thread each time | A different and defensible philosophy; the opposite of a continuing thread |

Note: `codex mcp-server` was removed in Codex 0.154, and `codex app-server` is an
experimental JSON-RPC surface — which is part of why several MCP wrappers above drifted.
A thin wrapper around the documented `codex exec` CLI is the stable surface today.

---

## Tested on

| | |
|---|---|
| Windows 11 + Windows PowerShell 5.1 + Codex CLI 0.155.1 | dry-runs for `new` / `resume` / `fork`, every refusal path, brief resolution, and one live `new` consultation. The live call reached Codex and was rejected by the account's usage limit, which exercised the whole failure path: the thread id was still parsed from the live `thread.started` event, the error message was lifted from the event stream, the reply file and the ledger entry were written, and the script exited non-zero |
| PowerShell 7.6 (`pwsh`, Windows 11) | exercised on 2026-09-24 with the same fake-`codex` harnesses as 5.1 (structured parsing and validation, atomic stores, the lock and the recovery record, timeout tree kill, fingerprints): all green after one PS7-only fix — `ConvertFrom-Json` in pwsh turns ISO-8601 strings into `[datetime]`, which broke the start-time comparison used to recognise a live lock holder or codex child; the four affected reads now normalise through the library's JSON-text helper. Windows PowerShell 5.1 re-run afterwards, no regression |
| Linux (WSL Ubuntu 24.04, PowerShell 7.6, native ext4) | exercised on 2026-09-24 with a bash fake `codex`: dry run, a full structured run, lock contention through the advisory `flock` (second consult and `-Status` refused, `-List` works, lock inode unchanged), timeout with the process tree killed and no survivors, recovery of `launching` and `survivors` records through the `ps` scan, `chmod +x` changing the fingerprint, `$HOME/.codex` resolution, atomic `findings.json` replacement. Three Linux-only defects were found and fixed: a process start time read by .NET on Linux can differ by under a second between readers, so the exact comparison declared a live codex child dead (now a one-second tolerance off Windows); the holder's own lock file could not be read back through a shared `FileStream` (the advisory lock blocked it — read via `cat` off Windows); the timeout kill stopped children before the root, leaving a window for the root to spawn more (root first now). Known and left: an atomic replace resets Unix permission bits of the store to the default; dates in messages render in an invariant format |
| macOS | **not yet exercised** — the Linux run covers the same pwsh code paths, but no macOS machine was available |
| 0.2.0 (Windows 11 + Windows PowerShell 5.1 + Codex CLI 0.155.1) | harness tests with a fake `codex` shim (structured parsing and validation, fingerprinting, the lock, findings bookkeeping, crash and timeout paths), re-run by a fresh-context verifier with its own fixtures; and the release's own consultations, live, in `.collab/bridge-0.2-2026-09-23/`: a framing `new` (0.1 bridge), an acceptance `fork` and a re-acceptance `resume` on the structured path (`--output-schema`, fenced-or-bare JSON parsing, findings ingestion, `prior_findings` fed back, the lock held with the codex child pid inside, before/after fingerprints, tree-drift warning). Both live acceptance runs delivered a HOLD from the reviewer, which is the bridge working as intended; the findings are tracked by id in that task's `findings.json`. A second model (GLM-5.3 through a Codex `model_providers` entry) was smoke-tested on the same wire: it works, but `--output-schema` is not enforced on that route and the reply came back as a fenced JSON block (`.collab/multi-model-2026-09-23/`) |

Reports from a `pwsh` or macOS/Linux run are the single most useful contribution right now.

### Troubleshooting

A failing consultation is still a written record: read `.collab/<task>/handoffs/<NN>-codex-<slug>.md`
and the `outcome` field of the ledger entry. Codex reports quota, auth and turn failures
on the **JSON event stream**, not on stderr, so the script lifts the message from there —
e.g. `failed: codex exit 1 - You've hit your usage limit. … try again at 12:21 PM.`
For anything else, rerun with `-DryRun` and compare the argv.

---

## Roadmap / help wanted

`ROADMAP.md`'s review-workflow features R1–R6 and `TECH_DEBT.md`'s T1–T4 shipped in
0.2.0 — see [ROADMAP.md](ROADMAP.md) and [TECH_DEBT.md](TECH_DEBT.md) for the per-item
**Status (0.2.0)** lines, including what is partial or deferred and why. Still open, on
the earlier bridge-features help-wanted list: a bash port, a `UserPromptSubmit` hook
injector, the reverse direction (a Codex-side tool that consults Claude), an MCP server
variant with background jobs, and tests on macOS/Linux and PowerShell 7 generally.
(`--output-schema` support, also on that list, shipped in 0.2.0 as the substrate of R3.)
Planned for 0.3.0, agreed with two reviewers (Codex and GLM-5.3) on one brief: R7 provider
support with reviewer lineages (Codex CLI already runs a second model through a
`model_providers` entry, so a `-Provider` option reuses the whole ledger), R8 requested
checks, R9 review groups for fanning one brief to two reviewers — see ROADMAP.md for the
facts behind them, including that `--output-schema` is not enforced on a third-party route.
Issues and PRs welcome for any of these.

---

## Contributing

Keep the script dependency-free and dual-shell (5.1 and 7). If you change the `codex`
invocation, re-check the four gotchas above — they are load-bearing. Please include the
`-DryRun` output for any argv change, and say which shells and platforms you exercised.

## License

MIT — see [LICENSE](LICENSE). Author: xelth.com
