# FAKE codex for the 0.3.0 harness - never calls any model. Same as fake-codex.ps1 plus:
#   FAKE_CODEX_NOTHREAD=1        no thread.started event (forces the rollout fallback)
#   FAKE_CODEX_ROLLOUT=ours|foreign|ours+foreign
#                                writes rollout files into $env:CODEX_HOME\sessions\<today>:
#                                'ours' contains the prompt (hence the consultation id),
#                                'foreign' an unrelated session; written in that order
#   FAKE_CODEX_ROLLOUT_LOG=path  "<kind> <uuid>" per rollout written
#   FAKE_CODEX_PRELINE=<json>    one raw event line written BEFORE thread.started
#   FAKE_CODEX_STDERR=<text>     written to stderr after the events started (e.g. an SSE
#                                data:{"error":{...}} line), as UTF-8 BYTES (like the real
#                                CLI) whatever the console code page is
#   FAKE_CODEX_LOGIN=utf8        `login status` answers with a non-ASCII status line (UTF-8)
#   FAKE_CODEX_EXIT=<n>          exit with n right after that (no reply copied)
#   FAKE_CODEX_FAIL_ON=<text>    only when the raw command line contains <text> (e.g.
#                                model_provider=""ZAI"" for one member of a panel): write
#                                "stream error: provider refused the request" to stderr and
#                                exit 1
#   FAKE_CODEX_HANG_ON=<text>    only when the raw command line contains <text>: sleep 60 s
#                                (the bridge's -TimeoutSec kills it)
#   FAKE_CODEX_RESUME_REPLY=<f>  on `resume <thread>` (the bridge's format-repair turn): copy
#                                <f> instead of FAKE_CODEX_REPLY and report the RESUMED thread
#                                id in thread.started (as the real CLI does) - a new one with
#                                FAKE_CODEX_RESUME_NEWTHREAD=1
#   FAKE_CODEX_RESUME_LOG=<path> on `resume`: "ARGS: ...", "PROMPT:" and the prompt, there
#   FAKE_CODEX_DELAY_MS=<ms> | <model>=<ms>[|<model>=<ms>...]
#                                sleep that long after turn.started on every exec turn; a map
#                                keys the delay by the `-m` model of the turn (`*=<ms>` or a
#                                bare number: every other model) - the panel cases' per-model
#                                delay
#   FAKE_CODEX_REPLY_MAP=<model>=<file>[|<model>=<file>...]
#                                the reply of a turn of that `-m` model (instead of
#                                FAKE_CODEX_REPLY; a `resume` turn keeps FAKE_CODEX_RESUME_REPLY)
#   FAKE_CODEX_LOGIN_DELAY_MS=<ms>  `login status` answers after that long
#   FAKE_CODEX_PIDDIR=<dir>      every exec turn writes <dir>\<pid>.pid ("<pid> <start time,
#                                UTC ticks>"): one file per process - the members of a
#                                parallel panel never share one (the no-orphan checks)
$ErrorActionPreference = 'Stop'
$raw = [string]$env:FAKE_CODEX_ARGS
# "<model>=<value>|..." -> the value for $Key ('*' or a bare value: the default; $null: none)
function Get-FakeMapValue {
    param([string]$Spec, [string]$Key)
    if (-not $Spec) { return $null }
    $default = $null
    foreach ($item in $Spec.Split('|')) {
        $eq = $item.IndexOf('=')
        if ($eq -lt 0) { if ($item.Trim()) { $default = $item.Trim() }; continue }
        $k = $item.Substring(0, $eq).Trim()
        $v = $item.Substring($eq + 1).Trim()
        if ($k -ceq $Key) { return $v }
        if ($k -eq '*') { $default = $v }
    }
    return $default
}
$model = ''
if ($raw -match '(?:^| )-m (\S+)') { $model = $Matches[1].Trim('"') }
# A log or pid file several fakes may write at once (the members of a parallel panel share
# the harness's variables): retried on a sharing violation.
function Write-FakeFile {
    param([string]$Path, [string]$Text)
    for ($i = 0; $i -lt 40; $i++) {
        try { [IO.File]::WriteAllText($Path, $Text); return } catch { Start-Sleep -Milliseconds 50 }
    }
    [IO.File]::WriteAllText($Path, $Text)
}
if ($raw -match '--version') { Write-Output 'codex-cli 0.155.1-fake'; exit 0 }
# `codex login status` (the bridge's credential preflight): logged in unless
# FAKE_CODEX_LOGIN=out, hanging 40 s with FAKE_CODEX_LOGIN=hang. Written to stderr,
# like the real CLI's status line.
if ($raw -match '^\s*login\s+status(\s|$)') {
    if ($env:FAKE_CODEX_LOGIN_DELAY_MS) { Start-Sleep -Milliseconds ([int]$env:FAKE_CODEX_LOGIN_DELAY_MS) }
    if ($env:FAKE_CODEX_LOGIN -eq 'out') { [Console]::Error.WriteLine('Not logged in'); exit 1 }
    if ($env:FAKE_CODEX_LOGIN -eq 'hang') { Start-Sleep -Seconds 40 }
    if ($env:FAKE_CODEX_LOGIN -eq 'utf8') {
        # "Logged in using ChatGPT - Jurgen's plan" with an en dash, u-umlaut and a curly apostrophe
        $line = 'Logged in using ChatGPT ' + [char]0x2013 + ' J' + [char]0x00FC + 'rgen' + [char]0x2019 + 's plan'
        $b = (New-Object System.Text.UTF8Encoding($false)).GetBytes($line + "`r`n")
        $es = [Console]::OpenStandardError(); $es.Write($b, 0, $b.Length); $es.Flush()
        exit 0
    }
    [Console]::Error.WriteLine('Logged in using ChatGPT'); exit 0
}
$o = $null
if ($raw -match '(?:^| )-o (\S+)') { $o = $Matches[1] }
$prompt = [Console]::In.ReadToEnd()
$resumeOf = ''
if ($env:FAKE_CODEX_RESUME_REPLY -and $raw -match ' resume ([0-9a-fA-F-]{36})') { $resumeOf = $Matches[1] }
if ($resumeOf -and $env:FAKE_CODEX_RESUME_LOG) {
    Write-FakeFile $env:FAKE_CODEX_RESUME_LOG "ARGS: $raw`nPROMPT:`n$prompt"
} elseif ($env:FAKE_CODEX_LOG) {
    Write-FakeFile $env:FAKE_CODEX_LOG "ARGS: $raw`nPROMPT:`n$prompt"
}
if ($env:FAKE_CODEX_PIDFILE) { Write-FakeFile $env:FAKE_CODEX_PIDFILE "$PID" }
if ($env:FAKE_CODEX_PIDDIR) { Write-FakeFile (Join-Path $env:FAKE_CODEX_PIDDIR "$PID.pid") "$PID $((Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks)" }
$tid = [guid]::NewGuid().ToString()
if ($resumeOf -and -not $env:FAKE_CODEX_RESUME_NEWTHREAD) { $tid = $resumeOf }
if ($env:FAKE_CODEX_PRELINE) { [Console]::Out.Write($env:FAKE_CODEX_PRELINE + "`n") }
if (-not $env:FAKE_CODEX_NOTHREAD) { [Console]::Out.Write("{""type"":""thread.started"",""thread_id"":""$tid""}`n") }
[Console]::Out.Write("{""type"":""turn.started""}`n")
[Console]::Out.Flush()
$delayMs = Get-FakeMapValue $env:FAKE_CODEX_DELAY_MS $model
if ($delayMs) { Start-Sleep -Milliseconds ([int]$delayMs) }
if ($env:FAKE_CODEX_ROLLOUT) {
    $now = Get-Date
    $day = Join-Path (Join-Path (Join-Path (Join-Path $env:CODEX_HOME 'sessions') ('{0:yyyy}' -f $now)) ('{0:MM}' -f $now)) ('{0:dd}' -f $now)
    [void][IO.Directory]::CreateDirectory($day)
    $written = @()
    foreach ($kind in $env:FAKE_CODEX_ROLLOUT.Split('+')) {
        $u = [guid]::NewGuid().ToString()
        $text = if ($kind -eq 'ours') { $prompt } else { 'an unrelated interactive session, started meanwhile' }
        $l1 = '{"type":"session_meta","payload":{"id":"' + $u + '"}}'
        $l2 = '{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":' + (ConvertTo-Json -InputObject $text -Compress) + '}]}}'
        $name = 'rollout-' + (Get-Date -Format 'yyyy-MM-ddTHH-mm-ss') + '-' + $u + '.jsonl'
        [IO.File]::WriteAllText((Join-Path $day $name), "$l1`n$l2`n")
        $written += "$kind $u"
        Start-Sleep -Milliseconds 1100
    }
    if ($env:FAKE_CODEX_ROLLOUT_LOG) { [IO.File]::WriteAllText($env:FAKE_CODEX_ROLLOUT_LOG, ($written -join "`n")) }
}
if ($env:FAKE_CODEX_SLEEP) { Start-Sleep -Seconds ([int]$env:FAKE_CODEX_SLEEP) }
if ($env:FAKE_CODEX_HANG_ON -and $raw.Contains($env:FAKE_CODEX_HANG_ON)) { Start-Sleep -Seconds 60 }
if ($env:FAKE_CODEX_STDERR) {
    $b = (New-Object System.Text.UTF8Encoding($false)).GetBytes($env:FAKE_CODEX_STDERR + "`r`n")
    $es = [Console]::OpenStandardError(); $es.Write($b, 0, $b.Length); $es.Flush()
}
if ($env:FAKE_CODEX_EXIT) { exit ([int]$env:FAKE_CODEX_EXIT) }
if ($env:FAKE_CODEX_FAIL_ON -and $raw.Contains($env:FAKE_CODEX_FAIL_ON)) {
    [Console]::Error.WriteLine('stream error: provider refused the request')
    exit 1
}
$mappedReply = Get-FakeMapValue $env:FAKE_CODEX_REPLY_MAP $model
if ($o -and $resumeOf) { [IO.File]::Copy($env:FAKE_CODEX_RESUME_REPLY, $o, $true) }
elseif ($o -and $mappedReply) { [IO.File]::Copy($mappedReply, $o, $true) }
elseif ($o -and $env:FAKE_CODEX_REPLY) { [IO.File]::Copy($env:FAKE_CODEX_REPLY, $o, $true) }
[Console]::Out.Write("{""type"":""turn.completed"",""usage"":{""input_tokens"":1000,""cached_input_tokens"":200,""cache_write_input_tokens"":0,""output_tokens"":300,""reasoning_output_tokens"":40}}`n")
exit 0
