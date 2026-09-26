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

## Round 2 - acceptance of wave 24 on this task (2026-09-26 17:05-17:30)

- Brief: handoffs/06-claude-wave24-acceptance.md; commit 65f5649; the panel ran through the new
  code (acceptance default 3600 s, continuation armed - no member needed it). 7 of 10 entries, 24
  min wall.

  | member | outcome | wall |
  |---|---|---|
  | ZAI :: glm-5.3 | ACCEPT, F07-1..3 (2 minor, 1 note) | 1205 s |
  | mimo :: mimo-v2.6-pro | HOLD, F08-1 blocker, F08-2..5 + F08-7 major, F08-6, F08-8 minor | 777 s |
  | byteplus :: deepseek-v4.1-flash | 429 on the plan (three BytePlus members at once) | 1413 s |
  | byteplus :: dola-seed-2.0-pro | ACCEPT, no findings | 767 s |
  | byteplus :: kimi-k2.5 | ACCEPT, no findings | 439 s |
  | kimi :: k3 | 401 "Your current plan supports only k3 up to 256K context" - the acceptance context overflowed the Plus window; recorded as class auth (a misclassification, fixed in 24b) | 320 s |
  | meta :: muse-spark-1.3-contributor [muse] | ACCEPT, F13-1 minor, F13-2 note | 692 s |

- The seven wave-24 findings (F02-9, F02-10, F02-11, F03-4, F03-5, F04-9, F04-10) ruled fixed by
  every usable member -> verified. Fix round 24b: F08-1..8, F07-1..3, F13-1..2 plus the 401
  context-limit classification. Roster: BytePlus concurrency lowered to 2 (Lite rate limit).
- Lesson: K3 on the Plus tier (256K) cannot carry a long acceptance (the Codex loop re-sends the
  whole context); keep k3 on checkpoints and design reviews, or upgrade the plan for 1M.

