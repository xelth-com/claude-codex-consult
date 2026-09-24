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
$ErrorActionPreference = 'Stop'
$raw = [string]$env:FAKE_CODEX_ARGS
if ($raw -match '--version') { Write-Output 'codex-cli 0.155.1-fake'; exit 0 }
# `codex login status` (the bridge's credential preflight): logged in unless
# FAKE_CODEX_LOGIN=out, hanging 40 s with FAKE_CODEX_LOGIN=hang. Written to stderr,
# like the real CLI's status line.
if ($raw -match '^\s*login\s+status(\s|$)') {
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
if ($env:FAKE_CODEX_LOG) {
    [IO.File]::WriteAllText($env:FAKE_CODEX_LOG, "ARGS: $raw`nPROMPT:`n$prompt")
}
if ($env:FAKE_CODEX_PIDFILE) { [IO.File]::WriteAllText($env:FAKE_CODEX_PIDFILE, "$PID") }
$tid = [guid]::NewGuid().ToString()
if ($env:FAKE_CODEX_PRELINE) { [Console]::Out.Write($env:FAKE_CODEX_PRELINE + "`n") }
if (-not $env:FAKE_CODEX_NOTHREAD) { [Console]::Out.Write("{""type"":""thread.started"",""thread_id"":""$tid""}`n") }
[Console]::Out.Write("{""type"":""turn.started""}`n")
[Console]::Out.Flush()
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
if ($o -and $env:FAKE_CODEX_REPLY) { [IO.File]::Copy($env:FAKE_CODEX_REPLY, $o, $true) }
[Console]::Out.Write("{""type"":""turn.completed"",""usage"":{""input_tokens"":1000,""cached_input_tokens"":200,""cache_write_input_tokens"":0,""output_tokens"":300,""reasoning_output_tokens"":40}}`n")
exit 0
