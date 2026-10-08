# Handoff 02 - Codex: astra-usefulness-framing

Date: 2026-10-08 10:37 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 1 of 12 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: 66352bbd-3b83-4586-aee5-2feacdc22f69.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-7e702b7a0fd5448cafbeecaa89ca6ca6.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a11aa9-58b4-7523-af1b-f515a6f605f5` (source: events).
Brief: `.collab/telemetry-usefulness-2026-10-08/handoffs/01-claude-usefulness-table-framing.md` (sha256 bf20ebc0506e). Reviewed: bc8219f, base bc8219fd723e04403ce245614dda370699404ad9, tree sha256 7dfac4050e6a, 0 changed files.
Bridge outcome: usable reply. Wall time: 194.4 s. Tokens: in 138990 (cached 101248), out 4616, reasoning 490.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Define what the ranking measures, preserve closed-list privacy, and resolve rating provenance and counting semantics before adding judge weights. Findings: 0 blocker, 5 major, 1 minor, 0 note (F02-1..F02-6, tracked in `findings.json`). Structured reply: `handoffs/02-codex-astra-usefulness-framing.reply.json`.
Raw event stream: `handoffs/02-codex-astra-usefulness-framing.events.jsonl`.
Verbatim reply follows.

---

**Q1. Ranking.** First choose the objective: observed satisfaction, correctness, operational reliability, or value for money. These columns support observed satisfaction; they cannot establish that several cheap reviewers equal one expensive reviewer. Missing options include separate satisfaction/reliability rankings, purpose-specific views, and a provisional section. I would need rating coverage, installation concentration, task mix, and independently adjudicated outcomes to choose confidently.

Start with one satisfaction score: let `(pU,pP,pN) ~ Dirichlet(U+1,P+1,N+1)` and rank by `100 × fifth_percentile(pU + 0.5pP)`. This supplies shrinkage and an uncertainty penalty. Require at least 10 distinct rated consultations for ranked eligibility; otherwise show “provisional.” A statistical correction alone cannot guarantee that two ratings never beat sixty. Existing rating events cannot establish that distinct count reliably (finding #4); until resolved, label an event-based preview explicitly.

Keep usable rate, failures, findings, blockers, latency, and rating coverage alongside the score. Do not reward finding volume or multiply unmatched consultation and rating denominators. Page globally, ten rows at a time, ordered by score descending, sample count descending, then vendor/model ascending. Bind links to the cached snapshot and scoring version; vendor views are optional. Disclose window truncation (finding #5).

**Q2. Judge coefficients.** The goal must allow Gemini—or any model—to rise when credible evidence supports it. Preserving the maintainer’s existing ordering would prejudge the result. Missing options are equal weights, calibration against independently adjudicated reviews, and a separate maintainer cohort.

Use equal weights initially. External general rankings do not establish review-judging accuracy; reviewer-derived weights are circular; hand-kept tiers encode an editorial preference. If coefficients are mandatory, publish a versioned table as an experimental view alongside unweighted results, pending calibration on shared cases.

Display `Σw·(yes + 0.5·partial)/Σw` as “judge-weighted rating utility,” with raw counts, unknown-judge share, and weight version. Legacy/unknown judges get neutral weight 1, not zero or an assumed premium identity. For weighted uncertainty, account for unequal weights and clustering; `n_eff=(Σw)²/Σw²` addresses only unequal weights.

**Q3. Judge field.** The consultation’s coordinator is not necessarily the later rater (finding #3). Capture the rating actor when rating occurs and persist it locally for backfill. Otherwise name the field `consult_coordinator`, not `judge`.

Use an optional closed object: `judge:{provider,model,source}`, with `source` from `rating_actor|consult_coordinator|unknown`. Distinguish absent identity (`unknown`) from an unrecognized supplied identity (`other`). Never copy the ledger’s provider label. Current vendor classification requires endpoint metadata that the coordinator record does not contain; use a dedicated conservative classifier. Host is optional diagnostic context, not authority; omit it from the main table. Reject neither old events nor ratings with missing identity.

**Q4. Unknown models.** Prefer **(c)**, optionally supplemented by **(a)**. Another option is a versioned, reviewed public catalog distributed to clients, with local exact matching before transmission; recognize public model IDs independently of unknown endpoint vendors.

(a) Emit only fixed family tokens: sending matched suffixes leaks private labels; rare combinations still expose usage. (b) Reject: `acme-prod-secret` passes the regex, and server suppression occurs after collection. Installation counts do not prove independent users. (c) Review additions against public identifiers; private aliases admitted through PRs defeat the boundary, and rare-model usage remains observable. (d) Adds no model-name disclosure, but retains existing metadata exposure and hides client diversity.

**Q5. Order of work.** Before either half, decide score meaning, counting unit/re-rating policy, actor provenance, unknown semantics, privacy boundary, and model-versus-endpoint identity. Before bridge release, verify intake compatibility with additive fields and sanitized backfill. The site can ship descriptive paging now. Later change thresholds, priors, coefficients, columns, and paging through documented scoring versions. Catalog growth needs compatible unknown handling; changing field meaning or exposing raw strings is not merely an additive change.

---

### Findings

- **F02-1** [major] `.collab/telemetry-usefulness-2026-10-08/handoffs/01-claude-usefulness-table-framing.md:22`, `.collab/telemetry-usefulness-2026-10-08/handoffs/01-claude-usefulness-table-framing.md:43` - The proposed ranking can encode the desired model ordering rather than measure reviewer usefulness: neither judge prestige nor finding volume establishes correctness, and aggregate satisfaction does not control for task mix or installation concentration. Trigger: Judge coefficients are selected to prevent a currently lower-ranked model from rising, or finding/blocker counts receive positive ranking bonuses without adjudication. Evidence: read-code: The stated motivation explicitly says a cheaper coordinator's positive rating must not lift Gemini because it is not a leader in the maintainer's table.; inferred: The listed aggregates contain marks and finding counts, but no independent correctness adjudication or demonstrated judge calibration. Verify: Evaluate candidate weighting schemes on the same independently adjudicated review cases, checking whether they improve correctness prediction over equal weights. Remedy: Define the metric as observational rating utility, retain diagnostic columns separately, and use equal weights until calibration supports a different scheme; publish editorial weighting only as an explicitly labeled alternative.
- **F02-2** [major] `.collab/telemetry-usefulness-2026-10-08/handoffs/01-claude-usefulness-table-framing.md:55` - The proposed raw-model regex and public-display threshold cannot preserve the existing prohibition on collecting private deployment labels. Trigger: A private model alias such as acme-prod-secret matches the allowed character pattern and is transmitted before the display threshold is evaluated. Evidence: read-code: The brief prohibits identifying private deployments but proposes sending matching raw strings and suppressing only their public display.; inferred: Character shape cannot distinguish a published model identifier from a private deployment alias; the example satisfies the pattern. Verify: Run the proposed classifier against private-looking aliases that satisfy its regex and inspect the serialized outbound event before any server suppression. Remedy: Perform exact matching against a reviewed public catalog locally, emitting only canonical catalog entries or fixed family/other tokens.
- **F02-3** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:7294`, `plugins/codex-consult/scripts/codex-findings.ps1:475`, `.collab/telemetry-usefulness-2026-10-08/handoffs/01-claude-usefulness-table-framing.md:52` - Copying the consultation ledger's coordinator into a field presented as the rating judge can attribute a rating to the wrong actor. Trigger: A consultation is started by one coordinator and later rated or re-rated by another model or a human. Evidence: read-code: Coordinator identity is resolved once at the start of a run and retained in the ledger.; read-code: The rating telemetry call receives the original consultation entry and the mark; it does not pass a separately captured rating actor. Verify: Start a consultation under coordinator A, rate it under coordinator B, and check whether the proposed judge serialization identifies B or explicitly labels A as consultation provenance. Remedy: Capture and persist rating-time identity with each mark, or expose the existing identity as consult_coordinator with explicit provenance and no claim that it identifies the rater.
- **F02-4** [major] `plugins/codex-consult/scripts/codex-findings.ps1:37`, `plugins/codex-consult/scripts/codex-findings.ps1:475`, `plugins/codex-consult/scripts/codex-consult-common.ps1:11818` - Rating telemetry cannot reliably reproduce the local latest-rating-per-consultation semantics, so event counts cannot safely be treated as distinct rated consultations for ranking confidence. Trigger: The same consultation is rated more than once, including a correction from yes to no. Evidence: read-code: Local re-rating replaces the previous mark, but telemetry is emitted for every rating, including re-ratings.; read-code: The event deliberately omits consultation identity and contains no replacement reference that distinguishes a correction from a separate consultation. Verify: Rate one consultation yes and then no in a telemetry fixture, and compare the one retained local mark with the emitted events and the site's sample count. Remedy: Choose explicit event-based semantics or design a privacy-reviewed replacement mechanism before claiming distinct-consultation confidence; do not silently reinterpret existing events as unique ratings.
- **F02-5** [minor] `.collab/telemetry-usefulness-2026-10-08/handoffs/01-claude-usefulness-table-framing.md:35` - The 5000-event aggregation cap can make a nominal time-window ranking incomplete and sensitive to event selection order. Trigger: More than 5000 eligible events occur within the requested window. Evidence: read-code: The aggregation is described as cached and limited to at most 5000 events.; inferred: A capped subset cannot represent all events in an overflowing window without an additional aggregation or sampling policy; that policy is not specified. Verify: Feed the site aggregation a fixture with 5001 eligible events and inspect selection order, effective coverage, truncation metadata, and paging stability. Remedy: Expose effective coverage and truncation, use deterministic cached snapshots for paging, and adopt complete rollups or a documented sampling policy if the cap becomes material.
- **F02-6** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:7318`, `plugins/codex-consult/scripts/codex-consult-common.ps1:11660`, `plugins/codex-consult/scripts/codex-consult-common.ps1:11689` - The existing reviewer classifier cannot be reused blindly for coordinator identities or public models behind unknown endpoints: it depends on endpoint metadata absent from the coordinator record and suppresses model identity when vendor resolution fails. Trigger: A Codex coordinator record without provider_config is passed to Get-TelemetryVendor, or a recognized public model is served through an unrecognized endpoint. Evidence: read-code: The coordinator record stores provider, model, engine, host and provenance fields, but not provider_config.; read-code: Vendor resolution uses provider_config.base_url or provider_config.builtin for Codex; the raw provider field is not a substitute.; read-code: Model classification returns other whenever Vendor is absent, before checking model names. Verify: Exercise classification fixtures for a known model through an unknown endpoint and for a coordinator record lacking provider_config; inspect provider and model separately. Remedy: Separate public model recognition from endpoint vendor classification, define the meaning of judge.provider explicitly, and sanitize through a dedicated closed-list classifier without transmitting provider labels.

### Prior findings

_(none)_

## Verdict: ADVISE

Define what the ranking measures, preserve closed-list privacy, and resolve rating provenance and counting semantics before adding judge weights.

### Blockers

_(none)_

### Unproven scenarios

- The xelth.com aggregation implementation, intake validation, deduplication, cap selection order, and cache behavior were not inspected.
- No empirical judge-calibration data, installation distribution, rating coverage, or task-mix analysis was supplied.
- No runtime fixtures were executed; implementation observations are based on read-only source inspection.

### First-run checklist (observable)

_(none)_
