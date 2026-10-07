# Handoff 23 - Claude (claude): smoke-badtoken

Date: 2026-10-07 04:26 local. Author: Claude (claude) (model glm-5.3, effort low), claude-cli 2.1.292.0.
Reviewer: ZAI-bad :: glm-5.3 [claude] (provider from -Provider, model from roster; engine claude (C:\users\dmytro\.local\bin\claude.exe), endpoint https://api.z.ai/api/anthropic (token from env AB_BAD_TOKEN); provider fingerprint 1cf82d4791c7; harness claude-cli 2.1.292.0).
Preflight: ok: env AB_BAD_TOKEN set.
Roster: C:/Users/Dmytro/AppData/Local/Temp/claude/C--Users-Dmytro-claude-codex-consult/3e7ca0bd-b95a-43fd-96e9-33788e0af7a8/scratchpad/roster-endpoint.json - entry 13 of 13 for -Provider ZAI-bad (engine, model applied).
Effort: low sent (requested low, mapping claude-v1, by caps-v1: engine:claude, any model; not confirmed by the provider). Consultation id: 436e2dc0-d2a6-4931-b686-b69042d37055.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn's init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply), purpose: chore). Argv: `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model glm-5.3 --effort low --session-id d2ad3f36-6686-463b-9140-0fc955bcdd77` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage ZAI-bad :: glm-5.3 [claude] in this task's ledger; other lineage(s): mimo-claude :: mimo-v2.6-pro [claude], openai :: gpt-6-astra, meta :: muse-spark-1.3-contributor [muse], byteplus :: dola-seed-2.0-pro, kimi :: k3, ZAI-claude :: glm-5.3 [claude], mimo :: mimo-v2.6-pro, ZAI :: glm-5.3, gemini :: gemini-3.1-pro-high [agy]). Result thread: `d2ad3f36-6686-463b-9140-0fc955bcdd77` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/21-claude-claude-engine-acceptance-decisions.md` (sha256 02c75199ae43). Reviewed: 11af9bc, base 11af9bc1e6e56d66aabd362c83a0b2e5e6270429, tree sha256 5fccf28ff1a0, 0 changed files.
Bridge outcome: failed: claude exit 1 - Failed to authenticate. API Error: 401 token expired or incorrect. Wall time: 184.8 s. Tokens: in 0 (cached 0), out 0, reasoning ?.
Engine turns: 1 (claude -p, auth endpoint; init tools Glob, Grep, Read; permission denials 0).
Timeout: 600 s (-TimeoutSec); continuation after a timeout kill: up to 600 s.
Partial reply: `handoffs/23-claudecode-smoke-badtoken.partial.md` - the run ended: claude exit 1 - Failed to authenticate. API Error: 401 token expired or incorrect; thread d2ad3f36-6686-463b-9140-0fc955bcdd77 - continue with `-Task claude-engine-2026-09-30 -Mode resume -Thread d2ad3f36-6686-463b-9140-0fc955bcdd77 -Purpose chore -ReplyName smoke-badtoken -TimeoutSec 600 -Prompt "finish your review"`.
Provider failure: auth - Failed to authenticate. API Error: 401 token expired or incorrect.
Raw event stream: `handoffs/23-claudecode-smoke-badtoken.events.jsonl`.
Verbatim reply follows.

---

_(no reply captured - what the killed turn(s) produced is salvaged in `handoffs/23-claudecode-smoke-badtoken.partial.md`)_

Claude (claude) reported: Failed to authenticate. API Error: 401 token expired or incorrect

```
⚠ claude.ai connectors are disabled because ANTHROPIC_API_KEY or another auth source is set and takes precedence over your claude.ai login · Unset it to load your organization's connectors
[claude-code:unrecognized_model] {"model":"glm-5.3","query_source":"sdk"}
```
