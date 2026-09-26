# Wave 24 - acceptance brief: a timeout never loses the review; one truth about availability

Commit under review: 65f5649 (main, 0.5.0 candidate). Sources: `ROADMAP.md` "Tech debt observed
in use" (T1, T2, T3), this task's design addendum (items 9-11) and decisions D14-D17 in
`handoffs/05-claude-companions-decisions.md`, and the muse task's F15-1. The CHANGELOG `[0.5.0]`
wave 24 entry is the implementer's report. This panel runs on the new code: the acceptance
default timeout is now 3600 s and a member killed on it gets one continuation turn.

## What wave 24 claims

1. Continuation after a timeout kill: one turn on the same thread/session (codex resume, agy
   conversation, muse session) with a finish-now prompt and `-ContinueSec` (default min(timeout,
   900)); a usable reply is ingested like a first-turn reply (`bridge_outcome` "usable reply
   (after a timeout continuation)", ledger `timeout_continue {thread, wall_seconds, outcome,
   events, usage}`); no continuation after survivors, a changed tree, or a quota/auth/billing
   failure; panel members continue in their own process (the guard grows by `-ContinueSec`).
2. Partial salvage: `<NN>-<engine>-<slug>.partial.md` from the captured stream (agent messages,
   reasoning, tool calls, the resume command as a footer), ledger `partial_reply`, the summary
   names it; `-Thread` accepts a killed agy conversation / muse session for a manual resume.
3. Per-purpose default timeouts (`timeout_source: purpose|explicit`, ledger `timeout_sec`);
   `-Range <git range>` for diff-review/acceptance: `git diff --shortstat` numbers in the prompt
   header and the ledger, a warning above 1500 lines with a timeout below 2400 s.
4. F15-1: the muse billing guard re-reads `auth.json` right before launch (`-Fresh`).
5. Availability: `Select-PanelMembers -NoNetwork` with per-entry verdicts; the endpoint group
   map over ALL roster entries; the providers listing rows, `-Short`, `-Short -Json` and the hook
   use the walk's verdict; a usage limit without a reset time is out for exactly 60 minutes on
   every surface; LAST FAILURE shows any limit that still blocks; the listing prints where its
   health comes from (`endpoint health:` naming the ledger directory) - the T2 disagreement was
   a listing run in another repository.
6. Tests: `harness-visibility` (76): UNIT, AVAIL, AGREE, QUOTA60, HOOK, DEFAULTS, RANGE, CONT
   (codex/agy/muse), PANEL, GUARD; field-order assertions updated in four harnesses.

## The ask

1. Rule the open findings listed in your prompt (F02-9, F02-10, F02-11, F03-4, F03-5, F04-9,
   F04-10 are wave 24's; the other open findings of this task belong to the companions wave, not
   yet implemented - rule them `not-checked` or `still-open`, do not spend time on them).
2. New defects in what wave 24 built: the continuation (when it must NOT run; the thread it
   resumes; the ledger; the panel member path), the salvage, the timeout defaults and `-Range`,
   the availability verdict and its surfaces, the 60-minute rule, F15-1. Cite lines of 65f5649.
   Say what you verified in code and what you inferred. Budget your time: this is a diff review
   of one wave, not a re-read of the bridge.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
