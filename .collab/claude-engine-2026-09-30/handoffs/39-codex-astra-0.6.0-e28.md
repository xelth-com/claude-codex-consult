# Handoff 39 - Codex: astra-0.6.0-e28

Date: 2026-10-08 01:16 local. Author: Codex (model gpt-6-astra, effort high), Codex CLI 0.155.1.
Reviewer: openai :: gpt-6-astra (provider from -Provider, model from roster; endpoint builtin:openai; provider fingerprint 56d97b6ece36; harness codex-cli 0.155.1).
Preflight: ok: Logged in using ChatGPT.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 1 of 12 for -Provider openai (model applied).
Effort: high sent (requested high, mapping openai, by caps-v1: builtin:openai, any model; not confirmed by the provider). Consultation id: 9250759b-9754-45b2-b9e3-44206c3fb43f.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m gpt-6-astra -c model_reasoning_effort="high" -c model_provider="openai" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-39e682d4702644bcb4c15b2b993e492a.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json fork 01a1188c-1205-7041-acca-b9cfc8a89a80 -` (prompt on stdin).
Parent thread: `01a1188c-1205-7041-acca-b9cfc8a89a80`. Result thread: `01a118a7-eee5-7943-8f20-c589977ce104` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/38-claude-0.6.0-e28.md` (sha256 c7e7e2e95179). Reviewed: e0d6168, base e0d6168cb39f97c0983af303375236d9eb7372e8, tree sha256 cc9644e64041, 0 changed files.
Bridge outcome: usable reply. Wall time: 97.8 s. Tokens: in 15000646 (cached 12288896), out 82329, reasoning 20739.
Timeout: 3600 s (the default of purpose acceptance); continuation after a timeout kill: up to 900 s. Range: `b4b4e67..e0cbafe` - the range changes 12 files, 755 lines (714 insertions, 41 deletions).
Verdict: ACCEPT - E28 fixes the demonstrated unsafe recovery release, with no remaining blocker found in this delta; its conservative server false positives are an availability tradeoff. Findings: 0 blocker, 0 major, 0 minor, 1 note (F39-1, tracked in `findings.json`). Structured reply: `handoffs/39-codex-astra-0.6.0-e28.reply.json`.
Raw event stream: `handoffs/39-codex-astra-0.6.0-e28.events.jsonl`.
Verbatim reply follows.

---

1. **F37-1 is fixed.** Both escaped configuration encodings now tokenize correctly and remain matched as reviewers. Read-only recovery replays returned `Active=true` for the original orphan scenario, `e"x"ec`, an unreadable command line, and ambiguous quoting. A normal `exec-server` was excluded, and recovery released after the reviewer disappeared. I found no additional unsafe exclusion in the reviewed bridge launch cases.

   **An app process can still hold recovery indefinitely while it remains alive.** The whole-word guard also matches incidental text: `"C:\tools\exec\codex.exe" app-server` counts as a reviewer, as does a server configuration value containing `exec`. I reproduced that behavior through recovery. This is E28’s deliberate conservative tradeoff, recorded as nonblocking finding #1. The hyphen rule correctly avoids matching `exec-server`. Known computer-use helpers retain their explicit name-based exception; unreadable ordinary `codex.exe` processes remain protected.

2. **ACCEPT this delta for tagging; no blockers remain.** The production change and regression fixtures address the original failure at both matcher and recovery levels. Both changed PowerShell files parsed successfully, and the non-`.collab` diff passed whitespace checks. The reported five recovery-harness reruns, together with the earlier full-suite evidence, are sufficient for this bounded change; another complete suite is unnecessary.

   I independently ran read-only matcher and mocked recovery checks. The native-process harness results are reported evidence from handoff 38, not runs performed during this review. The first-run checklist below specifies the observable acceptance signals.

---

### Findings

- **F39-1** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:9908`, `plugins/codex-consult/scripts/codex-consult-common.ps1:9910` - E28's whole-word exec guard can keep recovery blocked by an unrelated, long-lived app server when exec appears in its executable path or configuration value. This is a conservative availability tradeoff, not an unsafe release. Trigger: A machine-wide recovery scan encounters a qualifying process such as `"C:\tools\exec\codex.exe" app-server`, started after the pending record, after the actual reviewer has exited. Evidence: read-code: The raw command line and every parsed token are checked for exec before server-subcommand exclusion, including the executable path and option values.; ran-command: The server-path example returned Rule='name codex', Excluded='', and Active=true. Removing the process returned Active=false. A normal exec-server command remained excluded. Verify: Replay an unknown-tree pending record with the server-path example as its sole post-start process; confirm recovery remains active until that process disappears. Remedy: Retain the conservative guard for this release, but document incidental path/configuration matches and clarify the refusal reason so operators can identify the unrelated process before taking recovery action.

### Prior findings

- F37-1 - fixed - The corrected tokenizer and exec guard protect both escaped encodings. Independent mocked recovery replay kept the original orphan scenario active; the added native-process fixtures also cover refusal, unchanged pending state, and release after exit.

## Verdict: ACCEPT

E28 fixes the demonstrated unsafe recovery release, with no remaining blocker found in this delta; its conservative server false positives are an availability tradeoff.

### Blockers

_(none)_

### Unproven scenarios

- The native-process harnesses were not rerun during this read-only review; their passing results are reported in handoff 38.
- Arbitrary launcher shims, future CLI argument layouts, and non-Windows command-line representations were not exhaustively tested.

### First-run checklist (observable)

- [ ] While an escaped-configuration reviewer survives beneath a dead intermediate, recovery refuses launch, names its PID, and retains the pending record unchanged.
- [ ] Unreadable or ambiguous ordinary codex.exe command lines retain recovery protection.
- [ ] After the reviewer exits, recovery reports release while ordinary app-server and exec-server processes remain alive and appear in the exclusion list.
- [ ] No surviving reviewer PID appears in the exclusion list.
- [ ] Any app server counted because of incidental exec text is identified as the process holding recovery; an exit code alone must not imply that recovery completed.
