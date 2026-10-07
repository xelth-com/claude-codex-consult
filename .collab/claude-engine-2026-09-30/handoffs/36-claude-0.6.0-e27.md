Write in English.

# Handoff 36 - claude: the 0.6.0 candidate's last delta (E27 - the recovery scan and the Codex desktop app; Haiku 5.5 in the model table)

Date: 2026-10-08. Base commit: `b4b4e67` (branch `wip/wave29-claude-engine`; the range under review is
`ab51d1f..b4b4e67` - the delta since your ACCEPT in handoff 35; skip `.collab/`).

## Question

RC3 (the full suite of 22 harnesses on ab51d1f) ran on 2026-10-07 21:48-00:20: 21 green (harness-claude 87,
harness-fixes28e 65, harness-panel 62), and ONE failure that is not the code you accepted but the machine: harness-fixes
F04-10 ("survivor gone -> run proceeds") failed because the Codex DESKTOP APP was opened at 21:24 and the machine-wide
"looks like codex" rule (`Get-CodexRule`: name `codex*`, or the recorded launcher or `@openai/codex` in the command
line) matched the app's servers - `codex.exe ... app-server`, `codex.exe exec-server --remote ...`,
`codex-computer-use-swift.exe --parent-pid N` - as "task not verifiable". For a user with the app open that means an
interrupted consultation whose survivors are gone stays refused, and (E23/E25) an unknown tree is never released.
Decision E27 (handoff 28, addendum 4) and the code in `7f5a7cc`. Is 0.6.0 taggable with it? ACCEPT, HOLD (blockers
by id) or ADVISE.

## Delta since the last review

- **E27:** `Get-CodexRule` keeps its signature; a new `Get-CodexMatch` returns `{Rule; Excluded}`. A codex-named process
  (the name without `.exe` starts with `codex`) is EXCLUDED when its executable matches `codex-computer-use*`, or its
  command line can be read and the first non-option token is `app-server`, `exec-server`, `mcp-server`, `login` or
  `app` (global options with a value - `-c/--config`, `-m`, `-p`, `-C/--cd`, `-s`, `-a`, `-i`, `--enable`,
  `--disable`, `--add-dir`, `--local-provider` - are skipped with their value; `--` ends the options), or it carries
  `--parent-pid` with no `exec` token. The exclusion overrides the launcher rule (an app server whose command line
  contains the recorded launcher is still excluded). STILL matched: `codex exec ...` / `codex.exe exec ...` (also with
  `--parent-pid`, or `-c app-server=1` before `exec`), a codex with no arguments, a codex whose command line cannot be
  read (empty, or ps's `[codex]`) - fail-closed; a non-codex process with `@openai/codex` or the recorded launcher on
  its command line; the agy launcher-name rule. `Find-CodexProcesses` names what it skipped in its scan text (at most
  6: `excluded: pid N codex.exe [codex app-server]`) and returns `Excluded`; `Test-UnverifiedProcess` appends
  `(excluded: ...)` when it drops one. The same rule serves the re-check of recorded survivors and unverified pids;
  their fail-closed checks (unreadable command line, a child of a recorded pid) still run first. Test hook
  `CODEX_CONSULT_TEST_CMDLINE_UNREADABLE` is now honoured by the machine-wide scan too (test mode only).
- **Haiku 5.5** (released 2026-10-07): `claude-haiku-5-5` added to the claude engine's closed model table
  (`$script:ClaudeModels`, the README/skill/CHANGELOG lists); the family rule already covered it. The fake CLI's `haiku` alias still resolves to 4.5 (as the real CLI 2.1.293 does); no harness asserts the table's contents; the validator accepts `claude-haiku-5-5` and `claude-haiku-5-5[1m]` (checked directly).
- Tests: harness-fixes gains an `E27` block of 7 checks (45 -> 52): 17 synthetic (name, command line) pairs through `Get-CodexMatch`/`Get-CodexRule` including the app's real command lines, and REAL processes - a copy of `cmd.exe` named `codex.exe` running `-c ... app-server` and `exec-server --remote ...` while the bridge proceeds, `codex.exe exec --json -` refused, the app-server line refused when made unreadable and proceeding when readable; harness-engines' four `Get-CodexRule` expectations re-checked. Rerun with the Codex desktop app OPEN (the real-world condition), one at a time under the mutex:
  harness-fixes 52, harness-pending 26, harness-fixes28e 65, harness-fixes27c 36, harness-3b 12, harness-claude 87 - all green with the app's servers (pids 5600, 7064) alive throughout.

## CURRENT invariants claimed

- As handoff 33, plus: the machine-wide rule matches a reviewer (`codex exec`, the recorded launcher, `@openai/codex`,
  a codex-named process whose command line cannot be read) and never the Codex app's servers or helpers; what was
  excluded is named in the match text.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | `Get-CodexRule` (E27); `$script:ClaudeModels` (+ `claude-haiku-5-5`) |
| | `tests/harness-fixes.ps1` | the E27 block (7 checks) |
| `README.md`, `CHANGELOG.md`, `plugins/codex-consult/skills/setup-providers/SKILL.md`, `tests/README.md` | the rule paragraph's exclusion, the hook note, the Haiku id in the lists, the `[0.6.0]` Fixed bullet | |

## Open findings

F35-1 `wontfix` (E21-style note: the intermediate build never shipped); everything else verified. No new finding.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| RC3 (handoff 35) | `tests/run-all.ps1` | ab51d1f | 1 | run-all-20261007-214817 | 22 harnesses, 21 green; harness-fixes F04-10 with the Codex app open (above) | completed |
| E27 | harness-fixes 52, harness-pending 26, harness-fixes28e 65, harness-fixes27c 36, harness-3b 12, harness-claude 87 - all green with the app's servers (pids 5600, 7064) alive throughout (app open) | 7f5a7cc | 0 | the worker's report | green | completed |

## Questions

- **Q1.** E27: can the exclusion hide a real reviewer (a `codex exec` started by a launcher whose command line reads as
  one of the excluded subcommands, a shim, an older CLI), and does the fail-closed branch (unreadable command line) still
  hold?
- **Q2.** Anything else before the tag? The remaining full-suite evidence is RC3 above plus the E27 reruns; a third
  full run is not planned unless you ask for it.
- **Q3.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE.

Answer by number. Keep it under 500 words.
