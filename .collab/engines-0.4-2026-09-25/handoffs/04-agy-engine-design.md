# Handoff 04 - Gemini (gemini-3.1-pro-high through agy, direct; the engine of R10 does not exist yet): engine-design

Consultation id: 78f0fe62-6999-43d6-bd2f-db4e92be1686. Conversation: fdc21ce2-3e1c-480b-a3a6-3d978e61cc55. Wall: 194 s. Usage: {"input_tokens":53694,"output_tokens":12304,"thinking_tokens":8693,"cache_read_tokens":34002,"total_tokens":65998}. Verdict: ADVISE - The design correctly integrates agy but has critical flaws in error handling (F11/soft-denials) and hook performance.

# Review of agy engine design (ROADMAP R10)

**Q1.** stdin stream-json vs argv: Argv is immune to complex NDJSON quoting on stdin and buffer flushes. A risk of the stream path (D2) is that `agy` might bypass the schema validation for stream mode or expect specific EOF signals, resulting in a missing `structured_output` event.

**Q2.** Effort: D2's "record requested, send nothing" is correct because `agy` ties the reasoning tier strictly to the model ID (F5). Mapping effort dynamically would break the invariant that a thread belongs to one reviewer (model ID). The roster's `weighty` panel flag routes correctly if the roster uses the `-high` model ID.

**Q3.** Resume mismatch: Failing closed (D4) is correct. Ingesting the reply as a new conversation hides the fact that the model answered without the requested parent context, leading to hallucinations.

**Q4.** Default mode `resume`: `new` is a much better default. Defaulting to `resume` would cause the conversation to grow with every unrelated consultation, leading to context window exhaustion and severe topic drift. The cost to the judge of `new` is explicitly passing `-Mode resume` when continuity is truly needed.

**Q5.** Credential check: A 2s network call in the preflight is acceptable, but doing it in the hook (D9) is a blocker because it degrades the shell's listing performance. Local evidence (e.g., checking Windows Credential Manager or local tokens) should be used instead.

**Q6.** Failure classification: 
- **Quota**: `RESOURCE_EXHAUSTED`, `quota`, `429`
- **Auth**: `PERMISSION_DENIED`, `UNAUTHENTICATED`, `not signed in`
- **Capability/Permission**: `jetski: no output produced` (F11), `invalid model selection`
- **Retry**: `Get-RetryAfter` must parse `retry in X{s,m,h}`.

**Q7.** Verification: The proposed conditions (exit 0 + SUCCESS + `structured_output` + UUID) are insufficient. Stderr notices like "soft-denial" (F8), "partial output" (F7), or "jetski: no output produced" (F11) must FAIL the run, because they indicate the model was blocked and failed to complete the task.

**Q8.** Handoff naming: Changing the prefix to `NN-agy-<slug>` and the command to `agy ` (D3/D8) risks breaking `-Stats`, `-List`, and scoreboard parsers that hardcode `codex` in regexes.

**Q9.** Tests: I would add the F11 soft-denial case first. To test quoting in a Windows shim, I would avoid `.cmd` entirely and use a `fake-agy.ps1` called directly, or a minimal script to dump `sys.argv`.

**Q10.** D3 breaks Invariant 4 ("exit 0 only when every member produced a usable reply"). D3 treats a soft-denial (F8) as a mere warning. However, per F11, a soft-denial ends the run with SUCCESS but an empty response. If D3 warns instead of failing, the bridge accepts a blank reply, breaking the invariant.

### Fact F11 (The Denied Tool Call)
When a tool is auto-denied (F11), `agy` prints `jetski: no output produced` to stderr and returns SUCCESS with an empty response. The bridge must classify this as a `capability` or `permission` failure. ONE repair turn on the same conversation is exactly the right remedy: it preserves the context while appending a system prompt to answer without using the denied tool.

## Findings (5)
- **#1 blocker** D3 treats soft-denial as a warning, which breaks invariant 4 when F11 occurs. Trigger: agy prints 'jetski: no output produced' on soft-denial Remedy: Fail the run if stderr contains soft-denial notices. Verification: Check bridge output when agy stderr contains jetski: no output produced. [.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:78]
- **#2 major** Hook script degrades shell performance due to network call. Trigger: codex-providers.ps1 runs `agy models` Remedy: Check local credentials (e.g. Windows Credential Manager) instead of network. Verification: Time the shell startup with the new hook. [.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:109]
- **#3 major** Default mode 'resume' leads to context exhaustion. Trigger: Bridge invokes agy without -Mode new Remedy: Make 'new' the default mode. Verification: Run multiple consultations and check conversation growth. [.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:83]
- **#4 major** Stats/Scoreboard parsers may fail on new naming scheme. Trigger: Handoff files are named NN-agy-<slug> Remedy: Update regexes to match `(codex|agy)` instead of just `codex`. Verification: Run scoreboard generation with an agy engine. [.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:107]
- **#5 minor** cmd shim cannot reliably test quoting. Trigger: test suite runs FAKE_AGY_* Remedy: Use a powershell or python shim. Verification: Run test suite with complex prompt. [.collab/engines-0.4-2026-09-25/handoffs/01-claude-engine-agy-design.md:114]

## Unproven
- Scoreboard parser breakage (needs verify of parser code)
