# nonblocking-2026-09-26 - ROADMAP R12 (non-blocking consultation, -Detach), wave 24

The maintainer decided on 2026-09-26 to do every remaining roadmap item without waiting for the
openai reviewer. Wave 24 builds R12 on the parallel panel of wave 21.

## Round 1 - design review (2026-09-26)

- Design: handoffs/01-claude-r12-design.md (base 46440f3).
- Panel (parallel, codex engine only so that no agy/muse member fails on collab writes):
  ZAI :: glm-5.3, byteplus :: deepseek-v4.1-flash, byteplus :: dola-seed-2.0-pro; purpose framing.
- Result (panel 5b080c0b, 13 min): glm-5.3 ADVISE with F02-1..11 (6 major, 5 minor) - the
  gitignore claim was false, the foreground checks are not a superset of the real run's, no
  terminal status on error exits, -Wait's budget wrong for serialized groups, racy first write,
  stale liveness in -List and the hook, undefined aggregate exit and id8 collisions, cwd, encoding,
  member states. deepseek-v4.1-flash and dola-seed-2.0-pro: 429 on the BytePlus plan (request
  limit after the day's heavy panels), class quota.
- Decisions D1-D12: handoffs/05-claude-r12-decisions.md. Next: wave 24 implementation after the
  muse fix round (wave 23b) and the v0.4.0 tag.

