# (wave 30, T15) The rollout a FAKE codex writes, dot-sourced by fake-codex.ps1 and fake-codex3.ps1:
# shaped like codex-cli 0.155's <CODEX_HOME>\sessions\<yyyy>\<MM>\<dd>\rollout-<ts>-<thread>.jsonl - a
# session_meta line, then per model call a token_count event with the running total_token_usage, the
# call's last_token_usage, model_context_window and rate_limits (limit_id codex: primary = the 5-hour
# window, secondary = the weekly one), followed by the "premium" line with null windows and the same
# totals (as the real CLI writes it). Written ONLY under a CODEX_HOME the harness set (never the
# default ~/.codex). Switches:
#   FAKE_CODEX_QUOTA=1                write the rollout (else nothing happens)
#   FAKE_CODEX_QUOTA_PRIMARY=<pct>    the 5-hour window's used_percent (default 42)
#   FAKE_CODEX_QUOTA_RESET_MIN=<m>    its resets_at, minutes from now (default 120; negative: past)
#   FAKE_CODEX_QUOTA_SECONDARY=<pct>  the weekly window's used_percent (default 15, resets in 3 days)
#   FAKE_CODEX_QUOTA_NULL=1           both windows null (an older rollout / another plan)
#   FAKE_CODEX_QUOTA_CALLS=<n>        model calls (default 3): call i reads 1000*i input tokens
#                                     (500*i cached), writes 10
#   FAKE_CODEX_QUOTA_PAD_KB=<kb>      a response_item line of that many KB after session_meta (a
#                                     large thread)
#   FAKE_CODEX_QUOTA_SUBAGENT=1       also a sub-agent rollout (session_meta names the thread as
#                                     parent_thread_id): 2 calls of 2000 input tokens, its windows
#                                     FAKE_CODEX_QUOTA_SUBAGENT_PRIMARY (default: the thread's)
#                                     observed 1 s later
#   FAKE_CODEX_QUOTA_LOG=<path>       "<kind> <thread> <path>" per rollout written
# A fork (`fork <parent>`) starts its totals at the parent rollout's last total (the real CLI's
# inheritance); a resume (`resume <thread>`) appends to the thread's rollout and continues its total.
$script:FakeU8 = New-Object System.Text.UTF8Encoding($false)

function New-FakeV7Id {
    param([DateTimeOffset]$At = [DateTimeOffset]::UtcNow)
    $ms = '{0:x12}' -f $At.ToUnixTimeMilliseconds()
    $r = [guid]::NewGuid().ToString('N')
    return "$($ms.Substring(0, 8))-$($ms.Substring(8, 4))-7$($r.Substring(0, 3))-8$($r.Substring(3, 3))-$($r.Substring(6, 12))"
}

function Find-FakeRollout {
    param([string]$Thread)
    $root = Join-Path $env:CODEX_HOME 'sessions'
    if (-not (Test-Path -LiteralPath $root)) { return '' }
    $f = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter "rollout-*-$Thread.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)
    if ($f.Count -eq 0) { return '' }
    return $f[0].FullName
}

function Get-FakeLastTotal {
    param([string]$Path)
    $t = [pscustomobject]@{ input = [long]0; cached = [long]0; output = [long]0 }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $t }
    $m = [regex]::Matches([IO.File]::ReadAllText($Path), '"total_token_usage":\{"input_tokens":([0-9]+),"cached_input_tokens":([0-9]+),"cache_write_input_tokens":0,"output_tokens":([0-9]+)')
    if ($m.Count -gt 0) { $l = $m[$m.Count - 1]; $t.input = [long]$l.Groups[1].Value; $t.cached = [long]$l.Groups[2].Value; $t.output = [long]$l.Groups[3].Value }
    return $t
}

function Format-FakeWindow {
    param($Used, [double]$ResetMin, [int]$Minutes)
    if ($null -eq $Used -or "$Used" -eq '') { return 'null' }
    $reset = [DateTimeOffset]::UtcNow.AddMinutes($ResetMin).ToUnixTimeSeconds()
    return '{"used_percent":' + ([double]$Used).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + ',"window_minutes":' + $Minutes + ',"resets_at":' + $reset + '}'
}

function Get-FakeStamp { param([DateTimeOffset]$At) return $At.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture) }

function Add-FakeTokenLines {
    param([System.Text.StringBuilder]$Sb, [DateTimeOffset]$At, $Total, [long]$Last, [string]$Primary, [string]$Secondary)
    $tt = '{"input_tokens":' + $Total.input + ',"cached_input_tokens":' + $Total.cached + ',"cache_write_input_tokens":0,"output_tokens":' + $Total.output + ',"reasoning_output_tokens":0,"total_tokens":' + ($Total.input + $Total.output) + '}'
    $lt = '{"input_tokens":' + $Last + ',"cached_input_tokens":' + [long]($Last / 2) + ',"cache_write_input_tokens":0,"output_tokens":10,"reasoning_output_tokens":0,"total_tokens":' + ($Last + 10) + '}'
    $info = '{"total_token_usage":' + $tt + ',"last_token_usage":' + $lt + ',"model_context_window":258400}'
    [void]$Sb.Append('{"timestamp":"' + (Get-FakeStamp $At) + '","type":"event_msg","payload":{"type":"token_count","info":' + $info + ',"rate_limits":{"limit_id":"codex","limit_name":null,"primary":' + $Primary + ',"secondary":' + $Secondary + ',"credits":{"has_credits":false,"unlimited":false,"balance":"0"},"plan_type":"plus","rate_limit_reached_type":null}}}' + "`n")
    [void]$Sb.Append('{"timestamp":"' + (Get-FakeStamp $At) + '","type":"event_msg","payload":{"type":"token_count","info":' + $info + ',"rate_limits":{"limit_id":"premium","limit_name":null,"primary":null,"secondary":null,"credits":{"has_credits":false,"unlimited":false,"balance":"0"},"plan_type":"plus","rate_limit_reached_type":null}}}' + "`n")
}

# Writes the thread's rollout (and the sub-agent's); $Raw: the fake's command line (fork / resume).
function Write-FakeRollout {
    param([string]$Thread, [string]$Raw)
    if ($env:FAKE_CODEX_QUOTA -ne '1' -or -not $env:CODEX_HOME -or -not $Thread) { return }
    $now = [DateTimeOffset]::Now
    $dir = Join-Path (Join-Path (Join-Path (Join-Path $env:CODEX_HOME 'sessions') $now.ToString('yyyy')) $now.ToString('MM')) $now.ToString('dd')
    [void][IO.Directory]::CreateDirectory($dir)
    $resetMin = $(if ($env:FAKE_CODEX_QUOTA_RESET_MIN) { [double]$env:FAKE_CODEX_QUOTA_RESET_MIN } else { 120 })
    $pUsed = $(if ($env:FAKE_CODEX_QUOTA_PRIMARY) { $env:FAKE_CODEX_QUOTA_PRIMARY } else { '42' })
    $sUsed = $(if ($env:FAKE_CODEX_QUOTA_SECONDARY) { $env:FAKE_CODEX_QUOTA_SECONDARY } else { '15' })
    $primary = $(if ($env:FAKE_CODEX_QUOTA_NULL -eq '1') { 'null' } else { Format-FakeWindow $pUsed $resetMin 300 })
    $secondary = $(if ($env:FAKE_CODEX_QUOTA_NULL -eq '1') { 'null' } else { Format-FakeWindow $sUsed (3 * 1440) 10080 })
    $calls = $(if ($env:FAKE_CODEX_QUOTA_CALLS) { [int]$env:FAKE_CODEX_QUOTA_CALLS } else { 3 })
    $path = ''
    $total = [pscustomobject]@{ input = [long]0; cached = [long]0; output = [long]0 }
    $sb = New-Object System.Text.StringBuilder
    if ($Raw -match ' resume ([0-9a-fA-F-]{36})' -and $Matches[1] -eq $Thread) { $path = Find-FakeRollout $Thread; $total = Get-FakeLastTotal $path }
    if (-not $path) {
        if ($Raw -match ' fork ([0-9a-fA-F-]{36})') { $total = Get-FakeLastTotal (Find-FakeRollout $Matches[1]) }
        $path = Join-Path $dir "rollout-$($now.ToString('yyyy-MM-ddTHH-mm-ss'))-$Thread.jsonl"
        [void]$sb.Append('{"timestamp":"' + (Get-FakeStamp $now) + '","type":"session_meta","payload":{"id":"' + $Thread + '","timestamp":"' + (Get-FakeStamp $now) + '","cwd":"fake","originator":"codex_exec","cli_version":"0.155.1-fake","source":"exec","model_provider":"openai"}}' + "`n")
        $pad = $(if ($env:FAKE_CODEX_QUOTA_PAD_KB) { [int]$env:FAKE_CODEX_QUOTA_PAD_KB } else { 0 })
        if ($pad -gt 0) { [void]$sb.Append('{"timestamp":"' + (Get-FakeStamp $now) + '","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"' + ('x' * ($pad * 1024)) + '"}]}}' + "`n") }
    }
    for ($i = 1; $i -le $calls; $i++) {
        $last = [long](1000 * $i)
        $total.input += $last; $total.cached += [long](500 * $i); $total.output += 10
        Add-FakeTokenLines -Sb $sb -At $now.AddMilliseconds($i) -Total $total -Last $last -Primary $primary -Secondary $secondary
    }
    [IO.File]::AppendAllText($path, $sb.ToString(), $script:FakeU8)
    if ($env:FAKE_CODEX_QUOTA_LOG) { [IO.File]::AppendAllText($env:FAKE_CODEX_QUOTA_LOG, "thread $Thread $path`n") }
    if ($env:FAKE_CODEX_QUOTA_SUBAGENT -eq '1') {
        $sid = New-FakeV7Id
        $spath = Join-Path $dir "rollout-$($now.ToString('yyyy-MM-ddTHH-mm-ss'))-$sid.jsonl"
        $sp = $(if ($env:FAKE_CODEX_QUOTA_SUBAGENT_PRIMARY) { Format-FakeWindow $env:FAKE_CODEX_QUOTA_SUBAGENT_PRIMARY $resetMin 300 } else { $primary })
        $ssb = New-Object System.Text.StringBuilder
        [void]$ssb.Append('{"timestamp":"' + (Get-FakeStamp $now) + '","type":"session_meta","payload":{"id":"' + $sid + '","forked_from_id":"' + $Thread + '","timestamp":"' + (Get-FakeStamp $now) + '","cwd":"fake","originator":"codex_exec","cli_version":"0.155.1-fake","source":{"subagent":{"thread_spawn":{"parent_thread_id":"' + $Thread + '","depth":1,"agent_nickname":"Fake"}}},"model_provider":"openai"}}' + "`n")
        $st = [pscustomobject]@{ input = [long]0; cached = [long]0; output = [long]0 }
        for ($i = 1; $i -le 2; $i++) {
            $st.input += 2000; $st.cached += 1000; $st.output += 10
            Add-FakeTokenLines -Sb $ssb -At $now.AddSeconds(1).AddMilliseconds($i) -Total $st -Last 2000 -Primary $sp -Secondary $secondary
        }
        [IO.File]::AppendAllText($spath, $ssb.ToString(), $script:FakeU8)
        if ($env:FAKE_CODEX_QUOTA_LOG) { [IO.File]::AppendAllText($env:FAKE_CODEX_QUOTA_LOG, "subagent $sid $spath`n") }
    }
}
