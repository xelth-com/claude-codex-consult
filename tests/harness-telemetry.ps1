# codex-consult wave 28 (0.5.0; ROADMAP R17 - telemetry and complaints to the maintainer's intake, ON
# by default): the switch (CODEX_CONSULT_TELEMETRY, -Telemetry), the intake URL rule (https; plain
# http only for a loopback test intake), the salted instance id, the outcome classes and THE event
# allowlist walked key by key (a synthetic hostile entry and the real events of real runs - never a
# task name, a brief, a prompt, a path, a thread id, a finding text, the machine or the user name);
# the spool line after a usable and a failed run, -Telemetry off and CODEX_CONSULT_TELEMETRY=off
# writing nothing, a panel's members; the notice once per version, the dry run's line; the detached
# sender delivering and deleting - without the coordinator's host markers; a 429 with Retry-After
# respected (and one of more than 60 s not waited for), non-JSON answers leaving the spool intact,
# the 7-day drop, the sender lock, batches of 100; -Complain (the printed payload, -Yes, the
# public_ref, the confirmation, the complaint line and its later delivery, the 8 KiB limit);
# codex-telemetry.ps1 -Status; the SessionStart hook's `telemetry: on|off`; the documentation.
# (wave 28b, D1-D9, D16) the vendor table (provider = the vendor class of the endpoint, the model only
# in its vendor's pattern; a company-like label and model -> other/other, in a unit and a real run);
# the sender's deadline (one request 2 s by hook against a slow intake, the whole flush), its lock
# (a live owner refuses, an old lock and a dead owner's are taken over); the allow-listed sender
# environment; plain http only in test mode; the salt created atomically (four racing processes);
# a busy spool (5 s, the warning, -Status); the complaint's exact bytes; the intake's 400/413/403/
# other 4xx; -Forget -PublicRef / -Local; the spool file named by the local date.
# FAKES ONLY: fake-codex3.cmd; the intake is a LOCAL System.Net.HttpListener on 127.0.0.1 (a free
# port) or a closed loopback port - CODEX_CONSULT_TELEMETRY_URL always names one of them, never the
# real intake; CODEX_HOME is a scratch directory per case, CODEX_CONSULT_ROSTER a scratch file or
# 'none', CODEX_CONSULT_HEALTH 'none'; the host markers of the process that runs the harness are
# removed first; the API key variables hold dummy values. Runs under the host it is started with
# (powershell 5.1 or pwsh 7, Windows). Work files: $env:TEMP\codex-consult-tests\harness-telemetry\
# <guid>, removed at the end.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
$env:CODEX_CONSULT_HEALTH = 'none'
# the switch is set per case; the intake is ALWAYS local (a closed loopback port until a case names
# its listener)
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
$telemetryPs = Join-Path $scripts 'codex-telemetry.ps1'
$hookPs = Join-Path $scripts 'codex-consult-hook.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-telemetry') ([guid]::NewGuid().ToString('N'))
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
# the operator's real codex home: which telemetry files it has before (read only) - none may appear
$realHome = Join-Path $HOME '.codex'
$realTelemetry = { (@(if (Test-Path -LiteralPath $realHome) { Get-ChildItem -LiteralPath $realHome -Force | Where-Object { $_.Name -like 'telemetry*' } | ForEach-Object { $_.Name } }) | Sort-Object) -join ',' }
$realBefore = & $realTelemetry
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
# A fresh scratch codex home (config.toml only)
function New-Home {
    param([string]$Name)
    $h = Join-Path $work "home-$Name"
    [void][IO.Directory]::CreateDirectory($h)
    [IO.File]::WriteAllText((Join-Path $h 'config.toml'), $toml, $u8)
    return $h
}
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_STDERR', 'FAKE_CODEX_EXIT', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_PANEL_SEED', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_TELEMETRY', 'CODEX_CONSULT_TEST_TELEMETRY_ENV', 'RT_ACME_KEY', 'CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS', 'CODEX_CONSULT_TEST_TELEMETRY_FLUSH_MS')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    foreach ($k in (Get-HostMarkerNames)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $env:CODEX_CONSULT_HEALTH = 'none'
    $env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
}
# A case's environment: its codex home, its intake URL, its telemetry switch ('' = unset: ON), a
# roster ('' = none) and extra variables ('' removes one).
function Set-CaseEnv {
    param([string]$CodexHome, [string]$Url, [string]$Switch = '', [string]$Roster = '', [hashtable]$Env = @{})
    Clear-TestEnv
    $env:CODEX_HOME = $CodexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    $env:CODEX_CONSULT_TELEMETRY_URL = $Url
    if ($Switch) { $env:CODEX_CONSULT_TELEMETRY = $Switch }
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_CONSULT_TELEMETRY = 'off'; $env:CODEX_HOME = $savedCodexHome }
# One bridge run (synchronous): { Code; Out; First }
function Consult {
    param([string]$Repo, [string]$CodexHome, [string]$Url, [string]$Task, [string[]]$ArgList, [string]$Switch = '', [string]$Roster = '', [hashtable]$Env = @{})
    Set-CaseEnv $CodexHome $Url $Switch $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task $Task -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1) }
}
# A script started in the background (the intake answers while it runs), stdin from a file ($Stdin,
# '' = empty), output to files. Wait-Script collects it. { Proc; OutP; ErrP }
function Start-Script {
    param([string]$Script, [string[]]$ArgList, [string]$Cwd, [string]$CodexHome, [string]$Url, [string]$Switch = '', [hashtable]$Env = @{}, [string]$Stdin = '')
    Set-CaseEnv $CodexHome $Url $Switch '' $Env
    $tag = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $outP = Join-Path $work "out-$tag.txt"
    $inP = Join-Path $work "in-$tag.txt"
    [IO.File]::WriteAllText($inP, $Stdin, $u8)
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script) + @($ArgList)
    $argText = (@($all | ForEach-Object { if ([string]$_ -match '[\s"]' -or [string]$_ -eq '') { '"' + ([string]$_ -replace '"', '\"') + '"' } else { [string]$_ } }) -join ' ')
    $proc = Start-Process -FilePath $psExe -ArgumentList $argText -WorkingDirectory $Cwd -NoNewWindow -PassThru -RedirectStandardOutput $outP -RedirectStandardError "$outP.err" -RedirectStandardInput $inP
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $proc.Handle } catch { } }
    return [pscustomobject]@{ Proc = $proc; OutP = $outP; ErrP = "$outP.err" }
}
# { Code; Out } - the process waited for (killed after $TimeoutSec), the environment restored.
function Wait-Script {
    param($S, [int]$TimeoutSec = 90)
    if (-not $S.Proc.WaitForExit($TimeoutSec * 1000)) { try { $null = Stop-ProcessTree -Process $S.Proc } catch { }; $S.Proc.WaitForExit(5000) | Out-Null }
    Restore-Env
    $o = ''
    foreach ($f in @($S.OutP, $S.ErrP)) { if (Test-Path -LiteralPath $f) { $o += (Read-SharedText -Path $f) } }
    return [pscustomobject]@{ Code = $S.Proc.ExitCode; Out = $o.TrimEnd() }
}
# A local intake: an HttpListener on 127.0.0.1 and a free port. { Listener; Url; Pending }
function Start-Intake {
    $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $l.Start(); $port = $l.LocalEndpoint.Port; $l.Stop()
    $h = New-Object System.Net.HttpListener
    $h.Prefixes.Add("http://127.0.0.1:$port/")
    $h.Start()
    return [pscustomobject]@{ Listener = $h; Url = "http://127.0.0.1:$port/T"; Pending = $null }
}
function Stop-Intake { param($Intake) try { $Intake.Listener.Stop(); $Intake.Listener.Close() } catch { } }
# A closed loopback port: nothing answers there (an intake that is not reachable).
function Get-DeadUrl {
    $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $l.Start(); $port = $l.LocalEndpoint.Port; $l.Stop()
    return "http://127.0.0.1:$port/T"
}
$answerOk = @{ Status = 200; Type = 'application/json'; Body = '{"ok":true,"event_ids":[1]}' }
# Serves up to $Count requests with $Answers in order (the last one repeats) until $TimeoutSec;
# returns the requests { Method; Path; Query; Type; Body; At (s since the call); When }. An answer's
# DelayMs holds it back (a slow intake). A $Proc that has exited
# ends the wait after one more short look.
function Serve-Intake {
    param($Intake, [object[]]$Answers = @($answerOk), [int]$Count = 1, [double]$TimeoutSec = 60, $Proc = $null)
    $reqs = New-Object System.Collections.Generic.List[object]
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($reqs.Count -lt $Count) {
        if (-not $Intake.Pending) { $Intake.Pending = $Intake.Listener.BeginGetContext($null, $null) }
        $got = $false
        while ($true) {
            if ($Intake.Pending.AsyncWaitHandle.WaitOne(250)) { $got = $true; break }
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSec) { break }
            if ($Proc -and $Proc.HasExited) { if ($Intake.Pending.AsyncWaitHandle.WaitOne(1500)) { $got = $true }; break }
        }
        if (-not $got) { break }
        $ctx = $Intake.Listener.EndGetContext($Intake.Pending)
        $Intake.Pending = $null
        $rd = New-Object System.IO.StreamReader($ctx.Request.InputStream, $u8)
        $body = $rd.ReadToEnd()
        $reqs.Add([pscustomobject]@{ Method = $ctx.Request.HttpMethod; Path = $ctx.Request.Url.AbsolutePath; Query = $ctx.Request.Url.Query; Type = [string]$ctx.Request.ContentType; Body = $body; At = $watch.Elapsed.TotalSeconds; When = (Get-Date) })
        $a = $Answers[[Math]::Min($reqs.Count - 1, $Answers.Count - 1)]
        try {
            # (wave 28b, D2) a slow intake: the answer after DelayMs
            if ($a.DelayMs) { Start-Sleep -Milliseconds ([int]$a.DelayMs) }
            $resp = $ctx.Response
            $resp.StatusCode = [int]$a.Status
            if ($a.Type) { $resp.ContentType = [string]$a.Type }
            if ($a.Headers) { foreach ($k in $a.Headers.Keys) { $resp.AddHeader([string]$k, [string]$a.Headers[$k]) } }
            $bytes = $u8.GetBytes([string]$a.Body)
            $resp.ContentLength64 = $bytes.Length
            $resp.OutputStream.Write($bytes, 0, $bytes.Length)
            $resp.Close()
        } catch { }
    }
    return , ($reqs.ToArray())
}
# Waits until <spool>/.last was written at or after $Since (the sender finished), at most $TimeoutSec.
function Wait-Last {
    param([string]$CodexHome, [datetime]$Since, [int]$TimeoutSec = 45)
    $f = Join-Path (Join-Path $CodexHome 'telemetry-spool') '.last'
    $w = [System.Diagnostics.Stopwatch]::StartNew()
    while ($w.Elapsed.TotalSeconds -lt $TimeoutSec) {
        if ((Test-Path -LiteralPath $f) -and [IO.File]::GetLastWriteTimeUtc($f) -gt $Since.ToUniversalTime()) { Start-Sleep -Milliseconds 300; return $true }
        Start-Sleep -Milliseconds 250
    }
    return $false
}
function Last { param([string]$CodexHome) $f = Join-Path (Join-Path $CodexHome 'telemetry-spool') '.last'; if (Test-Path -LiteralPath $f) { return (ConvertFrom-Json (Read-SharedText -Path $f)) }; return $null }
# The spool's lines (every *.ndjson file, oldest first)
function Spool-Lines {
    param([string]$CodexHome)
    $d = Join-Path $CodexHome 'telemetry-spool'
    if (-not (Test-Path -LiteralPath $d)) { return , ([string[]]@()) }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($f in @(Get-ChildItem -LiteralPath $d -File -Filter '*.ndjson' | Sort-Object Name)) { foreach ($l in ((Read-SharedText -Path $f.FullName) -split "`n")) { if ($l.Trim()) { $lines.Add($l.TrimEnd("`r")) } } }
    return , ([string[]]$lines.ToArray())
}
function Spool-Bytes {
    param([string]$CodexHome)
    $d = Join-Path $CodexHome 'telemetry-spool'
    if (-not (Test-Path -LiteralPath $d)) { return '' }
    return ((@(Get-ChildItem -LiteralPath $d -File -Filter '*.ndjson' | Sort-Object Name | ForEach-Object { "$($_.Name):" + (Get-FileSha256 -Path $_.FullName) })) -join ';')
}
# A spool line written as the bridge writes it: kind, queued (unix s), body (JSON text)
function Seed-Line {
    param([string]$CodexHome, [string]$Kind, [string]$Body, [long]$Queued = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), [string]$Raw = '')
    $d = Join-Path $CodexHome 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($d)
    $line = $(if ($Raw) { $Raw } else { ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ v = 1; kind = $Kind; queued_unix = $Queued; body = $Body }) })
    [IO.File]::AppendAllText((Join-Path $d ([DateTime]::UtcNow.ToString('yyyy-MM-dd') + '.ndjson')), $line + "`n", $u8)
}
function Text { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Ledger { param([string]$Repo, [string]$Task) $f = Join-Path $Repo ".collab\$Task\sessions.json"; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Names { param($Obj) if ($null -eq $Obj) { return '' }; return (@($Obj.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') }
# THE allowlist walk of one event (an independent copy of the contract): every key at every level
# must be the contract's, in its order; returns the violations (empty: clean).
$eventKeys = 'app_id,app_version,instance_id,event_type,severity,title,details,tags,client_time,os,runtime'
$detailKeys = 'engine,provider,model,purpose,outcome,wall_seconds,tokens,findings,structured,format_retry,denial_retry,timeout_continue,panel_size,ps_version,os,bridge_version'
function Test-EventAllowlist {
    param($Ev)
    $v = New-Object System.Collections.Generic.List[string]
    if ((Names $Ev) -ne $eventKeys) { $v.Add("top: $(Names $Ev)") }
    if ((Names $Ev.details) -ne $detailKeys) { $v.Add("details: $(Names $Ev.details)") }
    if ((Names $Ev.details.tokens) -ne 'in,cached,out') { $v.Add("tokens: $(Names $Ev.details.tokens)") }
    if ((Names $Ev.details.findings) -ne 'blocker,major,minor,note') { $v.Add("findings: $(Names $Ev.details.findings)") }
    if (@($Ev.tags).Count -ne 2) { $v.Add("tags: $(@($Ev.tags).Count)") }
    foreach ($leaf in @($Ev.app_id, $Ev.event_type) ) { if (@('codex-consult', 'consultation') -notcontains [string]$leaf) { $v.Add("fixed value $leaf") } }
    if (@('info', 'warning', 'error') -notcontains [string]$Ev.severity) { $v.Add("severity $($Ev.severity)") }
    if ([string]$Ev.instance_id -cnotmatch '^[0-9a-f]{64}$') { $v.Add("instance_id $($Ev.instance_id)") }
    foreach ($k in @('in', 'cached', 'out')) { $x = $Ev.details.tokens.$k; if ($null -ne $x -and -not ($x -is [int] -or $x -is [long])) { $v.Add("tokens.$k not a number") } }
    foreach ($k in @('blocker', 'major', 'minor', 'note')) { $x = $Ev.details.findings.$k; if (-not ($x -is [int] -or $x -is [long])) { $v.Add("findings.$k not a number") } }
    foreach ($k in @('structured', 'format_retry', 'denial_retry', 'timeout_continue')) { if (-not ($Ev.details.$k -is [bool])) { $v.Add("$k not a boolean") } }
    return , ([string[]]$v.ToArray())
}
# Every string leaf of an object (recursively), but the instance id and the client time
function Get-Leaves {
    param($Obj)
    $list = New-Object System.Collections.Generic.List[string]
    $walk = $null
    $walk = {
        param($o, [string]$name)
        if ($null -eq $o) { return }
        if ($o -is [string]) { if (@('instance_id', 'client_time') -notcontains $name) { $list.Add($o) }; return }
        if ($o -is [System.Management.Automation.PSCustomObject]) { foreach ($p in $o.PSObject.Properties) { & $walk $p.Value $p.Name }; return }
        if ($o -is [System.Collections.IEnumerable]) { foreach ($i in $o) { & $walk $i $name }; return }
        $list.Add([string]$o)
    }
    & $walk $Obj ''
    return , ([string[]]$list.ToArray())
}
# The secrets a leaf must never carry: the machine name and the user name (4 characters or more,
# case-insensitive), and whatever the case adds
function Find-Leaks {
    param([string[]]$Leaves, [string[]]$Secrets)
    $all = @($Secrets) + @(@([Environment]::MachineName, [Environment]::UserName) | Where-Object { $_ -and $_.Length -ge 4 })
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($l in $Leaves) {
        foreach ($s in $all) { if ($s -and $l.IndexOf($s, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits.Add("'$l' carries '$s'") } }
        if ($l.Contains('\') -or $l -match '[A-Za-z]:/' -or $l.StartsWith('/')) { $hits.Add("'$l' looks like a path") }
    }
    return , ([string[]]$hits.ToArray())
}
$findingClaim = 'finding-secret-3m the cache key omits the tenant'
$replyJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[{"severity":"major","locations":[{"path":"app.txt","line":1}],"claim":"' + $findingClaim + '","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$reply = Join-Path $work 'reply.json'
[IO.File]::WriteAllText($reply, $replyJson, $u8)
$taskName = 'task-secret-7q'
$promptSecret = 'prompt-secret-4k check the cache'
$briefName = 'brief-secret-9z.md'
$version = Get-BridgeVersion
$noticeRe = @('telemetry is ON \(this notice is shown once per version\)', 'never sent - task names, briefs, prompts', 'switch it off with CODEX_CONSULT_TELEMETRY=off', 'complain or suggest: codex-consult\.ps1 -Task <task> -Complain', 'installing this plugin means accepting these terms')
function Count-Notice { param([string]$Out) return @($noticeRe | Where-Object { $Out -match ('(?m)^codex-consult: .*' + $_) }).Count }

try {

# =============================================================== UNIT: the switch, the URL, the instance id, the outcome, THE allowlist
if (Want 'UNIT') {
    $cases = @(@('', ''), @('off', ''), @(' OFF ', ''), @('0', ''), @('on', ''), @('yes', ''), @('garbage', ''), @('off', 'on'), @('', 'off'))
    $got = @(foreach ($c in $cases) {
            if ($c[0]) { $env:CODEX_CONSULT_TELEMETRY = $c[0] } else { Remove-Item env:CODEX_CONSULT_TELEMETRY -ErrorAction SilentlyContinue }
            $s = Get-TelemetrySwitch -Override $c[1]
            "$($s.Text)/$(if ($s.Source -like '*counts as off*') { 'bad' } else { $s.Source })"
        })
    $env:CODEX_CONSULT_TELEMETRY = 'off'
    Check 'UNIT' 'Get-TelemetrySwitch: unset -> on (the default); off / OFF / 0 -> off; on / yes -> on; any other value -> OFF ("not on or off: counts as off"); -Telemetry on|off wins over the variable' (($got -join ' ') -eq 'on/the default off/CODEX_CONSULT_TELEMETRY off/CODEX_CONSULT_TELEMETRY off/CODEX_CONSULT_TELEMETRY on/CODEX_CONSULT_TELEMETRY on/CODEX_CONSULT_TELEMETRY off/bad on/-Telemetry off/-Telemetry') ($got -join ' ')
    $urls = @(foreach ($u in @('', 'http://127.0.0.1:1/T/', 'http://localhost:5/T', 'https://intake.example/T', 'http://intake.example/T', 'not a url', 'ftp://127.0.0.1/T')) {
            if ($u) { $env:CODEX_CONSULT_TELEMETRY_URL = $u } else { Remove-Item env:CODEX_CONSULT_TELEMETRY_URL -ErrorAction SilentlyContinue }
            $r = Get-TelemetryUrl
            $(if ($r.Error) { '!' } else { $r.Base })
        })
    $env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
    Check 'UNIT' 'Get-TelemetryUrl (test mode): default https://xelth.com/T; a loopback http intake is taken (trailing slash dropped); https elsewhere is taken; plain http to another host, a non-URL and another scheme are refused' (($urls -join ' ') -eq 'https://xelth.com/T http://127.0.0.1:1/T http://localhost:5/T https://intake.example/T ! ! !') ($urls -join ' ')
    # (wave 28b, D4 / F36-9, F37-4) plain http to a loopback intake only WITH test mode
    $env:CODEX_CONSULT_TEST_MODE = ''
    $noTm = @(foreach ($u in @('http://127.0.0.1:1/T', 'http://localhost:5/T', 'https://intake.example/T')) { $env:CODEX_CONSULT_TELEMETRY_URL = $u; $r0 = Get-TelemetryUrl; $(if ($r0.Error) { "!$(if ($r0.Error -match 'only with CODEX_CONSULT_TEST_MODE=1') { 'tm' })" } else { $r0.Base }) })
    $env:CODEX_CONSULT_TEST_MODE = '1'
    $env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
    Check 'UNIT' 'D4 without CODEX_CONSULT_TEST_MODE=1 a plain-http loopback intake (127.0.0.1, localhost) is REFUSED ("plain http to a loopback intake only with CODEX_CONSULT_TEST_MODE=1"); https stays taken' (($noTm -join ' ') -eq '!tm !tm https://intake.example/T') ($noTm -join ' ')
    $h = New-Home 'unit'
    $env:CODEX_HOME = $h
    $none = Get-TelemetryInstanceId
    $saltP = Join-Path $h 'telemetry-salt'
    $noSalt = -not (Test-Path -LiteralPath $saltP)
    $id1 = Get-TelemetryInstanceId -Create
    $id2 = Get-TelemetryInstanceId
    $hex = (Text $saltP).Trim()
    $salt = New-Object byte[] 32
    for ($i = 0; $i -lt 32; $i++) { $salt[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    $mn = $u8.GetBytes([Environment]::MachineName)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $expect = ([BitConverter]::ToString($sha.ComputeHash([byte[]]($salt + $mn)))).Replace('-', '').ToLowerInvariant()
    $bare = ([BitConverter]::ToString($sha.ComputeHash($mn))).Replace('-', '').ToLowerInvariant()
    $sha.Dispose()
    Check 'UNIT' 'instance id: none without a salt (and nothing created); -Create makes <codex home>/telemetry-salt once (64 hex digits = 32 random bytes); id = sha256(salt bytes || UTF-8 machine name), stable, never the bare hash of the machine name' ($none -eq '' -and $noSalt -and $hex -cmatch '^[0-9a-f]{64}$' -and $id1 -eq $expect -and $id2 -eq $id1 -and $id1 -ne $bare) "$id1 vs $expect"
    $env:CODEX_HOME = $savedCodexHome
    $mk = { param([string]$Outcome, [string]$Class) [pscustomobject]@{ bridge_outcome = $Outcome; provider_failure = $(if ($Class) { [pscustomobject]@{ class = $Class } } else { $null }) } }
    $oc = @(foreach ($c in @(@('usable reply', ''), @('usable reply (after a timeout continuation)', ''), @('failed: codex exit 1', 'quota'), @('failed: x', 'auth'), @('failed: x', 'transport'), @('failed: timeout after 4 s (process tree killed)', ''), @('failed: stalled after 9 s without an event', ''), @('failed: stopped by the operator (-Kick)', 'operator'), @('failed: x', 'weird'), @('failed: could not start codex', ''))) { $o = Get-TelemetryOutcome (& $mk $c[0] $c[1]); "$($o.Outcome)/$($o.Severity)" })
    Check 'UNIT' 'the outcome class and severity: usable/info, usable-after-continuation/info, failed:quota and failed:auth warning, failed:transport error, failed:timeout and failed:stalled error (no provider class), failed:operator warning, an unknown class -> failed:unknown, a bridge failure -> failed:bridge error' (($oc -join ' ') -eq 'usable/info usable-after-continuation/info failed:quota/warning failed:auth/warning failed:transport/error failed:timeout/error failed:stalled/error failed:operator/warning failed:unknown/error failed:bridge/error') ($oc -join ' ')
    # a hostile entry: every free-text field carries a secret, the identity fields carry paths
    $user = [Environment]::UserName
    $hostile = [pscustomobject]@{
        n = 4; when = '2026-09-29T10:00:00+02:00'; purpose = "secret-purpose-$taskName"; topics = @('topic-secret'); role = 'role-secret'; consult_id = '11111111-2222-3333-4444-555555555555'
        reviewer = [pscustomobject]@{ provider = "C:\Users\$user\p"; model = "C:/Users/$user/m"; engine = 'codex'; identity_note = 'note-secret'; provider_fingerprint = 'fp-secret' }
        lineage = 'lineage-secret'; parent_thread = 'thread-secret-a'; thread = 'thread-secret-b'; command = "codex exec -C C:\Users\$user"; brief = "handoffs/01-claude-$briefName"; reply = 'handoffs/02-codex-reply-secret.md'
        bridge_outcome = "failed: codex exit 1 - $findingClaim"; provider_failure = [pscustomobject]@{ class = 'quota'; message = "message-secret $([Environment]::MachineName)" }
        warnings = @('warning-secret'); verdict_reason = 'reason-secret'; finding_ids = @('F04-1'); structured = $true; wall_seconds = 42.4
        findings = [pscustomobject]@{ blocker = 1; major = 2; minor = 3; note = 4 }; usage = [pscustomobject]@{ input_tokens = 1000; cached_input_tokens = 200; output_tokens = 300 }
        format_retry = [pscustomobject]@{ attempted = $true; reason = 'reason-secret' }; denial_retry = $null; timeout_continue = [pscustomobject]@{ outcome = 'not attempted: -ContinueSec 0' }; panel = [pscustomobject]@{ id = 'panel-secret'; of = 3 }
    }
    $hev = New-TelemetryEvent -Entry $hostile -InstanceId ('ab' * 32)
    $hjson = ConvertTo-Json -Compress -Depth 6 -InputObject $hev
    $hparsed = ConvertFrom-Json $hjson
    $viol = Test-EventAllowlist $hparsed
    $secrets = @($taskName, $briefName, 'secret', 'thread-', 'handoffs', '11111111-2222', $findingClaim.Substring(0, 20), 'F04-1')
    $leaks = Find-Leaks (Get-Leaves $hparsed) $secrets
    Check 'UNIT' 'THE allowlist, walked key by key on the event of a hostile entry: exactly app_id..runtime, details engine..bridge_version, tokens {in,cached,out}, findings {blocker,major,minor,note}, (wave 28b, D1) tags [provider, model]; no string leaf carries a task name, a brief, a thread id, a consultation id, a finding text or id, a message, a warning, a path, the machine or the user name' ($viol.Count -eq 0 -and $leaks.Count -eq 0) (($viol + $leaks) -join ' || ')
    Check 'UNIT' 'the hostile entry''s values: provider and model with a path shape -> other, an unknown purpose -> other, outcome failed:quota (severity warning), counts and booleans carried (format_retry true, timeout_continue false: not attempted), panel_size 3, wall_seconds rounded 42, tags [other, other]' ($hev.details.provider -eq 'other' -and $hev.details.model -eq 'other' -and $hev.details.purpose -eq 'other' -and $hev.title -eq 'failed:quota' -and $hev.severity -eq 'warning' -and $hev.details.findings.note -eq 4 -and $hev.details.tokens.cached -eq 200 -and $hev.details.format_retry -eq $true -and $hev.details.timeout_continue -eq $false -and $hev.details.panel_size -eq 3 -and $hev.details.wall_seconds -eq 42 -and (@($hev.tags) -join ',') -eq 'other,other') $hjson
    # (wave 28b, D1 / F36-1) THE vendor table: the provider is the vendor CLASS of the endpoint (its
    # host, the built-in openai provider, the engine), the model a name of that vendor's pattern
    $rv = { param([string]$Engine, $Pc, [string]$Label, [string]$Model) [pscustomobject]@{ reviewer = [pscustomobject]@{ provider = $Label; model = $Model; engine = $Engine; provider_config = $Pc } } }
    $bu = { param([string]$U) [pscustomobject]@{ base_url = $U; wire_api = 'responses' } }
    $vcases = @(
        @((& $rv 'codex' ([pscustomobject]@{ builtin = 'openai' }) 'openai' 'gpt-5.1'), 'openai/gpt-5.1'),
        @((& $rv 'codex' ([pscustomobject]@{ builtin = 'openai' }) 'openai' 'gpt-6-astra'), 'openai/gpt-6-astra'),
        @((& $rv 'codex' (& $bu 'https://api.openai.com/v1') 'work-oai' 'o4-mini'), 'openai/o4-mini'),
        @((& $rv 'codex' (& $bu 'https://api.z.ai/api/v1') 'ZAI' 'glm-5.3'), 'zai/glm-5.3'),
        @((& $rv 'codex' (& $bu 'https://api.z.ai/api/v1') 'ZAI' 'GLM-4.5-Air'), 'zai/glm-4.5-air'),
        @((& $rv 'codex' (& $bu 'https://token-plan-ams.xiaomimimo.com/v1') 'mimo' 'mimo-v2.6-pro'), 'xiaomi/mimo-v2.6-pro'),
        @((& $rv 'codex' (& $bu 'https://ark.ap-southeast.bytepluses.com/api/coding/v3') 'byteplus' 'deepseek-v4.1-flash'), 'byteplus/deepseek-v4.1-flash'),
        @((& $rv 'codex' (& $bu 'https://ark.ap-southeast.bytepluses.com/api/coding/v3') 'byteplus' 'dola-seed-2.0-pro'), 'byteplus/dola-seed-2.0-pro'),
        @((& $rv 'codex' (& $bu 'https://api.kimi.ai/coding/v1') 'kimi' 'k3'), 'moonshot/k3'),
        @((& $rv 'codex' (& $bu 'https://api.moonshot.ai/v1') 'moon' 'kimi-k2.5'), 'moonshot/kimi-k2.5'),
        @((& $rv 'codex' (& $bu 'https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1') 'alibaba' 'qwen3.8-max'), 'alibaba/qwen3.8-max'),
        @((& $rv 'agy' ([pscustomobject]@{ engine = 'agy' }) 'gemini' 'gemini-3.8-flash-high'), 'google/gemini-3.8-flash-high'),
        @((& $rv 'muse' ([pscustomobject]@{ engine = 'muse' }) 'meta' 'muse-spark-1.3-contributor'), 'meta/muse-spark-1.3-contributor'),
        @((& $rv 'codex' (& $bu 'https://api.z.ai/api/v1') 'ZAI' 'gpt-5.1'), 'zai/other'),
        @((& $rv 'codex' (& $bu 'https://api.z.ai/api/v1') 'ZAI' 'glm-acmecorp-private'), 'zai/other'),
        @((& $rv 'codex' (& $bu 'https://evil-z.ai.example/v1') 'ZAI' 'glm-5.3'), 'other/other'),
        @((& $rv 'codex' (& $bu 'http://127.0.0.1:8080/v1') 'local' 'qwen3:8b'), 'other/other'),
        @((& $rv 'agy' ([pscustomobject]@{ engine = 'agy' }) 'gemini' '/home/u/m'), 'google/other'),
        @((& $rv 'codex' $null 'x' 'gpt-5.1'), 'other/other')
    )
    $vgot = @(foreach ($vc in $vcases) { $vd = ConvertTo-TelemetryDetails $vc[0]; "$($vd.provider)/$($vd.model)" })
    $vwant = @($vcases | ForEach-Object { $_[1] })
    Check 'UNIT' 'D1 the vendor table: builtin openai (the ChatGPT login) and api.openai.com -> openai; api.z.ai -> zai; *.xiaomimimo.com -> xiaomi; *.bytepluses.com -> byteplus; api.kimi.ai, api.moonshot.ai -> moonshot; *.aliyuncs.com -> alibaba; engine agy -> google, muse -> meta; the model kept (lower case) only when it follows that vendor''s pattern (gpt-5.1 at z.ai, glm-acmecorp-private -> other); a look-alike host, a local endpoint, no endpoint -> other/other' (($vgot -join ' ') -eq ($vwant -join ' ')) (@(for ($i = 0; $i -lt $vgot.Count; $i++) { if ($vgot[$i] -ne $vwant[$i]) { "$($vwant[$i]) got $($vgot[$i])" } }) -join '; ')
    # the allowlist walks the VALUES: a roster label and a model that look like a company name
    $corp = & $rv 'codex' (& $bu 'https://llm.acmecorp-internal.example/v1') 'AcmeCorp-Legal' 'acmecorp-contracts-7b'
    $cev = New-TelemetryEvent -Entry $corp -InstanceId ('cd' * 32)
    $cjson = ConvertTo-Json -Compress -Depth 6 -InputObject $cev
    Check 'UNIT' 'D1 a roster label AcmeCorp-Legal on llm.acmecorp-internal.example with the model acmecorp-contracts-7b: provider other, model other, tags [other, other]; the event text holds neither name (case-insensitive)' ($cev.details.provider -eq 'other' -and $cev.details.model -eq 'other' -and (@($cev.tags) -join ',') -eq 'other,other' -and $cjson -inotmatch 'acmecorp') $cjson
    # (wave 28b, D5 / F36-9) the salt: never replaced once it parses; a bad one moved ASIDE (kept); racing creators agree
    $h5 = New-Home 'salt'
    $env:CODEX_HOME = $h5
    $s5 = Join-Path $h5 'telemetry-salt'
    [IO.File]::WriteAllText($s5, ('ab' * 32) + "`n", $u8)
    $keepId = Get-TelemetryInstanceId -Create
    $kept5 = (Text $s5).Trim() -eq ('ab' * 32)
    [IO.File]::WriteAllText($s5, "not a salt`n", $u8)
    $newId = Get-TelemetryInstanceId -Create
    $aside = @(Get-ChildItem -LiteralPath $h5 -File -Filter 'telemetry-salt.bad-*')
    $asideOk = ($aside.Count -eq 1 -and (Text $aside[0].FullName).Trim() -eq 'not a salt')
    $env:CODEX_HOME = $savedCodexHome
    Check 'UNIT' 'D5 a salt that parses is never replaced (-Create keeps it, the id from it); one that does not parse is moved ASIDE to telemetry-salt.bad-<guid> (kept, not deleted) and a new salt made' ($keepId -and $kept5 -and $newId -and $newId -ne $keepId -and (Text $s5).Trim() -cmatch '^[0-9a-f]{64}$' -and $asideOk) "kept $kept5 aside $($aside.Count)"
    $h6 = New-Home 'saltrace'
    $raceCmd = ". '$($scripts.Replace("'", "''"))\codex-consult-common.ps1'; `$env:CODEX_HOME = '$($h6.Replace("'", "''"))'; Get-TelemetryInstanceId -Create"
    $racers = @(for ($i = 0; $i -lt 4; $i++) { $o = Join-Path $work "race-$i.txt"; [pscustomobject]@{ Out = $o; Proc = (Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $raceCmd) -NoNewWindow -PassThru -RedirectStandardOutput $o) } })
    foreach ($rc in $racers) { if (-not $rc.Proc.WaitForExit(60000)) { try { $rc.Proc.Kill() } catch { } } }
    $raceIds = @($racers | ForEach-Object { (Text $_.Out).Trim() } | Select-Object -Unique)
    Check 'UNIT' 'D5 four processes creating the salt at once agree on ONE instance id (the move without overwrite: a loser reads the winner''s salt); one salt file, no stray temporary file' ($raceIds.Count -eq 1 -and $raceIds[0] -cmatch '^[0-9a-f]{64}$' -and @(Get-ChildItem -LiteralPath $h6 -File -Filter 'telemetry-salt*').Count -eq 1) "ids: $($raceIds -join ', ')"
    # (wave 28b, D16) the spool file is named by the LOCAL date
    $lateUtc = [DateTime]::SpecifyKind([DateTime]::UtcNow.Date.AddHours(23).AddMinutes(59), [DateTimeKind]::Utc)
    $nm = @((Get-TelemetrySpoolName -At $lateUtc), (Get-TelemetrySpoolName -At $lateUtc.ToLocalTime()), (Get-TelemetrySpoolName -At ([datetime]::new(2026, 9, 29, 23, 59, 59, [DateTimeKind]::Local))), (Get-TelemetrySpoolName -At ([datetime]::new(2026, 9, 30, 0, 0, 1, [DateTimeKind]::Local))))
    Check 'UNIT' 'D16 the spool file name is the LOCAL date: a UTC instant and its local time give the same name (its local date, not the UTC one); 23:59:59 and 00:00:01 local fall on two days' ($nm[0] -eq ($lateUtc.ToLocalTime().ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) + '.ndjson') -and $nm[0] -eq $nm[1] -and $nm[2] -eq '2026-09-29.ndjson' -and $nm[3] -eq '2026-09-30.ndjson') ($nm -join ' ')
    # (wave 28b, D3 / F36-3) the sender's environment: an ALLOW list
    $probe = @{ RT_ZAI_KEY = 'zai-test-key'; CODEX_CONSULT_ROSTER = 'x'; CLAUDECODE = '1'; CODEX_CONSULT_TEST_PANEL_SEED = '7'; CODEX_CONSULT_TEST_TELEMETRY_ENV = 'x'; LC_ALL = 'C'; HTTPS_PROXY = 'http://proxy.example:8080' }
    foreach ($k in $probe.Keys) { Set-Item "env:$k" $probe[$k] }
    $senv = Get-TelemetrySenderEnvironment
    $psiS = New-TelemetrySenderStartInfo -Script $telemetryPs -HostExe $psExe
    $blockNames = @($psiS.EnvironmentVariables.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $env:CODEX_CONSULT_TEST_MODE = ''
    $senvOff = Get-TelemetrySenderEnvironment
    $env:CODEX_CONSULT_TEST_MODE = '1'
    $bridgeKept = ([string]$env:RT_ZAI_KEY -eq 'zai-test-key' -and [string]$env:CLAUDECODE -eq '1')
    foreach ($k in $probe.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $sNames = @($senv.Keys | ForEach-Object { [string]$_ })
    $bad = @($sNames | Where-Object { -not (Test-TelemetrySenderEnvName -Name $_ -TestMode $true) })
    Check 'UNIT' 'D3 the sender''s environment is an ALLOW list (Get-TelemetrySenderEnvironment, the start info''s block cleared and filled from it): LC_ALL, HTTPS_PROXY, PATH, SystemRoot, CODEX_HOME, CODEX_CONSULT_TELEMETRY_URL in; no provider key (RT_ZAI_KEY), no host marker (CLAUDECODE), no CODEX_CONSULT_ROSTER, no CODEX_CONSULT_TEST_PANEL_SEED; in test mode CODEX_CONSULT_TEST_MODE and the sender''s own hook CODEX_CONSULT_TEST_TELEMETRY_ENV - without test mode neither; the bridge''s own environment unchanged' ($sNames -contains 'LC_ALL' -and $sNames -contains 'HTTPS_PROXY' -and ($sNames -contains 'PATH' -or $sNames -contains 'Path') -and $sNames -contains 'SystemRoot' -and $sNames -contains 'CODEX_CONSULT_TELEMETRY_URL' -and $sNames -notcontains 'RT_ZAI_KEY' -and $sNames -notcontains 'CLAUDECODE' -and $sNames -notcontains 'CODEX_CONSULT_ROSTER' -and $sNames -notcontains 'CODEX_CONSULT_TEST_PANEL_SEED' -and $sNames -contains 'CODEX_CONSULT_TEST_MODE' -and $sNames -contains 'CODEX_CONSULT_TEST_TELEMETRY_ENV' -and @($senvOff.Keys | Where-Object { ([string]$_) -like 'CODEX_CONSULT_TEST_*' }).Count -eq 0 -and $bad.Count -eq 0 -and (($blockNames | ForEach-Object { $_.ToLowerInvariant() }) -join ',') -eq ((@($sNames | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object)) -join ',') -and $bridgeKept) "sender: $($sNames -join ',') | block $($blockNames.Count)"
}

# =============================================================== SPOOL: the event after a usable and a failed run; off writes nothing; a panel
if (Want 'SPOOL') {
    $dead = Get-DeadUrl
    $h = New-Home 'spool'
    $r = New-Repo 'spool'
    [IO.File]::WriteAllText((Join-Path $r $briefName), "# brief`nlook at app.txt`n", $u8)
    $t0 = Get-Date
    $ok = Consult $r $h $dead $taskName @('-Purpose', 'checkpoint', '-Brief', $briefName, '-Prompt', $promptSecret, '-ReplyName', 'rs') -Env @{ FAKE_CODEX_REPLY = $reply }
    $lines = Spool-Lines $h
    $e = (Ledger $r $taskName)[-1]
    $sl = $null; $ev = $null
    try { $sl = ConvertFrom-Json $lines[0]; $ev = ConvertFrom-Json ([string]$sl.body) } catch { }
    # (wave 28b, D16) the LOCAL date names the file
    $spoolName = (Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) + '.ndjson'
    Check 'SPOOL' 'a usable run with telemetry on (unset): exit 0, ONE line in <codex home>/telemetry-spool/<local yyyy-mm-dd>.ndjson - {v 1, kind event, queued_unix, body: the event as a JSON string}' ($ok.Code -eq 0 -and $lines.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path (Join-Path $h 'telemetry-spool') $spoolName)) -and (Names $sl) -eq 'v,kind,queued_unix,body' -and $sl.v -eq 1 -and $sl.kind -eq 'event' -and $null -ne $ev) "$($ok.Code) $($lines.Count) $(if ($lines.Count) { $lines[0].Substring(0, [Math]::Min(120, $lines[0].Length)) })"
    $viol = @(); if ($ev) { $viol = Test-EventAllowlist $ev }
    Check 'SPOOL' 'the REAL event passes the allowlist walk (every key at every level the contract''s, in order)' ($ev -and $viol.Count -eq 0) ($viol -join ' || ')
    $iid = ''; $env:CODEX_HOME = $h; $iid = Get-TelemetryInstanceId; $env:CODEX_HOME = $savedCodexHome
    $d = $(if ($ev) { $ev.details } else { $null })
    Check 'SPOOL' 'the event is the committed entry''s: engine codex, provider openai, model gpt-5.1, purpose checkpoint, outcome usable (severity info, title usable), findings = the ledger''s (1 major), tokens = the ledger''s usage, structured true, wall_seconds = the ledger''s, panel_size 0, (wave 28b, D1) provider openai = the vendor class of the built-in provider, tags [openai, gpt-5.1], instance_id = this home''s, client_time UTC, runtime/os/bridge_version of this host' ($d -and $d.engine -eq 'codex' -and $d.provider -eq 'openai' -and $d.model -eq 'gpt-5.1' -and $d.purpose -eq 'checkpoint' -and $d.outcome -eq 'usable' -and $ev.severity -eq 'info' -and $ev.title -eq 'usable' -and $d.findings.major -eq $e.findings.major -and $d.findings.major -eq 1 -and $d.tokens.in -eq $e.usage.input_tokens -and $d.tokens.out -eq $e.usage.output_tokens -and $d.structured -eq $true -and [Math]::Abs($d.wall_seconds - [double]$e.wall_seconds) -le 1 -and $d.panel_size -eq 0 -and (@($ev.tags) -join ',') -eq 'openai,gpt-5.1' -and $ev.instance_id -eq $iid -and [string]$sl.body -match '"client_time":"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ"' -and $ev.runtime -eq (Get-TelemetryRuntime) -and $ev.os -eq (Get-TelemetryOs) -and $d.bridge_version -eq $version) $(if ($ev) { [string]$sl.body } else { '' })
    $leaks = @()
    if ($ev) { $leaks = Find-Leaks (Get-Leaves $ev) @($taskName, $briefName, 'secret', [string]$e.thread, [string]$e.consult_id, 'handoffs', $r) }
    $rawHits = @(foreach ($s in @($taskName, 'brief-secret', 'prompt-secret', 'finding-secret', [string]$e.thread, [string]$e.consult_id)) { if ($s -and $lines.Count -gt 0 -and $lines[0].Contains($s)) { $s } })
    Check 'SPOOL' 'the spool line carries no task name, brief name, prompt, finding text, thread id or consultation id, and no leaf a path, the machine or the user name' ($lines.Count -gt 0 -and $leaks.Count -eq 0 -and $rawHits.Count -eq 0) (($leaks + $rawHits) -join ' || ')
    $null = Wait-Last $h $t0
    Check 'SPOOL' 'the detached sender ran (an unreachable intake: .last "not delivered: ...", exit of the run unaffected) and the spool was kept' ((Last $h) -and ([string](Last $h).result) -like 'not delivered:*' -and (Spool-Lines $h).Count -eq 1) "$((Last $h).result)"
    # a failed run (a quota failure) in another repository (its endpoint is out afterwards)
    $rf = New-Repo 'spool-failed'
    $t1 = Get-Date
    $fl = Consult $rf $h $dead $taskName @('-Purpose', 'checkpoint', '-Prompt', $promptSecret, '-ReplyName', 'rf') -Env @{ FAKE_CODEX_STDERR = 'Error: credits exhausted for this token plan'; FAKE_CODEX_EXIT = '1' }
    $lines = Spool-Lines $h
    $ef = (Ledger $rf $taskName)[-1]
    $ev2 = $null; try { $ev2 = ConvertFrom-Json ([string](ConvertFrom-Json $lines[-1]).body) } catch { }
    Check 'SPOOL' 'a FAILED run (a quota failure) spools its event too: exit 1, a second line - severity warning, title and outcome failed:quota (the ledger''s provider_failure.class), allowlist clean' ($fl.Code -eq 1 -and $lines.Count -eq 2 -and $ef.provider_failure.class -eq 'quota' -and $ev2 -and $ev2.severity -eq 'warning' -and $ev2.title -eq 'failed:quota' -and $ev2.details.outcome -eq 'failed:quota' -and (Test-EventAllowlist $ev2).Count -eq 0) "$($fl.Code) lines=$($lines.Count) $($ef.bridge_outcome) | $(if ($ev2) { $ev2.title })"
    $null = Wait-Last $h $t1
    $ro = New-Repo 'spool-off'
    $off1 = Consult $ro $h $dead $taskName @('-Prompt', 'x', '-ReplyName', 'o1', '-Telemetry', 'off') -Env @{ FAKE_CODEX_REPLY = $reply }
    Check 'SPOOL' '-Telemetry off (telemetry otherwise on): a usable run appends NOTHING' ($off1.Code -eq 0 -and (Spool-Lines $h).Count -eq 2) "$($off1.Code) $((Spool-Lines $h).Count)"
    $h2 = New-Home 'spool-envoff'
    $off2 = Consult $ro $h2 $dead $taskName @('-Prompt', 'x', '-ReplyName', 'o2') -Switch 'off' -Env @{ FAKE_CODEX_REPLY = $reply }
    $written = @(Get-ChildItem -LiteralPath $h2 -Force | Where-Object { $_.Name -like 'telemetry*' } | ForEach-Object { $_.Name })
    Check 'SPOOL' 'CODEX_CONSULT_TELEMETRY=off in a fresh codex home: the run writes NOTHING of telemetry - no spool, no salt, no notice marker - and prints no notice' ($off2.Code -eq 0 -and $written.Count -eq 0 -and (Count-Notice $off2.Out) -eq 0) "$($off2.Code) [$($written -join ',')]"
    $t2 = Get-Date
    $on2 = Consult $ro $h2 $dead $taskName @('-Prompt', 'x', '-ReplyName', 'o3', '-Telemetry', 'on') -Switch 'off' -Env @{ FAKE_CODEX_REPLY = $reply }
    Check 'SPOOL' 'CODEX_CONSULT_TELEMETRY=off with -Telemetry on: the run''s switch wins - one line spooled' ($on2.Code -eq 0 -and (Spool-Lines $h2).Count -eq 1) "$($on2.Code) $((Spool-Lines $h2).Count)"
    $null = Wait-Last $h2 $t2
    # a panel: every member spools its own event (panel_size = the members), one sender for the panel
    $roster2 = Write-Roster 'two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'
    $h3 = New-Home 'spool-panel'
    $rp = New-Repo 'spool-panel'
    $t3 = Get-Date
    $pn = Consult $rp $h3 $dead $taskName @('-Panel', '-PanelAll', '-Purpose', 'checkpoint', '-Prompt', 'x', '-ReplyName', 'pn') -Roster $roster2 -Env @{ FAKE_CODEX_REPLY = $reply }
    $plLines = Spool-Lines $h3
    $pl = @($plLines | ForEach-Object { ConvertFrom-Json ([string](ConvertFrom-Json $_).body) })
    $provs = @($pl | ForEach-Object { $_.details.provider } | Sort-Object) -join ','
    Check 'SPOOL' 'a -Panel of two members: two lines, one per member (wave 28b, D1: the vendor classes openai and zai - the label ZAI never), each panel_size 2, outcome usable, allowlist clean' ($pn.Code -eq 0 -and $pl.Count -eq 2 -and $provs -ceq 'openai,zai' -and @($pl | Where-Object { $_.details.panel_size -eq 2 -and $_.details.outcome -eq 'usable' -and (Test-EventAllowlist $_).Count -eq 0 }).Count -eq 2) "$($pn.Code) $($pl.Count) $provs"
    Check 'SPOOL' 'the panel started its sender once every member was done (.last written after the panel)' (Wait-Last $h3 $t3) "$((Last $h3).result)"
    # (wave 28b, D1 / F36-1) a REAL run of a roster entry whose label and model look like a company
    $hc = New-Home 'spool-corp'
    [IO.File]::AppendAllText((Join-Path $hc 'config.toml'), "`n[model_providers.AcmeCorp-Legal]`nbase_url = `"https://llm.acmecorp-internal.example/v1`"`nenv_key = `"RT_ACME_KEY`"`nwire_api = `"responses`"`n", $u8)
    $rosterC = Write-Roster 'corp' '{"roster_version":1,"reviewers":[{"provider":"AcmeCorp-Legal","model":"acmecorp-contracts-7b"}]}'
    $rc = New-Repo 'spool-corp'
    $tc = Get-Date
    $cr = Consult $rc $hc $dead $taskName @('-Purpose', 'checkpoint', '-Prompt', 'x', '-ReplyName', 'corp', '-NativeEffort', 'high') -Roster $rosterC -Env @{ FAKE_CODEX_REPLY = $reply; RT_ACME_KEY = 'acme-test-key' }
    $cLines = Spool-Lines $hc
    $ec = @(Ledger $rc $taskName)[-1]
    $cev = $null; try { $cev = ConvertFrom-Json ([string](ConvertFrom-Json $cLines[0]).body) } catch { }
    Check 'SPOOL' 'D1 a real run of the roster entry AcmeCorp-Legal :: acmecorp-contracts-7b (its endpoint llm.acmecorp-internal.example): the ledger keeps the real label and model, the EVENT says provider other, model other, tags [other, other] - the spool line holds neither name' ($cr.Code -eq 0 -and $ec.reviewer.provider -eq 'AcmeCorp-Legal' -and $ec.reviewer.model -eq 'acmecorp-contracts-7b' -and $cLines.Count -eq 1 -and $cev -and $cev.details.provider -eq 'other' -and $cev.details.model -eq 'other' -and (@($cev.tags) -join ',') -eq 'other,other' -and $cLines[0] -inotmatch 'acmecorp') "$($cr.Code) $($ec.reviewer.provider) | $(if ($cLines.Count) { $cLines[0].Substring(0, [Math]::Min(160, $cLines[0].Length)) })"
    $null = Wait-Last $hc $tc
    # (wave 28b, D6 / F35-1, F36-8, F37-6) a spool file that stays busy: the event is NOT lost silently
    $hb = New-Home 'spool-busy'
    $rb = New-Repo 'spool-busy'
    $bdir = Join-Path $hb 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($bdir)
    $bfile = Join-Path $bdir (Get-TelemetrySpoolName)
    $holdFs = New-Object System.IO.FileStream($bfile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $wb = [System.Diagnostics.Stopwatch]::StartNew()
    try { $busy = Consult $rb $hb $dead $taskName @('-Prompt', 'x', '-ReplyName', 'busy') -Env @{ FAKE_CODEX_REPLY = $reply } } finally { $holdFs.Dispose() }
    $busySec = $wb.Elapsed.TotalSeconds
    $eb = @(Ledger $rb $taskName)[-1]
    $bw = @(@($eb.warnings) | Where-Object { ([string]$_) -match '^telemetry event not spooled \(the spool file .* stayed busy for 5 s\)$' })
    $sb = Start-Script $telemetryPs @('-Status') $work $hb $dead ''
    $xb = Wait-Script $sb
    Check 'SPOOL' 'D6 the day''s spool file held exclusively by another process for the whole run: the append waits 5 s, then the run (still exit 0) puts "telemetry event not spooled (the spool file ... stayed busy for 5 s)" into warnings[] and onto the console ("warning    : telemetry event not spooled"); -Status counts it ("not spooled: 1 event(s) since the last flush")' ($busy.Code -eq 0 -and $bw.Count -eq 1 -and $busy.Out -match '(?m)^warning    : telemetry event not spooled \(' -and $busySec -ge 5 -and $xb.Out -match '(?m)^not spooled: 1 event\(s\) since the last flush') "exit $($busy.Code) in $([Math]::Round($busySec, 1)) s; warnings: $(@($eb.warnings) -join ' | ') | $((($xb.Out -split "`n") | Where-Object { $_ -like 'not spooled*' }) -join '')"
    $sf = Start-Script $telemetryPs @('-Flush') $work $hb $dead 'on'
    $null = Wait-Script $sf
    $sb2 = Start-Script $telemetryPs @('-Status') $work $hb $dead ''
    $xb2 = Wait-Script $sb2
    Check 'SPOOL' 'D6 the next flush starts the count again: -Status "not spooled: none since the last flush"' ($xb2.Out -match '(?m)^not spooled: none since the last flush') ((($xb2.Out -split "`n") | Where-Object { $_ -like 'not spooled*' }) -join '')
}

# =============================================================== NOTICE / DRYRUN: the notice once per version; the dry run's line
if (Want 'NOTICE') {
    $dead = Get-DeadUrl
    $h = New-Home 'notice'
    $r = New-Repo 'notice'
    $d1 = Consult $r $h $dead 't' @('-DryRun', '-Prompt', 'x')
    $nothing = @(Get-ChildItem -LiteralPath $h -Force | Where-Object { $_.Name -like 'telemetry*' }).Count -eq 0
    Check 'DRYRUN' 'the dry run (telemetry on by default) prints "telemetry   : on (the default) - after the commit ONE anonymised event ..." and no notice, and writes nothing (no spool, no salt, no marker)' ($d1.Code -eq 0 -and $d1.Out -match '(?m)^telemetry   : on \(the default\) - after the commit ONE anonymised event' -and (Count-Notice $d1.Out) -eq 0 -and $nothing) ((($d1.Out -split "`n") | Where-Object { $_ -like 'telemetry*' }) -join ' | ')
    $d2 = Consult $r $h $dead 't' @('-DryRun', '-Prompt', 'x', '-Telemetry', 'off')
    $d3 = Consult $r $h $dead 't' @('-DryRun', '-Prompt', 'x') -Switch 'off'
    Check 'DRYRUN' 'the dry run says off: "telemetry   : off (-Telemetry) - nothing is spooled or sent", "off (CODEX_CONSULT_TELEMETRY)" with the variable' ($d2.Code -eq 0 -and $d2.Out -match '(?m)^telemetry   : off \(-Telemetry\) - nothing is spooled or sent' -and $d3.Out -match '(?m)^telemetry   : off \(CODEX_CONSULT_TELEMETRY\)') ((($d2.Out + "`n" + $d3.Out) -split "`n" | Where-Object { $_ -like 'telemetry*' }) -join ' | ')
    $bad = Consult $r $h $dead 't' @('-DryRun', '-Prompt', 'x', '-Telemetry', 'maybe')
    Check 'DRYRUN' '-Telemetry maybe is refused before anything starts (exit 1, "-Telemetry must be on or off")' ($bad.Code -eq 1 -and $bad.First -match '-Telemetry must be on or off') $bad.First
    $t0 = Get-Date
    $n1 = Consult $r $h $dead 't' @('-Prompt', 'x', '-ReplyName', 'n1') -Env @{ FAKE_CODEX_REPLY = $reply }
    $marker = Join-Path $h "telemetry-notice-$version"
    Check 'NOTICE' "the FIRST real run after the install prints the five-line notice (what is sent, what never is, the switch, -Complain, the terms and the README section) and writes the marker telemetry-notice-$version" ($n1.Code -eq 0 -and (Count-Notice $n1.Out) -eq 5 -and (Test-Path -LiteralPath $marker)) "notice lines $(Count-Notice $n1.Out)"
    $null = Wait-Last $h $t0
    $t1 = Get-Date
    $n2 = Consult $r $h $dead 't' @('-Prompt', 'x', '-ReplyName', 'n2') -Env @{ FAKE_CODEX_REPLY = $reply }
    Check 'NOTICE' 'the second run prints no notice (once per version)' ($n2.Code -eq 0 -and (Count-Notice $n2.Out) -eq 0) "notice lines $(Count-Notice $n2.Out)"
    $null = Wait-Last $h $t1
}

# =============================================================== SEND: the detached sender delivers and deletes, without the host markers
if (Want 'SEND') {
    $in = Start-Intake
    try {
        $h = New-Home 'send'
        $r = New-Repo 'send'
        $dump = Join-Path $work 'sender-env.txt'
        $markers = @{ CLAUDE_CODE_MESSAGING_SOCKET = 'fake-socket-28'; CLAUDE_CODE_MESSAGING_TOKEN = 'tok-28-dummy'; CODEX_THREAD_ID = '01a0e4bc-0000-7000-8000-000000000028'; ZCODE_SESSION_ID = 'zs-28-dummy'; CLAUDECODE = '1' }
        $envs = @{ FAKE_CODEX_REPLY = $reply; CODEX_CONSULT_TEST_TELEMETRY_ENV = $dump }
        foreach ($k in $markers.Keys) { $envs[$k] = $markers[$k] }
        $t0 = Get-Date
        $w = [System.Diagnostics.Stopwatch]::StartNew()
        $run = Consult $r $h $in.Url 't' @('-Prompt', 'x', '-ReplyName', 's1') -Env $envs
        $runSec = $w.Elapsed.TotalSeconds
        $reqs = Serve-Intake $in -Count 1 -TimeoutSec 60
        $delivered = Wait-Last $h $t0
        $body = $null; try { $body = ConvertFrom-Json $reqs[0].Body } catch { }
        $ev = $(if ($body) { @($body.events)[0] } else { $null })
        Check 'SEND' 'after a usable run the DETACHED sender (the run did not wait for it) POSTs to <intake>/v2/events: ONE request, application/json, {"events":[<the event>]} with this home''s instance id, allowlist clean' ($run.Code -eq 0 -and $reqs.Count -eq 1 -and $reqs[0].Method -eq 'POST' -and $reqs[0].Path -eq '/T/v2/events' -and $reqs[0].Type -like 'application/json*' -and @($body.events).Count -eq 1 -and $ev -and (Test-EventAllowlist $ev).Count -eq 0 -and $ev.details.outcome -eq 'usable') "run $([Math]::Round($runSec, 1)) s; $($reqs.Count) request(s) $(if ($reqs.Count) { "$($reqs[0].Method) $($reqs[0].Path)" })"
        Check 'SEND' 'delivered ({"ok":true}) = deleted: the spool holds no line afterwards; .last {time, result "delivered 1, kept 0, dropped 0 ...", delivered 1, kept 0, dropped 0, (wave 28b) rejected [], http 200}' ($delivered -and (Spool-Lines $h).Count -eq 0 -and (Last $h).delivered -eq 1 -and (Last $h).kept -eq 0 -and (Last $h).http -eq 200 -and ([string](Last $h).result) -like 'delivered 1, kept 0, dropped 0*' -and (Names (Last $h)) -eq 'time,result,delivered,kept,dropped,rejected,http') "$((Last $h).result)"
        $dumpText = Text $dump
        $dumpNames = @($dumpText -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        # (PSExecutionPolicyPreference: PowerShell sets it in its own process for -ExecutionPolicy Bypass)
        $notAllowed = @($dumpNames | Where-Object { -not (Test-TelemetrySenderEnvName -Name $_ -TestMode $true) -and $_ -ne 'PSExecutionPolicyPreference' })
        $markerHits = @($dumpNames | Where-Object { Test-HostMarkerName $_ })
        Check 'ENV' 'the sender starts WITHOUT the coordinator''s host markers (the bridge ran with CLAUDE_CODE_MESSAGING_SOCKET/TOKEN, CODEX_THREAD_ID, ZCODE_SESSION_ID, CLAUDECODE) and - wave 28b, D3 - with the ALLOW-LISTED environment only: its own dump (CODEX_CONSULT_TEST_TELEMETRY_ENV, every variable NAME) holds no marker, no provider key (RT_ZAI_KEY), no CODEX_CONSULT_ROSTER, nothing outside the allow list; it has CODEX_HOME and CODEX_CONSULT_TELEMETRY_URL' ((Test-Path -LiteralPath $dump) -and $dumpNames.Count -gt 0 -and $markerHits.Count -eq 0 -and $notAllowed.Count -eq 0 -and $dumpNames -notcontains 'RT_ZAI_KEY' -and $dumpNames -notcontains 'CODEX_CONSULT_ROSTER' -and $dumpNames -contains 'CODEX_HOME' -and $dumpNames -contains 'CODEX_CONSULT_TELEMETRY_URL') "names: [$($dumpNames -join ',')] not allowed: [$($notAllowed -join ',')]"
    } finally { Stop-Intake $in }
}

# =============================================================== R429 / NONJSON / DROP / LOCK / BATCH: the flush against scripted answers
if (Want 'FLUSH') {
    $body1 = '{"app_id":"codex-consult","n":1}'
    # 429 with Retry-After 2, then ok
    $in = Start-Intake
    try {
        $h = New-Home 'r429'
        Seed-Line $h 'event' $body1
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 429; Type = 'application/json'; Body = '{"ok":false,"error":"rate"}'; Headers = @{ 'Retry-After' = '2' } }, $answerOk) -Count 2 -TimeoutSec 60 -Proc $s.Proc
        $x = Wait-Script $s
        $gap = $(if ($reqs.Count -eq 2) { $reqs[1].At - $reqs[0].At } else { -1 })
        Check 'R429' 'a 429 with Retry-After: 2 is respected: the SAME request is sent once more after >= 2 s, delivered (exit 0), the spool emptied' ($x.Code -eq 0 -and $reqs.Count -eq 2 -and $gap -ge 1.9 -and $gap -lt 15 -and $reqs[0].Body -eq $reqs[1].Body -and $reqs[0].Body -eq ('{"events":[' + $body1 + ']}') -and (Spool-Lines $h).Count -eq 0) "exit $($x.Code), $($reqs.Count) request(s), gap $([Math]::Round($gap, 2)) s | $($x.Out)"
        $h = New-Home 'r429long'
        Seed-Line $h 'event' $body1
        $before = Spool-Bytes $h
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 429; Type = 'application/json'; Body = '{"ok":false}'; Headers = @{ 'Retry-After' = '120' } }) -Count 2 -TimeoutSec 20 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'R429' 'a 429 with Retry-After: 120 (more than 60 s) is NOT waited for: one request, not delivered (exit 1), the spool byte-identical, .last names the 429' ($x.Code -eq 1 -and $reqs.Count -eq 1 -and (Spool-Bytes $h) -eq $before -and ([string](Last $h).result) -match '429' -and (Last $h).http -eq 429) "exit $($x.Code), $($reqs.Count) request(s) | $((Last $h).result)"
        # non-JSON answers
        foreach ($ans in @(@{ Status = 200; Type = 'text/html'; Body = '<html><body>T</body></html>' }, @{ Status = 404; Type = 'text/html'; Body = '<html>not found</html>' }, @{ Status = 200; Type = 'application/json'; Body = '{"ok":false}' })) {
            $h = New-Home ('nonjson' + $ans.Status + $ans.Type.Length)
            Seed-Line $h 'event' $body1
            $before = Spool-Bytes $h
            $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
            $reqs = Serve-Intake $in -Answers @($ans) -Count 1 -TimeoutSec 30 -Proc $s.Proc
            $x = Wait-Script $s
            Check 'NONJSON' "an answer that is not the intake's JSON ok (HTTP $($ans.Status) $($ans.Type) $($ans.Body.Substring(0, [Math]::Min(12, $ans.Body.Length)))): not delivered (exit 1), the spool byte-identical, one line in .last - no other complaint" ($x.Code -eq 1 -and $reqs.Count -eq 1 -and (Spool-Bytes $h) -eq $before -and ([string](Last $h).result) -like 'not delivered: HTTP*' -and @($x.Out -split "`n" | Where-Object { $_.Trim() }).Count -eq 1) "exit $($x.Code) | $((Last $h).result)"
        }
        # the 7-day drop and an unreadable line
        $h = New-Home 'drop'
        Seed-Line $h 'event' '{"app_id":"codex-consult","n":"old"}' -Queued ([DateTimeOffset]::UtcNow.AddDays(-8).ToUnixTimeSeconds())
        Seed-Line $h 'event' $body1
        Seed-Line $h '' '' -Raw 'this is not a spool line'
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Count 2 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'DROP' 'lines older than 7 days (and a line that is no spool line) are DROPPED, not sent: one request with the fresh event only, the spool emptied, .last dropped 2' ($x.Code -eq 0 -and $reqs.Count -eq 1 -and $reqs[0].Body -eq ('{"events":[' + $body1 + ']}') -and (Spool-Lines $h).Count -eq 0 -and (Last $h).dropped -eq 2 -and (Last $h).delivered -eq 1) "exit $($x.Code), $($reqs.Count) request(s) | $((Last $h).result)"
        # the lock
        $h = New-Home 'lock'
        Seed-Line $h 'event' $body1
        $before = Spool-Bytes $h
        $lockFs = New-Object System.IO.FileStream((Join-Path (Join-Path $h 'telemetry-spool') '.flush.lock'), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        try {
            $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
            $reqs = Serve-Intake $in -Count 1 -TimeoutSec 20 -Proc $s.Proc
            $x = Wait-Script $s
        } finally { $lockFs.Dispose() }
        Check 'LOCK' 'a concurrent sender is refused by the lock (<spool>/.flush.lock held): exit 2 "another flush is running", no request, the spool byte-identical' ($x.Code -eq 2 -and $x.Out -match 'another flush is running' -and $reqs.Count -eq 0 -and (Spool-Bytes $h) -eq $before) "exit $($x.Code) | $($x.Out)"
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Count 1 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'LOCK' 'the lock released: the next flush delivers (exit 0, one request, spool emptied)' ($x.Code -eq 0 -and $reqs.Count -eq 1 -and (Spool-Lines $h).Count -eq 0) "exit $($x.Code), $($reqs.Count)"
        # batches of at most 100
        $h = New-Home 'batch'
        $d = Join-Path $h 'telemetry-spool'
        [void][IO.Directory]::CreateDirectory($d)
        $q = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $many = @(for ($i = 1; $i -le 150; $i++) { ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ v = 1; kind = 'event'; queued_unix = $q; body = ('{"app_id":"codex-consult","n":' + $i + '}') }) })
        [IO.File]::WriteAllText((Join-Path $d ([DateTime]::UtcNow.ToString('yyyy-MM-dd') + '.ndjson')), (($many -join "`n") + "`n"), $u8)
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Count 3 -TimeoutSec 40 -Proc $s.Proc
        $x = Wait-Script $s
        $sizes = @($reqs | ForEach-Object { @((ConvertFrom-Json $_.Body).events).Count })
        Check 'BATCH' '150 spooled events go in batches of at most 100: two POSTs of 100 and 50 events, oldest first, the spool emptied' ($x.Code -eq 0 -and ($sizes -join ',') -eq '100,50' -and (@((ConvertFrom-Json $reqs[0].Body).events)[0].n -eq 1) -and (Spool-Lines $h).Count -eq 0) "exit $($x.Code), batches $($sizes -join ',')"
        # (wave 28b, D8) the intake as it is built: 400 "events[i]: reason", 413, 403, another 4xx
        $seedN = { param([string]$H, [int]$N) for ($i = 1; $i -le $N; $i++) { Seed-Line $H 'event' ('{"app_id":"codex-consult","n":' + $i + '}') } }
        $ns = { param($Req) @(@((ConvertFrom-Json $Req.Body).events) | ForEach-Object { $_.n }) -join '+' }
        $h = New-Home 'r400'
        & $seedN $h 3
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 400; Type = 'application/json'; Body = '{"ok":false,"error":"events[1]: title longer than 200 characters"}' }, $answerOk) -Count 3 -TimeoutSec 40 -Proc $s.Proc
        $x = Wait-Script $s
        $lr = Last $h
        Check 'D8' 'a batch refused with 400 "events[1]: <reason>": event 1 is DROPPED (one line in .last rejected naming the reason), the rest resent at once (1+2+3, then 1+3), delivered (exit 0), the spool emptied' ($x.Code -eq 0 -and $reqs.Count -eq 2 -and (& $ns $reqs[0]) -eq '1+2+3' -and (& $ns $reqs[1]) -eq '1+3' -and (Spool-Lines $h).Count -eq 0 -and @($lr.rejected).Count -eq 1 -and ([string]@($lr.rejected)[0]) -match 'refused: title longer than 200 characters' -and $lr.delivered -eq 2) "exit $($x.Code), $(@($reqs | ForEach-Object { & $ns $_ }) -join ' | ') | $($lr.result)"
        $h = New-Home 'r400x4'
        & $seedN $h 5
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 400; Type = 'application/json'; Body = '{"ok":false,"error":"events[0]: bad severity"}' }) -Count 5 -TimeoutSec 40 -Proc $s.Proc
        $x = Wait-Script $s
        $lr = Last $h
        Check 'D8' 'at most THREE refused events per flush: a fourth 400 stops the flush (exit 1, "a fourth refused event"), 3 lines rejected, the other 2 events kept in the spool' ($x.Code -eq 1 -and $reqs.Count -eq 4 -and @($lr.rejected).Count -eq 3 -and (Spool-Lines $h).Count -eq 2 -and ([string]$lr.result) -match 'a fourth refused event') "exit $($x.Code), $($reqs.Count) request(s) | $($lr.result)"
        $h = New-Home 'r413'
        & $seedN $h 4
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 413; Type = 'application/json'; Body = '{"ok":false,"error":"body too large"}' }, $answerOk) -Count 4 -TimeoutSec 40 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'D8' '413: the batch is HALVED - 1+2+3+4 refused, then 1+2 and 3+4 delivered (exit 0, the spool emptied)' ($x.Code -eq 0 -and $reqs.Count -eq 3 -and (@($reqs | ForEach-Object { & $ns $_ }) -join ' | ') -eq '1+2+3+4 | 1+2 | 3+4' -and (Spool-Lines $h).Count -eq 0) "exit $($x.Code), $(@($reqs | ForEach-Object { & $ns $_ }) -join ' | ')"
        foreach ($ans in @(@{ Status = 403; Body = '{"ok":false,"error":"unknown app_id"}'; Want = 'HTTP 403 - the intake refuses this app' }, @{ Status = 404; Body = '{"ok":false,"error":"no such route"}'; Want = 'HTTP 404: no such route - the spool is kept' })) {
            $h = New-Home "r$($ans.Status)"
            & $seedN $h 2
            $before = Spool-Bytes $h
            $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
            $reqs = Serve-Intake $in -Answers @(@{ Status = $ans.Status; Type = 'application/json'; Body = $ans.Body }) -Count 3 -TimeoutSec 30 -Proc $s.Proc
            $x = Wait-Script $s
            Check 'D8' "HTTP $($ans.Status): the flush stops at once (one request, exit 1), the spool byte-identical, .last says why (`"$($ans.Want)`")" ($x.Code -eq 1 -and $reqs.Count -eq 1 -and (Spool-Bytes $h) -eq $before -and ([string](Last $h).result).Contains($ans.Want)) "exit $($x.Code), $($reqs.Count) | $((Last $h).result)"
        }
        # (wave 28b, D2 / F36-2) the deadline: ONE request bounded as a whole (test hook: 2 s)
        $h = New-Home 'slow'
        & $seedN $h 1
        $before = Spool-Bytes $h
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on' -Env @{ CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS = '2000' }
        $reqs = Serve-Intake $in -Answers @(@{ Status = 200; Type = 'application/json'; Body = '{"ok":true}'; DelayMs = 6000 }) -Count 1 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        $bound = $(if ($reqs.Count -eq 1) { try { ($s.Proc.ExitTime - $reqs[0].When).TotalSeconds } catch { 99 } } else { 99 })
        Check 'D2' 'an intake that answers only after 6 s: the request is cut at its bound (test hook 2 s; 8 s by default) - the sender exits within ~2 s of the request (not after the answer), exit 1 "no answer within 2 s", the spool byte-identical' ($x.Code -eq 1 -and $reqs.Count -eq 1 -and $bound -lt 4 -and ([string](Last $h).result) -match 'no answer within 2 s' -and (Spool-Bytes $h) -eq $before) "exit $($x.Code), exited $([Math]::Round($bound, 1)) s after the request | $((Last $h).result)"
        # the whole flush (test hooks: flush 3 s, request 2 s): three complaints answered after 1.2 s each
        $h = New-Home 'deadline'
        for ($i = 1; $i -le 3; $i++) { Seed-Line $h 'complaint' ('{"text":"c' + $i + '"}') }
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on' -Env @{ CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS = '2000'; CODEX_CONSULT_TEST_TELEMETRY_FLUSH_MS = '3000' }
        $reqs = Serve-Intake $in -Answers @(@{ Status = 200; Type = 'application/json'; Body = '{"ok":true,"public_ref":"x"}'; DelayMs = 1200 }) -Count 3 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        $span = $(if ($reqs.Count -ge 1) { try { ($s.Proc.ExitTime - $reqs[0].When).TotalSeconds } catch { 99 } } else { 99 })
        Check 'D2' 'the WHOLE flush has a deadline (test hook 3 s; 60 s by default): three complaints answered after 1.2 s each - the flush ends within the deadline (exit 1, "deadline ... was reached" or a request cut at what was left), what was not sent stays in the spool' ($x.Code -eq 1 -and $span -lt 5 -and ([string](Last $h).result) -match 'deadline \(3 s\) was reached|no answer within' -and (Spool-Lines $h).Count -ge 1 -and (Spool-Lines $h).Count -le 2) "exit $($x.Code), $($reqs.Count) request(s), ended $([Math]::Round($span, 1)) s after the first | $((Last $h).result)"
        # the lock: a live owner refuses, an old lock and a dead owner's are taken over
        $h = New-Home 'lock2'
        & $seedN $h 1
        $lockP = Join-Path (Join-Path $h 'telemetry-spool') '.flush.lock'
        [IO.File]::WriteAllText($lockP, (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ pid = $PID; start_time = [string](Get-ProcessStartIso -ProcessId $PID); token = 'harness'; since = (Get-IsoTimestamp) })), $u8)
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Count 1 -TimeoutSec 15 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'D2' 'a lock file whose owner is ALIVE and younger than 5 minutes (not held open): refused, exit 2 "another flush is running (pid <n> holds its lock", no request, the lock file left as it was' ($x.Code -eq 2 -and $x.Out -match 'another flush is running \(pid \d+ holds its lock' -and $reqs.Count -eq 0 -and (Text $lockP) -match '"token":"harness"') "exit $($x.Code) | $($x.Out)"
        [IO.File]::SetLastWriteTimeUtc($lockP, [DateTime]::UtcNow.AddMinutes(-6))
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Count 1 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'D2' 'the same lock 6 minutes old: TAKEN OVER - delivered (exit 0), .last "a stale sender lock was taken over: older than 5 minutes", the lock released afterwards (no file)' ($x.Code -eq 0 -and $reqs.Count -eq 1 -and ([string](Last $h).result) -match 'taken over: older than 5 minutes' -and -not (Test-Path -LiteralPath $lockP)) "exit $($x.Code) | $((Last $h).result)"
        & $seedN $h 1
        [IO.File]::WriteAllText($lockP, '{"pid":999999,"start_time":"2000-01-01T00:00:00.0000000Z","token":"gone","since":"2000-01-01T00:00:00Z"}', $u8)
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Count 1 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'D2' 'a fresh lock whose owner process is gone: taken over at once (exit 0, "its owner pid 999999 is gone")' ($x.Code -eq 0 -and $reqs.Count -eq 1 -and ([string](Last $h).result) -match 'its owner pid 999999 is gone') "exit $($x.Code) | $((Last $h).result)"
        # the refused URL and the switch
        $h = New-Home 'url'
        Seed-Line $h 'event' $body1
        $before = Spool-Bytes $h
        $s = Start-Script $telemetryPs @('-Flush') $work $h 'http://intake.example.invalid/T' 'on'
        $x = Wait-Script $s
        Check 'URL' 'CODEX_CONSULT_TELEMETRY_URL with plain http to another host: the flush refuses before any connection (exit 1, .last "not delivered: the intake URL ... is refused: only https ..."), the spool byte-identical' ($x.Code -eq 1 -and ([string](Last $h).result) -match 'is refused: only https' -and (Spool-Bytes $h) -eq $before) "exit $($x.Code) | $((Last $h).result)"
        $h = New-Home 'flushoff'
        Seed-Line $h 'event' $body1
        $before = Spool-Bytes $h
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'off'
        $reqs = Serve-Intake $in -Count 1 -TimeoutSec 8 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'URL' '-Flush with telemetry off (CODEX_CONSULT_TELEMETRY=off) sends nothing: exit 0 "telemetry is off", no request, the spool and .last untouched' ($x.Code -eq 0 -and $x.Out -match 'telemetry is off' -and $reqs.Count -eq 0 -and (Spool-Bytes $h) -eq $before -and -not (Last $h)) "exit $($x.Code) | $($x.Out)"
    } finally { Stop-Intake $in }
}

# =============================================================== COMPLAIN: the payload printed, confirmed, sent; kept when not delivered
if (Want 'COMPLAIN') {
    $in = Start-Intake
    try {
        $dead = Get-DeadUrl
        $h = New-Home 'complain'
        $r = New-Repo 'complain'
        $seed = Consult $r $h $dead $taskName @('-Purpose', 'checkpoint', '-Prompt', $promptSecret, '-ReplyName', 'c0') -Switch 'off' -Env @{ FAKE_CODEX_REPLY = $reply }
        $text = 'The panel summary hides which member timed out.'
        $s = Start-Script $consultPs @('-Task', $taskName, '-Complain', $text, '-Contact', 'ops@example.com', '-Yes') $r $h $in.Url 'off'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 200; Type = 'application/json'; Body = '{"ok":true,"complaint_id":7,"public_ref":"CC-7Q"}' }) -Count 1 -TimeoutSec 60 -Proc $s.Proc
        $x = Wait-Script $s
        $cb = $null; try { $cb = ConvertFrom-Json $reqs[0].Body } catch { }
        $printed = ''
        if ($x.Out -match '(?s)exactly this JSON goes to [^\n]*\n(\{.*?\n\})') { $printed = $Matches[1] }
        Check 'COMPLAIN' '-Task <t> -Complain "<text>" -Contact <c> -Yes (telemetry off - a complaint is an explicit send): ONE POST to <intake>/v2/complaints, exit 0, "complaint delivered - public_ref CC-7Q"' ($seed.Code -eq 0 -and $x.Code -eq 0 -and $reqs.Count -eq 1 -and $reqs[0].Path -eq '/T/v2/complaints' -and $x.Out -match 'complaint delivered - public_ref CC-7Q') "exit $($x.Code), $($reqs.Count) request(s) | $(($x.Out -split "`n")[-1])"
        Check 'COMPLAIN' 'the payload printed in full is EXACTLY the body sent' ($printed -and (($printed -replace "`r`n", "`n").Trim()) -eq (($reqs[0].Body -replace "`r`n", "`n").Trim())) "$($printed.Length) vs $(if ($reqs.Count) { $reqs[0].Body.Length })"
        $ctx = $(if ($cb) { $cb.context } else { $null })
        $cons = $(if ($ctx) { $ctx.consultation } else { $null })
        $cleaks = @(); if ($cb) { $cleaks = Find-Leaks (Get-Leaves $ctx) @($taskName, 'secret', 'handoffs') }
        Check 'COMPLAIN' 'the payload: {app_id, app_version, instance_id, text, context {consultation - the task''s last entry through THE allowlist, bridge_version, os, runtime}, contact}; the context carries no task name, prompt, path or name' ($cb -and (Names $cb) -eq 'app_id,app_version,instance_id,text,context,contact' -and $cb.text -eq $text -and $cb.contact -eq 'ops@example.com' -and (Names $ctx) -eq 'consultation,bridge_version,os,runtime' -and (Names $cons) -eq $detailKeys -and $cons.outcome -eq 'usable' -and $cons.findings.major -eq 1 -and $cb.instance_id -cmatch '^[0-9a-f]{64}$' -and $cleaks.Count -eq 0) "$(if ($cb) { Names $cb }) | $($cleaks -join ' || ')"
        # no confirmation: stdin says n
        $s = Start-Script $consultPs @('-Task', $taskName, '-Complain', $text) $r $h $in.Url 'off' -Stdin "n`n"
        $reqs = Serve-Intake $in -Count 1 -TimeoutSec 10 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'COMPLAIN' 'without -Yes it asks "send? [y/N]": answered n - not sent (exit 1), no request, nothing spooled' ($x.Code -eq 1 -and $x.Out -match 'send\? \[y/N\]' -and $x.Out -match 'not sent' -and $reqs.Count -eq 0 -and (Spool-Lines $h).Count -eq 0) "exit $($x.Code), $($reqs.Count) | $(($x.Out -split "`n")[-1])"
        $s = Start-Script $consultPs @('-Task', $taskName, '-Complain', $text) $r $h $in.Url 'off' -Stdin "y`n"
        $reqs = Serve-Intake $in -Answers @(@{ Status = 200; Type = 'application/json'; Body = '{"ok":true,"complaint_id":8,"public_ref":"CC-8R"}' }) -Count 1 -TimeoutSec 60 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'COMPLAIN' 'answered y - sent (exit 0, public_ref CC-8R)' ($x.Code -eq 0 -and $reqs.Count -eq 1 -and $x.Out -match 'public_ref CC-8R') "exit $($x.Code), $($reqs.Count)"
        # not delivered: kept in the spool as a complaint line, delivered by the next flush
        $s = Start-Script $consultPs @('-Task', $taskName, '-Complain', $text, '-Yes') $r $h $in.Url 'off'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 503; Type = 'text/plain'; Body = 'busy' }) -Count 1 -TimeoutSec 60 -Proc $s.Proc
        $x = Wait-Script $s
        $firstBody = $(if ($reqs.Count) { [string]$reqs[0].Body } else { '' })
        $cl = Spool-Lines $h
        $kept = $null; try { $kept = ConvertFrom-Json $cl[0] } catch { }
        $keptBody = $null; try { $keptBody = ConvertFrom-Json ([string]$kept.body) } catch { }
        Check 'COMPLAIN' 'not delivered (HTTP 503 text/plain): exit 3, "not delivered (...); kept in the spool as a complaint line", ONE spool line of kind complaint holding the same payload' ($x.Code -eq 3 -and $reqs.Count -eq 1 -and $x.Out -match 'kept in the spool as a complaint line' -and $cl.Count -eq 1 -and $kept.kind -eq 'complaint' -and $keptBody -and $keptBody.text -eq $text -and (Names $keptBody) -eq 'app_id,app_version,instance_id,text,context,contact') "exit $($x.Code) lines $($cl.Count) | $(($x.Out -split "`n")[-1])"
        $s = Start-Script $telemetryPs @('-Flush') $work $h $in.Url 'on'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 200; Type = 'application/json'; Body = '{"ok":true,"complaint_id":9,"public_ref":"CC-9S"}' }) -Count 1 -TimeoutSec 60 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'COMPLAIN' 'the sender retries the complaint line: POST <intake>/v2/complaints with the kept payload, delivered, the spool emptied' ($x.Code -eq 0 -and $reqs.Count -eq 1 -and $reqs[0].Path -eq '/T/v2/complaints' -and (ConvertFrom-Json $reqs[0].Body).text -eq $text -and (Spool-Lines $h).Count -eq 0) "exit $($x.Code), $($reqs.Count) $(if ($reqs.Count) { $reqs[0].Path })"
        # (wave 28b, D7 / F36-7, F37-5) shown = sent = deferred, byte for byte
        Check 'COMPLAIN' 'D7 the spool kept the EXACT text that was shown and sent at once (the 503 attempt''s body = the kept line''s body, whitespace and line ends included), and the deferred send posted those same bytes' ($firstBody -and $kept -and [string]$kept.body -ceq $firstBody -and $reqs.Count -eq 1 -and [string]$reqs[0].Body -ceq $firstBody -and $firstBody.Contains("`n")) "first $($firstBody.Length) kept $(if ($kept) { ([string]$kept.body).Length }) deferred $(if ($reqs.Count) { $reqs[0].Body.Length })"
        # limits and refusals (nothing sent: an unreachable intake anyway)
        $long = 'x' * 8193
        $s = Start-Script $consultPs @('-Task', $taskName, '-Complain', $long, '-Yes') $r $h $dead 'off'
        $x = Wait-Script $s
        $s2 = Start-Script $consultPs @('-Task', $taskName, '-Complain', $text, '-Prompt', 'x') $r $h $dead 'off'
        $x2 = Wait-Script $s2
        $s3 = Start-Script $consultPs @('-Task', $taskName, '-Contact', 'a@b') $r $h $dead 'off'
        $x3 = Wait-Script $s3
        Check 'COMPLAIN' 'refused, nothing sent or spooled: a text over 8 KiB ("8193 bytes ... at most 8192"), -Complain with another option ("-Complain takes only -Task, -CollabDir, -Contact and -Yes"), -Contact without -Complain' ($x.Code -eq 1 -and $x.Out -match '8193 bytes' -and $x2.Code -eq 1 -and $x2.Out -match '-Complain takes only' -and $x3.Code -eq 1 -and $x3.Out -match '-Contact and -Yes go with -Complain' -and (Spool-Lines $h).Count -eq 0) "$($x.Code)/$($x2.Code)/$($x3.Code)"
        # codex-telemetry.ps1 -Complain without a task: no consultation context
        $s = Start-Script $telemetryPs @('-Complain', $text, '-Yes') $work $h $in.Url 'off'
        $reqs = Serve-Intake $in -Answers @(@{ Status = 200; Type = 'application/json'; Body = '{"ok":true,"public_ref":"CC-10"}' }) -Count 1 -TimeoutSec 60 -Proc $s.Proc
        $x = Wait-Script $s
        $nb = $null; try { $nb = ConvertFrom-Json $reqs[0].Body } catch { }
        Check 'COMPLAIN' 'codex-telemetry.ps1 -Complain without -Task: context.consultation null, delivered (public_ref CC-10)' ($x.Code -eq 0 -and $nb -and $null -eq $nb.context.consultation -and $nb.context.bridge_version -eq $version -and $x.Out -match 'public_ref CC-10') "exit $($x.Code)"
    } finally { Stop-Intake $in }
}

# =============================================================== STATUS: codex-telemetry.ps1 -Status
if (Want 'STATUS') {
    $h = New-Home 'status'
    Seed-Line $h 'event' '{"a":1}'
    Seed-Line $h 'event' '{"a":2}'
    Seed-Line $h 'complaint' '{"text":"t"}'
    $env:CODEX_HOME = $h
    $iid = Get-TelemetryInstanceId -Create
    $env:CODEX_HOME = $savedCodexHome
    [IO.File]::WriteAllText((Join-Path (Join-Path $h 'telemetry-spool') '.last'), '{"time":"2026-09-29T10:00:00+02:00","result":"not delivered: HTTP 200 (text/html) is not the intake''s JSON answer - delivered 0, kept 3, dropped 0","delivered":0,"kept":3,"dropped":0,"http":200}', $u8)
    [IO.File]::WriteAllText((Join-Path $h "telemetry-notice-$version"), "x`n", $u8)
    $snap = (@(Get-ChildItem -LiteralPath $h -Recurse -Force -File | ForEach-Object { "$($_.FullName)=$($_.Length)=$($_.LastWriteTimeUtc.Ticks)" }) -join ';')
    $s = Start-Script $telemetryPs @('-Status') $work $h (Get-DeadUrl) ''
    $x = Wait-Script $s
    $snap2 = (@(Get-ChildItem -LiteralPath $h -Recurse -Force -File | ForEach-Object { "$($_.FullName)=$($_.Length)=$($_.LastWriteTimeUtc.Ticks)" }) -join ';')
    Check 'STATUS' '-Status: the switch and its source ("telemetry on (the default)"), the intake, the spool counts ("2 event(s), 1 complaint(s) in 1 file(s)"), the last flush''s result (the one line an undelivered intake gets), the instance id, the notice state; exit 0; nothing written' ($x.Code -eq 0 -and $x.Out -match 'telemetry on \(the default\)' -and $x.Out -match '(?m)^intake     : http://127\.0\.0\.1:\d+/T \(CODEX_CONSULT_TELEMETRY_URL\)' -and $x.Out -match '2 event\(s\), 1 complaint\(s\) in 1 file\(s\)' -and $x.Out -match '(?m)^last flush : .* - not delivered: HTTP 200 \(text/html\)' -and $x.Out.Contains("instance id: $iid") -and $x.Out -match "(?m)^notice     : shown for $([regex]::Escape($version))" -and $snap -eq $snap2) $x.Out
    $h2 = New-Home 'status-empty'
    $s = Start-Script $telemetryPs @('-Status') $work $h2 (Get-DeadUrl) 'off'
    $x = Wait-Script $s
    Check 'STATUS' '-Status in a fresh home with telemetry off: "telemetry off (CODEX_CONSULT_TELEMETRY)", 0 events, last flush never, no instance id yet, the notice not shown; creates no salt' ($x.Code -eq 0 -and $x.Out -match 'telemetry off \(CODEX_CONSULT_TELEMETRY\)' -and $x.Out -match '0 event\(s\), 0 complaint\(s\) in 0 file\(s\)' -and $x.Out -match '(?m)^last flush : never' -and $x.Out -match 'none yet' -and $x.Out -match 'not shown yet' -and -not (Test-Path -LiteralPath (Join-Path $h2 'telemetry-salt'))) $x.Out
    $s = Start-Script $telemetryPs @() $work $h2 (Get-DeadUrl) 'off'
    $x = Wait-Script $s
    Check 'STATUS' 'codex-telemetry.ps1 without a form is refused (exit 1: "give exactly one of -Flush, -Status, -Complain")' ($x.Code -eq 1 -and $x.Out -match 'give exactly one of -Flush, -Status, -Complain') $x.Out
}

# =============================================================== FORGET: delete my data (wave 28b, D9)
if (Want 'FORGET') {
    $in = Start-Intake
    try {
        $h = New-Home 'forget'
        Seed-Line $h 'event' '{"a":1}'
        $env:CODEX_HOME = $h
        $iid = Get-TelemetryInstanceId -Create
        $env:CODEX_HOME = $savedCodexHome
        $s = Start-Script $telemetryPs @('-Forget', '-PublicRef', 'CC-7Q') $work $h $in.Url ''
        $reqs = Serve-Intake $in -Answers @(@{ Status = 200; Type = 'application/json'; Body = '{"ok":true,"deleted":3}' }) -Count 1 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'FORGET' 'D9 -Forget -PublicRef CC-7Q: ONE request DELETE <intake>/v2/instances/<this instance id>?public_ref=CC-7Q, exit 0 "the intake deleted the data of instance ...", the local spool and salt untouched' ($x.Code -eq 0 -and $reqs.Count -eq 1 -and $reqs[0].Method -eq 'DELETE' -and $reqs[0].Path -eq "/T/v2/instances/$iid" -and $reqs[0].Query -eq '?public_ref=CC-7Q' -and $x.Out -match 'the intake deleted the data of instance' -and (Spool-Lines $h).Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $h 'telemetry-salt'))) "exit $($x.Code), $(if ($reqs.Count) { "$($reqs[0].Method) $($reqs[0].Path)$($reqs[0].Query)" }) | $($x.Out)"
        $s = Start-Script $telemetryPs @('-Forget', '-PublicRef', 'CC-7Q') $work $h $in.Url ''
        $reqs = Serve-Intake $in -Answers @(@{ Status = 404; Type = 'application/json'; Body = '{"ok":false,"error":"unknown public_ref"}' }) -Count 1 -TimeoutSec 30 -Proc $s.Proc
        $x = Wait-Script $s
        Check 'FORGET' 'D9 an intake that does not confirm (404): exit 3 "the intake did not confirm the deletion (HTTP 404: unknown public_ref)"' ($x.Code -eq 3 -and $reqs.Count -eq 1 -and $x.Out -match 'did not confirm the deletion \(HTTP 404: unknown public_ref\)') "exit $($x.Code) | $($x.Out)"
        $s = Start-Script $telemetryPs @('-Forget', '-Local') $work $h (Get-DeadUrl) ''
        $x = Wait-Script $s
        $left = @(Get-ChildItem -LiteralPath $h -Force | Where-Object { $_.Name -like 'telemetry-s*' -or $_.Name -like 'telemetry-not*' } | ForEach-Object { $_.Name })
        Check 'FORGET' 'D9 -Forget -Local: the local spool (every file), the salt and the not-spooled count are removed - exit 0 "removed locally", nothing sent; the next event makes a new instance id' ($x.Code -eq 0 -and $x.Out -match 'removed locally - ' -and $left.Count -eq 0) "exit $($x.Code), left [$($left -join ',')] | $($x.Out)"
        $s1 = Start-Script $telemetryPs @('-Forget') $work $h (Get-DeadUrl) ''
        $x1 = Wait-Script $s1
        $s2 = Start-Script $telemetryPs @('-Forget', '-PublicRef', 'CC-7Q') $work $h $in.Url ''
        $r2 = Serve-Intake $in -Count 1 -TimeoutSec 8 -Proc $s2.Proc
        $x2 = Wait-Script $s2
        $s3 = Start-Script $telemetryPs @('-Status', '-Local') $work $h (Get-DeadUrl) ''
        $x3 = Wait-Script $s3
        Check 'FORGET' 'D9 refusals, nothing sent: -Forget alone (exit 1, "needs -PublicRef <ref> ... -Local"), -Forget -PublicRef without a salt (exit 1, "no instance id", no request), -Local without -Forget (exit 1, "-Local goes with -Forget")' ($x1.Code -eq 1 -and $x1.Out -match 'needs -PublicRef <ref>' -and $x2.Code -eq 1 -and $x2.Out -match 'no instance id' -and $r2.Count -eq 0 -and $x3.Code -eq 1 -and $x3.Out -match '-Local goes with -Forget') "$($x1.Code)/$($x2.Code)/$($x3.Code)"
    } finally { Stop-Intake $in }
}

# =============================================================== HOOK: the SessionStart line says whether telemetry is on
if (Want 'HOOK') {
    $r = New-Repo 'hook'
    $bin = Join-Path $work 'bin'
    [void][IO.Directory]::CreateDirectory($bin)
    [IO.File]::WriteAllText((Join-Path $bin 'codex.cmd'), "@echo off`r`nset ""FAKE_CODEX_ARGS=%*""`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""$(Join-Path $sp 'fake-codex3.ps1')""`r`nexit /b %ERRORLEVEL%`r`n")
    $hh = New-Home 'hook'
    # (wave 27c, D13) the pointer line names the full command of this plugin's script
    $pointer = 'codex-consult: coordinator rules - skill codex-consult:coordinate (or powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $scripts 'codex-consult.ps1') + '" -Explain coordinate)'
    $lines = @{}
    foreach ($sw in @('', 'off', 'bogus')) {
        $savedPath = $env:Path
        $env:Path = "$bin;$savedPath"
        try { $s = Start-Script $hookPs @() $r $hh (Get-DeadUrl) $sw; $x = Wait-Script $s } finally { $env:Path = $savedPath }
        $lines[$(if ($sw) { $sw } else { 'unset' })] = @(($x.Out -split "`n") | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })
    }
    Check 'HOOK' 'the SessionStart hook''s pointer line ends with the switch: "; telemetry: on" (unset), "; telemetry: off" (off, and a value that is not on or off); still two lines, exit 0' ($lines['unset'].Count -eq 2 -and $lines['unset'][1] -ceq "$pointer; telemetry: on" -and $lines['off'][1] -ceq "$pointer; telemetry: off" -and $lines['bogus'][1] -ceq "$pointer; telemetry: off") (($lines['unset'] + $lines['off']) -join ' || ')
}

# =============================================================== DOCS: README, skills, manifest, the other harnesses
if (Want 'DOCS') {
    $readme = Text (Join-Path $repoRoot 'README.md')
    $sec = ''
    if ($readme -match '(?s)\n## Telemetry \(on by default\)\r?\n(.*?)\n## ') { $sec = $Matches[1] }
    $missing = @(foreach ($k in (@($eventKeys -split ',') + @($detailKeys -split ',') + @('installing this plugin means accepting these terms', 'CODEX_CONSULT_TELEMETRY=off', '-Telemetry off', 'telemetry-spool', 'telemetry-salt', '-Complain', 'public_ref', 'codex-telemetry.ps1 -Status', 'codex-telemetry.ps1 -Flush', 'instance_id', 'CODEX_CONSULT_TELEMETRY_URL', '7 days', '429', 'codex-telemetry.ps1 -Forget -PublicRef', '-Forget -Local', 'the intake is live', 'vendor class', '`openai`', '`zai`', '`xiaomi`', '`byteplus`', '`moonshot`', '`alibaba`', '`google`', '`meta`', '`other`', 'CODEX_CONSULT_TEST_MODE=1', '60 s', '8 s', 'events[i]', '413', '403', 'not spooled', '5 minutes'))) { if ($sec.IndexOf($k, [StringComparison]::OrdinalIgnoreCase) -lt 0) { $k } })
    Check 'DOCS' 'README "## Telemetry (on by default)": the terms line, the exact payload (every event and details key), the switch, the spool, the salt, the sender, -Complain and public_ref, -Status, the URL override, the 7-day drop, the 429 rule; (wave 28b) the live intake and delete-my-data (-Forget -PublicRef, -Forget -Local), the vendor table with every class, the http rule of test mode, the 60 s / 8 s bounds and the 5-minute lock, the D8 answers (events[i], 413, 403), the not-spooled warning' ($sec -and $missing.Count -eq 0) "missing: $($missing -join ', ')"
    Check 'DOCS' 'README tables: the options (-Telemetry, -Complain), the environment (CODEX_CONSULT_TELEMETRY, CODEX_CONSULT_TELEMETRY_URL) and "Tests" names harness-telemetry' ($readme -match '\| `-Telemetry on\\\|off`' -and $readme -match '\| `-Complain ' -and $readme -match '\| `CODEX_CONSULT_TELEMETRY` \|' -and $readme -match '\| `CODEX_CONSULT_TELEMETRY_URL` \|' -and $readme -match 'harness-telemetry') ''
    $cs = Text (Join-Path $pluginDir 'skills\consult-codex\SKILL.md')
    $ss = Text (Join-Path $pluginDir 'skills\setup-providers\SKILL.md')
    $pj = ConvertFrom-Json (Text (Join-Path $pluginDir '.claude-plugin\plugin.json'))
    Check 'DOCS' 'the consult-codex and setup-providers skills name the telemetry and its switch (CODEX_CONSULT_TELEMETRY=off); the plugin manifest''s description mentions the opt-out telemetry' ($cs.Contains('CODEX_CONSULT_TELEMETRY=off') -and $ss.Contains('CODEX_CONSULT_TELEMETRY=off') -and [string]$pj.description -match 'telemetry' -and [string]$pj.description -match 'opt-out|CODEX_CONSULT_TELEMETRY=off') ''
    $others = @(Get-ChildItem -LiteralPath $sp -Filter 'harness-*.ps1' | Where-Object { $_.Name -ne 'harness-telemetry.ps1' -and -not ((Text $_.FullName) -match "(?m)^\`$env:CODEX_CONSULT_TELEMETRY = 'off'$") } | ForEach-Object { $_.Name })
    $runAll = Text (Join-Path $sp 'run-all.ps1')
    Check 'DOCS' 'every OTHER harness sets CODEX_CONSULT_TELEMETRY=off at its top, and run-all.ps1 sets it (and an unreachable intake URL) for its children and registers harness-telemetry' ($others.Count -eq 0 -and $runAll -match "(?m)^\`$env:CODEX_CONSULT_TELEMETRY = 'off'$" -and $runAll -match "(?m)^\`$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127\.0\.0\.1:9/'$" -and $runAll -match "'harness-telemetry'") "without: $($others -join ', ')"
}

} finally {
    Restore-Env
    $env:CODEX_CONSULT_TELEMETRY = 'off'
    # the senders the cases started are gone after their .last; a short grace before the cleanup
    Start-Sleep -Milliseconds 500
    Remove-TestWork $work
}
Write-Host ''
Check 'GUARD' 'the operator''s real codex home got no telemetry file from this harness (its telemetry* names compared before and after, read only)' ((& $realTelemetry) -eq $realBefore) "before [$realBefore] after [$(& $realTelemetry)]"
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
Write-Host ("harness-telemetry ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
