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

## Round 2 - wave 25 accepted through a detached panel (2026-09-27 12:29-13:02)

- Wave 25 committed 53de158 after the laptop restart (the worker resumed from its intact tree);
  harness-detach 46, full suite green. Acceptance brief handoffs/06; the panel itself ran with
  `-Detach` (id aba1b9fb: the foreground returned in 7 s, `-Status -Id` showed the members while
  they ran, `-Wait -Id` returned the summary after 32 min) - the wave's own live test.
- Panel 61db2121, 5 of 8 (openai and both agy skipped on their limits; k3 left out for its 256K
  window): glm ACCEPT (F07-1..3), mimo ACCEPT (F08-1..2), dola ACCEPT (F10-1 note), muse ACCEPT
  (F11-1..2); deepseek 429 burst on the BytePlus plan. Every member ruled F02-1..11 fixed ->
  verified. Three reviewers independently found the same gap (an unreadable status file is never
  pruned); the notes go into wave 26 as carry-overs; F10-1 stays an accepted residual.

