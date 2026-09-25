# FAKE agy (Google Antigravity CLI) for harness-engines.ps1 - never calls any model. Started
# through fake-agy.cmd, which hands the command line over as FAKE_AGY_ARGS; the prompt arrives
# on STDIN as one NDJSON line (the bridge's transport), so cmd.exe never sees it. Prints the
# init / step_update / result events of `--output-format stream-json`, shaped like the real
# CLI's (agy 1.2.x): init {conversation_id, init{model, cwd, tools, permission_mode}},
# step_update {step_update{conversation_id, step_index, state, step_type, ...}}, result
# {result{conversation_id, status, response, duration_seconds, num_turns, structured_output?,
# usage, denied_actions?, error?}}.
#   `models`                    FAKE_AGY_MODELS=ok (default: "<id><TAB><name>" lines) | out
#                               (not signed in, exit 1) | hang (40 s) | nolist (exit 0, no
#                               list); FAKE_AGY_MODELS_LOG=<path> gets one line per call
#   print mode (-p=):
#   FAKE_AGY_REPLY=<file>         the reply: a JSON object -> result.structured_output (the
#                                 `response` text then carries the object plus two extra
#                                 keys, like the real CLI - F4); any other text -> response
#   FAKE_AGY_NOSTRUCTURED=1       FAKE_AGY_REPLY's text as the response only
#   FAKE_AGY_RESUME_REPLY=<file>  on a --conversation turn (the bridge's denial retry or format
#                                 repair): this reply instead
#   FAKE_AGY_STATUS=<S>           result.status (default SUCCESS); another status exits 1
#                                 unless FAKE_AGY_EXIT is set
#   FAKE_AGY_ERROR=<text>         result.error
#   FAKE_AGY_STDERR=<text>        written to stderr (UTF-8 bytes)
#   FAKE_AGY_CONVERSATION=notfound  on --conversation: `warning: conversation "<id>" not
#                                 found` and a NEW id; =other: a new id without the warning;
#                                 =mismatch: init and result ids differ; =notuuid: the
#                                 conversation id is not a uuid; default: the requested id on
#                                 --conversation, a new uuid otherwise
#   FAKE_AGY_DENIED=1             a turn WITHOUT --conversation: a run_command tool step, the
#                                 F11 stderr line, result SUCCESS with an empty response and
#                                 denied_actions (=all: every turn, the retry too)
#   FAKE_AGY_DENIED_REPLY=1       ... but that turn still answers (a notice WITH a reply)
#   FAKE_AGY_PARTIAL=1            the print-timeout stderr line, SUCCESS with an empty response
#   FAKE_AGY_NORESULT=1           no result event;  FAKE_AGY_TWORESULTS=1  two of them
#   FAKE_AGY_BADLINE=1            a line that is not JSON before the result
#   FAKE_AGY_WRITE=<rel path>     writes that file (relative to the working directory) on a
#                                 turn without --conversation (=<path>|all: on every turn)
#   FAKE_AGY_HANG=1               sleeps 60 s after init;  FAKE_AGY_HANG_ON=<text>  only when
#                                 the raw arguments contain <text>
#   FAKE_AGY_TRAILING=<text>      written to stdout after the result event (no newline):
#                                 trailing garbage / a partial line
#   FAKE_AGY_HANG_AFTER=1         sleeps 60 s after every event was written (a run that is
#                                 then killed by the bridge's timeout)
#   FAKE_AGY_EXIT=<n>             exits n after the events
#   FAKE_AGY_LOG=<path>           "ARGS: ...", "STDIN:" and the stdin text of a turn without
#                                 --conversation; the raw stdin bytes also to <path>.stdin
#   FAKE_AGY_RESUME_LOG=<path>    the same for a --conversation turn
#   FAKE_AGY_PIDFILE=<path>       its pid
$ErrorActionPreference = 'Stop'
$u8 = New-Object System.Text.UTF8Encoding($false)
$raw = [string]$env:FAKE_AGY_ARGS
function Out-Bytes { param([string]$Text) $b = $u8.GetBytes($Text); $s = [Console]::OpenStandardOutput(); $s.Write($b, 0, $b.Length); $s.Flush() }
function Err-Bytes { param([string]$Text) $b = $u8.GetBytes($Text + "`r`n"); $s = [Console]::OpenStandardError(); $s.Write($b, 0, $b.Length); $s.Flush() }
function J { param($Obj) return (ConvertTo-Json -InputObject $Obj -Compress -Depth 30) }

if ($raw -match '^\s*models(\s|$)') {
    if ($env:FAKE_AGY_MODELS_LOG) { [IO.File]::AppendAllText($env:FAKE_AGY_MODELS_LOG, "models`n") }
    $mode = if ($env:FAKE_AGY_MODELS) { $env:FAKE_AGY_MODELS } else { 'ok' }
    if ($mode -eq 'hang') { Start-Sleep -Seconds 40; exit 0 }
    Err-Bytes 'Fetching available models...'
    if ($mode -eq 'out') { Err-Bytes 'Error: you are not signed in. Run agy to sign in with your Google account.'; exit 1 }
    if ($mode -eq 'nolist') { Out-Bytes "no models today`n"; exit 0 }
    Out-Bytes ("gemini-3.8-flash-high`tGemini 3.8 Flash (High)`ngemini-3.8-flash-low`tGemini 3.8 Flash (Low)`ngemini-3.1-pro-high`tGemini 3.1 Pro (High)`n")
    exit 0
}

# ---- print mode
$stdinStream = [Console]::OpenStandardInput()
$ms = New-Object System.IO.MemoryStream
$stdinStream.CopyTo($ms)
$stdinBytes = $ms.ToArray()
$stdinText = $u8.GetString($stdinBytes)
$conv = ''
if ($raw -match '--conversation\s+(\S+)') { $conv = $Matches[1] }
$model = 'unknown'
if ($raw -match '--model\s+(\S+)') { $model = $Matches[1] }
$log = if ($conv -and $env:FAKE_AGY_RESUME_LOG) { $env:FAKE_AGY_RESUME_LOG } elseif (-not $conv) { $env:FAKE_AGY_LOG } else { '' }
if ($log) {
    [IO.File]::WriteAllText($log, "ARGS: $raw`nSTDIN:`n$stdinText", $u8)
    [IO.File]::WriteAllBytes("$log.stdin", $stdinBytes)
}
if ($env:FAKE_AGY_PIDFILE) { [IO.File]::WriteAllText($env:FAKE_AGY_PIDFILE, "$PID") }

$cmode = [string]$env:FAKE_AGY_CONVERSATION
$id = [guid]::NewGuid().ToString()
if ($conv) {
    if ($cmode -eq 'notfound') { Err-Bytes "warning: conversation `"$conv`" not found" }
    elseif ($cmode -ne 'other') { $id = $conv }
}
if ($cmode -eq 'notuuid') { $id = 'conv-1' }
$resultId = $id
if ($cmode -eq 'mismatch') { $resultId = [guid]::NewGuid().ToString() }

$denied = ($env:FAKE_AGY_DENIED -eq 'all') -or ($env:FAKE_AGY_DENIED -eq '1' -and -not $conv)
Out-Bytes ((J ([pscustomobject]@{ event = 'init'; conversation_id = $id; init = [pscustomobject]@{ model = $model; cwd = (Get-Location).Path; tools = @('view_file', 'grep_search', 'run_command', 'write_to_file'); permission_mode = 'request-review' } })) + "`n")
Out-Bytes ((J ([pscustomobject]@{ event = 'step_update'; step_update = [pscustomobject]@{ conversation_id = $id; step_index = 0; state = 'DONE'; step_type = 'user_input' } })) + "`n")
if ($env:FAKE_AGY_HANG -eq '1' -or ($env:FAKE_AGY_HANG_ON -and $raw.Contains($env:FAKE_AGY_HANG_ON))) { Start-Sleep -Seconds 60 }
Out-Bytes ((J ([pscustomobject]@{ event = 'step_update'; step_update = [pscustomobject]@{ conversation_id = $id; step_index = 1; state = 'DONE'; step_type = 'tool'; tool_name = 'view_file'; duration_seconds = 0.1; tool_info = [pscustomobject]@{ name = 'view_file'; parameters = [pscustomobject]@{ AbsolutePath = 'app.txt' }; output = '1 lines' } } })) + "`n")
if ($env:FAKE_AGY_WRITE) {
    $w = $env:FAKE_AGY_WRITE.Split('|')
    if (-not $conv -or ($w.Count -gt 1 -and $w[1] -eq 'all')) {
        $target = Join-Path (Get-Location).Path $w[0]
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        [IO.File]::WriteAllText($target, "written by the fake agy`n", $u8)
    }
}
if ($denied) {
    Out-Bytes ((J ([pscustomobject]@{ event = 'step_update'; step_update = [pscustomobject]@{ conversation_id = $id; step_index = 2; state = 'ACTIVE'; step_type = 'tool'; tool_name = 'run_command'; tool_info = [pscustomobject]@{ name = 'run_command'; parameters = [pscustomobject]@{ CommandLine = 'agy --version' } } } })) + "`n")
    Out-Bytes ((J ([pscustomobject]@{ event = 'step_update'; step_update = [pscustomobject]@{ conversation_id = $id; step_index = 2; state = 'DONE'; step_type = 'tool'; tool_name = 'run_command'; duration_seconds = 0.3 } })) + "`n")
    Err-Bytes ('jetski: no output produced ' + [char]0x2014 + ' a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow in settings.json (e.g. command(<target>)). Alternatively, re-run with --dangerously-skip-permissions to auto-approve all tools.')
}
if ($env:FAKE_AGY_PARTIAL -eq '1') { Err-Bytes '[agy] print timeout after 20s with turn in progress; returning partial output' }
if ($env:FAKE_AGY_STDERR) { Err-Bytes $env:FAKE_AGY_STDERR }
if ($env:FAKE_AGY_BADLINE -eq '1') { Out-Bytes "this is not json`n" }

# the reply
$replyFile = $env:FAKE_AGY_REPLY
$fromResume = $false
if ($conv -and $env:FAKE_AGY_RESUME_REPLY) { $replyFile = $env:FAKE_AGY_RESUME_REPLY; $fromResume = $true }
$response = ''
$structured = $null
if ($replyFile -and -not ($denied -and $env:FAKE_AGY_DENIED_REPLY -ne '1') -and $env:FAKE_AGY_PARTIAL -ne '1') {
    $text = [IO.File]::ReadAllText($replyFile, $u8)
    $obj = $null
    if (-not ($env:FAKE_AGY_NOSTRUCTURED -eq '1' -and -not $fromResume)) { try { $obj = ConvertFrom-Json -InputObject $text } catch { $obj = $null } }
    if ($null -ne $obj -and $obj -is [System.Management.Automation.PSCustomObject]) {
        $structured = $obj
        # F4: the response text of the same run is NOT the object (two extra keys)
        $withExtra = ConvertFrom-Json -InputObject $text
        $withExtra | Add-Member -NotePropertyName 'toolAction' -NotePropertyValue 'finish' -Force
        $withExtra | Add-Member -NotePropertyName 'toolSummary' -NotePropertyValue 'done' -Force
        $response = J $withExtra
    } else {
        $response = $text
    }
}
Out-Bytes ((J ([pscustomobject]@{ event = 'step_update'; step_update = [pscustomobject]@{ conversation_id = $id; step_index = 3; state = 'DONE'; step_type = 'agent_response'; duration_seconds = 1.5; usage = [pscustomobject]@{ input_tokens = 9000; output_tokens = 400; thinking_tokens = 100; cache_read_tokens = 0; total_tokens = 9400 } } })) + "`n")
if ($env:FAKE_AGY_NORESULT -ne '1') {
    $status = if ($env:FAKE_AGY_STATUS) { $env:FAKE_AGY_STATUS } else { 'SUCCESS' }
    $usage = if ($conv) { [pscustomobject]@{ input_tokens = 54000; output_tokens = 300; thinking_tokens = 80; cache_read_tokens = 30000; total_tokens = 54300 } } else { [pscustomobject]@{ input_tokens = 13000; output_tokens = 500; thinking_tokens = 120; cache_read_tokens = 4000; total_tokens = 13500 } }
    $res = [ordered]@{ conversation_id = $resultId; status = $status; response = $response; duration_seconds = 3.1; num_turns = 1 }
    if ($null -ne $structured) { $res['structured_output'] = $structured }
    if ($env:FAKE_AGY_ERROR) { $res['error'] = $env:FAKE_AGY_ERROR }
    $res['usage'] = $usage
    if ($denied) { $res['denied_actions'] = [pscustomobject]@{ action = 'command'; display_name = 'RunCommand' } }
    $line = (J ([pscustomobject]@{ event = 'result'; result = [pscustomobject]$res })) + "`n"
    Out-Bytes $line
    if ($env:FAKE_AGY_TWORESULTS -eq '1') { Out-Bytes $line }
}
if ($env:FAKE_AGY_TRAILING) { Out-Bytes $env:FAKE_AGY_TRAILING }
if ($env:FAKE_AGY_HANG_AFTER -eq '1') { Start-Sleep -Seconds 60 }
if ($env:FAKE_AGY_EXIT) { exit ([int]$env:FAKE_AGY_EXIT) }
if ($env:FAKE_AGY_STATUS -and $env:FAKE_AGY_STATUS -ne 'SUCCESS') { exit 1 }
exit 0
