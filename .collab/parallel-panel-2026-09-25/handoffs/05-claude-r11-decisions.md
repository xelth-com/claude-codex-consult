# R11 - decisions after the design review (round 1)

Reviews: 02 kimi :: k3 (ADVISE, F02-1..5), 03 byteplus :: deepseek-v4.1-flash (ADVISE, F03-1..11),
04 ZAI :: glm-5.3 (ADVISE, F04-1..8). All three accept member-side commit under a write lock (Q1);
none accepts the recovery model as written. The design in 01 stands where not overridden here.

D1. Liveness of every recovery record includes its WRITER (F03-1, F02-1, F04-4, F03-2, F04-5).
    Records carry the writing bridge's `pid` + `start_time`. A member rewrites the record the parent
    wrote for it with its own pid + start time as its first act. `Test-PendingActive`: a live writer
    (pid + matching start time) makes a record ACTIVE in every state, `reserved` included. For panel
    member records (a `panel` field) activity is judged ONLY by recorded pids + start times (writer,
    child, survivors) and, on Windows, by descendants of the recorded writer pid - never by the
    machine-wide name rule. Non-panel records keep today's rules plus the writer check.
    New state `committing`, written before the member takes the write lock. A member re-checks its
    parent (pid + start time) right before `launching` and stops there, nothing started, when the
    parent is gone.

D2. The write lock is an OS-held handle (F03-5a, F04-3). `<task>/.consult.write.lock`, permanent
    file, never unlinked, opened exclusively like `Enter-TaskLock` (release = close; a killed holder
    releases it). ONE shared routine "take write lock -> re-read stores -> apply delta -> write ->
    release" is used by panel members, single runs AND `codex-findings.ps1` (status changes,
    ratings), so no writer ever writes a store snapshot read before the lock.

D3. Give-up never touches the stores (F04-2, F02-4). Write lock not acquired within 60 s (retry
    with backoff): the member keeps its record in state `committing` with a note naming the reply
    files, keeps reply.json / events / the raw reply, exits non-zero, and the panel summary names it
    "commit blocked". The next run consumes the record like any interrupted reservation (numbering
    skips it) and names the orphaned reply (the `Get-PendingOriginalNote` flow).

D4. Ingest and render inside the lock (F03-6). Order: reply.json (before the lock) -> lock ->
    re-read -> `Add-ReplyFindings` on the fresh store -> handoff .md rendered from THAT ingest ->
    findings.json -> sessions.json (entry inserted by n) -> remove record -> release. A kill inside
    the lock can still leave ORPHAN findings (F03-11): accepted and documented; harness case added.

D5. Multiple leftovers (F02-3, F03-7). `Get-NextNumbers` takes an array of leftover records (max
    n / NN over all, per-record Recovered). Every reader enumerates `.consult.pending*.json`
    (`codex-consult.ps1`, `codex-findings.ps1 -List/-Status`). At the summary the parent removes
    the records of members it never launched and of launched members that are gone with the record
    still `reserved` (nothing was started).

D6. Member proof without the lock file (F03-5b). A member accepts its spec only when its own
    per-member record (written by the parent before the launch) names the same panel id, n, NN and
    parent pid + start time, and that parent is alive. Otherwise it refuses with a message naming
    the mismatch; nothing started.

D7. agy tree check (F04-1; F02-2 accepted). For a member of a concurrent panel the collab comparison
    also ignores the Write-TextAtomic temp variant of every ignored path (`.<name>.<guid>.tmp` in the
    same directory as `sessions.json`, `findings.json`, a sibling's `handoffs/<NN>-*`). The
    whole-collab-root scope stays (wave 18): a run on ANOTHER task committing during an agy run
    fails that run - pre-existing, now documented as a residual; do not run other tasks beside a
    panel with agy members.

D8. Endpoint-aware concurrency (F03-4, F04-8). Members run in parallel across provider labels and
    one after another within a label (all entries of one label share an endpoint or a sign-in; agy
    entries share the Google sign-in). The roster may raise a label's limit: an optional top-level
    `"parallel": { "<provider label>": <n> }` (validated: integers >= 1, labels present in the
    roster). `-PanelConcurrency <n>` is a global cap on top (0 = none, the default; 1 = strictly one
    after another, where the F15-3 "later members not started" rule still applies). Dry run and
    the ledger `panel` record show the effective plan (`concurrency`, the per-label limits).

D9. Completion time for health (F03-3, F02-5). Ledger entries gain `finished_at` (ISO, written at
    commit). `Get-EndpointHealth` orders by `finished_at` (older entries: `when` + `wall_seconds`),
    ties broken by n.

D10. Order invariant (F04-7, F03-9). `consults` stays sorted by n. Inside one panel a lineage
     appears once (same provider + model is refused), and across runs the task lock serialises
     lineages, so "highest n of a lineage = newest thread" holds; `Select-ParentThread` unchanged.
     Stated in README and asserted by a harness case (slowest member first in roster order).

D11. Guard from the spec (F04-6). The parent's kill guard for a member = its timeout + the format
     repair and denial retry budgets (when enabled) + 60 s write lock + 120 s slack.

D12. Task lock for the whole panel stays (F03-8 accepted as a limitation): `codex-findings.ps1`
     writes are refused while a panel runs, as a single run refuses them today. D2 makes relaxing
     this later (R12) safe. Documented.

D13. Fakes (F03-10): a per-model delay map and per-model reply for fake-codex3 (keyed by `-m`) and a
     delay for fake-agy, before the panel cases.
