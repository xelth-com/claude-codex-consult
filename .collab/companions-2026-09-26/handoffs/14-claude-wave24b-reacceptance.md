# Wave 24b - re-acceptance brief (a diff review of the fix round)

Commit under review: 6b88cc8 (main, 0.5.0 candidate); the previous acceptance panel on 65f5649
gave ACCEPT (glm, dola, kimi-k2.5, muse) and HOLD (mimo: F08-1 blocker, F08-2..5 and F08-7 major,
F08-6, F08-8 minor; glm added F07-1..3, muse F13-1..2). Wave 24b claims to fix all of them; its
CHANGELOG `[0.5.0]` "Wave 24b" bullets are the implementer's report.

What changed (functions to read): `Start-EngineProcess` in codex-consult.ps1 - every engine
process, the main turn included, starts through it after a fresh `Get-EngineLaunchBlock -Fresh`
(F08-1); the continuation gates (`not attempted: files changed during the run ...` for every
engine, F08-2; the killed turn's stderr, event errors and adapter class through the one classifier,
F08-3; a failed continuation supplies `provider_failure`, F08-4; a continuation reply must pass a
first reply's substantive and schema checks before it replaces the salvage, F08-5; the schema is
re-sent on prompt-only transports, F07-1); the printed resume command with the run's options
(F08-6); the 60-minute rule for a quota without a reset time in every caller (F08-7, a direct
`-Provider` run is refused, `-SkipPreflight` warns); `Get-RangeStat` refuses a single revision
(F08-8); exact usable outcomes in `Test-UsableOutcome` (F13-2); id-less tool items paired once in
`Read-CodexSalvage` (F07-2); `roster_positions` in the providers JSON (F13-1); an identity/health
cache within one listing (F07-3); a 401 whose text is a context-window limit is class
`capability` with a hint (the Kimi Plus 256K case), older `auth` entries re-read that way.

## The ask (a diff review, budget your time)

1. F08-1..8, F07-1..3, F13-1..2: fixed / still open, with the code location in 6b88cc8.
2. New defects introduced by 24b only (the launch helper and its record handling, the gates, the
   classifier path, the cache), citing lines. Say what you verified and what you inferred.
3. ACCEPT only if no blocker or major remains. The other open findings of this task belong to
   the companions wave (not implemented yet): rule them not-checked.
