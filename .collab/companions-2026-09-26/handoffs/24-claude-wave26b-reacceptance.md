# Wave 26b - re-acceptance brief: the wave 26 HOLD findings and the day's additions

Commit under review: 35d4a32 (main, 0.5.0 candidate); the previous acceptance reviewed f29f5ca
(handoffs 18-22: glm ACCEPT, dola ACCEPT, mimo HOLD on F22-1 major, F22-2..7 minor; glm F19-1 minor).
Binding decisions D1-D16: handoffs/23-claude-wave26-acceptance-decisions.md. The CHANGELOG `[0.5.0]`
"Wave 26b" entry is the implementer's report (what, where, deviations, counts).

## What wave 26b claims

1. F22-1 (D1): `Resolve-RoleFile` / `Get-RoleFileProblem` accept only a regular file with no reparse
   point on it or on the roles directory, resolved inside `<CollabDir>/roles` (the plugin's templates
   likewise); refusal before any prompt, handoff, ledger entry or process. Harness: a junction named
   like a role file (file symlinks need privileges on this account).
2. F19-1 (D2): `size_asked` and the `panel size reduced` warning; `asked` = the requested size.
3. F22-2/F22-4 (D3): roster provider/model/engine strings refused when they contain `::`, `[`, `]`,
   `|`, `,`, `#` or edge whitespace; the seed text length-prefixes every field; `tests/reference-draw.py`
   reproduces the old goldens and gives the new ones.
4. F22-3 (D4): exact role matching by augmenting paths (deviation: not an enumeration; no 8x8 limit),
   greedy fallback recorded as `roles_note`. F22-5 (D5): `routing.reserve`; 360 draws identical to
   wave 26. F22-6 (D6): the `needJoin` predicate. F22-7 (D7): `ConvertTo-LocationPath`.
5. D9: a write-disabled engine's (muse) tree/collab change is a WARNING - ledger `tree_check {outcome,
   files}`, the reply stays usable; agy keeps the failure. D15: partial salvage on any failed run with
   content (`partialOnFailure`).
6. D10-D12 (R18): `-Kick` (each member polls its own kick file - deviation from "the parent polls";
   also on a single run; failure class `operator`), roster `timeout_sec` (`timeout_source: roster`),
   `-StallSec` / roster `stall_sec` (the main turn only; ledger `stall`).
7. D13 (R20): the machine-wide health file (`CODEX_CONSULT_HEALTH`; `none` disables - every harness
   sets it), records with `retry_after`, the newest record decides (ties: the later `until`), the
   cross-repository `running[]` count (advisory: two panels checking at the same instant can both
   start a member - declared residual).
8. D16: roster `context_tokens` - fork/resume falls back to a new thread (`mode_fallback`), the
   too-large skip (estimate (ask + brief)/4; an explicit `-Provider` run is refused instead), the
   prompt line naming the window.
9. D14: the consult-codex Language and Live-members rules, `Write in English.` first in all six
   templates; README tables (options, ledger fields, roster keys, exit codes) updated.
10. Tests: `harness-fixes26b` 39 (new), `harness-muse` TREE +2; full suites green on both hosts except
    the known environmental F04-10.

## The ask

1. F22-1..7 and F19-1: fixed / still open / accepted limitation, with the code location in the commit
   (verify F22-1 in code: the reparse-point check on the file AND every directory component, and the
   containment after resolution).
2. New defects in the day's additions - the kick file protocol (races with the member's own exit and
   with the timeout kill; the salvage on a kick), the stall detector (a member that legitimately
   produces no events while a long tool call runs), the health file's lock and merge (two repositories
   writing at once; a stale `running[]` row whose pid was reused), `context_tokens` estimates and the
   fallback's prompt, `partialOnFailure` on a first-request refusal (must write nothing), the
   write-disabled warning path (must never apply to agy). Cite lines. Say what you verified in code and
   what you inferred. Budget your time: a review of one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
