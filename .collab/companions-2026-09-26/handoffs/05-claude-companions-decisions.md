# R14 + R15 + R16 - decisions after the design review (round 1)

Reviews: 02 mimo :: mimo-v2.6-pro (ADVISE, F02-1..15), 03 kimi :: k3 (ADVISE, F03-1..12),
04 alibaba :: qwen3.8-max (ADVISE, F04-1..18). Panel 3 at once, 31 min wall. The design in 01
stands where not overridden here. The availability addendum (items 9-11) is implemented in the
"operator visibility" wave (wave 24) with the decisions D14-D17 below; the rest is the
companions wave.

D1. One selection rule (F04-1, F02-5, F03-2, F04-3, F04-14). Eligible = available AND passes the
    weighty gate AND matches -Engine/-Model, computed once; ranking, the draw and exploration all
    use that one set. Fill slots 1..k by the weighted draw (D4). Diversity is a reserve, not a
    first pass: for the first min(k, number of labs with an entry scoring >= neutral) slots the
    draw is restricted to entries whose lab is not yet represented AND whose score is >= the
    neutral score; the remaining slots draw from the whole eligible rest. An entry below neutral
    never earns a lab seat. `lab` is NEVER defaulted to the provider label: a roster entry without
    `lab` gets its lab from a vendor table keyed on the model id prefix (qwen -> alibaba,
    deepseek -> deepseek, kimi/k3 -> moonshot, glm -> zhipu, dola/seed -> bytedance, mimo ->
    xiaomi, gemini -> google, muse -> meta, gpt -> openai); an unknown prefix = singleton lab
    (the entry's own lineage), with a run warning. Labs are canonicalised lowercase.
D2. Ratings and evidence keys (F02-2, F04-2, F03-11, F04-18). Ratings are keyed by `consult_id`
    (validated at -Rate time against the ledger entry's id; `n` kept for display) and copy
    `purpose`, `topics[]`, provider, model, engine and the consultation's `when` onto the rating
    record. Scoring reads the denormalised rating fields only - no join by `n` across tasks. The
    scoring function lives in `codex-consult-common.ps1` and is shared by the bridge and the
    scoreboard; the scoreboard reads findings.json of every task once per run (cached in memory).
D3. Score = a rate with a prior (F02-1, F03-1, F04-4, F02-3): for the ratings of the last 90 days
    (by the CONSULTATION's `when`, latest rating per consultation wins),
    `w = (yes + 0.5*partly + 2p) / (n + 4p)`, p = 0.5, then scaled into [0.25, 2] (w' = 0.25 +
    1.75*w). Hierarchy: the (lineage, purpose[, topic]) rate when it has >= 3 ratings, else the
    lineage's all-purpose rate (same formula), else neutral (w = 0.5 -> 1.125). Topics: canonical
    lowercase slugs, deduplicated; a rating credits each of its topics 1/t; a topic'd request
    averages weighted evidence (counts pooled), never a mean of means.
D4. The draw is exact and portable (F02-7, F04-5, F04-6, F03-7). Seed = SHA-256 of `task |
    purpose | brief_sha256 | sorted eligible lineages | nonce` where the nonce is `-PanelSeed <n>`
    when given (also `CODEX_CONSULT_TEST_PANEL_SEED`), else the date (UTC, YYYY-MM-DD) - so a dry
    run and the real run of the same day print the same pick. Per slot: the first 8 bytes of
    SHA-256(seed || slot index) as a uniform in [0,1) times the remaining weight sum picks the
    winner, which is removed; exploration: with probability 0.2 (from the same uniform's next
    8 bytes) the slot draws uniformly from the same restricted pool. Byte-identical on Windows
    PowerShell 5.1 and pwsh 7 (a harness case asserts exact sequences for fixed seeds; a separate
    statistical case bounds the exploration rate over many seeds).
D5. Roster order stays the default until there is evidence (F02-8, F03-6). `-PanelOrder
    roster|routed` (default `routed`); in `routed` mode a lineage without >= 3 ratings on any
    purpose is scored neutral, and when NO eligible lineage has >= 3 ratings the run falls back
    to `roster` mode and records `routing.fallback: "no ratings"` (no shuffle without evidence).
    `roster` mode = today's order with size and eligibility only, no exploration.
D6. Panel size semantics (F02-6, F04-11, F04-17, F03-12). Defaults per purpose: chore 1, none 1,
    checkpoint 1, diff-review 2, framing 3, decision 3, core-contract 4, acceptance 4, stuck all.
    `-PanelSize` with `-PanelAll` refused. The size bounds members STARTED; the summary and the
    ledger `panel` record state `asked k, started j, usable i`; no backfill (documented).
    Third member state `not-picked` (reason `panel size k`), excluded from skip reporting. The
    floor warning (framing/decision with fewer than 2 members) goes into runWarnings and the
    ledger; suppressed when `-PanelSize` was given explicitly.
D7. `-Require` contract (F02-12, F04-7, F04-8, F03-9, F04-15, F03-10, F04-13). Matcher: a roster
    position `#5`, a bare provider label (every entry of it), or `provider :: model` with an
    optional ` [engine]` suffix, compared on the resolved identity (provider, model, engine) -
    never on display strings; a model-less entry is named by position or label. Required
    members are pinned BEFORE the draw fills the seats (they take seats first, the size counts
    them); evaluated with roster-walk availability semantics (a usage limit without a reset time
    is unavailable) on `-Panel` and on single `-Provider` runs alike; unavailable -> refused
    before anything starts, exit 5, dry run shows the same. Roster `require: { <purpose>:
    [matchers] }` validated at load: every matcher must resolve to an entry (else roster error).
    A required member failing AFTER start aborts the panel at the next slot boundary, exit 5, the
    ledger records the required set. Exit code 5 documented in the README table and the skill.
    The roster validator's allowlists gain `lab` (entry), `require` (top level).
D8. Roles (F02-13, F03-3, F03-8, F04-16). Role names are slugs (`^[a-z0-9][a-z0-9._-]{0,40}$`)
    validated before any path join; resolution: `.collab/roles/<name>.md` (repository) wins over
    the plugin's `templates/role-<name>.md`; `-Role` and `-Roles` are mutually exclusive; more
    roles than picked members is refused; `-Roles` assigns by SCORE RANK among the picked members
    (highest first), and a roster entry may carry `roles: [..]` it is willing to take (a role
    goes only to a willing entry when any is willing). The role block is inserted after the ask
    and before the brief, never inside the output contract. Ledger `role` per member.
D9. Tests to update (F04-12, F02-14): every assertion pinning roster order or "N of M would run"
    per purpose is listed in the brief and rewritten to the recorded `routing.picked`; fixed-seed
    exact sequences replace rate assertions; cases for task-local n collisions, re-rating recency,
    lab normalisation, quality gaps in diversity, size precedence, -Require pinning and matcher,
    role slug traversal, unknown-reset transitions, shared endpoint outages.
D10. Docs (F02-15): "about five" is labelled an operational heuristic; the scoreboard gains a
     column for unique findings per member so the claim can be measured later.
D11. Exploration and gates (F04-14): see D1 - one eligible set.

Availability (implemented in wave 24, the operator visibility wave):
D14. One shared availability verdict (F02-9, F03-5): `Get-PreflightVerdict -RosterWalk` semantics
     are the truth for every surface - the roster walk, `codex-providers.ps1` rows, `-Short` and
     the hook; a quota without a known reset reads "out (limit hit <t>, reset unknown; retry
     after <t+60 min>)" everywhere (today only the walk refuses it; the display lags).
D15. Per-entry availability records (F02-10, F04-9): `Select-PanelMembers` gains `-NoNetwork`
     (passed to its preflight) and the hook/listing build their lines from its full member list
     (every entry judged, not the first available one); one clause per endpoint group when all
     of the group share the state, else per entry.
D16. Endpoint groups over ALL resolved roster identities (F02-11): the credential/quota group map
     is computed from every roster entry (not from the selected runners), and an outage marks the
     whole group.
D17. The line itself (F04-10, F03-4): no per-reason truncation in the short form; three counts
     (`available / out / not checked`); reset times converted with ToLocalTime() and a rounded
     relative hint; the hook's parser is updated in the same wave (or `-Short` gets a JSON mode
     the hook reads).

D12. Roster extension point (2026-09-26, for the Rust implementation C3 that shares the roster file):
     an optional `ext` key - a JSON object - allowed at the top level and per entry, validated only
     as an object and otherwise ignored by the bridge (never read, never written, preserved as is).
     `roster_version` stays 1. Documented in README's roster section as "reserved for other
     implementations; the bridge ignores it".

