# codex-consult wave 23: the `muse` engine (Meta's Muse Code CLI, headless `muse exec`), decisions
# D1-D16 - the adapter contract (one turn-options object, every turn's own prompt file), the
# secondary turns through the adapter for EVERY engine (D2: a static check and a format repair
# served by the muse fake), the launcher chain (-EngineExe bound to the selected engine, the env
# override, PATH, the vendor install location), the billing guard (an API key in the environment;
# -SkipPreflight, the roster walk and a panel member), the three sign-in states, the MSP extraction
# invariants (schema_version, one session, one terminal, the served model), the failure classes
# (exit 2, 130, the step cap, Meta's quota wording verbatim with its reset time and the shared
# endpoint health), the tree check and D12's forced class permission (agy too), resume and a
# session mismatch, -MaxModelSteps (argv, ledger, the panel spec), prompt and schema paths with
# spaces through the .cmd chain and the %-expansion refusal, the dry-run text, the providers
# listing. Wave 23b (the acceptance panel's F09-1..3): the billing guard fail-closed (no
# ESTABLISHED oauth sign-in - the keychain backend, no auth.json, no mechanism - refuses the
# launch under -SkipPreflight, in the walk, in a panel member and in the listing too), a
# prompt-only run's format repair keeping the main turn's transport (no --output-schema; ledger
# format_retry.schema_transport), the MSP evidence bound to the session stream and the run it
# links ("ambiguous provenance" for a nested or sub-stream record).
# FAKES ONLY: fake-muse.cmd (CODEX_CONSULT_MUSE_EXE), fake-agy.cmd and fake-codex3.cmd.
# The real muse is never resolvable: every child gets a scratch USERPROFILE/HOME (a fake
# auth.json, never the real one), a scratch LOCALAPPDATA (no install location) and a PATH without
# any directory that holds a muse launcher; the harness refuses to run otherwise. Runs under the
# host it is started with (powershell 5.1 or pwsh 7, Windows). Work files:
# $env:TEMP\codex-consult-tests\harness-muse\<guid>, removed at the end.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$providersPs = Join-Path $scripts 'codex-providers.ps1'
$schemaPath = [IO.Path]::GetFullPath((Join-Path $repoRoot 'plugins\codex-consult\schemas\consult-reply.schema.json'))
$fakeMuse = Join-Path $sp 'fake-muse.cmd'
$fakeAgy = Join-Path $sp 'fake-agy.cmd'
$fakeCodex = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-muse') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
$realConfig = Join-Path (Join-Path $HOME '.codex') 'config.toml'
$realConfigHash = ''
if (Test-Path -LiteralPath $realConfig -PathType Leaf) { $realConfigHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash }
# The process environment the cases change and the end restores (values are never printed).
$savedEnv = @{}
foreach ($k in @('CODEX_HOME', 'Path', 'USERPROFILE', 'HOME', 'LOCALAPPDATA', 'TEMP', 'TMP', 'TBH_CREDENTIAL_BACKEND', 'META_API_KEY', 'MODEL_API_KEY')) { $savedEnv[$k] = [Environment]::GetEnvironmentVariable($k) }
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
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
$codexHome = Join-Path $work 'codexhome'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), "model = `"gpt-5.1`"`n", $u8)
# The scratch home of every child (USERPROFILE and HOME): ~/.config/muse/auth.json is a FAKE.
$museHome = Join-Path $work 'home'
$authPath = Join-Path $museHome '.config\muse\auth.json'
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $authPath))
# ... with the AppData\Local of a real profile (wave 23b): without it Windows PowerShell 5.1's
# [Environment]::GetFolderPath('LocalApplicationData') is EMPTY under this USERPROFILE, and a
# long-lived 5.1 process (a bridge, a panel member) then writes its ModuleAnalysisCache
# relative to its working directory - into the test repository, where a muse run's tree check
# sees "Microsoft/Windows/PowerShell/ModuleAnalysisCache" appear (a timing-dependent failure).
[void][IO.Directory]::CreateDirectory((Join-Path $museHome 'AppData\Local'))
$tokenMark = 'FAKE-TOKEN-NOT-A-SECRET-7f3a91'
$authOauth = '{"providers":{"meta":{"access_token":"' + $tokenMark + '","obtained_via":"device_code","mechanism":"oauth","api_base_url":"https://example.invalid"}}}'
function Write-Auth { param([string]$Json) if ($Json) { [IO.File]::WriteAllText($authPath, $Json, $u8) } elseif (Test-Path -LiteralPath $authPath) { Remove-Item -LiteralPath $authPath -Force } }
Write-Auth $authOauth
# The scratch LOCALAPPDATA (no vendor install location unless a case creates one) and a PATH
# without any directory that holds a muse launcher.
$lad = Join-Path $work 'localappdata'
[void][IO.Directory]::CreateDirectory($lad)
$safePath = (@(([string]$savedEnv['Path']) -split ';' | Where-Object { $_ -and -not (Test-Path -LiteralPath (Join-Path $_ 'muse.cmd')) -and -not (Test-Path -LiteralPath (Join-Path $_ 'muse.exe')) -and -not (Test-Path -LiteralPath (Join-Path $_ 'muse')) })) -join ';'
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
$fakeVars = @('FAKE_MUSE_REPLY', 'FAKE_MUSE_RESUME_REPLY', 'FAKE_MUSE_TERMINAL', 'FAKE_MUSE_REASON', 'FAKE_MUSE_EXIT', 'FAKE_MUSE_USAGE_ERROR', 'FAKE_MUSE_STDERR', 'FAKE_MUSE_SESSION', 'FAKE_MUSE_TWOSESSIONS', 'FAKE_MUSE_MODEL', 'FAKE_MUSE_NOMODEL', 'FAKE_MUSE_SCHEMA_VERSION', 'FAKE_MUSE_TWOTERMINALS', 'FAKE_MUSE_NOTERMINAL', 'FAKE_MUSE_TERMINAL_STREAM', 'FAKE_MUSE_LINK', 'FAKE_MUSE_MODEL_STREAM', 'FAKE_MUSE_MODEL_RUN', 'FAKE_MUSE_TERMINAL_RUN', 'FAKE_MUSE_PARTIAL', 'FAKE_MUSE_WRITE', 'FAKE_MUSE_HANG', 'FAKE_MUSE_DELAY_MS', 'FAKE_MUSE_LOG', 'FAKE_MUSE_RESUME_LOG', 'FAKE_MUSE_COUNT', 'FAKE_MUSE_PIDFILE', 'FAKE_MUSE_VERSION', 'FAKE_MUSE_VERSION_LOG', 'FAKE_AGY_REPLY', 'FAKE_AGY_WRITE', 'FAKE_AGY_EXIT', 'FAKE_AGY_ERROR', 'FAKE_AGY_LOG', 'FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG')
$testVars = @('CODEX_CONSULT_EXE', 'CODEX_CONSULT_AGY_EXE', 'CODEX_CONSULT_MUSE_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_LOGIN_TIMEOUT', 'META_API_KEY', 'MODEL_API_KEY', 'TBH_CREDENTIAL_BACKEND')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
}
# Every case: the fakes are the launchers, the scratch home / LOCALAPPDATA / PATH above, the file
# credential backend. '' in $Env removes a variable. $Roster '' = CODEX_CONSULT_ROSTER=none.
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:CODEX_CONSULT_MUSE_EXE = $fakeMuse
    $env:CODEX_CONSULT_AGY_EXE = $fakeAgy
    $env:CODEX_CONSULT_EXE = $fakeCodex
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    $env:USERPROFILE = $museHome
    $env:HOME = $museHome
    $env:LOCALAPPDATA = $lad
    $env:TEMP = $savedEnv['TEMP']
    $env:TMP = $savedEnv['TMP']
    $env:TBH_CREDENTIAL_BACKEND = 'file'
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
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [string]$Script = $consultPs)
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $Script -Task t @ArgList 2>&1
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
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (Ledger $Repo)[-1] }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Td { param([string]$Repo, [string]$Rel) return (Join-Path (Join-Path $Repo '.collab\t') ($Rel -replace '/', '\')) }
function Text { param([string]$Path) if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Count-Lines { param([string]$Path) if (Test-Path -LiteralPath $Path) { return @(Get-Content -LiteralPath $Path | Where-Object { $_ }).Count }; return 0 }
function Seed-Task {
    param([string]$Repo, [object[]]$Entries)
    $dir = Join-Path $Repo '.collab\t'
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = 't'; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } })
}
function Uuid { return [guid]::NewGuid().ToString() }
$uuidRe = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
# A copy of the fake launcher in a directory of its own (-EngineExe, the install location).
function Copy-Fake {
    param([string]$Dir, [string]$Name = 'fake-muse.cmd')
    [void][IO.Directory]::CreateDirectory($Dir)
    Copy-Item -LiteralPath $fakeMuse -Destination (Join-Path $Dir $Name) -Force
    Copy-Item -LiteralPath (Join-Path $sp 'fake-muse.ps1') -Destination (Join-Path $Dir 'fake-muse.ps1') -Force
    return (Join-Path $Dir $Name)
}

$museModel = 'muse-spark-1.3'
$museFp = Get-Sha256Hex ($u8.GetBytes('cc-engine-v1|muse'))
$museArgs = @('-Engine', 'muse', '-Model', $museModel)
function New-MuseEntry {
    param([int]$N, [string]$Thread, [string]$Model = 'muse-spark-1.3', [string]$Provider = 'meta')
    return [pscustomobject]@{ n = $N; when = (Get-IsoTimestamp); purpose = ''; reviewer = [pscustomobject]@{ provider = $Provider; model = $Model; engine = 'muse'; provider_fingerprint = $museFp }; lineage = "$Provider :: $Model"; thread = $Thread; thread_source = 'events'; mode = 'new'; reply = ('handoffs/{0:D2}-muse-seed.md' -f $N); bridge_outcome = 'usable reply' }
}
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"c","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
$adviseF = Reply 'advise-finding.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$prose = "**Q1.** The engine table keeps the codex path unchanged for every existing reviewer and adds one row per engine.`n**Q2.** The session rules close the resume gap because a new session is never taken as the parent thread.`n`nVerdict: ADVISE`n"
$proseFile = Reply 'prose.md' $prose
$proseMd = $prose -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n'
$repairedFile = Reply 'repaired.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"the rules hold","reply_markdown":"' + $proseMd + '","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$emptyFile = Reply 'empty.txt' ''
$quotaReason = 'Usage limit reached for your Muse Code plan. Try again in 2 hours.'
$rosterMuse = Write-Roster 'muse' ('{"roster_version":1,"reviewers":[{"provider":"meta","engine":"muse","model":"' + $museModel + '"}]}')
$rosterMuseCodex = Write-Roster 'muse-codex' ('{"roster_version":1,"reviewers":[{"provider":"meta","engine":"muse","model":"' + $museModel + '"},{"provider":"openai","model":"gpt-5.1"}]}')

# Never a real muse: with the harness environment and no CODEX_CONSULT_MUSE_EXE, no launcher may
# resolve (PATH, the install location) - otherwise the harness refuses to run at all.
Set-CaseEnv '' @{ CODEX_CONSULT_MUSE_EXE = '' }
$realMuse = Resolve-EngineLauncher -Engine 'muse'
Restore-Env
if ($realMuse) {
    Write-Host "FAIL SAFETY   a real muse launcher resolves in the test environment ($realMuse); the harness refuses to run."
    Remove-TestWork $work
    Write-Host ("harness-muse ({0} {1}): 0 passed, 1 failure(s)." -f $hostTag, $PSVersionTable.PSVersion)
    exit 1
}

try {
# =============================================================== UNIT: the adapter functions in-process
if (Want 'UNIT') {
    # --- the engine row and the adapter contract (D1, D13)
    $spec = Get-EngineSpec 'muse'
    $fnMissing = @(foreach ($k in @('Argv', 'Stdin', 'Events', 'Outcome', 'Credential', 'Harness', 'IdentityConfig', 'LaunchBlock')) { $fn = [string]$spec.Adapter.$k; if (-not $fn -or -not (Get-Command $fn -ErrorAction SilentlyContinue)) { $k } })
    Check 'UNIT' 'engine row muse: label "Meta Muse (muse)", prefix muse, command muse, CODEX_CONSULT_MUSE_EXE, launchers muse.cmd muse.exe muse, modes new/resume, native|prompt-only, engine:muse, cc-engine-v1|muse, provider meta, no denial retry, prompt by file, every adapter function exists; EngineNames codex, agy, muse' ($spec.Label -eq 'Meta Muse (muse)' -and $spec.Prefix -eq 'muse' -and $spec.Command -eq 'muse' -and $spec.ExeEnv -eq 'CODEX_CONSULT_MUSE_EXE' -and (@($spec.LauncherNames) -join ',') -eq 'muse.cmd,muse.exe,muse' -and (@($spec.Modes) -join ',') -eq 'new,resume' -and (@($spec.Transports) -join ',') -eq 'native,prompt-only' -and $spec.HostName -eq 'engine:muse' -and $spec.CompatString -eq 'cc-engine-v1|muse' -and $spec.DefaultProvider -eq 'meta' -and -not $spec.DenialRetry -and $spec.PromptTransport -eq 'file' -and $fnMissing.Count -eq 0 -and ($script:EngineNames -join ',') -eq 'codex,agy,muse') "missing: $($fnMissing -join ',')"
    # --- argv against the real flag spellings (D1, D15)
    $full = New-MuseArgv -Turn (New-EngineTurnOptions -Model 'muse-spark-1.3' -Mode 'resume' -Thread 'T1' -PromptFile 'C:\p dir\p.txt' -Schema 'C:\s.json' -Effort 'xhigh' -MaxSteps 40)
    $min = New-MuseArgv -Turn (New-EngineTurnOptions -Model 'muse-spark-1.3-contributor' -PromptFile 'P')
    Check 'UNIT' 'New-MuseArgv: exec --json --prompt-file <P> --output-schema <S> --model <m> --reasoning-effort <e> --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never --max-model-steps <n> --session-id <t>; the minimal turn drops schema, effort, steps and session' (($full -join '|') -eq 'exec|--json|--prompt-file|C:\p dir\p.txt|--output-schema|C:\s.json|--model|muse-spark-1.3|--reasoning-effort|xhigh|--no-foreign-personal-context|--disable-web-tools|--disable-write|--disable-shell|--approval-mode|never|--max-model-steps|40|--session-id|T1' -and ($min -join '|') -eq 'exec|--json|--prompt-file|P|--model|muse-spark-1.3-contributor|--no-foreign-personal-context|--disable-web-tools|--disable-write|--disable-shell|--approval-mode|never' -and (ConvertTo-MuseStdin -Prompt 'x') -eq '') ($full -join ' ')
    $agyA = New-AgyArgv -Turn (New-EngineTurnOptions -Model 'gemini-3.8-flash-high' -Thread 'T2' -PromptFile 'ignored' -Schema 'S' -NativeEffort 'high')
    Check 'UNIT' 'D1: New-AgyArgv takes the same turn-options object (prompt file unused - agy reads stdin), argv unchanged' (($agyA -join ' ') -eq '-p= --input-format stream-json --output-format stream-json --model gemini-3.8-flash-high --json-schema S --print-timeout 0 --sandbox --disable-slash-commands --conversation T2 --effort high') ($agyA -join ' ')
    # --- D2: no turn of codex-consult.ps1 calls an engine's functions by name
    $cc = [IO.File]::ReadAllText($consultPs, $u8)
    $byName = [regex]::Matches($cc, 'Read-AgyEvents|Get-AgyTurnOutcome|New-AgyArgv|ConvertTo-AgyStdin|Read-MuseEvents|Get-MuseTurnOutcome|New-MuseArgv').Count
    $viaAdapter = [regex]::Matches($cc, '& \$engineSpec\.Adapter\.(Events|Outcome) ').Count
    $argvCalls = [regex]::Matches($cc, '& \$engineSpec\.Adapter\.Argv -Turn \$').Count
    Check 'UNIT' 'D2 (every engine): codex-consult.ps1 names no engine''s parser, outcome or argv function - the main turn, the denial retry, the format repair and (wave 24) the timeout continuation all go through $engineSpec.Adapter (4 Argv calls with -Turn, Events/Outcome for each turn)' ($byName -eq 0 -and $argvCalls -eq 4 -and $viaAdapter -ge 9) "by name $byName, argv $argvCalls, events/outcome $viaAdapter"
    # --- effort (D10)
    $mid = { param([string]$M) [pscustomobject]@{ HostName = 'engine:muse'; Model = $M; ModelSource = '-Model' } }
    $sent = @(foreach ($lvl in @('low', 'medium', 'high', 'xhigh')) { (Resolve-EffortPlan -Identity (& $mid 'muse-spark-1.3') -Requested $lvl).Sent })
    $contrib = Resolve-EffortPlan -Identity (& $mid 'muse-spark-1.3-contributor') -Requested 'medium'
    $old = Resolve-EffortPlan -Identity (& $mid 'muse-spark-1.2') -Requested 'high'
    $nat = Resolve-EffortPlan -Identity (& $mid 'muse-spark-1.2') -Requested 'high' -Native 'max'
    Check 'UNIT' 'D10: caps-v1 engine:muse = vocabulary muse (mapping muse-v1) for muse-spark-1.3 and -contributor only: low medium high xhigh as is; muse-spark-1.2 has no vocabulary (refused unless -NativeEffort, then verbatim); SchemaTransport native; the repair effort is low' (($sent -join ',') -eq 'low,medium,high,xhigh' -and (Resolve-EffortPlan -Identity (& $mid 'muse-spark-1.3') -Requested 'high').Mapping -eq 'muse-v1' -and $contrib.Sent -eq 'medium' -and $old.Error -match "^no effort vocabulary declared for model 'muse-spark-1\.2' on engine:muse" -and $nat.Sent -eq 'max' -and $nat.Mapping -eq 'native' -and (Get-SchemaTransport -Identity (& $mid 'x')).Transport -eq 'native' -and (Get-RepairEffort -Identity (& $mid 'muse-spark-1.3') -EffortPlan (Resolve-EffortPlan -Identity (& $mid 'muse-spark-1.3') -Requested 'xhigh')) -eq 'low') "$($sent -join ',') | $($old.Error)"
    $script:EffortCaps['engine:unit-test'] = @{ Vocabulary = 'no-such-vocabulary'; Models = $null; SchemaTransport = 'native' }
    $missing = Resolve-EffortPlan -Identity ([pscustomobject]@{ HostName = 'engine:unit-test'; Model = 'x'; ModelSource = '-Model' }) -Requested 'high'
    $script:EffortCaps.Remove('engine:unit-test')
    Check 'UNIT' 'D10: a caps row whose vocabulary is not declared is a loud plan error (never a silently empty mapping)' ($missing.Error -eq "caps-v1 names the effort vocabulary 'no-such-vocabulary' for engine:unit-test, but no such vocabulary is declared (a bridge defect); pass -NativeEffort <value> to send a value verbatim" -and -not $missing.Mapping) $missing.Error

    # --- MSP extraction invariants (D6)
    $script:mspSeq = 0
    $s1 = Uuid
    function Msp {
        param([string]$PayloadType, $Payload, $Sv = 1, [string]$Kind = 'session', [string]$Id = $s1)
        $script:mspSeq++
        return (ConvertTo-Json -Compress -Depth 10 -InputObject ([pscustomobject][ordered]@{ schema_version = $Sv; id = "018f0000-0000-7000-8000-00000000c3$($script:mspSeq)"; stream = [pscustomobject][ordered]@{ kind = $Kind; id = $Id }; sequence = $script:mspSeq; record_type = 'event'; payload_type = $PayloadType; payload = $Payload }))
    }
    function Msp-File { param([string]$Name, [string[]]$Lines, [string]$Tail = "`n") $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, (($Lines -join "`n") + $Tail), $u8); return $p }
    # (the real CLI's shape: every record on the session stream, the run named in
    # payload.run_stream {kind run, id} and linked to the session by session.run.linked)
    $r1 = Uuid
    $runRef = [pscustomobject][ordered]@{ kind = 'run'; id = $r1 }
    $mAccept = Msp 'runtime.command.accepted' ([pscustomobject]@{ kind = 'command_accepted'; command_kind = 'turn.submit' })
    $mLink = Msp 'session.run.linked' ([pscustomobject][ordered]@{ kind = 'session_run_linked'; run_stream = $runRef })
    $mModel = Msp 'run.model.configured' ([pscustomobject][ordered]@{ kind = 'run_model_configured'; run_stream = $runRef; provider_id = 'meta'; model_id = 'muse-spark-1.3'; source = 'startup' })
    $mDelta = Msp 'run.output.delta' ([pscustomobject][ordered]@{ kind = 'run_output_delta'; run_stream = $runRef; text = '{"a"' })
    $mDone = Msp 'run.terminal.completed' ([pscustomobject][ordered]@{ kind = 'run_terminal'; run_stream = $runRef; terminal = 'completed'; text = '{"a":1}'; reason = $null })
    $good = Read-MuseEvents -Path (Msp-File 'msp-good.jsonl' @($mAccept, $mLink, $mModel, $mDelta, $mDone))
    Check 'UNIT' 'Read-MuseEvents: one session (the stream id of kind session), schema_version 1, one terminal, text = the terminal''s text (never the deltas), models = run.model.configured, usage null; RunStream = the run the session links (wave 23b)' ($good.Records -eq 5 -and $good.RunStream -eq "run $r1" -and -not $good.Malformed -and $good.SchemaVersion -eq 1 -and $good.Session -eq $s1 -and $good.Thread -eq $s1 -and $good.TerminalCount -eq 1 -and $good.Terminal -eq 'completed' -and $good.Text -eq '{"a":1}' -and (@($good.Models) -join ',') -eq 'muse-spark-1.3' -and $null -eq $good.Usage) "$($good.Malformed) $($good.Session)"
    $bad = [ordered]@{
        'schema_version 2'      = @(@((Msp 'runtime.command.accepted' ([pscustomobject]@{ kind = 'x' }) 2), $mDone), '^unsupported MSP version 2 \(the bridge reads MSP 1\)$')
        'no schema_version'     = @(@(('{"id":"r","stream":{"kind":"session","id":"' + $s1 + '"},"payload_type":"x","payload":{}}'), $mDone), '^the record at line 1 has no integer schema_version$')
        'two sessions'          = @(@($mAccept, (Msp 'run.model.configured' ([pscustomobject]@{ kind = 'run_model_configured'; model_id = 'm' }) 1 'session' (Uuid)), $mDone), '^2 session streams \(exactly one expected\): ')
        'two terminals'         = @(@($mAccept, $mDone, $mDone), '^2 run_terminal records \(exactly one expected\)$')
        'terminal off-session'  = @(@($mAccept, (Msp 'run.terminal.completed' ([pscustomobject]@{ kind = 'run_terminal'; terminal = 'completed'; text = 't' }) 1 'run' (Uuid))), '^the run_terminal record at line 2 is on stream run [0-9a-f-]{36}, not on the session stream$')
        'a line that is no JSON' = @(@($mAccept, 'not json at all', $mDone), '^line 2 is not a JSON object$')
    }
    $badOut = @()
    $i = 0
    foreach ($k in $bad.Keys) {
        $i++
        $ev = Read-MuseEvents -Path (Msp-File "msp-bad-$i.jsonl" $bad[$k][0])
        if ($ev.Malformed -notmatch $bad[$k][1]) { $badOut += "$k -> [$($ev.Malformed)]" }
    }
    $partial = Msp-File 'msp-partial.jsonl' @($mAccept, $mLink, $mModel, $mDone, '{"schema_version":1,"id":"018f') ''
    $p0 = Read-MuseEvents -Path $partial
    $p1 = Read-MuseEvents -Path $partial -AllowPartialLast
    Check 'UNIT' "Read-MuseEvents malformed (fail closed): $(@($bad.Keys) -join ', '); a truncated LAST line only with -AllowPartialLast (after a kill or a non-zero exit)" ($badOut.Count -eq 0 -and $p0.Malformed -eq 'line 5 is not a JSON object' -and -not $p1.Malformed -and $p1.Terminal -eq 'completed') (($badOut -join ' | ') + " | partial: [$($p0.Malformed)] [$($p1.Malformed)]")
    # --- (wave 23b, F09-3) the provenance of the evidence: the session = the ONE stream of kind
    # session, its run = the one its session.run.linked record names; the model evidence and the
    # reply must be bound to that run on that stream
    $sub = Uuid
    $r2 = Uuid
    $otherRef = [pscustomobject][ordered]@{ kind = 'run'; id = $r2 }
    $prov = [ordered]@{
        'model on a sub-stream'   = @(@($mAccept, $mLink, (Msp 'run.model.configured' ([pscustomobject][ordered]@{ kind = 'run_model_configured'; run_stream = $runRef; model_id = 'muse-spark-1.3' }) 1 'task' $sub), $mDone), "^ambiguous provenance: the run\.model\.configured record at line 3 is on stream task $sub, not on the session stream$")
        'model of another run'    = @(@($mAccept, $mLink, (Msp 'run.model.configured' ([pscustomobject][ordered]@{ kind = 'run_model_configured'; run_stream = $otherRef; model_id = 'muse-spark-1.3' })), $mDone), "^ambiguous provenance: the run\.model\.configured record at line 3 names stream run $r2, not the run linked to the session \(run $r1\)$")
        'model, no run linked'    = @(@($mAccept, $mModel, $mDone), "^ambiguous provenance: the run\.model\.configured record at line 2 names stream run $r1, but no session\.run\.linked record links a run to the session$")
        'link on a sub-stream'    = @(@($mAccept, (Msp 'session.run.linked' ([pscustomobject][ordered]@{ kind = 'session_run_linked'; run_stream = $runRef }) 1 'task' $sub), $mModel, $mDone), "^ambiguous provenance: the session\.run\.linked record at line 2 is on stream task $sub, not on the session stream$")
        'link names no run'       = @(@($mAccept, (Msp 'session.run.linked' ([pscustomobject][ordered]@{ kind = 'session_run_linked' })), $mModel, $mDone), '^ambiguous provenance: the session\.run\.linked record at line 2 names no run stream$')
        'two runs linked'         = @(@($mAccept, $mLink, (Msp 'session.run.linked' ([pscustomobject][ordered]@{ kind = 'session_run_linked'; run_stream = $otherRef })), $mModel, $mDone), "^ambiguous provenance: 2 run streams linked to the session \(exactly one expected\): run $r1, run $r2$")
        'reply of another run'    = @(@($mAccept, $mLink, $mModel, (Msp 'run.terminal.completed' ([pscustomobject][ordered]@{ kind = 'run_terminal'; run_stream = $otherRef; terminal = 'completed'; text = '{"a":1}'; reason = $null }))), "^ambiguous provenance: the run_terminal record at line 4 names stream run $r2, not the run linked to the session \(run $r1\)$")
        'a nested session record' = @(@($mAccept, $mLink, $mModel, (Msp 'run.model.configured' ([pscustomobject][ordered]@{ kind = 'run_model_configured'; run_stream = $runRef; model_id = 'muse-spark-1.3' }) 1 'session' $sub), $mDone), "^2 session streams \(exactly one expected\): $s1, $sub$")
    }
    $provOut = @()
    $provEv = $null
    $i = 0
    foreach ($k in $prov.Keys) {
        $i++
        $ev = Read-MuseEvents -Path (Msp-File "msp-prov-$i.jsonl" $prov[$k][0])
        if ($ev.Malformed -notmatch $prov[$k][1] -or $ev.RunStream) { $provOut += "$k -> [$($ev.Malformed)] run [$($ev.RunStream)]" }
        if ($i -eq 1) { $provEv = $ev }
    }
    $provO = Get-MuseTurnOutcome -Events $provEv -ExitCode 0 -ExpectModel 'muse-spark-1.3'
    Check 'UNIT' "F09-3 (wave 23b): evidence of foreign provenance is a malformed stream (fail closed, ""ambiguous provenance: ...""): $(@($prov.Keys) -join ', '); the turn fails as class transport with the session a candidate only" ($provOut.Count -eq 0 -and $provO.Outcome -match '^failed: malformed event stream: ambiguous provenance: the run\.model\.configured record at line 3 is on stream task ' -and $provO.Class -eq 'transport' -and $provO.Thread -eq '' -and $provO.ThreadCandidate -eq $s1) (($provOut -join ' | ') + " | $($provO.Outcome)")
    # --- the failure rules (D6, D7)
    $okEv = $good
    $info = "muse: workspace root: C:\x (cwd default)`nmuse: Agent delegation: auto unavailable: workspace is untrusted."
    $o0 = Get-MuseTurnOutcome -Events $okEv -ExitCode 0 -StderrText "$info`nwarning: something to note" -ExpectModel 'muse-spark-1.3'
    $oDrift = Get-MuseTurnOutcome -Events $okEv -ExitCode 0 -ExpectModel 'muse-spark-1.3-contributor'
    $oNoModel = Get-MuseTurnOutcome -Events (Read-MuseEvents -Path (Msp-File 'msp-nomodel.jsonl' @($mAccept, $mLink, $mDone))) -ExitCode 0 -ExpectModel 'muse-spark-1.3'
    $oExpect = Get-MuseTurnOutcome -Events $okEv -ExitCode 0 -ExpectThread (Uuid) -ExpectModel 'muse-spark-1.3'
    Check 'UNIT' 'Get-MuseTurnOutcome: usable (thread = the session; a `warning:` line is a Warning, the two informational stderr lines are not); served model != asked -> "model drift: asked X, served Y" (capability, candidate only); no run.model.configured -> failed (unknown); another session on resume -> "parent session <p> not found, muse started <s>" (unknown, candidate)' ($o0.Ok -and $o0.Thread -eq $s1 -and (@($o0.Warnings) -join '|') -eq 'warning: something to note' -and -not $o0.DeniedEmpty -and $oDrift.Outcome -eq 'failed: model drift: asked muse-spark-1.3-contributor, served muse-spark-1.3' -and $oDrift.Class -eq 'capability' -and $oDrift.Thread -eq '' -and $oDrift.ThreadCandidate -eq $s1 -and $oNoModel.Outcome -eq 'failed: the muse event stream names no configured model (run.model.configured; asked muse-spark-1.3)' -and $oNoModel.Class -eq 'unknown' -and $oExpect.Outcome -match "^failed: parent session [0-9a-f-]{36} not found, muse started $s1$" -and $oExpect.Class -eq 'unknown' -and $oExpect.ThreadCandidate -eq $s1) "$($o0.Outcome) | $($oDrift.Outcome) | $($oExpect.Outcome)"
    $empty = [pscustomobject]@{ Records = 0; Malformed = ''; SchemaVersion = $null; Sessions = [string[]]@(); Session = ''; Thread = ''; TerminalCount = 0; HasTerminal = $false; Terminal = ''; Text = ''; Reason = ''; Models = [string[]]@(); Error = ''; Usage = $null; ToolName = ''; DeniedAction = '' }
    $e2 = Get-MuseTurnOutcome -Events $empty -ExitCode 2 -StderrText "$info`nerror: unexpected argument '--foo' found`n`nUsage: muse exec [OPTIONS]`n`nFor more information, try '--help'."
    $e130 = Get-MuseTurnOutcome -Events $empty -ExitCode 130 -StderrText $info
    $e143 = Get-MuseTurnOutcome -Events $empty -ExitCode 143
    $failedEv = Read-MuseEvents -Path (Msp-File 'msp-failed.jsonl' @($mAccept, $mLink, $mModel, (Msp 'run.terminal.failed' ([pscustomobject]@{ kind = 'run_terminal'; run_stream = $runRef; terminal = 'failed'; text = $null; reason = 'max_model_steps reached (40)' }))))
    $eCap = Get-MuseTurnOutcome -Events $failedEv -ExitCode 1 -StderrText $info
    $eCap0 = Get-MuseTurnOutcome -Events $failedEv -ExitCode 0 -StderrText $info
    $noTerm = Get-MuseTurnOutcome -Events (Read-MuseEvents -Path (Msp-File 'msp-noterm.jsonl' @($mAccept, $mLink, $mModel))) -ExitCode 0 -StderrText $info
    Check 'UNIT' 'D7: exit 2 -> "muse exit 2 (usage error) - error: ..." (capability; the error line, not the usage boilerplate); 130/143 -> transport; a failed terminal naming the step cap -> "max model steps reached" (capability, exit 1 or 0); no terminal -> failed, the informational stderr lines never its detail' ($e2.Outcome -eq "failed: muse exit 2 (usage error) - error: unexpected argument '--foo' found" -and $e2.Class -eq 'capability' -and $e130.Outcome -eq 'failed: muse exit 130 (stopped by a signal)' -and $e130.Class -eq 'transport' -and $e143.Class -eq 'transport' -and $eCap.Outcome -eq 'failed: muse exit 1 - max model steps reached (max_model_steps reached (40))' -and $eCap.Class -eq 'capability' -and $eCap0.Outcome -eq 'failed: muse terminal failed - max model steps reached (max_model_steps reached (40))' -and $eCap0.Class -eq 'capability' -and $noTerm.Outcome -eq 'failed: no run_terminal record in the muse event stream' -and $noTerm.Class -eq '') "$($e2.Outcome) | $($eCap.Outcome) | $($noTerm.Outcome)"
    $quotaEv = Read-MuseEvents -Path (Msp-File 'msp-quota.jsonl' @($mAccept, $mLink, $mModel, (Msp 'run.terminal.failed' ([pscustomobject]@{ kind = 'run_terminal'; run_stream = $runRef; terminal = 'failed'; text = $null; reason = $quotaReason }))))
    $qo = Get-MuseTurnOutcome -Events $quotaEv -ExitCode 1 -StderrText $info
    $qf = New-ProviderFailure -Texts @(@($qo.Texts) + @(($qo.Outcome -replace '^failed:\s*', ''))) -Class $qo.Class
    $qAt = [DateTimeOffset]::Parse([string]$qf.retry_after, [Globalization.CultureInfo]::InvariantCulture)
    $qDelta = ($qAt - [DateTimeOffset]::Now).TotalMinutes
    Check 'UNIT' 'D7: a failed terminal with Meta''s quota wording is recorded VERBATIM and classified by the shared classifier: class quota, retry_after = now + the named 2 hours' ($qo.Outcome -eq "failed: muse exit 1 - $quotaReason" -and $qf.class -eq 'quota' -and $qf.message -eq $quotaReason -and $qDelta -gt 115 -and $qDelta -le 121) "$($qf.class) $($qf.retry_after) $($qf.message)"

    # --- the sign-in (D5) and the billing guard (D4), in this process with a scratch home
    $credCase = {
        param([string]$Backend, [string]$Json, [switch]$NoFile)
        $script:MuseCredentialCache = @{}
        $env:USERPROFILE = $museHome; $env:HOME = $museHome
        if ($Backend) { $env:TBH_CREDENTIAL_BACKEND = $Backend } else { Remove-Item env:TBH_CREDENTIAL_BACKEND -ErrorAction SilentlyContinue }
        if ($NoFile) { Write-Auth '' } else { Write-Auth $Json }
        $c = Get-MuseCredentialInfo
        $s = Get-MuseSignIn
        $b = Get-MuseLaunchBlock
        $m = (Get-MuseIdentityConfig)['credential_mechanism']
        Restore-Env
        Write-Auth $authOauth
        $script:MuseCredentialCache = @{}
        return [pscustomobject]@{ Info = $c; SignIn = $s; Block = $b; Mechanism = $m }
    }
    $cOk = & $credCase 'file' $authOauth
    $cMissing = & $credCase 'file' '' -NoFile
    $cKeychain = & $credCase '' $authOauth
    $cNoMeta = & $credCase 'file' '{"providers":{"google":{"mechanism":"oauth"}}}'
    $cNoMech = & $credCase 'file' ('{"providers":{"meta":{"access_token":"' + $tokenMark + '"}}}')
    $cBadJson = & $credCase 'file' ('{"providers":{"meta":{"access_token":"' + $tokenMark + '" BROKEN')
    $cApi = & $credCase 'file' ('{"providers":{"meta":{"api_key":"' + $tokenMark + '","mechanism":"api_key"}}}')
    $cOdd = & $credCase 'file' ('{"providers":{"meta":{"mechanism":"' + $tokenMark + ' with spaces"}}}')
    $cKc2 = & $credCase 'keychain' $authOauth
    $allText = (@($cOk, $cMissing, $cKeychain, $cNoMeta, $cNoMech, $cBadJson, $cApi, $cOdd, $cKc2) | ForEach-Object { "$($_.SignIn.Detail) $($_.Block) $($_.Mechanism)" }) -join ' '
    Check 'UNIT' 'D5 sign-in states: ok "signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth)"; no file -> missing ("run `muse login` with TBH_CREDENTIAL_BACKEND=file"); keychain backend -> unknown (not checkable); no providers.meta -> missing; no mechanism / not JSON -> unknown' ($cOk.SignIn.Detail -eq 'ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth)' -and $cOk.Mechanism -eq 'oauth' -and $cMissing.SignIn.Detail -eq 'missing: not signed in: ~/.config/muse/auth.json does not exist (run `muse login` with TBH_CREDENTIAL_BACKEND=file)' -and $cKeychain.SignIn.State -eq 'unknown' -and $cKeychain.SignIn.Reason -match '^sign-in not checkable: TBH_CREDENTIAL_BACKEND is not set \(the keychain backend cannot be read; set TBH_CREDENTIAL_BACKEND=file - required on Windows' -and $null -eq $cKeychain.Mechanism -and $cNoMeta.SignIn.Detail -eq 'missing: not signed in: ~/.config/muse/auth.json has no Meta sign-in (providers.meta; run `muse login`)' -and $cNoMech.SignIn.Detail -eq 'unknown: sign-in not checkable: providers.meta in ~/.config/muse/auth.json names no mechanism' -and $cBadJson.SignIn.Detail -eq 'unknown: sign-in not checkable: ~/.config/muse/auth.json does not parse as JSON') "$($cOk.SignIn.Detail) | $($cKeychain.SignIn.Detail)"
    Check 'UNIT' 'D4: a mechanism other than oauth refuses the launch ("uses mechanism ''api_key'', not oauth"); a value that is no short identifier is "unrecognized" and refused; the credential''s VALUES never appear in any result (only key names and the mechanism enum)' ($cApi.Block -eq "the Muse sign-in in ~/.config/muse/auth.json uses mechanism 'api_key', not oauth: a muse run would not bill the Muse Code subscription; sign in with ``muse login``" -and $cOdd.Mechanism -eq 'unrecognized' -and $cOdd.Block -match "mechanism 'unrecognized'" -and $cOk.Block -eq '' -and -not $allText.Contains($tokenMark)) $cApi.Block
    $est = 'a muse run might bill per token instead of the Muse Code subscription; set TBH_CREDENTIAL_BACKEND=file and run `muse login`'
    Check 'UNIT' 'F09-1 (wave 23b, fail-closed): a launch needs an ESTABLISHED oauth sign-in - the keychain backend (not set / ''keychain''), no auth.json, no providers.meta, no mechanism, a file that does not parse -> "the Muse sign-in is not established as oauth (<cause>): a muse run might bill per token ...; set TBH_CREDENTIAL_BACKEND=file and run `muse login`"; oauth -> no refusal' ($cKeychain.Block -eq "the Muse sign-in is not established as oauth (TBH_CREDENTIAL_BACKEND is not set: the keychain backend cannot be read): $est" -and $cKc2.Block -eq "the Muse sign-in is not established as oauth (TBH_CREDENTIAL_BACKEND is 'keychain': the keychain backend cannot be read): $est" -and $cMissing.Block -eq "the Muse sign-in is not established as oauth (~/.config/muse/auth.json does not exist): $est" -and $cNoMeta.Block -eq "the Muse sign-in is not established as oauth (~/.config/muse/auth.json has no Meta sign-in (providers.meta)): $est" -and $cNoMech.Block -eq "the Muse sign-in is not established as oauth (providers.meta in ~/.config/muse/auth.json names no mechanism): $est" -and $cBadJson.Block -eq "the Muse sign-in is not established as oauth (~/.config/muse/auth.json does not parse as JSON): $est" -and $cOk.Block -eq '' -and $null -eq $cKeychain.Mechanism) "$($cKeychain.Block) | $($cNoMech.Block)"
    $blocks = @(foreach ($name in @('META_API_KEY', 'MODEL_API_KEY')) {
            $script:MuseCredentialCache = @{}
            Set-Item "env:$name" 'fake-key-value-4711'
            $env:USERPROFILE = $museHome; $env:TBH_CREDENTIAL_BACKEND = 'file'
            $b = Get-MuseLaunchBlock
            $eb = Get-EngineLaunchBlock -Engine 'muse'
            $ab = Get-EngineLaunchBlock -Engine 'agy'
            Restore-Env
            [pscustomobject]@{ Name = $name; Block = $b; Engine = $eb; Agy = $ab }
        })
    $script:MuseCredentialCache = @{}
    Check 'UNIT' 'D4: META_API_KEY or MODEL_API_KEY set -> "<NAME> is set: a muse run would bill per token instead of the Muse Code subscription; unset it (the muse process would inherit it)" - the name, never the value; Get-EngineLaunchBlock dispatches it for muse only (agy: none)' ($blocks[0].Block -eq 'META_API_KEY is set: a muse run would bill per token instead of the Muse Code subscription; unset it (the muse process would inherit it)' -and $blocks[1].Block -match '^MODEL_API_KEY is set: ' -and $blocks[0].Engine -eq $blocks[0].Block -and $blocks[0].Agy -eq '' -and -not (($blocks | ForEach-Object { $_.Block }) -join ' ').Contains('fake-key-value-4711')) $blocks[0].Block

    # --- the launcher chain (D3) and -EngineExe's binding
    $instDir = Join-Path $lad 'Programs\muse'
    $inst = Copy-Fake -Dir $instDir -Name 'muse.cmd'
    Set-CaseEnv '' @{ CODEX_CONSULT_MUSE_EXE = '' }
    $fromInstall = Resolve-EngineLauncher -Engine 'muse'
    Restore-Env
    Set-CaseEnv '' @{}
    $fromEnv = Resolve-EngineLauncher -Engine 'muse'
    $explicitCopy = Copy-Fake -Dir (Join-Path $work 'explicit dir')
    $fromExplicit = Resolve-EngineLauncher -Engine 'muse' -Explicit $explicitCopy
    Restore-Env
    Remove-Item -LiteralPath $instDir -Recurse -Force
    Set-CaseEnv '' @{ CODEX_CONSULT_MUSE_EXE = '' }
    $none = Resolve-EngineLauncher -Engine 'muse'
    Restore-Env
    Check 'UNIT' 'D3: the launcher: -EngineExe, then CODEX_CONSULT_MUSE_EXE, then PATH, then %LOCALAPPDATA%\Programs\muse\muse.cmd (a bridge started before the install does not see the new user PATH); none -> $null' ($fromExplicit -eq $explicitCopy -and $fromEnv -eq $fakeMuse -and $fromInstall -eq $inst -and $null -eq $none) "install=$fromInstall"
    $rMixed = Read-ReviewerRoster -Location ([pscustomobject]@{ Path = (Write-Roster 'bind-mixed' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"gemini-3.8-flash-high"},{"provider":"meta","engine":"muse","model":"' + $museModel + '"},{"provider":"openai","model":"gpt-5.1"}]}')); FromEnv = $true; Disabled = $false })
    $rOne = Read-ReviewerRoster -Location ([pscustomobject]@{ Path = $rosterMuseCodex; FromEnv = $true; Disabled = $false })
    $bE = Resolve-EngineExeBinding -Engine 'muse' -Roster $rMixed
    $bC = Resolve-EngineExeBinding -Engine 'codex' -Roster $rMixed
    $bP = Resolve-EngineExeBinding -Roster $rMixed -Provider 'meta'
    $bPc = Resolve-EngineExeBinding -Roster $rMixed -Provider 'openai'
    $bOne = Resolve-EngineExeBinding -Roster $rOne
    $bAmb = Resolve-EngineExeBinding -Roster $rMixed
    $bNone = Resolve-EngineExeBinding -Roster ([pscustomobject]@{ Exists = $false; Entries = @() })
    Check 'UNIT' 'D3: -EngineExe binds to the SELECTED engine: -Engine muse; -Engine codex refused (-CodexExe); the -Provider''s entry (meta -> muse; openai -> refused); the only non-codex engine of the roster; several -> refused as ambiguous; none -> "pass -Engine <agy|muse>"' ($bE.Engine -eq 'muse' -and $bC.Error -eq '-EngineExe names the launcher of an engine other than codex (agy, muse); codex takes -CodexExe' -and $bP.Engine -eq 'muse' -and $bPc.Error -match '^-EngineExe: the roster entry 3 for -Provider openai is engine codex' -and $bOne.Engine -eq 'muse' -and $bAmb.Error -eq '-EngineExe is ambiguous: the reviewer roster has entries of the engines agy and muse; pass -Engine <agy|muse> to name the one it launches' -and $bNone.Error -eq '-EngineExe names the launcher of an engine other than codex: pass -Engine <agy|muse> with it') "$($bAmb.Error) | $($bNone.Error)"
    # --- the harness string (D8)
    $vdir = Join-Path $work 'versioned'
    $vl = Copy-Fake -Dir $vdir -Name 'muse.cmd'
    [IO.File]::WriteAllText((Join-Path $vdir '.muse-version'), "1.4.0-R4161.1`n", $u8)
    $vlog = Join-Path $work 'version-calls.log'
    $env:FAKE_MUSE_VERSION_LOG = $vlog
    $script:MuseHarnessCache = @{}
    $h1 = Get-MuseHarness -Launcher $vl
    Remove-Item -LiteralPath (Join-Path $vdir '.muse-version')
    [IO.File]::WriteAllText((Join-Path $vdir '.muse-release-info.json'), '{"channel":"stable","version":"1.4.1-R5000.2","state":"installed"}', $u8)
    $script:MuseHarnessCache = @{}
    $h2 = Get-MuseHarness -Launcher $vl
    $callsBefore = Count-Lines $vlog
    Remove-Item -LiteralPath (Join-Path $vdir '.muse-release-info.json')
    $script:MuseHarnessCache = @{}
    $h3 = Get-MuseHarness -Launcher $vl
    $h3b = Get-MuseHarness -Launcher $vl
    $callsAfter = Count-Lines $vlog
    Remove-Item env:FAKE_MUSE_VERSION_LOG
    $script:MuseHarnessCache = @{}
    Check 'UNIT' 'D8: reviewer.harness "muse-cli <version>" from .muse-version next to the launcher, else .muse-release-info.json''s version (no process started for either), else `<launcher> --version` (once per launcher: cached)' ($h1 -eq 'muse-cli 1.4.0-R4161.1' -and $h2 -eq 'muse-cli 1.4.1-R5000.2' -and $callsBefore -eq 0 -and $h3 -eq 'muse-cli 9.9.9-fake' -and $h3b -eq $h3 -and $callsAfter -eq 1) "$h1 | $h2 | $h3 | calls $callsBefore/$callsAfter"
    # --- the .cmd %-expansion hazard (F02-14)
    $hz = Get-CmdArgvHazard -Launcher 'C:\x\muse.cmd' -Argv @('exec', '--prompt-file', 'C:\t %APPDATA% x\p.txt')
    Check 'UNIT' 'F02-14: an argument with ''%'' through a .cmd/.bat launcher is refused (cmd.exe expands %VAR% inside quotes); an .exe launcher or no ''%'' -> nothing' ($hz -match "^the launcher C:\\x\\muse\.cmd is a cmd\.exe script and 1 argument\(s\) contain '%' \(C:\\t %APPDATA% x\\p\.txt\)" -and (Get-CmdArgvHazard -Launcher 'C:\x\muse.exe' -Argv @('a%b')) -eq '' -and (Get-CmdArgvHazard -Launcher 'C:\x\muse.cmd' -Argv @('plain')) -eq '') $hz
}

# =============================================================== ROSTER: engine muse (D13)
if (Want 'ROSTER') {
    $r = New-Repo 'roster'
    $unknown = Consult $r (Write-Roster 'bad-engine' '{"roster_version":1,"reviewers":[{"provider":"meta","engine":"muse-cli","model":"m"}]}') @('-DryRun', '-Prompt', 'x')
    $nomodel = Consult $r (Write-Roster 'bad-nomodel' '{"roster_version":1,"reviewers":[{"provider":"meta","engine":"muse"}]}') @('-DryRun', '-Prompt', 'x')
    Check 'ROSTER' 'roster validation: "engine" must be one of codex, agy, muse; engine muse needs a model (e.g. muse-spark-1.3)' ($unknown.Code -eq 1 -and $unknown.First -match 'entry 1: engine must be one of: codex, agy, muse \(got "muse-cli"\)' -and $nomodel.Code -eq 1 -and $nomodel.First -match 'entry 1: engine muse needs a model \(the full model id, e\.g\. muse-spark-1\.3\)') "$($unknown.First) | $($nomodel.First)"
    $d = Consult $r $rosterMuseCodex @('-DryRun', '-Prompt', 'x')
    Check 'ROSTER' 'the walk selects the muse entry: engine from the roster, lineage "meta :: muse-spark-1.3 [muse]", roster.applied [engine, model]' ($d.Code -eq 0 -and $d.Preview.reviewer.engine -eq 'muse' -and $d.Preview.reviewer.provider -eq 'meta' -and $d.Out -match '(?m)^lineage     : meta :: muse-spark-1\.3 \[muse\]$' -and $d.Out -match '(?m)^engine      : muse - Meta Muse \(muse\) \(from roster\)$' -and (@($d.Preview.roster.applied) -join ',') -eq 'engine,model') (Line $d.Out 'lineage')
}

# =============================================================== DRYRUN: argv, identity, wording, refusals (D1, D9, D11)
if (Want 'DRYRUN') {
    $r = New-Repo 'dry'
    $base = @('-DryRun') + $museArgs + @('-Prompt', 'smoke', '-Purpose', 'framing')
    $d = Consult $r '' $base
    $cmdRe = '^muse exec --json --prompt-file .+codex-consult-prompt-[0-9a-f]{32}\.txt"? --output-schema ' + [regex]::Escape($schemaPath) + ' --model muse-spark-1\.3 --reasoning-effort high --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never$'
    Check 'DRYRUN' 'argv pinned to the real flags: muse exec --json --prompt-file <the turn''s prompt file> --output-schema <schema> --model muse-spark-1.3 --reasoning-effort high --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never (no --max-model-steps, no --session-id)' ($d.Code -eq 0 -and $d.Preview.command -match $cmdRe) $d.Preview.command
    Check 'DRYRUN' 'identity: provider meta (engine default), engine muse, fingerprint sha256(cc-engine-v1|muse), provider_config {engine, launcher, credential_mechanism oauth}, harness muse-cli 9.9.9-fake; effort high (mapping muse-v1); transport native; preflight ok from auth.json' ($d.Preview.reviewer.engine -eq 'muse' -and $d.Preview.reviewer.provider -eq 'meta' -and $d.Preview.reviewer.provider_source -eq 'engine default' -and $d.Preview.reviewer.provider_fingerprint -eq $museFp -and $d.Preview.reviewer.provider_config.launcher -eq $fakeMuse -and $d.Preview.reviewer.provider_config.credential_mechanism -eq 'oauth' -and (($d.Preview.reviewer.provider_config.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'engine,launcher,credential_mechanism' -and $d.Preview.reviewer.harness -eq 'muse-cli 9.9.9-fake' -and $d.Preview.effort_sent -eq 'high' -and $d.Preview.effort_mapping -eq 'muse-v1' -and $d.Preview.schema_transport -eq 'native' -and $d.Out -match '(?m)^preflight   : available \(ok: signed in \(~/\.config/muse/auth\.json: providers\.meta, mechanism oauth\)\)$') (Line $d.Out 'preflight')
    Check 'DRYRUN' 'D11 wording from the engine row: transport "passed as --output-schema, the reply is the run_terminal record''s text", "denial retry: n/a", "max steps   : the muse CLI''s default", the sandbox record, the prompt file line, the reply source, the tools line of the prompt' ($d.Out -match '(?m)^transport   : native \(caps-v1: engine:muse\): passed as --output-schema, the reply is the run_terminal record''s text \(run\.terminal\.completed\) \(validated locally too\)$' -and $d.Out -match '(?m)^denial retry: n/a \(the muse engine runs with its write, shell and web tools disabled - nothing is auto-denied\)$' -and $d.Out -match '(?m)^max steps   : the muse CLI''s default \(no --max-model-steps\)$' -and $d.Preview.sandbox -eq 'read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads)' -and $d.Out -match '(?m)^prompt file : .+codex-consult-prompt-[0-9a-f]{32}\.txt \(the prompt below, UTF-8 without BOM, written at launch; stdin is empty\)$' -and $d.Out -match '(?m)^prompt \(--prompt-file, \d+ chars\):$' -and $d.Out -match '(?m)^reply source: the run_terminal record''s text \(run\.terminal\.completed\), extracted to the reply json before validation$' -and $d.Out.Contains('Tools: you may read files of the repository (read_file); writing files, the shell and the web tools are disabled in this consultation (--disable-write --disable-shell --disable-web-tools) - do not try them; make NO file changes; a check that needs a command belongs under `## Requested checks`.') -and $d.Out -notmatch 'run_command') (Line $d.Out 'transport')
    Check 'DRYRUN' 'the preview: denial_retry null, usage null (MSP has no token usage), engine_run {turns <placeholder>, max_model_steps null, msp_schema_version <placeholder>}, reply NN-muse-reply.*' ($null -eq $d.Preview.denial_retry -and $null -eq $d.Preview.usage -and $null -ne $d.Preview.engine_run -and $null -eq $d.Preview.engine_run.max_model_steps -and [string]$d.Preview.engine_run.msp_schema_version -match 'MSP' -and $d.Preview.reply -match '^handoffs/\d\d-muse-reply\.md$' -and $d.Preview.events -match '^handoffs/\d\d-muse-reply\.events\.jsonl$') $d.Preview.reply
    $ms = Consult $r '' ($base + @('-MaxModelSteps', '40'))
    Check 'DRYRUN' 'D9: -MaxModelSteps 40 -> --max-model-steps 40 after --approval-mode never; "max steps   : 40 (--max-model-steps)"; engine_run.max_model_steps 40' ($ms.Code -eq 0 -and $ms.Preview.command -match ' --approval-mode never --max-model-steps 40$' -and $ms.Out -match '(?m)^max steps   : 40 \(--max-model-steps\)$' -and $ms.Preview.engine_run.max_model_steps -eq 40) $ms.Preview.command
    $refusals = [ordered]@{
        'steps with agy'   = @(@('-DryRun', '-Engine', 'agy', '-Model', 'gemini-3.8-flash-high', '-Prompt', 'x', '-MaxModelSteps', '40'), '^codex-consult: -MaxModelSteps is for the muse engine \(--max-model-steps\); the agy engine has no model-step cap\.$')
        'steps with codex' = @(@('-DryRun', '-Prompt', 'x', '-MaxModelSteps', '40'), '^codex-consult: -MaxModelSteps is for the muse engine \(--max-model-steps\); the codex engine has no model-step cap\.$')
        'steps negative'   = @(($base + @('-MaxModelSteps', '-3')), '^codex-consult: -MaxModelSteps must be a positive integer \(got -3\)')
        'fork'             = @(($base + @('-Mode', 'fork')), '^codex-consult: the muse engine has no fork; use -Mode resume or new\.$')
        'workspace-write'  = @(($base + @('-Sandbox', 'workspace-write')), '^codex-consult: -Sandbox workspace-write is refused for the muse engine: consultations are read-only there \(muse runs with --disable-write --disable-shell --disable-web-tools and the bridge''s tree check fails a run that changed anything\)\.$')
        'output-schema'    = @(($base + @('-SchemaTransport', 'output-schema')), '^codex-consult: -SchemaTransport output-schema is refused for the muse engine: it takes native or prompt-only \(native = the schema is passed as --output-schema\)\.$')
        'codex-config'     = @(($base + @('-CodexConfig', 'a=b')), '^codex-consult: -CodexConfig does not apply to the muse engine')
        'model 1.2'        = @(@('-DryRun', '-Engine', 'muse', '-Model', 'muse-spark-1.2', '-Prompt', 'x'), "^codex-consult: no effort vocabulary declared for model 'muse-spark-1\.2' on engine:muse")
    }
    $badR = @()
    foreach ($k in $refusals.Keys) {
        $o = Consult $r '' $refusals[$k][0]
        if (-not ($o.Code -eq 1 -and $o.First -match $refusals[$k][1])) { $badR += "$k -> $($o.First)" }
    }
    Check 'DRYRUN' "refused, one message each: $(@($refusals.Keys) -join ', ')" ($badR.Count -eq 0) ($badR -join ' | ')
    $po = Consult $r '' ($base + @('-SchemaTransport', 'prompt-only'))
    $nat = Consult $r '' @('-DryRun', '-Engine', 'muse', '-Model', 'muse-spark-1.2', '-Prompt', 'x', '-NativeEffort', 'max')
    $chore = Consult $r '' @('-DryRun', '-Engine', 'muse', '-Model', $museModel, '-Prompt', 'find x', '-Purpose', 'chore')
    Check 'DRYRUN' '-SchemaTransport prompt-only -> no --output-schema, the schema in the prompt ("--output-schema is NOT passed"); an undeclared model with -NativeEffort max -> --reasoning-effort max verbatim (mapping native); -Purpose chore -> no schema, effort low' ($po.Code -eq 0 -and $po.Preview.command -notmatch '--output-schema' -and $po.Out.Contains('JSON Schema of the reply:') -and $po.Out -match '(?m)^transport   : prompt-only \(.*\): --output-schema is NOT passed' -and $nat.Code -eq 0 -and $nat.Preview.command -match '--model muse-spark-1\.2 --reasoning-effort max ' -and $nat.Preview.effort_mapping -eq 'native' -and $chore.Code -eq 0 -and $chore.Preview.command -notmatch '--output-schema' -and $chore.Preview.command -match '--reasoning-effort low ') "$($nat.Preview.command)"
}

# =============================================================== ENGINEEXE: -EngineExe bound to the selected engine (D3)
if (Want 'ENGINEEXE') {
    $r = New-Repo 'exe'
    $copy = Copy-Fake -Dir (Join-Path $work 'fake launcher dir')
    $x1 = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x', '-EngineExe', $copy))
    $x2 = Consult $r $rosterMuse @('-DryRun', '-Prompt', 'x', '-EngineExe', $copy)
    Check 'ENGINEEXE' '-Engine muse -EngineExe <a copy in a directory with spaces> -> that launcher (dry-run line, provider_config.launcher, harness from it); without -Engine the roster''s only muse entry binds it' ($x1.Code -eq 0 -and $x1.Out -match ('(?m)^launcher    : ' + [regex]::Escape($copy) + '$') -and $x1.Preview.reviewer.provider_config.launcher -eq $copy -and $x2.Code -eq 0 -and $x2.Preview.reviewer.provider_config.launcher -eq $copy) "$(Line $x1.Out 'launcher') | $($x2.First)"
    $mixed = Write-Roster 'exe-mixed' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"gemini-3.8-flash-high"},{"provider":"meta","engine":"muse","model":"' + $museModel + '"}]}')
    $amb = Consult $r $mixed @('-DryRun', '-Prompt', 'x', '-EngineExe', $copy)
    $viaEngine = Consult $r $mixed @('-DryRun', '-Prompt', 'x', '-Engine', 'muse', '-EngineExe', $copy)
    $cx = Consult $r '' @('-DryRun', '-Prompt', 'x', '-Engine', 'codex', '-EngineExe', $copy)
    $noEng = Consult $r '' @('-DryRun', '-Prompt', 'x', '-EngineExe', $copy)
    $gone = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x', '-EngineExe', (Join-Path $work 'no-such\muse.cmd')))
    Check 'ENGINEEXE' 'refused: two engines in the roster without -Engine (ambiguous; -Engine muse resolves it), -Engine codex (-CodexExe), no roster and no -Engine, a launcher that does not exist' ($amb.Code -eq 1 -and $amb.First -eq 'codex-consult: -EngineExe is ambiguous: the reviewer roster has entries of the engines agy and muse; pass -Engine <agy|muse> to name the one it launches.' -and $viaEngine.Code -eq 0 -and $viaEngine.Preview.reviewer.provider_config.launcher -eq $copy -and $cx.Code -eq 1 -and $cx.First -eq 'codex-consult: -EngineExe names the launcher of an engine other than codex (agy, muse); codex takes -CodexExe.' -and $noEng.Code -eq 1 -and $noEng.First -match 'pass -Engine <agy\|muse> with it' -and $gone.Code -eq 1 -and $gone.First -match "^codex-consult: -EngineExe '.+no-such\\muse\.cmd' is not a file and not an application on PATH\.$") "$($amb.First) | $($noEng.First) | $($gone.First)"
    $lad2 = Join-Path $lad 'Programs\muse'
    $inst = Copy-Fake -Dir $lad2 -Name 'muse.cmd'
    $viaInstall = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x')) @{ CODEX_CONSULT_MUSE_EXE = '' }
    Remove-Item -LiteralPath $lad2 -Recurse -Force
    $noLauncher = Consult $r '' ($museArgs + @('-Prompt', 'x')) @{ CODEX_CONSULT_MUSE_EXE = '' }
    Check 'ENGINEEXE' 'D3: without -EngineExe and CODEX_CONSULT_MUSE_EXE and nothing on PATH the vendor install location %LOCALAPPDATA%\Programs\muse\muse.cmd is used; with none at all a real run is refused ("muse CLI not found")' ($viaInstall.Code -eq 0 -and $viaInstall.Preview.reviewer.provider_config.launcher -eq $inst -and $noLauncher.Code -eq 1 -and $noLauncher.Out -match 'muse CLI not found on PATH') "$(Line $viaInstall.Out 'launcher') | $($noLauncher.First)"
}

# =============================================================== RUN: a full run through the .cmd chain (D1, D15)
if (Want 'RUN') {
    $r = New-Repo 'run'
    $log = Join-Path $work 'run-log.txt'
    $cnt = Join-Path $work 'run-count.txt'
    $x = Consult $r '' ($museArgs + @('-Prompt', 'Check the %APPDATA% words in the prompt', '-Purpose', 'framing', '-ReplyName', 'run')) @{ FAKE_MUSE_REPLY = $adviseF; FAKE_MUSE_LOG = $log; FAKE_MUSE_COUNT = $cnt }
    $e = Last-Entry $r
    Check 'RUN' 'usable reply; ledger reviewer {engine muse, provider meta, fingerprint, harness muse-cli 9.9.9-fake, provider_config.credential_mechanism oauth}, lineage "meta :: muse-spark-1.3", thread = the session id (events), effort high muse-v1, schema_transport native, usage null' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply' -and $e.reviewer.engine -eq 'muse' -and $e.reviewer.provider -eq 'meta' -and $e.reviewer.provider_fingerprint -eq $museFp -and $e.reviewer.harness -eq 'muse-cli 9.9.9-fake' -and $e.reviewer.provider_config.credential_mechanism -eq 'oauth' -and $e.lineage -eq 'meta :: muse-spark-1.3' -and $e.thread -match $uuidRe -and $e.thread_source -eq 'events' -and $e.effort_sent -eq 'high' -and $e.effort_mapping -eq 'muse-v1' -and $e.schema_transport -eq 'native' -and $null -eq $e.usage -and $e.command.StartsWith('muse exec --json --prompt-file ')) "$($e.bridge_outcome) / $($x.First)"
    Check 'RUN' 'D2 ledger: engine_run {turns 1 (one subscription prompt), max_model_steps null, msp_schema_version 1}; denial_retry null, format_retry null, warnings []; the fake ran exactly one exec turn' ($e.engine_run.turns -eq 1 -and $null -eq $e.engine_run.max_model_steps -and $e.engine_run.msp_schema_version -eq 1 -and (($e.engine_run.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'turns,max_model_steps,msp_schema_version' -and $null -eq $e.denial_retry -and $null -eq $e.format_retry -and @($e.warnings).Count -eq 0 -and (Count-Lines $cnt) -eq 1) ($e.engine_run | ConvertTo-Json -Compress)
    $tl = Text $log
    $promptAt = $tl.IndexOf("PROMPT:`n")
    $seen = if ($promptAt -ge 0) { $tl.Substring($promptAt + 8) } else { '' }
    $argLines = @(($tl -split "`n") | Where-Object { $_.StartsWith('ARG: ') } | ForEach-Object { $_.Substring(5) })
    Check 'RUN' 'D1: the prompt travels in the prompt file (read by the fake: length = prompt_chars, ends with the consultation id, %APPDATA% in the ask unexpanded) and stdin is EMPTY (0 bytes); the fake saw exactly the 16 real-flag arguments' ($seen.Length -eq [int]$e.prompt_chars -and $seen.EndsWith("Consultation id: $($e.consult_id)") -and $seen.Contains('Check the %APPDATA% words in the prompt') -and $tl -match '(?m)^STDIN-BYTES: 0$' -and $argLines.Count -eq 16 -and $argLines[0] -eq 'exec' -and $argLines[2] -eq '--prompt-file' -and $argLines[4] -eq '--output-schema' -and $argLines[5] -eq $schemaPath -and $argLines[15] -eq 'never') "chars $($seen.Length)/$($e.prompt_chars), args $($argLines.Count)"
    $order = 'n,when,purpose,consult_id,reviewer,lineage,preflight,preflight_warning,roster,panel,parent_thread,thread,thread_source,thread_candidate,mode,command,brief,range,prompt_chars,reply,reply_json,events,partial_reply,model,effort,effort_requested,effort_sent,effort_mapping,effort_caps,effort_confirmed,max_words,sandbox,timeout_sec,timeout_source,continue_sec,extra_config,extra_config_source,peak,peak_schedule,peak_source,peak_evaluated_at,structured,schema,schema_transport,schema_transport_source,validation_error,format_retry,denial_retry,timeout_continue,base_commit,reviewed_revision,tree_sha256,tree_sha256_after,tree_changed_during_review,changed_files,brief_sha256,brief_sha256_after,brief_changed_during_review,fingerprint_note,artifacts,artifacts_changed_during_review,bridge_outcome,provider_failure,warnings,verdict,verdict_reason,findings,finding_ids,prior_findings,unchecked_prior_blockers,usage,engine_run,wall_seconds,finished_at,commit_wait_ms'
    Check 'RUN' 'ledger fields in the same order as a codex entry (engine_run right after usage)' ((($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq $order) ''
    $rj = Text (Td $r $e.reply_json)
    $md = Text (Td $r $e.reply)
    Check 'RUN' 'handoffs NN-muse-run.{md,reply.json,events.jsonl}; .reply.json = the terminal''s text; the finding ingested, verdict ADVISE; header "# Handoff NN - Meta Muse (muse): run", Author (effort high), Argv "(prompt from a file: --prompt-file)", "Engine turns: 1 (each one a Muse Code subscription prompt); MSP schema_version 1"' ($e.reply -match '^handoffs/\d\d-muse-run\.md$' -and $e.reply_json -match '^handoffs/\d\d-muse-run\.reply\.json$' -and (Test-Path (Td $r $e.events)) -and (ConvertFrom-Json $rj).verdict -eq 'ADVISE' -and $e.structured -eq $true -and @($e.finding_ids).Count -eq 1 -and $md -match '(?m)^# Handoff \d\d - Meta Muse \(muse\): run$' -and $md -match '(?m)^Date: .* Author: Meta Muse \(muse\) \(model muse-spark-1\.3, effort high\), muse-cli 9\.9\.9-fake\.$' -and $md.Contains('(prompt from a file: --prompt-file).') -and $md -match '(?m)^Engine turns: 1 \(each one a Muse Code subscription prompt\); MSP schema_version 1\.$' -and $md.Contains('Tokens: not reported by muse.') -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) (($md -split "`n")[0])
    # the prompt, the schema and the launcher paths with spaces through the .cmd chain (F02-14,
    # D15): TEMP with spaces (the prompt file), a copy of the plugin in a directory with spaces
    # (the schema path follows the scripts), the fake launcher in a directory with spaces
    $spTmp = Join-Path $work 'tmp dir with spaces'
    [void][IO.Directory]::CreateDirectory($spTmp)
    $plugCopy = Join-Path $work 'plugin dir with spaces'
    foreach ($sub in @('scripts', 'schemas')) {
        [void][IO.Directory]::CreateDirectory((Join-Path $plugCopy $sub))
        Copy-Item -Path (Join-Path (Join-Path (Join-Path $repoRoot 'plugins\codex-consult') $sub) '*') -Destination (Join-Path $plugCopy $sub) -Force
    }
    $schemaCopy = Join-Path $plugCopy 'schemas\consult-reply.schema.json'
    $spLauncher = Copy-Fake -Dir (Join-Path $work 'launcher dir with spaces')
    $slog = Join-Path $work 'spaces-log.txt'
    $y = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'spaces', '-EngineExe', $spLauncher)) @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_LOG = $slog; TEMP = $spTmp; TMP = $spTmp } -Script (Join-Path $plugCopy 'scripts\codex-consult.ps1')
    $ey = Last-Entry $r
    $st = Text $slog
    $spArgs = @(($st -split "`n") | Where-Object { $_.StartsWith('ARG: ') } | ForEach-Object { $_.Substring(5) })
    Check 'RUN' 'F02-14/D15: the prompt file (TEMP with spaces), the schema (the plugin in a directory with spaces) and the launcher (a directory with spaces) - both paths arrive whole through the .cmd chain as one argument each and are readable (the fake reads the prompt and checks the schema, else exit 2); the ledger names that launcher' ($y.Code -eq 0 -and $ey.bridge_outcome -eq 'usable reply' -and $spArgs.Count -eq 16 -and $spArgs[3].StartsWith($spTmp + '\codex-consult-prompt-') -and $spArgs[5] -eq $schemaCopy -and $st.Contains("PROMPT:`n") -and $st.Contains("Consultation id: $($ey.consult_id)") -and $ey.reviewer.provider_config.launcher -eq $spLauncher) "arg3=$(if ($spArgs.Count -gt 3) { $spArgs[3] }) arg5=$(if ($spArgs.Count -gt 5) { $spArgs[5] })"
    $pctTmp = Join-Path $work 'tmp %APPDATA% pct'
    [void][IO.Directory]::CreateDirectory($pctTmp)
    $plog = Join-Path $work 'pct-log.txt'
    $before = @(Ledger $r).Count
    $zd = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x')) @{ TEMP = $pctTmp; TMP = $pctTmp }
    $z = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'pct')) @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_LOG = $plog; TEMP = $pctTmp; TMP = $pctTmp }
    Check 'RUN' 'F02-14: a TEMP with ''%'' through the .cmd launcher: the dry run says "a real run is refused before launch", the real run is refused before anything starts (no process, no ledger entry, no recovery record left)' ($zd.Code -eq 0 -and $zd.Out -match '(?m)^launch      : a real run is refused before launch - the launcher .+fake-muse\.cmd is a cmd\.exe script and 1 argument\(s\) contain ''%''' -and $z.Code -eq 1 -and $z.First -match '^codex-consult: the muse run is refused before launch: the launcher .+ is a cmd\.exe script' -and -not (Test-Path $plog) -and @(Ledger $r).Count -eq $before -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) $z.First
    # no credential value anywhere (D5)
    $leak = @(Get-ChildItem -LiteralPath (Join-Path $r '.collab') -Recurse -File | Where-Object { (Text $_.FullName).Contains($tokenMark) } | ForEach-Object { $_.Name })
    Check 'RUN' 'D5: the fake auth.json''s token appears nowhere - not in the ledger, the handoffs, the event streams or the console' ($leak.Count -eq 0 -and -not $x.Out.Contains($tokenMark) -and -not $y.Out.Contains($tokenMark)) ($leak -join ', ')
}

# =============================================================== BILLING: the launch invariant (D4)
if (Want 'BILLING') {
    $r = New-Repo 'billing'
    $val = 'fake-key-value-0815'
    $a = Consult $r '' ($museArgs + @('-Prompt', 'x')) @{ META_API_KEY = $val; FAKE_MUSE_REPLY = $advise }
    $b = Consult $r '' ($museArgs + @('-Prompt', 'x', '-SkipPreflight')) @{ MODEL_API_KEY = $val; FAKE_MUSE_REPLY = $advise }
    $c = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x')) @{ META_API_KEY = $val }
    Check 'BILLING' 'META_API_KEY / MODEL_API_KEY set -> the muse run is refused before anything starts ("the muse engine is refused: <NAME> is set: a muse run would bill per token instead of the Muse Code subscription"), with -SkipPreflight too and in a dry run; the value is never printed; no ledger entry' ($a.Code -eq 1 -and $a.First -eq 'codex-consult: the muse engine is refused: META_API_KEY is set: a muse run would bill per token instead of the Muse Code subscription; unset it (the muse process would inherit it); nothing was started.' -and $b.Code -eq 1 -and $b.First -match '^codex-consult: the muse engine is refused: MODEL_API_KEY is set: ' -and $c.Code -eq 1 -and -not ($a.Out + $b.Out + $c.Out).Contains($val) -and @(Ledger $r).Count -eq 0) "$($a.First) | $($b.First)"
    $w = Consult $r $rosterMuseCodex @('-DryRun', '-Prompt', 'x') @{ META_API_KEY = $val }
    $ws = Consult $r $rosterMuseCodex @('-DryRun', '-Prompt', 'x', '-SkipPreflight') @{ META_API_KEY = $val }
    Check 'BILLING' 'the roster walk skips the muse entry ("refused: META_API_KEY is set: ...") and selects openai - with -SkipPreflight too (the launch invariant is not a preflight check); roster.skipped names it' ($w.Code -eq 0 -and $w.Preview.reviewer.provider -eq 'openai' -and $w.Preview.roster.skipped[0].engine -eq 'muse' -and $w.Preview.roster.skipped[0].reason -match '^refused: META_API_KEY is set: a muse run would bill per token' -and $ws.Code -eq 0 -and $ws.Preview.reviewer.provider -eq 'openai' -and $ws.Preview.roster.skipped[0].reason -match '^refused: META_API_KEY is set' -and -not ($w.Out + $ws.Out).Contains($val)) (Line $ws.Out 'Roster:')
    $pn = Consult $r $rosterMuseCodex @('-Panel', '-DryRun', '-Prompt', 'x', '-SkipPreflight') @{ MODEL_API_KEY = $val }
    Check 'BILLING' 'a panel member: the muse member is skipped ("refused: MODEL_API_KEY is set: ...") with -SkipPreflight too, the codex member still runs' ($pn.Code -eq 0 -and $pn.Out -match '(?m)^  #1 meta :: muse-spark-1\.3 \[muse\] - skipped: refused: MODEL_API_KEY is set: a muse run would bill per token' -and $pn.Out -match '(?m)^  #2 openai :: gpt-5\.1 - member, n=' -and -not $pn.Out.Contains($val)) (Line $pn.Out '  #1')
    Write-Auth '{"providers":{"meta":{"api_key":"sk-FAKE","mechanism":"api_key"}}}'
    $m = Consult $r '' ($museArgs + @('-Prompt', 'x', '-SkipPreflight')) @{ FAKE_MUSE_REPLY = $advise }
    Write-Auth $authOauth
    Check 'BILLING' 'D4: an auth.json whose providers.meta.mechanism is not oauth -> refused (with -SkipPreflight too): "uses mechanism ''api_key'', not oauth"' ($m.Code -eq 1 -and $m.First -eq "codex-consult: the muse engine is refused: the Muse sign-in in ~/.config/muse/auth.json uses mechanism 'api_key', not oauth: a muse run would not bill the Muse Code subscription; sign in with ``muse login``; nothing was started.") $m.First
    $lj = Providers $r $rosterMuseCodex @('-Json') @{ META_API_KEY = $val }
    $row = @($lj.Json | Where-Object { $_.name -eq 'meta' })[0]
    # (wave 23b, F09-1) no ESTABLISHED oauth sign-in: refused like an API key - under
    # -SkipPreflight, in a dry run, in the walk, in a panel member and in the listing alike
    $estRun = 'a muse run might bill per token instead of the Muse Code subscription; set TBH_CREDENTIAL_BACKEND=file and run `muse login`; nothing was started.'
    $bc = Join-Path $work 'billing-count.txt'
    Write-Auth ('{"providers":{"meta":{"access_token":"' + $tokenMark + '"}}}')
    $k1 = Consult $r '' ($museArgs + @('-Prompt', 'x', '-SkipPreflight')) @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COUNT = $bc }
    $k2 = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x', '-SkipPreflight'))
    Write-Auth $authOauth
    Check 'BILLING' 'F09-1 (wave 23b): providers.meta without a mechanism -> refused under -SkipPreflight too, and in the dry run: "the muse engine is refused: the Muse sign-in is not established as oauth (providers.meta in ~/.config/muse/auth.json names no mechanism): ...; set TBH_CREDENTIAL_BACKEND=file and run `muse login`"; no muse process, no ledger entry, no credential value printed' ($k1.Code -eq 1 -and $k1.First -eq "codex-consult: the muse engine is refused: the Muse sign-in is not established as oauth (providers.meta in ~/.config/muse/auth.json names no mechanism): $estRun" -and $k2.Code -eq 1 -and $k2.First -eq $k1.First -and -not (Test-Path $bc) -and @(Ledger $r).Count -eq 0 -and -not ($k1.Out + $k2.Out).Contains($tokenMark)) $k1.First
    $kw = Consult $r $rosterMuseCodex @('-DryRun', '-Prompt', 'x', '-SkipPreflight') @{ TBH_CREDENTIAL_BACKEND = '' }
    $rpn = New-Repo 'billing-panel'
    $kc = Join-Path $work 'billing-panel-count.txt'
    $kp = Consult $rpn $rosterMuseCodex @('-Panel', '-Prompt', 'x', '-SkipPreflight', '-ReplyName', 'kp') @{ TBH_CREDENTIAL_BACKEND = ''; FAKE_CODEX_REPLY = $advise; FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COUNT = $kc }
    $kled = @(Ledger $rpn)
    Check 'BILLING' 'F09-1: the keychain backend (TBH_CREDENTIAL_BACKEND not set) under -SkipPreflight: the roster walk skips the muse entry ("refused: the Muse sign-in is not established as oauth (TBH_CREDENTIAL_BACKEND is not set: the keychain backend cannot be read): ...") and selects openai; a real panel skips the muse member the same way, the codex member runs (one ledger entry), no muse process' ($kw.Code -eq 0 -and $kw.Preview.reviewer.provider -eq 'openai' -and $kw.Preview.roster.skipped[0].engine -eq 'muse' -and $kw.Preview.roster.skipped[0].reason -match '^refused: the Muse sign-in is not established as oauth \(TBH_CREDENTIAL_BACKEND is not set: the keychain backend cannot be read\): a muse run might bill per token' -and $kp.Code -eq 0 -and $kp.Out -match '(?m)^  #1 meta :: muse-spark-1\.3 \[muse\] - skipped: refused: the Muse sign-in is not established as oauth \(TBH_CREDENTIAL_BACKEND is not set' -and $kp.Out -match '(?m)^  #2 openai :: gpt-5\.1 - member, n=' -and $kled.Count -eq 1 -and $kled[0].reviewer.provider -eq 'openai' -and $kled[0].bridge_outcome -eq 'usable reply' -and -not (Test-Path $kc)) "$(Line $kw.Out 'Roster:') | $(Line $kp.Out '  #1')"
    $kl = Providers $r $rosterMuseCodex @('-Json') @{ TBH_CREDENTIAL_BACKEND = '' }
    $krow = @($kl.Json | Where-Object { $_.name -eq 'meta' })[0]
    $kopen = @($kl.Json | Where-Object { $_.name -eq 'openai' })[0]
    Check 'BILLING' 'F09-1: codex-providers with the keychain backend: the muse row''s credentials "unknown: sign-in not checkable: ...", its verdict "unavailable (refused: the Muse sign-in is not established as oauth (...): ...)"; the roster line selects openai' ($kl.Code -eq 0 -and $krow.credentials -match '^unknown: sign-in not checkable: TBH_CREDENTIAL_BACKEND is not set' -and $krow.verdict -match '^unavailable \(refused: the Muse sign-in is not established as oauth \(TBH_CREDENTIAL_BACKEND is not set: the keychain backend cannot be read\): a muse run might bill per token' -and $krow.roster_selected -eq $false -and $kopen.roster_selected -eq $true) $krow.verdict
    Check 'BILLING' 'codex-providers: the muse row is "unavailable (refused: META_API_KEY is set: ...)"; the roster line selects openai' ($lj.Code -eq 0 -and $row.verdict -match '^unavailable \(refused: META_API_KEY is set: a muse run would bill per token' -and $row.roster_selected -eq $false -and -not $lj.Out.Contains($val)) $row.verdict
}

# =============================================================== PREFLIGHT: the three sign-in states end to end (D5)
if (Want 'PREFLIGHT') {
    $r = New-Repo 'pre'
    $pc = Join-Path $work 'pre-count.txt'
    $mMsg = 'codex-consult: the muse engine is refused: the Muse sign-in is not established as oauth (~/.config/muse/auth.json does not exist): a muse run might bill per token instead of the Muse Code subscription; set TBH_CREDENTIAL_BACKEND=file and run `muse login`; nothing was started.'
    Write-Auth ''
    $mdry = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x'))
    $mrun = Consult $r '' ($museArgs + @('-Prompt', 'x')) @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COUNT = $pc }
    $mskip = Consult $r '' ($museArgs + @('-Prompt', 'x', '-SkipPreflight')) @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COUNT = $pc }
    $ml = Providers $r $rosterMuseCodex @('-Json')
    Write-Auth $authOauth
    $mrow = @($ml.Json | Where-Object { $_.name -eq 'meta' })[0]
    Check 'PREFLIGHT' 'no auth.json (file backend): the sign-in check says "missing: not signed in: ~/.config/muse/auth.json does not exist (run `muse login` with TBH_CREDENTIAL_BACKEND=file)" (the listing''s credentials); since wave 23b (F09-1) the LAUNCH is refused before any preflight - the dry run, the real run and -SkipPreflight alike ("the Muse sign-in is not established as oauth (~/.config/muse/auth.json does not exist): ..."); nothing started, no ledger entry' ($mdry.Code -eq 1 -and $mdry.First -eq $mMsg -and $mrun.Code -eq 1 -and $mrun.First -eq $mMsg -and $mskip.Code -eq 1 -and $mskip.First -eq $mMsg -and $mrow.credentials -eq 'missing: not signed in: ~/.config/muse/auth.json does not exist (run `muse login` with TBH_CREDENTIAL_BACKEND=file)' -and $mrow.verdict -match '^unavailable \(refused: the Muse sign-in is not established as oauth \(~/\.config/muse/auth\.json does not exist\): ' -and -not (Test-Path $pc) -and @(Ledger $r).Count -eq 0) "$($mrun.First) | $($mrow.verdict)"
    $kdry = Consult $r '' (@('-DryRun') + $museArgs + @('-Prompt', 'x')) @{ TBH_CREDENTIAL_BACKEND = '' }
    $krun = Consult $r '' ($museArgs + @('-Prompt', 'x')) @{ TBH_CREDENTIAL_BACKEND = ''; FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COUNT = $pc }
    $kskip = Consult $r '' ($museArgs + @('-Prompt', 'x', '-SkipPreflight', '-ReplyName', 'skip')) @{ TBH_CREDENTIAL_BACKEND = 'keychain'; FAKE_MUSE_REPLY = $advise; FAKE_MUSE_COUNT = $pc }
    Check 'PREFLIGHT' 'the keychain backend (TBH_CREDENTIAL_BACKEND not file): the sign-in is unknown (not checkable) - since wave 23b (F09-1) the launch is refused in the dry run, the real run AND under -SkipPreflight (before: it ran with credential_mechanism null); the message names the cause and the remedy; nothing started, no ledger entry' ($kdry.Code -eq 1 -and $kdry.First -match '^codex-consult: the muse engine is refused: the Muse sign-in is not established as oauth \(TBH_CREDENTIAL_BACKEND is not set: the keychain backend cannot be read\): a muse run might bill per token instead of the Muse Code subscription; set TBH_CREDENTIAL_BACKEND=file and run `muse login`; nothing was started\.$' -and $krun.Code -eq 1 -and $krun.First -eq $kdry.First -and $kskip.Code -eq 1 -and $kskip.First -match "^codex-consult: the muse engine is refused: the Muse sign-in is not established as oauth \(TBH_CREDENTIAL_BACKEND is 'keychain': the keychain backend cannot be read\): " -and -not (Test-Path $pc) -and @(Ledger $r).Count -eq 0) "$($krun.First) | $($kskip.First)"
}

# =============================================================== FAIL: the extraction invariants and failure classes end to end (D6, D7, D14)
if (Want 'FAIL') {
    $r = New-Repo 'fail'
    $cases = [ordered]@{
        'exit 2'          = @(@{ FAKE_MUSE_USAGE_ERROR = '1' }, "^failed: muse exit 2 \(usage error\) - error: unexpected argument '--fake-usage-error' found$", 'capability')
        'exit 130'        = @(@{ FAKE_MUSE_EXIT = '130' }, '^failed: muse exit 130 \(stopped by a signal\)$', 'transport')
        'step cap'        = @(@{ FAKE_MUSE_TERMINAL = 'failed'; FAKE_MUSE_REASON = 'max_model_steps reached (40)' }, '^failed: muse exit 1 - max model steps reached \(max_model_steps reached \(40\)\)$', 'capability')
        'cancelled'       = @(@{ FAKE_MUSE_TERMINAL = 'cancelled'; FAKE_MUSE_REASON = 'cancelled by the user' }, '^failed: muse exit 1 - cancelled by the user$', 'unknown')
        'schema_version 2' = @(@{ FAKE_MUSE_SCHEMA_VERSION = '2' }, '^failed: malformed event stream: unsupported MSP version 2 \(the bridge reads MSP 1\)$', 'transport')
        'two sessions'    = @(@{ FAKE_MUSE_TWOSESSIONS = '1' }, '^failed: malformed event stream: 2 session streams \(exactly one expected\): ', 'transport')
        'two terminals'   = @(@{ FAKE_MUSE_TWOTERMINALS = '1' }, '^failed: malformed event stream: 2 run_terminal records \(exactly one expected\)$', 'transport')
        'off-session'     = @(@{ FAKE_MUSE_TERMINAL_STREAM = 'run' }, '^failed: malformed event stream: the run_terminal record at line \d+ is on stream run ', 'transport')
        'partial line'    = @(@{ FAKE_MUSE_PARTIAL = '1' }, '^failed: malformed event stream: line \d+ is not a JSON object$', 'transport')
        'no terminal'     = @(@{ FAKE_MUSE_NOTERMINAL = '1' }, '^failed: no run_terminal record in the muse event stream$', 'unknown')
        'not a uuid'      = @(@{ FAKE_MUSE_SESSION = 'notuuid' }, "^failed: the session id 'session-1' is not a uuid$", 'unknown')
        'model drift'     = @(@{ FAKE_MUSE_MODEL = 'muse-spark-1.3-contributor' }, '^failed: model drift: asked muse-spark-1\.3, served muse-spark-1\.3-contributor$', 'capability')
        'no model'        = @(@{ FAKE_MUSE_NOMODEL = '1' }, '^failed: the muse event stream names no configured model \(run\.model\.configured; asked muse-spark-1\.3\)$', 'unknown')
    }
    $bad = @()
    $k = 0
    foreach ($name in $cases.Keys) {
        $k++
        $envK = @{ FAKE_MUSE_REPLY = $adviseF }
        foreach ($kk in $cases[$name][0].Keys) { $envK[$kk] = $cases[$name][0][$kk] }
        $o = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', "f$k")) $envK
        $e = Last-Entry $r
        $ok = ($o.Code -eq 1 -and $e.bridge_outcome -match $cases[$name][1] -and $e.provider_failure.class -eq $cases[$name][2] -and @($e.finding_ids).Count -eq 0 -and $e.engine_run.turns -eq 1)
        if ($name -eq 'schema_version 2' -and $e.engine_run.msp_schema_version -ne 2) { $ok = $false }
        if ($name -eq 'model drift' -and -not ($e.thread -eq '' -and $e.thread_candidate -match $uuidRe)) { $ok = $false }
        if (-not $ok) { $bad += "$name -> [$($e.bridge_outcome)] class $($e.provider_failure.class)" }
    }
    Check 'FAIL' "every rule fails the run with its class, nothing ingested, one turn: $(@($cases.Keys) -join ', ') (drift: the session is a candidate only; schema 2: engine_run.msp_schema_version 2)" ($bad.Count -eq 0) ($bad -join ' | ')
    # (wave 23b, F09-3) evidence of foreign provenance end to end: a nested / sub-stream record,
    # another run, no run linked -> malformed ("ambiguous provenance"), fail closed
    $provCases = [ordered]@{
        'model on a sub-stream' = @(@{ FAKE_MUSE_MODEL_STREAM = 'task' }, '^failed: malformed event stream: ambiguous provenance: the run\.model\.configured record at line 3 is on stream task [0-9a-f-]{36}, not on the session stream$')
        'model of another run'  = @(@{ FAKE_MUSE_MODEL_RUN = 'other' }, '^failed: malformed event stream: ambiguous provenance: the run\.model\.configured record at line 3 names stream run [0-9a-f-]{36}, not the run linked to the session \(run [0-9a-f-]{36}\)$')
        'no run linked'         = @(@{ FAKE_MUSE_LINK = 'none' }, '^failed: malformed event stream: ambiguous provenance: the run\.model\.configured record at line 2 names stream run [0-9a-f-]{36}, but no session\.run\.linked record links a run to the session$')
        'link on a sub-stream'  = @(@{ FAKE_MUSE_LINK = 'task' }, '^failed: malformed event stream: ambiguous provenance: the session\.run\.linked record at line 2 is on stream task [0-9a-f-]{36}, not on the session stream$')
        'two runs linked'       = @(@{ FAKE_MUSE_LINK = 'two' }, '^failed: malformed event stream: ambiguous provenance: 2 run streams linked to the session \(exactly one expected\): run [0-9a-f-]{36}, run [0-9a-f-]{36}$')
        'reply of another run'  = @(@{ FAKE_MUSE_TERMINAL_RUN = 'other' }, '^failed: malformed event stream: ambiguous provenance: the run_terminal record at line \d+ names stream run [0-9a-f-]{36}, not the run linked to the session \(run [0-9a-f-]{36}\)$')
    }
    $badP = @()
    foreach ($name in $provCases.Keys) {
        $k++
        $envK = @{ FAKE_MUSE_REPLY = $adviseF }
        foreach ($kk in $provCases[$name][0].Keys) { $envK[$kk] = $provCases[$name][0][$kk] }
        $o = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', "f$k")) $envK
        $e = Last-Entry $r
        if (-not ($o.Code -eq 1 -and $e.bridge_outcome -match $provCases[$name][1] -and $e.provider_failure.class -eq 'transport' -and @($e.finding_ids).Count -eq 0 -and $e.engine_run.turns -eq 1 -and $e.thread -eq '' -and $e.thread_candidate -match $uuidRe)) { $badP += "$name -> [$($e.bridge_outcome)] class $($e.provider_failure.class) thread [$($e.thread)]" }
    }
    Check 'FAIL' "F09-3 (wave 23b): evidence of foreign provenance fails the run as a malformed stream (""ambiguous provenance: ..."", class transport, nothing ingested, the session a candidate only, one turn): $(@($provCases.Keys) -join ', ')" ($badP.Count -eq 0) ($badP -join ' | ')
    $t = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'hang', '-TimeoutSec', '6')) @{ FAKE_MUSE_HANG = '1' }
    $et = Last-Entry $r
    Check 'FAIL' 'D7: the bridge''s own timeout kills the tree -> "failed: timeout after 6 s (process tree killed)", class transport (not the signal exit)' ($t.Code -eq 1 -and $et.bridge_outcome -match '^failed: timeout after 6 s \(process tree killed' -and $et.provider_failure.class -eq 'transport') $et.bridge_outcome
    # Meta's quota wording, verbatim, with its reset time - and the shared endpoint (D14)
    $rq = New-Repo 'quota'
    $two = Write-Roster 'two-muse' ('{"roster_version":1,"reviewers":[{"provider":"meta","engine":"muse","model":"muse-spark-1.3"},{"provider":"meta-contrib","engine":"muse","model":"muse-spark-1.3-contributor"},{"provider":"openai","model":"gpt-5.1"}]}')
    $qc = Join-Path $work 'quota-count.txt'
    $q = Consult $rq $two @('-Prompt', 'x', '-Provider', 'meta', '-ReplyName', 'q') @{ FAKE_MUSE_TERMINAL = 'failed'; FAKE_MUSE_REASON = $quotaReason; FAKE_MUSE_COUNT = $qc }
    $eq = Last-Entry $rq
    Check 'FAIL' 'a failed terminal with Meta''s quota wording: "failed: muse exit 1 - <the reason verbatim>", provider_failure {class quota, message verbatim, retry_after = the named reset}; no format repair after a quota failure (one exec turn)' ($q.Code -eq 1 -and $eq.bridge_outcome -eq "failed: muse exit 1 - $quotaReason" -and $eq.provider_failure.class -eq 'quota' -and $eq.provider_failure.message -eq $quotaReason -and $eq.provider_failure.retry_after -and $null -eq $eq.format_retry -and (Count-Lines $qc) -eq 1) "$($eq.provider_failure.class) $($eq.provider_failure.retry_after)"
    $q2 = Consult $rq $two @('-DryRun', '-Prompt', 'x', '-Provider', 'meta-contrib')
    $q3 = Consult $rq $two @('-DryRun', '-Prompt', 'x')
    Check 'FAIL' 'D14: one Meta sign-in = one endpoint - the quota blocks the OTHER muse label too until its reset (preflight "usage limit until <iso>"); the walk skips both muse entries and selects openai' ($q2.Code -eq 0 -and $q2.Out -match '(?m)^preflight   : unavailable \(usage limit until \d{4}-' -and $q3.Code -eq 0 -and $q3.Preview.reviewer.provider -eq 'openai' -and @($q3.Preview.roster.skipped).Count -eq 2 -and $q3.Preview.roster.skipped[1].reason -match '^usage limit until ') "$(Line $q2.Out 'preflight') | $(Line $q3.Out 'Roster:')"
}

# =============================================================== TREE: the tree check and D12's forced class (muse and agy)
if (Want 'TREE') {
    $r = New-Repo 'tree'
    $x = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'w')) @{ FAKE_MUSE_REPLY = $adviseF; FAKE_MUSE_WRITE = 'probe.txt' }
    $e = Last-Entry $r
    Check 'TREE' 'D12: muse writes probe.txt -> FAILED "the working tree changed during the run (by the reviewer or anyone else): 1 file: probe.txt - muse ran with --disable-write --disable-shell (the check cannot tell who changed it)", class permission, nothing ingested' ($x.Code -eq 1 -and $e.bridge_outcome -eq 'failed: the working tree changed during the run (by the reviewer or anyone else): 1 file: probe.txt - muse ran with --disable-write --disable-shell (the check cannot tell who changed it)' -and $e.provider_failure.class -eq 'permission' -and @($e.finding_ids).Count -eq 0) $e.bridge_outcome
    Remove-Item (Join-Path $r 'probe.txt')
    $y = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'wq')) @{ FAKE_MUSE_WRITE = 'probe2.txt'; FAKE_MUSE_TERMINAL = 'failed'; FAKE_MUSE_REASON = $quotaReason }
    $ey = Last-Entry $r
    Check 'TREE' 'D12: a write AND an already failed run (Meta''s quota) -> class permission all the same; that reason stays in the message; the outcome adds "; also: the working tree changed ..."' ($y.Code -eq 1 -and $ey.bridge_outcome -match ('^failed: muse exit 1 - ' + [regex]::Escape($quotaReason) + '; also: the working tree changed during the run \(by the reviewer or anyone else\): 1 file: probe2\.txt') -and $ey.provider_failure.class -eq 'permission' -and $ey.provider_failure.message -eq $quotaReason) "$($ey.provider_failure.class) | $($ey.bridge_outcome)"
    Remove-Item (Join-Path $r 'probe2.txt')
    $z = Consult $r '' @('-Engine', 'agy', '-Model', 'gemini-3.8-flash-high', '-Prompt', 'x', '-ReplyName', 'agyw') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_WRITE = 'probe3.txt'; FAKE_AGY_EXIT = '1'; FAKE_AGY_ERROR = 'UNAVAILABLE: backend down' }
    $ez = Last-Entry $r
    Check 'TREE' 'D12 for agy too: a write and "agy exit 1 - UNAVAILABLE ..." (class transport before wave 23) -> class permission, the agy error stays the message, "; also: ... - agy''s sandbox does not block writes"' ($z.Code -eq 1 -and $ez.reviewer.engine -eq 'agy' -and $ez.bridge_outcome -match "^failed: agy exit 1 - UNAVAILABLE: backend down; also: the working tree changed during the run \(by the reviewer or anyone else\): 1 file: probe3\.txt - agy's sandbox does not block writes$" -and $ez.provider_failure.class -eq 'permission' -and $ez.provider_failure.message -eq 'UNAVAILABLE: backend down') "$($ez.provider_failure.class) | $($ez.bridge_outcome)"
    Remove-Item (Join-Path $r 'probe3.txt')
}

# =============================================================== RESUME: sessions (D6, design 7)
if (Want 'RESUME') {
    $r = New-Repo 'resume'
    $t0 = Uuid
    Seed-Task $r @((New-MuseEntry 1 $t0))
    $rlog = Join-Path $work 'resume-log.txt'
    $a = Consult $r $rosterMuse @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'res') @{ FAKE_MUSE_REPLY = $advise; FAKE_MUSE_RESUME_LOG = $rlog }
    $ea = Last-Entry $r
    Check 'RESUME' '-Mode resume -> --session-id <the newest verified muse thread> at the end of the argv; the session comes back the same -> usable, parent = thread = t0' ($a.Code -eq 0 -and $ea.mode -eq 'resume' -and $ea.parent_thread -eq $t0 -and $ea.thread -eq $t0 -and $ea.bridge_outcome -eq 'usable reply' -and $ea.command.EndsWith("--session-id $t0") -and (Text $rlog) -match "(?m)^ARG: $t0$") $ea.command
    $b = Consult $r $rosterMuse @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'gone') @{ FAKE_MUSE_REPLY = $adviseF; FAKE_MUSE_SESSION = 'other' }
    $eb = Last-Entry $r
    Check 'RESUME' 'a resume that comes back on ANOTHER session -> FAILED "parent session <p> not found, muse started <s>" (class unknown), thread "" and the new session a candidate only; nothing ingested; the next resume still names t0' ($b.Code -eq 1 -and $eb.bridge_outcome -match "^failed: parent session $t0 not found, muse started [0-9a-f-]{36}$" -and $eb.provider_failure.class -eq 'unknown' -and $eb.thread -eq '' -and $eb.thread_candidate -match $uuidRe -and @($eb.finding_ids).Count -eq 0 -and (Consult $r $rosterMuse @('-DryRun', '-Prompt', 'x', '-Mode', 'resume')).Preview.parent_thread -eq $t0) $eb.bridge_outcome
    $th = Consult $r $rosterMuse @('-DryRun', '-Prompt', 'x', '-Thread', $t0)
    Check 'RESUME' '-Thread <a muse thread>: the thread fixes reviewer AND engine; mode resume; "thread      : <t0> (session resumed with --session-id)"' ($th.Code -eq 0 -and $th.Preview.mode -eq 'resume' -and $th.Preview.reviewer.engine -eq 'muse' -and $th.Preview.command.EndsWith("--session-id $t0") -and $th.Out -match "(?m)^thread      : $t0 \(session resumed with --session-id\)$") (Line $th.Out 'thread ')
}

# =============================================================== REPAIR: the secondary turns through the adapter (D2)
if (Want 'REPAIR') {
    $r = New-Repo 'repair'
    $rl = Join-Path $work 'repair-resume-log.txt'
    $ml = Join-Path $work 'repair-main-log.txt'
    $rc = Join-Path $work 'repair-count.txt'
    $x = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'pr')) @{ FAKE_MUSE_REPLY = $proseFile; FAKE_MUSE_RESUME_REPLY = $repairedFile; FAKE_MUSE_LOG = $ml; FAKE_MUSE_RESUME_LOG = $rl; FAKE_MUSE_COUNT = $rc }
    $e = Last-Entry $r
    $rt = Text $rl
    $rArgs = @(($rt -split "`n") | Where-Object { $_.StartsWith('ARG: ') } | ForEach-Object { $_.Substring(5) })
    $mainPf = @(((Text $ml) -split "`n") | Where-Object { $_.StartsWith('PROMPT-FILE: ') }) | Select-Object -First 1
    $repPf = @(($rt -split "`n") | Where-Object { $_.StartsWith('PROMPT-FILE: ') }) | Select-Object -First 1
    Check 'REPAIR' 'D2: prose first, JSON on the repair turn - the repair''s MSP stream is parsed by the MUSE adapter: structured, format_retry {succeeded, events NN-muse-pr.repair.events.jsonl}, the .reply.json holds the repaired object, engine_run.turns 2 (two subscription prompts), two exec turns' ($x.Code -eq 0 -and $e.structured -eq $true -and $e.format_retry.succeeded -eq $true -and $e.format_retry.events -match '^handoffs/\d\d-muse-pr\.repair\.events\.jsonl$' -and (Test-Path (Td $r $e.format_retry.events)) -and (ConvertFrom-Json (Text (Td $r $e.reply_json))).verdict_reason -eq 'the rules hold' -and $e.engine_run.turns -eq 2 -and (Count-Lines $rc) -eq 2) "$($e.bridge_outcome) turns=$($e.engine_run.turns)"
    Check 'REPAIR' 'D1: the repair turn continues THE session (--session-id <thread>), with the schema, effort low (the route''s lowest), ITS OWN prompt file (not the main turn''s) holding the repair prompt, and an empty stdin' ($rArgs -contains '--session-id' -and $rArgs[$rArgs.Count - 1] -eq $e.thread -and ($rArgs -join ' ') -match "--output-schema $([regex]::Escape($schemaPath)) --model muse-spark-1\.3 --reasoning-effort low " -and $repPf -and $mainPf -and $repPf -ne $mainPf -and $rt -match '(?m)^STDIN-BYTES: 0$' -and $rt.Contains("PROMPT:`nYour last message was prose, not the required JSON.")) "$repPf vs $mainPf"
    # (wave 23b, F09-2) a prompt-only run: the repair turn keeps the main turn's transport
    $pl = Join-Path $work 'repair-po-resume-log.txt'
    $pm = Join-Path $work 'repair-po-main-log.txt'
    $po = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'po', '-SchemaTransport', 'prompt-only')) @{ FAKE_MUSE_REPLY = $proseFile; FAKE_MUSE_RESUME_REPLY = $repairedFile; FAKE_MUSE_LOG = $pm; FAKE_MUSE_RESUME_LOG = $pl }
    $epo = Last-Entry $r
    $pot = Text $pl
    $poArgs = @(($pot -split "`n") | Where-Object { $_.StartsWith('ARG: ') } | ForEach-Object { $_.Substring(5) })
    $pmArgs = @(((Text $pm) -split "`n") | Where-Object { $_.StartsWith('ARG: ') } | ForEach-Object { $_.Substring(5) })
    $frOrder = (($epo.format_retry.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
    Check 'REPAIR' 'F09-2 (wave 23b): -SchemaTransport prompt-only - the main turn AND the repair turn (--session-id) pass no --output-schema, the repair prompt carries the schema as the main prompt does; ledger schema_transport prompt-only, format_retry.schema_transport prompt-only (the native run above: native); format_retry fields ...,original,events,schema_transport' ($po.Code -eq 0 -and $epo.schema_transport -eq 'prompt-only' -and $epo.structured -eq $true -and $epo.format_retry.succeeded -eq $true -and $epo.format_retry.schema_transport -eq 'prompt-only' -and $poArgs.Count -gt 0 -and $poArgs -notcontains '--output-schema' -and $poArgs -contains '--session-id' -and $pmArgs.Count -gt 0 -and $pmArgs -notcontains '--output-schema' -and $pot.Contains('JSON Schema of the reply:') -and $e.format_retry.schema_transport -eq 'native' -and $epo.engine_run.turns -eq 2 -and $frOrder -eq 'attempted,reason,succeeded,thread,wall_seconds,usage,drift,original,events,schema_transport') "repair args: $($poArgs -join ' ') | $frOrder"
    $rc2 = Join-Path $work 'repair-count-2.txt'
    $y = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'nofr', '-FormatRetry', '0')) @{ FAKE_MUSE_REPLY = $proseFile; FAKE_MUSE_COUNT = $rc2 }
    $ey = Last-Entry $r
    $rc3 = Join-Path $work 'repair-count-3.txt'
    $z = Consult $r '' ($museArgs + @('-Prompt', 'x', '-ReplyName', 'empty', '-DenialRetry', '1')) @{ FAKE_MUSE_REPLY = $emptyFile; FAKE_MUSE_COUNT = $rc3 }
    $ez = Last-Entry $r
    Check 'REPAIR' 'D2: -FormatRetry 0 -> no repair turn (one prompt); an empty reply with -DenialRetry 1 -> "failed: empty reply", NO denial retry for muse (denial_retry null, one prompt)' ($y.Code -eq 0 -and $ey.structured -eq $false -and $null -eq $ey.format_retry -and $ey.engine_run.turns -eq 1 -and (Count-Lines $rc2) -eq 1 -and $z.Code -eq 1 -and $ez.bridge_outcome -eq 'failed: empty reply' -and $null -eq $ez.denial_retry -and $ez.engine_run.turns -eq 1 -and (Count-Lines $rc3) -eq 1) "$($ez.bridge_outcome) turns=$($ez.engine_run.turns)"
}

# =============================================================== PANEL: -MaxModelSteps in the panel spec (D9, F02-16)
if (Want 'PANEL') {
    $r = New-Repo 'panel'
    $pd = Consult $r $rosterMuseCodex @('-Panel', '-DryRun', '-Prompt', 'x', '-MaxModelSteps', '40')
    Check 'PANEL' 'a dry-run panel with -MaxModelSteps 40: both members plan, the muse member''s command carries --max-model-steps 40 (the codex member ignores it)' ($pd.Code -eq 0 -and $pd.Out -match '(?m)^  #1 meta :: muse-spark-1\.3 \[muse\] - member' -and $pd.Out -match '--approval-mode never --max-model-steps 40' -and $pd.Out -match '(?m)^  #2 openai :: gpt-5\.1 - member') (Line $pd.Out '  #1')
    $p = Consult $r $rosterMuseCodex @('-Panel', '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'x', '-MaxModelSteps', '40') @{ FAKE_CODEX_REPLY = $advise; FAKE_MUSE_REPLY = $advise }
    $led = @(Ledger $r)
    $em = @($led | Where-Object { $_.reviewer.engine -eq 'muse' })[0]
    $ec = @($led | Where-Object { $_.reviewer.engine -eq 'codex' })[0]
    Check 'PANEL' 'a real panel (muse + codex at once): both usable; the muse member''s ledger engine_run.max_model_steps 40 and its command ends with --max-model-steps 40; the codex member: engine_run null; handoffs NN-muse-x-meta.md / NN-codex-x-openai.md' ($p.Code -eq 0 -and $led.Count -eq 2 -and $em.bridge_outcome -eq 'usable reply' -and $ec.bridge_outcome -eq 'usable reply' -and $em.engine_run.max_model_steps -eq 40 -and $em.command -match ' --max-model-steps 40$' -and $null -eq $ec.engine_run -and $em.reply -match '^handoffs/\d\d-muse-x-meta\.md$' -and $ec.reply -match '^handoffs/\d\d-codex-x-openai\.md$') "$($em.bridge_outcome) / $($ec.bridge_outcome)"
    $pc = Consult $r (Write-Roster 'codex-only' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"}]}') @('-Panel', '-DryRun', '-Prompt', 'x', '-MaxModelSteps', '40')
    Check 'PANEL' '-Panel -MaxModelSteps with no muse member -> refused' ($pc.Code -eq 1 -and $pc.First -eq 'codex-consult: -MaxModelSteps applies to the muse members of a panel (--max-model-steps); no member of this panel runs the muse engine.') $pc.First
}

# =============================================================== LISTING: codex-providers.ps1 (D3, D5, D10)
if (Want 'LISTING') {
    $r = New-Repo 'listing'
    $j = Providers $r $rosterMuseCodex @('-Json')
    $m = @($j.Json | Where-Object { $_.name -eq 'meta' })[0]
    Check 'LISTING' 'JSON: the muse row - engine muse, kind "engine muse", endpoint "muse (<launcher>)", credentials "ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth)", effort vocabulary muse with the 2 declared models, transport native, roster_selected, available' ($j.Code -eq 0 -and $m.engine -eq 'muse' -and $m.kind -eq 'engine muse' -and $m.endpoint -eq "muse ($fakeMuse)" -and $m.credentials -eq 'ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth)' -and $m.effort_vocabulary -eq 'muse' -and (@($m.effort_models) -join ',') -eq 'muse-spark-1.3,muse-spark-1.3-contributor' -and $m.schema_transport -eq 'native' -and $m.roster_selected -eq $true -and $m.verdict -eq 'available') "$($m.credentials) | $($m.verdict)"
    $nn = Providers $r $rosterMuseCodex @('-Json', '-NoNetwork')
    $m2 = @($nn.Json | Where-Object { $_.name -eq 'meta' })[0]
    $tbl = Providers $r $rosterMuseCodex @()
    Check 'LISTING' '-NoNetwork: the muse sign-in check is local and still runs (available); the table shows "engine muse" and effort "muse (2 declared models)"; the roster line selects meta :: muse-spark-1.3 [muse]' ($nn.Code -eq 0 -and $m2.verdict -eq 'available' -and $m2.credentials -match '^ok: signed in' -and $tbl.Out -match '(?m)^available\s+meta\s+1\s+engine muse\s+muse \(.+\)\s+ok: signed in .*muse \(2 declared models\)' -and $tbl.Out -match '(?m)^roster: .* -> would select meta :: muse-spark-1\.3 \[muse\]$') (Line $tbl.Out 'available  meta')
    $copy = Copy-Fake -Dir (Join-Path $work 'providers launcher')
    $ex = Providers $r $rosterMuseCodex @('-Json', '-EngineExe', $copy)
    $m3 = @($ex.Json | Where-Object { $_.name -eq 'meta' })[0]
    $miss = Providers $r $rosterMuseCodex @('-Json') @{ CODEX_CONSULT_MUSE_EXE = '' }
    $m4 = @($miss.Json | Where-Object { $_.name -eq 'meta' })[0]
    Check 'LISTING' 'D3: codex-providers -EngineExe binds to the roster''s muse engine (endpoint "muse (<the copy>)"); no launcher anywhere -> "unavailable (muse CLI not found on PATH)", endpoint "muse (launcher not found)"' ($ex.Code -eq 0 -and $m3.endpoint -eq "muse ($copy)" -and $m4.verdict -eq 'unavailable (muse CLI not found on PATH)' -and $m4.endpoint -eq 'muse (launcher not found)') "$($m3.endpoint) | $($m4.verdict)"
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-muse ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
