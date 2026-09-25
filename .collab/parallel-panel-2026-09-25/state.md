# parallel-panel-2026-09-25 - ROADMAP R11 (parallel panel), 0.4.x wave 21

The maintainer decided on 2026-09-25: the PowerShell bridge and a Rust implementation stay two
separate projects; R11 is built now in PowerShell, without waiting for the openai reviewer; the
design and the wave are reviewed by the other roster reviewers (Kimi K3 and company).

## Round 1 - design review (2026-09-25)

- Design: handoffs/01-claude-r11-design.md (base 3bd8a83).
- Panel (sequential - the current bridge): kimi :: k3, byteplus :: deepseek-v4.1-flash,
  ZAI :: glm-5.3, purpose framing.
- Result (panel 80ca1e25, 36 min wall - the members took 944 s, 445 s and 639 s one after another;
  run concurrently the panel would have taken the slowest member's 16 min):
  - 02 kimi :: k3 ADVISE, F02-1..5 (1 major, 3 minor, 1 note); format repair succeeded (96 s).
  - 03 byteplus :: deepseek-v4.1-flash ADVISE, F03-1..11 (1 blocker, 4 major, 5 minor, 1 note).
  - 04 ZAI :: glm-5.3 ADVISE, F04-1..8 (2 blocker, 2 major, 2 minor, 2 note).
  All three accept member-side commit under a write lock; the recovery model as designed has holes
  (a member's own bridge is never tested for liveness, so its record reads inactive in the commit
  window after parent death), the agy ignore list misses the atomic-write temp files, and the
  write-lock give-up path contradicted itself.
- Decisions D1-D13: handoffs/05-claude-r11-decisions.md. F02-2 and F03-8 accepted as documented
  limitations; F03-9 resolved by the sort-by-n invariant (D10); everything else goes into wave 21.
- Next: wave 21 implementation by a worker (fakes only), then a live parallel panel reviews the
  wave itself.
