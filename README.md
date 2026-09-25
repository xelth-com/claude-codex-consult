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
        "consult_id": "8f6a1e2d-...",
        "reviewer": {
          "provider": "ZAI",
          "provider_source": "-Provider",
          "model": "glm-5.3",
          "model_source": "-Model",
          "harness": "codex-cli 0.155.1",
          "provider_fingerprint": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85",
          "provider_config": { "base_url": "https://api.z.ai/...", "wire_api": "responses" },
          "identity_note": ""
        },
        "lineage": "ZAI :: glm-5.3",
        "preflight": "ok: env ZAI_API_KEY set",
        "preflight_warning": "",
        "parent_thread": "01a0c839-48ba-7182-8d15-fdc13dd17193",
        "thread": "01a0c86e-5193-7d70-a644-63a5c3f224b3",
        "thread_source": "events",
        "thread_candidate": "",
        "mode": "fork",
        "command": "codex exec --sandbox read-only --output-schema … --color never --json …",
        "brief": ".collab/my-task/handoffs/03-claude-invalidation.md",
        "prompt_chars": 212,
        "reply": "handoffs/04-codex-invalidation.md",
        "reply_json": "handoffs/04-codex-invalidation.reply.json",
        "events": "handoffs/04-codex-invalidation.events.jsonl",
        "model": "glm-5.3",
        "effort": "max",
        "effort_requested": "xhigh",
        "effort_sent": "max",
        "effort_mapping": "zai-v1",
        "effort_caps": "caps-v1",
        "effort_confirmed": null,
        "max_words": 700,
        "sandbox": "read-only",
        "extra_config": [],
        "peak": false,
        "peak_schedule": "Mon-Fri 14:00-18:00 +08:00",
        "peak_source": "env",
        "peak_evaluated_at": "2026-09-22T11:24:27+08:00",
        "structured": true,
        "schema": "consult-reply v1",
        "schema_transport": "output-schema",
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
        "provider_failure": null,
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

`thread_source` tells you where the thread id came from: `events`, `rollout (verified by
consultation id)`, or `unknown` (as of 0.3.0 a rollout candidate is never trusted without
that verification — see "A second reviewer through the same bridge"). `bridge_outcome`
is either `usable reply` or `failed: …` and
says only that the bridge worked; `verdict` (`ACCEPT`/`HOLD`/`REJECT`/`ADVISE`, empty
when unavailable) is what the reviewer decided — see "Role split" for why the two are
kept apart. `outcome` was renamed to `bridge_outcome` in 0.2.0; older entries with
`outcome` are left as written and only their `thread` field is read back.

As of 0.3.0, `consult_id`, `reviewer{…}` and `lineage` identify which model actually
answered (see "A second reviewer through the same bridge"). Inside `reviewer`,
`provider_source` is one of `-Provider`/`config`/`codex default`/`unknown` (how the
provider was decided) and `identity_note` carries the reason identity was left
unresolved (a `profile` key, an unreadable config, an unusable table, …) — empty when
identity resolved cleanly. `lineage` is a DISPLAY string (`<provider> :: <model>`) —
parent-thread matching compares `reviewer.provider` and `reviewer.model` separately,
never this string; an older ledger's `lineage: "ZAI/glm-5.3"` (the pre-wave-7 slash
form) still matches correctly for that reason. `preflight` (`ok: <detail>` |
`unknown: <reason>` | `skipped`) and `preflight_warning` (a recent usage-limit hit on
this provider, or empty) record the credential preflight (see "A second reviewer...").
`thread_candidate` is the diagnostic rollout uuid kept when it could not be verified
against `consult_id`; `effort_requested`/`effort_sent`/`effort_mapping`/`effort_caps`/
`effort_confirmed` replace the old single-stage view of `-Effort` (`effort` is kept,
equal to `effort_sent`, for readers of 0.2 ledgers and for `-Stats`; `effort_caps`
records which version of the bridge's declared-capability table decided the mapping);
`extra_config` lists any `-CodexConfig` overrides, expanded, in the form sent to argv,
and `extra_config_source` says where it came from: `''` (given directly), `-CodexConfig`,
or `roster` (a `-Provider` or `-Thread` run whose roster entry supplied it because
`-CodexConfig` was empty); `peak`/`peak_schedule`/`peak_source`
(`env`/`env (CODEX_CONSULT_NOW)`/`none`)/`peak_evaluated_at` record the tariff-window
check made immediately before launch; `schema_transport` (`output-schema`|`prompt-only`)
records how the reply schema reached this endpoint, and `schema_transport_source`
records why (`caps-v1`, or `-SchemaTransport` when that flag overrode it for this run;
`''` under `-Raw`, which uses neither) — see "Structured reply and findings". `roster`
(`null` without a reviewer roster) and `panel` (`null` outside a `-Panel` run) sit right
after `preflight_warning` — see "Reviewer roster and panel" below. Ledgers written
before 0.3.0 have none of these fields — that absence IS the "unknown
provenance" signal described above.

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
| `chore` | low | 400 | a bounded search or extraction task — report facts with file paths and line numbers, quote what was found, say what was not; no verdict, no findings |

`acceptance` and `diff-review` ask for a verdict of `ACCEPT`/`HOLD`/`REJECT`; every
other purpose except `chore` (and no purpose) asks for `ADVISE`. `chore` is a plain-text
reply like `-Raw` — no schema, no findings bookkeeping — meant for grunt work (searching
a big file, extracting facts) that should not cost a weighty reviewer's tokens. The word
cap applies to the prose (`reply_markdown`) only — findings are never truncated to fit
it.

### Structured reply and findings

By default (unless `-Raw`) the script asks Codex for one JSON object per the schema in
`schemas/consult-reply.schema.json` (schema v1) — but HOW that schema reaches the
endpoint depends on the resolved provider, per caps-v1's declared `schema_transport`:
`output-schema` passes `--output-schema` on the codex CLI invocation (the built-in
`openai` route enforces it server-side, so the reply comes back as bare JSON; the z.ai
hosts accept the flag WITHOUT enforcing it, so a fenced JSON block or, in principle,
plain Markdown can still come back); `prompt-only` never passes `--output-schema` at
all — the MiMo hosts, and any endpoint caps-v1 does not declare, reject the flag outright
(`responses_feature_not_supported: text.format type 'json_schema' is not supported,
only 'text' and 'json_object' are allowed` was the exact failure on the first live MiMo
run) — instead the format instruction reads "exactly one JSON object - no code fence,
no text before or after it - that satisfies the JSON Schema given at the end of this
section", and the schema file itself is appended to the prompt as a final
`JSON Schema of the reply:` section (about 2 KB); on `output-schema` hosts the prompt is
unchanged from 0.2.0. The reply is then parsed LENIENTLY (bare or fenced) and validated
locally, exactly as for any other reply. On a `prompt-only` route a reviewer that
ignores the instruction and answers in plain prose is kept as an ordinary Markdown reply
with no verdict and no findings — the same outcome as an INVALID structured reply on
any other route, not a bridge failure. Ledger `schema_transport`
(`output-schema`|`prompt-only`) records which was used, also reported per provider by
`codex-providers.ps1 -Json`; the reply header's `Structured reply:` line gets
`(prompt-only transport)` appended when applicable, and `-DryRun` prints a `transport   :`
line (e.g. `prompt-only (caps-v1: token-plan-ams.xiaomimimo.com): --output-schema is NOT
passed; the schema travels in the prompt, the reply is validated locally`), so a
plain-prose reply on that route is not mistaken for a validation bug.

**Contract-first prompt and format repair (0.3.0, wave 14).** A `prompt-only` route
that never enforces `--output-schema` server-side can still answer in prose even with
the schema attached, especially when the output-contract instruction sits after the
schema section instead of before it. Every structured prompt now OPENS with the
following paragraph, before the ask and the brief:

> FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON
> object (schema_version "1") - no code fence, no text before or after it. The
> Markdown answer lives only inside its reply_markdown string; each defect goes in
> findings[]. A prose final message cannot be ingested, however good the answer is.

When the reviewer still answers in prose, `-FormatRetry 1` (the default; `0` turns it
off) fires ONE recorded repair turn, but only when all of the following hold: the run
is structured (not `-Raw`, not `chore`); the bridge got a usable reply (exit 0, no
timeout, no provider failure); the reply fails to parse or validate as the schema (a
valid object with a verdict you merely disagree with is never retried); the thread is
verified (from the event stream or a verified rollout); and the prose is substantive
(≥120 words, or ≥40 words with a numbered answer at a line start). The repair turn is
`codex exec ... resume <thread> -`, read-only sandbox, the route's lowest effort, the
same `-CodexConfig` items, no `--output-schema`, and a prompt asking to convert the
previous message verbatim into the JSON object (the schema and the consultation id are
given; never the brief) — within `min(-TimeoutSec, 300)` s, under the same lock and
recovery record.

On success, the repaired object is ingested as the reply (findings and verdict
included; `.reply.json` holds the repaired object), and the original prose is kept
byte for byte as `handoffs/NN-codex-<slug>.original.md`, rendered after the structured
section under `## Original reply (prose, before format repair)`. On failure, today's
0.2.0/0.3.0 behaviour is unchanged — the prose is kept, `structured` stays `false` —
except that `validation_error` gets ` (format repair failed: <why>)` appended. Either
way the entry keeps its original `thread`; if the repair turn resumes a *different*
thread id, that id goes only to `format_retry.thread`, with a drift note. Drift notes
(warnings, never refusals) also cover: differing requested checks, a differing numbered
answer, a finding id named in the prose but missing from the object, a differing
verdict, and prose sentences not carried into `reply_markdown`. Ledger `format_retry`,
right after `validation_error`: `null` when repair was not attempted or is off,
otherwise `{attempted, reason, succeeded, thread, wall_seconds, usage, drift, original}`.
Console: `format repair: <succeeded|failed> in <s> s; drift: <n> note(s)`, one `  drift:`
line per note; `-DryRun` prints `format retry : 1 attempt if the reply is not valid
JSON` or `format retry : 0 (off)`. Panel members inherit `-FormatRetry` from the main
run.

Three files record the reply per consult: the raw `.reply.json` (Codex's last message
copied byte for byte, never re-serialized), the rendered `.md`, and
`<task>/findings.json` (only written when at least one finding exists). Copying the raw
reply happens FIRST, before it is even parsed: if that copy fails, it is a bridge
failure in its own right — `bridge_outcome = "failed: could not preserve the raw reply
(<error>); original kept at <temp path>"` — the run exits non-zero with no verdict and
no findings ingested, but the ledger entry is still appended so the failure itself is on
record.

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
rejected count — the R5 measurement of what each review purpose costs and produces, then
a **per-reviewer scoreboard**: one line per lineage (`<provider> :: <model>`, the
reviewer of the ledger entry each finding was ingested from) with raised, verified,
implemented, proposed, rejected, wontfix and superseded counts — a finding whose
consultation predates 0.3.0, or has no ledger entry, counts as `unknown provenance`. This
is what shows, over consultations, which reviewer actually finds what. Since wave 12 the
same scoreboard also carries the judge's usefulness marks — see `-Rate` below.

**`codex-findings.ps1 -Task <task> -Rate <n> -Useful yes|partly|no [-Note "<why>"]`**
records the judge's own mark of consultation `n` (a ledger entry number, not a finding
id) — was it useful, on this kind of question, or not. `findings.json` gets a top-level
`ratings` array of `{n, consult_id, lineage, provider, model, purpose, useful, note,
when}` (`lineage`/`provider`/`model`/`purpose` copied from that ledger entry so the row
survives even if the entry is later pruned); rating the same `n` again replaces its
record. `-Note` is required for `-Useful no` (why it missed), optional otherwise. It
takes the task lock exactly like a status change, so it is refused while a consultation
for the task is running. Rate **every** consultation, including a plain-prose reply that
raised no findings — otherwise the telemetry only ever counts structured reviewers.
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

**Requested checks (convention, not a schema field).** As of 0.3.0 the prompt also asks
Codex, in every purpose, to end `reply_markdown` with a `## Requested checks` section
when there is evidence it cannot obtain read-only: at most 5 items `RC1..RCn`, each ONE
runnable command or procedure, its working directory, the permission it needs
(read-only/workspace-write), the observation that would settle it, and a budget —
referring to a finding by its position in the reply (`finding #2`), an earlier id
(`F04-1`), or an invariant name. This is prose, not structure: the schema stays v1, the
bridge renders nothing extra for it (it is part of the verbatim reply), and
`.reply.json` and `findings.json` are untouched by it. The coordinator runs the listed
checks and records them in the next brief's `## Requested checks run` table (see
`templates/brief-review.md`), which is how they get "closed" — through the same
handoff/brief cycle as everything else, not through new tooling.

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
directory, flushed, and moved over the store in ONE rename that replaces the target
(`MoveFileEx` with `MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH` on Windows
PowerShell 5.1 through a small P/Invoke, `File.Move(tmp, dst, overwrite)` on PowerShell 7,
`rename(2)` on Unix), so a kill mid-write leaves at worst a stray `.<name>.<guid>.tmp`
beside the store, never a truncated or missing one. (0.2.0 used `File.Replace` on
Windows, which is not a single step: a hard kill inside it could leave the store gone —
caught once by the hard-kill harness and fixed in 0.3.0.) An *existing* store that
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
("a previous consultation's codex process (pid N) is still running…"). A dead recorded
pid is **not** proof of a dead tree — the recorded pid is usually the launcher shim, and
the real `codex` may be its orphaned child — so when every recorded pid is gone, and for
a `launching` record (which has no pid yet), the bridge scans for a process that is a
child of the dead bridge or of a dead recorded pid (Windows keeps an orphan's parent
id), and then for any codex-looking process (named `codex`, or carrying the launcher
path or `@openai/codex` on its command line) started at or after the record's `started`
time. The second rule cannot tell which task a process belongs to and says so ("task not
verifiable"); there is deliberately no age cut-off. A refusal names the process and the
record; delete `.consult.pending.json` only when you know that process is unrelated. A
record from another host naming pids is refused since they cannot be checked from here.
Otherwise the interrupted run is dead: its reservation is consumed (console line
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

### A second reviewer through the same bridge

`-Provider <name>` names a `[model_providers.<name>]` table in the user's Codex config;
it requires `-Model <name>` alongside it (refused otherwise) — the model is never
implied by the provider table, and the bridge never assumes one. Omit both and the
bridge resolves what Codex will actually use: it reads `$env:CODEX_HOME/config.toml`
(else `~/.codex/config.toml`) with a constrained scanner (below) for the top-level
`model_provider` (Codex's own default is `openai` when the key is absent) and `model`.
The provider is never assumed to be `openai` — it is read from the config or given
explicitly. A top-level `profile = "..."` key leaves identity UNRESOLVED even when
`-Provider` and `-Model` are both given: a profile can override the provider and the
effort behind the bridge's back, so its mere presence disables automatic `fork`/`resume`
regardless of what else was passed on the command line.

The scanner (`Read-CodexConfigSubset`) understands blank lines, `#` comments, table
headers `[a.b]` / `[a."quoted key"]`, and key/value lines with bare or quoted keys and
single-line string/bool/number/date values. Three tiers of "not understood", each with a
different blast radius:
- an array, an inline table, or a multi-line string as a VALUE makes only the KEY that
  holds it (and the table that key would define, e.g. `x = {...}` defining `x`)
  unusable — everything else in the file, including sibling keys in the same table,
  stays readable;
- a dotted key in key position, an array-of-tables (`[[a]]`), a sub-table, or a table/key
  defined twice makes the TABLE it writes into unusable;
- anything the scanner cannot tokenize at all — an unterminated string or array, a line
  it cannot parse as either a header or a key/value — is FATAL: the whole file is
  unusable, because the scanner can no longer tell which table the rest of the lines
  belong to.

Callers decide what an unusable table means: the top level is usable while
`model_provider`, `model` and `profile` are plain; a provider table is usable only when
every key in it is plain. Nothing is guessed. When the config cannot be read, or the
table this run needs is itself unusable, provider identity is `unknown`: `-Mode`
defaults to `new` and `fork`/`resume` are refused ("provider identity could not be
resolved (...); pass -Provider and -Model explicitly, or use -Mode new") — unless
`-Provider` and `-Model` are both given AND that provider's own table parses (and no
`profile` key is set), in which case identity is known even when the rest of the config
is not.

**Lineage** displays as `<provider> :: <model>` (e.g. `ZAI :: glm-5.3`) — but this string
is DISPLAY ONLY. What actually decides whether a thread belongs to this run's reviewer
is `reviewer.provider` and `reviewer.model` compared separately, field by field,
ordinal, plus the fingerprint below — never a string comparison of `lineage`. A ledger
entry from before this change, whose `lineage` still reads `ZAI/glm-5.3` (the old
slash form), still matches correctly: the comparison never looks at the display string.
What must MATCH for a `fork`/`resume` across consultations is narrower still: for a
provider defined by a `[model_providers.<name>]` table,
the *compatibility fingerprint* is the SHA-256 of its `base_url` (canonicalised:
lowercase scheme+host, path as-is, no trailing slash) and `wire_api` ONLY. An ABSENT
`wire_api` is canonicalised as `wire_api=default` — no protocol is asserted, it is
simply "whatever Codex defaults to" — and `provider_config` then carries no `wire_api`
key at all; a header or console `wire_api:` field shows `(default)`. A present but
EMPTY `wire_api = ""` is a distinct, different value from absent. Consequently, adding
an explicit `wire_api` value to a table that previously had none counts as an endpoint
change, exactly like changing `base_url` does — both are drift, both refuse `fork`/
`resume` (below). Comments, key ordering, a rotated `env_key`/`api_key`/secret, and the
table's `name` never change the fingerprint — reformatting the file or rotating a secret
never breaks a lineage.

`fork`/`resume` onto a parent whose recorded fingerprint differs is **always REFUSED,
never silently switched to a new thread** — you decide, with `-Mode new`, that a new
thread is what you want:

```
endpoint or protocol of provider ZAI changed since thread <uuid> (consult n=3 recorded
provider fingerprint <hash12>, now <hash12>); start a new thread with -Mode new
```

`-Mode new` is unaffected by drift. The harness version (`reviewer.harness = codex-cli
<version>`) is recorded as audit metadata only and never compared.

The built-in `openai` provider is more nuanced now that a config can also define a
`[model_providers.openai]` table of its own:
- **No such table** (the common case): identity is `builtin:openai`, and when the
  `OPENAI_BASE_URL` environment variable is set, that URL is folded into the SAME
  identity (`cc-provider-v1|builtin:openai|base_url=<canonicalised>`) — the built-in
  provider is not exempt from endpoint drift just because it needs no config table.
- **A usable `[model_providers.openai]` table** DEFINES the identity instead: its own
  `base_url`/`wire_api` become the fingerprint, `identity_note` records "user-defined
  [model_providers.openai] table used for the identity" (whether Codex itself actually
  merges a user table over its built-in default is not verified against the Codex
  source — the table is the more conservative claim either way), and `OPENAI_BASE_URL`
  is then IGNORED for the identity (the table wins).
- **An unusable `[model_providers.openai]` table** (an array, a dotted key, …) leaves
  the default openai identity UNRESOLVED when openai was reached implicitly (from the
  config or Codex's own default) — `fork`/`resume` are then off, `-Mode new` still
  works; an EXPLICIT `-Provider openai` naming that same unusable table is refused
  outright, since there is then no fallback identity left to fall back to.

The built-in identity is used only when the scanner can actually ESTABLISH that no
`[model_providers.openai]` declaration exists at all — not just that it did not find
one at the expected spot. Three things can hide such a declaration from a naive lookup:
a construct at `model_providers` itself (an inline table, an array, a dotted key from
the top level, a table defined twice — anything that is not a plain table of provider
names); an entry named `openai` written directly inside `[model_providers]` that is not
itself a sub-table header (an inline table, a dotted key, a plain value); or the
`[model_providers.openai]` table existing but being unusable for the usual reasons. Any
of the three leaves identity unresolved with a note naming the file:

```
Codex's default provider openai: the providers in <path> could not be established, so
[model_providers.openai] may be declared there - <reason>
```

`fork`/`resume` are then off, `-Mode new` still works. An unsupported construct under
some OTHER provider (`[model_providers.zai]` being unusable, say) never affects the
openai identity — only a construct that could itself hide an `openai` declaration does.

The reply header's `Reviewer:` line spells out where each piece of the identity came
from, in one line:

```
Reviewer: <lineage> (provider from <provider_source>, model from <model_source>;
endpoint <url>|builtin:openai[ via OPENAI_BASE_URL <url>][, wire_api: <v>|(default)];
provider fingerprint <12 hex>[; <note>]; harness <h>).
```

The `wire_api:` clause only appears when the identity came from a `[model_providers.*]`
table (any non-openai provider, or a user-defined openai table) — the plain built-in
`openai` identity with no table has no protocol to name. `<note>` is `identity_note`
when non-empty (e.g. the user-defined-openai-table note above, or why identity is
unresolved).

Within a lineage, the parent for `fork`/`resume` is the newest ledger entry with a
non-empty `thread` and the SAME lineage — never the task's newest thread overall.
`-Thread <uuid>` must name a thread belonging to an entry of the CURRENT run's lineage,
or the run is refused, verbatim:

```
thread <uuid> belongs to lineage a/b :: c (consult n=1); this run is a :: b/c. A thread
never changes provider or model: use -Mode new, or run as a/b :: c
```

An unknown uuid is refused as "unknown provenance"; `-Thread` together with `-Mode new`
is refused ("-Thread needs -Mode fork or resume").

Ledger entries written before 0.3.0 carry no `reviewer`/`lineage` field — their
provenance is UNKNOWN, full stop: they are never chosen as an automatic parent, and
`-Thread` naming one of their threads is refused ("unknown provenance (recorded before
0.3.0); use -Mode new"), even when the model looks like a match and the provider is
presumably `openai`. Practical consequence: the FIRST 0.3.0 consultation on a task whose
ledger predates 0.3.0 always starts a new thread, whatever provider or model it uses —
a one-time migration cost, not a bug.

Reading the thread id from the event stream is itself narrower than "any JSON line
mentioning a thread": only the primary `thread.started` event and the SESSION-START
events `session.started` / `session_configured` (top-level or msg-wrapped, for older
Codex versions) are consulted; any other event line — notably a `turn.started`, which
can carry a foreign `session_id` belonging to a different conversation — is ignored for
thread purposes. This closes a case where a foreign session id on such a line could
otherwise have been recorded as this run's thread.

The prompt's final line is `Consultation id: <guid>`, a fresh id per run (also written
to the ledger as `consult_id` and to `.consult.pending.json`). It exists because the
thread-id fallback — used when the event stream names no thread, including a *resumed*
thread whose `thread.started` event goes missing, whose rollout file then lives in an
OLDER day directory than the run's own start date — cannot otherwise tell whether a
rollout file is really this run's: the fallback scans the rollout files written since
the run started, newest first, and opens each candidate to check for this run's
consultation id. Found -> `thread` is set and `thread_source = 'rollout (verified by
consultation id)'`. Not found in any candidate -> `thread` stays empty, `thread_source =
'unknown'`, and the newest candidate's uuid is kept only as a diagnostic
`thread_candidate` — never used as a parent by a later run, whether by automatic
selection or by `-Thread`.

**Before anything is locked or started, the bridge preflights the provider — and it
fails CLOSED.** This uses the same local checks as `codex-providers.ps1` (see below):
for `openai` (or any table with `requires_openai_auth = true`), `codex login status`;
for any other provider, `env_key`/`experimental_bearer_token` in its table; plus this
ENDPOINT's own recorded health across every task ledger in the repository (below).
Missing credentials, an availability that could not even be ESTABLISHED (an unresolved
identity, or `codex login status` failing to run at all, or timing out after 15 s), and
a recent authentication failure on this same endpoint all refuse the run outright,
before the lock, with no ledger entry — a check that comes back UNKNOWN is no longer
treated as harmless:

```
provider ZAI is not usable: env ZAI_API_KEY not set; nothing was started (run
codex-providers.ps1 for the full picture)

provider ZAI: availability could not be established (`codex login status` did not
finish within 15 s); pass -SkipPreflight to launch anyway, or fix the check

provider ZAI is not usable: the last run on this endpoint was rejected as
unauthenticated at <when> (<message>); if you rotated the credential, pass
-SkipPreflight once
```

`-SkipPreflight` bypasses all three refusals (ledger `preflight: "skipped"`) — for an
endpoint that genuinely needs no credentials, or once you know a flagged failure no
longer applies, this is required, since the bridge cannot otherwise tell "no credentials
needed" from "credentials missing", or "fixed since" from "still broken". `-DryRun`
only PRINTS the verdict and never refuses on it, on any of the three checks. Ledger:
`preflight` = `ok: <detail>` | `unknown: <reason>` | `unavailable: auth failed <when>:
<message>` | `skipped`.

**Every failed consultation is classified and recorded**, so this endpoint health check
has something to read: `provider_failure` (right after `bridge_outcome`) is `null` on
success, else `{class, code, message (<=200 chars), when, retry_after}`. `class` is
decided by word-bounded keywords in the error text, tried in this order —
**`capability` first**, so "your token plan does not support response_format" is not
mistaken for a quota rejection: `capability` (not supported/unsupported/"does not
support"/feature_not_supported/json_schema); `auth` (401/403/unauthorized/forbidden/
invalid api key/authentication — matched on WORD BOUNDARIES, so "text authored by" never
counts); `quota` (usage limit/quota/rate limit or `rate_limit`/`usage_limit`/429/
insufficient balance/too many requests/credits exhausted/credit balance/payment
required/402/token plan/billing); `transport` (timeout/connection/dns/tls/certificate/
502-504/network — a bridge-internal failure like a timeout kill is `transport` too);
otherwise `unknown`. The bridge also parses the SSE-style payload some endpoints put on
stderr, `data:{"error":{...}}` (this is how the MiMo endpoint reported its schema
rejection), lifting `error.message`/`error.code` before classifying; `codex login
status`, Codex's stderr and its event stream are all decoded as UTF-8. The reply header
gets a `Provider failure:` line when there was one.

**`retry_after`** is when a `quota` failure said it resets, parsed from the message —
never guessed: Codex's own wording ("try again at Sep 28th, 2026 8:35 PM."), a bare
ISO-8601 timestamp, or a duration ("retry after 30", "resets in 2 days", "try again in
3 days 1 hour 7 minutes" — weeks/days/hours/minutes/seconds, summed). A quota failure
whose reset time lies in the future makes that endpoint `unavailable: usage limit until
<iso>` — refused before the lock (unless `-SkipPreflight`), and skipped outright in a
roster walk. A quota failure with **no** reset time still only warns for 60 minutes with
an explicit `-Provider`, exactly as before 0.3.0, but a roster walk skips it with reason
`"usage limit <n> min ago, no reset time given"`.

A wall-clock reset message names no time zone, so it is interpreted with the
**recording machine's** zone rules (`[TimeZoneInfo]::Local`) **at write time** — DST
included: an hour that a spring-forward transition makes invalid takes the
post-transition offset, an hour a fall-back transition makes ambiguous takes the
pre-transition one — and stored as an instant, `provider_failure.retry_after`, carrying
that offset (found live by the first panel run, F15-1). A ledger entry written before
this fix has no `retry_after` at all; reading it now falls back to reparsing its
message with the failure's own `when` offset as the reference zone, and that
reparse is labelled internally `RetryAfterBasis "message (reference offset)"` (a fresh
write's is `"ledger"`) — the residual: a legacy entry read on a machine in a different
zone than the one that recorded it can be off by the zone difference, since no zone was
ever stored for it. Every `retry_after` written from now on is a true instant and
carries no such residual.

**Endpoint health** is computed from ALL task ledgers in the repository (not just the
current task's), keyed by the ENDPOINT fingerprint — never the alias, so two provider
names pointing at the same endpoint share one health record — with the newest entry
winning: a later success clears an earlier failure. An `auth` failure within the last
24 hours refuses the run (message above); a `quota` failure without a reset time within
the last 60 minutes only warns (console `WARNING:` plus ledger `preflight_warning`, same
as before); a `quota` failure with a reset time in the future refuses (`retry_after`,
above); `capability`/`transport`/`unknown` failures are informational only, shown by
`codex-providers.ps1` but never refused on. This health check runs even under
`-SkipPreflight` — only the REFUSAL is bypassed, the information is still there to read.
Ledger entries from before 0.3.0 count as the built-in `openai` endpoint; an entry with
an unresolved identity (empty fingerprint) is ignored, since it names no endpoint
reliably.

`codex-providers.ps1 [-Provider <name>] [-Json] [-CollabDir <path>] [-CodexExe <path>]`
answers "what can I actually consult right now?" without touching anything: it writes
nothing, takes no task lock, makes no network call. It lists the built-in `openai` and
every `[model_providers.*]` table with a verdict (`available` /
`unavailable (<reason>)` — including `unavailable (usage limit until <iso>)` for a quota
failure with a known reset time still ahead — / `unknown (<reason>)`), kind
(`builtin`/`custom`), endpoint, credentials (the same preflight check above, spelled out:
`ok: Logged in using ChatGPT`, `missing: env ZAI_API_KEY not set`, or, with `"auth":
"none"` in the roster, `ok: declared anonymous in the roster`), the declared effort
vocabulary (`openai (any model)`, `zai (11 declared models)`, `mimo (5 declared
models)`, or `unknown (needs -NativeEffort)`), and a `LAST FAILURE (24 h)` column
(`<class>: <when> - <message>`, or `quota until <iso>: <message>` when the provider named
its reset time, from the same endpoint-health lookup above — an `auth` failure here is
exactly what makes the provider `unavailable`, a `quota`/`capability`/`transport`/
`unknown` one is shown for information). With a reviewer roster present, a `ROSTER`
column shows the provider's roster position(s) (`-` otherwise), and a final line reports
the walk: `roster: <path> -> would select ZAI :: glm-5.3 (skipped: ...)` or
`roster: <path> -> no entry is available (skipped: ...)`. `-Json` gives the same as
`last_failure {class, code, when, message, retry_after}`, `last_limit` (the newest quota
failure specifically, same shape, or `null`), `roster_position` (the first roster
position naming this provider, or `null`) and `roster_selected` (whether a consultation
without `-Provider`/`-Thread` would pick it right now). With `-Provider`, the exit code
IS the verdict: `0` available, `2` unavailable, `3` unknown, `1` no such provider name
(unchanged by the roster). Plan a second-reviewer run against this output, not against
hope — a provider `codex-providers.ps1` reports unavailable is not going to become
available by retrying the bridge.

An endpoint-health record dated in the **future** (a skewed clock somewhere, a
mislabelled zone) is no longer ignored — its age clamps to zero, "counts as now", so it
can never hide a fresh `auth`/`quota` failure behind an apparently ancient timestamp
(F15-4, found by the first live panel). On pwsh >= 7.5, ledgers are now parsed with
`ConvertFrom-Json -DateKind Offset` where available, so a `when`/`retry_after` value
keeps the offset it was recorded with instead of being silently converted to a local
`[datetime]` (F15-2); Windows PowerShell 5.1, which has no such parameter, keeps reading
them as plain strings, unchanged.

**Effort vocabularies are DECLARED, never inferred** — no host-wide or model-prefix
guess, only a capability table the bridge ships (`caps-v1`, recorded in the ledger as
`effort_caps`):

| Endpoint | Vocabulary | Declared models | Mapping from `-Effort` | Schema |
|---|---|---|---|---|
| built-in `openai` (no user table, no `OPENAI_BASE_URL`) | `low\|medium\|high\|xhigh` | any model | identity | `output-schema` (enforced server-side: bare JSON comes back) |
| `api.z.ai`, `open.bigmodel.cn` | `low\|high\|max` | `glm-5.3`, `glm-5.3-flash`, `glm-5.3-flashx`, `glm-5.2`, `glm-5.1`, `glm-5`, `glm-5-turbo`, `glm-4.7`, `glm-4.6`, `glm-4.5`, `glm-4.5-air` (11, exact) | `medium`->`high`, `xhigh`->`max`; `low`->`low`, `high`->`high`; mapping `zai-v1` | `output-schema` (passed, NOT enforced: fenced JSON or plain Markdown may come back) |
| `token-plan-ams.xiaomimimo.com`, `token-plan-cn.xiaomimimo.com`, `api.xiaomimimo.com` | `none\|low\|medium\|high` | `mimo-v2.6-pro`, `mimo-v2.6-flash`, `mimo-v2.6-pro-ultraspeed`, `mimo-v2.5-pro`, `mimo-v2.5` (5, exact) | `xhigh`->`high`; the rest as is; mapping `mimo-v1` | `prompt-only` (the bridge does not pass `--output-schema`; the prompt still asks for the JSON object, parsed leniently) |
| any UNKNOWN host | — (needs `-NativeEffort`) | — | — | `prompt-only` (the safe default — an undeclared endpoint's `--output-schema` support is unknown, so the bridge never risks the flag) |

Everything else — an undeclared model on a known host, any model on an unrecognised
host, an `openai` proxy reached via `OPENAI_BASE_URL`, or a user-defined
`[model_providers.openai]` table — has no declared vocabulary: the run is refused,
naming what IS declared:

```
no effort vocabulary declared for model 'glm-6' on api.z.ai (caps-v1 declares:
glm-4.5, glm-4.5-air, glm-4.6, glm-4.7, glm-5, glm-5-turbo, glm-5.1, glm-5.2, glm-5.3,
glm-5.3-flash, glm-5.3-flashx); pass -NativeEffort <value> to send a value verbatim
```

There is no model-prefix fallback any more — a host with no declared models, or a model
not on its declared list, always needs `-NativeEffort`. `-NativeEffort <value>` sends
that value to `-c model_reasoning_effort="..."` verbatim, mapping recorded as `native`
— but **`-Effort` and `-NativeEffort` exclude each other** ("-Effort and -NativeEffort
exclude each other: -Effort is mapped through the endpoint's effort vocabulary,
-NativeEffort is sent verbatim."). The ledger records `effort_requested` (what
`-Effort`/the preset, or `-NativeEffort`, asked for), `effort_sent` (what actually went
into argv), `effort_mapping` (`openai`|`zai-v1`|`mimo-v1`|`native`), `effort_caps`
(`caps-v1`, so a later change to the table is visible in old entries), and
`effort_confirmed` — always `null`, because Codex's event stream does not report the
effort it actually used. The console line spells out the requested/sent/mapping triple
in one place:

```
effort      : max sent (requested xhigh, mapping zai-v1, by host api.z.ai)
```

**Peak-hour tariffs**: `CODEX_CONSULT_PEAK_<PROVIDER-UPPERCASED>` =
`"<days> <HH:MM>-<HH:MM> <+HH:MM|-HH:MM>"` (days: a range `Mon-Fri`, a list `Mon,Wed`,
or `*`); an optional `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` = comma-separated dates or
`YYYY-MM-DD..YYYY-MM-DD` ranges marks all-day exceptions as off-peak — a range is
evaluated as an interval of any length; the only thing refused is `end < start`. Start
inclusive, end exclusive; a window where start > end spans midnight and the day check
uses the day the window STARTED; `*` matches every day.

The window is now checked TWICE: once early (so a malformed schedule, or `-OffPeakOnly`
already inside the window, is caught before any file hashing starts), and once again
IMMEDIATELY BEFORE LAUNCH, since hashing the tree and the brief takes real time and can
itself cross a window boundary. The launch-time result is what the ledger records:
`peak` (`true`/`false`/`null`), `peak_schedule`, `peak_source` (`env`,
`env (CODEX_CONSULT_NOW)`, or `none`), and `peak_evaluated_at` (an ISO timestamp with offset — when the decisive
check ran). Under `-OffPeakOnly`, a launch-time result that turns out to be peak
withdraws the run at that late point — the reservation is released, nothing is started,
NO ledger entry is written (there is nothing yet worth recording — the run never
reached the point of doing anything):

```
-OffPeakOnly: ZAI entered its peak window before launch (Mon-Fri 14:00-18:00 +08:00; now
2026-09-24 14:00 Mon +08:00); nothing was started.
```

Outside the window -> `peak: false`; the env var unset -> `peak: null` (unknown),
`peak_schedule: ''`, `peak_source: 'none'`; `-OffPeakOnly` refuses whenever the
(launch-time) result is `true` OR unknown ("no schedule for provider X; -OffPeakOnly
needs CODEX_CONSULT_PEAK_X" for the unknown case). A malformed spec is refused, naming
the variable and the bad token. When nothing is set, the console line reads:

```
peak        : unknown (CODEX_CONSULT_PEAK_ZAI not set)
```

`CODEX_CONSULT_NOW` is a TEST HOOK, not a user-facing feature: a comma-separated list of
ISO timestamps with an offset, consumed in order by successive peak evaluations within
one run (the last one repeats), so a test can put the early check off-peak and the
launch-time check inside the window. It should never be set in normal use;
`peak_source` becomes `env (CODEX_CONSULT_NOW)` when it was.

A note on z.ai specifically: `--output-schema` is **not enforced** on that route — the
reply comes back as a fenced JSON block rather than a schema-constrained response,
which the bridge's parser already accepts and validates locally, the same as any other
reply. And a plan's credentials are used only ever through the Codex CLI itself: the
bridge makes no direct HTTP call to any provider, on this route or any other — it
always shells out to `codex exec`.

**`-CodexConfig key=value[,key=value]`** passes extra `-c` overrides straight through to
`codex exec`, verbatim, right after the bridge's own `-c` options and before `-o` — one
comma-separated string, or a PowerShell array (the parameter itself cannot be repeated).
A value beginning with `~/` or `~\` is expanded to the home directory with forward
slashes, since Codex on Windows does not expand `~` itself (verified: it fails with
`os error 123`); a non-literal value (not already quoted, bracketed, `true`/`false`, or
numeric) is double-quoted so Codex's own TOML parsing of the value never trips on a bare
path. Refused keys — anything the bridge already owns as part of the reviewer identity
or the effort it records: `model`, `model_provider`, `model_reasoning_effort`,
`profile`, `model_providers` and any `model_providers.*` key. Recorded in the ledger as
`extra_config` (the expanded items, ready to compare against the argv). The motivating
case is a provider whose model catalog needs pointing at a file: a GLOBAL
`model_catalog_json` replaces Codex's OWN catalog outright and can silently degrade an
unrelated model, so it has to be passed per run, not left in the user's Codex config —
see the MiMo example below.

### Third example: Xiaomi MiMo

A third provider fits the same shape as z.ai: `[model_providers.mimo]` with
`base_url = "https://token-plan-ams.xiaomimimo.com/v1"` (the Token Plan endpoint — a
region-specific variant, `token-plan-cn.xiaomimimo.com`, and a direct `api.xiaomimimo.com`
also exist), `env_key = "MIMO_API_KEY"`, `wire_api = "responses"`. Its declared models
(`mimo-v2.6-pro`, `mimo-v2.6-flash`, `mimo-v2.6-pro-ultraspeed`, `mimo-v2.5-pro`,
`mimo-v2.5`) use the `mimo` effort vocabulary (`none|low|medium|high`, `xhigh`->`high`,
mapping `mimo-v1`) — see the caps-v1 table above. MiMo's model catalog is not built into
Codex, so it has to be supplied per run with `-CodexConfig
model_catalog_json=~/.codex/model-catalogs.json` (not set globally in the user's Codex
config — a global `model_catalog_json` replaces Codex's own catalog outright and was
observed, live, to degrade the DEFAULT `openai` model on an unrelated run: it answered
with "Model metadata not found, fallback"). Unlike z.ai, this route does not merely fail
to enforce the schema — the first live MiMo consultation through the bridge failed
outright at the first request, because the endpoint REJECTS `--output-schema` entirely
(`responses_feature_not_supported: text.format type 'json_schema' is not supported,
only 'text' and 'json_object' are allowed`). caps-v1 therefore declares MiMo's
`schema_transport` as `prompt-only`: the bridge never passes `--output-schema` to this
endpoint, asks for the JSON object in the prompt instead, and parses the reply leniently
(bare or fenced). More generally: a third-party route may ignore or refuse the schema —
the bridge chooses the transport per host, and a plain-Markdown reply on a
`prompt-only` route is kept with no verdict and no findings, the same as an invalid
structured reply anywhere else. No account details are needed to use this: the shape is
generic to any `[model_providers.*]` entry with its own model catalog.

### Reviewer roster and panel

A **reviewer roster** is an ordered JSON file naming the reviewers you are willing to
use, first choice first — `CODEX_CONSULT_ROSTER` (else `<codex home>/codex-consult-
roster.json`; `CODEX_CONSULT_ROSTER=none` turns it off, the default file included):

```json
{
  "roster_version": 1,
  "reviewers": [
    { "provider": "openai", "model": "gpt-5.1", "panel": "weighty" },
    { "provider": "ZAI", "model": "glm-5.3" },
    {
      "provider": "mimo",
      "model": "mimo-v2.6-pro",
      "codex_config": ["model_catalog_json=~/.codex/model-catalogs.json"],
      "auth": "none"
    }
  ]
}
```

Per entry: `provider` (required, a `[model_providers.<name>]` table or `openai`);
`model` (optional — omit it to use the Codex config's top-level model, as without a
roster); `codex_config` (optional, the same `-CodexConfig` rules); `auth: "none"`
(optional — declares an endpoint that needs no credential at all, so a table with no
`env_key`/bearer token still passes the check; ignored for `openai`/`requires_openai_auth`
providers, which are always checked through `codex login status`); `panel: "always"`
(the default) or `"weighty"` (this entry joins a `-Panel` run only on the weighty
purposes — `framing`, `decision`, `core-contract`, `acceptance`, `stuck` — or under
`-PanelAll`). An unusable roster file — an unknown key, `roster_version` other than 1,
an empty or non-array `reviewers`, the same `(provider, model)` twice, anything that does
not parse — **refuses every run naming the path**, including `-DryRun`: an existing
roster is never silently ignored.

**Selection.** `-Provider <name>` still names the reviewer directly; the roster does not
choose in that case, but that provider's roster entry supplies the model (when `-Model`
is empty) and `codex_config` (when `-CodexConfig` is empty) — ledger `model_source`/
`extra_config_source` `"roster"`. `-Thread <uuid>` still fixes the reviewer from the
thread's own ledger entry (`provider_source`/`model_source` `"-Thread"`); its roster
entry, if any, supplies `codex_config`. Otherwise the bridge walks the roster **in
order** and runs the first entry whose credentials are present and whose endpoint health
allows a run right now (a usage limit with a known reset time in the future, or one
without a reset time seen in the last 60 minutes, is skipped) — every skipped entry is
recorded with its reason, and when none is available the run is refused, naming every
entry and why, with nothing started. `-Model` without `-Provider` narrows the walk to
entries naming that model. Ledger `roster` = `{path, position, skipped: [{provider,
model, reason}], applied: []}`, right after `preflight_warning`; a console/handoff line
spells out the pick, e.g.:

```
Roster: <path> - position 2 of 3; skipped openai :: gpt-5.1 (usage limit until <iso>)
```

`codex-providers.ps1` shows the same walk without running anything: a `ROSTER` column
(the provider's roster position(s), or `-`), a closing line
`roster: <path> -> would select ZAI :: glm-5.3 (skipped: ...)` (or
`-> no entry is available (skipped: ...)`), and `-Json` fields `roster_position` (the
first position, or `null`) and `roster_selected` (whether this run's walk would pick that
provider right now).

**Panel.** `-Panel` sends the **same brief to every available roster entry**,
sequentially, each as a complete, independent consultation: its own preflight, its own
lock/pending record, its own parent thread (within its own lineage), its own
consultation id, its own reply file
(`handoffs/NN-codex-<ReplyName>-<provider lowercased>.md`) and its own ledger entry. Every
member sees only the findings that were open when the panel started — not a later
member's answer. A `"weighty"` roster entry joins only on the weighty purposes
(`framing`, `decision`, `core-contract`, `acceptance`, `stuck`); `-PanelAll` includes
every available entry regardless of purpose. `-Panel`/`-PanelAll` need a roster and are
refused together with `-Provider`, `-Thread`, or `-Mode resume` (each member forks the
newest thread of its own lineage, or starts one). Ledger `panel` = `{id, position, of,
members: [{provider, model, state: "run"|"skipped", reason}]}`. A failing member does
not stop the others — **except** when its failure leaves surviving processes behind
(the task's `.consult.pending.json` reservation stays active): the one-consultation-
per-task rule is absolute, so the remaining members are then not started at all and are
recorded `skipped` with reason `not started: the previous member (<lineage>) left
surviving processes (.consult.pending.json state survivors); recover the task first`
(narrowed from "never stops the others" after the first live panel found the gap,
F15-3); the summary shows `skipped  not started: ...` for them. A summary block closes
the run (one line per member: lineage, verdict or failure, finding counts, or the
`skipped` reason above); the run exits `0` only when every member produced a usable
reply, `1` otherwise. (Internally, each member runs as a child bridge process via
`-PanelSpec`, base64-encoded and never exposed as a documented option — it is not for
users.)

**`-SchemaTransport output-schema|prompt-only`** overrides caps-v1's declared transport
for one run (not with `-Raw`) — ledger `schema_transport_source` becomes
`-SchemaTransport` instead of `caps-v1`.

The council model this plugin encodes: the coordinator (Claude) is an equal participant,
not a rubber stamp waiting on Codex, and is the judge by default; a hard question can
hand the judge role to one reviewer explicitly (a `-Purpose decision` consultation whose
brief points at the other members' reply files and asks for a verdict — record that
verdict in `state.md` as the decision; the coordinator still executes and verifies). A
provider without a credential or without tokens left is simply not used — the roster
skips it and records why — and a fallback reviewer's reply is never presented as the
primary's. Disagreement between reviewers is the signal, not noise: record it in
`state.md` as an open item until evidence settles it; `codex-findings.ps1 -Stats`'s
scoreboard (below) shows over time who finds what. Hand bounded search/extraction work
to cheap roster members with `-Purpose chore`, and pre-digest large inputs before a
weighty brief — put the extract in the brief, not the raw file. Acceptance authority for
a release stays with the reviewer who raised the findings; a stand-in's ACCEPT is
recorded, but the tag waits for the one who raised them.

### Usefulness telemetry: codex-scoreboard.ps1

Wave 12 answers a plain operator question — *which reviewer has actually been useful,
on which kind of question* — across every task in the repository, not just one:

```
powershell -NoProfile -ExecutionPolicy Bypass -File plugins/codex-consult/scripts/codex-scoreboard.ps1 [-Task <task>] [-Json]
```

It reads every task's `sessions.json` (ledger) and `findings.json` (findings + the
`-Rate` marks above) under `<CollabDir>`, or one task's with `-Task`; it writes nothing,
takes no lock, and makes no network call. One row per `(reviewer lineage, purpose)`,
plus a `(total)` row per lineage and a grand `(all) (total)` row; a lineage that is
`unknown provenance` (an entry predating 0.3.0, or a finding with no ledger entry) sorts
last. Columns:

| Column | Meaning |
|---|---|
| `REVIEWER` | `<provider> :: <model>` of the ledger entries in this row, or `unknown provenance` |
| `PURPOSE` | the consultation's `-Purpose`, `(none)` without one, `(total)`/`(all) (total)` on a summary row |
| `CONSULTS` | ledger entries |
| `USABLE` | `bridge_outcome` = "usable reply" |
| `PROSE` | usable but not a valid structured reply (`-Raw`, `chore`, or invalid JSON) |
| `FAILED` | every other outcome |
| `RAISED` | findings raised by these consultations (joined by `source.consult`, the same join `-Stats` uses) |
| `VERIFIED` / `REJECTED` / `WONTFIX` / `SUPERSEDED` | current status of those findings |
| `OPEN` | `proposed` + `implemented` |
| `HIT%` | `verified / (verified + rejected)`, rounded percent; `-` when both are 0 |
| `A/H/R/D` | verdict counts: ACCEPT / HOLD / REJECT / ADVISE |
| `Y/P/N` | the judge's `-Rate` marks: yes / partly / no |
| `MEDIAN_S` | median `wall_seconds`; `-` when none |
| `TOKENS` | uncached input tokens / output tokens, summed |

`-Json` prints the same rows as an array with numeric fields (`hit_rate` a number or
`null`, `median_wall_seconds` a number or `null`) plus `kind`: `purpose` | `lineage` |
`total`. A fabricated example row (openai gpt-5.1, purpose `decision`, three
consultations, two verified findings, one rejected, all three judged useful):

```
REVIEWER          PURPOSE   CONSULTS USABLE PROSE FAILED RAISED VERIFIED REJECTED WONTFIX SUPERSEDED OPEN HIT%  A H R D Y P N MEDIAN_S TOKENS
openai :: gpt-5.1 decision  3        3      0     0      3      2        1        0       0          0    67%   1 1 1 0 3 0 0 41.2     6300/1840
```

Before choosing a panel or a judge for a hard question, run this (or `-Task <task>` for
just that task's history) to see who has actually been useful on that purpose so far —
not just who is cheapest or fastest. Every consultation should be rated
(`codex-findings.ps1 -Rate`, above) so this view stays complete rather than sampling
only the reviews someone remembered to grade.

### Role split

When a fresh-context verifier of the same model family is also reviewing, treat the
two as primary, not exclusive, responsibilities — either may challenge anything the
other says. The verifier is best used for mechanics: lint, interpreter/version
compatibility, build correctness, test wiring. Codex is best used for protocol and
state-machine correctness, and for naming what the evidence does not show. On a real
multi-wave task the two typically find mostly different defects. A second model
consulted through `-Provider` fits the same split as a measured, optional participant
in its own lineage: its "done" (and its ACCEPT) is never trusted any more than the
primary reviewer's, and it never closes a finding by itself.

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
| `-Provider <name>` | *none* → config's `model_provider` | Requires `-Model`; validated against `[model_providers.<name>]` in the Codex config |
| `-Purpose <purpose>` | *(none)* | Selects the prompt paragraph and the preset effort/words — see "Review purposes" |
| `-Effort low\|medium\|high\|xhigh` | preset default (`high` with no purpose) | Overrides the purpose's preset; mapped per the resolved provider's vocabulary |
| `-NativeEffort <value>` | *none* | Sends the value verbatim to `-c model_reasoning_effort=…`; required when no vocabulary is known for the endpoint/model |
| `-OffPeakOnly` | off | Refuses when `CODEX_CONSULT_PEAK_<PROVIDER>` says peak now, or is unset (unknown) |
| `-SkipPreflight` | off | Bypasses all three preflight refusals (missing credentials, unresolved availability, a recent auth failure on this endpoint); ledger `preflight: "skipped"`. Endpoint health is still recorded either way |
| `-CodexConfig key=value[,…]` | — | Extra `-c` overrides passed verbatim; refuses `model`/`model_provider`/`model_reasoning_effort`/`profile`/`model_providers(.*)` |
| `-Sandbox read-only\|workspace-write` | `read-only` | `danger-full-access` is refused |
| `-MaxWords <n>` | preset default (`700` with no purpose) | Overrides the purpose's preset; applies to prose only |
| `-Artifact <path>` | — | Repeatable; hashes a built artifact into the ledger. Missing path refuses the run |
| `-Raw` | off | 0.1-style plain-text reply: no schema, no findings bookkeeping |
| `-FormatRetry 0\|1` | `1` | One recorded repair turn when a structured reply comes back as prose (see "Contract-first prompt and format repair"); `0` turns it off. Ignored with `-Raw`/`chore`. Any other value refuses the run |
| `-Panel` / `-PanelAll` | off | Sends the brief to every available reviewer roster entry, sequentially, each its own consultation — see "Reviewer roster and panel". Needs a roster; refused with `-Provider`/`-Thread`/`-Mode resume` |
| `-SchemaTransport output-schema\|prompt-only` | caps-v1's declared transport | Overrides the reply-schema transport for this run; not with `-Raw`; ledger `schema_transport_source` |
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
| 0.3.0 (Windows 11, Windows PowerShell 5.1 and pwsh 7.6, Codex CLI 0.155.1) | `tests/run-all.ps1` on 5.1: harness-0.3 227/227, harness-roster 113/113, harness-format 23/23, harness-pending 26/26, harness-fixes 45/45, harness-lock2 11/11, harness-3b 12/12; harness-0.3 227/227, harness-roster 113/113 and harness-format 23/23 on pwsh 7.6 (fake `codex` shims: config resolution, scanner, fingerprints, lineage-scoped parents, rollout correlation, caps-v1, peak windows, preflight, failure classes, endpoint health, schema transport, `-CodexConfig`, plus wave 10's roster file validation, the three selection rules, usage limits with a known reset time, the F12-2 classifier order, UTF-8 capture, `-SchemaTransport`, the review panel and the `codex-findings.ps1 -Stats` scoreboard, plus waves 11-12's reset times across daylight-saving changes, timestamps keeping their offset on pwsh, future-stamped failures, a panel stopped by a member's surviving processes, the judge's marks (`-Rate`) and `codex-scoreboard.ps1`, plus wave 14's contract-first prompt and format-repair retry; exact case counts as of waves 11-14 are tracked in `tests/README.md`). Live, in `.collab/bridge-0.3-2026-09-24/`: the design review and two acceptance rounds on the openai lineage (a `new` thread, then the first `resume` under the provenance rules); the second reviewer (GLM-5.3, z.ai) through `-Provider ZAI` - its plain-Markdown reply kept with no verdict; the third reviewer (Xiaomi MiMo, `-Provider mimo` with a per-run model catalog) - first attempt refused by the endpoint (`--output-schema` unsupported; the failure was lifted into the ledger), then, with `prompt-only` transport, a bare-JSON structured HOLD ingested as F09-1..4 while reporting five earlier ids fixed; the first live review PANEL (`-PanelAll`, real roster) found F15-1..4 (wave 11) independently through both remaining members (GLM-5.3 and MiMo) after the weighty member was itself skipped on a known reset time; with the schema in the prompt but the output contract buried mid-prompt, the z.ai route answered in prose on two consultations, and a third consultation on the same route, after wave 14's contract-first fix, returned bare JSON - two independently-consulted cheap reviewers each diagnosed the same root cause (the contract buried past the schema, and the old "write it exactly as you would a normal reply" wording licensing prose), and wave 14 implements their recommendation. `codex-providers.ps1` on the real config: openai (`Logged in using ChatGPT`), ZAI and mimo (env keys) all available. macOS unexercised |
| 0.2.0 (Windows 11 + Windows PowerShell 5.1 + Codex CLI 0.155.1) | harness tests with a fake `codex` shim (structured parsing and validation, fingerprinting, the lock, findings bookkeeping, crash and timeout paths), re-run by a fresh-context verifier with its own fixtures; and the release's own consultations, live, in `.collab/bridge-0.2-2026-09-23/`: a framing `new` (0.1 bridge), an acceptance `fork` and a re-acceptance `resume` on the structured path (`--output-schema`, fenced-or-bare JSON parsing, findings ingestion, `prior_findings` fed back, the lock held with the codex child pid inside, before/after fingerprints, tree-drift warning). The reviewer delivered three HOLDs (11, then 3, then 1 finding) and, after four fix waves, an ACCEPT on 2026-09-24; every finding is tracked by id in that task's `findings.json` (12 verified, 2 superseded, 1 accepted limitation), and `codex-findings.ps1 -Stats` shows the five consultations' cost and yield. A second model (GLM-5.3 through a Codex `model_providers` entry) was smoke-tested on the same wire: it works, but `--output-schema` is not enforced on that route and the reply came back as a fenced JSON block (`.collab/multi-model-2026-09-23/`) |

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
R7 (provider support with reviewer lineages, effort mapping, peak-hour handling) and R8
(requested checks, shipped as a prompt/template convention rather than a schema change)
shipped in 0.3.0 — see "A second reviewer through the same bridge" above and
[ROADMAP.md](ROADMAP.md) for the full status lines. Of R9 (review groups), the reviewer
roster and the sequential review **panel** (`-Panel`/`-PanelAll`) and the per-reviewer
**scoreboard** (`codex-findings.ps1 -Stats`) shipped in 0.3.0 too — see "Reviewer roster
and panel" above; the corroboration/contradiction tooling (`-Link`, blind baseline
isolation, canonical-issue relations, grouped stats) is **deferred to 0.4.0**;
ROADMAP.md records the design-review requirements it must meet. Next after that is
R10 (**engines**, planned for 0.4.0): a roster field `engine` so a reviewer can be reached
through the CLI its provider officially supports — Claude Code headless
(`claude -p --json-schema`) or Google's Antigravity CLI (`agy -p --json-schema`) — where
the same models return native structured output on the first turn; verified live before
the design was written down, see ROADMAP.md. Issues and PRs
welcome for any of these, and for the earlier bridge-features list (a bash port, a
`UserPromptSubmit` hook injector, the reverse direction, an MCP server variant,
macOS testing).

---

## Tests

`tests/run-all.ps1` runs the seven scripted harnesses one at a time against a FAKE
`codex` shim — no real `codex`, no quota spent, your own `~/.codex/config.toml` never
touched. Windows PowerShell 5.1 runs everything; `harness-0.3.ps1`, `harness-roster.ps1`
and `harness-format.ps1` also run under PowerShell 7 (`pwsh`). As of 0.3.0: `harness-0.3`
227 assertions, `harness-roster` 113 (roster, panel, reset times across
daylight-saving changes, `-Rate` and `codex-scoreboard.ps1`), `harness-format` 23
(wave 14's contract-first prompt and format-repair retry, including the cases that must
NOT repair), `harness-pending` 26, `harness-fixes` 45, `harness-lock2` 11, `harness-3b`
12. Logs land under
`%TEMP%\codex-consult-tests\`. `tests/` is not part of the installed plugin package —
see `tests/README.md` for what each harness covers and how to run one directly.

```
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
```

---

## Contributing

Keep the script dependency-free and dual-shell (5.1 and 7). If you change the `codex`
invocation, re-check the four gotchas above — they are load-bearing. Please include the
`-DryRun` output for any argv change, and say which shells and platforms you exercised.
Run `tests/run-all.ps1` before a PR and include its summary line.

## License

MIT — see [LICENSE](LICENSE). Author: xelth.com
