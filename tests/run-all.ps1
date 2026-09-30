# Runs every harness of this directory (wave 28d: twenty, harness-fixes28d the last) ONE AT A TIME (they must never run concurrently:
# the recovery checks look for codex-like processes and would see each other's fake
# codex), each in a child process of the PowerShell that runs this script. Prints one
# summary line per harness and the FAIL lines of a failed one; the full output of each
# harness goes to a log under $env:TEMP\codex-consult-tests\run-all-<timestamp>\.
# Exit code: 0 when every harness passed, 1 otherwise.
# (wave 25, ROADMAP T4) -ScriptsDir <dir> (else the environment variable CODEX_CONSULT_SCRIPTS_DIR,
# else this checkout's plugins/codex-consult/scripts) names the scripts under test - e.g. an
# installed copy of the plugin; it is passed to every harness, and the summary line names it.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
#   pwsh -NoProfile -File tests/run-all.ps1 -Only harness-roster,harness-0.3
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1 -ScriptsDir <plugin>/scripts
param([string[]]$Only = @(), [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'plugins\codex-consult\scripts' }
if (-not (Test-Path -LiteralPath (Join-Path $scripts 'codex-consult.ps1') -PathType Leaf)) { Write-Host "run-all: no codex-consult.ps1 in '$scripts' (-ScriptsDir / CODEX_CONSULT_SCRIPTS_DIR)" -ForegroundColor Red; exit 1 }
$harnesses = @('harness-0.3', 'harness-roster', 'harness-format', 'harness-engines', 'harness-muse', 'harness-panel', 'harness-pending', 'harness-fixes', 'harness-lock2', 'harness-3b', 'harness-visibility', 'harness-detach', 'harness-companions', 'harness-fixes26b', 'harness-host', 'harness-telemetry', 'harness-fixes27c', 'harness-fixes28b', 'harness-fixes28c', 'harness-fixes28d')
# (wave 27) the coordinator's own settings never reach a harness: a CODEX_CONSULT_COORDINATOR of the
# operator would add warnings, a CODEX_CONSULT_BRIEF_PREFIX could refuse every run
foreach ($k in @('CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX')) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
# (wave 28, R17) telemetry off and the intake pointed at nothing reachable for every child: no harness
# spools an event into a real codex home or contacts the real intake (harness-telemetry sets its own
# switch and its local intake)
$env:CODEX_CONSULT_TELEMETRY = 'off'
$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
# (wave 27c, D14) the test hooks (CODEX_CONSULT_TEST_*, CODEX_CONSULT_NOW) are honoured only in test mode
$env:CODEX_CONSULT_TEST_MODE = '1'
$only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($o in $only) { if ($harnesses -notcontains $o) { Write-Host "run-all: unknown harness '$o' (known: $($harnesses -join ', '))" -ForegroundColor Red; exit 1 } }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$logDir = Join-Path (Join-Path $tmpBase 'codex-consult-tests') ('run-all-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($logDir)
Write-Host "run-all: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion) ($psExe); scripts $scripts; logs in $logDir"
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
    $out = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $file -ScriptsDir $scripts 2>&1 | ForEach-Object { "$_" })
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
Write-Host ("run-all: {0} harness(es), {1} failed; scripts: {2}" -f $ran, $failed, $scripts)
if ($failed -gt 0) { exit 1 }
exit 0
