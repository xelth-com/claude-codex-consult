# codex-consult engines (0.4.0, ROADMAP R10): the `agy` engine (Google's Antigravity CLI) next
# to codex - roster validation of `engine`, the dry-run argv, a full run's ledger, resume and
# the conversation-id rules, the denial retry (F11), every failure rule and class (with the
# Google wordings and their reset times), the format repair through --conversation, the
# read-only tree check (F12; wave 18: the whole collab directory, the documented blind spot of
# gitignored paths), the timeout kill, the recovery record naming the event stream, a mixed
# panel (codex + agy), the providers listing and the SessionStart hook line, the sign-in check
# (wave 18: 45 s, the ledger short-circuit), and the scoreboards. FAKES ONLY: fake-agy.cmd (CODEX_CONSULT_AGY_EXE) and fake-codex3.cmd
# (CODEX_CONSULT_EXE); CODEX_HOME and CODEX_CONSULT_ROSTER point at scratch files. Runs under
# the host it is started with (powershell 5.1 or pwsh 7, Windows) and launches the scripts with
# the same host. Work files: $env:TEMP\codex-consult-tests\harness-engines\<guid>, removed at
# the end.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$providersPs = Join-Path $scripts 'codex-providers.ps1'
$findingsPs = Join-Path $scripts 'codex-findings.ps1'
$scoreboardPs = Join-Path $scripts 'codex-scoreboard.ps1'
$hookPs = Join-Path $scripts 'codex-consult-hook.ps1'
$schemaPath = [IO.Path]::GetFullPath((Join-Path $repoRoot 'plugins\codex-consult\schemas\consult-reply.schema.json'))
$fakeAgy = Join-Path $sp 'fake-agy.cmd'
$fakeCodex = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-engines') ([guid]::NewGuid().ToString('N'))
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
$savedCodexHome = $env:CODEX_HOME
$savedPath = $env:Path
$script:fails = 0
$script:passes = 0

function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 300) { $ev = $ev.Substring(0, 300) + '...' }
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
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
# The scratch Codex config: the built-in openai, top-level model gpt-5.1 (the codex members).
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), "model = `"gpt-5.1`"`n", $u8)
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
$fakeVars = @('FAKE_AGY_REPLY', 'FAKE_AGY_NOSTRUCTURED', 'FAKE_AGY_RESUME_REPLY', 'FAKE_AGY_STATUS', 'FAKE_AGY_ERROR', 'FAKE_AGY_STDERR', 'FAKE_AGY_CONVERSATION', 'FAKE_AGY_DENIED', 'FAKE_AGY_DENIED_REPLY', 'FAKE_AGY_PARTIAL', 'FAKE_AGY_NORESULT', 'FAKE_AGY_TWORESULTS', 'FAKE_AGY_BADLINE', 'FAKE_AGY_WRITE', 'FAKE_AGY_HANG', 'FAKE_AGY_HANG_ON', 'FAKE_AGY_TRAILING', 'FAKE_AGY_HANG_AFTER', 'FAKE_AGY_EXIT', 'FAKE_AGY_LOG', 'FAKE_AGY_RESUME_LOG', 'FAKE_AGY_PIDFILE', 'FAKE_AGY_MODELS', 'FAKE_AGY_MODELS_LOG', 'FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_FAIL_ON')
$testVars = @('CODEX_CONSULT_EXE', 'CODEX_CONSULT_AGY_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_SURVIVORS', 'CODEX_CONSULT_TEST_LOGIN_TIMEOUT')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
    $env:Path = $savedPath
}
# The fakes are the launchers (CODEX_CONSULT_AGY_EXE, CODEX_CONSULT_EXE); '' in $Env removes a
# variable. $Roster '' = CODEX_CONSULT_ROSTER=none.
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:CODEX_CONSULT_AGY_EXE = $fakeAgy
    $env:CODEX_CONSULT_EXE = $fakeCodex
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome }
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
# The same through Start-Process with a command line quoted by hand (the MS C runtime rules:
# \" for a quote), so a -Prompt with ", \, %VAR% and a newline reaches the bridge unchanged on
# both hosts (Windows PowerShell 5.1 does not escape embedded quotes of native arguments).
function Quote-CArg {
    param([string]$S)
    if ($S -and $S -notmatch '[\s"]') { return $S }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $bs = 0
    foreach ($ch in $S.ToCharArray()) {
        if ($ch -eq '\') { $bs++; continue }
        if ($ch -eq '"') { [void]$sb.Append(('\' * ($bs * 2 + 1)) + '"'); $bs = 0; continue }
        [void]$sb.Append(('\' * $bs) + $ch); $bs = 0
    }
    [void]$sb.Append(('\' * ($bs * 2)) + '"')
    return $sb.ToString()
}
function Consult-Quoted {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't') + $ArgList
    $line = ($all | ForEach-Object { Quote-CArg $_ }) -join ' '
    $outFile = Join-Path $work ("quoted-" + [guid]::NewGuid().ToString('N') + '.txt')
    $proc = Start-Process -FilePath $psExe -ArgumentList $line -WorkingDirectory $Repo -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err"
    Restore-Env
    $out = @([IO.File]::ReadAllText($outFile) -split "`r?`n") + @([IO.File]::ReadAllText("$outFile.err") -split "`r?`n")
    return (ConvertFrom-RunOutput $out $proc.ExitCode)
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
function Run-Tool {
    param([string]$Script, [string]$Repo, [string[]]$ArgList)
    Set-CaseEnv '' @{}
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgList 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $c = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return [pscustomobject]@{ Code = $c; Out = $o; First = (($o -split "`n") | Select-Object -First 1) }
}
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Ledger { param([string]$Repo, [string]$Task = 't') $f = Join-Path $Repo ".collab\$Task\sessions.json"; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (Ledger $Repo)[-1] }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Td { param([string]$Repo, [string]$Rel) return (Join-Path (Join-Path $Repo '.collab\t') ($Rel -replace '/', '\')) }
function Text { param([string]$Path) if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Seed-Task {
    param([string]$Repo, [object[]]$Entries)
    $dir = Join-Path $Repo '.collab\t'
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = 't'; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } })
}
function Uuid { return [guid]::NewGuid().ToString() }
$uuidRe = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

$model = 'gemini-3.8-flash-high'
$agyFp = Get-Sha256Hex ($u8.GetBytes('cc-engine-v1|agy'))
# An agy ledger entry that can be a parent (a verified conversation of lineage gemini :: model).
function New-AgyEntry {
    param([int]$N, [string]$Thread, [string]$Model = 'gemini-3.8-flash-high', [string]$Provider = 'gemini')
    return [pscustomobject]@{ n = $N; when = (Get-IsoTimestamp); purpose = ''; reviewer = [pscustomobject]@{ provider = $Provider; model = $Model; engine = 'agy'; provider_fingerprint = $agyFp }; lineage = "$Provider :: $Model"; thread = $Thread; thread_source = 'events'; mode = 'new'; reply = ('handoffs/{0:D2}-agy-seed.md' -f $N); bridge_outcome = 'usable reply' }
}

$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"c","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
$adviseF = Reply 'advise-finding.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$prose = "**Q1.** The design of the engine table is sound and keeps the codex path unchanged for every existing reviewer.`n**Q2.** The conversation rules close the resume gap because a new conversation is never taken as the parent thread.`n`nVerdict: ADVISE`n"
$proseFile = Reply 'prose.md' $prose
$proseMd = $prose -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n'
$repairedFile = Reply 'repaired.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"the rules hold","reply_markdown":"' + $proseMd + '","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$rosterAgy = Write-Roster 'agy' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"' + $model + '"}]}')

try {
# =============================================================== UNIT: classifier + reset times (A5, A13), the event parser, the process rule
if (Want 'UNIT') {
    $f11 = 'jetski: no output produced ' + [char]0x2014 + ' a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow in settings.json (e.g. command(<target>)).'
    $samples = [ordered]@{
        $f11                                                                   = 'permission'
        'RESOURCE_EXHAUSTED: Quota exceeded for the day. Please retry in 32s.' = 'quota'
        'rate_limit_exceeded: retry in 1m5.3s'                                = 'quota'
        'UNAUTHENTICATED: Request had invalid authentication credentials.'   = 'auth'
        'PERMISSION_DENIED: The caller does not have permission'             = 'auth'
        'Error: you are not signed in. Run agy to sign in.'                    = 'auth'
        'login required'                                                       = 'auth'
        'Please sign in to continue'                                           = 'auth'
        'invalid model selection (unknown tier) --model gemini-3.8-flash-low conflicts with --effort=max' = 'capability'
        'INVALID_ARGUMENT: the schema is not valid'                            = 'capability'
        'UNAVAILABLE: The service is currently unavailable.'                   = 'transport'
        'DEADLINE_EXCEEDED: the request took too long'                         = 'transport'
        'Your token plan does not support response_format'                     = 'capability'
        '401 Unauthorized'                                                     = 'auth'
        'text authored by the reviewer'                                        = 'unknown'
    }
    $badC = @($samples.Keys | Where-Object { (Get-ProviderFailureClass $_) -ne $samples[$_] } | ForEach-Object { "$_ -> $(Get-ProviderFailureClass $_)" })
    Check 'UNIT' "Get-ProviderFailureClass: permission first; Google codes and wordings (quota, auth, capability, transport); the 0.3.0 samples unchanged ($($samples.Count) samples)" ($badC.Count -eq 0) ($badC -join ' | ')

    $ref = [DateTimeOffset]::Parse('2026-09-25T12:00:00+02:00', $inv)
    $cases = @(
        @{ Msg = 'RESOURCE_EXHAUSTED: Please retry in 32s.'; Secs = 32 },
        @{ Msg = 'rate_limit_exceeded: retry in 1m5.3s'; Secs = 66 },
        @{ Msg = 'Too many requests - retry after 2h'; Secs = 7200 },
        @{ Msg = 'quota exhausted, retry in 90 seconds'; Secs = 90 },
        @{ Msg = 'retry in 1h30m'; Secs = 5400 },
        @{ Msg = '{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","details":[{"@type":"type.googleapis.com/google.rpc.RetryInfo","retryDelay":{"seconds":45}}]}}'; Secs = 45 },
        @{ Msg = 'details: [{ "@type": "type.googleapis.com/google.rpc.RetryInfo", "retryDelay": "17s" }]'; Secs = 17 },
        @{ Msg = 'retryDelay: 32s'; Secs = 32 },
        @{ Msg = 'please retry later'; Secs = -1 }
    )
    $badR = @()
    foreach ($c in $cases) {
        $got = Get-RetryAfter -Message $c.Msg -Reference $ref -ReferenceOffset
        $want = if ($c.Secs -lt 0) { $null } else { $ref.AddSeconds($c.Secs) }
        if (($null -eq $want -and $null -ne $got) -or ($null -ne $want -and ($null -eq $got -or $got.UtcTicks -ne $want.UtcTicks))) { $badR += "$($c.Msg) -> $got (want $want)" }
    }
    Check 'UNIT' "Get-RetryAfter learns Google's wordings: retry in 32s / 1m5.3s (rounded up) / 90 seconds / 1h30m, retry after 2h, retryDelay {seconds} / ""17s"" / 32s; nothing -> null ($($cases.Count) samples)" ($badR.Count -eq 0) ($badR -join ' | ')

    $pfq = New-ProviderFailure -Texts @('{"error":{"code":429,"message":"Resource has been exhausted (e.g. check quota).","status":"RESOURCE_EXHAUSTED","details":[{"@type":"type.googleapis.com/google.rpc.RetryInfo","retryDelay":"30s"}]}}')
    $pfqAt = ConvertTo-WhenOffset $pfq.retry_after
    $pfqWhen = ConvertTo-WhenOffset $pfq.when
    Check 'UNIT' 'New-ProviderFailure on a gRPC payload: class quota, code 429, retry_after = when + 30 s from details.retryDelay (outside error.message)' ($pfq.class -eq 'quota' -and $pfq.code -eq '429' -and $null -ne $pfqAt -and [Math]::Abs(($pfqAt - $pfqWhen).TotalSeconds - 30) -le 1) "$($pfq.class) $($pfq.code) $($pfq.when) -> $($pfq.retry_after)"
    $pfp = New-ProviderFailure -Texts @($f11) -Class 'permission'
    Check 'UNIT' 'New-ProviderFailure -Class forces the class (permission), the message is the stderr line' ($pfp.class -eq 'permission' -and $pfp.message.StartsWith('jetski: no output produced')) $pfp.message

    # Read-AgyEvents: the real shapes (init top-level id, nested step ids, one result)
    $ev = Join-Path $work 'unit-events.jsonl'
    $cid = Uuid
    [IO.File]::WriteAllText($ev, (@(
                ('{"event":"init","conversation_id":"' + $cid + '","init":{"model":"m","permission_mode":"request-review"}}'),
                ('{"event":"step_update","step_update":{"conversation_id":"' + $cid + '","step_index":2,"state":"DONE","step_type":"tool","tool_name":"run_command"}}'),
                ('{"event":"result","result":{"conversation_id":"' + $cid + '","status":"SUCCESS","response":"{\"x\":1,\"toolAction\":\"finish\"}","structured_output":{"x":1},"usage":{"input_tokens":10,"output_tokens":2,"thinking_tokens":1,"cache_read_tokens":4,"total_tokens":12},"denied_actions":{"action":"command","display_name":"RunCommand"}}}')
            ) -join "`n") + "`n", $u8)
    $pe = Read-AgyEvents -Path $ev
    Check 'UNIT' 'Read-AgyEvents: init id, the result (status, structured_output compact, NOT the response), usage mapped (cache_read -> cached_input, thinking -> reasoning_output, total), last tool step, denied action' ($pe.InitThread -eq $cid -and $pe.Thread -eq $cid -and $pe.ResultCount -eq 1 -and -not $pe.Malformed -and $pe.Status -eq 'SUCCESS' -and $pe.HasStructured -and $pe.StructuredJson -eq '{"x":1}' -and $pe.Usage.input_tokens -eq 10 -and $pe.Usage.cached_input_tokens -eq 4 -and $pe.Usage.reasoning_output_tokens -eq 1 -and $pe.Usage.total_tokens -eq 12 -and $pe.ToolName -eq 'run_command' -and $pe.DeniedAction -eq 'RunCommand') "$($pe.StructuredJson) / $($pe.Usage | ConvertTo-Json -Compress)"
    [IO.File]::WriteAllText($ev, ('{"event":"init","conversation_id":"' + $cid + '"}' + "`n" + 'garbage' + "`n" + '{"event":"result","result":{"conversation_id":"' + $cid + '","status":"SUCCESS","response":"x"}}' + "`n" + '{"event":"res'), $u8)
    $pm = Read-AgyEvents -Path $ev -AllowPartialLast
    Check 'UNIT' 'Read-AgyEvents: a bad line inside the stream is malformed; a truncated LAST line is tolerated (-AllowPartialLast)' ($pm.Malformed -eq 'line 2 is not a JSON object' -and $pm.HasResult) $pm.Malformed
    # F10-2: trailing garbage after a valid result is a partial line only after a kill / non-zero exit
    [IO.File]::WriteAllText($ev, ('{"event":"init","conversation_id":"' + $cid + '"}' + "`n" + '{"event":"result","result":{"conversation_id":"' + $cid + '","status":"SUCCESS","response":"x"}}' + "`n" + '{"event":"res'), $u8)
    $pt0 = Read-AgyEvents -Path $ev
    $pt1 = Read-AgyEvents -Path $ev -AllowPartialLast
    Check 'UNIT' 'F10-2: a valid result followed by a garbage last line - malformed ("line 3 is not a JSON object") without -AllowPartialLast (exit 0), tolerated with it (killed / non-zero exit)' ($pt0.Malformed -eq 'line 3 is not a JSON object' -and $pt0.HasResult -and -not $pt1.Malformed -and $pt1.HasResult -and $pt1.Thread -eq $cid) "without: '$($pt0.Malformed)' with: '$($pt1.Malformed)'"
    # the collab snapshot (wave 18): every file under the root, recursively; .consult.* and .git left out
    $cs = Join-Path $work 'collab-snap'
    foreach ($f in @('t\sessions.json', 't\state.md', 't\handoffs\01-codex-a.md', 'u\handoffs\02-agy-b.md', 't\.consult.lock', 't\.consult.pending.json', 't\..consult.pending.json.abc.tmp', '.git\HEAD')) {
        $p = Join-Path $cs $f
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p))
        [IO.File]::WriteAllText($p, "x`n", $u8)
    }
    $snap = Get-CollabSnapshot -Dir $cs
    $keys = @($snap.Keys | Sort-Object)
    [IO.File]::WriteAllText((Join-Path $cs 'u\handoffs\02-agy-b.md'), "changed`n", $u8)
    [IO.File]::WriteAllText((Join-Path $cs 't\handoffs\03-agy-own.events.jsonl'), "own`n", $u8)
    $diff = Compare-DirectorySnapshot -Before $snap -After (Get-CollabSnapshot -Dir $cs) -IgnorePrefixes @('t/handoffs/03-agy-own.')
    Check 'UNIT' 'Get-CollabSnapshot: every file under the collab root, recursively, as "/"-paths (all task stores and handoffs), without .consult.* files and .git; a change in ANOTHER task is found, the run''s own files are not' (($keys -join ',') -eq 't/handoffs/01-codex-a.md,t/sessions.json,t/state.md,u/handoffs/02-agy-b.md' -and (@($diff) -join ',') -eq 'u/handoffs/02-agy-b.md') "$($keys -join ',') | diff: $(@($diff) -join ',')"

    $rule = Get-CodexRule -Name 'agy' -Cmd '' -Launcher 'C:\x\agy.exe'
    $rule2 = Get-CodexRule -Name 'agy.exe' -Cmd '' -Launcher 'C:\x\agy.exe'
    $rule3 = Get-CodexRule -Name 'cmd.exe' -Cmd 'cmd /c "C:\t\fake-agy.cmd" -p=' -Launcher 'C:\t\fake-agy.cmd'
    $rule4 = Get-CodexRule -Name 'agy' -Cmd '' -Launcher 'C:\t\fake-agy.cmd'
    Check 'UNIT' 'Get-CodexRule (A14): agy.exe found by the recorded launcher''s name (with or without .exe) and a shim by the launcher in the command line; a .cmd launcher gives no name rule' ($rule -eq 'name agy (the recorded launcher)' -and $rule2 -eq $rule -and $rule3 -eq 'launcher in command line' -and $rule4 -eq '') "$rule | $rule3 | '$rule4'"
}

# =============================================================== ROSTER: the `engine` field (fail-closed)
if (Want 'ROSTER') {
    $r = New-Repo 'roster'
    $bad = [ordered]@{
        'unknown'   = @('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"gemini-cli","model":"m"}]}', 'entry 1: engine must be one of: codex, agy \(got "gemini-cli"\)')
        'nomodel'   = @('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy"}]}', 'entry 1: engine agy needs a model')
        'cfg'       = @('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"m","codex_config":["a=b"]}]}', 'entry 1: codex_config does not apply to engine agy')
        'auth'      = @('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"m","auth":"none"}]}', 'entry 1: auth does not apply to engine agy')
        'twoengines' = @('{"roster_version":1,"reviewers":[{"provider":"gemini","model":"m"},{"provider":"gemini","engine":"agy","model":"n"}]}', "entries 1 and 2 use the provider label 'gemini' with two engines \(codex, agy\)")
    }
    $failed = @()
    foreach ($k in $bad.Keys) {
        $path = Write-Roster "bad-$k" $bad[$k][0]
        $o = Consult $r $path @('-DryRun', '-Prompt', 'x')
        $want = '^codex-consult: the reviewer roster ''' + [regex]::Escape($path) + ''' is not usable: ' + $bad[$k][1]
        if (-not ($o.Code -eq 1 -and $o.First -match $want)) { $failed += "$k -> $($o.First)" }
    }
    Check 'ROSTER' "refused (-DryRun too): $(@($bad.Keys) -join ', ')" ($failed.Count -eq 0) ($failed -join ' | ')
    $mixed = Write-Roster 'mixed' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"' + $model + '"},{"provider":"gemini","engine":"agy","model":"gemini-3.1-pro-high","panel":"weighty"},{"provider":"openai","model":"gpt-5.1","engine":"codex"}]}')
    $rr = Read-ReviewerRoster -Location ([pscustomobject]@{ Path = $mixed; FromEnv = $true; Disabled = $false })
    Check 'ROSTER' 'a valid mixed roster: entries carry Engine (agy, agy, codex) and EngineDeclared; one label with two models of one engine is fine (A15)' (-not $rr.Error -and @($rr.Entries).Count -eq 3 -and $rr.Entries[0].Engine -eq 'agy' -and $rr.Entries[2].Engine -eq 'codex' -and $rr.Entries[2].EngineDeclared) $rr.Error
    $d = Consult $r $mixed @('-DryRun', '-Prompt', 'x')
    Check 'ROSTER' 'the walk selects entry 1 (agy): engine from the roster, roster.applied [engine, model], lineage shown with [agy]' ($d.Code -eq 0 -and $d.Preview.reviewer.engine -eq 'agy' -and $d.Preview.reviewer.provider -eq 'gemini' -and (@($d.Preview.roster.applied) -join ',') -eq 'engine,model' -and $d.Out -match '(?m)^lineage     : gemini :: gemini-3\.8-flash-high \[agy\]$' -and $d.Out -match '(?m)^engine      : agy - Gemini \(agy\) \(from roster\)$') (Line $d.Out 'lineage')
    $d2 = Consult $r $mixed @('-DryRun', '-Prompt', 'x', '-Provider', 'gemini', '-Model', 'gemini-3.1-pro-high')
    Check 'ROSTER' 'A15: -Provider gemini -Model gemini-3.1-pro-high picks the weighty entry (exact model), engine agy' ($d2.Code -eq 0 -and $d2.Preview.reviewer.model -eq 'gemini-3.1-pro-high' -and $d2.Preview.reviewer.engine -eq 'agy' -and $d2.Preview.roster.position -eq 2) (Line $d2.Out 'Roster:')
    # F10-3: a label that names several entries, without -Model -> the first entry (0.3.0 rule) + a warning
    $lw = Consult $r $mixed @('-DryRun', '-Prompt', 'x', '-Provider', 'gemini')
    $lwText = "roster: label gemini names 2 entries; the first (gemini :: $model [agy]) is used - pass -Model for another"
    Check 'ROSTER' 'F10-3: -Provider gemini without -Model on a roster with two gemini entries -> the first entry (flash) is used, the console says "WARNING: roster: label gemini names 2 entries; the first (...) is used - pass -Model for another", and warnings[] records it; with -Model no warning' ($lw.Code -eq 0 -and $lw.Preview.reviewer.model -eq $model -and $lw.Preview.roster.position -eq 1 -and $lw.Out -match ('(?m)^WARNING: ' + [regex]::Escape($lwText) + '$') -and @($lw.Preview.warnings).Count -eq 1 -and $lw.Preview.warnings[0] -eq $lwText -and @($d2.Preview.warnings).Count -eq 0 -and $d2.Out -notmatch 'names 2 entries') "$(@($lw.Preview.warnings) -join ' | ')"
    $d3 = Consult $r $mixed @('-DryRun', '-Prompt', 'x', '-Engine', 'codex')
    $d4 = Consult $r $mixed @('-DryRun', '-Prompt', 'x', '-Provider', 'gemini', '-Engine', 'codex')
    Check 'ROSTER' '-Engine codex walks only the codex entries (-> openai, roster.applied without engine: entry 3 declares it but -Engine chose); -Provider gemini -Engine codex contradicts the entry -> refused' ($d3.Code -eq 0 -and $d3.Preview.reviewer.provider -eq 'openai' -and $d3.Preview.reviewer.engine -eq 'codex' -and $d4.Code -eq 1 -and $d4.First -match '^codex-consult: -Engine codex: the roster entry 1 for -Provider gemini is engine agy') "$($d3.Preview.reviewer.provider) | $($d4.First)"
    $skipAgy = Consult $r $mixed @('-DryRun', '-Prompt', 'x') @{ FAKE_AGY_MODELS = 'out' }
    Check 'ROSTER' 'agy not signed in -> both agy entries skipped (one `agy models` for both), the walk selects openai; roster.skipped entries carry engine agy' ($skipAgy.Code -eq 0 -and $skipAgy.Preview.reviewer.provider -eq 'openai' -and @($skipAgy.Preview.roster.skipped).Count -eq 2 -and $skipAgy.Preview.roster.skipped[0].engine -eq 'agy' -and $skipAgy.Preview.roster.skipped[0].reason -match '^missing: `agy models`: Error: you are not signed in' -and $skipAgy.Out -match 'skipped gemini :: gemini-3\.8-flash-high \[agy\] \(missing') (Line $skipAgy.Out 'Roster:')
}

# =============================================================== DRYRUN: argv, refusals, prompt
if (Want 'DRYRUN') {
    $r = New-Repo 'dry'
    $base = @('-DryRun', '-Engine', 'agy', '-Provider', 'gemini', '-Model', $model, '-Prompt', 'smoke', '-Purpose', 'framing')
    $d = Consult $r '' $base
    $wantCmd = "agy -p= --input-format stream-json --output-format stream-json --model $model --json-schema $schemaPath --print-timeout 0 --sandbox --disable-slash-commands"
    Check 'DRYRUN' 'argv: -p= --input-format stream-json --output-format stream-json --model <m> --json-schema <schema> --print-timeout 0 --sandbox --disable-slash-commands (no --effort, no --conversation); command starts with agy' ($d.Code -eq 0 -and $d.Preview.command -eq $wantCmd) $d.Preview.command
    Check 'DRYRUN' 'identity: provider gemini (from -Provider), engine agy, fingerprint sha256(cc-engine-v1|agy), provider_config {engine, launcher}; effort nothing sent (model-tier); transport native; mode new; sandbox record' ($d.Preview.reviewer.engine -eq 'agy' -and $d.Preview.reviewer.provider_fingerprint -eq $agyFp -and $d.Preview.reviewer.provider_config.engine -eq 'agy' -and $d.Preview.reviewer.provider_config.launcher -eq $fakeAgy -and $null -eq $d.Preview.effort_sent -and $d.Preview.effort_mapping -eq 'model-tier' -and $d.Preview.schema_transport -eq 'native' -and $d.Preview.mode -eq 'new' -and $d.Preview.sandbox -eq 'read-only (requested; enforced by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; agy --sandbox restricts the terminal only)' -and $d.Out -match '(?m)^preflight   : available \(ok: signed in \(3 models\)\)$' -and $d.Out -match '(?m)^effort      : nothing sent \(requested high, mapping model-tier, by caps-v1: engine agy, the tier is part of the model id\)$') (Line $d.Out 'preflight')
    Check 'DRYRUN' 'A9/A17a: the tools line right after the ask (no brief): read files only, never run_command, make NO file changes, checks under Requested checks' ($d.Out.Contains("smoke`n`nTools: you may read files of the repository; you have NO permission to run commands in this consultation - never call run_command; make NO file changes; a check that needs a command belongs under ``## Requested checks``.") -or $d.Out.Contains("smoke`r`n`r`nTools: you may read files")) ''
    Check 'DRYRUN' 'the preview has warnings [] and denial_retry (a placeholder), reply names NN-agy-reply.*' (@($d.Preview.warnings).Count -eq 0 -and $d.Preview.PSObject.Properties['denial_retry'] -and $d.Preview.reply -match '^handoffs/\d\d-agy-reply\.md$' -and $d.Preview.events -match '^handoffs/\d\d-agy-reply\.events\.jsonl$') $d.Preview.reply
    $n1 = Consult $r '' ($base + @('-NativeEffort', 'high'))
    Check 'DRYRUN' '-NativeEffort high -> --effort high at the end, effort_sent high, mapping native' ($n1.Code -eq 0 -and $n1.Preview.command -eq "$wantCmd --effort high" -and $n1.Preview.effort_sent -eq 'high' -and $n1.Preview.effort_mapping -eq 'native') $n1.Preview.command
    $p1 = Consult $r '' ($base + @('-SchemaTransport', 'prompt-only'))
    Check 'DRYRUN' '-SchemaTransport prompt-only -> no --json-schema, the schema in the prompt' ($p1.Code -eq 0 -and $p1.Preview.command -notmatch '--json-schema' -and $p1.Preview.schema_transport -eq 'prompt-only' -and $p1.Out.Contains('JSON Schema of the reply:')) $p1.Preview.command
    $refusals = [ordered]@{
        'fork'           = @(@('-Mode', 'fork'), '^codex-consult: the agy engine has no fork; use -Mode resume or new\.$')
        'workspace'      = @(@('-Sandbox', 'workspace-write'), '^codex-consult: -Sandbox workspace-write is refused for the agy engine')
        'output-schema'  = @(@('-SchemaTransport', 'output-schema'), '^codex-consult: -SchemaTransport output-schema is refused for the agy engine: it takes native or prompt-only')
        'codex-config'   = @(@('-CodexConfig', 'a=b'), '^codex-consult: -CodexConfig does not apply to the agy engine')
        'no-model'       = @(@(), '^codex-consult: the agy engine needs a model')
    }
    $badR = @()
    foreach ($k in $refusals.Keys) {
        $args2 = @('-DryRun', '-Engine', 'agy', '-Prompt', 'x') + @($refusals[$k][0])
        if ($k -ne 'no-model') { $args2 += @('-Model', $model) }
        $o = Consult $r '' $args2
        if (-not ($o.Code -eq 1 -and $o.First -match $refusals[$k][1])) { $badR += "$k -> $($o.First)" }
    }
    $nat = Consult $r '' @('-DryRun', '-Prompt', 'x', '-SchemaTransport', 'native')
    if (-not ($nat.Code -eq 1 -and $nat.First -match '^codex-consult: -SchemaTransport native is for the agy engine')) { $badR += "codex native -> $($nat.First)" }
    Check 'DRYRUN' "refused, one message each: $(@($refusals.Keys) -join ', '), and -SchemaTransport native for codex" ($badR.Count -eq 0) ($badR -join ' | ')
    # resume: --conversation <the parent>
    $t0 = Uuid
    Seed-Task $r @((New-AgyEntry 1 $t0))
    $rs = Consult $r '' ($base + @('-Mode', 'resume'))
    $def = Consult $r '' $base
    Check 'DRYRUN' '-Mode resume -> --conversation <newest thread of the lineage> after --disable-slash-commands; without -Mode the agy default is new even with a parent (A1)' ($rs.Code -eq 0 -and $rs.Preview.command -eq "$wantCmd --conversation $t0" -and $rs.Preview.parent_thread -eq $t0 -and $def.Preview.mode -eq 'new' -and $def.Preview.command -eq $wantCmd) $rs.Preview.command
    $th = Consult $r $rosterAgy @('-DryRun', '-Prompt', 'x', '-Thread', $t0)
    Check 'DRYRUN' '-Thread <agy thread> with a roster: the thread fixes reviewer AND engine; mode resume by default' ($th.Code -eq 0 -and $th.Preview.mode -eq 'resume' -and $th.Preview.reviewer.engine -eq 'agy' -and $th.Preview.command.EndsWith("--conversation $t0")) $th.Preview.command
    $raw = Consult $r '' @('-DryRun', '-Engine', 'agy', '-Model', $model, '-Prompt', 'find x', '-Purpose', 'chore')
    Check 'DRYRUN' '-Purpose chore on agy: no --json-schema, the tools line still there, effort nothing sent' ($raw.Code -eq 0 -and $raw.Preview.command -notmatch '--json-schema' -and $raw.Out.Contains('never call run_command')) $raw.Preview.command
}

# =============================================================== RUN: a full fake run
if (Want 'RUN') {
    $r = New-Repo 'run'
    $log = Join-Path $work 'run-log.txt'
    $ask = 'Check "quoted" words, a path C:\tmp\x\ and %APPDATA%' + "`n" + 'second line ' + [char]0x00FC + [char]0x2019
    $x = Consult-Quoted $r '' @('-Engine', 'agy', '-Provider', 'gemini', '-Model', $model, '-Prompt', $ask, '-Purpose', 'framing', '-ReplyName', 'run') @{ FAKE_AGY_REPLY = $adviseF; FAKE_AGY_LOG = $log }
    $e = Last-Entry $r
    Check 'RUN' 'usable reply; ledger reviewer.engine agy, provider gemini, fingerprint, lineage, command starts with "agy -p=", schema_transport native' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply' -and $e.reviewer.engine -eq 'agy' -and $e.reviewer.provider -eq 'gemini' -and $e.reviewer.provider_fingerprint -eq $agyFp -and $e.lineage -eq "gemini :: $model" -and $e.command.StartsWith('agy -p= ') -and $e.schema_transport -eq 'native' -and $e.reviewer.harness -eq 'agy-cli (version unknown)') "$($e.bridge_outcome) / $($x.First)"
    $stdinRaw = [IO.File]::ReadAllBytes("$log.stdin")
    $stdinText = $u8.GetString($stdinRaw)
    $msg = $null
    try { $msg = ConvertFrom-Json -InputObject $stdinText } catch { }
    $content = if ($msg) { [string]$msg.message.content } else { '' }
    Check 'RUN' 'A16: stdin = ONE NDJSON line {"event":"user","message":{"content":...}} + LF, UTF-8 without BOM; content = the composed prompt (length = prompt_chars, ends with the consultation id)' ($stdinRaw.Length -gt 3 -and -not ($stdinRaw[0] -eq 0xEF -and $stdinRaw[1] -eq 0xBB) -and $stdinText.EndsWith("`n") -and ($stdinText.TrimEnd("`n").IndexOf("`n") -lt 0) -and $msg.event -eq 'user' -and $content.Length -eq [int]$e.prompt_chars -and $content.EndsWith("Consultation id: $($e.consult_id)") -and $content.StartsWith('FINAL OUTPUT CONTRACT')) "bytes=$($stdinRaw.Length) chars=$($content.Length)/$($e.prompt_chars)"
    Check 'RUN' 'A8: the ask with ", \, %APPDATA%, a newline and non-ASCII arrives byte for byte (cmd.exe never sees the prompt)' ($content.Contains(($ask -replace "`n", "`r`n")) -or $content.Contains($ask)) ''
    $tl = [IO.File]::ReadAllText($log, $u8)
    Check 'RUN' 'the fake saw the argv: --model, --json-schema, --print-timeout 0, --sandbox, --disable-slash-commands, no --conversation, no --effort' ($tl -match "ARGS: -p= --input-format stream-json --output-format stream-json --model $([regex]::Escape($model)) --json-schema \S+ --print-timeout 0 --sandbox --disable-slash-commands\s*`n" -and $tl -notmatch '--conversation|--effort') (($tl -split "`n")[0])
    Check 'RUN' 'thread = result.conversation_id (uuid), source events; usage mapped (in 13000, cached 4000, out 500, reasoning 120, total 13500); effort null, mapping model-tier; warnings [], denial_retry null' ($e.thread -match $uuidRe -and $e.thread_source -eq 'events' -and $e.usage.input_tokens -eq 13000 -and $e.usage.cached_input_tokens -eq 4000 -and $e.usage.output_tokens -eq 500 -and $e.usage.reasoning_output_tokens -eq 120 -and $e.usage.total_tokens -eq 13500 -and $null -eq $e.effort -and $e.effort_mapping -eq 'model-tier' -and @($e.warnings).Count -eq 0 -and $null -eq $e.denial_retry) ($e.usage | ConvertTo-Json -Compress)
    $order = 'n,when,purpose,consult_id,reviewer,lineage,preflight,preflight_warning,roster,panel,parent_thread,thread,thread_source,thread_candidate,mode,command,brief,prompt_chars,reply,reply_json,events,model,effort,effort_requested,effort_sent,effort_mapping,effort_caps,effort_confirmed,max_words,sandbox,extra_config,extra_config_source,peak,peak_schedule,peak_source,peak_evaluated_at,structured,schema,schema_transport,schema_transport_source,validation_error,format_retry,denial_retry,base_commit,reviewed_revision,tree_sha256,tree_sha256_after,tree_changed_during_review,changed_files,brief_sha256,brief_sha256_after,brief_changed_during_review,fingerprint_note,artifacts,artifacts_changed_during_review,bridge_outcome,provider_failure,warnings,verdict,verdict_reason,findings,finding_ids,prior_findings,unchecked_prior_blockers,usage,wall_seconds'
    Check 'RUN' 'ledger fields in the same order as a codex entry' ((($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq $order) ''
    $rj = Td $r $e.reply_json
    $rjText = Text $rj
    Check 'RUN' 'handoff names NN-agy-run.{md,reply.json,events.jsonl}; .reply.json = structured_output compact (NOT the response with toolAction)' ($e.reply -match '^handoffs/\d\d-agy-run\.md$' -and $e.reply_json -match '^handoffs/\d\d-agy-run\.reply\.json$' -and $e.events -match '^handoffs/\d\d-agy-run\.events\.jsonl$' -and (Test-Path (Td $r $e.events)) -and $rjText -notmatch 'toolAction' -and (ConvertFrom-Json $rjText).verdict -eq 'ADVISE') $rjText.Substring(0, [Math]::Min(80, $rjText.Length))
    $fs = [IO.File]::ReadAllText((Join-Path $r '.collab\t\findings.json'), $u8) | ConvertFrom-Json
    Check 'RUN' 'the finding is ingested (findings.json, finding_ids), structured true, verdict ADVISE' ($e.structured -eq $true -and $e.verdict -eq 'ADVISE' -and @($e.finding_ids).Count -eq 1 -and @($fs.findings).Count -eq 1 -and $fs.findings[0].source.consult -eq $e.n) (@($e.finding_ids) -join ',')
    $md = Text (Td $r $e.reply)
    Check 'RUN' 'handoff header "# Handoff NN - Gemini (agy): run", Author line, Reviewer line with [agy], the Argv with agy, no pending record left' ($md -match '(?m)^# Handoff \d\d - Gemini \(agy\): run$' -and $md -match '(?m)^Date: .* Author: Gemini \(agy\) \(model gemini-3\.8-flash-high, effort tier in the model id\), agy-cli \(version unknown\)\.$' -and $md -match '(?m)^Reviewer: gemini :: gemini-3\.8-flash-high \[agy\] \(provider from -Provider' -and $md -match 'Argv: `agy -p= ' -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) (($md -split "`n")[0])
}

# =============================================================== RESUME: the conversation-id rules (A12)
if (Want 'RESUME') {
    $r = New-Repo 'resume'
    $t0 = Uuid
    Seed-Task $r @((New-AgyEntry 1 $t0))
    $rlog = Join-Path $work 'resume-log.txt'
    $a = Consult $r $rosterAgy @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'res') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_RESUME_LOG = $rlog }
    $ea = Last-Entry $r
    Check 'RESUME' '-Mode resume, agy answers on the same conversation -> usable, mode resume, parent = thread = the seeded conversation, argv --conversation' ($a.Code -eq 0 -and $ea.mode -eq 'resume' -and $ea.parent_thread -eq $t0 -and $ea.thread -eq $t0 -and $ea.bridge_outcome -eq 'usable reply' -and (Text $rlog) -match "--conversation $t0") $ea.bridge_outcome
    $b = Consult $r $rosterAgy @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'gone') @{ FAKE_AGY_REPLY = $adviseF; FAKE_AGY_CONVERSATION = 'notfound' }
    $eb = Last-Entry $r
    Check 'RESUME' 'the not-found warning -> FAILED: "parent conversation <p> not found, agy started <new>", class unknown, thread "" and the new id a candidate only; the reply kept (.reply.json) and named; nothing ingested' ($b.Code -eq 1 -and $eb.bridge_outcome -match "^failed: parent conversation $t0 not found, agy started [0-9a-f-]{36} \(warning: conversation" -and $eb.provider_failure.class -eq 'unknown' -and $eb.thread -eq '' -and $eb.thread_candidate -match $uuidRe -and $eb.thread_candidate -ne $t0 -and $eb.reply_json -and (Test-Path (Td $r $eb.reply_json)) -and @($eb.finding_ids).Count -eq 0 -and -not (Test-Path (Join-Path $r '.collab\t\findings.json'))) $eb.bridge_outcome
    $c = Consult $r $rosterAgy @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'other') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_CONVERSATION = 'other' }
    $ec = Last-Entry $r
    Check 'RESUME' 'another conversation id WITHOUT the warning -> failed the same way (class unknown, candidate only)' ($c.Code -eq 1 -and $ec.bridge_outcome -match "^failed: parent conversation $t0 not found, agy started " -and $ec.thread -eq '' -and $ec.provider_failure.class -eq 'unknown') $ec.bridge_outcome
    $d = Consult $r $rosterAgy @('-DryRun', '-Prompt', 'x', '-Mode', 'resume')
    Check 'RESUME' 'the next resume still names the verified conversation, never the failed runs'' new ids' ($d.Code -eq 0 -and $d.Preview.parent_thread -eq $t0) $d.Preview.parent_thread
    $m = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'mm') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_CONVERSATION = 'mismatch' }
    $em = Last-Entry $r
    $u = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'nu') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_CONVERSATION = 'notuuid' }
    $eu = Last-Entry $r
    Check 'RESUME' 'init id != result id -> failed (class unknown, the result id a candidate); a result id that is not a uuid -> failed (class unknown)' ($m.Code -eq 1 -and $em.bridge_outcome -match '^failed: conversation id mismatch: init [0-9a-f-]{36}, result [0-9a-f-]{36}$' -and $em.provider_failure.class -eq 'unknown' -and $em.thread -eq '' -and $u.Code -eq 1 -and $eu.bridge_outcome -eq "failed: the result's conversation_id 'conv-1' is not a uuid" -and $eu.provider_failure.class -eq 'unknown') "$($em.bridge_outcome) | $($eu.bridge_outcome)"
}

# =============================================================== DENIAL: F11 and the denial retry (A2, A3)
if (Want 'DENIAL') {
    $r = New-Repo 'denial'
    $brief = Join-Path $r 'brief.md'
    [IO.File]::WriteAllText($brief, "# brief`n`nQ1. Is it fine?`n", $u8)
    $rlog = Join-Path $work 'denial-resume.txt'
    $x = Consult $r $rosterAgy @('-Brief', 'brief.md', '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'den') @{ FAKE_AGY_DENIED = '1'; FAKE_AGY_RESUME_REPLY = $adviseF; FAKE_AGY_RESUME_LOG = $rlog }
    $e = Last-Entry $r
    $dr = $e.denial_retry
    Check 'DENIAL' 'F11 (tool auto-denied, empty SUCCESS) -> ONE denial-retry turn on the same conversation -> usable reply ingested; ledger denial_retry {attempted, reason, succeeded, thread, wall_seconds, usage, events} right after format_retry' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply' -and $dr.attempted -eq $true -and $dr.succeeded -eq $true -and $dr.thread -eq $e.thread -and $dr.reason.StartsWith('jetski: no output produced') -and $dr.usage.input_tokens -eq 54000 -and (($dr.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'attempted,reason,succeeded,thread,wall_seconds,usage,events' -and ((($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match 'format_retry,denial_retry,base_commit') -and @($e.finding_ids).Count -eq 1) $e.bridge_outcome
    $rp = Text $rlog
    Check 'DENIAL' 'the retry turn: --conversation <id> + --json-schema; its prompt = the output contract, "Your previous turn produced no output: the tool run_command was auto-denied (headless print mode has no "command" permission). Do NOT call it again...", the field meanings, the consultation id - never the brief' ($rp -match "--conversation $($e.thread)" -and $rp -match '--json-schema' -and $rp.Contains('FINAL OUTPUT CONTRACT') -and $rp.Contains('Your previous turn produced no output: the tool run_command was auto-denied (headless print mode has no \"command\" permission). Do NOT call it again; answer from what you have read, as the JSON object.') -and $rp.Contains('- findings: one item per concrete defect') -and $rp.Contains("Consultation id: $($e.consult_id)") -and $rp -notmatch 'Read the brief') (($rp -split "`n")[0])
    $md = Text (Td $r $e.reply)
    Check 'DENIAL' 'warnings[] names the denial notice; the handoff has "Warnings:" and "Denial retry: succeeded" lines and names the retry''s event stream (handoffs/NN-agy-den.denial-retry.events.jsonl, kept)' (@($e.warnings).Count -ge 1 -and $e.warnings[0] -match '^denial notice \(the first turn produced nothing; the denial-retry turn answered\): jetski: no output produced' -and $md -match '(?m)^Warnings: denial notice' -and $md -match '(?m)^Denial retry: succeeded in ' -and $md -match 'further turns: `handoffs/\d\d-agy-den\.denial-retry\.events\.jsonl`' -and @(Get-ChildItem (Join-Path $r '.collab\t\handoffs') -Filter '*-agy-den.denial-retry.events.jsonl').Count -eq 1) (Line $md 'Denial retry')
    Check 'DENIAL' 'F09-2: denial_retry.events names that turn''s event stream (handoffs-relative, the file exists, differs from the main events), so the ledger alone finds the retry''s provenance' ($dr.events -match '^handoffs/\d\d-agy-den\.denial-retry\.events\.jsonl$' -and (Test-Path (Td $r $dr.events)) -and $dr.events -ne $e.events -and (Text (Td $r $dr.events)) -match '"event":"result"') "events=$($dr.events)"
    $y = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'off', '-DenialRetry', '0') @{ FAKE_AGY_DENIED = '1'; FAKE_AGY_RESUME_REPLY = $advise }
    $ey = Last-Entry $r
    Check 'DENIAL' '-DenialRetry 0 -> FAILED, provider_failure.class permission, message = the stderr line, denial_retry null, no retry turn' ($y.Code -eq 1 -and $ey.bridge_outcome.StartsWith('failed: jetski: no output produced') -and $ey.provider_failure.class -eq 'permission' -and $ey.provider_failure.message.StartsWith('jetski: no output produced') -and $null -eq $ey.denial_retry -and $ey.thread -match $uuidRe) $ey.bridge_outcome
    $z = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'again') @{ FAKE_AGY_DENIED = 'all'; FAKE_AGY_RESUME_REPLY = $advise }
    $ez = Last-Entry $r
    Check 'DENIAL' 'the retry turn is denied too -> failed (class permission), "(denial retry failed: ...)", denial_retry.succeeded false, its events still named' ($z.Code -eq 1 -and $ez.bridge_outcome -match '^failed: jetski: no output produced.*\(denial retry failed: jetski: no output produced' -and $ez.provider_failure.class -eq 'permission' -and $ez.denial_retry.succeeded -eq $false -and $ez.denial_retry.events -match '^handoffs/\d\d-agy-again\.denial-retry\.events\.jsonl$') $ez.bridge_outcome
    $w = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'warn') @{ FAKE_AGY_DENIED = '1'; FAKE_AGY_DENIED_REPLY = '1'; FAKE_AGY_REPLY = $advise; FAKE_AGY_STDERR = 'warning: --mode plan has no effect with --disable-slash-commands' }
    $ew = Last-Entry $r
    Check 'DENIAL' 'a denial notice WITH a usable reply -> ingested, warnings [denial notice, the warning: line], no retry' ($w.Code -eq 0 -and $ew.bridge_outcome -eq 'usable reply' -and @($ew.warnings).Count -eq 2 -and $ew.warnings[0] -match '^denial notice: jetski' -and $ew.warnings[1] -eq 'warning: --mode plan has no effect with --disable-slash-commands' -and $null -eq $ew.denial_retry -and $w.Out -match '(?m)^warning    : denial notice') (@($ew.warnings) -join ' | ')
}

# =============================================================== FAIL: the failure rules and classes (A2, A13, A19)
if (Want 'FAIL') {
    # (each case in a repository of its own: a recorded auth failure or a usage limit with a
    # reset time ahead makes the preflight refuse the next run on the agy endpoint - checked
    # at the end)
    $cases = @(
        @{ Name = 'status ERROR + UNAUTHENTICATED'; Env = @{ FAKE_AGY_STATUS = 'ERROR'; FAKE_AGY_ERROR = 'UNAUTHENTICATED: Request had invalid authentication credentials.' }; Outcome = '^failed: agy exit 1 - UNAUTHENTICATED'; Class = 'auth' },
        @{ Name = 'status ERROR + RESOURCE_EXHAUSTED retry in 32s'; Env = @{ FAKE_AGY_STATUS = 'ERROR'; FAKE_AGY_ERROR = 'RESOURCE_EXHAUSTED: You have exhausted your capacity on this model. Please retry in 32s.' }; Outcome = '^failed: agy exit 1 - RESOURCE_EXHAUSTED'; Class = 'quota'; Retry = 32 },
        @{ Name = 'status ERROR exit 0 + UNAVAILABLE'; Env = @{ FAKE_AGY_STATUS = 'ERROR'; FAKE_AGY_EXIT = '0'; FAKE_AGY_ERROR = 'UNAVAILABLE: The service is currently unavailable.' }; Outcome = '^failed: agy status ERROR - UNAVAILABLE'; Class = 'transport' },
        @{ Name = 'invalid model selection'; Env = @{ FAKE_AGY_STATUS = 'ERROR'; FAKE_AGY_ERROR = 'invalid model selection (x): --model gemini-3.8-flash-low conflicts with --effort=max' }; Outcome = '^failed: agy exit 1 - invalid model selection'; Class = 'capability' },
        @{ Name = 'exit 3 with a SUCCESS result'; Env = @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_EXIT = '3' }; Outcome = '^failed: agy exit 3'; Class = '' },
        @{ Name = 'no result event'; Env = @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_NORESULT = '1' }; Outcome = '^failed: no result event in the agy event stream'; Class = ''; Candidate = $true },
        @{ Name = 'two result events'; Env = @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_TWORESULTS = '1' }; Outcome = '^failed: malformed event stream: 2 result events \(exactly one expected\)$'; Class = 'transport' },
        @{ Name = 'a bad line inside the stream'; Env = @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_BADLINE = '1' }; Outcome = '^failed: malformed event stream: line \d+ is not a JSON object$'; Class = 'transport' },
        @{ Name = 'F10-2: a valid result + a trailing garbage line + exit 0 -> malformed, not ingested'; Env = @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_TRAILING = '{"event":"res' }; Outcome = '^failed: malformed event stream: line \d+ is not a JSON object$'; Class = 'transport' },
        @{ Name = 'partial output (print timeout)'; Env = @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_PARTIAL = '1' }; Outcome = '^failed: partial output - \[agy\] print timeout'; Class = 'transport' },
        @{ Name = 'empty reply'; Env = @{}; Outcome = '^failed: empty reply$'; Class = '' }
    )
    $k = 0
    $repos = @{}
    foreach ($c in $cases) {
        $k++
        $r = New-Repo "fail-$k"
        $repos[$c.Name] = $r
        $o = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', "f$k") $c.Env
        $e = Last-Entry $r
        $ok = ($o.Code -eq 1 -and $e.bridge_outcome -match $c.Outcome -and $null -ne $e.provider_failure -and @($e.finding_ids).Count -eq 0)
        if ($c.Class) { $ok = $ok -and $e.provider_failure.class -eq $c.Class }
        $ev = "$($e.bridge_outcome) [$($e.provider_failure.class)]"
        if ($c.Retry) {
            $ra = ConvertTo-WhenOffset $e.provider_failure.retry_after
            $wh = ConvertTo-WhenOffset $e.provider_failure.when
            $ok = $ok -and $null -ne $ra -and [Math]::Abs(($ra - $wh).TotalSeconds - $c.Retry) -le 1
            $ev += " retry_after=$($e.provider_failure.retry_after)"
        }
        if ($c.Candidate) { $ok = $ok -and $e.thread -eq '' -and $e.thread_candidate -match $uuidRe }
        Check 'FAIL' $c.Name $ok $ev
    }
    # F10-2: the same trailing line on a run the bridge KILLED (timeout) is a partial line: the
    # timeout outcome decides, the stream is not called malformed
    $rt = New-Repo 'fail-trailing-kill'
    $tk = Consult $rt $rosterAgy @('-Prompt', 'x', '-ReplyName', 'tk', '-TimeoutSec', '8') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_TRAILING = '{"event":"res'; FAKE_AGY_HANG_AFTER = '1' }
    $etk = Last-Entry $rt
    Check 'FAIL' 'F10-2: a valid result + the trailing line, then killed by the timeout -> "failed: timeout after 8 s (process tree killed)" (not malformed), class transport, the result id a candidate only' ($tk.Code -eq 1 -and $etk.bridge_outcome -eq 'failed: timeout after 8 s (process tree killed)' -and $etk.provider_failure.class -eq 'transport' -and $etk.thread -eq '' -and $etk.thread_candidate -match $uuidRe -and (Text (Td $rt $etk.events)).EndsWith('{"event":"res') -and @($etk.finding_ids).Count -eq 0) "$($etk.bridge_outcome) cand=$($etk.thread_candidate)"
    $rq = $repos['status ERROR + RESOURCE_EXHAUSTED retry in 32s']
    # (the clock frozen at the failure: its reset time, 32 s later, still lies ahead)
    # (pwsh reads the ISO text back as a DateTime: format it again)
    $h = Providers $rq $rosterAgy @('-Json') @{ CODEX_CONSULT_NOW = (Format-OffsetIso (ConvertTo-WhenOffset (Last-Entry $rq).provider_failure.when)) }
    $row = @($h.Json | Where-Object { $_.name -eq 'gemini' })[0]
    Check 'FAIL' 'endpoint health by fingerprint: the listing shows the quota failure of the agy endpoint with its reset time, and the verdict "unavailable (usage limit until <iso>)" while it lies ahead' ($h.Code -eq 0 -and $row.last_failure.class -eq 'quota' -and $row.last_limit.retry_after -and $row.verdict -match '^unavailable \(usage limit until ') "$($row.verdict) / $($row.last_limit.retry_after)"
    $ra = $repos['status ERROR + UNAUTHENTICATED']
    $again = Consult $ra $rosterAgy @('-Prompt', 'x', '-ReplyName', 'again') @{ FAKE_AGY_REPLY = $advise }
    $solo = Consult $ra '' @('-Engine', 'agy', '-Model', $model, '-Prompt', 'x', '-ReplyName', 'solo') @{ FAKE_AGY_REPLY = $advise }
    Check 'FAIL' 'the recorded auth failure refuses the next agy run (preflight, fail-closed): the roster walk has no available entry; a solo run is refused with the auth message; no new ledger entry' ($again.Code -eq 1 -and $again.First -match "^codex-consult: no reviewer of the roster .* is available; nothing was started: #1 gemini :: gemini-3\.8-flash-high \[agy\] \(auth failed " -and $solo.Code -eq 1 -and $solo.First -match '^codex-consult: provider gemini is not usable: the last run on this endpoint was rejected as unauthenticated' -and @(Ledger $ra).Count -eq 1) "$($again.First) | $($solo.First)"
}

# =============================================================== PROSE: the prose gate and the repair through --conversation (step 9, A12)
if (Want 'PROSE') {
    $r = New-Repo 'prose'
    $rlog = Join-Path $work 'prose-resume.txt'
    $x = Consult $r $rosterAgy @('-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'pr') @{ FAKE_AGY_REPLY = $proseFile; FAKE_AGY_NOSTRUCTURED = '1'; FAKE_AGY_RESUME_REPLY = $repairedFile; FAKE_AGY_RESUME_LOG = $rlog }
    $e = Last-Entry $r
    $fr = $e.format_retry
    Check 'PROSE' 'a response text only (no structured_output) -> prose gate -> ONE repair turn -> structured, format_retry.succeeded, thread = repair thread, drift 0' ($x.Code -eq 0 -and $e.structured -eq $true -and $fr.attempted -eq $true -and $fr.succeeded -eq $true -and $fr.thread -eq $e.thread -and @($fr.drift).Count -eq 0 -and $e.verdict -eq 'ADVISE') "$($e.validation_error) / drift=$(@($fr.drift) -join '; ')"
    $rp = Text $rlog
    Check 'PROSE' 'the repair turn: --conversation <thread> --json-schema <schema>, the repair prompt (convert, do not re-answer), the consultation id, never the brief' ($rp -match "--json-schema \S+ --print-timeout 0 --sandbox --disable-slash-commands --conversation $($e.thread)" -and $rp.Contains('Your last message was prose, not the required JSON.') -and $rp.Contains("Consultation id: $($e.consult_id)")) (($rp -split "`n")[0])
    $orig = Td $r $fr.original
    Check 'PROSE' 'the original prose kept as NN-agy-pr.original.md (the response text), .reply.json = the repaired object, the repair''s event stream in handoffs' ($fr.original -match '^handoffs/\d\d-agy-pr\.original\.md$' -and (Text $orig) -eq $prose -and (ConvertFrom-Json (Text (Td $r $e.reply_json))).verdict_reason -eq 'the rules hold' -and @(Get-ChildItem (Join-Path $r '.collab\t\handoffs') -Filter '*-agy-pr.repair.events.jsonl').Count -eq 1) $fr.original
    Check 'PROSE' 'F09-2: format_retry.events names the repair turn''s event stream (handoffs/NN-agy-pr.repair.events.jsonl, exists); fields attempted,reason,succeeded,thread,wall_seconds,usage,drift,original,events' ($fr.events -match '^handoffs/\d\d-agy-pr\.repair\.events\.jsonl$' -and (Test-Path (Td $r $fr.events)) -and (($fr.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'attempted,reason,succeeded,thread,wall_seconds,usage,drift,original,events') "events=$($fr.events)"
    $y = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'lost') @{ FAKE_AGY_REPLY = $proseFile; FAKE_AGY_NOSTRUCTURED = '1'; FAKE_AGY_RESUME_REPLY = $repairedFile; FAKE_AGY_CONVERSATION = 'notfound' }
    $ey = Last-Entry $r
    Check 'PROSE' 'A12: the repair lands in a NEW conversation (not-found warning) -> FAILED repair: nothing from it ingested, the prose stays the reply of record' ($y.Code -eq 0 -and $ey.structured -eq $false -and $ey.format_retry.succeeded -eq $false -and $ey.validation_error -match 'format repair failed: parent conversation [0-9a-f-]{36} not found, agy started' -and @($ey.finding_ids).Count -eq 0) $ey.validation_error
    $z = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'norep', '-FormatRetry', '0') @{ FAKE_AGY_REPLY = $proseFile; FAKE_AGY_NOSTRUCTURED = '1' }
    $ez = Last-Entry $r
    Check 'PROSE' '-FormatRetry 0 -> no repair turn: prose kept, structured false, format_retry null' ($z.Code -eq 0 -and $ez.structured -eq $false -and $null -eq $ez.format_retry -and $ez.validation_error -match '^not valid JSON') $ez.validation_error
}

# =============================================================== TREE: read-only is enforced by the tree check (A17)
if (Want 'TREE') {
    $r = New-Repo 'tree'
    $x = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'w') @{ FAKE_AGY_REPLY = $adviseF; FAKE_AGY_WRITE = 'probe.txt' }
    $e = Last-Entry $r
    Check 'TREE' 'the reviewer writes probe.txt -> FAILED "the working tree changed during the run (by the reviewer or anyone else): 1 file: probe.txt - agy''s sandbox does not block writes" (F09-3 wording), class permission; the reply kept (.reply.json), nothing ingested' ($x.Code -eq 1 -and $e.bridge_outcome -eq "failed: the working tree changed during the run (by the reviewer or anyone else): 1 file: probe.txt - agy's sandbox does not block writes" -and $e.provider_failure.class -eq 'permission' -and $e.tree_changed_during_review -eq $true -and $e.reply_json -and (Test-Path (Td $r $e.reply_json)) -and @($e.finding_ids).Count -eq 0 -and -not (Test-Path (Join-Path $r '.collab\t\findings.json'))) $e.bridge_outcome
    Remove-Item (Join-Path $r 'probe.txt')
    $y = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'h') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_WRITE = '.collab\t\handoffs\99-agy-note.md' }
    $ey = Last-Entry $r
    Check 'TREE' 'a write into the task''s handoffs (outside the tree fingerprint) -> failed "the collab directory changed during the run (by the reviewer or anyone else): 1 file: .collab/t/handoffs/99-agy-note.md"' ($y.Code -eq 1 -and $ey.bridge_outcome -eq "failed: the collab directory changed during the run (by the reviewer or anyone else): 1 file: .collab/t/handoffs/99-agy-note.md - agy's sandbox does not block writes" -and $ey.provider_failure.class -eq 'permission') $ey.bridge_outcome
    Remove-Item (Join-Path $r '.collab\t\handoffs\99-agy-note.md')
    # F09-1 / F10-1: the WHOLE collab root - another task's directory, this task's stores
    $o1 = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'other') @{ FAKE_AGY_REPLY = $adviseF; FAKE_AGY_WRITE = '.collab\other-task\x.md' }
    $eo1 = Last-Entry $r
    Remove-Item (Join-Path $r '.collab\other-task') -Recurse -Force
    $o2 = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'store') @{ FAKE_AGY_REPLY = $adviseF; FAKE_AGY_WRITE = '.collab\t\state.md' }
    $eo2 = Last-Entry $r
    Remove-Item (Join-Path $r '.collab\t\state.md')
    Check 'TREE' 'F09-1/F10-1: a write to ANOTHER task (.collab/other-task/x.md) or to this task''s store (.collab/t/state.md) -> failed "the collab directory changed during the run (by the reviewer or anyone else): 1 file: <path>", class permission, nothing ingested' ($o1.Code -eq 1 -and $eo1.bridge_outcome -eq "failed: the collab directory changed during the run (by the reviewer or anyone else): 1 file: .collab/other-task/x.md - agy's sandbox does not block writes" -and $eo1.provider_failure.class -eq 'permission' -and @($eo1.finding_ids).Count -eq 0 -and $o2.Code -eq 1 -and $eo2.bridge_outcome -eq "failed: the collab directory changed during the run (by the reviewer or anyone else): 1 file: .collab/t/state.md - agy's sandbox does not block writes" -and @($eo2.finding_ids).Count -eq 0 -and -not (Test-Path (Join-Path $r '.collab\t\findings.json'))) "$($eo1.bridge_outcome) | $($eo2.bridge_outcome)"
    $z = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'rw') @{ FAKE_AGY_REPLY = $proseFile; FAKE_AGY_NOSTRUCTURED = '1'; FAKE_AGY_RESUME_REPLY = $repairedFile; FAKE_AGY_WRITE = 'late.txt|all' }
    $ez = Last-Entry $r
    Check 'TREE' 'a write during the main turn fails the run before any repair turn (none attempted)' ($z.Code -eq 1 -and $ez.bridge_outcome -match '^failed: the working tree changed during the run \(by the reviewer or anyone else\): 1 file: late\.txt' -and $null -eq $ez.format_retry) $ez.bridge_outcome
    Remove-Item (Join-Path $r 'late.txt')
    # the documented blind spot: a gitignored path is not monitored (README "Engines", F12)
    [IO.File]::WriteAllText((Join-Path $r '.gitignore'), "ignored/`n", $u8)
    $null = G $r @('add', '.gitignore'); $null = G $r @('commit', '-q', '-m', 'ignore')
    $ig = Consult $r $rosterAgy @('-Prompt', 'x', '-ReplyName', 'ign') @{ FAKE_AGY_REPLY = $adviseF; FAKE_AGY_WRITE = 'ignored\out.txt' }
    $eig = Last-Entry $r
    $readme = [IO.File]::ReadAllText((Join-Path $repoRoot 'README.md'), $u8) -replace '\s+', ' '
    Check 'TREE' 'documented blind spot: a write to a gitignored path leaves the run usable (tree unchanged, the finding ingested), and the README states the limit: "enforced by evidence for tracked and untracked files and the collab directory; not for gitignored paths, submodules or files outside the repository"' ($ig.Code -eq 0 -and $eig.bridge_outcome -eq 'usable reply' -and $eig.tree_changed_during_review -eq $false -and (Test-Path (Join-Path $r 'ignored\out.txt')) -and @($eig.finding_ids).Count -eq 1 -and $readme.Contains('enforced by evidence for tracked and untracked files and the collab directory; not for gitignored paths, submodules or files outside the repository')) $eig.bridge_outcome
    $c = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'cx') @{ FAKE_CODEX_REPLY = $advise }
    Check 'TREE' 'codex runs are unchanged: a clean codex run next to them is usable (no tree-check failure path for codex)' ($c.Code -eq 0 -and (Last-Entry $r).bridge_outcome -eq 'usable reply' -and (Last-Entry $r).reviewer.engine -eq 'codex') (Last-Entry $r).bridge_outcome
}

# =============================================================== TIMEOUT + RECOVERY: the kill, the recovery record naming the event stream (A18)
if (Want 'TIMEOUT') {
    $r = New-Repo 'timeout'
    $pidFile = Join-Path $work 'timeout-fake.pid'
    $pend = Join-Path $r '.collab\t\.consult.pending.json'
    Set-CaseEnv $rosterAgy @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_HANG = '1'; FAKE_AGY_PIDFILE = $pidFile }
    $bg = Start-Process -FilePath $psExe -WorkingDirectory $r -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-Prompt', 'x', '-ReplyName', 'hang', '-TimeoutSec', '6')
    Restore-Env
    $mid = $null
    for ($i = 0; $i -lt 80; $i++) { $pr = Read-PendingFile -Path $pend; if ($pr.Record -and $pr.Record.state -eq 'running' -and (Test-Path $pidFile)) { $mid = $pr.Record; break }; Start-Sleep -Milliseconds 250 }
    $bg.WaitForExit()
    $e = Last-Entry $r
    $fakePid = if (Test-Path $pidFile) { [int](Get-Content $pidFile) } else { 0 }
    Check 'RECOVER' 'while it runs the recovery record carries engine agy, the launcher, and events = the run''s event stream (repo-relative)' ($mid -and $mid.engine -eq 'agy' -and $mid.launcher -eq $fakeAgy -and $mid.events -match '^\.collab/t/handoffs/\d\d-agy-hang\.events\.jsonl$') "events=$($mid.events) engine=$($mid.engine)"
    Check 'TIMEOUT' 'hang -> "failed: timeout after 6 s (process tree killed)", the fake gone, no survivors, no pending record left, the init id a candidate only' ($e.bridge_outcome -eq 'failed: timeout after 6 s (process tree killed)' -and $fakePid -gt 0 -and -not (Get-Process -Id $fakePid -ErrorAction SilentlyContinue) -and -not (Test-Path $pend) -and $e.thread -eq '' -and $e.thread_candidate -match $uuidRe -and $e.provider_failure.class -eq 'transport') "$($e.bridge_outcome) cand=$($e.thread_candidate)"
    # a record left by a run that died (dead pids) names its event stream everywhere
    $dead = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'exit' -PassThru -WindowStyle Hidden
    $dead.WaitForExit()
    $ro = New-Repo 'recover'
    $evRel = '.collab/t/handoffs/02-agy-x.events.jsonl'
    $rec = [pscustomobject]@{ state = 'running'; n = 1; nn = '02'; reply = 'handoffs/02-agy-x.md'; events = $evRel; consult_id = (Uuid); started = (Get-IsoTimestamp); pid = $dead.Id; host = [Environment]::MachineName; launcher = $fakeAgy; engine = 'agy'; child_pid = $dead.Id; child_start_time = ''; survivors = [object[]]@(); note = '' }
    Write-JsonFile -Path (Join-Path $ro '.collab\t\.consult.pending.json') -Object $rec
    $note = "the raw event stream of that run is at $evRel (it may hold a usable reply); no ledger entry was written"
    $li = Run-Tool $findingsPs $ro @('-Task', 't', '-List')
    $dd = Consult $ro $rosterAgy @('-DryRun', '-Prompt', 'x')
    $nx = Consult $ro $rosterAgy @('-Prompt', 'x', '-ReplyName', 'next') @{ FAKE_AGY_REPLY = $advise }
    Check 'RECOVER' 'A18: -List, the dry run''s pending line and the next run''s recovery line all say "the raw event stream of that run is at <path> (it may hold a usable reply); no ledger entry was written"' ($li.Out -match ('(?m)^pending: state=running, n=1, nn=02, .*; ' + [regex]::Escape($note) + '$') -and (Line $dd.Out 'pending     :').Contains($note) -and $nx.Code -eq 0 -and $nx.Out -match ('(?m)^codex-consult: recovered reservation n=1, nn=02 .*' + [regex]::Escape($note))) (Line $li.Out 'pending')
}

# =============================================================== PANEL: a mixed panel (codex + agy)
if (Want 'PANEL') {
    $roster = Write-Roster 'panel' ('{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"gemini","engine":"agy","model":"' + $model + '"}]}')
    $r = New-Repo 'panel'
    $p = Consult $r $roster @('-Panel', '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'x') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_AGY_REPLY = $adviseF }
    $led = @(Ledger $r)
    $e1 = $led[0]; $e2 = $led[1]
    Check 'PANEL' 'both members run, one after another: openai through codex, gemini through agy; handoffs NN-codex-x-openai.md and NN-agy-x-gemini.md; one panel id; exit 0' ($p.Code -eq 0 -and $led.Count -eq 2 -and $e1.reviewer.engine -eq 'codex' -and $e2.reviewer.engine -eq 'agy' -and $e1.reply -match '^handoffs/\d\d-codex-x-openai\.md$' -and $e2.reply -match '^handoffs/\d\d-agy-x-gemini\.md$' -and $e2.command.StartsWith('agy ') -and [string]$e1.panel.id -eq [string]$e2.panel.id -and $e2.panel.position -eq 2 -and $e2.bridge_outcome -eq 'usable reply') "$($e1.reply) / $($e2.reply)"
    $short = ([string]$e1.panel.id).Substring(0, 8)
    $sumAt = $p.Out.LastIndexOf("Panel ${short}: 2 of 2 entries ran")
    $sl = if ($sumAt -ge 0) { @($p.Out.Substring($sumAt) -split "`n") } else { @('') }
    Check 'PANEL' 'summary: one line per member, the agy one shown with [agy]' ($sumAt -ge 0 -and $sl[1] -match '^  openai :: gpt-5\.1\s+ADVISE\s+0 blocker, 0 major, 1 minor' -and $sl[2] -match '^  gemini :: gemini-3\.8-flash-high \[agy\]\s+ADVISE\s+0 blocker, 0 major, 1 minor\s+prior: none\s+[0-9.]+ s  handoffs/\d\d-agy-x-gemini\.md$' -and $p.Out -match '=== panel [0-9a-f]{8} member 2 of 2: gemini :: gemini-3\.8-flash-high \[agy\] \(roster #2\) ===') (($sl | Select-Object -First 3) -join ' | ')
    $rf = New-Repo 'panel-fail'
    $pf = Consult $rf $roster @('-Panel', '-Prompt', 'x', '-ReplyName', 'f') @{ FAKE_CODEX_REPLY = $advise; FAKE_AGY_STATUS = 'ERROR'; FAKE_AGY_ERROR = 'UNAVAILABLE: try later' }
    $lf = @(Ledger $rf)
    Check 'PANEL' 'the agy member fails -> the codex member is still usable, the agy one recorded as failed, exit 1' ($pf.Code -eq 1 -and $lf.Count -eq 2 -and $lf[0].bridge_outcome -eq 'usable reply' -and $lf[1].bridge_outcome -match '^failed: agy exit 1 - UNAVAILABLE' -and $lf[1].provider_failure.class -eq 'transport') $lf[1].bridge_outcome
    $pe = Consult $r $roster @('-Panel', '-DryRun', '-Prompt', 'x', '-Engine', 'agy')
    Check 'PANEL' '-Panel -Engine agy -> only the agy entries' ($pe.Code -eq 0 -and $pe.First -match ': 1 of 1 roster entries would run' -and $pe.Out -match 'agy-x-gemini|agy-reply-gemini') $pe.First
}

# =============================================================== LISTING: codex-providers.ps1 and the SessionStart hook (A4)
if (Want 'LISTING') {
    $r = New-Repo 'listing'
    $roster = Write-Roster 'listing' ('{"roster_version":1,"reviewers":[{"provider":"gemini","engine":"agy","model":"' + $model + '"},{"provider":"gemini","engine":"agy","model":"gemini-3.1-pro-high","panel":"weighty"},{"provider":"openai","model":"gpt-5.1"}]}')
    $mlog = Join-Path $work 'models-1.log'
    $j = Providers $r $roster @('-Json') @{ FAKE_AGY_MODELS_LOG = $mlog }
    $gem = @($j.Json | Where-Object { $_.name -eq 'gemini' })
    $oai = @($j.Json | Where-Object { $_.name -eq 'openai' })[0]
    $g = $gem[0]
    Check 'LISTING' 'JSON: one engine row for the label gemini (two roster entries): engine agy, kind "engine agy", endpoint "agy (<launcher>)", table n/a, credentials "ok: signed in (3 models)", effort "agy (tier in the model id)", transport native, roster_position 1, roster_selected, available; codex rows engine codex' ($j.Code -eq 0 -and $gem.Count -eq 1 -and $g.engine -eq 'agy' -and $g.kind -eq 'engine agy' -and $g.endpoint -eq "agy ($fakeAgy)" -and $g.table -eq 'n/a' -and $g.credentials -eq 'ok: signed in (3 models)' -and $g.effort_vocabulary -eq 'agy (tier in the model id)' -and $g.schema_transport -eq 'native' -and $g.roster_position -eq 1 -and $g.roster_selected -eq $true -and $g.verdict -eq 'available' -and $oai.engine -eq 'codex' -and $oai.roster_position -eq 3) ($g | ConvertTo-Json -Compress -Depth 3)
    Check 'LISTING' 'one `agy models` call per listing (the walk and the row share it)' (@(Get-Content $mlog).Count -eq 1) "calls=$(@(Get-Content $mlog).Count)"
    $mlog2 = Join-Path $work 'models-2.log'
    $nn = Providers $r $roster @('-Json', '-NoNetwork') @{ FAKE_AGY_MODELS_LOG = $mlog2 }
    $g2 = @($nn.Json | Where-Object { $_.name -eq 'gemini' })[0]
    Check 'LISTING' '-NoNetwork: no `agy models` at all; credentials "not checked (launcher present; run codex-providers.ps1)", verdict "unknown (sign-in not checked)"; the walk skips the agy entries and selects openai' ($nn.Code -eq 0 -and -not (Test-Path $mlog2) -and $g2.credentials -eq 'not checked (launcher present; run codex-providers.ps1)' -and $g2.verdict -eq 'unknown (sign-in not checked)' -and $g2.roster_selected -eq $false -and (@($nn.Json | Where-Object { $_.name -eq 'openai' })[0]).roster_selected -eq $true) ($g2 | ConvertTo-Json -Compress -Depth 3)
    $out = Providers $r $roster @('-Json') @{ FAKE_AGY_MODELS = 'out' }
    $g3 = @($out.Json | Where-Object { $_.name -eq 'gemini' })[0]
    $noPath = (@($savedPath -split ';' | Where-Object { $_ -and -not (Test-Path (Join-Path $_ 'agy.exe')) -and -not (Test-Path (Join-Path $_ 'agy.cmd')) -and -not (Test-Path (Join-Path $_ 'agy')) }) -join ';')
    $miss = Providers $r $roster @('-Json') @{ CODEX_CONSULT_AGY_EXE = ''; Path = $noPath }
    $g4 = @($miss.Json | Where-Object { $_.name -eq 'gemini' })[0]
    Check 'LISTING' 'not signed in -> "unavailable (`agy models`: Error: you are not signed in...)"; no launcher -> "unavailable (agy CLI not found on PATH)", endpoint "agy (launcher not found)"' ($g3.verdict -match '^unavailable \(`agy models`: Error: you are not signed in' -and $g4.verdict -eq 'unavailable (agy CLI not found on PATH)' -and $g4.endpoint -eq 'agy (launcher not found)') "$($g3.verdict) | $($g4.verdict)"
    $tbl = Providers $r $roster @()
    Check 'LISTING' 'the table: the gemini row with kind "engine agy" and ROSTER 1,2; the roster line selects gemini :: ... [agy]' ($tbl.Code -eq 0 -and $tbl.Out -match '(?m)^available\s+gemini\s+1,2\s+engine agy\s+agy \(' -and $tbl.Out -match "(?m)^roster: .* -> would select gemini :: gemini-3\.8-flash-high \[agy\]$") (Line $tbl.Out 'roster:')
    # (45 s in real use - F13; the test hook CODEX_CONSULT_TEST_LOGIN_TIMEOUT shortens it)
    $hang = Providers $r $roster @('-Json', '-Provider', 'gemini') @{ FAKE_AGY_MODELS = 'hang'; CODEX_CONSULT_TEST_LOGIN_TIMEOUT = '3' }
    $g5 = @($hang.Json)[0]
    Check 'LISTING' '`agy models` hanging -> unknown after the timeout ("did not finish within 3 s" with the test hook), -Provider gemini exit 3' ($hang.Code -eq 3 -and $g5.verdict -eq 'unknown (`agy models` did not finish within 3 s)') $g5.verdict
    # the hook: -NoNetwork, a codex on PATH (a shim of the fake)
    $bin = Join-Path $work 'bin'
    [void][IO.Directory]::CreateDirectory($bin)
    [IO.File]::WriteAllText((Join-Path $bin 'codex.cmd'), "@echo off`r`nset ""FAKE_CODEX_ARGS=%*""`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""$(Join-Path $sp 'fake-codex3.ps1')""`r`nexit /b %ERRORLEVEL%`r`n")
    $mlog3 = Join-Path $work 'models-3.log'
    Set-CaseEnv $roster @{ FAKE_AGY_MODELS_LOG = $mlog3; Path = "$bin;$savedPath" }
    Push-Location $r
    $pe = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $hookOut = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $hookPs 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $ErrorActionPreference = $pe
    Pop-Location
    Restore-Env
    Check 'LISTING' 'SessionStart hook: no `agy models` call; "gemini not checked (launcher present)"; the roster walk skips it (-> openai)' (-not (Test-Path $mlog3) -and $hookOut -match '^codex-consult: reviewers - openai available \| gemini not checked \(launcher present\); roster -> would select openai$') $hookOut
}

# =============================================================== SIGNIN: the sign-in check's timing (F13, wave 18)
if (Want 'SIGNIN') {
    # an agy ledger entry of this repository, recorded $Minutes ago (the consult clock is the system clock here)
    function New-AgedAgyEntry {
        param([int]$N, [int]$Minutes, [string]$Outcome = 'usable reply', [string]$Class = '', [string]$RetryAfter = '')
        $en = New-AgyEntry $N $(if ($Outcome -eq 'usable reply') { Uuid } else { '' })
        $en.when = Get-IsoTimestamp ((Get-Date).AddMinutes(-$Minutes))
        $en.bridge_outcome = $Outcome
        if ($Class) { $en | Add-Member -NotePropertyName 'provider_failure' -NotePropertyValue ([pscustomobject]@{ class = $Class; code = ''; message = ($Outcome -replace '^failed:\s*', ''); when = $en.when; retry_after = $(if ($RetryAfter) { $RetryAfter } else { $null }) }) }
        return $en
    }
    $r = New-Repo 'signin'
    Seed-Task $r @((New-AgedAgyEntry 1 5))
    $ml = Join-Path $work 'signin-models-1.log'
    $d = Consult $r '' @('-DryRun', '-Engine', 'agy', '-Model', $model, '-Prompt', 'x') @{ FAKE_AGY_MODELS_LOG = $ml }
    $pj = Providers $r $rosterAgy @('-Json') @{ FAKE_AGY_MODELS_LOG = $ml }
    $pn = Providers $r $rosterAgy @('-Json', '-NoNetwork') @{ FAKE_AGY_MODELS_LOG = $ml }
    $gj = @($pj.Json | Where-Object { $_.name -eq 'gemini' })[0]
    $gn = @($pn.Json | Where-Object { $_.name -eq 'gemini' })[0]
    $calls = if (Test-Path $ml) { @(Get-Content $ml).Count } else { 0 }
    Check 'SIGNIN' 'F13: a usable agy reply 5 min ago in this repository''s ledgers -> NO `agy models` call: the preflight reads "ok: signed in (usable reply 5 min ago)", the listing shows the same text (with -NoNetwork too, verdict available)' ($d.Code -eq 0 -and $d.Out -match '(?m)^preflight   : available \(ok: signed in \(usable reply 5 min ago\)\)$' -and $d.Preview.preflight -eq 'ok: signed in (usable reply 5 min ago)' -and $gj.credentials -eq 'ok: signed in (usable reply 5 min ago)' -and $gj.verdict -eq 'available' -and $gn.credentials -eq 'ok: signed in (usable reply 5 min ago)' -and $gn.verdict -eq 'available' -and $calls -eq 0) "$(Line $d.Out 'preflight') | $($gj.credentials) | $($gn.verdict) | calls=$calls"
    $run = Consult $r '' @('-Engine', 'agy', '-Model', $model, '-Prompt', 'x', '-ReplyName', 'sig') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_MODELS_LOG = $ml }
    $er = Last-Entry $r
    Check 'SIGNIN' 'a real run on that evidence: no `agy models` call, usable reply, ledger preflight "ok: signed in (usable reply 5 min ago)"' ($run.Code -eq 0 -and $er.bridge_outcome -eq 'usable reply' -and $er.preflight -eq 'ok: signed in (usable reply 5 min ago)' -and -not (Test-Path $ml)) $er.preflight
    $r2 = New-Repo 'signin-old'
    Seed-Task $r2 @((New-AgedAgyEntry 1 61))
    $ml2 = Join-Path $work 'signin-models-2.log'
    $d2 = Consult $r2 '' @('-DryRun', '-Engine', 'agy', '-Model', $model, '-Prompt', 'x') @{ FAKE_AGY_MODELS_LOG = $ml2 }
    $calls2 = if (Test-Path $ml2) { @(Get-Content $ml2).Count } else { 0 }
    Check 'SIGNIN' 'a usable reply 61 min ago is too old -> the `agy models` call happens (one): "ok: signed in (3 models)"' ($d2.Code -eq 0 -and $d2.Preview.preflight -eq 'ok: signed in (3 models)' -and $calls2 -eq 1) "$($d2.Preview.preflight) calls=$calls2"
    $r3 = New-Repo 'signin-auth'
    Seed-Task $r3 @((New-AgedAgyEntry 1 5), (New-AgedAgyEntry 2 2 'failed: agy exit 1 - UNAUTHENTICATED: Request had invalid authentication credentials.' 'auth'))
    $r4 = New-Repo 'signin-quota'
    Seed-Task $r4 @((New-AgedAgyEntry 1 5), (New-AgedAgyEntry 2 2 'failed: agy exit 1 - RESOURCE_EXHAUSTED: quota exceeded' 'quota' (Format-OffsetIso ([DateTimeOffset]::Now.AddMinutes(60)))))
    $ml3 = Join-Path $work 'signin-models-3.log'
    $a3 = Consult $r3 '' @('-Engine', 'agy', '-Model', $model, '-Prompt', 'x', '-ReplyName', 'a3') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_MODELS_LOG = $ml3 }
    $a4 = Consult $r4 '' @('-Engine', 'agy', '-Model', $model, '-Prompt', 'x', '-ReplyName', 'a4') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_MODELS_LOG = $ml3 }
    Check 'SIGNIN' 'the endpoint health stays in front of the short-circuit: a usable reply 5 min ago, then an auth failure (or a usage limit with its reset ahead) 2 min ago -> refused, no `agy models` call, no new ledger entry' ($a3.Code -eq 1 -and $a3.First -match '^codex-consult: provider gemini is not usable: the last run on this endpoint was rejected as unauthenticated' -and $a4.Code -eq 1 -and $a4.First -match '^codex-consult: provider gemini is not usable: its usage limit \(hit at .*\) lasts until ' -and -not (Test-Path $ml3) -and @(Ledger $r3).Count -eq 2 -and @(Ledger $r4).Count -eq 2) "$($a3.First) | $($a4.First)"
    $r5 = New-Repo 'signin-hang'
    $h5 = Consult $r5 '' @('-Engine', 'agy', '-Model', $model, '-Prompt', 'x', '-ReplyName', 'h5') @{ FAKE_AGY_REPLY = $advise; FAKE_AGY_MODELS = 'hang'; CODEX_CONSULT_TEST_LOGIN_TIMEOUT = '3' }
    Check 'SIGNIN' 'F13: `agy models` hanging -> unknown after the timeout (45 s by default - $script:AgyModelsTimeoutSec; 3 s through CODEX_CONSULT_TEST_LOGIN_TIMEOUT) -> the run is refused, nothing started' ($h5.Code -eq 1 -and $h5.First -eq 'codex-consult: provider gemini: availability could not be established (`agy models` did not finish within 3 s); pass -SkipPreflight to launch anyway, or fix the check' -and @(Ledger $r5).Count -eq 0 -and $script:AgyModelsTimeoutSec -eq 45) "$($h5.First) default=$($script:AgyModelsTimeoutSec)"
}

# =============================================================== SCOREBOARD: [agy] in the scoreboards
if (Want 'SCOREBOARD') {
    $r = New-Repo 'score'
    $a = Consult $r '' @('-Engine', 'agy', '-Model', $model, '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'a') @{ FAKE_AGY_REPLY = $adviseF }
    $c = Consult $r '' @('-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'c') @{ FAKE_CODEX_REPLY = $advise }
    $sj = Run-Tool $scoreboardPs $r @('-Json')
    $rows = @()
    try { $rows = @(($sj.Out | ConvertFrom-Json) | ForEach-Object { $_ }) } catch { }
    $agyRow = @($rows | Where-Object { $_.lineage -eq "gemini :: $model [agy]" -and $_.purpose -eq 'framing' })
    $cdxRow = @($rows | Where-Object { $_.lineage -eq 'openai :: gpt-5.1' -and $_.purpose -eq 'framing' })
    Check 'SCOREBOARD' 'codex-scoreboard: the agy lineage is shown as "gemini :: <model> [agy]" (1 consult, 1 raised); the codex lineage unchanged' ($a.Code -eq 0 -and $c.Code -eq 0 -and $agyRow.Count -eq 1 -and $agyRow[0].consults -eq 1 -and $agyRow[0].raised -eq 1 -and $cdxRow.Count -eq 1) (@($rows | ForEach-Object { "$($_.lineage)|$($_.purpose)" }) -join ' ; ')
    $st = Run-Tool $findingsPs $r @('-Task', 't', '-Stats')
    $ra = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '1', '-Useful', 'yes')
    $fs = [IO.File]::ReadAllText((Join-Path $r '.collab\t\findings.json'), $u8) | ConvertFrom-Json
    Check 'SCOREBOARD' 'codex-findings -Stats board line "gemini :: <model> [agy]"; -Rate records lineage "... [agy]" (same rating fields)' ($st.Code -eq 0 -and $st.Out -match '(?m)^gemini :: gemini-3\.8-flash-high \[agy\]\s+1\s+' -and $ra.Code -eq 0 -and $ra.First -eq "codex-findings: consult n=1 (gemini :: $model [agy], framing) rated yes." -and $fs.ratings[0].lineage -eq "gemini :: $model [agy]" -and (($fs.ratings[0].PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'n,consult_id,lineage,provider,model,purpose,useful,note,when') $ra.First
}

} finally {
    Restore-Env
    $env:Path = $savedPath
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-engines ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
