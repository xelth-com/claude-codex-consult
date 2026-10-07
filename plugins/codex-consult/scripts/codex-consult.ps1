<#
.SYNOPSIS
    Consult a reviewer (Codex CLI, or the agy / muse engine) from any coordinator - an agent
    session of any host, or a shell - and record the consultation as files.

.DESCRIPTION
    A thin, dependency-free bridge. You write a Markdown brief; this script runs

        codex exec --sandbox <s> --color never --json [-m <model>] \
                   -c model_reasoning_effort="<e>" [-c model_provider="<p>"] \
                   -o <tmp> \
                   [--output-schema <plugin>/schemas/consult-reply.schema.json] \
                   [fork|resume <thread>] -

    from the git repository root, captures the JSONL event stream and the last
    agent message, wraps the reply in a handoff file, and appends one entry to
    <CollabDir>/<task>/sessions.json. Failed runs are recorded as failures too.

    Structured mode (the default) asks Codex for one JSON object matching
    schemas/consult-reply.schema.json (verdict, reply_markdown, findings, ...) - the
    prompt OPENS with a "FINAL OUTPUT CONTRACT" paragraph, before the ask and the brief -
    validates it locally, renders it into the handoff file, keeps the raw object as
    handoffs/NN-codex-<slug>.reply.json and tracks the findings by id in
    <CollabDir>/<task>/findings.json (statuses are moved by codex-findings.ps1).
    -Raw is the 0.1 plain-text consultation without any of that.
    Format repair (-FormatRetry 1, the default; 0 = off; never with -Raw or chore): a
    usable reply that is not a valid object, is substantive prose (Get-ProseGate: not
    a refusal; >= 25 words with two numbered answers, >= 40 with one, >= 120
    otherwise - else validation_error ends "(format repair not attempted: reply looks
    like a refusal | reply too short (<n> words))") and came on a verified thread
    (codex exit 0, no timeout, no provider failure) gets ONE repair turn - `codex exec ... resume <thread>`
    with --sandbox read-only, the lowest effort of the route, the same -CodexConfig
    items, NO --output-schema and a prompt that asks to convert the previous message
    unchanged into the object (the schema and the consultation id; never the brief),
    within min(-TimeoutSec, 300) s under the same lock and recovery record (which names
    the saved prose as `original` while the repair runs, so a run stopped then leaves
    "a usable prose reply of that run exists at <path>; no ledger entry was written for
    it" in every message about its reservation). A valid
    result is ingested as the reply (.reply.json = the repaired object; the prose is
    kept as handoffs/NN-codex-<slug>.original.md and after the structured section);
    drift notes compare the two (RC ids, numbered answers, finding ids, verdict, every
    prose sentence of >= 60 characters, at most the 40 longest). Ledger format_retry {attempted, reason, succeeded, thread,
    wall_seconds, usage, drift[], original, events (the repair turn's event stream when
    one is kept - agy, muse; null for codex), schema_transport (wave 23b: the repair
    turn's transport - codex: prompt-only, it never passes --output-schema; agy and muse:
    the main turn's, native or prompt-only - a prompt-only run's repair passes no schema
    flag, the schema travels in the repair prompt)} after validation_error (null otherwise);
    console "format repair: <succeeded|failed> in <s> s; drift: <n> note(s)".

    Reviewer identity and lineage (0.3.0): the provider and the model are what Codex
    will use - -Provider / -Model, else the top-level model_provider (Codex's
    default: the built-in openai) and model of <codex home>/config.toml, read by a
    constrained scanner (codex-consult-common.ps1). Whatever is resolved is pinned
    on the command line (-m, -c model_provider=...). The ledger records
    reviewer{...} and lineage '<provider> :: <model>' (display only); a run forks
    or resumes only a thread of the same reviewer.provider AND reviewer.model
    (compared separately) on the same endpoint (provider_fingerprint =
    base_url + wire_api). Threads recorded before 0.3.0 have unknown provenance and
    are never parents. An unresolved identity (unreadable config, a selected
    profile, an unknown model) records 'unknown' and allows only -Mode new. The
    prompt's last line is "Consultation id: <guid>" (ledger consult_id): a thread
    taken from a rollout file instead of the event stream is accepted only when
    that rollout contains it. -Effort is mapped through the endpoint's effort
    vocabulary DECLARED for it (capability table caps-v1; -NativeEffort sends a value
    verbatim). CODEX_CONSULT_PEAK_<PROVIDER> declares a peak window: a warning, or
    a refusal with -OffPeakOnly. Codex profiles (-p) are not supported.
    Preflight (fails CLOSED): before anything is locked or started, the resolved
    provider's credentials must be present (openai: `codex login status`; other
    providers: their env_key variable or a bearer token), its availability must
    be establishable (a resolved identity, a `login status` that answers), and its
    ENDPOINT must not have been rejected as unauthenticated in the last 24 h in
    any task of this repository (unless a later run there succeeded), nor be at a
    usage limit whose reset time the provider named (provider_failure.retry_after,
    read from e.g. "try again at Sep 28th, 2026 8:35 PM." with the rules of the
    recording machine's time zone, daylight saving included - refused until then) -
    otherwise the run is refused; -SkipPreflight bypasses it (and then warns). A
    usage-limit failure WITHOUT a reset time refuses the run for 60 minutes after it was
    hit (wave 24b, F08-7: an explicit -Provider run too - one verdict for every caller);
    (wave 24c) a BURST - a 429 that names no usage window or quota, e.g. ModelArk's
    "exceeded retry limit, last status: 429 Too Many Requests" - for 10 minutes.
    Failed runs record a classified provider_failure (auth | quota | capability |
    transport | unknown, plus kind - burst or "" -, retry_after and hint; a failure stamped
    in the future counts as now; wave 24b: a prompt larger than the plan's or the model's
    context window - "Your current plan supports only k3 up to 256K context", even under a
    401 - is capability, never auth - unless its text also names a quota class such as
    billing or credits (wave 24c, F15-1: quota wins) - and the summary adds "hint       :
    context too long for this plan/model - ...", decided when the failure is classified,
    from the code and the full message: provider_failure.hint). The endpoint
    health is read at the consult clock
    (CODEX_CONSULT_NOW, a test hook). codex-providers.ps1 lists every provider with
    that verdict. No network call is made for any of it. Codex's stderr, its event
    stream, its last message and `codex login status` are decoded as UTF-8.
    -CodexConfig key=value[,key=value] adds per-run `-c` overrides (e.g. a
    provider's model_catalog_json) after the bridge's own; keys that would change
    the recorded identity or effort are refused. -SchemaTransport output-schema |
    prompt-only overrides how caps-v1 sends the reply schema for this run (ledger
    schema_transport_source). -Purpose chore is a plain-text reply like -Raw (effort
    low, 400 words, a bounded search or extraction task).

    Reviewer roster (optional; see codex-consult-common.ps1): an ordered list of
    reviewers {provider, model?, codex_config?, auth?: "none", panel?:
    "always"|"weighty"|"light"} in the JSON file CODEX_CONSULT_ROSTER names (it must exist -
    a missing one refuses every run), else <codex home>/codex-consult-roster.json
    (absent = no roster, everything as without one). CODEX_CONSULT_ROSTER=none: no
    roster at all, the default file is ignored too. An existing file that is not a
    valid roster refuses every run (-DryRun too). With a roster:
      * -Provider: the roster does not select, but that provider's entry supplies
        the model (when -Model is empty) and codex_config (when -CodexConfig is
        empty); ledger model_source / extra_config_source "roster"
      * -Thread: the thread's ledger entry fixes the reviewer (provider_source and
        model_source "-Thread"); its roster entry supplies codex_config. If that
        reviewer is unavailable the refusal names what the roster would select for
        a new thread (-Mode new)
      * otherwise the roster is walked in order and the first entry whose preflight
        is available runs (a usage limit without a reset time < 60 min old is
        skipped, as everywhere); every skipped entry is recorded with its reason; none
        available = refused, nothing started. -Model without -Provider restricts the
        walk to the entries of that model; -SkipPreflight takes the first entry. The
        parent thread is then chosen for the SELECTED lineage as always.
    Ledger: roster {path, position, skipped[{provider, model, reason}], applied[]}
    after preflight_warning ($null without a roster); one line "Roster: ..." on the
    console, in the dry run and in the handoff header.
    -Panel (-PanelAll: every eligible entry, "weighty" and "light" ones too, whatever the
    purpose) sends the same brief to the roster entries it seats (wave 26: as many as the purpose needs, seated by
    their track record - "Companions" below), each a consultation of its own (own
    preflight, recovery record .consult.pending-<NN>.json, parent thread, consultation
    id, handoffs/NN-codex-<ReplyName>-<provider>.md and ledger entry with panel {id,
    position, of, members[{provider, model, state run|skipped, reason}], concurrency,
    limits}). 0.4.x wave 21 (ROADMAP R11): the members run IN PARALLEL as processes
    of their own - members of different endpoints at once, of one endpoint (one
    provider label, or labels that resolve to one provider fingerprint) one after
    another unless the roster's top-level "parallel" raises it; -PanelConcurrency
    caps the total (0 none, 1 strictly one after another). The -Panel run holds the
    task lock for the whole panel, judges every recovery record of the task first,
    assigns n and NN to every member up front in seat order and writes each
    member's `reserved` record before any member starts; a member accepts its spec
    only when that record names its panel, n, NN and parent, rewrites it with its
    own pid and only then checks that the parent lives (a parent gone: the member
    withdraws the record and stops, nothing started), and commits under the write lock
    (.consult.write.lock: re-read the stores, apply its own delta - the ledger stays
    sorted by n). A "weighty" entry joins only on framing, decision, core-contract,
    acceptance and stuck; a "light" entry (2026-10-07) joins on the other purposes and on
    those five only stands in - when no other entry of its provider label runs (listed
    "stands in for #<p> (<that entry's skip reason>)"). Every member is shown the findings
    open when the panel started. A failing member does not stop the others; with -PanelConcurrency 1 a
    member that leaves surviving processes stops the remaining ones (summary:
    "skipped  not started: ..."). A summary block closes the run; exit 0 only when
    every member produced a usable reply. Not with -Provider, -Thread or -Mode
    resume. TEST HOOKS: CODEX_CONSULT_TEST_SURVIVORS=<pid> makes a timeout kill
    report that live pid as a survivor; CODEX_CONSULT_TEST_WRITE_LOCK_SEC=<s>
    shortens the 60 s write-lock wait; CODEX_CONSULT_TEST_COMMIT_PAUSE_MS=<ms> (or
    <model>=<ms>[|...]: the runs of that model only) pauses a commit between
    findings.json and sessions.json; CODEX_CONSULT_TEST_PANEL_GUARD_SEC=<s> replaces a
    panel member's kill guard; CODEX_CONSULT_TEST_MEMBER_PAUSE_MS=<ms> pauses a panel
    member between the rewrite of its record and the check of its parent;
    CODEX_CONSULT_TEST_LAUNCH_PAUSE_MS=<ms> (or <model>=<ms>[|...]) pauses between the
    main turn's `launching` record and its guarded start (wave 24b).

    Companions (0.5.0, wave 26 - ROADMAP R14-R16):
      * size: a panel STARTS as many members as its purpose needs - chore, none and checkpoint
        1, diff-review 2, framing and decision 3, core-contract and acceptance 4, stuck every
        eligible member; -PanelSize <n> overrides (not with -PanelAll, which takes every
        eligible member). Eligible = available (the roster walk's verdict), past the weighty
        and light gates, matching -Engine/-Model - one set for the size, the ranking, the draw
        and the exploration. An eligible entry without a seat is `not-picked` (reason "panel size k"),
        never a skip. No backfill: a member that fails is not replaced. The summary and the
        ledger's panel record say `asked k, started j, usable i` (started/usable are written
        into every member's entry when the panel ends; wave 26b, D2: asked is the size
        REQUESTED, and fewer eligible members than asked warn "panel size reduced: asked k,
        eligible m" - console, handoff header, warnings[]; panel.routing.size_asked beside
        size; wave 26c, D5: more required members than asked warn "panel size raised: asked k,
        required r" the same way, panel.routing.size_source "required"). A framing or decision panel of fewer than 2 members warns (console, ledger
        warnings[]) unless -PanelSize was given
      * routing (-PanelOrder routed, the default): the seats are drawn by the members' routing
        scores - the judge's marks (codex-findings.ps1 -Rate) of every task of the repository
        from the last 90 days by the consultation's time, a rate with a prior
        (yes + 0.5 partly + 1) / (n + 2) scaled into [0.25, 2] (neutral 1.125), per (lineage,
        purpose[, topics]) with >= 3 marks, else the lineage's all-purpose rate with >= 3, else
        neutral. While NO eligible member has 3 marks the panel keeps the roster order
        (panel.routing.fallback "no ratings"); -PanelOrder roster always does. The draw: a seed
        = SHA-256 of "<task>|<purpose>|<brief sha256>|<sorted eligible lineages>|<nonce>" (the
        nonce: -PanelSeed, else CODEX_CONSULT_TEST_PANEL_SEED, else today's UTC date - a dry run
        and the real run of the same day draw the same seats; wave 26b, D3: every field of that
        text - and every lineage in the list - is written <len>:<value>, len its UTF-8 byte
        count, so no delimiter inside a value can shift a boundary; the reference
        implementation is tests/reference-draw.py); per seat SHA-256(seed || seat as 4
        bytes big-endian): its first 8 bytes (the top 53 bits / 2^53) pick by weight, the next 8
        explore (< 0.2: a uniform pick) - identical on Windows PowerShell 5.1 and PowerShell 7.
        Lab diversity (wave 26b, D5 - stated over the seats LEFT after the required): the reserve
        is min(seats left after the required, labs with an entry scoring >= neutral not yet
        seated); while fewer reserve seats are taken, a seat draws only from labs not yet
        seated whose entries score >= neutral (panel.routing.reserve: the seats it took; a lab:
        the roster entry's "lab", else the vendor of the model id's prefix - qwen alibaba,
        deepseek, kimi/k3 moonshot, glm zhipu, dola/seed bytedance, mimo xiaomi, gemini google,
        muse meta, gpt openai - else a lab of its own, with a warning). Members get their n and
        NN in seat order. Ledger panel.routing {mode, order, fallback, seed, nonce, nonce_source,
        size, size_asked, size_source, reserve, eligible[{position, lineage, lab, lab_source,
        score, basis, ratings,
        required}], picked[{slot, position, lineage, lab, rule: required | roster | lab-draw |
        lab-explore | rank-draw | rank-explore}], explored[], required[]}; the dry run prints it
      * -Topic a,b: the consultation's topics (slugs; ledger topics[], copied onto a rating);
        a routed panel scores on (purpose, topics) first - a mark credits each of its t topics
        1/t, the counts pooled
      * -Require <reviewer>[,...] (-Panel, or a single run with -Provider): a roster position
        (#5), a provider label (every entry of it) or '<provider> :: <model>' with an optional
        ' [<engine>]' - compared on what the roster names, never on a display string. A panel
        takes its default from the roster's "require": {"<purpose>": [...]} (validated at load:
        every matcher names an entry); -Require none drops it. A required reviewer is judged
        with the roster walk's verdict (a usage limit without a reset time is out); one that is
        out refuses the run before anything starts - who, why and when it is back - EXIT 5 (the
        dry run too); in a panel it takes a seat first (past the weighty or light gate), and when
        it produces no usable reply no further member starts: exit 5
      * -Role <name> (a single run, or every member of a panel) / -Roles a,b (a panel: by score
        rank, highest first; a roster entry's "roles": [...] says which it is willing to take -
        wave 26b, D4: an exact matching - every role some seated member is willing to take
        goes to a willing member, each role in order to the best-ranked member possible; only
        when no such assignment exists the greedy rank order, said in panel.roles_note and a
        warning): the block <CollabDir>/roles/<name>.md, else the plugin's
        templates/role-<name>.md (edge-cases, security, tests, docs), goes into the prompt after
        the ask and before the brief (never inside the output contract; the reply format, the
        verdict rules and the read-only rules stay). Names are slugs; an unknown role and more
        roles than members is refused; (wave 26b, D1) a role file must be a regular file inside
        its roles directory - a symlink or junction on the way (the file, the roles directory)
        refuses the run before anything exists ("role file refused: ..."). Ledger role
      * (wave 26b, D16) a roster entry's "context_tokens" (the reviewer's context window, an
        integer >= 32000): its prompt says "Your context window is M tokens: read only what the
        brief points to; prefer targeted reads." after the ask; a fork/resume whose thread last
        carried more than 80% of it with this prompt (usage.input_tokens of the thread's entry,
        else its events' last usage, plus (prompt + brief)/4) becomes a NEW thread - ledger
        mode_fallback {from, to, reason}, a summary line, the prompt names the previous reply
        file; a brief whose estimate ((ask + brief)/4) alone exceeds 80% skips the entry before
        its start ("brief too large for this reviewer's context (est. N of M tokens)"; an
        explicit -Provider run of it is refused)
      * (wave 26b, D13 - ROADMAP R20) the machine-wide endpoint health file <codex
        home>/codex-consult-health.json (CODEX_CONSULT_HEALTH=<path> another, =none none): every
        run records its usable reply or provider failure there ({endpoint, class, kind, until,
        retry_after, repo, when, message}) and its row in running[] while its turns run; every
        roster walk reads it beside the repository's ledgers (one record set, the newest
        decides), and a panel's endpoint parallel limit counts the runs of other repositories
        and panels on the endpoint ("panel member k of n waits: ..."). Optional: absent or
        unreadable = as before. (wave 29b, E16) A running row carries the roster entry's plan;
        a panel member counts every running row of its plan too, of any engine and repository
        ("... use its plan <slug> ...", the plan's limit: "parallel" {"<plan>": n}, default 1)
      * the roster's "ext" (top level and per entry) is an object reserved for other
        implementations: validated as an object, never read, never written
    Exit codes: 0 usable (a panel: every member), 1 a refusal or a failure, 5 a required
    reviewer is not available (or failed in a panel), 6 a detached background whose final status
    could not be written (its result is only in its log); -Status / -Wait: 0, 1, 2, 3, 4;
    (wave 26b) -Kick: 0 done, 1 no such member or not running, 4 refused.

    Engines (0.4.0): the CLI that carries the consultation - `codex` (the default, all of
    the above), `agy` (Google's Antigravity CLI for the Gemini models) or `muse` (Meta's Muse
    Code CLI, wave 23), chosen by -Engine or by the roster entry's `engine`. An agy or muse run
    has the same ledger, handoff files (handoffs/NN-agy-<slug>.*, NN-muse-<slug>.*), findings,
    ratings, panel, scoreboard, preflight, lock and recovery record as a codex run; every turn
    of such an engine (the main turn, a denial retry, a format repair) goes through the
    engine's adapter (argv from one turn-options object, its own prompt file, its own stream
    parser and failure rules) in the main turn's schema transport (wave 23b: a prompt-only
    run's secondary turns pass no schema flag either; the schema travels in their prompt).
    What differs for agy:
      * argv `agy -p= --input-format stream-json --output-format stream-json --model <m>
        [--json-schema <schema>] --print-timeout 0 --sandbox --disable-slash-commands
        [--conversation <thread>] [--effort <v>]`; the prompt is ONE NDJSON line
        {"event":"user","message":{"content":...}} on stdin; the working directory is the
        repository root; -EngineExe / CODEX_CONSULT_AGY_EXE override the launcher
      * the reply is the single `result` event's structured_output (else its response
        text, which goes through the prose gate and the format repair); the thread is
        result.conversation_id; usage maps cache_read_tokens -> cached_input_tokens and
        thinking_tokens -> reasoning_output_tokens
      * default mode new; -Mode resume / -Thread send --conversation; fork, -Sandbox
        workspace-write, -CodexConfig and -SchemaTransport output-schema are refused; the
        schema transport is `native` (or prompt-only); effort: nothing is sent (the tier is
        part of the model id; effort_mapping model-tier) unless -NativeEffort
      * a run FAILS on: exit != 0, a malformed stream (not exactly one result; a line that
        does not parse - the last one may be partial only after a kill or a non-zero exit),
        no result, init/result conversation ids that differ, status != SUCCESS, on resume
        the "conversation not found" warning or another id, stderr "partial output", an
        empty reply (with a denial notice: class permission) - and when the working tree
        (tracked or untracked files), the collab directory (every file under -CollabDir:
        all task stores and handoffs), the brief or an artifact changed during the run, by
        the reviewer or anyone else (agy's --sandbox does not block writes; the tree check
        does - enforced by evidence for tracked and untracked files and the collab
        directory; not for gitignored paths, submodules or files outside the repository).
        A denial notice or a `warning:` line with a usable reply is ledger `warnings[]`
        (present for every engine; also a non-unique -Provider label without -Model)
      * -DenialRetry 1 (the default): a run that produced nothing because a tool was
        auto-denied gets ONE more turn on the same conversation telling the model not to
        call it again (ledger denial_retry {..., events}, after format_retry)
      * preflight credential: `agy models` (45 s; cached per listing), skipped when THIS
        repository's ledgers hold a usable reply on the agy endpoint from the last 60
        minutes ("ok: signed in (usable reply <m> min ago)"; a recorded auth failure or
        usage limit still refuses)
    What differs for muse (the Muse Code subscription, signed in by browser with `muse login`;
    TBH_CREDENTIAL_BACKEND=file is required on Windows):
      * argv `muse exec --json --prompt-file <P> [--output-schema <S>] --model <m>
        [--reasoning-effort <e>] --no-foreign-personal-context --disable-web-tools
        --disable-write --disable-shell --approval-mode never [--max-model-steps <n>]
        [--session-id <thread>]` in the repository root; the prompt is the turn's own
        prompt file (stdin stays empty); the launcher: -EngineExe, CODEX_CONSULT_MUSE_EXE,
        PATH, then %LOCALAPPDATA%\Programs\muse\muse.cmd (Windows); a .cmd launcher with a
        '%' in an argument (a TEMP path) is refused before launch (cmd.exe would expand it)
      * the stream is MSP JSONL, schema_version 1 only: the reply is the text of the ONE
        run_terminal record, the thread the ONE session stream id; run.model.configured
        must name the requested model (else "model drift", class capability); no token usage;
        (wave 23b) the evidence is bound to the session stream and the ONE run it links
        (session.run.linked): a run.model.configured record off the session stream or of
        another run, a second linked run or a completed terminal of another run is
        "ambiguous provenance" - a malformed stream (class transport)
      * effort: vocabulary muse (mapping muse-v1: low medium high xhigh as is) for the
        declared models muse-spark-1.3 and muse-spark-1.3-contributor, sent as
        --reasoning-effort; -MaxModelSteps <n> sends --max-model-steps
      * billing, a launch invariant that -SkipPreflight never bypasses (fail-closed since
        wave 23b): a muse run needs an ESTABLISHED oauth sign-in - META_API_KEY or
        MODEL_API_KEY set, a credential mechanism other than oauth, or no mechanism
        established at all (the keychain backend, no auth.json, no providers.meta, no
        mechanism: "the Muse sign-in is not established as oauth (<cause>): ...; set
        TBH_CREDENTIAL_BACKEND=file and run `muse login`") refuses the run, the dry run too (a
        roster walk or a panel skips the entry: "refused: ..."); ledger
        reviewer.provider_config.credential_mechanism (oauth)
      * preflight: ~/.config/muse/auth.json must hold providers.meta with a mechanism (key
        names and the mechanism only; missing: "run `muse login`"); the keychain backend is
        not checkable - both states are refused at launch already (the billing guard)
      * no denial retry (the write, shell and web tools are off); a format repair continues
        the session (--session-id) in the main turn's transport (--output-schema only on a
        native run; ledger format_retry.schema_transport); each turn is one subscription prompt (ledger
        engine_run.turns); the harness is muse-cli <version> (.muse-version next to the
        launcher, else --version); engine_run.msp_schema_version
      * exit 2 (usage error) and a step-cap stop are class capability, 130/143 transport,
        a failed terminal's reason goes through the classifier verbatim (quota wording ->
        quota with its reset time)
    Both engines: a change of the working tree or the collab directory detected after the
    run fails it as class permission - also when it had already failed for another reason
    (that reason stays in the provider failure's message). (wave 26b, D9) Not so for muse,
    which the bridge runs write-DISABLED (--disable-write --disable-shell): there the change
    cannot be the reviewer's - it becomes a warning ("the collab directory changed during the
    run (1 file: .collab/t/state.md) - muse ran write-disabled, the change is not the
    reviewer's"), the reply stays usable; agy keeps the failure (F12). Ledger tree_check
    {outcome clean|warned|failed, files[]} (null for codex). (wave 24c) The working tree is
    compared by file CONTENTS (every tracked file's blob, every untracked file's hash): a
    commit, a moved HEAD or a staged change that leaves every file as it was is no change -
    ledger revision_moved "<old> -> <new>" notes a moved HEAD.

    Timeouts (0.5.0, wave 24 - a timeout never throws the reviewer's work away):
      * -TimeoutSec unset: the purpose's default - chore 600, checkpoint and none 900, framing
        and decision 1800, diff-review, core-contract and stuck 2400, acceptance 3600 s; an
        explicit -TimeoutSec always wins (ledger timeout_sec, timeout_source purpose|explicit;
        a -Panel's members inherit the resolved value). (wave 26b, D11) A roster entry's
        "timeout_sec" (an integer >= 60) replaces the purpose default for that reviewer (a
        panel member or a single run of that entry; timeout_source roster; its continuation
        budget follows it unless -ContinueSec is given); the panel's Timeout line lists these
        exceptions ("3600 s per member; #7 alibaba :: qwen3.8-max 1200 s (roster)")
      * (wave 26b, D12 - ROADMAP R18) -StallSec <s>: a run whose engine event stream (codex
        --json items, agy stream-json, muse MSP records - line by line) produced no event for
        that long while its process lives is stopped like a timeout: the same continuation
        turn and salvage, bridge_outcome "failed: stalled after N s without an event (process
        tree killed)", ledger stall {seconds, last_event}. Default 900; a roster entry's
        "stall_sec" overrides it for that reviewer (an explicit -StallSec wins); 0 = off
      * (wave 26b, D10) -Kick -Member <NN> [-Id <id8>]: from another shell, stop ONE running
        member of a panel (or a single run) of -Task by its handoff number - a detached panel
        with -Id, a foreground panel without (the member polls <task>/.consult.kick-<NN> while
        its engine turn runs). Its process tree is stopped, its partial output salvaged, it is
        recorded "failed: stopped by the operator (-Kick)" (provider_failure class operator -
        no endpoint's fault), the panel goes on with the others; -Status shows "stopped by the
        operator (-Kick)". Exit 0 done, 1 no such member or not running, 4 refused.
        (wave 26c, D1) The member checks the kick file before its wait loop, on every poll and
        once more after its process exited, and acknowledges it (<kick file>.ack): -Kick waits
        up to 10 s for that - exit 0 acknowledged (a member that had already finished records
        `kick_late` in warnings[], its outcome unchanged; a kick that stops only the format
        repair leaves the first reply usable), 1 no such running member (a kick file of that
        number is removed), 3 no acknowledgement in time (the file stays for the next poll)
      * (wave 26c, D3) the stall cut's timer resets on ANY growth of the event stream (bytes)
        and is suspended while a tool call is in flight (codex command_execution, mcp_tool_call,
        web_search items; agy tool steps; muse tool.* tasks)
      * continuation: when the bridge kills the MAIN turn on its timeout and the turn's thread
        is known (codex: thread.started; agy: the conversation of its init event; muse: its
        session stream), ONE more turn continues that thread (codex `exec ... resume <thread>`
        with the main turn's options; agy --conversation; muse --session-id) with the prompt
        "Your previous turn was stopped by a time limit after N s. Do not start over and do
        not read more files than you must: finish now and output your final answer in the
        required format." within -ContinueSec s (default min(timeout, 900); 0 = off). A usable
        reply is ingested like a first-turn reply, bridge_outcome "usable reply (after a
        timeout continuation)"; ledger timeout_continue {thread, wall_seconds, outcome, events,
        usage} (outcome "not attempted: <why>" when none ran: -ContinueSec 0, no known thread,
        surviving processes, "files changed during the run (the working tree | the collab
        directory | the brief | artifact(s))" - wave 24b, F08-2: one tree check for every
        engine, codex included; wave 24c: a change of file CONTENTS - a commit or a moved HEAD
        meanwhile is only noted, ledger revision_moved - or a quota, billing or auth failure in
        the killed turn's own evidence - F08-3, wave 24c F15-3: the structured evidence first -
        the adapter's class, the event error, the adapter's texts, a provider error payload on
        stderr - then only the DIAGNOSTIC stderr lines (ERROR level, or an HTTP status with its
        message; never a known informational engine message such as codex's models refresh),
        through the one classifier) - or (wave 29b, E12) a claude turn whose init or model
        proof failed although the bridge killed it (an extra tool, an MCP server, another
        permission mode or model, apiKeySource, a missing init field): that problem is the
        outcome, "not attempted: the killed turn failed its proof (...)", the salvage is kept.
        Never more than one per consultation; never after a
        quota, auth or billing failure (the launch guard - muse: auth.json - is re-read right
        before EVERY start of a turn, the main turn included: Start-EngineProcess, F08-1). On a
        prompt-only transport the continuation prompt carries the reply format and the schema
        again (F07-1). (wave 24b, F08-5) The continuation counts only when its reply passes a
        first reply's checks - a valid reply object, else substantive prose (Get-ProseGate;
        -Raw and chore: substantive prose); otherwise its outcome is "failed: not a usable
        reply - <why>" and the salvage is kept. (F08-4) A continuation that failed supplies
        provider_failure (its stderr, event error, class and retry_after - the endpoint health
        reads it). A panel member continues in its own process (its guard grows by
        -ContinueSec)
      * salvage: when a turn was killed on its timeout (the main turn without a successful
        continuation, the continuation, a denial retry, a format repair) - (wave 26b) or
        stopped by the stall cut or the operator's -Kick, and (D15) when ANY failed run's event
        streams hold at least one agent message, reasoning text or tool call (a provider failure
        mid-run, a denial, a tree-check failure; the footer then says "the run ended: <why>"
        instead of "killed at"; a stream without content leaves nothing) - the bridge writes
        handoffs/NN-<engine>-<slug>.partial.md - the reply's header, then per turn every agent
        message and reasoning text of its event stream in order and its tool calls (the
        command line of a shell command), then "killed at <t> s of <T> s; thread <id> -
        continue with `-Task <t> -Mode resume -Thread <id> -Purpose <p> [options] -Prompt
        "finish your review"`" (ledger partial_reply after events; bridge_outcome stays
        "failed: timeout ..."); the summary prints it and the exact manual resume command -
        (wave 24b, F08-6) with every replay-relevant option the run was given: -TimeoutSec
        (explicit), -ContinueSec (not the default), -Effort / -NativeEffort, -MaxWords,
        -SchemaTransport, -CodexConfig, -Artifact (resolved paths), -Range, -Sandbox (not
        read-only), -MaxModelSteps, -FormatRetry 0, -DenialRetry 0, -OffPeakOnly, -CodexExe /
        -EngineExe, and (wave 24c, F15-5) -ReplyName (when given; a panel member's own) and
        -SkipPreflight. -Thread takes the conversation of a killed agy or muse run (its entry
        names the partial reply). (wave 24c, F08-4) A continuation reply the checks REJECTED is
        kept in the partial file under "## continuation reply (rejected: <why>)", and
        timeout_continue.outcome names it
      * -Range <revision range> (diff-review and acceptance only): `git diff --shortstat
        <range>` once - "the range changes N files, M lines" in the prompt, ledger range
        {spec, files, insertions, deletions, lines}; a range of more than 1500 lines with a
        timeout below 2400 s WARNS (console, handoff header, ledger warnings[]); an unknown
        range, and (wave 24b, F08-8) a single revision - only base..head or base...head: a
        single revision would measure the working tree - is refused before anything starts

    Non-blocking consultation (0.5.0, wave 25 - ROADMAP R12): -Detach (a single run or -Panel;
    not with -DryRun, -Status, -Wait or -PanelSpec) checks the consultation in the caller's
    process like a real run - everything a dry run checks, plus what a real run refuses before
    its lock: a missing launcher of an engine that will run, an active recovery record, the
    preflight (a refusal: exit 1, nothing written) - then writes
    <task>/.consult.detached-<id8>.status.json (state starting; <id8> = the first 8 hex digits
    of the detach id), starts the consultation in a BACKGROUND process in the caller's working
    directory with -Brief, -Artifact and -CollabDir made absolute (Windows: cmd.exe /c through
    ShellExecute, hidden, the output redirected - it inherits none of the caller's handles;
    elsewhere /bin/sh -c 'exec nohup ...') and exits 0 printing the detach id, the status file
    and how to come back. The background is an ordinary run (lock, records, numbering, members,
    kill guard, commit, summary) that also keeps the status file (atomic replace): `running`
    {pid, start_time, host} first, the members as they start and finish (pending | running |
    usable | failed | skipped | killed | blocked | commit_blocked | orphan, with the outcome),
    `done` {exit, summary} on every exit path - a refusal after the start included; its console
    output (UTF-8) goes to <task>/.consult.detached-<id8>.log. Not checked in the foreground: the
    task lock and the time-dependent health/peak selection (a benign window: the background is
    refused, its status says so). -Status [-Id <id>] prints the detached runs of the task,
    newest first: the state, one line per member and, once done, the summary block the run
    printed; exit 0 all done and usable, 1 a failure (a run whose background died too), 2 one
    still running, 4 the query is refused (an -Id that matches no run or several, other
    options). -Wait [-Id <id>] [-WaitTimeoutSec <s>] checks every 2 s until the run(s) are done
    or their background is gone, then prints as -Status; its default timeout is the run's budget
    (budget_sec: per endpoint group ceil(members / limit) x the member guard, the largest group;
    with -PanelConcurrency also ceil(N / cap) x the guard; + 120 s); still running after it: exit
    3, the run untouched. -Status -Prune (the one writing form) deletes the files of runs that are
    done or died and were last written more than 7 days ago - (wave 26) and an unreadable status
    file 7 days after the file's own last write (-Status names the command that removes a younger
    one by hand); a never-started run only when its log was not written in those 7 days either. A
    background on another host is never judged. (wave 26) An inline -Prompt of a detached run goes
    to <task>/.consult.detached-<id8>.prompt.txt: the `starting` record names only that file, the
    background reads and removes it. The background's final status write is retried (3 x 250 ms);
    when it still fails the background exits 6 and says that the result exists only in its log. codex-findings.ps1 -List prints one line per detached run that is not done, the
    SessionStart hook one phrase for the repository. TEST HOOK: CODEX_CONSULT_TEST_DETACH_GUIDS=
    <guid>[,<guid>] - the detach ids tried first.

    (wave 27, R13) The host is a parameter. The coordinator - the agent session (of any host) or
    the shell that runs this script, the judge of every reply - may name its own model in
    CODEX_CONSULT_COORDINATOR (`<provider> :: <model>` [` [<engine>]`], a roster position `#<n>` or
    a provider label, parsed and compared like -Require): a seated reviewer whose RESOLVED identity
    is the coordinator's warns "a second opinion from the coordinator's own model" (the dry run too;
    never a refusal); a value that does not parse is refused before anything starts. (wave 27c,
    D9-D12) The value is RESOLVED like a seated reviewer (the entry's model, else the model the
    bridge would run): "own model" only when provider, model and engine are equal; a label whose
    model cannot be told gives "a reviewer from the coordinator's own provider (model not named)";
    only an unparseable value is refused (the roster's character rule); a value no roster entry
    matches is said (in_roster false), a `#<n>` that names no position here is warned about
    (unresolved). Its host is inferred as a hint only, in this order (codex: CODEX_SESSION_ID /
    CODEX_THREAD_ID; zcode: any ZCODE_ variable; claude-code: CLAUDECODE, CLAUDE_CODE_ENTRYPOINT,
    AI_AGENT claude-code*; else the install path - wave 28b, D11: only a script UNDER a host's
    plugin directory of this home: ~/.claude/plugins/cache, ~/.codex/plugins/cache or <codex
    home>/plugins/cache, ~/.zcode/cli/plugins/cache, ~/.qwen/extensions (qwen-code) -; else unknown). Ledger `coordinator {provider, model, engine, host, host_by, source
    explicit|inferred|none, in_roster, unresolved}` - `host` elsewhere stays the machine name. Every
    engine child (the main turn, a denial retry, a format repair, the continuation, the detached
    background, the launcher probes, the telemetry sender) is started WITHOUT the coordinator's host
    markers (CODEX_SESSION_ID, CODEX_THREAD_ID, CODEX_CI, every CODEX_SANDBOX*, CLAUDECODE,
    CLAUDE_CODE_ENTRYPOINT, AI_AGENT; wave 27b: CLAUDE_CODE_SESSION_ID, CLAUDE_CODE_BRIDGE_SESSION_ID,
    CLAUDE_CODE_CHILD_SESSION, CLAUDE_CODE_MESSAGING_SOCKET, CLAUDE_CODE_MESSAGING_TOKEN,
    CLAUDE_CODE_SESSION_ATTENDED, CLAUDE_CODE_EXECPATH, CLAUDE_PID, CLAUDE_EFFORT; wave 27c: every
    ZCODE_* - the whole prefix); exact CLAUDE_CODE_ names, so every other variable is kept
    (CLAUDE_CODE_USE_BEDROCK and the like, CLAUDE_PLUGIN_ROOT). (wave 28b, D10) No engine child gets
    CODEX_CONSULT_TEST_MODE or a CODEX_CONSULT_TEST_* variable either (a panel member and the detached
    background are the bridge: they keep them), and the telemetry sender starts with an allow-listed
    environment only. (wave 27c, D3) The hide is
    transactional: a marker that cannot be removed puts every removed one back and the start is
    refused ("bridge failure: host markers could not be hidden (<name>: <why>)"). Ledger
    `child_env_scrubbed` (the names, never a value).

    (wave 27c) Kill, kick, health, test hooks: a process tree kill is CONFIRMED (the root exited and
    every enumerated descendant; where the children cannot be enumerated - a restricted host - the
    fallback `taskkill /PID <root> /T /F` and the root again): "(process tree killed)" only then, else
    "(kill not confirmed: <why>; pid <n> may still run)", ledger kill_confirmed false, a warning and
    no continuation turn (D16). A -Kick request carries an id, is written atomically and JOINED by a
    second caller; the acknowledgement holds the id and the result (stopped | late) (D1); a kick of
    the timeout continuation keeps the timeout outcome and its salvage (D2). The stall reader is
    bounded (1 MiB carry, oversized lines skipped and counted - D5) and a tool call suspends the stall
    cut only while the stream grows: 2 x -StallSec without growth end it, and the cut names the open
    call (wave 28b, D12). Any failure of the machine-wide health update is retried and named; (wave
    28b, D13) at the commit its record goes into the journal <health file>.journal, the retry after
    the commit - or the next run of any repository - applies it, and the summary says how the retry
    ended. A CODEX_CONSULT_TEST_* hook (and CODEX_CONSULT_NOW) is honoured only with
    CODEX_CONSULT_TEST_MODE=1; otherwise it is ignored and the run warns once (D14); (wave 28b, D10) a
    run in test mode says "test mode is ON: test hooks are honoured" on the console and in warnings[].
    -BriefPrefix names the coordinator's briefs (handoffs/<NN>-<prefix>-<slug>.md; default
    claude); -Explain coordinate|consult|providers prints a skill's text for a host without skills.

    (wave 28, R17) Telemetry, ON by default (installing the plugin means accepting its terms - README
    "Telemetry (on by default)"): after the ledger commit of every consultation (a failed one too;
    a panel: every member) ONE anonymised event built from the committed entry through a closed
    allowlist - app_id, app_version, a salted instance id (sha256 of <codex home>/telemetry-salt and
    the machine name), event_type consultation, severity, the outcome class, details {engine,
    provider (wave 28b, D1: the vendor class of the endpoint, never the roster label), model (wave
    28c, D1: an entry of that vendor's closed list, else other), purpose, outcome, wall_seconds, tokens {in, cached, out}, findings
    counts, structured, format_retry, denial_retry, timeout_continue, panel_size, ps_version, os,
    bridge_version}, tags, client_time (UTC), os, runtime; NEVER a task name, brief, prompt, path,
    thread id, finding text, key, provider label, user name or the machine name - goes to <codex
    home>/telemetry-spool/<yyyy-mm-dd>.ndjson (the local date; at the commit with at most 1 s,
    else for up to 5 s after the write lock is released - wave 28c D7; one not spooled then is a
    warning and is counted), and ONE detached sender (codex-telemetry.ps1 -Flush,
    hidden, without the host markers; a panel starts it once when every member is done) delivers
    it to the intake (CODEX_CONSULT_TELEMETRY_URL, else https://xelth.com/T) - never waited for,
    never failing a run. CODEX_CONSULT_TELEMETRY=off (or -Telemetry off for one run) writes and
    sends nothing. The first real run after an install prints a five-line notice once (marker
    <codex home>/telemetry-notice-<version>); the dry run prints `telemetry   : on|off`, the
    SessionStart hook's pointer line ends `; telemetry: on|off`. -Task <t> -Complain "<text>"
    [-Contact <c>] [-Yes] prints the complaint's exact payload (the text, the task's last entry
    through the same allowlist), asks `send? [y/N]` unless -Yes and prints the public_ref - or
    keeps it in the spool (exit 0 delivered, 1 refused or not confirmed, 3 not delivered). State:
    codex-telemetry.ps1 -Status; delete my data: codex-telemetry.ps1 -Forget -PublicRef <ref> | -Local
    (both: the intake first, the local data only after it confirmed - wave 28c D2).

    Invariants:
      * read-only sandbox by default; danger-full-access is refused outright
      * every exec-level option must precede the fork|resume subcommand
      * the prompt travels on stdin ('-'), never as an argument
      * the model and the provider are the resolved ones and are passed
        explicitly (-m, -c model_provider=...) whenever they are known
      * one consultation per task directory at a time (a -Panel run counts as one:
        it holds the lock for all its members): <task>/.consult.lock is a
        permanent file held open while a run lasts (never delete it to "unlock";
        closing the process releases it). <task>/.consult.pending.json (a panel
        member: .consult.pending-<NN>.json) exists only while a run is in
        progress or after one was interrupted; the next run checks every one and
        refuses while the bridge that wrote it or its codex process may still be
        running. findings.json and sessions.json change only under
        <task>/.consult.write.lock (re-read, own delta, write). One Codex thread
        belongs to one task directory (not enforced).

    Runs on Windows PowerShell 5.1 and on PowerShell 7 (pwsh) for macOS/Linux.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 `
        -Task cache-rewrite -Mode fork -Purpose acceptance `
        -Brief .collab/cache-rewrite/handoffs/03-claude-invalidation.md `
        -Prompt "Judge the invalidation strategy." -ReplyName invalidation

.EXAMPLE
    pwsh -NoProfile -File codex-consult.ps1 -Task cache-rewrite -DryRun `
        -Prompt "Sanity-check the plan."

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 `
        -Task cache-rewrite -Provider ZAI -Model glm-5.3 -Purpose diff-review `
        -Brief .collab/cache-rewrite/handoffs/05-claude-diff.md -OffPeakOnly

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 `
        -Task cache-rewrite -Panel -Purpose acceptance -ReplyName acceptance `
        -Brief .collab/cache-rewrite/handoffs/07-claude-acceptance.md

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 `
        -Task cache-rewrite -Panel -Purpose acceptance -ReplyName acceptance -Detach `
        -Brief .collab/cache-rewrite/handoffs/07-claude-acceptance.md
    # later - 3f2a9c1b is the id -Detach printed:
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 -Task cache-rewrite -Status -Id 3f2a9c1b
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 -Task cache-rewrite -Wait -Id 3f2a9c1b

.EXAMPLE
    # a host without skills: the coordinator's rules, the consultation procedure
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 -Explain coordinate
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 -Explain consult
#>
[CmdletBinding()]
param(
    # Task id -> <CollabDir>/<Task>/ . Groups one conversation's briefs, replies and ledger.
    # Required (every form but -Explain). (wave 27) Not declared Mandatory: parameter sets would
    # end the automatic positional binding every parameter has; a missing -Task is refused below.
    [string]$Task = '',

    # Where consultations are stored. Relative paths resolve against the git repo root.
    [string]$CollabDir = '.collab',

    # new | resume | fork. Default: fork when a thread of this run's lineage is known,
    # otherwise new.
    [string]$Mode = '',

    # Thread (session) uuid for resume/fork: a thread of THIS task's ledger recorded by
    # 0.3.0 or later with the same lineage and endpoint. Default: the newest such thread.
    # With a reviewer roster and no -Provider, the thread's reviewer is used.
    [string]$Thread = '',

    # Path to an existing Markdown brief. This script never writes briefs.
    [string]$Brief = '',

    # Short one-line ask, prepended to the prompt.
    [string]$Prompt = '',

    # Codex model. Empty (the default): the model of the roster entry used, else the
    # top-level model of the Codex config (passed as -m when it can be read). Without
    # -Provider and with a roster: only the roster entries of this model are walked.
    [string]$Model = '',

    # framing | decision | checkpoint | core-contract | acceptance | diff-review | stuck |
    # chore. Sets the default effort and word cap and adds a purpose paragraph to the prompt.
    # chore (a bounded search or extraction task) is a plain-text reply like -Raw.
    [string]$Purpose = '',

    # low | medium | high | xhigh. Empty (the default): the purpose preset.
    [string]$Effort = '',

    # read-only | workspace-write. danger-full-access is refused.
    [string]$Sandbox = 'read-only',

    # Word cap requested from Codex (reply_markdown only; findings are never cut to
    # fit it). 0 (the default): the purpose preset.
    [int]$MaxWords = 0,

    # Hard wall-clock limit of the main turn; the process tree is killed when it is exceeded.
    # Unset (the default): the purpose's default (wave 24) - chore 600, checkpoint and none
    # 900, framing and decision 1800, diff-review, core-contract and stuck 2400, acceptance
    # 3600 s. Ledger timeout_sec and timeout_source (purpose | explicit).
    [int]$TimeoutSec = 0,

    # The budget of the ONE continuation turn after the main turn was killed on its timeout
    # (wave 24): the same thread, a "finish now" prompt. -1 (the default) = the smaller of the
    # timeout and 900 s; 0 = no continuation. Ledger continue_sec and timeout_continue.
    [int]$ContinueSec = -1,

    # diff-review and acceptance only (wave 24): the git revision range under review, base..head
    # or base...head (e.g. a1b2c3d..HEAD; a single revision is refused - wave 24b). `git diff
    # --shortstat <range>` runs once: its numbers go into the prompt and the ledger (range), and
    # a range of more than 1500 lines with a timeout below 2400 s warns. An unknown range is
    # refused before anything starts.
    [string]$Range = '',

    # Slug for the reply file: handoffs/<NN>-codex-<slug>.md
    [string]$ReplyName = 'reply',

    # Built artifacts (binaries, packages) to bind the review to: their SHA-256 goes
    # into the ledger. Relative to the current directory or the repo root. Several
    # paths: -Artifact a.exe,b.dll (with -File, one comma-separated string works too).
    [string[]]$Artifact = @(),

    # 0.1-style plain-text consultation: no --output-schema, no findings bookkeeping.
    [switch]$Raw,

    # Explicit path to the codex launcher. Env override: CODEX_CONSULT_EXE.
    [string]$CodexExe = '',

    # A [model_providers.<name>] table of the Codex config (case-sensitive; 'openai' is
    # built in). Empty (the default): the first available entry of the reviewer roster when
    # one exists, else the config's model_provider, else openai. Needs -Model (unless the
    # roster entry of that provider names a model).
    [string]$Provider = '',

    # Reasoning effort sent verbatim as -c model_reasoning_effort="<value>" (no effort
    # vocabulary applied; ledger effort_mapping 'native'). Excludes -Effort.
    [string]$NativeEffort = '',

    # Refuse to start inside the provider's peak window (CODEX_CONSULT_PEAK_<PROVIDER>),
    # and when no schedule is known. Without it a peak window only warns.
    [switch]$OffPeakOnly,

    # Skip the credential preflight (codex login status / the provider's env_key); the
    # ledger records preflight "skipped". For endpoints that need no credentials. With a
    # roster: its first entry is taken unchecked (-Panel: every entry).
    [switch]$SkipPreflight,

    # Extra Codex config overrides for this run only, each key=value (ONE comma-separated string; the parameter cannot be repeated - powershell -File binds it once, or one
    # comma-separated string): passed as `-c key=value` after the bridge's own -c options.
    # E.g. -CodexConfig model_catalog_json=~/.codex/model-catalogs.json. A value that is
    # not a TOML literal is wrapped in double quotes. Keys that would change what the
    # ledger records (model, model_provider, profile, model_reasoning_effort,
    # model_providers.*) are refused.
    [string[]]$CodexConfig = @(),

    # How the reply schema reaches the endpoint for this run: output-schema (passed as
    # --output-schema) or prompt-only (the schema travels in the prompt, the reply is
    # validated locally). Empty (the default): what capability table caps-v1 declares for
    # the endpoint. Not with -Raw. Ledger schema_transport_source '-SchemaTransport'.
    [string]$SchemaTransport = '',

    # Format repair (structured mode): 1 (the default) = when the reply is substantive
    # prose instead of the JSON object, ONE extra turn resumes the same thread and asks
    # for the same content as JSON (no --output-schema, lowest effort, no brief); 0 = off.
    # Ignored with -Raw and -Purpose chore. Ledger format_retry.
    [int]$FormatRetry = 1,

    # Review panel: the same brief goes to the reviewers of the roster the panel seats (wave 26:
    # the purpose's size - -PanelSize -, drawn by the ratings - -PanelOrder), each as a
    # consultation of its own in a process of its own (own preflight, recovery record,
    # parent thread, handoff files handoffs/NN-codex-<ReplyName>-<provider>.md and ledger
    # entry with a `panel` record); members of different endpoints run at once (see
    # -PanelConcurrency). Needs a roster; not with -Provider, -Thread or -Mode resume. A
    # "weighty" roster entry joins only on framing, decision, core-contract, acceptance and
    # stuck; a "light" one stands in on those only when no other entry of its label runs. Exit 0
    # only when every member produced a usable reply.
    [switch]$Panel,

    # -Panel with every eligible entry (no size), "weighty" and "light" ones included whatever the
    # purpose.
    [switch]$PanelAll,

    # INTERNAL: set by -Panel for each member run (the member and the panel's parameters,
    # base64 of UTF-8 JSON). Never pass it yourself.
    [string]$PanelSpec = '',

    # -Panel only: how many members may run at the same time, on top of the per-endpoint plan
    # (the members of one endpoint run one after another unless the roster's "parallel" raises
    # it). 0 (the default) = no cap; 1 = strictly one after another in roster order (a member
    # that leaves surviving processes then stops the rest); k = at most k at a time.
    [int]$PanelConcurrency = 0,

    # (wave 26, R14) -Panel only: how many members the panel starts (n >= 1; capped at the
    # eligible members, raised to the required ones). 0 (the default) = the purpose's size: chore,
    # none and checkpoint 1, diff-review 2, framing and decision 3, core-contract and acceptance 4,
    # stuck every eligible member. Not with -PanelAll (every eligible member).
    [int]$PanelSize = 0,

    # (wave 26, R15) -Panel only: routed (the default) = the seats are drawn by the reviewers'
    # usefulness ratings (-Rate) with a lab-diversity reserve and 20 % exploration - in roster
    # order while no eligible reviewer has 3 ratings in 90 days (ledger panel.routing.fallback);
    # roster = the roster order, no draw.
    [string]$PanelOrder = '',

    # (wave 26, D4) -Panel only: the nonce of the routing seed (a number or a token); default
    # CODEX_CONSULT_TEST_PANEL_SEED, else today's UTC date - a dry run and the real run of the
    # same day draw the same seats.
    [string]$PanelSeed = '',

    # (wave 26, R15) the topics of this consultation (slugs, e.g. -Topic security,tests): ledger
    # topics[], copied onto a rating; a routed panel scores its members on them.
    [string[]]$Topic = @(),

    # (wave 26, D7) reviewers that MUST take part - -Panel, or a single run with -Provider: a
    # roster position (#5), a provider label (every entry of it) or '<provider> :: <model>'
    # [' [<engine>]'], comma-separated. A required reviewer that is not available refuses the run
    # before anything starts (exit 5); in a panel it takes a seat first, and its failure after
    # the start stops the panel at the next member (exit 5). Default: the roster's "require" for
    # the purpose (a panel); -Require none drops it.
    [string[]]$Require = @(),

    # (wave 26, R16) a role for the reviewer (a single run) or for every member (-Panel): the
    # block <CollabDir>/roles/<name>.md, else the plugin's templates/role-<name>.md (edge-cases,
    # security, tests, docs), goes into the prompt after the ask. Not with -Roles.
    [string]$Role = '',

    # (wave 26, R16) -Panel only: roles for the members, by score rank (a member's roster
    # "roles" says which it is willing to take); at most one per member. Not with -Role.
    [string[]]$Roles = @(),

    # The CLI that carries the consultation: codex | agy | muse. Empty (the default): the engine of
    # the roster entry used (the thread's with -Thread), else codex. With a roster and no
    # -Provider/-Thread, only the entries of that engine are walked (-Panel: members).
    [string]$Engine = '',

    # Explicit path to the launcher of the SELECTED engine other than codex (wave 23, D3):
    # -Engine's; without -Engine the engine of the -Provider's roster entry, else the only such
    # engine among the roster's entries (several: pass -Engine). Env overrides:
    # CODEX_CONSULT_AGY_EXE, CODEX_CONSULT_MUSE_EXE. (codex: -CodexExe)
    [string]$EngineExe = '',

    # muse only (wave 23, D9): the model-step cap, sent as --max-model-steps <n> (a positive
    # integer); 0 (the default) = not sent - the muse CLI's own default applies. The bridge's
    # -TimeoutSec stays the outer bound. Refused with another engine; a -Panel passes it to its
    # muse members. Ledger engine_run.max_model_steps.
    [int]$MaxModelSteps = 0,

    # agy only: 1 (the default) = a run that produced nothing because a tool was auto-denied
    # (headless print mode cannot grant it) gets ONE more turn on the same conversation that
    # tells the model not to call it again; 0 = off. Ledger denial_retry. (muse has none: its
    # write, shell and web tools are disabled.)
    [int]$DenialRetry = 1,

    # Print the plan (argv, prompt, paths, ledger entry) without calling codex and
    # without writing anything.
    [switch]$DryRun,

    # (wave 25, R12) Non-blocking: check the consultation here like a real run (the dry run's
    # checks plus a real run's refusals before its lock), then run it in a BACKGROUND process and
    # return at once, printing the detach id, the status file
    # (<task>/.consult.detached-<id8>.status.json) and how to come back (-Status / -Wait). A single
    # run or -Panel; not with -DryRun, -Status, -Wait.
    [switch]$Detach,

    # (wave 25) Print the detached runs of the task (newest first; -Id: one): the state, one line
    # per member and, once done, the summary block the run printed. Exit 0 all done and usable, 1 a
    # failure (a died run too), 2 still running, 4 the query is refused. Takes only -Task,
    # -CollabDir, -Id, -Prune. Reads status files only.
    [switch]$Status,

    # (wave 25) With -Status or -Wait: one detached run - its detach id or the beginning of it (the
    # 8 hex digits -Detach prints). Empty (the default): every detached run of the task.
    [string]$Id = '',

    # (wave 25) Wait until the detached run(s) are done (or their background is gone), checking
    # every 2 s, then print as -Status. Exit 3 when still running after -WaitTimeoutSec.
    [switch]$Wait,

    # (wave 25) -Wait's limit in seconds. 0 (the default) = the run's own budget (budget_sec of its
    # status file; several runs: the largest).
    [int]$WaitTimeoutSec = 0,

    # (wave 25) With -Status: delete the status file and the log of every detached run that is
    # done or died and was last written more than 7 days ago (the one writing form of -Status).
    [switch]$Prune,

    # INTERNAL (wave 25): set by -Detach for its background process. Never pass it yourself.
    [string]$DetachId = '',

    # (wave 26b, D12 - ROADMAP R18) The stall cut: a run whose engine event stream (codex --json
    # items, agy stream-json, muse MSP records) produced no event for this many seconds while its
    # process lives is stopped like a timeout - the continuation turn and the salvage; bridge_outcome
    # "failed: stalled after N s without an event (process tree killed)", ledger stall {seconds,
    # last_event}. -1 (the default) = the roster entry's stall_sec, else 900; 0 = off. A panel
    # passes it to every member (an explicit value wins over the roster's).
    [int]$StallSec = -1,

    # (wave 26b, D10) Stop ONE running member of a panel (or a single run) of -Task by its handoff
    # number: -Kick -Member <NN> [-Id <id8> of a detached run]. Writes <task>/.consult.kick-<NN>;
    # the member stops its engine's process tree, salvages the partial output (.partial.md) and
    # records "failed: stopped by the operator (-Kick)" (class operator); the panel goes on with the
    # others. (wave 26c, D1) Waits up to 10 s for the member's acknowledgement (<kick file>.ack).
    # Exit 0 acknowledged, 1 no such member or not running, 3 no acknowledgement in time (4: the
    # query is refused).
    [switch]$Kick,

    # (wave 26b, D10) -Kick only: the member's handoff number (NN, as the panel prints it).
    [string]$Member = '',

    # (wave 27, R13 D6) The coordinator's brief prefix: its briefs are named
    # handoffs/<NN>-<prefix>-<slug>.md (a lowercase slug). Empty (the default): the environment
    # variable CODEX_CONSULT_BRIEF_PREFIX, else claude - the name every install's ledgers already
    # use. A reply prefix of the bridge (codex, agy, muse) is refused before anything starts. The
    # dry run shows it; the bridge never writes a brief.
    [string]$BriefPrefix = '',

    # (wave 27, R13 D5) coordinate | consult | providers: print the text of the plugin's skill
    # coordinate, consult-codex or setup-providers (its SKILL.md without the front matter, UTF-8)
    # for a host without skills, and exit 0. Read-only; takes no other parameter (not even -Task).
    [string]$Explain = '',

    # (wave 28, R17) on | off for this run: ONE anonymised event per consultation to the
    # maintainer's intake (README "Telemetry (on by default)"). Empty (the default):
    # CODEX_CONSULT_TELEMETRY, else on. A panel passes it to its members.
    [string]$Telemetry = '',

    # (wave 28, R17) A complaint or a suggestion to the maintainer: -Task <t> -Complain "<text>"
    # [-Contact <how to reach you>] [-Yes]. The payload - the text, the task's last ledger entry
    # through the event's allowlist, the plugin version, the OS - is printed in full, then `send?
    # [y/N]` unless -Yes; the public_ref is printed, or it is kept in the spool. Takes only -Task,
    # -CollabDir, -Contact, -Yes. Exit 0 delivered, 1 refused or not confirmed, 3 not delivered (kept).
    [string]$Complain = '',

    # (wave 28) With -Complain: how the maintainer can reach you (optional).
    [string]$Contact = '',

    # (wave 28) With -Complain: send without asking.
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

# ----------------------------------------------------------------------------- -Explain (wave 27, R13 D5)
# A host without skills reads the plugin's skills through the bridge itself: the SKILL.md of
# coordinate, consult-codex or setup-providers without its front matter, after one line naming the
# file and the plugin directory (`${CLAUDE_PLUGIN_ROOT}` in the text is that directory). UTF-8 bytes
# on stdout whatever the console's code page; nothing else is read or written; exit 0.
if ($PSBoundParameters.ContainsKey('Explain')) {
    $explainCommon = @([System.Management.Automation.Cmdlet]::CommonParameters) + @([System.Management.Automation.Cmdlet]::OptionalCommonParameters)
    $explainOthers = @($PSBoundParameters.Keys | Where-Object { $_ -ne 'Explain' -and $explainCommon -notcontains $_ })
    if ($explainOthers.Count -gt 0) { Stop-WithError "-Explain takes no other parameter (got -$($explainOthers -join ', -'))." }
    $explainSkills = @{ coordinate = 'coordinate'; consult = 'consult-codex'; providers = 'setup-providers' }
    $explainKey = ([string]$Explain).Trim().ToLowerInvariant()
    if (-not $explainSkills.ContainsKey($explainKey)) { Stop-WithError "-Explain takes coordinate, consult or providers (got '$Explain')." }
    $explainRoot = Split-Path -Parent $PSScriptRoot
    $explainPath = Join-Path (Join-Path (Join-Path $explainRoot 'skills') $explainSkills[$explainKey]) 'SKILL.md'
    if (-not (Test-Path -LiteralPath $explainPath -PathType Leaf)) { Stop-WithError "-Explain $($explainKey): '$explainPath' does not exist (an incomplete plugin directory)." }
    $explainBody = [IO.File]::ReadAllText($explainPath, $script:Utf8NoBom)
    if ($explainBody -match '\A---\r?\n[\s\S]*?\r?\n---\r?\n') { $explainBody = $explainBody.Substring($Matches[0].Length) }
    # (wave 27c, D13 / F32-9) runnable as written on a host that substitutes nothing: every
    # ${CLAUDE_PLUGIN_ROOT} of the skill text is replaced by this plugin's directory (the skills keep
    # the variable and the root sentence)
    $explainHead = "codex-consult -Explain $($explainKey): the $($explainSkills[$explainKey]) skill, $explainPath - " + '${CLAUDE_PLUGIN_ROOT}' + " in it is replaced by the plugin directory $explainRoot"
    $explainBody = $explainBody.Replace('${CLAUDE_PLUGIN_ROOT}', $explainRoot)
    $explainBytes = $script:Utf8NoBom.GetBytes($explainHead + "`n`n" + $explainBody.TrimStart("`r", "`n").TrimEnd() + "`n")
    # (wave 27c, D15 / F32-11) the stream flushed AND disposed
    $explainOut = [Console]::OpenStandardOutput()
    try {
        $explainOut.Write($explainBytes, 0, $explainBytes.Length)
        $explainOut.Flush()
    } finally { $explainOut.Dispose() }
    exit 0
}
# Every other form needs -Task (it was a Mandatory parameter - that prompted instead of refusing).
if (-not $Task) { Stop-WithError "-Task <id> is required (a slug: the task directory <CollabDir>/<id>/); the one form without it is -Explain coordinate|consult|providers." }

# ----------------------------------------------------------------------------- non-blocking consultation (wave 25, R12)
#
# -Detach (ROADMAP R12; decisions D1-D12 of its design round): the FOREGROUND - this process, as
# the coordinator started it - makes every check a real run makes before it takes the task lock
# (the dry run's checks, and the refusals a dry run only reports: the launcher of every engine
# that will run, an active recovery record, the preflight - D2), writes the status file once,
# state `starting` (Start-DetachedRun), starts the BACKGROUND and exits 0. Not checked in the
# foreground: the task lock and the time-dependent health/peak selection - a benign window: the
# background is refused then, and its status says so (D3).
# The BACKGROUND is `<this host> -File codex-consult.ps1 -Task <t> -CollabDir <absolute> -DetachId
# <guid>` in the caller's working directory (D8), its stdout and stderr in the log, started so
# that it holds none of the caller's handles: Windows - cmd.exe /c with the redirection, through
# ShellExecute, hidden; elsewhere - /bin/sh -c 'exec nohup ...'. Its first action is the self-
# report `running` {pid, start_time, host} (D5), then UTF-8 console output (D10), then the
# consultation itself IN THIS PROCESS with the foreground's arguments (the `starting` record's
# `args`), inside a try/finally that writes the final status {done, exit, summary} whatever the
# run did (D3). The run keeps its members' states in the file as they start and finish (D11), and
# Stop-WithError records a refusal before it exits ($script:StopWithErrorHook).
# -Status / -Wait read status files only (-Prune, the one writing form, deletes old ones): no
# lock, no roster, no launcher (D6, D7).

# This script's path (a function of the dot-sourced common file sees THAT file in $PSCommandPath).
$script:SelfPath = $PSCommandPath
# The parameters of this call (inside a function $PSBoundParameters is the function's own).
$script:ScriptBound = @{}
foreach ($bk in $PSBoundParameters.Keys) { $script:ScriptBound[$bk] = $PSBoundParameters[$bk] }
$script:CommonParameterNames = @([System.Management.Automation.Cmdlet]::CommonParameters) + @([System.Management.Automation.Cmdlet]::OptionalCommonParameters)
# The detached run this process is ({ Path; Record }) - set below when -DetachId names it.
$script:DetachRun = $null
# The summary block a run prints (Write-Summary); a detached run's status file keeps it (D3).
$script:SummaryLines = New-Object System.Collections.Generic.List[string]

# One line of the run's summary block: printed, and kept for a detached run's status file.
function Write-Summary {
    param([string]$Text = '', [string]$Color = '')
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
    $script:SummaryLines.Add($Text)
}

# (wave 26, F08-2) A TERMINAL status write (the run's own final write, the background's
# confirmation): up to 3 attempts, 250 ms apart. Returns '' when written, else the last error.
function Write-DetachedStatusRetry {
    param([string]$Path, $Record)
    $last = ''
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try { Write-DetachedStatus -Path $Path -Record $Record; return '' } catch { $last = ConvertTo-OneLine $_.Exception.Message }
        if ($attempt -lt 3) { Start-Sleep -Milliseconds 250 }
    }
    return $last
}

# Writes this detached run's status file. Best effort: a status write never stops the run
# (-Final: the terminal write, retried - Write-DetachedStatusRetry).
function Save-DetachedRun {
    param([switch]$Final)
    if (-not $script:DetachRun) { return }
    if ($Final) {
        $why = Write-DetachedStatusRetry -Path $script:DetachRun.Path -Record $script:DetachRun.Record
        if ($why) { Write-Host "codex-consult: could not write the final status to $($script:DetachRun.Path) ($why)" -ForegroundColor Yellow }
        return
    }
    try { Write-DetachedStatus -Path $script:DetachRun.Path -Record $script:DetachRun.Record } catch {
        Write-Host "codex-consult: could not update the status file $($script:DetachRun.Path) ($(ConvertTo-OneLine $_.Exception.Message))" -ForegroundColor Yellow
    }
}

# The members of this detached run - all of them (a panel once its numbers are assigned, a single
# run once its reviewer and numbers are known), saved.
function Set-DetachedMembers {
    param([object[]]$Members)
    if (-not $script:DetachRun) { return }
    $script:DetachRun.Record.members = [object[]]@($Members | Where-Object { $_ })
    Save-DetachedRun
}

# Fields of one member of this detached run (by roster position), saved unless -NoSave.
function Set-DetachedMember {
    param([int]$Position, [hashtable]$Values, [switch]$NoSave)
    if (-not $script:DetachRun) { return }
    $m = @($script:DetachRun.Record.members | Where-Object { $_ -and [int]$_.position -eq $Position }) | Select-Object -First 1
    if (-not $m) { return }
    foreach ($k in $Values.Keys) { $m.$k = $Values[$k] }
    if (-not $NoSave) { Save-DetachedRun }
}

# The run's own final status (D3), right before it exits: done, the exit code, the summary block
# it printed (Write-Summary) - else $Line. The background confirms it after the run returned.
function Set-DetachedFinal {
    param([int]$Exit, [string]$Line = '')
    if (-not $script:DetachRun) { return }
    $summary = $Line
    if ($script:SummaryLines.Count -gt 0) { $summary = $script:SummaryLines.ToArray() -join "`n" }
    Complete-DetachedRecord -Record $script:DetachRun.Record -Exit $Exit -Summary $summary
    Save-DetachedRun -Final
}

# The background's final write (D3), after the run returned or threw: the status file as the run
# left it (else $Fallback, the self-report), made final with the run's real exit code. (wave 26,
# F08-2) Retried (Write-DetachedStatusRetry); returns '' when written, else the error - the
# background then exits 6: the run's result exists only in its log.
function Complete-DetachedRun {
    param([string]$Path, $Fallback, [int]$Exit, [string]$Line = '')
    $rec = $Fallback
    $rd = Read-DetachedStatus -Path $Path
    if ($rd.Record -and [string]$rd.Record.id -eq [string]$Fallback.id) { $rec = $rd.Record }
    Complete-DetachedRecord -Record $rec -Exit $Exit -Line $Line
    $why = Write-DetachedStatusRetry -Path $Path -Record $rec
    if ($why) { Write-Host "codex-consult: could not write the final status to $Path ($why)" -ForegroundColor Red }
    return $why
}

# -Artifact a,b arrives as ONE string through `powershell -File`: each value is split on commas
# unless the whole value names an existing file (absolute, or relative to one of $Bases).
function Split-ArtifactArgument {
    param([string[]]$Values, [string[]]$Bases)
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($a in @($Values)) {
        if (-not $a -or -not $a.Trim()) { continue }
        $a = $a.Trim()
        $whole = -not $a.Contains(',')
        if (-not $whole) {
            if ([IO.Path]::IsPathRooted($a)) { $whole = Test-Path -LiteralPath $a -PathType Leaf }
            else {
                foreach ($base in $Bases) {
                    if (Test-Path -LiteralPath (Join-Path $base $a) -PathType Leaf) { $whole = $true; break }
                }
            }
        }
        if ($whole) { $list.Add($a) }
        else { foreach ($piece in $a.Split(',')) { if ($piece.Trim()) { $list.Add($piece.Trim()) } } }
    }
    return , ([string[]]$list.ToArray())
}

# The foreground of -Detach once every check passed (D1, D5, D8): picks the detach id, writes the
# `starting` record ONCE, starts the background, prints three lines and exits 0 - or refuses (exit
# 1) with nothing left behind. $Members: the planned members (pending; a roster-skipped entry
# skipped); $Budget: D4; $Plan: what runs; $BriefFull, $ArtifactFull: absolute (D8); $Warnings:
# what a real run prints before it starts. Reads the run's variables ($taskDir, $collabRoot,
# $callerCwd, $Task, $Purpose, $ReplyName).
function Start-DetachedRun {
    param([string]$Kind, [object[]]$Members, [int]$Budget, [string]$Plan, [string]$BriefFull = '', [string[]]$ArtifactFull = @(), [string[]]$Warnings = @())
    # The background's arguments: this call's, minus -Detach, with the paths absolute (D8).
    $bgArgs = @{}
    foreach ($k in $script:ScriptBound.Keys) {
        if ($k -eq 'Detach' -or $script:CommonParameterNames -contains $k) { continue }
        $bgArgs[$k] = $script:ScriptBound[$k]
    }
    if ($BriefFull) { $bgArgs['Brief'] = $BriefFull }
    if (@($ArtifactFull).Count -gt 0) { $bgArgs['Artifact'] = [string[]]@($ArtifactFull) }
    $bgArgs['CollabDir'] = $collabRoot
    # The id: a guid whose id8 names no status or log file of the task yet (D7). TEST HOOK:
    # CODEX_CONSULT_TEST_DETACH_GUIDS=<guid>[,<guid>...] - tried first, in that order.
    $tries = New-Object System.Collections.Generic.List[string]
    foreach ($g in ((Get-TestHookValue 'CODEX_CONSULT_TEST_DETACH_GUIDS')).Split(',')) {
        if ($g.Trim() -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { $tries.Add($g.Trim().ToLowerInvariant()) }
    }
    for ($i = 0; $i -lt 16; $i++) { $tries.Add([guid]::NewGuid().ToString()) }
    try { [void][IO.Directory]::CreateDirectory($taskDir) } catch { Stop-WithError "could not create the task directory '$taskDir' ($(ConvertTo-OneLine $_.Exception.Message)); nothing was started." }
    $newId = ''
    $paths = $null
    foreach ($cand in $tries) {
        $p = Get-DetachedPaths -TaskDir $taskDir -Id $cand
        if ((Test-Path -LiteralPath $p.Status) -or (Test-Path -LiteralPath $p.Log) -or (Test-Path -LiteralPath $p.Prompt)) { continue }
        $newId = $cand
        $paths = $p
        break
    }
    if (-not $newId) { Stop-WithError "no free detach id for task '$Task' (the status or log file of every candidate exists); nothing was started." }
    # (wave 26, F11-2) an inline -Prompt goes to <task>/.consult.detached-<id8>.prompt.txt (UTF-8,
    # gitignored like the log); the record's args name only that file (PromptFile), so a run that
    # never starts leaves no prompt text in its status file - the background reads the file and
    # removes it; -Status -Prune removes a left-over one with the run's other files
    $promptFile = ''
    if ($bgArgs.ContainsKey('Prompt') -and [string]$bgArgs['Prompt']) {
        $promptFile = $paths.Prompt
        try { Write-Utf8NoBom -Path $promptFile -Text ([string]$bgArgs['Prompt']) } catch {
            Stop-WithError "could not write the prompt file '$promptFile' ($(ConvertTo-OneLine $_.Exception.Message)); nothing was started."
        }
        $bgArgs.Remove('Prompt')
        $bgArgs['PromptFile'] = $promptFile
    }
    # The background's command line.
    $hostExe = (Get-Process -Id $PID).Path
    $bgLine = ''
    if ($script:OnWindows) {
        # cmd.exe would expand a %NAME% in these paths: refused rather than corrupted
        foreach ($pth in @($hostExe, $script:SelfPath, $collabRoot, $paths.Log)) {
            if ($pth.Contains('%')) { Stop-WithError "-Detach starts its background through cmd.exe, which would expand the '%' in '$pth'; run without -Detach; nothing was started." }
        }
        $collabArg = $collabRoot
        # a trailing backslash would escape the closing quote
        if ($collabArg.EndsWith('\')) { $collabArg += '.' }
        $inner = '"' + $hostExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $script:SelfPath + '" -Task ' + $Task + ' -CollabDir "' + $collabArg + '" -DetachId ' + $newId + ' <NUL 1>"' + $paths.Log + '" 2>&1'
        $bgLine = '/d /v:off /s /c "' + $inner + '"'
    } else {
        $q = { param([string]$s) "'" + $s.Replace("'", "'\''") + "'" }
        $bgLine = 'exec nohup ' + (& $q $hostExe) + ' -NoProfile -File ' + (& $q $script:SelfPath) + ' -Task ' + (& $q $Task) + ' -CollabDir ' + (& $q $collabRoot) + ' -DetachId ' + $newId + ' </dev/null >' + (& $q $paths.Log) + ' 2>&1'
    }
    # The `starting` record, written ONCE, before the background exists (D5).
    $rec = ConvertTo-DetachedRecord @{
        status_version = $script:DetachedStatusVersion; id = $newId; id8 = $paths.Id8; task = $Task; kind = $Kind; state = 'starting'
        started = (Get-IsoTimestamp); host = [Environment]::MachineName; budget_sec = $Budget; purpose = $Purpose; reply_name = $ReplyName
        brief = $BriefFull; members = [object[]]@($Members | Where-Object { $_ }); log = $paths.Log; args = (ConvertTo-DetachArgs -Arguments $bgArgs)
        # (wave 27, R13) the coordinator resolved here and the markers the background never gets
        coordinator = $coordinatorRecord; child_env_scrubbed = [object[]]@($childEnvScrubbed)
    }
    try { Write-DetachedStatus -Path $paths.Status -Record $rec } catch {
        $why = ConvertTo-OneLine $_.Exception.Message
        if ($promptFile) { $null = Remove-PendingFile -Path $promptFile }
        Stop-WithError "could not write the status file '$($paths.Status)' ($why); nothing was started."
    }
    # (wave 27, R13 D4) the background (and so every engine child of it) starts without the
    # coordinator's host markers; this process gets them back right after the start
    $bgHidden = $null
    try {
        $bgHidden = Hide-HostMarkers
        if ($script:OnWindows) {
            $cmdExe = [string]$env:ComSpec
            if (-not $cmdExe) { $cmdExe = 'cmd.exe' }
            # ShellExecute (no -NoNewWindow, no redirection here): the background inherits none of
            # this process's handles, so the caller's pipes close when this process exits
            $null = Start-Process -FilePath $cmdExe -ArgumentList $bgLine -WorkingDirectory $callerCwd -WindowStyle Hidden -PassThru
        } else {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = '/bin/sh'
            [void]$psi.ArgumentList.Add('-c')
            [void]$psi.ArgumentList.Add($bgLine)
            $psi.UseShellExecute = $false
            $psi.WorkingDirectory = $callerCwd
            # (wave 27c, D4) the block must come out clean, else the start is refused
            $scrub = Remove-HostMarkersFromStartInfo $psi -KeepTestVars
            if ($scrub) { throw "host markers could not be hidden ($scrub)" }
            $null = [System.Diagnostics.Process]::Start($psi)
        }
    } catch {
        Restore-HostMarkers -Saved $bgHidden
        $bgHidden = $null
        $why = ConvertTo-OneLine $_.Exception.Message
        $rmError = Remove-PendingFile -Path $paths.Status
        if ($promptFile) { $null = Remove-PendingFile -Path $promptFile }
        Stop-WithError "could not start the background process ($why); nothing was started$(if ($rmError) { " (the status file '$($paths.Status)' could not be removed: $rmError)" })."
    }
    Restore-HostMarkers -Saved $bgHidden
    foreach ($w in @($Warnings | Where-Object { $_ -and $_ -ne $script:TestModeWarning })) { Write-Host "WARNING: $w" -ForegroundColor Yellow }
    $collabOpt = $(if ($script:ScriptBound.ContainsKey('CollabDir')) { " -CollabDir `"$collabRoot`"" } else { '' })
    Write-Host "Detached $($paths.Id8): $Plan - it runs in the background (detach id $newId; budget $Budget s)."
    Write-Host "status file: $($paths.Status) (console output: $($paths.Log))"
    Write-Host "come back  : codex-consult.ps1 -Task $Task$collabOpt -Status -Id $($paths.Id8) (exit 0 done and usable, 1 a failure, 2 still running); -Wait -Id $($paths.Id8) waits until it is done (default: its budget, $Budget s)"
    # (wave 28b, D10) the test-mode line after the detach lines (the first line stays "Detached <id8>: ...")
    if (@($Warnings) -contains $script:TestModeWarning) { Write-Host "WARNING: $($script:TestModeWarning)" -ForegroundColor Yellow }
    exit 0
}

# -Status and -Wait refuse a query with exit 4 - never mistaken for a run's result (D7).
function Stop-StatusQuery {
    param([string]$Message)
    Write-Host "codex-consult: $Message" -ForegroundColor Red
    exit 4
}

# The -Status report of detached runs (newest first): per run its state, one line per member and,
# when it is done, the summary block the run printed - verbatim.
function Write-DetachedReport {
    param([object[]]$Runs, [DateTimeOffset]$Now = [DateTimeOffset]::Now)
    $first = $true
    foreach ($run in @($Runs)) {
        if (-not $first) { Write-Host '' }
        $first = $false
        $j = Get-DetachedJudgement -Record $run.Record -Problem ([string]$run.Error) -Now $Now
        $rec = $run.Record
        if (-not $rec) {
            Write-Host "detached $($run.Id8): $($j.Text)"
            # (wave 26, F07-1) how it goes away: -Status -Prune 7 days after its last write, or by hand
            $fileAge = $null
            try { $fileAge = $Now - [DateTimeOffset]([IO.File]::GetLastWriteTimeUtc($run.Path)) } catch { }
            if ($fileAge -and $fileAge.TotalDays -ge $script:DetachedPruneDays) { Write-Host "  -Status -Prune removes it (last written $(Format-DetachedSpan $fileAge) ago)" }
            else { Write-Host "  -Status -Prune removes it $($script:DetachedPruneDays) days after its last write; to remove it now: Remove-Item -LiteralPath '$($run.Path)', '$($run.Log)' (the log may say what happened)" }
            continue
        }
        $what = $(if ($rec.kind -eq 'panel') { 'review panel' } else { 'single run' })
        if ($rec.purpose) { $what += ", purpose $($rec.purpose)" }
        if ($rec.reply_name) { $what += ", reply name $($rec.reply_name)" }
        Write-Host "detached $($run.Id8) ($what): $($j.Text)"
        $pidText = $(if ($rec.pid) { "pid $($rec.pid) on $($rec.host)" } else { "no background pid yet (host $($rec.host))" })
        $wallText = $(if ($j.State -eq 'done' -and $null -ne $rec.wall_seconds) { "; wall $($rec.wall_seconds) s" } else { '' })
        Write-Host "  detach id $($rec.id), started $($rec.started), $pidText; budget $($rec.budget_sec) s$wallText"
        foreach ($m in @($rec.members | Where-Object { $_ })) {
            $outcome = [string]$m.outcome
            if ($outcome.StartsWith("$($m.state): ")) { $outcome = $outcome.Substring(([string]$m.state).Length + 2) }
            if ($outcome -eq [string]$m.state) { $outcome = '' }
            $details = New-Object System.Collections.Generic.List[string]
            if ($null -ne $m.n) { $details.Add("n=$($m.n)") }
            if ($m.handoff) { $details.Add("handoff $($m.handoff)") }
            if ($null -ne $m.wall_seconds) { $details.Add("$($m.wall_seconds) s") }
            Write-Host ("  #{0} {1} - {2}{3}{4}" -f $m.position, $m.lineage, $m.state, $(if ($outcome) { ": $outcome" } else { '' }), $(if ($details.Count -gt 0) { " ($($details.ToArray() -join ', '))" } else { '' }))
        }
        Write-Host "  log: $(if ($rec.log) { $rec.log } else { $run.Log })"
        if ($j.State -eq 'done' -and $rec.summary) {
            Write-Host ''
            foreach ($l in ([string]$rec.summary -split "`n")) { Write-Host $l }
        }
    }
}

# ---- (wave 26b, D10) -Kick -Member <NN> [-Id <id8>]: stop one running member
if ($Kick -or $script:ScriptBound.ContainsKey('Member')) {
    if (-not $Kick) { Stop-StatusQuery "-Member goes with -Kick." }
    $extra = @($script:ScriptBound.Keys | Where-Object { @('Task', 'CollabDir', 'Kick', 'Member', 'Id') -notcontains $_ -and $script:CommonParameterNames -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-StatusQuery "-Kick takes only -Task, -CollabDir, -Member and -Id; not -$(@($extra | Sort-Object) -join ', -')." }
    if ($Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Stop-StatusQuery "-Task must be a slug (letters, digits, dot, dash, underscore)." }
    if (([string]$Member).Trim() -notmatch '^[0-9]{1,4}$') { Stop-StatusQuery "-Kick needs -Member <NN>: the member's handoff number as the panel prints it (e.g. -Member 03); got '$Member'." }
    $kickNn = '{0:D2}' -f [int]([string]$Member).Trim()
    $want = $Id.Trim().ToLowerInvariant()
    if ($script:ScriptBound.ContainsKey('Id') -and $want -notmatch '^[0-9a-f][0-9a-f-]{0,35}$') { Stop-StatusQuery "-Id takes a detach id or its beginning (hexadecimal, as -Detach printed it); got '$Id'." }
    $kRepo = Resolve-RepoRoot -Cwd (Get-Location).Path
    $kCollab = Resolve-CollabRoot -RepoRoot $kRepo -CollabDir $CollabDir
    $kTaskDir = Join-Path $kCollab $Task
    $kPath = Get-KickPath -TaskDir $kTaskDir -Nn $kickNn
    # (wave 26c, D1) no such running member: exit 1, and a kick file of that number is removed
    $kickFail = { param([string]$Why) if ([IO.Directory]::Exists($kTaskDir)) { $null = Remove-PendingFile -Path $kPath }; Write-Host "codex-consult: -Kick: $Why" -ForegroundColor Red; exit 1 }
    if (-not [IO.Directory]::Exists($kTaskDir)) { & $kickFail "no task directory '$kTaskDir'." }
    # (wave 27c, D1) an acknowledgement older than 60 s (nobody's anymore) is swept first
    $null = Clear-StaleKickAck -KickPath $kPath
    # a detached run named by -Id: the member must be one of ITS members, running
    if ($want) {
        $w8 = $want.Replace('-', '')
        if ($w8.Length -gt 8) { $w8 = $w8.Substring(0, 8) }
        $kRuns = @(Read-DetachedRuns -TaskDir $kTaskDir | Where-Object { $_.Id8.StartsWith($w8) -and ($want.Length -le 8 -or ($_.Record -and ([string]$_.Record.id).ToLowerInvariant().StartsWith($want))) })
        if ($kRuns.Count -eq 0) { & $kickFail "no detached run $want in task $Task." }
        if ($kRuns.Count -gt 1) { Stop-StatusQuery "-Id $want names $($kRuns.Count) detached runs of task $($Task); give more of the id." }
        $kRec = $kRuns[0].Record
        $kMem = @(@(Get-PropertyValue $kRec 'members' @()) | Where-Object { $_ -and [string](Get-PropertyValue $_ 'handoff' '') -eq $kickNn }) | Select-Object -First 1
        if (-not $kMem) { & $kickFail "detached run $($kRuns[0].Id8) has no member with handoff $kickNn." }
        if ([string]$kMem.state -ne 'running') { & $kickFail "member $kickNn of detached run $($kRuns[0].Id8) is not running (state $($kMem.state))." }
    }
    # the run's recovery record: a member's .consult.pending-<NN>.json, a single run's .consult.pending.json
    $kItem = $null
    foreach ($p in (Get-PendingPaths -TaskDir $kTaskDir)) {
        $rd = Read-PendingFile -Path $p
        if ($rd.Exists -and $rd.Record -and [string](Get-PropertyValue $rd.Record 'nn' '') -eq $kickNn) { $kItem = $rd.Record; break }
    }
    if (-not $kItem) { & $kickFail "no run with handoff $kickNn is in progress in task $Task (no recovery record names it)." }
    $kChild = 0
    [void][int]::TryParse([string](Get-PropertyValue $kItem 'child_pid' ''), [ref]$kChild)
    if ([string]$kItem.state -ne 'running' -or $kChild -le 0 -or -not (Test-RecordedProcess -ProcessId $kChild -StartTime (ConvertTo-StartIso (Get-PropertyValue $kItem 'child_start_time' ''))).Alive) {
        & $kickFail "the run with handoff $kickNn has no engine turn running (state $($kItem.state))."
    }
    # (wave 26c, D1 / F26-1; wave 27c, D1 / F30-1, F29-2, F32-1, F30-6) THE REQUEST: written atomically
    # with an id - or, when a kick of this member is already pending, JOINED (its id taken, the file
    # never overwritten). The member acknowledges with <kick file>.ack {id, result: stopped - its turn
    # is being stopped | late - its turn had already finished, the outcome stays}. This caller waits
    # up to 10 s for an acknowledgement with ITS id; only the creator of the request removes it after
    # reading it (after a short grace, so a joiner reads it too), a joiner never.
    $kAck = "$kPath.ack"
    $kReq = New-KickRequest -KickPath $kPath
    if ($kReq.Error) { Stop-StatusQuery "-Kick: the kick request could not be written ($($kReq.Error))." }
    $kWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $kGot = $null
    while ($kWatch.Elapsed.TotalSeconds -lt 10) {
        $kRead = Read-KickRecord -Path $kAck
        if ($kRead.Exists -and $kRead.Id -and $kRead.Id -eq $kReq.Id) { $kGot = $kRead; break }
        Start-Sleep -Milliseconds 200
    }
    if (-not $kGot) {
        Write-Host "codex-consult: -Kick: the run with handoff $kickNn did not acknowledge the kick within 10 s - the kick file stays ($kPath): the member takes it at its next poll; a run that has ended leaves it to the next run of that number, which removes it." -ForegroundColor Yellow
        exit 3
    }
    if ($kReq.Created) {
        Start-Sleep -Milliseconds 1000
        if ((Read-KickRecord -Path $kAck).Id -eq $kReq.Id) { $null = Remove-PendingFile -Path $kAck }
    }
    if ($kGot.Result -eq 'late') {
        Write-Host "codex-consult: -Kick: member $kickNn of task $Task had already finished - the kick is recorded as kick_late in its warnings, its outcome unchanged."
        exit 0
    }
    Write-Host "codex-consult: -Kick: member $kickNn of task $Task stopped - it took the kick; its engine's process tree is being stopped and its partial output salvaged; it records ""failed: stopped by the operator (-Kick)"" (a format repair only: its first reply stands) - the panel goes on with the others."
    exit 0
}

# ---- (wave 28, R17) -Complain "<text>" [-Contact <c>] [-Yes]: a complaint to the maintainer's intake
if ($script:ScriptBound.ContainsKey('Complain') -or $script:ScriptBound.ContainsKey('Contact') -or $Yes) {
    if (-not $script:ScriptBound.ContainsKey('Complain')) { Stop-WithError "-Contact and -Yes go with -Complain ""<text>""." }
    $extra = @($script:ScriptBound.Keys | Where-Object { @('Task', 'CollabDir', 'Complain', 'Contact', 'Yes') -notcontains $_ -and $script:CommonParameterNames -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-WithError "-Complain takes only -Task, -CollabDir, -Contact and -Yes; not -$(@($extra | Sort-Object) -join ', -')." }
    if ($Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Stop-WithError "-Task must be a slug (letters, digits, dot, dash, underscore)." }
    # the task's last ledger entry (the highest n) - its allowlisted details are the context; none
    # when the task has no ledger yet
    $cSessions = Join-Path (Join-Path (Resolve-CollabRoot -RepoRoot (Resolve-RepoRoot -Cwd (Get-Location).Path) -CollabDir $CollabDir) $Task) 'sessions.json'
    $cEntry = $null
    if (Test-Path -LiteralPath $cSessions -PathType Leaf) {
        try { $cEntry = @(Get-PropertyValue (Get-PropertyValue (ConvertFrom-Json -InputObject (Read-SharedText -Path $cSessions)) 'codex' $null) 'consults' @() | Where-Object { $_ }) | Select-Object -Last 1 } catch {
            Stop-WithError "the ledger '$cSessions' could not be read ($(ConvertTo-OneLine $_.Exception.Message)); nothing was sent."
        }
    }
    if (-not $cEntry) { Write-Host "codex-consult: task '$Task' has no ledger entry yet ($cSessions): the complaint goes without a consultation's context." -ForegroundColor Yellow }
    exit (Invoke-TelemetryComplaint -Text $Complain -Contact $Contact -Entry $cEntry -Yes:$Yes)
}

# ---- -Status [-Id <id>] [-Prune] / -Wait [-Id <id>] [-WaitTimeoutSec <s>] (D6, D7)
if ($Status -or $Wait) {
    if ($Detach) { Stop-StatusQuery "-Detach does not go with -Status or -Wait: -Detach starts a consultation, -Status and -Wait look at detached ones." }
    $extra = @($script:ScriptBound.Keys | Where-Object { @('Task', 'CollabDir', 'Status', 'Wait', 'Id', 'WaitTimeoutSec', 'Prune') -notcontains $_ -and $script:CommonParameterNames -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-StatusQuery "-Status and -Wait take only -Task, -CollabDir, -Id, -Prune (with -Status) and -WaitTimeoutSec (with -Wait); not -$(@($extra | Sort-Object) -join ', -')." }
    if ($Prune -and $Wait) { Stop-StatusQuery "-Prune goes with -Status, not with -Wait (-Status -Prune is the one form that writes: it deletes old files)." }
    if ($script:ScriptBound.ContainsKey('WaitTimeoutSec')) {
        if (-not $Wait) { Stop-StatusQuery "-WaitTimeoutSec goes with -Wait." }
        if ($WaitTimeoutSec -le 0) { Stop-StatusQuery "-WaitTimeoutSec must be greater than 0 (got $WaitTimeoutSec); leave it out for the run's own budget." }
    }
    if ($Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Stop-StatusQuery "-Task must be a slug (letters, digits, dot, dash, underscore)." }
    $want = $Id.Trim().ToLowerInvariant()
    if ($script:ScriptBound.ContainsKey('Id') -and $want -notmatch '^[0-9a-f][0-9a-f-]{0,35}$') { Stop-StatusQuery "-Id takes a detach id or its beginning (hexadecimal, as -Detach printed it); got '$Id'." }
    $stRepo = Resolve-RepoRoot -Cwd (Get-Location).Path
    $stCollab = Resolve-CollabRoot -RepoRoot $stRepo -CollabDir $CollabDir
    if ($script:ScriptBound.ContainsKey('CollabDir') -and -not [IO.Directory]::Exists($stCollab)) {
        Stop-StatusQuery "-CollabDir '$CollabDir' does not exist ($stCollab); the id of a detached run goes with -Id (-Status -Id <id8>)."
    }
    $stTaskDir = Join-Path $stCollab $Task
    # the runs asked for: every one of the task, or the one -Id names (by its id8, a longer -Id by
    # the full id in its record)
    $selectRuns = {
        $w8 = $want.Replace('-', '')
        if ($w8.Length -gt 8) { $w8 = $w8.Substring(0, 8) }
        foreach ($r in (Read-DetachedRuns -TaskDir $stTaskDir)) {
            if (-not $want) { $r; continue }
            if (-not $r.Id8.StartsWith($w8)) { continue }
            if ($want.Length -gt 8 -and -not ($r.Record -and ([string]$r.Record.id).ToLowerInvariant().StartsWith($want))) { continue }
            $r
        }
    }
    $runs = @(& $selectRuns)
    if ($want) {
        if ($runs.Count -eq 0) {
            # (Read-DetachedRuns hands back the array itself: assigned, then enumerated)
            $allRuns = Read-DetachedRuns -TaskDir $stTaskDir
            $known = @($allRuns | ForEach-Object { $_.Id8 })
            Stop-StatusQuery "no detached run of task '$Task' has an id starting with '$want' ($(if ($known.Count -gt 0) { "its detached runs: $($known -join ', ')" } else { 'it has none' }))."
        }
        if ($runs.Count -gt 1) { Stop-StatusQuery "-Id '$want' matches $($runs.Count) detached runs of task '$Task': $(@($runs | ForEach-Object { $_.Id8 }) -join ', '); give more of the id." }
    }
    if ($Prune) {
        # D6: the files of runs that are done or died (never started included), last written more
        # than 7 days ago - a running run and one on another host stay. (wave 26, F07-1) An
        # UNREADABLE status file goes too once the file itself was last written more than 7 days
        # ago (a younger one stays; -Status names the command that removes it by hand); (F07-2) a
        # never-started run only when its log was not written in those 7 days either.
        $nowP = [DateTimeOffset]::Now
        foreach ($run in $runs) {
            $j = Get-DetachedJudgement -Record $run.Record -Problem ([string]$run.Error) -Now $nowP
            if (@('done', 'died', 'never-started', 'unreadable') -notcontains $j.State) { continue }
            $last = $null
            if ($j.State -eq 'unreadable') {
                try { $last = [DateTimeOffset]([IO.File]::GetLastWriteTimeUtc($run.Path)) } catch { $last = $null }
            } else {
                foreach ($f in @('finished', 'updated', 'started')) { if (-not $last -and $run.Record.$f) { $last = ConvertTo-WhenOffset $run.Record.$f } }
            }
            if (-not $last -or ($nowP - $last).TotalDays -lt $script:DetachedPruneDays) { continue }
            if ($j.State -eq 'never-started' -and (Test-Path -LiteralPath $run.Log -PathType Leaf)) {
                $logLast = $null
                try { $logLast = [DateTimeOffset]([IO.File]::GetLastWriteTimeUtc($run.Log)) } catch { }
                if ($logLast -and ($nowP - $logLast).TotalDays -lt $script:DetachedPruneDays) { continue }
            }
            $errs = @(foreach ($f in @($run.Path, $run.Log, (Get-DetachedPaths -TaskDir $stTaskDir -Id $run.Id8).Prompt)) { $e = Remove-PendingFile -Path $f; if ($e) { $e } })
            if ($errs.Count -gt 0) { Write-Host "codex-consult: could not prune detached $($run.Id8): $($errs -join '; ')" -ForegroundColor Yellow }
            else { Write-Host "pruned     : detached $($run.Id8) ($($j.State), last written $($last.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant))): its status file and log were removed" }
        }
        $runs = @(& $selectRuns)
    }
    $timedOut = $false
    $waitLimit = 0
    $limitText = ''
    if ($Wait) {
        $openRuns = { param($List) @($List | Where-Object { @('running', 'starting', 'elsewhere') -contains (Get-DetachedJudgement -Record $_.Record -Problem ([string]$_.Error)).State }) }
        $waiting = @(& $openRuns $runs)
        if ($waiting.Count -gt 0) {
            if ($WaitTimeoutSec -gt 0) { $waitLimit = $WaitTimeoutSec; $limitText = '-WaitTimeoutSec' }
            else {
                $waitLimit = [int](@($waiting | ForEach-Object { [int]$_.Record.budget_sec }) | Measure-Object -Maximum).Maximum
                if ($waitLimit -le 0) { $waitLimit = 3600 }
                $limitText = "the budget of the run$(if ($waiting.Count -gt 1) { 's' })"
            }
            $waitIds = @($waiting | ForEach-Object { $_.Id8 })
            Write-Host "codex-consult: waiting for $($waiting.Count) detached run$(if ($waiting.Count -ne 1) { 's' }) of task '$Task' ($($waitIds -join ', ')) - up to $waitLimit s ($limitText), checking every 2 s"
            $waitWatch = [Diagnostics.Stopwatch]::StartNew()
            while ($true) {
                $runs = @(& $selectRuns)
                $still = @(& $openRuns @($runs | Where-Object { $waitIds -contains $_.Id8 }))
                if ($still.Count -eq 0) { break }
                $left = $waitLimit - $waitWatch.Elapsed.TotalSeconds
                if ($left -le 0) { $timedOut = $true; break }
                Start-Sleep -Milliseconds ([int][Math]::Min(2000, [Math]::Max(100, $left * 1000)))
            }
        }
    }
    if ($runs.Count -eq 0) {
        Write-Host "codex-consult: no detached consultation in task '$Task' ($stTaskDir)."
        exit 0
    }
    $nowR = [DateTimeOffset]::Now
    Write-DetachedReport -Runs $runs -Now $nowR
    if ($timedOut) {
        Write-Host ''
        Write-Host "codex-consult: still running after $waitLimit s ($limitText); the run was not touched - -Wait again, or -Status later." -ForegroundColor Yellow
        exit 3
    }
    # D7: the worst state decides - 2 running > 1 failed (a died run too) > 0 all done and usable
    $worst = 0
    foreach ($run in $runs) {
        $e = (Get-DetachedJudgement -Record $run.Record -Problem ([string]$run.Error) -Now $nowR).Exit
        if ($e -gt $worst) { $worst = $e }
    }
    exit $worst
}
if ($script:ScriptBound.ContainsKey('Id') -or $Prune -or $script:ScriptBound.ContainsKey('WaitTimeoutSec')) {
    Stop-WithError "-Id and -Prune go with -Status (-Id and -WaitTimeoutSec with -Wait)."
}

# ---- -DetachId: the background process of -Detach, and then the run itself in it
if ($DetachId) {
    if ($Detach -or $DryRun -or $PanelSpec) { Stop-WithError "-DetachId is internal to -Detach; never pass it yourself." }
    if ($DetachId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { Stop-WithError "-DetachId is internal to -Detach (a detach id is a lowercase guid; got '$DetachId')." }
    $dRepo = Resolve-RepoRoot -Cwd (Get-Location).Path
    $dCollab = Resolve-CollabRoot -RepoRoot $dRepo -CollabDir $CollabDir
    $dPaths = Get-DetachedPaths -TaskDir (Join-Path $dCollab $Task) -Id $DetachId
    $dRead = Read-DetachedStatus -Path $dPaths.Status
    if ($dRead.Error) { Stop-WithError "-DetachId is internal to -Detach: $($dRead.Error)" }
    if (-not $dRead.Exists) { Stop-WithError "-DetachId is internal to -Detach: there is no status file $($dPaths.Status)." }
    $dRec = $dRead.Record
    if ([string]$dRec.id -ne $DetachId) { Stop-WithError "-DetachId is internal to -Detach: the status file $($dPaths.Status) belongs to detach id $($dRec.id)." }
    $ownStart = [string](Get-ProcessStartIso -ProcessId $PID)
    if ($dRec.state -eq 'starting' -and $null -eq $dRec.pid) {
        # THE BACKGROUND. Its command line carries -Task, -CollabDir and -DetachId only.
        $bgExtra = @($script:ScriptBound.Keys | Where-Object { @('Task', 'CollabDir', 'DetachId') -notcontains $_ -and $script:CommonParameterNames -notcontains $_ })
        if ($bgExtra.Count -gt 0) { Stop-WithError "-DetachId is internal to -Detach (its background takes only -Task, -CollabDir and -DetachId; got -$($bgExtra -join ', -'))." }
        # (D5) the self-report first: running, this process, this host - atomic
        $argsText = [string]$dRec.args
        $dRec.args = $null
        $dRec.state = 'running'
        $dRec.pid = $PID
        $dRec.start_time = $ownStart
        $dRec.host = [Environment]::MachineName
        try { Write-DetachedStatus -Path $dPaths.Status -Record $dRec } catch {
            Write-Host "codex-consult: the detached run could not report to its status file $($dPaths.Status) ($(ConvertTo-OneLine $_.Exception.Message)); nothing was started." -ForegroundColor Red
            exit 1
        }
        # (D10) UTF-8 before the first line of output: the log is read as UTF-8
        try { [Console]::OutputEncoding = $script:Utf8NoBom } catch { }
        $global:OutputEncoding = $script:Utf8NoBom
        Write-Host "codex-consult: detached run $($dPaths.Id8) (detach id $DetachId) - pid $PID on $([Environment]::MachineName), started $(Get-IsoTimestamp); status file $($dPaths.Status)"
        # (D3) the run in this process, the final status whatever happens in it
        $dCode = 1
        $dLine = ''
        try {
            $dSpec = ConvertFrom-DetachArgs -Text $argsText
            if ([string]$dSpec['Task'] -cne $Task) { throw "its arguments name task '$($dSpec['Task'])', not '$Task'" }
            # (wave 26, F11-2) the prompt from its file (the record names only the file), then the
            # file goes
            if ($dSpec.ContainsKey('PromptFile')) {
                $dPromptFile = [string]$dSpec['PromptFile']
                $dSpec.Remove('PromptFile')
                if (-not (Test-Path -LiteralPath $dPromptFile -PathType Leaf)) { throw "its prompt file '$dPromptFile' is gone" }
                $dSpec['Prompt'] = Read-SharedText -Path $dPromptFile
                $null = Remove-PendingFile -Path $dPromptFile
            }
            $global:LASTEXITCODE = 0
            & $script:SelfPath @dSpec -DetachId $DetachId
            $dCode = [int]$LASTEXITCODE
        } catch {
            $dCode = 1
            $dLine = "codex-consult: the detached run stopped on an error: $(ConvertTo-OneLine $_.Exception.Message)"
            Write-Host $dLine -ForegroundColor Red
        } finally {
            $dFinalError = Complete-DetachedRun -Path $dPaths.Status -Fallback $dRec -Exit $dCode -Line $dLine
        }
        if ($dFinalError) {
            # (wave 26, F08-2) a distinct exit: the status file does not say how the run ended
            Write-Host "codex-consult: the detached run $($dPaths.Id8) ended with exit $dCode, but its status file could not be made final - the result exists only in this log ($($dPaths.Log)); -Status will judge the run by its background (exit 6)." -ForegroundColor Red
            exit 6
        }
        exit $dCode
    }
    if ($dRec.state -ne 'running' -or [int]$dRec.pid -ne $PID -or -not (Test-SameStartTime -A ([string]$dRec.start_time) -B $ownStart)) {
        Stop-WithError "-DetachId is internal to -Detach: the status file $($dPaths.Status) is in state $($dRec.state)$(if ($dRec.pid) { " (pid $($dRec.pid))" }), not this process's."
    }
    # THE RUN (invoked by the background above, in the same process): it keeps the status file.
    $script:DetachRun = [pscustomobject]@{ Path = $dPaths.Status; Record = $dRec }
    $script:StopWithErrorHook = {
        param([string]$Line, [int]$Code = 1)
        if ($script:DetachRun) {
            Complete-DetachedRecord -Record $script:DetachRun.Record -Exit $Code -Summary $Line
            Save-DetachedRun -Final
        }
    }
}

# ---- -Detach: the foreground (D2, D8)
$detachForeground = $false
if ($Detach) {
    if ($PanelSpec) { Stop-WithError "-Detach does not go with -PanelSpec (internal to -Panel)." }
    if ($DryRun) { Stop-WithError "-Detach does not go with -DryRun: a dry run starts nothing to detach - run -DryRun alone first." }
    $detachForeground = $true
    # The foreground writes nothing and takes no lock - the dry run's rule - while the refusals a
    # real run makes before its lock are made here too ($detachForeground, D2).
    $DryRun = $true
}

# ----------------------------------------------------------------------------- codex helpers

# Thread id from the `codex exec --json` event stream.
# Ground truth (codex-cli 0.155.x): the FIRST JSONL line of every run - new, resume
# and fork alike - is
#   {"type":"thread.started","thread_id":"01a0c86d-4d77-7c01-98b1-f682bf63c677"}
# i.e. the event named "thread.started" carries the resulting thread in its
# top-level "thread_id" field. The other shapes below are version-drift safety nets,
# and they only look at SESSION-START events (type thread.started, session.started or
# session_configured, top-level or msg-wrapped): any other event may carry some other
# id (a parent thread, a sub-session) and is ignored for thread purposes. No thread
# here -> the caller falls back to the rollout rule.
$script:SessionStartEvents = @('thread.started', 'session.started', 'session_configured')
function Get-ThreadIdFromEvents {
    param([string]$Path)
    $text = Read-SharedText -Path $Path
    if (-not $text) { return '' }
    $uuidRe = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    foreach ($line in ($text -split "`r?`n")) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = $trimmed | ConvertFrom-Json } catch { continue }
        $type = ''
        if ($obj.PSObject.Properties['type']) { $type = [string]$obj.type }
        # primary: the "thread.started" event
        if ($type -ceq 'thread.started' -and $obj.PSObject.Properties['thread_id'] -and $obj.thread_id -match $uuidRe) {
            return [string]$obj.thread_id
        }
        # drift net 1: a top-level session-start event with a thread/session/conversation id
        if ($script:SessionStartEvents -ccontains $type) {
            foreach ($field in @('thread_id', 'session_id', 'conversation_id')) {
                if ($obj.PSObject.Properties[$field] -and $obj.$field -match $uuidRe) {
                    return [string]$obj.$field
                }
            }
        }
        # drift net 2: the older msg-wrapped shape ({"msg":{"type":"session_configured",...}})
        if ($obj.PSObject.Properties['msg'] -and $obj.msg -and $obj.msg.PSObject.Properties['type']) {
            $msg = $obj.msg
            if ($script:SessionStartEvents -ccontains [string]$msg.type) {
                foreach ($field in @('session_id', 'thread_id', 'conversation_id')) {
                    if ($msg.PSObject.Properties[$field] -and $msg.$field -match $uuidRe) {
                        return [string]$msg.$field
                    }
                }
            }
        }
    }
    return ''
}

# Codex reports a failed turn on the JSON event stream (stdout), not on stderr:
#   {"type":"error","message":"You've hit your usage limit. ..."}
#   {"type":"turn.failed","error":{"message":"..."}}
# Without this, a quota or auth failure shows up only as a bare "codex exit 1".
function Get-ErrorFromEvents {
    param([string]$Path)
    $text = Read-SharedText -Path $Path
    if (-not $text) { return '' }
    $found = ''
    foreach ($line in ($text -split "`r?`n")) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = $trimmed | ConvertFrom-Json } catch { continue }
        if (-not $obj.PSObject.Properties['type']) { continue }
        if ($obj.type -eq 'error' -and $obj.PSObject.Properties['message'] -and $obj.message) {
            $found = [string]$obj.message
        } elseif ($obj.type -eq 'turn.failed' -and $obj.PSObject.Properties['error']) {
            $err = $obj.error
            if ($err -and $err.PSObject.Properties['message'] -and $err.message) {
                $found = [string]$err.message
            }
        }
    }
    return ($found -replace '\s+', ' ').Trim()
}

# Token usage from the last `turn.completed` event:
#   {"type":"turn.completed","usage":{"input_tokens":206772,"cached_input_tokens":163840,
#    "cache_write_input_tokens":0,"output_tokens":1581,"reasoning_output_tokens":113}}
# The four recorded fields are copied when present; a missing field is $null, and a
# run without a turn.completed event has usage $null.
function Get-UsageFromEvents {
    param([string]$Path)
    $text = Read-SharedText -Path $Path
    if (-not $text) { return $null }
    $usage = $null
    foreach ($line in ($text -split "`r?`n")) {
        if ($line.IndexOf('turn.completed') -lt 0) { continue }
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $trimmed } catch { continue }
        if (-not $obj.PSObject.Properties['type'] -or $obj.type -ne 'turn.completed') { continue }
        $u = $null
        if ($obj.PSObject.Properties['usage']) { $u = $obj.usage }
        $values = [ordered]@{}
        foreach ($field in @('input_tokens', 'cached_input_tokens', 'output_tokens', 'reasoning_output_tokens')) {
            $values[$field] = $null
            if ($u -and $u.PSObject.Properties[$field] -and $null -ne $u.$field) { $values[$field] = [long]$u.$field }
        }
        $usage = [pscustomobject]$values
    }
    return $usage
}

# Fallback when the event stream names no thread: the rollout files written since the
# run started, <codex home>/sessions/<yyyy>/<mm>/<dd>/rollout-*-<uuid>.jsonl, newest
# first. Another task or an interactive Codex session may have written one too, so a
# rollout counts as THIS run's thread only when it contains this run's consultation id
# (the prompt's last line). { Thread (verified, or ''); Candidate (the newest unverified
# uuid - diagnostic only, never used as a thread or a parent) }.
function Find-ThreadInRollouts {
    param([datetime]$StartedAt, [string]$ConsultId)
    $found = [pscustomobject]@{ Thread = ''; Candidate = '' }
    $codexHome = Get-CodexHome
    if (-not $codexHome) { return $found }
    $root = Join-Path $codexHome 'sessions'
    if (-not (Test-Path -LiteralPath $root)) { return $found }
    # (wave 28b, D16) every LOCAL day from the start to now, invariant digits (Get-LocalDayDirs)
    $days = Get-LocalDayDirs -Root $root -StartedAt $StartedAt -Now (Get-Date)
    $candidates = @()
    foreach ($day in $days) {
        if (Test-Path -LiteralPath $day) {
            $candidates += Get-ChildItem -LiteralPath $day -Filter 'rollout-*.jsonl' -File -ErrorAction SilentlyContinue
        }
    }
    $recent = @($candidates |
            Where-Object { $_.LastWriteTime -ge $StartedAt.AddSeconds(-5) } |
            Sort-Object LastWriteTime -Descending)
    foreach ($file in $recent) {
        if ($file.Name -notmatch '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { continue }
        $uuid = $Matches[1]
        if (-not $found.Candidate) { $found.Candidate = $uuid }
        if ($ConsultId -and (Read-SharedText -Path $file.FullName).IndexOf($ConsultId, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $found.Thread = $uuid
            $found.Candidate = ''
            return $found
        }
    }
    return $found
}

# A TEST HOOK's milliseconds: "<ms>" for every run, or "<model>=<ms>[|<model>=<ms>...]" (with
# "*=<ms>" for the other models) for the runs of $Model; 0 when unset or not for this model.
function Get-TestHookMs {
    param([string]$Value, [string]$Model)
    if (-not $Value) { return 0 }
    $pick = ''
    foreach ($item in $Value.Split('|')) {
        $eq = $item.IndexOf('=')
        if ($eq -lt 0) { if ($item.Trim() -and -not $pick) { $pick = $item.Trim() }; continue }
        $k = $item.Substring(0, $eq).Trim()
        if ($k -ceq $Model) { $pick = $item.Substring($eq + 1).Trim(); break }
        if ($k -eq '*') { $pick = $item.Substring($eq + 1).Trim() }
    }
    $ms = 0
    if ([int]::TryParse($pick, [ref]$ms) -and $ms -gt 0) { return $ms }
    return 0
}

function Format-Usage {
    param($Usage)
    if ($null -eq $Usage) { return 'unknown' }
    $v = @{}
    foreach ($field in @('input_tokens', 'cached_input_tokens', 'output_tokens', 'reasoning_output_tokens')) {
        $v[$field] = '?'
        if ($null -ne $Usage.$field) { $v[$field] = "$($Usage.$field)" }
    }
    return "in $($v.input_tokens) (cached $($v.cached_input_tokens)), out $($v.output_tokens), reasoning $($v.reasoning_output_tokens)"
}

# ----------------------------------------------------------------------------- engine turns (agy, muse)

# (wave 24b, F08-1) The ONE guarded start of an engine process - EVERY Start-Process of a turn goes
# through it: the main turn, a denial retry, the timeout continuation, a format repair (codex and
# every other engine). Right before the start the engine's launch invariant is read afresh
# (Get-EngineLaunchBlock -Fresh, D4 - muse: the billing guard re-reads auth.json and the
# environment, never a sign-in cached by the preflight minutes earlier) and, for an engine other
# than codex, the %-hazard of a .cmd launcher (F02-14); a refusal starts nothing. { Proc ($null
# when nothing was started); Refusal ('' or why the launch was refused); Error ('' or why
# Start-Process failed) }. Reads the run's $engineName and $repoRoot.
function Start-EngineProcess {
    param([string]$Launcher, [string[]]$Argv, [string]$StdoutPath, [string]$StderrPath, [string]$StdinPath)
    $r = [pscustomobject]@{ Proc = $null; Refusal = ''; Error = '' }
    $refusal = Get-EngineLaunchBlock -Engine $engineName -Fresh
    if (-not $refusal -and $engineName -ne 'codex') { $refusal = Get-CmdArgvHazard -Launcher $Launcher -Argv $Argv }
    if ($refusal) { $r.Refusal = [string]$refusal; return $r }
    # (wave 27, R13 D4) the engine child never inherits the coordinator's host markers (the ledger's
    # child_env_scrubbed) - (wave 28b, D10) nor the test-mode variables; this process gets them back
    # right after the start
    $hiddenMarkers = $null
    # (wave 27c, D3 / F30-2) transactional: a removal that fails put everything back already - the
    # start is refused, nothing starts with part of the markers
    # (wave 29, D2) an engine with an ALLOW-listed child environment (claude: the adapter's ChildEnv
    # for the run's auth): every other variable is hidden in the same transaction
    $childEnvPlan = $null
    $startSpec = Get-EngineSpec -Name $engineName
    if ($engineName -ne 'codex' -and $startSpec -and $startSpec.Adapter -and $startSpec.Adapter.PSObject.Properties['ChildEnv'] -and $startSpec.Adapter.ChildEnv) {
        try { $childEnvPlan = & $startSpec.Adapter.ChildEnv -Auth $engineAuth -Endpoint $engineEndpoint } catch {
            $r.Refusal = "bridge failure: the child environment could not be built ($(ConvertTo-OneLine $_.Exception.Message))"
            return $r
        }
        # (wave 29b, E4) a child environment that must not start (claude auth endpoint without its
        # endpoint or its token: the CLI would fall back to the local login) - nothing starts
        if ($childEnvPlan -and $childEnvPlan.PSObject.Properties['Problem'] -and $childEnvPlan.Problem) {
            $r.Refusal = "the $engineName engine's child environment is not usable: $($childEnvPlan.Problem)"
            return $r
        }
    }
    # (wave 29) how the argv is quoted: the CRT rules for an engine that takes JSON text in argv
    # (claude --json-schema: \" never toggles a parser's quote state), else ConvertTo-ProcArg
    $quoteArg = $(if ($startSpec -and [string](Get-PropertyValue $startSpec 'ArgQuote' '') -eq 'crt') { 'ConvertTo-CrtArg' } else { 'ConvertTo-ProcArg' })
    try { $hiddenMarkers = Hide-HostMarkers -TestVars -ChildEnv $childEnvPlan } catch {
        $r.Refusal = "bridge failure: $(ConvertTo-OneLine $_.Exception.Message)"
        return $r
    }
    try {
        $r.Proc = Start-Process -FilePath $Launcher -ArgumentList ((($Argv | ForEach-Object { & $quoteArg $_ }) -join ' ')) `
            -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
            -RedirectStandardOutput $StdoutPath `
            -RedirectStandardError $StderrPath `
            -RedirectStandardInput $StdinPath
    } catch {
        $r.Error = ConvertTo-OneLine $_.Exception.Message
    } finally {
        Restore-HostMarkers -Saved $hiddenMarkers
    }
    return $r
}

# (wave 27c, D16) One tree kill of this run: kept for the ledger's kill_confirmed; an UNCONFIRMED one
# (no known survivor, but the tree could not be seen dead) gets a warning naming the pid - (wave 28c,
# D8) the pids whose start time could not be read when there are such (the bridge left them alone),
# else the root. (wave 28d, D5 / F49-1) A kill with survivors AND such unverified descendants warns
# too, naming BOTH groups.
function Add-KillCheck {
    param($Check, [string]$Turn)
    if (-not $Check) { return }
    $script:KillChecks.Add($Check)
    if (-not $Check.Confirmed -and @($Check.Survivors).Count -eq 0) {
        $script:KillWarnings.Add("kill not confirmed ($Turn): $($Check.Why); pid $(Get-KillMayRunPids $Check) may still run - check it, and stop it by hand if it does")
    } elseif (-not $Check.Confirmed -and @(Get-PropertyValue $Check 'Unverified' @()).Count -gt 0) {
        $script:KillWarnings.Add("kill not confirmed ($Turn): $(@($Check.Survivors).Count) processes survived: pid $(@($Check.Survivors) -join ', ')$(Get-KillUnverifiedText $Check) - check them, and stop them by hand if they do")
    }
}
function Get-KillMayRunPids {
    param($Check)
    $u = @(Get-PropertyValue $Check 'Unverified' @())
    if ($u.Count -gt 0) { return ($u -join ', ') }
    return [string]$Check.RootPid
}
# (wave 28d, D5) The unverified group next to the survivors: "; <why>; pid <n> may still run", '' when
# the kill left no descendant whose identity could not be read.
function Get-KillUnverifiedText {
    param($Check)
    $u = @(Get-PropertyValue $Check 'Unverified' @())
    if ($u.Count -eq 0) { return '' }
    return "; $($Check.Why); pid $($u -join ', ') may still run"
}

# (wave 27c, D16) How a tree kill is told: "(process tree killed)" only when confirmed; else "(kill
# not confirmed: <why>; pid <n> may still run)". (wave 28d, D5) With survivors: "(process tree killed;
# <n> processes survived: pid <n>[; <why>; pid <n> may still run])" - the unverified group named too.
function Format-KillText {
    param($Check)
    if (@($Check.Survivors).Count -gt 0) { return "(process tree killed; $(@($Check.Survivors).Count) processes survived: pid $(@($Check.Survivors) -join ', ')$(Get-KillUnverifiedText $Check))" }
    if ($Check.Confirmed) { return '(process tree killed)' }
    return "(kill not confirmed: $($Check.Why); pid $(Get-KillMayRunPids $Check) may still run)"
}
# One more turn (an engine's denial retry and format repair; wave 24: the timeout continuation
# of every engine, codex included) under the SAME task lock and recovery record as the run: the
# record goes launching -> running (child pid, start time, `events` = this turn's event stream)
# before the process is waited on; a timeout kills the process tree, and survivors are recorded
# (state survivors) and keep the record.
# -PromptPath / -PromptText (wave 23, D1): the turn's own prompt file, written first (muse
# names it in its argv; its stdin is then empty). Right before the start (Start-EngineProcess)
# the engine's launch invariant (D4; read afresh - wave 24, F15-1) and, for an engine other than
# codex, the .cmd %-hazard (F02-14) are checked again: a refusal starts nothing (the record gets
# its previous state back - (wave 24c, F15-6) so does a Start-Process error: every path that
# starts nothing).
# Reads the run's $pendingRecord, $pendingPath, $engineLauncher, $engineName and $repoRoot.
# { Exit (-1 unless it exited); Problem ('' or why the turn did not complete); Wall;
# KeepPending; Stderr (UTF-8 text); Started (a process was started: one more engine turn -
# for muse one more subscription prompt) }.
function Invoke-EngineTurn {
    param([string[]]$Argv, [string]$StdinText, [string]$EventsPath, [string]$StdinPath, [string]$StderrPath, [int]$Timeout, [string]$Note, [string]$PromptPath = '', [string]$PromptText = '')
    $t = [pscustomobject]@{ Exit = -1; Problem = ''; Wall = 0; KeepPending = $false; Stderr = ''; Started = $false }
    if ($PromptPath) { Write-Utf8NoBom -Path $PromptPath -Text $PromptText }
    Write-Utf8NoBom -Path $StdinPath -Text $StdinText
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $prevState = [string]$pendingRecord.state
    $prevNote = [string]$pendingRecord.note
    $pendingRecord.state = 'launching'
    $pendingRecord.note = "$Note being started; its pid is not recorded yet"
    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
        $t.Problem = "could not write the recovery record ($(ConvertTo-OneLine $_.Exception.Message)); the turn was not started"
        # (the record on disk still has its previous state: so does the one in memory)
        $pendingRecord.state = $prevState
        $pendingRecord.note = $prevNote
        return $t
    }
    $launch = Start-EngineProcess -Launcher $engineLauncher -Argv $Argv -StdoutPath $EventsPath -StderrPath $StderrPath -StdinPath $StdinPath
    $proc = $launch.Proc
    if (-not $proc) {
        # (wave 24c, F15-6) NOTHING was started - a launch refusal or a Start-Process error (a
        # launcher gone meanwhile): on every such path the record gets its previous state back. A
        # record left `launching` would tell the next run (after a bridge that died before its
        # commit) that a process may be starting - it would scan for one that never existed.
        $pendingRecord.state = $prevState
        $pendingRecord.note = $prevNote
        try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
        if ($launch.Refusal) {
            $t.Problem = "refused before launch: $($launch.Refusal)"
            return $t
        }
        $t.Problem = "could not start $engineName$(if ($launch.Error) { " - $($launch.Error)" })"
    }
    if ($proc) {
        if ($script:LegacyPS) { try { $null = $proc.Handle } catch { } }
        $t.Started = $true
        $registered = $true
        try {
            $pendingRecord.state = 'running'
            $pendingRecord.child_pid = $proc.Id
            $pendingRecord.child_start_time = [string](Get-ProcessStartIso -ProcessId $proc.Id)
            $pendingRecord.note = $Note
            $evRel = Get-RepoRelativePath -Root $repoRoot -Path $EventsPath
            $pendingRecord.events = $(if ($evRel) { $evRel } else { $EventsPath })
            Write-PendingFile -Path $pendingPath -Record $pendingRecord
        } catch {
            $registered = $false
            $t.Problem = "could not register the $Note process ($(ConvertTo-OneLine $_.Exception.Message)); it was stopped"
            # the record on disk still says launching: so does the one in memory
            $pendingRecord.state = 'launching'; $pendingRecord.child_pid = $null; $pendingRecord.child_start_time = ''
            $null = Stop-ProcessTree -Process $proc
        }
        if ($registered) {
            # (wave 26b, D10) the operator's kick is polled here too (no stall cut on these turns)
            $turnWait = Wait-EngineProcess -Process $proc -TimeoutSec $Timeout -KickPath $script:KickPath -Engine $engineName
            # (wave 26c, D1) a kick found after this turn had finished: taken late, the outcome stays
            if ($turnWait.KickLate) { $script:KickLateTurns.Add("the $($Note -replace ' turn$', '')") }
            if (-not $turnWait.Exited) {
                # (wave 27c, D16) the kill confirmed - "(process tree killed)" only then
                $turnKill = Stop-ProcessTreeChecked -Process $proc
                Add-KillCheck -Check $turnKill -Turn ($Note -replace ' turn$', '')
                $surv = [int[]]$turnKill.Survivors
                $stopWhat = "timeout after $Timeout s"
                if ($turnWait.Reason -eq 'kick') {
                    $script:RunKicked = $true
                    $script:KickedTurn = $(if ($Note -like 'format repair*') { 'repair' } elseif ($Note -like 'denial retry*') { 'retry' } elseif ($Note -like 'timeout continuation*') { 'continue' } else { 'turn' })
                    $stopWhat = 'stopped by the operator (-Kick)'
                    $null = Remove-PendingFile -Path $script:KickPath
                }
                $t.Problem = "$stopWhat $(Format-KillText $turnKill)"
                if ($surv.Count -gt 0) {
                    $t.Problem = "$stopWhat (process tree killed; $($surv.Count) processes survived: pid $($surv -join ', ')$(Get-KillUnverifiedText $turnKill))"
                    $t.KeepPending = $true
                    try {
                        $pendingRecord.state = 'survivors'
                        $pendingRecord.survivors = [object[]]@(New-SurvivorEntries -Pids $surv)
                        # (wave 28e, E1 / F54-1) the descendants the kill could not verify, beside them
                        $pendingRecord | Add-Member -NotePropertyName 'unverified' -NotePropertyValue ([object[]]@(New-UnverifiedEntries -Check $turnKill)) -Force
                        Write-PendingFile -Path $pendingPath -Record $pendingRecord
                    } catch { }
                }
            } else {
                $t.Exit = $proc.ExitCode
            }
        }
    }
    $watch.Stop()
    $t.Wall = [math]::Round($watch.Elapsed.TotalSeconds, 1)
    $t.Stderr = Read-SharedText -Path $StderrPath
    return $t
}

# The read-only check of an engine other than codex (agy A17, widened in wave 18 - F09-1/F10-1;
# muse wave 23, D12): '' when nothing the
# review must not touch changed during the run, else the reason - the working tree (tracked
# or untracked files; the paths that changed), the collab directory (EVERY file under it,
# recursively: every task's stores and handoffs - outside the tree fingerprint; the run's own
# <task>/handoffs/NN-<prefix>-<slug>.* files and the .consult.* lock and recovery files
# excepted), the brief, an artifact. The check cannot tell who changed a file, so the text
# does not blame the reviewer (F09-3). Gitignored paths, submodules and files outside the
# repository stay unmonitored (README "Engines", F12) - and so do reads. $CollabShown: the
# collab directory as shown in front of its paths ('.collab/' inside the repository, ''
# otherwise). The closing words are the engine row's TreeNote (D11). (wave 24c) The working tree
# is compared by CONTENT (Compare-TreeContent): a commit, a moved HEAD or a staged change that
# leaves every file as it was is no change - only a file whose content appeared, disappeared or
# changed is.
#
# (wave 26b, D9) Get-EngineTreeCheck: the same check, structured. An engine the bridge runs with
# its write capability DISABLED by its own flags (the spec's WriteDisabled: muse --disable-write
# --disable-shell) cannot have made the change: every part becomes a warning ("the collab
# directory changed during the run (1 file: .collab/t/state.md) - muse ran write-disabled, the
# change is not the reviewer's") and the reply stays usable - Outcome 'warned'. agy keeps the
# failure (F12: --sandbox does not block writes) - Outcome 'failed', Problem the text above.
# { Outcome ('clean' | 'warned' | 'failed'); Problem ('' unless failed); Warnings (string[]);
# Files (string[]: the tree's paths, the collab directory's paths as shown, 'brief', the
# artifacts) } - the ledger's tree_check is { outcome, files[] }.
function Get-EngineTreeCheck {
    param($RevBefore, $RevAfter, [bool]$BriefChanged, [string[]]$ChangedArtifacts, [hashtable]$CollabBefore, [hashtable]$CollabAfter, [string[]]$OwnPrefixes, [string]$Engine, [string]$CollabShown = '')
    $cut = { param([string[]]$Names) $n = @($Names); $list = (@($n | Select-Object -First 5) -join ', '); if ($n.Count -gt 5) { $list += ', ...' }; "$($n.Count) file$(if ($n.Count -ne 1) { 's' }): $list" }
    $spec = Get-EngineSpec -Name $Engine
    $writeOff = [bool](Get-PropertyValue $spec 'WriteDisabled' $false)
    $why = New-Object System.Collections.Generic.List[string]
    $warn = New-Object System.Collections.Generic.List[string]
    $files = New-Object System.Collections.Generic.List[string]
    $notMine = "$Engine ran write-disabled, the change is not the reviewer's"
    $tree = Compare-TreeContent -Before $RevBefore -After $RevAfter
    if ($tree.Changed) {
        foreach ($p in @($tree.Paths)) { $files.Add([string]$p) }
        $why.Add("the working tree changed during the run (by the reviewer or anyone else): $(& $cut $tree.Paths)")
        $warn.Add("the working tree changed during the run ($(& $cut $tree.Paths)) - $notMine")
    }
    $collab = Compare-DirectorySnapshot -Before $CollabBefore -After $CollabAfter -IgnorePrefixes $OwnPrefixes
    if ($collab.Count -gt 0) {
        $shown = [string[]]@($collab | ForEach-Object { $CollabShown + $_ })
        foreach ($p in $shown) { $files.Add($p) }
        $why.Add("the collab directory changed during the run (by the reviewer or anyone else): $(& $cut $shown)")
        $warn.Add("the collab directory changed during the run ($(& $cut $shown)) - $notMine")
    }
    if ($BriefChanged) {
        $files.Add('brief')
        $why.Add('the brief changed during the run (by the reviewer or anyone else)')
        $warn.Add("the brief changed during the run - $notMine")
    }
    if (@($ChangedArtifacts).Count -gt 0) {
        foreach ($p in @($ChangedArtifacts)) { $files.Add([string]$p) }
        $why.Add("artifact(s) changed during the run (by the reviewer or anyone else): $(@($ChangedArtifacts) -join ', ')")
        $warn.Add("artifact(s) changed during the run ($(@($ChangedArtifacts) -join ', ')) - $notMine")
    }
    $r = [pscustomobject]@{ Outcome = 'clean'; Problem = ''; Warnings = [string[]]@(); Files = [string[]]$files.ToArray() }
    if ($why.Count -eq 0) { return $r }
    if ($writeOff) { $r.Outcome = 'warned'; $r.Warnings = [string[]]$warn.ToArray(); return $r }
    $note = [string]$spec.TreeNote
    if (-not $note) { $note = "$Engine's sandbox does not block writes" }
    $r.Outcome = 'failed'
    $r.Problem = (($why.ToArray() -join '; ') + " - $note")
    return $r
}

function Get-EngineTreeProblem {
    param($RevBefore, $RevAfter, [bool]$BriefChanged, [string[]]$ChangedArtifacts, [hashtable]$CollabBefore, [hashtable]$CollabAfter, [string[]]$OwnPrefixes, [string]$Engine, [string]$CollabShown = '')
    return (Get-EngineTreeCheck -RevBefore $RevBefore -RevAfter $RevAfter -BriefChanged $BriefChanged -ChangedArtifacts $ChangedArtifacts -CollabBefore $CollabBefore -CollabAfter $CollabAfter -OwnPrefixes $OwnPrefixes -Engine $Engine -CollabShown $CollabShown).Problem
}

# ----------------------------------------------------------------------------- presets + prompt text

$validPurposes = $script:ConsultPurposes
$presetEffort = @{
    ''              = 'high'
    'framing'       = 'high'
    'decision'      = 'high'
    'checkpoint'    = 'medium'
    'core-contract' = 'xhigh'
    'acceptance'    = 'high'
    'diff-review'   = 'high'
    'stuck'         = 'xhigh'
    'chore'         = 'low'
}
$presetWords = @{
    ''              = 700
    'framing'       = 700
    'decision'      = 700
    'checkpoint'    = 500
    'core-contract' = 900
    'acceptance'    = 900
    'diff-review'   = 700
    'stuck'         = 700
    'chore'         = 400
}
# (wave 24, T1) the main turn's timeout when -TimeoutSec is not given: a big review needs more
# than the 900 s of a checkpoint (a ~4,000-line diff-review lost both members at 900 s)
$presetTimeout = @{
    ''              = 900
    'framing'       = 1800
    'decision'      = 1800
    'checkpoint'    = 900
    'core-contract' = 2400
    'acceptance'    = 3600
    'diff-review'   = 2400
    'stuck'         = 2400
    'chore'         = 600
}
# -Range: the purposes it applies to, and the size warning's thresholds
$rangePurposes = @('diff-review', 'acceptance')
$rangeWarnLines = 1500
$rangeWarnTimeout = 2400
$purposeText = @{
    'framing'       = 'Surface the options the brief does not list and challenge the framing itself before answering inside it. Say what you would need to know to choose between the options.'
    'decision'      = 'Rank the alternatives. For each one, name the deciding factor and its failure mode.'
    'checkpoint'    = 'Verify the CURRENT invariants the brief claims against the code as it is now, and report any drift between what is claimed and what exists. Keep it short.'
    'core-contract' = 'This review runs BEFORE dependent work is built on the core. Cover the interfaces, recovery and persistence paths and the state machines NAMED IN THE BRIEF and their immediate dependency boundaries - not the whole system. For each state machine: states, transitions, the failure at each transition. Name what the evidence does not show. Expect this review to be re-run whenever recovery, persistence or interfaces change.'
    'acceptance'    = 'Decide whether the result can be accepted. The verdict, the blockers, the unproven scenarios and an OBSERVABLE first-run checklist (what must be seen in logs or output on the first real run before an exit code 0 is believed) are mandatory.'
    'diff-review'   = 'Read the change adversarially: what breaks, what it does not cover, what the tests do not prove.'
    'stuck'         = 'The coordinator is stuck. Look for the angle they are missing and question their assumptions before proposing fixes.'
    'chore'         = 'This is a chore: a bounded search or extraction task. Report facts with file paths and line numbers, quote what you found, say what you did not find. No verdict, no findings, no recommendations beyond the ask.'
}

# ----------------------------------------------------------------------------- panel member (internal)

# A -Panel run starts one child run of this script per member with only -Task and
# -PanelSpec: the spec (base64 of UTF-8 JSON) carries the member's roster entry, the panel
# record and every other parameter of the -Panel call, so no brief, prompt or path travels
# through command-line quoting. Everything below then runs as for any consultation.
$panelMember = $null
if ($PanelSpec) {
    if ($Panel -or $PanelAll) { Stop-WithError "-PanelSpec is internal to -Panel; never combine them." }
    try {
        $panelMember = ConvertFrom-Json -InputObject ($script:Utf8NoBom.GetString([Convert]::FromBase64String($PanelSpec)))
    } catch {
        Stop-WithError "-PanelSpec is internal to -Panel and could not be read ($(ConvertTo-OneLine $_.Exception.Message))."
    }
    $pa = $panelMember.args
    $CollabDir = [string]$pa.collab_dir
    $Mode = [string]$pa.mode
    $Brief = [string]$pa.brief
    $Prompt = [string]$pa.prompt
    $Purpose = [string]$pa.purpose
    $Effort = [string]$pa.effort
    $Sandbox = [string]$pa.sandbox
    $MaxWords = [int]$pa.max_words
    $TimeoutSec = [int]$pa.timeout_sec
    # (wave 26b, D12) the stall cut the panel run resolved for this member (-StallSec, the roster
    # entry's stall_sec, else 900)
    $StallSec = [int](Get-PropertyValue $pa 'stall_sec' 900)
    # (wave 24) the panel run resolved the timeout, its source, the continuation budget and the
    # range statistics once; the member inherits them
    $memberTimeoutSource = [string](Get-PropertyValue $pa 'timeout_source' 'explicit')
    $ContinueSec = [int](Get-PropertyValue $pa 'continue_sec' -1)
    $Range = [string](Get-PropertyValue $pa 'range' '')
    $memberRangeStat = Get-PropertyValue $pa 'range_stat' $null
    $ReplyName = [string]$pa.reply_name
    $Artifact = [string[]]@(@($pa.artifact) | Where-Object { $_ })
    $Raw = [bool]$pa.raw
    $CodexExe = [string]$pa.codex_exe
    $NativeEffort = [string]$pa.native_effort
    $OffPeakOnly = [bool]$pa.off_peak_only
    $SkipPreflight = [bool]$pa.skip_preflight
    $CodexConfig = [string[]]@(@($pa.codex_config) | Where-Object { $_ })
    $SchemaTransport = [string]$pa.schema_transport
    if ($null -ne $pa.PSObject.Properties['format_retry']) { $FormatRetry = [int]$pa.format_retry }
    if ($null -ne $pa.PSObject.Properties['engine']) { $Engine = [string]$pa.engine }
    if ($null -ne $pa.PSObject.Properties['engine_exe']) { $EngineExe = [string]$pa.engine_exe }
    if ($null -ne $pa.PSObject.Properties['denial_retry']) { $DenialRetry = [int]$pa.denial_retry }
    if ($null -ne $pa.PSObject.Properties['max_model_steps']) { $MaxModelSteps = [int]$pa.max_model_steps }
    # (wave 27) the panel run's brief prefix (shown by a member's dry run)
    if ($null -ne $pa.PSObject.Properties['brief_prefix']) { $BriefPrefix = [string]$pa.brief_prefix }
    # (wave 28) the panel run's resolved telemetry switch
    if ($null -ne $pa.PSObject.Properties['telemetry']) { $Telemetry = [string]$pa.telemetry }
    $DryRun = [bool]$pa.dry_run
    # (wave 26) the topics and this member's role come from the panel run (-Roles: assigned there)
    $Topic = [string[]]@(@(Get-PropertyValue $pa 'topics' @()) | Where-Object { $_ } | ForEach-Object { [string]$_ })
    $Role = [string](Get-PropertyValue $panelMember 'role' '')
    $Roles = [string[]]@()
    $Require = [string[]]@()
    # (0.4.x wave 21) the numbers, the consultation id and the parent come from the panel run
    $memberNn = [string](Get-PropertyValue $panelMember 'nn' '')
    $memberN = 0
    [void][int]::TryParse([string](Get-PropertyValue $panelMember 'n' ''), [ref]$memberN)
    $memberParentPid = 0
    [void][int]::TryParse([string](Get-PropertyValue $panelMember 'parent_pid' ''), [ref]$memberParentPid)
    $memberParentStart = ConvertTo-JsonText (Get-PropertyValue $panelMember 'parent_start_time' '')
    if ($memberN -le 0 -or $memberNn -notmatch '^\d{2,}$' -or $memberParentPid -le 0) {
        Stop-WithError "-PanelSpec is internal to -Panel and does not name this member's numbers and parent (n, nn, parent_pid); this panel member was not started."
    }
    # This member's output reaches the -Panel run through a file: write it as UTF-8 (the
    # panel run reads it so).
    try { [Console]::OutputEncoding = $script:Utf8NoBom } catch { }
}
$panelRun = [bool]($Panel -or $PanelAll)
if ($PSBoundParameters.ContainsKey('PanelConcurrency') -and -not $panelRun) {
    Stop-WithError "-PanelConcurrency goes with -Panel (or -PanelAll) only."
}
if ($PanelConcurrency -lt 0) {
    Stop-WithError "-PanelConcurrency must be 0 (no cap) or a positive number (got $PanelConcurrency)."
}
# (wave 26, R14-R16) the companions' options
if (-not $panelRun -and -not $panelMember) {
    foreach ($pn in @('PanelSize', 'PanelOrder', 'PanelSeed', 'Roles')) {
        if ($PSBoundParameters.ContainsKey($pn)) { Stop-WithError "-$pn goes with -Panel (or -PanelAll) only." }
    }
}
if ($PSBoundParameters.ContainsKey('PanelSize')) {
    if ($PanelAll) { Stop-WithError "-PanelSize does not go with -PanelAll: -PanelAll runs every eligible member (drop one of them)." }
    if ($PanelSize -lt 1) { Stop-WithError "-PanelSize must be 1 or more (got $PanelSize); leave it out for the purpose's size." }
}
$PanelOrder = $PanelOrder.Trim().ToLowerInvariant()
if ($PanelOrder -and @('roster', 'routed') -notcontains $PanelOrder) { Stop-WithError "-PanelOrder must be roster or routed (got '$PanelOrder')." }
if (-not $PanelOrder) { $PanelOrder = 'routed' }
$PanelSeed = $PanelSeed.Trim()
if ($PanelSeed -and $PanelSeed -notmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$') { Stop-WithError "-PanelSeed must be a number or a token (letters, digits, dot, dash, underscore, colon; got '$PanelSeed')." }
$topicParse = ConvertTo-SlugList -Values $Topic -What '-Topic'
if ($topicParse.Error) { Stop-WithError "$($topicParse.Error)." }
$topicList = [string[]]$topicParse.Items
$Role = $Role.Trim()
$roleList = [string[]]@()
$rolesGiven = (@($Roles | Where-Object { $_ -and $_.Trim() }).Count -gt 0)
if ($Role -and $rolesGiven) { Stop-WithError "-Role and -Roles exclude each other: -Role gives the reviewer (every member) one role, -Roles one role per member." }
if ($Role) {
    $roleParse = ConvertTo-SlugList -Values @($Role) -What 'role'
    if ($roleParse.Error) { Stop-WithError "-Role: $($roleParse.Error)." }
    if (@($roleParse.Items).Count -ne 1) { Stop-WithError "-Role takes one role (one role per member: -Panel -Roles <a>,<b>)." }
    $Role = $roleParse.Items[0]
}
if ($rolesGiven) {
    $roleParse = ConvertTo-SlugList -Values $Roles -What 'role'
    if ($roleParse.Error) { Stop-WithError "-Roles: $($roleParse.Error)." }
    $roleList = [string[]]$roleParse.Items
}
$requireGiven = (@($Require | Where-Object { $_ -and $_.Trim() }).Count -gt 0)
# (wave 27, R13 D6) the coordinator's brief prefix: -BriefPrefix, else CODEX_CONSULT_BRIEF_PREFIX,
# else claude. A reply prefix of the bridge (an engine's: codex, agy, muse) is refused - a brief
# named like a reply would read as the reviewer's.
$briefPrefixSource = '-BriefPrefix'
$BriefPrefix = ([string]$BriefPrefix).Trim()
if (-not $BriefPrefix) {
    $BriefPrefix = ([string]$env:CODEX_CONSULT_BRIEF_PREFIX).Trim()
    $briefPrefixSource = 'CODEX_CONSULT_BRIEF_PREFIX'
    if (-not $BriefPrefix) { $BriefPrefix = 'claude'; $briefPrefixSource = 'the default' }
}
$replyPrefixes = [string[]]@($script:EngineNames | ForEach-Object { [string](Get-EngineSpec -Name $_).Prefix })
if ($replyPrefixes -contains $BriefPrefix) {
    Stop-WithError "the brief prefix '$BriefPrefix' ($briefPrefixSource) is a reply prefix: the bridge names its replies handoffs/<NN>-<$($replyPrefixes -join '|')>-<slug>.*; give the coordinator's briefs a prefix of their own (the default: claude); nothing was started."
}
if ($BriefPrefix -cnotmatch '^[a-z][a-z0-9-]{0,31}$') {
    Stop-WithError "the brief prefix '$BriefPrefix' ($briefPrefixSource) must be a lowercase slug (a letter, then letters, digits or dashes; at most 32 characters); nothing was started."
}
# (wave 28, R17) the telemetry switch of this run: -Telemetry on|off, else CODEX_CONSULT_TELEMETRY
# (unset: on); a panel member takes its panel run's
$Telemetry = ([string]$Telemetry).Trim().ToLowerInvariant()
if ($Telemetry -and @('on', 'off') -notcontains $Telemetry) { Stop-WithError "-Telemetry must be on or off (got '$Telemetry'); leave it out for CODEX_CONSULT_TELEMETRY (unset: on)." }
$telemetrySwitch = Get-TelemetrySwitch -Override $Telemetry

# ----------------------------------------------------------------------------- validation

$validEfforts = @('low', 'medium', 'high', 'xhigh')
if ($Effort) {
    $Effort = $Effort.Trim().ToLowerInvariant()
    if ($validEfforts -notcontains $Effort) {
        Stop-WithError "-Effort must be one of: $($validEfforts -join ', ') (got '$Effort')."
    }
}
$Purpose = $Purpose.Trim().ToLowerInvariant()
if ($Purpose -and $validPurposes -notcontains $Purpose) {
    Stop-WithError "-Purpose must be one of: $($validPurposes -join ', ') (got '$Purpose')."
}
# A chore is a plain-text consultation, exactly like -Raw: no --output-schema, no schema in
# the prompt, no findings bookkeeping (ledger structured false, schema '', schema_transport '').
if ($Purpose -eq 'chore') { $Raw = $true }
if ($PSBoundParameters.ContainsKey('MaxWords') -and $MaxWords -le 0) {
    Stop-WithError "-MaxWords must be greater than 0 (got $MaxWords)."
}
# (wave 24, T1) the timeout: an explicit -TimeoutSec wins, else the purpose's default; a panel
# member inherits the panel run's resolution (value and source).
$timeoutSource = 'explicit'
$continueGiven = $PSBoundParameters.ContainsKey('ContinueSec')
if ($panelMember) { $timeoutSource = $memberTimeoutSource }
elseif (-not $PSBoundParameters.ContainsKey('TimeoutSec')) {
    $TimeoutSec = [int]$presetTimeout[$Purpose]
    $timeoutSource = 'purpose'
}
if ($TimeoutSec -le 0) {
    Stop-WithError "-TimeoutSec must be greater than 0 (got $TimeoutSec)."
}
if ($PSBoundParameters.ContainsKey('ContinueSec') -and $ContinueSec -lt 0) {
    Stop-WithError "-ContinueSec must be 0 (no continuation after a timeout kill) or a number of seconds (got $ContinueSec)."
}
if ($ContinueSec -lt 0) { $ContinueSec = [Math]::Min($TimeoutSec, 900) }
# (wave 26b, D12) -StallSec: 0 = off, else seconds; unset (-1) = the roster entry's stall_sec, else
# 900 (resolved once the reviewer is known; a panel resolves it per member)
$stallGiven = $PSBoundParameters.ContainsKey('StallSec')
if ($stallGiven -and $StallSec -lt 0) {
    Stop-WithError "-StallSec must be 0 (no stall cut) or a number of seconds without an event (got $StallSec)."
}
$Range = $Range.Trim()
if ($Range -and $rangePurposes -notcontains $Purpose) {
    Stop-WithError "-Range goes with -Purpose diff-review or acceptance (got $(if ($Purpose) { "-Purpose $Purpose" } else { 'no -Purpose' })): it sizes a review of that range."
}
if ($Sandbox -eq 'danger-full-access') {
    Stop-WithError "-Sandbox danger-full-access is refused: consultations run without write access to your machine."
}
$validSandboxes = @('read-only', 'workspace-write')
if ($validSandboxes -notcontains $Sandbox) {
    Stop-WithError "-Sandbox must be one of: $($validSandboxes -join ', ') (got '$Sandbox')."
}
$validModes = @('', 'new', 'resume', 'fork')
if ($validModes -notcontains $Mode) {
    Stop-WithError "-Mode must be one of: new, resume, fork (got '$Mode')."
}
if (-not $Brief -and -not $Prompt) {
    Stop-WithError "Give at least one of -Brief <path> or -Prompt <text>."
}
if ($ReplyName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Stop-WithError "-ReplyName must be a slug (letters, digits, dot, dash, underscore)."
}
if ($Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Stop-WithError "-Task must be a slug (letters, digits, dot, dash, underscore)."
}
$Provider = $Provider.Trim()
$Model = $Model.Trim()
$Thread = $Thread.Trim()
$NativeEffort = $NativeEffort.Trim()
if ($NativeEffort) {
    if ($Effort) {
        Stop-WithError "-Effort and -NativeEffort exclude each other: -Effort is mapped through the endpoint's effort vocabulary, -NativeEffort is sent verbatim."
    }
    if ($NativeEffort -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        Stop-WithError "-NativeEffort must be a plain token (letters, digits, dot, dash, underscore; got '$NativeEffort')."
    }
}
if ($Thread -and $Mode -eq 'new') {
    Stop-WithError "-Thread needs -Mode fork or resume (-Mode new always starts a fresh thread)."
}
# -CodexConfig: one comma-separated string (powershell -File) is split only at a comma
# that starts the next key=, so a value like [1,2] stays whole; ~ is expanded and bare
# values are quoted (ConvertFrom-CodexConfigItems - a roster entry's codex_config follows
# the same rules). The expanded items are what goes to codex and to the ledger.
$extraConfig = New-Object System.Collections.Generic.List[string]
$cfgParse = ConvertFrom-CodexConfigItems -Values $CodexConfig -Label '-CodexConfig'
if ($cfgParse.Error) { Stop-WithError $cfgParse.Error }
foreach ($ci in $cfgParse.Items) { $extraConfig.Add($ci) }
$extraConfigSource = ''
if ($extraConfig.Count -gt 0) { $extraConfigSource = '-CodexConfig' }

# (NB: never $schemaTransport for this - PowerShell names are case-insensitive, that is the
# resolved transport below and would silently clobber the parameter)
$transportOverride = $SchemaTransport.Trim().ToLowerInvariant()
if ($transportOverride) {
    if (@('output-schema', 'prompt-only', 'native') -notcontains $transportOverride) {
        Stop-WithError "-SchemaTransport must be output-schema or prompt-only (got '$transportOverride'); omit it to use what caps-v1 declares for the endpoint."
    }
    if ($Raw) { Stop-WithError "-SchemaTransport does not apply to -Raw$(if ($Purpose -eq 'chore') { ' (-Purpose chore is a plain-text consultation)' }) (a raw consultation sends no reply schema)." }
}
if ($FormatRetry -ne 0 -and $FormatRetry -ne 1) {
    Stop-WithError "-FormatRetry must be 0 or 1 (got $FormatRetry): at most one format-repair turn per consultation."
}
$Engine = $Engine.Trim().ToLowerInvariant()
if ($Engine -and $script:EngineNames -notcontains $Engine) {
    Stop-WithError "-Engine must be one of: $($script:EngineNames -join ', ') (got '$Engine')."
}
if ($DenialRetry -ne 0 -and $DenialRetry -ne 1) {
    Stop-WithError "-DenialRetry must be 0 or 1 (got $DenialRetry): at most one denial-retry turn per consultation."
}
$EngineExe = $EngineExe.Trim()
if ($MaxModelSteps -lt 0) { Stop-WithError "-MaxModelSteps must be a positive integer (got $MaxModelSteps); omit it for the muse CLI's own default." }
# The launchers of the engines other than codex (engine -> path, '' = not found), resolved on
# first use; -EngineExe names the launcher of the SELECTED engine (wave 23, D3 - bound once the
# roster is read, below; codex has -CodexExe).
$engineLaunchers = @{}
$engineExeEngine = ''
# (never $formatRetry: PowerShell names are case-insensitive)
$repairEnabled = ($FormatRetry -eq 1 -and -not $Raw)

# The reviewer roster (CODEX_CONSULT_ROSTER - it must exist; none = no roster - else
# <codex home>/codex-consult-roster.json). No default file: no roster, everything as before. A file that is not a usable roster refuses the
# run, -DryRun included (fail-closed: an existing roster is never ignored).
$roster = Read-ReviewerRoster
if ($roster.Error) { Stop-WithError $roster.Error }
if ($panelRun) {
    if ($roster.Disabled) { Stop-WithError "-Panel needs a reviewer roster, and CODEX_CONSULT_ROSTER=none switches it off." }
    if (-not $roster.Exists) { Stop-WithError "-Panel needs a reviewer roster: '$($roster.Path)' does not exist (CODEX_CONSULT_ROSTER, else <codex home>/codex-consult-roster.json)." }
    if ($Provider) { Stop-WithError "-Panel seats reviewers of the roster and does not take -Provider (for one reviewer, drop -Panel; to insist on one in the panel: -Require)." }
    if ($Thread) { Stop-WithError "-Panel does not take -Thread: each member forks the newest thread of its own lineage (or starts one)." }
    if ($Mode -eq 'resume') { Stop-WithError "-Panel does not take -Mode resume: each member forks the newest thread of its own lineage (or starts one); -Mode new starts fresh threads for all." }
}
if ($panelMember -and -not $roster.Exists) { Stop-WithError "the reviewer roster '$($roster.Path)' is gone; this panel member was not started." }
# (wave 27, R13 D3/D4) The coordinator, resolved ONCE per consultation: here for a run the
# coordinator started (CODEX_CONSULT_COORDINATOR parsed by the reviewer matcher - a value that does
# not parse is refused before anything starts; the host inferred as a hint), and the host markers
# of its environment that no engine child gets (child_env_scrubbed). A panel member takes its panel
# run's (-PanelSpec), a detached run its foreground's (the status file: the background's own
# environment has no markers left) - never inferred again downstream.
$coordinatorRecord = $null
$childEnvScrubbed = [string[]]@()
$coordinatorFrom = ''
if ($panelMember -and $null -ne $panelMember.PSObject.Properties['coordinator']) {
    $coordinatorRecord = $panelMember.coordinator
    $childEnvScrubbed = [string[]]@(@(Get-PropertyValue $panelMember 'child_env_scrubbed' @()) | Where-Object { $_ } | ForEach-Object { [string]$_ })
    $coordinatorFrom = 'panel'
} elseif ($script:DetachRun -and $null -ne (Get-PropertyValue $script:DetachRun.Record 'coordinator' $null)) {
    $coordinatorRecord = $script:DetachRun.Record.coordinator
    $childEnvScrubbed = [string[]]@(@(Get-PropertyValue $script:DetachRun.Record 'child_env_scrubbed' @()) | Where-Object { $_ } | ForEach-Object { [string]$_ })
    $coordinatorFrom = 'detached'
}
if (-not $coordinatorRecord) {
    # (wave 27c, D9) resolved to a triple through the seated reviewer's rules - a model-less entry or
    # label takes the model the bridge would run (the Codex config's)
    $coordinatorResolved = Resolve-CoordinatorIdentity -Value ([string]$env:CODEX_CONSULT_COORDINATOR) -Roster $roster -Defaults (Get-CodexConfigDefaults)
    if ($coordinatorResolved.Error) { Stop-WithError $coordinatorResolved.Error }
    $coordinatorRecord = $coordinatorResolved.Record
    $childEnvScrubbed = Get-HostMarkerNames
    $coordinatorFrom = 'entry'
}
# (wave 27c, D12) a '#n' that names no roster position here: recorded unresolved, warned, the run
# goes on - every ledger entry of the run says so (a panel member's and a detached run's too)
$coordinatorWarnings = [string[]]@()
$coordinatorUnresolved = [string](Get-PropertyValue $coordinatorRecord 'unresolved' '')
if ($coordinatorUnresolved) { $coordinatorWarnings = [string[]]@("CODEX_CONSULT_COORDINATOR '$coordinatorUnresolved' names no roster position here - the coordinator is not known; no self-review warning can be given") }
# (wave 27c, D11) a coordinator no roster entry matches: said on the console (and the dry run's
# coordinator line), never refused - ledger coordinator.in_roster false
if ($coordinatorFrom -eq 'entry' -and (-not $DryRun -or $detachForeground) -and -not $coordinatorUnresolved -and (Get-PropertyValue $coordinatorRecord 'in_roster' $null) -eq $false) {
    Write-Host "coordinator: $(Format-CoordinatorId $coordinatorRecord) (not in the roster - no reviewer can match it)"
}
# (wave 26, D7) -Require: a panel, or a single run of a chosen reviewer (-Provider)
if ($requireGiven -and -not $panelRun -and -not $Provider) {
    Stop-WithError "-Require goes with -Panel, or with -Provider (a single run of a chosen reviewer); a roster walk takes whichever reviewer is available."
}
if ($Provider -and -not $Model) {
    # The roster entry of that provider may supply the model.
    $providerEntry = Find-RosterEntry -Roster $roster -Provider $Provider
    if (-not ($providerEntry -and $providerEntry.Model)) {
        Stop-WithError "-Provider needs -Model: the bridge cannot know which model a provider serves by default (e.g. -Provider $Provider -Model <model>)."
    }
}
# -EngineExe names the launcher of the SELECTED engine other than codex (wave 23, D3;
# Resolve-EngineExeBinding): -Engine's, else the -Provider's roster entry's, else the only such
# engine of the roster. A -Thread run checks it against the thread's engine below.
if ($EngineExe) {
    $exeBinding = Resolve-EngineExeBinding -Engine $Engine -Roster $roster -Provider $Provider -Model $Model
    if ($exeBinding.Error) { Stop-WithError "$($exeBinding.Error)." }
    $engineExeEngine = [string]$exeBinding.Engine
    $engineLaunchers[$engineExeEngine] = [string](Resolve-EngineLauncher -Engine $engineExeEngine -Explicit $EngineExe)
}

# Explicit -Effort / -MaxWords win over the purpose preset.
$effortResolved = $presetEffort[$Purpose]
if ($Effort) { $effortResolved = $Effort }
$maxWordsResolved = $presetWords[$Purpose]
if ($MaxWords -gt 0) { $maxWordsResolved = $MaxWords }
$purposeLabel = if ($Purpose) { $Purpose } else { 'none' }
$verdictRule = if (@('acceptance', 'diff-review') -contains $Purpose) { 'ACCEPT, HOLD or REJECT' } else { 'ADVISE' }

# ----------------------------------------------------------------------------- repo + task

$callerCwd = (Get-Location).Path
$repoRoot = Resolve-RepoRoot -Cwd $callerCwd
$collabRoot = Resolve-CollabRoot -RepoRoot $repoRoot -CollabDir $CollabDir

$taskDir = Join-Path $collabRoot $Task
$handoffsDir = Join-Path $taskDir 'handoffs'
# (wave 26b, D16) the new prompt's size for a reviewer with a roster context_tokens, estimated
# before any reviewer is chosen: (the ask + the brief it points to) / 4 characters a token
$promptEstimateChars = ([string]$Prompt).Length
if ($Brief) {
    foreach ($base in @($(if ([IO.Path]::IsPathRooted($Brief)) { '' } else { $callerCwd }), $repoRoot)) {
        $bp = $(if ($base) { Join-Path $base $Brief } else { $Brief })
        if (Test-Path -LiteralPath $bp -PathType Leaf) { $promptEstimateChars += [int](Get-Item -LiteralPath $bp).Length; break }
    }
}
$promptEstimate = [int][Math]::Ceiling($promptEstimateChars / 4.0)
# (wave 26, R16) the role blocks - <CollabDir>/roles/<name>.md, else the plugin's
# templates/role-<name>.md - are resolved now: an unknown role refuses the run, nothing started
$pluginRoot = Split-Path -Parent $PSScriptRoot
$roleInfo = $null
if ($Role) {
    $roleInfo = Resolve-RoleFile -Name $Role -CollabRoot $collabRoot -PluginRoot $pluginRoot
    if ($roleInfo.Error) { Stop-WithError "-Role: $($roleInfo.Error)$(if ($panelMember) { '; this panel member was not started' })." }
}
foreach ($rn in $roleList) {
    $ri = Resolve-RoleFile -Name $rn -CollabRoot $collabRoot -PluginRoot $pluginRoot
    if ($ri.Error) { Stop-WithError "-Roles: $($ri.Error)." }
}
$sessionsPath = Join-Path $taskDir 'sessions.json'
$findingsPath = Join-Path $taskDir 'findings.json'
$lockPath = Join-Path $taskDir '.consult.lock'
$pendingPath = Get-PendingPath -TaskDir $taskDir
$runStarted = Get-IsoTimestamp

# (wave 24, T1) -Range: `git diff --shortstat <range>` once - a panel member takes its panel
# run's numbers; an unknown range is refused here (nothing locked, nothing started). The ledger's
# `range`; the size warning goes to warnings[] (console, handoff header).
$rangeStat = $null
$rangeRecord = $null
$rangeWarning = ''
if ($Range) {
    if ($panelMember -and $null -ne $memberRangeStat) {
        $rangeStat = [pscustomobject]@{ Range = $Range; Files = [int](Get-PropertyValue $memberRangeStat 'files' 0); Insertions = [int](Get-PropertyValue $memberRangeStat 'insertions' 0); Deletions = [int](Get-PropertyValue $memberRangeStat 'deletions' 0); Lines = [int](Get-PropertyValue $memberRangeStat 'lines' 0); Error = '' }
    } else {
        $rangeStat = Get-RangeStat -Root $repoRoot -Range $Range
        if ($rangeStat.Error) { Stop-WithError "$($rangeStat.Error); nothing was started." }
    }
    $rangeRecord = [pscustomobject]@{ spec = $Range; files = $rangeStat.Files; insertions = $rangeStat.Insertions; deletions = $rangeStat.Deletions; lines = $rangeStat.Lines }
    if ($rangeStat.Lines -gt $rangeWarnLines -and $TimeoutSec -lt $rangeWarnTimeout) {
        $rangeWarning = "a range of $($rangeStat.Lines) lines with a $TimeoutSec s timeout: pass -TimeoutSec or a reading plan in the brief"
    }
}
$rangeText = $(if ($rangeStat) { "the range changes $($rangeStat.Files) file$(if ($rangeStat.Files -ne 1) { 's' }), $($rangeStat.Lines) line$(if ($rangeStat.Lines -ne 1) { 's' })" } else { '' })

# A -Panel member (0.4.x wave 21). Its recovery record .consult.pending-<NN>.json was written
# `reserved` by the panel run before it launched this member: that record - not the lock file -
# is the member's proof of a live parent owning the task (D6). It must name this panel, this n
# and NN and the parent (pid + start time, also as its writer); otherwise the member refuses,
# nothing started. Then the member rewrites the record with its own pid + start time (D1) and
# only THEN checks that the parent is alive (F07-1, F11-6): from the rewrite on the record reads
# active for as long as this process runs, and a parent that is gone at the check - even one that
# died before the rewrite, when a new run may already have read the record as inactive - stops
# the member right there, its record withdrawn, nothing started. A member that goes on had a
# live parent AFTER its record named it, so there is no moment in which the record reads
# inactive while the member runs. A dry-run member has no record.
$pendingRecord = $null
if ($panelMember) {
    $pendingPath = Get-MemberPendingPath -TaskDir $taskDir -Nn $memberNn
    if (-not $DryRun) {
        $own = Read-PendingFile -Path $pendingPath
        if ($own.Error) { Stop-WithError "$($own.Error) This panel member was not started." }
        if (-not $own.Exists) { Stop-WithError "this panel member's recovery record '$pendingPath' does not exist (the panel run writes it before it launches a member); this panel member was not started." }
        $ownRecord = $own.Record
        $ownPanel = Get-PropertyValue $ownRecord 'panel' $null
        $mismatch = New-Object System.Collections.Generic.List[string]
        $compare = { param($Name, $InRecord, $InSpec) if ([string]$InRecord -cne [string]$InSpec) { $mismatch.Add("$Name $(if ([string]$InRecord) { [string]$InRecord } else { '(none)' }) in the record, $InSpec in the spec") } }
        if ($null -eq $ownPanel) { $mismatch.Add('the record names no panel') }
        else {
            & $compare 'panel id' (Get-PropertyValue $ownPanel 'id' '') ([string]$panelMember.id)
            & $compare 'parent pid' (Get-PropertyValue $ownPanel 'parent_pid' '') $memberParentPid
            & $compare 'parent start time' (ConvertTo-JsonText (Get-PropertyValue $ownPanel 'parent_start_time' '')) $memberParentStart
        }
        & $compare 'n' (Get-PropertyValue $ownRecord 'n' '') $memberN
        & $compare 'nn' (Get-PropertyValue $ownRecord 'nn' '') $memberNn
        & $compare 'state' (Get-PropertyValue $ownRecord 'state' '') 'reserved'
        & $compare 'writer pid' (Get-PropertyValue $ownRecord 'pid' '') $memberParentPid
        if ($mismatch.Count -gt 0) {
            Stop-WithError "this panel member's recovery record '$pendingPath' does not match its spec ($($mismatch.ToArray() -join '; ')); this panel member was not started."
        }
        $ownRecord.pid = $PID
        $ownRecord | Add-Member -NotePropertyName 'start_time' -NotePropertyValue ([string](Get-ProcessStartIso -ProcessId $PID)) -Force
        $ownRecord.host = [Environment]::MachineName
        $ownRecord.note = "review panel member (the panel run is pid $memberParentPid)"
        try { Write-PendingFile -Path $pendingPath -Record $ownRecord } catch {
            Stop-WithError "could not rewrite this panel member's recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); this panel member was not started."
        }
        $pendingRecord = $ownRecord
        # TEST HOOK: CODEX_CONSULT_TEST_MEMBER_PAUSE_MS=<ms> - a pause between the rewrite and the
        # parent check (the harness kills the parent inside it).
        $memberPause = 0
        if ([int]::TryParse((Get-TestHookValue 'CODEX_CONSULT_TEST_MEMBER_PAUSE_MS'), [ref]$memberPause) -and $memberPause -gt 0) { Start-Sleep -Milliseconds $memberPause }
        if (-not (Test-PidAlive -ProcessId $memberParentPid -StartTime $memberParentStart)) {
            $rmError = Remove-PendingFile -Path $pendingPath
            Stop-WithError "the review panel run that launched this member (pid $memberParentPid) is gone; this panel member was not started - nothing was started and its recovery record '$pendingPath' $(if ($rmError) { "could not be withdrawn ($rmError; the next run consumes it)" } else { 'was withdrawn' })."
        }
    }
}

$codexExePath = Resolve-CodexLauncher -Explicit $CodexExe

$codexVersion = 'unknown'
if ($codexExePath) {
    # (wave 27, R13 D4) the probe, too, runs without the coordinator's host markers
    $versionHidden = $null
    # (wave 27c, D3/D4) a hide that fails skips the probe (the version stays unknown) - said once
    $versionSkip = ''
    try { $versionHidden = Hide-HostMarkers -TestVars } catch { $versionSkip = ConvertTo-OneLine $_.Exception.Message }
    if ($versionSkip) { $script:ProbeWarnings.Add("a launcher probe was skipped (codex --version): $versionSkip") }
    else {
        try {
            $v = & $codexExePath --version 2>$null
            if ($v) { $codexVersion = ([string]@($v)[0]).Trim() }
        } catch { } finally { Restore-HostMarkers -Saved $versionHidden }
    }
}
# "codex-cli 0.155.1" -> "0.155.1" for the prose header; sessions.json keeps the full string.
$codexVersionShort = $codexVersion -replace '^codex-cli\s+', ''
$harness = if ($codexVersion -match '^codex-cli\s') { $codexVersion } else { "codex-cli $codexVersion" }

# (wave 28, R17) the first run after an install - a real run the coordinator started, or the
# foreground of -Detach; never a dry run, a panel member or a detached background - prints the
# telemetry notice once (telemetry on only; the marker <codex home>/telemetry-notice-<version>)
if ((-not $DryRun -or $detachForeground) -and -not $panelMember -and -not $script:DetachRun) { Show-TelemetryNotice -Switch $telemetrySwitch }

# ----------------------------------------------------------------------------- review panel (-Panel)
#
# The roster is walked like the single-reviewer walk, without stopping at the first available
# entry (Select-PanelMembers). Each member then runs as a complete consultation of its own - a
# child run of this script (-PanelSpec) in a process of its own: own preflight, own recovery
# record .consult.pending-<NN>.json, own parent thread (the newest of its lineage, or a new one;
# -Mode new: new for all), own consultation id, handoff files
# handoffs/NN-<engine>-<ReplyName>-<provider>.md and ledger entry with the `panel` record.
# 0.4.x wave 21 (ROADMAP R11) - the members run IN PARALLEL; this run:
#   1. takes the task lock (.consult.lock; its informational record names the panel) and holds
#      it until the summary is printed: no other consultation or status update of the task in
#      between (D12);
#   2. judges EVERY recovery record of the task first: an active one refuses the panel, the
#      inactive ones are consumed (numbering skips past them; D5);
#   3. assigns n and NN to every member up front, in seat order (wave 26: panel.routing.picked -
#      the roster order unless the panel is routed; member k: n0 + k - 1, NN0 + k - 1), so the
#      files and the ledger keep that order whatever finishes first;
#   4. writes every member's `reserved` record (the panel, n, NN, this process as writer and
#      parent) BEFORE it launches any member - a member proves its parent with it, rewrites it
#      with its own pid and only then checks that the parent lives (D6, D1, F07-1);
#   5. launches the members as processes of their own (Start-Process; console output to files
#      in a temp directory) along the plan of Get-PanelPlan - members of different endpoints at
#      once, of one endpoint one after another unless the roster's "parallel" raises it,
#      -PanelConcurrency caps the total (D8) - polls them, prints one line per finished member
#      and stops a member that outlives its guard (its timeout + its format-repair and
#      denial-retry budgets + (wave 24) its timeout continuation's -ContinueSec + 60 s write
#      lock + 120 s, D11; Get-PanelMemberGuard);
#   6. prints every member's console output in roster order, the summary with the panel's wall
#      clock, and removes the records of members that never started anything (D5).
# A member that fails or is refused does not stop the others; with -PanelConcurrency 1 a member
# that leaves surviving processes stops the rest (recorded as skipped, exit 1; F15-3). Exit 0
# only when every member produced a usable reply (-DryRun: when every member's plan could be
# made; a dry run writes nothing and takes no lock).

# The ledger entry a panel member recorded (the task's sessions.json, read tolerantly).
function Find-PanelEntry {
    param([string]$Path, [string]$PanelId, [int]$Position)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $data = $null
    try { $data = ConvertFrom-Json -InputObject (Read-SharedText -Path $Path) } catch { return $null }
    $found = $null
    foreach ($c in @(Get-PropertyValue (Get-PropertyValue $data 'codex' $null) 'consults' @())) {
        $pr = Get-PropertyValue $c 'panel' $null
        if ($null -ne $pr -and [string](Get-PropertyValue $pr 'id' '') -eq $PanelId -and [string](Get-PropertyValue $pr 'position' '') -eq [string]$Position) { $found = $c }
    }
    return $found
}

function Format-PriorCounts {
    param($Entry)
    $prior = @(Get-PropertyValue $Entry 'prior_findings' @() | Where-Object { $_ })
    if ($prior.Count -eq 0) { return 'prior: none' }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($st in $script:PriorStatuses) {
        $n = @($prior | Where-Object { [string](Get-PropertyValue $_ 'status' '') -eq $st }).Count
        if ($n -gt 0) { $parts.Add("$n $st") }
    }
    return 'prior: ' + ($parts.ToArray() -join ', ')
}

# The console output of a member (its stdout, then its stderr file; UTF-8) as lines.
function Read-PanelMemberOutput {
    param($Slot)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($Slot.OutPath, $Slot.ErrPath)) {
        if (-not $f) { continue }
        $t = Read-SharedText -Path $f
        if (-not $t -or -not $t.Trim()) { continue }
        foreach ($l in ($t.TrimEnd() -split "`r?`n")) { $lines.Add($l) }
    }
    return , ([string[]]$lines.ToArray())
}

# Starts one member: its spec (base64 of UTF-8 JSON on the command line, as before), its console
# output to <temp>/codex-consult-panel-<id>/<NN>.out|.err, stdin from an empty file. Reads the
# panel run's variables; sets the slot's Proc / Watch / State ('running' | 'failed-start').
function Start-PanelMember {
    param($Slot)
    $pm = $Slot.Pm
    # The members whose files this member's agy tree check leaves out (D7): deliberately the
    # UNION of all other slots whenever the plan lets any two members run at once - not only
    # those the scheduler can actually run beside this one (F11-5). That costs no evidence: an
    # ignored path that did not change hides nothing, and one that changed was written by a
    # member running meanwhile (or by this member's own reviewer - the D7 residual the README
    # names: the ignored paths are the task's stores and the other members' handoff names).
    $siblings = @()
    if ($panelPlan.Effective -gt 1) { $siblings = @($panelSlots | Where-Object { $_.K -ne $Slot.K } | ForEach-Object { [string]$_.Nn }) }
    $spec = [pscustomobject]@{
        id                = $panelId
        position          = $Slot.K
        of                = $panelRunners.Count
        members           = $panelMembersRecord
        roster_position   = $pm.Entry.Position
        provider          = $pm.Entry.Provider
        model             = $pm.Entry.Model
        engine            = [string]$pm.Entry.Engine
        skipped           = $panelSkippedRecord
        listed_ids        = [object[]]$panelListed
        n                 = $Slot.N
        nn                = $Slot.Nn
        consult_id        = $Slot.ConsultId
        parent_pid        = $PID
        parent_start_time = $panelParentStart
        sibling_nns       = [object[]]$siblings
        concurrency       = $panelPlan.Effective
        limits            = $panelLimits
        asked             = $panelRoute.SizeAsked
        routing           = $panelRoute.Routing
        role              = $(if ($panelRoleOf.ContainsKey([int]$pm.Entry.Position)) { [string]$panelRoleOf[[int]$pm.Entry.Position] } else { '' })
        roles_note        = $panelRolesNote
        panel_warnings    = [object[]]@($panelWarnings)
        # (wave 27, R13) the coordinator the panel run resolved, and the host markers of its
        # environment - the member never resolves them again
        coordinator        = $coordinatorRecord
        child_env_scrubbed = [object[]]@($childEnvScrubbed)
        args              = [pscustomobject]@{
            collab_dir       = $CollabDir
            mode             = $Mode
            brief            = $Brief
            prompt           = $Prompt
            purpose          = $Purpose
            effort           = $Effort
            sandbox          = $Sandbox
            max_words        = $MaxWords
            timeout_sec      = $Slot.TimeoutSec
            timeout_source   = $Slot.TimeoutSource
            continue_sec     = $Slot.ContinueSec
            stall_sec        = $Slot.StallSec
            range            = $Range
            range_stat       = $rangeRecord
            reply_name       = $Slot.ReplyName
            artifact         = [object[]]@($Artifact)
            raw              = [bool]$Raw
            codex_exe        = $CodexExe
            native_effort    = $NativeEffort
            off_peak_only    = [bool]$OffPeakOnly
            skip_preflight   = [bool]$SkipPreflight
            codex_config     = [object[]]@($CodexConfig)
            schema_transport = $transportOverride
            format_retry     = $FormatRetry
            engine           = $Engine
            engine_exe       = $EngineExe
            denial_retry     = $DenialRetry
            max_model_steps  = $MaxModelSteps
            topics           = [object[]]@($topicList)
            brief_prefix     = $BriefPrefix
            telemetry        = $telemetrySwitch.Text
            dry_run          = [bool]$DryRun
        }
    }
    $specB64 = [Convert]::ToBase64String($script:Utf8NoBom.GetBytes((ConvertTo-Json -InputObject $spec -Depth 8 -Compress)))
    $Slot.OutPath = Join-Path $panelTmp "$($Slot.Nn).out"
    $Slot.ErrPath = Join-Path $panelTmp "$($Slot.Nn).err"
    $argLine = (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $panelSelf, '-Task', $Task, '-PanelSpec', $specB64) | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' '
    try {
        $Slot.Proc = Start-Process -FilePath $panelHost -ArgumentList $argLine -WorkingDirectory $callerCwd -NoNewWindow -PassThru `
            -RedirectStandardOutput $Slot.OutPath -RedirectStandardError $Slot.ErrPath -RedirectStandardInput $panelEmptyIn
        # PS 5.1: touch .Handle right away, or .ExitCode comes back empty (see the run below)
        if ($script:LegacyPS) { try { $null = $Slot.Proc.Handle } catch { } }
        $Slot.Watch = [System.Diagnostics.Stopwatch]::StartNew()
        $Slot.State = 'running'
    } catch {
        $Slot.State = 'failed-start'
        $Slot.StartError = ConvertTo-OneLine $_.Exception.Message
    }
}

# A finished (or stopped) member: its console output, its refusal line, its ledger entry and
# what became of its recovery record.
function Complete-PanelMember {
    param($Slot)
    $Slot.Lines = Read-PanelMemberOutput $Slot
    $last = @($Slot.Lines | Where-Object { $_ -match '^codex-consult: ' }) | Select-Object -Last 1
    $Slot.Refusal = $(if ($last) { $last -replace '^codex-consult: ', '' } else { "exit $($Slot.Exit)" })
    if (-not $DryRun) {
        $Slot.Entry = Find-PanelEntry -Path $sessionsPath -PanelId $panelId -Position $Slot.K
        $rd = Read-PendingFile -Path $Slot.RecordPath
        $Slot.RecordState = $(if ($rd.Exists -and $rd.Record) { [string](Get-PropertyValue $rd.Record 'state' '') } else { '' })
    }
}

# One phrase for a member that ran (the progress line; the summary builds on it).
function Get-PanelMemberStatus {
    param($Slot)
    if ($Slot.State -eq 'killed') { return "killed by the panel after $($Slot.Wall) s (its guard: $($Slot.Guard) s)" }
    if ($Slot.State -eq 'failed-start') { return "failed: could not start the member process - $($Slot.StartError)" }
    if ($DryRun) { if ($Slot.Exit -eq 0) { return 'planned' } else { return "refused: $(ConvertTo-OneLine $Slot.Refusal)" } }
    if ($null -ne $Slot.Entry) { return [string](Get-PropertyValue $Slot.Entry 'bridge_outcome' '') }
    if ($Slot.RecordState -eq 'committing') {
        # D3: the write lock never acquired (the member says so) - or stopped INSIDE its commit
        # (a kill, a crash: its findings may be ORPHAN; the record names the kept reply)
        if ($Slot.Refusal -match '^commit blocked:') { return "commit blocked: $(ConvertTo-OneLine ($Slot.Refusal -replace '^commit blocked:\s*', ''))" }
        return "failed: stopped inside its commit (exit $($Slot.Exit)); findings it wrote have no ledger entry (ORPHAN)"
    }
    return "failed: $(ConvertTo-OneLine $Slot.Refusal)"
}

# (wave 26) Did a member produce a usable reply (it ran, was not killed, its ledger entry says so)?
function Test-PanelSlotUsable {
    param($Slot)
    if ($Slot.State -ne 'done' -or $null -eq $Slot.Entry) { return $false }
    return (Test-UsableOutcome ([string](Get-PropertyValue $Slot.Entry 'bridge_outcome' '')))
}

# (wave 25, D11) A member's state in a detached panel's status file - the classes behind
# Get-PanelMemberStatus: pending | running | usable | failed | killed | blocked | commit_blocked |
# orphan (a roster-skipped entry is `skipped` from the start; a member never started, at the end).
function Get-PanelSlotDetachState {
    param($Slot)
    switch ($Slot.State) {
        'waiting' { return 'pending' }
        'running' { return 'running' }
        'blocked' { return 'blocked' }
        'killed' { return 'killed' }
        'failed-start' { return 'failed' }
    }
    if ($null -ne $Slot.Entry) {
        if (Test-UsableOutcome ([string](Get-PropertyValue $Slot.Entry 'bridge_outcome' ''))) { return 'usable' }
        return 'failed'
    }
    if ($Slot.RecordState -eq 'committing') {
        if ($Slot.Refusal -match '^commit blocked:') { return 'commit_blocked' }
        return 'orphan'
    }
    return 'failed'
}

if ($panelRun) {
    # What would make every member fail the same way is refused once, up front.
    if ($Brief) {
        $briefProbe = $Brief
        if (-not [IO.Path]::IsPathRooted($briefProbe)) {
            foreach ($base in @($callerCwd, $repoRoot)) {
                if (Test-Path -LiteralPath (Join-Path $base $briefProbe) -PathType Leaf) { $briefProbe = Join-Path $base $briefProbe; break }
            }
        }
        if (-not (Test-Path -LiteralPath $briefProbe -PathType Leaf)) {
            Stop-WithError "brief '$Brief' not found (this script never writes briefs; write it first)."
        }
    }
    # (-Detach: the refusals a real run makes before its lock are made in the foreground too - D2)
    if ((-not $DryRun -or $detachForeground) -and -not $codexExePath -and @($roster.Entries | Where-Object { $_.Engine -eq 'codex' -and (-not $Engine -or $Engine -eq 'codex') }).Count -gt 0) {
        Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
    }
    $panelConfig = Read-CodexConfigSubset -Path (Get-CodexConfigPath)
    $panelClock = Get-ConsultClock -Peek
    if ($panelClock.Error) { Stop-WithError $panelClock.Error }
    $panelAllConsults = Read-AllTaskConsults -CollabRoot $collabRoot
    $panelSelection = Select-PanelMembers -Roster $roster -Config $panelConfig -Consults $panelAllConsults -Launcher ([string]$codexExePath) -LoginCache @{} -UtcNow $panelClock.Now.UtcDateTime -OpenAiBaseUrl ([string]$env:OPENAI_BASE_URL) -Model $Model -Purpose $Purpose -All:$PanelAll -SkipPreflight:$SkipPreflight -Engine $Engine -EngineLaunchers $engineLaunchers -EstimateTokens $promptEstimate
    $panelEntries = @($panelSelection.Members)
    if ($panelEntries.Count -eq 0) { Stop-WithError $panelSelection.Error }
    # (wave 26, D7) the required reviewers - -Require, else the roster's "require" for the purpose -
    # judged with the roster walk's verdict: one that is out (or not in this panel) refuses the
    # panel before anything starts, exit 5; one that only the weighty (or light) gate held back
    # takes part.
    $panelRequired = Resolve-RequiredReviewers -Roster $roster -Require $Require -Purpose $Purpose -Explicit:$requireGiven -UseRoster
    if ($panelRequired.Error) { Stop-WithError "$($panelRequired.Error)." }
    $requiredProblems = New-Object System.Collections.Generic.List[string]
    foreach ($reqPos in $panelRequired.Positions) {
        $reqPm = @($panelEntries | Where-Object { [int]$_.Entry.Position -eq [int]$reqPos }) | Select-Object -First 1
        if (-not $reqPm) {
            $reqEntry = @($roster.Entries | Where-Object { [int]$_.Position -eq [int]$reqPos }) | Select-Object -First 1
            $reqFilters = @(@($(if ($Engine) { "-Engine $Engine" }), $(if ($Model) { "-Model $Model" })) | Where-Object { $_ }) -join ' '
            $requiredProblems.Add("#$reqPos $(if ($reqEntry.Model) { Format-ReviewerLineage -Provider $reqEntry.Provider -Model $reqEntry.Model -Engine $reqEntry.Engine } else { $reqEntry.Provider }) (not in this panel: $reqFilters)")
            continue
        }
        if ($reqPm.State -eq 'skipped' -and @('weighty', 'light') -notcontains [string]$reqPm.SkipKind) { $requiredProblems.Add((Format-RequiredOutage -Member $reqPm -UtcNow $panelClock.Now.UtcDateTime)) }
    }
    if ($requiredProblems.Count -gt 0) {
        Stop-WithError "required reviewer$(if ($requiredProblems.Count -ne 1) { 's' }) not available ($($panelRequired.Source)): $($requiredProblems.ToArray() -join '; '); nothing was started - wait for $(if ($requiredProblems.Count -ne 1) { 'them' } else { 'it' }), or run without $(if ($panelRequired.Source -eq '-Require') { 'that -Require' } else { 'the requirement (-Require none)' }) (exit 5)." -Code 5
    }
    # (wave 26, R14/R15, D1-D6) the panel's seats: the size (the purpose's, -PanelSize, -PanelAll),
    # the required first, then the draw over the ratings - or the roster order
    $panelSizeSource = 'purpose'
    $panelSizeWanted = Get-PanelDefaultSize $Purpose
    if ($PanelAll) { $panelSizeWanted = 0; $panelSizeSource = '-PanelAll' }
    elseif ($PSBoundParameters.ContainsKey('PanelSize')) { $panelSizeWanted = $PanelSize; $panelSizeSource = '-PanelSize' }
    $panelNonce = $panelClock.Now.UtcDateTime.ToString('yyyy-MM-dd', $script:Invariant)
    $panelNonceSource = 'date'
    if ($PanelSeed) { $panelNonce = $PanelSeed; $panelNonceSource = '-PanelSeed' }
    elseif (((Get-TestHookValue 'CODEX_CONSULT_TEST_PANEL_SEED')).Trim()) { $panelNonce = ((Get-TestHookValue 'CODEX_CONSULT_TEST_PANEL_SEED')).Trim(); $panelNonceSource = 'CODEX_CONSULT_TEST_PANEL_SEED' }
    $panelBriefSha = ''
    if ($Brief) { $panelBriefSha = Get-FileSha256OrMissing -Path $briefProbe }
    $panelRatings = Read-AllTaskRatings -CollabRoot $collabRoot -Consults $panelAllConsults
    $panelRoute = Select-PanelRouting -Members $panelEntries -Size $panelSizeWanted -SizeSource $panelSizeSource -Order $PanelOrder -Ratings $panelRatings -Purpose $Purpose -Topics $topicList -UtcNow $panelClock.Now.UtcDateTime -Task $Task -BriefSha $panelBriefSha -Nonce $panelNonce -NonceSource $panelNonceSource -Required ([int[]]$panelRequired.Positions)
    $panelRunners = @($panelRoute.Picked)
    if ($panelRunners.Count -eq 0) {
        Stop-WithError $(if ($panelSelection.Error) { $panelSelection.Error } else { "no reviewer of the roster '$($roster.Path)' is eligible for this panel; nothing was started (run codex-providers.ps1 for the full picture)" })
    }
    $panelWarnings = [string[]]@($panelRoute.Warnings)
    # (wave 27, R13 D3) a seated member that is the coordinator's own model (its resolved identity):
    # warned here, the dry run too - not in the members' panel_warnings (each member warns in its own
    # ledger entry)
    $panelCoordinatorWarnings = [string[]]@(foreach ($cpm in $panelRunners) {
            # (wave 27c, D9) 'own' (the resolved triple) or 'provider' (no model named: the weaker one)
            $cKind = Get-CoordinatorMatch -Coordinator $coordinatorRecord -Provider ([string]$cpm.Identity.Provider) -Model ([string]$cpm.Identity.Model) -Engine ([string]$cpm.Identity.Engine) -Auth ([string](Get-PropertyValue $cpm.Identity 'Auth' ''))
            if ($cKind) {
                Format-CoordinatorWarning -Kind $cKind -Lineage (Format-ReviewerLineage -Provider $cpm.Identity.Provider -Model $cpm.Identity.Model -Engine ([string]$cpm.Identity.Engine))
            }
        })
    # (wave 26, R16) the members' roles: -Role for every member, -Roles by score rank (D8)
    $panelRoleOf = @{}
    $panelRolesNote = ''
    if ($Role) { foreach ($pm in $panelRunners) { $panelRoleOf[[int]$pm.Entry.Position] = $Role } }
    elseif ($roleList.Count -gt 0) {
        $roleAssign = Select-RoleAssignment -Members $panelRunners -Roles $roleList
        if ($roleAssign.Error) { Stop-WithError "$($roleAssign.Error); nothing was started." }
        $panelRoleOf = $roleAssign.Of
        # (wave 26b, D4) no assignment honours every willingness: the greedy rank order, said
        if ($roleAssign.Note) { $panelRolesNote = $roleAssign.Note; $panelWarnings = [string[]]@(@($panelWarnings) + @($roleAssign.Note)) }
    }
    # -MaxModelSteps goes to the members whose engine has a step cap (muse); none -> refused.
    if ($MaxModelSteps -gt 0 -and @($panelRunners | Where-Object { (Get-EngineSpec ([string]$_.Entry.Engine)).StepsFlag }).Count -eq 0) {
        Stop-WithError "-MaxModelSteps applies to the members of a panel whose engine has a model-step cap (muse --max-model-steps, claude --max-turns); no member of this panel runs such an engine."
    }
    # A launcher every member of an engine would miss is refused once, up front.
    if (-not $DryRun -or $detachForeground) {
        foreach ($panelEngine in @($panelRunners | ForEach-Object { [string]$_.Identity.Engine } | Select-Object -Unique)) {
            if ($panelEngine -ne 'codex' -and -not (Get-EngineLauncher -Engine $panelEngine -Launchers $engineLaunchers)) {
                Stop-WithError "$panelEngine CLI not found on PATH (set -EngineExe <path> or the $((Get-EngineSpec $panelEngine).ExeEnv) environment variable)."
            }
        }
    }
    $panelId = [guid]::NewGuid().ToString()
    $panelShort = $panelId.Substring(0, 8)
    $panelMembersRecord = [object[]]@($panelEntries | ForEach-Object { [pscustomobject]@{ provider = $_.Entry.Provider; model = $_.Identity.Model; state = $_.State; reason = $_.Reason } })
    # (wave 26, D6) an entry that is eligible but got no seat ('not-picked') is no skip
    $panelSkippedRecord = [object[]]@($panelEntries | Where-Object { $_.State -eq 'skipped' } | ForEach-Object { [pscustomobject]@{ provider = $_.Entry.Provider; model = $_.Identity.Model; engine = [string]$_.Entry.Engine; reason = $_.Reason } })
    # The plan (D8): endpoint groups, the roster's "parallel", -PanelConcurrency.
    $panelPlan = Get-PanelPlan -Runners $panelRunners -Parallel $roster.Parallel -Cap $PanelConcurrency
    $panelLimits = [pscustomobject]$panelPlan.Limits
    $panelParentStart = [string](Get-ProcessStartIso -ProcessId $PID)
    $panelSelf = $PSCommandPath
    $panelHost = (Get-Process -Id $PID).Path
    $panelTmp = Join-Path ([IO.Path]::GetTempPath()) "codex-consult-panel-$panelId"
    $panelEmptyIn = Join-Path $panelTmp 'stdin.empty'
    $panelLock = $null
    $panelSlots = New-Object System.Collections.Generic.List[object]
    $panelWatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $DryRun) {
            [void][IO.Directory]::CreateDirectory($handoffsDir)
            $panelLock = Enter-TaskLock -TaskDir $taskDir -Task $Task -Panel $panelId
            if (-not $panelLock.Acquired) { Stop-WithError $panelLock.Message }
        }
        # Every recovery record of the task, judged before anything is written: an active one
        # refuses the panel (a dry run reports it); the others are consumed below.
        $panelPending = Read-TaskPendingRecords -TaskDir $taskDir
        if ($panelPending.Error) { Stop-WithError $panelPending.Error }
        $panelPendingRefusal = ''
        if ($panelPending.Active) {
            if ($DryRun -and -not $detachForeground) { $panelPendingRefusal = [string]$panelPending.Active.Check.Message } else { Stop-WithError $panelPending.Active.Check.Message }
        }
        # The numbers of every member, past everything on disk (a store that does not parse
        # refuses here, before any member starts).
        $panelSessions = Read-JsonStore -Path $sessionsPath
        $panelConsults = @()
        if ($null -ne $panelSessions) { $panelConsults = @(Get-PropertyValue (Get-PropertyValue $panelSessions 'codex' $null) 'consults' @() | Where-Object { $_ }) }
        $panelStore = Read-FindingsFile -Path $findingsPath -Task $Task
        $panelNumbers = Get-NextNumbers -Consults $panelConsults -Store $panelStore -HandoffsDir $handoffsDir -Leftovers @($panelPending.Items | ForEach-Object { $_.Record })
        # The findings every member is shown: those open when the panel starts.
        $panelListed = @()
        if (-not $Raw) {
            $panelListed = @(@($panelStore.findings) | Where-Object { $_ -and $script:OpenStatuses -contains [string](Get-PropertyValue $_ 'status' '') } | ForEach-Object { [string]$_.id })
        }
        $guardHook = 0
        [void][int]::TryParse((Get-TestHookValue 'CODEX_CONSULT_TEST_PANEL_GUARD_SEC'), [ref]$guardHook)
        $slotOf = @{}
        $k = 0
        foreach ($pm in $panelRunners) {
            $k++
            $slug = ($pm.Entry.Provider.ToLowerInvariant() -replace '[^a-z0-9._-]', '-').Trim('-')
            if (-not $slug) { $slug = 'reviewer' }
            $engineK = [string]$pm.Entry.Engine
            if (-not $engineK) { $engineK = 'codex' }
            $nnK = '{0:D2}' -f ([int]$panelNumbers.Nn + $k - 1)
            # The kill guard from the member's own budgets (D11, Get-PanelMemberGuard): its
            # timeout, one format-repair turn and (an engine with a denial retry: agy) one
            # denial-retry turn of min(timeout, 300) s when enabled, (wave 24) the timeout
            # continuation's -ContinueSec, the 60 s write-lock wait, 120 s slack. TEST HOOK:
            # CODEX_CONSULT_TEST_PANEL_GUARD_SEC.
            # (wave 26b, D11) the roster entry's own timeout_sec replaces the purpose default for
            # this member (an explicit -TimeoutSec wins for all); its continuation budget follows
            # it unless -ContinueSec was given
            $slotTimeout = $TimeoutSec
            $slotTimeoutSource = $timeoutSource
            $slotContinue = $ContinueSec
            $entryTimeout = [int](Get-PropertyValue $pm.Entry 'TimeoutSec' 0)
            if ($timeoutSource -ne 'explicit' -and $entryTimeout -gt 0) {
                $slotTimeout = $entryTimeout
                $slotTimeoutSource = 'roster'
                if (-not $continueGiven) { $slotContinue = [Math]::Min($entryTimeout, 900) }
            }
            # (wave 26b, D12) the member's stall cut: -StallSec, else its entry's stall_sec, else 900
            $slotStall = 900
            if ($stallGiven) { $slotStall = $StallSec }
            elseif ([int](Get-PropertyValue $pm.Entry 'StallSec' -1) -ge 0) { $slotStall = [int]$pm.Entry.StallSec }
            $guard = Get-PanelMemberGuard -TimeoutSec $slotTimeout -ContinueSec $slotContinue -Repair:$repairEnabled -DenialRetry:([bool]((Get-EngineSpec $engineK).DenialRetry -and $DenialRetry -eq 1))
            if ($guardHook -gt 0) { $guard = $guardHook }
            $slot = [pscustomobject]@{
                Pm = $pm; K = $k; N = ($panelNumbers.N + $k - 1); Nn = $nnK; Engine = $engineK
                TimeoutSec = $slotTimeout; TimeoutSource = $slotTimeoutSource; ContinueSec = $slotContinue; StallSec = $slotStall; ExternalWaitShown = $false
                ReplyName = "$ReplyName-$slug"; Reply = "handoffs/$nnK-$((Get-EngineSpec $engineK).Prefix)-$ReplyName-$slug.md"
                RecordPath = (Get-MemberPendingPath -TaskDir $taskDir -Nn $nnK); ConsultId = [guid]::NewGuid().ToString()
                Group = [int]$panelPlan.GroupOf[[int]$pm.Entry.Position]; Guard = $guard
                State = 'waiting'; Proc = $null; Watch = $null; Exit = $null; Wall = 0; OutPath = ''; ErrPath = ''
                Entry = $null; Refusal = ''; RecordState = ''; RecordKept = $false; NotStarted = ''; StartError = ''; Lines = [string[]]@()
            }
            $panelSlots.Add($slot)
            $slotOf[[int]$pm.Entry.Position] = $slot
        }
        # (wave 26b, D13) the endpoint fingerprints of every endpoint group (the machine-wide count);
        # (wave 29b, E16) and the plans of its members: a running row of the plan counts too
        $panelGroupFps = @{}
        $panelGroupPlans = @{}
        foreach ($s in $panelSlots) {
            $gi = [int]$s.Group
            if (-not $panelGroupFps.ContainsKey($gi)) { $panelGroupFps[$gi] = [string[]]@() }
            if (-not $panelGroupPlans.ContainsKey($gi)) { $panelGroupPlans[$gi] = [string[]]@() }
            $fpS = [string]$s.Pm.Identity.Fingerprint
            if ($fpS -and $panelGroupFps[$gi] -notcontains $fpS) { $panelGroupFps[$gi] = [string[]]@($panelGroupFps[$gi] + $fpS) }
            $plS = [string](Get-PropertyValue $s.Pm.Entry 'Plan' '')
            if ($plS -and $panelGroupPlans[$gi] -cnotcontains $plS) { $panelGroupPlans[$gi] = [string[]]@($panelGroupPlans[$gi] + $plS) }
        }

        # (wave 25, R12) -Detach: the panel's checks passed (D2: the launchers, the records, the
        # stores, the selection) - the background runs it; this process writes the `starting`
        # record and returns. The budget (D4) from the plan and the members' guards.
        if ($detachForeground) {
            $detachGuards = @{}
            foreach ($s in $panelSlots) { $detachGuards[[int]$s.Pm.Entry.Position] = [int]$s.Guard }
            $detachBudget = Get-DetachedBudget -Groups $panelPlan.Groups -GuardOf $detachGuards -Cap $PanelConcurrency
            $detachMembers = @(foreach ($pm in @($panelEntries | Where-Object { $_.State -ne 'not-picked' })) {
                    $detachShown = Format-ReviewerLineage -Provider $pm.Identity.Provider -Model $pm.Identity.Model -Engine ([string]$pm.Identity.Engine)
                    if ($pm.State -eq 'run') { New-DetachedMember -Position ([int]$pm.Entry.Position) -Lineage $detachShown }
                    else { New-DetachedMember -Position ([int]$pm.Entry.Position) -Lineage $detachShown -State 'skipped' -Outcome ([string]$pm.Reason) }
                })
            # D8: the brief and the artifacts absolute (a missing artifact is refused here, not by every member)
            $detachArtifacts = @(Resolve-ArtifactPaths -Paths (Split-ArtifactArgument -Values $Artifact -Bases @($callerCwd, $repoRoot)) -Bases @($callerCwd, $repoRoot))
            $detachBrief = ''
            if ($Brief) { $detachBrief = (Resolve-Path -LiteralPath $briefProbe).Path }
            $detachPlan = "a review panel of $($panelRunners.Count) of $($panelEntries.Count) roster entries, $($panelPlan.Text) (purpose $purposeLabel, timeout $TimeoutSec s per member)"
            Start-DetachedRun -Kind 'panel' -Members $detachMembers -Budget $detachBudget -Plan $detachPlan -BriefFull $detachBrief -ArtifactFull @($detachArtifacts | ForEach-Object { $_.full }) -Warnings (@($rangeWarning) + @($panelWarnings) + @($panelCoordinatorWarnings))
        }
        # (wave 25) a detached panel: its members with their numbers, in roster order
        if ($script:DetachRun) {
            Set-DetachedMembers @(foreach ($pm in @($panelEntries | Where-Object { $_.State -ne 'not-picked' })) {
                    $detachShown = Format-ReviewerLineage -Provider $pm.Identity.Provider -Model $pm.Identity.Model -Engine ([string]$pm.Identity.Engine)
                    if ($pm.State -eq 'run') {
                        $ds = $slotOf[[int]$pm.Entry.Position]
                        New-DetachedMember -Position ([int]$pm.Entry.Position) -Lineage $detachShown -N $ds.N -Handoff $ds.Nn -Reply $ds.Reply
                    } else { New-DetachedMember -Position ([int]$pm.Entry.Position) -Lineage $detachShown -State 'skipped' -Outcome ([string]$pm.Reason) }
                })
        }

        $panelVerb = if ($DryRun) { 'would run' } else { 'run' }
        Write-Host "Panel $panelShort$(if ($DryRun) { ' (dry run - nothing is executed or written)' }): $($panelRunners.Count) of $($panelEntries.Count) roster entries $panelVerb, $($panelPlan.Text) (roster $($roster.Path); panel id $panelId)"
        # The lineage as shown: ' [agy]' for a member of another engine than codex.
        foreach ($pm in $panelEntries) { $pm | Add-Member -NotePropertyName 'Shown' -NotePropertyValue (Format-ReviewerLineage -Provider $pm.Identity.Provider -Model $pm.Identity.Model -Engine ([string]$pm.Identity.Engine)) -Force }
        foreach ($pm in $panelEntries) {
            $slot = $slotOf[[int]$pm.Entry.Position]
            $roleShown = $(if ($panelRoleOf.ContainsKey([int]$pm.Entry.Position)) { ", role $($panelRoleOf[[int]$pm.Entry.Position])" } else { '' })
            # (2026-10-07) a light entry standing in says for whom (its Reason)
            $stateShown = $(if ($pm.State -eq 'run') { "member, n=$($slot.N), handoff $($slot.Nn)$roleShown$(if ($pm.Required) { ', required' })$(if ($pm.Reason) { ", $($pm.Reason)" })" } elseif ($pm.State -eq 'not-picked') { "not picked: $($pm.Reason)" } else { "skipped: $($pm.Reason)" })
            Write-Host ("  #{0} {1} - {2}" -f $pm.Entry.Position, $pm.Shown, $stateShown)
        }
        # (wave 26) the routing record, as the members' ledger entries carry it (panel.routing)
        foreach ($rl in (Format-RoutingLines -Routing $panelRoute.Routing -Purpose $Purpose)) { Write-Host $rl }
        if ($topicList.Count -gt 0) { Write-Host "Topics: $($topicList -join ', ')" }
        foreach ($pw in $panelWarnings) { Write-Host "WARNING: $pw" -ForegroundColor Yellow }
        foreach ($cw in $panelCoordinatorWarnings) { Write-Host "WARNING: $cw" -ForegroundColor Yellow }
        # (wave 28b, D10) the panel run says it too (each member's warnings[] carries it)
        if (Test-TestMode) { Write-Host "WARNING: $($script:TestModeWarning)" -ForegroundColor Yellow }
        $groupTexts = @(foreach ($g in $panelPlan.Groups) {
                $cnt = @($g.Positions).Count
                $t = "$(@($g.Labels) -join '+') x$cnt"
                if ($cnt -gt 1) { $t += $(if ($g.Limit -ge $cnt) { ' at once' } elseif ($g.Limit -le 1) { ' one after another' } else { " $($g.Limit) at a time" }) }
                $t
            })
        Write-Host "Concurrency: $($panelPlan.Text) - endpoint groups: $($groupTexts -join ', '); -PanelConcurrency $(if ($PanelConcurrency -gt 0) { $PanelConcurrency } else { '0 (no cap)' })"
        # (wave 26b, D11) the members whose roster entry sets its own timeout_sec are listed
        $timeoutExceptions = @($panelSlots | Where-Object { $_.TimeoutSource -eq 'roster' } | ForEach-Object { "#$($_.Pm.Entry.Position) $(Format-ReviewerLineage -Provider $_.Pm.Identity.Provider -Model $_.Pm.Identity.Model -Engine ([string]$_.Pm.Identity.Engine)) $($_.TimeoutSec) s (roster)" })
        Write-Host "Timeout: $TimeoutSec s per member ($(Format-TimeoutSource -Source $timeoutSource -PurposeLabel $purposeLabel))$(if ($timeoutExceptions.Count -gt 0) { '; ' + ($timeoutExceptions -join '; ') }); continuation after a timeout kill: $(if ($ContinueSec -gt 0) { "up to $ContinueSec s on the same thread" } else { 'off (-ContinueSec 0)' })"
        if ($rangeStat) { Write-Host "Range: $Range - $rangeText ($($rangeStat.Insertions) insertions, $($rangeStat.Deletions) deletions)" }
        if ($rangeWarning) { Write-Host "WARNING: $rangeWarning" -ForegroundColor Yellow }
        if ($panelPendingRefusal) { Write-Host "pending     : the real run would be REFUSED - $panelPendingRefusal" -ForegroundColor Yellow }

        if (-not $DryRun) {
            # Every member's `reserved` record BEFORE any member starts: a panel run that dies
            # from here on leaves one record per planned member (inactive once this process is
            # gone - the next run consumes them).
            $written = New-Object System.Collections.Generic.List[string]
            foreach ($slot in $panelSlots) {
                $launcherK = Get-EngineLauncher -Engine $slot.Engine -Launchers $engineLaunchers -CodexLauncher ([string]$codexExePath)
                $panelInfo = [pscustomobject]@{ id = $panelId; position = $slot.K; of = $panelRunners.Count; parent_pid = $PID; parent_start_time = $panelParentStart }
                $rec = New-PendingRecord -State 'reserved' -N $slot.N -Nn $slot.Nn -Reply $slot.Reply -Started (Get-IsoTimestamp) -Launcher $launcherK -ConsultId $slot.ConsultId -Engine $slot.Engine -Panel $panelInfo
                $rec.note = "reserved by review panel $panelShort (pid $PID); the member has not started"
                try { Write-PendingFile -Path $slot.RecordPath -Record $rec } catch {
                    $why = ConvertTo-OneLine $_.Exception.Message
                    foreach ($w in $written) { $null = Remove-PendingFile -Path $w }
                    Stop-WithError "could not write the recovery record '$($slot.RecordPath)': $why; no panel member was started."
                }
                $written.Add($slot.RecordPath)
            }
            # The consumed records go now (their numbers are skipped) - never a path a member
            # record now uses.
            for ($i = 0; $i -lt @($panelPending.Items).Count; $i++) {
                $it = $panelPending.Items[$i]
                $num = $panelNumbers.Items[$i]
                $st = [string](Get-PropertyValue $it.Record 'state' '')
                if (-not (@($written) -icontains $it.Path)) {
                    $rmError = Remove-PendingFile -Path $it.Path
                    if ($rmError) { Write-Host "codex-consult: could not remove the consumed recovery record $($it.Path) ($rmError)" -ForegroundColor Yellow }
                }
                if ($num.Recovered) { Write-Host "codex-consult: recovered reservation n=$($num.N), nn=$($num.Nn) ($($it.Name): state '$st' of an interrupted run; $($it.Check.Check)); numbering continues past it." -ForegroundColor Yellow }
                else { Write-Host "codex-consult: cleared the recovery record of consult n=$($num.N), nn=$($num.Nn) ($($it.Name): state '$st'; $($it.Check.Check)); its ledger entry exists." -ForegroundColor Yellow }
            }
        } else {
            for ($i = 0; $i -lt @($panelPending.Items).Count; $i++) {
                $it = $panelPending.Items[$i]
                $num = $panelNumbers.Items[$i]
                if (-not $it.Check.Active) { Write-Host "pending     : $($it.Path) (state '$([string](Get-PropertyValue $it.Record 'state' ''))', n=$($num.N), nn=$($num.Nn); $($it.Check.Check)): the real run recovers it; numbering continues past it." -ForegroundColor Yellow }
            }
        }

        # ------------------------------------------------------------------ launch + poll
        [void][IO.Directory]::CreateDirectory($panelTmp)
        Write-Utf8NoBom -Path $panelEmptyIn -Text ''
        $panelBlocked = ''
        $panelRequiredFailed = $false
        while ($true) {
            $progress = $false
            foreach ($slot in $panelSlots) {
                if ($slot.State -ne 'running') { continue }
                $exited = $true
                try { $exited = $slot.Proc.HasExited } catch { $exited = $true }
                if ($exited) {
                    try { $slot.Exit = $slot.Proc.ExitCode } catch { $slot.Exit = -1 }
                    $slot.Wall = [math]::Round($slot.Watch.Elapsed.TotalSeconds, 1)
                    $slot.State = 'done'
                } elseif ($slot.Watch.Elapsed.TotalSeconds -gt $slot.Guard) {
                    $null = Stop-ProcessTree -Process $slot.Proc
                    $slot.Exit = -1
                    $slot.Wall = [math]::Round($slot.Watch.Elapsed.TotalSeconds, 1)
                    $slot.State = 'killed'
                } else {
                    continue
                }
                $progress = $true
                Complete-PanelMember $slot
                # (never $status: that is the -Status parameter, a switch)
                $memberStatus = Get-PanelMemberStatus $slot
                Set-DetachedMember -Position ([int]$slot.Pm.Entry.Position) -Values @{ state = (Get-PanelSlotDetachState $slot); outcome = $memberStatus; wall_seconds = $slot.Wall }
                if ($memberStatus.Length -gt 110) { $memberStatus = $memberStatus.Substring(0, 110) + '...' }
                Write-Host "  panel member $($slot.K) of $($panelRunners.Count) finished: $($slot.Pm.Shown) - $memberStatus ($($slot.Wall) s)"
                # (wave 26, D7) a REQUIRED member without a usable reply stops the panel at the next
                # slot boundary: no further member starts; exit 5
                if (-not $DryRun -and $slot.Pm.Required -and -not $panelRequiredFailed -and -not (Test-PanelSlotUsable $slot)) {
                    $panelRequiredFailed = $true
                    if (-not $panelBlocked) { $panelBlocked = "not started: the required member $($slot.Pm.Shown) produced no usable reply - the panel stops (exit 5)" }
                }
                # -PanelConcurrency 1: a member that left surviving processes stops the rest - one
                # member after another is the old order, and its rule stays (F15-3).
                if (-not $DryRun -and $PanelConcurrency -eq 1 -and -not $panelBlocked) {
                    $rd = Read-PendingFile -Path $slot.RecordPath
                    if ($rd.Error) {
                        $panelBlocked = "not started: the previous member's recovery record cannot be used ($(ConvertTo-OneLine $rd.Error))"
                    } elseif ($rd.Exists) {
                        $chk = Test-PendingActive -Record $rd.Record -Path $slot.RecordPath
                        if ($chk.Active) { $panelBlocked = "not started: the previous member ($($slot.Pm.Shown)) left surviving processes ($([IO.Path]::GetFileName($slot.RecordPath)) state $(Get-PropertyValue $rd.Record 'state' '')); recover the task first" }
                    }
                }
            }
            $running = @($panelSlots | Where-Object { $_.State -eq 'running' }).Count
            foreach ($slot in $panelSlots) {
                if ($slot.State -ne 'waiting') { continue }
                if ($panelBlocked) {
                    $slot.State = 'blocked'; $slot.NotStarted = $panelBlocked; $progress = $true
                    Set-DetachedMember -Position ([int]$slot.Pm.Entry.Position) -Values @{ state = 'blocked'; outcome = $panelBlocked }
                    continue
                }
                if ($PanelConcurrency -gt 0 -and $running -ge $PanelConcurrency) { break }
                $grp = $panelPlan.Groups[$slot.Group]
                if (@($panelSlots | Where-Object { $_.Group -eq $slot.Group -and $_.State -eq 'running' }).Count -ge $grp.Limit) { continue }
                # (wave 26b, D13) the runs of this machine OUTSIDE the panel on the group's endpoints
                # (another repository's members, another panel, a single run - the machine-wide
                # health file's running[]) count against the group's limit too - (wave 29b, E16) and
                # the runs of the group's PLANS on any route, engine and repository (the group's
                # limit is never above its plans' "parallel" values, default 1)
                if (-not $DryRun) {
                    $grpPlans = [string[]]@($panelGroupPlans[[int]$slot.Group])
                    $extRun = Get-MachineRunningCount -Fingerprints $panelGroupFps[[int]$slot.Group] -ExcludePanel $panelId -Plans $grpPlans
                    if ($extRun.Count -gt 0 -and (@($panelSlots | Where-Object { $_.Group -eq $slot.Group -and $_.State -eq 'running' }).Count + $extRun.Count) -ge $grp.Limit) {
                        if (-not $slot.ExternalWaitShown) {
                            $slot.ExternalWaitShown = $true
                            $byPlanPids = @(@($extRun.ByPlan) | ForEach-Object { [string](Get-PropertyValue $_ 'pid' '') })
                            $extWho = @($extRun.Rows | ForEach-Object { $rowPlan = [string](Get-PropertyValue $_ 'plan' ''); "$([string](Get-PropertyValue $_ 'label' '')) in $([string](Get-PropertyValue $_ 'repo' '')) task $([string](Get-PropertyValue $_ 'task' '')) handoff $([string](Get-PropertyValue $_ 'nn' '')) ($(if ($rowPlan -and $byPlanPids -contains [string](Get-PropertyValue $_ 'pid' '')) { "plan $rowPlan, " })pid $([string](Get-PropertyValue $_ 'pid' '')))" }) -join '; '
                            $usedPlans = @(@($extRun.ByPlan) | ForEach-Object { [string](Get-PropertyValue $_ 'plan' '') } | Where-Object { $_ } | Select-Object -Unique)
                            $what = $(if (@($extRun.ByPlan).Count -eq 0) { 'its endpoint' } elseif (@($extRun.ByPlan).Count -eq $extRun.Count) { "its plan $($usedPlans -join ', ')" } else { "its endpoint or its plan $($usedPlans -join ', ')" })
                            Write-Host "  panel member $($slot.K) of $($panelRunners.Count) waits: $($extRun.Count) run(s) elsewhere on this machine use $what (parallel limit $($grp.Limit)): $extWho"
                        }
                        continue
                    }
                }
                # within an endpoint group the roster order holds
                if (@($panelSlots | Where-Object { $_.Group -eq $slot.Group -and $_.State -eq 'waiting' -and $_.K -lt $slot.K }).Count -gt 0) { continue }
                Start-PanelMember $slot
                $progress = $true
                if ($slot.State -eq 'running') { $running++; Set-DetachedMember -Position ([int]$slot.Pm.Entry.Position) -Values @{ state = 'running' } }
                elseif ($slot.State -eq 'failed-start') {
                    Set-DetachedMember -Position ([int]$slot.Pm.Entry.Position) -Values @{ state = 'failed'; outcome = (Get-PanelMemberStatus $slot) }
                    if (-not $DryRun -and $slot.Pm.Required -and -not $panelRequiredFailed) {
                        $panelRequiredFailed = $true
                        $panelBlocked = "not started: the required member $($slot.Pm.Shown) could not be started - the panel stops (exit 5)"
                    }
                }
            }
            if (@($panelSlots | Where-Object { $_.State -eq 'waiting' -or $_.State -eq 'running' }).Count -eq 0) { break }
            if (-not $progress) { Start-Sleep -Milliseconds 500 }
        }
        $panelWatch.Stop()
        $panelWall = [math]::Round($panelWatch.Elapsed.TotalSeconds, 1)

        # ------------------------------------------------------------------ console output, records
        foreach ($slot in $panelSlots) {
            if (@('done', 'killed') -notcontains $slot.State) { continue }
            Write-Host ""
            Write-Host "=== panel $panelShort member $($slot.K) of $($panelRunners.Count): $($slot.Pm.Shown) (roster #$($slot.Pm.Entry.Position)) ==="
            foreach ($l in $slot.Lines) { Write-Host $l }
        }
        if (-not $DryRun) {
            # D5: the records of members that never started, and of launched members that are
            # gone with their record still `reserved` (nothing was started under it), go.
            foreach ($slot in $panelSlots) {
                $rd = Read-PendingFile -Path $slot.RecordPath
                if (-not $rd.Exists -or $rd.Error) { continue }
                $st = [string](Get-PropertyValue $rd.Record 'state' '')
                if ((@('waiting', 'blocked', 'failed-start') -contains $slot.State) -or $st -eq 'reserved') {
                    $rmError = Remove-PendingFile -Path $slot.RecordPath
                    if ($rmError) { $slot.RecordKept = $true; Write-Host "codex-consult: could not remove the unused recovery record $($slot.RecordPath) ($rmError)" -ForegroundColor Yellow }
                } else {
                    $slot.RecordKept = $true
                    $slot.RecordState = $st
                }
            }
        }

        # ------------------------------------------------------------------ summary
        $rows = New-Object System.Collections.Generic.List[object]
        $allUsable = ($panelRunners.Count -gt 0)
        $panelStarted = @($panelSlots | Where-Object { @('done', 'killed') -contains $_.State }).Count
        foreach ($pm in @($panelEntries | Where-Object { $_.State -ne 'not-picked' })) {
            $row = [pscustomobject]@{ Lineage = $pm.Shown; Status = ''; Counts = ''; Prior = ''; Tail = ''; Wide = $false }
            if ($pm.State -ne 'run') {
                $row.Status = 'skipped'
                $row.Counts = $pm.Reason
                $row.Wide = $true
            } else {
                $slot = $slotOf[[int]$pm.Entry.Position]
                if (@('waiting', 'blocked') -contains $slot.State) {
                    $row.Status = 'skipped'
                    $row.Counts = $(if ($slot.NotStarted) { $slot.NotStarted } else { 'not started' })
                    $row.Wide = $true
                    $allUsable = $false
                } elseif ($DryRun -and $slot.State -eq 'done') {
                    if ($slot.Exit -eq 0) { $row.Status = 'planned' } else { $row.Status = "refused: $(ConvertTo-OneLine $slot.Refusal)"; $row.Wide = $true; $allUsable = $false }
                } elseif ($null -eq $slot.Entry) {
                    $row.Status = Get-PanelMemberStatus $slot
                    if (-not $DryRun -and -not $slot.RecordKept) { $row.Status += " (n=$($slot.N) and handoff $($slot.Nn) stay unused)" }
                    elseif (-not $DryRun) { $row.Status += " ($([IO.Path]::GetFileName($slot.RecordPath)) kept, state $($slot.RecordState))" }
                    $row.Wide = $true
                    $allUsable = $false
                } else {
                    $me = $slot.Entry
                    $outcome = [string](Get-PropertyValue $me 'bridge_outcome' '')
                    $tail = "$(Get-PropertyValue $me 'wall_seconds' '?') s  $(Get-PropertyValue $me 'reply' '')"
                    # (wave 24) a reply after a timeout continuation is usable (said so); a
                    # salvaged partial reply is named
                    if ($outcome -cne 'usable reply' -and (Test-UsableOutcome $outcome)) { $tail += '  (after a timeout continuation)' }
                    $partialRel = [string](Get-PropertyValue $me 'partial_reply' '')
                    if ($partialRel) { $tail += "  partial $partialRel" }
                    if ($slot.State -eq 'killed') {
                        $row.Status = Get-PanelMemberStatus $slot
                        $row.Tail = $tail
                        $row.Wide = $true
                        $allUsable = $false
                    } elseif (-not (Test-UsableOutcome $outcome)) {
                        $short = $outcome -replace '^failed:\s*', ''
                        if ($short.Length -gt 90) { $short = $short.Substring(0, 90) + '...' }
                        $row.Status = "failed: $short"
                        $row.Tail = $tail
                        $row.Wide = $true
                        $allUsable = $false
                    } else {
                        $verdictText = [string](Get-PropertyValue $me 'verdict' '')
                        if ($verdictText -and (Get-PropertyValue $me 'structured' $false) -eq $true) {
                            $row.Status = $verdictText
                            $fc = Get-PropertyValue $me 'findings' $null
                            $row.Counts = "$(Get-PropertyValue $fc 'blocker' 0) blocker, $(Get-PropertyValue $fc 'major' 0) major, $(Get-PropertyValue $fc 'minor' 0) minor"
                            if ([int](Get-PropertyValue $fc 'note' 0) -gt 0) { $row.Counts += ", $(Get-PropertyValue $fc 'note' 0) note" }
                            $row.Prior = Format-PriorCounts $me
                        } else {
                            $row.Status = 'prose (no verdict)'
                        }
                        $row.Tail = $tail
                    }
                }
            }
            $rows.Add($row)
        }
        $wLineage = (@($rows | ForEach-Object { $_.Lineage.Length }) | Measure-Object -Maximum).Maximum
        $narrow = @($rows | Where-Object { -not $_.Wide })
        $wStatus = 7
        $wCounts = 0
        $wPrior = 0
        if ($narrow.Count -gt 0) {
            $wStatus = [Math]::Max(7, (@($narrow | ForEach-Object { $_.Status.Length }) | Measure-Object -Maximum).Maximum)
            $wCounts = (@($narrow | ForEach-Object { $_.Counts.Length }) | Measure-Object -Maximum).Maximum
            $wPrior = (@($narrow | ForEach-Object { $_.Prior.Length }) | Measure-Object -Maximum).Maximum
        }
        # (wave 25) a detached panel: every member's final state (D11); the summary block below
        # goes to its status file too (Write-Summary, D3)
        if ($script:DetachRun) {
            foreach ($slot in $panelSlots) {
                $dState = Get-PanelSlotDetachState $slot
                $dOutcome = ''
                if (@('waiting', 'blocked') -contains $slot.State) { $dOutcome = $(if ($slot.NotStarted) { $slot.NotStarted } else { 'not started' }); if ($slot.State -eq 'waiting') { $dState = 'skipped' } }
                else { $dOutcome = Get-PanelMemberStatus $slot }
                Set-DetachedMember -Position ([int]$slot.Pm.Entry.Position) -Values @{ state = $dState; outcome = $dOutcome; wall_seconds = $(if (@('done', 'killed') -contains $slot.State) { $slot.Wall } else { $null }) } -NoSave
            }
        }
        # (wave 26, D6) asked k, started j, usable i - the ledger's panel record gets the same
        # numbers below; (wave 26b, D2 / F19-1) asked is the size REQUESTED (the purpose's,
        # -PanelSize; -PanelAll: every eligible), not the seats after the clamp
        $panelUsable = @($panelSlots | Where-Object { Test-PanelSlotUsable $_ }).Count
        $requiredMissing = @($panelSlots | Where-Object { $_.Pm.Required -and -not (Test-PanelSlotUsable $_) })
        Write-Host ""
        # (a "(" inside a string nested in "$(...)" would end the subexpression early: built in pieces)
        $panelHead = "$panelStarted of $($panelEntries.Count) entries ran " + '(' + "asked $($panelRoute.SizeAsked), started $panelStarted, usable $panelUsable; wall clock $panelWall s; $($panelPlan.Text)" + ')'
        if ($DryRun) { $panelHead = "$($panelRunners.Count) of $($panelEntries.Count) entries would run " + '(dry run) (' + "wall clock $panelWall s; $($panelPlan.Text)" + ')' }
        Write-Summary "Panel $($panelShort): $panelHead"
        foreach ($row in $rows) {
            $parts = New-Object System.Collections.Generic.List[string]
            $parts.Add($row.Lineage.PadRight($wLineage))
            if ($row.Wide) {
                $parts.Add($row.Status.PadRight($(if ($row.Status -eq 'skipped') { $wStatus } else { 0 })))
                if ($row.Counts) { $parts.Add($row.Counts) }
            } else {
                $parts.Add($row.Status.PadRight($wStatus))
                if ($wCounts -gt 0) { $parts.Add($row.Counts.PadRight($wCounts)) }
                if ($wPrior -gt 0) { $parts.Add($row.Prior.PadRight($wPrior)) }
            }
            if ($row.Tail) { $parts.Add($row.Tail) }
            Write-Summary ('  ' + (($parts.ToArray() -join '  ').TrimEnd()))
        }
        $notPicked = @($panelEntries | Where-Object { $_.State -eq 'not-picked' })
        if ($notPicked.Count -gt 0) { Write-Summary "  not picked (panel size $($panelRoute.K)): $(@($notPicked | ForEach-Object { $_.Shown }) -join ', ')" }
        if (-not $DryRun) {
            # (wave 26, D6) every member's ledger entry learns how the panel ended: panel.started and
            # panel.usable (a member commits before the panel ends; best effort - a failure warns)
            $countCommit = $null
            try {
                $countCommit = Enter-StoreCommit -TaskDir $taskDir -Task $Task -TimeoutSec (Get-WriteLockTimeout)
                if (-not $countCommit.Acquired) { Write-Host "codex-consult: the panel's counts were not written to the ledger ($($countCommit.Message))" -ForegroundColor Yellow }
                elseif ($null -ne $countCommit.Sessions) {
                    $countChanged = $false
                    foreach ($ce in @(Get-PropertyValue (Get-PropertyValue $countCommit.Sessions 'codex' $null) 'consults' @())) {
                        $cp = Get-PropertyValue $ce 'panel' $null
                        if ($null -eq $cp -or [string](Get-PropertyValue $cp 'id' '') -ne $panelId) { continue }
                        $cp | Add-Member -NotePropertyName 'started' -NotePropertyValue $panelStarted -Force
                        $cp | Add-Member -NotePropertyName 'usable' -NotePropertyValue $panelUsable -Force
                        $countChanged = $true
                    }
                    if ($countChanged) { Complete-StoreCommit -Commit $countCommit -Sessions }
                }
            } catch {
                Write-Host "codex-consult: the panel's counts were not written to the ledger ($(ConvertTo-OneLine $_.Exception.Message))" -ForegroundColor Yellow
            } finally { Exit-StoreCommit -Commit $countCommit }
            # (wave 28, R17) every member put its event into the spool: ONE detached sender for the
            # panel (not waited for; silent)
            if ($telemetrySwitch.On -and $panelStarted -gt 0) {
                $telemetryWhy = Start-TelemetrySender
                if ($telemetryWhy) { Write-Verbose "telemetry: $telemetryWhy" }
            }
        }
        if (-not $DryRun -and $requiredMissing.Count -gt 0) {
            Write-Summary "  required member$(if ($requiredMissing.Count -ne 1) { 's' }) without a usable reply: $(@($requiredMissing | ForEach-Object { $_.Pm.Shown }) -join ', ') - exit 5"
            Set-DetachedFinal -Exit 5
            exit 5
        }
        if ($allUsable) { Set-DetachedFinal -Exit 0; exit 0 }
        Set-DetachedFinal -Exit 1
        exit 1
    } finally {
        Exit-TaskLock -Lock $panelLock
        if ($panelTmp -and (Test-Path -LiteralPath $panelTmp)) { Remove-Item -LiteralPath $panelTmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ----------------------------------------------------------------------------- reviewer, effort, peak

# All decided BEFORE the task lock is taken (a refusal here touches nothing).
# Resolve-ReviewerIdentity: what Codex will use, read from its config (never assumed).
$codexConfigScan = Read-CodexConfigSubset -Path (Get-CodexConfigPath)
$openAiBaseUrl = [string]$env:OPENAI_BASE_URL
# The endpoint health of every task ledger of this repository, read at the consult clock
# (CODEX_CONSULT_NOW freezes it in tests; -Peek leaves the peak evaluations their values).
$healthClock = Get-ConsultClock -Peek
if ($healthClock.Error) { Stop-WithError $healthClock.Error }
$healthNow = $healthClock.Now.UtcDateTime
$allConsults = Read-AllTaskConsults -CollabRoot $collabRoot
$loginCache = @{}

# Which reviewer (Read-ReviewerRoster, Select-RosterReviewer):
#   no roster      -Provider / -Model, else the Codex config (as always)
#   -Provider      the roster does not select; its entry for that provider supplies the
#                  model (when -Model is empty) and codex_config (when -CodexConfig is empty)
#   -Thread        the thread's ledger entry fixes the provider and the model; the roster
#                  entry supplies codex_config
#   otherwise      the first roster entry whose preflight is available (-Model: only the
#                  entries that resolve to that model; -Engine: only the entries of that
#                  engine); skipped entries are recorded
# The engine (0.4.0): -Engine, else the engine of the roster entry used (the thread's entry
# with -Thread), else codex. -Engine that contradicts the entry is refused (a provider label
# names one engine).
$engineName = $Engine
$engineFrom = $(if ($Engine) { '-Engine' } else { '' })
$rosterRule = ''
$rosterEntry = $null
$rosterSkipped = @()
$rosterApplied = New-Object System.Collections.Generic.List[string]
# Notices decided before the run that go to the ledger's `warnings[]` (every engine) and the
# console: a -Provider label that names several roster entries (wave 18, F10-3).
$runWarnings = New-Object System.Collections.Generic.List[string]
# (wave 24, T1) a big -Range for the timeout
if ($rangeWarning) { $runWarnings.Add($rangeWarning) }
# (wave 27c, D14 / F32-10) test hooks in the environment without CODEX_CONSULT_TEST_MODE=1: ignored,
# and said once (the console, the ledger's warnings[])
$ignoredTestHooks = Get-IgnoredTestHooks
if ($ignoredTestHooks.Count -gt 0) { $runWarnings.Add("test hook$(if ($ignoredTestHooks.Count -ne 1) { 's' }) ignored - CODEX_CONSULT_TEST_MODE=1 is not set: $($ignoredTestHooks -join ', ')") }
# (wave 28b, D10 / F36-5) test mode never goes unnoticed: a run that finds CODEX_CONSULT_TEST_MODE=1
# says so on the console and in warnings[] (every harness expects this line); no engine child gets
# the test-mode variables (Hide-HostMarkers -TestVars)
if (Test-TestMode) { $runWarnings.Add($script:TestModeWarning) }
# (wave 27c, D12) the coordinator's own warnings (a '#n' that names no roster position here)
foreach ($cw in @($coordinatorWarnings)) { if ($cw) { $runWarnings.Add([string]$cw) } }
# (wave 26) the panel run's routing warnings (a lab of its own, the floor) - every member's ledger
if ($panelMember) { foreach ($pw in @(Get-PropertyValue $panelMember 'panel_warnings' @())) { if ($pw) { $runWarnings.Add([string]$pw) } } }
$identityProvider = $Provider
$identityModel = $Model
$providerSourceOverride = ''
$modelSourceOverride = ''
if ($roster.Exists) {
    if ($panelMember) {
        # A member of a -Panel run: the roster entry the panel run selected for it.
        $rosterRule = 'panel'
        $memberPosition = [int]$panelMember.roster_position
        $rosterEntry = @($roster.Entries | Where-Object { $_.Position -eq $memberPosition }) | Select-Object -First 1
        $memberEngine = if ($panelMember.PSObject.Properties['engine'] -and $panelMember.engine) { [string]$panelMember.engine } else { 'codex' }
        if (-not $rosterEntry -or $rosterEntry.Provider -cne [string]$panelMember.provider -or $rosterEntry.Model -cne [string]$panelMember.model -or $rosterEntry.Engine -ne $memberEngine) {
            Stop-WithError "the reviewer roster '$($roster.Path)' changed while the panel ran (entry $memberPosition is no longer $([string]$panelMember.provider) $([string]$panelMember.model)$(if ($memberEngine -ne 'codex') { " [$memberEngine]" })); this panel member was not started."
        }
        $engineName = $rosterEntry.Engine
        $engineFrom = 'roster'
        $rosterSkipped = @($panelMember.skipped | Where-Object { $_ })
        $identityProvider = $rosterEntry.Provider
        $providerSourceOverride = 'roster'
        if ($rosterEntry.Model -and -not $Model) {
            $identityModel = $rosterEntry.Model
            $modelSourceOverride = 'roster'
            $rosterApplied.Add('model')
        }
    } elseif ($Provider) {
        $rosterRule = 'provider'
        $rosterEntry = Find-RosterEntry -Roster $roster -Provider $Provider -Model $Model
        if ($rosterEntry -and $Engine -and $rosterEntry.Engine -ne $Engine) {
            Stop-WithError "-Engine $($Engine): the roster entry $($rosterEntry.Position) for -Provider $Provider is engine $($rosterEntry.Engine) (a provider label names one engine); drop -Engine, or use another label"
        }
        if ($rosterEntry -and -not $Engine) {
            $engineName = $rosterEntry.Engine
            $engineFrom = 'roster'
            if ($rosterEntry.EngineDeclared) { $rosterApplied.Add('engine') }
        }
        if ($rosterEntry -and -not $Model -and $rosterEntry.Model) {
            $identityModel = $rosterEntry.Model
            $modelSourceOverride = 'roster'
            $rosterApplied.Add('model')
        }
        # The 0.3.0 rule stays (the first entry of the label), but a label that names several
        # entries (e.g. gemini on a flash and a weighty pro model) is easy to misuse: say so.
        $sameLabel = @($roster.Entries | Where-Object { $_.Provider -ceq $Provider })
        if ($rosterEntry -and -not $Model -and $sameLabel.Count -gt 1) {
            $firstShown = if ($rosterEntry.Model) { Format-ReviewerLineage -Provider $rosterEntry.Provider -Model $rosterEntry.Model -Engine $rosterEntry.Engine } else { "$($rosterEntry.Provider) (config model)" }
            $runWarnings.Add("roster: label $Provider names $($sameLabel.Count) entries; the first ($firstShown) is used - pass -Model for another")
        }
    } elseif ($Thread) {
        $rosterRule = 'thread'
        # This task's ledger, read before the lock (Select-ParentThread checks the thread
        # again under it). A store that does not parse is refused here already.
        $threadStore = Read-JsonStore -Path $sessionsPath
        $threadConsults = @()
        if ($null -ne $threadStore) { $threadConsults = @(Get-PropertyValue (Get-PropertyValue $threadStore 'codex' $null) 'consults' @()) }
        $threadFound = Find-ThreadEntry -Consults $threadConsults -Thread $Thread
        if ($threadFound.Error) { Stop-WithError $threadFound.Error }
        $threadReviewer = Get-EntryReviewer $threadFound.Entry
        if ($Engine -and $threadReviewer.Engine -ne $Engine) {
            Stop-WithError "-Engine $($Engine): thread $Thread belongs to engine $($threadReviewer.Engine) ($($threadReviewer.Display)); a thread never changes engine - drop -Engine, or use -Mode new"
        }
        $engineName = $threadReviewer.Engine
        $engineFrom = '-Thread'
        $identityProvider = $threadReviewer.Provider
        $providerSourceOverride = '-Thread'
        if (-not $Model) {
            $identityModel = $threadReviewer.Model
            $modelSourceOverride = '-Thread'
        }
        $rosterEntry = Find-RosterEntry -Roster $roster -Provider $identityProvider -Model $identityModel
    } else {
        $rosterRule = 'walk'
        $walk = Select-RosterReviewer -Roster $roster -Config $codexConfigScan -Consults $allConsults -Launcher ([string]$codexExePath) -LoginCache $loginCache -UtcNow $healthNow -OpenAiBaseUrl $openAiBaseUrl -Model $Model -SkipPreflight:$SkipPreflight -Engine $Engine -EngineLaunchers $engineLaunchers -EstimateTokens $promptEstimate
        if ($walk.Error) { Stop-WithError $walk.Error }
        $rosterEntry = $walk.Entry
        $rosterSkipped = @($walk.Skipped)
        $engineName = $rosterEntry.Engine
        if (-not $Engine) {
            $engineFrom = 'roster'
            if ($rosterEntry.EngineDeclared) { $rosterApplied.Add('engine') }
        }
        $identityProvider = $rosterEntry.Provider
        $providerSourceOverride = 'roster'
        if ($rosterEntry.Model -and -not $Model) {
            $identityModel = $rosterEntry.Model
            $modelSourceOverride = 'roster'
            $rosterApplied.Add('model')
        }
    }
    if ($rosterEntry -and $extraConfig.Count -eq 0 -and @($rosterEntry.CodexConfig).Count -gt 0) {
        foreach ($ci in @($rosterEntry.CodexConfig)) { $extraConfig.Add($ci) }
        $extraConfigSource = 'roster'
        $rosterApplied.Add('codex_config')
    }
}
# (wave 26b, D16) a single run's explicit reviewer (-Provider, -Thread) whose context window the
# new prompt alone would fill beyond 80% is refused before anything starts (a roster walk skips it)
if (-not $panelMember -and $rosterEntry -and $rosterRule -ne 'walk') {
    $ctxRefusal = Get-ContextSkip -Entry $rosterEntry -EstimateTokens $promptEstimate
    if ($ctxRefusal) { Stop-WithError "$ctxRefusal - roster entry #$($rosterEntry.Position); nothing was started (a shorter brief, or another reviewer)." }
}
# (wave 26b, D11) a single run's roster entry with its own timeout_sec: it replaces the purpose
# default (an explicit -TimeoutSec wins; a panel member got its value from the panel run)
if (-not $panelMember -and $rosterEntry -and $timeoutSource -eq 'purpose' -and [int](Get-PropertyValue $rosterEntry 'TimeoutSec' 0) -gt 0) {
    $TimeoutSec = [int]$rosterEntry.TimeoutSec
    $timeoutSource = 'roster'
    if (-not $continueGiven) { $ContinueSec = [Math]::Min($TimeoutSec, 900) }
    $rosterApplied.Add('timeout_sec')
}
# (wave 26b, D12) a single run's stall cut: -StallSec, else its roster entry's stall_sec, else 900
if (-not $panelMember -and -not $stallGiven) {
    $StallSec = 900
    if ($rosterEntry -and [int](Get-PropertyValue $rosterEntry 'StallSec' -1) -ge 0) { $StallSec = [int]$rosterEntry.StallSec; $rosterApplied.Add('stall_sec') }
}
# (wave 26, D7) -Require on a single run (with -Provider): every required reviewer must be available
# by the roster walk's verdict (stricter than a plain -Provider run: a usage limit without a reset
# time is out) - else the run is refused before anything starts, exit 5 (a dry run too).
$singleRequired = $null
if ($requireGiven -and -not $panelRun -and -not $panelMember) {
    if (-not $roster.Exists) { Stop-WithError "-Require names reviewers of the roster, and there is no reviewer roster$(if ($roster.Disabled) { ' (CODEX_CONSULT_ROSTER=none)' })." }
    $singleRequired = Resolve-RequiredReviewers -Roster $roster -Require $Require -Explicit
    if ($singleRequired.Error) { Stop-WithError "$($singleRequired.Error)." }
    if (@($singleRequired.Positions).Count -gt 0) {
        $reqRoster = [pscustomobject]@{ Exists = $true; Path = $roster.Path; Entries = [object[]]@($roster.Entries | Where-Object { $singleRequired.Positions -contains [int]$_.Position }) }
        $reqSel = Select-PanelMembers -Roster $reqRoster -Config $codexConfigScan -Consults $allConsults -Launcher ([string]$codexExePath) -LoginCache $loginCache -UtcNow $healthNow -OpenAiBaseUrl $openAiBaseUrl -All -EngineLaunchers $engineLaunchers
        $reqOut = @(@($reqSel.Members) | Where-Object { $_.State -ne 'run' } | ForEach-Object { Format-RequiredOutage -Member $_ -UtcNow $healthNow })
        if ($reqOut.Count -gt 0) {
            Stop-WithError "required reviewer$(if ($reqOut.Count -ne 1) { 's' }) not available (-Require, judged like the roster walk): $($reqOut -join '; '); nothing was started - wait for $(if ($reqOut.Count -ne 1) { 'them' } else { 'it' }), or run without -Require (exit 5)." -Code 5
        }
    }
}
if (-not $engineName) { $engineName = 'codex' }
if (-not $engineFrom) { $engineFrom = 'default' }
$engineSpec = Get-EngineSpec -Name $engineName
$isCodex = ($engineName -eq 'codex')
$anonymous = [bool]($rosterEntry -and $rosterEntry.Auth -eq 'none')

# What an engine does not support is refused with one message each (nothing started).
if (-not $isCodex) {
    if ($Mode -eq 'fork' -and @($engineSpec.Modes) -notcontains 'fork') { Stop-WithError "the $engineName engine has no fork; use -Mode resume or new." }
    if ($Sandbox -ne 'read-only') { Stop-WithError "-Sandbox $Sandbox is refused for the $engineName engine: consultations are read-only there ($($engineSpec.ReadOnlyNote))." }
    if (@($CodexConfig | Where-Object { $_ -and $_.Trim() }).Count -gt 0) { Stop-WithError "-CodexConfig does not apply to the $engineName engine (it configures codex exec)." }
    if ($transportOverride -and $engineSpec.Transports -notcontains $transportOverride) { Stop-WithError "-SchemaTransport $transportOverride is refused for the $engineName engine: it takes $($engineSpec.Transports -join ' or ') (native = the schema is passed as $($engineSpec.SchemaFlag))." }
    # agy: default mode new (a conversation is resumed only on request); -Thread resumes it.
    if (-not $Mode) { $Mode = $(if ($Thread) { 'resume' } else { $engineSpec.DefaultMode }) }
} else {
    if ($transportOverride -and $engineSpec.Transports -notcontains $transportOverride) { Stop-WithError "-SchemaTransport $transportOverride is for the agy, muse and claude engines; codex takes output-schema or prompt-only." }
}
# -MaxModelSteps: an engine with a model-step cap only (muse, D9); a panel member of another
# engine ignores the panel's value.
if ($MaxModelSteps -gt 0 -and -not $engineSpec.StepsFlag) {
    if ($panelMember) { $MaxModelSteps = 0 }
    else { Stop-WithError "-MaxModelSteps is for an engine with a model-step cap (muse --max-model-steps, claude --max-turns); the $engineName engine has none." }
}
# -EngineExe was bound to one engine (D3): a run of another engine other than codex would
# silently use that engine's default launcher - refused.
if ($engineExeEngine -and -not $isCodex -and $engineExeEngine -ne $engineName) {
    Stop-WithError "-EngineExe names the $engineExeEngine launcher, but this run's engine is $engineName (from $engineFrom); pass -Engine $engineName with -EngineExe."
}
# (wave 23, D4) the engine's launch invariant - muse: an API key in the environment would bill
# per token instead of the subscription. Never bypassed by -SkipPreflight; checked again right
# before every launch.
$launchBlock = Get-EngineLaunchBlock -Engine $engineName
if ($launchBlock) { Stop-WithError "the $engineName engine is refused: $launchBlock; nothing was started." }
# The ledger's `sandbox`: what was requested - and for another engine how it is enforced (A17;
# the engine row's own words).
$sandboxRecord = $Sandbox
if (-not $isCodex) { $sandboxRecord = [string]$engineSpec.SandboxRecord }
$engineLauncher = [string]$codexExePath
if (-not $isCodex) {
    $engineLauncher = Get-EngineLauncher -Engine $engineName -Launchers $engineLaunchers
    $harness = Get-EngineHarness -Engine $engineName -Launcher $engineLauncher
}

# (wave 29) an engine that takes a roster `auth` (claude: subscription | api-key) - the roster
# entry's, else the engine's default (the first); its child environment, preflight and billing check
# follow it. (wave 29b, E1) auth endpoint exists only in a roster entry: its `endpoint` object
# ($engineEndpoint) travels with the auth - the identity, the preflight, the child environment
$engineAuth = ''
$engineEndpoint = $null
$identityArgs = @{ Config = $codexConfigScan; Provider = $identityProvider; Model = $identityModel; OpenAiBaseUrl = $openAiBaseUrl; Engine = $engineName; Launcher = $engineLauncher }
if (@(Get-PropertyValue $engineSpec 'AuthModes' @()).Count -gt 0) {
    $engineAuth = $(if ($rosterEntry -and @($engineSpec.AuthModes) -contains [string]$rosterEntry.Auth) { [string]$rosterEntry.Auth } else { [string]@($engineSpec.AuthModes)[0] })
    $identityArgs['Auth'] = $engineAuth
    if ($engineAuth -eq 'endpoint') {
        $engineEndpoint = Get-PropertyValue $rosterEntry 'Endpoint' $null
        $identityArgs['Endpoint'] = $engineEndpoint
    }
}
$identity = Resolve-ReviewerIdentity @identityArgs
if ($identity.Error) { Stop-WithError $identity.Error }
# (wave 29, item 8) a claude model outside the engine's table is refused (a roster entry was checked
# when the roster was read); an alias floats - each thread is pinned to the id it resolves to.
# (wave 29b, E2) auth endpoint: the open id pattern; the id is sent straight (no alias warning)
if ($engineName -eq 'claude') {
    $claudeModelProblem = Get-ClaudeModelProblem ([string]$identity.Model) -Auth $engineAuth
    if ($claudeModelProblem) { Stop-WithError "the claude model '$($identity.Model)' $claudeModelProblem; nothing was started." }
    if ($engineAuth -ne 'endpoint' -and (Test-ClaudeModelAlias ([string]$identity.Model))) { $runWarnings.Add("claude model $($identity.Model) is an alias: the alias floats; each thread is pinned to the id it resolves to (engine_run.model_resolved)") }
}
if ($providerSourceOverride) { $identity.ProviderSource = $providerSourceOverride }
if ($modelSourceOverride) { $identity.ModelSource = $modelSourceOverride }
$reviewerRecord = New-ReviewerRecord -Identity $identity -Harness $harness
# (wave 29, D4) the model the engine's turns send: the identity's; claude pins a thread to the id its
# first turn resolved (set below for resume / fork, and after the main turn for the later turns)
$engineModel = [string]$identity.Model
$lineage = $identity.Lineage
# The lineage as shown on the console and in the handoff (' [agy]' for another engine).
$lineageShown = Format-ReviewerLineage -Provider $identity.Provider -Model $identity.Model -Engine $engineName
# (wave 27, R13 D3) the reviewer - its RESOLVED identity - is the coordinator's own model: a
# warning (the console, the dry run, the ledger's warnings[]), never a refusal
# (wave 27c, D9) "own model" only when provider, model and engine are equal; a coordinator named by
# its provider alone (no model could be resolved) gives the weaker warning
$coordinatorKind = Get-CoordinatorMatch -Coordinator $coordinatorRecord -Provider ([string]$identity.Provider) -Model ([string]$identity.Model) -Engine $engineName -Auth $engineAuth
if ($coordinatorKind) {
    $runWarnings.Add((Format-CoordinatorWarning -Kind $coordinatorKind -Lineage $lineageShown))
}
# (wave 25) the member's position in a detached run's status file: its roster position, else 1
$detachMemberPosition = $(if ($rosterEntry) { [int]$rosterEntry.Position } else { 1 })
$modelLabel = $identity.Model
$reviewerLine = "Reviewer: $lineageShown (provider from $($reviewerRecord.provider_source), model from $($identity.ModelSource); $($identity.Display)"
if ($identity.Resolved) {
    $reviewerLine += "; provider fingerprint $(Format-ShortHash $identity.Fingerprint)"
    if ($identity.Note) { $reviewerLine += "; $($identity.Note)" }
    $reviewerLine += "; harness $harness)."
} else {
    $reviewerLine += "; identity UNRESOLVED - never a parent thread: $($identity.Note); harness $harness)."
}

# Effort: requested (preset or -Effort) -> sent, through the endpoint's vocabulary.
$effortPlan = Resolve-EffortPlan -Identity $identity -Requested $effortResolved -Native $NativeEffort
if ($effortPlan.Error) { Stop-WithError $effortPlan.Error }
$effortSent = $effortPlan.Sent

# How the reply schema reaches the endpoint (caps-v1): 'output-schema' passes
# --output-schema; 'prompt-only' (an endpoint that rejects a json_schema response format,
# or one caps-v1 does not declare) puts the schema in the prompt and relies on the local
# validation alone. -SchemaTransport overrides it for this run. -Raw uses neither.
$schemaTransport = ''
$schemaTransportBasis = ''
$schemaTransportSource = ''
if (-not $Raw) {
    $st = Get-SchemaTransport -Identity $identity
    if ($transportOverride) {
        $schemaTransport = $transportOverride
        $schemaTransportBasis = "-SchemaTransport; $($st.Basis) would use $($st.Transport)"
        $schemaTransportSource = '-SchemaTransport'
    } else {
        $schemaTransport = $st.Transport
        $schemaTransportBasis = $st.Basis
        $schemaTransportSource = $script:EffortCapsVersion
    }
}

# Preflight: is the resolved provider usable? Local checks only, no network (see
# Get-ProviderCredential), then the endpoint's recorded health in ALL task ledgers of this
# repository (Get-EndpointHealth, keyed by provider_fingerprint). It fails CLOSED
# (Get-PreflightVerdict): missing credentials, an availability that cannot be established
# (an unresolved identity, a `codex login status` that cannot run or times out), a recent
# authentication failure on this endpoint and a usage limit whose reset time lies ahead all
# refuse the run - no ledger entry, nothing started - unless -SkipPreflight; so does (wave 24b,
# F08-7) a usage limit without a reset time hit less than 60 minutes ago - the verdict of every
# caller, the roster walk's too. -SkipPreflight launches anyway and warns (Format-QuotaWarning).
# -DryRun reports and never refuses.
$preflight = 'skipped'
$preflightLabel = 'skipped (-SkipPreflight)'
$preflightWarning = ''
$preflightRefusal = ''
$health = $null
if ($identity.Resolved) {
    $health = Get-EndpointHealth -Consults $allConsults -Fingerprint $identity.Fingerprint -UtcNow $healthNow
    $preflightWarning = Format-QuotaWarning -Identity $identity -Health $health -SkipPreflight:$SkipPreflight
}
if (-not $SkipPreflight) {
    $preflightVerdict = Get-PreflightVerdict -Identity $identity -Config $codexConfigScan -Launcher $engineLauncher -Health $health -LoginCache $loginCache -Anonymous:$anonymous
    # (wave 29b, E5) a usage limit on another route of the roster entry's plan refuses the run too
    if ($rosterEntry -and $roster.Exists) {
        $preflightVerdict = Get-PlanQuotaVerdict -Verdict $preflightVerdict -Entry $rosterEntry -Identity $identity -Roster $roster -Config $codexConfigScan -Consults $allConsults -Launcher ([string]$codexExePath) -EngineLaunchers $engineLaunchers -UtcNow $healthNow -OpenAiBaseUrl $openAiBaseUrl
    }
    $preflight = $preflightVerdict.Preflight
    $preflightLabel = $preflightVerdict.Label
    $preflightRefusal = $preflightVerdict.Refusal
    if ($preflightVerdict.State -ne 'available' -and $rosterRule -eq 'thread') {
        # The thread cannot continue: say which reviewer a new thread would get.
        $alternative = Select-RosterReviewer -Roster $roster -Config $codexConfigScan -Consults $allConsults -Launcher ([string]$codexExePath) -LoginCache $loginCache -UtcNow $healthNow -OpenAiBaseUrl $openAiBaseUrl -EngineLaunchers $engineLaunchers
        $hint = if ($alternative.Entry) { "; to continue with another reviewer, start a new thread: -Mode new; the roster would select $(Format-ReviewerLineage -Provider $alternative.Identity.Provider -Model $alternative.Identity.Model -Engine ([string]$alternative.Identity.Engine))" } else { '; the roster has no available reviewer for a new thread either' }
        $preflightRefusal += $hint
        $preflightLabel += $hint
    }
    if ($preflightRefusal -and (-not $DryRun -or $detachForeground)) { Stop-WithError $preflightRefusal }
}
# (wave 27c, D4) a launcher probe that could not be started without the host markers was skipped:
# why, in warnings[] (the preflight said "not checked")
foreach ($probeWarning in @($script:ProbeWarnings)) { if ($probeWarning -and -not $runWarnings.Contains([string]$probeWarning)) { $runWarnings.Add([string]$probeWarning) } }
# (wave 29) the engine's provider_config fields known only after the preflight (claude: auth_method
# and api_provider as `claude auth status` reported them) - the identity was resolved before it ran
if ($engineAuth -and $engineSpec.Adapter -and $engineSpec.Adapter.PSObject.Properties['IdentityConfig'] -and $engineSpec.Adapter.IdentityConfig) {
    $icNow = & $engineSpec.Adapter.IdentityConfig -Auth $engineAuth -Launcher $engineLauncher -Endpoint $engineEndpoint
    foreach ($k in @($icNow.Keys)) { $reviewerRecord.provider_config | Add-Member -NotePropertyName ([string]$k) -NotePropertyValue $icNow[$k] -Force }
}
# (wave 29, item 2) claude: its transcripts must not land in the repository under review
if ($engineName -eq 'claude') {
    $claudeLaunchProblem = Get-ClaudeLaunchProblem -RepoRoot $repoRoot -Launcher $engineLauncher -Auth $engineAuth
    if ($claudeLaunchProblem -and (-not $DryRun -or $detachForeground)) { Stop-WithError "the claude engine is refused: $claudeLaunchProblem; nothing was started." }
    if ($claudeLaunchProblem) { $runWarnings.Add("a real run is refused: $claudeLaunchProblem") }
}

# One line on the roster decision (console, dry run, handoff header) and the ledger's
# `roster` object ($null without a roster file).
$rosterLine = ''
$rosterRecord = $null
if ($roster.Exists) {
    $rosterCount = @($roster.Entries).Count
    $rosterPosition = $null
    if ($rosterEntry) { $rosterPosition = [int]$rosterEntry.Position }
    $appliedText = if ($rosterApplied.Count -gt 0) { "$($rosterApplied.ToArray() -join ', ') applied" } else { 'nothing applied' }
    if ($rosterRule -eq 'walk') {
        $rosterLine = "Roster: $($roster.Path) - position $rosterPosition of $rosterCount"
        if ($SkipPreflight) { $rosterLine += ' (-SkipPreflight: taken unchecked)' }
        if ($rosterSkipped.Count -gt 0) { $rosterLine += "; skipped $(Format-RosterSkips $rosterSkipped)" }
    } elseif ($rosterRule -eq 'panel') {
        $rosterLine = "Roster: $($roster.Path) - position $rosterPosition of $rosterCount, panel $(([string]$panelMember.id).Substring(0, 8)) member $([int]$panelMember.position) of $([int]$panelMember.of)"
        if ($rosterSkipped.Count -gt 0) { $rosterLine += "; skipped $(Format-RosterSkips $rosterSkipped)" }
    } elseif ($rosterRule -eq 'provider') {
        if ($rosterEntry) { $rosterLine = "Roster: $($roster.Path) - entry $rosterPosition of $rosterCount for -Provider $Provider ($appliedText)" }
        else { $rosterLine = "Roster: $($roster.Path) - no entry for -Provider $Provider (nothing applied)" }
    } else {
        if ($rosterEntry) { $rosterLine = "Roster: $($roster.Path) - entry $rosterPosition of $rosterCount for -Thread $Thread, $lineageShown ($appliedText)" }
        else { $rosterLine = "Roster: $($roster.Path) - no entry for -Thread $Thread, $lineageShown (nothing applied)" }
    }
    $rosterRecord = [pscustomobject]@{
        path     = $roster.Path
        position = $rosterPosition
        skipped  = [object[]]@($rosterSkipped | ForEach-Object { [pscustomobject]@{ provider = $_.provider; model = $_.model; engine = $(if (Get-PropertyValue $_ 'engine' '') { [string]$_.engine } else { 'codex' }); reason = $_.reason } })
        applied  = [object[]]$rosterApplied.ToArray()
    }
}
# The ledger's `panel` record of a -Panel member ($null otherwise): the same members list in
# every member's entry, and the panel's plan (0.4.x wave 21): concurrency = the most members
# that could run at once, limits = provider label -> members of its endpoint at a time.
$panelRecord = $null
if ($panelMember) {
    $panelRecord = [pscustomobject]@{
        id          = [string]$panelMember.id
        position    = [int]$panelMember.position
        of          = [int]$panelMember.of
        members     = [object[]]@(@($panelMember.members) | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ provider = [string]$_.provider; model = [string]$_.model; state = [string]$_.state; reason = [string]$_.reason } })
        concurrency = [int](Get-PropertyValue $panelMember 'concurrency' 1)
        limits      = (Get-PropertyValue $panelMember 'limits' $null)
        asked       = [int](Get-PropertyValue $panelMember 'asked' ([int]$panelMember.of))
        started     = $null
        usable      = $null
        routing     = (Get-PropertyValue $panelMember 'routing' $null)
        roles_note  = [string](Get-PropertyValue $panelMember 'roles_note' '')
    }
}
if ($rosterLine -and -not $DryRun) { Write-Host $rosterLine }
# (wave 28b, D10) the test-mode line is printed with the run's output (after the commit), never before a
# refusal: a refusal's own message stays the first line
if (-not $DryRun) { foreach ($rw in $runWarnings) { if ($rw -ne $script:TestModeWarning) { Write-Host "WARNING: $rw" -ForegroundColor Yellow } } }
if ($preflightWarning -and -not $DryRun) { Write-Host "WARNING: $preflightWarning" -ForegroundColor Yellow }

# Peak window of the provider (evaluated once, now).
$peakProvider = ''
if ($identity.ProviderSource) { $peakProvider = $identity.Provider }
# Early check (malformed schedules, -OffPeakOnly with no schedule or already inside the
# window, the dry-run preview). The status that counts is evaluated again right before
# launch - preparation (hashing, fingerprints) may cross a window boundary.
$peak = Get-PeakStatusNow -Provider $peakProvider
if ($peak.Error) { Stop-WithError $peak.Error }
if ($OffPeakOnly) {
    if (-not $peakProvider) {
        Stop-WithError "no schedule for provider unknown (the reviewer identity is unresolved: $($identity.Note)); -OffPeakOnly needs a known provider and its CODEX_CONSULT_PEAK_<PROVIDER>."
    }
    if ($null -eq $peak.Peak) {
        Stop-WithError "no schedule for provider $peakProvider; -OffPeakOnly needs $($peak.Variable)."
    }
    if ($peak.Peak) {
        Stop-WithError "-OffPeakOnly: $peakProvider is inside its peak window ($($peak.Schedule); now $($peak.Local)); nothing was started."
    }
}
$peakWarning = ''
if ($peak.Peak -eq $true) { $peakWarning = "WARNING: $peakProvider peak window ($($peak.Schedule)) - this consultation runs at peak tariff." }
$peakLabel = if ($null -eq $peak.Peak) { "unknown ($(if ($peak.Variable) { "$($peak.Variable) not set" } else { 'provider unknown' }))" } elseif ($peak.Peak) { "PEAK ($($peak.Schedule); now $($peak.Local))" } else { "off-peak ($($peak.Schedule); now $($peak.Local); $($peak.Detail))" }

# The prompt's last line; a rollout file is attributed to this run only if it holds it. (A
# panel member's comes from its panel run, which wrote it into the member's record.)
$consultId = [guid]::NewGuid().ToString()
if ($panelMember -and [string](Get-PropertyValue $panelMember 'consult_id' '') -match '^[0-9a-fA-F-]{36}$') { $consultId = [string]$panelMember.consult_id }

# ----------------------------------------------------------------------------- brief, artifacts, schema

# Paths are resolved (and a missing one refused) here; the bytes are hashed under the
# task lock right before the run and again after it (binding drift, see below).
$briefRef = ''
$briefPath = ''
if ($Brief) {
    $briefPath = $Brief
    if (-not [IO.Path]::IsPathRooted($briefPath)) {
        foreach ($base in @($callerCwd, $repoRoot)) {
            $candidate = Join-Path $base $briefPath
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $briefPath = $candidate; break }
        }
    }
    if (-not (Test-Path -LiteralPath $briefPath -PathType Leaf)) {
        Stop-WithError "brief '$Brief' not found (this script never writes briefs; write it first)."
    }
    $briefPath = (Resolve-Path -LiteralPath $briefPath).Path
    $briefRel = Get-RepoRelativePath -Root $repoRoot -Path $briefPath
    if ($briefRel) {
        $briefRef = $briefRel
    } else {
        # Outside the repository: Codex still reads it (read-only sandbox reads are
        # not path-limited), but the prompt must carry the absolute path.
        $briefRef = $briefPath
    }
}

# -Artifact a,b arrives as ONE string through `powershell -File`; split on commas
# unless the whole string names an existing file (Split-ArtifactArgument).
$artifactList = Split-ArtifactArgument -Values $Artifact -Bases @($callerCwd, $repoRoot)
$artifactItems = @(Resolve-ArtifactPaths -Paths $artifactList -Bases @($callerCwd, $repoRoot))

$schemaPath = ''
if (-not $Raw) {
    $schemaPath = [IO.Path]::GetFullPath((Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'schemas') 'consult-reply.schema.json'))
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        Stop-WithError "output schema not found at '$schemaPath' (reinstall the plugin, or pass -Raw for a plain-text consultation)."
    }
}

if ((-not $DryRun -or $detachForeground) -and $isCodex -and -not $codexExePath) {
    Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
}
if ((-not $DryRun -or $detachForeground) -and -not $isCodex -and -not $engineLauncher) {
    Stop-WithError "$engineName CLI not found on PATH (set -EngineExe <path> or the $($engineSpec.ExeEnv) environment variable)."
}

$tmpRoot = [System.IO.Path]::GetTempPath()
$tmpId = [guid]::NewGuid().ToString('N')
$lastMsgPath = Join-Path $tmpRoot "codex-consult-last-$tmpId.md"
$promptPath = Join-Path $tmpRoot "codex-consult-prompt-$tmpId.txt"
$stderrPath = Join-Path $tmpRoot "codex-consult-stderr-$tmpId.txt"
# the format-repair turn (-FormatRetry): its last message, events, stderr and prompt
$repairLastPath = Join-Path $tmpRoot "codex-consult-repair-last-$tmpId.md"
$repairEventsPath = Join-Path $tmpRoot "codex-consult-repair-events-$tmpId.jsonl"
$repairStderrPath = Join-Path $tmpRoot "codex-consult-repair-stderr-$tmpId.txt"
$repairPromptPath = Join-Path $tmpRoot "codex-consult-repair-prompt-$tmpId.txt"
# the denial-retry turn of an engine (-DenialRetry): its stdin and stderr (its event stream
# goes to handoffs/, like the run's)
$denialPromptPath = Join-Path $tmpRoot "codex-consult-denial-prompt-$tmpId.txt"
$denialStderrPath = Join-Path $tmpRoot "codex-consult-denial-stderr-$tmpId.txt"
# (wave 24) the timeout-continuation turn: its prompt (codex and agy: its stdin), its stderr and
# - codex - its last message (its event stream goes to handoffs/, like the run's)
$continuePromptPath = Join-Path $tmpRoot "codex-consult-continue-prompt-$tmpId.txt"
$continueStderrPath = Join-Path $tmpRoot "codex-consult-continue-stderr-$tmpId.txt"
$continueLastPath = Join-Path $tmpRoot "codex-consult-continue-last-$tmpId.md"
# (wave 23, D1) an engine whose prompt travels in a file (muse: --prompt-file <the turn's prompt
# file>) reads an EMPTY stdin from here; codex and agy read their prompt file as stdin.
$engineStdinPath = Join-Path $tmpRoot "codex-consult-stdin-$tmpId.txt"
$promptByFile = (-not $isCodex -and $engineSpec.PromptTransport -eq 'file')
$stdinPath = $(if ($promptByFile) { $engineStdinPath } else { $promptPath })

# ----------------------------------------------------------------------------- lock + run
#
# Everything from here to the end runs while <task>/.consult.lock is HELD OPEN (not in
# -DryRun, which writes nothing at all): the lock is taken BEFORE the recovery records,
# sessions.json and findings.json are read and before the consult number n and the
# handoff number NN are allocated, and released in `finally` by closing the handle
# (an `exit` inside `try` still runs it; the lock file itself is permanent). A -Panel
# member takes no lock: its panel run holds it for the whole panel, judged the records
# and handed the member its n and NN.
#
# Recovery record <task>/.consult.pending.json (a panel member: .consult.pending-<NN>.json;
# atomic replace):
#   1. read EVERY record of the task first: unusable -> refuse; a live writer or codex
#      process of an interrupted run -> refuse; otherwise their reservations are consumed
#      (numbering skips past them; consumed member records are removed)
#   2. {state: reserved, n, nn, reply, consult_id, pid, start_time}
#                                       after allocation - replaces the old record (a
#                                       member: its record, rewritten at its start)
#   3. {state: launching}               right before Start-Process (a failed write
#                                       aborts the run before codex exists; a member
#                                       whose panel run is gone stops here instead)
#   4. {state: running, child_pid}      right after Start-Process; if this write fails
#                                       the codex tree is killed, the run is recorded
#                                       as failed and the record stays 'launching'
#   5. {state: survivors, survivors[]}  after a timeout kill that left survivors; kept
#   6. {state: committing}              the run is over; waiting for the write lock (kept,
#                                       naming the reply files, when the lock is never had)
#   7. deleted after the ledger commit (under the write lock) when codex is known to be gone
# If this process dies at any point, the record tells the next run what to check.
#
# Write order after the run (0.4.x wave 21: 2-4 and the record's removal under
# <task>/.consult.write.lock, on stores RE-READ under it - Enter-StoreCommit):
#   1. handoffs/NN-codex-<slug>.reply.json  byte-for-byte copy of Codex's last message,
#                                           BEFORE any parsing (a failed copy is a
#                                           bridge failure; the temp original is kept)
#   2. handoffs/NN-codex-<slug>.md          header + verbatim reply (+ the section rendered
#                                           from the ingest into the FRESH findings.json)
#   3. findings.json                        new findings, reviewer checks
#   4. sessions.json                        the ledger entry, inserted by n - the commit point
# Both JSON stores are replaced atomically (temp file + replace), and an existing
# store that is empty or unparseable is refused as corruption. A crash between 3 and
# 4 leaves findings or reviewer checks whose consult has no ledger entry;
# `codex-findings.ps1 -List` flags them as ORPHAN, and numbering never reuses a
# number that any finding, reviewer check, handoff file or reservation names.

$lock = $null
$commit = $null
$keepPending = $false
$keepLastMsg = $false
$keepContinueLast = $false
if (-not $DryRun) {
    [void][IO.Directory]::CreateDirectory($handoffsDir)
    if (-not $panelMember) {
        $lock = Enter-TaskLock -TaskDir $taskDir -Task $Task
        if (-not $lock.Acquired) { Stop-WithError $lock.Message }
    }
}

try {
    # ------------------------------------------------------------------------- recovery records

    # EVERY recovery record of the task (.consult.pending.json and a panel's
    # .consult.pending-<NN>.json), read and judged BEFORE anything is written (a dry run only
    # reports). A panel member skips this: its panel run judged them all under the lock.
    $pendingItems = @()
    if (-not $panelMember) {
        $pendingAll = Read-TaskPendingRecords -TaskDir $taskDir
        if ($pendingAll.Error) { Stop-WithError $pendingAll.Error }
        if ($pendingAll.Active -and (-not $DryRun -or $detachForeground)) { Stop-WithError $pendingAll.Active.Check.Message }
        $pendingItems = @($pendingAll.Items)
    }

    # ------------------------------------------------------------------------- ledgers

    # Read for the numbering, the parent thread and the prompt. Written only by the commit,
    # re-read under the write lock (Enter-StoreCommit) - never from this snapshot.
    $sessions = Read-JsonStore -Path $sessionsPath
    if ($null -eq $sessions) {
        $sessions = [pscustomobject]@{
            task_id = $Task
            cwd     = $repoRoot
            codex   = [pscustomobject]@{
                tool     = $(if ($isCodex) { $codexVersion } else { $harness })
                consults = [object[]]@()
            }
        }
    }
    if (-not $sessions.PSObject.Properties['codex']) {
        $sessions | Add-Member -NotePropertyName 'codex' -NotePropertyValue ([pscustomobject]@{ tool = $(if ($isCodex) { $codexVersion } else { $harness }); consults = [object[]]@() })
    }
    if (-not $sessions.codex.PSObject.Properties['consults']) {
        $sessions.codex | Add-Member -NotePropertyName 'consults' -NotePropertyValue ([object[]]@())
    }
    # (`tool` is the codex version; an agy run leaves it as it is)
    if ($isCodex) { $sessions.codex.tool = $codexVersion }

    # findings.json is read in both modes - numbering must see every finding and
    # reviewer check - but only structured mode lists open findings and ingests.
    $findingsStore = Read-FindingsFile -Path $findingsPath -Task $Task
    $openFindings = @()
    if (-not $Raw) {
        $openFindings = @($findingsStore.findings | Where-Object { $script:OpenStatuses -contains [string](Get-PropertyValue $_ 'status' '') })
        # A panel member lists only what was open when the panel started: the prompt is the
        # same for every member, and a member never sees an earlier member's findings.
        if ($panelMember -and $panelMember.PSObject.Properties['listed_ids']) {
            $panelBaseline = @(@($panelMember.listed_ids) | Where-Object { $_ } | ForEach-Object { [string]$_ })
            $openFindings = @($openFindings | Where-Object { $panelBaseline -contains [string]$_.id })
        }
    }
    $listedIds = [string[]]@($openFindings | ForEach-Object { [string]$_.id })
    # { id; severity; status } of the listed prior findings, for verdict validation.
    $priorInfo = @($openFindings | ForEach-Object {
            [pscustomobject]@{ id = [string]$_.id; severity = [string](Get-PropertyValue $_ 'severity' ''); status = [string](Get-PropertyValue $_ 'status' '') }
        })

    # ------------------------------------------------------------------------- mode + thread

    # Older ledger entries (0.1/0.2: no `reviewer`) are left untouched; their threads
    # have unknown provenance and are never parents. The parent is lineage-scoped
    # (Select-ParentThread): the newest verified thread of this run's lineage on the
    # same endpoint, or -Thread when it is one.
    $consults = @($sessions.codex.consults | Where-Object { $_ })
    $selection = Select-ParentThread -Consults $consults -Identity $identity -Mode $Mode -Thread $Thread
    if ($selection.Error) { Stop-WithError $selection.Error }
    $Mode = $selection.Mode
    $parentThread = $selection.Parent
    $parentNote = $selection.Note

    # ------------------------------------------------------------------------- numbering

    # The old recovery records' reservations are consumed here: numbering skips past their
    # n / nn (and past everything else on disk that names a number). A panel member's n and
    # NN were assigned by its panel run.
    if ($panelMember) {
        $numbers = $null
        $consultN = $memberN
        $nn = $memberNn
    } else {
        $numbers = Get-NextNumbers -Consults $consults -Store $findingsStore -HandoffsDir $handoffsDir -Leftovers @($pendingItems | ForEach-Object { $_.Record })
        $consultN = $numbers.N
        $nn = $numbers.Nn
    }
    $recoveredLines = New-Object System.Collections.Generic.List[string]
    for ($pi = 0; $pi -lt $pendingItems.Count; $pi++) {
        $pItem = $pendingItems[$pi]
        $pNum = $numbers.Items[$pi]
        $state = [string](Get-PropertyValue $pItem.Record 'state' '')
        # a panel member's record is named (the single run's record is the classic one)
        $which = $(if ($pItem.Name -ine '.consult.pending.json') { "$($pItem.Name): " } else { '' })
        if ($DryRun) {
            if ($pItem.Check.Active) { $recoveredLines.Add("$($pItem.Path) (state '$state', n=$($pNum.N), nn=$($pNum.Nn)): the next run would be REFUSED - $($pItem.Check.Message)") }
            else { $recoveredLines.Add("$($pItem.Path) (state '$state', n=$($pNum.N), nn=$($pNum.Nn); $($pItem.Check.Check)): the next run recovers it; numbering continues past it.") }
        } elseif ($pNum.Recovered) {
            $line = "recovered reservation n=$($pNum.N), nn=$($pNum.Nn) ($($which)state '$state' of an interrupted run; $($pItem.Check.Check)); numbering continues past it."
            $recoveredLines.Add($line)
            Write-Host "codex-consult: $line" -ForegroundColor Yellow
        } else {
            # Its consultation reached the ledger (e.g. a failed registration or timeout
            # survivors that have exited since): nothing to recover, only to clear.
            $line = "cleared the recovery record of consult n=$($pNum.N), nn=$($pNum.Nn) ($($which)state '$state'; $($pItem.Check.Check)); its ledger entry exists."
            $recoveredLines.Add($line)
            Write-Host "codex-consult: $line" -ForegroundColor Yellow
        }
    }
    # NB: PowerShell variable names are case-insensitive - never call these $replyName,
    # that would silently clobber the -ReplyName parameter.
    # The handoff prefix is the engine's (NN-codex-<slug>.md, NN-agy-<slug>.md, ...).
    $enginePrefix = [string]$engineSpec.Prefix
    $replyFileName = "$nn-$enginePrefix-$ReplyName.md"
    $eventsFileName = "$nn-$enginePrefix-$ReplyName.events.jsonl"
    $replyJsonFileName = "$nn-$enginePrefix-$ReplyName.reply.json"
    $replyPath = Join-Path $handoffsDir $replyFileName
    $eventsPath = Join-Path $handoffsDir $eventsFileName
    $replyJsonPath = Join-Path $handoffsDir $replyJsonFileName
    $replyRel = "handoffs/$replyFileName"
    $eventsRel = "handoffs/$eventsFileName"
    $replyJsonPlanned = ''
    if (-not $Raw) { $replyJsonPlanned = "handoffs/$replyJsonFileName" }
    # This run's reservation replaces the consumed record (atomically; if the write
    # fails the old record is left intact and nothing was started). A panel member updates
    # the record it rewrote at its start (its reply, consultation id and launcher).
    if (-not $DryRun) {
        if ($panelMember) {
            $pendingRecord.reply = $replyRel
            $pendingRecord.consult_id = $consultId
            $pendingRecord.launcher = $engineLauncher
            $pendingRecord.engine = $engineName
            try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
                Stop-WithError "could not write the recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); nothing was started."
            }
        } else {
            $pendingRecord = New-PendingRecord -State 'reserved' -N $consultN -Nn $nn -Reply $replyRel -Started $runStarted -Launcher $engineLauncher -ConsultId $consultId -Engine $engineName
            try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
                Stop-WithError "could not write the recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); nothing was started."
            }
            # The consumed records of a panel's members go now (their numbers are skipped).
            foreach ($pItem in $pendingItems) {
                if ($pItem.Path -ieq $pendingPath) { continue }
                $rmError = Remove-PendingFile -Path $pItem.Path
                if ($rmError) { Write-Host "codex-consult: could not remove the consumed recovery record $($pItem.Path) ($rmError)" -ForegroundColor Yellow }
            }
        }
    }
    # (wave 25) a detached run: its member with the reviewer and the numbers of this run
    if ($script:DetachRun) { Set-DetachedMembers @(New-DetachedMember -Position $detachMemberPosition -Lineage $lineageShown -N $consultN -Handoff $nn -Reply $replyRel) }

    # ------------------------------------------------------------------------- prompt

    $nl = "`r`n"
    # (wave 26b, D16) the reviewer's context window (its roster entry's context_tokens), 0 = unknown
    $contextTokens = $(if ($rosterEntry) { [int](Get-PropertyValue $rosterEntry 'ContextTokens' 0) } else { 0 })
    # (wave 28b, D15) the window reaches the ENGINE: a codex reviewer with a roster context_tokens n
    # gets `-c model_context_window=<n>` and `-c model_auto_compact_token_limit=<0.8 n>` (keys of the
    # Codex config, both present in codex-cli 0.155.1) on every turn - unless -CodexConfig or the
    # entry's codex_config already sets that key (the operator's value wins). Ledger
    # `context_window` {tokens, auto_compact_limit, items} (null without one). For agy and muse the
    # key guards only the start (the prompt estimate - their CLIs take no such option).
    $contextConfig = New-Object System.Collections.Generic.List[string]
    $contextWindowRecord = $null
    if ($contextTokens -gt 0 -and $isCodex) {
        $compactAt = [long][Math]::Floor(0.8 * $contextTokens)
        foreach ($cw in @(@('model_context_window', [long]$contextTokens), @('model_auto_compact_token_limit', $compactAt))) {
            if (@($extraConfig | Where-Object { ([string]$_).Trim() -match ('^' + [regex]::Escape([string]$cw[0]) + '\s*=') }).Count -eq 0) { $contextConfig.Add("$($cw[0])=$($cw[1])") }
        }
        $contextWindowRecord = [pscustomobject]@{ tokens = [long]$contextTokens; auto_compact_limit = $compactAt; items = [object[]]$contextConfig.ToArray() }
    }
    $promptParts = New-Object System.Collections.ArrayList
    # Structured mode: the output contract comes FIRST, before the ask and the brief - a
    # reviewer that reads a long brief first tends to answer in prose (handoffs 17/18).
    if (-not $Raw) {
        [void]$promptParts.Add('FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON object (schema_version "1") - no code fence, no text before or after it. The Markdown answer lives only inside its reply_markdown string; each defect goes in findings[]. A prose final message cannot be ingested, however good the answer is.')
    }
    if ($Prompt) { [void]$promptParts.Add($Prompt.Trim()) }
    # (wave 26b, D16) a reviewer with a known context window is told so, right after the ask
    if ($contextTokens -gt 0) { [void]$promptParts.Add("Your context window is $contextTokens tokens: read only what the brief points to; prefer targeted reads.") }
    if ($roleInfo) {
        # (wave 26, R16, D8) the role: after the ask, before the brief - never inside the output
        # contract; it narrows what the reviewer looks at, nothing else changes
        [void]$promptParts.Add("Your role in this review: $($roleInfo.Name). Focus on what it asks for; the reply format, the verdict rules and the read-only rule stay as stated.$nl$(($roleInfo.Text -replace "`r`n", "`n") -replace "`n", $nl)")
    }
    if ($briefRef) {
        [void]$promptParts.Add("Read the brief at ``$briefRef`` (path relative to the repository root, which is your working directory) and answer every numbered question in it.")
    }
    if ($rangeStat) {
        # (wave 24, T1) the size of the reviewed range, measured once by the bridge
        [void]$promptParts.Add("Review range: ``$Range`` - $rangeText ($($rangeStat.Insertions) insertions, $($rangeStat.Deletions) deletions; git diff --shortstat). Plan your reading for its size.")
    }
    if (-not $isCodex) {
        # The engine's own tools line (D11): agy's print mode auto-denies a tool it cannot grant
        # and its --sandbox does not block file writes (F11, F12); muse runs with its write,
        # shell and web tools disabled.
        [void]$promptParts.Add([string]$engineSpec.ToolsLine)
    }
    if ($Raw) {
        # (a plain -Raw consultation carries no purpose paragraph, as in 0.1; a chore does)
        if ($Purpose -eq 'chore') { [void]$promptParts.Add("Review purpose: chore. $($purposeText['chore'])") }
        [void]$promptParts.Add("Constraints: write NO files and make no edits - this is a read-only consultation; answer in English; keep the answer under $maxWordsResolved words.")
    } else {
        if ($Purpose) {
            [void]$promptParts.Add("Review purpose: $Purpose. $($purposeText[$Purpose])")
        }
        if ($openFindings.Count -gt 0) {
            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add('Findings from earlier consultations in this task that are still open (id - status - locations - claim - trigger - verify):')
            foreach ($f in $openFindings) {
                $line = "- $($f.id) - $($f.status) - $(Format-Locations -Locations (Get-PropertyValue $f 'locations' @())) - $(ConvertTo-OneLine ([string](Get-PropertyValue $f 'claim' '')))"
                $trigger = ConvertTo-OneLine ([string](Get-PropertyValue $f 'trigger' ''))
                if ($trigger) { $line += " - trigger: $trigger" }
                $verify = ConvertTo-OneLine ([string](Get-PropertyValue $f 'verification' ''))
                if ($verify) { $line += " - verify: $verify" }
                $lines.Add($line)
            }
            $lines.Add('Report each listed id in `prior_findings` as fixed, still-open or not-checked (unknown-id if you cannot find it). Do not file a still-open one again as a new finding unless the claim changed; when a new finding replaces a listed one (a split, a merge, a corrected claim), name the old id in its `supersedes`.')
            [void]$promptParts.Add(($lines.ToArray() -join $nl))
        }
        $priorLine = '- prior_findings: an empty array (no earlier findings are open in this task).'
        if ($openFindings.Count -gt 0) {
            $priorLine = '- prior_findings: one entry {id, status, note} per id listed above; status fixed | still-open | not-checked | unknown-id.'
        }
        $schemaLines = @(
            $(if ($schemaTransport -eq 'prompt-only') { 'Reply format: your final message must be exactly one JSON object - no code fence, no text before or after it - that satisfies the JSON Schema given at the end of this section (schema_version "1"). Field meaning:' } else { 'Reply format: your final message must be exactly one JSON object matching the output schema you were given (schema_version "1"). Field meaning:' }),
            '- reply_markdown: your full answer in Markdown, answering every numbered question by number. This is what people read - a complete Markdown answer, but it lives INSIDE the JSON string, never as the message itself. The word limit below applies to reply_markdown only - never shorten, merge or drop findings to fit it.',
            '  If you want evidence you cannot obtain read-only, end reply_markdown with a section `## Requested checks` listing at most 5 items `RC1`..`RCn`, each ONE runnable command or procedure with its working directory, the permission it needs (read-only / workspace-write), the observation that would settle it, and a budget (time or scope); refer to a finding by its position in your findings array (`finding #2`), by an earlier id (`F04-1`) or by the invariant name. "Investigate X" is not a check. Omit the section if you need nothing.',
            '- findings: one item per concrete defect or risk you assert; an empty array is a valid answer.',
            '  - severity: blocker (must be fixed before acceptance) | major | minor | note.',
            '  - locations: every place the finding concerns, each {path, line} with the path relative to the repository root and line null when no single line applies; an empty array when the finding is not tied to a place (e.g. a missing interface).',
            '  - claim: the assertion, self-contained. trigger: the input or state that exposes it.',
            '  - evidence: what you ALREADY did to support the claim, one entry per source: kind (read-code: you read the code there | ran-command: you ran something and saw the result | inferred: deduced from other evidence | assumed: not checked), reference (the file, command or log you looked at), observation (what you saw there). At least one entry; use kind "assumed" when you checked nothing.',
            '  - verification: one step the coordinator can run next to confirm the claim (prospective - not what you already did).',
            '  - remedy: the fix you propose.',
            '  - supersedes: ids of earlier findings this one replaces (a split, a merge, a corrected claim); otherwise an empty array.',
            "- verdict: ACCEPT, HOLD or REJECT for acceptance and diff-review consultations, ADVISE for every other consultation; this one takes $verdictRule. verdict_reason: one sentence.",
            $priorLine,
            '- unproven: scenarios the evidence does not cover (an empty array if none).',
            '- first_run_checklist: for an acceptance consultation, what must be observed in logs or output on the first real run before an exit code 0 is believed; an empty array for other purposes.',
            '- schema_version: always "1".'
        )
        [void]$promptParts.Add(($schemaLines -join $nl))
        if ($schemaTransport -eq 'prompt-only') {
            # The endpoint does not receive the schema: it travels here instead.
            $schemaText = ([IO.File]::ReadAllText($schemaPath, $script:Utf8NoBom).Trim() -replace "`r`n", "`n") -replace "`n", $nl
            [void]$promptParts.Add("JSON Schema of the reply:$nl$schemaText")
        }
        [void]$promptParts.Add("Constraints: write NO files and make no edits - this is a read-only consultation; answer in English; keep reply_markdown under $maxWordsResolved words.")
    }
    # (wave 28c, D11 / F43-3, F44-6) a member with a context window (context_tokens) may compact it
    # mid-review, and a summary may lose the brief: its prompt ends by naming the brief again - the
    # last line before the consultation id (which stays last). (wave 28d, D7 / F50-2) Without a brief
    # file the one-line ask itself is repeated there. (wave 28e, E4 / F54-4) A multi-line ask is not
    # folded into one line: its FIRST line is repeated whole (whitespace inside it folded; longer than
    # 300 characters it is cut and points to the top of the prompt), followed by the count of the
    # remaining (non-blank) lines - " (+<n> more lines)"; a one-line ask as before, cut at 300.
    $rereadLine = ''
    if ($contextTokens -gt 0 -and $briefRef) { $rereadLine = "Before you answer, re-read the brief: ``$briefRef``." }
    elseif ($contextTokens -gt 0 -and $Prompt -and $Prompt.Trim()) {
        $askLines = @(([string]$Prompt).Trim() -split "\r?\n" | Where-Object { $_.Trim() })
        $askLine = ConvertTo-OneLine $askLines[0]
        if ($askLine.Length -gt 300) { $askLine = $askLine.Substring(0, 300) + '... (cut here: the whole ask is at the top of this prompt)' }
        $askMore = $askLines.Count - 1
        if ($askMore -gt 0) { $askLine += " (+$askMore more $(if ($askMore -eq 1) { 'line' } else { 'lines' }))" }
        $rereadLine = "Before you answer, re-read the ask: $askLine"
    }
    if ($rereadLine) { [void]$promptParts.Add($rereadLine) }
    # Always the LAST line: it ties a rollout file to this run (Find-ThreadInRollouts).
    [void]$promptParts.Add("Consultation id: $consultId")
    $promptText = [string]::Join("$nl$nl", $promptParts.ToArray())
    # (wave 26b, D16) fork/resume on a reviewer with a context window: the continued thread's last
    # recorded context (the ledger entry's usage.input_tokens, else its event stream's last usage)
    # plus this prompt's estimate ((prompt + brief) / 4) beyond 80% of context_tokens -> a NEW
    # thread instead, recorded (ledger mode_fallback {from, to, reason}; a summary line); the
    # prompt then names the reviewer's previous reply file so it can re-read its earlier review
    $modeFallbackRecord = $null
    if ($contextTokens -gt 0 -and ($Mode -eq 'fork' -or $Mode -eq 'resume') -and $parentThread) {
        $parentEntry = @($consults | Where-Object { [string](Get-PropertyValue $_ 'thread' '') -eq $parentThread }) | Select-Object -Last 1
        $priorTokens = 0
        $priorUsage = $(if ($parentEntry) { Get-PropertyValue $parentEntry 'usage' $null } else { $null })
        if ($null -ne $priorUsage) { [void][int]::TryParse([string](Get-PropertyValue $priorUsage 'input_tokens' ''), [ref]$priorTokens) }
        if ($priorTokens -le 0 -and $parentEntry -and [string](Get-PropertyValue $parentEntry 'events' '')) {
            $pev = Join-Path $taskDir ([string]$parentEntry.events)
            if ((Get-EntryEngine $parentEntry) -eq 'codex' -and (Test-Path -LiteralPath $pev -PathType Leaf)) {
                try { $pu = Get-UsageFromEvents -Path $pev; if ($pu) { [void][int]::TryParse([string](Get-PropertyValue $pu 'input_tokens' ''), [ref]$priorTokens) } } catch { }
            }
        }
        $briefChars = 0
        if ($briefPath -and (Test-Path -LiteralPath $briefPath -PathType Leaf)) { $briefChars = [int](Get-Item -LiteralPath $briefPath).Length }
        # (wave 28d, D8 / F48-4) the re-read line is bridge text: it takes no part in the decision to
        # continue the thread (the same prompt decides the same way with or without it)
        $rereadChars = $(if ($rereadLine) { $rereadLine.Length + 2 * $nl.Length } else { 0 })
        $newEstimate = [int][Math]::Ceiling(($promptText.Length - $rereadChars + $briefChars) / 4.0)
        if (($priorTokens + $newEstimate) -gt $script:ContextShare * $contextTokens) {
            $modeFallbackRecord = [pscustomobject]@{ from = $Mode; to = 'new'; reason = "the $Mode thread $parentThread last carried $priorTokens tokens; with this prompt (est. $newEstimate) that exceeds 80% of the reviewer's context window ($contextTokens tokens)" }
            Write-Host "codex-consult: mode $Mode -> new: $($modeFallbackRecord.reason)" -ForegroundColor Yellow
            $prevReply = $(if ($parentEntry -and [string](Get-PropertyValue $parentEntry 'reply' '')) { Get-RepoRelativePath -Root $repoRoot -Path (Join-Path $taskDir ([string]$parentEntry.reply)) } else { '' })
            $Mode = 'new'
            $parentThread = ''
            $parentNote = "mode fallback: $($modeFallbackRecord.reason)"
            if ($prevReply) {
                $promptParts.Insert($promptParts.Count - 1, "Your previous reply in this task is ``$($prevReply.Replace('\', '/'))``: this consultation starts a new thread because the previous one is too large for your context window - re-read that reply if you need your earlier review.")
                $promptText = [string]::Join("$nl$nl", $promptParts.ToArray())
            }
        }
    }

    # ------------------------------------------------------------------------- argv

    if (-not $isCodex) {
        # The engine's own argv from ONE turn-options object (wave 23, D1): the schema natively
        # unless prompt-only, the thread on resume, the effort (agy: only -NativeEffort; muse:
        # the mapped value), this turn's prompt file (muse), -MaxModelSteps (muse).
        $engineSchemaArg = ''
        if (-not $Raw -and $schemaTransport -eq 'native') { $engineSchemaArg = $schemaPath }
        $engineThreadArg = ''
        if ($Mode -eq 'resume' -or ($Mode -eq 'fork' -and @($engineSpec.Modes) -contains 'fork')) { $engineThreadArg = $parentThread }
        # (wave 29, D4) the model every turn sends: the roster's on a new thread; on resume and fork the
        # id the parent thread resolved (its ledger entry's engine_run.model_resolved) - a thread is
        # one resolved model, never a floating alias
        if ($engineName -eq 'claude' -and $engineThreadArg) {
            $pinnedEntry = @($consults | Where-Object { [string](Get-PropertyValue $_ 'thread' '') -eq $parentThread }) | Select-Object -Last 1
            $pinnedModel = [string](Get-PropertyValue (Get-PropertyValue $pinnedEntry 'engine_run' $null) 'model_resolved' '')
            if ($pinnedModel) { $engineModel = $pinnedModel }
        }
        # (wave 29, item 2) a new thread of an engine that mints its id (claude --session-id): known
        # before the first byte - a turn killed before its result still has a thread
        $engineNewThread = ''
        if (-not $engineThreadArg -and (Get-PropertyValue $engineSpec 'MintsThread' $false)) { $engineNewThread = [guid]::NewGuid().ToString() }
        # (wave 29, item 1) the directories outside the repository the reviewer must read (claude
        # --restricted confines its file tools to the working directories): a rooted collab directory,
        # the brief's, the artifacts'
        $engineAddDirs = New-Object System.Collections.Generic.List[string]
        if (Get-PropertyValue $engineSpec 'AddDirs' $false) {
            $outsideDirs = New-Object System.Collections.Generic.List[string]
            if ($collabRoot) { $outsideDirs.Add([string]$collabRoot) }
            if ($briefPath) { $outsideDirs.Add((Split-Path -Parent ([string]$briefPath))) }
            foreach ($ai in @($artifactItems)) { if ($ai -and [string]$ai.full) { $outsideDirs.Add((Split-Path -Parent ([string]$ai.full))) } }
            foreach ($od in $outsideDirs) {
                if (-not $od) { continue }
                $odFull = [IO.Path]::GetFullPath($od).TrimEnd([char]'\', [char]'/')
                if ($null -eq (Get-RepoRelativePath -Root $repoRoot -Path $odFull) -and -not $engineAddDirs.Contains($odFull)) { $engineAddDirs.Add($odFull) }
            }
        }
        $mainTurn = New-EngineTurnOptions -Model $engineModel -Mode $Mode -Thread $engineThreadArg -PromptFile $promptPath -Schema $engineSchemaArg -Effort $effortSent -NativeEffort $NativeEffort -MaxSteps $MaxModelSteps -NewThread $engineNewThread -AddDirs ([string[]]$engineAddDirs.ToArray()) -Auth $engineAuth
        $argv = & $engineSpec.Adapter.Argv -Turn $mainTurn
    } else {
        # Exec-level options MUST precede the fork|resume subcommand: `codex exec fork --help`
        # has no --sandbox/--color, and placing them after the subcommand fails with
        # "unexpected argument". --output-schema is exec-level too.
        $argv = @(
            'exec',
            '--sandbox', $Sandbox,
            '--color', 'never',
            '--json'
        )
        # The resolved model and provider are pinned whenever they are known, so the run
        # cannot drift from what the ledger records (values are TOML strings for -c).
        if ($identity.ModelSource -ne 'unknown') { $argv += @('-m', $identity.Model) }
        $argv += @('-c', ('model_reasoning_effort="' + (ConvertTo-TomlBasicString $effortSent) + '"'))
        if ($identity.ProviderSource) { $argv += @('-c', ('model_provider="' + (ConvertTo-TomlBasicString $identity.Provider) + '"')) }
        foreach ($ec in $extraConfig) { $argv += @('-c', $ec) }
        foreach ($cc in $contextConfig) { $argv += @('-c', $cc) }
        $argv += @('-o', $lastMsgPath)
        if (-not $Raw -and $schemaTransport -eq 'output-schema') { $argv += @('--output-schema', $schemaPath) }
        if ($Mode -eq 'fork') { $argv += @('fork', $parentThread) }
        elseif ($Mode -eq 'resume') { $argv += @('resume', $parentThread) }
        # The prompt is piped on stdin ('-'): a prompt passed as a positional argument
        # would travel through the npm codex.cmd shim on Windows, where cmd.exe still
        # expands %VAR% inside double quotes and would corrupt briefs that mention
        # %APPDATA% & co.
        $argv += '-'
    }

    $commandStr = "$($engineSpec.Command) " + (Format-Argv $argv)
    # What the engine reads on stdin: codex the prompt itself, agy one NDJSON line, muse nothing
    # (its prompt is the prompt file named in its argv).
    $stdinText = $promptText
    if (-not $isCodex) { $stdinText = & $engineSpec.Adapter.Stdin -Prompt $promptText }
    # A .cmd launcher expands %VAR% inside quoted arguments (F02-14): a real run is refused.
    $argvHazard = ''
    if (-not $isCodex) { $argvHazard = Get-CmdArgvHazard -Launcher $engineLauncher -Argv $argv }
    # (wave 29, D9) an engine with a bound on its stdin prompt (claude: 1 MiB): a larger prompt is
    # refused before anything starts
    $promptBound = ''
    $maxPromptBytes = [long](Get-PropertyValue $engineSpec 'MaxPromptBytes' 0)
    if (-not $isCodex -and $maxPromptBytes -gt 0) {
        $promptBytes = $script:Utf8NoBom.GetByteCount([string]$stdinText)
        if ($promptBytes -gt $maxPromptBytes) { $promptBound = "brief too large for this engine: the prompt is $promptBytes bytes, the $engineName engine takes at most $maxPromptBytes bytes on stdin" }
    }
    if ($promptBound -and (-not $DryRun -or $detachForeground)) { Stop-WithError "$promptBound; nothing was started." }

    # (wave 25, R12) -Detach: every check a real run makes before its lock has passed (D2; the
    # launch hazard above too) - the background runs the consultation; this process writes the
    # `starting` record and returns. The budget (D4): the member guard of this run + 120 s.
    if ($detachForeground) {
        if ($argvHazard) { Stop-WithError "the $engineName run would be refused before launch: $argvHazard; nothing was started." }
        $detachGuard = Get-PanelMemberGuard -TimeoutSec $TimeoutSec -ContinueSec $ContinueSec -Repair:$repairEnabled -DenialRetry:([bool]($engineSpec.DenialRetry -and $DenialRetry -eq 1))
        $detachBudget = Get-DetachedBudget -Groups @([pscustomobject]@{ Limit = 1; Positions = @(1) }) -GuardOf @{ 1 = $detachGuard }
        $detachWarnings = @($runWarnings.ToArray()) + @($preflightWarning, ($peakWarning -replace '^WARNING:\s*', ''))
        Start-DetachedRun -Kind 'run' -Members @(New-DetachedMember -Position $detachMemberPosition -Lineage $lineageShown) -Budget $detachBudget -Plan "a single run of $lineageShown (purpose $purposeLabel, timeout $TimeoutSec s)" -BriefFull $briefPath -ArtifactFull @($artifactItems | ForEach-Object { $_.full }) -Warnings $detachWarnings
    }

    # ------------------------------------------------------------------------- bindings

    # Hashed now, under the lock (and again after the run): the brief and the artifacts
    # live outside the tree fingerprint (collab dir / ignored or external files).
    $briefSha = ''
    if ($briefPath) { $briefSha = Get-FileSha256OrMissing -Path $briefPath }
    $artifactHashes = @(Get-ArtifactHashes -Artifacts $artifactItems)
    # Fingerprint of the tree under review, before the run (and again after it).
    $revBefore = Get-RevisionInfo -Root $repoRoot -CollabRoot $collabRoot

    # ------------------------------------------------------------------------- dry run

    if ($DryRun) {
        $previewFindings = [pscustomobject]@{ blocker = 0; major = 0; minor = 0; note = 0 }
        $previewIds = @()
        if (-not $Raw) { $previewIds = @("F$nn-1", '...') }
        $previewArtifacts = @($artifactHashes | ForEach-Object { [pscustomobject]@{ path = $_.path; sha256 = $_.sha256; sha256_after = '<computed after the run>' } })
        $preview = [pscustomobject]@{
            n                               = $consultN
            when                            = (Get-IsoTimestamp)
            purpose                         = $Purpose
            topics                          = [object[]]@($topicList)
            role                            = $(if ($roleInfo) { $roleInfo.Name } else { '' })
            consult_id                      = $consultId
            reviewer                        = $reviewerRecord
            lineage                         = $lineage
            coordinator                     = $coordinatorRecord
            preflight                       = $preflight
            preflight_warning               = $preflightWarning
            roster                          = $rosterRecord
            panel                           = $panelRecord
            parent_thread                   = $parentThread
            thread                          = '<filled from the event stream>'
            thread_source                   = $(if ($isCodex) { 'events|rollout (verified by consultation id)|unknown' } else { 'events|unknown' })
            thread_candidate                = $(if ($isCodex) { '<"" or an unverified rollout uuid>' } else { '<"" or a conversation id that is never a parent>' })
            mode                            = $Mode
            mode_fallback                   = $modeFallbackRecord
            command                         = $commandStr
            child_env_scrubbed              = [object[]]@($childEnvScrubbed)
            brief                           = $briefRef
            range                           = $rangeRecord
            prompt_chars                    = $promptText.Length
            reply                           = $replyRel
            reply_json                      = $replyJsonPlanned
            events                          = $eventsRel
            partial_reply                   = "<'' or handoffs/$nn-$enginePrefix-$ReplyName.partial.md after a timeout kill>"
            model                           = $modelLabel
            effort                          = $effortSent
            effort_requested                = $effortPlan.Requested
            effort_sent                     = $effortSent
            effort_mapping                  = $effortPlan.Mapping
            effort_caps                     = $effortPlan.Caps
            effort_confirmed                = $null
            max_words                       = $maxWordsResolved
            sandbox                         = $sandboxRecord
            timeout_sec                     = $TimeoutSec
            timeout_source                  = $timeoutSource
            continue_sec                    = $ContinueSec
            extra_config                    = [object[]]$extraConfig.ToArray()
            extra_config_source             = $extraConfigSource
            context_window                  = $contextWindowRecord
            peak                            = $peak.Peak
            peak_schedule                   = $peak.Schedule
            peak_source                     = $peak.Source
            peak_evaluated_at               = $peak.EvaluatedAt
            structured                      = $(if ($Raw) { $false } else { '<true when the reply validates>' })
            schema                          = $(if ($Raw) { '' } else { 'consult-reply v1' })
            schema_transport                = $schemaTransport
            schema_transport_source         = $schemaTransportSource
            validation_error                = $(if ($Raw) { '' } else { '<"" or the first validation error>' })
            format_retry                    = $(if (-not $repairEnabled) { $null } else { '<null, or {attempted, reason, succeeded, thread, wall_seconds, usage, drift, original, events, schema_transport} after a format-repair turn>' })
            denial_retry                    = $(if (-not $engineSpec.DenialRetry -or $DenialRetry -ne 1) { $null } else { '<null, or {attempted, reason, succeeded, thread, wall_seconds, usage, events} after a denial-retry turn>' })
            timeout_continue                = $(if ($ContinueSec -le 0) { '<null, or {thread, wall_seconds 0, outcome "not attempted: -ContinueSec 0", events null, usage null} after a timeout kill>' } else { "<null, or {thread, wall_seconds, outcome, events, usage} of ONE continuation turn (up to $ContinueSec s) after a timeout kill of the main turn>" })
            stall                           = $(if ($StallSec -le 0) { $null } else { "<null, or {seconds, last_event} when the stream went $StallSec s without an event while the process lived (stopped like a timeout)>" })
            kill_confirmed                  = '<null, or true|false after a process tree kill (false: the kill was not confirmed - no continuation followed)>'
            base_commit                     = $revBefore.base_commit
            reviewed_revision               = $revBefore.reviewed_revision
            tree_sha256                     = $revBefore.tree_sha256
            tree_sha256_after               = '<computed after the run>'
            tree_changed_during_review      = '<true|false: a file''s content changed during the run>'
            revision_moved                  = '<null, or "<old base_commit> -> <new base_commit>" when HEAD moved during the run (informational - not a tree change)>'
            changed_files                   = $revBefore.changed_files
            brief_sha256                    = $briefSha
            brief_sha256_after              = $(if ($briefPath) { '<computed after the run>' } else { '' })
            brief_changed_during_review     = '<true|false>'
            fingerprint_note                = $revBefore.fingerprint_note
            artifacts                       = [object[]]$previewArtifacts
            artifacts_changed_during_review = '<true|false>'
            tree_check                      = $(if ($isCodex) { $null } else { "<{outcome clean|$(if ($engineSpec.WriteDisabled) { 'warned' } else { 'failed' }), files[]}: the engine's tree check (the working tree, the collab directory, the brief, the artifacts)>" })
            bridge_outcome                  = '<usable reply | failed: ...>'
            provider_failure                = '<null, or {class auth|quota|capability|transport|unknown, kind burst|"", code, message, when, retry_after, hint} of a failed run>'
            warnings                        = [object[]]$runWarnings.ToArray()
            verdict                         = $(if ($Raw) { '' } else { "<$($verdictRule -replace ', | or ', '|'), or '' when unavailable>" })
            verdict_reason                  = $(if ($Raw) { '' } else { '<one sentence>' })
            findings                        = $previewFindings
            finding_ids                     = [object[]]$previewIds
            prior_findings                  = [object[]]@($listedIds | ForEach-Object { [pscustomobject]@{ id = $_; status = '<fixed|still-open|not-checked|unknown-id>' } })
            unchecked_prior_blockers        = [object[]]@()
            usage                           = $(if ($isCodex) { [pscustomobject]@{ input_tokens = '<n>'; cached_input_tokens = '<n>'; output_tokens = '<n>'; reasoning_output_tokens = '<n>' } } elseif (-not $engineSpec.HasUsage) { $null } else { [pscustomobject]@{ input_tokens = '<n>'; cached_input_tokens = '<n (cache_read_tokens)>'; output_tokens = '<n>'; reasoning_output_tokens = '<n (thinking_tokens)>'; total_tokens = '<n>' } })
            compactions                     = $(if ($contextTokens -gt 0) { "<n (the compactions the engine's stream reported), else 'unknown'>" } else { '<null, or n when the engine''s stream reported a compaction>' })
            engine_run                      = $(if ($isCodex) { $null } elseif ($engineName -eq 'claude') { [pscustomobject]@{ turns = '<the turns started: 1, + a denial retry, + a format repair>'; max_model_steps = $(if ($MaxModelSteps -gt 0) { $MaxModelSteps } else { $null }); msp_schema_version = $null; auth = $engineAuth; init_tools = '<the tools the init events listed: Glob, Grep, Read, StructuredOutput>'; mcp_servers = '<0>'; permission_mode = '<dontAsk>'; api_key_source = $(if ($engineAuth -eq 'api-key') { '<ANTHROPIC_API_KEY>' } elseif ($engineAuth -eq 'endpoint') { '<none (recorded raw; ANTHROPIC_API_KEY fails the turn)>' } else { '<none>' }); model_resolved = $(if ($engineAuth -eq 'endpoint') { '<the model id the init event names - it must equal the pinned id>' } else { '<the model id the init event resolved>' }); other_models = '<[] or the other models a turn named>'; permission_denials = '<n>'; denied_tools = '<[] or the tools denied>'; rate_limit = '<null, or the most severe rate_limit_event as the CLI wrote it>'; quota_mark = '<null, or {class quota, kind, code, message, when, retry_after, hint}: a usable reply whose turn saw a rejecting rate_limit_event - the route is out as after a failed quota turn>'; cost_usd = '<the notional total_cost_usd>'; child_env_allowed = [object[]]@((Get-ClaudeChildEnvironment -Auth $engineAuth -Endpoint $engineEndpoint).Names); switched_off = [object[]]$script:ClaudeSwitchedOff } } else { [pscustomobject]@{ turns = '<the turns started: 1, + a denial retry, + a format repair>'; max_model_steps = $(if ($MaxModelSteps -gt 0) { $MaxModelSteps } else { $null }); msp_schema_version = $(if ($engineSpec.PromptTransport -eq 'file') { '<the MSP schema_version of the stream: 1>' } else { $null }) } })
            wall_seconds                    = 0
            finished_at                     = '<written at the commit>'
            commit_wait_ms                  = '<ms the commit waited for the write lock>'
        }
        Write-Host "DRY RUN - nothing was executed and no file was written." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "repo root   : $repoRoot"
        Write-Host "task dir    : $taskDir"
        Write-Host "sessions    : $sessionsPath"
        if (-not $Raw) { Write-Host "findings    : $findingsPath ($($openFindings.Count) open finding(s) listed in the prompt)" }
        Write-Host "lock        : $lockPath (held open for the run; not in a dry run)"
        foreach ($rl in $recoveredLines) { Write-Host "pending     : $rl" -ForegroundColor Yellow }
        if ($isCodex) {
            if ($codexExePath) { Write-Host "launcher    : $codexExePath" }
            else { Write-Host "launcher    : (codex not found on PATH)" -ForegroundColor Yellow }
            Write-Host "codex       : $codexVersion"
            Write-Host "config      : $($identity.ConfigPath)$(if (-not $codexConfigScan.Exists) { ' (not found)' })"
        } else {
            Write-Host "engine      : $engineName - $($engineSpec.Label) (from $engineFrom)"
            if ($engineLauncher) { Write-Host "launcher    : $engineLauncher" }
            else { Write-Host "launcher    : ($engineName CLI not found on PATH; -EngineExe or $($engineSpec.ExeEnv))" -ForegroundColor Yellow }
            Write-Host "harness     : $harness"
            Write-Host "config      : (not used by the $engineName engine)"
        }
        Write-Host "reviewer    : $($reviewerLine -replace '^Reviewer: ', '')"
        Write-Host "lineage     : $lineageShown"
        # (wave 27, R13) the coordinator, what its engine children do not get, its brief prefix
        Write-Host "coordinator : $(Format-CoordinatorText $coordinatorRecord)"
        if ($engineName -eq 'claude' -and $engineAuth -eq 'endpoint') {
            # (wave 29b, E4) the route's base URL, the token variable's NAME (never its value), the plan
            $dryCe = Get-ClaudeChildEnvironment -Auth $engineAuth -Endpoint $engineEndpoint
            Write-Host "child env   : an allow list (auth endpoint): $(@($dryCe.Names) -join ', ') - every other variable (the host markers, ANTHROPIC_* but ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN, CLAUDE_* but CLAUDE_CONFIG_DIR) is left out$(if ($dryCe.Problem) { "; a real run is refused: $($dryCe.Problem)" })"
            if ($engineEndpoint) { Write-Host "endpoint    : $($engineEndpoint.BaseUrl) (ANTHROPIC_BASE_URL); token from env $($engineEndpoint.EnvKey) (ANTHROPIC_AUTH_TOKEN - the value is never shown); API_TIMEOUT_MS $($engineEndpoint.TimeoutMs); plan $(if ([string]$engineEndpoint.Plan) { $engineEndpoint.Plan } else { '(none)' }); no claude auth status - the model the init event names is the proof" }
        }
        elseif ($engineName -eq 'claude') { Write-Host "child env   : an allow list (auth $engineAuth): $(@((Get-ClaudeChildEnvironment -Auth $engineAuth).Names) -join ', ') - every other variable (the host markers, ANTHROPIC_*, CLAUDE_* but CLAUDE_CONFIG_DIR) is left out" }
        else { Write-Host "child env   : $(if (@($childEnvScrubbed).Count -gt 0) { "without the host markers $(@($childEnvScrubbed) -join ', ') (every other variable is kept)" } else { 'no host marker set - the environment is passed as it is' })" }
        Write-Host "brief prefix: $BriefPrefix ($briefPrefixSource) - the coordinator's briefs are handoffs/<NN>-$BriefPrefix-<slug>.md, this reply $nn-$enginePrefix-$ReplyName.*"
        # (wave 28, R17)
        if ($telemetrySwitch.On) { Write-Host "telemetry   : on ($($telemetrySwitch.Source)) - after the commit ONE anonymised event of this consultation goes to the spool and a background sender delivers it (README ""Telemetry (on by default)""; CODEX_CONSULT_TELEMETRY=off or -Telemetry off switches it off)" }
        else { Write-Host "telemetry   : off ($($telemetrySwitch.Source)) - nothing is spooled or sent" }
        if ($preflightLabel -match 'a real run is refused') { Write-Host "preflight   : $preflightLabel" -ForegroundColor Yellow }
        else { Write-Host "preflight   : $preflightLabel" }
        if ($rosterLine) { Write-Host $rosterLine }
        foreach ($rw in $runWarnings) { Write-Host "WARNING: $rw" -ForegroundColor Yellow }
        if ($preflightWarning) { Write-Host "WARNING: $preflightWarning" -ForegroundColor Yellow }
        Write-Host "model       : $modelLabel"
        Write-Host "purpose     : $purposeLabel (effort $(if ($null -eq $effortSent) { 'none sent' } else { $effortSent }), max words $maxWordsResolved)"
        if ($topicList.Count -gt 0) { Write-Host "topics      : $($topicList -join ', ')" }
        if ($roleInfo) { Write-Host "role        : $($roleInfo.Name) ($($roleInfo.Source): $($roleInfo.Path)) - in the prompt after the ask" }
        if ($singleRequired -and @($singleRequired.Positions).Count -gt 0) { Write-Host "required    : $(@($singleRequired.Positions | ForEach-Object { "#$_" }) -join ', ') available (-Require)" }
        Write-Host "effort      : $(if ($null -eq $effortSent) { 'nothing' } else { $effortSent }) sent (requested $($effortPlan.Requested), mapping $($effortPlan.Mapping), by $($effortPlan.Basis))"
        Write-Host "timeout     : $TimeoutSec s ($(if ($timeoutSource -eq 'purpose') { "the default of purpose $purposeLabel; -TimeoutSec overrides" } else { Format-TimeoutSource -Source $timeoutSource -PurposeLabel $purposeLabel })); continuation after a timeout kill: $(if ($ContinueSec -gt 0) { "one turn of up to $ContinueSec s on the same thread (-ContinueSec; 0 = off)" } else { 'off (-ContinueSec 0)' })"
        if ($rangeStat) { Write-Host "range       : $Range - $rangeText ($($rangeStat.Insertions) insertions, $($rangeStat.Deletions) deletions)" }
        if ($peakWarning) { Write-Host "peak        : $peakLabel" -ForegroundColor Yellow; Write-Host $peakWarning -ForegroundColor Yellow }
        else { Write-Host "peak        : $peakLabel" }
        if ($Raw) { Write-Host "reply format: raw text ($(if ($Purpose -eq 'chore') { '-Purpose chore' } else { '-Raw' }): no schema, no findings bookkeeping)" }
        else {
            Write-Host "schema      : $schemaPath"
            if ($schemaTransport -eq 'output-schema') { Write-Host "transport   : output-schema ($schemaTransportBasis): passed as --output-schema" }
            elseif ($schemaTransport -eq 'native') { Write-Host "transport   : native ($schemaTransportBasis): passed as $($engineSpec.SchemaFlag), the reply is $($engineSpec.ReplySource) (validated locally too)" }
            elseif ($isCodex) { Write-Host "transport   : prompt-only ($schemaTransportBasis): --output-schema is NOT passed; the schema travels in the prompt, the reply is validated locally" }
            else { Write-Host "transport   : prompt-only ($schemaTransportBasis): $($engineSpec.SchemaFlag) is NOT passed; the schema travels in the prompt, the reply is validated locally" }
        }
        if ($repairEnabled) { Write-Host 'format retry : 1 attempt if the reply is not valid JSON' } else { Write-Host 'format retry : 0 (off)' }
        if (-not $isCodex) {
            if (-not $engineSpec.DenialRetry) { Write-Host "denial retry: n/a (the $engineName engine runs with its write, shell and web tools disabled - nothing is auto-denied)" }
            elseif ($DenialRetry -eq 1) { Write-Host 'denial retry: 1 attempt if a tool was auto-denied and the turn produced nothing' } else { Write-Host 'denial retry: 0 (off)' }
            if ($engineSpec.StepsFlag) { Write-Host "max steps   : $(if ($MaxModelSteps -gt 0) { "$MaxModelSteps ($($engineSpec.StepsFlag))" } else { "the $engineName CLI's default (no $($engineSpec.StepsFlag))" })" }
            Write-Host "sandbox     : $sandboxRecord"
            if ($argvHazard) { Write-Host "launch      : a real run is refused before launch - $argvHazard" -ForegroundColor Yellow }
            if ($promptBound) { Write-Host "launch      : a real run is refused before launch - $promptBound" -ForegroundColor Yellow }
        }
        Write-Host "mode        : $Mode"
        if ($Mode -eq 'new') { Write-Host "thread      : (a new thread will be created)" }
        elseif (-not $isCodex) { Write-Host "thread      : $parentThread ($($engineSpec.ThreadNoun) resumed with $($engineSpec.ThreadFlag))" }
        else { Write-Host "thread      : $parentThread (parent for $Mode)" }
        if ($parentNote) { Write-Host "parent      : $parentNote" }
        Write-Host "consult id  : $consultId (the prompt's last line)"
        Write-Host "handoff     : $nn (consult n = $consultN)"
        Write-Host "reviewed    : $($revBefore.reviewed_revision), base $($revBefore.base_commit), $($revBefore.changed_files) changed files"
        $treeShown = $revBefore.tree_sha256
        if (-not $treeShown) { $treeShown = '(none)' }
        Write-Host "tree sha256 : $treeShown ($($revBefore.fingerprint_note))"
        if ($briefSha) { Write-Host "brief sha256: $briefSha" }
        foreach ($art in $artifactHashes) { Write-Host "artifact    : $($art.path) sha256 $($art.sha256)" }
        Write-Host ""
        Write-Host "argv        :"
        $argv | ForEach-Object { Write-Host "    $_" }
        Write-Host ""
        Write-Host "command     : $commandStr"
        if ($promptByFile) {
            Write-Host "prompt file : $promptPath (the prompt below, UTF-8 without BOM, written at launch; stdin is empty)"
            Write-Host "prompt (--prompt-file, $($promptText.Length) chars):"
        } else {
            if (-not $isCodex) { Write-Host "stdin       : one NDJSON line {""event"":""user"",""message"":{""content"":<the prompt>}} ($($stdinText.Length) chars, UTF-8, LF)" }
            Write-Host "prompt (stdin, $($promptText.Length) chars):"
        }
        Write-Host "----"
        Write-Host $promptText
        Write-Host "----"
        Write-Host ""
        Write-Host "reply file  : $replyPath"
        if (-not $Raw) { Write-Host "reply json  : $replyJsonPath" }
        Write-Host "events file : $eventsPath"
        if ($isCodex) { Write-Host "last message: $lastMsgPath (temp)" }
        else { Write-Host "reply source: $($engineSpec.ReplySource), extracted to the reply json before validation" }
        Write-Host ""
        Write-Host "sessions.json entry preview:"
        Write-Host (ConvertTo-Json -InputObject $preview -Depth 10)
        exit 0
    }

    # ------------------------------------------------------------------------- run

    # The prompt file and the stdin (D1): codex and agy read the prompt file as stdin; muse
    # reads it through --prompt-file and gets an empty stdin.
    if ($promptByFile) {
        Write-Utf8NoBom -Path $promptPath -Text $promptText
        Write-Utf8NoBom -Path $stdinPath -Text $stdinText
    } else {
        Write-Utf8NoBom -Path $promptPath -Text $stdinText
    }

    # Peak status AT LAUNCH (the one the ledger records). Under -OffPeakOnly a window
    # entered since the early check stops the run here: no child exists yet, this run's
    # reservation is withdrawn (nothing was written under its numbers), no ledger entry.
    $peak = Get-PeakStatusNow -Provider $peakProvider
    if ($peak.Error) {
        $null = Remove-PendingFile -Path $pendingPath
        Stop-WithError $peak.Error
    }
    $peakWarning = ''
    if ($peak.Peak -eq $true) { $peakWarning = "WARNING: $peakProvider peak window ($($peak.Schedule)) - this consultation runs at peak tariff." }
    if ($OffPeakOnly -and $peak.Peak -ne $false) {
        $rmError = Remove-PendingFile -Path $pendingPath
        $tail = ''
        if ($rmError) { $tail = " (the recovery record '$pendingPath' could not be removed: $rmError; the next run will find no codex and consume it)" }
        Stop-WithError "-OffPeakOnly: $peakProvider entered its peak window before launch ($($peak.Schedule); now $($peak.Local)); nothing was started.$tail"
    }
    if ($peakWarning) { Write-Host $peakWarning -ForegroundColor Yellow }
    # (wave 23) the engine's launch invariant again (D4) and the %-expansion hazard of a .cmd
    # launcher (F02-14) are checked right before the start of the main turn itself
    # (Start-EngineProcess, wave 24b F08-1) - a refusal withdraws the reservation: nothing was
    # started, no ledger entry.

    # agy's --sandbox does not block writes (A17): what the review must not touch is
    # compared after the run - the tree fingerprint (above) and the whole collab directory
    # (every task's stores and handoffs; wave 18). The run's own handoff files
    # (<task>/handoffs/NN-<prefix>-<slug>.*) are its output, not a change.
    $collabBefore = $null
    $ownPrefixes = [string[]]@("$Task/handoffs/$nn-$enginePrefix-$ReplyName.")
    # A member of a panel whose members run at the same time (D7): the task's two stores and
    # the siblings' handoffs are theirs to write meanwhile (each with its atomic-write temp);
    # every other collab path stays monitored.
    if ($panelMember) {
        # (Get-PanelIgnorePrefixes hands back the array itself: assigned directly, never @()-wrapped)
        $siblingPrefixes = Get-PanelIgnorePrefixes -Task $Task -SiblingNns ([string[]]@(@(Get-PropertyValue $panelMember 'sibling_nns' @()) | Where-Object { $_ } | ForEach-Object { [string]$_ }))
        $ownPrefixes = [string[]]($ownPrefixes + $siblingPrefixes)
    }
    $collabShown = ''
    if (-not $isCodex) {
        $collabBefore = Get-CollabSnapshot -Dir $collabRoot
        $collabRelShown = Get-RepoRelativePath -Root $repoRoot -Path $collabRoot
        if ($collabRelShown) { $collabShown = "$collabRelShown/" }
    }

    # (3) launching - from the next statement on, a crash may leave a codex process
    # whose pid is not recorded; the next run then scans for one (Test-PendingActive).
    $engineCmd = [string]$engineSpec.Command
    # A panel member re-checks its panel run right before it starts anything (D1): when that
    # run is gone, the member stops here - nothing started, its record withdrawn.
    if ($panelMember -and -not (Test-PidAlive -ProcessId $memberParentPid -StartTime $memberParentStart)) {
        $rmError = Remove-PendingFile -Path $pendingPath
        Stop-WithError "the review panel run that launched this member (pid $memberParentPid) is gone; this member stopped before starting $engineCmd - nothing was started$(if ($rmError) { " (its recovery record '$pendingPath' could not be removed: $rmError)" })."
    }
    $pendingRecord.state = 'launching'
    $pendingRecord.note = "$engineCmd is being started; its pid is not recorded yet"
    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
        Stop-WithError "could not write the recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); $engineCmd was not started."
    }
    # TEST HOOK: CODEX_CONSULT_TEST_LAUNCH_PAUSE_MS=<ms> | <model>=<ms>[|...] - a pause between
    # the `launching` record and the guarded start of the MAIN turn (wave 24b, F08-1: a sign-in
    # that changes after the preflight is seen by the launch guard).
    # (wave 26b, D10) this run's kick file (-Kick -Member <NN>); one left from an earlier run of
    # the same number is stale
    $script:KickPath = Get-KickPath -TaskDir $taskDir -Nn $nn
    $null = Remove-PendingFile -Path $script:KickPath
    # (wave 27c, D1) an acknowledgement of that number older than 60 s is swept; a younger one is
    # left to the caller that has not read it yet (a caller only ever reads the ack of its own id)
    $null = Clear-StaleKickAck -KickPath $script:KickPath
    $launchPause = Get-TestHookMs -Value ((Get-TestHookValue 'CODEX_CONSULT_TEST_LAUNCH_PAUSE_MS')) -Model ([string]$identity.Model)
    if ($launchPause -gt 0) { Start-Sleep -Milliseconds $launchPause }

    $startedAt = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = -1
    $bridgeOutcome = ''
    # (wave 24) the main turn was killed on the timeout (and how many processes survived it)
    $mainTimedOut = $false
    $mainSurvivors = 0
    # (wave 27c, D16) every tree kill of this run, confirmed or not (ledger kill_confirmed), and the
    # warnings of the unconfirmed ones; the main turn's kill not confirmed: no continuation
    $script:KillChecks = New-Object System.Collections.Generic.List[object]
    $script:KillWarnings = New-Object System.Collections.Generic.List[string]
    $script:TurnWarnings = New-Object System.Collections.Generic.List[string]
    $mainKillUnconfirmed = $false
    # (wave 26b, D12) the main turn was stopped by the stall cut (a kind of timeout: $mainTimedOut
    # too); ledger stall. (D10) $script:RunKicked: the operator stopped a turn (-Kick).
    $mainStalled = $false
    $stallRecord = $null
    $mainWait = $null
    $script:RunKicked = $false
    # (wave 26c, D1) which turn the kick stopped (main | retry | continue | repair), and the turns
    # that had already finished when their kick was found (kick_late: the outcome stays)
    $script:KickedTurn = ''
    $script:KickLateTurns = New-Object System.Collections.Generic.List[string]
    # (wave 24b, F08-1) the main turn starts through the ONE guarded start as every other turn:
    # the launch invariant read afresh (muse: auth.json and the environment) right before it
    $launch = Start-EngineProcess -Launcher $engineLauncher -Argv $argv -StdoutPath $eventsPath -StderrPath $stderrPath -StdinPath $stdinPath
    if ($launch.Refusal) {
        $rmError = Remove-PendingFile -Path $pendingPath
        Stop-WithError "the $engineName run is refused before launch: $($launch.Refusal); nothing was started.$(if ($rmError) { " (The recovery record '$pendingPath' could not be removed: $rmError; the next run consumes it.)" })"
    }
    $proc = $launch.Proc
    if ($launch.Error) { $bridgeOutcome = "failed: could not start $engineCmd - $($launch.Error)" }
    if ($proc) {
        # PS 5.1: touching .Handle before the process exits caches it, otherwise
        # .ExitCode comes back empty on a -PassThru process.
        if ($script:LegacyPS) { try { $null = $proc.Handle } catch { } }
        # (4) running - register the child before waiting on it.
        $registerError = ''
        try {
            $pendingRecord.state = 'running'
            $pendingRecord.child_pid = $proc.Id
            $pendingRecord.child_start_time = [string](Get-ProcessStartIso -ProcessId $proc.Id)
            $pendingRecord.note = ''
            # A18: the raw event stream of this run (for agy it holds the reply itself).
            $pendingRecord.events = $(if (Get-RepoRelativePath -Root $repoRoot -Path $eventsPath) { Get-RepoRelativePath -Root $repoRoot -Path $eventsPath } else { $eventsPath })
            # (wave 28b, D19) TEST HOOK (test mode only): CODEX_CONSULT_TEST_REGISTER_FAIL=1 - the
            # registration write fails (the harnesses inject it here, never by patching a function)
            if ((Get-TestHookValue 'CODEX_CONSULT_TEST_REGISTER_FAIL').Trim() -eq '1') { throw 'injected: registration write failed (test hook CODEX_CONSULT_TEST_REGISTER_FAIL)' }
            Write-PendingFile -Path $pendingPath -Record $pendingRecord
        } catch {
            $registerError = ConvertTo-OneLine $_.Exception.Message
            # the record on disk still says launching: so does the one in memory (a kept
            # record is written from it after the commit)
            $pendingRecord.state = 'launching'; $pendingRecord.child_pid = $null; $pendingRecord.child_start_time = ''
        }
        if ($registerError) {
            # An unregistered codex must not outlive this run: stop it now. The record
            # on disk stays 'launching', so the next run checks for a codex process.
            $survivors = Stop-ProcessTree -Process $proc   # [int[]]; never wrap in @(): that nests the array
            $bridgeOutcome = "failed: could not register the $engineCmd process ($registerError); $engineCmd was stopped"
            if ($survivors.Count -gt 0) { $bridgeOutcome += "; $($survivors.Count) processes survived: pid $($survivors -join ', ')" }
            $keepPending = $true
        } else {
            # (wave 25) a detached run: its member runs
            Set-DetachedMember -Position $detachMemberPosition -Values @{ state = 'running' }
            # (wave 26b, D13) running on the endpoint: counted by every panel of this machine
            # (wave 29b, E16) with the roster entry's plan: a panel elsewhere counts it against the plan
            $null = Register-MachineRunning -Fingerprint ([string]$identity.Fingerprint) -Label ([string]$identity.Provider) -Repo $repoRoot -Task $Task -Nn $nn -Panel $(if ($panelMember) { [string]$panelMember.id } else { '' }) -Plan $(if ($rosterEntry) { [string](Get-PropertyValue $rosterEntry 'Plan' '') } else { '' })
            # (wave 26b, D10, D12) the wait watches the timeout, the stall cut (-StallSec: no event
            # line for that long) and the operator's kick file
            $mainWait = Wait-EngineProcess -Process $proc -TimeoutSec $TimeoutSec -StallSec $StallSec -EventsPath $eventsPath -KickPath $script:KickPath -Engine $engineName
            $finished = $mainWait.Exited
            if ($mainWait.KickLate) { $script:KickLateTurns.Add('the main turn') }
            # (wave 27c, D5) event lines longer than 1 MiB the bounded reader skipped: one warning
            if ($mainWait.Oversized -gt 0) { $script:TurnWarnings.Add("oversized_lines: $($mainWait.Oversized) event line(s) longer than 1 MiB were not parsed by the stall timer's reader (its activity counts bytes; the reply is read from the whole stream)") }
            if (-not $finished) {
                # The launcher is usually a shim (codex.cmd -> node -> codex.exe): kill
                # the whole tree, or the real codex keeps running after we give up.
                # (wave 27c, D16) the kill CONFIRMED: an unconfirmed one is never "(process tree
                # killed)" and no continuation follows it (the orphan may still hold the thread)
                $mainKill = Stop-ProcessTreeChecked -Process $proc
                # (wave 28e, E1) TEST HOOK (test mode only): CODEX_CONSULT_TEST_UNVERIFIED=<pid>[,<pid>] -
                # these pids, when alive, are reported as descendants of this kill whose start time could
                # not be read (no test can make that happen to a fake's tree on cue). Only ever adds
                # unverified pids: a stricter outcome.
                $hookUnverified = @(foreach ($hu in @(((Get-TestHookValue 'CODEX_CONSULT_TEST_UNVERIFIED')).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' })) { if ((Get-Process -Id ([int]$hu) -ErrorAction SilentlyContinue) -and (@($mainKill.Unverified) -notcontains [int]$hu)) { [int]$hu } })
                if ($hookUnverified.Count -gt 0) {
                    $mainKill.Unverified = [int[]]@(@($mainKill.Unverified) + $hookUnverified)
                    $mainKill.Confirmed = $false
                    if (-not $mainKill.Why -or $mainKill.Why -match '^start time of pid ') { $mainKill.Why = "start time of pid $(@($mainKill.Unverified) -join ', ') unreadable" }
                }
                Add-KillCheck -Check $mainKill -Turn 'main turn'
                $survivors = [int[]]$mainKill.Survivors
                # TEST HOOK: CODEX_CONSULT_TEST_SURVIVORS=<pid>[,<pid>] - these pids, when
                # alive, are reported as survivors of this kill (no test can make a real
                # process outlive a kill). Only ever adds survivors: a stricter outcome.
                foreach ($hookPid in @(((Get-TestHookValue 'CODEX_CONSULT_TEST_SURVIVORS')).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' })) {
                    if ((Get-Process -Id ([int]$hookPid) -ErrorAction SilentlyContinue) -and ($survivors -notcontains [int]$hookPid)) { $survivors = [int[]]@($survivors + [int]$hookPid) }
                }
                # (wave 27c, D16) survivors - the hook's too - mean the kill is not confirmed
                if ($survivors.Count -gt 0) { $mainKill.Confirmed = $false; $mainKill.Survivors = [int[]]$survivors }
                $stopText = "timeout after $TimeoutSec s"
                if ($mainWait.Reason -eq 'stall') {
                    # (wave 26b, D12) stopped like a timeout: the continuation turn and the salvage follow
                    $mainStalled = $true
                    $stopText = "stalled after $StallSec s without an event"
                    # (wave 27c, D6; wave 28b, D12) a tool call open while the stream did not grow for 2 x
                    # the threshold: said in the cut, naming the open call
                    if ($mainWait.ToolOpen -gt 0 -or $mainWait.OpenTools) { $stopText += " - no output for $($mainWait.Silent) s (a tool call open for $($mainWait.ToolOpen) s$(if ($mainWait.OpenTools) { ": $($mainWait.OpenTools)" }))" }
                    $stallRecord = [pscustomobject]@{ seconds = $StallSec; last_event = $(if ($null -ne $mainWait.LastEvent) { Format-OffsetIso $mainWait.LastEvent } else { $null }) }
                }
                $bridgeOutcome = "failed: $stopText $(Format-KillText $mainKill)"
                $mainTimedOut = $true
                $mainKillUnconfirmed = [bool](-not $mainKill.Confirmed -and $survivors.Count -eq 0)
                if ($mainWait.Reason -eq 'kick') {
                    # (wave 26b, D10) the operator stopped it: no continuation; the salvage follows
                    $script:RunKicked = $true
                    $script:KickedTurn = 'main'
                    $mainTimedOut = $false
                    $stopText = 'stopped by the operator (-Kick)'
                    $bridgeOutcome = "failed: $stopText$(if ($mainKillUnconfirmed) { " $(Format-KillText $mainKill)" })"
                    $null = Remove-PendingFile -Path $script:KickPath
                }
                $mainSurvivors = $survivors.Count
                if ($survivors.Count -gt 0) {
                    $bridgeOutcome = "failed: $stopText (process tree killed; $($survivors.Count) processes survived: pid $($survivors -join ', ')$(Get-KillUnverifiedText $mainKill); the next run for this task is refused until they exit)"
                    # (5) survivors - kept after this run.
                    $keepPending = $true
                    try {
                        $pendingRecord.state = 'survivors'
                        # { pid, start_time, name } per survivor, so a reused pid is not
                        # mistaken for the survivor later (New-SurvivorEntries streams
                        # objects; @() is correct here - it does not return ", $array").
                        $pendingRecord.survivors = [object[]]@(New-SurvivorEntries -Pids $survivors)
                        # (wave 28e, E1 / F54-1) the descendants the kill could not verify, beside them
                        $pendingRecord | Add-Member -NotePropertyName 'unverified' -NotePropertyValue ([object[]]@(New-UnverifiedEntries -Check $mainKill)) -Force
                        Write-PendingFile -Path $pendingPath -Record $pendingRecord
                    } catch {
                        $bridgeOutcome += "; WARNING: the survivors could not be recorded ($(ConvertTo-OneLine $_.Exception.Message)) - $pendingPath still names only child pid $($proc.Id)"
                    }
                }
            } else {
                $exitCode = $proc.ExitCode
            }
        }
    }
    $stopwatch.Stop()
    $wallSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

    $revAfter = Get-RevisionInfo -Root $repoRoot -CollabRoot $collabRoot
    # (wave 24c) the tree changed = a file's CONTENT changed (Compare-TreeContent); HEAD moving
    # (a commit meanwhile) is only noted - ledger revision_moved
    $treeCompare = Compare-TreeContent -Before $revBefore -After $revAfter
    $treeChanged = $treeCompare.Changed
    $revisionMoved = $treeCompare.RevisionMoved
    $briefShaAfter = ''
    if ($briefPath) { $briefShaAfter = Get-FileSha256OrMissing -Path $briefPath }
    $briefChanged = ($briefSha -ne $briefShaAfter)
    # Rehash the exact resolved path each hash was taken from (no lookup by name).
    $artifactsFinal = @($artifactHashes | ForEach-Object {
            [pscustomobject]@{ path = $_.path; sha256 = $_.sha256; sha256_after = (Get-FileSha256OrMissing -Path $_.full) }
        })
    $changedArtifacts = @($artifactsFinal | Where-Object { $_.sha256 -ne $_.sha256_after } | ForEach-Object { $_.path })
    $artifactsChanged = ($changedArtifacts.Count -gt 0)

    $stderrText = Read-SharedText -Path $stderrPath
    $rawReply = ''
    if ($isCodex) { $rawReply = (Read-SharedText -Path $lastMsgPath).Trim() }
    # Ledger `warnings` (every engine; [] when none): agy's denial notices and `warning:`
    # lines that came with a usable reply.
    $engineWarnings = New-Object System.Collections.Generic.List[string]
    foreach ($rw in $runWarnings) { $engineWarnings.Add($rw) }
    # (wave 27c, D16) the main turn's unconfirmed kill (the later turns' are added before the entry)
    foreach ($kw in @(@($script:TurnWarnings) + @($script:KillWarnings))) { if ($kw -and -not $engineWarnings.Contains([string]$kw)) { $engineWarnings.Add([string]$kw) } }
    $agyTurn = $null
    $agyEvents = $null
    $agyFailureClass = ''
    $agyFailureTexts = @()
    # (wave 23) engine turns started (ledger engine_run.turns; for muse each one is a
    # subscription prompt) and the MSP schema version of the stream (muse)
    $engineTurns = $(if ($proc) { 1 } else { 0 })
    $mspVersion = $null
    $denialRetryRecord = $null
    # (wave 24) the secondary turns, for the salvage of a turn killed on its timeout
    $retryTurn = $null
    $retryEventsPath = ''
    $repairTurn = $null
    $repairProblem = ''
    $repairEngineEvents = ''
    $treeProblem = ''
    # (wave 26b, D9) the ledger's tree_check {outcome, files[]} (null for codex: no check) and
    # the warnings a write-disabled engine's check added (replaced when the check runs again)
    $treeCheckRecord = $null
    $treeCheckWarnings = [string[]]@()
    $extraEvents = New-Object System.Collections.Generic.List[string]
    $replyJsonRel = ''

    if ($isCodex) {
    # thread id - never let a parse/IO problem here swallow the sessions.json record.
    # A rollout file is this run's thread only when it contains the consultation id;
    # otherwise the newest one is kept as thread_candidate (diagnostic, never a parent).
    $threadId = ''
    $threadSource = 'unknown'
    $threadCandidate = ''
    try {
        $threadId = Get-ThreadIdFromEvents -Path $eventsPath
        if ($threadId) {
            $threadSource = 'events'
        } else {
            $fromRollout = Find-ThreadInRollouts -StartedAt $startedAt -ConsultId $consultId
            $threadId = $fromRollout.Thread
            $threadCandidate = $fromRollout.Candidate
            if ($threadId) { $threadSource = 'rollout (verified by consultation id)' }
        }
    } catch {
        $threadId = ''
        $threadSource = 'unknown'
        $threadCandidate = ''
    }

    $eventError = ''
    try { $eventError = Get-ErrorFromEvents -Path $eventsPath } catch { $eventError = '' }
    $usage = $null
    try { $usage = Get-UsageFromEvents -Path $eventsPath } catch { $usage = $null }

    if (-not $bridgeOutcome) {
        if ($exitCode -ne 0) {
            $detail = $eventError
            if (-not $detail -and $stderrText) {
                $detail = ($stderrText.Trim() -split "`r?`n" | Select-Object -Last 1)
            }
            $tail = ''
            if ($detail) { $tail = ' - ' + $detail }
            $bridgeOutcome = "failed: codex exit $exitCode$tail"
        } elseif (-not $rawReply) {
            $detail = ''
            if ($eventError) { $detail = ' - ' + $eventError }
            $bridgeOutcome = "failed: empty reply$detail"
        } else {
            $bridgeOutcome = 'usable reply'
        }
    }

    # ------------------------------------------------------------------------- 1. reply.json

    # The first write after the run, before anything parses the reply: Codex's last
    # message copied BYTE FOR BYTE (never re-serialized, never trimmed). If it cannot
    # be preserved, the run is a bridge failure and the temp original is kept.
    if (-not $Raw -and (Test-Path -LiteralPath $lastMsgPath -PathType Leaf)) {
        $copyError = ''
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try {
                [IO.File]::Copy($lastMsgPath, $replyJsonPath, $true)
                $copyError = ''
                break
            } catch {
                $copyError = ConvertTo-OneLine $_.Exception.Message
                Start-Sleep -Milliseconds 250
            }
        }
        if ($copyError) {
            $keepLastMsg = $true
            $note = "could not preserve the raw reply ($copyError); original kept at $lastMsgPath"
            if ($bridgeOutcome -eq 'usable reply') { $bridgeOutcome = "failed: $note" }
            else { $bridgeOutcome += "; $note" }
        } else {
            $replyJsonRel = $replyJsonPlanned
        }
    }

    } else {
        # ---------------------------------------------------------------- engine: the turn
        # The event stream is already saved (handoffs/NN-<prefix>-<slug>.events.jsonl, stdout by
        # redirection); the engine's adapter parses it (agy: the LAST and only `result` event
        # carries the reply, A6, A19; muse: the ONE run_terminal record, D6). A truncated last
        # line is a partial line only when the process was killed or exited non-zero (F10-2);
        # after exit 0 trailing garbage makes the stream malformed.
        $allowPartial = [bool]($bridgeOutcome -or $exitCode -ne 0)
        try { $agyEvents = & $engineSpec.Adapter.Events -Path $eventsPath -AllowPartialLast:$allowPartial } catch { $agyEvents = & $engineSpec.Adapter.Events -Path '' }
        $agyTurn = & $engineSpec.Adapter.Outcome -Events $agyEvents -ExitCode $exitCode -StderrText $stderrText -Pre $bridgeOutcome -ExpectThread $(if ($Mode -eq 'resume') { $parentThread } else { '' }) -ExpectModel $engineModel -Turn $mainTurn
        if ($agyEvents.PSObject.Properties['SchemaVersion']) { $mspVersion = $agyEvents.SchemaVersion }
        $bridgeOutcome = $agyTurn.Outcome
        $rawReplyFull = [string]$agyTurn.Reply
        $rawReply = $rawReplyFull.Trim()
        $threadId = [string]$agyTurn.Thread
        $threadSource = $(if ($threadId) { 'events' } else { 'unknown' })
        $threadCandidate = [string]$agyTurn.ThreadCandidate
        # (wave 29, D4) every later turn of the thread (denial retry, continuation, repair) sends the
        # id the main turn's init event resolved - never the floating alias again
        $engineModelResolved = [string](Get-PropertyValue $agyTurn 'ModelResolved' '')
        if ($engineModelResolved) { $engineModel = $engineModelResolved }
        $eventError = [string]$agyEvents.Error
        $usage = $agyEvents.Usage
        $agyFailureClass = [string]$agyTurn.Class
        $agyFailureTexts = @($agyTurn.Texts)
        foreach ($w in @($agyTurn.Warnings)) { $engineWarnings.Add($w) }

        # 1. reply.json (A18): the reply extracted from the event stream, atomically, BEFORE
        # any validation - structured_output serialized compactly, else the response text.
        if (-not $Raw -and $rawReplyFull.Trim()) {
            try {
                Write-TextAtomic -Path $replyJsonPath -Text $rawReplyFull
                $replyJsonRel = $replyJsonPlanned
            } catch {
                $note = "could not preserve the reply ($(ConvertTo-OneLine $_.Exception.Message)); it is still in $eventsRel"
                if ($bridgeOutcome -eq 'usable reply') { $bridgeOutcome = "failed: $note"; $agyFailureClass = 'unknown'; $agyFailureTexts = @($note) }
                else { $bridgeOutcome += "; $note" }
            }
        }

        # Read-only check (A17): the tree, the collab directory, the brief, the artifacts. A
        # detected change forces class permission (wave 23, D12) - also when the run had already
        # failed for another reason: that reason stays in the provider failure's message.
        $treeCheck = Get-EngineTreeCheck -RevBefore $revBefore -RevAfter $revAfter -BriefChanged $briefChanged -ChangedArtifacts $changedArtifacts -CollabBefore $collabBefore -CollabAfter (Get-CollabSnapshot -Dir $collabRoot) -OwnPrefixes $ownPrefixes -Engine $engineName -CollabShown $collabShown
        $treeProblem = $treeCheck.Problem
        $treeCheckRecord = [pscustomobject]@{ outcome = $treeCheck.Outcome; files = [object[]]@($treeCheck.Files) }
        # (wave 26b, D9) a write-disabled engine (muse): the change is a warning, the reply stays
        $treeCheckWarnings = [string[]]@($treeCheck.Warnings)
        foreach ($w in $treeCheckWarnings) { $engineWarnings.Add($w) }
        if ($treeProblem) {
            $agyFailureClass = 'permission'
            if ($bridgeOutcome -eq 'usable reply') {
                $bridgeOutcome = "failed: $treeProblem"
                $agyFailureTexts = @($treeProblem)
            } else {
                $bridgeOutcome += "; also: $treeProblem"
            }
        }

        # ---------------------------------------------------------------- denial retry (A3)
        # The turn produced nothing because a tool was auto-denied (F11), on a verified
        # conversation: ONE more turn there, told not to call it again (the output contract,
        # the field meanings and the consultation id - never the brief). Only an engine with a
        # denial retry (agy; muse has none - its tools are off, D2); parsed through the adapter.
        if ($engineSpec.DenialRetry -and $DenialRetry -eq 1 -and $agyTurn.DeniedEmpty -and $threadId -and -not $treeProblem) {
            $deniedTool = [string]$agyEvents.ToolName
            if (-not $deniedTool) { $deniedTool = [string]$agyEvents.DeniedAction }
            $toolText = if ($deniedTool) { "the tool $deniedTool" } else { 'a tool' }
            $permText = if ($agyTurn.Permission) { "(headless print mode has no ""$($agyTurn.Permission)"" permission)" } else { '(headless print mode cannot grant its permission)' }
            $retryParts = New-Object System.Collections.Generic.List[string]
            if (-not $Raw) {
                $retryParts.Add($promptParts[0])
                $retryParts.Add("Your previous turn produced no output: $toolText was auto-denied $permText. Do NOT call it again; answer from what you have read, as the JSON object.")
                $retryParts.Add(($schemaLines -join $nl))
                # (wave 23b) a prompt-only run: no schema flag on this turn either - the schema
                # travels in the retry prompt, as in the main turn's
                if ($schemaTransport -eq 'prompt-only') {
                    $retrySchemaText = ([IO.File]::ReadAllText($schemaPath, $script:Utf8NoBom).Trim() -replace "`r`n", "`n") -replace "`n", $nl
                    $retryParts.Add("JSON Schema of the reply:$nl$retrySchemaText")
                }
            } else {
                $retryParts.Add("Your previous turn produced no output: $toolText was auto-denied $permText. Do NOT call it again; answer from what you have read.")
            }
            $retryParts.Add("Consultation id: $consultId")
            $retryPrompt = [string]::Join("$nl$nl", $retryParts.ToArray())
            # the main turn's schema transport (wave 23b): the engine's schema flag on a native run only
            $retrySchemaArg = if (-not $Raw -and $schemaTransport -eq 'native') { $schemaPath } else { '' }
            $retryOpts = New-EngineTurnOptions -Model $engineModel -Mode 'denial-retry' -Thread $threadId -PromptFile $denialPromptPath -Schema $retrySchemaArg -Effort $effortSent -NativeEffort $NativeEffort -MaxSteps $MaxModelSteps -AddDirs @($mainTurn.AddDirs) -Auth $engineAuth
            $retryArgv = & $engineSpec.Adapter.Argv -Turn $retryOpts
            $retryEventsName = "$nn-$enginePrefix-$ReplyName.denial-retry.events.jsonl"
            $retryEventsPath = Join-Path $handoffsDir $retryEventsName
            $extraEvents.Add("handoffs/$retryEventsName")
            $retryTimeout = [Math]::Min($TimeoutSec, 300)
            $retryTurn = Invoke-EngineTurn -Argv $retryArgv -StdinText (& $engineSpec.Adapter.Stdin -Prompt $retryPrompt) -EventsPath $retryEventsPath -StdinPath $(if ($promptByFile) { $stdinPath } else { $denialPromptPath }) -StderrPath $denialStderrPath -Timeout $retryTimeout -Note 'denial retry turn' -PromptPath $(if ($promptByFile) { $denialPromptPath } else { '' }) -PromptText $retryPrompt
            if ($retryTurn.KeepPending) { $keepPending = $true }
            if ($retryTurn.Started) { $engineTurns++ }
            $retryEvents = & $engineSpec.Adapter.Events -Path $retryEventsPath -AllowPartialLast:([bool]($retryTurn.Problem -or $retryTurn.Exit -ne 0))
            $retryOut = & $engineSpec.Adapter.Outcome -Events $retryEvents -ExitCode $retryTurn.Exit -StderrText $retryTurn.Stderr -Pre $(if ($retryTurn.Problem) { "failed: $($retryTurn.Problem)" } else { '' }) -ExpectThread $threadId -ExpectModel $engineModel -Turn $retryOpts
            $retryReason = [string]$agyTurn.DenialLine
            if ($retryReason.Length -gt 200) { $retryReason = $retryReason.Substring(0, 200) }
            $denialRetryRecord = [pscustomobject]@{
                attempted    = $true
                reason       = $retryReason
                succeeded    = [bool]$retryOut.Ok
                thread       = [string]$retryEvents.Thread
                wall_seconds = $retryTurn.Wall
                usage        = $retryEvents.Usage
                # (F09-2) that turn's event stream, handoffs-relative; null when no turn ran
                events       = $(if (Test-Path -LiteralPath $retryEventsPath -PathType Leaf) { "handoffs/$retryEventsName" } else { $null })
            }
            if ($retryOut.Ok) {
                $bridgeOutcome = 'usable reply'
                $agyFailureClass = ''
                $agyFailureTexts = @()
                $rawReplyFull = [string]$retryOut.Reply
                $rawReply = $rawReplyFull.Trim()
                $engineWarnings.Add("denial notice (the first turn produced nothing; the denial-retry turn answered): $(ConvertTo-OneLine $agyTurn.DenialLine)")
                foreach ($w in @($retryOut.Warnings)) { $engineWarnings.Add($w) }
                if (-not $Raw -and $rawReplyFull.Trim()) {
                    try { Write-TextAtomic -Path $replyJsonPath -Text $rawReplyFull; $replyJsonRel = $replyJsonPlanned } catch { }
                }
            } else {
                $bridgeOutcome += " (denial retry failed: $(ConvertTo-OneLine ($retryOut.Outcome -replace '^failed:\s*', '')))"
            }
        }
    }

    # ------------------------------------------------------------------------- timeout continuation

    # (wave 24, T1 - the maintainer's request: the provider and the CLI still hold the
    # conversation; Codex keeps the whole rollout of a thread the bridge killed) The MAIN turn
    # was killed on its timeout: ONE more turn on that thread - the main turn's options, codex
    # `exec ... resume <thread>`, agy --conversation, muse --session-id - asks the reviewer to
    # finish now instead of starting over, within -ContinueSec s, under the same lock and
    # recovery record (Invoke-EngineTurn). Not when the thread is unknown, processes survived
    # the kill, files changed during the run (wave 24b, F08-2: ONE tree check for every engine -
    # codex's fingerprints too), the killed turn's own evidence names a quota, billing or auth
    # failure (F08-3: every candidate through the one classifier, Get-KilledTurnFailure), or
    # -ContinueSec is 0 (ledger timeout_continue.outcome "not attempted: <why>"); the launch
    # guard (muse: billing) is read afresh right before it. A prompt-only transport gets the reply
    # format and the schema again (F07-1). The continuation counts only when its reply passes the
    # checks of a first reply (F08-5, Test-ContinuationReply) - then it is ingested exactly like
    # one ("usable reply (after a timeout continuation)"); otherwise the salvage below covers both
    # turns' streams, and a continuation that FAILED supplies the provider failure (F08-4). At
    # most once.
    $timeoutContinueRecord = $null
    $continued = $false
    $continueTurn = $null
    $continueThread = ''
    $continueProblem = ''
    # (wave 24b) the continuation answered, but not with a usable reply (F08-5); the evidence of a
    # continuation that failed - { Texts; Class } for provider_failure (F08-4)
    $continueRejected = $false
    # (wave 24c, F08-4) the text of a continuation reply the checks rejected, and why - kept in the
    # partial file
    $continueRejectedText = ''
    $continueRejectedWhy = ''
    $continueFailure = $null
    $continueEventsRel = $null
    $continueEventsName = "$nn-$enginePrefix-$ReplyName.continue.events.jsonl"
    $continueEventsPath = Join-Path $handoffsDir $continueEventsName
    if ($mainTimedOut) {
        $continueThread = $(if ($threadId) { $threadId } elseif (-not $isCodex -and $agyTurn) { [string]$agyTurn.ThreadCandidate } else { '' })
        $continueSkip = ''
        if ($ContinueSec -le 0) { $continueSkip = '-ContinueSec 0' }
        # (wave 29b, E12) the killed turn's init or model proof failed (claude: a prohibited tool, an
        # MCP server, another permission mode or model, apiKeySource, a missing init field): a
        # continuation would resume a session that ran outside the proven capability
        elseif (-not $isCodex -and $agyTurn -and [string](Get-PropertyValue $agyTurn 'ProofProblem' '')) { $continueSkip = "the killed turn failed its proof (class $([string]$agyTurn.Class): $(ConvertTo-OneLine ([string]$agyTurn.ProofProblem)))" }
        elseif (-not $continueThread) { $continueSkip = 'the thread of the killed turn is not known' }
        elseif ($mainSurvivors -gt 0) { $continueSkip = "$mainSurvivors process(es) survived the kill" }
        elseif ($mainKillUnconfirmed) { $continueSkip = "the kill of the main turn was not confirmed ($($mainKill.Why)) - pid $($mainKill.RootPid) may still hold the thread" }
        else {
            # (wave 24b, F08-2) ONE tree check for every engine: the working tree, the brief or an
            # artifact changed while the killed turn ran - codex: the fingerprints taken around the
            # run (a workspace-write run may have written); an engine: its tree check, which covers
            # the collab directory too. A continuation would answer about another state.
            $moved = New-Object System.Collections.Generic.List[string]
            if ($treeChanged) { $moved.Add('the working tree') }
            if ($treeProblem -and $treeProblem -match 'the collab directory changed') { $moved.Add('the collab directory') }
            if ($briefChanged) { $moved.Add('the brief') }
            if ($artifactsChanged) { $moved.Add('artifact(s)') }
            if ($treeProblem -and $moved.Count -eq 0) { $moved.Add('the tree check') }
            if ($moved.Count -gt 0) { $continueSkip = "files changed during the run ($($moved.ToArray() -join ', '))" }
        }
        if (-not $continueSkip) {
            # (wave 24b, F08-3) the killed turn's OWN failure evidence (never the bridge's timeout
            # text) through the ONE classifier: the adapter's class and failure texts (an engine),
            # the event stream's error, every line of its stderr - quota (billing included) or auth
            $killed = Get-KilledTurnFailure -AdapterClass $(if ($isCodex) { '' } else { [string]$agyFailureClass }) -Texts ([string[]]@(@([string]$eventError) + @($(if ($isCodex) { @() } else { @($agyFailureTexts) })))) -StderrText $stderrText
            if ($killed.Class) { $continueSkip = "the killed turn reported a $($killed.Class) failure ($($killed.Text))" }
        }
        if ($continueSkip) {
            $timeoutContinueRecord = [pscustomobject]@{ thread = $continueThread; wall_seconds = 0; outcome = "not attempted: $continueSkip"; events = $null; usage = $null }
        } else {
            $contParts = New-Object System.Collections.Generic.List[string]
            if (-not $Raw) { $contParts.Add([string]$promptParts[0]) }
            $contParts.Add($(if ($mainStalled) { "Your previous turn was stopped after no output for $StallSec s outside a tool call." } else { "Your previous turn was stopped by a time limit after $TimeoutSec s." }) + ' Do not start over and do not read more files than you must: finish now and output your final answer in the required format.')
            # (wave 24b, F07-1) a prompt-only transport: the endpoint never receives the schema -
            # the continuation re-sends the reply format and the schema, as the denial retry does
            if (-not $Raw -and $schemaTransport -eq 'prompt-only') {
                $contParts.Add(($schemaLines -join $nl))
                $contSchemaText = ([IO.File]::ReadAllText($schemaPath, $script:Utf8NoBom).Trim() -replace "`r`n", "`n") -replace "`n", $nl
                $contParts.Add("JSON Schema of the reply:$nl$contSchemaText")
            }
            $contParts.Add("Consultation id: $consultId")
            $continuePrompt = [string]::Join("$nl$nl", $contParts.ToArray())
            if ($isCodex) {
                # the main turn's exec-level options (-Mode resume semantics), its own last message
                $contArgv = @('exec', '--sandbox', $Sandbox, '--color', 'never', '--json')
                if ($identity.ModelSource -ne 'unknown') { $contArgv += @('-m', $identity.Model) }
                $contArgv += @('-c', ('model_reasoning_effort="' + (ConvertTo-TomlBasicString $effortSent) + '"'))
                if ($identity.ProviderSource) { $contArgv += @('-c', ('model_provider="' + (ConvertTo-TomlBasicString $identity.Provider) + '"')) }
                foreach ($ec in $extraConfig) { $contArgv += @('-c', $ec) }
                foreach ($cc in $contextConfig) { $contArgv += @('-c', $cc) }
                $contArgv += @('-o', $continueLastPath)
                if (-not $Raw -and $schemaTransport -eq 'output-schema') { $contArgv += @('--output-schema', $schemaPath) }
                $contArgv += @('resume', $continueThread, '-')
                $contStdin = $continuePrompt
                $contStdinPath = $continuePromptPath
                $contPromptFile = ''
            } else {
                # the engine's own argv from one turn-options object, in the main turn's schema
                # transport (native: the schema flag; prompt-only: none)
                $contSchemaArg = $(if (-not $Raw -and $schemaTransport -eq 'native') { $schemaPath } else { '' })
                $contOpts = New-EngineTurnOptions -Model $engineModel -Mode 'timeout-continue' -Thread $continueThread -PromptFile $continuePromptPath -Schema $contSchemaArg -Effort $effortSent -NativeEffort $NativeEffort -MaxSteps $MaxModelSteps -AddDirs @($mainTurn.AddDirs) -Auth $engineAuth
                $contArgv = & $engineSpec.Adapter.Argv -Turn $contOpts
                $contStdin = & $engineSpec.Adapter.Stdin -Prompt $continuePrompt
                $contStdinPath = $(if ($promptByFile) { $stdinPath } else { $continuePromptPath })
                $contPromptFile = $(if ($promptByFile) { $continuePromptPath } else { '' })
            }
            $extraEvents.Add("handoffs/$continueEventsName")
            Write-Host "codex-consult: the main turn was $(if ($mainStalled) { "stopped at $wallSeconds s ($StallSec s without an event)" } else { "killed at $wallSeconds s of $TimeoutSec s" }); one continuation turn on thread $continueThread (up to $ContinueSec s)" -ForegroundColor Yellow
            $continueTurn = Invoke-EngineTurn -Argv $contArgv -StdinText $contStdin -EventsPath $continueEventsPath -StdinPath $contStdinPath -StderrPath $continueStderrPath -Timeout $ContinueSec -Note 'timeout continuation turn' -PromptPath $contPromptFile -PromptText $continuePrompt
            if ($continueTurn.KeepPending) { $keepPending = $true }
            if ($continueTurn.Started) { $engineTurns++ }
            if (Test-Path -LiteralPath $continueEventsPath -PathType Leaf) { $continueEventsRel = "handoffs/$continueEventsName" }
            $contUsage = $null
            if ($isCodex) {
                $contThreadSeen = ''
                try { $contThreadSeen = Get-ThreadIdFromEvents -Path $continueEventsPath } catch { $contThreadSeen = '' }
                try { $contUsage = Get-UsageFromEvents -Path $continueEventsPath } catch { $contUsage = $null }
                $contRaw = (Read-SharedText -Path $continueLastPath).Trim()
                $contErr = ''
                try { $contErr = Get-ErrorFromEvents -Path $continueEventsPath } catch { $contErr = '' }
                $continueProblem = [string]$continueTurn.Problem
                if (-not $continueProblem -and $continueTurn.Exit -ne 0) {
                    $continueProblem = "codex exit $($continueTurn.Exit)$(if ($contErr) { " - $contErr" })"
                }
                if (-not $continueProblem -and $contThreadSeen -and $contThreadSeen -ne $continueThread) { $continueProblem = "the continuation came back on thread $contThreadSeen, not $continueThread" }
                if (-not $continueProblem -and -not $contRaw) { $continueProblem = 'empty reply' }
                if (-not $continueProblem) {
                    # (wave 24b, F08-5) the checks of a first reply before the continuation counts
                    $contCheck = Test-ContinuationReply -Text $contRaw -Raw:$Raw -Purpose $Purpose -PriorFindings $priorInfo
                    if (-not $contCheck.Usable) { $continueProblem = "not a usable reply - $($contCheck.Reason)"; $continueRejected = $true; $continueRejectedText = $contRaw; $continueRejectedWhy = [string]$contCheck.Reason }
                }
                if ($continueProblem -and -not $continueRejected -and $continueTurn.Started) {
                    # (wave 24b, F08-4) the failed continuation's own evidence, best first: an SSE
                    # error payload on its stderr, its event stream's error, its stderr's last line,
                    # the bridge's reason
                    $contStderr = [string]$continueTurn.Stderr
                    $contSse = @(($contStderr -split "`r?`n") | Where-Object { $_ -match '^\s*data:\s*\{' }) | Select-Object -Last 1
                    $contTail = (($contStderr.Trim() -split "`r?`n") | Select-Object -Last 1)
                    $continueFailure = [pscustomobject]@{ Texts = [string[]]@(@([string]$contSse, $contErr, [string]$contTail, $continueProblem) | Where-Object { $_ }); Class = '' }
                }
                if (-not $continueProblem) {
                    $continued = $true
                    $bridgeOutcome = 'usable reply'
                    $rawReply = $contRaw
                    if (-not $Raw) {
                        # the continuation's last message, byte for byte, as the reply json
                        $copyError = ''
                        for ($attempt = 1; $attempt -le 6; $attempt++) {
                            try { [IO.File]::Copy($continueLastPath, $replyJsonPath, $true); $copyError = ''; break } catch { $copyError = ConvertTo-OneLine $_.Exception.Message; Start-Sleep -Milliseconds 250 }
                        }
                        if ($copyError) { $bridgeOutcome = "failed: could not preserve the raw reply of the continuation ($copyError); it is in $(if ($continueEventsRel) { $continueEventsRel } else { 'its event stream' })"; $continued = $false; $continueProblem = $copyError }
                        else { $replyJsonRel = $replyJsonPlanned }
                    }
                }
            } else {
                $contEv = & $engineSpec.Adapter.Events -Path $continueEventsPath -AllowPartialLast:([bool]($continueTurn.Problem -or $continueTurn.Exit -ne 0))
                $contOut = & $engineSpec.Adapter.Outcome -Events $contEv -ExitCode $continueTurn.Exit -StderrText $continueTurn.Stderr -Pre $(if ($continueTurn.Problem) { "failed: $($continueTurn.Problem)" } else { '' }) -ExpectThread $continueThread -ExpectModel $engineModel -Turn $contOpts
                $contUsage = $contEv.Usage
                if ($contOut.Ok) {
                    # (wave 24b, F08-5) the checks of a first reply before the continuation counts
                    $contCheck = Test-ContinuationReply -Text ([string]$contOut.Reply) -Raw:$Raw -Purpose $Purpose -PriorFindings $priorInfo
                    if (-not $contCheck.Usable) { $continueProblem = "not a usable reply - $($contCheck.Reason)"; $continueRejected = $true; $continueRejectedText = [string]$contOut.Reply; $continueRejectedWhy = [string]$contCheck.Reason }
                } else {
                    $continueProblem = ($contOut.Outcome -replace '^failed:\s*', '')
                    # (wave 24b, F08-4) the failed continuation's own evidence and its class
                    if ($continueTurn.Started) { $continueFailure = [pscustomobject]@{ Texts = [string[]]@(@($contOut.Texts) + @($continueProblem) | Where-Object { $_ }); Class = [string]$contOut.Class } }
                }
                if ($contOut.Ok -and -not $continueRejected) {
                    $continued = $true
                    $bridgeOutcome = 'usable reply'
                    $agyFailureClass = ''
                    $agyFailureTexts = @()
                    $rawReplyFull = [string]$contOut.Reply
                    $rawReply = $rawReplyFull.Trim()
                    # the conversation is verified now: the continuation came back on it
                    $threadId = [string]$contOut.Thread
                    $threadSource = 'events'
                    $threadCandidate = ''
                    foreach ($w in @($contOut.Warnings)) { $engineWarnings.Add($w) }
                    if ($null -eq $mspVersion -and $contEv.PSObject.Properties['SchemaVersion']) { $mspVersion = $contEv.SchemaVersion }
                    if (-not $Raw -and $rawReplyFull.Trim()) {
                        try { Write-TextAtomic -Path $replyJsonPath -Text $rawReplyFull; $replyJsonRel = $replyJsonPlanned } catch {
                            $bridgeOutcome = "failed: could not preserve the reply of the continuation ($(ConvertTo-OneLine $_.Exception.Message)); it is in $(if ($continueEventsRel) { $continueEventsRel } else { 'its event stream' })"
                            $agyFailureClass = 'unknown'; $agyFailureTexts = @($bridgeOutcome -replace '^failed:\s*', ''); $continued = $false; $continueProblem = 'the reply could not be preserved'
                        }
                    }
                }
            }
            $timeoutContinueRecord = [pscustomobject]@{
                thread       = $continueThread
                wall_seconds = $continueTurn.Wall
                outcome      = $(if ($continued) { 'usable reply' } else { "failed: $continueProblem" })
                events       = $continueEventsRel
                usage        = $contUsage
            }
        }
    }

    # ------------------------------------------------------------------------- structured reply

    # A reply that is not valid JSON or breaks the schema is NOT a bridge failure: the
    # raw text is kept as the reply, but there is no verdict and no finding is recorded.
    # A structurally valid reply whose verdict does not fit the purpose or contradicts
    # a blocker keeps its findings but records no verdict.
    $structured = $false
    $parse = $null
    $ingest = $null
    $validationError = ''
    $verdict = ''
    $verdictReason = ''
    $replyBody = $rawReply
    $counts = [pscustomobject]@{ blocker = 0; major = 0; minor = 0; note = 0 }
    $findingIds = @()
    $priorForLedger = @()
    $uncheckedPrior = @()
    $bridgeBug = $false
    if (-not $Raw -and $bridgeOutcome -eq 'usable reply') {
        try {
            $parse = ConvertFrom-StructuredReply -Text $rawReply -Purpose $Purpose -PriorFindings $priorInfo
            $validationError = $parse.ValidationError
        } catch {
            $bridgeBug = $true
            $validationError = "bridge could not process the reply: $(ConvertTo-OneLine $_.Exception.Message)"
            $parse = [pscustomobject]@{ Valid = $false; ValidationError = $validationError; Reply = $null; UncheckedPriorBlockers = @() }
        }
    }

    # ------------------------------------------------------------------------- format repair

    # The reviewer answered in prose instead of the JSON object: ONE repair turn resumes the
    # same thread and asks it to convert that message, unchanged, into the object - no
    # --output-schema, the lowest effort of the route, never the brief. Only for a usable
    # reply (codex exit 0, no timeout, no provider failure) that is substantive prose on a
    # VERIFIED thread, and only with -FormatRetry 1. The task lock and the recovery record
    # stay held (state running; child_pid = the repair process). The result is validated
    # like any reply; drift notes compare the prose with the repaired object (warnings).
    $formatRetryRecord = $null
    $repairedOk = $false
    $originalProse = ''
    $repairConsole = ''
    $repairEligible = [bool]($repairEnabled -and $parse -and -not $parse.Valid -and -not $bridgeBug -and $bridgeOutcome -eq 'usable reply' -and
        $threadId -and ($threadSource -eq 'events' -or $threadSource -eq 'rollout (verified by consultation id)'))
    # The prose itself must be worth converting (Get-ProseGate: not a refusal, above the
    # word floors); when it is not, validation_error says why no repair turn ran.
    $proseGate = $null
    if ($repairEligible) {
        $proseGate = Get-ProseGate -Text $rawReply
        if (-not $proseGate.Substantive) { $validationError = "$validationError (format repair not attempted: $($proseGate.Reason))" }
    }
    if ($repairEligible -and $proseGate.Substantive) {
        $originalProse = $rawReply
        $repairReason = [string]$validationError
        if ($repairReason.Length -gt 200) { $repairReason = $repairReason.Substring(0, 200) }
        # The raw first message, byte for byte (the .reply.json gets the repaired object).
        $originalRel = "handoffs/$nn-$enginePrefix-$ReplyName.original.md"
        $originalFull = Join-Path $handoffsDir "$nn-$enginePrefix-$ReplyName.original.md"
        if ($isCodex) { try { [IO.File]::Copy($(if ($continued) { $continueLastPath } else { $lastMsgPath }), $originalFull, $true) } catch { Write-Utf8NoBom -Path $originalFull -Text $rawReply } }
        else { Write-Utf8NoBom -Path $originalFull -Text $rawReplyFull }
        $repairSchema = ([IO.File]::ReadAllText($schemaPath, $script:Utf8NoBom).Trim() -replace "`r`n", "`n") -replace "`n", $nl
        $repairPrompt = 'Your last message was prose, not the required JSON. Reply with exactly one bare JSON object satisfying the JSON Schema below - no fence, nothing before or after it. Convert, do not re-answer: copy your previous content unchanged (the same Q1..Qn answers verbatim inside reply_markdown, the same findings, the same Requested checks, the same prior-finding statuses and the same verdict); add or omit nothing.' +
            "$nl$nl" + "JSON Schema of the reply:$nl$repairSchema" + "$nl$nl" + "Consultation id: $consultId"
        $repairTimeout = [Math]::Min($TimeoutSec, 300)
        # (wave 23b, F09-2 of the muse acceptance) the repair turn's schema transport: codex
        # never passes --output-schema on it (prompt-only); an engine uses the main turn's
        # transport - native: the schema flag; prompt-only: no schema flag, the schema travels
        # in the repair prompt below as it did in the main turn's. Ledger
        # format_retry.schema_transport.
        $repairTransport = $(if ($isCodex) { 'prompt-only' } else { $schemaTransport })
        # format_retry.events (F09-2): the repair turn's event stream when one is kept
        # (agy: handoffs/NN-agy-<slug>.repair.events.jsonl); codex's goes to a temp file that
        # is removed - null (the codex file layout is unchanged).
        $repairEventsRel = $null
        if ($isCodex) {
            $repairEffort = Get-RepairEffort -Identity $identity -EffortPlan $effortPlan
            $repairArgv = @('exec', '--sandbox', 'read-only', '--color', 'never', '--json')
            if ($identity.ModelSource -ne 'unknown') { $repairArgv += @('-m', $identity.Model) }
            $repairArgv += @('-c', ('model_reasoning_effort="' + (ConvertTo-TomlBasicString $repairEffort) + '"'))
            if ($identity.ProviderSource) { $repairArgv += @('-c', ('model_provider="' + (ConvertTo-TomlBasicString $identity.Provider) + '"')) }
            foreach ($ec in $extraConfig) { $repairArgv += @('-c', $ec) }
            foreach ($cc in $contextConfig) { $repairArgv += @('-c', $cc) }
            $repairArgv += @('-o', $repairLastPath, 'resume', $threadId, '-')
            Write-Utf8NoBom -Path $repairPromptPath -Text $repairPrompt
            $repairWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $repairExit = -1
            $repairProblem = ''
            $repairProc = $null
            # The recovery record names the saved prose BEFORE the repair process exists: if
            # this run is stopped now, the next run (and codex-findings -List) points at it
            # (Get-PendingOriginalNote). State launching until the repair pid is registered.
            $originalRepoRel = Get-RepoRelativePath -Root $repoRoot -Path $originalFull
            if (-not $originalRepoRel) { $originalRepoRel = $originalFull }
            $pendingRecord | Add-Member -NotePropertyName 'original' -NotePropertyValue $originalRepoRel -Force
            $pendingRecord | Add-Member -NotePropertyName 'first_reply' -NotePropertyValue 'usable prose (format repair in progress)' -Force
            $repairPrevState = [string]$pendingRecord.state
            $repairPrevNote = [string]$pendingRecord.note
            $pendingRecord.state = 'launching'
            $pendingRecord.note = 'format repair turn being started; its pid is not recorded yet'
            try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
                $repairProblem = "could not write the recovery record ($(ConvertTo-OneLine $_.Exception.Message)); the repair turn was not started"
                $pendingRecord.state = $repairPrevState
                $pendingRecord.note = $repairPrevNote
            }
            if (-not $repairProblem) {
                # (wave 24b, F08-1) the ONE guarded start
                $repairLaunch = Start-EngineProcess -Launcher $codexExePath -Argv $repairArgv -StdoutPath $repairEventsPath -StderrPath $repairStderrPath -StdinPath $repairPromptPath
                $repairProc = $repairLaunch.Proc
                if ($repairLaunch.Refusal) { $repairProblem = "refused before launch: $($repairLaunch.Refusal)" }
                elseif (-not $repairProc) { $repairProblem = "could not start codex$(if ($repairLaunch.Error) { " - $($repairLaunch.Error)" })" }
                if (-not $repairProc) {
                    # (wave 24c, F15-6) nothing was started: the record gets its previous state back
                    # (it keeps naming the saved prose, `original`)
                    $pendingRecord.state = $repairPrevState
                    $pendingRecord.note = $repairPrevNote
                    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
                }
            }
            if ($repairProc) {
                if ($script:LegacyPS) { try { $null = $repairProc.Handle } catch { } }
                $repairRegistered = $true
                try {
                    $pendingRecord.state = 'running'
                    $pendingRecord.child_pid = $repairProc.Id
                    $pendingRecord.child_start_time = [string](Get-ProcessStartIso -ProcessId $repairProc.Id)
                    $pendingRecord.note = 'format repair turn'
                    Write-PendingFile -Path $pendingPath -Record $pendingRecord
                } catch {
                    $repairRegistered = $false
                    $repairProblem = "could not register the repair process ($(ConvertTo-OneLine $_.Exception.Message)); it was stopped"
                    $pendingRecord.state = 'launching'; $pendingRecord.child_pid = $null; $pendingRecord.child_start_time = ''
                    $null = Stop-ProcessTree -Process $repairProc
                }
                if ($repairRegistered) {
                    # (wave 26b, D10) the operator's kick is polled here too
                    $repairWait = Wait-EngineProcess -Process $repairProc -TimeoutSec $repairTimeout -KickPath $script:KickPath
                    if ($repairWait.KickLate) { $script:KickLateTurns.Add('the format repair') }
                    if (-not $repairWait.Exited) {
                        $repairKill = Stop-ProcessTreeChecked -Process $repairProc
                        Add-KillCheck -Check $repairKill -Turn 'format repair'
                        $repairSurvivors = [int[]]$repairKill.Survivors
                        $repairStop = "timeout after $repairTimeout s"
                        if ($repairWait.Reason -eq 'kick') { $script:RunKicked = $true; $script:KickedTurn = 'repair'; $repairStop = 'stopped by the operator (-Kick)'; $null = Remove-PendingFile -Path $script:KickPath }
                        $repairProblem = "$repairStop $(Format-KillText $repairKill)"
                        if ($repairSurvivors.Count -gt 0) {
                            $repairProblem = "$repairStop (process tree killed; $($repairSurvivors.Count) processes survived: pid $($repairSurvivors -join ', ')$(Get-KillUnverifiedText $repairKill))"
                            $keepPending = $true
                            try {
                                $pendingRecord.state = 'survivors'
                                $pendingRecord.survivors = [object[]]@(New-SurvivorEntries -Pids $repairSurvivors)
                                # (wave 28e, E1 / F54-1) the descendants the kill could not verify, beside them
                                $pendingRecord | Add-Member -NotePropertyName 'unverified' -NotePropertyValue ([object[]]@(New-UnverifiedEntries -Check $repairKill)) -Force
                                Write-PendingFile -Path $pendingPath -Record $pendingRecord
                            } catch { }
                        }
                    } else {
                        $repairExit = $repairProc.ExitCode
                    }
                }
            }
            $repairWatch.Stop()
            $repairWall = [math]::Round($repairWatch.Elapsed.TotalSeconds, 1)
            $repairThread = ''
            try { $repairThread = Get-ThreadIdFromEvents -Path $repairEventsPath } catch { $repairThread = '' }
            $repairUsage = $null
            try { $repairUsage = Get-UsageFromEvents -Path $repairEventsPath } catch { $repairUsage = $null }
            $repairRaw = (Read-SharedText -Path $repairLastPath).Trim()
            if (-not $repairProblem -and $repairExit -ne 0) { $repairProblem = "codex exit $repairExit" }
            if (-not $repairProblem -and -not $repairRaw) { $repairProblem = 'empty reply' }
        } else {
            # An engine (agy, muse): the same repair prompt on the same conversation / session
            # (agy --conversation, muse --session-id), with the schema in the main turn's
            # transport (native: the engine's schema flag; prompt-only: none - wave 23b), through
            # the engine's adapter (wave 23, D2); the turn must come back on THAT thread (A12) - a
            # repair in a fresh one has no "last message" to convert and would invent one. At
            # most once; only after a usable reply (never after a quota, auth or billing failure).
            $originalRepoRel = Get-RepoRelativePath -Root $repoRoot -Path $originalFull
            if (-not $originalRepoRel) { $originalRepoRel = $originalFull }
            $pendingRecord | Add-Member -NotePropertyName 'original' -NotePropertyValue $originalRepoRel -Force
            $pendingRecord | Add-Member -NotePropertyName 'first_reply' -NotePropertyValue 'usable prose (format repair in progress)' -Force
            $repairOpts = New-EngineTurnOptions -Model $engineModel -Mode 'format-repair' -Thread $threadId -PromptFile $repairPromptPath -Schema $(if ($repairTransport -eq 'native') { $schemaPath } else { '' }) -Effort (Get-RepairEffort -Identity $identity -EffortPlan $effortPlan) -NativeEffort $NativeEffort -MaxSteps $MaxModelSteps -AddDirs @($mainTurn.AddDirs) -Auth $engineAuth
            $repairArgv = & $engineSpec.Adapter.Argv -Turn $repairOpts
            $repairEventsName = "$nn-$enginePrefix-$ReplyName.repair.events.jsonl"
            $repairEngineEvents = Join-Path $handoffsDir $repairEventsName
            $extraEvents.Add("handoffs/$repairEventsName")
            $repairTurn = Invoke-EngineTurn -Argv $repairArgv -StdinText (& $engineSpec.Adapter.Stdin -Prompt $repairPrompt) -EventsPath $repairEngineEvents -StdinPath $(if ($promptByFile) { $stdinPath } else { $repairPromptPath }) -StderrPath $repairStderrPath -Timeout $repairTimeout -Note 'format repair turn' -PromptPath $(if ($promptByFile) { $repairPromptPath } else { '' }) -PromptText $repairPrompt
            if ($repairTurn.KeepPending) { $keepPending = $true }
            if ($repairTurn.Started) { $engineTurns++ }
            $repairWall = $repairTurn.Wall
            $repairEv = & $engineSpec.Adapter.Events -Path $repairEngineEvents -AllowPartialLast:([bool]($repairTurn.Problem -or $repairTurn.Exit -ne 0))
            if (Test-Path -LiteralPath $repairEngineEvents -PathType Leaf) { $repairEventsRel = "handoffs/$repairEventsName" }
            $repairOut = & $engineSpec.Adapter.Outcome -Events $repairEv -ExitCode $repairTurn.Exit -StderrText $repairTurn.Stderr -Pre $(if ($repairTurn.Problem) { "failed: $($repairTurn.Problem)" } else { '' }) -ExpectThread $threadId -ExpectModel $engineModel -Turn $repairOpts
            $repairThread = [string]$repairEv.Thread
            $repairUsage = $repairEv.Usage
            $repairRawFull = [string]$repairOut.Reply
            $repairRaw = $repairRawFull.Trim()
            $repairProblem = ''
            if (-not $repairOut.Ok) { $repairProblem = ($repairOut.Outcome -replace '^failed:\s*', '') }
        }
        $repairParse = $null
        if (-not $repairProblem) {
            try {
                $repairParse = ConvertFrom-StructuredReply -Text $repairRaw -Purpose $Purpose -PriorFindings $priorInfo
                if (-not $repairParse.Valid) { $repairProblem = "still not valid: $($repairParse.ValidationError)" }
            } catch {
                $repairProblem = "bridge could not process the repaired reply: $(ConvertTo-OneLine $_.Exception.Message)"
                $repairParse = $null
            }
        }
        $drift = New-Object System.Collections.Generic.List[string]
        if ($isCodex -and $repairThread -and $repairThread -ne $threadId) { $drift.Add('repair returned a different thread id') }
        if (-not $repairProblem) {
            $repairedOk = $true
            $parse = $repairParse
            $validationError = $parse.ValidationError
            foreach ($d in (Get-FormatRepairDrift -Prose $originalProse -Reply $parse.Reply)) { $drift.Add($d) }
            # The .reply.json holds the repaired object, byte for byte.
            if ($isCodex) { try { [IO.File]::Copy($repairLastPath, $replyJsonPath, $true); $replyJsonRel = $replyJsonPlanned } catch { } }
            else { try { Write-TextAtomic -Path $replyJsonPath -Text $repairRawFull; $replyJsonRel = $replyJsonPlanned } catch { } }
        } else {
            $validationError = "$validationError (format repair failed: $(ConvertTo-OneLine $repairProblem))"
        }
        $formatRetryRecord = [pscustomobject]@{
            attempted        = $true
            reason           = $repairReason
            succeeded        = $repairedOk
            thread           = $repairThread
            wall_seconds     = $repairWall
            usage            = $repairUsage
            drift            = [object[]]$drift.ToArray()
            original         = $originalRel
            events           = $repairEventsRel
            schema_transport = $repairTransport
        }
        $repairConsole = "format repair: $(if ($repairedOk) { 'succeeded' } else { 'failed' }) in $repairWall s; drift: $($drift.Count) note(s)"
    }

    # An engine's denial-retry or format-repair turn may have written too - the read-only check
    # again over the whole run (A17); a run that changed anything ingests nothing, and the
    # change forces class permission (D12).
    if (-not $isCodex -and $extraEvents.Count -gt 0 -and -not $treeProblem) {
        $revAfter = Get-RevisionInfo -Root $repoRoot -CollabRoot $collabRoot
        $treeCompare = Compare-TreeContent -Before $revBefore -After $revAfter
        $treeChanged = $treeCompare.Changed
        $revisionMoved = $treeCompare.RevisionMoved
        if ($briefPath) { $briefShaAfter = Get-FileSha256OrMissing -Path $briefPath }
        $briefChanged = ($briefSha -ne $briefShaAfter)
        $artifactsFinal = @($artifactHashes | ForEach-Object { [pscustomobject]@{ path = $_.path; sha256 = $_.sha256; sha256_after = (Get-FileSha256OrMissing -Path $_.full) } })
        $changedArtifacts = @($artifactsFinal | Where-Object { $_.sha256 -ne $_.sha256_after } | ForEach-Object { $_.path })
        $artifactsChanged = ($changedArtifacts.Count -gt 0)
        $treeCheck = Get-EngineTreeCheck -RevBefore $revBefore -RevAfter $revAfter -BriefChanged $briefChanged -ChangedArtifacts $changedArtifacts -CollabBefore $collabBefore -CollabAfter (Get-CollabSnapshot -Dir $collabRoot) -OwnPrefixes $ownPrefixes -Engine $engineName -CollabShown $collabShown
        $treeProblem = $treeCheck.Problem
        $treeCheckRecord = [pscustomobject]@{ outcome = $treeCheck.Outcome; files = [object[]]@($treeCheck.Files) }
        # (wave 26b, D9) the whole run's warnings replace the main turn's
        foreach ($w in $treeCheckWarnings) { [void]$engineWarnings.Remove($w) }
        $treeCheckWarnings = [string[]]@($treeCheck.Warnings)
        foreach ($w in $treeCheckWarnings) { $engineWarnings.Add($w) }
        if ($treeProblem) {
            $agyFailureClass = 'permission'
            if ($bridgeOutcome -eq 'usable reply') {
                $bridgeOutcome = "failed: $treeProblem"
                $agyFailureTexts = @($treeProblem)
                # the reply stays named (reply json, handoff), nothing of it is ingested
                $parse = $null
            } else {
                $bridgeOutcome += "; also: $treeProblem"
            }
        }
    }

    # Classified provider failure (null on success): what the endpoint said - an SSE
    # `data:{"error":...}` line, the event-stream error, stderr - or the bridge's own reason.
    # Later preflights read it back per endpoint (Get-EndpointHealth).
    # (wave 23) ledger engine_run: null for codex; for an engine the turns started, the model-step
    # cap sent (muse) and the MSP schema version of the stream (muse).
    $engineRunRecord = $null
    if (-not $isCodex) {
        $engineRunRecord = [pscustomobject]@{
            turns              = $engineTurns
            max_model_steps    = $(if ($MaxModelSteps -gt 0) { $MaxModelSteps } else { $null })
            msp_schema_version = $mspVersion
        }
        # (wave 29) the claude engine's evidence per run, over the turns that ran: the init events'
        # tools (the union), MCP servers (the most any turn listed), permission mode and apiKeySource,
        # the resolved model (D4) and the other models a turn named, the permission denials (count and
        # tools), the most severe rate_limit_event as the CLI wrote it (D6), the notional cost
        # (total_cost_usd - a subscription is not billed per request), the auth mode, the names of the
        # child environment (D2 - never a value) and what R22 switched off
        if ($engineName -eq 'claude') {
            $claudeEvs = @(@($agyEvents, $retryEvents, $contEv, $repairEv) | Where-Object { $null -ne $_ -and $_.PSObject.Properties['InitCount'] -and [int]$_.InitCount -gt 0 })
            $claudeOuts = @(@($agyTurn, $retryOut, $contOut, $repairOut) | Where-Object { $null -ne $_ -and $_.PSObject.Properties['ModelResolved'] })
            $claudeResolved = [string](@($claudeOuts | ForEach-Object { [string]$_.ModelResolved } | Where-Object { $_ }) | Select-Object -Last 1)
            $claudeTools = New-Object System.Collections.Generic.List[string]
            foreach ($ce in $claudeEvs) { foreach ($tn in @($ce.InitTools)) { if ($tn -and -not $claudeTools.Contains([string]$tn)) { $claudeTools.Add([string]$tn) } } }
            $claudeOther = @(@($claudeOuts | ForEach-Object { @($_.OtherModels) }) | Where-Object { $_ } | Select-Object -Unique)
            $claudeDenials = @(@(@($agyEvents, $retryEvents, $contEv, $repairEv) | Where-Object { $null -ne $_ -and $_.PSObject.Properties['Denials'] }) | ForEach-Object { @($_.Denials) } | Where-Object { $_ })
            $claudeRate = $null
            foreach ($ce in @(@($agyEvents, $retryEvents, $contEv, $repairEv) | Where-Object { $null -ne $_ -and $_.PSObject.Properties['RateLimit'] -and $null -ne $_.RateLimit })) {
                if ($null -eq $claudeRate -or $ce.RateLimitRejected) { $claudeRate = $ce.RateLimit }
            }
            $claudeCost = $null
            foreach ($ce in @(@($agyEvents, $retryEvents, $contEv, $repairEv) | Where-Object { $null -ne $_ -and $_.PSObject.Properties['CostUsd'] -and $null -ne $_.CostUsd })) { $claudeCost = [double]$(if ($null -eq $claudeCost) { 0 } else { $claudeCost }) + [double]$ce.CostUsd }
            $claudeFirst = $(if ($claudeEvs.Count -gt 0) { $claudeEvs[0] } else { $null })
            $claudeEnvNames = [string[]]@()
            try { $claudeEnvNames = [string[]](Get-ClaudeChildEnvironment -Auth $engineAuth -Endpoint $engineEndpoint).Names } catch { $claudeEnvNames = [string[]]@() }
            foreach ($kv in @(
                    @('auth', $engineAuth),
                    @('init_tools', [object[]]$claudeTools.ToArray()),
                    @('mcp_servers', $(if ($claudeEvs.Count -gt 0) { [long](@($claudeEvs | ForEach-Object { @($_.InitMcp).Count }) | Measure-Object -Maximum).Maximum } else { $null })),
                    @('permission_mode', $(if ($claudeFirst -and @($claudeFirst.InitModes).Count -gt 0) { ConvertTo-ClaudeToken ([string]@($claudeFirst.InitModes)[0]) } else { $null })),
                    @('api_key_source', $(if ($claudeFirst -and @($claudeFirst.InitKeySources).Count -gt 0) { ConvertTo-ClaudeToken ([string]@($claudeFirst.InitKeySources)[0]) } else { $null })),
                    @('model_resolved', $(if ($claudeResolved) { $claudeResolved } else { $null })),
                    @('other_models', [object[]]@($claudeOther)),
                    @('permission_denials', [long]$claudeDenials.Count),
                    @('denied_tools', [object[]]@($claudeDenials | ForEach-Object { [string]$_.Tool } | Where-Object { $_ } | Select-Object -Unique)),
                    @('rate_limit', $claudeRate),
                    @('quota_mark', $null),
                    @('cost_usd', $claudeCost),
                    @('child_env_allowed', [object[]]$claudeEnvNames),
                    @('switched_off', [object[]]$script:ClaudeSwitchedOff))) {
                $engineRunRecord | Add-Member -NotePropertyName ([string]$kv[0]) -NotePropertyValue $kv[1]
            }
            # (item 9) the coordinator compared again with the model the run resolved: an alias the
            # warning was given on may have resolved elsewhere (or the other way round)
            if ($engineRunRecord.model_resolved -and ([string]$engineRunRecord.model_resolved) -cne [string]$identity.Model) {
                $coordinatorKindAfter = Get-CoordinatorMatch -Coordinator $coordinatorRecord -Provider ([string]$identity.Provider) -Model ([string]$engineRunRecord.model_resolved) -Engine $engineName -Auth $engineAuth
                if ($coordinatorKindAfter -and $coordinatorKindAfter -ne $coordinatorKind) { $engineWarnings.Add((Format-CoordinatorWarning -Kind $coordinatorKindAfter -Lineage "$lineageShown (resolved $($engineRunRecord.model_resolved))")) }
                elseif (-not $coordinatorKindAfter -and $coordinatorKind) { $engineWarnings.Add("coordinator: $lineageShown resolved to $($engineRunRecord.model_resolved) - not the coordinator's own model ($([string](Get-PropertyValue $coordinatorRecord 'model' ''))) after all; the warning above was given before the run") }
            }
        }
    }
    # (wave 26b, D10) a turn the operator stopped (-Kick): the run failed by the operator's hand -
    # class operator (no endpoint's fault: the health views never read it as an outage).
    # (wave 26c, D1 / F25-2) A kick that stopped only the FORMAT REPAIR leaves an earlier usable
    # reply usable (its prose stands, not converted; a warning says so); a kick found after a turn
    # had finished (kick_late) changes no outcome.
    # (wave 27c, D2 / F30-5) a kick addresses the RUN of a member, not one turn: found before or during
    # the timeout continuation it cancels the continuation - the timeout outcome and its salvage stay
    # (the operator's stop is no provider evidence: no provider failure from the cancelled turn); the
    # warning names the cancelled turn
    $kickedContinuation = [bool]($script:RunKicked -and $script:KickedTurn -eq 'continue' -and -not $continued)
    if ($kickedContinuation) { $continueFailure = $null; $engineWarnings.Add('kick: the operator stopped the timeout continuation (-Kick); the timeout outcome and its salvage stay') }
    $kickFailsRun = [bool]($script:RunKicked -and -not $kickedContinuation -and -not ($script:KickedTurn -eq 'repair' -and (Test-UsableOutcome $bridgeOutcome)))
    if ($script:RunKicked -and -not $kickFailsRun -and -not $kickedContinuation) { $engineWarnings.Add('kick: the operator stopped the format repair (-Kick); the first reply stands, not converted') }
    # (wave 27c, D16) the later turns' unconfirmed kills, and the ledger's kill_confirmed: $null when no
    # tree was killed, $true when every kill was confirmed without survivors, else $false
    foreach ($kw in @(@($script:TurnWarnings) + @($script:KillWarnings))) { if ($kw -and -not $engineWarnings.Contains([string]$kw)) { $engineWarnings.Add([string]$kw) } }
    $killConfirmedRecord = $null
    if ($script:KillChecks.Count -gt 0) { $killConfirmedRecord = [bool](@($script:KillChecks | Where-Object { -not $_.Confirmed -or @($_.Survivors).Count -gt 0 }).Count -eq 0) }
    foreach ($kl in $script:KickLateTurns) { $engineWarnings.Add("kick_late: the member had already finished ($kl) - the kick changed nothing") }
    if ($kickFailsRun -and $bridgeOutcome -notlike 'failed: stopped by the operator*') { $bridgeOutcome = 'failed: stopped by the operator (-Kick)' }
    $providerFailure = $null
    if ($kickFailsRun) {
        $providerFailure = New-ProviderFailure -Texts @('stopped by the operator (-Kick)') -Class 'operator'
    } elseif ($bridgeOutcome -ne 'usable reply' -and -not $isCodex -and $agyFailureClass -eq 'permission') {
        # the tree check's forced class (D12) outranks the evidence of every turn
        $providerFailure = New-ProviderFailure -Texts @(@($agyFailureTexts) + @(($bridgeOutcome -replace '^failed:\s*', ''))) -Class $agyFailureClass
    } elseif ($bridgeOutcome -ne 'usable reply' -and $continueFailure) {
        # (wave 24b, F08-4) the timeout continuation ran and FAILED: the final failing turn's
        # complete evidence - its stderr, its event error, its adapter's class - and the reset
        # time it names (retry_after); the endpoint health reads it, so a 429 in the continuation
        # marks the endpoint out like one in a first turn
        $providerFailure = New-ProviderFailure -Texts @($continueFailure.Texts) -Class ([string]$continueFailure.Class)
    } elseif ($bridgeOutcome -ne 'usable reply' -and $isCodex) {
        $sseLines = @(($stderrText -split "`r?`n") | Where-Object { $_ -match '^\s*data:\s*\{' })
        $stderrTail = (($stderrText.Trim() -split "`r?`n") | Select-Object -Last 1)
        $providerFailure = New-ProviderFailure -Texts @(($sseLines | Select-Object -Last 1), $eventError, $stderrTail, ($bridgeOutcome -replace '^failed:\s*', ''))
    } elseif ($bridgeOutcome -ne 'usable reply') {
        # agy: the result's error, the telling stderr line, the bridge's reason - and the class
        # the turn rules force (permission, transport, unknown), else the classifier's.
        $providerFailure = New-ProviderFailure -Texts @(@($agyFailureTexts) + @(($bridgeOutcome -replace '^failed:\s*', ''))) -Class $agyFailureClass
    }
    # (wave 24b) the operator's next step for a failure the bridge can explain (Get-FailureHint:
    # a context-window limit of the plan or the model) - the summary and the handoff header
    $failureHint = Get-FailureHint $providerFailure
    # (wave 29b, E15) a usable reply whose turn saw a REJECTING rate-limit event: the route's health
    # gets the mark a failed quota turn would get - the same classifier on the same quota text
    # (New-ProviderFailure -Class quota: a usage window with its reset, a burst 10 minutes) -, kept in
    # engine_run.quota_mark and in the machine-wide record; the roster walk, the listing and the
    # plan (E5) read it as a quota failure right after the reply (Get-EndpointHealth)
    $quotaMark = $null
    if (-not $isCodex -and $engineRunRecord -and $engineRunRecord.PSObject.Properties['quota_mark'] -and (Test-UsableOutcome $bridgeOutcome)) {
        $markText = [string](@(@($agyTurn, $retryOut, $contOut, $repairOut) | Where-Object { $null -ne $_ -and $_.PSObject.Properties['QuotaMark'] -and [string]$_.QuotaMark } | ForEach-Object { [string]$_.QuotaMark }) | Select-Object -First 1)
        if ($markText) {
            $quotaMark = New-ProviderFailure -Texts @($markText) -Class 'quota'
            $engineRunRecord.quota_mark = $quotaMark
        }
    }
    # (wave 24) a reply of the timeout continuation says so everywhere (ledger, header, summary)
    if ($continued -and $bridgeOutcome -eq 'usable reply') { $bridgeOutcome = 'usable reply (after a timeout continuation)' }
    # (wave 26b, D13; wave 26c, D2 / F26-2) the run's outcome on the endpoint into the machine-wide
    # health (a usable reply, or a provider failure other than the operator's) - now, before the
    # ledger; a lock timeout is retried once at the ledger commit, and if that fails too the run
    # says so (warnings[], the summary): the repository ledger keeps the truth either way
    # (wave 27c, D7 / F30-7, F29-1, F32-3) ANY failure of the update is retried - its cause named
    # (wave 28b, D13 / F36-6, F37-1) the record is built ONCE: the same record goes into the journal at
    # the commit and into the retry after it (applying is idempotent)
    $machineHealthRetry = $false
    $machineHealthCause = ''
    $machineHealthRecord = New-MachineHealthRecord -Fingerprint ([string]$identity.Fingerprint) -Outcome $bridgeOutcome -Failure $providerFailure -Repo $repoRoot -QuotaMark $quotaMark
    if ($machineHealthRecord -and -not (Add-MachineHealthRecord -Fingerprint ([string]$identity.Fingerprint) -Outcome $bridgeOutcome -Failure $providerFailure -Repo $repoRoot -Record $machineHealthRecord) -and [string]$script:MachineHealthLastError) { $machineHealthRetry = $true; $machineHealthCause = [string]$script:MachineHealthLastError }
    # (wave 28c, D10 / F42-6, F44-1) a journal line that could not be applied was moved aside, never
    # dropped silently: said in warnings[] (the updates of this run so far - its registration, its outcome)
    foreach ($hn in (Get-MachineHealthJournalNotes)) { if ($hn -and -not $engineWarnings.Contains([string]$hn)) { $engineWarnings.Add([string]$hn) } }
    # (wave 28c, D11 / F43-3, F44-6) a reviewer that compacted its context is seen: the compactions its
    # engine reported in the event streams of every turn (Get-CompactionCount) - n > 0 is recorded
    # (ledger `compactions`) and warned about; none reported by a member with a context window
    # (context_tokens) is `unknown` - the installed codex's `exec --json` reports no compaction event,
    # so "none seen" is not "none happened"; otherwise null
    $compactionCount = Get-CompactionCount -Paths @($eventsPath, $retryEventsPath, $continueEventsPath, $(if ($isCodex) { $repairEventsPath } else { $repairEngineEvents }))
    $compactionsRecord = $null
    if ($compactionCount -gt 0) {
        $compactionsRecord = [long]$compactionCount
        $engineWarnings.Add("the reviewer compacted its context $compactionCount time(s) - the reply may rest on a summary of the brief")
    } elseif ($contextTokens -gt 0) { $compactionsRecord = 'unknown' }

    # ------------------------------------------------------------------------- salvage

    # (wave 24, T1) A turn the bridge killed on its timeout - the main turn without a usable
    # continuation, the continuation, a denial retry, a format repair - leaves
    # handoffs/NN-<engine>-<slug>.partial.md (written with the reply file, under the write lock):
    # the reply's header, then per turn every agent message and reasoning text of its event
    # stream in order and its tool calls (Read-TurnSalvage), then the footer "killed at <t> s of
    # <T> s; thread <id> - continue with `<arguments>`". Ledger partial_reply; bridge_outcome is
    # unchanged (a killed main turn stays "failed: timeout ..."); the summary prints the file and
    # the exact resume command.
    $isKilled = { param([string]$Problem) return [bool]($Problem -and $Problem -match '^(timeout after |stopped by the operator)') }
    $continueKilled = [bool]($continueTurn -and (& $isKilled ([string]$continueTurn.Problem)))
    $retryKilled = [bool]($retryTurn -and (& $isKilled ([string]$retryTurn.Problem)))
    $repairKilled = $(if ($isCodex) { & $isKilled ([string]$repairProblem) } else { [bool]($repairTurn -and (& $isKilled ([string]$repairTurn.Problem))) })
    $partialNeeded = [bool](($mainTimedOut -and -not $continued) -or $continueKilled -or $retryKilled -or $repairKilled -or $script:RunKicked)
    # (wave 26b, D15) ANY failed run keeps what its reviewer produced: a provider failure mid-run
    # (a 429 after retries, a 401/403 quota, a network error), a denial, a tree-check failure - when
    # an event stream of the run holds at least one agent message, reasoning text or tool call.
    # Same file, same ledger field; the footer says why the run ended. A stream with no content (a
    # 401 on the first request) leaves nothing.
    $partialOnFailure = $false
    if (-not $partialNeeded -and -not (Test-UsableOutcome $bridgeOutcome)) {
        foreach ($sp in @($eventsPath, $retryEventsPath, $continueEventsPath, $(if ($isCodex) { $repairEventsPath } else { $repairEngineEvents }))) {
            if (-not $sp -or -not (Test-Path -LiteralPath $sp -PathType Leaf)) { continue }
            $sv = Read-TurnSalvage -Engine $engineName -Path $sp
            if (@($sv.Items | Where-Object { $_ }).Count -gt 0 -or @($sv.Tools | Where-Object { $_ }).Count -gt 0) { $partialOnFailure = $true; break }
        }
        if ($partialOnFailure) { $partialNeeded = $true }
    }
    $endedWhy = ConvertTo-OneLine ($bridgeOutcome -replace '^failed:\s*', '')
    if ($endedWhy.Length -gt 200) { $endedWhy = $endedWhy.Substring(0, 200) + '...' }
    $partialRel = ''
    $partialPath = ''
    $partialBody = ''
    $partialFooter = ''
    $resumeCommand = ''
    if ($partialNeeded) {
        $partialName = "$nn-$enginePrefix-$ReplyName.partial.md"
        $partialPath = Join-Path $handoffsDir $partialName
        $partialRel = "handoffs/$partialName"
        $turns = New-Object System.Collections.Generic.List[object]
        $killedAt = New-Object System.Collections.Generic.List[string]
        $mainKickedHere = [bool]($script:RunKicked -and $mainWait -and $mainWait.Reason -eq 'kick')
        $mainNote = $(if ($mainStalled) { "stopped at $wallSeconds s: $StallSec s without an event" } elseif ($mainKickedHere) { "stopped by the operator (-Kick) at $wallSeconds s" } elseif ($mainTimedOut) { "killed at $wallSeconds s of $TimeoutSec s" } elseif ($partialOnFailure) { "it ended at $wallSeconds s: $endedWhy" } else { 'it ended by itself' })
        $turns.Add([pscustomobject]@{ Label = 'Turn 1 - the main turn'; Note = $mainNote; Salvage = (Read-TurnSalvage -Engine $engineName -Path $eventsPath) })
        if ($mainStalled) { $killedAt.Add("$wallSeconds s, $StallSec s without an event (the main turn)") }
        elseif ($mainKickedHere) { $killedAt.Add("$wallSeconds s by the operator (the main turn)") }
        elseif ($mainTimedOut) { $killedAt.Add("$wallSeconds s of $TimeoutSec s (the main turn)") }
        if ($retryTurn) {
            $turns.Add([pscustomobject]@{ Label = "Turn $($turns.Count + 1) - the denial retry"; Note = $(if ($retryKilled) { "killed at $($retryTurn.Wall) s of $retryTimeout s" } elseif ($denialRetryRecord -and $denialRetryRecord.succeeded) { 'it answered' } else { 'it failed' }); Salvage = (Read-TurnSalvage -Engine $engineName -Path $retryEventsPath) })
            if ($retryKilled) { $killedAt.Add("$($retryTurn.Wall) s of $retryTimeout s (the denial retry)") }
        }
        if ($continueTurn) {
            $turns.Add([pscustomobject]@{ Label = "Turn $($turns.Count + 1) - the timeout continuation"; Note = $(if ($continueKilled) { "killed at $($continueTurn.Wall) s of $ContinueSec s" } elseif ($continued) { "it answered in $($continueTurn.Wall) s" } else { "failed: $continueProblem" }); Salvage = (Read-TurnSalvage -Engine $engineName -Path $continueEventsPath) })
            if ($continueKilled) { $killedAt.Add("$($continueTurn.Wall) s of $ContinueSec s (the timeout continuation)") }
        }
        if ($formatRetryRecord) {
            $repairStream = $(if ($isCodex) { $repairEventsPath } else { $repairEngineEvents })
            $turns.Add([pscustomobject]@{ Label = "Turn $($turns.Count + 1) - the format repair"; Note = $(if ($repairKilled) { "killed at $repairWall s of $repairTimeout s" } elseif ($repairedOk) { 'it succeeded' } else { 'it failed' }); Salvage = (Read-TurnSalvage -Engine $engineName -Path $repairStream) })
            if ($repairKilled) { $killedAt.Add("$repairWall s of $repairTimeout s (the format repair)") }
        }
        $partialBody = Format-PartialBody -Turns $turns.ToArray()
        # (wave 24c, F08-4) a continuation reply the checks REJECTED (not a provider failure: the
        # reviewer answered, but not with a review the run can take) is not thrown away: its text
        # follows the turns under its own heading, and timeout_continue.outcome names where it is
        if ($continueRejected -and $continueRejectedText.Trim()) {
            $partialBody = $partialBody.TrimEnd() + "`n`n## continuation reply (rejected: $continueRejectedWhy)`n`n" + ($continueRejectedText.Trim() -replace "`r`n", "`n") + "`n"
            if ($timeoutContinueRecord) { $timeoutContinueRecord.outcome = "$($timeoutContinueRecord.outcome); its text is kept in $partialRel under ""continuation reply (rejected)""" }
        }
        # The thread to resume: the run's verified thread, else the killed turn's own (the
        # continuation's thread, an engine's candidate from its own stream)
        $resumeThread = $(if ($threadId) { $threadId } elseif ($continueThread) { $continueThread } elseif (-not $isCodex -and $threadCandidate) { $threadCandidate } else { '' })
        $killedText = $(if ($killedAt.Count -eq 1) { $killedAt[0] -replace ' \([^)]*\)$', '' } else { $killedAt.ToArray() -join ', ' })
        # (wave 26b, D15) no turn was killed: the footer says why the run ended
        $endedText = $(if ($killedAt.Count -gt 0) { "killed at $killedText" } else { "the run ended: $endedWhy" })
        if ($resumeThread) {
            $resumeParts = New-Object System.Collections.Generic.List[string]
            $resumeParts.Add("-Task $Task")
            if ($CollabDir -ne '.collab') { $resumeParts.Add("-CollabDir $(if ($CollabDir -match '\s') { '"' + $CollabDir + '"' } else { $CollabDir })") }
            $resumeParts.Add("-Mode resume -Thread $resumeThread")
            # without a roster the thread's reviewer must be named (with one, -Thread fixes it)
            if (-not $roster.Exists) {
                $resumeParts.Add("-Provider $($identity.Provider) -Model $($identity.Model)")
                if (-not $isCodex) { $resumeParts.Add("-Engine $engineName") }
            }
            if ($Purpose) { $resumeParts.Add("-Purpose $Purpose") }
            if ($Raw -and $Purpose -ne 'chore') { $resumeParts.Add('-Raw') }
            # (wave 24b, F08-6) every replay-relevant option of the killed run - the same limits,
            # endpoint configuration and review scope (what the purpose resolves again the same
            # way is left out: a timeout from the purpose, the default continuation budget). A
            # value with a character outside [A-Za-z0-9._:/\=+@~-] is double-quoted.
            $qa = { param([string]$V) if ($V -match '^[A-Za-z0-9._:/\\=+@~-]+$') { $V } else { '"' + ($V -replace '"', '\"') + '"' } }
            # (wave 24c, F15-5) the handoff names (-ReplyName, when given - a panel member's is its
            # own "<name>-<provider>") and the preflight decision (-SkipPreflight: a run that started
            # unchecked resumes unchecked instead of being refused by the check it skipped)
            if ($PSBoundParameters.ContainsKey('ReplyName') -or $panelMember) { $resumeParts.Add("-ReplyName $(& $qa $ReplyName)") }
            if ($timeoutSource -eq 'explicit') { $resumeParts.Add("-TimeoutSec $TimeoutSec") }
            if ($ContinueSec -ne [Math]::Min($TimeoutSec, 900)) { $resumeParts.Add("-ContinueSec $ContinueSec") }
            if ($Effort) { $resumeParts.Add("-Effort $Effort") }
            if ($NativeEffort) { $resumeParts.Add("-NativeEffort $(& $qa $NativeEffort)") }
            if ($MaxWords -gt 0) { $resumeParts.Add("-MaxWords $MaxWords") }
            if ($transportOverride) { $resumeParts.Add("-SchemaTransport $transportOverride") }
            $cfgGiven = @(@($CodexConfig) | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
            if ($cfgGiven.Count -gt 0) { $resumeParts.Add("-CodexConfig $(& $qa ($cfgGiven -join ','))") }
            if (@($artifactHashes).Count -gt 0) { $resumeParts.Add("-Artifact $(& $qa ((@($artifactHashes) | ForEach-Object { [string]$_.full }) -join ','))") }
            if ($Range) { $resumeParts.Add("-Range $(& $qa $Range)") }
            if ($isCodex -and $Sandbox -ne 'read-only') { $resumeParts.Add("-Sandbox $Sandbox") }
            if ($MaxModelSteps -gt 0) { $resumeParts.Add("-MaxModelSteps $MaxModelSteps") }
            if ($FormatRetry -eq 0 -and -not $Raw) { $resumeParts.Add('-FormatRetry 0') }
            if ($DenialRetry -eq 0 -and $engineSpec.DenialRetry) { $resumeParts.Add('-DenialRetry 0') }
            if ($OffPeakOnly) { $resumeParts.Add('-OffPeakOnly') }
            if ($SkipPreflight) { $resumeParts.Add('-SkipPreflight') }
            if ($CodexExe) { $resumeParts.Add("-CodexExe $(& $qa $CodexExe)") }
            if ($EngineExe -and -not $isCodex) { $resumeParts.Add("-EngineExe $(& $qa $EngineExe)") }
            $resumeParts.Add('-Prompt "finish your review"')
            $resumeArgs = $resumeParts.ToArray() -join ' '
            $partialFooter = "$endedText; thread $resumeThread - continue with ``$resumeArgs``"
            $resumeCommand = "$(if ($script:LegacyPS) { 'powershell -NoProfile -ExecutionPolicy Bypass' } else { 'pwsh -NoProfile' }) -File ""$PSCommandPath"" $resumeArgs"
        } else {
            $partialFooter = "$endedText; the thread of the $(if ($killedAt.Count -gt 0) { 'killed' } else { 'failed' }) turn is not known - no resume is possible (start again with -Mode new)"
        }
    }

    # ------------------------------------------------------------------------- commit (write lock)

    # 0.4.x wave 21 (D2-D4). The run is over and its reply files (.reply.json, the event
    # stream, a repair's .original.md) are on disk. The rest happens under
    # <task>/.consult.write.lock on stores RE-READ under it (Enter-StoreCommit): this run's
    # findings are ingested into the FRESH findings.json (Add-ReplyFindings - the new ids
    # F<NN>-k are this run's own), the handoff .md is rendered from THAT ingest, then
    # findings.json, then sessions.json (the entry inserted by n), then the record goes - a
    # sibling panel member's commit in between is never lost. The record says `committing`
    # meanwhile. When the write lock cannot be had within 60 s the stores are NOT touched: the
    # record stays `committing`, naming the kept reply files, the run exits non-zero ("commit
    # blocked") and the next run consumes the record like any interrupted reservation (D3).
    $preCommitState = [string]$pendingRecord.state
    $pendingRecord.state = 'committing'
    $pendingRecord.note = 'the run is over; committing under the write lock'
    # The reply this commit is about is named in the record from here on: a commit that never
    # completes - the write lock never had (D3), or the bridge stopped inside it (D4) - leaves a
    # record that says where the reply is (Get-PendingOriginalNote).
    $kept = New-Object System.Collections.Generic.List[string]
    if ($replyJsonRel) {
        $keptJson = Get-RepoRelativePath -Root $repoRoot -Path $replyJsonPath
        if (-not $keptJson) { $keptJson = $replyJsonPath }
        $pendingRecord | Add-Member -NotePropertyName 'reply_json' -NotePropertyValue $keptJson -Force
        $kept.Add($keptJson)
    } elseif ($isCodex -and $continued -and (Test-Path -LiteralPath $continueLastPath -PathType Leaf)) {
        # (wave 24: -Raw after a timeout continuation) the continuation's last message
        $pendingRecord | Add-Member -NotePropertyName 'raw_reply' -NotePropertyValue $continueLastPath -Force
        $kept.Add($continueLastPath)
    } elseif ($isCodex -and (Test-Path -LiteralPath $lastMsgPath -PathType Leaf)) {
        # (-Raw, or a reply that could not be copied) the last message is only in its temp file
        $pendingRecord | Add-Member -NotePropertyName 'raw_reply' -NotePropertyValue $lastMsgPath -Force
        $kept.Add($lastMsgPath)
    }
    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
    $commit = Enter-StoreCommit -TaskDir $taskDir -Task $Task -TimeoutSec (Get-WriteLockTimeout)
    if (-not $commit.Acquired) {
        if ([string](Get-PropertyValue $pendingRecord 'raw_reply' '')) { $keepLastMsg = $true; $keepContinueLast = $true }
        if ([string](Get-PropertyValue $pendingRecord 'events' '')) { $kept.Add([string]$pendingRecord.events) }
        if ([string](Get-PropertyValue $pendingRecord 'original' '')) { $kept.Add([string]$pendingRecord.original) }
        $pendingRecord.note = "commit blocked: $($commit.Message); findings.json and sessions.json were not touched"
        try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
        Write-Summary "codex-consult: commit blocked: $($commit.Message). This run's reply is kept ($(if ($kept.Count -gt 0) { $kept.ToArray() -join ', ' } else { 'nothing to keep' })); no ledger entry was written and the stores were not touched - $pendingPath stays in state committing and the next run consumes it (bridge outcome: $bridgeOutcome)." Red
        Set-DetachedMember -Position $detachMemberPosition -Values @{ state = 'commit_blocked'; outcome = "commit blocked: $($commit.Message)"; wall_seconds = $wallSeconds } -NoSave
        Set-DetachedFinal -Exit 1
        exit 1
    }
    $findingsStore = $commit.Findings
    # How long this commit waited for the write lock (another commit of the task held it) -
    # ledger commit_wait_ms, a console line when it waited at all (F11-3).
    $commitWaitMs = [int]$commit.WaitedMs

    if ($parse -and $parse.Valid) {
        try {
            $ingest = Add-ReplyFindings -Store $findingsStore -Reply $parse.Reply -Nn $nn -ConsultN $consultN `
                -ReplyRel $replyRel -ThreadId $threadId -BaseCommit $revBefore.base_commit `
                -TreeSha256 $revBefore.tree_sha256 -ListedIds $listedIds
            $structured = $true
            $replyBody = $parse.Reply.reply_markdown
            $verdict = $parse.Verdict
            if (-not $parse.VerdictInvalid) { $verdictReason = $parse.Reply.verdict_reason }
            $counts = $ingest.Counts
            $findingIds = @($ingest.NewIds)
            $priorForLedger = @($ingest.PriorEntries | ForEach-Object { [pscustomobject]@{ id = $_.id; status = $_.status } })
            $uncheckedPrior = @($parse.UncheckedPriorBlockers)
        } catch {
            # Never lose the reply over a bridge bug: record it as unprocessable.
            $structured = $false
            $ingest = $null
            $verdict = ''
            $verdictReason = ''
            $replyBody = $rawReply
            $validationError = "bridge could not process the reply: $(ConvertTo-OneLine $_.Exception.Message)"
            $parse = [pscustomobject]@{ Valid = $false; ValidationError = $validationError; Reply = $null; UncheckedPriorBlockers = @() }
        }
    }

    # ------------------------------------------------------------------------- 2. reply file

    $parentLine = 'Parent thread: (none - new thread).'
    if ($parentNote -and -not $parentThread) { $parentLine = "Parent thread: (none - new thread; $parentNote)." }
    if ($parentThread) { $parentLine = "Parent thread: ``$parentThread``." }
    $resultThread = '(unknown)'
    if ($threadId) { $resultThread = "``$threadId``" }
    $threadSourceText = $threadSource
    if ($threadCandidate -and $isCodex) { $threadSourceText += "; unverified rollout candidate ``$threadCandidate`` did not contain this run's consultation id - not used as a thread or a parent" }
    elseif ($threadCandidate) { $threadSourceText += "; conversation ``$threadCandidate`` is not a verified thread of this run - never a parent" }
    $briefLine = 'Brief: (none, prompt only).'
    if ($briefRef) { $briefLine = "Brief: ``$briefRef`` (sha256 $(Format-ShortHash $briefSha))." }
    $treeText = 'tree sha256 none (no git)'
    if ($revBefore.tree_sha256) { $treeText = "tree sha256 $(Format-ShortHash $revBefore.tree_sha256)" }
    $reviewedLine = "Reviewed: $($revBefore.reviewed_revision), base $($revBefore.base_commit), $treeText, $($revBefore.changed_files) changed files"
    if ($artifactHashes.Count -gt 0) {
        $reviewedLine += ', artifacts: ' + (($artifactHashes | ForEach-Object { "$($_.path)=$(Format-ShortHash $_.sha256)" }) -join ', ')
    }
    $reviewedLine += '.'
    $driftLines = New-Object System.Collections.Generic.List[string]
    if ($treeChanged) { $driftLines.Add('WARNING: working tree changed during the review (fingerprint before/after differ).') }
    # (wave 24c) HEAD moved (a commit meanwhile): informational - the tree check compares contents
    if ($revisionMoved) { $driftLines.Add("Note: HEAD moved during the review ($(($revisionMoved -split ' -> ' | ForEach-Object { if ($_ -match '^[0-9a-f]{40}$') { $_.Substring(0, 7) } else { $_ } }) -join ' -> '))$(if (-not $treeChanged) { ' - no file content changed: not a tree change' }).") }
    if ($briefChanged) { $driftLines.Add("WARNING: the brief changed during the review (sha256 $(Format-ShortHash $briefSha) before, $(Format-ShortHash $briefShaAfter) after).") }
    if ($artifactsChanged) { $driftLines.Add("WARNING: artifact(s) changed during the review: $($changedArtifacts -join ', ').") }
    $verdictWarning = ''
    if ($structured) { $verdictWarning = Format-VerdictWarning -Parse $parse }

    $headerLines = New-Object System.Collections.Generic.List[string]
    $headerLines.Add("# Handoff $nn - $($engineSpec.Label): $ReplyName")
    $headerLines.Add('')
    if ($isCodex) { $headerLines.Add("Date: $($startedAt.ToString('yyyy-MM-dd HH:mm', $script:Invariant)) local. Author: Codex (model $modelLabel, effort $effortSent), Codex CLI $codexVersionShort.") }
    else { $headerLines.Add("Date: $($startedAt.ToString('yyyy-MM-dd HH:mm', $script:Invariant)) local. Author: $($engineSpec.Label) (model $modelLabel, effort $(if ($null -eq $effortSent) { 'tier in the model id' } elseif ($effortPlan.Mapping -eq 'native') { "$effortSent (-NativeEffort)" } else { $effortSent })), $harness.") }
    $headerLines.Add($reviewerLine)
    $preflightLine = "Preflight: $preflight."
    if ($preflightWarning) { $preflightLine += " WARNING: $preflightWarning." }
    $headerLines.Add($preflightLine)
    if ($rosterLine) { $headerLines.Add("$rosterLine.") }
    $headerLines.Add("Effort: $(if ($null -eq $effortSent) { 'nothing' } else { $effortSent }) sent (requested $($effortPlan.Requested), mapping $($effortPlan.Mapping), by $($effortPlan.Basis); not confirmed by the provider). Consultation id: $consultId.")
    if ($peakWarning) { $headerLines.Add(($peakWarning -replace 'this consultation runs at', 'this consultation ran at')) }
    foreach ($rl in $recoveredLines) { $headerLines.Add("Recovery record: $rl") }
    $headerLines.Add("Invocation: ``codex-consult.ps1`` (mode: $Mode, sandbox: $sandboxRecord, purpose: $purposeLabel). Argv: ``$commandStr`` ($($engineSpec.PromptVia)).")
    $headerLines.Add("$parentLine Result thread: $resultThread (source: $threadSourceText).")
    $headerLines.Add("$briefLine $reviewedLine")
    foreach ($d in $driftLines) { $headerLines.Add($d) }
    $headerLines.Add("Bridge outcome: $bridgeOutcome. Wall time: $wallSeconds s. Tokens: $(if (-not $engineSpec.HasUsage) { "not reported by $engineName" } else { Format-Usage $usage }).")
    if ($engineRunRecord) { $headerLines.Add("Engine turns: $($engineRunRecord.turns)$(if ($engineName -eq 'muse') { ' (each one a Muse Code subscription prompt)' })$(if ($engineName -eq 'claude') { " (claude -p, auth $engineAuth$(if ($engineRunRecord.model_resolved) { "; model $($engineRunRecord.model_resolved)" }); init tools $(if (@($engineRunRecord.init_tools).Count -gt 0) { @($engineRunRecord.init_tools) -join ', ' } else { '(none seen)' }); permission denials $($engineRunRecord.permission_denials))" })$(if ($null -ne $engineRunRecord.max_model_steps) { "; $(if ($engineSpec.StepsFlag) { $engineSpec.StepsFlag } else { '--max-model-steps' }) $($engineRunRecord.max_model_steps)" })$(if ($null -ne $engineRunRecord.msp_schema_version) { "; MSP schema_version $($engineRunRecord.msp_schema_version)" }).") }
    if ($engineWarnings.Count -gt 0) { $headerLines.Add("Warnings: $(($engineWarnings.ToArray() | ForEach-Object { ConvertTo-OneLine $_ }) -join '; ').") }
    if ($denialRetryRecord) {
        if ($denialRetryRecord.succeeded) { $headerLines.Add("Denial retry: succeeded in $($denialRetryRecord.wall_seconds) s - the first turn produced nothing (a tool was auto-denied); one more turn on conversation ``$threadId`` answered without it. Tokens of that turn: $(Format-Usage $denialRetryRecord.usage).") }
        else { $headerLines.Add("Denial retry: failed in $($denialRetryRecord.wall_seconds) s - the first turn produced nothing (a tool was auto-denied) and the retry turn on conversation ``$threadId`` did not produce a usable reply.") }
    }
    # (wave 24) the timeout: what applied, the continuation, the salvaged partial reply
    $timeoutHeader = "Timeout: $TimeoutSec s ($(Format-TimeoutSource -Source $timeoutSource -PurposeLabel $purposeLabel)); continuation after a timeout kill: $(if ($ContinueSec -gt 0) { "up to $ContinueSec s" } else { 'off (-ContinueSec 0)' })."
    if ($rangeStat) { $timeoutHeader += " Range: ``$Range`` - $rangeText ($($rangeStat.Insertions) insertions, $($rangeStat.Deletions) deletions)." }
    $headerLines.Add($timeoutHeader)
    if ($timeoutContinueRecord) {
        if ($continued) { $headerLines.Add("Timeout continuation: the main turn was killed at $wallSeconds s of $TimeoutSec s; one continuation turn on thread ``$continueThread`` answered in $($timeoutContinueRecord.wall_seconds) s. Tokens of that turn: $(if (-not $engineSpec.HasUsage) { "not reported by $engineName" } else { Format-Usage $timeoutContinueRecord.usage }).") }
        else {
            $contHeader = "Timeout continuation: $($timeoutContinueRecord.outcome)"
            if ($continueTurn) { $contHeader += " (in $($timeoutContinueRecord.wall_seconds) s)" }
            if ($continueThread) { $contHeader += " - thread ``$continueThread``" }
            $headerLines.Add("$contHeader.")
        }
    }
    if ($partialNeeded) { $headerLines.Add("Partial reply: ``$partialRel`` - $partialFooter.") }
    if ($providerFailure) {
        $codeText = ''
        if ($providerFailure.code) { $codeText = " ($($providerFailure.code))" }
        $headerLines.Add("Provider failure: $($providerFailure.class)$codeText - $($providerFailure.message).$(if ($failureHint) { " Hint: $failureHint." })")
    }
    if ($parse) {
        $statusLine = Format-StructuredStatusLine -Parse $parse -Ingest $ingest -ReplyJsonRel $replyJsonRel
        if ($schemaTransport -eq 'prompt-only') {
            if ($statusLine.Contains('Structured reply')) { $statusLine = $statusLine.Replace('Structured reply', 'Structured reply (prompt-only transport)') }
            else { $statusLine += ' (prompt-only transport)' }
        }
        $headerLines.Add($statusLine)
    }
    if ($verdictWarning) { $headerLines.Add($verdictWarning) }
    if ($formatRetryRecord) {
        $driftText = if (@($formatRetryRecord.drift).Count -gt 0) { "$(@($formatRetryRecord.drift).Count) note(s): $(@($formatRetryRecord.drift) -join '; ')" } else { 'none' }
        if ($repairedOk) {
            $headerLines.Add("Format repair: succeeded in $($formatRetryRecord.wall_seconds) s - the first reply was prose ($(ConvertTo-OneLine $formatRetryRecord.reason)); one repair turn resumed thread ``$threadId`` and converted it. Drift: $driftText. The original prose follows the structured section and is kept as ``$($formatRetryRecord.original)``.")
        } else {
            $headerLines.Add("Format repair: failed in $($formatRetryRecord.wall_seconds) s - the first reply was prose ($(ConvertTo-OneLine $formatRetryRecord.reason)) and the repair turn did not produce a valid object; the prose is kept below (also ``$($formatRetryRecord.original)``).")
        }
    }
    $furtherTurns = ''
    if ($extraEvents.Count -gt 0) { $furtherTurns = '; further turns: ' + (($extraEvents.ToArray() | ForEach-Object { '`' + $_ + '`' }) -join ', ') }
    $headerLines.Add("Raw event stream: ``$eventsRel``$furtherTurns.")
    $headerLines.Add('Verbatim reply follows.')
    $headerLines.Add('')
    $headerLines.Add('---')
    $headerLines.Add('')
    $header = $headerLines.ToArray() -join "`n"

    $body = $replyBody
    if (-not $rawReply) {
        $body = "_(no reply captured)_"
        if ($partialNeeded) { $body = "_(no reply captured - what the killed turn(s) produced is salvaged in ``$partialRel``)_" }
        if ($eventError) {
            $body += "`n`n$($engineSpec.Label) reported: $eventError"
        }
        if ($stderrText.Trim()) {
            $body += "`n`n```````n" + $stderrText.Trim() + "`n``````"
        }
    } elseif (-not $body) {
        $body = '_(empty reply_markdown)_'
    }
    $section = ''
    if ($structured) { $section = Format-StructuredSection -Parse $parse -Ingest $ingest -ReviewerLabel $engineSpec.Label }
    $replyText = $header + "`n" + ($body -replace "`r`n", "`n") + "`n"
    if ($section) { $replyText += "`n---`n`n" + ($section -replace "`r`n", "`n") + "`n" }
    if ($repairedOk) { $replyText += "`n---`n`n## Original reply (prose, before format repair)`n`n" + ($originalProse -replace "`r`n", "`n") + "`n" }
    Write-Utf8NoBom -Path $replyPath -Text $replyText
    # (wave 24) the salvaged partial reply: the same header, then what the turns produced
    if ($partialNeeded) {
        $pHeader = New-Object System.Collections.Generic.List[string]
        $pHeader.Add("# Handoff $nn - $($engineSpec.Label): $ReplyName - partial reply (a turn was killed on its timeout)")
        for ($hi = 1; $hi -lt $headerLines.Count; $hi++) {
            if ($headerLines[$hi] -eq 'Verbatim reply follows.') { break }
            $pHeader.Add($headerLines[$hi])
        }
        $pHeader.Add('What the reviewer produced before the kill follows (every agent message and reasoning text of each turn''s event stream, in order, then its tool calls).')
        $partialText = (($pHeader.ToArray() -join "`n").TrimEnd()) + "`n`n---`n`n" + $partialBody.TrimEnd() + "`n`n---`n`n" + $partialFooter + "`n"
        Write-Utf8NoBom -Path $partialPath -Text $partialText
    }

    # ------------------------------------------------------------------------- 3. findings.json

    if ($ingest -and $ingest.Changed) {
        Complete-StoreCommit -Commit $commit -Findings
    }
    # TEST HOOK: CODEX_CONSULT_TEST_COMMIT_PAUSE_MS=<ms> | <model>=<ms>[|...] - a pause inside
    # the commit, between findings.json and sessions.json (the ORPHAN window a kill can hit;
    # write-lock contention); a map pauses only the runs of that model.
    $commitPause = Get-TestHookMs -Value ((Get-TestHookValue 'CODEX_CONSULT_TEST_COMMIT_PAUSE_MS')) -Model ([string]$identity.Model)
    if ($commitPause -gt 0) { Start-Sleep -Milliseconds $commitPause }

    # ------------------------------------------------------------------------- 4. sessions.json

    # `model` holds the resolved model and `effort` the value sent (= effort_sent): the
    # 0.2 fields keep their meaning for older readers and codex-findings.ps1 -Stats.
    $entry = [pscustomobject]@{
        n                               = $consultN
        when                            = (Get-IsoTimestamp $startedAt)
        purpose                         = $Purpose
        topics                          = [object[]]@($topicList)
        role                            = $(if ($roleInfo) { $roleInfo.Name } else { '' })
        consult_id                      = $consultId
        reviewer                        = $reviewerRecord
        lineage                         = $lineage
        coordinator                     = $coordinatorRecord
        preflight                       = $preflight
        preflight_warning               = $preflightWarning
        roster                          = $rosterRecord
        panel                           = $panelRecord
        parent_thread                   = $parentThread
        thread                          = $threadId
        thread_source                   = $threadSource
        thread_candidate                = $threadCandidate
        mode                            = $Mode
        mode_fallback                   = $modeFallbackRecord
        command                         = $commandStr
        child_env_scrubbed              = [object[]]@($childEnvScrubbed)
        brief                           = $briefRef
        range                           = $rangeRecord
        prompt_chars                    = $promptText.Length
        reply                           = $replyRel
        reply_json                      = $replyJsonRel
        events                          = $eventsRel
        partial_reply                   = $partialRel
        model                           = $modelLabel
        effort                          = $effortSent
        effort_requested                = $effortPlan.Requested
        effort_sent                     = $effortSent
        effort_mapping                  = $effortPlan.Mapping
        effort_caps                     = $effortPlan.Caps
        effort_confirmed                = $null
        max_words                       = $maxWordsResolved
        sandbox                         = $sandboxRecord
        timeout_sec                     = $TimeoutSec
        timeout_source                  = $timeoutSource
        continue_sec                    = $ContinueSec
        extra_config                    = [object[]]$extraConfig.ToArray()
        extra_config_source             = $extraConfigSource
        context_window                  = $contextWindowRecord
        peak                            = $peak.Peak
        peak_schedule                   = $peak.Schedule
        peak_source                     = $peak.Source
        peak_evaluated_at               = $peak.EvaluatedAt
        structured                      = $structured
        schema                          = $(if ($Raw) { '' } else { 'consult-reply v1' })
        schema_transport                = $schemaTransport
        schema_transport_source         = $schemaTransportSource
        validation_error                = $validationError
        format_retry                    = $formatRetryRecord
        denial_retry                    = $denialRetryRecord
        timeout_continue                = $timeoutContinueRecord
        stall                           = $stallRecord
        kill_confirmed                  = $killConfirmedRecord
        base_commit                     = $revBefore.base_commit
        reviewed_revision               = $revBefore.reviewed_revision
        tree_sha256                     = $revBefore.tree_sha256
        tree_sha256_after               = $revAfter.tree_sha256
        tree_changed_during_review      = $treeChanged
        revision_moved                  = $(if ($revisionMoved) { $revisionMoved } else { $null })
        changed_files                   = $revBefore.changed_files
        brief_sha256                    = $briefSha
        brief_sha256_after              = $briefShaAfter
        brief_changed_during_review     = $briefChanged
        fingerprint_note                = $revBefore.fingerprint_note
        artifacts                       = [object[]]$artifactsFinal
        artifacts_changed_during_review = $artifactsChanged
        tree_check                      = $treeCheckRecord
        bridge_outcome                  = $bridgeOutcome
        provider_failure                = $providerFailure
        warnings                        = [object[]]$engineWarnings.ToArray()
        verdict                         = $verdict
        verdict_reason                  = $verdictReason
        findings                        = [pscustomobject]@{ blocker = $counts.blocker; major = $counts.major; minor = $counts.minor; note = $counts.note }
        finding_ids                     = [object[]]$findingIds
        prior_findings                  = [object[]]$priorForLedger
        unchecked_prior_blockers        = [object[]]$uncheckedPrior
        usage                           = $usage
        compactions                     = $compactionsRecord
        engine_run                      = $engineRunRecord
        wall_seconds                    = $wallSeconds
        finished_at                     = (Get-IsoTimestamp)
        commit_wait_ms                  = $commitWaitMs
    }
    # The FRESH ledger (re-read under the write lock): created when absent, the entry
    # inserted at its place by n (a panel member that finishes first still lands after the
    # lower-n members' entries; D10).
    $ledger = $commit.Sessions
    if ($null -eq $ledger) {
        $ledger = [pscustomobject]@{
            task_id = $Task
            cwd     = $repoRoot
            codex   = [pscustomobject]@{
                tool     = $(if ($isCodex) { $codexVersion } else { $harness })
                consults = [object[]]@()
            }
        }
    }
    if (-not $ledger.PSObject.Properties['codex']) {
        $ledger | Add-Member -NotePropertyName 'codex' -NotePropertyValue ([pscustomobject]@{ tool = $(if ($isCodex) { $codexVersion } else { $harness }); consults = [object[]]@() })
    }
    if (-not $ledger.codex.PSObject.Properties['consults']) {
        $ledger.codex | Add-Member -NotePropertyName 'consults' -NotePropertyValue ([object[]]@())
    }
    # (`tool` is the codex version; an agy run leaves it as it is)
    if ($isCodex) { $ledger.codex.tool = $codexVersion }
    # (wave 26c, D2) the machine-wide health update that failed before the commit - (wave 28b, D13 /
    # F36-6, F37-1) its record goes into the JOURNAL beside the health file now, inside the write lock
    # (a local append: no wait for the health lock, so the hold on this task's lock does not grow);
    # this entry's warning says a retry follows the commit; the retry after the lock is released - or
    # the next run of any repository, should this one die first - applies the journal and empties it
    $machineHealthAfterLock = $false
    $machineHealthJournalWhy = ''
    if ($machineHealthRetry) {
        $machineHealthJournalWhy = Add-MachineHealthJournal -Record $machineHealthRecord
        $engineWarnings.Add("machine-wide health not updated at the commit ($machineHealthCause); $(if ($machineHealthJournalWhy) { "the journal could not be written ($machineHealthJournalWhy); " } else { 'the record is kept in the journal; ' })a retry follows the commit")
        $entry.warnings = [object[]]$engineWarnings.ToArray()
        $machineHealthAfterLock = $true
    }
    # (wave 28b, D6 / F35-1, F36-8, F37-6) telemetry on: the event of THIS entry (the allowlist;
    # warnings[] is not part of it) goes into the spool now, inside the write lock - (wave 28c, D7 /
    # F43-4) with a wait of at most 1 s (the telemetry lock and the spool file together), so the hold
    # on this task's lock grows by 1 s at most; a failure is retried for up to 5 s AFTER the lock is
    # released (below), and only then warned about and counted
    $telemetryLine = ''
    $telemetryFirst = $null
    if ($telemetrySwitch.On) {
        $telemetryFirst = Add-TelemetryEvent -Entry $entry -Switch $telemetrySwitch -WaitMs 1000
        if (-not $telemetryFirst.Why) { $telemetryFirst = $null }
    }
    Add-LedgerEntry -Sessions $ledger -Entry $entry
    $commit.Sessions = $ledger
    Complete-StoreCommit -Commit $commit -Sessions

    # (7) The ledger is committed and codex is known to be gone: the recovery record
    # has nothing left to protect (still under the write lock). Kept after a failed
    # registration ('launching') or with timeout survivors - in that state again.
    $pendingNote = ''
    if ($keepPending) {
        $pendingRecord.state = $preCommitState
        $pendingRecord.note = ''
        # The ledger now holds this run's entry: the saved prose / reply is no longer orphaned.
        if ($pendingRecord.PSObject.Properties['original']) { $pendingRecord.original = ''; $pendingRecord.first_reply = '' }
        if ($pendingRecord.PSObject.Properties['reply_json']) { $pendingRecord.reply_json = '' }
        if ($pendingRecord.PSObject.Properties['raw_reply']) { $pendingRecord.raw_reply = '' }
        $pendingRecord.events = ''
        try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
        $pendingNote = "recovery record kept: $pendingPath (state '$($pendingRecord.state)')"
    } else {
        $rmError = Remove-PendingFile -Path $pendingPath
        if ($rmError) { $pendingNote = "could not remove $pendingPath ($rmError); the next run will find codex gone and consume it" }
    }
    Exit-StoreCommit -Commit $commit
    # (wave 27c, D8) the full retry of the machine-wide health, outside the write lock - (wave 28b,
    # D13) it applies the journal (this run's record and any other) and empties it; its OUTCOME, either
    # way, is in the summary (the console, and a detached run's status record)
    $machineHealthLine = ''
    if ($machineHealthAfterLock) {
        if (Add-MachineHealthRecord -Fingerprint ([string]$identity.Fingerprint) -Outcome $bridgeOutcome -Failure $providerFailure -Repo $repoRoot -Record $machineHealthRecord) {
            $machineHealthLine = 'health     : machine-wide health updated by the retry after the commit (the journal applied)'
        } else {
            $machineHealthLine = "warning    : machine-wide health not updated by the retry after the commit ($(if ([string]$script:MachineHealthLastError) { [string]$script:MachineHealthLastError } else { $machineHealthCause }))$(if (-not $machineHealthJournalWhy) { " - the record waits in $(Get-MachineHealthJournalPath) for the next run" })"
        }
    }
    # (wave 26b, D13) the machine-wide health: this run leaves running[] (its outcome went in before
    # the ledger - wave 26c, D2). Optional: a file that cannot be written is left as it is.
    $null = Unregister-MachineRunning
    # (wave 28c, D10) the journal's unreadable lines found by the updates after the commit: the summary
    $healthJournalLines = @(foreach ($hn in (Get-MachineHealthJournalNotes)) { if ($hn) { "warning    : $hn" } })
    # (wave 28c, D7 / F43-4) the event that did not go into the spool at the commit: once more, with up
    # to 5 s, now that the write lock is released - only a failure of this attempt (or an event that
    # met a running -Forget, which is dropped at once - D3) is warned about (the console, a detached
    # run's status record) and counted as not spooled (codex-telemetry.ps1 -Status)
    if ($telemetryFirst) {
        if ($telemetryFirst.Forgetting) {
            # (wave 28e, E2) a count that could not be written is said too
            $nsWhy = ''
            try { $nsWhy = [string](Add-TelemetryNotSpooled -Why $telemetryFirst.Why) } catch { $nsWhy = ConvertTo-OneLine $_.Exception.Message }
            $telemetryLine = "warning    : telemetry event not spooled ($($telemetryFirst.Why)) - dropped$(if ($nsWhy) { "; $nsWhy" })"
        } else {
            $telemetryRetry = Add-TelemetryEvent -Entry $entry -Switch $telemetrySwitch -WaitMs $script:TelemetrySpoolWaitMs -Count
            if ($telemetryRetry.Why) { $telemetryLine = "warning    : telemetry event not spooled ($($telemetryRetry.Why)) - at the commit ($($telemetryFirst.Why)) and for $([Math]::Round($script:TelemetrySpoolWaitMs / 1000.0, 1)) s after it" }
        }
    }
    # (wave 28, R17) telemetry on: the event went into the spool at the commit (wave 28b, D6); now the
    # detached sender starts (not waited for) - a panel member leaves the sender to its panel run, a
    # run that keeps its recovery record (survivors, a failed registration) starts none (the next
    # run's sender delivers), and so does a run whose event was not spooled. Never fails the run.
    if ($telemetrySwitch.On -and -not $telemetryLine -and -not ($panelMember -or $keepPending)) {
        $senderWhy = Start-TelemetrySender
        if ($senderWhy) { Write-Verbose "telemetry: the sender did not start ($senderWhy)" }
    }

    # ------------------------------------------------------------------------- output

    # (wave 28b, D10) test mode never goes unnoticed: said with the run's output (and in warnings[])
    if (Test-TestMode) { Write-Host "WARNING: $($script:TestModeWarning)" -ForegroundColor Yellow }

    $commitWaitLine = ''
    if ($commitWaitMs -gt 0) { $commitWaitLine = "write lock : waited $commitWaitMs ms for another commit of this task" }
    # (wave 24) the timeout continuation and the salvaged partial reply, with the exact command
    # that resumes the killed thread
    $continueLine = ''
    if ($timeoutContinueRecord) {
        if ($continued) { $continueLine = "continued  : the main turn was killed at $wallSeconds s of $TimeoutSec s; one continuation turn on thread $continueThread answered in $($timeoutContinueRecord.wall_seconds) s" }
        else { $continueLine = "continued  : $($timeoutContinueRecord.outcome)$(if ($continueTurn) { " (in $($timeoutContinueRecord.wall_seconds) s)" })$(if ($continueThread) { " - thread $continueThread" })" }
    }
    $partialLines = @()
    if ($partialNeeded) {
        $partialLines += "partial    : $partialPath ($partialFooter)"
        $partialLines += $(if ($resumeCommand) { "resume     : $resumeCommand" } else { 'resume     : not possible - the thread of the killed turn is not known (start again with -Mode new)' })
    }
    # (wave 25) the summary block (Write-Summary): printed, and - a detached run - its status file's
    # `summary`, with the member's final state (D3, D11)
    if (-not (Test-UsableOutcome $bridgeOutcome)) {
        Write-Summary "codex-consult: $bridgeOutcome (wall $wallSeconds s)" Red
        if ($modeFallbackRecord) { Write-Summary "mode       : $($modeFallbackRecord.from) -> new ($($modeFallbackRecord.reason))" Yellow }
        # (wave 24b) the next step for a failure the bridge can explain (a context-window limit)
        if ($failureHint) { Write-Summary "hint       : $failureHint" Yellow }
        if ($continueLine) { Write-Summary $continueLine Yellow }
        foreach ($pl in $partialLines) { Write-Summary $pl Yellow }
        if ($pendingNote) { Write-Summary "pending    : $pendingNote" Yellow }
        if ($commitWaitLine) { Write-Summary $commitWaitLine }
        if ($machineHealthLine) { Write-Summary $machineHealthLine Yellow }
        foreach ($hl in $healthJournalLines) { Write-Summary $hl Yellow }
        if ($telemetryLine) { Write-Summary $telemetryLine Yellow }
        foreach ($d in $driftLines) { Write-Summary $d Yellow }
        Write-Summary "reply file : $replyPath"
        if ($replyJsonRel) { Write-Summary "reply json : $replyJsonPath" }
        Write-Summary "events file: $eventsPath"
        foreach ($w in $engineWarnings) { Write-Summary "warning    : $w" Yellow }
        if ($stderrText.Trim()) {
            Write-Summary "--- $engineCmd stderr (tail) ---"
            Write-Summary (($stderrText.Trim() -split "`r?`n" | Select-Object -Last 20) -join "`n")
        }
        Set-DetachedMember -Position $detachMemberPosition -Values @{ state = 'failed'; outcome = $bridgeOutcome; wall_seconds = $wallSeconds } -NoSave
        Set-DetachedFinal -Exit 1
        exit 1
    }

    Write-Summary "codex-consult: $bridgeOutcome - $lineageShown, mode $Mode, thread $threadId (source: $threadSource), wall $wallSeconds s"
    if ($modeFallbackRecord) { Write-Summary "mode       : $($modeFallbackRecord.from) -> new ($($modeFallbackRecord.reason))" Yellow }
    if ($continueLine) { Write-Summary $continueLine Yellow }
    foreach ($pl in $partialLines) { Write-Summary $pl Yellow }
    foreach ($w in $engineWarnings) { Write-Summary "warning    : $w" Yellow }
    if ($denialRetryRecord) { Write-Summary "denial retry: $(if ($denialRetryRecord.succeeded) { 'succeeded' } else { 'failed' }) in $($denialRetryRecord.wall_seconds) s" Yellow }
    if ($repairConsole) {
        Write-Summary $repairConsole $(if ($repairedOk -and @($formatRetryRecord.drift).Count -eq 0) { 'Gray' } else { 'Yellow' })
        foreach ($dn in @($formatRetryRecord.drift)) { Write-Summary "  drift: $dn" Yellow }
    }
    if ($threadCandidate -and $isCodex) { Write-Summary "thread     : unknown - rollout candidate $threadCandidate did not contain consultation id $consultId (not used as a thread or a parent)" Yellow }
    if (-not $identity.Resolved) { Write-Summary "reviewer   : identity unresolved ($($identity.Note)); this thread is never a parent" Yellow }
    if ($peakWarning) { Write-Summary $peakWarning Yellow }
    if ($parse) {
        if ($structured) {
            if ($parse.VerdictInvalid) { Write-Summary "verdict    : (invalid: $validationError)" Yellow }
            else { Write-Summary "verdict    : $verdict - $(ConvertTo-OneLine $verdictReason)" }
            if ($verdictWarning) { Write-Summary $verdictWarning Yellow }
            if ($findingIds.Count -gt 0) { Write-Summary "findings   : $(Format-SeverityCounts $counts) -> $(Format-IdRange $findingIds) in findings.json" }
            else { Write-Summary "findings   : none" }
            if (@($ingest.PriorEntries).Count -gt 0) {
                Write-Summary ("prior      : " + ((@($ingest.PriorEntries) | ForEach-Object { "$($_.id) $($_.status)" }) -join ', '))
            }
            if (@($ingest.UnknownIds).Count -gt 0) {
                Write-Summary "unknown ids: $(@($ingest.UnknownIds) -join ', ') (not in findings.json; ignored)" Yellow
            }
            if (@($ingest.UnknownSupersedes).Count -gt 0) {
                Write-Summary "supersedes : $(@($ingest.UnknownSupersedes) -join ', ') not in findings.json (kept on the new finding only)" Yellow
            }
        } else {
            Write-Summary "structured : INVALID ($validationError) - raw text kept; no findings recorded" Yellow
        }
    }
    if ($pendingNote) { Write-Summary "pending    : $pendingNote" Yellow }
    if ($commitWaitLine) { Write-Summary $commitWaitLine }
    if ($machineHealthLine) { Write-Summary $machineHealthLine Yellow }
    foreach ($hl in $healthJournalLines) { Write-Summary $hl Yellow }
    if ($telemetryLine) { Write-Summary $telemetryLine Yellow }
    foreach ($d in $driftLines) { Write-Summary $d Yellow }
    Write-Summary "reply file : $replyPath"
    if ($replyJsonRel) { Write-Summary "reply json : $replyJsonPath" }
    Write-Summary "events file: $eventsPath"
    Set-DetachedMember -Position $detachMemberPosition -Values @{ state = 'usable'; outcome = $bridgeOutcome; wall_seconds = $wallSeconds } -NoSave
    Set-DetachedFinal -Exit 0
    Write-Host ""
    Write-Host $replyBody
    if ($section) {
        Write-Host ""
        Write-Host $section
    }
    exit 0
} finally {
    foreach ($tmp in @($promptPath, $stderrPath, $repairLastPath, $repairEventsPath, $repairStderrPath, $repairPromptPath, $denialPromptPath, $denialStderrPath, $engineStdinPath, $continuePromptPath, $continueStderrPath)) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
    if (-not $keepContinueLast -and $continueLastPath -and (Test-Path -LiteralPath $continueLastPath)) {
        Remove-Item -LiteralPath $continueLastPath -Force -ErrorAction SilentlyContinue
    }
    if (-not $keepLastMsg -and (Test-Path -LiteralPath $lastMsgPath)) {
        Remove-Item -LiteralPath $lastMsgPath -Force -ErrorAction SilentlyContinue
    }
    Exit-StoreCommit -Commit $commit
    # (wave 26b, D13) whatever happened, this run no longer runs on its endpoint
    if (-not $DryRun) { $null = Unregister-MachineRunning }
    Exit-TaskLock -Lock $lock
}
