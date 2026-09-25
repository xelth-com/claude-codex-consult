# Examples

> **Everything under this directory is FABRICATED.** No Codex call produced it.
> The thread ids, the commit hash, the timings and the reply text were written by
> hand to show the layout the tool produces. Do not cite the reply as a real
> Codex opinion.

`.collab/example-task/` mirrors exactly what appears in your own project after three
structured (0.3.0-style) consultations on one thread. Every 0.3.0 ledger entry records
`reviewer{provider, provider_source, model, model_source, harness,
provider_fingerprint, provider_config, identity_note}` and a `lineage`
(`<provider> :: <model>`, display only; here `openai :: gpt-5.1` for all three consults,
since they share one thread). The parent thread for `fork`/`resume` is chosen from the
newest entry of the SAME reviewer (provider and model compared separately, same
endpoint), never the task's newest thread overall. See the README section "Reviewer
identity and lineage" for what changes when a second provider (e.g. z.ai/GLM) is used
instead. None of these three consults used a reviewer roster or `-Panel`, so their
`roster` and `panel` ledger fields are `null`; the README's "The ledger" and "Reviewer
roster and panel" sections show those fields when a roster is in play.

`codex-consult-roster.json` in this directory is a FABRICATED example roster
(`CODEX_CONSULT_ROSTER`, else `<codex home>/codex-consult-roster.json`): three generic
reviewers — a built-in `openai` model marked `"panel": "weighty"` (joins a `-Panel` run
only on the weighty purposes), a z.ai-shaped GLM entry, and a MiMo-shaped entry whose
`codex_config` supplies a per-run model catalog - plus (0.4.0) two Gemini entries on the
`agy` engine (Google's Antigravity CLI): the label `gemini` on a flash model for every
panel and on the pro model as a `"weighty"` entry (one label may name several models of one
engine; `-Provider gemini -Model gemini-3.1-pro-high` picks the second for a single run).
An agy entry needs a `model` and takes no `codex_config` or `auth`. (`"auth": "none"` is for
a table with neither `env_key` nor a bearer token, such as a local endpoint; it has no
effect on a provider like these, whose tables name an `env_key`.) The FABRICATED ledger
below predates 0.4.0: a 0.4.0 entry also records `reviewer.engine`, `denial_retry` and
`warnings` (see the README's "The ledger"), and an agy consultation's files are named
`NN-agy-<slug>.*`.

```
.collab/
└── example-task/
    ├── sessions.json                                    the ledger
    ├── findings.json                                    the findings tracked by id
    └── handoffs/
        ├── 01-claude-cache-invalidation.md              your brief (you write this)
        ├── 02-codex-cache-invalidation.md               the reply (the script writes this)
        ├── 02-codex-cache-invalidation.reply.json       the raw structured reply, byte for byte
        └── 02-codex-cache-invalidation.events.jsonl     the raw event stream (omitted here)
```

Numbering is a single shared sequence across both sides, so the directory reads as a
conversation in file order. The script always takes the next free 2-digit prefix.

The `.events.jsonl` file is left out of this example because a real one is a few
hundred lines of JSONL. In your own repository it sits next to the reply and is
committed with it.

### Findings and their ids

`02-codex-cache-invalidation.reply.json` is the structured reply Codex returned:
a verdict, the prose in `reply_markdown`, and a `findings[]` array. Each finding gets an
id of the form `F<NN>-<k>` — `NN` the two-digit handoff number of the reply that raised
it (`02` here), `k` its 1-based position in that reply's findings array — so this
example's three findings are `F02-1`, `F02-2`, `F02-3`. They are rendered at the end of
`02-codex-cache-invalidation.md` (`### Findings`, then `### Prior findings`, then the
verdict/blockers/unproven/first-run-checklist blocks), and tracked by id in
`findings.json`, each starting at status `proposed` with its own `history[]`. In your
own project you move them along with
`codex-findings.ps1 -Task <task> -Id F02-1 -Status implemented|verified|rejected|wontfix|superseded -Note … -Evidence …`.

Each entry's `validation_error` is followed by `format_retry` (wave 14): `null` here,
since none of these three FABRICATED consults triggered a format-repair turn. A
non-`null` value (`{attempted, reason, succeeded, thread, wall_seconds, usage, drift,
original, events}` - `events` names the repair turn's event stream when one is kept, the
agy engine's; `null` for codex) means a structured reply that first came back as prose was converted by one
recorded repair turn — see the README's "Structured reply, findings and format repair"
for when it fires and how to read its drift notes.

`findings.json` also carries a top-level `ratings` array (wave 12): one entry per
consultation the judge marked with `codex-findings.ps1 -Task <task> -Rate <n> -Useful
yes|partly|no [-Note "<why>"]` — `{n, consult_id, lineage, provider, model, purpose,
useful, note, when}`, copied from that consultation's ledger entry. This example file
has one FABRICATED rating, for consult `n: 3` (the `decision` consultation above,
`lineage: "openai :: gpt-5.1"`) marked `useful: "yes"`. `codex-scoreboard.ps1` sums
these marks per reviewer and purpose across every task.
