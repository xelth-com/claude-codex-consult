# Wave 26 acceptance (handoffs 18-22) - decisions

Panel 6da33911 on f29f5ca, routed by the ratings (the first live routed panel): glm-5.3 ACCEPT (F19-1 minor,
F19-2 note; 39 prior findings checked fixed, 5 not checked), dola-seed-2.0-pro ACCEPT (no finding; 41 checked
fixed, 3 not checked), mimo-v2.6-pro HOLD (F22-1 major, F22-2..7 minor; 44 checked fixed; the reply came
through the timeout continuation - killed at 3600 s, one turn of 359 s), deepseek-v4.1-flash failed (429 on
BytePlus: two members of the bridge on that endpoint plus another repository's panels at the same time).
Verdict: HOLD stands until F22-1 is fixed; the fixes go into wave 26b with the items seen in use the same day.

D1. F22-1 (role file follows a symlink or junction out of the roles directory; the text goes to external
    reviewers): `Resolve-RoleFile` accepts only a regular file (no ReparsePoint attribute on the file or any
    directory between `<CollabDir>/roles` and it) whose resolved full path is inside `<CollabDir>/roles`; the
    plugin's `templates/role-<name>.md` likewise inside the plugin's templates directory; anything else refuses
    the run before any prompt, handoff, ledger entry or process exists ("role file refused: <why>"). Harness
    cases: a symlinked role file (created with a junction when symlinks need privileges), a role directory that
    is a junction, a file outside the tree.
D2. F19-1 (the clamped panel size is recorded silently): the ledger keeps `size_asked` beside `size`; when the
    size was reduced (fewer eligible than asked) the run warns `panel size reduced: asked k, eligible m`
    (console, handoff header, ledger `warnings[]`); the summary line says `asked k` from the request, not the
    clamp.
D3. F22-2 and F22-4 (matcher and seed delimiters inside provider or model strings): the roster validator
    refuses a provider label, model or engine that contains `::`, `[`, `]`, `|`, `,` or `#` or leading/trailing
    whitespace ("roster entry #n: provider must not contain '::'"); the seed text length-prefixes every field
    (`<len>:<value>`) so the join is unambiguous; the golden sequences of the harness are regenerated and the
    reference implementation updated in the same commit (both listed in the CHANGELOG).
D4. F22-3 (greedy role assignment can violate willingness when a full assignment exists): assign by a small
    exhaustive matching over the seated members (at most 8 members, at most 8 roles): the assignment that
    honours every willingness and, among those, gives each role in order the best-ranked member; only when
    no willingness-honouring assignment exists does the greedy rank order apply, and the ledger says so
    (`roles_note`).
D5. F22-5 (required pins consume seats before the lab reserve): the reserve is defined over the seats left
    after the pins - the README and the ledger say `reserve: min(seats left after the required, labs with an
    entry >= neutral not yet seated)`; `panel.routing` records `reserve` (the number of reserve seats
    applied) so the claim is auditable. No change to the draw.
D6. F22-6 (legacy rating completion skips records with a provider but no model or purpose): `needJoin` is
    true when ANY of provider, model, purpose, engine or consult_when is missing; the harness case covers a
    record with a provider only.
D7. F22-7 (UNIQ location matching is case- and prefix-sensitive): location keys are compared after
    normalising separators, case (Windows), a leading `./`, and `\` vs `/`; the line stays exact.
D8. F19-2: wontfix by design (a routed panel reads the repository's findings stores once per run; a cache
    would go stale across sessions).

Seen in use the same day (xelth.com cap3d panels, the bridge's own acceptance) - in wave 26b as well:
D9. A write-disabled engine's tree check is a warning, not a failure (the muse member of another
    repository's panel was recorded `failed: the collab directory changed ... state.md` while it ran with
    `--disable-write --disable-shell`; the coordinator had written state.md). When the engine ran with its
    write capability disabled by the bridge's own flags (muse), a change outside the run's own handoff files
    becomes `warnings[]`: `the collab directory changed during the run (<files>) - muse ran write-disabled,
    the change is not the reviewer's` and the reply stays usable; the working tree check likewise. agy keeps
    the failure (F12: `--sandbox` does not block writes). Ledger `tree_check {outcome: warned|failed|clean,
    files[]}`.
D10. `-Kick <nn>` for one member: on a detached panel `-Kick -Id <id8> -Member <nn>`; on a foreground panel
     the operator writes nothing - the parent polls `<task>/.consult.kick-<nn>` (created by `-Kick -Task <t>
     -Member <nn>` from another shell). The member's process tree is stopped, its partial output salvaged (the
     wave 24 machinery, `.partial.md`), the member recorded `failed: stopped by the operator (-Kick)` (class
     `operator`), the panel goes on with the others. Exit code of `-Kick`: 0 done, 1 no such member or not
     running.
D11. Per-entry timeout: a roster entry's optional `timeout_sec` (integer >= 60) replaces the purpose default
     for that member (an explicit `-TimeoutSec` still wins for all); the panel's `Timeout:` line lists the
     exceptions (`3600 s per member; #7 alibaba :: qwen3.8-max 1200 s (roster)`); ledger `timeout_source`
     gains the value `roster`.
D12. Stall auto-cut (ROADMAP R18): a member whose event stream has produced no event for `-StallSec` s
     (default 900; roster entry `stall_sec` overrides; 0 = off) while its process is alive is stopped like a
     timeout: the same continuation turn and salvage, `bridge_outcome` `failed: stalled after N s without an
     event (process tree killed)`, ledger `stall {seconds, last_event}`. The readers already consume the
     streams line by line: keep a last-event timestamp per member.
D13. Machine-wide endpoint health (ROADMAP R20): `~/.codex/codex-consult-health.json` (path overridable by
     `CODEX_CONSULT_HEALTH`), written under a lock by every run that records a provider failure or a usable
     reply on an endpoint, read by every roster walk beside the repository's ledgers (the later `until` wins);
     the endpoint parallel limit counts running members of every repository through a `running[]` table in
     the same file (pid + start time liveness, stale rows pruned). Record `{endpoint, class, kind, until,
     repo, when}`. The file is optional: unreadable or absent = as today.
D14. The consult-codex skill: a standalone **Language** rule (briefs, prompts, follow-ups, handoff titles in
     English; the operator's language only in the conversation; source material translated, never pasted in
     another language) and a standalone **Live members** rule (while an agy or muse member runs, write nothing
     under the collab directory or the working tree - state.md included - and run no git command; queue notes
     until the panel closes). Every template's first line: `Write in English.`

Re-acceptance: by mimo (the reviewer who raised F22-1..7) with glm; the brief lists D1-D14 and the commit.

Addenda sent to the implementer during the wave (2026-09-28):
D15. Partial salvage on ANY failed run whose event stream has content (an agent message, reasoning text
     or a tool call): the wave 24 `.partial.md`, ledger `partial_reply` and the `partial :` line, not only
     after a timeout kill - a 429 after retries, a quota 401/403, a network error, a denial, a tree-check
     failure. The footer names why the run ended. Nothing is written for an empty stream (a refusal on the
     first request). Seen: a DeepSeek member worked 2568 s before its 429 and left only events.jsonl.
D16. Roster entry `context_tokens` (integer >= 32000): fork/resume of a thread whose last recorded context
     plus the new prompt's estimate exceeds 80% of it falls back to a new thread (ledger `mode_fallback`,
     a summary line, the previous reply file named in the prompt); a prompt estimate over 80% skips the
     member before start with `brief too large for this reviewer's context (est. N of M tokens)`; a seated
     member with the key gets one prompt line naming its window. Seen: a Kimi k3 member (256K plan) forked a
     217K-token thread with a 6 KB brief and was refused 401 on its first request - nothing to salvage; a
     one-line probe on a new thread worked (51 s; 44K tokens of scaffolding per request).
