Write in English.

# Handoff 38 - claude: E28 (the fail-closed exclusion) - the last round before the 0.6.0 tag

Date: 2026-10-08. Base commit: `e0cbafe` (branch `wip/wave29-claude-engine`; the range under review is `b4b4e67..e0cbafe` -
the fix since your HOLD in handoff 37; skip `.collab/`).

## Question

Your round on handoff 36 held on F37-1: E27's tokenizer toggled quoting at a Windows backslash-escaped quote, so a
reviewer with `-c "developer_instructions=\"please app-server check\"" exec --json -` could be excluded and an
unknown-tree record released. Decision E28 (handoff 28, addendum 5); the code is `67a0029`. ACCEPT, HOLD (blockers by
id) or ADVISE.

## Delta since the last review

- **E28** (`Get-CodexServerExclusion`, codex-named processes only, in this order): (1) a readable command line that
  contains the word `exec` ANYWHERE - matched as `(?<![\w-])exec(?![\w-])` on the raw text AND on every parsed
  argument (so `e"x"ec` counts; a hyphen is part of the word, so the app's `exec-server` is still excluded) - is NEVER
  excluded: the process matches as `name codex`; (2) `codex-computer-use*` excluded by name even with an unreadable
  command line; (3) an unreadable command line is not excluded (fail-closed); (4) unbalanced quoting (a line ending
  inside quotes, a program-name quote never closed) is not excluded - Rule `command line ambiguous - counted as
  codex`; (5) a server subcommand (`app-server`, `exec-server`, `mcp-server`, `login`, `app` as the first non-option
  token) is excluded, the tokenizer now following the Windows/Rust rules the Codex CLI itself uses (`\"` inside a
  quoted value is a literal quote, `""` inside quotes one literal quote, backslashes before a quote halved); (6)
  `--parent-pid` without `exec` excluded. The launcher and `@openai/codex` rules unchanged. Side effects, named: a
  codex-prefixed helper with unbalanced quotes now counts as codex (before: never matched); a codex-prefixed process
  not named exactly `codex` carrying `exec` is still matched only by the launcher / `@openai/codex` rules.
- Note on the encodings: your encoding `-c "developer_instructions=\"please app-server check\"" exec` was the one E27
  mis-read; the alternative `-c developer_instructions="please \"app-server\" check" exec` stayed one token even
  before. Both are tested as REAL processes.
- RC1 (harness-fixes, the E27 block, 52 -> 56): 9 synthetic pairs + a tokenizer check (both escaped encodings,
  `e"x"ec`, `exec` inside a server's value, `\"` and `""` in a real app-server's value still excluded, three
  unbalanced-quote cases); two `cmd.exe` copies named `codex.exe` carrying the two encodings followed by `exec --json
  -`, under a recorded launcher (stopped) and an unrecorded intermediate (stopped) - their parent confirmed dead; the
  scan finds both as `[name codex, task not verifiable]`, neither in the excluded list, the app-like servers still
  excluded; a panel member's `kill_unconfirmed` record is refused (exit 1) naming both pids while they live, no
  reviewer launched, the record byte-identical; released after they exit with the server exclusions named and no
  reviewer pid among them; the desktop-server and unreadable-command controls kept; a negative control against the
  E27 scripts fails the new checks (the escaped reviewer appears in `Excluded`).
- RC2 (with the Codex desktop app's servers alive throughout, one at a time under the mutex): harness-fixes 56,
  harness-pending 26, harness-fixes28e 65, harness-fixes27c 36, harness-3b 12 - all green; the release line reads
  `excluded: pid N codex.exe [codex app-server], pid M codex.exe [codex exec-server], ...` with no reviewer pid.

## CURRENT invariants claimed

- A codex-named process is excluded from the recovery scan only when its command line was read, parsed without
  ambiguity, carries no `exec` word anywhere, and names one of the app's server subcommands (or is a known helper);
  every other codex-named process counts as a reviewer.

## Changed files

| File | Change |
|---|---|
| `plugins/codex-consult/scripts/codex-consult-common.ps1` | `Get-CodexServerExclusion`, the tokenizer, `Get-CodexMatch` |
| `tests/harness-fixes.ps1`, `tests/README.md`, `README.md`, `CHANGELOG.md` | the E27 block (+4), one sentence each |

## Open findings

F37-1 `implemented` (67a0029); F35-1 `wontfix`; everything else verified. No new finding.

## Requested checks run

| check | command | revision | exit | log | observation | state |
|---|---|---|---|---|---|---|
| RC1 | `tests/run-all.ps1 -Only harness-fixes` (E27 block) | 67a0029 | 0 | the worker's report | 56/56 | completed |
| RC2 | the five recovery harnesses, app open | 67a0029 | 0 | the worker's report | all green | completed |
| RC3 (handoff 35) | `tests/run-all.ps1` | ab51d1f | 1 | run-all-20261007-214817 | 21 of 22 green; harness-fixes failed only on the app condition E27/E28 fix | completed |

## Questions

- **Q1.** E28: a reviewer the exclusion can still hide, or an app process it now counts as a reviewer in a way that
  blocks a task forever (the hyphen rule, the ambiguity rule)?
- **Q2.** Verdict: ACCEPT, HOLD (blockers by id), or ADVISE. The tag follows an ACCEPT directly (the evidence: RC3 of
  handoff 35 plus the E27/E28 reruns with the app open).

Answer by number. Keep it under 400 words.
