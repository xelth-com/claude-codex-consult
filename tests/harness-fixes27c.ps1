# codex-consult wave 27c (0.5.0; the fix round of the waves 26c/27/27b acceptance - decisions D1-D24 of
# .collab/companions-2026-09-26/handoffs/33-...): KICK - the kick protocol per request (two concurrent
# -Kick callers on one member: one request, both acknowledged by its id, the acknowledgement retired;
# an old acknowledgement of another id swept) (D1) and a kick of the timeout continuation keeping the
# timeout outcome and its salvage (D2); HIDE - the transactional hide of the host markers (a removal
# that fails puts everything back and the engine start is refused) (D3) and the launcher probes that
# never fail open (the start-info path, then the process environment, then skipped - "not checked"
# and a warning) (D4); STREAM - the bounded stream reader (only new bytes scanned, the carry capped,
# an oversized line skipped and counted) (D5) and the capped tool-call suspension of the stall timer
# (D6); HEALTH - every failure of the machine-wide health update retried and named (D7), the retry
# inside the write lock bounded to one attempt of at most 1 s (D8); COORD - the coordinator as a
# resolved triple, the weaker "own provider" warning, the shared character rule, a coordinator
# outside the roster, an unresolved '#n' (D9-D12); POINTER - the hook's pointer command runnable as
# printed (D13), -Explain disposing its stream (D15); TESTMODE - test hooks honoured only with
# CODEX_CONSULT_TEST_MODE=1, else ignored with one warning (D14); KILL - a tree kill that cannot be
# confirmed (the children cannot be enumerated - the test hook of D16, gated by D14): no
# "(process tree killed)", ledger kill_confirmed false, a warning, NO continuation turn; and a
# confirmed one (D16); ZCODE - the zcode hint from ZCODE_APP_VERSION / ZCODE_PROCESS_LABEL and from the
# install path, the completed scrub list (D20, D21); DOCS - the plugin README, powershell/pwsh, the
# Codex sandbox paragraph, the AGENTS.md places per host, the hook one-liner rule, the tool time
# limits (D17-D19, D23, D24). (D22 - the templates - is harness-host's GREP.) FAKES ONLY: fake-codex3.cmd;
# CODEX_HOME and CODEX_CONSULT_ROSTER point at scratch files, CODEX_CONSULT_HEALTH is 'none' (HEALTH:
# scratch paths), telemetry off; the host markers of the process that runs it are removed first; the
# API key variables hold dummy values. Runs under the host it is started with (powershell 5.1 or pwsh
# 7, Windows). Work files: $env:TEMP\codex-consult-tests\harness-fixes27c\<guid>, removed at the end.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
$env:CODEX_CONSULT_HEALTH = 'none'
# (wave 28) telemetry off and the intake pointed at nothing reachable: no harness but
# harness-telemetry spools an event or contacts an intake
$env:CODEX_CONSULT_TELEMETRY = 'off'
$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
# (wave 27c, D14) the test hooks (CODEX_CONSULT_TEST_*, CODEX_CONSULT_NOW) are honoured only in test mode
$env:CODEX_CONSULT_TEST_MODE = '1'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$pluginDir = Split-Path -Parent $scripts
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$hookPs = Join-Path $scripts 'codex-consult-hook.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-fixes27c') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 10; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
$savedCodexHome = $env:CODEX_HOME
$script:fails = 0
$script:passes = 0
function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 400) { $ev = $ev.Substring(0, 400) + '...' }
    Write-Host ("{0} {1,-8} {2}{3}" -f $mark, $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
}
function Want { param([string]$Name) return (-not $Only -or ($Only -split ',') -contains $Name) }
function G { param([string]$Repo, [string[]]$A) $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = & git -C $Repo @A 2>&1; $ErrorActionPreference = $p; return $o }
function New-Repo {
    param([string]$Name)
    $r = Join-Path $work $Name
    if (Test-Path $r) { Remove-Item $r -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($r)
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    return $r
}
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n"
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
function Write-Roster { param([string]$Name, [string]$Json) $p = Join-Path $work "roster-$Name.json"; [IO.File]::WriteAllText($p, $Json, $u8); return $p }
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_HANG_NEW', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP', 'FAKE_CODEX_PIDDIR', 'FAKE_CODEX_TOOL_OPEN', 'FAKE_CODEX_ITEMS')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_TEST_HIDE_FAIL', 'CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL', 'CODEX_CONSULT_TEST_KILL_DENIED', 'CODEX_CONSULT_TEST_TOOL_CAP_SEC', 'CODEX_CONSULT_TEST_WAIT_TICK_MS', 'CODEX_CONSULT_TEST_HEALTH_LOCK_SEC', 'CODEX_CONSULT_TEST_PANEL_SEED', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_PLUGIN_ROOT')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    foreach ($k in (Get-HostMarkerNames)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $env:CODEX_CONSULT_HEALTH = 'none'
    $env:CODEX_CONSULT_TEST_MODE = '1'
}
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome }
function Get-Previews {
    param([string]$Text)
    $list = New-Object System.Collections.Generic.List[object]
    $mark = 'sessions.json entry preview:'
    $at = $Text.IndexOf($mark)
    while ($at -ge 0) {
        $rest = $Text.Substring($at + $mark.Length)
        $next = $rest.IndexOf($mark)
        $chunk = $(if ($next -ge 0) { $rest.Substring(0, $next) } else { $rest })
        $lines = New-Object System.Collections.Generic.List[string]
        $depth = 0
        $started = $false
        foreach ($l in ($chunk -split "`n")) {
            $t = $l.TrimEnd("`r")
            if (-not $started) { if ($t.Trim() -eq '{') { $started = $true } else { continue } }
            $lines.Add($t)
            $depth += ([regex]::Matches($t, '[\{\[]')).Count - ([regex]::Matches($t, '[\}\]]')).Count
            if ($started -and $depth -le 0) { break }
        }
        try { $list.Add((($lines.ToArray() -join "`n") | ConvertFrom-Json)) } catch { $list.Add($null) }
        $at = $(if ($next -ge 0) { $at + $mark.Length + $next } else { -1 })
    }
    return , ($list.ToArray())
}
# One bridge call (synchronous): { Code; Out; First; Previews }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task 't' -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Previews = (Get-Previews $text) }
}
# A bridge call in the background (its output to a file): { Proc; OutP } - Wait-Bg collects it
function Start-Bg {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    $tag = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $outP = Join-Path $work "bg-$tag.txt"
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-CodexExe', $fake) + @($ArgList)
    $argText = (@($all | ForEach-Object { if ([string]$_ -match '[\s"]' -or [string]$_ -eq '') { '"' + ([string]$_ -replace '"', '\"') + '"' } else { [string]$_ } }) -join ' ')
    $proc = Start-Process -FilePath $psExe -ArgumentList $argText -WorkingDirectory $Repo -NoNewWindow -PassThru -RedirectStandardOutput $outP -RedirectStandardError "$outP.err"
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $proc.Handle } catch { } }
    Restore-Env
    return [pscustomobject]@{ Proc = $proc; OutP = $outP }
}
function Wait-Bg {
    param($Bg, [int]$TimeoutSec = 120)
    if (-not $Bg.Proc.WaitForExit($TimeoutSec * 1000)) { try { $null = Stop-ProcessTree -Process $Bg.Proc } catch { } }
    $o = ''
    foreach ($f in @($Bg.OutP, "$($Bg.OutP).err")) { if (Test-Path -LiteralPath $f) { $o += (Read-SharedText -Path $f) } }
    return [pscustomobject]@{ Code = $Bg.Proc.ExitCode; Out = $o }
}
# A script with arbitrary arguments (no -Task added): { Code; Out }
function Run-Raw {
    param([string]$Script, [string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv '' $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgList 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $c = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return [pscustomobject]@{ Code = $c; Out = $o }
}
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Text { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
# Waits until the task's recovery record is `running` with a live child whose note matches $Note
function Wait-Running {
    param([string]$Repo, [string]$Note = '', [int]$TimeoutSec = 60)
    $p = Join-Path $Repo '.collab\t\.consult.pending.json'
    $w = [System.Diagnostics.Stopwatch]::StartNew()
    while ($w.Elapsed.TotalSeconds -lt $TimeoutSec) {
        $rd = Read-PendingFile -Path $p
        if ($rd.Exists -and $rd.Record -and [string]$rd.Record.state -eq 'running' -and [int](Get-PropertyValue $rd.Record 'child_pid' 0) -gt 0 -and (-not $Note -or ([string](Get-PropertyValue $rd.Record 'note' '')) -like "*$Note*")) { return $true }
        Start-Sleep -Milliseconds 250
    }
    return $false
}
# Stops the fake codex processes whose pid files are in $Dir (the orphans of a kill that was not confirmed)
function Stop-Orphans {
    param([string]$Dir)
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -Filter '*.pid' -ErrorAction SilentlyContinue)) {
        $n = 0
        if ([int]::TryParse(($f.BaseName), [ref]$n)) { try { Stop-Process -Id $n -Force -ErrorAction SilentlyContinue } catch { } }
    }
}
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Join-Path $work 'advise.json'
[IO.File]::WriteAllText($advise, $adviseJson, $u8)
$roster2 = Write-Roster 'two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'

try {

# =============================================================== TESTMODE: test hooks only in test mode (D14)
if (Want 'TESTMODE') {
    $env:CODEX_CONSULT_TEST_PANEL_SEED = 'seed-27c'
    $env:CODEX_CONSULT_TEST_MODE = ''
    $offVal = Get-TestHookValue 'CODEX_CONSULT_TEST_PANEL_SEED'
    $offList = (Get-IgnoredTestHooks) -join ','
    $env:CODEX_CONSULT_TEST_MODE = '1'
    $onVal = Get-TestHookValue 'CODEX_CONSULT_TEST_PANEL_SEED'
    $onList = (Get-IgnoredTestHooks) -join ','
    Remove-Item env:CODEX_CONSULT_TEST_PANEL_SEED
    Check 'TESTMODE' 'D14 a CODEX_CONSULT_TEST_* hook is honoured only with CODEX_CONSULT_TEST_MODE=1: without it Get-TestHookValue gives '''' and Get-IgnoredTestHooks names it; with it the value and nothing ignored' ($offVal -eq '' -and $offList -eq 'CODEX_CONSULT_TEST_PANEL_SEED' -and $onVal -eq 'seed-27c' -and $onList -eq '') "off '$offVal' [$offList] on '$onVal' [$onList]"
    $r = New-Repo 'testmode'
    $d = Consult $r $roster2 @('-Panel', '-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_TEST_MODE = ''; CODEX_CONSULT_TEST_PANEL_SEED = 'seed-27c' }
    $pv = @($d.Previews | Where-Object { $_ })
    $warned = @($pv | Where-Object { @($_.warnings | Where-Object { ([string]$_) -eq 'test hook ignored - CODEX_CONSULT_TEST_MODE=1 is not set: CODEX_CONSULT_TEST_PANEL_SEED' }).Count -eq 1 }).Count
    $nonces = @($pv | ForEach-Object { [string]$_.panel.routing.nonce_source } | Select-Object -Unique)
    Check 'TESTMODE' 'D14 end to end: a panel dry run with CODEX_CONSULT_TEST_PANEL_SEED but no test mode - the seed is IGNORED (routing nonce_source is not the hook) and every member''s warnings[] says so once: "test hook ignored - CODEX_CONSULT_TEST_MODE=1 is not set: CODEX_CONSULT_TEST_PANEL_SEED"' ($d.Code -eq 0 -and $pv.Count -ge 1 -and $warned -eq $pv.Count -and ($nonces -join ',') -notmatch 'CODEX_CONSULT_TEST_PANEL_SEED') "exit $($d.Code) previews $($pv.Count) warned $warned nonce $($nonces -join ',')"
}

# =============================================================== HIDE: transactional hide (D3), probes never fail open (D4)
if (Want 'HIDE') {
    Clear-TestEnv
    $env:CLAUDECODE = '1'; $env:CLAUDE_CODE_MESSAGING_TOKEN = 'tok-27c'; $env:ZCODE_SESSION_ID = 'zs-27c'
    $env:CODEX_CONSULT_TEST_HIDE_FAIL = 'CLAUDE_CODE_MESSAGING_TOKEN'
    $err = ''
    try { $null = Hide-HostMarkers } catch { $err = $_.Exception.Message }
    $back = ($env:CLAUDECODE -eq '1' -and $env:CLAUDE_CODE_MESSAGING_TOKEN -eq 'tok-27c' -and $env:ZCODE_SESSION_ID -eq 'zs-27c')
    $ran = $false
    try { Invoke-WithoutHostMarkers -Action { $script:ranAction = $true } } catch { }
    $ran = [bool]$script:ranAction
    Remove-Item env:CODEX_CONSULT_TEST_HIDE_FAIL
    $saved = Hide-HostMarkers
    $during = (Get-HostMarkerNames) -join ','
    Restore-HostMarkers -Saved $saved
    $after = (Get-HostMarkerNames) -join ','
    Clear-TestEnv
    Check 'HIDE' 'D3 (F30-2) the hide is TRANSACTIONAL: a removal that fails (test hook CODEX_CONSULT_TEST_HIDE_FAIL=CLAUDE_CODE_MESSAGING_TOKEN - removed after CLAUDECODE) throws "host markers could not be hidden (CLAUDE_CODE_MESSAGING_TOKEN: ...)" and every marker removed before it is back; Invoke-WithoutHostMarkers then runs nothing; without the hook all three are hidden and restored' ($err -match '^host markers could not be hidden \(CLAUDE_CODE_MESSAGING_TOKEN: ' -and $back -and -not $ran -and $during -eq '' -and $after -eq 'CLAUDECODE,CLAUDE_CODE_MESSAGING_TOKEN,ZCODE_SESSION_ID') "err '$err' back $back ran $ran during '$during' after '$after'"
    $r = New-Repo 'hide'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'h') @{ FAKE_CODEX_REPLY = $advise; CLAUDECODE = '1'; CLAUDE_CODE_MESSAGING_TOKEN = 'tok-27c'; CODEX_CONSULT_TEST_HIDE_FAIL = 'CLAUDECODE' }
    Check 'HIDE' 'D3 end to end: the engine start is REFUSED when the markers cannot be hidden - "the codex run is refused before launch: bridge failure: host markers could not be hidden (CLAUDECODE: ...); nothing was started.", exit 1, no ledger entry' ($x.Code -eq 1 -and $x.Out -match 'refused before launch: bridge failure: host markers could not be hidden \(CLAUDECODE: ' -and $x.Out -match 'nothing was started' -and @(Ledger $r).Count -eq 0) (($x.Out -split "`n" | Where-Object { $_ -match 'refused|could not' }) -join ' || ')
    # D4: the start-info path fails -> the probe runs with the markers hidden from the process environment
    $dumpDir = Join-Path $work 'probe-env'
    [void][IO.Directory]::CreateDirectory($dumpDir)
    $p1 = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ CLAUDECODE = '1'; CLAUDE_CODE_MESSAGING_TOKEN = 'tok-27c'; CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL = '1'; FAKE_CODEX_ENV_DUMP = $dumpDir }
    $login = @(Get-ChildItem -LiteralPath $dumpDir -Filter 'login-*.env')
    $loginText = $(if ($login.Count) { Text $login[0].FullName } else { '' })
    Check 'HIDE' 'D4 (F30-4) the start-info block cannot be scrubbed (test hook CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL): the probe (`codex login status`) runs FROM A FRESH start info while the markers are hidden from the bridge''s own environment - its environment has none of them; the preflight is available' ($p1.Code -eq 0 -and $login.Count -ge 1 -and $loginText -notmatch 'CLAUDECODE=|CLAUDE_CODE_MESSAGING_TOKEN=' -and (Line $p1.Out 'preflight   :') -match 'available') "$(Line $p1.Out 'preflight   :') | dump: $(($loginText -split "`n" | Where-Object { $_ }) -join ' ')"
    $p2 = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ CLAUDECODE = '1'; CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL = '1'; CODEX_CONSULT_TEST_HIDE_FAIL = 'CLAUDECODE' }
    $pv2 = @($p2.Previews)[0]
    Check 'HIDE' 'D4 both paths fail: the probe is SKIPPED - never started with the markers -, the preflight reads "not checked - `codex login status` was skipped: ..." (a real run is refused, fail-closed) and warnings[] says why ("a launcher probe was skipped: ...")' ($p2.Code -eq 0 -and (Line $p2.Out 'preflight   :') -match 'not checked - `codex login status` was skipped: ' -and @($pv2.warnings | Where-Object { ([string]$_) -like 'a launcher probe was skipped*' }).Count -ge 1) "$(Line $p2.Out 'preflight   :') | $(@($pv2.warnings) -join ' / ')"
}

# =============================================================== STREAM: the bounded reader (D5), the capped tool suspension (D6)
if (Want 'STREAM') {
    $sf = Join-Path $work 'stream.jsonl'
    [IO.File]::WriteAllText($sf, "a`n" + ('x' * 3000), $u8)
    $g1 = Read-StreamChunk -Path $sf -CarryCap 1000
    [IO.File]::AppendAllText($sf, "tail-of-the-long-line`nb`npart", $u8)
    $g2 = Read-StreamChunk -Path $sf -Offset $g1.Offset -Carry $g1.Carry -Discarding $g1.Discarding -CarryCap 1000
    [IO.File]::AppendAllText($sf, "ial`n", $u8)
    $g3 = Read-StreamChunk -Path $sf -Offset $g2.Offset -Carry $g2.Carry -Discarding $g2.Discarding -CarryCap 1000
    Check 'STREAM' 'D5 (F30-3, F32-8) the reader is BOUNDED: an unfinished line longer than the cap is dropped at once (carry 0) and skipped up to its end, counted once (Oversized 1), never parsed; the next lines ("b", "partial" across two reads) come through; the growth counts every byte' (($g1.Lines -join '|') -eq 'a' -and $g1.Carry.Length -eq 0 -and $g1.Discarding -and $g1.Oversized -eq 1 -and ($g2.Lines -join '|') -eq 'b' -and -not $g2.Discarding -and $g2.Carry.Length -eq 4 -and ($g3.Lines -join '|') -eq 'partial' -and $g1.Bytes -eq 3002) "g1 [$($g1.Lines -join '|')] carry $($g1.Carry.Length) disc $($g1.Discarding) over $($g1.Oversized) bytes $($g1.Bytes) | g2 [$($g2.Lines -join '|')] carry $($g2.Carry.Length) | g3 [$($g3.Lines -join '|')]"
    $bf = Join-Path $work 'big.jsonl'
    $fs = New-Object IO.FileStream($bf, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
    $chunk = New-Object byte[] (1MB)
    for ($i = 0; $i -lt $chunk.Length; $i++) { $chunk[$i] = 120 }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $off = 0; $carry = [byte[]]@(); $disc = $false; $over = 0; $maxCarry = 0
    for ($k = 0; $k -lt 24; $k++) {
        $fs.Write($chunk, 0, $chunk.Length); $fs.Flush()
        $x = Read-StreamChunk -Path $bf -Offset $off -Carry $carry -Discarding $disc
        $off = $x.Offset; $carry = $x.Carry; $disc = $x.Discarding; $over += $x.Oversized
        if ($carry.Length -gt $maxCarry) { $maxCarry = $carry.Length }
    }
    $fs.Dispose()
    $sw.Stop()
    Check 'STREAM' 'D5 one line of 24 MiB that never ends, read in 24 polls of +1 MiB: the carry never exceeds the 1 MiB cap, the line is counted once, the polls stay linear (well under 20 s in all)' ($maxCarry -le 1048576 -and $over -eq 1 -and $disc -and $sw.Elapsed.TotalSeconds -lt 20) "max carry $maxCarry, oversized $over, $([math]::Round($sw.Elapsed.TotalSeconds, 2)) s"
    # D6: a tool call open past the cap resumes the stall timer
    $ef = Join-Path $work 'tool.jsonl'
    [IO.File]::WriteAllText($ef, '{"type":"item.started","item":{"id":"item_9","type":"command_execution","command":"long build","status":"in_progress"}}' + "`n", $u8)
    $env:CODEX_CONSULT_TEST_WAIT_TICK_MS = '200'
    $env:CODEX_CONSULT_TEST_TOOL_CAP_SEC = '4'
    $pl = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 40' -PassThru -WindowStyle Hidden
    $w6 = [Diagnostics.Stopwatch]::StartNew()
    $wc = Wait-EngineProcess -Process $pl -TimeoutSec 20 -StallSec 2 -EventsPath $ef
    $w6.Stop()
    try { Stop-Process -Id $pl.Id -Force -ErrorAction SilentlyContinue } catch { }
    Remove-Item env:CODEX_CONSULT_TEST_TOOL_CAP_SEC
    $pl2 = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 40' -PassThru -WindowStyle Hidden
    $wn = Wait-EngineProcess -Process $pl2 -TimeoutSec 7 -StallSec 2 -EventsPath $ef
    try { Stop-Process -Id $pl2.Id -Force -ErrorAction SilentlyContinue } catch { }
    Remove-Item env:CODEX_CONSULT_TEST_WAIT_TICK_MS
    Check 'STREAM' 'D6 (F32-7) a tool call cannot suspend the stall timer for ever: open past the cap (max(3 x stall, 1800 s); test hook 4 s) with no growth, the timer resumes from the last byte - Reason stall, ToolOpen >= 4 s, Silent >= 2 s, well before the timeout; under the cap (1800 s here) the suspension holds until the timeout' ($wc.Reason -eq 'stall' -and $wc.ToolOpen -ge 4 -and $wc.Silent -ge 2 -and $w6.Elapsed.TotalSeconds -lt 15 -and $wn.Reason -eq 'timeout') "capped: $($wc.Reason) open $($wc.ToolOpen) s silent $($wc.Silent) s in $([math]::Round($w6.Elapsed.TotalSeconds, 1)) s | uncapped: $($wn.Reason)"
    $r = New-Repo 'toolcap'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'tc', '-StallSec', '3', '-ContinueSec', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_TOOL_OPEN = '40'; CODEX_CONSULT_TEST_TOOL_CAP_SEC = '5'; CODEX_CONSULT_TEST_WAIT_TICK_MS = '250' }
    $e = @(Ledger $r)[-1]
    Check 'STREAM' 'D6 end to end: a codex member whose tool call stays open (FAKE_CODEX_TOOL_OPEN) past the cap is cut: "failed: stalled after 3 s without an event - no output for N s (a tool call open for M s) (process tree killed)", ledger stall {seconds 3}' ($x.Code -eq 1 -and $e.bridge_outcome -match '^failed: stalled after 3 s without an event - no output for \d+ s \(a tool call open for \d+ s\) \(process tree killed\)$' -and $e.stall.seconds -eq 3) "$($e.bridge_outcome)"
}

# =============================================================== HEALTH: every failure retried and named (D7), the in-lock retry bounded (D8)
if (Want 'HEALTH') {
    $r = New-Repo 'health'
    $missing = Join-Path (Join-Path $work 'no-such-dir') 'health.json'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'hm') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $missing }
    $e = @(Ledger $r)[-1]
    $cause = "the directory $(Split-Path -Parent $missing) does not exist"
    Check 'HEALTH' 'D7 (F30-7, F29-1, F32-3) a failure that is no lock timeout (the health file''s directory is missing) is retried too and NAMED: warnings[] "machine-wide health not updated at the commit (the directory ... does not exist); retried after it", the summary "warning    : machine-wide health not updated (the directory ... does not exist)"; the run delivers' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply' -and @($e.warnings) -contains "machine-wide health not updated at the commit ($cause); retried after it" -and $x.Out.Contains("warning    : machine-wide health not updated ($cause)")) "$(@($e.warnings) -join ' / ')"
    $hL = Join-Path $work 'health-lock.json'
    $env:CODEX_CONSULT_HEALTH = $hL
    $env:CODEX_CONSULT_TEST_HEALTH_LOCK_SEC = '5'
    $lk = [IO.File]::Open("$hL.lock", [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $w1 = [Diagnostics.Stopwatch]::StartNew()
        $ok1 = Update-MachineHealth -AddRunning ([pscustomobject]@{ endpoint = 'e'; pid = $PID }) -Attempts 1 -AttemptSec 1
        $w1.Stop()
        $err1 = [string]$script:MachineHealthLastError
    } finally { $lk.Dispose() }
    Remove-Item env:CODEX_CONSULT_TEST_HEALTH_LOCK_SEC
    $env:CODEX_CONSULT_HEALTH = 'none'
    Check 'HEALTH' 'D8 (F32-2) the retry inside the task write lock is ONE attempt of at most 1 s (Update-MachineHealth -Attempts 1 -AttemptSec 1, even when an attempt would last 5 s): false after about 1 s, cause "lock timeout"' (-not $ok1 -and $err1 -eq 'lock timeout' -and $w1.Elapsed.TotalSeconds -lt 2.5) "$ok1 '$err1' in $([math]::Round($w1.Elapsed.TotalSeconds, 2)) s"
    $lk = [IO.File]::Open("$hL.lock", [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $x2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'hl') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hL; CODEX_CONSULT_TEST_HEALTH_LOCK_SEC = '1' }
    } finally { $lk.Dispose() }
    $e2 = @(Ledger $r)[-1]
    Check 'HEALTH' 'D8 end to end (the health lock held elsewhere): the ledger entry, written inside the write lock, says "machine-wide health not updated at the commit (lock timeout); retried after it"; the full retry outside the lock fails too and the summary says "machine-wide health not updated (lock timeout)"' ($x2.Code -eq 0 -and @($e2.warnings) -contains 'machine-wide health not updated at the commit (lock timeout); retried after it' -and $x2.Out -match '(?m)^warning    : machine-wide health not updated \(lock timeout\)\r?$') "$(@($e2.warnings) -join ' / ')"
}

# =============================================================== COORD: the coordinator (D9-D12)
if (Want 'COORD') {
    $roster = [pscustomobject]@{ Exists = $true; Entries = @(
            [pscustomobject]@{ Position = 1; Provider = 'openai'; Model = 'gpt-5.1'; Engine = 'codex' },
            [pscustomobject]@{ Position = 2; Provider = 'mimo'; Model = ''; Engine = 'codex' },
            [pscustomobject]@{ Position = 3; Provider = 'ZAI'; Model = 'glm-5.3'; Engine = 'codex' },
            [pscustomobject]@{ Position = 4; Provider = 'ZAI'; Model = 'glm-5.2'; Engine = 'codex' },
            [pscustomobject]@{ Position = 5; Provider = 'gemini'; Model = 'g-3'; Engine = 'agy' }) }
    $def = [pscustomobject]@{ Provider = 'openai'; Model = 'gpt-5.1' }
    $tri = @(foreach ($v in @('#2', 'mimo', 'openai', 'ZAI', 'gemini :: g-3', 'ZAI :: glm-5.3')) { $x = (Resolve-CoordinatorIdentity -Value $v -Roster $roster -Defaults $def).Record; "$($x.provider)/$($x.model)/$($x.engine)" })
    Check 'COORD' 'D9 (F30-8) a resolved TRIPLE through the seated reviewer''s rules: #2 (a model-less entry) and the label mimo -> the model the bridge would run (the config''s gpt-5.1), openai -> its entry''s model, ZAI (two entries of two models) -> no model named, a lineage -> its roster entry''s engine (gemini: agy)' (($tri -join ' ') -eq 'mimo/gpt-5.1/codex mimo/gpt-5.1/codex openai/gpt-5.1/codex ZAI// gemini/g-3/agy ZAI/glm-5.3/codex') ($tri -join ' ')
    $cZai = (Resolve-CoordinatorIdentity -Value 'ZAI' -Roster $roster -Defaults $def).Record
    $cMimo = (Resolve-CoordinatorIdentity -Value '#2' -Roster $roster -Defaults $def).Record
    $m = @(
        (Get-CoordinatorMatch -Coordinator $cZai -Provider 'ZAI' -Model 'glm-5.2' -Engine 'codex'),
        (Get-CoordinatorMatch -Coordinator $cMimo -Provider 'mimo' -Model 'gpt-5.1' -Engine 'codex'),
        (Get-CoordinatorMatch -Coordinator $cMimo -Provider 'mimo' -Model 'mimo-v2' -Engine 'codex'),
        (Get-CoordinatorMatch -Coordinator $cMimo -Provider 'openai' -Model 'gpt-5.1' -Engine 'codex'))
    Check 'COORD' 'D9 (F32-6) "own model" only when provider, model and engine are equal: a label that names no model -> "provider" (the weaker warning, "a reviewer from the coordinator''s own provider (model not named)"); #2 resolved -> own for its model only, nothing for another model or provider' (($m -join ',') -eq 'provider,own,,' -and (Format-CoordinatorWarning -Lineage 'ZAI :: glm-5.2' -Kind 'provider') -match "a reviewer from the coordinator's own provider \(model not named\)") ($m -join ',')
    $rf = Write-Roster 'chars' '{"roster_version":1,"reviewers":[{"provider":"Acme Lab","model":"model v2"}]}'
    $loc = [pscustomobject]@{ Path = $rf; FromEnv = $true; Disabled = $false }
    $ro = Read-ReviewerRoster -Location $loc
    $ca = Resolve-CoordinatorIdentity -Value 'Acme Lab :: model v2' -Roster $ro -Defaults $def
    $rfb = Write-Roster 'charsbad' '{"roster_version":1,"reviewers":[{"provider":"acme|lab","model":"m"}]}'
    $rob = Read-ReviewerRoster -Location ([pscustomobject]@{ Path = $rfb; FromEnv = $true; Disabled = $false })
    $cb = Resolve-CoordinatorIdentity -Value 'acme|lab :: m' -Roster $null -Defaults $def
    Check 'COORD' 'D10 (F30-9) ONE character rule (Get-IdentityStringProblem): the roster accepts provider "Acme Lab" and model "model v2" and so does the coordinator value (in_roster true); a "|" is refused by both' (-not $ro.Error -and -not $ca.Error -and $ca.Record.in_roster -eq $true -and $ca.Record.model -eq 'model v2' -and $rob.Error -match "must not contain '\|'" -and $cb.Error -match "must not contain '\|'") "$($ro.Error) | $($ca.Error) | $($rob.Error) | $($cb.Error)"
    $r = New-Repo 'coord'
    $d1 = Consult $r $roster2 @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_COORDINATOR = 'ZAI :: glm-9' }
    $p1 = @($d1.Previews)[0]
    $x1 = Consult $r $roster2 @('-Prompt', 'x', '-ReplyName', 'c1') @{ CODEX_CONSULT_COORDINATOR = 'ZAI :: glm-9'; FAKE_CODEX_REPLY = $advise }
    $e1 = @(Ledger $r)[-1]
    Check 'COORD' 'D11 (F32-4) a coordinator no roster entry matches is SAID, not refused: the dry run''s "coordinator : ZAI :: glm-9; ... (not in the roster - no reviewer can match it)", the real run''s console line "coordinator: ZAI :: glm-9 (not in the roster - no reviewer can match it)", ledger coordinator.in_roster false' ($d1.Code -eq 0 -and (Line $d1.Out 'coordinator :') -match '\(not in the roster - no reviewer can match it\)$' -and $p1.coordinator.in_roster -eq $false -and $x1.Code -eq 0 -and $x1.Out -match '(?m)^coordinator: ZAI :: glm-9 \(not in the roster - no reviewer can match it\)' -and $e1.coordinator.in_roster -eq $false) "$(Line $d1.Out 'coordinator :') | $($e1.coordinator | ConvertTo-Json -Compress)"
    $x2 = Consult $r $roster2 @('-Prompt', 'x', '-ReplyName', 'c2') @{ CODEX_CONSULT_COORDINATOR = '#9'; FAKE_CODEX_REPLY = $advise }
    $e2 = @(Ledger $r)[-1]
    Check 'COORD' 'D12 (F32-5) "#9" names no roster position here - NOT a refusal: the run delivers (exit 0), ledger coordinator {unresolved "#9", source explicit, in_roster false}, warnings[] "CODEX_CONSULT_COORDINATOR ''#9'' names no roster position here ..."' ($x2.Code -eq 0 -and $e2.coordinator.unresolved -eq '#9' -and $e2.coordinator.in_roster -eq $false -and @($e2.warnings | Where-Object { ([string]$_) -like "CODEX_CONSULT_COORDINATOR '#9' names no roster position here*" }).Count -eq 1) "exit $($x2.Code) $($e2.coordinator | ConvertTo-Json -Compress)"
    $rz = Write-Roster 'zai2' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"ZAI","model":"glm-5.2"}]}'
    $x3 = Consult $r $rz @('-Prompt', 'x', '-ReplyName', 'c3') @{ CODEX_CONSULT_COORDINATOR = 'ZAI'; FAKE_CODEX_REPLY = $advise }
    $e3 = @(Ledger $r)[-1]
    Check 'COORD' 'D9 end to end: the coordinator names only the provider ZAI (two roster models: no model named) and the walk seats ZAI :: glm-5.3 - the WEAKER warning "coordinator: ZAI :: glm-5.3 is a reviewer from the coordinator''s own provider (model not named) ...", never "own model"' ($x3.Code -eq 0 -and @($e3.warnings | Where-Object { ([string]$_) -like "coordinator: ZAI :: glm-5.3 is a reviewer from the coordinator's own provider (model not named)*" }).Count -eq 1 -and @($e3.warnings | Where-Object { ([string]$_) -like "*the coordinator's own model (CODEX_CONSULT_COORDINATOR) - a second opinion*" }).Count -eq 0 -and $null -eq $e3.coordinator.model) "$(@($e3.warnings) -join ' / ')"
}

# =============================================================== POINTER: the hook's command runnable as printed (D13), -Explain disposes (D15)
if (Want 'POINTER') {
    $r = New-Repo 'pointer'
    # the hook finds `codex` on PATH: a fake one first (never the machine's codex)
    $bin = Join-Path $work 'bin'
    [void][IO.Directory]::CreateDirectory($bin)
    [IO.File]::WriteAllText((Join-Path $bin 'codex.cmd'), "@echo off`r`nset ""FAKE_CODEX_ARGS=%*""`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""$(Join-Path $sp 'fake-codex3.ps1')""`r`nexit /b %ERRORLEVEL%`r`n")
    $savedPath = $env:Path
    $env:Path = "$bin;$savedPath"
    try { $h = Run-Raw $hookPs $r @() } finally { $env:Path = $savedPath }
    $pl = @(($h.Out -split "`n") | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ -like 'codex-consult: coordinator rules - *' }) | Select-Object -First 1
    $cmd = ''
    if ($pl -match '\(or (powershell -NoProfile -ExecutionPolicy Bypass -File "([^"]+)" -Explain coordinate)\); telemetry: ') { $cmd = $Matches[1]; $path = $Matches[2] }
    $ex = $null
    if ($cmd) { $ex = Run-Raw $path $r @('-Explain', 'coordinate') }
    Check 'POINTER' 'D13 (F32-9) the hook''s pointer line prints the FULL command of this plugin''s script (powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>\scripts\codex-consult.ps1" -Explain coordinate) - run as printed it gives the coordinate skill (exit 0) with the plugin root filled in' ($cmd -and (Test-Path -LiteralPath $path) -and $path -eq (Join-Path $scripts 'codex-consult.ps1') -and $ex.Code -eq 0 -and $ex.Out -match '^codex-consult -Explain coordinate: the coordinate skill' -and -not $ex.Out.Substring($ex.Out.IndexOf("`n")).Contains('${CLAUDE_PLUGIN_ROOT}') -and $ex.Out.Contains($pluginDir)) "$pl"
    $src = Text $consultPs
    Check 'POINTER' 'D15 (F32-11) -Explain flushes AND disposes its output stream (try/finally Dispose)' ($src -match '\$explainOut\.Flush\(\)\s*\r?\n\s*\}\s*finally\s*\{\s*\$explainOut\.Dispose\(\)\s*\}') ''
}

# =============================================================== KILL: the tree kill confirmed (D16)
if (Want 'KILL') {
    $r = New-Repo 'kill'
    $pidDir = Join-Path $work 'kill-pids'
    [void][IO.Directory]::CreateDirectory($pidDir)
    $log = Join-Path $work 'kill-fake.log'
    $killWatch = [Diagnostics.Stopwatch]::StartNew()
    # in the background with its output in files: an orphan that inherited a pipe would hold a synchronous
    # caller until it exits - the bridge's own exit is what counts here
    $kbg = Start-Bg $r '' @('-Prompt', 'x', '-ReplyName', 'k1', '-TimeoutSec', '4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_PIDDIR = $pidDir; FAKE_CODEX_LOG = $log; CODEX_CONSULT_TEST_KILL_DENIED = '1' }
    $x = Wait-Bg $kbg
    $pids = @(Get-ChildItem -LiteralPath $pidDir -Filter '*.pid' | ForEach-Object { [int]$_.BaseName })
    $orphanAlive = @($pids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }).Count
    Stop-Orphans $pidDir
    $e = @(Ledger $r)[-1]
    Check 'KILL' 'D16 (H4) the children cannot be enumerated (test hook CODEX_CONSULT_TEST_KILL_DENIED - process inspection and taskkill denied, as in a restricted host): the outcome NEVER says "(process tree killed)" - "failed: timeout after 4 s (kill not confirmed: ...; pid <n> may still run)", ledger kill_confirmed false, warnings[] "kill not confirmed (main turn): ..."; the fake reviewer really outlived the kill (an orphan, stopped by the harness)' ($x.Code -eq 1 -and $e.bridge_outcome -match '^failed: timeout after 4 s \(kill not confirmed: the children could not be enumerated \(process inspection denied \(test hook CODEX_CONSULT_TEST_KILL_DENIED\)\).*; pid \d+ may still run\)$' -and $e.kill_confirmed -eq $false -and @($e.warnings | Where-Object { ([string]$_) -like 'kill not confirmed (main turn): *' }).Count -eq 1 -and $orphanAlive -ge 1) "$($e.bridge_outcome) | kill_confirmed $($e.kill_confirmed) | orphans $orphanAlive of pids [$($pids -join ',')] after $([math]::Round($killWatch.Elapsed.TotalSeconds, 1)) s"
    Check 'KILL' 'D16 NO continuation turn after an unconfirmed kill (the orphan may still hold the thread): timeout_continue.outcome "not attempted: the kill of the main turn was not confirmed (...)", and the fake saw no `resume` turn' ($e.timeout_continue.outcome -like 'not attempted: the kill of the main turn was not confirmed*' -and (Text $log) -notmatch ' resume ') "$($e.timeout_continue.outcome)"
    $x2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'k2', '-TimeoutSec', '4', '-ContinueSec', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1' }
    $e2 = @(Ledger $r)[-1]
    Check 'KILL' 'D16 a kill that CAN be confirmed (the tree enumerated, every process gone): "failed: timeout after 4 s (process tree killed)", ledger kill_confirmed true' ($x2.Code -eq 1 -and $e2.bridge_outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e2.kill_confirmed -eq $true) "$($e2.bridge_outcome) | $($e2.kill_confirmed)"
    $x3 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'k3') @{ FAKE_CODEX_REPLY = $advise }
    $e3 = @(Ledger $r)[-1]
    Check 'KILL' 'D16 a run without a kill records kill_confirmed null (the key right after stall)' ($x3.Code -eq 0 -and $null -eq $e3.kill_confirmed -and ((($e3.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match ',stall,kill_confirmed,base_commit,')) "$($e3.kill_confirmed)"
}

# =============================================================== KICK: per-request acknowledgements (D1), a kick of the continuation (D2)
if (Want 'KICK') {
    $r = New-Repo 'kick'
    $bg = Start-Bg $r '' @('-Prompt', 'x', '-ReplyName', 'kk', '-TimeoutSec', '90', '-ContinueSec', '0', '-StallSec', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; CODEX_CONSULT_TEST_WAIT_TICK_MS = '5000' }
    $running = Wait-Running $r
    $kp = Join-Path $r '.collab\t\.consult.kick-01'
    # an old acknowledgement of another request, 2 minutes old: swept by the next -Kick
    [IO.File]::WriteAllText("$kp.ack", '{"id":"00000000-0000-0000-0000-000000000000","result":"stopped","when":"' + (Get-IsoTimestamp ((Get-Date).AddMinutes(-2))) + '","pid":1}', $u8)
    Set-CaseEnv '' @{}
    $argText = "-NoProfile -ExecutionPolicy Bypass -File ""$consultPs"" -Task t -Kick -Member 01"
    $o1 = Join-Path $work 'kick1.txt'; $o2 = Join-Path $work 'kick2.txt'
    $k1 = Start-Process -FilePath $psExe -ArgumentList $argText -WorkingDirectory $r -NoNewWindow -PassThru -RedirectStandardOutput $o1 -RedirectStandardError "$o1.err"
    $k2 = Start-Process -FilePath $psExe -ArgumentList $argText -WorkingDirectory $r -NoNewWindow -PassThru -RedirectStandardOutput $o2 -RedirectStandardError "$o2.err"
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $k1.Handle; $null = $k2.Handle } catch { } }
    $null = $k1.WaitForExit(40000); $null = $k2.WaitForExit(40000)
    Restore-Env
    $run = Wait-Bg $bg
    $t1 = Text $o1; $t2 = Text $o2
    $e = @(Ledger $r)[-1]
    Start-Sleep -Milliseconds 500
    Check 'KICK' 'D1 (F30-1, F29-2, F32-1) two concurrent -Kick callers on ONE running member: one request (the second JOINS the first - the file is never overwritten), both callers acknowledged by that request''s id - exit 0 "stopped" each -, the member stopped once ("failed: stopped by the operator (-Kick)"); afterwards no kick file and no acknowledgement left (the creator retires it), the old acknowledgement of another id swept' ($running -and $k1.ExitCode -eq 0 -and $k2.ExitCode -eq 0 -and $t1 -match 'member 01 of task t stopped' -and $t2 -match 'member 01 of task t stopped' -and $e.bridge_outcome -eq 'failed: stopped by the operator (-Kick)' -and -not (Test-Path -LiteralPath $kp) -and -not (Test-Path -LiteralPath "$kp.ack")) "running $running | exits $($k1.ExitCode)/$($k2.ExitCode) | $($e.bridge_outcome) | kick $((Test-Path -LiteralPath $kp)) ack $((Test-Path -LiteralPath "$kp.ack"))"
    # D2: a kick found during the timeout continuation - the timeout outcome and its salvage stay
    $r2 = New-Repo 'kickcont'
    $bg2 = Start-Bg $r2 '' @('-Prompt', 'x', '-ReplyName', 'kc', '-TimeoutSec', '4', '-ContinueSec', '60', '-StallSec', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_HANG_ON = ' resume ' }
    $contRunning = Wait-Running $r2 -Note 'timeout continuation' -TimeoutSec 60
    $kc = Run-Raw $consultPs $r2 @('-Task', 't', '-Kick', '-Member', '01')
    $run2 = Wait-Bg $bg2
    $e2 = @(Ledger $r2)[-1]
    Check 'KICK' 'D2 (F30-5) a kick addresses the RUN: found during the timeout continuation it cancels the continuation - the timeout outcome ("failed: timeout after 4 s (process tree killed)") and its salvage (partial_reply) stay, no provider failure of class operator, warnings[] "kick: the operator stopped the timeout continuation (-Kick); the timeout outcome and its salvage stay"' ($contRunning -and $kc.Code -eq 0 -and $e2.bridge_outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e2.partial_reply -and [string]$e2.timeout_continue.outcome -like '*stopped by the operator (-Kick)*' -and [string](Get-PropertyValue $e2.provider_failure 'class' '') -ne 'operator' -and @($e2.warnings) -contains 'kick: the operator stopped the timeout continuation (-Kick); the timeout outcome and its salvage stay') "running $contRunning kick exit $($kc.Code) | $($e2.bridge_outcome) | cont $($e2.timeout_continue.outcome) | $(@($e2.warnings) -join ' / ')"
}

# =============================================================== ZCODE: the hint (D20) and the completed scrub list (D21)
if (Want 'ZCODE') {
    Clear-TestEnv
    $hh = New-Object System.Collections.Generic.List[string]
    foreach ($case in @(@{ ZCODE_APP_VERSION = '3.14.3' }, @{ ZCODE_PROCESS_LABEL = 'shell' }, @{ ZCODE_ENV = 'production' }, @{ ZCODE_RG_BINARY = 'C:\z\rg.exe'; CLAUDECODE = '1' }, @{ ZCODE_ENV = 'production'; CODEX_THREAD_ID = 'x' }, @{ CLAUDE_PLUGIN_ROOT = 'C:\c' })) {
        Clear-TestEnv
        foreach ($k in $case.Keys) { Set-Item "env:$k" $case[$k] }
        $x = Get-CoordinatorHostHint
        $hh.Add("$($x.Host)/$($x.By)")
    }
    Clear-TestEnv
    $pz = Get-CoordinatorHostHint -ScriptPath 'C:\Users\u\.zcode\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'
    $pc = Get-CoordinatorHostHint -ScriptPath 'C:\Users\u\.codex\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'
    $pa = Get-CoordinatorHostHint -ScriptPath 'C:\Users\u\.claude\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'
    $pn = Get-CoordinatorHostHint -ScriptPath 'C:\repo\.claude\worktrees\x\plugins\codex-consult\scripts'
    Check 'ZCODE' 'D20 the zcode hint from ANY variable with the prefix ZCODE_ (what the shell tool of Z Code really carries: ZCODE_APP_VERSION, ZCODE_PROCESS_LABEL, ZCODE_ENV ...) - after the codex markers, before the claude-code ones; no marker at all -> the install path: a plugin cache under .zcode, .codex, .claude -> zcode, codex, claude-code (by path); a checkout elsewhere and CLAUDE_PLUGIN_ROOT -> unknown (none)' (($hh -join ',') -eq 'zcode/markers,zcode/markers,zcode/markers,zcode/markers,codex/markers,unknown/none' -and "$($pz.Host)/$($pz.By)" -eq 'zcode/path' -and $pc.Host -eq 'codex' -and $pa.Host -eq 'claude-code' -and "$($pn.Host)/$($pn.By)" -eq 'unknown/none') "$($hh -join ',') | $($pz.Host)/$($pz.By) $($pc.Host) $($pa.Host) $($pn.Host)/$($pn.By)"
    $r = New-Repo 'zcode'
    $dumpDir = Join-Path $work 'zcode-env'
    [void][IO.Directory]::CreateDirectory($dumpDir)
    $zEnv = @{ ZCODE_APP_VERSION = '3.14.3'; ZCODE_ENV = 'production'; ZCODE_PROCESS_LABEL = 'shell-tool'; ZCODE_BASE_URL = 'https://fake-27c.invalid'; ZCODE_BUILTIN_PROVIDER_CONFIG_FILE = 'C:\fake-27c\builtin.json'; ZCODE_PERSONAL_PROVIDER_CONFIG_FILE = 'C:\fake-27c\personal.json'; CLAUDE_CODE_USE_BEDROCK = '0'; CLAUDE_PLUGIN_ROOT = 'C:\fake-27c\cplugin'; FAKE_CODEX_REPLY = $advise; FAKE_CODEX_ENV_DUMP = $dumpDir }
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'z') $zEnv
    $e = @(Ledger $r)[-1]
    $ex = @(Get-ChildItem -LiteralPath $dumpDir -Filter 'exec-*.env')
    $exText = $(if ($ex.Count) { Text $ex[0].FullName } else { '' })
    Check 'ZCODE' 'D20/D21 a run from the Z Code shell tool (the names read inside a Z Code session on 2026-09-29): coordinator {host zcode, host_by markers}; child_env_scrubbed = EVERY ZCODE_ name (the provider configuration files included); the engine child has no ZCODE_ variable at all, and still gets CLAUDE_CODE_USE_BEDROCK and CLAUDE_PLUGIN_ROOT (exact CLAUDE_CODE_ names, no CLAUDE prefix)' ($x.Code -eq 0 -and $e.coordinator.host -eq 'zcode' -and $e.coordinator.host_by -eq 'markers' -and (@($e.child_env_scrubbed) -join ',') -eq 'ZCODE_APP_VERSION,ZCODE_BASE_URL,ZCODE_BUILTIN_PROVIDER_CONFIG_FILE,ZCODE_ENV,ZCODE_PERSONAL_PROVIDER_CONFIG_FILE,ZCODE_PROCESS_LABEL' -and $ex.Count -ge 1 -and $exText -notmatch '(?m)^ZCODE_' -and $exText -match 'CLAUDE_CODE_USE_BEDROCK=0' -and $exText -match 'CLAUDE_PLUGIN_ROOT=') "$($e.coordinator | ConvertTo-Json -Compress) scrubbed $(@($e.child_env_scrubbed) -join ',') | child: $(($exText -split "`n" | Where-Object { $_ -like 'ZCODE*' -or $_ -like 'CLAUDE*' }) -join ' ')"
}
# =============================================================== DOCS: D17-D19, D21, D23, D24 (D22: harness-host GREP)
if (Want 'DOCS') {
    $pr = Text (Join-Path $pluginDir 'README.md')
    Check 'DOCS' 'D17 (H1) the plugin directory ships a short README.md: what it is, the three skills, -Explain, the URL of the repository README' ($pr -and $pr.Contains('consult-codex') -and $pr.Contains('coordinate') -and $pr.Contains('setup-providers') -and $pr.Contains('-Explain') -and $pr.Contains('https://github.com/xelth-com/claude-codex-consult')) "$($pr.Length) chars"
    $skills = @('consult-codex', 'coordinate', 'setup-providers') | ForEach-Object { Text (Join-Path $pluginDir "skills\$_\SKILL.md") }
    $readme = Text (Join-Path $repoRoot 'README.md')
    Check 'DOCS' 'D17 the skills name "the repository README" with its URL where they refer to a section of it' (@($skills | Where-Object { $_ -match 'README' -and -not $_.Contains('https://github.com/xelth-com/claude-codex-consult') }).Count -eq 0) ''
    Check 'DOCS' 'D18 (H2) powershell for Windows (always present), pwsh for macOS, Linux and a real PowerShell 7 install; the WindowsApps alias may be refused inside a host sandbox - the README and the consult-codex skill' ($readme.Contains('WindowsApps') -and $skills[0].Contains('WindowsApps')) ''
    Check 'DOCS' 'D19 (H3) the Codex CLI sandbox paragraph states what was observed on 2026-09-29 (codex-cli 0.155.1, workspace-write with network access: the reviewer child had no connection; -DryRun, -Explain, -Status work inside it)' ($readme -match '0\.155\.1' -and $readme -match 'no connection' -and $readme -match 'workspace-write') ''
    Check 'DOCS' 'D21 the README''s scrub list names the whole prefix ZCODE_* and the date and build it was read from (Z Code desktop 3.14.3, 2026-09-29)' ($readme.Contains('`ZCODE_*`') -and $readme -match '3\.14\.3' -and $readme.Contains('ZCODE_PERSONAL_PROVIDER_CONFIG_FILE')) ''
    Check 'DOCS' 'D23 the README names where the three AGENTS.md lines go per host (Codex CLI ~/.codex/AGENTS.md, Z Code ~/.zcode/AGENTS.md, Kimi Code the project file only); the consult-codex skill''s first section: no codex-consult: line in the instructions or the context - run the hook one-liner once' ($readme.Contains('~/.codex/AGENTS.md') -and $readme.Contains('~/.zcode/AGENTS.md') -and $readme -match '(?s)### Kimi Code.*?the project file only' -and $skills[0] -match 'codex-consult-hook\.ps1') ''
    Check 'DOCS' 'D24 the consult-codex and coordinate skills: when the shell tool''s limit is shorter than the purpose''s timeout, or unknown, start with -Detach and come back with -Wait / -Status; the limits seen with their dates (Kimi Code 300 s, Z Code 600 s, 2026-09-29)' ($skills[0] -match '-Detach' -and $skills[0] -match '300 s' -and $skills[1] -match '300 s' -and $skills[1] -match '600 s' -and $skills[1] -match '2026-09-29') ''
}

} finally {
    Restore-Env
    Start-Sleep -Milliseconds 500
    Remove-TestWork $work
}
Write-Host ''
Write-Host ("harness-fixes27c ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
