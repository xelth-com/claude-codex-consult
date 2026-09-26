# Runs every harness of this directory ONE AT A TIME (they must never run concurrently:
# the recovery checks look for codex-like processes and would see each other's fake
# codex), each in a child process of the PowerShell that runs this script. Prints one
# summary line per harness and the FAIL lines of a failed one; the full output of each
# harness goes to a log under $env:TEMP\codex-consult-tests\run-all-<timestamp>\.
# Exit code: 0 when every harness passed, 1 otherwise.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
#   pwsh -NoProfile -File tests/run-all.ps1 -Only harness-roster,harness-0.3
param([string[]]$Only = @())
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$harnesses = @('harness-0.3', 'harness-roster', 'harness-format', 'harness-engines', 'harness-muse', 'harness-panel', 'harness-pending', 'harness-fixes', 'harness-lock2', 'harness-3b', 'harness-visibility')
$only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($o in $only) { if ($harnesses -notcontains $o) { Write-Host "run-all: unknown harness '$o' (known: $($harnesses -join ', '))" -ForegroundColor Red; exit 1 } }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$logDir = Join-Path (Join-Path $tmpBase 'codex-consult-tests') ('run-all-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($logDir)
Write-Host "run-all: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion) ($psExe); logs in $logDir"
$failed = 0
$ran = 0
foreach ($h in $harnesses) {
    if ($only.Count -gt 0 -and $only -notcontains $h) { continue }
    $ran++
    $file = Join-Path $PSScriptRoot "$h.ps1"
    $log = Join-Path $logDir "$h.log"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $file 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous
    $sw.Stop()
    [IO.File]::WriteAllText($log, (($out -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    $pass = @($out | Where-Object { $_ -match '^PASS' }).Count
    $fail = @($out | Where-Object { $_ -match '^FAIL' }).Count
    $summary = @($out | Where-Object { $_ -match ('^' + [regex]::Escape($h) + '\b.*failure') }) | Select-Object -Last 1
    # A harness counts as passed only when it finished (its summary line is there),
    # exited 0, printed no FAIL line and at least one PASS line.
    $ok = ($code -eq 0 -and $fail -eq 0 -and $pass -gt 0 -and $summary)
    if (-not $ok) { $failed++ }
    $mark = if ($ok) { 'ok  ' } else { 'FAIL' }
    Write-Host ('{0} {1,-16} PASS={2,-4} FAIL={3,-3} exit={4} {5,5:N0} s :: {6}' -f $mark, $h, $pass, $fail, $code, $sw.Elapsed.TotalSeconds, $(if ($summary) { $summary } else { '(no summary line - the harness did not finish)' }))
    if (-not $ok) {
        $out | Where-Object { $_ -match '^FAIL' } | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        Write-Host "     log: $log"
    }
}
Write-Host ("run-all: {0} harness(es), {1} failed." -f $ran, $failed)
if ($failed -gt 0) { exit 1 }
exit 0
