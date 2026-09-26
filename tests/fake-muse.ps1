# FAKE muse (Meta's Muse Code CLI) for harness-muse.ps1 - never calls any model and never reads
# a credential. Started through fake-muse.cmd, which hands the command line over as
# FAKE_MUSE_ARGS (parsed here with the MS C runtime quoting the bridge uses, so a path with
# spaces arrives whole). `exec --json` prints MSP JSONL records shaped like the real CLI's
# (Muse Code 1.4.0, a sanitized probe of a completed `muse exec --json --output-schema` run with
# a read_file tool call): every record {schema_version, id, stream{kind: session, id},
# sequence, recorded_at, record_type, durability, causation_id, payload_type,
# payload_schema_version, payload}; payloads runtime.command.accepted, session.run.linked,
# run.model.configured {provider_id meta, profile_id tbh, model_id, display_label, source},
# turn.input.user, run.lifecycle.started, task.stream.linked, task.lifecycle.* (a model response
# task and a tool.read_file task), tool.result, run.output.delta and ONE run.terminal.<kind>
# {kind run_terminal, terminal, text, reason}. Ids are generated (no real session id).
# It is STRICT about the real flags: any other argument, a missing value, an unreadable
# --prompt-file or --output-schema, a --reasoning-effort outside the CLI's list, an
# --approval-mode other than never or a --max-model-steps that is not a positive integer ->
# stderr "error: ..." and exit 2 (the CLI's usage error).
#   `--version`                 prints "muse <FAKE_MUSE_VERSION or 9.9.9-fake>";
#                               FAKE_MUSE_VERSION_LOG=<path> gets one line per call
#   exec:
#   FAKE_MUSE_REPLY=<file>        the terminal text (default {"answer":"fake"})
#   FAKE_MUSE_RESUME_REPLY=<file> on a --session-id turn (the bridge's format repair or a
#                                 resume): this reply instead
#   FAKE_MUSE_TERMINAL=<kind>     failed | cancelled (default completed); text null, reason
#                                 FAKE_MUSE_REASON; exit 1 unless FAKE_MUSE_EXIT is set
#   FAKE_MUSE_REASON=<text>       payload.reason of the terminal record
#   FAKE_MUSE_EXIT=<n>            exit n after the records (1, 2, 130, 143 ...)
#   FAKE_MUSE_USAGE_ERROR=1       no records: stderr "error: ..." and exit 2
#   FAKE_MUSE_STDERR=<text>       one more stderr line (after the two informational ones)
#   FAKE_MUSE_SESSION=other       on --session-id: a NEW session (a mismatch); =notuuid: the
#                                 session id is not a uuid; default: the requested id on
#                                 --session-id, a new uuid otherwise
#   FAKE_MUSE_TWOSESSIONS=1       the second half of the records on another session stream
#   FAKE_MUSE_MODEL=<model>       run.model.configured serves this model (a drift);
#                                 FAKE_MUSE_NOMODEL=1: no run.model.configured record
#   FAKE_MUSE_SCHEMA_VERSION=<n>  every record's schema_version (default 1)
#   FAKE_MUSE_TWOTERMINALS=1      two run_terminal records;  FAKE_MUSE_NOTERMINAL=1: none
#   FAKE_MUSE_TERMINAL_STREAM=run the terminal record on a run stream (off the session)
#   (wave 23b, F09-3 - the provenance of the evidence; every record names its run in
#   payload.run_stream {kind run, id}, like the real CLI's)
#   FAKE_MUSE_LINK=none | task | two  no session.run.linked record | that record on a task
#                                 (sub-)stream | a second one linking ANOTHER run
#   FAKE_MUSE_MODEL_STREAM=task   the run.model.configured record on a task (sub-)stream
#   FAKE_MUSE_MODEL_RUN=other     the run.model.configured record names ANOTHER run stream
#   FAKE_MUSE_TERMINAL_RUN=other  the run_terminal record names ANOTHER run stream
#   FAKE_MUSE_PARTIAL=1           a truncated JSON line after the terminal (no newline)
#   FAKE_MUSE_WRITE=<rel path>    writes that file (relative to the working directory) on a
#                                 turn without --session-id (=<path>|all: on every turn)
#   FAKE_MUSE_HANG=1              sleeps 60 s after the first records (a timeout kill)
#   FAKE_MUSE_DELAY_MS=<ms>       sleeps that long before the answer
#   FAKE_MUSE_LOG=<path>          RAW: <FAKE_MUSE_ARGS>, ARG: <each argument>, STDIN-BYTES: <n>,
#                                 PROMPT-FILE: <path>, then PROMPT: and the prompt file's text
#                                 (a turn without --session-id); FAKE_MUSE_RESUME_LOG=<path>: the
#                                 same for a --session-id turn
#   FAKE_MUSE_COUNT=<path>        one line per exec turn ("exec <session or new>")
#   FAKE_MUSE_PIDFILE=<path>      its pid
$ErrorActionPreference = 'Stop'
$u8 = New-Object System.Text.UTF8Encoding($false)
$raw = [string]$env:FAKE_MUSE_ARGS
function Out-Bytes { param([string]$Text) $b = $u8.GetBytes($Text); $s = [Console]::OpenStandardOutput(); $s.Write($b, 0, $b.Length); $s.Flush() }
function Err-Bytes { param([string]$Text) $b = $u8.GetBytes($Text + "`r`n"); $s = [Console]::OpenStandardError(); $s.Write($b, 0, $b.Length); $s.Flush() }
function J { param($Obj) return (ConvertTo-Json -InputObject $Obj -Compress -Depth 30) }
# (retried on a sharing violation: parallel panel members share the harness's variables)
function Invoke-FakeWrite { param([scriptblock]$Do) for ($i = 0; $i -lt 40; $i++) { try { & $Do; return } catch { Start-Sleep -Milliseconds 50 } }; & $Do }
function Stop-Usage { param([string]$Why) Err-Bytes "error: $Why"; Err-Bytes 'Usage: muse exec [OPTIONS]'; exit 2 }

# The command line, split by the MS C runtime rules the bridge quotes for: blanks separate
# arguments outside double quotes; "" inside quotes is one quote.
function Split-CommandLine {
    param([string]$Line)
    $args2 = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    $inQ = $false
    $have = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $ch = $Line[$i]
        if ($ch -eq '"') {
            if ($inQ -and $i + 1 -lt $Line.Length -and $Line[$i + 1] -eq '"') { [void]$sb.Append('"'); $i++; continue }
            $inQ = -not $inQ; $have = $true; continue
        }
        if (-not $inQ -and ($ch -eq ' ' -or $ch -eq "`t")) {
            if ($have) { $args2.Add($sb.ToString()); [void]$sb.Clear(); $have = $false }
            continue
        }
        [void]$sb.Append($ch); $have = $true
    }
    if ($have) { $args2.Add($sb.ToString()) }
    return , ([string[]]$args2.ToArray())
}
$argv = Split-CommandLine $raw

if ($argv.Count -ge 1 -and $argv[0] -eq '--version') {
    if ($env:FAKE_MUSE_VERSION_LOG) { Invoke-FakeWrite { [IO.File]::AppendAllText($env:FAKE_MUSE_VERSION_LOG, "version`n") } }
    Out-Bytes ("muse $(if ($env:FAKE_MUSE_VERSION) { $env:FAKE_MUSE_VERSION } else { '9.9.9-fake' })`n")
    exit 0
}
if ($argv.Count -lt 1 -or $argv[0] -ne 'exec') { Stop-Usage "unrecognized subcommand '$(if ($argv.Count -ge 1) { $argv[0] })'" }

# ---- exec: the real flags only
$valueFlags = @('--prompt-file', '--output-schema', '--model', '--reasoning-effort', '--approval-mode', '--max-model-steps', '--session-id')
$switchFlags = @('--json', '--no-foreign-personal-context', '--disable-web-tools', '--disable-write', '--disable-shell')
$opt = @{}
for ($i = 1; $i -lt $argv.Count; $i++) {
    $a = $argv[$i]
    if ($switchFlags -ccontains $a) { $opt[$a] = $true; continue }
    if ($valueFlags -ccontains $a) {
        if ($i + 1 -ge $argv.Count) { Stop-Usage "a value is required for '$a'" }
        $opt[$a] = $argv[$i + 1]; $i++; continue
    }
    Stop-Usage "unexpected argument '$a' found"
}
if (-not $opt['--json']) { Stop-Usage 'the fake only speaks --json' }
if (-not $opt['--prompt-file']) { Stop-Usage "the following required argument was not provided: --prompt-file (or a prompt)" }
$promptFile = [string]$opt['--prompt-file']
if (-not (Test-Path -LiteralPath $promptFile -PathType Leaf)) { Stop-Usage "cannot read prompt file '$promptFile'" }
if ($opt['--output-schema'] -and -not (Test-Path -LiteralPath ([string]$opt['--output-schema']) -PathType Leaf)) { Stop-Usage "cannot read output schema '$($opt['--output-schema'])'" }
if (-not $opt['--model']) { Stop-Usage 'the fake needs --model' }
if ($opt['--reasoning-effort'] -and @('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra') -cnotcontains [string]$opt['--reasoning-effort']) { Stop-Usage "invalid value '$($opt['--reasoning-effort'])' for '--reasoning-effort'" }
if ($opt['--approval-mode'] -and [string]$opt['--approval-mode'] -cne 'never') { Stop-Usage "the fake takes --approval-mode never only" }
$steps = 0
if ($opt['--max-model-steps'] -and (-not [int]::TryParse([string]$opt['--max-model-steps'], [ref]$steps) -or $steps -lt 1)) { Stop-Usage "invalid value '$($opt['--max-model-steps'])' for '--max-model-steps'" }
if ($env:FAKE_MUSE_USAGE_ERROR -eq '1') { Stop-Usage "unexpected argument '--fake-usage-error' found" }

$stdinBytes = @()
try {
    $ms = New-Object System.IO.MemoryStream
    [Console]::OpenStandardInput().CopyTo($ms)
    $stdinBytes = $ms.ToArray()
} catch { $stdinBytes = @() }
$promptText = [IO.File]::ReadAllText($promptFile, $u8)
$conv = [string]$opt['--session-id']
$model = [string]$opt['--model']
$log = if ($conv -and $env:FAKE_MUSE_RESUME_LOG) { $env:FAKE_MUSE_RESUME_LOG } elseif (-not $conv) { $env:FAKE_MUSE_LOG } else { '' }
if ($log) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("RAW: $raw")
    foreach ($a in $argv) { $lines.Add("ARG: $a") }
    $lines.Add("STDIN-BYTES: $($stdinBytes.Length)")
    $lines.Add("PROMPT-FILE: $promptFile")
    $lines.Add('PROMPT:')
    Invoke-FakeWrite { [IO.File]::WriteAllText($log, (($lines.ToArray() -join "`n") + "`n" + $promptText), $u8) }
}
if ($env:FAKE_MUSE_COUNT) { Invoke-FakeWrite { [IO.File]::AppendAllText($env:FAKE_MUSE_COUNT, "exec $(if ($conv) { $conv } else { 'new' })`n") } }
if ($env:FAKE_MUSE_PIDFILE) { Invoke-FakeWrite { [IO.File]::WriteAllText($env:FAKE_MUSE_PIDFILE, "$PID") } }

# ---- the session and the records
$session = [guid]::NewGuid().ToString()
if ($conv -and $env:FAKE_MUSE_SESSION -ne 'other') { $session = $conv }
if ($env:FAKE_MUSE_SESSION -eq 'notuuid') { $session = 'session-1' }
$command = [guid]::NewGuid().ToString()
$schemaVersion = 1
if ($env:FAKE_MUSE_SCHEMA_VERSION) { $schemaVersion = [int]$env:FAKE_MUSE_SCHEMA_VERSION }
$script:seq = 0
$script:streamId = $session
# a sub-stream (a task stream) and another run - the F09-3 knobs' foreign provenance
$subStream = [guid]::NewGuid().ToString()
$otherRun = [pscustomobject][ordered]@{ kind = 'run'; id = [guid]::NewGuid().ToString() }
function Rec {
    param([string]$RecordType, [string]$PayloadType, $Payload, [string]$Durability = 'durable', [string]$StreamKind = 'session')
    $script:seq++
    $o = [pscustomobject][ordered]@{
        schema_version         = $schemaVersion
        id                     = ('018f0000-0000-7000-8000-{0:x12}' -f (50000 + 2 * $script:seq))
        stream                 = [pscustomobject][ordered]@{ kind = $StreamKind; id = $(if ($StreamKind -eq 'session') { $script:streamId } elseif ($StreamKind -eq 'task') { $subStream } else { $command }) }
        sequence               = $script:seq
        recorded_at            = [long]1780531400000000 + 2 * $script:seq
        record_type            = $RecordType
        durability             = $Durability
        causation_id           = $command
        payload_type           = $PayloadType
        payload_schema_version = 1
        payload                = $Payload
    }
    Out-Bytes ((J $o) + "`n")
}
$runStream = [pscustomobject][ordered]@{ kind = 'run'; id = $command }
function P { param([string]$Kind, [hashtable]$More = @{}) $p = [ordered]@{ kind = $Kind; command_id = $command; run_stream = $runStream }; foreach ($k in $More.Keys) { $p[$k] = $More[$k] }; return [pscustomobject]$p }
function Task-Records {
    param([string]$TaskKind, [string]$Output = '')
    $tid = [guid]::NewGuid().ToString()
    $ts = [pscustomobject][ordered]@{ kind = 'task'; id = $tid }
    Rec 'event' 'task.stream.linked' (P 'task_stream_linked' @{ task_id = $tid; task_stream = $ts })
    foreach ($ev in @('proposed', 'accepted', 'scheduled', 'side_effect_intent', 'started')) {
        $e = [ordered]@{ kind = $ev; task_id = $tid }
        if ($ev -eq 'proposed') { $e['task_kind'] = $TaskKind }
        Rec 'event' "task.lifecycle.$ev" (P 'task_lifecycle' @{ task_stream = $ts; task_id = $tid; event = [pscustomobject]$e })
    }
    if ($Output) { Rec 'event' 'task.lifecycle.output' (P 'task_lifecycle' @{ task_stream = $ts; task_id = $tid; event = [pscustomobject][ordered]@{ kind = 'output'; task_id = $tid; chunk = $Output } }) }
    Rec 'event' 'task.lifecycle.completed' (P 'task_lifecycle' @{ task_stream = $ts; task_id = $tid; event = [pscustomobject][ordered]@{ kind = 'completed'; task_id = $tid } })
}

Err-Bytes "muse: workspace root: $((Get-Location).Path) (cwd default)"
Err-Bytes 'muse: Agent delegation: auto unavailable: workspace is untrusted.'
Rec 'reconciliation' 'runtime.command.accepted' ([pscustomobject][ordered]@{ kind = 'command_accepted'; command_id = $command; client_id = $null; command_kind = 'turn.submit' })
if ($env:FAKE_MUSE_LINK -ne 'none') {
    Rec 'event' 'session.run.linked' ([pscustomobject][ordered]@{ kind = 'session_run_linked'; command_id = $command; run_stream = $runStream }) 'durable' $(if ($env:FAKE_MUSE_LINK -eq 'task') { 'task' } else { 'session' })
    if ($env:FAKE_MUSE_LINK -eq 'two') { Rec 'event' 'session.run.linked' ([pscustomobject][ordered]@{ kind = 'session_run_linked'; command_id = $command; run_stream = $otherRun }) }
}
if ($env:FAKE_MUSE_NOMODEL -ne '1') {
    $served = if ($env:FAKE_MUSE_MODEL) { $env:FAKE_MUSE_MODEL } else { $model }
    $mp = P 'run_model_configured' @{ provider_id = 'meta'; profile_id = 'tbh'; model_id = $served; display_label = $served; source = 'startup' }
    if ($env:FAKE_MUSE_MODEL_RUN -eq 'other') { $mp.run_stream = $otherRun }
    Rec 'event' 'run.model.configured' $mp 'durable' $(if ($env:FAKE_MUSE_MODEL_STREAM -eq 'task') { 'task' } else { 'session' })
}
$shown = if ($promptText.Length -gt 200) { $promptText.Substring(0, 200) } else { $promptText }
Rec 'status' 'turn.input.user' (P 'turn_input_user' @{ prompt = $shown }) 'ephemeral'
Rec 'event' 'run.lifecycle.started' (P 'run_started' @{ prompt = $shown })
if ($env:FAKE_MUSE_HANG -eq '1') { Start-Sleep -Seconds 60 }
Task-Records 'model.meta.response'
Task-Records 'tool.read_file' "Read text file ``app.txt``.`n1|one"
Rec 'event' 'tool.result' ([pscustomobject][ordered]@{ kind = 'tool_result'; command_id = $command; run_stream = $runStream; call_id = 'call_0000000000000000000000000000fake'; text = "Read text file ``app.txt``.`n1|one" })
if ($env:FAKE_MUSE_TWOSESSIONS -eq '1') { $script:streamId = [guid]::NewGuid().ToString() }
if ($env:FAKE_MUSE_DELAY_MS) { Start-Sleep -Milliseconds ([int]$env:FAKE_MUSE_DELAY_MS) }
if ($env:FAKE_MUSE_WRITE) {
    $w = $env:FAKE_MUSE_WRITE.Split('|')
    if (-not $conv -or ($w.Count -gt 1 -and $w[1] -eq 'all')) {
        $target = Join-Path (Get-Location).Path $w[0]
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        [IO.File]::WriteAllText($target, "written by the fake muse`n", $u8)
    }
}

# ---- the answer
$replyFile = $env:FAKE_MUSE_REPLY
if ($conv -and $env:FAKE_MUSE_RESUME_REPLY) { $replyFile = $env:FAKE_MUSE_RESUME_REPLY }
$text = '{"answer":"fake"}'
if ($replyFile) { $text = [IO.File]::ReadAllText($replyFile, $u8) }
$terminal = if ($env:FAKE_MUSE_TERMINAL) { $env:FAKE_MUSE_TERMINAL } else { 'completed' }
if ($terminal -eq 'completed') {
    $half = [int][Math]::Floor($text.Length / 2)
    Rec 'status' 'run.output.delta' (P 'run_output_delta' @{ text = $text.Substring(0, $half) }) 'ephemeral'
    Rec 'status' 'run.output.delta' (P 'run_output_delta' @{ text = $text.Substring($half) }) 'ephemeral'
}
if ($env:FAKE_MUSE_STDERR) { Err-Bytes $env:FAKE_MUSE_STDERR }
if ($env:FAKE_MUSE_NOTERMINAL -ne '1') {
    $reason = $null
    if ($env:FAKE_MUSE_REASON) { $reason = $env:FAKE_MUSE_REASON }
    $tp = P 'run_terminal' @{ terminal = $terminal; text = $(if ($terminal -eq 'completed') { $text } else { $null }); reason = $reason }
    if ($env:FAKE_MUSE_TERMINAL_RUN -eq 'other') { $tp.run_stream = $otherRun }
    $kind = if ($env:FAKE_MUSE_TERMINAL_STREAM -eq 'run') { 'run' } else { 'session' }
    Rec 'event' "run.terminal.$terminal" $tp 'durable' $kind
    if ($env:FAKE_MUSE_TWOTERMINALS -eq '1') { Rec 'event' "run.terminal.$terminal" $tp 'durable' $kind }
}
if ($env:FAKE_MUSE_PARTIAL -eq '1') { Out-Bytes '{"schema_version":1,"id":"018f0000-0000-7000-8000-0000' }
if ($env:FAKE_MUSE_EXIT) { exit ([int]$env:FAKE_MUSE_EXIT) }
if ($terminal -ne 'completed') { exit 1 }
exit 0
