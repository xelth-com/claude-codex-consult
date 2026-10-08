Write in English.

# Handoff 01 - claude: the public "Reviewer usefulness" table - top 10, paging, judge coefficients, unknown models

Date: 2026-10-08. Purpose: framing. The maintainer's site renders a public table of reviewer usefulness from the
bridge's anonymous telemetry (the intake's `GET /T/v2/public/usefulness?app_id=codex-consult&days=90`; one row per
(reviewer vendor class, model) with consultations, usable rate, failures by class, findings per consultation,
blockers, mean wall minutes, and the coordinator's ratings useful / partial / no). The operator asked for four
changes; the bridge side of this repository and the site's aggregation are both ours to change (the site is the
`xelth.com` repository; the bridge's rating event is built by `New-TelemetryRatingEvent` /
`ConvertTo-TelemetryRatingDetails` in `plugins/codex-consult/scripts/codex-consult-common.ps1` ~11840; the vendor /
model classification by `Get-TelemetryVendor` ~10880: a closed list of published model ids per vendor, anything else
is sent as `other`; the provider label and every path/name never leave the machine).

## The operator's asks (2026-10-07)

1. **Top 10.** Show only the ten best rows by one ranking column or a combined score, with "next 10" paging for the
   lower places ("the tool aims at the top edge, but someone may use cheap models to reach one top model's level").
2. **What clients send.** Include rows for what OTHER installations report - they may wire networks unknown to us.
   Today an unknown model id is sent as `other` (the closed list protects private labels), so client models never
   appear by name.
3. **Who judged.** Show, or account for, the coordinator model that filed the ratings, "so Fable's marks are not
   mixed with a cheap model's: if someone's coordinator is DeepSeek and it rates Gemini 100% useful, that must not
   lift Gemini, which is not a leader in our own table." The operator's preference: simple per-judge COEFFICIENTS
   rather than a filter, the weight of a judge model taken from an external ranking (LMArena, OpenRouter) or from
   the bridge's own usefulness list; how to compute them is open.
4. The judge is not in the rating event today (details: engine, provider = vendor class, model, purpose, mark,
   age_days) - the ledger has `coordinator {host, model}`.

## Constraints

- Privacy as today: no provider label, no path, no brief text, no key name; an event is one line of counts and
  closed-list classes. Any new field must be a class from a closed list or a free string that cannot identify an
  installation or a private deployment.
- The intake is live and public reads are unauthenticated; the aggregation runs over at most 5000 events of 365
  days and is cached; the table must stay a server-rendered HTML with the JSON link, no client-side framework.
- Old events have no judge field; the table must keep working on them (the maintainer's own 100+ ratings of
  September are by Claude Fable 5.1 / Opus 5.5 coordinators, known out of band).
- The bridge's telemetry contract is versioned (`v2`); a new field is additive.

## Questions

- **Q1. Ranking.** One combined score for "usefulness" from the columns that exist (useful / partial / no counts,
  usable rate, findings per consultation, blockers, n): propose the formula and its small-n correction (a reviewer
  with 2 ratings must not outrank one with 60), and what the "next 10" paging keys on (rank only, or rank within a
  vendor?).
- **Q2. Judge coefficients.** Where should a judge model's weight come from - LMArena / OpenRouter ranks (external,
  changing, needs a fetched table and a mapping of model ids), the bridge's own usefulness table (circular: a model
  judged useful as a REVIEWER weighs more as a JUDGE?), or a hand-kept table of tiers published with the site (e.g.
  frontier 1.0, strong 0.7, mid 0.4, small 0.2 by family)? How does a weighted "useful" rate read in the table, and how
  is a rating with no judge (old events) weighted?
- **Q3. The judge field.** Shape of the additive rating-event field: `judge: {provider: <vendor class>, model:
  <closed-list id or other>, host: <claude-code|codex|zcode|...>}` from the ledger's coordinator (never the label)?
  Is the judge's HOST (which agent product) useful to show, or noise?
- **Q4. Unknown models.** To show what clients wire, which of these is acceptable: (a) keep `other` but add the
  vendor class and the model FAMILY (`glm-*`, `qwen-*`) from a pattern list; (b) send the raw model id when it matches
  a conservative published-id pattern (`^[a-z0-9][a-z0-9.-]{2,40}$`, no spaces, no uppercase, no digits-only
  secrets) and show it only once at least N distinct installations reported it (k-anonymity); (c) a maintained allow
  list that grows by pull request; (d) nothing - `other` stays. Name the privacy failure of each.
- **Q5. Order of work.** The bridge half (the judge field) ships in 0.6.1; the site half can be built now on the
  existing events. What must be decided before either half, and what can change later without a contract break?

Answer by number. Keep it under 700 words.
