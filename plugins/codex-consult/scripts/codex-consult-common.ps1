<#
.SYNOPSIS
    Shared helpers for codex-consult.ps1 and codex-findings.ps1. Dot-source it:

        . (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

.DESCRIPTION
    Dot-sourcing runs this file in the caller's scope, so the $script: variables set
    here belong to the calling script. A caller may set $script:ToolName BEFORE
    dot-sourcing to change the prefix of Stop-WithError messages, and (wave 25)
    $script:StopWithErrorHook to a scriptblock that Stop-WithError runs with the refusal
    line before it exits (a detached run records it as its final status).

    Contents:
      * text/JSON I/O    Write-Utf8NoBom, Write-JsonFile, Read-SharedText
      * errors, git      Stop-WithError, Get-GitOutput, Invoke-GitCapture
      * paths            Resolve-RepoRoot, Resolve-CollabRoot, Get-RepoRelativePath
      * fingerprints     Get-FileSha256, Get-RevisionInfo, Get-ArtifactHashes,
                         Compare-TreeContent (wave 24c: the tree check by content, a moved
                         HEAD as revision_moved)
      * findings         Read-FindingsFile, Write-FindingsFile, Format-FindingLine,
                         Add-ReplyFindings
      * structured reply ConvertFrom-StructuredReply, Test-StructuredReply,
                         Format-StructuredSection, Format-StructuredStatusLine
      * format repair    Test-SubstantiveProse, Get-RepairEffort, Get-FormatRepairDrift
      * codex config     Get-CodexHome, Get-CodexConfigPath, Read-CodexConfigSubset
                         (constrained TOML scanner), Get-ProviderTable,
                         ConvertFrom-CodexConfigItems (-CodexConfig / codex_config rules)
      * reviewer         Resolve-ReviewerIdentity, New-ReviewerRecord,
                         Resolve-EffortPlan (effort vocabularies), Get-PeakStatus
                         (peak windows), Select-ParentThread (lineage-scoped parent)
      * engines          $script:Engines (codex | agy | muse), Get-EngineSpec,
                         Resolve-EngineLauncher, Resolve-EngineExeBinding,
                         Get-EngineCredential (agy: `agy models`; muse: auth.json key
                         names), New-EngineTurnOptions (the adapter contract),
                         Get-EngineLaunchBlock (muse: the billing guard),
                         Get-CmdArgvHazard, New-AgyArgv, ConvertTo-AgyStdin,
                         Read-AgyEvents, Get-AgyTurnOutcome, New-MuseArgv,
                         Read-MuseEvents, Get-MuseTurnOutcome, Get-MuseHarness,
                         Format-ReviewerLineage
      * availability     Resolve-CodexLauncher, Get-CodexLoginStatus (UTF-8),
                         Get-ProviderCredential, Get-ProviderFailureClass,
                         Get-RetryAfter (a provider's named reset time),
                         New-ProviderFailure, Get-EndpointHealth (usage limits with a
                         known reset time block until then), Get-ConsultClock,
                         Test-ContextOverflow and Get-FailureHint (wave 24b: a context-
                         window limit is capability, with its hint; wave 24c: quota wording
                         wins, the hint stored at classification - Get-ClassHint),
                         Get-FailureKind (wave 24c: a burst 429, out for 10 minutes)
      * continuation     (wave 24b) Get-KilledTurnFailure (the one classifier over a killed
                         turn's evidence; wave 24c: structured evidence and diagnostic stderr
                         lines only), Test-ContinuationReply (a first reply's checks)
      * reviewer roster  Get-RosterPath, Read-ReviewerRoster (fail-closed validation),
                         Find-RosterEntry, Get-PreflightVerdict, Format-QuotaWarning,
                         Select-RosterReviewer (the walk), Select-PanelMembers (-Panel),
                         Get-CachedReviewerIdentity / Get-CachedEndpointHealth (wave 24b:
                         one resolution per listing; wave 24c: New-ListingCache, ordinal),
                         Get-PanelPlan (the panel's endpoint-aware concurrency),
                         Get-PanelIgnorePrefixes (an agy member's siblings),
                         Format-RosterSkips; Find-ThreadEntry (-Thread lookup)
      * task lock        Enter-TaskLock, Exit-TaskLock (ownership, .consult.lock)
      * store commit     Enter-StoreCommit, Complete-StoreCommit, Exit-StoreCommit (the ONE
                         way to change findings.json / sessions.json: .consult.write.lock,
                         re-read, delta, write), Enter-WriteLock, Add-LedgerEntry
      * recovery record  Read-PendingFile, Write-PendingFile, Remove-PendingFile,
                         Test-PendingActive, Find-CodexProcesses, Get-PendingPaths,
                         Read-TaskPendingRecords (.consult.pending.json and the panel
                         members' .consult.pending-<NN>.json); (wave 28e)
                         New-UnverifiedEntries, Test-UnverifiedProcess (E19: Get-CommandLineGap)
      * processes        Stop-ProcessTree, ConvertTo-ProcArg, Format-Argv
      * detached runs    (wave 25, R12) Write-DetachedStatus, Get-DetachedBudget (D4),
                         Complete-DetachedRecord (D3), ConvertTo-DetachArgs /
                         ConvertFrom-DetachArgs; (wave 26, F07-3) the readers - Get-DetachedPaths,
                         New-DetachedMember, ConvertTo-DetachedRecord, Read-DetachedStatus,
                         Read-DetachedRuns, Get-DetachedJudgement (liveness: D5, D6, D11),
                         Format-DetachedListLine (codex-findings.ps1 -List), Get-DetachedPhrase
                         (the SessionStart hook) - and the small helpers they need live in
                         codex-consult-detached.ps1, dot-sourced below
      * companions       (wave 26, R14-R16) Get-PanelDefaultSize, ConvertTo-SlugList,
                         Get-EntryLab (the vendor table), Resolve-ReviewerMatcher and
                         Resolve-RequiredReviewers (-Require), Read-AllTaskRatings and
                         Get-RoutingScore (shared with codex-scoreboard.ps1), Get-PanelSeed,
                         Get-SlotUniforms, Invoke-PanelDraw, Select-PanelRouting,
                         Format-RoutingLines, Resolve-RoleFile, Select-RoleAssignment;
                         (wave 27) ConvertFrom-ReviewerMatcher (the one parser) and
                         Test-ReviewerMatch (the one comparison)
      * host             (wave 27, R13) the coordinator's host markers - Get-HostMarkerNames,
                         Hide-HostMarkers / Restore-HostMarkers (an engine child's start;
                         wave 28b: -TestVars, Test-TestVarName), Remove-HostMarkersFromStartInfo
                         (the probes); the coordinator - Get-CoordinatorHost (a hint; wave 28b:
                         Get-HostPluginRoots anchors the path), Resolve-CoordinatorIdentity
                         (CODEX_CONSULT_COORDINATOR), Test-CoordinatorReviewer,
                         Format-CoordinatorText, Format-CoordinatorWarning
      * telemetry        (wave 28, R17) Get-BridgeVersion, Get-TelemetryPaths, Get-TelemetryUrl,
                         Get-TelemetryInstanceId (the salted instance id), Get-TelemetryOutcome,
                         ConvertTo-TelemetryDetails (THE allowlist; wave 28b: the vendor table
                         $script:TelemetryVendors, Get-TelemetryVendor, Get-TelemetryModelToken;
                         R24: Get-TelemetryReviewerClass, Get-TelemetryPurpose - shared with the
                         rating event), New-TelemetryEvent, (R24) ConvertTo-TelemetryRatingDetails /
                         New-TelemetryRatingEvent (codex-findings.ps1 -Rate), Add-TelemetrySpoolLine,
                         Add-TelemetryEvent (the bridge's call AT a commit; -RatingMark: the rating
                         event), (R24) the rating backfill - Find-RatingLedgerEntry,
                         Set-RatingTelemetrySent, Invoke-TelemetryBackfillRatings (codex-telemetry.ps1
                         -BackfillRatings; a mark's telemetry_sent), Start-TelemetrySender (the allow-listed
                         environment: Get-TelemetrySenderEnvironment, Start-NoInheritProcess),
                         Show-TelemetryNotice, Invoke-TelemetryRequest / Invoke-TelemetrySend (the
                         8 s bound, the 429 rule), Enter-/Exit-TelemetryFlushLock,
                         Invoke-TelemetryFlush (the sender: 60 s, the D8 answers),
                         Get-TelemetrySpoolCounts, Get-TelemetryNotSpooled (wave 28e: one file
                         per producer - Get-TelemetryNotSpooledFiles, the flush's fold
                         Merge-TelemetryNotSpooled / Complete-TelemetryNotSpooledFold - E20:
                         .last first, then the deletes), Read-TelemetryLast,
                         Invoke-TelemetryComplaint (-Complain), Invoke-TelemetryForget (-Forget);
                         the switch - Get-TelemetrySwitch - lives in
                         codex-consult-detached.ps1 (the hook prints it)

    Windows PowerShell 5.1 and PowerShell 7 compatible, no external dependencies.
    Keep this file ASCII: Windows PowerShell reads a BOM-less script in the ANSI
    code page. Functions that end in `return , $array` hand back the array itself:
    assign their result directly - wrapping the call in @(...) nests the array.
#>

# PowerShell 5.1 has no $IsWindows; an undefined variable is $null there.
$script:OnWindows = if ($null -ne $IsWindows) { [bool]$IsWindows } else { $true }
$script:LegacyPS = ($PSVersionTable.PSVersion.Major -lt 6)
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:Invariant = [System.Globalization.CultureInfo]::InvariantCulture
if (-not $script:ToolName) { $script:ToolName = 'codex-consult' }
# (wave 26, F07-3) the small helpers and the detached-run readers, shared with the SessionStart
# hook (which dot-sources that file alone): Read-SharedText, Get-PropertyValue, ConvertTo-OneLine,
# Test-IsJsonObject, ConvertTo-JsonText, ConvertTo-WhenOffset, Get-GitOutput, Resolve-RepoRoot,
# Resolve-CollabRoot, Get-ProcessStartIso, Test-SameStartTime, Test-PidAlive, Read-DetachedRuns,
# Get-DetachedJudgement, Get-DetachedPhrase & co.
. (Join-Path $PSScriptRoot 'codex-consult-detached.ps1')

# Closed sets of the consult-reply v1 schema (schemas/consult-reply.schema.json).
$script:ReplyFields = @('schema_version', 'verdict', 'verdict_reason', 'reply_markdown', 'findings', 'prior_findings', 'unproven', 'first_run_checklist')
$script:FindingFields = @('severity', 'locations', 'claim', 'trigger', 'evidence', 'verification', 'remedy', 'supersedes')
$script:Verdicts = @('ACCEPT', 'HOLD', 'REJECT', 'ADVISE')
$script:Severities = @('blocker', 'major', 'minor', 'note')
$script:EvidenceKinds = @('read-code', 'ran-command', 'inferred', 'assumed')
$script:PriorStatuses = @('fixed', 'still-open', 'not-checked', 'unknown-id')
# Coordinator-owned statuses of a tracked finding (findings.json).
$script:FindingStatuses = @('proposed', 'implemented', 'verified', 'rejected', 'wontfix', 'superseded')
$script:OpenStatuses = @('proposed', 'implemented')

# ----------------------------------------------------------------------------- text + JSON I/O

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

# MoveFileExW for Windows PowerShell 5.1, whose .NET Framework has no File.Move with
# overwrite: compiled once per process on first use (Add-Type, ~0.2 s) and cached. $true
# when [CodexConsultNative]::MoveFileEx is available.
$script:NativeMoveReady = $null
function Test-NativeMove {
    if ($null -ne $script:NativeMoveReady) { return $script:NativeMoveReady }
    $script:NativeMoveReady = $false
    try {
        if (-not ('CodexConsultNative' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CodexConsultNative {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "MoveFileExW")]
    public static extern bool MoveFileEx(string existingFileName, string newFileName, int flags);
}
'@
        }
        $script:NativeMoveReady = $true
    } catch { }
    return $script:NativeMoveReady
}

# Replaces $Path with $Text (UTF-8, no BOM) atomically: the text is written and flushed
# to disk (FileStream.Flush($true)) in a temp file .<name>.<guid>.tmp NEXT TO the
# destination (same volume), which then replaces the destination in ONE rename:
#   PowerShell 7 (Windows, macOS, Linux)  [IO.File]::Move($tmp, $dst, $true) - on
#       Windows MoveFileEx(MOVEFILE_REPLACE_EXISTING), elsewhere rename(2)
#   Windows PowerShell 5.1                MoveFileExW(MOVEFILE_REPLACE_EXISTING |
#       MOVEFILE_WRITE_THROUGH) through Test-NativeMove; only if Add-Type fails, the old
#       path: File.Move when the destination does not exist, else File.Replace
#       (ReplaceFile - NOT one atomic step: a process killed inside it can leave the
#       destination missing and the new text in the temp file)
# A crash leaves either the old or the new file, never a truncated or a missing one (at
# worst a stray .<name>.<guid>.tmp next to it). A rename that keeps failing (a reader
# holding the destination open without FileShare.Delete) is retried, then the temp file
# is removed and the error thrown.
function Write-TextAtomic {
    param([string]$Path, [string]$Text)
    $full = [IO.Path]::GetFullPath($Path)
    $dir = [IO.Path]::GetDirectoryName($full)
    $tmp = Join-Path $dir ('.' + [IO.Path]::GetFileName($full) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $bytes = $script:Utf8NoBom.GetBytes($Text)
    $fs = New-Object System.IO.FileStream($tmp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.Flush($true)
    } finally { $fs.Dispose() }
    $lastError = $null
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            if (-not $script:LegacyPS) {
                [IO.File]::Move($tmp, $full, $true)
            } elseif (Test-NativeMove) {
                # MOVEFILE_REPLACE_EXISTING (0x1) | MOVEFILE_WRITE_THROUGH (0x8)
                if (-not [CodexConsultNative]::MoveFileEx($tmp, $full, 0x9)) {
                    throw (New-Object System.ComponentModel.Win32Exception([Runtime.InteropServices.Marshal]::GetLastWin32Error()))
                }
            } elseif (-not [IO.File]::Exists($full)) {
                [IO.File]::Move($tmp, $full)
            } else {
                # Fallback only when Add-Type failed (see above): not one atomic step.
                # $null would reach .NET as '' - NullString is a real null (no backup file).
                [IO.File]::Replace($tmp, $full, [System.Management.Automation.Language.NullString]::Value)
            }
            return
        } catch {
            # A reader holding the destination open without FileShare.Delete makes the
            # rename fail with a sharing violation; it is gone a moment later.
            $lastError = $_.Exception
            Start-Sleep -Milliseconds 250
        }
    }
    try { [IO.File]::Delete($tmp) } catch { }
    throw "could not replace '$full': $($lastError.Message)"
}

# JSON stores (sessions.json, findings.json): UTF-8 without BOM, LF line endings,
# replaced atomically. -InputObject, never the pipeline: piping an array into
# ConvertTo-Json unrolls it.
function Write-JsonFile {
    param([string]$Path, $Object)
    $json = ConvertTo-Json -InputObject $Object -Depth 20
    Write-TextAtomic -Path $Path -Text (($json -replace "`r`n", "`n") + "`n")
}

# ConvertFrom-Json that keeps a timestamp's recorded offset: PowerShell 7 turns ISO
# timestamps into LOCAL [datetime] (the offset a ledger recorded is lost, F15-2); from 7.5
# on, -DateKind Offset returns them as [DateTimeOffset] with that offset. Windows
# PowerShell 5.1 leaves them strings. (ConvertTo-Json writes a DateTimeOffset back as the
# same ISO text.)
$script:JsonDateKindOffset = $null
function ConvertFrom-JsonKeepOffset {
    param([string]$Text)
    if ($null -eq $script:JsonDateKindOffset) {
        $script:JsonDateKindOffset = [bool]((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind'))
    }
    if ($script:JsonDateKindOffset) { return (ConvertFrom-Json -InputObject $Text -DateKind Offset) }
    return (ConvertFrom-Json -InputObject $Text)
}

# Reads an existing JSON store. $null when the file does not exist. An EXISTING
# store that is empty, unreadable, unparseable or not a JSON object is corruption:
# refuse, never start over with a new store (that would silently drop history).
function Read-JsonStore {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $text = Read-SharedText -Path $Path
    $data = $null
    $why = ''
    if (-not $text.Trim()) {
        $why = 'it is empty or could not be read'
    } else {
        try { $data = ConvertFrom-JsonKeepOffset -Text $text } catch { $why = "it does not parse: $(($_.Exception.Message -replace '\s+', ' ').Trim())" }
        if (-not $why -and -not ($data -is [System.Management.Automation.PSCustomObject])) { $why = 'it is not a JSON object' }
    }
    if ($why) {
        Stop-WithError "refusing to use '$Path': $why. An existing store is never replaced by a new one - restore it (e.g. from git) or move it aside deliberately, then retry."
    }
    return $data
}

function Get-IsoTimestamp {
    param([datetime]$When = (Get-Date))
    return $When.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant)
}

# Prints the refusal and exits $Code: 1, or (wave 26, D7) 5 - a required reviewer is not
# available.
function Stop-WithError {
    param([string]$Message, [int]$Code = 1)
    Write-Host "$($script:ToolName): $Message" -ForegroundColor Red
    # (wave 25, R12, D3) a detached run records the refusal as its final status before it exits
    if ($script:StopWithErrorHook) { try { & $script:StopWithErrorHook "$($script:ToolName): $Message" $Code } catch { } }
    exit $Code
}

# (wave 27c, D14 / F32-10) A test hook's value: a CODEX_CONSULT_TEST_* variable (and the test clock
# CODEX_CONSULT_NOW) is honoured ONLY while CODEX_CONSULT_TEST_MODE=1 is set too - every harness sets
# it; without it the variable is ignored ('' here) and the run warns once (Get-IgnoredTestHooks), so
# a hook left in an operator's environment never changes a real consultation.
# (wave 28b, D10) the line every run in test mode says (console, warnings[])
$script:TestModeWarning = 'test mode is ON: test hooks are honoured'
function Test-TestMode {
    return ([string][Environment]::GetEnvironmentVariable('CODEX_CONSULT_TEST_MODE')).Trim() -eq '1'
}
function Get-TestHookValue {
    param([string]$Name)
    if (-not (Test-TestMode)) { return '' }
    return [string][Environment]::GetEnvironmentVariable($Name)
}
# The test hooks set in this process's environment that are IGNORED (no CODEX_CONSULT_TEST_MODE=1):
# their names, sorted ordinal (empty in test mode).
function Get-IgnoredTestHooks {
    if (Test-TestMode) { return , ([string[]]@()) }
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($k in @([Environment]::GetEnvironmentVariables().Keys)) {
        $n = [string]$k
        $u = $n.ToUpperInvariant()
        if (($u.StartsWith('CODEX_CONSULT_TEST_') -and $u -ne 'CODEX_CONSULT_TEST_MODE') -or $u -eq 'CODEX_CONSULT_NOW') {
            if (([string][Environment]::GetEnvironmentVariable($n)).Trim() -and -not $names.Contains($n)) { $names.Add($n) }
        }
    }
    $arr = [string[]]$names.ToArray()
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return , $arr
}

# ----------------------------------------------------------------------------- git

# Argument quoting: bare token when it is safe, otherwise wrap in double quotes and
# double any embedded quote. This is the Windows CRT rule, which is also what
# .NET's Process argument parser implements on macOS/Linux, so one form serves both.
# It is what survives the npm codex.cmd shim on Windows.
function ConvertTo-ProcArg {
    param([string]$Value)
    if ($Value -eq '-') { return $Value }
    if ($Value -match '^[A-Za-z0-9_.\-:\\/=]+$') { return $Value }
    return '"' + ($Value -replace '"', '""') + '"'
}

# Human-readable argv for the record in sessions.json.
function Format-Argv {
    param([string[]]$Argv)
    $parts = $Argv | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }
    return ($parts -join ' ')
}

# Runs git with the output captured as raw BYTES (NUL-separated `-z` output must not
# go through PowerShell's line splitting or a console code page). stdin is not
# redirected: on .NET Framework the child's stdin writer can emit a UTF-8 preamble
# (chcp 65001), so paths travel as arguments instead. Returns $null when git cannot
# be started, else { ExitCode; Bytes; Err (stderr as text) }.
function Invoke-GitCapture {
    param([string]$Root, [string[]]$GitArgs)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'git'
        $psi.WorkingDirectory = $Root
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        if ($null -ne $psi.PSObject.Properties['ArgumentList']) {
            # .NET Core / PowerShell 7: no quoting rules to get wrong (paths may hold
            # quotes or newlines outside Windows).
            foreach ($a in $GitArgs) { $psi.ArgumentList.Add($a) }
        } else {
            # .NET Framework = Windows, where paths cannot contain '"' or newlines.
            $psi.Arguments = (($GitArgs | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' ')
        }
        $p = [System.Diagnostics.Process]::Start($psi)
        try {
            $ms = New-Object System.IO.MemoryStream
            $copy = $p.StandardOutput.BaseStream.CopyToAsync($ms)
            $err = $p.StandardError.ReadToEndAsync()
            $p.WaitForExit()
            $copy.Wait()
            $null = $err.Wait(5000)
            return [pscustomobject]@{ ExitCode = $p.ExitCode; Bytes = $ms.ToArray(); Err = [string]$err.Result }
        } finally {
            $p.Dispose()
        }
    } catch {
        return $null
    }
}

# -Range (wave 24, T1): `git diff --shortstat <range> --` once, in the repository root - "the
# range changes N files, M lines" (M = insertions + deletions). { Range; Files; Insertions;
# Deletions; Lines; Error ('' or why the range is refused: not a revision range git knows here,
# an argument that could be read as an option, a single revision, git not runnable) }.
# (wave 24b, F08-8) Only a range of two revisions - base..head or base...head, both named - is
# measured: `git diff <revision>` would measure the WORKING TREE against that revision, a size
# that changes while the review runs and differs from what the reviewer reads.
function Get-RangeStat {
    param([string]$Root, [string]$Range)
    $r = [pscustomobject]@{ Range = $Range; Files = 0; Insertions = 0; Deletions = 0; Lines = 0; Error = '' }
    if (-not $Range -or $Range.StartsWith('-') -or $Range -match '[\s\x00-\x1f]') {
        $r.Error = "-Range '$Range' is not a git revision range (e.g. a1b2c3d..HEAD; no spaces, not starting with '-')"
        return $r
    }
    $m = [regex]::Match($Range, '^(?<base>.+?)(?<sep>\.\.\.?)(?<head>.+)$')
    if (-not $m.Success -or $m.Groups['head'].Value.Contains('..') -or $m.Groups['head'].Value.StartsWith('.')) {
        $r.Error = "-Range '$Range' is not a range of two revisions: pass base..head or base...head (e.g. a1b2c3d..HEAD) - a single revision would measure the working tree against it, which changes while the review runs"
        return $r
    }
    $cap = Invoke-GitCapture -Root $Root -GitArgs @('diff', '--shortstat', $Range, '--')
    if ($null -eq $cap) { $r.Error = "-Range '$Range': git could not be started in $Root"; return $r }
    if ($cap.ExitCode -ne 0) {
        $why = @(([string]$cap.Err) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) | Select-Object -First 1
        $r.Error = "-Range '$Range' is not a revision range git knows in $Root (git diff --shortstat: $(if ($why) { $why } else { "exit $($cap.ExitCode)" }))"
        return $r
    }
    $out = $script:Utf8NoBom.GetString($cap.Bytes)
    if ($out -match '(\d+) files? changed') { $r.Files = [int]$Matches[1] }
    if ($out -match '(\d+) insertions?\(\+\)') { $r.Insertions = [int]$Matches[1] }
    if ($out -match '(\d+) deletions?\(-\)') { $r.Deletions = [int]$Matches[1] }
    $r.Lines = $r.Insertions + $r.Deletions
    return $r
}

# ----------------------------------------------------------------------------- paths

# '/'-separated path of $Path relative to $Root; '' when they are the same
# directory; $null when $Path is not under $Root.
function Get-RepoRelativePath {
    param([string]$Root, [string]$Path)
    $cmp = if ($script:OnWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd([char]'\', [char]'/')
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([char]'\', [char]'/')
    if ($full.Equals($rootFull, $cmp)) { return '' }
    foreach ($sep in @('\', '/')) {
        $prefix = $rootFull + $sep
        if ($full.StartsWith($prefix, $cmp)) { return $full.Substring($prefix.Length).Replace('\', '/') }
    }
    return $null
}

# (wave 28b, D16) The day directories of Codex's session files (<root>/<yyyy>/<MM>/<dd>) that a run
# started at $StartedAt and looked at by $Now may have written to: every LOCAL calendar day from the
# start's to now's (Codex names them by the local date; a run across midnight looks at both days),
# invariant digits whatever the culture (a Buddhist or Hijri calendar never renames a year). string[].
function Get-LocalDayDirs {
    param([string]$Root, [datetime]$StartedAt, [datetime]$Now = (Get-Date))
    $toLocal = { param([datetime]$d) if ($d.Kind -eq [DateTimeKind]::Utc) { $d.ToLocalTime() } else { $d } }
    $from = (& $toLocal $StartedAt).Date
    $to = (& $toLocal $Now).Date
    if ($to -lt $from) { $x = $from; $from = $to; $to = $x }
    $days = New-Object System.Collections.Generic.List[datetime]
    for ($d = $from; $d -le $to -and $days.Count -lt 7; $d = $d.AddDays(1)) { $days.Add($d) }
    if ($days[$days.Count - 1] -ne $to) { $days.Add($to) }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($d in $days) { $out.Add((Join-Path (Join-Path (Join-Path $Root $d.ToString('yyyy', $script:Invariant)) $d.ToString('MM', $script:Invariant)) $d.ToString('dd', $script:Invariant))) }
    return , ([string[]]$out.ToArray())
}

# ----------------------------------------------------------------------------- hashing + fingerprint

function ConvertTo-HexString {
    param([byte[]]$Bytes)
    return ([BitConverter]::ToString($Bytes)).Replace('-', '').ToLowerInvariant()
}

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (ConvertTo-HexString $sha.ComputeHash($Bytes)) } finally { $sha.Dispose() }
}

# Streams the file, so a large built artifact is not loaded into memory.
function Get-FileSha256 {
    param([string]$Path)
    $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return (ConvertTo-HexString $sha.ComputeHash([System.IO.Stream]$fs)) } finally { $sha.Dispose() }
    } finally { $fs.Dispose() }
}

# Manifest framing: fields are separated by single spaces, the path is the rest of
# the line, a rename's source follows after a TAB. Escaping backslash, TAB, CR and LF
# makes every line unambiguous whatever the file name holds.
function ConvertTo-ManifestPath {
    param([string]$Path)
    return $Path.Replace('\', '\\').Replace("`t", '\t').Replace("`r", '\r').Replace("`n", '\n')
}

# Blob ids for the given repo-relative paths (regular files that exist), computed by
# `git hash-object -- <paths>` in batches that respect the Windows command-line
# limit. Paths travel as arguments, never via --stdin-paths (see Invoke-GitCapture),
# so a path holding a newline needs no special case. A batch that fails is retried
# one path at a time; a path that still fails gets 'unreadable'.
function New-PathMap {
    # Path-keyed maps are ordinal (case-sensitive): a.txt and A.txt are two files on
    # a case-sensitive filesystem. A PowerShell @{} would merge them.
    return , ([System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal))
}

function Get-GitBlobIds {
    param([string]$Root, [string[]]$Paths)
    $result = New-PathMap
    $batches = New-Object System.Collections.Generic.List[object]
    $current = New-Object System.Collections.Generic.List[string]
    $chars = 0
    foreach ($p in $Paths) {
        if ($current.Count -gt 0 -and ($chars + $p.Length + 3) -gt 24000) {
            $batches.Add($current.ToArray())
            $current = New-Object System.Collections.Generic.List[string]
            $chars = 0
        }
        $current.Add($p)
        $chars += $p.Length + 3
    }
    if ($current.Count -gt 0) { $batches.Add($current.ToArray()) }
    foreach ($batch in $batches) {
        $ids = $null
        $run = Invoke-GitCapture -Root $Root -GitArgs (@('hash-object', '--') + $batch)
        if ($run -and $run.ExitCode -eq 0) {
            $lines = @(($script:Utf8NoBom.GetString($run.Bytes) -split "`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($lines.Count -eq $batch.Count) { $ids = $lines }
        }
        for ($i = 0; $i -lt $batch.Count; $i++) {
            if ($ids) { $result[$batch[$i]] = $ids[$i]; continue }
            $one = Invoke-GitCapture -Root $Root -GitArgs @('hash-object', '--', $batch[$i])
            $id = 'unreadable'
            if ($one -and $one.ExitCode -eq 0) {
                $text = $script:Utf8NoBom.GetString($one.Bytes).Trim()
                if ($text) { $id = $text }
            }
            $result[$batch[$i]] = $id
        }
    }
    return , $result
}

# File modes of tracked paths that differ from HEAD, from `git diff --raw -z HEAD`
# (worktree against HEAD; with core.filemode=false git takes the executable bit from
# the index). Value: '100644' when the mode is unchanged, '100644>100755' when it
# changed, '000000>100644' for a path new since HEAD, '100644>000000' for a deletion.
function Get-GitModeMap {
    param([string]$Root)
    $map = New-PathMap
    $run = Invoke-GitCapture -Root $Root -GitArgs @('--no-optional-locks', 'diff', '--raw', '-z', '--no-renames', '--no-ext-diff', '--no-abbrev', 'HEAD')
    if (-not $run -or $run.ExitCode -ne 0) { return , $map }
    $tokens = $script:Utf8NoBom.GetString($run.Bytes).Split([char]0)
    $i = 0
    while ($i -lt $tokens.Length - 1) {
        $meta = $tokens[$i]
        if (-not $meta.StartsWith(':')) { $i++; continue }
        $path = $tokens[$i + 1]
        $i += 2
        $parts = $meta.Substring(1).Split(' ')
        if ($parts.Length -lt 2) { continue }
        $mode = $parts[0]
        if ($parts[0] -ne $parts[1]) { $mode = "$($parts[0])>$($parts[1])" }
        $map[$path] = $mode
    }
    return , $map
}

# Revision fingerprint of the working tree (T2). tree_sha256 is the SHA-256 of a
# deterministic manifest:
#
#     base <full sha, or 'none' before the first commit>
#     <XY> <mode> <blob id | deleted | dir> <path>[<TAB><rename source>]
#
# one line per entry of `git status --porcelain=v1 -uall -z` (ignored files are not
# listed by git status, so they are outside the fingerprint by definition), sorted by
# path (ordinal), LF-joined with a trailing LF. The path is part of every line, so a
# rename changes the value even when the content does not. <mode> comes from
# Get-GitModeMap for tracked entries ('=' when git diff HEAD does not list the path,
# i.e. the worktree matches HEAD there); untracked entries get 'u' (mode not
# recorded). Entries under the
# collaboration directory are excluded: the consultation's own output must not move
# the fingerprint. A submodule or nested repository is recorded as 'dir' and not
# recursed. Every omission is spelled out in fingerprint_note. No git -> tree_sha256
# '' and fingerprint_note 'no git'. changed_files and dirty count the manifest
# entries, i.e. also without the collaboration directory.
# git status runs with --no-optional-locks, so computing a fingerprint never writes
# to the repository (not even an index refresh) - -DryRun stays write-free.
# (wave 24c) content_sha256 / content: the CONTENT fingerprint the tree check during a run
# compares (Compare-TreeContent) - every tracked file's blob (`git ls-files -s -z`, the index's
# blob ids; a path git status lists takes its worktree blob instead, or is gone when deleted) and
# every untracked file's blob, under the same exclusions (the collab directory, ignored files; a
# submodule is its gitlink, 'dir' once changed), as "<blob> <path>" lines sorted by path. It
# depends on file contents only - never on HEAD, the commit id or the index's metadata (what is
# staged, file modes): a commit, a moved HEAD or a `git add` that leaves every file as it was
# leaves it unchanged. content_sha256 '' (and content $null) when ls-files fails or without git.
function Get-RevisionInfo {
    param([string]$Root, [string]$CollabRoot = '')
    $info = [pscustomobject]@{
        base_commit       = 'unknown'
        short_sha         = 'unknown'
        dirty             = $false
        reviewed_revision = 'unknown'
        tree_sha256       = ''
        changed_files     = 0
        fingerprint_note  = 'no git'
        manifest          = ''
        content_sha256    = ''
        content           = $null
    }
    $status = Invoke-GitCapture -Root $Root -GitArgs @('--no-optional-locks', 'status', '--porcelain=v1', '-uall', '-z')
    if (-not $status -or $status.ExitCode -ne 0) { return $info }

    $notes = New-Object System.Collections.Generic.List[string]
    $head = Get-GitOutput -Root $Root -GitArgs @('rev-parse', '--verify', '-q', 'HEAD')
    $base = 'none'
    if ($head) {
        $base = ([string]@($head)[0]).Trim()
        $info.base_commit = $base
        $short = Get-GitOutput -Root $Root -GitArgs @('rev-parse', '--short', 'HEAD')
        if ($short) { $info.short_sha = ([string]@($short)[0]).Trim() }
    } else {
        $notes.Add('no commits yet')
    }

    $collabRel = $null
    if ($CollabRoot) {
        $collabRel = Get-RepoRelativePath -Root $Root -Path $CollabRoot
        if ($null -eq $collabRel) { $notes.Add('collab dir outside the repository') }
        elseif ($collabRel -eq '') { $notes.Add('collab dir is the repository root: nothing excluded'); $collabRel = $null }
    }
    $cmp = if ($script:OnWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

    # Parse the NUL-separated entries: "XY <path>", and for a rename or copy the
    # source path follows as the next NUL-terminated field.
    $tokens = $script:Utf8NoBom.GetString($status.Bytes).Split([char]0)
    $entries = New-Object System.Collections.Generic.List[object]
    $excluded = 0
    $i = 0
    while ($i -lt $tokens.Length) {
        $tok = $tokens[$i]
        $i++
        if ($tok.Length -lt 4) { continue }
        $xy = $tok.Substring(0, 2)
        $path = $tok.Substring(3)
        $orig = $null
        if ($xy[0] -ceq 'R' -or $xy[0] -ceq 'C' -or $xy[1] -ceq 'R' -or $xy[1] -ceq 'C') {
            if ($i -lt $tokens.Length) { $orig = $tokens[$i]; $i++ }
        }
        if ($collabRel -and ($path.Equals($collabRel, $cmp) -or $path.StartsWith($collabRel + '/', $cmp))) {
            $excluded++
            continue
        }
        $entries.Add([pscustomobject]@{ XY = $xy; Path = $path; Orig = $orig; Blob = ''; Mode = 'u' })
    }

    $modeMap = New-PathMap
    if ($head) { $modeMap = Get-GitModeMap -Root $Root }
    else { $notes.Add('tracked file modes not recorded (no HEAD to compare with)') }
    foreach ($e in $entries) {
        if ($e.XY -eq '??' -or -not $head) { continue }
        if ($modeMap.ContainsKey($e.Path)) { $e.Mode = $modeMap[$e.Path] } else { $e.Mode = '=' }
    }

    $toHash = New-Object System.Collections.Generic.List[string]
    $dirs = 0
    foreach ($e in $entries) {
        $full = [IO.Path]::Combine($Root, $e.Path)
        if ([IO.Directory]::Exists($full)) { $e.Blob = 'dir'; $dirs++ }
        elseif ([IO.File]::Exists($full)) { $toHash.Add($e.Path) }
        else { $e.Blob = 'deleted' }
    }
    if ($toHash.Count -gt 0) {
        $ids = Get-GitBlobIds -Root $Root -Paths $toHash.ToArray()
        foreach ($e in $entries) {
            if ($e.Blob) { continue }
            $id = $null
            if ($ids.TryGetValue($e.Path, [ref]$id)) { $e.Blob = $id } else { $e.Blob = 'unreadable' }
        }
    }
    $unreadable = @($entries | Where-Object { $_.Blob -eq 'unreadable' }).Count

    $keys = New-Object System.Collections.Generic.List[string]
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($e in $entries) {
        $line = $e.XY + ' ' + $e.Mode + ' ' + $e.Blob + ' ' + (ConvertTo-ManifestPath $e.Path)
        if ($null -ne $e.Orig) { $line += "`t" + (ConvertTo-ManifestPath $e.Orig) }
        $keys.Add($e.Path + [char]0 + $line)
        $lines.Add($line)
    }
    $keyArr = $keys.ToArray()
    $lineArr = $lines.ToArray()
    [Array]::Sort($keyArr, $lineArr, [StringComparer]::Ordinal)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("base $base`n")
    foreach ($l in $lineArr) { [void]$sb.Append($l + "`n") }
    $manifest = $sb.ToString()

    if ($collabRel) { $notes.Add("collab dir '$collabRel' excluded ($excluded entries)") }
    $notes.Add('ignored files excluded')
    $notes.Add('untracked file modes not recorded')
    if ($dirs -gt 0) { $notes.Add("submodules not recursed ($dirs directory entries)") }
    else { $notes.Add('submodules not recursed') }
    if ($unreadable -gt 0) { $notes.Add("$unreadable files unreadable") }

    # (wave 24c) the content fingerprint: the index's blob of every tracked path, then what git
    # status says about the worktree (its blob, 'dir', or gone), then the untracked files
    $ls = Invoke-GitCapture -Root $Root -GitArgs @('--no-optional-locks', 'ls-files', '-s', '-z')
    if ($ls -and $ls.ExitCode -eq 0) {
        $content = New-PathMap
        foreach ($rec in $script:Utf8NoBom.GetString($ls.Bytes).Split([char]0)) {
            # "<mode> <object> <stage><TAB><path>"
            $tab = $rec.IndexOf([char]9)
            if ($tab -lt 0) { continue }
            $meta = $rec.Substring(0, $tab).Split(' ')
            $p = $rec.Substring($tab + 1)
            if ($meta.Length -lt 2 -or -not $p) { continue }
            if ($collabRel -and ($p.Equals($collabRel, $cmp) -or $p.StartsWith($collabRel + '/', $cmp))) { continue }
            $content[$p] = $meta[1]
        }
        foreach ($e in $entries) {
            if ($e.Blob -eq 'deleted') { [void]$content.Remove($e.Path) } else { $content[$e.Path] = $e.Blob }
        }
        $contentKeys = [string[]]@($content.Keys)
        [Array]::Sort($contentKeys, [StringComparer]::Ordinal)
        $csb = New-Object System.Text.StringBuilder
        foreach ($k in $contentKeys) { [void]$csb.Append($content[$k] + ' ' + (ConvertTo-ManifestPath $k) + "`n") }
        $info.content_sha256 = Get-Sha256Hex -Bytes ($script:Utf8NoBom.GetBytes($csb.ToString()))
        $info.content = $content
    }

    $info.manifest = $manifest
    $info.tree_sha256 = Get-Sha256Hex -Bytes ($script:Utf8NoBom.GetBytes($manifest))
    $info.changed_files = $entries.Count
    $info.dirty = ($entries.Count -gt 0)
    $info.reviewed_revision = $info.short_sha
    if ($info.dirty) { $info.reviewed_revision = "$($info.short_sha) + uncommitted" }
    $info.fingerprint_note = ($notes.ToArray() -join '; ')
    return $info
}

# The paths whose manifest lines (Get-RevisionInfo .manifest) differ between two
# fingerprints: a file that appeared, disappeared or changed (content, mode, status), in
# manifest order, each once. The agy engine's tree check names them (A17).
function Get-ManifestChanges {
    param([string]$Before, [string]$After)
    $b = @{}
    $a = @{}
    foreach ($l in @(([string]$Before) -split "`n")) { if ($l -and -not $l.StartsWith('base ')) { $b[$l] = $true } }
    foreach ($l in @(([string]$After) -split "`n")) { if ($l -and -not $l.StartsWith('base ')) { $a[$l] = $true } }
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($l in @($b.Keys) + @($a.Keys)) {
        if ($b.ContainsKey($l) -and $a.ContainsKey($l)) { continue }
        # "XY mode blob path[<TAB>orig]"
        $parts = $l.Split(' ', 4)
        $p = if ($parts.Count -ge 4) { $parts[3].Split("`t")[0] } else { $l }
        if (-not $paths.Contains($p)) { $paths.Add($p) }
    }
    $sorted = [string[]]$paths.ToArray()
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return , $sorted
}

# (wave 24c) Did the working tree change while a reviewer ran? By CONTENT (Get-RevisionInfo
# content_sha256): the review binding's tree_sha256 also moves with HEAD, the staged state and file
# modes - a coordinator committing the collab files while a panel member ran failed that member
# with "the working tree changed during the run ...: 0 files" (the live ledger, 2026-09-26: HEAD
# moved, no file changed). { Changed; Paths (every path whose content appeared, disappeared or
# changed, ordinal order); RevisionMoved ('' or "<old base_commit> -> <new base_commit>": HEAD
# moved - informational (ledger revision_moved), never a tree change by itself) }. Without a
# content fingerprint on either side (git ls-files failed) the tree fingerprints decide, as before.
function Compare-TreeContent {
    param($Before, $After)
    $r = [pscustomobject]@{ Changed = $false; Paths = [string[]]@(); RevisionMoved = '' }
    $bc = [string](Get-PropertyValue $Before 'content_sha256' '')
    $ac = [string](Get-PropertyValue $After 'content_sha256' '')
    if ($bc -and $ac) {
        if ($bc -cne $ac) {
            $r.Changed = $true
            $names = New-Object System.Collections.Generic.List[string]
            $b = $Before.content
            $a = $After.content
            foreach ($k in @($b.Keys)) {
                $v = $null
                if (-not $a.TryGetValue($k, [ref]$v) -or $v -cne $b[$k]) { $names.Add($k) }
            }
            foreach ($k in @($a.Keys)) { if (-not $b.ContainsKey($k)) { $names.Add($k) } }
            $sorted = [string[]]$names.ToArray()
            [Array]::Sort($sorted, [StringComparer]::Ordinal)
            $r.Paths = $sorted
        }
    } elseif ([string]$Before.tree_sha256 -cne [string]$After.tree_sha256) {
        $r.Changed = $true
        $r.Paths = [string[]](Get-ManifestChanges -Before $Before.manifest -After $After.manifest)
    }
    $bb = [string](Get-PropertyValue $Before 'base_commit' '')
    $ab = [string](Get-PropertyValue $After 'base_commit' '')
    if ($Before.tree_sha256 -and $After.tree_sha256 -and $bb -cne $ab) { $r.RevisionMoved = "$bb -> $ab" }
    return $r
}

# Relative path ('/'-separated) -> "<length>|<sha256>" of EVERY file under $Dir, recursively
# (0.4.0 wave 18: the whole collab root - every task's stores findings.json / sessions.json /
# state.md and handoffs - which lies outside the tree fingerprint). Left out: the bridge's
# own lock and recovery files (a name starting with .consult., and the atomic-write temp
# ..consult.*), .git directories, and directories that are reparse points (a junction or a
# symlink is not followed). An absent directory is an empty snapshot.
function Get-CollabSnapshot {
    param([string]$Dir)
    # ordinal keys: a.md and A.md are two files on a case-sensitive filesystem
    $snap = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    if (-not $Dir -or -not [IO.Directory]::Exists($Dir)) { return $snap }
    $root = [IO.Path]::GetFullPath($Dir).TrimEnd([char]'\', [char]'/')
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        $info = New-Object System.IO.DirectoryInfo($d)
        $files = @()
        $subdirs = @()
        try { $files = @($info.GetFiles()); $subdirs = @($info.GetDirectories()) } catch { continue }
        foreach ($f in $files) {
            if ($f.Name.StartsWith('.consult.', [StringComparison]::OrdinalIgnoreCase) -or $f.Name.StartsWith('..consult.', [StringComparison]::OrdinalIgnoreCase)) { continue }
            $rel = $f.FullName.Substring($root.Length).TrimStart([char]'\', [char]'/').Replace('\', '/')
            $snap[$rel] = "$($f.Length)|$(Get-FileSha256OrMissing -Path $f.FullName)"
        }
        foreach ($s in $subdirs) {
            if ($s.Name -eq '.git') { continue }
            if (($s.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            $stack.Push($s.FullName)
        }
    }
    return $snap
}

# The paths that are new, gone or changed between two Get-CollabSnapshot results, except
# those starting with one of $IgnorePrefixes (the files the run writes itself).
function Compare-DirectorySnapshot {
    param([hashtable]$Before, [hashtable]$After, [string[]]$IgnorePrefixes = @())
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($n in @(@($Before.Keys) + @($After.Keys) | Select-Object -Unique)) {
        $skip = $false
        foreach ($pfx in @($IgnorePrefixes)) { if ($pfx -and $n.StartsWith($pfx, [StringComparison]::OrdinalIgnoreCase)) { $skip = $true } }
        if ($skip) { continue }
        if ($Before.ContainsKey($n) -and $After.ContainsKey($n) -and $Before[$n] -eq $After[$n]) { continue }
        $names.Add($n)
    }
    $sorted = [string[]]$names.ToArray()
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return , $sorted
}

# SHA-256 of a file, or 'missing' when it no longer exists / cannot be read (used
# for the after-run rehash of the brief and the artifacts).
function Get-FileSha256OrMissing {
    param([string]$Path)
    try {
        if (-not [IO.File]::Exists($Path)) { return 'missing' }
        return (Get-FileSha256 -Path $Path)
    } catch { return 'missing' }
}

# Built artifacts to bind a review to: resolves each path (as given, relative to one
# of $Bases or absolute) to { path = as given; full = absolute path }. A missing
# artifact stops the run - the caller asked to bind the review to it, silently
# skipping it would defeat the binding. Hashing happens separately (under the task
# lock, and again after the run). Emits one object per artifact; collect with @(...).
function Resolve-ArtifactPaths {
    param([string[]]$Paths, [string[]]$Bases)
    foreach ($raw in @($Paths)) {
        if (-not $raw) { continue }
        $resolved = $null
        if ([IO.Path]::IsPathRooted($raw)) {
            if (Test-Path -LiteralPath $raw -PathType Leaf) { $resolved = $raw }
        } else {
            foreach ($b in $Bases) {
                $candidate = Join-Path $b $raw
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $resolved = $candidate; break }
            }
        }
        if (-not $resolved) {
            $looked = if ([IO.Path]::IsPathRooted($raw)) { $raw } else { (@($Bases) | Select-Object -Unique) -join ', ' }
            Stop-WithError "artifact '$raw' not found (looked in: $looked); a review cannot be bound to a missing artifact."
        }
        [pscustomobject]@{ path = $raw; full = (Resolve-Path -LiteralPath $resolved).Path }
    }
}

# { path; full; sha256 } per resolved artifact (from Resolve-ArtifactPaths). `full`
# travels with the hash so the after-run rehash reads exactly the same file - never
# a lookup by name (a.bin and A.bin are two files on a case-sensitive filesystem).
function Get-ArtifactHashes {
    param($Artifacts)
    foreach ($a in @($Artifacts | Where-Object { $null -ne $_ })) {
        [pscustomobject]@{ path = $a.path; full = $a.full; sha256 = (Get-FileSha256OrMissing -Path $a.full) }
    }
}

# ----------------------------------------------------------------------------- findings.json

function New-FindingsStore {
    param([string]$Task)
    return [pscustomobject]@{ task_id = $Task; findings = [object[]]@() }
}

# A missing findings.json is a new store; an existing one that is empty or does not
# parse is corruption (Read-JsonStore refuses).
function Read-FindingsFile {
    param([string]$Path, [string]$Task)
    $data = Read-JsonStore -Path $Path
    if ($null -eq $data) { return (New-FindingsStore -Task $Task) }
    if (-not $data.PSObject.Properties['findings']) {
        Stop-WithError "refusing to use '$Path': it has no findings array. Restore it (e.g. from git) or move it aside deliberately, then retry."
    }
    $data.findings = [object[]]@($data.findings | Where-Object { $null -ne $_ })
    return $data
}

function Write-FindingsFile {
    param([string]$Path, $Store)
    $Store.findings = [object[]]@($Store.findings | Where-Object { $null -ne $_ })
    Write-JsonFile -Path $Path -Object $Store
}

# Next consult number n and handoff number NN. No number that anything on disk
# already names may be handed out again:
#   n  > the ledger's entry count and every entry's n, every finding's
#        source.consult, every reviewer_checks[].consult, and the n of every
#        interrupted run's recovery record ($Leftovers: the records of
#        .consult.pending.json and the panel members' .consult.pending-<NN>.json);
#   NN > every handoff file "<NN>-..." (two OR MORE digits, so 100-... counts),
#        every finding id F<NN>-<k>, and the nn of every such recovery record.
# Per record (Items, in the order given): Recovered is set when its n has no ledger entry
# (a run that stopped before its commit point); the caller reports each. Recovered /
# RecoveredN / RecoveredNn of the result: any record recovered / the first record's numbers.
function Get-NextNumbers {
    param($Consults, $Store, [string]$HandoffsDir, [Alias('Leftover')] [object[]]$Leftovers = @())
    $ledgerNs = @{}
    $maxN = @($Consults).Count
    foreach ($c in @($Consults | Where-Object { $null -ne $_ })) {
        $v = 0
        if ($c.PSObject.Properties['n'] -and [int]::TryParse([string]$c.n, [ref]$v)) {
            $ledgerNs[$v] = $true
            if ($v -gt $maxN) { $maxN = $v }
        }
    }
    $maxNn = 0
    if ($HandoffsDir -and (Test-Path -LiteralPath $HandoffsDir)) {
        foreach ($file in @(Get-ChildItem -LiteralPath $HandoffsDir -File -ErrorAction SilentlyContinue)) {
            $v = 0
            if ($file.Name -match '^(\d{2,})-' -and [int]::TryParse($Matches[1], [ref]$v) -and $v -gt $maxNn) { $maxNn = $v }
        }
    }
    if ($Store) {
        foreach ($f in @($Store.findings | Where-Object { $null -ne $_ })) {
            $v = 0
            $src = Get-PropertyValue $f 'source' $null
            if ($src -and [int]::TryParse([string](Get-PropertyValue $src 'consult' ''), [ref]$v) -and $v -gt $maxN) { $maxN = $v }
            foreach ($rc in @(Get-PropertyValue $f 'reviewer_checks' @())) {
                $v = 0
                if ($rc -and [int]::TryParse([string](Get-PropertyValue $rc 'consult' ''), [ref]$v) -and $v -gt $maxN) { $maxN = $v }
            }
            $v = 0
            if ([string](Get-PropertyValue $f 'id' '') -match '^F(\d{2,})-\d+$' -and [int]::TryParse($Matches[1], [ref]$v) -and $v -gt $maxNn) { $maxNn = $v }
        }
    }
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($leftover in @($Leftovers | Where-Object { $null -ne $_ })) {
        $recovered = $false
        $recN = $null
        $recNn = ''
        $v = 0
        if ([int]::TryParse([string](Get-PropertyValue $leftover 'n' ''), [ref]$v) -and $v -gt 0) {
            $recN = $v
            if (-not $ledgerNs.ContainsKey($v)) { $recovered = $true }
            if ($v -gt $maxN) { $maxN = $v }
        }
        $w = 0
        $leftNn = [string](Get-PropertyValue $leftover 'nn' '')
        if ($leftNn -and [int]::TryParse($leftNn, [ref]$w) -and $w -gt 0) {
            $recNn = $leftNn
            if ($w -gt $maxNn) { $maxNn = $w }
            if ($null -eq $recN) { $recovered = $true }
        }
        $items.Add([pscustomobject]@{ N = $recN; Nn = $recNn; Recovered = $recovered })
    }
    $first = if ($items.Count -gt 0) { $items[0] } else { [pscustomobject]@{ N = $null; Nn = ''; Recovered = $false } }
    return [pscustomobject]@{
        N           = $maxN + 1
        Nn          = ('{0:D2}' -f ($maxNn + 1))
        Recovered   = [bool](@($items | Where-Object { $_.Recovered }).Count -gt 0)
        RecoveredN  = $first.N
        RecoveredNn = $first.Nn
        Items       = [object[]]$items.ToArray()
    }
}

# Appends $Item to the array property $Name of $Object (creating it when missing) and
# keeps the value an [object[]] - a one-element array must stay an array in JSON.
function Add-ArrayItem {
    param($Object, [string]$Name, $Item)
    if ($Object.PSObject.Properties[$Name]) {
        $existing = @($Object.$Name | Where-Object { $null -ne $_ })
        $Object.$Name = [object[]]($existing + @($Item))
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue ([object[]]@($Item))
    }
}

# "claim" -> "claim." ; leaves text that already ends in . ! ? alone.
function Close-Sentence {
    param([string]$Text)
    $t = ConvertTo-OneLine $Text
    if (-not $t) { return '' }
    if ($t -match '[.!?]$') { return $t }
    return $t + '.'
}

# "src/x.rs:120, docs/a.md" ; "(no location)" for an empty list.
function Format-Locations {
    param($Locations, [switch]$Code)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($l in @($Locations | Where-Object { $null -ne $_ })) {
        $p = [string](Get-PropertyValue $l 'path' '')
        $line = Get-PropertyValue $l 'line' $null
        $text = $p
        if ($null -ne $line -and "$line" -ne '') { $text = "${p}:$line" }
        if (-not $text) { continue }
        if ($Code) { $text = '`' + $text + '`' }
        $parts.Add($text)
    }
    if ($parts.Count -eq 0) { return '(no location)' }
    return ($parts.ToArray() -join ', ')
}

# One line per finding for `codex-findings.ps1 -List`:
#   id  status  severity  location  claim (first 100 chars)
function Format-FindingLine {
    param($Finding, [switch]$Orphan)
    $id = [string](Get-PropertyValue $Finding 'id' '?')
    $status = [string](Get-PropertyValue $Finding 'status' '?')
    $severity = [string](Get-PropertyValue $Finding 'severity' '?')
    $locs = @((Get-PropertyValue $Finding 'locations' @()) | Where-Object { $null -ne $_ })
    $loc = '-'
    if ($locs.Count -gt 0) {
        $loc = Format-Locations -Locations @($locs[0])
        if ($locs.Count -gt 1) { $loc += " (+$($locs.Count - 1))" }
    }
    $claim = ConvertTo-OneLine ([string](Get-PropertyValue $Finding 'claim' ''))
    if ($claim.Length -gt 100) { $claim = $claim.Substring(0, 100) }
    $line = '{0,-9} {1,-11} {2,-7} {3,-28} {4}' -f $id, $status, $severity, $loc, $claim
    if ($Orphan) { $line += '  [ORPHAN: no ledger entry for its consult]' }
    return $line
}

# ----------------------------------------------------------------------------- structured reply

function Test-IsJsonString {
    param($Value)
    # PowerShell 7's ConvertFrom-Json turns ISO-date-looking strings into [datetime]
    # ([DateTimeOffset] with -DateKind Offset).
    return (($Value -is [string]) -or ($Value -is [datetime]) -or ($Value -is [DateTimeOffset]))
}

function Test-IsJsonArray {
    param($Value)
    return (($null -ne $Value) -and ($Value -is [array]))
}

function Test-IsJsonInteger {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte] -or
        $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [sbyte]) { return $true }
    if ($Value.GetType().FullName -eq 'System.Numerics.BigInteger') { return $true }
    if ($Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) { return ($Value -eq [math]::Floor($Value)) }
    return $false
}

# Checks the exact object/field/enum structure of schemas/consult-reply.schema.json
# (additionalProperties:false included). Returns an array of error strings; empty
# means structurally valid.
function Test-StructuredReply {
    param($Reply)
    $errors = New-Object System.Collections.Generic.List[string]
    if (-not (Test-IsJsonObject $Reply)) {
        $errors.Add('the reply is not a JSON object')
        return , ([string[]]$errors.ToArray())
    }
    $names = @($Reply.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($f in $script:ReplyFields) {
        if ($names -notcontains $f) { $errors.Add("missing field '$f'") }
    }
    foreach ($n in $names) {
        if ($script:ReplyFields -cnotcontains $n) { $errors.Add("unexpected field '$n'") }
    }
    if ($errors.Count -gt 0) { return , ([string[]]$errors.ToArray()) }

    if (-not (Test-IsJsonString $Reply.schema_version) -or [string]$Reply.schema_version -cne '1') {
        $errors.Add("schema_version must be ""1"" (got '$($Reply.schema_version)')")
    }
    if (-not (Test-IsJsonString $Reply.verdict) -or $script:Verdicts -cnotcontains [string]$Reply.verdict) {
        $errors.Add("verdict '$($Reply.verdict)' is not one of $($script:Verdicts -join '|')")
    }
    foreach ($f in @('verdict_reason', 'reply_markdown')) {
        if (-not (Test-IsJsonString $Reply.$f)) { $errors.Add("$f is not a string") }
    }
    foreach ($f in @('unproven', 'first_run_checklist')) {
        if (-not (Test-IsJsonArray $Reply.$f)) { $errors.Add("$f is not an array"); continue }
        $k = 0
        foreach ($item in $Reply.$f) {
            if (-not (Test-IsJsonString $item)) { $errors.Add("$f[$k] is not a string") }
            $k++
        }
    }

    if (-not (Test-IsJsonArray $Reply.findings)) {
        $errors.Add('findings is not an array')
    } else {
        $k = 0
        foreach ($fd in $Reply.findings) {
            $at = "findings[$k]"
            $k++
            if (-not (Test-IsJsonObject $fd)) { $errors.Add("$at is not an object"); continue }
            $fnames = @($fd.PSObject.Properties | ForEach-Object { $_.Name })
            $missing = $false
            foreach ($f in $script:FindingFields) {
                if ($fnames -notcontains $f) { $errors.Add("$at is missing '$f'"); $missing = $true }
            }
            foreach ($n in $fnames) {
                if ($script:FindingFields -cnotcontains $n) { $errors.Add("$at has unexpected field '$n'") }
            }
            if ($missing) { continue }
            if (-not (Test-IsJsonString $fd.severity) -or $script:Severities -cnotcontains [string]$fd.severity) {
                $errors.Add("$at.severity '$($fd.severity)' is not one of $($script:Severities -join '|')")
            }
            foreach ($f in @('claim', 'trigger', 'verification', 'remedy')) {
                if (-not (Test-IsJsonString $fd.$f)) { $errors.Add("$at.$f is not a string") }
            }
            if (-not (Test-IsJsonArray $fd.locations)) {
                $errors.Add("$at.locations is not an array")
            } else {
                $j = 0
                foreach ($l in $fd.locations) {
                    $lat = "$at.locations[$j]"
                    $j++
                    if (-not (Test-IsJsonObject $l)) { $errors.Add("$lat is not an object"); continue }
                    $lnames = @($l.PSObject.Properties | ForEach-Object { $_.Name })
                    if ($lnames -notcontains 'path' -or $lnames -notcontains 'line') { $errors.Add("$lat needs 'path' and 'line'"); continue }
                    foreach ($n in $lnames) { if (@('path', 'line') -cnotcontains $n) { $errors.Add("$lat has unexpected field '$n'") } }
                    if (-not (Test-IsJsonString $l.path)) { $errors.Add("$lat.path is not a string") }
                    if ($null -ne $l.line) {
                        if (-not (Test-IsJsonInteger $l.line)) { $errors.Add("$lat.line '$($l.line)' is not an integer or null") }
                        elseif ($l.line -lt 1 -or $l.line -gt 2147483647) { $errors.Add("$lat.line '$($l.line)' is outside 1..2147483647") }
                    }
                }
            }
            if (-not (Test-IsJsonArray $fd.evidence)) {
                $errors.Add("$at.evidence is not an array")
            } else {
                $j = 0
                foreach ($ev in $fd.evidence) {
                    $eat = "$at.evidence[$j]"
                    $j++
                    if (-not (Test-IsJsonObject $ev)) { $errors.Add("$eat is not an object"); continue }
                    $enames = @($ev.PSObject.Properties | ForEach-Object { $_.Name })
                    $bad = $false
                    foreach ($f in @('kind', 'reference', 'observation')) {
                        if ($enames -notcontains $f) { $errors.Add("$eat is missing '$f'"); $bad = $true }
                    }
                    foreach ($n in $enames) { if (@('kind', 'reference', 'observation') -cnotcontains $n) { $errors.Add("$eat has unexpected field '$n'") } }
                    if ($bad) { continue }
                    if (-not (Test-IsJsonString $ev.kind) -or $script:EvidenceKinds -cnotcontains [string]$ev.kind) {
                        $errors.Add("$eat.kind '$($ev.kind)' is not one of $($script:EvidenceKinds -join '|')")
                    }
                    foreach ($f in @('reference', 'observation')) {
                        if (-not (Test-IsJsonString $ev.$f)) { $errors.Add("$eat.$f is not a string") }
                    }
                }
            }
            if (-not (Test-IsJsonArray $fd.supersedes)) {
                $errors.Add("$at.supersedes is not an array")
            } else {
                $j = 0
                foreach ($s in $fd.supersedes) {
                    if (-not (Test-IsJsonString $s)) { $errors.Add("$at.supersedes[$j] is not a string") }
                    $j++
                }
            }
        }
    }

    if (-not (Test-IsJsonArray $Reply.prior_findings)) {
        $errors.Add('prior_findings is not an array')
    } else {
        $k = 0
        foreach ($pf in $Reply.prior_findings) {
            $at = "prior_findings[$k]"
            $k++
            if (-not (Test-IsJsonObject $pf)) { $errors.Add("$at is not an object"); continue }
            $pnames = @($pf.PSObject.Properties | ForEach-Object { $_.Name })
            $bad = $false
            foreach ($f in @('id', 'status', 'note')) {
                if ($pnames -notcontains $f) { $errors.Add("$at is missing '$f'"); $bad = $true }
            }
            foreach ($n in $pnames) { if (@('id', 'status', 'note') -cnotcontains $n) { $errors.Add("$at has unexpected field '$n'") } }
            if ($bad) { continue }
            if (-not (Test-IsJsonString $pf.id)) { $errors.Add("$at.id is not a string") }
            if (-not (Test-IsJsonString $pf.status) -or $script:PriorStatuses -cnotcontains [string]$pf.status) {
                $errors.Add("$at.status '$($pf.status)' is not one of $($script:PriorStatuses -join '|')")
            }
            if (-not (Test-IsJsonString $pf.note)) { $errors.Add("$at.note is not a string") }
        }
    }
    return , ([string[]]$errors.ToArray())
}

# A validated reply rebuilt with plain strings and [object[]] arrays, so a
# one-element array stays an array when it is written back to JSON.
function ConvertTo-NormalizedReply {
    param($Reply)
    $findings = @(foreach ($fd in $Reply.findings) {
            [pscustomobject]@{
                severity     = [string]$fd.severity
                locations    = [object[]]@(foreach ($l in $fd.locations) {
                        $line = $null
                        if ($null -ne $l.line) { $line = [int]$l.line }
                        [pscustomobject]@{ path = (ConvertTo-JsonText $l.path); line = $line }
                    })
                claim        = (ConvertTo-JsonText $fd.claim)
                trigger      = (ConvertTo-JsonText $fd.trigger)
                evidence     = [object[]]@(foreach ($ev in $fd.evidence) {
                        [pscustomobject]@{ kind = [string]$ev.kind; reference = (ConvertTo-JsonText $ev.reference); observation = (ConvertTo-JsonText $ev.observation) }
                    })
                verification = (ConvertTo-JsonText $fd.verification)
                remedy       = (ConvertTo-JsonText $fd.remedy)
                supersedes   = [object[]]@(foreach ($s in $fd.supersedes) { ConvertTo-JsonText $s })
            }
        })
    $prior = @(foreach ($pf in $Reply.prior_findings) {
            [pscustomobject]@{ id = (ConvertTo-JsonText $pf.id); status = [string]$pf.status; note = (ConvertTo-JsonText $pf.note) }
        })
    return [pscustomobject]@{
        schema_version      = '1'
        verdict             = [string]$Reply.verdict
        verdict_reason      = (ConvertTo-JsonText $Reply.verdict_reason)
        reply_markdown      = (ConvertTo-JsonText $Reply.reply_markdown)
        findings            = [object[]]$findings
        prior_findings      = [object[]]$prior
        unproven            = [object[]]@(foreach ($u in $Reply.unproven) { ConvertTo-JsonText $u })
        first_run_checklist = [object[]]@(foreach ($c in $Reply.first_run_checklist) { ConvertTo-JsonText $c })
    }
}

function Get-AllowedVerdicts {
    param([string]$Purpose)
    if (@('acceptance', 'diff-review') -contains $Purpose) { return , ([string[]]@('ACCEPT', 'HOLD', 'REJECT')) }
    return , ([string[]]@('ADVISE'))
}

# How the reply disposes of each OPEN PRIOR BLOCKER listed in the prompt.
# $PriorFindings: { id; severity; status } of the listed (open) prior findings.
# Emits { id; disposition } for each one with severity blocker and status
# proposed|implemented: 'still-open' (reported so - any report of it wins),
# 'fixed', or 'not-checked' (reported not-checked or unknown-id, or not reported).
function Get-PriorBlockerDispositions {
    param($Reply, $PriorFindings)
    $reported = @{}
    foreach ($p in @($Reply.prior_findings | Where-Object { $null -ne $_ })) {
        $key = [string]$p.id
        if ($reported.ContainsKey($key) -and $reported[$key] -eq 'still-open') { continue }
        $reported[$key] = [string]$p.status
    }
    foreach ($pf in @($PriorFindings | Where-Object { $null -ne $_ })) {
        if ([string]$pf.severity -ne 'blocker') { continue }
        if ($script:OpenStatuses -notcontains [string]$pf.status) { continue }
        $id = [string]$pf.id
        $disposition = 'not-checked'
        if ($reported.ContainsKey($id)) {
            $s = $reported[$id]
            if ($s -eq 'still-open') { $disposition = 'still-open' }
            elseif ($s -eq 'fixed') { $disposition = 'fixed' }
        }
        [pscustomobject]@{ id = $id; disposition = $disposition }
    }
}

# Contextual checks of a structurally valid (normalized) reply:
#   * the verdict must fit the purpose: ACCEPT|HOLD|REJECT for acceptance and
#     diff-review, ADVISE for every other purpose and for none;
#   * ACCEPT contradicts any NEW blocker finding;
#   * ACCEPT contradicts an open prior blocker the reply reports still-open;
#   * ACCEPT with an open prior blocker reported not-checked (or not reported) is
#     allowed but returned in Unchecked so the caller can warn.
function Test-ReplySemantics {
    param($Reply, [string]$Purpose = '', $PriorFindings = @())
    $problems = New-Object System.Collections.Generic.List[string]
    $short = New-Object System.Collections.Generic.List[string]
    $unchecked = @()
    $verdict = [string]$Reply.verdict
    $allowed = Get-AllowedVerdicts -Purpose $Purpose
    $purposeLabel = if ($Purpose) { $Purpose } else { 'none' }
    if ($allowed -cnotcontains $verdict) {
        $problems.Add("verdict $verdict is not allowed for purpose $purposeLabel (expected $($allowed -join '|'))")
        $short.Add("$verdict not allowed for purpose $purposeLabel")
    }
    if ($verdict -eq 'ACCEPT') {
        $newBlockers = @($Reply.findings | Where-Object { $_.severity -eq 'blocker' }).Count
        if ($newBlockers -gt 0) {
            $problems.Add("verdict ACCEPT contradicts $newBlockers blocker finding(s)")
            $short.Add("ACCEPT contradicts $newBlockers blocker")
        }
        $dispositions = @(Get-PriorBlockerDispositions -Reply $Reply -PriorFindings $PriorFindings)
        $stillOpen = @($dispositions | Where-Object { $_.disposition -eq 'still-open' } | ForEach-Object { $_.id })
        if ($stillOpen.Count -gt 0) {
            $problems.Add("verdict ACCEPT contradicts still-open prior blocker $($stillOpen -join ', ')")
            $short.Add("ACCEPT contradicts still-open prior blocker $($stillOpen -join ', ')")
        }
        $unchecked = @($dispositions | Where-Object { $_.disposition -eq 'not-checked' } | ForEach-Object { $_.id })
    }
    return [pscustomobject]@{
        Problems  = [string[]]$problems.ToArray()
        Short     = [string[]]$short.ToArray()
        Unchecked = [string[]]$unchecked
    }
}

# Parses Codex's last message in structured mode. Tolerates a ```json fence around
# the object. Never throws: any failure becomes a validation error. Outcomes
# (amendment M2 + review F04-4/5/6):
#   Valid=$false             not JSON, any structural error, or a failure while
#                            normalizing: ValidationError = the first error, no
#                            verdict, the caller records no findings
#   Valid, VerdictInvalid    structurally valid but the verdict does not fit the
#                            purpose or contradicts new / still-open prior blockers:
#                            findings are ingested, Verdict '', ValidationError and
#                            VerdictProblem say why
#   Valid                    Verdict = the reply's verdict
# UncheckedPriorBlockers lists open prior blockers an ACCEPT left not-checked.
# $PriorFindings: { id; severity; status } of the open prior findings listed in the
# prompt.
function ConvertFrom-StructuredReply {
    param([string]$Text, [string]$Purpose = '', $PriorFindings = @())
    $result = [pscustomobject]@{
        Valid                  = $false
        Reply                  = $null
        Errors                 = [string[]]@()
        ValidationError        = ''
        Verdict                = ''
        VerdictInvalid         = $false
        VerdictProblem         = ''
        UncheckedPriorBlockers = [string[]]@()
        BlockerCount           = 0
        Fenced                 = $false
    }
    $t = ''
    if ($Text) { $t = $Text.Trim() }
    if (-not $t) {
        $result.ValidationError = 'empty reply'
        $result.Errors = [string[]]@('empty reply')
        return $result
    }
    $fence = [regex]::Match($t, '^```[A-Za-z0-9_-]*[ \t]*\r?\n(?<body>[\s\S]*?)\r?\n[ \t]*```$')
    if ($fence.Success) { $t = $fence.Groups['body'].Value.Trim(); $result.Fenced = $true }
    $obj = $null
    try {
        $obj = ConvertFrom-Json -InputObject $t
    } catch {
        $msg = ConvertTo-OneLine $_.Exception.Message
        if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) + '...' }
        $result.ValidationError = "not valid JSON: $msg"
        $result.Errors = [string[]]@($result.ValidationError)
        return $result
    }
    try {
        $errs = Test-StructuredReply -Reply $obj
        if ($errs.Count -gt 0) {
            $result.Errors = $errs
            $result.ValidationError = $errs[0]
            return $result
        }
        $norm = ConvertTo-NormalizedReply -Reply $obj
        $sem = Test-ReplySemantics -Reply $norm -Purpose $Purpose -PriorFindings $PriorFindings
    } catch {
        $msg = ConvertTo-OneLine $_.Exception.Message
        if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 160) + '...' }
        $result.ValidationError = "could not validate the reply: $msg"
        $result.Errors = [string[]]@($result.ValidationError)
        return $result
    }
    $result.Valid = $true
    $result.Reply = $norm
    $result.BlockerCount = @($norm.findings | Where-Object { $_.severity -eq 'blocker' }).Count
    $result.UncheckedPriorBlockers = $sem.Unchecked
    if ($sem.Problems.Count -gt 0) {
        $result.VerdictInvalid = $true
        $result.ValidationError = ($sem.Problems -join '; ')
        $result.VerdictProblem = ($sem.Short -join '; ')
        $result.Verdict = ''
    } else {
        $result.Verdict = $norm.verdict
    }
    return $result
}

# "WARNING: ACCEPT with N unchecked prior blocker(s) (F02-1)." or ''.
function Format-VerdictWarning {
    param($Parse)
    if (-not $Parse -or -not $Parse.Valid -or -not $Parse.Reply -or $Parse.Reply.verdict -ne 'ACCEPT') { return '' }
    $u = @($Parse.UncheckedPriorBlockers | Where-Object { $_ })
    if ($u.Count -eq 0) { return '' }
    return "WARNING: ACCEPT with $($u.Count) unchecked prior blocker(s) ($($u -join ', '))."
}

function Get-SeverityCounts {
    param($Findings)
    $c = [pscustomobject]@{ blocker = 0; major = 0; minor = 0; note = 0 }
    foreach ($f in @($Findings | Where-Object { $null -ne $_ })) {
        switch ([string]$f.severity) {
            'blocker' { $c.blocker++ }
            'major' { $c.major++ }
            'minor' { $c.minor++ }
            'note' { $c.note++ }
        }
    }
    return $c
}

function Format-SeverityCounts {
    param($Counts)
    return "$($Counts.blocker) blocker, $($Counts.major) major, $($Counts.minor) minor, $($Counts.note) note"
}

function Format-IdRange {
    param([string[]]$Ids)
    $list = @($Ids | Where-Object { $_ })
    if ($list.Count -eq 0) { return '' }
    if ($list.Count -eq 1) { return $list[0] }
    return "$($list[0])..$($list[$list.Count - 1])"
}

# Ingests a VALID structured reply into the findings store (in memory; the caller
# writes the file). New findings get F<NN>-<k> and status 'proposed'; the reviewer's
# prior_findings become reviewer_checks on the findings they name (a reviewer's
# "fixed" is evidence, never a status change); an id that was listed in the prompt
# but not reported gets a 'not-checked' check; an id that does not exist is ignored
# (no record) and returned in UnknownIds; supersedes fills superseded_by on the old
# finding (bookkeeping, not a status change).
function Add-ReplyFindings {
    param(
        $Store,
        $Reply,
        [string]$Nn,
        [int]$ConsultN,
        [string]$ReplyRel,
        [string]$ThreadId,
        [string]$BaseCommit,
        [string]$TreeSha256,
        [string[]]$ListedIds = @(),
        [string]$When = ''
    )
    if (-not $When) { $When = Get-IsoTimestamp }
    $existing = @{}
    foreach ($f in @($Store.findings)) {
        if ($null -ne $f -and $f.PSObject.Properties['id']) { $existing[[string]$f.id] = $f }
    }
    # Open prior blockers the reply does not report fixed stay blockers: they are
    # rendered with the new ones (no new finding record is created for them).
    $priorInfo = @(foreach ($listed in @($ListedIds | Where-Object { $_ })) {
            if ($existing.ContainsKey($listed)) {
                $rec = $existing[$listed]
                [pscustomobject]@{ id = [string]$rec.id; severity = [string](Get-PropertyValue $rec 'severity' ''); status = [string](Get-PropertyValue $rec 'status' '') }
            }
        })
    $retained = @(foreach ($d in @(Get-PriorBlockerDispositions -Reply $Reply -PriorFindings $priorInfo)) {
            if ($d.disposition -eq 'fixed') { continue }
            [pscustomobject]@{ id = $d.id; disposition = $d.disposition; record = $existing[$d.id] }
        })
    $newIds = New-Object System.Collections.Generic.List[string]
    $newRecords = New-Object System.Collections.Generic.List[object]
    $k = 0
    foreach ($f in @($Reply.findings)) {
        $k++
        $id = "F$Nn-$k"
        $newIds.Add($id)
        $newRecords.Add([pscustomobject]@{
                id              = $id
                status          = 'proposed'
                severity        = $f.severity
                locations       = [object[]]@($f.locations)
                claim           = $f.claim
                trigger         = $f.trigger
                evidence        = [object[]]@($f.evidence)
                verification    = $f.verification
                remedy          = $f.remedy
                supersedes      = [object[]]@($f.supersedes)
                superseded_by   = [object[]]@()
                source          = [pscustomobject]@{
                    consult     = $ConsultN
                    reply       = $ReplyRel
                    thread      = $ThreadId
                    base_commit = $BaseCommit
                    tree_sha256 = $TreeSha256
                }
                history         = [object[]]@([pscustomobject]@{
                        when        = $When
                        status      = 'proposed'
                        by          = 'codex-consult'
                        note        = ''
                        evidence    = ''
                        base_commit = $BaseCommit
                        tree_sha256 = $TreeSha256
                    })
                reviewer_checks = [object[]]@()
            })
    }
    $changed = ($newRecords.Count -gt 0)

    $unknownSupersedes = New-Object System.Collections.Generic.List[string]
    foreach ($rec in $newRecords) {
        foreach ($old in @($rec.supersedes)) {
            if ($existing.ContainsKey([string]$old)) {
                $target = $existing[[string]$old]
                $already = @(Get-PropertyValue $target 'superseded_by' @()) -contains $rec.id
                if (-not $already) { Add-ArrayItem -Object $target -Name 'superseded_by' -Item $rec.id; $changed = $true }
            } else {
                $unknownSupersedes.Add([string]$old)
            }
        }
    }

    $priorEntries = New-Object System.Collections.Generic.List[object]
    $unknownIds = New-Object System.Collections.Generic.List[string]
    $reported = @{}
    foreach ($p in @($Reply.prior_findings)) {
        $priorId = [string]$p.id
        $reported[$priorId] = $true
        $known = $existing.ContainsKey($priorId)
        $priorEntries.Add([pscustomobject]@{ id = $priorId; status = $p.status; note = $p.note; known = $known })
        if ($known) {
            Add-ArrayItem -Object $existing[$priorId] -Name 'reviewer_checks' -Item ([pscustomobject]@{
                    consult     = $ConsultN
                    when        = $When
                    status      = $p.status
                    note        = $p.note
                    base_commit = $BaseCommit
                    tree_sha256 = $TreeSha256
                })
            $changed = $true
        } else {
            $unknownIds.Add($priorId)
        }
    }
    $notReported = New-Object System.Collections.Generic.List[string]
    foreach ($listed in @($ListedIds | Where-Object { $_ })) {
        if ($reported.ContainsKey($listed) -or -not $existing.ContainsKey($listed)) { continue }
        $notReported.Add($listed)
        $priorEntries.Add([pscustomobject]@{ id = $listed; status = 'not-checked'; note = '(not reported)'; known = $true })
        Add-ArrayItem -Object $existing[$listed] -Name 'reviewer_checks' -Item ([pscustomobject]@{
                consult     = $ConsultN
                when        = $When
                status      = 'not-checked'
                note        = '(not reported)'
                base_commit = $BaseCommit
                tree_sha256 = $TreeSha256
            })
        $changed = $true
    }

    if ($newRecords.Count -gt 0) {
        # In id order (0.4.x wave 21): after every finding whose F<NN> is not greater than this
        # run's - a panel member that commits first still lands after the lower-NN members'
        # findings; a single run (the highest NN) appends as before.
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($f in @($Store.findings | Where-Object { $null -ne $_ })) { $list.Add($f) }
        $mine = 0
        [void][int]::TryParse($Nn, [ref]$mine)
        $at = $list.Count
        for ($i = $list.Count - 1; $i -ge 0; $i--) {
            $v = 0
            if ([string](Get-PropertyValue $list[$i] 'id' '') -match '^F(\d{2,})-\d+$' -and [int]::TryParse($Matches[1], [ref]$v) -and $v -gt $mine) { $at = $i } else { break }
        }
        $list.InsertRange($at, $newRecords)
        $Store.findings = [object[]]$list.ToArray()
    }
    return [pscustomobject]@{
        NewIds            = [string[]]$newIds.ToArray()
        PriorEntries      = [object[]]$priorEntries.ToArray()
        UnknownIds        = [string[]]$unknownIds.ToArray()
        NotReported       = [string[]]$notReported.ToArray()
        UnknownSupersedes = [string[]]$unknownSupersedes.ToArray()
        RetainedBlockers  = [object[]]$retained
        Counts            = (Get-SeverityCounts -Findings $Reply.findings)
        Changed           = $changed
    }
}

# The header line that follows "Bridge outcome: ..." in a structured-mode reply file.
function Format-StructuredStatusLine {
    param($Parse, $Ingest, [string]$ReplyJsonRel = '')
    if (-not $Parse.Valid) {
        $line = "Structured reply: INVALID ($($Parse.ValidationError)) - raw text kept; no findings recorded."
        if ($ReplyJsonRel) { $line += " Raw last message: ``$ReplyJsonRel``." }
        return $line
    }
    if ($Parse.VerdictInvalid) {
        $verdictText = "Verdict: (invalid: $($Parse.VerdictProblem))."
    } else {
        $reason = Close-Sentence $Parse.Reply.verdict_reason
        $verdictText = "Verdict: $($Parse.Verdict)"
        if ($reason) { $verdictText += " - $reason" } else { $verdictText += '.' }
    }
    $n = @($Parse.Reply.findings).Count
    if ($n -gt 0) {
        $findingsText = "Findings: $(Format-SeverityCounts $Ingest.Counts) ($(Format-IdRange $Ingest.NewIds), tracked in ``findings.json``)."
    } else {
        $findingsText = 'Findings: none.'
    }
    $line = "$verdictText $findingsText"
    if ($ReplyJsonRel) { $line += " Structured reply: ``$ReplyJsonRel``." }
    return $line
}

# The rendered section appended after the verbatim reply_markdown (amendment M8):
# Findings, Prior findings, then the four R4 blocks last - Verdict, Blockers,
# Unproven scenarios, First-run checklist (observable).
function Format-StructuredSection {
    param($Parse, $Ingest, [string]$ReviewerLabel = 'Codex')
    $r = $Parse.Reply
    $ids = @($Ingest.NewIds)
    $out = New-Object System.Collections.Generic.List[string]

    $out.Add('### Findings')
    $out.Add('')
    $findings = @($r.findings)
    if ($findings.Count -eq 0) { $out.Add('_(none)_') }
    for ($i = 0; $i -lt $findings.Count; $i++) {
        $f = $findings[$i]
        $line = "- **$($ids[$i])** [$($f.severity)] $(Format-Locations -Locations $f.locations -Code) - $(Close-Sentence $f.claim)"
        if ($f.trigger) { $line += " Trigger: $(Close-Sentence $f.trigger)" }
        $ev = @(foreach ($e in @($f.evidence)) { "$($e.kind): $(ConvertTo-OneLine $e.observation)" })
        if ($ev.Count -gt 0) { $line += " Evidence: $(Close-Sentence ($ev -join '; '))" }
        if ($f.verification) { $line += " Verify: $(Close-Sentence $f.verification)" }
        if ($f.remedy) { $line += " Remedy: $(Close-Sentence $f.remedy)" }
        $sup = @($f.supersedes | Where-Object { $_ })
        if ($sup.Count -gt 0) { $line += " Supersedes: $($sup -join ', ')." }
        $out.Add($line)
    }
    $out.Add('')

    $out.Add('### Prior findings')
    $out.Add('')
    $prior = @($Ingest.PriorEntries)
    if ($prior.Count -eq 0) { $out.Add('_(none)_') }
    foreach ($p in $prior) {
        $line = "- $($p.id) - $($p.status)"
        $note = ConvertTo-OneLine $p.note
        if ($note) { $line += " - $note" }
        if (-not $p.known) { $line += ' _(unknown id: not in findings.json, ignored)_' }
        $out.Add($line)
    }
    $out.Add('')

    if ($Parse.VerdictInvalid) {
        $out.Add("## Verdict: (invalid: $($Parse.VerdictProblem))")
        $out.Add('')
        $why = "$ReviewerLabel answered $($r.verdict)"
        $reason = ConvertTo-OneLine $r.verdict_reason
        if ($reason) { $why += " ($reason)" }
        $out.Add("$why; no verdict was recorded: $($Parse.ValidationError).")
    } else {
        $out.Add("## Verdict: $($Parse.Verdict)")
        $out.Add('')
        $reason = ConvertTo-OneLine $r.verdict_reason
        if (-not $reason) { $reason = '_(no reason given)_' }
        $out.Add($reason)
    }
    $warning = Format-VerdictWarning -Parse $Parse
    if ($warning) {
        $out.Add('')
        $out.Add("**$warning**")
    }
    $out.Add('')

    # New blockers, then the open prior blockers this reply did not report fixed.
    $out.Add('### Blockers')
    $out.Add('')
    $nb = 0
    for ($i = 0; $i -lt $findings.Count; $i++) {
        $f = $findings[$i]
        if ($f.severity -ne 'blocker') { continue }
        $nb++
        $line = "- **$($ids[$i])** $(Format-Locations -Locations $f.locations -Code) - $(Close-Sentence $f.claim)"
        if ($f.verification) { $line += " Verify: $(Close-Sentence $f.verification)" }
        if ($f.remedy) { $line += " Remedy: $(Close-Sentence $f.remedy)" }
        $out.Add($line)
    }
    foreach ($rb in @($Ingest.RetainedBlockers | Where-Object { $null -ne $_ })) {
        $nb++
        $rec = $rb.record
        $line = "- **$($rb.id)** (prior, $($rb.disposition)) $(Format-Locations -Locations (Get-PropertyValue $rec 'locations' @()) -Code) - $(Close-Sentence ([string](Get-PropertyValue $rec 'claim' '')))"
        $verify = [string](Get-PropertyValue $rec 'verification' '')
        if ($verify) { $line += " Verify: $(Close-Sentence $verify)" }
        $remedy = [string](Get-PropertyValue $rec 'remedy' '')
        if ($remedy) { $line += " Remedy: $(Close-Sentence $remedy)" }
        $out.Add($line)
    }
    if ($nb -eq 0) { $out.Add('_(none)_') }
    $out.Add('')

    $out.Add('### Unproven scenarios')
    $out.Add('')
    $un = @($r.unproven | Where-Object { $_ })
    if ($un.Count -eq 0) { $out.Add('_(none)_') }
    foreach ($u in $un) { $out.Add("- $(ConvertTo-OneLine $u)") }
    $out.Add('')

    $out.Add('### First-run checklist (observable)')
    $out.Add('')
    $cl = @($r.first_run_checklist | Where-Object { $_ })
    if ($cl.Count -eq 0) { $out.Add('_(none)_') }
    foreach ($c in $cl) { $out.Add("- [ ] $(ConvertTo-OneLine $c)") }

    return ($out.ToArray() -join "`n")
}

# ----------------------------------------------------------------------------- format repair
#
# A structured consultation whose reviewer answered in prose (not the JSON object) gets ONE
# repair turn (codex-consult.ps1 -FormatRetry 1): the same thread is resumed and asked to
# convert its previous message, unchanged, into the JSON object. These helpers decide
# whether the prose is worth converting, which effort the repair turn uses, and what the
# conversion may have changed (drift notes - warnings only).

# Is a prose reply worth a repair turn? { Substantive; Reason ('' | 'reply looks like a
# refusal' | 'reply too short (<n> words)'); Words; Numbered }.
#   refusal   the first 200 characters (trimmed, case-insensitive; curly apostrophes read as
#             straight ones) START with refusal phrasing (I cannot, I can't, I'm sorry,
#             I am sorry, I am unable, I'm unable, "Sorry, ", As an AI, I won't) or hold
#             two such phrases, AND the whole text has no numbered answer and no
#             finding-like marker (F<NN>-<k>, RC<n>, Verdict): not substantive
#   numbered  answers at a line start in any of these styles: **Q<n>.**, Q<n>., Q<n>:,
#             <n>., <n>), **<n>.**, ### Q<n> (any heading level)
#   floors    >= 25 words with at least two numbered answers, >= 40 words with one,
#             >= 120 words otherwise
$script:RefusalPhrases = @("i cannot", "i can't", "i'm sorry", 'i am sorry', 'i am unable', "i'm unable", 'sorry, ', 'as an ai', "i won't")
$script:NumberedAnswerRe = [regex]'(?m)^[ \t]*(?:\*\*Q[0-9]+[.:]\*\*|Q[0-9]+[.:]|\*\*[0-9]+\.\*\*|[0-9]+[.)]|#{1,6}[ \t]*Q[0-9]+\b)'
function Get-ProseGate {
    param([string]$Text)
    $t = [string]$Text
    $words = @(($t -split '\s+') | Where-Object { $_ }).Count
    $numbered = $script:NumberedAnswerRe.Matches($t).Count
    $r = [pscustomobject]@{ Substantive = $false; Reason = ''; Words = $words; Numbered = $numbered }
    $head = ($t.Trim() -replace '[\u2018\u2019]', "'")
    if ($head.Length -gt 200) { $head = $head.Substring(0, 200) }
    $head = $head.ToLowerInvariant()
    $lead = $head -replace '^[\s*#>_`-]+', ''
    $startsRefusal = @($script:RefusalPhrases | Where-Object { $lead.StartsWith($_) }).Count -gt 0
    $hits = 0
    foreach ($ph in $script:RefusalPhrases) { $hits += ([regex]::Matches($head, [regex]::Escape($ph))).Count }
    $markers = ($numbered -gt 0) -or ($t -match '\bF[0-9]{2,}-[0-9]+\b') -or ($t -match '\bRC[0-9]+\b') -or ($t -match '(?i)\bverdict\b')
    if (($startsRefusal -or $hits -ge 2) -and -not $markers) { $r.Reason = 'reply looks like a refusal'; return $r }
    if (($numbered -ge 2 -and $words -ge 25) -or ($numbered -ge 1 -and $words -ge 40) -or $words -ge 120) { $r.Substantive = $true; return $r }
    $r.Reason = "reply too short ($words words)"
    return $r
}

function Test-SubstantiveProse {
    param([string]$Text)
    return (Get-ProseGate -Text $Text).Substantive
}

# The effort of the repair turn: the lowest value of the route's effort vocabulary (the
# value 'low' maps to; caps-v1), or the value sent when -NativeEffort bypassed the
# vocabulary.
function Get-RepairEffort {
    param($Identity, $EffortPlan)
    if ($EffortPlan.Mapping -eq 'native') { return [string]$EffortPlan.Sent }
    $hostName = [string]$Identity.HostName
    if ($hostName -and $script:EffortCaps.ContainsKey($hostName) -and $script:EffortVocabularies.ContainsKey($script:EffortCaps[$hostName].Vocabulary)) {
        return [string]$script:EffortVocabularies[$script:EffortCaps[$hostName].Vocabulary].Map['low']
    }
    return [string]$EffortPlan.Sent
}

function ConvertTo-DriftText {
    param([string]$Text)
    return (([string]$Text -replace '\s+', ' ').Trim().ToLowerInvariant())
}

# What a format repair may have changed: the prose (the first reply) against the repaired
# object ($Reply: reply_markdown, findings, prior_findings, verdict). One note per check
# that differs, [string[]] (empty when clean):
#   1 the RC<n> ids of the prose vs of reply_markdown
#   2 the numbered answers (Q<n>. at a line start, bold or not) of both
#   3 every F<NN>-<k> id the prose names appears in prior_findings or findings
#   4 a verdict token the prose states (ACCEPT|HOLD|REJECT|ADVISE, after "Verdict" if
#     there is one) equals the JSON verdict
#   5 every prose sentence of >= 60 characters (whitespace-normalised; the 40 longest at
#     most, to bound the cost) appears in reply_markdown (normalised, case-insensitive) -
#     a changed remedy in a short sentence counts as much as one in a long one
function Get-FormatRepairDrift {
    param([string]$Prose, $Reply)
    $notes = New-Object System.Collections.Generic.List[string]
    $md = [string](Get-PropertyValue $Reply 'reply_markdown' '')
    $rcOf = { param($t) @([regex]::Matches([string]$t, '\bRC([0-9]+)\b') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique | ForEach-Object { "RC$_" }) }
    $rcProse = @(& $rcOf $Prose)
    $rcMd = @(& $rcOf $md)
    if (($rcProse -join ',') -ne ($rcMd -join ',')) {
        $notes.Add("requested checks differ: prose $(if ($rcProse.Count) { $rcProse -join ', ' } else { 'none' }), reply_markdown $(if ($rcMd.Count) { $rcMd -join ', ' } else { 'none' })")
    }
    $qOf = { param($t) @([regex]::Matches([string]$t, '(?m)^\s*(?:\*\*)?Q([0-9]+)\.') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique) }
    $qProse = @(& $qOf $Prose)
    $qMd = @(& $qOf $md)
    if ($qProse.Count -ne $qMd.Count) {
        $notes.Add("numbered answers differ: prose $($qProse.Count), reply_markdown $($qMd.Count)")
    }
    $idsProse = @([regex]::Matches([string]$Prose, '\bF[0-9]{2,}-[0-9]+\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($idsProse.Count -gt 0) {
        $known = New-Object System.Collections.Generic.List[string]
        foreach ($pf in @(Get-PropertyValue $Reply 'prior_findings' @())) { if ($pf) { $known.Add([string](Get-PropertyValue $pf 'id' '')) } }
        $findingsText = ConvertTo-Json -InputObject ([object[]]@(Get-PropertyValue $Reply 'findings' @())) -Depth 8 -Compress
        foreach ($m in [regex]::Matches([string]$findingsText, '\bF[0-9]{2,}-[0-9]+\b')) { $known.Add($m.Value) }
        $missing = @($idsProse | Where-Object { -not $known.Contains($_) })
        if ($missing.Count -gt 0) { $notes.Add("finding id(s) named in the prose but absent from prior_findings/findings: $($missing -join ', ')") }
    }
    $vm = [regex]::Match([string]$Prose, '\b[Vv]erdict\b[^A-Za-z]{0,12}(ACCEPT|HOLD|REJECT|ADVISE)\b')
    if (-not $vm.Success) { $vm = [regex]::Match([string]$Prose, '\b(ACCEPT|HOLD|REJECT|ADVISE)\b') }
    $jsonVerdict = [string](Get-PropertyValue $Reply 'verdict' '')
    if ($vm.Success -and $vm.Groups[1].Value -cne $jsonVerdict) {
        $notes.Add("verdict differs: prose $($vm.Groups[1].Value), JSON $(if ($jsonVerdict) { $jsonVerdict } else { '(none)' })")
    }
    $sentences = @(([string]$Prose -split '(?<=[.!?])\s+|\r?\n') | ForEach-Object { ConvertTo-DriftText $_ } | Where-Object { $_.Length -ge 60 } | Sort-Object -Unique | Sort-Object -Property Length -Descending | Select-Object -First 40)
    if ($sentences.Count -gt 0) {
        $mdNorm = ConvertTo-DriftText $md
        $lost = @($sentences | Where-Object { -not $mdNorm.Contains($_) })
        if ($lost.Count -gt 0) {
            $first = $lost[0]
            if ($first.Length -gt 60) { $first = $first.Substring(0, 60) + '...' }
            $notes.Add("$($lost.Count) of the $($sentences.Count) prose sentences (>= 60 chars) are not in reply_markdown (first: '$first')")
        }
    }
    return , ([string[]]$notes.ToArray())
}

# ----------------------------------------------------------------------------- codex config + reviewer identity
#
# The bridge records WHICH reviewer answered and lets a consultation fork or resume
# only a thread of the same reviewer. Codex picks the provider and the model from its
# config (<codex home>/config.toml): the top-level `model_provider` (Codex's own
# default: the built-in `openai`) and `model`; a provider other than openai is a
# [model_providers.<name>] table. The bridge reads that file with a CONSTRAINED
# scanner (no TOML library) and pins what it resolved on the codex command line
# (-m <model>, -c model_provider="<name>"), so the ledger and the run agree.
#
# Scanner contract (Read-CodexConfigSubset):
#   understood   blank lines; # comments (full-line or trailing); table headers [a.b]
#                whose segments are bare, "basic" or 'literal' keys; key = value lines
#                with ONE bare or quoted key and a single-line "basic" or 'literal'
#                string, a boolean, a number or a date/time as the value
#   skipped      arrays [...], inline tables {...} and multi-line strings """ / ''':
#                delimited by their exact lexical extent (strings, escapes, comments and
#                bracket nesting are honoured) and never interpreted; the KEY holding
#                one is unsupported, and so is the table the value would define
#                (x = {...} defines the table x)
#   unsupported  dotted keys (a.b = 1: the table they write into, a, is unsupported),
#                arrays of tables [[a]] (a), a table or a key defined twice (that table)
#   fatal        anything else - a line the scanner cannot tokenize, an unterminated
#                string or array: the whole file is unusable, because the scanner can
#                no longer tell which table the rest belongs to
# Callers decide what an unsupported key means. The top level is usable while the
# three keys the bridge reads there (model_provider, model, profile) are plain. A
# provider table is usable only when EVERY key in it is plain and nothing else writes
# into it (dotted keys, inline tables, sub-tables): all of it describes the endpoint.
# Nothing is guessed. Profiles are not supported: a config that selects one
# (`profile = "x"`) can change the provider, the model and the effort behind the
# bridge, so the reviewer identity stays unresolved (-p/--profile is never passed).

$script:TomlKeySep = [string][char]31
$script:SecretKeyPattern = '(?i)env_key|api_key|bearer|token|secret|password'
$script:TomlRe = @{
    Ws        = [regex]'\G[ \t]*'
    Comment   = [regex]'\G#[^\n]*'
    Bare      = [regex]'\G[A-Za-z0-9_-]+'
    Basic     = [regex]'\G"((?:[^"\\\n]|\\[^\n])*)"'
    Literal   = [regex]"\G'([^'\n]*)'"
    MlBasic   = [regex]'\G"""(?:[^"\\]|\\[\s\S]|"{1,2}(?!"))*"{3,5}'
    MlLiteral = [regex]"\G'''(?:[^']|'{1,2}(?!'))*'{3,5}"
    Scalar    = [regex]'\G[^ \t\n#]+'
    DateTail  = [regex]'\G [0-9]{2}:[0-9]{2}[^ \t\n#]*'
}
$script:TomlScalarRules = @(
    @{ Kind = 'boolean'; Re = '^(true|false)$' },
    @{ Kind = 'integer'; Re = '^[+-]?(0|[1-9](_?[0-9])*)$' },
    @{ Kind = 'integer'; Re = '^0x[0-9A-Fa-f](_?[0-9A-Fa-f])*$' },
    @{ Kind = 'integer'; Re = '^0o[0-7](_?[0-7])*$' },
    @{ Kind = 'integer'; Re = '^0b[01](_?[01])*$' },
    @{ Kind = 'float'; Re = '^[+-]?(0|[1-9](_?[0-9])*)(\.[0-9](_?[0-9])*)?([eE][+-]?[0-9](_?[0-9])*)?$' },
    @{ Kind = 'float'; Re = '^[+-]?(inf|nan)$' },
    @{ Kind = 'datetime'; Re = '^[0-9]{4}-[0-9]{2}-[0-9]{2}([Tt ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?([Zz]|[+-][0-9]{2}:[0-9]{2})?)?$' },
    @{ Kind = 'datetime'; Re = '^[0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' }
)

function Get-CodexHome {
    if ($env:CODEX_HOME) { return $env:CODEX_HOME }
    $home_ = $HOME
    if (-not $home_) { $home_ = $env:USERPROFILE }
    if (-not $home_) { return '' }
    return (Join-Path $home_ '.codex')
}

function Get-CodexConfigPath {
    $codexHome = Get-CodexHome
    if (-not $codexHome) { return '' }
    return (Join-Path $codexHome 'config.toml')
}

# A config line for an error message (it may reach the ledger's identity_note): the
# VALUE is masked - every string and every bare word in it becomes '...', only its
# structure ([ { , = #) stays, since a value can hold a credential; keys and table
# headers are shown as written. Trimmed to 60 characters.
function Format-TomlLineForMessage {
    param([string]$Line, [int]$ValueStart = -1)
    $head = ''
    $tail = $Line
    if ($ValueStart -ge 0 -and $ValueStart -le $Line.Length) {
        $head = $Line.Substring(0, $ValueStart)
        $tail = $Line.Substring($ValueStart)
    } elseif ($Line.TrimStart().StartsWith('[')) {
        $head = $Line
        $tail = ''
    } else {
        $kp = Read-TomlKeyPath -S $Line -Start 0
        if (-not $kp -or $kp.End -ge $Line.Length -or $Line[$kp.End] -ne [char]'=') { return '<not a key = value line; content not shown>' }
        $head = $Line.Substring(0, $kp.End + 1)
        $tail = $Line.Substring($kp.End + 1)
    }
    $sb = New-Object System.Text.StringBuilder
    $m = [regex]::Match($tail, '"(?:[^"\\]|\\.)*"|''[^'']*''|["'']|[^\s\[\]\{\},=#"'']+')
    $pos = 0
    while ($m.Success) {
        [void]$sb.Append($tail.Substring($pos, $m.Index - $pos))
        $first = $m.Value.Substring(0, 1)
        if ($m.Value.Length -eq 1 -and ($first -eq '"' -or $first -eq "'")) { [void]$sb.Append('...'); $pos = $tail.Length; break }
        if ($first -eq '"' -or $first -eq "'") { [void]$sb.Append($first + '...' + $first) }
        else { [void]$sb.Append('...') }
        $pos = $m.Index + $m.Length
        $m = $m.NextMatch()
    }
    if ($pos -lt $tail.Length) { [void]$sb.Append($tail.Substring($pos)) }
    $t = ($head + $sb.ToString()).Trim()
    if ($t.Length -gt 60) { $t = $t.Substring(0, 60) }
    return $t
}

function ConvertFrom-TomlEscapes {
    param([string]$Raw)
    if ($Raw.IndexOf([char]'\') -lt 0) { return $Raw }
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $e = $m.Groups[1].Value
        $first = $e.Substring(0, 1)
        try {
            if ($first -ceq 'b') { return [string][char]8 }
            if ($first -ceq 't') { return [string][char]9 }
            if ($first -ceq 'n') { return [string][char]10 }
            if ($first -ceq 'f') { return [string][char]12 }
            if ($first -ceq 'r') { return [string][char]13 }
            if ($first -ceq 'e') { return [string][char]27 }
            if ($first -ceq '"') { return '"' }
            if ($first -ceq '\') { return '\' }
            if ($first -ceq 'u' -or $first -ceq 'U' -or $first -ceq 'x') {
                return [char]::ConvertFromUtf32([Convert]::ToInt32($e.Substring(1), 16))
            }
        } catch { }
        return $m.Value
    }
    return [regex]::Replace($Raw, '\\(u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|x[0-9A-Fa-f]{2}|[\s\S])', $evaluator)
}

# "a.b" / 'model_providers."my provider"' - segments quoted when they are not bare.
function Format-TomlPath {
    param([string[]]$Segments)
    $parts = @(foreach ($seg in @($Segments)) {
            if ($seg -match '^[A-Za-z0-9_-]+$') { $seg } else { '"' + ($seg -replace '\\', '\\' -replace '"', '\"') + '"' }
        })
    return ($parts -join '.')
}

# The inside of a TOML basic string, for `-c key="<value>"` (Codex parses the value as
# TOML): backslash and double quote escaped.
function ConvertTo-TomlBasicString {
    param([string]$Value)
    return ($Value -replace '\\', '\\' -replace '"', '\"')
}

function Get-TomlTable {
    param($Tables, [string[]]$Segments)
    $key = (@($Segments) -join $script:TomlKeySep)
    if (-not $Tables.ContainsKey($key)) {
        $Tables[$key] = [pscustomobject]@{
            Name       = (Format-TomlPath $Segments)
            Segments   = [string[]]@($Segments)
            HeaderLine = 0
            Ok         = $true
            Reason     = ''
            Entries    = (New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal))
        }
    }
    return $Tables[$key]
}

function Set-TomlUnsupported {
    param($Table, [string]$Reason)
    if ($Table.Ok) { $Table.Ok = $false; $Table.Reason = $Reason }
}

# One key (a.b."c d".'e') starting at $Start: { Segments; End } (End after trailing
# blanks) or $null when there is no key there.
function Read-TomlKeyPath {
    param([string]$S, [int]$Start)
    $segs = New-Object System.Collections.Generic.List[string]
    $i = $Start
    while ($true) {
        $i += $script:TomlRe.Ws.Match($S, $i).Length
        $m = $script:TomlRe.Bare.Match($S, $i)
        if ($m.Success) { $segs.Add($m.Value) }
        else {
            $m = $script:TomlRe.Basic.Match($S, $i)
            if ($m.Success) { $segs.Add((ConvertFrom-TomlEscapes $m.Groups[1].Value)) }
            else {
                $m = $script:TomlRe.Literal.Match($S, $i)
                if ($m.Success) { $segs.Add($m.Groups[1].Value) } else { return $null }
            }
        }
        $i += $m.Length
        $i += $script:TomlRe.Ws.Match($S, $i).Length
        if ($i -lt $S.Length -and $S[$i] -eq [char]'.') { $i++; continue }
        break
    }
    return [pscustomobject]@{ Segments = [string[]]$segs.ToArray(); End = $i }
}

# The value starting at $Start: { Kind; Value; Supported; End; Lines; Error }. Lines =
# newlines consumed (multi-line values). Error <> '' when there is no value the scanner
# knows there (the caller treats that as fatal).
function Read-TomlValue {
    param([string]$S, [int]$Start)
    $len = $S.Length
    $v = [pscustomobject]@{ Kind = ''; Value = $null; Supported = $false; End = $Start; Lines = 0; Error = '' }
    if ($Start -ge $len -or $S[$Start] -eq [char]"`n") { $v.Error = 'missing value'; return $v }
    $c = $S[$Start]
    if ($c -eq [char]'"' -or $c -eq [char]"'") {
        $q3 = ([string]$c) * 3
        if ($Start + 3 -le $len -and $S.Substring($Start, 3) -eq $q3) {
            $re = if ($c -eq [char]'"') { $script:TomlRe.MlBasic } else { $script:TomlRe.MlLiteral }
            $m = $re.Match($S, $Start)
            if (-not $m.Success) { $v.Error = 'unterminated multi-line string'; return $v }
            $v.Kind = 'multi-line string'
            $v.End = $Start + $m.Length
            $v.Lines = $m.Value.Split([char]"`n").Count - 1
            return $v
        }
        if ($c -eq [char]'"') {
            $m = $script:TomlRe.Basic.Match($S, $Start)
            if (-not $m.Success) { $v.Error = 'unterminated string'; return $v }
            $v.Value = ConvertFrom-TomlEscapes $m.Groups[1].Value
        } else {
            $m = $script:TomlRe.Literal.Match($S, $Start)
            if (-not $m.Success) { $v.Error = 'unterminated string'; return $v }
            $v.Value = $m.Groups[1].Value
        }
        $v.Kind = 'string'
        $v.Supported = $true
        $v.End = $Start + $m.Length
        return $v
    }
    if ($c -eq [char]'[' -or $c -eq [char]'{') {
        $kind = if ($c -eq [char]'[') { 'array' } else { 'inline table' }
        $depth = 0
        $lines = 0
        $i = $Start
        while ($i -lt $len) {
            $ch = $S[$i]
            if ($ch -eq [char]"`n") { $lines++; $i++; continue }
            if ($ch -eq [char]'#') { $i += $script:TomlRe.Comment.Match($S, $i).Length; continue }
            if ($ch -eq [char]'"' -or $ch -eq [char]"'") {
                $inner = Read-TomlValue -S $S -Start $i
                if ($inner.Error) { $v.Error = "unterminated string inside an $kind"; return $v }
                $lines += $inner.Lines
                $i = $inner.End
                continue
            }
            if ($ch -eq [char]'[' -or $ch -eq [char]'{') { $depth++ }
            elseif ($ch -eq [char]']' -or $ch -eq [char]'}') {
                $depth--
                if ($depth -eq 0) {
                    $v.Kind = $kind
                    $v.End = $i + 1
                    $v.Lines = $lines
                    return $v
                }
            }
            $i++
        }
        $v.Error = "unterminated $kind"
        return $v
    }
    $m = $script:TomlRe.Scalar.Match($S, $Start)
    $token = $m.Value
    $end = $Start + $m.Length
    if ($token -cmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') {
        $tail = $script:TomlRe.DateTail.Match($S, $end)
        if ($tail.Success) { $token += $tail.Value; $end += $tail.Length }
    }
    foreach ($rule in $script:TomlScalarRules) {
        if ($token -cmatch $rule.Re) {
            $v.Kind = $rule.Kind
            $v.Value = $token
            $v.Supported = $true
            $v.End = $end
            return $v
        }
    }
    $v.Error = 'not a value the scanner knows'
    return $v
}

# Position of the end of the line (the newline or the end of the text) after optional
# blanks and a comment; -1 when something else follows.
function Get-TomlLineEnd {
    param([string]$S, [int]$Start)
    $i = $Start + $script:TomlRe.Ws.Match($S, $Start).Length
    if ($i -lt $S.Length -and $S[$i] -eq [char]'#') { $i += $script:TomlRe.Comment.Match($S, $i).Length }
    if ($i -ge $S.Length -or $S[$i] -eq [char]"`n") { return $i }
    return -1
}

# Reads the Codex config with the constrained scanner (contract above).
# { Path; Exists; Ok; Reason; Tables } - Tables maps the table path (segments joined
# by U+001F, '' = top level) to { Name; Segments; HeaderLine; Ok; Reason; Entries };
# Entries maps a key (ordinal) to { Key; Line; Kind; Value; Supported; Reason }.
# Exists $false (no file) is not an error: Codex then runs on its built-in defaults.
function Read-CodexConfigSubset {
    param([string]$Path)
    $tables = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $result = [pscustomobject]@{ Path = $Path; Exists = $false; Ok = $true; Reason = ''; Tables = $tables }
    $top = Get-TomlTable -Tables $tables -Segments @()
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $result }
    $result.Exists = $true
    $text = $null
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'it is not a file' }
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        try {
            $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $true)
            try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
        } finally { $fs.Dispose() }
    } catch {
        $result.Ok = $false
        $result.Reason = "the Codex config '$Path' could not be read: $(ConvertTo-OneLine $_.Exception.Message)"
        return $result
    }
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $s = $text -replace "`r`n", "`n"
    $lines = $s -split "`n"
    $len = $s.Length
    $i = 0
    $line = 1
    $current = $top
    while ($i -lt $len) {
        $i += $script:TomlRe.Ws.Match($s, $i).Length
        if ($i -ge $len) { break }
        $c = $s[$i]
        if ($c -eq [char]"`n") { $i++; $line++; continue }
        if ($c -eq [char]'#') { $i += $script:TomlRe.Comment.Match($s, $i).Length; continue }
        $lineNo = $line
        $lineText = $lines[$lineNo - 1]
        $lineStart = 0
        if ($i -gt 0) { $lineStart = $s.LastIndexOf([char]"`n", $i - 1) + 1 }
        $fatal = "unsupported TOML construct at line ${lineNo}: $(Format-TomlLineForMessage -Line $lineText)"
        if ($c -eq [char]'[') {
            $isAot = ($i + 1 -lt $len -and $s[$i + 1] -eq [char]'[')
            $close = if ($isAot) { ']]' } else { ']' }
            $kp = Read-TomlKeyPath -S $s -Start ($i + $close.Length)
            if (-not $kp -or $kp.End + $close.Length -gt $len -or $s.Substring($kp.End, $close.Length) -ne $close) {
                $result.Ok = $false; $result.Reason = $fatal; break
            }
            $eol = Get-TomlLineEnd -S $s -Start ($kp.End + $close.Length)
            if ($eol -lt 0) { $result.Ok = $false; $result.Reason = $fatal; break }
            $t = Get-TomlTable -Tables $tables -Segments $kp.Segments
            if ($isAot) { Set-TomlUnsupported $t "$fatal (array of tables)" }
            elseif ($t.HeaderLine -gt 0) { Set-TomlUnsupported $t "table [$($t.Name)] is defined twice in the Codex config (lines $($t.HeaderLine) and $lineNo)" }
            if ($t.HeaderLine -eq 0) { $t.HeaderLine = $lineNo }
            $current = $t
            $i = $eol
            continue
        }
        $kp = Read-TomlKeyPath -S $s -Start $i
        if (-not $kp -or $kp.End -ge $len -or $s[$kp.End] -ne [char]'=') { $result.Ok = $false; $result.Reason = $fatal; break }
        $p = $kp.End + 1
        $p += $script:TomlRe.Ws.Match($s, $p).Length
        $v = Read-TomlValue -S $s -Start $p
        if ($v.Error) { $result.Ok = $false; $result.Reason = "$fatal ($($v.Error))"; break }
        $eol = Get-TomlLineEnd -S $s -Start $v.End
        if ($eol -lt 0) { $result.Ok = $false; $result.Reason = $fatal; break }
        $line += $v.Lines
        $i = $eol
        $construct = "unsupported TOML construct at line ${lineNo}: $(Format-TomlLineForMessage -Line $lineText -ValueStart ($p - $lineStart))"
        $segs = @($kp.Segments)
        if ($segs.Count -gt 1) {
            $targetSegs = @($current.Segments) + @($segs[0..($segs.Count - 2)])
            $target = Get-TomlTable -Tables $tables -Segments $targetSegs
            Set-TomlUnsupported $target "$construct (dotted key)"
            if (-not $current.Entries.ContainsKey($segs[0])) {
                $current.Entries[$segs[0]] = [pscustomobject]@{ Key = $segs[0]; Line = $lineNo; Kind = 'dotted key'; Value = $null; Supported = $false; Reason = "$construct (dotted key)" }
            }
            continue
        }
        $k = [string]$segs[0]
        if ($current.Entries.ContainsKey($k)) {
            Set-TomlUnsupported $current "key '$k' is defined twice in [$($current.Name)] of the Codex config (lines $($current.Entries[$k].Line) and $lineNo)"
            continue
        }
        $why = ''
        if (-not $v.Supported) { $why = "$construct ($($v.Kind))" }
        $current.Entries[$k] = [pscustomobject]@{ Key = $k; Line = $lineNo; Kind = $v.Kind; Value = $v.Value; Supported = $v.Supported; Reason = $why }
        if ($v.Kind -eq 'array' -or $v.Kind -eq 'inline table') {
            $sub = Get-TomlTable -Tables $tables -Segments (@($current.Segments) + @($k))
            Set-TomlUnsupported $sub $why
        }
    }
    return $result
}

# A setting that must be a plain string: { Present; Value; Line; Reason } - Reason when
# it is present but not a plain string.
function Get-TomlString {
    param($Table, [string]$Key)
    if (-not $Table -or -not $Table.Entries.ContainsKey($Key)) { return [pscustomobject]@{ Present = $false; Value = ''; Line = 0; Reason = '' } }
    $e = $Table.Entries[$Key]
    $why = ''
    if (-not $e.Supported) { $why = $e.Reason }
    elseif ($e.Kind -ne 'string') { $why = "'$Key' at line $($e.Line) of the Codex config is a $($e.Kind), not a string" }
    return [pscustomobject]@{ Present = $true; Value = [string]$e.Value; Line = $e.Line; Reason = $why }
}

function Get-ProviderNames {
    param($Config)
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($t in $Config.Tables.Values) {
        if (@($t.Segments).Count -eq 2 -and $t.Segments[0] -ceq 'model_providers') { $names.Add($t.Segments[1]) }
    }
    return , $names.ToArray()
}

# [model_providers.<Name>]: { Found; Ok; Reason; Table }. Usable only when every key in
# it is plain and nothing else writes into it (dotted keys, inline tables, sub-tables).
function Get-ProviderTable {
    param($Config, [string]$Name)
    $key = (@('model_providers', $Name) -join $script:TomlKeySep)
    if (-not $Config.Tables.ContainsKey($key)) {
        # Declared only below its own path (a dotted key or header writing
        # model_providers.<name>.x): the provider exists, but not as a plain table.
        $prefix = $key + $script:TomlKeySep
        foreach ($other in $Config.Tables.Values) {
            if ((@($other.Segments) -join $script:TomlKeySep).StartsWith($prefix, [StringComparison]::Ordinal)) {
                $why = $other.Reason
                if (-not $why) { $why = "unsupported TOML construct at line $($other.HeaderLine): [$($other.Name)] declares the provider only through a sub-table" }
                return [pscustomobject]@{ Found = $true; Ok = $false; Reason = $why; Table = $null }
            }
        }
        return [pscustomobject]@{ Found = $false; Ok = $false; Reason = ''; Table = $null }
    }
    $t = $Config.Tables[$key]
    $why = ''
    if (-not $t.Ok) { $why = $t.Reason }
    if (-not $why) {
        foreach ($e in $t.Entries.Values) { if (-not $e.Supported) { $why = $e.Reason; break } }
    }
    if (-not $why) {
        $prefix = $key + $script:TomlKeySep
        foreach ($other in $Config.Tables.Values) {
            if ((@($other.Segments) -join $script:TomlKeySep).StartsWith($prefix, [StringComparison]::Ordinal)) {
                $why = $other.Reason
                if (-not $why) { $why = "unsupported TOML construct at line $($other.HeaderLine): [$($other.Name)] (a sub-table of the provider)" }
                break
            }
        }
    }
    return [pscustomobject]@{ Found = $true; Ok = (-not $why); Reason = $why; Table = $t }
}

# Can the scanner establish whether model_providers.<Name> is declared at all? '' = yes
# (it is a plain table, or nothing declares it); otherwise the reason. A TOML value at key
# path P only defines keys below P, so what can hide a declaration of
# model_providers.<Name> is a construct at `model_providers` itself (an inline table,
# array or string value; a dotted key `model_providers.<x> = ...` written from the top
# level; an array of tables; a table defined twice) or an entry <Name> inside a
# [model_providers] table that is not a sub-table header (an inline table, a dotted key,
# a multi-line string, even a plain value). A construct under model_providers.<other>
# cannot declare <Name> and does not count.
function Get-ProviderSetProblem {
    param($Config, [string]$Name)
    $top = $Config.Tables['']
    # (a top-level dotted key model_providers.<x>... is judged by the table it writes
    # into, which the scanner marked: [model_providers] itself, or <x>'s table)
    if ($top -and $top.Entries.ContainsKey('model_providers') -and $top.Entries['model_providers'].Kind -ne 'dotted key') {
        $e = $top.Entries['model_providers']
        $why = $e.Reason
        if (-not $why) { $why = "model_providers at line $($e.Line) is a $($e.Kind), not a table of providers" }
        return $why
    }
    if ($Config.Tables.ContainsKey('model_providers')) {
        $mp = $Config.Tables['model_providers']
        if (-not $mp.Ok) { return $mp.Reason }
        if ($mp.Entries.ContainsKey($Name)) {
            $e = $mp.Entries[$Name]
            $why = $e.Reason
            if (-not $why) { $why = "[model_providers] declares $Name at line $($e.Line) as a $($e.Kind), not as a table" }
            return $why
        }
    }
    return ''
}

# base_url as the provider identity sees it: scheme and host lowercased, credentials
# (user:pass@) dropped, path as written, no trailing slash. { Url; HostName }.
function ConvertTo-CanonicalBaseUrl {
    param([string]$Url)
    $u = ([string]$Url).Trim()
    $m = [regex]::Match($u, '^([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]*)(.*)$')
    if (-not $m.Success) { return [pscustomobject]@{ Url = $u.TrimEnd([char]'/'); HostName = '' } }
    $scheme = $m.Groups[1].Value.ToLowerInvariant()
    $authority = $m.Groups[2].Value
    $at = $authority.LastIndexOf([char]'@')
    if ($at -ge 0) { $authority = $authority.Substring($at + 1) }
    $authority = $authority.ToLowerInvariant()
    $hostName = $authority
    if ($hostName.StartsWith('[')) {
        $close = $hostName.IndexOf([char]']')
        if ($close -gt 0) { $hostName = $hostName.Substring(0, $close + 1) }
    } else {
        $hostName = $hostName -replace ':[0-9]*$', ''
    }
    return [pscustomobject]@{ Url = ("${scheme}://$authority" + $m.Groups[3].Value).TrimEnd([char]'/'); HostName = $hostName }
}

# Endpoint identity of a usable provider table: { Compat; HostName; BaseUrl; WireApi;
# Display; Config; Error }. Compat = 'cc-provider-v1|base_url=<canonical>|wire_api=<v>'.
# An absent wire_api is 'default' there - no protocol is asserted, and adding the key
# later is a detected change - and provider_config then has no wire_api key. An absent
# base_url is '' (Codex's own default endpoint, not asserted either).
# Config = the table without secret-like keys, sorted by key, base_url without
# credentials and query values (audit metadata, never compared; the fingerprint covers
# the full canonical URL).
function Get-ProviderEndpoint {
    param($Table, [string]$TableName, [string]$Where)
    $r = [pscustomobject]@{ Compat = ''; HostName = ''; BaseUrl = ''; WireApi = ''; Display = ''; Config = (New-Object PSObject); Error = '' }
    $bu = Get-TomlString -Table $Table -Key 'base_url'
    $wa = Get-TomlString -Table $Table -Key 'wire_api'
    if ($bu.Reason) { $r.Error = "$TableName in $Where is not usable - $($bu.Reason)"; return $r }
    if ($wa.Reason) { $r.Error = "$TableName in $Where is not usable - $($wa.Reason)"; return $r }
    $cu = ConvertTo-CanonicalBaseUrl $bu.Value
    $wire = 'default'
    $wireLabel = '(default)'
    if ($wa.Present) { $wire = $wa.Value.Trim(); $wireLabel = $wire }
    $audit = ($cu.Url -replace '\?.*$', '?...')
    $r.Compat = "cc-provider-v1|base_url=$($cu.Url)|wire_api=$wire"
    $r.HostName = $cu.HostName
    $r.BaseUrl = $cu.Url
    $r.WireApi = $wireLabel
    $r.Display = "endpoint $(if ($audit) { $audit } else { '(default)' }), wire_api: $wireLabel"
    $keys = [string[]]@($Table.Entries.Keys)
    [Array]::Sort($keys, [StringComparer]::Ordinal)
    foreach ($key in $keys) {
        if ($key -match $script:SecretKeyPattern) { continue }
        $e = $Table.Entries[$key]
        $val = $e.Value
        if ($key -ceq 'base_url') { $val = $audit }
        elseif ($e.Kind -eq 'boolean') { $val = ($e.Value -ceq 'true') }
        elseif ($e.Kind -eq 'integer') { $n = [long]0; if ([long]::TryParse(($e.Value -replace '_', ''), [ref]$n)) { $val = $n } }
        $r.Config | Add-Member -NotePropertyName $key -NotePropertyValue $val
    }
    return $r
}

# The reviewer this run will talk to, as Codex will resolve it:
#   provider  -Provider, else the config's model_provider, else 'openai' (Codex default)
#   model     -Model, else the config's model
#   endpoint  any provider with a [model_providers.<name>] table: its base_url and
#             wire_api (Get-ProviderEndpoint). openai WITHOUT such a table: built in,
#             'cc-provider-v1|builtin:openai', plus '|base_url=<canonical>' when
#             OPENAI_BASE_URL (honoured by Codex for its built-in provider) is set.
#             A user-defined [model_providers.openai] table is used for the identity
#             when it is usable (whether Codex merges it over the built-in is not
#             verified - the table is the safer claim, and it is noted in
#             identity_note); an unusable one leaves the identity unresolved.
#             provider_fingerprint = SHA-256 of that canonical string: comments, key
#             order, whitespace, `name`, headers and secret rotation never change it.
# Resolved = provider, model and endpoint all known and no profile in play; otherwise
# Fingerprint is '' (such a run is never a parent) and Note says why (Note may also
# carry information on a resolved identity). Error is set only for an explicit
# -Provider that cannot be used (the caller refuses the run).
function Resolve-ReviewerIdentity {
    param($Config, [string]$Provider = '', [string]$Model = '', [string]$OpenAiBaseUrl = '', [string]$Engine = 'codex', [string]$Launcher = '', [string]$Auth = '', $Endpoint = $null)
    $notes = New-Object System.Collections.Generic.List[string]
    $id = [pscustomobject]@{
        Provider       = 'unknown'
        ProviderSource = ''
        Model          = 'unknown'
        ModelSource    = 'unknown'
        Lineage        = ''
        Resolved       = $false
        Note           = ''
        Error          = ''
        Fingerprint    = ''
        CompatString   = ''
        HostName       = ''
        BaseUrl        = ''
        WireApi        = ''
        ProviderConfig = (New-Object PSObject)
        Display        = 'endpoint unknown'
        ConfigPath     = [string]$Config.Path
        Engine         = 'codex'
        Auth           = ''
        Endpoint       = $null
    }
    # Another engine than codex (Resolve-EngineIdentity): no Codex config lookup at all.
    if ($Engine -and $Engine -ne 'codex') { return (Resolve-EngineIdentity -Identity $id -Engine $Engine -Provider $Provider -Model $Model -Launcher $Launcher -Auth $Auth -Endpoint $Endpoint) }
    $where = if ($Config.Path) { [string]$Config.Path } else { '(no Codex home)' }
    $fileReason = ''
    if ($Config.Exists -and -not $Config.Ok) { $fileReason = $Config.Reason }
    $top = $null
    if ($Config.Exists -and $Config.Ok) { $top = $Config.Tables[''] }
    $topReason = $fileReason
    if (-not $topReason -and $top -and -not $top.Ok) { $topReason = $top.Reason }
    # An unreadable file cannot rule out a profile: never resolved.
    if ($fileReason) { $notes.Add($fileReason) }
    if ($top) {
        $pf = Get-TomlString -Table $top -Key 'profile'
        if ($pf.Present) {
            if ($pf.Reason) { $notes.Add($pf.Reason) }
            else { $notes.Add("the Codex config selects profile '$($pf.Value)' (line $($pf.Line)); profiles are not supported - a profile can change the provider, the model and the effort behind the bridge") }
        }
    }
    $cfgProvider = $null
    $cfgModel = $null
    if ($top -and -not $topReason) {
        $cfgProvider = Get-TomlString -Table $top -Key 'model_provider'
        $cfgModel = Get-TomlString -Table $top -Key 'model'
    }

    if ($Provider) {
        $id.Provider = $Provider; $id.ProviderSource = '-Provider'
    } elseif ($topReason) {
        if (-not $notes.Contains($topReason)) { $notes.Add($topReason) }
    } elseif ($cfgProvider -and $cfgProvider.Present) {
        if ($cfgProvider.Reason) { $notes.Add($cfgProvider.Reason) }
        elseif (-not $cfgProvider.Value) { $notes.Add("model_provider at line $($cfgProvider.Line) of $where is empty") }
        else { $id.Provider = $cfgProvider.Value; $id.ProviderSource = 'config' }
    } else {
        $id.Provider = 'openai'; $id.ProviderSource = 'codex default'
    }

    if ($Model) {
        $id.Model = $Model; $id.ModelSource = '-Model'
    } elseif ($topReason) {
        if (-not $notes.Contains($topReason)) { $notes.Add($topReason) }
    } elseif ($cfgModel -and $cfgModel.Present) {
        if ($cfgModel.Reason) { $notes.Add($cfgModel.Reason) }
        elseif (-not $cfgModel.Value) { $notes.Add("model at line $($cfgModel.Line) of $where is empty") }
        else { $id.Model = $cfgModel.Value; $id.ModelSource = 'config' }
    } elseif ($Config.Exists) {
        $notes.Add("no -Model and no top-level model in $where")
    } else {
        $notes.Add("no -Model and no Codex config at $where (the model Codex picks by default is not known to the bridge)")
    }

    $compat = ''
    $infos = New-Object System.Collections.Generic.List[string]
    if ($id.ProviderSource) {
        $name = $id.Provider
        $tableName = '[' + (Format-TomlPath @('model_providers', $name)) + ']'
        $err = ''
        $pt = $null
        $setProblem = ''
        if ($Config.Exists -and $Config.Ok) {
            $pt = Get-ProviderTable -Config $Config -Name $name
            $setProblem = Get-ProviderSetProblem -Config $Config -Name $name
        }
        if ($setProblem) {
            # Something the scanner cannot read may declare this provider: neither the
            # built-in fallback nor "unknown provider" can be claimed.
            $err = "the providers in $where could not be established, so $tableName may be declared there - $setProblem"
        } elseif ($name -ceq 'openai' -and -not ($pt -and $pt.Found)) {
            # Built in, no user table. (A config that cannot be scanned is already a
            # note: it cannot rule out a [model_providers.openai] table either.)
            $compat = 'cc-provider-v1|builtin:openai'
            $id.HostName = 'builtin:openai'
            $id.WireApi = '(built in)'
            $display = 'endpoint builtin:openai'
            $pc = New-Object PSObject
            $pc | Add-Member -NotePropertyName 'builtin' -NotePropertyValue 'openai'
            if ($OpenAiBaseUrl -and $OpenAiBaseUrl.Trim()) {
                $cu = ConvertTo-CanonicalBaseUrl $OpenAiBaseUrl
                $audit = ($cu.Url -replace '\?.*$', '?...')
                $compat += "|base_url=$($cu.Url)"
                $id.HostName = $cu.HostName
                $id.BaseUrl = $cu.Url
                $display += " via OPENAI_BASE_URL $audit"
                $pc | Add-Member -NotePropertyName 'base_url' -NotePropertyValue $audit
                $pc | Add-Member -NotePropertyName 'base_url_source' -NotePropertyValue 'OPENAI_BASE_URL'
            }
            $id.ProviderConfig = $pc
            $id.Display = $display
        } elseif (-not $Config.Exists) {
            $err = "unknown provider '$name': there is no Codex config at $where, so there is no $tableName table (built in: openai)"
        } elseif (-not $Config.Ok) {
            $err = "$tableName cannot be read: $($Config.Reason)"
        } elseif (-not $pt.Found) {
            $found = Get-ProviderNames -Config $Config
            $list = '(none)'
            if ($found.Count -gt 0) { $list = $found -join ', ' }
            $err = "unknown provider '$name': $where has no $tableName table; providers found: $list (built in: openai)"
        } elseif (-not $pt.Ok) {
            $err = "$tableName in $where is not usable - $($pt.Reason)"
        } else {
            $ep = Get-ProviderEndpoint -Table $pt.Table -TableName $tableName -Where $where
            if ($ep.Error) { $err = $ep.Error }
            else {
                $compat = $ep.Compat
                $id.HostName = $ep.HostName
                $id.BaseUrl = $ep.BaseUrl
                $id.WireApi = $ep.WireApi
                $id.ProviderConfig = $ep.Config
                $id.Display = $ep.Display
                if ($name -ceq 'openai') { $infos.Add('user-defined [model_providers.openai] table used for the identity') }
            }
        }
        if ($err) {
            if ($id.ProviderSource -eq '-Provider') { $id.Error = $err }
            elseif ($name -ceq 'openai') { $notes.Add("$(if ($id.ProviderSource -eq 'config') { "the config's model_provider" } else { "Codex's default provider openai" }): $err") }
            else { $notes.Add("the config's model_provider: $err") }
            $compat = ''
        }
    }
    $id.Lineage = Format-Lineage -Provider $id.Provider -Model $id.Model
    $id.Resolved = [bool]($id.ProviderSource -and $id.ModelSource -ne 'unknown' -and $compat -and -not $id.Error -and $notes.Count -eq 0)
    if ($id.Resolved) {
        $id.CompatString = $compat
        $id.Fingerprint = Get-Sha256Hex ($script:Utf8NoBom.GetBytes($compat))
    }
    $id.Note = ((@($notes.ToArray()) + @($infos.ToArray())) -join '; ')
    return $id
}

# Display form of a lineage: '<provider> :: <model>'. Display metadata only - a provider
# name or a model may itself contain '/' or '::', so identities are always compared field
# by field (reviewer.provider, reviewer.model, provider_fingerprint), never by this string.
function Format-Lineage {
    param([string]$Provider, [string]$Model)
    return "$Provider :: $Model"
}

# The lineage as listings show it: Format-Lineage plus ' [<engine>]' for an engine other
# than codex ('' or absent = codex, the engine of every entry recorded before 0.4.0).
function Format-ReviewerLineage {
    param([string]$Provider, [string]$Model, [string]$Engine = '')
    $l = Format-Lineage -Provider $Provider -Model $Model
    if ($Engine -and $Engine -ne 'codex') { $l += " [$Engine]" }
    return $l
}

# The engine of a ledger entry's reviewer: reviewer.engine, 'codex' when absent (every entry
# recorded before 0.4.0, and legacy entries without a reviewer).
function Get-EntryEngine {
    param($Entry)
    $rev = Get-PropertyValue $Entry 'reviewer' $null
    $e = [string](Get-PropertyValue $rev 'engine' '')
    if (-not $e) { return 'codex' }
    return $e
}

# The engine branch of Resolve-ReviewerIdentity (see the engine table below): the provider is
# a free label (default: the engine's DefaultProvider), the model is REQUIRED (for agy the full
# id with its tier), the endpoint is the engine itself - HostName 'engine:<name>', CompatString
# 'cc-engine-v1|<name>', Fingerprint its SHA-256 (a thread of the engine never mixes with a codex
# thread), ProviderConfig { engine; launcher }. Error: an unknown engine or a missing model.
# (wave 29) An engine that takes a roster `auth` (claude: AuthModes subscription | api-key; '' = the
# first): Auth is kept on the identity, and (D7 / F03-7) the endpoint - the fingerprint the health
# records are keyed by - is the engine + the auth mode + the model family
# ('cc-engine-v1|claude|subscription|opus'): an Opus limit never marks Sonnet or the API key out.
# (wave 29b, E5) auth endpoint (the roster entry's $Endpoint): the ROUTE identity -
# 'cc-engine-v1|claude|endpoint|<canonical base_url>|<env_key name>' (lineage, parenting, the
# health of auth, transport and capability failures); provider_config {engine, launcher,
# credential_mechanism endpoint, base_url, env_key, plan}; Display names the base URL. The plan
# (quota) is not part of it (Get-PlanQuotaVerdict). An endpoint auth without an endpoint is an error.
function Resolve-EngineIdentity {
    param($Identity, [string]$Engine, [string]$Provider, [string]$Model, [string]$Launcher, [string]$Auth = '', $Endpoint = $null)
    $id = $Identity
    $id.Engine = $Engine
    $spec = Get-EngineSpec -Name $Engine
    if (-not $spec) {
        $id.Error = "unknown engine '$Engine' (engines: $($script:EngineNames -join ', '))"
        $id.Lineage = Format-Lineage -Provider $id.Provider -Model $id.Model
        return $id
    }
    $authModes = @(Get-PropertyValue $spec 'AuthModes' @())
    if ($authModes.Count -gt 0) {
        if ($Auth -and $authModes -notcontains $Auth) { $id.Error = "the $Engine engine takes auth $($authModes -join ' or ') (got '$Auth')" }
        if ($null -eq $id.PSObject.Properties['Auth']) { $id | Add-Member -NotePropertyName 'Auth' -NotePropertyValue '' }
        $id.Auth = $(if ($authModes -contains $Auth) { $Auth } else { [string]$authModes[0] })
        if ($null -eq $id.PSObject.Properties['Endpoint']) { $id | Add-Member -NotePropertyName 'Endpoint' -NotePropertyValue $null }
        if ($id.Auth -eq 'endpoint') {
            $id.Endpoint = $Endpoint
            $epWhy = Get-ClaudeEndpointProblem $Endpoint
            if ($epWhy -and -not $id.Error) { $id.Error = "the $Engine engine's auth endpoint is not usable: $epWhy" }
        }
    }
    if ($Provider) { $id.Provider = $Provider; $id.ProviderSource = '-Provider' }
    else { $id.Provider = [string]$spec.DefaultProvider; $id.ProviderSource = 'engine default' }
    if ($Model) { $id.Model = $Model; $id.ModelSource = '-Model' }
    else { $id.Error = "the $Engine engine needs a model: pass -Model <id> (the full model id, e.g. $($spec.ModelExample)) or name it in the roster entry" }
    $id.HostName = [string]$spec.HostName
    $id.WireApi = ''
    $id.BaseUrl = ''
    $pc = New-Object PSObject
    $pc | Add-Member -NotePropertyName 'engine' -NotePropertyValue $Engine
    $pc | Add-Member -NotePropertyName 'launcher' -NotePropertyValue $(if ($Launcher) { $Launcher } else { '' })
    # (wave 23) the engine's own fields - muse: credential_mechanism (D4); (wave 29) claude:
    # credential_mechanism (the roster's auth), auth_method, api_provider
    if ($spec.Adapter -and $spec.Adapter.PSObject.Properties['IdentityConfig'] -and $spec.Adapter.IdentityConfig) {
        $icArgs = @{}
        if ($authModes.Count -gt 0) { $icArgs['Auth'] = [string]$id.Auth; $icArgs['Launcher'] = $Launcher }
        if ($id.Auth -eq 'endpoint') { $icArgs['Endpoint'] = $id.Endpoint }
        $extra = & $spec.Adapter.IdentityConfig @icArgs
        foreach ($k in @($extra.Keys)) { $pc | Add-Member -NotePropertyName ([string]$k) -NotePropertyValue $extra[$k] }
    }
    $id.ProviderConfig = $pc
    $id.Display = "engine $Engine ($(if ($Launcher) { $Launcher } else { "$($spec.Command) CLI not found" }))"
    if ($id.Auth -eq 'endpoint' -and $id.Endpoint) { $id.Display += ", endpoint $($id.Endpoint.BaseUrl) (token from env $($id.Endpoint.EnvKey))" }
    $id.ConfigPath = ''
    $id.Lineage = Format-Lineage -Provider $id.Provider -Model $id.Model
    if (-not $id.Error) {
        $id.Resolved = $true
        $id.CompatString = [string]$spec.CompatString
        if ($authModes.Count -gt 0 -and $id.Auth -eq 'endpoint') {
            $id.CompatString = "$($spec.CompatString)|endpoint|$($id.Endpoint.Canonical)|$($id.Endpoint.EnvKey)"
        } elseif ($authModes.Count -gt 0) {
            $family = $(if ($Engine -eq 'claude') { Get-ClaudeModelFamily $id.Model } else { '' })
            $id.CompatString = "$($spec.CompatString)|$($id.Auth)|$(if ($family) { $family } else { (ConvertTo-ClaudeModelBase $id.Model) })"
        }
        $id.Fingerprint = Get-Sha256Hex ($script:Utf8NoBom.GetBytes($id.CompatString))
    }
    return $id
}

# The `reviewer` object of a ledger entry. `engine` (0.4.0): codex | agy | muse; readers treat an
# absent field as codex.
function New-ReviewerRecord {
    param($Identity, [string]$Harness)
    $engine = [string]$Identity.Engine
    if (-not $engine) { $engine = 'codex' }
    return [pscustomobject]@{
        provider             = $Identity.Provider
        provider_source      = $(if ($Identity.ProviderSource) { $Identity.ProviderSource } else { 'unknown' })
        model                = $Identity.Model
        model_source         = $Identity.ModelSource
        engine               = $engine
        harness              = $Harness
        provider_fingerprint = $Identity.Fingerprint
        provider_config      = $Identity.ProviderConfig
        identity_note        = $Identity.Note
    }
}

# Per-run Codex config overrides: -CodexConfig and a roster entry's codex_config follow the
# same rules. Each item is key=value; one string may carry several, split only at a comma
# that starts the next key=, so a value like [1,2] stays whole. Keys that would change what
# the ledger records (model, model_provider, profile, model_reasoning_effort,
# model_providers.*) are refused. A value starting with ~/ or ~\ gets the home directory
# ($HOME, else USERPROFILE) and forward slashes (Codex does not expand ~; on Windows
# `~/...` fails with os error 123). A value that is not a TOML literal is wrapped in double
# quotes (Codex parses the value as TOML and falls back to a literal string, so a bare path
# is a TOML string either way). { Items (string[], as passed to codex and recorded in the
# ledger); Error ('' or the message, prefixed by $Label) }.
function ConvertFrom-CodexConfigItems {
    param([string[]]$Values, [string]$Label = '-CodexConfig')
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($cfgArg in @($Values)) {
        if (-not $cfgArg -or -not $cfgArg.Trim()) { continue }
        foreach ($item in ($cfgArg.Trim() -split ',(?=\s*[A-Za-z0-9_.]+=)')) {
            $item = $item.Trim()
            if ($item -notmatch '^[A-Za-z0-9_.]+=.+$') {
                return [pscustomobject]@{ Items = [string[]]@(); Error = "$Label '$item' is malformed: expected key=value (key: letters, digits, _ and .; a non-empty value)." }
            }
            $cfgKey = $item.Substring(0, $item.IndexOf('='))
            $cfgValue = $item.Substring($item.IndexOf('=') + 1)
            if (@('model', 'model_provider', 'profile', 'model_reasoning_effort', 'model_providers') -ccontains $cfgKey -or $cfgKey.StartsWith('model_providers.', [StringComparison]::Ordinal)) {
                return [pscustomobject]@{ Items = [string[]]@(); Error = "$Label '$item' is refused: $cfgKey is part of the reviewer identity and effort the bridge records (use -Model / -Provider / -Effort; providers belong in the Codex config)." }
            }
            if ($cfgValue -match '^~[\\/]') {
                $homeDir = $HOME
                if (-not $homeDir) { $homeDir = $env:USERPROFILE }
                $cfgValue = (($homeDir.TrimEnd([char]'\', [char]'/') + $cfgValue.Substring(1)) -replace '\\', '/')
            }
            if ($cfgValue -notmatch '^(["''0-9\[{]|true$|false$)') { $cfgValue = '"' + (ConvertTo-TomlBasicString $cfgValue) + '"' }
            $items.Add("$cfgKey=$cfgValue")
        }
    }
    return [pscustomobject]@{ Items = [string[]]$items.ToArray(); Error = '' }
}

# ----------------------------------------------------------------------------- effort vocabularies
#
# -Effort and the purpose presets speak low|medium|high|xhigh. What an endpoint accepts
# is DECLARED, never inferred (no host-wide or model-prefix guess): capability table
# caps-v1 -
#   the built-in openai provider (no user table, no OPENAI_BASE_URL)
#       vocabulary openai for any model (Codex validates its own models)   low medium high xhigh
#   hosts api.z.ai, open.bigmodel.cn
#       vocabulary zai (mapping zai-v1) ONLY for the declared models below  low high max
#       (exact, case-sensitive): medium -> high, xhigh -> max
#   hosts token-plan-ams.xiaomimimo.com, token-plan-cn.xiaomimimo.com, api.xiaomimimo.com
#       vocabulary mimo (mapping mimo-v1) ONLY for the declared models     none low medium
#       below (exact): low, medium, high as is, xhigh -> high               high
#   host ark.ap-southeast.bytepluses.com (BytePlus ModelArk Coding Plan)
#       vocabulary ark (mapping ark-v1) ONLY for the declared models     low medium high
#       below (exact): low, medium, high as is, xhigh -> high
#   host api.kimi.ai (Kimi Code membership)
#       vocabulary kimi (mapping kimi-v1) ONLY for the declared models   low high max
#       below (exact): medium -> high, xhigh -> max
#   host token-plan.ap-southeast-1.maas.aliyuncs.com (Alibaba Model Studio Token Plan)
#       vocabulary alibaba (mapping alibaba-v1) ONLY for the declared    low medium high
#       models below (exact), all four as is. The plan's `auto` router   xhigh
#       is not declared: the endpoint picks its target model, so the accepted effort is unknown.
#   engine:agy (the agy engine, any model)
#       vocabulary model-tier (mapping model-tier): NOTHING is sent - the reasoning tier is
#       part of the agy model id (gemini-3.8-flash-high); effort_sent null. -NativeEffort
#       sends --effort <value> verbatim (agy checks it against the tier itself). The reply
#       schema travels natively (--json-schema): SchemaTransport 'native'.
#   engine:muse (the muse engine: Meta's Muse Code CLI, wave 23)
#       vocabulary muse (mapping muse-v1) ONLY for the live-verified   low medium high
#       subscription models below (exact): all four as is, sent as      xhigh
#       --reasoning-effort <v>. The reply schema travels natively (--output-schema):
#       SchemaTransport 'native'.
#   engine:claude (the claude engine: Claude Code headless, wave 29)
#       vocabulary claude (mapping claude-v1) for any model of the    low medium high
#       engine's table: all four as is, sent as --effort <v> (the      xhigh
#       CLI also takes max - only through -NativeEffort). Whether a model without adaptive
#       reasoning applies it is not known (effort_confirmed null). The reply schema travels
#       natively (--json-schema, its text): SchemaTransport 'native'.
# A vocabulary a caps row names but $script:EffortVocabularies lacks is a plan error (a bridge
# defect, never a silently empty mapping).
# Anything else - an undeclared model on a known host, any model on another endpoint -
# has no vocabulary: the run is refused unless -NativeEffort sends a value verbatim.
# Codex's events do not report the effort the endpoint applied: effort_confirmed is null.
$script:EffortCapsVersion = 'caps-v1'
$script:EffortVocabularies = @{
    'openai' = @{ Mapping = 'openai'; Map = @{ 'low' = 'low'; 'medium' = 'medium'; 'high' = 'high'; 'xhigh' = 'xhigh' } }
    'zai'    = @{ Mapping = 'zai-v1'; Map = @{ 'low' = 'low'; 'medium' = 'high'; 'high' = 'high'; 'xhigh' = 'max' } }
    'mimo'   = @{ Mapping = 'mimo-v1'; Map = @{ 'low' = 'low'; 'medium' = 'medium'; 'high' = 'high'; 'xhigh' = 'high' } }
    # BytePlus ModelArk Coding Plan (the Codex integration doc: model_reasoning_effort = low | medium | high)
    'ark'    = @{ Mapping = 'ark-v1'; Map = @{ 'low' = 'low'; 'medium' = 'medium'; 'high' = 'high'; 'xhigh' = 'high' } }
    # Kimi Code (Moonshot) on its Codex base URL: K3 takes low | high | max (the Kimi Code Codex doc)
    'kimi'   = @{ Mapping = 'kimi-v1'; Map = @{ 'low' = 'low'; 'medium' = 'high'; 'high' = 'high'; 'xhigh' = 'max' } }
    # Alibaba Cloud Model Studio Token Plan: every text model takes low | medium | high | xhigh
    # (the Model Studio Codex doc, 2026-09-26)
    'alibaba' = @{ Mapping = 'alibaba-v1'; Map = @{ 'low' = 'low'; 'medium' = 'medium'; 'high' = 'high'; 'xhigh' = 'xhigh' } }
    # Meta's Muse Code CLI (--reasoning-effort none|minimal|low|medium|high|xhigh|max|ultra)
    'muse'    = @{ Mapping = 'muse-v1'; Map = @{ 'low' = 'low'; 'medium' = 'medium'; 'high' = 'high'; 'xhigh' = 'xhigh' } }
    # (wave 29) Claude Code (--effort low|medium|high|xhigh|max - its help; max only via -NativeEffort)
    'claude'  = @{ Mapping = 'claude-v1'; Map = @{ 'low' = 'low'; 'medium' = 'medium'; 'high' = 'high'; 'xhigh' = 'xhigh' } }
}
# The model names Kimi Code accepts on https://api.kimi.ai/coding/v1 (its Codex doc; which of them a
# membership unlocks depends on the tier: Plus has k3 at 256K context, Pro adds the 1M window and
# kimi-for-coding-highspeed).
$script:KimiDeclaredModels = @('k3', 'k3-256k', 'kimi-for-coding', 'kimi-for-coding-highspeed')
$script:ZaiDeclaredModels = @('glm-5.3', 'glm-5.3-flash', 'glm-5.3-flashx', 'glm-5.2', 'glm-5.1', 'glm-5', 'glm-5-turbo', 'glm-4.7', 'glm-4.6', 'glm-4.5', 'glm-4.5-air')
$script:MimoDeclaredModels = @('mimo-v2.6-pro', 'mimo-v2.6-flash', 'mimo-v2.6-pro-ultraspeed', 'mimo-v2.5-pro', 'mimo-v2.5')
# The model names the BytePlus ModelArk Coding Plan accepts on its Codex (OpenAI-protocol) base URL
# https://ark.ap-southeast.bytepluses.com/api/coding/v3 (its quick-start guide, 2026-09-24).
$script:ArkPlanDeclaredModels = @('dola-seed-2.0-pro', 'dola-seed-2.0-lite', 'dola-seed-2.0-code', 'bytedance-seed-code', 'glm-5.3-flash', 'glm-5.2', 'glm-5.1', 'kimi-k2.5', 'gpt-oss-120b', 'deepseek-v4.1-flash', 'deepseek-v4-flash', 'deepseek-v4-pro')
# The text models the Alibaba Cloud Model Studio Token Plan (Personal Edition) lists on its
# subscription page and the Codex doc (2026-09-26), without the plan's `auto` router (its target
# model - and so the effort it accepts - is chosen by the endpoint).
# The Muse Code subscription models verified live through `muse exec` (2026-09-25/26): the
# contributor variant (the CLI default; Meta may train on its inputs) and the standard one. The
# docs also list the 1.2 pair and 1.1 - not declared until verified.
$script:MuseDeclaredModels = @('muse-spark-1.3', 'muse-spark-1.3-contributor')
$script:AlibabaTokenPlanDeclaredModels = @('qwen3.8-max', 'qwen3.8-flash', 'qwen3.7-max', 'qwen3.7-plus', 'qwen3.6-flash', 'deepseek-v4.1-flash', 'deepseek-v4-pro', 'deepseek-v4-pro-0813', 'deepseek-v4-flash-0731', 'glm-5.3', 'glm-5.2')
# host -> { Vocabulary; Models ($null = any model); SchemaTransport }. SchemaTransport: how
# the reply schema reaches the endpoint - 'output-schema' (--output-schema; the built-in
# openai enforces it, z.ai accepts it without enforcing) or 'prompt-only' (MiMo rejects a
# json_schema response format: the schema travels in the prompt only). An endpoint not
# in the table is 'prompt-only' (Get-SchemaTransport).
$script:EffortCaps = @{
    'builtin:openai'                = @{ Vocabulary = 'openai'; Models = $null; SchemaTransport = 'output-schema' }
    'api.z.ai'                      = @{ Vocabulary = 'zai'; Models = $script:ZaiDeclaredModels; SchemaTransport = 'output-schema' }
    'open.bigmodel.cn'              = @{ Vocabulary = 'zai'; Models = $script:ZaiDeclaredModels; SchemaTransport = 'output-schema' }
    'token-plan-ams.xiaomimimo.com' = @{ Vocabulary = 'mimo'; Models = $script:MimoDeclaredModels; SchemaTransport = 'prompt-only' }
    'token-plan-cn.xiaomimimo.com'  = @{ Vocabulary = 'mimo'; Models = $script:MimoDeclaredModels; SchemaTransport = 'prompt-only' }
    'api.xiaomimimo.com'            = @{ Vocabulary = 'mimo'; Models = $script:MimoDeclaredModels; SchemaTransport = 'prompt-only' }
    # BytePlus ModelArk Coding Plan (ap-southeast-1): the quota counts only through the /api/coding/v3
    # base URL; the schema travels in the prompt (a json_schema response format is not documented).
    'ark.ap-southeast.bytepluses.com' = @{ Vocabulary = 'ark'; Models = $script:ArkPlanDeclaredModels; SchemaTransport = 'prompt-only' }
    # Kimi Code membership (overseas domain; the China domain api.kimi.com is not declared): the
    # schema travels in the prompt (a json_schema response format on this route is not documented).
    'api.kimi.ai'                   = @{ Vocabulary = 'kimi'; Models = $script:KimiDeclaredModels; SchemaTransport = 'prompt-only' }
    # Alibaba Cloud Model Studio Token Plan (Singapore only): the quota counts only with the plan's own
    # key (sk-sp-...) on this base URL (/compatible-mode/v1, Responses API); a general Model Studio
    # key or base URL bills pay-as-you-go. The schema travels in the prompt.
    'token-plan.ap-southeast-1.maas.aliyuncs.com' = @{ Vocabulary = 'alibaba'; Models = $script:AlibabaTokenPlanDeclaredModels; SchemaTransport = 'prompt-only' }
    'engine:agy'                    = @{ Vocabulary = 'model-tier'; Models = $null; SchemaTransport = 'native' }
    'engine:muse'                   = @{ Vocabulary = 'muse'; Models = $script:MuseDeclaredModels; SchemaTransport = 'native' }
    # (wave 29) any model of the engine's table (the roster refuses the rest); --json-schema natively
    'engine:claude'                 = @{ Vocabulary = 'claude'; Models = $null; SchemaTransport = 'native' }
}

# { Transport ('output-schema' | 'prompt-only'); Basis } for the identity's endpoint;
# 'prompt-only' is the safe default for an endpoint caps-v1 does not declare (a
# json_schema response format it may reject would fail the whole run).
function Get-SchemaTransport {
    param($Identity)
    $hostName = [string]$Identity.HostName
    if ($hostName -and $script:EffortCaps.ContainsKey($hostName)) {
        return [pscustomobject]@{ Transport = $script:EffortCaps[$hostName].SchemaTransport; Basis = "$($script:EffortCapsVersion): $hostName" }
    }
    $label = if ($hostName) { $hostName } else { 'unknown-host' }
    return [pscustomobject]@{ Transport = 'prompt-only'; Basis = "default for an endpoint $($script:EffortCapsVersion) does not declare: $label" }
}

# { Requested; Sent; Mapping; Caps; Basis; Error }
function Resolve-EffortPlan {
    param($Identity, [string]$Requested, [string]$Native = '')
    $plan = [pscustomobject]@{ Requested = $Requested; Sent = ''; Mapping = ''; Caps = $script:EffortCapsVersion; Basis = ''; Error = '' }
    if ($Native) {
        $plan.Requested = $Native; $plan.Sent = $Native; $plan.Mapping = 'native'; $plan.Basis = '-NativeEffort, sent verbatim'
        return $plan
    }
    $hostName = [string]$Identity.HostName
    $model = [string]$Identity.Model
    $cap = $null
    if ($hostName -and $script:EffortCaps.ContainsKey($hostName)) { $cap = $script:EffortCaps[$hostName] }
    if ($cap -and $cap.Vocabulary -eq 'model-tier') {
        # An engine whose model id carries the reasoning tier: nothing is sent.
        $plan.Sent = $null
        $plan.Mapping = 'model-tier'
        $plan.Basis = "$($script:EffortCapsVersion): engine $($hostName -replace '^engine:', ''), the tier is part of the model id"
        return $plan
    }
    if (-not $cap) {
        $hostLabel = if ($hostName) { $hostName } else { 'unknown-host' }
        # Ordinal order: the same list on Windows PowerShell 5.1 (NLS ignores '-') and pwsh 7 (ICU).
        $declaredHosts = [string[]]@($script:EffortCaps.Keys | Where-Object { $_ -notlike 'engine:*' })
        [Array]::Sort($declaredHosts, [StringComparer]::Ordinal)
        $declared = $declaredHosts -join ', '
        $plan.Error = "no effort vocabulary declared for $hostLabel ($($script:EffortCapsVersion) declares $declared); pass -NativeEffort <value> to send a value verbatim"
        return $plan
    }
    if (($null -ne $cap.Models) -and (($Identity.ModelSource -eq 'unknown') -or -not ($cap.Models -ccontains $model))) {
        $plan.Error = "no effort vocabulary declared for model '$model' on $hostName ($($script:EffortCapsVersion) declares: $($cap.Models -join ', ')); pass -NativeEffort <value> to send a value verbatim"
        return $plan
    }
    $v = $null
    if ($script:EffortVocabularies.ContainsKey([string]$cap.Vocabulary)) { $v = $script:EffortVocabularies[[string]$cap.Vocabulary] }
    if ($null -eq $v) {
        # (wave 23, D10) a caps row whose vocabulary is not declared: loud, never an empty mapping
        $plan.Error = "$($script:EffortCapsVersion) names the effort vocabulary '$($cap.Vocabulary)' for $hostName, but no such vocabulary is declared (a bridge defect); pass -NativeEffort <value> to send a value verbatim"
        return $plan
    }
    $plan.Sent = $v.Map[$Requested]
    $plan.Mapping = $v.Mapping
    $plan.Basis = if ($null -eq $cap.Models) { "$($script:EffortCapsVersion): $hostName, any model" } else { "$($script:EffortCapsVersion): $hostName, $model" }
    return $plan
}

# ----------------------------------------------------------------------------- peak windows
#
# CODEX_CONSULT_PEAK_<PROVIDER> = "<days> <HH:MM>-<HH:MM> <+HH:MM|-HH:MM>" (the provider
# name upper-cased, every character outside A-Z 0-9 replaced by _), e.g.
# CODEX_CONSULT_PEAK_ZAI="Mon-Fri 14:00-18:00 +08:00". Days: *, a day (Mon), a range
# (Mon-Fri; it may wrap: Fri-Mon) or a comma list of those. Optional
# CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT = comma-separated YYYY-MM-DD or
# YYYY-MM-DD..YYYY-MM-DD: those calendar dates (in the schedule's offset) are off-peak all
# day. Evaluated ONCE at launch in the fixed offset: start inclusive, end exclusive (24:00
# = midnight); an overnight window (start > end) spans midnight and its day check applies
# to the day it STARTED. peak = $true | $false; $null = no schedule (unknown). A long
# consultation that starts off-peak may still run into the window.
$script:DayNames = @('sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat')

# The clock of the peak evaluations. TEST HOOK: CODEX_CONSULT_NOW = one or more ISO
# timestamps with an offset, comma-separated; the k-th evaluation of a run uses the k-th
# (the last one repeats), so a test can put the early check off-peak and the launch-time
# check inside the window. Unset: the system clock. { Now (DateTimeOffset); Iso; FromEnv;
# Error }. -Peek reads the value the next evaluation would get without consuming it (the
# endpoint-health reading of the preflight and codex-providers.ps1 use it).
$script:ConsultClockCalls = 0
function Get-ConsultClock {
    param([switch]$Peek)
    $raw = (Get-TestHookValue 'CODEX_CONSULT_NOW')
    $call = $script:ConsultClockCalls
    if (-not $Peek) { $script:ConsultClockCalls++ }
    if (-not $raw.Trim()) {
        $n = [DateTimeOffset]::Now
        return [pscustomobject]@{ Now = $n; Iso = $n.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant); FromEnv = $false; Error = '' }
    }
    $items = @($raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $parsed = New-Object System.Collections.Generic.List[DateTimeOffset]
    foreach ($item in $items) {
        $dto = [DateTimeOffset]::MinValue
        if ($item -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?([+-][0-9]{2}:[0-9]{2}|Z)$' -or -not [DateTimeOffset]::TryParse($item, $script:Invariant, [System.Globalization.DateTimeStyles]::None, [ref]$dto)) {
            return [pscustomobject]@{ Now = $null; Iso = ''; FromEnv = $true; Error = "CODEX_CONSULT_NOW='$raw' is malformed: bad token '$item' (a test hook: ISO timestamps with an offset, e.g. 2026-09-24T13:59:59+08:00, comma-separated)" }
        }
        $parsed.Add($dto)
    }
    $pick = $parsed[[Math]::Min($call, $parsed.Count - 1)]
    return [pscustomobject]@{ Now = $pick; Iso = $pick.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant); FromEnv = $true; Error = '' }
}

# Get-PeakStatus at the clock's current reading; adds EvaluatedAt and marks a peak_source
# 'env (CODEX_CONSULT_NOW)' when the test hook set the time. Error covers both inputs.
function Get-PeakStatusNow {
    param([string]$Provider)
    $clock = Get-ConsultClock
    if ($clock.Error) { return [pscustomobject]@{ Peak = $null; Schedule = ''; Source = 'none'; Variable = ''; Local = ''; Detail = ''; Error = $clock.Error; EvaluatedAt = '' } }
    $st = Get-PeakStatus -Provider $Provider -UtcNow $clock.Now.UtcDateTime
    if ($clock.FromEnv -and $st.Source -eq 'env') { $st.Source = 'env (CODEX_CONSULT_NOW)' }
    $st | Add-Member -NotePropertyName 'EvaluatedAt' -NotePropertyValue $clock.Iso
    return $st
}

function Get-PeakVariableName {
    param([string]$Provider)
    return ('CODEX_CONSULT_PEAK_' + ($Provider.ToUpperInvariant() -replace '[^A-Z0-9]', '_'))
}

# { Days (bool[7], index = [int][DayOfWeek]); Start; End (minutes); Offset; Error }
function ConvertFrom-PeakSpec {
    param([string]$Spec, [string]$VarName)
    $r = [pscustomobject]@{ Days = $null; Start = 0; End = 0; Offset = [TimeSpan]::Zero; Error = '' }
    $format = "expected '<days> <HH:MM>-<HH:MM> <+HH:MM|-HH:MM>', e.g. 'Mon-Fri 14:00-18:00 +08:00'"
    $trimmed = ([string]$Spec).Trim()
    $tokens = @($trimmed -split '\s+')
    if ($tokens.Count -ne 3) {
        $r.Error = "$VarName='$Spec' is malformed: bad token '$trimmed' ($($tokens.Count) field(s) instead of 3); $format"
        return $r
    }
    $dayHelp = 'day names are Mon Tue Wed Thu Fri Sat Sun, a range Mon-Fri, a list Mon,Wed or *'
    $days = New-Object 'bool[]' 7
    if ($tokens[0] -eq '*') {
        for ($d = 0; $d -lt 7; $d++) { $days[$d] = $true }
    } else {
        foreach ($item in $tokens[0].Split(',')) {
            $mRange = [regex]::Match($item, '^([A-Za-z]{3})-([A-Za-z]{3})$')
            if ($mRange.Success) {
                $a = [Array]::IndexOf($script:DayNames, $mRange.Groups[1].Value.ToLowerInvariant())
                $b = [Array]::IndexOf($script:DayNames, $mRange.Groups[2].Value.ToLowerInvariant())
                if ($a -lt 0 -or $b -lt 0) { $r.Error = "$VarName='$Spec' is malformed: bad token '$item' ($dayHelp); $format"; return $r }
                $d = $a
                while ($true) { $days[$d] = $true; if ($d -eq $b) { break }; $d = ($d + 1) % 7 }
                continue
            }
            $one = -1
            if ($item -match '^[A-Za-z]{3}$') { $one = [Array]::IndexOf($script:DayNames, $item.ToLowerInvariant()) }
            if ($one -lt 0) { $r.Error = "$VarName='$Spec' is malformed: bad token '$item' ($dayHelp); $format"; return $r }
            $days[$one] = $true
        }
    }
    $mt = [regex]::Match($tokens[1], '^([0-9]{2}):([0-9]{2})-([0-9]{2}):([0-9]{2})$')
    $timeOk = $mt.Success
    if ($timeOk) {
        $sh = [int]$mt.Groups[1].Value; $sm = [int]$mt.Groups[2].Value; $eh = [int]$mt.Groups[3].Value; $em = [int]$mt.Groups[4].Value
        $timeOk = ($sh -le 23 -and $sm -le 59 -and $em -le 59 -and ($eh -le 23 -or ($eh -eq 24 -and $em -eq 0)))
        if ($timeOk) {
            $r.Start = $sh * 60 + $sm
            $r.End = $eh * 60 + $em
            if ($r.Start -eq $r.End) { $timeOk = $false }
        }
    }
    if (-not $timeOk) { $r.Error = "$VarName='$Spec' is malformed: bad token '$($tokens[1])' (a window HH:MM-HH:MM, 00:00..23:59, end up to 24:00, start <> end); $format"; return $r }
    $mo = [regex]::Match($tokens[2], '^([+-])([0-9]{2}):([0-9]{2})$')
    $offOk = $mo.Success
    if ($offOk) {
        $oh = [int]$mo.Groups[2].Value; $om = [int]$mo.Groups[3].Value
        $offOk = ($om -le 59 -and ($oh * 60 + $om) -le 14 * 60)
        if ($offOk) {
            $r.Offset = New-Object TimeSpan($oh, $om, 0)
            if ($mo.Groups[1].Value -eq '-') { $r.Offset = $r.Offset.Negate() }
        }
    }
    if (-not $offOk) { $r.Error = "$VarName='$Spec' is malformed: bad token '$($tokens[2])' (a UTC offset +HH:MM or -HH:MM, at most 14:00); $format"; return $r }
    $r.Days = $days
    return $r
}

# { Intervals (list of @(start, end) dates, inclusive); Error }. Ranges are kept as
# intervals - any length, never expanded; only end < start is refused.
function ConvertFrom-PeakExceptions {
    param([string]$Text, [string]$VarName)
    $list = New-Object System.Collections.Generic.List[object]
    $r = [pscustomobject]@{ Intervals = $list; Error = '' }
    $format = 'expected comma-separated YYYY-MM-DD or YYYY-MM-DD..YYYY-MM-DD'
    foreach ($raw in ([string]$Text).Split(',')) {
        $item = $raw.Trim()
        if (-not $item) { continue }
        $parts = @($item -split '\.\.')
        $parsed = New-Object System.Collections.Generic.List[datetime]
        foreach ($p in $parts) {
            $dt = [datetime]::MinValue
            if ($p -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' -or -not [datetime]::TryParseExact($p, 'yyyy-MM-dd', $script:Invariant, [System.Globalization.DateTimeStyles]::None, [ref]$dt)) {
                $r.Error = "$VarName='$Text' is malformed: bad token '$item' ($format)"; return $r
            }
            $parsed.Add($dt.Date)
        }
        if ($parsed.Count -gt 2 -or ($parsed.Count -eq 2 -and $parsed[1] -lt $parsed[0])) {
            $r.Error = "$VarName='$Text' is malformed: bad token '$item' ($format; a range must not run backwards)"; return $r
        }
        $list.Add(@($parsed[0], $parsed[$parsed.Count - 1]))
    }
    return $r
}

# { Peak ($true | $false | $null); Schedule; Source ('env'|'none'); Variable; Local;
#   Detail; Error }. -Spec / -Except replace the environment (tests).
function Get-PeakStatus {
    param([string]$Provider, [datetime]$UtcNow = [datetime]::UtcNow, [string]$Spec = $null, [string]$Except = $null)
    $st = [pscustomobject]@{ Peak = $null; Schedule = ''; Source = 'none'; Variable = ''; Local = ''; Detail = 'no schedule'; Error = '' }
    if (-not $Provider) { $st.Detail = 'provider unknown'; return $st }
    $var = Get-PeakVariableName $Provider
    $st.Variable = $var
    if (-not $PSBoundParameters.ContainsKey('Spec')) { $Spec = [Environment]::GetEnvironmentVariable($var) }
    if (-not $PSBoundParameters.ContainsKey('Except')) { $Except = [Environment]::GetEnvironmentVariable($var + '_EXCEPT') }
    if (-not $Spec -or -not $Spec.Trim()) { return $st }
    $parsed = ConvertFrom-PeakSpec -Spec $Spec -VarName $var
    if ($parsed.Error) { $st.Error = $parsed.Error; return $st }
    $exceptions = $null
    if ($Except -and $Except.Trim()) {
        $exceptions = ConvertFrom-PeakExceptions -Text $Except -VarName ($var + '_EXCEPT')
        if ($exceptions.Error) { $st.Error = $exceptions.Error; return $st }
    }
    $st.Source = 'env'
    $st.Schedule = $Spec.Trim()
    if ($exceptions) { $st.Schedule += "; except $($Except.Trim())" }
    $utc = $UtcNow
    if ($utc.Kind -eq [DateTimeKind]::Local) { $utc = $utc.ToUniversalTime() }
    $local = $utc.Add($parsed.Offset)
    $sign = if ($parsed.Offset -lt [TimeSpan]::Zero) { '-' } else { '+' }
    $st.Local = $local.ToString('yyyy-MM-dd HH:mm ddd', $script:Invariant) + " $sign" + $parsed.Offset.Duration().ToString('hh\:mm', $script:Invariant)
    $tod = $local.TimeOfDay.TotalMinutes
    $dow = [int]$local.DayOfWeek
    $prev = ($dow + 6) % 7
    if ($parsed.Start -lt $parsed.End) {
        $inside = ($parsed.Days[$dow] -and $tod -ge $parsed.Start -and $tod -lt $parsed.End)
    } else {
        $inside = (($parsed.Days[$dow] -and $tod -ge $parsed.Start) -or ($parsed.Days[$prev] -and $tod -lt $parsed.End))
    }
    $dateKey = $local.ToString('yyyy-MM-dd', $script:Invariant)
    $exceptionHit = $false
    if ($exceptions) {
        foreach ($iv in $exceptions.Intervals) { if ($local.Date -ge $iv[0] -and $local.Date -le $iv[1]) { $exceptionHit = $true; break } }
    }
    if ($exceptionHit) {
        $st.Peak = $false
        $st.Detail = "exception date $dateKey (off-peak all day)"
    } elseif ($inside) {
        $st.Peak = $true
        $st.Detail = 'inside the peak window'
    } else {
        $st.Peak = $false
        $st.Detail = 'outside the peak window'
    }
    return $st
}

# ----------------------------------------------------------------------------- provider availability
#
# Is a provider usable at all - are its credentials present? Decided locally, never over
# the network:
#   openai (built in), or a table with requires_openai_auth = true
#                 `<codex> login status` (Codex reads its own stored login; timeout
#                 15 s): exit 0 and a "Logged in" line -> ok; anything else -> missing
#   other tables  env_key names an environment variable that is set and non-empty, or
#                 the table carries experimental_bearer_token -> ok; else missing
# A provider that needs no credentials at all (a local endpoint without env_key) reads as
# missing: pass -SkipPreflight for it, or declare it in the reviewer roster with
# "auth": "none" (-Anonymous: ok, "declared anonymous in the roster" - only for a table
# without env_key and bearer token; a table WITH env_key still needs the variable).
# What credentials cannot show - revoked keys,
# exhausted plans - comes from the ledgers: failures are classified (auth, quota,
# capability, transport, unknown) and read back per ENDPOINT (Get-EndpointHealth).

function Resolve-CodexLauncher {
    param([string]$Explicit)
    # An explicit launcher (-CodexExe, then CODEX_CONSULT_EXE) that does not resolve is an
    # error, never a silent fall-through to whatever `codex` is on PATH.
    $explicitSources = @(@{ value = $Explicit; label = '-CodexExe' }, @{ value = $env:CODEX_CONSULT_EXE; label = 'CODEX_CONSULT_EXE' })
    foreach ($source in $explicitSources) {
        $candidate = [string]$source.value
        if ($candidate) {
            if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
            $cmd = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            Stop-WithError "$($source.label) '$candidate' is not a file and not an application on PATH."
        }
    }
    # On Windows, Get-Command 'codex' resolves to codex.ps1 (the npm shim), which
    # Start-Process cannot launch; ask for the native exe / cmd shim first.
    $names = if ($script:OnWindows) { @('codex.exe', 'codex.cmd', 'codex.bat', 'codex') } else { @('codex') }
    foreach ($name in $names) {
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function New-CredentialResult {
    param([string]$State, [string]$Reason)
    $prefix = @{ ok = 'ok: '; missing = 'missing: '; unknown = 'unknown: ' }[$State]
    return [pscustomobject]@{ State = $State; Reason = $Reason; Detail = ($prefix + $Reason) }
}

# (wave 27c, D4) A launcher probe's ProcessStartInfo: no shell, no window, stdin/stdout/stderr
# redirected, UTF-8 output. Built fresh by every Start-ProbeProcess attempt.
function New-ProbeStartInfo {
    param([string]$Launcher, [string]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Launcher
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $script:Utf8NoBom
    $psi.StandardErrorEncoding = $script:Utf8NoBom
    return $psi
}
# `<launcher> login status` with a timeout; stdout and stderr are both read (the status
# line may come on either) and decoded as UTF-8 (the Codex CLI writes UTF-8; the default
# would be the console code page). { State ok|missing|unknown; Reason; Detail }.
function Get-CodexLoginStatus {
    param([string]$Launcher, [int]$TimeoutSec = 15)
    if (-not $Launcher) { return (New-CredentialResult 'unknown' 'codex CLI not found, `codex login status` could not run') }
    $p = $null
    try {
        # (wave 27c, D4) through Start-ProbeProcess: never started with the host markers
        $start = Start-ProbeProcess -Make { New-ProbeStartInfo -Launcher $Launcher -Arguments 'login status' }
        if ($start.Skipped) { return (New-CredentialResult 'unknown' "not checked - ``codex login status`` was skipped: $($start.Skipped)") }
        $p = $start.Proc
    } catch {
        return (New-CredentialResult 'unknown' "``codex login status`` could not be started ($(ConvertTo-OneLine $_.Exception.Message))")
    }
    try {
        try { $p.StandardInput.Close() } catch { }
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $null = Stop-ProcessTree -Process $p
            return (New-CredentialResult 'unknown' "``codex login status`` did not finish within $TimeoutSec s")
        }
        $p.WaitForExit()
        $null = $outTask.Wait(5000)
        $null = $errTask.Wait(5000)
        $lines = @((([string]$outTask.Result) + "`n" + ([string]$errTask.Result)) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $loggedIn = @($lines | Where-Object { $_ -cmatch 'Logged in' }) | Select-Object -First 1
        if ($p.ExitCode -eq 0 -and $loggedIn) { return (New-CredentialResult 'ok' $loggedIn) }
        $first = if ($lines.Count -gt 0) { $lines[0] } else { "exit $($p.ExitCode)" }
        return (New-CredentialResult 'missing' $first)
    } finally {
        $p.Dispose()
    }
}

# Credentials of a provider: $Table is its [model_providers.<name>] table object ($null for
# the built-in openai without one). $LoginCache (a hashtable) avoids running
# `login status` twice in one listing. -Anonymous: the reviewer roster declares the endpoint
# credential-free ("auth": "none").
function Get-ProviderCredential {
    param([string]$Name, $Table, [string]$Launcher, [hashtable]$LoginCache = $null, [int]$TimeoutSec = 15, [switch]$Anonymous)
    $openaiAuth = ($Name -ceq 'openai')
    if (-not $openaiAuth -and $Table) {
        $ro = $Table.Entries['requires_openai_auth']
        if ($Table.Entries.ContainsKey('requires_openai_auth') -and $ro.Supported -and $ro.Kind -eq 'boolean' -and $ro.Value -ceq 'true') { $openaiAuth = $true }
    }
    if ($openaiAuth) {
        if ($LoginCache -and $LoginCache.ContainsKey('login')) { return $LoginCache['login'] }
        $r = Get-CodexLoginStatus -Launcher $Launcher -TimeoutSec $TimeoutSec
        if ($LoginCache) { $LoginCache['login'] = $r }
        return $r
    }
    if (-not $Table) { return (New-CredentialResult 'unknown' "no [model_providers.$Name] table") }
    $ek = Get-TomlString -Table $Table -Key 'env_key'
    $bt = Get-TomlString -Table $Table -Key 'experimental_bearer_token'
    $envName = ''
    if ($ek.Present -and -not $ek.Reason) { $envName = $ek.Value.Trim() }
    if ($envName) {
        $v = [Environment]::GetEnvironmentVariable($envName)
        if ($v -and $v.Trim()) { return (New-CredentialResult 'ok' "env $envName set") }
    }
    if ($bt.Present -and -not $bt.Reason -and $bt.Value) { return (New-CredentialResult 'ok' 'bearer token in config') }
    if ($envName) { return (New-CredentialResult 'missing' "env $envName not set") }
    if ($Anonymous) { return (New-CredentialResult 'ok' 'declared anonymous in the roster') }
    return (New-CredentialResult 'missing' 'no env_key/bearer token in the table')
}

# ----------------------------------------------------------------------------- engines
#
# The CLI that carries a consultation (0.4.0, ROADMAP R10). One row per engine; `codex` is
# the default and its path through codex-consult.ps1 is the 0.3.0 one. Every other engine is
# driven through the same adapter interface (the Adapter functions named in its row), so a
# further engine (e.g. `claude`) is one more row plus its adapter functions. EVERY turn of an
# engine - the main turn, a denial retry, a format repair - goes through them (wave 23, D1/D2):
#   Argv        the argv of a turn, from ONE turn-options object (New-EngineTurnOptions: Model,
#               Mode, Thread, PromptFile, Schema, Effort, NativeEffort, MaxSteps)
#   Stdin       the text written to the turn's stdin (agy: the prompt as one NDJSON line; muse:
#               nothing - its prompt travels in the turn's own prompt file)
#   Events      the event-stream parser -> a normalized turn record (Thread, Usage, Error, ...)
#   Outcome     the failure rules of a turn (-Events -ExitCode -StderrText -Pre -ExpectThread
#               -ExpectModel)
#   Credential  the sign-in check of the preflight (-Launcher -TimeoutSec)
#   Harness     (optional) reviewer.harness (-Launcher); else the launcher's file version
#   IdentityConfig  (optional) extra reviewer.provider_config fields (an ordered hashtable)
#   LaunchBlock (optional) the launch invariant: '' or the refusal (Get-EngineLaunchBlock;
#               -Fresh right before a launch - wave 24, F15-1)
#   Salvage     (wave 24) what a killed turn's stream holds: its agent messages and reasoning
#               text and its tool calls (-Path; Read-TurnSalvage, the .partial.md)
#   ChildEnv    (optional, wave 29) the child's ALLOW-listed environment (-Auth -Endpoint;
#               claude: Get-ClaudeChildEnvironment) - Start-EngineProcess hides every other
#               variable in the transaction of Hide-HostMarkers, and (wave 29b) refuses the start
#               when its Problem is set
#   LocalCheck  (optional, wave 29) a local part of the sign-in no ledger evidence replaces
#               (-Auth [-Endpoint]; '' or why not - claude auth api-key: ANTHROPIC_API_KEY set
#               now; wave 29b, auth endpoint: the variable endpoint.env_key names set now)
# The Outcome also receives -Turn (wave 29): the turn's options object (mode, threads, the
# minted id, the pinned model, the auth) - agy and muse ignore it.
# Row fields: Name, Label (handoff header / author), Prefix (handoff file names
# NN-<prefix>-<slug>.*), Command (first word of the ledger `command`), ExeEnv (launcher
# override), LauncherNames (PATH lookup, in order), InstallLaunchers (the vendor's install
# locations, tried after PATH: { Env; Rel }), Modes, DefaultMode ('' = automatic: fork when a
# parent exists), Sandboxes, Transports (-SchemaTransport values), HostName (caps-v1 key),
# CompatString (the provider fingerprint's input), DefaultProvider (the lineage label without
# -Provider), ModelExample, DenialRetry (the engine can take a denial-retry turn),
# PromptTransport (stdin | file), LocalSignIn (the sign-in check reads local files only: it
# runs under -NoNetwork too), StepsFlag (the model-step cap flag -MaxModelSteps sends; '' = the
# engine has none: -MaxModelSteps is refused), HasUsage (its stream reports token usage), and
# the engine's own wording (D11): PromptVia, ReplySource,
# SchemaFlag, ThreadFlag, ThreadNoun, ReadOnlyNote (the -Sandbox refusal), SandboxRecord (the
# ledger's `sandbox`), TreeNote (the tree check's closing words), ToolsLine (the prompt's tools
# line).
#
#   agy   Google's Antigravity CLI: `agy -p= --input-format stream-json --output-format
#         stream-json --model <m> [--json-schema <schema>] --print-timeout 0 --sandbox
#         --disable-slash-commands [--conversation <thread>] [--effort <v>]`, the prompt as
#         ONE NDJSON line on stdin, the reply = the LAST (and only) `result` event's
#         structured_output (never its `response` text when structured_output is there).
#         Read-only is NOT enforced by agy (--sandbox restricts the terminal only): the
#         bridge's tree check fails a run that changed the working tree (tracked or
#         untracked files) or the collab directory; gitignored paths, submodules and files
#         outside the repository stay unmonitored.
#
#   muse  Meta's Muse Code CLI (wave 23): `muse exec --json --prompt-file <P> [--output-schema
#         <S>] --model <m> [--reasoning-effort <e>] --no-foreign-personal-context
#         --disable-web-tools --disable-write --disable-shell --approval-mode never
#         [--max-model-steps <n>] [--session-id <thread>]`, run in the repository root with an
#         EMPTY stdin: the prompt is the turn's own prompt file. The stream is MSP JSONL
#         (schema_version 1 only); the reply = the text of the ONE run_terminal record
#         (run.terminal.completed); the thread = the ONE session stream id. The subscription
#         bills through the browser sign-in only: an API key in the environment refuses the run,
#         and so does a sign-in not established as oauth (Get-MuseLaunchBlock, D4, wave 23b).
#         No denial retry (its write, shell and web tools are off);
#         the same tree check as agy (reads - read_file is not confined to the repository -,
#         gitignored paths, submodules and files outside the repository stay unmonitored).
#
#   claude  Claude Code headless (wave 29, ROADMAP R10 with R22): `claude -p --output-format
#         stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools
#         Read,Grep,Glob --permission-mode dontAsk --model <m> [--effort <e>] [--json-schema
#         <schema text>] [--max-turns <n>] [--add-dir <dir>...] (--session-id <minted uuid> |
#         --resume <thread> [--fork-session])` in the repository root, the prompt on stdin as plain
#         UTF-8. The reply = the ONE `result` event's structured_output (else its result text); the
#         thread = the session id the bridge minted (new), resumed (resume and every secondary turn)
#         or the fork's new one. Every turn's init event must PROVE the read-only capability (only
#         Read, Grep, Glob and StructuredOutput, no MCP server, permission mode dontAsk) and the
#         credential (apiKeySource none for the subscription, ANTHROPIC_API_KEY for auth api-key) -
#         else the turn fails; a thread is one resolved model (D4). The child gets an ALLOW-listed
#         environment (Get-ClaudeChildEnvironment, D2) - the preflight (`claude auth status`) and
#         the version probe too (D3). Managed settings and their hooks still apply under
#         --restricted, so the tree check is the strict one (D1): a change fails the run, as for
#         agy. Parallel limit 1 in a panel (D5: its members run one after another unless the
#         roster's "parallel" raises their label). Reply prefix claudecode: the coordinator's
#         default brief prefix is claude.
#         (wave 29b, E1-E7) auth endpoint: the same CLI against a third-party Anthropic-compatible
#         endpoint named by the roster entry (`endpoint` {base_url, env_key, timeout_ms}) - the child
#         gets ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN (from the variable env_key names) and
#         API_TIMEOUT_MS, never ANTHROPIC_API_KEY or a model alias variable; the model is the
#         provider's id sent straight (no table) and proven by equality with the init event's;
#         the preflight is local (no `claude auth status`); the identity is the ROUTE
#         ('cc-engine-v1|claude|endpoint|<canonical base_url>|<env_key>'), the quota the entry's
#         `plan` (Get-PlanQuotaVerdict, the panel's plan group); telemetry and the lab by host.
$script:EngineNames = @('codex', 'agy', 'muse', 'claude')
$script:Engines = @{
    'codex' = [pscustomobject]@{
        Name = 'codex'; Label = 'Codex'; Prefix = 'codex'; Command = 'codex'; ExeEnv = 'CODEX_CONSULT_EXE'
        LauncherNames = $(if ($script:OnWindows) { @('codex.exe', 'codex.cmd', 'codex.bat', 'codex') } else { @('codex') })
        InstallLaunchers = @()
        Modes = @('new', 'resume', 'fork'); DefaultMode = ''; Sandboxes = @('read-only', 'workspace-write')
        Transports = @('output-schema', 'prompt-only'); HostName = ''; CompatString = ''; DefaultProvider = ''; ModelExample = 'gpt-5.1'
        DenialRetry = $false; PromptTransport = 'stdin'; LocalSignIn = $false; StepsFlag = ''; HasUsage = $true
        PromptVia = 'prompt on stdin'; ReplySource = ''; SchemaFlag = '--output-schema'; ThreadFlag = ''; ThreadNoun = 'thread'
        ReadOnlyNote = ''; SandboxRecord = ''; TreeNote = ''; ToolsLine = ''; WriteDisabled = $false
        Adapter = $null
    }
    'agy'   = [pscustomobject]@{
        Name = 'agy'; Label = 'Gemini (agy)'; Prefix = 'agy'; Command = 'agy'; ExeEnv = 'CODEX_CONSULT_AGY_EXE'
        LauncherNames = $(if ($script:OnWindows) { @('agy.exe', 'agy.cmd', 'agy.bat', 'agy') } else { @('agy') })
        InstallLaunchers = @()
        Modes = @('new', 'resume'); DefaultMode = 'new'; Sandboxes = @('read-only')
        Transports = @('native', 'prompt-only'); HostName = 'engine:agy'; CompatString = 'cc-engine-v1|agy'; DefaultProvider = 'gemini'; ModelExample = 'gemini-3.8-flash-high'
        DenialRetry = $true; PromptTransport = 'stdin'; LocalSignIn = $false; StepsFlag = ''; HasUsage = $true
        PromptVia = 'prompt on stdin as one NDJSON line'
        ReplySource = "the result event's structured_output (else its response text)"
        SchemaFlag = '--json-schema'; ThreadFlag = '--conversation'; ThreadNoun = 'conversation'
        ReadOnlyNote = "its --sandbox restricts the terminal only; the bridge's tree check fails a run that writes"
        SandboxRecord = 'read-only (requested; enforced by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; agy --sandbox restricts the terminal only)'
        TreeNote = "agy's sandbox does not block writes"
        # (wave 26b, D9) agy's writes are not disabled (F12): its tree check FAILS a run
        WriteDisabled = $false
        # agy's print mode auto-denies a tool it cannot grant and then ends the turn with no
        # output (F11), and its --sandbox does not block file writes (F12): say both up front.
        ToolsLine = 'Tools: you may read files of the repository; you have NO permission to run commands in this consultation - never call run_command; make NO file changes; a check that needs a command belongs under `## Requested checks`.'
        Adapter = [pscustomobject]@{ Argv = 'New-AgyArgv'; Stdin = 'ConvertTo-AgyStdin'; Events = 'Read-AgyEvents'; Outcome = 'Get-AgyTurnOutcome'; Credential = 'Get-AgyModelsStatus'; Harness = ''; IdentityConfig = ''; LaunchBlock = ''; Salvage = 'Read-AgySalvage' }
    }
    'muse'  = [pscustomobject]@{
        Name = 'muse'; Label = 'Meta Muse (muse)'; Prefix = 'muse'; Command = 'muse'; ExeEnv = 'CODEX_CONSULT_MUSE_EXE'
        LauncherNames = $(if ($script:OnWindows) { @('muse.cmd', 'muse.exe', 'muse') } else { @('muse') })
        # The vendor installs muse.cmd into %LOCALAPPDATA%\Programs\muse and adds that directory to
        # the USER Path - which a bridge started before the install does not see (D3).
        InstallLaunchers = $(if ($script:OnWindows) { @([pscustomobject]@{ Env = 'LOCALAPPDATA'; Rel = 'Programs\muse\muse.cmd' }) } else { @() })
        Modes = @('new', 'resume'); DefaultMode = 'new'; Sandboxes = @('read-only')
        Transports = @('native', 'prompt-only'); HostName = 'engine:muse'; CompatString = 'cc-engine-v1|muse'; DefaultProvider = 'meta'; ModelExample = 'muse-spark-1.3'
        DenialRetry = $false; PromptTransport = 'file'; LocalSignIn = $true; StepsFlag = '--max-model-steps'; HasUsage = $false
        PromptVia = 'prompt from a file: --prompt-file'
        ReplySource = "the run_terminal record's text (run.terminal.completed)"
        SchemaFlag = '--output-schema'; ThreadFlag = '--session-id'; ThreadNoun = 'session'
        ReadOnlyNote = "muse runs with --disable-write --disable-shell --disable-web-tools and the bridge's tree check fails a run that changed anything"
        SandboxRecord = 'read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads)'
        TreeNote = 'muse ran with --disable-write --disable-shell (the check cannot tell who changed it)'
        # (wave 26b, D9) the bridge's own flags disable muse's writes: a change found by the tree
        # check is a warning (tree_check.outcome warned), never the reviewer's failure
        WriteDisabled = $true
        ToolsLine = 'Tools: you may read files of the repository (read_file); writing files, the shell and the web tools are disabled in this consultation (--disable-write --disable-shell --disable-web-tools) - do not try them; make NO file changes; a check that needs a command belongs under `## Requested checks`.'
        Adapter = [pscustomobject]@{ Argv = 'New-MuseArgv'; Stdin = 'ConvertTo-MuseStdin'; Events = 'Read-MuseEvents'; Outcome = 'Get-MuseTurnOutcome'; Credential = 'Get-MuseSignIn'; Harness = 'Get-MuseHarness'; IdentityConfig = 'Get-MuseIdentityConfig'; LaunchBlock = 'Get-MuseLaunchBlock'; Salvage = 'Read-MuseSalvage' }
    }
    # (wave 29) Claude Code headless. Row fields of its own: AuthModes (the roster's `auth` it takes;
    # the first is the default; wave 29b: endpoint - a third-party Anthropic-compatible endpoint),
    # LocalAuthModes (wave 29b: the auth modes whose credential check is local - no ledger
    # short-circuit, -NoNetwork too), MintsThread (a new thread's id is minted by the bridge: --session-id),
    # MaxPromptBytes (D9), ArgQuote (crt: ConvertTo-CrtArg - the schema TEXT travels in argv),
    # ParallelScope (engine: its panel members share one scheduling group, D5), AddDirs (the
    # directories outside the repository the reviewer must read go to --add-dir).
    'claude' = [pscustomobject]@{
        Name = 'claude'; Label = 'Claude (claude)'; Prefix = 'claudecode'; Command = 'claude'; ExeEnv = 'CODEX_CONSULT_CLAUDE_EXE'
        LauncherNames = $(if ($script:OnWindows) { @('claude.exe', 'claude.cmd', 'claude') } else { @('claude') })
        # the native installer puts claude.exe into %USERPROFILE%\.local\bin (obs) - a bridge started
        # before the install may not see it on PATH
        InstallLaunchers = $(if ($script:OnWindows) { @([pscustomobject]@{ Env = 'USERPROFILE'; Rel = '.local\bin\claude.exe' }) } else { @([pscustomobject]@{ Env = 'HOME'; Rel = '.local/bin/claude' }) })
        Modes = @('new', 'resume', 'fork'); DefaultMode = 'new'; Sandboxes = @('read-only')
        Transports = @('native', 'prompt-only'); HostName = 'engine:claude'; CompatString = 'cc-engine-v1|claude'; DefaultProvider = 'anthropic'; ModelExample = 'claude-sonnet-5-5'
        DenialRetry = $true; PromptTransport = 'stdin'; LocalSignIn = $false; StepsFlag = '--max-turns'; HasUsage = $true
        AuthModes = @('subscription', 'api-key', 'endpoint'); LocalAuthModes = @('endpoint'); MintsThread = $true; MaxPromptBytes = 1048576; ArgQuote = 'crt'; ParallelScope = 'engine'; AddDirs = $true
        PromptVia = 'prompt on stdin'
        ReplySource = "the result event's structured_output (else its result text)"
        SchemaFlag = '--json-schema'; ThreadFlag = '--resume'; ThreadNoun = 'session'
        ReadOnlyNote = "claude runs with --restricted and the read tools only (Read, Grep, Glob), each turn's init event must prove it, and the bridge's tree check fails a run that changed anything"
        SandboxRecord = 'read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn''s init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply)'
        TreeNote = 'claude ran with --restricted and read tools only, but managed settings and their hooks still apply'
        # (D1 / F02-1, F03-1) the init event proves the tools, not the absence of a managed hook: the
        # tree check FAILS a run that changed the tree, as for agy
        WriteDisabled = $false
        ToolsLine = 'Tools: you may read files of the repository (Read, Grep, Glob); no shell, web or write tool exists in this consultation; make NO file changes; a check that needs a command belongs under `## Requested checks`.'
        Adapter = [pscustomobject]@{ Argv = 'Get-ClaudeArgs'; Stdin = 'ConvertTo-ClaudeStdin'; Events = 'Read-ClaudeEvents'; Outcome = 'Get-ClaudeTurnOutcome'; Credential = 'Get-ClaudeSignIn'; Harness = 'Get-ClaudeHarness'; IdentityConfig = 'Get-ClaudeIdentityConfig'; LaunchBlock = ''; Salvage = 'Read-ClaudeSalvage'; ChildEnv = 'Get-ClaudeChildEnvironment'; LocalCheck = 'Test-ClaudeLocalCredential' }
    }
}

# The row of an engine, or $null.
function Get-EngineSpec {
    param([string]$Name)
    if ($Name -and $script:Engines.ContainsKey($Name)) { return $script:Engines[$Name] }
    return $null
}

# The launcher of an engine: $Explicit (codex: -CodexExe; others: -EngineExe), then the
# engine's ExeEnv variable, then its LauncherNames on PATH, then (wave 23, D3) its vendor
# install locations (InstallLaunchers: muse - %LOCALAPPDATA%\Programs\muse\muse.cmd on
# Windows). An explicit launcher that does not resolve is an error (never a silent
# fall-through to PATH); $null when none is found.
function Resolve-EngineLauncher {
    param([string]$Engine, [string]$Explicit = '')
    if (-not $Engine -or $Engine -eq 'codex') { return (Resolve-CodexLauncher -Explicit $Explicit) }
    $spec = Get-EngineSpec -Name $Engine
    if (-not $spec) { return $null }
    $sources = @(@{ value = $Explicit; label = '-EngineExe' }, @{ value = [Environment]::GetEnvironmentVariable($spec.ExeEnv); label = $spec.ExeEnv })
    foreach ($source in $sources) {
        $candidate = [string]$source.value
        if ($candidate) {
            if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
            $cmd = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
            if ($cmd) { return @($cmd)[0].Source }
            Stop-WithError "$($source.label) '$candidate' is not a file and not an application on PATH."
        }
    }
    foreach ($name in @($spec.LauncherNames)) {
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
        if ($cmd) { return @($cmd)[0].Source }
    }
    foreach ($il in @($spec.InstallLaunchers)) {
        if ($null -eq $il) { continue }
        $base = [string][Environment]::GetEnvironmentVariable([string]$il.Env)
        if (-not $base.Trim()) { continue }
        $candidate = Join-Path $base ([string]$il.Rel)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    return $null
}

# The engine -EngineExe names (wave 23, D3): the SELECTED engine other than codex - -Engine's
# when given (codex is refused: it takes -CodexExe); else the one the run can select: the
# roster entry of -Provider (codex-providers: of the -Provider row), else the only engine other
# than codex among the roster's entries. None or several -> refused ("pass -Engine <name>").
# { Engine; Error }.
function Resolve-EngineExeBinding {
    param([string]$Engine = '', $Roster = $null, [string]$Provider = '', [string]$Model = '')
    $r = [pscustomobject]@{ Engine = ''; Error = '' }
    $others = @($script:EngineNames | Where-Object { $_ -ne 'codex' })
    if ($Engine) {
        if ($Engine -eq 'codex') { $r.Error = "-EngineExe names the launcher of an engine other than codex ($($others -join ', ')); codex takes -CodexExe"; return $r }
        $r.Engine = $Engine
        return $r
    }
    if ($Provider) {
        $pe = Find-RosterEntry -Roster $Roster -Provider $Provider -Model $Model
        if ($pe -and $pe.Engine -ne 'codex') { $r.Engine = [string]$pe.Engine; return $r }
        if ($pe) { $r.Error = "-EngineExe: the roster entry $($pe.Position) for -Provider $Provider is engine codex, which takes -CodexExe"; return $r }
    }
    $used = New-Object System.Collections.Generic.List[string]
    if ($Roster -and $Roster.Exists) {
        foreach ($e in @($Roster.Entries)) { $en = [string]$e.Engine; if ($en -and $en -ne 'codex' -and -not $used.Contains($en)) { $used.Add($en) } }
    }
    if ($used.Count -eq 1) { $r.Engine = $used[0]; return $r }
    if ($used.Count -gt 1) { $r.Error = "-EngineExe is ambiguous: the reviewer roster has entries of the engines $($used.ToArray() -join ' and '); pass -Engine <$($others -join '|')> to name the one it launches" }
    else { $r.Error = "-EngineExe names the launcher of an engine other than codex: pass -Engine <$($others -join '|')> with it" }
    return $r
}

# The launcher of $Engine for a walk over the roster: codex -> $CodexLauncher; any other engine
# is resolved once per $Launchers table (engine -> path, '' = not found).
function Get-EngineLauncher {
    param([string]$Engine, [hashtable]$Launchers = $null, [string]$CodexLauncher = '')
    if (-not $Engine -or $Engine -eq 'codex') { return $CodexLauncher }
    if ($null -ne $Launchers -and $Launchers.ContainsKey($Engine)) { return [string]$Launchers[$Engine] }
    $p = [string](Resolve-EngineLauncher -Engine $Engine)
    if ($null -ne $Launchers) { $Launchers[$Engine] = $p }
    return $p
}

# The harness string of an engine run (reviewer.harness): agy has no --version flag (the CLI
# rejects unknown flags), so the version comes from the launcher's file metadata when it
# carries one: "agy-cli <version>" or "agy-cli (version unknown)". Nothing is started.
function Get-EngineHarness {
    param([string]$Engine, [string]$Launcher)
    # (wave 23, D8) an engine that names its own version source (muse: Get-MuseHarness)
    $spec = Get-EngineSpec -Name $Engine
    if ($spec -and $spec.Adapter -and $spec.Adapter.PSObject.Properties['Harness'] -and $spec.Adapter.Harness) { return [string](& $spec.Adapter.Harness -Launcher $Launcher) }
    $ver = ''
    if ($Launcher) {
        try { $ver = [string](Get-Item -LiteralPath $Launcher -ErrorAction Stop).VersionInfo.ProductVersion } catch { $ver = '' }
    }
    if ($ver -and $ver.Trim()) { return "$Engine-cli $($ver.Trim())" }
    return "$Engine-cli (version unknown)"
}

# `agy models` with a timeout (a network round-trip, usually ~2 s but observed at 1.7-15+ s,
# hence 45 s): exit 0 and at least one "<id><TAB><name>" line -> ok "signed in (N models)";
# output mentioning login / sign in / auth / unauthenticated -> missing; anything else (and a
# timeout) -> unknown. stdout and stderr are read as UTF-8. { State; Reason; Detail } like
# Get-CodexLoginStatus.
$script:AgyModelsTimeoutSec = 45
function Get-AgyModelsStatus {
    param([string]$Launcher, [int]$TimeoutSec = 45)
    if (-not $Launcher) { return (New-CredentialResult 'missing' 'agy CLI not found on PATH') }
    $p = $null
    try {
        # (wave 27c, D4) through Start-ProbeProcess: never started with the host markers
        $start = Start-ProbeProcess -Make { New-ProbeStartInfo -Launcher $Launcher -Arguments 'models' }
        if ($start.Skipped) { return (New-CredentialResult 'unknown' "not checked - ``agy models`` was skipped: $($start.Skipped)") }
        $p = $start.Proc
    } catch {
        return (New-CredentialResult 'unknown' "``agy models`` could not be started ($(ConvertTo-OneLine $_.Exception.Message))")
    }
    try {
        try { $p.StandardInput.Close() } catch { }
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $null = Stop-ProcessTree -Process $p
            return (New-CredentialResult 'unknown' "``agy models`` did not finish within $TimeoutSec s")
        }
        $p.WaitForExit()
        $null = $outTask.Wait(5000)
        $null = $errTask.Wait(5000)
        $outLines = @(([string]$outTask.Result) -split "`r?`n" | Where-Object { $_ -and $_.Trim() })
        $allLines = @((([string]$outTask.Result) + "`n" + ([string]$errTask.Result)) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $models = @($outLines | Where-Object { $_ -match '^\S+\t' })
        if ($p.ExitCode -eq 0 -and $models.Count -ge 1) { return (New-CredentialResult 'ok' "signed in ($($models.Count) models)") }
        $authLine = @($allLines | Where-Object { $_ -match '(?i)log ?in|sign in|signed in|\bauth|unauthenticated' }) | Select-Object -First 1
        if ($authLine) { return (New-CredentialResult 'missing' "``agy models``: $authLine") }
        $first = if ($allLines.Count -gt 0) { $allLines[-1] } else { 'no output' }
        return (New-CredentialResult 'unknown' "``agy models`` exit $($p.ExitCode) without a model list ($first)")
    } finally {
        $p.Dispose()
    }
}

# Sign-in of an engine for the preflight and the listing. A missing launcher is always
# missing ("agy CLI not found on PATH"). Then (wave 18, F13) the ledger short-circuit: when
# $Health (Get-EndpointHealth of the engine's endpoint, read from THIS repository's ledgers)
# holds a usable reply no older than 60 minutes (RecentUsable, consult clock), the sign-in is
# evidenced - "ok: signed in (usable reply <m> min ago)" - and nothing is started (also with
# -NoNetwork: it is a ledger read). The caller keeps the endpoint health's auth and quota rules
# in front of it (Get-PreflightVerdict): a recorded auth failure or a usage limit still
# refuses. -NoNetwork (the SessionStart hook): otherwise nothing is started - "not checked
# (launcher present; run codex-providers.ps1)", State unknown, Reason "sign-in not checked" -
# unless the engine's check reads local files only (LocalSignIn: muse's auth.json key names).
# Else the adapter's check (agy: `agy models`, 45 s - TEST HOOK
# CODEX_CONSULT_TEST_LOGIN_TIMEOUT=<s> shortens it). $LoginCache: one check per launcher per
# listing. (wave 29) $Auth: the roster's auth of an engine that takes one (claude: subscription |
# api-key) - passed to its check, and part of the cache key. (wave 29b, E3) $Endpoint: the roster
# entry's endpoint (claude auth endpoint); an auth mode of the row's LocalAuthModes (claude:
# endpoint) is checked locally by the adapter EVERY time - no ledger short-circuit, under -NoNetwork
# too ("ok: env <NAME> set").
function Get-EngineCredential {
    param([string]$Engine, [string]$Launcher, [hashtable]$LoginCache = $null, [switch]$NoNetwork, [int]$TimeoutSec = 0, $Health = $null, [string]$Auth = '', $Endpoint = $null)
    $spec = Get-EngineSpec -Name $Engine
    if (-not $spec -or -not $spec.Adapter) { return (New-CredentialResult 'unknown' "no credential check for engine '$Engine'") }
    if (-not $Launcher) { return (New-CredentialResult 'missing' "$($spec.Command) CLI not found on PATH") }
    # (wave 29) an engine's LOCAL check that no ledger evidence replaces (claude auth api-key: the key
    # must be set NOW - a usable reply an hour ago proves nothing about this process's environment)
    $authModes = @(Get-PropertyValue $spec 'AuthModes' @())
    $authUsed = $(if ($authModes.Count -gt 0) { $(if ($authModes -contains $Auth) { $Auth } else { [string]$authModes[0] }) } else { '' })
    if ($spec.Adapter.PSObject.Properties['LocalCheck'] -and $spec.Adapter.LocalCheck) {
        $localArgs = @{ Auth = $authUsed }
        if ($authUsed -eq 'endpoint') { $localArgs['Endpoint'] = $Endpoint }
        $localWhy = [string](& $spec.Adapter.LocalCheck @localArgs)
        if ($localWhy) { return (New-CredentialResult 'missing' $localWhy) }
    }
    if ($authUsed -and @(Get-PropertyValue $spec 'LocalAuthModes' @()) -contains $authUsed) {
        return (& $spec.Adapter.Credential -Launcher $Launcher -Auth $authUsed -Endpoint $Endpoint)
    }
    if ($Health -and $Health.PSObject.Properties['RecentUsable'] -and $Health.RecentUsable) {
        return (New-CredentialResult 'ok' "signed in (usable reply $($Health.RecentUsable.AgeMinutes) min ago)")
    }
    if ($NoNetwork -and -not ($spec.PSObject.Properties['LocalSignIn'] -and $spec.LocalSignIn)) { return [pscustomobject]@{ State = 'unknown'; Reason = 'sign-in not checked'; Detail = 'not checked (launcher present; run codex-providers.ps1)' } }
    if ($TimeoutSec -le 0) {
        $TimeoutSec = $script:AgyModelsTimeoutSec
        $hook = ((Get-TestHookValue 'CODEX_CONSULT_TEST_LOGIN_TIMEOUT')).Trim()
        if ($hook -match '^[0-9]+$' -and [int]$hook -gt 0) { $TimeoutSec = [int]$hook }
    }
    $credArgs = @{ Launcher = $Launcher; TimeoutSec = $TimeoutSec }
    if ($authUsed) { $credArgs['Auth'] = $authUsed }
    $key = "engine:$Engine|$Launcher$(if ($credArgs.ContainsKey('Auth')) { "|$($credArgs['Auth'])" })"
    if ($LoginCache -and $LoginCache.ContainsKey($key)) { return $LoginCache[$key] }
    $r = & $spec.Adapter.Credential @credArgs
    if ($LoginCache) { $LoginCache[$key] = $r }
    return $r
}

# ---- engine turns (every engine other than codex)

# One turn of an engine other than codex (wave 23, D1): what its adapter's Argv receives -
# { Model; Mode (new | resume | denial-retry | format-repair | timeout-continue - wave 24);
# Thread (the conversation / session
# to continue, '' = a new one); PromptFile (this turn's own prompt file: muse reads it through
# --prompt-file, agy's prompt travels on stdin); Schema (the schema path, '' = none); Effort (the
# value to send, $null = nothing); NativeEffort (-NativeEffort, verbatim); MaxSteps (muse
# --max-model-steps, claude --max-turns; 0 = not sent); (wave 29) NewThread (the id the bridge
# minted for a new thread of an engine with MintsThread - claude --session-id; '' otherwise); AddDirs
# (string[]: directories outside the repository the reviewer must read - claude --add-dir); Auth
# (the roster's auth of an engine that takes one - the claude turn's credential check) }. The same
# object reaches the adapter's Outcome as -Turn (wave 29): the mode, the threads, the pinned model.
function New-EngineTurnOptions {
    param([string]$Model, [string]$Mode = 'new', [string]$Thread = '', [string]$PromptFile = '', [string]$Schema = '', $Effort = $null, [string]$NativeEffort = '', [int]$MaxSteps = 0, [string]$NewThread = '', [string[]]$AddDirs = @(), [string]$Auth = '')
    return [pscustomobject]@{ Model = $Model; Mode = $Mode; Thread = $Thread; PromptFile = $PromptFile; Schema = $Schema; Effort = $Effort; NativeEffort = $NativeEffort; MaxSteps = $MaxSteps; NewThread = $NewThread; AddDirs = [string[]]@($AddDirs | Where-Object { $_ }); Auth = $Auth }
}

# The launch invariant of an engine (wave 23, D4): '' or the refusal. Checked when a roster
# entry is selected (the walk and the panel skip it, under -SkipPreflight too), when the run's
# engine is known (a refusal; -SkipPreflight never bypasses it) and again right before every
# Start-Process of a turn - there with -Fresh (wave 24, F15-1: what the invariant reads is read
# again, never taken from a cache filled minutes earlier). muse: Get-MuseLaunchBlock (billing);
# other engines: none.
function Get-EngineLaunchBlock {
    param([string]$Engine, [switch]$Fresh)
    $spec = Get-EngineSpec -Name $Engine
    if (-not $spec -or -not $spec.Adapter -or -not $spec.Adapter.PSObject.Properties['LaunchBlock'] -or -not $spec.Adapter.LaunchBlock) { return '' }
    return [string](& $spec.Adapter.LaunchBlock -Fresh:$Fresh)
}

# cmd.exe expands %VAR% even inside double quotes when it runs a .cmd / .bat launcher (the
# reason the codex prompt goes on stdin; F02-14): an engine argument that contains '%' would
# reach the CLI changed. '' or the refusal (the first two such arguments named).
function Get-CmdArgvHazard {
    param([string]$Launcher, [string[]]$Argv)
    if (-not $Launcher -or [IO.Path]::GetExtension($Launcher) -notmatch '^\.(cmd|bat)$') { return '' }
    $bad = @(@($Argv) | Where-Object { $_ -and $_.Contains('%') })
    if ($bad.Count -eq 0) { return '' }
    return "the launcher $Launcher is a cmd.exe script and $($bad.Count) argument(s) contain '%' ($(@($bad | Select-Object -First 2) -join ', ')): cmd.exe would expand %VAR% in them; set TEMP and TMP to a directory without '%', or point -EngineExe at the CLI's .exe"
}

# A launcher's output (stdout and stderr as UTF-8) with a timeout, nothing on stdin: { Started;
# Exit (-1 when it did not exit); TimedOut; Out; Err }.
function Invoke-LauncherCapture {
    param([string]$Launcher, [string]$Arguments, [int]$TimeoutSec = 15)
    $r = [pscustomobject]@{ Started = $false; Exit = -1; TimedOut = $false; Out = ''; Err = '' }
    $p = $null
    try {
        # (wave 27c, D4) through Start-ProbeProcess: never started with the host markers (skipped: not
        # started, the caller sees Started $false)
        $start = Start-ProbeProcess -Make { New-ProbeStartInfo -Launcher $Launcher -Arguments $Arguments }
        if ($start.Skipped) { return $r }
        $p = $start.Proc
    } catch { return $r }
    $r.Started = $true
    try {
        try { $p.StandardInput.Close() } catch { }
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $null = Stop-ProcessTree -Process $p
            $r.TimedOut = $true
            return $r
        }
        $p.WaitForExit()
        $null = $outTask.Wait(5000)
        $null = $errTask.Wait(5000)
        $r.Exit = $p.ExitCode
        $r.Out = [string]$outTask.Result
        $r.Err = [string]$errTask.Result
        return $r
    } finally {
        $p.Dispose()
    }
}

# ---- agy adapter

# The argv of one agy turn (after the launcher), from the turn options (New-EngineTurnOptions).
# Schema: --json-schema (structured mode with transport native, and every repair / denial-retry
# turn); Thread: --conversation (resume, repair, denial retry); NativeEffort: --effort <v>
# verbatim (never otherwise: the tier is part of the model id). PromptFile is not used: the
# prompt travels on stdin (ConvertTo-AgyStdin).
function New-AgyArgv {
    param($Turn)
    $a = @('-p=', '--input-format', 'stream-json', '--output-format', 'stream-json', '--model', [string]$Turn.Model)
    if ($Turn.Schema) { $a += @('--json-schema', [string]$Turn.Schema) }
    $a += @('--print-timeout', '0', '--sandbox', '--disable-slash-commands')
    if ($Turn.Thread) { $a += @('--conversation', [string]$Turn.Thread) }
    if ($Turn.NativeEffort) { $a += @('--effort', [string]$Turn.NativeEffort) }
    return , ([string[]]$a)
}

# The stdin of one agy turn: ONE NDJSON line {"event":"user","message":{"content":"<prompt>"}}
# plus one LF, serialized by ConvertTo-Json -Compress on both hosts (Windows PowerShell 5.1
# escapes some characters as \uXXXX - the same JSON string), written UTF-8 without BOM by the
# caller.
function ConvertTo-AgyStdin {
    param([string]$Prompt)
    $o = [pscustomobject]@{ event = 'user'; message = [pscustomobject]@{ content = $Prompt } }
    return ((ConvertTo-Json -InputObject $o -Compress -Depth 5) + "`n")
}

$script:UuidRe = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

# One agy event stream (stdout of --output-format stream-json), parsed tolerantly into the
# normalized turn record the run block uses:
#   InitThread       init.conversation_id ('' when none)
#   ResultCount      number of `result` events (exactly one is a well-formed stream)
#   Malformed        '' or why the stream is malformed: a line that does not parse, more
#                    than one result, a result that is not an object. The LAST non-empty
#                    line may be a partial line only with -AllowPartialLast - the caller
#                    passes it when the process was killed (timeout) or exited non-zero
#                    (wave 18, F10-2); on exit 0 trailing garbage makes the stream malformed
#   HasResult        a result event was seen
#   Thread           result.conversation_id ('' when absent)
#   Status, Response, Error      result.status / .response / .error (strings)
#   HasStructured    result.structured_output is a JSON object
#   StructuredJson   that object serialized compactly (ConvertTo-Json -Compress -Depth 30)
#   Usage            { input_tokens, cached_input_tokens (cache_read_tokens), output_tokens,
#                    reasoning_output_tokens (thinking_tokens), total_tokens } or $null
#   ToolName         tool_name of the LAST step_update with step_type "tool" ('' when none)
#   DeniedAction     result.denied_actions[].display_name / .action (first; '' when none)
function Read-AgyEvents {
    param([string]$Path, [switch]$AllowPartialLast)
    $r = [pscustomobject]@{ InitThread = ''; ResultCount = 0; Malformed = ''; HasResult = $false; Thread = ''; Status = ''; Response = ''; Error = ''; HasStructured = $false; StructuredJson = ''; Usage = $null; ToolName = ''; DeniedAction = '' }
    $text = Read-SharedText -Path $Path
    if (-not $text) { return $r }
    $lines = @($text -split "`r?`n")
    $lastIdx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i].Trim()) { $lastIdx = $i; break } }
    $result = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if (-not $t) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $t } catch { $obj = $null }
        if ($null -eq $obj -or -not ($obj -is [System.Management.Automation.PSCustomObject])) {
            if (($i -ne $lastIdx -or -not $AllowPartialLast) -and -not $r.Malformed) { $r.Malformed = "line $($i + 1) is not a JSON object" }
            continue
        }
        $ev = [string](Get-PropertyValue $obj 'event' '')
        if ($ev -eq 'init') {
            if (-not $r.InitThread) { $r.InitThread = [string](Get-PropertyValue $obj 'conversation_id' '') }
        } elseif ($ev -eq 'step_update') {
            $su = Get-PropertyValue $obj 'step_update' $null
            if ($su -and [string](Get-PropertyValue $su 'step_type' '') -eq 'tool') {
                $tn = [string](Get-PropertyValue $su 'tool_name' '')
                if ($tn) { $r.ToolName = $tn }
            }
        } elseif ($ev -eq 'result') {
            $r.ResultCount++
            $res = Get-PropertyValue $obj 'result' $null
            if ($null -eq $res -or -not ($res -is [System.Management.Automation.PSCustomObject])) {
                if (-not $r.Malformed) { $r.Malformed = "result event at line $($i + 1) is not an object" }
                continue
            }
            $result = $res
        }
    }
    if ($r.ResultCount -gt 1 -and -not $r.Malformed) { $r.Malformed = "$($r.ResultCount) result events (exactly one expected)" }
    if ($null -ne $result) {
        $r.HasResult = $true
        $r.Thread = [string](Get-PropertyValue $result 'conversation_id' '')
        $r.Status = [string](Get-PropertyValue $result 'status' '')
        $r.Response = [string](Get-PropertyValue $result 'response' '')
        $err = Get-PropertyValue $result 'error' ''
        if ($err -is [string]) { $r.Error = $err } else { $r.Error = (ConvertTo-Json -InputObject $err -Compress -Depth 10) }
        $so = Get-PropertyValue $result 'structured_output' $null
        if ($null -ne $so -and $so -is [System.Management.Automation.PSCustomObject]) {
            $r.HasStructured = $true
            $r.StructuredJson = ConvertTo-Json -InputObject $so -Compress -Depth 30
        }
        $u = Get-PropertyValue $result 'usage' $null
        if ($null -ne $u) {
            $map = [ordered]@{ input_tokens = 'input_tokens'; cached_input_tokens = 'cache_read_tokens'; output_tokens = 'output_tokens'; reasoning_output_tokens = 'thinking_tokens'; total_tokens = 'total_tokens' }
            $values = [ordered]@{}
            foreach ($k in $map.Keys) {
                $values[$k] = $null
                $v = Get-PropertyValue $u $map[$k] $null
                $n = [long]0
                if ($null -ne $v -and [long]::TryParse([string]$v, [ref]$n)) { $values[$k] = $n }
            }
            $r.Usage = [pscustomobject]$values
        }
        foreach ($da in @(Get-PropertyValue $result 'denied_actions' @())) {
            if ($null -eq $da) { continue }
            $name = [string](Get-PropertyValue $da 'display_name' '')
            if (-not $name) { $name = [string](Get-PropertyValue $da 'action' '') }
            if ($name) { $r.DeniedAction = $name; break }
        }
    }
    return $r
}

# The failure rules of one agy turn (the main turn, a denial retry, a format repair):
# { Ok; Outcome ('usable reply' | 'failed: ...'); Class ('' = classify the texts, else the
# forced provider_failure class); Texts (the failure evidence, best first); Thread (a verified
# conversation id, '' otherwise); ThreadCandidate (an id that is never a parent); Reply (the
# reply text: structured_output serialized, else the response); Structured; DeniedEmpty (the
# F11 case: a denial notice and nothing to use); DenialLine; Permission (the permission the
# notice names, e.g. command); NotFound (the resume warning line); Warnings (string[]) }.
#   $Pre             a failure the bridge already knows (timeout, could not start, not
#                    registered) - it wins
#   exit != 0        failed: agy exit <n> - <result.error | stderr>
#   malformed        failed: malformed event stream: <why> (class transport)
#   no result        failed: no result event in the agy event stream (init id -> candidate)
#   init != result   failed: conversation id mismatch (class unknown)
#   status           failed: agy status <S> - <error>
#   $ExpectThread    (resume, repair, denial retry) the not-found warning, a result without
#                    conversation_id, or another id -> failed (class unknown); the new id is
#                    a candidate only
#   not a uuid       failed (class unknown)
#   partial          stderr "returning partial output" / "print timeout" -> failed
#   empty reply      with a denial notice: failed: <notice> (class permission, DeniedEmpty);
#                    otherwise failed: empty reply
#   usable           a denial notice and every `warning:` line of stderr become Warnings
function Get-AgyTurnOutcome {
    # (-ExpectModel: the adapter contract; agy's result names no served model - not checked; -Turn
    # (wave 29): the adapter contract - the turn's options, not needed by agy's rules)
    param($Events, [int]$ExitCode, [string]$StderrText = '', [string]$Pre = '', [string]$ExpectThread = '', [string]$ExpectModel = '', $Turn = $null)
    $o = [pscustomobject]@{ Ok = $false; Outcome = ''; Class = ''; Texts = [string[]]@(); Thread = ''; ThreadCandidate = ''; Reply = ''; Structured = $false; DeniedEmpty = $false; DenialLine = ''; Permission = ''; NotFound = ''; Warnings = [string[]]@() }
    $lines = @(([string]$StderrText) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $denial = @($lines | Where-Object { $_ -match '(?i)no output produced|auto-denied' }) | Select-Object -First 1
    $notFound = @($lines | Where-Object { $_ -match '(?i)^warning:\s*conversation\s.*not found' }) | Select-Object -First 1
    $partial = @($lines | Where-Object { $_ -match '(?i)returning partial output|print timeout' }) | Select-Object -First 1
    $warnLines = @($lines | Where-Object { $_ -match '(?i)^warning:' })
    $stderrTail = if ($lines.Count -gt 0) { $lines[-1] } else { '' }
    if ($denial) {
        $o.DenialLine = [string]$denial
        if ($denial -match 'the "(?<perm>[^"]+)" permission') { $o.Permission = $Matches['perm'] }
    }
    if ($notFound) { $o.NotFound = [string]$notFound }
    $o.Reply = if ($Events.HasStructured) { [string]$Events.StructuredJson } else { [string]$Events.Response }
    $o.Structured = [bool]$Events.HasStructured
    $resId = [string]$Events.Thread
    $initId = [string]$Events.InitThread
    $fail = {
        param([string]$Why, [string]$Class = '', [string[]]$Texts = @())
        $o.Ok = $false
        $o.Outcome = "failed: $Why"
        $o.Class = $Class
        $o.Texts = [string[]]@(@($Texts) + @($Why) | Where-Object { $_ })
    }
    $bestErr = [string]$Events.Error
    $detail = if ($bestErr) { $bestErr } elseif ($denial) { [string]$denial } else { $stderrTail }
    if ($Pre) {
        $o.Outcome = $Pre
        $o.Texts = [string[]]@(@($bestErr, $detail, ($Pre -replace '^failed:\s*', '')) | Where-Object { $_ })
        if ($resId -match $script:UuidRe) { $o.ThreadCandidate = $resId } elseif ($initId -match $script:UuidRe) { $o.ThreadCandidate = $initId }
        return $o
    }
    if ($ExitCode -ne 0) {
        & $fail "agy exit $ExitCode$(if ($detail) { " - $(ConvertTo-OneLine $detail)" })" '' @($bestErr, $detail)
        if ($resId -match $script:UuidRe -and (-not $ExpectThread -or $resId -eq $ExpectThread) -and -not $notFound) { $o.Thread = $resId } elseif ($resId -match $script:UuidRe) { $o.ThreadCandidate = $resId } elseif ($initId -match $script:UuidRe) { $o.ThreadCandidate = $initId }
        return $o
    }
    if ($Events.Malformed) {
        & $fail "malformed event stream: $($Events.Malformed)" 'transport'
        if ($initId -match $script:UuidRe) { $o.ThreadCandidate = $initId }
        return $o
    }
    if (-not $Events.HasResult) {
        & $fail "no result event in the agy event stream$(if ($stderrTail) { " - $(ConvertTo-OneLine $stderrTail)" })" '' @($stderrTail)
        if ($initId -match $script:UuidRe) { $o.ThreadCandidate = $initId }
        return $o
    }
    if ($initId -and $resId -and $initId -ne $resId) {
        & $fail "conversation id mismatch: init $initId, result $resId" 'unknown'
        if ($resId -match $script:UuidRe) { $o.ThreadCandidate = $resId }
        return $o
    }
    if ($ExpectThread) {
        if ($notFound) {
            & $fail "parent conversation $ExpectThread not found, agy started $(if ($resId) { $resId } else { 'another conversation' }) ($notFound)" 'unknown' @($notFound)
            if ($resId -match $script:UuidRe) { $o.ThreadCandidate = $resId }
            return $o
        }
        if (-not $resId) {
            & $fail "the result names no conversation id (resume of $ExpectThread)" 'unknown'
            return $o
        }
        if ($resId -ne $ExpectThread) {
            & $fail "parent conversation $ExpectThread not found, agy started $resId" 'unknown'
            if ($resId -match $script:UuidRe) { $o.ThreadCandidate = $resId }
            return $o
        }
    }
    if ($Events.Status -ne 'SUCCESS') {
        & $fail "agy status $(if ($Events.Status) { $Events.Status } else { '(none)' })$(if ($detail) { " - $(ConvertTo-OneLine $detail)" })" '' @($bestErr, $detail)
        if ($resId -match $script:UuidRe) { $o.Thread = $resId }
        return $o
    }
    if (-not ($resId -match $script:UuidRe)) {
        & $fail "the result's conversation_id '$resId' is not a uuid" 'unknown'
        return $o
    }
    $o.Thread = $resId
    if ($partial) {
        & $fail "partial output - $(ConvertTo-OneLine $partial)" '' @($partial)
        return $o
    }
    if (-not $Events.HasStructured -and -not ([string]$Events.Response).Trim()) {
        if ($denial) {
            & $fail (ConvertTo-OneLine $denial) 'permission' @($denial)
            $o.DeniedEmpty = $true
        } else {
            & $fail "empty reply$(if ($bestErr) { " - $(ConvertTo-OneLine $bestErr)" })" '' @($bestErr)
        }
        return $o
    }
    $o.Ok = $true
    $o.Outcome = 'usable reply'
    $w = New-Object System.Collections.Generic.List[string]
    if ($denial) { $w.Add("denial notice: $(ConvertTo-OneLine $denial)") }
    foreach ($wl in $warnLines) { $w.Add((ConvertTo-OneLine $wl)) }
    $o.Warnings = [string[]]$w.ToArray()
    return $o
}

# ---- muse adapter (wave 23: Meta's Muse Code CLI, headless `muse exec`; decisions D1-D16)

# The Muse sign-in (D5). With TBH_CREDENTIAL_BACKEND=file the CLI keeps it in
# ~/.config/muse/auth.json (home: USERPROFILE on Windows, else HOME); any other backend is the OS
# keychain, which the bridge cannot read (on Windows the keychain write fails anyway: the file
# backend is required there). The file is read for the presence of providers.meta and its
# `mechanism` value only (an enum such as oauth, never a secret); the parsed object is never
# logged, returned or written, and a parse error is reported without its text. Cached per
# backend and path for this process - for listings and the preflight; -Fresh (wave 24, F15-1)
# reads the file again (and refreshes the cache): the launch guard right before every
# Start-Process of a muse turn uses it. { Backend (file | keychain); State (ok | missing |
# unknown); Reason; Cause (wave 23b: the reason without its remedy, '' when ok - the billing
# guard names it); Mechanism ('' when not read; 'unrecognized' for a value that is not a short
# identifier - never shown) }.
$script:MuseCredentialCache = @{}
$script:MuseAuthShown = '~/.config/muse/auth.json'
function Get-MuseAuthPath {
    $h = ''
    if ($script:OnWindows) { $h = [string]$env:USERPROFILE }
    if (-not $h) { $h = [string]$env:HOME }
    if (-not $h) { $h = [string]$HOME }
    if (-not $h) { return '' }
    return (Join-Path (Join-Path (Join-Path $h '.config') 'muse') 'auth.json')
}
function Get-MuseCredentialInfo {
    param([switch]$Fresh)
    $backend = ([string]$env:TBH_CREDENTIAL_BACKEND).Trim().ToLowerInvariant()
    $path = Get-MuseAuthPath
    $key = "$backend|$path"
    if (-not $Fresh -and $script:MuseCredentialCache.ContainsKey($key)) { return $script:MuseCredentialCache[$key] }
    $info = [pscustomobject]@{ Backend = $(if ($backend -eq 'file') { 'file' } else { 'keychain' }); State = 'unknown'; Reason = ''; Cause = ''; Mechanism = '' }
    $shown = $script:MuseAuthShown
    if ($backend -ne 'file') {
        $info.Cause = "TBH_CREDENTIAL_BACKEND is $(if ($backend) { "'$backend'" } else { 'not set' }): the keychain backend cannot be read"
        $info.Reason = "sign-in not checkable: TBH_CREDENTIAL_BACKEND is $(if ($backend) { "'$backend'" } else { 'not set' }) (the keychain backend cannot be read; set TBH_CREDENTIAL_BACKEND=file - required on Windows - and run ``muse login``)"
    } elseif (-not $path) {
        $info.Cause = 'no home directory (USERPROFILE / HOME)'
        $info.Reason = 'sign-in not checkable: no home directory (USERPROFILE / HOME)'
    } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $info.State = 'missing'
        $info.Cause = "$shown does not exist"
        $info.Reason = "not signed in: $shown does not exist (run ``muse login`` with TBH_CREDENTIAL_BACKEND=file)"
    } else {
        $data = $null
        $why = ''
        $text = Read-SharedText -Path $path
        if (-not $text -or -not $text.Trim()) { $why = 'is empty or could not be read' }
        else {
            try { $data = ConvertFrom-Json -InputObject $text } catch { $why = 'does not parse as JSON' }
            if (-not $why -and -not (Test-IsJsonObject $data)) { $why = 'is not a JSON object' }
        }
        $text = $null
        if ($why) {
            $info.Cause = "$shown $why"
            $info.Reason = "sign-in not checkable: $shown $why"
        } else {
            $providers = Get-PropertyValue $data 'providers' $null
            $meta = $null
            if (Test-IsJsonObject $providers) { $meta = Get-PropertyValue $providers 'meta' $null }
            if (-not (Test-IsJsonObject $meta)) {
                $info.State = 'missing'
                $info.Cause = "$shown has no Meta sign-in (providers.meta)"
                $info.Reason = "not signed in: $shown has no Meta sign-in (providers.meta; run ``muse login``)"
            } else {
                $mech = Get-PropertyValue $meta 'mechanism' $null
                if (-not ($mech -is [string]) -or -not $mech.Trim()) {
                    $info.Cause = "providers.meta in $shown names no mechanism"
                    $info.Reason = "sign-in not checkable: providers.meta in $shown names no mechanism"
                } else {
                    $info.State = 'ok'
                    if ($mech -cmatch '^[A-Za-z][A-Za-z0-9_.-]{0,31}$') { $info.Mechanism = $mech } else { $info.Mechanism = 'unrecognized' }
                    $info.Reason = "signed in ($shown`: providers.meta, mechanism $($info.Mechanism))"
                }
            }
        }
        $data = $null
    }
    $script:MuseCredentialCache[$key] = $info
    return $info
}

# The preflight's sign-in check of a muse entry (the adapter's Credential; local, nothing is
# started): ok (providers.meta with a mechanism), missing (no file, no providers.meta), unknown
# (the keychain backend, a file that does not parse, no mechanism). Since wave 23b (F09-1)
# missing and unknown refuse the LAUNCH itself (Get-MuseLaunchBlock: no oauth sign-in is
# established) - with -SkipPreflight too, before this check is ever consulted.
function Get-MuseSignIn {
    param([string]$Launcher = '', [int]$TimeoutSec = 0)
    $c = Get-MuseCredentialInfo
    return (New-CredentialResult $c.State $c.Reason)
}

# reviewer.provider_config's muse fields (D4): credential_mechanism = providers.meta.mechanism
# (the file backend), $null when it cannot be read.
function Get-MuseIdentityConfig {
    $c = Get-MuseCredentialInfo
    $o = [ordered]@{}
    $o['credential_mechanism'] = $(if ($c.Mechanism) { $c.Mechanism } else { $null })
    return $o
}

# The billing invariant of a muse launch (D4; fail-closed since wave 23b, F09-1): the
# subscription bills through the browser sign-in only; an API key the child would inherit bills
# per token instead. '' ONLY for an established oauth sign-in (auth.json's providers.meta.
# mechanism read as oauth), else the refusal: META_API_KEY or MODEL_API_KEY set (non-empty) in
# this process; a readable mechanism other than oauth; or no mechanism established at all - the
# keychain backend, no home, no or an unreadable auth.json, no providers.meta, no mechanism
# (the refusal names that cause and the remedy: TBH_CREDENTIAL_BACKEND=file and `muse login`).
# Names only - a value is never shown. Not a preflight check: -SkipPreflight never bypasses
# it; there is no roster opt-out and no override flag. -Fresh (wave 24, F15-1): auth.json is
# read again, not taken from this process's cache - the guard right before a launch.
$script:MuseApiKeyVariables = @('META_API_KEY', 'MODEL_API_KEY')
function Get-MuseLaunchBlock {
    param([switch]$Fresh)
    foreach ($name in $script:MuseApiKeyVariables) {
        $v = [Environment]::GetEnvironmentVariable($name)
        if ($v -and $v.Trim()) { return "$name is set: a muse run would bill per token instead of the Muse Code subscription; unset it (the muse process would inherit it)" }
    }
    $c = Get-MuseCredentialInfo -Fresh:$Fresh
    if ($c.State -eq 'ok' -and $c.Mechanism -eq 'oauth') { return '' }
    if ($c.Mechanism -and $c.Mechanism -ne 'oauth') { return "the Muse sign-in in $($script:MuseAuthShown) uses mechanism '$($c.Mechanism)', not oauth: a muse run would not bill the Muse Code subscription; sign in with ``muse login``" }
    $cause = $(if ($c.Cause) { $c.Cause } else { $c.Reason })
    return "the Muse sign-in is not established as oauth ($cause): a muse run might bill per token instead of the Muse Code subscription; set TBH_CREDENTIAL_BACKEND=file and run ``muse login``"
}

# reviewer.harness of a muse run (D8): "muse-cli <version>" from .muse-version next to the
# launcher (the vendor's install directory), else the `version` of .muse-release-info.json
# there, else `<launcher> --version` (local, no prompt spent; 15 s), else "muse-cli (version
# unknown)". An unseen version is recorded, never refused. Cached per launcher.
$script:MuseHarnessCache = @{}
$script:MuseVersionRe = '^v?[0-9]+\.[0-9]+[0-9A-Za-z.+_-]{0,48}$'
function Get-MuseHarness {
    param([string]$Launcher)
    if (-not $Launcher) { return 'muse-cli (version unknown)' }
    if ($script:MuseHarnessCache.ContainsKey($Launcher)) { return $script:MuseHarnessCache[$Launcher] }
    $ver = ''
    $dir = Split-Path -Parent $Launcher
    if ($dir) {
        $vf = Join-Path $dir '.muse-version'
        if (Test-Path -LiteralPath $vf -PathType Leaf) { $ver = [string](@((Read-SharedText -Path $vf) -split "`r?`n")[0]).Trim() }
        if ($ver -notmatch $script:MuseVersionRe) {
            $ver = ''
            $rf = Join-Path $dir '.muse-release-info.json'
            if (Test-Path -LiteralPath $rf -PathType Leaf) {
                try { $ver = ([string](Get-PropertyValue (ConvertFrom-Json -InputObject (Read-SharedText -Path $rf)) 'version' '')).Trim() } catch { $ver = '' }
            }
        }
    }
    if ($ver -notmatch $script:MuseVersionRe) {
        $ver = ''
        $cap = Invoke-LauncherCapture -Launcher $Launcher -Arguments '--version' -TimeoutSec 15
        if ($cap.Started -and -not $cap.TimedOut -and $cap.Exit -eq 0) {
            foreach ($tok in @(($cap.Out + "`n" + $cap.Err) -split '\s+')) {
                if ($tok -match $script:MuseVersionRe) { $ver = $tok; break }
            }
        }
    }
    $h = $(if ($ver) { "muse-cli $($ver -replace '^v', '')" } else { 'muse-cli (version unknown)' })
    $script:MuseHarnessCache[$Launcher] = $h
    return $h
}

# The argv of one muse turn (after the launcher), from the turn options: the prompt through
# --prompt-file (the turn's own file; stdin stays empty), the schema through --output-schema
# (structured mode with transport native, and the repair turn), --reasoning-effort only when
# an effort is sent, the read-only flags always, --max-model-steps only with -MaxModelSteps,
# --session-id to continue a session (resume, the format repair).
function New-MuseArgv {
    param($Turn)
    $a = @('exec', '--json', '--prompt-file', [string]$Turn.PromptFile)
    if ($Turn.Schema) { $a += @('--output-schema', [string]$Turn.Schema) }
    $a += @('--model', [string]$Turn.Model)
    if ($null -ne $Turn.Effort -and ([string]$Turn.Effort).Trim()) { $a += @('--reasoning-effort', [string]$Turn.Effort) }
    $a += @('--no-foreign-personal-context', '--disable-web-tools', '--disable-write', '--disable-shell', '--approval-mode', 'never')
    if ([int]$Turn.MaxSteps -gt 0) { $a += @('--max-model-steps', [string][int]$Turn.MaxSteps) }
    if ($Turn.Thread) { $a += @('--session-id', [string]$Turn.Thread) }
    return , ([string[]]$a)
}

# The stdin of a muse turn: nothing (the prompt is the turn's prompt file).
function ConvertTo-MuseStdin {
    param([string]$Prompt)
    return ''
}

# One muse stream (stdout of `muse exec --json`: MSP JSONL records {schema_version, id,
# stream{kind,id}, sequence, record_type, payload_type, payload, ...}), parsed into the
# normalized turn record (D6):
#   Records          the records read
#   Malformed        '' or why the stream is malformed: a line that is not a JSON object (the
#                    LAST line may be partial only with -AllowPartialLast, as for agy), a record
#                    without an integer schema_version, a schema_version other than 1
#                    ("unsupported MSP version N"), more than one session stream id, more than one
#                    run_terminal record, a run_terminal record off the session stream; (wave
#                    23b, F09-3) "ambiguous provenance: ..." - the evidence is bound to the ONE
#                    session stream and the ONE run it links: a session.run.linked record off the
#                    session stream or naming no run stream, more than one run stream linked to
#                    the session, a run.model.configured record off the session stream or naming
#                    another run than the linked one (or with no run linked at all), a completed
#                    run_terminal naming another run (the real CLI puts every record on the
#                    session stream and names the run in payload.run_stream {kind run, id})
#   SchemaVersion    the first record's schema_version ($null when none) - ledger
#                    engine_run.msp_schema_version
#   Sessions         the distinct stream ids of stream.kind "session" (exactly one expected)
#   Session / Thread the session id when exactly one ('' otherwise)
#   RunStream        (wave 23b) the run the session links ("run <id>" from session.run.linked;
#                    '' when none or the stream is malformed): the model evidence and the reply
#                    belong to it
#   TerminalCount, HasTerminal, Terminal (payload.terminal: completed | failed | cancelled ...),
#   Text (payload.text), Reason (payload.reason, '' when null)
#   Models           the model_id of every run.model.configured record, in order
#   Error            the reason of a terminal other than completed
#   Usage            $null (MSP records carry no token usage); ToolName, DeniedAction '' (the
#                    run block's shared fields)
function Read-MuseEvents {
    param([string]$Path, [switch]$AllowPartialLast)
    $r = [pscustomobject]@{ Records = 0; Malformed = ''; SchemaVersion = $null; Sessions = [string[]]@(); Session = ''; Thread = ''; RunStream = ''; TerminalCount = 0; HasTerminal = $false; Terminal = ''; Text = ''; Reason = ''; Models = [string[]]@(); Error = ''; Usage = $null; ToolName = ''; DeniedAction = '' }
    $text = Read-SharedText -Path $Path
    if (-not $text) { return $r }
    $lines = @($text -split "`r?`n")
    $lastIdx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i].Trim()) { $lastIdx = $i; break } }
    $sessions = New-Object System.Collections.Generic.List[string]
    $models = New-Object System.Collections.Generic.List[string]
    # (wave 23b, F09-3) where the evidence sits - { Kind; Id (the record's stream); Line; Run
    # (payload.run_stream as "<kind> <id>", '' when absent) } of every session.run.linked and
    # run.model.configured record (and of the run_terminal record)
    $links = New-Object System.Collections.Generic.List[object]
    $modelAt = New-Object System.Collections.Generic.List[object]
    $terminal = $null
    $terminalStream = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if (-not $t) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $t } catch { $obj = $null }
        if ($null -eq $obj -or -not ($obj -is [System.Management.Automation.PSCustomObject])) {
            if (($i -ne $lastIdx -or -not $AllowPartialLast) -and -not $r.Malformed) { $r.Malformed = "line $($i + 1) is not a JSON object" }
            continue
        }
        $r.Records++
        $sv = Get-PropertyValue $obj 'schema_version' $null
        if (-not (Test-IsJsonInteger $sv)) {
            if (-not $r.Malformed) { $r.Malformed = "the record at line $($i + 1) has no integer schema_version" }
        } else {
            if ($null -eq $r.SchemaVersion) { $r.SchemaVersion = [int]$sv }
            if ([long]$sv -ne 1 -and -not $r.Malformed) { $r.Malformed = "unsupported MSP version $sv (the bridge reads MSP 1)" }
        }
        $stream = Get-PropertyValue $obj 'stream' $null
        $sKind = ''
        $sId = ''
        if (Test-IsJsonObject $stream) {
            $sKind = [string](Get-PropertyValue $stream 'kind' '')
            $sId = [string](Get-PropertyValue $stream 'id' '')
        }
        if ($sKind -eq 'session' -and $sId -and -not $sessions.Contains($sId)) { $sessions.Add($sId) }
        $pType = [string](Get-PropertyValue $obj 'payload_type' '')
        $payload = Get-PropertyValue $obj 'payload' $null
        $pKind = ''
        $pRun = ''
        if (Test-IsJsonObject $payload) {
            $pKind = [string](Get-PropertyValue $payload 'kind' '')
            $rs = Get-PropertyValue $payload 'run_stream' $null
            if (Test-IsJsonObject $rs) { $pRun = ('{0} {1}' -f [string](Get-PropertyValue $rs 'kind' ''), [string](Get-PropertyValue $rs 'id' '')).Trim() }
        }
        $at = [pscustomobject]@{ Kind = $sKind; Id = $sId; Line = $i + 1; Run = $pRun }
        if ($pType -eq 'session.run.linked' -or $pKind -eq 'session_run_linked') { $links.Add($at) }
        if ($pType -eq 'run.model.configured' -or $pKind -eq 'run_model_configured') {
            $modelAt.Add($at)
            $mid = [string](Get-PropertyValue $payload 'model_id' '')
            if ($mid) { $models.Add($mid) }
        }
        if ($pKind -eq 'run_terminal' -or $pType -like 'run.terminal.*') {
            $r.TerminalCount++
            $terminal = $payload
            $terminalStream = $at
        }
    }
    $r.Sessions = [string[]]$sessions.ToArray()
    $r.Models = [string[]]$models.ToArray()
    if ($sessions.Count -gt 1 -and -not $r.Malformed) { $r.Malformed = "$($sessions.Count) session streams (exactly one expected): $($sessions.ToArray() -join ', ')" }
    if ($r.TerminalCount -gt 1 -and -not $r.Malformed) { $r.Malformed = "$($r.TerminalCount) run_terminal records (exactly one expected)" }
    if ($sessions.Count -eq 1) { $r.Session = $sessions[0]; $r.Thread = $sessions[0] }
    if ($null -ne $terminal) {
        $r.HasTerminal = $true
        if (Test-IsJsonObject $terminal) {
            $r.Terminal = [string](Get-PropertyValue $terminal 'terminal' '')
            $tx = Get-PropertyValue $terminal 'text' $null
            if ($null -eq $tx) { $r.Text = '' } elseif ($tx -is [string]) { $r.Text = $tx } else { $r.Text = ConvertTo-Json -InputObject $tx -Compress -Depth 30 }
            $rs = Get-PropertyValue $terminal 'reason' $null
            if ($null -eq $rs) { $r.Reason = '' } elseif ($rs -is [string]) { $r.Reason = $rs } else { $r.Reason = ConvertTo-Json -InputObject $rs -Compress -Depth 10 }
        } elseif (-not $r.Malformed) { $r.Malformed = "the run_terminal record at line $($terminalStream.Line) has no payload object" }
        if (-not $r.Malformed -and ($terminalStream.Kind -ne 'session' -or ($r.Session -and $terminalStream.Id -ne $r.Session))) {
            $r.Malformed = "the run_terminal record at line $($terminalStream.Line) is on stream $(if ($terminalStream.Kind) { $terminalStream.Kind } else { '(none)' }) $($terminalStream.Id), not on the session stream"
        }
        if ($r.Terminal -ne 'completed') { $r.Error = $r.Reason }
    }
    # (wave 23b, F09-3) the provenance of the evidence, fail closed: the session is the ONE
    # stream of kind session; its run is the ONE run stream the session.run.linked records ON
    # that stream name; every run.model.configured record (the model evidence) must sit on the
    # session stream and name that run, and a completed run_terminal (the reply) must name it
    # too. A nested or sub-stream record, a second linked run, or evidence bound to no linked
    # run is "ambiguous provenance" - a malformed stream. (No session: the turn rules fail it.)
    if (-not $r.Malformed -and $sessions.Count -eq 1) {
        $sid = $sessions[0]
        $runs = New-Object System.Collections.Generic.List[string]
        foreach ($l in $links) {
            if ($l.Kind -ne 'session' -or $l.Id -ne $sid) { $r.Malformed = "ambiguous provenance: the session.run.linked record at line $($l.Line) is on stream $(Format-MuseStreamRef $l.Kind $l.Id), not on the session stream"; break }
            if ($l.Run -notmatch '^run \S+$') { $r.Malformed = "ambiguous provenance: the session.run.linked record at line $($l.Line) names no run stream"; break }
            if (-not $runs.Contains($l.Run)) { $runs.Add($l.Run) }
        }
        if (-not $r.Malformed -and $runs.Count -gt 1) { $r.Malformed = "ambiguous provenance: $($runs.Count) run streams linked to the session (exactly one expected): $($runs.ToArray() -join ', ')" }
        $linkedRun = ''
        if ($runs.Count -eq 1) { $linkedRun = $runs[0] }
        if (-not $r.Malformed) {
            foreach ($m in $modelAt) {
                $named = $(if ($m.Run) { "stream $($m.Run)" } else { 'no run stream' })
                if ($m.Kind -ne 'session' -or $m.Id -ne $sid) { $r.Malformed = "ambiguous provenance: the run.model.configured record at line $($m.Line) is on stream $(Format-MuseStreamRef $m.Kind $m.Id), not on the session stream"; break }
                if (-not $linkedRun) { $r.Malformed = "ambiguous provenance: the run.model.configured record at line $($m.Line) names $named, but no session.run.linked record links a run to the session"; break }
                if ($m.Run -ne $linkedRun) { $r.Malformed = "ambiguous provenance: the run.model.configured record at line $($m.Line) names $named, not the run linked to the session ($linkedRun)"; break }
            }
        }
        if (-not $r.Malformed -and $linkedRun -and $r.Terminal -eq 'completed' -and $terminalStream.Run -ne $linkedRun) {
            $r.Malformed = "ambiguous provenance: the run_terminal record at line $($terminalStream.Line) names $(if ($terminalStream.Run) { "stream $($terminalStream.Run)" } else { 'no run stream' }), not the run linked to the session ($linkedRun)"
        }
        if (-not $r.Malformed) { $r.RunStream = $linkedRun }
    }
    return $r
}

# "<kind> <id>" of a record's stream, "(none)" without one (Read-MuseEvents' messages).
function Format-MuseStreamRef {
    param([string]$Kind, [string]$Id)
    $s = ("$Kind $Id").Trim()
    if (-not $s) { return '(none)' }
    return $s
}

# The failure rules of one muse turn (the main turn, the format repair; D6, D7). The same result
# object as Get-AgyTurnOutcome (DeniedEmpty is always $false: there is no denial retry):
#   $Pre             a failure the bridge already knows (its own timeout, could not start) wins
#   (detail: the terminal's reason, else the first `error:` line of stderr, else its last line)
#   exit 2           failed: muse exit 2 (usage error) - <detail>, class capability
#   exit 130 / 143   failed: muse exit <n> (stopped by a signal) - <detail>, class transport
#   other exit != 0  failed: muse exit <n> - <terminal reason | stderr>; a reason that names the
#                    step cap -> "max model steps reached", class capability; else the texts'
#                    classifier (quota wording -> quota, with retry_after when a reset is named)
#   malformed        failed: malformed event stream: <why>, class transport
#   no terminal      failed: no run_terminal record in the muse event stream, classified text
#   no session       failed (class unknown)
#   $ExpectThread    (resume, repair) a session other than the requested one -> failed: parent
#                    session <p> not found, muse started <s> (class unknown; a candidate only)
#   terminal != completed  failed: muse terminal <t> - <reason> (step cap: capability)
#   session not a uuid     failed (class unknown)
#   $ExpectModel     run.model.configured must name exactly the requested model: none -> failed
#                    (class unknown), another -> failed: model drift: asked X, served Y (class
#                    capability); the session is then a candidate only, never a parent
#   empty text       failed: empty reply
#   usable           every `warning:` line of stderr becomes a Warning
$script:MuseStepCapRe = '(?i)\bmax(?:imum)?[ _-]?(?:model[ _-]?)?steps?\b|\bstep (?:cap|limit|budget)\b'
# The informational lines every `muse exec` prints on stderr (the workspace root; "Agent
# delegation: auto unavailable: workspace is untrusted.") - never a failure's detail (the second
# would read as class transport).
$script:MuseInfoStderrRe = '(?i)^muse:\s*(workspace root:|agent delegation:)'
function Get-MuseTurnOutcome {
    # (-Turn, wave 29: the adapter contract - the turn's options, not needed by muse's rules)
    param($Events, [int]$ExitCode, [string]$StderrText = '', [string]$Pre = '', [string]$ExpectThread = '', [string]$ExpectModel = '', $Turn = $null)
    $o = [pscustomobject]@{ Ok = $false; Outcome = ''; Class = ''; Texts = [string[]]@(); Thread = ''; ThreadCandidate = ''; Reply = ''; Structured = $false; DeniedEmpty = $false; DenialLine = ''; Permission = ''; NotFound = ''; Warnings = [string[]]@() }
    $lines = @(([string]$StderrText) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch $script:MuseInfoStderrRe })
    $warnLines = @($lines | Where-Object { $_ -match '(?i)^(muse:\s*)?warning:' })
    # the telling stderr line: the first `error:` line (a usage error ends with its usage
    # boilerplate), else the last line
    $errLine = @($lines | Where-Object { $_ -match '(?i)^(muse:\s*)?error\b' }) | Select-Object -First 1
    $stderrTail = if ($errLine) { [string]$errLine } elseif ($lines.Count -gt 0) { $lines[-1] } else { '' }
    $session = [string]$Events.Session
    $isUuid = ($session -match $script:UuidRe)
    if ($Events.Terminal -eq 'completed') { $o.Reply = [string]$Events.Text }
    if ($o.Reply.Trim().StartsWith('{')) { try { $o.Structured = (Test-IsJsonObject (ConvertFrom-Json -InputObject $o.Reply)) } catch { $o.Structured = $false } }
    $reason = [string]$Events.Reason
    $detail = if ($reason) { $reason } else { $stderrTail }
    $stepCap = ($detail -and $detail -match $script:MuseStepCapRe)
    $fail = {
        param([string]$Why, [string]$Class = '', [string[]]$Texts = @())
        $o.Ok = $false
        $o.Outcome = "failed: $Why"
        $o.Class = $Class
        $o.Texts = [string[]]@(@($Texts) + @($Why) | Where-Object { $_ })
    }
    if ($Pre) {
        $o.Outcome = $Pre
        $o.Texts = [string[]]@(@($reason, $detail, ($Pre -replace '^failed:\s*', '')) | Where-Object { $_ })
        if ($isUuid) { $o.ThreadCandidate = $session }
        return $o
    }
    if ($ExitCode -ne 0) {
        $tail = $(if ($detail) { " - $(ConvertTo-OneLine $detail)" } else { '' })
        if ($ExitCode -eq 2) { & $fail "muse exit 2 (usage error)$tail" 'capability' @($detail) }
        elseif ($ExitCode -eq 130 -or $ExitCode -eq 143) { & $fail "muse exit $ExitCode (stopped by a signal)$tail" 'transport' @($detail) }
        elseif ($stepCap) { & $fail "muse exit $ExitCode - max model steps reached$(if ($detail) { " ($(ConvertTo-OneLine $detail))" })" 'capability' @($detail) }
        else { & $fail "muse exit $ExitCode$tail" '' @($reason, $stderrTail) }
        if ($isUuid -and (-not $ExpectThread -or $session -eq $ExpectThread)) { $o.Thread = $session } elseif ($isUuid) { $o.ThreadCandidate = $session }
        return $o
    }
    if ($Events.Malformed) {
        & $fail "malformed event stream: $($Events.Malformed)" 'transport'
        if ($isUuid) { $o.ThreadCandidate = $session }
        return $o
    }
    if (-not $Events.HasTerminal) {
        & $fail "no run_terminal record in the muse event stream$(if ($stderrTail) { " - $(ConvertTo-OneLine $stderrTail)" })" '' @($stderrTail)
        if ($isUuid) { $o.ThreadCandidate = $session }
        return $o
    }
    if (-not $session) {
        & $fail 'the muse event stream names no session (no stream of kind session)' 'unknown'
        return $o
    }
    if ($ExpectThread -and $session -ne $ExpectThread) {
        & $fail "parent session $ExpectThread not found, muse started $session" 'unknown'
        if ($isUuid) { $o.ThreadCandidate = $session }
        return $o
    }
    if ($Events.Terminal -ne 'completed') {
        $t = if ($Events.Terminal) { $Events.Terminal } else { '(none)' }
        if ($stepCap) { & $fail "muse terminal $t - max model steps reached$(if ($detail) { " ($(ConvertTo-OneLine $detail))" })" 'capability' @($detail) }
        else { & $fail "muse terminal $t$(if ($detail) { " - $(ConvertTo-OneLine $detail)" })" '' @($reason, $stderrTail) }
        if ($isUuid) { $o.Thread = $session }
        return $o
    }
    if (-not $isUuid) {
        & $fail "the session id '$session' is not a uuid" 'unknown'
        return $o
    }
    if ($ExpectModel) {
        $served = @($Events.Models)
        if ($served.Count -eq 0) {
            & $fail "the muse event stream names no configured model (run.model.configured; asked $ExpectModel)" 'unknown'
            $o.ThreadCandidate = $session
            return $o
        }
        $other = @($served | Where-Object { $_ -cne $ExpectModel }) | Select-Object -First 1
        if ($other) {
            & $fail "model drift: asked $ExpectModel, served $other" 'capability'
            $o.ThreadCandidate = $session
            return $o
        }
    }
    $o.Thread = $session
    if (-not $o.Reply.Trim()) {
        & $fail 'empty reply' ''
        return $o
    }
    $o.Ok = $true
    $o.Outcome = 'usable reply'
    $o.Warnings = [string[]]@($warnLines | ForEach-Object { ConvertTo-OneLine $_ })
    return $o
}

# ---- claude adapter (wave 29: Claude Code headless, `claude -p`; ROADMAP R10 with R22 - the design
# of the task claude-engine-2026-09-30 as amended by its decisions D1-D12)

# (D4 / F02-3) THE model table of the claude engine: the aliases the CLI resolves itself (its help:
# "an alias for the latest model") and the published model ids (2026-09-25). A roster entry of the
# engine names one of them - optionally with the 1M-context suffix [1m], stripped before every
# comparison - and the telemetry's closed model list of the vendor class anthropic IS this table.
# Anything else is refused by the roster validator and reads `other` in telemetry; the ledger keeps
# the real name. (wave 29b, E2) The table does NOT apply to auth endpoint (a third-party
# Anthropic-compatible endpoint): its model is the id as the provider publishes it, matching
# $script:ClaudeEndpointModelRe (an optional [1m] suffix), sent straight as --model <id>.
$script:ClaudeModelAliases = @('opus', 'sonnet', 'haiku', 'fable')
$script:ClaudeModels = @('opus', 'sonnet', 'haiku', 'fable', 'claude-fable-5-1', 'claude-fable-5', 'claude-opus-5-5', 'claude-opus-5', 'claude-opus-4-8', 'claude-opus-4-7', 'claude-opus-4-6', 'claude-sonnet-5-5', 'claude-sonnet-5', 'claude-sonnet-4-6', 'claude-haiku-4-5')
# The roster's `auth` of the engine (item 6): the subscription login (the default), an API key or
# (wave 29b, E1) a third-party Anthropic-compatible endpoint spelled out in the roster entry's
# `endpoint` object ({base_url, env_key, timeout_ms}) - ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN
# in the child environment only
$script:ClaudeAuthModes = @('subscription', 'api-key', 'endpoint')
# (wave 29b, E2) the model id of an endpoint entry; (E1) the endpoint's keys, its token variable's
# NAME, its API_TIMEOUT_MS bounds and default; (E5) a plan slug (any entry of any engine)
$script:ClaudeEndpointModelRe = '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}(\[1m\])?$'
$script:ClaudeEndpointKeys = @('base_url', 'env_key', 'timeout_ms')
$script:ClaudeEndpointEnvKeyRe = '^[A-Z][A-Z0-9_]{2,}$'
$script:ClaudeEndpointTimeoutDefault = 3000000
$script:ClaudeEndpointTimeoutMin = 60000
$script:ClaudeEndpointTimeoutMax = 7200000
$script:PlanSlugRe = '^[a-z][a-z0-9-]{1,31}$'
# (item 4) The tools a claude turn may have: the read tools and the CLI's own StructuredOutput -
# proven by EVERY init event of the turn, with no MCP server and the permission mode dontAsk
$script:ClaudeTools = @('Read', 'Grep', 'Glob', 'StructuredOutput')
$script:ClaudeToolsArg = 'Read,Grep,Glob'
$script:ClaudePermissionMode = 'dontAsk'
# (D9) the largest prompt the engine is given on stdin (the row's MaxPromptBytes, 1 MiB): the upper
# bound of `claude -p` reading stdin is not known - a 52 KB prompt was read whole (obs)
# (R22) what a reviewer child runs without (ledger engine_run.switched_off): --restricted (user,
# project and local settings - their hooks and plugins -, the repository's and the home directory's
# CLAUDE.md / AGENTS.md: P3; the code-running tools and WebFetch), --strict-mcp-config (MCP servers),
# --disable-slash-commands (skills, slash commands), --tools Read,Grep,Glob (no write tool exists),
# DISABLE_AUTOUPDATER=1 (a reviewer never replaces the binary the coordinator runs)
$script:ClaudeSwitchedOff = @('user-settings', 'project-settings', 'local-settings', 'instruction-files', 'mcp-servers', 'skills', 'slash-commands', 'code-tools', 'web-tools', 'write-tools', 'autoupdater')

# A claude model name without its 1M-context suffix [1m], trimmed and lower-cased.
function ConvertTo-ClaudeModelBase {
    param([string]$Model)
    return ((([string]$Model).Trim()) -replace '(?i)\[1m\]$', '').ToLowerInvariant()
}
# The family of a claude model (opus | sonnet | haiku | fable), '' when it names none.
function Get-ClaudeModelFamily {
    param([string]$Model)
    $b = ConvertTo-ClaudeModelBase $Model
    if ($script:ClaudeModelAliases -ccontains $b) { return $b }
    if ($b -match '^claude-(opus|sonnet|haiku|fable)-') { return $Matches[1] }
    return ''
}
# Whether a claude model name is an alias (it floats: each thread is pinned to the id it resolves to).
function Test-ClaudeModelAlias {
    param([string]$Model)
    return ($script:ClaudeModelAliases -ccontains (ConvertTo-ClaudeModelBase $Model))
}
# Whether $Served is the model $Pinned asks for: equal after [1m] is stripped, or $Pinned an alias
# and $Served an id of its family (claude-<alias>-...), or the other way round. (wave 29b, E2)
# -Exact (auth endpoint): equal after the [1m] strip only - no alias family, so a turn served by
# the subscription can never pass for the endpoint's model.
function Test-ClaudeModelMatch {
    param([string]$Pinned, [string]$Served, [switch]$Exact)
    $p = ConvertTo-ClaudeModelBase $Pinned
    $s = ConvertTo-ClaudeModelBase $Served
    if (-not $p -or -not $s) { return $false }
    if ($p -ceq $s) { return $true }
    if ($Exact) { return $false }
    if ($script:ClaudeModelAliases -ccontains $p) { return $s.StartsWith("claude-$p-", [StringComparison]::Ordinal) }
    if ($script:ClaudeModelAliases -ccontains $s) { return $p.StartsWith("claude-$s-", [StringComparison]::Ordinal) }
    return $false
}
# '' when a roster or -Model value names a model of the table (D4; a trailing [1m] allowed), else why not.
# (wave 29b, E2) -Auth endpoint: the open id pattern instead of the table.
function Get-ClaudeModelProblem {
    param($Model, [string]$Auth = '')
    if (-not ($Model -is [string]) -or -not $Model.Trim()) { return 'is empty' }
    if ($Auth -eq 'endpoint') {
        if ([string]$Model -cnotmatch $script:ClaudeEndpointModelRe) { return 'is not a model id the endpoint route takes (the id as the provider publishes it: letters, digits, ".", "_", "-", at most 64 characters, optionally ending with [1m])' }
        # (wave 29b, E11) the billing proof: on this route the init event's apiKeySource is 'none', the
        # same as for the subscription login, so a silent fallback to the local login is visible only
        # when the init model id is one the subscription CANNOT serve. An id of the closed table or any
        # claude-* id could be served by the subscription: refused (a -Model and a roster entry alike).
        $eb = (([string]$Model) -replace '\[1m\]$', '').ToLowerInvariant()
        if ($script:ClaudeModels -contains $eb -or $eb.StartsWith('claude-', [StringComparison]::Ordinal)) { return "is an Anthropic model id, which the endpoint route cannot carry: the init event's apiKeySource is 'none' on this route as on the subscription, so only a model the subscription cannot serve proves the billing - name the provider's own model id" }
        return ''
    }
    $b = ([string]$Model) -replace '\[1m\]$', ''
    if ($script:ClaudeModels -cnotcontains $b) { return "is not in the claude engine's model table ($($script:ClaudeModels -join ', '); each may end with [1m])" }
    return ''
}

# (wave 29b, E1) The endpoint object of a roster entry with auth endpoint, from the roster's JSON
# value: { Endpoint ($null on a refusal; else { BaseUrl (as written - what ANTHROPIC_BASE_URL
# gets); Canonical (lower-case scheme and host, the explicit port if any, the path without a
# trailing slash - the route fingerprint's part); HostName; EnvKey (the NAME of the variable that
# holds the token - never its value); TimeoutMs (API_TIMEOUT_MS; default 3000000); Plan (the
# entry's plan slug, '' without one - provider_config only) }); Error ('' or the refusal in the
# roster's wording, without the entry prefix) }. Neither a URL nor an env_key value is echoed in a
# refusal: either could hold a credential pasted by mistake.
function ConvertFrom-ClaudeEndpointValue {
    param($Value, [string]$Plan = '')
    $r = [pscustomobject]@{ Endpoint = $null; Error = '' }
    if (-not (Test-IsJsonObject $Value)) { $r.Error = 'endpoint must be an object {"base_url": "https://...", "env_key": "<VARIABLE NAME>", "timeout_ms": <milliseconds, optional>}'; return $r }
    foreach ($prop in $Value.PSObject.Properties) {
        if ($script:ClaudeEndpointKeys -cnotcontains $prop.Name) { $r.Error = "endpoint has an unknown key '$($prop.Name)' (allowed: $($script:ClaudeEndpointKeys -join ', '))"; return $r }
    }
    $urlWhy = 'endpoint.base_url must be an absolute https URL without credentials, query or fragment (e.g. "https://api.z.ai/api/anthropic"; the value is not shown)'
    $bu = Get-PropertyValue $Value 'base_url' $null
    if (-not ($bu -is [string]) -or -not $bu.Trim() -or $bu -match '\s') { $r.Error = $urlWhy; return $r }
    $uri = $null
    if ($bu -notmatch '^(?i)https://[^/?#@]+' -or -not [Uri]::TryCreate($bu, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -cne 'https' -or -not $uri.Host -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $bu.Contains('#') -or $bu.Contains('?')) { $r.Error = $urlWhy; return $r }
    $ek = Get-PropertyValue $Value 'env_key' $null
    if (-not ($ek -is [string]) -or $ek -cnotmatch $script:ClaudeEndpointEnvKeyRe) { $r.Error = 'endpoint.env_key must be the NAME of the environment variable that holds the token (capital letters, digits and _, at least 3 characters, starting with a letter - e.g. "ZAI_API_KEY"), never the token itself (the value is not shown)'; return $r }
    $tm = [long]$script:ClaudeEndpointTimeoutDefault
    if ($Value.PSObject.Properties['timeout_ms']) {
        $tv = $Value.timeout_ms
        if (-not (Test-IsJsonInteger $tv) -or [double]$tv -lt $script:ClaudeEndpointTimeoutMin -or [double]$tv -gt $script:ClaudeEndpointTimeoutMax) { $r.Error = "endpoint.timeout_ms must be an integer from $($script:ClaudeEndpointTimeoutMin) to $($script:ClaudeEndpointTimeoutMax) (milliseconds - API_TIMEOUT_MS; default $($script:ClaudeEndpointTimeoutDefault); got $(ConvertTo-Json -InputObject $tv -Compress))"; return $r }
        $tm = [long]$tv
    }
    $cu = ConvertTo-CanonicalBaseUrl $bu
    $r.Endpoint = [pscustomobject]@{ BaseUrl = [string]$bu; Canonical = [string]$cu.Url; HostName = [string]$cu.HostName; EnvKey = [string]$ek; TimeoutMs = [long]$tm; Plan = [string]$Plan }
    return $r
}

# (wave 29b, E3) '' when an endpoint object is usable for a launch (a base URL that parses, a token
# variable NAME), else why not - the defensive re-check of the preflight and the child environment.
function Get-ClaudeEndpointProblem {
    param($Endpoint)
    if ($null -eq $Endpoint) { return 'auth endpoint names no endpoint (the roster entry''s "endpoint" object)' }
    $bu = [string](Get-PropertyValue $Endpoint 'BaseUrl' '')
    $uri = $null
    if (-not $bu -or -not [Uri]::TryCreate($bu, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -cne 'https' -or -not $uri.Host) { return 'endpoint.base_url does not parse as an absolute https URL' }
    if ([string](Get-PropertyValue $Endpoint 'EnvKey' '') -cnotmatch $script:ClaudeEndpointEnvKeyRe) { return 'endpoint.env_key is not a variable name' }
    return ''
}

# (wave 29b, E3) The token of an endpoint, read from the variable its env_key NAMES - at the moment
# a child environment is built (the launch), never stored, logged or printed. '' when unset or blank.
function Get-ClaudeEndpointToken {
    param($Endpoint)
    $n = [string](Get-PropertyValue $Endpoint 'EnvKey' '')
    if (-not $n) { return '' }
    $v = [Environment]::GetEnvironmentVariable($n)
    if (-not $v -or -not $v.Trim()) { return '' }
    return [string]$v
}

# (D2 / F02-2, F03-2, F03-4, F03-5) THE child environment of the claude engine: an ALLOW list, never a
# scrub list - the system variables a process needs (as for the telemetry sender), the locale, proxy
# and trust variables, CLAUDE_CONFIG_DIR (the login lives there) and - only with auth api-key -
# ANTHROPIC_API_KEY. Every other ANTHROPIC_* and every CLAUDE_* / CLAUDE_CODE_* variable is absent
# (no inherited gateway, routing, provider selector, effort, persistence or model override reaches a
# reviewer; a Bedrock, Vertex or Foundry setup fails closed at the preflight - D10), and so is every
# host marker and test-mode variable. DISABLE_AUTOUPDATER=1 is set. Names compared case-insensitively.
# (wave 29b, E4) auth endpoint adds - for that mode only - ANTHROPIC_BASE_URL (endpoint.base_url),
# ANTHROPIC_AUTH_TOKEN (the value of the variable endpoint.env_key names, read when the environment
# is built - at the launch -, never logged) and API_TIMEOUT_MS (endpoint.timeout_ms); ANTHROPIC_API_KEY
# stays absent (it would take precedence), and so does every model alias variable (ANTHROPIC_MODEL,
# ANTHROPIC_DEFAULT_*_MODEL, ANTHROPIC_SMALL_FAST_MODEL - E2).
# TEST HOOK (test mode only): CODEX_CONSULT_TEST_CHILD_ENV_PASS=<prefix> lets the variables of that
# prefix through too (the harness's fake CLI reads its FAKE_CLAUDE_* drivers) - never a prefix of
# ANTHROPIC, CLAUDE or CODEX_CONSULT.
$script:ClaudeChildEnvNames = @(
    'SystemRoot', 'windir', 'SystemDrive', 'ComSpec', 'PATH', 'PATHEXT', 'TEMP', 'TMP', 'TMPDIR',
    'USERPROFILE', 'HOME', 'HOMEDRIVE', 'HOMEPATH', 'APPDATA', 'LOCALAPPDATA', 'ProgramData', 'ALLUSERSPROFILE', 'PUBLIC', 'PSModulePath',
    'USERNAME', 'USERDOMAIN', 'COMPUTERNAME', 'USER', 'LOGNAME', 'SHELL', 'TERM',
    'PROCESSOR_ARCHITECTURE', 'PROCESSOR_IDENTIFIER', 'PROCESSOR_LEVEL', 'PROCESSOR_REVISION', 'NUMBER_OF_PROCESSORS', 'OS',
    'LANG', 'LANGUAGE', 'TZ',
    'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR',
    'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'ALL_PROXY',
    'SSL_CERT_FILE', 'SSL_CERT_DIR', 'REQUESTS_CA_BUNDLE', 'CURL_CA_BUNDLE', 'NODE_EXTRA_CA_CERTS',
    'CLAUDE_CONFIG_DIR'
)
$script:ClaudeChildEnvPrefixes = @('ProgramFiles', 'CommonProgramFiles', 'ProgramW6432', 'CommonProgramW6432', 'LC_')
$script:ClaudeChildEnvSet = [ordered]@{ 'DISABLE_AUTOUPDATER' = '1' }
# (wave 29b, E4) the variables auth endpoint sets in the child (never inherited from this process)
$script:ClaudeEndpointEnvNames = @('ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL', 'API_TIMEOUT_MS')
function Test-ClaudeChildEnvName {
    param([string]$Name, [string]$Auth = 'subscription', [string]$PassPrefix = '')
    $u = ([string]$Name).ToUpperInvariant()
    foreach ($n in $script:ClaudeChildEnvNames) { if ($u -ceq $n.ToUpperInvariant()) { return $true } }
    foreach ($p in $script:ClaudeChildEnvPrefixes) { if ($u.StartsWith($p.ToUpperInvariant(), [StringComparison]::Ordinal)) { return $true } }
    if ($Auth -eq 'api-key' -and $u -ceq 'ANTHROPIC_API_KEY') { return $true }
    if ($PassPrefix -and $u.StartsWith($PassPrefix.ToUpperInvariant(), [StringComparison]::Ordinal)) { return $true }
    return $false
}
# The child environment of a claude process for $Auth, from THIS process's environment (read-only
# here): { Auth; Env (name -> value, sorted; the allowed variables plus the set ones); Names
# (string[], sorted ordinal - the ledger's engine_run.child_env_allowed; never a value); Removed
# (string[]: the names of this process's variables the child does not get); Problem (wave 29b: ''
# or why no child may start with it - auth endpoint without a usable endpoint or without its token
# set: the CLI would fall back to the local login and could send its OAuth token to the third-party
# base URL; Start-EngineProcess refuses the start) }. One builder for the preflight, the version
# probe and every turn (D3 / F03-3). $Endpoint: the roster entry's endpoint (auth endpoint only).
function Get-ClaudeChildEnvironment {
    param([string]$Auth = 'subscription', $Endpoint = $null)
    if ($script:ClaudeAuthModes -notcontains $Auth) { $Auth = 'subscription' }
    $pass = ([string](Get-TestHookValue 'CODEX_CONSULT_TEST_CHILD_ENV_PASS')).Trim()
    if ($pass -and ($pass -notmatch '^[A-Za-z][A-Za-z0-9_]{3,}$' -or $pass.ToUpperInvariant() -match '^(ANTHROPIC|CLAUDE|CODEX_CONSULT)')) { $pass = '' }
    $cmp = $(if ($script:OnWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal })
    $envOut = New-Object 'System.Collections.Generic.SortedDictionary[string,string]' ($cmp)
    $removed = New-Object System.Collections.Generic.List[string]
    $all = [Environment]::GetEnvironmentVariables()
    foreach ($k in @($all.Keys)) {
        $n = [string]$k
        if (-not $n -or $n.Contains('=') -or $envOut.ContainsKey($n)) { continue }
        if (Test-ClaudeChildEnvName -Name $n -Auth $Auth -PassPrefix $pass) { $envOut[$n] = [string]$all[$k] }
        elseif (-not $script:ClaudeChildEnvSet.Contains($n) -and -not ($Auth -eq 'endpoint' -and $script:ClaudeEndpointEnvNames -contains $n.ToUpperInvariant()) -and -not $removed.Contains($n)) { $removed.Add($n) }
    }
    foreach ($k in @($script:ClaudeChildEnvSet.Keys)) { $envOut[[string]$k] = [string]$script:ClaudeChildEnvSet[$k] }
    $problem = ''
    if ($Auth -eq 'endpoint') {
        # (E4) the route's own three variables; the token only when its variable is set now
        $problem = Get-ClaudeEndpointProblem $Endpoint
        if (-not $problem) {
            $envOut['ANTHROPIC_BASE_URL'] = [string]$Endpoint.BaseUrl
            $envOut['API_TIMEOUT_MS'] = [string][long]$Endpoint.TimeoutMs
            $token = Get-ClaudeEndpointToken $Endpoint
            if ($token) { $envOut['ANTHROPIC_AUTH_TOKEN'] = $token }
            else { $problem = "env $($Endpoint.EnvKey) not set (the token of auth endpoint)" }
            $token = $null
        }
    }
    $names = [string[]]@($envOut.Keys)
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $rm = [string[]]$removed.ToArray()
    [Array]::Sort($rm, [StringComparer]::Ordinal)
    return [pscustomobject]@{ Auth = $Auth; Env = $envOut; Names = $names; Removed = $rm; Problem = $problem }
}

# A probe of the claude launcher (`claude auth status`, `claude --version`) in the child
# environment of $Auth (D3): its start info's block is CLEARED and filled from
# Get-ClaudeChildEnvironment, then started through Start-ProbeProcess (never with a host marker).
# Nothing on stdin; stdout and stderr as UTF-8. { Started; Why; Exit (-1 when it did not exit);
# TimedOut; Out; Err }.
function Invoke-ClaudeProbe {
    param([string]$Launcher, [string]$Arguments, [int]$TimeoutSec = 15, [string]$Auth = 'subscription')
    $r = [pscustomobject]@{ Started = $false; Why = ''; Exit = -1; TimedOut = $false; Out = ''; Err = '' }
    $p = $null
    try {
        # (the block reads $Launcher, $Arguments and $Auth of this function: Start-ProbeProcess runs it
        # in a child scope of its own, which has none of them)
        $start = Start-ProbeProcess -Make {
            $cpsi = New-ProbeStartInfo -Launcher $Launcher -Arguments $Arguments
            $cblock = $cpsi.EnvironmentVariables
            $cblock.Clear()
            $cce = Get-ClaudeChildEnvironment -Auth $Auth
            foreach ($ck in @($cce.Env.Keys)) { $cblock[[string]$ck] = [string]$cce.Env[$ck] }
            $cpsi
        }
        if ($start.Skipped) { $r.Why = [string]$start.Skipped; return $r }
        $p = $start.Proc
    } catch { $r.Why = ConvertTo-OneLine $_.Exception.Message; return $r }
    $r.Started = $true
    try {
        try { $p.StandardInput.Close() } catch { }
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $null = Stop-ProcessTree -Process $p
            $r.TimedOut = $true
            return $r
        }
        $p.WaitForExit()
        $null = $outTask.Wait(5000)
        $null = $errTask.Wait(5000)
        $r.Exit = $p.ExitCode
        $r.Out = [string]$outTask.Result
        $r.Err = [string]$errTask.Result
        return $r
    } finally {
        $p.Dispose()
    }
}

# A short identifier as the CLI reported it (authMethod, apiProvider, apiKeySource, a permission
# mode), '' when absent, 'unrecognized' for anything that is not one - never an arbitrary text.
function ConvertTo-ClaudeToken {
    param($Value)
    if (-not ($Value -is [string]) -or -not $Value.Trim()) { return '' }
    if ($Value -cmatch '^[A-Za-z][A-Za-z0-9_.-]{0,39}$') { return $Value }
    return 'unrecognized'
}

# (item 6, D3 / F03-3, F03-9) The sign-in check of a claude entry - `claude auth status` (local, free:
# no request is spent) in the SAME child environment as a turn of $Auth, 15 s. Its JSON is read
# BEFORE its exit code: loggedIn false -> missing ("not signed in"), whatever the exit code;
# loggedIn true -> ok when the route is the one the roster names: subscription - authMethod
# claude.ai; api-key - ANTHROPIC_API_KEY set in this process (checked before anything starts); an
# apiProvider other than firstParty (a gateway, Bedrock, Vertex, Foundry - D10) or another
# authMethod -> missing. No launcher -> missing; not started, a timeout, no JSON or no loggedIn ->
# unknown ("not checked"). No credentials-file fallback. Only authMethod, apiProvider and
# projectsDirectory are kept (the cache, for the ledger's provider_config and the launch check) -
# never the account's e-mail or organisation.
# (wave 29b, E3) auth endpoint: NO `claude auth status` (it reads the local login and ignores the
# base URL - P12) and no live request (it would spend the plan's credits): the launcher is found,
# endpoint.base_url parses and the variable endpoint.env_key names is set and non-empty - "ok: env
# <NAME> set" or "missing: env <NAME> not set", as for a codex table (never the value).
$script:ClaudeSignInCache = @{}
function Get-ClaudeSignIn {
    param([string]$Launcher = '', [int]$TimeoutSec = 15, [string]$Auth = 'subscription', $Endpoint = $null)
    if ($script:ClaudeAuthModes -notcontains $Auth) { $Auth = 'subscription' }
    if (-not $Launcher) { return (New-CredentialResult 'missing' 'claude CLI not found on PATH') }
    if ($Auth -eq 'endpoint') {
        $ep = Get-ClaudeEndpointProblem $Endpoint
        if ($ep) { return (New-CredentialResult 'missing' $ep) }
        if (-not (Get-ClaudeEndpointToken $Endpoint)) { return (New-CredentialResult 'missing' "env $($Endpoint.EnvKey) not set") }
        return (New-CredentialResult 'ok' "env $($Endpoint.EnvKey) set")
    }
    if ($Auth -eq 'api-key') {
        $key = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY')
        if (-not $key -or -not $key.Trim()) { return (New-CredentialResult 'missing' 'ANTHROPIC_API_KEY is not set (roster auth api-key)') }
    }
    $t = $(if ($TimeoutSec -gt 0) { [Math]::Min($TimeoutSec, 15) } else { 15 })
    $cap = Invoke-ClaudeProbe -Launcher $Launcher -Arguments 'auth status' -TimeoutSec $t -Auth $Auth
    if (-not $cap.Started) { return (New-CredentialResult 'unknown' "not checked - ``claude auth status`` could not be started$(if ($cap.Why) { " ($($cap.Why))" })") }
    if ($cap.TimedOut) { return (New-CredentialResult 'unknown' "not checked - ``claude auth status`` did not finish within $t s") }
    $o = $null
    $out = [string]$cap.Out
    $a = $out.IndexOf('{'); $b = $out.LastIndexOf('}')
    if ($a -ge 0 -and $b -gt $a) { try { $o = ConvertFrom-Json -InputObject $out.Substring($a, $b - $a + 1) } catch { $o = $null } }
    $out = $null
    if (-not (Test-IsJsonObject $o)) { return (New-CredentialResult 'unknown' "not checked - ``claude auth status`` printed no JSON object (exit $($cap.Exit))") }
    $li = Get-PropertyValue $o 'loggedIn' $null
    $am = ConvertTo-ClaudeToken (Get-PropertyValue $o 'authMethod' $null)
    $ap = ConvertTo-ClaudeToken (Get-PropertyValue $o 'apiProvider' $null)
    $pd = Get-PropertyValue $o 'projectsDirectory' $null
    $o = $null
    $script:ClaudeSignInCache["$Launcher|$Auth"] = [pscustomobject]@{ AuthMethod = $am; ApiProvider = $ap; ProjectsDirectory = $(if ($pd -is [string]) { $pd } else { '' }) }
    if ($li -eq $false) { return (New-CredentialResult 'missing' 'not signed in (`claude auth status`: loggedIn false; run `claude auth login`)') }
    if ($li -ne $true) { return (New-CredentialResult 'unknown' "not checked - ``claude auth status`` names no loggedIn (exit $($cap.Exit))") }
    if ($ap -and $ap -cne 'firstParty') { return (New-CredentialResult 'missing' "apiProvider $ap - routes other than Anthropic's own API (a gateway, Bedrock, Vertex, Foundry) are out of scope for the claude engine") }
    if ($Auth -eq 'subscription') {
        if ($am -cne 'claude.ai') { return (New-CredentialResult 'missing' "signed in with authMethod $(if ($am) { $am } else { '(none)' }), not the claude.ai subscription the roster names (auth subscription; an API key is auth api-key)") }
        return (New-CredentialResult 'ok' 'signed in (claude.ai subscription)')
    }
    return (New-CredentialResult 'ok' "signed in (ANTHROPIC_API_KEY set$(if ($am) { "; authMethod $am" }))")
}

# (item 6) The local part of a claude entry's sign-in that no ledger evidence replaces (the
# adapter's LocalCheck, before the 60-minute short-circuit of Get-EngineCredential): auth api-key
# needs ANTHROPIC_API_KEY set in this process now. '' or the reason (a name, never a value).
# (wave 29b, E3) auth endpoint: a usable endpoint and the variable its env_key names set now.
function Test-ClaudeLocalCredential {
    param([string]$Auth = 'subscription', $Endpoint = $null)
    if ($Auth -eq 'endpoint') {
        $ep = Get-ClaudeEndpointProblem $Endpoint
        if ($ep) { return $ep }
        if (-not (Get-ClaudeEndpointToken $Endpoint)) { return "env $($Endpoint.EnvKey) not set" }
        return ''
    }
    if ($Auth -ne 'api-key') { return '' }
    $key = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY')
    if (-not $key -or -not $key.Trim()) { return 'ANTHROPIC_API_KEY is not set (roster auth api-key)' }
    return ''
}

# reviewer.provider_config's claude fields (item 6): credential_mechanism = the roster's auth
# (subscription | api-key); auth_method and api_provider as `claude auth status` reported them in
# this process (the preflight), $null when it did not run. (wave 29b, E5) auth endpoint:
# credential_mechanism endpoint, base_url (as the roster names it - not a secret), env_key (the
# variable's NAME - the token never appears) and plan (the entry's plan slug, $null without one).
function Get-ClaudeIdentityConfig {
    param([string]$Auth = 'subscription', [string]$Launcher = '', $Endpoint = $null)
    if ($script:ClaudeAuthModes -notcontains $Auth) { $Auth = 'subscription' }
    if ($Auth -eq 'endpoint') {
        $e = [ordered]@{}
        $e['credential_mechanism'] = 'endpoint'
        $e['base_url'] = $(if ($Endpoint) { [string]$Endpoint.BaseUrl } else { $null })
        $e['env_key'] = $(if ($Endpoint) { [string]$Endpoint.EnvKey } else { $null })
        $e['plan'] = $(if ($Endpoint -and [string](Get-PropertyValue $Endpoint 'Plan' '')) { [string]$Endpoint.Plan } else { $null })
        return $e
    }
    $c = $null
    if ($script:ClaudeSignInCache.ContainsKey("$Launcher|$Auth")) { $c = $script:ClaudeSignInCache["$Launcher|$Auth"] }
    $o = [ordered]@{}
    $o['credential_mechanism'] = $Auth
    $o['auth_method'] = $(if ($c -and $c.AuthMethod) { $c.AuthMethod } else { $null })
    $o['api_provider'] = $(if ($c -and $c.ApiProvider) { $c.ApiProvider } else { $null })
    return $o
}

# (item 2) Where the engine keeps its transcripts must not lie in the repository under review (the
# strict tree check would fail every run): CLAUDE_CONFIG_DIR, and the projectsDirectory the sign-in
# check read. '' or the refusal.
function Get-ClaudeLaunchProblem {
    param([string]$RepoRoot, [string]$Launcher = '', [string]$Auth = 'subscription')
    if (-not $RepoRoot) { return '' }
    $cfg = [string][Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR')
    if ($cfg.Trim()) { try { if ($null -ne (Get-RepoRelativePath -Root $RepoRoot -Path $cfg.Trim())) { return "CLAUDE_CONFIG_DIR ($($cfg.Trim())) lies inside the repository under review: the engine's transcripts would change the tree; point it elsewhere" } } catch { } }
    $key = "$Launcher|$Auth"
    if ($script:ClaudeSignInCache.ContainsKey($key)) {
        $pd = [string]$script:ClaudeSignInCache[$key].ProjectsDirectory
        if ($pd.Trim()) { try { if ($null -ne (Get-RepoRelativePath -Root $RepoRoot -Path $pd.Trim())) { return "the claude projectsDirectory ($($pd.Trim())) lies inside the repository under review: the engine's transcripts would change the tree" } } catch { } }
    }
    return ''
}

# reviewer.harness of a claude run (item 6): "claude-cli <version>" from the launcher's file
# metadata (the native claude.exe carries it), else `<launcher> --version` in the child environment
# (an npm shim; local, no request spent; 15 s), else "claude-cli (version unknown)". Cached per
# launcher.
$script:ClaudeHarnessCache = @{}
$script:ClaudeVersionRe = '^v?[0-9]+\.[0-9]+[0-9A-Za-z.+_-]{0,48}$'
function Get-ClaudeHarness {
    param([string]$Launcher)
    if (-not $Launcher) { return 'claude-cli (version unknown)' }
    if ($script:ClaudeHarnessCache.ContainsKey($Launcher)) { return $script:ClaudeHarnessCache[$Launcher] }
    $ver = ''
    try { $ver = ([string](Get-Item -LiteralPath $Launcher -ErrorAction Stop).VersionInfo.ProductVersion).Trim() } catch { $ver = '' }
    if ($ver -notmatch $script:ClaudeVersionRe) {
        $ver = ''
        $cap = Invoke-ClaudeProbe -Launcher $Launcher -Arguments '--version' -TimeoutSec 15
        if ($cap.Started -and -not $cap.TimedOut -and $cap.Exit -eq 0) {
            foreach ($tok in @(($cap.Out + "`n" + $cap.Err) -split '\s+')) { if ($tok -match $script:ClaudeVersionRe) { $ver = $tok; break } }
        }
    }
    $h = $(if ($ver) { "claude-cli $($ver -replace '^v', '')" } else { 'claude-cli (version unknown)' })
    $script:ClaudeHarnessCache[$Launcher] = $h
    return $h
}

# (item 1) The reply schema as `claude --json-schema` takes it: its TEXT, whitespace outside strings
# removed (one line; the strings keep theirs). '' when the file cannot be read.
function Get-ClaudeSchemaText {
    param([string]$Path)
    $text = ''
    try { $text = [IO.File]::ReadAllText($Path, $script:Utf8NoBom) } catch { return '' }
    $sb = New-Object System.Text.StringBuilder
    $inStr = $false
    $esc = $false
    foreach ($ch in $text.ToCharArray()) {
        if ($inStr) {
            [void]$sb.Append($ch)
            if ($esc) { $esc = $false } elseif ($ch -eq [char]'\') { $esc = $true } elseif ($ch -eq [char]'"') { $inStr = $false }
            continue
        }
        if ($ch -eq [char]'"') { $inStr = $true; [void]$sb.Append($ch); continue }
        if ([char]::IsWhiteSpace($ch) -or $ch -eq [char]0xFEFF) { continue }
        [void]$sb.Append($ch)
    }
    return $sb.ToString()
}

# (item 1) The argv of one claude turn (after the launcher), from the turn options: print mode, the
# stream-json events, the restricted read-only session (--restricted --strict-mcp-config
# --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk), the model (the
# roster's on a new thread, the RESOLVED id on every later turn - D4), --effort when one is sent (the
# repair sends low), the schema TEXT (--json-schema: structured mode with transport native and every
# repair / denial-retry / continuation turn of such a run), --max-turns with -MaxModelSteps (D8),
# --add-dir for a collab directory, brief or artifact outside the repository, then the session:
# --session-id <the minted uuid> on a new thread (known before the first byte - item 2), --resume
# <thread> to continue one (every secondary turn), --resume <parent> --fork-session to fork. The
# prompt travels on stdin, never in argv.
function Get-ClaudeArgs {
    param($Turn)
    $a = @('-p', '--output-format', 'stream-json', '--verbose', '--restricted', '--strict-mcp-config', '--disable-slash-commands', '--tools', $script:ClaudeToolsArg, '--permission-mode', $script:ClaudePermissionMode, '--model', [string]$Turn.Model)
    if ($null -ne $Turn.Effort -and ([string]$Turn.Effort).Trim()) { $a += @('--effort', [string]$Turn.Effort) }
    if ($Turn.Schema) { $a += @('--json-schema', (Get-ClaudeSchemaText -Path ([string]$Turn.Schema))) }
    if ([int]$Turn.MaxSteps -gt 0) { $a += @('--max-turns', [string][int]$Turn.MaxSteps) }
    foreach ($d in @(Get-PropertyValue $Turn 'AddDirs' @())) { if ($d) { $a += @('--add-dir', [string]$d) } }
    $thread = [string]$Turn.Thread
    if ($thread) {
        $a += @('--resume', $thread)
        if ([string]$Turn.Mode -eq 'fork') { $a += '--fork-session' }
    } else {
        $nt = [string](Get-PropertyValue $Turn 'NewThread' '')
        if ($nt) { $a += @('--session-id', $nt) }
    }
    return , ([string[]]$a)
}

# The stdin of a claude turn: the prompt itself, plain UTF-8 (written without a BOM by the caller).
function ConvertTo-ClaudeStdin {
    param([string]$Prompt)
    return [string]$Prompt
}

# (wave 29) One argument of an engine whose CLI parses its command line by the C runtime rules
# (claude): a bare token when safe, else double-quoted with every quote as \" and the backslashes
# before a quote (and at the end) doubled - read the same by every Windows argv parser (the one-line
# schema text of --json-schema is full of quotes), and safe through a cmd.exe shim as long as the
# value holds no % and no cmd.exe operator outside its quotes.
function ConvertTo-CrtArg {
    param([string]$Value)
    if ($Value -and $Value -match '^[A-Za-z0-9_.\-:\\/=]+$') { return $Value }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $bs = 0
    foreach ($ch in ([string]$Value).ToCharArray()) {
        if ($ch -eq [char]'\') { $bs++; continue }
        if ($ch -eq [char]'"') { [void]$sb.Append('\', 2 * $bs + 1); [void]$sb.Append('"'); $bs = 0; continue }
        if ($bs -gt 0) { [void]$sb.Append('\', $bs); $bs = 0 }
        [void]$sb.Append($ch)
    }
    if ($bs -gt 0) { [void]$sb.Append('\', 2 * $bs) }
    [void]$sb.Append('"')
    return $sb.ToString()
}

# A Unix time (seconds, or milliseconds when it is that large) or an ISO string as a DateTimeOffset
# (UTC), $null when it is neither.
function ConvertFrom-ClaudeResetTime {
    param($Value)
    if ($null -eq $Value) { return $null }
    $n = [double]0
    if (($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) -or ($Value -is [string] -and $Value -match '^[0-9]{9,14}(\.[0-9]+)?$' -and [double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$n))) {
        if (-not ($Value -is [string])) { $n = [double]$Value }
        if ($n -gt 1e12) { $n = $n / 1000 }
        if ($n -lt 1e9 -or $n -gt 1e10) { return $null }
        try { return [DateTimeOffset]::FromUnixTimeSeconds([long][Math]::Floor($n)) } catch { return $null }
    }
    if ($Value -is [string]) {
        $d = [DateTimeOffset]::MinValue
        if ($Value -match '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' -and [DateTimeOffset]::TryParse($Value, $script:Invariant, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$d)) { return $d.ToUniversalTime() }
    }
    if ($Value -is [datetime]) { return ([DateTimeOffset]([datetime]::SpecifyKind($Value, [DateTimeKind]::Utc))) }
    return $null
}

# One claude event stream (stdout of `claude -p --output-format stream-json --verbose`: one JSON
# object per line - obs), parsed tolerantly into the normalized turn record (item 3):
#   InitCount        the `system`/`init` events (one per `claude -p` run); every one is evidence
#   InitThread, InitModel   the FIRST init's session_id and model
#   InitThreads, InitModels, InitModes, InitKeySources   the distinct values over every init
#   InitTools        the union of their tools; InitMcp the names of their MCP servers (any entry
#                    counts); InitCwd the first init's cwd
#   InitLacks        (wave 29b, E14) the capability fields an init event lacks, over every init, in
#                    the order model, permissionMode, tools, mcp_servers: model and permissionMode
#                    absent, null, not a string or blank; tools and mcp_servers absent or not an
#                    array (a missing field is never read as an empty one). A missing apiKeySource
#                    is not listed: it adds nothing to InitKeySources (recorded null - older CLIs)
#   InitKeyLacks     (A4) $true when any init's apiKeySource is absent, null or not a string; the
#                    billing proof of subscription and api-key (Get-ClaudeInitProblem), tolerated
#                    only under auth endpoint
#   ResultCount      number of `result` events (exactly one is a well-formed stream)
#   Malformed        '' or why the stream is malformed: a line that does not parse as a JSON object
#                    (the LAST non-empty line may be partial only with -AllowPartialLast - a killed
#                    turn or a non-zero exit, F10-2), more than one result, a result that is not the
#                    last event, two init events that name different sessions
#   HasResult; Thread (result.session_id); Subtype; IsError; Response (result.result - its text);
#   Error (the result text of a failed result, else its errors[]); HasStructured; StructuredJson
#   (result.structured_output serialized compactly); CostUsd (total_cost_usd - notional on a
#   subscription, kept local); NumTurns; StopReason
#   Usage            { input_tokens (input + cache read + cache creation: the whole prompt, as
#                    codex counts it), cached_input_tokens (cache_read_input_tokens),
#                    cache_creation_input_tokens, output_tokens, reasoning_output_tokens ($null:
#                    not reported), total_tokens } or $null
#   ModelUsage       the keys of result.modelUsage; MainModel the key with the most output tokens
#   AssistantModels  the distinct message.model of the assistant events (<synthetic> left out)
#   Denials          result.permission_denials as { Tool; Target (file_path | path | pattern) };
#                    DenialCount; ToolName / DeniedAction the first denial as "<tool> <target>"
#   RateLimit        the most severe rate_limit_event's info object as the CLI wrote it (D6: recorded
#                    raw); RateLimitStatus; RateLimitRejected (a status that rejects); RateLimitType;
#                    RateLimitReset (DateTimeOffset or $null) - field names read defensively
#   Compactions      the system/compact_boundary events
function Read-ClaudeEvents {
    param([string]$Path, [switch]$AllowPartialLast)
    $r = [pscustomobject]@{
        InitCount = 0; InitThread = ''; InitModel = ''; InitThreads = [string[]]@(); InitModels = [string[]]@(); InitModes = [string[]]@(); InitKeySources = [string[]]@(); InitKeyLacks = $false; InitTools = [string[]]@(); InitMcp = [string[]]@(); InitCwd = ''; InitLacks = [string[]]@()
        ResultCount = 0; Malformed = ''; HasResult = $false; Thread = ''; Subtype = ''; IsError = $false; Response = ''; Error = ''; HasStructured = $false; StructuredJson = ''
        CostUsd = $null; NumTurns = $null; StopReason = ''; Usage = $null; ModelUsage = [string[]]@(); MainModel = ''; AssistantModels = [string[]]@()
        Denials = [object[]]@(); DenialCount = 0; ToolName = ''; DeniedAction = ''
        RateLimit = $null; RateLimitStatus = ''; RateLimitRejected = $false; RateLimitType = ''; RateLimitReset = $null; Compactions = 0
    }
    $text = $(if ($Path) { Read-SharedText -Path $Path } else { '' })
    if (-not $text) { return $r }
    $lines = @($text -split "`r?`n")
    $lastIdx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i].Trim()) { $lastIdx = $i; break } }
    $result = $null
    $resultLine = -1
    $afterResult = $false
    $threads = New-Object System.Collections.Generic.List[string]
    $models = New-Object System.Collections.Generic.List[string]
    $modes = New-Object System.Collections.Generic.List[string]
    $keySources = New-Object System.Collections.Generic.List[string]
    $tools = New-Object System.Collections.Generic.List[string]
    $mcp = New-Object System.Collections.Generic.List[string]
    $amodels = New-Object System.Collections.Generic.List[string]
    $lacks = New-Object System.Collections.Generic.List[string]
    $rlRank = -1
    $addU = { param($list, [string]$v) if (-not $list.Contains($v)) { $list.Add($v) } }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if (-not $t) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $t } catch { $obj = $null }
        if ($null -eq $obj -or -not ($obj -is [System.Management.Automation.PSCustomObject])) {
            if (($i -ne $lastIdx -or -not $AllowPartialLast) -and -not $r.Malformed) { $r.Malformed = "line $($i + 1) is not a JSON object" }
            continue
        }
        if ($null -ne $result) { $afterResult = $true }
        $type = [string](Get-PropertyValue $obj 'type' '')
        $sub = [string](Get-PropertyValue $obj 'subtype' '')
        if ($type -eq 'system' -and $sub -eq 'init') {
            $r.InitCount++
            $sid = [string](Get-PropertyValue $obj 'session_id' '')
            $mdl = [string](Get-PropertyValue $obj 'model' '')
            if ($r.InitCount -eq 1) { $r.InitThread = $sid; $r.InitModel = $mdl; $r.InitCwd = [string](Get-PropertyValue $obj 'cwd' '') }
            & $addU $threads $sid
            & $addU $models $mdl
            & $addU $modes ([string](Get-PropertyValue $obj 'permissionMode' ''))
            # (wave 29b, E14) the capability fields must be THERE: a string model and permission mode,
            # an array of tools and of MCP servers - an absent field proves nothing
            foreach ($sf in @('model', 'permissionMode')) {
                $sp = $obj.PSObject.Properties[$sf]
                if ($null -eq $sp -or -not ($sp.Value -is [string]) -or -not ([string]$sp.Value).Trim()) { & $addU $lacks $sf }
            }
            foreach ($af in @('tools', 'mcp_servers')) {
                $ap = $obj.PSObject.Properties[$af]
                if ($null -eq $ap -or $null -eq $ap.Value -or -not ($ap.Value -is [array])) { & $addU $lacks $af }
            }
            # (E14) apiKeySource absent (older CLIs): nothing recorded - engine_run.api_key_source null
            # (A4) ... but the billing proof of subscription and api-key: InitKeyLacks (absent, null or not a string)
            $ks = Get-PropertyValue $obj 'apiKeySource' $null
            if ($ks -is [string]) { & $addU $keySources $ks } else { $r.InitKeyLacks = $true }
            foreach ($tn in @(Get-PropertyValue $obj 'tools' @())) { if ($null -ne $tn) { & $addU $tools ([string]$tn) } }
            foreach ($ms in @(Get-PropertyValue $obj 'mcp_servers' @())) {
                if ($null -eq $ms) { continue }
                $mn = $(if (Test-IsJsonObject $ms) { [string](Get-PropertyValue $ms 'name' '') } else { [string]$ms })
                & $addU $mcp $(if ($mn) { $mn } else { '(unnamed)' })
            }
        } elseif ($type -eq 'system' -and $sub -eq 'compact_boundary') {
            $r.Compactions++
        } elseif ($type -eq 'assistant') {
            $msg = Get-PropertyValue $obj 'message' $null
            $am = [string](Get-PropertyValue $msg 'model' '')
            if ($am -and $am -cne '<synthetic>') { & $addU $amodels $am }
        } elseif ($type -eq 'rate_limit_event') {
            $info = Get-PropertyValue $obj 'rate_limit_info' $null
            if (-not (Test-IsJsonObject $info)) { $info = $obj }
            $st = [string](Get-PropertyValue $info 'status' '')
            $rank = $(if ($st -match '(?i)reject') { 2 } elseif ($st -match '(?i)warn') { 1 } else { 0 })
            if ($rank -ge $rlRank) {
                $rlRank = $rank
                $r.RateLimit = $info
                $r.RateLimitStatus = ConvertTo-ClaudeToken $st
                $r.RateLimitType = ConvertTo-ClaudeToken (Get-PropertyValue $info 'rateLimitType' (Get-PropertyValue $info 'rate_limit_type' $null))
                $reset = Get-PropertyValue $info 'resetsAt' $null
                if ($null -eq $reset) { $reset = Get-PropertyValue $info 'resets_at' $null }
                if ($null -eq $reset) { $reset = Get-PropertyValue $info 'reset_at' $null }
                $r.RateLimitReset = ConvertFrom-ClaudeResetTime $reset
            }
            if ($rank -eq 2) { $r.RateLimitRejected = $true }
        } elseif ($type -eq 'result') {
            $r.ResultCount++
            $result = $obj
            $resultLine = $i
            $afterResult = $false
        }
    }
    $r.InitThreads = [string[]]@($threads | Where-Object { $_ })
    $r.InitModels = [string[]]@($models | Where-Object { $_ })
    $r.InitModes = [string[]]$modes.ToArray()
    $r.InitKeySources = [string[]]$keySources.ToArray()
    $r.InitTools = [string[]]$tools.ToArray()
    $r.InitMcp = [string[]]$mcp.ToArray()
    $r.AssistantModels = [string[]]$amodels.ToArray()
    $r.InitLacks = [string[]]@(@('model', 'permissionMode', 'tools', 'mcp_servers') | Where-Object { $lacks.Contains($_) })
    if (-not $r.Malformed -and $r.ResultCount -gt 1) { $r.Malformed = "$($r.ResultCount) result events (exactly one expected)" }
    if (-not $r.Malformed -and $afterResult) { $r.Malformed = "an event follows the result event (line $($resultLine + 1)); the result must be the last" }
    if (-not $r.Malformed -and @($r.InitThreads).Count -gt 1) { $r.Malformed = "the init events name $(@($r.InitThreads).Count) sessions ($(@($r.InitThreads) -join ', '))" }
    if ($null -ne $result) {
        $r.HasResult = $true
        $r.Thread = [string](Get-PropertyValue $result 'session_id' '')
        $r.Subtype = [string](Get-PropertyValue $result 'subtype' '')
        $r.IsError = ((Get-PropertyValue $result 'is_error' $false) -eq $true)
        $rt = Get-PropertyValue $result 'result' ''
        $r.Response = $(if ($rt -is [string]) { $rt } else { '' })
        $r.StopReason = [string](Get-PropertyValue $result 'stop_reason' '')
        $nt = Get-PropertyValue $result 'num_turns' $null
        $ntv = [long]0
        if ($null -ne $nt -and [long]::TryParse([string]$nt, [ref]$ntv)) { $r.NumTurns = $ntv }
        $cost = Get-PropertyValue $result 'total_cost_usd' $null
        $cv = [double]0
        if ($null -ne $cost -and [double]::TryParse([string]$cost, [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$cv)) { $r.CostUsd = $cv }
        if ($r.IsError -or ($r.Subtype -and $r.Subtype -ne 'success')) {
            $r.Error = $r.Response
            if (-not $r.Error.Trim()) {
                $errs = @(@(Get-PropertyValue $result 'errors' @()) | Where-Object { $null -ne $_ } | ForEach-Object { if ($_ -is [string]) { $_ } else { ConvertTo-Json -InputObject $_ -Compress -Depth 6 } })
                $r.Error = ($errs -join '; ')
            }
        }
        $so = Get-PropertyValue $result 'structured_output' $null
        if ($null -ne $so -and $so -is [System.Management.Automation.PSCustomObject]) {
            $r.HasStructured = $true
            $r.StructuredJson = ConvertTo-Json -InputObject $so -Compress -Depth 30
        }
        $u = Get-PropertyValue $result 'usage' $null
        if (Test-IsJsonObject $u) {
            $num = { param($name) $v = Get-PropertyValue $u $name $null; $n = [long]0; if ($null -ne $v -and [long]::TryParse([string]$v, [ref]$n)) { $n } else { $null } }
            $in = & $num 'input_tokens'
            $cr = & $num 'cache_read_input_tokens'
            $cc = & $num 'cache_creation_input_tokens'
            $ou = & $num 'output_tokens'
            $inAll = $null
            if ($null -ne $in) { $inAll = [long]$in + $(if ($null -ne $cr) { [long]$cr } else { 0 }) + $(if ($null -ne $cc) { [long]$cc } else { 0 }) }
            $r.Usage = [pscustomobject]([ordered]@{ input_tokens = $inAll; cached_input_tokens = $cr; cache_creation_input_tokens = $cc; output_tokens = $ou; reasoning_output_tokens = $null; total_tokens = $(if ($null -ne $inAll -and $null -ne $ou) { [long]$inAll + [long]$ou } else { $null }) })
        }
        $mu = Get-PropertyValue $result 'modelUsage' $null
        if (Test-IsJsonObject $mu) {
            $keys = New-Object System.Collections.Generic.List[string]
            $best = -1.0
            foreach ($p in $mu.PSObject.Properties) {
                $keys.Add([string]$p.Name)
                $outT = [double]0
                [void][double]::TryParse([string](Get-PropertyValue $p.Value 'outputTokens' 0), [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$outT)
                if ($outT -gt $best) { $best = $outT; $r.MainModel = [string]$p.Name }
            }
            $r.ModelUsage = [string[]]$keys.ToArray()
        }
        $den = New-Object System.Collections.Generic.List[object]
        foreach ($d in @(Get-PropertyValue $result 'permission_denials' @())) {
            if (-not (Test-IsJsonObject $d)) { continue }
            $tin = Get-PropertyValue $d 'tool_input' $null
            $target = ''
            foreach ($f in @('file_path', 'path', 'pattern', 'notebook_path', 'url', 'command')) { $tv = Get-PropertyValue $tin $f $null; if ($tv -is [string] -and $tv) { $target = ConvertTo-OneLine $tv; break } }
            if ($target.Length -gt 200) { $target = $target.Substring(0, 200) }
            $den.Add([pscustomobject]@{ Tool = [string](Get-PropertyValue $d 'tool_name' ''); Target = $target })
        }
        $r.Denials = [object[]]$den.ToArray()
        $r.DenialCount = $den.Count
        if ($den.Count -gt 0) {
            $r.DeniedAction = ("$($den[0].Tool) $($den[0].Target)").Trim()
            $r.ToolName = $r.DeniedAction
        }
    }
    return $r
}

# (item 4, D1 / F09-3) What the init events of a turn prove - evidence first: every init must list
# no tool outside Read, Grep, Glob, StructuredOutput, no MCP server and the permission mode dontAsk
# (else class permission); and (item 6, F09-1) the credential the CLI took must be the roster's:
# subscription - apiKeySource none; api-key - ANTHROPIC_API_KEY (else class auth: the turn billed
# another way); (wave 29b, E3) endpoint - apiKeySource is none on this route too (P8, P10), so it
# proves nothing: it is recorded raw, and only ANTHROPIC_API_KEY fails the turn (class auth: a
# competing credential reached the child) - the proof of the route is the init model (D4, -Exact)
# and child_env_allowed. (wave 29b, E14) First of all every init must CARRY the capability fields -
# model, permissionMode, tools (an array), mcp_servers (an array): one missing, null or of another
# type fails the turn with class capability ("init event lacks <field> - the CLI's schema changed;
# pin the version"); a missing apiKeySource fails (class auth) under subscription and api-key, is recorded null under endpoint (A4). (E12) The caller runs this
# on EVERY turn's events, a turn the bridge killed on its timeout or stall included. { Problem (''
# when proven or when there is no init - the caller decides); Class }.
function Get-ClaudeInitProblem {
    param($Events, [string]$Auth = 'subscription')
    $r = [pscustomobject]@{ Problem = ''; Class = '' }
    if ([int]$Events.InitCount -le 0) { return $r }
    $lack = @(@(Get-PropertyValue $Events 'InitLacks' @()) | Where-Object { $_ }) | Select-Object -First 1
    if ($null -ne $lack) { $r.Problem = "init event lacks $lack - the CLI's schema changed; pin the version"; $r.Class = 'capability'; return $r }
    $extra = @(@($Events.InitTools) | Where-Object { $script:ClaudeTools -cnotcontains [string]$_ })
    if ($extra.Count -gt 0) { $r.Problem = "the init event lists tools outside $($script:ClaudeTools -join ', '): $($extra -join ', ') - the turn's read-only capability is not proven"; $r.Class = 'permission'; return $r }
    if (@($Events.InitMcp).Count -gt 0) { $r.Problem = "the init event lists MCP server(s) ($(@($Events.InitMcp) -join ', ')) - a reviewer runs without any"; $r.Class = 'permission'; return $r }
    $badMode = @(@($Events.InitModes) | Where-Object { [string]$_ -cne $script:ClaudePermissionMode }) | Select-Object -First 1
    if ($null -ne $badMode) { $r.Problem = "the init event names the permission mode '$(ConvertTo-ClaudeToken ([string]$badMode))', not $($script:ClaudePermissionMode)"; $r.Class = 'permission'; return $r }
    if ($Auth -eq 'endpoint') {
        if (@(@($Events.InitKeySources) | Where-Object { [string]$_ -ceq 'ANTHROPIC_API_KEY' }).Count -gt 0) {
            $r.Problem = 'the init event names apiKeySource ANTHROPIC_API_KEY on an endpoint route - a competing credential reached the child (auth endpoint sends ANTHROPIC_AUTH_TOKEN only)'
            $r.Class = 'auth'
        }
        return $r
    }
    if ([bool](Get-PropertyValue $Events 'InitKeyLacks' $false)) {
        $r.Problem = 'init event lacks apiKeySource - the billing proof of this auth mode; pin the CLI version'
        $r.Class = 'auth'
        return $r
    }
    $want = $(if ($Auth -eq 'api-key') { 'ANTHROPIC_API_KEY' } else { 'none' })
    $badKey = @(@($Events.InitKeySources) | Where-Object { [string]$_ -cne $want }) | Select-Object -First 1
    if ($null -ne $badKey) {
        $shown = $(if ([string]$badKey) { ConvertTo-ClaudeToken ([string]$badKey) } else { '(none named)' })
        $r.Problem = "the init event names apiKeySource $shown, not $want - the turn did not bill $(if ($Auth -eq 'api-key') { 'the API key' } else { 'the claude.ai subscription' }) the roster names (auth $Auth)"
        $r.Class = 'auth'
        return $r
    }
    return $r
}

# (wave 29b, E12, E13) What a turn's events prove about its MODEL against the pin ($Pinned: the id
# or alias the turn asked for; -Exact: an endpoint route, equality only): every init event's model
# must be the pinned one (D4: an alias takes an id of its family) - "model drift: asked <p>, served
# <m>" -, and (E13) every assistant event's message.model must be the init's id after the [1m]
# strip - "a different model authored an assistant message: <id>" (the largest-output heuristic of
# modelUsage does not prove who answered). Class capability. { Problem ('' when proven or when
# there is no init model); Class }. Run on every turn, a killed one included (E12).
function Get-ClaudeServedModelProblem {
    param($Events, [string]$Pinned = '', [switch]$Exact)
    $r = [pscustomobject]@{ Problem = ''; Class = '' }
    $served = [string]$Events.InitModel
    if (-not $served) { return $r }
    if ($Pinned) {
        $drift = @(@($Events.InitModels) | Where-Object { -not (Test-ClaudeModelMatch -Pinned $Pinned -Served ([string]$_) -Exact:$Exact) }) | Select-Object -First 1
        if ($null -ne $drift) { $r.Problem = "model drift: asked $Pinned, served $drift"; $r.Class = 'capability'; return $r }
    }
    $foreign = @(@($Events.AssistantModels) | Where-Object { -not (Test-ClaudeModelMatch -Pinned $served -Served ([string]$_) -Exact) }) | Select-Object -First 1
    if ($null -ne $foreign) { $r.Problem = "a different model authored an assistant message: $foreign"; $r.Class = 'capability'; return $r }
    return $r
}

# (item 3, D6) The wording of a usage limit and of a missing sign-in in claude's result text or
# stderr ("Not logged in <middle dot> Please run /login" - obs; "... usage limit reached|<unix time>", "You've
# hit your limit <middle dot> resets ...") - field names and wordings beyond the observed ones are assumed.
# (wave 29b, E4) an endpoint route's 401/403 (P11: "Failed to authenticate. API Error: 401 ...") is
# class auth; a 429 is class quota by its status (\b429\b) whatever its wording - extend the lists
# after the first sightings of each provider's texts.
$script:ClaudeQuotaRe = '(?i)usage limit|limit reached|hit your (?:usage |session |weekly )?limit|rate[ _]limit|weekly limit|session limit|quota|too many requests|\b429\b|credit balance is too low|overage'
$script:ClaudeAuthRe = '(?i)not logged in|please run /login|invalid api key|oauth token (?:has )?(?:expired|revoked)|authentication[ _]error|failed to authenticate|api error: 40[13]\b|\b401\b|unauthori[sz]ed'

# The failure rules of one claude turn (the main turn, a denial retry, a format repair, a timeout
# continuation) - the adapter contract of agy and muse plus -Turn (the turn's options: Mode, Thread,
# NewThread, Model, Auth) and the fields ModelResolved, OtherModels, ProofProblem and QuotaMark:
#   $Pre             a failure the bridge already knows (timeout, could not start) - it wins over
#                    everything but the proof of the turn's init and model (wave 29b, E12): a killed
#                    turn whose init or model proof fails is FAILED with that problem and its class
#                    ("<problem> (the turn was also stopped: <Pre>)"), ProofProblem set - the caller
#                    runs no continuation on that session; otherwise a rejecting rate_limit_event
#                    before the kill makes the class quota (no continuation)
#   init proof       (item 4, item 6; evidence first, whatever the exit code) (E14) the capability
#                    fields present -> else class capability; tools, MCP servers, permission mode ->
#                    class permission; apiKeySource -> class auth; ProofProblem
#   exit != 0        failed: claude exit <n> - <result text | stderr>; quota or auth wording -> that
#                    class
#   malformed        class transport; no init event (exit 0) -> class permission (not proven); no
#                    result -> failed (the init's session id is a candidate)
#   the session      init and result must agree; a new thread must come back on the minted id, a
#                    resume (every secondary turn) on its thread, a fork on a NEW uuid (not its
#                    parent) - else class unknown, the id a candidate only
#   is_error / subtype other than success -> failed: claude <subtype> - <text>; class quota (a
#                    rejecting rate_limit_event or the limit wording - D6), auth (its wording),
#                    capability (error_max_turns - D8 -, error_max_structured_output_retries)
#   the model        (D4) the init model must be the pinned one (an alias: an id of its family);
#                    (E13) every assistant event's message.model must be the init's id after the
#                    [1m] strip ("a different model authored an assistant message: <id>");
#                    modelUsage's main model must be it too - else class capability, ProofProblem; a
#                    modelUsage key that authored no assistant message is recorded (OtherModels) and
#                    warned about (a helper model of the CLI)
#   empty reply      with permission denials: failed, class permission, DeniedEmpty (the denial
#                    retry); otherwise failed: empty reply
#   usable           denials beside the reply (the tools and paths), a warning rate-limit status and
#                    other models become Warnings; (E15) a REJECTING rate_limit_event during a turn
#                    whose result succeeded keeps the reply usable: the warning "a rate limit
#                    rejected a request during the turn: <the event's info, raw>" and QuotaMark (the
#                    quota text a failed turn would carry - the caller marks the route's health with
#                    it, New-ProviderFailure -Class quota)
function Get-ClaudeTurnOutcome {
    param($Events, [int]$ExitCode, [string]$StderrText = '', [string]$Pre = '', [string]$ExpectThread = '', [string]$ExpectModel = '', $Turn = $null)
    $o = [pscustomobject]@{ Ok = $false; Outcome = ''; Class = ''; Texts = [string[]]@(); Thread = ''; ThreadCandidate = ''; Reply = ''; Structured = $false; DeniedEmpty = $false; DenialLine = ''; Permission = ''; NotFound = ''; Warnings = [string[]]@(); ModelResolved = ''; OtherModels = [string[]]@(); ProofProblem = ''; QuotaMark = '' }
    $lines = @(([string]$StderrText) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $stderrTail = $(if ($lines.Count -gt 0) { [string]$lines[-1] } else { '' })
    $mode = [string](Get-PropertyValue $Turn 'Mode' '')
    $turnThread = [string](Get-PropertyValue $Turn 'Thread' '')
    $newThread = [string](Get-PropertyValue $Turn 'NewThread' '')
    $auth = [string](Get-PropertyValue $Turn 'Auth' '')
    if ($script:ClaudeAuthModes -notcontains $auth) { $auth = 'subscription' }
    # (wave 29b, E2) an endpoint route's model is proven by equality (no alias family)
    $exact = ($auth -eq 'endpoint')
    $pinned = $(if ($ExpectModel) { $ExpectModel } else { [string](Get-PropertyValue $Turn 'Model' '') })
    $forkOf = $(if ($mode -eq 'fork' -and $turnThread) { $turnThread } else { '' })
    $expect = $ExpectThread
    if (-not $expect -and $turnThread -and -not $forkOf) { $expect = $turnThread }
    if (-not $expect -and -not $turnThread -and $newThread) { $expect = $newThread }
    $resId = [string]$Events.Thread
    $initId = [string]$Events.InitThread
    $okId = { param([string]$Id) [bool]($Id -match $script:UuidRe -and (-not $expect -or $Id -eq $expect) -and (-not $forkOf -or $Id -ne $forkOf)) }
    $candidateOf = { param([string]$Id) if ($Id -match $script:UuidRe -and (-not $forkOf -or $Id -ne $forkOf)) { $Id } else { '' } }
    $o.Structured = [bool]$Events.HasStructured
    $o.Reply = $(if ($Events.HasStructured) { [string]$Events.StructuredJson } elseif (-not $Events.IsError) { [string]$Events.Response } else { '' })
    # (D6) the quota evidence: a rejecting rate_limit_event, else the limit wording of the result's
    # text or stderr; its reset time (the event's, else a "|<unix time>" in the text) as ISO in the text
    $errText = [string]$Events.Error
    $quotaText = ''
    $resetAt = $Events.RateLimitReset
    if ($Events.RateLimitRejected) {
        $quotaText = "usage limit reached (claude rate_limit_event $($Events.RateLimitStatus)$(if ($Events.RateLimitType) { ", $($Events.RateLimitType)" }))"
    } elseif ($errText -and $errText -match $script:ClaudeQuotaRe) {
        $quotaText = "usage limit: $(ConvertTo-OneLine $errText)"
    } else {
        $ql = @($lines | Where-Object { $_ -match $script:ClaudeQuotaRe }) | Select-Object -First 1
        if ($ql) { $quotaText = "usage limit: $(ConvertTo-OneLine $ql)" }
    }
    if ($quotaText -and $null -eq $resetAt -and $errText -match '\|(?<t>[0-9]{10,13})\b') { $resetAt = ConvertFrom-ClaudeResetTime $Matches['t'] }
    if ($quotaText -and $null -ne $resetAt) { $quotaText += "; resets at $(([DateTimeOffset]$resetAt).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', $script:Invariant))" }
    $authText = ''
    if (-not $quotaText) {
        if ($errText -and $errText -match $script:ClaudeAuthRe) { $authText = ConvertTo-OneLine $errText }
        else { $al = @($lines | Where-Object { $_ -match $script:ClaudeAuthRe }) | Select-Object -First 1; if ($al) { $authText = ConvertTo-OneLine $al } }
    }
    $evidenceClass = $(if ($quotaText) { 'quota' } elseif ($authText) { 'auth' } else { '' })
    $fail = {
        param([string]$Why, [string]$Class = '', [string[]]$Texts = @())
        $o.Ok = $false
        $o.Outcome = "failed: $Why"
        $o.Class = $Class
        $o.Texts = [string[]]@(@($Texts) + @($Why) | Where-Object { $_ })
    }
    $detail = $(if ($errText.Trim()) { $errText } else { $stderrTail })
    if ($Pre) {
        # (wave 29b, E12) a killed turn's init and model are judged too: a prohibited tool, an MCP
        # server, another permission mode, apiKeySource, a missing capability field, another model -
        # that problem is the reason (the stop is said after it), and no continuation may resume the
        # session (ProofProblem); the salvage of the turn is still kept by the caller
        $proofPre = Get-ClaudeInitProblem -Events $Events -Auth $auth
        if (-not $proofPre.Problem) { $proofPre = Get-ClaudeServedModelProblem -Events $Events -Pinned $pinned -Exact:$exact }
        if ($proofPre.Problem) {
            $stopped = ConvertTo-OneLine ($Pre -replace '^failed:\s*', '')
            & $fail "$($proofPre.Problem) (the turn was also stopped: $stopped)" $proofPre.Class @($quotaText, $errText, $stderrTail)
            $o.ProofProblem = $proofPre.Problem
            $o.ThreadCandidate = & $candidateOf $(if ($resId) { $resId } else { $initId })
            return $o
        }
        $o.Outcome = $Pre
        $o.Class = $(if ($quotaText) { 'quota' } else { '' })
        $o.Texts = [string[]]@(@($quotaText, $errText, $stderrTail, ($Pre -replace '^failed:\s*', '')) | Where-Object { $_ })
        $o.ThreadCandidate = & $candidateOf $(if ($resId) { $resId } else { $initId })
        if ($o.ThreadCandidate -and $expect -and $o.ThreadCandidate -ne $expect) { $o.ThreadCandidate = '' }
        # (D4) a killed turn's init already resolved the model: the continuation sends that id
        $servedPre = [string]$Events.InitModel
        if ($servedPre -and (-not $pinned -or (Test-ClaudeModelMatch -Pinned $pinned -Served $servedPre -Exact:$exact))) {
            $o.ModelResolved = $servedPre
            if ($pinned -match '(?i)\[1m\]$' -and $servedPre -notmatch '(?i)\[1m\]$') { $o.ModelResolved += '[1m]' }
        }
        return $o
    }
    $proof = Get-ClaudeInitProblem -Events $Events -Auth $auth
    if ($proof.Problem) {
        & $fail $proof.Problem $proof.Class
        $o.ProofProblem = $proof.Problem
        $o.ThreadCandidate = & $candidateOf $(if ($resId) { $resId } else { $initId })
        return $o
    }
    if ($ExitCode -ne 0) {
        & $fail "claude exit $ExitCode$(if ($detail) { " - $(ConvertTo-OneLine $detail)" })" $evidenceClass @($quotaText, $authText, $errText, $stderrTail)
        if (& $okId $resId) { $o.Thread = $resId } else { $o.ThreadCandidate = & $candidateOf $(if ($resId) { $resId } else { $initId }) }
        return $o
    }
    if ($Events.Malformed) {
        & $fail "malformed event stream: $($Events.Malformed)" 'transport'
        $o.ThreadCandidate = & $candidateOf $initId
        return $o
    }
    if ([int]$Events.InitCount -le 0) {
        & $fail "the claude event stream has no init event - the turn's tools, MCP servers and permission mode are not proven" 'permission'
        return $o
    }
    if (-not $Events.HasResult) {
        & $fail "no result event in the claude event stream$(if ($stderrTail) { " - $(ConvertTo-OneLine $stderrTail)" })" $evidenceClass @($quotaText, $authText, $stderrTail)
        $o.ThreadCandidate = & $candidateOf $initId
        return $o
    }
    if ($initId -and $resId -and $initId -ne $resId) {
        & $fail "session id mismatch: init $initId, result $resId" 'unknown'
        $o.ThreadCandidate = & $candidateOf $resId
        return $o
    }
    if ($expect -and $resId -ne $expect) {
        $why = $(if ($turnThread) { "parent session $expect not found, claude answered on $(if ($resId) { $resId } else { 'no session' })" } else { "the new session is $(if ($resId) { $resId } else { '(none)' }), not the minted $expect" })
        & $fail $why 'unknown'
        $o.ThreadCandidate = & $candidateOf $resId
        return $o
    }
    if ($forkOf -and $resId -eq $forkOf) {
        & $fail "the fork came back on its parent session $forkOf (--fork-session started no new session)" 'unknown'
        return $o
    }
    if (-not ($resId -match $script:UuidRe)) {
        & $fail "the result's session_id '$resId' is not a uuid" 'unknown'
        return $o
    }
    if ($Events.IsError -or $Events.Subtype -ne 'success') {
        $st = $(if ($Events.Subtype) { $Events.Subtype } else { '(none)' })
        $cls = $evidenceClass
        if (-not $cls -and $st -eq 'error_max_turns') { $cls = 'capability' }
        if (-not $cls -and $st -eq 'error_max_structured_output_retries') { $cls = 'capability' }
        $what = $(if ($st -eq 'error_max_turns') { 'max turns reached (--max-turns)' } elseif ($st -eq 'error_max_structured_output_retries') { 'no reply satisfied the schema (structured output retries exhausted)' } else { '' })
        & $fail "claude $st$(if ($what) { " - $what" })$(if ($detail) { " - $(ConvertTo-OneLine $detail)" })" $cls @($quotaText, $authText, $errText, $stderrTail)
        $o.Thread = $resId
        return $o
    }
    # (D4) one resolved model per thread, proven per turn
    $served = [string]$Events.InitModel
    if (-not $served) {
        & $fail "the init event names no model (asked $pinned)" 'unknown'
        $o.ThreadCandidate = $resId
        return $o
    }
    # (D4) the init model against the pin; (wave 29b, E13) every assistant message by the init's id
    $modelProof = Get-ClaudeServedModelProblem -Events $Events -Pinned $pinned -Exact:$exact
    if ($modelProof.Problem) {
        & $fail $modelProof.Problem $modelProof.Class
        $o.ProofProblem = $modelProof.Problem
        $o.ThreadCandidate = $resId
        return $o
    }
    if (@($Events.ModelUsage).Count -gt 0 -and $Events.MainModel -and -not (Test-ClaudeModelMatch -Pinned $served -Served ([string]$Events.MainModel) -Exact:$exact)) {
        & $fail "model drift: the init event names $served, the result's modelUsage names $($Events.MainModel) as the main model" 'capability'
        $o.ProofProblem = [string]$o.Texts[-1]
        $o.ThreadCandidate = $resId
        return $o
    }
    $resolved = $served
    if ($pinned -match '(?i)\[1m\]$' -and $resolved -notmatch '(?i)\[1m\]$') { $resolved += '[1m]' }
    $o.ModelResolved = $resolved
    $o.OtherModels = [string[]]@(@(@($Events.ModelUsage) + @($Events.AssistantModels)) | Where-Object { $_ -and -not (Test-ClaudeModelMatch -Pinned $served -Served ([string]$_) -Exact:$exact) } | Select-Object -Unique)
    $o.Thread = $resId
    $denialList = (@($Events.Denials | Select-Object -First 5 | ForEach-Object { ("$($_.Tool) $($_.Target)").Trim() }) -join '; ')
    if ([int]$Events.DenialCount -gt 0) { $o.DenialLine = "$($Events.DenialCount) tool call(s) denied under --permission-mode dontAsk: $denialList" }
    if (-not $o.Reply.Trim()) {
        if ([int]$Events.DenialCount -gt 0) {
            & $fail "no reply - $($o.DenialLine)" 'permission' @($o.DenialLine)
            $o.DeniedEmpty = $true
        } else {
            & $fail 'empty reply' ''
        }
        return $o
    }
    $o.Ok = $true
    $o.Outcome = 'usable reply'
    $w = New-Object System.Collections.Generic.List[string]
    if ([int]$Events.DenialCount -gt 0) { $w.Add("permission denials beside the reply: $($o.DenialLine)") }
    # (wave 29b, E15) a rejecting rate_limit_event survives the successful result: the reply stays,
    # the event is said raw, and the quota text a failed turn would carry marks the route (QuotaMark)
    if ($Events.RateLimitRejected) {
        $rawRl = $(try { ConvertTo-Json -InputObject $Events.RateLimit -Compress -Depth 6 } catch { [string]$Events.RateLimitStatus })
        $w.Add("a rate limit rejected a request during the turn: $rawRl")
        $o.QuotaMark = $quotaText
    }
    if ($Events.RateLimitStatus -and $Events.RateLimitStatus -match '(?i)warn') { $w.Add("claude rate limit status $($Events.RateLimitStatus)$(if ($Events.RateLimitType) { " ($($Events.RateLimitType))" })$(if ($null -ne $Events.RateLimitReset) { "; resets at $(([DateTimeOffset]$Events.RateLimitReset).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', $script:Invariant))" })") }
    if (@($o.OtherModels).Count -gt 0) { $w.Add("other models in the turn beside $($served): $(@($o.OtherModels) -join ', ') (engine_run.other_models; a helper model of the CLI?)") }
    foreach ($wl in @($lines | Where-Object { $_ -match '(?i)^warning:' })) { $w.Add((ConvertTo-OneLine $wl)) }
    $o.Warnings = [string[]]$w.ToArray()
    return $o
}

# (item 7) claude stream-json: the assistant events' text blocks (agent messages) and thinking blocks
# (reasoning; empty when the CLI omits the thinking text) in stream order, the result's text when
# no text block came; a tool_use -> "<tool>: <file_path | path | pattern>", once per call id.
function Read-ClaudeSalvage {
    param([string]$Path)
    $items = New-Object System.Collections.Generic.List[object]
    $toolMap = [ordered]@{}
    $text = $(if ($Path) { Read-SharedText -Path $Path } else { '' })
    if (-not $text) { return (New-TurnSalvage -Items $items -ToolMap $toolMap) }
    $response = ''
    $sawText = $false
    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $t } catch { continue }
        $type = [string](Get-PropertyValue $obj 'type' '')
        if ($type -eq 'result') {
            $rt = Get-PropertyValue $obj 'result' ''
            if ($rt -is [string]) { $response = $rt }
            continue
        }
        if ($type -ne 'assistant') { continue }
        $msg = Get-PropertyValue $obj 'message' $null
        foreach ($b in @(Get-PropertyValue $msg 'content' @())) {
            if (-not (Test-IsJsonObject $b)) { continue }
            $bt = [string](Get-PropertyValue $b 'type' '')
            if ($bt -eq 'text') {
                $tx = [string](Get-PropertyValue $b 'text' '')
                if ($tx.Trim()) { $items.Add([pscustomobject]@{ Kind = 'message'; Text = $tx }); $sawText = $true }
            } elseif ($bt -eq 'thinking') {
                $tx = [string](Get-PropertyValue $b 'thinking' '')
                if ($tx.Trim()) { $items.Add([pscustomobject]@{ Kind = 'reasoning'; Text = $tx }) }
            } elseif ($bt -eq 'tool_use') {
                $id = [string](Get-PropertyValue $b 'id' '')
                if (-not $id) { $id = "#$($toolMap.Count)" }
                $name = [string](Get-PropertyValue $b 'name' '')
                $in = Get-PropertyValue $b 'input' $null
                $target = ''
                foreach ($f in @('file_path', 'path', 'pattern')) { $tv = Get-PropertyValue $in $f $null; if ($tv -is [string] -and $tv) { $target = ConvertTo-OneLine $tv; break } }
                if (-not $toolMap.Contains($id)) { $toolMap[$id] = $(if ($target) { "$($name): $target" } else { $name }) }
            }
        }
    }
    if (-not $sawText -and $response.Trim()) { $items.Add([pscustomobject]@{ Kind = 'message'; Text = $response }) }
    return (New-TurnSalvage -Items $items -ToolMap $toolMap)
}

# ---- salvage (wave 24, T1): what a turn the bridge killed on its timeout had produced

# The salvage of one turn's event stream: { Items (object[] of { Kind 'message' | 'reasoning';
# Text }, in stream order); Tools (string[]: the tool calls made, in order - a name, and for a
# shell command the command line) }. Nothing is judged: a partial line, an unknown event, a
# missing field are skipped. Read-TurnSalvage picks the engine's reader (codex: its --json
# items; agy: stream-json step updates; muse: MSP records - the adapter's Salvage).
function New-TurnSalvage {
    param([System.Collections.Generic.List[object]]$Items, $ToolMap)
    $tools = New-Object System.Collections.Generic.List[string]
    if ($null -ne $ToolMap) { foreach ($k in @($ToolMap.Keys)) { $tools.Add([string]$ToolMap[$k]) } }
    $it = @()
    if ($null -ne $Items) { $it = $Items.ToArray() }
    return [pscustomobject]@{ Items = [object[]]$it; Tools = [string[]]$tools.ToArray() }
}

# codex --json: item.completed agent_message / reasoning -> text; command_execution -> "shell:
# <command>", web_search -> "web_search: <query>", mcp_tool_call -> "mcp: <server>/<tool>",
# collab_tool_call -> "collab: <tool>", any other item type (not error) -> its type; a tool
# item is listed once (item.started, completed by item.completed - a command still running at
# the kill is listed too). (wave 24b, F07-2) An item without an id is paired too: its
# item.started opens it under a key of its own; an id-less item.completed of the same type closes
# the open one of the same name (the same command line), else the oldest open one; with nothing
# open it is a tool call of its own.
function Read-CodexSalvage {
    param([string]$Path)
    $items = New-Object System.Collections.Generic.List[object]
    $toolMap = [ordered]@{}
    $text = $(if ($Path) { Read-SharedText -Path $Path } else { '' })
    if (-not $text) { return (New-TurnSalvage -Items $items -ToolMap $toolMap) }
    $k = 0
    # item type -> the keys of its id-less items started and not completed yet, oldest first
    $openIdless = @{}
    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $t } catch { continue }
        $type = [string](Get-PropertyValue $obj 'type' '')
        if ($type -ne 'item.started' -and $type -ne 'item.completed') { continue }
        $it = Get-PropertyValue $obj 'item' $null
        if (-not (Test-IsJsonObject $it)) { continue }
        $itype = [string](Get-PropertyValue $it 'type' '')
        $k++
        $id = [string](Get-PropertyValue $it 'id' '')
        if ($itype -eq 'agent_message' -or $itype -eq 'reasoning') {
            $tx = [string](Get-PropertyValue $it 'text' '')
            if ($type -eq 'item.completed' -and $tx.Trim()) { $items.Add([pscustomobject]@{ Kind = $(if ($itype -eq 'reasoning') { 'reasoning' } else { 'message' }); Text = $tx }) }
            continue
        }
        if (-not $itype -or $itype -eq 'error') { continue }
        $name = $itype
        if ($itype -eq 'command_execution') { $name = "shell: $(ConvertTo-OneLine ([string](Get-PropertyValue $it 'command' '')))" }
        elseif ($itype -eq 'web_search') {
            $q = [string](Get-PropertyValue $it 'query' '')
            if (-not $q) { $q = [string](Get-PropertyValue (Get-PropertyValue $it 'action' $null) 'query' '') }
            $name = "web_search: $(ConvertTo-OneLine $q)".TrimEnd(' ', ':')
        } elseif ($itype -eq 'mcp_tool_call') { $name = "mcp: $([string](Get-PropertyValue $it 'server' ''))/$([string](Get-PropertyValue $it 'tool' ''))" }
        elseif ($itype -eq 'collab_tool_call') { $name = "collab: $([string](Get-PropertyValue $it 'tool' ''))" }
        if (-not $id) {
            if (-not $openIdless.ContainsKey($itype)) { $openIdless[$itype] = New-Object System.Collections.Generic.List[string] }
            $open = $openIdless[$itype]
            if ($type -eq 'item.completed' -and $open.Count -gt 0) {
                $at = 0
                for ($oi = 0; $oi -lt $open.Count; $oi++) { if ([string]$toolMap[$open[$oi]] -ceq $name) { $at = $oi; break } }
                $id = $open[$at]
                $open.RemoveAt($at)
            } else {
                $id = "#$k"
                if ($type -eq 'item.started') { $open.Add($id) }
            }
        }
        if ($type -eq 'item.completed' -or -not $toolMap.Contains($id)) { $toolMap[$id] = $name }
    }
    return (New-TurnSalvage -Items $items -ToolMap $toolMap)
}

# agy stream-json: the text_delta pieces of an agent_response step (one message per step, in
# the order the steps began), the result's response text when no step carried text; a tool
# step -> its tool_name ("run_command: <CommandLine>" for a shell command), once per step.
function Read-AgySalvage {
    param([string]$Path)
    $items = New-Object System.Collections.Generic.List[object]
    $toolMap = [ordered]@{}
    $text = $(if ($Path) { Read-SharedText -Path $Path } else { '' })
    if (-not $text) { return (New-TurnSalvage -Items $items -ToolMap $toolMap) }
    $msgs = [ordered]@{}
    $response = ''
    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $t } catch { continue }
        $ev = [string](Get-PropertyValue $obj 'event' '')
        if ($ev -eq 'result') {
            $res = Get-PropertyValue $obj 'result' $null
            if (Test-IsJsonObject $res) { $response = [string](Get-PropertyValue $res 'response' '') }
            continue
        }
        if ($ev -ne 'step_update') { continue }
        $su = Get-PropertyValue $obj 'step_update' $null
        if (-not (Test-IsJsonObject $su)) { continue }
        $idx = "step $([string](Get-PropertyValue $su 'step_index' ''))"
        $st = [string](Get-PropertyValue $su 'step_type' '')
        if ($st -eq 'agent_response') {
            $d = Get-PropertyValue $su 'text_delta' $null
            if ($d -is [string] -and $d) {
                if (-not $msgs.Contains($idx)) { $msgs[$idx] = New-Object System.Text.StringBuilder }
                [void]$msgs[$idx].Append($d)
            }
        } elseif ($st -eq 'tool') {
            $name = [string](Get-PropertyValue $su 'tool_name' '')
            if (-not $name) { continue }
            $params = Get-PropertyValue (Get-PropertyValue $su 'tool_info' $null) 'parameters' $null
            $cmdLine = [string](Get-PropertyValue $params 'CommandLine' '')
            if ($name -eq 'run_command' -and $cmdLine) { $name = "run_command: $(ConvertTo-OneLine $cmdLine)" }
            if (-not $toolMap.Contains($idx)) { $toolMap[$idx] = $name }
        }
    }
    foreach ($k in @($msgs.Keys)) { $s = $msgs[$k].ToString(); if ($s.Trim()) { $items.Add([pscustomobject]@{ Kind = 'message'; Text = $s }) } }
    if ($items.Count -eq 0 -and $response.Trim()) { $items.Add([pscustomobject]@{ Kind = 'message'; Text = $response }) }
    return (New-TurnSalvage -Items $items -ToolMap $toolMap)
}

# muse MSP: the run.output.delta texts, one message per run of consecutive deltas (a tool call
# in between starts the next); a task proposed with task_kind tool.<name> -> <name>, once per
# task (muse's shell and write tools are disabled - no command line to show).
function Read-MuseSalvage {
    param([string]$Path)
    $items = New-Object System.Collections.Generic.List[object]
    $toolMap = [ordered]@{}
    $text = $(if ($Path) { Read-SharedText -Path $Path } else { '' })
    if (-not $text) { return (New-TurnSalvage -Items $items -ToolMap $toolMap) }
    $cur = New-Object System.Text.StringBuilder
    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $t } catch { continue }
        $pType = [string](Get-PropertyValue $obj 'payload_type' '')
        $payload = Get-PropertyValue $obj 'payload' $null
        if (-not (Test-IsJsonObject $payload)) { continue }
        if ($pType -eq 'run.output.delta') {
            $d = Get-PropertyValue $payload 'text' $null
            if ($d -is [string]) { [void]$cur.Append($d) }
        } elseif ($pType -eq 'task.lifecycle.proposed') {
            $ev = Get-PropertyValue $payload 'event' $null
            $kind = [string](Get-PropertyValue $ev 'task_kind' '')
            if ($kind -like 'tool.*') {
                if ($cur.ToString().Trim()) { $items.Add([pscustomobject]@{ Kind = 'message'; Text = $cur.ToString() }) }
                [void]$cur.Clear()
                $tid = [string](Get-PropertyValue $ev 'task_id' '')
                if (-not $tid) { $tid = "#$($toolMap.Count)" }
                if (-not $toolMap.Contains($tid)) { $toolMap[$tid] = $kind.Substring(5) }
            }
        }
    }
    if ($cur.ToString().Trim()) { $items.Add([pscustomobject]@{ Kind = 'message'; Text = $cur.ToString() }) }
    return (New-TurnSalvage -Items $items -ToolMap $toolMap)
}

# The salvage reader of an engine (codex: Read-CodexSalvage; another engine: its adapter's
# Salvage).
function Read-TurnSalvage {
    param([string]$Engine, [string]$Path)
    if (-not $Engine -or $Engine -eq 'codex') { return (Read-CodexSalvage -Path $Path) }
    $spec = Get-EngineSpec -Name $Engine
    if ($spec -and $spec.Adapter -and $spec.Adapter.PSObject.Properties['Salvage'] -and $spec.Adapter.Salvage) { return (& $spec.Adapter.Salvage -Path $Path) }
    return (New-TurnSalvage -Items $null -ToolMap $null)
}

# The body of a <NN>-<engine>-<slug>.partial.md: per turn ($Turns: object[] of { Label; Note
# (e.g. "killed at 902.1 s of 900 s"); Salvage }) a heading, every agent message and reasoning
# text in stream order, then the tool calls. Markdown, LF line ends.
function Format-PartialBody {
    param([object[]]$Turns)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($turn in @($Turns | Where-Object { $_ })) {
        $out.Add("## $($turn.Label)$(if ($turn.Note) { " - $($turn.Note)" })")
        $out.Add('')
        $sal = $turn.Salvage
        $items = @($sal.Items | Where-Object { $_ })
        if ($items.Count -eq 0) { $out.Add('_(no agent message or reasoning text in this turn''s event stream)_'); $out.Add('') }
        $nMsg = 0; $nRea = 0
        foreach ($it in $items) {
            if ($it.Kind -eq 'reasoning') { $nRea++; $out.Add("**Reasoning $($nRea):**") } else { $nMsg++; $out.Add("**Agent message $($nMsg):**") }
            $out.Add('')
            $out.Add((([string]$it.Text).Trim() -replace "`r`n", "`n"))
            $out.Add('')
        }
        $tools = @($sal.Tools | Where-Object { $_ })
        $out.Add("**Tool calls ($($tools.Count)):**$(if ($tools.Count -eq 0) { ' none' })")
        if ($tools.Count -gt 0) { $out.Add(''); foreach ($tl in $tools) { $out.Add("- ``$(([string]$tl) -replace '`', "'")``") } }
        $out.Add('')
    }
    return ($out.ToArray() -join "`n")
}

# ---- the timeout continuation's gates (wave 24b)

# (wave 24c, F15-3) Informational stderr lines of the engines - never failure evidence, whatever
# words they echo: codex's models refresh ("<time> ERROR codex_models_manager::manager: failed to
# refresh available models: ... failed to decode models response: ...; body: {...}" - logged at
# ERROR level with the whole models list in it), its fallback-metadata notice ("Model metadata for
# `<model>` not found. Defaulting to fallback metadata; ..."), "Reading prompt from stdin...", and
# muse's workspace root and delegation notices ($script:MuseInfoStderrRe).
$script:InfoStderrRe = '(?i)failed to (?:refresh available models|decode models response)|\bmodel metadata for\b.*\bnot found\b|^reading prompt from stdin'
function Test-InformationalStderr {
    param([string]$Line)
    return [bool]($Line -match $script:InfoStderrRe -or $Line -match $script:MuseInfoStderrRe)
}
# (wave 24c, F15-3) A DIAGNOSTIC stderr line (matched case-sensitively, -cmatch): ERROR or FATAL
# level - "ERROR: ...", a log line "<time> ERROR <target>: ...", "error: ..." / "Error: ..." at the
# start, "stream error: ...", "error 429", level=error - or an HTTP status with its message: "429
# Too Many Requests", "401 Unauthorized", "last status: 429", "status_code=401", "HTTP 403",
# "Payment required (402)". A plain line that merely contains a word such as auth, billing or 429
# ("loaded auth.json", "request 429 tracing enabled") is not one.
$script:DiagnosticStderrRe = '(?:^|[\s\[|])(?:ERROR|FATAL)\b|(?i:^\s*(?:error|fatal)\b\s*(?:\[[^\]]*\])?\s*:)|(?i:\b(?:stream|request|api|provider|upstream|http|response)\s+error\b)|(?i:\berror\s+[45][0-9]{2}\b)|(?i:\blevel\s*[=:]\s*"?(?:error|fatal)\b)|(?i:\bHTTP(?:/[0-9.]+)?\s+[45][0-9]{2}\b)|(?i:\bstatus(?:[ _]code)?\s*[:=]?\s*[45][0-9]{2}\b)|\b[45][0-9]{2}\s+[A-Z][a-z]+|\([45][0-9]{2}\)'

# (F08-3) Does the killed turn's OWN failure evidence forbid a continuation? A quota class (a usage
# or rate limit; billing, payment, an insufficient balance, exhausted credits) or an auth class
# forbids it - never a continuation after a quota, auth or billing failure. (wave 24c, F15-3) The
# evidence, structured first: the adapter's class (an engine's turn rules); then the structured
# errors - the event stream's error and the adapter's failure texts ($Texts), every provider error
# payload on stderr (an SSE `data: {"error":...}` line, a bare {"error":...}); then only the
# DIAGNOSTIC lines of stderr ($script:DiagnosticStderrRe: ERROR level, or an HTTP status with its
# message). A known informational engine message (Test-InformationalStderr) is never evidence,
# whatever words it echoes, and neither is a plain line that merely contains one ("loaded
# auth.json", "request 429 tracing enabled"). A text of $Texts that is a copy of a stderr line (agy
# keeps its stderr tail there) is judged as that line. Every candidate goes through the ONE
# classifier (ConvertFrom-ProviderErrorText + Get-ProviderFailureClass - the one provider_failure
# uses); the bridge's own timeout text is transport and forbids nothing. { Class ('' | quota |
# auth); Text (the evidence, one line) }.
function Get-KilledTurnFailure {
    param([string]$AdapterClass = '', [string[]]$Texts = @(), [string]$StderrText = '')
    $r = [pscustomobject]@{ Class = ''; Text = '' }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($sl in @(([string]$StderrText) -split "`r?`n")) { $slt = $sl.Trim(); if ($slt) { $lines.Add($slt) } }
    $candidates = New-Object System.Collections.Generic.List[string]
    # 1. the structured errors: the event stream's error, the adapter's failure texts
    foreach ($t in @($Texts)) {
        $tt = ([string]$t).Trim()
        if ($tt -and -not $lines.Contains($tt)) { $candidates.Add($tt) }
    }
    # 2. a provider error payload on stderr, 3. a diagnostic stderr line - an informational one never
    $diagnostic = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) {
        if (Test-InformationalStderr $l) { continue }
        if ((ConvertFrom-ProviderErrorText -Text $l).Found) { $candidates.Add($l) }
        elseif ($l -cmatch $script:DiagnosticStderrRe) { $diagnostic.Add($l) }
    }
    foreach ($d in $diagnostic) { $candidates.Add($d) }
    if ($AdapterClass -eq 'quota' -or $AdapterClass -eq 'auth') {
        $r.Class = $AdapterClass
        $r.Text = ConvertTo-OneLine $(if ($candidates.Count -gt 0) { $candidates[0] } else { "the $AdapterClass class of the turn's rules" })
        return $r
    }
    foreach ($c in $candidates) {
        $p = ConvertFrom-ProviderErrorText -Text $c
        $cls = Get-ProviderFailureClass "$($p.Code) $($p.Message)"
        if ($cls -eq 'quota' -or $cls -eq 'auth') { $r.Class = $cls; $r.Text = ConvertTo-OneLine $c; return $r }
    }
    return $r
}

# (F08-5) Is the reply of a timeout continuation a review the run can take - the checks a first
# reply passes before it is ingested? Structured mode: a valid reply object (ConvertFrom-
# StructuredReply), else substantive prose (Get-ProseGate - the format repair then converts it, as
# for a first reply); -Raw and chore: substantive prose. Until it passes, the killed turn's salvage
# is kept and the continuation is not "usable" (a one-sentence "Done." must not replace the work the
# killed turn did). { Usable; Reason ('' or why not - the prose gate's reason, after "not a valid
# reply object (<why>) and" in structured mode) }.
function Test-ContinuationReply {
    param([string]$Text, [switch]$Raw, [string]$Purpose = '', $PriorFindings = @())
    $r = [pscustomobject]@{ Usable = $false; Reason = '' }
    $t = ([string]$Text).Trim()
    if (-not $t) { $r.Reason = 'empty reply'; return $r }
    $invalid = ''
    if (-not $Raw) {
        try {
            $p = ConvertFrom-StructuredReply -Text $t -Purpose $Purpose -PriorFindings $PriorFindings
            if ($p.Valid) { $r.Usable = $true; return $r }
            $invalid = ConvertTo-OneLine ([string]$p.ValidationError)
        } catch { $invalid = "the bridge could not process it: $(ConvertTo-OneLine $_.Exception.Message)" }
        if ($invalid.Length -gt 120) { $invalid = $invalid.Substring(0, 120) + '...' }
    }
    $gate = Get-ProseGate -Text $t
    if ($gate.Substantive) { $r.Usable = $true; return $r }
    $r.Reason = $(if ($invalid) { "not a valid reply object ($invalid) and $($gate.Reason)" } else { [string]$gate.Reason })
    return $r
}

# Classes of a provider failure, tried in this order (case-insensitive). permission comes
# first (0.4.0, agy F11: a tool the headless print mode cannot grant was auto-denied and
# the turn produced nothing). capability comes next: "Your token plan does not support
# response_format" is a capability rejection, not a quota one. auth matches whole words
# only ("text authored by" is not auth). transport stays last. Google's wordings (the agy
# engine): RESOURCE_EXHAUSTED -> quota, UNAUTHENTICATED / PERMISSION_DENIED / "not signed
# in" -> auth, INVALID_ARGUMENT / "invalid model selection" -> capability, UNAVAILABLE /
# DEADLINE_EXCEEDED -> transport.
# A usage limit said in WORDS ($script:QuotaTextPattern: usage limit, quota, rate limit, ...)
# is quota even under an auth status, and is tried right before auth: Kimi Code answers "403
# Forbidden: You've reached your 5-hour usage limit..." (live ledger, 2026-09-26), which the
# 403 must not turn into an auth failure - the preflight would refuse that endpoint for 24 h.
$script:QuotaTextPattern = '(?i)usage[ _]limit|quota|rate[ _]limit|resource_exhausted|too many requests'
# (wave 24b) A prompt larger than the context window of the plan or the model is capability, tried
# before auth: Kimi Code answers "401 Unauthorized: Your current plan supports only k3 up to 256K
# context. 1M context is available on higher-tier Kimi Code plans." (live ledger, 2026-09-26) - an
# auth class would refuse that endpoint for 24 h although its credential is fine. Also "maximum
# context length is N tokens", context_length_exceeded, "exceeds the context window", "prompt is
# too long", "input token count ... exceeds the maximum number of tokens". A text that also names
# a usage limit stays quota - (wave 24c, F15-1) and so does one with ANY other quota-class wording
# (billing, payment, an insufficient balance, credits, a token plan: the complete quota pattern of
# $script:FailureClassPatterns): "billing_required: insufficient balance for this context window"
# is quota, never capability (Test-ContextOverflow).
$script:ContextOverflowPattern = '(?i)supports?\s+only\b.{0,80}?\b(?:context|tokens?)\b|context[ _-]?(?:length|window)|maximum\s+context|context_length_exceeded|prompt\s+is\s+too\s+long|input\s+(?:is\s+)?too\s+long|input\s+token\s+count|exceeds?\s+the\s+maximum\s+number\s+of\s+tokens'
$script:FailureClassPatterns = [ordered]@{
    'permission' = '(?i)no output produced|auto-denied|permission that headless mode'
    'capability' = '(?i)not supported|unsupported|does(?: not|n[''\u2019]t) support|do not support|feature_not_supported|json_schema|invalid_argument|invalid model selection|conflicts with --effort'
    'auth'       = '(?i)\b40[13]\b|unauthori[sz]ed|forbidden|invalid[ _]api[ _]key|\bauthentication\b|\bauth\b|\bapi key\b|permission_denied|unauthenticated|not signed in|login required|sign in to'
    'quota'      = '(?i)usage[ _]limit|quota|rate[ _]limit|\b429\b|insufficient balance|too many requests|credits? exhausted|credit balance|payment required|\b402\b|token plan|plan exhausted|billing|resource_exhausted|rate_limit_exceeded'
    'transport'  = '(?i)timeout|timed out|connection|econn|enotfound|\bdns\b|\btls\b|certificate|\b50[234]\b|network|\bunavailable\b|deadline_exceeded'
}
$script:BuiltinOpenAiFingerprint = Get-Sha256Hex ($script:Utf8NoBom.GetBytes('cc-provider-v1|builtin:openai'))

# permission | capability | auth | quota | transport | unknown
function Get-ProviderFailureClass {
    param([string]$Message)
    foreach ($k in $script:FailureClassPatterns.Keys) {
        if ($k -eq 'capability' -and (Test-ContextOverflow $Message)) { return 'capability' }
        if ($k -eq 'auth' -and $Message -match $script:QuotaTextPattern) { return 'quota' }
        if ($Message -match $script:FailureClassPatterns[$k]) { return $k }
    }
    return 'unknown'
}

# (wave 24b) The failure text says the prompt outgrew the context window of the plan or the model
# ($script:ContextOverflowPattern) and names no usage limit - (wave 24c, F15-1) no quota-class
# wording at all: the complete quota pattern (usage or rate limit, billing, payment, an
# insufficient balance, credits, a token plan, 402/429) wins over the context exception, so a
# quota or billing failure that also mentions a context window is never capability (no
# continuation after it, the endpoint out as for any quota).
function Test-ContextOverflow {
    param([string]$Message)
    return [bool]($Message -and $Message -match $script:ContextOverflowPattern -and $Message -notmatch $script:FailureClassPatterns['quota'])
}

# (wave 24b) The operator's next step for a recorded provider failure the bridge can explain - ''
# or one phrase. A context-window rejection (class capability, Test-ContextOverflow): "context too
# long for this plan/model - ...". The summary of a failed run prints it (`hint       :`), the
# handoff header after its `Provider failure:` line. (wave 24c, F15-4) The hint is decided when the
# failure is CLASSIFIED: New-ProviderFailure stores it as provider_failure.hint, from the code and
# the FULL message the class came from - a code-only context_length_exceeded ("Request too
# large."), a context phrase past the 200 characters the message keeps. Get-FailureHint reads it
# from there; an entry recorded before wave 24c has none: its class and its code + message decide.
$script:ContextHint = 'context too long for this plan/model - narrow the brief (fewer or smaller files to read, a smaller -Range, a reading plan) or choose a model with a larger context window'
function Get-ClassHint {
    param([string]$Class, [string]$Text)
    if ($Class -eq 'capability' -and (Test-ContextOverflow $Text)) { return $script:ContextHint }
    return ''
}
function Get-FailureHint {
    param($Failure)
    if ($null -eq $Failure) { return '' }
    $stored = Get-PropertyValue $Failure 'hint' $null
    if ($null -ne $stored) { return [string]$stored }
    $class = [string](Get-PropertyValue $Failure 'class' '')
    return (Get-ClassHint -Class $class -Text "$([string](Get-PropertyValue $Failure 'code' '')) $([string](Get-PropertyValue $Failure 'message' ''))")
}

# (wave 24c) A 429 that names no usage window and no quota is a BURST: ModelArk (BytePlus) answers
# "exceeded retry limit, last status: 429 Too Many Requests, request id: ..." for burst and
# concurrency limits that recover within minutes, besides the plan's own windows (live ledgers,
# 2026-09-26). provider_failure.kind 'burst' (after class; '' for every other failure): without a
# reset time such an endpoint is out for 10 minutes ($script:BurstOutMinutes), not 60. A 429 whose
# text names a usage limit, a quota, a balance, credits, billing, a token plan, an hour/day/week/
# month window or a reset keeps the 60-minute rule.
$script:BurstTextPattern = '(?i)\b429\b|too many requests|concurren'
$script:QuotaWindowPattern = '(?i)usage[ _]?limit|\bquota|resource_exhausted|insufficient|\bbalance|\bcredits?\b|\bbilling|\bpayment|\b402\b|token[ _]plan|plan exhausted|\b(?:hours?|days?|weeks?|months?)\b|hourly|daily|weekly|monthly|\bwindow|\bresets?\b'
$script:BurstOutMinutes = 10
$script:QuotaOutMinutes = 60
# 'burst' or '' - $Text: the code and the (full) message the class came from.
function Get-FailureKind {
    param([string]$Class, [string]$Text)
    if ($Class -ne 'quota' -or -not $Text) { return '' }
    if ($Text -match $script:BurstTextPattern -and $Text -notmatch $script:QuotaWindowPattern) { return 'burst' }
    return ''
}

# The provider's own error inside a failure text: an SSE payload `data:{"error":{...}}`
# (MiMo sends its rejections that way) or a bare `{"error":{...}}` -> error.message and
# error.code; otherwise the text itself. { Code; Message; Found (wave 24c: an error payload was
# found - structured evidence, Get-KilledTurnFailure) }.
function ConvertFrom-ProviderErrorText {
    param([string]$Text)
    $r = [pscustomobject]@{ Code = ''; Message = (ConvertTo-OneLine $Text); Found = $false }
    if (-not $Text) { return $r }
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($Text, '(?m)data:\s*(\{.*\})\s*$')) { $candidates.Add($m.Groups[1].Value) }
    $at = $Text.IndexOf('{"error"')
    if ($at -ge 0) { $candidates.Add($Text.Substring($at).Trim()) }
    foreach ($json in $candidates) {
        $o = $null
        try { $o = ConvertFrom-Json -InputObject $json } catch { continue }
        $e = Get-PropertyValue $o 'error' $null
        if ($null -eq $e) { continue }
        $r.Found = $true
        if ($e -is [string]) { $r.Message = ConvertTo-OneLine $e; return $r }
        $msg = [string](Get-PropertyValue $e 'message' '')
        if ($msg) { $r.Message = ConvertTo-OneLine $msg }
        $r.Code = [string](Get-PropertyValue $e 'code' '')
        if (-not $r.Code) { $r.Code = [string](Get-PropertyValue $e 'type' '') }
        return $r
    }
    return $r
}

# When a provider says its limit resets - read from its failure message, never guessed.
# Recognised (case-insensitive; a straight or a curly apostrophe makes no difference):
#   1. Codex's wording "try again at Sep 28th, 2026 8:35 PM." (also "resets at",
#      "available at", "until" before the same form; full or 3-letter month names; the
#      ordinal suffix, the comma, the year and AM/PM are optional - no AM/PM = a 24-hour
#      clock; no year = the reference's year, or the next one when that date lies more
#      than a day before the reference). Codex prints a WALL-CLOCK time of the machine it
#      runs on (ConvertFrom-WallClock).
#   2. an ISO-8601 timestamp after try again / retry / reset / until / available: with an
#      offset it is an instant; without one it is a wall-clock time like 1.
#   3. a duration: "retry after 30" / "Retry-After: 30s" (no unit = seconds), "retry after
#      1 week", "try again in 5 minutes", "resets in 2 days", "try again in 3 days 1 hour
#      7 minutes" (units w, d, h, m, s; the parts are summed) -> $Reference + it.
#   4. Google's wordings (the agy engine, 0.4.0): "retry in 32s", "retry in 1m5.3s" (Go
#      durations: h, m, s, ms, decimals), "retry in 90 seconds", and the gRPC RetryInfo
#      payload "retryDelay":{"seconds":32} / "retryDelay": "32s" / retryDelay: 32s ->
#      $Reference + it, fractions rounded UP to the next second.
#   5. a compact duration after resets / try again / retry / available in (0.4.x, the agy
#      quota "Individual quota reached. ... Resets in 68h58m18s."; also "in 2d3h", "in 45m",
#      "in 30s"; units w, d, h, m, s, ms, decimals) -> $Reference + it, rounded up.
#   6. a rolling window (0.4.x, Kimi Code: "You've reached your 5-hour usage limit. Your quota
#      will reset when the current 5-hour window ends.") -> $Reference + the window's length.
#      That is an UPPER BOUND, not the provider's own reset time: the window ends at the
#      latest one window length after the failure (it began at or before it). Tried last.
# Which offset (F15-1):
#   write time (New-ProviderFailure, on the machine that saw the failure): a wall-clock
#     time is read with the rules of -TimeZone (default [TimeZoneInfo]::Local), so a reset
#     on the far side of a daylight-saving change gets the offset valid THEN (Berlin: a
#     failure at 2026-10-25T01:00+02:00 saying "Oct 26th, 2026 8:35 PM" ->
#     2026-10-26T20:35:00+01:00). A time that does not exist (the spring gap) takes the
#     offset after the transition, an ambiguous one (the autumn overlap) the offset before
#     it. Instants are shown in that zone.
#   read time (-ReferenceOffset: a ledger entry recorded without retry_after): the reader's
#     zone may not be the recorder's, so the offset of $Reference (the failure's `when`) is
#     used for a wall-clock time and for display.
# DateTimeOffset, or $null when the message names no reset time.
$script:MonthNumbers = @{ 'jan' = 1; 'feb' = 2; 'mar' = 3; 'apr' = 4; 'may' = 5; 'jun' = 6; 'jul' = 7; 'aug' = 8; 'sep' = 9; 'oct' = 10; 'nov' = 11; 'dec' = 12 }
$script:DurationUnit = '(?:weeks?|wks?|w|days?|d|hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)\b'
$script:RetryAfterRe = @{
    Codex = [regex]('(?i)(?:try\s+again\s+(?:at|on|after)|resets?\s+(?:at|on)|available\s+(?:again\s+)?(?:at|on|after)|until)\s+' +
        '(?<mon>jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?\s+' +
        '(?<day>[0-9]{1,2})(?:st|nd|rd|th)?\b,?\s*(?:(?<year>[0-9]{4})\b,?\s*)?(?:at\s+)?' +
        '(?<hour>[0-9]{1,2}):(?<min>[0-9]{2})(?::(?<sec>[0-9]{2}))?(?:\s*(?<ampm>[ap])\.?\s?m\b\.?)?')
    Iso   = [regex]'(?i)(?:try\s+again|retry|resets?|until|available)[^0-9\r\n]{0,24}?(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})[T ](?<time>[0-9]{2}:[0-9]{2}(?::[0-9]{2}(?:\.[0-9]+)?)?)(?<tz>Z|[+-][0-9]{2}:?[0-9]{2})?'
    After = [regex]('(?i)retry[- ]after[:\s]\s*(?<n>[0-9]+)(?![0-9:.\-])(?:\s*(?<u>' + $script:DurationUnit + '))?')
    In    = [regex]('(?i)(?:try\s+again|resets?)\s+in\s+(?<parts>[0-9]+\s*' + $script:DurationUnit + '(?:(?:\s*,\s*|\s+and\s+|\s+)[0-9]+\s*' + $script:DurationUnit + ')*)')
    Part  = [regex]('(?i)(?<n>[0-9]+)\s*(?<u>' + $script:DurationUnit + ')')
    # Google: "retry in 32s" / "retry in 1m5.3s" (a Go duration) / "retry in 90 seconds"
    RetryIn = [regex]'(?i)\bretry\s+in\s+(?<dur>(?:[0-9]+(?:\.[0-9]+)?(?:ms|h|m|s))+(?![A-Za-z0-9])|[0-9]+(?:\.[0-9]+)?\s*(?:hours?|hrs?|minutes?|mins?|seconds?|secs?)\b(?:(?:\s*,\s*|\s+and\s+|\s+)[0-9]+(?:\.[0-9]+)?\s*(?:hours?|hrs?|minutes?|mins?|seconds?|secs?)\b)*)'
    # gRPC RetryInfo: "retryDelay":{"seconds":32} or "retryDelay": "32s" / retryDelay: 32s
    RetryDelay = [regex]'(?i)retryDelay"?\s*[:=]\s*(?:\{\s*"?seconds"?\s*:\s*"?(?<sec>[0-9]+)|"?(?<dur>(?:[0-9]+(?:\.[0-9]+)?(?:ms|h|m|s))+)(?![A-Za-z0-9]))'
    GoPart = [regex]'(?i)(?<n>[0-9]+(?:\.[0-9]+)?)\s*(?<u>ms|hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)'
    # a compact duration: "Resets in 68h58m18s", "in 2d3h", "in 45m", "in 30s"
    Compact = [regex]'(?i)\b(?:try\s+again|resets?|retry|available(?:\s+again)?)\s+in\s+(?<dur>(?:[0-9]+(?:\.[0-9]+)?(?:w|d|h|ms|m|s))+)(?![A-Za-z0-9])'
    CompactPart = [regex]'(?i)(?<n>[0-9]+(?:\.[0-9]+)?)(?<u>w|d|h|ms|m|s)'
    # a rolling window: "reset when the current 5-hour window ends" (an UPPER BOUND)
    Window = [regex]'(?i)\bresets?\s+when\s+the\s+current\s+(?<n>[0-9]+)[- ](?<u>minute|hour|day|week)s?\s+window\s+ends'
}
# Seconds of a Go duration ("1m5.3s", "500ms") or a worded one ("90 seconds", "1 hour 30
# minutes"); decimals allowed; $null when nothing parses.
function ConvertFrom-GoDuration {
    param([string]$Text)
    $total = [double]0
    $any = $false
    foreach ($p in $script:RetryAfterRe.GoPart.Matches([string]$Text)) {
        $n = [double]::Parse($p.Groups['n'].Value, $script:Invariant)
        $u = $p.Groups['u'].Value.ToLowerInvariant()
        if ($u -eq 'ms') { $total += $n / 1000 }
        elseif ($u.StartsWith('h')) { $total += $n * 3600 }
        elseif ($u.StartsWith('m')) { $total += $n * 60 }
        else { $total += $n }
        $any = $true
    }
    if (-not $any) { return $null }
    return $total
}
# Seconds of a compact duration ("68h58m18s", "2d3h", "500ms"; units w, d, h, m, s, ms,
# decimals); $null when nothing parses.
function ConvertFrom-CompactDuration {
    param([string]$Text)
    $total = [double]0
    $any = $false
    foreach ($p in $script:RetryAfterRe.CompactPart.Matches([string]$Text)) {
        $n = [double]::Parse($p.Groups['n'].Value, $script:Invariant)
        switch ($p.Groups['u'].Value.ToLowerInvariant()) {
            'w' { $total += $n * 604800 }
            'd' { $total += $n * 86400 }
            'h' { $total += $n * 3600 }
            'm' { $total += $n * 60 }
            'ms' { $total += $n / 1000 }
            default { $total += $n }
        }
        $any = $true
    }
    if (-not $any) { return $null }
    return $total
}
function ConvertTo-DurationSeconds {
    param([long]$N, [string]$Unit)
    $u = ([string]$Unit).ToLowerInvariant()
    if ($u.StartsWith('w')) { return $N * 604800 }
    if ($u.StartsWith('d')) { return $N * 86400 }
    if ($u.StartsWith('h')) { return $N * 3600 }
    if ($u.StartsWith('m')) { return $N * 60 }
    return $N
}
# A wall-clock time -> DateTimeOffset (see Get-RetryAfter): the offset of $TimeZone at that
# time (a nonexistent time: the offset after the transition; an ambiguous one: the offset
# before it), or with -ReferenceOffset (or no zone) the offset of $Reference.
function ConvertFrom-WallClock {
    param([datetime]$Wall, [DateTimeOffset]$Reference, [TimeZoneInfo]$TimeZone = $null, [switch]$ReferenceOffset)
    $w = [datetime]::SpecifyKind($Wall, [DateTimeKind]::Unspecified)
    if ($ReferenceOffset -or $null -eq $TimeZone) { return (New-Object DateTimeOffset -ArgumentList $w, $Reference.Offset) }
    if ($TimeZone.IsInvalidTime($w)) { $offset = $TimeZone.GetUtcOffset($w.AddDays(1)) }
    elseif ($TimeZone.IsAmbiguousTime($w)) { $offset = $TimeZone.GetUtcOffset($w.AddDays(-1)) }
    else { $offset = $TimeZone.GetUtcOffset($w) }
    return (New-Object DateTimeOffset -ArgumentList $w, $offset)
}

# An instant shown in $TimeZone (or, with -ReferenceOffset / no zone, in $Reference's offset).
function ConvertTo-ZoneTime {
    param([DateTimeOffset]$At, [DateTimeOffset]$Reference, [TimeZoneInfo]$TimeZone = $null, [switch]$ReferenceOffset)
    if ($ReferenceOffset -or $null -eq $TimeZone) { return $At.ToOffset($Reference.Offset) }
    return [TimeZoneInfo]::ConvertTime($At, $TimeZone)
}

function Get-RetryAfter {
    param([string]$Message, [DateTimeOffset]$Reference, [TimeZoneInfo]$TimeZone = [TimeZoneInfo]::Local, [switch]$ReferenceOffset)
    if (-not $Message) { return $null }
    $text = $Message -replace '[\u2018\u2019]', "'"
    $m = $script:RetryAfterRe.Codex.Match($text)
    if ($m.Success) {
        try {
            $month = $script:MonthNumbers[$m.Groups['mon'].Value.Substring(0, 3).ToLowerInvariant()]
            $day = [int]$m.Groups['day'].Value
            $hour = [int]$m.Groups['hour'].Value
            $minute = [int]$m.Groups['min'].Value
            $second = 0
            if ($m.Groups['sec'].Success) { $second = [int]$m.Groups['sec'].Value }
            $ok = $true
            if ($m.Groups['ampm'].Success) {
                if ($hour -lt 1 -or $hour -gt 12) { $ok = $false }
                $pm = ($m.Groups['ampm'].Value -ieq 'p')
                if ($hour -eq 12) { $hour = 0 }
                if ($pm) { $hour += 12 }
            }
            if ($ok) {
                if ($m.Groups['year'].Success) {
                    $wall = New-Object DateTime -ArgumentList ([int]$m.Groups['year'].Value), $month, $day, $hour, $minute, $second
                    return (ConvertFrom-WallClock -Wall $wall -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset)
                }
                $at = ConvertFrom-WallClock -Wall (New-Object DateTime -ArgumentList $Reference.Year, $month, $day, $hour, $minute, $second) -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset
                if ($at -lt $Reference.AddDays(-1)) {
                    $at = ConvertFrom-WallClock -Wall (New-Object DateTime -ArgumentList ($Reference.Year + 1), $month, $day, $hour, $minute, $second) -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset
                }
                return $at
            }
        } catch { }
    }
    $m = $script:RetryAfterRe.Iso.Match($text)
    if ($m.Success) {
        $stamp = $m.Groups['date'].Value + 'T' + $m.Groups['time'].Value
        $tz = $m.Groups['tz'].Value
        if ($tz -and $tz -ne 'Z' -and $tz -ne 'z' -and $tz.Length -eq 5) { $tz = $tz.Substring(0, 3) + ':' + $tz.Substring(3) }
        $dto = [DateTimeOffset]::MinValue
        if ($tz) {
            if ([DateTimeOffset]::TryParse($stamp + $tz.ToUpperInvariant(), $script:Invariant, [System.Globalization.DateTimeStyles]::None, [ref]$dto)) {
                return (ConvertTo-ZoneTime -At $dto -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset)
            }
        } else {
            $dt = [datetime]::MinValue
            if ([datetime]::TryParse($stamp, $script:Invariant, [System.Globalization.DateTimeStyles]::None, [ref]$dt)) {
                try { return (ConvertFrom-WallClock -Wall $dt -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset) } catch { }
            }
        }
    }
    $m = $script:RetryAfterRe.After.Match($text)
    if ($m.Success) {
        $unit = if ($m.Groups['u'].Success) { $m.Groups['u'].Value } else { 's' }
        $at = $Reference.AddSeconds((ConvertTo-DurationSeconds -N ([long]$m.Groups['n'].Value) -Unit $unit))
        return (ConvertTo-ZoneTime -At $at -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset)
    }
    $m = $script:RetryAfterRe.In.Match($text)
    if ($m.Success) {
        $total = [long]0
        foreach ($part in $script:RetryAfterRe.Part.Matches($m.Groups['parts'].Value)) {
            $total += (ConvertTo-DurationSeconds -N ([long]$part.Groups['n'].Value) -Unit $part.Groups['u'].Value)
        }
        return (ConvertTo-ZoneTime -At ($Reference.AddSeconds($total)) -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset)
    }
    # a compact duration: "Resets in 68h58m18s", "in 2d3h" (5.)
    $m = $script:RetryAfterRe.Compact.Match($text)
    if ($m.Success) {
        $secs = ConvertFrom-CompactDuration -Text $m.Groups['dur'].Value
        if ($null -ne $secs) { return (ConvertTo-ZoneTime -At ($Reference.AddSeconds([Math]::Ceiling($secs))) -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset) }
    }
    # Google (agy): "retry in 32s", "retry in 1m5.3s", "retry in 90 seconds"
    $m = $script:RetryAfterRe.RetryIn.Match($text)
    if ($m.Success) {
        $secs = ConvertFrom-GoDuration -Text $m.Groups['dur'].Value
        if ($null -ne $secs) { return (ConvertTo-ZoneTime -At ($Reference.AddSeconds([Math]::Ceiling($secs))) -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset) }
    }
    # gRPC RetryInfo: "retryDelay":{"seconds":N} / "retryDelay": "32s"
    $m = $script:RetryAfterRe.RetryDelay.Match($text)
    if ($m.Success) {
        $secs = $null
        if ($m.Groups['sec'].Success) { $secs = [double]$m.Groups['sec'].Value }
        else { $secs = ConvertFrom-GoDuration -Text $m.Groups['dur'].Value }
        if ($null -ne $secs) { return (ConvertTo-ZoneTime -At ($Reference.AddSeconds([Math]::Ceiling($secs))) -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset) }
    }
    # a rolling window (6.): the failure + the window's length - an UPPER BOUND
    $m = $script:RetryAfterRe.Window.Match($text)
    if ($m.Success) {
        $at = $Reference.AddSeconds((ConvertTo-DurationSeconds -N ([long]$m.Groups['n'].Value) -Unit $m.Groups['u'].Value))
        return (ConvertTo-ZoneTime -At $at -Reference $Reference -TimeZone $TimeZone -ReferenceOffset:$ReferenceOffset)
    }
    return $null
}

function Format-OffsetIso {
    param($Value)
    if ($null -eq $Value) { return '' }
    return ([DateTimeOffset]$Value).ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant)
}

# The ledger's provider_failure of a failed run: { class; kind; code; message (<= 200); when;
# retry_after; hint }. $Texts: the evidence in order of preference (the event-stream error,
# stderr, the bridge outcome); the first that holds a provider error payload wins, else the
# first non-empty. retry_after: the reset time the chosen message names (Get-RetryAfter,
# read from the FULL message before it is cut to 200 characters), ISO with offset, or $null.
# (wave 24c) Everything the classification decides is decided HERE, from the code and the FULL
# message, and stored: kind ('burst' - a 429 that names no usage window or quota, out for 10
# minutes - or ''; Get-FailureKind) and hint (F15-4: the operator's next step, '' or one phrase;
# Get-ClassHint) - a later reader has only the message cut to 200 characters.
function New-ProviderFailure {
    param([string[]]$Texts, [string]$Class = '')
    $chosen = $null
    $chosenRaw = ''
    foreach ($t in @($Texts | Where-Object { $_ -and $_.Trim() })) {
        $p = ConvertFrom-ProviderErrorText -Text $t
        if ($p.Code -or ($t.IndexOf('{"error"') -ge 0)) { $chosen = $p; $chosenRaw = $t; break }
        if (-not $chosen) { $chosen = $p; $chosenRaw = $t }
    }
    if (-not $chosen) { $chosen = [pscustomobject]@{ Code = ''; Message = '' } }
    $msg = [string]$chosen.Message
    $now = Get-Date
    $retryAfter = Get-RetryAfter -Message $msg -Reference ([DateTimeOffset]$now)
    # A gRPC error payload (Google, the agy engine) names its reset time in the details
    # (RetryInfo.retryDelay), outside error.message.
    if ($null -eq $retryAfter -and $chosenRaw -and $chosenRaw -match '(?i)retryDelay') { $retryAfter = Get-RetryAfter -Message $chosenRaw -Reference ([DateTimeOffset]$now) }
    if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) }
    $evidence = "$($chosen.Code) $($chosen.Message)"
    $cls = $(if ($Class) { $Class } else { (Get-ProviderFailureClass $evidence) })
    return [pscustomobject]@{
        class       = $cls
        kind        = (Get-FailureKind -Class $cls -Text $evidence)
        code        = [string]$chosen.Code
        message     = $msg
        when        = (Get-IsoTimestamp $now)
        retry_after = $(if ($null -ne $retryAfter) { Format-OffsetIso $retryAfter } else { $null })
        hint        = (Get-ClassHint -Class $cls -Text $evidence)
    }
}

# Every consultation of every task ledger under $CollabRoot, read tolerantly (a store that
# does not parse is skipped here; codex-consult.ps1 refuses it when that task is used).
function Read-AllTaskConsults {
    param([string]$CollabRoot)
    $all = New-Object System.Collections.Generic.List[object]
    if (-not $CollabRoot -or -not (Test-Path -LiteralPath $CollabRoot -PathType Container)) { return , $all.ToArray() }
    foreach ($dir in @(Get-ChildItem -LiteralPath $CollabRoot -Directory -ErrorAction SilentlyContinue)) {
        $f = Join-Path $dir.FullName 'sessions.json'
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
        try {
            $data = ConvertFrom-JsonKeepOffset -Text (Read-SharedText -Path $f)
            foreach ($c in @(Get-PropertyValue (Get-PropertyValue $data 'codex' $null) 'consults' @())) { if ($null -ne $c) { $all.Add($c) } }
        } catch { }
    }
    return , $all.ToArray()
}

# A ledger entry's bridge_outcome that counts as a usable reply: EXACTLY 'usable reply' or (wave
# 24) 'usable reply (after a timeout continuation)' - the reply of the ONE continuation turn the
# bridge ran on the thread of a turn it had killed on its timeout. (wave 24b, F13-2) Any other
# string - a future 'usable reply (<something>)' too - is not usable until it is added here: the
# predicate clears the endpoint health, evidences a sign-in (RecentUsable) and counts on the
# scoreboard, so it fails closed.
$script:UsableOutcomes = @('usable reply', 'usable reply (after a timeout continuation)')
function Test-UsableOutcome {
    param([string]$Outcome)
    return [bool]($script:UsableOutcomes -ccontains $Outcome)
}

# Health of one ENDPOINT (provider_fingerprint - never the alias) from the ledgers of all
# tasks. Entries recorded before 0.3.0 count as the built-in openai endpoint; entries with
# an unresolved identity (empty fingerprint) are ignored. A failure's class comes from its
# provider_failure, else (older entries) from its bridge_outcome. Newest wins: a later
# successful run clears an earlier auth or quota failure ("later" by completion: finished_at,
# else when + wall_seconds; ties by n). $UtcNow: the consult clock
# (Get-ConsultClock -Peek), so a test can freeze time.
#   Auth         the newest of {success, auth failure} is an auth failure <= 24 h old
#   Quota        the newest of {success, quota failure} is a quota failure that still
#                blocks: its RetryAfter lies in the future, or it has no RetryAfter and its
#                limit was hit less than 60 minutes ago (wave 24, T3: Hit + 60 min lies ahead
#                - "out (limit hit <t>, reset unknown; retry after <t + 60 min>)"; wave 24c:
#                10 minutes for a burst - FailureKind 'burst', a 429 that names no usage window
#                or quota); a RetryAfter in the past clears it
#   QuotaKnown   [bool] Quota is set and names its reset time (RetryAfter)
#   LastLimit    the newest quota failure <= 24 h old, else (wave 24, T2) the Quota record
#                that still blocks (a reset days ahead): an endpoint that is out never shows
#                no failure at all
#   LastFailure  the newest failure of any class <= 24 h old, else the Quota record that
#                still blocks (informational)
#   RecentUsable the newest usable reply <= 60 min old (wave 18: an engine's sign-in is then
#                evidenced without a network check - Get-EngineCredential)
# Each record is $null or { Class; Code; Message; When; AgeMinutes (a `when` in the future
# counts as now: 0); RetryAfter (DateTimeOffset or $null: provider_failure.retry_after, else
# Get-RetryAfter -ReferenceOffset on the recorded message with the failure's `when` as
# reference); RetryAfterIso ('' when none); RetryAfterBasis ('ledger' | 'message (reference
# offset)' | ''); Hit (wave 24: DateTimeOffset - when the failure happened: provider_failure.
# when, else the entry's `when`; a time in the future counts as now); HitIso; Until
# (RetryAfter, else Hit + OutMinutes); FailureKind (wave 24c: provider_failure.kind - 'burst' or
# '' - recorded with the class, else derived from the code and message by Get-FailureKind);
# OutMinutes (10 for a burst, else 60) }. A usable reply is Test-UsableOutcome (a reply after a
# timeout continuation counts).
# (wave 26b, D13) The records of the machine-wide health file (Read-MachineHealth) take part as
# entries of their own: every repository's failures and usable replies on the endpoint, beside
# this repository's ledgers - one record set, the newest decides as within one ledger; a record
# at the same completion time as another counts with the later `until` (a quota record's until is
# its retry_after). -NoMachine: the ledgers alone.
# (wave 29b, E5) -Fingerprints: several endpoints read as ONE record set (a plan's routes - only its
# Quota is used: Get-PlanQuotaVerdict); every record carries its Fingerprint.
# (wave 29b, E15) An entry that carries a quota mark - engine_run.quota_mark, the provider_failure a
# failed quota turn would have recorded, on a usable reply whose turn saw a rejecting rate-limit
# event - counts twice: as itself (a usable reply: RecentUsable, it clears older failures) and as that
# quota failure 1 ms after it, so the route stays out until the mark's reset (or 60 minutes, 10 for a
# burst) exactly as after a failed quota turn - and a later usable reply clears it as usual.
function Get-EndpointHealth {
    param([object[]]$Consults, [string]$Fingerprint, [datetime]$UtcNow = [datetime]::UtcNow, [switch]$NoMachine, [string[]]$Fingerprints = @())
    $h = [pscustomobject]@{ Auth = $null; Quota = $null; QuotaKnown = $false; LastLimit = $null; LastFailure = $null; RecentUsable = $null }
    $fpSet = @(@($Fingerprints) + @($Fingerprint) | Where-Object { $_ } | Select-Object -Unique)
    if ($fpSet.Count -eq 0) { return $h }
    $nowOffset = New-Object DateTimeOffset ([datetime]::SpecifyKind($UtcNow, [DateTimeKind]::Utc))
    $records = New-Object System.Collections.Generic.List[object]
    $allConsults = @($Consults | Where-Object { $null -ne $_ })
    if (-not $NoMachine) {
        foreach ($oneFp in $fpSet) {
            $machineEntries = ConvertTo-MachineHealthEntries -Fingerprint $oneFp
            $allConsults = @($allConsults) + @($machineEntries)
        }
    }
    # (E15) the quota marks as entries of their own, 1 ms after the entry that carries them
    $marked = New-Object System.Collections.Generic.List[object]
    foreach ($c in $allConsults) {
        $marked.Add($c)
        $qm = Get-PropertyValue (Get-PropertyValue $c 'engine_run' $null) 'quota_mark' $null
        if ($null -eq $qm -or [string](Get-PropertyValue $qm 'class' '') -ne 'quota') { continue }
        $mAt = ConvertTo-WhenOffset (Get-PropertyValue $c 'when' '')
        if ($null -eq $mAt) { continue }
        $mOrder = ConvertTo-WhenOffset (Get-PropertyValue $c 'finished_at' '')
        if ($null -eq $mOrder) {
            $mOrder = $mAt
            $mws = 0.0
            if ([double]::TryParse([string](Get-PropertyValue $c 'wall_seconds' ''), [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$mws) -and $mws -gt 0) { $mOrder = $mAt.AddSeconds($mws) }
        }
        $marked.Add([pscustomobject]@{ n = (Get-PropertyValue $c 'n' 0); when = (Get-PropertyValue $c 'when' ''); finished_at = $mOrder.AddMilliseconds(1); bridge_outcome = 'failed: quota (a rate limit rejected a request during a usable turn)'; reviewer = (Get-PropertyValue $c 'reviewer' $null); provider_failure = $qm })
    }
    foreach ($c in $marked) {
        $rev = Get-PropertyValue $c 'reviewer' $null
        $fp = if ($null -eq $rev) { $script:BuiltinOpenAiFingerprint } else { [string](Get-PropertyValue $rev 'provider_fingerprint' '') }
        if (-not $fp -or $fpSet -notcontains $fp) { continue }
        $outcome = [string](Get-PropertyValue $c 'bridge_outcome' '')
        if (-not $outcome) { continue }
        $at = ConvertTo-WhenOffset (Get-PropertyValue $c 'when' '')
        if ($null -eq $at) { continue }
        # A failure stamped in the future (clock skew, a mislabelled zone) counts as now:
        # its age is clamped to 0, it is never skipped (F15-4).
        $age = [Math]::Max(0, ($UtcNow - $at.UtcDateTime).TotalMinutes)
        # "Newest" is by COMPLETION (D9, F03-3): a panel's members start together and finish in
        # any order, so a member that started later may have succeeded before an earlier one hit
        # its usage limit. finished_at (0.4.x wave 21), else when + wall_seconds (older entries),
        # else when; ties by n (F02-5).
        $order = ConvertTo-WhenOffset (Get-PropertyValue $c 'finished_at' '')
        if ($null -eq $order) {
            $order = $at
            $ws = 0.0
            if ([double]::TryParse([string](Get-PropertyValue $c 'wall_seconds' ''), [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$ws) -and $ws -gt 0) { $order = $at.AddSeconds($ws) }
        }
        $entryN = 0
        [void][int]::TryParse([string](Get-PropertyValue $c 'n' ''), [ref]$entryN)
        $rec = [pscustomobject]@{ At = $at; Order = $order; N = $entryN; Ok = (Test-UsableOutcome $outcome); Class = ''; Code = ''; Message = ''; When = $at.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant); AgeMinutes = [int][Math]::Max(0, [Math]::Floor($age)); Age = $age; RetryAfter = $null; RetryAfterIso = ''; RetryAfterBasis = ''; Hit = $at; HitIso = ''; Until = $at.AddMinutes(60); FailureKind = ''; OutMinutes = $script:QuotaOutMinutes; Fingerprint = $fp }
        if (-not $rec.Ok) {
            $reference = $at
            $pf = Get-PropertyValue $c 'provider_failure' $null
            $recordedClass = ''
            if ($null -ne $pf) {
                $rec.Class = [string](Get-PropertyValue $pf 'class' 'unknown')
                $recordedClass = $rec.Class
                # An entry recorded as auth whose message says usage limit / quota / rate limit
                # counts as quota (Get-ProviderFailureClass's rule, applied when the ledger is
                # READ): a 401/403 with a usage-limit text recorded before that rule existed
                # (Kimi Code's 5-hour limit) stops refusing the endpoint for 24 h as an auth
                # failure - without anyone editing the ledger.
                if ($rec.Class -eq 'auth' -and ([string](Get-PropertyValue $pf 'message' '')) -match $script:QuotaTextPattern) { $rec.Class = 'quota' }
                # (wave 24b) likewise a 401 whose text is a context-window limit of the plan
                # (Test-ContextOverflow: Kimi Code's "Your current plan supports only k3 up to 256K
                # context") counts as capability - it never refuses the endpoint for 24 h
                elseif ($rec.Class -eq 'auth' -and (Test-ContextOverflow ([string](Get-PropertyValue $pf 'message' '')))) { $rec.Class = 'capability' }
                # (wave 24c, F15-1) and an entry the context exception recorded as capability although
                # its text also names a quota class (billing, a balance, credits - recorded before
                # wave 24c) is read with today's classifier: quota wins
                elseif ($rec.Class -eq 'capability' -and ([string](Get-PropertyValue $pf 'message' '')) -match $script:ContextOverflowPattern -and -not (Test-ContextOverflow ([string](Get-PropertyValue $pf 'message' '')))) {
                    $rec.Class = Get-ProviderFailureClass "$([string](Get-PropertyValue $pf 'code' '')) $([string](Get-PropertyValue $pf 'message' ''))"
                }
                $rec.Code = [string](Get-PropertyValue $pf 'code' '')
                $rec.Message = [string](Get-PropertyValue $pf 'message' '')
                # (wave 24c) the kind recorded with that class ('burst': a 429 that names no usage
                # window or quota); an entry recorded before wave 24c, or read as another class, gets
                # it from its code and message
                $recordedKind = Get-PropertyValue $pf 'kind' $null
                $rec.FailureKind = $(if ($null -ne $recordedKind -and $rec.Class -eq $recordedClass) { [string]$recordedKind } else { Get-FailureKind -Class $rec.Class -Text "$($rec.Code) $($rec.Message)" })
                $pfWhen = ConvertTo-WhenOffset (Get-PropertyValue $pf 'when' '')
                if ($null -ne $pfWhen) { $reference = $pfWhen }
                $recorded = Get-PropertyValue $pf 'retry_after' $null
                if ($null -ne $recorded -and "$recorded") { $rec.RetryAfter = ConvertTo-WhenOffset $recorded }
            } else {
                # older entry: classify its bridge_outcome, lifting an SSE/JSON error payload
                $parsedOutcome = ConvertFrom-ProviderErrorText -Text $outcome
                $rec.Class = Get-ProviderFailureClass "$($parsedOutcome.Code) $outcome"
                $rec.Code = $parsedOutcome.Code
                $rec.Message = $parsedOutcome.Message
                $rec.FailureKind = Get-FailureKind -Class $rec.Class -Text "$($rec.Code) $($rec.Message)"
            }
            if ($rec.Class -ne 'quota') { $rec.FailureKind = '' }
            $rec.OutMinutes = $(if ($rec.FailureKind -eq 'burst') { $script:BurstOutMinutes } else { $script:QuotaOutMinutes })
            # an entry recorded without retry_after: read the reset time from its message now
            if ($null -ne $rec.RetryAfter) { $rec.RetryAfterBasis = 'ledger' }
            else {
                $rec.RetryAfter = Get-RetryAfter -Message $rec.Message -Reference $reference -ReferenceOffset
                if ($null -ne $rec.RetryAfter) { $rec.RetryAfterBasis = 'message (reference offset)' }
            }
            # (wave 24) when the failure happened - a time in the future counts as now (F15-4) -
            # and, without a reset time, the 60 minutes it stays out ((wave 24c) 10 for a burst)
            $hit = $reference
            if ($hit.UtcDateTime -gt $UtcNow) { $hit = $nowOffset.ToOffset($hit.Offset) }
            $rec.Hit = $hit
            $rec.HitIso = Format-OffsetIso $hit
            $rec.Until = $hit.AddMinutes($rec.OutMinutes)
            if ($null -ne $rec.RetryAfter) {
                $rec.RetryAfterIso = Format-OffsetIso $rec.RetryAfter
                $rec.Until = $rec.RetryAfter
            }
            # (wave 26c, D2 / F26-2) a machine-wide record's stored until (never in a ledger's
            # provider_failure) is its until - the tie-break of two records at the same time
            if ($null -ne $pf) {
                $storedUntil = ConvertTo-WhenOffset (Get-PropertyValue $pf 'until' $null)
                if ($null -ne $storedUntil) { $rec.Until = $storedUntil }
            }
            if ($rec.Message.Length -gt 100) { $rec.Message = $rec.Message.Substring(0, 100) }
        }
        $records.Add($rec)
    }
    $sorted = @($records | Sort-Object -Property @{ Expression = { $_.Order }; Descending = $true }, @{ Expression = { $_.Until }; Descending = $true }, @{ Expression = { $_.N }; Descending = $true })
    $auth = @($sorted | Where-Object { $_.Ok -or $_.Class -eq 'auth' }) | Select-Object -First 1
    if ($auth -and -not $auth.Ok -and $auth.AgeMinutes -le 24 * 60) { $h.Auth = $auth }
    $quota = @($sorted | Where-Object { $_.Ok -or $_.Class -eq 'quota' }) | Select-Object -First 1
    if ($quota -and -not $quota.Ok) {
        if ($null -ne $quota.RetryAfter) {
            if ($quota.RetryAfter.UtcDateTime -gt $UtcNow) { $h.Quota = $quota }
        } elseif ($quota.Until.UtcDateTime -gt $UtcNow) {
            $h.Quota = $quota
        }
    }
    $h.QuotaKnown = [bool]($h.Quota -and $null -ne $h.Quota.RetryAfter)
    $h.LastLimit = @($sorted | Where-Object { -not $_.Ok -and $_.Class -eq 'quota' -and $_.AgeMinutes -le 24 * 60 }) | Select-Object -First 1
    $h.LastFailure = @($sorted | Where-Object { -not $_.Ok -and $_.AgeMinutes -le 24 * 60 }) | Select-Object -First 1
    if (-not $h.LastLimit -and $h.Quota) { $h.LastLimit = $h.Quota }
    if (-not $h.LastFailure -and $h.Quota) { $h.LastFailure = $h.Quota }
    $h.RecentUsable = @($sorted | Where-Object { $_.Ok -and $_.Age -le 60 }) | Select-Object -First 1
    return $h
}

# ----------------------------------------------------------------------------- machine-wide endpoint health (wave 26b, D13 - ROADMAP R20)
#
# ONE file per machine, <codex home>/codex-consult-health.json (CODEX_CONSULT_HEALTH=<path> names
# another; CODEX_CONSULT_HEALTH=none: no file - read nor written), so that the repositories of
# one machine see each other's endpoint outcomes and running members:
#   { "health_version": 1,
#     "endpoints": [ { "endpoint": "<provider fingerprint>", "class": "ok" | "<a provider failure
#                      class>", "kind": "burst" | "", "until": "<iso>" | null, "retry_after": "<the
#                      reset time the provider named>" | null, "repo": "<repository root>", "when":
#                      "<iso>", "message": "<the failure's message, cut to 200>"[, "quota_mark": {
#                      "class": "quota", "kind", "until", "retry_after", "message", "when" } - (wave
#                      29b, E15) on an "ok" record whose turn saw a rejecting rate-limit event] } ],
#     "running":   [ { "endpoint": "<fingerprint>", "label": "<provider label>", "pid": <the run's
#                      bridge pid>, "start_time": "<its start>", "repo": "...", "task": "...", "nn":
#                      "<NN>", "panel": "<panel id or ''>", "since": "<iso>"[, "plan": "<the roster
#                      entry's plan> - (wave 29b, E16) only when the entry names one"] } ] }
# Written under <file>.lock (exclusive open, retried up to 10 s; not acquired = not written) by
# every run that records a provider failure (class operator excepted) or a usable reply
# (Add-MachineHealthRecord: until = a quota's reset time, else the hit + 60 min (10 for a burst);
# an auth failure + 24 h; else null), and by every run while its engine turns run
# (Register-MachineRunning / Unregister-MachineRunning). Every write prunes: an endpoint record
# older than 24 h whose until has passed; a running row whose pid + start time is gone. Read by
# every endpoint-health question (Get-EndpointHealth: every roster walk, the panel selection,
# codex-providers.ps1) and by the panel's scheduler (Get-MachineRunningCount: the endpoint
# parallel limit counts the members of OTHER repositories and panels running on the endpoint -
# (wave 29b, E16) and on any route of the same plan, whatever their engine).
# The file is optional: absent, unreadable or not parseable = as before wave 26b.

$script:MachineHealthCache = $null

# A running row's start_time as Get-ProcessStartIso writes it (UTC round-trip 'o'), whatever the
# JSON reader made of it (PowerShell 7 turns an ISO text into a [datetime] or [DateTimeOffset]).
function ConvertTo-StartIso {
    param($Value)
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime.ToString('o', $script:Invariant) }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('o', $script:Invariant) }
    return [string]$Value
}

function Get-MachineHealthPath {
    $v = ([string]$env:CODEX_CONSULT_HEALTH).Trim()
    if ($v) { if ($v -ieq 'none') { return '' }; return $v }
    $h = Get-CodexHome
    if (-not $h) { return '' }
    return (Join-Path $h 'codex-consult-health.json')
}

# { Path; Endpoints (object[]); Running (object[]) } - tolerant: absent or unreadable = empty.
# Cached per process by the file's size and write time.
function Read-MachineHealth {
    param([switch]$Fresh)
    $r = [pscustomobject]@{ Path = (Get-MachineHealthPath); Endpoints = [object[]]@(); Running = [object[]]@() }
    if (-not $r.Path -or -not [IO.File]::Exists($r.Path)) { return $r }
    $stamp = ''
    try { $fi = New-Object IO.FileInfo($r.Path); $stamp = "$($fi.Length)|$($fi.LastWriteTimeUtc.Ticks)" } catch { return $r }
    if (-not $Fresh -and $script:MachineHealthCache -and $script:MachineHealthCache.Path -eq $r.Path -and $script:MachineHealthCache.Stamp -eq $stamp) { return $script:MachineHealthCache.Data }
    try {
        $text = Read-SharedText -Path $r.Path
        if ($text -and $text.Trim()) {
            $data = ConvertFrom-JsonKeepOffset -Text $text
            $r.Endpoints = [object[]]@(@(Get-PropertyValue $data 'endpoints' @()) | Where-Object { $null -ne $_ -and [string](Get-PropertyValue $_ 'endpoint' '') })
            $r.Running = [object[]]@(@(Get-PropertyValue $data 'running' @()) | Where-Object { $null -ne $_ })
        }
    } catch { $r.Endpoints = [object[]]@(); $r.Running = [object[]]@() }
    $script:MachineHealthCache = [pscustomobject]@{ Path = $r.Path; Stamp = $stamp; Data = $r }
    return $r
}

# The machine file's endpoint records of $Fingerprint as ledger-like entries for Get-EndpointHealth.
function ConvertTo-MachineHealthEntries {
    param([string]$Fingerprint)
    $out = New-Object System.Collections.Generic.List[object]
    if (-not $Fingerprint) { return , ([object[]]$out.ToArray()) }
    foreach ($e in @((Read-MachineHealth).Endpoints)) {
        if ([string](Get-PropertyValue $e 'endpoint' '') -ne $Fingerprint) { continue }
        $when = Get-PropertyValue $e 'when' $null
        if ($null -eq (ConvertTo-WhenOffset $when)) { continue }
        $cls = [string](Get-PropertyValue $e 'class' '')
        $repo = [string](Get-PropertyValue $e 'repo' '')
        if ($cls -eq 'ok') {
            # (wave 29b, E15) a usable reply with a quota mark: the mark travels as engine_run.quota_mark
            $okRun = $null
            $mk = Get-PropertyValue $e 'quota_mark' $null
            if ($null -ne $mk -and (Test-IsJsonObject $mk)) {
                $mkReset = Get-PropertyValue $mk 'retry_after' $null
                $mkUntil = Get-PropertyValue $mk 'until' $null
                $mkWhen = Get-PropertyValue $mk 'when' $null
                $okRun = [pscustomobject]@{ quota_mark = [pscustomobject]@{ class = 'quota'; kind = [string](Get-PropertyValue $mk 'kind' ''); code = ''; message = [string](Get-PropertyValue $mk 'message' ''); when = $(if ($null -ne (ConvertTo-WhenOffset $mkWhen)) { $mkWhen } else { $when }); retry_after = $(if ($null -ne (ConvertTo-WhenOffset $mkReset)) { $mkReset } else { $null }); until = $(if ($null -ne (ConvertTo-WhenOffset $mkUntil)) { $mkUntil } else { $null }) } }
            }
            $out.Add([pscustomobject]@{ n = 0; when = $when; finished_at = $when; bridge_outcome = 'usable reply'; reviewer = [pscustomobject]@{ provider_fingerprint = $Fingerprint }; provider_failure = $null; engine_run = $okRun })
            continue
        }
        if (-not $cls) { continue }
        # the provider's own reset time (retry_after), when it named one - the until of a failure
        # without one is recomputed by Get-EndpointHealth (hit + 60 min, 10 for a burst)
        $resetAt = Get-PropertyValue $e 'retry_after' $null
        # (wave 26c, D2 / F26-2) the stored `until` travels too: the tie-break of two records at the
        # same time is the later until (Get-EndpointHealth)
        $storedUntil = Get-PropertyValue $e 'until' $null
        $pf = [pscustomobject]@{ class = $cls; kind = [string](Get-PropertyValue $e 'kind' ''); code = ''; message = [string](Get-PropertyValue $e 'message' ''); when = $when; retry_after = $(if ($null -ne (ConvertTo-WhenOffset $resetAt)) { $resetAt } else { $null }); until = $(if ($null -ne (ConvertTo-WhenOffset $storedUntil)) { $storedUntil } else { $null }) }
        $out.Add([pscustomobject]@{ n = 0; when = $when; finished_at = $when; bridge_outcome = "failed: $cls (machine-wide health; recorded by $repo)"; reviewer = [pscustomobject]@{ provider_fingerprint = $Fingerprint }; provider_failure = $pf })
    }
    return , ([object[]]$out.ToArray())
}

# (wave 28b, D13 / F36-6, F37-1) THE JOURNAL beside the health file: <health file>.journal, append-only
# NDJSON, one endpoint record per line. A run whose health update failed before its ledger commit
# appends its record there INSIDE the commit (a local append - no wait for the health lock;
# Add-MachineHealthJournal); every health update (Update-MachineHealth: the retry after the commit,
# the next run of ANY repository - its registration, its outcome) applies the journal under the
# health lock and empties it once the health file is written. Applying is idempotent: a record
# already in endpoints[] (the same endpoint, class, kind, when and repository) is not added again.
# (wave 28c, D10) A line that does not parse is moved to <health file>.journal.bad (appended: the
# time, a tab, the line's bytes) and counted in a warning; the journal loses only what was applied
# or moved.
function Get-MachineHealthJournalPath {
    $h = Get-MachineHealthPath
    if (-not $h) { return '' }
    return "$h.journal"
}

# (wave 28c, D10) The warnings of the journal's apply in this process ("health journal: <n> unreadable
# line(s) kept in <file>"): Get-MachineHealthJournalNotes returns them and starts the list again -
# the run puts them into its warnings[] (before the commit) or its summary (after it).
$script:MachineHealthJournalNotes = New-Object System.Collections.Generic.List[string]
function Get-MachineHealthJournalNotes {
    $out = [string[]]$script:MachineHealthJournalNotes.ToArray()
    $script:MachineHealthJournalNotes.Clear()
    return $out
}

# Appends one endpoint record to the journal (exclusive open, retried up to 2 s). '' when written,
# else why not; never throws.
function Add-MachineHealthJournal {
    param($Record)
    try {
        $j = Get-MachineHealthJournalPath
        if (-not $j) { return 'no machine-wide health file' }
        if ($null -eq $Record) { return 'no record' }
        $jdir = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($j))
        if (-not [IO.Directory]::Exists($jdir)) { return "the directory $jdir does not exist" }
        $bytes = $script:Utf8NoBom.GetBytes((ConvertTo-Json -Compress -Depth 4 -InputObject $Record) + "`n")
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            try {
                $fs = New-Object System.IO.FileStream($j, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try { $fs.Write($bytes, 0, $bytes.Length); $fs.Flush($true) } finally { $fs.Dispose() }
                return ''
            } catch [System.IO.IOException] {
                if ($watch.ElapsedMilliseconds -ge 2000) { return "the journal $j stayed busy" }
                Start-Sleep -Milliseconds 50
            }
        }
    } catch { return (ConvertTo-OneLine $_.Exception.Message) }
}

# The identity of an endpoint record for the journal's idempotent apply.
function Get-MachineHealthRecordKey {
    param($Record)
    $w = ConvertTo-WhenOffset (Get-PropertyValue $Record 'when' '')
    # (wave 29b, A6 / F24-1) a record that carries a quota mark has another identity than the unmarked
    # one of the same route, repository and second: the key gains the mark's reset, so a marked success is
    # never discarded in favour of an unmarked one (the identical marked record replayed stays one)
    $mk = Get-PropertyValue $Record 'quota_mark' $null
    $mkId = ''
    if ($null -ne $mk) {
        $mu = ConvertTo-WhenOffset (Get-PropertyValue $mk 'until' '')
        $mkId = '|mark:' + $(if ($mu) { [string]$mu.UtcTicks } else { '' })
    }
    return ((@('endpoint', 'class', 'kind', 'repo') | ForEach-Object { [string](Get-PropertyValue $Record $_ '') }) -join '|') + '|' + $(if ($w) { [string]$w.UtcTicks } else { '' }) + $mkId
}

# Changes the machine file under its lock - (wave 28b, D13) applies the journal first, then adds
# $AddEndpoint to endpoints[] (neither added twice), drops every running row of $RemovePid (> 0),
# adds $AddRunning to running[] - then prunes and writes it atomically, and empties the journal it
# applied ((wave 28c, D10) its unreadable lines moved to <journal>.bad first - never dropped). $true
# when written; never throws.
function Update-MachineHealth {
    param($AddEndpoint = $null, $AddRunning = $null, [int]$RemovePid = 0, [int]$Attempts = 3, [double]$AttemptSec = 0)
    # (wave 26c, D2 / F26-2; wave 27c, D7 / F30-7, F29-1, F32-3) why the last update was not written -
    # EVERY failure names its cause: 'lock timeout', 'the directory ... does not exist', 'write failed:
    # <why>'; '' when written or when there is nothing to write (no file configured)
    $script:MachineHealthLastError = ''
    $path = Get-MachineHealthPath
    if (-not $path) { return $false }
    # (wave 28b, D13) TEST HOOK (test mode only): CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST=1 - the FIRST
    # update of this process that adds an endpoint record fails ('lock timeout (test hook)'): the run's
    # own record before the commit, so the journal and the retry after the commit can be watched
    if ($null -ne $AddEndpoint -and -not $script:HealthFailFirstDone -and (Get-TestHookValue 'CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST').Trim() -eq '1') {
        $script:HealthFailFirstDone = $true
        $script:MachineHealthLastError = 'lock timeout (test hook CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST)'
        return $false
    }
    $lockFs = $null
    $journalFs = $null
    try {
        $dir = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($path))
        if (-not [IO.Directory]::Exists($dir)) { $script:MachineHealthLastError = "the directory $dir does not exist"; return $false }
        # (wave 26c, D2) the lock: $Attempts attempts of 5 s each (TEST HOOK: CODEX_CONSULT_TEST_HEALTH_LOCK_SEC
        # = the seconds of one attempt); (wave 27c, D8) $AttemptSec > 0 caps one attempt (the one
        # attempt inside the task write lock: at most 1 s)
        # (NB: never $attemptSec - PowerShell names are case-insensitive, that is the parameter)
        $oneAttemptSec = 5
        $hookSec = 0
        if ([int]::TryParse((Get-TestHookValue 'CODEX_CONSULT_TEST_HEALTH_LOCK_SEC'), [ref]$hookSec) -and $hookSec -gt 0) { $oneAttemptSec = $hookSec }
        if ($AttemptSec -gt 0 -and $AttemptSec -lt $oneAttemptSec) { $oneAttemptSec = $AttemptSec }
        for ($attempt = 1; $attempt -le $Attempts -and $null -eq $lockFs; $attempt++) {
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $delay = 25
            while ($null -eq $lockFs -and $watch.Elapsed.TotalSeconds -lt $oneAttemptSec) {
                try { $lockFs = [IO.File]::Open("$path.lock", [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
                catch [System.IO.IOException] {
                    Start-Sleep -Milliseconds $delay
                    $delay = [Math]::Min($delay * 2, 500)
                }
            }
        }
        if ($null -eq $lockFs) { $script:MachineHealthLastError = 'lock timeout'; return $false }
        $cur = Read-MachineHealth -Fresh
        $endpoints = New-Object System.Collections.Generic.List[object]
        $running = New-Object System.Collections.Generic.List[object]
        foreach ($e in @($cur.Endpoints)) { $endpoints.Add($e) }
        foreach ($x in @($cur.Running)) { $running.Add($x) }
        $data = [pscustomobject]@{ endpoints = $endpoints; running = $running }
        # (wave 28b, D13) the journal: held exclusively until the file is written, then emptied (busy:
        # left for the next update). (wave 28c, D10 / F42-6, F44-1) read as BYTES, line by line: a line
        # that parses is applied; one that does not (a torn append of a writer that died) is MOVED to
        # <journal>.bad - appended there with the time - and counted in the warning "health journal: <n>
        # unreadable line(s) kept in <file>"; the journal then loses exactly the bytes that were applied
        # or moved (a prefix), never more - a line that could not be moved stays, and so does everything
        # after it (applied again next time: idempotent).
        $keys = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($e in $endpoints) { [void]$keys.Add((Get-MachineHealthRecordKey $e)) }
        $journalPath = "$path.journal"
        $jBytes = $null
        $jBad = New-Object System.Collections.Generic.List[object]
        if ([IO.File]::Exists($journalPath)) {
            for ($i = 0; $i -lt 20 -and $null -eq $journalFs; $i++) {
                try { $journalFs = New-Object System.IO.FileStream($journalPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) } catch { Start-Sleep -Milliseconds 50 }
            }
            if ($journalFs) {
                $jBytes = New-Object byte[] ([int]$journalFs.Length)
                $journalFs.Position = 0
                $got = 0
                while ($got -lt $jBytes.Length) { $n = $journalFs.Read($jBytes, $got, $jBytes.Length - $got); if ($n -le 0) { break }; $got += $n }
                if ($got -lt $jBytes.Length) { $cut = New-Object byte[] $got; [Array]::Copy($jBytes, $cut, $got); $jBytes = $cut }
                $pos = 0
                while ($pos -lt $jBytes.Length) {
                    $nl = [Array]::IndexOf($jBytes, [byte]10, $pos)
                    $end = $(if ($nl -ge 0) { $nl + 1 } else { $jBytes.Length })
                    $jl = $script:Utf8NoBom.GetString($jBytes, $pos, $end - $pos)
                    if ($jl.Trim()) {
                        $jrec = $null
                        try { $jrec = ConvertFrom-JsonKeepOffset -Text $jl.Trim() } catch { $jrec = $null }
                        if (-not $jrec -or -not (Test-IsJsonObject $jrec) -or -not [string](Get-PropertyValue $jrec 'endpoint' '')) {
                            $jBad.Add([pscustomobject]@{ Start = $pos; End = $end })
                        } elseif ($keys.Add((Get-MachineHealthRecordKey $jrec))) { $endpoints.Add($jrec) }
                    }
                    $pos = $end
                }
            }
        }
        if ($null -ne $AddEndpoint -and $keys.Add((Get-MachineHealthRecordKey $AddEndpoint))) { $endpoints.Add($AddEndpoint) }
        if ($RemovePid -gt 0) { foreach ($x in @($running | Where-Object { [int](Get-PropertyValue $_ 'pid' 0) -eq $RemovePid })) { [void]$running.Remove($x) } }
        if ($null -ne $AddRunning) { $running.Add($AddRunning) }
        # prune: old records whose until has passed; running rows whose process is gone
        $now = [DateTimeOffset]::UtcNow
        $keepE = @($data.endpoints | Where-Object {
                $w = ConvertTo-WhenOffset (Get-PropertyValue $_ 'when' '')
                $u = ConvertTo-WhenOffset (Get-PropertyValue $_ 'until' '')
                # (wave 29b, E15) an ok record stays while its quota mark still blocks
                if ($null -eq $u) { $u = ConvertTo-WhenOffset (Get-PropertyValue (Get-PropertyValue $_ 'quota_mark' $null) 'until' '') }
                ($null -ne $w) -and (($now - $w).TotalHours -le 24 -or ($null -ne $u -and $u -gt $now))
            })
        if ($keepE.Count -gt 500) { $keepE = @($keepE | Select-Object -Last 500) }
        $keepR = @($data.running | Where-Object { Test-PidAlive -ProcessId ([int](Get-PropertyValue $_ 'pid' 0)) -StartTime (ConvertTo-StartIso (Get-PropertyValue $_ 'start_time' '')) })
        $out = [pscustomobject]@{ health_version = 1; endpoints = [object[]]$keepE; running = [object[]]$keepR }
        Write-TextAtomic -Path $path -Text ((ConvertTo-Json -InputObject $out -Depth 6) + "`n")
        $script:MachineHealthCache = $null
        # (D13) applied: the journal is emptied (a crash before this line applies it again - no double);
        # (wave 28c, D10) first the unreadable lines go to <journal>.bad (with the time), then the journal
        # loses exactly the prefix that was applied or moved
        if ($journalFs -and $null -ne $jBytes) {
            $consumed = $jBytes.Length
            if ($jBad.Count -gt 0) {
                $badPath = "$journalPath.bad"
                $moved = $false
                try {
                    $bfs = New-Object System.IO.FileStream($badPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                    try {
                        foreach ($b in $jBad) {
                            $len = $b.End - $b.Start
                            if ($len -gt 0 -and $jBytes[$b.End - 1] -eq 10) { $len-- }
                            $head = $script:Utf8NoBom.GetBytes((Get-IsoTimestamp) + "`t")
                            $bfs.Write($head, 0, $head.Length)
                            $bfs.Write($jBytes, $b.Start, $len)
                            $bfs.WriteByte(10)
                        }
                        $bfs.Flush($true)
                    } finally { $bfs.Dispose() }
                    $moved = $true
                } catch { $moved = $false }
                if ($moved) {
                    $script:MachineHealthJournalNotes.Add("health journal: $($jBad.Count) unreadable line(s) kept in $badPath")
                } else {
                    # not moved: they stay in the journal - with everything from the first of them on
                    $consumed = [int]$jBad[0].Start
                    $script:MachineHealthJournalNotes.Add("health journal: $($jBad.Count) unreadable line(s) could not be moved to $badPath - kept in $journalPath")
                }
            }
            try {
                $rest = $jBytes.Length - $consumed
                if ($rest -le 0) { $journalFs.SetLength(0) }
                else {
                    $journalFs.Position = 0
                    $journalFs.Write($jBytes, $consumed, $rest)
                    $journalFs.SetLength($rest)
                }
                $journalFs.Flush()
            } catch { }
        }
        return $true
    } catch {
        $script:MachineHealthLastError = "write failed: $(ConvertTo-OneLine $_.Exception.Message)"
        return $false
    } finally {
        if ($journalFs) { try { $journalFs.Dispose() } catch { } }
        if ($lockFs) { try { $lockFs.Dispose() } catch { } }
    }
}

# A run's outcome on an endpoint into the machine file: a usable reply (class ok) or its provider
# failure ($Failure: the ledger's provider_failure; class operator is not the endpoint's). No-op
# without a fingerprint or a file.
function Add-MachineHealthRecord {
    param([string]$Fingerprint, [string]$Outcome, $Failure = $null, [string]$Repo = '', [int]$Attempts = 3, [double]$AttemptSec = 0, $Record = $null, $QuotaMark = $null)
    # (wave 26c, D2) a record that is not written for another reason is no lock timeout
    $script:MachineHealthLastError = ''
    if (-not $Fingerprint -or -not (Get-MachineHealthPath)) { return $false }
    # (wave 28b, D13) the caller's record (the one it journaled), else built here
    $rec = $(if ($null -ne $Record) { $Record } else { New-MachineHealthRecord -Fingerprint $Fingerprint -Outcome $Outcome -Failure $Failure -Repo $Repo -QuotaMark $QuotaMark })
    if ($null -eq $rec) { return $false }
    return (Update-MachineHealth -AddEndpoint $rec -Attempts $Attempts -AttemptSec $AttemptSec)
}

# (wave 28b, D13) The endpoint record of a run's outcome (see Add-MachineHealthRecord), or $null when
# there is none (no fingerprint, class operator, neither usable nor a provider failure). Its `when`
# is fixed here, so the journaled record and the retried one are the same record. (wave 29b, E15)
# -QuotaMark (engine_run.quota_mark of a usable reply): the ok record carries it as quota_mark {class
# quota, kind, until (its reset, else its time + 60 min, 10 for a burst), retry_after, message, when}.
function New-MachineHealthRecord {
    param([string]$Fingerprint, [string]$Outcome, $Failure = $null, [string]$Repo = '', $QuotaMark = $null)
    if (-not $Fingerprint) { return $null }
    $now = [DateTimeOffset]::Now
    $rec = $null
    if (Test-UsableOutcome $Outcome) {
        $rec = [pscustomobject]@{ endpoint = $Fingerprint; class = 'ok'; kind = ''; until = $null; retry_after = $null; repo = $Repo; when = (Format-OffsetIso $now); message = '' }
        if ($null -ne $QuotaMark -and [string](Get-PropertyValue $QuotaMark 'class' '') -eq 'quota') {
            $mWhen = ConvertTo-WhenOffset (Get-PropertyValue $QuotaMark 'when' '')
            if ($null -eq $mWhen) { $mWhen = $now }
            $mKind = [string](Get-PropertyValue $QuotaMark 'kind' '')
            $mRa = ConvertTo-WhenOffset (Get-PropertyValue $QuotaMark 'retry_after' '')
            $mUntil = $(if ($null -ne $mRa) { $mRa } else { $mWhen.AddMinutes($(if ($mKind -eq 'burst') { $script:BurstOutMinutes } else { $script:QuotaOutMinutes })) })
            $mMsg = [string](Get-PropertyValue $QuotaMark 'message' '')
            if ($mMsg.Length -gt 200) { $mMsg = $mMsg.Substring(0, 200) }
            $rec | Add-Member -NotePropertyName 'quota_mark' -NotePropertyValue ([pscustomobject]@{ class = 'quota'; kind = $mKind; until = (Format-OffsetIso $mUntil); retry_after = $(if ($null -ne $mRa) { Format-OffsetIso $mRa } else { $null }); message = $mMsg; when = (Format-OffsetIso $mWhen) })
        }
    } elseif ($null -ne $Failure) {
        $cls = [string](Get-PropertyValue $Failure 'class' '')
        if (-not $cls -or $cls -eq 'operator') { return $null }
        $when = ConvertTo-WhenOffset (Get-PropertyValue $Failure 'when' '')
        if ($null -eq $when) { $when = $now }
        $kind = [string](Get-PropertyValue $Failure 'kind' '')
        $until = $null
        $ra = $null
        if ($cls -eq 'quota') {
            $ra = ConvertTo-WhenOffset (Get-PropertyValue $Failure 'retry_after' '')
            if ($null -ne $ra) { $until = $ra } else { $until = $when.AddMinutes($(if ($kind -eq 'burst') { $script:BurstOutMinutes } else { $script:QuotaOutMinutes })) }
        } elseif ($cls -eq 'auth') { $until = $when.AddHours(24) }
        $msg = [string](Get-PropertyValue $Failure 'message' '')
        if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) }
        $rec = [pscustomobject]@{ endpoint = $Fingerprint; class = $cls; kind = $kind; until = $(if ($null -ne $until) { Format-OffsetIso $until } else { $null }); retry_after = $(if ($null -ne $ra) { Format-OffsetIso $ra } else { $null }); repo = $Repo; when = (Format-OffsetIso $when); message = $msg }
    }
    return $rec
}

# This run's row in running[] while its engine turns run (the bridge's pid and start time).
# (wave 29b, E16) -Plan: the roster entry's plan - the row carries it when there is one, so a panel
# elsewhere counts this run against the plan's limit too (Get-MachineRunningCount -Plans).
function Register-MachineRunning {
    param([string]$Fingerprint, [string]$Label = '', [string]$Repo = '', [string]$Task = '', [string]$Nn = '', [string]$Panel = '', [string]$Plan = '')
    if (-not $Fingerprint -or -not (Get-MachineHealthPath)) { return $false }
    $row = [pscustomobject]@{ endpoint = $Fingerprint; label = $Label; pid = $PID; start_time = [string](Get-ProcessStartIso -ProcessId $PID); repo = $Repo; task = $Task; nn = $Nn; panel = $Panel; since = (Get-IsoTimestamp) }
    if ($Plan) { $row | Add-Member -NotePropertyName 'plan' -NotePropertyValue $Plan }
    return (Update-MachineHealth -AddRunning $row -RemovePid $PID)
}

function Unregister-MachineRunning {
    if (-not (Get-MachineHealthPath)) { return $false }
    if (@((Read-MachineHealth -Fresh).Running | Where-Object { [int](Get-PropertyValue $_ 'pid' 0) -eq $PID }).Count -eq 0) { return $true }
    return (Update-MachineHealth -RemovePid $PID)
}

# How many runs of the machine are running on these endpoints outside the panel $ExcludePanel
# (another repository's members, another panel, a single run) - live rows only. (wave 29b, E16)
# -Plans: a row of one of these plans counts too, whatever its endpoint, engine and repository (a
# codex ZAI run of plan zai for a claude ZAI-claude member). { Count; Rows; ByPlan (the rows that
# count only through their plan) }.
function Get-MachineRunningCount {
    param([string[]]$Fingerprints, [string]$ExcludePanel = '', [string[]]$Plans = @())
    $planSet = @(@($Plans) | Where-Object { $_ })
    $rows = @((Read-MachineHealth).Running | Where-Object {
            $fp = [string](Get-PropertyValue $_ 'endpoint' '')
            $rp = [string](Get-PropertyValue $_ 'plan' '')
            (($fp -and @($Fingerprints) -contains $fp) -or ($rp -and $planSet -ccontains $rp)) -and -not ($ExcludePanel -and [string](Get-PropertyValue $_ 'panel' '') -eq $ExcludePanel) -and
            (Test-PidAlive -ProcessId ([int](Get-PropertyValue $_ 'pid' 0)) -StartTime (ConvertTo-StartIso (Get-PropertyValue $_ 'start_time' '')))
        })
    $byPlan = @($rows | Where-Object { -not (@($Fingerprints) -contains [string](Get-PropertyValue $_ 'endpoint' '')) })
    return [pscustomobject]@{ Count = $rows.Count; Rows = [object[]]$rows; ByPlan = [object[]]$byPlan }
}

# ----------------------------------------------------------------------------- reviewer roster
#
# The reviewer roster is an ordered list of reviewers the operator is willing to use, first
# choice first. A JSON file (never created by the bridge):
#   CODEX_CONSULT_ROSTER=<path>   that file; it MUST exist (a roster that is asked for and
#                                 missing refuses the run - it is never skipped silently)
#   CODEX_CONSULT_ROSTER=none     no roster at all, the default file is ignored too
#   unset                         <codex home>/codex-consult-roster.json when it exists;
#                                 absent = no roster: everything behaves as without one
#
#   { "roster_version": 1,
#     "reviewers": [ { "provider": "openai", "model": "gpt-5.1" },
#                    { "provider": "ZAI", "model": "glm-5.3" },
#                    { "provider": "local", "model": "m", "auth": "none",
#                      "codex_config": ["model_catalog_json=~/.codex/catalog.json"] } ] }
#
#   provider      required: a [model_providers.<name>] table of the Codex config
#                 (case-sensitive) or openai
#   model         optional: absent = the model resolves as without a roster (the Codex
#                 config's top-level model)
#   codex_config  optional: key=value items with exactly the -CodexConfig rules
#                 (ConvertFrom-CodexConfigItems)
#   auth          optional, only "none": the endpoint needs no credential (a table without
#                 env_key/bearer token then passes the credential check; a table WITH
#                 env_key still needs the variable). (wave 29) Engine claude: "subscription"
#                 (the default - the claude.ai login) or "api-key" (ANTHROPIC_API_KEY)
#   panel         optional, "always" (the default), "weighty" or "light": with -Panel a weighty
#                 reviewer joins only on the weighty purposes (framing, decision,
#                 core-contract, acceptance, stuck) or with -PanelAll; a light one (2026-10-07)
#                 joins on the light purposes and stands in on a weighty purpose only when no
#                 other entry of its provider label runs (every one skipped - unavailable,
#                 context, refused - or none), or with -PanelAll. The single-reviewer walk
#                 ignores it.
#   engine        optional (0.4.0), "codex" (the default) or "agy": the CLI that carries the
#                 consultation. For agy the provider is a free label (the lineage's
#                 provider, e.g. "gemini"), the model is REQUIRED (the full id with its
#                 tier), codex_config and auth are refused, and one label names one engine
#                 across the roster. Two entries with the same label and different models
#                 are fine (e.g. a "panel": "weighty" entry on the pro model). (wave 29) Engine
#                 claude: the model is one of the engine's table ($script:ClaudeModels -
#                 an alias or an id, optionally ending with [1m]) and auth is allowed (above).
#   parallel      optional TOP-LEVEL object (0.4.x wave 21) { "<provider label>": <n> }: a
#                 -Panel runs the members of one endpoint one after another (Get-PanelPlan);
#                 n >= 1 lets that label's members run n at a time. Every key must be a
#                 label the roster uses, every value an integer >= 1.
# Anything else - an unknown key, roster_version other than 1, reviewers not an array or
# empty, the same (provider, model) twice, a file that does not parse - makes the roster
# unusable, and the bridge refuses to run (fail-closed: an existing roster is never
# ignored).
#
# Selection (codex-consult.ps1; codex-providers.ps1 shows the same walk):
#   -Provider given   the roster does not select; the first entry of that provider (by
#                     -Model too when several entries name it) supplies its model when
#                     -Model is empty and its codex_config when -CodexConfig is empty
#   -Thread given     the thread's ledger entry fixes the reviewer; its roster entry
#                     supplies codex_config
#   otherwise         the roster is walked in order and the first entry whose preflight is
#                     available is used (Select-RosterReviewer); every skipped entry is
#                     recorded with its reason. None available: refused.
#   -Panel            the entries the panel seats (Select-PanelMembers, then (wave 26)
#                     Select-PanelRouting: the purpose's size, the draw) run the same brief, each
#                     as a consultation of its own; members of different endpoints at once,
#                     of one endpoint one after another (Get-PanelPlan, roster "parallel").

# Where the roster comes from: { Path ('' when none); FromEnv (CODEX_CONSULT_ROSTER named
# it: it must exist); Disabled (CODEX_CONSULT_ROSTER=none) }.
# ----------------------------------------------------------------------------- companions (wave 26: R14-R16)
#
# Decisions D1-D12 of the companions design round (.collab-independent summary): a panel takes as
# many members as its purpose needs (Get-PanelDefaultSize, -PanelSize), from as many LABS as it can
# (a lab-diversity reserve, D1), chosen by the reviewers' usefulness ratings (-Rate) with a share
# of exploration (D3, D4) - or in roster order until there is evidence (D5); required reviewers
# (-Require, the roster's `require`) take their seats first (D7); a member may take a narrow ROLE
# (D8). The roster gains `lab`, `roles`, `require` and the extension point `ext` (D12).

# The consultation purposes (codex-consult.ps1 -Purpose; the keys of the roster's `require`).
$script:ConsultPurposes = @('framing', 'decision', 'checkpoint', 'core-contract', 'acceptance', 'diff-review', 'stuck', 'chore')
# D8 / D3: a role or topic name is a lowercase slug, checked before any path join.
$script:SlugPattern = '^[a-z0-9][a-z0-9._-]{0,40}$'
# D1: the lab of a model whose roster entry names none, keyed on the model id's PREFIX (never the
# provider label - one label may serve several labs, one lab several labels). First match wins.
# (wave 29) claude, opus, sonnet, haiku, fable: anthropic - the prefix covers the aliases and the ids.
$script:LabVendors = @('qwen=alibaba', 'deepseek=deepseek', 'kimi=moonshot', 'k3=moonshot', 'glm=zhipu', 'dola=bytedance', 'seed=bytedance', 'mimo=xiaomi', 'gemini=google', 'muse=meta', 'gpt=openai', 'claude=anthropic', 'opus=anthropic', 'sonnet=anthropic', 'haiku=anthropic', 'fable=anthropic')
# D6: the default panel size per purpose ('' = no purpose; 0 = every eligible member).
$script:PanelSizes = @{ '' = 1; 'chore' = 1; 'checkpoint' = 1; 'diff-review' = 2; 'framing' = 3; 'decision' = 3; 'core-contract' = 4; 'acceptance' = 4; 'stuck' = 0 }
# D6: the purposes whose panel should hear at least two members (the floor warning).
$script:PanelFloorPurposes = @('framing', 'decision')

# The default size of a panel for $Purpose (D6): chore, none and checkpoint 1, diff-review 2,
# framing and decision 3, core-contract and acceptance 4, stuck every eligible member (0).
function Get-PanelDefaultSize {
    param([string]$Purpose = '')
    if ($script:PanelSizes.ContainsKey($Purpose)) { return [int]$script:PanelSizes[$Purpose] }
    return 1
}

# Names given on the command line or in the roster as canonical slugs (D3, D8): every value split
# at commas (powershell -File binds a [string[]] as ONE string), trimmed, lowercased, empty ones
# dropped, duplicates removed (first one kept). { Items (string[]); Error ('' or the refusal) }.
function ConvertTo-SlugList {
    param([string[]]$Values, [string]$What = 'name')
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($v in @($Values)) {
        if ($null -eq $v) { continue }
        foreach ($piece in ([string]$v).Split(',')) {
            $s = $piece.Trim().ToLowerInvariant()
            if (-not $s) { continue }
            if ($s -notmatch $script:SlugPattern) {
                return [pscustomobject]@{ Items = [string[]]@(); Error = "$What '$($piece.Trim())' is not a slug (lowercase letters, digits, dot, dash, underscore; at most 41 characters, starting with a letter or digit)" }
            }
            if (-not $items.Contains($s)) { $items.Add($s) }
        }
    }
    return [pscustomobject]@{ Items = [string[]]$items.ToArray(); Error = '' }
}

# The lab a model id belongs to by the vendor table (D1), '' when its prefix is unknown.
function Get-ModelLab {
    param([string]$Model)
    $m = ([string]$Model).Trim().ToLowerInvariant()
    if (-not $m) { return '' }
    foreach ($pair in $script:LabVendors) {
        $kv = $pair.Split('=')
        if ($m.StartsWith($kv[0])) { return $kv[1] }
    }
    return ''
}

# The lab of a roster entry (D1): its `lab` (canonical lowercase), else the vendor table on the
# model it resolves to, else a lab of its own - its lineage, lowercased (Source 'singleton'; a
# routed panel warns). { Lab; Source ('roster' | 'vendor' | 'singleton') }. (wave 29b, E5) An
# endpoint entry of the claude engine (a third-party model through the claude CLI): the telemetry
# vendor table by its base URL's HOST first (api.z.ai -> zhipu, *.xiaomimimo.com -> xiaomi,
# api.kimi.ai -> moonshot) - never anthropic because of the engine -, then the model as above.
function Get-EntryLab {
    param($Entry, [string]$Model = '', [string]$Lineage = '')
    $declared = [string](Get-PropertyValue $Entry 'Lab' '')
    if ($declared) { return [pscustomobject]@{ Lab = $declared; Source = 'roster' } }
    $ep = Get-PropertyValue $Entry 'Endpoint' $null
    if ($ep -and [string](Get-PropertyValue $Entry 'Auth' '') -eq 'endpoint') {
        $hv = Get-TelemetryVendorByHost ([string](Get-PropertyValue $ep 'BaseUrl' ''))
        if ($hv -and [string](Get-PropertyValue $hv 'Lab' '')) { return [pscustomobject]@{ Lab = [string]$hv.Lab; Source = 'vendor' } }
    }
    $m = $Model
    if (-not $m) { $m = [string](Get-PropertyValue $Entry 'Model' '') }
    $v = Get-ModelLab $m
    if ($v) { return [pscustomobject]@{ Lab = $v; Source = 'vendor' } }
    $own = $Lineage
    if (-not $own) { $own = Format-ReviewerLineage -Provider ([string]$Entry.Provider) -Model $m -Engine ([string](Get-PropertyValue $Entry 'Engine' '')) }
    return [pscustomobject]@{ Lab = $own.ToLowerInvariant(); Source = 'singleton' }
}

# (wave 27, R13 D3) A reviewer matcher PARSED - the one parser of `#<n>` (a roster position), a
# bare provider label and `<provider> :: <model>`, either of the last two with an optional
# ` [<engine>]` suffix: -Require, the roster's `require` (D7) and CODEX_CONSULT_COORDINATOR all go
# through it. { Kind ('position' | 'label' | 'lineage'); Position (int, 0 unless a position);
# Provider; Model ($null for a label or a position); Engine ('' = any engine); Error ('' or why
# it does not parse) }.
function ConvertFrom-ReviewerMatcher {
    param([string]$Matcher)
    $t = ([string]$Matcher).Trim()
    $r = [pscustomobject]@{ Kind = ''; Position = 0; Provider = ''; Model = $null; Engine = ''; Error = '' }
    if (-not $t) { $r.Error = 'an empty reviewer matcher'; return $r }
    if ($t -match '^#(\d+)$') {
        $r.Kind = 'position'
        $r.Position = [int]$Matches[1]
        return $r
    }
    if ($t -match '^(.*\S)\s+\[([A-Za-z0-9_-]+)\]$') {
        $t = $Matches[1]
        $r.Engine = $Matches[2].ToLowerInvariant()
        if ($script:EngineNames -notcontains $r.Engine) { $r.Error = "'$Matcher' names the engine '$($r.Engine)' (known: $($script:EngineNames -join ', '))"; return $r }
    }
    $r.Kind = 'label'
    $r.Provider = $t
    $sep = $t.IndexOf(' :: ')
    if ($sep -ge 0) {
        $r.Kind = 'lineage'
        $r.Provider = $t.Substring(0, $sep).Trim()
        $r.Model = $t.Substring($sep + 4).Trim()
        if (-not $r.Provider -or -not $r.Model) { $r.Error = "'$Matcher' is not '<provider> :: <model>'"; return $r }
    }
    return $r
}

# (wave 27, R13 D3) Whether a reviewer (its provider, model and engine) is named by a parsed matcher
# of kind label or lineage: the provider ordinal, the model ordinal when the matcher names one, the
# engine when it names one ('' counts as codex) - field by field, never a display string. The one
# comparison of Resolve-ReviewerMatcher (roster entries) and of the coordinator warning (the
# RESOLVED identity of a seated reviewer - Test-CoordinatorReviewer).
function Test-ReviewerMatch {
    param($Parsed, [string]$Provider, [string]$Model, [string]$Engine)
    if (-not $Engine) { $Engine = 'codex' }
    $pModel = Get-PropertyValue $Parsed 'Model' $null
    $pEngine = [string](Get-PropertyValue $Parsed 'Engine' '')
    return [bool]($Provider -ceq [string]$Parsed.Provider -and ($null -eq $pModel -or $Model -ceq [string]$pModel) -and (-not $pEngine -or $Engine -eq $pEngine))
}

# A reviewer matcher (-Require, the roster's `require`; D7) against roster entries: `#<n>` (the
# entry at roster position n), a bare provider label (every entry of it), or `<provider> ::
# <model>` - either form with an optional ` [<engine>]` suffix. Compared field by field on what
# the roster names (provider and model ordinal, the engine), never on a display string; a model-
# less entry is named by its position or its label. { Positions (int[], roster order); Error }.
# (wave 27) Parsed by ConvertFrom-ReviewerMatcher, compared by Test-ReviewerMatch.
function Resolve-ReviewerMatcher {
    param([object[]]$Entries, [string]$Matcher)
    $fail = { param($why) [pscustomobject]@{ Positions = [int[]]@(); Error = $why } }
    $parsedMatcher = ConvertFrom-ReviewerMatcher -Matcher $Matcher
    if ($parsedMatcher.Error) { return (& $fail $parsedMatcher.Error) }
    if ($parsedMatcher.Kind -eq 'position') {
        $pos = [int]$parsedMatcher.Position
        $hit = @($Entries | Where-Object { [int]$_.Position -eq $pos })
        if ($hit.Count -eq 0) { return (& $fail "'$(([string]$Matcher).Trim())' names no roster position (the roster has $(@($Entries).Count) entries)") }
        return [pscustomobject]@{ Positions = [int[]]@($pos); Error = '' }
    }
    $hits = @($Entries | Where-Object { Test-ReviewerMatch -Parsed $parsedMatcher -Provider ([string]$_.Provider) -Model ([string]$_.Model) -Engine ([string]$_.Engine) })
    if ($hits.Count -eq 0) { return (& $fail "'$Matcher' matches no roster entry") }
    return [pscustomobject]@{ Positions = [int[]]@($hits | ForEach-Object { [int]$_.Position }); Error = '' }
}

# The required roster positions of a run (D7): -Require's matchers (explicit - `none` alone means
# no requirement), else the roster's `require` for $Purpose (a -Panel run only: $UseRoster). {
# Positions (int[], roster order, unique); Matchers (string[]); Source ('' | '-Require' | 'roster
# require.<purpose>'); Error }.
function Resolve-RequiredReviewers {
    param($Roster, [string[]]$Require = @(), [string]$Purpose = '', [switch]$Explicit, [switch]$UseRoster)
    $r = [pscustomobject]@{ Positions = [int[]]@(); Matchers = [string[]]@(); Source = ''; Error = '' }
    $matchers = New-Object System.Collections.Generic.List[string]
    if ($Explicit) {
        foreach ($v in @($Require)) { foreach ($p in ([string]$v).Split(',')) { if ($p.Trim()) { $matchers.Add($p.Trim()) } } }
        if ($matchers.Count -eq 1 -and $matchers[0] -ieq 'none') { $r.Source = '-Require none'; return $r }
        if (@($matchers | Where-Object { $_ -ieq 'none' }).Count -gt 0) { $r.Error = "-Require none stands alone (it drops the roster's requirement); do not combine it with reviewers"; return $r }
        $r.Source = '-Require'
    } elseif ($UseRoster -and $Roster -and $Roster.PSObject.Properties['Require'] -and $null -ne $Roster.Require -and $Roster.Require.ContainsKey($Purpose)) {
        foreach ($m in @($Roster.Require[$Purpose])) { $matchers.Add([string]$m) }
        $r.Source = "roster require.$Purpose"
    }
    if ($matchers.Count -eq 0) { return $r }
    if (-not $Roster -or -not $Roster.Exists) { $r.Error = '-Require names reviewers of the roster, and there is no reviewer roster'; return $r }
    $set = New-Object System.Collections.Generic.List[int]
    foreach ($m in $matchers) {
        $res = Resolve-ReviewerMatcher -Entries @($Roster.Entries) -Matcher $m
        if ($res.Error) { $r.Error = "$($r.Source): $($res.Error)"; return $r }
        foreach ($p in $res.Positions) { if (-not $set.Contains([int]$p)) { $set.Add([int]$p) } }
    }
    $r.Positions = [int[]]@($set.ToArray() | Sort-Object)
    $r.Matchers = [string[]]$matchers.ToArray()
    return $r
}

# ----------------------------------------------------------------------------- host (wave 27, R13)
#
# (D4, F04-7) The coordinator's HOST MARKERS: an engine child the bridge starts (the main turn, a
# denial retry, a format repair, the timeout continuation - Start-EngineProcess -, the detached
# background, and the launcher probes `codex login status`, `agy models`, `<launcher> --version`)
# never inherits them, so a nested codex reviewer cannot take its coordinator's session for its
# own. Everything else is kept: CODEX_HOME, the provider keys, PATH, the bridge's own
# CODEX_CONSULT_* variables. The ledger's `child_env_scrubbed` names what was removed (never a
# value). Names: exact, plus every name that starts with a prefix (every CODEX_SANDBOX*, and - wave
# 27c - every ZCODE_*). (wave 27b) The list is completed with what a host session really hands its
# children - a session id, its messaging socket and TOKEN, its attendance, its executable path, its
# pid and effort -, so a reviewer child never inherits the
# coordinator's session channel. EXACT names on purpose, never the whole CLAUDE_CODE_ prefix: the
# operator's own settings (CLAUDE_CODE_USE_BEDROCK and the like) must still reach an engine, and
# CLAUDE_PLUGIN_ROOT / CLAUDE_PLUGIN_DATA (the plugin's own directories) are kept.
# (wave 27c, D21) Z Code: the WHOLE prefix ZCODE_ - what the shell tool of Z Code really carries
# (read inside a Z Code session on 2026-09-29, desktop 3.14.3: ZCODE_APP_VERSION, ZCODE_BASE_URL,
# ZCODE_BUILD_COMMIT_ID, ZCODE_BUILTIN_PROVIDER_CONFIG_FILE, ZCODE_DESKTOP_CONTEXT_PROMPT_ENABLED,
# ZCODE_ENV, ZCODE_PERSONAL_PROVIDER_CONFIG_FILE, ZCODE_PROCESS_LABEL, ZCODE_RG_BINARY,
# ZCODE_RUNTIME_ENV, ZCODE_UGREP_BINARY, ZCODE_WINDOWS_APP_INSTALL_DIR - two of them point at the
# operator's provider configuration files; no reviewer engine reads a ZCODE_ variable); the
# CLAUDE_CODE_ names stay EXACT
$script:HostMarkerNames = @(
    'CODEX_SESSION_ID', 'CODEX_THREAD_ID', 'CODEX_CI',
    'CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT', 'AI_AGENT',
    'CLAUDE_CODE_SESSION_ID', 'CLAUDE_CODE_BRIDGE_SESSION_ID', 'CLAUDE_CODE_CHILD_SESSION',
    'CLAUDE_CODE_MESSAGING_SOCKET', 'CLAUDE_CODE_MESSAGING_TOKEN', 'CLAUDE_CODE_SESSION_ATTENDED',
    'CLAUDE_CODE_EXECPATH', 'CLAUDE_PID', 'CLAUDE_EFFORT'
)
$script:HostMarkerPrefixes = @('CODEX_SANDBOX', 'ZCODE_')

# Whether a variable name is a host marker (Windows: case-insensitive, like its environment).
function Test-HostMarkerName {
    param([string]$Name)
    $n = $Name
    if ($script:OnWindows) { $n = $n.ToUpperInvariant() }
    if ($script:HostMarkerNames -ccontains $n) { return $true }
    foreach ($p in $script:HostMarkerPrefixes) { if ($n.StartsWith($p, [StringComparison]::Ordinal)) { return $true } }
    return $false
}

# (wave 28b, D10 / F36-5) The TEST-MODE variables: CODEX_CONSULT_TEST_MODE and every
# CODEX_CONSULT_TEST_* (case-insensitive). No ENGINE child gets them - the main turn, a denial retry,
# a format repair, the timeout continuation (Start-EngineProcess: Hide-HostMarkers -TestVars) and
# the launcher probes (Remove-HostMarkersFromStartInfo, Start-ProbeProcess, the version probe) - and
# the sender gets only CODEX_CONSULT_TEST_MODE and its own hooks, and only in test mode
# (Get-TelemetrySenderEnvironment). A panel member and a detached background ARE the bridge: they
# keep them. The ledger's child_env_scrubbed keeps naming the host markers only.
function Test-TestVarName {
    param([string]$Name)
    return ([string]$Name).ToUpperInvariant().StartsWith('CODEX_CONSULT_TEST_', [StringComparison]::Ordinal)
}

# The test-mode variables set in THIS process's environment, sorted ordinal: string[].
function Get-TestVarNames {
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($k in @([Environment]::GetEnvironmentVariables().Keys)) {
        $n = [string]$k
        if ((Test-TestVarName $n) -and -not $names.Contains($n)) { $names.Add($n) }
    }
    $arr = [string[]]$names.ToArray()
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return , $arr
}

# The host markers set in THIS process's environment, sorted ordinal: string[] (maybe empty).
function Get-HostMarkerNames {
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($k in @([Environment]::GetEnvironmentVariables().Keys)) {
        $n = [string]$k
        if ((Test-HostMarkerName $n) -and -not $names.Contains($n)) { $names.Add($n) }
    }
    $arr = [string[]]$names.ToArray()
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return , $arr
}

# Removes the host markers from THIS process's environment right before a child is started
# (Start-Process has no environment parameter on Windows PowerShell 5.1: the child inherits the
# process's block) and returns what was removed (name -> value) for Restore-HostMarkers, which the
# caller runs in a `finally` right after the start - the bridge's own process keeps its markers.
# (wave 27c, D3 / F30-2) TRANSACTIONAL: the snapshot of every marker is taken FIRST, the removals
# run inside `try`, and a removal that fails puts back everything removed so far and THROWS
# "host markers could not be hidden (<name>: <why>)" - the caller refuses the start (a child never
# starts with part of the markers). TEST HOOK (test mode only, D14): CODEX_CONSULT_TEST_HIDE_FAIL=
# <name> makes the removal of that marker fail. (wave 28b, D10) -TestVars (an ENGINE child): the
# test-mode variables (Test-TestVarName) are hidden too, in the same transaction.
# (wave 29, D2) -ChildEnv: an engine's ALLOW-listed child environment (Get-ClaudeChildEnvironment):
# every variable of this process outside its Env is removed too, and its own values
# (DISABLE_AUTOUPDATER=1) are set - in the SAME transaction; the saved value of a variable that was
# not set is $null (Restore-HostMarkers removes it again).
function Hide-HostMarkers {
    param([switch]$TestVars, $ChildEnv = $null)
    $saved = [ordered]@{}
    foreach ($n in (Get-HostMarkerNames)) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }
    if ($TestVars) { foreach ($n in (Get-TestVarNames)) { if (-not $saved.Contains($n)) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) } } }
    $sets = [ordered]@{}
    if ($null -ne $ChildEnv) {
        foreach ($k in @([Environment]::GetEnvironmentVariables().Keys)) {
            $n = [string]$k
            if ($n -and -not $n.Contains('=') -and -not $ChildEnv.Env.ContainsKey($n) -and -not $saved.Contains($n)) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }
        }
        foreach ($k in @($ChildEnv.Env.Keys)) {
            $n = [string]$k
            $want = [string]$ChildEnv.Env[$k]
            $cur = [Environment]::GetEnvironmentVariable($n)
            if ($cur -cne $want) {
                if (-not $saved.Contains($n)) { $saved[$n] = $cur }
                $sets[$n] = $want
            }
        }
    }
    $failOn = ([string](Get-TestHookValue 'CODEX_CONSULT_TEST_HIDE_FAIL')).Trim()
    $removed = [ordered]@{}
    $current = ''
    try {
        foreach ($n in @($saved.Keys)) {
            $current = [string]$n
            if ($sets.Contains($current)) { continue }
            if ($failOn -and $current -ieq $failOn) { throw 'the removal was refused (test hook CODEX_CONSULT_TEST_HIDE_FAIL)' }
            # a real null: PowerShell passes $null to a [string] argument as '' - which PowerShell 7
            # (.NET) keeps as an EMPTY variable instead of removing it
            [Environment]::SetEnvironmentVariable($current, [NullString]::Value)
            $removed[$current] = $saved[$current]
        }
        foreach ($n in @($sets.Keys)) {
            $current = [string]$n
            if ($failOn -and $current -ieq $failOn) { throw 'the change was refused (test hook CODEX_CONSULT_TEST_HIDE_FAIL)' }
            [Environment]::SetEnvironmentVariable($current, [string]$sets[$n])
            $removed[$current] = $saved[$current]
        }
    } catch {
        $why = ConvertTo-OneLine $_.Exception.Message
        try { Restore-HostMarkers -Saved $removed } catch { }
        throw "host markers could not be hidden ($($current): $why)"
    }
    return $saved
}

function Restore-HostMarkers {
    param($Saved)
    if ($null -eq $Saved) { return }
    # (wave 29) a saved $null: the variable was not set before (a child environment's own value) - removed
    foreach ($n in @($Saved.Keys)) {
        $v = $Saved[$n]
        if ($null -eq $v) { [Environment]::SetEnvironmentVariable([string]$n, [NullString]::Value) }
        else { [Environment]::SetEnvironmentVariable([string]$n, [string]$v) }
    }
}

# (wave 27c, D3) THE way a child is started without the host markers: hides them (transactional,
# Hide-HostMarkers), runs $Action, restores them in `finally`. A hide that fails runs nothing and
# throws "host markers could not be hidden (<name>: <why>)". Returns what $Action returned.
function Invoke-WithoutHostMarkers {
    param([scriptblock]$Action, [switch]$TestVars)
    $saved = Hide-HostMarkers -TestVars:$TestVars
    try { return (& $Action) } finally { Restore-HostMarkers -Saved $saved }
}

# The same for a ProcessStartInfo (the launcher probes): its environment block without the markers
# and (wave 28b, D10) without the test-mode variables - a probe is an engine CLI.
# (wave 27c, D4 / F30-4) '' when the block holds no marker afterwards, else why not (a removal that
# failed, a marker still there) - never fails open silently: the caller then starts the probe
# through Invoke-WithoutHostMarkers, or skips it. TEST HOOK (test mode only):
# CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL=1 makes this report a failure.
function Remove-HostMarkersFromStartInfo {
    param($StartInfo, [switch]$KeepTestVars)
    if ((Get-TestHookValue 'CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL').Trim() -eq '1') { return 'the start-info block could not be scrubbed (test hook CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL)' }
    try {
        $block = $StartInfo.EnvironmentVariables
        # (-KeepTestVars: the detached background - the bridge itself)
        $drop = { param([string]$n) (Test-HostMarkerName $n) -or (-not $KeepTestVars -and (Test-TestVarName $n)) }
        foreach ($k in @($block.Keys)) { if (& $drop ([string]$k)) { $block.Remove([string]$k) } }
        $left = @(@($block.Keys) | Where-Object { & $drop ([string]$_) })
        if ($left.Count -gt 0) { return "the start-info block still holds $($left -join ', ')" }
        return ''
    } catch { return "the start-info block could not be scrubbed ($(ConvertTo-OneLine $_.Exception.Message))" }
}

# (wave 27c, D4) Starts a launcher probe (`codex login status`, `agy models`, `<launcher> --version`
# and the like) without the host markers: $Make builds a fresh ProcessStartInfo; its block is
# scrubbed (Remove-HostMarkersFromStartInfo); when that fails the probe starts from a FRESH start
# info while the markers are hidden from this process (Invoke-WithoutHostMarkers); when that fails
# too the probe is SKIPPED. { Proc ($null when skipped); Skipped ('' or why); Note ('' or how it was
# started instead) }. Start errors throw, as [Process]::Start does.
$script:ProbeWarnings = New-Object System.Collections.Generic.List[string]
function Start-ProbeProcess {
    param([scriptblock]$Make)
    $r = [pscustomobject]@{ Proc = $null; Skipped = ''; Note = '' }
    $psi = & $Make
    $why = Remove-HostMarkersFromStartInfo $psi
    if (-not $why) { $r.Proc = [System.Diagnostics.Process]::Start($psi); return $r }
    $hidden = $null
    try { $hidden = Hide-HostMarkers -TestVars } catch {
        $r.Skipped = "$why; $(ConvertTo-OneLine $_.Exception.Message)"
        if (-not $script:ProbeWarnings.Contains("a launcher probe was skipped: $($r.Skipped)")) { $script:ProbeWarnings.Add("a launcher probe was skipped: $($r.Skipped)") }
        return $r
    }
    try {
        $fresh = & $Make
        $r.Proc = [System.Diagnostics.Process]::Start($fresh)
        $r.Note = "$why - started with the markers hidden from the bridge's own environment"
    } finally { Restore-HostMarkers -Saved $hidden }
    return $r
}

# (D3, F03-3, F04-5) The coordinator's host - a HINT inferred from its markers, never an identity:
# `codex` (CODEX_SESSION_ID or CODEX_THREAD_ID - looked at FIRST: a codex session started from a
# claude-code session inherits that session's markers, and its own are the innermost), (wave 27b)
# `zcode` (looked at before claude-code: Z Code sets no claude-code marker of its own, so a
# claude-code marker next to its own is taken as inherited) - (wave 27c, D20) ANY variable with the
# prefix ZCODE_ (the shell tool of Z Code carries neither ZCODE_SESSION_ID nor ZCODE_PROJECT_DIR, but
# its ZCODE_APP_VERSION, ZCODE_PROCESS_LABEL and more) -, `claude-code` (CLAUDECODE,
# CLAUDE_CODE_ENTRYPOINT, or AI_AGENT starting with claude-code), else - no marker of any host - the
# install path of the running script. (wave 28b, D11 / F36-4) ANCHORED: the script's root must lie
# UNDER one of the hosts' plugin directories, resolved from the home directory (Get-HostPluginRoots:
# <home>/.claude/plugins/cache/, <home>/.codex/plugins/cache/ and <codex home>/plugins/cache/,
# <home>/.zcode/cli/plugins/cache/, <home>/.qwen/extensions/ -> claude-code, codex, zcode,
# qwen-code); a path that merely CONTAINS such a name (a clone under `.claude/worktrees/...`, a
# directory called `.codex` elsewhere) gives no hint. -HomeDir / -CodexHome: a harness's (default:
# the home and the Codex home of this process). { Host; By ('markers' | 'path' | 'none') }.
function Get-HostPluginRoots {
    param([string]$HomeDir = '', [string]$CodexHome = '')
    if (-not $HomeDir) { $HomeDir = $(if ($HOME) { [string]$HOME } else { [string]$env:USERPROFILE }) }
    if (-not $CodexHome) { $CodexHome = [string](Get-CodexHome) }
    $roots = New-Object System.Collections.Generic.List[object]
    # ([IO.Path]::Combine, not Join-Path: pure string work - Join-Path wants the drive to exist)
    $add = { param([string]$Base, [string[]]$Parts, [string]$HostName) if ($Base) { $pp = $Base; foreach ($x in $Parts) { $pp = [IO.Path]::Combine($pp, $x) }; $roots.Add([pscustomobject]@{ Root = $pp; Host = $HostName }) } }
    & $add $HomeDir @('.claude', 'plugins', 'cache') 'claude-code'
    & $add $HomeDir @('.codex', 'plugins', 'cache') 'codex'
    & $add $CodexHome @('plugins', 'cache') 'codex'
    & $add $HomeDir @('.zcode', 'cli', 'plugins', 'cache') 'zcode'
    & $add $HomeDir @('.qwen', 'extensions') 'qwen-code'
    return , ([object[]]$roots.ToArray())
}
function Get-CoordinatorHostHint {
    param([string]$ScriptPath = $PSScriptRoot, [string]$HomeDir = '', [string]$CodexHome = '')
    $get = { param($n) [string][Environment]::GetEnvironmentVariable($n) }
    if ((& $get 'CODEX_SESSION_ID') -or (& $get 'CODEX_THREAD_ID')) { return [pscustomobject]@{ Host = 'codex'; By = 'markers' } }
    foreach ($k in @([Environment]::GetEnvironmentVariables().Keys)) { if (([string]$k).ToUpperInvariant().StartsWith('ZCODE_') -and (& $get ([string]$k))) { return [pscustomobject]@{ Host = 'zcode'; By = 'markers' } } }
    if ((& $get 'CLAUDECODE') -or (& $get 'CLAUDE_CODE_ENTRYPOINT') -or (& $get 'AI_AGENT').StartsWith('claude-code', [StringComparison]::OrdinalIgnoreCase)) { return [pscustomobject]@{ Host = 'claude-code'; By = 'markers' } }
    $norm = { param([string]$x) try { $f = [IO.Path]::GetFullPath($x) } catch { $f = $x }; $f = $f.Replace('\', '/').TrimEnd('/') + '/'; if ($script:OnWindows) { $f = $f.ToLowerInvariant() }; $f }
    $p = [string]$ScriptPath
    if ($p) {
        $sp = & $norm $p
        foreach ($root in (Get-HostPluginRoots -HomeDir $HomeDir -CodexHome $CodexHome)) {
            $rp = & $norm ([string]$root.Root)
            if ($sp.Length -gt $rp.Length -and $sp.StartsWith($rp, [StringComparison]::Ordinal)) { return [pscustomobject]@{ Host = [string]$root.Host; By = 'path' } }
        }
    }
    return [pscustomobject]@{ Host = 'unknown'; By = 'none' }
}

# The host hint alone (a string) - see Get-CoordinatorHostHint.
function Get-CoordinatorHost {
    param([string]$ScriptPath = $PSScriptRoot)
    return (Get-CoordinatorHostHint -ScriptPath $ScriptPath).Host
}
# (wave 27c, D10 / F30-9) THE character rule of a provider label and a model id - the roster's
# validator and CODEX_CONSULT_COORDINATOR share it: a non-empty string without surrounding blanks
# and without the matcher's and the seed's delimiters ('::', '[', ']', '|', ',', '#' -
# Get-RosterStringProblem). Interior blanks are allowed. '' or why not ("is empty", "has
# surrounding blanks", "must not contain '::'").
function Get-IdentityStringProblem {
    param($Value)
    if (-not ($Value -is [string]) -or -not $Value.Trim()) { return 'is empty' }
    if ($Value -cne $Value.Trim()) { return 'has surrounding blanks' }
    $bad = Get-RosterStringProblem $Value
    if ($bad) { return "must not contain $bad" }
    return ''
}

# (wave 27c, D9) The Codex config's defaults the bridge would run with: { Provider (model_provider,
# else openai); Model (the top-level model, '' when none) } - a model-less roster entry and a bare
# label of the default provider resolve to them.
function Get-CodexConfigDefaults {
    $r = [pscustomobject]@{ Provider = 'openai'; Model = '' }
    try {
        $cfg = Read-CodexConfigSubset -Path (Get-CodexConfigPath)
        if ($cfg.Exists -and $cfg.Ok) {
            $top = $cfg.Tables['']
            if ($top -and $top.Ok) {
                $pp = Get-TomlString -Table $top -Key 'model_provider'
                if ($pp.Present -and -not $pp.Reason -and $pp.Value) { $r.Provider = [string]$pp.Value }
                $mm = Get-TomlString -Table $top -Key 'model'
                if ($mm.Present -and -not $mm.Reason -and $mm.Value) { $r.Model = [string]$mm.Value }
            }
        }
    } catch { }
    return $r
}

# (D3, F03-2, F04-4) The coordinator's identity, resolved ONCE at the start of a run (a panel member
# and a detached background take their run's - never inferred again downstream): the value of
# CODEX_CONSULT_COORDINATOR (optional) parsed by the reviewer matcher (ConvertFrom-ReviewerMatcher)
# - `<provider> :: <model>` [` [<engine>]`], a roster position `#<n>` or a provider label - and the
# host hint (Get-CoordinatorHostHint: markers, else the install path; no warning comes from it).
# (wave 27c, D9 / F30-8, F32-6) A RESOLVED TRIPLE, through the same rules as a seated reviewer: `#n`
# is that entry's provider, its model - else the model the bridge would run (the Codex config's,
# $Defaults) - and its engine; a label is the model of its roster entry (else, for the config's
# own provider, the config's model) - several entries of different models leave the model unnamed;
# a lineage without an engine takes its roster entry's, else codex. (D10) Only a value that cannot be
# PARSED - the matcher's grammar, the shared character rule (Get-IdentityStringProblem) - is refused
# (Error). (D11 / F32-4) A coordinator no roster entry matches is said, not refused: in_roster false.
# (D12 / F32-5) `#n` that names no position here is no refusal: unresolved "#n" and a warning. {
# Record - the ledger's `coordinator` {provider, model, engine, host, host_by (markers | path |
# none), source (explicit | inferred | none), in_roster ($null without a roster or an identity),
# unresolved ($null, or the `#n` that named nothing)}; Error ('' or the refusal); Warnings }.
function Resolve-CoordinatorIdentity {
    param([string]$Value, $Roster = $null, $Defaults = $null, [string]$ScriptPath = $PSScriptRoot)
    $hint = Get-CoordinatorHostHint -ScriptPath $ScriptPath
    if ($null -eq $Defaults) { $Defaults = [pscustomobject]@{ Provider = 'openai'; Model = '' } }
    $r = [pscustomobject]@{ Record = $null; Error = ''; Warnings = [string[]]@() }
    $hasRoster = [bool]($Roster -and $Roster.Exists)
    $mk = {
        param($P, $M, $E, [string]$Src, $InRoster, $Unresolved)
        [pscustomobject]@{ provider = $P; model = $M; engine = $E; host = $hint.Host; host_by = $hint.By; source = $Src; in_roster = $InRoster; unresolved = $Unresolved }
    }
    $v = ([string]$Value).Trim()
    if (-not $v) {
        $r.Record = & $mk $null $null $null $(if ($hint.Host -ne 'unknown') { 'inferred' } else { 'none' }) $null $null
        return $r
    }
    $m = ConvertFrom-ReviewerMatcher -Matcher $v
    # (wave 29, item 9) a coordinator's model id (Claude family) may carry the 1M-context suffix
    # (claude-opus-5-5[1m]): stripped - the comparison is on the model
    if ($null -ne $m.Model -and ([string]$m.Model) -match '(?i)^claude-.*\[1m\]$') { $m.Model = ([string]$m.Model) -replace '(?i)\[1m\]$', '' }
    $why = [string]$m.Error
    if (-not $why -and $m.Kind -ne 'position') {
        $pp = Get-IdentityStringProblem ([string]$m.Provider)
        if ($pp) { $why = "the provider '$($m.Provider)' $pp" }
        elseif ($null -ne $m.Model) { $mp = Get-IdentityStringProblem ([string]$m.Model); if ($mp) { $why = "the model '$($m.Model)' $mp" } }
    }
    if ($why) {
        $r.Error = "CODEX_CONSULT_COORDINATOR='$v' cannot be used: $why - give '<provider> :: <model>' (optionally ' [<engine>]'), a roster position '#<n>' or a provider label; nothing was started."
        return $r
    }
    $entries = @()
    if ($hasRoster) { $entries = @($Roster.Entries) }
    $modelOf = { param($e) if ([string]$e.Model) { [string]$e.Model } elseif (-not [string]$e.Engine -or [string]$e.Engine -eq 'codex') { [string]$Defaults.Model } else { '' } }
    if ($m.Kind -eq 'position') {
        $entry = @($entries | Where-Object { [int]$_.Position -eq [int]$m.Position }) | Select-Object -First 1
        if (-not $entry) {
            $r.Record = & $mk $null $null $null 'explicit' $(if ($hasRoster) { $false } else { $null }) $v
            $r.Warnings = [string[]]@("CODEX_CONSULT_COORDINATOR '$v' names no roster position here$(if ($hasRoster) { " (the roster has $($entries.Count) entries)" } else { ' (there is no reviewer roster)' }) - the coordinator is not known; no self-review warning can be given")
            return $r
        }
        $em = & $modelOf $entry
        $r.Record = & $mk ([string]$entry.Provider) $(if ($em) { $em } else { $null }) $(if ([string]$entry.Engine) { [string]$entry.Engine } else { 'codex' }) 'explicit' $true $null
        return $r
    }
    $hits = @($entries | Where-Object { Test-ReviewerMatch -Parsed $m -Provider ([string]$_.Provider) -Model ([string]$_.Model) -Engine ([string]$_.Engine) })
    $model = $m.Model
    $engine = $(if ($m.Engine) { [string]$m.Engine } else { $null })
    if ($m.Kind -eq 'lineage') {
        if (-not $engine) { $engine = $(if ($hits.Count -gt 0 -and [string]$hits[0].Engine) { [string]$hits[0].Engine } else { 'codex' }) }
    } else {
        # a label: the model of its roster entries when they name ONE model (and one engine); none in
        # the roster - the config's model for the config's own provider
        $models = @($hits | ForEach-Object { & $modelOf $_ } | Where-Object { $_ } | Select-Object -Unique)
        $engines = @($hits | ForEach-Object { if ([string]$_.Engine) { [string]$_.Engine } else { 'codex' } } | Select-Object -Unique)
        if ($hits.Count -gt 0) {
            if ($models.Count -eq 1 -and $engines.Count -eq 1 -and @($hits | Where-Object { -not (& $modelOf $_) }).Count -eq 0) { $model = [string]$models[0]; $engine = [string]$engines[0] }
        } elseif ([string]$m.Provider -ceq [string]$Defaults.Provider -and [string]$Defaults.Model -and (-not $engine -or $engine -eq 'codex')) {
            $model = [string]$Defaults.Model; $engine = 'codex'
        }
    }
    $r.Record = & $mk ([string]$m.Provider) $(if ($model) { [string]$model } else { $null }) $engine 'explicit' $(if ($hasRoster) { [bool]($hits.Count -gt 0) } else { $null }) $null
    return $r
}

# (wave 27c, D9) How a seated reviewer - its RESOLVED provider, model and engine - relates to the
# coordinator: 'own' (provider, model and engine all equal - "the coordinator's own model"),
# 'provider' (the coordinator names only its provider - no model could be resolved - and the
# reviewer is of that provider: the weaker warning), else ''. An explicit identity only (an inferred
# host names no model); the provider and the model compared ordinal.
# (wave 29, item 9) A reviewer of the claude engine: the ENGINE fixes the vendor - the coordinator's
# provider is compared with anthropic (case-insensitive) whatever the roster's label, its engine may
# be unnamed (codex, the default) or claude, and the models after normalising (Test-ClaudeModelMatch:
# [1m] stripped, an alias equal to any id of its family). A coordinator on an Anthropic model sets
# CODEX_CONSULT_COORDINATOR="anthropic :: <its model id>". (wave 29b, E5) That anthropic branch is
# for auth subscription and api-key only: an endpoint entry ($Auth endpoint - a third-party model
# through the claude CLI) is compared as a codex entry is (its label and its model, ordinal).
function Get-CoordinatorMatch {
    param($Coordinator, [string]$Provider, [string]$Model, [string]$Engine, [string]$Auth = '')
    if (-not $Coordinator -or [string](Get-PropertyValue $Coordinator 'source' '') -ne 'explicit') { return '' }
    if ($Engine -eq 'claude' -and $Auth -ne 'endpoint') {
        $ccp = [string](Get-PropertyValue $Coordinator 'provider' '')
        if (-not $ccp -or $ccp -ine 'anthropic') { return '' }
        $cce = [string](Get-PropertyValue $Coordinator 'engine' '')
        if ($cce -and $cce -ne 'codex' -and $cce -ne 'claude') { return '' }
        $ccm = [string](Get-PropertyValue $Coordinator 'model' '')
        if (-not $ccm) { return 'provider' }
        if (Test-ClaudeModelMatch -Pinned $ccm -Served $Model) { return 'own' }
        return ''
    }
    $cp = [string](Get-PropertyValue $Coordinator 'provider' '')
    if (-not $cp -or $cp -cne $Provider) { return '' }
    if (-not $Engine) { $Engine = 'codex' }
    $cm = [string](Get-PropertyValue $Coordinator 'model' '')
    $ce = [string](Get-PropertyValue $Coordinator 'engine' '')
    if ($ce -and $ce -ne $Engine) { return '' }
    if (-not $cm) { return 'provider' }
    if ($cm -ceq $Model -and (-not $ce -or $ce -eq $Engine)) { return 'own' }
    return ''
}

# (D3) Whether a seated reviewer is the coordinator's own model (Get-CoordinatorMatch 'own').
function Test-CoordinatorReviewer {
    param($Coordinator, [string]$Provider, [string]$Model, [string]$Engine, [string]$Auth = '')
    return ((Get-CoordinatorMatch -Coordinator $Coordinator -Provider $Provider -Model $Model -Engine $Engine -Auth $Auth) -eq 'own')
}

# The coordinator as shown (the dry run, the warning): `<provider> :: <model>` (` [<engine>]` when
# not codex), a label alone, or `(no identity given)`; then the host hint and the source; (wave 27c)
# an unresolved `#n`, and "(not in the roster - no reviewer can match it)" (D11).
function Format-CoordinatorText {
    param($Coordinator)
    if (-not $Coordinator) { return '(none)' }
    $p = [string](Get-PropertyValue $Coordinator 'provider' '')
    $m = [string](Get-PropertyValue $Coordinator 'model' '')
    $e = [string](Get-PropertyValue $Coordinator 'engine' '')
    $un = [string](Get-PropertyValue $Coordinator 'unresolved' '')
    $who = '(no identity given - CODEX_CONSULT_COORDINATOR is not set)'
    if ($un) { $who = "$un (names no roster position here)" }
    elseif ($p) {
        $who = $(if ($m) { "$p :: $m" } else { "$p (model not named)" })
        if ($e -and $e -ne 'codex') { $who += " [$e]" }
    }
    $by = [string](Get-PropertyValue $Coordinator 'host_by' 'markers')
    $text = "$who; host $([string](Get-PropertyValue $Coordinator 'host' 'unknown')) ($(if ($by -eq 'path') { 'inferred from the install path, a hint' } else { 'inferred, a hint' })); source $([string](Get-PropertyValue $Coordinator 'source' 'none'))"
    if ((Get-PropertyValue $Coordinator 'in_roster' $null) -eq $false -and -not $un) { $text += ' (not in the roster - no reviewer can match it)' }
    return $text
}

# The coordinator's identity alone, as the console line of D11 names it.
function Format-CoordinatorId {
    param($Coordinator)
    $p = [string](Get-PropertyValue $Coordinator 'provider' '')
    $m = [string](Get-PropertyValue $Coordinator 'model' '')
    $e = [string](Get-PropertyValue $Coordinator 'engine' '')
    $who = $(if ($m) { "$p :: $m" } else { $p })
    if ($e -and $e -ne 'codex') { $who += " [$e]" }
    return $who
}

# The warning when a seated reviewer is the coordinator's own model (D3; not a refusal) - (wave 27c,
# D9) or, -Kind provider, a reviewer of the coordinator's own provider while no model is named.
function Format-CoordinatorWarning {
    param([string]$Lineage, [string]$Kind = 'own')
    if ($Kind -eq 'provider') { return "coordinator: $Lineage is a reviewer from the coordinator's own provider (model not named) (CODEX_CONSULT_COORDINATOR) - it may be the coordinator's own model" }
    return "coordinator: $Lineage is the coordinator's own model (CODEX_CONSULT_COORDINATOR) - a second opinion from the coordinator's own model, not an independent one"
}
function Get-RosterPath {
    $p = ([string]$env:CODEX_CONSULT_ROSTER).Trim()
    if ($p -ieq 'none') { return [pscustomobject]@{ Path = ''; FromEnv = $true; Disabled = $true } }
    if ($p) {
        if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path (Get-Location).Path $p }
        return [pscustomobject]@{ Path = $p; FromEnv = $true; Disabled = $false }
    }
    $codexHome = Get-CodexHome
    $default = ''
    if ($codexHome) { $default = Join-Path $codexHome 'codex-consult-roster.json' }
    return [pscustomobject]@{ Path = $default; FromEnv = $false; Disabled = $false }
}

# { Exists; Path; Disabled (CODEX_CONSULT_ROSTER=none); Entries ({ Position; Provider; Model
# ('' = not given); CodexConfig (string[], already expanded and quoted); Auth ('' | 'none'; claude:
# 'subscription' | 'api-key' | (wave 29b) 'endpoint'); (wave 29b, E1) Endpoint ($null, or with auth
# endpoint ConvertFrom-ClaudeEndpointValue's object: BaseUrl, Canonical, HostName, EnvKey,
# TimeoutMs, Plan); (E5) Plan ('' or the entry's plan slug - any engine);
# Panel ('always' | 'weighty' | 'light'); Engine ('codex' | 'agy'); EngineDeclared (the entry names
# its engine); (wave 26) Lab ('' = not given; canonical lowercase - D1); Roles (string[]: the
# roles it is willing to take - D8) }); Parallel (hashtable, ordinal keys: provider label -> n
# from the top-level "parallel"; empty when absent); (wave 26) Require (hashtable, ordinal keys:
# purpose -> string[] of reviewer matchers from the top-level "require", each resolved to an
# entry at load - D7); Error }. Error is the whole refusal message; the caller stops on it.
# (wave 26, D12) "ext" - an object at the top level and in any entry - is the extension point of
# other implementations that share the file: validated as an object only, never read, never
# written.
# $Location: Get-RosterPath (the default).
# (wave 26b, D3) The first delimiter of the reviewer matcher (`::`, ` [<engine>]`) or of the
# seed text (`|`, `,`) - or `#` (a position matcher) - found in a roster string, quoted, else ''.
# Blanks around the value are refused by the callers' own checks.
function Get-RosterStringProblem {
    param([string]$Value)
    foreach ($d in @('::', '[', ']', '|', ',', '#')) {
        if ($Value.Contains($d)) { return "'$d'" }
    }
    return ''
}

function Read-ReviewerRoster {
    param($Location = $null)
    if ($null -eq $Location) { $Location = Get-RosterPath }
    $Path = [string]$Location.Path
    $r = [pscustomobject]@{ Exists = $false; Path = $Path; Disabled = [bool]$Location.Disabled; Entries = [object[]]@(); Parallel = (New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)); Require = (New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)); Error = '' }
    if ($r.Disabled) { return $r }
    if ($Path -and $Location.FromEnv -and -not (Test-Path -LiteralPath $Path)) {
        $r.Error = "the reviewer roster '$Path' named by CODEX_CONSULT_ROSTER does not exist; unset CODEX_CONSULT_ROSTER to use <codex home>/codex-consult-roster.json when it exists, or set it to none for no roster."
        return $r
    }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $r }
    $r.Exists = $true
    $why = ''
    $data = $null
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $why = 'it is not a file'
    } else {
        $text = Read-SharedText -Path $Path
        if (-not $text.Trim()) { $why = 'it is empty or could not be read' }
        else {
            try { $data = ConvertFrom-Json -InputObject $text } catch { $why = "it does not parse: $(ConvertTo-OneLine $_.Exception.Message)" }
            if (-not $why -and -not (Test-IsJsonObject $data)) { $why = 'the top level is not a JSON object' }
        }
    }
    $entries = New-Object System.Collections.Generic.List[object]
    if (-not $why) {
        foreach ($prop in $data.PSObject.Properties) {
            if (@('roster_version', 'reviewers', 'parallel', 'require', 'ext') -cnotcontains $prop.Name) { $why = "unknown key '$($prop.Name)' at the top level (allowed: roster_version, reviewers, parallel, require, ext)"; break }
        }
    }
    if (-not $why -and $data.PSObject.Properties['ext'] -and -not (Test-IsJsonObject $data.ext)) { $why = "ext must be an object (the extension point of other implementations; got $(ConvertTo-Json -InputObject $data.ext -Compress))" }
    if (-not $why) {
        if (-not $data.PSObject.Properties['roster_version']) { $why = 'roster_version is missing (expected 1)' }
        elseif (-not (Test-IsJsonInteger $data.roster_version) -or [long]$data.roster_version -ne 1) { $why = "roster_version must be 1 (got $(ConvertTo-Json -InputObject $data.roster_version -Compress))" }
    }
    if (-not $why) {
        if (-not $data.PSObject.Properties['reviewers']) { $why = 'reviewers is missing' }
        elseif (-not (Test-IsJsonArray $data.reviewers)) { $why = 'reviewers is not an array' }
        elseif (@($data.reviewers).Count -eq 0) { $why = 'reviewers is empty' }
    }
    if (-not $why) {
        $pos = 0
        foreach ($item in @($data.reviewers)) {
            $pos++
            $at = "entry $pos"
            if (-not (Test-IsJsonObject $item)) { $why = "$at is not an object"; break }
            foreach ($prop in $item.PSObject.Properties) {
                if (@('provider', 'model', 'codex_config', 'auth', 'endpoint', 'plan', 'panel', 'engine', 'lab', 'roles', 'timeout_sec', 'stall_sec', 'context_tokens', 'ext') -cnotcontains $prop.Name) { $why = "$at has an unknown key '$($prop.Name)' (allowed: provider, model, codex_config, auth, endpoint, plan, panel, engine, lab, roles, timeout_sec, stall_sec, context_tokens, ext)"; break }
            }
            if ($why) { break }
            # (wave 26b, D3 / F22-2, F22-4) the matcher's and the seed's delimiters never inside a
            # provider label, a model or an engine: '::', '[', ']', '|', ',', '#'
            # (wave 29) a claude model may end with the 1M-context suffix [1m] - the rest obeys the rule
            $isClaudeItem = ($item.PSObject.Properties['engine'] -and $item.engine -is [string] -and $item.engine -ceq 'claude')
            foreach ($sk in @('provider', 'model', 'engine')) {
                if (-not $item.PSObject.Properties[$sk] -or -not ($item.$sk -is [string])) { continue }
                $sv = [string]$item.$sk
                if ($sk -eq 'model' -and $isClaudeItem) { $sv = $sv -replace '\[1m\]$', '' }
                $bad = Get-RosterStringProblem $sv
                if ($bad) { $why = "roster entry #${pos}: $sk must not contain $bad"; break }
            }
            if ($why) { break }
            # (wave 26b, D11) the entry's own timeout: an integer >= 60 (seconds); (D12) its stall
            # cut: an integer >= 0 (seconds without an event; 0 = off)
            $entryTimeout = 0
            if ($item.PSObject.Properties['timeout_sec']) {
                if (-not (Test-IsJsonInteger $item.timeout_sec) -or [double]$item.timeout_sec -lt 60 -or [double]$item.timeout_sec -gt 86400) { $why = "${at}: timeout_sec must be an integer from 60 to 86400 (seconds; got $(ConvertTo-Json -InputObject $item.timeout_sec -Compress))"; break }
                $entryTimeout = [int]$item.timeout_sec
            }
            # (wave 26b, D16) the reviewer's context window in tokens: an integer >= 32000
            $entryContext = 0
            if ($item.PSObject.Properties['context_tokens']) {
                if (-not (Test-IsJsonInteger $item.context_tokens) -or [double]$item.context_tokens -lt 32000 -or [double]$item.context_tokens -gt 100000000) { $why = "${at}: context_tokens must be an integer from 32000 to 100000000 (the reviewer's context window in tokens, e.g. 256000; got $(ConvertTo-Json -InputObject $item.context_tokens -Compress))"; break }
                $entryContext = [int]$item.context_tokens
            }
            $entryStall = -1
            if ($item.PSObject.Properties['stall_sec']) {
                if (-not (Test-IsJsonInteger $item.stall_sec) -or [double]$item.stall_sec -lt 0 -or [double]$item.stall_sec -gt 86400) { $why = "${at}: stall_sec must be an integer from 0 (off) to 86400 (seconds without an event; got $(ConvertTo-Json -InputObject $item.stall_sec -Compress))"; break }
                $entryStall = [int]$item.stall_sec
            }
            if ($item.PSObject.Properties['ext'] -and -not (Test-IsJsonObject $item.ext)) { $why = "${at}: ext must be an object (the extension point of other implementations; got $(ConvertTo-Json -InputObject $item.ext -Compress))"; break }
            # (wave 29b, E5) the plan (the quota a route shares with the other routes to the same
            # coding plan): a slug, on any entry of any engine
            $entryPlan = ''
            if ($item.PSObject.Properties['plan']) {
                if (-not ($item.plan -is [string]) -or $item.plan -cnotmatch $script:PlanSlugRe) { $why = "${at}: plan must be a slug of 2 to 32 characters - lowercase letters, digits and ""-"", starting with a letter (e.g. ""zai""; got $(ConvertTo-Json -InputObject $item.plan -Compress))"; break }
                $entryPlan = [string]$item.plan
            }
            # (wave 26, D1) the lab: a non-empty string, canonical lowercase
            $lab = ''
            if ($item.PSObject.Properties['lab']) {
                $lv = $item.lab
                if (-not ($lv -is [string]) -or -not $lv.Trim() -or $lv -cne $lv.Trim()) { $why = "${at}: lab must be a non-empty string without surrounding blanks (e.g. ""moonshot""; omit it to take the lab from the model id)"; break }
                $lab = $lv.ToLowerInvariant()
            }
            # (wave 26, D8) the roles the entry is willing to take: an array of role slugs
            $entryRoles = [string[]]@()
            if ($item.PSObject.Properties['roles']) {
                $rv = $item.roles
                $allStrings = (Test-IsJsonArray $rv)
                if ($allStrings) { foreach ($x in @($rv)) { if (-not ($x -is [string])) { $allStrings = $false } } }
                if (-not $allStrings) { $why = "${at}: roles must be an array of role names (e.g. [""security"", ""tests""])"; break }
                $rl = ConvertTo-SlugList -Values ([string[]]@($rv)) -What 'role'
                if ($rl.Error) { $why = "${at}: roles: $($rl.Error)"; break }
                $entryRoles = $rl.Items
            }
            $provider = $null
            if ($item.PSObject.Properties['provider']) { $provider = $item.provider }
            if (Get-IdentityStringProblem $provider) { $why = "$at needs a provider: a non-empty string without surrounding blanks"; break }
            $model = ''
            if ($item.PSObject.Properties['model']) {
                $mv = $item.model
                $mvCheck = $(if ($isClaudeItem -and $mv -is [string]) { $mv -replace '\[1m\]$', '' } else { $mv })
                if (Get-IdentityStringProblem $mvCheck) { $why = "${at}: model must be a non-empty string without surrounding blanks (omit it to use the Codex config's model)"; break }
                $model = $mv
            }
            $cfgItems = [string[]]@()
            if ($item.PSObject.Properties['codex_config']) {
                $cv = $item.codex_config
                $allStrings = (Test-IsJsonArray $cv)
                if ($allStrings) { foreach ($x in @($cv)) { if (-not ($x -is [string])) { $allStrings = $false } } }
                if (-not $allStrings) { $why = "${at}: codex_config must be an array of key=value strings"; break }
                $parsed = ConvertFrom-CodexConfigItems -Values ([string[]]@($cv)) -Label 'codex_config'
                if ($parsed.Error) { $why = "${at}: $($parsed.Error.TrimEnd([char]'.'))"; break }
                $cfgItems = $parsed.Items
            }
            $auth = ''
            if ($item.PSObject.Properties['auth']) {
                # (wave 29) claude takes subscription | api-key (wave 29b: | endpoint) - checked below,
                # once the engine is known
                if ($isClaudeItem) {
                    if (-not ($item.auth -is [string]) -or $script:ClaudeAuthModes -cnotcontains $item.auth) { $why = "${at}: auth of engine claude must be ""subscription"" (the claude.ai login, the default) or ""api-key"" (ANTHROPIC_API_KEY) or ""endpoint"" (a third-party Anthropic-compatible endpoint named by the entry's ""endpoint"") (got $(ConvertTo-Json -InputObject $item.auth -Compress))"; break }
                    $auth = [string]$item.auth
                } else {
                    if (-not ($item.auth -is [string]) -or $item.auth -cne 'none') { $why = "${at}: auth may only be ""none"" (an endpoint that needs no credential; omit it otherwise)"; break }
                    $auth = 'none'
                }
            }
            $panelWeight = 'always'
            if ($item.PSObject.Properties['panel']) {
                if (-not ($item.panel -is [string]) -or @('always', 'weighty', 'light') -cnotcontains $item.panel) { $why = "${at}: panel must be ""always"", ""weighty"" or ""light"" (got $(ConvertTo-Json -InputObject $item.panel -Compress))"; break }
                $panelWeight = $item.panel
            }
            $engine = 'codex'
            $engineDeclared = $false
            if ($item.PSObject.Properties['engine']) {
                if (-not ($item.engine -is [string]) -or $script:EngineNames -cnotcontains $item.engine) { $why = "${at}: engine must be one of: $($script:EngineNames -join ', ') (got $(ConvertTo-Json -InputObject $item.engine -Compress))"; break }
                $engine = $item.engine
                $engineDeclared = $true
            }
            if ($engine -ne 'codex') {
                if (-not $model) { $why = "${at}: engine $engine needs a model (the full model id, e.g. $((Get-EngineSpec $engine).ModelExample))"; break }
                if ($item.PSObject.Properties['codex_config']) { $why = "${at}: codex_config does not apply to engine $engine (it configures codex exec)"; break }
                if ($item.PSObject.Properties['auth'] -and $engine -ne 'claude') { $why = "${at}: auth does not apply to engine $engine (the $engine CLI keeps its own sign-in)"; break }
            }
            # (wave 29, item 8, D4) a claude entry: a model of the engine's table; auth defaults to
            # subscription. (wave 29b, E1, E2) auth endpoint: the `endpoint` object is REQUIRED (and
            # refused with every other auth and engine), the model is the open id pattern
            $entryEndpoint = $null
            if ($engine -eq 'claude') {
                if (-not $auth) { $auth = 'subscription' }
                $mp = Get-ClaudeModelProblem $model -Auth $auth
                if ($mp) { $why = "${at}: the claude model '$model' $mp"; break }
            }
            if ($item.PSObject.Properties['endpoint'] -and -not ($engine -eq 'claude' -and $auth -eq 'endpoint')) { $why = "${at}: endpoint applies only to engine claude with auth ""endpoint"" (this entry: engine $engine$(if ($engine -eq 'claude') { ", auth $auth" }))"; break }
            if ($engine -eq 'claude' -and $auth -eq 'endpoint') {
                if (-not $item.PSObject.Properties['endpoint']) { $why = "${at}: auth ""endpoint"" needs an ""endpoint"" object {""base_url"": ""https://..."", ""env_key"": ""<VARIABLE NAME>""} - the Anthropic-compatible endpoint and the variable that holds its token"; break }
                $epv = ConvertFrom-ClaudeEndpointValue -Value $item.endpoint -Plan $entryPlan
                if ($epv.Error) { $why = "${at}: $($epv.Error)"; break }
                $entryEndpoint = $epv.Endpoint
            }
            $other = @($entries | Where-Object { $_.Provider -ceq $provider -and $_.Engine -ne $engine }) | Select-Object -First 1
            if ($other) { $why = "entries $($other.Position) and $pos use the provider label '$provider' with two engines ($($other.Engine), $engine); a label names one engine"; break }
            $dup = @($entries | Where-Object { $_.Provider -ceq $provider -and $_.Model -ceq $model }) | Select-Object -First 1
            if ($dup) {
                $label = if ($model) { Format-Lineage -Provider $provider -Model $model } else { "$provider (no model)" }
                $why = "entries $($dup.Position) and $pos are the same reviewer $label"; break
            }
            $entries.Add([pscustomobject]@{ Position = $pos; Provider = $provider; Model = $model; CodexConfig = $cfgItems; Auth = $auth; Panel = $panelWeight; Engine = $engine; EngineDeclared = $engineDeclared; Lab = $lab; Roles = $entryRoles; TimeoutSec = $entryTimeout; StallSec = $entryStall; ContextTokens = $entryContext; Endpoint = $entryEndpoint; Plan = $entryPlan })
        }
    }
    if (-not $why -and $data.PSObject.Properties['parallel']) {
        $pv = $data.parallel
        if (-not (Test-IsJsonObject $pv)) {
            $why = "parallel must be an object {""<provider label>"": <n>} (got $(ConvertTo-Json -InputObject $pv -Compress))"
        } else {
            # (wave 29b, E7) a key names a provider label or a plan (the plan's scheduling group)
            foreach ($prop in $pv.PSObject.Properties) {
                if (@($entries | Where-Object { $_.Provider -ceq $prop.Name -or ($_.Plan -and $_.Plan -ceq $prop.Name) }).Count -eq 0) { $why = "parallel names the provider label '$($prop.Name)', which no entry of the roster uses (as its provider label or its plan)"; break }
                if (-not (Test-IsJsonInteger $prop.Value) -or [double]$prop.Value -lt 1) { $why = "parallel.$($prop.Name) must be an integer >= 1 (got $(ConvertTo-Json -InputObject $prop.Value -Compress))"; break }
                $r.Parallel[$prop.Name] = [int]$prop.Value
            }
        }
    }
    # (wave 26, D7) the required reviewers per purpose: every matcher must name an entry
    if (-not $why -and $data.PSObject.Properties['require']) {
        $qv = $data.require
        if (-not (Test-IsJsonObject $qv)) {
            $why = "require must be an object {""<purpose>"": [""<reviewer>"", ...]} (got $(ConvertTo-Json -InputObject $qv -Compress))"
        } else {
            foreach ($prop in $qv.PSObject.Properties) {
                if ($script:ConsultPurposes -cnotcontains $prop.Name) { $why = "require names the purpose '$($prop.Name)' (known: $($script:ConsultPurposes -join ', '))"; break }
                $ok = (Test-IsJsonArray $prop.Value) -and @($prop.Value).Count -gt 0
                if ($ok) { foreach ($x in @($prop.Value)) { if (-not ($x -is [string]) -or -not $x.Trim()) { $ok = $false } } }
                if (-not $ok) { $why = "require.$($prop.Name) must be a non-empty array of reviewers (""#<position>"", ""<provider>"" or ""<provider> :: <model>"", optionally with "" [<engine>]"")"; break }
                foreach ($x in @($prop.Value)) {
                    $res = Resolve-ReviewerMatcher -Entries ([object[]]$entries.ToArray()) -Matcher $x
                    if ($res.Error) { $why = "require.$($prop.Name): $($res.Error)"; break }
                }
                if ($why) { break }
                $r.Require[$prop.Name] = [string[]]@($prop.Value | ForEach-Object { $_.Trim() })
            }
        }
    }
    if ($why) {
        $r.Error = "the reviewer roster '$Path' is not usable: $why. Fix it or move it aside - an existing roster is never ignored (CODEX_CONSULT_ROSTER names another file)."
        return $r
    }
    $r.Entries = [object[]]$entries.ToArray()
    return $r
}

# The roster entry of a provider (-Provider, or a thread's reviewer): the first entry that
# names it; when several do and $Model is given, the first whose model equals $Model. $null
# when none names it.
function Find-RosterEntry {
    param($Roster, [string]$Provider, [string]$Model = '')
    if (-not $Roster -or -not $Roster.Exists) { return $null }
    $byProvider = @($Roster.Entries | Where-Object { $_.Provider -ceq $Provider })
    if ($byProvider.Count -eq 0) { return $null }
    if ($Model -and $byProvider.Count -gt 1) {
        $exact = @($byProvider | Where-Object { $_.Model -ceq $Model }) | Select-Object -First 1
        if ($exact) { return $exact }
    }
    return $byProvider[0]
}

# The preflight decision for one identity, local checks only (credentials, then the
# endpoint's recorded health): { State available|unavailable|unknown; Preflight (the
# ledger's preflight text); Reason (one phrase: why a roster walk skips it); Refusal (the
# refusal message of a real run); Label (the dry-run line); (wave 24, D14 - what every
# availability surface shows) Kind ('' | identity | unresolved | credentials | auth | quota |
# quota-unknown-reset | unknown); Hit and Until (DateTimeOffset or $null: when the recorded
# failure happened and when the endpoint is expected back - a known reset, or Hit + 60 min, or
# (wave 24c) Hit + 10 min for a burst); Credential (the credential result, $null before the
# check); Burst (wave 24c: the quota-unknown-reset is a burst - a 429 that names no usage window or
# quota: "burst limit (429) hit <iso>, reset unknown; retry after <iso + 10 min>") }. In this order:
#   identity error / unresolved  unavailable / unknown
#   credentials missing          unavailable (Get-ProviderCredential, Get-EngineCredential)
#   auth failure <= 24 h         unavailable: auth failed <when>: <message>
#   usage limit with a known     unavailable: usage limit until <iso>
#   reset in the future
#   usage limit without a reset  unavailable: usage limit hit <iso>, reset unknown; retry
#   time, hit < 60 min ago       after <iso + 60 min> - for EVERY caller (wave 24b, F08-7: an
#                                explicit -Provider run too, not only the roster walk, the
#                                panel and the views; -RosterWalk changes the refusal's
#                                wording only - a direct run names -SkipPreflight)
#   a burst (wave 24c) without  unavailable: burst limit (429) hit <iso>, reset unknown;
#   a reset, hit < 10 min ago    retry after <iso + 10 min> (Burst; Kind quota-unknown-reset)
#   credentials unknown          unknown (wave 24: a recorded auth failure or usage limit
#                                outranks a sign-in that was not checked - the hook's
#                                -NoNetwork line names what is out)
# $Health: Get-EndpointHealth of the identity's endpoint ($null: none known).
function Get-PreflightVerdict {
    param($Identity, $Config, [string]$Launcher, $Health, [hashtable]$LoginCache = $null, [switch]$Anonymous, [switch]$RosterWalk, [switch]$NoNetwork)
    $v = [pscustomobject]@{ State = 'available'; Preflight = ''; Reason = ''; Refusal = ''; Label = ''; Kind = ''; Hit = $null; Until = $null; Credential = $null; Burst = $false }
    $p = [string]$Identity.Provider
    $engine = [string]$Identity.Engine
    if (-not $engine) { $engine = 'codex' }
    if ($Identity.Error) {
        $v.State = 'unavailable'
        $v.Kind = 'identity'
        $v.Reason = $Identity.Error
        $v.Preflight = "unavailable: $($Identity.Error)"
        $v.Refusal = $Identity.Error
        $v.Label = "unavailable ($($Identity.Error)) - a real run is refused"
        return $v
    }
    if (-not $Identity.Resolved) {
        $reason = "reviewer identity unresolved: $($Identity.Note)"
        $v.State = 'unknown'
        $v.Kind = 'unresolved'
        $v.Preflight = "unknown: $reason"
        $v.Reason = $v.Preflight
        $v.Refusal = "provider $($p): availability could not be established ($reason); pass -SkipPreflight to launch anyway, or fix the check"
        $v.Label = "unknown ($reason) - a real run is refused: $($v.Refusal)"
        return $v
    }
    if ($engine -ne 'codex') {
        # An engine keeps its own sign-in: its credential check (agy: `agy models`, or a usable
        # reply on this endpoint within the last 60 minutes - the auth / quota rules below
        # still apply).
        $cred = Get-EngineCredential -Engine $engine -Launcher $Launcher -LoginCache $LoginCache -NoNetwork:$NoNetwork -Health $Health -Auth ([string](Get-PropertyValue $Identity 'Auth' '')) -Endpoint (Get-PropertyValue $Identity 'Endpoint' $null)
    } else {
        $table = $null
        if ($Config -and $Config.Exists -and $Config.Ok) {
            $pt = Get-ProviderTable -Config $Config -Name $p
            if ($pt.Found) { $table = $pt.Table }
        }
        $cred = Get-ProviderCredential -Name $p -Table $table -Launcher $Launcher -LoginCache $LoginCache -Anonymous:$Anonymous
    }
    $v.Credential = $cred
    $v.Preflight = $cred.Detail
    $v.Reason = $cred.Detail
    if ($cred.State -eq 'missing') {
        $v.State = 'unavailable'
        $v.Kind = 'credentials'
        $v.Refusal = "provider $p is not usable: $($cred.Reason); nothing was started (run codex-providers.ps1 for the full picture)"
        $v.Label = "unavailable ($($cred.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($Health -and $Health.Auth) {
        $v.State = 'unavailable'
        $v.Kind = 'auth'
        $v.Hit = $Health.Auth.Hit
        $v.Reason = "auth failed $($Health.Auth.When): $($Health.Auth.Message)"
        $v.Preflight = "unavailable: $($v.Reason)"
        $v.Refusal = "provider $p is not usable: the last run on this endpoint was rejected as unauthenticated at $($Health.Auth.When) ($($Health.Auth.Message)); if you rotated the credential, pass -SkipPreflight once"
        $v.Label = "unavailable ($($v.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($Health -and $Health.Quota -and $Health.QuotaKnown) {
        $v.State = 'unavailable'
        $v.Kind = 'quota'
        $v.Hit = $Health.Quota.Hit
        $v.Until = $Health.Quota.RetryAfter
        $v.Reason = "usage limit until $($Health.Quota.RetryAfterIso)"
        $v.Preflight = "unavailable: $($v.Reason)"
        $v.Refusal = "provider $p is not usable: its usage limit (hit at $($Health.Quota.When): $($Health.Quota.Message)) lasts until $($Health.Quota.RetryAfterIso); nothing was started (pass -SkipPreflight to launch anyway)"
        $v.Label = "unavailable ($($v.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($Health -and $Health.Quota) {
        # (wave 24b, F08-7) the 60-minute rule is the verdict of every caller; (wave 24c) a burst - a
        # 429 that names no usage window or quota - is out for 10 minutes
        $untilIso = Format-OffsetIso $Health.Quota.Until
        $v.State = 'unavailable'
        $v.Kind = 'quota-unknown-reset'
        $v.Burst = ([string](Get-PropertyValue $Health.Quota 'FailureKind' '') -eq 'burst')
        $v.Hit = $Health.Quota.Hit
        $v.Until = $Health.Quota.Until
        $outMin = Get-PropertyValue $Health.Quota 'OutMinutes' $script:QuotaOutMinutes
        $v.Reason = "$(if ($v.Burst) { 'burst limit (429)' } else { 'usage limit' }) hit $($Health.Quota.HitIso), reset unknown; retry after $untilIso"
        $v.Preflight = "unavailable: $($v.Reason)"
        $v.Refusal = "provider $p is not usable: it hit a $(if ($v.Burst) { 'burst' } else { 'usage' }) limit at $($Health.Quota.HitIso) ($($Health.Quota.Message)$(if ($v.Burst) { ' - a 429 that names no usage limit or quota' })) and named no reset time - out for $outMin minutes, until $untilIso; nothing was started$(if (-not $RosterWalk) { ' (pass -SkipPreflight to launch anyway)' })"
        $v.Label = "unavailable ($($v.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($cred.State -eq 'unknown') {
        $v.State = 'unknown'
        $v.Kind = 'unknown'
        $v.Refusal = "provider $($p): availability could not be established ($($cred.Reason)); pass -SkipPreflight to launch anyway, or fix the check"
        $v.Label = "unknown ($($cred.Reason)) - a real run is refused: $($v.Refusal)"
    } else {
        $v.Label = "available ($($cred.Detail))"
    }
    return $v
}

# (wave 29b, E5) THE PLAN identity (quota). A roster entry's optional `plan` names the coding plan
# whose quota its route spends - the same plan can be reached on several routes (z.ai through codex
# as ZAI and through the claude engine as ZAI-claude). The health records of EVERY route of the plan (the
# fingerprints of the roster's entries with that plan) are read as one record set
# (Get-EndpointHealth -Fingerprints): when its newest {usable reply, quota failure} is a quota
# failure that still blocks (a usage limit with a reset ahead, or without one for 60 minutes, a
# burst for 10), the plan is out until that time. Auth, transport and capability failures stay
# route-local; without a `plan` nothing propagates. { Plan; Quota (the blocking record, with its
# Fingerprint; $null); QuotaKnown; Label (the provider label of the route it was recorded on - the
# first roster entry of the plan on that fingerprint) }. Cached in a listing cache per plan and clock.
function Get-PlanQuota {
    param($Roster, [string]$Plan, $Config, [object[]]$Consults, [string]$Launcher = '', [hashtable]$EngineLaunchers = $null, [datetime]$UtcNow = [datetime]::UtcNow, [string]$OpenAiBaseUrl = '', [hashtable]$Cache = $null)
    $use = Test-ListingCache $Cache
    $key = Get-ListingCacheKey @('plan', $Plan, [string]$UtcNow.Ticks)
    if ($use -and $Cache.ContainsKey($key)) { return $Cache[$key] }
    $r = [pscustomobject]@{ Plan = $Plan; Quota = $null; QuotaKnown = $false; Label = '' }
    $labelOf = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    $fps = New-Object System.Collections.Generic.List[string]
    foreach ($e in @(@($Roster.Entries) | Where-Object { $_ -and [string](Get-PropertyValue $_ 'Plan' '') -ceq $Plan })) {
        $eng = $(if ([string](Get-PropertyValue $e 'Engine' '')) { [string]$e.Engine } else { 'codex' })
        $lau = Get-EngineLauncher -Engine $eng -Launchers $EngineLaunchers -CodexLauncher $Launcher
        $id = Get-CachedReviewerIdentity -Cache $Cache -Config $Config -Provider ([string]$e.Provider) -Model ([string]$e.Model) -OpenAiBaseUrl $OpenAiBaseUrl -Engine $eng -Launcher $lau -Auth ([string]$e.Auth) -Endpoint (Get-PropertyValue $e 'Endpoint' $null)
        if (-not $id.Resolved -or -not $id.Fingerprint) { continue }
        if (-not $labelOf.ContainsKey([string]$id.Fingerprint)) { $labelOf[[string]$id.Fingerprint] = [string]$e.Provider; $fps.Add([string]$id.Fingerprint) }
    }
    if ($fps.Count -gt 0) {
        $h = Get-EndpointHealth -Consults $Consults -Fingerprints ([string[]]$fps.ToArray()) -UtcNow $UtcNow
        if ($h.Quota) {
            $r.Quota = $h.Quota
            $r.QuotaKnown = $h.QuotaKnown
            $r.Label = [string]$labelOf[[string]$h.Quota.Fingerprint]
        }
    }
    if ($use) { $Cache[$key] = $r }
    return $r
}

# (wave 29b, E5) A preflight verdict ($Verdict: Get-PreflightVerdict's for $Identity) with the plan
# quota of its roster entry applied: an entry whose own verdict is available or not checked is OUT
# when its plan is (Get-PlanQuota) on ANOTHER route - "plan <slug> (usage limit on <label> until
# <iso>)", or without a reset time "plan <slug> (usage limit on <label> hit <iso>, reset unknown;
# retry after <iso>)"; Kind quota | quota-unknown-reset, Hit and Until of that record, PlanQuota {
# Plan; Label } for the availability views. Any other verdict, an entry without a plan, a plan with
# no blocking record (or one recorded on this entry's own route - its own verdict says it): $Verdict
# unchanged.
function Get-PlanQuotaVerdict {
    param($Verdict, $Entry, $Identity, $Roster, $Config, [object[]]$Consults, [string]$Launcher = '', [hashtable]$EngineLaunchers = $null, [datetime]$UtcNow = [datetime]::UtcNow, [string]$OpenAiBaseUrl = '', [hashtable]$Cache = $null, [switch]$RosterWalk)
    $plan = [string](Get-PropertyValue $Entry 'Plan' '')
    if (-not $plan -or -not $Verdict -or -not $Roster) { return $Verdict }
    if (-not ($Verdict.State -eq 'available' -or ($Verdict.State -eq 'unknown' -and $Verdict.Kind -eq 'unknown'))) { return $Verdict }
    $pq = Get-PlanQuota -Roster $Roster -Plan $plan -Config $Config -Consults $Consults -Launcher $Launcher -EngineLaunchers $EngineLaunchers -UtcNow $UtcNow -OpenAiBaseUrl $OpenAiBaseUrl -Cache $Cache
    if (-not $pq.Quota) { return $Verdict }
    $ownFp = $(if ($Identity -and $Identity.Resolved) { [string]$Identity.Fingerprint } else { '' })
    if ($ownFp -and [string]$pq.Quota.Fingerprint -eq $ownFp) { return $Verdict }
    $q = $pq.Quota
    $on = $(if ($pq.Label) { $pq.Label } else { 'another route' })
    $p = [string]$Identity.Provider
    $v = [pscustomobject]@{ State = 'unavailable'; Preflight = ''; Reason = ''; Refusal = ''; Label = ''; Kind = ''; Hit = $q.Hit; Until = $null; Credential = $Verdict.Credential; Burst = $false; PlanQuota = [pscustomobject]@{ Plan = $plan; Label = $on } }
    if ($pq.QuotaKnown) {
        $v.Kind = 'quota'
        $v.Until = $q.RetryAfter
        $v.Reason = "plan $plan (usage limit on $on until $($q.RetryAfterIso))"
        $v.Refusal = "provider $p is not usable: its plan $plan hit a usage limit on $on at $($q.When) ($($q.Message)) that lasts until $($q.RetryAfterIso); nothing was started$(if (-not $RosterWalk) { ' (pass -SkipPreflight to launch anyway)' })"
    } else {
        $v.Kind = 'quota-unknown-reset'
        $v.Burst = ([string](Get-PropertyValue $q 'FailureKind' '') -eq 'burst')
        $v.Until = $q.Until
        $untilIso = Format-OffsetIso $q.Until
        $what = $(if ($v.Burst) { 'burst limit (429)' } else { 'usage limit' })
        $v.Reason = "plan $plan ($what on $on hit $($q.HitIso), reset unknown; retry after $untilIso)"
        $v.Refusal = "provider $p is not usable: its plan $plan hit a $(if ($v.Burst) { 'burst' } else { 'usage' }) limit on $on at $($q.HitIso) ($($q.Message)) and named no reset time - out until $untilIso; nothing was started$(if (-not $RosterWalk) { ' (pass -SkipPreflight to launch anyway)' })"
    }
    $v.Preflight = "unavailable: $($v.Reason)"
    $v.Label = "unavailable ($($v.Reason)) - a real run is refused: $($v.Refusal)"
    return $v
}

# The warning of a usage limit that does not refuse the run - with -SkipPreflight only (wave 24b,
# F08-7: without it every usage limit that still blocks refuses the run, Get-PreflightVerdict):
# one whose reset time lies ahead, or one without a reset time hit less than 60 minutes ago. ''
# otherwise.
function Format-QuotaWarning {
    param($Identity, $Health, [switch]$SkipPreflight)
    if (-not $Health -or -not $Health.Quota -or -not $SkipPreflight) { return '' }
    $q = $Health.Quota
    if ($Health.QuotaKnown) {
        return "provider $($Identity.Provider) hit a usage limit $($q.AgeMinutes) min ago that lasts until $($q.RetryAfterIso): $($q.Message)"
    }
    return "provider $($Identity.Provider) hit a $(if ([string](Get-PropertyValue $q 'FailureKind' '') -eq 'burst') { 'burst limit (429)' } else { 'usage limit' }) $($q.AgeMinutes) min ago (reset unknown; out until $(Format-OffsetIso $q.Until)): $($q.Message)"
}

# (wave 24b, F07-3) ONE listing resolves each reviewer's identity and each endpoint's health
# ONCE: the walk (Select-RosterReviewer), every entry's availability (Get-RosterAvailability,
# Select-PanelMembers) and the rows of codex-providers.ps1 share $Cache (New-ListingCache, one per
# invocation - the Codex config, the ledgers and the consult clock are fixed within it; $null = no
# cache). Keys: the identity's inputs (provider, model, engine, launcher, OPENAI_BASE_URL); the
# endpoint's fingerprint and the clock. The credential checks have their own cache ($LoginCache:
# one `codex login status` and one `agy models` per listing).
# (wave 24c, F15-2) Provider and model identity is case-SENSITIVE (ZAI and zai are two
# [model_providers] tables, glm-5.3 and GLM-5.3 two models; the roster compares them ordinally), but
# a PowerShell @{} folds case - two case-distinct entries would share one slot and one entry would
# get the other's identity, fingerprint and health. The cache is therefore an ORDINAL hashtable
# (New-ListingCache) with case-preserving keys whose every part is length-prefixed
# (Get-ListingCacheKey: "<length>:<text>|..."; no separator inside a part can shift the parts). Only
# a cache made by New-ListingCache is used (its marker entry): any other hashtable is ignored - the
# identity is then resolved every time, never taken from a case-folded slot.
$script:ListingCacheMarker = 'cc-listing-cache:ordinal'
function New-ListingCache {
    $c = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    $c[$script:ListingCacheMarker] = $true
    return $c
}
function Test-ListingCache {
    param([hashtable]$Cache)
    return [bool]($null -ne $Cache -and $Cache.ContainsKey($script:ListingCacheMarker))
}
function Get-ListingCacheKey {
    param([string[]]$Parts)
    return ((@($Parts) | ForEach-Object { "$(([string]$_).Length):$_" }) -join '|')
}
# (wave 29) $Auth: a roster entry's auth - passed on only for an engine that takes one (claude).
# (wave 29b) $Endpoint: the roster entry's endpoint (claude auth endpoint) - its base URL, env_key
# name and plan are part of the cache key.
function Get-CachedReviewerIdentity {
    param([hashtable]$Cache, $Config, [string]$Provider, [string]$Model = '', [string]$OpenAiBaseUrl = '', [string]$Engine = 'codex', [string]$Launcher = '', [string]$Auth = '', $Endpoint = $null)
    if (-not $Engine) { $Engine = 'codex' }
    $idArgs = @{ Config = $Config; Provider = $Provider; Model = $Model; OpenAiBaseUrl = $OpenAiBaseUrl; Engine = $Engine; Launcher = $Launcher }
    $es = Get-EngineSpec -Name $Engine
    if ($es -and @(Get-PropertyValue $es 'AuthModes' @()).Count -gt 0 -and $Auth) { $idArgs['Auth'] = $Auth } else { $Auth = '' }
    $epKey = ''
    if ($Auth -eq 'endpoint') {
        $idArgs['Endpoint'] = $Endpoint
        if ($Endpoint) { $epKey = "$([string]$Endpoint.BaseUrl) $([string]$Endpoint.EnvKey) $([string](Get-PropertyValue $Endpoint 'TimeoutMs' '')) $([string](Get-PropertyValue $Endpoint 'Plan' ''))" }
    }
    $use = Test-ListingCache $Cache
    $key = Get-ListingCacheKey @('identity', $Provider, $Model, $Engine, $Launcher, $OpenAiBaseUrl, $Auth, $epKey)
    if ($use -and $Cache.ContainsKey($key)) { return $Cache[$key] }
    $id = Resolve-ReviewerIdentity @idArgs
    if ($use) { $Cache[$key] = $id }
    return $id
}
function Get-CachedEndpointHealth {
    param([hashtable]$Cache, [object[]]$Consults, [string]$Fingerprint, [datetime]$UtcNow = [datetime]::UtcNow)
    $use = Test-ListingCache $Cache
    $key = Get-ListingCacheKey @('health', $Fingerprint, [string]$UtcNow.Ticks)
    if ($use -and $Cache.ContainsKey($key)) { return $Cache[$key] }
    $h = Get-EndpointHealth -Consults $Consults -Fingerprint $Fingerprint -UtcNow $UtcNow
    if ($use) { $Cache[$key] = $h }
    return $h
}

# The roster walk: the first entry whose preflight verdict (Get-PreflightVerdict
# -RosterWalk) is available. $Model (an explicit -Model without -Provider) restricts the walk
# to the entries that resolve to that model. -SkipPreflight takes the first entry unchecked -
# except for an engine's launch invariant (wave 23, D4: muse's billing guard), which skips an
# entry ("refused: ...") with and without -SkipPreflight.
# { Entry; Identity; Verdict; Skipped (object[] of { provider; model; reason }, in roster
# order - never a List: @() over a List property fails on Windows PowerShell 5.1);
# Considered (entries walked); Error ('' or the refusal: none available / no entry for
# $Model / the first entry's identity error under -SkipPreflight) }.
# (wave 26b, D16) A roster entry with a context_tokens whose context the new prompt alone would
# fill beyond 80%: '' or the skip reason "brief too large for this reviewer's context (est. N of M
# tokens)". $EstimateTokens: the caller's estimate (the ask and the brief, 4 characters a token).
$script:ContextShare = 0.8
function Get-ContextSkip {
    param($Entry, [int]$EstimateTokens = 0)
    $ct = [int](Get-PropertyValue $Entry 'ContextTokens' 0)
    if ($ct -le 0 -or $EstimateTokens -le 0) { return '' }
    if ($EstimateTokens -gt $script:ContextShare * $ct) { return "brief too large for this reviewer's context (est. $EstimateTokens of $ct tokens)" }
    return ''
}

function Select-RosterReviewer {
    param($Roster, $Config, [object[]]$Consults, [string]$Launcher, [hashtable]$LoginCache = $null, [datetime]$UtcNow = [datetime]::UtcNow, [string]$OpenAiBaseUrl = '', [string]$Model = '', [switch]$SkipPreflight, [string]$Engine = '', [hashtable]$EngineLaunchers = $null, [switch]$NoNetwork, [hashtable]$Cache = $null, [int]$EstimateTokens = 0)
    $skipped = New-Object System.Collections.Generic.List[object]
    $r = [pscustomobject]@{ Entry = $null; Identity = $null; Verdict = $null; Skipped = [object[]]@(); Considered = 0; Error = '' }
    $listing = New-Object System.Collections.Generic.List[string]
    foreach ($e in @($Roster.Entries)) {
        $entryEngine = if ($e.PSObject.Properties['Engine'] -and $e.Engine) { [string]$e.Engine } else { 'codex' }
        if ($Engine -and $entryEngine -ne $Engine) { continue }
        $entryLauncher = Get-EngineLauncher -Engine $entryEngine -Launchers $EngineLaunchers -CodexLauncher $Launcher
        $id = Get-CachedReviewerIdentity -Cache $Cache -Config $Config -Provider $e.Provider -Model $e.Model -OpenAiBaseUrl $OpenAiBaseUrl -Engine $entryEngine -Launcher $entryLauncher -Auth ([string]$e.Auth) -Endpoint (Get-PropertyValue $e 'Endpoint' $null)
        if ($Model -and $id.Model -cne $Model) { continue }
        $r.Considered++
        $block = Get-EngineLaunchBlock -Engine $entryEngine
        if ($block) {
            $skipped.Add([pscustomobject]@{ provider = $e.Provider; model = $id.Model; engine = $entryEngine; reason = "refused: $block" })
            $listing.Add("#$($e.Position) $(Format-ReviewerLineage -Provider $id.Provider -Model $id.Model -Engine $entryEngine) (refused: $block)")
            continue
        }
        # (wave 26b, D16) a brief its context window cannot hold
        $ctxSkip = Get-ContextSkip -Entry $e -EstimateTokens $EstimateTokens
        if ($ctxSkip) {
            $skipped.Add([pscustomobject]@{ provider = $e.Provider; model = $id.Model; engine = $entryEngine; reason = $ctxSkip })
            $listing.Add("#$($e.Position) $(Format-ReviewerLineage -Provider $id.Provider -Model $id.Model -Engine $entryEngine) ($ctxSkip)")
            continue
        }
        if ($SkipPreflight) {
            if ($id.Error) { $r.Error = $id.Error; return $r }
            $r.Entry = $e; $r.Identity = $id
            $r.Skipped = [object[]]$skipped.ToArray()
            return $r
        }
        $health = $null
        if ($id.Resolved) { $health = Get-CachedEndpointHealth -Cache $Cache -Consults $Consults -Fingerprint $id.Fingerprint -UtcNow $UtcNow }
        $verdict = Get-PreflightVerdict -Identity $id -Config $Config -Launcher $entryLauncher -Health $health -LoginCache $LoginCache -Anonymous:($e.Auth -eq 'none') -RosterWalk -NoNetwork:$NoNetwork
        # (wave 29b, E5) a usage limit on another route of the entry's plan
        $verdict = Get-PlanQuotaVerdict -Verdict $verdict -Entry $e -Identity $id -Roster $Roster -Config $Config -Consults $Consults -Launcher $Launcher -EngineLaunchers $EngineLaunchers -UtcNow $UtcNow -OpenAiBaseUrl $OpenAiBaseUrl -Cache $Cache -RosterWalk
        if ($verdict.State -eq 'available') {
            $r.Entry = $e; $r.Identity = $id; $r.Verdict = $verdict
            $r.Skipped = [object[]]$skipped.ToArray()
            return $r
        }
        $skipped.Add([pscustomobject]@{ provider = $e.Provider; model = $id.Model; engine = $entryEngine; reason = $verdict.Reason })
        $listing.Add("#$($e.Position) $(Format-ReviewerLineage -Provider $id.Provider -Model $id.Model -Engine $entryEngine) ($($verdict.Reason))")
    }
    if ($r.Considered -eq 0) {
        $all = (@($Roster.Entries) | ForEach-Object { "#$($_.Position) $(if ($_.Model) { Format-ReviewerLineage -Provider $_.Provider -Model $_.Model -Engine $_.Engine } else { "$($_.Provider) (config model)" })" }) -join ', '
        if ($Engine -and -not $Model) {
            $r.Error = "-Engine $($Engine): no entry of the reviewer roster '$($Roster.Path)' uses that engine ($all); pass -Provider <label> -Model <model> to choose a reviewer outside the roster"
        } else {
            $r.Error = "-Model $($Model): no entry of the reviewer roster '$($Roster.Path)' resolves to that model ($all); pass -Provider <name> -Model $Model to choose a reviewer outside the roster"
        }
        return $r
    }
    $r.Skipped = [object[]]$skipped.ToArray()
    $r.Error = "no reviewer of the roster '$($Roster.Path)' is available; nothing was started: $($listing.ToArray() -join '; ') (run codex-providers.ps1 for the full picture)"
    return $r
}

# The purposes on which a "weighty" roster entry joins a panel (and a "light" one only stands in).
$script:WeightyPurposes = @('framing', 'decision', 'core-contract', 'acceptance', 'stuck')

# The members of a review panel (-Panel): the roster walked like Select-RosterReviewer
# without stopping at the first available entry. Every entry whose preflight verdict is
# available (with -SkipPreflight: every entry) runs, unless it is "weighty" and $Purpose is
# light (not in $script:WeightyPurposes) and -All (-PanelAll) is not given, or its engine's
# launch invariant refuses it (wave 23, D4 - with -SkipPreflight too). (2026-10-07) A "light"
# entry on a weighty $Purpose without -All is held back (SkipKind light) once it passed every
# other check; after the whole roster is judged it stands in - State run, Reason "stands in for
# #<p> (<that sibling's skip reason>)" or "stands in (no other entry of label <label>)" - when
# no other member of its provider label (compared ordinally, as Get-PanelPlan groups) runs; in
# roster order, so a second light entry of the label sees the first one run. $Model: as for
# the walk. -NoNetwork (wave 24, D15): passed to every preflight (an engine's sign-in that
# needs the network is then "not checked") - the availability view of the hook and the listing
# (Get-RosterAvailability) judges EVERY entry this way. { Members (object[], roster order, of {
# Entry; Identity; State 'run'|'skipped'; Reason ('' when it runs - a light stand-in's "stands
# in ..."); Verdict (the preflight verdict, $null under -SkipPreflight or a launch refusal);
# Health (the endpoint health, $null when unresolved); Block ('' or the launch refusal); SkipKind
# (wave 26: '' | refused | unavailable | weighty | context | light - why it is skipped) }); Error
# ('' or the refusal: nobody runs / no entry for $Model) }. (wave 26) Select-PanelRouting then
# seats the panel among the members that run (State 'not-picked' for the rest).
function Select-PanelMembers {
    param($Roster, $Config, [object[]]$Consults, [string]$Launcher, [hashtable]$LoginCache = $null, [datetime]$UtcNow = [datetime]::UtcNow, [string]$OpenAiBaseUrl = '', [string]$Model = '', [string]$Purpose = '', [switch]$All, [switch]$SkipPreflight, [string]$Engine = '', [hashtable]$EngineLaunchers = $null, [switch]$NoNetwork, [hashtable]$Cache = $null, [int]$EstimateTokens = 0)
    $members = New-Object System.Collections.Generic.List[object]
    $r = [pscustomobject]@{ Members = [object[]]@(); Error = '' }
    $listing = New-Object System.Collections.Generic.List[string]
    $purposeLabel = if ($Purpose) { $Purpose } else { 'none' }
    foreach ($e in @($Roster.Entries)) {
        $entryEngine = if ($e.PSObject.Properties['Engine'] -and $e.Engine) { [string]$e.Engine } else { 'codex' }
        if ($Engine -and $entryEngine -ne $Engine) { continue }
        $entryLauncher = Get-EngineLauncher -Engine $entryEngine -Launchers $EngineLaunchers -CodexLauncher $Launcher
        $id = Get-CachedReviewerIdentity -Cache $Cache -Config $Config -Provider $e.Provider -Model $e.Model -OpenAiBaseUrl $OpenAiBaseUrl -Engine $entryEngine -Launcher $entryLauncher -Auth ([string]$e.Auth) -Endpoint (Get-PropertyValue $e 'Endpoint' $null)
        if ($Model -and $id.Model -cne $Model) { continue }
        $state = 'run'
        $reason = ''
        $skipKind = ''
        $verdict = $null
        $health = $null
        if ($id.Resolved) { $health = Get-CachedEndpointHealth -Cache $Cache -Consults $Consults -Fingerprint $id.Fingerprint -UtcNow $UtcNow }
        $block = Get-EngineLaunchBlock -Engine $entryEngine
        if ($block) { $state = 'skipped'; $reason = "refused: $block"; $skipKind = 'refused' }
        elseif (-not $SkipPreflight) {
            $verdict = Get-PreflightVerdict -Identity $id -Config $Config -Launcher $entryLauncher -Health $health -LoginCache $LoginCache -Anonymous:($e.Auth -eq 'none') -RosterWalk -NoNetwork:$NoNetwork
            # (wave 29b, E5) a usage limit on another route of the entry's plan
            $verdict = Get-PlanQuotaVerdict -Verdict $verdict -Entry $e -Identity $id -Roster $Roster -Config $Config -Consults $Consults -Launcher $Launcher -EngineLaunchers $EngineLaunchers -UtcNow $UtcNow -OpenAiBaseUrl $OpenAiBaseUrl -Cache $Cache -RosterWalk
            if ($verdict.State -ne 'available') { $state = 'skipped'; $reason = $verdict.Reason; $skipKind = 'unavailable' }
        }
        if ($state -eq 'run' -and $e.Panel -eq 'weighty' -and -not $All -and $script:WeightyPurposes -notcontains $Purpose) {
            $state = 'skipped'
            $reason = "weighty reviewer; purpose $purposeLabel is light (use -PanelAll)"
            $skipKind = 'weighty'
        }
        # (wave 26b, D16) skipped before its start: the brief is too large for its context window
        if ($state -eq 'run') {
            $ctxSkip = Get-ContextSkip -Entry $e -EstimateTokens $EstimateTokens
            if ($ctxSkip) { $state = 'skipped'; $reason = $ctxSkip; $skipKind = 'context' }
        }
        # (2026-10-07) a light entry on a weighty purpose: held back after every other check (a
        # stand-in below needs none again)
        if ($state -eq 'run' -and $e.Panel -eq 'light' -and -not $All -and $script:WeightyPurposes -contains $Purpose) {
            $state = 'skipped'
            $reason = "light reviewer; purpose $purposeLabel is weighty - it stands in only when no entry of its label runs"
            $skipKind = 'light'
        }
        $members.Add([pscustomobject]@{ Entry = $e; Identity = $id; State = $state; Reason = $reason; Verdict = $verdict; Health = $health; Block = [string]$block; SkipKind = $skipKind })
    }
    # (2026-10-07) the stand-in: a held-back light entry runs when no other member of its provider
    # label runs; the first skipped sibling that is not itself a held-back light entry is named
    foreach ($m in $members) {
        if ($m.State -ne 'skipped' -or $m.SkipKind -ne 'light') { continue }
        $label = [string]$m.Entry.Provider
        $siblings = @($members | Where-Object { -not [object]::ReferenceEquals($_, $m) -and [string]$_.Entry.Provider -ceq $label })
        if (@($siblings | Where-Object { $_.State -eq 'run' }).Count -gt 0) { continue }
        $named = @($siblings | Where-Object { $_.State -eq 'skipped' -and $_.SkipKind -ne 'light' }) | Select-Object -First 1
        $m.State = 'run'
        $m.SkipKind = ''
        $m.Reason = $(if ($named) { "stands in for #$($named.Entry.Position) ($($named.Reason))" } elseif ($siblings.Count -eq 0) { "stands in (no other entry of label $label)" } else { "stands in (no other entry of label $label runs)" })
    }
    foreach ($m in $members) {
        $mEngine = if ($m.Entry.PSObject.Properties['Engine'] -and $m.Entry.Engine) { [string]$m.Entry.Engine } else { 'codex' }
        $listing.Add("#$($m.Entry.Position) $(Format-ReviewerLineage -Provider $m.Identity.Provider -Model $m.Identity.Model -Engine $mEngine) ($(if ($m.State -eq 'run') { 'runs' } else { $m.Reason }))")
    }
    $r.Members = [object[]]$members.ToArray()
    if ($members.Count -eq 0) {
        $all = (@($Roster.Entries) | ForEach-Object { "#$($_.Position) $(if ($_.Model) { Format-ReviewerLineage -Provider $_.Provider -Model $_.Model -Engine $_.Engine } else { "$($_.Provider) (config model)" })" }) -join ', '
        if ($Engine -and -not $Model) {
            $r.Error = "-Engine $($Engine): no entry of the reviewer roster '$($Roster.Path)' uses that engine ($all)"
        } else {
            $r.Error = "-Model $($Model): no entry of the reviewer roster '$($Roster.Path)' resolves to that model ($all); pass -Provider <name> -Model $Model to choose a reviewer outside the roster"
        }
    } elseif (@($members | Where-Object { $_.State -eq 'run' }).Count -eq 0) {
        $r.Error = "no reviewer of the roster '$($Roster.Path)' is available; nothing was started: $($listing.ToArray() -join '; ') (run codex-providers.ps1 for the full picture)"
    }
    return $r
}

# One required reviewer that is out, for the exit-5 refusal (D7): "#3 openai :: gpt-6-astra (usage
# limit until <iso>; back Sun 20:35, in 2d 10h)" - the roster walk's reason, then when it is
# expected back, in local time (a verdict that names it).
function Format-RequiredOutage {
    param($Member, [datetime]$UtcNow = [datetime]::UtcNow)
    $shown = Format-ReviewerLineage -Provider ([string]$Member.Identity.Provider) -Model ([string]$Member.Identity.Model) -Engine ([string]$Member.Entry.Engine)
    $text = "#$($Member.Entry.Position) $shown ($($Member.Reason)"
    $until = $null
    if ($Member.Verdict) { $until = $Member.Verdict.Until }
    if ($null -ne $until) {
        $now = New-Object DateTimeOffset ([datetime]::SpecifyKind($UtcNow, [DateTimeKind]::Utc))
        $text += "; back $(Format-LocalWhen -When $until -NowUtc $UtcNow), $(Format-RelativeHint ($until - $now))"
    }
    return $text + ')'
}

# ----------------------------------------------------------------------------- telemetry routing (wave 26, R15)
#
# The judge's marks (codex-findings.ps1 -Rate) of EVERY task of the repository, scored per
# reviewer (D2, D3) - one function for the bridge's panel routing and codex-scoreboard.ps1:
#   evidence   the ratings of the last 90 days by the CONSULTATION's time (rating.consult_when,
#              else - a rating recorded before wave 26 - the ledger entry with its consult_id,
#              else the rating's own time); the latest rating of a consultation wins (keyed by
#              consult_id; a rating without one by task and n); every field is read from the
#              rating record itself (denormalised at -Rate time) - no join by n across tasks
#   rate       w = (yes + 0.5 partly + 2p) / (n + 4p), p = 0.5 - a rate with a prior that pulls
#              few ratings to 0.5; the score = 0.25 + 1.75 w, in [0.25, 2]; neutral = 1.125
#   hierarchy  (lineage, purpose, topics) when the pooled topic evidence reaches 3 ratings, else
#              (lineage, purpose) with >= 3, else the lineage's all-purpose rate with >= 3, else
#              neutral. A rating credits each of its t topics 1/t; a request with topics pools the
#              credited counts over its topics (never a mean of means)
$script:RoutingWindowDays = 90
$script:RoutingMinRatings = 3
$script:RoutingPrior = 0.5
$script:RoutingExplore = 0.2
$script:RoutingNeutral = 0.25 + 1.75 * 0.5

# (wave 26c, D4 / F26-4) Whether a record's field is MISSING: absent, null, a string that is empty or
# white space, or a list without one non-blank item.
function Test-BlankField {
    param($Object, [string]$Name)
    if ($null -eq $Object -or -not $Object.PSObject.Properties[$Name]) { return $true }
    $v = $Object.$Name
    if ($null -eq $v) { return $true }
    if ($v -is [string]) { return (-not $v.Trim()) }
    if ($v -is [System.Collections.IEnumerable]) { return (@($v | Where-Object { $null -ne $_ -and ([string]$_).Trim() }).Count -eq 0) }
    return (-not ([string]$v).Trim())
}

# Every rating of every task under $CollabRoot, normalised: { Key; Task; N; ConsultId; Provider;
# Model; Engine; Lineage; Purpose; Topics (string[]); ConsultWhen (DateTimeOffset or $null);
# RatedWhen; Useful (yes | partly | no) }. A findings.json that does not parse is left out (read
# tolerantly, like Read-AllTaskConsults); a rating without a provider (unknown provenance) or with
# another mark is left out. $Consults (Read-AllTaskConsults; read here when $null) resolves a
# pre-wave-26 rating's missing fields by its consult_id - never by n. Duplicates: the latest
# rating (RatedWhen) of a consultation wins. $Stores (hashtable: task directory name -> its parsed
# findings.json, $null when none): stores the caller already read (the scoreboard reads each
# findings.json once per run - D2); without it every task's findings.json is read here.
function Read-AllTaskRatings {
    param([string]$CollabRoot, [object[]]$Consults = $null, [hashtable]$Stores = $null)
    $out = New-Object System.Collections.Generic.List[object]
    if (-not $CollabRoot -or -not (Test-Path -LiteralPath $CollabRoot -PathType Container)) { return , ([object[]]$out.ToArray()) }
    $byId = $null
    $byKey = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($dir in @(Get-ChildItem -LiteralPath $CollabRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $store = $null
        if ($null -ne $Stores) {
            if (-not $Stores.ContainsKey($dir.Name)) { continue }
            $store = $Stores[$dir.Name]
            if ($null -eq $store) { continue }
        } else {
            $f = Join-Path $dir.FullName 'findings.json'
            if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
            try { $store = ConvertFrom-JsonKeepOffset -Text (Read-SharedText -Path $f) } catch { continue }
        }
        foreach ($rt in @(Get-PropertyValue $store 'ratings' @())) {
            if ($null -eq $rt) { continue }
            $useful = [string](Get-PropertyValue $rt 'useful' '')
            if (@('yes', 'partly', 'no') -cnotcontains $useful) { continue }
            $cid = [string](Get-PropertyValue $rt 'consult_id' '')
            $entry = $null
            # (wave 26b, D6 / F22-6) joined by consult_id when ANY identity field is missing - the
            # provider, the model, the purpose, the engine, consult_when (or topics) - a record
            # with a provider only included. (wave 26c, D4 / F26-4) "missing" = absent OR empty or
            # white space (an empty topics list too); a field that is missing takes the entry's.
            $missing = @{}
            foreach ($fld in @('provider', 'model', 'purpose', 'engine', 'consult_when', 'topics')) { $missing[$fld] = Test-BlankField -Object $rt -Name $fld }
            $needJoin = $cid -and (@($missing.Values | Where-Object { $_ }).Count -gt 0)
            if ($needJoin) {
                if ($null -eq $byId) {
                    $byId = New-Object System.Collections.Hashtable ([StringComparer]::OrdinalIgnoreCase)
                    if ($null -eq $Consults) { $Consults = Read-AllTaskConsults -CollabRoot $CollabRoot }
                    foreach ($c in @($Consults)) { $ci = [string](Get-PropertyValue $c 'consult_id' ''); if ($ci -and -not $byId.ContainsKey($ci)) { $byId[$ci] = $c } }
                }
                if ($byId.ContainsKey($cid)) { $entry = $byId[$cid] }
            }
            $rev = $null
            if ($null -ne $entry) { $rev = Get-PropertyValue $entry 'reviewer' $null }
            $provider = ([string](Get-PropertyValue $rt 'provider' '')).Trim()
            if (-not $provider -and $null -ne $rev) { $provider = [string](Get-PropertyValue $rev 'provider' '') }
            if (-not $provider) { continue }
            $model = ([string](Get-PropertyValue $rt 'model' '')).Trim()
            if (-not $model -and $null -ne $rev) { $model = [string](Get-PropertyValue $rev 'model' '') }
            $engine = ([string](Get-PropertyValue $rt 'engine' '')).Trim()
            if (-not $engine -and $null -ne $rev) { $engine = [string](Get-PropertyValue $rev 'engine' '') }
            if (-not $engine -and [string](Get-PropertyValue $rt 'lineage' '') -match '\s\[([a-z]+)\]$') { $engine = $Matches[1] }
            if (-not $engine) { $engine = 'codex' }
            $purpose = ([string](Get-PropertyValue $rt 'purpose' '')).Trim()
            if ($missing['purpose'] -and $null -ne $entry) { $purpose = [string](Get-PropertyValue $entry 'purpose' '') }
            $topicsRaw = @()
            if (-not $missing['topics']) { $topicsRaw = @(Get-PropertyValue $rt 'topics' @()) }
            elseif ($null -ne $entry) { $topicsRaw = @(Get-PropertyValue $entry 'topics' @()) }
            $topics = (ConvertTo-SlugList -Values ([string[]]@($topicsRaw | Where-Object { $_ } | ForEach-Object { [string]$_ })) -What 'topic').Items
            $cwhen = ConvertTo-WhenOffset (Get-PropertyValue $rt 'consult_when' $null)
            if ($null -eq $cwhen -and $null -ne $entry) { $cwhen = ConvertTo-WhenOffset (Get-PropertyValue $entry 'when' $null) }
            $rwhen = ConvertTo-WhenOffset (Get-PropertyValue $rt 'when' $null)
            if ($null -eq $cwhen) { $cwhen = $rwhen }
            $n = [string](Get-PropertyValue $rt 'n' '')
            $key = $(if ($cid) { $cid.ToLowerInvariant() } else { "$($dir.Name)#n$n" })
            $rec = [pscustomobject]@{
                Key = $key; Task = $dir.Name; N = $n; ConsultId = $cid; Provider = $provider; Model = $model; Engine = $engine
                Lineage = (Format-ReviewerLineage -Provider $provider -Model $model -Engine $engine); Purpose = $purpose; Topics = [string[]]$topics
                ConsultWhen = $cwhen; RatedWhen = $rwhen; Useful = $useful
            }
            if ($byKey.ContainsKey($key)) {
                $old = $byKey[$key]
                $newer = ($null -ne $rwhen -and ($null -eq $old.RatedWhen -or $rwhen -ge $old.RatedWhen))
                if (-not $newer) { continue }
                $byKey[$key] = $rec
                for ($i = 0; $i -lt $out.Count; $i++) { if ($out[$i].Key -ceq $key) { $out[$i] = $rec; break } }
                continue
            }
            $byKey[$key] = $rec
            $out.Add($rec)
        }
    }
    return , ([object[]]$out.ToArray())
}

# w = (yes + 0.5 partly + 2p) / (n + 4p), scaled into [0.25, 2] (D3).
function Get-RoutingRate {
    param([double]$Yes, [double]$Partly, [double]$Count)
    $p = $script:RoutingPrior
    $w = ($Yes + 0.5 * $Partly + 2 * $p) / ($Count + 4 * $p)
    return (0.25 + 1.75 * $w)
}

# The routing score of one reviewer (D3) at the consult clock $UtcNow: { Score; Basis
# ('purpose+topics' | 'purpose' | 'all-purpose' | 'neutral'); Ratings (the count behind the basis,
# topic credit pooled - fractional); All (its ratings of every purpose in the window - the
# evidence D5 asks for: >= 3); Yes; Partly; No (at the basis) }. -AllPurpose: the all-purpose rate
# only (the scoreboard's lineage total).
function Get-RoutingScore {
    param([object[]]$Ratings, [string]$Provider, [string]$Model, [string]$Engine = 'codex', [string]$Purpose = '', [string[]]$Topics = @(), [datetime]$UtcNow = [datetime]::UtcNow, [switch]$AllPurpose)
    if (-not $Engine) { $Engine = 'codex' }
    $now = New-Object DateTimeOffset ([datetime]::SpecifyKind($UtcNow, [DateTimeKind]::Utc))
    $from = $now.AddDays(-$script:RoutingWindowDays)
    $mine = @($Ratings | Where-Object { $_ -and $_.Provider -ceq $Provider -and $_.Model -ceq $Model -and $_.Engine -eq $Engine -and $null -ne $_.ConsultWhen -and $_.ConsultWhen -ge $from })
    $count = {
        param([object[]]$List)
        $c = @{ yes = 0.0; partly = 0.0; no = 0.0; n = 0.0 }
        foreach ($x in $List) { $c[$x.Useful] += 1.0; $c.n += 1.0 }
        $c
    }
    $all = & $count $mine
    $res = [pscustomobject]@{ Score = $script:RoutingNeutral; Basis = 'neutral'; Ratings = 0.0; All = [int]$all.n; Yes = 0.0; Partly = 0.0; No = 0.0 }
    $onPurpose = @($mine | Where-Object { $_.Purpose -ceq $Purpose })
    if ($AllPurpose) { $onPurpose = @() }
    $want = @($Topics | Where-Object { $_ })
    if ($want.Count -gt 0) {
        $c = @{ yes = 0.0; partly = 0.0; no = 0.0; n = 0.0 }
        foreach ($x in $onPurpose) {
            $t = @($x.Topics).Count
            if ($t -eq 0) { continue }
            foreach ($topic in $want) {
                if (@($x.Topics) -ccontains $topic) { $c[$x.Useful] += 1.0 / $t; $c.n += 1.0 / $t }
            }
        }
        if ($c.n -ge $script:RoutingMinRatings - 1e-9) {
            $res.Score = Get-RoutingRate -Yes $c.yes -Partly $c.partly -Count $c.n; $res.Basis = 'purpose+topics'; $res.Ratings = $c.n; $res.Yes = $c.yes; $res.Partly = $c.partly; $res.No = $c.no
            return $res
        }
    }
    $p = & $count $onPurpose
    if ($p.n -ge $script:RoutingMinRatings) {
        $res.Score = Get-RoutingRate -Yes $p.yes -Partly $p.partly -Count $p.n; $res.Basis = 'purpose'; $res.Ratings = $p.n; $res.Yes = $p.yes; $res.Partly = $p.partly; $res.No = $p.no
        return $res
    }
    if ($all.n -ge $script:RoutingMinRatings) {
        $res.Score = Get-RoutingRate -Yes $all.yes -Partly $all.partly -Count $all.n; $res.Basis = 'all-purpose'; $res.Ratings = $all.n; $res.Yes = $all.yes; $res.Partly = $all.partly; $res.No = $all.no
    }
    return $res
}

# The routing seed (D4; wave 26b, D3 / F22-4: length-prefixed): SHA-256 over the UTF-8 text
# `<task>|<purpose>|<brief sha256>|<lineages>|<nonce>` where every field is written `<len>:<value>`
# (len = the value's UTF-8 byte count) and <lineages> is the eligible lineages, sorted ordinally,
# each written `<len>:<lineage>`, joined by ',' - so no provider, model or task string can shift a
# boundary. An independent reference implementation: tests/reference-draw.py. { Hex; Bytes; Text }.
function ConvertTo-LengthPrefixed {
    param([string]$Value)
    return "$($script:Utf8NoBom.GetByteCount([string]$Value)):$Value"
}

function Get-PanelSeed {
    param([string]$Task, [string]$Purpose, [string]$BriefSha, [string[]]$Lineages, [string]$Nonce)
    $sorted = [string[]]@($Lineages | ForEach-Object { [string]$_ })
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $joined = @($sorted | ForEach-Object { ConvertTo-LengthPrefixed $_ }) -join ','
    $text = @((ConvertTo-LengthPrefixed $Task), (ConvertTo-LengthPrefixed $Purpose), (ConvertTo-LengthPrefixed $BriefSha), (ConvertTo-LengthPrefixed $joined), (ConvertTo-LengthPrefixed $Nonce)) -join '|'
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $bytes = $sha.ComputeHash($script:Utf8NoBom.GetBytes($text)) } finally { $sha.Dispose() }
    return [pscustomobject]@{ Hex = (ConvertTo-HexString $bytes); Bytes = [byte[]]$bytes; Text = $text }
}

# A uniform in [0, 1) from 8 bytes of $Hash at $Offset (D4): their top 53 bits (big-endian) / 2^53
# - exact in a double, so both runtimes agree to the bit.
function ConvertTo-Uniform53 {
    param([byte[]]$Hash, [int]$Offset = 0)
    $v = [long]0
    for ($i = 0; $i -lt 6; $i++) { $v = $v * 256 + [long]$Hash[$Offset + $i] }
    $v = $v * 32 + ([long]$Hash[$Offset + 6] -shr 3)
    return ([double]$v / 9007199254740992.0)
}

# The two uniforms of draw slot $Slot (1-based over the panel's seats; D4): SHA-256(seed ||
# the slot as 4 bytes big-endian) - bytes 0..7 pick (the weighted draw), bytes 8..15 decide
# exploration (< 0.2). { Pick; Explore; Hex }.
function Get-SlotUniforms {
    param([byte[]]$Seed, [int]$Slot)
    $buf = New-Object byte[] ($Seed.Length + 4)
    [Array]::Copy($Seed, $buf, $Seed.Length)
    $buf[$Seed.Length] = [byte](($Slot -shr 24) -band 255)
    $buf[$Seed.Length + 1] = [byte](($Slot -shr 16) -band 255)
    $buf[$Seed.Length + 2] = [byte](($Slot -shr 8) -band 255)
    $buf[$Seed.Length + 3] = [byte]($Slot -band 255)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $h = $sha.ComputeHash($buf) } finally { $sha.Dispose() }
    return [pscustomobject]@{ Pick = (ConvertTo-Uniform53 -Hash $h -Offset 0); Explore = (ConvertTo-Uniform53 -Hash $h -Offset 8); Hex = (ConvertTo-HexString $h) }
}

# The seats of a routed panel (D1, D4): $Candidates (roster order) of { Position; Lab; Weight;
# Pinned }; $K seats. Pinned candidates take the first seats (rule `required`, roster order); then
# the lab reserve (wave 26b, D5 / F22-5 - defined over the seats LEFT after the pins): reserve =
# min(K - the pinned, the labs with a candidate weighing >= $Neutral that the pins did not seat);
# while fewer reserve seats than that are taken, the draw is restricted to candidates of a lab not
# yet seated that weigh >= $Neutral (rule lab-draw / lab-explore); otherwise it draws from every
# candidate left (rank-draw / rank-explore). (The same seats as the wave 26 formulation min(K,
# good labs) over all seated labs - D5 changed the statement, not the draw.) A slot explores (a
# uniform pick from the same pool) when its second
# uniform is below $Explore; else the weighted pick: the first candidate, in roster order, whose
# running weight sum exceeds uniform x the pool's weight sum. The winner leaves the pool.
# Returns the seats in order: { Slot; Candidate; Rule }.
function Invoke-PanelDraw {
    param([object[]]$Candidates, [int]$K, [byte[]]$Seed, [double]$Neutral = $script:RoutingNeutral, [double]$Explore = $script:RoutingExplore)
    $seats = New-Object System.Collections.Generic.List[object]
    $left = New-Object System.Collections.Generic.List[object]
    foreach ($c in @($Candidates | Where-Object { $_ })) {
        if ($c.Pinned) { $seats.Add([pscustomobject]@{ Slot = $seats.Count + 1; Candidate = $c; Rule = 'required' }) } else { $left.Add($c) }
    }
    $goodLabs = @(@($Candidates | Where-Object { $_ -and [double]$_.Weight -ge $Neutral }) | ForEach-Object { [string]$_.Lab } | Select-Object -Unique)
    $pinnedLabs = @($seats | ForEach-Object { [string]$_.Candidate.Lab } | Select-Object -Unique)
    $reserve = [Math]::Min([Math]::Max(0, $K - $seats.Count), @($goodLabs | Where-Object { $pinnedLabs -notcontains $_ }).Count)
    $reserveTaken = 0
    while ($seats.Count -lt $K -and $left.Count -gt 0) {
        $slot = $seats.Count + 1
        $seatedLabs = @($seats | ForEach-Object { [string]$_.Candidate.Lab } | Select-Object -Unique)
        $pool = @()
        $kind = 'rank'
        if ($reserveTaken -lt $reserve) {
            $pool = @($left | Where-Object { $seatedLabs -notcontains [string]$_.Lab -and [double]$_.Weight -ge $Neutral })
            if ($pool.Count -gt 0) { $kind = 'lab' }
        }
        if ($pool.Count -eq 0) { $pool = @($left.ToArray()); $kind = 'rank' }
        $u = Get-SlotUniforms -Seed $Seed -Slot $slot
        $winner = $null
        $rule = ''
        if ($u.Explore -lt $Explore) {
            $idx = [int][Math]::Floor($u.Pick * $pool.Count)
            if ($idx -ge $pool.Count) { $idx = $pool.Count - 1 }
            $winner = $pool[$idx]
            $rule = "$kind-explore"
        } else {
            $total = 0.0
            foreach ($c in $pool) { $total += [double]$c.Weight }
            $target = $u.Pick * $total
            $acc = 0.0
            foreach ($c in $pool) {
                $acc += [double]$c.Weight
                if ($target -lt $acc) { $winner = $c; break }
            }
            if ($null -eq $winner) { $winner = $pool[$pool.Count - 1] }
            $rule = "$kind-draw"
        }
        if ($kind -eq 'lab') { $reserveTaken++ }
        $seats.Add([pscustomobject]@{ Slot = $slot; Candidate = $winner; Rule = $rule })
        [void]$left.Remove($winner)
    }
    return , ([object[]]$seats.ToArray())
}

# The panel's routing (wave 26; D1, D4-D7): who of Select-PanelMembers' members takes a seat.
#   eligible   State 'run' (available, the weighty gate passed, -Engine/-Model matched) - one set
#              for the ranking, the draw and exploration (D1, D11); a REQUIRED entry that only the
#              weighty gate (2026-10-07: or the light gate) held back is eligible too (the caller
#              refuses a required entry that is out, exit 5)
#   size       $Size (0 = every eligible member: -PanelAll, stuck), at least the required count,
#              at most the eligible count; the size bounds the members STARTED - no backfill.
#              (wave 26b, D2 / F19-1) size_asked = $Size as asked (0: the eligible count); a size
#              reduced below it (fewer eligible than asked) warns `panel size reduced: asked k,
#              eligible m`
#   reserve    (wave 26b, D5) the number of seats the lab reserve applied (rule lab-*)
#   mode       $Order 'roster': the required, then the rest in roster order, no draw (D5); 'routed':
#              the seeded draw of Invoke-PanelDraw over the scores (Get-RoutingScore) - unless NO
#              eligible reviewer has >= 3 ratings in the window: then roster order, fallback
#              'no ratings' (no shuffle without evidence)
# Members that are eligible but get no seat: State 'not-picked', Reason 'panel size <k>'. Every
# member gains Lineage, Lab, LabSource, Score (Get-RoutingScore), Required, Rule, Slot.
# { Members (roster order); Picked (seat order); K; SizeAsked; Routing (the ledger's panel.routing:
# mode, order, fallback, seed, nonce, nonce_source, size, size_asked, size_source, reserve,
# eligible[{position, lineage, lab,
# lab_source, score, basis, ratings, required}], picked[{slot, position, lineage, lab, rule}],
# explored[lineage], required[lineage]); Warnings (string[]: a singleton lab in a routed panel,
# the floor) }.
function Select-PanelRouting {
    param([object[]]$Members, [int]$Size = 0, [string]$SizeSource = 'purpose', [string]$Order = 'routed', [object[]]$Ratings = @(), [string]$Purpose = '', [string[]]$Topics = @(), [datetime]$UtcNow = [datetime]::UtcNow, [string]$Task = '', [string]$BriefSha = '', [string]$Nonce = '', [string]$NonceSource = 'date', [int[]]$Required = @())
    $neutral = $script:RoutingNeutral
    $req = @($Required | ForEach-Object { [int]$_ })
    foreach ($m in @($Members | Where-Object { $_ })) {
        $isReq = ($req -contains [int]$m.Entry.Position)
        if ($isReq -and $m.State -eq 'skipped' -and @('weighty', 'light') -contains [string](Get-PropertyValue $m 'SkipKind' '')) { $m.State = 'run'; $m.Reason = '' }
        $engine = [string]$m.Identity.Engine
        if (-not $engine) { $engine = [string]$m.Entry.Engine }
        if (-not $engine) { $engine = 'codex' }
        $lineage = Format-ReviewerLineage -Provider ([string]$m.Identity.Provider) -Model ([string]$m.Identity.Model) -Engine $engine
        $lab = Get-EntryLab -Entry $m.Entry -Model ([string]$m.Identity.Model) -Lineage $lineage
        $score = Get-RoutingScore -Ratings $Ratings -Provider ([string]$m.Identity.Provider) -Model ([string]$m.Identity.Model) -Engine $engine -Purpose $Purpose -Topics $Topics -UtcNow $UtcNow
        $m | Add-Member -NotePropertyName 'Lineage' -NotePropertyValue $lineage -Force
        $m | Add-Member -NotePropertyName 'Lab' -NotePropertyValue ([string]$lab.Lab) -Force
        $m | Add-Member -NotePropertyName 'LabSource' -NotePropertyValue ([string]$lab.Source) -Force
        $m | Add-Member -NotePropertyName 'Score' -NotePropertyValue $score -Force
        $m | Add-Member -NotePropertyName 'Required' -NotePropertyValue ([bool]$isReq) -Force
        $m | Add-Member -NotePropertyName 'Rule' -NotePropertyValue '' -Force
        $m | Add-Member -NotePropertyName 'Slot' -NotePropertyValue 0 -Force
    }
    $eligible = @($Members | Where-Object { $_ -and $_.State -eq 'run' })
    $k = $Size
    if ($k -le 0) { $k = $eligible.Count }
    $sizeAsked = $k
    $pinned = @($eligible | Where-Object { $_.Required })
    # (wave 26c, D5 / F26-5) raised by the required reviewers: said and recorded (size_source required)
    $sizeRaised = $false
    if ($k -lt $pinned.Count) { $k = $pinned.Count; $sizeRaised = $true; $SizeSource = 'required' }
    if ($k -gt $eligible.Count) { $k = $eligible.Count }
    $mode = $Order
    $fallback = ''
    if ($mode -eq 'routed' -and @($eligible | Where-Object { $_.Score.All -ge $script:RoutingMinRatings }).Count -eq 0) { $mode = 'roster'; $fallback = 'no ratings' }
    $seed = Get-PanelSeed -Task $Task -Purpose $Purpose -BriefSha $BriefSha -Lineages ([string[]]@($eligible | ForEach-Object { $_.Lineage })) -Nonce $Nonce
    $seats = New-Object System.Collections.Generic.List[object]
    if ($mode -eq 'routed') {
        $cands = @($eligible | ForEach-Object { [pscustomobject]@{ Position = [int]$_.Entry.Position; Lab = [string]$_.Lab; Weight = [double]$_.Score.Score; Pinned = [bool]$_.Required; Member = $_ } })
        foreach ($s in (Invoke-PanelDraw -Candidates $cands -K $k -Seed $seed.Bytes)) { $seats.Add([pscustomobject]@{ Slot = $s.Slot; Member = $s.Candidate.Member; Rule = $s.Rule }) }
    } else {
        $chosen = New-Object System.Collections.Generic.List[object]
        foreach ($m in $pinned) { $chosen.Add($m) }
        foreach ($m in @($eligible | Where-Object { -not $_.Required })) { if ($chosen.Count -ge $k) { break }; $chosen.Add($m) }
        # the required take the first seats (D7), then the roster order
        $slot = 0
        foreach ($m in $chosen) { $slot++; $seats.Add([pscustomobject]@{ Slot = $slot; Member = $m; Rule = $(if ($m.Required) { 'required' } else { 'roster' }) }) }
    }
    foreach ($s in $seats) { $s.Member.Rule = $s.Rule; $s.Member.Slot = $s.Slot }
    foreach ($m in $eligible) {
        if ($m.Slot -le 0) { $m.State = 'not-picked'; $m.Reason = "panel size $k" }
    }
    $warnings = New-Object System.Collections.Generic.List[string]
    # (wave 26b, D2 / F19-1) a size the eligible set could not fill is said, never recorded silently
    if ($k -lt $sizeAsked) { $warnings.Add("panel size reduced: asked $sizeAsked, eligible $($eligible.Count)") }
    if ($sizeRaised) { $warnings.Add("panel size raised: asked $sizeAsked, required $($pinned.Count)") }
    if ($mode -eq 'routed') {
        foreach ($m in @($eligible | Where-Object { $_.LabSource -eq 'singleton' })) {
            $warnings.Add("routing: no lab known for #$($m.Entry.Position) $($m.Lineage) (its model id has no known vendor prefix) - it counts as a lab of its own; give its roster entry a ""lab""")
        }
    }
    if ($SizeSource -ne '-PanelSize' -and $script:PanelFloorPurposes -contains $Purpose -and $seats.Count -lt 2) {
        $warnings.Add("panel floor: a $Purpose panel runs $($seats.Count) member$(if ($seats.Count -ne 1) { 's' }) - $Purpose questions should hear at least 2 reviewers (pass -PanelSize to choose the size explicitly)")
    }
    $round = { param([double]$x, [int]$d) [Math]::Round($x, $d) }
    $routing = [pscustomobject]@{
        mode         = $mode
        order        = $Order
        fallback     = $fallback
        seed         = $seed.Hex
        nonce        = $Nonce
        nonce_source = $NonceSource
        size         = $k
        size_asked   = $sizeAsked
        size_source  = $SizeSource
        reserve      = @($seats | Where-Object { $_.Rule -like 'lab-*' }).Count
        eligible     = [object[]]@($eligible | ForEach-Object { [pscustomobject]@{ position = [int]$_.Entry.Position; lineage = $_.Lineage; lab = $_.Lab; lab_source = $_.LabSource; score = (& $round $_.Score.Score 4); basis = $_.Score.Basis; ratings = (& $round $_.Score.Ratings 2); required = [bool]$_.Required } })
        picked       = [object[]]@($seats | ForEach-Object { [pscustomobject]@{ slot = $_.Slot; position = [int]$_.Member.Entry.Position; lineage = $_.Member.Lineage; lab = $_.Member.Lab; rule = $_.Rule } })
        explored     = [object[]]@($seats | Where-Object { $_.Rule -like '*-explore' } | ForEach-Object { $_.Member.Lineage })
        required     = [object[]]@($pinned | ForEach-Object { $_.Lineage })
    }
    return [pscustomobject]@{ Members = [object[]]@($Members); Picked = [object[]]@($seats | ForEach-Object { $_.Member }); K = $k; SizeAsked = $sizeAsked; Routing = $routing; Warnings = [string[]]$warnings.ToArray() }
}

# (wave 26b, D11) Where a run's timeout came from, as the Timeout lines say it: purpose -> "the
# default of purpose <p>", roster -> "the roster entry's timeout_sec", explicit -> "-TimeoutSec".
function Format-TimeoutSource {
    param([string]$Source, [string]$PurposeLabel = 'none')
    switch ($Source) {
        'purpose' { return "the default of purpose $PurposeLabel" }
        'roster' { return "the roster entry's timeout_sec" }
        default { return '-TimeoutSec' }
    }
}

# The routing record as console lines (the panel run and its dry run print the same).
function Format-RoutingLines {
    param($Routing, [string]$Purpose = '')
    $lines = New-Object System.Collections.Generic.List[string]
    $sizeWhy = $(if ($Routing.size_source -eq 'purpose') { "the default of purpose $(if ($Purpose) { $Purpose } else { 'none' })" } else { [string]$Routing.size_source })
    # (wave 26c, D5) the requested count when the size differs from it (raised by the required
    # reviewers, reduced to the eligible ones)
    $askedV = Get-PropertyValue $Routing 'size_asked' $null
    if ($null -ne $askedV -and [int]$askedV -ne [int]$Routing.size) { $sizeWhy += "; asked $askedV" }
    $sizeText = "size $($Routing.size) ($sizeWhy)"
    if ($Routing.mode -eq 'routed') {
        $lines.Add("Routing: routed by the ratings - $sizeText; seed $($Routing.seed.Substring(0, 12)) (nonce $($Routing.nonce) from $($Routing.nonce_source)); exploration $($script:RoutingExplore) per slot")
    } else {
        $why = $(if ($Routing.fallback) { "fallback: $($Routing.fallback) - no eligible reviewer has $($script:RoutingMinRatings) ratings in $($script:RoutingWindowDays) days" } else { '-PanelOrder roster' })
        $lines.Add("Routing: roster order ($why) - $sizeText")
    }
    $el = @($Routing.eligible | ForEach-Object { "#$($_.position) $($_.lineage) (lab $($_.lab)$(if ($_.lab_source -ne 'roster') { " by $($_.lab_source)" }); score $(([double]$_.score).ToString('0.###', $script:Invariant)) $($_.basis)$(if ([double]$_.ratings -gt 0) { " of $(([double]$_.ratings).ToString('0.##', $script:Invariant))" })$(if ($_.required) { '; required' }))" })
    $lines.Add("  eligible: $(if ($el.Count -gt 0) { $el -join ', ' } else { '(none)' })")
    $pk = @($Routing.picked | ForEach-Object { "$($_.slot). #$($_.position) $($_.lineage) ($($_.rule))" })
    $lines.Add("  picked  : $(if ($pk.Count -gt 0) { $pk -join ', ' } else { '(none)' })")
    if (@($Routing.required).Count -gt 0) { $lines.Add("  required: $(@($Routing.required) -join ', ')") }
    return , ([string[]]$lines.ToArray())
}

# ----------------------------------------------------------------------------- roles (wave 26, R16)
#
# A role narrows what a reviewer looks at (D8): a Markdown block inserted into the prompt after the
# ask and before the brief - never inside the output contract; the verdict rules, the read-only
# sandbox and the reply format stay as they are. A role name is a slug (checked before any path is
# built); `<CollabDir>/roles/<name>.md` of the repository wins over the plugin's
# `templates/role-<name>.md` (edge-cases, security, tests, docs ship). { Name; Path; Source
# ('repository' | 'plugin'); Text; Error }.
# (wave 26b, D1 / F22-1) A role file's containment: the text goes into the prompt of external
# reviewers, so the file must be a regular file (no reparse point - symlink, junction - on the
# file, nor on any directory from $Root down to it, $Root included) whose full path lies inside
# $Root. '' when the file passes (or does not exist at all), else the reason. Attributes are read
# without following links (FileSystemInfo.Attributes is the link's own).
function Get-RoleFileProblem {
    param([string]$Path, [string]$Root)
    $sep = [IO.Path]::DirectorySeparatorChar
    $cmp = $(if ($sep -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal })
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($rootFull + $sep, $cmp)) { return "'$Path' is outside '$rootFull'" }
    $fi = New-Object IO.FileInfo($full)
    $di = New-Object IO.DirectoryInfo($full)
    if (-not $fi.Exists -and -not $di.Exists) {
        # a dangling link reports neither; its attributes still read
        $attr = $null
        try { $attr = [IO.File]::GetAttributes($full) } catch { $attr = $null }
        if ($null -eq $attr) { return '' }
        return "'$full' is not a regular file (attributes $attr)"
    }
    if ($di.Exists) { return "'$full' is a directory$(if (($di.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { ' link (reparse point)' }), not a regular file" }
    if (($fi.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return "'$full' is a symbolic link or another reparse point, not a regular file" }
    $dir = $fi.Directory
    while ($dir) {
        if (($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return "the directory '$($dir.FullName)' is a junction or symbolic link (reparse point)" }
        if ([string]::Equals($dir.FullName.TrimEnd('\', '/'), $rootFull, $cmp)) { break }
        $dir = $dir.Parent
    }
    return ''
}

function Resolve-RoleFile {
    param([string]$Name, [string]$CollabRoot = '', [string]$PluginRoot = '')
    $r = [pscustomobject]@{ Name = $Name; Path = ''; Source = ''; Text = ''; Error = '' }
    if ($Name -cnotmatch $script:SlugPattern) { $r.Error = "role '$Name' is not a slug (lowercase letters, digits, dot, dash, underscore)"; return $r }
    $candidates = New-Object System.Collections.Generic.List[object]
    if ($CollabRoot) { $candidates.Add(@((Join-Path (Join-Path $CollabRoot 'roles') "$Name.md"), 'repository', (Join-Path $CollabRoot 'roles'))) }
    if ($PluginRoot) { $candidates.Add(@((Join-Path (Join-Path $PluginRoot 'templates') "role-$Name.md"), 'plugin', (Join-Path $PluginRoot 'templates'))) }
    foreach ($c in $candidates) {
        # (wave 26b, D1) a roles directory that is itself a junction refuses every role of it
        $rootInfo = New-Object IO.DirectoryInfo([IO.Path]::GetFullPath($c[2]))
        if ($rootInfo.Exists -and ($rootInfo.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $r.Error = "role file refused: the $($c[1]) roles directory '$($rootInfo.FullName)' is a junction or symbolic link (reparse point)"; return $r
        }
        $why = Get-RoleFileProblem -Path $c[0] -Root $c[2]
        if ($why) { $r.Error = "role file refused: $why"; return $r }
        if (Test-Path -LiteralPath $c[0] -PathType Leaf) {
            $text = (Read-SharedText -Path $c[0]).Trim()
            if (-not $text) { $r.Error = "the role file '$($c[0])' is empty"; return $r }
            $r.Path = $c[0]; $r.Source = $c[1]; $r.Text = $text
            return $r
        }
    }
    $known = New-Object System.Collections.Generic.List[string]
    foreach ($c in $candidates) {
        $dir = Split-Path -Parent $c[0]
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
            $n = $f.BaseName
            if ($c[1] -eq 'plugin') { if ($n -notlike 'role-*') { continue }; $n = $n.Substring(5) }
            if ($n -cmatch $script:SlugPattern -and -not $known.Contains($n)) { $known.Add($n) }
        }
    }
    $r.Error = "unknown role '$Name' (no $(if ($CollabRoot) { "$(Join-Path (Join-Path $CollabRoot 'roles') "$Name.md") nor " })templates/role-$Name.md; known: $(if ($known.Count -gt 0) { ($known.ToArray() | Sort-Object) -join ', ' } else { 'none' }))"
    return $r
}

# (wave 26b, D4) Kuhn's augmenting path for the role matching: can role $Role (an index into
# $Willing, a list of int[] member indices) take a member, moving earlier roles along? $MatchOf:
# member index -> role index (updated on success).
function Find-RoleAugment {
    param([int]$Role, $Willing, [hashtable]$MatchOf, [hashtable]$Seen)
    foreach ($m in @($Willing[$Role])) {
        if ($Seen.ContainsKey([int]$m)) { continue }
        $Seen[[int]$m] = $true
        if (-not $MatchOf.ContainsKey([int]$m) -or (Find-RoleAugment -Role ([int]$MatchOf[[int]$m]) -Willing $Willing -MatchOf $MatchOf -Seen $Seen)) { $MatchOf[[int]$m] = $Role; return $true }
    }
    return $false
}

# (wave 26b, D4) Can every role of $RoleIdx take a distinct member of $Free (member indices) that
# is willing to take it? $WillingOf: role index -> int[] member indices.
function Test-RoleMatching {
    param([int[]]$RoleIdx, [int[]]$Free, [hashtable]$WillingOf)
    $willing = New-Object System.Collections.Generic.List[object]
    foreach ($ri in @($RoleIdx)) { $willing.Add([int[]]@(@($WillingOf[[int]$ri]) | Where-Object { @($Free) -contains [int]$_ })) }
    $matchOf = @{}
    for ($i = 0; $i -lt $willing.Count; $i++) {
        if (-not (Find-RoleAugment -Role $i -Willing $willing -MatchOf $matchOf -Seen @{})) { return $false }
    }
    return $true
}

# -Roles a,b,c over a panel's picked members (D8): the roles go by SCORE RANK (the routing score,
# highest first; ties by seat). (wave 26b, D4 / F22-3) An exact matching, not a greedy pass: a
# role is CONSTRAINED when a seated member is willing to take it (its roster entry's `roles`); the
# assignment gives every constrained role a willing member and, among the assignments that do,
# each role in the order given the best-ranked member possible (lexicographic by rank; an
# unconstrained role takes the best-ranked member left that no later constrained role needs). Only
# when no such assignment exists do the roles go by the wave 26 greedy rank order (each role to
# the best-ranked willing member left, else the best-ranked left) - and Note says so (the ledger's
# panel.roles_note, a warning). More roles than members is refused. { Of (hashtable roster
# position -> role); Note; Error }.
function Select-RoleAssignment {
    param([object[]]$Members, [string[]]$Roles)
    $r = [pscustomobject]@{ Of = @{}; Note = ''; Error = '' }
    $list = @($Members | Where-Object { $_ })
    if (@($Roles).Count -gt $list.Count) { $r.Error = "-Roles names $(@($Roles).Count) roles for $($list.Count) panel member$(if ($list.Count -ne 1) { 's' }) (at most one role each)"; return $r }
    $ranked = New-Object System.Collections.Generic.List[object]
    $i = 0
    foreach ($m in $list) {
        $i++
        $sc = $script:RoutingNeutral
        if ($m.PSObject.Properties['Score'] -and $null -ne $m.Score) { $sc = [double]$m.Score.Score }
        $ranked.Add([pscustomobject]@{ Member = $m; Score = $sc; Seat = $i })
    }
    $left = New-Object System.Collections.Generic.List[object]
    foreach ($x in @($ranked | Sort-Object -Property @{ Expression = { $_.Score }; Descending = $true }, @{ Expression = { $_.Seat }; Descending = $false })) { $left.Add($x) }
    $order = [object[]]$left.ToArray()
    $roleArr = [string[]]@($Roles)
    # the willing members of every role, as rank indices; a role nobody seated declares is free
    $willingOf = @{}
    $constrained = New-Object System.Collections.Generic.List[int]
    for ($ri = 0; $ri -lt $roleArr.Count; $ri++) {
        $w = New-Object System.Collections.Generic.List[int]
        for ($mi = 0; $mi -lt $order.Count; $mi++) { if (@(Get-PropertyValue $order[$mi].Member.Entry 'Roles' @()) -ccontains $roleArr[$ri]) { $w.Add($mi) } }
        $willingOf[$ri] = [int[]]$w.ToArray()
        if ($w.Count -gt 0) { $constrained.Add($ri) }
    }
    $allIdx = [int[]]@(0..($order.Count - 1))
    if ($order.Count -eq 0) { $allIdx = [int[]]@() }
    if (Test-RoleMatching -RoleIdx ([int[]]$constrained.ToArray()) -Free $allIdx -WillingOf $willingOf) {
        # role by role in order, the best-ranked member that still leaves every later constrained
        # role a willing member: the lexicographically best assignment that honours willingness
        $used = New-Object System.Collections.Generic.List[int]
        for ($ri = 0; $ri -lt $roleArr.Count; $ri++) {
            $later = [int[]]@($constrained | Where-Object { $_ -gt $ri })
            for ($mi = 0; $mi -lt $order.Count; $mi++) {
                if ($used.Contains($mi)) { continue }
                if ($constrained.Contains($ri) -and @($willingOf[$ri]) -notcontains $mi) { continue }
                $free = [int[]]@($allIdx | Where-Object { $_ -ne $mi -and -not $used.Contains([int]$_) })
                if (Test-RoleMatching -RoleIdx $later -Free $free -WillingOf $willingOf) {
                    $used.Add($mi)
                    $r.Of[[int]$order[$mi].Member.Entry.Position] = $roleArr[$ri]
                    break
                }
            }
        }
        return $r
    }
    $unmet = New-Object System.Collections.Generic.List[string]
    foreach ($ri in $constrained) { $unmet.Add("$($roleArr[$ri]): willing $(@($willingOf[$ri] | ForEach-Object { "#$($order[$_].Member.Entry.Position)" }) -join ' ')") }
    $r.Note = "roles: no assignment gives every role a willing member ($($unmet.ToArray() -join '; ')) - the roles went by score rank, a willing member first where one was left"
    foreach ($role in $roleArr) {
        $willing = @($left | Where-Object { @(Get-PropertyValue $_.Member.Entry 'Roles' @()) -ccontains $role })
        $take = $(if ($willing.Count -gt 0) { $willing[0] } else { $left[0] })
        $r.Of[[int]$take.Member.Entry.Position] = $role
        [void]$left.Remove($take)
    }
    return $r
}

# The endpoint groups of a set of roster members ({ Entry; Identity } - Select-PanelMembers'
# records): one group per provider label, merged with every other label whose members resolve
# to the same provider fingerprint, to a fixed point (two labels on one base URL; every agy
# label - they share one Google sign-in). A member whose identity is unresolved adds no
# fingerprint. Groups are numbered in the order their first member appears. { Labels
# (string[], first-seen order); Groups (object[] of { Labels (List[string]); Positions
# (List[int] roster positions) }); GroupOf (hashtable roster position -> group index);
# IndexOfLabel (hashtable label -> group index) }. Used twice (wave 24, D16): over a panel's
# RUNNERS for the scheduling plan (Get-PanelPlan) and over ALL roster entries for the
# availability view (Get-RosterAvailability: an outage marks its whole group).
# (wave 29, D5 / F02-4, F04-1) -Scheduling (the panel plan only): the members of an engine whose
# row has ParallelScope 'engine' (claude) share one group whatever their fingerprints - they run one
# after another unless the roster's "parallel" raises their labels; the availability view keeps its
# groups by endpoint (D7: an Opus outage does not mark Sonnet). (wave 29b, E7) -Scheduling too: a
# member with a roster `plan` adds the key 'plan:<slug>' - the members of one plan share a group
# across engines and routes (a codex ZAI member and a claude ZAI-claude member serialize); the
# availability view does not group by plan (E5: only a quota failure propagates over a plan).
function Get-EndpointGroups {
    param([object[]]$Members, [switch]$Scheduling)
    $labels = New-Object System.Collections.Generic.List[string]
    $fps = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($m in @($Members | Where-Object { $_ })) {
        $label = [string]$m.Entry.Provider
        if (-not $fps.ContainsKey($label)) { $fps[$label] = New-Object System.Collections.Generic.List[string]; $labels.Add($label) }
        $fp = ''
        if ($m.Identity -and $m.Identity.Resolved) { $fp = [string]$m.Identity.Fingerprint }
        if ($fp -and -not $fps[$label].Contains($fp)) { $fps[$label].Add($fp) }
        if ($Scheduling) {
            $mEngine = [string](Get-PropertyValue $m.Entry 'Engine' '')
            $mSpec = $(if ($mEngine) { Get-EngineSpec -Name $mEngine } else { $null })
            if ($mSpec -and [string](Get-PropertyValue $mSpec 'ParallelScope' '') -eq 'engine' -and -not $fps[$label].Contains("engine:$mEngine")) { $fps[$label].Add("engine:$mEngine") }
            $mPlan = [string](Get-PropertyValue $m.Entry 'Plan' '')
            if ($mPlan -and -not $fps[$label].Contains("plan:$mPlan")) { $fps[$label].Add("plan:$mPlan") }
        }
    }
    # one group per label, then labels that share a fingerprint are merged (to a fixed point)
    $groupOfLabel = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    for ($i = 0; $i -lt $labels.Count; $i++) { $groupOfLabel[$labels[$i]] = $i }
    $changed = $true
    while ($changed) {
        $changed = $false
        for ($i = 0; $i -lt $labels.Count; $i++) {
            for ($j = $i + 1; $j -lt $labels.Count; $j++) {
                $gi = $groupOfLabel[$labels[$i]]; $gj = $groupOfLabel[$labels[$j]]
                if ($gi -eq $gj) { continue }
                $shared = @($fps[$labels[$i]] | Where-Object { $fps[$labels[$j]].Contains($_) }).Count -gt 0
                if (-not $shared) { continue }
                $keep = [Math]::Min($gi, $gj); $drop = [Math]::Max($gi, $gj)
                foreach ($l in $labels) { if ($groupOfLabel[$l] -eq $drop) { $groupOfLabel[$l] = $keep } }
                $changed = $true
            }
        }
    }
    $groups = New-Object System.Collections.Generic.List[object]
    $indexOf = @{}
    $groupOf = @{}
    foreach ($m in @($Members | Where-Object { $_ })) {
        $label = [string]$m.Entry.Provider
        $gid = $groupOfLabel[$label]
        if (-not $indexOf.ContainsKey($gid)) {
            $indexOf[$gid] = $groups.Count
            $groups.Add([pscustomobject]@{ Labels = (New-Object System.Collections.Generic.List[string]); Positions = (New-Object System.Collections.Generic.List[int]) })
        }
        $g = $groups[$indexOf[$gid]]
        if (-not $g.Labels.Contains($label)) { $g.Labels.Add($label) }
        $g.Positions.Add([int]$m.Entry.Position)
        $groupOf[[int]$m.Entry.Position] = $indexOf[$gid]
    }
    $indexOfLabel = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($l in $labels) { $indexOfLabel[$l] = $indexOf[$groupOfLabel[$l]] }
    return [pscustomobject]@{ Labels = [string[]]$labels.ToArray(); Groups = [object[]]$groups.ToArray(); GroupOf = $groupOf; IndexOfLabel = $indexOfLabel }
}

# The concurrency plan of a panel (0.4.x wave 21, D8 - endpoint-aware): members that reach the
# same ENDPOINT run one after another, members of different endpoints at once. The endpoint
# groups come from Get-EndpointGroups over the runners. A group runs 1 member at a time unless
# the roster's top-level "parallel" raises its label (a merged group: the smallest limit of its
# labels); -Cap (-PanelConcurrency) caps the total (0 = no cap, 1 = strictly one after another
# in roster order). $Runners: the members Select-PanelMembers runs (State 'run'), in roster
# order.
# (wave 29b, E7) A group that holds members of a `plan` is limited by the plan too: the plan's own
# "parallel" value (default 1) caps it, and a label without a "parallel" value of its own takes its
# plan's - so {"parallel": {"zai": 2}} lets a codex ZAI member and a claude ZAI-claude member run
# at once, and without it they run one after another.
# { Groups (object[] of { Labels (string[]); Limit; Positions (int[] roster positions) });
#   GroupOf (hashtable roster position -> group index); Cap; Effective (the most members
#   that can run at once); Text ('at once' | 'one after another' | 'at most <k> at a time');
#   Limits (ordered: label -> its group's limit, roster order) }
function Get-PanelPlan {
    param([object[]]$Runners, [hashtable]$Parallel = $null, [int]$Cap = 0)
    $eg = Get-EndpointGroups -Members $Runners -Scheduling
    $effective = 0
    $limits = [ordered]@{}
    $out = New-Object System.Collections.Generic.List[object]
    # (E7) the plans of each label among the runners
    $plansOf = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($m in @($Runners | Where-Object { $_ })) {
        $pl = [string](Get-PropertyValue $m.Entry 'Plan' '')
        $lb = [string]$m.Entry.Provider
        if (-not $plansOf.ContainsKey($lb)) { $plansOf[$lb] = New-Object System.Collections.Generic.List[string] }
        if ($pl -and -not $plansOf[$lb].Contains($pl)) { $plansOf[$lb].Add($pl) }
    }
    $planLimit = { param([string]$P) if ($null -ne $Parallel -and $Parallel.ContainsKey($P)) { [int]$Parallel[$P] } else { 1 } }
    foreach ($g in $eg.Groups) {
        $limit = 0
        foreach ($l in $g.Labels) {
            $v = 1
            $lPlans = $(if ($plansOf.ContainsKey($l)) { @($plansOf[$l]) } else { @() })
            if ($null -ne $Parallel -and $Parallel.ContainsKey($l)) { $v = [int]$Parallel[$l] }
            elseif ($lPlans.Count -gt 0) { $v = [int](@($lPlans | ForEach-Object { & $planLimit $_ }) | Measure-Object -Minimum).Minimum }
            if ($limit -eq 0 -or $v -lt $limit) { $limit = $v }
            foreach ($pl in $lPlans) { $pv = & $planLimit $pl; if ($pv -lt $limit) { $limit = $pv } }
        }
        $effective += [Math]::Min($limit, $g.Positions.Count)
        $out.Add([pscustomobject]@{ Labels = [string[]]$g.Labels.ToArray(); Limit = $limit; Positions = [int[]]$g.Positions.ToArray() })
    }
    foreach ($l in $eg.Labels) { $limits[$l] = $out[$eg.IndexOfLabel[$l]].Limit }
    if ($Cap -gt 0 -and $Cap -lt $effective) { $effective = $Cap }
    $count = @($Runners | Where-Object { $_ }).Count
    $text = if ($effective -ge $count) { 'at once' } elseif ($effective -le 1) { 'one after another' } else { "at most $effective at a time" }
    return [pscustomobject]@{ Groups = [object[]]$out.ToArray(); GroupOf = $eg.GroupOf; Cap = $Cap; Effective = $effective; Text = $text; Limits = $limits }
}

# The collab paths an agy panel member's tree check leaves out besides its own handoff files
# (0.4.x wave 21, D7): the task's two stores and the handoffs of the OTHER members of its
# panel ($SiblingNns; none when the panel runs one member at a time), each with its
# Write-TextAtomic temp variant (.<name>.<guid>.tmp in the same directory). The caller passes
# deliberately the union of all other members, not only those that can overlap this one
# (F11-5): an ignored path that did not change hides nothing, and one that changed was written
# by a member running meanwhile - or by this member's reviewer, the documented D7 residual.
# Prefixes relative to the collab root, '/'-separated (Get-CollabSnapshot keys). Everything
# else in the collab root stays monitored (other tasks, state.md, briefs).
function Get-PanelIgnorePrefixes {
    param([string]$Task, [string[]]$SiblingNns = @())
    $nns = @($SiblingNns | Where-Object { $_ })
    $p = New-Object System.Collections.Generic.List[string]
    if ($nns.Count -eq 0) { return , ([string[]]$p.ToArray()) }
    foreach ($store in @('sessions.json', 'findings.json')) { $p.Add("$Task/$store"); $p.Add("$Task/.$store.") }
    foreach ($s in $nns) { $p.Add("$Task/handoffs/$s-"); $p.Add("$Task/handoffs/.$s-") }
    return , ([string[]]$p.ToArray())
}

# "openai :: gpt-5.1 (usage limit until ...), ZAI :: glm-5.3 (missing: env ZAI_KEY not set)"
function Format-RosterSkips {
    param([object[]]$Skipped)
    return ((@($Skipped | Where-Object { $_ }) | ForEach-Object { "$(Format-ReviewerLineage -Provider $_.provider -Model $_.model -Engine ([string](Get-PropertyValue $_ 'engine' ''))) ($($_.reason))" }) -join ', ')
}

# The kill guard of a panel member (0.4.x wave 21, D11; wave 24): its timeout, one format-repair
# turn (-Repair) and - an engine with a denial retry (agy) - one denial-retry turn
# (-DenialRetry) of min(timeout, 300) s each, the timeout continuation's budget (-ContinueSec;
# 0 = none), the 60 s write-lock wait and 120 s slack. The panel run stops a member that
# outlives it.
function Get-PanelMemberGuard {
    param([int]$TimeoutSec, [int]$ContinueSec = 0, [switch]$Repair, [switch]$DenialRetry)
    $g = $TimeoutSec + 60 + 120
    if ($Repair) { $g += [Math]::Min($TimeoutSec, 300) }
    if ($DenialRetry) { $g += [Math]::Min($TimeoutSec, 300) }
    if ($ContinueSec -gt 0) { $g += $ContinueSec }
    return $g
}

# ----------------------------------------------------------------------------- availability view (wave 24)
#
# One truth about availability (D14-D17): the roster walk, codex-providers.ps1's rows, its -Short
# line and the SessionStart hook judge a roster entry with the SAME verdict - the engine's launch
# invariant, then Get-PreflightVerdict -RosterWalk (through Select-PanelMembers -All, which judges
# EVERY entry, a weighty one too) - on the endpoint health of the ledgers of the repository the
# command runs in (Read-AllTaskConsults). An entry is available, out (unavailable: missing
# credentials, a recorded auth failure, a usage limit - with a known reset, or without one for 60
# minutes -, an identity error, a launch refusal) or not checked (unknown: an engine sign-in that
# -NoNetwork did not check, an unresolved identity, a check that could not run).

# "in 2d 10h" | "in 3h 20m" | "in 52m" | "in <1m" - rounded to the hour from one day on, else to
# the minute; "now" when the span is not positive.
function Format-RelativeHint {
    param([TimeSpan]$Span)
    if ($Span.TotalSeconds -le 0) { return 'now' }
    $m = [long][Math]::Round($Span.TotalMinutes, [MidpointRounding]::AwayFromZero)
    if ($m -lt 1) { return 'in <1m' }
    if ($m -ge 1440) {
        $h = [long][Math]::Round($Span.TotalHours, [MidpointRounding]::AwayFromZero)
        $d = [long][Math]::Floor($h / 24)
        $hh = $h - 24 * $d
        if ($hh -eq 0) { return "in ${d}d" }
        return "in ${d}d ${hh}h"
    }
    if ($m -ge 60) {
        $h = [long][Math]::Floor($m / 60)
        $mm = $m - 60 * $h
        if ($mm -eq 0) { return "in ${h}h" }
        return "in ${h}h ${mm}m"
    }
    return "in ${m}m"
}

# A moment in LOCAL time for the one-line views (D17: ToLocalTime()): 'HH:mm' on the local day of
# $NowUtc, 'ddd HH:mm' up to six days from it (either way), else 'yyyy-MM-dd HH:mm' (invariant
# culture: English day names).
function Format-LocalWhen {
    param([DateTimeOffset]$When, [datetime]$NowUtc = [datetime]::UtcNow)
    $local = $When.ToLocalTime()
    $nowLocal = (New-Object DateTimeOffset ([datetime]::SpecifyKind($NowUtc, [DateTimeKind]::Utc))).ToLocalTime()
    $days = [Math]::Abs(($local.Date - $nowLocal.Date).TotalDays)
    if ($days -lt 1) { return $local.ToString('HH:mm', $script:Invariant) }
    if ($days -le 6) { return $local.ToString('ddd HH:mm', $script:Invariant) }
    return $local.ToString('yyyy-MM-dd HH:mm', $script:Invariant)
}

# The first clause of a launch refusal - up to the first ': ' outside parentheses ("META_API_KEY
# is set"), the whole text when there is none: a complete phrase, never a cut (D17).
function Get-FirstClause {
    param([string]$Text)
    $depth = 0
    for ($i = 0; $i -lt $Text.Length - 1; $i++) {
        $c = $Text[$i]
        if ($c -eq '(') { $depth++ } elseif ($c -eq ')' -and $depth -gt 0) { $depth-- }
        elseif ($c -eq ':' -and $depth -eq 0 -and $Text[$i + 1] -eq ' ') { return $Text.Substring(0, $i) }
    }
    return $Text
}

# One availability record from a verdict (Get-PreflightVerdict -RosterWalk) and a launch refusal
# ($Block; it outranks the verdict): { Position; Provider; Model; Engine; Lineage ('<provider> ::
# <model>', the provider alone without a model); Group; State available | out (unavailable,
# refused) | not checked (unknown); Kind; Reason (the roster walk's reason); Short (the one-line
# view's complete phrase, in LOCAL time with a rounded relative hint - "until Sun 20:35, in 2d
# 10h"; "limit hit 10:31, reset unknown; retry after 11:31, in 52m" ((wave 24c) a burst: "burst
# limit hit 10:31, reset unknown; retry after 10:41, in 2m"); "auth failed Sat 10:31";
# the credential's reason ("env MIMO_API_KEY not set", "sign-in not checked"); "refused: <first
# clause of the launch refusal>"); Hit; Until }.
function ConvertTo-AvailabilityRecord {
    param([int]$Position, [string]$Provider, [string]$Model = '', [string]$Engine = 'codex', [int]$Group = 0, $Verdict = $null, [string]$Block = '', [datetime]$UtcNow = [datetime]::UtcNow)
    $rec = [pscustomobject]@{ Position = $Position; Provider = $Provider; Model = $Model; Engine = $(if ($Engine) { $Engine } else { 'codex' }); Lineage = $(if ($Model) { Format-Lineage -Provider $Provider -Model $Model } else { $Provider }); Group = $Group; State = 'available'; Kind = ''; Reason = ''; Short = ''; Hit = $null; Until = $null }
    $v = $Verdict
    if ($Block) {
        $rec.State = 'out'; $rec.Kind = 'refused'; $rec.Reason = "refused: $Block"; $rec.Short = "refused: $(Get-FirstClause $Block)"
        return $rec
    }
    if (-not $v -or $v.State -eq 'available') { return $rec }
    $rec.State = $(if ($v.State -eq 'unavailable') { 'out' } else { 'not checked' })
    $rec.Kind = [string]$v.Kind
    $rec.Reason = [string]$v.Reason
    $rec.Hit = $v.Hit
    $rec.Until = $v.Until
    $now = New-Object DateTimeOffset ([datetime]::SpecifyKind($UtcNow, [DateTimeKind]::Utc))
    # (wave 29b, E5) out because its plan is out on another route: "plan zai (usage limit on ZAI
    # until 15:00, in 3h)"
    $pqv = Get-PropertyValue $v 'PlanQuota' $null
    if ($pqv -and $rec.Kind -eq 'quota' -and $null -ne $rec.Until) { $rec.Short = "plan $($pqv.Plan) (usage limit on $($pqv.Label) until $(Format-LocalWhen -When $rec.Until -NowUtc $UtcNow), $(Format-RelativeHint ($rec.Until - $now)))" }
    elseif ($pqv -and $rec.Kind -eq 'quota-unknown-reset' -and $null -ne $rec.Until) { $rec.Short = "plan $($pqv.Plan) ($(if ([bool](Get-PropertyValue $v 'Burst' $false)) { 'burst limit' } else { 'limit' }) hit on $($pqv.Label) $(Format-LocalWhen -When $rec.Hit -NowUtc $UtcNow), reset unknown; retry after $(Format-LocalWhen -When $rec.Until -NowUtc $UtcNow), $(Format-RelativeHint ($rec.Until - $now)))" }
    elseif ($rec.Kind -eq 'quota' -and $null -ne $rec.Until) { $rec.Short = "until $(Format-LocalWhen -When $rec.Until -NowUtc $UtcNow), $(Format-RelativeHint ($rec.Until - $now))" }
    elseif ($rec.Kind -eq 'quota-unknown-reset' -and $null -ne $rec.Until) { $rec.Short = "$(if ([bool](Get-PropertyValue $v 'Burst' $false)) { 'burst limit hit' } else { 'limit hit' }) $(Format-LocalWhen -When $rec.Hit -NowUtc $UtcNow), reset unknown; retry after $(Format-LocalWhen -When $rec.Until -NowUtc $UtcNow), $(Format-RelativeHint ($rec.Until - $now))" }
    elseif ($rec.Kind -eq 'auth') { $rec.Short = "auth failed $(if ($null -ne $rec.Hit) { Format-LocalWhen -When $rec.Hit -NowUtc $UtcNow } else { 'recently' })" }
    elseif ($rec.Kind -eq 'unresolved') { $rec.Short = 'identity unresolved' }
    elseif ($v.Credential -and $v.Credential.Reason -and @('credentials', 'unknown') -contains $rec.Kind) { $rec.Short = [string]$v.Credential.Reason }
    else { $rec.Short = [string]$v.Reason }
    return $rec
}

# Every roster entry's availability (D15): Select-PanelMembers -All [-NoNetwork] - the roster
# walk's verdict for each entry, in roster order - plus the endpoint groups over ALL entries
# (Get-EndpointGroups; D16: an outage recorded on an endpoint - auth, a usage limit - marks every
# entry of its group). { Records (object[] in roster order of { Position; Provider; Model;
# Engine; Lineage ('<provider> :: <model>'); Group; State available|out|not checked; Kind
# (Get-PreflightVerdict's, or refused); Reason (the roster walk's reason); Short (the one-line
# view's phrase, local time - Format-AvailabilityLine); Hit; Until }); Groups (Get-EndpointGroups);
# Total; Available; Out; NotChecked; Selected (the first available record - the entry the
# single-reviewer walk selects - or $null) }.
function Get-RosterAvailability {
    param($Roster, $Config, [object[]]$Consults, [string]$Launcher, [hashtable]$LoginCache = $null, [datetime]$UtcNow = [datetime]::UtcNow, [string]$OpenAiBaseUrl = '', [hashtable]$EngineLaunchers = $null, [switch]$NoNetwork, [hashtable]$Cache = $null)
    $sel = Select-PanelMembers -Roster $Roster -Config $Config -Consults $Consults -Launcher $Launcher -LoginCache $LoginCache -UtcNow $UtcNow -OpenAiBaseUrl $OpenAiBaseUrl -All -EngineLaunchers $EngineLaunchers -NoNetwork:$NoNetwork -Cache $Cache
    $members = @($sel.Members | Where-Object { $_ })
    $eg = Get-EndpointGroups -Members $members
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($m in $members) {
        $pos = [int]$m.Entry.Position
        $records.Add((ConvertTo-AvailabilityRecord -Position $pos -Provider ([string]$m.Entry.Provider) -Model ([string]$m.Identity.Model) -Engine ([string]$m.Entry.Engine) -Group ([int]$eg.GroupOf[$pos]) -Verdict $m.Verdict -Block ([string]$m.Block) -UtcNow $UtcNow))
    }
    # D16: an outage recorded on the endpoint marks the whole group (an entry of it that was not
    # judged out by itself - e.g. an unresolved one - is out with the same reason)
    foreach ($rec in @($records | Where-Object { $_.State -eq 'out' -and @('auth', 'quota', 'quota-unknown-reset') -contains $_.Kind })) {
        foreach ($o in @($records | Where-Object { $_.Group -eq $rec.Group -and $_.State -ne 'out' })) {
            $o.State = 'out'; $o.Kind = $rec.Kind; $o.Reason = $rec.Reason; $o.Hit = $rec.Hit; $o.Until = $rec.Until; $o.Short = $rec.Short
        }
    }
    $all = [object[]]$records.ToArray()
    return [pscustomobject]@{
        Records    = $all
        Groups     = $eg
        Total      = $all.Count
        Available  = @($all | Where-Object { $_.State -eq 'available' }).Count
        Out        = @($all | Where-Object { $_.State -eq 'out' }).Count
        NotChecked = @($all | Where-Object { $_.State -eq 'not checked' }).Count
        Selected   = (@($all | Where-Object { $_.State -eq 'available' }) | Select-Object -First 1)
    }
}

# The one-line availability view (D17; the SessionStart hook, codex-providers.ps1 -Short): what is
# OUT and what was NOT CHECKED, per roster entry, then the count -
#   codex-consult: out - openai :: gpt-6-astra (until Sun 20:35, in 2d 10h), gemini :: * (until
#   Sun 21:30, in 2d 11h); 9 of 11 reviewers available
#   codex-consult: all 11 reviewers available
# The entries of one endpoint group collapse to '<label> :: *' (labels of a merged group joined by
# '+') when there are at least two and all share the state and the phrase; otherwise one clause
# per entry. Nothing is cut. The count names the not-checked entries ("7 of 11 reviewers
# available, 2 out, 2 not checked") whenever there are any (then the three counts do not add up
# from the clauses alone). $Noun: 'reviewers' (a roster) or 'providers' (none).
function Format-AvailabilityLine {
    param($Availability, [string]$Noun = 'reviewers', [string]$Prefix = 'codex-consult: ', [string]$Suffix = '')
    $recs = @($Availability.Records | Where-Object { $_ })
    $n = $recs.Count
    $noun = $(if ($n -eq 1) { $Noun -replace 's$', '' } else { $Noun })
    if ($n -eq 0) { return "${Prefix}no $Noun to check$Suffix" }
    $a = @($recs | Where-Object { $_.State -eq 'available' }).Count
    $o = @($recs | Where-Object { $_.State -eq 'out' }).Count
    $c = @($recs | Where-Object { $_.State -eq 'not checked' }).Count
    if ($o -eq 0 -and $c -eq 0) { return "${Prefix}all $n $noun available$Suffix" }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($state in @('out', 'not checked')) {
        $these = @($recs | Where-Object { $_.State -eq $state })
        if ($these.Count -eq 0) { continue }
        $clauses = New-Object System.Collections.Generic.List[string]
        $done = @{}
        foreach ($r in $these) {
            if ($done.ContainsKey($r.Group)) { continue }
            $group = @($recs | Where-Object { $_.Group -eq $r.Group })
            $same = @($group | Where-Object { $_.State -eq $state -and $_.Short -ceq $r.Short })
            if ($group.Count -ge 2 -and $same.Count -eq $group.Count) {
                $done[$r.Group] = $true
                $labels = @($group | ForEach-Object { $_.Provider } | Select-Object -Unique)
                $clauses.Add("$($labels -join '+') :: * ($($r.Short))")
            } else {
                $clauses.Add("$($r.Lineage) ($($r.Short))")
            }
        }
        $parts.Add("$state - $($clauses.ToArray() -join ', ')")
    }
    $tail = "$a of $n $noun available"
    if ($c -gt 0) { $tail += ", $o out, $c not checked" }
    $parts.Add($tail)
    return "$Prefix$($parts.ToArray() -join '; ')$Suffix"
}

# ----------------------------------------------------------------------------- parent thread (lineage)
#
# A thread belongs to one reviewer - reviewer.provider AND reviewer.model, compared field
# by field with ordinal equality (the display string 'lineage' = '<provider> :: <model>'
# is never compared) - on one endpoint (provider_fingerprint). Only a ledger entry written by 0.3.0 or later (it has a
# `reviewer`) whose identity was resolved (non-empty provider_fingerprint) and whose
# `thread` was verified (from the events, or a rollout that contains the consultation
# id) can be a parent - automatically (the newest of this run's lineage) or through
# -Thread. Entries recorded before 0.3.0 have UNKNOWN provenance: never a parent. A
# rollout candidate (thread_candidate) is diagnostic only: never a parent.

function Get-EntryFingerprint {
    param($Entry)
    $rev = Get-PropertyValue $Entry 'reviewer' $null
    if ($null -eq $rev) { return '' }
    return [string](Get-PropertyValue $rev 'provider_fingerprint' '')
}

# { Provider; Model; Engine; Display } of a 0.3.0+ entry's reviewer ($null for a legacy
# entry). Engine: reviewer.engine, 'codex' when absent (0.3.x entries).
function Get-EntryReviewer {
    param($Entry)
    $rev = Get-PropertyValue $Entry 'reviewer' $null
    if ($null -eq $rev) { return $null }
    $p = [string](Get-PropertyValue $rev 'provider' '')
    $m = [string](Get-PropertyValue $rev 'model' '')
    $e = [string](Get-PropertyValue $rev 'engine' '')
    if (-not $e) { $e = 'codex' }
    return [pscustomobject]@{ Provider = $p; Model = $m; Engine = $e; Display = (Format-ReviewerLineage -Provider $p -Model $m -Engine $e) }
}

# Same reviewer: provider and model equal, ordinal (case-sensitive), each on its own - and the
# same engine (an absent one is codex), so a codex thread and an agy thread of the same label
# and model never mix (their fingerprints differ as well).
function Test-SameReviewer {
    param($EntryReviewer, $Identity)
    $idEngine = [string]$Identity.Engine
    if (-not $idEngine) { $idEngine = 'codex' }
    $entryEngine = [string](Get-PropertyValue $EntryReviewer 'Engine' '')
    if (-not $entryEngine) { $entryEngine = 'codex' }
    return ($null -ne $EntryReviewer -and [string]::Equals($EntryReviewer.Provider, [string]$Identity.Provider, [StringComparison]::Ordinal) -and [string]::Equals($EntryReviewer.Model, [string]$Identity.Model, [StringComparison]::Ordinal) -and $entryEngine -eq $idEngine)
}

function Format-ShortHash {
    param([string]$Hash)
    if ($Hash.Length -ge 12) { return $Hash.Substring(0, 12) }
    return $Hash
}

# The ledger entry that recorded thread $Thread (the newest one) if it can be a parent at
# all: recorded by 0.3.0 or later (it has a `reviewer`) with a resolved identity (a
# provider_fingerprint). { Entry; N; Error }. Used by Select-ParentThread and by the roster
# rule "-Thread fixes the reviewer" (codex-consult.ps1). (wave 24) The conversation of an
# engine run the bridge KILLED on its timeout (an agy / muse entry with a `partial_reply`)
# counts too: its id - a candidate only, since no result verified it - came from that run's
# own event stream (agy's init, muse's session stream), and the salvage names it as the
# thread to resume; the resumed turn itself must come back on it (the adapter's rule). Only
# for -Thread: never an automatic parent. A codex candidate (a foreign rollout) never does.
function Find-ThreadEntry {
    param([object[]]$Consults, [string]$Thread)
    $r = [pscustomobject]@{ Entry = $null; N = $null; Error = '' }
    $entries = @($Consults | Where-Object { $null -ne $_ })
    $thread = ([string]$Thread).Trim()
    $match = $null
    for ($i = $entries.Count - 1; $i -ge 0; $i--) {
        if ([string](Get-PropertyValue $entries[$i] 'thread' '') -eq $thread) { $match = $entries[$i]; break }
    }
    if (-not $match -and $thread) {
        for ($i = $entries.Count - 1; $i -ge 0; $i--) {
            $e = $entries[$i]
            if ([string](Get-PropertyValue $e 'thread_candidate' '') -eq $thread -and [string](Get-PropertyValue $e 'partial_reply' '') -and (Get-EntryEngine $e) -ne 'codex') { $match = $e; break }
        }
    }
    if (-not $match) {
        $cand = $null
        for ($i = $entries.Count - 1; $i -ge 0; $i--) {
            if ([string](Get-PropertyValue $entries[$i] 'thread_candidate' '') -eq $thread) { $cand = $entries[$i]; break }
        }
        if ($cand) { $r.Error = "thread $thread has unknown provenance: it is only an unverified rollout candidate of consult n=$(Get-PropertyValue $cand 'n' '?') (that rollout did not contain the run's consultation id); use -Mode new" }
        else { $r.Error = "thread $thread has unknown provenance: it is not in this task's ledger; use -Mode new" }
        return $r
    }
    $n = Get-PropertyValue $match 'n' '?'
    if ($null -eq (Get-PropertyValue $match 'reviewer' $null)) {
        $r.Error = "thread $thread has unknown provenance (recorded before 0.3.0); use -Mode new"; return $r
    }
    if (-not (Get-EntryFingerprint $match)) {
        $r.Error = "thread $thread has unknown provenance: consult n=$n ran with an unresolved reviewer identity ($((Get-EntryReviewer $match).Display)); use -Mode new"; return $r
    }
    $r.Entry = $match
    $r.N = $n
    return $r
}

# { Mode; Parent; ParentN; Note; Error }. $Mode '' = automatic.
function Select-ParentThread {
    param([object[]]$Consults, $Identity, [string]$Mode, [string]$Thread)
    $r = [pscustomobject]@{ Mode = $Mode; Parent = ''; ParentN = $null; Note = ''; Error = '' }
    $entries = @($Consults | Where-Object { $null -ne $_ })
    $lineage = Format-ReviewerLineage -Provider $Identity.Provider -Model $Identity.Model -Engine ([string]$Identity.Engine)
    $unresolvedMsg = "provider identity could not be resolved ($($Identity.Note)); pass -Provider and -Model explicitly, or use -Mode new"
    $driftMsg = { param($t, $n, $fp) "endpoint or protocol of provider $($Identity.Provider) changed since thread $t (consult n=$n recorded provider fingerprint $(Format-ShortHash $fp), now $(Format-ShortHash $Identity.Fingerprint)); start a new thread with -Mode new" }
    $thread = ([string]$Thread).Trim()
    if ($thread) {
        if ($Mode -eq 'new') { $r.Error = '-Thread needs -Mode fork or resume (-Mode new always starts a fresh thread).'; return $r }
        if (-not $Identity.Resolved) { $r.Error = $unresolvedMsg; return $r }
        $found = Find-ThreadEntry -Consults $entries -Thread $thread
        if ($found.Error) { $r.Error = $found.Error; return $r }
        $match = $found.Entry
        $n = $found.N
        $fp = Get-EntryFingerprint $match
        $theirRev = Get-EntryReviewer $match
        $theirs = $theirRev.Display
        if (-not (Test-SameReviewer $theirRev $Identity)) {
            $r.Error = "thread $thread belongs to lineage $theirs (consult n=$n); this run is $lineage. A thread never changes provider or model: use -Mode new, or run as $theirs"; return $r
        }
        if ($fp -ne $Identity.Fingerprint) { $r.Error = (& $driftMsg $thread $n $fp); return $r }
        if (-not $r.Mode) { $r.Mode = 'fork' }
        $r.Parent = $thread
        $r.ParentN = $n
        $r.Note = "-Thread, lineage $lineage (consult n=$n)"
        return $r
    }
    if (-not $Identity.Resolved) {
        if ($Mode -eq 'fork' -or $Mode -eq 'resume') { $r.Error = $unresolvedMsg; return $r }
        $r.Mode = 'new'
        $r.Note = "reviewer identity unresolved, automatic fork/resume is off ($($Identity.Note))"
        return $r
    }
    $parent = $null
    $legacy = 0; $unresolved = 0; $candidates = 0
    $others = New-Object System.Collections.Generic.List[string]
    for ($i = $entries.Count - 1; $i -ge 0; $i--) {
        $c = $entries[$i]
        $t = [string](Get-PropertyValue $c 'thread' '')
        if (-not $t) {
            if ([string](Get-PropertyValue $c 'thread_candidate' '')) { $candidates++ }
            continue
        }
        if ($null -eq (Get-PropertyValue $c 'reviewer' $null)) { $legacy++; continue }
        if (-not (Get-EntryFingerprint $c)) { $unresolved++; continue }
        $cr = Get-EntryReviewer $c
        if (-not (Test-SameReviewer $cr $Identity)) { if (-not $others.Contains($cr.Display)) { $others.Add($cr.Display) }; continue }
        if (-not $parent) { $parent = $c }
    }
    if ($parent) {
        if ($Mode -eq 'new') { return $r }
        $pt = [string]$parent.thread
        $n = Get-PropertyValue $parent 'n' '?'
        $fp = Get-EntryFingerprint $parent
        if ($fp -ne $Identity.Fingerprint) { $r.Error = (& $driftMsg $pt $n $fp); return $r }
        if (-not $r.Mode) { $r.Mode = 'fork' }
        $r.Parent = $pt
        $r.ParentN = $n
        $r.Note = "newest thread of lineage $lineage (consult n=$n)"
        return $r
    }
    $why = New-Object System.Collections.Generic.List[string]
    if ($legacy -gt 0) { $why.Add("$legacy thread(s) recorded before 0.3.0 have unknown provenance and are never automatic parents") }
    if ($others.Count -gt 0) { $why.Add("other lineage(s): $($others -join ', ')") }
    if ($unresolved -gt 0) { $why.Add("$unresolved thread(s) of runs with an unresolved reviewer identity are never parents") }
    if ($candidates -gt 0) { $why.Add("$candidates unverified rollout candidate(s) are never parents") }
    $note = "no thread of lineage $lineage in this task's ledger"
    if ($why.Count -gt 0) { $note += '; ' + ($why.ToArray() -join '; ') }
    if ($Mode -eq 'fork' -or $Mode -eq 'resume') {
        $r.Error = "-Mode $Mode needs a parent thread: $note. Pass -Thread <uuid> of lineage $lineage, or use -Mode new"
        return $r
    }
    $r.Mode = 'new'
    if ($entries.Count -gt 0) { $r.Note = $note }
    return $r
}

# ----------------------------------------------------------------------------- task lock + pending record
#
# OWNERSHIP and RECOVERY METADATA are two different files:
#
#   <task>/.consult.lock          ownership. A PERMANENT file at a stable path: opened
#                                 with FileMode.OpenOrCreate and held open for the whole
#                                 critical section; release = close the handle, never
#                                 unlink (a contender that already opened the path must
#                                 never end up locking a different file than the next
#                                 one). The OS decides ownership: a holder that dies
#                                 loses it with its handle. Share mode:
#                                   * Windows: FileShare.Read - a refused contender can
#                                     read the holder's record for its message, nobody
#                                     else can open it for writing;
#                                   * elsewhere: FileShare.None, which .NET on Unix
#                                     emulates with an advisory flock(LOCK_EX) (any other
#                                     share mode maps to a shared lock that would not
#                                     exclude).
#                                 Cross-host exclusion (a task directory on a network
#                                 share used from two machines) is out of scope. The
#                                 content is informational only - { pid, start_time,
#                                 host, task, started } of the current holder, plus
#                                 `panel` (its id) while a -Panel run holds it - written
#                                 after the handle is held; overwriting it destroys
#                                 nothing recoverable. A -Panel run holds it for the
#                                 whole panel; its members never take it.
#
#   <task>/.consult.write.lock    (0.4.x wave 21) the COMMIT lock of the task's two stores,
#                                 same discipline (permanent file, held open, release =
#                                 close, a killed holder releases it), held only for one
#                                 commit and waited for (Enter-WriteLock: backoff up to
#                                 60 s). Every writer of findings.json / sessions.json -
#                                 a single run, a panel member, codex-findings.ps1 -Status
#                                 and -Rate - goes through Enter-StoreCommit: lock,
#                                 RE-READ both stores, apply its own delta, write, release.
#                                 No writer ever writes a store snapshot read before it.
#
#   <task>/.consult.pending.json  recovery metadata of the consultation in progress,
#   <task>/.consult.pending-<NN>.json  (one per -Panel member, NN = its handoff number;
#                                 written `reserved` by the panel run before any member
#                                 starts, then owned by the member) - replaced ATOMICALLY
#                                 (Write-TextAtomic):
#                                   { state, n, nn, reply, events, consult_id, started,
#                                     pid, start_time, host, launcher, engine, child_pid,
#                                     child_start_time, survivors, unverified, note [, reply_json,
#                                     raw_reply, original, first_reply, panel] }
#                                 state: reserved    numbers allocated, codex not started
#                                        launching   about to start codex (the child may
#                                                    or may not exist)
#                                        running     codex started as child_pid
#                                        survivors   a timeout kill left survivors[] alive
#                                        committing  the run is over; the bridge waits for
#                                                    or holds the write lock (kept when the
#                                                    write lock was never acquired: the
#                                                    reply files it names have no ledger
#                                                    entry)
#                                 pid + start_time: the bridge that wrote the record (a
#                                 panel member rewrites its record with its own before it
#                                 checks its parent); while THAT process runs the record is active
#                                 in every state. panel: { id, position, of, parent_pid,
#                                 parent_start_time } of a member record. survivors[]:
#                                   { pid, start_time, name } per process still alive
#                                   after the kill (start_time: UTC round-trip string
#                                   from Get-Process; name: its ProcessName). A recorded
#                                   process counts as alive only while its pid runs with
#                                   the SAME start time (and name, when recorded); an
#                                   entry without a start time (older records: a bare
#                                   pid) is judged by the evidence rule of the unverified
#                                   pids (Test-RecordedProcess; wave 28e, E19: fail-closed)
#                                   - never by pid alone.
#                                 unverified[] (wave 28e, E1): { pid, why } per descendant
#                                   whose start time could not be read at the kill (left
#                                   alone by it: neither a survivor nor gone). The next
#                                   run names them and checks them again
#                                   (Test-UnverifiedProcess): gone - dropped; still
#                                   unreadable - it blocks as a survivor (fail-closed);
#                                   readable - started before the run: dropped, else it
#                                   blocks only if it looks like codex.
#                                 It is deleted when the run completed cleanly (after the
#                                 ledger commit, under the write lock). A run that finds
#                                 records decides from ALL of them BEFORE writing anything
#                                 (Read-TaskPendingRecords, Test-PendingActive): a live
#                                 writer or codex process refuses the run; a dead one's
#                                 reservation is consumed (numbering skips past it) and
#                                 only then is the file replaced by the new run's record
#                                 (a member record: removed). An unparseable pending file
#                                 is corruption and refuses.

function New-LockRefusal {
    param([string]$Path, [string]$Message)
    return [pscustomobject]@{ Acquired = $false; Path = $Path; Stream = $null; Record = $null; Message = $Message }
}

# Content of a lock file without taking it (for messages): the parsed record, or
# $null when the file is absent, held exclusively, empty or unparseable. Outside
# Windows, every FileStream .NET opens takes an advisory flock (LOCK_SH for a shared
# open), which the holder's LOCK_EX refuses: there `cat` reads it (it takes no lock).
function Read-LockContent {
    param([string]$Path)
    if (-not [IO.File]::Exists($Path)) { return $null }
    $text = ''
    if ($script:OnWindows) {
        try {
            $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            try {
                $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $true)
                $text = $sr.ReadToEnd()
            } finally { $fs.Dispose() }
        } catch { return $null }
    } else {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $text = ((@(& cat -- $Path 2>$null)) -join "`n") } catch { $text = '' } finally { $ErrorActionPreference = $previous }
    }
    if (-not $text -or -not $text.Trim()) { return $null }
    $obj = $null
    try { $obj = ConvertFrom-Json -InputObject $text } catch { return $null }
    if (Test-IsJsonObject $obj) { return $obj }
    return $null
}

# Takes the task's ownership lock (see the section comment). Returns
# { Acquired; Path; Stream; Record; Message } - the caller refuses when not Acquired.
function Enter-TaskLock {
    param([string]$TaskDir, [string]$Task, [string]$Panel = '')
    $path = Join-Path $TaskDir '.consult.lock'
    $share = if ($script:OnWindows) { [IO.FileShare]::Read } else { [IO.FileShare]::None }
    $record = [pscustomobject]@{
        pid        = $PID
        start_time = (Get-ProcessStartIso -ProcessId $PID)
        host       = [Environment]::MachineName
        task       = $Task
        started    = (Get-IsoTimestamp)
    }
    if ($Panel) { $record | Add-Member -NotePropertyName 'panel' -NotePropertyValue $Panel }
    $fs = $null
    try {
        $fs = [IO.File]::Open($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, $share)
    } catch [System.IO.IOException] {
        # The holder may not have replaced its predecessor's informational record
        # yet: re-read briefly and name a pid only when that pid is alive.
        $holder = $null
        for ($attempt = 1; $attempt -le 8; $attempt++) {
            $candidate = Read-LockContent -Path $path
            $cpid = 0
            if ($candidate -and [int]::TryParse([string](Get-PropertyValue $candidate 'pid' ''), [ref]$cpid) -and
                (Test-PidAlive -ProcessId $cpid -StartTime (ConvertTo-JsonText (Get-PropertyValue $candidate 'start_time' '')))) { $holder = $candidate; break }
            Start-Sleep -Milliseconds 125
        }
        $who = 'a live process'
        if ($holder) {
            $who = "pid $(Get-PropertyValue $holder 'pid' '?') on $(Get-PropertyValue $holder 'host' '?') since $(Get-PropertyValue $holder 'started' '?')"
            $holderPanel = [string](Get-PropertyValue $holder 'panel' '')
            if ($holderPanel) { $who += " (review panel $($holderPanel.Substring(0, [Math]::Min(8, $holderPanel.Length))))" }
        }
        return (New-LockRefusal -Path $path -Message "another consultation or status update for task '$Task' is running: $path is held open by $who. Wait for it to finish; the lock is released when that process exits.")
    } catch {
        return (New-LockRefusal -Path $path -Message "could not open the lock '$path': $($_.Exception.Message)")
    }
    # Informational only (who holds it); nothing recoverable lives here.
    try {
        $bytes = $script:Utf8NoBom.GetBytes((ConvertTo-Json -InputObject $record -Compress) + "`n")
        $fs.SetLength(0)
        $fs.Position = 0
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.Flush($true)
    } catch { }
    return [pscustomobject]@{ Acquired = $true; Path = $path; Stream = $fs; Record = $record; Message = '' }
}

# Releases the ownership lock: close the handle, nothing else (the file stays).
function Exit-TaskLock {
    param($Lock)
    if ($null -eq $Lock -or -not $Lock.Acquired -or $null -eq $Lock.Stream) { return }
    $Lock.Acquired = $false
    try { $Lock.Stream.Dispose() } catch { }
}

# How long a commit waits for the write lock before it gives up (D3): 60 s.
# TEST HOOK: CODEX_CONSULT_TEST_WRITE_LOCK_SEC=<s> shortens it.
function Get-WriteLockTimeout {
    $v = 0.0
    if ([double]::TryParse((Get-TestHookValue 'CODEX_CONSULT_TEST_WRITE_LOCK_SEC'), [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$v) -and $v -gt 0) { return $v }
    return 60.0
}

# Takes <task>/.consult.write.lock (see the section comment): opened like .consult.lock and
# retried with backoff (50 ms, doubling up to 1 s) while another process holds it, until
# $TimeoutSec. { Acquired; Path; Stream; Record; Message; Waited (seconds); WaitedMs (whole
# milliseconds, 0 when the lock was free at once) }; release with Exit-TaskLock (close the
# handle; the file stays).
function Enter-WriteLock {
    param([string]$TaskDir, [string]$Task, [double]$TimeoutSec = 60)
    $path = Join-Path $TaskDir '.consult.write.lock'
    $share = if ($script:OnWindows) { [IO.FileShare]::Read } else { [IO.FileShare]::None }
    $record = [pscustomobject]@{
        pid        = $PID
        start_time = (Get-ProcessStartIso -ProcessId $PID)
        host       = [Environment]::MachineName
        task       = $Task
        started    = (Get-IsoTimestamp)
    }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $delay = 50
    $fs = $null
    while ($null -eq $fs) {
        try {
            $fs = [IO.File]::Open($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, $share)
        } catch [System.IO.DirectoryNotFoundException] {
            $r = New-LockRefusal -Path $path -Message "could not open the write lock '$path': $($_.Exception.Message)"
            $r | Add-Member -NotePropertyName 'Waited' -NotePropertyValue ([math]::Round($watch.Elapsed.TotalSeconds, 1))
            $r | Add-Member -NotePropertyName 'WaitedMs' -NotePropertyValue ([int]$watch.ElapsedMilliseconds)
            return $r
        } catch [System.IO.IOException] {
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSec) {
                $who = 'a live process'
                $holder = Read-LockContent -Path $path
                $hpid = 0
                if ($holder -and [int]::TryParse([string](Get-PropertyValue $holder 'pid' ''), [ref]$hpid) -and
                    (Test-PidAlive -ProcessId $hpid -StartTime (ConvertTo-JsonText (Get-PropertyValue $holder 'start_time' '')))) {
                    $who = "pid $hpid on $(Get-PropertyValue $holder 'host' '?') since $(Get-PropertyValue $holder 'started' '?')"
                }
                $r = New-LockRefusal -Path $path -Message "the write lock '$path' of task '$Task' was not acquired within $TimeoutSec s: it is held open by $who"
                $r | Add-Member -NotePropertyName 'Waited' -NotePropertyValue ([math]::Round($watch.Elapsed.TotalSeconds, 1))
                $r | Add-Member -NotePropertyName 'WaitedMs' -NotePropertyValue ([int]$watch.ElapsedMilliseconds)
                return $r
            }
            Start-Sleep -Milliseconds $delay
            $delay = [Math]::Min($delay * 2, 1000)
        } catch {
            $r = New-LockRefusal -Path $path -Message "could not open the write lock '$path': $($_.Exception.Message)"
            $r | Add-Member -NotePropertyName 'Waited' -NotePropertyValue ([math]::Round($watch.Elapsed.TotalSeconds, 1))
            $r | Add-Member -NotePropertyName 'WaitedMs' -NotePropertyValue ([int]$watch.ElapsedMilliseconds)
            return $r
        }
    }
    # the first attempt succeeded: no wait at all (not the few microseconds of the open)
    $waitedMs = $(if ($delay -eq 50) { 0 } else { [int]$watch.ElapsedMilliseconds })
    # Informational only (who holds it); nothing recoverable lives here.
    try {
        $bytes = $script:Utf8NoBom.GetBytes((ConvertTo-Json -InputObject $record -Compress) + "`n")
        $fs.SetLength(0)
        $fs.Position = 0
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.Flush($true)
    } catch { }
    return [pscustomobject]@{ Acquired = $true; Path = $path; Stream = $fs; Record = $record; Message = ''; Waited = [math]::Round($watch.Elapsed.TotalSeconds, 1); WaitedMs = $waitedMs }
}

# THE way every writer changes a task's stores (D2, F04-3): codex-consult.ps1 (a single run,
# a panel member) and codex-findings.ps1 (-Status, -Rate). Takes the write lock, then
# RE-READS findings.json and sessions.json; the caller applies ITS OWN delta to these fresh
# objects, writes them with Complete-StoreCommit (findings.json, then sessions.json) and
# releases with Exit-StoreCommit in a finally. A store that no longer parses refuses
# (Read-JsonStore; the lock is released on the way out). Not acquired within $TimeoutSec:
# Acquired $false and the Message - the caller gives up WITHOUT touching the stores (D3).
# { Acquired; Message; Waited; WaitedMs; Lock; FindingsPath; SessionsPath; Findings (the fresh
# store, a new one when absent); Sessions (the fresh ledger object, $null when absent) }.
function Enter-StoreCommit {
    param([string]$TaskDir, [string]$Task, [double]$TimeoutSec = 60, [switch]$NoSessions)
    $lock = Enter-WriteLock -TaskDir $TaskDir -Task $Task -TimeoutSec $TimeoutSec
    $c = [pscustomobject]@{
        Acquired     = [bool]$lock.Acquired
        Message      = [string]$lock.Message
        Waited       = $lock.Waited
        WaitedMs     = [int](Get-PropertyValue $lock 'WaitedMs' 0)
        Lock         = $lock
        FindingsPath = (Join-Path $TaskDir 'findings.json')
        SessionsPath = (Join-Path $TaskDir 'sessions.json')
        Findings     = $null
        Sessions     = $null
    }
    if (-not $c.Acquired) { return $c }
    $read = $false
    try {
        $c.Findings = Read-FindingsFile -Path $c.FindingsPath -Task $Task
        if (-not $NoSessions) { $c.Sessions = Read-JsonStore -Path $c.SessionsPath }
        $read = $true
    } finally {
        if (-not $read) { Exit-TaskLock -Lock $lock; $c.Acquired = $false }
    }
    return $c
}

# Writes the commit's fresh stores in the documented order: findings.json, then
# sessions.json (the commit point). Only while the write lock is held.
function Complete-StoreCommit {
    param($Commit, [switch]$Findings, [switch]$Sessions)
    if ($null -eq $Commit -or -not $Commit.Acquired -or -not $Commit.Lock.Acquired) { throw 'Complete-StoreCommit: the write lock is not held' }
    if ($Findings) { Write-FindingsFile -Path $Commit.FindingsPath -Store $Commit.Findings }
    if ($Sessions) { Write-JsonFile -Path $Commit.SessionsPath -Object $Commit.Sessions }
}

# Releases the write lock of a commit (idempotent; $null is fine).
function Exit-StoreCommit {
    param($Commit)
    if ($null -eq $Commit) { return }
    Exit-TaskLock -Lock $Commit.Lock
    $Commit.Acquired = $false
}

# Inserts $Entry into the ledger object's codex.consults at its place by n (D10): the array
# stays sorted by n whatever order a panel's members commit in - an entry lands after every
# entry whose n is not greater than its own, so a single run (the highest n) is appended as
# before. Select-ParentThread's "newest thread of a lineage" is therefore the highest n.
function Add-LedgerEntry {
    param($Sessions, $Entry)
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($c in @($Sessions.codex.consults | Where-Object { $null -ne $_ })) { $list.Add($c) }
    $mine = 0
    [void][int]::TryParse([string](Get-PropertyValue $Entry 'n' ''), [ref]$mine)
    $at = $list.Count
    for ($i = $list.Count - 1; $i -ge 0; $i--) {
        $v = 0
        if ([int]::TryParse([string](Get-PropertyValue $list[$i] 'n' ''), [ref]$v) -and $v -gt $mine) { $at = $i } else { break }
    }
    $list.Insert($at, $Entry)
    $Sessions.codex.consults = [object[]]$list.ToArray()
}

$script:PendingStates = @('reserved', 'launching', 'running', 'survivors', 'committing')

function Get-PendingPath {
    param([string]$TaskDir)
    return (Join-Path $TaskDir '.consult.pending.json')
}

# The recovery record of a -Panel member: <task>/.consult.pending-<NN>.json.
function Get-MemberPendingPath {
    param([string]$TaskDir, [string]$Nn)
    return (Join-Path $TaskDir ".consult.pending-$Nn.json")
}

# Every recovery record file of a task: .consult.pending.json first, then the panel members'
# .consult.pending-<...>.json by name. (Their atomic-write temps ..consult.pending*.tmp are
# not records.)
function Get-PendingPaths {
    param([string]$TaskDir)
    $single = New-Object System.Collections.Generic.List[string]
    $members = New-Object System.Collections.Generic.List[string]
    if ($TaskDir -and [IO.Directory]::Exists($TaskDir)) {
        foreach ($f in [IO.Directory]::GetFiles($TaskDir)) {
            $name = [IO.Path]::GetFileName($f)
            if ($name -ieq '.consult.pending.json') { $single.Add($f) }
            elseif ($name -match '^\.consult\.pending-[^\\/]+\.json$') { $members.Add($f) }
        }
    }
    $sorted = [string[]]$members.ToArray()
    [Array]::Sort($sorted, [StringComparer]::OrdinalIgnoreCase)
    return , ([string[]]($single.ToArray() + $sorted))
}

# Every recovery record of a task (Get-PendingPaths), read and judged (Test-PendingActive):
# { Items (object[] of { Path; Name; Record; Check }); Active (the first active item, or
# $null); Error ('' or the refusal for the first unusable record - corruption refuses) }.
function Read-TaskPendingRecords {
    param([string]$TaskDir)
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($p in (Get-PendingPaths -TaskDir $TaskDir)) {
        $rd = Read-PendingFile -Path $p
        if ($rd.Error) { return [pscustomobject]@{ Items = [object[]]$items.ToArray(); Active = $null; Error = $rd.Error } }
        if (-not $rd.Exists) { continue }
        $chk = Test-PendingActive -Record $rd.Record -Path $p
        $items.Add([pscustomobject]@{ Path = $p; Name = [IO.Path]::GetFileName($p); Record = $rd.Record; Check = $chk })
    }
    $active = @($items | Where-Object { $_.Check.Active }) | Select-Object -First 1
    return [pscustomobject]@{ Items = [object[]]$items.ToArray(); Active = $active; Error = '' }
}

# { Exists; Record; Error }. Absent -> Exists $false. Present but empty, unparseable,
# not an object, or with an unknown state -> Error (corruption: the caller refuses).
function Read-PendingFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Exists = $false; Record = $null; Error = '' } }
    $text = Read-SharedText -Path $Path
    $obj = $null
    $why = ''
    if (-not $text.Trim()) { $why = 'it is empty or could not be read' }
    else {
        try { $obj = ConvertFrom-Json -InputObject $text } catch { $why = "it does not parse: $(ConvertTo-OneLine $_.Exception.Message)" }
        if (-not $why -and -not (Test-IsJsonObject $obj)) { $why = 'it is not a JSON object' }
        if (-not $why -and $script:PendingStates -notcontains [string](Get-PropertyValue $obj 'state' '')) { $why = "its state '$(Get-PropertyValue $obj 'state' '')' is not one of $($script:PendingStates -join '|')" }
    }
    if ($why) {
        return [pscustomobject]@{ Exists = $true; Record = $null; Error = "the recovery record '$Path' is unusable: $why. It describes an interrupted consultation - inspect it (and any codex process it may name), then repair or delete it deliberately." }
    }
    return [pscustomobject]@{ Exists = $true; Record = $obj; Error = '' }
}

# consult_id (0.3.0): the run's consultation id - the last line of its prompt - so an
# interrupted run's rollout file can be identified later. Informational only.
# engine (0.4.0): the CLI of the run (codex | agy | muse; absent in older records = codex), so the
# messages name the right process. events (0.4.0): the raw event stream of the turn that
# runs (repo-relative when inside the repository), set when its process is registered:
# for agy it holds the reply itself, so a run that stops before its ledger entry leaves it
# named here (Get-PendingOriginalNote).
# start_time (0.4.x wave 21, D1): the start time of the bridge that writes the record (pid),
# so the record is judged active while that very process runs. panel: the member's panel
# record { id, position, of, parent_pid, parent_start_time } ($null: not a panel member).
function New-PendingRecord {
    param([string]$State, $N, [string]$Nn, [string]$Reply, [string]$Started, [string]$Launcher = '', [string]$ConsultId = '', [string]$Engine = 'codex', $Panel = $null)
    $r = [pscustomobject]@{
        state            = $State
        n                = $N
        nn               = $Nn
        reply            = $Reply
        events           = ''
        consult_id       = $ConsultId
        started          = $Started
        pid              = $PID
        start_time       = [string](Get-ProcessStartIso -ProcessId $PID)
        host             = [Environment]::MachineName
        launcher         = $Launcher
        engine           = $Engine
        child_pid        = $null
        child_start_time = ''
        survivors        = [object[]]@()
        unverified       = [object[]]@()
        note             = ''
    }
    if ($null -ne $Panel) { $r | Add-Member -NotePropertyName 'panel' -NotePropertyValue $Panel }
    return $r
}

# Atomic replace (temp + replace); throws on failure - callers decide what a failed
# write means at their point in the sequence.
function Write-PendingFile {
    param([string]$Path, $Record)
    Write-JsonFile -Path $Path -Object $Record
}

# '' when deleted (or already absent), else the error text.
function Remove-PendingFile {
    param([string]$Path)
    $err = ''
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            if ([IO.File]::Exists($Path)) { [IO.File]::Delete($Path) }
            return ''
        } catch {
            $err = ConvertTo-OneLine $_.Exception.Message
            Start-Sleep -Milliseconds 250
        }
    }
    return $err
}

# The "looks like codex" rule: '' or the reason - name codex / codex.exe (the native
# binary), the file name of the recorded launcher when that is a binary (0.4.0: agy.exe
# for the agy engine, found by name AND by the recorded launcher path), or a command line
# containing the recorded launcher path (the codex.cmd shim, -CodexExe, -EngineExe) or
# @openai/codex (node running the npm package). It cannot tell WHICH task's consultation
# a process belongs to.
function Get-CodexRule {
    param([string]$Name, [string]$Cmd, [string]$Launcher = '')
    if ($Name -match '^codex(\.exe)?$') { return 'name codex' }
    if ($Launcher -and $Name) {
        $ext = [IO.Path]::GetExtension($Launcher)
        $base = [IO.Path]::GetFileNameWithoutExtension($Launcher)
        $nameBase = $Name -replace '(?i)\.exe$', ''
        if ($base -and ($ext -eq '' -or $ext -ieq '.exe') -and $nameBase.Equals($base, [StringComparison]::OrdinalIgnoreCase)) { return "name $base (the recorded launcher)" }
    }
    if ($Launcher -and $Cmd -and $Cmd.IndexOf($Launcher, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return 'launcher in command line' }
    if ($Cmd -match '@openai[\\/]codex') { return '@openai/codex in command line' }
    return ''
}

# One process: { pid; name (ProcessName); cmd; start (UTC round-trip, '' when it cannot
# be read); (wave 28e, E19) ppid (its parent's pid, 0 when it cannot be read) }, or $null when no
# process has that pid. A command line that cannot be read (access denied - another user's or an
# elevated process) is ''. (wave 28e, E19) TEST HOOK (test mode only):
# CODEX_CONSULT_TEST_CMDLINE_UNREADABLE=<pid>[,<pid>] - these pids read with the command line ''
# (as access denied makes it).
function Get-ProcessInfo {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return $null }
    $p = $null
    try { $p = Get-Process -Id $ProcessId -ErrorAction Stop } catch { return $null }
    $start = ''
    try { $start = $p.StartTime.ToUniversalTime().ToString('o', $script:Invariant) } catch { $start = '' }
    $cmd = ''
    $ppid = 0
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($script:OnWindows) {
            try {
                $w = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$ProcessId" -Property CommandLine, ParentProcessId -ErrorAction Stop
                if ($w) { $cmd = [string]@($w)[0].CommandLine; [void][int]::TryParse([string]@($w)[0].ParentProcessId, [ref]$ppid) }
            } catch { $cmd = '' }
        } else {
            try { $cmd = ((@(& ps -o 'args=' -p $ProcessId 2>$null)) -join ' ').Trim() } catch { $cmd = '' }
            try { [void][int]::TryParse(((@(& ps -o 'ppid=' -p $ProcessId 2>$null)) -join ' ').Trim(), [ref]$ppid) } catch { $ppid = 0 }
        }
    } finally { $ErrorActionPreference = $previous }
    $hook = Get-TestHookValue 'CODEX_CONSULT_TEST_CMDLINE_UNREADABLE'
    if ($hook -and (@($hook.Split(',') | ForEach-Object { $_.Trim() }) -contains [string]$ProcessId)) { $cmd = '' }
    return [pscustomobject]@{ pid = $ProcessId; name = [string]$p.ProcessName; cmd = $cmd; start = $start; ppid = $ppid }
}

# (wave 28e, E19 / F27-2) The generic runtimes a reviewer may run under (the codex npm shim is cmd ->
# node -> codex): such a process tells what it runs only through the arguments on its command line.
$script:GenericRuntimeNames = @('node', 'nodejs', 'bun', 'deno', 'cmd', 'powershell', 'pwsh', 'sh', 'bash', 'dash', 'zsh', 'python', 'python3')
# (wave 28e, E19 / F27-2) Whether a command line read for a process says what it runs: '' when it does;
# 'unreadable' when it could not be read ('' - access denied - or ps's "[name]" for a process whose
# arguments it cannot see); 'no arguments' when the process is a generic runtime
# ($script:GenericRuntimeNames) and its command line holds nothing beyond the executable. Pure.
function Get-CommandLineGap {
    param([string]$Name, [string]$Cmd)
    $c = ([string]$Cmd).Trim()
    if (-not $c -or $c -match '^\[[^\]]*\]$') { return 'unreadable' }
    $base = ([string]$Name -replace '(?i)\.exe$', '').ToLowerInvariant()
    if ($script:GenericRuntimeNames -contains $base) {
        $rest = ''
        if ($c.StartsWith('"')) {
            $close = $c.IndexOf('"', 1)
            $rest = $(if ($close -ge 0) { $c.Substring($close + 1) } else { '' })
        } else {
            $sp = $c.IndexOfAny([char[]]@(' ', "`t"))
            $rest = $(if ($sp -ge 0) { $c.Substring($sp) } else { '' })
        }
        if (-not $rest.Trim()) { return 'no arguments' }
    }
    return ''
}

# Survivor entries { pid, start_time, name } for the given pids (a pid that is already
# gone is left out).
function New-SurvivorEntries {
    param([int[]]$Pids)
    foreach ($id in @($Pids)) {
        $info = Get-ProcessInfo -ProcessId $id
        if ($info) { [pscustomobject]@{ pid = $id; start_time = $info.start; name = $info.name } }
    }
}

# (wave 28e, E1 / F54-1) The recovery record's unverified[] of a tree kill: { pid, why } per descendant
# whose start time could not be read (the kill check's Unverified and its Why) - the kill left it alone,
# it is neither a survivor nor gone; the next run checks it again (Test-UnverifiedProcess).
function New-UnverifiedEntries {
    param($Check)
    $why = [string](Get-PropertyValue $Check 'Why' '')
    foreach ($u in @(Get-PropertyValue $Check 'Unverified' @())) {
        $id = 0
        if ([int]::TryParse([string]$u, [ref]$id) -and $id -gt 0) { [pscustomobject]@{ pid = $id; why = $why } }
    }
}

# (wave 28e, E23 / F30-1) A tree kill that was NOT confirmed and names no pid - neither a survivor nor a
# descendant it could not verify (the children could not be enumerated and the tree-kill fallback failed,
# or the root did not exit): its why, '' for any other kill. The recovery record then keeps the UNKNOWN
# tree (`kill_unconfirmed`: that why) and the next run scans for it (Test-PendingActive).
function Get-KillUnconfirmedWhy {
    param($Check, [int[]]$Survivors = @())
    if (-not $Check -or $Check.Confirmed) { return '' }
    if (@($Survivors).Count -gt 0 -or @(Get-PropertyValue $Check 'Survivors' @()).Count -gt 0 -or @(Get-PropertyValue $Check 'Unverified' @()).Count -gt 0) { return '' }
    $w = [string](Get-PropertyValue $Check 'Why' '')
    if (-not $w) { $w = 'the kill was not confirmed' }
    return $w
}

# (wave 28e, E1 / F54-1) A pid of the record's unverified[] - a descendant whose start time could not be
# read at the kill, so no start time was recorded - checked again: { Alive; How }.
#   gone (no process with that pid): not alive - dropped;
#   its start time STILL cannot be read: ALIVE - fail-closed, it blocks the task as a survivor does
#     until it exits (or the operator deletes the record knowing it is unrelated);
#   readable now: a process that started before that run ($Since, the record's `started`) cannot be
#     one of its descendants - not alive; else the "looks like codex" rule (Get-CodexRule) decides, as
#     for a survivor recorded without a start time - never by pid alone.
# (wave 28e, E19 / F27-2) FAIL-CLOSED on the evidence: a process that started after that run is dropped
# only when it is PROVEN unrelated - its command line was read (Get-CommandLineGap ''), the rule does
# not match it AND its parent is none of the record's pids ($RecordedPids: the writer, the child, the
# survivors, the other unverified pids). A command line that cannot be read (access denied; a generic
# runtime such as node or powershell with no arguments on it) counts as RUNNING ("command line not
# readable - counted as running (fail-closed)"), and so does a child of a recorded pid. Only "gone",
# "started before that run" or "command line read and not codex-like" release it. The same rule
# re-checks a survivor recorded without a start time, or whose start time cannot be read now
# (Test-RecordedProcess).
function Test-UnverifiedProcess {
    param([int]$ProcessId, $Since = $null, [string]$Launcher = '', [int[]]$RecordedPids = @())
    $st = Get-ProcessStartIso -ProcessId $ProcessId
    if ($null -eq $st) { return [pscustomobject]@{ Alive = $false; How = 'gone' } }
    if (-not $st) { return [pscustomobject]@{ Alive = $true; How = 'its start time still cannot be read - counted as running (fail-closed)' } }
    if ($null -ne $Since) {
        $at = [DateTimeOffset]::MinValue
        if ([DateTimeOffset]::TryParse($st, $script:Invariant, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$at) -and $at -lt $Since) {
            return [pscustomobject]@{ Alive = $false; How = "started $st, before that run: not its process" }
        }
    }
    $info = Get-ProcessInfo -ProcessId $ProcessId
    if (-not $info) { return [pscustomobject]@{ Alive = $false; How = 'gone' } }
    $rule = Get-CodexRule -Name $info.name -Cmd $info.cmd -Launcher $Launcher
    if ($rule) { return [pscustomobject]@{ Alive = $true; How = "start time readable now; $rule" } }
    $gap = Get-CommandLineGap -Name $info.name -Cmd $info.cmd
    if ($gap) { return [pscustomobject]@{ Alive = $true; How = "start time readable now; pid $ProcessId runs $($info.name)$(if ($gap -eq 'no arguments') { ' (a generic runtime, no arguments on its command line)' }); command line not readable - counted as running (fail-closed)" } }
    $ppid = [int](Get-PropertyValue $info 'ppid' 0)
    if ($ppid -gt 0 -and $ppid -ne $ProcessId -and @($RecordedPids) -contains $ppid) { return [pscustomobject]@{ Alive = $true; How = "start time readable now; pid $ProcessId runs $($info.name), a child of the recorded pid $ppid - counted as running" } }
    return [pscustomobject]@{ Alive = $false; How = "start time readable now; pid $ProcessId runs $($info.name), not codex" }
}

# Is a process recorded in a pending record still that process? Returns { Alive; How }.
#   with a recorded start time that can be read now too: alive only when the pid runs with that
#     start time (and that name, when one is recorded) - a different start time means the pid was
#     reused by an unrelated process;
#   without one (older records: a bare pid), or when the live start time cannot be read: (wave 28e,
#     E19 / F27-2) the SAME fail-closed evidence rule and messages as an unverified pid
#     (Test-UnverifiedProcess): gone - not alive; its start time unreadable - counted as running;
#     started before that run ($Since) - not alive; looks like codex (Get-CodexRule) - alive; its
#     command line unreadable (a generic runtime with no arguments too) - counted as running; a child
#     of a recorded pid ($RecordedPids) - counted as running; only a command line read and not
#     codex-like drops it. Never by pid alone (before E19: alive only when it looked like codex).
function Test-RecordedProcess {
    param([int]$ProcessId, [string]$StartTime = '', [string]$Name = '', [string]$Launcher = '', $Since = $null, [int[]]$RecordedPids = @())
    $info = Get-ProcessInfo -ProcessId $ProcessId
    if (-not $info) { return [pscustomobject]@{ Alive = $false; How = 'gone' } }
    if ($StartTime -and $info.start) {
        if (-not (Test-SameStartTime -A $info.start -B $StartTime)) { return [pscustomobject]@{ Alive = $false; How = 'pid reused (start time differs)' } }
        if ($Name -and -not $info.name.Equals($Name, [StringComparison]::OrdinalIgnoreCase)) { return [pscustomobject]@{ Alive = $false; How = "pid reused (now $($info.name))" } }
        return [pscustomobject]@{ Alive = $true; How = 'pid + start time' }
    }
    return (Test-UnverifiedProcess -ProcessId $ProcessId -Since $Since -Launcher $Launcher -RecordedPids $RecordedPids)
}

# Best-effort scan for the codex process an interrupted 'launching' run may have left,
# started at or after $Since, excluding this process and its ancestors.
#   Windows, with the interrupted bridge's pid ($BridgePid): a process counts when its
#     ParentProcessId is that pid (any name) - Windows keeps the parent id of an orphan,
#     so this attributes the process to THIS task's run. If a live process now owns
#     that pid (reused), only children created before it started count.
#   otherwise (no bridge pid recorded, or not Windows, where orphans are reparented):
#     the "looks like codex" rule (Get-CodexRule), which cannot tell which task a
#     process belongs to - such matches are labelled "task not verifiable".
# Returns { Found = [object[]] { pid; name; rule }; Check = <what was scanned>; Failed }.
function Find-CodexProcesses {
    param([datetime]$Since, [string]$Launcher = '', [int]$BridgePid = 0)
    $found = New-Object System.Collections.Generic.List[object]
    $sinceText = $Since.ToString('yyyy-MM-ddTHH:mm:ss', $script:Invariant)
    $byParent = ($script:OnWindows -and $BridgePid -gt 0)
    $rules = if ($byParent) { "children of the interrupted bridge pid $BridgePid" } else { 'name codex*, or a command line containing the recorded launcher or @openai/codex' }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $procs = New-Object System.Collections.Generic.List[object]
        if ($script:OnWindows) {
            $check = "Win32_Process scan ($rules; started at or after $sinceText)"
            $all = $null
            try { $all = @(Get-CimInstance -ClassName Win32_Process -Property ProcessId, ParentProcessId, Name, CommandLine, CreationDate -ErrorAction Stop) } catch {
                return [pscustomobject]@{ Found = [object[]]@(); Check = "$check could not run: $(ConvertTo-OneLine $_.Exception.Message)"; Failed = $true }
            }
            foreach ($p in $all) {
                $procs.Add([pscustomobject]@{ pid = [int]$p.ProcessId; ppid = [int]$p.ParentProcessId; name = [string]$p.Name; cmd = [string]$p.CommandLine; created = $p.CreationDate })
            }
        } else {
            $check = "ps scan ($rules; started at or after $sinceText)"
            $lines = $null
            try { $lines = @(& ps -eo 'pid=,ppid=,etimes=,comm=,args=' 2>$null) } catch { $lines = $null }
            if ($LASTEXITCODE -ne 0 -or $null -eq $lines) {
                return [pscustomobject]@{ Found = [object[]]@(); Check = "$check could not run"; Failed = $true }
            }
            $now = Get-Date
            foreach ($l in $lines) {
                $m = [regex]::Match([string]$l, '^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s*(.*)$')
                if (-not $m.Success) { continue }
                $procs.Add([pscustomobject]@{ pid = [int]$m.Groups[1].Value; ppid = [int]$m.Groups[2].Value; name = $m.Groups[4].Value; cmd = $m.Groups[5].Value; created = $now.AddSeconds( - [double]$m.Groups[3].Value) })
            }
        }
        # never count ourselves or our ancestors (the shell that started this run may
        # carry the launcher path on its command line)
        $byId = @{}
        foreach ($p in $procs) { $byId[$p.pid] = $p }
        $excluded = @{}
        $cur = $PID
        for ($guard = 0; $guard -lt 64 -and $cur -gt 0 -and -not $excluded.ContainsKey($cur); $guard++) {
            $excluded[$cur] = $true
            if (-not $byId.ContainsKey($cur)) { break }
            $cur = $byId[$cur].ppid
        }
        if ($byParent) {
            # A live process holding the bridge's pid now is a reuse (the bridge itself
            # is gone - we hold the lock); its children are not ours, ours predate it.
            $reusedAt = $null
            if ($byId.ContainsKey($BridgePid)) { $reusedAt = $byId[$BridgePid].created }
            foreach ($p in $procs) {
                if ($excluded.ContainsKey($p.pid) -or $p.ppid -ne $BridgePid) { continue }
                if ($null -eq $p.created -or $p.created -lt $Since) { continue }
                if ($null -ne $reusedAt -and $p.created -ge $reusedAt) { continue }
                $found.Add([pscustomobject]@{ pid = $p.pid; name = $p.name; rule = "child of the interrupted bridge (ppid $BridgePid)" })
            }
        } else {
            foreach ($p in $procs) {
                if ($excluded.ContainsKey($p.pid)) { continue }
                if ($null -eq $p.created -or $p.created -lt $Since) { continue }
                $rule = Get-CodexRule -Name $p.name -Cmd $p.cmd -Launcher $Launcher
                if ($rule) { $found.Add([pscustomobject]@{ pid = $p.pid; name = $p.name; rule = "$rule, task not verifiable" }) }
            }
        }
        return [pscustomobject]@{ Found = [object[]]$found.ToArray(); Check = $check; Failed = $false }
    } finally {
        $ErrorActionPreference = $previous
    }
}

# A reservation whose run was stopped during its format-repair turn names the prose reply
# it had already saved (`original`, set when the repair turn starts): every message that
# reports or consumes such a record says so. '' when the record has no `original`.
# 0.4.0: a record that names its turn's raw event stream (`events`) says so too - for the agy
# engine that stream holds the reply itself (A18).
# 0.4.x wave 21 (D3, D4): a run names its reply in the record when it starts its commit
# (`reply_json`, or `raw_reply` for a raw codex run), so a commit that never completes - the
# write lock never acquired, or the bridge stopped inside it - leaves the record in state
# committing, naming the kept reply.
function Get-PendingOriginalNote {
    param($Record)
    $o = [string](Get-PropertyValue $Record 'original' '')
    $ev = [string](Get-PropertyValue $Record 'events' '')
    $rj = [string](Get-PropertyValue $Record 'reply_json' '')
    $rr = [string](Get-PropertyValue $Record 'raw_reply' '')
    $parts = New-Object System.Collections.Generic.List[string]
    if ($rj) { $parts.Add("the reply of that run is kept at $rj (its commit did not complete); no ledger entry was written for it") }
    if ($rr) { $parts.Add("the raw last message of that run is kept at $rr") }
    if ($o) { $parts.Add("a usable prose reply of that run exists at $o; no ledger entry was written for it") }
    if ($ev) {
        if ($o -or $rj) { $parts.Add("the raw event stream of that run is at $ev (it may hold a usable reply)") }
        else { $parts.Add("the raw event stream of that run is at $ev (it may hold a usable reply); no ledger entry was written") }
    }
    return ($parts.ToArray() -join '; ')
}

# Decides whether a pending record (from Read-PendingFile) still belongs to a live
# consultation. Returns { Active; Message; Check }. The rules, in this order:
#   1. THE WRITER (0.4.x wave 21, D1) decides first: a record that names the bridge that
#      wrote it (pid + start_time) is ACTIVE while that process runs on this host - in EVERY
#      state, `reserved` included (a panel member building its prompt, running its reviewer,
#      committing; a panel run whose members have not started yet). Never by pid alone (a
#      record without start_time - older bridges - skips this rule), never this very
#      process, not across hosts.
#   2. When the writer is gone or unknown, the state decides:
#      reserved            inactive: nothing was started under it;
#      running / survivors / committing
#                          active while child_pid (with its start time) or any survivor pid
#                          is alive on this host - (wave 28e, E1) or an unverified pid
#                          (Test-UnverifiedProcess: its start time still unreadable, or
#                          readable and codex-like - (E19) or its command line unreadable,
#                          or a child of a recorded pid); every one of them is named; pids from
#                          another host: active (they cannot be checked from here); all
#                          recorded pids gone: the process scan below (a dead launcher is
#                          no proof of a dead tree);
#      launching           the child may or may not exist: the process scan below; from
#                          another host (no pids to check): treated as dead.
#      (wave 28e, E23 / F30-1) a record with kill_unconfirmed (a kill that was not confirmed
#                          and named no pid): its tree is unknown - released only by a clean
#                          scan by parent pid (the writer, the child, the other recorded pids)
#                          AND the machine-wide rule - (E25 / F32-1) a panel member's record
#                          too (a live sibling's reviewer postpones its release); a failed
#                          scan, a find, a host outside Windows or another host: active.
#   3. The process scan: children of the recorded writer and of the recorded pids (Windows
#      keeps an orphan's parent id), then - for a record OUTSIDE a panel only - the
#      machine-wide "looks like codex" rule (Find-CodexProcesses; "task not verifiable").
#      A panel member's record (`panel`) NEVER uses that name rule: a live sibling member's
#      reviewer looks like codex too (F03-2, F04-5); outside Windows, where orphans are
#      reparented, it is judged by its recorded pids + start times only.
function Test-PendingActive {
    param($Record, [string]$Path)
    $state = [string](Get-PropertyValue $Record 'state' '')
    $recHost = [string](Get-PropertyValue $Record 'host' '')
    $otherHost = [bool]($recHost -and -not $recHost.Equals([Environment]::MachineName, [StringComparison]::OrdinalIgnoreCase))
    $what = "state '$state', consult n=$(Get-PropertyValue $Record 'n' '?'), handoff $(Get-PropertyValue $Record 'nn' '?'), started $(Get-PropertyValue $Record 'started' '?')"
    $panelInfo = Get-PropertyValue $Record 'panel' $null
    $isPanel = ($null -ne $panelInfo)
    if ($isPanel) {
        $panelId = [string](Get-PropertyValue $panelInfo 'id' '')
        $what += ", review panel $($panelId.Substring(0, [Math]::Min(8, $panelId.Length))) member $(Get-PropertyValue $panelInfo 'position' '?')"
    }
    $launcher = [string](Get-PropertyValue $Record 'launcher' '')
    # the CLI the record's run started (0.4.0 `engine`; older records: codex)
    $cli = [string](Get-PropertyValue $Record 'engine' '')
    if (-not $cli) { $cli = 'codex' }
    $pids = New-Object System.Collections.Generic.List[object]
    $cp = 0
    if ([int]::TryParse([string](Get-PropertyValue $Record 'child_pid' ''), [ref]$cp) -and $cp -gt 0) {
        $pids.Add([pscustomobject]@{ pid = $cp; start = (ConvertTo-JsonText (Get-PropertyValue $Record 'child_start_time' '')); name = '' })
    }
    # survivors: { pid, start_time, name } entries; a bare pid (older record) has no
    # start time and is judged by the "looks like codex" rule, never by pid alone.
    foreach ($s in @(Get-PropertyValue $Record 'survivors' @())) {
        $sp = 0
        $sStart = ''
        $sName = ''
        if ($null -ne $s -and $s -is [psobject] -and $s.PSObject.Properties['pid']) {
            [void][int]::TryParse([string]$s.pid, [ref]$sp)
            $sStart = ConvertTo-JsonText (Get-PropertyValue $s 'start_time' '')
            $sName = [string](Get-PropertyValue $s 'name' '')
        } else {
            [void][int]::TryParse([string]$s, [ref]$sp)
        }
        if ($sp -gt 0) { $pids.Add([pscustomobject]@{ pid = $sp; start = $sStart; name = $sName }) }
    }
    # (wave 28e, E1 / F54-1) unverified: { pid, why } entries - descendants whose start time could not
    # be read at the kill; reported and checked again below (Test-UnverifiedProcess)
    $unverified = New-Object System.Collections.Generic.List[object]
    foreach ($u in @(Get-PropertyValue $Record 'unverified' @())) {
        $up = 0
        $uWhy = ''
        if ($null -ne $u -and $u -is [psobject] -and $u.PSObject.Properties['pid']) {
            [void][int]::TryParse([string]$u.pid, [ref]$up)
            $uWhy = [string](Get-PropertyValue $u 'why' '')
        } else {
            [void][int]::TryParse([string]$u, [ref]$up)
        }
        if ($up -gt 0) { $unverified.Add([pscustomobject]@{ pid = $up; why = $uWhy }) }
    }
    $originalNote = Get-PendingOriginalNote $Record
    $inactive = { param($c) [pscustomobject]@{ Active = $false; Message = ''; Check = $(if ($originalNote) { "$c; $originalNote" } else { $c }) } }
    $active = { param($m, $c) [pscustomobject]@{ Active = $true; Message = $(if ($originalNote) { $m.TrimEnd([char]'.') + "; $originalNote." } else { $m }); Check = $c } }

    # D1: the bridge that wrote the record, while it runs (a panel member building its prompt,
    # running its reviewer or committing) - by pid + start time only, and never this process.
    $writerPid = 0
    [void][int]::TryParse([string](Get-PropertyValue $Record 'pid' ''), [ref]$writerPid)
    $writerStart = ConvertTo-JsonText (Get-PropertyValue $Record 'start_time' '')
    $writerGone = ''
    if ($writerPid -gt 0 -and $writerStart -and $writerPid -ne $PID) {
        if ($otherHost) {
            # cannot be checked from here; the rules below decide (pids on another host: active)
        } elseif (Test-PidAlive -ProcessId $writerPid -StartTime $writerStart) {
            return (& $active "a consultation of this task is still running: its bridge (pid $writerPid) wrote $Path ($what). Wait for it to finish; the record is removed when it commits." "writer pid $writerPid alive (pid + start time)")
        } else {
            $writerGone = "writer pid $writerPid gone"
        }
    }

    if ($state -eq 'reserved') { return (& $inactive "reserved: $cli was never started$(if ($writerGone) { "; $writerGone" })") }
    if (($pids.Count -gt 0 -or $unverified.Count -gt 0) -and $state -ne 'launching') {
        $pidList = (@(@($pids | ForEach-Object { $_.pid }) + @($unverified | ForEach-Object { $_.pid })) -join ', ')
        if ($otherHost) {
            return (& $active "an interrupted consultation on host $recHost left $cli process(es) pid $pidList ($what); they cannot be checked from this host. Delete $Path only after making sure they are gone." "pids on host $recHost")
        }
        $alive = New-Object System.Collections.Generic.List[string]
        $aliveHow = New-Object System.Collections.Generic.List[string]
        $gone = New-Object System.Collections.Generic.List[string]
        # (wave 28e, E19 / F27-2) the record's start and pids, for EVERY re-check by the evidence rule (a
        # survivor without a start time, or whose start time cannot be read now, and every unverified pid):
        # a process that started before the record is not its; a child of a recorded pid is never dropped
        $uSince = $null
        try { $uSince = [DateTimeOffset]::Parse((ConvertTo-JsonText (Get-PropertyValue $Record 'started' '')), $script:Invariant) } catch { $uSince = $null }
        $recordedPids = [int[]]@(@($(if ($writerPid -gt 0) { $writerPid })) + @($pids | ForEach-Object { [int]$_.pid }) + @($unverified | ForEach-Object { [int]$_.pid }) | Where-Object { $_ -gt 0 } | Select-Object -Unique)
        foreach ($entry in $pids) {
            $verdict = Test-RecordedProcess -ProcessId $entry.pid -StartTime $entry.start -Name $entry.name -Launcher $launcher -Since $uSince -RecordedPids $recordedPids
            # (E19) a pid judged by the evidence rule (not by its pid + start time) says why in the refusal
            if ($verdict.Alive) { $alive.Add($(if ($verdict.How -eq 'pid + start time') { "$($entry.pid)" } else { "$($entry.pid) [$($verdict.How)]" })); $aliveHow.Add("$($entry.pid) [$($verdict.How)]") } else { $gone.Add("$($entry.pid) [$($verdict.How)]") }
        }
        # (wave 28e, E1 / F54-1) the descendants the kill could not verify, checked again now: one still
        # unreadable, or readable and codex-like, blocks like a survivor; a gone one is dropped - said
        $uAlive = New-Object System.Collections.Generic.List[string]
        $uGone = New-Object System.Collections.Generic.List[string]
        if ($unverified.Count -gt 0) {
            foreach ($entry in $unverified) {
                $verdict = Test-UnverifiedProcess -ProcessId $entry.pid -Since $uSince -Launcher $launcher -RecordedPids $recordedPids
                if ($verdict.Alive) { $uAlive.Add("$($entry.pid) [$($verdict.How)$(if ($entry.why) { "; at the kill: $($entry.why)" })]") } else { $uGone.Add("$($entry.pid) [$($verdict.How)]") }
            }
        }
        $uDropped = $(if ($uGone.Count -gt 0) { "unverified pid(s) $($uGone -join ', ') dropped" } else { '' })
        if ($alive.Count -gt 0 -or $uAlive.Count -gt 0) {
            $parts = New-Object System.Collections.Generic.List[string]
            $checkParts = New-Object System.Collections.Generic.List[string]
            if ($alive.Count -gt 0) { $parts.Add("a previous consultation's $cli process (pid $($alive -join ', ')) is still running ($what)"); $checkParts.Add("pid $($aliveHow -join ', ') alive") }
            if ($uAlive.Count -gt 0) {
                $parts.Add($(if ($alive.Count -gt 0) { "a process its kill could not verify blocks too: pid $($uAlive -join ', ')" } else { "a previous consultation's $cli run left a process its kill could not verify ($what): pid $($uAlive -join ', ') - it blocks the task as a survivor does" }))
                $checkParts.Add("unverified pid $($uAlive -join ', ') counted as running")
            }
            if ($uDropped) { $parts.Add($uDropped); $checkParts.Add($uDropped) }
            return (& $active "$($parts -join '; '). Wait for it to exit or stop it, then retry; $Path keeps its record until then." ($checkParts -join '; '))
        }
        # Every RECORDED pid is gone - but the record names the launcher (the npm shim on
        # Windows) and the survivors the kill could see; the real codex may be a
        # descendant that outlived them. A dead launcher is not proof of a dead tree:
        # fall through to the descendant scan below (F04-10).
        $goneParts = New-Object System.Collections.Generic.List[string]
        if ($gone.Count -gt 0) { $goneParts.Add("$cli pid(s) $($gone -join ', ') no longer running") }
        if ($uDropped) { $goneParts.Add($uDropped) }
        $recordedGone = $goneParts -join '; '
    } else {
        $recordedGone = ''
    }
    if ($writerGone) { $recordedGone = $(if ($recordedGone) { "$writerGone; $recordedGone" } else { $writerGone }) }
    # (wave 28e, E23 / F30-1) a kill that was not confirmed and named no pid left an UNKNOWN tree
    # (`kill_unconfirmed`): only a clean scan by parent pid - the writer, the child, every other recorded
    # pid (Windows keeps an orphan's parent id) - AND a clean machine-wide "looks like codex" check release
    # the record ((E25 / F32-1) a panel member's too: a reviewer under a dead, unrecorded intermediate is
    # invisible by parent; a live sibling member's codex merely postpones the release); a scan that fails or
    # finds a process refuses, and so does a host without the rule by parent pid (outside Windows orphans
    # are reparented) or another host: the operator then deletes the record knowing none of it runs
    # (fail-closed).
    $killUnconfirmed = [string](Get-PropertyValue $Record 'kill_unconfirmed' '')
    if ($killUnconfirmed) {
        $kWhy = "the kill of its $cli run was not confirmed ($killUnconfirmed)"
        $kRelease = "Make sure no $cli process of that run still runs, then delete $Path to release it."
        if ($otherHost) { return (& $active "an interrupted consultation on host $recHost ($what) left an UNKNOWN process tree - $kWhy; it cannot be checked from this host. $kRelease" "unknown tree after an unconfirmed kill on host $recHost") }
        if (-not $script:OnWindows) { return (& $active "an interrupted consultation ($what) left an UNKNOWN process tree - $kWhy - and this host cannot scan for its processes by parent pid (outside Windows an orphan is reparented). $kRelease" "unknown tree after an unconfirmed kill ($killUnconfirmed): no scan by parent pid outside Windows - released only by the operator") }
        $kParents = New-Object System.Collections.Generic.List[int]
        $kWriter = 0
        if ([int]::TryParse([string](Get-PropertyValue $Record 'pid' ''), [ref]$kWriter) -and $kWriter -gt 0) { $kParents.Add($kWriter) }
        foreach ($entry in $pids) { if ([int]$entry.pid -gt 0 -and -not $kParents.Contains([int]$entry.pid)) { $kParents.Add([int]$entry.pid) } }
        foreach ($entry in $unverified) { if ([int]$entry.pid -gt 0 -and -not $kParents.Contains([int]$entry.pid)) { $kParents.Add([int]$entry.pid) } }
        if ($kParents.Count -eq 0) { return (& $active "an interrupted consultation ($what) left an UNKNOWN process tree - $kWhy - and the record names no pid to scan under. $kRelease" "unknown tree after an unconfirmed kill: no recorded pid to scan under") }
        $kSince = [datetime]::MinValue
        try { $kSince = [DateTimeOffset]::Parse((ConvertTo-JsonText (Get-PropertyValue $Record 'started' '')), $script:Invariant).LocalDateTime } catch { $kSince = [datetime]::MinValue }
        $kChecks = New-Object System.Collections.Generic.List[string]
        if ($recordedGone) { $kChecks.Add($recordedGone) }
        $kScans = New-Object System.Collections.Generic.List[object]
        foreach ($parent in $kParents) { $kScans.Add($parent) }
        # then the machine-wide rule, for EVERY record ((E25 / F32-1) a panel member's too): a grandchild
        # whose own parent died is invisible by parent
        $kScans.Add(0)
        foreach ($parent in $kScans) {
            $s = Find-CodexProcesses -Since $kSince -Launcher $launcher -BridgePid ([int]$parent)
            if ($s.Failed) { return (& $active "an interrupted consultation ($what) left an UNKNOWN process tree - $kWhy - and the scan for its processes failed: $($s.Check). $kRelease" "unknown tree after an unconfirmed kill; $($s.Check)") }
            if (@($s.Found).Count -gt 0) {
                if ($isPanel -and [int]$parent -eq 0) {
                    # (E25) the machine-wide rule cannot tell a sibling member's reviewer from this member's
                    # orphan: either postpones the release
                    $list = (@($s.Found) | ForEach-Object { "pid $($_.pid) $($_.name) (task not verifiable)" }) -join ', '
                    return (& $active "an interrupted consultation ($what) left an UNKNOWN process tree - $kWhy - and a codex-like process runs: $list - this panel member's unknown tree is released only when no such process runs. Wait for it to exit or stop it, then retry (or delete $Path once you know it is unrelated)." "unknown tree after an unconfirmed kill; $($s.Check)")
                }
                $list = (@($s.Found) | ForEach-Object { "pid $($_.pid) $($_.name) [$($_.rule)]" }) -join ', '
                return (& $active "an interrupted consultation ($what) left an UNKNOWN process tree - $kWhy - and a $cli-like process of it may still run: $list, found by $($s.Check). Wait for it to exit or stop it, then retry (or delete $Path once you know it is unrelated)." "unknown tree after an unconfirmed kill; $($s.Check)")
            }
            $kChecks.Add("$($s.Check): none found")
        }
        return (& $inactive "unknown tree after an unconfirmed kill: the scan found no codex-like process under pid $($kParents -join ', ') since $(ConvertTo-JsonText (Get-PropertyValue $Record 'started' '')) - released ($($kChecks -join '; '))")
    }
    # The child may exist unregistered (launching) or as a descendant of a dead recorded
    # process (running/survivors). Scan for it; never trust a dead root or elapsed time.
    if ($otherHost) { return (& $inactive "state '$state' from host $recHost without pids: treated as dead") }
    if ($isPanel -and -not $script:OnWindows) {
        # Orphans are reparented outside Windows: only the recorded pids tell (above).
        return (& $inactive "$(if ($recordedGone) { "$recordedGone; " })panel member record: judged by its recorded pids only (no process scan outside Windows)")
    }
    $since = [datetime]::MinValue
    try { $since = [DateTimeOffset]::Parse((ConvertTo-JsonText (Get-PropertyValue $Record 'started' '')), $script:Invariant).LocalDateTime } catch { $since = [datetime]::MinValue }
    # Parent pids whose (orphaned) children would be ours: the bridge that wrote the
    # record and every recorded codex pid (the launcher shim, the survivors). On Windows
    # an orphan keeps the ParentProcessId of its dead parent; elsewhere orphans are
    # reparented and only the command-line rule below can find them.
    $parentPids = New-Object System.Collections.Generic.List[int]
    $bridgePid = 0
    if ([int]::TryParse([string](Get-PropertyValue $Record 'pid' ''), [ref]$bridgePid) -and $bridgePid -gt 0) { $parentPids.Add($bridgePid) }
    foreach ($entry in $pids) { if ($entry.pid -gt 0 -and -not $parentPids.Contains([int]$entry.pid)) { $parentPids.Add([int]$entry.pid) } }
    # (wave 28e, E1) and every unverified pid (its orphans keep its parent id too)
    foreach ($entry in $unverified) { if ($entry.pid -gt 0 -and -not $parentPids.Contains([int]$entry.pid)) { $parentPids.Add([int]$entry.pid) } }
    $scan = $null
    $checks = New-Object System.Collections.Generic.List[string]
    if ($recordedGone) { $checks.Add($recordedGone) }
    foreach ($parent in $parentPids) {
        $s = Find-CodexProcesses -Since $since -Launcher $launcher -BridgePid $parent
        if ($s.Failed) { $scan = $s; break }
        if (@($s.Found).Count -gt 0) { $scan = $s; break }
        $checks.Add("$($s.Check): none found")
    }
    # A panel member's record stops here: recorded pids and their children only - the
    # machine-wide rule below would take a live SIBLING member's reviewer for its orphan.
    if ($isPanel -and ($null -eq $scan -or (-not $scan.Failed -and @($scan.Found).Count -eq 0))) {
        $checks.Add('panel member record: no machine-wide name scan')
        return (& $inactive ($checks -join '; '))
    }
    # The parent-pid rule sees only DIRECT children of a dead parent. If the shim died
    # but its own child lives, only the "looks like codex" rule can see it; its matches
    # cannot be tied to this task and are labelled so. There is deliberately NO age
    # cut-off: an old record with a live codex-looking process started after it refuses
    # until that process exits or the operator deletes the record knowing it is unrelated.
    if ($null -eq $scan -or (-not $scan.Failed -and @($scan.Found).Count -eq 0)) {
        $scan = Find-CodexProcesses -Since $since -Launcher $launcher -BridgePid 0
    }
    if ($checks.Count -gt 0) { $scan.Check = (($checks -join '; ') + '; then ' + $scan.Check) }
    if ($scan.Failed) {
        return (& $active "an interrupted consultation ($what) may have left a $cli process running, and the check failed: $($scan.Check). Make sure no such process runs, then delete $Path." $scan.Check)
    }
    if (@($scan.Found).Count -gt 0) {
        $list = (@($scan.Found) | ForEach-Object { "pid $($_.pid) $($_.name) [$($_.rule)]" }) -join ', '
        return (& $active "an interrupted consultation ($what) may still have its $cli process running: $list, found by $($scan.Check). Wait for it to exit or stop it, then retry (or delete $Path once you know it is unrelated)." $scan.Check)
    }
    return (& $inactive "$($scan.Check): none found")
}

# (wave 28c, D11 / F43-3, F44-6) The compactions an engine REPORTED in the event streams of a run's
# turns: a line whose `type` is context_compacted, compacted or thread.compacted (a protocol event
# passed through), or an item.completed whose item is a context_compaction / contextCompaction /
# compaction. The names are the ones the Codex CLI uses in its protocol (read from the strings of
# codex-cli 0.155.1); that version's `exec --json` stream carries none of them - its items are
# agent_message, reasoning, command_execution, file_change, mcp_tool_call, collab_tool_call,
# web_search, todo_list - so 0 here is "none reported", not "none happened" (the ledger then says
# `unknown` for a member with context_tokens). Missing files are skipped. Returns the count.
$script:CompactionEventTypes = @('context_compacted', 'compacted', 'thread.compacted')
$script:CompactionItemTypes = @('context_compaction', 'contextCompaction', 'compaction')
function Get-CompactionCount {
    param([string[]]$Paths)
    $n = 0
    foreach ($p in @($Paths)) {
        if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
        $text = ''
        try { $text = Read-SharedText -Path $p } catch { continue }
        foreach ($line in ($text -split "`r?`n")) {
            if ($line.IndexOf('ompact', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $t = $line.Trim()
            if (-not $t.StartsWith('{')) { continue }
            $o = $null
            try { $o = ConvertFrom-Json -InputObject $t } catch { continue }
            if (-not (Test-IsJsonObject $o)) { continue }
            $type = [string](Get-PropertyValue $o 'type' '')
            if ($script:CompactionEventTypes -ccontains $type) { $n++; continue }
            # (wave 29) claude stream-json: system/compact_boundary
            if ($type -ceq 'system' -and [string](Get-PropertyValue $o 'subtype' '') -ceq 'compact_boundary') { $n++; continue }
            $msg = Get-PropertyValue $o 'msg' $null
            if ($msg -and $script:CompactionEventTypes -ccontains [string](Get-PropertyValue $msg 'type' '')) { $n++; continue }
            if ($type -ceq 'item.completed') {
                $it = Get-PropertyValue $o 'item' $null
                $itType = [string](Get-PropertyValue $it 'type' '')
                if (-not $itType) { $itType = [string](Get-PropertyValue $it 'item_type' '') }
                if ($script:CompactionItemTypes -ccontains $itType) { $n++ }
            }
        }
    }
    return $n
}

# ----------------------------------------------------------------------------- processes

# (wave 28b, D14 / F37-3) The pid/ppid pairs of a process table in text: `ps -A -o pid=,ppid=` (two
# numbers per line), or /proc/<pid>/stat lines ("<pid> (<comm>) <state> <ppid> ..." - the command
# may hold blanks and parentheses: the ppid is the second field after the LAST ')'). Pure (a harness
# feeds it text). [object[]] of { Pid; Ppid }.
function ConvertFrom-ProcessTable {
    param([string[]]$Lines, [ValidateSet('ps', 'proc')][string]$Format = 'ps')
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($l in @($Lines)) {
        $t = ([string]$l).Trim()
        if (-not $t) { continue }
        $procId = 0; $ppid = 0
        if ($Format -eq 'ps') {
            $parts = @($t -split '\s+')
            if ($parts.Count -ge 2 -and [int]::TryParse($parts[0], [ref]$procId) -and [int]::TryParse($parts[1], [ref]$ppid)) { $out.Add([pscustomobject]@{ Pid = $procId; Ppid = $ppid }) }
        } else {
            $close = $t.LastIndexOf(')')
            $open = $t.IndexOf(' ')
            if ($close -lt 0 -or $open -lt 0) { continue }
            $rest = @($t.Substring($close + 1).Trim() -split '\s+')
            if ($rest.Count -ge 2 -and [int]::TryParse($t.Substring(0, $open), [ref]$procId) -and [int]::TryParse($rest[1], [ref]$ppid)) { $out.Add([pscustomobject]@{ Pid = $procId; Ppid = $ppid }) }
        }
    }
    return , ([object[]]$out.ToArray())
}

# The descendants of $RootId in a list of { Pid; Ppid } pairs (breadth first, no repeats): int[].
function Get-TreeFromPairs {
    param([object[]]$Pairs, [int]$RootId)
    $found = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootId)
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        foreach ($p in @($Pairs)) {
            $n = [int]$p.Pid
            if ([int]$p.Ppid -eq $cur -and $n -ne $cur -and $n -ne $RootId -and -not $found.Contains($n)) { $found.Add($n); $queue.Enqueue($n) }
        }
    }
    return , ([int[]]$found.ToArray())
}

# (wave 27c, D16) The descendants of $RootId and whether the process table could be read at all: {
# Pids (int[]); Starts (wave 28b, D14: pid -> its start time as Get-ProcessStartIso reads it, '' when
# unknown - the liveness probe compares it, so a recycled pid is no survivor); Via (cim | pgrep | ps
# | proc); Denied ('' or why the children could not be enumerated - a restricted host, e.g. a sandbox
# that denies process inspection) }. Windows: CIM. Elsewhere (Get-UnixDescendantTree): pgrep -P,
# else (wave 28b, D14 / F37-3) `ps -A -o pid=,ppid=`, else /proc/<pid>/stat - (wave 28c, D9) a pgrep
# that fails (any exit but 0 and 1, a timeout) goes on to the next method; denied only when none of
# them works. TEST
# HOOK (test mode only, D14): CODEX_CONSULT_TEST_KILL_DENIED=1 - the enumeration is denied (and so is
# taskkill, Invoke-TaskKillTree); (wave 28c, D8) =taskkill - taskkill alone is denied.
function Get-DescendantTree {
    param([int]$RootId)
    $r = [pscustomobject]@{ Pids = [int[]]@(); Starts = @{}; Via = ''; Denied = '' }
    if ((Get-TestHookValue 'CODEX_CONSULT_TEST_KILL_DENIED').Trim() -eq '1') { $r.Denied = 'process inspection denied (test hook CODEX_CONSULT_TEST_KILL_DENIED)'; return $r }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($script:OnWindows) {
            $all = @()
            try { $all = @(Get-CimInstance -ClassName Win32_Process -Property ProcessId, ParentProcessId -ErrorAction Stop) } catch { $r.Denied = "the process table could not be read ($(ConvertTo-OneLine $_.Exception.Message))"; return $r }
            if ($all.Count -eq 0) { $r.Denied = 'the process table came back empty'; return $r }
            $r.Via = 'cim'
            $r.Pids = Get-TreeFromPairs -Pairs ([object[]]@($all | ForEach-Object { [pscustomobject]@{ Pid = [int]$_.ProcessId; Ppid = [int]$_.ParentProcessId } })) -RootId $RootId
        } else {
            # (wave 28c, D9 / F42-5) pgrep, else ps, else /proc - a FAILED method goes on to the next
            $u = Get-UnixDescendantTree -RootId $RootId
            if ($u.Denied) { $r.Denied = $u.Denied; return $r }
            $r.Via = $u.Via
            $r.Pids = [int[]]$u.Pids
        }
        # (wave 28b, D14 / F37-2) each descendant's start time, read NOW - before the kill
        # (a pid already gone is recorded as '<gone>': the probe never counts it)
        foreach ($d in $r.Pids) { $st = Get-ProcessStartIso -ProcessId $d; $r.Starts[[int]$d] = $(if ($null -eq $st) { '<gone>' } else { [string]$st }) }
    } finally {
        $ErrorActionPreference = $previous
    }
    return $r
}

# (wave 28c, D9) One command, its output captured and its time bounded: { Exit (-1 when it did not
# run or was stopped); Lines (stdout, non-empty lines); TimedOut; Error ('' or why it did not run) }.
# The process is killed when it outlives $TimeoutMs.
function Invoke-CapturedCommand {
    param([string]$File, [string[]]$ArgList = @(), [int]$TimeoutMs = 5000)
    $r = [pscustomobject]@{ Exit = -1; Lines = [string[]]@(); TimedOut = $false; Error = '' }
    $proc = $null
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $File
        $psi.Arguments = ((@($ArgList) | ForEach-Object { ConvertTo-ProcArg ([string]$_) }) -join ' ')
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($TimeoutMs)) {
            $r.TimedOut = $true
            try { $proc.Kill() } catch { }
            try { $null = $proc.WaitForExit(1000) } catch { }
            return $r
        }
        $proc.WaitForExit()
        $r.Exit = [int]$proc.ExitCode
        $text = ''
        try { $text = [string]$outTask.Result } catch { $text = '' }
        try { $null = $errTask.Result } catch { }
        $r.Lines = [string[]]@($text -split "`r?`n" | Where-Object { $_.Trim() })
    } catch {
        $r.Error = ConvertTo-OneLine $_.Exception.Message
    } finally { if ($proc) { try { $proc.Dispose() } catch { } } }
    return $r
}

# (wave 28c, D9 / F42-5) The descendants of $RootId where there is no CIM (Linux, macOS): { Pids;
# Via (pgrep | ps | proc); Denied ('' or why no method worked); Tried (what each method answered) }.
#   pgrep -P <pid> for each process, breadth first: exit 0 - the pids it printed (every line a pid, or
#     the enumeration FAILED); exit 1 - no child (pgrep's "no match"); ANY other exit, a timeout (each
#     call bounded by $TimeoutMs), or a pgrep that cannot run - a FAILED enumeration, never an empty
#     child set: the next method;
#   `ps -A -o pid=,ppid=` (exit 0 and a table that parses), else /proc/<pid>/stat (under $ProcRoot);
#   denied only when every method failed - the kill is then not confirmed (Stop-ProcessTreeChecked).
# $Runner (a harness's): { param($File, $ArgList, $TimeoutMs) -> the shape of Invoke-CapturedCommand };
# an answer with Error 'not found' stands for a missing command. Pure but for the runner and the
# /proc reads.
function Get-UnixDescendantTree {
    param([int]$RootId, [scriptblock]$Runner = $null, [string]$ProcRoot = '/proc', [int]$TimeoutMs = 5000)
    $r = [pscustomobject]@{ Pids = [int[]]@(); Via = ''; Denied = ''; Tried = (New-Object System.Collections.Generic.List[string]) }
    $run = $Runner
    if (-not $run) {
        $run = {
            param([string]$File, [string[]]$ArgList, [int]$TimeoutMs)
            $cmd = Get-Command $File -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $cmd) { return [pscustomobject]@{ Exit = -1; Lines = [string[]]@(); TimedOut = $false; Error = 'not found' } }
            return (Invoke-CapturedCommand -File ([string]$cmd.Source) -ArgList $ArgList -TimeoutMs $TimeoutMs)
        }
    }
    # 1. pgrep
    $found = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootId)
    $pgrepWhy = ''
    while ($queue.Count -gt 0 -and -not $pgrepWhy) {
        $cur = $queue.Dequeue()
        $a = & $run 'pgrep' ([string[]]@('-P', [string]$cur)) $TimeoutMs
        if ($a.Error) { $pgrepWhy = $(if ($a.Error -eq 'not found') { 'no pgrep' } else { "pgrep failed ($($a.Error))" }); break }
        if ($a.TimedOut) { $pgrepWhy = "pgrep -P $cur timed out after $([Math]::Round($TimeoutMs / 1000.0, 1)) s"; break }
        if ($a.Exit -eq 1) { continue }
        if ($a.Exit -ne 0) { $pgrepWhy = "pgrep -P $cur exit $($a.Exit)"; break }
        foreach ($k in @($a.Lines)) {
            $n = 0
            if (-not [int]::TryParse(([string]$k).Trim(), [ref]$n) -or $n -le 0) { $pgrepWhy = "pgrep -P $cur printed '$(ConvertTo-OneLine ([string]$k))', not a pid"; break }
            if (-not $found.Contains($n) -and $n -ne $RootId) { $found.Add($n); $queue.Enqueue($n) }
        }
    }
    if (-not $pgrepWhy) { $r.Via = 'pgrep'; $r.Pids = [int[]]$found.ToArray(); return $r }
    $r.Tried.Add($pgrepWhy)
    # 2. ps
    $pairs = @()
    $a = & $run 'ps' ([string[]]@('-A', '-o', 'pid=,ppid=')) $TimeoutMs
    if ($a.Error) { $r.Tried.Add($(if ($a.Error -eq 'not found') { 'no ps' } else { "ps failed ($($a.Error))" })) }
    elseif ($a.TimedOut) { $r.Tried.Add("ps timed out after $([Math]::Round($TimeoutMs / 1000.0, 1)) s") }
    elseif ($a.Exit -ne 0) { $r.Tried.Add("ps exit $($a.Exit)") }
    else {
        $pairs = ConvertFrom-ProcessTable -Lines ([string[]]@($a.Lines)) -Format 'ps'
        if (@($pairs).Count -gt 0) { $r.Via = 'ps' } else { $r.Tried.Add('ps printed no process table') }
    }
    # 3. /proc
    if (-not $r.Via) {
        if ($ProcRoot -and [IO.Directory]::Exists($ProcRoot)) {
            $stats = New-Object System.Collections.Generic.List[string]
            foreach ($d in @(Get-ChildItem -LiteralPath $ProcRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^[0-9]+$' })) {
                try { $stats.Add([IO.File]::ReadAllText((Join-Path $d.FullName 'stat'))) } catch { }
            }
            $pairs = ConvertFrom-ProcessTable -Lines ([string[]]$stats.ToArray()) -Format 'proc'
            if (@($pairs).Count -gt 0) { $r.Via = 'proc' } else { $r.Tried.Add("$ProcRoot unreadable") }
        } else { $r.Tried.Add("no $ProcRoot") }
    }
    if (-not $r.Via) { $r.Denied = "the process table could not be read ($($r.Tried -join '; '))"; return $r }
    $r.Pids = Get-TreeFromPairs -Pairs ([object[]]$pairs) -RootId $RootId
    return $r
}

# Descendant pids of $RootId (Get-DescendantTree). Best effort.
function Get-DescendantPids {
    param([int]$RootId)
    return , ([int[]](Get-DescendantTree -RootId $RootId).Pids)
}

# (wave 27c, D16) `taskkill /PID <root> /T /F` (Windows): its exit code (0 = the whole tree was
# terminated), -1 when it could not run. Under the D16 test hook it is "denied": exit 1, nothing run
# (CODEX_CONSULT_TEST_KILL_DENIED=1, or - wave 28c - =taskkill: taskkill alone).
function Invoke-TaskKillTree {
    param([int]$RootId)
    if (@('1', 'taskkill') -contains (Get-TestHookValue 'CODEX_CONSULT_TEST_KILL_DENIED').Trim()) { return 1 }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $global:LASTEXITCODE = 0
        & taskkill.exe /PID $RootId /T /F 2>$null | Out-Null
        return [int]$LASTEXITCODE
    } catch { return -1 } finally { $ErrorActionPreference = $previous }
}
# (wave 26b, D10) The operator's kick file of the run with handoff number $Nn:
# <task>/.consult.kick-<NN> - written by `-Kick -Member <NN>` (from another shell), polled by the
# run while its engine turn runs; the run deletes it once the turn's process tree is stopped (the
# acknowledgement -Kick waits for). A `.consult.*` file: outside the tree check.
function Get-KickPath {
    param([string]$TaskDir, [string]$Nn)
    return (Join-Path $TaskDir ".consult.kick-$Nn")
}

# (wave 27c, D1 / F30-1, F29-2, F32-1, F30-6) The kick protocol, per REQUEST: the kick file and its
# acknowledgement are small JSON records { id (a GUID), when, pid[, result] }. Read-KickRecord reads
# one tolerantly: { Exists; Id ('' for an older plain-text file); Result; When ($null when unknown -
# then the file's own write time counts) }.
function Read-KickRecord {
    param([string]$Path)
    $r = [pscustomobject]@{ Exists = $false; Id = ''; Result = ''; When = $null }
    if (-not $Path -or -not [IO.File]::Exists($Path)) { return $r }
    $r.Exists = $true
    $text = Read-SharedText -Path $Path
    try {
        $o = ConvertFrom-Json -InputObject $text
        if (Test-IsJsonObject $o) {
            $r.Id = [string](Get-PropertyValue $o 'id' '')
            $r.Result = [string](Get-PropertyValue $o 'result' '')
            $r.When = ConvertTo-WhenOffset (Get-PropertyValue $o 'when' '')
        }
    } catch {
        # an older plain-text record: "kicked <iso> ..." / "late <iso> ..."
        if ($text -match '^(kicked|late)\b') { $r.Result = $(if ($Matches[1] -eq 'late') { 'late' } else { 'stopped' }) }
    }
    if ($null -eq $r.When) { try { $r.When = [DateTimeOffset]([IO.File]::GetLastWriteTimeUtc($Path)) } catch { } }
    return $r
}

# (wave 27c, D1) A caller's kick request: a new request is written ATOMICALLY (a temporary file,
# then a rename that never replaces) - when a kick file is already there the caller JOINS it (takes
# its id) and never overwrites it. { Id; Created ($true: this caller made the request - only it
# removes the acknowledgement after reading it); Error }.
function New-KickRequest {
    param([string]$KickPath)
    $r = [pscustomobject]@{ Id = ''; Created = $false; Error = '' }
    $id = [guid]::NewGuid().ToString()
    $tmp = "$KickPath.$([guid]::NewGuid().ToString('N')).tmp"
    try { Write-Utf8NoBom -Path $tmp -Text ((ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ id = $id; when = (Get-IsoTimestamp); pid = $PID })) + "`n") } catch { $r.Error = ConvertTo-OneLine $_.Exception.Message; return $r }
    try {
        for ($i = 0; $i -lt 20; $i++) {
            try { [IO.File]::Move($tmp, $KickPath); $r.Id = $id; $r.Created = $true; return $r } catch { }
            $existing = Read-KickRecord -Path $KickPath
            if ($existing.Exists -and $existing.Id) { $r.Id = $existing.Id; return $r }
            Start-Sleep -Milliseconds 100
        }
        $r.Error = "the kick file '$KickPath' is there but carries no request id"
        return $r
    } finally { try { if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) } } catch { } }
}

# (wave 27c, D1) An acknowledgement older than 60 s that is not $KeepId's is swept (by any later
# -Kick, and by the next run start of the member). $true when one was removed.
function Clear-StaleKickAck {
    param([string]$KickPath, [string]$KeepId = '')
    $ack = Read-KickRecord -Path "$KickPath.ack"
    if (-not $ack.Exists -or ($KeepId -and $ack.Id -eq $KeepId)) { return $false }
    if ($null -ne $ack.When -and ([DateTimeOffset]::Now - $ack.When).TotalSeconds -lt 60) { return $false }
    return (-not (Remove-PendingFile -Path "$KickPath.ack"))
}

# (wave 26c, D1 / F26-1, F25-2) The member TAKES the operator's kick: (wave 27c, D1) it writes the
# acknowledgement <kick file>.ack - atomically - holding the request's id and the result: "stopped"
# (the turn is being stopped) or "late" (the turn had already finished, the outcome stays), and
# removes the kick file. The callers wait for THEIR id. Never throws.
function Confirm-Kick {
    param([string]$KickPath, [string]$What = 'stopped')
    if (-not $KickPath) { return }
    $req = Read-KickRecord -Path $KickPath
    try { Write-TextAtomic -Path "$KickPath.ack" -Text ((ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ id = $req.Id; result = $What; when = (Get-IsoTimestamp); pid = $PID })) + "`n") } catch { }
    $null = Remove-PendingFile -Path $KickPath
}
# (wave 26c, D3) The bytes appended to an event stream since byte $Offset, and the COMPLETE lines
# among them: { Offset (the new end); Bytes (the growth - any byte counts as activity); Lines
# (string[], the complete lines, UTF-8); Carry (byte[]: the unfinished last line, completed by the
# next read); Discarding (the unfinished line is an oversized one being skipped); Oversized (lines
# discarded by this read) }. Shared read; a file that is absent or cannot be read yet counts as no
# growth.
# (wave 27c, D5 / F30-3, F32-8) BOUNDED: only the newly read bytes are scanned for line ends
# ([Array]::IndexOf), the carry is the text after the last line end and is capped at $CarryCap (1
# MiB) - a longer unfinished line is discarded up to its end and counted (Oversized); the stall
# timer's activity is the byte count, independent of parsing.
$script:StreamCarryCap = 1048576
function Read-StreamChunk {
    param([string]$Path, [long]$Offset = 0, [byte[]]$Carry = @(), [bool]$Discarding = $false, [int]$CarryCap = $script:StreamCarryCap)
    $r = [pscustomobject]@{ Offset = $Offset; Bytes = 0; Lines = [string[]]@(); Carry = [byte[]]@($Carry); Discarding = $Discarding; Oversized = 0 }
    if (-not $Path) { return $r }
    $fs = $null
    try {
        $fs = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        if ($fs.Length -lt $Offset) { $Offset = 0; $Carry = @(); $Discarding = $false }
        [void]$fs.Seek($Offset, [IO.SeekOrigin]::Begin)
        $pending = New-Object IO.MemoryStream
        if (@($Carry).Count -gt 0) { $pending.Write([byte[]]$Carry, 0, @($Carry).Count) }
        $lines = New-Object System.Collections.Generic.List[string]
        $buf = New-Object byte[] 65536
        $grown = [long]0
        $oversized = 0
        while ($true) {
            $got = $fs.Read($buf, 0, $buf.Length)
            if ($got -le 0) { break }
            $grown += $got
            $start = 0
            while ($start -lt $got) {
                $nl = [Array]::IndexOf($buf, [byte]10, $start, $got - $start)
                if ($nl -lt 0) {
                    # no line end in the rest: it joins the unfinished line (unless that one is skipped)
                    if (-not $Discarding) {
                        $pending.Write($buf, $start, $got - $start)
                        if ($pending.Length -gt $CarryCap) { $Discarding = $true; $oversized++; $pending.SetLength(0) }
                    }
                    break
                }
                if ($Discarding) {
                    # the oversized line ends here: skipped, never parsed
                    $Discarding = $false
                } else {
                    $pending.Write($buf, $start, $nl - $start)
                    if ($pending.Length -gt $CarryCap) { $oversized++ }
                    else { $lines.Add($script:Utf8NoBom.GetString($pending.GetBuffer(), 0, [int]$pending.Length).TrimEnd("`r")) }
                }
                $pending.SetLength(0)
                $start = $nl + 1
            }
        }
        $r.Offset = $Offset + $grown
        $r.Bytes = $grown
        $r.Lines = [string[]]$lines.ToArray()
        $r.Carry = $pending.ToArray()
        $r.Discarding = $Discarding
        $r.Oversized = $oversized
    } catch { } finally { if ($fs) { $fs.Dispose() } }
    return $r
}
# (wave 26c, D3 / F26-3, F25-1) The tool calls in flight in an engine's event stream, updated per
# complete line ($Open: a HashSet[string] of their keys): codex `item.started` of a
# command_execution, mcp_tool_call or web_search item until its `item.completed` (by the item id;
# an id-less one by its type); agy a `tool` step in state ACTIVE until the same step reports
# another state; muse a task proposed with task_kind tool.* until its task.lifecycle end
# (completed, failed, cancelled, rejected). A line that is not such an event changes nothing.
# (wave 28b, D12) $Labels (optional, key -> text): what an open key names for the stall cut - "codex
# command_execution <id>", "agy tool step <n>", "muse <task kind> <task id>". (wave 29) claude: an
# assistant event's tool_use block until the user event's tool_result with its tool_use_id ("claude
# <tool> <id>").
$script:CodexToolItems = @('command_execution', 'mcp_tool_call', 'web_search')
function Update-ToolFlight {
    param([string]$Engine, [string]$Line, $Open, $Labels = $null)
    $t = ([string]$Line).Trim()
    if (-not $t.StartsWith('{')) { return }
    # a cheap test first: most lines are messages and deltas
    $isCodex = (-not $Engine -or $Engine -eq 'codex')
    if ($isCodex -and $t.IndexOf('command_execution') -lt 0 -and $t.IndexOf('mcp_tool_call') -lt 0 -and $t.IndexOf('web_search') -lt 0) { return }
    if ($Engine -eq 'agy' -and $t.IndexOf('"tool"') -lt 0) { return }
    if ($Engine -eq 'muse' -and $t.IndexOf('task.lifecycle.') -lt 0) { return }
    if ($Engine -eq 'claude' -and $t.IndexOf('tool_use') -lt 0 -and $t.IndexOf('tool_result') -lt 0) { return }
    $obj = $null
    try { $obj = ConvertFrom-Json -InputObject $t } catch { return }
    if ($isCodex) {
        $type = [string](Get-PropertyValue $obj 'type' '')
        if ($type -ne 'item.started' -and $type -ne 'item.completed') { return }
        $it = Get-PropertyValue $obj 'item' $null
        if (-not (Test-IsJsonObject $it)) { return }
        $itype = [string](Get-PropertyValue $it 'type' '')
        if ($script:CodexToolItems -notcontains $itype) { return }
        $id = [string](Get-PropertyValue $it 'id' '')
        if ($type -eq 'item.started') {
            $key = $(if ($id) { "codex:$id" } else { "codex-type:$itype#$($Open.Count)" })
            [void]$Open.Add($key)
            if ($null -ne $Labels) { $Labels[$key] = "codex $itype$(if ($id) { " $id" })" }
            return
        }
        if ($id -and $Open.Contains("codex:$id")) { [void]$Open.Remove("codex:$id"); return }
        $k = @($Open | Where-Object { $_ -like "codex-type:$itype#*" }) | Select-Object -First 1
        if ($k) { [void]$Open.Remove([string]$k) }
        return
    }
    if ($Engine -eq 'agy') {
        if ([string](Get-PropertyValue $obj 'event' '') -ne 'step_update') { return }
        $su = Get-PropertyValue $obj 'step_update' $null
        if (-not (Test-IsJsonObject $su) -or [string](Get-PropertyValue $su 'step_type' '') -ne 'tool') { return }
        $key = "agy:$([string](Get-PropertyValue $su 'step_index' ''))"
        if ([string](Get-PropertyValue $su 'state' '') -eq 'ACTIVE') {
            [void]$Open.Add($key)
            if ($null -ne $Labels) { $Labels[$key] = "agy tool step $([string](Get-PropertyValue $su 'step_index' '?'))" }
        } else { [void]$Open.Remove($key) }
        return
    }
    if ($Engine -eq 'muse') {
        $pType = [string](Get-PropertyValue $obj 'payload_type' '')
        if ($pType -notlike 'task.lifecycle.*') { return }
        $payload = Get-PropertyValue $obj 'payload' $null
        $ev = Get-PropertyValue $payload 'event' $null
        $tid = [string](Get-PropertyValue $ev 'task_id' '')
        if (-not $tid) { $tid = [string](Get-PropertyValue $payload 'task_id' '') }
        if (-not $tid) { return }
        if ($pType -eq 'task.lifecycle.proposed') {
            $kind = [string](Get-PropertyValue $ev 'task_kind' '')
            if ($kind -like 'tool.*') {
                [void]$Open.Add("muse:$tid")
                if ($null -ne $Labels) { $Labels["muse:$tid"] = "muse $kind $tid" }
            }
            return
        }
        if (@('task.lifecycle.completed', 'task.lifecycle.failed', 'task.lifecycle.cancelled', 'task.lifecycle.canceled', 'task.lifecycle.rejected') -contains $pType) { [void]$Open.Remove("muse:$tid") }
        return
    }
    if ($Engine -eq 'claude') {
        $type = [string](Get-PropertyValue $obj 'type' '')
        if ($type -ne 'assistant' -and $type -ne 'user') { return }
        $msg = Get-PropertyValue $obj 'message' $null
        foreach ($b in @(Get-PropertyValue $msg 'content' @())) {
            if (-not (Test-IsJsonObject $b)) { continue }
            $bt = [string](Get-PropertyValue $b 'type' '')
            if ($type -eq 'assistant' -and $bt -eq 'tool_use') {
                $id = [string](Get-PropertyValue $b 'id' '')
                if (-not $id) { continue }
                [void]$Open.Add("claude:$id")
                if ($null -ne $Labels) { $Labels["claude:$id"] = "claude $([string](Get-PropertyValue $b 'name' 'tool')) $id" }
            } elseif ($type -eq 'user' -and $bt -eq 'tool_result') {
                $tid = [string](Get-PropertyValue $b 'tool_use_id' '')
                if ($tid) { [void]$Open.Remove("claude:$tid") }
            }
        }
    }
}

# (wave 26b, D10, D12) Waits for an engine turn's process: its wall-clock limit ($TimeoutSec), the
# stall cut ($StallSec > 0: no output appended to $EventsPath for that long while the process
# lives - the codex --json items, agy's stream-json, muse's MSP records all go to that file; the
# clock starts with the turn) and the operator's kick ($KickPath appears).
# (wave 26c, D3) The silent timer resets on ANY growth of the stream (bytes, not complete lines)
# and is SUSPENDED while a tool call is in flight (Update-ToolFlight over $Engine's events): a
# member running one long command is never cut; the timeout stays the hard bound.
# (wave 26c, D1) The kick file is checked before the wait loop, on every poll and ONCE MORE after
# the process exited: a kick found then is taken as LATE (KickLate - the outcome stays); every
# taken kick is acknowledged (Confirm-Kick).
# Polls every second (TEST HOOK: CODEX_CONSULT_TEST_WAIT_TICK_MS). Kills nothing - the caller
# stops the tree. { Exited; Reason ('' | 'timeout' | 'stall' | 'kick'); KickLate; Events (lines
# seen); LastEvent (DateTimeOffset of the last line seen, $null when none); Silent (seconds
# without output outside a tool call at the stall cut); ToolWait (seconds the timer was suspended
# for tool calls) }.
# (wave 27c, D5) Oversized: the event lines longer than 1 MiB skipped by the bounded reader.
# (wave 28b, D12 / F36-11, F32-7) A tool call cannot suspend the stall timer for ever, and no
# completion event is needed to end the suspension: while a tool call is open, the stream must still
# GROW - once it has not grown for 2 x -StallSec (TEST HOOK, test mode only:
# CODEX_CONSULT_TEST_TOOL_CAP_SEC = that bound in seconds; no floor) the suspension ends and the
# stall cut follows, naming the open call: ToolOpen = the seconds the tool call(s) had been open (0
# when the cut was an ordinary one), OpenTools = what they were ("codex command_execution item_3",
# "agy tool step 4", "muse tool.shell t1"; several joined by ', ').
function Wait-EngineProcess {
    param($Process, [int]$TimeoutSec, [int]$StallSec = 0, [string]$EventsPath = '', [string]$KickPath = '', [string]$Engine = 'codex')
    $r = [pscustomobject]@{ Exited = $false; Reason = ''; KickLate = $false; Events = 0; LastEvent = $null; Silent = 0; ToolWait = 0; Oversized = 0; ToolOpen = 0; OpenTools = '' }
    $tick = 1000
    $hook = 0
    if ([int]::TryParse((Get-TestHookValue 'CODEX_CONSULT_TEST_WAIT_TICK_MS'), [ref]$hook) -and $hook -gt 0) { $tick = $hook }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $limitMs = [long]$TimeoutSec * 1000
    $stallMs = [long]$StallSec * 1000
    $offset = [long]0
    $carry = [byte[]]@()
    $discarding = $false
    $lastMs = [long]0
    # (wave 27c, D6) the last growth of the stream (never moved by a tool suspension), when the tool
    # calls in flight opened; (wave 28b, D12) how long an open tool call may leave the stream
    # without growth: 2 x the stall threshold
    $lastByteMs = [long]0
    $openSinceMs = [long]-1
    $toolQuietMs = 2 * $stallMs
    $capHook = 0
    if ([int]::TryParse((Get-TestHookValue 'CODEX_CONSULT_TEST_TOOL_CAP_SEC'), [ref]$capHook) -and $capHook -gt 0) { $toolQuietMs = [long]$capHook * 1000 }
    $toolMs = [long]0
    $open = New-Object 'System.Collections.Generic.HashSet[string]'
    $labels = @{}
    # before the loop: a kick for a turn still running stops it (one for a turn that has already
    # exited is taken as late right below)
    $exitedAlready = $false
    try { $exitedAlready = [bool]$Process.HasExited } catch { }
    if ($KickPath -and -not $exitedAlready -and [IO.File]::Exists($KickPath)) { $r.Reason = 'kick'; Confirm-Kick -KickPath $KickPath -What 'stopped'; return $r }
    while ($true) {
        $left = $limitMs - $watch.ElapsedMilliseconds
        if ($left -le 0) { $r.Reason = 'timeout'; break }
        if ($Process.WaitForExit([int][Math]::Min([long]$tick, $left))) {
            $r.Exited = $true
            if ($KickPath -and [IO.File]::Exists($KickPath)) { $r.KickLate = $true; Confirm-Kick -KickPath $KickPath -What 'late' }
            break
        }
        if ($KickPath -and [IO.File]::Exists($KickPath)) { $r.Reason = 'kick'; Confirm-Kick -KickPath $KickPath -What 'stopped'; break }
        if ($stallMs -gt 0 -and $EventsPath) {
            $nowMs = $watch.ElapsedMilliseconds
            $g = Read-StreamChunk -Path $EventsPath -Offset $offset -Carry $carry -Discarding $discarding
            $offset = $g.Offset
            $carry = $g.Carry
            $discarding = $g.Discarding
            $r.Oversized += $g.Oversized
            if ($g.Bytes -gt 0) { $lastMs = $nowMs; $lastByteMs = $nowMs }
            if (@($g.Lines).Count -gt 0) { $r.Events += @($g.Lines).Count; $r.LastEvent = [DateTimeOffset]::Now }
            $wasOpen = ($open.Count -gt 0)
            foreach ($ln in $g.Lines) { Update-ToolFlight -Engine $Engine -Line $ln -Open $open -Labels $labels }
            if ($open.Count -gt 0) { if ($openSinceMs -lt 0) { $openSinceMs = $nowMs } } else { $openSinceMs = [long]-1 }
            $openFor = $(if ($openSinceMs -ge 0) { $nowMs - $openSinceMs } else { [long]0 })
            if ($open.Count -gt 0 -and ($nowMs - $lastByteMs) -ge $toolQuietMs) {
                # (D12) a tool call open, but no growth of the stream for 2 x stall: the suspension
                # ends, the cut names the open call(s)
                $r.Reason = 'stall'
                $r.Silent = [int][Math]::Floor(($nowMs - $lastByteMs) / 1000)
                $r.ToolOpen = [int][Math]::Floor($openFor / 1000)
                $r.OpenTools = (@($open | Sort-Object | ForEach-Object { if ($labels.ContainsKey($_)) { [string]$labels[$_] } else { [string]$_ } }) -join ', ')
                break
            }
            if ($wasOpen -or $open.Count -gt 0) {
                # a tool call in flight (or one that just ended): the silent timer does not run
                $toolMs += [Math]::Max([long]0, $nowMs - $lastMs)
                $lastMs = $nowMs
                continue
            }
            if (($nowMs - $lastMs) -ge $stallMs) {
                $r.Reason = 'stall'
                $r.Silent = [int][Math]::Floor(($nowMs - $lastMs) / 1000)
                break
            }
        }
    }
    $r.ToolWait = [int][Math]::Floor($toolMs / 1000)
    return $r
}

# Kills the process AND its descendants (the launcher is usually a shim: cmd.exe or
# node in front of the real codex binary). Windows: taskkill /T /F; elsewhere: the
# pgrep -P tree. Best effort; returns the pids (root included) still alive after it,
# as an [int[]] (empty when the whole tree is gone) - Stop-ProcessTreeChecked says more.
# A kill returns before the OS has torn the process down: the killed pids are polled
# (100 ms steps, up to 3 s) and only those still alive after that wait are survivors.
# A process merely still exiting must not be recorded as a survivor - that would keep
# .consult.pending.json in state 'survivors' and block the task until a later run.
function Stop-ProcessTree {
    param($Process)
    return , ([int[]](Stop-ProcessTreeChecked -Process $Process).Survivors)
}

# (wave 27c, D16 / H4) The tree kill, CONFIRMED: { Survivors (int[] - the pids known alive after
# it); Confirmed ($true only when the root exited and every known descendant is gone - and, where
# the children could not be enumerated, taskkill /T /F reported the whole tree terminated); Why ('' or
# why it is not confirmed); RootPid }. When the enumeration is denied (a restricted host) the kill
# falls back to `taskkill /PID <root> /T /F` - once before the root is killed, and once more when the
# root is still there - and checks the root again. A kill that is not confirmed must never be
# reported as "(process tree killed)", and no continuation turn may follow it (the orphan may still
# hold the thread). (wave 28c, D8 / F42-4) No pid-only identity: a descendant is killed by its pid
# only while its identity is confirmed (Get-PidIdentity 'alive': the start time read at the
# enumeration matches the one read now); a descendant whose start time cannot be read is neither
# killed by pid nor counted as gone - it is left alone, listed in Unverified, and the kill is "not
# confirmed: start time of pid <n> unreadable" (Windows' taskkill /T, which walks the live tree of
# the root itself, still runs).
function Stop-ProcessTreeChecked {
    param($Process)
    $res = [pscustomobject]@{ Survivors = [int[]]@(); Confirmed = $true; Why = ''; RootPid = 0; Unverified = [int[]]@() }
    if ($null -eq $Process) { return $res }
    $rootId = $Process.Id
    $res.RootPid = $rootId
    $tree = Get-DescendantTree -RootId $rootId
    $descendants = [int[]]$tree.Pids
    $denied = [string]$tree.Denied
    $taskkillExit = $null
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($script:OnWindows) { $taskkillExit = Invoke-TaskKillTree -RootId $rootId }
        # The root before its descendants: a root that outlives its children reacts to
        # their death (a shell or node shim carries on and may start new processes).
        try { if (-not $Process.HasExited) { $Process.Kill() } } catch { }
        foreach ($d in $descendants) {
            # (wave 28b, D14) never a pid that meanwhile belongs to another process; (wave 28c, D8)
            # never one whose identity cannot be confirmed
            $st0 = $(if ($tree.Starts -and $tree.Starts.ContainsKey([int]$d)) { [string]$tree.Starts[[int]$d] } else { '' })
            if ($st0 -eq '<gone>' -or (Get-PidIdentity -ProcessId $d -StartTime $st0) -ne 'alive') { continue }
            try { Stop-Process -Id $d -Force -ErrorAction SilentlyContinue } catch { }
        }
        try { $null = $Process.WaitForExit(10000) } catch { }
    } finally {
        $ErrorActionPreference = $previous
    }
    # The root: its handle (immune to pid reuse). (wave 28b, D14 / F37-2) A descendant counts as alive
    # only while a process with its pid exists WITH the start time read at the enumeration - a pid the
    # OS handed to another process meanwhile is no survivor; (wave 28c, D8) one whose start time cannot
    # be read is neither alive nor gone: unverified.
    $starts = $tree.Starts
    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    $rootGone = $true
    $unknown = New-Object System.Collections.Generic.List[int]
    while ($true) {
        $alive = New-Object System.Collections.Generic.List[int]
        $unknown = New-Object System.Collections.Generic.List[int]
        $rootGone = $true
        try { $rootGone = $Process.HasExited } catch { $rootGone = $true }
        if (-not $rootGone) { $alive.Add($rootId) }
        foreach ($d in $descendants) {
            $st = $(if ($starts -and $starts.ContainsKey([int]$d)) { [string]$starts[[int]$d] } else { '' })
            if ($st -eq '<gone>') { continue }
            $idn = Get-PidIdentity -ProcessId $d -StartTime $st
            if ($idn -eq 'alive') { $alive.Add($d) } elseif ($idn -eq 'unknown') { $unknown.Add($d) }
        }
        if (($alive.Count -eq 0 -and $unknown.Count -eq 0) -or [DateTime]::UtcNow -ge $deadline) { break }
        Start-Sleep -Milliseconds 100
    }
    if ($unknown.Count -gt 0) {
        $res.Confirmed = $false
        $res.Unverified = [int[]]$unknown.ToArray()
        $res.Why = "start time of pid $($unknown -join ', ') unreadable"
    }
    if ($denied) {
        # the children are not known: the fallback taskkill once more when the root is still there,
        # then the root checked again
        if (-not $rootGone -and $script:OnWindows) {
            $taskkillExit = Invoke-TaskKillTree -RootId $rootId
            try { $null = $Process.WaitForExit(3000) } catch { }
            try { $rootGone = $Process.HasExited } catch { $rootGone = $true }
            if ($rootGone) { [void]$alive.Remove($rootId) }
        }
        if (-not $rootGone) {
            $res.Confirmed = $false
            $res.Why = "the children could not be enumerated ($denied) and the root process did not exit"
        } elseif (-not $script:OnWindows -or $taskkillExit -ne 0) {
            $res.Confirmed = $false
            $res.Why = "the children could not be enumerated ($denied)$(if ($script:OnWindows) { " and taskkill /T /F failed (exit $taskkillExit)" }) - the root exited, its children may not have"
        }
    }
    if ($alive.Count -gt 0) { $res.Confirmed = $false }
    $res.Survivors = [int[]]$alive.ToArray()
    return $res
}
# ----------------------------------------------------------------------------- detached runs (wave 25, R12): the writers
#
# (wave 26, F07-3) The readers of the detached runs - the status record, its judgement, the -List
# line and the SessionStart hook's phrase - live in codex-consult-detached.ps1, which this file
# dot-sources at the top (the hook dot-sources it alone). The writers stay here.

# Replaces the status file atomically (Write-JsonFile: temp + rename; readers never see a
# partial file); `updated` is set here. Throws on failure - the caller decides what it means.
function Write-DetachedStatus {
    param([string]$Path, $Record)
    $Record.updated = Get-IsoTimestamp
    Write-JsonFile -Path $Path -Object $Record
}

# The budget of a detached run (D4) - -Wait's default timeout: per endpoint group ceil(members /
# limit) x the longest member guard of the group, the largest over the groups; with a
# -PanelConcurrency cap also ceil(members / cap) x the longest guard; the larger of the two, plus
# $Slack (120 s). A single run is one group of one member. $Groups: Get-PanelPlan's groups
# (Limit, Positions); $GuardOf: roster position -> that member's kill guard.
function Get-DetachedBudget {
    param([object[]]$Groups, [hashtable]$GuardOf, [int]$Cap = 0, [int]$Slack = 120)
    $byGroups = 0
    $longest = 0
    $count = 0
    foreach ($g in @($Groups | Where-Object { $_ })) {
        $positions = @($g.Positions)
        if ($positions.Count -eq 0) { continue }
        $gMax = 0
        foreach ($p in $positions) { $v = [int]$GuardOf[[int]$p]; if ($v -gt $gMax) { $gMax = $v } }
        $limit = [Math]::Max(1, [int]$g.Limit)
        $waves = [int][Math]::Ceiling($positions.Count / [double]$limit)
        if ($waves * $gMax -gt $byGroups) { $byGroups = $waves * $gMax }
        if ($gMax -gt $longest) { $longest = $gMax }
        $count += $positions.Count
    }
    $byCap = 0
    if ($Cap -gt 0 -and $count -gt 0) { $byCap = [int][Math]::Ceiling($count / [double]$Cap) * $longest }
    return [int]([Math]::Max($byGroups, $byCap) + $Slack)
}

# Makes a record final (D3): state done, the exit code, finished and wall_seconds (from `started`)
# unless already set, the summary ($Summary when given, else the one it has, else $Line, else a
# pointer to the log), and every member still pending -> skipped "not started: <the first summary
# line>", still running -> failed "stopped: the run ended (exit <e>) before this member finished".
# Idempotent: the run's own final write and the background's confirmation after it agree.
function Complete-DetachedRecord {
    param($Record, [int]$Exit, [string]$Summary = '', [string]$Line = '')
    $now = Get-Date
    $Record.state = 'done'
    $Record.exit = $Exit
    if (-not $Record.finished) { $Record.finished = Get-IsoTimestamp $now }
    if ($null -eq $Record.wall_seconds) {
        $st = ConvertTo-WhenOffset $Record.started
        if ($st) { $Record.wall_seconds = [math]::Round(([DateTimeOffset]$now - $st).TotalSeconds, 1) }
    }
    if ($Summary) { $Record.summary = $Summary }
    elseif (-not $Record.summary) {
        $Record.summary = $(if ($Line) { $Line } else { "codex-consult: the detached run ended with exit $Exit without a summary; its console output is in $($Record.log)" })
    }
    $why = ConvertTo-OneLine ((([string]$Record.summary) -split "`n")[0] -replace '^codex-consult:\s*', '')
    if ($why.Length -gt 200) { $why = $why.Substring(0, 197) + '...' }
    foreach ($m in @($Record.members | Where-Object { $_ })) {
        if ($m.state -eq 'pending') { $m.state = 'skipped'; $m.outcome = "not started: $why" }
        elseif ($m.state -eq 'running') { $m.state = 'failed'; $m.outcome = "stopped: the run ended (exit $Exit) before this member finished" }
    }
}

# The background's arguments (-Detach) as text for the `starting` record - base64 of UTF-8
# PowerShell CLIXML: PSSerializer keeps every value's type (a -Prompt that looks like a date stays a
# string, an array an array; no command-line quoting is involved) - and back, a hashtable to splat.
# A switch travels as [bool].
function ConvertTo-DetachArgs {
    param([hashtable]$Arguments)
    $clean = @{}
    foreach ($k in @($Arguments.Keys)) {
        $v = $Arguments[$k]
        if ($v -is [System.Management.Automation.SwitchParameter]) { $v = [bool]$v.IsPresent }
        elseif ($v -is [array]) { $v = [string[]]@($v | ForEach-Object { [string]$_ }) }
        $clean[[string]$k] = $v
    }
    $xml = [System.Management.Automation.PSSerializer]::Serialize($clean)
    return [Convert]::ToBase64String($script:Utf8NoBom.GetBytes($xml))
}

function ConvertFrom-DetachArgs {
    param([string]$Text)
    if (-not $Text) { throw 'the status file carries no arguments for the background' }
    $obj = [System.Management.Automation.PSSerializer]::Deserialize($script:Utf8NoBom.GetString([Convert]::FromBase64String($Text)))
    if (-not ($obj -is [System.Collections.IDictionary])) { throw 'the arguments in the status file are not a parameter table' }
    $spec = @{}
    foreach ($k in @($obj.Keys)) {
        $v = $obj[$k]
        if ($null -ne $v -and -not ($v -is [string]) -and $v -is [System.Collections.IEnumerable]) { $v = [string[]]@($v | ForEach-Object { [string]$_ }) }
        $spec[[string]$k] = $v
    }
    return $spec
}

# ----------------------------------------------------------------------------- telemetry (wave 28, R17)
#
# ONE anonymised event per consultation and the operator's complaints, to the maintainer's intake
# (the T-hub v2 contract: POST <base>/v2/events, POST <base>/v2/complaints). ON by default;
# CODEX_CONSULT_TELEMETRY=off, or -Telemetry off for one run, switches it off (Get-TelemetrySwitch,
# codex-consult-detached.ps1). Never in a consultation's critical path: (wave 28b, D6) at the ledger
# commit - inside the task's write lock, right before the entry is added - the bridge appends one
# NDJSON line to <codex home>/telemetry-spool/<yyyy-mm-dd>.ndjson (the LOCAL date - D16;
# Add-TelemetryEvent; (wave 28c, D7) the append waits at most 1 s there and is retried for up to 5 s
# after the write lock; an event that is still not spooled puts "telemetry event not spooled
# (<why>) ..." onto the console and the detached status record, and is counted for -Status), and
# after the commit it starts ONE detached sender
# (codex-telemetry.ps1 -Flush - Start-TelemetrySender), which it does not wait for. The event is
# built from the ledger entry being committed through a closed allowlist (ConvertTo-TelemetryDetails,
# New-TelemetryEvent): the engine, (wave 28b, D1) the VENDOR CLASS of the endpoint and the model name
# only when it equals an entry of that vendor's closed list (wave 28c; $script:TelemetryVendors - never the roster
# label), the purpose, the outcome class, wall seconds, token and finding counts, a few booleans,
# the panel size, the PowerShell version, the OS, the plugin version and a salted instance id -
# never a task name, a brief, a prompt, a path, a thread id, a finding text, a key, a provider label
# the operator typed, a user name or the machine name in clear.
#
# A spool line: {"v":1,"kind":"event"|"complaint","queued_unix":<s>,"body":"<the JSON sent>"} - the
# body travels as a JSON STRING, so the sender posts exactly the bytes that were built (no
# re-serialisation: PowerShell 7's ConvertFrom-Json would turn the ISO client_time into a date).
# Every writer of a spool file opens it EXCLUSIVELY (FileShare.None; the bridge's append retried up
# to 5 s, the sender's read and rewrite ~2 s); the sender removes what it delivered or dropped as a
# multiset of exact lines, so lines appended while it posted stay.
# (wave 28b, D2) The sender has a deadline: one flush ends after 60 s in all, one request (connect,
# send, read) is bounded as a whole by 8 s; its lock <spool>/.flush.lock is a marker file released
# in `finally`. (wave 28c, D4, D5) The lock is taken over only from a dead owner, the sender checks
# its token before each send and rewrite, and the 60 s cover every local step too.
# (D3) The sender starts with a MINIMAL environment built from an allow list
# (Get-TelemetrySenderEnvironment) - no provider key, no host marker, no other CODEX_CONSULT_*
# variable; the bridge's own environment is never changed for it.
# (wave 28c, D3, D7) Every producer's append, the salt's creation and -Forget -Local take THE
# telemetry lock (Enter-TelemetryLock); the commit's append waits at most 1 s and is retried for up
# to 5 s after the task's write lock is released; -Forget -Local writes the forgetting marker.

$script:TelemetryAppId = 'codex-consult'
$script:TelemetryDefaultUrl = 'https://xelth.com/T'
$script:TelemetrySpoolDays = 7
$script:TelemetryBatchMax = 100
$script:TelemetryRetryAfterMax = 60
$script:TelemetryTextMaxBytes = 8192
# (wave 28b, D2, D6, D8) the sender's bounds, the spool append's wait, the refused-event rounds
$script:TelemetryFlushMs = 60000
$script:TelemetryRequestMs = 8000
$script:TelemetryLockStaleSec = 300
$script:TelemetrySpoolWaitMs = 5000
$script:TelemetryRejectRounds = 3
# (wave 28b, D1 / F36-1) THE vendor table: the event's `provider` is the vendor CLASS of the endpoint
# the reviewer talked to - derived from the endpoint's HOST (the host equals one of Hosts or ends with
# '.' + one of them), or from the engine for agy (google) and muse (meta); a codex run on the built-in
# provider (the ChatGPT login or an API key, no OPENAI_BASE_URL) is openai; anything else is `other`.
# (wave 28c, D1 / F42-1, F43-2) The event's `model` is the model name only when the class is known AND
# the name, lower-cased, EQUALS an entry of that class's Models - a CLOSED list of the published model
# names the README documents (its effort table and its roster examples) and the rosters have run. No
# pattern, no version wildcard: a model outside the list reads `other` until a release adds it. The
# roster label and a model name outside the table never leave the machine; the ledger and every local
# file keep the real ones. Known limitation (F43-6, F44-3): the class is derived from the host NAME
# only - a private gateway or relay under a vendor's domain reads as that vendor.
# (wave 29b, E5, E6) Lab: the lab (Get-EntryLab) an endpoint entry of the claude engine gets from its
# base URL's HOST - '' for a host that resells other labs' models (byteplus, alibaba: the model id
# decides there). MiniMax (api.minimax.io, api.minimax.cn; the published id MiniMax-M3, listed lower
# case as every list is) is known by shape and not run.
$script:TelemetryVendors = @(
    [pscustomobject]@{ Class = 'openai'; Hosts = @('openai.com', 'chatgpt.com'); Engine = ''; Builtin = 'openai'; Lab = 'openai'; Models = @('gpt-5.1', 'gpt-6-astra', 'o4-mini') }
    [pscustomobject]@{ Class = 'zai'; Hosts = @('z.ai', 'bigmodel.cn'); Engine = ''; Builtin = ''; Lab = 'zhipu'; Models = @('glm-5.3', 'glm-5.3-flash', 'glm-5.3-flashx', 'glm-5.2', 'glm-5.1', 'glm-5', 'glm-5-turbo', 'glm-4.7', 'glm-4.6', 'glm-4.5', 'glm-4.5-air') }
    [pscustomobject]@{ Class = 'xiaomi'; Hosts = @('xiaomimimo.com'); Engine = ''; Builtin = ''; Lab = 'xiaomi'; Models = @('mimo-v2.6-pro', 'mimo-v2.6-flash', 'mimo-v2.6-pro-ultraspeed', 'mimo-v2.5-pro', 'mimo-v2.5') }
    [pscustomobject]@{ Class = 'byteplus'; Hosts = @('bytepluses.com'); Engine = ''; Builtin = ''; Lab = ''; Models = @('dola-seed-2.0-pro', 'dola-seed-2.0-lite', 'dola-seed-2.0-code', 'bytedance-seed-code', 'glm-5.3-flash', 'glm-5.2', 'glm-5.1', 'kimi-k2.5', 'gpt-oss-120b', 'deepseek-v4.1-flash', 'deepseek-v4-flash', 'deepseek-v4-pro') }
    [pscustomobject]@{ Class = 'moonshot'; Hosts = @('kimi.ai', 'moonshot.ai'); Engine = ''; Builtin = ''; Lab = 'moonshot'; Models = @('k3', 'k3-256k', 'kimi-for-coding', 'kimi-for-coding-highspeed', 'kimi-k2.5', 'kimi-k3') }
    [pscustomobject]@{ Class = 'alibaba'; Hosts = @('aliyuncs.com'); Engine = ''; Builtin = ''; Lab = ''; Models = @('qwen3.8-max', 'qwen3.8-flash', 'qwen3.7-max', 'qwen3.7-plus', 'qwen3.6-flash', 'deepseek-v4.1-flash', 'deepseek-v4-pro', 'deepseek-v4-pro-0813', 'deepseek-v4-flash-0731', 'glm-5.3', 'glm-5.2') }
    [pscustomobject]@{ Class = 'minimax'; Hosts = @('api.minimax.io', 'api.minimax.cn'); Engine = ''; Builtin = ''; Lab = 'minimax'; Models = @('minimax-m3') }
    [pscustomobject]@{ Class = 'google'; Hosts = @(); Engine = 'agy'; Builtin = ''; Lab = 'google'; Models = @('gemini-3.8-flash-high', 'gemini-3.8-flash-medium', 'gemini-3.8-flash-low', 'gemini-3.1-pro-high', 'gemini-3.1-pro-low') }
    [pscustomobject]@{ Class = 'meta'; Hosts = @(); Engine = 'muse'; Builtin = ''; Lab = 'meta'; Models = @('muse-spark-1.3', 'muse-spark-1.3-contributor') }
    # (wave 29, item 10, D4) the claude engine: its model table IS the list ([1m] stripped first) -
    # (wave 29b, E6) the fallback for an entry without a base URL (auth subscription, api-key)
    [pscustomobject]@{ Class = 'anthropic'; Hosts = @(); Engine = 'claude'; Builtin = ''; Lab = 'anthropic'; Models = $script:ClaudeModels }
)
# The closed sets of the event (anything else becomes 'other' / 'unknown')
$script:TelemetryEventKeys = @('app_id', 'app_version', 'instance_id', 'event_type', 'severity', 'title', 'details', 'tags', 'client_time', 'os', 'runtime')
$script:TelemetryDetailKeys = @('engine', 'provider', 'model', 'purpose', 'outcome', 'wall_seconds', 'tokens', 'findings', 'structured', 'format_retry', 'denial_retry', 'timeout_continue', 'panel_size', 'ps_version', 'os', 'bridge_version')
# (R24) the details of a `rating` event (codex-findings.ps1 -Rate) and its marks
$script:TelemetryRatingDetailKeys = @('engine', 'provider', 'model', 'purpose', 'mark', 'age_days', 'bridge_version', 'os', 'ps_version')
$script:TelemetryRatingMarks = @('yes', 'partly', 'no')
$script:TelemetryFailureClasses = @('auth', 'quota', 'capability', 'transport', 'permission', 'operator', 'unknown', 'timeout', 'stalled', 'bridge')
$script:BridgeVersion = $null

# The plugin's version (.claude-plugin/plugin.json next to this scripts directory), read once;
# 'unknown' when it cannot be read.
function Get-BridgeVersion {
    if ($null -ne $script:BridgeVersion) { return $script:BridgeVersion }
    $v = 'unknown'
    try {
        $mf = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) '.claude-plugin') 'plugin.json'
        if (Test-Path -LiteralPath $mf -PathType Leaf) {
            $c = [string](Get-PropertyValue (ConvertFrom-Json -InputObject (Read-SharedText -Path $mf)) 'version' '')
            if ($c -match '^[0-9A-Za-z][0-9A-Za-z.+-]{0,31}$') { $v = $c }
        }
    } catch { }
    $script:BridgeVersion = $v
    return $v
}

# Where telemetry keeps its files, under the Codex home; $null without one. { Home; Spool (the
# directory); Salt; Last (the last flush's result); Lock (the sender's lock); Notice (the marker of
# the notice for this plugin version); NotSpooled (wave 28b, D6: the events not spooled, one NDJSON
# line each - (wave 28e, E2) the LEGACY single file, still counted and folded); NotSpooledOwn (wave
# 28e, E2: THIS process's file of them, telemetry-not-spooled-<pid>-<start ticks>.ndjson); (wave 28c,
# D3) TelLock (THE telemetry lock of the producers, the salt's creation and -Forget) and Forgetting (the
# marker -Forget writes while it deletes) }.
function Get-TelemetryPaths {
    $h = Get-CodexHome
    if (-not $h) { return $null }
    $spool = Join-Path $h 'telemetry-spool'
    return [pscustomobject]@{
        Home          = $h
        Spool         = $spool
        Salt          = (Join-Path $h 'telemetry-salt')
        Last          = (Join-Path $spool '.last')
        Lock          = (Join-Path $spool '.flush.lock')
        Notice        = (Join-Path $h ('telemetry-notice-' + (Get-BridgeVersion)))
        NotSpooled    = (Join-Path $h 'telemetry-not-spooled.ndjson')
        NotSpooledOwn = (Join-Path $h "telemetry-not-spooled-$PID-$(Get-TelemetryOwnStartTicks).ndjson")
        TelLock       = (Join-Path $h 'telemetry.lock')
        Forgetting    = (Join-Path $h 'telemetry-forgetting')
    }
}

# (wave 28e, E2) This process's start time in ticks (Get-ProcessStartTicks), read once; 0 when it
# cannot be read (its not-spooled file then names no start: its identity counts as unknown).
$script:TelemetryOwnStartTicks = $null
function Get-TelemetryOwnStartTicks {
    if ($null -eq $script:TelemetryOwnStartTicks) {
        $t = Get-ProcessStartTicks -ProcessId $PID
        $script:TelemetryOwnStartTicks = $(if ($null -ne $t -and $t -gt 0) { [long]$t } else { [long]0 })
    }
    return $script:TelemetryOwnStartTicks
}

# (wave 28c, D3 / F42-3) THE telemetry lock <codex home>/telemetry.lock - taken by every spool append
# of a producer (Add-TelemetryEvent, a complaint kept), by the salt's creation and by -Forget -Local:
# an OPEN HANDLE (FileShare.None), so the OS releases it when its holder dies (it is never stale; the
# empty file stays). While -Forget holds it, the marker <codex home>/telemetry-forgetting says so; a
# producer that meets the marker (or a lock that stays busy past its short wait) drops its event -
# counted - instead of recreating the salt or the spool. (wave 28d, D2 / F48-2) The marker HEALS
# itself: it names its owner {pid, start_time, (wave 28e, E3) start_ticks, since}; -Forget removes it
# in `finally`; a marker whose
# owner lives (Test-PidAlive - an identity that cannot be confirmed counts as living) refuses as
# before, and one whose owner is gone - or that names none: -Forget writes it under this lock, so no
# -Forget is writing it while it is held - is REMOVED under the lock (one line in <spool>/.last
# `notes`, Resolve-TelemetryForgetting) and the holder goes on. Re-entrant within a process.
# -IgnoreMarker: -Forget's own entry (it replaces a marker left behind), the spool's rewrite and the
# notes of .last. { Ok; Why; Forgetting }.
$script:TelemetryLockStream = $null
$script:TelemetryLockDepth = 0
function Enter-TelemetryLock {
    param([int]$WaitMs = 1000, [switch]$IgnoreMarker)
    $r = [pscustomobject]@{ Ok = $false; Why = ''; Forgetting = $false }
    $p = Get-TelemetryPaths
    if (-not $p) { $r.Why = 'no codex home (CODEX_HOME, else ~/.codex)'; return $r }
    if ($script:TelemetryLockStream) {
        if (-not $IgnoreMarker) { $why = Resolve-TelemetryForgetting -Paths $p; if ($why) { $r.Forgetting = $true; $r.Why = $why; return $r } }
        $script:TelemetryLockDepth++
        $r.Ok = $true
        return $r
    }
    try { [void][IO.Directory]::CreateDirectory($p.Home) } catch { $r.Why = "the codex home $($p.Home) could not be made ($(ConvertTo-OneLine $_.Exception.Message))"; return $r }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $fs = $null
    while ($null -eq $fs) {
        # a marker whose owner lives refuses at once (that -Forget holds this lock while it deletes)
        if (-not $IgnoreMarker -and [IO.File]::Exists($p.Forgetting)) {
            $m = Get-TelemetryForgettingOwner -Path $p.Forgetting
            if ($m.Alive) { $r.Forgetting = $true; $r.Why = $m.Why; return $r }
        }
        try { $fs = New-Object System.IO.FileStream($p.TelLock, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) } catch {
            if ($watch.ElapsedMilliseconds -ge $WaitMs) { $r.Why = "the telemetry lock $($p.TelLock) stayed busy for $([Math]::Round($WaitMs / 1000.0, 1)) s"; return $r }
            Start-Sleep -Milliseconds 25
        }
    }
    $script:TelemetryLockStream = $fs
    $script:TelemetryLockDepth = 1
    # the marker again, under the lock: a -Forget that finished removed it; (wave 28d, D2) one whose
    # owner is gone is removed now, one whose owner lives refuses
    if (-not $IgnoreMarker) {
        $why = Resolve-TelemetryForgetting -Paths $p
        if ($why) { Exit-TelemetryLock; $r.Forgetting = $true; $r.Why = $why; return $r }
    }
    $r.Ok = $true
    return $r
}

# Releases the telemetry lock (the last of a re-entrant holder's calls closes the handle).
function Exit-TelemetryLock {
    if (-not $script:TelemetryLockStream) { return }
    $script:TelemetryLockDepth--
    if ($script:TelemetryLockDepth -gt 0) { return }
    try { $script:TelemetryLockStream.Dispose() } catch { }
    $script:TelemetryLockStream = $null
    $script:TelemetryLockDepth = 0
}

# (wave 28d, D2 / F48-2) The forgetting marker as it is - read only: { There; Pid; Since; Alive (its
# owner - pid and start time - lives, or its identity cannot be confirmed: Test-PidAlive, never
# removed on a guess; a marker that names no owner is not alive); Why (the refusal while it lives) }.
# (wave 28e, E3 / F54-3) A marker that records `start_ticks` (the owner's start time in ticks, 100 ns -
# what -Forget writes since wave 28e) is judged on pid AND those ticks (Get-PidIdentityTicks: exactly
# equal on Windows; 'unknown' counts as alive); an older marker without them by its start_time string
# as before.
function Get-TelemetryForgettingOwner {
    param([string]$Path)
    $m = [pscustomobject]@{ There = $false; Pid = 0; Since = ''; Alive = $false; Why = '' }
    if (-not [IO.File]::Exists($Path)) { return $m }
    $m.There = $true
    $o = $null
    try { $t = [string](Read-SharedText -Path $Path); if ($t.Trim().StartsWith('{')) { $o = ConvertFrom-JsonKeepOffset -Text $t } } catch { $o = $null }
    $n = Get-TelemetryCount (Get-PropertyValue $o 'pid' $null)
    if ($null -ne $n -and $n -le [int]::MaxValue) { $m.Pid = [int]$n }
    $m.Since = [string](ConvertTo-JsonText (Get-PropertyValue $o 'since' ''))
    $ticks = Get-TelemetryCount (Get-PropertyValue $o 'start_ticks' $null)
    if ($m.Pid -gt 0 -and $null -ne $ticks -and $ticks -gt 0) { $m.Alive = [bool]((Get-PidIdentityTicks -ProcessId $m.Pid -StartTicks ([long]$ticks)) -ne 'gone') }
    elseif ($m.Pid -gt 0) { $m.Alive = [bool](Test-PidAlive -ProcessId $m.Pid -StartTime ([string](ConvertTo-StartIso (Get-PropertyValue $o 'start_time' '')))) }
    $m.Why = "codex-telemetry.ps1 -Forget -Local is deleting the local telemetry data (pid $($m.Pid)$(if ($m.Since) { ", since $($m.Since)" }); the marker $Path)"
    return $m
}

# (wave 28d, D2) UNDER the telemetry lock: a forgetting marker whose owner is gone (or that names none)
# is removed - one line in <spool>/.last `notes` - and '' is returned (the holder goes on); a marker
# whose owner lives returns the refusal. '' without a marker.
function Resolve-TelemetryForgetting {
    param($Paths)
    $m = Get-TelemetryForgettingOwner -Path $Paths.Forgetting
    if (-not $m.There) { return '' }
    if ($m.Alive) { return $m.Why }
    try { [IO.File]::Delete($Paths.Forgetting) } catch { return "the forgetting marker $($Paths.Forgetting) of a -Forget -Local that is gone could not be removed ($(ConvertTo-OneLine $_.Exception.Message))" }
    Add-TelemetryLastNote -Text "removed the forgetting marker of $(if ($m.Pid -gt 0) { "pid $($m.Pid) (gone)" } else { 'no named owner' })$(if ($m.Since) { " since $($m.Since)" }) - a -Forget -Local that did not finish; run it again to finish the local deletion"
    return ''
}

# The intake's base URL: CODEX_CONSULT_TELEMETRY_URL (an operator setting), else
# https://xelth.com/T. Only https - (wave 28b, D4 / F36-9, F37-4) plain http only for a LOOPBACK host
# (127.0.0.1, localhost, ::1) AND with CODEX_CONSULT_TEST_MODE=1 (a harness's local intake). { Base
# (no trailing slash; '' when refused); Source; Error }.
function Get-TelemetryUrl {
    $raw = ([string][Environment]::GetEnvironmentVariable('CODEX_CONSULT_TELEMETRY_URL')).Trim()
    $src = 'CODEX_CONSULT_TELEMETRY_URL'
    if (-not $raw) { $raw = $script:TelemetryDefaultUrl; $src = 'the default' }
    $r = [pscustomobject]@{ Base = ''; Source = $src; Error = '' }
    $u = $null
    if (-not [Uri]::TryCreate($raw, [UriKind]::Absolute, [ref]$u) -or -not $u.Host) {
        $r.Error = "the intake URL '$raw' ($src) is not an absolute URL"
        return $r
    }
    if ($u.Scheme -ne 'https') {
        if (-not ($u.Scheme -eq 'http' -and $u.IsLoopback)) {
            $r.Error = "the intake URL '$raw' ($src) is refused: only https (plain http only for a loopback test intake in test mode)"
            return $r
        }
        if (-not (Test-TestMode)) {
            $r.Error = "the intake URL '$raw' ($src) is refused: plain http to a loopback intake only with CODEX_CONSULT_TEST_MODE=1 (a harness); a real intake is https"
            return $r
        }
    }
    $r.Base = $raw.TrimEnd('/')
    return $r
}

# The instance id: the lowercase hex SHA-256 of the 32 salt bytes followed by the UTF-8 bytes of
# the machine name - the machine name never leaves in clear, and a new salt makes a new instance.
# The salt: <codex home>/telemetry-salt, 64 lowercase hex digits, created ONCE (-Create). (wave 28b,
# D5 / F36-9) Created atomically: a new salt is written to a temporary file and MOVED into place
# without overwriting - a creator that loses the race reads the winner's salt; a salt that parses is
# never deleted or replaced. A salt that does not parse is moved ASIDE (telemetry-salt.bad-<guid>,
# kept) before a new one is made - and moved back when it turns out to parse after all (another
# creator's salt that arrived in between). '' without a salt (and not -Create) or when it cannot be
# made. (wave 28c, D3) -Create makes a salt only UNDER THE TELEMETRY LOCK (Enter-TelemetryLock, at
# most $WaitMs; re-entrant for a producer that holds it) and never while -Forget deletes: '' then.
function Read-TelemetrySalt {
    param([string]$Path)
    try { if ([IO.File]::Exists($Path)) { $t = (Read-SharedText -Path $Path).Trim(); if ($t -cmatch '^[0-9a-f]{64}$') { return $t } } } catch { }
    return ''
}
function Get-TelemetryInstanceId {
    param([switch]$Create, [int]$WaitMs = 2000)
    $p = Get-TelemetryPaths
    if (-not $p) { return '' }
    $hex = Read-TelemetrySalt -Path $p.Salt
    if (-not $hex) {
        if (-not $Create) { return '' }
        $lk = Enter-TelemetryLock -WaitMs $WaitMs
        if (-not $lk.Ok) { return '' }
        try {
            $hex = Read-TelemetrySalt -Path $p.Salt
            if (-not $hex) { $hex = New-TelemetrySalt -Paths $p }
        } finally { Exit-TelemetryLock }
        if (-not $hex) { return '' }
    }
    $salt = New-Object byte[] 32
    for ($i = 0; $i -lt 32; $i++) { $salt[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    $name = $script:Utf8NoBom.GetBytes([string][Environment]::MachineName)
    $all = New-Object byte[] ($salt.Length + $name.Length)
    [Array]::Copy($salt, 0, $all, 0, $salt.Length)
    [Array]::Copy($name, 0, $all, $salt.Length, $name.Length)
    return (Get-Sha256Hex -Bytes $all)
}

# The salt's creation (the caller holds the telemetry lock): the hex salt, '' when it cannot be made.
function New-TelemetrySalt {
    param($Paths)
    $p = $Paths
    $hex = ''
    try {
        [void][IO.Directory]::CreateDirectory($p.Home)
        for ($round = 0; $round -lt 3 -and -not $hex; $round++) {
            if ([IO.File]::Exists($p.Salt)) {
                # a salt that does not parse: moved aside (never deleted), then checked - one that
                # parses after all (a racing creator's) goes back when the place is still free
                $hex = Read-TelemetrySalt -Path $p.Salt
                if ($hex) { break }
                $aside = "$($p.Salt).bad-$([guid]::NewGuid().ToString('N'))"
                try { [IO.File]::Move($p.Salt, $aside) } catch { Start-Sleep -Milliseconds 50; continue }
                if (Read-TelemetrySalt -Path $aside) {
                    try { [IO.File]::Move($aside, $p.Salt) } catch { }
                    continue
                }
            }
            $bytes = New-Object byte[] 32
            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
            $tmp = "$($p.Salt).$([guid]::NewGuid().ToString('N')).tmp"
            Write-Utf8NoBom -Path $tmp -Text ((ConvertTo-HexString $bytes) + "`n")
            # moved into place only when absent: a salt another run moved there first wins
            try { [IO.File]::Move($tmp, $p.Salt) } catch { try { [IO.File]::Delete($tmp) } catch { } }
            $hex = Read-TelemetrySalt -Path $p.Salt
        }
    } catch { return '' }
    return $hex
}

# 'windows 10.0.26200' | 'linux <major>.<minor>' | 'macos <major>.<minor>' - the family and version.
function Get-TelemetryOs {
    $ver = [Environment]::OSVersion.Version
    if ($script:OnWindows) { return "windows $($ver.Major).$($ver.Minor).$($ver.Build)" }
    if ($IsMacOS) { return "macos $($ver.Major).$($ver.Minor)" }
    return "linux $($ver.Major).$($ver.Minor)"
}

# 'powershell 5.1' (Windows PowerShell) | 'pwsh 7.x'.
function Get-TelemetryRuntime {
    $v = $PSVersionTable.PSVersion
    return "$(if ($script:LegacyPS) { 'powershell' } else { 'pwsh' }) $($v.Major).$($v.Minor)"
}

# A value of the event from a closed pattern: the value when it matches, else $Other ('' in:
# $Empty).
function Get-TelemetryToken {
    param([string]$Value, [string]$Pattern, [string]$Empty = 'unknown', [string]$Other = 'other')
    $v = ([string]$Value).Trim()
    if (-not $v) { return $Empty }
    if ($v -cmatch $Pattern) { return $v }
    return $Other
}

# A non-negative whole number of the entry, or $null.
function Get-TelemetryCount {
    param($Value)
    if ($null -eq $Value) { return $null }
    $n = [long]0
    if ([long]::TryParse([string]$Value, [System.Globalization.NumberStyles]::Integer, $script:Invariant, [ref]$n) -and $n -ge 0) { return $n }
    return $null
}

# The outcome of a committed ledger entry: { Outcome - usable | usable-after-continuation |
# failed:<class>; Severity - info (usable) | warning (a provider limit or auth failure, or the
# operator's -Kick) | error (every other failure); Class }. The class is the provider failure's
# (auth, quota, capability, transport, permission, operator, unknown), else from the outcome:
# timeout, stalled, or bridge (a failure of the bridge or the engine without a provider class).
function Get-TelemetryOutcome {
    param($Entry)
    $bo = [string](Get-PropertyValue $Entry 'bridge_outcome' '')
    if (Test-UsableOutcome $bo) {
        $o = $(if ($bo -like '*after a timeout continuation*') { 'usable-after-continuation' } else { 'usable' })
        return [pscustomobject]@{ Outcome = $o; Severity = 'info'; Class = '' }
    }
    $cls = [string](Get-PropertyValue (Get-PropertyValue $Entry 'provider_failure' $null) 'class' '')
    if (-not $cls) {
        if ($bo -like 'failed: timeout*') { $cls = 'timeout' }
        elseif ($bo -like 'failed: stalled*') { $cls = 'stalled' }
        elseif ($bo -like '*stopped by the operator*') { $cls = 'operator' }
        else { $cls = 'bridge' }
    }
    if ($script:TelemetryFailureClasses -cnotcontains $cls) { $cls = 'unknown' }
    $sev = $(if (@('auth', 'quota', 'operator') -contains $cls) { 'warning' } else { 'error' })
    return [pscustomobject]@{ Outcome = "failed:$cls"; Severity = $sev; Class = $cls }
}

# (wave 28b, D1) The vendor class of a ledger entry's reviewer ($script:TelemetryVendors): the class
# of the endpoint's HOST - the base_url the ledger recorded (reviewer.provider_config.base_url) -,
# else the engine's class (agy, muse, claude), else (codex) the built-in openai provider - else
# 'other'. (wave 29b, E6) HOST FIRST for every engine whenever provider_config names a base_url (a
# claude endpoint entry: api.z.ai -> zai), the engine row only as the fallback; a base_url of an
# unknown host is 'other'. Returns the table row, or $null ('other').
function Get-TelemetryVendor {
    param($Reviewer)
    $engine = [string](Get-PropertyValue $Reviewer 'engine' '')
    if (-not $engine) { $engine = 'codex' }
    $pc = Get-PropertyValue $Reviewer 'provider_config' $null
    $bu = [string](Get-PropertyValue $pc 'base_url' '')
    if ($bu) { return (Get-TelemetryVendorByHost $bu) }
    if ($engine -ne 'codex') { return (@($script:TelemetryVendors | Where-Object { $_.Engine -and $_.Engine -ceq $engine }) | Select-Object -First 1) }
    $bi = [string](Get-PropertyValue $pc 'builtin' '')
    if (-not $bi) { return $null }
    return (@($script:TelemetryVendors | Where-Object { $_.Builtin -and $_.Builtin -ceq $bi }) | Select-Object -First 1)
}

# (wave 29b) The vendor row of a base URL's HOST (the host equals one of a row's Hosts or ends with
# '.' + one of them), $null for any other host, an IP literal or no host.
function Get-TelemetryVendorByHost {
    param([string]$BaseUrl)
    $hostName = ([string](ConvertTo-CanonicalBaseUrl $BaseUrl).HostName).TrimEnd('.')
    if (-not $hostName -or $hostName.StartsWith('[')) { return $null }
    foreach ($v in $script:TelemetryVendors) {
        foreach ($h in @($v.Hosts)) { if ($hostName -ceq $h -or $hostName.EndsWith('.' + $h, [StringComparison]::Ordinal)) { return $v } }
    }
    return $null
}

# (wave 28b, D1; wave 28c, D1 / F42-1, F43-2) The model the event may carry: the list entry of $Vendor
# that the name EQUALS after lower-casing (the table's own text - never the operator's), else 'other';
# '' -> 'unknown'. (wave 28d, D6 / F50-1) BOTH sides are lower-cased: a table entry with an upper-case
# letter matches too.
function Get-TelemetryModelToken {
    param($Vendor, [string]$Model)
    $m = ([string]$Model).Trim().ToLowerInvariant()
    if (-not $m) { return 'unknown' }
    if (-not $Vendor) { return 'other' }
    # (wave 29) the 1M-context suffix [1m] is not part of the name - (wave 29b, E6) for every vendor
    # (a claude endpoint entry may pin glm-5.3[1m])
    $m = $m -replace '\[1m\]$', ''
    foreach ($known in @($Vendor.Models)) { if (([string]$known).ToLowerInvariant() -ceq $m) { return [string]$known } }
    return 'other'
}

# (R24) The reviewer of a ledger entry as an event may carry it - ONE code path for the consultation
# and the rating event: { engine (codex | agy | muse | claude | other); provider (the vendor class of
# Get-TelemetryVendor, else other); model (Get-TelemetryModelToken: an entry of that vendor's closed
# list, other, or unknown without a model) }. The roster label is never read.
function Get-TelemetryReviewerClass {
    param($Entry)
    $rev = Get-PropertyValue $Entry 'reviewer' $null
    $engine = [string](Get-PropertyValue $rev 'engine' 'codex')
    if ($script:EngineNames -cnotcontains $engine) { $engine = 'other' }
    $vendor = $null
    if ($engine -ne 'other') { $vendor = Get-TelemetryVendor $rev }
    $provider = $(if ($vendor) { [string]$vendor.Class } else { 'other' })
    $modelRaw = [string](Get-PropertyValue $rev 'model' '')
    if (-not $modelRaw) { $modelRaw = [string](Get-PropertyValue $Entry 'model' '') }
    return [pscustomobject]@{ engine = $engine; provider = $provider; model = (Get-TelemetryModelToken -Vendor $vendor -Model $modelRaw) }
}

# (R24) The purpose of a ledger entry as an event carries it: one of $script:ConsultPurposes, `none`
# without one, else `other`.
function Get-TelemetryPurpose {
    param($Entry)
    $purpose = [string](Get-PropertyValue $Entry 'purpose' '')
    if (-not $purpose) { return 'none' }
    if ($script:ConsultPurposes -cnotcontains $purpose) { return 'other' }
    return $purpose
}

# The event's `details` from a ledger entry - THE allowlist: every value is built here from a closed
# set, a number, a boolean or (wave 28b, D1) the vendor table (Get-TelemetryVendor,
# Get-TelemetryModelToken: the provider is a vendor class, the model (wave 28c) an entry of that
# vendor's closed list; the roster label is never read - R24: Get-TelemetryReviewerClass). Nothing
# else of the entry is read.
function ConvertTo-TelemetryDetails {
    param($Entry)
    $rc = Get-TelemetryReviewerClass $Entry
    $engine = $rc.engine
    $provider = $rc.provider
    $model = $rc.model
    $purpose = Get-TelemetryPurpose $Entry
    $usage = Get-PropertyValue $Entry 'usage' $null
    $fc = Get-PropertyValue $Entry 'findings' $null
    $fcount = { param($k) $n = Get-TelemetryCount (Get-PropertyValue $fc $k $null); if ($null -eq $n) { [long]0 } else { $n } }
    $fr = Get-PropertyValue $Entry 'format_retry' $null
    $dr = Get-PropertyValue $Entry 'denial_retry' $null
    $tc = Get-PropertyValue $Entry 'timeout_continue' $null
    $panelSize = [long]0
    $pr = Get-PropertyValue $Entry 'panel' $null
    if ($pr) { $ps = Get-TelemetryCount (Get-PropertyValue $pr 'of' $null); if ($null -ne $ps) { $panelSize = $ps } }
    $wall = Get-TelemetryCount ([Math]::Round([double](Get-PropertyValue $Entry 'wall_seconds' 0)))
    $psv = Get-TelemetryToken -Value ([string]$PSVersionTable.PSVersion) -Pattern '^[0-9][0-9A-Za-z.+-]{0,31}$'
    return [pscustomobject]@{
        engine           = $engine
        provider         = $provider
        model            = $model
        purpose          = $purpose
        outcome          = (Get-TelemetryOutcome $Entry).Outcome
        wall_seconds     = $(if ($null -eq $wall) { [long]0 } else { $wall })
        tokens           = [pscustomobject]@{
            in     = (Get-TelemetryCount (Get-PropertyValue $usage 'input_tokens' $null))
            cached = (Get-TelemetryCount (Get-PropertyValue $usage 'cached_input_tokens' $null))
            out    = (Get-TelemetryCount (Get-PropertyValue $usage 'output_tokens' $null))
        }
        findings         = [pscustomobject]@{ blocker = (& $fcount 'blocker'); major = (& $fcount 'major'); minor = (& $fcount 'minor'); note = (& $fcount 'note') }
        structured       = ((Get-PropertyValue $Entry 'structured' $false) -eq $true)
        format_retry     = [bool]($fr -and (Get-PropertyValue $fr 'attempted' $false) -eq $true)
        denial_retry     = [bool]($dr -and (Get-PropertyValue $dr 'attempted' $false) -eq $true)
        timeout_continue = [bool]($tc -and -not ([string](Get-PropertyValue $tc 'outcome' '')).StartsWith('not attempted'))
        panel_size       = $panelSize
        ps_version       = $psv
        os               = (Get-TelemetryOs)
        bridge_version   = (Get-BridgeVersion)
    }
}

# The event of one committed consultation (the intake's v2 event; the keys in
# $script:TelemetryEventKeys order). client_time is UTC (an instant, not a day). (wave 28b, D1) The
# tags carry the same two closed values as details: the vendor class and the model token.
function New-TelemetryEvent {
    param($Entry, [string]$InstanceId)
    $d = ConvertTo-TelemetryDetails $Entry
    $o = Get-TelemetryOutcome $Entry
    return [pscustomobject]@{
        app_id      = $script:TelemetryAppId
        app_version = (Get-BridgeVersion)
        instance_id = $InstanceId
        event_type  = 'consultation'
        severity    = $o.Severity
        title       = $o.Outcome
        details     = $d
        tags        = [object[]]@($d.provider, $d.model)
        client_time = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', $script:Invariant)
        os          = (Get-TelemetryOs)
        runtime     = (Get-TelemetryRuntime)
    }
}

# (R24) The whole days between the consultation's time - $ConsultWhen when it parses (a mark's
# consult_when, -BackfillRatings), else the ledger entry's `when` - and $RatedAt (now, or a mark's
# `when`): the elapsed time floored, never below 0 - 0 the same day, and 0 when no time parses.
function Get-TelemetryAgeDays {
    param($Entry, [DateTimeOffset]$RatedAt = [DateTimeOffset]::UtcNow, $ConsultWhen = $null)
    $wo = $null
    if ($null -ne $ConsultWhen -and [string]$ConsultWhen) { $wo = ConvertTo-WhenOffset $ConsultWhen }
    if ($null -eq $wo) { $wo = ConvertTo-WhenOffset (Get-PropertyValue $Entry 'when' $null) }
    if ($null -eq $wo) { return [long]0 }
    $days = [Math]::Floor(($RatedAt.UtcDateTime - $wo.UtcDateTime).TotalDays)
    if ($days -lt 0) { return [long]0 }
    return [long]$days
}

# (R24) The `details` of a RATING event (codex-findings.ps1 -Rate) - its own allowlist,
# $script:TelemetryRatingDetailKeys in that order: the reviewer and the purpose through the
# consultation event's code path (Get-TelemetryReviewerClass, Get-TelemetryPurpose - the vendor
# class and the closed-list model, never the roster label), the mark (yes | partly | no; anything
# else other), the consultation's age in whole days (Get-TelemetryAgeDays), the plugin version, the
# OS and the PowerShell version. Nothing else of the entry or the mark is read: never the note, the
# topics, the task, the consultation's id, n or lineage.
function ConvertTo-TelemetryRatingDetails {
    param($Entry, [string]$Mark, [DateTimeOffset]$RatedAt = [DateTimeOffset]::UtcNow, $ConsultWhen = $null)
    $rc = Get-TelemetryReviewerClass $Entry
    $m = ([string]$Mark).Trim().ToLowerInvariant()
    if ($script:TelemetryRatingMarks -cnotcontains $m) { $m = 'other' }
    return [pscustomobject]@{
        engine         = $rc.engine
        provider       = $rc.provider
        model          = $rc.model
        purpose        = (Get-TelemetryPurpose $Entry)
        mark           = $m
        age_days       = (Get-TelemetryAgeDays -Entry $Entry -RatedAt $RatedAt -ConsultWhen $ConsultWhen)
        bridge_version = (Get-BridgeVersion)
        os             = (Get-TelemetryOs)
        ps_version     = (Get-TelemetryToken -Value ([string]$PSVersionTable.PSVersion) -Pattern '^[0-9][0-9A-Za-z.+-]{0,31}$')
    }
}

# (R24) The event of one rating (the judge's mark of a consultation, codex-findings.ps1 -Rate): the
# top level exactly as a consultation event's ($script:TelemetryEventKeys order), event_type rating,
# severity info, the mark as its title, tags [provider, model]. -RatedAt (a DateTimeOffset; null:
# now) is when the mark was given - client_time and the age are taken from it; -ConsultWhen the
# consultation's time as the mark recorded it (Get-TelemetryAgeDays) - both for
# codex-telemetry.ps1 -BackfillRatings, which sends marks given earlier.
function New-TelemetryRatingEvent {
    param($Entry, [string]$Mark, [string]$InstanceId, $RatedAt = $null, $ConsultWhen = $null)
    $at = $(if ($null -ne $RatedAt) { [DateTimeOffset]$RatedAt } else { [DateTimeOffset]::UtcNow })
    $d = ConvertTo-TelemetryRatingDetails -Entry $Entry -Mark $Mark -RatedAt $at -ConsultWhen $ConsultWhen
    return [pscustomobject]@{
        app_id      = $script:TelemetryAppId
        app_version = (Get-BridgeVersion)
        instance_id = $InstanceId
        event_type  = 'rating'
        severity    = 'info'
        title       = $d.mark
        details     = $d
        tags        = [object[]]@($d.provider, $d.model)
        client_time = $at.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ', $script:Invariant)
        os          = (Get-TelemetryOs)
        runtime     = (Get-TelemetryRuntime)
    }
}

# Opens a spool file EXCLUSIVELY (FileShare.None), retrying for $WaitMs (about 2 s; the bridge's
# append 5 s - wave 28b, D6); $null when it does not exist ($Mode Open) or stays busy.
function Open-TelemetrySpoolFile {
    param([string]$Path, [System.IO.FileMode]$Mode = [System.IO.FileMode]::Open, [int]$WaitMs = 2000)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($Mode -eq [System.IO.FileMode]::Open -and -not [IO.File]::Exists($Path)) { return $null }
        try { return (New-Object System.IO.FileStream($Path, $Mode, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)) } catch {
            if ($watch.ElapsedMilliseconds -ge $WaitMs) { return $null }
            Start-Sleep -Milliseconds 50
        }
    }
}

# (wave 28b, D16) The spool file of a moment: <yyyy-MM-dd>.ndjson of its LOCAL date (as the engines
# name their session directories), invariant digits.
function Get-TelemetrySpoolName {
    param([datetime]$At = (Get-Date))
    $local = $(if ($At.Kind -eq [DateTimeKind]::Utc) { $At.ToLocalTime() } else { $At })
    return ($local.ToString('yyyy-MM-dd', $script:Invariant) + '.ndjson')
}

# The non-empty lines of an open spool file (UTF-8), from its start.
function Read-TelemetryStreamLines {
    param($Stream)
    $Stream.Position = 0
    $sr = New-Object System.IO.StreamReader($Stream, $script:Utf8NoBom, $false, 4096, $true)
    try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
    return , ([string[]]@($text -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ }))
}

# Appends ONE line to today's spool file (the LOCAL date - D16): {v, kind, queued_unix, body}.
# (wave 28c, D3) Under the telemetry lock (Enter-TelemetryLock - re-entrant; the forgetting marker
# refuses); the lock and the file's exclusive open share $WaitMs. '' when written, else why not
# (never throws).
function Add-TelemetrySpoolLine {
    param([string]$Kind, [string]$BodyJson, [int]$WaitMs = $script:TelemetrySpoolWaitMs)
    $held = $false
    try {
        $p = Get-TelemetryPaths
        if (-not $p) { return 'no codex home (CODEX_HOME, else ~/.codex)' }
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $lk = Enter-TelemetryLock -WaitMs $WaitMs
        if (-not $lk.Ok) { return $lk.Why }
        $held = $true
        [void][IO.Directory]::CreateDirectory($p.Spool)
        $line = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ v = 1; kind = $Kind; queued_unix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); body = $BodyJson })
        $file = Join-Path $p.Spool (Get-TelemetrySpoolName)
        $fileWait = [int][Math]::Max(50, $WaitMs - $watch.ElapsedMilliseconds)
        $fs = Open-TelemetrySpoolFile -Path $file -Mode ([System.IO.FileMode]::OpenOrCreate) -WaitMs $fileWait
        if (-not $fs) { return "the spool file '$file' stayed busy for $([Math]::Round($WaitMs / 1000.0, 1)) s" }
        try {
            [void]$fs.Seek(0, [System.IO.SeekOrigin]::End)
            $bytes = $script:Utf8NoBom.GetBytes($line + "`n")
            $fs.Write($bytes, 0, $bytes.Length)
            $fs.Flush()
        } finally { $fs.Dispose() }
        return ''
    } catch { return (ConvertTo-OneLine $_.Exception.Message) } finally { if ($held) { Exit-TelemetryLock } }
}

# One spool line parsed: { Line; Kind; Queued (unix s); Body (the JSON text) }, or $null when it is
# not a spool line.
function ConvertFrom-TelemetrySpoolLine {
    param([string]$Line)
    try { $o = ConvertFrom-Json -InputObject $Line } catch { return $null }
    if (-not (Test-IsJsonObject $o)) { return $null }
    $kind = [string](Get-PropertyValue $o 'kind' '')
    $body = Get-PropertyValue $o 'body' $null
    $q = Get-TelemetryCount (Get-PropertyValue $o 'queued_unix' $null)
    if (@('event', 'complaint') -cnotcontains $kind -or -not ($body -is [string]) -or -not $body -or $null -eq $q) { return $null }
    return [pscustomobject]@{ Line = $Line; Kind = $kind; Queued = $q; Body = [string]$body }
}

# (wave 28b, D3 / F36-3) THE sender's environment: an ALLOW list, never a scrub list - the system
# variables a PowerShell process needs, the locale and proxy variables, PowerShell's own telemetry
# opt-out, CODEX_HOME, CODEX_CONSULT_TELEMETRY and CODEX_CONSULT_TELEMETRY_URL; (D10) in test mode
# also CODEX_CONSULT_TEST_MODE and the sender's own hooks CODEX_CONSULT_TEST_TELEMETRY_* - no
# provider key, no host marker, no other CODEX_CONSULT_* variable. Names compared case-insensitively:
# (wave 28c, D6 / F41-1, F42-9) the proxy variables pass in both cases (http_proxy and HTTP_PROXY ...;
# outside Windows, where the environment is case-sensitive, both spellings are kept), and so do the
# trust inputs of a private CA (SSL_CERT_FILE, SSL_CERT_DIR, REQUESTS_CA_BUNDLE, CURL_CA_BUNDLE,
# NODE_EXTRA_CA_CERTS). README "Telemetry (on by default)" lists the whole allow list.
$script:TelemetrySenderEnvNames = @(
    'SystemRoot', 'windir', 'SystemDrive', 'ComSpec', 'PATH', 'PATHEXT', 'TEMP', 'TMP', 'TMPDIR',
    'USERPROFILE', 'HOME', 'HOMEDRIVE', 'HOMEPATH', 'APPDATA', 'LOCALAPPDATA', 'ProgramData', 'ALLUSERSPROFILE', 'PSModulePath',
    'PROCESSOR_ARCHITECTURE', 'NUMBER_OF_PROCESSORS', 'OS', 'LANG', 'LANGUAGE', 'TZ',
    'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'ALL_PROXY',
    'SSL_CERT_FILE', 'SSL_CERT_DIR', 'REQUESTS_CA_BUNDLE', 'CURL_CA_BUNDLE', 'NODE_EXTRA_CA_CERTS',
    'POWERSHELL_TELEMETRY_OPTOUT', 'POWERSHELL_UPDATECHECK',
    'CODEX_HOME', 'CODEX_CONSULT_TELEMETRY', 'CODEX_CONSULT_TELEMETRY_URL'
)
$script:TelemetrySenderEnvPrefixes = @('ProgramFiles', 'CommonProgramFiles', 'ProgramW6432', 'CommonProgramW6432', 'LC_')

# Whether a variable may reach the sender (see above).
function Test-TelemetrySenderEnvName {
    param([string]$Name, [bool]$TestMode = $false)
    $u = ([string]$Name).ToUpperInvariant()
    foreach ($n in $script:TelemetrySenderEnvNames) { if ($u -ceq $n.ToUpperInvariant()) { return $true } }
    foreach ($p in $script:TelemetrySenderEnvPrefixes) { if ($u.StartsWith($p.ToUpperInvariant(), [StringComparison]::Ordinal)) { return $true } }
    if ($TestMode -and ($u -ceq 'CODEX_CONSULT_TEST_MODE' -or $u.StartsWith('CODEX_CONSULT_TEST_TELEMETRY_', [StringComparison]::Ordinal))) { return $true }
    return $false
}

# The sender's environment: the allowed variables of THIS process (name -> value, sorted ordinal
# ignoring case on Windows; (wave 28c, D6) ordinal elsewhere, where http_proxy and HTTP_PROXY are two
# variables and both pass). Read-only: this process's environment is never changed for it.
function Get-TelemetrySenderEnvironment {
    $tm = Test-TestMode
    $cmp = $(if ($script:OnWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal })
    $out = New-Object 'System.Collections.Generic.SortedDictionary[string,string]' ($cmp)
    $all = [Environment]::GetEnvironmentVariables()
    foreach ($k in @($all.Keys)) {
        $n = [string]$k
        if (-not $n -or $out.ContainsKey($n)) { continue }
        if (Test-TelemetrySenderEnvName -Name $n -TestMode $tm) { $out[$n] = [string]$all[$k] }
    }
    # the sender flushes the spool THIS bridge writes: its codex home, named even when it was derived
    if (-not $out.ContainsKey('CODEX_HOME')) { $ch = [string](Get-CodexHome); if ($ch) { $out['CODEX_HOME'] = $ch } }
    return $out
}

# (wave 28b, D3) The sender's ProcessStartInfo: its environment block CLEARED, then filled from the
# allow list (Get-TelemetrySenderEnvironment); hidden, in the temp directory. Windows: this host
# -NoProfile -ExecutionPolicy Bypass -File codex-telemetry.ps1 -Flush -Telemetry on; elsewhere:
# /bin/sh -c 'exec nohup <host> -NoProfile -File ... </dev/null >/dev/null 2>&1'.
function New-TelemetrySenderStartInfo {
    param([string]$Script, [string]$HostExe)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = [IO.Path]::GetTempPath()
    if ($script:OnWindows) {
        $psi.FileName = $HostExe
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File ' + (ConvertTo-ProcArg $Script) + ' -Flush -Telemetry on'
    } else {
        $q = { param([string]$s) "'" + $s.Replace("'", "'\''") + "'" }
        $psi.FileName = '/bin/sh'
        [void]$psi.ArgumentList.Add('-c')
        [void]$psi.ArgumentList.Add('exec nohup ' + (& $q $HostExe) + ' -NoProfile -File ' + (& $q $Script) + ' -Flush -Telemetry on </dev/null >/dev/null 2>&1')
    }
    $block = $psi.EnvironmentVariables
    $block.Clear()
    $senderEnv = Get-TelemetrySenderEnvironment
    foreach ($k in @($senderEnv.Keys)) { $block[[string]$k] = [string]$senderEnv[$k] }
    return $psi
}

# (wave 28b, D3) Windows: CreateProcessW with bInheritHandles = FALSE, the start info's environment
# block and CREATE_NO_WINDOW - so the sender inherits NO handle of this process (a caller reading
# the bridge's output is not held open by it) and gets exactly the allow-listed environment
# (.NET's Process.Start inherits every inheritable handle; ShellExecute cannot take an environment).
# Compiled once per process on first use (Add-Type). Returns the pid; throws when it cannot start.
function Start-NoInheritProcess {
    param($StartInfo, $Environment = $null)
    if (-not ('CodexConsultSpawn' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
public static class CodexConsultSpawn {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX; public int dwY; public int dwXSize; public int dwYSize; public int dwXCountChars;
        public int dwYCountChars; public int dwFillAttribute; public int dwFlags; public short wShowWindow;
        public short cbReserved2; public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr h);
    public static int Start(string app, string commandLine, string dir, string[] names, string[] values) {
        List<KeyValuePair<string, string>> pairs = new List<KeyValuePair<string, string>>();
        for (int i = 0; i < names.Length; i++) { pairs.Add(new KeyValuePair<string, string>(names[i], values[i])); }
        pairs.Sort(delegate (KeyValuePair<string, string> a, KeyValuePair<string, string> b) { return string.CompareOrdinal(a.Key.ToUpperInvariant(), b.Key.ToUpperInvariant()); });
        StringBuilder block = new StringBuilder();
        foreach (KeyValuePair<string, string> p in pairs) { block.Append(p.Key).Append('=').Append(p.Value).Append('\0'); }
        block.Append('\0');
        IntPtr env = Marshal.StringToHGlobalUni(block.ToString());
        try {
            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            si.dwFlags = 1;
            si.wShowWindow = 0;
            PROCESS_INFORMATION pi;
            uint flags = 0x00000400 | 0x08000000 | 0x00000200;
            if (!CreateProcessW(app, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero, false, flags, env, dir, ref si, out pi)) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
            return pi.dwProcessId;
        } finally { Marshal.FreeHGlobal(env); }
    }
}
'@
    }
    # (the names as $Environment spells them: .NET Framework's StringDictionary lowercases its keys)
    $names = New-Object System.Collections.Generic.List[string]
    $values = New-Object System.Collections.Generic.List[string]
    $src = $(if ($null -ne $Environment) { $Environment } else { $StartInfo.EnvironmentVariables })
    foreach ($k in @($src.Keys)) { $names.Add([string]$k); $values.Add([string]$src[$k]) }
    $cmd = (ConvertTo-ProcArg $StartInfo.FileName) + ' ' + $StartInfo.Arguments
    return [CodexConsultSpawn]::Start($StartInfo.FileName, $cmd, $StartInfo.WorkingDirectory, $names.ToArray(), $values.ToArray())
}

# Starts THE detached sender (New-TelemetrySenderStartInfo: the allow-listed environment only - no
# host marker, no key, wave 28b D3), hidden, in the temp directory; never waited for. Windows:
# Start-NoInheritProcess (no handle of this process is inherited, the caller's pipes close when the
# bridge exits); elsewhere Process.Start of /bin/sh ... nohup. '' when started, else why not.
function Start-TelemetrySender {
    $self = Join-Path $PSScriptRoot 'codex-telemetry.ps1'
    if (-not [IO.File]::Exists($self)) { return "'$self' does not exist" }
    try {
        $hostExe = (Get-Process -Id $PID).Path
        $psi = New-TelemetrySenderStartInfo -Script $self -HostExe $hostExe
        if ($script:OnWindows) { $null = Start-NoInheritProcess -StartInfo $psi -Environment (Get-TelemetrySenderEnvironment) }
        else { $null = [System.Diagnostics.Process]::Start($psi) }
        return ''
    } catch {
        return (ConvertTo-OneLine $_.Exception.Message)
    }
}

# (wave 28b, D6) An event that could not be spooled: one line {time, why} - codex-telemetry.ps1 -Status
# counts them. (wave 28d, D4 / F49-2) APPEND-ONLY and written WITHOUT the telemetry lock (a busy lock or
# a -Forget in flight never loses a count). (wave 28e, E2 / F54-2) ONE FILE PER PRODUCER PROCESS:
# <codex home>/telemetry-not-spooled-<pid>-<start ticks>.ndjson (NotSpooledOwn) - no other process
# appends to it, so no append waits for another producer's; the retry (up to 1 s) only covers a reader
# of this very file. A flush folds the files of producers that are gone into one line of <spool>/.last
# and removes them (Merge-TelemetryNotSpooled), so no file grows past what one process wrote. '' when
# the line is written, else why not (best effort: the callers carry on).
function Add-TelemetryNotSpooled {
    param([string]$Why)
    $p = Get-TelemetryPaths
    if (-not $p) { return 'no codex home (CODEX_HOME, else ~/.codex)' }
    $line = (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ time = (Get-IsoTimestamp); why = (ConvertTo-OneLine $Why) })) + "`n"
    $err = ''
    for ($i = 0; $i -lt 20; $i++) {
        try { [void][IO.Directory]::CreateDirectory($p.Home); [IO.File]::AppendAllText($p.NotSpooledOwn, $line, $script:Utf8NoBom); return '' } catch { $err = ConvertTo-OneLine $_.Exception.Message; Start-Sleep -Milliseconds 50 }
    }
    return "the not-spooled count $($p.NotSpooledOwn) could not be written ($err)"
}

# (wave 28e, E2) The not-spooled files of the codex home: the producers' files
# telemetry-not-spooled-<pid>-<start ticks>.ndjson and the legacy single file
# telemetry-not-spooled.ndjson (written before wave 28e) - (E26 / F32-2) and the legacy file's STAGED
# generations telemetry-not-spooled-legacy-<utc ticks>.ndjson (a flush renames the legacy file to such a
# unique name before it counts it; no producer writes to one). [object[]] of { Path; Name; Pid (0: legacy
# or staged); Ticks; Legacy; Staged }, sorted by name. Another name that starts the same way is not one of
# them.
function Get-TelemetryNotSpooledFiles {
    param($Paths = $null)
    $p = $(if ($Paths) { $Paths } else { Get-TelemetryPaths })
    $out = New-Object System.Collections.Generic.List[object]
    if (-not $p -or -not [IO.Directory]::Exists($p.Home)) { return , ([object[]]@()) }
    foreach ($f in @(Get-ChildItem -LiteralPath $p.Home -File -Force -Filter 'telemetry-not-spooled*.ndjson' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ($f.Name -eq 'telemetry-not-spooled.ndjson') { $out.Add([pscustomobject]@{ Path = $f.FullName; Name = $f.Name; Pid = 0; Ticks = [long]0; Legacy = $true; Staged = $false }); continue }
        $ms = [regex]::Match($f.Name, '^telemetry-not-spooled-legacy-([0-9]{1,19})\.ndjson$')
        if ($ms.Success) {
            $st = [long]0
            if ([long]::TryParse($ms.Groups[1].Value, [ref]$st)) { $out.Add([pscustomobject]@{ Path = $f.FullName; Name = $f.Name; Pid = 0; Ticks = $st; Legacy = $false; Staged = $true }) }
            continue
        }
        $m = [regex]::Match($f.Name, '^telemetry-not-spooled-([0-9]{1,10})-([0-9]{1,19})\.ndjson$')
        if (-not $m.Success) { continue }
        $fp = [long]0
        $ft = [long]0
        if (-not [long]::TryParse($m.Groups[1].Value, [ref]$fp) -or $fp -gt [int]::MaxValue -or -not [long]::TryParse($m.Groups[2].Value, [ref]$ft)) { continue }
        $out.Add([pscustomobject]@{ Path = $f.FullName; Name = $f.Name; Pid = [int]$fp; Ticks = $ft; Legacy = $false; Staged = $false })
    }
    return , ([object[]]$out.ToArray())
}

# (wave 28e, E2) The lines of a not-spooled text: complete lines only (an append in progress has no line
# end yet); -Tail: a last piece without one counts too (the file of a producer that is gone - it will
# never end it).
function Get-TelemetryNotSpooledLines {
    param([string]$Text, [switch]$Tail)
    $t = [string]$Text
    if (-not $Tail) { $end = $t.LastIndexOf("`n"); $t = $(if ($end -ge 0) { $t.Substring(0, $end) } else { '' }) }
    return , ([string[]]@($t -split "`n" | Where-Object { $_.Trim() }))
}

# (wave 28e, E24 / F30-2) The `not_spooled_folded[]` of a .last record as a map name -> bytes: each entry
# {name, bytes} names a file a fold counted and the length it had then (its lines up to there are in a
# fold's note); a bare name (the E20 build before E24) maps to -1 - counted whole. Case-insensitive, as
# the file names are on Windows.
function Get-TelemetryFoldedMap {
    param($Last)
    $m = @{}
    foreach ($e in @(Get-PropertyValue $Last 'not_spooled_folded' @())) {
        if ($null -eq $e) { continue }
        if ($e -is [string]) { if ($e) { $m[$e] = [long]-1 }; continue }
        $n = [string](Get-PropertyValue $e 'name' '')
        if (-not $n) { continue }
        $b = [long]-1
        [void][long]::TryParse([string](Get-PropertyValue $e 'bytes' ''), [ref]$b)
        $m[$n] = $b
    }
    return $m
}

# (wave 28e, E24 / F30-2) The text of a shared file from byte $Offset on (UTF-8): $null when the file is
# shorter than $Offset (another file under that name) or cannot be read.
function Read-SharedTextFrom {
    param([string]$Path, [long]$Offset)
    try {
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        try {
            if ($fs.Length -lt $Offset) { return $null }
            [void]$fs.Seek($Offset, [System.IO.SeekOrigin]::Begin)
            $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $false, 4096, $true)
            try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
        } finally { $fs.Dispose() }
    } catch { return $null }
}

# The events not spooled since the last flush - (wave 28e, E2) the complete lines of EVERY not-spooled
# file (Get-TelemetryNotSpooledFiles: one per producer, and the legacy file), summed, less the
# `not_spooled_seen` of <spool>/.last (the lines of the files that flush KEPT after its fold - the
# folded files are gone with their lines; an older .last's count of the legacy file means the same);
# every line when no flush recorded one. { Count; Last (the latest why by time, '' when none since the
# last flush); When; Total (every line of every file); Files }. -All: every line counts.
# (wave 28e, E20 / F27-3; E24 / F30-2) A file that .last `not_spooled_folded[]` names counts only its
# complete lines BEYOND the bytes recorded there (those are in a fold's note already - a flush that saved
# .last but did not get to delete it; an older bridge may have appended since); one shorter than that is
# another file under that name and counts whole; a bare name (bytes unknown) counts nothing. (E26 /
# F32-2) The legacy file telemetry-not-spooled.ndjson counts WHOLE, always - a fold never counts it under
# its own name (it stages it first), so no entry ever covers it (one an earlier build wrote is ignored).
# LegacyLines: its complete lines (part of Total; the flush without the telemetry lock leaves them out
# of not_spooled_seen).
function Get-TelemetryNotSpooled {
    param([switch]$All)
    $r = [pscustomobject]@{ Count = 0; Last = ''; When = ''; Total = 0; Files = 0; LegacyLines = 0 }
    $p = Get-TelemetryPaths
    if (-not $p) { return $r }
    $files = Get-TelemetryNotSpooledFiles -Paths $p
    if ($files.Count -eq 0) { return $r }
    $lastRec = Read-TelemetryLast
    $folded = Get-TelemetryFoldedMap -Last $lastRec
    $seen = [long]0
    if (-not $All) { $sv = Get-TelemetryCount (Get-PropertyValue $lastRec 'not_spooled_seen' $null); if ($null -ne $sv) { $seen = [long]$sv } }
    $latest = $null
    foreach ($f in $files) {
        try {
            $text = $null
            if (-not $f.Legacy -and $folded.ContainsKey($f.Name)) {
                $b = [long]$folded[$f.Name]
                if ($b -lt 0) { continue }
                $text = Read-SharedTextFrom -Path $f.Path -Offset $b
            }
            $named = ($null -ne $text)
            if ($null -eq $text) { $text = [string](Read-SharedText -Path $f.Path) }
            $lines = Get-TelemetryNotSpooledLines -Text $text
            # a named file with nothing beyond its recorded bytes is accounted for: not one of the files
            if ($named -and $lines.Count -eq 0) { continue }
            $r.Files++
            $r.Total += $lines.Count
            if ($f.Legacy) { $r.LegacyLines += $lines.Count }
            foreach ($l in $lines) {
                try {
                    $o = ConvertFrom-Json -InputObject $l
                    $w = ConvertTo-WhenOffset (Get-PropertyValue $o 'time' $null)
                    if ($null -eq $latest -or ($null -ne $w -and ($null -eq $latest.At -or $w -ge $latest.At))) { $latest = [pscustomobject]@{ At = $w; Why = [string](Get-PropertyValue $o 'why' ''); When = [string](ConvertTo-JsonText (Get-PropertyValue $o 'time' '')) } }
                } catch { }
            }
        } catch { }
    }
    $r.Count = [int][Math]::Max([long]0, [long]$r.Total - $seen)
    if ($r.Count -gt 0 -and $latest) { $r.Last = $latest.Why; $r.When = $latest.When }
    return $r
}

# (wave 28e, E2 / F54-2, F53-1) The flush's fold, UNDER the telemetry lock: every not-spooled file whose
# producer is gone (Get-PidIdentityTicks 'gone': no process with its pid, or one with another start) -
# and the legacy single file, whose writers are older bridges - is read under an exclusive handle that
# still lets it be deleted (an appender meanwhile waits and then starts the file anew: nothing is
# lost) and its lines counted (a last piece without a line end too: its producer will never end it).
# A producer that lives - or whose identity cannot be confirmed - keeps its file.
# (wave 28e, E20 / F27-3) NOTHING is deleted here: the flush first saves .last - the fold's note, the new
# `not_spooled_seen` and `not_spooled_folded[]` - and only after that save deletes the files under the
# handles kept open (Complete-TelemetryNotSpooledFold): a crash or a failed save never loses their count.
# (E26 / F32-2) The legacy file telemetry-not-spooled.ndjson - the one name older bridges append to and
# recreate - is never counted or deleted under its own name: before anything is counted it is RENAMED
# (one atomic [IO.File]::Move) to a unique staged name telemetry-not-spooled-legacy-<utc ticks>.ndjson,
# which no producer writes to and which never recurs, so {name, bytes} identifies that generation
# exactly; an older bridge that recreates the legacy name afterwards writes a NEW generation the next fold
# stages again. A rename that keeps failing (a writer holds the file; retried for about 1 s) skips the
# legacy file this flush - neither counted nor seen - with a note (Note). A staged file is folded like a
# gone producer's.
# (E24 / F30-2) `not_spooled_folded[]` holds {name, bytes} - the length each file had when it was counted
# (under its handle: nothing appended meanwhile). A file that $AlreadyFolded (Get-TelemetryFoldedMap of the
# .last before) names was counted by an earlier flush that did not get to delete it: of the SAME length -
# held for its delete, not counted again; LONGER (an older bridge appended to the legacy file after the
# crash) - its complete lines beyond the recorded bytes are counted as new (one more producer folded), then
# deleted; SHORTER - another file under that name: folded afresh; a bare name (bytes unknown) - deleted
# without counting; one that cannot be opened stays named, never counted as kept. A name whose file is
# gone simply leaves the list.
# { Lines (the lines folded now); Producers (the files folded now); Seen (the complete lines of the files
# kept - the flush's `not_spooled_seen`); Folded (a list of {name, bytes}: every file this fold covers -
# the new `not_spooled_folded`); Open (the handles held: { Path; Name; Stream }); Home; Note ('' or why
# the legacy file was not staged) }. Never throws; Complete-TelemetryNotSpooledFold closes the handles.
function Merge-TelemetryNotSpooled {
    param($Paths = $null, $AlreadyFolded = $null)
    $r = [pscustomobject]@{ Lines = 0; Producers = 0; Seen = 0; Folded = (New-Object System.Collections.Generic.List[object]); Open = (New-Object System.Collections.Generic.List[object]); Home = ''; Note = '' }
    $p = $(if ($Paths) { $Paths } else { Get-TelemetryPaths })
    if (-not $p) { return $r }
    $r.Home = [string]$p.Home
    $before = $(if ($AlreadyFolded -is [hashtable]) { $AlreadyFolded } else { @{} })
    # (E26) the legacy file staged under a unique name first
    $legacyPath = Join-Path $p.Home 'telemetry-not-spooled.ndjson'
    if ([IO.File]::Exists($legacyPath)) {
        $ticks = [DateTime]::UtcNow.Ticks
        while ([IO.File]::Exists((Join-Path $p.Home "telemetry-not-spooled-legacy-$ticks.ndjson"))) { $ticks++ }
        $stagedPath = Join-Path $p.Home "telemetry-not-spooled-legacy-$ticks.ndjson"
        $moveErr = ''
        $moved = $false
        for ($i = 0; $i -lt 10 -and -not $moved; $i++) {
            try { [IO.File]::Move($legacyPath, $stagedPath); $moved = $true } catch { $moveErr = ConvertTo-OneLine $_.Exception.Message; Start-Sleep -Milliseconds 100 }
        }
        if (-not $moved -and [IO.File]::Exists($legacyPath)) { $r.Note = "the legacy not-spooled file $legacyPath could not be staged ($moveErr) - not folded this flush" }
    }
    foreach ($f in (Get-TelemetryNotSpooledFiles -Paths $p)) {
        try {
            # (E26) the legacy file itself is never counted (nor seen): staged above, or busy - next flush
            if ($f.Legacy) { continue }
            $rec = $null
            if ($before.ContainsKey($f.Name)) { $rec = [long]$before[$f.Name] }
            $gone = ($null -ne $rec) -or $f.Staged -or ((Get-PidIdentityTicks -ProcessId $f.Pid -StartTicks $f.Ticks) -eq 'gone')
            if ($gone) {
                $fs = $null
                try { $fs = New-Object System.IO.FileStream($f.Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Delete) } catch { $fs = $null }
                if ($fs) {
                    $n = -1
                    $len = [long]-1
                    $earlier = $false
                    try {
                        $len = [long]$fs.Length
                        if ($null -ne $rec -and ($rec -lt 0 -or $len -ge $rec)) {
                            # counted up to $rec bytes by an earlier fold: only the complete lines beyond are new
                            $earlier = $true
                            $n = 0
                            if ($rec -ge 0 -and $len -gt $rec) {
                                [void]$fs.Seek($rec, [System.IO.SeekOrigin]::Begin)
                                $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $false, 4096, $true)
                                try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
                                $n = (Get-TelemetryNotSpooledLines -Text $text).Count
                            }
                        } else {
                            $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $false, 4096, $true)
                            try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
                            $n = (Get-TelemetryNotSpooledLines -Text $text -Tail).Count
                        }
                    } catch { $n = -1 }
                    if ($n -ge 0) {
                        $r.Open.Add([pscustomobject]@{ Path = $f.Path; Name = $f.Name; Stream = $fs })
                        $r.Folded.Add([pscustomobject]@{ name = $f.Name; bytes = $len })
                        if (-not $earlier -or $n -gt 0) { $r.Lines += $n; $r.Producers++ }
                        continue
                    }
                    $fs.Dispose()
                }
                if ($null -ne $rec) { $r.Folded.Add([pscustomobject]@{ name = $f.Name; bytes = $rec }); continue }
            }
            $r.Seen += (Get-TelemetryNotSpooledLines -Text ([string](Read-SharedText -Path $f.Path))).Count
        } catch { }
    }
    return $r
}

# (wave 28e, E20 / F27-3) The end of a fold (Merge-TelemetryNotSpooled): -Delete - ONLY after .last was
# saved - deletes every file the fold holds open (under its handle: nothing appends meanwhile); then every
# handle is closed (without -Delete: closed only, every file stays). The entries {name, bytes} of the fold
# whose file is still there afterwards (object[]) - .last goes on naming them. Never throws.
function Complete-TelemetryNotSpooledFold {
    param($Fold, [switch]$Delete)
    if (-not $Fold) { return , ([object[]]@()) }
    # (.ToArray(), never @(): Windows PowerShell 5.1 fails "argument types do not match" on @() of a
    # List[object] held in a property)
    foreach ($o in $Fold.Open.ToArray()) {
        try { if ($Delete) { [IO.File]::Delete($o.Path) } } catch { } finally { try { $o.Stream.Dispose() } catch { } }
    }
    $left = New-Object System.Collections.Generic.List[object]
    foreach ($e in $Fold.Folded.ToArray()) { if (-not $Fold.Home -or [IO.File]::Exists((Join-Path $Fold.Home ([string]$e.name)))) { $left.Add($e) } }
    return , ([object[]]$left.ToArray())
}

# (wave 28b, D6; wave 28c, D3, D7 / F42-3, F43-4) The bridge's spool append of the event of $Entry -
# the entry as it is committed. Everything under the telemetry lock (Enter-TelemetryLock): the
# forgetting marker checked, the salt read or created, the event built, the line appended - the lock
# and the spool file's exclusive open share $WaitMs. The ledger commit calls it INSIDE the task's
# write lock with 1 s; when that fails the run calls it again AFTER the write lock is released, with
# 5 s and -Count - only then is the event counted as not spooled (Add-TelemetryNotSpooled) and the
# run warns (the console, a detached run's status record). An event met by the forgetting marker is
# dropped at once (no retry; the caller counts it after the write lock). { Why ('' when spooled or
# telemetry off); Forgetting }. Never throws. (R24) -RatingMark yes|partly|no: the event is the
# RATING event of $Entry (New-TelemetryRatingEvent - codex-findings.ps1 -Rate at the mark's commit,
# codex-telemetry.ps1 -BackfillRatings with the mark's -RatedAt and -ConsultWhen), else the
# consultation event.
function Add-TelemetryEvent {
    param($Entry, $Switch, [int]$WaitMs = 1000, [switch]$Count, [string]$RatingMark = '', $RatedAt = $null, $ConsultWhen = $null)
    $r = [pscustomobject]@{ Why = ''; Forgetting = $false }
    if (-not $Switch -or -not $Switch.On) { return $r }
    $held = $false
    try {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $lk = Enter-TelemetryLock -WaitMs $WaitMs
        if (-not $lk.Ok) { $r.Why = $lk.Why; $r.Forgetting = $lk.Forgetting }
        else {
            $held = $true
            $id = Get-TelemetryInstanceId -Create
            if (-not $id) { $r.Why = 'no instance id (the salt could not be created)' }
            else {
                $ev = $(if ($RatingMark) { New-TelemetryRatingEvent -Entry $Entry -Mark $RatingMark -InstanceId $id -RatedAt $RatedAt -ConsultWhen $ConsultWhen } else { New-TelemetryEvent -Entry $Entry -InstanceId $id })
                $r.Why = Add-TelemetrySpoolLine -Kind 'event' -BodyJson (ConvertTo-Json -Compress -Depth 6 -InputObject $ev) -WaitMs ([int][Math]::Max(50, $WaitMs - $watch.ElapsedMilliseconds))
            }
        }
    } catch { $r.Why = ConvertTo-OneLine $_.Exception.Message } finally { if ($held) { Exit-TelemetryLock } }
    # (wave 28e, E2) a count that could not be written is said with the event's why
    if ($r.Why -and $Count) { try { $nsWhy = Add-TelemetryNotSpooled -Why $r.Why; if ($nsWhy) { $r.Why += "; $nsWhy" } } catch { } }
    return $r
}

# The spool and the sender in one call (Add-TelemetryEvent with 5 s, then - unless -NoSender -
# Start-TelemetrySender): '' when done, else why not. Never throws.
function Submit-TelemetryEvent {
    param($Entry, $Switch, [switch]$NoSender)
    if (-not $Switch -or -not $Switch.On) { return '' }
    $why = (Add-TelemetryEvent -Entry $Entry -Switch $Switch -WaitMs $script:TelemetrySpoolWaitMs -Count).Why
    if ($why) { return $why }
    if (-not $NoSender) { $why = Start-TelemetrySender }
    return $why
}

# The first run after an install (no marker <codex home>/telemetry-notice-<plugin version>) prints
# the five-line notice once and writes the marker - only while telemetry is on (off: nothing is
# printed or written).
function Show-TelemetryNotice {
    param($Switch)
    if (-not $Switch -or -not $Switch.On) { return }
    $p = Get-TelemetryPaths
    if (-not $p -or [IO.File]::Exists($p.Notice)) { return }
    $u = Get-TelemetryUrl
    $where = $(if ($u.Base) { $u.Base } else { $script:TelemetryDefaultUrl })
    Write-Host "codex-consult: telemetry is ON (this notice is shown once per version): after each consultation ONE anonymised event goes to the maintainer's intake ($where) - engine, the vendor class of the endpoint and the model name from a closed table (else 'other'), purpose, outcome class, wall seconds, token and finding counts, PowerShell version, OS, plugin version, a salted instance id." -ForegroundColor Yellow
    Write-Host "codex-consult: never sent - task names, briefs, prompts, replies, finding texts, paths, thread ids, keys, provider labels, user names, the machine name." -ForegroundColor Yellow
    Write-Host "codex-consult: switch it off with CODEX_CONSULT_TELEMETRY=off (one run: -Telemetry off); events wait in $($p.Spool) and a background sender delivers them - never blocking a consultation." -ForegroundColor Yellow
    Write-Host "codex-consult: complain or suggest: codex-consult.ps1 -Task <task> -Complain ""<text>"" (prints the exact payload and asks before sending); state: codex-telemetry.ps1 -Status." -ForegroundColor Yellow
    Write-Host "codex-consult: installing this plugin means accepting these terms - README, section ""Telemetry (on by default)"", says what is sent and how to delete your data (codex-telemetry.ps1 -Forget)." -ForegroundColor Yellow
    try {
        [void][IO.Directory]::CreateDirectory($p.Home)
        Write-Utf8NoBom -Path $p.Notice -Text ((Get-IsoTimestamp) + "`n")
    } catch { }
}

# One request to the intake (POST with a JSON body; DELETE for -Forget): a TCP connect probe of at
# most $ConnectMs (the proxy's address when the system proxy is used for the URL), then the request.
# (wave 28b, D2 / F36-2) $TotalMs bounds the WHOLE request - the probe, the connection, sending the
# body and reading the answer (HttpClient with the answer buffered inside its timeout, a cancel at
# the bound, and a hard wait of the bound): a slow or trickling intake costs at most $TotalMs.
# Delivered only on a 2xx answer that is a JSON object with "ok": true - anything else (a timeout,
# an HTML page, a 4xx/5xx, a JSON without ok) is not delivered. { Delivered; Status (0: no HTTP
# answer); Json; Text (the answer, at most 64 K characters); Why; RetryAfter (seconds; -1 when not
# given) }.
$script:TelemetryHttpReady = $false
function Invoke-TelemetryRequest {
    param([string]$Url, [string]$Body = '', [string]$Method = 'POST', [int]$ConnectMs = 3000, [int]$TotalMs = 8000)
    $r = [pscustomobject]@{ Delivered = $false; Status = 0; Json = $null; Text = ''; Why = ''; RetryAfter = -1 }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $boundText = "$([Math]::Round($TotalMs / 1000.0, 1)) s"
    if ($script:LegacyPS) { try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { } }
    $uri = [Uri]$Url
    $target = $uri
    $useProxy = $false
    try {
        $proxy = [Net.WebRequest]::DefaultWebProxy
        if ($proxy -and -not $uri.IsLoopback -and -not $proxy.IsBypassed($uri)) { $pu = $proxy.GetProxy($uri); if ($pu -and $pu -ne $uri) { $target = $pu; $useProxy = $true } }
    } catch { }
    $probeMs = [int][Math]::Max(100, [Math]::Min($ConnectMs, $TotalMs))
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $tcp.BeginConnect($target.Host, $target.Port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($probeMs)) { $r.Why = "no connection to $($target.Host):$($target.Port) within $([Math]::Round($probeMs / 1000.0, 1)) s"; return $r }
        $tcp.EndConnect($ar)
    } catch {
        $ex = $_.Exception
        while ($ex.InnerException) { $ex = $ex.InnerException }
        $r.Why = "could not connect to $($target.Host):$($target.Port) ($(ConvertTo-OneLine $ex.Message))"
        return $r
    } finally { try { $tcp.Close() } catch { } }
    $left = [int]($TotalMs - $watch.ElapsedMilliseconds)
    if ($left -lt 100) { $r.Why = "no answer within $boundText"; return $r }
    if (-not $script:TelemetryHttpReady) { Add-Type -AssemblyName System.Net.Http; $script:TelemetryHttpReady = $true }
    $handler = $null; $client = $null; $msg = $null; $cts = $null; $resp = $null
    try {
        $handler = New-Object System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $handler.UseProxy = $useProxy
        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.Timeout = [TimeSpan]::FromMilliseconds($left)
        $client.MaxResponseContentBufferSize = 1048576
        $msg = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method)), $uri)
        [void]$msg.Headers.TryAddWithoutValidation('Accept', 'application/json')
        [void]$msg.Headers.TryAddWithoutValidation('User-Agent', "codex-consult/$(Get-BridgeVersion)")
        $msg.Headers.ExpectContinue = $false
        $msg.Headers.ConnectionClose = $true
        if ($Method -ne 'DELETE' -or $Body) {
            $bytes = $script:Utf8NoBom.GetBytes($Body)
            $msg.Content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $bytes)
            [void]$msg.Content.Headers.TryAddWithoutValidation('Content-Type', 'application/json; charset=utf-8')
        }
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter($left)
        $task = $client.SendAsync($msg, [System.Net.Http.HttpCompletionOption]::ResponseContentRead, $cts.Token)
        $done = $false
        try { $done = $task.Wait($left + 250) } catch { $done = $task.IsCompleted }
        if (-not $done -or $task.IsCanceled) {
            try { $cts.Cancel() } catch { }
            $r.Why = "no answer within $boundText"
            return $r
        }
        if ($task.IsFaulted) {
            $m = $task.Exception
            while ($m.InnerException) { $m = $m.InnerException }
            $r.Why = $(if ($m -is [System.OperationCanceledException] -or $m -is [TimeoutException]) { "no answer within $boundText" } else { "no answer ($(ConvertTo-OneLine $m.Message))" })
            return $r
        }
        $resp = $task.Result
        $r.Status = [int]$resp.StatusCode
        $ctype = ''
        try { if ($resp.Content -and $resp.Content.Headers.ContentType) { $ctype = [string]$resp.Content.Headers.ContentType.MediaType } } catch { }
        try {
            $ra = $resp.Headers.RetryAfter
            if ($ra) {
                # (PowerShell unwraps the Nullable properties: a TimeSpan / DateTimeOffset, or $null)
                if ($null -ne $ra.Delta) { $r.RetryAfter = [int][Math]::Max(0, [Math]::Ceiling(([TimeSpan]$ra.Delta).TotalSeconds)) }
                elseif ($null -ne $ra.Date) { $r.RetryAfter = [int][Math]::Max(0, [Math]::Ceiling((([DateTimeOffset]$ra.Date) - [DateTimeOffset]::UtcNow).TotalSeconds)) }
            }
        } catch { }
        $text = ''
        try { if ($resp.Content) { $text = [string]$resp.Content.ReadAsStringAsync().Result } } catch { $text = '' }
        if ($text.Length -gt 65536) { $text = $text.Substring(0, 65536) }
        $r.Text = $text
        $obj = $null
        try { if ($text.Trim().StartsWith('{')) { $obj = ConvertFrom-Json -InputObject $text } } catch { $obj = $null }
        if ($obj -and (Test-IsJsonObject $obj)) { $r.Json = $obj }
        if ($r.Status -ge 200 -and $r.Status -lt 300 -and $r.Json -and (Get-PropertyValue $r.Json 'ok' $false) -eq $true) {
            $r.Delivered = $true
        } elseif (-not $r.Json) {
            $r.Why = "HTTP $($r.Status)$(if ($ctype) { " ($ctype)" }) is not the intake's JSON answer"
        } else {
            $r.Why = "HTTP $($r.Status)$(if ((Get-PropertyValue $r.Json 'error' '')) { ": $(ConvertTo-OneLine ([string]$r.Json.error))" } else { ' without ok: true' })"
        }
    } catch {
        $m = $_.Exception
        while ($m.InnerException) { $m = $m.InnerException }
        $r.Why = "no answer ($(ConvertTo-OneLine $m.Message))"
    } finally {
        foreach ($d in @($resp, $msg, $client, $handler, $cts)) { if ($d) { try { $d.Dispose() } catch { } } }
    }
    return $r
}

# A POST (Invoke-TelemetryRequest) - kept for the callers of wave 28.
function Invoke-TelemetryPost {
    param([string]$Url, [string]$Body, [int]$ConnectMs = 3000, [int]$TotalMs = 8000)
    return (Invoke-TelemetryRequest -Url $Url -Body $Body -Method 'POST' -ConnectMs $ConnectMs -TotalMs $TotalMs)
}

# POSTs with the intake's rate rule: a 429 whose Retry-After is at most 60 s - and (wave 28b, D2)
# fits into $BudgetMs, what is left of the flush's deadline (0: no deadline) - is waited for and the
# SAME request sent once more; a longer or missing Retry-After, or a second 429, stops there. No
# other retry. Every request is bounded by $TotalMs (and by the budget).
function Invoke-TelemetrySend {
    param([string]$Url, [string]$Body, [int]$ConnectMs = 3000, [int]$TotalMs = 8000, [long]$BudgetMs = 0)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $one = { param([long]$Left) if ($BudgetMs -gt 0) { [int][Math]::Max(100, [Math]::Min([long]$TotalMs, $Left)) } else { $TotalMs } }
    $r = Invoke-TelemetryPost -Url $Url -Body $Body -ConnectMs $ConnectMs -TotalMs (& $one ($BudgetMs - $watch.ElapsedMilliseconds))
    if ($r.Status -eq 429) {
        $left = $BudgetMs - $watch.ElapsedMilliseconds
        if ($r.RetryAfter -ge 0 -and $r.RetryAfter -le $script:TelemetryRetryAfterMax -and ($BudgetMs -le 0 -or ([long]$r.RetryAfter * 1000 + 1000) -lt $left)) {
            Start-Sleep -Seconds $r.RetryAfter
            $r = Invoke-TelemetryPost -Url $Url -Body $Body -ConnectMs $ConnectMs -TotalMs (& $one ($BudgetMs - $watch.ElapsedMilliseconds))
            if ($r.Status -eq 429) { $r.Why = 'HTTP 429 again after its Retry-After' }
        } elseif ($r.RetryAfter -ge 0 -and $r.RetryAfter -le $script:TelemetryRetryAfterMax) {
            $r.Why = "HTTP 429 (Retry-After $($r.RetryAfter) s does not fit into the flush's deadline: not retried now)"
        } else {
            $r.Why = "HTTP 429 (Retry-After $(if ($r.RetryAfter -ge 0) { "$($r.RetryAfter) s, more than $($script:TelemetryRetryAfterMax) s" } else { 'not given' }): not retried now)"
        }
    }
    return $r
}

# Removes $Lines (a multiset of exact lines) from a spool file - lines appended before stay; an
# emptied file is deleted. (wave 28d, D1 / F48-1, F49-3) The rewrite is ATOMIC: under the telemetry
# lock (Enter-TelemetryLock -IgnoreMarker - no producer appends meanwhile) the file is read under its
# exclusive handle, the kept lines go to <spool file>.tmp in the same directory (a .tmp a crash left
# behind is replaced), are flushed to disk, and the temporary file REPLACES the spool file in one step
# ([IO.File]::Move with overwrite; MoveFileEx(REPLACE_EXISTING | WRITE_THROUGH) on Windows PowerShell
# 5.1, as Write-TextAtomic) - nothing truncates the spool in place: a crash leaves the old file or the
# new one, never a truncated one. A replace that keeps failing leaves the spool as it was (its
# delivered lines are sent again later - at least once). $WaitMs (wave 28c, D5: what is left of the
# flush's deadline) bounds the waits for the lock and the file BEFORE the rewrite starts; nothing
# inside the rewrite is cut by the deadline. TEST HOOK (test mode only):
# CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH=1 - the process exits (code 86) between the temporary
# file and the replace, as a crash would. '' when done, else why not.
function Remove-TelemetrySpoolLines {
    param([string]$Path, [string[]]$Lines, [int]$WaitMs = 2000)
    if (@($Lines).Count -eq 0) { return '' }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $lk = Enter-TelemetryLock -WaitMs $WaitMs -IgnoreMarker
    if (-not $lk.Ok) { return "the spool file '$Path' was not rewritten ($($lk.Why))" }
    try {
        $fs = Open-TelemetrySpoolFile -Path $Path -WaitMs ([int][Math]::Max(50, $WaitMs - $watch.ElapsedMilliseconds))
        if (-not $fs) { return "the spool file '$Path' stayed busy" }
        $keep = New-Object System.Collections.Generic.List[string]
        try {
            $remove = New-Object 'System.Collections.Generic.Dictionary[string,int]'
            foreach ($l in $Lines) { if ($remove.ContainsKey($l)) { $remove[$l]++ } else { $remove[$l] = 1 } }
            foreach ($l in (Read-TelemetryStreamLines $fs)) {
                if ($remove.ContainsKey($l) -and $remove[$l] -gt 0) { $remove[$l]--; continue }
                $keep.Add($l)
            }
        } finally { $fs.Dispose() }
        $tmp = "$Path.tmp"
        if ($keep.Count -eq 0) {
            [IO.File]::Delete($Path)
            try { if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) } } catch { }
            return ''
        }
        $bytes = $script:Utf8NoBom.GetBytes(($keep.ToArray() -join "`n") + "`n")
        $ts = New-Object System.IO.FileStream($tmp, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try { $ts.Write($bytes, 0, $bytes.Length); $ts.Flush($true) } finally { $ts.Dispose() }
        if ((Get-TestHookValue 'CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH').Trim() -eq '1') { [Environment]::Exit(86) }
        $lastError = $null
        for ($attempt = 1; $attempt -le 8; $attempt++) {
            try {
                if (-not $script:LegacyPS) {
                    [IO.File]::Move($tmp, $Path, $true)
                } elseif (Test-NativeMove) {
                    if (-not [CodexConsultNative]::MoveFileEx($tmp, $Path, 0x9)) { throw (New-Object System.ComponentModel.Win32Exception([Runtime.InteropServices.Marshal]::GetLastWin32Error())) }
                } else {
                    [IO.File]::Replace($tmp, $Path, [System.Management.Automation.Language.NullString]::Value)
                }
                return ''
            } catch {
                # a reader holding the spool file open without FileShare.Delete: gone a moment later
                $lastError = $_.Exception
                Start-Sleep -Milliseconds 250
            }
        }
        try { [IO.File]::Delete($tmp) } catch { }
        return "the spool file '$Path' could not be replaced ($(ConvertTo-OneLine $lastError.Message)); it is kept as it was"
    } catch { return (ConvertTo-OneLine $_.Exception.Message) } finally { Exit-TelemetryLock }
}

# The spool as it is: { Files; Events; Complaints; Invalid; Oldest (unix s or $null) } - read-only.
function Get-TelemetrySpoolCounts {
    $c = [pscustomobject]@{ Files = 0; Events = 0; Complaints = 0; Invalid = 0; Oldest = $null }
    $p = Get-TelemetryPaths
    if (-not $p -or -not [IO.Directory]::Exists($p.Spool)) { return $c }
    foreach ($f in @(Get-ChildItem -LiteralPath $p.Spool -File -Filter '*.ndjson' | Sort-Object Name)) {
        $c.Files++
        foreach ($l in @((Read-SharedText -Path $f.FullName) -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })) {
            $s = ConvertFrom-TelemetrySpoolLine $l
            if (-not $s) { $c.Invalid++; continue }
            if ($s.Kind -eq 'event') { $c.Events++ } else { $c.Complaints++ }
            if ($null -eq $c.Oldest -or $s.Queued -lt $c.Oldest) { $c.Oldest = $s.Queued }
        }
    }
    return $c
}

# (wave 28b, D2 / F36-2) The sender's lock <spool>/.flush.lock: a MARKER file {pid, start_time,
# token, since}. (wave 28d, D3 / F48-3, F49-4) BORN WITH ITS OWNER: the record is written to a
# temporary file <lock>.<guid>.tmp (flushed to disk) that is MOVED into place without overwriting - a
# healthy sender never leaves a lock without its owner record, and two senders never both create one.
# An existing lock is refused while somebody holds it open. (wave 28c, D4 / F42-7, F43-5, F44-2) A
# lock whose owner process (pid and start time) lives is NEVER taken over, however old - an owner
# whose identity cannot be confirmed counts as living (Test-PidAlive); it is reported ("sender busy
# since <t>"), and (D3) once it is older than 30 minutes as "sender stuck since <t> (pid <n>)" (Stuck,
# which the flush writes into <spool>/.last `notes`; -Status says it too) with what the operator can
# do. A lock that names no owner or cannot be read counts as HELD while it is younger than 30 s; after
# that - and a lock whose owner is gone at once - it is REMOVED under an exclusive handle (nobody
# rewrites it meanwhile) and the sender starts over (TookOver says why). Released (deleted) in
# `finally` by its owner only (the token); every sender checks its token again right before each spool
# rewrite and each send (Test-TelemetryFlushLockMine).
# { Ok; Token; TookOver ('' or why the old lock was removed); Why (why refused); Stuck ('' or
# "sender stuck since <t> (pid <n>)") }.
$script:TelemetryOwnerlessLockSec = 30
$script:TelemetryStuckLockSec = 1800
function Enter-TelemetryFlushLock {
    param([string]$Path)
    $r = [pscustomobject]@{ Ok = $false; Token = ([guid]::NewGuid().ToString('N')); TookOver = ''; Why = ''; Stuck = '' }
    $content = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ pid = $PID; start_time = [string](Get-ProcessStartIso -ProcessId $PID); token = $r.Token; since = (Get-IsoTimestamp) })
    $bytes = $script:Utf8NoBom.GetBytes($content + "`n")
    for ($round = 0; $round -lt 3; $round++) {
        # (wave 28d, D3) the record first, in a temporary file; then moved into place only when no lock is there
        $tmp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            $ts = New-Object System.IO.FileStream($tmp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $ts.Write($bytes, 0, $bytes.Length); $ts.Flush($true) } finally { $ts.Dispose() }
            $moved = $false
            try { [IO.File]::Move($tmp, $Path); $moved = $true } catch { }
            if ($moved) { $r.Ok = $true; return $r }
        } catch {
            $r.Why = "the lock could not be written ($(ConvertTo-OneLine $_.Exception.Message))"
            return $r
        } finally { try { if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) } } catch { } }
        # a lock is there: read under an exclusive handle that still lets it be deleted
        $fs = $null
        try { $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Delete) } catch {
            if (-not [IO.File]::Exists($Path)) { continue }
            $r.Why = 'another flush is running (its lock is held)'
            return $r
        }
        $removed = ''
        try {
            $age = ([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($Path)).TotalSeconds
            $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $false, 4096, $true)
            try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
            $own = Get-TelemetryFlushLockOwner -Text $text
            $since = $own.Since
            if (-not $since) { $since = [IO.File]::GetLastWriteTimeUtc($Path).ToLocalTime().ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant) }
            if ($own.Owner -eq 'alive') {
                if ($age -ge $script:TelemetryStuckLockSec) {
                    $r.Stuck = "sender stuck since $since (pid $($own.Pid))"
                    $r.Why = "another flush is running: $($r.Stuck) - its lock is $([int]($age / 60)) min old and its owner lives: it is never taken over; stop pid $($own.Pid) if it hangs, or delete $Path when no such process runs"
                } else {
                    $r.Why = "another flush is running: sender busy since $since (pid $($own.Pid) holds its lock, $([int]$age) s old$(if ($age -ge $script:TelemetryLockStaleSec) { ' - its owner lives: left alone' }))"
                }
                return $r
            }
            if ($own.Owner -eq 'none' -and $age -lt $script:TelemetryOwnerlessLockSec) {
                $r.Why = "another flush is running (its lock names no owner yet - held while younger than $($script:TelemetryOwnerlessLockSec) s: $([int]$age) s old)"
                return $r
            }
            $removed = $(if ($own.Owner -eq 'gone') { "its owner pid $($own.Pid) is gone" } else { "it named no owner for $([int]$age) s" })
            # removed under this handle (FileShare.Delete only: nobody writes it meanwhile); then the
            # sender starts over
            [IO.File]::Delete($Path)
        } catch {
            $r.Why = "the lock could not be taken ($(ConvertTo-OneLine $_.Exception.Message))"
            return $r
        } finally { $fs.Dispose() }
        $r.TookOver = $removed
    }
    $r.Why = 'another flush is running (its lock came back each time it was removed)'
    return $r
}

# (wave 28d, D3) A flush lock's owner as its text says: { Pid; Since; Owner - 'alive' (its pid and
# start time live, or its identity cannot be confirmed: Test-PidAlive), 'gone', 'none' (the lock names
# no owner or cannot be read) }. Read only.
function Get-TelemetryFlushLockOwner {
    param([string]$Text)
    $o = [pscustomobject]@{ Pid = 0; Since = ''; Owner = 'none' }
    $rec = $null
    try { if (([string]$Text).Trim().StartsWith('{')) { $rec = ConvertFrom-JsonKeepOffset -Text $Text } } catch { $rec = $null }
    $n = Get-TelemetryCount (Get-PropertyValue $rec 'pid' $null)
    if ($null -ne $n -and $n -le [int]::MaxValue) { $o.Pid = [int]$n }
    $o.Since = [string](ConvertTo-JsonText (Get-PropertyValue $rec 'since' ''))
    if ($o.Pid -gt 0) { $o.Owner = $(if (Test-PidAlive -ProcessId $o.Pid -StartTime ([string](ConvertTo-StartIso (Get-PropertyValue $rec 'start_time' '')))) { 'alive' } else { 'gone' }) }
    return $o
}

# (wave 28c, D4) Whether the sender's lock still carries $Token: read without taking it (shared); a
# lock that is gone, names another token or cannot be read within about 1 s is NOT this sender's -
# the sender then stops without rewriting the spool or sending more.
function Test-TelemetryFlushLockMine {
    param([string]$Path, [string]$Token)
    for ($i = 0; $i -lt 20; $i++) {
        try {
            if (-not [IO.File]::Exists($Path)) { return $false }
            $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $false, 4096, $true)
                try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
            } finally { $fs.Dispose() }
            try { return (([string](Get-PropertyValue (ConvertFrom-Json -InputObject $text) 'token' '')) -ceq $Token) } catch { return $false }
        } catch { Start-Sleep -Milliseconds 50 }
    }
    return $false
}

# Releases the sender's lock when it still carries $Token (a lock taken over by another sender stays).
function Exit-TelemetryFlushLock {
    param([string]$Path, [string]$Token)
    for ($i = 0; $i -lt 20; $i++) {
        try {
            if (-not [IO.File]::Exists($Path)) { return }
            $mine = $false
            $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            try {
                $sr = New-Object System.IO.StreamReader($fs, $script:Utf8NoBom, $false, 4096, $true)
                try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }
                try { $mine = ([string](Get-PropertyValue (ConvertFrom-Json -InputObject $text) 'token' '')) -ceq $Token } catch { $mine = $false }
            } finally { $fs.Dispose() }
            if ($mine) { [IO.File]::Delete($Path) }
            return
        } catch { Start-Sleep -Milliseconds 50 }
    }
}

# A test hook's positive milliseconds (test mode only), else $Default.
function Get-TelemetryHookMs {
    param([string]$Name, [int]$Default)
    $v = 0
    if ([int]::TryParse(([string](Get-TestHookValue $Name)).Trim(), [ref]$v) -and $v -gt 0) { return $v }
    return $Default
}

# THE flush (codex-telemetry.ps1 -Flush; the detached sender): under the sender lock
# (Enter-TelemetryFlushLock - a concurrent sender is refused, a stale lock taken over), every spool
# file oldest first: lines older than 7 days and lines that are not spool lines are dropped; events go
# in batches of at most 100 ({"events": [...]}) to <base>/v2/events, complaints one by one to
# <base>/v2/complaints; the delivered and dropped lines are removed, the rest stays.
# (wave 28b, D2) One flush ends after 60 s in all (TEST HOOK, test mode only:
# CODEX_CONSULT_TEST_TELEMETRY_FLUSH_MS), one request after 8 s (CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS)
# - what is not sent stays in the spool. (D8) Against the intake as it is built: a batch refused with
# 400 "events[i]: <reason>" - event i is DROPPED (one line in .last `rejected`) and the rest resent, at
# most three times per flush; 413 - the batch is halved (an event refused alone is dropped); 403 - the
# flush stops, the spool is kept, the reason is said; any other 4xx, a 5xx, a timeout - the flush
# stops there (nothing is hammered; the next run's sender tries again). The events not spooled since
# the last flush (D6) are counted from zero again.
# (wave 28c, D5 / F42-8) The 60 s cover the WHOLE flush - the lock, the spool's enumeration, every
# file's read, every request and every rewrite: the clock is checked before each step, and a step that
# no longer fits stops the flush cleanly (what is not sent stays). A request is started only while
# 1.5 s are left (1 s kept back for the rewrite that follows it); the rewrite of lines already
# delivered is always attempted, with a wait of at most what is left (at least 0.1 s) - skipping it
# would send them again. (D4) The sender checks its token in the lock before each send and each
# rewrite: a sender that lost its lock stops without rewriting. (wave 28d, D1) Every rewrite is atomic
# (Remove-TelemetrySpoolLines); (D2) a forgetting marker whose owner lives stops the flush, one whose
# owner is gone is removed.
# Writes <spool>/.last {time, result, delivered, kept, dropped, rejected, http, (wave 28d) not_spooled_seen,
# (wave 28e, E20) not_spooled_folded, notes} - (wave 28e, E2) folding the not-spooled files of gone
# producers into one of its notes (Merge-TelemetryNotSpooled; E20: saved BEFORE the files are deleted -
# Complete-TelemetryNotSpooledFold). { Exit (0 done or
# nothing to send, 1 something not delivered or the URL refused, 2 another sender holds the lock);
# Result; Delivered; Kept; Dropped; Rejected (string[]); Http; TookOver }.
$script:TelemetryRewriteReserveMs = 1000
function Invoke-TelemetryFlush {
    param([int]$ConnectMs = 3000, [int]$TotalMs = 0, [int]$FlushMs = 0)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    if ($TotalMs -le 0) { $TotalMs = Get-TelemetryHookMs 'CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS' $script:TelemetryRequestMs }
    if ($FlushMs -le 0) { $FlushMs = Get-TelemetryHookMs 'CODEX_CONSULT_TEST_TELEMETRY_FLUSH_MS' $script:TelemetryFlushMs }
    $res = [pscustomobject]@{ Exit = 0; Result = ''; Delivered = 0; Kept = 0; Dropped = 0; Rejected = (New-Object System.Collections.Generic.List[string]); Http = $null; TookOver = '' }
    $p = Get-TelemetryPaths
    if (-not $p) { $res.Exit = 1; $res.Result = 'no codex home (CODEX_HOME, else ~/.codex)'; return $res }
    if (-not [IO.Directory]::Exists($p.Spool)) { $res.Result = 'nothing to send (no spool)'; return $res }
    $lock = Enter-TelemetryFlushLock -Path $p.Lock
    if (-not $lock.Ok) {
        # (wave 28d, D3) a sender stuck for 30 minutes: one line in .last for the operator
        if ($lock.Stuck) { Add-TelemetryLastNote -Text $lock.Stuck }
        $res.Exit = 2; $res.Result = $lock.Why; return $res
    }
    $res.TookOver = $lock.TookOver
    $deadlineText = "the flush's deadline ($([Math]::Round($FlushMs / 1000.0, 1)) s) was reached"
    $lostText = 'this sender lost its lock (another sender holds it now) - it stopped without rewriting the spool'
    $leftMs = { [long]$FlushMs - $watch.ElapsedMilliseconds }
    $lost = $false
    try {
        # (D6; wave 28d, D4; wave 28e, E2) the count of events not spooled starts again with every flush:
        # at its end (under the telemetry lock, with .last) the files of gone producers are folded into
        # one line of .last notes and removed, and the lines of the files kept are recorded (.last
        # not_spooled_seen) - Merge-TelemetryNotSpooled below
        $url = Get-TelemetryUrl
        $stop = ''
        if ($url.Error) { $stop = $url.Error }
        # (wave 28d, D2 / F48-2) the forgetting marker: one whose owner is gone is removed (under the
        # telemetry lock; a line in .last); one whose owner lives stops this flush - nothing is sent
        # while -Forget deletes
        if (-not $stop -and [IO.File]::Exists($p.Forgetting)) {
            $fg = Enter-TelemetryLock -WaitMs ([int][Math]::Max(100, [Math]::Min(1000, (& $leftMs))))
            if ($fg.Ok) { Exit-TelemetryLock } elseif ($fg.Forgetting) { $stop = $fg.Why }
        }
        $cutoff = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - ($script:TelemetrySpoolDays * 86400)
        $rounds = 0
        $queuedText = { param($s) try { [DateTimeOffset]::FromUnixTimeSeconds([long]$s.Queued).ToLocalTime().ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant) } catch { [string]$s.Queued } }
        $reserve = [long]$script:TelemetryRewriteReserveMs
        # (wave 28c, D5) the enumeration is a step too
        $files = @()
        if (-not $stop) {
            if ((& $leftMs) -le 0) { $stop = $deadlineText }
            else { $files = @(Get-ChildItem -LiteralPath $p.Spool -File -Filter '*.ndjson' | Sort-Object Name) }
        }
        foreach ($f in $files) {
            if ($stop) { break }
            # (D5) a file's read only while there is time for it and a send
            $left = & $leftMs
            if ($left -lt (500 + $reserve)) { $stop = $deadlineText; break }
            $fs = Open-TelemetrySpoolFile -Path $f.FullName -WaitMs ([int][Math]::Min(2000, $left - 500 - $reserve))
            if (-not $fs) { continue }
            try { $lines = Read-TelemetryStreamLines $fs } finally { $fs.Dispose() }
            $drop = New-Object System.Collections.Generic.List[string]
            $done = New-Object System.Collections.Generic.List[string]
            $events = New-Object System.Collections.Generic.List[object]
            $complaints = New-Object System.Collections.Generic.List[object]
            foreach ($l in $lines) {
                $s = ConvertFrom-TelemetrySpoolLine $l
                if (-not $s -or $s.Queued -lt $cutoff) { $drop.Add($l); continue }
                if ($s.Kind -eq 'event') { $events.Add($s) } else { $complaints.Add($s) }
            }
            $batchSize = $script:TelemetryBatchMax
            $i = 0
            while ($i -lt $events.Count -and -not $stop) {
                $left = & $leftMs
                if ($left -lt (500 + $reserve)) { $stop = $deadlineText; break }
                # (wave 28c, D4) still this sender's lock
                if (-not (Test-TelemetryFlushLockMine -Path $p.Lock -Token $lock.Token)) { $lost = $true; $stop = $lostText; break }
                $batch = @($events.GetRange($i, [Math]::Min($batchSize, $events.Count - $i)))
                $r = Invoke-TelemetrySend -Url "$($url.Base)/v2/events" -Body ('{"events":[' + (@($batch | ForEach-Object { $_.Body }) -join ',') + ']}') -ConnectMs $ConnectMs -TotalMs $TotalMs -BudgetMs ($left - $reserve)
                if ($r.Status) { $res.Http = $r.Status }
                if ($r.Delivered) {
                    foreach ($b in $batch) { $done.Add($b.Line) }
                    $res.Delivered += $batch.Count
                    $i += $batch.Count
                    continue
                }
                $err = $(if ($r.Json) { [string](Get-PropertyValue $r.Json 'error' '') } else { '' })
                if (-not $err) { $err = [string]$r.Text }
                $m = [regex]::Match($err, 'events\[(\d+)\]\s*:\s*([^\r\n]*)')
                if ($r.Status -eq 400 -and $m.Success -and [int]$m.Groups[1].Value -lt $batch.Count) {
                    if ($rounds -ge $script:TelemetryRejectRounds) { $stop = "HTTP 400: $(ConvertTo-OneLine $err) - a fourth refused event in this flush; the rest stays"; break }
                    $rounds++
                    $bad = $batch[[int]$m.Groups[1].Value]
                    $drop.Add($bad.Line)
                    $res.Rejected.Add("event queued $(& $queuedText $bad) refused: $(ConvertTo-OneLine $m.Groups[2].Value)")
                    [void]$events.Remove($bad)
                    continue
                }
                if ($r.Status -eq 413) {
                    if ($batch.Count -gt 1) { $batchSize = [int][Math]::Max(1, [Math]::Floor($batch.Count / 2)); continue }
                    $drop.Add($batch[0].Line)
                    $res.Rejected.Add("event queued $(& $queuedText $batch[0]) refused: HTTP 413 (too large alone)")
                    [void]$events.Remove($batch[0])
                    continue
                }
                if ($r.Status -eq 403) { $stop = "HTTP 403 - the intake refuses this app ($(ConvertTo-OneLine $r.Why)); the spool is kept"; break }
                $stop = $(if ($r.Status -ge 400 -and $r.Status -lt 500 -and $r.Status -ne 429) { "$(ConvertTo-OneLine $r.Why) - the spool is kept" } else { $r.Why })
            }
            foreach ($cp in $complaints) {
                if ($stop) { break }
                $left = & $leftMs
                if ($left -lt (500 + $reserve)) { $stop = $deadlineText; break }
                if (-not (Test-TelemetryFlushLockMine -Path $p.Lock -Token $lock.Token)) { $lost = $true; $stop = $lostText; break }
                $r = Invoke-TelemetrySend -Url "$($url.Base)/v2/complaints" -Body $cp.Body -ConnectMs $ConnectMs -TotalMs $TotalMs -BudgetMs ($left - $reserve)
                if ($r.Status) { $res.Http = $r.Status }
                if ($r.Delivered) { $done.Add($cp.Line); $res.Delivered++; continue }
                if ($r.Status -eq 403) { $stop = "HTTP 403 - the intake refuses this app ($(ConvertTo-OneLine $r.Why)); the spool is kept" }
                elseif ($r.Status -ge 400 -and $r.Status -lt 500 -and $r.Status -ne 429) { $stop = "$(ConvertTo-OneLine $r.Why) - the spool is kept" }
                else { $stop = $r.Why }
            }
            # (wave 28c, D4) the rewrite only while the lock is still this sender's; (D5) with at most
            # what is left of the deadline (the lines already delivered must go: at least 0.1 s)
            if ($lost -or -not (Test-TelemetryFlushLockMine -Path $p.Lock -Token $lock.Token)) { $lost = $true; $stop = $lostText; break }
            $res.Dropped += $drop.Count
            $why = Remove-TelemetrySpoolLines -Path $f.FullName -Lines ([string[]]@($done.ToArray() + $drop.ToArray())) -WaitMs ([int][Math]::Max(100, [Math]::Min(2000, (& $leftMs))))
            if ($why -and -not $stop) { $stop = $why }
        }
        # (D5) the spool's counts are one more read of every file: only while time is left (and a file
        # another process holds is not counted either)
        $counted = $false
        $notCounted = 'the deadline'
        if ((& $leftMs) -gt 0) {
            try {
                $counts = Get-TelemetrySpoolCounts
                $res.Kept = $counts.Events + $counts.Complaints + $counts.Invalid
                $counted = $true
            } catch { $notCounted = 'a spool file could not be read' }
        }
        if (-not $counted) { $res.Kept = $null }
        $keptText = $(if ($counted) { "$($res.Kept)" } else { "? (not counted: $notCounted)" })
        $rej = $(if ($res.Rejected.Count -gt 0) { ", $($res.Rejected.Count) refused by the intake" } else { '' })
        if ($stop) {
            $res.Exit = 1
            $res.Result = "not delivered: $stop - delivered $($res.Delivered), kept $keptText, dropped $($res.Dropped)$rej"
        } elseif ($res.Delivered -eq 0 -and $res.Dropped -eq 0) {
            $res.Result = 'nothing to send'
        } else {
            $res.Result = "delivered $($res.Delivered), kept $keptText, dropped $($res.Dropped)$(if ($res.Dropped -gt $res.Rejected.Count) { " (older than $($script:TelemetrySpoolDays) days or unreadable$(if ($res.Rejected.Count -gt 0) { ', or refused' }))" } elseif ($res.Rejected.Count -gt 0) { ' (refused by the intake)' })"
        }
        if ($res.TookOver) { $res.Result += " (a stale sender lock was taken over: $($res.TookOver))" }
        # (wave 28d, D2, D3, D4) .last keeps its notes (a stuck sender's line goes: this sender holds
        # the lock now) and records the not-spooled lines seen; written under the telemetry lock, so a
        # note added meanwhile is not lost. (wave 28e, E2 / F54-2, F53-1) Under that lock the files of
        # not-spooled events whose producers are gone are folded - ONE note line "folded <n> not-spooled
        # line(s) of <m> gone producer(s)" - and removed; not_spooled_seen counts the lines of the files
        # kept (live producers). Without the lock nothing is folded and every line counts as seen.
        # (wave 28e, E20 / F27-3) In THIS order: .last is saved first - the fold's note, the new
        # not_spooled_seen and not_spooled_folded[] ((E24) {name, bytes} of the files the fold covers) - and only
        # after that save are the files deleted (still under the handles the fold holds); then .last is
        # written once more without the names of the files now gone. A crash between the save and the
        # deletes leaves files .last names: the next flush deletes them WITHOUT counting them again (and
        # -Status leaves them out). A .last that cannot be written folds nothing: the files and the old
        # baseline stay, and the result carries a warning.
        $lkLast = Enter-TelemetryLock -WaitMs 1000 -IgnoreMarker
        $fold = $null
        try {
            $lastBefore = Read-TelemetryLast
            $notes = @(@(Get-PropertyValue $lastBefore 'notes' @()) | Where-Object { $_ -and ([string]$_) -notmatch '^\S+ sender stuck since ' } | ForEach-Object { [string]$_ })
            # (wave 28e, E24) {name, bytes} of the files an earlier fold counted (a bare name: bytes -1)
            $foldedBefore = Get-TelemetryFoldedMap -Last $lastBefore
            if ($lkLast.Ok) {
                $fold = Merge-TelemetryNotSpooled -Paths $p -AlreadyFolded $foldedBefore
                $nsSeen = [long]$fold.Seen
                $foldedNames = [object[]]$fold.Folded.ToArray()
                if ($fold.Producers -gt 0) { $notes += "$(Get-IsoTimestamp) folded $($fold.Lines) not-spooled line(s) of $($fold.Producers) gone producer(s)" }
                if ($fold.Note) { $notes += "$(Get-IsoTimestamp) $($fold.Note)" }
            } else {
                # (E26) the legacy file's lines are never seen: they count until a fold stages them
                $nsAll = Get-TelemetryNotSpooled -All
                $nsSeen = [long]$nsAll.Total - [long]$nsAll.LegacyLines
                # the entries an earlier fold counted stay while their files are there
                $foldedNames = [object[]]@(foreach ($k in @($foldedBefore.Keys)) { if ([IO.File]::Exists((Join-Path $p.Home ([string]$k)))) { [pscustomobject]@{ name = [string]$k; bytes = [long]$foldedBefore[$k] } } })
            }
            $notes = @($notes | Select-Object -Last $script:TelemetryLastNotesMax)
            $lastNew = [pscustomobject]@{ time = (Get-IsoTimestamp); result = $res.Result; delivered = $res.Delivered; kept = $res.Kept; dropped = $res.Dropped; rejected = [object[]]$res.Rejected.ToArray(); http = $res.Http; not_spooled_seen = $nsSeen; not_spooled_folded = [object[]]$foldedNames; notes = [object[]]$notes }
            $saved = $false
            try {
                Write-JsonFile -Path $p.Last -Object $lastNew
                $saved = $true
            } catch {
                $res.Result += "; warning: $($p.Last) could not be written ($(ConvertTo-OneLine $_.Exception.Message)) - nothing was folded: the not-spooled files and the last baseline stay, the next flush counts them"
            }
            if ($saved -and $fold -and $fold.Folded.Count -gt 0) {
                # TEST HOOK (test mode only): CODEX_CONSULT_TEST_FOLD_CRASH=1 - the process exits (code 87)
                # between the save of .last and the deletes, as a crash would; (E26) =2 - it exits (code 88)
                # between the deletes and the rewrite of .last that drops their names
                $foldCrash = (Get-TestHookValue 'CODEX_CONSULT_TEST_FOLD_CRASH').Trim()
                if ($foldCrash -eq '1') { [Environment]::Exit(87) }
                $left = Complete-TelemetryNotSpooledFold -Fold $fold -Delete
                if ($foldCrash -eq '2') { [Environment]::Exit(88) }
                if ($left.Count -ne $foldedNames.Count) {
                    $lastNew.not_spooled_folded = [object[]]$left
                    try { Write-JsonFile -Path $p.Last -Object $lastNew } catch { }
                }
            }
        } catch { } finally {
            if ($fold) { try { $null = Complete-TelemetryNotSpooledFold -Fold $fold } catch { } }
            if ($lkLast.Ok) { Exit-TelemetryLock }
        }
    } finally { Exit-TelemetryFlushLock -Path $p.Lock -Token $lock.Token }
    return $res
}

# The last flush's record (<spool>/.last): the object, or $null when there is none (or it cannot
# be read).
function Read-TelemetryLast {
    $p = Get-TelemetryPaths
    if (-not $p -or -not [IO.File]::Exists($p.Last)) { return $null }
    try { return (ConvertFrom-JsonKeepOffset -Text (Read-SharedText -Path $p.Last)) } catch { return $null }
}

# (wave 28d, D2, D3) One line "<time> <text>" in <spool>/.last `notes`: what the telemetry client did or
# saw on its own - a forgetting marker whose owner was gone removed, a sender stuck. A text already
# there is not added again; the last 10 lines are kept; the flush's own fields stay (a flush carries
# the notes on). Under the telemetry lock (-IgnoreMarker, at most 1 s; re-entrant); best effort,
# never throws.
$script:TelemetryLastNotesMax = 10
function Add-TelemetryLastNote {
    param([string]$Text)
    try {
        $p = Get-TelemetryPaths
        if (-not $p -or -not $Text) { return }
        $lk = Enter-TelemetryLock -WaitMs 1000 -IgnoreMarker
        if (-not $lk.Ok) { return }
        try {
            [void][IO.Directory]::CreateDirectory($p.Spool)
            $last = Read-TelemetryLast
            $o = [ordered]@{}
            if ($last) { foreach ($pr in $last.PSObject.Properties) { $o[$pr.Name] = $pr.Value } }
            $notes = New-Object System.Collections.Generic.List[string]
            foreach ($n in @(Get-PropertyValue $last 'notes' @())) { if ($n) { $notes.Add([string]$n) } }
            if (@($notes | Where-Object { $_.EndsWith(' ' + $Text, [StringComparison]::Ordinal) }).Count -eq 0) { $notes.Add("$(Get-IsoTimestamp) $Text") }
            $o['notes'] = [object[]]@($notes | Select-Object -Last $script:TelemetryLastNotesMax)
            Write-JsonFile -Path $p.Last -Object ([pscustomobject]$o)
        } finally { Exit-TelemetryLock }
    } catch { }
}

# -Complain (codex-consult.ps1 -Task <t> -Complain, codex-telemetry.ps1 -Complain): the payload
# {app_id, app_version, instance_id, text (at most 8 KiB of UTF-8), context {consultation - the
# task's last ledger entry through the event's allowlist (ConvertTo-TelemetryDetails), or null;
# bridge_version; os; runtime}, contact (or null)} is printed in full, then `send? [y/N]` unless
# -Yes, then sent synchronously (10 s; a 429 as in Invoke-TelemetrySend). Delivered: the
# public_ref is printed. Not delivered: the payload is kept in the spool as a complaint line - the
# sender retries it. Independent of the telemetry switch (an explicit, confirmed send). Exit 0
# delivered, 1 refused or not confirmed, 3 not delivered (kept in the spool).
function Invoke-TelemetryComplaint {
    param([string]$Text, [string]$Contact = '', $Entry = $null, [switch]$Yes, [int]$TotalMs = 10000)
    $t = [string]$Text
    if (-not $t.Trim()) { Write-Host 'codex-consult: -Complain needs a text: -Complain "<what went wrong or what you miss>".' -ForegroundColor Red; return 1 }
    $tb = $script:Utf8NoBom.GetByteCount($t)
    if ($tb -gt $script:TelemetryTextMaxBytes) { Write-Host "codex-consult: the complaint's text is $tb bytes (UTF-8); the intake takes at most $($script:TelemetryTextMaxBytes) - shorten it; nothing was sent." -ForegroundColor Red; return 1 }
    $c = ([string]$Contact).Trim()
    if ($c.Length -gt 256) { Write-Host 'codex-consult: -Contact takes at most 256 characters; nothing was sent.' -ForegroundColor Red; return 1 }
    $p = Get-TelemetryPaths
    if (-not $p) { Write-Host 'codex-consult: no codex home (CODEX_HOME, else ~/.codex): no instance id and no spool; nothing was sent.' -ForegroundColor Red; return 1 }
    $u = Get-TelemetryUrl
    if ($u.Error) { Write-Host "codex-consult: $($u.Error); nothing was sent." -ForegroundColor Red; return 1 }
    # (wave 28c, D3) the salt under the telemetry lock - never while -Forget deletes
    $lk = Enter-TelemetryLock -WaitMs 5000
    if (-not $lk.Ok) { Write-Host "codex-consult: $($lk.Why); nothing was sent." -ForegroundColor Red; return 1 }
    try { $id = Get-TelemetryInstanceId -Create } finally { Exit-TelemetryLock }
    if (-not $id) { Write-Host "codex-consult: the instance id could not be made (the salt $($p.Salt)); nothing was sent." -ForegroundColor Red; return 1 }
    $payload = [pscustomobject]@{
        app_id      = $script:TelemetryAppId
        app_version = (Get-BridgeVersion)
        instance_id = $id
        text        = $t
        context     = [pscustomobject]@{
            consultation   = $(if ($Entry) { ConvertTo-TelemetryDetails $Entry } else { $null })
            bridge_version = (Get-BridgeVersion)
            os             = (Get-TelemetryOs)
            runtime        = (Get-TelemetryRuntime)
        }
        contact     = $(if ($c) { $c } else { $null })
    }
    $json = ConvertTo-Json -Depth 6 -InputObject $payload
    Write-Host "codex-consult: the complaint - exactly this JSON goes to $($u.Base)/v2/complaints:"
    Write-Host $json
    if (-not $Yes) {
        $answer = ''
        try {
            if ([Console]::IsInputRedirected) { Write-Host 'send? [y/N] ' -NoNewline; $answer = [Console]::In.ReadLine() }
            else { $answer = Read-Host 'send? [y/N]' }
        } catch { $answer = '' }
        if (([string]$answer).Trim() -notmatch '^(?i:y|yes)$') { Write-Host 'codex-consult: not sent (no confirmation; -Yes sends without asking).'; return 1 }
    }
    $r = Invoke-TelemetrySend -Url "$($u.Base)/v2/complaints" -Body $json -ConnectMs 3000 -TotalMs $TotalMs
    if ($r.Delivered) {
        $ref = ConvertTo-OneLine ([string](Get-PropertyValue $r.Json 'public_ref' ''))
        Write-Host "codex-consult: complaint delivered - public_ref $(if ($ref) { $ref } else { '(none given)' }) (quote it when you write to the maintainer)."
        return 0
    }
    # (wave 28b, D7 / F36-7, F37-5) the spool keeps the EXACT text that was shown (and would have been
    # sent now): the deferred send posts those bytes - (wave 28c, D3) under the telemetry lock, and only
    # while the instance is still the one the text names (a -Forget in between: not kept)
    $why = ''
    $lk2 = Enter-TelemetryLock -WaitMs 5000
    if (-not $lk2.Ok) { $why = $lk2.Why }
    else {
        try {
            if ((Get-TelemetryInstanceId) -cne $id) { $why = 'the instance id changed meanwhile (codex-telemetry.ps1 -Forget -Local ran)' }
            else { $why = Add-TelemetrySpoolLine -Kind 'complaint' -BodyJson $json }
        } finally { Exit-TelemetryLock }
    }
    if ($why) { Write-Host "codex-consult: not delivered ($($r.Why)); it could not be kept in the spool either ($why) - nothing was sent." -ForegroundColor Yellow; return 3 }
    Write-Host "codex-consult: not delivered ($($r.Why)); kept in the spool as a complaint line ($($p.Spool)) - exactly the JSON shown above; the sender retries it after the next consultation, or run codex-telemetry.ps1 -Flush." -ForegroundColor Yellow
    return 3
}

# (wave 28b, D9; wave 28c, D2, D3 / F42-2, F42-3, F43-1, F44-4) Delete my data. -PublicRef <ref>:
# `DELETE <intake>/v2/instances/<instance id>?public_ref=<ref>` - the intake removes every event and
# complaint of this instance (the ref is the public_ref a delivered complaint printed; the intake asks
# for it as proof). -Local: the local spool (every file of it), the salt (the next event makes a NEW
# instance id), the count of events not spooled and the salts moved aside. Independent of the switch.
#   * -PublicRef with -Local: the intake FIRST - the local deletion runs ONLY after the intake confirmed
#     the DELETE (2xx, "ok": true); any other answer leaves the salt, the spool and the counters as they
#     are, says why and exits 3 - the same command can be repeated (with the right reference). While
#     the DELETE runs the telemetry lock and the forgetting marker are held (no producer spools, no
#     sender sends in between).
#   * -Local alone: says in one line that the intake still holds what was sent (and how to remove it:
#     -Forget -PublicRef <ref> BEFORE -Local - the instance id dies with the salt), then asks
#     `remove locally? [y/N]` unless -Yes.
#   * The local deletion is atomic against producers (D3): under the telemetry lock, with the marker
#     <codex home>/telemetry-forgetting {pid, start_time, (wave 28e, E3) start_ticks, since} written
#     first and removed LAST, and
#     under the sender's lock (refused while a sender holds it). (wave 28d, D2 / F48-2) The marker is
#     removed in `finally` - a deletion that fails halfway says so (run -Forget -Local again to finish
#     it) and blocks nothing; a -Forget that is killed leaves a marker whose owner is gone, which the
#     next producer or sender removes (Resolve-TelemetryForgetting).
# Exit 0 done, 1 refused or not confirmed, 3 the intake did not confirm the deletion (nothing deleted).
function Invoke-TelemetryForget {
    param([string]$PublicRef = '', [switch]$Local, [switch]$Yes, [int]$TotalMs = 10000)
    $p = Get-TelemetryPaths
    if (-not $p) { Write-Host 'codex-telemetry: no codex home (CODEX_HOME, else ~/.codex): no instance id and no spool; nothing to forget.' -ForegroundColor Red; return 1 }
    $ref = ([string]$PublicRef).Trim()
    if (-not $ref -and -not $Local) { Write-Host 'codex-telemetry: -Forget needs -PublicRef <ref> (delete the data of this instance at the intake), -Local (remove the local spool and the salt), or both.' -ForegroundColor Red; return 1 }
    $u = $null
    $id = Get-TelemetryInstanceId
    if ($ref) {
        if ($ref -notmatch '^[A-Za-z0-9._-]{1,128}$') { Write-Host "codex-telemetry: -PublicRef '$ref' is not a public_ref (letters, digits, dot, dash, underscore); nothing was sent$(if ($Local) { ' and nothing removed' })." -ForegroundColor Red; return 1 }
        $u = Get-TelemetryUrl
        if ($u.Error) { Write-Host "codex-telemetry: $($u.Error); nothing was sent$(if ($Local) { ' and nothing removed' })." -ForegroundColor Red; return 1 }
        if (-not $id) { Write-Host "codex-telemetry: this machine has no instance id (no salt $($p.Salt)): the intake holds nothing of it; nothing was sent$(if ($Local) { ' and nothing removed (-Forget -Local alone removes the local files)' })." -ForegroundColor Red; return 1 }
    } else {
        # (D2 / F44-4) -Local alone: the intake keeps what was sent - said, then confirmed
        Write-Host "codex-telemetry: -Local removes the LOCAL data only - the intake still holds what this machine sent$(if ($id) { " (instance $id)" }); to remove it there, run codex-telemetry.ps1 -Forget -PublicRef <ref> BEFORE -Local (the instance id dies with the salt)." -ForegroundColor Yellow
        if (-not $Yes) {
            $answer = ''
            try {
                if ([Console]::IsInputRedirected) { Write-Host 'remove locally? [y/N] ' -NoNewline; $answer = [Console]::In.ReadLine() }
                else { $answer = Read-Host 'remove locally? [y/N]' }
            } catch { $answer = '' }
            if (([string]$answer).Trim() -notmatch '^(?i:y|yes)$') { Write-Host 'codex-telemetry: nothing removed (no confirmation; -Yes removes without asking).'; return 1 }
        }
    }
    if ($ref -and -not $Local) {
        $target = "$($u.Base)/v2/instances/$id`?public_ref=$([Uri]::EscapeDataString($ref))"
        Write-Host "codex-telemetry: DELETE $target"
        $r = Invoke-TelemetryRequest -Url $target -Method 'DELETE' -TotalMs $TotalMs
        if ($r.Delivered) { Write-Host "codex-telemetry: the intake deleted the data of instance $id."; return 0 }
        Write-Host "codex-telemetry: the intake did not confirm the deletion ($($r.Why)); nothing is deleted there - try again later (with the right -PublicRef)." -ForegroundColor Yellow
        return 3
    }
    # -Local (with or without -PublicRef): the telemetry lock, the marker, the sender's lock - then the
    # intake (when asked), then the local files; the marker removed last
    $lk = Enter-TelemetryLock -WaitMs 5000 -IgnoreMarker
    if (-not $lk.Ok) { Write-Host "codex-telemetry: nothing was $(if ($ref) { 'sent or ' })removed - $($lk.Why); try again." -ForegroundColor Red; return 1 }
    $flush = $null
    $removed = New-Object System.Collections.Generic.List[string]
    # (wave 28d, D2) set once the marker is (being) written: `finally` removes it again
    $markerOwned = $false
    try {
        try {
            $markerOwned = $true
            # (wave 28e, E3) the owner's start time in ticks too (full resolution); start_time stays for
            # the readers of older versions
            $ownTicks = Get-ProcessStartTicks -ProcessId $PID
            Write-Utf8NoBom -Path $p.Forgetting -Text ((ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ pid = $PID; start_time = [string](Get-ProcessStartIso -ProcessId $PID); start_ticks = $(if ($null -ne $ownTicks -and $ownTicks -gt 0) { [long]$ownTicks } else { $null }); since = (Get-IsoTimestamp) })) + "`n")

        } catch { Write-Host "codex-telemetry: nothing was $(if ($ref) { 'sent or ' })removed - the marker $($p.Forgetting) could not be written ($(ConvertTo-OneLine $_.Exception.Message))." -ForegroundColor Red; return 1 }
        if ([IO.Directory]::Exists($p.Spool)) {
            $flush = Enter-TelemetryFlushLock -Path $p.Lock
            if (-not $flush.Ok) {
                Write-Host "codex-telemetry: nothing was $(if ($ref) { 'sent or ' })removed - $($flush.Why); try again when it is done." -ForegroundColor Red
                $flush = $null
                return 1
            }
        }
        if ($ref) {
            $target = "$($u.Base)/v2/instances/$id`?public_ref=$([Uri]::EscapeDataString($ref))"
            Write-Host "codex-telemetry: DELETE $target"
            $r = Invoke-TelemetryRequest -Url $target -Method 'DELETE' -TotalMs $TotalMs
            if (-not $r.Delivered) {
                Write-Host "codex-telemetry: the intake did not confirm the deletion ($($r.Why)); NOTHING was deleted - not there and not here: the salt (instance $id), the spool and the counters are kept, so the same command can be repeated (with the right -PublicRef)." -ForegroundColor Yellow
                return 3
            }
            Write-Host "codex-telemetry: the intake deleted the data of instance $id."
        }
        if ([IO.Directory]::Exists($p.Spool)) {
            foreach ($f in @(Get-ChildItem -LiteralPath $p.Spool -File -Force | Where-Object { $_.FullName -ne $p.Lock })) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $removed.Add($f.Name) }
        }
        if ($flush) { Exit-TelemetryFlushLock -Path $p.Lock -Token $flush.Token; $flush = $null }
        try { if ([IO.Directory]::Exists($p.Spool)) { Remove-Item -LiteralPath $p.Spool -Recurse -Force -ErrorAction Stop } } catch { }
        $aside = @(Get-ChildItem -LiteralPath $p.Home -File -Filter 'telemetry-salt.bad-*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        # (wave 28e, E2) every not-spooled file: each producer's and the legacy one
        $nsFiles = @(foreach ($nf in (Get-TelemetryNotSpooledFiles -Paths $p)) { $nf.Path })
        foreach ($f in @(@($p.Salt) + $nsFiles + $aside)) { if ([IO.File]::Exists($f)) { Remove-Item -LiteralPath $f -Force -ErrorAction Stop; $removed.Add([IO.Path]::GetFileName($f)) } }
        # the marker LAST
        [IO.File]::Delete($p.Forgetting)
        Write-Host "codex-telemetry: removed locally - $(if ($removed.Count -gt 0) { $removed -join ', ' } else { 'nothing (there was no spool and no salt)' }); the next event makes a new instance id."
        return 0
    } catch {
        Write-Host "codex-telemetry: the local deletion did not finish ($(ConvertTo-OneLine $_.Exception.Message))$(if ($removed.Count -gt 0) { "; removed so far: $($removed -join ', ')" }); run codex-telemetry.ps1 -Forget -Local again to finish it." -ForegroundColor Red
        return 1
    } finally {
        # (wave 28d, D2) the marker never outlives this -Forget
        if ($markerOwned) { try { if ([IO.File]::Exists($p.Forgetting)) { [IO.File]::Delete($p.Forgetting) } } catch { } }
        if ($flush) { Exit-TelemetryFlushLock -Path $p.Lock -Token $flush.Token }
        Exit-TelemetryLock
    }
}

# ----------------------------------------------------------------------------- the rating backfill (R24)
#
# A mark of findings.json `ratings` whose event went into the spool carries `telemetry_sent` (unix
# seconds, UTC): codex-findings.ps1 -Rate sets it when it spools the mark's event,
# codex-telemetry.ps1 -BackfillRatings when it spools a mark given before. A mark that has it is
# never sent again; a re-rating replaces the mark (and sends its own event).

# The ledger entry a mark rates - as -Rate recorded it: the entry whose consult_id equals the mark's
# (case-insensitive), or - a mark without one (recorded before wave 26) - the entry whose n equals
# the mark's n. $null when none (never a guess).
function Find-RatingLedgerEntry {
    param($Consults, $Mark)
    $cid = [string](Get-PropertyValue $Mark 'consult_id' '')
    $mn = 0
    $hasN = [int]::TryParse([string](Get-PropertyValue $Mark 'n' ''), [ref]$mn)
    $found = $null
    foreach ($c in @($Consults | Where-Object { $null -ne $_ })) {
        if ($cid) {
            if ([string](Get-PropertyValue $c 'consult_id' '') -ieq $cid) { $found = $c }
        } elseif ($hasN) {
            $v = 0
            if ([int]::TryParse([string](Get-PropertyValue $c 'n' ''), [ref]$v) -and $v -eq $mn) { $found = $c }
        }
    }
    return $found
}

# Do two marks name the same rating: the same consultation (consult_id when both have one, else n)
# and the same `when` (the instant)?
function Test-RatingMarkSame {
    param($A, $B)
    $ia = [string](Get-PropertyValue $A 'consult_id' '')
    $ib = [string](Get-PropertyValue $B 'consult_id' '')
    $same = $(if ($ia -and $ib) { $ia -ieq $ib } else { [string](Get-PropertyValue $A 'n' '') -eq [string](Get-PropertyValue $B 'n' '') })
    if (-not $same) { return $false }
    $wa = ConvertTo-WhenOffset (Get-PropertyValue $A 'when' $null)
    $wb = ConvertTo-WhenOffset (Get-PropertyValue $B 'when' $null)
    if ($null -eq $wa -or $null -eq $wb) { return ([string](Get-PropertyValue $A 'when' '') -ceq [string](Get-PropertyValue $B 'when' '')) }
    return ($wa.UtcTicks -eq $wb.UtcTicks)
}

# Writes `telemetry_sent` = $Sent into the mark of <task>/findings.json that is $Mark (the same
# consultation and `when`, Test-RatingMarkSame) and has none yet - through the task's store commit
# (the write lock, findings.json re-read under it). '' when written, else why not. For -Rate's
# event spooled only by the retry after the locks.
function Set-RatingTelemetrySent {
    param([string]$TaskDir, [string]$Task, $Mark, [long]$Sent)
    $commit = $null
    try {
        $commit = Enter-StoreCommit -TaskDir $TaskDir -Task $Task -TimeoutSec (Get-WriteLockTimeout) -NoSessions
        if (-not $commit.Acquired) { return $commit.Message }
        foreach ($m in @(Get-PropertyValue $commit.Findings 'ratings' @())) {
            if ($null -eq $m -or $null -ne (Get-PropertyValue $m 'telemetry_sent' $null)) { continue }
            if (Test-RatingMarkSame $m $Mark) {
                $m | Add-Member -NotePropertyName 'telemetry_sent' -NotePropertyValue $Sent -Force
                $null = Complete-StoreCommit -Commit $commit -Findings
                return ''
            }
        }
        return 'the mark is no longer in findings.json (rated again meanwhile)'
    } catch { return (ConvertTo-OneLine $_.Exception.Message) } finally { $null = Exit-StoreCommit -Commit $commit }
}

# codex-telemetry.ps1 -BackfillRatings [-DryRun]: every mark of every task of $CollabRoot
# (<task>/findings.json `ratings`) without `telemetry_sent` gets its rating event spooled ONCE -
# the ledger entry looked up as -Rate recorded it (Find-RatingLedgerEntry; none: the mark is
# SKIPPED and counted, never a guessed reviewer; a mark that is not yes | partly | no or whose
# `when` does not parse is skipped too), the event built by New-TelemetryRatingEvent with the mark's
# `when` as -RatedAt (client_time) and its consult_when (age_days), spooled with up to 5 s, and
# `telemetry_sent` written into the mark - per task under the task's store commit (the write lock,
# findings.json re-read under it, written once at the end). A spool failure stops that task's
# remaining marks (they stay unsent: the next run sends them). -DryRun reads without a lock, prints
# per event the vendor class, the model, the mark and the age (never a text) and writes nothing.
# Telemetry off: refused, nothing read or written. One line per task that has marks, then the total;
# unless -DryRun the detached sender starts when something was spooled. Exit 0 done, 1 refused or
# something not spooled.
function Invoke-TelemetryBackfillRatings {
    param([string]$CollabRoot, $Switch, [switch]$DryRun)
    if (-not $Switch -or -not $Switch.On) {
        Write-Host "codex-telemetry: telemetry is off ($($Switch.Source)): -BackfillRatings sends nothing and writes nothing - switch it on (CODEX_CONSULT_TELEMETRY unset or on, or -Telemetry on) to backfill." -ForegroundColor Red
        return 1
    }
    if (-not $DryRun -and -not (Get-TelemetryPaths)) {
        Write-Host 'codex-telemetry: no codex home (CODEX_HOME, else ~/.codex): nothing can be spooled.' -ForegroundColor Red
        return 1
    }
    $verb = $(if ($DryRun) { 'would send' } else { 'sent' })
    $tot = [pscustomobject]@{ Sent = 0; Already = 0; Skipped = 0; Failed = 0; Tasks = 0 }
    $taskDirs = @()
    if ([IO.Directory]::Exists($CollabRoot)) {
        $taskDirs = @(Get-ChildItem -LiteralPath $CollabRoot -Directory -Force | Where-Object { $_.Name -match '^[A-Za-z0-9][A-Za-z0-9._-]*$' -and [IO.File]::Exists((Join-Path $_.FullName 'findings.json')) } | Sort-Object Name)
    }
    foreach ($td in $taskDirs) {
        $task = $td.Name
        # a first look without a lock: a task without marks is not listed, one whose marks are all
        # sent takes no lock
        $peek = Read-JsonStore -Path (Join-Path $td.FullName 'findings.json')
        $marks = @(@(Get-PropertyValue $peek 'ratings' @()) | Where-Object { $null -ne $_ })
        if ($marks.Count -eq 0) { continue }
        $tot.Tasks++
        $sent = 0; $already = 0; $skipped = 0; $failed = 0; $why = ''
        $commit = $null
        $store = $peek
        $sessions = $null
        if ($DryRun -or @($marks | Where-Object { $null -eq (Get-PropertyValue $_ 'telemetry_sent' $null) }).Count -eq 0) {
            $sessions = Read-JsonStore -Path (Join-Path $td.FullName 'sessions.json')
        } else {
            $commit = Enter-StoreCommit -TaskDir $td.FullName -Task $task -TimeoutSec (Get-WriteLockTimeout)
            if (-not $commit.Acquired) {
                Write-Host "codex-telemetry: ${task}: not processed - $($commit.Message)" -ForegroundColor Yellow
                $tot.Failed++
                continue
            }
            $store = $commit.Findings
            $sessions = $commit.Sessions
        }
        try {
            $consults = @(Get-PropertyValue (Get-PropertyValue $sessions 'codex' $null) 'consults' @())
            $changed = $false
            foreach ($m in @(Get-PropertyValue $store 'ratings' @())) {
                if ($null -eq $m) { continue }
                if ($null -ne (Get-PropertyValue $m 'telemetry_sent' $null)) { $already++; continue }
                $useful = ([string](Get-PropertyValue $m 'useful' '')).Trim().ToLowerInvariant()
                $ratedAt = ConvertTo-WhenOffset (Get-PropertyValue $m 'when' $null)
                $entry = Find-RatingLedgerEntry -Consults $consults -Mark $m
                if ($null -eq $entry -or $script:TelemetryRatingMarks -cnotcontains $useful -or $null -eq $ratedAt) { $skipped++; continue }
                $cw = Get-PropertyValue $m 'consult_when' $null
                if ($DryRun) {
                    $d = ConvertTo-TelemetryRatingDetails -Entry $entry -Mark $useful -RatedAt $ratedAt -ConsultWhen $cw
                    Write-Host "codex-telemetry: would send: $($d.provider) / $($d.model) ($($d.engine)), purpose $($d.purpose), mark $($d.mark), age_days $($d.age_days), client_time $($ratedAt.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ', $script:Invariant))"
                    $sent++
                    continue
                }
                if ($why) { $failed++; continue }
                $r = Add-TelemetryEvent -Entry $entry -Switch $Switch -WaitMs $script:TelemetrySpoolWaitMs -RatingMark $useful -RatedAt $ratedAt -ConsultWhen $cw
                if ($r.Why) { $why = $r.Why; $failed++; continue }
                $m | Add-Member -NotePropertyName 'telemetry_sent' -NotePropertyValue ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Force
                $changed = $true
                $sent++
            }
            if ($changed) { $null = Complete-StoreCommit -Commit $commit -Findings }
        } finally { $null = Exit-StoreCommit -Commit $commit }
        $tot.Sent += $sent; $tot.Already += $already; $tot.Skipped += $skipped; $tot.Failed += $failed
        $line = "codex-telemetry: ${task}: $verb $sent, already $already, skipped $skipped$(if ($failed -gt 0) { "; not spooled $failed ($why) - they stay unsent" })"
        if ($failed -gt 0) { Write-Host $line -ForegroundColor Yellow } else { Write-Host $line }
    }
    Write-Host "codex-telemetry: total: $verb $($tot.Sent), already $($tot.Already), skipped $($tot.Skipped)$(if ($tot.Failed -gt 0) { ", not spooled or not processed $($tot.Failed)" }) in $($tot.Tasks) task(s) with marks under $CollabRoot$(if ($tot.Skipped -gt 0) { ' (skipped: no ledger entry for the mark, or a mark that is not yes|partly|no or has no time)' })"
    if ($DryRun) {
        Write-Host 'codex-telemetry: dry run - nothing was spooled or written.'
    } elseif ($tot.Sent -gt 0) {
        $sw = Start-TelemetrySender
        if ($sw) { Write-Host "codex-telemetry: the sender did not start ($sw) - the next consultation's sender, or codex-telemetry.ps1 -Flush, delivers the spool." -ForegroundColor Yellow }
        else { Write-Host 'codex-telemetry: the sender started (detached) - codex-telemetry.ps1 -Status shows the result.' }
    }
    return $(if ($tot.Failed -gt 0) { 1 } else { 0 })
}
