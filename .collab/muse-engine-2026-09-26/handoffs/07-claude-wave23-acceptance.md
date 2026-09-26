# Wave 23 - the muse engine: acceptance brief

Commit under review: f2c219a (main; 46440f3 adds only CHANGELOG text). Design:
handoffs/01-claude-muse-engine-design.md. Binding decisions: handoffs/05-claude-muse-decisions.md
(D1-D16). What was built, the deviations and the declared residuals are in CHANGELOG.md, section
[0.4.0], the "Wave 23" entries (the implementer stopped on a usage limit before writing a
separate report; the CHANGELOG entry is that report). A first live run through the real
subscription succeeded (state.md, round 2).

## The ask

1. For every open finding listed in your prompt (F02-*, F03-*): fixed / still open / accepted
   limitation per the decisions - with the code location that shows it.
2. New defects in the muse engine and in what wave 23 changed for every engine: the turn-options
   argv contract, the denial-retry and format-repair turns routed through the adapter, the
   billing launch invariant (incl. -SkipPreflight, the roster walk, panel members, the
   providers listing), the sign-in preflight, the MSP invariants and failure classes, the
   launcher resolution and -EngineExe binding, D12's forced permission class for agy and muse,
   the ledger's engine_run, and whether tests/harness-muse.ps1 would catch regressions.
   Cite lines of f2c219a. Say what you verified in code and what you inferred.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
