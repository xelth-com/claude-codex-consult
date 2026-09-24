# FAKE codex for tests - never calls any model. fake-codex.cmd passes its raw
# command line in FAKE_CODEX_ARGS (powershell -File would mis-parse -o/-c/--json).
$ErrorActionPreference = 'Stop'
$raw = [string]$env:FAKE_CODEX_ARGS
if ($raw -match '--version') { Write-Output 'codex-cli 0.155.1-fake'; exit 0 }
# `codex login status` (the bridge's credential preflight): logged in unless
# FAKE_CODEX_LOGIN=out, hanging 40 s with FAKE_CODEX_LOGIN=hang. Written to stderr,
# like the real CLI's status line.
if ($raw -match '^\s*login\s+status(\s|$)') {
    if ($env:FAKE_CODEX_LOGIN -eq 'out') { [Console]::Error.WriteLine('Not logged in'); exit 1 }
    if ($env:FAKE_CODEX_LOGIN -eq 'hang') { Start-Sleep -Seconds 40 }
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
[Console]::Out.Write("{""type"":""thread.started"",""thread_id"":""$tid""}`n")
[Console]::Out.Write("{""type"":""turn.started""}`n")
[Console]::Out.Flush()
if ($env:FAKE_CODEX_TOUCH) { foreach ($t in $env:FAKE_CODEX_TOUCH.Split(';')) { if ($t) { Add-Content -LiteralPath $t -Value 'changed during review' } } }
if ($env:FAKE_CODEX_SLEEP) { Start-Sleep -Seconds ([int]$env:FAKE_CODEX_SLEEP) }
if ($env:FAKE_CODEX_FAIL) {
    [Console]::Out.Write("{""type"":""error"",""message"":""$($env:FAKE_CODEX_FAIL)""}`n")
    exit 1
}
if ($o -and $env:FAKE_CODEX_REPLY) { [IO.File]::Copy($env:FAKE_CODEX_REPLY, $o, $true) }
if (-not $env:FAKE_CODEX_NOUSAGE) {
    [Console]::Out.Write("{""type"":""turn.completed"",""usage"":{""input_tokens"":1000,""cached_input_tokens"":200,""cache_write_input_tokens"":0,""output_tokens"":300,""reasoning_output_tokens"":40}}`n")
}
exit 0
