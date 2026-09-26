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
# hook and the roster walk agree. F15-1: the muse launch guard re-reads auth.json.
# FAKES ONLY: fake-codex3.cmd, fake-agy.cmd, fake-muse.cmd (CODEX_CONSULT_*_EXE); CODEX_HOME, the
# roster, USERPROFILE/HOME (a fake muse auth.json) and LOCALAPPDATA point at SCRATCH directories;
# PATH holds no muse launcher (the harness refuses to run otherwise). Runs under the host it is
# started with (powershell 5.1 or pwsh 7, Windows). Work files:
# $env:TEMP\codex-consult-tests\harness-visibility\<guid>, removed at the end.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
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
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_RESUME_REPLY', 'FAKE_CODEX_RESUME_LOG', 'FAKE_CODEX_LOG', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_HANG_NEW', 'FAKE_CODEX_ITEMS', 'FAKE_CODEX_PRELINE', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_FAIL_ON', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_REPLY_MAP', 'FAKE_AGY_REPLY', 'FAKE_AGY_RESUME_REPLY', 'FAKE_AGY_NOSTRUCTURED', 'FAKE_AGY_HANG', 'FAKE_AGY_HANG_ON', 'FAKE_AGY_TEXT', 'FAKE_AGY_DENIED', 'FAKE_AGY_LOG', 'FAKE_AGY_RESUME_LOG', 'FAKE_AGY_MODELS', 'FAKE_AGY_MODELS_LOG', 'FAKE_MUSE_REPLY', 'FAKE_MUSE_RESUME_REPLY', 'FAKE_MUSE_HANG', 'FAKE_MUSE_TEXT', 'FAKE_MUSE_LOG', 'FAKE_MUSE_RESUME_LOG', 'FAKE_MUSE_COUNT')
$testVars = @('CODEX_CONSULT_EXE', 'CODEX_CONSULT_AGY_EXE', 'CODEX_CONSULT_MUSE_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_SURVIVORS', 'CODEX_CONSULT_TEST_LOGIN_TIMEOUT', 'META_API_KEY', 'MODEL_API_KEY', 'TBH_CREDENTIAL_BACKEND', 'RT_ZAI_KEY', 'RT_MIMO_KEY')
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
    $out = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $hookPs 2>&1 | ForEach-Object { "$_" }) -join "`n"
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

    # --- T3: a quota failure without a reset time is out for 60 minutes after it was hit
    $now = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    $hit = $now.AddMinutes(-9)
    $q = New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-15) 'failed: codex exit 1 - 429 Too Many Requests' (Quota $hit '429 Too Many Requests')
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
    Check 'UNIT' 'D14 Get-PreflightVerdict -RosterWalk: unavailable, Kind quota-unknown-reset, Reason "usage limit hit <iso>, reset unknown; retry after <iso + 60 min>", Hit and Until; without -RosterWalk (an explicit single run) available - Format-QuotaWarning warns' ($vW.State -eq 'unavailable' -and $vW.Kind -eq 'quota-unknown-reset' -and $vW.Reason -eq "usage limit hit $(Iso $hit), reset unknown; retry after $(Iso $hit.AddMinutes(60))" -and (Iso $vW.Until) -eq (Iso $hit.AddMinutes(60)) -and $vS.State -eq 'available' -and (Format-QuotaWarning -Identity $idZ -Health $h) -match '^provider ZAI hit a usage limit') $vW.Reason
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
    $zq = @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $now.AddMinutes(-12) 'failed: codex exit 1 - 429 Too Many Requests' (Quota $hitZ '429 Too Many Requests')))
    $rz = Roster-Of (Write-Roster 'avail-zai' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"zai2","model":"glm-5.3"}]}')
    $az = Get-RosterAvailability -Roster $rz -Config $cfgZ -Consults $zq -Launcher $fakeCodex -LoginCache @{} -UtcNow $now.UtcDateTime -NoNetwork
    $lineZ = Format-AvailabilityLine -Availability $az
    $expZ = "codex-consult: out - ZAI+zai2 :: * (limit hit $(Local-When $hitZ $now), reset unknown; retry after $(Local-When $hitZ.AddMinutes(60) $now), in 51m); 0 of 2 reviewers available"
    Check 'AVAIL' 'T3/D16: a 429 without a reset time 9 min ago on the ZAI endpoint -> both labels of that endpoint group (ZAI, zai2) out, one clause "ZAI+zai2 :: * (limit hit <local>, reset unknown; retry after <local + 60 min>, in 51m)" - no clause cut at 60 characters' ($lineZ -eq $expZ) $lineZ
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

# =============================================================== QUOTA60: a quota failure without a reset time is out for 60 minutes - everywhere (T3, D14)
if (Want 'QUOTA60') {
    $r = New-Repo 'quota60'
    $nowQ = [DateTimeOffset]::new(2026, 9, 26, 10, 40, 0, [TimeSpan]::FromHours(2))
    $hitQ = $nowQ.AddMinutes(-9)
    Seed-Ledger $r 'other' @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp 'codex' $nowQ.AddMinutes(-12) 'failed: codex exit 1 - exceeded retry limit, last status: 429 Too Many Requests' (Quota $hitQ 'exceeded retry limit, last status: 429 Too Many Requests')))
    $clockQ = @{ CODEX_CONSULT_NOW = (Iso $nowQ) }
    $reasonQ = "usage limit hit $(Iso $hitQ), reset unknown; retry after $(Iso $hitQ.AddMinutes(60))"
    $rosterZO = Write-Roster 'zai-openai' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"openai","model":"gpt-5.1"}]}'
    $d = Consult $r $rosterZO @('-DryRun', '-Prompt', 'x') $clockQ
    $pj = Providers $r $rosterZO @('-Json') $clockQ
    $zr = @($pj.Json | Where-Object { $_.name -eq 'ZAI' })[0]
    $expQ = "codex-consult: out - ZAI :: glm-5.3 (limit hit $(Local-When $hitQ $nowQ), reset unknown; retry after $(Local-When $hitQ.AddMinutes(60) $nowQ), in 51m); 1 of 2 reviewers available"
    $sh = Providers $r $rosterZO @('-Short') $clockQ
    $hk = Hook $r $rosterZO $clockQ
    Check 'QUOTA60' 'T3 a 429 without a reset time, hit 9 min ago (the BytePlus case): the roster walk skips ZAI "usage limit hit <iso>, reset unknown; retry after <iso + 60 min>"; the listing row reads "unavailable (<the same>)"; -Short and the hook say it is out, in local time - one verdict everywhere' ($d.Code -eq 0 -and $d.Preview.roster.position -eq 2 -and $d.Preview.roster.skipped[0].reason -eq $reasonQ -and $zr.verdict -eq "unavailable ($reasonQ)" -and $zr.roster_selected -eq $false -and $sh.Out.Trim() -eq $expQ -and $hk -eq $expQ) "walk='$($d.Preview.roster.skipped[0].reason)' row='$($zr.verdict)' hook='$hk'"
    $later = @{ CODEX_CONSULT_NOW = (Iso $hitQ.AddMinutes(61)) }
    $d2 = Consult $r $rosterZO @('-DryRun', '-Prompt', 'x') $later
    $sh2 = Providers $r $rosterZO @('-Short') $later
    Check 'QUOTA60' '... 61 min after the hit: the walk selects ZAI again, the line reads "all 2 reviewers available"' ($d2.Code -eq 0 -and $d2.Preview.roster.position -eq 1 -and $sh2.Out.Trim() -eq 'codex-consult: all 2 reviewers available') $sh2.Out.Trim()
    $px = Providers $r $rosterZO @('-Provider', 'ZAI') $clockQ
    $dx = Consult $r $rosterZO @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3') $clockQ
    Check 'QUOTA60' '... codex-providers -Provider ZAI exits 2 (unavailable - the walk''s verdict); an explicit -Provider ZAI run is not refused, it warns (the operator chose that reviewer; the documented rule)' ($px.Code -eq 2 -and $dx.Code -eq 0 -and $dx.Preview.preflight_warning -match '^provider ZAI hit a usage limit 12 min ago: ') "exit $($px.Code) | $($dx.Preview.preflight_warning)"
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
    $resumeArgs = "-Task t -Mode resume -Thread $($e2.thread) -Provider openai -Model gpt-5.1 -Purpose checkpoint -Prompt ""finish your review"""
    Check 'CONT' 'T1 the continuation hangs too: bridge_outcome stays "failed: timeout after 4 s (process tree killed)"; timeout_continue.outcome "failed: timeout after 4 s (process tree killed)"; partial_reply = handoffs/02-codex-hh.partial.md (right after events in the ledger); exit 1; no recovery record left' ($y.Code -eq 1 -and $e2.bridge_outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e2.timeout_continue.outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $e2.partial_reply -eq 'handoffs/02-codex-hh.partial.md' -and (Test-Path $pp) -and ((@($e2.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match 'reply_json,events,partial_reply,model') -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) "$($e2.bridge_outcome) | $($e2.partial_reply)"
    Check 'CONT' '... the partial file: the reply''s header ("Bridge outcome: failed: timeout ..."), "## Turn 1 - the main turn - killed at <t> s of 4 s" with its reasoning, agent message and the shell command line, "## Turn 2 - the timeout continuation - killed at ...", then the footer "killed at ... ; thread <id> - continue with `-Task t -Mode resume -Thread <id> -Provider openai -Model gpt-5.1 -Purpose checkpoint -Prompt "finish your review"`" (no roster: the reviewer is named)' ($pt -match '(?m)^# Handoff 02 - Codex: hh - partial reply \(a turn was killed on its timeout\)$' -and $pt -match '(?m)^Bridge outcome: failed: timeout after 4 s \(process tree killed\)\.' -and $pt -match '(?m)^## Turn 1 - the main turn - killed at [0-9.]+ s of 4 s$' -and $pt.Contains('Reading the brief (first turn).') -and $pt.Contains('Q1 so far (first turn): the change looks consistent.') -and $pt.Contains('- `shell: git diff --stat HEAD~1 (first)`') -and $pt -match '(?m)^## Turn 2 - the timeout continuation - killed at [0-9.]+ s of 4 s$' -and $pt.Contains('Reading the brief (resume turn).') -and $pt.TrimEnd().EndsWith("; thread $($e2.thread) - continue with ``$resumeArgs``")) (($pt.TrimEnd() -split "`n") | Select-Object -Last 1)
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
    $v = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'quota', '-TimeoutSec', '4', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json'; FAKE_CODEX_PRELINE = '{"type":"error","message":"You have hit your usage limit. Try again later."}' }
    $e5 = Last-Entry $r
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
    Check 'CONT' 'the scoreboard counts a reply after a timeout continuation as usable (USABLE = the usable entries, 3 of the 7 runs)' ($tot -and [int]$tot.usable -eq $wantUsable -and $wantUsable -eq 3) "usable=$($tot.usable) want=$wantUsable"
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
    Check 'CONTAGY' 'T1 agy, the continuation hangs too: failed (timeout), the conversation stays a candidate (= timeout_continue.thread); the partial file salvages both turns (the text_delta message, "run_command: git log -1 (first)", the resume turn''s text) and names the conversation to resume (a roster: no -Provider needed)' ($y.Code -eq 1 -and $e2.bridge_outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $e2.thread -eq '' -and $e2.thread_candidate -match $uuidRe -and $e2.thread_candidate -eq $e2.timeout_continue.thread -and $pt.Contains('Reading the brief (first turn).') -and $pt.Contains('- `run_command: git log -1 (first)`') -and $pt.Contains('Reading the brief (resume turn).') -and $pt.TrimEnd().EndsWith("; thread $($e2.thread_candidate) - continue with ``-Task t -Mode resume -Thread $($e2.thread_candidate) -Prompt ""finish your review""``")) (($pt.TrimEnd() -split "`n") | Select-Object -Last 1)
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

# =============================================================== PANEL: members continue in their own process (T1)
if (Want 'PANEL') {
    $r = New-Repo 'panel'
    $p = Consult $r $rosterCodex @('-Panel', '-Prompt', 'x', '-Purpose', 'checkpoint', '-TimeoutSec', '5', '-ReplyName', 'pc') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1' }
    $led = @(Ledger $r)
    Check 'PANEL' 'T1 a panel whose members'' main turns hang: each member continues in its own process - both entries "usable reply (after a timeout continuation)" with their timeout_continue; the summary rows read ADVISE ... "(after a timeout continuation)"; exit 0' ($p.Code -eq 0 -and $led.Count -eq 2 -and @($led | Where-Object { $_.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $_.timeout_continue.outcome -eq 'usable reply' }).Count -eq 2 -and ([regex]::Matches($p.Out, '(?m)^  \S+ :: \S+\s+ADVISE .*\(after a timeout continuation\)$').Count -eq 2)) ((($p.Out -split "`n") | Where-Object { $_ -match 'after a timeout continuation\)$' }) -join ' / ')
    $q = Consult $r $rosterCodex @('-Panel', '-Prompt', 'x', '-Purpose', 'checkpoint', '-TimeoutSec', '5', '-ReplyName', 'ph', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""' }
    $zl = @(Ledger $r | Where-Object { $_.reviewer.provider -eq 'ZAI' }) | Select-Object -Last 1
    $zrow = (($q.Out -split "`n") | Where-Object { $_ -match '^  ZAI :: glm-5\.3\s+failed: timeout' } | Select-Object -First 1)
    Check 'PANEL' '... one member hangs on both turns: its row "failed: timeout after 5 s (process tree killed)" names its partial reply; its own output (in the panel''s) prints the resume command (-Thread of its thread, -Purpose checkpoint); the other member answers; exit 1' ($q.Code -eq 1 -and $zl.bridge_outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $zl.partial_reply -and $zrow -and $zrow.Contains("partial $($zl.partial_reply)") -and $q.Out.Contains("-Task t -Mode resume -Thread $($zl.thread) -Purpose checkpoint -Prompt ""finish your review""")) $zrow
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
