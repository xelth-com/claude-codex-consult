# E7 / M9-11 re-verified against the permanent held-handle ownership lock. Recovery
# (child pids, survivors, reservations) lives in .consult.pending.json and is covered
# by harness-pending.ps1. Windows; fake codex only.
$ErrorActionPreference = 'Stop'
# These cases use the Codex home of the machine; a reviewer roster there
# (<codex home>/codex-consult-roster.json) must not change what they test: none = no roster.
$env:CODEX_CONSULT_ROSTER = 'none'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$fake = Join-Path $PSScriptRoot 'fake-codex.cmd'
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-lock2') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$dir = Join-Path $work 'lock'
[void][IO.Directory]::CreateDirectory($dir)
$lockPath = Join-Path $dir '.consult.lock'
$u8 = New-Object System.Text.UTF8Encoding($false)
$me = [Environment]::MachineName
$script:fails = 0
function Say { param([string]$Label, [bool]$Ok, [string]$Ev = '') if (-not $Ok) { $script:fails++ }; Write-Host ("{0} {1,-66} {2}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Label, $Ev) }
function Test-LockHeld { param([string]$Path) if (-not (Test-Path $Path)) { return $false }; try { $f = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None); $f.Dispose(); return $false } catch { return $true } }
function G { param([string]$Repo, [string[]]$A) $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = & git -C $Repo @A 2>&1; $ErrorActionPreference = $p; return $o }

$holder = $null
$bg = $null
try {
# 1. a LIVE holder (another process holding the handle) -> refused, message names it
$holderPs = Join-Path $dir 'holder.ps1'
[IO.File]::WriteAllText($holderPs, ". '$scripts\codex-consult-common.ps1'`n`$l = Enter-TaskLock -TaskDir '$dir' -Task 't'`n[IO.File]::WriteAllText('$dir\held.flag', 'x')`nStart-Sleep -Seconds 60`n", $u8)
$holder = Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $holderPs -PassThru -WindowStyle Hidden
for ($i = 0; $i -lt 80 -and -not (Test-Path "$dir\held.flag"); $i++) { Start-Sleep -Milliseconds 250 }
$r1 = Enter-TaskLock -TaskDir $dir -Task 't'
Say '1 live holder -> refused, message names its pid' ((-not $r1.Acquired) -and $r1.Message -match "held open by pid $($holder.Id) on $me since ") ''
$wr = $true; try { [IO.File]::WriteAllText($lockPath, 'x') } catch { $wr = $false }
$del = $true; try { [IO.File]::Delete($lockPath) } catch { $del = $false }
Say '1b held lock cannot be overwritten or deleted by others' ((-not $wr) -and (-not $del) -and (Test-Path $lockPath)) "write=$wr delete=$del"

# 2. the holder dies (hard kill): the OS drops the handle; the next Enter simply opens it
Stop-Process -Id $holder.Id -Force; $holder.WaitForExit()
$r2 = Enter-TaskLock -TaskDir $dir -Task 't'
Say '2 dead holder -> reopened, no heuristics' ($r2.Acquired) ''
$heldNow = Test-LockHeld $lockPath
Exit-TaskLock -Lock $r2
Say '2b release = close only: file kept, no longer held' ($heldNow -and (Test-Path $lockPath) -and -not (Test-LockHeld $lockPath)) ''

# 3. lock content is informational only
$l3 = Enter-TaskLock -TaskDir $dir -Task 't'
Write-Host "   lock record: $(Get-Content -Raw $lockPath)"
Exit-TaskLock -Lock $l3
Say '3 lock content = { pid, start_time, host, task, started } only' (((Read-LockContent -Path $lockPath).PSObject.Properties.Name -join ',') -eq 'pid,start_time,host,task,started') ''

# 4. real runs (E7): a consultation in flight holds the task; a second consultation and a
#    findings update are refused; -List works; afterwards the lock is free and no
#    recovery record is left. A fresh repository, seeded with one consultation that
#    records findings.
$repo = Join-Path $work 'e2e-repo'
[void][IO.Directory]::CreateDirectory($repo)
$null = G $repo @('init', '-q'); $null = G $repo @('config', 'user.email', 't@e.com'); $null = G $repo @('config', 'user.name', 'T')
[IO.File]::WriteAllText((Join-Path $repo 'app.txt'), "line1`n", $u8)
$null = G $repo @('add', '-A'); $null = G $repo @('commit', '-q', '-m', 'init')
$seedReply = Join-Path $work 'r1.json'
[IO.File]::WriteAllText($seedReply, '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"Seed.","reply_markdown":"Seed.","findings":[{"severity":"major","locations":[{"path":"app.txt","line":1}],"claim":"app.txt line 1 is wrong","trigger":"reading it","evidence":[{"kind":"read-code","reference":"app.txt:1","observation":"says line1"}],"verification":"cat app.txt","remedy":"fix it","supersedes":[]}],"prior_findings":[],"unproven":[],"first_run_checklist":[]}', $u8)
$longReply = Join-Path $work 'r2.json'
[IO.File]::WriteAllText($longReply, '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"One more.","reply_markdown":"Checked F01-1.","findings":[],"prior_findings":[{"id":"F01-1","status":"still-open","note":"not fixed yet"}],"unproven":[],"first_run_checklist":[]}', $u8)
Push-Location $repo
$pp = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$env:FAKE_CODEX_REPLY = $seedReply
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'codex-consult.ps1') -Task e2e -CodexExe $fake -Prompt 'seed' -ReplyName 'seed' 2>&1
$seedCode = $LASTEXITCODE
Remove-Item env:FAKE_CODEX_REPLY
$ErrorActionPreference = $pp
Pop-Location
Say '4 seed consultation recorded a finding (F01-1)' ($seedCode -eq 0 -and (Test-Path (Join-Path $repo '.collab\e2e\findings.json'))) "exit $seedCode"

$env:FAKE_CODEX_SLEEP = '12'
$env:FAKE_CODEX_REPLY = $longReply
$bg = Start-Process -FilePath 'powershell.exe' -WorkingDirectory $repo -PassThru -WindowStyle Hidden -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scripts 'codex-consult.ps1'),
    '-Task', 'e2e', '-CodexExe', $fake, '-Prompt', 'long', '-ReplyName', 'long')
Remove-Item env:FAKE_CODEX_SLEEP, env:FAKE_CODEX_REPLY
$taskPending = Join-Path $repo '.collab\e2e\.consult.pending.json'
$taskLock = Join-Path $repo '.collab\e2e\.consult.lock'
$midState = ''
for ($i = 0; $i -lt 60; $i++) { $p = Read-PendingFile -Path $taskPending; if ($p.Record -and $p.Record.state -eq 'running') { $midState = "running child_pid=$($p.Record.child_pid)"; break }; Start-Sleep -Milliseconds 250 }
Push-Location $repo
$pp = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$o1 = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'codex-consult.ps1') -Task e2e -CodexExe $fake -Prompt 'second' 2>&1) -join ' '
$c1 = $LASTEXITCODE
$o2 = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'codex-findings.ps1') -Task e2e -Id F01-1 -Status implemented 2>&1) -join ' '
$c2 = $LASTEXITCODE
$o3 = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'codex-findings.ps1') -Task e2e -List 2>&1) -join ' '
$c3 = $LASTEXITCODE
$ErrorActionPreference = $pp
Pop-Location
$bg.WaitForExit()
Say '4 in flight: pending record says running with the child pid' ([bool]$midState) $midState
Say '4 in flight: 2nd consult refused' ($c1 -eq 1 -and $o1 -match 'held open by pid \d+') ''
Say '4 in flight: findings -Status refused' ($c2 -eq 1 -and $o2 -match 'held open by pid \d+') ''
Say '4 in flight: -List works and shows the pending record' ($c3 -eq 0 -and $o3 -match 'pending: state=running') ''
Say '4 finished (exit 0): lock free, file kept, no recovery record' ($bg.ExitCode -eq 0 -and (Test-Path $taskLock) -and -not (Test-LockHeld $taskLock) -and -not (Test-Path $taskPending)) "bg exit $($bg.ExitCode)"
} finally {
    Remove-Item env:FAKE_CODEX_SLEEP, env:FAKE_CODEX_REPLY -ErrorAction SilentlyContinue
    if ($holder -and -not $holder.HasExited) { try { Stop-Process -Id $holder.Id -Force } catch { } }
    if ($bg -and -not $bg.HasExited) { try { $bg.WaitForExit(30000) | Out-Null } catch { } }
    Remove-TestWork $work
}

Write-Host ""
Write-Host "harness-lock2: $script:fails failure(s)."
if ($script:fails -gt 0) { exit 1 }
exit 0
