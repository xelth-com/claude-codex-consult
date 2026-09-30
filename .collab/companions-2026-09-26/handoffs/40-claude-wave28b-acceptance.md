# Wave 28b - re-acceptance brief

Commit under review: e5c6992 (main, 0.5.0 candidate; range 1de388e..e5c6992). The previous review was of
1de388e (handoffs 34-38 of this task: glm and qwen ACCEPT; mimo HOLD on F36-1..5 major, F36-6..11 minor; glm
F35-1 minor; qwen F37-1..5 minor, F37-6 note). Binding decisions: `handoffs/39-claude-wave28b-decisions.md`
(D1-D19). The CHANGELOG `[0.5.0]` entry "Wave 28b" is the report of the implementer: what, where, deviations,
counts.

## What wave 28b claims

1. D1 (F36-1): the event carries a vendor class derived from the endpoint host and a model name only when it
   matches that vendor's published pattern - one table in the common script; anything else is `other`; the
   roster label never leaves the machine; the harness walks the VALUES of an event.
2. D2 (F36-2): one flush ends after 60 s in all, one request is bounded as a whole, the flush lock is released
   in `finally`, a lock older than 5 minutes or whose owner is gone is taken over.
3. D3 (F36-3): the sender starts with an environment built from an allow list.
4. D4, D5 (F36-9, F37-4): the intake URL must be https, plain http only for a loopback address in test mode;
   the salt is created atomically.
5. D6, D7 (F35-1, F36-7, F36-8, F37-5, F37-6): an event that cannot be spooled is a warning in the ledger and
   a count in `-Status`; the spool keeps the exact bytes `-Complain` showed.
6. D8, D9: the sender against the intake as built (a refused event is dropped and the rest resent; 413 halves
   the batch; 403 stops the flush); `-Forget` (delete my data at the intake, or locally).
7. D10 (F36-5): test mode and the test hooks are removed from engine children and from the sender outside a
   harness; a run in test mode says `test mode is ON: test hooks are honoured`.
8. D11 (F36-4): the host hint by path compares the script root with the plugin directories of the hosts
   resolved from the home directory.
9. D12-D14 (F36-11, F36-6, F37-1..3): the suspension of the stall timer ends after 2 x stall seconds without
   growth; the health update is journaled and applied by the retry or the next run; a descendant counts as
   alive only with its start time unchanged, children are read from `ps` or `/proc` where `pgrep` is absent.
10. D15, D16: `context_tokens` reaches the engine (`model_context_window`, `model_auto_compact_token_limit`);
    days are local.
11. D17-D19 (F36-10): one name for the plugin directory per command block; the waiting section says which
    price is which; two harnesses report and go on, and the registration failure is a gated test hook.
12. Deviations the implementer names: in test mode the sender keeps the test mode variable and its own
    telemetry test hooks; the test-mode line prints after the commit and a refused run does not print it; the
    routing nonce stays the UTC date; a flush lock whose owner is gone is taken over at once.

## The ask

1. F35-1, F36-1..11, F37-1..6: fixed / still open / accepted limitation, with the code location in the commit.
2. New defects in this wave. Look at: the vendor table (a host that is a prefix or a suffix of a known host; a
   private deployment behind a known host name; whether `title`, `tags` or the failure class can still carry
   free text); the allow list of the sender (what a PowerShell process on each operating system needs that is
   missing; what is on it that should not be); the deadline (a request that streams slowly inside the 8 s; the
   lock takeover while the old owner still writes); dropping a refused event (the index of the intake against
   the order of the batch after a resend); `-Forget` (what it sends, what it deletes locally, a wrong
   `public_ref`); the journal of the health update (two repositories applying it at once; a torn last line);
   the test-mode line (the dry run; a refused run in test mode); the engine limits of `context_tokens` (what
   happens when the engine compacts in the middle of a review - is the reply still bound to the brief);
   local days (the hour of a daylight-saving change).
   Cite lines. Say what you verified in code and what you inferred. Budget your time: a review of one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
