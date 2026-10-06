# Wave 28d re-acceptance (handoffs 52-55) - the verdict of the judge: 0.5.0 is tagged

Panel 7d9a3136 on d65e2e9 (range fc6978a..d65e2e9), required glm-5.3 and mimo-v2.6-pro, third member
gemini-3.8-flash-high [agy]; gpt-6-astra was skipped by its plan's usage limit. glm ACCEPT (F53-1 note), gemini
ACCEPT (no finding), mimo HOLD (F54-1..2 major, F54-3..4 minor). All three confirm F48-1..4, F49-1..4 and
F50-1..2 fixed: they are verified.

The judge's decision on the HOLD. The two findings mimo rates major concern diagnostics, not data, privacy
or the outcome of a run: F54-1 - the recovery record names only the confirmed survivors, so the next run
cannot re-check a descendant whose start time could not be read (the run itself already refuses the
continuation and names the pid on the console); F54-2 - the append-only count of events that could not be
spooled can lose entries under concurrent appends (the count is a diagnostic of best-effort telemetry, the
events themselves were already dropped by design). Both are rated MINOR by the judge, with F54-3 (the
liveness of the forgetting marker at the resolution of a start time string), F54-4 (a multi-line inline ask
collapsed to one line) and F53-1 (the not-spooled file grows between forgets) they form wave 28e of the 0.6.0
candidate, to be built with wave 29 and reviewed with it. Four rounds of review of the 0.5.0 candidate by the
same required reviewer went from five majors on the whole wave to two on a record field and a counter; the
rest of the candidate has been accepted by every reviewer of the last two rounds.

Decision: 0.5.0 is tagged on d65e2e9 (the collab commits after it carry no code).

Wave 28e (for the 0.6.0 candidate, with wave 29):
E1. F54-1: the recovery record gains `unverified[]` (pid, why) beside `survivors[]`; the next run reports
    them and re-checks the ones whose identity can be read then.
E2. F54-2: the not-spooled count is one file per producer process (`not-spooled-<pid>-<start>.ndjson`),
    appended without contention; `-Status` sums them; a flush folds files of dead producers into one line of
    `.last` and removes them (F53-1: the files never grow between forgets).
E3. F54-3: the marker's owner is compared on pid AND a start time with full resolution (ticks), as the flush
    lock does.
E4. F54-4: the inline anchor keeps the first line of a multi-line ask whole (up to 300 characters) and the
    count of the remaining lines.
