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

Before planning a run against a second reviewer (`-Provider`) or a panel (`-Panel`), run
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-providers.ps1"`
(add `-Provider <name>` to check just one) and read its verdict. **A provider it
reports `unavailable` is not planned on** — do not schedule work against a provider
whose credentials are missing, or whose usage limit resets in the future, on the
strength that it "should" work; the bridge preflights the same check before every run
and will refuse anyway, but knowing this before writing the brief saves the round trip.
A refused preflight is not a bridge failure — `codex-providers.ps1` says why (missing
credentials, an unresolved identity, a recent auth failure, or a usage limit until an
iso timestamp); do not plan further work on that provider until it reports available
again. With a reviewer roster (`CODEX_CONSULT_ROSTER`, else `<codex home>/codex-consult-
roster.json`), the same command's `ROSTER` column and its closing `roster: <path> ->
would select ...` line show which entry a plain consultation would pick right now, and
which ones the walk would skip and why — see the README's "Reviewer roster and panel"
section for the file's shape and the selection rules.

**If a provider you need is missing** (no `[model_providers.<name>]` row, `missing: env
... not set`, no roster), follow the `setup-providers` skill
(`${CLAUDE_PLUGIN_ROOT}/skills/setup-providers/SKILL.md`) before planning work on it; never
handle the key yourself.

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
| `chore` | low | 400 |

`chore` is a bounded search or extraction task — a plain-text reply like `-Raw` (no
schema, no findings bookkeeping), meant for grunt work (searching a big file, extracting
facts) that should not cost a weighty reviewer's tokens; hand it to a cheap roster
member. `-Effort` and `-MaxWords` override the preset when given. Options:

- `-Mode new` — no thread to build on yet. This is the default when no thread of this
  run's reviewer lineage is known.
- `-Mode fork` — branch from the last thread of this lineage. The default once one
  exists, and the right choice whenever another client (Codex CLI, the desktop app)
  might still be appending to that thread.
- `-Mode resume` — sequential continuation of one thread, when nothing else writes to it.
- `-Thread <uuid>` — pick a specific parent. Omitted, the script takes the newest
  verified thread of the SAME lineage (provider, model and endpoint) in
  `.collab/<task>/sessions.json`, never the task's newest thread overall. With a roster,
  the thread's own ledger entry decides the reviewer.
- `-Model <name>` — omit it and the model comes from the roster entry used, else the top
  level of the user's `~/.codex/config.toml`; the resolved model is always pinned with
  `-m`. Only pass it when the user asked for a specific model.
- `-Provider <name>` — a `[model_providers.<name>]` entry from the Codex config
  (case-sensitive), for consulting one specific reviewer (e.g. GLM through a z.ai
  provider entry). Needs `-Model` alongside it unless that provider's roster entry names
  a model. **A second model is consulted in its own lineage; never
  fork/resume across providers** — the bridge enforces this by refusing a `-Thread`
  or automatic parent whose lineage does not match the current `-Provider`/`-Model`,
  but do not try to work around that by hand either. See the README sections "Reviewer
  identity and lineage", "Effort vocabularies (caps-v1)" and "Peak-hour windows" for how
  the provider is resolved, the effort vocabulary per endpoint, and peak-hour handling.
  A ledger entry from a 0.1/0.2 task
  carries no reviewer identity, so its provenance is unknown: the first 0.3.0
  consultation on such a task always starts a new thread, whatever provider or model
  you use.
- `-Engine codex|agy|muse` — the CLI that carries the consultation (0.4.0). Omitted, it comes
  from the roster entry used (`"engine": "agy"` for Gemini through Google's Antigravity CLI),
  else `codex`. For agy, `-Provider` is a free label (e.g. `gemini`) and `-Model` the full
  model id with its tier (`gemini-3.8-flash-high`); no effort is sent (the tier is in the
  id), the default mode is `new` (`-Mode resume` / `-Thread` continue a conversation), and
  `fork`, `-Sandbox workspace-write`, `-CodexConfig` and `-SchemaTransport output-schema`
  are refused. Its files are `handoffs/<NN>-agy-<slug>.*`. An agy run FAILS when the working
  tree (tracked or untracked files) or the collab directory (every task's stores and
  handoffs) changed during it, by the reviewer or anyone else (agy's sandbox does not block
  writes) - do not edit the repository or the collab directory, and run no other
  consultation here, while one runs. Read-only is enforced by evidence for tracked and
  untracked files and the collab directory; not for gitignored paths, submodules or files
  outside the repository. `-DenialRetry 0|1` (default 1): one more turn when a tool was
  auto-denied and the turn produced nothing. `-EngineExe <path>` if `agy` is not on `PATH`.
  `-Provider gemini` without `-Model` on a roster with several `gemini` entries takes the
  first one and warns (`roster: label gemini names 2 entries; ...`) - pass `-Model` for
  another. See the README section "Engines". `muse` (wave 23: Meta's Muse Code CLI for the
  Muse Code subscription; `"engine": "muse"`, label e.g. `meta`, `-Model muse-spark-1.3` or
  `muse-spark-1.3-contributor`): the effort goes as `--reasoning-effort`; the default mode is
  `new`; files `handoffs/<NN>-muse-<slug>.*`; no denial retry; `-MaxModelSteps <n>` caps its
  model steps (muse only). A muse run is REFUSED while `META_API_KEY` or `MODEL_API_KEY` is
  set (it would bill per token), and while no oauth sign-in is established (the keychain
  backend, no `auth.json`, no mechanism: `the Muse sign-in is not established as oauth
  (<cause>): ...`) - also under `-SkipPreflight`, in the roster walk and in a panel; never set
  or unset those variables and never sign in yourself, tell the user (`TBH_CREDENTIAL_BACKEND=file`,
  then `muse login`). Its sign-in is `~/.config/muse/auth.json`; never read that file. The same read-only tree
  check as agy applies. `-EngineExe <path>` names the launcher of the selected engine
  (`-Engine`'s, else the roster's only engine other than codex).
- `-NativeEffort <value>` — send an effort value verbatim when the resolved provider's
  endpoint has no known vocabulary (the run refuses `-Effort` in that case and tells you
  to use this instead).
- `-OffPeakOnly` — refuse the run instead of just warning when the provider's peak-hour
  window (`CODEX_CONSULT_PEAK_<PROVIDER>`) is active, or when no schedule is set for it.
- `-SkipPreflight` — bypass the automatic preflight (the bridge otherwise refuses,
  before the lock, a provider whose credentials are missing, whose availability cannot
  be established, whose endpoint was rejected as unauthenticated in the last 24 h, or
  whose usage limit resets in the future; with a roster, the first entry is then taken
  unchecked). Only for an endpoint that genuinely needs no credential, or once after the
  user rotated a credential — do not use it to push past a real refusal.
- `-CodexConfig key=value[,…]` — pass extra `-c` overrides straight through to `codex
  exec`. The bridge refuses any key it already owns (`model`, `model_provider`,
  `model_reasoning_effort`, `profile`, `model_providers(.*)`). Example: a
  `[model_providers.mimo]` entry (Xiaomi MiMo) needs its model catalog supplied per run
  rather than set globally in the user's Codex config, since a global
  `model_catalog_json` replaces Codex's own catalog and can degrade an unrelated
  model — `-CodexConfig model_catalog_json=~/.codex/model-catalogs.json`.
- `-Purpose <purpose>` (see table above), `-Effort low|medium|high|xhigh`,
  `-MaxWords <n>` (both override the preset), `-TimeoutSec <n>` (default 900),
  `-Sandbox read-only|workspace-write` (default `read-only`).
- `-Artifact <path>` — hash a built artifact (an executable, a bundle) into the ledger
  so the review is bound to it, not just to the source tree. Several paths go in ONE
  comma-separated string (`-Artifact a.exe,b.dll`); the parameter cannot be repeated
  (PowerShell refuses a parameter given twice). A missing path refuses the run
  rather than silently skipping the binding.
- `-Raw` — 0.1-style plain-text reply: no structured schema, no findings bookkeeping.
  Use it for a quick informal ask that is not going into the findings ledger.
- `-Panel` (`-PanelAll` to include `"weighty"` roster entries whatever the purpose) —
  send the **same brief to every available reviewer roster entry**, in parallel across
  endpoints (one after another within one endpoint), each its own consultation, own
  lineage and own reply file. `-PanelConcurrency 1` runs them strictly one after another.
  Needs a reviewer roster; refused with `-Provider`, `-Thread`, or `-Mode resume`. See
  "The panel" below.
- `-SchemaTransport output-schema|prompt-only|native` — override caps-v1's declared reply-schema
  transport for this one run (not with `-Raw`); use it only when you know the endpoint's
  declared transport is wrong for it right now, not as a routine override.
- `-CollabDir <path>` (default `.collab`), `-CodexExe <path>` if `codex` is not on `PATH`.
- `-DryRun` — print the argv, the resolved paths and the planned ledger entry without
  calling Codex. Use it when a call fails and you need to see what would be sent.

The script creates `handoffs/` and `sessions.json` when missing, and writes (with the
`agy` or `muse` engine the prefix is `agy` / `muse` instead of `codex`, and a denial-retry or format-repair
turn keeps its own `.denial-retry.events.jsonl` / `.repair.events.jsonl` next to them):

- `handoffs/<NN>-codex-<slug>.md` — header, the verbatim reply, and (unless `-Raw`)
  the rendered findings/verdict/blockers/unproven/first-run-checklist sections;
- `handoffs/<NN>-codex-<slug>.reply.json` — the raw structured reply, byte for byte
  (structured mode only);
- `handoffs/<NN>-codex-<slug>.events.jsonl` — the raw event stream;
- `handoffs/<NN>-codex-<slug>.original.md` — the first-turn prose, only after a format
  repair (see step 3);
- `findings.json` — every finding from this reply, appended (structured mode only,
  only when there is at least one finding);
- `sessions.json` — one ledger entry appended, the commit point for this consult.

A launched run that fails exits non-zero and is still recorded as an entry, so the ledger
is a complete history and not just a success log. A refusal (bad arguments, an unusable
roster, a preflight refusal, a live previous run, `-OffPeakOnly`) exits non-zero with a
`codex-consult: <message>` line and writes nothing.

## 3. Read, verify, record

Read the reply file. **Verify every finding yourself** before acting on it — open the
cited location, run the build, run the test. Codex proposes; you verify and decide.
A reviewer may answer in plain prose instead of the requested JSON object (most often on
a route that does not enforce the schema: z.ai, or a `prompt-only` route such as MiMo).
With `-FormatRetry 1` (the default) the bridge then spends ONE recorded repair turn on
the same thread when the prose is substantive (in the run's own schema transport - ledger
`format_retry.schema_transport`); when the repair was not attempted
(`format_retry` is `null` and `validation_error` says why) or failed, the prose is kept
with no verdict and no findings, which is not a bridge failure. Only then re-ask once,
explicitly asking it to "return the JSON object", if you need this consultation's
findings tracked.

When `format_retry.succeeded` is `true` in the ledger entry, the ingested findings and
verdict came from a repair turn that converted a prose reply after the fact — **read the
drift notes (`format_retry.drift[]`) before trusting them**. If a drift note disagrees
with what the structured reply says (a different verdict, a numbered answer that does
not match, a finding named in the prose but missing from the object), the original prose
— kept byte for byte as `handoffs/NN-codex-<slug>.original.md` — is the evidence of
record, not the repaired object.

If the reply ends with a `## Requested checks` section (`RC1..RCn`, at most 5 — a
convention, not a schema field), run each one yourself or hand it to a worker,
then fill the `## Requested checks run` table in the next brief
(`templates/brief-review.md`) with the command, the revision it ran against, its exit
status, where the log or observation lives, and its state
(`completed`/`failed`/`skipped`). Cite that table's rows, not a paraphrase, when the
next brief references what was checked.

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
while one is in progress for that task — a whole `-Panel` run included — (under the same
live-process rules, without ever modifying a recovery record); its write, like `-Rate`'s,
goes through the task's commit write lock on a freshly re-read `findings.json`. `-List`
(which flags `[ORPHAN]` findings — a crash between the findings write and the ledger
write) and `-Stats` only read and never take the lock. `.consult.lock` and
`.consult.write.lock` are permanent and git-ignored — deleting them does nothing useful.
`.consult.pending.json` (a panel member's: `.consult.pending-<NN>.json`) means a run in
progress or an interrupted one; the next consultation recovers it automatically unless the
bridge that wrote it or a codex process from it is still alive, in which case it is
refused and the message says which pid.

**Rate the consultation.** After recording the findings (or confirming a prose reply
raised none), mark whether it was actually useful:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-findings.ps1" -Task <task> -Rate <n> -Useful yes|partly|no -Note "<why, required for no>"
```

`<n>` is the ledger entry number of that consultation, not a finding id. Rate **every**
consultation, including a plain-prose reply that produced no ids — skipping those means
the telemetry only ever counts structured reviewers, which biases the scoreboard toward
whoever happens to answer in JSON. `codex-scoreboard.ps1` (below) sums these marks per
reviewer and purpose.

## Role split: the operator's council

Treat every reviewer in play — Claude (this coordinator), Codex, and any roster member
— as a council with these rules, not as a primary reviewer plus optional extras:

- **The coordinator is an equal participant, not a rubber stamp**, and is the judge by
  default: its own ideas are on the table alongside every reviewer's. For a genuinely
  hard question, the judge role can be handed to one reviewer explicitly — a
  `-Purpose decision` consultation whose brief references the other members' reply
  files by path and asks for a verdict; record that verdict in `state.md` as the
  decision, but the coordinator still executes and verifies it.
- **Every brief goes to the panel by default (`-Panel`).** Cheap roster members join
  every brief; weighty ones (roster `"panel": "weighty"`) join only the weighty
  purposes (`framing`, `decision`, `core-contract`, `acceptance`, `stuck`) unless you
  pass `-PanelAll`. Tokens are finite for every provider — do not spend a weighty
  reviewer on a checkpoint or a routine diff review unless the question is hard.
- **A provider without a credential or without tokens left is simply not used** — the
  roster skips it and records why (see the README's "Reviewer roster and panel"); a fallback reviewer's
  reply is never presented as the primary's, and lineage stays per reviewer — no
  fork/resume across providers, panel or not.
- **Disagreement is the signal, not noise.** Record it in `state.md` as an open item
  until evidence settles who was right; `codex-findings.ps1 -Stats`'s per-reviewer
  scoreboard shows, over time, who actually finds what.
- **Before picking a panel or a judge for a hard question, check the scoreboard.** Run
  `codex-scoreboard.ps1` (see the README's "Usefulness telemetry: codex-scoreboard.ps1") to see which
  reviewer has actually been useful on that purpose so far, not just who is cheapest or
  fastest.
- **Chores go to cheap members.** Hand bounded search/extraction work to a cheap roster
  member with `-Purpose chore`, and pre-digest large inputs before a weighty brief — put
  the extract in the brief, not the raw file.
- **Acceptance authority for a release stays with the reviewer who raised the
  findings.** A stand-in's ACCEPT is recorded, but the tag waits for the one who raised
  them.

When a fresh-context verifier of the same model family (Claude, in the mechanics role)
is also reviewing, that split is a further, orthogonal division of labor, not exclusive
responsibilities — either may challenge anything the other says:

- **The verifier** is best used for mechanics: lint, interpreter/version compatibility,
  build correctness, test wiring, whether the code does what a summary claims it does.
- **Codex** is best used for protocol and state-machine correctness, and for naming
  what the evidence does not show — the failure modes a mechanical read does not surface.

On a real multi-wave task the two typically find mostly different defects; treat both
as required coverage, not as a redundant second look.

## The panel

`-Panel` (a reviewer roster is required — see the README's "Reviewer roster and panel") sends the **same
brief to every available roster entry**: each member is a complete, independent
consultation — its own preflight, its own lineage, its own reply file
(`handoffs/NN-codex-<ReplyName>-<provider>.md`) and its own ledger entry (`panel`
field). `-PanelAll` includes `"weighty"` roster entries whatever the purpose; without
it, a `"weighty"` entry only joins on the weighty purposes.

- **Parallel across endpoints** (0.4.x wave 21) — members run as processes of their own,
  at once when they reach different endpoints, one after another within one endpoint (one
  provider label, or labels on one provider fingerprint such as all agy labels); the
  roster's top-level `"parallel": {"<label>": n}` raises a label's limit, and
  `-PanelConcurrency <n>` caps the total (`1` = strictly one after another). The panel
  takes about as long as its slowest member, and it holds the task lock for the whole
  panel: no `codex-findings.ps1 -Status`/`-Rate` on that task until it ends. The ledger
  stays sorted by `n` (roster order) whatever finishes first.
- A failing member does not stop the rest. With `-PanelConcurrency 1` a member whose
  failure leaves surviving processes stops the remaining members — recorded `skipped` with
  reason `not started: the previous member (<lineage>) left surviving processes
  (.consult.pending-<NN>.json state survivors); recover the task first` (F15-3); at the
  default the others run on, and the kept record blocks the task afterwards until it is
  recovered.
- **Do not run other consultations in the repository beside a panel with agy members**:
  an agy member's read-only check fails on any collab change outside its own task's stores
  and its siblings' handoffs.
- **Per-lineage** — each member forks the newest thread of its own lineage (or starts
  one); never fork or resume one member's thread under another's provider/model.
- **Members see the same open-findings snapshot** — every member is shown the findings
  that were open when the panel started, not a later member's answer. This is **NOT
  blind between waves**: within one panel run, all members see the same pre-panel
  state, but a LATER panel (on the same task) will see findings the earlier panel
  raised, exactly as a normal sequential consultation would.
- A summary block closes the run (one line per member: lineage, verdict or failure,
  finding counts); the run exits `0` only when every member produced a usable reply.
- Record every member's findings normally with `codex-findings.ps1`; nothing about a
  panel changes the status lifecycle. There is still no `-Link`/`-Stats -Group` tooling
  for corroboration or contradiction between members — compare replies by hand and use
  `-Stats`'s scoreboard to see who finds what over time (ROADMAP R9, deferred to 0.4.0).

Without `-Panel`, `-Provider` still lets you consult one specific reviewer on the same
wire (e.g. a specific roster member, or any `[model_providers.<name>]` entry) — see the
README's "Reviewer identity and lineage" and "Effort vocabularies (caps-v1)" for how
identity, lineage and effort are resolved for a single-reviewer run.

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
8. **Never use a provider without a credential or without tokens left.** The roster
   exists so this is checked automatically, not assumed; a provider `codex-providers.ps1`
   or a roster walk reports skipped/unavailable is not planned on.
9. **A fallback reviewer's reply is never presented as the primary's.** Lineage stays
   per reviewer; note explicitly which reviewer actually answered, panel or not.
10. **Judge delegation is explicit.** The coordinator is the judge by default; handing
    that role to one reviewer for a hard question is a deliberate `-Purpose decision`
    consultation referencing the other members' replies, recorded in `state.md` — never
    an implicit "whoever answered ACCEPT wins".
