<#
.SYNOPSIS
    The detached-run readers of the codex-consult bridge (wave 26, F07-3): dot-sourced by
    codex-consult-common.ps1 (so by every script of the plugin) and, alone, by the SessionStart
    hook, which needs one phrase about the detached consultations of the repository and should
    not parse the whole common script for it.

.DESCRIPTION
    Contents: a few small helpers the readers need (Read-SharedText, Get-PropertyValue,
    ConvertTo-OneLine, Test-IsJsonObject, ConvertTo-JsonText, ConvertTo-WhenOffset,
    Get-GitOutput, Resolve-RepoRoot, Resolve-CollabRoot, Get-ProcessStartIso,
    Test-SameStartTime, Test-PidAlive, wave 28c: Get-PidIdentity; wave 28e: Get-ProcessStartTicks,
    Get-PidIdentityTicks; wave 28: Get-TelemetrySwitch, the switch the hook prints)
    and the readers of a detached run's status file
    (Get-DetachedPaths, New-DetachedMember, ConvertTo-DetachedTime, ConvertTo-DetachedRecord,
    Read-DetachedStatus, Read-DetachedRuns, Format-DetachedSpan, Get-DetachedJudgement,
    Format-DetachedListLine, Get-DetachedPhrase). Nothing here writes a file.

    Windows PowerShell 5.1 and PowerShell 7 compatible. Keep this file ASCII.
#>

# The script-scope values the helpers read (codex-consult-common.ps1 sets them first; the hook
# does not).
if ($null -eq $script:OnWindows) { $script:OnWindows = if ($null -ne $IsWindows) { [bool]$IsWindows } else { $true } }
if ($null -eq $script:Utf8NoBom) { $script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false) }
if ($null -eq $script:Invariant) { $script:Invariant = [System.Globalization.CultureInfo]::InvariantCulture }

# ----------------------------------------------------------------------------- small helpers

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

function Get-PropertyValue {
    param($Object, [string]$Name, $Default = '')
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name] -and $null -ne $Object.$Name) { return $Object.$Name }
    return $Default
}

function ConvertTo-OneLine {
    param([string]$Text)
    if (-not $Text) { return '' }
    return (($Text -replace '\s+', ' ').Trim())
}

function Test-IsJsonObject {
    param($Value)
    return ($Value -is [System.Management.Automation.PSCustomObject])
}

function ConvertTo-JsonText {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [datetime]) { return $Value.ToString('o', $script:Invariant) }
    if ($Value -is [DateTimeOffset]) { return $Value.ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFFzzz', $script:Invariant) }
    return [string]$Value
}

function ConvertTo-WhenOffset {
    param($Value)
    if ($Value -is [DateTimeOffset]) { return $Value }
    if ($Value -is [datetime]) { return [DateTimeOffset]$Value }
    $at = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse([string]$Value, $script:Invariant, [System.Globalization.DateTimeStyles]::None, [ref]$at)) { return $at }
    return $null
}

# Process start time as a UTC round-trip string. $null: no such process. '': the
# process exists but its start time cannot be read (e.g. another user's process).
# (wave 28c, D8) TEST HOOK (test mode only): CODEX_CONSULT_TEST_START_UNREADABLE=<pid>[,<pid>] - these
# pids, while they exist, read as '' (a start time that cannot be read).
function Get-ProcessStartIso {
    param([int]$ProcessId)
    $p = $null
    try { $p = Get-Process -Id $ProcessId -ErrorAction Stop } catch { return $null }
    $unreadable = [string][Environment]::GetEnvironmentVariable('CODEX_CONSULT_TEST_START_UNREADABLE')
    if ($unreadable -and ([string][Environment]::GetEnvironmentVariable('CODEX_CONSULT_TEST_MODE')).Trim() -eq '1') {
        if (@($unreadable.Split(',') | ForEach-Object { $_.Trim() }) -contains [string]$ProcessId) { return '' }
    }
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

# (wave 28c, D8 / F42-4) The identity of a pid against the start time read for it before: 'alive' (a
# process with this pid exists AND has that start time), 'gone' (no such process, or one with another
# start time - the pid was handed to another process), 'unknown' (a process with this pid exists, but
# the start time recorded or the one read now is unreadable - its identity cannot be confirmed). A
# KILL acts on 'alive' only and never counts 'unknown' as gone (Stop-ProcessTreeChecked); a holder of
# a lock or a record counts as alive on 'unknown' (Test-PidAlive: never taken over on a guess).
function Get-PidIdentity {
    param([int]$ProcessId, [string]$StartTime = '')
    if ($ProcessId -le 0) { return 'gone' }
    $live = Get-ProcessStartIso -ProcessId $ProcessId
    if ($null -eq $live) { return 'gone' }
    if (-not $StartTime -or -not $live) { return 'unknown' }
    if (Test-SameStartTime -A $live -B $StartTime) { return 'alive' }
    return 'gone'
}

# A pid counts as alive when a process with that id exists and - if a start time was
# recorded for it - still has that start time (otherwise the pid was reused). (wave 28c, D8) An
# identity that cannot be confirmed ('unknown' of Get-PidIdentity) counts as ALIVE here: a holder is
# never taken over, a survivor never released, on a guess.
function Test-PidAlive {
    param([int]$ProcessId, [string]$StartTime = '')
    if ($ProcessId -le 0) { return $false }
    $live = Get-ProcessStartIso -ProcessId $ProcessId
    if ($null -eq $live) { return $false }
    if ($StartTime -and $live -and -not (Test-SameStartTime -A $live -B $StartTime)) { return $false }
    return $true
}

# (wave 28e, E3 / F54-3) A process's start time as a whole number of ticks (UTC, 100 ns - the full
# resolution Windows reports; read through Get-ProcessStartIso, so its test hook applies): $null - no
# such process; -1 - the process exists but its start time cannot be read; else the ticks.
function Get-ProcessStartTicks {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return $null }
    $iso = Get-ProcessStartIso -ProcessId $ProcessId
    if ($null -eq $iso) { return $null }
    $t = [DateTimeOffset]::MinValue
    if ($iso -and [DateTimeOffset]::TryParse($iso, $script:Invariant, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$t)) { return [long]$t.UtcTicks }
    return [long]-1
}

# (wave 28e, E3, E2) The identity of a pid against the start ticks recorded for it (Get-ProcessStartTicks):
# 'alive' (a process with this pid runs with EXACTLY those ticks - outside Windows within the same
# second, the jitter Test-SameStartTime explains), 'gone' (no such process, or one with another start:
# the pid was handed to another process), 'unknown' (no ticks were recorded, or the start time cannot
# be read now). A holder counts as alive on 'unknown' - never removed on a guess.
function Get-PidIdentityTicks {
    param([int]$ProcessId, [long]$StartTicks = 0)
    if ($ProcessId -le 0) { return 'gone' }
    $live = Get-ProcessStartTicks -ProcessId $ProcessId
    if ($null -eq $live) { return 'gone' }
    if ($StartTicks -le 0 -or $live -lt 0) { return 'unknown' }
    if ($live -eq $StartTicks) { return 'alive' }
    if (-not $script:OnWindows -and [math]::Abs($live - $StartTicks) -lt [TimeSpan]::TicksPerSecond) { return 'alive' }
    return 'gone'
}

# (wave 28, R17) The telemetry switch - shared with the SessionStart hook, which prints it. A run's
# -Telemetry on|off ($Override) wins; else CODEX_CONSULT_TELEMETRY: unset or empty - ON (the
# default); on, 1, true, yes - on; off, 0, false, no, none - off; ANY OTHER VALUE counts as off (a
# switch that cannot be read never sends). Reads the environment only. { On; Text ('on' | 'off');
# Source ('-Telemetry' | 'the default' | 'CODEX_CONSULT_TELEMETRY' | ... (not on or off: counts as
# off)) }.
function Get-TelemetrySwitch {
    param([string]$Override = '')
    $o = ([string]$Override).Trim().ToLowerInvariant()
    if ($o -eq 'on' -or $o -eq 'off') { return [pscustomobject]@{ On = ($o -eq 'on'); Text = $o; Source = '-Telemetry' } }
    $v = ([string][Environment]::GetEnvironmentVariable('CODEX_CONSULT_TELEMETRY')).Trim().ToLowerInvariant()
    if (-not $v) { return [pscustomobject]@{ On = $true; Text = 'on'; Source = 'the default' } }
    if (@('on', '1', 'true', 'yes') -contains $v) { return [pscustomobject]@{ On = $true; Text = 'on'; Source = 'CODEX_CONSULT_TELEMETRY' } }
    if (@('off', '0', 'false', 'no', 'none') -contains $v) { return [pscustomobject]@{ On = $false; Text = 'off'; Source = 'CODEX_CONSULT_TELEMETRY' } }
    return [pscustomobject]@{ On = $false; Text = 'off'; Source = "CODEX_CONSULT_TELEMETRY='$v' (not on or off: counts as off)" }
}

# ----------------------------------------------------------------------------- detached runs (wave 25, R12): the readers
#
# codex-consult.ps1 -Detach checks a consultation like a real run in the caller's process (the
# dry run's checks plus those a real run makes before it takes the task lock - D2), then runs it
# in a BACKGROUND process and returns at once. The run's state is its status file
# <task>/.consult.detached-<id8>.status.json (atomic replace; <id8> = the first 8 hex digits of
# the detach id, a guid), its console output (stdout and stderr) the log
# <task>/.consult.detached-<id8>.log. Both names start with .consult.: Get-CollabSnapshot leaves
# them out (an agy or muse member's tree check never sees them), the collab directory is outside
# the tree fingerprint, and .gitignore carries .consult.detached-* (D1).
# Writers (D5): the foreground writes `starting` (no pid) ONCE, before it launches the
# background, never after; from then on only the background writes - its self-report `running`
# {pid, start_time, host} first, the members as they start and finish, `done` {exit, summary} on
# EVERY exit path (D3); `codex-consult.ps1 -Status -Prune` deletes the files of runs that are done
# or died, 7 days after (D6) - (wave 26, F07-1) an unreadable status file too, 7 days after the
# file was last written. Readers - -Status, -Wait, codex-findings.ps1 -List, the SessionStart
# hook - judge a record that is not done by its background's liveness (Get-DetachedJudgement, D6);
# a background on another host is never judged (D11).
#
# The record (status_version 1), fields in this order: status_version, id (the guid), id8, task,
# kind (run | panel), state (starting | running | done), exit (null until done), started (the
# foreground's clock), updated, finished, wall_seconds, pid, start_time (the background's: UTC
# round trip), host, budget_sec (D4 - -Wait's default timeout), purpose, reply_name, brief,
# members[{position (the roster position; 1 without a roster), lineage, state (D11: pending |
# running | usable | failed | skipped | killed | blocked | commit_blocked | orphan), outcome (the
# panel's Get-PanelMemberStatus phrase; a single run: its bridge outcome), wall_seconds, n,
# handoff (NN), reply}], summary (the summary block the run printed - a single run: its outcome
# lines up to `events file:`; a panel: its `Panel <id8>: ...` block - else its last error line),
# log, args (only in the foreground's `starting` record: the background's parameters, base64 of
# UTF-8 PowerShell CLIXML; the self-report drops it).

$script:DetachedStatusVersion = 1
# D5: a `starting` record without a pid reads "starting" this long, then "never started"
$script:DetachedStartGraceSec = 60
# D6: -Status -Prune removes the runs that are done or died after this many days
$script:DetachedPruneDays = 7
# D11: a member's state
$script:DetachedMemberStates = @('pending', 'running', 'usable', 'failed', 'skipped', 'killed', 'blocked', 'commit_blocked', 'orphan')
# "k of N members finished": the member states that count as finished (a skipped entry never ran)
$script:DetachedMemberDone = @('usable', 'failed', 'killed', 'blocked', 'commit_blocked', 'orphan')

# The files of a detached run: { Id8; Status; Log; Prompt (wave 26, F11-2: the inline -Prompt of
# a run that has not started yet) }.
function Get-DetachedPaths {
    param([string]$TaskDir, [string]$Id)
    $id8 = ([string]$Id).Replace('-', '')
    if ($id8.Length -gt 8) { $id8 = $id8.Substring(0, 8) }
    $id8 = $id8.ToLowerInvariant()
    return [pscustomobject]@{ Id8 = $id8; Status = (Join-Path $TaskDir ".consult.detached-$id8.status.json"); Log = (Join-Path $TaskDir ".consult.detached-$id8.log"); Prompt = (Join-Path $TaskDir ".consult.detached-$id8.prompt.txt") }
}

# One entry of a record's members[] (every field, in order).
function New-DetachedMember {
    param([int]$Position, [string]$Lineage, [string]$State = 'pending', [string]$Outcome = '', $Wall = $null, $N = $null, [string]$Handoff = '', [string]$Reply = '')
    return [pscustomobject]@{ position = $Position; lineage = $Lineage; state = $State; outcome = $Outcome; wall_seconds = $Wall; n = $N; handoff = $Handoff; reply = $Reply }
}

# A timestamp field back as text ($null for none): a [datetime] or [DateTimeOffset] that
# ConvertFrom-Json made of it (PowerShell 7) returns to the bridge's own form - the local ISO
# form of Get-IsoTimestamp, or (-RoundTrip) the UTC round trip of Get-ProcessStartIso.
function ConvertTo-DetachedTime {
    param($Value, [switch]$RoundTrip)
    if ($null -eq $Value -or ($Value -is [string] -and -not $Value)) { return $null }
    if ($RoundTrip) { return (ConvertTo-JsonText $Value) }
    $at = ConvertTo-WhenOffset $Value
    if ($null -eq $at) { return [string]$Value }
    return $at.ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant)
}

# The record in its canonical form (every field, in order, timestamps as text) from a parsed
# status file or a hashtable of fields: a record read and written back keeps its form under
# PowerShell 7 too.
function ConvertTo-DetachedRecord {
    param($Record)
    if ($Record -is [System.Collections.IDictionary]) { $Record = [pscustomobject]$Record }
    $members = New-Object System.Collections.Generic.List[object]
    foreach ($m in @(Get-PropertyValue $Record 'members' @())) {
        if ($null -eq $m) { continue }
        $nValue = $null
        $nParsed = 0
        if ([int]::TryParse([string](Get-PropertyValue $m 'n' ''), [ref]$nParsed)) { $nValue = $nParsed }
        $members.Add((New-DetachedMember -Position ([int](Get-PropertyValue $m 'position' 0)) -Lineage ([string](Get-PropertyValue $m 'lineage' '')) -State ([string](Get-PropertyValue $m 'state' 'pending')) -Outcome ([string](Get-PropertyValue $m 'outcome' '')) -Wall (Get-PropertyValue $m 'wall_seconds' $null) -N $nValue -Handoff ([string](Get-PropertyValue $m 'handoff' '')) -Reply ([string](Get-PropertyValue $m 'reply' ''))))
    }
    $pidValue = $null
    $parsed = 0
    if ([int]::TryParse([string](Get-PropertyValue $Record 'pid' ''), [ref]$parsed) -and $parsed -gt 0) { $pidValue = $parsed }
    $exitValue = $null
    if ([int]::TryParse([string](Get-PropertyValue $Record 'exit' ''), [ref]$parsed)) { $exitValue = $parsed }
    $budget = 0
    [void][int]::TryParse([string](Get-PropertyValue $Record 'budget_sec' ''), [ref]$budget)
    $version = $script:DetachedStatusVersion
    if ([int]::TryParse([string](Get-PropertyValue $Record 'status_version' ''), [ref]$parsed)) { $version = $parsed }
    return [pscustomobject]@{
        status_version = $version
        id             = [string](Get-PropertyValue $Record 'id' '')
        id8            = [string](Get-PropertyValue $Record 'id8' '')
        task           = [string](Get-PropertyValue $Record 'task' '')
        kind           = [string](Get-PropertyValue $Record 'kind' 'run')
        state          = [string](Get-PropertyValue $Record 'state' '')
        exit           = $exitValue
        started        = (ConvertTo-DetachedTime (Get-PropertyValue $Record 'started' $null))
        updated        = (ConvertTo-DetachedTime (Get-PropertyValue $Record 'updated' $null))
        finished       = (ConvertTo-DetachedTime (Get-PropertyValue $Record 'finished' $null))
        wall_seconds   = (Get-PropertyValue $Record 'wall_seconds' $null)
        pid            = $pidValue
        start_time     = (ConvertTo-DetachedTime (Get-PropertyValue $Record 'start_time' $null) -RoundTrip)
        host           = [string](Get-PropertyValue $Record 'host' '')
        budget_sec     = $budget
        purpose        = [string](Get-PropertyValue $Record 'purpose' '')
        reply_name     = [string](Get-PropertyValue $Record 'reply_name' '')
        brief          = [string](Get-PropertyValue $Record 'brief' '')
        members        = [object[]]$members.ToArray()
        summary        = [string](Get-PropertyValue $Record 'summary' '')
        log            = [string](Get-PropertyValue $Record 'log' '')
        args           = $(if ([string](Get-PropertyValue $Record 'args' '')) { [string]$Record.args } else { $null })
        # (wave 27, R13 D3/D4) the coordinator the foreground resolved and the host markers it kept
        # from the background: the run takes both from here (its own environment has no markers)
        coordinator        = (Get-PropertyValue $Record 'coordinator' $null)
        child_env_scrubbed = [object[]]@(@(Get-PropertyValue $Record 'child_env_scrubbed' @()) | Where-Object { $_ } | ForEach-Object { [string]$_ })
    }
}

# { Exists; Record (canonical); Error }. Absent -> Exists $false. Present but empty,
# unparseable, not an object, without an id or with a state other than starting | running |
# done -> Error.
function Read-DetachedStatus {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [pscustomobject]@{ Exists = $false; Record = $null; Error = '' } }
    $text = Read-SharedText -Path $Path
    $obj = $null
    $why = ''
    if (-not $text.Trim()) { $why = 'it is empty or could not be read' }
    else {
        try { $obj = ConvertFrom-Json -InputObject $text } catch { $why = "it does not parse: $(ConvertTo-OneLine $_.Exception.Message)" }
        if (-not $why -and -not (Test-IsJsonObject $obj)) { $why = 'it is not a JSON object' }
        if (-not $why -and -not [string](Get-PropertyValue $obj 'id' '')) { $why = 'it names no id' }
        if (-not $why -and @('starting', 'running', 'done') -notcontains [string](Get-PropertyValue $obj 'state' '')) { $why = "its state '$(Get-PropertyValue $obj 'state' '')' is not one of starting|running|done" }
    }
    if ($why) { return [pscustomobject]@{ Exists = $true; Record = $null; Error = "the status file '$Path' cannot be used: $why" } }
    return [pscustomobject]@{ Exists = $true; Record = (ConvertTo-DetachedRecord $obj); Error = '' }
}

# Every detached run of a task, newest first (by `started`, else the file time; then by id8):
# { Path; Id8; Record; Error; When; Log }. An atomic-write temp is not a run.
function Read-DetachedRuns {
    param([string]$TaskDir)
    $runs = New-Object System.Collections.Generic.List[object]
    if (-not $TaskDir -or -not [IO.Directory]::Exists($TaskDir)) { return , ([object[]]@()) }
    foreach ($f in [IO.Directory]::GetFiles($TaskDir, '.consult.detached-*.status.json')) {
        $name = [IO.Path]::GetFileName($f)
        if ($name -notmatch '^\.consult\.detached-([0-9A-Za-z]+)\.status\.json$') { continue }
        $id8 = $Matches[1].ToLowerInvariant()
        $rd = Read-DetachedStatus -Path $f
        $when = $null
        if ($rd.Record) { $when = ConvertTo-WhenOffset $rd.Record.started }
        if ($null -eq $when) { try { $when = [DateTimeOffset]([IO.File]::GetLastWriteTimeUtc($f)) } catch { $when = [DateTimeOffset]::MinValue } }
        $runs.Add([pscustomobject]@{ Path = $f; Id8 = $id8; Record = $rd.Record; Error = $rd.Error; When = $when; Log = (Join-Path $TaskDir ".consult.detached-$id8.log") })
    }
    $sorted = @($runs | Sort-Object -Property @{ Expression = { $_.When }; Descending = $true }, @{ Expression = { $_.Id8 }; Descending = $false })
    return , ([object[]]$sorted)
}

# "45 s" | "12 min" | "2 h 05 min" | "3 d 04 h"
function Format-DetachedSpan {
    param([TimeSpan]$Span)
    if ($Span.TotalSeconds -lt 0) { $Span = [TimeSpan]::Zero }
    if ($Span.TotalSeconds -lt 90) { return "$([int][Math]::Floor($Span.TotalSeconds)) s" }
    if ($Span.TotalMinutes -lt 90) { return "$([int][Math]::Floor($Span.TotalMinutes)) min" }
    if ($Span.TotalHours -lt 48) { return ('{0} h {1:D2} min' -f [int][Math]::Floor($Span.TotalHours), $Span.Minutes) }
    return ('{0} d {1:D2} h' -f [int][Math]::Floor($Span.TotalDays), $Span.Hours)
}

# The verdict on one detached run (D5, D6, D11): { State; Exit; Text; Finished; Of }
#   done           the run ended: Exit 0 when its exit was 0, else 1
#   running        not done, its background (pid + start time, on this host) is alive: Exit 2
#   elsewhere      not done, its background runs on another host: liveness cannot be checked
#                  from here and is never judged: Exit 2
#   starting       written by the foreground (no pid yet) less than 60 s ago: Exit 2
#   died           not done, and its background is gone: Exit 1 (its recovery records are
#                  judged by the next run of the task as usual)
#   never-started  still `starting` without a pid after 60 s: Exit 1
#   unreadable     the status file cannot be used ($Problem): Exit 1
# Finished / Of: its members that finished / that run (a roster-skipped entry does not run; a
# member the run never started - skipped "not started: ..." - counts as run and finished).
function Get-DetachedJudgement {
    param($Record, [string]$Problem = '', [DateTimeOffset]$Now = [DateTimeOffset]::Now)
    if ($Problem -or $null -eq $Record) {
        $text = $Problem
        if (-not $text) { $text = 'no status record' }
        return [pscustomobject]@{ State = 'unreadable'; Exit = 1; Text = $text; Finished = 0; Of = 0 }
    }
    $members = @($Record.members | Where-Object { $_ })
    $notStarted = { param($m) [string]$m.state -eq 'skipped' -and [string]$m.outcome -match '^not started' }
    $of = @($members | Where-Object { [string]$_.state -ne 'skipped' -or (& $notStarted $_) }).Count
    $finished = @($members | Where-Object { $script:DetachedMemberDone -contains [string]$_.state -or (& $notStarted $_) }).Count
    $started = ConvertTo-WhenOffset $Record.started
    $startedText = $(if ($Record.started) { [string]$Record.started } else { '(unknown)' })
    $state = [string]$Record.state
    if ($state -eq 'done') {
        $code = $Record.exit
        $exitText = $(if ($null -eq $code) { 'unknown' } else { [string]$code })
        $ok = ($null -ne $code -and [int]$code -eq 0)
        return [pscustomobject]@{ State = 'done'; Exit = $(if ($ok) { 0 } else { 1 }); Text = "done, exit $exitText"; Finished = $finished; Of = $of }
    }
    $bgPid = 0
    if ($null -ne $Record.pid) { $bgPid = [int]$Record.pid }
    if ($bgPid -le 0) {
        $age = $(if ($started) { $Now - $started } else { [TimeSpan]::MaxValue })
        if ($age.TotalSeconds -lt $script:DetachedStartGraceSec) {
            return [pscustomobject]@{ State = 'starting'; Exit = 2; Text = "starting - the background has not reported yet (started $(Format-DetachedSpan $age) ago)"; Finished = $finished; Of = $of }
        }
        # (wave 26, F07-2) conditional: a slow background may still report later - its self-report
        # then turns this record into `running` (the judgement is made afresh at every read)
        return [pscustomobject]@{ State = 'never-started'; Exit = 1; Text = "never started - no background process reported within $($script:DetachedStartGraceSec) s of $startedText; if one starts late it still reports and the run reads running again (its log may say why)"; Finished = $finished; Of = $of }
    }
    $recordHost = [string]$Record.host
    if ($recordHost -and $recordHost -ine [Environment]::MachineName) {
        return [pscustomobject]@{ State = 'elsewhere'; Exit = 2; Text = "running on host $recordHost since $startedText (pid $bgPid) - its liveness cannot be checked from this host"; Finished = $finished; Of = $of }
    }
    if (Test-PidAlive -ProcessId $bgPid -StartTime ([string]$Record.start_time)) {
        $since = $(if ($started) { " ($(Format-DetachedSpan ($Now - $started)))" } else { '' })
        return [pscustomobject]@{ State = 'running'; Exit = 2; Text = "running since $startedText$since, $finished of $of members finished"; Finished = $finished; Of = $of }
    }
    return [pscustomobject]@{ State = 'died'; Exit = 1; Text = "died - its background process (pid $bgPid) is gone without a final status, $finished of $of members finished; its recovery records are judged by the next run of the task as usual"; Finished = $finished; Of = $of }
}

# The line codex-findings.ps1 -List prints for a detached run of the task that is not done ('' for
# a done one): `detached <id8>: running since <t>, k of N members finished`, or its died,
# starting, never-started or other-host wording (D6), with the command that shows it.
function Format-DetachedListLine {
    param($Run, [string]$Task, [DateTimeOffset]$Now = [DateTimeOffset]::Now)
    $j = Get-DetachedJudgement -Record $Run.Record -Problem ([string]$Run.Error) -Now $Now
    if ($j.State -eq 'done') { return '' }
    return "detached $($Run.Id8): $($j.Text) (codex-consult.ps1 -Task $Task -Status -Id $($Run.Id8))"
}

# The SessionStart hook's phrase over every task of the collab root (D6): '' when no detached run
# is running, died or finished in the last $FinishedHours hours; else e.g. "; 1 detached
# consultation running (task t)" or "; detached consultations: 1 running (task t), 1 finished
# (task u)". Status files only; nothing is written.
function Get-DetachedPhrase {
    param([string]$CollabRoot, [DateTimeOffset]$Now = [DateTimeOffset]::Now, [int]$FinishedHours = 24)
    if (-not $CollabRoot -or -not [IO.Directory]::Exists($CollabRoot)) { return '' }
    $tasksOf = @{ running = (New-Object System.Collections.Generic.List[string]); finished = (New-Object System.Collections.Generic.List[string]); died = (New-Object System.Collections.Generic.List[string]) }
    $counts = @{ running = 0; finished = 0; died = 0 }
    foreach ($dir in [IO.Directory]::GetDirectories($CollabRoot)) {
        $task = [IO.Path]::GetFileName($dir)
        foreach ($run in (Read-DetachedRuns -TaskDir $dir)) {
            $j = Get-DetachedJudgement -Record $run.Record -Problem ([string]$run.Error) -Now $Now
            $cat = ''
            if (@('running', 'elsewhere', 'starting') -contains $j.State) { $cat = 'running' }
            elseif (@('died', 'never-started', 'unreadable') -contains $j.State) { $cat = 'died' }
            else {
                $fin = ConvertTo-WhenOffset $run.Record.finished
                if ($fin -and ($Now - $fin).TotalHours -lt $FinishedHours) { $cat = 'finished' }
            }
            if (-not $cat) { continue }
            $counts[$cat]++
            if (-not $tasksOf[$cat].Contains($task)) { $tasksOf[$cat].Add($task) }
        }
    }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($cat in @('running', 'finished', 'died')) {
        if ($counts[$cat] -eq 0) { continue }
        $tasks = @($tasksOf[$cat])
        $shown = ($tasks | Select-Object -First 3) -join ', '
        if ($tasks.Count -gt 3) { $shown += ', ...' }
        $parts.Add("$cat ($(if ($tasks.Count -eq 1) { 'task' } else { 'tasks' }) $shown)")
    }
    if ($parts.Count -eq 0) { return '' }
    $total = $counts.running + $counts.finished + $counts.died
    if ($parts.Count -eq 1) {
        return "; $total detached consultation$(if ($total -ne 1) { 's' }) $($parts[0])"
    }
    $withCounts = @(foreach ($cat in @('running', 'finished', 'died')) { if ($counts[$cat] -gt 0) { "$($counts[$cat]) " + (@($parts | Where-Object { $_.StartsWith("$cat ") }) | Select-Object -First 1) } })
    return "; detached consultations: $($withCounts -join ', ')"
}
