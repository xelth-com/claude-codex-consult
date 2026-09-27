# Wave 26 - acceptance brief: companions (ROADMAP R14-R16, the roster `ext` point, the wave 25 carry-overs)

Commit under review: f29f5ca (main, 0.5.0 candidate). Design: handoffs/01-claude-companions-design.md;
binding decisions D1-D12 and D14-D17: handoffs/05-claude-companions-decisions.md (the findings F02-1..15,
F03-1..12, F04-1..18 of this task). The wave 25 acceptance's carry-overs come from
`.collab/nonblocking-2026-09-26/` (F07-1/2/3, F08-1/2, F11-1/2). The CHANGELOG `[0.5.0]` wave 26 entries
(Added, Changed, Fixed, Known limitations) and README "Companions (0.5.0, wave 26)" are the implementer's report.

## What wave 26 claims

1. Size by stakes (D6): `-Panel` seats chore/none/checkpoint 1, diff-review 2, framing/decision 3,
   core-contract/acceptance 4, stuck every eligible member; `-PanelSize <n>` overrides, `-PanelAll` seats
   all; one eligible set (available by the roster walk's verdict, past the weighty gate, matching
   `-Engine`/`-Model`) for the size, the ranking, the draw and the exploration (D1, D11); the size bounds
   the members STARTED (no backfill); the `not-picked` member state; the summary `asked k, started j,
   usable i`; the framing/decision floor warning.
2. Routing (D2-D5): `-PanelOrder routed|roster` (default routed); `Get-RoutingScore` from every task's
   `-Rate` marks keyed by `consult_id` (latest wins), 90 days by the consultation's time, the hierarchy
   (lineage, purpose, topics) >= 3 marks -> (lineage, purpose) -> all-purpose -> neutral 1.125; roster
   order while no eligible reviewer has 3 marks (`routing.fallback`); the exact draw (seed = SHA-256 of
   task|purpose|brief sha256|sorted eligible lineages|nonce; per seat SHA-256(seed||seat), top 53 bits;
   explore < 0.2); the lab reserve; seats numbered n/NN in seat order (D9); ledger `panel.routing`.
3. Labs (D1): roster `lab`, else the vendor of the model id's prefix, never the provider label.
4. `-Topic a,b`: ledger `topics[]` after `purpose`, copied onto the rating, scored by a routed panel.
5. Required reviewers (D7): `-Require` matchers (`#n`, a label, `provider :: model [engine]`), the
   roster's top-level `require` per purpose validated at load, `-Require none`; an out required reviewer
   refuses before anything starts with exit 5 (the dry run too, `Format-RequiredOutage`); required take
   the first seats; a required member without a usable reply stops the panel at the next member, exit 5;
   on a single run only with `-Provider`, as a gate.
6. Roles (D8): `-Role` (single run, or every member of a panel) and `-Roles a,b` (a panel, by score rank,
   willingness from the entry's `roles`); role files `<CollabDir>/roles/<name>.md` else the plugin's
   `templates/role-{edge-cases,security,tests,docs}.md`; slugs checked before any path; the block after
   the ask and before the brief; ledger `role` after `topics`.
7. The roster extension point (D12): `ext` objects at the top level and in entries, validated as objects
   only, never read or written; `roster_version` 1.
8. `codex-findings.ps1 -Rate` keyed by `consult_id` with `engine`, `topics`, `consult_when`;
   `codex-scoreboard.ps1` `SCORE`, `UNIQ` (D10), `-By purpose|topic`.
9. The wave 25 carry-overs: unreadable status files older than 7 days pruned (F07-1/F08-1/F11-1), the
   conditional never-started wording (F07-2), the final status write retried then exit 6 (F08-2), the
   detached readers split into `codex-consult-detached.ps1` and the hook sourcing only it (F07-3), an
   inline `-Prompt` kept in a prompt file, not in the status record's arguments (F11-2).
10. Tests: `harness-companions` 42 (roster keys, unit, score, draw with golden sequences from an
    independent implementation, route, size, routed end to end, require, role, rate/scoreboard, the
    config guard); `harness-roster` 119, `harness-panel` 54, `harness-detach` 51 (CARRY).

## Declared deviations and residuals (judge them)

- The singleton-lab warning only on routed panels; roster-order panels seat the required first, then
  roster order; required reviewers skip the weighty gate but must be available; `-Require` on a roster
  walk is refused. No backfill for a failed member. A later rating can change the seats for the same seed
  (the ledger's `panel.routing` records what ran). A panel run that dies before its end leaves
  `panel.started`/`panel.usable` null. F10-1 (killing only the background panel parent leaves members
  running) stays accepted. The draw uses the top 53 bits of each 8-byte slice so the uniform is exact in a
  double on both PowerShell runtimes.

## The ask

1. D1-D12, D14-D17: implemented as decided / deviates / open, with the code location in the commit.
2. New defects in: the eligible set and the size bound; the score (prior, window, hierarchy, topic
   pooling, `consult_id` keying and the legacy completion); the draw's determinism and portability
   (byte order, the 53-bit conversion, the seat loop), the lab reserve and exploration; seat-order
   numbering versus the write lock and the pending records of R11; the `-Require` refusals and exit 5
   paths (before start, after a required member fails, the dry run); the role assignment and role-file
   precedence (traversal); the `ext` validation; the `-Rate` record and the scoreboard's `UNIQ`
   location matching; the carry-overs (prune, retry, exit 6, the split file sourced by the hook, the
   prompt file). Cite lines. Say what you verified in code and what you inferred. Budget your time: a
   review of one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
