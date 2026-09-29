# Waves 26c, 27 and 27b - acceptance brief

Commit under review: c6f6966 (main, 0.5.0 candidate). The previous review was of 35d4a32 (handoffs 24-26 of
this task: glm ACCEPT with F25-1 minor and F25-2 note; mimo HOLD on F26-1..3 major, F26-4..5 minor, F26-6 note).
Binding decisions: `handoffs/27-claude-wave26c-decisions.md` of this task (D1-D6); for wave 27
`.collab/host-2026-09-26/handoffs/05-claude-r13-decisions.md` (D1-D9) and
`.collab/host-2026-09-26/handoffs/06-claude-wave27b-addendum.md` (F1-F4, B1-B3, B8, B9). The CHANGELOG `[0.5.0]`
entries "Wave 26c" and "Wave 27" (with its 27b sub-bullets) are the reports of the implementers: what, where,
deviations, counts.

## What the waves claim

1. 26c D1 (F26-1, F25-2): the member checks its kick file before the wait loop, on every poll and once more
   after the process exit; `-Kick` waits up to 10 s for the acknowledgement (`<kick file>.ack` or the state of
   the pending record) - exit 0 acknowledged, 1 no such running member, 3 no acknowledgement in time; a late
   kick is recorded `kick_late` and changes no outcome; a kick that hits only the format repair keeps the first
   reply.
2. 26c D2 (F26-2): the health lock waits 5 s, three attempts; a failed update is retried at the ledger commit;
   then `warnings[]` says `machine-wide health not updated (lock timeout)`; the stored `until` and
   `retry_after` are carried; the merge applies the documented tie-break.
3. 26c D3 (F26-3, F25-1): the stall timer resets on any growth of the stream in bytes and is suspended while a
   tool call is in flight (codex `item.started` of command_execution, mcp_tool_call, web_search until its
   `item.completed`; agy tool steps; muse `tool.*` tasks).
4. 26c D4 (F26-4): an empty or whitespace field counts as missing in the legacy rating completion. D5 (F26-5):
   `panel size raised: asked k, required r`, `size_source: required`. D6 (F26-6): accepted limitation, one
   README sentence.
5. 27 D1-D2: one plugin for every host, no copies of skills, nothing written to the home directory;
   `${CLAUDE_PLUGIN_ROOT}` stays in the invocations, `CODEX_CONSULT_ROOT` for a plain shell.
6. 27 D3: `CODEX_CONSULT_COORDINATOR` parsed by the reviewer matcher (split into `ConvertFrom-ReviewerMatcher`
   and `Test-ReviewerMatch`), compared on the resolved identity; refusal of an unparseable value before anything
   starts; ledger `coordinator {provider, model, engine, host, source}`; the warning "a second opinion from the
   coordinator's own model" (dry run too). Host hint order: codex, zcode, claude-code, unknown.
7. 27 D4 + 27b B1: `Hide-HostMarkers` around every engine child start, the detached background, `codex
   --version` and the launcher probes; ledger `child_env_scrubbed` (names only); the list of exact names and
   prefixes (CODEX_SANDBOX*, ZCODE_PLUGIN*).
8. 27 D5: the pointer line of the hook; `-Explain coordinate|consult|providers`. D6: host-neutral wording;
   `-BriefPrefix` / `CODEX_CONSULT_BRIEF_PREFIX` (reply prefixes refused). Parameter sets were removed from
   codex-consult.ps1 (they switched off positional binding); `-Task` is checked by hand.
9. 27 D7-D8 + 27b B3, B9: the `coordinate` skill (invariants, the idle watchdog rule, means per host), the
   agent files with tier aliases, the Codex agent examples, README "Install" for Claude Code, Codex CLI, Z Code,
   Kimi Code and any shell, "For the coordinator".
10. Tests: fifteen harnesses, the same counts on Windows PowerShell 5.1 and PowerShell 7 (0.3 229, roster 119,
    format 37, engines 97, muse 74, panel 54, pending 26, fixes 43 of 45 - the two F04-10 cases are
    environmental, lock2 11, 3b 12, visibility 121, detach 51, companions 42, fixes26b 51, host 50). B8: the
    detach SINGLE case holds the fake reviewer on a release file.

## The ask

1. F26-1..5 and F25-1..2: fixed / still open / accepted limitation, with the code location in the commit.
2. New defects in these waves. Look at: the kick acknowledgement (two `-Kick` callers at once; the `.ack` file
   left behind; exit 3 followed by a late poll); the health retry at the ledger commit (a record written twice;
   a lock held by a dead process); the stall suspension (a tool call that never completes - the timeout must
   still cut the member; a stream that grows by partial lines only); the coordinator identity (a label that is
   also a provider name; `#n` against a changed roster; the detached background inheriting it); the scrub (is
   the environment of the coordinator restored on EVERY path, exceptions included; does any production code
   honour the test-only variables of the fake; names versus values in the ledger); `-Explain` (can it read a
   file outside the skills directory); the removal of parameter sets (an option combination that was refused
   before and is accepted now); the skill and README text for each host (a command that cannot work as
   written). Cite lines. Say what you verified in code and what you inferred. Budget your time: a review of
   one wave.
3. ACCEPT only if no blocker or major remains; HOLD names exactly what must change.
