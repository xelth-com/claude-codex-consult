# Waves 27c, 28, 27d acceptance (handoffs 34-38) - decisions for wave 28b

Panel a0d1d2a5 on 1de388e (range c6f6966..1de388e), routed, required glm-5.3 and mimo-v2.6-pro: glm ACCEPT
(F35-1 minor), qwen3.8-max ACCEPT after a timeout continuation (F37-1..5 minor, F37-6 note), mimo HOLD after a
timeout continuation (F36-1..5 major, F36-6..11 minor), k3 failed in the middle of its review (401: the thread
had grown past the 256K window of its plan). All three usable replies confirm the findings of the previous
round fixed: F29-1..2, F30-1..4, F30-6..9 and F32-1..6, F32-8..11 are verified; F32-7 is narrowed into F36-11.
The HOLD of a required reviewer stands: four of its five majors concern what leaves the machine.

## Telemetry: what leaves the machine

D1. A closed vocabulary instead of operator text (F36-1 major). The roster label and the model name are text the
    operator typed. The event carries `provider` = the vendor class derived from the ENDPOINT host through a
    table shipped with the bridge (`api.openai.com` and the ChatGPT login -> `openai`, `api.z.ai` -> `zai`, and
    so on for every provider the README documents; the engines agy and muse -> `google`, `meta`), anything else
    -> `other`; `model` = the model name only when the vendor class is known AND the name matches that
    vendor's published pattern in the same table, else `other`. `tags` carry the same two values. The label
    never leaves the machine. The allowlist test of the harness walks the VALUES too: a roster with a label
    and a model that look like a company name must produce `other` / `other`.
D2. The sender has a deadline (F36-2 major). One flush ends after 60 s in all, whatever the intake does; one
    request is bounded as a whole (connect, send, read) by 8 s; the flush lock is released in `finally` and a
    lock older than 5 minutes is taken over; what is not sent stays in the spool.
D3. The sender starts with a minimal environment (F36-3 major): an ALLOW list, not a scrub list - the system
    variables a PowerShell process needs (SystemRoot, windir, ComSpec, PATH, PATHEXT, TEMP, TMP, USERPROFILE,
    HOME, APPDATA, LOCALAPPDATA, ProgramData, ProgramFiles*, PSModulePath, the locale and proxy variables),
    `CODEX_HOME`, `CODEX_CONSULT_TELEMETRY`, `CODEX_CONSULT_TELEMETRY_URL`, and in a harness the test mode
    variables. No provider key, no host marker, no other `CODEX_CONSULT_*` variable.
D4. The intake URL (F36-9, F37-4): `CODEX_CONSULT_TELEMETRY_URL` stays an operator setting and must be https;
    plain http is accepted only for a loopback address AND with `CODEX_CONSULT_TEST_MODE=1`.
D5. The salt is created atomically (F36-9): write a temporary file, move it without overwriting; a creator
    that loses reads the winner's salt; never delete a salt that parses.
D6. A spool that cannot be written is visible (F35-1, F36-8, F37-6): the append waits up to 5 s; a failure
    puts `telemetry event not spooled (<why>)` into `warnings[]` of the ledger entry and onto the console, and
    `-Status` counts the events not spooled since the last flush.
D7. `-Complain` keeps its promise (F36-7, F37-5): the spool keeps the exact bytes that were shown; the deferred
    send posts those bytes.
D8. The sender against the intake as it is built: a batch refused with 400 `events[i]: reason` - drop event i
    (one line in `.last`), resend the rest, at most three times per flush; 413 - halve the batch; 403 - stop
    the flush, keep the spool, say why; any other 4xx - keep the spool, say why.
D9. Delete my data: `codex-telemetry.ps1 -Forget -PublicRef <ref>` sends `DELETE /T/v2/instances/<instance
    id>?public_ref=<ref>`; `-Forget -Local` removes the local spool and the salt. The README says the intake is
    live and names both.

## Test mode, host hint, member control

D10. Test mode cannot leak or stay unnoticed (F36-5 major): `CODEX_CONSULT_TEST_MODE` and every
     `CODEX_CONSULT_TEST_*` are removed from the environment of ENGINE children and of the sender (a panel
     member, which is the bridge itself, keeps them); a run that finds `CODEX_CONSULT_TEST_MODE=1` prints `test
     mode is ON: test hooks are honoured` on the console and puts it into `warnings[]` - every harness expects
     that line.
D11. The host hint by path is anchored (F36-4 major): the root of the running script is compared with the
     plugin directories of the hosts resolved from the home directory (`<home>/.claude/plugins/cache/`,
     `<home>/.codex/plugins/cache/` or `<codex home>/plugins/cache/`, `<home>/.zcode/cli/plugins/cache/`,
     `<home>/.qwen/extensions/`); a path that merely contains such a name gives no hint.
D12. An open tool call and the stall cut (F36-11, F32-7): the suspension ends after 2 x stall seconds without
     any growth of the stream (no floor of 1800 s); the cut names the open tool call.
D13. The health update survives a crash (F36-6, F37-1): inside the lock the run appends the record to a
     journal beside the health file (a local append, no lock wait); the retry after the lock, or the next run
     of any repository, applies the journal and empties it; the warning says `a retry follows the commit`,
     and the detached status record and the console summary carry the outcome of the retry.
D14. The confirmed kill (F37-2, F37-3): a descendant counts as alive only with its start time unchanged; on a
     host that is not Windows and has no `pgrep` the children are read from `ps -o pid=,ppid=`, then `/proc`;
     only when nothing works is the kill unconfirmed.
D15. The window of the reviewer reaches the engine (seen live: the k3 member failed with 401 in the middle of
     its review): a roster entry with `context_tokens` gives codex `-c model_context_window=<n>` and `-c
     model_auto_compact_token_limit=<0.8 n>`; the ledger records both; for agy and muse the README says the
     key guards only the start.
D16. Days are local (reported by the other implementation after a run across midnight): every place that
     computes a day (the rollout search, the spool file name, the health file) uses the LOCAL date, as the
     engine does; one harness row crosses midnight.

## Documentation and harnesses

D17. Host instructions (F36-10): every command block of a host section uses ONE name for the plugin directory
     and defines it in the same block; the hook block works when copied as written on every host.
D18. The waiting section (F36-10): the text says which price is a full wake and which a cache read, and a
     compaction after the cache expired costs a cold resume PLUS the summary.
D19. Harnesses report and go on: `harness-pending` section (e) and `harness-fixes` F04-11 print FAIL with what
     was missing instead of stopping with an exception. `harness-pending` (e) injects the registration failure
     through the hook `CODEX_CONSULT_TEST_REGISTER_FAIL` (gated by test mode), not by patching a function, so
     the rows measure any implementation given with `-ScriptsDir`.

Candidates recorded in the ROADMAP, not in this wave: R21, R22 (reviewer children without the plugin of the
coordinator and without multi-agent tools), R23.
Re-acceptance: by mimo (required) with glm; the brief lists D1-D19 and the commit.
