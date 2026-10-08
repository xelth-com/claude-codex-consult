# Handoff 40 - wave 29c: the paired A/B of the endpoint route (E8) - z.ai complete, MiMo half done

Date: 2026-10-08 (night). Coordinator: Claude Code (Fable 5.1). Code under test: v0.6.0 (890fc9e). The question of
E8 (handoff 12): does the `claude` engine's endpoint route (Claude Code headless against a plan's Anthropic-compatible
endpoint) earn its place in the roster beside the codex route of the same plan?

## Method (as E8 prescribes)

- Two dedicated worktrees at v0.6.0 (`cc-ab-zai` on branch `ab/zai`, `cc-ab-mimo` on `ab/mimo`; one per plan, because the
  claude engine's strict tree check fails a turn when the collab directory changes - the two chains must not share one).
- Twelve briefs, the same for both plans: verbatim copies of earlier checkpoint/acceptance/decision briefs of this
  repository (companions 52, 27, 51, 06, 46; bridge-0.3 07, 19, 16, 03; nonblocking 06; host 06; parallel-panel 06), each
  with a header saying it is re-asked against the current tree. Purpose `checkpoint`, `-Mode new`, timeout 1800 s, the
  same one-line prompt. Per pair the ORDER of the two routes is random (seeded); the arms run one after another (the
  plan group serialises them anyway); the driver is resumable (a usable arm is never repeated).
- Roster: `~/.codex/codex-consult-roster-0.6.json` (`ZAI` / `ZAI-claude`, `mimo` / `mimo-claude`, plan keys) through
  the checkout's 0.6.0 scripts.
- Credits by the plans' published formulas: z.ai GLM-5.3 6.9 / 1.7 / 24 per 10,000 tokens (input miss / cached /
  output; cache creation counted as a miss); MiMo 300 / 2.5 / 600 per token (miss / hit / output).
- Blind marks: an opus judge received, per pair, the brief and the two replies' `reply_markdown` + findings (no reviewer
  header, no file names, A/B assignment random, the key withheld), rated each reply `useful yes|partly|no` and 1-5 on
  one bar, and named a preference per pair; the key was applied afterwards and the marks recorded as `-Rate` in the A/B
  ledgers (24 marks for z.ai).

## z.ai (GLM-5.3) - 12 of 12 pairs, 01:21-03:33

| pair | codex: wall s / credits | claude: wall s / credits | credits ratio | wall ratio |
|---|---|---|---|---|
| 01 | 475 / 592 | 191 / 142 | 0.24 | 0.40 |
| 02 | 611 / 862 | 162 / 112 | 0.13 | 0.26 |
| 03 | 321 / 310 | 197 / 142 | 0.46 | 0.61 |
| 04 | 189 / 192 | 97 / 74 | 0.39 | 0.51 |
| 05 | 295 / 322 | 181 / 112 | 0.35 | 0.61 |
| 06 | 492 / 454 | 145 / 107 | 0.24 | 0.30 |
| 07 | 227 / 212 | 151 / 78 | 0.37 | 0.66 |
| 08 | 347 / 321 | 139 / 90 | 0.28 | 0.40 |
| 09 | 276 / 277 | 97 / 66 | 0.24 | 0.35 |
| 10 | 532 / 489 | 346 / 217 | 0.44 | 0.65 |
| 11 | 426 / 274 | 354 / 68 | 0.25 | 0.83 |
| 12 | 862 / 517 | 235 / 110 | 0.21 | 0.27 |

- Usable: codex 12/12, claude 12/12. Structured on the first turn: 12/12 both.
- Median credits ratio (claude / codex) **0.27** (gate <= 0.8). Median wall ratio **0.46** (gate <= 1.25).
- Blind marks (opus judge, routes hidden): codex mean 4.08 (median 4), claude mean **4.33** (median 4.5); useful: yes 10 /
  partly 2 on each route; preference: claude 7 pairs, codex 4, tie 1. Gate "not worse": **PASS**.
- The judge found no fabricated file, function or line range in the 24 replies; four factual errors (two per route);
  duplicate finding ids were an ordering effect (both routes write one task ledger, the second arm saw the first arm's
  findings as filed) and were not weighted.
- **Decision E8 for z.ai: the endpoint route STAYS** - all four gates pass, with a wide margin on credits and wall time.

## MiMo (mimo-v2.6-pro) - 6 of 12 pairs complete, 01:21-03:40 (chain interrupted)

| pair | codex: wall s / credits (M) | claude: wall s / credits (M) | credits ratio | wall ratio |
|---|---|---|---|---|
| 01 | 520 / 200 | 1133 / 55 | 0.27 | 2.18 |
| 02 | 765 / 279 | 439 / 27 | 0.10 | 0.57 |
| 03 | 643 / 346 | 476 / 36 | 0.10 | 0.74 |
| 04 | 399 / 268 | 697 / 37 | 0.14 | 1.75 |
| 05 | 574 / 203 | 585 / 35 | 0.17 | 1.02 |
| 06 | 559 / 274 | 603 / 48 | 0.18 | 1.08 |

- Usable 6/6 both; structured 6/6 both. Median credits ratio **0.16** (gate <= 0.8); median wall ratio **1.05** (gate <=
  1.25; two pairs above 1.25 - the MiMo endpoint is slower through Claude Code than through codex, unlike z.ai).
- The chain was killed at 03:40 by Claude Code's memory guard (a peer session's cargo build, `link.exe` at 7.6 GB on a
  16 GB machine) during pair 7's codex arm (the claude arm of pair 7 is usable, n=13); the orphaned pending record of that
  arm (n=14, bridge pid dead) is left for the bridge's own recovery on the next run. The driver resumes from pair 7
  when restarted (the operator's word is needed: the guard forbids a restart on the coordinator's initiative).
- Blind marks for MiMo: pending the full 12 pairs (the same judge, the same bar).
- **Decision for MiMo: PENDING** the remaining 6 pairs and the blind marks; the preliminary numbers pass three gates.

## What the A/B also showed

- The claude engine's endpoint route ran 36 consultations (24 z.ai, 13 MiMo - 7 claude arms) without a single failure,
  quota hold or format repair; every reply was structured on the first turn (the native `--json-schema` transport),
  while the codex route's structured rate was also 100% on these briefs.
- Credits: the codex route re-sends the whole context on every tool turn (2-3 M input tokens per MiMo consultation,
  0.5-0.9 M on z.ai); Claude Code's prompt caching keeps the endpoint route at 0.1-0.3x of that.
- Wall time: z.ai through Claude Code is 2-4x faster; MiMo through Claude Code is about the same as codex (its
  Anthropic endpoint answers slower than its Responses endpoint).

## Files

- `.collab/ab-zai-2026-10-08/` (branch `ab/zai`, merged into main): the 12 briefs, 24 replies, the ledger with 24 ratings.
- `.collab/ab-mimo-2026-10-08/` (branch `ab/mimo`, merged when complete): the 12 briefs, 13 replies so far.
- The driver and the analyser: the coordinator's scratchpad `ab/ab-driver.ps1`, `ab/ab-analyze.py` (to be committed under
  `tests/ab/` with wave 29c's close).
