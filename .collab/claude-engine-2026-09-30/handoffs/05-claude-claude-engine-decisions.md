# The `claude` engine (R10, wave 29) - decisions after the design review (handoffs 02-04)

Reviews: 02 muse-spark (ADVISE, F02-1..5), 03 gpt-6-astra (ADVISE, F03-1..9), 04 gemini-3.1-pro-high (ADVISE,
F04-1..2). Panel of 3 at once, 347 s. The design in 01 stands where not overridden here.

Probes run by the coordinator after the review (2026-09-30, Claude Code 2.1.285, Windows, the smallest model;
scripts and outputs under the coordinator's scratch directory):

P1. A Read outside the working directories under `--restricted --permission-mode dontAsk`: the `tool_result`
    is an error text ("<path> is outside <working directory>..."), the turn goes on, the `result` event is
    `subtype: success`, `is_error: false`, and `permission_denials` lists the call (`tool_name`, `tool_use_id`,
    `tool_input`). No empty success.
P2. `--max-turns 2` is accepted (exit 0, `num_turns: 2`) although `--help` does not list it.
P3. The home directory's `CLAUDE.md` does not reach a restricted reviewer (asked for a name that only that
    file contains: "no"). With the repository files (01, obs) the answer to Q8 is complete: `--restricted`
    loads no instruction file.
P4. `modelUsage` of the result event has one key, the resolved model id of the turn.
P5. `claude auth status` exits 0 when signed in.
P6. A session killed with taskkill /T /F in the middle of a turn (49 stream lines written, a tool call open)
    resumes with `--resume <id>`: exit success, the same `session_id`, a usable structured reply.
P7. Two `claude -p` runs started together in one directory, beside the coordinator's own session and its
    subagents, both succeed with different session ids.

Decisions:

D1. The tree check is the strict one (F02-1, F03-1): a change of the working tree or the collab directory
    during a claude turn FAILS the run, as for agy. The init event proves the tools, not the absence of
    managed hooks; `WriteDisabled` stays `$false`. The ledger keeps `engine_run.init_tools` as evidence.
D2. The child environment is an ALLOW list, not a scrub list (F02-2, F03-2, F03-4, F03-5): the system
    variables a process needs (as for the telemetry sender of wave 28b/c), the proxy and trust variables,
    `CLAUDE_CONFIG_DIR`, and - only with `auth: api-key` - `ANTHROPIC_API_KEY`. Every other `ANTHROPIC_*` and
    every `CLAUDE_*` / `CLAUDE_CODE_*` variable is absent, so no inherited routing, effort, persistence or
    model override reaches a reviewer. `DISABLE_AUTOUPDATER=1` is set. `child_env_scrubbed` is replaced for this
    engine by `child_env_allowed` (names).
D3. The preflight runs in the SAME environment as a turn (F03-3): `Get-ClaudeSignIn` builds the child
    environment of D2 first. It reads the JSON before the exit code (F03-9): `loggedIn: false` -> out,
    whatever the exit code; `loggedIn: true` with the expected `authMethod` -> available; no JSON, a timeout
    or a missing launcher -> not checked.
D4. One resolved model per thread, proven per turn (F03-6, F02-3): the turn fails with class `capability` when
    the init model differs from the pinned id, or when `modelUsage` of the result names another model than the
    pinned one as the main model (a second key is recorded as `engine_run.other_models` and warned about, not
    failed, until it is known whether the CLI uses a helper model). The roster validator and the telemetry
    list use the SAME model table (the closed list of wave 28c): an alias resolves to its id through the init
    event; `[1m]` is stripped before every comparison.
D5. Concurrency (F02-4, F04-1): claude members of one panel run one at a time by default (the engine's
    parallel limit is 1; the roster's `parallel` may raise it); P7 shows two together work, which the README
    states as observed, not guaranteed.
D6. Denial, quota, resume (F02-5, F04-2): a denial is what P1 shows - a usable reply with `permission_denials`
    is usable with a warning that lists the tools and paths denied; success with no reply and denials is
    `DeniedEmpty`. Quota: a `result` with `is_error: true` or a `rate_limit_event` whose status rejects the
    request is class `quota`; the exact field names are read defensively (any `rate_limit_event` is recorded
    raw in `engine_run.rate_limit`), because the limit cannot be provoked in a test. The continuation after a
    timeout kill resumes the minted session id (P6); a resume that fails is an ordinary continuation failure.
D7. Health (F03-7): the health key of a claude reviewer is engine + auth mode + model family
    (`claude/subscription/opus`), not one bucket for the engine.
D8. `-MaxModelSteps` maps to `--max-turns` (F03-8, P2).
D9. The stdin upper bound (Q1) stays open: the adapter refuses a prompt over 1 MiB before the start
    (`brief too large for this engine`), which is far above any brief seen.
D10. Out of scope, stated in the README: routing through a gateway (`ANTHROPIC_BASE_URL`), Bedrock, Vertex and
     Foundry (D2 removes their variables, so such a setup fails closed at the preflight); calling the API
     directly instead of the CLI (F04: the roadmap's R10 is engines through the vendor's own CLI; the
     subscription login exists only there).
D11. Verification as in 01, plus: one panel with two claude members (D5 raised to 2) beside a codex member;
     one consultation with `-Mode resume`; one deliberately denied read (a brief that asks for a file outside
     the repository) showing the warning.
D12. Order: wave 29 starts from main AFTER wave 28c is merged (both touch the same files); its worker reads
     01, this file and the two fact files copied into this task (`facts/`).

Answered questions of 01: Q1 (stdin, 52 KB), Q2 (P1), Q8 (P3 and 01), Q9 (P5 and 01), Q11 (P6), Q12 (P7);
Q3, Q5, Q6, Q7, Q10 stay open and are decided defensively in D4 and D6.
