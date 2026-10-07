Write in English.

_A/B pair 09 (wave 29c): this brief is a verbatim copy of `.collab/host-2026-09-26/handoffs/06-claude-wave27b-addendum.md` of an earlier task, re-asked against the CURRENT tree. Answer its numbered questions against the code as it is now; where the brief names a commit range or a file that no longer matches, say so and answer on the current code._

# Wave 27b - addendum to the R13 + R19 decisions (05), decided by the coordinator on 2026-09-29

Wave 27 (D1-D9 of 05) was implemented on 2026-09-28. Before its merge the operator asked for two more
coordinator hosts and specified the idle rule; one gap of D4 was found in use. Facts observed on this machine:

F1. A child of a Claude Code session inherits, beside CLAUDECODE, CLAUDE_CODE_ENTRYPOINT and AI_AGENT (the
    names D4 scrubs): CLAUDE_CODE_SESSION_ID, CLAUDE_CODE_BRIDGE_SESSION_ID, CLAUDE_CODE_CHILD_SESSION,
    CLAUDE_CODE_MESSAGING_SOCKET, CLAUDE_CODE_MESSAGING_TOKEN, CLAUDE_CODE_SESSION_ATTENDED,
    CLAUDE_CODE_EXECPATH, CLAUDE_PID, CLAUDE_EFFORT (names read from inside a child, values never). A reviewer
    with a shell would have received the messaging socket and token of the session.
F2. Z Code (Z.ai; desktop 3.14.3, CLI 0.16.9) is a Claude-layout plugin host: `plugins marketplace add` and
    `plugins install` installed the plugin (skills and the SessionStart hook recognised); its code substitutes
    both `${CLAUDE_PLUGIN_ROOT}` and `${ZCODE_PLUGIN_ROOT}` and sets ZCODE_SESSION_ID, ZCODE_PROJECT_DIR and
    ZCODE_PLUGIN_* for the processes it starts; it sets no Claude marker; it reads AGENTS.md; a headless run
    outside the app stops at "Select a model before continuing".
F3. Kimi Code 0.27.0 has no plugin system: `--skills-dir` loads the skills of the plugin;
    `${CLAUDE_PLUGIN_ROOT}` is not substituted; its shell tool on Windows is Git Bash; it sets no marker of its
    own; AGENTS.md is read from the working directory only; headless `-p` takes neither `--yolo` nor `--auto`;
    no hooks.
F4. On Claude Code the agent has no means to compact its own context: there is no tool, and a scheduled prompt
    whose text is `/compact ...` arrives as ordinary text (tested with a one-shot scheduled prompt).

Decisions:
B1. The scrub list of D4 gains the exact names of F1 and ZCODE_SESSION_ID, ZCODE_PROJECT_DIR and every
    ZCODE_PLUGIN*. Not the whole CLAUDE_CODE_ prefix (the operator settings such as CLAUDE_CODE_USE_BEDROCK must
    reach a future claude engine) and not CLAUDE_PLUGIN_ROOT / CLAUDE_PLUGIN_DATA.
B2. `coordinator.host` gains `zcode` (ZCODE_SESSION_ID or ZCODE_PROJECT_DIR); order codex, zcode, claude-code,
    unknown.
B3. README "Install" gains "Z Code" and "Kimi Code"; "Hooks on each host" and the "means per host" section of
    the coordinate skill name both.
B8. harness-detach SINGLE no longer depends on machine speed: the fake reviewer holds until a release file
    appears (test-only variables of the fake, cap 120 s); the assertions are unchanged. harness-panel RUN and
    GUARD stay as they are (they compare the start-up time of the bridge with fixed budgets).
B9. The idle watchdog rule replaces the watchdog-wake invariant of the coordinate skill (the operator
    specified it): (1) one recurring wake every 30 minutes, armed at the first delegation of the session and
    kept when the work ends; (2) the idle clock counts from the last activity of any kind; (3) small reads at
    every wake, anything finished restarts the count; (4) something must wake the coordinator when work ends -
    a detached panel gets a background `-Wait`; (5) nothing runs: wake 1 a note, wake 2 handover, compact,
    remove the wake; (6) something runs with an unknown end: wakes 1-2 check, wake 3 handover, compact, remove
    the wake; (7) where the agent cannot compact (F4): without running work - handover, remove the wake, one
    line to the operator; with running work - keep the wake while the expected wait is under about nine hours
    (a wake costs a cache read, a cold resume a cache write: about twenty wakes equal one cold resume); the
    auto-compact threshold of the host is the lever of the operator.

Verification: full suites on both PowerShell hosts on the final code (2026-09-29); live coordinator runs per
host are recorded in README "Tested on" as they happen.
