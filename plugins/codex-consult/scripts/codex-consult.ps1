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
    wall_seconds, usage, drift[], original} after validation_error (null otherwise);
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
    brief to EVERY available roster entry, one after another, each a consultation
    of its own (own preflight, lock, pending record, parent thread, consultation id,
    handoffs/NN-codex-<ReplyName>-<provider>.md and ledger entry with
    panel {id, position, of, members[{provider, model, state run|skipped, reason}]}).
    A "weighty" entry joins only on framing, decision, core-contract, acceptance and
    stuck. Every member is shown the findings open when the panel started. A failing
    member does not stop the others - except when it leaves surviving processes,
    which hold the task's reservation (.consult.pending.json): the remaining members
    are then not started (summary: "skipped  not started: ..."). A summary block
    closes the run; exit 0 only when every member produced a usable reply. Not with
    -Provider, -Thread or -Mode resume. TEST HOOK: CODEX_CONSULT_TEST_SURVIVORS=<pid>
    makes a timeout kill report that live pid as a survivor.

    Invariants:
      * read-only sandbox by default; danger-full-access is refused outright
      * every exec-level option must precede the fork|resume subcommand
      * the prompt travels on stdin ('-'), never as an argument
      * the model and the provider are the resolved ones and are passed
        explicitly (-m, -c model_provider=...) whenever they are known
      * one consultation per task directory at a time: <task>/.consult.lock is a
        permanent file held open while a run lasts (never delete it to "unlock";
        closing the process releases it). <task>/.consult.pending.json exists
        only while a run is in progress or after one was interrupted; the next
        run checks it and refuses while that run's codex process may still be
        running. One Codex thread belongs to one task directory (not enforced).

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

    # Extra Codex config overrides for this run only, each key=value (repeatable, or one
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

    # Review panel: the same brief goes to EVERY available reviewer of the roster, one after
    # another, each as a consultation of its own (own preflight, lock, pending record,
    # parent thread, handoff files handoffs/NN-codex-<ReplyName>-<provider>.md and ledger
    # entry with a `panel` record). Needs a roster; not with -Provider, -Thread or -Mode
    # resume. A "weighty" roster entry joins only on framing, decision, core-contract,
    # acceptance and stuck. Exit 0 only when every member produced a usable reply.
    [switch]$Panel,

    # -Panel with every available entry, "weighty" ones included whatever the purpose.
    [switch]$PanelAll,

    # INTERNAL: set by -Panel for each member run (the member and the panel's parameters,
    # base64 of UTF-8 JSON). Never pass it yourself.
    [string]$PanelSpec = '',

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
    $DryRun = [bool]$pa.dry_run
    # This member's output reaches the -Panel run through a pipe: write it as UTF-8 (the
    # panel run reads it so).
    try { [Console]::OutputEncoding = $script:Utf8NoBom } catch { }
}
$panelRun = [bool]($Panel -or $PanelAll)

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
    if (@('output-schema', 'prompt-only') -notcontains $transportOverride) {
        Stop-WithError "-SchemaTransport must be output-schema or prompt-only (got '$transportOverride'); omit it to use what caps-v1 declares for the endpoint."
    }
    if ($Raw) { Stop-WithError "-SchemaTransport does not apply to -Raw$(if ($Purpose -eq 'chore') { ' (-Purpose chore is a plain-text consultation)' }) (a raw consultation sends no reply schema)." }
}
if ($FormatRetry -ne 0 -and $FormatRetry -ne 1) {
    Stop-WithError "-FormatRetry must be 0 or 1 (got $FormatRetry): at most one format-repair turn per consultation."
}
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
# entry (Select-PanelMembers). Each member then runs as a complete consultation of its own -
# a child run of this script (-PanelSpec), strictly one after another: own preflight, own
# task lock and recovery record, own parent thread (the newest of its lineage, or a new one;
# -Mode new: new for all), own consultation id, handoff files
# handoffs/NN-codex-<ReplyName>-<provider>.md and ledger entry with the `panel` record. A
# member that fails or is refused does not stop the others - unless it leaves surviving
# processes: they hold the task's reservation, so the remaining members are not started
# (recorded in the summary as skipped, exit 1). This run itself takes no lock
# and writes nothing; it prints a summary and exits 0 only when every member produced a
# usable reply (-DryRun: when every member's plan could be made).

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
    if (-not $DryRun -and -not $codexExePath) {
        Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
    }
    $panelConfig = Read-CodexConfigSubset -Path (Get-CodexConfigPath)
    $panelClock = Get-ConsultClock -Peek
    if ($panelClock.Error) { Stop-WithError $panelClock.Error }
    $panelSelection = Select-PanelMembers -Roster $roster -Config $panelConfig -Consults (Read-AllTaskConsults -CollabRoot $collabRoot) -Launcher ([string]$codexExePath) -LoginCache @{} -UtcNow $panelClock.Now.UtcDateTime -OpenAiBaseUrl ([string]$env:OPENAI_BASE_URL) -Model $Model -Purpose $Purpose -All:$PanelAll -SkipPreflight:$SkipPreflight
    if ($panelSelection.Error) { Stop-WithError $panelSelection.Error }
    $panelEntries = @($panelSelection.Members)
    $panelRunners = @($panelEntries | Where-Object { $_.State -eq 'run' })
    $panelId = [guid]::NewGuid().ToString()
    $panelShort = $panelId.Substring(0, 8)
    $panelMembersRecord = [object[]]@($panelEntries | ForEach-Object { [pscustomobject]@{ provider = $_.Entry.Provider; model = $_.Identity.Model; state = $_.State; reason = $_.Reason } })
    $panelSkippedRecord = [object[]]@($panelEntries | Where-Object { $_.State -ne 'run' } | ForEach-Object { [pscustomobject]@{ provider = $_.Entry.Provider; model = $_.Identity.Model; reason = $_.Reason } })
    # The findings every member is shown: those open when the panel starts.
    $panelListed = @()
    if (-not $Raw -and (Test-Path -LiteralPath $findingsPath -PathType Leaf)) {
        $panelStore = Read-FindingsFile -Path $findingsPath -Task $Task
        $panelListed = @(@($panelStore.findings) | Where-Object { $_ -and $script:OpenStatuses -contains [string](Get-PropertyValue $_ 'status' '') } | ForEach-Object { [string]$_.id })
    }
    $panelVerb = if ($DryRun) { 'would run' } else { 'run' }
    Write-Host "Panel $panelShort$(if ($DryRun) { ' (dry run - nothing is executed or written)' }): $($panelRunners.Count) of $($panelEntries.Count) roster entries $panelVerb, one after another (roster $($roster.Path); panel id $panelId)"
    foreach ($pm in $panelEntries) {
        Write-Host ("  #{0} {1} - {2}" -f $pm.Entry.Position, $pm.Identity.Lineage, $(if ($pm.State -eq 'run') { 'member' } else { "skipped: $($pm.Reason)" }))
    }
    $psHost = (Get-Process -Id $PID).Path
    $panelResults = @{}
    $k = 0
    $panelStarted = 0
    $panelBlocked = ''
    $previousLineage = ''
    foreach ($pm in $panelRunners) {
        $k++
        # One consultation per task at a time: a member that left surviving processes
        # holds the task's reservation (.consult.pending.json), and every later member
        # would be refused. They are not started; the summary says why (F15-3).
        if (-not $DryRun -and -not $panelBlocked) {
            $pendingNow = Read-PendingFile -Path $pendingPath
            if ($pendingNow.Error) {
                $panelBlocked = "not started: the task's recovery record cannot be used ($(ConvertTo-OneLine $pendingNow.Error))"
            } elseif ($pendingNow.Exists) {
                $activeNow = Test-PendingActive -Record $pendingNow.Record -Path $pendingPath
                if ($activeNow.Active) {
                    $stateNow = [string](Get-PropertyValue $pendingNow.Record 'state' '')
                    if ($previousLineage) { $panelBlocked = "not started: the previous member ($previousLineage) left surviving processes (.consult.pending.json state $stateNow); recover the task first" }
                    else { $panelBlocked = "not started: an earlier consultation of this task is still active (.consult.pending.json state $stateNow); recover the task first" }
                }
            }
        }
        if ($panelBlocked) {
            $panelResults[[int]$pm.Entry.Position] = [pscustomobject]@{ Exit = $null; Entry = $null; Refusal = ''; NotStarted = $panelBlocked }
            continue
        }
        $panelStarted++
        $previousLineage = $pm.Identity.Lineage
        $slug = ($pm.Entry.Provider.ToLowerInvariant() -replace '[^a-z0-9._-]', '-').Trim('-')
        if (-not $slug) { $slug = 'reviewer' }
        $spec = [pscustomobject]@{
            id              = $panelId
            position        = $k
            of              = $panelRunners.Count
            members         = $panelMembersRecord
            roster_position = $pm.Entry.Position
            provider        = $pm.Entry.Provider
            model           = $pm.Entry.Model
            skipped         = $panelSkippedRecord
            listed_ids      = [object[]]$panelListed
            args            = [pscustomobject]@{
                collab_dir       = $CollabDir
                mode             = $Mode
                brief            = $Brief
                prompt           = $Prompt
                purpose          = $Purpose
                effort           = $Effort
                sandbox          = $Sandbox
                max_words        = $MaxWords
                timeout_sec      = $TimeoutSec
                reply_name       = "$ReplyName-$slug"
                artifact         = [object[]]@($Artifact)
                raw              = [bool]$Raw
                codex_exe        = $CodexExe
                native_effort    = $NativeEffort
                off_peak_only    = [bool]$OffPeakOnly
                skip_preflight   = [bool]$SkipPreflight
                codex_config     = [object[]]@($CodexConfig)
                schema_transport = $transportOverride
                format_retry     = $FormatRetry
                dry_run          = [bool]$DryRun
            }
        }
        $specB64 = [Convert]::ToBase64String($script:Utf8NoBom.GetBytes((ConvertTo-Json -InputObject $spec -Depth 8 -Compress)))
        Write-Host ""
        Write-Host "=== panel $panelShort member $k of $($panelRunners.Count): $($pm.Identity.Lineage) (roster #$($pm.Entry.Position)) ==="
        $captured = New-Object System.Collections.Generic.List[string]
        $eapBefore = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $encBefore = $null
        try { $encBefore = [Console]::OutputEncoding; [Console]::OutputEncoding = $script:Utf8NoBom } catch { }
        & $psHost -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Task $Task -PanelSpec $specB64 2>&1 | ForEach-Object { $lineText = "$_"; $captured.Add($lineText); Write-Host $lineText }
        $childExit = $LASTEXITCODE
        if ($encBefore) { try { [Console]::OutputEncoding = $encBefore } catch { } }
        $ErrorActionPreference = $eapBefore
        $memberEntry = $null
        if (-not $DryRun) { $memberEntry = Find-PanelEntry -Path $sessionsPath -PanelId $panelId -Position $k }
        $refusal = @($captured | Where-Object { $_ -match '^codex-consult: ' }) | Select-Object -Last 1
        $panelResults[[int]$pm.Entry.Position] = [pscustomobject]@{ Exit = $childExit; Entry = $memberEntry; Refusal = $(if ($refusal) { $refusal -replace '^codex-consult: ', '' } else { "exit $childExit" }); NotStarted = '' }
    }

    # ------------------------------------------------------------------------- summary
    $rows = New-Object System.Collections.Generic.List[object]
    $allUsable = ($panelRunners.Count -gt 0)
    foreach ($pm in $panelEntries) {
        $row = [pscustomobject]@{ Lineage = $pm.Identity.Lineage; Status = ''; Counts = ''; Prior = ''; Tail = ''; Wide = $false }
        if ($pm.State -ne 'run') {
            $row.Status = 'skipped'
            $row.Counts = $pm.Reason
            $row.Wide = $true
        } else {
            $res = $panelResults[[int]$pm.Entry.Position]
            if ($res.NotStarted) {
                $row.Status = 'skipped'
                $row.Counts = $res.NotStarted
                $row.Wide = $true
                $allUsable = $false
            } elseif ($DryRun) {
                if ($res.Exit -eq 0) { $row.Status = 'planned' } else { $row.Status = "refused: $(ConvertTo-OneLine $res.Refusal)"; $row.Wide = $true; $allUsable = $false }
            } elseif ($null -eq $res.Entry) {
                $row.Status = "failed: $(ConvertTo-OneLine $res.Refusal)"
                $row.Wide = $true
                $allUsable = $false
            } else {
                $me = $res.Entry
                $outcome = [string](Get-PropertyValue $me 'bridge_outcome' '')
                $tail = "$(Get-PropertyValue $me 'wall_seconds' '?') s  $(Get-PropertyValue $me 'reply' '')"
                if ($outcome -ne 'usable reply') {
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
    Write-Host "Panel $($panelShort): $(if ($DryRun) { "$($panelRunners.Count) of $($panelEntries.Count) entries would run (dry run)" } else { "$panelStarted of $($panelEntries.Count) entries ran" })"
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
#                  entries that resolve to that model); skipped entries are recorded
$rosterRule = ''
$rosterEntry = $null
$rosterSkipped = @()
$rosterApplied = New-Object System.Collections.Generic.List[string]
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
        if (-not $rosterEntry -or $rosterEntry.Provider -cne [string]$panelMember.provider -or $rosterEntry.Model -cne [string]$panelMember.model) {
            Stop-WithError "the reviewer roster '$($roster.Path)' changed while the panel ran (entry $memberPosition is no longer $([string]$panelMember.provider) $([string]$panelMember.model)); this panel member was not started."
        }
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
        if ($rosterEntry -and -not $Model -and $rosterEntry.Model) {
            $identityModel = $rosterEntry.Model
            $modelSourceOverride = 'roster'
            $rosterApplied.Add('model')
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
        $identityProvider = $threadReviewer.Provider
        $providerSourceOverride = '-Thread'
        if (-not $Model) {
            $identityModel = $threadReviewer.Model
            $modelSourceOverride = '-Thread'
        }
        $rosterEntry = Find-RosterEntry -Roster $roster -Provider $identityProvider -Model $identityModel
    } else {
        $rosterRule = 'walk'
        $walk = Select-RosterReviewer -Roster $roster -Config $codexConfigScan -Consults $allConsults -Launcher ([string]$codexExePath) -LoginCache $loginCache -UtcNow $healthNow -OpenAiBaseUrl $openAiBaseUrl -Model $Model -SkipPreflight:$SkipPreflight
        if ($walk.Error) { Stop-WithError $walk.Error }
        $rosterEntry = $walk.Entry
        $rosterSkipped = @($walk.Skipped)
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
$anonymous = [bool]($rosterEntry -and $rosterEntry.Auth -eq 'none')

$identity = Resolve-ReviewerIdentity -Config $codexConfigScan -Provider $identityProvider -Model $identityModel -OpenAiBaseUrl $openAiBaseUrl
if ($identity.Error) { Stop-WithError $identity.Error }
if ($providerSourceOverride) { $identity.ProviderSource = $providerSourceOverride }
if ($modelSourceOverride) { $identity.ModelSource = $modelSourceOverride }
$reviewerRecord = New-ReviewerRecord -Identity $identity -Harness $harness
$lineage = $identity.Lineage
$modelLabel = $identity.Model
$reviewerLine = "Reviewer: $lineage (provider from $($reviewerRecord.provider_source), model from $($identity.ModelSource); $($identity.Display)"
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
    $preflightVerdict = Get-PreflightVerdict -Identity $identity -Config $codexConfigScan -Launcher ([string]$codexExePath) -Health $health -LoginCache $loginCache -Anonymous:$anonymous
    $preflight = $preflightVerdict.Preflight
    $preflightLabel = $preflightVerdict.Label
    $preflightRefusal = $preflightVerdict.Refusal
    if ($preflightVerdict.State -ne 'available' -and $rosterRule -eq 'thread') {
        # The thread cannot continue: say which reviewer a new thread would get.
        $alternative = Select-RosterReviewer -Roster $roster -Config $codexConfigScan -Consults $allConsults -Launcher ([string]$codexExePath) -LoginCache $loginCache -UtcNow $healthNow -OpenAiBaseUrl $openAiBaseUrl
        $hint = if ($alternative.Entry) { "; to continue with another reviewer, start a new thread: -Mode new; the roster would select $($alternative.Identity.Lineage)" } else { '; the roster has no available reviewer for a new thread either' }
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
        if ($rosterEntry) { $rosterLine = "Roster: $($roster.Path) - entry $rosterPosition of $rosterCount for -Thread $Thread, $lineage ($appliedText)" }
        else { $rosterLine = "Roster: $($roster.Path) - no entry for -Thread $Thread, $lineage (nothing applied)" }
    }
    $rosterRecord = [pscustomobject]@{
        path     = $roster.Path
        position = $rosterPosition
        skipped  = [object[]]@($rosterSkipped | ForEach-Object { [pscustomobject]@{ provider = $_.provider; model = $_.model; reason = $_.reason } })
        applied  = [object[]]$rosterApplied.ToArray()
    }
}
# The ledger's `panel` record of a -Panel member ($null otherwise): the same members list in
# every member's entry.
$panelRecord = $null
if ($panelMember) {
    $panelRecord = [pscustomobject]@{
        id       = [string]$panelMember.id
        position = [int]$panelMember.position
        of       = [int]$panelMember.of
        members  = [object[]]@(@($panelMember.members) | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ provider = [string]$_.provider; model = [string]$_.model; state = [string]$_.state; reason = [string]$_.reason } })
    }
}
if ($rosterLine -and -not $DryRun) { Write-Host $rosterLine }
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

# The prompt's last line; a rollout file is attributed to this run only if it holds it.
$consultId = [guid]::NewGuid().ToString()

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

if (-not $DryRun -and -not $codexExePath) {
    Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
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

# ----------------------------------------------------------------------------- lock + run
#
# Everything from here to the end runs while <task>/.consult.lock is HELD OPEN (not in
# -DryRun, which writes nothing at all): the lock is taken BEFORE the recovery record,
# sessions.json and findings.json are read and before the consult number n and the
# handoff number NN are allocated, and released in `finally` by closing the handle
# (an `exit` inside `try` still runs it; the lock file itself is permanent).
#
# Recovery record <task>/.consult.pending.json (atomic replace, only under the lock):
#   1. read it first: unusable -> refuse; a live codex process of an interrupted run
#      -> refuse; otherwise its reservation is consumed (numbering skips past it)
#   2. {state: reserved, n, nn, reply, consult_id}
#                                       after allocation - replaces the old record
#   3. {state: launching}               right before Start-Process (a failed write
#                                       aborts the run before codex exists)
#   4. {state: running, child_pid}      right after Start-Process; if this write fails
#                                       the codex tree is killed, the run is recorded
#                                       as failed and the record stays 'launching'
#   5. {state: survivors, survivors[]}  after a timeout kill that left survivors; kept
#   6. deleted after the ledger commit when codex is known to be gone
# If this process dies at any point, the record tells the next run what to check.
#
# Write order after the run:
#   1. handoffs/NN-codex-<slug>.reply.json  byte-for-byte copy of Codex's last message,
#                                           BEFORE any parsing (a failed copy is a
#                                           bridge failure; the temp original is kept)
#   2. handoffs/NN-codex-<slug>.md          header + verbatim reply (+ rendered section)
#   3. findings.json                        new findings, reviewer checks
#   4. sessions.json                        the ledger entry - the commit point
# Both JSON stores are replaced atomically (temp file + replace), and an existing
# store that is empty or unparseable is refused as corruption. A crash between 3 and
# 4 leaves findings or reviewer checks whose consult has no ledger entry;
# `codex-findings.ps1 -List` flags them as ORPHAN, and numbering never reuses a
# number that any finding, reviewer check, handoff file or reservation names.

$lock = $null
$keepPending = $false
$keepLastMsg = $false
if (-not $DryRun) {
    [void][IO.Directory]::CreateDirectory($handoffsDir)
    $lock = Enter-TaskLock -TaskDir $taskDir -Task $Task
    if (-not $lock.Acquired) { Stop-WithError $lock.Message }
}

try {
    # ------------------------------------------------------------------------- recovery record

    # Read and judged BEFORE anything is written (a dry run only reports).
    $pendingOld = $null
    $pendingCheck = $null
    $pendingRefusal = ''
    $pendingRead = Read-PendingFile -Path $pendingPath
    if ($pendingRead.Error) { Stop-WithError $pendingRead.Error }
    if ($pendingRead.Exists) {
        $pendingOld = $pendingRead.Record
        $pendingCheck = Test-PendingActive -Record $pendingOld -Path $pendingPath
        if ($pendingCheck.Active) {
            if ($DryRun) { $pendingRefusal = $pendingCheck.Message } else { Stop-WithError $pendingCheck.Message }
        }
    }

    # ------------------------------------------------------------------------- ledgers

    $sessions = Read-JsonStore -Path $sessionsPath
    if ($null -eq $sessions) {
        $sessions = [pscustomobject]@{
            task_id = $Task
            cwd     = $repoRoot
            codex   = [pscustomobject]@{
                tool     = $codexVersion
                consults = [object[]]@()
            }
        }
        if (-not $DryRun) { Write-JsonFile -Path $sessionsPath -Object $sessions }
    }
    if (-not $sessions.PSObject.Properties['codex']) {
        $sessions | Add-Member -NotePropertyName 'codex' -NotePropertyValue ([pscustomobject]@{ tool = $codexVersion; consults = [object[]]@() })
    }
    if (-not $sessions.codex.PSObject.Properties['consults']) {
        $sessions.codex | Add-Member -NotePropertyName 'consults' -NotePropertyValue ([object[]]@())
    }
    $sessions.codex.tool = $codexVersion

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

    # The old recovery record's reservation is consumed here: numbering skips past its
    # n / nn (and past everything else on disk that names a number).
    $numbers = Get-NextNumbers -Consults $consults -Store $findingsStore -HandoffsDir $handoffsDir -Leftover $pendingOld
    $consultN = $numbers.N
    $nn = $numbers.Nn
    $recoveredLine = ''
    if ($pendingOld) {
        $state = [string](Get-PropertyValue $pendingOld 'state' '')
        if ($DryRun) {
            if ($pendingRefusal) { $recoveredLine = "$pendingPath (state '$state', n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn)): the next run would be REFUSED - $pendingRefusal" }
            else { $recoveredLine = "$pendingPath (state '$state', n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn); $($pendingCheck.Check)): the next run recovers it; numbering continues past it." }
        } elseif ($numbers.Recovered) {
            $recoveredLine = "recovered reservation n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn) (state '$state' of an interrupted run; $($pendingCheck.Check)); numbering continues past it."
            Write-Host "codex-consult: $recoveredLine" -ForegroundColor Yellow
        } else {
            # Its consultation reached the ledger (e.g. a failed registration or timeout
            # survivors that have exited since): nothing to recover, only to clear.
            $recoveredLine = "cleared the recovery record of consult n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn) (state '$state'; $($pendingCheck.Check)); its ledger entry exists."
            Write-Host "codex-consult: $recoveredLine" -ForegroundColor Yellow
        }
    }
    # NB: PowerShell variable names are case-insensitive - never call these $replyName,
    # that would silently clobber the -ReplyName parameter.
    $replyFileName = "$nn-codex-$ReplyName.md"
    $eventsFileName = "$nn-codex-$ReplyName.events.jsonl"
    $replyJsonFileName = "$nn-codex-$ReplyName.reply.json"
    $replyPath = Join-Path $handoffsDir $replyFileName
    $eventsPath = Join-Path $handoffsDir $eventsFileName
    $replyJsonPath = Join-Path $handoffsDir $replyJsonFileName
    $replyRel = "handoffs/$replyFileName"
    $eventsRel = "handoffs/$eventsFileName"
    $replyJsonPlanned = ''
    if (-not $Raw) { $replyJsonPlanned = "handoffs/$replyJsonFileName" }
    # This run's reservation replaces the consumed record (atomically; if the write
    # fails the old record is left intact and nothing was started).
    $pendingRecord = $null
    if (-not $DryRun) {
        $pendingRecord = New-PendingRecord -State 'reserved' -N $consultN -Nn $nn -Reply $replyRel -Started $runStarted -Launcher ([string]$codexExePath) -ConsultId $consultId
        try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
            Stop-WithError "could not write the recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); nothing was started."
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

    $commandStr = 'codex ' + (Format-Argv $argv)

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
            thread_source                   = 'events|rollout (verified by consultation id)|unknown'
            thread_candidate                = '<"" or an unverified rollout uuid>'
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
            sandbox                         = $Sandbox
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
            format_retry                    = $(if (-not $repairEnabled) { $null } else { '<null, or {attempted, reason, succeeded, thread, wall_seconds, usage, drift, original} after a format-repair turn>' })
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
            verdict                         = $(if ($Raw) { '' } else { "<$($verdictRule -replace ', | or ', '|'), or '' when unavailable>" })
            verdict_reason                  = $(if ($Raw) { '' } else { '<one sentence>' })
            findings                        = $previewFindings
            finding_ids                     = [object[]]$previewIds
            prior_findings                  = [object[]]@($listedIds | ForEach-Object { [pscustomobject]@{ id = $_; status = '<fixed|still-open|not-checked|unknown-id>' } })
            unchecked_prior_blockers        = [object[]]@()
            usage                           = [pscustomobject]@{ input_tokens = '<n>'; cached_input_tokens = '<n>'; output_tokens = '<n>'; reasoning_output_tokens = '<n>' }
            wall_seconds                    = 0
        }
        Write-Host "DRY RUN - nothing was executed and no file was written." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "repo root   : $repoRoot"
        Write-Host "task dir    : $taskDir"
        Write-Host "sessions    : $sessionsPath"
        if (-not $Raw) { Write-Host "findings    : $findingsPath ($($openFindings.Count) open finding(s) listed in the prompt)" }
        Write-Host "lock        : $lockPath (held open for the run; not in a dry run)"
        if ($recoveredLine) { Write-Host "pending     : $recoveredLine" -ForegroundColor Yellow }
        if ($codexExePath) { Write-Host "launcher    : $codexExePath" }
        else { Write-Host "launcher    : (codex not found on PATH)" -ForegroundColor Yellow }
        Write-Host "codex       : $codexVersion"
        Write-Host "config      : $($identity.ConfigPath)$(if (-not $codexConfigScan.Exists) { ' (not found)' })"
        Write-Host "reviewer    : $($reviewerLine -replace '^Reviewer: ', '')"
        Write-Host "lineage     : $lineage"
        if ($preflightLabel -match 'a real run is refused') { Write-Host "preflight   : $preflightLabel" -ForegroundColor Yellow }
        else { Write-Host "preflight   : $preflightLabel" }
        if ($rosterLine) { Write-Host $rosterLine }
        if ($preflightWarning) { Write-Host "WARNING: $preflightWarning" -ForegroundColor Yellow }
        Write-Host "model       : $modelLabel"
        Write-Host "purpose     : $purposeLabel (effort $effortSent, max words $maxWordsResolved)"
        Write-Host "effort      : $effortSent sent (requested $($effortPlan.Requested), mapping $($effortPlan.Mapping), by $($effortPlan.Basis))"
        if ($peakWarning) { Write-Host "peak        : $peakLabel" -ForegroundColor Yellow; Write-Host $peakWarning -ForegroundColor Yellow }
        else { Write-Host "peak        : $peakLabel" }
        if ($Raw) { Write-Host "reply format: raw text ($(if ($Purpose -eq 'chore') { '-Purpose chore' } else { '-Raw' }): no schema, no findings bookkeeping)" }
        else {
            Write-Host "schema      : $schemaPath"
            if ($schemaTransport -eq 'output-schema') { Write-Host "transport   : output-schema ($schemaTransportBasis): passed as --output-schema" }
            else { Write-Host "transport   : prompt-only ($schemaTransportBasis): --output-schema is NOT passed; the schema travels in the prompt, the reply is validated locally" }
        }
        if ($repairEnabled) { Write-Host 'format retry : 1 attempt if the reply is not valid JSON' } else { Write-Host 'format retry : 0 (off)' }
        Write-Host "mode        : $Mode"
        if ($Mode -eq 'new') { Write-Host "thread      : (a new thread will be created)" }
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
        Write-Host "prompt (stdin, $($promptText.Length) chars):"
        Write-Host "----"
        Write-Host $promptText
        Write-Host "----"
        Write-Host ""
        Write-Host "reply file  : $replyPath"
        if (-not $Raw) { Write-Host "reply json  : $replyJsonPath" }
        Write-Host "events file : $eventsPath"
        Write-Host "last message: $lastMsgPath (temp)"
        Write-Host ""
        Write-Host "sessions.json entry preview:"
        Write-Host (ConvertTo-Json -InputObject $preview -Depth 10)
        exit 0
    }

    # ------------------------------------------------------------------------- run

    Write-Utf8NoBom -Path $promptPath -Text $promptText

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

    # (3) launching - from the next statement on, a crash may leave a codex process
    # whose pid is not recorded; the next run then scans for one (Test-PendingActive).
    $pendingRecord.state = 'launching'
    $pendingRecord.note = 'codex is being started; its pid is not recorded yet'
    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
        Stop-WithError "could not write the recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); codex was not started."
    }

    $startedAt = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = -1
    $bridgeOutcome = ''
    $argStr = (($argv | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' ')

    $proc = $null
    try {
        $proc = Start-Process -FilePath $codexExePath -ArgumentList $argStr `
            -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
            -RedirectStandardOutput $eventsPath `
            -RedirectStandardError $stderrPath `
            -RedirectStandardInput $promptPath
    } catch {
        $bridgeOutcome = "failed: could not start codex - $($_.Exception.Message)"
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
            Write-PendingFile -Path $pendingPath -Record $pendingRecord
        } catch {
            $registerError = ConvertTo-OneLine $_.Exception.Message
        }
        if ($registerError) {
            # An unregistered codex must not outlive this run: stop it now. The record
            # on disk stays 'launching', so the next run checks for a codex process.
            $survivors = Stop-ProcessTree -Process $proc   # [int[]]; never wrap in @(): that nests the array
            $bridgeOutcome = "failed: could not register the codex process ($registerError); codex was stopped"
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
    $rawReply = (Read-SharedText -Path $lastMsgPath).Trim()

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
    $replyJsonRel = ''
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
        $originalRel = "handoffs/$nn-codex-$ReplyName.original.md"
        $originalFull = Join-Path $handoffsDir "$nn-codex-$ReplyName.original.md"
        try { [IO.File]::Copy($lastMsgPath, $originalFull, $true) } catch { Write-Utf8NoBom -Path $originalFull -Text $rawReply }
        $repairEffort = Get-RepairEffort -Identity $identity -EffortPlan $effortPlan
        $repairArgv = @('exec', '--sandbox', 'read-only', '--color', 'never', '--json')
        if ($identity.ModelSource -ne 'unknown') { $repairArgv += @('-m', $identity.Model) }
        $repairArgv += @('-c', ('model_reasoning_effort="' + (ConvertTo-TomlBasicString $repairEffort) + '"'))
        if ($identity.ProviderSource) { $repairArgv += @('-c', ('model_provider="' + (ConvertTo-TomlBasicString $identity.Provider) + '"')) }
        foreach ($ec in $extraConfig) { $repairArgv += @('-c', $ec) }
        $repairArgv += @('-o', $repairLastPath, 'resume', $threadId, '-')
        $repairSchema = ([IO.File]::ReadAllText($schemaPath, $script:Utf8NoBom).Trim() -replace "`r`n", "`n") -replace "`n", $nl
        $repairPrompt = 'Your last message was prose, not the required JSON. Reply with exactly one bare JSON object satisfying the JSON Schema below - no fence, nothing before or after it. Convert, do not re-answer: copy your previous content unchanged (the same Q1..Qn answers verbatim inside reply_markdown, the same findings, the same Requested checks, the same prior-finding statuses and the same verdict); add or omit nothing.' +
            "$nl$nl" + "JSON Schema of the reply:$nl$repairSchema" + "$nl$nl" + "Consultation id: $consultId"
        Write-Utf8NoBom -Path $repairPromptPath -Text $repairPrompt
        $repairTimeout = [Math]::Min($TimeoutSec, 300)
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
        if ($repairThread -and $repairThread -ne $threadId) { $drift.Add('repair returned a different thread id') }
        if (-not $repairProblem) {
            $repairedOk = $true
            $parse = $repairParse
            $validationError = $parse.ValidationError
            foreach ($d in (Get-FormatRepairDrift -Prose $originalProse -Reply $parse.Reply)) { $drift.Add($d) }
            # The .reply.json holds the repaired object, byte for byte.
            try { [IO.File]::Copy($repairLastPath, $replyJsonPath, $true); $replyJsonRel = $replyJsonPlanned } catch { }
        } else {
            $validationError = "$validationError (format repair failed: $(ConvertTo-OneLine $repairProblem))"
        }
        $formatRetryRecord = [pscustomobject]@{
            attempted    = $true
            reason       = $repairReason
            succeeded    = $repairedOk
            thread       = $repairThread
            wall_seconds = $repairWall
            usage        = $repairUsage
            drift        = [object[]]$drift.ToArray()
            original     = $originalRel
        }
        $repairConsole = "format repair: $(if ($repairedOk) { 'succeeded' } else { 'failed' }) in $repairWall s; drift: $($drift.Count) note(s)"
    }

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

    # Classified provider failure (null on success): what the endpoint said - an SSE
    # `data:{"error":...}` line, the event-stream error, stderr - or the bridge's own reason.
    # Later preflights read it back per endpoint (Get-EndpointHealth).
    $providerFailure = $null
    if ($bridgeOutcome -ne 'usable reply') {
        $sseLines = @(($stderrText -split "`r?`n") | Where-Object { $_ -match '^\s*data:\s*\{' })
        $stderrTail = (($stderrText.Trim() -split "`r?`n") | Select-Object -Last 1)
        $providerFailure = New-ProviderFailure -Texts @(($sseLines | Select-Object -Last 1), $eventError, $stderrTail, ($bridgeOutcome -replace '^failed:\s*', ''))
    }

    # ------------------------------------------------------------------------- 2. reply file

    $parentLine = 'Parent thread: (none - new thread).'
    if ($parentNote -and -not $parentThread) { $parentLine = "Parent thread: (none - new thread; $parentNote)." }
    if ($parentThread) { $parentLine = "Parent thread: ``$parentThread``." }
    $resultThread = '(unknown)'
    if ($threadId) { $resultThread = "``$threadId``" }
    $threadSourceText = $threadSource
    if ($threadCandidate) { $threadSourceText += "; unverified rollout candidate ``$threadCandidate`` did not contain this run's consultation id - not used as a thread or a parent" }
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
    $headerLines.Add("# Handoff $nn - Codex: $ReplyName")
    $headerLines.Add('')
    $headerLines.Add("Date: $($startedAt.ToString('yyyy-MM-dd HH:mm', $script:Invariant)) local. Author: Codex (model $modelLabel, effort $effortSent), Codex CLI $codexVersionShort.")
    $headerLines.Add($reviewerLine)
    $preflightLine = "Preflight: $preflight."
    if ($preflightWarning) { $preflightLine += " WARNING: $preflightWarning." }
    $headerLines.Add($preflightLine)
    if ($rosterLine) { $headerLines.Add("$rosterLine.") }
    $headerLines.Add("Effort: $effortSent sent (requested $($effortPlan.Requested), mapping $($effortPlan.Mapping), by $($effortPlan.Basis); not confirmed by the provider). Consultation id: $consultId.")
    if ($peakWarning) { $headerLines.Add(($peakWarning -replace 'this consultation runs at', 'this consultation ran at')) }
    if ($recoveredLine) { $headerLines.Add("Recovery record: $recoveredLine") }
    $headerLines.Add("Invocation: ``codex-consult.ps1`` (mode: $Mode, sandbox: $Sandbox, purpose: $purposeLabel). Argv: ``$commandStr`` (prompt on stdin).")
    $headerLines.Add("$parentLine Result thread: $resultThread (source: $threadSourceText).")
    $headerLines.Add("$briefLine $reviewedLine")
    foreach ($d in $driftLines) { $headerLines.Add($d) }
    $headerLines.Add("Bridge outcome: $bridgeOutcome. Wall time: $wallSeconds s. Tokens: $(Format-Usage $usage).")
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
    $headerLines.Add("Raw event stream: ``$eventsRel``.")
    $headerLines.Add('Verbatim reply follows.')
    $headerLines.Add('')
    $headerLines.Add('---')
    $headerLines.Add('')
    $header = $headerLines.ToArray() -join "`n"

    $body = $replyBody
    if (-not $rawReply) {
        $body = "_(no reply captured)_"
        if ($eventError) {
            $body += "`n`nCodex reported: $eventError"
        }
        if ($stderrText.Trim()) {
            $body += "`n`n```````n" + $stderrText.Trim() + "`n``````"
        }
    } elseif (-not $body) {
        $body = '_(empty reply_markdown)_'
    }
    $section = ''
    if ($structured) { $section = Format-StructuredSection -Parse $parse -Ingest $ingest }
    $replyText = $header + "`n" + ($body -replace "`r`n", "`n") + "`n"
    if ($section) { $replyText += "`n---`n`n" + ($section -replace "`r`n", "`n") + "`n" }
    if ($repairedOk) { $replyText += "`n---`n`n## Original reply (prose, before format repair)`n`n" + ($originalProse -replace "`r`n", "`n") + "`n" }
    Write-Utf8NoBom -Path $replyPath -Text $replyText

    # ------------------------------------------------------------------------- 3. findings.json

    if ($ingest -and $ingest.Changed) {
        Write-FindingsFile -Path $findingsPath -Store $findingsStore
    }

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
        sandbox                         = $Sandbox
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
        verdict                         = $verdict
        verdict_reason                  = $verdictReason
        findings                        = [pscustomobject]@{ blocker = $counts.blocker; major = $counts.major; minor = $counts.minor; note = $counts.note }
        finding_ids                     = [object[]]$findingIds
        prior_findings                  = [object[]]$priorForLedger
        unchecked_prior_blockers        = [object[]]$uncheckedPrior
        usage                           = $usage
        wall_seconds                    = $wallSeconds
    }
    $newConsults = @()
    $newConsults += $consults
    $newConsults += $entry
    $sessions.codex.consults = [object[]]$newConsults
    Write-JsonFile -Path $sessionsPath -Object $sessions

    # (6) The ledger is committed and codex is known to be gone: the recovery record
    # has nothing left to protect (still under the lock). Kept after a failed
    # registration ('launching') or with timeout survivors.
    $pendingNote = ''
    if ($keepPending) {
        # The ledger now holds this run's entry: the saved prose is no longer orphaned.
        if ($pendingRecord -and $pendingRecord.PSObject.Properties['original'] -and $pendingRecord.original) {
            $pendingRecord.original = ''
            $pendingRecord.first_reply = ''
            try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch { }
        }
        $pendingNote = "recovery record kept: $pendingPath (state '$($pendingRecord.state)')"
    } else {
        $rmError = Remove-PendingFile -Path $pendingPath
        if ($rmError) { $pendingNote = "could not remove $pendingPath ($rmError); the next run will find codex gone and consume it" }
    }

    # ------------------------------------------------------------------------- output

    if ($bridgeOutcome -ne 'usable reply') {
        Write-Host "codex-consult: $bridgeOutcome (wall $wallSeconds s)" -ForegroundColor Red
        if ($pendingNote) { Write-Host "pending    : $pendingNote" -ForegroundColor Yellow }
        foreach ($d in $driftLines) { Write-Host $d -ForegroundColor Yellow }
        Write-Host "reply file : $replyPath"
        if ($replyJsonRel) { Write-Host "reply json : $replyJsonPath" }
        Write-Host "events file: $eventsPath"
        if ($stderrText.Trim()) {
            Write-Host "--- codex stderr (tail) ---"
            Write-Host (($stderrText.Trim() -split "`r?`n" | Select-Object -Last 20) -join "`n")
        }
        exit 1
    }

    Write-Host "codex-consult: $bridgeOutcome - $lineage, mode $Mode, thread $threadId (source: $threadSource), wall $wallSeconds s"
    if ($repairConsole) {
        Write-Host $repairConsole -ForegroundColor $(if ($repairedOk -and @($formatRetryRecord.drift).Count -eq 0) { 'Gray' } else { 'Yellow' })
        foreach ($dn in @($formatRetryRecord.drift)) { Write-Host "  drift: $dn" -ForegroundColor Yellow }
    }
    if ($threadCandidate) { Write-Host "thread     : unknown - rollout candidate $threadCandidate did not contain consultation id $consultId (not used as a thread or a parent)" -ForegroundColor Yellow }
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
    foreach ($tmp in @($promptPath, $stderrPath, $repairLastPath, $repairEventsPath, $repairStderrPath, $repairPromptPath)) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
    if (-not $keepLastMsg -and (Test-Path -LiteralPath $lastMsgPath)) {
        Remove-Item -LiteralPath $lastMsgPath -Force -ErrorAction SilentlyContinue
    }
    Exit-TaskLock -Lock $lock
}
