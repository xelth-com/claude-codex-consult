# Handoff 01 - Claude: cache invalidation strategy

> FABRICATED EXAMPLE. Written by hand to illustrate the brief format.

Date: 2026-09-22. Base commit: `4e9cc4f` (+ uncommitted work in `src/cache/`).

## Question

We are replacing a per-request cache lookup with a shared read-through cache. I need a
judgement on the invalidation strategy before I write the eviction path, because it
determines the key schema and that is expensive to change later.

## Task state

- Done: `CacheKey` type, the read-through wrapper, and a `moka`-backed in-process store
  (`src/cache/store.rs:1-180`).
- Open: invalidation. Nothing evicts anything yet except the TTL.
- Not in scope: the distributed/multi-process case. Single process for now, but the key
  schema should not make a later move to Redis absurd.

## Evidence

- `src/cache/key.rs:22` - `CacheKey` is currently `(tenant_id, resource_kind, resource_id)`.
- `src/cache/store.rs:96` - read-through entry point; TTL is a flat 300 s.
- `src/api/resource.rs:210-260` - the four write paths that must invalidate:
  `create`, `update`, `delete`, and the bulk `import` (which can touch ~50k rows).
- `src/api/resource.rs:248` - `import` currently holds the write transaction for the
  whole batch, so anything we do per-row there is multiplied by 50k.

## Alternatives weighed

1. **Direct key eviction on write.** Each write path computes the exact key and evicts
   it. Precise, but `import` would issue 50k evictions inside the transaction.
2. **Generation counter per (tenant, resource_kind).** Keys embed a generation; a write
   bumps the generation and every old key becomes unreachable. O(1) invalidation for
   `import`, but old entries linger until TTL and the key gets a fourth component.
3. **Drop the cache entirely for tenants with an active import.** Simple, but adds a
   piece of global mutable state I do not love.

Current preference: 2, with 1 as a later optimisation for the single-row paths.

## Questions

- **Q1.** Is the generation counter the right default here, or is the memory cost of
  stranded entries (up to the 300 s TTL, worst case the whole working set twice) worse
  than 50k evictions inside a transaction?
- **Q2.** If generation: should the counter live in the key or in a side table consulted
  on read? What does that cost when this later moves to Redis?
- **Q3.** Is there a failure mode in option 2 I have not named — specifically around a
  write that is rolled back after the generation was already bumped?
- **Q4.** Anything in `src/api/resource.rs:210-260` that makes any of these three
  materially harder than I have assumed?

Answer by number. Keep it under 600 words.
