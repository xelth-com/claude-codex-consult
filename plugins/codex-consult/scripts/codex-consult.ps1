<#
.SYNOPSIS
    Consult OpenAI Codex from Claude Code and record the consultation as files.

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
    otherwise the run is refused; -SkipPreflight bypasses it. A usage-limit failure
    WITHOUT a reset time within the last hour only warns. Failed runs record a
    classified provider_failure (auth | quota | capability | transport | unknown,
    plus retry_after; a failure stamped in the future counts as now). The endpoint
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
    "always"|"weighty"} in the JSON file CODEX_CONSULT_ROSTER names (it must exist -
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
        is available runs (a usage limit without a reset time <= 60 min old is
        skipped here); every skipped entry is recorded with its reason; none
        available = refused, nothing started. -Model without -Provider restricts the
        walk to the entries of that model; -SkipPreflight takes the first entry. The
        parent thread is then chosen for the SELECTED lineage as always.
    Ledger: roster {path, position, skipped[{provider, model, reason}], applied[]}
    after preflight_warning ($null without a roster); one line "Roster: ..." on the
    console, in the dry run and in the handoff header.
    -Panel (-PanelAll: "weighty" entries too, whatever the purpose) sends the same
    brief to EVERY available roster entry, each a consultation of its own (own
    preflight, recovery record .consult.pending-<NN>.json, parent thread, consultation
    id, handoffs/NN-codex-<ReplyName>-<provider>.md and ledger entry with panel {id,
    position, of, members[{provider, model, state run|skipped, reason}], concurrency,
    limits}). 0.4.x wave 21 (ROADMAP R11): the members run IN PARALLEL as processes
    of their own - members of different endpoints at once, of one endpoint (one
    provider label, or labels that resolve to one provider fingerprint) one after
    another unless the roster's top-level "parallel" raises it; -PanelConcurrency
    caps the total (0 none, 1 strictly one after another). The -Panel run holds the
    task lock for the whole panel, judges every recovery record of the task first,
    assigns n and NN to every member up front in roster order and writes each
    member's `reserved` record before any member starts; a member accepts its spec
    only when that record names its panel, n, NN and parent, rewrites it with its
    own pid and only then checks that the parent lives (a parent gone: the member
    withdraws the record and stops, nothing started), and commits under the write lock
    (.consult.write.lock: re-read the stores, apply its own delta - the ledger stays
    sorted by n). A "weighty" entry joins only on framing, decision, core-contract,
    acceptance and stuck. Every member is shown the findings open when the panel
    started. A failing member does not stop the others; with -PanelConcurrency 1 a
    member that leaves surviving processes stops the remaining ones (summary:
    "skipped  not started: ..."). A summary block closes the run; exit 0 only when
    every member produced a usable reply. Not with -Provider, -Thread or -Mode
    resume. TEST HOOKS: CODEX_CONSULT_TEST_SURVIVORS=<pid> makes a timeout kill
    report that live pid as a survivor; CODEX_CONSULT_TEST_WRITE_LOCK_SEC=<s>
    shortens the 60 s write-lock wait; CODEX_CONSULT_TEST_COMMIT_PAUSE_MS=<ms> (or
    <model>=<ms>[|...]: the runs of that model only) pauses a commit between
    findings.json and sessions.json; CODEX_CONSULT_TEST_PANEL_GUARD_SEC=<s> replaces a
    panel member's kill guard; CODEX_CONSULT_TEST_MEMBER_PAUSE_MS=<ms> pauses a panel
    member between the rewrite of its record and the check of its parent.

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
    (that reason stays in the provider failure's message).

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
#>
[CmdletBinding()]
param(
    # Task id -> <CollabDir>/<Task>/ . Groups one conversation's briefs, replies and ledger.
    [Parameter(Mandatory = $true)]
    [string]$Task,

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

    # Hard wall-clock limit; the codex process tree is killed when it is exceeded.
    [int]$TimeoutSec = 900,

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

    # Review panel: the same brief goes to EVERY available reviewer of the roster, each as a
    # consultation of its own in a process of its own (own preflight, recovery record,
    # parent thread, handoff files handoffs/NN-codex-<ReplyName>-<provider>.md and ledger
    # entry with a `panel` record); members of different endpoints run at once (see
    # -PanelConcurrency). Needs a roster; not with -Provider, -Thread or -Mode resume. A
    # "weighty" roster entry joins only on framing, decision, core-contract, acceptance and
    # stuck. Exit 0 only when every member produced a usable reply.
    [switch]$Panel,

    # -Panel with every available entry, "weighty" ones included whatever the purpose.
    [switch]$PanelAll,

    # INTERNAL: set by -Panel for each member run (the member and the panel's parameters,
    # base64 of UTF-8 JSON). Never pass it yourself.
    [string]$PanelSpec = '',

    # -Panel only: how many members may run at the same time, on top of the per-endpoint plan
    # (the members of one endpoint run one after another unless the roster's "parallel" raises
    # it). 0 (the default) = no cap; 1 = strictly one after another in roster order (a member
    # that leaves surviving processes then stops the rest); k = at most k at a time.
    [int]$PanelConcurrency = 0,

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
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

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
    $days = @($StartedAt, (Get-Date)) | ForEach-Object {
        Join-Path (Join-Path (Join-Path $root ('{0:yyyy}' -f $_)) ('{0:MM}' -f $_)) ('{0:dd}' -f $_)
    } | Select-Object -Unique
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

# One more turn of a non-codex engine (the denial retry, the format repair) under the SAME
# task lock and recovery record as the run: the record goes launching -> running (child pid,
# start time, `events` = this turn's event stream) before the process is waited on; a timeout
# kills the process tree, and survivors are recorded (state survivors) and keep the record.
# -PromptPath / -PromptText (wave 23, D1): the turn's own prompt file, written first (muse
# names it in its argv; its stdin is then empty). Right before the start the engine's launch
# invariant (D4) and the .cmd %-hazard (F02-14) are checked again: a refusal starts nothing.
# Reads the run's $pendingRecord, $pendingPath, $engineLauncher, $engineName and $repoRoot.
# { Exit (-1 unless it exited); Problem ('' or why the turn did not complete); Wall;
# KeepPending; Stderr (UTF-8 text); Started (a process was started: one more engine turn -
# for muse one more subscription prompt) }.
function Invoke-EngineTurn {
    param([string[]]$Argv, [string]$StdinText, [string]$EventsPath, [string]$StdinPath, [string]$StderrPath, [int]$Timeout, [string]$Note, [string]$PromptPath = '', [string]$PromptText = '')
    $t = [pscustomobject]@{ Exit = -1; Problem = ''; Wall = 0; KeepPending = $false; Stderr = ''; Started = $false }
    if ($PromptPath) { Write-Utf8NoBom -Path $PromptPath -Text $PromptText }
    Write-Utf8NoBom -Path $StdinPath -Text $StdinText
    $refusal = Get-EngineLaunchBlock -Engine $engineName
    if (-not $refusal) { $refusal = Get-CmdArgvHazard -Launcher $engineLauncher -Argv $Argv }
    if ($refusal) {
        $t.Problem = "refused before launch: $refusal"
        return $t
    }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $pendingRecord.state = 'launching'
    $pendingRecord.note = "$Note being started; its pid is not recorded yet"
    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
        $t.Problem = "could not write the recovery record ($(ConvertTo-OneLine $_.Exception.Message)); the turn was not started"
        return $t
    }
    $proc = $null
    try {
        $proc = Start-Process -FilePath $engineLauncher -ArgumentList ((($Argv | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' ')) `
            -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
            -RedirectStandardOutput $EventsPath `
            -RedirectStandardError $StderrPath `
            -RedirectStandardInput $StdinPath
    } catch {
        $t.Problem = "could not start $engineName - $(ConvertTo-OneLine $_.Exception.Message)"
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
            if (-not $proc.WaitForExit($Timeout * 1000)) {
                $surv = Stop-ProcessTree -Process $proc   # [int[]]; never wrap in @()
                $t.Problem = "timeout after $Timeout s (process tree killed)"
                if ($surv.Count -gt 0) {
                    $t.Problem = "timeout after $Timeout s (process tree killed; $($surv.Count) processes survived: pid $($surv -join ', '))"
                    $t.KeepPending = $true
                    try {
                        $pendingRecord.state = 'survivors'
                        $pendingRecord.survivors = [object[]]@(New-SurvivorEntries -Pids $surv)
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
# otherwise). The closing words are the engine row's TreeNote (D11).
function Get-EngineTreeProblem {
    param($RevBefore, $RevAfter, [bool]$BriefChanged, [string[]]$ChangedArtifacts, [hashtable]$CollabBefore, [hashtable]$CollabAfter, [string[]]$OwnPrefixes, [string]$Engine, [string]$CollabShown = '')
    $cut = { param([string[]]$Names) $n = @($Names); $list = (@($n | Select-Object -First 5) -join ', '); if ($n.Count -gt 5) { $list += ', ...' }; "$($n.Count) file$(if ($n.Count -ne 1) { 's' }): $list" }
    $why = New-Object System.Collections.Generic.List[string]
    if ($RevBefore.tree_sha256 -ne $RevAfter.tree_sha256) {
        $paths = Get-ManifestChanges -Before $RevBefore.manifest -After $RevAfter.manifest
        $why.Add("the working tree changed during the run (by the reviewer or anyone else): $(& $cut $paths)")
    }
    $collab = Compare-DirectorySnapshot -Before $CollabBefore -After $CollabAfter -IgnorePrefixes $OwnPrefixes
    if ($collab.Count -gt 0) { $why.Add("the collab directory changed during the run (by the reviewer or anyone else): $(& $cut ([string[]]@($collab | ForEach-Object { $CollabShown + $_ })))") }
    if ($BriefChanged) { $why.Add('the brief changed during the run (by the reviewer or anyone else)') }
    if (@($ChangedArtifacts).Count -gt 0) { $why.Add("artifact(s) changed during the run (by the reviewer or anyone else): $(@($ChangedArtifacts) -join ', ')") }
    if ($why.Count -eq 0) { return '' }
    $note = [string](Get-EngineSpec -Name $Engine).TreeNote
    if (-not $note) { $note = "$Engine's sandbox does not block writes" }
    return (($why.ToArray() -join '; ') + " - $note")
}

# ----------------------------------------------------------------------------- presets + prompt text

$validPurposes = @('framing', 'decision', 'checkpoint', 'core-contract', 'acceptance', 'diff-review', 'stuck', 'chore')
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
    $DryRun = [bool]$pa.dry_run
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
if ($TimeoutSec -le 0) {
    Stop-WithError "-TimeoutSec must be greater than 0 (got $TimeoutSec)."
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
    if ($Provider) { Stop-WithError "-Panel runs every available reviewer of the roster and does not take -Provider (for one reviewer, drop -Panel)." }
    if ($Thread) { Stop-WithError "-Panel does not take -Thread: each member forks the newest thread of its own lineage (or starts one)." }
    if ($Mode -eq 'resume') { Stop-WithError "-Panel does not take -Mode resume: each member forks the newest thread of its own lineage (or starts one); -Mode new starts fresh threads for all." }
}
if ($panelMember -and -not $roster.Exists) { Stop-WithError "the reviewer roster '$($roster.Path)' is gone; this panel member was not started." }
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
$sessionsPath = Join-Path $taskDir 'sessions.json'
$findingsPath = Join-Path $taskDir 'findings.json'
$lockPath = Join-Path $taskDir '.consult.lock'
$pendingPath = Get-PendingPath -TaskDir $taskDir
$runStarted = Get-IsoTimestamp

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
        if ([int]::TryParse([string]$env:CODEX_CONSULT_TEST_MEMBER_PAUSE_MS, [ref]$memberPause) -and $memberPause -gt 0) { Start-Sleep -Milliseconds $memberPause }
        if (-not (Test-PidAlive -ProcessId $memberParentPid -StartTime $memberParentStart)) {
            $rmError = Remove-PendingFile -Path $pendingPath
            Stop-WithError "the review panel run that launched this member (pid $memberParentPid) is gone; this panel member was not started - nothing was started and its recovery record '$pendingPath' $(if ($rmError) { "could not be withdrawn ($rmError; the next run consumes it)" } else { 'was withdrawn' })."
        }
    }
}

$codexExePath = Resolve-CodexLauncher -Explicit $CodexExe

$codexVersion = 'unknown'
if ($codexExePath) {
    try {
        $v = & $codexExePath --version 2>$null
        if ($v) { $codexVersion = ([string]@($v)[0]).Trim() }
    } catch { }
}
# "codex-cli 0.155.1" -> "0.155.1" for the prose header; sessions.json keeps the full string.
$codexVersionShort = $codexVersion -replace '^codex-cli\s+', ''
$harness = if ($codexVersion -match '^codex-cli\s') { $codexVersion } else { "codex-cli $codexVersion" }

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
#   3. assigns n and NN to every member up front, in roster order (member k: n0 + k - 1,
#      NN0 + k - 1), so the files and the ledger keep the roster order whatever finishes first;
#   4. writes every member's `reserved` record (the panel, n, NN, this process as writer and
#      parent) BEFORE it launches any member - a member proves its parent with it, rewrites it
#      with its own pid and only then checks that the parent lives (D6, D1, F07-1);
#   5. launches the members as processes of their own (Start-Process; console output to files
#      in a temp directory) along the plan of Get-PanelPlan - members of different endpoints at
#      once, of one endpoint one after another unless the roster's "parallel" raises it,
#      -PanelConcurrency caps the total (D8) - polls them, prints one line per finished member
#      and stops a member that outlives its guard (its timeout + its format-repair and
#      denial-retry budgets + 60 s write lock + 120 s, D11);
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
        args              = [pscustomobject]@{
            collab_dir       = $CollabDir
            mode             = $Mode
            brief            = $Brief
            prompt           = $Prompt
            purpose          = $Purpose
            effort           = $Effort
            sandbox          = $Sandbox
            max_words        = $MaxWords
            timeout_sec      = $TimeoutSec
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
    if (-not $DryRun -and -not $codexExePath -and @($roster.Entries | Where-Object { $_.Engine -eq 'codex' -and (-not $Engine -or $Engine -eq 'codex') }).Count -gt 0) {
        Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
    }
    $panelConfig = Read-CodexConfigSubset -Path (Get-CodexConfigPath)
    $panelClock = Get-ConsultClock -Peek
    if ($panelClock.Error) { Stop-WithError $panelClock.Error }
    $panelSelection = Select-PanelMembers -Roster $roster -Config $panelConfig -Consults (Read-AllTaskConsults -CollabRoot $collabRoot) -Launcher ([string]$codexExePath) -LoginCache @{} -UtcNow $panelClock.Now.UtcDateTime -OpenAiBaseUrl ([string]$env:OPENAI_BASE_URL) -Model $Model -Purpose $Purpose -All:$PanelAll -SkipPreflight:$SkipPreflight -Engine $Engine -EngineLaunchers $engineLaunchers
    if ($panelSelection.Error) { Stop-WithError $panelSelection.Error }
    $panelEntries = @($panelSelection.Members)
    $panelRunners = @($panelEntries | Where-Object { $_.State -eq 'run' })
    # -MaxModelSteps goes to the members whose engine has a step cap (muse); none -> refused.
    if ($MaxModelSteps -gt 0 -and @($panelRunners | Where-Object { (Get-EngineSpec ([string]$_.Entry.Engine)).StepsFlag }).Count -eq 0) {
        Stop-WithError "-MaxModelSteps applies to the muse members of a panel (--max-model-steps); no member of this panel runs the muse engine."
    }
    # A launcher every member of an engine would miss is refused once, up front.
    if (-not $DryRun) {
        foreach ($panelEngine in @($panelRunners | ForEach-Object { [string]$_.Identity.Engine } | Select-Object -Unique)) {
            if ($panelEngine -ne 'codex' -and -not (Get-EngineLauncher -Engine $panelEngine -Launchers $engineLaunchers)) {
                Stop-WithError "$panelEngine CLI not found on PATH (set -EngineExe <path> or the $((Get-EngineSpec $panelEngine).ExeEnv) environment variable)."
            }
        }
    }
    $panelId = [guid]::NewGuid().ToString()
    $panelShort = $panelId.Substring(0, 8)
    $panelMembersRecord = [object[]]@($panelEntries | ForEach-Object { [pscustomobject]@{ provider = $_.Entry.Provider; model = $_.Identity.Model; state = $_.State; reason = $_.Reason } })
    $panelSkippedRecord = [object[]]@($panelEntries | Where-Object { $_.State -ne 'run' } | ForEach-Object { [pscustomobject]@{ provider = $_.Entry.Provider; model = $_.Identity.Model; engine = [string]$_.Entry.Engine; reason = $_.Reason } })
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
            if ($DryRun) { $panelPendingRefusal = [string]$panelPending.Active.Check.Message } else { Stop-WithError $panelPending.Active.Check.Message }
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
        [void][int]::TryParse([string]$env:CODEX_CONSULT_TEST_PANEL_GUARD_SEC, [ref]$guardHook)
        $slotOf = @{}
        $k = 0
        foreach ($pm in $panelRunners) {
            $k++
            $slug = ($pm.Entry.Provider.ToLowerInvariant() -replace '[^a-z0-9._-]', '-').Trim('-')
            if (-not $slug) { $slug = 'reviewer' }
            $engineK = [string]$pm.Entry.Engine
            if (-not $engineK) { $engineK = 'codex' }
            $nnK = '{0:D2}' -f ([int]$panelNumbers.Nn + $k - 1)
            # The kill guard from the member's own budgets (D11): its timeout, one format-repair
            # turn and (an engine with a denial retry: agy) one denial-retry turn of
            # min(timeout, 300) s when enabled, the 60 s write-lock wait, 120 s slack. TEST HOOK:
            # CODEX_CONSULT_TEST_PANEL_GUARD_SEC.
            $guard = $TimeoutSec + 60 + 120
            if ($repairEnabled) { $guard += [Math]::Min($TimeoutSec, 300) }
            if ((Get-EngineSpec $engineK).DenialRetry -and $DenialRetry -eq 1) { $guard += [Math]::Min($TimeoutSec, 300) }
            if ($guardHook -gt 0) { $guard = $guardHook }
            $slot = [pscustomobject]@{
                Pm = $pm; K = $k; N = ($panelNumbers.N + $k - 1); Nn = $nnK; Engine = $engineK
                ReplyName = "$ReplyName-$slug"; Reply = "handoffs/$nnK-$((Get-EngineSpec $engineK).Prefix)-$ReplyName-$slug.md"
                RecordPath = (Get-MemberPendingPath -TaskDir $taskDir -Nn $nnK); ConsultId = [guid]::NewGuid().ToString()
                Group = [int]$panelPlan.GroupOf[[int]$pm.Entry.Position]; Guard = $guard
                State = 'waiting'; Proc = $null; Watch = $null; Exit = $null; Wall = 0; OutPath = ''; ErrPath = ''
                Entry = $null; Refusal = ''; RecordState = ''; RecordKept = $false; NotStarted = ''; StartError = ''; Lines = [string[]]@()
            }
            $panelSlots.Add($slot)
            $slotOf[[int]$pm.Entry.Position] = $slot
        }

        $panelVerb = if ($DryRun) { 'would run' } else { 'run' }
        Write-Host "Panel $panelShort$(if ($DryRun) { ' (dry run - nothing is executed or written)' }): $($panelRunners.Count) of $($panelEntries.Count) roster entries $panelVerb, $($panelPlan.Text) (roster $($roster.Path); panel id $panelId)"
        # The lineage as shown: ' [agy]' for a member of another engine than codex.
        foreach ($pm in $panelEntries) { $pm | Add-Member -NotePropertyName 'Shown' -NotePropertyValue (Format-ReviewerLineage -Provider $pm.Identity.Provider -Model $pm.Identity.Model -Engine ([string]$pm.Identity.Engine)) -Force }
        foreach ($pm in $panelEntries) {
            $slot = $slotOf[[int]$pm.Entry.Position]
            Write-Host ("  #{0} {1} - {2}" -f $pm.Entry.Position, $pm.Shown, $(if ($pm.State -eq 'run') { "member, n=$($slot.N), handoff $($slot.Nn)" } else { "skipped: $($pm.Reason)" }))
        }
        $groupTexts = @(foreach ($g in $panelPlan.Groups) {
                $cnt = @($g.Positions).Count
                $t = "$(@($g.Labels) -join '+') x$cnt"
                if ($cnt -gt 1) { $t += $(if ($g.Limit -ge $cnt) { ' at once' } elseif ($g.Limit -le 1) { ' one after another' } else { " $($g.Limit) at a time" }) }
                $t
            })
        Write-Host "Concurrency: $($panelPlan.Text) - endpoint groups: $($groupTexts -join ', '); -PanelConcurrency $(if ($PanelConcurrency -gt 0) { $PanelConcurrency } else { '0 (no cap)' })"
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
                $status = Get-PanelMemberStatus $slot
                if ($status.Length -gt 110) { $status = $status.Substring(0, 110) + '...' }
                Write-Host "  panel member $($slot.K) of $($panelRunners.Count) finished: $($slot.Pm.Shown) - $status ($($slot.Wall) s)"
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
                if ($panelBlocked) { $slot.State = 'blocked'; $slot.NotStarted = $panelBlocked; $progress = $true; continue }
                if ($PanelConcurrency -gt 0 -and $running -ge $PanelConcurrency) { break }
                $grp = $panelPlan.Groups[$slot.Group]
                if (@($panelSlots | Where-Object { $_.Group -eq $slot.Group -and $_.State -eq 'running' }).Count -ge $grp.Limit) { continue }
                # within an endpoint group the roster order holds
                if (@($panelSlots | Where-Object { $_.Group -eq $slot.Group -and $_.State -eq 'waiting' -and $_.K -lt $slot.K }).Count -gt 0) { continue }
                Start-PanelMember $slot
                $progress = $true
                if ($slot.State -eq 'running') { $running++ }
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
        foreach ($pm in $panelEntries) {
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
                    if ($slot.State -eq 'killed') {
                        $row.Status = Get-PanelMemberStatus $slot
                        $row.Tail = $tail
                        $row.Wide = $true
                        $allUsable = $false
                    } elseif ($outcome -ne 'usable reply') {
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
        Write-Host ""
        Write-Host "Panel $($panelShort): $(if ($DryRun) { "$($panelRunners.Count) of $($panelEntries.Count) entries would run (dry run)" } else { "$panelStarted of $($panelEntries.Count) entries ran" }) (wall clock $panelWall s; $($panelPlan.Text))"
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
            Write-Host ('  ' + (($parts.ToArray() -join '  ').TrimEnd()))
        }
        if ($allUsable) { exit 0 }
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
        $walk = Select-RosterReviewer -Roster $roster -Config $codexConfigScan -Consults $allConsults -Launcher ([string]$codexExePath) -LoginCache $loginCache -UtcNow $healthNow -OpenAiBaseUrl $openAiBaseUrl -Model $Model -SkipPreflight:$SkipPreflight -Engine $Engine -EngineLaunchers $engineLaunchers
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
if (-not $engineName) { $engineName = 'codex' }
if (-not $engineFrom) { $engineFrom = 'default' }
$engineSpec = Get-EngineSpec -Name $engineName
$isCodex = ($engineName -eq 'codex')
$anonymous = [bool]($rosterEntry -and $rosterEntry.Auth -eq 'none')

# What an engine does not support is refused with one message each (nothing started).
if (-not $isCodex) {
    if ($Mode -eq 'fork') { Stop-WithError "the $engineName engine has no fork; use -Mode resume or new." }
    if ($Sandbox -ne 'read-only') { Stop-WithError "-Sandbox $Sandbox is refused for the $engineName engine: consultations are read-only there ($($engineSpec.ReadOnlyNote))." }
    if (@($CodexConfig | Where-Object { $_ -and $_.Trim() }).Count -gt 0) { Stop-WithError "-CodexConfig does not apply to the $engineName engine (it configures codex exec)." }
    if ($transportOverride -and $engineSpec.Transports -notcontains $transportOverride) { Stop-WithError "-SchemaTransport $transportOverride is refused for the $engineName engine: it takes $($engineSpec.Transports -join ' or ') (native = the schema is passed as $($engineSpec.SchemaFlag))." }
    # agy: default mode new (a conversation is resumed only on request); -Thread resumes it.
    if (-not $Mode) { $Mode = $(if ($Thread) { 'resume' } else { $engineSpec.DefaultMode }) }
} else {
    if ($transportOverride -and $engineSpec.Transports -notcontains $transportOverride) { Stop-WithError "-SchemaTransport $transportOverride is for the agy and muse engines; codex takes output-schema or prompt-only." }
}
# -MaxModelSteps: an engine with a model-step cap only (muse, D9); a panel member of another
# engine ignores the panel's value.
if ($MaxModelSteps -gt 0 -and -not $engineSpec.StepsFlag) {
    if ($panelMember) { $MaxModelSteps = 0 }
    else { Stop-WithError "-MaxModelSteps is for the muse engine (--max-model-steps); the $engineName engine has no model-step cap." }
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

$identity = Resolve-ReviewerIdentity -Config $codexConfigScan -Provider $identityProvider -Model $identityModel -OpenAiBaseUrl $openAiBaseUrl -Engine $engineName -Launcher $engineLauncher
if ($identity.Error) { Stop-WithError $identity.Error }
if ($providerSourceOverride) { $identity.ProviderSource = $providerSourceOverride }
if ($modelSourceOverride) { $identity.ModelSource = $modelSourceOverride }
$reviewerRecord = New-ReviewerRecord -Identity $identity -Harness $harness
$lineage = $identity.Lineage
# The lineage as shown on the console and in the handoff (' [agy]' for another engine).
$lineageShown = Format-ReviewerLineage -Provider $identity.Provider -Model $identity.Model -Engine $engineName
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
# refuse the run - no ledger entry, nothing started - unless -SkipPreflight. A usage limit
# without a reset time within the last hour only warns (a roster walk skips it instead).
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
    if ($preflightRefusal -and -not $DryRun) { Stop-WithError $preflightRefusal }
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
    }
}
if ($rosterLine -and -not $DryRun) { Write-Host $rosterLine }
if (-not $DryRun) { foreach ($rw in $runWarnings) { Write-Host "WARNING: $rw" -ForegroundColor Yellow } }
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
# unless the whole string names an existing file.
$artifactList = New-Object System.Collections.Generic.List[string]
foreach ($a in @($Artifact)) {
    if (-not $a -or -not $a.Trim()) { continue }
    $a = $a.Trim()
    $whole = -not $a.Contains(',')
    if (-not $whole) {
        if ([IO.Path]::IsPathRooted($a)) { $whole = Test-Path -LiteralPath $a -PathType Leaf }
        else {
            foreach ($base in @($callerCwd, $repoRoot)) {
                if (Test-Path -LiteralPath (Join-Path $base $a) -PathType Leaf) { $whole = $true; break }
            }
        }
    }
    if ($whole) { $artifactList.Add($a) }
    else { foreach ($piece in $a.Split(',')) { if ($piece.Trim()) { $artifactList.Add($piece.Trim()) } } }
}
$artifactItems = @(Resolve-ArtifactPaths -Paths $artifactList.ToArray() -Bases @($callerCwd, $repoRoot))

$schemaPath = ''
if (-not $Raw) {
    $schemaPath = [IO.Path]::GetFullPath((Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'schemas') 'consult-reply.schema.json'))
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        Stop-WithError "output schema not found at '$schemaPath' (reinstall the plugin, or pass -Raw for a plain-text consultation)."
    }
}

if (-not $DryRun -and $isCodex -and -not $codexExePath) {
    Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
}
if (-not $DryRun -and -not $isCodex -and -not $engineLauncher) {
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
        if ($pendingAll.Active -and -not $DryRun) { Stop-WithError $pendingAll.Active.Check.Message }
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

    # ------------------------------------------------------------------------- prompt

    $nl = "`r`n"
    $promptParts = New-Object System.Collections.ArrayList
    # Structured mode: the output contract comes FIRST, before the ask and the brief - a
    # reviewer that reads a long brief first tends to answer in prose (handoffs 17/18).
    if (-not $Raw) {
        [void]$promptParts.Add('FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON object (schema_version "1") - no code fence, no text before or after it. The Markdown answer lives only inside its reply_markdown string; each defect goes in findings[]. A prose final message cannot be ingested, however good the answer is.')
    }
    if ($Prompt) { [void]$promptParts.Add($Prompt.Trim()) }
    if ($briefRef) {
        [void]$promptParts.Add("Read the brief at ``$briefRef`` (path relative to the repository root, which is your working directory) and answer every numbered question in it.")
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
    # Always the LAST line: it ties a rollout file to this run (Find-ThreadInRollouts).
    [void]$promptParts.Add("Consultation id: $consultId")
    $promptText = [string]::Join("$nl$nl", $promptParts.ToArray())

    # ------------------------------------------------------------------------- argv

    if (-not $isCodex) {
        # The engine's own argv from ONE turn-options object (wave 23, D1): the schema natively
        # unless prompt-only, the thread on resume, the effort (agy: only -NativeEffort; muse:
        # the mapped value), this turn's prompt file (muse), -MaxModelSteps (muse).
        $engineSchemaArg = ''
        if (-not $Raw -and $schemaTransport -eq 'native') { $engineSchemaArg = $schemaPath }
        $engineThreadArg = ''
        if ($Mode -eq 'resume') { $engineThreadArg = $parentThread }
        $mainTurn = New-EngineTurnOptions -Model $identity.Model -Mode $Mode -Thread $engineThreadArg -PromptFile $promptPath -Schema $engineSchemaArg -Effort $effortSent -NativeEffort $NativeEffort -MaxSteps $MaxModelSteps
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
            consult_id                      = $consultId
            reviewer                        = $reviewerRecord
            lineage                         = $lineage
            preflight                       = $preflight
            preflight_warning               = $preflightWarning
            roster                          = $rosterRecord
            panel                           = $panelRecord
            parent_thread                   = $parentThread
            thread                          = '<filled from the event stream>'
            thread_source                   = $(if ($isCodex) { 'events|rollout (verified by consultation id)|unknown' } else { 'events|unknown' })
            thread_candidate                = $(if ($isCodex) { '<"" or an unverified rollout uuid>' } else { '<"" or a conversation id that is never a parent>' })
            mode                            = $Mode
            command                         = $commandStr
            brief                           = $briefRef
            prompt_chars                    = $promptText.Length
            reply                           = $replyRel
            reply_json                      = $replyJsonPlanned
            events                          = $eventsRel
            model                           = $modelLabel
            effort                          = $effortSent
            effort_requested                = $effortPlan.Requested
            effort_sent                     = $effortSent
            effort_mapping                  = $effortPlan.Mapping
            effort_caps                     = $effortPlan.Caps
            effort_confirmed                = $null
            max_words                       = $maxWordsResolved
            sandbox                         = $sandboxRecord
            extra_config                    = [object[]]$extraConfig.ToArray()
            extra_config_source             = $extraConfigSource
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
            base_commit                     = $revBefore.base_commit
            reviewed_revision               = $revBefore.reviewed_revision
            tree_sha256                     = $revBefore.tree_sha256
            tree_sha256_after               = '<computed after the run>'
            tree_changed_during_review      = '<true|false>'
            changed_files                   = $revBefore.changed_files
            brief_sha256                    = $briefSha
            brief_sha256_after              = $(if ($briefPath) { '<computed after the run>' } else { '' })
            brief_changed_during_review     = '<true|false>'
            fingerprint_note                = $revBefore.fingerprint_note
            artifacts                       = [object[]]$previewArtifacts
            artifacts_changed_during_review = '<true|false>'
            bridge_outcome                  = '<usable reply | failed: ...>'
            provider_failure                = '<null, or {class auth|quota|capability|transport|unknown, code, message, when} of a failed run>'
            warnings                        = [object[]]$runWarnings.ToArray()
            verdict                         = $(if ($Raw) { '' } else { "<$($verdictRule -replace ', | or ', '|'), or '' when unavailable>" })
            verdict_reason                  = $(if ($Raw) { '' } else { '<one sentence>' })
            findings                        = $previewFindings
            finding_ids                     = [object[]]$previewIds
            prior_findings                  = [object[]]@($listedIds | ForEach-Object { [pscustomobject]@{ id = $_; status = '<fixed|still-open|not-checked|unknown-id>' } })
            unchecked_prior_blockers        = [object[]]@()
            usage                           = $(if ($isCodex) { [pscustomobject]@{ input_tokens = '<n>'; cached_input_tokens = '<n>'; output_tokens = '<n>'; reasoning_output_tokens = '<n>' } } elseif (-not $engineSpec.HasUsage) { $null } else { [pscustomobject]@{ input_tokens = '<n>'; cached_input_tokens = '<n (cache_read_tokens)>'; output_tokens = '<n>'; reasoning_output_tokens = '<n (thinking_tokens)>'; total_tokens = '<n>' } })
            engine_run                      = $(if ($isCodex) { $null } else { [pscustomobject]@{ turns = '<the turns started: 1, + a denial retry, + a format repair>'; max_model_steps = $(if ($MaxModelSteps -gt 0) { $MaxModelSteps } else { $null }); msp_schema_version = $(if ($engineSpec.PromptTransport -eq 'file') { '<the MSP schema_version of the stream: 1>' } else { $null }) } })
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
        if ($preflightLabel -match 'a real run is refused') { Write-Host "preflight   : $preflightLabel" -ForegroundColor Yellow }
        else { Write-Host "preflight   : $preflightLabel" }
        if ($rosterLine) { Write-Host $rosterLine }
        foreach ($rw in $runWarnings) { Write-Host "WARNING: $rw" -ForegroundColor Yellow }
        if ($preflightWarning) { Write-Host "WARNING: $preflightWarning" -ForegroundColor Yellow }
        Write-Host "model       : $modelLabel"
        Write-Host "purpose     : $purposeLabel (effort $(if ($null -eq $effortSent) { 'none sent' } else { $effortSent }), max words $maxWordsResolved)"
        Write-Host "effort      : $(if ($null -eq $effortSent) { 'nothing' } else { $effortSent }) sent (requested $($effortPlan.Requested), mapping $($effortPlan.Mapping), by $($effortPlan.Basis))"
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
    # (wave 23) right before the launch: the engine's launch invariant again (D4) and the
    # %-expansion hazard of a .cmd launcher (F02-14) - the reservation is withdrawn, nothing
    # was started, no ledger entry.
    if (-not $isCodex) {
        $preLaunch = Get-EngineLaunchBlock -Engine $engineName
        if (-not $preLaunch) { $preLaunch = $argvHazard }
        if ($preLaunch) {
            $rmError = Remove-PendingFile -Path $pendingPath
            Stop-WithError "the $engineName run is refused before launch: $preLaunch; nothing was started.$(if ($rmError) { " (The recovery record '$pendingPath' could not be removed: $rmError; the next run consumes it.)" })"
        }
    }

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

    $startedAt = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = -1
    $bridgeOutcome = ''
    $argStr = (($argv | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' ')

    $proc = $null
    try {
        $proc = Start-Process -FilePath $engineLauncher -ArgumentList $argStr `
            -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
            -RedirectStandardOutput $eventsPath `
            -RedirectStandardError $stderrPath `
            -RedirectStandardInput $stdinPath
    } catch {
        $bridgeOutcome = "failed: could not start $engineCmd - $($_.Exception.Message)"
    }
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
            $finished = $proc.WaitForExit($TimeoutSec * 1000)
            if (-not $finished) {
                # The launcher is usually a shim (codex.cmd -> node -> codex.exe): kill
                # the whole tree, or the real codex keeps running after we give up.
                $survivors = Stop-ProcessTree -Process $proc   # [int[]]; never wrap in @(): that nests the array
                # TEST HOOK: CODEX_CONSULT_TEST_SURVIVORS=<pid>[,<pid>] - these pids, when
                # alive, are reported as survivors of this kill (no test can make a real
                # process outlive a kill). Only ever adds survivors: a stricter outcome.
                foreach ($hookPid in @(([string]$env:CODEX_CONSULT_TEST_SURVIVORS).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' })) {
                    if ((Get-Process -Id ([int]$hookPid) -ErrorAction SilentlyContinue) -and ($survivors -notcontains [int]$hookPid)) { $survivors = [int[]]@($survivors + [int]$hookPid) }
                }
                $bridgeOutcome = "failed: timeout after $TimeoutSec s (process tree killed)"
                if ($survivors.Count -gt 0) {
                    $bridgeOutcome = "failed: timeout after $TimeoutSec s (process tree killed; $($survivors.Count) processes survived: pid $($survivors -join ', '); the next run for this task is refused until they exit)"
                    # (5) survivors - kept after this run.
                    $keepPending = $true
                    try {
                        $pendingRecord.state = 'survivors'
                        # { pid, start_time, name } per survivor, so a reused pid is not
                        # mistaken for the survivor later (New-SurvivorEntries streams
                        # objects; @() is correct here - it does not return ", $array").
                        $pendingRecord.survivors = [object[]]@(New-SurvivorEntries -Pids $survivors)
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
    $treeChanged = ($revBefore.tree_sha256 -ne $revAfter.tree_sha256)
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
    $agyTurn = $null
    $agyEvents = $null
    $agyFailureClass = ''
    $agyFailureTexts = @()
    # (wave 23) engine turns started (ledger engine_run.turns; for muse each one is a
    # subscription prompt) and the MSP schema version of the stream (muse)
    $engineTurns = $(if ($proc) { 1 } else { 0 })
    $mspVersion = $null
    $denialRetryRecord = $null
    $treeProblem = ''
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
        $agyTurn = & $engineSpec.Adapter.Outcome -Events $agyEvents -ExitCode $exitCode -StderrText $stderrText -Pre $bridgeOutcome -ExpectThread $(if ($Mode -eq 'resume') { $parentThread } else { '' }) -ExpectModel ([string]$identity.Model)
        if ($agyEvents.PSObject.Properties['SchemaVersion']) { $mspVersion = $agyEvents.SchemaVersion }
        $bridgeOutcome = $agyTurn.Outcome
        $rawReplyFull = [string]$agyTurn.Reply
        $rawReply = $rawReplyFull.Trim()
        $threadId = [string]$agyTurn.Thread
        $threadSource = $(if ($threadId) { 'events' } else { 'unknown' })
        $threadCandidate = [string]$agyTurn.ThreadCandidate
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
        $treeProblem = Get-EngineTreeProblem -RevBefore $revBefore -RevAfter $revAfter -BriefChanged $briefChanged -ChangedArtifacts $changedArtifacts -CollabBefore $collabBefore -CollabAfter (Get-CollabSnapshot -Dir $collabRoot) -OwnPrefixes $ownPrefixes -Engine $engineName -CollabShown $collabShown
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
            $retryOpts = New-EngineTurnOptions -Model $identity.Model -Mode 'denial-retry' -Thread $threadId -PromptFile $denialPromptPath -Schema $retrySchemaArg -Effort $effortSent -NativeEffort $NativeEffort -MaxSteps $MaxModelSteps
            $retryArgv = & $engineSpec.Adapter.Argv -Turn $retryOpts
            $retryEventsName = "$nn-$enginePrefix-$ReplyName.denial-retry.events.jsonl"
            $retryEventsPath = Join-Path $handoffsDir $retryEventsName
            $extraEvents.Add("handoffs/$retryEventsName")
            $retryTimeout = [Math]::Min($TimeoutSec, 300)
            $retryTurn = Invoke-EngineTurn -Argv $retryArgv -StdinText (& $engineSpec.Adapter.Stdin -Prompt $retryPrompt) -EventsPath $retryEventsPath -StdinPath $(if ($promptByFile) { $stdinPath } else { $denialPromptPath }) -StderrPath $denialStderrPath -Timeout $retryTimeout -Note 'denial retry turn' -PromptPath $(if ($promptByFile) { $denialPromptPath } else { '' }) -PromptText $retryPrompt
            if ($retryTurn.KeepPending) { $keepPending = $true }
            if ($retryTurn.Started) { $engineTurns++ }
            $retryEvents = & $engineSpec.Adapter.Events -Path $retryEventsPath -AllowPartialLast:([bool]($retryTurn.Problem -or $retryTurn.Exit -ne 0))
            $retryOut = & $engineSpec.Adapter.Outcome -Events $retryEvents -ExitCode $retryTurn.Exit -StderrText $retryTurn.Stderr -Pre $(if ($retryTurn.Problem) { "failed: $($retryTurn.Problem)" } else { '' }) -ExpectThread $threadId -ExpectModel ([string]$identity.Model)
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
        if ($isCodex) { try { [IO.File]::Copy($lastMsgPath, $originalFull, $true) } catch { Write-Utf8NoBom -Path $originalFull -Text $rawReply } }
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
            $pendingRecord.state = 'launching'
            $pendingRecord.note = 'format repair turn being started; its pid is not recorded yet'
            try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
                $repairProblem = "could not write the recovery record ($(ConvertTo-OneLine $_.Exception.Message)); the repair turn was not started"
            }
            if (-not $repairProblem) { try {
                $repairProc = Start-Process -FilePath $codexExePath -ArgumentList ((($repairArgv | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' ')) `
                    -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
                    -RedirectStandardOutput $repairEventsPath `
                    -RedirectStandardError $repairStderrPath `
                    -RedirectStandardInput $repairPromptPath
            } catch {
                $repairProblem = "could not start codex - $(ConvertTo-OneLine $_.Exception.Message)"
            } }
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
                    if (-not $repairProc.WaitForExit($repairTimeout * 1000)) {
                        $repairSurvivors = Stop-ProcessTree -Process $repairProc   # [int[]]; never wrap in @()
                        $repairProblem = "timeout after $repairTimeout s (process tree killed)"
                        if ($repairSurvivors.Count -gt 0) {
                            $repairProblem = "timeout after $repairTimeout s (process tree killed; $($repairSurvivors.Count) processes survived: pid $($repairSurvivors -join ', '))"
                            $keepPending = $true
                            try {
                                $pendingRecord.state = 'survivors'
                                $pendingRecord.survivors = [object[]]@(New-SurvivorEntries -Pids $repairSurvivors)
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
            $repairOpts = New-EngineTurnOptions -Model $identity.Model -Mode 'format-repair' -Thread $threadId -PromptFile $repairPromptPath -Schema $(if ($repairTransport -eq 'native') { $schemaPath } else { '' }) -Effort (Get-RepairEffort -Identity $identity -EffortPlan $effortPlan) -NativeEffort $NativeEffort -MaxSteps $MaxModelSteps
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
            $repairOut = & $engineSpec.Adapter.Outcome -Events $repairEv -ExitCode $repairTurn.Exit -StderrText $repairTurn.Stderr -Pre $(if ($repairTurn.Problem) { "failed: $($repairTurn.Problem)" } else { '' }) -ExpectThread $threadId -ExpectModel ([string]$identity.Model)
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
        $treeChanged = ($revBefore.tree_sha256 -ne $revAfter.tree_sha256)
        if ($briefPath) { $briefShaAfter = Get-FileSha256OrMissing -Path $briefPath }
        $briefChanged = ($briefSha -ne $briefShaAfter)
        $artifactsFinal = @($artifactHashes | ForEach-Object { [pscustomobject]@{ path = $_.path; sha256 = $_.sha256; sha256_after = (Get-FileSha256OrMissing -Path $_.full) } })
        $changedArtifacts = @($artifactsFinal | Where-Object { $_.sha256 -ne $_.sha256_after } | ForEach-Object { $_.path })
        $artifactsChanged = ($changedArtifacts.Count -gt 0)
        $treeProblem = Get-EngineTreeProblem -RevBefore $revBefore -RevAfter $revAfter -BriefChanged $briefChanged -ChangedArtifacts $changedArtifacts -CollabBefore $collabBefore -CollabAfter (Get-CollabSnapshot -Dir $collabRoot) -OwnPrefixes $ownPrefixes -Engine $engineName -CollabShown $collabShown
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
    }
    $providerFailure = $null
    if ($bridgeOutcome -ne 'usable reply' -and $isCodex) {
        $sseLines = @(($stderrText -split "`r?`n") | Where-Object { $_ -match '^\s*data:\s*\{' })
        $stderrTail = (($stderrText.Trim() -split "`r?`n") | Select-Object -Last 1)
        $providerFailure = New-ProviderFailure -Texts @(($sseLines | Select-Object -Last 1), $eventError, $stderrTail, ($bridgeOutcome -replace '^failed:\s*', ''))
    } elseif ($bridgeOutcome -ne 'usable reply') {
        # agy: the result's error, the telling stderr line, the bridge's reason - and the class
        # the turn rules force (permission, transport, unknown), else the classifier's.
        $providerFailure = New-ProviderFailure -Texts @(@($agyFailureTexts) + @(($bridgeOutcome -replace '^failed:\s*', ''))) -Class $agyFailureClass
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
    } elseif ($isCodex -and (Test-Path -LiteralPath $lastMsgPath -PathType Leaf)) {
        # (-Raw, or a reply that could not be copied) the last message is only in its temp file
        $pendingRecord | Add-Member -NotePropertyName 'raw_reply' -NotePropertyValue $lastMsgPath -Force
        $kept.Add($lastMsgPath)
    }
    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
    $commit = Enter-StoreCommit -TaskDir $taskDir -Task $Task -TimeoutSec (Get-WriteLockTimeout)
    if (-not $commit.Acquired) {
        if ([string](Get-PropertyValue $pendingRecord 'raw_reply' '')) { $keepLastMsg = $true }
        if ([string](Get-PropertyValue $pendingRecord 'events' '')) { $kept.Add([string]$pendingRecord.events) }
        if ([string](Get-PropertyValue $pendingRecord 'original' '')) { $kept.Add([string]$pendingRecord.original) }
        $pendingRecord.note = "commit blocked: $($commit.Message); findings.json and sessions.json were not touched"
        try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
        Write-Host "codex-consult: commit blocked: $($commit.Message). This run's reply is kept ($(if ($kept.Count -gt 0) { $kept.ToArray() -join ', ' } else { 'nothing to keep' })); no ledger entry was written and the stores were not touched - $pendingPath stays in state committing and the next run consumes it (bridge outcome: $bridgeOutcome)." -ForegroundColor Red
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
    if ($engineRunRecord) { $headerLines.Add("Engine turns: $($engineRunRecord.turns)$(if ($engineName -eq 'muse') { ' (each one a Muse Code subscription prompt)' })$(if ($null -ne $engineRunRecord.max_model_steps) { "; --max-model-steps $($engineRunRecord.max_model_steps)" })$(if ($null -ne $engineRunRecord.msp_schema_version) { "; MSP schema_version $($engineRunRecord.msp_schema_version)" }).") }
    if ($engineWarnings.Count -gt 0) { $headerLines.Add("Warnings: $(($engineWarnings.ToArray() | ForEach-Object { ConvertTo-OneLine $_ }) -join '; ').") }
    if ($denialRetryRecord) {
        if ($denialRetryRecord.succeeded) { $headerLines.Add("Denial retry: succeeded in $($denialRetryRecord.wall_seconds) s - the first turn produced nothing (a tool was auto-denied); one more turn on conversation ``$threadId`` answered without it. Tokens of that turn: $(Format-Usage $denialRetryRecord.usage).") }
        else { $headerLines.Add("Denial retry: failed in $($denialRetryRecord.wall_seconds) s - the first turn produced nothing (a tool was auto-denied) and the retry turn on conversation ``$threadId`` did not produce a usable reply.") }
    }
    if ($providerFailure) {
        $codeText = ''
        if ($providerFailure.code) { $codeText = " ($($providerFailure.code))" }
        $headerLines.Add("Provider failure: $($providerFailure.class)$codeText - $($providerFailure.message).")
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

    # ------------------------------------------------------------------------- 3. findings.json

    if ($ingest -and $ingest.Changed) {
        Complete-StoreCommit -Commit $commit -Findings
    }
    # TEST HOOK: CODEX_CONSULT_TEST_COMMIT_PAUSE_MS=<ms> | <model>=<ms>[|...] - a pause inside
    # the commit, between findings.json and sessions.json (the ORPHAN window a kill can hit;
    # write-lock contention); a map pauses only the runs of that model.
    $commitPause = Get-TestHookMs -Value ([string]$env:CODEX_CONSULT_TEST_COMMIT_PAUSE_MS) -Model ([string]$identity.Model)
    if ($commitPause -gt 0) { Start-Sleep -Milliseconds $commitPause }

    # ------------------------------------------------------------------------- 4. sessions.json

    # `model` holds the resolved model and `effort` the value sent (= effort_sent): the
    # 0.2 fields keep their meaning for older readers and codex-findings.ps1 -Stats.
    $entry = [pscustomobject]@{
        n                               = $consultN
        when                            = (Get-IsoTimestamp $startedAt)
        purpose                         = $Purpose
        consult_id                      = $consultId
        reviewer                        = $reviewerRecord
        lineage                         = $lineage
        preflight                       = $preflight
        preflight_warning               = $preflightWarning
        roster                          = $rosterRecord
        panel                           = $panelRecord
        parent_thread                   = $parentThread
        thread                          = $threadId
        thread_source                   = $threadSource
        thread_candidate                = $threadCandidate
        mode                            = $Mode
        command                         = $commandStr
        brief                           = $briefRef
        prompt_chars                    = $promptText.Length
        reply                           = $replyRel
        reply_json                      = $replyJsonRel
        events                          = $eventsRel
        model                           = $modelLabel
        effort                          = $effortSent
        effort_requested                = $effortPlan.Requested
        effort_sent                     = $effortSent
        effort_mapping                  = $effortPlan.Mapping
        effort_caps                     = $effortPlan.Caps
        effort_confirmed                = $null
        max_words                       = $maxWordsResolved
        sandbox                         = $sandboxRecord
        extra_config                    = [object[]]$extraConfig.ToArray()
        extra_config_source             = $extraConfigSource
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
        base_commit                     = $revBefore.base_commit
        reviewed_revision               = $revBefore.reviewed_revision
        tree_sha256                     = $revBefore.tree_sha256
        tree_sha256_after               = $revAfter.tree_sha256
        tree_changed_during_review      = $treeChanged
        changed_files                   = $revBefore.changed_files
        brief_sha256                    = $briefSha
        brief_sha256_after              = $briefShaAfter
        brief_changed_during_review     = $briefChanged
        fingerprint_note                = $revBefore.fingerprint_note
        artifacts                       = [object[]]$artifactsFinal
        artifacts_changed_during_review = $artifactsChanged
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

    # ------------------------------------------------------------------------- output

    $commitWaitLine = ''
    if ($commitWaitMs -gt 0) { $commitWaitLine = "write lock : waited $commitWaitMs ms for another commit of this task" }
    if ($bridgeOutcome -ne 'usable reply') {
        Write-Host "codex-consult: $bridgeOutcome (wall $wallSeconds s)" -ForegroundColor Red
        if ($pendingNote) { Write-Host "pending    : $pendingNote" -ForegroundColor Yellow }
        if ($commitWaitLine) { Write-Host $commitWaitLine }
        foreach ($d in $driftLines) { Write-Host $d -ForegroundColor Yellow }
        Write-Host "reply file : $replyPath"
        if ($replyJsonRel) { Write-Host "reply json : $replyJsonPath" }
        Write-Host "events file: $eventsPath"
        foreach ($w in $engineWarnings) { Write-Host "warning    : $w" -ForegroundColor Yellow }
        if ($stderrText.Trim()) {
            Write-Host "--- $engineCmd stderr (tail) ---"
            Write-Host (($stderrText.Trim() -split "`r?`n" | Select-Object -Last 20) -join "`n")
        }
        exit 1
    }

    Write-Host "codex-consult: $bridgeOutcome - $lineageShown, mode $Mode, thread $threadId (source: $threadSource), wall $wallSeconds s"
    foreach ($w in $engineWarnings) { Write-Host "warning    : $w" -ForegroundColor Yellow }
    if ($denialRetryRecord) { Write-Host "denial retry: $(if ($denialRetryRecord.succeeded) { 'succeeded' } else { 'failed' }) in $($denialRetryRecord.wall_seconds) s" -ForegroundColor Yellow }
    if ($repairConsole) {
        Write-Host $repairConsole -ForegroundColor $(if ($repairedOk -and @($formatRetryRecord.drift).Count -eq 0) { 'Gray' } else { 'Yellow' })
        foreach ($dn in @($formatRetryRecord.drift)) { Write-Host "  drift: $dn" -ForegroundColor Yellow }
    }
    if ($threadCandidate -and $isCodex) { Write-Host "thread     : unknown - rollout candidate $threadCandidate did not contain consultation id $consultId (not used as a thread or a parent)" -ForegroundColor Yellow }
    if (-not $identity.Resolved) { Write-Host "reviewer   : identity unresolved ($($identity.Note)); this thread is never a parent" -ForegroundColor Yellow }
    if ($peakWarning) { Write-Host $peakWarning -ForegroundColor Yellow }
    if ($parse) {
        if ($structured) {
            if ($parse.VerdictInvalid) { Write-Host "verdict    : (invalid: $validationError)" -ForegroundColor Yellow }
            else { Write-Host "verdict    : $verdict - $(ConvertTo-OneLine $verdictReason)" }
            if ($verdictWarning) { Write-Host $verdictWarning -ForegroundColor Yellow }
            if ($findingIds.Count -gt 0) { Write-Host "findings   : $(Format-SeverityCounts $counts) -> $(Format-IdRange $findingIds) in findings.json" }
            else { Write-Host "findings   : none" }
            if (@($ingest.PriorEntries).Count -gt 0) {
                Write-Host ("prior      : " + ((@($ingest.PriorEntries) | ForEach-Object { "$($_.id) $($_.status)" }) -join ', '))
            }
            if (@($ingest.UnknownIds).Count -gt 0) {
                Write-Host "unknown ids: $(@($ingest.UnknownIds) -join ', ') (not in findings.json; ignored)" -ForegroundColor Yellow
            }
            if (@($ingest.UnknownSupersedes).Count -gt 0) {
                Write-Host "supersedes : $(@($ingest.UnknownSupersedes) -join ', ') not in findings.json (kept on the new finding only)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "structured : INVALID ($validationError) - raw text kept; no findings recorded" -ForegroundColor Yellow
        }
    }
    if ($pendingNote) { Write-Host "pending    : $pendingNote" -ForegroundColor Yellow }
    if ($commitWaitLine) { Write-Host $commitWaitLine }
    foreach ($d in $driftLines) { Write-Host $d -ForegroundColor Yellow }
    Write-Host "reply file : $replyPath"
    if ($replyJsonRel) { Write-Host "reply json : $replyJsonPath" }
    Write-Host "events file: $eventsPath"
    Write-Host ""
    Write-Host $replyBody
    if ($section) {
        Write-Host ""
        Write-Host $section
    }
    exit 0
} finally {
    foreach ($tmp in @($promptPath, $stderrPath, $repairLastPath, $repairEventsPath, $repairStderrPath, $repairPromptPath, $denialPromptPath, $denialStderrPath, $engineStdinPath)) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
    if (-not $keepLastMsg -and (Test-Path -LiteralPath $lastMsgPath)) {
        Remove-Item -LiteralPath $lastMsgPath -Force -ErrorAction SilentlyContinue
    }
    Exit-StoreCommit -Commit $commit
    Exit-TaskLock -Lock $lock
}
