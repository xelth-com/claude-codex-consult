# Wave 28b re-acceptance (handoffs 40-44) - decisions for wave 28c

Panel 8937563b on e5c6992 (range 1de388e..e5c6992), routed, required glm-5.3 and mimo-v2.6-pro: glm ACCEPT
(F41-1 minor), muse-spark ACCEPT (F44-1..2 minor, F44-3..6 note), mimo HOLD after a timeout continuation
(F42-1..6 major, F42-7..9 minor), qwen3.8-max HOLD after a timeout continuation (F43-1 major, F43-2..3 minor,
F43-4..7 note). All four confirm the eighteen findings of the previous round implemented; F35-1, F36-2..11 and
F37-1..6 are verified; F36-1 (operator text in telemetry) is narrowed into F42-1 (the model pattern). Two HOLDs,
one of them from a required reviewer: wave 28c fixes every finding below.

## Telemetry

D1. The model name is a CLOSED list (F42-1 major, F43-2): the bridge ships a list of published model names per
    vendor class (the models the README documents and the ones its rosters have run); `details.model` and the
    tag carry a name only when it EQUALS a list entry after lower-casing; anything else is `other`. No pattern,
    no version wildcard. A new model reads `other` until a release adds it; the README says so.
D2. `-Forget` never strands data (F42-2 major, F43-1 major, F44-4): with `-PublicRef`, the local deletion runs
    ONLY after the intake confirmed the DELETE (2xx); any other answer leaves the salt, the spool and the
    counters untouched, prints why, exits non-zero, and can be repeated with the right reference. `-Forget
    -Local` alone deletes locally and says in one line that the intake still holds what was sent, and how to
    remove it (`-Forget -PublicRef <ref>` BEFORE `-Local`, because the instance id dies with the salt) - and
    asks for confirmation unless `-Yes`.
D3. Local deletion is atomic against producers (F42-3 major): `-Forget` takes the telemetry lock that the
    spool append and the salt creation also take; while it holds it, it writes a `forgetting` marker; a
    producer that meets the lock or the marker drops its event (counted) instead of recreating the salt or the
    spool; the marker is removed last.
D4. The flush lock (F42-7, F43-5, F44-2): a lock is taken over ONLY when its owner process is gone (pid and
    start time); an old lock with a living owner is left alone and reported (`sender busy since <t>`). Every
    sender writes a token into the lock and checks it again immediately before each spool rewrite; a sender
    that lost the lock stops without rewriting.
D5. The deadline covers the whole flush (F42-8): spool enumeration, reads and rewrites count against the 60 s;
    the sender checks the clock before every local step and stops cleanly when it has passed.
D6. The sender's environment (F41-1, F42-9): the allow list gains the proxy variables in both cases
    (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`) and the trust inputs (`SSL_CERT_FILE`,
    `SSL_CERT_DIR`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`); the README lists the whole
    allow list.
D7. The spool append does not hold the task write lock (F43-4): inside the lock the event is built and
    appended with a wait of at most 1 s; when that fails the run retries for up to 5 s after the lock is
    released, and only then warns (console, the detached status record) and counts the event as not spooled.

## Process tree and health

D8. No pid-only identity (F42-4 major): a descendant whose start time cannot be read is neither killed by pid
    nor counted as gone - the kill is `not confirmed: start time of pid <n> unreadable` and the bridge leaves
    that process alone.
D9. `pgrep` errors are errors (F42-5 major): exit 1 (no match) is an empty child set; any other non-zero exit,
    or a timeout, is a failed enumeration and goes to the next method (`ps`, `/proc`); when all fail, the kill
    is unconfirmed.
D10. The health journal loses nothing silently (F42-6 major, F44-1): an unparsable line is moved to
     `<journal>.bad` (appended, with the time), counted in the warning `health journal: <n> unreadable
     line(s) kept in <file>`, and the journal is truncated only by the number of bytes that were applied or
     moved - never blindly to zero.

## Member control and documentation

D11. A reviewer that compacts is seen (F43-3, F44-6): when the engine reports a compaction in its stream, the
     ledger records `compactions: <n>` and the run warns `the reviewer compacted its context <n> time(s) - the
     reply may rest on a summary of the brief`; the prompt of a member that has `context_tokens` ends with one
     line that names the brief file again ("before you answer, re-read the brief: <path>"). Which event the
     installed codex emits on compaction is looked up first; if none is observable, the ledger says
     `compactions: unknown` for such members and the README says so.
D12. The test-mode line also appears in the dry run (F44-5); the README states where it appears and where it
     does not (a refused run).
D13. The CHANGELOG states the runs as they were (F43-7), and wave 28c ends with one clean full suite on EACH
     host for the final code.
D14. The idle watchdog rule, revision 6 (the operator's decision of 2026-09-30): until a host lets the agent
     compact itself there are two states - while work runs or is awaited the context is kept warm always; when
     idle the agent writes the handover at idle wake 2, removes the wake and tells the operator the cheap ways
     back. The branch "keep the wake for half the refreshes a cold resume is worth" is removed from the skill
     and the README; the boundary tables stay as the operator's guide for a manual compaction; README names
     the launch option that bounds the context (`--autocompact <tokens>` on the host it was checked on).
Accepted as limitations, documented in one sentence each: F44-3 and F43-6 (the vendor class is derived from the
host name; a private gateway under a vendor's domain reads as that vendor).

Re-acceptance: by mimo and qwen (both held), with glm; the brief lists D1-D14 and the commit.
