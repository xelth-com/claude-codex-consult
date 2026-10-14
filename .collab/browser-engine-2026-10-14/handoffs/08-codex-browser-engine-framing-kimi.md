# Handoff 08 - Codex: browser-engine-framing-kimi

Date: 2026-10-14 14:56 local. Author: Codex (model k3, effort high), Codex CLI 0.155.1.
Reviewer: kimi :: k3 (provider from roster, model from roster; endpoint https://api.kimi.ai/coding/v1, wire_api: responses; provider fingerprint 8f7901d404b5; harness codex-cli 0.155.1).
Preflight: ok: env KIMI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 8 of 10, panel 34c8b9a5 member 7 of 10.
Effort: high sent (requested high, mapping kimi-v1, by caps-v1: api.kimi.ai, k3; not confirmed by the provider). Consultation id: b11bc146-ad87-4d81-889b-78963948519b.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m k3 -c model_reasoning_effort="high" -c model_provider="kimi" -c features.multi_agent=false -c model_context_window=256000 -c model_auto_compact_token_limit=204800 -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-7760c7bf138645e9b13daf29902bdd08.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a13a7c-1c4e-73a0-8e41-c85cdcca09d0` (source: events).
Brief: `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` (sha256 19fb466d7f96). Reviewed: 49dde0c, base 49dde0cc2b7f0ba2e40fa90c0c60536ca7965b30, tree sha256 99269e8342cd, 0 changed files.
Bridge outcome: usable reply. Wall time: 367.3 s. Tokens: in 453843 (cached 353536), out 4593, reasoning 1486.
Quota (rollout): no window in the rollout; this run 453843 input tokens (353536 cached) in 9 calls, max 55357 per call of 243200; sub-agents 0; sub-agents off (features.multi_agent=false); budget 15 % of the 5-hour window.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The framing is sound and the boundary is correctly stated as a constraint, but the current ROADMAP shape contains three fixable defects (distribution wording, WASM-first choice, unauthenticated relay default) and omits several options worth deciding explicitly before build order is frozen. Findings: 0 blocker, 3 major, 1 minor, 0 note (F08-1..F08-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/08-codex-browser-engine-framing-kimi.reply.json`.
Raw event stream: `handoffs/08-codex-browser-engine-framing-kimi.events.jsonl`.
Verbatim reply follows.

---

## Challenging the framing first

Two things the brief treats as settled deserve a re-look. (1) **WASM-first is not obviously the right v1.** WASM cannot touch the DOM; a JS host shim does all real work either way, so the security boundary is the host API, not the bytecode. JS adapters behind the same capability-scoped host API are equally signable and far easier to debug through DOM churn. (2) **"Adapters are fetched and updated through the telemetry channel" contradicts the stated boundary** — that makes the product a distributor of unauthored adapter code. Catalogue = pointers + hashes only.

Options the brief does not list: a **manual clipboard mode** (bridge formats the pack, user pastes, extension only reads the reply — the lowest-risk degradation path and a legitimate v0); **grok has an official API** (xAI) that may be cheaper to add as an `http` engine than automating grok.com; and a **bookmarklet/in-page userscript** variant that skips the extension entirely for read-only capture.

To choose between options I would need: (a) how often gemini.google.com and grok.com DOMs actually churn (decides JS vs WASM investment and fuzzy-selector budget); (b) whether the operator's risk tolerance permits the catalogue to even *name* sites, or only adapter hashes; (c) whether C3 already has a WASM runtime or that must be built from scratch; (d) whether the user's xAI/Grok terms actually forbid automation (grok may not need a browser adapter at all).

## Q1 — Boundary design
The product must NOT contain: any shipped adapter, default-enabled adapters, selectors or site names in code/docs, tutorials like "how to automate Gemini", a default adapter list, or update machinery that pushes adapter bytes. Docs phrase it as userscript managers do (Tampermonkey/Violentmonkey ship zero scripts and no site logic); OpenInterpreter and Playwright phrase it as "you automate what you are authorized to automate". The catalogue may list adapter name, author, source URL, SHA-256 hash, signature, and usefulness score — never the code. An explicit `adapter author / user assumes site-terms responsibility` line in the enable dialog, mirroring the xelixir lands-disabled rule.

## Q2 — Technical shape
JS adapters behind a strict host API (query/click/type/read on the one chat tab; no cookies, no other tabs, no network) are the safest and simplest to sandbox and sign; WASM is an optional v2 sandboxing layer, not v1. CDP/Playwright is ruled out: it is headless-capable, invisible to the user, and makes the product itself an automation tool — precisely the grey zone the operator excludes. Minimal contract: `limits()` (context chars, rate, capabilities), `new_chat()`, `send(text)`, `await_answer(timeout) -> {text, truncated}`, `continue_thread(): bool`, `detect_block(): ok|captcha|ratelimit|logged_out`. `attach()` optional; text-only pack covers Gemini web, grok.com, and generic textarea sites.

## Q3 — Detection/abuse
Keep: human cadence, visible turns, per-adapter rate limits, no headless, zero CAPTCHA handling, hard stop on `detect_block()!=ok`. Add: concurrency 1 per site; exponential backoff with a low retry cap (no retry storms); a persistent status badge (xelth pattern) so the user always sees automation is live; session starts only on explicit user action; per-day message budget per adapter; never retry a `captcha` outcome automatically.

## Q4 — Reviewer quality
Per-adapter pack budget from `limits()` (free tiers: 8–16k chars), enforced by C3 with a `truncated` flag on the pack. Mark replies `engine=browser` + `adapter_id/version/site`, default weight lower in routed panels until usefulness ratings accumulate (same mechanism as existing marks). Prefer continuing the site's own conversation (stateful) — stateless re-send re-pays the pack every turn and burns free quota; adapters declare continuation support, C3 falls back to re-send with drift warning after N turns.

## Q5 — Telemetry/distribution
Fields: `adapter_id`, `adapter_version`, `site`, `outcome_class` (ok/captcha/ratelimit/logged_out/dom_churn/timeout), `pack_truncated`, plus existing engine/model/mark. Catalogue: signed JSON of {id, version, author, source_url, sha256, signature, usefulness aggregate}; the update channel delivers **hashes and pointers only** — the user fetches bytes from the author's repo, verifies hash, adapter lands disabled, enabled explicitly. /C3/ aggregates per adapter; bad adapters get delisted (pointer removed), never patched by the product.

## Q6 — Order of work / not-build
Order: (1) JS adapter contract + strict host API in a gemini-mcp-derived extension, with the WS token **required** (finding #3); (2) clipboard/manual mode as the no-extension fallback and contract test harness; (3) catalogue format + signing + hash-only updates; (4) telemetry fields + /C3/ table; (5) reference adapter outside the product. Do NOT build: CAPTCHA handling, cookie import, HTTP replay (already abandoned once — PROTOCOL.md), headless mode, multi-tab fan-out, WASM runtime before v1 proves the contract, PowerShell parity. Fix-after: per-day budgets, drift warnings.

---

### Findings

- **F08-1** [major] `ROADMAP.md:396` - The planned distribution path ('adapters are fetched and updated through the same telemetry/usefulness channel') makes the product host and push adapter code it did not author, contradicting the operator's hard boundary that the product ships only a neutral frame. Trigger: First adapter update pushed through the usefulness channel; the company is now distributing site-automation code. Evidence: read-code: 'adapters are fetched and updated through the same telemetry/usefulness channel (opt-in), with signatures'; read-code: Hard boundary: 'We ship no adapter... the company clearly outside the grey area'. Verify: Strike or reword the distribution clause to pointers+hashes and have the operator confirm the catalogue never serves adapter bytes. Remedy: Catalogue entries carry author source URL + SHA-256 + signature only; the client verifies the hash of user-fetched bytes; adapters land disabled.
- **F08-2** [major] `ROADMAP.md:389` - WASM adapters as the default runtime are over-engineering: WASM cannot access the DOM, so a JS host shim is the real security boundary regardless; JS adapters behind the same host API are equally signable and much easier to maintain through DOM churn. Trigger: First DOM-churn incident on gemini.google.com requiring an adapter debug/redeploy cycle in WASM toolchain. Evidence: read-code: 'Adapters are WASM modules run in the extension... strict host API: DOM query/click/type/read of the chat tab only'; read-code: Working production bridge is a JS content script; no WASM anywhere in the proven design. Verify: Confirm no WASM runtime exists in C3 today; estimate the shim that WASM would need and show it equals the JS host API surface. Remedy: v1: signed JS adapters behind the strict capability-scoped host API; keep WASM as an optional v2 sandbox layer.
- **F08-3** [major] `ROADMAP.md:387` - The inherited gemini-mcp relay defaults to no auth token (GEMINI_MCP_WS_TOKEN off by default); for a browser engine that pastes arbitrary text into the user's signed-in chat tab, any local process can drive exfiltration through the tab — a confused-deputy hole worth closing in the new engine even though gemini-mcp tolerated it. Trigger: Any untrusted local process connecting to ws://127.0.0.1:4455 and submitting text with mcp_task blocks or pack content. Evidence: read-code: Token 'off by default because the tool surface is whatever the user configured locally'; unauthenticated connections accepted with a warning; inferred: That guarantee only holds if the relay's client is the bridge, not any local process. Verify: Attempt an unauthenticated WS client against the lifted relay in the C3 engine and confirm whether it can inject text into the chat tab. Remedy: Require a per-install random token for the browser engine's relay (generated at setup, stored in user config), not optional.
- **F08-4** [minor] (no location) - A default stateless re-send conversation model for web reviewers re-pays the full pack every turn and burns small free-tier quotas; thread continuation should be the default where the adapter supports it. Trigger: A multi-turn diff-review consultation against grok.com free tier exhausting the daily question budget after a few exchanges. Evidence: assumed: No evidence gathered on grok/gemini continuation APIs; quota arithmetic inferred from free-tier limits. Verify: Measure pack size vs. grok.com free daily limit with one real multi-turn consultation using continuation vs. re-send. Remedy: Adapter contract includes continue_thread(); C3 prefers continuation and marks replies with a context-drift warning after N turns.

### Prior findings

_(none)_

## Verdict: ADVISE

The framing is sound and the boundary is correctly stated as a constraint, but the current ROADMAP shape contains three fixable defects (distribution wording, WASM-first choice, unauthenticated relay default) and omits several options worth deciding explicitly before build order is frozen.

### Blockers

_(none)_

### Unproven scenarios

- Actual DOM churn rate of gemini.google.com and grok.com (decides JS vs WASM maintenance cost and fuzzy-selector budget).
- Whether grok.com's terms permit automation or whether the xAI API makes a browser adapter unnecessary for grok.
- Whether C3 already contains a WASM runtime or it must be built (affects order-of-work step 2).
- Whether the operator's risk tolerance allows the catalogue to name sites at all, or only hashes/pointers.

### First-run checklist (observable)

_(none)_
