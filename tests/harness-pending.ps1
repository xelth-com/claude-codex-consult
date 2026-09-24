# Ownership vs recovery metadata (review F06-1, F06-2, F06-3, F04-10): coordinator cases
# (a)..(g) plus the crash-at-acquisition proof. Fake codex only.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
# These cases use the Codex home of the machine; a reviewer roster there
# (<codex home>/codex-consult-roster.json) must not change what they test: none = no roster.
$env:CODEX_CONSULT_ROSTER = 'none'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$fake = Join-Path $sp 'fake-codex.cmd'
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-pending') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
try {
$u8 = New-Object System.Text.UTF8Encoding($false)
$me = [Environment]::MachineName
$script:fails = 0
function Check { param([string]$Id, [string]$What, [bool]$Ok, [string]$Ev = '') if (-not $Ok) { $script:fails++ }; Write-Host ("{0} {1,-4} {2}{3}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Id, $What, $(if ($Ev) { "  | $Ev" } else { '' })) }
function Cut { param([string]$S) if ($S.Length -gt 200) { return $S.Substring(0, 200) }; return $S }
function Want { param([string]$Name) return (-not $Only -or ($Only -split ',') -contains $Name) }
function G { param([string]$Repo, [string[]]$A) $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = & git -C $Repo @A 2>&1; $ErrorActionPreference = $p; return $o }
function New-Repo {
    param([string]$Name, [switch]$CaseSensitive)
    $r = Join-Path $work $Name
    if (Test-Path $r) { Remove-Item $r -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($r)
    if ($CaseSensitive) { $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $null = & fsutil.exe file setCaseSensitiveInfo $r enable 2>&1; $ErrorActionPreference = $p }
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    [IO.File]::WriteAllText((Join-Path $r '.gitignore'), "*.bin`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
function Clear-FakeEnv { foreach ($k in @('FAKE_CODEX_REPLY', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_FAIL', 'FAKE_CODEX_TOUCH', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_LOG', 'FAKE_CODEX_NOUSAGE')) { Remove-Item "env:$k" -ErrorAction SilentlyContinue } }
function Run-Script {
    param([string]$Script, [string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{})
    Clear-FakeEnv
    foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -Task t @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Clear-FakeEnv
    return [pscustomobject]@{ Code = $code; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
}
function Consult { param([string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{}) return (Run-Script (Join-Path $scripts 'codex-consult.ps1') $Repo (@('-CodexExe', $fake) + $ArgList) $Env) }
function Findings { param([string]$Repo, [string[]]$ArgList) return (Run-Script (Join-Path $scripts 'codex-findings.ps1') $Repo $ArgList) }
function Last-Entry { param([string]$Repo) return @((Get-Content -Raw (Join-Path $Repo '.collab\t\sessions.json') | ConvertFrom-Json).codex.consults)[-1] }
function Sha { param([string]$Path) return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash }
function Test-LockHeld { param([string]$Path) if (-not (Test-Path $Path)) { return $false }; try { $f = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None); $f.Dispose(); return $false } catch { return $true } }
function Seed-Pending {
    param([string]$Repo, [string]$State, [int]$N, [string]$Nn, [string]$Started = '', [string]$Launcher = '', $ChildPid = 'null', [string]$ChildStart = '', [string]$Survivors = '', [string]$HostName = $me)
    if (-not $Started) { $Started = Get-IsoTimestamp }
    $json = '{"state":"' + $State + '","n":' + $N + ',"nn":"' + $Nn + '","reply":"handoffs/' + $Nn + '-codex-old.md","started":"' + $Started + '","pid":1,"host":"' + $HostName + '","launcher":' + (ConvertTo-Json $Launcher) + ',"child_pid":' + $ChildPid + ',"child_start_time":"' + $ChildStart + '","survivors":[' + $Survivors + '],"note":""}'
    $p = Join-Path $Repo '.collab\t\.consult.pending.json'
    [IO.File]::WriteAllText($p, $json, $u8)
    return $p
}
$advise = Join-Path $work 'advise.json'
[IO.File]::WriteAllText($advise, '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}', $u8)

# ------------------------------------------------------------------ (a) reserved from a dead run
if (Want 'a') {
    $r = New-Repo 'a'
    $pend = Seed-Pending $r 'reserved' 9 '20'
    $l = Findings $r @('-List')
    Check '(a)' '-List shows the interrupted reservation' ($l.Out -match 'pending: state=reserved, n=9, nn=20') (($l.Out -split "`n" | Where-Object { $_ -match '^pending' }) -join '')
    $d = Consult $r @('-DryRun', '-Prompt', 'x')
    Check '(a)' 'dry run: next run recovers it -> handoff 21, n=10 (pending untouched)' ($d.Out -match 'handoff     : 21 \(consult n = 10\)' -and $d.Out -match 'the next run recovers it' -and (Test-Path $pend)) (($d.Out -split "`n" | Where-Object { $_ -match '^pending|^handoff' }) -join ' / ')
    $x = Consult $r @('-Prompt', 'x', '-ReplyName', 'rec') @{ FAKE_CODEX_REPLY = $advise }
    $e = Last-Entry $r
    Check '(a)' 'run: "recovered reservation n=9, nn=20", commits n=10 / 21-codex-rec.md, pending removed' ($x.Code -eq 0 -and $x.Out -match 'recovered reservation n=9, nn=20' -and $e.n -eq 10 -and $e.reply -eq 'handoffs/21-codex-rec.md' -and -not (Test-Path $pend)) "n=$($e.n) reply=$($e.reply)"
}

# ------------------------------------------------------------------ F06-1 nothing is destroyed before it is judged
if (Want 'F06-1') {
    $r = New-Repo 'f61'
    $td = Join-Path $r '.collab\t'
    Write-JsonFile -Path (Join-Path $td 'findings.json') -Object ([pscustomobject]@{ task_id = 't'; findings = [object[]]@([pscustomobject]@{ id = 'F01-1'; status = 'proposed'; severity = 'major'; claim = 'c'; source = [pscustomobject]@{ consult = 1; reply = 'handoffs/01-codex-a.md' } }) })
    $sleeper = Start-Process powershell.exe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 60' -PassThru -WindowStyle Hidden
    $pend = Seed-Pending $r 'running' 9 '20' -ChildPid $sleeper.Id -ChildStart (Get-ProcessStartIso -ProcessId $sleeper.Id) -Survivors "$($sleeper.Id)"
    $h0 = Sha $pend
    # crash right after acquiring and reading (the old failure window): a process takes the
    # lock, reads the record, and dies
    $crash = Join-Path $work 'crash-acquire.ps1'
    [IO.File]::WriteAllText($crash, ". '$scripts\codex-consult-common.ps1'`n`$l = Enter-TaskLock -TaskDir '$td' -Task 't'`n`$p = Read-PendingFile -Path '$pend'`n[Environment]::Exit(9)`n", $u8)
    $cp = Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $crash -PassThru -WindowStyle Hidden; $cp.WaitForExit()
    Check 'F06-1' 'crash right after acquisition + read: pending record byte-identical' ((Sha $pend) -eq $h0) ''
    $x = Consult $r @('-Prompt', 'x') @{ FAKE_CODEX_REPLY = $advise }
    $f = Findings $r @('-Id', 'F01-1', '-Status', 'implemented')
    $s = Findings $r @('-Stats')
    Check 'F06-1' 'live child: consult and -Status refused, record byte-identical after both' ($x.Code -eq 1 -and $x.Out -match "\(pid $($sleeper.Id)\) is still running" -and $f.Code -eq 1 -and $f.Out -match 'is still running' -and (Sha $pend) -eq $h0) (($x.Out -split "`n")[0])
    Stop-Process -Id $sleeper.Id -Force; $sleeper.WaitForExit()
    $y = Consult $r @('-Prompt', 'x', '-ReplyName', 'after') @{ FAKE_CODEX_REPLY = $advise }
    $e = Last-Entry $r
    Check 'F06-1' 'child gone: reservation consumed (n=10, 21-...), then replaced/removed' ($y.Code -eq 0 -and $y.Out -match 'recovered reservation n=9, nn=20' -and $e.n -eq 10 -and $e.reply -eq 'handoffs/21-codex-after.md' -and -not (Test-Path $pend)) "n=$($e.n) reply=$($e.reply)"
    [IO.File]::WriteAllText($pend, '{ "state": "running", "n": 1', $u8)
    $z = Consult $r @('-Prompt', 'x')
    $zf = Findings $r @('-Id', 'F01-1', '-Status', 'implemented')
    Check 'F06-1' 'unparseable pending record -> consult and -Status refuse, file untouched' ($z.Code -eq 1 -and $z.Out -match 'recovery record .* is unusable' -and $zf.Code -eq 1 -and ([IO.File]::ReadAllText($pend)) -eq '{ "state": "running", "n": 1') (Cut (($z.Out -split "`n")[0]))
    Remove-Item $pend
}

# ------------------------------------------------------------------ (b) launching
if (Want 'b') {
    $r = New-Repo 'b'
    $pend = Seed-Pending $r 'launching' 4 '05' -Started (Get-IsoTimestamp) -Launcher $fake
    Start-Sleep -Seconds 1
    $x = Consult $r @('-Prompt', 'x', '-ReplyName', 'none') @{ FAKE_CODEX_REPLY = $advise }
    Check '(b)' 'launching, no codex process -> recovered (says which scan was used)' ($x.Code -eq 0 -and $x.Out -match "recovered reservation n=4, nn=05 \(state 'launching' of an interrupted run; Win32_Process scan .*: none found\)") (($x.Out -split "`n" | Where-Object { $_ -match 'recovered' }) -join '')
    # simulated native binary: a copy of PING.EXE named codex.exe, started after `started`
    $simDir = Join-Path $work 'sim'; [void][IO.Directory]::CreateDirectory($simDir)
    Copy-Item "$env:SystemRoot\System32\PING.EXE" (Join-Path $simDir 'codex.exe') -Force
    $pend = Seed-Pending $r 'launching' 6 '08' -Started (Get-IsoTimestamp ((Get-Date).AddSeconds(-2))) -Launcher $fake
    $sim = Start-Process (Join-Path $simDir 'codex.exe') -ArgumentList '-n', '40', '127.0.0.1' -PassThru -WindowStyle Hidden
    $y = Consult $r @('-Prompt', 'x') @{ FAKE_CODEX_REPLY = $advise }
    Check '(b)' 'launching + a process named codex.exe started since -> refused' ($y.Code -eq 1 -and $y.Out -match "pid $($sim.Id) codex\.exe \[name codex(, task not verifiable)?\]") (Cut (($y.Out -split "`n")[0]))
    Stop-Process -Id $sim.Id -Force; $sim.WaitForExit()
    # the real boundary: the bridge died after Start-Process, before registering - its
    # launcher (the fake shim) is still running
    Clear-FakeEnv; $env:FAKE_CODEX_SLEEP = '40'
    $shim = Start-Process -FilePath $fake -PassThru -WindowStyle Hidden
    Clear-FakeEnv
    Start-Sleep -Milliseconds 800
    $z = Consult $r @('-Prompt', 'x') @{ FAKE_CODEX_REPLY = $advise }
    Check '(b)' 'launching + the launcher shim still running -> refused (launcher rule)' ($z.Code -eq 1 -and $z.Out -match 'launcher in command line') (Cut (($z.Out -split "`n")[0]))
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; & taskkill.exe /PID $shim.Id /T /F 2>&1 | Out-Null; $ErrorActionPreference = $p
    Start-Sleep -Milliseconds 500
    $w = Consult $r @('-Prompt', 'x', '-ReplyName', 'after') @{ FAKE_CODEX_REPLY = $advise }
    Check '(b)' 'processes gone -> recovered n=6/nn=08' ($w.Code -eq 0 -and $w.Out -match 'recovered reservation n=6, nn=08') ''
    $pend = Seed-Pending $r 'launching' 11 '12' -HostName 'OTHER-HOST'
    $o = Consult $r @('-Prompt', 'x', '-ReplyName', 'other') @{ FAKE_CODEX_REPLY = $advise }
    Check '(b)' 'launching from another host (no pids) -> treated as dead' ($o.Code -eq 0 -and $o.Out -match "from host OTHER-HOST without pids: treated as dead") ''
}

# ------------------------------------------------------------------ (c) running
if (Want 'c') {
    $r = New-Repo 'c'
    $child = Start-Process powershell.exe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 60' -PassThru -WindowStyle Hidden
    $pend = Seed-Pending $r 'running' 2 '03' -ChildPid $child.Id -ChildStart (Get-ProcessStartIso -ProcessId $child.Id)
    $x = Consult $r @('-Prompt', 'x') @{ FAKE_CODEX_REPLY = $advise }
    Check '(c)' 'running with a live child_pid -> refused' ($x.Code -eq 1 -and $x.Out -match "\(pid $($child.Id)\) is still running") ''
    $pend = Seed-Pending $r 'running' 2 '03' -ChildPid $child.Id -ChildStart '2001-01-01T00:00:00.0000000Z'
    $y = Consult $r @('-Prompt', 'x', '-ReplyName', 'reused') @{ FAKE_CODEX_REPLY = $advise }
    Check '(c)' 'same pid, different start time (reused) -> recovered' ($y.Code -eq 0 -and $y.Out -match 'recovered reservation n=2, nn=03') ''
    Stop-Process -Id $child.Id -Force; $child.WaitForExit()
    $pend = Seed-Pending $r 'running' 7 '09' -ChildPid $child.Id -ChildStart 'x'
    $z = Consult $r @('-Prompt', 'x', '-ReplyName', 'dead') @{ FAKE_CODEX_REPLY = $advise }
    Check '(c)' 'running with a dead child_pid -> recovered' ($z.Code -eq 0 -and $z.Out -match 'recovered reservation n=7, nn=09') ''
    $pend = Seed-Pending $r 'running' 13 '14' -ChildPid 4242 -HostName 'OTHER-HOST'
    $o = Consult $r @('-Prompt', 'x') @{ FAKE_CODEX_REPLY = $advise }
    Check '(c)' 'running from another host with a pid -> refused' ($o.Code -eq 1 -and $o.Out -match 'on host OTHER-HOST left codex process') ''
    Remove-Item $pend
}

# ------------------------------------------------------------------ (d) survivors
if (Want 'd') {
    $r = New-Repo 'd'
    $s1 = Start-Process powershell.exe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 60' -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 1
    $s1Start = (Get-Process -Id $s1.Id).StartTime.ToUniversalTime().ToString('o')
    # wave 3b: survivors are { pid, start_time, name } entries; a bare pid would be judged
    # by the codex rule and a plain powershell sleeper would (correctly) not count.
    $pend = Seed-Pending $r 'survivors' 5 '06' -Survivors ('{"pid":' + $s1.Id + ',"start_time":"' + $s1Start + '","name":"powershell"}')
    $x = Consult $r @('-Prompt', 'x') @{ FAKE_CODEX_REPLY = $advise }
    Check '(d)' 'survivors alive -> refused' ($x.Code -eq 1 -and $x.Out -match "\(pid $($s1.Id)\) is still running") ''
    Stop-Process -Id $s1.Id -Force; $s1.WaitForExit()
    $y = Consult $r @('-Prompt', 'x', '-ReplyName', 'after') @{ FAKE_CODEX_REPLY = $advise }
    Check '(d)' 'survivors gone -> recovered n=5/nn=06' ($y.Code -eq 0 -and $y.Out -match 'recovered reservation n=5, nn=06') ''
}

# ------------------------------------------------------------------ (e) registration write fails
if (Want 'e') {
    # fault injection on a COPY of the scripts: the copy's Write-PendingFile throws for
    # state 'running' (the write right after Start-Process). Everything else is identical.
    $inj = Join-Path $work 'inject'
    if (Test-Path $inj) { Remove-Item $inj -Recurse -Force }
    [void][IO.Directory]::CreateDirectory("$inj\scripts"); [void][IO.Directory]::CreateDirectory("$inj\schemas")
    Copy-Item "$scripts\*.ps1" "$inj\scripts\"; Copy-Item "$scripts\..\schemas\*.json" "$inj\schemas\"
    $libc = "$inj\scripts\codex-consult-common.ps1"
    $t = [IO.File]::ReadAllText($libc)
    $t = $t.Replace("function Write-PendingFile {`n    param([string]`$Path, `$Record)`n", "function Write-PendingFile {`n    param([string]`$Path, `$Record)`n    if (`$Record.state -eq 'running') { throw 'injected: registration write failed' }`n")
    [IO.File]::WriteAllText($libc, $t, $u8)
    $r = New-Repo 'e'
    $pidFile = Join-Path $work 'e-fake.pid'; if (Test-Path $pidFile) { Remove-Item $pidFile }
    $runStart = (Get-Date).AddSeconds(-1)
    $x = Run-Script "$inj\scripts\codex-consult.ps1" $r @('-CodexExe', $fake, '-Prompt', 'x', '-ReplyName', 'inj') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_SLEEP = '40'; FAKE_CODEX_PIDFILE = $pidFile }
    Start-Sleep -Milliseconds 800
    $e = Last-Entry $r
    $pend = (Read-PendingFile -Path (Join-Path $r '.collab\t\.consult.pending.json')).Record
    $left = @((Find-CodexProcesses -Since $runStart -Launcher $fake).Found)
    $grand = if (Test-Path $pidFile) { [int](Get-Content $pidFile) } else { 0 }
    Check '(e)' 'registration write fails -> exit 1, outcome recorded in the ledger' ($x.Code -eq 1 -and $e.bridge_outcome -eq 'failed: could not register the codex process (injected: registration write failed); codex was stopped') "bridge_outcome='$($e.bridge_outcome)'"
    Check '(e)' 'codex child tree killed (no launcher process left, fake grandchild dead)' ($left.Count -eq 0 -and ($grand -eq 0 -or -not (Get-Process -Id $grand -ErrorAction SilentlyContinue))) "launcher processes left=$($left.Count); fake pid file: $(if ($grand) { $grand } else { 'not written' })"
    Check '(e)' "pending stays 'launching' (n/nn of this run), lock not held" ($pend.state -eq 'launching' -and $pend.n -eq 1 -and $pend.nn -eq '01' -and -not (Test-LockHeld (Join-Path $r '.collab\t\.consult.lock'))) "state=$($pend.state) n=$($pend.n) nn=$($pend.nn)"
    $y = Consult $r @('-Prompt', 'x', '-ReplyName', 'next') @{ FAKE_CODEX_REPLY = $advise }
    $e2 = Last-Entry $r
    Check '(e)' 'next (real) run: launching rule finds no codex -> recovered, commits n=2' ($y.Code -eq 0 -and $y.Out -match "(recovered reservation|cleared the recovery record of consult) n=1, nn=01 \(state 'launching'.*Win32_Process scan .*: none found" -and $e2.n -eq 2) "n=$($e2.n) reply=$($e2.reply)"
}

# ------------------------------------------------------------------ (f) the lock file is permanent
if (Want 'f') {
    $r = New-Repo 'f'
    $lockPath = Join-Path $r '.collab\t\.consult.lock'
    function Get-FileId { param([string]$P) $p0 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = (& fsutil.exe file queryFileID $P 2>&1) -join ' '; $ErrorActionPreference = $p0; if ($o -match '(0x[0-9a-fA-F]+)') { return $Matches[1] }; return "?($o)" }
    $x1 = Consult $r @('-Prompt', 'x', '-ReplyName', 'one') @{ FAKE_CODEX_REPLY = $advise }
    $id1 = Get-FileId $lockPath; $c1 = (Get-Item $lockPath).CreationTimeUtc.Ticks
    $x2 = Consult $r @('-Prompt', 'x', '-ReplyName', 'two') @{ FAKE_CODEX_REPLY = $advise }
    $x3 = Consult $r @('-Prompt', 'x', '-ReplyName', 'three', '-TimeoutSec', '2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_SLEEP = '20' }
    $id3 = Get-FileId $lockPath; $c3 = (Get-Item $lockPath).CreationTimeUtc.Ticks
    Check '(f)' 'lock file never deleted: same file id + creation time across 3 runs (incl. a timeout)' ($x1.Code -eq 0 -and $x2.Code -eq 0 -and $x3.Code -eq 1 -and $id1 -eq $id3 -and $c1 -eq $c3) "file id $id1 -> $id3"
    Check '(f)' 'after the runs: lock not held, content = informational holder record only' (-not (Test-LockHeld $lockPath) -and ((Read-LockContent -Path $lockPath).PSObject.Properties.Name -join ',') -eq 'pid,start_time,host,task,started') ((Read-LockContent -Path $lockPath) | ConvertTo-Json -Compress)
    $def = (Get-Command Exit-TaskLock).Definition
    Check '(f)' 'Exit-TaskLock only closes the handle (no Delete / SetLength in it)' ($def -notmatch 'Delete|SetLength') ''
}

# ------------------------------------------------------------------ (g) case-distinct artifacts
if (Want 'g') {
    $r = New-Repo 'g' -CaseSensitive
    [IO.File]::WriteAllText((Join-Path $r 'a.bin'), "same`n", $u8)
    [IO.File]::WriteAllText((Join-Path $r 'A.bin'), "same`n", $u8)
    $files = @(Get-ChildItem -LiteralPath $r -File -Filter '*.bin' | ForEach-Object { $_.Name }) -join ','
    $x = Consult $r @('-Prompt', 'x', '-ReplyName', 'art', '-Artifact', 'a.bin,A.bin') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_TOUCH = (Join-Path $r 'A.bin') }
    $e = Last-Entry $r
    $lo = @($e.artifacts) | Where-Object { $_.path -ceq 'a.bin' }
    $up = @($e.artifacts) | Where-Object { $_.path -ceq 'A.bin' }
    $md = [IO.File]::ReadAllText((Join-Path $r '.collab\t\handoffs\01-codex-art.md'))
    Check '(g)' 'only A.bin changed: its own sha256_after moves, a.bin stays, drift reported for A.bin only' ($up.sha256 -ne $up.sha256_after -and $up.sha256_after -eq (Sha (Join-Path $r 'A.bin')).ToLower() -and $lo.sha256 -eq $lo.sha256_after -and $e.artifacts_changed_during_review -eq $true -and $md -match 'WARNING: artifact\(s\) changed during the review: A\.bin\.') "files=$files; A.bin $($up.sha256.Substring(0,12))->$($up.sha256_after.Substring(0,12)), a.bin $($lo.sha256.Substring(0,12))->$($lo.sha256_after.Substring(0,12))"
}

} finally {
    Remove-TestWork $work
}

Write-Host ""
Write-Host "harness-pending: $script:fails failure(s)."
if ($script:fails -gt 0) { exit 1 }
exit 0
