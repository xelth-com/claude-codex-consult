# companions-2026-09-26 - ROADMAP R14+R15+R16 (adaptive companions, telemetry routing, roles), wave 25

Opened 2026-09-26 under the maintainer's decision to do every remaining roadmap item without
waiting for the openai reviewer. Design: handoffs/01-claude-companions-design.md. Its review panel runs after the
preceding wave is accepted (one live panel at a time; never a panel while a worker runs harnesses).

## Round 1 - design review (2026-09-26)

- Design: handoffs/01-claude-companions-design.md with the availability addendum (items 9-11, Q5).
- Panel (parallel): mimo :: mimo-v2.6-pro, kimi :: k3, alibaba :: qwen3.8-max - three labs; z.ai busy
  with a resumed review, BytePlus on its request limit; purpose framing.
- Result (panel, 31 min wall): mimo ADVISE F02-1..15 (3 blocker, 11 major, 1 minor), k3 ADVISE
  F03-1..12 (3 major, 7 minor, 2 note), qwen3.8-max ADVISE F04-1..18 (2 blocker, 10 major, 4
  minor, 2 note). Blockers: the two selection rules contradict (diversity-first vs weighted
  draw); ratings joined by task-local n across tasks; a seed that cannot be reproduced (the panel
  id is generated after selection); -Require without a matcher, pinning or precedence.
- Decisions D1-D11 (companions wave) and D14-D17 (availability, folded into wave 24):
  handoffs/05-claude-companions-decisions.md. Order of waves: 24 timeouts + availability, 25 R12
  detach, 26 companions (this task), 27 R13 host, 28 R17 telemetry.

