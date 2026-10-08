# Wave 29c - the paired A/B of a plan's two routes (E8)

`ab-driver.ps1` runs, inside a dedicated worktree of this repository, the same briefs through a plan's codex route
and its Claude Code endpoint route (`auth: endpoint`), the order of the two arms random per pair, one arm after the
other, resumable (a usable arm is never repeated); `ab-analyze.py <sessions.json> zai|mimo [ratings.json]` computes the
per-pair credits (the plans' published formulas), wall time, the structured-first-turn rate and the E8 gates. The blind
marks come from a judge that sees only the brief and the two replies' `reply_markdown` + findings (A/B assignment
random, the key withheld) and are recorded with `codex-findings.ps1 -Rate`. The 2026-10-08 run: handoff 40 of
`.collab/claude-engine-2026-09-30/`, ledgers `.collab/ab-zai-2026-10-08/` and `.collab/ab-mimo-2026-10-08/`.
