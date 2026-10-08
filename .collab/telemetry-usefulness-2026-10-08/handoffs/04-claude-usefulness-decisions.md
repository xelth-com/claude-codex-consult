# The public usefulness table - decisions after the framing (02 astra, 03 kimi)

Coordinator: Claude Code (Fable 5.1), 2026-10-08. Both reviewers converge; the coordinator is the judge.

U1. **Ranking = a shrunken useful-rate with an uncertainty penalty.** Per reviewer row, over DEDUPED ratings (U5):
    score = 100 x the 5th percentile of (pU + 0.5 pP) under Dirichlet(U+1, P+1, N+1) (astra; kimi's Beta prior with
    k=10 is the same idea - the lower bound is used because it penalises small n without a magic k). Eligibility for
    the ranked top: at least 10 ratings (astra); rows below the floor are shown in a "provisional" group after the
    ranked ones, ordered by the same score. Findings per consultation, blockers, usable rate, failures and wall minutes
    stay COLUMNS and never enter the score (both; F02-1). Paging: global rank only, ten rows a page, "next 10", the
    page bound to the cached snapshot and a scoring version; a vendor FILTER (kimi) instead of rank-within-vendor.
U2. **Judge weights: a versioned, hand-kept tier table, shown as an experimental column beside the raw counts** - never
    external chat rankings (they do not measure review judging), never the bridge's own table (circular, a feedback
    loop - F03-1). Tiers by model family, published with the site: frontier 1.0 (Fable, Opus 5.5, GPT-6 Astra, Gemini
    3.1 Pro, K3...), strong 0.7, mid 0.4, small 0.2 - the operator's coefficients, with the table versioned so a
    change is a visible event. The main score (U1) stays UNWEIGHTED; the weighted rate `sum w (yes + 0.5 partial) /
    sum w` is the second column "judge-weighted", with the share of ratings whose judge is unknown. Ratings without a
    judge (every event before 0.6.1): a documented one-time legacy rule - the maintainer's own installation (known out
    of band: frontier coordinators) weight 1.0; any other unknown judge the neutral 1.0 too, counted in the unknown
    share (astra), and a later stratified view per judge tier (kimi) when the data warrants it.
U3. **The judge field, resolved at RATING time** (F02-3): `judge: {provider: <vendor class>, model: <closed-list id or
    "other">, source: "rating_actor" | "consult_coordinator" | "unknown"}` - the rating actor from
    CODEX_CONSULT_COORDINATOR and the host markers of the process that runs `-Rate`; when that is unset, the ledger
    entry's consult-time coordinator with source `consult_coordinator`; else `unknown`. A DEDICATED classifier for
    coordinator identities (F02-6): the coordinator record `{provider, model, engine, host}` has no provider_config,
    so its provider NAME is mapped to a vendor class (openai -> openai, anthropic/claude-code -> anthropic, the roster
    label's table host when it is a roster label, else other) and its model through the same closed lists. No host in
    the event (noise; both).
U4. **Unknown models: (c) the allow list grows by pull request**, nothing else (both; F02-2 rejects the regex + threshold
    route: the label leaves the machine before any threshold). A consent flag (kimi's option) is deferred; family
    tokens (a) are not sent.
U5. **One rating per consultation on the site: a `consult_ref`.** The bridge mints a random 128-bit id per consultation
    (no derivation from anything local), sends it in the consultation event AND in every rating event of that
    consultation; the aggregation keeps the LATEST rating per consult_ref (the local semantics; F02-4) and links
    ratings to consultations (rating coverage per reviewer becomes exact). Events without consult_ref (before 0.6.1)
    keep today's counting.
U6. **The aggregation window** (F02-5): the 5000-event cap becomes a windowed query that reads every event of the
    requested days (or says it was cut); the table states the cut.
U7. **Order:** the site half (U1, U2 unweighted first + the judge column reading `judge` when present, U6, paging) ships
    now on the existing events; the bridge half (U3, U5) is 0.6.1 with the time-only reset parse (TECH_DEBT); the
    tier table starts with the operator's values and is versioned in the site repository.

Findings F02-1..6 and F03-1 are answered by U1-U6; they move to implemented with the two halves.
