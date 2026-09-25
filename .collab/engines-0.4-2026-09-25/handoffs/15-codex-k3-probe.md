# Handoff 15 - Codex: k3-probe

Date: 2026-09-25 18:53 local. Author: Codex (model kimi-k3, effort medium), Codex CLI 0.155.1.
Reviewer: byteplus :: kimi-k3 (provider from -Provider, model from -Model; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Effort: medium sent (requested medium, mapping native, by -NativeEffort, sent verbatim; not confirmed by the provider). Consultation id: 07808d69-94aa-45db-a5ab-0d2a2c818d11.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m kimi-k3 -c model_reasoning_effort="medium" -c model_provider="byteplus" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-b105904daecc4080980af4a6fd4da792.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage byteplus :: kimi-k3 in this task's ledger; other lineage(s): gemini :: gemini-3.8-flash-low [agy], gemini :: gemini-3.8-flash-high [agy], mimo :: mimo-v2.6-pro, ZAI :: glm-5.3). Result thread: `01a0d97c-4423-7061-a68e-19c2bef73a14` (source: events).
Brief: (none, prompt only). Reviewed: 4e2016f + uncommitted, base 4e2016f1c7627050db12718b9f2e72f6c786f2a2, tree sha256 a8cf2d6db37d, 6 changed files.
Bridge outcome: failed: codex exit 1 - unexpected status 401 Unauthorized: The API key format is incorrect. Request id: 0217903552230390eb6750cc7dc4c5e11333efa00d940ee3d369b, url: https://ark.ap-southeast.bytepluses.com/api/coding/v3/responses, request id: 0217903552230390eb6750cc7dc4c5e11333efa00d940ee3d369b. Wall time: 28.8 s. Tokens: unknown.
Provider failure: auth - unexpected status 401 Unauthorized: The API key format is incorrect. Request id: 0217903552230390eb6750cc7dc4c5e11333efa00d940ee3d369b, url: https://ark.ap-southeast.bytepluses.com/api/coding/v3/respo.
Raw event stream: `handoffs/15-codex-k3-probe.events.jsonl`.
Verbatim reply follows.

---

_(no reply captured)_

Codex reported: unexpected status 401 Unauthorized: The API key format is incorrect. Request id: 0217903552230390eb6750cc7dc4c5e11333efa00d940ee3d369b, url: https://ark.ap-southeast.bytepluses.com/api/coding/v3/responses, request id: 0217903552230390eb6750cc7dc4c5e11333efa00d940ee3d369b

```
2026-09-25T16:53:14.908593Z ERROR codex_models_manager::manager: failed to refresh available models: unexpected status 401 Unauthorized: The API key format is incorrect. Request id: 021790355195597c95e3350f28d4e5f7ad155450ef541a396bd52, url: https://ark.ap-southeast.bytepluses.com/api/coding/v3/models?client_version=0.155.1, request id: 021790355195597c95e3350f28d4e5f7ad155450ef541a396bd52
2026-09-25T16:53:14.911106Z ERROR codex_models_manager::manager: failed to refresh available models: unexpected status 401 Unauthorized: The API key format is incorrect. Request id: 021790355195605a4a9e4d164f3c176730993b0b2e8dd9dc6cc17, url: https://ark.ap-southeast.bytepluses.com/api/coding/v3/models?client_version=0.155.1, request id: 021790355195605a4a9e4d164f3c176730993b0b2e8dd9dc6cc17
```
