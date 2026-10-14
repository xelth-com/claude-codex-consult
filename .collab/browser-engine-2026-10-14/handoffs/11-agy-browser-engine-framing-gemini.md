# Handoff 11 - Gemini (agy): browser-engine-framing-gemini

Date: 2026-10-14 15:09 local. Author: Gemini (agy) (model gemini-3.8-flash-high, effort tier in the model id), agy-cli (version unknown).
Reviewer: gemini :: gemini-3.8-flash-high [agy] (provider from -Provider, model from -Model; engine agy (C:\Users\Dmytro\AppData\Local\Microsoft\WinGet\Packages\Google.AntigravityCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\agy.exe); provider fingerprint a612ba12e63e; harness agy-cli (version unknown)).
Preflight: ok: signed in (6 models).
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - entry 4 of 10 for -Provider gemini (engine applied).
Effort: nothing sent (requested high, mapping model-tier, by caps-v1: engine agy, the tier is part of the model id; not confirmed by the provider). Consultation id: 3026814c-ff7c-4dec-b524-8a230e07c9bd.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; enforced by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; agy --sandbox restricts the terminal only), purpose: framing). Argv: `agy -p= --input-format stream-json --output-format stream-json --model gemini-3.8-flash-high --json-schema C:\Users\Dmytro\.claude\plugins\cache\claude-codex-consult\codex-consult\0.6.1\schemas\consult-reply.schema.json --print-timeout 0 --sandbox --disable-slash-commands` (prompt on stdin as one NDJSON line).
Parent thread: (none - new thread; no thread of lineage gemini :: gemini-3.8-flash-high [agy] in this task's ledger; other lineage(s): mimo :: mimo-v2.6-pro, kimi :: k3, byteplus :: dola-seed-2.0-pro, byteplus :: deepseek-v4.1-flash, openai :: gpt-6-astra, ZAI :: glm-5.3, alibaba :: qwen3.8-max). Result thread: `ff93fd51-1f14-4401-9e7c-2fa510e36b82` (source: events).
Brief: `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` (sha256 19fb466d7f96). Reviewed: 9422a76, base 9422a76baddb76f0d5321bdd0577a7c0d3fc73c3, tree sha256 b77ed2f27101, 0 changed files.
Bridge outcome: usable reply. Wall time: 364.5 s. Tokens: in 76186 (cached 762395), out 21866, reasoning 18261.
Engine turns: 1.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The browser engine framing requires narrowing to user-sandboxed JS adapters with token-authenticated local transports, removing vendor-specific references, and relying on thread continuation to preserve free-tier quotas. Findings: none. Structured reply: `handoffs/11-agy-browser-engine-framing-gemini.reply.json`.
Raw event stream: `handoffs/11-agy-browser-engine-framing-gemini.events.jsonl`.
Verbatim reply follows.

---

### Framing Review: Browser Engine Architecture

#### Framing Challenge & Unlisted Options
The brief frames the choice around extension WASM vs. extension JS vs. external CDP drivers. However, this misses essential architectural choices and premises:
1. **Unlisted Option A (Isolated Browser Profile):** Driving the user's everyday interactive session risks keystroke collisions, tab theft, and cross-origin prompt injection via local sockets. Running an isolated automation Chrome profile with persistent sessions cleanly separates personal browsing from review automation.
2. **Unlisted Option B (Userscript Engines / Declarative Selectors):** Leveraging existing userscript engines (Tampermonkey/Violentmonkey) or declarative JSON selector schemas eliminates custom extension maintenance and dynamic code-loading hazards.
3. **Unlisted Option C (No Browser Engine / CLI Prioritization):** Gemini web is already accessible through the `agy` CLI on the same Google subscription (F05-9). If grok.com free tier is the sole unique target, building an entire multi-process browser pipeline for low-context, high-churn free quotas is economically questionable.

**Decision Prerequisites:** Choosing between these requires knowing: (1) target model inventory (are any critical models genuinely browser-only?); (2) distribution channel (Chrome Web Store bans dynamic WASM/code loading under MV3 remotely hosted code rules; sideloading limits adoption); (3) operator legal risk tolerance regarding publishing adapter catalogues.

---

#### Q1. Boundary Design
- **Exclusions:** The product must contain zero site-specific selectors, domain regexes, vendor names (`gemini`, `grok`), or pre-installed adapters in code, docs, or test fixtures.
- **Precedents:** Follow Userscript managers (Tampermonkey/Violentmonkey) and local LLM clients (OpenInterpreter): ship exclusively the generic execution engine. Terms of service compliance is explicitly assigned to user-authored scripts.
- **Catalogue:** The product must not distribute adapter code. A catalogue should publish only capability manifests, author signing keys, and SHA-256 hashes of user-hosted scripts.

#### Q2. Technical Shape & Adapter Contract
- **Shape:** Sandboxed JS adapters in an isolated extension world are superior to WASM (WASM cannot touch the DOM without an equivalent JS shim, adds toolchain friction during DOM churn, and triggers MV3 store bans). External CDP/Playwright requires `--remote-debugging-port`, exposing all browser tabs and cookies to local processes.
- **Minimal Contract:**
  - `init(tabId) -> {ok, status: ready|need_auth|captcha}`
  - `new_chat() -> {ok, thread_id}`
  - `send(text) -> {ok}`
  - `poll_answer() -> {state: streaming|done|refused|error, text, error_class?}`
  - `abort()`
  *(Drop `attach(file)`: unneeded exfiltration risk per F05-5. Add error classification per F05-3).*

#### Q3. Detection & Abuse Mitigation
- Enforce human typing cadence (50–150ms randomized jitter) and visible foreground tab execution (no headless mode).
- Impose strict per-adapter turn rate limits and daily caps.
- Hard stop on anti-automation signals: immediate abort on Cloudflare Turnstile, reCAPTCHA, or interstitial gates. Never attempt evasion or automated bypass.

#### Q4. Reviewer Quality & Conversation Model
- **Budget:** Strict per-adapter input budget (e.g. 2,000–4,000 words); bridge trims periphery to prevent web chat truncation.
- **Routing:** New browser adapters must enter as `panel: "light"` with reduced prior weight (0.5) until proven by `-Rate`.
- **Continuations:** Thread continuation must be the default (`new_chat` initially, then append turns). Stateless re-sending consumes entire packs every turn, rapidly exhausting free-tier quotas (F08-4).

#### Q5. Telemetry & Distribution
- **Telemetry:** Spool `adapter_hash` (SHA-256), `adapter_version`, `status_class` (`ok|dom_drift|quota|auth`), `turn_count`, `wall_seconds`. Hash or omit site domains to eliminate browsing history re-identification (F03-5).
- **Distribution:** Pointers, public keys, and content hashes only—never hosting code bytes (F08-1). Implement the xelixir shield rule: adapters land disabled and require explicit user enablement. Aggregate failure rates retire broken versions.

#### Q6. Order of Work & What NOT to Build
- **Do NOT Build:** Central adapter hosting; dynamic WASM runners; `attach(file)` verbs; CAPTCHA solvers; unauthenticated loopback WS relays (must require token auth per F05-2/F08-3).
- **Order:**
  1. *Blocker:* Token-authenticated WebSocket relay and tab-pinned extension bridge.
  2. *Blocker:* Closed engine vocabulary extension across C3 and PowerShell (`browser` engine per F05-4).
  3. *Blocker:* Adapter contract with failure classification and completion polling.
  4. *Fix-after:* Hashed telemetry aggregation, catalogue verification, and external reference adapter repo.

---

### Findings

_(none)_

### Prior findings

- F03-1 - still-open - Roadmap and brief still explicitly name Gemini and grok.com as automation targets.
- F03-2 - still-open - Reusing gemini-mcp watchdog and extension permissions without audit remains in roadmap.
- F03-3 - still-open - Roadmap still describes distributing and updating adapters via usefulness channel.
- F03-4 - still-open - WASM sandbox capability mediation and origin pinning remain unspecified.
- F03-5 - still-open - Plaintext site telemetry proposal in brief and roadmap remains unchanged.
- F05-1 - still-open - Remotely hosted code update channel in MV3 extension remains in proposal.
- F05-2 - still-open - Unauthenticated loopback WebSocket relay from gemini-mcp remains in framing.
- F05-3 - still-open - 5-verb adapter contract still lacks failure classification and completion boundary.
- F05-4 - still-open - Closed engine vocabulary in C3 and PowerShell plugin still unaddressed.
- F05-5 - still-open - attach(file) verb remains in contract without clear reviewer use case.
- F05-6 - still-open - Format repair turn costs on web chat free tiers remain unaddressed.
- F05-7 - still-open - Per-adapter pack token budget enforcement mechanism still absent.
- F05-8 - still-open - Telemetry fields lack outcome class, version compound key, and repair flags.
- F05-9 - still-open - Gemini web justification still overlaps with existing agy CLI engine.
- F07-1 - still-open - Content-addressable storage or IPFS for adapter distribution remains unconsidered.
- F07-2 - still-open - WASM memory limits and gas metering remain unspecified in framing.
- F07-3 - still-open - CONTRIBUTING.md policy against site-adapter PRs is still missing.
- F07-4 - still-open - Adapter manifest format remains unspecified in framing.
- F08-1 - still-open - Roadmap distribution clause still specifies fetching/updating adapter code.
- F08-2 - still-open - WASM complexity over JS host shim boundary remains unaddressed in roadmap.
- F08-3 - still-open - Confused-deputy exposure on unauthenticated local WebSocket relay remains open.
- F08-4 - still-open - Conversation model still defaults to stateless re-send rather than continuation.

## Verdict: ADVISE

The browser engine framing requires narrowing to user-sandboxed JS adapters with token-authenticated local transports, removing vendor-specific references, and relying on thread continuation to preserve free-tier quotas.

### Blockers

_(none)_

### Unproven scenarios

_(none)_

### First-run checklist (observable)

_(none)_
