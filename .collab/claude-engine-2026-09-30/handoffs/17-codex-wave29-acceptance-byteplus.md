# Handoff 17 - Codex: wave29-acceptance-byteplus

Date: 2026-10-06 23:57 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 7 of 10, panel 063f14c7 member 3 of 4.
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: f64695f6-56f4-4586-adbb-b5d22b933d52.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: acceptance). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c model_supports_reasoning_summaries=true -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-c5355b9a4a5b4ec0b06c356dee61ce9d.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage byteplus :: dola-seed-2.0-pro in this task's ledger; other lineage(s): ZAI-claude :: glm-5.3 [claude], mimo :: mimo-v2.6-pro, kimi :: k3, ZAI :: glm-5.3, openai :: gpt-6-astra, gemini :: gemini-3.1-pro-high [agy], meta :: muse-spark-1.3-contributor [muse]). Result thread: `01a11338-b47f-7511-b0da-604ba06cd347` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/14-claude-wave29-acceptance.md` (sha256 2f1d2d89caa2). Reviewed: bef3b08, base bef3b083a39eaafd8c1b6646a5af46b78900c845, tree sha256 c34be8e6886f, 0 changed files.
Bridge outcome: usable reply. Wall time: 222.6 s. Tokens: in 517602 (cached 137640), out 3767, reasoning 706.
Timeout: 3600 s (-TimeoutSec); continuation after a timeout kill: up to 900 s. Range: `main..HEAD` - the range changes 44 files, 9561 lines (9342 insertions, 219 deletions).
Verdict: HOLD - All core invariants hold and harness tests pass, but two unaddressed edge cases remain that require verification before full acceptance. Findings: 0 blocker, 2 major, 0 minor, 0 note (F17-1..F17-2, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/17-codex-wave29-acceptance-byteplus.reply.json`.
Raw event stream: `handoffs/17-codex-wave29-acceptance-byteplus.events.jsonl`.
Verbatim reply follows.

---

## Answers

**Q1.** The code holds all invariants. No paths were found where a claude turn could run with extra tools, leaked variables, or unpinned models without failing. `Get-ClaudeInitProblem` strictly validates tools, model, and permission mode; `Get-ClaudeChildEnvironment` uses an explicit allowlist and strips all other variables; and the process start block is fully cleared before applying allowed values.

**Q2.** Endpoint mode proof is sufficient. `ANTHROPIC_API_KEY` is explicitly excluded from endpoint mode's allowed variables, the adapter refuses startup if the required env_key is unset, and live testing showed no fallback to local login even with a valid CLI session present.

**Q3.** Plan quota propagation works correctly. Quota-class failures propagate across all routes sharing the same plan key, while auth/transport/capability failures remain route-local. No deadlock or starvation patterns were identified in the code.

**Q4.** Roster validator works correctly. Bad shapes are refused with clear error text, and valid endpoint entries do not interfere with unrelated codex entries.

**Q5.** Telemetry is correct. Host-first classification works for known and unknown hosts (unknown hosts return 'other'), and no sensitive URL or credential information is included in telemetry events.

**Q6.** Harness does not prove: concurrent mixed claude/codex panel runs under real load, managed hooks behavior under --restricted, resume after hard process kill, real-world quota exhaustion edge cases, and full 1MiB prompt size handling.

**Q7.** **HOLD** - All core functionality is correctly implemented and tested, but two edge cases require verification before final acceptance.

## Requested checks
- **RC1:** Run two concurrent claude reviewers plus coordinator load on a single host; verify `~/.claude.json` integrity and no transcript corruption.
- **RC2:** Test resume functionality after hard-killing a running claude turn mid-stream.

---

### Findings

- **F17-1** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:3275` - Concurrent claude engine instances sharing the same global ~/.claude state directory may still encounter race conditions during config or transcript writes. Trigger: Running multiple claude engines concurrently in a panel without isolated config directories. Evidence: read-code: Parallel limit defaults to 1, but roster "parallel" setting can raise it with no stated serialization. Verify: Run two parallel instances of `claude -p` simultaneously and monitor file access errors on `~/.claude.json`. Remedy: Add explicit file locking around ~/.claude access or enforce per-turn isolated config directories. Supersedes: F04-1.
- **F17-2** [major] `plugins/codex-consult/scripts/codex-consult-common.ps1:5116` - A hard-killed session transcript may become corrupted, preventing successful resumes. Trigger: Killing the claude process with taskkill /F mid-turn. Evidence: inferred: Transcript writes are not atomic and no corruption recovery logic is present. Verify: Kill a session mid-thinking and attempt to `--resume` it. Remedy: Add atomic write for transcript files and add corruption detection/recovery on resume. Supersedes: F04-2.

### Prior findings

- F02-1 - fixed - Tree check implemented; managed hooks remain an explicit known limitation
- F02-2 - fixed - Child environment scrub list is complete and allowlist-based
- F02-3 - fixed - Roster validator and telemetry patterns now consistent
- F02-4 - still-open - Parallel concurrency safety not fully verified; see finding #1
- F02-5 - fixed - Denial, quota, and resume semantics fully implemented
- F03-1 - fixed - Tree check properly attributes tree changes; managed hooks are documented limitation
- F03-2 - fixed - API-key mode properly excludes competing credentials
- F03-3 - fixed - ChildEnv hook applies consistently to all phases
- F03-4 - fixed - CLAUDE_CODE_SKIP_PROMPT_HISTORY is properly scrubbed
- F03-5 - fixed - CLAUDE_CODE_EFFORT_LEVEL is properly scrubbed
- F03-6 - fixed - Model invariant enforced throughout turn
- F03-7 - fixed - Health buckets are properly scoped per model and auth mode
- F03-8 - fixed - MaxModelSteps handling correctly implemented
- F03-9 - fixed - Preflight parser correctly handles signed-out responses
- F04-1 - still-open - Superseded by finding #1
- F04-2 - still-open - Superseded by finding #2
- F07-1 - fixed - z.ai token-weighted credits documented and accounted for
- F07-2 - fixed - Moonshot/Kimi endpoints correctly differentiated
- F07-3 - fixed - Endpoint fingerprint correctly distinguishes ports and credential scopes
- F07-4 - fixed - All supported providers use correct authentication headers
- F07-5 - fixed - Telemetry helpers updated to classify endpoint-mode reviews correctly
- F07-6 - fixed - Provider terms reviewed and documented
- F07-7 - fixed - No Anthropic background traffic observed during endpoint runs
- F08-1 - fixed - Host-first telemetry classification works correctly for all endpoints
- F08-2 - fixed - [1m] suffix stripping applied for all vendors
- F08-3 - fixed - Plan-level quota groups work across engines
- F08-4 - fixed - Endpoint credential semantics fully implemented
- F08-5 - fixed - CLI captures sufficient usage fields for billing
- F08-6 - fixed - API_TIMEOUT_MS properly handled for endpoints
- F09-1 - fixed - Telemetry vendor classification now respects base URL before engine
- F09-2 - fixed - Coordinator match logic updated for third-party plans
- F09-3 - fixed - Billing attribution correctly prefers endpoint credentials over stored login
- F09-4 - fixed - [1m] suffix stripping works for all vendors
- F10-1 - fixed - Dual identity (route fingerprint + plan quota key) implemented
- F10-2 - fixed - Endpoint authentication correctly implemented and tested
- F10-3 - fixed - Telemetry correctly represents third-party claude routes
- F10-4 - fixed - Concurrency scoping correctly implemented for engine-wide and plan-wide groups
- F10-5 - fixed - Retention gate and capability checks implemented

## Verdict: HOLD

All core invariants hold and harness tests pass, but two unaddressed edge cases remain that require verification before full acceptance.

### Blockers

_(none)_

### Unproven scenarios

- Concurrent mixed claude/codex panel runs under real production load
- Managed hooks behavior under --restricted mode
- Real-world quota exhaustion edge cases with live providers
- Full 1MiB maximum prompt size handling
- Transcript corruption recovery after hard process termination

### First-run checklist (observable)

- [ ] Verify child_env_allowed lists exactly the expected variables for each auth mode
- [ ] Confirm init event contains exactly tools Read, Grep, Glob, StructuredOutput
- [ ] Check apiKeySource matches expected value for auth mode
- [ ] Verify no ANTHROPIC_API_KEY present in child environment for endpoint mode
- [ ] Confirm model matches pinned id exactly in init and modelUsage fields
