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

