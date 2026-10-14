# 01 — Framing brief: a `browser` engine for the reviewer bridge (web-chat reviewers via the user's own Chrome tab)

**Context.** The bridge (this repo = the PowerShell plugin; `C:\Users\Dmytro\C3` = its Rust port with engines codex / agy /
muse / claude / http and a "reviewer pack" for models without repository tools) lets a coordinator consult reviewers
from different labs. Many labs answer only in the browser: for free (grok.com) or under a chat subscription the user
already has (Gemini web with a Pro plan → gemini-3.8-flash) but no API/CLI plan. The operator wants a `browser` engine:
the bridge drives a web chat UI through Chrome, so a roster can hold `browser :: gemini-web`, `browser :: grok`.

**Hard boundary set by the operator (read this first).** Automating a vendor's web chat sits in a grey zone of the
vendors' terms. Therefore the PRODUCT must stay a neutral frame: engine, adapter contract, sandbox, telemetry fields,
catalogue format, signing. SITE ADAPTERS (the DOM logic for a given site) are user-land: written, enabled and run by the
user in the user's own signed-in browser session. We ship no adapter for a site whose terms forbid automation; the
operator wants the company clearly outside the grey area. Please treat this as a design constraint, not as a question.

**Prior art (same author, reusable).** `C:\Users\Dmytro\gemini-mcp` (read `DESIGN.md` §"Transport: an in-tab extension
relay", §"WebSocket message contract", §"Security stance"; `PROTOCOL.md` explains why cookie/HTTP replay was abandoned):
a Chrome extension + local WebSocket relay that gives the Gemini web app MCP tools; no API key, no cookies, the signed-in
tab is the credential. `C:\Users\Dmytro\xelth.rs` README "Chrome Extension: DOM Heuristic Doctor" (retry loops, fuzzy
selectors, status badge). ROADMAP section "Browser engine" in this repo (just added) sketches the shape: C3 ↔ local WS ↔
extension ↔ adapter (WASM in the extension, contract `new_chat / send / await_answer / attach? / limits`), reviewer pack
as the only input (no repo tools), verbatim reply → the usual ledger/findings/ratings, telemetry fields
`adapter_id/version/site`, adapters rated and distributed through the usefulness channel with signatures (xelixir
"WASM shield" rule: user-installed, lands disabled, enabled explicitly).

**Questions (answer by number, ≤700 words, concrete):**
- Q1. Boundary design: what must the product NOT contain (code, defaults, docs, catalogue entries) so that it is plainly
  a neutral automation frame and the adapter author carries the site-terms responsibility? Precedents you know
  (browser extensions, userscript managers, OpenInterpreter-style tools, "bring your own session" products) and how they
  phrase it; what a catalogue may list (hashes? names? nothing?).
- Q2. Technical shape: WASM adapters inside the extension (host API = DOM read/click/type on the chat tab only) vs.
  JS adapters vs. a CDP/Playwright driver outside the browser. Which is safest for the user (no cookie/credential
  exposure, no cross-tab reach), most robust to DOM churn, and simplest to sandbox and sign? What is the minimal
  adapter contract that covers Gemini web, grok.com, and a generic "textarea + answer container" site?
- Q3. Detection/abuse: how to keep the engine on the right side — human cadence, user-visible turns, per-adapter rate
  limits, no headless mode, no CAPTCHA handling at all, hard stop on any anti-automation signal. What else?
- Q4. Reviewer quality: a web reviewer gets only the pack text (small free-tier contexts). Pack budget per adapter, how
  the bridge should mark these replies (lower default weight in a routed panel until ratings prove them), and whether
  threads can be continued (the site's own conversation vs. stateless re-send).
- Q5. Telemetry/distribution: which fields per consultation (adapter id/version, site, outcome class) and what the
  catalogue + signing + opt-in update channel should look like so that adapters are rated in the field and bad ones
  are retired — without the product hosting adapter code it did not author (pointers/hashes only?).
- Q6. Order of work and what you would NOT build. Blockers vs. fix-after.
