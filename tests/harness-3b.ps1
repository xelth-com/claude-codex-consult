$ErrorActionPreference = 'Stop'
# These cases use the Codex home of the machine; a reviewer roster there
# (<codex home>/codex-consult-roster.json) must not change what they test: none = no roster.
$env:CODEX_CONSULT_ROSTER = 'none'
. (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'plugins\codex-consult\scripts\codex-consult-common.ps1')
$script:fails = 0
function Check([string]$name, [bool]$cond) { if ($cond) { "PASS $name" } else { "FAIL $name"; $script:fails++ } }
function Rec([string]$state, [hashtable]$extra) {
    $r = [pscustomobject]@{
        state = $state; n = 5; nn = '07'; reply = 'handoffs/07-codex-x.md'
        started = (Get-Date).AddMinutes(-2).ToString('yyyy-MM-ddTHH:mm:sszzz')
        pid = 0; host = [Environment]::MachineName; launcher = ''
        child_pid = $null; child_start_time = $null; survivors = @(); note = ''
    }
    foreach ($k in $extra.Keys) { $r.$k = $extra[$k] }
    return $r
}
$cleanup = New-Object System.Collections.Generic.List[int]
try {
    # ---- (a) survivors entries -------------------------------------------------
    $sleeper = Start-Process powershell -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 120' -PassThru -WindowStyle Hidden
    $cleanup.Add($sleeper.Id)
    Start-Sleep -Seconds 1
    $realStart = (Get-Process -Id $sleeper.Id).StartTime.ToUniversalTime().ToString('o')
    $wrongStart = (Get-Date).AddDays(-1).ToUniversalTime().ToString('o')

    $v1 = Test-PendingActive -Record (Rec 'survivors' @{ survivors = @([pscustomobject]@{ pid = $sleeper.Id; start_time = $wrongStart; name = 'powershell' }) }) -Path 'x'
    Check 'a1 survivor with a reused pid (wrong start time) -> not active' (-not $v1.Active)
    "   a1: $($v1.Check)"
    $v2 = Test-PendingActive -Record (Rec 'survivors' @{ survivors = @([pscustomobject]@{ pid = $sleeper.Id; start_time = $realStart; name = 'powershell' }) }) -Path 'x'
    Check 'a2 survivor with the correct pid + start time -> active' ($v2.Active)
    "   a2: $($v2.Check)"
    $v3 = Test-PendingActive -Record (Rec 'survivors' @{ survivors = @($sleeper.Id) }) -Path 'x'
    Check 'a3 bare-pid survivor (old shape) on a plain sleeper -> not active (codex rule)' (-not $v3.Active)
    "   a3: $($v3.Check)"
    $v3b = Test-PendingActive -Record (Rec 'survivors' @{ survivors = @([pscustomobject]@{ pid = $sleeper.Id; start_time = $realStart; name = 'cmd' }) }) -Path 'x'
    Check 'a4 correct start time but a different recorded name -> not active (pid reused)' (-not $v3b.Active)
    "   a4: $($v3b.Check)"

    # ---- (b) launching + ppid rule ----------------------------------------------
    # an intermediate powershell spawns a grandchild sleeper and exits: the grandchild
    # keeps ParentProcessId = the dead intermediate pid (like an orphaned codex child)
    $mid = Start-Process powershell -ArgumentList '-NoProfile', '-Command', "Start-Process powershell -ArgumentList '-NoProfile','-Command','Start-Sleep 120' -WindowStyle Hidden" -PassThru -WindowStyle Hidden
    [void]$mid.WaitForExit(20000)
    $midPid = $mid.Id
    Start-Sleep -Seconds 1
    $grand = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$midPid") | Select-Object -First 1
    Check 'b0 a grandchild exists whose ppid is the dead intermediate pid' ($null -ne $grand)
    if ($grand) { $cleanup.Add([int]$grand.ProcessId) }

    $v4 = Test-PendingActive -Record (Rec 'launching' @{ pid = $midPid }) -Path 'x'
    Check 'b1 launching with pid = dead bridge pid and a live child of it -> active by the ppid rule' ($v4.Active -and $v4.Message -match 'ppid')
    "   b1: $($v4.Check)"
    $v5 = Test-PendingActive -Record (Rec 'launching' @{ pid = 999999 }) -Path 'x'
    Check 'b2 launching with an unrelated dead pid -> not active' (-not $v5.Active)
    "   b2: $($v5.Check)"

    $lp = Start-Process powershell -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 120 # C:\fake\codex.cmd' -PassThru -WindowStyle Hidden
    $cleanup.Add($lp.Id)
    Start-Sleep -Seconds 1
    $v6 = Test-PendingActive -Record (Rec 'launching' @{ pid = $midPid; launcher = 'C:\fake\codex.cmd' }) -Path 'x'
    Check 'b3 a process carrying the launcher path but a different ppid is NOT attributed (Windows)' ($v6.Message -notmatch ("pid " + $lp.Id + " "))
    "   b3: $($v6.Message)"
    $v7 = Test-PendingActive -Record (Rec 'launching' @{ pid = 0; launcher = 'C:\fake\codex.cmd' }) -Path 'x'
    Check 'b4 without a bridge pid the command-line rule applies and says task not verifiable' ($v7.Active -and $v7.Message -match 'task not verifiable')
    "   b4: $($v7.Check)"

    # ---- (c) F04-10 round 4: a dead launcher is not a dead tree --------------------
    # running record whose child_pid is the DEAD intermediate (like a dead shim) while its
    # grandchild (the real codex) lives -> active by the descendant rule
    $v8 = Test-PendingActive -Record (Rec 'running' @{ pid = 999998; child_pid = $midPid; child_start_time = $wrongStart }) -Path 'x'
    Check 'c1 running record naming a dead launcher whose child lives -> active (descendant of the dead launcher)' ($v8.Active -and $v8.Message -match "ppid $midPid")
    "   c1: $($v8.Check)"
    # running record with a dead child pid, no descendants and no codex-looking process
    # (the launcher-path sleeper is stopped first) -> inactive
    try { Stop-Process -Id $lp.Id -Force -ErrorAction SilentlyContinue } catch { }
    Start-Sleep -Seconds 1
    $v9 = Test-PendingActive -Record (Rec 'running' @{ pid = 999998; child_pid = 999997; child_start_time = $wrongStart }) -Path 'x'
    Check 'c2 running record with a dead child, no descendants, nothing codex-like -> not active' (-not $v9.Active)
    "   c2: $($v9.Check)"
    # launching record older than 30 minutes with a live launcher-path process started
    # after it -> still active (no age cut-off), labelled task not verifiable
    $lp2 = Start-Process powershell -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 120 # C:\fake\codex.cmd' -PassThru -WindowStyle Hidden
    $cleanup.Add($lp2.Id)
    Start-Sleep -Seconds 1
    $old = Rec 'launching' @{ pid = 999996; launcher = 'C:\fake\codex.cmd' }
    $old.started = (Get-Date).AddMinutes(-32).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $v10 = Test-PendingActive -Record $old -Path 'x'
    Check 'c3 launching record 32 min old + live launcher-path process -> active, task not verifiable (no age cut-off)' ($v10.Active -and $v10.Message -match 'task not verifiable')
    "   c3: $($v10.Check)"
} finally {
    foreach ($id in $cleanup) { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch { } }
}
"harness-3b: $($script:fails) failure(s)."
if ($script:fails -gt 0) { exit 1 }
exit 0
