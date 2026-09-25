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

## Round 2 - wave 21 accepted through its own parallel panel (2026-09-26 00:19-00:50)

- Wave 21 committed as 2de15e9 (full suite green under Windows PowerShell 5.1, harness-panel 48
  also under pwsh 7.6.6). Brief: handoffs/06-claude-wave21-acceptance.md. Roster: a scratch copy
  of the maintainer's roster plus `"parallel": {"byteplus": 3}`.
- Panel 46393649: 8 of 9 entries (openai skipped: usage limit until 2026-09-28 20:35), at most 7 at
  a time; wall clock 1823 s against about 6430 s summed.

  | member | outcome | wall | input tokens (cached) |
  |---|---|---|---|
  | ZAI :: glm-5.3 | ACCEPT, 1 note (F07-1), 24 prior fixed | 1218 s | 6.45M (5.97M) |
  | mimo :: mimo-v2.6-pro | timeout at 1800 s, tree killed | 1801 s | - |
  | gemini :: gemini-3.8-flash-high [agy] | transport: API error after 8 attempts | 439 s | 64k |
  | gemini :: gemini-3.1-pro-high [agy] | quota: "Resets in 68h58m18s" | 292 s | 0 |
  | byteplus :: deepseek-v4.1-flash | ACCEPT, F11-1..6 (2 minor, 4 note) | 1682 s | 9.63M (8.89M) |
  | byteplus :: dola-seed-2.0-pro | ACCEPT, no findings | 447 s | 638k |
  | byteplus :: kimi-k2.5 | prose, no verdict | 343 s | 524k |
  | kimi :: k3 | 403 "5-hour usage limit" (recorded as auth - a bug) | 212 s | - |

- After the run: ledger n 1..11 in order with `finished_at` and the panel plan on every entry, no
  `.consult.pending*.json` left, findings in id order. BytePlus Lite carried three concurrent
  members.
- Statuses: the 21 design findings ruled fixed -> verified; F02-2, F03-8, F03-11 -> wontfix
  (accepted limitations D7, D12, D4; ruled still-open-as-accepted by deepseek and dola).
- Fix round (same implementer): F07-1 + F11-6 close the parent-death window by rewriting the member
  record before the parent check; F11-1 comment; F11-2 member killed inside its commit; F11-3
  prove commit contention; F11-4 -Rate refuses on active records; F11-5 comment. Plus two
  classification bugs from this ledger: Kimi's 403 usage-limit text classified as auth (must be
  quota, retry_after <= 5 h, also re-read that way from older entries) and agy's relative
  "Resets in 68h58m18s" not parsed into retry_after.
- Quotas learned: the Kimi Plus 5-hour window was used up by one smoke checkpoint (~0.5M tokens)
  plus the design review; the agy (Google AI Pro) quota is out until about 2026-09-29 01:30.
