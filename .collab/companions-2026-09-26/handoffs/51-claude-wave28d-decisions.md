# Wave 28c re-acceptance (handoffs 46-50) - decisions for wave 28d

Panel 7e4efeb8 on fc6978a (range e5c6992..fc6978a), required mimo-v2.6-pro, qwen3.8-max and glm-5.3: glm ACCEPT
(no finding), qwen ACCEPT (F49-1 minor, F49-2..4 note), muse-spark ACCEPT (F50-1 minor, F50-2 note), mimo HOLD
(F48-1..3 major, F48-4 minor). All four confirm the findings of the previous round fixed: F41-1, F42-1..9,
F43-1..5, F43-7, F44-1..2 and F44-4..6 are verified. Three of four accept; the HOLD of a required reviewer
stands, and its three majors are small, local and real. Wave 28d touches the telemetry code and one warning.

D1. The spool is rewritten atomically (F48-1 major, F49-3): the kept lines go to `<spool file>.tmp` in the same
    directory, are flushed to disk, and the temporary file REPLACES the spool in one step; nothing truncates
    the spool in place. A `.tmp` left by a crash is removed by the next rewrite. The deadline is checked
    before a rewrite starts, never inside one.
D2. The forgetting marker heals itself (F48-2 major): the marker holds the pid, the start time and the time of
    its owner; `-Forget` removes it in `finally`; a producer or a sender that meets a marker whose owner is
    gone removes it (one line in `.last`) and goes on; a marker with a living owner blocks as before.
D3. A flush lock is born with its owner (F48-3 major, F49-4): the lock is created with its owner record in one
    step (a temporary file moved into place without overwriting), so a healthy sender never leaves an
    ownerless lock. An ownerless or unreadable lock counts as HELD while it is younger than 30 s; after that it
    is removed and the sender starts over. A lock with a living owner is never taken over; when it is older
    than 30 minutes, `.last` and `-Status` say `sender stuck since <time> (pid <n>)` so the operator can act.
D4. The not-spooled count cannot be lost (F49-2): it is an append-only file written without the telemetry
    lock; `-Status` counts its lines since the last flush.
D5. Unverified descendants are always named (F49-1): when a kill leaves survivors AND descendants whose
    identity could not be read, the warning and the outcome text list both groups.
D6. The model comparison lower-cases both sides (F50-1).
D7. The re-read line exists for an inline prompt too (F50-2): a member with `context_tokens` that runs without
    a brief file gets the one-line ask repeated at the end of the prompt.
D8. The prompt hash and thread reuse (F48-4): find every hash or key that decides thread reuse, lineage or the
    finding ids; when the appended line takes part in one, exclude it (it is bridge text, the same for every
    run of such a member); the CHANGELOG states what was found.

Harness cases for D1-D7 (a crash between the temporary file and the replace is simulated with a gated test
hook; a marker and a lock of a dead owner; a lock without an owner, young and old). Both full suites end `0
failed` on the final code. Re-acceptance: by mimo (required) with glm; the brief lists D1-D8 and the commit.
