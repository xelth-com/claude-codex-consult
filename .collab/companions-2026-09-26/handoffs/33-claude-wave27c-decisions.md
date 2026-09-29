# Waves 26c, 27, 27b acceptance (handoffs 28-32) - decisions for wave 27c

Panel 222af1cb on c6f6966 (range 35d4a32..c6f6966), routed, required glm-5.3 and mimo-v2.6-pro:
glm ACCEPT (F29-1 minor, F29-2 note), mimo HOLD (F30-1..3 major, F30-4..9 minor), dola-seed-2.0-pro ACCEPT
(no finding), qwen3.8-max ACCEPT (F32-1..5 minor, F32-6..11 note). All four confirm F25-1..2 and F26-1..5 fixed:
those seven are verified. The HOLD of a required reviewer stands; wave 27c fixes every finding below. Two live
host checks of the same day add H1-H4 (`.collab/host-2026-09-26/handoffs/07-claude-host-live-checks.md`).

D1. Kick acknowledgement per request (F30-1 major, F29-2, F32-1, F30-6). The kick file carries a request id
    (a GUID) and is written atomically (temporary file, then rename). A caller that finds a kick file present
    JOINS it (reads its id) and never overwrites it. The member acknowledges with `<kick file>.ack` holding the
    id and the result (`stopped` or `late`) and removes the kick file. Callers wait for an acknowledgement with
    THEIR id; only the creator of the request removes the acknowledgement after reading it, a joiner never.
    No caller removes an acknowledgement before writing. An acknowledgement older than 60 s whose id is not
    the caller's is swept by any later `-Kick` and by the next run start of the member.
D2. A kick between two turns (F30-5): as designed, documented. A kick addresses the RUN of a member, not one
    turn: found before or during the format repair it cancels the repair and the first reply stays usable;
    found before or during the continuation it cancels the continuation and the timeout outcome with its
    salvage stays. README "Member control" says so; the ledger note names which turn was cancelled.
D3. Hiding the host markers is transactional (F30-2 major): one helper takes the snapshot first, removes
    inside `try`, restores in `finally`, and is used at every child start (engine turns, the detached
    background, the telemetry sender of wave 28). A removal that fails restores what was removed and the
    engine start is refused: `bridge failure: host markers could not be hidden (<name>: <why>)`.
D4. Probes never fail open silently (F30-4): when the start-info path cannot remove a marker the probe runs
    through the helper of D3; when that fails too the probe is skipped, the preflight reads "not checked" and
    `warnings[]` says why.
D5. The stream reader is bounded (F30-3 major, F32-8): only the newly read bytes are scanned for line ends;
    the carry is the text after the last line end, capped at 1 MiB - a longer unfinished line is discarded up
    to its end and counted (`oversized_lines`, one warning per run). Activity for the stall timer is the
    number of bytes read, independent of parsing.
D6. An open tool call cannot suspend the stall timer for ever (F32-7): when a tool call has been in flight
    longer than max(3 x stall seconds, 1800 s) with no growth of the stream at all, the stall timer resumes
    and the cut says `no output for N s (a tool call open for M s)`.
D7. Machine-wide health, every failure class (F30-7, F29-1, F32-3): any failure of the update sets the retry
    flag, and the warning names the real cause: `machine-wide health not updated (<cause>)`.
D8. The health retry never extends the hold on the task write lock (F32-2): inside the lock one attempt with
    a wait of at most 1 s; after the lock is released the full retry (3 x 5 s). The ledger warning, written
    inside the lock, reads `machine-wide health not updated at the commit (<cause>); retried after it`.
D9. The coordinator identity is a resolved triple (F30-8, F32-6): `#n` and a label resolve through the same
    code as a seated reviewer (the model of the entry, else the default the bridge would run). A bare
    provider label without a resolvable model gives the weaker warning `a reviewer from the coordinator's
    own provider (model not named)`; "own model" is said only when provider, model and engine are equal.
D10. One character rule (F30-9): coordinator parsing and the roster validator share one function - what the
     roster accepts as a provider or model string, the coordinator value accepts.
D11. A coordinator outside the roster is said, not refused (F32-4): ledger `coordinator.in_roster: false`,
     dry run and console line `coordinator: <id> (not in the roster - no reviewer can match it)`.
D12. `#n` that names no position here (F32-5): not a refusal. The coordinator is recorded with
     `unresolved: "#n"`, a warning `CODEX_CONSULT_COORDINATOR '#n' names no roster position here`, the run
     goes on. Only a value that cannot be PARSED is refused (D3 of the R13 decisions).
D13. Runnable as written on a host without substitution (F32-9, the Kimi Code run): the pointer line of the
     hook prints the full path of the script (the hook knows its own root); `-Explain` prints the skill
     text with `${CLAUDE_PLUGIN_ROOT}` replaced by the actual plugin root. The skills keep the variable and
     the root sentence (D2 of R13).
D14. Test hooks cannot change production behaviour by accident (F32-10): a `CODEX_CONSULT_TEST_*` variable is
     honoured only when `CODEX_CONSULT_TEST_MODE=1` is set too (every harness sets it); without it the
     variable is ignored and the run warns once that it saw one.
D15. `-Explain` flushes and disposes its output stream (F32-11).
D16. The kill is confirmed (H4, major; seen live): after a process tree kill the bridge checks that the root
     process exited. When the enumeration of children is denied (a restricted host) it falls back to
     `taskkill /PID <root> /T /F` and checks again. The outcome says `(process tree killed)` only when
     confirmed; otherwise `(kill not confirmed: <why>; pid <n> may still run)`, ledger
     `kill_confirmed: false`, a warning, and NO continuation turn on that thread.
D17. The plugin directory ships a short `README.md` (H1): what the plugin is, the three skills, `-Explain`,
     the URL of the repository README; the skills name "the repository README" with that URL where they
     refer to a section of it.
D18. `pwsh` on Windows (H2): the skills and the README say `powershell` for Windows (always present) and
     `pwsh` for macOS, Linux and a real PowerShell 7 install; the WindowsApps alias may be refused inside a
     host sandbox.
D19. The Codex CLI sandbox paragraph states what was observed (H3): on Windows with codex-cli 0.155.1 the
     `workspace-write` sandbox with network access enabled gave the reviewer child no connection
     (2026-09-29); `-DryRun`, `-Explain` and `-Status` work inside it; a real consultation needs the
     coordinator session outside the sandbox (the decision of the operator) or the operator runs the bridge
     command from a plain shell.

D20. The host hint of Z Code (seen live, task `r13-host`): the shell tool of Z Code carries neither
     ZCODE_SESSION_ID nor ZCODE_PROJECT_DIR (it carries other ZCODE_* names such as ZCODE_APP_VERSION,
     ZCODE_ENV, ZCODE_PROCESS_LABEL), so the host was recorded `unknown`. The hint `zcode` is given when ANY
     of ZCODE_SESSION_ID, ZCODE_PROJECT_DIR, ZCODE_APP_VERSION, ZCODE_PROCESS_LABEL is set. When no marker of
     any host is set, the hint comes from the install path of the running script (a plugin cache under a
     directory `.zcode`, `.codex` or `.claude`), recorded `coordinator.host_by: markers | path | none`. README
     "Z Code" says what was observed: no session-start line reaches the context of a desktop session - the
     second `AGENTS.md` line covers it.
D21. The scrub list for Z Code is the whole prefix `ZCODE_` (REPLACES the list of names first written here,
     and the prefix `ZCODE_PLUGIN` of 27b). Read by the operator inside a Z Code session on 2026-09-29
     (desktop 3.14.3, names only): ZCODE_APP_VERSION, ZCODE_BASE_URL, ZCODE_BUILD_COMMIT_ID,
     ZCODE_BUILTIN_PROVIDER_CONFIG_FILE, ZCODE_DESKTOP_CONTEXT_PROMPT_ENABLED, ZCODE_ENV,
     ZCODE_PERSONAL_PROVIDER_CONFIG_FILE, ZCODE_PROCESS_LABEL, ZCODE_RG_BINARY, ZCODE_RUNTIME_ENV,
     ZCODE_UGREP_BINARY, ZCODE_WINDOWS_APP_INSTALL_DIR. Two of them point at the provider configuration
     files of the operator; no reviewer engine reads any `ZCODE_` variable, so nothing is lost by removing
     them all, and a name a later build adds is covered. (The `CLAUDE_CODE_` names stay exact: the settings of
     the operator must reach a future claude engine.) The host hint of D20 follows: ANY variable with the
     prefix `ZCODE_` gives `zcode`, checked after the codex markers and before the claude-code ones.

Added from the full report of the Z Code coordinator (the operator pasted it after the run):
D22. The brief templates name no host (a residue of D6 of R13): `templates/brief-review.md` and every other
     template say `# Handoff <NN> - <coordinator>: <slug>`; the harness grep of D6 covers the templates.
D23. Where the three `AGENTS.md` lines go, per host, including the global file: the README names it for each
     host (Codex CLI `~/.codex/AGENTS.md`, Z Code `~/.zcode/AGENTS.md`, Kimi Code the project file only). A
     coordinator that finds no `codex-consult:` line in its instructions and none in its context runs the
     hook one-liner once - the `consult-codex` skill says so in its first section.
D24. Tool time limits of the hosts: a blocking bridge call is cut when the limit of the shell tool is shorter
     than the timeout of the run (seen: Kimi Code 300 s in the foreground, Z Code 600 s; a checkpoint run
     has 900 s). The `consult-codex` and `coordinate` skills say: when the limit of your shell tool is
     shorter than the timeout of the purpose, or unknown, start the run with `-Detach` and come back with
     `-Wait` or `-Status`; "means per host" lists the limits seen with their dates.

Harness cases for every D item with code (fakes only); D16 with a fake whose tree cannot be enumerated.
Re-acceptance: by mimo (required) with glm; the brief lists D1-D24 and the commit. It can run together with
the acceptance of wave 28.
