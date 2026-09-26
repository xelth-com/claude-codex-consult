<#
.SYNOPSIS
    Shared helpers for codex-consult.ps1 and codex-findings.ps1. Dot-source it:

        . (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

.DESCRIPTION
    Dot-sourcing runs this file in the caller's scope, so the $script: variables set
    here belong to the calling script. A caller may set $script:ToolName BEFORE
    dot-sourcing to change the prefix of Stop-WithError messages.

    Contents:
      * text/JSON I/O    Write-Utf8NoBom, Write-JsonFile, Read-SharedText
      * errors, git      Stop-WithError, Get-GitOutput, Invoke-GitCapture
      * paths            Resolve-RepoRoot, Resolve-CollabRoot, Get-RepoRelativePath
      * fingerprints     Get-FileSha256, Get-RevisionInfo, Get-ArtifactHashes
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
                         known reset time block until then), Get-ConsultClock
      * reviewer roster  Get-RosterPath, Read-ReviewerRoster (fail-closed validation),
                         Find-RosterEntry, Get-PreflightVerdict, Format-QuotaWarning,
                         Select-RosterReviewer (the walk), Select-PanelMembers (-Panel),
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
                         members' .consult.pending-<NN>.json)
      * processes        Stop-ProcessTree, ConvertTo-ProcArg, Format-Argv

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

# Start-Process holds the stdout/stderr redirection handles for a short while after
# the child exits, so a plain Get-Content can fail with "the process cannot access
# the file ... because it is being used by another process" - observed on a
# fast-failing codex run. Read with FileShare.ReadWrite (+ Delete, so an atomic
# replace of the file is not blocked by this reader) and retry briefly.
function Read-SharedText {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            try {
                $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding($false)), $true)
                try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
            } finally { $fs.Dispose() }
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    return ''
}

function Get-IsoTimestamp {
    param([datetime]$When = (Get-Date))
    return $When.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant)
}

function Stop-WithError {
    param([string]$Message)
    Write-Host "$($script:ToolName): $Message" -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------------------------- git

# Git is optional and every call here is allowed to fail (no repo, no commits yet,
# git not installed). Windows PowerShell turns a native command's stderr into a
# terminating NativeCommandError while $ErrorActionPreference is 'Stop', so relax it
# for the duration of the call and report failure as $null.
function Get-GitOutput {
    param([string]$Root, [string[]]$GitArgs)
    $all = @('-C', $Root) + $GitArgs
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git @all 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return $out
    } catch {
        return $null
    } finally {
        $ErrorActionPreference = $previous
    }
}

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
# be started, else { ExitCode; Bytes }.
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
            return [pscustomobject]@{ ExitCode = $p.ExitCode; Bytes = $ms.ToArray() }
        } finally {
            $p.Dispose()
        }
    } catch {
        return $null
    }
}

# ----------------------------------------------------------------------------- paths

# The working directory of the caller is the project being discussed, not the
# directory the scripts live in (a plugin installs them outside the project).
function Resolve-RepoRoot {
    param([string]$Cwd)
    $top = Get-GitOutput -Root $Cwd -GitArgs @('rev-parse', '--show-toplevel')
    if ($top) {
        $first = ([string]@($top)[0]).Trim()
        if ($first -and (Test-Path -LiteralPath $first)) {
            return (Resolve-Path -LiteralPath $first).Path
        }
    }
    # Not a git repository: fall back to the current directory.
    return $Cwd
}

# Relative -CollabDir resolves against the repository root.
function Resolve-CollabRoot {
    param([string]$RepoRoot, [string]$CollabDir)
    $p = $CollabDir
    if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $RepoRoot $p }
    return [IO.Path]::GetFullPath($p)
}

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

function Get-PropertyValue {
    param($Object, [string]$Name, $Default = '')
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name] -and $null -ne $Object.$Name) { return $Object.$Name }
    return $Default
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

function ConvertTo-OneLine {
    param([string]$Text)
    if (-not $Text) { return '' }
    return (($Text -replace '\s+', ' ').Trim())
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

function Test-IsJsonObject {
    param($Value)
    return ($Value -is [System.Management.Automation.PSCustomObject])
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

function ConvertTo-JsonText {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [datetime]) { return $Value.ToString('o', $script:Invariant) }
    if ($Value -is [DateTimeOffset]) { return $Value.ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFFzzz', $script:Invariant) }
    return [string]$Value
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
    param($Config, [string]$Provider = '', [string]$Model = '', [string]$OpenAiBaseUrl = '', [string]$Engine = 'codex', [string]$Launcher = '')
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
    }
    # Another engine than codex (Resolve-EngineIdentity): no Codex config lookup at all.
    if ($Engine -and $Engine -ne 'codex') { return (Resolve-EngineIdentity -Identity $id -Engine $Engine -Provider $Provider -Model $Model -Launcher $Launcher) }
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
function Resolve-EngineIdentity {
    param($Identity, [string]$Engine, [string]$Provider, [string]$Model, [string]$Launcher)
    $id = $Identity
    $id.Engine = $Engine
    $spec = Get-EngineSpec -Name $Engine
    if (-not $spec) {
        $id.Error = "unknown engine '$Engine' (engines: $($script:EngineNames -join ', '))"
        $id.Lineage = Format-Lineage -Provider $id.Provider -Model $id.Model
        return $id
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
    # (wave 23) the engine's own fields - muse: credential_mechanism (D4)
    if ($spec.Adapter -and $spec.Adapter.PSObject.Properties['IdentityConfig'] -and $spec.Adapter.IdentityConfig) {
        $extra = & $spec.Adapter.IdentityConfig
        foreach ($k in @($extra.Keys)) { $pc | Add-Member -NotePropertyName ([string]$k) -NotePropertyValue $extra[$k] }
    }
    $id.ProviderConfig = $pc
    $id.Display = "engine $Engine ($(if ($Launcher) { $Launcher } else { "$($spec.Command) CLI not found" }))"
    $id.ConfigPath = ''
    $id.Lineage = Format-Lineage -Provider $id.Provider -Model $id.Model
    if (-not $id.Error) {
        $id.Resolved = $true
        $id.CompatString = [string]$spec.CompatString
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
    $raw = [string]$env:CODEX_CONSULT_NOW
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

# `<launcher> login status` with a timeout; stdout and stderr are both read (the status
# line may come on either) and decoded as UTF-8 (the Codex CLI writes UTF-8; the default
# would be the console code page). { State ok|missing|unknown; Reason; Detail }.
function Get-CodexLoginStatus {
    param([string]$Launcher, [int]$TimeoutSec = 15)
    if (-not $Launcher) { return (New-CredentialResult 'unknown' 'codex CLI not found, `codex login status` could not run') }
    $p = $null
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Launcher
        $psi.Arguments = 'login status'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = $script:Utf8NoBom
        $psi.StandardErrorEncoding = $script:Utf8NoBom
        $p = [System.Diagnostics.Process]::Start($psi)
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
#   LaunchBlock (optional) the launch invariant: '' or the refusal (Get-EngineLaunchBlock)
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
$script:EngineNames = @('codex', 'agy', 'muse')
$script:Engines = @{
    'codex' = [pscustomobject]@{
        Name = 'codex'; Label = 'Codex'; Prefix = 'codex'; Command = 'codex'; ExeEnv = 'CODEX_CONSULT_EXE'
        LauncherNames = $(if ($script:OnWindows) { @('codex.exe', 'codex.cmd', 'codex.bat', 'codex') } else { @('codex') })
        InstallLaunchers = @()
        Modes = @('new', 'resume', 'fork'); DefaultMode = ''; Sandboxes = @('read-only', 'workspace-write')
        Transports = @('output-schema', 'prompt-only'); HostName = ''; CompatString = ''; DefaultProvider = ''; ModelExample = 'gpt-5.1'
        DenialRetry = $false; PromptTransport = 'stdin'; LocalSignIn = $false; StepsFlag = ''; HasUsage = $true
        PromptVia = 'prompt on stdin'; ReplySource = ''; SchemaFlag = '--output-schema'; ThreadFlag = ''; ThreadNoun = 'thread'
        ReadOnlyNote = ''; SandboxRecord = ''; TreeNote = ''; ToolsLine = ''
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
        # agy's print mode auto-denies a tool it cannot grant and then ends the turn with no
        # output (F11), and its --sandbox does not block file writes (F12): say both up front.
        ToolsLine = 'Tools: you may read files of the repository; you have NO permission to run commands in this consultation - never call run_command; make NO file changes; a check that needs a command belongs under `## Requested checks`.'
        Adapter = [pscustomobject]@{ Argv = 'New-AgyArgv'; Stdin = 'ConvertTo-AgyStdin'; Events = 'Read-AgyEvents'; Outcome = 'Get-AgyTurnOutcome'; Credential = 'Get-AgyModelsStatus'; Harness = ''; IdentityConfig = ''; LaunchBlock = '' }
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
        ToolsLine = 'Tools: you may read files of the repository (read_file); writing files, the shell and the web tools are disabled in this consultation (--disable-write --disable-shell --disable-web-tools) - do not try them; make NO file changes; a check that needs a command belongs under `## Requested checks`.'
        Adapter = [pscustomobject]@{ Argv = 'New-MuseArgv'; Stdin = 'ConvertTo-MuseStdin'; Events = 'Read-MuseEvents'; Outcome = 'Get-MuseTurnOutcome'; Credential = 'Get-MuseSignIn'; Harness = 'Get-MuseHarness'; IdentityConfig = 'Get-MuseIdentityConfig'; LaunchBlock = 'Get-MuseLaunchBlock' }
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
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Launcher
        $psi.Arguments = 'models'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = $script:Utf8NoBom
        $psi.StandardErrorEncoding = $script:Utf8NoBom
        $p = [System.Diagnostics.Process]::Start($psi)
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
# listing.
function Get-EngineCredential {
    param([string]$Engine, [string]$Launcher, [hashtable]$LoginCache = $null, [switch]$NoNetwork, [int]$TimeoutSec = 0, $Health = $null)
    $spec = Get-EngineSpec -Name $Engine
    if (-not $spec -or -not $spec.Adapter) { return (New-CredentialResult 'unknown' "no credential check for engine '$Engine'") }
    if (-not $Launcher) { return (New-CredentialResult 'missing' "$($spec.Command) CLI not found on PATH") }
    if ($Health -and $Health.PSObject.Properties['RecentUsable'] -and $Health.RecentUsable) {
        return (New-CredentialResult 'ok' "signed in (usable reply $($Health.RecentUsable.AgeMinutes) min ago)")
    }
    if ($NoNetwork -and -not ($spec.PSObject.Properties['LocalSignIn'] -and $spec.LocalSignIn)) { return [pscustomobject]@{ State = 'unknown'; Reason = 'sign-in not checked'; Detail = 'not checked (launcher present; run codex-providers.ps1)' } }
    if ($TimeoutSec -le 0) {
        $TimeoutSec = $script:AgyModelsTimeoutSec
        $hook = ([string]$env:CODEX_CONSULT_TEST_LOGIN_TIMEOUT).Trim()
        if ($hook -match '^[0-9]+$' -and [int]$hook -gt 0) { $TimeoutSec = [int]$hook }
    }
    $key = "engine:$Engine|$Launcher"
    if ($LoginCache -and $LoginCache.ContainsKey($key)) { return $LoginCache[$key] }
    $r = & $spec.Adapter.Credential -Launcher $Launcher -TimeoutSec $TimeoutSec
    if ($LoginCache) { $LoginCache[$key] = $r }
    return $r
}

# ---- engine turns (every engine other than codex)

# One turn of an engine other than codex (wave 23, D1): what its adapter's Argv receives -
# { Model; Mode (new | resume | denial-retry | format-repair); Thread (the conversation / session
# to continue, '' = a new one); PromptFile (this turn's own prompt file: muse reads it through
# --prompt-file, agy's prompt travels on stdin); Schema (the schema path, '' = none); Effort (the
# value to send, $null = nothing); NativeEffort (-NativeEffort, verbatim); MaxSteps (muse
# --max-model-steps, 0 = not sent) }.
function New-EngineTurnOptions {
    param([string]$Model, [string]$Mode = 'new', [string]$Thread = '', [string]$PromptFile = '', [string]$Schema = '', $Effort = $null, [string]$NativeEffort = '', [int]$MaxSteps = 0)
    return [pscustomobject]@{ Model = $Model; Mode = $Mode; Thread = $Thread; PromptFile = $PromptFile; Schema = $Schema; Effort = $Effort; NativeEffort = $NativeEffort; MaxSteps = $MaxSteps }
}

# The launch invariant of an engine (wave 23, D4): '' or the refusal. Checked when a roster
# entry is selected (the walk and the panel skip it, under -SkipPreflight too), when the run's
# engine is known (a refusal; -SkipPreflight never bypasses it) and again right before every
# Start-Process of a turn. muse: Get-MuseLaunchBlock (billing); other engines: none.
function Get-EngineLaunchBlock {
    param([string]$Engine)
    $spec = Get-EngineSpec -Name $Engine
    if (-not $spec -or -not $spec.Adapter -or -not $spec.Adapter.PSObject.Properties['LaunchBlock'] -or -not $spec.Adapter.LaunchBlock) { return '' }
    return [string](& $spec.Adapter.LaunchBlock)
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
        $p = [System.Diagnostics.Process]::Start($psi)
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
    # (-ExpectModel: the adapter contract; agy's result names no served model - not checked)
    param($Events, [int]$ExitCode, [string]$StderrText = '', [string]$Pre = '', [string]$ExpectThread = '', [string]$ExpectModel = '')
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
# backend and path for this process. { Backend (file | keychain); State (ok | missing |
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
    $backend = ([string]$env:TBH_CREDENTIAL_BACKEND).Trim().ToLowerInvariant()
    $path = Get-MuseAuthPath
    $key = "$backend|$path"
    if ($script:MuseCredentialCache.ContainsKey($key)) { return $script:MuseCredentialCache[$key] }
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
# it; there is no roster opt-out and no override flag.
$script:MuseApiKeyVariables = @('META_API_KEY', 'MODEL_API_KEY')
function Get-MuseLaunchBlock {
    foreach ($name in $script:MuseApiKeyVariables) {
        $v = [Environment]::GetEnvironmentVariable($name)
        if ($v -and $v.Trim()) { return "$name is set: a muse run would bill per token instead of the Muse Code subscription; unset it (the muse process would inherit it)" }
    }
    $c = Get-MuseCredentialInfo
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
    param($Events, [int]$ExitCode, [string]$StderrText = '', [string]$Pre = '', [string]$ExpectThread = '', [string]$ExpectModel = '')
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
        if ($k -eq 'auth' -and $Message -match $script:QuotaTextPattern) { return 'quota' }
        if ($Message -match $script:FailureClassPatterns[$k]) { return $k }
    }
    return 'unknown'
}

# The provider's own error inside a failure text: an SSE payload `data:{"error":{...}}`
# (MiMo sends its rejections that way) or a bare `{"error":{...}}` -> error.message and
# error.code; otherwise the text itself. { Code; Message }.
function ConvertFrom-ProviderErrorText {
    param([string]$Text)
    $r = [pscustomobject]@{ Code = ''; Message = (ConvertTo-OneLine $Text) }
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

# The ledger's provider_failure of a failed run: { class; code; message (<= 200); when;
# retry_after }. $Texts: the evidence in order of preference (the event-stream error,
# stderr, the bridge outcome); the first that holds a provider error payload wins, else the
# first non-empty. retry_after: the reset time the chosen message names (Get-RetryAfter,
# read from the FULL message before it is cut to 200 characters), ISO with offset, or $null.
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
    return [pscustomobject]@{
        class       = $(if ($Class) { $Class } else { (Get-ProviderFailureClass "$($chosen.Code) $($chosen.Message)") })
        code        = [string]$chosen.Code
        message     = $msg
        when        = (Get-IsoTimestamp $now)
        retry_after = $(if ($null -ne $retryAfter) { Format-OffsetIso $retryAfter } else { $null })
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

function ConvertTo-WhenOffset {
    param($Value)
    if ($Value -is [DateTimeOffset]) { return $Value }
    if ($Value -is [datetime]) { return [DateTimeOffset]$Value }
    $at = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse([string]$Value, $script:Invariant, [System.Globalization.DateTimeStyles]::None, [ref]$at)) { return $at }
    return $null
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
#                blocks: its RetryAfter lies in the future, or it has no RetryAfter and is
#                <= 60 min old (a RetryAfter in the past clears it)
#   QuotaKnown   [bool] Quota is set and names its reset time (RetryAfter)
#   LastLimit    the newest quota failure <= 24 h old (informational)
#   LastFailure  the newest failure of any class <= 24 h old (informational)
#   RecentUsable the newest usable reply <= 60 min old (wave 18: an engine's sign-in is then
#                evidenced without a network check - Get-EngineCredential)
# Each record is $null or { Class; Code; Message; When; AgeMinutes (a `when` in the future
# counts as now: 0); RetryAfter (DateTimeOffset or $null: provider_failure.retry_after, else
# Get-RetryAfter -ReferenceOffset on the recorded message with the failure's `when` as
# reference); RetryAfterIso ('' when none); RetryAfterBasis ('ledger' | 'message (reference
# offset)' | ''); Until (RetryAfter, else When + 60 min) }.
function Get-EndpointHealth {
    param([object[]]$Consults, [string]$Fingerprint, [datetime]$UtcNow = [datetime]::UtcNow)
    $h = [pscustomobject]@{ Auth = $null; Quota = $null; QuotaKnown = $false; LastLimit = $null; LastFailure = $null; RecentUsable = $null }
    if (-not $Fingerprint) { return $h }
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($c in @($Consults | Where-Object { $null -ne $_ })) {
        $rev = Get-PropertyValue $c 'reviewer' $null
        $fp = if ($null -eq $rev) { $script:BuiltinOpenAiFingerprint } else { [string](Get-PropertyValue $rev 'provider_fingerprint' '') }
        if (-not $fp -or $fp -ne $Fingerprint) { continue }
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
        $rec = [pscustomobject]@{ At = $at; Order = $order; N = $entryN; Ok = ($outcome -eq 'usable reply'); Class = ''; Code = ''; Message = ''; When = $at.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant); AgeMinutes = [int][Math]::Max(0, [Math]::Floor($age)); Age = $age; RetryAfter = $null; RetryAfterIso = ''; RetryAfterBasis = ''; Until = $at.AddMinutes(60) }
        if (-not $rec.Ok) {
            $reference = $at
            $pf = Get-PropertyValue $c 'provider_failure' $null
            if ($null -ne $pf) {
                $rec.Class = [string](Get-PropertyValue $pf 'class' 'unknown')
                # An entry recorded as auth whose message says usage limit / quota / rate limit
                # counts as quota (Get-ProviderFailureClass's rule, applied when the ledger is
                # READ): a 401/403 with a usage-limit text recorded before that rule existed
                # (Kimi Code's 5-hour limit) stops refusing the endpoint for 24 h as an auth
                # failure - without anyone editing the ledger.
                if ($rec.Class -eq 'auth' -and ([string](Get-PropertyValue $pf 'message' '')) -match $script:QuotaTextPattern) { $rec.Class = 'quota' }
                $rec.Code = [string](Get-PropertyValue $pf 'code' '')
                $rec.Message = [string](Get-PropertyValue $pf 'message' '')
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
            }
            # an entry recorded without retry_after: read the reset time from its message now
            if ($null -ne $rec.RetryAfter) { $rec.RetryAfterBasis = 'ledger' }
            else {
                $rec.RetryAfter = Get-RetryAfter -Message $rec.Message -Reference $reference -ReferenceOffset
                if ($null -ne $rec.RetryAfter) { $rec.RetryAfterBasis = 'message (reference offset)' }
            }
            if ($null -ne $rec.RetryAfter) {
                $rec.RetryAfterIso = Format-OffsetIso $rec.RetryAfter
                $rec.Until = $rec.RetryAfter
            }
            if ($rec.Message.Length -gt 100) { $rec.Message = $rec.Message.Substring(0, 100) }
        }
        $records.Add($rec)
    }
    $sorted = @($records | Sort-Object -Property @{ Expression = { $_.Order }; Descending = $true }, @{ Expression = { $_.N }; Descending = $true })
    $auth = @($sorted | Where-Object { $_.Ok -or $_.Class -eq 'auth' }) | Select-Object -First 1
    if ($auth -and -not $auth.Ok -and $auth.AgeMinutes -le 24 * 60) { $h.Auth = $auth }
    $quota = @($sorted | Where-Object { $_.Ok -or $_.Class -eq 'quota' }) | Select-Object -First 1
    if ($quota -and -not $quota.Ok) {
        if ($null -ne $quota.RetryAfter) {
            if ($quota.RetryAfter.UtcDateTime -gt $UtcNow) { $h.Quota = $quota }
        } elseif ($quota.AgeMinutes -le 60) {
            $h.Quota = $quota
        }
    }
    $h.QuotaKnown = [bool]($h.Quota -and $null -ne $h.Quota.RetryAfter)
    $h.LastLimit = @($sorted | Where-Object { -not $_.Ok -and $_.Class -eq 'quota' -and $_.AgeMinutes -le 24 * 60 }) | Select-Object -First 1
    $h.LastFailure = @($sorted | Where-Object { -not $_.Ok -and $_.AgeMinutes -le 24 * 60 }) | Select-Object -First 1
    $h.RecentUsable = @($sorted | Where-Object { $_.Ok -and $_.Age -le 60 }) | Select-Object -First 1
    return $h
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
#                 env_key still needs the variable)
#   panel         optional, "always" (the default) or "weighty": with -Panel a weighty
#                 reviewer joins only on the weighty purposes (framing, decision,
#                 core-contract, acceptance, stuck) or with -PanelAll. The single-reviewer
#                 walk ignores it.
#   engine        optional (0.4.0), "codex" (the default) or "agy": the CLI that carries the
#                 consultation. For agy the provider is a free label (the lineage's
#                 provider, e.g. "gemini"), the model is REQUIRED (the full id with its
#                 tier), codex_config and auth are refused, and one label names one engine
#                 across the roster. Two entries with the same label and different models
#                 are fine (e.g. a "panel": "weighty" entry on the pro model).
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
#   -Panel            every available entry (Select-PanelMembers) runs the same brief, each
#                     as a consultation of its own; members of different endpoints at once,
#                     of one endpoint one after another (Get-PanelPlan, roster "parallel").

# Where the roster comes from: { Path ('' when none); FromEnv (CODEX_CONSULT_ROSTER named
# it: it must exist); Disabled (CODEX_CONSULT_ROSTER=none) }.
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
# ('' = not given); CodexConfig (string[], already expanded and quoted); Auth ('' | 'none');
# Panel ('always' | 'weighty'); Engine ('codex' | 'agy'); EngineDeclared (the entry names
# its engine) }); Parallel (hashtable, ordinal keys: provider label -> n from the top-level
# "parallel"; empty when absent); Error }. Error is the whole refusal message; the caller
# stops on it.
# $Location: Get-RosterPath (the default).
function Read-ReviewerRoster {
    param($Location = $null)
    if ($null -eq $Location) { $Location = Get-RosterPath }
    $Path = [string]$Location.Path
    $r = [pscustomobject]@{ Exists = $false; Path = $Path; Disabled = [bool]$Location.Disabled; Entries = [object[]]@(); Parallel = (New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)); Error = '' }
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
            if (@('roster_version', 'reviewers', 'parallel') -cnotcontains $prop.Name) { $why = "unknown key '$($prop.Name)' at the top level (allowed: roster_version, reviewers, parallel)"; break }
        }
    }
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
                if (@('provider', 'model', 'codex_config', 'auth', 'panel', 'engine') -cnotcontains $prop.Name) { $why = "$at has an unknown key '$($prop.Name)' (allowed: provider, model, codex_config, auth, panel, engine)"; break }
            }
            if ($why) { break }
            $provider = $null
            if ($item.PSObject.Properties['provider']) { $provider = $item.provider }
            if (-not ($provider -is [string]) -or -not $provider.Trim() -or $provider -cne $provider.Trim()) { $why = "$at needs a provider: a non-empty string without surrounding blanks"; break }
            $model = ''
            if ($item.PSObject.Properties['model']) {
                $mv = $item.model
                if (-not ($mv -is [string]) -or -not $mv.Trim() -or $mv -cne $mv.Trim()) { $why = "${at}: model must be a non-empty string without surrounding blanks (omit it to use the Codex config's model)"; break }
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
                if (-not ($item.auth -is [string]) -or $item.auth -cne 'none') { $why = "${at}: auth may only be ""none"" (an endpoint that needs no credential; omit it otherwise)"; break }
                $auth = 'none'
            }
            $panelWeight = 'always'
            if ($item.PSObject.Properties['panel']) {
                if (-not ($item.panel -is [string]) -or @('always', 'weighty') -cnotcontains $item.panel) { $why = "${at}: panel must be ""always"" or ""weighty"" (got $(ConvertTo-Json -InputObject $item.panel -Compress))"; break }
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
                if ($item.PSObject.Properties['auth']) { $why = "${at}: auth does not apply to engine $engine (the $engine CLI keeps its own sign-in)"; break }
            }
            $other = @($entries | Where-Object { $_.Provider -ceq $provider -and $_.Engine -ne $engine }) | Select-Object -First 1
            if ($other) { $why = "entries $($other.Position) and $pos use the provider label '$provider' with two engines ($($other.Engine), $engine); a label names one engine"; break }
            $dup = @($entries | Where-Object { $_.Provider -ceq $provider -and $_.Model -ceq $model }) | Select-Object -First 1
            if ($dup) {
                $label = if ($model) { Format-Lineage -Provider $provider -Model $model } else { "$provider (no model)" }
                $why = "entries $($dup.Position) and $pos are the same reviewer $label"; break
            }
            $entries.Add([pscustomobject]@{ Position = $pos; Provider = $provider; Model = $model; CodexConfig = $cfgItems; Auth = $auth; Panel = $panelWeight; Engine = $engine; EngineDeclared = $engineDeclared })
        }
    }
    if (-not $why -and $data.PSObject.Properties['parallel']) {
        $pv = $data.parallel
        if (-not (Test-IsJsonObject $pv)) {
            $why = "parallel must be an object {""<provider label>"": <n>} (got $(ConvertTo-Json -InputObject $pv -Compress))"
        } else {
            foreach ($prop in $pv.PSObject.Properties) {
                if (@($entries | Where-Object { $_.Provider -ceq $prop.Name }).Count -eq 0) { $why = "parallel names the provider label '$($prop.Name)', which no entry of the roster uses"; break }
                if (-not (Test-IsJsonInteger $prop.Value) -or [double]$prop.Value -lt 1) { $why = "parallel.$($prop.Name) must be an integer >= 1 (got $(ConvertTo-Json -InputObject $prop.Value -Compress))"; break }
                $r.Parallel[$prop.Name] = [int]$prop.Value
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
# refusal message of a real run); Label (the dry-run line) }.
#   unresolved identity          unknown
#   credentials missing/unknown  unavailable / unknown (Get-ProviderCredential)
#   auth failure <= 24 h         unavailable
#   usage limit with a known     unavailable: usage limit until <iso>
#   reset in the future
#   usage limit without a reset  -RosterWalk: unavailable (a later roster entry exists to
#   time, <= 60 min old          fall back to); otherwise available - Format-QuotaWarning
#                                warns about it
# $Health: Get-EndpointHealth of the identity's endpoint ($null: none known).
function Get-PreflightVerdict {
    param($Identity, $Config, [string]$Launcher, $Health, [hashtable]$LoginCache = $null, [switch]$Anonymous, [switch]$RosterWalk, [switch]$NoNetwork)
    $v = [pscustomobject]@{ State = 'available'; Preflight = ''; Reason = ''; Refusal = ''; Label = '' }
    $p = [string]$Identity.Provider
    $engine = [string]$Identity.Engine
    if (-not $engine) { $engine = 'codex' }
    if ($Identity.Error) {
        $v.State = 'unavailable'
        $v.Reason = $Identity.Error
        $v.Preflight = "unavailable: $($Identity.Error)"
        $v.Refusal = $Identity.Error
        $v.Label = "unavailable ($($Identity.Error)) - a real run is refused"
        return $v
    }
    if (-not $Identity.Resolved) {
        $reason = "reviewer identity unresolved: $($Identity.Note)"
        $v.State = 'unknown'
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
        $cred = Get-EngineCredential -Engine $engine -Launcher $Launcher -LoginCache $LoginCache -NoNetwork:$NoNetwork -Health $Health
    } else {
        $table = $null
        if ($Config -and $Config.Exists -and $Config.Ok) {
            $pt = Get-ProviderTable -Config $Config -Name $p
            if ($pt.Found) { $table = $pt.Table }
        }
        $cred = Get-ProviderCredential -Name $p -Table $table -Launcher $Launcher -LoginCache $LoginCache -Anonymous:$Anonymous
    }
    $v.Preflight = $cred.Detail
    $v.Reason = $cred.Detail
    if ($cred.State -eq 'missing') {
        $v.State = 'unavailable'
        $v.Refusal = "provider $p is not usable: $($cred.Reason); nothing was started (run codex-providers.ps1 for the full picture)"
        $v.Label = "unavailable ($($cred.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($cred.State -eq 'unknown') {
        $v.State = 'unknown'
        $v.Refusal = "provider $($p): availability could not be established ($($cred.Reason)); pass -SkipPreflight to launch anyway, or fix the check"
        $v.Label = "unknown ($($cred.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($Health -and $Health.Auth) {
        $v.State = 'unavailable'
        $v.Reason = "auth failed $($Health.Auth.When): $($Health.Auth.Message)"
        $v.Preflight = "unavailable: $($v.Reason)"
        $v.Refusal = "provider $p is not usable: the last run on this endpoint was rejected as unauthenticated at $($Health.Auth.When) ($($Health.Auth.Message)); if you rotated the credential, pass -SkipPreflight once"
        $v.Label = "unavailable ($($v.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($Health -and $Health.Quota -and $Health.QuotaKnown) {
        $v.State = 'unavailable'
        $v.Reason = "usage limit until $($Health.Quota.RetryAfterIso)"
        $v.Preflight = "unavailable: $($v.Reason)"
        $v.Refusal = "provider $p is not usable: its usage limit (hit at $($Health.Quota.When): $($Health.Quota.Message)) lasts until $($Health.Quota.RetryAfterIso); nothing was started (pass -SkipPreflight to launch anyway)"
        $v.Label = "unavailable ($($v.Reason)) - a real run is refused: $($v.Refusal)"
    } elseif ($RosterWalk -and $Health -and $Health.Quota) {
        $v.State = 'unavailable'
        $v.Reason = "usage limit $($Health.Quota.AgeMinutes) min ago, no reset time given"
        $v.Preflight = "unavailable: $($v.Reason)"
        $v.Refusal = "provider $p is not usable: it hit a usage limit $($Health.Quota.AgeMinutes) min ago ($($Health.Quota.Message)) and named no reset time; nothing was started"
        $v.Label = "unavailable ($($v.Reason)) - a real run is refused: $($v.Refusal)"
    } else {
        $v.Label = "available ($($cred.Detail))"
    }
    return $v
}

# The warning of a usage limit that does not refuse the run: one without a known reset time
# (<= 60 min old), or - with -SkipPreflight - one whose reset time lies ahead. '' otherwise.
function Format-QuotaWarning {
    param($Identity, $Health, [switch]$SkipPreflight)
    if (-not $Health -or -not $Health.Quota) { return '' }
    $q = $Health.Quota
    if ($Health.QuotaKnown) {
        if (-not $SkipPreflight) { return '' }
        return "provider $($Identity.Provider) hit a usage limit $($q.AgeMinutes) min ago that lasts until $($q.RetryAfterIso): $($q.Message)"
    }
    return "provider $($Identity.Provider) hit a usage limit $($q.AgeMinutes) min ago: $($q.Message)"
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
function Select-RosterReviewer {
    param($Roster, $Config, [object[]]$Consults, [string]$Launcher, [hashtable]$LoginCache = $null, [datetime]$UtcNow = [datetime]::UtcNow, [string]$OpenAiBaseUrl = '', [string]$Model = '', [switch]$SkipPreflight, [string]$Engine = '', [hashtable]$EngineLaunchers = $null, [switch]$NoNetwork)
    $skipped = New-Object System.Collections.Generic.List[object]
    $r = [pscustomobject]@{ Entry = $null; Identity = $null; Verdict = $null; Skipped = [object[]]@(); Considered = 0; Error = '' }
    $listing = New-Object System.Collections.Generic.List[string]
    foreach ($e in @($Roster.Entries)) {
        $entryEngine = if ($e.PSObject.Properties['Engine'] -and $e.Engine) { [string]$e.Engine } else { 'codex' }
        if ($Engine -and $entryEngine -ne $Engine) { continue }
        $entryLauncher = Get-EngineLauncher -Engine $entryEngine -Launchers $EngineLaunchers -CodexLauncher $Launcher
        $id = Resolve-ReviewerIdentity -Config $Config -Provider $e.Provider -Model $e.Model -OpenAiBaseUrl $OpenAiBaseUrl -Engine $entryEngine -Launcher $entryLauncher
        if ($Model -and $id.Model -cne $Model) { continue }
        $r.Considered++
        $block = Get-EngineLaunchBlock -Engine $entryEngine
        if ($block) {
            $skipped.Add([pscustomobject]@{ provider = $e.Provider; model = $id.Model; engine = $entryEngine; reason = "refused: $block" })
            $listing.Add("#$($e.Position) $(Format-ReviewerLineage -Provider $id.Provider -Model $id.Model -Engine $entryEngine) (refused: $block)")
            continue
        }
        if ($SkipPreflight) {
            if ($id.Error) { $r.Error = $id.Error; return $r }
            $r.Entry = $e; $r.Identity = $id
            $r.Skipped = [object[]]$skipped.ToArray()
            return $r
        }
        $health = $null
        if ($id.Resolved) { $health = Get-EndpointHealth -Consults $Consults -Fingerprint $id.Fingerprint -UtcNow $UtcNow }
        $verdict = Get-PreflightVerdict -Identity $id -Config $Config -Launcher $entryLauncher -Health $health -LoginCache $LoginCache -Anonymous:($e.Auth -eq 'none') -RosterWalk -NoNetwork:$NoNetwork
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

# The purposes on which a "weighty" roster entry joins a panel.
$script:WeightyPurposes = @('framing', 'decision', 'core-contract', 'acceptance', 'stuck')

# The members of a review panel (-Panel): the roster walked like Select-RosterReviewer
# without stopping at the first available entry. Every entry whose preflight verdict is
# available (with -SkipPreflight: every entry) runs, unless it is "weighty" and $Purpose is
# light (not in $script:WeightyPurposes) and -All (-PanelAll) is not given, or its engine's
# launch invariant refuses it (wave 23, D4 - with -SkipPreflight too). $Model: as for
# the walk. { Members (object[], roster order, of { Entry; Identity; State 'run'|'skipped';
# Reason ('' when it runs) }); Error ('' or the refusal: nobody runs / no entry for $Model) }.
function Select-PanelMembers {
    param($Roster, $Config, [object[]]$Consults, [string]$Launcher, [hashtable]$LoginCache = $null, [datetime]$UtcNow = [datetime]::UtcNow, [string]$OpenAiBaseUrl = '', [string]$Model = '', [string]$Purpose = '', [switch]$All, [switch]$SkipPreflight, [string]$Engine = '', [hashtable]$EngineLaunchers = $null)
    $members = New-Object System.Collections.Generic.List[object]
    $r = [pscustomobject]@{ Members = [object[]]@(); Error = '' }
    $listing = New-Object System.Collections.Generic.List[string]
    $purposeLabel = if ($Purpose) { $Purpose } else { 'none' }
    foreach ($e in @($Roster.Entries)) {
        $entryEngine = if ($e.PSObject.Properties['Engine'] -and $e.Engine) { [string]$e.Engine } else { 'codex' }
        if ($Engine -and $entryEngine -ne $Engine) { continue }
        $entryLauncher = Get-EngineLauncher -Engine $entryEngine -Launchers $EngineLaunchers -CodexLauncher $Launcher
        $id = Resolve-ReviewerIdentity -Config $Config -Provider $e.Provider -Model $e.Model -OpenAiBaseUrl $OpenAiBaseUrl -Engine $entryEngine -Launcher $entryLauncher
        if ($Model -and $id.Model -cne $Model) { continue }
        $state = 'run'
        $reason = ''
        $block = Get-EngineLaunchBlock -Engine $entryEngine
        if ($block) { $state = 'skipped'; $reason = "refused: $block" }
        elseif (-not $SkipPreflight) {
            $health = $null
            if ($id.Resolved) { $health = Get-EndpointHealth -Consults $Consults -Fingerprint $id.Fingerprint -UtcNow $UtcNow }
            $verdict = Get-PreflightVerdict -Identity $id -Config $Config -Launcher $entryLauncher -Health $health -LoginCache $LoginCache -Anonymous:($e.Auth -eq 'none') -RosterWalk
            if ($verdict.State -ne 'available') { $state = 'skipped'; $reason = $verdict.Reason }
        }
        if ($state -eq 'run' -and $e.Panel -eq 'weighty' -and -not $All -and $script:WeightyPurposes -notcontains $Purpose) {
            $state = 'skipped'
            $reason = "weighty reviewer; purpose $purposeLabel is light (use -PanelAll)"
        }
        $members.Add([pscustomobject]@{ Entry = $e; Identity = $id; State = $state; Reason = $reason })
        $listing.Add("#$($e.Position) $(Format-ReviewerLineage -Provider $id.Provider -Model $id.Model -Engine $entryEngine) ($(if ($state -eq 'run') { 'runs' } else { $reason }))")
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

# The concurrency plan of a panel (0.4.x wave 21, D8 - endpoint-aware): members that reach the
# same ENDPOINT run one after another, members of different endpoints at once. An endpoint
# group is the members of one provider label, merged with every other label whose members
# resolve to the same provider fingerprint (two labels on one base URL; every agy label - they
# share one Google sign-in). A group runs 1 member at a time unless the roster's top-level
# "parallel" raises its label (a merged group: the smallest limit of its labels); -Cap
# (-PanelConcurrency) caps the total (0 = no cap, 1 = strictly one after another in roster
# order). $Runners: the members Select-PanelMembers runs (State 'run'), in roster order.
# { Groups (object[] of { Labels (string[]); Limit; Positions (int[] roster positions) });
#   GroupOf (hashtable roster position -> group index); Cap; Effective (the most members
#   that can run at once); Text ('at once' | 'one after another' | 'at most <k> at a time');
#   Limits (ordered: label -> its group's limit, roster order) }
function Get-PanelPlan {
    param([object[]]$Runners, [hashtable]$Parallel = $null, [int]$Cap = 0)
    $labels = New-Object System.Collections.Generic.List[string]
    $fps = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($m in @($Runners | Where-Object { $_ })) {
        $label = [string]$m.Entry.Provider
        if (-not $fps.ContainsKey($label)) { $fps[$label] = New-Object System.Collections.Generic.List[string]; $labels.Add($label) }
        $fp = ''
        if ($m.Identity -and $m.Identity.Resolved) { $fp = [string]$m.Identity.Fingerprint }
        if ($fp -and -not $fps[$label].Contains($fp)) { $fps[$label].Add($fp) }
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
    foreach ($m in @($Runners | Where-Object { $_ })) {
        $label = [string]$m.Entry.Provider
        $gid = $groupOfLabel[$label]
        if (-not $indexOf.ContainsKey($gid)) {
            $indexOf[$gid] = $groups.Count
            $groups.Add([pscustomobject]@{ Labels = (New-Object System.Collections.Generic.List[string]); Limit = 0; Positions = (New-Object System.Collections.Generic.List[int]) })
        }
        $g = $groups[$indexOf[$gid]]
        if (-not $g.Labels.Contains($label)) { $g.Labels.Add($label) }
        $g.Positions.Add([int]$m.Entry.Position)
        $groupOf[[int]$m.Entry.Position] = $indexOf[$gid]
    }
    $effective = 0
    $limits = [ordered]@{}
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($g in $groups) {
        $limit = 0
        foreach ($l in $g.Labels) {
            $v = 1
            if ($null -ne $Parallel -and $Parallel.ContainsKey($l)) { $v = [int]$Parallel[$l] }
            if ($limit -eq 0 -or $v -lt $limit) { $limit = $v }
        }
        $effective += [Math]::Min($limit, $g.Positions.Count)
        $out.Add([pscustomobject]@{ Labels = [string[]]$g.Labels.ToArray(); Limit = $limit; Positions = [int[]]$g.Positions.ToArray() })
    }
    foreach ($l in $labels) { $limits[$l] = $out[$indexOf[$groupOfLabel[$l]]].Limit }
    if ($Cap -gt 0 -and $Cap -lt $effective) { $effective = $Cap }
    $count = @($Runners | Where-Object { $_ }).Count
    $text = if ($effective -ge $count) { 'at once' } elseif ($effective -le 1) { 'one after another' } else { "at most $effective at a time" }
    return [pscustomobject]@{ Groups = [object[]]$out.ToArray(); GroupOf = $groupOf; Cap = $Cap; Effective = $effective; Text = $text; Limits = $limits }
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
# rule "-Thread fixes the reviewer" (codex-consult.ps1).
function Find-ThreadEntry {
    param([object[]]$Consults, [string]$Thread)
    $r = [pscustomobject]@{ Entry = $null; N = $null; Error = '' }
    $entries = @($Consults | Where-Object { $null -ne $_ })
    $thread = ([string]$Thread).Trim()
    $match = $null
    for ($i = $entries.Count - 1; $i -ge 0; $i--) {
        if ([string](Get-PropertyValue $entries[$i] 'thread' '') -eq $thread) { $match = $entries[$i]; break }
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
#                                     child_start_time, survivors, note [, reply_json,
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
#                                   pid) counts only if that process looks like codex
#                                   (Test-RecordedProcess) - never by pid alone.
#                                 It is deleted when the run completed cleanly (after the
#                                 ledger commit, under the write lock). A run that finds
#                                 records decides from ALL of them BEFORE writing anything
#                                 (Read-TaskPendingRecords, Test-PendingActive): a live
#                                 writer or codex process refuses the run; a dead one's
#                                 reservation is consumed (numbering skips past it) and
#                                 only then is the file replaced by the new run's record
#                                 (a member record: removed). An unparseable pending file
#                                 is corruption and refuses.

# Process start time as a UTC round-trip string. $null: no such process. '': the
# process exists but its start time cannot be read (e.g. another user's process).
function Get-ProcessStartIso {
    param([int]$ProcessId)
    $p = $null
    try { $p = Get-Process -Id $ProcessId -ErrorAction Stop } catch { return $null }
    try { return $p.StartTime.ToUniversalTime().ToString('o', $script:Invariant) } catch { return '' }
}

# Do two start times (UTC round-trip strings from Get-ProcessStartIso) name the same
# process start? Windows reports a process's start time exactly. .NET on Linux derives
# Process.StartTime from a boot time that every process computes for itself
# (CLOCK_REALTIME_COARSE - CLOCK_BOOTTIME), so two processes reading the SAME pid get
# values a few milliseconds apart. Outside Windows, less than one second apart counts
# as the same start (a pid is not handed out again that fast).
function Test-SameStartTime {
    param([string]$A, [string]$B)
    if ($A -eq $B) { return $true }
    if ($script:OnWindows) { return $false }
    $ta = [DateTimeOffset]::MinValue
    $tb = [DateTimeOffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal
    if (-not [DateTimeOffset]::TryParse($A, $script:Invariant, $styles, [ref]$ta)) { return $false }
    if (-not [DateTimeOffset]::TryParse($B, $script:Invariant, $styles, [ref]$tb)) { return $false }
    return ([math]::Abs($ta.UtcTicks - $tb.UtcTicks) -lt [TimeSpan]::TicksPerSecond)
}

# A pid counts as alive when a process with that id exists and - if a start time was
# recorded for it - still has that start time (otherwise the pid was reused).
function Test-PidAlive {
    param([int]$ProcessId, [string]$StartTime = '')
    if ($ProcessId -le 0) { return $false }
    $live = Get-ProcessStartIso -ProcessId $ProcessId
    if ($null -eq $live) { return $false }
    if ($StartTime -and $live -and -not (Test-SameStartTime -A $live -B $StartTime)) { return $false }
    return $true
}

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
    if ([double]::TryParse([string]$env:CODEX_CONSULT_TEST_WRITE_LOCK_SEC, [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$v) -and $v -gt 0) { return $v }
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
# be read) }, or $null when no process has that pid.
function Get-ProcessInfo {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return $null }
    $p = $null
    try { $p = Get-Process -Id $ProcessId -ErrorAction Stop } catch { return $null }
    $start = ''
    try { $start = $p.StartTime.ToUniversalTime().ToString('o', $script:Invariant) } catch { $start = '' }
    $cmd = ''
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($script:OnWindows) {
            try {
                $w = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$ProcessId" -Property CommandLine -ErrorAction Stop
                if ($w) { $cmd = [string]@($w)[0].CommandLine }
            } catch { $cmd = '' }
        } else {
            try { $cmd = ((@(& ps -o 'args=' -p $ProcessId 2>$null)) -join ' ').Trim() } catch { $cmd = '' }
        }
    } finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ pid = $ProcessId; name = [string]$p.ProcessName; cmd = $cmd; start = $start }
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

# Is a process recorded in a pending record still that process? Returns { Alive; How }.
#   with a recorded start time: alive only when the pid runs with that start time (and
#     that name, when one is recorded) - a different start time means the pid was
#     reused by an unrelated process;
#   without one (older records), or when the live start time cannot be read: alive
#     only when the process looks like codex (Get-CodexRule) - never by pid alone.
function Test-RecordedProcess {
    param([int]$ProcessId, [string]$StartTime = '', [string]$Name = '', [string]$Launcher = '')
    $info = Get-ProcessInfo -ProcessId $ProcessId
    if (-not $info) { return [pscustomobject]@{ Alive = $false; How = 'gone' } }
    if ($StartTime -and $info.start) {
        if (-not (Test-SameStartTime -A $info.start -B $StartTime)) { return [pscustomobject]@{ Alive = $false; How = 'pid reused (start time differs)' } }
        if ($Name -and -not $info.name.Equals($Name, [StringComparison]::OrdinalIgnoreCase)) { return [pscustomobject]@{ Alive = $false; How = "pid reused (now $($info.name))" } }
        return [pscustomobject]@{ Alive = $true; How = 'pid + start time' }
    }
    $rule = Get-CodexRule -Name $info.name -Cmd $info.cmd -Launcher $Launcher
    if ($rule) { return [pscustomobject]@{ Alive = $true; How = "no start time recorded; $rule" } }
    return [pscustomobject]@{ Alive = $false; How = "no start time recorded; pid $ProcessId runs $($info.name), not codex" }
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
#                          is alive on this host; pids from another host: active (they
#                          cannot be checked from here); all recorded pids gone: the
#                          process scan below (a dead launcher is no proof of a dead tree);
#      launching           the child may or may not exist: the process scan below; from
#                          another host (no pids to check): treated as dead.
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
    if ($pids.Count -gt 0 -and $state -ne 'launching') {
        $pidList = (@($pids | ForEach-Object { $_.pid }) -join ', ')
        if ($otherHost) {
            return (& $active "an interrupted consultation on host $recHost left $cli process(es) pid $pidList ($what); they cannot be checked from this host. Delete $Path only after making sure they are gone." "pids on host $recHost")
        }
        $alive = New-Object System.Collections.Generic.List[string]
        $aliveHow = New-Object System.Collections.Generic.List[string]
        $gone = New-Object System.Collections.Generic.List[string]
        foreach ($entry in $pids) {
            $verdict = Test-RecordedProcess -ProcessId $entry.pid -StartTime $entry.start -Name $entry.name -Launcher $launcher
            if ($verdict.Alive) { $alive.Add("$($entry.pid)"); $aliveHow.Add("$($entry.pid) [$($verdict.How)]") } else { $gone.Add("$($entry.pid) [$($verdict.How)]") }
        }
        if ($alive.Count -gt 0) {
            return (& $active "a previous consultation's $cli process (pid $($alive -join ', ')) is still running ($what). Wait for it to exit or stop it, then retry; $Path keeps its record until then." "pid $($aliveHow -join ', ') alive")
        }
        # Every RECORDED pid is gone - but the record names the launcher (the npm shim on
        # Windows) and the survivors the kill could see; the real codex may be a
        # descendant that outlived them. A dead launcher is not proof of a dead tree:
        # fall through to the descendant scan below (F04-10).
        $recordedGone = "$cli pid(s) $($gone -join ', ') no longer running"
    } else {
        $recordedGone = ''
    }
    if ($writerGone) { $recordedGone = $(if ($recordedGone) { "$writerGone; $recordedGone" } else { $writerGone }) }
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

# ----------------------------------------------------------------------------- processes

# Descendant pids of $RootId (Windows: CIM; elsewhere: pgrep -P). Best effort.
function Get-DescendantPids {
    param([int]$RootId)
    $found = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootId)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $all = @()
        if ($script:OnWindows) {
            try { $all = @(Get-CimInstance -ClassName Win32_Process -Property ProcessId, ParentProcessId -ErrorAction Stop) } catch { $all = @() }
        }
        while ($queue.Count -gt 0) {
            $cur = $queue.Dequeue()
            $kids = @()
            if ($script:OnWindows) {
                $kids = @($all | Where-Object { [int]$_.ParentProcessId -eq $cur -and [int]$_.ProcessId -ne $cur } | ForEach-Object { [int]$_.ProcessId })
            } else {
                try { $kids = @(& pgrep -P $cur 2>$null) } catch { $kids = @() }
            }
            foreach ($k in $kids) {
                $n = 0
                if ([int]::TryParse(([string]$k).Trim(), [ref]$n) -and -not $found.Contains($n)) {
                    $found.Add($n)
                    $queue.Enqueue($n)
                }
            }
        }
    } finally {
        $ErrorActionPreference = $previous
    }
    return , ([int[]]$found.ToArray())
}

# Kills the process AND its descendants (the launcher is usually a shim: cmd.exe or
# node in front of the real codex binary). Windows: taskkill /T /F; elsewhere: the
# pgrep -P tree. Best effort; returns the pids (root included) still alive after it,
# as an [int[]] (empty when the whole tree is gone).
# A kill returns before the OS has torn the process down: the killed pids are polled
# (100 ms steps, up to 3 s) and only those still alive after that wait are survivors.
# A process merely still exiting must not be recorded as a survivor - that would keep
# .consult.pending.json in state 'survivors' and block the task until a later run.
function Stop-ProcessTree {
    param($Process)
    if ($null -eq $Process) { return , ([int[]]@()) }
    $rootId = $Process.Id
    $descendants = Get-DescendantPids -RootId $rootId
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($script:OnWindows) {
            try { & taskkill.exe /PID $rootId /T /F 2>$null | Out-Null } catch { }
        }
        # The root before its descendants: a root that outlives its children reacts to
        # their death (a shell or node shim carries on and may start new processes).
        try { if (-not $Process.HasExited) { $Process.Kill() } } catch { }
        foreach ($d in $descendants) {
            try { Stop-Process -Id $d -Force -ErrorAction SilentlyContinue } catch { }
        }
        try { $null = $Process.WaitForExit(10000) } catch { }
    } finally {
        $ErrorActionPreference = $previous
    }
    # Get-Process by pid is the liveness probe on every platform (kill -0 semantics).
    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    while ($true) {
        $alive = New-Object System.Collections.Generic.List[int]
        $rootGone = $true
        try { $rootGone = $Process.HasExited } catch { $rootGone = $true }
        if (-not $rootGone) { $alive.Add($rootId) }
        foreach ($d in $descendants) {
            if (Get-Process -Id $d -ErrorAction SilentlyContinue) { $alive.Add($d) }
        }
        if ($alive.Count -eq 0 -or [DateTime]::UtcNow -ge $deadline) { break }
        Start-Sleep -Milliseconds 100
    }
    return , ([int[]]$alive.ToArray())
}
