# muse-engine-2026-09-26 - ROADMAP R10 third engine: Meta Muse Code (wave 23)

The maintainer subscribed to Muse Code (Everyday) on 2026-09-25; the subscription works only
through Meta's `muse` CLI signed in by browser. CLI 1.4.0 installed, signed in with
TBH_CREDENTIAL_BACKEND=file, headless exec verified (see handoffs/01, "Verified facts").

## Round 1 - design review (2026-09-26)

- Design: handoffs/01-claude-muse-engine-design.md (base 37b98b4).
- Panel (parallel): ZAI :: glm-5.3, byteplus :: deepseek-v4.1-flash, byteplus ::
  dola-seed-2.0-pro - three labs; purpose framing.
- Result (panel 0168bb07, the three at once, 772 s wall against 1594 s summed):
  - 02 ZAI :: glm-5.3 ADVISE, F02-1..21 (3 blocker, 10 major, 5 minor, 3 note).
  - 03 byteplus :: deepseek-v4.1-flash ADVISE, F03-1..13 (1 blocker, 7 major, 5 minor).
  - 04 byteplus :: dola-seed-2.0-pro ADVISE, F04-1..7 - four restate the design's own to-do items
    (rejected), three duplicate other findings (superseded).
  The blockers: the adapter contract cannot pass a prompt file; the denial-retry and
  format-repair turns parse with the agy functions by name; the billing guard had no integration
  point (-SkipPreflight could bypass it); the launcher is not on the running session's PATH
  (checked: it is on the User PATH, but a bridge started before the install cannot see it).
- Decisions D1-D16: handoffs/05-claude-muse-decisions.md.
- Next: wave 23 implementation by the wave-21 implementer (fakes only), then a live smoke through
  the subscription and an acceptance panel.

## Round 2 - wave 23 implemented, first live run (2026-09-26)

- Wave 23 committed as f2c219a (a first implementer overflowed its context before editing; a
  fresh one implemented D1-D16 and ran the full suite green - harness-muse 65 - then stopped on
  the account's weekly model limit before writing its report; the CHANGELOG entry is its report).
- Live smoke, n=4: `meta :: muse-spark-1.3-contributor [muse]` through the subscription - usable,
  structured on the first turn (native schema), ADVISE "bridge argv spellings match the verified
  facts", 76.7 s wall; harness `muse-cli 1.4.0-R4161.1`; the launcher found at the vendor install
  path (the running session's PATH predates the install); preflight "signed in (auth.json:
  providers.meta, mechanism oauth)"; engine_run turns 1, MSP schema 1; tree unchanged.
- Roster: `meta :: muse-spark-1.3-contributor [muse]` (the maintainer's choice of the contributor
  variant). Next: an acceptance panel on f2c219a.

## Round 3 - acceptance panel on f2c219a (2026-09-26 09:53-10:23)

- Brief: handoffs/07-claude-wave23-acceptance.md. Panel df203d79, 7 of 10 entries at once
  (openai and both agy entries skipped on known reset times), wall 1802 s.

  | member | outcome | wall |
  |---|---|---|
  | ZAI :: glm-5.3 | timeout at 1800 s | 1802 s |
  | mimo :: mimo-v2.6-pro | HOLD - F09-1 major, F09-2 major, F09-3 minor; 33 priors ruled fixed | 1582 s |
  | byteplus :: deepseek-v4.1-flash | timeout at 1800 s | 1802 s |
  | byteplus :: dola-seed-2.0-pro | ACCEPT, no findings, 27 priors fixed | 543 s |
  | byteplus :: kimi-k2.5 | ACCEPT, no findings, 34 priors fixed | 1567 s |
  | kimi :: k3 | timeout at 1800 s | 1802 s |
  | meta :: muse-spark-1.3-contributor [muse] | failed: collab changed (2 files) | 1181 s |

- The muse member failed because the coordinator wrote ratings into OTHER tasks' findings.json
  during the panel - the accepted D7/F02-2 residual, now a rule for the coordinator: no writes to
  any task while a panel with agy or muse members runs. Its subscription prompt was spent.
- Lesson: an acceptance of a wave this size needs -TimeoutSec 3600 for the deep reviewers, or a
  narrower brief; three of seven members hit 1800 s.
- Rulings: F02-14, F02-15, F02-21, F03-7 -> verified; F02-8, F02-19, F03-11 -> wontfix (accepted
  limitations D12/D7). F09-1..3 -> fix round (wave 23b), then re-acceptance and the v0.4.0 tag
  (the maintainer decided on 2026-09-26 to tag without the openai reviewer).
- Tag v0.3.0 set at 7f46fe4 and pushed (2026-09-26).

## Round 4 - wave 23b and the resumed acceptance (2026-09-26 12:30-13:00)

- Wave 23b (23843df): F09-1..3 fixed by a fresh implementer (also agy's prompt-only denial retry,
  a timeout-kill assertion in harness-panel); full suite green (0.3 227, roster 117, format 37,
  engines 97, muse 72, panel 53, pending 26, fixes 45, lock2 11, 3b 12).
- Continuation experiment (the maintainer's request that a review killed on timeout is not
  lost): Codex kept the full rollouts of the three members killed at 1800 s in round 3. A
  `-Mode resume` on glm-5.3's thread with a finish-now prompt and a 900 s budget (n=12) returned
  a structured ACCEPT in 148 s: 30 prior findings ruled (F09-1..3 fixed at 23843df, which it
  read), F15-1 minor (the credential cache can serve the pre-launch billing guard a stale
  mechanism), F15-2 note (the accepted SHA must be the one holding the fixes). Usage 14.2M
  input, 13.3M cached (94%) - the provider cache held across the kill. This is the evidence for
  wave 24's automatic continuation turn.
- Acceptance of the muse engine: glm (resumed) ACCEPT, dola ACCEPT, kimi-k2.5 ACCEPT; mimo's HOLD
  items fixed and ruled fixed by glm. v0.4.0 tagged at 23843df (F15-2's remedy). F15-1 goes to
  wave 24.

