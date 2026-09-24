# Handoff 13 - Claude: diff review of wave 10 (reviewer roster, panel, known reset times)

Date: 2026-09-24. Base commit: `68353d7` (tag `v0.2.0`) + uncommitted 0.3.0 work. This brief goes to the
PANEL: every available entry of the operator's roster, one consultation per reviewer, same text for all.
The Codex reviewer (`openai`) is expected to be SKIPPED by the roster because its plan reported a usage
limit with a reset time on Sep 28 - that skip, with its reason, is the first thing this wave must get right.

## Question

An adversarial read of wave 10: does the bridge now honour the operator's rule "never call or count on a
provider that has no credential or no tokens" WITHOUT anybody switching the default by hand, and does the
panel keep each reviewer's lineage and evidence separate?

## What changed (read these)

- `plugins/codex-consult/scripts/codex-consult-common.ps1`, new section "reviewer roster"
  (`Get-RosterPath`, `Read-ReviewerRoster`, `Find-RosterEntry`, `Get-PreflightVerdict`,
  `Select-RosterReviewer`, `Select-PanelMembers`) and the changed "provider availability" section
  (`Get-RetryAfter`, `retry_after` in `New-ProviderFailure`, `Get-EndpointHealth` with `RetryAfter`,
  `Until`, `QuotaKnown`; classifier order capability, auth, quota, transport).
- `plugins/codex-consult/scripts/codex-consult.ps1`: the roster rules (`-Provider` explicit -> entry defaults
  only; `-Thread` -> the thread's recorded reviewer; else the first available entry), `-Panel` / `-PanelAll`
  (members run sequentially as child bridge processes with an internal `-PanelSpec`; all see the findings
  that were open when the panel started), `-SchemaTransport`, purpose `chore`, ledger fields `roster`,
  `panel`, `extra_config_source`, `schema_transport_source`, `provider_failure.retry_after`.
- `plugins/codex-consult/scripts/codex-providers.ps1`: verdict `unavailable (usage limit until <iso>)`,
  ROSTER column, the final `roster: <path> -> would select ...` line.
- `plugins/codex-consult/scripts/codex-findings.ps1`: per-reviewer scoreboard under `-Stats`.
- `tests/harness-roster.ps1` (95 cases) - the fixtures are the claims; check that the fixtures test what
  the .DESCRIPTION headers promise.

## CURRENT invariants claimed

- A roster entry with no credential, or whose endpoint has a quota failure with a KNOWN reset time in the
  future, or an auth failure within 24 h, is never launched and never counted on; the skip and its reason
  are in the ledger (`roster.skipped`) and on the console.
- A quota failure WITHOUT a reset time: an explicit `-Provider` still runs with a warning for 60 minutes
  (a transient 429 must not block an operator's explicit choice); a roster walk skips the entry.
- A panel member is a complete consultation: own lineage, own preflight, own parent selection, own lock
  and pending record, own consultation id; a member's failure does not stop the others; exit 0 only when
  every member produced a usable reply.
- The prompt every member sees is identical except for the consultation id; later members do NOT see
  earlier members' findings of the same panel.
- A `"weighty"` entry joins a panel only on framing, decision, core-contract, acceptance, stuck.
- No network call is made by any of this; a missing default roster file changes nothing (0.3.0 behaviour
  before wave 10); a roster named by `CODEX_CONSULT_ROSTER` that does not exist or does not parse refuses.

## Questions (answer by number, under 700 words)

- **Q1.** `Get-RetryAfter`: the Codex wording is "try again at Sep 28th, 2026 8:35 PM" in the LOCAL time of
  the machine that recorded the failure; the bridge interprets it in the offset of the failure's `when`.
  Where does this go wrong (DST change between `when` and the reset, a ledger read on a machine in another
  zone, a message with no year, a 12-hour time without AM/PM)? Give the concrete input and the wrong
  result, or say the case is handled and point at the line.
- **Q2.** The roster walk evaluates each entry's preflight in order and stops at the first available one.
  Name a sequence of ledger entries (across two tasks) where the walk picks an entry the operator's rule
  says it must not, or refuses one it should take. Read `Get-EndpointHealth` and `Get-PreflightVerdict`.
- **Q3.** Panel: members are child processes of the bridge holding the task lock one after another. What
  happens when member 2 is killed by the timeout while member 3 is still to run - state of
  `.consult.pending.json`, the ledger, the exit code, the summary block? Read the panel loop in
  `codex-consult.ps1`.
- **Q4.** Verdict (ACCEPT / HOLD / REJECT) on wave 10 as a diff, with blockers, unproven scenarios and the
  first-run checklist for THIS consultation: your own ledger entry must show `roster` with the openai entry
  in `skipped` (reason `usage limit until 2026-09-28T20:35:00+02:00`), `panel` with `id`, your `position`
  and the `members` list, `provider_source roster`, `schema_transport` per your host, and the reply file
  named `handoffs/14-codex-wave10-<provider>.md` or `15-...`.

Return the JSON object described in the instructions (schema v1).
