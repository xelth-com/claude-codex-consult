# The `claude` engine - decisions after the acceptance round (handoffs 14-20)

Acceptance panel on handoff 14 (2026-10-06/07): 16 kimi HOLD, 17 dola-seed HOLD, 18 muse HOLD (astra out on the
ChatGPT limit twice, 15 and 19); their common blocker closed by E11 (d8fecd2). Then 20 gpt-6-astra alone on the
same brief after E11: HOLD - two blockers and two majors in the turn-outcome logic of the engine core (wave 29),
plus F10-4 still open. The coordinator is the judge; D1-D12 (05), E1-E11 (12 and the E11 commit) stand where not
amended here.

Decisions:

E12. **A killed turn's init is judged too** (20 #1 = F20-1). `Get-ClaudeInitProblem` runs on the events of EVERY
     turn, including a turn killed on its timeout or stall: a capability or permission problem of that init
     (an extra tool, an MCP server, a wrong permission mode, a wrong model, a wrong apiKeySource) FAILS the
     consultation with that class, and NO continuation turn is attempted - a continuation would resume a
     session that ran with prohibited tools. The salvage (`.partial.md`) is still kept. The summary names the
     init problem, not the timeout, as the reason.
E13. **The assistant messages prove the model, not the largest-output heuristic** (20 #2 = F20-2; reopens F18-2).
     Every `assistant` event's `message.model` of a turn must equal the pinned id after the `[1m]` strip, else
     the turn fails with class `capability` (`a different model authored an assistant message: <id>`); the init
     model and the main `modelUsage` key stay enforced as before. `modelUsage` keys other than the pinned id
     remain `engine_run.other_models` with a warning (a helper model that authors no assistant message). D4 is
     amended accordingly; F18-2 moves from wontfix to implemented by this.
E14. **A missing capability field is a failure, not an empty array** (20 #3 = F20-3). The init event must carry
     `model`, `permissionMode`, `tools` (an array) and `mcp_servers` (an array); a missing or non-array field
     fails the turn with class `capability` (`init event lacks <field> - the CLI's schema changed; pin the
     version`). `apiKeySource` missing is recorded as `null` (older CLIs) - not a failure.
E15. **A rejecting rate-limit event survives a successful terminal result** (20 #4 = F20-4). The reply stays
     usable; the event is recorded raw in `engine_run.rate_limit` with a warning (`a rate limit rejected a
     request during the turn: <raw>`), and the route's health gets the SAME mark a failed quota turn would get
     from the existing classifier (a usage window -> `usage limit until <reset>`; a burst 429 -> 10 minutes), so
     the roster walk and the plan propagation (E5) see it before the next request hits it.
E16. **The machine-wide limit knows the plan** (F10-4). A consultation's machine-wide running record carries
     the entry's `plan` when it has one; the endpoint-limit check counts, besides the records of the same
     fingerprint, every running record of the same plan from any engine and any repository, with the plan's
     limit (`parallel.<plan>`, default 1). A running codex `ZAI` member in another repository makes a
     `ZAI-claude` run wait, exactly as a same-fingerprint run does today (wave 26b); the wait message names the
     plan.
E17. **Brief 14's tool invariant corrected**: the init tools are Read, Grep, Glob plus `StructuredOutput` only
     under the `native` schema transport; a prompt-only or raw/chore run lists three. Handoff 13 (a chore) is a
     smoke of the route, not native-schema evidence; P8 and the A/B run (handoff 11, `--json-schema`) are.

Amendments after the RC3 smoke on the MiMo endpoint route (handoff 22, F22-1..5; 2026-10-07):

A1. (F22-1) **D6 is AMENDED by E15**: a `rate_limit_event` whose status rejects the request is class `quota` only
    when the turn produces no usable result; when the CLI retried and the terminal result is a success, the reply
    stands (E15) and the rejection is carried as the warning and the health mark. The README states both halves.
A2. (F22-2) E13 reads: every assistant message's `message.model` must equal **the id the init event resolved**
    (an alias pin such as `sonnet` resolves to `claude-sonnet-5-5` in the init event; the comparison is against
    that id, after the `[1m]` strip) - as the code does.
A3. (F22-3) E15's mark is the usage-window mark of the existing classifier - until the reset the event names,
    else 60 minutes; the burst (10-minute) kind cannot arise on this path because the mark's text names a usage
    limit. The "burst 429 -> 10 minutes" clause of E15 is withdrawn.
A4. (F22-4) **E14 amended**: a missing `apiKeySource` is recorded `null` and tolerated ONLY under `auth: endpoint`
    (where the field proves nothing - E3); under `subscription` and `api-key` the field IS the per-turn billing
    proof, so a missing or non-string `apiKeySource` FAILS the turn with class `auth` (`init event lacks
    apiKeySource - the billing proof of this auth mode; pin the CLI version`).
A5. (F22-5) E12's wording: an apiKeySource problem of a killed turn's init is class `auth`, the tool, MCP and
    permission-mode problems class `permission`/`capability` - whatever `Get-ClaudeInitProblem` returns. E16's
    note: a label that carries a `plan` is capped by `parallel.<plan>` (default 1), so raising D5's label limit
    needs `parallel.<plan>` raised as well; the README's roster table says so.

Verification (the acceptance's RC1-RC3 of handoff 20): fake-stream fixtures in `tests/harness-claude.ps1` for
E12-E15 (a prohibited init on a timed-out turn followed by a valid continuation stays FAILED; an Opus-authored
assistant message under a pinned Sonnet fails; an init without `tools` fails; a rejecting rate-limit event
with a successful result keeps the reply usable and marks the health); E16 with two task directories (or
repositories) sharing one health store: a held codex route of plan `zai` makes a panel's same-plan claude
member wait at limit 1 (RC2). RC3 (per-provider native-schema smoke with the invalid-token attempt) is run by
the coordinator against z.ai and MiMo once E12-E16 land.
