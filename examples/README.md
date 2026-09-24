# Examples

> **Everything under this directory is FABRICATED.** No Codex call produced it.
> The thread ids, the commit hash, the timings and the reply text were written by
> hand to show the layout the tool produces. Do not cite the reply as a real
> Codex opinion.

`.collab/example-task/` mirrors exactly what appears in your own project after one
structured (0.2.0-style) consultation:

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
