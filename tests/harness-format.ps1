# codex-consult first-turn output contract and format repair (-FormatRetry): the prompt
# opens with the FINAL OUTPUT CONTRACT paragraph; a substantive prose reply on a verified
# thread gets ONE repair turn (`resume <thread>`, no --output-schema, lowest effort) whose
# valid JSON is ingested, the prose kept as .original.md; drift notes; the cases that must
# NOT repair. Fake codex only (fake-codex3.cmd; FAKE_CODEX_RESUME_REPLY answers the repair
# turn); CODEX_HOME is a scratch directory. Runs under the host it is started with
# (powershell 5.1 or pwsh 7, Windows). Work files:
# $env:TEMP\codex-consult-tests\harness-format\<guid>, removed at the end.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-format') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
$savedCodexHome = $env:CODEX_HOME
$script:fails = 0
$script:passes = 0
function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $ev = $Evidence
    if ($ev.Length -gt 300) { $ev = $ev.Substring(0, 300) + '...' }
    Write-Host ("{0} {1,-7} {2}{3}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
}
function Want { param([string]$Name) return (-not $Only -or ($Only -split ',') -contains $Name) }
function G { param([string]$Repo, [string[]]$A) $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = & git -C $Repo @A 2>&1; $ErrorActionPreference = $p; return $o }
function New-Repo {
    param([string]$Name)
    $r = Join-Path $work $Name
    [void][IO.Directory]::CreateDirectory($r)
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n", $u8)
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_LOG', 'FAKE_CODEX_NOTHREAD', 'FAKE_CODEX_ROLLOUT', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_STDERR', 'FAKE_CODEX_EXIT', 'FAKE_CODEX_RESUME_REPLY', 'FAKE_CODEX_RESUME_LOG', 'FAKE_CODEX_RESUME_NEWTHREAD', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_HANG_ON')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + @('RT_ZAI_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER'))) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
}
function Consult {
    param([string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{}, [string]$Roster = 'none')
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:CODEX_CONSULT_ROSTER = $Roster
    foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task t -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Clear-TestEnv
    $env:CODEX_HOME = $savedCodexHome
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    $preview = $null
    $at = $text.IndexOf('sessions.json entry preview:')
    if ($at -ge 0) { try { $preview = $text.Substring($at + 'sessions.json entry preview:'.Length) | ConvertFrom-Json } catch { } }
    return [pscustomobject]@{ Code = $code; Out = $text; Preview = $preview; First = (($text -split "`n") | Select-Object -First 1) }
}
function File { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (Ledger $Repo)[-1] }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Get-DryPrompt { param([string]$Out) $m = [regex]::Match($Out, "(?s)prompt \(stdin, \d+ chars\):\n----\n(.*?)\n----\n"); if ($m.Success) { return $m.Groups[1].Value } else { return '' } }

$contract = 'FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON object (schema_version "1") - no code fence, no text before or after it. The Markdown answer lives only inside its reply_markdown string; each defect goes in findings[]. A prose final message cannot be ingested, however good the answer is.'
# A substantive prose answer (numbered answers, requested checks, a verdict line).
$prose = @'
**Q1.** The cache invalidation path is correct for single writers and handles the eviction race well enough for now.
**Q2.** Finding F01-1 is still open because the retry path does not re-check the generation counter after the lock.
**Q3.** Nothing else blocks acceptance of this change set in its present form, as far as I can see from the code.

Verdict: HOLD

## Requested checks
RC1 - run the soak test in ./ for 10 minutes (read-only) and expect zero mismatches in the log.
RC2 - run the fuzzer in ./ for 5 minutes (read-only) and expect no crash or assertion failure.
'@
$proseFile = File 'prose.md' ($prose -replace "`r`n", "`n")
$proseMd = (Get-Content -Raw $proseFile) -replace '\\', '\\' -replace '"', '\"' -replace "`r?`n", '\n'
$finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"retry path skips the generation check","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
# The faithful conversion: the same text inside reply_markdown, the verdict HOLD, the finding.
$repaired = File 'repaired.json' ('{"schema_version":"1","verdict":"HOLD","verdict_reason":"the retry path is still open","reply_markdown":"' + $proseMd.TrimEnd('\n'.ToCharArray()) + '","findings":[' + $finding + '],"prior_findings":[{"id":"F01-1","status":"still-open","note":"retry path"}],"unproven":[],"first_run_checklist":["soak test log shows zero mismatches"]}')
# A drifting conversion: RC2 dropped, F01-1 not reported, verdict ACCEPT.
$driftMd = ($prose -split "`r?`n" | Where-Object { $_ -notmatch '^RC2' }) -join "`n"
$driftMd = $driftMd -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n'
$drifted = File 'drifted.json' ('{"schema_version":"1","verdict":"ACCEPT","verdict_reason":"fine","reply_markdown":"' + $driftMd + '","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":["x"]}')
$shortProse = File 'short.md' 'Looks fine to me, nothing to add here at all.'

try {
# =============================================================== CONTRACT: the prompt's first paragraph
if (Want 'CONTRACT') {
    $r = New-Repo 'contract'
    $d = Consult $r @('-DryRun', '-Prompt', 'Judge the change.', '-Purpose', 'acceptance')
    $pr = Get-DryPrompt $d.Out
    $paras = @($pr -split "`r?`n`r?`n")
    Check 'CONTR' 'dry run: the prompt opens with the FINAL OUTPUT CONTRACT paragraph, then the ask; Consultation id stays last' ($d.Code -eq 0 -and $paras[0] -eq $contract -and $paras[1] -eq 'Judge the change.' -and $paras[-1] -match '^Consultation id: [0-9a-f-]{36}$') $paras[0]
    Check 'CONTR' 'the reply_markdown sentence says the answer lives INSIDE the JSON string' ($pr.Contains('This is what people read - a complete Markdown answer, but it lives INSIDE the JSON string, never as the message itself.') -and -not $pr.Contains('write it exactly as you would a normal reply')) ''
    Check 'CONTR' 'dry run: "format retry : 1 attempt if the reply is not valid JSON"; ledger preview format_retry placeholder' ($d.Out -match '(?m)^format retry : 1 attempt if the reply is not valid JSON$' -and [string]$d.Preview.format_retry -match '^<null, or \{attempted') (Line $d.Out 'format retry')
    $d0 = Consult $r @('-DryRun', '-Prompt', 'x', '-FormatRetry', '0')
    $dr = Consult $r @('-DryRun', '-Prompt', 'x', '-Raw')
    $dc = Consult $r @('-DryRun', '-Prompt', 'x', '-Purpose', 'chore')
    Check 'CONTR' '-FormatRetry 0 / -Raw / chore: "format retry : 0 (off)", preview null; -Raw and chore carry no contract paragraph' ($d0.Out -match '(?m)^format retry : 0 \(off\)$' -and $null -eq $d0.Preview.format_retry -and $dr.Out -match '(?m)^format retry : 0 \(off\)$' -and -not (Get-DryPrompt $dr.Out).Contains('FINAL OUTPUT CONTRACT') -and $dc.Out -match '(?m)^format retry : 0 \(off\)$' -and -not (Get-DryPrompt $dc.Out).Contains('FINAL OUTPUT CONTRACT')) ''
    $d2 = Consult $r @('-DryRun', '-Prompt', 'x', '-FormatRetry', '2')
    Check 'CONTR' '-FormatRetry 2 refused' ($d2.Code -eq 1 -and $d2.First -eq 'codex-consult: -FormatRetry must be 0 or 1 (got 2): at most one format-repair turn per consultation.') $d2.First
}

# =============================================================== REPAIR: prose, then valid JSON on resume
if (Want 'REPAIR') {
    $r = New-Repo 'repair'
    $log = Join-Path $work 'repair-main.log'
    $rlog = Join-Path $work 'repair-resume.log'
    $x = Consult $r @('-Prompt', 'Judge the change.', '-Purpose', 'acceptance', '-ReplyName', 'acc', '-Sandbox', 'workspace-write', '-Effort', 'xhigh', '-CodexConfig', 'hide_agent_reasoning=true') @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_LOG = $log; FAKE_CODEX_RESUME_LOG = $rlog }
    $e = Last-Entry $r
    $fr = $e.format_retry
    $td = Join-Path $r '.collab\t'
    Check 'REPAIR' 'prose first, valid JSON on resume -> structured true, the finding ingested, verdict HOLD, format_retry.succeeded true with the original parse error as reason' ($x.Code -eq 0 -and $e.structured -eq $true -and @($e.finding_ids).Count -eq 1 -and $e.verdict -eq 'HOLD' -and $fr.attempted -eq $true -and $fr.succeeded -eq $true -and $fr.reason -and $fr.reason.Length -le 200 -and $e.validation_error -eq '') "reason=$($fr.reason)"
    $names = ($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    $frNames = ($fr.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    Check 'REPAIR' 'ledger: format_retry right after validation_error (then denial_retry, 0.4.0), fields attempted,reason,succeeded,thread,wall_seconds,usage,drift,original,events (0.4.0: events null for codex - its repair stream is not kept); no drift for a faithful conversion' ($names -match 'validation_error,format_retry,denial_retry,base_commit' -and $frNames -eq 'attempted,reason,succeeded,thread,wall_seconds,usage,drift,original,events' -and $null -eq $fr.events -and @($fr.drift).Count -eq 0 -and $null -ne $fr.usage) "$frNames / drift=$(@($fr.drift) -join '; ')"
    Check 'REPAIR' 'thread unchanged: the entry keeps the first thread, the repair (resume) reported the same one' ($e.thread -and $fr.thread -eq $e.thread -and $e.thread_source -eq 'events') "$($e.thread) / $($fr.thread)"
    $orig = Join-Path $td ($fr.original -replace '/', '\')
    $replyJson = Join-Path $td ($e.reply_json -replace '/', '\')
    Check 'REPAIR' '.original.md = the prose byte for byte; .reply.json = the repaired object byte for byte' ($fr.original -match '^handoffs/\d\d-codex-acc\.original\.md$' -and (Test-Path $orig) -and (Get-FileHash $orig).Hash -eq (Get-FileHash $proseFile).Hash -and (Get-FileHash $replyJson).Hash -eq (Get-FileHash $repaired).Hash) $fr.original
    $md = [IO.File]::ReadAllText((Join-Path $td ($e.reply -replace '/', '\')), $u8)
    $origAt = $md.IndexOf('## Original reply (prose, before format repair)')
    Check 'REPAIR' 'handoff: "Format repair: succeeded" header line, the structured section, then the original prose verbatim under its heading' ($md -match '(?m)^Format repair: succeeded in [0-9.]+ s - the first reply was prose' -and $md.Contains('Structured reply') -and $origAt -gt 0 -and $md.Substring($origAt).Contains(($prose -replace "`r`n", "`n").Trim())) ''
    Check 'REPAIR' 'console: "format repair: succeeded in <s> s; drift: 0 note(s)"' ($x.Out -match '(?m)^format repair: succeeded in [0-9.]+ s; drift: 0 note\(s\)$') (Line $x.Out 'format repair')
    $ra = ([IO.File]::ReadAllText($rlog) -split "`n")[0]
    $rp = [IO.File]::ReadAllText($rlog)
    Check 'REPAIR' 'repair argv: --sandbox read-only, same -m/provider/-CodexConfig, effort low, no --output-schema, -o <tmp> resume <thread> -' ($ra -match '--sandbox read-only' -and $ra -notmatch 'workspace-write' -and $ra -match '-m gpt-5\.1' -and $ra.Contains('model_reasoning_effort=""low""') -and $ra.Contains('model_provider=""openai""') -and $ra.Contains('hide_agent_reasoning=true') -and $ra -notmatch '--output-schema' -and $ra -match (' resume ' + [regex]::Escape($e.thread) + ' -\s*$')) $ra
    Check 'REPAIR' 'repair prompt: the conversion request, the schema, the SAME consultation id last; no brief, no ask, no contract paragraph' ($rp -match 'PROMPT:\s*Your last message was prose, not the required JSON\. Reply with exactly one bare JSON object' -and $rp.Contains('Convert, do not re-answer: copy your previous content unchanged') -and $rp.Contains('JSON Schema of the reply:') -and $rp.TrimEnd() -match ('Consultation id: ' + [regex]::Escape($e.consult_id) + '$') -and -not $rp.Contains('Judge the change.') -and -not $rp.Contains('FINAL OUTPUT CONTRACT')) ''
    $fs = [IO.File]::ReadAllText((Join-Path $td 'findings.json'), $u8) | ConvertFrom-Json
    Check 'REPAIR' 'findings.json: the finding from the REPAIRED object' (@($fs.findings).Count -eq 1 -and $fs.findings[0].claim -eq 'retry path skips the generation check') ''

    # the repair returns a different thread id
    $rn = New-Repo 'repair-newthread'
    $n = Consult $rn @('-Prompt', 'x', '-Purpose', 'acceptance', '-ReplyName', 'nt') @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_NEWTHREAD = '1' }
    $en = Last-Entry $rn
    Check 'REPAIR' 'a repair that reports another thread -> the entry keeps the original thread, format_retry.thread records the other, drift note' ($n.Code -eq 0 -and $en.format_retry.succeeded -and $en.format_retry.thread -and $en.format_retry.thread -ne $en.thread -and @($en.format_retry.drift) -contains 'repair returned a different thread id') (@($en.format_retry.drift) -join '; ')
}

# =============================================================== TWICE: prose again on the repair turn
if (Want 'TWICE') {
    $r = New-Repo 'twice'
    $x = Consult $r @('-Prompt', 'x', '-Purpose', 'acceptance', '-ReplyName', 'tw') @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $proseFile }
    $e = Last-Entry $r
    $td = Join-Path $r '.collab\t'
    Check 'TWICE' 'prose twice -> structured false, format_retry.succeeded false, reason set, validation_error names the failed repair, prose kept, no findings' ($x.Code -eq 0 -and $e.structured -eq $false -and $e.format_retry.attempted -and $e.format_retry.succeeded -eq $false -and $e.format_retry.reason -and $e.validation_error -match '\(format repair failed: still not valid: ' -and -not (Test-Path (Join-Path $td 'findings.json')) -and (Test-Path (Join-Path $td ($e.format_retry.original -replace '/', '\'))) -and $x.Out -match '(?m)^format repair: failed in [0-9.]+ s; drift: 0 note\(s\)$') $e.validation_error
    $md = [IO.File]::ReadAllText((Join-Path $td ($e.reply -replace '/', '\')), $u8)
    Check 'TWICE' 'handoff: "Format repair: failed" line, the prose as the reply, no "Original reply" section' ($md -match '(?m)^Format repair: failed in' -and $md.Contains('**Q1.** The cache invalidation') -and -not $md.Contains('## Original reply (prose, before format repair)')) ''
}

# =============================================================== DRIFT: the repaired object drops content
if (Want 'DRIFT') {
    $r = New-Repo 'drift'
    $x = Consult $r @('-Prompt', 'x', '-Purpose', 'acceptance', '-ReplyName', 'dr') @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $drifted }
    $e = Last-Entry $r
    $dr = @($e.format_retry.drift)
    Check 'DRIFT' 'a repaired object that drops RC2, the prior finding F01-1 and changes the verdict -> succeeded, with the three drift notes (warnings only)' ($x.Code -eq 0 -and $e.structured -eq $true -and $e.format_retry.succeeded -and @($dr | Where-Object { $_ -eq 'requested checks differ: prose RC1, RC2, reply_markdown RC1' }).Count -eq 1 -and @($dr | Where-Object { $_ -eq 'finding id(s) named in the prose but absent from prior_findings/findings: F01-1' }).Count -eq 1 -and @($dr | Where-Object { $_ -eq 'verdict differs: prose HOLD, JSON ACCEPT' }).Count -eq 1) ($dr -join ' | ')
    Check 'DRIFT' 'console lists them: "drift: N note(s)" and one "  drift: ..." line each' ($x.Out -match ('(?m)^format repair: succeeded in [0-9.]+ s; drift: ' + $dr.Count + ' note\(s\)$') -and ([regex]::Matches($x.Out, '(?m)^  drift: ')).Count -eq $dr.Count) (Line $x.Out 'format repair')
}

# =============================================================== NONE: the cases that must not repair
if (Want 'NONE') {
    $r = New-Repo 'none'
    $rlog = Join-Path $work 'none-resume.log'
    $cases = [ordered]@{
        'short prose (10 words)'  = @(@('-Prompt', 'x', '-ReplyName', 'short'), @{ FAKE_CODEX_REPLY = $shortProse; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_LOG = $rlog })
        '-Raw'                    = @(@('-Prompt', 'x', '-ReplyName', 'raw', '-Raw'), @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_LOG = $rlog })
        '-Purpose chore'          = @(@('-Prompt', 'x', '-ReplyName', 'chore', '-Purpose', 'chore'), @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_LOG = $rlog })
        '-FormatRetry 0'          = @(@('-Prompt', 'x', '-ReplyName', 'off', '-FormatRetry', '0'), @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_LOG = $rlog })
        'unverified thread'       = @(@('-Prompt', 'x', '-ReplyName', 'nothread'), @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_LOG = $rlog; FAKE_CODEX_NOTHREAD = '1' })
        'codex exit 1'            = @(@('-Prompt', 'x', '-ReplyName', 'exit'), @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_LOG = $rlog; FAKE_CODEX_EXIT = '1' })
    }
    $bad = @()
    foreach ($k in $cases.Keys) {
        if (Test-Path $rlog) { Remove-Item $rlog }
        $o = Consult $r $cases[$k][0] $cases[$k][1]
        $e = Last-Entry $r
        if (-not ($e.PSObject.Properties['format_retry'] -and $null -eq $e.format_retry -and -not (Test-Path $rlog) -and $o.Out -notmatch 'format repair:')) { $bad += "$k -> format_retry=$($e.format_retry | ConvertTo-Json -Compress) resumed=$(Test-Path $rlog)" }
    }
    Check 'NONE' "no repair turn (format_retry null, no resume) for: $(@($cases.Keys) -join ', ')" ($bad.Count -eq 0) ($bad -join ' | ')
    $v = Consult $r @('-Prompt', 'x', '-ReplyName', 'valid') @{ FAKE_CODEX_REPLY = (File 'advise.json' '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'); FAKE_CODEX_RESUME_REPLY = $repaired; FAKE_CODEX_RESUME_LOG = $rlog }
    Check 'NONE' 'a valid first reply -> no repair (format_retry null)' ($v.Code -eq 0 -and $null -eq (Last-Entry $r).format_retry -and (Last-Entry $r).structured -eq $true) ''
}

# =============================================================== PANEL: members repair too
if (Want 'PANEL') {
    $r = New-Repo 'panel'
    $roster = File 'roster.json' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'
    $p = Consult $r @('-Panel', '-Prompt', 'x', '-Purpose', 'acceptance', '-ReplyName', 'pn') @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired } $roster
    $l = @(Ledger $r)
    Check 'PANEL' 'a panel member performs the repair too: both members structured after one repair turn each, exit 0' ($p.Code -eq 0 -and $l.Count -eq 2 -and @($l | Where-Object { $_.structured -eq $true -and $_.format_retry.succeeded -eq $true }).Count -eq 2) "$($l.Count) entries"
    $p0 = Consult (New-Repo 'panel-off') @('-Panel', '-Prompt', 'x', '-Purpose', 'acceptance', '-ReplyName', 'po', '-FormatRetry', '0') @{ FAKE_CODEX_REPLY = $proseFile; FAKE_CODEX_RESUME_REPLY = $repaired } $roster
    $l0 = @(Ledger (Join-Path $work 'panel-off'))
    Check 'PANEL' 'members inherit -FormatRetry 0: no repair, prose kept' ($l0.Count -eq 2 -and @($l0 | Where-Object { $null -eq $_.format_retry -and $_.structured -eq $false }).Count -eq 2) ''
}
# =============================================================== GATE: which prose is worth a repair turn (F21)
if (Want 'GATE') {
    $samples = @(
        @{ Name = '**Q<n>.** x2, 26 words'; Text = "**Q1.** The invalidation path is correct for single writers today.`n**Q2.** The retry path is still open and needs the generation re-check after the lock is taken again."; Sub = $true; N = 2 },
        @{ Name = 'Q<n>: style x2'; Text = "Q1: The invalidation path is correct for single writers and handles eviction.`nQ2: The retry path is still open and needs the generation counter re-check after the lock."; Sub = $true; N = 2 },
        @{ Name = '<n>) style x2'; Text = "1) The invalidation path is correct for single writers and handles eviction.`n2) The retry path is still open and needs the generation counter re-check after the lock."; Sub = $true; N = 2 },
        @{ Name = '**<n>.** and ### Q<n> styles'; Text = "**1.** The invalidation path is correct for single writers and handles eviction well.`n### Q2`nThe retry path is still open and needs the generation counter re-check after the lock."; Sub = $true; N = 2 },
        @{ Name = '12 words, two numbered answers -> too short'; Text = "**Q1.** Handled as described in the brief.`n**Q2.** Agree with the plan."; Sub = $false; N = 2; Reason = 'reply too short (12 words)' },
        @{ Name = 'one numbered answer, 30 words -> too short (floor 40)'; Text = "Q1. The invalidation path is correct for single writers and handles eviction well enough; the retry path is still open and needs the generation counter re-check after the lock is taken."; Sub = $false; N = 1; Reason = 'reply too short (31 words)' }
    )
    $bad = @()
    foreach ($c in $samples) {
        $g = Get-ProseGate -Text $c.Text
        $ok = ($g.Substantive -eq $c.Sub -and $g.Numbered -eq $c.N -and (-not $c.Reason -or $g.Reason -eq $c.Reason))
        if (-not $ok) { $bad += "$($c.Name): substantive=$($g.Substantive) numbered=$($g.Numbered) words=$($g.Words) reason='$($g.Reason)'" }
    }
    Check 'GATE' "Get-ProseGate: the numbered styles (**Q1.**, Q1:, 1), **1.**, ### Q1) and the floors (25 words + two answers, 40 + one)" ($bad.Count -eq 0) ($bad -join ' | ')
    $refusalText = ("I'm sorry, but I cannot help with reviewing this change set in the way the brief asks. " * 8).Trim()
    $gR = Get-ProseGate -Text $refusalText
    $gM = Get-ProseGate -Text ("I cannot find a defect in the retry path. " + ('Verdict: HOLD. RC1 - run the soak test. ' * 15))
    Check 'GATE' 'a refusal (starts with refusal phrasing, no numbered answer, no F/RC/Verdict marker) is not substantive; the same opening with markers is' ($gR.Substantive -eq $false -and $gR.Reason -eq 'reply looks like a refusal' -and $gR.Words -ge 120 -and $gM.Substantive -eq $true) "refusal words=$($gR.Words)"

    $r = New-Repo 'gate'
    $refFile = File 'refusal.md' $refusalText
    $x1 = Consult $r @('-Prompt', 'x', '-ReplyName', 'ref') @{ FAKE_CODEX_REPLY = $refFile; FAKE_CODEX_RESUME_REPLY = $repaired }
    $e1 = Last-Entry $r
    Check 'GATE' 'a 130-word refusal -> no repair turn, format_retry null, validation_error ends "(format repair not attempted: reply looks like a refusal)"' ($x1.Code -eq 0 -and $null -eq $e1.format_retry -and $e1.validation_error -match '\(format repair not attempted: reply looks like a refusal\)$') $e1.validation_error
    $tiny = File 'tiny.md' "**Q1.** Handled as described in the brief.`n**Q2.** Agree with the plan."
    $x2 = Consult $r @('-Prompt', 'x', '-ReplyName', 'tiny') @{ FAKE_CODEX_REPLY = $tiny; FAKE_CODEX_RESUME_REPLY = $repaired }
    $e2 = Last-Entry $r
    Check 'GATE' 'a 12-word "**Q1.** ... **Q2.** ..." reply -> no repair, "(format repair not attempted: reply too short (12 words))"' ($x2.Code -eq 0 -and $null -eq $e2.format_retry -and $e2.validation_error -match '\(format repair not attempted: reply too short \(12 words\)\)$') $e2.validation_error
    $thirty = File 'thirty.md' "Q1. The invalidation path is correct for single writers today and handles eviction.`nQ2. The retry path is still open; it needs the generation re-check after the lock."
    $x3 = Consult $r @('-Prompt', 'x', '-Purpose', 'acceptance', '-ReplyName', 'thirty') @{ FAKE_CODEX_REPLY = $thirty; FAKE_CODEX_RESUME_REPLY = $repaired }
    $e3 = Last-Entry $r
    Check 'GATE' 'a ~30-word Q1./Q2. answer -> the repair turn runs (format_retry.attempted)' ($x3.Code -eq 0 -and $e3.format_retry.attempted -eq $true) "words=$((Get-ProseGate -Text (Get-Content -Raw $thirty)).Words)"
}

# =============================================================== DRIFT5: a changed remedy in a SHORT sentence (F20)
if (Want 'DRIFT5') {
    $long = @(
        '**Q1.** The cache invalidation path is correct for single writers and handles the eviction race well enough for the current release plan.',
        '**Q2.** The retry path does not re-check the generation counter after it takes the lock again, so a stale entry can be served for one round.',
        '**Q3.** The eviction order is deterministic under test, but the production clock source makes it depend on wall time, which the tests do not model.',
        '**Q4.** The metrics hook counts hits before the lock is released, so the reported hit rate is slightly optimistic under heavy contention loads.',
        '**Q5.** The configuration loader accepts negative capacities and silently clamps them to zero, which hides operator mistakes in production files.',
        '**Q6.** The benchmark numbers in the brief were produced on a warm cache and do not represent the cold-start behaviour that users will see first.',
        'Remedy: re-check the generation counter right after taking the retry lock.'
    )
    $proseD = ($long -join "`n")
    $proseDFile = File 'prose-d5.md' $proseD
    $esc = { param($t) ($t -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n') }
    $changed = ($long[0..5] + @('Remedy: add a global mutex around the whole retry path instead.')) -join "`n"
    $objChanged = File 'd5-changed.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"' + (& $esc $changed) + '","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
    $objSame = File 'd5-same.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"' + (& $esc $proseD) + '","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
    $remedyLen = $long[6].Length
    $r = New-Repo 'drift5'
    $x = Consult $r @('-Prompt', 'x', '-ReplyName', 'd5') @{ FAKE_CODEX_REPLY = $proseDFile; FAKE_CODEX_RESUME_REPLY = $objChanged }
    $dr = @((Last-Entry $r).format_retry.drift)
    Check 'DRIFT5' "a changed remedy in a $remedyLen-char sentence (not among the five longest) -> '1 of the 7 prose sentences (>= 60 chars) are not in reply_markdown (first: ...)'" ($x.Code -eq 0 -and $remedyLen -ge 60 -and $remedyLen -le 100 -and @($dr | Where-Object { $_ -match "^1 of the 7 prose sentences \(>= 60 chars\) are not in reply_markdown \(first: 'remedy: re-check the generation counter right after taking t\.\.\.'\)$" }).Count -eq 1) ($dr -join ' | ')
    $y = Consult $r @('-Prompt', 'x', '-ReplyName', 'd5s') @{ FAKE_CODEX_REPLY = $proseDFile; FAKE_CODEX_RESUME_REPLY = $objSame }
    Check 'DRIFT5' 'an unchanged conversion of the same prose -> no drift note' ($y.Code -eq 0 -and (Last-Entry $r).format_retry.succeeded -and @((Last-Entry $r).format_retry.drift).Count -eq 0) (@((Last-Entry $r).format_retry.drift) -join ' | ')
}

# =============================================================== ORPHAN: a run stopped during its repair turn (F20/F21)
if (Want 'ORPHAN') {
    # (a) the recovery record names the saved prose while the repair turn runs
    $r = New-Repo 'orphan-live'
    $pend = Join-Path $r '.collab\t\.consult.pending.json'
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome; $env:CODEX_CONSULT_ROSTER = 'none'
    $env:FAKE_CODEX_REPLY = $proseFile; $env:FAKE_CODEX_RESUME_REPLY = $repaired; $env:FAKE_CODEX_HANG_ON = ' resume '
    $bg = Start-Process -FilePath $psExe -WorkingDirectory $r -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-CodexExe', $fake, '-Prompt', 'x', '-Purpose', 'acceptance', '-ReplyName', 'live', '-TimeoutSec', '8')
    Clear-TestEnv
    $env:CODEX_HOME = $savedCodexHome
    $mid = $null
    for ($i = 0; $i -lt 120; $i++) {
        $pr = Read-PendingFile -Path $pend
        if ($pr.Record -and [string](Get-PropertyValue $pr.Record 'original' '') -and $pr.Record.state -eq 'running') { $mid = $pr.Record; break }
        Start-Sleep -Milliseconds 250
    }
    $bg.WaitForExit()
    $origRel = if ($mid) { [string]$mid.original } else { '' }
    Check 'ORPHAN' 'during the repair turn the recovery record carries original (repo-relative .original.md, already on disk), first_reply, state running with the repair pid' ($mid -and $origRel -match '^\.collab/t/handoffs/\d\d-codex-live\.original\.md$' -and $mid.first_reply -eq 'usable prose (format repair in progress)' -and $mid.child_pid -gt 0 -and $mid.note -eq 'format repair turn' -and (Test-Path (Join-Path $r ($origRel -replace '/', '\')))) "original=$origRel"
    $el = Last-Entry $r
    Check 'ORPHAN' '... the repair timed out: prose kept, format_retry.succeeded false, the record removed at the end' ($el.format_retry.succeeded -eq $false -and $el.validation_error -match 'format repair failed: timeout after 8 s' -and -not (Test-Path $pend)) $el.validation_error

    # (b) a record left by a run stopped during its repair turn (simulated: dead pids)
    $dead = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'exit' -PassThru -WindowStyle Hidden
    $dead.WaitForExit()
    function Seed-Orphan {
        param([string]$Repo, [string]$State, $ChildPid, [string]$ChildStart, [switch]$NoOriginal)
        $rec = [ordered]@{ state = $State; n = 1; nn = '02'; reply = 'handoffs/02-codex-x.md'; consult_id = [guid]::NewGuid().ToString(); started = (Get-IsoTimestamp); pid = $dead.Id; host = [Environment]::MachineName; launcher = $fake; child_pid = $ChildPid; child_start_time = $ChildStart; survivors = [object[]]@(); note = 'format repair turn' }
        if (-not $NoOriginal) { $rec['original'] = '.collab/t/handoffs/02-codex-x.original.md'; $rec['first_reply'] = 'usable prose (format repair in progress)' }
        Write-JsonFile -Path (Join-Path $Repo '.collab\t\.consult.pending.json') -Object ([pscustomobject]$rec)
    }
    $note = 'a usable prose reply of that run exists at .collab/t/handoffs/02-codex-x.original.md; no ledger entry was written for it'
    $findingsPs = Join-Path $scripts 'codex-findings.ps1'
    function Findings-List { param([string]$Repo) Clear-TestEnv; $env:CODEX_HOME = $codexHome; $env:CODEX_CONSULT_ROSTER = 'none'; Push-Location $Repo; $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $findingsPs -Task t -List -All 2>&1 | ForEach-Object { "$_" }) -join "`n"; $ErrorActionPreference = $p; Pop-Location; Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome; return $o }
    $ro = New-Repo 'orphan-dead'
    Seed-Orphan $ro 'running' $dead.Id ''
    $lo = Findings-List $ro
    Check 'ORPHAN' 'codex-findings -List: the pending line names the saved prose' ($lo -match ('(?m)^pending: state=running, n=1, nn=02, .*; ' + [regex]::Escape($note) + '$')) ((($lo -split "`n") | Where-Object { $_ -match '^pending' }) -join '')
    $dd = Consult $ro @('-DryRun', '-Prompt', 'x')
    Check 'ORPHAN' 'dry run: the pending line names it' ($dd.Code -eq 0 -and (Line $dd.Out 'pending     :').Contains($note)) (Line $dd.Out 'pending     :')
    $xo = Consult $ro @('-Prompt', 'x', '-ReplyName', 'next') @{ FAKE_CODEX_REPLY = (File 'adv.json' '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}') }
    $eo = Last-Entry $ro
    $mdo = [IO.File]::ReadAllText((Join-Path $ro ".collab\t\$($eo.reply -replace '/', '\')"), $u8)
    Check 'ORPHAN' 'the next run consumes the reservation: console "recovered reservation ...; <note>" and the handoff header "Recovery record: ..." name the path' ($xo.Code -eq 0 -and $xo.Out -match ('(?m)^codex-consult: recovered reservation n=1, nn=02 .*' + [regex]::Escape($note)) -and $mdo -match ('(?m)^Recovery record: recovered reservation n=1, nn=02 .*' + [regex]::Escape($note))) (Line $xo.Out 'codex-consult: recovered')
    # a live repair process -> the refusal names it too
    $sleeper = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 120') -PassThru -WindowStyle Hidden
    try {
        $rl = New-Repo 'orphan-alive'
        Seed-Orphan $rl 'running' $sleeper.Id ([string](Get-ProcessStartIso -ProcessId $sleeper.Id))
        $xl = Consult $rl @('-Prompt', 'x', '-ReplyName', 'blocked') @{ FAKE_CODEX_REPLY = $proseFile }
    } finally { Stop-Process -Id $sleeper.Id -Force -ErrorAction SilentlyContinue }
    Check 'ORPHAN' 'a still-running repair process -> the refusal ends with the note' ($xl.Code -eq 1 -and $xl.First -match ("is still running .*; " + [regex]::Escape($note) + '\.$')) $xl.First
    # without the fields: as before
    $rn = New-Repo 'orphan-plain'
    Seed-Orphan $rn 'running' $dead.Id '' -NoOriginal
    $ln = Findings-List $rn
    $xn = Consult $rn @('-Prompt', 'x', '-ReplyName', 'plain') @{ FAKE_CODEX_REPLY = (File 'adv2.json' '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}') }
    Check 'ORPHAN' 'a record without original/first_reply prints as before (no note in -List or the recovery line)' ($ln -match '(?m)^pending: state=running' -and $ln -notmatch 'usable prose reply' -and $xn.Code -eq 0 -and $xn.Out -match '(?m)^codex-consult: recovered reservation n=1, nn=02' -and $xn.Out -notmatch 'usable prose reply') ((($ln -split "`n") | Where-Object { $_ -match '^pending' }) -join '')
}
} finally {
    Clear-TestEnv
    $env:CODEX_HOME = $savedCodexHome
    Remove-TestWork $work
}
Write-Host ("harness-format ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
