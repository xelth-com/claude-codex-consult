# Examples

> **Everything under this directory is FABRICATED.** No Codex call produced it.
> The thread ids, the commit hash, the timings and the reply text were written by
> hand to show the layout the tool produces. Do not cite the reply as a real
> Codex opinion.

`.collab/example-task/` mirrors exactly what appears in your own project after one
consultation:

```
.collab/
└── example-task/
    ├── sessions.json                                  the ledger
    └── handoffs/
        ├── 01-claude-cache-invalidation.md            your brief (you write this)
        ├── 02-codex-cache-invalidation.md             the reply (the script writes this)
        └── 02-codex-cache-invalidation.events.jsonl   the raw event stream (omitted here)
```

Numbering is a single shared sequence across both sides, so the directory reads as a
conversation in file order. The script always takes the next free 2-digit prefix.

The `.events.jsonl` file is left out of this example because a real one is a few
hundred lines of JSONL. In your own repository it sits next to the reply and is
committed with it.
