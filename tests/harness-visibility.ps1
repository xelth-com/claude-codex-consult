# codex-consult wave 24 (0.5.0, "operator visibility"): a timeout never throws the reviewer's work
# away (T1) and one truth about availability (T2, T3; decisions D14-D17 of the companions design
# review). T1: the per-purpose default timeouts and timeout_source, -ContinueSec and ONE
# continuation turn on the killed turn's thread (codex `exec ... resume`, agy --conversation, muse
# --session-id; a usable reply = "usable reply (after a timeout continuation)"), the salvaged
# handoffs/NN-<engine>-<slug>.partial.md (the main turn, the continuation, a denial retry, a format
# repair) with the exact resume command, -Range (git diff --shortstat, the prompt, the ledger, the
# size warning, an unknown range refused), the panel member guard. T2/T3: Get-EndpointHealth's
# 60-minute rule for a quota failure without a reset time and the still-blocking older failure,
# Get-PreflightVerdict's order and fields, Get-EndpointGroups over all roster entries,
# Get-RosterAvailability and the one-line view (codex-providers.ps1 -Short, -Short -Json, the
# SessionStart hook), the listing's health source, and ONE ledger making the listing, -Short, the
# hook and the roster walk agree. F15-1: the muse launch guard re-reads auth.json. Wave 24b (the
# acceptance panel's F07-1..3, F08-1..8, F13-1/2 and two ledger facts): UNIT24B in-process, GATES
# end to end - the main turn's guarded start, the continuation's gates (one tree check, one
# classifier), its failure as provider_failure, a first reply's checks before it counts, the
# prompt-only schema, the complete resume command, -Range of two revisions, roster_positions.
# Wave 24c (the re-acceptance panel's F15-1..6, the F08-4 residual, the F08-2 ruling and two ledger
# facts): UNIT24C in-process, GATES24C and BURST end to end - quota wording beats the context
# exception, the ordinal listing cache, only diagnostic stderr lines gate the continuation, the hint
# stored at classification, -ReplyName/-SkipPreflight in the resume command, the record restored
# after a Start-Process error, a rejected continuation reply kept, the tree check by CONTENT (a
# commit meanwhile is revision_moved, not a change), the 10-minute burst 429.
# FAKES ONLY: fake-codex3.cmd, fake-agy.cmd, fake-muse.cmd (CODEX_CONSULT_*_EXE); CODEX_HOME, the
# roster, USERPROFILE/HOME (a fake muse auth.json) and LOCALAPPDATA point at SCRATCH directories;
# PATH holds no muse launcher (the harness refuses to run otherwise). Runs under the host it is
# started with (powershell 5.1 or pwsh 7, Windows). Work files:
# $env:TEMP\codex-consult-tests\harness-visibility\<guid>, removed at the end.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
# (wave 26b, D13) the machine-wide health file stays out of these cases (every case its own
# repository; harness-fixes26b.ps1 points CODEX_CONSULT_HEALTH at scratch files of its own)
$env:CODEX_CONSULT_HEALTH = 'none'
# (wave 28) telemetry off and the intake pointed at nothing reachable: no harness but
# harness-telemetry spools an event or contacts an intake
$env:CODEX_CONSULT_TELEMETRY = 'off'
$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
# (wave 27c, D14) the test hooks (CODEX_CONSULT_TEST_*, CODEX_CONSULT_NOW) are honoured only in test mode
$env:CODEX_CONSULT_TEST_MODE = '1'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# (wave 25, T4) the scripts under test: -ScriptsDir, else CODEX_CONSULT_SCRIPTS_DIR, else this checkout's
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$providersPs = Join-Path $scripts 'codex-providers.ps1'
$hookPs = Join-Path $scripts 'codex-consult-hook.ps1'
$scoreboardPs = Join-Path $scripts 'codex-scoreboard.ps1'
$fakeCodex = Join-Path $sp 'fake-codex3.cmd'
$fakeAgy = Join-Path $sp 'fake-agy.cmd'
$fakeMuse = Join-Path $sp 'fake-muse.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-visibility') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$realConfig = Join-Path (Join-Path $HOME '.codex') 'config.toml'
$realConfigHash = ''
if (Test-Path -LiteralPath $realConfig -PathType Leaf) { $realConfigHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash }
# The process environment the cases change and the end restores (values are never printed).
$savedEnv = @{}
foreach ($k in @('CODEX_HOME', 'Path', 'USERPROFILE', 'HOME', 'LOCALAPPDATA', 'TEMP', 'TMP', 'TBH_CREDENTIAL_BACKEND', 'META_API_KEY', 'MODEL_API_KEY', 'RT_ZAI_KEY', 'RT_MIMO_KEY')) { $savedEnv[$k] = [Environment]::GetEnvironmentVariable($k) }
$script:fails = 0
$script:passes = 0

function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 300) { $ev = $ev.Substring(0, 300) + '...' }
    Write-Host ("{0} {1,-9} {2}{3}" -f $mark, $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
}
function Want { param([string]$Name) return (-not $Only -or ($Only -split ',') -contains $Name) }
function G { param([string]$Repo, [string[]]$A) $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = & git -C $Repo @A 2>&1; $ErrorActionPreference = $p; return $o }
function New-Repo {
    param([string]$Name)
    $r = Join-Path $work $Name
    if (Test-Path $r) { Remove-Item $r -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($r)
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T'); $null = G $r @('config', 'core.autocrlf', 'false')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
# The scratch Codex config: the built-in openai (top-level model gpt-5.1) plus ZAI (env
# RT_ZAI_KEY), zai2 (the SAME endpoint as ZAI, env RT_ZAI_KEY) and mimo (env RT_MIMO_KEY).
$codexHome = Join-Path $work 'codexhome'
[void][IO.Directory]::CreateDirectory($codexHome)
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.zai2]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.mimo]`nbase_url = `"https://token-plan-ams.xiaomimimo.com/v1`"`nenv_key = `"RT_MIMO_KEY`"`nwire_api = `"responses`"`n"
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
$cfg = Read-CodexConfigSubset -Path (Join-Path $codexHome 'config.toml')
# The scratch home of every child (USERPROFILE and HOME): ~/.config/muse/auth.json is a FAKE.
$museHome = Join-Path $work 'home'
$authPath = Join-Path $museHome '.config\muse\auth.json'
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $authPath))
# (a long-lived Windows PowerShell 5.1 under this USERPROFILE needs its AppData\Local: harness-muse)
[void][IO.Directory]::CreateDirectory((Join-Path $museHome 'AppData\Local'))
$authOauth = '{"providers":{"meta":{"access_token":"FAKE-TOKEN-NOT-A-SECRET-24","mechanism":"oauth"}}}'
$authApiKey = '{"providers":{"meta":{"access_token":"FAKE-TOKEN-NOT-A-SECRET-24","mechanism":"api_key"}}}'
function Write-Auth { param([string]$Json) [IO.File]::WriteAllText($authPath, $Json, $u8) }
Write-Auth $authOauth
$lad = Join-Path $work 'localappdata'
[void][IO.Directory]::CreateDirectory($lad)
$safePath = (@(([string]$savedEnv['Path']) -split ';' | Where-Object { $_ -and -not (Test-Path -LiteralPath (Join-Path $_ 'muse.cmd')) -and -not (Test-Path -LiteralPath (Join-Path $_ 'muse.exe')) -and -not (Test-Path -LiteralPath (Join-Path $_ 'muse')) })) -join ';'
# a directory with a `codex` shim of the fake (the hook looks for codex on PATH)
$bin = Join-Path $work 'bin'
[void][IO.Directory]::CreateDirectory($bin)
[IO.File]::WriteAllText((Join-Path $bin 'codex.cmd'), "@echo off`r`nset ""FAKE_CODEX_ARGS=%*""`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""$(Join-Path $sp 'fake-codex3.ps1')""`r`nexit /b %ERRORLEVEL%`r`n")
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_RESUME_REPLY', 'FAKE_CODEX_RESUME_LOG', 'FAKE_CODEX_LOG', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_HANG_NEW', 'FAKE_CODEX_ITEMS', 'FAKE_CODEX_PRELINE', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_FAIL_ON', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_REPLY_MAP', 'FAKE_CODEX_STDERR', 'FAKE_CODEX_EXIT', 'FAKE_CODEX_WRITE', 'FAKE_CODEX_STDERR_FIRST', 'FAKE_CODEX_RESUME_FAIL', 'FAKE_CODEX_COMMIT', 'FAKE_AGY_STDERR', 'FAKE_AGY_HANG_AFTER', 'FAKE_AGY_STATUS', 'FAKE_AGY_ERROR', 'FAKE_AGY_EXIT', 'FAKE_AGY_REPLY', 'FAKE_AGY_RESUME_REPLY', 'FAKE_AGY_NOSTRUCTURED', 'FAKE_AGY_HANG', 'FAKE_AGY_HANG_ON', 'FAKE_AGY_TEXT', 'FAKE_AGY_DENIED', 'FAKE_AGY_LOG', 'FAKE_AGY_RESUME_LOG', 'FAKE_AGY_MODELS', 'FAKE_AGY_MODELS_LOG', 'FAKE_MUSE_REPLY', 'FAKE_MUSE_RESUME_REPLY', 'FAKE_MUSE_HANG', 'FAKE_MUSE_TEXT', 'FAKE_MUSE_LOG', 'FAKE_MUSE_RESUME_LOG', 'FAKE_MUSE_COUNT', 'FAKE_MUSE_WRITE', 'FAKE_MUSE_COMMIT', 'FAKE_MUSE_STDERR')
$testVars = @('CODEX_CONSULT_EXE', 'CODEX_CONSULT_TEST_LAUNCH_PAUSE_MS', 'CODEX_CONSULT_AGY_EXE', 'CODEX_CONSULT_MUSE_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_SURVIVORS', 'CODEX_CONSULT_TEST_LOGIN_TIMEOUT', 'META_API_KEY', 'MODEL_API_KEY', 'TBH_CREDENTIAL_BACKEND', 'RT_ZAI_KEY', 'RT_MIMO_KEY')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
}
# Every case: the fakes are the launchers, the scratch homes, PATH without a muse launcher, the
# ZAI key set (mimo's not). '' in $Env removes a variable. $Roster '' = CODEX_CONSULT_ROSTER=none.
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:CODEX_CONSULT_EXE = $fakeCodex
    $env:CODEX_CONSULT_AGY_EXE = $fakeAgy
    $env:CODEX_CONSULT_MUSE_EXE = $fakeMuse
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    $env:USERPROFILE = $museHome
    $env:HOME = $museHome
    $env:LOCALAPPDATA = $lad
    $env:TEMP = $savedEnv['TEMP']
    $env:TMP = $savedEnv['TMP']
    $env:TBH_CREDENTIAL_BACKEND = 'file'
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:Path = $safePath
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env {
    Clear-TestEnv
    foreach ($k in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($k, $savedEnv[$k]) }
}
function ConvertFrom-RunOutput {
    param($Out, [int]$Code)
    $text = (($Out | ForEach-Object { "$_" }) -join "`n")
    $preview = $null
    $mark = 'sessions.json entry preview:'
    $at = $text.IndexOf($mark)
    if ($at -ge 0) { try { $preview = $text.Substring($at + $mark.Length) | ConvertFrom-Json } catch { $preview = $null } }
    return [pscustomobject]@{ Code = $Code; Out = $text; Preview = $preview; First = (($text -split "`n") | Select-Object -First 1) }
}
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task t @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return (ConvertFrom-RunOutput $out $code)
}
function Providers {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList = @(), [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $providersPs @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    $json = $null
    if ($ArgList -contains '-Json') { try { $parsed = $text | ConvertFrom-Json; $json = @($parsed | ForEach-Object { $_ }) } catch { $json = $null } }
    return [pscustomobject]@{ Code = $code; Out = $text; Json = $json }
}
function Hook {
    param([string]$Repo, [string]$Roster, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    $env:Path = "$bin;$safePath"
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    # (wave 27) the availability line alone: the hook's second line (the pointer to the
    # coordinator's rules) is harness-host's
    $out = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $hookPs 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch '^codex-consult: coordinator rules - ' }) -join "`n"
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return $out
}
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (Ledger $Repo)[-1] }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Td { param([string]$Repo, [string]$Rel) return (Join-Path (Join-Path $Repo '.collab\t') ($Rel -replace '/', '\')) }
function Text { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Uuid { return [guid]::NewGuid().ToString() }
function Iso { param($When) return ([DateTimeOffset]$When).ToString('yyyy-MM-ddTHH:mm:sszzz', $inv) }
function Seed-Ledger {
    param([string]$Repo, [string]$TaskName, [object[]]$Entries)
    $dir = Join-Path $Repo ".collab\$TaskName"
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = $TaskName; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } })
}
$uuidRe = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$builtinFp = Get-Sha256Hex ($u8.GetBytes('cc-provider-v1|builtin:openai'))
$zaiFp = Get-Sha256Hex ($u8.GetBytes('cc-provider-v1|base_url=https://api.z.ai/api/v1|wire_api=responses'))
$agyFp = Get-Sha256Hex ($u8.GetBytes('cc-engine-v1|agy'))
# a ledger entry of a reviewer (the endpoint health's input); $Failure: its provider_failure
function New-Entry {
    param([int]$N, [string]$Provider, [string]$Model, [string]$Fp, [string]$Engine = 'codex', [DateTimeOffset]$When, [string]$Outcome = 'usable reply', $Failure = $null)
    $e = [ordered]@{ n = $N; when = (Iso $When); purpose = ''; reviewer = [pscustomobject]@{ provider = $Provider; model = $Model; engine = $Engine; provider_fingerprint = $Fp }; thread = $(if ($Outcome -eq 'usable reply') { Uuid } else { '' }); thread_source = 'events'; mode = 'new'; reply = ('handoffs/{0:D2}-x.md' -f $N); bridge_outcome = $Outcome; wall_seconds = 1; finished_at = (Iso $When.AddSeconds(1)) }
    if ($null -ne $Failure) { $e['provider_failure'] = $Failure }
    return [pscustomobject]$e
}
function Quota { param([DateTimeOffset]$When, [string]$Message, $RetryAfter = $null) return [pscustomobject]@{ class = 'quota'; code = ''; message = $Message; when = (Iso $When); retry_after = $(if ($null -ne $RetryAfter) { Iso $RetryAfter } else { $null }) } }
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"c","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
$adviseF = Reply 'advise-finding.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$prose = "**Q1.** The engine table keeps the codex path unchanged for every existing reviewer and adds one row per engine.`n**Q2.** The session rules close the resume gap because a new session is never taken as the parent thread.`n`nVerdict: ADVISE`n"
$proseFile = Reply 'prose.md' $prose
$agyModel = 'gemini-3.8-flash-high'
$museModel = 'muse-spark-1.3'
$rosterCodex = Write-Roster 'codex' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'
$rosterAgy = Write-Roster 'agy' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"' + $agyModel + '"}]}')
$rosterMuse = Write-Roster 'muse' ('{"roster_version":1,"reviewers":[{"provider":"meta","engine":"muse","model":"' + $museModel + '"}]}')
# a roster read in-process (as CODEX_CONSULT_ROSTER would name it)
function Roster-Of { param([string]$Path) return (Read-ReviewerRoster -Location ([pscustomobject]@{ Path = $Path; FromEnv = $true; Disabled = $false })) }
# the local-time phrases of the one-line view, as the bridge must compute them
function Local-When { param([DateTimeOffset]$When, [DateTimeOffset]$Now) return (Format-LocalWhen -When $When -NowUtc $Now.UtcDateTime) }

# Never a real muse or agy: with the harness environment the launchers are the fakes, and no
# muse launcher resolves without the override - otherwise the harness refuses to run at all.
Set-CaseEnv '' @{ CODEX_CONSULT_MUSE_EXE = '' }
$realMuse = Resolve-EngineLauncher -Engine 'muse'
Restore-Env
if ($realMuse) {
    Write-Host "FAIL SAFETY   a real muse launcher resolves in the test environment ($realMuse); the harness refuses to run."
    Remove-TestWork $work
    Write-Host ("harness-visibility ({0} {1}): 0 passed, 1 failure(s)." -f $hostTag, $PSVersionTable.PSVersion)
    exit 1
}

try {
# =============================================================== UNIT: the new functions in-process
if (Want 'UNIT') {
    Check 'UNIT' 'Test-UsableOutcome: "usable reply" and "usable reply (after a timeout continuation)" are usable; a failure and a look-alike are not' ((Test-UsableOutcome 'usable reply') -and (Test-UsableOutcome 'usable reply (after a timeout continuation)') -and -not (Test-UsableOutcome 'failed: timeout after 5 s (process tree killed)') -and -not (Test-UsableOutcome 'usable replyx') -and -not (Test-UsableOutcome '')) ''
    $hints = @((Format-RelativeHint (New-TimeSpan -Days 2 -Hours 10 -Minutes 20)), (Format-RelativeHint (New-TimeSpan -Hours 3 -Minutes 20)), (Format-RelativeHint (New-TimeSpan -Minutes 52)), (Format-RelativeHint (New-TimeSpan -Seconds 20)), (Format-RelativeHint (New-TimeSpan -Minutes -5)), (Format-RelativeHint (New-TimeSpan -Days 1)), (Format-RelativeHint (New-TimeSpan -Hours 2)), (Format-RelativeHint (New-TimeSpan -Days 2 -Hours 10 -Minutes 40)))
    Check 'UNIT' 'D17 Format-RelativeHint (rounded): 2d 10h 20m -> "in 2d 10h"; 3h 20m; 52m; 20 s -> "in <1m"; the past -> "now"; 1 day -> "in 1d"; 2 h -> "in 2h"; 2d 10h 40m rounds to "in 2d 11h"' (($hints -join '|') -eq 'in 2d 10h|in 3h 20m|in 52m|in <1m|now|in 1d|in 2h|in 2d 11h') ($hints -join '|')
    $noonLocal = [DateTimeOffset]((Get-Date).Date.AddHours(12))
    $w1 = Format-LocalWhen -When $noonLocal.AddMinutes(30).ToUniversalTime() -NowUtc $noonLocal.UtcDateTime
    $w2 = Format-LocalWhen -When $noonLocal.AddDays(2) -NowUtc $noonLocal.UtcDateTime
    $w3 = Format-LocalWhen -When $noonLocal.AddDays(10) -NowUtc $noonLocal.UtcDateTime
    Check 'UNIT' 'D17 Format-LocalWhen: LOCAL time (ToLocalTime, also for a UTC value) - "HH:mm" on the day, "ddd HH:mm" within six days, "yyyy-MM-dd HH:mm" beyond' ($w1 -eq $noonLocal.AddMinutes(30).ToString('HH:mm', $inv) -and $w2 -eq $noonLocal.AddDays(2).ToString('ddd HH:mm', $inv) -and $w3 -eq $noonLocal.AddDays(10).ToString('yyyy-MM-dd HH:mm', $inv)) "$w1 | $w2 | $w3"
    $fc1 = Get-FirstClause 'META_API_KEY is set: a muse run would bill per token instead of the Muse Code subscription; unset it'
    $fc2 = Get-FirstClause 'the Muse sign-in is not established as oauth (TBH_CREDENTIAL_BACKEND is not set: the keychain backend cannot be read): a muse run might bill per token'
    Check 'UNIT' 'Get-FirstClause: a launch refusal''s first clause, up to the first ": " outside parentheses (a complete phrase, never a cut)' ($fc1 -eq 'META_API_KEY is set' -and $fc2 -eq 'the Muse sign-in is not established as oauth (TBH_CREDENTIAL_BACKEND is not set: the keychain backend cannot be read)' -and (Get-FirstClause 'no colon') -eq 'no colon') "$fc1 | $fc2"

    # --- T3: a quota failure without a reset time is out for 60 minutes after it was hit (a 429 that
    # names a usage limit; wave 24c: a bare burst 429 is out for 10 minutes - UNIT24C, BURST)
    $now = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    $hit = $now.AddMinutes(-9)
    $q = New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-15) 'failed: codex exit 1 - 429 Too Many Requests: usage limit exceeded' (Quota $hit '429 Too Many Requests: usage limit exceeded')
    $h = Get-EndpointHealth -Consults @($q) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    Check 'UNIT' 'T3 Get-EndpointHealth: a quota failure without a reset time, hit 9 min ago -> Quota (not QuotaKnown), Hit = provider_failure.when (not the entry''s start), Until = Hit + 60 min' ($h.Quota -and -not $h.QuotaKnown -and $h.Quota.HitIso -eq (Iso $hit) -and (Iso $h.Quota.Until) -eq (Iso $hit.AddMinutes(60))) "hit $($h.Quota.HitIso) until $(Iso $h.Quota.Until)"
    $h59 = Get-EndpointHealth -Consults @($q) -Fingerprint $zaiFp -UtcNow $hit.AddMinutes(59).UtcDateTime
    $h61 = Get-EndpointHealth -Consults @($q) -Fingerprint $zaiFp -UtcNow $hit.AddMinutes(61).UtcDateTime
    $okE = New-Entry 2 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-5)
    $hOk = Get-EndpointHealth -Consults @($q, $okE) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    $contE = New-Entry 3 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-5) 'usable reply (after a timeout continuation)'
    $hCont = Get-EndpointHealth -Consults @($q, $contE) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    Check 'UNIT' '... still out 59 min after the hit, no longer 61 min after (LastFailure keeps showing it); a later usable reply clears it - a reply after a timeout continuation too (and counts as RecentUsable)' ($h59.Quota -and -not $h61.Quota -and $h61.LastFailure.Class -eq 'quota' -and -not $hOk.Quota -and -not $hCont.Quota -and $hCont.RecentUsable) ''
    $old = New-Entry 1 'openai' 'gpt-6-astra' $builtinFp 'codex' $now.AddDays(-2) "failed: codex exit 1 - You've hit your usage limit." (Quota $now.AddDays(-2) "You've hit your usage limit." $now.AddDays(2))
    $ho = Get-EndpointHealth -Consults @($old) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    Check 'UNIT' 'T2 Get-EndpointHealth: a weekly limit hit 2 days ago with its reset 2 days ahead -> Quota (known) AND LastFailure/LastLimit name it (the 24-hour window used to hide it: LAST FAILURE "-" for an endpoint that was out)' ($ho.QuotaKnown -and $ho.LastFailure -and $ho.LastFailure.Class -eq 'quota' -and $ho.LastLimit.RetryAfterIso -eq (Iso $now.AddDays(2))) "$($ho.LastFailure.When)"
    $env:RT_ZAI_KEY = 'zai-test-key'
    $idZ = Resolve-ReviewerIdentity -Config $cfg -Provider 'ZAI' -Model 'glm-5.3'
    $vW = Get-PreflightVerdict -Identity $idZ -Config $cfg -Launcher $fakeCodex -Health $h -RosterWalk
    $vS = Get-PreflightVerdict -Identity $idZ -Config $cfg -Launcher $fakeCodex -Health $h
    Check 'UNIT' 'D14 Get-PreflightVerdict -RosterWalk: unavailable, Kind quota-unknown-reset, Reason "usage limit hit <iso>, reset unknown; retry after <iso + 60 min>", Hit and Until' ($vW.State -eq 'unavailable' -and $vW.Kind -eq 'quota-unknown-reset' -and $vW.Reason -eq "usage limit hit $(Iso $hit), reset unknown; retry after $(Iso $hit.AddMinutes(60))" -and (Iso $vW.Until) -eq (Iso $hit.AddMinutes(60))) $vW.Reason
    $qwS = Format-QuotaWarning -Identity $idZ -Health $h -SkipPreflight
    Check 'UNIT' 'F08-7 the 60-minute rule is unconditional: without -RosterWalk (an explicit -Provider run) the SAME verdict - unavailable, Kind quota-unknown-reset, the same Reason, Hit and Until; only the refusal differs ("... out for 60 minutes, until <iso>; nothing was started (pass -SkipPreflight to launch anyway)"); Format-QuotaWarning is empty without -SkipPreflight and names the reset-unknown window with it' ($vS.State -eq 'unavailable' -and $vS.Kind -eq 'quota-unknown-reset' -and $vS.Reason -eq $vW.Reason -and (Iso $vS.Until) -eq (Iso $vW.Until) -and (Iso $vS.Hit) -eq (Iso $vW.Hit) -and $vS.Refusal.EndsWith('; nothing was started (pass -SkipPreflight to launch anyway)') -and -not $vW.Refusal.Contains('-SkipPreflight') -and (Format-QuotaWarning -Identity $idZ -Health $h) -eq '' -and $qwS -eq "provider ZAI hit a usage limit 15 min ago (reset unknown; out until $(Iso $hit.AddMinutes(60))): 429 Too Many Requests: usage limit exceeded") "$($vS.State) | $qwS"
    $idA = Resolve-ReviewerIdentity -Config $cfg -Provider 'gemini' -Model $agyModel -Engine 'agy' -Launcher $fakeAgy
    $qa = New-Entry 1 'gemini' $agyModel $agyFp 'agy' $now.AddMinutes(-30) 'failed: agy exit 3 - Individual quota reached.' (Quota $now.AddMinutes(-30) 'Individual quota reached.' $now.AddDays(2))
    $ha = Get-EndpointHealth -Consults @($qa) -Fingerprint $agyFp -UtcNow $now.UtcDateTime
    $vA = Get-PreflightVerdict -Identity $idA -Config $cfg -Launcher $fakeAgy -Health $ha -RosterWalk -NoNetwork
    $vA0 = Get-PreflightVerdict -Identity $idA -Config $cfg -Launcher $fakeAgy -Health $null -RosterWalk -NoNetwork
    Check 'UNIT' 'D14: a recorded usage limit outranks a sign-in that -NoNetwork did not check (agy): unavailable "usage limit until <iso>" (Kind quota, Until); without a recorded failure: unknown (Kind unknown, "sign-in not checked")' ($vA.State -eq 'unavailable' -and $vA.Kind -eq 'quota' -and (Iso $vA.Until) -eq (Iso $now.AddDays(2)) -and $vA0.State -eq 'unknown' -and $vA0.Kind -eq 'unknown' -and $vA0.Credential.Reason -eq 'sign-in not checked') "$($vA.Reason) | $($vA0.Reason)"
    $mk = { param($Pos, $Prov, $Mod, $Eng) [pscustomobject]@{ Entry = [pscustomobject]@{ Position = $Pos; Provider = $Prov; Model = $Mod; Engine = $Eng }; Identity = (Resolve-ReviewerIdentity -Config $cfg -Provider $Prov -Model $Mod -Engine $Eng -Launcher $(if ($Eng -eq 'agy') { $fakeAgy } else { '' })) } }
    $ms = @((& $mk 1 'openai' 'gpt-5.1' 'codex'), (& $mk 2 'ZAI' 'glm-5.3' 'codex'), (& $mk 3 'gemini' $agyModel 'agy'), (& $mk 4 'zai2' 'glm-5.3' 'codex'), (& $mk 5 'gemini' 'gemini-3.1-pro-high' 'agy'))
    $eg = Get-EndpointGroups -Members $ms
    Check 'UNIT' 'D16 Get-EndpointGroups over ALL entries: ZAI and zai2 (one base URL) form one group, the two gemini entries another, openai its own; labels in first-seen order' ($eg.Groups.Count -eq 3 -and $eg.GroupOf[2] -eq $eg.GroupOf[4] -and $eg.GroupOf[3] -eq $eg.GroupOf[5] -and $eg.GroupOf[1] -ne $eg.GroupOf[2] -and (@($eg.Groups[$eg.GroupOf[2]].Labels) -join '+') -eq 'ZAI+zai2' -and ($eg.Labels -join ',') -eq 'openai,ZAI,gemini,zai2') (($eg.Groups | ForEach-Object { @($_.Labels) -join '+' }) -join ' | ')
    $plan = Get-PanelPlan -Runners $ms -Cap 0
    Check 'UNIT' 'Get-PanelPlan (now built on Get-EndpointGroups) keeps its plan: 3 endpoint groups, at most 3 of the 5 at a time, every label''s limit 1' ($plan.Groups.Count -eq 3 -and $plan.Effective -eq 3 -and $plan.Text -eq 'at most 3 at a time' -and $plan.Limits['ZAI'] -eq 1 -and $plan.Limits['zai2'] -eq 1 -and $plan.GroupOf[4] -eq $plan.GroupOf[2]) $plan.Text
    Check 'UNIT' 'the panel member guard grows by -ContinueSec: 900 + 60 + 120 + repair 300 + denial 300 + continuation 900 = 2580; -ContinueSec 0 -> 1680; timeout 5 with continuation 5 and a repair -> 195' ((Get-PanelMemberGuard -TimeoutSec 900 -ContinueSec 900 -Repair -DenialRetry) -eq 2580 -and (Get-PanelMemberGuard -TimeoutSec 900 -ContinueSec 0 -Repair -DenialRetry) -eq 1680 -and (Get-PanelMemberGuard -TimeoutSec 5 -ContinueSec 5 -Repair) -eq 195) ''

    # --- T1: the salvage readers of the three streams, the partial body
    $cx = Reply 'salv-codex.jsonl' ((@(('{"type":"thread.started","thread_id":"' + (Uuid) + '"}'), '{"type":"turn.started"}', '{"type":"item.completed","item":{"id":"item_0","type":"reasoning","text":"Plan: read the diff."}}', '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"git diff --stat","status":"in_progress"}}', '{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"git diff --stat","exit_code":0,"status":"completed"}}', '{"type":"item.started","item":{"id":"item_2","type":"web_search","query":"","action":{"type":"other"}}}', '{"type":"item.completed","item":{"id":"item_2","type":"web_search","query":"codex exec resume","action":{"type":"search","query":"codex exec resume"}}}', '{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":"Q1: fine so far."}}', '{"type":"item.started","item":{"id":"item_4","type":"command_execution","command":"rg -n foo","status":"in_progress"}}', '{"type":"item.completed","item":{"id":"item_5","type":"error","message":"metadata"}}', '{"type":"item.comp')) -join "`n")
    $s = Read-CodexSalvage -Path $cx
    Check 'UNIT' 'T1 Read-CodexSalvage: reasoning and agent message in stream order; tools: the shell command lines (one still running at the kill too), web_search with its query; no error item; a partial last line skipped' ((@($s.Items | ForEach-Object { "$($_.Kind):$($_.Text)" }) -join '|') -eq 'reasoning:Plan: read the diff.|message:Q1: fine so far.' -and ($s.Tools -join '|') -eq 'shell: git diff --stat|web_search: codex exec resume|shell: rg -n foo') "$((@($s.Items | ForEach-Object { $_.Text }) -join '|')) / $($s.Tools -join '|')"
    $ag = Reply 'salv-agy.jsonl' ((@('{"event":"init","conversation_id":"c1"}', '{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"agent_response","text_delta":"Looking "}}', '{"event":"step_update","step_update":{"step_index":1,"state":"ACTIVE","step_type":"agent_response","text_delta":"at it."}}', '{"event":"step_update","step_update":{"step_index":2,"state":"ACTIVE","step_type":"tool","tool_name":"view_file","tool_info":{"name":"view_file","parameters":{"AbsolutePath":"app.txt"}}}}', '{"event":"step_update","step_update":{"step_index":2,"state":"DONE","step_type":"tool","tool_name":"view_file"}}', '{"event":"step_update","step_update":{"step_index":3,"state":"ACTIVE","step_type":"tool","tool_name":"run_command","tool_info":{"name":"run_command","parameters":{"CommandLine":"git status"}}}}', '{"event":"step_update","step_update":{"step_index":4,"state":"ACTIVE","step_type":"agent_response","text_delta":"Second message."}}')) -join "`n")
    $sa = Read-TurnSalvage -Engine 'agy' -Path $ag
    Check 'UNIT' 'T1 Read-AgySalvage (the agy adapter''s Salvage): the text_delta pieces of a step joined - one message per step, in order; a tool once per step; run_command with its command line' ((@($sa.Items | ForEach-Object { "$($_.Kind):$($_.Text)" }) -join '|') -eq 'message:Looking at it.|message:Second message.' -and ($sa.Tools -join '|') -eq 'view_file|run_command: git status') "$((@($sa.Items | ForEach-Object { $_.Text }) -join '|')) / $($sa.Tools -join '|')"
    $mu = Reply 'salv-muse.jsonl' ((@('{"schema_version":1,"payload_type":"run.output.delta","payload":{"kind":"run_output_delta","text":"First "}}', '{"schema_version":1,"payload_type":"run.output.delta","payload":{"kind":"run_output_delta","text":"part."}}', '{"schema_version":1,"payload_type":"task.lifecycle.proposed","payload":{"kind":"task_lifecycle","event":{"kind":"proposed","task_id":"t1","task_kind":"tool.read_file"}}}', '{"schema_version":1,"payload_type":"task.lifecycle.proposed","payload":{"kind":"task_lifecycle","event":{"kind":"proposed","task_id":"t2","task_kind":"model.meta.response"}}}', '{"schema_version":1,"payload_type":"run.output.delta","payload":{"kind":"run_output_delta","text":"After the tool."}}')) -join "`n")
    $sm = Read-TurnSalvage -Engine 'muse' -Path $mu
    Check 'UNIT' 'T1 Read-MuseSalvage (the muse adapter''s Salvage): run.output.delta texts - a tool call in between starts the next message; tools = the tool.* task kinds' ((@($sm.Items | ForEach-Object { "$($_.Kind):$($_.Text)" }) -join '|') -eq 'message:First part.|message:After the tool.' -and ($sm.Tools -join '|') -eq 'read_file') "$((@($sm.Items | ForEach-Object { $_.Text }) -join '|')) / $($sm.Tools -join '|')"
    $body = Format-PartialBody -Turns @([pscustomobject]@{ Label = 'Turn 1 - the main turn'; Note = 'killed at 5.2 s of 5 s'; Salvage = $s }, [pscustomobject]@{ Label = 'Turn 2 - the timeout continuation'; Note = 'failed: x'; Salvage = (Read-TurnSalvage -Engine 'codex' -Path '') })
    Check 'UNIT' 'T1 Format-PartialBody: a heading per turn with its note, "**Reasoning 1:**" and "**Agent message 1:**" with the text, the tool calls as a list; a turn without text says so' ($body -match '(?m)^## Turn 1 - the main turn - killed at 5\.2 s of 5 s$' -and $body.Contains("**Reasoning 1:**`n`nPlan: read the diff.") -and $body.Contains("**Agent message 1:**`n`nQ1: fine so far.") -and $body.Contains('**Tool calls (3):**') -and $body.Contains('- `shell: git diff --stat`') -and $body.Contains('_(no agent message or reasoning text in this turn''s event stream)_') -and $body.Contains('**Tool calls (0):** none')) ''

    # --- -Thread takes the conversation of an agy / muse run the bridge killed (its candidate)
    $cand = Uuid
    $ea = [pscustomobject]@{ n = 1; reviewer = [pscustomobject]@{ provider = 'gemini'; model = $agyModel; engine = 'agy'; provider_fingerprint = $agyFp }; thread = ''; thread_candidate = $cand; partial_reply = 'handoffs/01-agy-x.partial.md'; bridge_outcome = 'failed: timeout after 5 s (process tree killed)' }
    $eb = [pscustomobject]@{ n = 1; reviewer = $ea.reviewer; thread = ''; thread_candidate = $cand; partial_reply = ''; bridge_outcome = 'failed: agy exit 1' }
    $ec = [pscustomobject]@{ n = 1; reviewer = [pscustomobject]@{ provider = 'openai'; model = 'gpt-5.1'; engine = 'codex'; provider_fingerprint = $builtinFp }; thread = ''; thread_candidate = $cand; partial_reply = 'handoffs/01-codex-x.partial.md'; bridge_outcome = 'failed: timeout after 5 s (process tree killed)' }
    $fa = Find-ThreadEntry -Consults @($ea) -Thread $cand
    $fb = Find-ThreadEntry -Consults @($eb) -Thread $cand
    $fc = Find-ThreadEntry -Consults @($ec) -Thread $cand
    Check 'UNIT' 'T1 Find-ThreadEntry: the conversation of an agy run the bridge killed (a candidate only; the entry names its partial reply) is resumable with -Thread; without a partial reply it stays an unverified candidate; a codex candidate (a foreign rollout) never' ($fa.Entry -and -not $fa.Error -and $fb.Error -match 'unverified rollout candidate' -and $fc.Error -match 'unverified rollout candidate') "$($fb.Error)"
    # --- -Range: git diff --shortstat
    $rr = New-Repo 'range-unit'
    [IO.File]::WriteAllText((Join-Path $rr 'b.txt'), "1`n2`n3`n", $u8)
    [IO.File]::WriteAllText((Join-Path $rr 'app.txt'), "ONE`n", $u8)
    $null = G $rr @('add', '-A'); $null = G $rr @('commit', '-q', '-m', 'second')
    $rs = Get-RangeStat -Root $rr -Range 'HEAD~1..HEAD'
    $rbad = Get-RangeStat -Root $rr -Range 'nope..HEAD'
    $ropt = Get-RangeStat -Root $rr -Range '--output=x'
    $rsp = Get-RangeStat -Root $rr -Range 'HEAD~1 ..HEAD'
    Check 'UNIT' 'T1 Get-RangeStat: HEAD~1..HEAD -> 2 files, 4 insertions, 1 deletion, 5 lines; an unknown revision is refused with git''s own reason; an option-like or spaced argument is refused before git runs' ($rs.Files -eq 2 -and $rs.Insertions -eq 4 -and $rs.Deletions -eq 1 -and $rs.Lines -eq 5 -and -not $rs.Error -and $rbad.Error -match "^-Range 'nope\.\.HEAD' is not a revision range git knows in .* \(git diff --shortstat: fatal: " -and $ropt.Error -match 'is not a git revision range' -and $rsp.Error -match 'is not a git revision range') "$($rs.Files)/$($rs.Insertions)/$($rs.Deletions) | $($rbad.Error)"

    # --- F15-1: the muse launch guard re-reads auth.json (listings and the preflight keep the cache)
    $env:USERPROFILE = $museHome; $env:HOME = $museHome; $env:TBH_CREDENTIAL_BACKEND = 'file'
    Write-Auth $authOauth
    $script:MuseCredentialCache.Clear()
    $b0 = Get-MuseLaunchBlock
    Write-Auth $authApiKey
    $bStale = Get-MuseLaunchBlock
    $bFresh = Get-EngineLaunchBlock -Engine 'muse' -Fresh
    $bAfter = Get-MuseLaunchBlock
    Write-Auth $authOauth
    $script:MuseCredentialCache.Clear()
    Restore-Env
    Check 'UNIT' 'F15-1: auth.json changed from oauth to api_key after a read - the cached read (a listing, the preflight) still passes, the launch guard (Get-EngineLaunchBlock -Fresh) reads the file again and refuses; the fresh read refreshes the cache' ($b0 -eq '' -and $bStale -eq '' -and $bFresh -match "uses mechanism 'api_key', not oauth" -and $bAfter -match "uses mechanism 'api_key'") "stale='$bStale' fresh='$(Get-FirstClause $bFresh)'"
}

# =============================================================== UNIT24B: wave 24b, the acceptance panel's fixes (in-process)
if (Want 'UNIT24B') {
    $now = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    # --- F13-2: the two usable outcomes, exactly
    $qd = New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-15) 'failed: codex exit 1 - 429 Too Many Requests' (Quota $now.AddMinutes(-9) '429 Too Many Requests')
    $draft = New-Entry 2 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-5) 'usable reply (draft)'
    $hDraft = Get-EndpointHealth -Consults @($qd, $draft) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    Check 'UNIT24B' 'F13-2 Test-UsableOutcome matches the two known outcomes EXACTLY: "usable reply (draft)", "usable reply (partial)", a case variant and a trailing space are not usable - a later "usable reply (draft)" entry neither clears a usage limit nor evidences a sign-in' ((Test-UsableOutcome 'usable reply') -and (Test-UsableOutcome 'usable reply (after a timeout continuation)') -and -not (Test-UsableOutcome 'usable reply (draft)') -and -not (Test-UsableOutcome 'usable reply (partial)') -and -not (Test-UsableOutcome 'Usable reply') -and -not (Test-UsableOutcome 'usable reply ') -and $hDraft.Quota -and -not $hDraft.RecentUsable) ''
    # --- F07-2: id-less tool items of a codex stream are listed once
    $idl = Reply 'salv-idless.jsonl' ((@(('{"type":"thread.started","thread_id":"' + (Uuid) + '"}'), '{"type":"item.started","item":{"type":"command_execution","command":"git status","status":"in_progress"}}', '{"type":"item.completed","item":{"type":"command_execution","command":"git status","exit_code":0,"status":"completed"}}', '{"type":"item.started","item":{"type":"command_execution","command":"git log -1","status":"in_progress"}}', '{"type":"item.started","item":{"type":"command_execution","command":"git diff","status":"in_progress"}}', '{"type":"item.completed","item":{"type":"command_execution","command":"git diff","exit_code":0,"status":"completed"}}', '{"type":"item.completed","item":{"type":"command_execution","command":"git log -1","exit_code":0,"status":"completed"}}', '{"type":"item.started","item":{"type":"command_execution","command":"sleep 99","status":"in_progress"}}', '{"type":"item.completed","item":{"type":"web_search","query":"x"}}', '{"type":"item.completed","item":{"id":"item_9","type":"agent_message","text":"done"}}') -join "`n") + "`n")
    $si = Read-CodexSalvage -Path $idl
    Check 'UNIT24B' 'F07-2 Read-CodexSalvage: tool items WITHOUT an id are paired (item.started opens; an id-less item.completed of the same type closes the open one of the same command, else the oldest) - one line per call, never twice: git status, git log -1, git diff (completed out of order), sleep 99 (running at the kill), web_search (completed only)' (($si.Tools -join '|') -eq 'shell: git status|shell: git log -1|shell: git diff|shell: sleep 99|web_search: x' -and (@($si.Items | ForEach-Object { $_.Text }) -join '|') -eq 'done') ($si.Tools -join '|')
    # --- F08-8: -Range takes two revisions only
    $rr8 = New-Repo 'range-24b'
    [IO.File]::WriteAllText((Join-Path $rr8 'b.txt'), "1`n2`n", $u8)
    $null = G $rr8 @('add', '-A'); $null = G $rr8 @('commit', '-q', '-m', 'second')
    $g1 = Get-RangeStat -Root $rr8 -Range 'HEAD'
    $g2 = Get-RangeStat -Root $rr8 -Range 'HEAD~1...HEAD'
    $g3 = Get-RangeStat -Root $rr8 -Range '..HEAD'
    $g4 = Get-RangeStat -Root $rr8 -Range 'HEAD~1..'
    $g5 = Get-RangeStat -Root $rr8 -Range 'HEAD~1....HEAD'
    $g6 = Get-RangeStat -Root $rr8 -Range 'HEAD~1..HEAD'
    Check 'UNIT24B' 'F08-8 Get-RangeStat: a single revision (HEAD) is refused ("is not a range of two revisions: pass base..head or base...head ... a single revision would measure the working tree"), so are "..HEAD", "HEAD~1.." and four dots; base...head and base..head are measured' ($g1.Error -match "^-Range 'HEAD' is not a range of two revisions: pass base\.\.head or base\.\.\.head .*a single revision would measure the working tree against it" -and $g3.Error -and $g4.Error -and $g5.Error -and -not $g2.Error -and $g2.Files -eq 1 -and $g2.Lines -eq 2 -and -not $g6.Error -and $g6.Lines -eq 2) "$($g1.Error) | $($g2.Error) $($g2.Lines)"
    # --- F08-3: the killed turn's evidence through the one classifier
    $k1 = Get-KilledTurnFailure -Texts @('timeout after 5 s (process tree killed)') -StderrText "Reading prompt from stdin...`nERROR: Insufficient balance: top up the prepaid plan to continue"
    $k2 = Get-KilledTurnFailure -Texts @('', 'timeout after 5 s (process tree killed)') -StderrText 'Payment required (402): the prepaid plan is exhausted'
    $k3 = Get-KilledTurnFailure -StderrText 'data: {"error":{"code":"1113","message":"Insufficient balance or no resource package. Please recharge."}}'
    $k4 = Get-KilledTurnFailure -AdapterClass 'auth' -Texts @('the sign-in expired')
    $k5 = Get-KilledTurnFailure -Texts @('timeout after 5 s (process tree killed)') -StderrText "Reading prompt from stdin...`nwarning: slow network"
    $k6 = Get-KilledTurnFailure -Texts @('You have hit your usage limit. Try again later.', 'timeout after 5 s (process tree killed)')
    Check 'UNIT24B' 'F08-3 Get-KilledTurnFailure: every diagnostic stderr line (wave 24c, F15-3: ERROR level or an HTTP status) and text through the ONE classifier - billing wording the old keyword filter skipped ("ERROR: Insufficient balance: ...", "Payment required (402) ...") and an SSE payload are quota, an adapter class auth is auth, a usage limit in the event error is quota; the bridge''s timeout text and plain noise forbid nothing' ($k1.Class -eq 'quota' -and $k1.Text -eq 'ERROR: Insufficient balance: top up the prepaid plan to continue' -and $k2.Class -eq 'quota' -and $k3.Class -eq 'quota' -and $k4.Class -eq 'auth' -and $k5.Class -eq '' -and $k6.Class -eq 'quota') "$($k1.Class)/$($k2.Class)/$($k3.Class)/$($k4.Class)/'$($k5.Class)'/$($k6.Class)"
    # --- F08-5: a continuation's reply passes a first reply's checks before it counts
    $c1 = Test-ContinuationReply -Text 'Done.'
    $c2 = Test-ContinuationReply -Text $adviseJson
    $c3 = Test-ContinuationReply -Text $prose
    $c4 = Test-ContinuationReply -Text 'Done.' -Raw
    $c5 = Test-ContinuationReply -Text "I cannot finish this review in the time left." -Raw
    $c6 = Test-ContinuationReply -Text '{"verdict":"ADVISE"}'
    Check 'UNIT24B' 'F08-5 Test-ContinuationReply: "Done." is not usable ("not a valid reply object (...) and reply too short (1 words)"), a valid object and substantive prose are (the format repair converts prose), -Raw "Done." is not ("reply too short (1 words)"), a refusal is not, an invalid short object is not' (-not $c1.Usable -and $c1.Reason -match '^not a valid reply object \(.+\) and reply too short \(1 words\)$' -and $c2.Usable -and $c3.Usable -and -not $c4.Usable -and $c4.Reason -eq 'reply too short (1 words)' -and -not $c5.Usable -and $c5.Reason -eq 'reply looks like a refusal' -and -not $c6.Usable) "$($c1.Reason) | $($c4.Reason) | $($c5.Reason)"
    # --- the kimi 401 of the wave 24 acceptance ledger (n=9): a context-window limit, never auth
    $kimi = 'unexpected status 401 Unauthorized: Your current plan supports only k3 up to 256K context. 1M context is available on higher-tier Kimi Code plans. Upgrade: https://www.kimi.com/code?from=server_k3_error#pricing, url: https://api.kimi.ai/coding/v1/responses, cf-ray: a4133b7fbf13d2fa-FRA'
    $pfK = New-ProviderFailure -Texts @($kimi)
    $hintK = Get-FailureHint $pfK
    $ctxCls = @((Get-ProviderFailureClass "This model's maximum context length is 128000 tokens. However, your messages resulted in 130211 tokens."), (Get-ProviderFailureClass 'context_length_exceeded'), (Get-ProviderFailureClass 'prompt is too long: 208000 tokens > 200000 maximum'), (Get-ProviderFailureClass 'The input token count (1200000) exceeds the maximum number of tokens allowed (1048576).'), (Get-ProviderFailureClass '401 Unauthorized: invalid API key'), (Get-ProviderFailureClass "403 Forbidden: You've reached your 5-hour usage limit; your plan supports only 1M tokens per window"))
    Check 'UNIT24B' 'the kimi 401 "Your current plan supports only k3 up to 256K context ..." is class capability (not auth), no retry_after; the hint "context too long for this plan/model - narrow the brief ... or choose a model with a larger context window"; other context wordings are capability; a plain 401 stays auth; a usage-limit text naming tokens stays quota' ((Get-ProviderFailureClass $kimi) -eq 'capability' -and $pfK.class -eq 'capability' -and $null -eq $pfK.retry_after -and $hintK -match '^context too long for this plan/model - narrow the brief \(.+\) or choose a model with a larger context window$' -and ($ctxCls -join ',') -eq 'capability,capability,capability,capability,auth,quota' -and (Get-FailureHint ([pscustomobject]@{ class = 'auth'; message = '401 Unauthorized: invalid API key' })) -eq '') "$($pfK.class) | $($ctxCls -join ',') | $hintK"
    $kimiFp = Get-Sha256Hex ($u8.GetBytes('cc-provider-v1|base_url=https://api.kimi.ai/coding/v1|wire_api=responses'))
    $kAuth = New-Entry 9 'kimi' 'k3' $kimiFp 'codex' $now.AddMinutes(-20) "failed: codex exit 1 - $kimi" ([pscustomobject]@{ class = 'auth'; code = ''; message = $kimi.Substring(0, 200); when = (Iso $now.AddMinutes(-15)); retry_after = $null })
    $hK = Get-EndpointHealth -Consults @($kAuth) -Fingerprint $kimiFp -UtcNow $now.UtcDateTime
    Check 'UNIT24B' '... an entry RECORDED as auth with that message (the live ledger''s n=9, before wave 24b) is read as capability: no 24-hour auth refusal (Auth null), LastFailure class capability' ($null -eq $hK.Auth -and $hK.LastFailure.Class -eq 'capability' -and $null -eq $hK.Quota) "$($hK.LastFailure.Class)"
    # --- the byteplus 429 (n=6): quota, no reset time in the text; an echoed Retry-After is read
    $bp = 'exceeded retry limit, last status: 429 Too Many Requests, request id: 0217904369195483cb8a93f7287826a4278aac7f0d089f9d37170'
    $raBp = Get-RetryAfter -Message $bp -Reference $now
    $raEcho = Get-RetryAfter -Message 'exceeded retry limit, last status: 429 Too Many Requests, Retry-After: 30' -Reference $now
    Check 'UNIT24B' 'the byteplus 429 "exceeded retry limit, last status: 429 Too Many Requests, request id: ..." is quota with NO reset time (the request id is not a duration) - (wave 24c) a burst: out for 10 minutes (UNIT24C); a Retry-After echoed in such a text is read (+30 s)' ((Get-ProviderFailureClass $bp) -eq 'quota' -and $null -eq $raBp -and $null -ne $raEcho -and $raEcho.UtcDateTime -eq $now.AddSeconds(30).UtcDateTime) "$raBp | $raEcho"
    # --- F07-3: one listing resolves each identity and each endpoint's health once
    $env:RT_ZAI_KEY = 'zai-test-key'
    $rosterC = Roster-Of (Write-Roster 'cache4' ('{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"zai2","model":"glm-5.3"},{"provider":"gemini","engine":"agy","model":"' + $agyModel + '"}]}'))
    $consC = @((New-Entry 1 'openai' 'gpt-5.1' $builtinFp 'codex' $now.AddMinutes(-30) "failed: codex exit 1 - You've hit your usage limit." (Quota $now.AddMinutes(-30) "You've hit your usage limit." $now.AddDays(1))))
    $script:idCalls = 0
    $script:healthCalls = 0
    $origIdentity = ${function:Resolve-ReviewerIdentity}
    $origHealth = ${function:Get-EndpointHealth}
    function Resolve-ReviewerIdentity { param($Config, [string]$Provider = '', [string]$Model = '', [string]$OpenAiBaseUrl = '', [string]$Engine = 'codex', [string]$Launcher = '') $script:idCalls++; & $origIdentity @PSBoundParameters }
    function Get-EndpointHealth { param([object[]]$Consults, [string]$Fingerprint, [datetime]$UtcNow = [datetime]::UtcNow) $script:healthCalls++; & $origHealth @PSBoundParameters }
    try {
        $cacheL = New-ListingCache
        $walkC = Select-RosterReviewer -Roster $rosterC -Config $cfg -Consults $consC -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -EngineLaunchers @{ agy = $fakeAgy } -NoNetwork -Cache $cacheL
        $availC = Get-RosterAvailability -Roster $rosterC -Config $cfg -Consults $consC -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -EngineLaunchers @{ agy = $fakeAgy } -NoNetwork -Cache $cacheL
        $idWith = $script:idCalls; $hWith = $script:healthCalls
        $script:idCalls = 0; $script:healthCalls = 0
        $walkN = Select-RosterReviewer -Roster $rosterC -Config $cfg -Consults $consC -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -EngineLaunchers @{ agy = $fakeAgy } -NoNetwork
        $availN = Get-RosterAvailability -Roster $rosterC -Config $cfg -Consults $consC -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -EngineLaunchers @{ agy = $fakeAgy } -NoNetwork
        $idWithout = $script:idCalls; $hWithout = $script:healthCalls
    } finally {
        ${function:Resolve-ReviewerIdentity} = $origIdentity
        ${function:Get-EndpointHealth} = $origHealth
        Restore-Env
    }
    Check 'UNIT24B' 'F07-3 one listing (the walk + every entry''s availability) sharing -Cache resolves each of the 4 entries'' identity ONCE and each of the 3 endpoints'' health ONCE (without the cache: more); the same selection and the same line either way' ($idWith -eq 4 -and $hWith -eq 3 -and $idWithout -gt $idWith -and $hWithout -gt $hWith -and $walkC.Entry.Position -eq $walkN.Entry.Position -and $walkC.Entry.Position -eq 2 -and (Format-AvailabilityLine -Availability $availC) -eq (Format-AvailabilityLine -Availability $availN)) "with: $idWith identities, $hWith health reads; without: $idWithout, $hWithout"
}

# =============================================================== UNIT24C: wave 24c, the re-acceptance panel's fixes and two ledger facts (in-process)
if (Want 'UNIT24C') {
    $now = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    # --- F15-1: every quota-class wording wins over the context exception
    $mix1 = 'billing_required: insufficient balance for this context window'
    $mix2 = 'credits exhausted; prompt is too long'
    $mix3 = 'unexpected status 402 Payment Required: the prompt exceeds the context window of your token plan'
    $kimiCtx = 'unexpected status 401 Unauthorized: Your current plan supports only k3 up to 256K context. 1M context is available on higher-tier Kimi Code plans.'
    $clsMix = @((Get-ProviderFailureClass $mix1), (Get-ProviderFailureClass $mix2), (Get-ProviderFailureClass $mix3), (Get-ProviderFailureClass $kimiCtx))
    $kMix1 = Get-KilledTurnFailure -Texts @($mix1, 'timeout after 5 s (process tree killed)')
    $kMix2 = Get-KilledTurnFailure -Texts @('timeout after 5 s (process tree killed)') -StderrText "ERROR: $mix2"
    $pfMix = New-ProviderFailure -Texts @($mix1)
    $pfMixAt = [pscustomobject]@{ class = $pfMix.class; kind = $pfMix.kind; code = ''; message = $mix1; when = (Iso $now.AddMinutes(-9)); retry_after = $null; hint = $pfMix.hint }
    $hMix = Get-EndpointHealth -Consults @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-12) "failed: codex exit 1 - $mix1" $pfMixAt)) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    $old24b = [pscustomobject]@{ class = 'capability'; code = ''; message = $mix2; when = (Iso $now.AddMinutes(-9)); retry_after = $null }
    $hOld = Get-EndpointHealth -Consults @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-12) "failed: codex exit 1 - $mix2" $old24b)) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    Check 'UNIT24C' 'F15-1 quota wins over the context exception: "billing_required: insufficient balance for this context window", "credits exhausted; prompt is too long" and a 402 naming the context window of a token plan are quota (the kimi plan-context 401 stays capability); a killed turn with that evidence (a text, an ERROR line) reports quota - no continuation; its provider_failure is quota without the context hint and blocks the endpoint 60 minutes; an entry wave 24b recorded as capability with such a text is read as quota' (($clsMix -join ',') -eq 'quota,quota,quota,capability' -and $kMix1.Class -eq 'quota' -and $kMix2.Class -eq 'quota' -and $pfMix.class -eq 'quota' -and $pfMix.kind -eq '' -and $pfMix.hint -eq '' -and $hMix.Quota -and -not $hMix.QuotaKnown -and (Iso $hMix.Quota.Until) -eq (Iso $now.AddMinutes(51)) -and $hOld.Quota -and $hOld.LastFailure.Class -eq 'quota') "$($clsMix -join ',') | killed $($kMix1.Class)/$($kMix2.Class) | recorded $($pfMix.class) | 24b entry read as $($hOld.LastFailure.Class)"
    # --- F15-2: the listing cache is ordinal - ZAI :: glm-5.3 and zai :: GLM-5.3 never share a slot
    $cfgCase = Read-CodexConfigSubset -Path (Reply 'config-case.toml' "[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.zai]`nbase_url = `"https://open.bigmodel.cn/api/paas/v4`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n")
    $rosterCase = Roster-Of (Write-Roster 'case' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"zai","model":"GLM-5.3"}]}')
    $env:RT_ZAI_KEY = 'zai-test-key'
    try {
        $cacheCase = New-ListingCache
        $idUp = Get-CachedReviewerIdentity -Cache $cacheCase -Config $cfgCase -Provider 'ZAI' -Model 'glm-5.3'
        $idLow = Get-CachedReviewerIdentity -Cache $cacheCase -Config $cfgCase -Provider 'zai' -Model 'GLM-5.3'
        $idUp2 = Get-CachedReviewerIdentity -Cache $cacheCase -Config $cfgCase -Provider 'ZAI' -Model 'glm-5.3'
        $consCase = @((New-Entry 1 'zai' 'GLM-5.3' $idLow.Fingerprint 'codex' $now.AddMinutes(-12) 'failed: codex exit 1 - usage limit reached' (Quota $now.AddMinutes(-9) 'usage limit reached')))
        $availCase = Get-RosterAvailability -Roster $rosterCase -Config $cfgCase -Consults $consCase -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -NoNetwork -Cache (New-ListingCache)
        $plainCache = @{}
        $null = Get-CachedReviewerIdentity -Cache $plainCache -Config $cfgCase -Provider 'ZAI' -Model 'glm-5.3'
    } finally { Restore-Env }
    Check 'UNIT24C' 'F15-2 ZAI :: glm-5.3 and zai :: GLM-5.3 (two tables, two endpoints) resolve SEPARATELY through one New-ListingCache (ordinal, case-preserving length-prefixed keys: the marker and two identity slots) - each its own provider, model and fingerprint; one listing over both judges each by its OWN endpoint health (zai out for its usage limit, ZAI available); a plain @{} is never used as a cache (nothing written into it)' ($idUp.Provider -ceq 'ZAI' -and $idUp.Model -ceq 'glm-5.3' -and $idLow.Provider -ceq 'zai' -and $idLow.Model -ceq 'GLM-5.3' -and $idUp.Fingerprint -and $idLow.Fingerprint -and $idUp.Fingerprint -ne $idLow.Fingerprint -and $idUp2.Fingerprint -eq $idUp.Fingerprint -and $cacheCase.Count -eq 3 -and $availCase.Records[0].State -eq 'available' -and $availCase.Records[1].State -eq 'out' -and $availCase.Records[1].Kind -eq 'quota-unknown-reset' -and $plainCache.Count -eq 0) "ZAI $([string]$idUp.Fingerprint) / zai $([string]$idLow.Fingerprint); slots $($cacheCase.Count); states $($availCase.Records[0].State)/$($availCase.Records[1].State); plain $($plainCache.Count)"
    # --- F15-3: only structured evidence and the diagnostic stderr lines are classified
    $benign = "Reading prompt from stdin...`nloaded auth.json`nrequest 429 tracing enabled`nbilling module ready`n2026-09-26T18:28:36.873087Z ERROR codex_models_manager::manager: failed to refresh available models: stream disconnected before completion: failed to decode models response: missing field ``models`` at line 1 column 27995; body: {""data"":[{""id"":""m"",""billing"":""quota"",""auth"":""429""}]}`nModel metadata for ``k3`` not found. Defaulting to fallback metadata; this can degrade performance and cause issues."
    $kBenign = Get-KilledTurnFailure -Texts @('timeout after 5 s (process tree killed)') -StderrText $benign
    $kDiag = @(foreach ($l in @('ERROR: exceeded retry limit, last status: 429 Too Many Requests, request id: 0217904369195483cb8a93f7287826a4278aac7f0d089f9d37170', '2026-09-26T08:30:28Z ERROR codex_core::codex: unexpected status 401 Unauthorized: invalid API key', 'WARN codex_core::client: stream error: exceeded retry limit, last status: 429 Too Many Requests; retrying 1/5', 'Payment required (402): the prepaid plan is exhausted', 'Error: you are not signed in. Run agy to sign in with your Google account.')) { [string](Get-KilledTurnFailure -Texts @('timeout after 5 s (process tree killed)') -StderrText "$benign`n$l").Class })
    $kTail = Get-KilledTurnFailure -Texts @('', 'loaded auth.json', 'timeout after 5 s (process tree killed)') -StderrText 'loaded auth.json'
    $kSse = Get-KilledTurnFailure -StderrText "$benign`ndata: {""error"":{""code"":""1113"",""message"":""Insufficient balance or no resource package. Please recharge.""}}"
    Check 'UNIT24C' 'F15-3 Get-KilledTurnFailure classifies structured evidence and DIAGNOSTIC stderr lines only: plain lines that merely contain auth, billing or 429 ("loaded auth.json", "request 429 tracing enabled"), codex''s models refresh logged at ERROR level with a body naming billing, quota and auth, the fallback-metadata notice -> nothing (the continuation stays permitted); an "ERROR:" line, an ERROR log line with an HTTP status, a WARN "stream error" with "last status: 429", "(402)", "Error: ..." -> quota/auth/quota/quota/auth; an SSE payload is structured evidence; an agy stderr tail copied into the adapter''s texts is judged as that line' ($kBenign.Class -eq '' -and ($kDiag -join ',') -eq 'quota,auth,quota,quota,auth' -and $kTail.Class -eq '' -and $kSse.Class -eq 'quota') "benign '$($kBenign.Class)' | $($kDiag -join ',') | tail '$($kTail.Class)' | sse $($kSse.Class)"
    # --- F15-4: the hint is decided when the failure is classified
    $pfCode = New-ProviderFailure -Texts @('data: {"error":{"code":"context_length_exceeded","message":"Request too large."}}')
    $longCtx = ('The upstream gateway validated every message, tool definition and attachment of the conversation and rejected the request. ' * 2) + 'Reason: the prompt is too long for this model (212000 tokens > 200000).'
    $pfLong = New-ProviderFailure -Texts @($longCtx)
    $legacyCtx = [pscustomobject]@{ class = 'capability'; code = 'context_length_exceeded'; message = 'Request too large.' }
    Check 'UNIT24C' 'F15-4 the hint is decided at classification and stored (provider_failure.hint): a code-only context_length_exceeded ("Request too large.") and a context phrase past the 200 characters the message keeps both get "context too long for this plan/model - ..." (Get-FailureHint reads it: summary and header); an entry recorded before wave 24c (no hint) gets it from its code + message' ($pfCode.class -eq 'capability' -and $pfCode.code -eq 'context_length_exceeded' -and $pfCode.hint -match '^context too long for this plan/model - ' -and (Get-FailureHint $pfCode) -eq $pfCode.hint -and $pfLong.message.Length -eq 200 -and $pfLong.message -notmatch 'too long' -and $pfLong.class -eq 'capability' -and (Get-FailureHint $pfLong) -match '^context too long for this plan/model - ' -and (Get-FailureHint $legacyCtx) -match '^context too long for this plan/model - ') "code $($pfCode.class) hint '$([string]$pfCode.hint)' | long $($pfLong.class)/$($pfLong.message.Length)"
    # --- F15-6: Invoke-EngineTurn (codex-consult.ps1, taken from its AST) restores the record on every non-start path
    $astConsult = [System.Management.Automation.Language.Parser]::ParseFile($consultPs, [ref]$null, [ref]$null)
    foreach ($fd in @($astConsult.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and @('Start-EngineProcess', 'Invoke-EngineTurn') -contains $n.Name }, $true))) { . ([scriptblock]::Create($fd.Extent.Text)) }
    $turnDir = Join-Path $work 'f15-6'
    [void][IO.Directory]::CreateDirectory($turnDir)
    $pendingPath = Join-Path $turnDir '.consult.pending.json'
    $pendingRecord = New-PendingRecord -State 'running' -N 1 -Nn '01' -Reply 'handoffs/01-codex-x.md' -Started (Iso $now) -Launcher 'x' -ConsultId (Uuid)
    $pendingRecord.child_pid = 4242
    $pendingRecord.note = 'the main turn'
    Write-PendingFile -Path $pendingPath -Record $pendingRecord
    $engineName = 'codex'
    $engineLauncher = Join-Path $turnDir 'launcher-gone.cmd'
    $tErr = Invoke-EngineTurn -Argv @('exec', '-') -StdinText 'x' -EventsPath (Join-Path $turnDir 'c.events.jsonl') -StdinPath (Join-Path $turnDir 'c.stdin') -StderrPath (Join-Path $turnDir 'c.stderr') -Timeout 5 -Note 'timeout continuation turn'
    $dErr = (Read-PendingFile -Path $pendingPath).Record
    $memErr = [string]$pendingRecord.state
    Set-CaseEnv '' @{ META_API_KEY = 'x-not-a-key' }
    try {
        $engineName = 'muse'
        $tRef = Invoke-EngineTurn -Argv @('exec') -StdinText '' -EventsPath (Join-Path $turnDir 'r.events.jsonl') -StdinPath (Join-Path $turnDir 'r.stdin') -StderrPath (Join-Path $turnDir 'r.stderr') -Timeout 5 -Note 'format repair turn' -PromptPath (Join-Path $turnDir 'r.prompt.md') -PromptText 'x'
    } finally { Restore-Env }
    $dRef = (Read-PendingFile -Path $pendingPath).Record
    Check 'UNIT24C' 'F15-6 Invoke-EngineTurn (codex-consult.ps1, taken from its AST): a Start-Process error (the launcher is gone) starts nothing and gives the recovery record its previous state back - on disk and in memory: running, the main turn''s child pid 4242 and note, never "launching"; Problem "could not start codex - ..."; a launch refusal (muse: META_API_KEY set) restores it the same way' ($tErr.Problem -match '^could not start codex - ' -and -not $tErr.Started -and $dErr.state -eq 'running' -and $dErr.note -eq 'the main turn' -and [int]$dErr.child_pid -eq 4242 -and $memErr -eq 'running' -and $tRef.Problem -match '^refused before launch: META_API_KEY is set' -and -not $tRef.Started -and $dRef.state -eq 'running' -and $dRef.note -eq 'the main turn') "$($tErr.Problem) | disk $($dErr.state)/$($dErr.note)/$($dErr.child_pid) | $([string]$tRef.Problem)"
    Remove-Variable -Name pendingPath, pendingRecord, engineName, engineLauncher -ErrorAction SilentlyContinue
    # --- the burst 429 (the live ledgers: nonblocking n=2, companions n=6 and n=12) - out for 10 minutes
    $bpMsgs = @('exceeded retry limit, last status: 429 Too Many Requests, request id: 021790411419329e8a97f786c365ea5f8ca348976dbfcd2d8a713', 'exceeded retry limit, last status: 429 Too Many Requests, request id: 0217904369195483cb8a93f7287826a4278aac7f0d089f9d37170', 'exceeded retry limit, last status: 429 Too Many Requests, request id: 021790447325230e0fa5d59a7b50e9f748f37815b909e289b22b6')
    $bpPf = @($bpMsgs | ForEach-Object { New-ProviderFailure -Texts @($_) })
    $pfUse = New-ProviderFailure -Texts @('429 Too Many Requests: usage limit exceeded')
    $pfWin = New-ProviderFailure -Texts @("unexpected status 403 Forbidden: You've reached your 5-hour usage limit. Your quota will reset when the current 5-hour window ends.")
    Check 'UNIT24C' 'burst: the three live 429s ("exceeded retry limit, last status: 429 Too Many Requests, request id: ...") are quota, kind burst, no retry_after; a 429 naming a usage limit and a 5-hour window are kind "" (the 60-minute rule); provider_failure fields class,kind,code,message,when,retry_after,hint' (@($bpPf | Where-Object { $_.class -eq 'quota' -and $_.kind -eq 'burst' -and $null -eq $_.retry_after }).Count -eq 3 -and $pfUse.class -eq 'quota' -and $pfUse.kind -eq '' -and $pfWin.class -eq 'quota' -and $pfWin.kind -eq '' -and (($bpPf[0].PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'class,kind,code,message,when,retry_after,hint') "$(@($bpPf | ForEach-Object { "$($_.class)/$($_.kind)" }) -join ' ') | '$($pfUse.kind)'/'$($pfWin.kind)'"
    $hitB = $now.AddMinutes(-9)
    $bEntry = New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-12) "failed: codex exit 1 - $($bpMsgs[1])" (Quota $hitB $bpMsgs[1])
    $hB9 = Get-EndpointHealth -Consults @($bEntry) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    $hB11 = Get-EndpointHealth -Consults @($bEntry) -Fingerprint $zaiFp -UtcNow $hitB.AddMinutes(11).UtcDateTime
    $uEntry = New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-12) 'failed: codex exit 1 - 429 Too Many Requests: usage limit exceeded' (Quota $hitB '429 Too Many Requests: usage limit exceeded')
    $hU11 = Get-EndpointHealth -Consults @($uEntry) -Fingerprint $zaiFp -UtcNow $hitB.AddMinutes(11).UtcDateTime
    $kEntry = New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-12) 'failed: codex exit 1 - rate limited' ([pscustomobject]@{ class = 'quota'; kind = 'burst'; code = ''; message = 'rate limited'; when = (Iso $hitB); retry_after = $null; hint = '' })
    $hK = Get-EndpointHealth -Consults @($kEntry) -Fingerprint $zaiFp -UtcNow $now.UtcDateTime
    Check 'UNIT24C' 'burst: Get-EndpointHealth reads a burst 429 recorded WITHOUT kind (as the live ledgers hold it) from its message - FailureKind burst, out 10 minutes: blocking 9 min after the hit (Until = Hit + 10 min), clear 11 min after (LastFailure keeps it); a 429 naming a usage limit is still out 11 min after (Until = Hit + 60 min); a recorded kind is taken as recorded' ($hB9.Quota -and $hB9.Quota.FailureKind -eq 'burst' -and $hB9.Quota.OutMinutes -eq 10 -and (Iso $hB9.Quota.Until) -eq (Iso $hitB.AddMinutes(10)) -and -not $hB11.Quota -and $hB11.LastFailure.Class -eq 'quota' -and $hU11.Quota -and (Iso $hU11.Quota.Until) -eq (Iso $hitB.AddMinutes(60)) -and $hK.Quota.FailureKind -eq 'burst' -and $hK.Quota.OutMinutes -eq 10) "until $(if ($hB9.Quota) { Iso $hB9.Quota.Until }) | blocking 11 min after: $([bool]$hB11.Quota) | usage-limit 429 until $(if ($hU11.Quota) { Iso $hU11.Quota.Until })"
    $env:RT_ZAI_KEY = 'zai-test-key'
    try {
        $idZb = Resolve-ReviewerIdentity -Config $cfg -Provider 'ZAI' -Model 'glm-5.3'
        $vB = Get-PreflightVerdict -Identity $idZb -Config $cfg -Launcher $fakeCodex -Health $hB9 -RosterWalk
        $vBs = Get-PreflightVerdict -Identity $idZb -Config $cfg -Launcher $fakeCodex -Health $hB9
        $qwB = Format-QuotaWarning -Identity $idZb -Health $hB9 -SkipPreflight
        $recB = ConvertTo-AvailabilityRecord -Position 1 -Provider 'ZAI' -Model 'glm-5.3' -Verdict $vB -UtcNow $now.UtcDateTime
    } finally { Restore-Env }
    $m100 = $bpMsgs[1].Substring(0, 100)
    Check 'UNIT24C' 'burst: the verdict of every caller - unavailable, Kind quota-unknown-reset, Burst, Reason "burst limit (429) hit <iso>, reset unknown; retry after <iso + 10 min>"; the refusal "... it hit a burst limit at <iso> (<message> - a 429 that names no usage limit or quota) and named no reset time - out for 10 minutes, until <iso>; nothing was started (pass -SkipPreflight to launch anyway)"; the -SkipPreflight warning and the one-line view say "burst limit"' ($vB.State -eq 'unavailable' -and $vB.Kind -eq 'quota-unknown-reset' -and $vB.Burst -and $vB.Reason -eq "burst limit (429) hit $(Iso $hitB), reset unknown; retry after $(Iso $hitB.AddMinutes(10))" -and $vBs.Refusal -eq "provider ZAI is not usable: it hit a burst limit at $(Iso $hitB) ($m100 - a 429 that names no usage limit or quota) and named no reset time - out for 10 minutes, until $(Iso $hitB.AddMinutes(10)); nothing was started (pass -SkipPreflight to launch anyway)" -and $qwB -eq "provider ZAI hit a burst limit (429) 12 min ago (reset unknown; out until $(Iso $hitB.AddMinutes(10))): $m100" -and $recB.Short -eq "burst limit hit $(Local-When $hitB $now), reset unknown; retry after $(Local-When $hitB.AddMinutes(10) $now), in 1m") "$($vB.Reason) | $($recB.Short)"
    # --- the tree check by CONTENT: a commit (HEAD moved) is no tree change
    $rt = New-Repo 'content-24c'
    [IO.File]::WriteAllText((Join-Path $rt '.collab\t\state.md'), "coordinator notes`n", $u8)
    [IO.File]::WriteAllText((Join-Path $rt 'app.txt'), "one`ntwo`n", $u8)
    [IO.File]::WriteAllText((Join-Path $rt 'new.txt'), "untracked`n", $u8)
    $collabT = Join-Path $rt '.collab'
    $cb = Get-RevisionInfo -Root $rt -CollabRoot $collabT
    $null = G $rt @('add', '-f', '.collab/t/state.md', 'app.txt'); $null = G $rt @('commit', '-q', '-m', 'coordinator')
    $ca = Get-RevisionInfo -Root $rt -CollabRoot $collabT
    $cc1 = Compare-TreeContent -Before $cb -After $ca
    $null = G $rt @('add', 'new.txt')
    $cc2 = Compare-TreeContent -Before $cb -After (Get-RevisionInfo -Root $rt -CollabRoot $collabT)
    [IO.File]::WriteAllText((Join-Path $rt 'app.txt'), "changed`n", $u8)
    $cc3 = Compare-TreeContent -Before $cb -After (Get-RevisionInfo -Root $rt -CollabRoot $collabT)
    Check 'UNIT24C' 'the tree check compares CONTENTS (Compare-TreeContent): committing the collab files and a file already changed moves HEAD and tree_sha256 but no content - no change, RevisionMoved "<old base_commit> -> <new>"; staging an untracked file (git add) is no change either; a real content change is one, naming its path' (-not $cc1.Changed -and $cb.tree_sha256 -ne $ca.tree_sha256 -and $cb.base_commit -ne $ca.base_commit -and $cc1.RevisionMoved -eq "$($cb.base_commit) -> $($ca.base_commit)" -and $cb.content_sha256 -eq $ca.content_sha256 -and -not $cc2.Changed -and $cc3.Changed -and ($cc3.Paths -join ',') -eq 'app.txt') "commit: $($cc1.Changed) '$($cc1.RevisionMoved)' | add: $($cc2.Changed) | edit: $($cc3.Changed) [$($cc3.Paths -join ',')]"
    # --- F08-2 ruling: the codex engine's collab exclusion is documented
    $readme24c = [IO.File]::ReadAllText((Join-Path $repoRoot 'README.md'), $u8) -replace '\s+', ' '
    Check 'UNIT24C' 'F08-2 ruling (by design, unchanged): the README residual states that a codex run''s continuation gate does not see the collab directory - the codex engine never snapshots it (it cannot tell its own writes from others'')' ($readme24c.Contains('Residual (codex):') -and $readme24c.Contains('never snapshots the collab directory')) ''
}

# =============================================================== AVAIL: every roster entry judged, the one-line view (in-process)
if (Want 'AVAIL') {
    $now = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    $roster5 = Roster-Of (Write-Roster 'avail5' ('{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"gemini","engine":"agy","model":"' + $agyModel + '"},{"provider":"gemini","engine":"agy","model":"gemini-3.1-pro-high","panel":"weighty"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'))
    $oaiUntil = $now.AddDays(2).AddHours(10)
    $gemUntil = $now.AddDays(2).AddHours(11)
    $consults = @((New-Entry 1 'openai' 'gpt-5.1' $builtinFp 'codex' $now.AddDays(-1).AddHours(-1) "failed: codex exit 1 - You've hit your usage limit." (Quota $now.AddDays(-1).AddHours(-1) "You've hit your usage limit." $oaiUntil)), (New-Entry 2 'gemini' $agyModel $agyFp 'agy' $now.AddMinutes(-30) 'failed: agy exit 3 - Individual quota reached.' (Quota $now.AddMinutes(-30) 'Individual quota reached.' $gemUntil)), (New-Entry 3 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-20)))
    $env:RT_ZAI_KEY = 'zai-test-key'
    Remove-Item env:RT_MIMO_KEY -ErrorAction SilentlyContinue
    $a5 = Get-RosterAvailability -Roster $roster5 -Config $cfg -Consults $consults -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -EngineLaunchers @{ agy = $fakeAgy } -NoNetwork
    $line5 = Format-AvailabilityLine -Availability $a5
    $exp5 = "codex-consult: out - openai :: gpt-5.1 (until $(Local-When $oaiUntil $now), in 2d 10h), gemini :: * (until $(Local-When $gemUntil $now), in 2d 11h), mimo :: mimo-v2.6-pro (env RT_MIMO_KEY not set); 1 of 5 reviewers available"
    Check 'AVAIL' 'D15/D17 the line over EVERY entry (the weighty one too, -NoNetwork): openai out until <local> with the rounded hint, both gemini entries collapse to "gemini :: *", mimo out for its missing key; "1 of 5 reviewers available"' ($line5 -eq $exp5) $line5
    Check 'AVAIL' '... the records: states out/available/out/out/out, kinds quota/-/quota/quota/credentials, the walk''s reasons ("usage limit until <iso>"), the first available = ZAI (what the single-reviewer walk selects)' ((@($a5.Records | ForEach-Object { $_.State }) -join ',') -eq 'out,available,out,out,out' -and (@($a5.Records | ForEach-Object { $_.Kind }) -join ',') -eq 'quota,,quota,quota,credentials' -and $a5.Records[0].Reason -eq "usage limit until $(Iso $oaiUntil)" -and $a5.Selected.Provider -eq 'ZAI' -and $a5.Available -eq 1 -and $a5.Out -eq 4 -and $a5.NotChecked -eq 0) ((@($a5.Records | ForEach-Object { "$($_.Provider):$($_.State):$($_.Kind)" })) -join ' ')
    $walk5 = Select-RosterReviewer -Roster $roster5 -Config $cfg -Consults $consults -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -EngineLaunchers @{ agy = $fakeAgy } -NoNetwork
    Check 'AVAIL' 'D14: the single-reviewer walk selects the same entry the records call the first available one, and skips openai with the same reason' ($walk5.Entry.Position -eq $a5.Selected.Position -and $walk5.Skipped[0].reason -eq $a5.Records[0].Reason) "walk #$($walk5.Entry.Position)"
    $a2 = Get-RosterAvailability -Roster (Roster-Of $rosterCodex) -Config $cfg -Consults @() -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -NoNetwork
    Check 'AVAIL' 'D17: every entry available -> "codex-consult: all 2 reviewers available"' ((Format-AvailabilityLine -Availability $a2) -eq 'codex-consult: all 2 reviewers available') (Format-AvailabilityLine -Availability $a2)
    $rosterAgy3 = Roster-Of (Write-Roster 'avail-agy3' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"' + $agyModel + '"},{"provider":"gemini","engine":"agy","model":"gemini-3.1-pro-high"},{"provider":"openai","model":"gpt-5.1"}]}'))
    $a3 = Get-RosterAvailability -Roster $rosterAgy3 -Config $cfg -Consults @() -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -EngineLaunchers @{ agy = $fakeAgy } -NoNetwork
    $line3 = Format-AvailabilityLine -Availability $a3
    Check 'AVAIL' 'D17 three counts: two agy entries whose sign-in -NoNetwork did not check -> "not checked - gemini :: * (sign-in not checked); 1 of 3 reviewers available, 0 out, 2 not checked"' ($line3 -eq 'codex-consult: not checked - gemini :: * (sign-in not checked); 1 of 3 reviewers available, 0 out, 2 not checked' -and $a3.NotChecked -eq 2) $line3
    # a config with a third label on the ZAI endpoint whose key is not set, and none of a top-level model
    $cfgZ = Read-CodexConfigSubset -Path (Reply 'config-zai.toml' "[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.zai2]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.zai3]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI3_KEY`"`nwire_api = `"responses`"`n")
    $hitZ = $now.AddMinutes(-9)
    $zq = @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-12) 'failed: codex exit 1 - 429 Too Many Requests: usage limit exceeded' (Quota $hitZ '429 Too Many Requests: usage limit exceeded')))
    $rz = Roster-Of (Write-Roster 'avail-zai' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"zai2","model":"glm-5.3"}]}')
    $az = Get-RosterAvailability -Roster $rz -Config $cfgZ -Consults $zq -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -NoNetwork
    $lineZ = Format-AvailabilityLine -Availability $az
    $expZ = "codex-consult: out - ZAI+zai2 :: * (limit hit $(Local-When $hitZ $now), reset unknown; retry after $(Local-When $hitZ.AddMinutes(60) $now), in 51m); 0 of 2 reviewers available"
    Check 'AVAIL' 'T3/D16: a 429 naming a usage limit without a reset time 9 min ago on the ZAI endpoint -> both labels of that endpoint group (ZAI, zai2) out, one clause "ZAI+zai2 :: * (limit hit <local>, reset unknown; retry after <local + 60 min>, in 51m)" - no clause cut at 60 characters' ($lineZ -eq $expZ) $lineZ
    $rz3 = Roster-Of (Write-Roster 'avail-zai3' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"zai3","model":"glm-5.3"},{"provider":"ZAI"}]}')
    $az3 = Get-RosterAvailability -Roster $rz3 -Config $cfgZ -Consults $zq -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -NoNetwork
    $lineZ3 = Format-AvailabilityLine -Availability $az3
    $shortZ = "limit hit $(Local-When $hitZ $now), reset unknown; retry after $(Local-When $hitZ.AddMinutes(60) $now), in 51m"
    Check 'AVAIL' 'D15/D16: entries of one group in different states get one clause each (zai3: its key is not set); the ZAI entry without a model (identity unresolved: not checked by itself) is marked out by its group''s recorded outage' ($lineZ3 -eq "codex-consult: out - ZAI :: glm-5.3 ($shortZ), zai3 :: glm-5.3 (env RT_ZAI3_KEY not set), ZAI :: unknown ($shortZ); 0 of 3 reviewers available" -and $az3.Records[2].Kind -eq 'quota-unknown-reset') $lineZ3
    Restore-Env
}

# =============================================================== AGREE: ONE ledger - the listing, -Short, the hook and the roster walk agree (T2, D14)
if (Want 'AGREE') {
    $r = New-Repo 'agree'
    $nowA = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    $clockA = @{ CODEX_CONSULT_NOW = (Iso $nowA) }
    $untilA = $nowA.AddDays(2).AddHours(10)
    # the report behind T2: a weekly limit hit TWO days ago (outside the 24-hour window of LAST
    # FAILURE), its reset still ahead; ZAI answered 30 minutes ago
    Seed-Ledger $r 'other' @((New-Entry 1 'openai' 'gpt-5.1' $builtinFp 'codex' $nowA.AddDays(-2) "failed: codex exit 1 - You've hit your usage limit." (Quota $nowA.AddDays(-2) "You've hit your usage limit." $untilA)), (New-Entry 2 'ZAI' 'glm-5.3' $zaiFp 'codex' $nowA.AddMinutes(-30)))
    $pj = Providers $r $rosterCodex @('-Json') $clockA
    $oai = @($pj.Json | Where-Object { $_.name -eq 'openai' })[0]
    $zai = @($pj.Json | Where-Object { $_.name -eq 'ZAI' })[0]
    Check 'AGREE' 'T2 codex-providers -Json: openai "unavailable (usage limit until <iso>)", last_failure = the 2-day-old quota failure with its retry_after (no longer "-"), not selected; ZAI selected; every row names its health source (the collab dir: 1 task ledger, 2 consultations)' ($pj.Code -eq 0 -and $oai.verdict -eq "unavailable (usage limit until $(Iso $untilA))" -and $oai.last_failure.class -eq 'quota' -and $oai.last_failure.retry_after -eq (Iso $untilA) -and $oai.roster_selected -eq $false -and $zai.roster_selected -eq $true -and $oai.health_source -match '\\.collab \(1 task ledger, 2 consultations\)$') "$($oai.verdict) | $($oai.health_source)"
    $pt = Providers $r $rosterCodex @() $clockA
    $oline = (($pt.Out -split "`n") | Where-Object { $_ -match '^unavailable \(usage limit until [^)]*\)\s+openai\s' } | Select-Object -First 1)
    Check 'AGREE' 'T2 the table: an "endpoint health: <collab dir> (1 task ledger, 2 consultations), read at <local time> - the ledgers of THIS repository" line; LAST FAILURE of openai "quota until <iso>: ..."; the roster line selects ZAI and skips openai with the walk''s reason; "availability: out - openai :: gpt-5.1 (until <local>, in 2d 10h); 1 of 2 reviewers available"' ($pt.Code -eq 0 -and $pt.Out -match '(?m)^endpoint health: .*\\.collab \(1 task ledger, 2 consultations\), read at \d{4}-\d\d-\d\d \d\d:\d\d - the ledgers of THIS repository$' -and $oline -match ('quota until ' + [regex]::Escape((Iso $untilA)) + ': ') -and $pt.Out.Contains("-> would select ZAI :: glm-5.3 (skipped: openai :: gpt-5.1 (usage limit until $(Iso $untilA)))") -and $pt.Out.Contains("availability: out - openai :: gpt-5.1 (until $(Local-When $untilA $nowA), in 2d 10h); 1 of 2 reviewers available")) ((@(($pt.Out -split "`n") | Where-Object { $_ -match '^(endpoint health|roster|unavailable)' })) -join ' || ')
    $d = Consult $r $rosterCodex @('-DryRun', '-Prompt', 'x') $clockA
    Check 'AGREE' 'D14 the roster walk of a consultation (dry run) on the same ledger: selects ZAI (position 2), skips openai with exactly the listing row''s reason' ($d.Code -eq 0 -and $d.Preview.roster.position -eq 2 -and $d.Preview.roster.skipped[0].reason -eq "usage limit until $(Iso $untilA)" -and "unavailable ($($d.Preview.roster.skipped[0].reason))" -eq $oai.verdict) (Line $d.Out 'Roster:')
    $expA = "codex-consult: out - openai :: gpt-5.1 (until $(Local-When $untilA $nowA), in 2d 10h); 1 of 2 reviewers available"
    $sh = Providers $r $rosterCodex @('-Short') $clockA
    $hk = Hook $r $rosterCodex $clockA
    Check 'AGREE' 'D15/D17 codex-providers -Short and the SessionStart hook print the same line: "codex-consult: out - openai :: gpt-5.1 (until <local>, in 2d 10h); 1 of 2 reviewers available"' ($sh.Code -eq 0 -and $sh.Out.Trim() -eq $expA -and $hk -eq $expA) "short='$($sh.Out.Trim())' hook='$hk'"
    $sj = Providers $r $rosterCodex @('-Short', '-Json') $clockA
    $o = @($sj.Json)[0]
    Check 'AGREE' 'D15 -Short -Json: {line, health_source, total 2, available 1, out 1, not_checked 0, roster, entries[]} - entry 1 out (kind quota, the walk''s reason, until <iso>), entry 2 available' ($sj.Code -eq 0 -and $o.line -eq $expA -and $o.total -eq 2 -and $o.available -eq 1 -and $o.out -eq 1 -and $o.not_checked -eq 0 -and $o.roster -eq $rosterCodex -and $o.entries[0].state -eq 'out' -and $o.entries[0].kind -eq 'quota' -and $o.entries[0].until -eq (Iso $untilA) -and $o.entries[0].reason -eq "usage limit until $(Iso $untilA)" -and $o.entries[1].state -eq 'available' -and $o.health_source -match '\(1 task ledger, 2 consultations\)$') ($o | ConvertTo-Json -Compress -Depth 4)
    # the cause of T2: the same listing in ANOTHER repository sees none of those ledgers - and says so
    $r2 = New-Repo 'agree-elsewhere'
    $pe = Providers $r2 $rosterCodex @() $clockA
    Check 'AGREE' 'T2 (the cause): run in another repository the listing reads THAT repository''s ledgers - openai available and would be selected - and its "endpoint health:" line says so (0 task ledgers, 0 consultations)' ($pe.Code -eq 0 -and $pe.Out -match '(?m)^available\s+openai\s' -and $pe.Out -match '(?m)^endpoint health: .*\(0 task ledgers, 0 consultations\), read at ' -and $pe.Out -match '-> would select openai :: gpt-5\.1') (Line $pe.Out 'endpoint health:')
}

# =============================================================== QUOTA60: a quota failure without a reset time is out for 60 minutes - everywhere (T3, D14; wave 24c: a 429 that names a usage limit - a bare burst 429 is BURST's)
if (Want 'QUOTA60') {
    $r = New-Repo 'quota60'
    $nowQ = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    $hitQ = $nowQ.AddMinutes(-9)
    Seed-Ledger $r 'other' @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $nowQ.AddMinutes(-12) 'failed: codex exit 1 - 429 Too Many Requests: usage limit exceeded' (Quota $hitQ '429 Too Many Requests: usage limit exceeded')))
    $clockQ = @{ CODEX_CONSULT_NOW = (Iso $nowQ) }
    $reasonQ = "usage limit hit $(Iso $hitQ), reset unknown; retry after $(Iso $hitQ.AddMinutes(60))"
    $rosterZO = Write-Roster 'zai-openai' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"openai","model":"gpt-5.1"}]}'
    $d = Consult $r $rosterZO @('-DryRun', '-Prompt', 'x') $clockQ
    $pj = Providers $r $rosterZO @('-Json') $clockQ
    $zr = @($pj.Json | Where-Object { $_.name -eq 'ZAI' })[0]
    $expQ = "codex-consult: out - ZAI :: glm-5.3 (limit hit $(Local-When $hitQ $nowQ), reset unknown; retry after $(Local-When $hitQ.AddMinutes(60) $nowQ), in 51m); 1 of 2 reviewers available"
    $sh = Providers $r $rosterZO @('-Short') $clockQ
    $hk = Hook $r $rosterZO $clockQ
    Check 'QUOTA60' 'T3 a 429 naming a usage limit without a reset time, hit 9 min ago: the roster walk skips ZAI "usage limit hit <iso>, reset unknown; retry after <iso + 60 min>"; the listing row reads "unavailable (<the same>)"; -Short and the hook say it is out, in local time - one verdict everywhere' ($d.Code -eq 0 -and $d.Preview.roster.position -eq 2 -and $d.Preview.roster.skipped[0].reason -eq $reasonQ -and $zr.verdict -eq "unavailable ($reasonQ)" -and $zr.roster_selected -eq $false -and $sh.Out.Trim() -eq $expQ -and $hk -eq $expQ) "walk='$($d.Preview.roster.skipped[0].reason)' row='$($zr.verdict)' hook='$hk'"
    $later = @{ CODEX_CONSULT_NOW = (Iso $hitQ.AddMinutes(61)) }
    $d2 = Consult $r $rosterZO @('-DryRun', '-Prompt', 'x') $later
    $sh2 = Providers $r $rosterZO @('-Short') $later
    Check 'QUOTA60' '... 61 min after the hit: the walk selects ZAI again, the line reads "all 2 reviewers available"' ($d2.Code -eq 0 -and $d2.Preview.roster.position -eq 1 -and $sh2.Out.Trim() -eq 'codex-consult: all 2 reviewers available') $sh2.Out.Trim()
    $px = Providers $r $rosterZO @('-Provider', 'ZAI') $clockQ
    $dx = Consult $r $rosterZO @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3') $clockQ
    $n0q = @(Ledger $r).Count
    $xq = Consult $r $rosterZO @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'refused') ($clockQ + @{ FAKE_CODEX_REPLY = $advise })
    $sq = Consult $r $rosterZO @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-SkipPreflight') $clockQ
    $refQ = "codex-consult: provider ZAI is not usable: it hit a usage limit at $(Iso $hitQ) (429 Too Many Requests: usage limit exceeded) and named no reset time - out for 60 minutes, until $(Iso $hitQ.AddMinutes(60)); nothing was started (pass -SkipPreflight to launch anyway)"
    Check 'QUOTA60' 'F08-7 ... codex-providers -Provider ZAI exits 2 and an explicit -Provider ZAI run is REFUSED too (one verdict for every caller): the dry run reads preflight "unavailable: <the walk''s reason>" with no warning; the real run exits 1 with "... out for 60 minutes, until <iso>; nothing was started (pass -SkipPreflight to launch anyway)", no ledger entry; -SkipPreflight launches and warns "(reset unknown; out until <iso>)"' ($px.Code -eq 2 -and $dx.Code -eq 0 -and $dx.Preview.preflight -eq "unavailable: $reasonQ" -and $dx.Preview.preflight_warning -eq '' -and $xq.Code -eq 1 -and $xq.First -eq $refQ -and @(Ledger $r).Count -eq $n0q -and $sq.Code -eq 0 -and $sq.Preview.preflight -eq 'skipped' -and $sq.Preview.preflight_warning -eq "provider ZAI hit a usage limit 12 min ago (reset unknown; out until $(Iso $hitQ.AddMinutes(60))): 429 Too Many Requests: usage limit exceeded") "exit $($px.Code) | $($xq.First) | $($sq.Preview.preflight_warning)"
    Seed-Ledger $r 'other2' @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $nowQ.AddMinutes(-3)))
    $sh3 = Providers $r $rosterZO @('-Short') $clockQ
    Check 'QUOTA60' '... a later successful run on that endpoint (another task of the repository) clears it at once: "all 2 reviewers available"' ($sh3.Out.Trim() -eq 'codex-consult: all 2 reviewers available') $sh3.Out.Trim()
}

# =============================================================== HOOK: the SessionStart line variants (D15-D17; -Short prints the same)
if (Want 'HOOK') {
    $r = New-Repo 'hook'
    $h1 = Hook $r $rosterCodex
    $s1 = Providers $r $rosterCodex @('-Short')
    Check 'HOOK' 'every entry available: "codex-consult: all 2 reviewers available" (hook and -Short)' ($h1 -eq 'codex-consult: all 2 reviewers available' -and $s1.Out.Trim() -eq $h1) $h1
    $rA = Write-Roster 'hook-agy' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"' + $agyModel + '"},{"provider":"gemini","engine":"agy","model":"gemini-3.1-pro-high","panel":"weighty"},{"provider":"openai","model":"gpt-5.1"}]}')
    $mlog = Join-Path $work 'hook-models.log'
    $h2 = Hook $r $rA @{ FAKE_AGY_MODELS_LOG = $mlog }
    Check 'HOOK' 'the agy sign-in is not checked by the hook (-NoNetwork: no `agy models` call): "codex-consult: not checked - gemini :: * (sign-in not checked); 1 of 3 reviewers available, 0 out, 2 not checked" - the weighty entry is judged too' ($h2 -eq 'codex-consult: not checked - gemini :: * (sign-in not checked); 1 of 3 reviewers available, 0 out, 2 not checked' -and -not (Test-Path $mlog)) $h2
    $rU = New-Repo 'hook-usable'
    Seed-Ledger $rU 'other' @((New-Entry 1 'gemini' $agyModel $agyFp 'agy' ([DateTimeOffset]::Now.AddMinutes(-5))))
    $h3 = Hook $rU $rA
    Check 'HOOK' '... a usable agy reply in THIS repository''s ledgers within the last 60 minutes evidences the sign-in: "codex-consult: all 3 reviewers available"' ($h3 -eq 'codex-consult: all 3 reviewers available') $h3
    $h4 = Hook $r $rosterMuse @{ META_API_KEY = 'not-a-real-key' }
    Check 'HOOK' 'the muse billing guard (local): META_API_KEY set -> "codex-consult: out - meta :: muse-spark-1.3 (refused: META_API_KEY is set); 0 of 1 reviewer available" (the key''s value is never shown)' ($h4 -eq 'codex-consult: out - meta :: muse-spark-1.3 (refused: META_API_KEY is set); 0 of 1 reviewer available' -and $h4 -notmatch 'not-a-real-key') $h4
    $h5 = Hook $r ''
    $s5 = Providers $r '' @('-Short')
    Check 'HOOK' 'no roster: the providers of the Codex config - "codex-consult: out - mimo (env RT_MIMO_KEY not set); 3 of 4 providers available (no reviewer roster)" (hook and -Short)' ($h5 -eq 'codex-consult: out - mimo (env RT_MIMO_KEY not set); 3 of 4 providers available (no reviewer roster)' -and $s5.Out.Trim() -eq $h5) $h5
    $bad = Write-Roster 'hook-bad' '{"roster_version":1,"reviewers":[]}'
    $h6 = Hook $r $bad
    Check 'HOOK' 'an unusable roster: one line "codex-consult: reviewer check failed - <why>", exit 0 (the session never fails)' ($h6 -match '^codex-consult: reviewer check failed - codex-providers: ' -and ($h6 -split "`n").Count -eq 1) $h6
    $sp2 = Providers $r $rosterCodex @('-Short', '-Provider', 'ZAI')
    Check 'HOOK' '-Short with -Provider is refused (the line is about every reviewer)' ($sp2.Code -eq 1 -and $sp2.Out -match '-Short summarizes every reviewer') $sp2.Out
}

# =============================================================== DEFAULTS: per-purpose default timeouts, timeout_source, the continuation budget (T1)
if (Want 'DEFAULTS') {
    $r = New-Repo 'defaults'
    $got = New-Object System.Collections.Generic.List[string]
    foreach ($p in @('', 'chore', 'checkpoint', 'framing', 'decision', 'diff-review', 'core-contract', 'stuck', 'acceptance')) {
        $a = @('-DryRun', '-Prompt', 'x')
        if ($p) { $a += @('-Purpose', $p) }
        $d = Consult $r '' $a
        $got.Add("$(if ($p) { $p } else { 'none' })=$($d.Preview.timeout_sec)/$($d.Preview.timeout_source)/$($d.Preview.continue_sec)")
        if ($p -eq 'diff-review') { $dr = $d }
    }
    $expD = 'none=900/purpose/900 chore=600/purpose/600 checkpoint=900/purpose/900 framing=1800/purpose/900 decision=1800/purpose/900 diff-review=2400/purpose/900 core-contract=2400/purpose/900 stuck=2400/purpose/900 acceptance=3600/purpose/900'
    Check 'DEFAULTS' 'T1 -TimeoutSec unset -> the purpose''s default (chore 600, checkpoint and none 900, framing and decision 1800, diff-review, core-contract and stuck 2400, acceptance 3600), timeout_source purpose, continue_sec = min(timeout, 900)' (($got.ToArray() -join ' ') -eq $expD) ($got.ToArray() -join ' ')
    Check 'DEFAULTS' '... the dry run says which applied: "timeout     : 2400 s (the default of purpose diff-review; -TimeoutSec overrides); continuation after a timeout kill: one turn of up to 900 s on the same thread (-ContinueSec; 0 = off)"' ((Line $dr.Out 'timeout     :') -eq 'timeout     : 2400 s (the default of purpose diff-review; -TimeoutSec overrides); continuation after a timeout kill: one turn of up to 900 s on the same thread (-ContinueSec; 0 = off)') (Line $dr.Out 'timeout     :')
    $e1 = Consult $r '' @('-DryRun', '-Prompt', 'x', '-Purpose', 'acceptance', '-TimeoutSec', '1234')
    $e2 = Consult $r '' @('-DryRun', '-Prompt', 'x', '-TimeoutSec', '300')
    $e3 = Consult $r '' @('-DryRun', '-Prompt', 'x', '-ContinueSec', '0')
    $e4 = Consult $r '' @('-DryRun', '-Prompt', 'x', '-Purpose', 'framing', '-ContinueSec', '120')
    $e5 = Consult $r '' @('-DryRun', '-Prompt', 'x', '-ContinueSec', '-2')
    Check 'DEFAULTS' 'an explicit -TimeoutSec always wins (acceptance with 1234 -> 1234, explicit); the continuation budget follows it (300 -> 300); -ContinueSec 0 = off (the dry run says so), 120 = 120; a negative -ContinueSec is refused' ($e1.Preview.timeout_sec -eq 1234 -and $e1.Preview.timeout_source -eq 'explicit' -and $e1.Preview.continue_sec -eq 900 -and $e2.Preview.continue_sec -eq 300 -and $e3.Preview.continue_sec -eq 0 -and (Line $e3.Out 'timeout     :') -match 'continuation after a timeout kill: off \(-ContinueSec 0\)$' -and $e4.Preview.timeout_sec -eq 1800 -and $e4.Preview.continue_sec -eq 120 -and $e5.Code -eq 1 -and $e5.First -match '-ContinueSec must be 0') "$($e5.First)"
    $pd = Consult $r $rosterCodex @('-Panel', '-DryRun', '-Prompt', 'x', '-Purpose', 'acceptance')
    $pe = Consult $r $rosterCodex @('-Panel', '-DryRun', '-Prompt', 'x', '-Purpose', 'acceptance', '-TimeoutSec', '700', '-ContinueSec', '60')
    Check 'DEFAULTS' 'a panel resolves the timeout once and its members inherit it: "Timeout: 3600 s per member (the default of purpose acceptance); continuation after a timeout kill: up to 900 s on the same thread"; both members'' previews say 3600/purpose; with -TimeoutSec 700 -ContinueSec 60: 700/explicit/60' ($pd.Code -eq 0 -and $pd.Out.Contains('Timeout: 3600 s per member (the default of purpose acceptance); continuation after a timeout kill: up to 900 s on the same thread') -and ([regex]::Matches($pd.Out, '"timeout_sec":\s+3600,').Count -eq 2) -and ([regex]::Matches($pd.Out, '"timeout_source":\s+"purpose",').Count -eq 2) -and ([regex]::Matches($pe.Out, '"timeout_sec":\s+700,').Count -eq 2) -and ([regex]::Matches($pe.Out, '"timeout_source":\s+"explicit",').Count -eq 2) -and ([regex]::Matches($pe.Out, '"continue_sec":\s+60,').Count -eq 2)) (Line $pd.Out 'Timeout:')
}

# =============================================================== RANGE: -Range, its numbers and the size warning (T1)
if (Want 'RANGE') {
    $r = New-Repo 'range'
    [IO.File]::WriteAllText((Join-Path $r 'small.txt'), "a`nb`nc`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'small')
    [IO.File]::WriteAllText((Join-Path $r 'big.txt'), ((1..1600 | ForEach-Object { "line $_" }) -join "`n") + "`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'big')
    $d = Consult $r '' @('-DryRun', '-Prompt', 'x', '-Purpose', 'diff-review', '-Range', 'HEAD~2..HEAD~1')
    Check 'RANGE' 'dry run: "range       : HEAD~2..HEAD~1 - the range changes 1 file, 3 lines (3 insertions, 0 deletions)"; the prompt names it ("Review range: `HEAD~2..HEAD~1` - the range changes 1 file, 3 lines ..."); ledger range {spec, files 1, insertions 3, deletions 0, lines 3}; no warning' ($d.Code -eq 0 -and (Line $d.Out 'range       :') -eq 'range       : HEAD~2..HEAD~1 - the range changes 1 file, 3 lines (3 insertions, 0 deletions)' -and $d.Out.Contains('Review range: `HEAD~2..HEAD~1` - the range changes 1 file, 3 lines (3 insertions, 0 deletions; git diff --shortstat). Plan your reading for its size.') -and $d.Preview.range.spec -eq 'HEAD~2..HEAD~1' -and $d.Preview.range.files -eq 1 -and $d.Preview.range.lines -eq 3 -and $d.Out -notmatch 'WARNING: a range') (Line $d.Out 'range       :')
    $dw = Consult $r '' @('-DryRun', '-Prompt', 'x', '-Purpose', 'diff-review', '-Range', 'HEAD~1..HEAD', '-TimeoutSec', '900')
    $dn = Consult $r '' @('-DryRun', '-Prompt', 'x', '-Purpose', 'diff-review', '-Range', 'HEAD~1..HEAD')
    $warn = 'a range of 1600 lines with a 900 s timeout: pass -TimeoutSec or a reading plan in the brief'
    Check 'RANGE' 'T1 a range of 1600 lines with -TimeoutSec 900 WARNS ("WARNING: a range of 1600 lines with a 900 s timeout: pass -TimeoutSec or a reading plan in the brief", ledger warnings[]); with the diff-review default (2400 s) it does not' ($dw.Code -eq 0 -and $dw.Out.Contains("WARNING: $warn") -and @($dw.Preview.warnings) -contains $warn -and $dn.Code -eq 0 -and $dn.Out -notmatch 'WARNING: a range' -and @($dn.Preview.warnings).Count -eq 0) (Line $dw.Out 'WARNING:')
    $acc = Reply 'accept.json' '{"schema_version":"1","verdict":"ACCEPT","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
    $x = Consult $r '' @('-Prompt', 'x', '-Purpose', 'acceptance', '-Range', 'HEAD~1..HEAD', '-TimeoutSec', '600', '-ReplyName', 'rng') @{ FAKE_CODEX_REPLY = $acc }
    $e = Last-Entry $r
    $md = Text (Td $r $e.reply)
    Check 'RANGE' 'a real run records range {HEAD~1..HEAD, 1 file, 1600 insertions, 0 deletions, 1600 lines}, the warning in warnings[], timeout_sec 600 / explicit; the handoff header: "Warnings: a range of 1600 lines ..." and "Timeout: 600 s (-TimeoutSec); ... Range: `HEAD~1..HEAD` - the range changes 1 file, 1600 lines (1600 insertions, 0 deletions)."' ($x.Code -eq 0 -and $e.range.spec -eq 'HEAD~1..HEAD' -and $e.range.files -eq 1 -and $e.range.insertions -eq 1600 -and $e.range.deletions -eq 0 -and $e.range.lines -eq 1600 -and @($e.warnings) -contains 'a range of 1600 lines with a 600 s timeout: pass -TimeoutSec or a reading plan in the brief' -and $e.timeout_sec -eq 600 -and $e.timeout_source -eq 'explicit' -and $md -match '(?m)^Warnings: a range of 1600 lines with a 600 s timeout' -and $md.Contains('Timeout: 600 s (-TimeoutSec); continuation after a timeout kill: up to 600 s. Range: `HEAD~1..HEAD` - the range changes 1 file, 1600 lines (1600 insertions, 0 deletions).')) "$($x.First)"
    $n0 = @(Ledger $r).Count
    $u = Consult $r '' @('-Prompt', 'x', '-Purpose', 'diff-review', '-Range', 'nope..HEAD') @{ FAKE_CODEX_REPLY = $acc }
    $wp = Consult $r '' @('-Prompt', 'x', '-Purpose', 'checkpoint', '-Range', 'HEAD~1..HEAD') @{ FAKE_CODEX_REPLY = $acc }
    Check 'RANGE' 'an unknown range is refused before anything starts ("-Range ''nope..HEAD'' is not a revision range git knows in <root> (git diff --shortstat: fatal: ...); nothing was started.", no ledger entry); -Range with a purpose other than diff-review or acceptance is refused' ($u.Code -eq 1 -and $u.First -match "^codex-consult: -Range 'nope\.\.HEAD' is not a revision range git knows in .* \(git diff --shortstat: fatal: .*\); nothing was started\.$" -and $wp.Code -eq 1 -and $wp.First -match '-Range goes with -Purpose diff-review or acceptance' -and @(Ledger $r).Count -eq $n0) "$($u.First) | $($wp.First)"
    $pw = Consult $r $rosterCodex @('-Panel', '-DryRun', '-Prompt', 'x', '-Purpose', 'diff-review', '-Range', 'HEAD~1..HEAD', '-TimeoutSec', '900')
    Check 'RANGE' 'a panel measures the range once: "Range: HEAD~1..HEAD - the range changes 1 file, 1600 lines (1600 insertions, 0 deletions)" and one WARNING; both members'' previews carry the range and the warning' ($pw.Code -eq 0 -and $pw.Out.Contains('Range: HEAD~1..HEAD - the range changes 1 file, 1600 lines (1600 insertions, 0 deletions)') -and ([regex]::Matches($pw.Out, '"lines":\s+1600').Count -eq 2) -and ([regex]::Matches($pw.Out, [regex]::Escape($warn)).Count -ge 3)) (Line $pw.Out 'Range:')
}

# =============================================================== CONT: the codex timeout continuation and the salvage (T1)
if (Want 'CONT') {
    $r = New-Repo 'cont-codex'
    # (a) the main turn hangs, the continuation answers
    $rlog = Join-Path $work 'cont-resume.log'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'ok', '-TimeoutSec', '5') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_RESUME_REPLY = $adviseF; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_ITEMS = '1'; FAKE_CODEX_RESUME_LOG = $rlog }
    $e = Last-Entry $r
    $tc = $e.timeout_continue
    $rl = Text $rlog
    $md = Text (Td $r $e.reply)
    Check 'CONT' 'T1 codex: the main turn hangs, the bridge kills it at 5 s and runs ONE continuation on its thread (`exec ... resume <thread> -` with the main turn''s options, --output-schema included); the reply is ingested like a first-turn reply - "usable reply (after a timeout continuation)", verdict ADVISE, finding F01-1' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $e.verdict -eq 'ADVISE' -and (@($e.finding_ids) -join ',') -eq 'F01-1' -and $e.thread -match $uuidRe -and $rl -match ('(?m)^ARGS: exec --sandbox read-only --color never --json -m gpt-5\.1 .*--output-schema .* resume ' + [regex]::Escape($e.thread) + ' -\s*$')) "$($e.bridge_outcome) | $((($rl -split "`n") | Select-Object -First 1))"
    Check 'CONT' '... the continuation prompt: the output contract, "Your previous turn was stopped by a time limit after 5 s. Do not start over and do not read more files than you must: finish now and output your final answer in the required format.", the consultation id - never the brief' ($rl.Contains('Your previous turn was stopped by a time limit after 5 s. Do not start over and do not read more files than you must: finish now and output your final answer in the required format.') -and $rl.Contains('FINAL OUTPUT CONTRACT') -and $rl.Contains("Consultation id: $($e.consult_id)")) ''
    Check 'CONT' '... ledger timeout_continue {thread = the run''s thread, wall_seconds, outcome "usable reply", events handoffs/01-codex-ok.continue.events.jsonl (kept), usage}; partial_reply ""; timeout_sec 5 explicit, continue_sec 5; the summary "continued  : the main turn was killed at <t> s of 5 s; one continuation turn on thread <id> answered in <w> s"; the handoff header says so' ($tc.thread -eq $e.thread -and $tc.outcome -eq 'usable reply' -and $tc.wall_seconds -gt 0 -and $tc.events -eq 'handoffs/01-codex-ok.continue.events.jsonl' -and (Test-Path (Td $r $tc.events)) -and $null -ne $tc.usage -and $e.partial_reply -eq '' -and $e.timeout_sec -eq 5 -and $e.timeout_source -eq 'explicit' -and $e.continue_sec -eq 5 -and $x.Out -match ('(?m)^continued  : the main turn was killed at [0-9.]+ s of 5 s; one continuation turn on thread ' + [regex]::Escape($e.thread) + ' answered in [0-9.]+ s$') -and $md -match '(?m)^Timeout continuation: the main turn was killed at [0-9.]+ s of 5 s; one continuation turn on thread `' -and $md -match '(?m)^Bridge outcome: usable reply \(after a timeout continuation\)\.' -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) (Line $x.Out 'continued')
    # (b) the continuation hangs too: the salvage from BOTH turns and the exact resume command
    $y = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'hh', '-TimeoutSec', '4', '-Purpose', 'checkpoint', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json'; FAKE_CODEX_ITEMS = '1' }
    $e2 = Last-Entry $r
    $pp = Td $r $e2.partial_reply
    $pt = Text $pp
    $resumeArgs = "-Task t -Mode resume -Thread $($e2.thread) -Provider openai -Model gpt-5.1 -Purpose checkpoint -ReplyName hh -TimeoutSec 4 -Prompt ""finish your review"""
    Check 'CONT' 'T1 the continuation hangs too: bridge_outcome stays "failed: timeout after 4 s (process tree killed)"; timeout_continue.outcome "failed: timeout after 4 s (process tree killed)"; partial_reply = handoffs/02-codex-hh.partial.md (right after events in the ledger); exit 1; no recovery record left' ($y.Code -eq 1 -and $e2.bridge_outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e2.timeout_continue.outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e2.partial_reply -eq 'handoffs/02-codex-hh.partial.md' -and (Test-Path $pp) -and ((@($e2.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match 'reply_json,events,partial_reply,model') -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) "$($e2.bridge_outcome) | $($e2.partial_reply)"
    Check 'CONT' '... the partial file: the reply''s header ("Bridge outcome: failed: timeout ..."), "## Turn 1 - the main turn - killed at <t> s of 4 s" with its reasoning, agent message and the shell command line, "## Turn 2 - the timeout continuation - killed at ...", then the footer "killed at ... ; thread <id> - continue with `-Task t -Mode resume -Thread <id> -Provider openai -Model gpt-5.1 -Purpose checkpoint -ReplyName hh -TimeoutSec 4 -Prompt "finish your review"`" (no roster: the reviewer is named; wave 24b: the explicit -TimeoutSec too; wave 24c: the -ReplyName given)' ($pt -match '(?m)^# Handoff 02 - Codex: hh - partial reply \(a turn was killed on its timeout\)$' -and $pt -match '(?m)^Bridge outcome: failed: timeout after 4 s \(process tree killed\)\.' -and $pt -match '(?m)^## Turn 1 - the main turn - killed at [0-9.]+ s of 4 s$' -and $pt.Contains('Reading the brief (first turn).') -and $pt.Contains('Q1 so far (first turn): the change looks consistent.') -and $pt.Contains('- `shell: git diff --stat HEAD~1 (first)`') -and $pt -match '(?m)^## Turn 2 - the timeout continuation - killed at [0-9.]+ s of 4 s$' -and $pt.Contains('Reading the brief (resume turn).') -and $pt.TrimEnd().EndsWith("; thread $($e2.thread) - continue with ``$resumeArgs``")) (($pt.TrimEnd() -split "`n") | Select-Object -Last 1)
    Check 'CONT' '... the summary prints the partial file and the exact manual resume command ("resume     : powershell|pwsh ... -File "<codex-consult.ps1>" -Task t -Mode resume -Thread <id> ..."); the handoff names it ("Partial reply: `handoffs/02-codex-hh.partial.md` - killed at ...")' ($y.Out -match ('(?m)^partial    : .*02-codex-hh\.partial\.md \(killed at ') -and $y.Out.Contains("resume     : ") -and $y.Out.Contains("-File ""$consultPs"" $resumeArgs") -and (Text (Td $r $e2.reply)) -match '(?m)^Partial reply: `handoffs/02-codex-hh\.partial\.md` - killed at ') (Line $y.Out 'resume')
    # (c) the manual resume command works: the killed thread continues (a fork-free resume)
    $z = Consult $r '' @('-Mode', 'resume', '-Thread', $e2.thread, '-Provider', 'openai', '-Model', 'gpt-5.1', '-Purpose', 'checkpoint', '-Prompt', 'finish your review', '-ReplyName', 'resumed') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise }
    $e3 = Last-Entry $r
    Check 'CONT' '... running that command resumes the killed thread: mode resume, parent = result thread = the killed thread, usable reply' ($z.Code -eq 0 -and $e3.mode -eq 'resume' -and $e3.parent_thread -eq $e2.thread -and $e3.thread -eq $e2.thread -and $e3.bridge_outcome -eq 'usable reply') "$($z.First)"
    # (d) -ContinueSec 0: no continuation, the salvage of the main turn
    $w = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'off', '-TimeoutSec', '4', '-ContinueSec', '0', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json'; FAKE_CODEX_ITEMS = '1' }
    $e4 = Last-Entry $r
    $pt4 = Text (Td $r $e4.partial_reply)
    Check 'CONT' '-ContinueSec 0: no continuation (timeout_continue {outcome "not attempted: -ContinueSec 0", wall 0, events null}), the partial file holds the main turn only and its footer "killed at <t> s of 4 s; thread <id> - continue with ..."' ($w.Code -eq 1 -and $e4.timeout_continue.outcome -eq 'not attempted: -ContinueSec 0' -and $e4.timeout_continue.wall_seconds -eq 0 -and $null -eq $e4.timeout_continue.events -and $pt4 -match '(?m)^## Turn 1 - the main turn' -and $pt4 -notmatch '## Turn 2' -and $pt4.TrimEnd() -match ('killed at [0-9.]+ s of 4 s; thread ' + [regex]::Escape($e4.thread) + ' - continue with `')) $e4.timeout_continue.outcome
    # (e) the killed turn's own stream names a usage limit: never a continuation after a quota failure
    # (a repository of its own: that usage limit names no reset time, so it keeps the endpoint out
    # for 60 minutes - every later run on it in the same repository would be refused, wave 24b)
    $rv = New-Repo 'cont-codex-quota'
    $v = Consult $rv '' @('-Prompt', 'x', '-ReplyName', 'quota', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json'; FAKE_CODEX_PRELINE = '{"type":"error","message":"You have hit your usage limit. Try again later."}' }
    $e5 = Last-Entry $rv
    Check 'CONT' 'never a continuation after a quota failure: the killed turn''s stream says "usage limit" -> timeout_continue.outcome "not attempted: the killed turn reported a quota failure (...)"; the salvage is written' ($v.Code -eq 1 -and $e5.timeout_continue.outcome -match '^not attempted: the killed turn reported a quota failure \(' -and $e5.partial_reply -match '^handoffs/\d\d-codex-quota\.partial\.md$') $e5.timeout_continue.outcome
    # (g) the format repair turn killed on its timeout (codex: `exec ... resume <thread>` hangs)
    $g = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'rep', '-TimeoutSec', '5', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_HANG_ON = ' resume '; FAKE_CODEX_ITEMS = '1' }
    $e7 = Last-Entry $r
    $pt7 = Text (Td $r $e7.partial_reply)
    Check 'CONT' 'T1 codex, a format repair killed on its timeout (min(5, 300) s): the prose stays the usable reply (format_retry.succeeded false), no continuation (the main turn was not killed), the partial file has the main turn and "## Turn 2 - the format repair - killed at <t> s of 5 s" with its salvaged text; the summary prints it and the resume command' ($g.Code -eq 0 -and $e7.bridge_outcome -eq 'usable reply' -and $e7.format_retry.succeeded -eq $false -and $null -eq $e7.timeout_continue -and $e7.partial_reply -match '-codex-rep\.partial\.md$' -and $pt7 -match '(?m)^## Turn 1 - the main turn - it ended by itself$' -and $pt7 -match '(?m)^## Turn 2 - the format repair - killed at [0-9.]+ s of 5 s$' -and $pt7.Contains('Reading the brief (resume turn).') -and $g.Out -match '(?m)^partial    : ' -and $g.Out -match ('(?m)^resume     : .* -Mode resume -Thread ' + [regex]::Escape($e7.thread))) "$($e7.partial_reply)"
    # (f) surviving processes: no continuation on a thread a killed process may still write
    $pidFile = Join-Path $work 'cont-surv.pid'
    $keeper = Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 30' -PassThru -WindowStyle Hidden
    $sv = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'surv', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json'; CODEX_CONSULT_TEST_SURVIVORS = [string]$keeper.Id }
    $e6 = Last-Entry $r
    try { Stop-Process -Id $keeper.Id -Force -ErrorAction SilentlyContinue } catch { }
    Start-Sleep -Milliseconds 500
    Remove-Item (Join-Path $r '.collab\t\.consult.pending.json') -ErrorAction SilentlyContinue
    Check 'CONT' 'surviving processes after the kill: no continuation (timeout_continue.outcome "not attempted: 1 process(es) survived the kill")' ($sv.Code -eq 1 -and $e6.timeout_continue.outcome -eq 'not attempted: 1 process(es) survived the kill') $e6.timeout_continue.outcome
    $sb = & $psExe -NoProfile -ExecutionPolicy Bypass -File $scoreboardPs -CollabDir (Join-Path $r '.collab') -Task t -Json 2>&1
    $rows = @(((($sb | ForEach-Object { "$_" }) -join "`n") | ConvertFrom-Json) | ForEach-Object { $_ })
    $tot = @($rows | Where-Object { $_.kind -eq 'total' }) | Select-Object -Last 1
    $wantUsable = @(Ledger $r | Where-Object { Test-UsableOutcome ([string]$_.bridge_outcome) }).Count
    Check 'CONT' 'the scoreboard counts a reply after a timeout continuation as usable (USABLE = the usable entries, 3 of the 6 runs)' ($tot -and [int]$tot.usable -eq $wantUsable -and $wantUsable -eq 3) "usable=$($tot.usable) want=$wantUsable"
}

# =============================================================== CONTAGY: the agy continuation, the salvage of a denial retry and a format repair (T1)
if (Want 'CONTAGY') {
    $r = New-Repo 'cont-agy'
    $rlog = Join-Path $work 'agy-resume.log'
    $x = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'ok', '-TimeoutSec', '6') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_RESUME_REPLY = $advise; FAKE_AGY_HANG = 'new'; FAKE_AGY_TEXT = '1'; FAKE_AGY_RESUME_LOG = $rlog }
    $e = Last-Entry $r
    $rl = Text $rlog
    Check 'CONTAGY' 'T1 agy: the main turn hangs after its init event; ONE continuation on that conversation (--conversation <init id>) answers; the conversation is verified by it (ledger thread = timeout_continue.thread, no candidate), "usable reply (after a timeout continuation)", engine_run.turns 2; its prompt travels on stdin (the finish-now sentence)' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $e.thread -match $uuidRe -and $e.thread -eq $e.timeout_continue.thread -and $e.thread_candidate -eq '' -and $e.thread_source -eq 'events' -and $e.engine_run.turns -eq 2 -and $e.timeout_continue.outcome -eq 'usable reply' -and $rl -match ('--conversation ' + [regex]::Escape($e.thread)) -and $rl.Contains('Your previous turn was stopped by a time limit after 6 s.')) "$($e.bridge_outcome) turns=$($e.engine_run.turns)"
    $y = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'hh', '-TimeoutSec', '5') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_HANG = '1'; FAKE_AGY_TEXT = '1' }
    $e2 = Last-Entry $r
    $pt = Text (Td $r $e2.partial_reply)
    Check 'CONTAGY' 'T1 agy, the continuation hangs too: failed (timeout), the conversation stays a candidate (= timeout_continue.thread); the partial file salvages both turns (the text_delta message, "run_command: git log -1 (first)", the resume turn''s text) and names the conversation to resume (a roster: no -Provider needed)' ($y.Code -eq 1 -and $e2.bridge_outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $e2.thread -eq '' -and $e2.thread_candidate -match $uuidRe -and $e2.thread_candidate -eq $e2.timeout_continue.thread -and $pt.Contains('Reading the brief (first turn).') -and $pt.Contains('- `run_command: git log -1 (first)`') -and $pt.Contains('Reading the brief (resume turn).') -and $pt.TrimEnd().EndsWith("; thread $($e2.thread_candidate) - continue with ``-Task t -Mode resume -Thread $($e2.thread_candidate) -ReplyName hh -TimeoutSec 5 -Prompt ""finish your review""``")) (($pt.TrimEnd() -split "`n") | Select-Object -Last 1)
    $z = Consult $r $rosterAgy @('-Mode', 'resume', '-Thread', $e2.thread_candidate, '-Prompt', 'finish your review', '-ReplyName', 'resumed') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_RESUME_REPLY = $advise }
    $e3 = Last-Entry $r
    Check 'CONTAGY' '... the manual resume of that conversation works (-Thread takes the killed run''s own conversation): mode resume, thread = the conversation, usable reply' ($z.Code -eq 0 -and $e3.mode -eq 'resume' -and $e3.thread -eq $e2.thread_candidate -and $e3.bridge_outcome -eq 'usable reply') "$($z.First)"
    # the denial retry killed on its timeout
    $d = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'den', '-TimeoutSec', '5') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_DENIED = '1'; FAKE_AGY_HANG_ON = '--conversation' }
    $e4 = Last-Entry $r
    $pt4 = Text (Td $r $e4.partial_reply)
    Check 'CONTAGY' 'T1 a denial retry killed on its timeout: bridge_outcome "... (denial retry failed: timeout after 5 s ...)", no continuation (the main turn was not killed: timeout_continue null), the partial file has "## Turn 2 - the denial retry - killed at <t> s of 5 s" and the footer names the conversation' ($d.Code -eq 1 -and $e4.bridge_outcome -match '\(denial retry failed: timeout after 5 s \(process tree killed\)\)$' -and $null -eq $e4.timeout_continue -and $e4.partial_reply -match '-agy-den\.partial\.md$' -and $pt4 -match '(?m)^## Turn 2 - the denial retry - killed at [0-9.]+ s of 5 s$' -and $pt4.TrimEnd() -match ('- continue with `-Task t -Mode resume -Thread ' + [regex]::Escape($e4.thread))) "$($e4.bridge_outcome)"
    # the format repair killed on its timeout
    $f = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'rep', '-TimeoutSec', '5') @{ FAKE_AGY_REPLY = $proseFile; FAKE_AGY_NOSTRUCTURED = '1'; FAKE_AGY_HANG_ON = '--conversation' }
    $e5 = Last-Entry $r
    $pt5 = Text (Td $r $e5.partial_reply)
    Check 'CONTAGY' 'T1 a format repair killed on its timeout: the prose reply stays usable (bridge_outcome "usable reply", format_retry.succeeded false), the partial file has "## Turn 2 - the format repair - killed at <t> s of 5 s"; the summary prints it and the resume command' ($f.Code -eq 0 -and $e5.bridge_outcome -eq 'usable reply' -and $e5.format_retry.succeeded -eq $false -and $e5.partial_reply -match '-agy-rep\.partial\.md$' -and $pt5 -match '(?m)^## Turn 2 - the format repair - killed at [0-9.]+ s of 5 s$' -and $f.Out -match '(?m)^partial    : ' -and $f.Out -match '(?m)^resume     : .* -Mode resume -Thread ') "$($e5.bridge_outcome) | $($e5.partial_reply)"
}

# =============================================================== CONTMUSE: the muse continuation, F15-1, a killed repair (T1)
if (Want 'CONTMUSE') {
    $r = New-Repo 'cont-muse'
    $rlog = Join-Path $work 'muse-resume.log'
    $x = Consult $r $rosterMuse @('-Prompt', 'x', '-ReplyName', 'ok', '-TimeoutSec', '6') @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_RESUME_REPLY = $advise; FAKE_MUSE_HANG = 'new'; FAKE_MUSE_TEXT = '1'; FAKE_MUSE_RESUME_LOG = $rlog }
    $e = Last-Entry $r
    $rl = Text $rlog
    Check 'CONTMUSE' 'T1 muse: the main turn hangs; ONE continuation on its session (--session-id <session>, its own prompt file) answers: "usable reply (after a timeout continuation)", the session verified (thread = timeout_continue.thread), engine_run.turns 2 (two subscription prompts)' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $e.thread -match $uuidRe -and $e.thread -eq $e.timeout_continue.thread -and $e.engine_run.turns -eq 2 -and $rl -match ('(?m)^ARG: ' + [regex]::Escape($e.thread) + '$') -and $rl.Contains('Your previous turn was stopped by a time limit after 6 s.')) "$($e.bridge_outcome) turns=$($e.engine_run.turns)"
    $y = Consult $r $rosterMuse @('-Prompt', 'x', '-ReplyName', 'hh', '-TimeoutSec', '5') @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_HANG = '1'; FAKE_MUSE_TEXT = '1' }
    $e2 = Last-Entry $r
    $pt = Text (Td $r $e2.partial_reply)
    Check 'CONTMUSE' 'T1 muse, the continuation hangs too: failed (timeout), the partial file salvages both turns (the run.output.delta texts, the "search" tool task) and names the session' ($y.Code -eq 1 -and $e2.bridge_outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $e2.timeout_continue.outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $pt.Contains('Notes so far (first turn).') -and $pt.Contains('- `search`') -and $pt.Contains('Notes so far (resume turn).') -and $pt.TrimEnd() -match ('- continue with `-Task t -Mode resume -Thread ' + [regex]::Escape($e2.timeout_continue.thread))) "$($e2.partial_reply)"
    # F15-1: auth.json turns into an api_key sign-in while the main turn runs: the continuation's
    # launch guard reads it again and refuses - nothing is started
    $count = Join-Path $work 'muse-count.log'
    $pend = Join-Path $r '.collab\t\.consult.pending.json'
    Set-CaseEnv $rosterMuse @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_RESUME_REPLY = $advise; FAKE_MUSE_HANG = 'new'; FAKE_MUSE_COUNT = $count }
    $bg = Start-Process -FilePath $psExe -WorkingDirectory $r -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-Prompt', 'x', '-ReplyName', 'billing', '-TimeoutSec', '8')
    Restore-Env
    $seen = $false
    for ($i = 0; $i -lt 120; $i++) { $pr = Read-PendingFile -Path $pend; if ($pr.Record -and $pr.Record.state -eq 'running' -and (Test-Path $count)) { $seen = $true; break }; Start-Sleep -Milliseconds 250 }
    Write-Auth $authApiKey
    $bg.WaitForExit()
    Write-Auth $authOauth
    $e3 = Last-Entry $r
    Check 'CONTMUSE' 'F15-1: auth.json changed to an api_key sign-in while the main turn ran -> the continuation''s launch guard re-reads it and refuses before launch (timeout_continue.outcome "failed: refused before launch: the Muse sign-in ... uses mechanism ''api_key'', not oauth ..."), nothing started (one exec, engine_run.turns 1)' ($seen -and $e3.reply -match '-muse-billing\.md$' -and $e3.timeout_continue.outcome -match "^failed: refused before launch: the Muse sign-in in ~/\.config/muse/auth\.json uses mechanism 'api_key', not oauth" -and $e3.engine_run.turns -eq 1 -and @(Get-Content $count).Count -eq 1) "$($e3.timeout_continue.outcome)"
    $f = Consult $r $rosterMuse @('-Prompt', 'x', '-ReplyName', 'rep', '-TimeoutSec', '5') @{ FAKE_MUSE_REPLY = $proseFile; FAKE_MUSE_HANG = 'resume' }
    $e4 = Last-Entry $r
    $pt4 = Text (Td $r $e4.partial_reply)
    Check 'CONTMUSE' 'T1 a muse format repair killed on its timeout: the prose stays the usable reply, "## Turn 2 - the format repair - killed at <t> s of 5 s" in the partial file' ($f.Code -eq 0 -and $e4.bridge_outcome -eq 'usable reply' -and $e4.format_retry.succeeded -eq $false -and $pt4 -match '(?m)^## Turn 2 - the format repair - killed at [0-9.]+ s of 5 s$') "$($e4.partial_reply)"
}

# =============================================================== GATES: wave 24b end to end - the continuation's gates, its failure, the resume command, the main launch guard
if (Want 'GATES') {
    # --- F08-2: codex, a workspace-write run that changed a tracked file is never continued
    $rg = New-Repo 'gates-tree'
    $rlogT = Join-Path $work 'gates-tree-resume.log'
    $x = Consult $rg '' @('-Prompt', 'x', '-ReplyName', 'tree', '-TimeoutSec', '4', '-Mode', 'new', '-Sandbox', 'workspace-write') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_WRITE = 'app.txt'; FAKE_CODEX_RESUME_LOG = $rlogT }
    $e = Last-Entry $rg
    Check 'GATES' 'F08-2 codex -Sandbox workspace-write: the killed main turn wrote a tracked file -> NO continuation (timeout_continue.outcome "not attempted: files changed during the run (the working tree)", no resume turn started), tree_changed_during_review true, the salvage is written; exit 1' ($x.Code -eq 1 -and $e.timeout_continue.outcome -eq 'not attempted: files changed during the run (the working tree)' -and -not (Test-Path $rlogT) -and $e.tree_changed_during_review -eq $true -and $e.partial_reply -match '^handoffs/01-codex-tree\.partial\.md$') "$($e.timeout_continue.outcome)"
    # --- F08-3: billing wording only on the killed turn's stderr (codex) / next to its result (agy)
    $rb = New-Repo 'gates-billing'
    $rlogB = Join-Path $work 'gates-billing-resume.log'
    $x = Consult $rb '' @('-Prompt', 'x', '-ReplyName', 'bill', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_STDERR_FIRST = 'ERROR: Insufficient balance: top up the prepaid plan to continue'; FAKE_CODEX_RESUME_LOG = $rlogB }
    $e = Last-Entry $rb
    Check 'GATES' 'F08-3 codex: the killed turn''s stderr says "ERROR: Insufficient balance: ..." (no word the old keyword filter knew; wave 24c: an ERROR-level line - a diagnostic one) -> NO continuation ("not attempted: the killed turn reported a quota failure (ERROR: Insufficient balance: ...)", no resume turn); provider_failure class quota' ($x.Code -eq 1 -and $e.timeout_continue.outcome -eq 'not attempted: the killed turn reported a quota failure (ERROR: Insufficient balance: top up the prepaid plan to continue)' -and -not (Test-Path $rlogB) -and $e.provider_failure.class -eq 'quota') "$($e.timeout_continue.outcome) | $($e.provider_failure.class)"
    $ra = New-Repo 'gates-agy'
    $rlogA = Join-Path $work 'gates-agy-resume.log'
    $x = Consult $ra $rosterAgy @('-Prompt', 'x', '-ReplyName', 'pay', '-TimeoutSec', '5') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_RESUME_REPLY = $advise; FAKE_AGY_HANG_AFTER = '1'; FAKE_AGY_STDERR = 'Payment required (402): the prepaid plan is exhausted'; FAKE_AGY_RESUME_LOG = $rlogA }
    $e = Last-Entry $ra
    Check 'GATES' 'F08-3 agy: the killed turn''s own evidence (its stderr, which the adapter keeps in its failure texts) names "Payment required (402)" -> NO continuation ("not attempted: the killed turn reported a quota failure (...)"), engine_run.turns 1, no --conversation turn started' ($x.Code -eq 1 -and $e.timeout_continue.outcome -match '^not attempted: the killed turn reported a quota failure \(Payment required \(402\)' -and $e.engine_run.turns -eq 1 -and -not (Test-Path $rlogA)) "$($e.timeout_continue.outcome)"
    # --- F08-4: a failure DURING the continuation is the run's provider_failure
    $rq = New-Repo 'gates-429'
    $x = Consult $rq '' @('-Prompt', 'x', '-ReplyName', 'c429', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_RESUME_FAIL = "You've hit your usage limit. Try again in 3 hours." }
    $e = Last-Entry $rq
    $pfWhen = [DateTimeOffset]::Parse([string]$e.provider_failure.when, $inv)
    $pfRa = $(if ($e.provider_failure.retry_after) { [DateTimeOffset]::Parse([string]$e.provider_failure.retry_after, $inv) } else { $null })
    $pv = Providers $rq '' @('-Provider', 'openai')
    Check 'GATES' 'F08-4 codex: the main turn times out, the continuation fails with "You''ve hit your usage limit. Try again in 3 hours." -> bridge_outcome stays "failed: timeout ...", timeout_continue.outcome "failed: codex exit 1 - You''ve hit ...", provider_failure = the CONTINUATION''s evidence: class quota, retry_after = its when + 3 h; the next availability check (codex-providers -Provider openai) reads it: exit 2, "unavailable (usage limit until <iso>)"' ($x.Code -eq 1 -and $e.bridge_outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e.timeout_continue.outcome -match "^failed: codex exit 1 - You've hit your usage limit" -and $e.provider_failure.class -eq 'quota' -and $e.provider_failure.message -eq "You've hit your usage limit. Try again in 3 hours." -and $null -ne $pfRa -and [Math]::Abs(($pfRa - $pfWhen.AddHours(3)).TotalSeconds) -le 2 -and $pv.Code -eq 2 -and $pv.Out -match '(?m)^unavailable \(usage limit until [^)]+\)\s+openai\s') "$($e.provider_failure.class) | $($e.provider_failure.retry_after) | providers exit $($pv.Code)"
    # (a separate repository: the quota the F08-3 case recorded keeps the agy endpoint out for 60 minutes)
    $ra4 = New-Repo 'gates-agy-429'
    $x = Consult $ra4 $rosterAgy @('-Prompt', 'x', '-ReplyName', 'cq', '-TimeoutSec', '5') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_HANG = 'new'; FAKE_AGY_STATUS = 'RESOURCE_EXHAUSTED'; FAKE_AGY_ERROR = 'Individual quota reached. Resets in 2h0m0s.' }
    $e = Last-Entry $ra4
    $pfWhen = [DateTimeOffset]::Parse([string]$e.provider_failure.when, $inv)
    $pfRa = $(if ($e.provider_failure.retry_after) { [DateTimeOffset]::Parse([string]$e.provider_failure.retry_after, $inv) } else { $null })
    Check 'GATES' 'F08-4 agy: the continuation (--conversation) answers RESOURCE_EXHAUSTED "Individual quota reached. Resets in 2h0m0s." -> provider_failure class quota with retry_after = its when + 2 h (the engine''s class and texts of the continuation), timeout_continue.outcome "failed: agy exit 1 - Individual quota reached. ..."' ($x.Code -eq 1 -and $e.provider_failure.class -eq 'quota' -and $null -ne $pfRa -and [Math]::Abs(($pfRa - $pfWhen.AddHours(2)).TotalSeconds) -le 2 -and $e.timeout_continue.outcome -match '^failed: agy exit 1 - Individual quota reached') "$($e.provider_failure.class) | $($e.provider_failure.retry_after) | $($e.timeout_continue.outcome)"
    # --- F08-5: a one-word continuation never replaces the killed turn's work
    $done = Reply 'done.txt' 'Done.'
    $rc = New-Repo 'gates-oneword'
    $x = Consult $rc '' @('-Prompt', 'x', '-ReplyName', 'one', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $done; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_ITEMS = '1' }
    $e = Last-Entry $rc
    $pt = Text (Td $rc $e.partial_reply)
    Check 'GATES' 'F08-5 codex: the continuation answers "Done." after a rich killed turn -> it does NOT count: timeout_continue.outcome "failed: not a usable reply - not a valid reply object (...) and reply too short (1 words)", bridge_outcome stays "failed: timeout ...", no .reply.json, the partial file keeps the main turn''s reasoning, message and command and shows the continuation''s turn; provider_failure stays the main turn''s (transport); exit 1' ($x.Code -eq 1 -and $e.bridge_outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e.timeout_continue.outcome -match '^failed: not a usable reply - not a valid reply object \(.+\) and reply too short \(1 words\); its text is kept in handoffs/01-codex-one\.partial\.md under "continuation reply \(rejected\)"$' -and $e.reply_json -eq '' -and $e.partial_reply -eq 'handoffs/01-codex-one.partial.md' -and $pt.Contains('Reading the brief (first turn).') -and $pt.Contains('- `shell: git diff --stat HEAD~1 (first)`') -and $pt -match '(?m)^## Turn 2 - the timeout continuation - failed: not a usable reply' -and $e.provider_failure.class -eq 'transport') "$($e.timeout_continue.outcome)"
    Check 'GATES24C' 'F08-4 residual, codex: the REJECTED continuation reply is not discarded - the partial file keeps its text under "## continuation reply (rejected: <why>)" after the turns, and timeout_continue.outcome names where ("...; its text is kept in handoffs/01-codex-one.partial.md under "continuation reply (rejected)"")' ($pt -match '(?m)^## continuation reply \(rejected: not a valid reply object \(.+\) and reply too short \(1 words\)\)$' -and $pt.Substring($pt.IndexOf('## continuation reply (rejected: ')).Contains("`n`nDone.`n") -and $pt.IndexOf('## continuation reply (rejected: ') -gt $pt.IndexOf('## Turn 2 - the timeout continuation') -and $e.timeout_continue.outcome.EndsWith('; its text is kept in handoffs/01-codex-one.partial.md under "continuation reply (rejected)"')) "$($e.timeout_continue.outcome)"
    $ra5 = New-Repo 'gates-agy-one'
    $x = Consult $ra5 $rosterAgy @('-Prompt', 'x', '-ReplyName', 'one', '-TimeoutSec', '5') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_RESUME_REPLY = $done; FAKE_AGY_HANG = 'new'; FAKE_AGY_TEXT = '1' }
    $e = Last-Entry $ra5
    $pt = Text (Td $ra5 $e.partial_reply)
    Check 'GATES' 'F08-5 agy: an adapter-OK continuation "Done." is not usable either - "failed: not a usable reply - ...", the salvage of both turns is written, the conversation stays a candidate (thread "")' ($x.Code -eq 1 -and $e.timeout_continue.outcome -match '^failed: not a usable reply - ' -and $e.partial_reply -match '-agy-one\.partial\.md$' -and $pt.Contains('Reading the brief (first turn).') -and $e.thread -eq '' -and $e.thread_candidate -eq $e.timeout_continue.thread) "$($e.timeout_continue.outcome)"
    Check 'GATES24C' 'F08-4 residual, agy: the rejected "Done." of the --conversation continuation is kept in the partial file under "## continuation reply (rejected: ...)", the outcome names it' ($pt -match '(?m)^## continuation reply \(rejected: ' -and $pt.Substring($pt.IndexOf('## continuation reply (rejected: ')).Contains("`n`nDone.`n") -and $e.timeout_continue.outcome -match '; its text is kept in handoffs/[0-9]{2}-agy-one\.partial\.md under "continuation reply \(rejected\)"$') "$($e.timeout_continue.outcome)"
    # --- F07-1: a prompt-only transport re-sends the reply format and the schema
    $rp = New-Repo 'gates-promptonly'
    $rlogP = Join-Path $work 'gates-po-resume.log'
    $rlogO = Join-Path $work 'gates-os-resume.log'
    $x = Consult $rp '' @('-Prompt', 'x', '-ReplyName', 'po', '-TimeoutSec', '4', '-Mode', 'new', '-SchemaTransport', 'prompt-only') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_RESUME_LOG = $rlogP }
    $ePo = Last-Entry $rp
    $y = Consult $rp '' @('-Prompt', 'x', '-ReplyName', 'os', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_RESUME_LOG = $rlogO }
    $lp = Text $rlogP
    $lo = Text $rlogO
    Check 'GATES' 'F07-1 codex -SchemaTransport prompt-only: the continuation prompt carries the output contract, the finish-now sentence, the reply format ("... satisfies the JSON Schema given at the end of this section ...") and "JSON Schema of the reply:" with the schema - no --output-schema; with output-schema the prompt names neither (the flag carries the schema); both continue to a usable reply' ($x.Code -eq 0 -and $ePo.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $lp.Contains('FINAL OUTPUT CONTRACT') -and $lp.Contains('Your previous turn was stopped by a time limit after 4 s.') -and $lp.Contains('that satisfies the JSON Schema given at the end of this section') -and $lp.Contains('JSON Schema of the reply:') -and $lp.Contains('"reply_markdown"') -and (($lp -split "`n")[0]) -notmatch '--output-schema' -and $y.Code -eq 0 -and (($lo -split "`n")[0]) -match '--output-schema' -and -not $lo.Contains('JSON Schema of the reply:') -and -not $lo.Contains('Reply format:')) "prompt-only $($lp.Length) chars, output-schema $($lo.Length) chars"
    # --- F08-6: the printed resume command replays every replay-relevant option - and works
    $r6 = New-Repo 'gates-resume'
    [IO.File]::WriteAllText((Join-Path $r6 'b.txt'), "1`n2`n3`n", $u8)
    $null = G $r6 @('add', '-A'); $null = G $r6 @('commit', '-q', '-m', 'second')
    $art6 = Join-Path $work 'gates-artifact.bin'
    [IO.File]::WriteAllText($art6, "artifact bytes`n", $u8)
    $x = Consult $r6 '' @('-Prompt', 'x', '-ReplyName', 'full', '-Purpose', 'diff-review', '-TimeoutSec', '4', '-ContinueSec', '0', '-Mode', 'new', '-Effort', 'low', '-MaxWords', '321', '-SchemaTransport', 'prompt-only', '-CodexConfig', 'model_verbosity=low', '-Artifact', $art6, '-Range', 'HEAD~1..HEAD') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json' }
    $ek = Last-Entry $r6
    $rline = [string](Line $x.Out 'resume     :')
    $fileMark = "-File ""$consultPs"" "
    $argText = $(if ($rline.Contains($fileMark)) { $rline.Substring($rline.IndexOf($fileMark) + $fileMark.Length) } else { '' })
    $toks = @([regex]::Matches($argText, '"((?:\\"|[^"])*)"|(\S+)') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value -replace '\\"', '"' } else { $_.Groups[2].Value } })
    $wantArgs = "-Task t -Mode resume -Thread $($ek.thread) -Provider openai -Model gpt-5.1 -Purpose diff-review -ReplyName full -TimeoutSec 4 -ContinueSec 0 -Effort low -MaxWords 321 -SchemaTransport prompt-only -CodexConfig model_verbosity=low -Artifact $((Resolve-Path -LiteralPath $art6).Path) -Range HEAD~1..HEAD -Prompt ""finish your review"""
    Check 'GATES' 'F08-6 the manual resume command of a killed run names every replay-relevant option it was given: (wave 24c, F15-5) -ReplyName, -TimeoutSec, -ContinueSec, -Effort, -MaxWords, -SchemaTransport, -CodexConfig, -Artifact (the resolved path), -Range (the summary line and the partial file''s footer)' ($x.Code -eq 1 -and $argText -eq $wantArgs -and (Text (Td $r6 $ek.partial_reply)).TrimEnd().EndsWith("continue with ``$wantArgs``")) $argText
    $runArgs = @()
    for ($ti = 0; $ti -lt $toks.Count; $ti++) { if ($toks[$ti] -eq '-Task') { $ti++; continue }; $runArgs += $toks[$ti] }
    $z = Consult $r6 '' $runArgs @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise }
    $ez = Last-Entry $r6
    Check 'GATES' '... running exactly that command resumes the killed thread with the SAME settings: mode resume on the killed thread, timeout 4 (explicit), continue_sec 0, effort low, max_words 321, schema_transport prompt-only (-SchemaTransport), the same extra_config, the artifact''s hash, range HEAD~1..HEAD (2 files, 4 lines) - a usable reply' ($z.Code -eq 0 -and $ez.mode -eq 'resume' -and $ez.thread -eq $ek.thread -and $ez.bridge_outcome -eq 'usable reply' -and $ez.timeout_sec -eq 4 -and $ez.timeout_source -eq 'explicit' -and $ez.continue_sec -eq 0 -and $ez.effort_requested -eq 'low' -and $ez.max_words -eq 321 -and $ez.schema_transport -eq 'prompt-only' -and $ez.schema_transport_source -eq '-SchemaTransport' -and (@($ez.extra_config) -join ',') -eq (@($ek.extra_config) -join ',') -and @($ek.extra_config).Count -eq 1 -and $ez.artifacts[0].sha256 -eq $ek.artifacts[0].sha256 -and $ez.range.spec -eq 'HEAD~1..HEAD' -and $ez.range.lines -eq $ek.range.lines) "$($z.First) | $($ez.timeout_sec)/$($ez.continue_sec)/$($ez.effort_requested)/$($ez.max_words)/$($ez.schema_transport)/$(@($ez.extra_config) -join ',')/$($ez.range.spec)"
    # --- F08-8: -Range with a single revision is refused before anything starts
    $n6 = @(Ledger $r6).Count
    $s8 = Consult $r6 '' @('-Prompt', 'x', '-Purpose', 'diff-review', '-Range', 'HEAD') @{ FAKE_CODEX_REPLY = $advise }
    Check 'GATES' 'F08-8 -Range HEAD (a single revision: git diff would measure the working tree) is refused before anything starts - "-Range ''HEAD'' is not a range of two revisions: pass base..head or base...head ...", no ledger entry' ($s8.Code -eq 1 -and $s8.First -match "^codex-consult: -Range 'HEAD' is not a range of two revisions: pass base\.\.head or base\.\.\.head" -and @(Ledger $r6).Count -eq $n6) $s8.First
    # --- F08-1: the MAIN turn's start re-reads the muse sign-in (auth.json changed after the preflight)
    $rm = New-Repo 'gates-muse-launch'
    $countM = Join-Path $work 'gates-muse-count.log'
    $pendM = Join-Path $rm '.collab\t\.consult.pending.json'
    $outM = Join-Path $work 'gates-muse-launch.out'
    $errM = Join-Path $work 'gates-muse-launch.err'
    Write-Auth $authOauth
    Set-CaseEnv $rosterMuse @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COUNT = $countM; CODEX_CONSULT_TEST_LAUNCH_PAUSE_MS = '6000' }
    $bgM = Start-Process -FilePath $psExe -WorkingDirectory $rm -PassThru -NoNewWindow -RedirectStandardOutput $outM -RedirectStandardError $errM -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-Prompt', 'x', '-ReplyName', 'launch')
    # (Windows PowerShell 5.1: touching .Handle while the process runs keeps its ExitCode readable)
    try { $null = $bgM.Handle } catch { }
    Restore-Env
    $seenM = $false
    for ($i = 0; $i -lt 200; $i++) { $prM = Read-PendingFile -Path $pendM; if ($prM.Record -and $prM.Record.state -eq 'launching') { $seenM = $true; break }; Start-Sleep -Milliseconds 100 }
    Write-Auth $authApiKey
    $bgM.WaitForExit()
    $codeM = $bgM.ExitCode
    Write-Auth $authOauth
    $textM = Text $outM
    Check 'GATES' 'F08-1 muse: auth.json turns into an api_key sign-in AFTER the preflight, while the main turn''s record says launching -> the main turn''s guarded start re-reads it and refuses: exit 1, "the muse run is refused before launch: the Muse sign-in ... uses mechanism ''api_key'', not oauth ...; nothing was started.", no muse process, no ledger entry, no recovery record' ($seenM -and $codeM -eq 1 -and $textM -match "codex-consult: the muse run is refused before launch: the Muse sign-in in ~/\.config/muse/auth\.json uses mechanism 'api_key', not oauth" -and $textM.Contains('nothing was started.') -and -not (Test-Path $countM) -and @(Ledger $rm).Count -eq 0 -and -not (Test-Path $pendM)) "seen=$seenM exit=$codeM $((($textM -split "`n") | Where-Object { $_ -match 'refused' } | Select-Object -First 1))"
    # --- F13-1: the providers rows list every roster position of a label
    $r13 = New-Repo 'gates-positions'
    $roster13 = Write-Roster 'positions' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"' + $agyModel + '"},{"provider":"openai","model":"gpt-5.1"},{"provider":"gemini","engine":"agy","model":"gemini-3.1-pro-high"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"ZAI","model":"glm-5.2"}]}')
    $pj13 = Providers $r13 $roster13 @('-Json', '-NoNetwork')
    $gemR = @($pj13.Json | Where-Object { $_.name -eq 'gemini' })[0]
    $zaiR = @($pj13.Json | Where-Object { $_.name -eq 'ZAI' })[0]
    $oaiR = @($pj13.Json | Where-Object { $_.name -eq 'openai' })[0]
    $mimoR = @($pj13.Json | Where-Object { $_.name -eq 'mimo' })[0]
    Check 'GATES' 'F13-1 codex-providers -Json: roster_positions (every position of the label) beside roster_position (the first) - gemini [1,3] (two agy models), ZAI [4,5], openai [2], mimo [] (no entry, roster_position null)' ($pj13.Code -eq 0 -and $gemR.roster_position -eq 1 -and (@($gemR.roster_positions) -join ',') -eq '1,3' -and $zaiR.roster_position -eq 4 -and (@($zaiR.roster_positions) -join ',') -eq '4,5' -and (@($oaiR.roster_positions) -join ',') -eq '2' -and $null -eq $mimoR.roster_position -and @($mimoR.roster_positions).Count -eq 0 -and $pj13.Out -match '"roster_positions":') "gemini $(@($gemR.roster_positions) -join ',') | ZAI $(@($zaiR.roster_positions) -join ',') | mimo $(@($mimoR.roster_positions).Count)"
    # --- the kimi 401 of the wave 24 acceptance ledger, end to end: capability, a hint, no 24-hour block
    $rk = New-Repo 'gates-context'
    $kimiText = 'unexpected status 401 Unauthorized: Your current plan supports only k3 up to 256K context. 1M context is available on higher-tier Kimi Code plans. Upgrade: https://www.kimi.com/code?from=server_k3_error#pricing, url: https://api.kimi.ai/coding/v1/responses, cf-ray: a4133b7fbf13d2fa-FRA'
    $x = Consult $rk '' @('-Prompt', 'x', '-ReplyName', 'ctx', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_STDERR = $kimiText; FAKE_CODEX_EXIT = '1' }
    $e = Last-Entry $rk
    $mdK = Text (Td $rk $e.reply)
    $dK = Consult $rk '' @('-DryRun', '-Prompt', 'x')
    Check 'GATES' 'the plan''s context limit under a 401 (kimi :: k3): provider_failure class capability (never auth), the summary "hint       : context too long for this plan/model - narrow the brief ... or choose a model with a larger context window", the handoff header "Provider failure: capability - ... Hint: context too long ..."; the next preflight on that endpoint is not refused (no 24-hour auth block)' ($x.Code -eq 1 -and $e.provider_failure.class -eq 'capability' -and $e.bridge_outcome -match '^failed: codex exit 1 - unexpected status 401 Unauthorized: Your current plan supports only k3' -and $x.Out -match '(?m)^hint       : context too long for this plan/model - narrow the brief .+ or choose a model with a larger context window$' -and $mdK -match '(?m)^Provider failure: capability - unexpected status 401 .+\. Hint: context too long for this plan/model - ' -and $dK.Code -eq 0 -and $dK.Preview.preflight -eq 'ok: Logged in using ChatGPT') "$($e.provider_failure.class) | $($dK.Preview.preflight)"
}

# =============================================================== GATES24C: wave 24c end to end - the tree check by content, the diagnostic stderr filter, the complete resume command
if (Want 'GATES24C') {
    # --- the live defect (companions n=13): a commit of the collab files while a muse member runs
    $rmA = New-Repo 'g24c-muse-commit'
    [IO.File]::WriteAllText((Join-Path $rmA '.collab\t\state.md'), "coordinator notes`n", $u8)
    $x = Consult $rmA $rosterMuse @('-Prompt', 'x', '-ReplyName', 'mc') @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COMMIT = '.collab/t/state.md' }
    $e = Last-Entry $rmA
    $headA = [string](@(G $rmA @('rev-parse', 'HEAD'))[0])
    $headA = $headA.Trim()
    $hdrA = Text (Td $rmA $e.reply)
    $noteA = "Note: HEAD moved during the review ($(([string]$e.base_commit).Substring(0, [Math]::Min(7, ([string]$e.base_commit).Length))) -> $($headA.Substring(0, [Math]::Min(7, $headA.Length)))) - no file content changed: not a tree change."
    Check 'GATES24C' 'the live defect (companions n=13): the coordinator COMMITS the collab files while a muse member runs - HEAD moves, no file content changes -> NOT a tree change: usable reply, tree_changed_during_review false, ledger revision_moved "<base_commit> -> <the new HEAD>" (base_commit stays the reviewed one), the handoff notes "Note: HEAD moved during the review (<old> -> <new>) - no file content changed: not a tree change."' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply' -and $e.tree_changed_during_review -eq $false -and $e.revision_moved -eq "$($e.base_commit) -> $headA" -and $e.base_commit -ne $headA -and $hdrA.Contains($noteA)) "$($e.bridge_outcome) | $($e.revision_moved)"
    # --- a real content change still fails (the reviewer rewrites a tracked file; it is committed too)
    $rmB = New-Repo 'g24c-muse-write'
    $x = Consult $rmB $rosterMuse @('-Prompt', 'x', '-ReplyName', 'mw') @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_WRITE = 'app.txt'; FAKE_MUSE_COMMIT = 'app.txt' }
    $e = Last-Entry $rmB
    Check 'GATES24C' '... a real content change is still SEEN, committed or not: the tracked app.txt rewritten (and committed) during the run -> tree_changed_during_review true, revision_moved recorded as well; (wave 26b, D9) for muse - write-disabled by the bridge - it is a warning ("the working tree changed during the run (1 file: app.txt) - muse ran write-disabled, the change is not the reviewer''s"), tree_check warned, the reply usable (agy keeps the failure: harness-muse TREE)' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply' -and $null -eq $e.provider_failure -and @($e.warnings | Where-Object { $_ -eq "the working tree changed during the run (1 file: app.txt) - muse ran write-disabled, the change is not the reviewer's" }).Count -eq 1 -and $e.tree_check.outcome -eq 'warned' -and $e.tree_changed_during_review -eq $true -and [string]$e.revision_moved -match '^[0-9a-f]{40} -> [0-9a-f]{40}$') "$($e.bridge_outcome) | $(@($e.warnings) -join ' | ')"
    # --- codex: HEAD moved while the main turn hung - the continuation is not blocked
    $rcC = New-Repo 'g24c-codex-commit'
    [IO.File]::WriteAllText((Join-Path $rcC 'app.txt'), "one`ntwo`n", $u8)
    $x = Consult $rcC '' @('-Prompt', 'x', '-ReplyName', 'cc', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_COMMIT = 'app.txt' }
    $e = Last-Entry $rcC
    Check 'GATES24C' 'codex: app.txt (changed before the run) is committed while the main turn hangs - HEAD moves, the contents stay -> the timeout continuation is NOT blocked (the old fingerprint said "files changed during the run"): "usable reply (after a timeout continuation)", tree_changed_during_review false, revision_moved "<old> -> <new>", no working-tree WARNING in the handoff' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $e.timeout_continue.outcome -eq 'usable reply' -and $e.tree_changed_during_review -eq $false -and [string]$e.revision_moved -match '^[0-9a-f]{40} -> [0-9a-f]{40}$' -and -not (Text (Td $rcC $e.reply)).Contains('WARNING: working tree changed')) "$($e.bridge_outcome) | $($e.timeout_continue.outcome) | $($e.revision_moved)"
    # --- F15-3: a killed codex turn whose stderr holds only informational lines is continued
    $rcD = New-Repo 'g24c-benign'
    $benignE = "loaded auth.json`nrequest 429 tracing enabled`n2026-09-26T18:28:36.873087Z ERROR codex_models_manager::manager: failed to refresh available models: stream disconnected before completion: failed to decode models response: missing field ``models`` at line 1 column 27995; body: {""data"":[{""id"":""m"",""billing"":""quota""}]}"
    $x = Consult $rcD '' @('-Prompt', 'x', '-ReplyName', 'bn', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_STDERR_FIRST = $benignE }
    $e = Last-Entry $rcD
    Check 'GATES24C' 'F15-3 codex: the killed turn''s stderr holds only informational lines ("loaded auth.json", "request 429 tracing enabled", codex''s models refresh at ERROR level with a body naming billing and quota) -> the continuation is permitted and answers: "usable reply (after a timeout continuation)"' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $e.timeout_continue.outcome -eq 'usable reply') "$($e.timeout_continue.outcome)"
    # --- F15-5: -ReplyName and -SkipPreflight travel in the resume command
    $rcE = New-Repo 'g24c-resume'
    $x = Consult $rcE '' @('-Prompt', 'x', '-ReplyName', 'hold', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-SkipPreflight', '-TimeoutSec', '4', '-ContinueSec', '0', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json' }
    $ek = Last-Entry $rcE
    $rlineE = [string](Line $x.Out 'resume     :')
    $fileMarkE = "-File ""$consultPs"" "
    $argTextE = $(if ($rlineE.Contains($fileMarkE)) { $rlineE.Substring($rlineE.IndexOf($fileMarkE) + $fileMarkE.Length) } else { '' })
    $wantE = "-Task t -Mode resume -Thread $($ek.thread) -Provider mimo -Model mimo-v2.6-pro -ReplyName hold -TimeoutSec 4 -ContinueSec 0 -SkipPreflight -Prompt ""finish your review"""
    $z = Consult $rcE '' @('-Mode', 'resume', '-Thread', $ek.thread, '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-ReplyName', 'hold', '-TimeoutSec', '4', '-ContinueSec', '0', '-SkipPreflight', '-Prompt', 'finish your review') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise }
    $ez = Last-Entry $rcE
    $nE = @(Ledger $rcE).Count
    $zNo = Consult $rcE '' @('-Mode', 'resume', '-Thread', $ek.thread, '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-ReplyName', 'hold', '-TimeoutSec', '4', '-ContinueSec', '0', '-Prompt', 'finish your review') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise }
    Check 'GATES24C' 'F15-5 a killed run given -ReplyName hold and -SkipPreflight (mimo, whose key is not set) prints a resume command with both ("... -ReplyName hold -TimeoutSec 4 -ContinueSec 0 -SkipPreflight -Prompt ..."); running it resumes the killed thread unchecked, as the run started (preflight "skipped"), under the same reply name (handoffs/02-codex-hold.md); without -SkipPreflight the same command is refused before anything starts (RT_MIMO_KEY not set)' ($x.Code -eq 1 -and $argTextE -eq $wantE -and $z.Code -eq 0 -and $ez.mode -eq 'resume' -and $ez.thread -eq $ek.thread -and $ez.preflight -eq 'skipped' -and $ez.reply -eq 'handoffs/02-codex-hold.md' -and $zNo.Code -eq 1 -and $zNo.First -match 'RT_MIMO_KEY' -and @(Ledger $rcE).Count -eq $nE) "$argTextE | $($z.First) | $($zNo.First)"
}

# =============================================================== BURST: a burst 429 is out for 10 minutes, not 60 (wave 24c; the live ledgers' BytePlus 429)
if (Want 'BURST') {
    $r = New-Repo 'burst'
    $nowB = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    $hitB = $nowB.AddMinutes(-9)
    $bp = 'exceeded retry limit, last status: 429 Too Many Requests, request id: 021790447325230e0fa5d59a7b50e9f748f37815b909e289b22b6'
    Seed-Ledger $r 'other' @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $nowB.AddMinutes(-12) "failed: codex exit 1 - $bp" (Quota $hitB $bp)))
    $clockB = @{ CODEX_CONSULT_NOW = (Iso $nowB) }
    $rosterZOB = Write-Roster 'zai-openai-burst' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"openai","model":"gpt-5.1"}]}'
    $reasonB = "burst limit (429) hit $(Iso $hitB), reset unknown; retry after $(Iso $hitB.AddMinutes(10))"
    $d = Consult $r $rosterZOB @('-DryRun', '-Prompt', 'x') $clockB
    $sh = Providers $r $rosterZOB @('-Short') $clockB
    $expB = "codex-consult: out - ZAI :: glm-5.3 (burst limit hit $(Local-When $hitB $nowB), reset unknown; retry after $(Local-When $hitB.AddMinutes(10) $nowB), in 1m); 1 of 2 reviewers available"
    Check 'BURST' 'the live BytePlus 429 (recorded without kind), hit 9 min ago: the roster walk skips ZAI "burst limit (429) hit <iso>, reset unknown; retry after <iso + 10 min>"; -Short says "burst limit hit <local>, reset unknown; retry after <local + 10 min>, in 1m"' ($d.Code -eq 0 -and $d.Preview.roster.position -eq 2 -and $d.Preview.roster.skipped[0].reason -eq $reasonB -and $sh.Out.Trim() -eq $expB) "walk='$($d.Preview.roster.skipped[0].reason)' short='$($sh.Out.Trim())'"
    $laterB = @{ CODEX_CONSULT_NOW = (Iso $hitB.AddMinutes(11)) }
    $d2 = Consult $r $rosterZOB @('-DryRun', '-Prompt', 'x') $laterB
    $sh2 = Providers $r $rosterZOB @('-Short') $laterB
    Check 'BURST' '... 11 minutes after the hit (not 61): the walk selects ZAI again, "all 2 reviewers available"' ($d2.Code -eq 0 -and $d2.Preview.roster.position -eq 1 -and $sh2.Out.Trim() -eq 'codex-consult: all 2 reviewers available') $sh2.Out.Trim()
    $n0 = @(Ledger $r).Count
    $xb = Consult $r $rosterZOB @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'refused') ($clockB + @{ FAKE_CODEX_REPLY = $advise })
    $refB = "codex-consult: provider ZAI is not usable: it hit a burst limit at $(Iso $hitB) ($($bp.Substring(0, 100)) - a 429 that names no usage limit or quota) and named no reset time - out for 10 minutes, until $(Iso $hitB.AddMinutes(10)); nothing was started (pass -SkipPreflight to launch anyway)"
    Check 'BURST' '... an explicit -Provider ZAI run inside the 10 minutes is refused: "... it hit a burst limit at <iso> (<message> - a 429 that names no usage limit or quota) and named no reset time - out for 10 minutes, until <iso>; nothing was started (pass -SkipPreflight to launch anyway)", nothing recorded' ($xb.Code -eq 1 -and $xb.First -eq $refB -and @(Ledger $r).Count -eq $n0) $xb.First
    # a real run whose codex fails with that 429 records kind burst
    $rb2 = New-Repo 'burst-run'
    $xr = Consult $rb2 '' @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'b429') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_STDERR = "ERROR: $bp"; FAKE_CODEX_EXIT = '1' }
    $er = Last-Entry $rb2
    $shr = Providers $rb2 $rosterZOB @('-Short')
    Check 'BURST' '... a run whose codex fails with that 429 records provider_failure {class quota, kind burst, retry_after null} (kind right after class); the one-line view then says ZAI is out with "burst limit hit"' ($xr.Code -eq 1 -and $er.provider_failure.class -eq 'quota' -and $er.provider_failure.kind -eq 'burst' -and $null -eq $er.provider_failure.retry_after -and (($er.provider_failure.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'class,kind,code,message,when,retry_after,hint' -and $shr.Out -match 'ZAI :: glm-5\.3 \(burst limit hit ') "$($er.provider_failure.class)/$($er.provider_failure.kind) | $($shr.Out.Trim())"
}

# =============================================================== PANEL: members continue in their own process (T1)
if (Want 'PANEL') {
    $r = New-Repo 'panel'
    $p = Consult $r $rosterCodex @('-Panel', '-PanelSize', '2', '-Prompt', 'x', '-Purpose', 'checkpoint', '-TimeoutSec', '5', '-ReplyName', 'pc') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1' }
    $led = @(Ledger $r)
    Check 'PANEL' 'T1 a panel whose members'' main turns hang: each member continues in its own process - both entries "usable reply (after a timeout continuation)" with their timeout_continue; the summary rows read ADVISE ... "(after a timeout continuation)"; exit 0' ($p.Code -eq 0 -and $led.Count -eq 2 -and @($led | Where-Object { $_.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $_.timeout_continue.outcome -eq 'usable reply' }).Count -eq 2 -and ([regex]::Matches($p.Out, '(?m)^  \S+ :: \S+\s+ADVISE .*\(after a timeout continuation\)$').Count -eq 2)) ((($p.Out -split "`n") | Where-Object { $_ -match 'after a timeout continuation\)$' }) -join ' / ')
    $q = Consult $r $rosterCodex @('-Panel', '-PanelSize', '2', '-Prompt', 'x', '-Purpose', 'checkpoint', '-TimeoutSec', '5', '-ReplyName', 'ph', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""' }
    $zl = @(Ledger $r | Where-Object { $_.reviewer.provider -eq 'ZAI' }) | Select-Object -Last 1
    $zrow = (($q.Out -split "`n") | Where-Object { $_ -match '^  ZAI :: glm-5\.3\s+failed: timeout' } | Select-Object -First 1)
    Check 'PANEL' '... one member hangs on both turns: its row "failed: timeout after 5 s (process tree killed)" names its partial reply; its own output (in the panel''s) prints the resume command (-Thread of its thread, -Purpose checkpoint, wave 24c: the member''s own -ReplyName); the other member answers; exit 1' ($q.Code -eq 1 -and $zl.bridge_outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $zl.partial_reply -and $zrow -and $zrow.Contains("partial $($zl.partial_reply)") -and $q.Out.Contains("-Task t -Mode resume -Thread $($zl.thread) -Purpose checkpoint -ReplyName $((([string]$zl.reply) -replace '^handoffs/[0-9]+-codex-', '') -replace '\.md$', '') -TimeoutSec 5 -Prompt ""finish your review""")) $zrow
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-visibility ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
