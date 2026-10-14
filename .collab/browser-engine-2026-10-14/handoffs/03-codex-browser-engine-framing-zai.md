# Handoff 03 - Codex: browser-engine-framing-zai

Date: 2026-10-14 14:56 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 2 of 10, panel 34c8b9a5 member 2 of 10.
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: d2c697e0-05f4-4b53-ad7b-9f2b99c4871a.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -c features.multi_agent=false -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-61a0dbdc158546a3973d70180dac8ff5.md --output-schema C:\Users\Dmytro\.claude\plugins\cache\claude-codex-consult\codex-consult\0.6.1\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a13a7c-333f-7061-8d71-714bb10168fc` (source: events).
Brief: `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` (sha256 19fb466d7f96). Reviewed: 49dde0c, base 49dde0cc2b7f0ba2e40fa90c0c60536ca7965b30, tree sha256 99269e8342cd, 0 changed files.
Bridge outcome: usable reply. Wall time: 441.1 s. Tokens: in 1085225 (cached 945728), out 9530, reasoning 4858.
Quota (rollout): no window in the rollout; this run 1085225 input tokens (945728 cached) in 6 calls, max 789113 per call of 996147; sub-agents 0; sub-agents off (features.multi_agent=false); budget 15 % of the 5-hour window.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - This is a framing consultation, not an acceptance or diff review. Findings: 0 blocker, 4 major, 1 minor, 0 note (F03-1..F03-5, tracked in `findings.json`). Structured reply: `handoffs/03-codex-browser-engine-framing-zai.reply.json`.
Raw event stream: `handoffs/03-codex-browser-engine-framing-zai.events.jsonl`.
Verbatim reply follows.

---

## Framing challenge
The brief omits three safer shapes: (1) **draft-only assist**: the extension fills the prompt and the human clicks Send; (2) **declarative adapters**: signed selector/accessibility mappings rather than executable modules; and (3) **Chrome Native Messaging** instead of a listening loopback WebSocket. The framing also assumes field ratings make web reviewers acceptable before any evidence exists.

To choose, I need: the operator's legal-risk tolerance and publication surface; target-site terms and account-suspension tolerance; the adapter threat model; whether Chrome Web Store or unpacked distribution is required; actual free-tier context, thread, and attachment behavior; and whether one-click or draft-only send is acceptable.

### Q1 — Boundary
Do not ship site URLs, selectors, DOM traces, screenshots, fixtures, model aliases, default roster entries, auto-discovery, installers, reverse-engineered endpoints, cookie/session access, headless/CDP paths, CAPTCHA handling, or vendor-targeted marketing. The neutral frame should say: it provides a capability-bounded bridge; adapters are third-party user-installed software; enabling one asserts the user's authority and compliance with the site.

Userscript managers such as [Tampermonkey](https://www.tampermonkey.net/) are useful precedents as neutral script managers, but that posture is not immunity. Chrome policy regulates the whole extension experience, including marketing and user safety ([Chrome Web Store policies](https://developer.chrome.com/docs/webstore/program-policies)). Open Interpreter is a weaker precedent: it is intentionally a local execution agent, not a narrow third-party-session adapter.

Initially use only a **local catalogue**: opaque adapter id, version, artifact digest, manifest digest, publisher key fingerprint, compatibility, capabilities, and aggregate status—no target domain, URL, or automatic fetch. Publish usefulness metrics separately; let users import a publisher's URL and hash manually.

### Q2 — Technical shape
Use an extension selected-tab capability host plus Native Messaging to C3; Chrome explicitly supports extension/native-host communication over stdio with an extension-allowlist ([Native Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)). Put each adapter in a WASM Web Worker or sandboxed page with no Chrome APIs. WASM must be explicitly enabled by the extension CSP, and the host must mediate every capability ([Chrome extension CSP](https://developer.chrome.com/docs/extensions/reference/manifest/content-security-policy)). Pin the user-selected tab and origin; allow only bounded DOM query/read/type/click/wait and explicitly approved attachment bytes.

JS in an isolated Worker is simpler and debuggable, but still needs the same host mediation; unrestricted extension JS is unsafe. CDP/Playwright outside the browser is worst for this use: broad cross-tab control, debugging-port risk, persistent-profile exposure, and invisible automation. WASM does not itself fix DOM churn: use roles/labels, bounded MutationObserver waits, stale-version detection, and signed updates.

Minimal contract: `manifest()`, `new_chat()`, `send_turn(text, attachments?, consent_id)`, `await_turn() -> {answer, stopped, outcome}`, `cancel()`, `dispose()`, and `limits()`.

### Q3 — Detection/abuse
Require per-turn visible consent or draft-only mode; one active tab and concurrency 1; fixed conservative rate floors and per-adapter/account budgets; global kill switch; no background tab creation, reloading, retry loops, jitter designed to mimic humans, headless mode, stealth flags, CAPTCHA handling, or retry after an anti-automation signal. Quarantine the adapter, record only an outcome class, and require explicit re-enable. Redact the pack and show exactly what will leave the machine.

### Q4 — Reviewer quality
Start at **6,000 input tokens / 1,500 output tokens** for unknown adapters; signed adapter limits may lower it. Pack priority: question and schema, invariants, brief, minimal focus/periphery; drop changelogs first. Mark replies `browser/provisional`, weight 0.5, and prohibit them from supplying a deciding panel quorum until, for example, ten rated consultations show adequate precision without unsafe findings. Use one fresh stateless chat per consultation first. Thread continuation is fix-after only: opt-in, conversation-scoped, explicitly marked, and never reused across sites or accounts.

### Q5 — Telemetry and distribution
Send `engine=browser`, provider/model if adapter-declared, adapter id/version/digest, capability set, outcome class, duration bucket, timeout, retries, thread mode, schema success, and usefulness mark. Do not send prompt, DOM text, account identifiers, vendor conversation ids, or raw errors. Prefer hashed origin over plaintext `site`, and make that field explicit opt-in.

The product should not host, proxy, recommend, fetch, or auto-update third-party adapter binaries. Publish signed metadata and ratings; users import the publisher URL plus digest. Updates land disabled, show a capability diff, and require signature verification and explicit enable. Retirement should be a signed status change, not remote code removal.

### Q6 — Order
Blockers: legal-boundary review; neutral naming/docs; selected-tab + Native Messaging architecture; WASM host sandbox; consent and hard-stop UX; local manifest/signature format; generic mock-adapter tests; provisional routing and telemetry allowlist.

Then: out-of-repo reference adapter, metrics, thread experiment, attachment support, and PowerShell parity only if host invariance demands it.

Do not build: CDP/Playwright, bundled or named-site adapters, cookie replay, CAPTCHA workarounds, stealth/headless behavior, background self-healing tabs, automatic catalogue installation, or autonomous multi-turn panels.

---

### Findings

- **F03-1** [major] `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md:5`, `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md:7`, `ROADMAP.md:373`, `ROADMAP.md:380` - Product-facing documents already name Gemini and grok.com as intended automation targets while asserting a neutral, adapter-only boundary, which weakens the intended separation before any adapter exists. Trigger: Publishing or distributing the roadmap and brief as product documentation for the browser engine. Evidence: read-code: The brief names the target sites and desired roster entries before defining the neutral frame.; read-code: The roadmap records the same vendor-specific ask directly under the product browser-engine direction. Verify: Have counsel or the operator review the roadmap as published product communication and identify vendor-specific facilitation exposure. Remedy: Keep product documentation generic; discuss concrete vendors only in a non-shipped legal/risk record. Use neutral examples and a local fixture adapter.
- **F03-2** [major] `ROADMAP.md:382`, `ROADMAP.md:390` - Reusing gemini-mcp as the stated prior art would violate the proposed one-visible-chat-tab constraint if its extension permissions and watchdog behavior are copied unchanged. Trigger: Porting the prior extension manifest/background behavior into the C3 browser engine. Evidence: read-code: It requests tabs, alarms, storage, and debugger permissions.; read-code: Its watchdog can create a background pinned tab and query/reload matching tabs. Verify: Compare any new extension manifest and watchdog against the prior art for tabs, debugger, host permissions, tab creation, and reload operations. Remedy: Use a user-selected pinned tab, no tabs or debugger permission, no automatic creation/reload, and Native Messaging from the extension to C3.
- **F03-3** [major] `ROADMAP.md:376`, `ROADMAP.md:391` - The sketched catalogue/fetch/update/usefulness channel can turn the product into a distributor or curator of third-party automation code despite the stated boundary. Trigger: The product publishes signed adapter entries or downloads/updates an adapter artifact, even when the code is authored elsewhere. Evidence: read-code: The roadmap says adapters are signed, listed in a catalogue, rated, fetched, and updated through the same channel.; inferred: Facilitating retrieval and automatic promotion of site adapters is materially different from documenting a local manifest format. Verify: Trace one adapter install/update from catalogue lookup through artifact acquisition and identify every party hosting, selecting, signing, and vouching for the artifact. Remedy: Ship only a local import format plus public opaque metrics; require the user manually to supply a publisher URL and digest, with no product-side recommendation or fetch.
- **F03-4** [major] `ROADMAP.md:389`, `ROADMAP.md:391` - The roadmap treats WASM as the sandbox without specifying the capability mediation needed to prevent prompt exfiltration, wrong-origin actions, resource exhaustion, or Chrome API escape. Trigger: A signed but malicious or compromised adapter runs with a broad DOM query/click/type API on an incorrectly pinned tab. Evidence: read-code: It specifies WASM and a strict host API but not worker isolation, origin pinning, operation quotas, attachment mediation, or CSP.; ran-command: Chrome disables WebAssembly under the default extension-pages CSP; using it requires an explicit policy and still depends on the host API. Verify: Attempt exfiltration and cross-tab actions from the reference adapter's WASM and inspect whether every operation is denied outside the selected origin and approved turn. Remedy: Run adapters in an isolated worker/sandbox with no extension APIs; expose only audited, quota-limited operations on a pinned selected tab and explicit user consent.
- **F03-5** [minor] `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md:21`, `ROADMAP.md:392` - Adding plaintext site telemetry creates a re-identification and sensitive-browsing-history risk not justified by usefulness aggregation. Trigger: A user runs adapters for uncommon or private sites and the existing default-on telemetry path sends the origin. Evidence: read-code: The proposed telemetry fields include adapter_id, version, and site.; inferred: Adapter identity is usually sufficient for aggregate quality; a site origin can reveal personal tool use. Verify: Review the emitted event in a network capture for uncommon adapter origins and test whether omitting or hashing site changes any required aggregate. Remedy: Use adapter id/version/digest by default; send only a salted or truncated origin hash under explicit opt-in if field diagnostics require it.

### Prior findings

_(none)_

## Verdict: ADVISE

This is a framing consultation, not an acceptance or diff review.

### Blockers

_(none)_

### Unproven scenarios

- The legal effect of neutral-frame versus catalogue-facilitated distribution has not been reviewed by counsel.
- The actual Gemini and grok context limits, thread semantics, attachment behavior, and anti-automation signals are unknown.
- The selected Native Messaging plus WASM-worker design has not been implemented or penetration-tested.

### First-run checklist (observable)

_(none)_
