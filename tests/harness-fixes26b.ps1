# codex-consult wave 26b (0.5.0; decisions D1-D14 of the wave 26 acceptance,
# .collab/companions-2026-09-26/handoffs/23-claude-wave26-acceptance-decisions.md): a role file
# contained in its roles directory (no symlink or junction on the way, D1); the reduced panel size
# said (size_asked, the warning, the summary's `asked`, D2); roster strings without the matcher's and
# the seed's delimiters and the length-prefixed seed (D3); the exact role matching (D4); the lab
# reserve over the seats left after the pins, routing.reserve (D5 - and the same seats as before);
# the legacy rating join (D6); the UNIQ location keys (D7); -Kick (a foreground and a detached panel,
# the refusals; D10); the roster's timeout_sec (D11); the stall cut (-StallSec, the roster's
# stall_sec, D12); the machine-wide endpoint health file (a 429 of one repository honoured by the
# roster walk of another; a member running in one repository counted against the endpoint's
# parallel limit in the other; pruning; D13). D9 (the write-disabled tree check) is covered in
# harness-muse.ps1 (TREE), where the muse sign-in fakes live. (wave 26c, decisions D1-D5 of
# handoffs/27-claude-wave26c-decisions.md) KICKACK the kick acknowledged (late, before the loop,
# -Kick exit 3 and 1, a kick of the format repair only), HEALTHLOCK the stored until and the lock
# timeout's retry and warning, STALLTOOL the stall cut outside tool calls and on byte growth,
# JOINBLANK a legacy rating's empty fields, SIZERAISE the size raised by required reviewers.
# FAKES ONLY: fake-codex3.cmd;
# CODEX_HOME, CODEX_CONSULT_ROSTER and CODEX_CONSULT_HEALTH point at scratch files (the machine-wide
# health file is 'none' unless a case names a scratch file of its own); the API key variables hold
# dummy test values. Runs under the host it is started with (powershell 5.1 or pwsh 7, Windows).
# Work files: $env:TEMP\codex-consult-tests\harness-fixes26b\<guid>, removed at the end.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
$env:CODEX_CONSULT_HEALTH = 'none'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$scoreboardPs = Join-Path $scripts 'codex-scoreboard.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-fixes26b') ([guid]::NewGuid().ToString('N'))
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
$realHealth = Join-Path (Join-Path $HOME '.codex') 'codex-consult-health.json'
$savedCodexHome = $env:CODEX_HOME
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
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
# The scratch Codex config (as in harness-companions): openai built in, ZAI (RT_ZAI_KEY), mimo
# (RT_MIMO_KEY), byteplus and alibaba (their roster entries say auth none).
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.mimo]`nbase_url = `"https://token-plan-ams.xiaomimimo.com/v1`"`nenv_key = `"RT_MIMO_KEY`"`nwire_api = `"responses`"`n`n[model_providers.byteplus]`nbase_url = `"https://ark.ap-southeast.bytepluses.com/api/coding/v3`"`nwire_api = `"responses`"`n`n[model_providers.alibaba]`nbase_url = `"https://token-plan-intl.dashscope.aliyuncs.com/compatible-mode/v1`"`nwire_api = `"responses`"`n"
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_FAIL_ON', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_HANG_NEW', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_REPLY_MAP', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_ITEMS', 'FAKE_CODEX_RESUME_REPLY', 'FAKE_CODEX_STDERR', 'FAKE_CODEX_EXIT', 'FAKE_CODEX_FAIL_EVENT', 'FAKE_CODEX_TOOL_OPEN', 'FAKE_CODEX_DRIP', 'FAKE_CODEX_RESUME_LOG')
$testVars = @('RT_ZAI_KEY', 'RT_MIMO_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_PANEL_SEED', 'CODEX_CONSULT_TEST_PANEL_GUARD_SEC', 'CODEX_CONSULT_TEST_HEALTH_LOCK_SEC')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
    $env:CODEX_CONSULT_HEALTH = 'none'
}
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:RT_MIMO_KEY = 'mimo-test-key'
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome }
function Get-Previews {
    param([string]$Text)
    $list = New-Object System.Collections.Generic.List[object]
    $mark = 'sessions.json entry preview:'
    $at = $Text.IndexOf($mark)
    while ($at -ge 0) {
        $rest = $Text.Substring($at + $mark.Length)
        $next = $rest.IndexOf($mark)
        $chunk = $(if ($next -ge 0) { $rest.Substring(0, $next) } else { $rest })
        $lines = New-Object System.Collections.Generic.List[string]
        $depth = 0
        $started = $false
        foreach ($l in ($chunk -split "`n")) {
            $t = $l.TrimEnd("`r")
            if (-not $started) { if ($t.Trim() -eq '{') { $started = $true } else { continue } }
            $lines.Add($t)
            $depth += ([regex]::Matches($t, '[\{\[]')).Count - ([regex]::Matches($t, '[\}\]]')).Count
            if ($started -and $depth -le 0) { break }
        }
        try { $list.Add((($lines.ToArray() -join "`n") | ConvertFrom-Json)) } catch { $list.Add($null) }
        $at = $(if ($next -ge 0) { $at + $mark.Length + $next } else { -1 })
    }
    return , ($list.ToArray())
}
# One bridge call: { Code; Out; First; Previews }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task t -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Previews = (Get-Previews $text) }
}
# A bridge call in the BACKGROUND (the harness acts meanwhile): { Proc; OutPath; ErrPath }
function Start-Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [string]$Name = 'bg')
    Set-CaseEnv $Roster $Env
    $outP = Join-Path $work "$Name-$([guid]::NewGuid().ToString('N').Substring(0, 6)).out"
    $errP = "$outP.err"
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-CodexExe', $fake) + @($ArgList)
    $argText = (@($all | ForEach-Object { if ([string]$_ -match '[\s"]' -or [string]$_ -eq '') { '"' + ([string]$_ -replace '"', '\"') + '"' } else { [string]$_ } }) -join ' ')
    $proc = Start-Process -FilePath $psExe -ArgumentList $argText -WorkingDirectory $Repo -NoNewWindow -PassThru -RedirectStandardOutput $outP -RedirectStandardError $errP
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $proc.Handle } catch { } }
    Restore-Env
    return [pscustomobject]@{ Proc = $proc; OutPath = $outP; ErrPath = $errP }
}
function Wait-Consult {
    param($Bg, [int]$Sec = 120)
    $done = $Bg.Proc.WaitForExit($Sec * 1000)
    if (-not $done) { try { $null = Stop-ProcessTree -Process $Bg.Proc } catch { } }
    $text = ''
    foreach ($f in @($Bg.OutPath, $Bg.ErrPath)) { if (Test-Path -LiteralPath $f) { $text += [IO.File]::ReadAllText($f) } }
    $code = $(if ($done) { $Bg.Proc.ExitCode } else { -99 })
    return [pscustomobject]@{ Code = $code; Out = $text; Done = $done }
}
# Waits until a recovery record of the task says `running` (a member's .consult.pending-<NN>.json,
# or the single run's .consult.pending.json); $true when it did within $Sec.
function Wait-Running {
    param([string]$Repo, [string]$Name, [int]$Sec = 40)
    $f = Join-Path $Repo ".collab\t\$Name"
    $w = [Diagnostics.Stopwatch]::StartNew()
    while ($w.Elapsed.TotalSeconds -lt $Sec) {
        try { if ((Test-Path -LiteralPath $f) -and ([IO.File]::ReadAllText($f) | ConvertFrom-Json).state -eq 'running') { return $true } } catch { }
        Start-Sleep -Milliseconds 250
    }
    return $false
}
function Run-Tool {
    param([string]$Script, [string]$Repo, [string[]]$ArgList, [string]$Roster = '', [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
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
function Ledger { param([string]$Repo, [string]$TaskName = 't') $f = Join-Path $Repo ".collab\$TaskName\sessions.json"; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Iso { param($Dto) return ([DateTimeOffset]$Dto).ToString('yyyy-MM-ddTHH:mm:sszzz', $inv) }
function Guid-Of { param([int]$K) return ('00000000-0000-4000-8000-{0:D12}' -f $K) }
function Picks { param($Routing) return (@($Routing.picked | ForEach-Object { "$($_.position)/$($_.rule)" }) -join ' ') }
function Same-Path { param($A, [string]$B) return ([string]$A).Replace('/', '\').TrimEnd('\') -ieq $B.Replace('/', '\').TrimEnd('\') }
function Line { param([string]$Text, [string]$Prefix) return @(($Text -split "`n") | Where-Object { $_.StartsWith($Prefix) }) | Select-Object -First 1 }
function MkLink {
    param([string]$Opt, [string]$Link, [string]$Target)
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $null = & cmd /c "mklink $Opt `"$Link`" `"$Target`" >nul 2>&1"
    $ErrorActionPreference = $p
    return (Test-Path -LiteralPath $Link)
}
function Rt {
    param([string]$Provider, [string]$Model, [string]$Useful, [string]$Purpose = 'framing', [int]$N = 1)
    $script:ridSeq++
    return [pscustomobject][ordered]@{ n = $N; consult_id = (Guid-Of (900000 + $script:ridSeq)); lineage = (Format-ReviewerLineage -Provider $Provider -Model $Model); provider = $Provider; model = $Model; engine = 'codex'; purpose = $Purpose; topics = [object[]]@(); consult_when = (Iso ([DateTimeOffset]::Now.AddDays(-1))); useful = $Useful; note = ''; when = (Iso ([DateTimeOffset]::Now)) }
}
$script:ridSeq = 0
function Seed-Store {
    param([string]$Repo, [string]$TaskName, [object[]]$Ratings = @(), [object[]]$Findings = @(), [object[]]$Entries = $null)
    $dir = Join-Path $Repo ".collab\$TaskName"
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'findings.json') -Object ([pscustomobject]@{ task_id = $TaskName; findings = [object[]]@($Findings); ratings = [object[]]@($Ratings) })
    if ($null -ne $Entries) { Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = $TaskName; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } }) }
}

$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$roster2 = Write-Roster 'two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'
$roster5 = Write-Roster 'five' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro"},{"provider":"byteplus","model":"kimi-k2.5","auth":"none"},{"provider":"alibaba","model":"qwen3.8-max","auth":"none"}]}'
$zaiFp = Get-Sha256Hex ($u8.GetBytes('cc-provider-v1|base_url=https://api.z.ai/api/v1|wire_api=responses'))

try {
# =============================================================== D1: the role file stays inside its roles directory
if (Want 'ROLEFILE') {
    $r = New-Repo 'rolefile'
    $outside = Join-Path $work 'outside-roles'
    [void][IO.Directory]::CreateDirectory($outside)
    [IO.File]::WriteAllText((Join-Path $outside 'leak.md'), 'SECRET TEXT OF ANOTHER DIRECTORY', $u8)
    [IO.File]::WriteAllText((Join-Path $outside 'security.md'), 'SECRET SECURITY ROLE OUTSIDE', $u8)
    $roles = Join-Path $r '.collab\roles'
    [void][IO.Directory]::CreateDirectory($roles)
    # a symbolic link to a file outside - when this account may create one; else (no privilege) a
    # directory junction named like a role file (the decision's fallback)
    $linkKind = 'symlink'
    if (-not (MkLink '' (Join-Path $roles 'leak.md') (Join-Path $outside 'leak.md'))) { $linkKind = 'junction'; $null = MkLink '/J' (Join-Path $roles 'leak.md') $outside }
    $log = Join-Path $work 'rolefile.log'
    $x = Consult $r '' @('-Prompt', 'x', '-Role', 'leak', '-ReplyName', 'lk') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log }
    $xd = Consult $r '' @('-Prompt', 'x', '-Role', 'leak', '-DryRun')
    $nothing = (-not (Test-Path (Join-Path $r '.collab\t\sessions.json'))) -and @(Get-ChildItem (Join-Path $r '.collab\t\handoffs')).Count -eq 0 -and (Get-PendingPaths -TaskDir (Join-Path $r '.collab\t')).Count -eq 0 -and -not (Test-Path $log)
    Check 'ROLEFILE' "D1 (F22-1): <CollabDir>/roles/leak.md is a $linkKind to a file outside the roles directory -> the run is refused before anything exists (exit 1, ""-Role: role file refused: ... reparse point ...""; no ledger, no handoff, no recovery record, no reviewer process); the dry run the same; the outside text never printed" ($x.Code -eq 1 -and $x.First -like 'codex-consult: -Role: role file refused: *' -and $x.First -match 'reparse point' -and $xd.Code -eq 1 -and $xd.First -eq $x.First -and $nothing -and $x.Out -notmatch 'SECRET TEXT') $x.First
    # the roles directory itself a junction: every role of it is refused - no fallback to the plugin's
    $r2 = New-Repo 'rolesjunction'
    $null = MkLink '/J' (Join-Path $r2 '.collab\roles') $outside
    $y = Consult $r2 '' @('-Prompt', 'x', '-Role', 'security', '-DryRun')
    $y2 = Consult $r2 $roster2 @('-Panel', '-PanelAll', '-Roles', 'security,tests', '-DryRun', '-Prompt', 'x')
    Check 'ROLEFILE' 'D1: a .collab/roles directory that is itself a junction (to a directory with security.md) refuses -Role security (not the plugin''s template instead): "the repository roles directory ... is a junction or symbolic link (reparse point)"; -Roles on a panel likewise, nothing started' ($y.Code -eq 1 -and $y.First -like 'codex-consult: -Role: role file refused: the repository roles directory *is a junction or symbolic link (reparse point)*' -and $y.Out -notmatch 'SECRET SECURITY' -and $y2.Code -eq 1 -and $y2.First -like 'codex-consult: -Roles: role file refused: the repository roles directory *') "$($y.First) | $($y2.First)"
    # in process: a path outside the root; the plugin's templates directory as a junction
    $why = Get-RoleFileProblem -Path (Join-Path $outside 'leak.md') -Root $roles
    $fakePlugin = Join-Path $work 'fake-plugin'
    [void][IO.Directory]::CreateDirectory($fakePlugin)
    $tplTarget = Join-Path $work 'tpl-target'
    [void][IO.Directory]::CreateDirectory($tplTarget)
    [IO.File]::WriteAllText((Join-Path $tplTarget 'role-docs.md'), 'docs role', $u8)
    $null = MkLink '/J' (Join-Path $fakePlugin 'templates') $tplTarget
    $pl = Resolve-RoleFile -Name 'docs' -CollabRoot (Join-Path $work 'no-collab') -PluginRoot $fakePlugin
    $ok = Resolve-RoleFile -Name 'docs' -CollabRoot (Join-Path $work 'no-collab') -PluginRoot (Split-Path -Parent $scripts)
    Check 'ROLEFILE' 'D1: a file outside the roles directory is refused ("... is outside ..."); the plugin''s templates/role-<name>.md likewise inside the plugin''s templates directory (a templates junction refused); the shipped template still resolves' ($why -like "*is outside*" -and $pl.Error -like 'role file refused: the plugin roles directory *' -and -not $ok.Error -and $ok.Source -eq 'plugin') "$why | $($pl.Error) | $($ok.Source)"
}

# =============================================================== D2: the reduced size is said
if (Want 'SIZE') {
    $r = New-Repo 'size'
    $d = Consult $r $roster2 @('-Panel', '-Purpose', 'acceptance', '-DryRun', '-Prompt', 'x')
    $pv = @($d.Previews)[0]
    Check 'SIZE' 'D2 (F19-1): an acceptance panel (size 4) over 2 eligible entries warns "panel size reduced: asked 4, eligible 2" (console; the ledger preview''s warnings[]); panel.routing.size_asked 4 beside size 2; panel.asked 4 (the request, not the clamp)' ($d.Code -eq 0 -and $d.Out -match '(?m)^WARNING: panel size reduced: asked 4, eligible 2$' -and $pv.panel.routing.size_asked -eq 4 -and $pv.panel.routing.size -eq 2 -and $pv.panel.asked -eq 4 -and @($pv.warnings | Where-Object { $_ -eq 'panel size reduced: asked 4, eligible 2' }).Count -eq 1) "$($pv.panel.routing.size_asked)/$($pv.panel.routing.size) asked $($pv.panel.asked)"
    $x = Consult $r $roster2 @('-Panel', '-Purpose', 'acceptance', '-Prompt', 'x', '-ReplyName', 'sz') @{ FAKE_CODEX_REPLY = $advise }
    $led = @(Ledger $r)
    $sum = [regex]::Matches($x.Out, '(?m)^Panel [0-9a-f]{8}: .*$')
    $hand = [IO.File]::ReadAllText((Join-Path $r '.collab\t\handoffs\01-codex-sz-openai.md'), $u8)
    Check 'SIZE' 'D2: the real run - the summary says "2 of 2 entries ran (asked 4, started 2, usable 2; ...)"; every member''s ledger warnings[] and handoff header carry the warning; panel.asked 4, routing.size_asked 4' ($x.Code -eq 0 -and $sum.Count -gt 0 -and $sum[$sum.Count - 1].Value -match '^Panel [0-9a-f]{8}: 2 of 2 entries ran \(asked 4, started 2, usable 2; ' -and $led.Count -eq 2 -and @($led | Where-Object { @($_.warnings) -contains 'panel size reduced: asked 4, eligible 2' -and $_.panel.asked -eq 4 -and $_.panel.routing.size_asked -eq 4 }).Count -eq 2 -and $hand -match 'Warnings: .*panel size reduced: asked 4, eligible 2') "$(if ($sum.Count -gt 0) { $sum[$sum.Count - 1].Value })"
    $f = Consult $r $roster2 @('-Panel', '-PanelSize', '2', '-DryRun', '-Prompt', 'x')
    Check 'SIZE' 'D2: a size the eligible set fills warns nothing (-PanelSize 2 over 2)' ($f.Code -eq 0 -and $f.Out -notmatch 'panel size reduced') ''
}

# =============================================================== D3: roster strings and the length-prefixed seed
if (Want 'SEED') {
    $bad = New-Object System.Collections.Generic.List[string]
    $cases = @(
        @('provider', 'a::b', "roster entry #1: provider must not contain '::'"),
        @('provider', 'a[b', "roster entry #1: provider must not contain '['"),
        @('provider', 'a#1', "roster entry #1: provider must not contain '#'"),
        @('model', 'glm|5', "roster entry #1: model must not contain '|'"),
        @('model', 'glm,5', "roster entry #1: model must not contain ','"),
        @('model', 'glm]5', "roster entry #1: model must not contain ']'"))
    foreach ($c in $cases) {
        $obj = [ordered]@{ provider = 'ZAI'; model = 'glm-5.3' }
        $obj[$c[0]] = $c[1]
        $p = Write-Roster 'bad-seed' (ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{ roster_version = 1; reviewers = @([pscustomobject]$obj) }))
        $res = Read-ReviewerRoster ([pscustomobject]@{ Path = $p; FromEnv = $true; Disabled = $false })
        if (-not ([string]$res.Error).Contains(": $($c[2]). Fix it")) { $bad.Add("$($c[1]) -> $($res.Error)") }
    }
    $pBlank = Write-Roster 'bad-blank' '{"roster_version":1,"reviewers":[{"provider":"ZAI ","model":"glm-5.3"}]}'
    $resBlank = Read-ReviewerRoster ([pscustomobject]@{ Path = $pBlank; FromEnv = $true; Disabled = $false })
    Check 'SEED' 'D3 (F22-2): the roster validator refuses a provider label or model with ''::'', ''['', '']'', ''|'', '','' or ''#'' ("roster entry #1: provider must not contain ''::''") and one with surrounding blanks' ($bad.Count -eq 0 -and $resBlank.Error -like '*surrounding blanks*') ($bad.ToArray() -join ' ; ')
    $s1 = Get-PanelSeed -Task 't' -Purpose 'p' -BriefSha '' -Lineages @('a,b') -Nonce 'n'
    $s2 = Get-PanelSeed -Task 't' -Purpose 'p' -BriefSha '' -Lineages @('a', 'b') -Nonce 'n'
    $s3 = Get-PanelSeed -Task 'x|y' -Purpose 'z' -BriefSha '' -Lineages @('l') -Nonce 'n'
    $s4 = Get-PanelSeed -Task 'x' -Purpose 'y|z' -BriefSha '' -Lineages @('l') -Nonce 'n'
    Check 'SEED' 'D3 (F22-4): the seed text length-prefixes every field and every lineage ("1:t|1:p|0:|3:1:l|1:n"), so joins that collided before no longer do (lineages "a,b" vs "a","b"; task "x|y" + purpose "z" vs "x" + "y|z")' ($s1.Hex -ne $s2.Hex -and $s3.Hex -ne $s4.Hex -and (Get-PanelSeed -Task 't' -Purpose 'p' -BriefSha '' -Lineages @('l') -Nonce 'n').Text -eq '1:t|1:p|0:|3:1:l|1:n' -and $s1.Text -eq '1:t|1:p|0:|5:3:a,b|1:n' -and $s2.Text -eq '1:t|1:p|0:|7:1:a,1:b|1:n') "$($s1.Text) vs $($s2.Text) | $($s3.Text) vs $($s4.Text)"
}

# =============================================================== D4: the exact role matching
if (Want 'ROLES') {
    $mm = { param([int]$Pos, [string[]]$Willing, [double]$Score) [pscustomobject]@{ Entry = [pscustomobject]@{ Position = $Pos; Roles = [string[]]$Willing }; Score = [pscustomobject]@{ Score = $Score } } }
    $a1 = Select-RoleAssignment -Members @((& $mm 1 @('a', 'b') 2.0), (& $mm 2 @('a') 1.0)) -Roles @('a', 'b')
    $a2 = Select-RoleAssignment -Members @((& $mm 1 @('a', 'b') 2.0), (& $mm 2 @() 1.0)) -Roles @('a', 'b')
    $a3 = Select-RoleAssignment -Members @((& $mm 1 @() 2.0), (& $mm 2 @() 1.5), (& $mm 3 @() 1.0)) -Roles @('x', 'y')
    $a4 = Select-RoleAssignment -Members @((& $mm 1 @('s') 2.0), (& $mm 2 @() 1.0)) -Roles @('d', 's')
    $a5 = Select-RoleAssignment -Members @((& $mm 1 @('a', 'b', 'c') 2.0), (& $mm 2 @('a', 'b') 1.8), (& $mm 3 @('a') 1.5), (& $mm 4 @() 1.0)) -Roles @('a', 'b', 'c', 'd')
    Check 'ROLES' 'D4 (F22-3): the exact matching - m1 (willing a,b; best) and m2 (willing a): roles a,b -> m2 a, m1 b (every willingness honoured; the greedy pass gave m1 a and forced b onto unwilling m2); nobody declares -> the rank order (x to #1, y to #2); an undeclared role before a declared one leaves the willing member for it (d -> #2, s -> #1); four roles over a chain of willingness (c #1, b #2, a #3, d #4)' ($a1.Of[2] -eq 'a' -and $a1.Of[1] -eq 'b' -and -not $a1.Note -and $a3.Of[1] -eq 'x' -and $a3.Of[2] -eq 'y' -and -not $a3.Of.ContainsKey(3) -and $a4.Of[1] -eq 's' -and $a4.Of[2] -eq 'd' -and $a5.Of[1] -eq 'c' -and $a5.Of[2] -eq 'b' -and $a5.Of[3] -eq 'a' -and $a5.Of[4] -eq 'd' -and -not $a5.Note) "a1 #1=$($a1.Of[1]) #2=$($a1.Of[2]); a4 #1=$($a4.Of[1]) #2=$($a4.Of[2]); a5 $(@(1..4 | ForEach-Object { "#$_=$($a5.Of[$_])" }) -join ' ')"
    Check 'ROLES' 'D4: no assignment honours every willingness (a and b both only by #1) -> the greedy rank order (a -> #1, b -> #2) and the note "roles: no assignment gives every role a willing member (a: willing #1; b: willing #1) - the roles went by score rank, ..."' ($a2.Of[1] -eq 'a' -and $a2.Of[2] -eq 'b' -and $a2.Note -like 'roles: no assignment gives every role a willing member (a: willing #1; b: willing #1) - the roles went by score rank*') $a2.Note
    $rr = New-Repo 'roles'
    $rolesR = Write-Roster 'roles' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","roles":["security","tests"]},{"provider":"ZAI","model":"glm-5.3"}]}'
    $e1 = Consult $rr $rolesR @('-Panel', '-PanelAll', '-Roles', 'security,tests', '-DryRun', '-Prompt', 'x')
    $pvs = @($e1.Previews)
    Check 'ROLES' 'D4 end to end: -Roles security,tests where only #1 is willing (for both) -> the greedy order, said: WARNING "roles: no assignment ..." on the console, ledger panel.roles_note and warnings[] of every member' ($e1.Code -eq 0 -and $e1.Out -match '(?m)^WARNING: roles: no assignment gives every role a willing member' -and $pvs.Count -eq 2 -and @($pvs | Where-Object { $_.panel.roles_note -like 'roles: no assignment*' -and @($_.warnings | Where-Object { $_ -like 'roles: no assignment*' }).Count -eq 1 }).Count -eq 2) "$(@($pvs | ForEach-Object { "$($_.lineage)=$($_.role)" }) -join ', ')"
}

# =============================================================== D5: the reserve after the pins; the same seats as before
if (Want 'RESERVE') {
    # the wave 26 formulation (reserve = min(K, good labs), counted over every seated lab)
    $oldDraw = {
        param([object[]]$Candidates, [int]$K, [byte[]]$Seed)
        $neutral = 0.25 + 1.75 * 0.5
        $seats = New-Object System.Collections.Generic.List[object]
        $left = New-Object System.Collections.Generic.List[object]
        foreach ($c in $Candidates) { if ($c.Pinned) { $seats.Add([pscustomobject]@{ Slot = $seats.Count + 1; Candidate = $c; Rule = 'required' }) } else { $left.Add($c) } }
        $goodLabs = @(@($Candidates | Where-Object { [double]$_.Weight -ge $neutral }) | ForEach-Object { [string]$_.Lab } | Select-Object -Unique)
        $reserve = [Math]::Min($K, $goodLabs.Count)
        while ($seats.Count -lt $K -and $left.Count -gt 0) {
            $slot = $seats.Count + 1
            $seatedLabs = @($seats | ForEach-Object { [string]$_.Candidate.Lab } | Select-Object -Unique)
            $covered = @($seatedLabs | Where-Object { $goodLabs -contains $_ }).Count
            $pool = @(); $kind = 'rank'
            if ($covered -lt $reserve) { $pool = @($left | Where-Object { $seatedLabs -notcontains [string]$_.Lab -and [double]$_.Weight -ge $neutral }); if ($pool.Count -gt 0) { $kind = 'lab' } }
            if ($pool.Count -eq 0) { $pool = @($left.ToArray()); $kind = 'rank' }
            $u = Get-SlotUniforms -Seed $Seed -Slot $slot
            $winner = $null
            if ($u.Explore -lt 0.2) { $idx = [int][Math]::Floor($u.Pick * $pool.Count); if ($idx -ge $pool.Count) { $idx = $pool.Count - 1 }; $winner = $pool[$idx]; $rule = "$kind-explore" }
            else { $total = 0.0; foreach ($c in $pool) { $total += [double]$c.Weight }; $target = $u.Pick * $total; $acc = 0.0; foreach ($c in $pool) { $acc += [double]$c.Weight; if ($target -lt $acc) { $winner = $c; break } }; if ($null -eq $winner) { $winner = $pool[$pool.Count - 1] }; $rule = "$kind-draw" }
            $seats.Add([pscustomobject]@{ Slot = $slot; Candidate = $winner; Rule = $rule })
            [void]$left.Remove($winner)
        }
        return , ([object[]]$seats.ToArray())
    }
    $cd = { param([int]$P, [string]$L, [double]$W, [bool]$Pin = $false) [pscustomobject]@{ Position = $P; Lab = $L; Weight = $W; Pinned = $Pin } }
    $sets = @(
        @(@((& $cd 1 'a' 2.0 $true), (& $cd 2 'a' 1.9), (& $cd 3 'b' 1.5), (& $cd 4 'c' 1.3), (& $cd 5 'd' 0.6)), 3),
        @(@((& $cd 1 'a' 0.4 $true), (& $cd 2 'b' 1.2 $true), (& $cd 3 'b' 1.9), (& $cd 4 'c' 1.3), (& $cd 5 'e' 1.125)), 4),
        @(@((& $cd 1 'x' 1.125), (& $cd 2 'y' 2.0), (& $cd 3 'y' 1.6), (& $cd 4 'z' 0.3)), 2))
    $diff = 0
    foreach ($set in $sets) {
        for ($n = 1; $n -le 120; $n++) {
            $sd = (Get-PanelSeed -Task 't' -Purpose 'decision' -BriefSha '' -Lineages @('x') -Nonce "$n").Bytes
            $new = (@(Invoke-PanelDraw -Candidates $set[0] -K $set[1] -Seed $sd) | ForEach-Object { "$($_.Candidate.Position)/$($_.Rule)" }) -join ' '
            $old = (@(& $oldDraw $set[0] $set[1] $sd) | ForEach-Object { "$($_.Candidate.Position)/$($_.Rule)" }) -join ' '
            if ($new -ne $old) { $diff++ }
        }
    }
    $p1 = Invoke-PanelDraw -Candidates $sets[0][0] -K 3 -Seed (Get-PanelSeed -Task 't' -Purpose 'x' -BriefSha '' -Lineages @('x') -Nonce '1').Bytes
    Check 'RESERVE' 'D5 (F22-5): the reserve is defined over the seats LEFT after the pins - min(K - the pinned, labs >= neutral the pins did not seat): a pinned a-entry and K=3 over labs a, b, c (d below neutral) -> required, then two lab seats (b and c, never a again, never d); and the draw is unchanged: 3 candidate sets x 120 seeds seat exactly what the wave 26 formulation seated' ($diff -eq 0 -and $p1[0].Rule -eq 'required' -and @($p1 | Where-Object { $_.Rule -like 'lab-*' }).Count -eq 2 -and (@($p1[1..2] | ForEach-Object { $_.Candidate.Lab } | Sort-Object) -join ',') -eq 'b,c') "differences $diff; $(@($p1 | ForEach-Object { "$($_.Candidate.Position)/$($_.Rule)" }) -join ' ')"
    $r = New-Repo 'reserve'
    $ratings = @()
    for ($i = 1; $i -le 4; $i++) { $ratings += (Rt 'ZAI' 'glm-5.3' 'yes' -N $i) }
    for ($i = 5; $i -le 7; $i++) { $ratings += (Rt 'mimo' 'mimo-v2.6-pro' 'no' -N $i) }
    for ($i = 8; $i -le 10; $i++) { $ratings += (Rt 'byteplus' 'kimi-k2.5' 'yes' -N $i) }
    Seed-Store $r 'rated' -Ratings $ratings
    $d1 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-PanelSeed', '15', '-DryRun', '-Prompt', 'x')
    $rt1 = @($d1.Previews)[0].panel.routing
    $d2 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-PanelSeed', '15', '-Require', '#2', '-DryRun', '-Prompt', 'x')
    $rt2 = @($d2.Previews)[0].panel.routing
    Check 'RESERVE' 'D5: panel.routing.reserve records the reserve seats applied - a routed framing panel over five labs: every seat a lab seat (reserve 3 = the lab-* rules); with #2 required (pinned first): the reserve counts only the seats after it (= its lab-* rules, at most 2)' ($d1.Code -eq 0 -and $rt1.reserve -eq @($rt1.picked | Where-Object { $_.rule -like 'lab-*' }).Count -and $rt1.reserve -eq 3 -and $d2.Code -eq 0 -and $rt2.picked[0].rule -eq 'required' -and $rt2.reserve -eq @($rt2.picked | Where-Object { $_.rule -like 'lab-*' }).Count -and $rt2.reserve -le 2) "$(Picks $rt1) reserve $($rt1.reserve) | $(Picks $rt2) reserve $($rt2.reserve)"
}

# =============================================================== D6: the legacy rating join
if (Want 'JOIN') {
    $r = New-Repo 'join'
    $cid = Guid-Of 777001
    $entry = [pscustomobject]@{ n = 1; when = (Iso ([DateTimeOffset]::Now.AddDays(-2))); purpose = 'framing'; topics = [object[]]@('security'); consult_id = $cid; reviewer = [pscustomobject]@{ provider = 'ZAI'; model = 'glm-5.3'; engine = 'codex'; provider_fingerprint = $zaiFp }; bridge_outcome = 'usable reply' }
    $rating = [pscustomobject]@{ n = 1; consult_id = $cid; provider = 'ZAI'; useful = 'yes'; note = ''; when = (Iso ([DateTimeOffset]::Now)) }
    Seed-Store $r 'legacy' -Ratings @($rating) -Entries @($entry)
    $all = @(Read-AllTaskRatings -CollabRoot (Join-Path $r '.collab'))
    Check 'JOIN' 'D6 (F22-6): a rating with a provider (and a consult_id) but no model, purpose, engine, topics or consult_when is completed from its consultation - model glm-5.3, purpose framing, engine codex, topics [security], consult_when = the entry''s when' ($all.Count -eq 1 -and $all[0].Model -eq 'glm-5.3' -and $all[0].Purpose -eq 'framing' -and $all[0].Engine -eq 'codex' -and (@($all[0].Topics) -join ',') -eq 'security' -and $null -ne $all[0].ConsultWhen -and $all[0].ConsultWhen -lt [DateTimeOffset]::Now.AddDays(-1)) "$($all[0].Lineage) $($all[0].Purpose) $($all[0].ConsultWhen)"
}

# =============================================================== D7: UNIQ location keys
if (Want 'UNIQ') {
    $rb = New-Repo 'uniq'
    $pid1 = 'aaaaaaaa-0000-4000-8000-000000000026'
    $now = [DateTimeOffset]::Now.AddHours(-2)
    $mkE = { param([int]$N, [string]$Prov, [string]$Model, [int]$Pos) [pscustomobject]@{ n = $N; when = (Iso $now); purpose = 'framing'; topics = [object[]]@(); consult_id = (Guid-Of (700000 + $N)); reviewer = [pscustomobject]@{ provider = $Prov; model = $Model; engine = 'codex'; provider_fingerprint = 'x' }; panel = [pscustomobject]@{ id = $pid1; position = $Pos; of = 2 }; thread = ''; bridge_outcome = 'usable reply'; wall_seconds = 3; usage = $null } }
    $fd = { param([string]$Id, [int]$N, [string]$Path, $Line) [pscustomobject]@{ id = $Id; status = 'proposed'; severity = 'minor'; claim = 'c'; locations = [object[]]@([pscustomobject]@{ path = $Path; line = $Line }); source = [pscustomobject]@{ consult = $N }; history = [object[]]@(); reviewer_checks = [object[]]@() } }
    Seed-Store $rb 'b' -Entries @((& $mkE 1 'ZAI' 'glm-5.3' 1), (& $mkE 2 'mimo' 'mimo-v2.6-pro' 2)) -Findings @((& $fd 'F01-1' 1 'src\App.txt' 3), (& $fd 'F01-2' 1 'src/app.txt' 4), (& $fd 'F02-1' 2 './src//app.txt' 3))
    $sj = Run-Tool $scoreboardPs $rb @('-Json')
    $jr = @(); try { $jr = @(($sj.Out | ConvertFrom-Json) | ForEach-Object { $_ }) } catch { }
    $zt = @($jr | Where-Object { $_.lineage -eq 'ZAI :: glm-5.3' -and $_.purpose -eq '(total)' })[0]
    $mt = @($jr | Where-Object { $_.lineage -eq 'mimo :: mimo-v2.6-pro' -and $_.purpose -eq '(total)' })[0]
    Check 'UNIQ' 'D7 (F22-7): location keys are compared after normalising (\ vs /, a leading ./, doubled separators, case on Windows; the line exact) - "src\App.txt:3" and "./src//app.txt:3" are one location (neither unique), "src/app.txt:4" is: ZAI 1 unique of 2, mimo 0 of 1' ($sj.Code -eq 0 -and $zt.unique -eq 1 -and $zt.panel_raised -eq 2 -and $mt.unique -eq 0 -and $mt.panel_raised -eq 1) "ZAI $($zt.unique)/$($zt.panel_raised) mimo $($mt.unique)/$($mt.panel_raised) $($sj.First)"
}

# =============================================================== D11: the roster entry's timeout_sec
if (Want 'TIMEOUT') {
    $r = New-Repo 'timeout'
    $tr = Write-Roster 'timeout' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3","timeout_sec":120}]}'
    $d = Consult $r $tr @('-Panel', '-PanelAll', '-Purpose', 'checkpoint', '-DryRun', '-Prompt', 'x')
    $pvs = @($d.Previews)
    $pz = @($pvs | Where-Object { $_.reviewer.provider -eq 'ZAI' })[0]
    $po = @($pvs | Where-Object { $_.reviewer.provider -eq 'openai' })[0]
    Check 'TIMEOUT' 'D11: a roster entry''s timeout_sec replaces the purpose default for that member - "Timeout: 900 s per member (the default of purpose checkpoint); #2 ZAI :: glm-5.3 120 s (roster); ..."; ZAI timeout_sec 120, timeout_source roster, continue_sec 120 (follows it); openai 900 purpose 900' ($d.Code -eq 0 -and $d.Out -match '(?m)^Timeout: 900 s per member \(the default of purpose checkpoint\); #2 ZAI :: glm-5\.3 120 s \(roster\); continuation after a timeout kill: up to 900 s on the same thread$' -and $pz.timeout_sec -eq 120 -and $pz.timeout_source -eq 'roster' -and $pz.continue_sec -eq 120 -and $po.timeout_sec -eq 900 -and $po.timeout_source -eq 'purpose' -and $po.continue_sec -eq 900) (Line $d.Out 'Timeout:')
    $e = Consult $r $tr @('-Panel', '-PanelAll', '-Purpose', 'checkpoint', '-TimeoutSec', '300', '-DryRun', '-Prompt', 'x')
    Check 'TIMEOUT' 'D11: an explicit -TimeoutSec still wins for all (300 explicit for both; no exception listed)' ($e.Code -eq 0 -and $e.Out -match '(?m)^Timeout: 300 s per member \(-TimeoutSec\); continuation' -and @(@($e.Previews) | Where-Object { $_.timeout_sec -eq 300 -and $_.timeout_source -eq 'explicit' }).Count -eq 2) (Line $e.Out 'Timeout:')
    $s = Consult $r $tr @('-Provider', 'ZAI', '-Purpose', 'checkpoint', '-DryRun', '-Prompt', 'x')
    $ps1 = @($s.Previews)[0]
    Check 'TIMEOUT' 'D11: a single run of that entry (-Provider ZAI) takes it too: timeout 120 s ("the roster entry''s timeout_sec"), timeout_source roster, roster.applied names timeout_sec' ($s.Code -eq 0 -and $ps1.timeout_sec -eq 120 -and $ps1.timeout_source -eq 'roster' -and @($ps1.roster.applied) -contains 'timeout_sec' -and $s.Out -match '(?m)^timeout     : 120 s \(the roster entry''s timeout_sec\)') (Line $s.Out 'timeout     :')
    $x = Consult $r $tr @('-Panel', '-PanelAll', '-Purpose', 'checkpoint', '-Prompt', 'x', '-ReplyName', 'to') @{ FAKE_CODEX_REPLY = $advise }
    $led = @(Ledger $r)
    $lz = @($led | Where-Object { $_.reviewer.provider -eq 'ZAI' })[0]
    Check 'TIMEOUT' 'D11: the real run records it - the ZAI member''s ledger timeout_sec 120, timeout_source roster; openai 900 purpose' ($x.Code -eq 0 -and $lz.timeout_sec -eq 120 -and $lz.timeout_source -eq 'roster' -and @($led | Where-Object { $_.reviewer.provider -eq 'openai' -and $_.timeout_sec -eq 900 -and $_.timeout_source -eq 'purpose' }).Count -eq 1) "$($lz.timeout_sec)/$($lz.timeout_source)"
    $bt = Write-Roster 'timeout-bad' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","timeout_sec":59}]}'
    $bs = Write-Roster 'stall-bad' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","stall_sec":"x"}]}'
    $v1 = Consult $r $bt @('-DryRun', '-Prompt', 'x')
    $v2 = Consult $r $bs @('-DryRun', '-Prompt', 'x')
    Check 'TIMEOUT' 'D11/D12: the roster refuses timeout_sec below 60 and a stall_sec that is no integer (fail-closed, exit 1)' ($v1.Code -eq 1 -and $v1.First -like '*entry 1: timeout_sec must be an integer from 60 to 86400*' -and $v2.Code -eq 1 -and $v2.First -like '*entry 1: stall_sec must be an integer from 0 (off) to 86400*') "$($v1.First) | $($v2.First)"
}

# =============================================================== D12: the stall cut
if (Want 'STALL') {
    $r = New-Repo 'stall'
    $w = [Diagnostics.Stopwatch]::StartNew()
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'st', '-StallSec', '3', '-TimeoutSec', '60') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_RESUME_REPLY = $advise }
    $wall = $w.Elapsed.TotalSeconds
    $e = @(Ledger $r)[-1]
    Check 'STALL' 'D12 (R18): the fake emits its first events and then hangs; -StallSec 3 -> stopped like a timeout after 3 s without an event (not the 60 s timeout): the continuation turn answers - "usable reply (after a timeout continuation)", ledger stall {seconds 3, last_event <iso>}, timeout_continue.outcome usable reply; the console says "stopped at ... (3 s without an event)"' ($x.Code -eq 0 -and $e.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $e.stall.seconds -eq 3 -and $null -ne $e.stall.last_event -and $e.timeout_continue.outcome -eq 'usable reply' -and $x.Out -match 'the main turn was stopped at [0-9.]+ s \(3 s without an event\); one continuation turn' -and $wall -lt 45) "$($e.bridge_outcome) stall $($e.stall | ConvertTo-Json -Compress) wall $([Math]::Round($wall, 1))"
    $y = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'st2', '-StallSec', '3', '-TimeoutSec', '60', '-ContinueSec', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_ITEMS = '1' }
    $ey = @(Ledger $r)[-1]
    $partial = $(if ($ey.partial_reply) { Join-Path $r ".collab\t\$($ey.partial_reply)" } else { '' })
    Check 'STALL' 'D12: without a continuation (-ContinueSec 0): "failed: stalled after 3 s without an event (process tree killed)", the salvage (.partial.md with the stream''s messages, "stopped at ... s: 3 s without an event"), ledger stall' ($y.Code -eq 1 -and $ey.bridge_outcome -eq 'failed: stalled after 3 s without an event (process tree killed)' -and $ey.stall.seconds -eq 3 -and $partial -and (Test-Path -LiteralPath $partial) -and ([IO.File]::ReadAllText($partial, $u8)) -match 'Q1 so far \(first turn\)' -and ([IO.File]::ReadAllText($partial, $u8)) -match '3 s without an event') "$($ey.bridge_outcome) partial $($ey.partial_reply)"
    $sr = Write-Roster 'stall' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","stall_sec":2}]}'
    $z = Consult $r $sr @('-Prompt', 'x', '-ReplyName', 'st3', '-TimeoutSec', '60', '-ContinueSec', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1' }
    $ez = @(Ledger $r)[-1]
    $o = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'st4', '-StallSec', '0', '-TimeoutSec', '5', '-ContinueSec', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1' }
    $eo = @(Ledger $r)[-1]
    $v = Consult $r '' @('-Prompt', 'x', '-StallSec', '-2', '-DryRun')
    Check 'STALL' 'D12: the roster entry''s stall_sec 2 applies without -StallSec ("stalled after 2 s", roster.applied stall_sec); -StallSec 0 = off (the 5 s timeout kills it: "failed: timeout after 5 s", stall null); -StallSec -2 refused' ($z.Code -eq 1 -and $ez.bridge_outcome -eq 'failed: stalled after 2 s without an event (process tree killed)' -and $ez.stall.seconds -eq 2 -and @($ez.roster.applied) -contains 'stall_sec' -and $o.Code -eq 1 -and $eo.bridge_outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $null -eq $eo.stall -and $v.Code -eq 1 -and $v.First -like '*-StallSec must be 0 (no stall cut) or a number of seconds*') "$($ez.bridge_outcome) | $($eo.bridge_outcome) | $($v.First)"
}

# =============================================================== D10: -Kick
if (Want 'KICK') {
    $k1 = Run-Tool $consultPs (New-Repo 'kickref') @('-Task', 't', '-Kick')
    $k2 = Run-Tool $consultPs (New-Repo 'kickref2') @('-Task', 't', '-Kick', '-Member', '07')
    $k3 = Run-Tool $consultPs (New-Repo 'kickref3') @('-Task', 't', '-Member', '01', '-Prompt', 'x')
    Check 'KICK' 'D10 refusals: -Kick without -Member (exit 4); -Kick -Member 07 when no run 07 is in progress (exit 1, "no run with handoff 07 is in progress"); -Member without -Kick (exit 4)' ($k1.Code -eq 4 -and $k1.First -like '*-Kick needs -Member <NN>*' -and $k2.Code -eq 1 -and $k2.First -like '*no run with handoff 07 is in progress in task t*' -and $k3.Code -eq 4 -and $k3.First -like '*-Member goes with -Kick*') "$($k1.First) | $($k2.First) | $($k3.First)"
    # a foreground panel: the ZAI member hangs (60 s); -Kick from another process stops it
    $r = New-Repo 'kick'
    $bg = Start-Consult $r $roster2 @('-Panel', '-PanelAll', '-Prompt', 'x', '-ReplyName', 'kk', '-TimeoutSec', '120') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""'; FAKE_CODEX_ITEMS = '1' } -Name 'kick'
    $up = Wait-Running $r '.consult.pending-02.json'
    $kw = [Diagnostics.Stopwatch]::StartNew()
    $kk = Run-Tool $consultPs $r @('-Task', 't', '-Kick', '-Member', '02')
    $res = Wait-Consult $bg 90
    $led = @(Ledger $r)
    $lz = @($led | Where-Object { $_.reviewer.provider -eq 'ZAI' })[0]
    $lo = @($led | Where-Object { $_.reviewer.provider -eq 'openai' })[0]
    $part = $(if ($lz.partial_reply) { Join-Path $r ".collab\t\$($lz.partial_reply)" } else { '' })
    Check 'KICK' 'D10: a FOREGROUND panel - -Kick -Member 02 from another shell (exit 0, "member 02 of task t stopped"): the ZAI member''s tree is stopped, its partial output salvaged (.partial.md with its stream), recorded "failed: stopped by the operator (-Kick)" class operator; the openai member finishes usable; the panel exits 1 long before the fake''s 60 s' ($up -and $kk.Code -eq 0 -and $kk.First -like 'codex-consult: -Kick: member 02 of task t stopped*' -and $res.Done -and $res.Code -eq 1 -and $lz.bridge_outcome -eq 'failed: stopped by the operator (-Kick)' -and $lz.provider_failure.class -eq 'operator' -and $part -and (Test-Path -LiteralPath $part) -and ([IO.File]::ReadAllText($part, $u8)) -match 'stopped by the operator' -and $lo.bridge_outcome -eq 'usable reply' -and $kw.Elapsed.TotalSeconds -lt 45 -and -not (Test-Path -LiteralPath (Join-Path $r '.collab\t\.consult.kick-02'))) "up $up kick $($kk.Code) $($kk.First) | panel $($res.Code) | $($lz.bridge_outcome) | $($lz.provider_failure.class) | $($lo.bridge_outcome)"
    # a detached panel: -Kick -Id <id8> -Member 02; -Status says so
    $r2 = New-Repo 'kickdetach'
    $dt = Consult $r2 $roster2 @('-Panel', '-PanelAll', '-Prompt', 'x', '-ReplyName', 'kd', '-TimeoutSec', '120', '-Detach') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""' }
    $id8 = ''
    if ($dt.Out -match 'Detached ([0-9a-f]{8})') { $id8 = $Matches[1] }
    $up2 = Wait-Running $r2 '.consult.pending-02.json'
    $kd = Run-Tool $consultPs $r2 @('-Task', 't', '-Kick', '-Id', $id8, '-Member', '02')
    $kx = Run-Tool $consultPs $r2 @('-Task', 't', '-Kick', '-Id', $id8, '-Member', '05')
    $wt = Run-Tool $consultPs $r2 @('-Task', 't', '-Wait', '-Id', $id8, '-WaitTimeoutSec', '90')
    $st = Run-Tool $consultPs $r2 @('-Task', 't', '-Status', '-Id', $id8)
    $ld = @(Ledger $r2 | Where-Object { $_.reviewer.provider -eq 'ZAI' })[0]
    Check 'KICK' 'D10: a DETACHED panel - -Kick -Id <id8> -Member 02 (exit 0); a member the run does not have (05) exit 1; -Wait ends with exit 1 (a member failed); -Status shows the member "stopped by the operator (-Kick)"; the ledger outcome and class operator' ($dt.Code -eq 0 -and $id8 -and $up2 -and $kd.Code -eq 0 -and $kx.Code -eq 1 -and $kx.First -like '*has no member with handoff 05*' -and $wt.Code -eq 1 -and $st.Out -match '(?m)^  #2 ZAI :: glm-5\.3 - failed: stopped by the operator \(-Kick\)' -and $ld.bridge_outcome -eq 'failed: stopped by the operator (-Kick)' -and $ld.provider_failure.class -eq 'operator') "id $id8 up $up2 kick $($kd.Code) $($kd.First) | $($kx.First) | wait $($wt.Code) | $(Line $st.Out '  #2')"
}

# =============================================================== D15: the salvage of any failed run with content
if (Want 'SALVAGE') {
    $r = New-Repo 'salvage'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'fe') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_ITEMS = '2'; FAKE_CODEX_FAIL_EVENT = 'exceeded retry limit, last status: 429 Too Many Requests' }
    $e = @(Ledger $r)[-1]
    $pp = $(if ($e.partial_reply) { Join-Path $r ".collab\t\$($e.partial_reply)" } else { '' })
    $pt = $(if ($pp -and (Test-Path -LiteralPath $pp)) { [IO.File]::ReadAllText($pp, $u8) } else { '' })
    Check 'SALVAGE' 'D15 (supervisor addendum): a run that fails mid-run - two agent messages, then a 429 error event and exit 1 - keeps them: handoffs/01-codex-fe.partial.md (both messages, the reasoning, the tool call; the footer "the run ended: <why>; thread <id> - continue with ...", not "killed at"), ledger partial_reply set, the summary''s "partial    :" line; bridge_outcome and the provider failure unchanged (failed, class quota)' ($x.Code -eq 1 -and $e.partial_reply -eq 'handoffs/01-codex-fe.partial.md' -and $pt -match 'Q1 so far \(first turn\)' -and $pt -match 'Q2 so far \(first turn\)' -and $pt -match '(?m)^the run ended: .*429.*; thread [0-9a-f-]{36} - continue with ' -and $pt -notmatch 'killed at' -and $x.Out -match '(?m)^partial    : ' -and $e.bridge_outcome -like 'failed: *' -and $e.provider_failure.class -eq 'quota') "$($e.bridge_outcome) | $($e.partial_reply) | $($e.provider_failure.class)"
    $r = New-Repo 'salvage-none'
    $y = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'nc') @{ FAKE_CODEX_STDERR = 'data:{"error":{"code":"invalid_api_key","message":"401 Unauthorized: invalid API key"}}'; FAKE_CODEX_EXIT = '1' }
    $ey = @(Ledger $r)[-1]
    Check 'SALVAGE' 'D15: a failure with no content in its stream (a 401 on the first request) writes nothing: partial_reply "", no .partial.md, no "partial    :" line' ($y.Code -eq 1 -and $ey.partial_reply -eq '' -and -not (Test-Path (Join-Path $r '.collab\t\handoffs\01-codex-nc.partial.md')) -and $y.Out -notmatch '(?m)^partial    : ') "$($ey.bridge_outcome) | [$($ey.partial_reply)]"
}

# =============================================================== D16: the reviewer's context window
if (Want 'CONTEXT') {
    $r = New-Repo 'context'
    $cr = Write-Roster 'context' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","context_tokens":32000},{"provider":"openai","model":"gpt-5.1"}]}'
    $thr = '11111111-2222-4333-8444-555555555555'
    $prior = [pscustomobject]@{ n = 1; when = (Iso ([DateTimeOffset]::Now.AddHours(-1))); purpose = ''; topics = [object[]]@(); consult_id = (Guid-Of 610001); reviewer = [pscustomobject]@{ provider = 'ZAI'; provider_source = 'roster'; model = 'glm-5.3'; model_source = 'roster'; engine = 'codex'; provider_fingerprint = $zaiFp }; lineage = 'ZAI :: glm-5.3'; thread = $thr; thread_source = 'events'; mode = 'new'; reply = 'handoffs/01-codex-first.md'; events = 'handoffs/01-codex-first.events.jsonl'; bridge_outcome = 'usable reply'; usage = [pscustomobject]@{ input_tokens = 27000; cached_input_tokens = 0; output_tokens = 900; reasoning_output_tokens = 0 }; wall_seconds = 30 }
    Seed-Store $r 't' -Entries @($prior)
    [IO.File]::WriteAllText((Join-Path $r '.collab\t\handoffs\01-codex-first.md'), "earlier review`n", $u8)
    $d = Consult $r $cr @('-Provider', 'ZAI', '-Prompt', 'x', '-DryRun')
    $pv = @($d.Previews)[0]
    Check 'CONTEXT' 'D16 (a): a roster entry with context_tokens 32000 whose newest thread last carried 27000 input tokens - the automatic fork (27000 + the prompt estimate > 80% of 32000) is replaced by a NEW thread: console "mode fork -> new: ...", ledger mode new, mode_fallback {from fork, to new, reason "... 27000 tokens ... 80% ... (32000 tokens)"}, parent_thread ""; the prompt names the previous reply (.collab/t/handoffs/01-codex-first.md) to re-read' ($d.Code -eq 0 -and $d.Out -match 'codex-consult: mode fork -> new: ' -and $pv.mode -eq 'new' -and $pv.mode_fallback.from -eq 'fork' -and $pv.mode_fallback.to -eq 'new' -and $pv.mode_fallback.reason -match '27000 tokens' -and $pv.mode_fallback.reason -match '80% of the reviewer''s context window \(32000 tokens\)' -and -not $pv.parent_thread -and $d.Out -match 'Your previous reply in this task is `\.collab/t/handoffs/01-codex-first\.md`') "$($pv.mode) | $($pv.mode_fallback | ConvertTo-Json -Compress)"
    $iAsk = $d.Out.IndexOf("`nx`n"); $iCtx = $d.Out.IndexOf('Your context window is 32000 tokens: read only what the brief points to; prefer targeted reads.')
    $o = Consult $r $cr @('-Provider', 'openai', '-Prompt', 'x', '-DryRun')
    Check 'CONTEXT' 'D16 (c): the member with context_tokens gets the line "Your context window is 32000 tokens: read only what the brief points to; prefer targeted reads." right after the ask; a reviewer without context_tokens does not' ($iAsk -ge 0 -and $iCtx -gt $iAsk -and $o.Code -eq 0 -and $o.Out -notmatch 'Your context window is') "ask $iAsk ctx $iCtx"
    $x = Consult $r $cr @('-Provider', 'ZAI', '-Prompt', 'x', '-ReplyName', 'fb') @{ FAKE_CODEX_REPLY = $advise }
    $ex = @(Ledger $r)[-1]
    Check 'CONTEXT' 'D16 (a): the real run records it - ledger mode new, mode_fallback from fork; the summary line "mode       : fork -> new (...)"; a usable reply on a fresh thread' ($x.Code -eq 0 -and $ex.mode -eq 'new' -and $ex.mode_fallback.from -eq 'fork' -and $x.Out -match '(?m)^mode       : fork -> new \(' -and $ex.bridge_outcome -eq 'usable reply' -and $ex.thread -ne $thr) "$($ex.mode) $($ex.mode_fallback.from) $($ex.thread)"
    # (b) a brief the window cannot hold: skipped before the start
    $rb = New-Repo 'context-big'
    [IO.File]::WriteAllText((Join-Path $rb 'big.md'), ('word ' * 24000), $u8)
    $pn = Consult $rb $cr @('-Panel', '-PanelAll', '-Brief', 'big.md', '-DryRun', '-Prompt', 'x')
    $pp = @($pn.Previews)[0]
    $wk = Consult $rb $cr @('-Brief', 'big.md', '-DryRun', '-Prompt', 'x')
    $pz = Consult $rb $cr @('-Provider', 'ZAI', '-Brief', 'big.md', '-DryRun', '-Prompt', 'x')
    Check 'CONTEXT' 'D16 (b): a brief of ~120 KB (est. 30001 of 32000 tokens > 80%) - the panel member is skipped before its start ("#1 ZAI :: glm-5.3 - skipped: brief too large for this reviewer''s context (est. 30001 of 32000 tokens)"; the ledger''s skipped list), the other member runs; a roster walk skips it the same way (roster.skipped) and takes openai; an explicit -Provider ZAI is refused (exit 1)' ($pn.Code -eq 0 -and $pn.Out -match "(?m)^  #1 ZAI :: glm-5\.3 - skipped: brief too large for this reviewer's context \(est\. 30001 of 32000 tokens\)$" -and @($pn.Previews).Count -eq 1 -and @($pp.panel.members | Where-Object { $_.reason -like 'brief too large*' }).Count -eq 1 -and $wk.Code -eq 0 -and @($wk.Previews)[0].reviewer.provider -eq 'openai' -and @($wk.Previews)[0].roster.skipped[0].reason -eq "brief too large for this reviewer's context (est. 30001 of 32000 tokens)" -and $pz.Code -eq 1 -and $pz.First -like "codex-consult: brief too large for this reviewer's context (est. 30001 of 32000 tokens)*") "$(Line $pn.Out '  #1') | $(@($wk.Previews)[0].reviewer.provider) | $($pz.First)"
    $bad = Write-Roster 'context-bad' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","context_tokens":1000}]}'
    $v = Consult $rb $bad @('-DryRun', '-Prompt', 'x')
    Check 'CONTEXT' 'D16: the roster refuses a context_tokens below 32000 (fail-closed)' ($v.Code -eq 1 -and $v.First -like '*entry 1: context_tokens must be an integer from 32000*') $v.First
}

# =============================================================== D13: the machine-wide endpoint health
if (Want 'HEALTH') {
    $hA = Join-Path $work 'health-a.json'
    $ra = New-Repo 'health-a'
    $rb = New-Repo 'health-b'
    $rz = Write-Roster 'zai-first' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"openai","model":"gpt-5.1"}]}'
    $q = Consult $ra $rz @('-Provider', 'ZAI', '-Prompt', 'x', '-ReplyName', 'q') @{ FAKE_CODEX_STDERR = 'Error: credits exhausted for this token plan'; FAKE_CODEX_EXIT = '1'; CODEX_CONSULT_HEALTH = $hA }
    $hj = $null; try { $hj = [IO.File]::ReadAllText($hA, $u8) | ConvertFrom-Json } catch { }
    $rec = @($hj.endpoints | Where-Object { $_.endpoint -eq $zaiFp })[0]
    Check 'HEALTH' 'D13 (R20): a run that records a provider failure writes it into the machine-wide file (CODEX_CONSULT_HEALTH, a scratch path here): {endpoint = the ZAI fingerprint, class quota, kind, until = hit + 60 min, retry_after null (no reset named), repo = repository A, when, message}' ($q.Code -eq 1 -and $hj.health_version -eq 1 -and $rec.class -eq 'quota' -and (Same-Path $rec.repo $ra) -and $null -eq $rec.retry_after -and $null -ne (ConvertTo-WhenOffset $rec.until) -and [Math]::Abs(((ConvertTo-WhenOffset $rec.until) - (ConvertTo-WhenOffset $rec.when)).TotalMinutes - 60) -lt 1 -and @($hj.running).Count -eq 0) "$(if ($rec) { $rec | ConvertTo-Json -Compress })"
    $w1 = Consult $rb $rz @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_HEALTH = $hA }
    $w2 = Consult $rb $rz @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_HEALTH = 'none' }
    $p1 = @($w1.Previews)[0]; $p2 = @($w2.Previews)[0]
    Check 'HEALTH' 'D13: repository B (no failure in its own ledgers) honours it - its roster walk skips ZAI ("usage limit hit ..., reset unknown; retry after ...") and takes openai; with CODEX_CONSULT_HEALTH=none (no file) the walk takes ZAI as before' ($w1.Code -eq 0 -and $p1.reviewer.provider -eq 'openai' -and @($p1.roster.skipped).Count -eq 1 -and $p1.roster.skipped[0].reason -like 'usage limit hit *, reset unknown; retry after *' -and $w2.Code -eq 0 -and $p2.reviewer.provider -eq 'ZAI') "$($p1.reviewer.provider) skipped [$(@($p1.roster.skipped | ForEach-Object { $_.reason }) -join '; ')] | none: $($p2.reviewer.provider)"
    $ok = Consult $rb $rz @('-Provider', 'ZAI', '-SkipPreflight', '-Prompt', 'x', '-ReplyName', 'ok') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hA }
    $w3 = Consult $ra $rz @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_HEALTH = $hA }
    Check 'HEALTH' 'D13: a later usable reply on the endpoint (repository B, class ok) clears it for repository A too - A''s walk, whose own ledger still has the quota failure, takes ZAI again (the newest record decides across the file and the ledgers)' ($ok.Code -eq 0 -and $w3.Code -eq 0 -and @($w3.Previews)[0].reviewer.provider -eq 'ZAI') "$(@($w3.Previews)[0].reviewer.provider)"
    # running[]: a single run of repository C holds the ZAI endpoint; repository D's panel waits for it
    $hB = Join-Path $work 'health-b.json'
    $rc = New-Repo 'health-c'
    $rd = New-Repo 'health-d'
    $slow = Start-Consult $rc '' @('-Provider', 'ZAI', '-Model', 'glm-5.3', '-Prompt', 'x', '-ReplyName', 'slow') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_DELAY_MS = '25000'; CODEX_CONSULT_HEALTH = $hB } -Name 'slow'
    $seen = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $seen -and $sw.Elapsed.TotalSeconds -lt 40) {
        try { if (@(([IO.File]::ReadAllText($hB, $u8) | ConvertFrom-Json).running).Count -gt 0) { $seen = $true } } catch { }
        if (-not $seen) { Start-Sleep -Milliseconds 250 }
    }
    $rowNow = $null; try { $rowNow = @(([IO.File]::ReadAllText($hB, $u8) | ConvertFrom-Json).running)[0] } catch { }
    $pn = Consult $rd $roster2 @('-Panel', '-PanelAll', '-Prompt', 'x', '-ReplyName', 'pw') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hB }
    $sres = Wait-Consult $slow 60
    $lc = @(Ledger $rc)[-1]
    $ldz = @(Ledger $rd | Where-Object { $_.reviewer.provider -eq 'ZAI' })[0]
    $cFin = ConvertTo-WhenOffset $lc.finished_at
    $dStart = ConvertTo-WhenOffset $ldz.when
    $after = $null; try { $after = [IO.File]::ReadAllText($hB, $u8) | ConvertFrom-Json } catch { }
    Check 'HEALTH' 'D13: running[] - repository C''s run on ZAI holds a row {endpoint, label ZAI, pid, start_time, repo C, task, nn, panel ""}; repository D''s panel counts it against the endpoint''s parallel limit (1): "panel member 2 of 2 waits: 1 run(s) elsewhere on this machine use its endpoint (parallel limit 1): ZAI in <C> task t handoff 01 ..."; D''s ZAI member starts only after C finished; both usable; running[] empty afterwards' ($seen -and $rowNow.label -eq 'ZAI' -and (Same-Path $rowNow.repo $rc) -and $rowNow.nn -eq '01' -and $pn.Code -eq 0 -and $pn.Out -match 'panel member 2 of 2 waits: 1 run\(s\) elsewhere on this machine use its endpoint \(parallel limit 1\): ZAI in \S*health-c task t handoff 01 \(pid \d+\)'  -and $sres.Code -eq 0 -and $null -ne $cFin -and $null -ne $dStart -and $dStart -ge $cFin.AddSeconds(-1) -and @($after.running).Count -eq 0) "seen $seen | $(Line $pn.Out '  panel member 2 of 2 waits') | C finished $($lc.finished_at), D ZAI when $($ldz.when) | running after $(@($after.running).Count)"
    # pruning and an unreadable file
    $hC = Join-Path $work 'health-c.json'
    $old = (Iso ([DateTimeOffset]::Now.AddDays(-3)))
    $stale = [pscustomobject]@{ health_version = 1; endpoints = @([pscustomobject]@{ endpoint = 'e-old'; class = 'quota'; kind = ''; until = (Iso ([DateTimeOffset]::Now.AddDays(-2))); repo = 'x'; when = $old; message = 'm' }, [pscustomobject]@{ endpoint = 'e-long'; class = 'quota'; kind = ''; until = (Iso ([DateTimeOffset]::Now.AddDays(2))); repo = 'x'; when = $old; message = 'weekly' }); running = @([pscustomobject]@{ endpoint = 'e'; label = 'L'; pid = 999999; start_time = '2020-01-01T00:00:00.0000000Z'; repo = 'x'; task = 't'; nn = '01'; panel = ''; since = $old }) }
    [IO.File]::WriteAllText($hC, (ConvertTo-Json -InputObject $stale -Depth 5), $u8)
    $saved = $env:CODEX_CONSULT_HEALTH
    $env:CODEX_CONSULT_HEALTH = $hC
    $wrote = Add-MachineHealthRecord -Fingerprint 'e-new' -Outcome 'usable reply' -Repo 'y'
    $env:CODEX_CONSULT_HEALTH = $saved
    $pr = [IO.File]::ReadAllText($hC, $u8) | ConvertFrom-Json
    $hD = Join-Path $work 'health-d.json'
    [IO.File]::WriteAllText($hD, '{ not json', $u8)
    $bad = Consult $rb $rz @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_HEALTH = $hD }
    Check 'HEALTH' 'D13: every write prunes - a record older than 24 h whose until passed goes, one whose until lies ahead (a weekly limit) stays, a running row whose pid + start time is gone goes; a file that does not parse is read as empty (the walk works as before)' ($wrote -and (@($pr.endpoints | ForEach-Object { $_.endpoint }) -join ',') -eq 'e-long,e-new' -and @($pr.running).Count -eq 0 -and $bad.Code -eq 0 -and @($bad.Previews)[0].reviewer.provider -eq 'ZAI') "$(@($pr.endpoints | ForEach-Object { $_.endpoint }) -join ',') running $(@($pr.running).Count) | bad file: $($bad.Code)"
}

# ======================================================================= wave 26c (decisions D1-D6 of
# .collab/companions-2026-09-26/handoffs/27-claude-wave26c-decisions.md; F25-1/2, F26-1..5)
$prose26c = Reply 'prose-26c.md' ("1. The first answer: the invalidation path looks correct, because every writer takes the lock before it touches the cache entry and releases it after the write.`n" + "2. The second answer: the retry path has no test at all and should get one before the release, since a silent retry loop hides the real failure.`n")

# =============================================================== 26c D1: the kick acknowledged
if (Want 'KICKACK') {
    $kd = Join-Path $work 'kickunit'
    [void][IO.Directory]::CreateDirectory($kd)
    $kf = Join-Path $kd '.consult.kick-05'
    $pe = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-Command', 'exit 0' -PassThru -WindowStyle Hidden
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $pe.Handle } catch { } }
    $null = $pe.WaitForExit(20000)
    [IO.File]::WriteAllText($kf, "kick`n")
    $wl = Wait-EngineProcess -Process $pe -TimeoutSec 20 -KickPath $kf
    $ackL = $(if (Test-Path -LiteralPath "$kf.ack") { [IO.File]::ReadAllText("$kf.ack") } else { '' })
    Check 'KICKACK' '26c D1 (F26-1, F25-2): a kick file found once the turn''s process has exited is taken LATE - Wait-EngineProcess: Exited, KickLate, no kick reason; the kick file removed, the acknowledgement <kick file>.ack says "late"' ($wl.Exited -and $wl.KickLate -and $wl.Reason -eq '' -and -not (Test-Path -LiteralPath $kf) -and $ackL -match '^late ') "exited $($wl.Exited) late $($wl.KickLate) reason '$($wl.Reason)' ack '$($ackL.Trim())'"
    Remove-Item -LiteralPath "$kf.ack" -ErrorAction SilentlyContinue
    $pl = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 30' -PassThru -WindowStyle Hidden
    [IO.File]::WriteAllText($kf, "kick`n")
    $kw0 = [Diagnostics.Stopwatch]::StartNew()
    $wk = Wait-EngineProcess -Process $pl -TimeoutSec 20 -KickPath $kf
    $kw0.Stop()
    try { Stop-Process -Id $pl.Id -Force -ErrorAction SilentlyContinue } catch { }
    $ackK = $(if (Test-Path -LiteralPath "$kf.ack") { [IO.File]::ReadAllText("$kf.ack") } else { '' })
    Check 'KICKACK' '26c D1: a kick file already there when the wait starts on a LIVE turn is taken before the wait loop (reason kick at once), acknowledged "kicked", the kick file removed' ($wk.Reason -eq 'kick' -and -not $wk.Exited -and -not $wk.KickLate -and $kw0.Elapsed.TotalSeconds -lt 1 -and $ackK -match '^kicked ' -and -not (Test-Path -LiteralPath $kf)) "reason '$($wk.Reason)' in $([math]::Round($kw0.Elapsed.TotalSeconds, 2)) s ack '$($ackK.Trim())'"
    # -Kick against a run whose member never polls (a fabricated running record, a live child): exit 3, the file stays;
    # once the child is gone: exit 1 and the stale kick file is removed
    $r = New-Repo 'kickack'
    $td = Join-Path $r '.collab\t'
    [void][IO.Directory]::CreateDirectory($td)
    $sl = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 90' -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 500
    $rec = New-PendingRecord -State 'running' -N 7 -Nn '07' -Reply 'handoffs/07-codex-x.md' -Started (Get-IsoTimestamp) -Launcher 'x' -ConsultId (Guid-Of 881001)
    $rec.child_pid = $sl.Id
    $rec.child_start_time = [string](Get-ProcessStartIso -ProcessId $sl.Id)
    Write-PendingFile -Path (Join-Path $td '.consult.pending.json') -Record $rec
    $kw1 = [Diagnostics.Stopwatch]::StartNew()
    $k3 = Run-Tool $consultPs $r @('-Task', 't', '-Kick', '-Member', '07')
    $kw1.Stop()
    $stays = Test-Path -LiteralPath (Join-Path $td '.consult.kick-07')
    try { Stop-Process -Id $sl.Id -Force -ErrorAction SilentlyContinue } catch { }
    Start-Sleep -Milliseconds 500
    $k1b = Run-Tool $consultPs $r @('-Task', 't', '-Kick', '-Member', '07')
    Check 'KICKACK' '26c D1: -Kick waits up to 10 s for the acknowledgement - a member that never takes it: exit 3 after ~10 s ("did not acknowledge the kick within 10 s - the kick file stays"), the kick file still there; once no engine turn runs: exit 1 and that stale kick file is removed' ($k3.Code -eq 3 -and $k3.Out -match 'did not acknowledge the kick within 10 s' -and $kw1.Elapsed.TotalSeconds -ge 9 -and $kw1.Elapsed.TotalSeconds -lt 40 -and $stays -and $k1b.Code -eq 1 -and $k1b.Out -match 'no engine turn running' -and -not (Test-Path -LiteralPath (Join-Path $td '.consult.kick-07'))) "exit $($k3.Code) after $([math]::Round($kw1.Elapsed.TotalSeconds, 1)) s, stays $stays | then exit $($k1b.Code)"
    # a kick that stops only the FORMAT REPAIR: the first reply stands (usable, not converted)
    $r2 = New-Repo 'kickrepair'
    $bg = Start-Consult $r2 '' @('-Prompt', 'x', '-ReplyName', 'kr', '-TimeoutSec', '120') @{ FAKE_CODEX_REPLY = $prose26c; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_ON = ' resume ' } -Name 'kickrepair'
    $pend = Join-Path $r2 '.collab\t\.consult.pending.json'
    $inRepair = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $inRepair -and $sw.Elapsed.TotalSeconds -lt 60) {
        try { $pr0 = [IO.File]::ReadAllText($pend) | ConvertFrom-Json; if ($pr0.state -eq 'running' -and $pr0.note -eq 'format repair turn') { $inRepair = $true } } catch { }
        if (-not $inRepair) { Start-Sleep -Milliseconds 250 }
    }
    $kr = Run-Tool $consultPs $r2 @('-Task', 't', '-Kick', '-Member', '01')
    $res = Wait-Consult $bg 90
    $er = @(Ledger $r2)[-1]
    Check 'KICKACK' '26c D1 (F25-2): -Kick while only the format repair runs (exit 0, acknowledged): the first reply STANDS - bridge_outcome "usable reply", provider_failure null (no operator class), format_retry failed, warnings[] "kick: the operator stopped the format repair (-Kick); the first reply stands, not converted"' ($inRepair -and $kr.Code -eq 0 -and $res.Done -and $er.bridge_outcome -eq 'usable reply' -and $null -eq $er.provider_failure -and $er.format_retry.succeeded -eq $false -and @($er.warnings | Where-Object { ([string]$_).StartsWith('kick: the operator stopped the format repair (-Kick)') }).Count -eq 1) "repair seen $inRepair; kick $($kr.Code) $($kr.First) | $($er.bridge_outcome) | $(@($er.warnings) -join ' / ')"
}

# =============================================================== 26c D2: the machine-wide health update
if (Want 'HEALTHLOCK') {
    $hT = Join-Path $work 'health-tie.json'
    $hit = [DateTimeOffset]::Now.AddMinutes(-5)
    $tie = [pscustomobject]@{ health_version = 1; endpoints = @(
            [pscustomobject]@{ endpoint = 'e-tie'; class = 'quota'; kind = ''; until = (Iso $hit.AddMinutes(120)); retry_after = $null; repo = 'a'; when = (Iso $hit); message = 'usage limit' },
            [pscustomobject]@{ endpoint = 'e-tie'; class = 'quota'; kind = ''; until = (Iso $hit.AddMinutes(20)); retry_after = $null; repo = 'b'; when = (Iso $hit); message = 'usage limit' }); running = @() }
    [IO.File]::WriteAllText($hT, (ConvertTo-Json -InputObject $tie -Depth 5), $u8)
    $savedH = $env:CODEX_CONSULT_HEALTH
    $env:CODEX_CONSULT_HEALTH = $hT
    $eh = Get-EndpointHealth -Consults @() -Fingerprint 'e-tie'
    $env:CODEX_CONSULT_HEALTH = $savedH
    Check 'HEALTHLOCK' '26c D2 (F26-2): the record conversion carries the STORED until - two quota records of one endpoint at the same moment: the later until decides (out until hit + 120 min, not the recomputed hit + 60)' ($null -ne $eh.Quota -and (Iso $eh.Quota.Until) -eq (Iso $hit.AddMinutes(120))) "$(if ($eh.Quota) { Iso $eh.Quota.Until } else { 'no quota' })"
    $hL = Join-Path $work 'health-lock.json'
    $r = New-Repo 'healthlock'
    $lk = [IO.File]::Open("$hL.lock", [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'hl') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hL; CODEX_CONSULT_TEST_HEALTH_LOCK_SEC = '1' }
    } finally { $lk.Dispose() }
    $el = @(Ledger $r)[-1]
    Check 'HEALTHLOCK' '26c D2: the health file''s lock held elsewhere (3 attempts of the hook''s 1 s each, then the one retry at the ledger commit): the run still delivers (usable reply, exit 0), warnings[] and the summary say "machine-wide health not updated (lock timeout)", the ledger keeps the truth; nothing was written to the file' ($x.Code -eq 0 -and $el.bridge_outcome -eq 'usable reply' -and @($el.warnings) -contains 'machine-wide health not updated (lock timeout)' -and $x.Out -match '(?m)^warning    : machine-wide health not updated \(lock timeout\)$' -and -not (Test-Path -LiteralPath $hL)) "exit $($x.Code) | $(@($el.warnings) -join ' / ')"
}

# =============================================================== 26c D3: the stall cut outside tool calls
if (Want 'STALLTOOL') {
    $open = New-Object 'System.Collections.Generic.HashSet[string]'
    Update-ToolFlight -Engine 'codex' -Line '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"make"}}' -Open $open
    $c1 = $open.Count
    Update-ToolFlight -Engine 'codex' -Line '{"type":"item.completed","item":{"id":"item_2","type":"agent_message","text":"command_execution soon"}}' -Open $open
    $c2 = $open.Count
    Update-ToolFlight -Engine 'codex' -Line '{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"make"}}' -Open $open
    $c3 = $open.Count
    Update-ToolFlight -Engine 'agy' -Line '{"event":"step_update","step_update":{"step_index":4,"state":"ACTIVE","step_type":"tool","tool_name":"run_command"}}' -Open $open
    $c4 = $open.Count
    Update-ToolFlight -Engine 'agy' -Line '{"event":"step_update","step_update":{"step_index":4,"state":"DONE","step_type":"tool","tool_name":"run_command"}}' -Open $open
    $c5 = $open.Count
    Update-ToolFlight -Engine 'muse' -Line '{"payload_type":"task.lifecycle.proposed","payload":{"task_id":"t1","event":{"kind":"proposed","task_id":"t1","task_kind":"tool.read_file"}}}' -Open $open
    $c6 = $open.Count
    Update-ToolFlight -Engine 'muse' -Line '{"payload_type":"task.lifecycle.completed","payload":{"task_id":"t1","event":{"kind":"completed","task_id":"t1"}}}' -Open $open
    $c7 = $open.Count
    Check 'STALLTOOL' '26c D3 (F26-3): the tool calls in flight - codex item.started of a command_execution until its item.completed (an agent message in between changes nothing), an agy tool step ACTIVE until DONE, a muse tool.* task until its task.lifecycle.completed' ((@($c1, $c2, $c3, $c4, $c5, $c6, $c7) -join ',') -eq '1,1,0,1,0,1,0') (@($c1, $c2, $c3, $c4, $c5, $c6, $c7) -join ',')
    $r = New-Repo 'stalltool'
    $w1 = [Diagnostics.Stopwatch]::StartNew()
    $t1 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'to', '-StallSec', '3', '-TimeoutSec', '60') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_TOOL_OPEN = '8' }
    $w1.Stop()
    $e1 = @(Ledger $r)[-1]
    Check 'STALLTOOL' '26c D3 (F25-1): one silent tool call of 8 s (item.started, nothing, item.completed) with -StallSec 3 is NOT cut - the timer is suspended while it is in flight: usable reply, stall null, the run took the 8 s' ($t1.Code -eq 0 -and $e1.bridge_outcome -eq 'usable reply' -and $null -eq $e1.stall -and $w1.Elapsed.TotalSeconds -ge 8) "$($e1.bridge_outcome) in $([math]::Round($w1.Elapsed.TotalSeconds, 1)) s"
    $t2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'dr', '-StallSec', '3', '-TimeoutSec', '60') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_DRIP = '7' }
    $e2 = @(Ledger $r)[-1]
    Check 'STALLTOOL' '26c D3: a line written one byte a second for 7 s (no newline until the end) with -StallSec 3 is NOT cut - any growth of the stream resets the timer: usable reply, stall null' ($t2.Code -eq 0 -and $e2.bridge_outcome -eq 'usable reply' -and $null -eq $e2.stall) "$($e2.bridge_outcome)"
    $rlog = Join-Path $work 'stall-resume.log'
    $t3 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'sc', '-StallSec', '3', '-TimeoutSec', '60') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_RESUME_LOG = $rlog }
    $e3 = @(Ledger $r)[-1]
    $rl = $(if (Test-Path -LiteralPath $rlog) { [IO.File]::ReadAllText($rlog) } else { '' })
    Check 'STALLTOOL' '26c D3: a silent main turn outside any tool call is still cut (stall {seconds 3}), and the continuation says "Your previous turn was stopped after no output for 3 s outside a tool call."' ($null -ne $e3.stall -and [int]$e3.stall.seconds -eq 3 -and $rl.Contains('Your previous turn was stopped after no output for 3 s outside a tool call.')) "$($e3.bridge_outcome)"
}

# =============================================================== 26c D4: a legacy rating's empty fields
if (Want 'JOINBLANK') {
    $r = New-Repo 'joinblank'
    $cid = Guid-Of 777002
    $entry = [pscustomobject]@{ n = 1; when = (Iso ([DateTimeOffset]::Now.AddDays(-2))); purpose = 'decision'; topics = [object[]]@('tests'); consult_id = $cid; reviewer = [pscustomobject]@{ provider = 'mimo'; model = 'mimo-v2.6-pro'; engine = 'codex'; provider_fingerprint = 'x' }; bridge_outcome = 'usable reply' }
    $rating = [pscustomobject]@{ n = 1; consult_id = $cid; provider = 'mimo'; model = ''; purpose = '  '; engine = ''; topics = [object[]]@(); consult_when = ''; useful = 'partly'; note = 'n'; when = (Iso ([DateTimeOffset]::Now)) }
    Seed-Store $r 'legacy2' -Ratings @($rating) -Entries @($entry)
    $all = @(Read-AllTaskRatings -CollabRoot (Join-Path $r '.collab'))
    Check 'JOINBLANK' '26c D4 (F26-4): a rating whose model is EMPTY (and purpose white space, engine empty, topics [], consult_when empty) counts those fields as missing and completes them from its consultation - model mimo-v2.6-pro, purpose decision, engine codex, topics [tests]' ($all.Count -eq 1 -and $all[0].Model -eq 'mimo-v2.6-pro' -and $all[0].Purpose -eq 'decision' -and $all[0].Engine -eq 'codex' -and (@($all[0].Topics) -join ',') -eq 'tests' -and $null -ne $all[0].ConsultWhen) "$($all[0].Lineage) / $($all[0].Purpose) / $(@($all[0].Topics) -join ',')"
}

# =============================================================== 26c D5: the size raised by the required reviewers
if (Want 'SIZERAISE') {
    $r = New-Repo 'sizeraise'
    $d = Consult $r $roster2 @('-Panel', '-PanelSize', '1', '-Require', 'openai,ZAI', '-DryRun', '-Prompt', 'x')
    $pv = @($d.Previews)[0]
    Check 'SIZERAISE' '26c D5 (F26-5): -PanelSize 1 with two required reviewers seats both and says so - "WARNING: panel size raised: asked 1, required 2", the preview''s warnings[], panel.routing size 2, size_asked 1, size_source required, the dry run''s Routing line "size 2 (required; asked 1)"' ($d.Code -eq 0 -and $d.Out -match '(?m)^WARNING: panel size raised: asked 1, required 2$' -and @($pv.warnings | Where-Object { $_ -eq 'panel size raised: asked 1, required 2' }).Count -eq 1 -and $pv.panel.routing.size -eq 2 -and $pv.panel.routing.size_asked -eq 1 -and $pv.panel.routing.size_source -eq 'required' -and $d.Out -match '(?m)^Routing: .* - size 2 \(required; asked 1\)') "$($pv.panel.routing.size)/$($pv.panel.routing.size_asked) $($pv.panel.routing.size_source)"
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
# the real machine-wide health file (when the operator's own runs keep one) names no scratch repository of this harness
$leak = 0
if (Test-Path -LiteralPath $realHealth -PathType Leaf) {
    try { $rh = [IO.File]::ReadAllText($realHealth, $u8) | ConvertFrom-Json; $leak = @(@($rh.endpoints) + @($rh.running) | Where-Object { $_ -and ([string]$_.repo).Replace('/', '\') -like "$work*" }).Count } catch { }
}
Check 'GUARD' 'the user''s own Codex config was never modified; the real machine-wide health file (~/.codex/codex-consult-health.json) got nothing from these cases' ($guard -and $leak -eq 0) "leaked rows: $leak"
Write-Host ("harness-fixes26b ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
