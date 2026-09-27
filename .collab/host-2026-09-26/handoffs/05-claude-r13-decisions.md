# R13 + R19 - decisions after the design review (handoffs 02-04)

Reviews: 02 kimi :: k3 (ADVISE, F02-1..4), 03 mimo :: mimo-v2.6-pro (ADVISE, F03-1..7), 04 alibaba ::
qwen3.8-max (ADVISE, F04-1..11). Panel of 3 at once, 26 min wall. The design in 01 stands where not
overridden here; items 1, 2 and 7 of it are replaced.

Verified by the judge on this machine (2026-09-27, codex-cli 0.155.1): `codex plugin` exists with
`add`, `list`, `marketplace` (add/list/upgrade/remove) and `remove`; `~/.codex/config.toml` already
configures marketplaces (`openai-bundled`, `claude-plugins-official` from a GitHub URL); `~/.codex/plugins/
cache/` exists. F04-1 is right: the Codex host installs Claude-layout plugins itself.

D1. Install on the Codex host = the same plugin through Codex's plugin system (F04-1, F03-1, F04-9,
    F02-1, F02-3, F04-3). No copies of skills, no install script, no `install/` folder, nothing written
    to `$HOME` by the bridge (F04-2). The README's "Codex CLI" section is two operator-run commands
    (`codex plugin marketplace add <this repository's GitHub URL>`, `codex plugin add codex-consult` - the
    implementer reads `codex plugin marketplace --help` / `codex plugin add --help` for the exact
    syntax, read-only, never against the real `~/.codex/`) plus the AGENTS.md rule (D7). The "any shell"
    section is a git clone with `CODEX_CONSULT_ROOT=<clone>/plugins/codex-consult`.
D2. The root variable, reversed (F02-2, F04-3): the skills keep `${CLAUDE_PLUGIN_ROOT}` in every
    invocation (both hosts set it for a Claude-layout plugin - the live verification confirms it on
    Codex; if Codex does not, wave 27 falls back to D2-alt: the resolution line). One sentence at the
    top of each skill: "`${CLAUDE_PLUGIN_ROOT}` is the plugin directory; from a plain shell set
    `CODEX_CONSULT_ROOT` to it and use that instead". The `<skill dir>/../..` fallback is dropped from
    the docs (correct only for a clone, misleading for anything else).
D3. Coordinator identity (F03-2, F04-4, F04-5, F03-3): `CODEX_CONSULT_COORDINATOR` (optional) is parsed
    with the wave 26 reviewer matcher (`provider :: model [engine]`, a roster position `#n`, or a
    label) and compared on the RESOLVED identity (provider, model, engine) - the same code path as
    `-Require`, never a lineage string compare. Unparseable -> refused before anything starts. The host
    is inferred only as a hint: `coordinator.host` = `claude-code` (CLAUDECODE / CLAUDE_CODE_ENTRYPOINT
    / AI_AGENT starting with `claude-code`), `codex` (CODEX_SESSION_ID / CODEX_THREAD_ID), else
    `unknown`; no warning from inference alone. Ledger `coordinator {provider, model, engine, host,
    source: explicit|inferred|none}` - a NEW key, never `host` (F04-10: `host` is the machine name).
    The warning when a seated reviewer's identity equals the coordinator's: "a second opinion from the
    coordinator's own model" (not refused), also in the dry run.
D4. Child environment hygiene (F04-7): every engine child the bridge starts (main turn, denial retry,
    format repair, continuation, the detached background) gets the coordinator's environment MINUS a
    documented list of host markers: `CODEX_SESSION_ID`, `CODEX_THREAD_ID`, `CODEX_CI`,
    `CODEX_SANDBOX_NETWORK_DISABLED`, every `CODEX_SANDBOX*`, `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`,
    `AI_AGENT`; kept: `CODEX_HOME`, the provider keys, PATH, everything else. Ledger `child_env_scrubbed`
    (the names removed; never values). Harness: a fake engine that prints its environment; both hosts.
D5. Hooks on both hosts (F04-6, F03-7, F04-8): the plugin's `hooks/hooks.json` SessionStart is expected
    to run on Codex too (the live verification checks it; if it does not, the AGENTS rule of D7 tells the
    coordinator to run the one-liner). The documented one-liner carries `-ExecutionPolicy Bypass`. The
    hook prints one pointer line beside the availability line: `codex-consult: coordinator rules -
    skill codex-consult:coordinate (or codex-consult.ps1 -Explain coordinate)`.
    `codex-consult.ps1 -Explain coordinate|consult|providers` prints the corresponding SKILL.md body for
    skill-less hosts (Kimi's option; read-only, exit 0).
D6. Wording (F03-4, F02-4): script synopses, `.DESCRIPTION`/`.EXAMPLE` text, the hook header and the
    README/skills say "the coordinator" / "the judge"; Claude Code and Codex CLI are named only in the
    host-specific install and hooks sections. The brief prefix `NN-claude-<slug>` stays the DEFAULT
    (the ledgers of every install use it) but is documented as "the coordinator's brief prefix";
    `-BriefPrefix <slug>` / `CODEX_CONSULT_BRIEF_PREFIX` lets another host name its briefs; an engine
    name (`codex`, `agy`, `muse`, `claude` reserved for the future claude engine's REPLIES? no - `claude`
    stays the brief default; the reserved reply prefixes are the engine names of `engines`) is refused
    as a brief prefix when it is a reply prefix (`codex`, `agy`, `muse`). The harness greps the skills
    and README for `Claude` outside the host sections and for `${CLAUDE_PLUGIN_ROOT}` outside the
    documented line and the invocations.
D7. R19 (F03-5, F03-6, F04-11; Q4-Q6): ONE separate skill `coordinate`, English, host-neutral. Body =
    the invariants (one objective per worker; a fresh worker per wave with its state on disk - STATE.md,
    logs, the CHANGELOG entry as the report; poll a state file instead of a blocking wait; a watchdog
    wake shorter than the host's prompt-cache TTL, phrased "when your host wakes you, read the worker's
    state file, then message or `-Kick`"; compaction or a fresh session at wave boundaries; never redo
    a worker's work; English to reviewers, the operator's language only with the operator; the
    live-member rule - nothing written under the collab directory or the working tree, no git command,
    while an agy or muse member runs; rate every consultation; ask the operator before going on without
    a required reviewer; the bridge's own means: `-Detach`, `-Status`, `-Wait`, `-Kick`) followed by a
    "means per host" section: Claude Code (subagents by tier alias, scheduled wakes, `/autocompact`,
    the `agents/` files), Codex CLI (`~/.codex/agents/<tier>.toml` with `name`, `description`,
    `developer_instructions` and no model key; `SubagentStop`, `PreCompact`; a background shell as the
    watchdog), plain shell (cron). Tier CONTRACT, not model names: deep reasoning / default execution /
    cheap read-only recon. Agent files: the plugin ships Claude Code `agents/{opus,sonnet,haiku}-worker.md`
    using the tier ALIASES `opus` / `sonnet` / `haiku` (stable aliases, not versions - Kimi); no Codex
    agent files are shipped or written (`install/examples/codex-agents/*.toml` as examples the operator
    may copy, documented as such). `consult-codex` cross-links `coordinate`. The AGENTS.md rule for the
    Codex host is a three-line snippet in the README the OPERATOR pastes (`install/AGENTS.snippet.md`
    is dropped; the text lives in the README).
D8. The operator's private CLAUDE.md migration is documented in one README paragraph ("For the
    coordinator"); the plugin never edits a CLAUDE.md.
D9. Verification (replaces 01 "Verification"): on THIS machine, after the OPERATOR installs the plugin
    on the Codex host per the README, one fresh `codex exec` session as the coordinator runs one
    checkpoint consultation with reviewer `mimo :: mimo-v2.6-pro` on task `r13-host` from the README
    and the skills alone; the ledger entry proves `coordinator.host: codex`, `child_env_scrubbed` and
    the hook line (or its absence, recorded). Harness: D2's greps, D3's matcher and refusal, D4's fake
    engine environment, D5's `-Explain`, D6's prefix refusal, the `coordinate` skill's presence and
    front matter, the agent files' front matter (model = an alias).

Requested checks answered: RC2 (Kimi, env markers inside `codex exec`) - observed by the alibaba reviewer
from inside its own run: `CODEX_SESSION_ID`, `CODEX_THREAD_ID`, `CODEX_CI`, `CODEX_SANDBOX_NETWORK_DISABLED`
set; the Claude markers `AI_AGENT`, `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT` inherited from the coordinator
- the basis of D4.
