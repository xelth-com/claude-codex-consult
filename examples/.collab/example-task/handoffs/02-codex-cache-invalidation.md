# Handoff 02 - Codex: cache-invalidation

> FABRICATED EXAMPLE. No Codex call produced this file. The header below shows the
> exact fields the script emits; the thread ids, timings and reply text are invented.

Date: 2026-09-22 11:24 local. Author: Codex (model config default, effort high), Codex CLI 0.155.1.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only). Argv: `codex exec --sandbox read-only --color never --json -c model_reasoning_effort="high" -o /tmp/codex-consult-last-0f3c.md fork 01a0c839-48ba-7182-8d15-fdc13dd17193 -` (prompt on stdin).
Parent thread: `01a0c839-48ba-7182-8d15-fdc13dd17193`. Result thread: `01a0c86e-5193-7d70-a644-63a5c3f224b3` (source: events).
Brief: `.collab/example-task/handoffs/01-claude-cache-invalidation.md`. Reviewed revision: 4e9cc4f + uncommitted. Outcome: usable reply. Wall time: 41.3 s.
Raw event stream: `handoffs/02-codex-cache-invalidation.events.jsonl`.
Verbatim reply follows.

---

**Q1 — Generation counter, yes, but not for the reason you gave.** The 50k evictions are
not the strongest argument: `moka`'s invalidate is cheap and you could batch them after
the transaction commits. The stronger argument is correctness under concurrency. With
direct eviction you have a read-repopulate window: a reader that misses, reads the old
row, then loses the race to your eviction, writes a stale entry that now lives for the
full TTL. A generation bump closes that window because the reader's key becomes
unreachable regardless of when it writes. Take option 2.

The stranded-entry cost is real but bounded and self-correcting: `moka` evicts by size
under pressure before the TTL matters, so the worst case is not "two working sets" but
"one working set plus whatever fits". Set an explicit max capacity if you have not.

**Q2 — Put the generation in the key, not a side table.** A side table means every read
becomes two lookups, and when this moves to Redis that is two round trips instead of
one, which is exactly the cost you are trying to avoid by caching. In the key, the
generation is free on read: you already have `(tenant_id, resource_kind)` in hand at
lookup time, so you fetch the generation from a small in-process map (one entry per
tenant/kind pair, not per resource) and concatenate.

For the Redis move, that same generation map is the only thing that needs to become
shared state, and it is small and monotonic — which is the easiest possible thing to
put in Redis. Compare that to migrating a side table of per-key versions.

**Q3 — Yes: the rollback case you named, and one you did not.** Bumping the generation
before the transaction commits is safe if the transaction rolls back (you lose cache
entries, you do not serve stale data). Bumping it *after* commit is the dangerous
ordering: between commit and bump, readers populate the cache from the new row under the
*old* generation, and those entries survive the bump only if... they do not, actually —
they are unreachable too. So post-commit bump is also safe against staleness, it just
strands more. Bump before commit; treat the generation as a lower bound on freshness,
never an exact version.

The failure mode you did not name is generation overflow-by-restart: if the counter
lives in process memory and resets to 0 on restart, a surviving external cache (once you
move to Redis) will serve entries written under a *higher* generation from the previous
process lifetime. Seed the counter from wall-clock milliseconds at startup rather than
from 0, or persist it. Cheap now, painful later.

**Q4 — One thing.** `src/api/resource.rs:248` holds the write transaction across the
whole 50k-row import, which means the generation bump — whenever you place it — is
invisible to readers until that transaction commits, i.e. potentially for minutes. For
the duration, readers serve pre-import data from cache *and* from the database
consistently, so this is not a correctness bug, but it does mean "invalidation happened"
and "readers see new data" are minutes apart for imports. If that matters to a caller,
chunk the import transaction; if it does not, write the assumption down next to the bump
so the next reader of this code does not rediscover it.

I would not start with option 1 as an optimisation for single-row paths. Two
invalidation mechanisms in one cache is how you get a bug that only reproduces under
load. Add it only if profiling says the stranded entries cost you something measurable.
