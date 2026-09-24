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
      * task lock        Enter-TaskLock, Exit-TaskLock (ownership, .consult.lock)
      * recovery record  Read-PendingFile, Write-PendingFile, Remove-PendingFile,
                         Test-PendingActive, Find-CodexProcesses
                         (.consult.pending.json)
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

# Replaces $Path with $Text (UTF-8, no BOM) atomically: the text is written and
# flushed to a temp file in the same directory, which then replaces the destination
# in one step (Windows: File.Replace -> ReplaceFile; elsewhere: File.Move with
# overwrite -> rename(2)). A crash leaves either the old or the new file, never a
# truncated one (at worst a stray .<name>.<guid>.tmp next to it).
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
            if (-not [IO.File]::Exists($full)) {
                [IO.File]::Move($tmp, $full)
            } elseif ($script:OnWindows) {
                # $null would reach .NET as '' - NullString is a real null (no backup file).
                [IO.File]::Replace($tmp, $full, [System.Management.Automation.Language.NullString]::Value)
            } else {
                [IO.File]::Move($tmp, $full, $true)
            }
            return
        } catch {
            # A reader holding the destination open without FileShare.Delete makes
            # ReplaceFile fail with a sharing violation; it is gone a moment later.
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
        try { $data = ConvertFrom-Json -InputObject $text } catch { $why = "it does not parse: $(($_.Exception.Message -replace '\s+', ' ').Trim())" }
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
#        source.consult, every reviewer_checks[].consult, and the n of an
#        interrupted run's recovery record ($Leftover = .consult.pending.json);
#   NN > every handoff file "<NN>-..." (two OR MORE digits, so 100-... counts),
#        every finding id F<NN>-<k>, and the nn of that recovery record.
# Recovered is set when the recovery record's n has no ledger entry (a run that
# stopped before its commit point); the caller reports it.
function Get-NextNumbers {
    param($Consults, $Store, [string]$HandoffsDir, $Leftover)
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
    $recovered = $false
    $recN = $null
    $recNn = ''
    if ($Leftover) {
        $v = 0
        if ([int]::TryParse([string](Get-PropertyValue $Leftover 'n' ''), [ref]$v) -and $v -gt 0) {
            $recN = $v
            if (-not $ledgerNs.ContainsKey($v)) { $recovered = $true }
            if ($v -gt $maxN) { $maxN = $v }
        }
        $w = 0
        $leftNn = [string](Get-PropertyValue $Leftover 'nn' '')
        if ($leftNn -and [int]::TryParse($leftNn, [ref]$w) -and $w -gt 0) {
            $recNn = $leftNn
            if ($w -gt $maxNn) { $maxNn = $w }
            if ($null -eq $recN) { $recovered = $true }
        }
    }
    return [pscustomobject]@{
        N           = $maxN + 1
        Nn          = ('{0:D2}' -f ($maxNn + 1))
        Recovered   = $recovered
        RecoveredN  = $recN
        RecoveredNn = $recNn
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
    # PowerShell 7's ConvertFrom-Json turns ISO-date-looking strings into [datetime].
    return (($Value -is [string]) -or ($Value -is [datetime]))
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
        $Store.findings = [object[]](@($Store.findings | Where-Object { $null -ne $_ }) + $newRecords.ToArray())
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
    param($Parse, $Ingest)
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
        $why = "Codex answered $($r.verdict)"
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
#                                 host, task, started } of the current holder - written
#                                 after the handle is held; overwriting it destroys
#                                 nothing recoverable.
#
#   <task>/.consult.pending.json  recovery metadata of the consultation in progress,
#                                 replaced ATOMICALLY (Write-TextAtomic) and only while
#                                 the lock is held:
#                                   { state, n, nn, reply, started, pid, host, launcher,
#                                     child_pid, child_start_time, survivors, note }
#                                 state: reserved   numbers allocated, codex not started
#                                        launching  about to start codex (the child may
#                                                   or may not exist)
#                                        running    codex started as child_pid
#                                        survivors  a timeout kill left survivors[] alive
#                                 pid: the bridge that wrote the record. survivors[]:
#                                   { pid, start_time, name } per process still alive
#                                   after the kill (start_time: UTC round-trip string
#                                   from Get-Process; name: its ProcessName). A recorded
#                                   process counts as alive only while its pid runs with
#                                   the SAME start time (and name, when recorded); an
#                                   entry without a start time (older records: a bare
#                                   pid) counts only if that process looks like codex
#                                   (Test-RecordedProcess) - never by pid alone.
#                                 It is deleted when the run completed cleanly (after the
#                                 ledger commit). A run that finds one decides from it
#                                 BEFORE writing anything (Test-PendingActive): a live
#                                 codex process refuses the run; a dead one's reservation
#                                 is consumed (numbering skips past it) and only then is
#                                 the file replaced by the new run's record. An
#                                 unparseable pending file is corruption and refuses.

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
    param([string]$TaskDir, [string]$Task)
    $path = Join-Path $TaskDir '.consult.lock'
    $share = if ($script:OnWindows) { [IO.FileShare]::Read } else { [IO.FileShare]::None }
    $record = [pscustomobject]@{
        pid        = $PID
        start_time = (Get-ProcessStartIso -ProcessId $PID)
        host       = [Environment]::MachineName
        task       = $Task
        started    = (Get-IsoTimestamp)
    }
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
        if ($holder) { $who = "pid $(Get-PropertyValue $holder 'pid' '?') on $(Get-PropertyValue $holder 'host' '?') since $(Get-PropertyValue $holder 'started' '?')" }
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

$script:PendingStates = @('reserved', 'launching', 'running', 'survivors')

function Get-PendingPath {
    param([string]$TaskDir)
    return (Join-Path $TaskDir '.consult.pending.json')
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

function New-PendingRecord {
    param([string]$State, $N, [string]$Nn, [string]$Reply, [string]$Started, [string]$Launcher = '')
    return [pscustomobject]@{
        state            = $State
        n                = $N
        nn               = $Nn
        reply            = $Reply
        started          = $Started
        pid              = $PID
        host             = [Environment]::MachineName
        launcher         = $Launcher
        child_pid        = $null
        child_start_time = ''
        survivors        = [object[]]@()
        note             = ''
    }
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
# binary), or a command line containing the recorded launcher path (the codex.cmd
# shim or -CodexExe) or @openai/codex (node running the npm package). It cannot tell
# WHICH task's consultation a process belongs to.
function Get-CodexRule {
    param([string]$Name, [string]$Cmd, [string]$Launcher = '')
    if ($Name -match '^codex(\.exe)?$') { return 'name codex' }
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

# Decides whether a pending record (from Read-PendingFile) still belongs to a live
# consultation. Returns { Active; Message; Check }:
#   reserved             never active (codex was not started);
#   running / survivors  active while child_pid (with its start time) or any survivor
#                        pid is alive on this host; with pids from another host:
#                        active (they cannot be checked from here);
#   launching            the child may or may not exist: active when
#                        Find-CodexProcesses finds a codex process started since the
#                        record's `started` (or cannot scan); from another host (no
#                        pids to check): treated as dead.
function Test-PendingActive {
    param($Record, [string]$Path)
    $state = [string](Get-PropertyValue $Record 'state' '')
    $recHost = [string](Get-PropertyValue $Record 'host' '')
    $otherHost = [bool]($recHost -and -not $recHost.Equals([Environment]::MachineName, [StringComparison]::OrdinalIgnoreCase))
    $what = "state '$state', consult n=$(Get-PropertyValue $Record 'n' '?'), handoff $(Get-PropertyValue $Record 'nn' '?'), started $(Get-PropertyValue $Record 'started' '?')"
    $launcher = [string](Get-PropertyValue $Record 'launcher' '')
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
    $inactive = { param($c) [pscustomobject]@{ Active = $false; Message = ''; Check = $c } }
    $active = { param($m, $c) [pscustomobject]@{ Active = $true; Message = $m; Check = $c } }

    if ($state -eq 'reserved') { return (& $inactive 'reserved: codex was never started') }
    if ($pids.Count -gt 0 -and $state -ne 'launching') {
        $pidList = (@($pids | ForEach-Object { $_.pid }) -join ', ')
        if ($otherHost) {
            return (& $active "an interrupted consultation on host $recHost left codex process(es) pid $pidList ($what); they cannot be checked from this host. Delete $Path only after making sure they are gone." "pids on host $recHost")
        }
        $alive = New-Object System.Collections.Generic.List[string]
        $aliveHow = New-Object System.Collections.Generic.List[string]
        $gone = New-Object System.Collections.Generic.List[string]
        foreach ($entry in $pids) {
            $verdict = Test-RecordedProcess -ProcessId $entry.pid -StartTime $entry.start -Name $entry.name -Launcher $launcher
            if ($verdict.Alive) { $alive.Add("$($entry.pid)"); $aliveHow.Add("$($entry.pid) [$($verdict.How)]") } else { $gone.Add("$($entry.pid) [$($verdict.How)]") }
        }
        if ($alive.Count -gt 0) {
            return (& $active "a previous consultation's codex process (pid $($alive -join ', ')) is still running ($what). Wait for it to exit or stop it, then retry; $Path keeps its record until then." "pid $($aliveHow -join ', ') alive")
        }
        return (& $inactive "codex pid(s) $($gone -join ', ') no longer running")
    }
    # launching (or running/survivors without any pid): the child may exist unregistered
    if ($otherHost) { return (& $inactive "state '$state' from host $recHost without pids: treated as dead") }
    $since = [datetime]::MinValue
    try { $since = [DateTimeOffset]::Parse((ConvertTo-JsonText (Get-PropertyValue $Record 'started' '')), $script:Invariant).LocalDateTime } catch { $since = [datetime]::MinValue }
    $bridgePid = 0
    [void][int]::TryParse([string](Get-PropertyValue $Record 'pid' ''), [ref]$bridgePid)
    $scan = Find-CodexProcesses -Since $since -Launcher $launcher -BridgePid $bridgePid
    # The parent-pid rule sees only DIRECT children of the dead bridge. On Windows the
    # npm shim is that child (codex.cmd -> cmd.exe -> node), so if the shim died but its
    # own child lives, the rule misses it. While the record is young (30 min), fall back
    # to the "looks like codex" rule; its matches cannot be tied to this task and are
    # labelled so. An older launching record with no direct child is treated as dead.
    if (-not $scan.Failed -and @($scan.Found).Count -eq 0 -and $bridgePid -gt 0 -and $since -gt (Get-Date).AddMinutes(-30)) {
        $fallback = Find-CodexProcesses -Since $since -Launcher $launcher -BridgePid 0
        if ($fallback.Failed -or @($fallback.Found).Count -gt 0) {
            $fallback.Check = "$($scan.Check): none found; then $($fallback.Check)"
            $scan = $fallback
        } else {
            $scan.Check = "$($scan.Check): none found; then $($fallback.Check)"
        }
    }
    if ($scan.Failed) {
        return (& $active "an interrupted consultation ($what) may have left a codex process running, and the check failed: $($scan.Check). Make sure no such process runs, then delete $Path." $scan.Check)
    }
    if (@($scan.Found).Count -gt 0) {
        $list = (@($scan.Found) | ForEach-Object { "pid $($_.pid) $($_.name) [$($_.rule)]" }) -join ', '
        return (& $active "an interrupted consultation ($what) may still have its codex process running: $list, found by $($scan.Check). Wait for it to exit or stop it, then retry (or delete $Path once you know it is unrelated)." $scan.Check)
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
    $alive = New-Object System.Collections.Generic.List[int]
    $rootGone = $true
    try { $rootGone = $Process.HasExited } catch { $rootGone = $true }
    if (-not $rootGone) { $alive.Add($rootId) }
    foreach ($d in $descendants) {
        if (Get-Process -Id $d -ErrorAction SilentlyContinue) { $alive.Add($d) }
    }
    return , ([int[]]$alive.ToArray())
}
