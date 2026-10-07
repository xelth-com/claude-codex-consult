# claude-codex-consult (CCC)

A plugin (`codex-consult`, version 0.6.0) for the agent that coordinates the work - the
**coordinator**, the judge of every reply - to consult reviewers and record every
consultation as files. This README is written for the AI coding agent that installs, wires
and uses the plugin; humans can follow the same steps. The host is a parameter (0.5.0, wave
27): the same plugin installs through the plugin system of each supported agent host, and
the scripts run from any shell (see "Install"). A reviewer reached through a provider table
needs no ChatGPT plan.

## For the agent installing this

- **What it is:** a dependency-free PowerShell bridge that runs `codex exec` for a review (or, per roster entry, another CLI "engine": Google's Antigravity CLI `agy` for the Gemini models, Meta's Muse Code CLI `muse` for the Muse Code subscription, Claude Code headless `claude` for the Claude subscription or an API key - see "Engines"), records the consultation as files (brief, verbatim reply, JSON ledger), and manages reviewer identity, availability, a roster/panel and structured findings.
- **Prerequisites.** Check each with the command; do not assume:
  - [ ] Windows PowerShell 5.1 or PowerShell 7: `powershell -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` or `pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` → `5.1.…` or `7.…` (on Windows use `powershell` - always present; `pwsh` there may be only the WindowsApps alias, which a host's sandbox can refuse to execute; `pwsh` on macOS, Linux and a real PowerShell 7 install)
  - [ ] git: `git --version` → `git version …`
  - [ ] Codex CLI on PATH: `codex --version` → `codex-cli 0.148` or newer (tested with `codex-cli 0.155.1`)
  - [ ] a reviewer: `codex login status` → `Logged in using ChatGPT`, **or** a `[model_providers.<name>]` table whose `env_key` variable the USER has set. Never create, print or paste an API key.
  - [ ] optional, Gemini through the `agy` engine: `agy models` → lines `<model id><TAB><name>` (the USER installed Google's Antigravity CLI and signed in by running `agy` once; you never handle the login). See "Engines".
  - [ ] optional, Meta Muse through the `muse` engine: the USER installed Muse Code and signed in with `muse login` with the user variable `TBH_CREDENTIAL_BACKEND=file` set first (required on every OS: the bridge launches muse only on an oauth sign-in it can read from `~/.config/muse/auth.json`); `codex-providers.ps1` then shows the roster's muse row with `ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth)`. `META_API_KEY` and `MODEL_API_KEY` must NOT be set (a muse run is refused then: it would bill per token). You never read `auth.json` or handle the login. See "Engines (wave 23)".
  - [ ] optional, Claude through the `claude` engine: the USER installed Claude Code (`claude --version` -> `2.1...` or newer) and signed in (`claude auth login`, or `/login` in an interactive session); `codex-providers.ps1` then shows the roster's claude row with `ok: signed in (claude.ai subscription)`. The USER must not route Claude Code through an inherited `ANTHROPIC_BASE_URL`, Bedrock, Vertex or Foundry (such a setup is unavailable, and those variables never reach the reviewer); a coding plan with an Anthropic-compatible endpoint (z.ai, MiMo, Kimi Code) can also run through Claude Code as an explicit roster entry with `auth: "endpoint"` (setup-providers section 3g). You never handle the login or an API key. See "Engines (wave 29)".
- **Telemetry, on by default (0.5.0):** after every consultation ONE anonymised event (engine, provider label, model, purpose, outcome class, counts, versions, a salted instance id - never a task, brief, prompt, path or name) goes to the maintainer's intake; installing the plugin means accepting these terms. Tell the operator before the first consultation; `CODEX_CONSULT_TELEMETRY=off` (a user variable the OPERATOR sets) switches it off. The exact payload: "Telemetry (on by default)".
- **Install:** the section "Install" - one host each: the plugin system of your agent host (the operator runs the install commands), or a clone for any shell.
- **Verify:** `codex-providers.ps1` → at least one row `available`; then a `-DryRun` consultation → first line `DRY RUN - nothing was executed and no file was written.` and a line `preflight   : available (…)`. Exact commands: "Setup on a new machine", steps 0 and 9.
- **First consultation:** the `consult-codex` skill (`codex-consult:consult-codex <task-id> <question>`), or the command under "Usage".
- **Coordinating:** the `coordinate` skill (workers, waves, waits) - "For the coordinator".
- **More reviewers** (z.ai GLM, Xiaomi MiMo, BytePlus, Kimi, Alibaba, any Responses-API provider; Gemini through the `agy` engine; Meta Muse through the `muse` engine; Claude through the `claude` engine; a coding plan with an Anthropic-compatible endpoint - z.ai, MiMo, Kimi Code - can also run through Claude Code, section 3g): follow the `setup-providers` skill. Its step 0 asks the operator which subscriptions they have and maps each to its section - on a fresh machine start there, or hand the operator the prompt under "First run".

---

## First run: the prompt for the operator

The plugin ships no subscription. Every reviewer is a CLI or a plan the operator already pays
for (a ChatGPT plan behind the Codex CLI, a coding plan behind a `[model_providers]` table, Google's
Antigravity CLI, Meta's Muse Code CLI, Claude Code); the bridge only launches them and reads the roster. So the
first thing a fresh installation needs is a conversation: what the machine has, what the operator
subscribes to, and which of it to wire. The `setup-providers` skill runs that conversation from its
step 0. The operator starts it by pasting this prompt into their agent host, right after the install
commands of their host under "Install" - Claude Code, Codex CLI, Z Code, Kimi Code, Qwen Code,
OpenCode, Muse Code or a plain shell alike:

```text
The codex-consult plugin is installed. Wire my reviewers by following its setup-providers skill
from step 0 (codex-consult:setup-providers; a host without skills prints it with the plugin's own
script: powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/codex-consult.ps1"
-Explain providers - pwsh -NoProfile -File on macOS and Linux; the plugin directory is in this
session's start line or under "Install" in the repository README).

1. Check first, ask second: the shell, git, the Codex CLI and its login, then the preflight
   codex-providers.ps1 -Short. One line per result.
2. Ask me which of these I have (several are possible), skipping what the preflight already shows
   as available: a ChatGPT plan (Plus, Pro, Team, Enterprise); z.ai GLM Coding Plan; Xiaomi MiMo
   Token Plan; Google AI Pro or Ultra (the Antigravity CLI); BytePlus ModelArk Coding Plan; Kimi
   Code membership; Alibaba Model Studio Token Plan (Qwen); Meta Muse Code subscription; a Claude
   subscription or an Anthropic API key (Claude Code; a coding plan with an Anthropic-compatible endpoint - z.ai,
   MiMo, Kimi Code - can also run through Claude Code, setup-providers section 3g); another
   Responses-API provider or a pay-as-you-go key; none of them.
3. For each one I name, follow its section of the skill. Ask before installing anything or editing
   config.toml. A CLI install, a login or an API key is mine to do in my own terminal: give me the
   exact command or the exact variable NAME, wait for me, then verify. Never create, print, read
   back or paste a key.
4. Write the roster (ask me which reviewer comes first and which count as "weighty"), verify with
   codex-providers.ps1 and a -DryRun consultation, and tell me that telemetry is on by default and
   how to switch it off (CODEX_CONSULT_TELEMETRY=off).
5. Record what you wired in the project's state.md (variable names, never values) and tell me what
   is still unavailable and why.
```

What the agent does with it is the skill: the checks of "Setup on a new machine" steps 1-4, the
interview of step 0, one section per plan (2, 3, 3b-3g), the roster (4), the verification (5) and
the record (7). A machine with nothing to wire ends with a clear answer - "no reviewer: the Codex
CLI is not signed in and no plan was named" - not with a half-written roster.

---

## Install

One plugin for every host: the same directory `plugins/codex-consult/` (skills, scripts,
templates, schemas, hooks, agents) is installed by the host's own plugin system - no copies of
skills, no install script, nothing the bridge writes into your home directory. The install
commands write the host's own configuration, so the **operator** runs them in a terminal; a
coordinator never runs them itself (inside a workspace sandbox it could not, and it must not
install software on its own).

### Claude Code

At the Claude Code prompt (the operator):

```
/plugin marketplace add xelth-com/claude-codex-consult
/plugin install codex-consult@claude-codex-consult
```

Skills `codex-consult:consult-codex`, `codex-consult:setup-providers`, `codex-consult:coordinate`;
agents `codex-consult:opus-worker`, `codex-consult:sonnet-worker`, `codex-consult:haiku-worker`
(model aliases `opus`, `sonnet`, `haiku`); the SessionStart hook. The plugin directory is
`~/.claude/plugins/cache/claude-codex-consult/codex-consult/<version>/`; inside the skills it is
`${CLAUDE_PLUGIN_ROOT}`. Update: `/plugin marketplace update claude-codex-consult`.

### Codex CLI

Codex CLI installs this Claude-layout plugin itself (checked with `codex-cli 0.155.1`: it
mirrors `.claude-plugin/plugin.json`, `hooks/hooks.json`, `scripts/`, `skills/` and
`templates/` into its plugin cache and lists the skills as `codex-consult:<skill>`). In the
operator's own terminal:

```
codex plugin marketplace add xelth-com/claude-codex-consult
codex plugin add codex-consult@claude-codex-consult
```

Expect `codex plugin list` to show `codex-consult@claude-codex-consult`; the plugin directory is
`<codex home>/plugins/cache/claude-codex-consult/codex-consult/<version>/`. Update: `codex plugin
marketplace upgrade claude-codex-consult`; remove: `codex plugin remove
codex-consult@claude-codex-consult`, then `codex plugin marketplace remove claude-codex-consult`.
Codex CLI runs no Claude Code agent files: the worker tiers are agent files of its own that the
operator may keep in `~/.codex/agents/<tier>.toml` (`name`, `description`,
`developer_instructions`, no model key) - the plugin ships EXAMPLES to copy,
`<plugin>/install/examples/codex-agents/{opus,sonnet,haiku}-worker.toml`, and never writes one.

Then the operator pastes these three lines into the project's `AGENTS.md` or the global one of
Codex CLI, `~/.codex/AGENTS.md` (`<codex home>/AGENTS.md`), with `<plugin>` replaced by the plugin
directory above (re-point it after an upgrade):

```text
codex-consult: follow skill codex-consult:coordinate for delegation, waves and waits, and skill codex-consult:consult-codex for consultations; without skills read them with: powershell -NoProfile -ExecutionPolicy Bypass -File <plugin>/scripts/codex-consult.ps1 -Explain coordinate (or -Explain consult).
codex-consult: when no "codex-consult:" line is in your context at session start, run powershell -NoProfile -ExecutionPolicy Bypass -File <plugin>/scripts/codex-consult-hook.ps1 and read its two lines (who is out, where the rules are).
codex-consult: CODEX_CONSULT_COORDINATOR names you as "<provider> :: <model>" in the roster's spelling - keep the operator's value when it is set, set it yourself before a consultation only when it is empty; installing, upgrading and signing in are the operator's - never run "codex plugin" or "codex login" yourself.
```

The sandbox: a real consultation writes under the repository's `.collab/` and starts the
reviewer's CLI (`codex exec`, `agy`, `muse`) as a child process that needs the network and
writes its own session files under `<codex home>`. A coordinator session in the `read-only`
sandbox can run `-DryRun`, `-Explain` and `codex-providers.ps1` only. (0.5.0, wave 27c) What was
observed on 2026-09-29 (Windows, codex-cli 0.155.1): in the `workspace-write` sandbox with network
access enabled (`codex exec --sandbox workspace-write -c sandbox_workspace_write.network_access=true
--add-dir <codex home> ...`) the reviewer child had no connection - the run timed out -, while
`-DryRun`, `-Explain` and `-Status` work inside it; process inspection is denied there too (the
bridge now confirms every tree kill and says when it cannot - "Timeouts"). A real consultation
therefore needs the coordinator session OUTSIDE the sandbox (the operator's decision), or the
operator runs the bridge command from a plain shell. `pwsh` inside the sandbox resolved to the
WindowsApps alias, which the sandbox refused to execute: on Windows use `powershell`.

### Z Code

Z Code (Z.ai's agent host; checked with desktop 3.14.3, CLI 0.16.9) installs this Claude-layout
plugin through its own plugin manager - in the app, or with its CLI in the operator's terminal
(`<zcode>`: on Windows `node "<install dir>\resources\glm\zcode.cjs"`, which the desktop app
ships; there is no `zcode` on PATH):

```
<zcode> plugins marketplace add xelth-com/claude-codex-consult
<zcode> plugins install codex-consult@claude-codex-consult
```

Expect the plugin enabled with its skills and the SessionStart hook. Z Code substitutes both
`${CLAUDE_PLUGIN_ROOT}` and `${ZCODE_PLUGIN_ROOT}` in skills, hooks and commands, so the skills
work unchanged. It reads `AGENTS.md` - the project's, or its global `~/.zcode/AGENTS.md`: the three
lines above apply, `<plugin>` being the directory Z Code installed the plugin to. A live
coordinator session runs inside the app (a headless `-p` run outside it stops at "Select a model
before continuing"). (wave 27c) Observed in a desktop session (2026-09-29, desktop 3.14.3): its
shell tool carries `ZCODE_*` variables (`ZCODE_APP_VERSION`, `ZCODE_ENV`, `ZCODE_PROCESS_LABEL`,
two provider configuration file paths and more) but neither `ZCODE_SESSION_ID` nor
`ZCODE_PROJECT_DIR`; the bridge infers the host `zcode` from ANY `ZCODE_` variable and scrubs the
whole prefix from every child. No `codex-consult:` session-start line reached the context of that
desktop session - the second `AGENTS.md` line (run the hook one-liner) covers it. Its shell tool
cut a blocking call at 600 s: a run with a longer timeout goes with `-Detach`.

### Kimi Code

Kimi Code (`kimi`, checked with 0.27.0) has no plugin system: the operator clones the repository
and starts it with the plugin's skills directory (`--skills-dir` is repeatable):

```powershell
git clone https://github.com/xelth-com/claude-codex-consult <clone>
$env:CODEX_CONSULT_ROOT = "<clone>/plugins/codex-consult"     # the plugin directory: ONE name, set here
kimi --skills-dir "$env:CODEX_CONSULT_ROOT/skills"
```

(Bash: `export CODEX_CONSULT_ROOT=<clone>/plugins/codex-consult`, then `kimi --skills-dir
"$CODEX_CONSULT_ROOT/skills"` - the skills directory is `<clone>/plugins/codex-consult/skills`.) It
does not substitute `${CLAUDE_PLUGIN_ROOT}` (the skill text arrives literally), so
`CODEX_CONSULT_ROOT` must stay set in the environment `kimi` starts from - the block above sets it
for that shell; every skill's first sentence says to use it instead; its shell tool on Windows is
Git Bash (`$CODEX_CONSULT_ROOT`). No hooks: the session-start line comes from the hook one-liner
(`codex-consult-hook.ps1`, below), the rules from the `coordinate` skill or `-Explain coordinate`.
Paste the three lines above into the PROJECT's `AGENTS.md` - the project file only (Kimi Code reads
it from the working directory only, not from a parent directory or the home), `<plugin>` =
`<clone>/plugins/codex-consult`. Its shell tool cut a blocking call at 300 s in the foreground
(2026-09-29): a run with a longer timeout goes with `-Detach` (then `-Wait` / `-Status`).
It sets no environment marker of its own (`coordinator.host` stays `unknown`), so the coordinator
names itself: `CODEX_CONSULT_COORDINATOR`, e.g. `kimi :: k3` (the label and model your roster
uses for it). A headless `-p` run takes neither `--yolo` nor `--auto`.

### Qwen Code

Qwen Code (`qwen`, checked with 0.15.6) installs this plugin as an extension straight from the
repository's Claude marketplace (the source form `<marketplace-url>:<plugin-name>`). In the
operator's terminal:

```
qwen extensions install https://github.com/xelth-com/claude-codex-consult:codex-consult --consent
```

Expect the whole plugin directory in `~/.qwen/extensions/codex-consult`, enabled; `qwen extensions
list` shows the skills and the three agents. At the install Qwen Code replaces
`${CLAUDE_PLUGIN_ROOT}` in the skill text by the install path, so the skills' commands run as
written. `hooks/hooks.json` is copied, but no hook is listed for the extension: the session-start
line comes from the hook one-liner (the second `AGENTS.md` line). Update: `qwen extensions update
codex-consult`; remove: `qwen extensions uninstall codex-consult`. The three lines above go into the
project's `AGENTS.md` (its bundled documentation: Qwen Code reads it beside its own `QWEN.md`) or its
global `~/.qwen/QWEN.md`, `<plugin>` = `~/.qwen/extensions/codex-consult`. Headless: a positional
prompt, `-y` for automatic approval. Its shell tool's time limit is unknown: start a run with
`-Detach`. Not run live by the maintainer: the free Qwen OAuth quota ended on 2026-04-15, so the
session had no model access (choosing another route with `/auth` is the operator's step).

### OpenCode

OpenCode (`opencode`, 1.17.18) has no Claude-layout plugins (its plugins are npm modules), but it
discovers skills in fixed places - its documentation (opencode.ai/docs/skills, read 2026-09-29): in
a project `.opencode/skills/<name>/SKILL.md`, `.claude/skills/<name>/SKILL.md` or
`.agents/skills/<name>/SKILL.md` (walking up to the git worktree root); globally
`~/.config/opencode/skills/*/SKILL.md`, `~/.claude/skills/*/SKILL.md` or
`~/.agents/skills/*/SKILL.md`. No option adds a directory, and a skill's name must equal its
directory name (lower case, digits, single hyphens - the plugin's skills satisfy it). So the
operator clones the repository and LINKS each skill directory - a link, never a copy, so that a
`git pull` updates the skills:

Windows (PowerShell; a junction per skill):

```powershell
git clone https://github.com/xelth-com/claude-codex-consult <clone>
$env:CODEX_CONSULT_ROOT = "<clone>/plugins/codex-consult"     # the plugin directory: ONE name, set here
New-Item -ItemType Directory -Force "$HOME/.config/opencode/skills" | Out-Null
foreach ($n in 'consult-codex', 'coordinate', 'setup-providers') { cmd /c mklink /J "$HOME\.config\opencode\skills\$n" "$env:CODEX_CONSULT_ROOT\skills\$n" }
```

Elsewhere (bash; a symbolic link per skill, `ln -s`):

```bash
git clone https://github.com/xelth-com/claude-codex-consult <clone>
export CODEX_CONSULT_ROOT=<clone>/plugins/codex-consult      # the plugin directory: ONE name, set here
mkdir -p ~/.config/opencode/skills
for n in consult-codex coordinate setup-providers; do ln -s "$CODEX_CONSULT_ROOT/skills/$n" ~/.config/opencode/skills/$n; done
```

It does not substitute `${CLAUDE_PLUGIN_ROOT}`: keep `CODEX_CONSULT_ROOT` set in the environment
`opencode` starts from. It runs no Claude-layout hooks: the hook one-liner gives
the session-start line. The three lines above go into the project's `AGENTS.md` (found walking up
to the worktree root) or the global `~/.config/opencode/AGENTS.md`, `<plugin>` =
`<clone>/plugins/codex-consult`. Headless: `opencode run "<prompt>"`. Its shell tool's time limit is
unknown: start a run with `-Detach`. Not run live by the maintainer: the provider configured on the
machine refused the authentication.

### Muse Code

Muse Code (`muse`, 1.4.0) installs skills one at a time from a directory: `muse skills install
<path> [--scope user]`; `muse skills update <skill-id>` refreshes one, `muse skills list` shows the
source of each (user, project, built-in, plugin), and `muse skills import --from claude|codex`
imports the skills of those hosts. **Muse Code is also a REVIEWER engine of the bridge** ("Engines
(wave 23)"), and skills installed at user scope are visible to the reviewer sessions too: install
the three skills at PROJECT scope, in the repositories where Muse Code coordinates - never with
`--scope user` - and check the source column of `muse skills list`:

```powershell
git clone https://github.com/xelth-com/claude-codex-consult <clone>
$env:CODEX_CONSULT_ROOT = "<clone>/plugins/codex-consult"     # the plugin directory: ONE name, set here
# in the project (PROJECT scope):
foreach ($n in 'consult-codex', 'coordinate', 'setup-providers') { muse skills install "$env:CODEX_CONSULT_ROOT/skills/$n" }
```

Keep `CODEX_CONSULT_ROOT` set in the environment Muse Code starts from (that Muse Code substitutes
`${CLAUDE_PLUGIN_ROOT}` is not known) and run the hook one-liner at the start. The three lines above
go into the project's `AGENTS.md`, `<plugin>` = `<clone>/plugins/codex-consult`; Muse Code also
includes the personal rules of other hosts on its own. Headless: `muse exec --prompt-file <file>
--workspace <dir>`. Its shell tool is PowerShell with a default wait of 10 s and a maximum of 300 s:
a run with a longer timeout goes with `-Detach` (then `-Wait` / `-Status`). Not run live by the
maintainer as a coordinator: on Windows its shell tool needs the sandbox setup of Muse Code done once
with elevated rights ("sandbox users are not ready").

### Any shell (a clone)

```powershell
git clone https://github.com/xelth-com/claude-codex-consult <clone>
$env:CODEX_CONSULT_ROOT = "<clone>/plugins/codex-consult"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:CODEX_CONSULT_ROOT/scripts/codex-consult.ps1" -Explain consult
```

Bash: `export CODEX_CONSULT_ROOT=<clone>/plugins/codex-consult`. Every skill starts with the same
sentence: `${CLAUDE_PLUGIN_ROOT}` is the plugin directory; from a plain shell set
`CODEX_CONSULT_ROOT` to it and use that instead. `-Explain coordinate|consult|providers` prints
a skill's text for a host that has no skills.

### Hooks on each host

The plugin's one hook is SessionStart (`hooks/hooks.json` → `scripts/codex-consult-hook.ps1`):
two lines into the coordinator's context - who is out and until when, then
`codex-consult: coordinator rules - skill codex-consult:coordinate (or powershell -NoProfile
-ExecutionPolicy Bypass -File "<plugin>/scripts/codex-consult.ps1" -Explain coordinate); telemetry:
on` - (wave 27c, D13) the full command with this installation's own script path, runnable as
printed on a host that substitutes nothing (`pwsh -NoProfile -File ...` off Windows); (wave 28) the
telemetry switch, `on` or `off`. Claude Code runs it at every session start of a project where the plugin is
enabled. Codex CLI knows the same event and reads `hooks/hooks.json`, and it runs a plugin's
hooks only once they are trusted; whether it does for this plugin is part of the host's
acceptance run. Z Code recognises the hook at the install and substitutes the plugin root in it,
so it runs as on Claude Code. Kimi Code has no hooks. Qwen Code copies `hooks/hooks.json` with the
extension but lists no hook for it; OpenCode runs no Claude-layout hooks; for Muse Code none was
checked. Until a host's run is confirmed, and on any host without hooks, the one-liner does the same
(the AGENTS.md rule above):

```powershell
# the plugin directory - ONE name, CODEX_CONSULT_ROOT: kept when the host's environment sets it (Kimi
# Code, OpenCode, Muse Code, any shell), else the newest install of a plugin host in this home
if (-not $env:CODEX_CONSULT_ROOT) {
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "$HOME/.codex" }
    $env:CODEX_CONSULT_ROOT = @(@("$HOME/.claude/plugins/cache", "$codexHome/plugins/cache", "$HOME/.zcode/cli/plugins/cache") |
            ForEach-Object { Get-ChildItem "$_/claude-codex-consult/codex-consult" -Directory -ErrorAction SilentlyContinue }) +
        @(Get-Item "$HOME/.qwen/extensions/codex-consult" -ErrorAction SilentlyContinue) |
        Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty FullName
}
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:CODEX_CONSULT_ROOT/scripts/codex-consult-hook.ps1"
```

(Wave 28b, D17: copied as written it works on every host - it defines the one name it uses. On
macOS/Linux: `pwsh -NoProfile -File "$CODEX_CONSULT_ROOT/scripts/codex-consult-hook.ps1"` with
`CODEX_CONSULT_ROOT` exported.) It writes nothing, needs no network and always exits `0`.

---

## For the coordinator

The coordinator is the session that plans, delegates to workers, consults reviewers and keeps
the final word - on Claude Code, Codex CLI, Z Code, Kimi Code, a shell, or (documented, not run
live) Qwen Code, OpenCode and Muse Code. Its rules ship with
the plugin as the `coordinate` skill (invariants first, then the means per host and the worker
tier contract: deep reasoning, default execution, cheap read-only recon); `consult-codex` is the consultation
procedure. Set `CODEX_CONSULT_COORDINATOR` to your own model (`<provider> :: <model>` [`
[<engine>]`], a roster position `#<n>`, or a provider label): the bridge parses it with the
`-Require` matcher, refuses only a value that does not parse (the roster's own character rule -
interior blanks are fine, `::`, `[`, `]`, `|`, `,`, `#` inside a name are not) before anything
starts, and warns - on the console, in the dry run and in the ledger's `warnings[]`, never
refusing - when it seats your own model as a reviewer ("a second opinion from the coordinator's
own model"). (0.5.0, wave 27c) The value is resolved like a seated reviewer: `#<n>` and a label
take the model of their roster entry, else the model the bridge would run (the Codex config's);
"own model" is said only when provider, model and engine are equal, and a label whose model
cannot be told (two roster models of it) gives the weaker "a reviewer from the coordinator's own
provider (model not named)". A value no roster entry matches is said, not refused (`coordinator:
<id> (not in the roster - no reviewer can match it)`, ledger `coordinator.in_roster` false); a
`#<n>` that names no position in THIS repository's roster is warned about and recorded
`coordinator.unresolved` - the run goes on. Your host is inferred as a hint only (ledger
`coordinator.host`, from its markers, else from the plugin's install path - `coordinator.host_by`),
and every engine child is started without your host's markers (ledger `child_env_scrubbed`). Your briefs are
named with the coordinator's brief prefix, `handoffs/<NN>-<prefix>-<slug>.md`: `claude` by
default (every existing ledger uses it), another slug through `-BriefPrefix` or
`CODEX_CONSULT_BRIEF_PREFIX` - never `codex`, `agy` or `muse`, the bridge's reply prefixes.

(Wave 29) A Claude Code coordinator sets `CODEX_CONSULT_COORDINATOR="anthropic :: <its model id>"` (a trailing `[1m]` is stripped). For a reviewer of the `claude` engine the ENGINE fixes the vendor: the coordinator's provider is compared with `anthropic` (case-insensitive) whatever the roster label, and the models after normalising (`[1m]` stripped, an alias equal to any id of its family); after the run the resolved model is compared again and a warning is added when the answer changed - always a warning, never a refusal ("Engines (wave 29)").

The `coordinate` skill also carries the idle watchdog (its rule 3): one recurring wake every 30
minutes, armed at your first delegation or wait and kept while any running work exists (a worker,
a detached panel, a shell job, another session's window, the operator's announced step, a
cooldown); compaction at wave boundaries and before a wait longer than the boundary; when idle, the
handover and a compaction at the second idle wake - or, where the agent cannot compact itself
(revision 6 of the rule, 2026-09-30), the context kept warm while work runs or is awaited and, when
idle, the handover at the second idle wake, the wake removed and one line to the operator with the
cheap ways back. The host's auto-compact threshold is the operator's lever: it keeps every wake and
every cold resume small (Claude Code: `--autocompact <tokens>` at launch). Why a wake pays, and when
compacting pays more: the next section, "Waiting: keep the prompt cache or compact".

If your own CLAUDE.md or AGENTS.md carries a private "supervisor / worker delegation" block (the
worker tiers, waves, waits, the language rule), shrink it to a pointer - "Coordinator rules:
skill codex-consult:coordinate" - and keep only what is really yours (your own agent names, a
project convention). The plugin never edits a CLAUDE.md or an AGENTS.md: that migration, like
pasting the AGENTS.md lines above, is the operator's. A same-named agent file of your own
(`~/.claude/agents/opus-worker.md`, `~/.codex/agents/opus-worker.toml`) stays yours; the plugin's
Claude Code agents are namespaced (`codex-consult:opus-worker`).

## Waiting: keep the prompt cache or compact

A coordinator waits a lot: for its workers, a review panel, another session, the operator. This
section explains what a wait costs, why the `coordinate` skill keeps a recurring wake, and when
compacting the conversation is cheaper than keeping it. It assumes no knowledge of prompt caching.

**The prompt cache.** Every request of a coordinator carries its whole context - the instructions,
the tools and the conversation so far, often several hundred thousand tokens. The model's vendor
keeps a context it has just processed in a *prompt cache* for a limited *lifetime*: one hour in the
coordinator sessions where this was measured, five minutes by default on the API (one hour on
request). A request that repeats the cached context within the lifetime pays only the cheap *cache
read* for it and starts the lifetime anew - a *refresh*. A request after the lifetime finds nothing
and pays a *cache write* of the whole context - here called a *cold resume*.

**Three prices.** Beside plain input, a token is paid as a cache read (a small fraction of the
input price), as a cache write (twice the input price with the one-hour lifetime, 1.25 times with
five minutes) or as output (what the model writes, the dearest). API list prices of 2026-09, USD
per million tokens:

| Model of the coordinator | Input / output | Cache read | Cache write, 1 h lifetime | One cold resume costs as much as |
|---|---|---|---|---|
| Claude Fable 5.1 | 10 / 50 | 0.25 (0.025 x input) | 20 (2 x input) | 80 cache reads - 40 hours of refreshes every 30 minutes |
| Claude Opus 5.5 | 4 / 20 | 0.20 (0.05 x input) | 8 (2 x input) | 40 cache reads - 20 hours |
| Claude Sonnet 5.5 | 2 / 10 | 0.20 (0.1 x input) | 4 (2 x input) | 20 cache reads - 10 hours |

(Wave 28b, D18) Two refresh prices appear below, and they are not the same: a *cache read* alone
(r x P x C - the API's `max_tokens: 0` request, nothing else billed) and a *full wake* (the cache
read PLUS the wake's own turn - `one wake` in the formulas). The last column of this table counts
cache reads; a full wake costs more, so a cold resume is worth fewer full wakes (at 850K tokens on
Claude Fable 5.1: 17 USD / 0.2475 USD = about 69 full wakes, not 80).

**Refreshing, and what counts as running work.** The `coordinate` skill arms ONE recurring wake
every 30 minutes at the first delegation or wait of a session. A wake is a small turn: it reads the
whole context from the cache (the refresh), adds about 1K tokens of new input - written to the
cache at the write price - and about 300 tokens of output. On the API a refresh needs no turn:
repeat the previous request with `max_tokens: 0` (not streamed), and only the cache read is billed.
The wake stays armed, and the session does not count as idle, while any *running work* exists:

- a worker or subagent of your own that has not reported;
- a detached panel or consultation (a background `-Wait` is its notification);
- a long shell job you started (a test suite, a build);
- a window you gave ANOTHER session, or a step of another session you depend on, until it says it is done;
- a step of the operator with a named end ("I install it and come back");
- a cooldown with a named end (a provider's `retry_after`, a quota window) before a run you will repeat.

Idle is only: none of these, and nothing to do without the operator.

**Keep or compact: the boundary.** To *compact* is to let the model write a summary of the
conversation and go on from it: the small new context - the *compact window*, about 50K tokens with
the host's own instructions and tools - replaces the large one. Before a long wait there are three
ways: keep the large context warm with wakes; compact, remove the wake and read the compact window
cold at the end; or let the large cache expire and pay its cold resume. With C the context in
tokens, P the input and Pout the output price per token, r the cache-read and w the cache-write
multiplier:

```text
one wake       = r x P x C + turn           turn = 1K x w x P (new input) + 300 x Pout
keep, n wakes  = n x one wake + r x P x C   (the resume reads the warm context)
compact        = r x P x C + S x Pout + w x P x C2   (one read, the summary S of about 10K
                 output tokens, the cold write of the compact window C2 of about 50K at the resume)
let it expire  = w x P x C                  (the cold resume)
boundary       = (S x Pout + w x P x C2) / one wake   wakes; hours = wakes / 2
compact after expiry = w x P x C + S x Pout + w x P x C2   (the cache gone: the compaction re-reads
                 the whole context COLD, then writes the summary; the compact window's cold write follows)
```

Keeping and compacting both read the large context once, so keeping is cheaper while its wakes cost
less than the summary and the cold write of the compact window - at 1M on Claude Fable 5.1, (1.75 -
0.25) / 0.285 = 5.3 wakes, 2.6 hours. In USD, a wake every 30 minutes:

| Context C | Claude Fable 5.1: keep is cheaper up to | one wake | compact | let it expire | Claude Opus 5.5: keep up to | Claude Sonnet 5.5: keep up to |
|---|---|---|---|---|---|---|
| 1M | 2.6 hours | 0.29 | 1.75 | 20 | 1.4 hours | 0.7 hours |
| 850K | 3.0 hours | 0.25 | 1.71 | 17 | 1.6 hours | 0.8 hours |
| 500K | 4.7 hours | 0.16 | 1.63 | 10 | 2.6 hours | 1.4 hours |
| 300K | 6.8 hours | 0.11 | 1.58 | 6 | 4.1 hours | 2.2 hours |
| 150K | 10.3 hours | 0.07 | 1.54 | 3 | 6.8 hours | 4.1 hours |

The price of compacting hardly depends on C (it is mostly the summary and the cold write of the
compact window); the price of keeping grows with C - the larger the context, the earlier compaction
wins. The cheaper a cache read is relative to the model's other prices (a small r), the longer
keeping pays: the boundary comes earlier on the cheaper models. Above about 80K tokens, compacting
(while the cache is warm) is cheaper than letting the cache expire, however long the wait. A third way - compact, then
keep the small compact window warm - beats reading it cold on Claude Fable 5.1 only for waits under
about eight to ten hours (depending on how much of it is already cached), by less than one USD: a
refinement, not another rule.

Worked example: a night of 8 hours at 850K tokens on Claude Fable 5.1. Keeping the context warm
costs 16 wakes x 0.2475 = 3.96 USD, plus 0.21 USD for the read at the resume: about 4.2 USD.
Compacting before the night and reading the compact window cold in the morning costs 1.71 USD.
Letting the large cache expire costs one cold resume: 17 USD.

What the money does not show: after a compaction every working turn reads the compact window
instead of the large context (0.01 instead of 0.21 USD a turn in the example) - in favour of
compaction; a compaction drops the detail the summary did not keep - against it, which is why the
rule compacts at wave boundaries, with the state on disk.

**The rule** (the `coordinate` skill, rule 3):

1. While running work goes on: keep the wake. No compaction in the middle of a wave.
2. At a wave boundary (the report is read, the state is on disk): compact, or start a fresh session from the state file.
3. A wait of known length: shorter than the boundary - refresh; longer - compact first (while the cache is warm), then remove the wake and let something wake you at the end.
4. Idle: idle wake 1 - one line in the state file; idle wake 2 - the handover, then compact and remove the wake.
5. Where the agent cannot compact itself (Claude Code, verified on 2026-09-29: no tool for it, and a scheduled `/compact` arrives as ordinary text) - (revision 6, the operator's decision of 2026-09-30) two states only, until the host lets the agent compact itself: while work runs or is awaited, the context is kept warm ALWAYS, however long the wait; when idle, idle wake 1 is the note and idle wake 2 writes the handover on disk, removes the wake and tells the operator in one line the cheap ways back - a fresh session from the state file; or, to keep the conversation, a cheaper model whose window holds the context, a compaction there, and back (the cold cache below); and the launch option that bounds the context at the next start. (Revision 5's branch "keep the wake for half the refreshes a cold resume is worth" is removed; the boundary tables above stay as the operator's guide for a manual compaction before a long absence.)
6. Compact only while the cache is warm: after it expired, a compaction costs a cold resume PLUS the summary (and the compact window's cold write at the resume) - more than letting it expire.
7. The operator's lever: the host's auto-compact threshold keeps C small all the time - on Claude Code the launch option `--autocompact <tokens>` (`auto`, or 100k to 1M tokens; Claude Code 2.1.285 `--help`, checked on 2026-09-30), in a session `/autocompact`.

**When the moment was missed: a cold cache.** A cold context is read ONCE at full price whatever
comes next; what is left to choose is the price list of that one read. Caches are per model, so with
a cold cache a model switch loses nothing. For a cold context of 850K tokens and a coordinator on
Claude Fable 5.1, estimated from the list prices: going on as it is writes the whole context to the
cache again, about 17 USD; compacting on the same model costs that one read at the input or at the
cache-write price plus the summary and the compact window, about 10 to 19 USD; switching the session
to a cheaper model whose window holds the whole context, compacting there and switching back costs
about 3 to 4.5 USD through Claude Sonnet 5.5 and about 4.5 to 8 USD through Claude Opus 5.5; a fresh
session from the state file costs about 1 USD and loses everything that is not on disk. Conditions:
a model with a window smaller than the context cannot do it; the weaker model writes the summary, so
give the compaction explicit instructions on what to keep and rely on the state file for the rest;
and with a WARM cache never switch - a warm read on the strong model is cheaper than any cold read.
That the host's compaction command runs on the session's current model is assumed, not measured.

**Measured, taken, estimated.** Observed: the one-hour lifetime in the coordinator sessions where it
was measured, and (2026-09-29) that Claude Code gives its agent no way to compact itself. Taken from
the vendor: the API list prices of 2026-09 and the multipliers. Estimated: the wake's turn (1K
tokens in, 300 out), the summary (10K) and the compact window (50K). Every cost and boundary in this
section is computed from these with the formulas above; none is read from a bill.

**Caveats.** Prices change: take the current ones from the vendor's pricing page (for the Claude
models, Anthropic's API pricing) and recompute with the formulas. Subscription plans meter usage
their own way; the USD figures describe the API. The numbers assume a wake every 30 minutes: a
longer interval stretches every boundary in proportion (the same number of wakes) and leaves less
margin before a one-hour lifetime ends.

---

## Setup on a new machine

Run each step, compare with the expected output, and stop and tell the user at the first
mismatch you cannot fix without them. `<codex home>` is `$CODEX_HOME` when set, else
`~/.codex`. Commands are shown for Windows PowerShell
(`powershell -NoProfile -ExecutionPolicy Bypass -File …`), which is always present on Windows; on
macOS, Linux and a real PowerShell 7 install run `pwsh -NoProfile -File …` with the same arguments.
(Wave 27c, D18) On Windows `pwsh` may be only the WindowsApps alias, which a host's sandbox can
refuse to execute (seen in the Codex CLI sandbox, 2026-09-29): use `powershell` there.

**0. Locate the scripts.** Inside this plugin's skills, `${CLAUDE_PLUGIN_ROOT}` is the
plugin directory. From a plain shell, `$P` is the newest version in the plugin cache of the host
that installed it (see "Install"), or the clone's `plugins/codex-consult`:

```powershell
$cache = "$HOME/.claude/plugins/cache/claude-codex-consult/codex-consult"          # installed with /plugin
# $cache = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "$HOME/.codex" })/plugins/cache/claude-codex-consult/codex-consult"   # installed with codex plugin
$P = (Get-ChildItem $cache -Directory | Sort-Object { [version]$_.Name } | Select-Object -Last 1).FullName
# a clone: $P = "<clone>/plugins/codex-consult"
Test-Path "$P/scripts/codex-consult.ps1"        # expect: True
$env:CODEX_CONSULT_ROOT = $P                     # what the skills' root sentence means from a shell
```

Bash: `P=$(ls -d ~/.claude/plugins/cache/claude-codex-consult/codex-consult/*/ | sort -V | tail -1)`
(or under `<codex home>/plugins/cache/...`).

**1. Shell and git.** Run the two prerequisite commands above. Without git the bridge still
runs, but the project root is the current directory and nothing binds the review to a
revision (`base_commit: "unknown"`, `fingerprint_note: "no git"`). On macOS/Linux without
`pwsh`, ask the user to install PowerShell 7.

**2. Codex CLI.** `codex --version` → `codex-cli 0.155.1` (≥ 0.148 has `codex exec fork`).
Missing: ask the user to install it (https://github.com/openai/codex). A launcher that is
not on PATH: pass `-CodexExe <path>` or set `CODEX_CONSULT_EXE`.

**3. The built-in OpenAI reviewer (ChatGPT plan).** `codex login status` →
`Logged in using ChatGPT`. Anything else: ask the user to run `codex login` in their own
terminal (it opens a browser). The built-in `openai` provider needs no config table.

**4. Check the top level of the Codex config** (`<codex home>/config.toml`). Print only the
lines the bridge cares about, never the whole file (it may hold a bearer token):

```powershell
$cfg = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "$HOME/.codex" }) 'config.toml'
Select-String -Path $cfg -Pattern '^\s*(model|model_provider|profile|model_catalog_json)\s*=', '^\s*\['
```

Expect:
- a top-level `model = "<model>"`. A run without `-Model` and without a roster uses it; if it
  is missing, that run's reviewer identity is unresolved (only `-Mode new`, never a parent
  thread). A roster entry with a `model` also avoids this.
- `model_provider` absent (Codex's default is the built-in `openai`) or naming a table.
- **no** top-level `profile = …`: a profile can change the provider, model and effort
  behind the bridge, so its presence leaves every run's identity unresolved (no
  `fork`/`resume`), even with `-Provider` and `-Model`. Ask the user before removing it.
- **no** top-level `model_catalog_json`: a global catalog replaces Codex's own and was
  observed to degrade the default `openai` model on an unrelated run ("Model metadata not
  found, fallback"). Ask the user before removing it; pass catalogs per run (step 6).

**5. Add a third-party provider (optional).** One table per provider. Take `base_url` and
`wire_api` from the provider's official Codex page; never invent an endpoint:

| Provider | Official Codex page | `base_url` on that page (read 2026-09-25) |
|---|---|---|
| z.ai GLM Coding Plan | https://docs.z.ai/devpack/tool/codex | `https://api.z.ai/api/v1` |
| Xiaomi MiMo Token Plan | https://mimo.mi.com/docs/en-US/tokenplan/integration/codex-configuration | `https://token-plan-cn.xiaomimimo.com/v1`; the user's plan console names their region (`token-plan-ams.xiaomimimo.com` exists too); pay-as-you-go: `https://api.xiaomimimo.com/v1` |
| BytePlus ModelArk Coding Plan (Dola-Seed, GLM, DeepSeek, Kimi, gpt-oss under one subscription) | https://docs.byteplus.com/en/docs/ModelArk/1928261 | `https://ark.ap-southeast.bytepluses.com/api/coding/v3` (the plan quota; `/api/v3` is pay-as-you-go) |
| Kimi Code membership (Moonshot; K3 from the Plus tier) | https://www.kimi.com/code/docs/en/third-party-tools/codex.html | `https://api.kimi.ai/coding/v1` (the membership quota; `https://api.moonshot.ai/v1` is the pay-as-you-go API) |
| Alibaba Cloud Model Studio Token Plan (Qwen 3.8, DeepSeek, GLM under one credit subscription; Singapore only) | https://www.alibabacloud.com/help/en/model-studio/codex | `https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1` with the plan's own `sk-sp-` key (a general Model Studio key or base URL bills pay-as-you-go) |

Both pages put the key into the file as `experimental_bearer_token = "<key>"`. Do not copy
that line; use `env_key`, so the key only lives in the user's environment:

```toml
[model_providers.ZAI]
name = "Z.ai GLM Coding Plan"
base_url = "https://api.z.ai/api/v1"
env_key = "ZAI_API_KEY"
wire_api = "responses"

[model_providers.mimo]
name = "Xiaomi MiMo Token Plan"
base_url = "https://token-plan-ams.xiaomimimo.com/v1"
env_key = "MIMO_API_KEY"
wire_api = "responses"
```

- The table name is the provider name everywhere: `-Provider ZAI`, roster
  `"provider": "ZAI"`, `CODEX_CONSULT_PEAK_ZAI`. It is case-sensitive; keep it short and
  ASCII.
- Plain single-line values only. An array, inline table, multi-line string, dotted key or
  sub-table inside a provider table makes that table unusable to the bridge's scanner
  (see "Reviewer identity and lineage").
- Set `wire_api` explicitly. `base_url` and `wire_api` define the endpoint fingerprint:
  changing either later (adding a `wire_api` to a table that had none counts) ends
  `fork`/`resume` onto that reviewer's older threads. `name`, comments, key order and a
  rotated key never do.
- Then ask the USER to set the variable in their own terminal and restart the coordinator's
  session (a running session - of any host - does not see a variable set after it started): Windows
  `setx ZAI_API_KEY "<key>"`; macOS/Linux `export ZAI_API_KEY="<key>"` in `~/.bashrc`,
  `~/.zshrc` or `~/.profile`.
- Verify without reading the value:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-providers.ps1" -Provider ZAI`
  → one row starting `available` with `ok: env ZAI_API_KEY set`, exit code `0` (`2`
  unavailable, `3` unknown, `1` no such provider).
- Use a model that caps-v1 declares for the host (see "Effort vocabularies (caps-v1)"): z.ai
  `glm-5.3`, MiMo `mimo-v2.6-pro`, and so on. Any other model there needs `-NativeEffort`
  on every run, which a roster entry cannot supply.

**6. Per-run model catalogs (MiMo-style providers).** Codex has no built-in catalog for
MiMo models. Save the catalog file that the MiMo Codex page links to as
`<codex home>/model-catalogs.json` (ask the user to download it, or download it with their
consent) and pass it per run, never globally: in the roster entry,
`"codex_config": ["model_catalog_json=~/.codex/model-catalogs.json"]`, or on one command,
`-CodexConfig model_catalog_json=~/.codex/model-catalogs.json`. z.ai's page also suggests
a global `~/.codex/models.json`; the z.ai route has been used live without one, and if one
is needed it goes per run the same way. The MiMo endpoint rejects `--output-schema`;
caps-v1 already sends the schema in the prompt for those hosts, so there is nothing to
configure for that.

**7. Write the reviewer roster** at `<codex home>/codex-consult-roster.json`, first choice
first, with the expensive reviewer marked `weighty`:

```json
{
  "roster_version": 1,
  "reviewers": [
    { "provider": "openai", "model": "<the ChatGPT-plan model>", "panel": "weighty" },
    { "provider": "ZAI", "model": "glm-5.3" },
    {
      "provider": "mimo",
      "model": "mimo-v2.6-pro",
      "codex_config": ["model_catalog_json=~/.codex/model-catalogs.json"]
    }
  ]
}
```

A `weighty` entry joins a `-Panel` run only on the weighty purposes. A `light` entry
(2026-10-07) joins on the other purposes and on a weighty one only stands in for an entry of its
label that does not run. Two models of one plan split the work that way, e.g. Kimi Code:

```json
    { "provider": "kimi", "model": "k3", "context_tokens": 256000, "panel": "weighty" },
    { "provider": "kimi", "model": "kimi-for-coding", "context_tokens": 1000000, "panel": "light" }
```

`k3` takes the architecture decisions, `kimi-for-coding` the code reviews and checkpoints and a
weighty brief too large for `k3`'s 256K window - and one weighty panel never seats both, so the
plan's 5-hour window is not spent twice. `"auth": "none"` is
only for a table with neither `env_key` nor a bearer token (a local endpoint); it does
nothing for a table that names an `env_key`. Every field and rule: "Reviewer roster and
panel". An invalid roster refuses **every** run, dry runs included, so validate it at
once: `codex-providers.ps1` must not exit `1`. To use another file, the user sets
`CODEX_CONSULT_ROSTER=<path>` (the file must exist); `CODEX_CONSULT_ROSTER=none` switches
the roster off.

(Wave 29) An entry of the `claude` engine carries `"auth": "subscription"` (the default) or `"api-key"` and a `model` from the engine's table: "Engines (wave 29)".

**8. Peak windows (optional).** If a plan bills more at peak hours, the user sets
`CODEX_CONSULT_PEAK_<PROVIDER>`, e.g. `setx CODEX_CONSULT_PEAK_ZAI "Mon-Fri 14:00-18:00 +08:00"`,
with the schedule taken from the plan's own page (never guess one). Format and
`-OffPeakOnly`: "Peak-hour windows".

**9. Verify.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-providers.ps1"
```

Expect this shape, exit `0`:

```
codex config: C:\Users\<you>\.codex\config.toml
endpoint health: <repo>\.collab (0 task ledgers, 0 consultations), read at 2026-09-26 10:40 - the ledgers of THIS repository
VERDICT    PROVIDER  ROSTER  KIND     ENDPOINT                                  CREDENTIALS                  EFFORT                    LAST FAILURE
available  openai    1       builtin  builtin:openai                            ok: Logged in using ChatGPT  openai (any model)        -
available  ZAI       2       custom   https://api.z.ai/api/v1                   ok: env ZAI_API_KEY set      zai (11 declared models)  -
available  mimo      3       custom   https://token-plan-ams.xiaomimimo.com/v1  ok: env MIMO_API_KEY set     mimo (5 declared models)  -
roster: C:\Users\<you>\.codex\codex-consult-roster.json -> would select openai :: <model>
availability: all 3 reviewers available
```

`missing: env MIMO_API_KEY not set` means the variable is not visible to this process (not
set, or the coordinator's session was not restarted). Health (the `LAST FAILURE` column, usage limits)
comes from the ledgers of the repository you run in - the `endpoint health:` line names them -
so a fresh repository shows none.
Then, inside a git repository:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" `
    -Task setup-check -Prompt "Reply with one sentence." -DryRun
```

Expect exit `0` and, among other lines: `DRY RUN - nothing was executed and no file was
written.`, `reviewer    : <provider> :: <model> (provider from …, model from …; …)`,
`preflight   : available (ok: …)`, `Roster: <path> - position 1 of 3`,
`transport   : output-schema (…)` or `prompt-only (…)`,
`format retry : 1 attempt if the reply is not valid JSON`, `mode        : new`. Repeat
with `-Provider ZAI -Model glm-5.3` (and each other provider) to check every reviewer.

**10. First live consultation.** It spends a little of the reviewer's quota, so ask the
user first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" `
    -Task setup-check -Purpose chore -ReplyName smoke `
    -Prompt "List the top-level files of this repository, one line each."
```

Expect `codex-consult: usable reply - <provider> :: <model>, mode new, thread <uuid>
(source: events), wall <n> s`, exit `0`, and the files
`.collab/setup-check/handoffs/01-codex-smoke.md` and `.collab/setup-check/sessions.json`.

**11. Record the setup** in the project's `state.md` (or whatever notes file the project
keeps): the providers wired and their models, the roster path, order and panel weights,
the env variable NAMES (never values), the peak variables, the `codex-providers.ps1`
verdicts with the date, and anything left unavailable and why.

**Ask the user / never do.**

| Ask the user to… | Never… |
|---|---|
| install Codex CLI or PowerShell 7 | create, print, echo, log, commit or paste an API key, or read one back from the environment |
| run `codex login` | put a key into `config.toml` (`experimental_bearer_token`), the roster, a brief, `state.md` or a commit |
| set `<NAME>_API_KEY` (`setx` or the shell profile), then restart the coordinator's session | set `model_catalog_json` or `profile` at the top level of `config.toml` |
| confirm the plan's region, models and peak schedule | invent a base URL, a model name or a peak schedule |
| agree before the first live consultation | pass `-SkipPreflight` to get past a real refusal; `fork`/`resume` a thread under another provider or model; delete `.consult.lock` |

---

## Components in this plugin

| Component | What it does |
|---|---|
| skill `consult-codex` (`/codex-consult:consult-codex <task-id> <ask>`) | the consultation process: when to consult, reconciling findings, the brief, the one command, verifying and recording findings, rating the consultation, the panel and the council rules |
| skill `setup-providers` (`/codex-consult:setup-providers [provider]`) | wiring reviewers on a machine: Codex login, `[model_providers.*]` tables with `env_key`, per-run catalogs, the `agy` engine (install, the user's sign-in, `agy models`, roster entries), the `muse` engine (install, `muse login` with the file credential backend, never an API key, the contributor vs standard model), the roster, peak windows, verification |
| skill `coordinate` (`/codex-consult:coordinate`) | (0.5.0, wave 27, R19) the coordinator's rules: one objective per worker, a fresh worker per wave with its state on disk, polling a state file instead of a blocking wait (a watchdog wake below the host's prompt-cache lifetime), compaction at wave boundaries, never redoing a worker's work, English to reviewers, the live-member rule, rating every consultation, asking the operator before going on without a required reviewer, the bridge's own means (`-Detach`, `-Status`, `-Wait`, `-Kick`), the worker tier contract, then the means per host. Host-neutral; `codex-consult.ps1 -Explain coordinate` prints it where a host has no skills |
| agents `agents/opus-worker.md`, `sonnet-worker.md`, `haiku-worker.md` | (wave 27) the worker tiers of the `coordinate` skill as agent files for the host that reads them (namespaced `codex-consult:<tier>-worker`): deep reasoning, default execution, cheap read-only recon (no Edit/Write tool); the model is the tier ALIAS `opus`, `sonnet`, `haiku` - never a version |
| examples `install/examples/codex-agents/*.toml` | (wave 27) the same three tiers as agent files for Codex CLI (`name`, `description`, `developer_instructions`, no model key) - EXAMPLES the operator may copy to `~/.codex/agents/`; the plugin never installs or writes them |
| `README.md` (the plugin directory) | (wave 27c, D17) a short index for an installed plugin: what it is, the three skills, `-Explain` for a host without skills, and the URL of this repository README |
| hook `SessionStart` (`hooks/hooks.json` → `scripts/codex-consult-hook.ps1`) | at every session start (`startup`, `resume`) in a project where the plugin is enabled - on a host that runs the plugin's hooks; elsewhere the one-liner of "Hooks on each host" - adds TWO lines to the agent's context: (wave 27) the second is always `codex-consult: coordinator rules - skill codex-consult:coordinate (or codex-consult.ps1 -Explain coordinate); telemetry: on` - (wave 28) ending with the telemetry switch, `on` or `off` ("Telemetry (on by default)"); the first is the availability line (0.5.0, the line `codex-providers.ps1 -Short` prints): what is OUT, per roster entry, with the reset in local time and a rounded relative hint, then the count - `codex-consult: out - openai :: gpt-6-astra (until Sun 20:35, in 2d 10h), gemini :: * (until Sun 21:30, in 2d 11h); 9 of 11 reviewers available`, or `codex-consult: all 11 reviewers available`. Every entry is judged with the roster walk's own verdict (credentials, the launch invariant, the endpoint health of THIS repository's ledgers: an auth failure, a usage limit with a reset ahead, one without a reset for 60 minutes after it was hit); the entries of one endpoint group that share the state collapse to `<label> :: *`; nothing is cut. An agy entry's sign-in is not checked here (no network call): `not checked - gemini :: * (sign-in not checked); 7 of 11 reviewers available, 2 out, 2 not checked` - unless THIS repository's ledgers hold a usable agy reply from the last 60 minutes; a muse entry's local check and billing guard run (`meta :: <model> (refused: META_API_KEY is set)`). Without a roster: the providers (`... (no reviewer roster)`). `codex-consult: codex CLI not found on PATH - follow the setup-providers skill ...` when Codex is missing; `codex-consult: reviewer check failed - <why>` for an unusable roster or config. It runs `codex-providers.ps1 -Short -Json -NoNetwork`: nothing written, exit code always 0, about one second (`codex login status`), timeout 30 s; `pwsh` when present, else `powershell`. Disable it with the plugin (the host's plugin switch, e.g. `/plugin disable codex-consult`) — hooks have no per-plugin switch |
| script `scripts/codex-telemetry.ps1` | (0.5.0, wave 28, R17) the telemetry's sender (`-Flush`, started detached by the bridge after a ledger commit), the operator's complaint (`-Complain`) and the state (`-Status`) - "Telemetry (on by default)" |
| evals `evals/` (`claude plugin eval <plugin dir> --ablation none --allow-tools Bash` — the `--allow-tools Bash` operator grant is REQUIRED for the two cases that run the bridge; they are silently downgraded without it) | the install test: two cases a fresh agent must pass with only this plugin loaded — `dry-run-consultation` (reach the bridge through the `consult-codex` skill, run `-DryRun` for task `eval-smoke`, report the fixed first line, the preflight and reviewer lines, write nothing) and `providers-listing` (use `codex-providers.ps1`, one verdict per provider, no invented verdict). Graders: `tool_used`, `regex` on the trace, `file_exists: false`, an `llm` rubric. A machine with no usable reviewer still passes when reported honestly. The third case `command-plan` (tag `readonly`) needs no shell grant and runs everywhere: the agent must produce the exact dry-run command and the files a real run writes, from the skill, without executing anything. Shell-granted cases need a sandbox backend: Linux/macOS have one; on Windows the eval runner refuses to run a shell tool unconfined (`sandbox required but unavailable`), so there run `--case command-plan` only. Results land in `evals/results/` (ignored by git) |

Per-provider alias skills a user may keep in `~/.claude/skills/` (say, one that maps "ask
GLM" to `-Provider ZAI -Model glm-5.3`) are optional personal conventions, not part of
the plugin; nothing here needs or installs them.

---

## Usage

Three steps per consultation: write a brief, run one command, read and record. The
`consult-codex` skill is the procedure; this section and the ones below are the reference.
`$P` is the plugin directory (setup step 0); inside the plugin's skills the same commands
use `${CLAUDE_PLUGIN_ROOT}`. On macOS, Linux and a real PowerShell 7 install replace `powershell
-NoProfile -ExecutionPolicy Bypass -File` with `pwsh -NoProfile -File`; on Windows keep
`powershell` (always present - `pwsh` may be only the WindowsApps alias a host sandbox refuses).

**1. Write the brief** to `.collab/<task>/handoffs/<NN>-<prefix>-<slug>.md`. `<NN>` is the next
free two-digit prefix; you and the bridge share one sequence, so the directory reads as a
conversation. `<prefix>` is the coordinator's brief prefix (wave 27): `claude` by default - the
name every install's ledgers already use - or your host's own slug through `-BriefPrefix` /
`CODEX_CONSULT_BRIEF_PREFIX`; the bridge's reply prefixes `codex`, `agy` and `muse` are refused
(the dry run prints `brief prefix: <prefix> (<source>) - ...`). Start from `templates/brief-framing.md` (framing, decision, stuck) or
`templates/brief-review.md` (checkpoint, core-contract, acceptance, diff-review). One page:
the question, the task state (on a continued thread, the delta since the last review plus
the CURRENT invariants, because history is not an authoritative current-state record),
evidence with `file:line`, alternatives weighed, numbered questions Q1…Qn, a word cap. The
bridge never writes briefs. `-Prompt` is a one-line ask; do not paste the brief into it.

**2. Run one command** from inside the project:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" `
    -Task my-task -Purpose diff-review `
    -Brief .collab/my-task/handoffs/03-claude-invalidation.md `
    -Prompt "Judge the invalidation strategy." -ReplyName invalidation
```

- `-Task` and `-ReplyName` are slugs (letters, digits, `.`, `-`, `_`).
- Leave `-Mode` out. It defaults to `fork` when a thread of this run's reviewer lineage is
  known, else `new`. `fork` is also right when another client (Codex CLI, the desktop app)
  may still append to that thread; use `-Mode resume` only when nothing else writes to it.
  `-Thread <uuid>` picks a specific parent of the same lineage.
- One specific reviewer: `-Provider <name> -Model <model>`. Every available roster
  reviewer: `-Panel`.
- A big review (0.5.0): leave `-TimeoutSec` out - the purpose sets it (diff-review 2400 s,
  acceptance 3600 s) - and pass `-Range <from>..<to>`: the bridge measures the range once, tells
  the reviewer its size and warns when the timeout is short for it. A reviewer the bridge kills
  on its timeout gets ONE continuation turn on its thread; if that fails too, its work so far is
  salvaged into `handoffs/<NN>-codex-<slug>.partial.md` and the summary prints the command that
  resumes the thread ("Timeouts, the continuation and the partial reply").
- When a call misbehaves, rerun it with `-DryRun` first: it prints the argv, the resolved
  launcher, reviewer, preflight, roster pick, transport, the prompt that would go on stdin,
  every path and the planned ledger entry, and writes nothing.
- A long consultation you do not want to wait for (0.5.0): add `-Detach` - the call returns in
  seconds, the consultation runs in the background, and `-Status -Id <id8>` / `-Wait -Id <id8>`
  bring you back to it ("Non-blocking consultation").

Expect on success (exit `0`):

```
codex-consult: usable reply - ZAI :: glm-5.3, mode fork, thread <uuid> (source: events), wall 41.2 s
verdict    : HOLD - <verdict_reason>
findings   : 1 blocker, 2 major, 0 minor, 1 note -> F04-1..F04-4 in findings.json
reply file : <repo>\.collab\my-task\handoffs\04-codex-invalidation.md
```

Exit `1` with `codex-consult: <message>` and nothing written is a **refusal** (bad
arguments, an unusable roster or config table, a preflight refusal, a live previous run,
`-OffPeakOnly`). Exit `1` with `codex-consult: failed: … (wall <n> s)` is a **bridge
failure**: the run was launched and its reply file (with the stderr tail) and ledger entry
were still written.

**3. Read, verify, record.** The bridge writes, per consultation:

| File | Content |
|---|---|
| `handoffs/<NN>-codex-<slug>.md` | header lines (`Date`/author, `Reviewer:`, `Preflight`, `Roster:`, `Effort:`, peak warning, `Recovery record:`, `Invocation:` with the argv, parent and result thread, brief and reviewed revision, drift warnings, `Bridge outcome:`/wall/tokens, (0.5.0) `Timeout:`, `Timeout continuation:`, `Partial reply:`, `Provider failure:`, `Structured reply:`, verdict warning, `Format repair:`, `Raw event stream:`), `---`, the reply **verbatim**, then (structured runs) the rendered findings, prior findings, verdict, blockers, unproven scenarios and first-run checklist; after a format repair, the original prose |
| `handoffs/<NN>-codex-<slug>.reply.json` | the reviewer's last message, byte for byte (structured runs) |
| `handoffs/<NN>-codex-<slug>.events.jsonl` | the raw event stream |
| `handoffs/<NN>-codex-<slug>.original.md` | the first-turn prose, only after a format repair |
| `handoffs/<NN>-codex-<slug>.continue.events.jsonl` | (0.5.0) the event stream of the timeout continuation, only after a timeout kill of the main turn |
| `handoffs/<NN>-codex-<slug>.partial.md` | (0.5.0) only when a turn was killed on its timeout and no continuation answered (or a denial retry or format repair was killed): the reply's header, then per turn every agent message and reasoning text of its event stream in order and its tool calls, then `killed at <t> s of <T> s; thread <id> - continue with <arguments>` |
| `findings.json` | the findings tracked by id, and the `ratings` (only written once there is something to record) |
| `sessions.json` | the ledger; one entry appended per consultation |

Verify every finding yourself (open the location, run the build or test) before acting
on it, then move its status with `codex-findings.ps1` and rate the consultation with
`-Rate` (see "Findings: ids, status, ratings"). Commit the whole `.collab/` tree next to
the code; `.gitignore` excludes only the bridge's runtime files (`.consult.lock`,
`.consult.write.lock`, `.consult.pending.json`, a panel member's `.consult.pending-<NN>.json`, and
(0.5.0) a detached run's status file and log, `.consult.detached-*`, and (wave 26c) a kick file
and its acknowledgement, `.consult.kick-*`) - add the same patterns to your project's
`.gitignore`. A fabricated example of the layout is in `examples/`.

---

## Review purposes

`-Purpose` selects the prompt paragraph and the default effort and word cap; `-Effort` and
`-MaxWords` override either.

| `-Purpose` | Effort | Max words | Timeout (0.5.0) | Asks the reviewer to… |
|---|---|---|---|---|
| *(none)* | high | 700 | 900 s | answer the brief with no preset framing |
| `framing` | high | 700 | 1800 s | surface options the brief did not list; challenge the framing |
| `decision` | high | 700 | 1800 s | rank the alternatives, name the deciding factor and each one's failure mode |
| `checkpoint` | medium | 500 | 900 s | verify the CURRENT invariants the brief claims against the code as it is now |
| `core-contract` | xhigh | 900 | 2400 s | cover the interfaces, recovery/persistence paths and state machines named in the brief: states, transitions, the failure at each transition |
| `acceptance` | high | 900 | 3600 s | decide ACCEPT/HOLD/REJECT, with blockers, unproven scenarios and an observable first-run checklist |
| `diff-review` | high | 700 | 2400 s | an adversarial read: what breaks, what is not covered, what the tests do not prove |
| `stuck` | xhigh | 700 | 2400 s | find the angle the coordinator is missing; question assumptions before proposing fixes |
| `chore` | low | 400 | 600 s | a bounded search or extraction task: facts with file paths and line numbers, quotes of what was found, what was not; no verdict, no findings |

`acceptance` and `diff-review` take a verdict of `ACCEPT`/`HOLD`/`REJECT`; every other
purpose, and no purpose, takes `ADVISE`. The timeout is the main turn's when `-TimeoutSec` is
not given (an explicit `-TimeoutSec` always wins; see "Timeouts, the continuation and the partial
reply"). `chore` is a plain-text reply like `-Raw` (no
schema, no findings bookkeeping, no format repair): give grunt work to a cheap reviewer
with it. The word cap applies to the prose (`reply_markdown`) only; findings are never cut
to fit it. The weighty purposes (`framing`, `decision`, `core-contract`, `acceptance`,
`stuck`) decide which roster entries join a panel.

---

## Timeouts, the continuation and the partial reply (0.5.0)

A timeout never throws the reviewer's work away. **The timeout** is the main turn's wall-clock
limit; past it the bridge kills the reviewer's process tree. Without `-TimeoutSec` the purpose
sets it:

| Purpose | Timeout |
|---|---|
| `chore` | 600 s |
| `checkpoint`, *(none)* | 900 s |
| `framing`, `decision` | 1800 s |
| `diff-review`, `core-contract`, `stuck` | 2400 s |
| `acceptance` | 3600 s |

An explicit `-TimeoutSec` always wins; the dry run (`timeout     : 2400 s (the default of
purpose diff-review; -TimeoutSec overrides); ...`), the handoff header (`Timeout:`) and the
ledger (`timeout_sec`, `timeout_source` `purpose` or `explicit`) say which applied; a `-Panel`'s
members inherit the resolved value. (Wave 26b, D11) A roster entry's `timeout_sec` (an integer
>= 60) replaces the purpose's default for that reviewer - as a panel member or a single run of
the entry - with `timeout_source` `roster` (its continuation budget follows it unless
`-ContinueSec` is given; an explicit `-TimeoutSec` still wins for all); the panel's line lists
the exceptions: `Timeout: 3600 s per member (the default of purpose acceptance); #7 alibaba ::
qwen3.8-max 1200 s (roster); ...`.

**The stall cut (wave 26b, D12 - ROADMAP R18).** A reviewer can hang without dying: its process
lives, its event stream stops. `-StallSec <s>` (default 900; a roster entry's `stall_sec`
overrides it for that reviewer, an explicit `-StallSec` wins; `0` = off) stops a main turn whose
event stream - codex's `--json` items, agy's stream-json, muse's MSP records, read line by line
while the turn runs - produced no output for that long while its process lived. (Wave 26c, D3)
ANY growth of the stream resets the timer (bytes - a line still being written counts), and the
timer is SUSPENDED while a tool call is in flight: codex's `item.started` of a
`command_execution`, `mcp_tool_call` or `web_search` item until its `item.completed`, an agy
`tool` step in state `ACTIVE` until it reports another state, a muse task proposed as `tool.*`
until its `task.lifecycle` end - a member running one long command is never cut; the timeout
stays the hard bound. It is stopped like a timeout: the process tree is killed, the one
continuation turn follows ("Your previous turn was stopped after no output for N s outside a
tool call. ..."), then the salvage; `bridge_outcome` `failed: stalled after N s without an event
(process tree killed)` when no continuation saved it; ledger `stall {seconds, last_event}` (the
threshold, and when the last event line was seen - `null`: none since the start). A panel passes
the resolved value to each member. (Wave 27c, D6; wave 28b, D12) A tool call cannot suspend the
timer for ever, and no completion event is needed to end the suspension: while a tool call is open
the stream must still GROW - once it has not grown for 2 x `-StallSec` (no floor; the 1800 s of
wave 27c are gone) the suspension ends and the cut follows, naming the open call - `failed: stalled
after N s without an event - no output for S s (a tool call open for M s: codex command_execution
item_9)` (agy: `agy tool step <n>`, muse: `muse tool.<kind> <task id>`). A tool call whose stream
keeps growing (its progress lines) is never cut. (D5) The stream is read
bounded: only the new bytes are scanned for line ends, the unfinished line is kept up to 1 MiB - a
longer one is skipped to its end, never parsed, and counted (`warnings[]`: `oversized_lines: N ...`,
once per run); the timer's activity is the byte count, whatever parses.

**The kill, confirmed (wave 27c, D16).** After a process tree kill the bridge checks that the root
process exited and that every descendant it enumerated is gone. Where the children cannot be
enumerated (a restricted host - the Codex CLI sandbox denies process inspection, 2026-09-29) it falls
back to `taskkill /PID <root> /T /F` and checks the root again. (Wave 28b, D14) The descendants are
enumerated with CIM on Windows; elsewhere with `pgrep -P`, else `ps -A -o pid=,ppid=`, else the
`/proc/<pid>/stat` files - only when none of them works is a kill unconfirmed for that reason.
(Wave 28c, D9 / F42-5) `pgrep`'s exit 1 (no match) is an empty child set; any other non-zero exit, a
call that does not end within 5 s, output that is not a pid, or a `pgrep` that cannot run is a failed
enumeration - never an empty child set - and the next method (`ps`, then `/proc`) is tried.
Each descendant's start time is read at the enumeration, and the check after the kill counts a
descendant as alive only while a process with its pid AND that start time exists: a pid the
system handed to another process meanwhile is no survivor (and is never killed). (Wave 28c, D8 /
F42-4) No pid-only identity: a descendant whose start time cannot be read (at the enumeration or
at the kill - another user's process, say) is neither killed by its pid nor counted as gone - the
bridge leaves it alone and the kill is `not confirmed: start time of pid <n> unreadable` (the
outcome `(kill not confirmed: start time of pid <n> unreadable; pid <n> may still run)`, naming
that pid). (Wave 28d, D5 / F49-1) When the same kill also leaves survivors, both groups are named -
the outcome `(process tree killed; <n> processes survived: pid <a>, <b>; start time of pid <u>
unreadable; pid <u> may still run)` and the warning `kill not confirmed (<turn>): <n> processes survived:
pid <a>, <b>; start time of pid <u> unreadable; pid <u> may still run - check them, and stop them by
hand if they do`; (wave 28e, E1 / F54-1) the recovery record keeps that group too (`unverified[]`
beside `survivors[]`), so the next run checks it again. (Wave 28e, E18 / F27-1) A kill that left NO
survivor but such a group keeps the record as well (state `survivors`, `survivors: []` beside
`unverified[]`): the outcome ends `(kill not confirmed: <why>; pid <u> may still run; the next run for
this task is refused until it exits)`, and the next run checks that pid again as below. (Wave 28e,
E23 / F30-1) A kill that is NOT confirmed and names no pid at all - the children could not be enumerated
and the tree-kill fallback failed - keeps the record too (state `survivors`, `survivors: []`,
`unverified: []`, `kill_unconfirmed: "<why>"`): its tree is unknown, and the next run releases it only
after a clean scan for its processes (below). On Windows `taskkill /PID <root> /T /F`, which walks the root's live tree itself, still
runs. The outcome says `(process tree
killed)` ONLY when the kill is confirmed; otherwise `(kill not confirmed: <why>; pid <n> may still
run)`, the ledger's `kill_confirmed` is `false`, `warnings[]` says `kill not confirmed (<turn>): ...`
- check that pid and stop it by hand - and NO continuation turn follows (`timeout_continue.outcome`
`not attempted: the kill of the main turn was not confirmed (...)`): an orphaned reviewer may still
hold its thread ("the thread already has an active writer"). Such an orphan also still holds the
output pipe of a caller that waits for the bridge's output (a coordinator's blocking shell call
returns only when the orphan exits) - one more reason to start runs in such a host with `-Detach`.

**Member control - stopping one member: `-Kick` (wave 26b, D10).** From another shell, `codex-consult.ps1 -Task
<task> -Kick -Member <NN>` (a foreground panel: the parent's members each poll
`<task>/.consult.kick-<NN>` while their engine turn runs) or `-Kick -Id <id8> -Member <NN>` (a
detached run: the member must be one of its running members) stops that member: its engine's
process tree is killed, its partial output salvaged (`.partial.md`), it is recorded `failed:
stopped by the operator (-Kick)` with `provider_failure.class` `operator` (never an endpoint's
outage), no continuation follows, and the panel goes on with the others (`-Status` shows the
member `failed: stopped by the operator (-Kick)`). (Wave 26c, D1) The member checks the kick
file before its wait loop, on every poll and ONCE MORE after its process exited, and acknowledges
it: `<task>/.consult.kick-<NN>.ack` (`stopped` - its turn is being stopped; `late` - its turn had
already finished: it records `kick_late: the member had already finished (...)` in `warnings[]`
and its outcome is unchanged); the kick file is removed. (Wave 27c, D1) Per REQUEST: the kick file
is a small record `{id, when, pid}` written atomically (a temporary file, then a rename that never
replaces) - a caller that finds one present JOINS it (takes its id) and never overwrites it; the
acknowledgement holds the request's id and the result (`stopped` or `late`); each caller waits for
an acknowledgement with ITS id; only the caller that created the request removes it after reading
it (a joiner never), and no caller removes one before writing. An acknowledgement older than 60 s
that is not the caller's is swept by any later `-Kick` and by the next run start of that number -
so two operators kicking one member at once both get the same, true answer. A kick addresses the
RUN of a member, not one turn (D2): found before or during the FORMAT REPAIR it cancels the repair
and the first reply stays usable (`warnings[]`: `kick: the operator stopped the format repair
(-Kick); the first reply stands, not converted`); found before or during the TIMEOUT CONTINUATION
it cancels the continuation and the timeout outcome with its salvage stays (`warnings[]`: `kick:
the operator stopped the timeout continuation (-Kick); the timeout outcome and its salvage stay`).
`-Kick` waits up to 10 s for the acknowledgement. Exit `0` acknowledged, `1` no such member or not
running (a kick file of that number is removed), `3` no acknowledgement in time (the kick file
stays: the member takes it at its next poll; the next run of that number removes a stale one), `4`
refused.

**The continuation.** When the bridge kills the MAIN turn on its timeout and the turn's thread
is known (codex: its `thread.started`; agy: the conversation of its init event; muse: its session
stream), the provider and the CLI still hold the conversation - Codex keeps the whole rollout of
a killed thread. The bridge then runs ONE more turn on that thread (codex `exec ... resume
<thread>` with the main turn's options, `--output-schema` included; agy `--conversation`; muse
`--session-id`) with the prompt `Your previous turn was stopped by a time limit after N s. Do not
start over and do not read more files than you must: finish now and output your final answer in
the required format.`, within `-ContinueSec` s (default: the smaller of the timeout and 900 s;
`0` = off). A usable reply is ingested exactly like a first-turn reply: `bridge_outcome`
`usable reply (after a timeout continuation)` (a usable reply everywhere - the endpoint health,
the scoreboard, a panel's exit code), ledger `timeout_continue {thread, wall_seconds, outcome,
events, usage}`, the summary line `continued  : the main turn was killed at <t> s of <T> s; one
continuation turn on thread <id> answered in <w> s`. No continuation (`outcome` `not attempted:
<why>`) when the thread is unknown, when processes survived the kill (they may still write to
it), (wave 27c, D16) when the kill was not confirmed, when files changed during the run (`files changed during the run (the working tree | the
collab directory | the brief | artifact(s))` - one tree check for every engine, a codex
`-Sandbox workspace-write` run included; 0.5.0 wave 24c: the working tree by file CONTENTS - a
commit or a moved HEAD meanwhile, such as the coordinator committing the collab files, is no
change and only noted as `revision_moved`), when the killed turn's own evidence names a quota,
billing or auth failure (wave 24c: its structured evidence first - the engine adapter's class,
the event stream's error, the adapter's texts, a provider error payload on stderr - then only the
DIAGNOSTIC lines of its stderr: ERROR (or FATAL) level, or an HTTP status with its message; a
known informational engine message - codex's models refresh, logged at ERROR level with the whole
models list in it, its fallback-metadata notice - never counts, and neither does a plain line that
merely contains a word such as auth, billing or 429; all of it through the one classifier -
`ERROR: Insufficient balance: ...` or `Payment required (402)` stops it as surely as a 429), or
with `-ContinueSec 0`. The launch guard (muse: the
billing guard re-reads `auth.json` and the environment) runs right before EVERY start of a turn -
the main turn too (0.5.0, wave 24b) - a refusal: `failed: refused before launch: ...`. On a
prompt-only transport (MiMo, undeclared hosts) the continuation prompt carries the reply format
and the JSON Schema again. The continuation COUNTS only when its reply passes the checks a first
reply passes - a valid reply object, else substantive prose (the format repair then converts
it; `-Raw` and `chore`: substantive prose); a `Done.` is `failed: not a usable reply - ...` and
the salvage of the killed turn is kept - (wave 24c) and so is the rejected reply itself: the
partial file adds it after the turns under `## continuation reply (rejected: <why>)`, and the
outcome names it (`...; its text is kept in handoffs/<NN>-<engine>-<slug>.partial.md under
"continuation reply (rejected)"`). A continuation that FAILED (a 429, an auth error, its own
timeout) supplies the run's `provider_failure` - its class and `retry_after` - so the endpoint
health sees a limit hit in the continuation. Never more than one per consultation. A `-Panel`
member continues inside its own process; its kill guard grows by `-ContinueSec`.

**Residual (codex):** the continuation gate of a codex run does not see the collab directory - by
design, the codex engine never snapshots the collab directory (it cannot tell its own writes from
others'), so only the working tree, the brief and the artifacts stop a codex continuation; the agy
and muse engines compare the whole collab directory too (wave 24c, the ruling on F08-2).

**The partial reply.** When a turn was killed on its timeout - the main turn without a usable
continuation, the continuation, a denial retry, a format repair; (wave 26b) or stopped by the
stall cut or the operator's `-Kick`; and (wave 26b, D15) whenever ANY run fails while one of its
event streams holds at least one agent message, reasoning text or tool call - a provider failure
mid-run (a 429 after retries, a 401/403 quota, a network error), a denial, a tree-check failure;
then the main turn's heading says `it ended at <t> s: <why>` and the footer `the run ended:
<why>; thread <id> - continue with ...` instead of `killed at`; a stream without content (a 401
on the first request) leaves nothing - the bridge writes
`handoffs/<NN>-<engine>-<slug>.partial.md`: the reply's header, then per turn (`## Turn 1 - the
main turn - killed at 902.3 s of 900 s`, `## Turn 2 - the timeout continuation - ...`) every agent
message and reasoning text of its event stream in order and its tool calls (the command line of a
shell command), then the footer ``killed at <t> s of <T> s; thread <id> - continue with `-Task
<task> -Mode resume -Thread <id> -Purpose <p> [options] -Prompt "finish your review"` `` - with
every replay-relevant option the run was given (wave 24b): `-TimeoutSec` (when explicit),
`-ContinueSec` (when not the default), `-Effort` / `-NativeEffort`, `-MaxWords`,
`-SchemaTransport`, `-CodexConfig`, `-Artifact` (the resolved paths), `-Range`, `-Sandbox` (when
not read-only), `-MaxModelSteps`, `-FormatRetry 0`, `-DenialRetry 0`, `-OffPeakOnly`,
`-CodexExe` / `-EngineExe`, and (wave 24c) `-ReplyName` (when given; a panel member's own
`<name>-<provider>`) and `-SkipPreflight` (a run that started unchecked resumes unchecked instead of
being refused by the check it skipped). The ledger names it
(`partial_reply`), the handoff header too (`Partial reply:`); `bridge_outcome` stays `failed:
timeout after <T> s (process tree killed)` - the run did not produce a usable reply. The summary
prints the file and the exact command:

```
codex-consult: failed: timeout after 900 s (process tree killed) (wall 902.3 s)
continued  : failed: timeout after 900 s (process tree killed) (in 901.0 s) - thread <id>
partial    : <repo>\.collab\my-task\handoffs\05-codex-review.partial.md (killed at 902.3 s of 900 s (the main turn), 901 s of 900 s (the timeout continuation); thread <id> - continue with `...`)
resume     : powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>\scripts\codex-consult.ps1" -Task my-task -Mode resume -Thread <id> -Purpose diff-review -Range a1b2c3d..HEAD -Prompt "finish your review"
```

**To resume** a killed reviewer, run that command: the reviewer continues its own thread with
everything it read already in context (a resumed Codex acceptance that had been killed at 1800 s
answered in 148 s, 94% of its 14.2M input tokens cached). With a roster `-Thread` fixes the
reviewer; without one the command names `-Provider`, `-Model` (and `-Engine`). `-Thread` also
takes the conversation of an agy or muse run the bridge killed (a candidate only, since no
result verified it; its ledger entry names the partial reply), and the resumed turn must come
back on it. A timed-out panel member is resumed the same way, not re-asked from scratch.

**`-Range <from>..<to>`** (diff-review and acceptance only): `git diff --shortstat <range> --`
runs once; the prompt says ``Review range: `<range>` - the range changes N files, M lines (I
insertions, D deletions; git diff --shortstat). Plan your reading for its size.``, the ledger
records `range {spec, files, insertions, deletions, lines}`, and a range of more than 1500
lines with a timeout below 2400 s WARNS (console `WARNING:`, the handoff header's `Warnings:`,
ledger `warnings[]`): `a range of M lines with a T s timeout: pass -TimeoutSec or a reading
plan in the brief`. A range git does not know (or an argument that could be read as an option)
is refused before anything starts, and so is (wave 24b) a single revision: only `base..head` or
`base...head` - `git diff <revision>` would measure the WORKING TREE against it, a size that
changes while the review runs. A `-Panel` measures it once for all members.

**Rating a failed consultation** (`codex-findings.ps1 -Rate`): rate `no` only when the failure
was the reviewer's (a refusal, an invented finding, prose it could not convert); skip the rating
when the bridge's timeout or a plan limit killed it - resume it instead.

---

## Non-blocking consultation (0.5.0): -Detach, -Status, -Wait

A consultation holds the caller's turn for its whole wall clock - a parallel acceptance panel
for 15-30 minutes. With `-Detach` the call returns within seconds and the consultation runs in
a background process; you come back to THAT question with `-Status` or `-Wait` when you are
ready. Nothing else changes: the background is an ordinary run (task lock, recovery records,
numbering, members, kill guard, commit, the ledger), so everything the blocking run writes it
writes too.

```powershell
# 1. park it (a single run or -Panel; any other option as usual)
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" `
    -Task my-task -Panel -Purpose acceptance -ReplyName acceptance -Detach `
    -Brief .collab/my-task/handoffs/07-claude-acceptance.md
```

Expect (exit `0`), three lines - write the id and the brief into the task's `state.md`:

```
Detached 3f2a9c1b: a review panel of 3 of 3 roster entries, at once (purpose acceptance, timeout 3600 s per member) - it runs in the background (detach id 3f2a9c1b-...; budget 5100 s).
status file: <repo>\.collab\my-task\.consult.detached-3f2a9c1b.status.json (console output: <repo>\.collab\my-task\.consult.detached-3f2a9c1b.log)
come back  : codex-consult.ps1 -Task my-task -Status -Id 3f2a9c1b (exit 0 done and usable, 1 a failure, 2 still running); -Wait -Id 3f2a9c1b waits until it is done (default: its budget, 5100 s)
```

```powershell
# 2. look (never blocks; reads status files only)
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" -Task my-task -Status -Id 3f2a9c1b
# 3. or wait for it (checks every 2 s; the default limit is the run's budget)
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" -Task my-task -Wait -Id 3f2a9c1b -WaitTimeoutSec 540
# (wave 26b) stop ONE member that hangs (its handoff number, as -Status shows it); the rest go on
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" -Task my-task -Kick -Id 3f2a9c1b -Member 03
```

`-Status` prints, per detached run of the task (newest first; `-Id` picks one by its id or a
prefix of it), its state, one line per member and - once done - the summary block the run
printed, verbatim (a panel: its `Panel <id8>: ...` block; a single run: its outcome lines from
`codex-consult: <outcome>` to `events file:` - the reply itself is in the reply file and in the
log):

```
detached 3f2a9c1b (review panel, purpose acceptance, reply name acceptance): running since 2026-09-26T21:40:02+02:00 (12 min), 2 of 3 members finished
  detach id 3f2a9c1b-..., started 2026-09-26T21:40:02+02:00, pid 8508 on HOST; budget 5100 s
  #1 openai :: gpt-6-astra - running (n=5, handoff 08)
  #2 ZAI :: glm-5.3 - usable: usable reply (n=6, handoff 09, 311.4 s)
  #3 mimo :: mimo-v2.6-pro - failed: timeout after 3600 s (process tree killed) (n=7, handoff 10, 3790.2 s)
  log: <repo>\.collab\my-task\.consult.detached-3f2a9c1b.log
```

| Exit | `-Status` / `-Wait` |
|---|---|
| `0` | every run asked about is done and exited 0 (every member usable) |
| `1` | a run is done with a failure (exit 1), its background died, it never started, or its status file is unusable |
| `2` | a run is still running (or starting, or runs on another host) - the worst state decides: 2 > 1 > 0 |
| `3` | `-Wait` only: still running after `-WaitTimeoutSec` (default: the run's `budget_sec`); the run was not touched |
| `4` | the query is refused: `-Id` matches no run or several (`-Id 'abcd' matches 2 detached runs of task 't': abcd5678, abcd1234; give more of the id.`), or an option that does not go with it |

- **What `-Detach` checks before it returns** (a refusal: exit `1`, nothing written, nothing
  started): everything `-DryRun` checks, plus what a real run refuses before it takes the task
  lock and a dry run only reports - a missing launcher of an engine that will run, an ACTIVE
  recovery record of the task, the preflight (credentials, a recorded auth failure or usage
  limit), the roster; a missing brief or artifact; (a single run) a `.cmd` launcher's `%` hazard. Not checked:
  the task lock itself and the time-dependent health/peak selection - a benign window: if
  another consultation takes the task in between, the background is refused and its status says
  so (`done, exit 1`, the refusal line as its summary). `-Detach` is refused with `-DryRun`,
  `-Status`, `-Wait` and the internal `-PanelSpec`.
- **The background** is `<the same PowerShell> -File codex-consult.ps1 -Task <t> -CollabDir
  <absolute> -DetachId <guid>`, started in the caller's working directory with `-Brief`,
  `-Artifact` and `-CollabDir` made absolute (the ledger's `artifacts[].path` of a detached run
  is therefore absolute); the other arguments travel in the status file's `starting` record
  (PowerShell CLIXML, no command-line quoting). Windows: `cmd.exe /d /v:off /s /c` through
  ShellExecute, hidden, with the output redirected - it holds none of the caller's handles, so
  the calling tool's capture ends when the foreground exits (a path with `%` is refused: cmd
  would expand it); macOS/Linux: `/bin/sh -c 'exec nohup <pwsh> ... </dev/null >log 2>&1'`. Its
  first action is the self-report (`running`, its pid, start time and host); its console output
  (stdout and stderr, UTF-8) goes to the log; a try/finally around the run writes the final
  status (`done`, the exit code, the summary) on every exit path - a refusal after the start
  (`Stop-WithError`), an error, a normal end.
- **Liveness.** A status file that is not `done` is judged by its background's pid AND start
  time on this host: gone = `died - its background process (pid N) is gone without a final
  status ...` (its recovery records are judged by the next run of the task as usual - the
  members' records are consumed, the task lock was released with the process); `starting`
  without a pid reads "starting" for 60 s, then `never started` (see its log) - (wave 26) a
  judgement made afresh at every read: a background that starts late still reports, and the run
  then reads `running`. A background on another host is never judged (`its liveness cannot be
  checked from this host`).
- **The final status** (wave 26): the background's final write is retried (3 attempts, 250 ms
  apart); when it still fails, the background prints `... its status file could not be made
  final - the result exists only in this log (<log>) ...` and exits `6` (the status file keeps
  its last state, and `-Status` judges the run by its background).
- **Budget** (`budget_sec`, `-Wait`'s default limit): per endpoint group ceil(members / limit)
  x the member kill guard (timeout + format repair + denial retry + continuation + 60 s write
  lock + 120 s), the largest group; with `-PanelConcurrency` also ceil(N / cap) x the guard; the
  larger, plus 120 s. A single run is one group of one member (no purpose: 2400 s). Pass a
  `-WaitTimeoutSec` below your tool's own command timeout and repeat `-Wait`, or poll `-Status`.
- **Where it shows.** `codex-findings.ps1 -List` prints one line per detached run of the task that
  is not done (`detached 3f2a9c1b: running since <t> (<s>), 2 of 3 members finished (codex-consult.ps1
  -Task my-task -Status -Id 3f2a9c1b)`, or the died / starting / never-started / other-host
  wording); the SessionStart hook adds one phrase for the repository (`; 1 detached consultation
  running (task my-task)`, `; 2 detached consultations finished (tasks a, b)` - finished in the last
  24 h - or `; detached consultations: 1 running (task a), 1 died (task b)`).
- **Retention.** Status and log files stay (they are small and git-ignored by the
  `.consult.detached-*` pattern). `-Status -Prune` - the one writing form of `-Status` - deletes
  those of runs that are done or died and were last written more than 7 days ago (a never-started
  run only when its log was not written in those 7 days either); running runs and runs on another
  host stay. (wave 26) An UNREADABLE status file (empty, unparseable, without an id or a known
  state) - which counts as a failure in every `-Status`/`-Wait` of the task, in `-List` and in the
  hook - is deleted too once the FILE was last written more than 7 days ago; for a younger one
  `-Status` prints the command that removes it by hand (`Remove-Item -LiteralPath '<status>',
  '<log>'`).
- **The prompt** (wave 26): an inline `-Prompt` of a detached run is written to
  `<task>/.consult.detached-<id8>.prompt.txt` (git-ignored like the log); the `starting` record's
  `args` name only that file (`PromptFile`), so a run that never starts leaves its prompt text in
  that file, not in the status record. The background reads the file and removes it; `-Prune`
  removes a left-over one with the run's other files. (`-Brief` travels as a path, as always.)
- One consultation per task still holds: while a detached run holds the task, a second one (and
  `codex-findings.ps1 -Id/-Status/-Rate`) on that task is refused on the task lock.

The status file (`<task>/.consult.detached-<id8>.status.json`, replaced atomically; the
foreground writes it once, `starting`, before the background exists; from then on only the
background writes it):

| Field | Meaning |
|---|---|
| `status_version` | `1` |
| `id`, `id8` | the detach id (a guid) and its first 8 hex digits (the file name) |
| `task`, `kind` | the task; `run` or `panel` |
| `state` | `starting` (the foreground's record, no pid) -> `running` (the background's self-report) -> `done` |
| `exit` | the run's exit code (`null` until done) |
| `started`, `updated`, `finished`, `wall_seconds` | the foreground's start, the last write, the end, the wall clock |
| `pid`, `start_time`, `host` | the background process (its start time as UTC round trip) and host - liveness is judged by all three |
| `budget_sec` | the budget above |
| `purpose`, `reply_name`, `brief` | as given (`brief` absolute) |
| `members[]` | `{position (roster position; 1 without a roster), lineage, state, outcome, wall_seconds, n, handoff (NN), reply}`; `state`: `pending`, `running`, `usable`, `failed`, `skipped` (a roster-skipped entry; a member never started - `not started: <why>`), `killed` (by the panel's guard), `blocked` (`-PanelConcurrency 1` after surviving processes), `commit_blocked`, `orphan` (stopped inside its commit); `outcome`: the panel's status phrase (its bridge outcome, `killed by the panel after ...`, ...) |
| `summary` | the summary block the run printed; a refusal: its `codex-consult: <message>` line |
| `log` | the console log `<task>/.consult.detached-<id8>.log` |
| `args` | the `starting` record only: the background's parameters (base64 of UTF-8 PowerShell CLIXML; wave 26: an inline `-Prompt` as `PromptFile`, the path of its prompt file); dropped by the self-report |

---

## The ledger

`.collab/<task>/sessions.json` holds `task_id`, `cwd` (the repository root) and
`codex: {tool, consults[]}`. Every run that got past the refusals adds one entry, failed
runs included, so the ledger is a history and not a success log; `consults` stays sorted by
`n` (0.4.x wave 21: a parallel panel's members commit in any order, each entry is inserted at
its place, so the highest `n` of a lineage is always its newest thread). A refusal (see
"Usage") writes nothing. A full entry, fields in the order the bridge writes them:

```json
{
  "n": 4,
  "when": "2026-09-22T11:24:27+02:00",
  "purpose": "diff-review",
  "topics": [],
  "role": "",
  "consult_id": "8f6a1e2d-…",
  "reviewer": {
    "provider": "ZAI",
    "provider_source": "-Provider",
    "model": "glm-5.3",
    "model_source": "-Model",
    "engine": "codex",
    "harness": "codex-cli 0.155.1",
    "provider_fingerprint": "e3b0c44298fc…",
    "provider_config": { "base_url": "https://api.z.ai/api/v1", "wire_api": "responses" },
    "identity_note": ""
  },
  "lineage": "ZAI :: glm-5.3",
  "coordinator": { "provider": "openai", "model": "gpt-5.1", "engine": "codex", "host": "codex", "host_by": "markers", "source": "explicit", "in_roster": true, "unresolved": null },
  "preflight": "ok: env ZAI_API_KEY set",
  "preflight_warning": "",
  "roster": null,
  "panel": null,
  "parent_thread": "01a0c839-48ba-7182-8d15-fdc13dd17193",
  "thread": "01a0c86e-5193-7d70-a644-63a5c3f224b3",
  "thread_source": "events",
  "thread_candidate": "",
  "mode": "fork",
  "mode_fallback": null,
  "command": "codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort=\"max\" -c model_provider=\"ZAI\" -o <temp> --output-schema <schema> fork 01a0c839-… -",
  "child_env_scrubbed": ["CODEX_CI", "CODEX_SANDBOX_NETWORK_DISABLED", "CODEX_SESSION_ID", "CODEX_THREAD_ID"],
  "brief": ".collab/my-task/handoffs/03-claude-invalidation.md",
  "range": null,
  "prompt_chars": 3412,
  "reply": "handoffs/04-codex-invalidation.md",
  "reply_json": "handoffs/04-codex-invalidation.reply.json",
  "events": "handoffs/04-codex-invalidation.events.jsonl",
  "partial_reply": "",
  "model": "glm-5.3",
  "effort": "max",
  "effort_requested": "xhigh",
  "effort_sent": "max",
  "effort_mapping": "zai-v1",
  "effort_caps": "caps-v1",
  "effort_confirmed": null,
  "max_words": 700,
  "sandbox": "read-only",
  "timeout_sec": 2400,
  "timeout_source": "purpose",
  "continue_sec": 900,
  "extra_config": [],
  "extra_config_source": "",
  "peak": false,
  "peak_schedule": "Mon-Fri 14:00-18:00 +08:00",
  "peak_source": "env",
  "peak_evaluated_at": "2026-09-22T11:24:27+02:00",
  "structured": true,
  "schema": "consult-reply v1",
  "schema_transport": "output-schema",
  "schema_transport_source": "caps-v1",
  "validation_error": "",
  "format_retry": null,
  "denial_retry": null,
  "timeout_continue": null,
  "stall": null,
  "kill_confirmed": null,
  "base_commit": "4e9cc4f0…",
  "reviewed_revision": "4e9cc4f + uncommitted",
  "tree_sha256": "9c2a…",
  "tree_sha256_after": "9c2a…",
  "tree_changed_during_review": false,
  "revision_moved": null,
  "changed_files": 3,
  "brief_sha256": "7b31…",
  "brief_sha256_after": "7b31…",
  "brief_changed_during_review": false,
  "fingerprint_note": "collab dir '.collab' excluded (2 entries); ignored files excluded; untracked file modes not recorded; submodules not recursed",
  "artifacts": [],
  "artifacts_changed_during_review": false,
  "tree_check": null,
  "bridge_outcome": "usable reply",
  "provider_failure": null,
  "warnings": [],
  "verdict": "HOLD",
  "verdict_reason": "one blocker in the invalidation path",
  "findings": { "blocker": 1, "major": 2, "minor": 0, "note": 1 },
  "finding_ids": ["F04-1", "F04-2", "F04-3", "F04-4"],
  "prior_findings": [{ "id": "F02-3", "status": "fixed" }],
  "unchecked_prior_blockers": [],
  "usage": { "input_tokens": 18400, "cached_input_tokens": 12000, "output_tokens": 900, "reasoning_output_tokens": 400 },
  "wall_seconds": 11.1,
  "finished_at": "2026-09-22T11:24:39+02:00",
  "commit_wait_ms": 0
}
```

This is the only place field meanings are listed; other sections refer to them by name.

| Field | Values and meaning |
|---|---|
| `n` | consultation number in this task; never reused (allocation: "Write order and atomic stores") |
| `when` | local start time, ISO 8601 with offset |
| `purpose` | the `-Purpose`, `""` without one |
| `topics` | (0.5.0, wave 26) the `-Topic` slugs (lowercase, deduplicated), `[]` without; copied onto a rating, scored by a routed panel ("Companions") |
| `role` | (0.5.0, wave 26) the role the reviewer was given (`-Role`, or a panel's `-Roles`/`-Role`), `""` without one ("Companions") |
| `consult_id` | a fresh guid per run; also the prompt's last line `Consultation id: <guid>` and the key that verifies a rollout-file thread id |
| `reviewer.provider` / `reviewer.provider_source` | the provider that answered; how it was decided: `-Provider`, `config`, `codex default`, `roster`, `-Thread` or `unknown` |
| `reviewer.model` / `reviewer.model_source` | the model that answered (`unknown` when unresolvable); `-Model`, `config`, `roster`, `-Thread` or `unknown` |
| `reviewer.engine` | (0.4.0) the CLI that carried the run: `codex`, `agy` or (wave 23) `muse` (see "Engines"); an entry without it is `codex`. A thread never mixes engines |
| `reviewer.harness` | `codex-cli <version>` (`agy-cli <version>` or `agy-cli (version unknown)` for agy; `muse-cli <version>` for muse, from `.muse-version` next to the launcher, else `muse --version`); audit only, never compared (Wave 29) Claude: `claude-cli <ProductVersion>` from the native `claude.exe` file metadata (e.g. `claude-cli 2.1.285.0`), else `claude --version` (an npm shim), else `claude-cli (version unknown)`. |
| `reviewer.provider_fingerprint` / `reviewer.provider_config` | SHA-256 of the canonical endpoint (`""` when identity is unresolved); `{base_url, wire_api}` of the table (no `wire_api` key when the table has none), or `{builtin: "openai"}`; for the agy engine SHA-256 of `cc-engine-v1\|agy` and `{engine, launcher}`; for the muse engine SHA-256 of `cc-engine-v1\|muse` and `{engine, launcher, credential_mechanism}` (the sign-in's `providers.meta.mechanism`, e.g. `oauth`; `null` when it cannot be read) (Wave 29) For the claude engine: SHA-256 of `cc-engine-v1|claude|<auth>|<model family>` (e.g. `cc-engine-v1|claude|subscription|opus`) and `{engine, launcher, credential_mechanism, auth_method, api_provider}` - `credential_mechanism` is the roster `auth`, `auth_method` and `api_provider` are the `authMethod` and `apiProvider` of `claude auth status` (never the account's e-mail or organisation). |
| `reviewer.identity_note` | why identity is unresolved, or how it was derived (e.g. a user-defined `[model_providers.openai]` table); `""` otherwise |
| `lineage` | `<provider> :: <model>`, display only; matching never compares this string |
| `coordinator` | (0.5.0, wave 27; right after `lineage`) who asked: `{provider, model, engine, host, host_by, source, in_roster, unresolved}`. `provider`/`model`/`engine` from `CODEX_CONSULT_COORDINATOR` (`<provider> :: <model>` [` [<engine>]`], a roster position `#<n>`, or a label), else `null` - (wave 27c, D9) a RESOLVED triple, through the rules of a seated reviewer: `#<n>` and a label take the model of their roster entry, else the model the bridge would run (the Codex config's), a lineage its entry's engine, else `codex`; `model` stays `null` for a label whose model cannot be told (two roster models of it); `host` the coordinator's agent host, a HINT only, in this order - `codex` (`CODEX_SESSION_ID`/`CODEX_THREAD_ID`, looked at first), `zcode` (wave 27c, D20: ANY `ZCODE_` variable), `claude-code` (`CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`, `AI_AGENT` starting with `claude-code`), else the install path of the running script - (wave 28b, D11) ANCHORED: only a script UNDER a host's plugin directory of this home, `~/.claude/plugins/cache/` (`claude-code`), `~/.codex/plugins/cache/` or `<codex home>/plugins/cache/` (`codex`), `~/.zcode/cli/plugins/cache/` (`zcode`), `~/.qwen/extensions/` (`qwen-code`); a path that merely contains such a name gives no hint -, else `unknown` (e.g. Kimi Code from a clone); `host_by` `markers`, `path` or `none`; `source` `explicit` (the variable is set), `inferred` (a host hint only) or `none`; `in_roster` (D11) `true`/`false` - `false`: no roster entry matches, said on the console, never refused - or `null` (no roster, no identity); `unresolved` (D12) `null`, or the `#<n>` that named no roster position here (a warning; the run goes on). Resolved once per run: a panel member and a detached run carry their run's. NOT the `host` of the lock, recovery and status records, which stays the machine name |
| `preflight` | `ok: <credential detail>` or `skipped` (`-SkipPreflight`); any other verdict refuses the run |
| `preflight_warning` | a recent usage limit that did not refuse the run, else `""` |
| `roster` | `null` without a roster; else `{path, position, skipped: [{provider, model, engine, reason}], applied: []}`, `applied` naming what the roster entry supplied (`engine`, `model`, `codex_config`; wave 26b: `timeout_sec`, `stall_sec`); (wave 26b, D16) a skip `reason` may be `brief too large for this reviewer's context (est. N of M tokens)` |
| `panel` | `null` outside a panel; else `{id, position, of, members: [{provider, model, state: "run"\|"skipped"\|"not-picked", reason}], concurrency, limits, asked, started, usable, routing}` - `concurrency` (0.4.x wave 21) the most members the panel's plan let run at once, `limits` `{"<provider label>": n}` the members of that label's endpoint at a time (see "The panel"); (wave 26) `asked` the size requested (wave 26b, D2: the purpose's size or `-PanelSize` as asked - `-PanelAll` and `stuck`: every eligible member; before 26b it was the seats), `started` and `usable` how many members were started and gave a usable reply - written into every member's entry when the panel ends (`null` until then, and when the panel run died first); `routing` `{mode, order, fallback, seed, nonce, nonce_source, size, size_asked, size_source, reserve, eligible: [{position, lineage, lab, lab_source, score, basis, ratings, required}], picked: [{slot, position, lineage, lab, rule}], explored: [lineage], required: [lineage]}` ("Companions") - (wave 26b) `size_asked` the size requested beside the `size` seated (fewer eligible warns `panel size reduced: asked k, eligible m`), `reserve` the seats the lab reserve took (the `lab-*` rules); `roles_note` (wave 26b, D4, after `routing`) `""`, or why the `-Roles` went by the greedy rank order (no assignment gives every role a willing member) |
| `parent_thread` / `thread` | the thread forked or resumed (`""` for `new`); the resulting thread (`""` when not verified) |
| `thread_source` | `events`, `rollout (verified by consultation id)` or `unknown` |
| `thread_candidate` | an unverified rollout uuid (agy: a conversation id the run could not verify - a failed resume's new conversation, the init id of a run without a result) kept for diagnosis only; never a parent |
| `mode` / `command` | `new`, `fork` or `resume`; the full argv as one string (prompt on stdin) |
| `child_env_scrubbed` | (0.5.0, wave 27; right after `command`) the NAMES of the coordinator's host markers that no engine child got (sorted; never a value; `[]` when none was set): `CODEX_SESSION_ID`, `CODEX_THREAD_ID`, `CODEX_CI`, every `CODEX_SANDBOX*`, `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`, `AI_AGENT`; (wave 27b) what a host session hands its children besides - `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_BRIDGE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION`, `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDE_CODE_MESSAGING_TOKEN`, `CLAUDE_CODE_SESSION_ATTENDED`, `CLAUDE_CODE_EXECPATH`, `CLAUDE_PID`, `CLAUDE_EFFORT` - so a reviewer never inherits the coordinator's session channel (its messaging socket and token); (wave 27c, D21) every `ZCODE_*` - the whole prefix: read inside a Z Code session on 2026-09-29 (desktop 3.14.3), its shell tool carries `ZCODE_APP_VERSION`, `ZCODE_BASE_URL`, `ZCODE_BUILD_COMMIT_ID`, `ZCODE_BUILTIN_PROVIDER_CONFIG_FILE`, `ZCODE_DESKTOP_CONTEXT_PROMPT_ENABLED`, `ZCODE_ENV`, `ZCODE_PERSONAL_PROVIDER_CONFIG_FILE`, `ZCODE_PROCESS_LABEL`, `ZCODE_RG_BINARY`, `ZCODE_RUNTIME_ENV`, `ZCODE_UGREP_BINARY`, `ZCODE_WINDOWS_APP_INSTALL_DIR` (two of them point at the operator's provider configuration files; no reviewer engine reads a `ZCODE_` variable). Every engine child - the main turn, a denial retry, a format repair, the continuation, the detached background, the launcher probes, (wave 28) the telemetry sender - is started without them; every other variable (`CODEX_HOME`, the provider keys, `PATH`, `CODEX_CONSULT_*`) is kept. EXACT names for the `CLAUDE_CODE_` ones, never that whole prefix: the operator's own settings (`CLAUDE_CODE_USE_BEDROCK` and the like) must still reach an engine, and `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA` stay. (wave 27c, D3) The hide is transactional: a marker that cannot be removed puts every removed one back and refuses the start (`bridge failure: host markers could not be hidden (<name>: <why>)`); a launcher probe whose start-info cannot be scrubbed runs with the markers hidden from the bridge's own environment, else it is skipped - "not checked" and a warning (D4) |
| `mode_fallback` | (wave 26b, D16; after `mode`) `null`, or `{from: "fork"\|"resume", to: "new", reason}` when a reviewer with a roster `context_tokens` would have continued a thread whose last recorded context plus this prompt exceeds 80% of its window - the run started a new thread instead, and its prompt names the reviewer's previous reply file |
| `brief` / `prompt_chars` | the brief path (`""` without one); the prompt length |
| `range` | (0.5.0) `null` without `-Range`, else `{spec, files, insertions, deletions, lines}` of `git diff --shortstat <spec>` |
| `reply` / `reply_json` / `events` | handoff paths relative to the task directory (`reply_json` is `""` for plain-text runs) |
| `partial_reply` | (0.5.0) `""`, or `handoffs/<NN>-<engine>-<slug>.partial.md` when a turn was killed on its timeout (the salvage; "Timeouts, the continuation and the partial reply"); (wave 26b) also after the stall cut, the operator's `-Kick`, and (D15) any failed run whose event streams hold an agent message, reasoning text or tool call |
| `model` / `effort` | kept for 0.2 readers and `-Stats`: the resolved model; `effort` equals `effort_sent` |
| `effort_requested` / `effort_sent` / `effort_mapping` / `effort_caps` / `effort_confirmed` | the preset, `-Effort` or `-NativeEffort` value; the value put into argv (`null` for agy: the tier is part of the model id); `openai`, `zai-v1`, `mimo-v1`, `model-tier` (agy), `muse-v1` (muse) or `native`; the capability-table version (`caps-v1`); always `null` (Codex does not report the effort it used) |
| `max_words` / `sandbox` | the resolved word cap; `read-only` or `workspace-write` (agy: `read-only (requested; enforced by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; agy --sandbox restricts the terminal only)`; muse: `read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads)`) |
| `timeout_sec` / `timeout_source` / `continue_sec` | (0.5.0) the main turn's timeout; `purpose` (the purpose's default), `explicit` (`-TimeoutSec`) or (wave 26b, D11) `roster` (the roster entry's `timeout_sec`); the timeout continuation's budget (`0` = off) |
| `extra_config` / `extra_config_source` | the `-CodexConfig` or roster `codex_config` items as sent (expanded); `""` (none), `-CodexConfig` or `roster` |
| `context_window` | (wave 28b, D15; after `extra_config_source`) `null`, or `{tokens, auto_compact_limit, items}` for a codex reviewer whose roster entry has `context_tokens`: the window n, 0.8 n, and the `-c` items the bridge added to every turn - `model_context_window=<n>`, `model_auto_compact_token_limit=<0.8 n>` (an item `-CodexConfig` or `codex_config` already sets is left to the operator's value); agy and muse take no such option - there the key guards only the start |
| `peak` / `peak_schedule` / `peak_source` / `peak_evaluated_at` | `true`, `false` or `null` (no schedule) at launch; the schedule; `env`, `env (CODEX_CONSULT_NOW)` or `none`; when that decisive check ran |
| `structured` / `schema` | whether a valid structured reply was ingested; `consult-reply v1`, or `""` for `-Raw` |
| `schema_transport` / `schema_transport_source` | `output-schema`, `prompt-only` or `native` (agy: `--json-schema`; muse: `--output-schema`); `caps-v1` or `-SchemaTransport` (`""` for plain-text runs) |
| `validation_error` | `""`, or every validation message joined with `; `, plus a format-repair note |
| `format_retry` | `null` (no repair attempted, or off), else `{attempted, reason, succeeded, thread, wall_seconds, usage, drift, original, events, schema_transport}` - `events` (0.4.0) the repair turn's event stream, handoffs-relative, when one is kept (agy: `handoffs/NN-agy-<slug>.repair.events.jsonl`; muse: `handoffs/NN-muse-<slug>.repair.events.jsonl`), else `null` (codex: its repair stream is a temp file); `schema_transport` (wave 23b) the repair turn's transport: codex `prompt-only` (its repair never passes `--output-schema`), an engine the main turn's - `native`, or `prompt-only` with no schema flag and the schema in the repair prompt |
| `denial_retry` | (0.4.0, agy; always `null` for muse, which has no denial retry) `null` (not attempted), else `{attempted, reason, succeeded, thread, wall_seconds, usage, events}`: the one extra turn after a run that produced nothing because a tool was auto-denied (see "Engines"); `events` = that turn's event stream (`handoffs/NN-agy-<slug>.denial-retry.events.jsonl`, `null` when no turn ran) |
| `timeout_continue` | (0.5.0) `null` unless the main turn was killed on its timeout; else `{thread, wall_seconds, outcome, events, usage}` of the ONE continuation turn - `outcome` `usable reply`, `failed: <why>` or `not attempted: <why>` (then `wall_seconds` 0, `events` and `usage` `null`); (wave 24c) a reply the checks rejected: `failed: not a usable reply - <why>; its text is kept in handoffs/<NN>-<engine>-<slug>.partial.md under "continuation reply (rejected)"` |
| `stall` | (wave 26b, D12; after `timeout_continue`) `null`, or `{seconds, last_event}` when the main turn was stopped by the stall cut (`-StallSec`, the roster's `stall_sec`): the threshold, and when the last event line was seen (`null`: none since the start). (wave 27c, D6; wave 28b, D12) A tool call in flight suspends the cut only while the stream grows: 2 x `-StallSec` without growth end the suspension, and the outcome says `... - no output for N s (a tool call open for M s: <the open call>)`; (D5) the stream is read with a bounded carry of 1 MiB - a longer unfinished line is skipped and counted (`oversized_lines: N ...` in `warnings[]`) |
| `kill_confirmed` | (wave 27c, D16; right after `stall`) `null` when no process tree was killed; `true` when every kill of the run was CONFIRMED (the root exited and every known descendant is gone); `false` when one was not - the children could not be enumerated (a restricted host, e.g. a sandbox that denies process inspection) and `taskkill /PID <root> /T /F` could not confirm the tree, or processes survived. An unconfirmed kill is never told "(process tree killed)": the outcome says `(kill not confirmed: <why>; pid <n> may still run)`, `warnings[]` says `kill not confirmed (<turn>): ...`, and NO continuation turn follows it (the orphan may still hold the thread) |
| `base_commit` … `fingerprint_note` | revision binding: see "Binding a review to a revision"; (wave 24c) `tree_changed_during_review` compares file contents, and `revision_moved` (after it) is `null`, or `"<old base_commit> -> <new>"` when HEAD moved during the run - informational, never a tree change by itself |
| `artifacts` / `artifacts_changed_during_review` | `[{path, sha256, sha256_after}]` per `-Artifact`; whether any changed during the run |
| `tree_check` | (wave 26b, D9; after `artifacts_changed_during_review`) `null` for codex (no check); for an engine `{outcome, files}`: `clean`, `warned` (muse - write-disabled by the bridge's flags: a change is not the reviewer's, the reply stays usable, `warnings[]` says so) or `failed` (agy - its sandbox does not block writes); `files` the changed paths (the working tree's, the collab directory's as shown, `brief`, the artifacts) |
| `bridge_outcome` | `usable reply`, (0.5.0) `usable reply (after a timeout continuation)` or `failed: <why>`: only whether the bridge worked |
| `provider_failure` | `null` on success, else `{class, kind, code, message, when, retry_after, hint}` (see "Preflight and endpoint health"; wave 26b: class `operator` for a run stopped by `-Kick` - no endpoint's fault, never read as an outage): (wave 24c) `kind` `burst` - a 429 that names no usage window or quota, out for 10 minutes - or `""`; `hint` the operator's next step, decided when the failure is classified (`""`, or `context too long for this plan/model - ...`) |
| `warnings` | (0.4.0) notices of the run - a `-Provider` label that names several roster entries (any engine), agy's denial notice and its `warning:` stderr lines that came with a usable reply; (wave 26) a panel's floor warning and a routed panel's `routing: no lab known for ...`; (wave 26b) `panel size reduced: asked k, eligible m`, (wave 26c, D5) `panel size raised: asked k, required r` (the required reviewers outnumber the size asked: `panel.routing.size_source` `required`, `size_asked` the request; the dry run's `Routing:` line says `; asked k`), `roles: no assignment gives every role a willing member ...`, and a muse run's tree-check change (`the collab directory changed during the run (<files>) - muse ran write-disabled, the change is not the reviewer's`); (wave 27) `coordinator: <lineage> is the coordinator's own model (CODEX_CONSULT_COORDINATOR) - a second opinion from the coordinator's own model, not an independent one` when the reviewer's resolved identity is the coordinator's; (wave 28b) `test mode is ON: test hooks are honoured` (D10: every run with `CODEX_CONSULT_TEST_MODE=1` - a harness) and `machine-wide health not updated at the commit (<cause>); the record is kept in the journal; a retry follows the commit` (D13); (wave 28c) `health journal: <n> unreadable line(s) kept in <file>` (D10) and `the reviewer compacted its context <n> time(s) - the reply may rest on a summary of the brief` (D11) - (wave 28c, D7) a telemetry event that could not be spooled is no longer here: its final attempt comes after the commit, so it is said on the console and in a detached run's status record only; `[]` when none |
| `verdict` / `verdict_reason` | `ACCEPT`, `HOLD`, `REJECT`, `ADVISE`, or `""` (unavailable or invalid); one sentence |
| `findings` / `finding_ids` | severity counts of the new findings; their ids |
| `prior_findings` | the reviewer's reports on earlier ids: `{id, status}` with `fixed`, `still-open`, `not-checked` or `unknown-id` |
| `unchecked_prior_blockers` | open prior blockers the reviewer did not check while answering `ACCEPT` |
| `usage` / `wall_seconds` | token counts from the event stream (agy: `cache_read_tokens` -> `cached_input_tokens`, `thinking_tokens` -> `reasoning_output_tokens`, plus `total_tokens`; muse: `null` - its records carry no usage); wall time |
| `compactions` | (wave 28c, D11 / F43-3, F44-6; right after `usage`) how often the reviewer compacted its context during the run, as its ENGINE REPORTED it in the event streams of the run's turns (`Get-CompactionCount`: a `context_compacted` / `compacted` / `thread.compacted` event, or an `item.completed` whose item is a `context_compaction` / `contextCompaction` / `compaction` - the names of the Codex CLI's protocol): a number n > 0 - and the warning `the reviewer compacted its context <n> time(s) - the reply may rest on a summary of the brief`; `unknown` for a member with `context_tokens` when none was reported - the installed codex-cli 0.155.1's `exec --json` stream reports no compaction at all (its item types, read from the binary: agent_message, reasoning, command_execution, file_change, mcp_tool_call, collab_tool_call, web_search, todo_list), so "none seen" is not "none happened"; `null` otherwise. The prompt of a member with `context_tokens` (and a `-Brief`) names the brief again as its last line before the consultation id: ``Before you answer, re-read the brief: `<path>`.``; (wave 28d, D7 / F50-2) without a brief file (an inline `-Prompt`) the one-line ask itself is repeated there - `Before you answer, re-read the ask: <the ask, whitespace folded to one line>` (an ask longer than 300 characters - 500 before wave 28e - is cut there and points to the top of the prompt: `... (cut here: the whole ask is at the top of this prompt)`); (wave 28e, E4 / F54-4) a multi-line ask is not folded into one line: its FIRST line is repeated whole (whitespace inside it folded, cut at 300 characters the same way) and the count of its remaining non-blank lines follows - `Before you answer, re-read the ask: <first line> (+<n> more lines)`. (D8 / F48-4) The line is bridge text: no hash of the prompt exists, and the line takes no part in the context estimate that decides whether a fork or resume continues its thread (`mode_fallback`) |
| `engine_run` | (wave 23) `null` for codex; for an engine `{turns, max_model_steps, msp_schema_version}`: the engine turns started (the main turn, a denial retry, a format repair - each muse turn spends one Muse Code subscription prompt), `-MaxModelSteps` as sent (`null` when not), the MSP `schema_version` of a muse stream (`null` for agy); right after `compactions` (wave 28c; before: `usage`) (Wave 29) For the claude engine `{turns, max_model_steps, msp_schema_version (null), auth, init_tools, mcp_servers, permission_mode, api_key_source, model_resolved, other_models, permission_denials, denied_tools, rate_limit, quota_mark, cost_usd, child_env_allowed, switched_off}`: the init event's proof of every turn, the ONE resolved model of the thread, the raw most-severe `rate_limit_event` info, (wave 29b, E15) `quota_mark` - `null`, or the `provider_failure` a failed quota turn would record, when a rejecting `rate_limit_event` came beside a successful result (the endpoint health reads it as a quota failure right after the reply) -, `total_cost_usd` (local only; notional on a subscription), the NAMES (never values) of the environment variables the child received, and what R22 switched off. |
| `finished_at` | (0.4.x wave 21) when the entry was committed (`when` is the reviewer's start). The endpoint health's "newest wins" orders by it (older entries: `when` + `wall_seconds`), ties by `n` - a panel's members finish in any order |
| `commit_wait_ms` | (0.4.x wave 21) how long the commit waited for the write lock because another commit of the task held it (`0`: it was free); the console says `write lock : waited N ms for another commit of this task` when it waited |

`bridge_outcome` and `verdict` are separate on purpose: a delivered `HOLD` is a success of
the bridge. Legacy entries: the pre-0.2.0 field `outcome` (now `bridge_outcome`) is left
as written and only its `thread` is read; entries written before 0.3.0 have no `reviewer`,
`lineage` or later fields, and that absence marks them as unknown provenance (see
"Reviewer identity and lineage"); a pre-wave-7 `lineage` in the slash form
(`ZAI/glm-5.3`) still matches, since matching compares `reviewer.provider` and
`reviewer.model`.

(0.5.0, wave 28, R17) The telemetry event ("Telemetry (on by default)") is built from the
COMMITTED entry and reads only these fields: `reviewer.engine`, `reviewer.provider`,
`reviewer.model` (else `model`), `purpose`, `bridge_outcome`, `provider_failure.class`,
`wall_seconds`, `usage.input_tokens` / `cached_input_tokens` / `output_tokens`, `findings`,
`structured`, `format_retry.attempted`, `denial_retry.attempted`, `timeout_continue.outcome` and
`panel.of`. The ledger gets no telemetry field: whether a consultation was reported is the run's
switch (`-Telemetry`, `CODEX_CONSULT_TELEMETRY`), and what left the machine is in the spool until
it is delivered.

---

## Structured reply, findings and format repair

Unless `-Raw` or `-Purpose chore`, the bridge asks the reviewer for one JSON object per
`schemas/consult-reply.schema.json` (schema v1) and validates it locally.

**Reply fields.** `schema_version` (`"1"`), `verdict`, `verdict_reason`, `reply_markdown`
(the full prose answer), `findings[]`, `prior_findings[]`, `unproven[]`,
`first_run_checklist[]`. Each finding: `severity` (`blocker`/`major`/`minor`/`note`),
`locations[]` (`{path, line}`, empty when not tied to a place), `claim`, `trigger`,
`evidence[]` (`{kind, reference, observation}`, what the reviewer already checked; `kind`
is `read-code`/`ran-command`/`inferred`/`assumed`), `verification` (what you run next to
confirm it), `remedy`, `supersedes[]` (ids of earlier findings it replaces).

**Output contract.** Every structured prompt OPENS with this paragraph, before the ask and
the brief:

> FINAL OUTPUT CONTRACT: your ENTIRE final message must be exactly one bare JSON
> object (schema_version "1") - no code fence, no text before or after it. The
> Markdown answer lives only inside its reply_markdown string; each defect goes in
> findings[]. A prose final message cannot be ingested, however good the answer is.

**Schema transport** (per host, declared by caps-v1; see "Effort vocabularies (caps-v1)"):
- `output-schema`: `--output-schema <schema>` is passed. The built-in `openai` route
  enforces it server-side (bare JSON comes back); the z.ai hosts accept the flag without
  enforcing it (a fenced JSON block or plain Markdown can come back).
- `prompt-only`: the flag is never passed. The MiMo hosts reject it outright
  (`responses_feature_not_supported: text.format type 'json_schema' is not supported, only
  'text' and 'json_object' are allowed`), and an undeclared host might. The schema file
  (about 2 KB) is appended as a final `JSON Schema of the reply:` section, with an
  instruction for exactly one JSON object, no fence.
- Either way the reply is parsed leniently (bare or fenced) and validated locally. Ledger
  `schema_transport`/`schema_transport_source`; `codex-providers.ps1 -Json` reports
  `schema_transport` per provider; the reply header's `Structured reply:` line gets
  `(prompt-only transport)` appended; `-DryRun` prints e.g. `transport   : prompt-only
  (caps-v1: token-plan-ams.xiaomimimo.com): --output-schema is NOT passed; the schema
  travels in the prompt, the reply is validated locally`. `-SchemaTransport
  output-schema|prompt-only` overrides the declared transport for one run (not with
  `-Raw`); use it only when the declared transport is known to be wrong for the endpoint.

**Validation.** The parsed reply must match the schema exactly: every required field, legal
enum values, `additionalProperties: false`, `line` either `null` or an integer in
`1..2147483647` (anything else is a validation error, never a crash). A structural error
(not valid JSON, an unknown field, a bad enum, a `null` where an array is required, …)
means no verdict and no findings ingestion; the raw text is kept as the reply body and the
header reads `Structured reply: INVALID (…) — raw text kept; no findings recorded.` A JSON
parse error's `(…)` is the .NET exception message, in the machine's UI language. The one
exception is the format-repair turn below. A bridge-side bug while parsing or ingesting a
valid reply is reported separately as `bridge could not process the reply: …`, also with
no ingestion. Three semantic rules also apply (messages joined with `; ` in
`validation_error`); none of them is a bridge failure (`bridge_outcome` stays
`usable reply` whenever the text is non-empty):

- **The verdict must fit the purpose** (see "Review purposes"). A mismatch drops the
  verdict (`""`); findings are still ingested.
- **`ACCEPT` next to a new `blocker` finding** is a contradiction: findings are ingested,
  the verdict becomes `""`, `validation_error = "verdict ACCEPT contradicts N blocker
  finding(s)"`, header `Verdict: (invalid: ACCEPT contradicts N blocker)`.
- **`ACCEPT` next to a prior open blocker reported `still-open`** is the same
  contradiction (`"verdict ACCEPT contradicts still-open prior blocker F02-1"`). A prior
  open blocker reported `not-checked` or `unknown-id`, or not mentioned, is **not** an
  error: the verdict is kept, `WARNING: ACCEPT with N unchecked prior blocker(s) (F02-1,
  …).` is printed and the ids go to `unchecked_prior_blockers`.

The rendered `### Blockers` section lists new blocker findings and retained prior
blockers, the latter marked `(prior, still-open)` or `(prior, not-checked)`, for every
verdict, without duplicating the prior finding's record.

**Format repair (`-FormatRetry`, default `1`; `0` turns it off).** When a structured run
comes back as prose, the bridge spends ONE recorded repair turn, only if all of these
hold: the run is structured (not `-Raw`, not `chore`); the bridge got a usable reply (exit
0, no timeout, no provider failure); the reply fails to parse or validate (a valid object
with a verdict you disagree with is never retried); the thread is verified (events or a
verified rollout); and the prose is substantive: ≥ 25 words with two numbered answers, ≥ 40
with one, ≥ 120 otherwise (numbered answers at a line start: `**Q1.**`, `Q1.`, `Q1:`,
`1.`, `1)`, `**1.**`, `### Q1`), and not a refusal (a reply that opens with, or is
dominated by, refusal phrasing and has no numbered answer, finding id, `RC` id or
verdict). When the gate says no, `format_retry` stays `null` and `validation_error` ends
with ` (format repair not attempted: reply looks like a refusal)` or
` (format repair not attempted: reply too short (<n> words))`.

- The turn: `codex exec ... resume <thread> -`, read-only sandbox, the route's lowest
  effort, the same `-CodexConfig` items, no `--output-schema`, a prompt that asks to
  convert the previous message verbatim into the object (schema and consultation id
  given, never the brief), within `min(-TimeoutSec, 300)` s, under the same lock and
  recovery record.
- Success: the repaired object is ingested (findings and verdict; `.reply.json` holds it);
  the original prose is kept byte for byte as `handoffs/<NN>-codex-<slug>.original.md` and
  rendered after the structured section under `## Original reply (prose, before format
  repair)`. Failure: the prose is kept, `structured` stays `false`, and `validation_error`
  gets ` (format repair failed: <why>)`.
- The entry keeps its original `thread`; a repair turn that resumed a different thread id
  records it only in `format_retry.thread`, with a drift note.
- Drift notes are warnings, never refusals: differing requested checks, a differing
  numbered answer, a finding id named in the prose but missing from the object, a
  differing verdict, and prose sentences not carried into `reply_markdown` (every
  sentence of ≥ 60 characters, at most the 40 longest). When a drift note disagrees with
  the object, the original prose is the evidence of record.
- Console: `format repair: <succeeded|failed> in <s> s; drift: <n> note(s)` plus one
  `  drift:` line per note; `-DryRun`: `format retry : 1 attempt if the reply is not valid
  JSON` or `format retry : 0 (off)`. Panel members inherit `-FormatRetry`.
- A bridge killed during the repair turn does not lose the first answer: before the repair
  starts, the recovery record gets `original` (the `.original.md` path, already on disk)
  and `first_reply: "usable prose (format repair in progress)"`, and every message built
  from that record (the refusal while the repair may still run, the `recovered
  reservation ...` note, the dry run's `pending` line, `codex-findings.ps1 -List`) adds `a
  usable prose reply of that run exists at <path>; no ledger entry was written for it`.
  Both fields are cleared once the ledger entry is written; a run that consumed or cleared
  a record has a `Recovery record:` header line.

**Requested checks (a convention, not a schema field).** Every purpose's prompt asks the
reviewer to end `reply_markdown`, when it needs evidence it cannot get read-only, with a
`## Requested checks` section: at most 5 items `RC1..RCn`, each ONE runnable command or
procedure, its working directory, the permission it needs (read-only/workspace-write),
the observation that would settle it and a budget, referring to a finding by position
(`finding #2`), an earlier id (`F04-1`) or an invariant name. The schema stays v1 and the
bridge renders nothing extra. Run the checks (or hand them to a worker) and record them in
the next brief's `## Requested checks run` table (`templates/brief-review.md`).

### Findings: ids, status, ratings

Each finding gets `F<NN>-<k>`: `NN` the handoff number of the reply that raised it (two
digits or more), `k` its 1-based position in that reply's `findings[]`. The stored record
in `findings.json` carries `id`, `status`, `severity`, `locations[]`, `claim`, `trigger`,
`evidence[]`, `verification`, `remedy`, `supersedes[]`, `superseded_by[]` (filled on the
OLD finding when a later one names it; bookkeeping, not a status change), `source`
(`{consult, reply, thread, base_commit, tree_sha256}`), `history[]` (one entry per status
change: `{when, status, by, note, evidence, base_commit, tree_sha256}`) and
`reviewer_checks[]` (one entry per later reply that reported on it:
`{consult, when, status, note, base_commit, tree_sha256}`, with the reviewer's own
`fixed`/`still-open`/`not-checked`, never the tracked status).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-findings.ps1" -Task <task> -List [-All]
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-findings.ps1" -Task <task> -Stats
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-findings.ps1" -Task <task> -Id F04-1 -Status verified -Evidence "<what you ran and what it showed>"
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-findings.ps1" -Task <task> -Id F04-2 -Status rejected -Note "<why>"
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-findings.ps1" -Task <task> -Rate 4 -Useful partly -Note "<why; required for no>"
```

- **Statuses:** `proposed → implemented → verified`, with `rejected`, `wontfix` and
  `superseded` as alternatives; any status may follow any other, and `history[]` is the
  audit trail (appended, never overwritten, with the revision fingerprint of that moment).
  `verified` requires `-Evidence` (what you ran, not that you believe it); `rejected` and a
  reopen (`-Status proposed` on a non-`proposed` finding) require `-Note`; `superseded`
  requires neither. A later reply reporting a finding `fixed` is evidence to cite, never a
  status change: the coordinator moves the status. All flags: `-CollabDir` (default
  `.collab`), `-List`, `-All`, `-Stats`, `-Id`, `-Status`, `-Note`, `-Evidence`, `-Rate`,
  `-Useful`, `-Telemetry on|off` (with `-Rate` only).
- **`-List`** shows open findings (`proposed`/`implemented`), `-All` every finding. It flags
  `[ORPHAN]` on a finding whose `source.consult` has no ledger entry or whose entry's
  `reply` does not match, and on a finding whose `reviewer_checks[]` names a consult with
  no ledger entry (the signature of a crash between the findings write and the ledger
  write); a closed finding with an orphan check is shown even without `-All`. It prints a
  `pending: state=…, n=…, nn=…` line when an interrupted run left a recovery record.
- **`-Stats`** prints one line per consultation (purpose, effort, wall time, output
  tokens, verdict, and proposed/implemented/verified/rejected counts), then a per-reviewer
  scoreboard: one line per lineage with raised, verified, implemented, proposed, rejected,
  wontfix and superseded counts and the yes/partly/no marks. A finding whose consultation
  predates 0.3.0, or has no ledger entry, counts as `unknown provenance`.
- **`-Rate <n>`** records the judge's usefulness mark for consultation `n` (a ledger entry
  number, not a finding id) in the top-level `ratings` array of `findings.json`:
  `{n, consult_id, lineage, provider, model, engine, purpose, topics, consult_when, useful,
  note, when}` (R24: and `telemetry_sent`, unix seconds, once its telemetry event was spooled),
  copied from that ledger entry so the row survives pruning. (0.5.0, wave 26) The
  mark is keyed by the consultation's `consult_id` (`n` is only unique within a task - kept for
  display): rating the same consultation again replaces its record, and everything a routed
  panel needs is on the record itself - the reviewer, the purpose, the `topics` and the
  consultation's own time `consult_when` (`when` is the time of the mark). A mark recorded
  before wave 26 is completed from the ledger entry with its `consult_id`, never by `n`. Rate
  **every** consultation, plain-prose ones included, or the telemetry only counts
  structured reviewers - and a routed panel only routes by what was rated. (R24) With telemetry
  on, every `-Rate` (a re-rating too) also spools ONE anonymised `rating` event once the mark is
  committed - the vendor class, the closed-list model, the purpose, the mark and the
  consultation's age in days, never the note or the topics ("Telemetry (on by default)");
  `-Telemetry on|off` decides for one rating, and `-Telemetry` without `-Rate` is refused. Marks
  given before that: `codex-telemetry.ps1 -BackfillRatings` sends each once.
- **Locking:** a status change and `-Rate` take the task lock and are refused while a
  consultation of the task runs, and - both judging every recovery record of the task - while
  an interrupted one's bridge or codex process may still run (a panel member whose panel run
  died included); `-List` and `-Stats` only read and never lock.

### Write order and atomic stores

Per consultation: `.reply.json` first (the byte-for-byte copy, before anything parses it),
then the rendered `.md`, then `findings.json`, then `sessions.json` last (the commit
point). If the raw copy fails, that is a bridge failure in its own right:
`bridge_outcome = "failed: could not preserve the raw reply (<error>); original kept at
<temp path>"`, exit non-zero, no verdict, no ingestion, ledger entry still appended. A
rerun's next consult number and handoff number are allocated past every ledger `n`,
every `source.consult` and `reviewer_checks[].consult`, every `F<NN>` id and any
reservation in `.consult.pending.json`, in `-Raw` mode too, so nothing written or reserved
is overwritten.

**The commit write lock (0.4.x wave 21).** The handoff `.md`, `findings.json`, `sessions.json`
and the removal of the run's recovery record happen under `<task>/.consult.write.lock` - a
permanent file owned by holding it open, like `.consult.lock`, but held only for the seconds
of one commit and waited for (backoff up to 60 s). Under it the bridge RE-READS both stores
and applies only its own delta: this run's findings (`F<NN>-k`, kept in id order) and
reviewer checks go into the fresh `findings.json`, the handoff's rendered section is made from
THAT ingest, the ledger entry is inserted at its place by `n`. Every writer does so - a single
run, a panel member, `codex-findings.ps1 -Status` and `-Rate` - so no writer replaces a store
with a snapshot read before it and no concurrent commit is lost (ledger `commit_wait_ms`: how
long it waited). Before it waits, the run marks its recovery record `committing` and names
its reply there (`reply_json`: the `.reply.json`; a raw codex run: its last message's temp
file), so a commit that never completes leaves a record that says where the reply is. When
the lock cannot be had within 60 s it gives up WITHOUT touching the stores: the record stays
`committing`, the run exits non-zero (`codex-consult: commit blocked: the write lock '<path>'
of task '<task>' was not acquired within 60 s: it is held open by ...`; a panel's summary says
`commit blocked`), and the next run consumes the record like any interrupted reservation,
naming the kept reply (`the reply of that run is kept at <path> (its commit did not
complete)`). A kill inside the commit can still leave findings without a ledger entry
(`codex-findings.ps1 -List` flags them ORPHAN; a panel's summary says `stopped inside its
commit`); the record stays `committing` the same way, and numbering never reuses their ids.

`sessions.json` and `findings.json` are written to a temp file in the same directory,
flushed, and moved over the store in ONE rename that replaces it (`MoveFileEx` with
`MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH` via P/Invoke on Windows PowerShell
5.1, `File.Move(tmp, dst, overwrite)` on PowerShell 7, `rename(2)` on Unix). A kill
mid-write leaves at worst a stray `.<name>.<guid>.tmp`, never a truncated or missing
store. An existing store that is empty, unparseable, not a JSON object, or (for
`findings.json`) missing its `findings` array is corruption: every mode, `-DryRun` and
`-List` included, refuses and names the file; it is never replaced with an empty store.

---

## Binding a review to a revision

Every entry records `base_commit` (full SHA, or `unknown` without git or commits),
`reviewed_revision` (short SHA, `+ uncommitted` when the tree is dirty; for humans),
`changed_files`, and `tree_sha256`: the SHA-256 of a manifest built from
`git status --porcelain=v1 -uall -z`, one line per changed or untracked entry,
`<XY> <mode> <blob|deleted|dir> <path>[<TAB><rename source>]`, sorted by path (ordinal,
case-sensitive). A rename, a content edit and a file-mode change all move it. `<mode>`
comes from `git diff --raw HEAD`: `=` when the worktree matches HEAD, values such as
`100644>100755` or `000000>100644` when it differs, `u` for an untracked entry (git reports
no mode for those). `tree_sha256` values computed before this mode field existed are not
comparable with later ones.

Paths under `<CollabDir>` are excluded entirely (from the hash, `changed_files` and the
dirty check), so the consultation's own files never move the fingerprint; submodules are
recorded as a `dir` entry, not recursed. `fingerprint_note` spells out every exclusion
whenever git is present, e.g. `collab dir '.collab' excluded (2 entries); ignored files
excluded; untracked file modes not recorded; submodules not recursed`; with no git,
`tree_sha256` is `""` and `fingerprint_note` is `"no git"`.

The tree, the brief and every `-Artifact` are hashed under the lock before and after the
run: `tree_sha256_after`/`tree_changed_during_review`, `brief_sha256`/
`brief_sha256_after`/`brief_changed_during_review`, and each `artifacts[]` entry's
`sha256`/`sha256_after` with `artifacts_changed_during_review`. Each difference prints its
own `WARNING: …` header line, independently of the others.

(0.5.0, wave 24c) `tree_changed_during_review` - the `WARNING`, an engine's tree check and the
continuation gate - compares file CONTENTS: every tracked file's blob (`git ls-files -s`; the
worktree's blob for a path `git status` lists) and every untracked file's hash, under the same
exclusions (the collab directory, ignored files, submodules not recursed) - never HEAD, the commit
id or the index's metadata. A commit, a moved HEAD or a `git add` that leaves every file as it was
is no change (the coordinator committing the collab files while a reviewer runs used to fail an
agy or muse member with `the working tree changed during the run ...: 0 files`), so
`tree_sha256_after` may differ from `tree_sha256` while `tree_changed_during_review` is `false`. A
moved HEAD is recorded as `revision_moved` (`"<old base_commit> -> <new>"`, informational) and
noted in the handoff header (`Note: HEAD moved during the review (<old> -> <new>) - no file content
changed: not a tree change.`); `base_commit` and `reviewed_revision` stay the reviewed revision.

`-Artifact <path>` binds a built artifact (a binary, a bundle) to the review. Pass several
as ONE comma-separated string (`-Artifact a.exe,b.dll`); the parameter cannot be repeated
(PowerShell refuses a parameter given twice). Paths resolve against the current directory,
then the repository root; a missing path refuses the run.

---

## The lock and recovery

The rule: one consultation per task at a time (a `-Panel` run counts as one: it holds the
lock for all its members); an interrupted run leaves `.consult.pending.json` (a panel
member: `.consult.pending-<NN>.json`) and the next consultation recovers it automatically
unless the bridge that wrote it or a codex process from it is still alive; never delete
`.consult.lock` or `.consult.write.lock`.

- **`<task>/.consult.lock`** is permanent: created on first use, never deleted. Owning it
  means holding it OPEN for the whole run (Windows: `FileShare.Read`, so a refused
  contender can read who holds it; elsewhere `FileShare.None`, an advisory `flock`);
  closing the handle releases it. Its content (`{pid, start_time, host, task, started}`,
  plus `panel` while a `-Panel` run holds it) is informational only; deleting the file
  unlocks nothing. `codex-consult.ps1` (a `-Panel` run for the whole panel; its members
  never), `codex-findings.ps1 -Id/-Status` and `-Rate` take it; `-List`/`-Stats` never do.
- **`<task>/.consult.write.lock`** (0.4.x wave 21) is the commit lock of the two stores,
  with the same discipline, held for one commit only (see "Write order and atomic stores").
- **`<task>/.consult.pending.json`** is the recovery record (a panel member's:
  `.consult.pending-<NN>.json`, written `reserved` by the panel run before any member
  starts, then owned by the member). It exists only during a run or after an interrupted
  one (a clean run deletes it after the ledger write) and moves through `reserved` (before
  Codex starts) → `launching` → `running` (child registered) → `survivors` (a
  `-TimeoutSec` kill could not stop the whole process tree) → `committing` (the run is
  over; waiting for or holding the write lock). It names the bridge that wrote it (`pid`
  and, since wave 21, `start_time`).
- **The next run judges every record before writing anything.** Unreadable or malformed:
  refused as corruption, naming the file. A record whose writer (pid + start time) still
  runs on this host is active in every state, `reserved` included - a panel member building
  its prompt, running its reviewer or committing (`a consultation of this task is still
  running: its bridge (pid N) wrote <record>…`). `running`/`survivors`/`committing` with a
  recorded pid alive on this host: refused (`a previous consultation's codex process (pid N)
  is still running…`). (Wave 28e, E1 / F54-1) A `survivors` record also keeps `unverified[]`
  `{pid, why}` - the descendants whose start time the kill could not read (it left them alone) -
  and the next run names each one and checks it again: gone - dropped (`unverified pid(s) N
  [gone] dropped`); its start time still unreadable - it blocks the task as a survivor does
  (`… its start time still cannot be read - counted as running (fail-closed)`); readable now - a
  process that started before that run is not its descendant (dropped), any other blocks only
  when it looks like codex (the rule below), never by pid alone. (Wave 28e, E18 / F27-1) A kill that
  left only such descendants keeps its record too (`survivors: []`). (Wave 28e, E19 / F27-2) That
  re-check is FAIL-CLOSED on the evidence: a pid whose start time is readable now is dropped only when
  it is proven unrelated - it started before that run, or its command line was READ, does not look
  like codex and its parent is none of the record's pids; a command line that cannot be read (access
  denied, or a generic runtime such as `node` or `powershell` with no arguments on it) counts as
  running (`… command line not readable - counted as running (fail-closed)`), and so does a child of
  a recorded pid (TEST HOOK, test mode only: `CODEX_CONSULT_TEST_CMDLINE_UNREADABLE=<pid>[,<pid>]` -
  these pids read with a command line that cannot be read). The same rule, with the same messages,
  re-checks a SURVIVOR recorded without a start time (an older record's bare pid) or whose start time
  cannot be read now (`Test-RecordedProcess`); a survivor whose recorded start time is read now is
  judged by its pid and that start time as before. (Wave 28e, E23 / F30-1) A record with
  `kill_unconfirmed` (a kill that named no pid and was not confirmed) is released only by a clean scan:
  by parent pid under the recorded bridge, then under the recorded child (Windows keeps an orphan's
  parent id) and by the machine-wide rule below - a scan that fails refuses (`… left an
  UNKNOWN process tree - the kill of its codex run was not confirmed (<why>) - and the scan for its
  processes failed: …`), one that finds a process refuses naming it (`… and a codex-like process of it
  may still run: pid N … [child of the interrupted bridge (ppid M)], found by …`), and a clean one
  releases the record (`unknown tree after an unconfirmed kill: the scan found no codex-like process
  under pid <bridge>, <child> since <started> - released (…)`). Outside Windows (no scan by parent pid)
  and from another host the run is refused (`… Make sure no codex process of that run still runs, then
  delete <record> to release it.`), and `codex-findings.ps1 -List` names the record and why. (Wave 28e,
  E25 / F32-1) A panel member's record needs BOTH scans clean as well: a reviewer that lives under a
  dead, unrecorded intermediate is invisible by parent pid. The machine-wide rule cannot tell a live
  sibling member's reviewer from this member's orphan, so either postpones the release (`… and a
  codex-like process runs: pid N <name> (task not verifiable) - this panel member's unknown tree is
  released only when no such process runs`).
  A dead recorded pid is not proof of a dead tree (it is usually the launcher shim), so
  when every recorded pid is gone, and for a `launching` record, the bridge scans for a
  child of the dead bridge or of a dead recorded pid (Windows keeps an orphan's parent
  id), then for any codex-looking process (named `codex`, or with the launcher path or
  `@openai/codex` on its command line) started at or after the record's `started` time.
  (Wave 29, E27) A reviewer run is always `codex exec ...` (or the launcher shim that starts it),
  so that rule leaves out a codex-named process whose command line shows it is one of the Codex
  desktop app's (or an IDE extension's) servers or helpers - `app-server`, `exec-server`,
  `mcp-server`, `login` or `app` as its first non-option token (after `-c key=value` and the
  other global options), an executable named `codex-computer-use*`, or `--parent-pid` without
  `exec` - and the scan names what it left out (`Win32_Process scan (…; excluded: pid N codex.exe
  [codex app-server]): none found`); `codex exec …`, the launcher path or `@openai/codex` on a
  command line, and a codex whose command line cannot be read still count (fail-closed; the test
  hook `CODEX_CONSULT_TEST_CMDLINE_UNREADABLE` is honoured by this scan too).
  That second rule cannot tell tasks apart and says so ("task not verifiable"); there is
  no age cut-off - and it is never applied to a panel member's record, which is judged by
  its recorded pids and (Windows) their children only: a live SIBLING member's reviewer
  looks like codex too. A record from another host naming pids is refused. Otherwise the
  reservation is consumed (`recovered reservation n=…, nn=…`, or `cleared the recovery
  record of consult n=…` when that consult already reached the ledger; a member record is
  named: `(.consult.pending-05.json: state '…'`), numbering skips past every one, and the
  consumed member records are removed.
- Delete a recovery record only when you know the named process is unrelated.
  `-List`/`-Stats` print one `pending:` line per record without locking; `-DryRun` reports
  what the next run would recover, or that it would be refused and why. These files are
  git-ignored.
- Not enforced: one Codex thread belongs to one task directory. Never resume the same
  thread from two task directories.

---

## Reviewer identity and lineage

Every run records which reviewer answered (`reviewer`, `lineage`) and continues only that
reviewer's own threads. A thread never changes provider or model.

**Resolution.** The provider comes from, in order: `-Provider`; with a roster, the
thread's own ledger entry under `-Thread`, else the roster walk (see "Reviewer roster and
panel"); the config's top-level `model_provider`; Codex's default, the built-in `openai`.
The model: `-Model`; the thread's entry or the roster entry; the config's top-level
`model`. Without a roster, a `-Thread` must match the lineage resolved this way. The config is
`$env:CODEX_HOME/config.toml`, else `~/.codex/config.toml`. `-Provider` names a
`[model_providers.<name>]` table (case-sensitive; `openai` is built in) and needs `-Model`
unless that provider's roster entry names a model (`-Provider needs -Model: the bridge
cannot know which model a provider serves by default`). Whatever is resolved is pinned on
the command line (`-m <model>`, `-c model_provider="<provider>"`). A top-level
`profile = "…"` key leaves identity UNRESOLVED even when `-Provider` and `-Model` are both
given (a profile can override the provider and effort behind the bridge); Codex profiles
(`-p`) are never passed.

**The config scanner** (`Read-CodexConfigSubset`) understands blank lines, `#` comments,
table headers `[a.b]` and `[a."quoted key"]`, and key/value lines with bare (ASCII) or
quoted keys and single-line string, bool, number or date values. What it does not
understand has three blast radii:
- an array, inline table or multi-line string as a VALUE makes only that KEY unusable (and
  the table the key would define, e.g. `x = {...}` defining `x`);
- a dotted key, an array-of-tables (`[[a]]`), a sub-table, or a table/key defined twice
  makes the TABLE it writes into unusable;
- a line it cannot tokenize at all (an unterminated string or array, a line that is
  neither header nor key/value) makes the whole FILE unusable.

The top level is usable while `model_provider`, `model` and `profile` are plain; a
provider table is usable only when every key in it is plain. When the config or the table
this run needs is unusable, identity is unresolved, unless `-Provider` and `-Model` are
both given, that provider's own table parses and no `profile` is set. A TOML 1.1 unicode
bare key makes the file unusable; quote it.

**Unresolved identity** is recorded as `unknown`: `-Mode` defaults to `new`, `fork` and
`resume` are refused (`provider identity could not be resolved (...); pass -Provider and
-Model explicitly, or use -Mode new`), the entry is never a parent, and the preflight
refuses the run unless `-SkipPreflight` (see "Preflight and endpoint health").

**Endpoint fingerprint.** For a `[model_providers.<name>]` table, `provider_fingerprint` is
the SHA-256 of its `base_url` (lowercase scheme and host, path as is, no trailing slash)
and `wire_api` only. An absent `wire_api` is canonicalised as `wire_api=default`
(`provider_config` then has no `wire_api` key; headers show `wire_api: (default)`); an
empty `wire_api = ""` is a different value. Changing `base_url` or `wire_api` (including
adding one) is endpoint drift; comments, key order, a rotated `env_key`/secret and the
table's `name` never are. `fork`/`resume` onto a parent with a different fingerprint is
always REFUSED, never silently switched to a new thread:

```
endpoint or protocol of provider ZAI changed since thread <uuid> (consult n=3 recorded
provider fingerprint <hash12>, now <hash12>); start a new thread with -Mode new
```

**The built-in `openai` provider:**
- no `[model_providers.openai]` table (the usual case): identity `builtin:openai`; a set
  `OPENAI_BASE_URL` is folded into it (`cc-provider-v1|builtin:openai|base_url=<canonical>`),
  so a proxy change is drift too.
- a usable `[model_providers.openai]` table DEFINES the identity (its `base_url`/`wire_api`),
  `identity_note` says `user-defined [model_providers.openai] table used for the identity`,
  and `OPENAI_BASE_URL` is ignored. Whether Codex merges such a table over its built-in
  default is not verified against the Codex source; the table is the conservative claim.
- an unusable one leaves an implicitly reached `openai` unresolved; an explicit
  `-Provider openai` naming it is refused outright.
- the built-in identity is used only when the scanner can ESTABLISH that no
  `[model_providers.openai]` declaration exists. A construct at `model_providers` itself
  (an inline table, an array, a dotted key from the top level, a table defined twice), an
  `openai` entry written inline inside `[model_providers]`, or an unusable
  `[model_providers.openai]` table leaves identity unresolved with `Codex's default
  provider openai: the providers in <path> could not be established, so
  [model_providers.openai] may be declared there - <reason>`. An unusable table under
  another provider never affects `openai`.
- `openai`'s auth mode (API key or ChatGPT sign-in) is not part of the fingerprint. Other
  built-in Codex providers (`oss`, `ollama`, `lmstudio`, …) are not recognised.

**The `Reviewer:` header line** says where each piece came from:

```
Reviewer: <lineage> (provider from <provider_source>, model from <model_source>;
endpoint <url>|builtin:openai[ via OPENAI_BASE_URL <url>][, wire_api: <v>|(default)];
provider fingerprint <12 hex>[; <note>]; harness <h>).
```

The `wire_api:` clause appears only for an identity taken from a table; `<note>` is
`identity_note` when non-empty.

**Parent threads.** The parent for `fork`/`resume` is the newest ledger entry of THIS task
with a verified `thread`, a resolved identity, the same `reviewer.provider` AND
`reviewer.model` (compared separately, ordinal) and the same fingerprint; never the task's
newest thread overall. `-Thread <uuid>` must name such a thread:

```
thread <uuid> belongs to lineage a/b :: c (consult n=1); this run is a :: b/c. A thread
never changes provider or model: use -Mode new, or run as a/b :: c
```

An unknown uuid is refused as unknown provenance; `-Thread` with `-Mode new` is refused
(`-Thread needs -Mode fork or resume`). Entries written before 0.3.0 have unknown
provenance: never an automatic parent, and `-Thread` naming one is refused (`unknown
provenance (recorded before 0.3.0); use -Mode new`). So the first 0.3.0 consultation on an
older task always starts a new thread.

**Where the thread id comes from.** Only the `thread.started` event and the session-start
events `session.started`/`session_configured` (top-level or msg-wrapped) are read; any
other line, notably a `turn.started` carrying a foreign `session_id`, is ignored. When the
stream names no thread (including a resumed thread whose rollout file lives in an OLDER
day directory), the bridge scans the rollout files written since the run started, newest
first - (wave 28b, D16) in `<codex home>/sessions/<yyyy>/<MM>/<dd>/` of every LOCAL calendar day
from the start to now (Codex names them by the local date; a run across midnight looks at both
days; invariant digits whatever the culture) - and accepts one only if it contains this run's
`Consultation id:` line
(`thread_source = "rollout (verified by consultation id)"`). Otherwise `thread` stays
empty, `thread_source = "unknown"`, and the newest candidate is kept as
`thread_candidate`, never used as a parent.

---

## Preflight and endpoint health

Before anything is locked or started, the bridge checks the resolved provider locally
(the same check as `codex-providers.ps1`; no network call for a codex provider - an agy
engine's sign-in check is one `agy models` call, or none after a usable agy reply within
the last 60 minutes; a muse engine's reads `~/.config/muse/auth.json` locally, see "Engines")
and fails CLOSED. An engine's launch invariant is NOT part of it (muse: an API key in the
environment refuses the run with and without `-SkipPreflight`):

| Check | Refusal |
|---|---|
| credentials: `openai` or a table with `requires_openai_auth = true` → `codex login status` (15 s timeout, UTF-8); any other table → its `env_key` variable is set, or it has an `experimental_bearer_token`, or the roster entry says `"auth": "none"` and the table names neither | `provider ZAI is not usable: env ZAI_API_KEY not set; nothing was started (run codex-providers.ps1 for the full picture)` |
| availability can be established (a resolved identity; `codex login status` runs and finishes - (wave 27c, D4) and is never started with the coordinator's host markers: a probe whose start-info cannot be scrubbed runs with the markers hidden from the bridge's own environment, else it is SKIPPED - the preflight reads `not checked - ...` and `warnings[]` says why) | `provider ZAI: availability could not be established (…); pass -SkipPreflight to launch anyway, or fix the check` |
| no `auth` failure on this ENDPOINT in the last 24 h (unless a later run there succeeded) | `provider ZAI is not usable: the last run on this endpoint was rejected as unauthenticated at <when> (<message>); if you rotated the credential, pass -SkipPreflight once` |
| no usage limit whose named reset time lies ahead | `provider ZAI is not usable: its usage limit (hit at <when>: <message>) lasts until <iso>; nothing was started (pass -SkipPreflight to launch anyway)` |
| (0.5.0, wave 24b) no usage limit WITHOUT a reset time hit in the last 60 minutes | `provider ZAI is not usable: it hit a usage limit at <iso> (<message>) and named no reset time - out for 60 minutes, until <iso + 60 min>; nothing was started (pass -SkipPreflight to launch anyway)` |
| (wave 24c) no BURST 429 without a reset time hit in the last 10 minutes | `provider ZAI is not usable: it hit a burst limit at <iso> (<message> - a 429 that names no usage limit or quota) and named no reset time - out for 10 minutes, until <iso + 10 min>; nothing was started (pass -SkipPreflight to launch anyway)` |

A usage limit with NO reset time is out for 60 minutes after it was hit (the failure's own
time; a later successful run on the endpoint clears it) - one verdict for every caller: an
explicit `-Provider` run is refused (wave 24b; it used to warn and run), a roster walk skips it
(`usage limit hit <iso>, reset unknown; retry after <iso + 60 min>`), and the providers listing,
`-Short` and the SessionStart line say the same. (wave 24c) A BURST - a 429 whose text names no
usage window or quota: ModelArk (BytePlus) answers `exceeded retry limit, last status: 429 Too
Many Requests, request id: ...` for burst and concurrency limits that recover within minutes - is
out for 10 minutes instead (`provider_failure.kind` `burst`; the walk reads `burst limit (429) hit
<iso>, reset unknown; retry after <iso + 10 min>`, the one-line view `burst limit hit 10:31, reset
unknown; retry after 10:41, in 2m`); a 429 that names a usage limit, a quota, a balance, credits,
billing, a token plan, an hour/day/week/month window or a reset keeps the 60 minutes. An entry
recorded before wave 24c (no `kind`) is judged from its message. With `-SkipPreflight` a usage limit that still
blocks only warns (console `WARNING:`, ledger `preflight_warning`). `-SkipPreflight` bypasses every refusal
above (ledger `preflight: "skipped"`; with a roster, the first entry is taken unchecked,
under `-Panel` every entry). Use it only for an endpoint that genuinely needs no
credential and has no roster entry saying so, or once, after the user rotated a
credential inside the 24-hour auth window. `-DryRun` only prints the verdict and never
refuses on it. The credential check sees only what is local (a variable set, a token in the
config, a login); it cannot see live quota. A credential's validity is learned only from a
failed run.

**Machine-wide endpoint health (wave 26b, D13 - ROADMAP R20).** The ledgers are per repository,
but an endpoint's limits are per account: a 429 that one repository's panel hit is news to the
next repository's roster walk. So every run also records its outcome on the endpoint in ONE file
per machine, `<codex home>/codex-consult-health.json` (`CODEX_CONSULT_HEALTH=<path>` names
another, `=none` turns it off - read nor written): a usable reply (`class` `ok`) or a provider
failure (class `operator` excepted) as `{endpoint (the provider fingerprint), class, kind,
until, retry_after, repo, when, message}` - `until` the reset time the provider named, else the
hit + 60 minutes (10 for a burst), an auth failure + 24 h - and, while its engine turns run, a
row in `running[]` (`{endpoint, label, pid, start_time, repo, task, nn, panel, since}`, (wave 29b, E16) plus `plan`
when the roster entry names one; (E15) a `class` `ok` record may carry a `quota_mark`). Every
write happens under `<file>.lock` (an exclusive open; (wave 26c, D2) three attempts of 5 s each;
not acquired = not written) and prunes: an endpoint record older than 24 h whose `until` has
passed, a running row whose pid and start time are gone. (Wave 26c, D2) A run writes its outcome
record BEFORE its ledger entry; when that write timed out on the lock it is retried once at the
ledger commit, and if it fails again the run says so - while the repository ledger keeps the
truth. (Wave 27c, D7) ANY failure of that write is retried, and its cause is named: `lock
timeout`, `the directory <dir> does not exist`, `write failed: <why>`. (D8) The retry at the commit
never extends the hold on the task's write lock (which the other members of a panel wait for).
(Wave 28b, D13) The update survives a crash: THE JOURNAL `<health file>.journal` (append-only
NDJSON beside the health file, one endpoint record per line). When the update before the commit
failed, the run appends its record to the journal INSIDE the write lock - a local append, no wait
for the health lock - and the ledger entry says `machine-wide health not updated at the commit
(<cause>); the record is kept in the journal; a retry follows the commit` (`the journal could not
be written (<why>)` in its place when even that failed). After the lock is released the full retry
(3 x 5 s) applies the journal and empties it; its outcome, either way, is in the summary - the
console and a detached run's status record: `health     : machine-wide health updated by the retry
after the commit (the journal applied)`, or `warning    : machine-wide health not updated by the
retry after the commit (<cause>) - the record waits in <health file>.journal for the next run`.
Should the run die between its commit and the retry, the next run of ANY repository applies the
journal: every health update (a registration in `running[]`, an outcome) applies it under the lock
first and empties it once the file is written. Applying is idempotent - a record already in
`endpoints[]` (the same endpoint, class, kind, repository and time) is not added twice. (Wave 28c,
D10 / F42-6, F44-1) Nothing is lost silently: a journal line that does not parse (the torn append of
a writer that died) is MOVED to `<health file>.journal.bad` - appended there as the time, a tab and
the line's exact bytes - and counted in the warning `health journal: <n> unreadable line(s) kept in
<file>` (the run's `warnings[]` for an update before its commit, its summary for one after it); the
journal is then shortened by exactly the bytes that were applied or moved, never blindly to zero - a
line that cannot be moved (the `.bad` cannot be written) stays in the journal with everything after
it, and the next update tries again. Every
endpoint-health question - the roster walk, the panel's selection, `-Require`,
`codex-providers.ps1`, the SessionStart line - reads the file's records beside the repository's
ledgers as ONE record set: the newest record decides, as within one ledger (a later usable reply
anywhere clears a failure; two records at the same moment count with the later `until` - (wave
26c) the record's STORED `until` and `retry_after` travel with it). A panel's endpoint parallel limit (the roster's `parallel`, default 1)
also counts the runs of OTHER repositories, panels and single runs on the member's endpoint - (wave
29b, E16) and on any route of the member's `plan` -: the member waits, and says so (`panel member 2
of 3 waits: 1 run(s) elsewhere on this machine use its endpoint (parallel limit 1): ZAI in <repo>
task t handoff 04 (pid 1234)`; `... use its plan zai ...`, `(plan zai, pid 1234)` for a run counted
through its plan). The file is
optional: absent, unreadable or not parseable = as before wave 26b; a single run never waits
for it (its own row counts for the panels).

**Failure classes.** A failed run records `provider_failure = {class, kind, code, message
(<= 200 chars), when, retry_after, hint}` (and a `Provider failure:` header line; `kind` and `hint`
since wave 24c - see the 10-minute burst above and the context hint below). The class
comes from word-bounded keywords, tried in this order: `permission` (0.4.0: no output
produced/auto-denied/"permission that headless mode" - agy's F11 notice; also forced for
agy's tree-check failure), `capability` (not supported/unsupported/"does not
support"/feature_not_supported/json_schema/INVALID_ARGUMENT/invalid model
selection/"conflicts with --effort"; 0.5.0, wave 24b: a prompt larger than the plan's or the
model's context window - "supports only ... context/tokens", context length/window, "maximum
context", context_length_exceeded, "prompt is too long", "input token count" - even under a 401:
Kimi Code answers `unexpected status 401 Unauthorized: Your current plan supports only k3 up to
256K context...`, which must never block the endpoint for 24 h as `auth`; the summary adds
`hint       : context too long for this plan/model - narrow the brief (...) or choose a model
with a larger context window`, the handoff header a `Hint:`; a ledger entry recorded as `auth`
with such a text is read as `capability`; wave 24c: NOT when the text also names any quota class,
such as billing, payment, an insufficient balance, credits or a token plan: `billing_required:
insufficient balance for this context window` is `quota`, never `capability`, and an entry wave 24b recorded as
`capability` with such a text is read as `quota`; the hint is decided when the failure is
classified, from the code and the FULL message, and stored as `provider_failure.hint` - a code-only
`context_length_exceeded` or a context phrase past the 200 characters the message keeps gets it
too), then a usage limit said in words (usage
limit/quota/rate limit/RESOURCE_EXHAUSTED/too many requests) is `quota` even under a 401 or
403 status - Kimi Code answers `unexpected status 403 Forbidden: You've reached your 5-hour
usage limit...` - then `auth` (401/403/unauthorized/forbidden/invalid api
key/authentication/PERMISSION_DENIED/UNAUTHENTICATED/not signed in/login required/sign in
to), `quota` (usage limit/quota/rate limit/`rate_limit`/`usage_limit`/429/insufficient
balance/too many requests/credits exhausted/credit balance/payment required/402/token
plan/billing/RESOURCE_EXHAUSTED/rate_limit_exceeded), `transport`
(timeout/connection/dns/tls/certificate/502-504/network/UNAVAILABLE/DEADLINE_EXCEEDED; a
bridge-side timeout kill is `transport`, so is agy's malformed event stream), else
`unknown` (agy's conversation-id failures are forced to `unknown`). An SSE-style `data:{"error":{...}}` payload on stderr (how
the MiMo endpoint reports rejections) is parsed for `error.message`/`error.code` first. The
same word rule applies when the health READS a ledger: an entry recorded as `auth` whose
message says usage limit / quota / rate limit counts as `quota`, so an older misclassified
entry stops refusing its endpoint for 24 h without anyone editing the ledger.
Codex reports quota, auth and turn failures on the JSON event stream, not on stderr; the
bridge lifts the message from there. MiMo's exact wording for exhausted credits is not
confirmed; its keywords are a best guess.

**`retry_after`** is a quota failure's reset time, parsed from the message and never
guessed: Codex's wording (`try again at Sep 28th, 2026 8:35 PM.`), a bare ISO-8601
timestamp, a duration (`retry after 30`, `retry after 2h`, `resets in 2 days`, `try again
in 3 days 1 hour 7 minutes`), or Google's wordings (`retry in 32s`, `retry in 1m5.3s`,
`retry in 90 seconds`, the gRPC `"retryDelay":{"seconds":N}` / `"retryDelay": "32s"` - a
fraction rounds up to the next second), a compact duration after resets / try again / retry /
available in (agy's `Individual quota reached. ... Resets in 68h58m18s.`; also `in 2d3h`,
`in 45m`, `in 30s`), or a rolling window (Kimi Code's `Your quota will reset when the current
5-hour window ends.` -> the failure time + 5 h: an UPPER BOUND, since the window ends at the
latest 5 h after the failure). A wall-clock time is interpreted with the recording machine's time-zone rules
at write time, DST included (a spring-forward gap takes the post-transition offset, a
fall-back overlap the pre-transition one), and stored as an instant with its offset. An
entry written before that fix has no `retry_after`; reading it reparses the message with
the failure's own `when` offset, which can be off by a zone difference when read on a
machine in another zone.

**Endpoint health** is read from ALL task ledgers of the current repository, keyed by
the endpoint fingerprint (never the alias, so two names for one endpoint share one
record); the newest entry wins, so a later success clears an earlier failure. A fresh
repository therefore has no health history. `capability`/`transport`/`unknown` failures
are informational only. The health check runs even under `-SkipPreflight` (only the
refusal is bypassed). Pre-0.3.0 entries count as the built-in `openai` endpoint; an entry
with an unresolved identity is ignored. A record dated in the future counts as now. On
pwsh ≥ 7.5, ledgers are parsed with `ConvertFrom-Json -DateKind Offset` so timestamps
keep their recorded offset; Windows PowerShell 5.1 reads them as plain strings.

### codex-providers.ps1

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-providers.ps1" [-Provider <name>] [-Json] [-Short] [-CollabDir <path>] [-CodexExe <path>] [-EngineExe <path>] [-NoNetwork]
```

It answers "what can I consult right now?" and writes nothing, takes no lock and makes no
network call for a codex provider (at most one `agy models` call per agy engine; none
after a usable agy reply within the last 60 minutes, none with `-NoNetwork` - the
SessionStart hook's mode). First line: `codex config: <path>`; then (0.5.0) `endpoint health:
<collab dir> (<k> task ledgers, <m> consultations), read at <local time> - the ledgers of THIS
repository`: the health comes from the ledgers of the repository the command runs in, so run it
in the repository whose consultations you mean (run elsewhere, it sees none of them - the cause
of a listing that called an entry available while every panel of the day skipped it). Every
verdict below is the roster walk's own (`Get-PreflightVerdict -RosterWalk`, 0.5.0): a row never
reads available for an endpoint the walk skips. Then one row per provider (the built-in
`openai` and every `[model_providers.*]` table): `VERDICT` (`available`,
`unavailable (<reason>)` including `unavailable (usage limit until <iso>)`, or
`unknown (<reason>)` when `codex login status` could not run or the config cannot be
scanned), `PROVIDER`, `ROSTER` (roster positions, or `-`), `KIND` (`builtin`/`custom`),
`ENDPOINT` (canonical `base_url`, or `builtin:openai[+OPENAI_BASE_URL <url>]`),
`CREDENTIALS` (`ok: Logged in using ChatGPT`, `ok: env NAME set`, `ok: bearer token in
config`, `ok: declared anonymous in the roster`, `missing: env NAME not set`, `missing: no
env_key/bearer token in the table`, `missing: <first line of login status>`), `EFFORT`
(`openai (any model)`, `zai (11 declared models)`, `mimo (5 declared models)` or
`unknown (needs -NativeEffort)`) and `LAST FAILURE` (`<class>: <when> - <message>`, or `quota
until <iso>: …`; the newest failure of the last 24 h, else - 0.5.0 - the usage limit that still
makes the endpoint unavailable, e.g. a weekly limit hit days ago). With a roster, a line
`roster: <path> -> would select <provider> :: <model> (skipped: …)` or `roster: <path> -> no
entry is available (skipped: …)` (the single-run walk itself), then `availability: <the -Short
line>`. **Engine rows (0.4.0):** one more row per provider label the roster declares with
`"engine": "agy"` - `KIND` `engine agy`, `ENDPOINT` `agy (<launcher>)` (or `agy (launcher
not found)`), table `n/a`, `CREDENTIALS` from `agy models` (`ok: signed in (N models)`,
`missing: …` for sign-in wording or `missing: agy CLI not found on PATH`, `unknown: …`;
`ok: signed in (usable reply <m> min ago)` without any call when this repository's ledgers
hold a usable agy reply from the last 60 minutes - also with `-NoNetwork`; otherwise with
`-NoNetwork` `not checked (launcher present; run codex-providers.ps1)` and the verdict
`unknown (sign-in not checked)`), `EFFORT` `agy (tier in the model id)`, transport
`native`; health, `LAST FAILURE` and the roster columns as for any provider (health is
keyed by the engine's fingerprint, shared by every agy label). A `"engine": "muse"` label
(wave 23) gets the same kind of row: `KIND` `engine muse`, `ENDPOINT` `muse (<launcher>)`,
`CREDENTIALS` from the local sign-in check (`ok: signed in (~/.config/muse/auth.json:
providers.meta, mechanism oauth)`, `missing: not signed in: ...`, `unknown: sign-in not
checkable: ...` - also with `-NoNetwork`, it starts nothing), `EFFORT` `muse (2 declared
models)`, and the verdict `unavailable (refused: META_API_KEY is set: ...)` while the billing
guard would refuse it (wave 23b: also `unavailable (refused: the Muse sign-in is not established
as oauth (<cause>): ...)` for the keychain backend, no `auth.json` or no mechanism - the
`CREDENTIALS` column still shows the sign-in state). `-EngineExe` binds to the `-Provider` row's engine, else to the only
engine other than codex in the roster. `-Json` returns objects with
`name`, `engine` (`codex`, `agy` or `muse`), `kind`, `endpoint`, `wire_api`, `table`
(`built in`/`usable`/`unusable: <reason>`), `credentials`, `effort_vocabulary`,
`effort_models`, `schema_transport`, `last_limit` (the newest quota failure),
`last_failure` (`{class, code, when, message, retry_after}`), `roster_position` (first
position or `null`), (0.5.0, wave 24b) `roster_positions` (every position of the label, `[]`
when none - a label with two models has two), `roster_selected`, `verdict` and (0.5.0)
`health_source`. One listing resolves each entry's identity and each endpoint's health once
(the walk, the availability line and the rows share them; wave 24c: in an ORDINAL cache - `ZAI`
and `zai`, `glm-5.3` and `GLM-5.3` never share an entry). **`-Short`**
(0.5.0) prints ONE line over EVERY roster entry, each judged with the roster walk's verdict - the
SessionStart hook's line: `codex-consult: out - <provider> :: <model> (until <local time>, in
<rounded hint>), <label> :: * (...); <a> of <n> reviewers available` (the entries of one endpoint
group that share the state collapse to `<label> :: *`; a quota without a reset reads `limit hit
10:31, reset unknown; retry after 11:31, in 52m`, a burst 429 (wave 24c) `burst limit hit 10:31,
reset unknown; retry after 10:41, in 2m`; `..., <o> out, <c> not checked` when an entry was
not checked; nothing is cut), or `codex-consult: all <n> reviewers available`; without a roster
the providers (`... (no reviewer roster)`). `-Short -Json` returns `{line, health_source, total,
available, out, not_checked, roster, entries[{position, provider, model, engine, lineage, group,
state, kind, reason, short, hit, until}]}`. Not with `-Provider`. Exit codes with `-Provider`: `0`
available, `2` unavailable, `3` unknown, `1` no such provider or a usage error (an
unusable roster, a `CODEX_CONSULT_ROSTER` file that does not exist); the verdict is the roster
walk's, so a quota without a reset time hit within the hour exits `2` (0.5.0). Without `-Provider`:
`0` unless the roster is unusable. Plan against this output: a provider reported
unavailable does not become available by retrying the bridge.

---

## Effort vocabularies (caps-v1)

Effort vocabularies and schema transports are DECLARED per endpoint in a table the bridge
ships (`caps-v1`, ledger `effort_caps`), never inferred from a host or model prefix:

| Endpoint | Vocabulary | Declared models | Mapping from `-Effort` | Schema transport |
|---|---|---|---|---|
| built-in `openai` (no user table, no `OPENAI_BASE_URL`) | `low\|medium\|high\|xhigh` | any model | identity (`openai`) | `output-schema`, enforced |
| `api.z.ai`, `open.bigmodel.cn` | `low\|high\|max` | `glm-5.3`, `glm-5.3-flash`, `glm-5.3-flashx`, `glm-5.2`, `glm-5.1`, `glm-5`, `glm-5-turbo`, `glm-4.7`, `glm-4.6`, `glm-4.5`, `glm-4.5-air` (11, exact) | `medium`→`high`, `xhigh`→`max`, `low`/`high` as is (`zai-v1`) | `output-schema`, not enforced |
| `token-plan-ams.xiaomimimo.com`, `token-plan-cn.xiaomimimo.com`, `api.xiaomimimo.com` | `none\|low\|medium\|high` | `mimo-v2.6-pro`, `mimo-v2.6-flash`, `mimo-v2.6-pro-ultraspeed`, `mimo-v2.5-pro`, `mimo-v2.5` (5, exact) | `xhigh`→`high`, the rest as is (`mimo-v1`) | `prompt-only` |
| `ark.ap-southeast.bytepluses.com` (BytePlus ModelArk Coding Plan, base URL `/api/coding/v3`) | `low\|medium\|high` | `dola-seed-2.0-pro`, `dola-seed-2.0-lite`, `dola-seed-2.0-code`, `bytedance-seed-code`, `glm-5.3-flash`, `glm-5.2`, `glm-5.1`, `kimi-k2.5`, `gpt-oss-120b`, `deepseek-v4.1-flash`, `deepseek-v4-flash`, `deepseek-v4-pro` (12, exact) | `xhigh`→`high`, the rest as is (`ark-v1`) | `prompt-only` |
| `api.kimi.ai` (Kimi Code membership, base URL `/coding/v1`) | `low\|high\|max` | `k3`, `k3-256k`, `kimi-for-coding`, `kimi-for-coding-highspeed` (4, exact; the tier decides which the plan unlocks) | `medium`→`high`, `xhigh`→`max`, `low`/`high` as is (`kimi-v1`) | `prompt-only` |
| `token-plan.ap-southeast-1.maas.aliyuncs.com` (Alibaba Model Studio Token Plan, base URL `/compatible-mode/v1`) | `low\|medium\|high\|xhigh` | `qwen3.8-max`, `qwen3.8-flash`, `qwen3.7-max`, `qwen3.7-plus`, `qwen3.6-flash`, `deepseek-v4.1-flash`, `deepseek-v4-pro`, `deepseek-v4-pro-0813`, `deepseek-v4-flash-0731`, `glm-5.3`, `glm-5.2` (11, exact; the plan's `auto` router is not declared) | all four as is (`alibaba-v1`) | `prompt-only` |
| `engine:agy` (the agy engine) | none: the tier is part of the model id | any model | nothing sent (`model-tier`) | `native` (`--json-schema`) |
| `engine:muse` (the muse engine, wave 23) | `low\|medium\|high\|xhigh` (`--reasoning-effort`; the CLI also takes none, minimal, max, ultra) | `muse-spark-1.3`, `muse-spark-1.3-contributor` (2, exact: the live-verified subscription models) | all four as is (`muse-v1`) | `native` (`--output-schema`) |
| `engine:claude` (the claude engine, wave 29) | `low\|medium\|high\|xhigh` (`--effort`; `max` only through `-NativeEffort`) | the ids and aliases of the engine's model table ("Engines (wave 29)") | all four as is (`claude-v1`); the repair turn sends `low`; `effort_confirmed` `null` | `native` (`--json-schema`) |
| any other host | none (needs `-NativeEffort`) | — | — | `prompt-only` (safe default) |

Anything undeclared (another model on a known host, any model on an unknown host, an
`openai` proxy via `OPENAI_BASE_URL`, a user-defined `[model_providers.openai]` table) is
refused, naming what IS declared:

```
no effort vocabulary declared for model 'glm-6' on api.z.ai (caps-v1 declares:
glm-4.5, glm-4.5-air, glm-4.6, glm-4.7, glm-5, glm-5-turbo, glm-5.1, glm-5.2, glm-5.3,
glm-5.3-flash, glm-5.3-flashx); pass -NativeEffort <value> to send a value verbatim
```

A caps row whose vocabulary the bridge does not declare is a plan error (a bridge defect),
never an empty mapping. `-NativeEffort <value>` (a plain token) is sent as `-c model_reasoning_effort="<value>"`
verbatim (agy: `--effort <value>`, muse: `--reasoning-effort <value>`), mapping `native`. `-Effort` and `-NativeEffort` exclude each other. The console
shows the triple in one line, e.g.
`effort      : max sent (requested xhigh, mapping zai-v1, by host api.z.ai)`.

---

## Peak-hour windows

`CODEX_CONSULT_PEAK_<PROVIDER>` (provider uppercased, non-alphanumerics → `_`) =
`"<days> <HH:MM>-<HH:MM> <+HH:MM|-HH:MM>"`; days are a range (`Mon-Fri`), a list
(`Mon,Wed`) or `*`. Start inclusive, end exclusive; a window whose start is after its end
spans midnight and is keyed to the day it started. Optional
`CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` = comma-separated `YYYY-MM-DD` dates or
`YYYY-MM-DD..YYYY-MM-DD` ranges of any length, all-day off-peak (only `end < start` is
refused). A malformed spec is refused, naming the variable and the token.

The window is checked twice: early (a malformed schedule or `-OffPeakOnly` already inside
the window is caught before any hashing) and again immediately before launch; the
launch-time result is recorded (`peak`, `peak_schedule`, `peak_source`,
`peak_evaluated_at`). A long consultation can still run into a window after launch; there
is no mid-run check. Inside the window a run warns
(`WARNING: ZAI peak window (…) - this consultation runs at peak tariff.`); with
`-OffPeakOnly` it is refused, both when peak and when no schedule is set (`no schedule for
provider ZAI; -OffPeakOnly needs CODEX_CONSULT_PEAK_ZAI`). A run that enters the window
during preparation is withdrawn at launch with nothing started and no ledger entry:

```
-OffPeakOnly: ZAI entered its peak window before launch (Mon-Fri 14:00-18:00 +08:00; now
2026-09-24 14:00 Mon +08:00); nothing was started.
```

No schedule: `peak: null`, `peak_schedule: ""`, `peak_source: "none"`, console
`peak        : unknown (CODEX_CONSULT_PEAK_ZAI not set)`. `CODEX_CONSULT_NOW` (ISO
timestamps, consumed one per evaluation, the last repeating; `peak_source` then reads
`env (CODEX_CONSULT_NOW)`) is a test hook; never set it in normal use.

---

## Per-run Codex overrides (-CodexConfig)

`-CodexConfig key=value[,key=value]` passes extra `-c` overrides to `codex exec` verbatim,
after the bridge's own `-c` options and before `-o`. Pass one comma-separated string; the
parameter cannot be repeated. The string is split only at a comma that starts the next
`key=`, so a value like `[1,2]` stays whole. A value starting with `~/` or `~\` is
expanded to the home directory with forward slashes (Codex on Windows does not expand `~`:
`os error 123`); a value that is not already quoted, bracketed, `true`/`false` or numeric
is double-quoted. Refused keys (they are part of the recorded identity or effort):
`model`, `model_provider`, `model_reasoning_effort`, `profile`, `model_providers` and any
`model_providers.*`. Ledger `extra_config` (expanded, as sent) and `extra_config_source`.
A roster entry's `codex_config` follows the same rules and applies when `-CodexConfig` is
empty. The main use: a per-run `model_catalog_json`, because a global one replaces Codex's
own catalog (setup step 6).

---

## Reviewer roster and panel

**The roster** is an ordered JSON file of the reviewers the user is willing to use, first
choice first: `CODEX_CONSULT_ROSTER` (that file must exist, or every run is refused), else
`<codex home>/codex-consult-roster.json` when it exists (absent = no roster).
`CODEX_CONSULT_ROSTER=none` disables it, the default file included. Example: setup step 7;
a fabricated one is `examples/codex-consult-roster.json`.

| Key | Meaning |
|---|---|
| `roster_version` | must be `1` |
| `reviewers[].provider` | required: `openai` or a `[model_providers.<name>]` table |
| `reviewers[].model` | optional: omit it to use the config's top-level `model` |
| `reviewers[].codex_config` | optional array of `key=value` strings, `-CodexConfig` rules |
| `reviewers[].auth` | optional `"none"`: the endpoint needs no credential, so a table with no `env_key` and no bearer token passes the check. No effect on a table that names an `env_key`, nor on `openai`/`requires_openai_auth` providers (always `codex login status`) (Wave 29) For the `claude` engine only: `"subscription"` (default; the Claude subscription signed in through Claude Code), `"api-key"` (`ANTHROPIC_API_KEY`) or (wave 29b) `"endpoint"` (a third-party Anthropic-compatible endpoint named by the entry's `endpoint`); `"none"` is refused for it. |
| `reviewers[].panel` | `"always"` (default), `"weighty"` or (2026-10-07) `"light"`. `"weighty"`: joins a `-Panel` run only on `framing`, `decision`, `core-contract`, `acceptance` and `stuck`, or under `-PanelAll`. `"light"`: joins on the other purposes; on those five it is skipped (`light reviewer; purpose <p> is weighty - it stands in only when no entry of its label runs`) unless no other entry of its provider label runs once the whole roster is judged (every one skipped - unavailable, context, refused - or none): then it stands in, listed and recorded in `panel.members` as `stands in for #<n> (<that entry's skip reason>)` or `stands in (no other entry of label <label>)`; under `-PanelAll` or `-Require` it is seated like any entry. The single-reviewer walk ignores the weight |
| `reviewers[].engine` | (0.4.0) `"codex"` (default), `"agy"` or (wave 23) `"muse"`: the CLI that carries it (see "Engines"). For `agy` and `muse`: `provider` is a free label, `model` is required, `codex_config` and `auth` are refused; one label names one engine across the roster (Wave 29) `"claude"`: Claude Code headless (`claude -p`): `provider` is a free label (default `anthropic`), `model` is REQUIRED and must be one of the engine's table (aliases `opus`, `sonnet`, `haiku`, `fable` and the ids listed in "Engines (wave 29)", each optionally ending in `[1m]`), `auth` is `subscription`, `api-key` or (wave 29b) `endpoint` (then the closed model table does not apply: the id as the provider publishes it - and (E11) an Anthropic model id, i.e. an id or alias of the table or any `claude-*` id, is refused: the init event's `apiKeySource` is `none` on this route as on the subscription, so only a model the subscription cannot serve proves the billing), `codex_config` is refused. |
| `reviewers[].endpoint` | (wave 29b) object `{"base_url": "https://...", "env_key": "<VARIABLE NAME>", "timeout_ms": <optional>}`: REQUIRED with engine `claude` and `auth: "endpoint"`, REFUSED with `subscription` / `api-key` and on every other engine. `base_url` is an absolute https URL without credentials, query or fragment (sent as written as `ANTHROPIC_BASE_URL`); `env_key` is the NAME of the variable that holds the token (`^[A-Z][A-Z0-9_]{2,}$`; the operator sets it, the value is read at launch and never logged); `timeout_ms` is optional, 60000-7200000, default 3000000 (`API_TIMEOUT_MS`); an unknown key is refused. See "Endpoint mode" under "Engines (wave 29)" |
| `reviewers[].plan` | (wave 29b) optional slug (`^[a-z][a-z0-9-]{1,31}$`), allowed on every entry of every engine: the entries that share one plan share one quota. A quota-class failure (usage limit, 429) on any of them marks every entry of the plan out until the same reset time, and the plan is one scheduling group across engines; auth, transport and capability failures stay with their own route. Without `plan` nothing propagates |
| `reviewers[].lab` | (0.5.0, wave 26) optional: the lab behind the model (`"moonshot"`, `"deepseek"`, ...; canonical lowercase) for a panel's lab diversity. Omitted: the vendor of the model id's prefix (qwen alibaba, deepseek, kimi/k3 moonshot, glm zhipu, dola/seed bytedance, mimo xiaomi, gemini google, muse meta, gpt openai) - never the provider label - else a lab of its own (a routed panel warns); (wave 29b) a claude entry of auth `endpoint`: the lab of its base URL's host first (`api.z.ai` zhipu, `*.xiaomimimo.com` xiaomi, `api.kimi.ai` moonshot, `api.minimax.io` minimax) |
| `reviewers[].roles` | (wave 26) optional array of role names the entry is willing to take under `-Roles` ("Companions") |
| `reviewers[].timeout_sec` | (wave 26b, D11) optional integer 60-86400: this reviewer's main-turn timeout in place of the purpose's default (a panel member or a single run of the entry; an explicit `-TimeoutSec` still wins for all); ledger `timeout_source` `roster`; the panel's `Timeout:` line lists it (`3600 s per member; #7 alibaba :: qwen3.8-max 1200 s (roster)`) |
| `reviewers[].stall_sec` | (wave 26b, D12) optional integer 0-86400: this reviewer's stall cut in place of the default 900 s (`0` = off; an explicit `-StallSec` wins) |
| `reviewers[].context_tokens` | (wave 26b, D16) optional integer 32000-100000000: the reviewer's context window in tokens (e.g. `256000` for a plan that caps the model there). The prompt says `Your context window is M tokens: read only what the brief points to; prefer targeted reads.`; a fork/resume whose thread last carried more than 80% of it with this prompt becomes a new thread (ledger `mode_fallback`); a brief whose estimate alone exceeds 80% skips the entry before its start. (wave 28b, D15) The window reaches the ENGINE too: a codex reviewer gets `-c model_context_window=<n>` and `-c model_auto_compact_token_limit=<0.8 n>` on every turn (the Codex config keys; both present in codex-cli 0.155.1), recorded in the ledger's `context_window`; for agy and muse the key guards only the start (the prompt, the fork check, the skip) |
| `reviewers[].ext` | (wave 26) optional object, reserved for other implementations that share the file: validated as an object, otherwise ignored by the bridge (never read, never written) |
| `parallel` | (0.4.x wave 21) optional top-level object `{"<provider label>": <n>}`: a `-Panel` runs the members of one endpoint one after another; n >= 1 lets n members of that label run at once (see "The panel"). Every key must be a label the roster uses, every value an integer >= 1; (wave 29b) a key may also name a `plan` slug (the plan's members, across engines, run n at once; a label without its own value takes its plan's) |
| `require` | (wave 26) optional top-level object `{"<purpose>": ["<reviewer>", ...]}`: the reviewers a `-Panel` of that purpose must include - a roster position `#5`, a provider label, or `<provider> :: <model>` with an optional ` [<engine>]`; every matcher must name an entry (else the roster is unusable). `-Require` replaces it for one run, `-Require none` drops it ("Companions") |
| `ext` | (wave 26) optional top-level object, reserved for other implementations; validated as an object, ignored otherwise. `roster_version` stays `1` |

The allowed keys of an entry are `provider`, `model`, `codex_config`, `auth`, `endpoint`, `plan`, `panel`, `engine`, `lab`, `roles`,
`timeout_sec`, `stall_sec`, `context_tokens` and `ext`.

An unusable roster (an unknown key, `roster_version` other than 1, an empty or non-array
`reviewers`, the same `(provider, model)` twice, anything that does not parse) **refuses
every run, `-DryRun` included, naming the path**; an existing roster is never ignored.
(Wave 26b, D3) A provider label or model with surrounding blanks, or containing `::`, `[`,
`]`, `|`, `,` or `#` - the reviewer matcher's and the routing seed's delimiters - is refused
the same way (`roster entry #3: provider must not contain '::'`).

**Selection.**
- `-Provider <name>`: the roster does not choose, but that provider's entry supplies the
  model (when `-Model` is empty) and `codex_config` (when `-CodexConfig` is empty); ledger
  `model_source`/`extra_config_source` `roster`. When several entries share the label and
  `-Model` is not given, the FIRST one is used, with a console warning and a ledger
  `warnings[]` entry: `roster: label gemini names 2 entries; the first (gemini ::
  gemini-3.8-flash-high [agy]) is used - pass -Model for another`.
- `-Thread <uuid>`: the thread's own ledger entry fixes the reviewer (`provider_source`/
  `model_source` `-Thread`); its roster entry supplies `codex_config`. If that reviewer is
  unavailable, the refusal names what the roster would select for a new thread
  (`-Mode new`).
- Otherwise the bridge walks the roster in order and runs the first entry that passes the
  preflight (a usage limit with a future reset time, or one without a reset time from the
  last 60 minutes, is skipped). Every skipped entry is recorded with its reason; when none
  is available the run is refused, naming each entry and why, with nothing started.
  `-Model` without `-Provider` restricts the walk to entries of that model. The parent
  thread is then chosen within the selected lineage.
- The pick is printed and put in the handoff header, e.g. `Roster: <path> - position 2 of 3;
  skipped openai :: <model> (usage limit until <iso>)`; ledger `roster`.

**The panel.** `-Panel` sends the same brief to the roster entries it seats - (0.5.0, wave 26)
as many as its purpose needs, chosen by their track record ("Companions" below) - each as a
complete, independent consultation: its own preflight, recovery record, parent thread (the
newest of its own lineage, or a new one; `-Mode new` starts fresh threads for all; an agy
member starts a new conversation), consultation id, reply file
`handoffs/<NN>-<engine>-<ReplyName>-<provider lowercased>.md` (`codex`, `agy` or `muse`) and
ledger entry (`panel`). A roster may mix engines; `-Panel -Engine agy` runs only the agy
entries. `-MaxModelSteps` travels in the panel spec to the muse members (refused when the
panel has none); a muse member whose billing guard refuses is skipped (`refused: ...`).
Every member sees the findings that were open when the panel started, not a later
member's answer; a later panel on the same task does see this panel's findings (members are
not blind across waves). `-PanelAll` includes `weighty` and `light` entries whatever the purpose.
`-Panel`/`-PanelAll` need a roster and are refused with `-Provider`, `-Thread` or
`-Mode resume`.

**Members run in parallel (0.4.x wave 21, ROADMAP R11)**, each in a bridge process of its
own, so a panel takes about as long as its slowest member instead of the sum of all:

- *The plan is endpoint-aware.* Members that reach the same endpoint run one after another:
  the entries of one provider label are one endpoint, and so are labels whose entries
  resolve to the same provider fingerprint (two labels on one base URL; every agy label -
  they share one Google sign-in). Different endpoints run at once. The roster's optional
  top-level `"parallel": { "<provider label>": <n> }` lets n members of that label run at
  once (integers >= 1, labels the roster uses; anything else refuses the roster).
  `-PanelConcurrency <n>` caps the total on top: `0` (the default) no cap, `1` strictly one
  after another in roster order, `k` at most k at a time. The first output line says which
  (`at once`, `one after another`, `at most 2 at a time`), a `Concurrency:` line lists the
  endpoint groups, and each member's ledger `panel` record carries `concurrency` and `limits`.
  (Wave 29) The members of the `claude` engine are one scheduling group whatever their labels: they run ONE AT A TIME by default, and `"parallel": {"anthropic": 2}` raises it (two `claude -p` runs at once in one directory were observed to work, not guaranteed).
- *The panel run owns the task.* It holds `.consult.lock` for the whole panel (its record
  names the panel), so a single run, another panel or `codex-findings.ps1 -Status`/`-Rate` on
  the task is refused until the panel ends. It judges every recovery record of the task
  first, gives every member its consult number n and handoff number NN up front in seat
  order (wave 26: the order of `panel.routing.picked` - the roster order unless the panel is
  routed) - files and ledger entries keep that order whatever finishes first - and writes
  each member's recovery record `<task>/.consult.pending-<NN>.json` (`reserved`, naming the
  panel, n, NN and itself) before it starts any member.
- *A member proves its parent.* It accepts its spec only when its record names the same
  panel, n, NN and parent (pid + start time); it then rewrites the record with its own pid
  and start time and only after that checks that the parent is alive - a parent gone by then
  (even one that died before the rewrite) makes the member withdraw its record and stop,
  nothing started. So the record never reads inactive while the member runs, also when the
  parent dies later. Right before it starts its reviewer it checks the parent again and stops
  there, nothing started, if the parent is gone. It commits under
  the write lock ("Write order and atomic stores"): every member's findings, reviewer checks
  and ledger entry survive whatever order they commit in.
- *The run.* The panel run polls its members, prints one line per member as it finishes,
  and stops a member that outlives its guard (its `-TimeoutSec` + one format-repair turn and,
  for agy, one denial-retry turn of min(timeout, 300) s when enabled + (0.5.0) its timeout
  continuation's `-ContinueSec` + 60 s write lock + 120 s) with its process tree. It then prints every member's console output in roster
  order and the summary block with the panel's wall clock (one line per member: lineage,
  verdict or failure - `commit blocked`, `killed by the panel after N s` -, finding counts,
  or the skip reason; a member that left no ledger entry names its unused n and handoff, or
  its kept record), and removes the records of members that never started anything. Exit
  `0` only when every member produced a usable reply.
- A failing member does not stop the others. With `-PanelConcurrency 1` the old rule
  stays: a member that leaves surviving processes (its record stays in `survivors`) stops the
  remaining ones, recorded `skipped` with `not started: the previous member (<lineage>) left
  surviving processes (.consult.pending-<NN>.json state survivors); recover the task first`.
  At the default, the other members run on; the kept record blocks the task afterwards
  until it is recovered, as any interrupted run's does.
- If the panel run itself dies, its members finish and commit on their own; meanwhile a new
  consultation of the task finds the lock free but is refused by the member records (their
  writers, the members, are alive), and consumes them afterwards.
- **Residual (agy):** while members run at the same time, an agy member's read-only check
  ("Engines") leaves out the task's `sessions.json` and `findings.json` and the other members'
  handoff files (each with its atomic-write temp file `.<name>.<guid>.tmp`), which the
  siblings write meanwhile; an agy reviewer that writes its own task's stores is then not
  caught by the check (a store that no longer parses is still refused at the commit). Every
  other collab path stays monitored - so a consultation on ANOTHER task that commits during
  an agy member's run fails that member: run no other consultation in the repository beside
  a panel with agy members.

Example - three reviewers on three endpoints (add `-PanelConcurrency 1` to run the same
panel one after another under the same protocol):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 -Task cache-rewrite `
    -Panel -Purpose acceptance -ReplyName acceptance `
    -Brief .collab/cache-rewrite/handoffs/07-claude-acceptance.md
```
```
Panel 1a2b3c4d: 3 of 3 roster entries run, at once (roster <path>; panel id 1a2b3c4d-...)
  #1 openai :: gpt-5.1 - member, n=8, handoff 12
  #2 ZAI :: glm-5.3 - member, n=9, handoff 13
  #3 mimo :: mimo-v2.6-pro - member, n=10, handoff 14
Routing: roster order (fallback: no ratings - no eligible reviewer has 3 ratings in 90 days) - size 4 (the default of purpose acceptance)
  eligible: #1 openai :: gpt-5.1 (lab openai by vendor; score 1.125 neutral), #2 ZAI :: glm-5.3 (lab zhipu by vendor; score 1.125 neutral), #3 mimo :: mimo-v2.6-pro (lab xiaomi by vendor; score 1.125 neutral)
  picked  : 1. #1 openai :: gpt-5.1 (roster), 2. #2 ZAI :: glm-5.3 (roster), 3. #3 mimo :: mimo-v2.6-pro (roster)
Concurrency: at once - endpoint groups: openai x1, ZAI x1, mimo x1; -PanelConcurrency 0 (no cap)
  panel member 3 of 3 finished: mimo :: mimo-v2.6-pro - usable reply (231.4 s)
  ...
Panel 1a2b3c4d: 3 of 3 entries ran (asked 3, started 3, usable 3; wall clock 402.7 s; at once)
  openai :: gpt-5.1      ACCEPT  0 blocker, 0 major, 2 minor  prior: 3 fixed  398.2 s  handoffs/12-codex-acceptance-openai.md
  ...
```

Members run as child bridge processes through the internal `-PanelSpec` parameter; never
pass it yourself. There is no tooling yet for linking corroborating or contradicting
findings across members (ROADMAP R9): compare the replies yourself.

### Companions (0.5.0, wave 26): panel size, routing, required reviewers, roles

**Size by stakes.** A panel starts as many members as its purpose needs: `chore`, no purpose
and `checkpoint` **1**, `diff-review` **2**, `framing` and `decision` **3**, `core-contract` and
`acceptance` **4**, `stuck` **every eligible member**. `-PanelSize <n>` (n >= 1) overrides it;
`-PanelAll` takes every eligible member, the `weighty` and `light` ones included (`-PanelSize`
with `-PanelAll` is refused). *Eligible* = available by the roster walk's verdict, past the
weighty and light gates, matching `-Engine`/`-Model` - one set for the size, the ranking, the
draw and the exploration. The size bounds the members STARTED and is capped at the eligible count; there is
**no backfill** - a member that fails (or hits its peak window at launch) is not replaced. An
eligible entry without a seat is listed `not picked: panel size k` (ledger member state
`not-picked`) and is never reported as a skip. The first line says `2 of 5 roster entries
run`, the summary `Panel <id8>: 2 of 5 entries ran (asked 2, started 2, usable 1; wall clock
...)` and one `not picked (panel size 2): ...` line; every member's ledger `panel` record gets
`asked`, `started` and `usable` when the panel ends. (Wave 26b, D2) `asked` is the size
REQUESTED - the purpose's, `-PanelSize` (`-PanelAll`, `stuck`: every eligible member) - not the
seats after the cap; when fewer members are eligible than asked the run warns `panel size
reduced: asked 4, eligible 2` (console, handoff header, ledger `warnings[]`) and the ledger keeps
`panel.routing.size_asked` beside `size`. A `framing` or `decision` panel of fewer
than 2 members warns (`panel floor: ...`, console and ledger `warnings[]`) unless `-PanelSize`
was given. *Diminishing returns:* past about five diverse members findings tend to repeat -
an operational heuristic, not a rule; the scoreboard's `UNIQ` column (findings no other member
of the panel raised at the same place) measures it.

**Routing by the track record.** `-PanelOrder routed` (the default) draws the seats by the
members' routing scores; `-PanelOrder roster` keeps the roster order (no draw, no exploration).
The score (`Get-RoutingScore`, shared with `codex-scoreboard.ps1`) reads the judge's marks
(`codex-findings.ps1 -Rate`) of **every task of the repository** from the last 90 days by the
consultation's own time: `w = (yes + 0.5 partly + 1) / (n + 2)` - a rate with a prior that pulls
few marks to 0.5 - scaled into `[0.25, 2]` (`0.25 + 1.75 w`; neutral `1.125`), for the
reviewer's (purpose, topics) when the pooled topic credit reaches 3 marks (a mark credits each
of its t topics `1/t`), else its purpose with >= 3 marks, else its all-purpose rate with >= 3,
else neutral. **While no eligible member has 3 marks, the panel keeps the roster order**
(`routing.fallback: "no ratings"`) - no shuffle without evidence.

- *The draw* is exact and the same on Windows PowerShell 5.1 and PowerShell 7: seed =
  SHA-256 of `<task>|<purpose>|<brief sha256>|<lineages>|<nonce>` where (wave 26b, D3) every
  field is written `<len>:<value>` (len = its UTF-8 byte count) and `<lineages>` is the eligible
  lineages sorted ordinally, each `<len>:<lineage>`, joined by `,` - e.g.
  `1:t|7:framing|3:abc|26:6:a :: x,6:b :: y,6:c :: z|2:42` - so no value can shift a boundary
  (the seeds, and so the seats of a given nonce, differ from wave 26's; the independent
  reference implementation is `tests/reference-draw.py`); the nonce is `-PanelSeed <n>`, else
  `CODEX_CONSULT_TEST_PANEL_SEED`, else
  today's UTC date - a dry run and the real run of the same day draw the same seats. Seat s:
  SHA-256(seed || s as 4 bytes big-endian); its first 8 bytes (top 53 bits / 2^53) are a uniform
  u, the next 8 decide exploration (below 0.2: the seat is a uniform pick `floor(u x pool)`);
  otherwise the first entry, in roster order, whose running weight sum exceeds `u x` the pool's
  weight sum wins and leaves the pool.
- *Lab diversity* is a reserve, not a first pass, over the seats left after the required (wave
  26b, D5): `reserve: min(seats left after the required, labs with an entry >= neutral not yet
  seated)` - while fewer reserve seats are taken, a seat draws only from labs not yet seated
  whose entries score >= neutral (an entry below neutral never earns a lab seat); the remaining
  seats draw from every eligible entry left. `panel.routing.reserve` records the reserve seats
  applied (the `lab-*` rules), so the claim is auditable; the seats are those of wave 26 (the
  statement changed, not the draw). The lab is the roster entry's `lab`, else the vendor of
  the model id's prefix, else a lab of its own (`routing: no lab known for ...`, a warning).
- *The record:* every member's ledger `panel.routing` (field table in "The ledger") and the
  console print the same - the mode and the fallback, the seed and the nonce, every eligible
  entry with its lab, score and basis, the seats in order with the rule that filled each
  (`required`, `roster`, `lab-draw`, `lab-explore`, `rank-draw`, `rank-explore`):

```
Routing: routed by the ratings - size 3 (the default of purpose framing); seed 4be0c2a91f3e (nonce 2026-09-27 from date); exploration 0.2 per slot
  eligible: #1 openai :: gpt-6-astra (lab openai by vendor; score 1.708 purpose of 4), #2 ZAI :: glm-5.3 (lab zhipu by vendor; score 1.125 neutral), ...
  picked  : 1. #1 openai :: gpt-6-astra (lab-draw), 2. #4 byteplus :: deepseek-v4.1-flash (lab-draw), 3. #2 ZAI :: glm-5.3 (lab-explore)
```

**Topics.** `-Topic security,tests` names what a consultation is about (lowercase slugs; ledger
`topics[]`, copied onto its mark); a routed panel with topics scores its members on those
topics first. `codex-scoreboard.ps1 -By topic` shows the rows per topic.

**Required reviewers.** `-Require <reviewer>[,<reviewer>...]` (`-Panel`, or a single run with
`-Provider`) names who must take part: a roster position (`#5`), a provider label (every entry
of it) or `<provider> :: <model>` with an optional ` [<engine>]` - compared on the roster's own
provider, model and engine, never on a display string; a model-less entry is named by its
position or its label; a matcher that names no entry is refused. A panel without `-Require`
takes the roster's `"require": {"<purpose>": [...]}` for its purpose; `-Require none` drops it.
A required reviewer is judged with the roster walk's verdict (stricter than a plain `-Provider`
run: a usage limit without a reset time is out for its 60 minutes) - one that is out refuses the
run **before anything starts, exit 5**, naming who, why and when it is back (`required reviewer
not available (-Require): #1 openai :: gpt-6-astra (usage limit until ...; back Sun 20:35, in
2d 10h); nothing was started - ...`); the dry run does the same. In a panel the required take
their seats first (a `weighty` one on a light purpose and a `light` one on a weighty purpose
included), and a required member that produces no usable reply stops the panel at the next member (no further member starts), exit 5;
the ledger's `panel.routing.required` names them.

**Roles.** `-Role <name>` gives a single run - or every member of a panel - a narrow role;
`-Roles a,b` (a panel only, not with `-Role`) gives one role per member, by SCORE RANK among the
seated members (highest first). (Wave 26b, D4) The assignment is an exact matching, not a
greedy pass: a role some seated member is willing to take (its roster entry's `"roles": [...]`)
goes to a willing member, and among the assignments that honour every such willingness each
role in order gets the best-ranked member possible (an augmenting-path matching - no size
bound); only when no assignment honours every willingness do the roles go by the wave 26 greedy
order (each to the best-ranked willing member left, else the best-ranked left) - and the run says
so: a warning and the ledger's `panel.roles_note`. The role's text - `<CollabDir>/roles/<name>.md`
of the repository, else the plugin's `templates/role-<name>.md` (`edge-cases`, `security`,
`tests`, `docs` ship) - goes into the prompt after the ask and before the brief (never inside
the output contract); the reply format, the verdict rules and the read-only rules do not change.
Names are slugs checked before any path is built; an unknown role and more roles than members are
refused, nothing started. (Wave 26b, D1) The role text reaches external reviewers, so the file
must be a REGULAR file inside its roles directory: no symbolic link or junction on the file or
on the roles directory itself (`<CollabDir>/roles`, the plugin's `templates`), its full path
inside that directory - anything else refuses the run before any prompt, handoff, ledger entry or
process exists (`-Role: role file refused: ... is a directory link (reparse point), not a regular
file`). (Wave 26c, D6 - F26-6, an accepted limitation) A hard link is indistinguishable from the
file itself, and the check and the read are separate steps: the check defends against reparse
points and against paths outside the roles directory, not against a hostile repository. Ledger
`role`.

**Council rules** (the `consult-codex` skill has the full list): the coordinator is an
equal participant and the judge by default; a hard question can hand the judge role to
one reviewer explicitly with a `-Purpose decision` consultation that points at the other
members' reply files, recorded in `state.md`. A provider without a credential or tokens is
simply not used, and a fallback reviewer's reply is never presented as the primary's.
Disagreement is the signal: record it in `state.md` until evidence settles it. Give
bounded search/extraction work to cheap members with `-Purpose chore` and put extracts,
not raw files, into a weighty brief. Acceptance authority for a release stays with the
reviewer who raised the findings.

---

## Engines (0.4.0): Gemini through the Antigravity CLI (`agy`)

An **engine** is the CLI that carries a consultation. `codex` (`codex exec`) is the default
and everything above describes it. `agy` - Google's Antigravity CLI, the official headless
client of the Gemini models under a Google AI Pro plan - enforces the reply schema natively
(`--json-schema`), which `codex exec` cannot promise for every endpoint. The ledger, the
handoff files, findings, ratings, the panel, the scoreboards, the preflight, the lock and
the recovery record are the same for both. The design and its review round are ROADMAP
R10; a `claude` engine (Claude Code headless) is planned as the next row of the same
engine table (`$script:Engines` in `codex-consult-common.ps1`).

**Choosing it.** A roster entry `{ "provider": "gemini", "engine": "agy", "model":
"gemini-3.8-flash-high" }`, or on the command line `-Engine agy -Provider gemini -Model
gemini-3.8-flash-high` (without a roster the label defaults to `gemini`). For agy the
provider is a free LABEL (the lineage's provider) and the model is REQUIRED - the full
id, whose last part is the reasoning tier (`gemini-3.8-flash-{high,medium,low}`,
`gemini-3.1-pro-{high,low}`; `agy models` lists them). One label names one engine across
the roster; `codex_config` and `auth` are refused on an agy entry. `-Engine` without
`-Provider` restricts the roster walk (and `-Panel`) to that engine's entries. Solo runs on
the weighty model need no new mechanism: a second entry with the same label and another
model is legal (the duplicate rule is provider + model), e.g.
`{ "provider": "gemini", "engine": "agy", "model": "gemini-3.1-pro-high", "panel":
"weighty" }` - a panel then routes weighty purposes to it, and `-Provider gemini -Model
gemini-3.1-pro-high` picks it for a single run.

**The invocation.** From the repository root:
`agy -p= --input-format stream-json --output-format stream-json --model <m> --json-schema
<plugin>/schemas/consult-reply.schema.json --print-timeout 0 --sandbox
--disable-slash-commands [--conversation <thread>] [--effort <v>]`. The prompt travels as
ONE NDJSON line `{"event":"user","message":{"content":"<prompt>"}}` on stdin (UTF-8, no
BOM, one LF) - no argv length limit, no cmd.exe quoting. `--print-timeout 0` is pinned
because an agy-side timeout looks like success (partial output); the bridge's
`-TimeoutSec` process-tree kill is the only timeout. Effort: nothing is sent (`effort_sent`
`null`, mapping `model-tier`) - the tier is part of the model id and the model id is the
lineage; `-NativeEffort <v>` sends `--effort <v>` verbatim and agy's own conflict check
applies. The prompt of an agy run carries one more line: `Tools: you may read files of the
repository; you have NO permission to run commands in this consultation - never call
run_command; make NO file changes; a check that needs a command belongs under ## Requested
checks.` The launcher: `agy.exe` on PATH (winget package `Google.AntigravityCLI`, or the
official installer under `%LOCALAPPDATA%\agy\bin`), else `-EngineExe <path>` or
`CODEX_CONSULT_AGY_EXE`.

**Refused for agy** (one message each, nothing started): `-Mode fork` (agy has no fork),
`-Sandbox workspace-write`, `-CodexConfig`, `-SchemaTransport output-schema` (it takes
`native` or `prompt-only`). **Mode:** `new` by default - a conversation grows with every
turn, so it is resumed only on request: `-Mode resume` (the newest verified conversation of
the lineage) or `-Thread <uuid>` sends `--conversation <thread>`.

**The reply.** stdout is saved as `handoffs/NN-agy-<slug>.events.jsonl`. The reply is the
`result` event's `structured_output` (never its `response` text when `structured_output`
is there - the text carries extra keys), extracted atomically to
`handoffs/NN-agy-<slug>.reply.json` BEFORE any validation, then validated like a codex
reply; without `structured_output` the `response` text goes through the prose gate and the
format repair (one turn on `--conversation <thread>`, in the main turn's transport: `--json-schema`
on a native run, none on a prompt-only one - the schema then travels in the repair prompt,
wave 23b). The thread is
`result.conversation_id`.

**A run FAILS** (nothing ingested, the reply kept and named) on: exit code != 0; a
malformed event stream (not exactly one `result` event, a line that does not parse - the
last line counts as a partial line only when the bridge killed the process or it exited
non-zero; after exit 0 trailing garbage fails the run) - class `transport`; no `result` event (the init id is kept as
`thread_candidate` only); an init id different from the result's (class `unknown`);
`status` other than `SUCCESS`; on resume the `warning: conversation "<id>" not found`, a
result without an id, or another id (`failed: parent conversation <p> not found, agy started
<new>`, class `unknown` - the new conversation is never a parent); an id that is not a
uuid; `returning partial output` / `print timeout` on stderr; an empty reply (with agy's
denial notice: class `permission`, message = that line). The same conversation-id checks
apply to a format-repair or denial-retry turn: a repair that lands in a new conversation is
a failed repair and nothing from it is ingested.

**F11 and the denial retry.** When the model calls a tool headless print mode cannot grant
(e.g. `run_command`), agy auto-denies it and may end the turn with exit 0, `SUCCESS`, an
empty response and `jetski: no output produced - a tool required the "command" permission
that headless mode cannot prompt for, so it was auto-denied...` on stderr. With
`-DenialRetry 1` (the default) the bridge then runs ONE more turn on the same conversation:
the output contract, `Your previous turn produced no output: the tool run_command was
auto-denied (headless print mode has no "command" permission). Do NOT call it again; answer
from what you have read, as the JSON object.`, the field meanings and the consultation id
(never the brief), `--json-schema` on a native run (wave 23b: none on a prompt-only run, the
schema then travels in the retry prompt), `min(-TimeoutSec, 300)` s, same lock and recovery
record, its events in `handoffs/NN-agy-<slug>.denial-retry.events.jsonl`. Ledger
`denial_retry {attempted, reason, succeeded, thread, wall_seconds, usage, events}` (`events`
names that stream, as `format_retry.events` names a repair turn's); a handoff line
`Denial retry: succeeded|failed ...`. A denial notice WITH a usable reply is ingested with
a ledger `warnings[]` entry and a `Warnings:` handoff line.

**F12: read-only is NOT enforced by agy.** Its `--sandbox` restricts the terminal only
(a `write_to_file` call created a file with no prompt; `--mode plan` changes nothing). The
bridge therefore compares, before and after every agy turn, the working tree (its tracked
and untracked files, by content - wave 24c: a commit or a moved HEAD that leaves every file as it
was is no change, only `revision_moved`), the WHOLE collab directory (every file under
`-CollabDir`, recursively: every task's `findings.json` / `sessions.json` / `state.md` and
handoffs; the bridge's own `.consult.*` files and this run's own `NN-agy-<slug>.*` files
excepted - and, for a member of a panel whose members run at the same time, the task's two
stores and the other members' handoffs, see "The panel"), the brief and the artifacts, and
fails the run when any of them changed: `failed:
the working tree changed during the run (by the reviewer or anyone else): <n> files: <list>
- agy's sandbox does not block writes` (or `the collab directory changed during the run (by
the reviewer or anyone else): <n> files: .collab/<task>/...`), class `permission`, the reply
kept and named, nothing ingested. Read-only is thereby **enforced by evidence for tracked and
untracked files and the collab directory; not for gitignored paths, submodules or files
outside the repository** - a write there goes unnoticed (the git manifest does not list
ignored files and does not recurse submodules). Ledger `sandbox`: `read-only (requested;
enforced by evidence for tracked and untracked files and the collab directory, not for
gitignored paths, submodules or files outside the repository; agy --sandbox restricts the
terminal only)`. The check cannot tell who changed a file: a file changed by YOU during the
run - a brief saved into the handoffs, an edit in the tree, another consultation of this
repository writing its own handoffs and ledger - fails it too. **Do not edit the repository
or the collab directory, and run no other consultation here, while an agy consultation
runs.**

**Sign-in and cost.** agy keeps its credentials in the OS keyring after the USER signed in
interactively (run `agy` once); the bridge never handles a login. The preflight's credential
check is `agy models` (a network round-trip, usually ~2 s but observed at 1.7-15+ s, so the
timeout is 45 s; once per listing): exit 0 and at least one `<id><TAB><name>` line -> `ok:
signed in (N models)`; sign-in wording -> `missing`; anything else, a timeout included ->
`unknown` (refused). No call at all when THIS repository's ledgers hold a usable reply on the
agy endpoint (its fingerprint) from the last 60 minutes (consult clock): the sign-in is
evidenced - `ok: signed in (usable reply <m> min ago)`, the listing shows the same text; the
endpoint health stays in front of it (a recorded auth failure or a usage limit still
refuses). The hook does not make the call (`not checked (launcher present)`, or `available`
on that ledger evidence). Every agy call carries about 13-25k tokens of the CLI's own prompt
and tools, and a resume replays the conversation (a resumed turn was observed at 54k input
tokens); a diff review on `gemini-3.8-flash-high` reads the tree - the first live panel's
took 605 s at 1.6M input + 5.9M cached tokens. The ledger records `usage` per run. Google AI
Pro refreshes the quota every five hours until a weekly limit; the CLI cannot show the
remaining quota. A lineage binds engine + label + model, not the signed-in Google account
(TECH_DEBT T7).

**Recovery.** The recovery record names each running turn's event stream (`events`, also
for codex): a run that stops before its ledger entry leaves `the raw event stream of that
run is at <path> (it may hold a usable reply); no ledger entry was written` in every message
about its reservation (`-List`, the dry run, the next run). An interrupted `agy.exe` is found
by the recorded launcher's name as well as by the launcher in a command line.

**Listings.** `codex-scoreboard.ps1` and `codex-findings.ps1 -Stats`/`-Rate` show an agy
lineage as `gemini :: gemini-3.8-flash-high [agy]`; the panel summary and the roster lines
do too.

**A change forces class `permission` (wave 23).** For agy and muse alike, a change the tree
check detects fails the run as class `permission` even when the run had ALREADY failed for
another reason: that reason stays the provider failure's message and the outcome adds `;
also: <the change>` (before wave 23 an already failed run kept its first class).

## Engines (wave 23): Meta's Muse Code CLI (`muse`)

`muse` drives Meta's Muse Code CLI headless for the **Muse Code subscription** (the Everyday
plan: 10-50 prompts per 5 hours). The subscription works only through Meta's own CLI signed
in by browser; an API key bills per token instead - so, as with `agy` for Gemini, the bridge
drives the vendor's CLI. Everything the engines share (ledger, handoffs, findings, ratings,
the panel, the scoreboards, the preflight, the lock, the recovery record, the tree check) is
as described for agy above; what differs:

**Choosing it.** A roster entry `{ "provider": "meta", "engine": "muse", "model":
"muse-spark-1.3" }`, or `-Engine muse -Model muse-spark-1.3` (the label defaults to `meta`).
caps-v1 declares the two live-verified subscription models: `muse-spark-1.3-contributor` (the
CLI's default; Meta may train on its inputs) and `muse-spark-1.3` - which one a roster uses
is the installing USER's decision (the `setup-providers` skill asks). Another model (the docs
also list the 1.2 pair and 1.1) needs `-NativeEffort <value>`.

**The invocation.** From the repository root: `muse exec --json --prompt-file <P>
[--output-schema <plugin>/schemas/consult-reply.schema.json] --model <m> [--reasoning-effort
<e>] --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell
--approval-mode never [--max-model-steps <n>] [--session-id <thread>]`. The prompt is written
to the turn's OWN prompt file (UTF-8, no BOM) and named by `--prompt-file`; stdin stays
empty. Every turn - the main turn and a format repair - builds its argv from one turn-options
object through the engine's adapter and parses its stream through the engine's own parser
and failure rules (wave 23 routes agy's denial retry and format repair through its adapter
the same way). Effort: vocabulary `muse` (mapping `muse-v1`: `low`, `medium`, `high`, `xhigh`
as is) sent as `--reasoning-effort`; the repair turn sends `low`. `-MaxModelSteps <n>` sends
`--max-model-steps <n>` (muse only; without it the CLI's own default applies; the bridge's
`-TimeoutSec` stays the outer bound; a `-Panel` passes it to its muse members). The prompt's
tools line: `Tools: you may read files of the repository (read_file); writing files, the shell
and the web tools are disabled in this consultation (--disable-write --disable-shell
--disable-web-tools) - do not try them; make NO file changes; a check that needs a command
belongs under ## Requested checks.`

**The launcher.** `-EngineExe <path>` (it names the launcher of the SELECTED engine other
than codex: `-Engine`'s, else the `-Provider`'s roster entry's, else the only such engine of
the roster - two such engines without `-Engine` are refused as ambiguous;
`codex-providers.ps1 -EngineExe` binds the same way), then `CODEX_CONSULT_MUSE_EXE`, then
`muse.cmd` / `muse.exe` / `muse` on PATH, then the vendor's install location
`%LOCALAPPDATA%\Programs\muse\muse.cmd` on Windows (the installer adds that directory to the
USER Path, which a bridge started before the install does not see). `muse.cmd` runs a
PowerShell launcher that runs the versioned binary (and may update it). cmd.exe expands
`%VAR%` even inside quotes, so a turn whose arguments contain `%` (a `TEMP` path) through a
`.cmd` launcher is refused before launch - set `TEMP`/`TMP` elsewhere or point `-EngineExe`
at the `.exe`. `reviewer.harness` is `muse-cli <version>` from `.muse-version` next to the
launcher (else `.muse-release-info.json`'s `version`, else `muse --version`, which spends no
prompt); an unseen version is recorded, never refused.

**Billing is a launch invariant.** A muse run is REFUSED - nothing started, no ledger entry -
while `META_API_KEY` or `MODEL_API_KEY` is set in the bridge's environment: `the muse engine
is refused: META_API_KEY is set: a muse run would bill per token instead of the Muse Code
subscription; unset it (the muse process would inherit it)`; and while the sign-in's
`providers.meta.mechanism` is anything but `oauth`. Since wave 23b the guard is fail-closed: a
muse run needs an ESTABLISHED oauth sign-in, so the keychain backend, no `auth.json`, no
`providers.meta`, no `mechanism` or a file that does not parse refuse it too: `` the muse
engine is refused: the Muse sign-in is not established as oauth (<the cause>): a muse run might
bill per token instead of the Muse Code subscription; set TBH_CREDENTIAL_BACKEND=file and run
`muse login` ``. There is no override flag. It is not a preflight check:
`-SkipPreflight` never bypasses it; a roster walk and `-Panel` skip the entry (`refused:
...`) with and without `-SkipPreflight`; it is checked again right before every launch;
`codex-providers.ps1` shows the row as `unavailable (refused: ...)`. Only variable names are
ever shown, never a value. There is no roster opt-out for per-token billing. Ledger
`reviewer.provider_config.credential_mechanism` records the mechanism (an enum, never a
secret; `oauth` in every entry, since no other mechanism launches).

**Sign-in (preflight).** `muse login` shows a device code the USER approves in the browser
(the bridge never handles it). On Windows the keychain write fails, and the bridge cannot read
a keychain anywhere, so the file backend is required: the USER sets the user variable
`TBH_CREDENTIAL_BACKEND=file` before `muse login`,
and the credential lives in `~/.config/muse/auth.json`. The preflight reads that file for the
presence of `providers.meta` and its `mechanism` only - the parsed object is never logged or
written, a parse error is reported without its text, nothing is started (so the check also
runs under `-NoNetwork` and in the SessionStart hook): `ok: signed in
(~/.config/muse/auth.json: providers.meta, mechanism oauth)`; no file or no `providers.meta`
-> `missing: not signed in: ...`; another backend (the keychain) or no mechanism -> `unknown:
sign-in not checkable ...`. Since wave 23b both refuse the LAUNCH (the billing guard above:
no oauth sign-in is established) - before the preflight, in a dry run, a roster walk and a
panel too, and `-SkipPreflight` does not change that; the fix is `TBH_CREDENTIAL_BACKEND=file`
and `muse login`. The file shows the
shape of a sign-in, not that it is still valid: an expired sign-in shows as a failed run. The
ledger short-circuit (a usable reply on the endpoint within 60 minutes) and the endpoint
health apply as for agy. One Meta sign-in is one endpoint: every muse label shares the
fingerprint `cc-engine-v1|muse`, so a usage limit hit by one muse entry blocks all of them
until its reset.

**The reply.** stdout (`handoffs/NN-muse-<slug>.events.jsonl`) is MSP JSONL - every record
`{schema_version, id, stream{kind, id}, sequence, record_type, payload_type, payload, ...}`.
The reply is the `text` of the ONE `run_terminal` record (`run.terminal.completed`),
extracted atomically to `handoffs/NN-muse-<slug>.reply.json` before any validation; with
`--output-schema` it is the JSON object (validated locally too), without it (`-SchemaTransport
prompt-only`) the prose goes through the prose gate and the format repair (at most one turn,
`--session-id <thread>`, its own prompt file, in the main turn's transport - wave 23b: a
prompt-only run's repair passes no `--output-schema` either, its prompt carries the schema;
never after a failed run). The thread is the ONE session stream id (`stream.kind` `session`);
the run is the ONE run stream the session links (`session.run.linked`, on the session stream),
and the evidence is bound to it (wave 23b): every `run.model.configured` record must sit on the
session stream and name that run in `payload.run_stream`, and so must the completed
`run_terminal` - the real CLI writes every record that way. The records carry no token
usage (ledger `usage` `null`); ledger `engine_run {turns, max_model_steps,
msp_schema_version}` counts the turns started - each one spends a subscription prompt.

**A run FAILS** (nothing ingested; the reply kept and named when there is one) on: exit 2
(`muse exit 2 (usage error) - <the error line>`, class `capability`); exit 130 or 143
(`stopped by a signal`, class `transport`; the bridge's own timeout kill reads `timeout after
<n> s`); any other non-zero exit, with the terminal's reason as the message - a reason that
names the step cap is `max model steps reached` (class `capability`), anything else goes
VERBATIM through the shared classifier (a usage-limit wording is class `quota`, with
`retry_after` when it names a reset; Meta's own wording is not known yet); a malformed stream
(class `transport`): a line that does not parse (the last one may be partial only after a
kill or a non-zero exit), a record whose `schema_version` is not `1` (`unsupported MSP version
<n>` - fail closed), two session streams, two `run_terminal` records, a `run_terminal` off the
session stream, evidence of foreign provenance (`ambiguous provenance: ...`, wave 23b: a
`session.run.linked` or `run.model.configured` record off the session stream - a nested or
sub-stream record -, a link naming no run, two linked runs, a model record or a completed
terminal naming another run, a model record with no run linked); no `run_terminal` record; no session; on resume or repair a session other than
the requested one (`parent session <p> not found, muse started <s>`, class `unknown` - the new
session is never a parent); a terminal other than `completed`; a session id that is not a
uuid; `run.model.configured` naming another model than the one asked (`model drift: asked X,
served Y`, class `capability`) or none. A resume whose CLI silently started a fresh session
under the requested id cannot be told apart from a real resume (the stream would echo the id).

**Mode and refusals.** `new` by default; `-Mode resume` or `-Thread <uuid>` sends
`--session-id <thread>`; `-Mode fork`, `-Sandbox workspace-write`, `-CodexConfig` and
`-SchemaTransport output-schema` are refused. There is no denial retry: the write, shell and
web tools are off, so nothing is auto-denied (ledger `denial_retry` `null`).

**Read-only: flags plus evidence.** Muse runs with `--disable-write --disable-shell
--disable-web-tools --approval-mode never`, and the bridge runs the agy tree check (the
working tree's tracked and untracked files, the WHOLE collab directory, the brief, the
artifacts). (Wave 26b, D9) Because the bridge's own flags disable muse's writes, a change the
check finds is NOT the reviewer's - another party wrote it (the coordinator's `state.md`, a
commit): it becomes a WARNING and the reply stays usable - `warnings[]` (console, handoff
header, the summary's `warning    :` line) `the collab directory changed during the run (1
file: .collab/t/state.md) - muse ran write-disabled, the change is not the reviewer's`, ledger
`tree_check {outcome: "warned", files: [...]}`; a run that failed for its own reason keeps that
reason and class (no forced `permission`). Before wave 26b such a change failed the run as class
`permission` (a panel member of another repository was lost that way while its coordinator
wrote `state.md`). agy keeps the failure (its `--sandbox` does not block writes, F12). The
coordinator's side: while an agy or muse member runs, write nothing under the collab directory
or the working tree (the skill's "Live members" rule). The boundary is
agy's: read-only is **enforced by evidence for tracked and untracked files and the collab
directory; not for gitignored paths, submodules or files outside the repository** - and not
for reads: the native `read_file` tool is not confined to the repository, so the bridge does
not keep a file outside it from being read. Ledger `sandbox`: `read-only (requested; muse
--disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence
for tracked and untracked files and the collab directory, not for gitignored paths,
submodules, files outside the repository or what the reviewer reads)`.

**Listings.** `codex-providers.ps1` shows one row per muse label (`KIND` `engine muse`,
`ENDPOINT` `muse (<launcher>)`, `EFFORT` `muse (2 declared models)`, transport `native`); the
scoreboards and the panel summary show `meta :: muse-spark-1.3 [muse]`.

---

## Engines (wave 29): Claude Code headless (`claude`)

`claude` drives Claude Code headless (`claude -p`) for a **Claude subscription** (or, per roster entry, an
Anthropic API key, or - wave 29b - a coding plan's Anthropic-compatible endpoint: "Endpoint mode" below). The subscription works only through Anthropic's own CLI signed in by the user; as with `agy`
for Gemini and `muse` for Muse, the bridge drives the vendor's CLI and never calls the API directly (ROADMAP R10,
with R22: the reviewer runs with everything but reading switched off). Everything the engines share (ledger,
handoffs, findings, ratings, the panel, the scoreboards, the preflight, the lock, the recovery record) is as
described for agy above; what differs:

**Choosing it.** A roster entry `{ "provider": "anthropic", "engine": "claude", "model": "claude-opus-5-5",
"auth": "subscription", "panel": "weighty", "context_tokens": 1000000, "timeout_sec": 1800 }`, or `-Engine claude
-Model sonnet` (the label defaults to `anthropic`). `model` is REQUIRED and must be one of the engine's model table:
the aliases `opus`, `sonnet`, `haiku`, `fable` and the ids `claude-fable-5-1`, `claude-fable-5`, `claude-opus-5-5`,
`claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-sonnet-5-5`, `claude-sonnet-5`,
`claude-sonnet-4-6`, `claude-haiku-5-5`, `claude-haiku-4-5` - each may end with `[1m]` (the 1M context variant;
claude entries only).
Which model a roster uses is the installing USER's decision (the `setup-providers` skill asks). `auth` (engine claude
only) is `subscription` (default), `api-key` or `endpoint`; `codex_config` and `auth: none` are refused. The lab of a
claude entry is `anthropic` for a model or label starting `claude`, `opus`, `sonnet`, `haiku` or `fable`. Other
vendors' models go through this engine only in endpoint mode (below), where the model table does not apply and the lab
comes from the endpoint's host. Reply files are `handoffs/NN-claudecode-<slug>.*` - the prefix is
`claudecode`, not `claude`, because `claude` is the coordinator's default brief prefix. Ledger `sandbox` is
read-only; `-Sandbox workspace-write` is refused.

**The invocation.** From the repository root, the prompt on stdin (plain UTF-8, never argv): `claude -p
--output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools
Read,Grep,Glob --permission-mode dontAsk --model <m> [--effort <e>] [--json-schema <schema text>] [--max-turns <n>]
[--add-dir <dir>...] (--session-id <minted uuid> | --resume <thread> [--fork-session])`. The schema text travels in
argv (whitespace removed), so the arguments are quoted by the C runtime rules (`\"`); `--add-dir` appears only for a
rooted `-CollabDir`, a brief or artifacts outside the repository. Schema transport `native` (default,
`--json-schema`) or `prompt-only`. Effort: vocabulary `claude` (mapping `claude-v1`): `low`, `medium`, `high`,
`xhigh` as is, sent as `--effort`; `max` only through `-NativeEffort`; the repair turn sends `low`. `-MaxModelSteps
<n>` sends `--max-turns <n>`. A prompt over 1 MiB (UTF-8 bytes on stdin) is refused before the start (`brief too
large for this engine: ...`).

**The launcher.** `-EngineExe <path>`, then `CODEX_CONSULT_CLAUDE_EXE`, then `claude.exe`, `claude.cmd`, `claude`
on PATH, then the native install location `%USERPROFILE%\.local\bin\claude.exe` (`~/.local/bin/claude` elsewhere).
`reviewer.harness` is `claude-cli <ProductVersion>` from the native `claude.exe` file metadata (e.g. `claude-cli
2.1.285.0`), else `claude --version` (an npm shim), else `claude-cli (version unknown)`.

**Lineage.** A new thread's session id is MINTED by the bridge (`--session-id <uuid>`), so it is known before the
first byte. `-Mode resume` (or `-Thread <uuid>`) sends `--resume <thread>` and the same id must come back; `-Mode
fork` sends `--resume <parent> --fork-session` and the answer must be a new uuid, not the parent. Every secondary turn
(a denial retry, a format repair, a timeout continuation) resumes the thread. The transcripts live in Claude Code's
own projects directory, outside the repository; a `CLAUDE_CONFIG_DIR` or a projects directory inside the repository
under review refuses the run.

**What is proven on every turn.** The init event of EVERY turn must CARRY `model`, `permissionMode`, `tools` (an
array) and `mcp_servers` (an array) - a missing, null or non-array field FAILS the turn with class `capability`
(`init event lacks <field> - the CLI's schema changed; pin the version`; wave 29b, E14 - a missing field is never read
as an empty one; a missing or non-string `apiKeySource` is the billing proof lacking: it FAILS the turn with class `auth` (`init event lacks apiKeySource - the billing proof of this auth mode; pin the CLI version`) under `subscription` and `api-key`, and is recorded as `null` only under `endpoint`, where the field proves nothing; A4). It must list
no tool outside `Read`, `Grep`, `Glob` and `StructuredOutput` - the init lists `Read`, `Grep`, `Glob`, plus
`StructuredOutput` only under the `native` schema transport (`--json-schema`); a prompt-only or raw/chore run lists
three (E17) -, no MCP server, and `permissionMode` `dontAsk` - else the turn FAILS with class `permission`. (E12) A
turn the bridge KILLED on its timeout or stall is judged the same way: an init or model proof that fails is the run's
outcome (`<problem> (the turn was also stopped: timeout after N s ...)`, its class), NO timeout continuation resumes
that session (`timeout_continue.outcome` `not attempted: the killed turn failed its proof (class <c>: <problem>)`),
and the salvage (`.partial.md`) is kept. Billing: with roster `auth` `subscription` the init `apiKeySource` must be `none`; with `api-key` the
variable `ANTHROPIC_API_KEY` must be set - else class `auth`; with `endpoint` see "Endpoint mode". What R22 switched off is recorded (ledger
`engine_run.switched_off`): user, project and local settings, instruction files (the repository's and the home
directory's `CLAUDE.md` / `AGENTS.md` do not reach a restricted reviewer - observed), MCP servers, skills, slash
commands, code tools, web tools, write tools, the autoupdater.

**One model per thread (D4).** The roster model goes to `--model` on a new thread; the init event's model is the
resolved id, and every later turn of the thread - the secondary turns, and later `-Mode resume` or `fork`
consultations (from the parent entry's `engine_run.model_resolved`) - sends that id. The init model must match the
pinned one (an alias `opus|sonnet|haiku|fable` matches any `claude-<alias>-...` id; `[1m]` is stripped); (wave 29b,
E13) EVERY `assistant` event's `message.model` must equal that id after the `[1m]` strip - the assistant messages prove
who answered, not the largest-output heuristic (`a different model authored an assistant message: <id>`); and the
result's `modelUsage` main model (the one with the most output tokens) must be it too - else class `capability`. A
`modelUsage` key that authored no assistant message (a helper model of the CLI) is recorded
(`engine_run.other_models`) with a warning. A run on an alias says `the alias floats;
each thread is pinned to the id it resolves to`.

**The child environment (D2, D3).** An ALLOW list, not a scrub list. The claude child gets: the system variables a
process needs (`SystemRoot`, `windir`, `SystemDrive`, `ComSpec`, `PATH`, `PATHEXT`, `TEMP`, `TMP`, `TMPDIR`,
`USERPROFILE`, `HOME`, `HOMEDRIVE`, `HOMEPATH`, `APPDATA`, `LOCALAPPDATA`, `ProgramData`, `ALLUSERSPROFILE`,
`PUBLIC`, `PSModulePath`, `USERNAME`, `USERDOMAIN`, `COMPUTERNAME`, `USER`, `LOGNAME`, `SHELL`, `TERM`,
`PROCESSOR_ARCHITECTURE`, `PROCESSOR_IDENTIFIER`, `PROCESSOR_LEVEL`, `PROCESSOR_REVISION`, `NUMBER_OF_PROCESSORS`,
`OS`, `LANG`, `LANGUAGE`, `TZ`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`,
`XDG_RUNTIME_DIR`), the proxy variables (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `ALL_PROXY`), the trust variables
(`SSL_CERT_FILE`, `SSL_CERT_DIR`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`), the prefixes
`ProgramFiles`, `CommonProgramFiles`, `ProgramW6432`, `CommonProgramW6432`, `LC_`, plus `CLAUDE_CONFIG_DIR` and - only
with auth `api-key` - `ANTHROPIC_API_KEY` (with auth `endpoint`, see "Endpoint mode": `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN` and `API_TIMEOUT_MS` instead). Every other `ANTHROPIC_*` and `CLAUDE_*` / `CLAUDE_CODE_*` variable
(an inherited gateway base URL, auth token, Bedrock / Vertex / Foundry selectors, `CLAUDE_CODE_EFFORT_LEVEL`,
`CLAUDE_CODE_SKIP_PROMPT_HISTORY`, model overrides, `CLAUDE_CODE_GIT_BASH_PATH`, ...), every host marker and every
test-mode variable is absent; `DISABLE_AUTOUPDATER=1` is set; names are compared case-insensitively. The SAME
environment serves the preflight (`claude auth status`), the version probe and every turn. Ledger
`engine_run.child_env_allowed` lists the NAMES (never values); the top-level `child_env_scrubbed` still names the
host markers that were set. Test hook (test mode only): `CODEX_CONSULT_TEST_CHILD_ENV_PASS=<prefix>` lets that prefix
through (the harness's fake reads `FAKE_CLAUDE_*`); never a prefix of `ANTHROPIC`, `CLAUDE` or `CODEX_CONSULT`.

**Sign-in (preflight).** The USER signs in (`claude auth login`, or `/login` in an interactive session); the bridge
never handles it. `Get-ClaudeSignIn` runs `claude auth status` (local, free, 15 s) in the child environment of the
entry's auth and reads its JSON BEFORE its exit code: `loggedIn` false -> `out` (`not signed in ... run claude auth
login`); true -> `available` when the auth is `subscription` and `authMethod` is `claude.ai`, or the auth is
`api-key` and `ANTHROPIC_API_KEY` is set; another `authMethod`, or an `apiProvider` other than `firstParty` (a
gateway, Bedrock, Vertex, Foundry - out of scope, D10; an endpoint entry has its own local preflight) -> `unavailable`; no launcher -> `missing`; not started, a
timeout or no JSON -> `not checked`. The `api-key` test (`ANTHROPIC_API_KEY` set) runs BEFORE the 60-minute ledger
short-circuit of every engine's sign-in check - a usable reply an hour ago proves nothing about this process's
environment. The row reads `ok: signed in (claude.ai subscription)`. The check needs no
network but starts a process, so under `-NoNetwork` (the SessionStart hook) it is `not checked`. Only `authMethod` and
`apiProvider` (ledger `reviewer.provider_config.auth_method`, `.api_provider`) and the projects directory are kept -
never the account's e-mail or organisation; `provider_config.credential_mechanism` is the roster `auth`. The endpoint
health fingerprint of a claude entry is engine + auth + model family (`cc-engine-v1|claude|subscription|opus`): an
Opus usage limit never marks Sonnet or the API-key route out.

**The reply.** The reply is the ONE `result` event's `structured_output`; else its `result` text goes through the
prose gate and the format repair (effort `low`, the same thread, the main turn's transport). Usage: `input_tokens` is
input + cache read + cache creation, `cached_input_tokens` the cache read, `cache_creation_input_tokens`,
`output_tokens`; `reasoning_output_tokens` is `null`. `total_cost_usd` stays local as `engine_run.cost_usd` (notional
on a subscription). Garbage after the result, or two results, is a malformed stream (class `transport`); a partial
last line is tolerated only after a kill or a non-zero exit. Ledger `engine_run` is `{turns, max_model_steps,
msp_schema_version (null), auth, init_tools, mcp_servers, permission_mode, api_key_source, model_resolved,
other_models, permission_denials, denied_tools, rate_limit, quota_mark, cost_usd, child_env_allowed, switched_off}`; the handoff
header reads `Engine turns: N (claude -p, auth subscription; model <id>; init tools Glob, Grep, Read,
StructuredOutput; permission denials 0)`.

**Denials.** Under `--permission-mode dontAsk` a Read outside the working directories is denied and the turn goes on
(observed). A usable reply with `permission_denials` stays usable, with a warning that lists the tools and paths; a
success with NO reply and denials is a denied-empty run and gets ONE denial-retry turn, as agy (`-DenialRetry`).

**A run FAILS** (nothing ingested; the reply kept and named when there is one) on: `Not logged in ... /login` and
similar (class `auth`); a `rate_limit_event` whose status rejects, or an error result with limit wording (`usage
limit`, `limit reached`, `hit your limit`, ...) (class `quota`, with the reset time - the event's `resetsAt`, or a
`|<unix time>` in the text - as `provider_failure.retry_after`); `error_max_turns` (from `-MaxModelSteps`) and
`error_max_structured_output_retries` (class `capability`); an init proof that fails (class `permission`), a model
that drifts (class `capability`), a malformed stream (class `transport`). The raw most-severe `rate_limit_event` info
is kept in `engine_run.rate_limit`; a warning status (`allowed_warning`) becomes a ledger warning. (Wave 29b, E15) A
REJECTING `rate_limit_event` followed by a SUCCESSFUL result keeps the reply usable: the event goes raw into
`engine_run.rate_limit`, the warning `a rate limit rejected a request during the turn: <the event, raw>` is added, and
`engine_run.quota_mark` holds the `provider_failure` a failed quota turn would have recorded (the same classifier on
the same text: a usage window until its reset, without one 60 minutes; a burst 429 10 minutes). The endpoint health
reads that mark as a quota failure right after the reply, so the roster walk, `codex-providers.ps1` (`unavailable
(usage limit until <reset>)`) and the plan (E5: `unavailable (plan zai (usage limit on ZAI-claude until <reset>))`)
see it before the next request hits it; the machine-wide record (`class` `ok` with its `quota_mark`) carries it to
the other repositories; a later usable reply on the route clears it as usual (A6: a record's identity in the machine-wide file includes its quota mark and the mark's reset, so a marked success and an unmarked success of the same route, repository and second are two records - the marked one is never dropped by the deduplication - and replaying the identical marked record adds nothing).

**Read-only: flags plus evidence, and the STRICT tree check (D1).** `--tools Read,Grep,Glob` leaves no writing tool,
but managed settings and their hooks still apply under `--restricted`, so the init event proves the tools, not the
absence of a writing hook. The bridge therefore runs the strict agy tree check: ANY change of the working tree or the
collab directory during a claude turn FAILS the run (class `permission`), as for agy; the coordinator writes nothing
under the collab directory or the working tree while a claude member runs (the skill's "Live members" rule). The
boundary is agy's: enforced by evidence for tracked and untracked files and the collab directory, not for gitignored
paths, submodules or files outside the repository, and not for reads.

**The panel (D5).** The members of the claude engine run ONE AT A TIME by default - one scheduling group for the
engine, whatever their labels; the roster's top-level `"parallel": {"anthropic": 2}` raises it. Two `claude -p` runs
at once in one directory were observed to work (P7) - stated as observed, not guaranteed. A stall or tool flight: a
`tool_use` without its `tool_result` suspends the stall timer (`claude <tool> <id>`). The salvage (`.partial.md`)
keeps the text blocks, the thinking blocks (when the CLI returns thinking text) and the tool calls as `<tool>:
<path|pattern>`; a `system/compact_boundary` event counts as a compaction.

**The coordinator (R13).** A Claude Code coordinator sets `CODEX_CONSULT_COORDINATOR="anthropic :: <its model id>"`
(a trailing `[1m]` is stripped). For a claude reviewer the ENGINE fixes the vendor: the coordinator's provider is
compared with `anthropic` (case-insensitive) whatever the roster label, and the models after normalising (`[1m]`
stripped, an alias equal to any id of its family). After the run the resolved model is compared again and a warning is
added when the answer changed. Always a warning, never a refusal.

**Telemetry.** The vendor class is `anthropic` for the engine claude WITHOUT a base URL (auth `subscription`, `api-key`);
an endpoint entry is classed by the HOST of its base URL like any other entry (wave 29b, E6). The model is
sent only when, lower-cased and with `[1m]` stripped, it EQUALS an entry of the vendor class's closed list, else `other`.
Nothing else of a claude run leaves (no result, denial, path or cost). See "Telemetry (on by default)".

**Endpoint mode (wave 29b, E1-E10): a coding plan through Claude Code.** A third credential mechanism, `auth:
"endpoint"`, runs Claude Code against a third-party Anthropic-compatible endpoint (a coding plan). Decision record:
`.collab/claude-engine-2026-09-30/handoffs/12-claude-claude-engine-endpoint-decisions.md`. The entry spells the
endpoint out; it is never derived from a Codex `[model_providers]` table:

```json
{"provider": "ZAI-claude", "engine": "claude", "model": "glm-5.3", "auth": "endpoint",
 "endpoint": {"base_url": "https://api.z.ai/api/anthropic", "env_key": "ZAI_API_KEY", "timeout_ms": 3000000},
 "plan": "zai"}
```

- **The entry (E1).** `endpoint` is REQUIRED with `auth: "endpoint"` and REFUSED with `subscription` / `api-key` and on
  every other engine. `base_url`: an absolute https URL without credentials, query or fragment, sent as written to the
  child as `ANTHROPIC_BASE_URL`. `env_key`: the NAME of the variable that holds the token (`^[A-Z][A-Z0-9_]{2,}$`);
  the operator sets that variable, its value is read at launch and never logged. `timeout_ms`: optional, default
  3000000, 60000-7200000 (`API_TIMEOUT_MS`). Unknown keys are refused. (E11) The `model` of an endpoint entry (and a
  `-Model` for such a run) may not be an Anthropic model id - an id or alias of the engine's table (case-insensitive,
  `[1m]` stripped) or any `claude-*` id: the init event's `apiKeySource` is `none` on this route as on the subscription,
  so only a model the subscription cannot serve proves the billing; name the provider's own id. The provider label is the operator's and
  distinct per route: `ZAI` stays the codex entry, `ZAI-claude` the endpoint entry (the rules "one label names one
  engine" and "one (provider, model) once" are unchanged). Each refusal comes inside the usual "the reviewer roster
  '<path>' is not usable: ... Fix it or move it aside" message, prefixed `entry <n>: `, e.g. `auth "endpoint" needs an
  "endpoint" object {"base_url": "https://...", "env_key": "<VARIABLE NAME>"} - the Anthropic-compatible endpoint and
  the variable that holds its token`, `endpoint applies only to engine claude with auth "endpoint" (this entry: engine
  claude, auth subscription)`, `endpoint has an unknown key 'x' (allowed: base_url, env_key, timeout_ms)`,
  `endpoint.base_url must be an absolute https URL without credentials, query or fragment (e.g.
  "https://api.z.ai/api/anthropic"; the value is not shown)`, `endpoint.env_key must be the NAME of the environment
  variable that holds the token (...), never the token itself (the value is not shown)`, `endpoint.timeout_ms must be an
  integer from 60000 to 7200000 (milliseconds - API_TIMEOUT_MS; default 3000000; got 5)`, `plan must be a slug of 2 to
  32 characters - lowercase letters, digits and "-", starting with a letter (e.g. "zai"; got "Zai")`, and `parallel names
  the provider label 'x', which no entry of the roster uses (as its provider label or its plan)`.
- **The model (E2).** Sent straight as `--model <id>`, the id as the provider publishes it (letters, digits, `.`, `_`,
  `-`, at most 64 characters, optionally ending with `[1m]`); the closed claude model table does NOT apply. No alias
  mapping variable (`ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_*_MODEL`, `ANTHROPIC_SMALL_FAST_MODEL`) ever reaches the
  child. Proof per turn: the init event's `model` and the main `modelUsage` key must EQUAL the pinned id after the
  `[1m]` strip (no alias-family matching on this route), else class `capability`.
- **The preflight and the proof (E3).** Local only: the launcher is found, `base_url` parses, and the `env_key` variable
  is set and non-empty. There is NO `claude auth status` (it reads the local login and ignores the base URL) and no live
  request (it would spend the plan's credits). The credentials text reads like a codex table's: `ok: env ZAI_API_KEY
  set` or `missing: env ZAI_API_KEY not set`. `apiKeySource` is `none` on this route too and is recorded raw; the value
  `ANTHROPIC_API_KEY` fails the turn with class `auth`. The billing proof is `init.model` equal to the pinned id (a
  subscription turn cannot serve it) plus the ledger's `engine_run.child_env_allowed` (`ANTHROPIC_AUTH_TOKEN` present,
  `ANTHROPIC_API_KEY` absent). The stderr notice `[claude-code:unrecognized_model]` is not a failure.
- **The child environment (E4).** The allow list above plus, for this mode only, `ANTHROPIC_BASE_URL`,
  `ANTHROPIC_AUTH_TOKEN` (the value of the `env_key` variable) and `API_TIMEOUT_MS`; `ANTHROPIC_API_KEY` is absent. If
  the token variable is unset at launch, nothing starts (the CLI would otherwise fall back to the local login). A
  401/403 (`Failed to authenticate. API Error: 401 ...`) is class `auth` with no fallback to the subscription; a 429 is
  class `quota` by its status.
- **Two identities (E5).** The ROUTE identity (lineage, parenting, the health of auth, transport and capability
  failures) is the fingerprint SHA-256 of `cc-engine-v1|claude|endpoint|<canonical base_url>|<env_key name>` (canonical:
  lower-case scheme and host, the explicit port if any, the path without a trailing slash); the ledger's
  `reviewer.provider_config` is `{engine, launcher, credential_mechanism: "endpoint", base_url, env_key, plan}` - the
  token never appears. The PLAN identity is the optional entry key `plan` (`^[a-z][a-z0-9-]{1,31}$`), allowed on every
  entry of every engine: a QUOTA-class failure (usage limit, 429) recorded on any entry marks every entry with the same
  plan out until the same reset time - the roster walk and the `codex-providers.ps1` row show `unavailable (plan zai
  (usage limit on ZAI until <iso>))`, the `-Short` / hook line `ZAI-claude :: glm-5.3 (plan zai (usage limit on ZAI
  until 15:00, in 3h))`. Auth, transport and capability failures stay route-local; without `plan` nothing propagates. A
  later usable reply on any route of the plan clears it (the plan's routes are read as one record set). The lab of an
  endpoint entry comes from the base URL's host (`api.z.ai` zhipu, `*.xiaomimimo.com` xiaomi, `api.kimi.ai` moonshot,
  `api.minimax.io` minimax), never `anthropic` because of the engine. The coordinator rule compares an endpoint entry as
  a codex entry (label and model); the `anthropic` provider rule applies to `subscription` and `api-key` only.
- **Concurrency (E7).** The claude members keep ONE engine-wide scheduling group by default (D5); in addition every
  `plan` is a scheduling group across engines: a ZAI-via-codex member and a ZAI-claude member run one after another,
  raised by the roster's `"parallel": {"zai": 2}` (a `parallel` key may name a plan slug as well as a provider label; a
  label without its own value takes its plan's). (E16) Machine-wide too: a run's row in the health file's `running[]`
  carries its entry's `plan`, and a panel member counts every running row of its plan - from any engine and any
  repository - against its group's limit (never above the plan's `parallel`, default 1), exactly as a run on its own
  endpoint (wave 26b): a codex `ZAI` run in another repository makes a `ZAI-claude` member wait, `panel member 1 of 2
  waits: 1 run(s) elsewhere on this machine use its plan zai (parallel limit 1): ZAI in <repo> task t handoff 01 (plan
  zai, pid <n>)`.
- **Dry run.** Two lines for this mode: `child env   : an allow list (auth endpoint): <names> - every other variable
  (the host markers, ANTHROPIC_* but ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN, CLAUDE_* but CLAUDE_CONFIG_DIR) is
  left out` and `endpoint    : https://api.z.ai/api/anthropic (ANTHROPIC_BASE_URL); token from env ZAI_API_KEY
  (ANTHROPIC_AUTH_TOKEN - the value is never shown); API_TIMEOUT_MS 3000000; plan zai; no claude auth status - the
  model the init event names is the proof`; the reviewer line reads `engine claude (<launcher>), endpoint
  https://api.z.ai/api/anthropic (token from env ZAI_API_KEY)`. The `codex-providers.ps1` engine row's endpoint column
  reads `claude endpoint https://api.z.ai/api/anthropic (<launcher>)`.
- **Documented examples (E9).** z.ai GLM Coding Plan: `https://api.z.ai/api/anthropic`, model `glm-5.3`, env e.g.
  `ZAI_API_KEY`, plan `zai`. Xiaomi MiMo Token Plan: `https://token-plan-ams.xiaomimimo.com/anthropic`, model
  `mimo-v2.6-pro`, env e.g. `MIMO_API_KEY`, plan `mimo`. Kimi Code: `https://api.kimi.ai/coding/` (overseas;
  `api.kimi.com/coding/` domestic), models `k3`, `k3-256k`, `kimi-for-coding`, env e.g. `KIMI_API_KEY`, plan `kimi`
  (NOT `api.moonshot.ai`: that is the pay-as-you-go platform, a different product). MiniMax
  (`https://api.minimax.io/anthropic`, `MiniMax-M3`): shape known, not run. Alibaba's Coding Plan and Token Plan are NOT
  documented for this route: their terms say "for interactive AI coding tools (Claude Code, Codex) only - not for
  backend services" (the same wording applies to the codex route to Alibaba: TECH_DEBT).
- **Terms and cost.** Both z.ai and MiMo name Claude Code; the operator decides whether a read-only reviewer is within
  their plan's terms and records that decision in their task's `state.md`. z.ai meters token-weighted credits (a 5-hour
  and a weekly pool), not prompts.
- **Whether the route stays (E8, wave 29c).** Decided by evidence, not by this implementation: paired, order-randomised
  runs of the same briefs through both routes, at least 12 pairs per provider; keep the route when the median credits are
  at most 0.8x the codex route AND the first-turn structured rate is not lower AND the median wall time is at most 1.25x
  AND the blind `-Rate` marks are not worse. One pair so far (P13: credits 0.30x, wall 0.51x, both structured) is an
  anecdote.

**Not done, on purpose.** The Agent tool and subagents, MCP servers, web tools, Bash and every write tool,
`workspace-write`; `--bare` (API-key only: it ignores the subscription login); routing through an INHERITED gateway
(`ANTHROPIC_BASE_URL` from the environment: removed from every child), Bedrock, Vertex and Foundry (their variables
are removed - such a setup fails closed at the preflight; decision D10 stands for them, and is reversed only for the
explicit endpoint entry above); calling the API directly instead of the CLI (R10 is engines through the vendor's own
CLI; the subscription login exists only there); other vendors' models outside the endpoint mode; stream-json input; `--include-partial-messages`;
`--max-budget-usd`; `--fallback-model`; `--bg`, `--worktree`, `--agents`; `--no-session-persistence` (every secondary
turn resumes).

**Observed, and still open.** Observed on 2026-09-30 (Claude Code 2.1.285, Windows): a stdin prompt of 52 KB is read
whole; a denied Read gives an error `tool_result`, `permission_denials` and a success (P1); `--max-turns` is accepted
although `--help` does not list it (P2); the home `CLAUDE.md` does not reach a restricted reviewer (P3); `modelUsage`
has one key (P4); `claude auth status` exits 0 when signed in (P5); a session killed with `taskkill /T /F` mid-turn
resumes under the same id (P6); two runs at once work (P7). Open, and decided defensively: whether `--effort` does
anything on a model without adaptive reasoning (Q3), whether `--session-id` pins a fork (Q5), streaming during one long
thinking block (Q6), the exit codes and the limit stream (Q7, Q10).

**Listings and tests.** `codex-providers.ps1` shows one row per claude label (`KIND` `engine claude`, `EFFORT`
`claude`, transport `native`); the scoreboards and the panel summary show `anthropic :: claude-opus-5-5 [claude]`. The
fake is `tests/fake-claude.cmd` + `tests/fake-claude.ps1` (driven by `FAKE_CLAUDE_*`) and the harness is
`tests/harness-claude.ps1` (a real `claude` is never started: see "Tests").

---

## Usefulness telemetry: codex-scoreboard.ps1

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-scoreboard.ps1" [-Task <task>] [-Json] [-By purpose|topic] [-CollabDir <path>]
```

Answers "which reviewer has been useful on which kind of question" across every task of
the repository (or one task with `-Task`), from each `sessions.json` and `findings.json`
(including the `-Rate` marks). It writes nothing, takes no lock, makes no network call and
exits `0`; a store it cannot read is reported and left out. One row per
`(reviewer lineage, purpose)` - (0.5.0, wave 26) or per `(reviewer lineage, topic)` with `-By
topic` (a consultation with two topics is on both rows, once on its lineage's total) -, a
`(total)` row per lineage and a grand `(all) (total)` row; `unknown provenance` (pre-0.3.0
entries, findings without a ledger entry) sorts last.

| Column | Meaning |
|---|---|
| `REVIEWER` | `<provider> :: <model>`, or `unknown provenance` |
| `PURPOSE` | the `-Purpose`, `(none)`, or `(total)`/`(all) (total)` on summary rows |
| `CONSULTS` / `USABLE` / `PROSE` / `FAILED` | ledger entries; `bridge_outcome` = `usable reply`; usable but not a valid structured reply (`-Raw`, `chore`, invalid JSON); every other outcome |
| `RAISED` | findings raised by these consultations (joined by `source.consult`, as in `-Stats`) |
| `VERIFIED` / `REJECTED` / `WONTFIX` / `SUPERSEDED` / `OPEN` | current status of those findings; `OPEN` = `proposed` + `implemented` |
| `HIT%` | `verified / (verified + rejected)`, rounded; `-` when both are 0 |
| `A/H/R/D` | verdicts ACCEPT / HOLD / REJECT / ADVISE |
| `Y/P/N` | the `-Rate` marks yes / partly / no (wave 26: a mark belongs to the consultation whose `consult_id` it carries; one recorded without, to its `n` in the task) |
| `SCORE` | (wave 26) the routing score a routed `-Panel` gives this reviewer for this purpose - the bridge's own `Get-RoutingScore` over the marks of EVERY task (last 90 days): `1.125` (neutral) below 3 marks; a lineage's total row: its all-purpose score; `-` on a `-By topic` row ("Companions") |
| `UNIQ` | (wave 26) `unique/panel-raised`: findings this reviewer raised as a panel member that no other member of the same panel raised at the same location (path and line; a finding without a location counts as unique), of all it raised in panels - the measure behind the "about five members" heuristic; (wave 26b, D7) a location is compared after normalising its path - `\` and `/` alike, runs of `/` collapsed, a leading `./` dropped, case-insensitive on Windows - the line exactly |
| `MEDIAN_S` | median `wall_seconds`; `-` when none |
| `TOKENS` | uncached input tokens / output tokens |

`-Json` returns the same rows with numeric fields (`hit_rate`, `score` and
`median_wall_seconds` a number or `null`; `unique` and `panel_raised`) plus `kind`: `purpose`
(`topic` with `-By topic`), `lineage` or `total`. Run it before choosing a panel or a judge for
a hard question - a routed panel already uses the same scores.

---

## Telemetry (on by default)

(0.5.0, wave 28 - ROADMAP R17.) **Installing this plugin means accepting these terms.** After
every consultation the bridge reports ONE anonymised event to the maintainer's intake, so the
bridge can be improved by people the maintainer never hears from; the operator can also send a
complaint or a suggestion. It is ON by default - an opt-in intake collects nothing - and one
line switches it off:

```powershell
$env:CODEX_CONSULT_TELEMETRY = 'off'     # or set it as a user variable; one run: -Telemetry off
```

`CODEX_CONSULT_TELEMETRY`: unset or empty - on; `on`, `1`, `true`, `yes` - on; `off`, `0`,
`false`, `no`, `none` - off; ANY other value counts as off (a switch that cannot be read never
sends). `codex-consult.ps1 -Telemetry on|off` decides for one run (a panel passes it to its
members). Off means nothing of telemetry is written or sent: no spool line, no salt, no notice.
The first real run after an install (or an update: the marker is per plugin version) prints a
five-line notice once - what is sent, what never is, the switch, `-Complain`, these terms -
while telemetry is on; the dry run prints `telemetry   : on (<source>) - ...` or `telemetry   :
off (<source>) - nothing is spooled or sent`; the SessionStart hook's pointer line ends with
`; telemetry: on` or `; telemetry: off`.

**What is sent - the exact payload** (`POST <intake>/v2/events`, `{"events": [...]}`, at most
100 per request), built from the ledger entry being committed through a closed allowlist
(`ConvertTo-TelemetryDetails`; every value a closed set, a number, a boolean or an entry of the
vendor table below):

```json
{
  "app_id": "codex-consult",
  "app_version": "0.5.0",
  "instance_id": "5ba1dfa7108eabedec5ee84a332c647aeea71a1b3a2e42088499db1019b8fa7d",
  "event_type": "consultation",
  "severity": "info",
  "title": "usable",
  "details": {
    "engine": "codex",
    "provider": "zai",
    "model": "glm-5.3",
    "purpose": "acceptance",
    "outcome": "usable",
    "wall_seconds": 213,
    "tokens": { "in": 515000, "cached": 402000, "out": 9100 },
    "findings": { "blocker": 0, "major": 2, "minor": 1, "note": 0 },
    "structured": true,
    "format_retry": false,
    "denial_retry": false,
    "timeout_continue": false,
    "panel_size": 4,
    "ps_version": "7.6.6",
    "os": "windows 10.0.26200",
    "bridge_version": "0.5.0"
  },
  "tags": ["zai", "glm-5.3"],
  "client_time": "2026-09-29T14:14:33Z",
  "os": "windows 10.0.26200",
  "runtime": "pwsh 7.6"
}
```

| Key | Meaning |
|---|---|
| `app_id`, `app_version`, `details.bridge_version` | `codex-consult` and the plugin's version (`.claude-plugin/plugin.json`) |
| `instance_id` | SHA-256 of the 32 random bytes in `<codex home>/telemetry-salt` (64 hex digits, created once by the first event) followed by the UTF-8 machine name: the machine name never leaves in clear, and a new salt makes a new, unlinkable instance |
| `severity`, `title`, `details.outcome` | `info` - `usable` or `usable-after-continuation`; `warning` - `failed:quota`, `failed:auth` (a provider limit or sign-in) or `failed:operator` (`-Kick`); `error` - every other `failed:<class>`: the provider failure's class (`capability`, `transport`, `permission`, `unknown`), else `timeout`, `stalled` or `bridge` |
| `details.engine`, `provider`, `model`, `purpose` | the engine (`codex`, `agy`, `muse`); (wave 28b, D1) the VENDOR CLASS of the endpoint the reviewer talked to - never the provider label of the roster or the config; (wave 28c, D1) the model name only when the vendor class is known and the name EQUALS an entry of that class's closed list (after lower-casing), else `other`; the purpose (`none` without one) (Wave 29) The engines are `codex`, `agy`, `muse` and `claude`; the vendor class of the engine `claude` is `anthropic`. |
| `details.wall_seconds`, `tokens`, `findings` | the entry's wall time (rounded), token counts (`null` when the engine reports none) and finding counts by severity |
| `details.structured`, `format_retry`, `denial_retry`, `timeout_continue` | booleans: a valid structured reply; a format repair, a denial retry, a timeout continuation turn attempted |
| `details.panel_size` | the members of the panel this consultation belonged to; `0` for a single run |
| `details.ps_version`, `os`, `runtime` | `$PSVersionTable.PSVersion`; the OS family and version; `powershell 5.1` or `pwsh 7.x` |
| `tags`, `client_time` | (wave 28b) `[provider, model]` - the same two closed values as `details`; when the event was built, UTC (an instant, not a day) |

**The vendor table** (wave 28b, D1 - `$script:TelemetryVendors` in `codex-consult-common.ps1`, ONE
data structure). The roster label and the model are text the operator typed, so neither leaves
the machine as typed: the event's `provider` is the vendor class of the endpoint's HOST (the host
equals one listed or ends with `.` + one; the ledger's `reviewer.provider_config.base_url`), or of
the engine - (wave 29b, E6) the host is read FIRST for every engine whenever the entry has a base URL, the engine row is
only the fallback, and an unknown host reads `other`; the `[1m]` strip applies to every vendor's model token. (Wave 28c, D1 / F42-1, F43-2) The model is sent only when it EQUALS, after
lower-casing, an entry of its vendor class's CLOSED list below - the published model names this
README documents (the effort table, the roster examples) and the rosters have run - and then as the
list's own text; no pattern, no version wildcard: a model name outside the list, however
version-like, reads `other`, and a new model reads `other` until a release adds it to the list. The
ledger and every local file keep the real label and model. Known limitation (F43-6, F44-3): the
class is derived from the host NAME only - a private gateway, relay or proxy under a vendor's
domain (`<tenant>.openai.com`, or a hosts-file entry for a vendor's name) reads as that vendor.

| Vendor class | Endpoint | Models sent (the closed list; anything else is `other`) |
|---|---|---|
| `openai` | the built-in provider (the ChatGPT login or an API key, no `OPENAI_BASE_URL`), `*.openai.com`, `chatgpt.com` | `gpt-5.1`, `gpt-6-astra`, `o4-mini` |
| `zai` | `*.z.ai` (`api.z.ai`), `*.bigmodel.cn` (`open.bigmodel.cn`, the effort table's other Z.ai host) | `glm-5.3`, `glm-5.3-flash`, `glm-5.3-flashx`, `glm-5.2`, `glm-5.1`, `glm-5`, `glm-5-turbo`, `glm-4.7`, `glm-4.6`, `glm-4.5`, `glm-4.5-air` |
| `xiaomi` | `*.xiaomimimo.com` (`token-plan-cn`, `token-plan-ams`, `api`) | `mimo-v2.6-pro`, `mimo-v2.6-flash`, `mimo-v2.6-pro-ultraspeed`, `mimo-v2.5-pro`, `mimo-v2.5` |
| `byteplus` | `*.bytepluses.com` (`ark.ap-southeast.bytepluses.com`) | `dola-seed-2.0-pro`, `dola-seed-2.0-lite`, `dola-seed-2.0-code`, `bytedance-seed-code`, `glm-5.3-flash`, `glm-5.2`, `glm-5.1`, `kimi-k2.5`, `gpt-oss-120b`, `deepseek-v4.1-flash`, `deepseek-v4-flash`, `deepseek-v4-pro` |
| `moonshot` | `*.kimi.ai`, `*.moonshot.ai` | `k3`, `k3-256k`, `kimi-for-coding`, `kimi-for-coding-highspeed`, `kimi-k2.5`, `kimi-k3` |
| `alibaba` | `*.aliyuncs.com` (the Token Plan endpoint) | `qwen3.8-max`, `qwen3.8-flash`, `qwen3.7-max`, `qwen3.7-plus`, `qwen3.6-flash`, `deepseek-v4.1-flash`, `deepseek-v4-pro`, `deepseek-v4-pro-0813`, `deepseek-v4-flash-0731`, `glm-5.3`, `glm-5.2` |
| `google` | the engine `agy` | `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `gemini-3.8-flash-low`, `gemini-3.1-pro-high`, `gemini-3.1-pro-low` |
| `meta` | the engine `muse` | `muse-spark-1.3`, `muse-spark-1.3-contributor` |
| `minimax` | `api.minimax.io`, `api.minimax.cn` | `minimax-m3` (the published id `MiniMax-M3`, listed lower case like every list) |
| `anthropic` | the engine `claude` WITHOUT a base URL (auth `subscription`, `api-key`; the model list is the engine's table, `[1m]` stripped first) | `opus`, `sonnet`, `haiku`, `fable`, `claude-fable-5-1`, `claude-fable-5`, `claude-opus-5-5`, `claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-sonnet-5-5`, `claude-sonnet-5`, `claude-sonnet-4-6`, `claude-haiku-5-5`, `claude-haiku-4-5` |
| `other` | any other host (a local endpoint, a company's own gateway, a look-alike host), or no endpoint recorded | always `other` |

A roster entry `AcmeCorp-Legal` on `https://llm.acmecorp-internal.example/v1` with the model
`acmecorp-contracts-7b` is sent as `provider: other`, `model: other` (`harness-telemetry` UNIT and
SPOOL check exactly that, on a synthetic entry and a real run).

- **The rating event** (R24, 2026-10-06). When the judge rates a consultation -
  `codex-findings.ps1 -Task <task> -Rate <n> -Useful yes|partly|no` - the bridge spools ONE more
  event of `event_type` `rating` for that ledger entry (every rating, a re-rating too; the switch as
  above, `-Telemetry on|off` on `codex-findings.ps1` for one rating) at the mark's commit, inside the
  write lock with at most 1 s, as a consultation's event; spooled, the mark in `findings.json`
  carries `telemetry_sent` (unix seconds). A spool that stays busy is retried for up to 5 s after
  both task locks are released (spooled then, a second store commit writes `telemetry_sent`); a
  failure then prints `codex-findings: warning: telemetry rating event not spooled (<why>) - at the
  commit (<why>) and for 5 s after it; codex-telemetry.ps1 -BackfillRatings sends it later`, is
  counted for `-Status` and never changes the rating's exit code. Then the same detached sender
  starts. The top level is a
  consultation event's (`app_id` ... `runtime`, `tags` `[provider, model]`) with `severity` `info`
  and `title` the mark; `details` are exactly `engine`, `provider`, `model`, `purpose`, `mark`
  (`yes`, `partly`, `no`), `age_days` (the whole days from the consultation's `when` to the rating,
  `0` the same day), `bridge_version`, `os`, `ps_version` - the reviewer through the consultation
  event's own code path (`Get-TelemetryReviewerClass`: the vendor class and the closed-list model,
  `other` / `unknown` exactly as there). Never in it: the `-Note` text, the topics, the task, the
  consultation's `n`, `consult_id` or lineage, the roster label. Example `details`:
  `{"engine":"codex","provider":"zai","model":"glm-5.3","purpose":"acceptance","mark":"partly","age_days":0,"bridge_version":"0.5.0","os":"windows 10.0.26200","ps_version":"7.6.6"}`.
  The intake aggregates consultations and ratings per vendor class and model.
- **Backfilling earlier marks** (R24, 2026-10-06). Marks given before the rating event existed have
  no `telemetry_sent`; one command in the repository sends each of them ONCE:

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-telemetry.ps1" -BackfillRatings -DryRun   # what would be sent
  powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-telemetry.ps1" -BackfillRatings          # send
  ```

  `-BackfillRatings` walks every `<collab>/<task>/findings.json` of the current repository
  (`-CollabDir`, default `.collab`), and for every mark without `telemetry_sent` looks the
  consultation up in that task's `sessions.json` as `-Rate` recorded it (`consult_id`, else `n`
  for a mark older than wave 26). A mark whose entry is not there is SKIPPED and counted - a
  reviewer is never guessed - and so is a mark that is not `yes`/`partly`/`no` or has no `when`.
  Every other mark goes out as the same `rating` event `-Rate` sends, with `client_time` = the
  mark's own `when` (when the rating happened; the intake keeps its own receipt time) and
  `age_days` from the mark's `consult_when`, and `telemetry_sent` (unix seconds) is written into
  the mark under the task's store commit - so a second run sends nothing (`already`), and nor do
  marks `-Rate` spooled itself. It prints `codex-telemetry: <task>: sent N, already M, skipped K`
  per task with marks, then `codex-telemetry: total: ...`, and starts the detached sender when it
  spooled something. `-DryRun` prints one `would send: <vendor class> / <model> (<engine>),
  purpose .., mark .., age_days .., client_time ..` line per event - never a note or a topic -
  and writes nothing (no spool, no salt, no marker). Telemetry off (`CODEX_CONSULT_TELEMETRY=off`
  or `-Telemetry off`): refused with exit `1`, nothing written. Exit `1` also when a spool append
  failed (those marks stay unsent; run it again).

**Never sent:** task names, briefs, prompts, replies, paths, thread ids, consultation ids,
finding texts or ids, messages, warnings, keys, provider labels as typed, user names, the machine
name in clear, a rating's note or topics. A unit test walks every key AND value of real events and
of an event built from a hostile entry (`tests/harness-telemetry.ps1` UNIT, SPOOL, RATE, BACKFILL).

**How it travels.** Never in a consultation's critical path. (Wave 28b, D6) At the ledger commit
(a failed run's too; each panel member its own), inside the task's write lock and right before the
entry is added, the event is appended as ONE NDJSON line to the spool,
`<codex home>/telemetry-spool/<yyyy-mm-dd>.ndjson` (the LOCAL date, as the engines name their
session directories - D16; a line is `{"v":1, "kind":"event", "queued_unix":<s>, "body":"<the
JSON above as a string>"}`). (Wave 28c, D7 / F43-4) Inside the write lock the append waits at most
1 s (the telemetry lock and a spool file another process holds, together), so a busy spool adds at
most 1 s to the hold on the task's lock; when that fails, the run tries again for up to 5 s after
the write lock is released, and only then warns - on the console and in a detached run's status
record: `warning    : telemetry event not spooled (<why>) - at the commit (<why>) and for 5 s after
it` (the entry is already committed, so its `warnings[]` no longer carries this line). An event
that is not spooled is never lost silently: `codex-telemetry.ps1 -Status` counts the events not
spooled since the last flush. (Wave 28d, D4 / F49-2) The count is append-only and written without the
telemetry lock, so a busy lock or a `-Forget` in flight never loses a count. (Wave 28e, E2 / F54-2,
F53-1) It is ONE FILE PER PRODUCER PROCESS - `<codex home>/telemetry-not-spooled-<pid>-<start
ticks>.ndjson`, which no other process appends to (no append waits for another producer's; a line
that cannot be written is said in the warning) - and `-Status` sums the complete lines of every such
file and of the legacy single file `telemetry-not-spooled.ndjson` of older versions. Each flush, under
the telemetry lock, folds the files whose producer is gone (no process with that pid and start time;
the legacy file too) into ONE line of `.last` `notes` (`folded <n> not-spooled line(s) of <m> gone
producer(s)`) and removes them, and records in `.last` `not_spooled_seen` the lines of the files it
kept (live producers): `-Status` counts the lines beyond them, and no file grows past what one process
wrote. (Wave 28e, E20 / F27-3) In THIS order: `.last` is saved first - the note, the new
`not_spooled_seen` and `not_spooled_folded[]` (the names of the files the fold covers) - and only after
that save are the files deleted (then `.last` drops the names of the files now gone). A crash in between
leaves files `.last` names: `-Status` leaves them out, and the next flush deletes them WITHOUT counting
them again. (Wave 28e, E24 / F30-2) Each entry is `{name, bytes}` - the file's length when it was
counted: a named file of the recorded length is deleted uncounted, a LONGER one has its complete lines
beyond the recorded bytes counted as new (`-Status` counts them too) and is then deleted, and a shorter
one is another file under that name, folded afresh. (Wave 28e, E26 / F32-2) The legacy file
`telemetry-not-spooled.ndjson` - the one name older bridges append to and recreate - is never counted or
deleted under its own name: under the telemetry lock, before anything is counted, the fold renames it
(one atomic move) to a unique staged name `telemetry-not-spooled-legacy-<utc ticks>.ndjson` that no
producer writes to and that never recurs, so `{name, bytes}` identifies that generation exactly. An
older bridge that recreates the legacy name afterwards writes a NEW generation the next fold stages again
(a legacy file a writer holds is skipped for about 1 s of retries, then this flush, with a note; `-Status`
always counts the legacy file's lines whole). A `.last` that cannot be written folds nothing - the files and the old baseline stay, and the
flush's result ends `; warning: <spool>/.last could not be written (...) - nothing was folded: ...`
(TEST HOOK, test mode only: `CODEX_CONSULT_TEST_FOLD_CRASH=1` - the flush exits between the save and the
deletes; (E26) `CODEX_CONSULT_TEST_FOLD_CRASH=2` - it exits between the deletes and the rewrite of `.last`
that drops their names). `-Forget -Local` removes every one of them, the staged ones too. After the commit ONE
detached sender starts - `codex-telemetry.ps1 -Flush`, the same PowerShell, hidden, not waited for
(a panel starts one when every member is done).

(Wave 28c, D3 / F42-3) **The telemetry lock.** `<codex home>/telemetry.lock` is held - as an open
handle, which the OS releases when its holder dies, so it is never stale; the empty file stays - by
every spool append of a producer (a consultation's event, a complaint kept), by the salt's creation
and by `-Forget -Local`. While `-Forget -Local` deletes, it also writes the marker
`<codex home>/telemetry-forgetting` `{pid, start_time, start_ticks, since}` (removed last; wave 28e, E3
/ F54-3: `start_ticks` is the owner's start time in ticks of 100 ns, and a marker that has it is judged
on its pid AND exactly those ticks - outside Windows within the same second, the jitter of .NET's start
time there; an older marker without it by its `start_time` as before). A producer that meets the
marker - or a lock that stays busy past its short wait (1 s at the commit, 5 s after it) - DROPS its
event and counts it instead of recreating the salt or the spool: `telemetry event not spooled
(codex-telemetry.ps1 -Forget -Local is deleting the local telemetry data (pid <n>, since <t>; the
marker ...)) - dropped`. (Wave 28d, D2 / F48-2) The marker heals itself: `-Forget` removes it in
`finally` (a deletion that fails halfway says `run codex-telemetry.ps1 -Forget -Local again to finish
it` and blocks nothing), and a producer or a sender that meets a marker whose owner is gone - or
that names none (`-Forget` writes it under the telemetry lock, so nobody is writing it while the lock
is held) - removes it under the telemetry lock, leaves one line in `.last` `notes` (`removed the
forgetting marker of pid <n> (gone) since <t> - a -Forget -Local that did not finish; run it again
to finish the local deletion`) and goes on. A marker whose owner lives (its pid with its start time;
an identity that cannot be confirmed counts as living) blocks as before - the sender too stops
before sending anything. `-Status` shows the marker and its owner (`forgetting : the marker ... - its
owner pid <n> lives` / `... is gone`).

(D3 of wave 28b; wave 28c, D6 / F41-1, F42-9) The sender starts with a MINIMAL environment built
from an allow list - the whole list: `SystemRoot`, `windir`, `SystemDrive`, `ComSpec`, `PATH`,
`PATHEXT`, `TEMP`, `TMP`, `TMPDIR`, `USERPROFILE`, `HOME`, `HOMEDRIVE`, `HOMEPATH`, `APPDATA`,
`LOCALAPPDATA`, `ProgramData`, `ALLUSERSPROFILE`, `PSModulePath`, `PROCESSOR_ARCHITECTURE`,
`NUMBER_OF_PROCESSORS`, `OS`, `LANG`, `LANGUAGE`, `TZ`, every variable starting `ProgramFiles`,
`CommonProgramFiles`, `ProgramW6432`, `CommonProgramW6432` or `LC_`; the proxy variables
`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `ALL_PROXY` in both cases (`http_proxy` ... - names are
compared ignoring case, and outside Windows, where `http_proxy` and `HTTP_PROXY` are two variables,
both are kept); the trust inputs of a private CA `SSL_CERT_FILE`, `SSL_CERT_DIR`,
`REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`; PowerShell's own
`POWERSHELL_TELEMETRY_OPTOUT` and `POWERSHELL_UPDATECHECK`; `CODEX_HOME`,
`CODEX_CONSULT_TELEMETRY`, `CODEX_CONSULT_TELEMETRY_URL`; and in test mode
`CODEX_CONSULT_TEST_MODE` with the sender's own hooks `CODEX_CONSULT_TEST_TELEMETRY_*` - no
provider key, no host marker, no other `CODEX_CONSULT_*` variable; on Windows it is created
without inheriting any handle of the bridge. The bridge's own environment is never changed for it.

(D2) The sender has a deadline: ONE flush ends after 60 s in all, ONE request (connect, send, read
the answer) is bounded as a whole by 8 s - what is not sent stays in the spool. (Wave 28c, D5 /
F42-8) The 60 s cover the whole flush - the lock, the spool's enumeration, every file's read (a
busy file's wait included), every request and every rewrite: the clock is checked before each step
and a step that no longer fits stops the flush cleanly; a request starts only while 1.5 s are left
(1 s kept back for the rewrite after it), and the rewrite that removes lines already delivered is
always attempted, with a wait of at most what is left. (Wave 28d, D1 / F48-1, F49-3) Every rewrite of a
spool file is ATOMIC: under the telemetry lock (no producer appends meanwhile) the kept lines go to
`<spool file>.tmp` in the same directory, are flushed to disk, and the temporary file replaces the spool
file in one step (a move with overwrite - `MoveFileEx` on Windows PowerShell 5.1); nothing truncates the
spool in place, so a crash leaves the old file or the new one, and a `.tmp` a crash left behind is
replaced by the next rewrite. The deadline is checked before a rewrite starts, never inside one. (TEST
HOOK, test mode only: `CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH=1` - the process exits between the
temporary file and the replace.) Its lock `<spool>/.flush.lock` is a marker
file `{pid, start_time, token, since}`: a concurrent sender is refused; (wave 28d, D3 / F48-3, F49-4)
the lock is born with its owner - the record is written to a temporary file that is moved into place
without overwriting, so a healthy sender never leaves a lock without its owner and two senders never
both create one; (wave 28c, D4 / F42-7, F43-5, F44-2) a lock is taken over ONLY when its owner process
(pid and start time) is gone - a lock whose owner lives is left alone however old it is and reported
(`another flush is running: sender busy since <t> (pid <n> holds its lock, <s> s old - its owner
lives: left alone)`), an owner whose identity cannot be confirmed counts as living; (wave 28d, D3)
once it is older than 30 minutes it is reported as `sender stuck since <t> (pid <n>)` - in `.last`
`notes` and by `-Status` - with what the operator can do (stop that pid if it hangs, or delete the
lock when no such process runs). A lock that names no owner or cannot be read counts as HELD while it
is younger than 30 s; after that it is removed and the sender starts over (`a stale sender lock was
taken over: it named no owner for <s> s`); a dead owner's lock is removed at once.
The 5-minute age rule of wave 28b is gone. Every sender writes its token into the lock
and checks it again right before each send and each spool rewrite: a sender that lost its lock
stops without rewriting (`this sender lost its lock ... - it stopped without rewriting the spool`;
the lines it delivered are sent again later - at least once). The owner releases its lock in
`finally`. The sender reads the spool oldest first, drops lines older than 7 days,
posts the events in batches of at most 100 and the complaint lines one by one, removes what was
delivered and keeps the rest. Delivered means a 2xx answer that is a JSON object with `"ok": true`.
(D8) Against the intake as it is built: a batch refused with `400` `events[i]: <reason>` - event i
is dropped (one line in `.last` `rejected`) and the rest resent, at most three times per flush;
`413` - the batch is halved (an event refused alone is dropped); `403` - the flush stops, the spool
is kept, `.last` says why; any other 4xx, a 5xx, an HTML page, a timeout - the flush stops there,
keeps the spool and costs exactly one line in `codex-telemetry.ps1 -Status`, never a warning in a
consultation; the next consultation's sender tries again. A `429` whose `Retry-After` is at most
60 s - and fits into the flush's deadline - is waited for and the same request sent once more; a
longer one, a missing one or a second 429 ends the flush. The result is written to `<spool>/.last`
`{time, result, delivered, kept, dropped, rejected, http, not_spooled_seen, not_spooled_folded, notes}` (wave 28d: `notes` - at
most 10 lines `<time> <text>` of what the telemetry client did or saw on its own, carried from flush to
flush; a `sender stuck` line goes once a sender holds the lock again). `codex-telemetry.ps1 -Flush` sends by
hand (exit `0` done or nothing to send, `1` something not delivered, `2` another sender holds the
lock).

**The intake.** `https://xelth.com/T` (the "T-hub" v2 contract: `POST /v2/events`, `POST
/v2/complaints`, `DELETE /v2/instances/<id>?public_ref=<ref>`, `GET /health`) - the intake is live.
`CODEX_CONSULT_TELEMETRY_URL` is an operator setting naming another base URL: https only; (D4)
plain http is accepted only for a loopback host (`127.0.0.1`, `localhost`, `::1`) AND with
`CODEX_CONSULT_TEST_MODE=1` - a harness's local intake. Every harness but `harness-telemetry` runs
with `CODEX_CONSULT_TELEMETRY=off`, and that one talks to a local `HttpListener` only.

**Complaints and suggestions:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-consult.ps1" -Task <task> -Complain "<text>" [-Contact "<how to reach you>"] [-Yes]
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-telemetry.ps1" -Complain "<text>" [-Task <task>] [-Contact "<c>"] [-Yes]
```

The payload `{app_id, app_version, instance_id, text (at most 8 KiB of UTF-8), context
{consultation - the task's LAST ledger entry through the same allowlist as `details`, or `null`;
bridge_version; os; runtime}, contact (or null)}` is printed in full - exactly the bytes that are
sent -, then `send? [y/N]` unless `-Yes`, then it goes to `<intake>/v2/complaints`
synchronously (10 s). Delivered: `complaint delivered - public_ref <ref>` - quote it when you
write to the maintainer, and keep it: it is the proof `-Forget -PublicRef` needs. Not delivered:
`not delivered (<why>); kept in the spool as a complaint line` - (wave 28b, D7) the spool keeps
EXACTLY the text that was shown, and the sender posts those same bytes later. A complaint is an
explicit, confirmed send: it does not depend on the switch. Exit `0` delivered, `1` refused or not
confirmed, `3` not delivered (kept). `-Complain` takes only `-Task`, `-CollabDir`, `-Contact`,
`-Yes`.

**State:** `codex-telemetry.ps1 -Status` - the switch and where it comes from, the intake URL,
the spool's counts, the events not spooled since the last flush, (wave 28c, D3) the forgetting
marker when it is there (wave 28d: and whether its owner lives), (wave 28d, D3) the sender's lock when
there is one (`sender     : busy since ...` / `sender stuck since <t> (pid <n>) ...` / a stale one), the
last flush's result and its notes (`note       : ...`), the instance id (not secret), whether the notice
was shown for this version, and `test mode  : ON` when `CODEX_CONSULT_TEST_MODE=1`. Reads only.

**Your data - delete it** (wave 28b, D9; wave 28c, D2). At the intake:
`codex-telemetry.ps1 -Forget -PublicRef <ref>` sends `DELETE <intake>/v2/instances/<your instance
id>?public_ref=<ref>` - the intake removes every event and complaint of this instance; `<ref>` is the `public_ref` a
delivered complaint of this instance printed (send one first if you have none: `-Complain "Please
delete my data." -Yes`). Locally: `codex-telemetry.ps1 -Forget -Local` removes the spool (every file
of it), the salt (and any `telemetry-salt.bad-*` kept aside) and the not-spooled count - the next
event starts a new instance id, which cannot be linked to the old one. To do both, give both
switches: `-Forget -PublicRef <ref> -Local` asks the intake FIRST and deletes locally only after the
intake confirmed the DELETE (a 2xx answer with `"ok": true`); any other answer - a wrong reference,
an intake that cannot be reached - deletes NOTHING, not there and not here: the salt, the spool and
the counters stay, the reason is printed, the exit is `3`, and the same command can be repeated
with the right reference (while the DELETE runs the telemetry lock and the forgetting marker are
held, so no event is spooled or sent in between). `-Forget -Local` ALONE first says in one line that
the intake still holds what this machine sent and how to remove it - `-Forget -PublicRef <ref>`
BEFORE `-Local`, because the instance id dies with the salt - then asks `remove locally? [y/N]`
unless `-Yes`. The local deletion holds the telemetry lock and writes the forgetting marker (removed
last - wave 28d: in `finally`, also when the deletion fails halfway), and is refused while a sender
holds its lock. Exit `0` done, `1` refused or not confirmed
(no salt, no `-PublicRef` or `-Local`, a sender holding the lock, no `y`), `3` the intake did not
confirm the deletion (nothing deleted). The salt is created atomically (D5): a new salt is written
to a temporary file and moved into place without overwriting - (wave 28c) under the telemetry lock -,
a racing creator reads the winner's salt, and a salt that parses is never deleted or replaced.

---

## Project isolation

One user-scope install serves every project without mixing them: the ledger and handoffs
live under `<repo>/<CollabDir>/<task>/` (`<repo>` = `git rev-parse --show-toplevel` of the
current directory, else the directory itself), parent threads come only from that
repository's `sessions.json`, endpoint health only from that repository's ledgers, and
`codex` runs with the repository root as its working directory. The read-only sandbox
blocks writes, not reads, so keep briefs inside the repository and never pass a `-Thread`
taken from another project's ledger. Codex's own `memories` feature (`codex features
list`), if enabled, is a Codex-side channel across all threads; the bridge neither reads
nor writes it.

---

## Options

`codex-consult.ps1`:

| Option | Default | Notes |
|---|---|---|
| `-Task <id>` | *required* | slug; groups one conversation under `<CollabDir>/<id>/` |
| `-Brief <path>` / `-Prompt <text>` | — | at least one; the brief must exist (resolved against the current directory, then the repo root) |
| `-Purpose <purpose>` | *(none)* | prompt paragraph, preset effort and word cap: "Review purposes" |
| `-Mode new\|fork\|resume` | `fork` when a thread of this run's lineage is known, else `new` (agy, muse: `new`; `resume` with `-Thread`) | `fork` branches, `resume` appends; agy and muse have no `fork` (Wave 29) The claude engine allows `fork` (`--resume <parent> --fork-session`) as well as `resume`; default `new`. |
| `-Thread <uuid>` | the newest verified thread of this lineage in this task | needs `fork`/`resume`; must belong to this lineage |
| `-Provider <name>` | first available roster entry; without a roster, the config's `model_provider`, else `openai` | case-sensitive table name; needs `-Model` unless its roster entry names one |
| `-Model <name>` | the roster entry's model, else the config's top-level `model` | the resolved model is always passed as `-m`; without `-Provider` it restricts the roster walk |
| `-Effort low\|medium\|high\|xhigh` | the purpose preset (`high` without one) | mapped through the endpoint's caps-v1 vocabulary |
| `-NativeEffort <token>` | — | sent verbatim; excludes `-Effort`; required where caps-v1 declares nothing |
| `-MaxWords <n>` | the purpose preset (`700` without one) | prose only |
| `-Sandbox read-only\|workspace-write` | `read-only` | `danger-full-access` is refused, with no flag to force it |
| `-TimeoutSec <n>` | the purpose's default (0.5.0: 600-3600 s, "Timeouts, the continuation and the partial reply") | the main turn's process TREE is killed past it; ledger `timeout_sec`, `timeout_source` |
| `-ContinueSec <n>` | the smaller of the timeout and 900 s | (0.5.0) the budget of the ONE continuation turn on the killed turn's thread; `0` = off; ledger `continue_sec`, `timeout_continue` |
| `-StallSec <n>` | the roster entry's `stall_sec`, else `900` | (wave 26b, R18) the stall cut: no event line in the engine's stream for n s while its process lives - stopped like a timeout (the continuation turn, the salvage); `0` = off; a panel passes it to every member; ledger `stall` |
| `-Range <from>..<to>` | — | (0.5.0) diff-review and acceptance only: `git diff --shortstat` once - the size in the prompt and the ledger (`range`), a warning above 1500 lines with a timeout below 2400 s; an unknown range and a single revision (only `base..head` / `base...head`) are refused |
| `-ReplyName <slug>` | `reply` | names `handoffs/<NN>-codex-<slug>.*` (`<NN>-agy-<slug>.*`, `<NN>-muse-<slug>.*` for the engines) |
| `-Artifact <path>[,<path>…]` | — | one comma-separated string; hashes built artifacts into the ledger; a missing path refuses the run |
| `-Raw` | off | 0.1-style plain-text reply: no schema, no findings, no format repair |
| `-FormatRetry 0\|1` | `1` | one recorded repair turn for a substantive prose reply; any other value refuses |
| `-SchemaTransport output-schema\|prompt-only\|native` | caps-v1's declared transport | one run only; not with `-Raw`; `native` (agy's `--json-schema`, muse's `--output-schema`) only for agy and muse, `output-schema` only for codex (Wave 29) claude: `native` (`--json-schema`, the default) or `prompt-only`. |
| `-CodexConfig key=value[,…]` | — (roster `codex_config` when empty) | one comma-separated string; refused keys: "Per-run Codex overrides (-CodexConfig)" |
| `-OffPeakOnly` | off | refuses at peak and when no schedule is set |
| `-SkipPreflight` | off | bypasses every preflight refusal; ledger `preflight: "skipped"` |
| `-Panel` / `-PanelAll` | off | a review panel of the roster, in parallel across endpoints (one after another within one): (wave 26) as many members as the purpose needs, seated by their track record; `-PanelAll`: every eligible entry, `weighty` ones included; needs a roster; not with `-Provider`/`-Thread`/`-Mode resume` ("Companions") |
| `-PanelConcurrency <n>` | `0` | `-Panel` only: at most n members at a time on top of the per-endpoint plan; `0` no cap, `1` strictly one after another |
| `-PanelSize <n>` | the purpose's size (1-4, `stuck`: all) | (wave 26) `-Panel` only: the members started; not with `-PanelAll`; silences the framing/decision floor warning |
| `-PanelOrder routed\|roster` | `routed` | (wave 26) `-Panel` only: draw the seats by the ratings (roster order while no eligible reviewer has 3 marks), or keep the roster order |
| `-PanelSeed <n>` | `CODEX_CONSULT_TEST_PANEL_SEED`, else today's UTC date | (wave 26) `-Panel` only: the nonce of the routing seed (a number or token) |
| `-Topic <a>[,<b>…]` | — | (wave 26) the consultation's topics (slugs): ledger `topics[]`, copied onto its mark; a routed panel scores on them |
| `-Require <reviewer>[,…]` | the roster's `require` for the purpose (a panel) | (wave 26) `-Panel`, or a single run with `-Provider`: `#<position>`, a label or `<provider> :: <model>` [` [<engine>]`]; out = exit `5` before anything starts; `none` drops the roster's |
| `-Role <name>` | — | (wave 26) a role block after the ask (`<CollabDir>/roles/<name>.md`, else `templates/role-<name>.md`); a panel: every member; not with `-Roles`; ledger `role` |
| `-Roles <a>[,<b>…]` | — | (wave 26) `-Panel` only: one role per member by score rank (a roster entry's `roles` = willing); at most one per member |
| `-CollabDir <path>` | `.collab` | relative to the git repo root |
| `-CodexExe <path>` | the launcher on PATH | env override `CODEX_CONSULT_EXE` |
| `-Engine codex\|agy\|muse` | the roster entry's engine (the thread's with `-Thread`), else `codex` | "Engines"; with a roster and no `-Provider`/`-Thread` it restricts the walk (and `-Panel`) to that engine (Wave 29) `claude` is the fourth value: `-Engine codex\|agy\|muse\|claude`. |
| `-EngineExe <path>` | the engine's launcher on PATH (muse: then `%LOCALAPPDATA%\Programs\muse\muse.cmd`) | the launcher of the SELECTED engine other than codex: `-Engine`'s, else the `-Provider`'s roster entry's, else the only such engine of the roster (several: refused - pass `-Engine`); env overrides `CODEX_CONSULT_AGY_EXE`, `CODEX_CONSULT_MUSE_EXE` (Wave 29) claude: `CODEX_CONSULT_CLAUDE_EXE`, then `claude.exe`, `claude.cmd`, `claude` on PATH, then `%USERPROFILE%\.localin\claude.exe` (`~/.local/bin/claude` elsewhere). |
| `-MaxModelSteps <n>` | not sent (the CLI's default) | muse only (wave 23): `--max-model-steps <n>`; refused with another engine; passed to a panel's muse members; ledger `engine_run.max_model_steps` (Wave 29) Also claude: `--max-turns <n>`; any other engine is refused with `-MaxModelSteps is for an engine with a model-step cap (muse --max-model-steps, claude --max-turns); the <engine> engine has none.` |
| `-DenialRetry 0\|1` | `1` | agy: one more turn on the same conversation after a run that produced nothing because a tool was auto-denied; ledger `denial_retry` (muse has none) |
| `-DryRun` | off | prints the plan (argv, prompt, paths, preflight, roster pick, ledger entry); calls nothing, writes nothing |
| `-Detach` | off | (0.5.0) checks the run here like a real run, then runs it in a background process and returns at once (exit `0`): the detach id, the status file, the come-back commands; a single run or `-Panel`; not with `-DryRun`, `-Status`, `-Wait` ("Non-blocking consultation") |
| `-Status [-Id <id>] [-Prune]` | — | (0.5.0) the detached runs of the task: state, members, the summary block once done; exit `0` / `1` / `2` / `4`; reads status files only - `-Prune` deletes those of runs done or died more than 7 days ago; takes only `-Task`, `-CollabDir`, `-Id`, `-Prune` |
| `-Wait [-Id <id>] [-WaitTimeoutSec <s>]` | the run's `budget_sec` | (0.5.0) waits (every 2 s) until the run(s) are done or their background is gone, then prints as `-Status`; exit `3` when still running after the limit |
| `-Id <id>` | every detached run of the task | (0.5.0) with `-Status` / `-Wait` / (wave 26b) `-Kick`: one run, by its detach id or a prefix of it (the 8 hex digits `-Detach` prints); a prefix of several runs is refused (exit `4`) |
| `-Kick -Member <NN> [-Id <id>]` | — | (wave 26b) from another shell: stop ONE running member of a panel (or a single run) of `-Task` by its handoff number - a detached run with `-Id`, a foreground panel without; its process tree is stopped, its partial output salvaged, it records `failed: stopped by the operator (-Kick)` (class `operator`) and the panel goes on; (wave 26c) waits up to 10 s for the member's acknowledgement; exit `0` acknowledged, `1` no such member or not running, `3` no acknowledgement in time, `4` refused. Takes only `-Task`, `-CollabDir`, `-Member`, `-Id` |
| `-BriefPrefix <slug>` | `CODEX_CONSULT_BRIEF_PREFIX`, else `claude` | (wave 27, R13) the coordinator's brief prefix: its briefs are `handoffs/<NN>-<prefix>-<slug>.md`; a lowercase slug; a reply prefix (`codex`, `agy`, `muse`) is refused before anything starts (exit `1`, the dry run too); the dry run prints `brief prefix:`; the bridge never writes a brief |
| `-Explain coordinate\|consult\|providers` | — | (wave 27, R13) prints the plugin's skill `coordinate`, `consult-codex` or `setup-providers` - one line naming the file and the plugin directory, then the SKILL.md without its front matter, UTF-8 - for a host without skills; read-only, exit `0`; takes no other parameter (not even `-Task`); an unknown name exits `1` |
| `-Telemetry on\|off` | `CODEX_CONSULT_TELEMETRY`, else `on` | (wave 28, R17) this run's telemetry switch: `on` spools ONE anonymised event after the commit and starts the detached sender, `off` writes and sends nothing; a panel passes it to its members; another value is refused (exit `1`); the dry run prints `telemetry   : on\|off (<source>)` ("Telemetry (on by default)") |
| `-Complain "<text>" [-Contact <c>] [-Yes]` | — | (wave 28, R17) a complaint or suggestion to the maintainer's intake: prints the exact payload (the text - at most 8 KiB -, the task's last ledger entry through the event's allowlist, the plugin version, the OS, the instance id), asks `send? [y/N]` unless `-Yes`, prints the `public_ref` - or keeps it in the spool; exit `0` delivered, `1` refused or not confirmed, `3` not delivered (kept). Takes only `-Task`, `-CollabDir`, `-Contact`, `-Yes`; independent of the switch |

Exit codes of `codex-consult.ps1` (a run; `-Status`/`-Wait` have their own table in
"Non-blocking consultation"):

| Exit | Meaning |
|---|---|
| `0` | a usable reply (a panel: every member's); `-DryRun`: the plan could be made; (wave 27) `-Explain`: the skill was printed |
| `1` | a refusal before anything started (the message says why), or a run or a panel member without a usable reply |
| `5` | (0.5.0, wave 26) a REQUIRED reviewer (`-Require`, the roster's `require`) is not available - refused before anything started, the dry run too - or, in a panel, produced no usable reply (no further member was started) |
| `6` | (0.5.0, wave 26) a detached run's background could not make its status file final (3 attempts); the run's result exists only in its log |

`-Kick` (wave 26b; wave 26c, D1): `0` the member acknowledged the kick (its tree is being stopped,
it records the operator's failure - or, its turn had already finished, `kick_late` and an unchanged
outcome), `1` no such member or no engine turn running (a detached run named by `-Id` without that
member, a member not running; a kick file of that number is removed), `3` no acknowledgement
within 10 s (the kick file stays for the member's next poll), `4` the query is refused (`-Member`
missing or not a number, another option given).

Environment variables:

| Variable | Set by | Effect |
|---|---|---|
| `CODEX_HOME` | user | Codex home: `config.toml`, `sessions/` (rollout files), the default roster; default `~/.codex` |
| a table's `env_key` (e.g. `ZAI_API_KEY`) | the user only | the provider credential; the bridge only checks that it is set |
| `OPENAI_BASE_URL` | user | folded into the built-in `openai` identity (drift when it changes) |
| `CODEX_CONSULT_ROSTER` | user | roster file path (must exist), or `none` |
| `CODEX_CONSULT_COORDINATOR` | the coordinator (its session) | (wave 27, R13) the coordinator's own model: `<provider> :: <model>` [` [<engine>]`], a roster position `#<n>` or a provider label, parsed like `-Require`; a reviewer whose resolved identity it names gets a warning (never a refusal); a value that does not parse refuses the run before anything starts; ledger `coordinator`. (Wave 27c, D9-D12) Resolved like a seated reviewer (a triple: the entry's model, else the model the bridge would run); "own model" only when provider, model and engine are equal, the weaker "a reviewer from the coordinator's own provider (model not named)" for a label whose model cannot be told; only a value that cannot be PARSED is refused (the roster's character rule); one no roster entry matches is said (`coordinator.in_roster` false), a `#<n>` that names no position here is warned about (`coordinator.unresolved`) |
| `CODEX_CONSULT_BRIEF_PREFIX` | the coordinator | (wave 27, R13) the coordinator's brief prefix when `-BriefPrefix` is not given (default `claude`); a reply prefix (`codex`, `agy`, `muse`) is refused |
| `CODEX_CONSULT_ROOT` | the operator or the coordinator (a shell) | (wave 27, R13) the plugin directory for commands typed in a plain shell - the skills' `${CLAUDE_PLUGIN_ROOT}`; the scripts do not read it (they find their siblings themselves) |
| `CODEX_SESSION_ID`, `CODEX_THREAD_ID`, `CODEX_CI`, `CODEX_SANDBOX*`, `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`, `AI_AGENT`; (wave 27b) `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_BRIDGE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION`, `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDE_CODE_MESSAGING_TOKEN`, `CLAUDE_CODE_SESSION_ATTENDED`, `CLAUDE_CODE_EXECPATH`, `CLAUDE_PID`, `CLAUDE_EFFORT`; (wave 27c) `ZCODE_*` (the whole prefix - read inside a Z Code session on 2026-09-29, desktop 3.14.3) | the coordinator's host | (wave 27, R13) host markers: read once for the ledger's `coordinator.host` (a hint: the codex markers, then any `ZCODE_` variable, then the claude-code markers, else the install path), never passed to an engine child (ledger `child_env_scrubbed`). Exact `CLAUDE_CODE_` names: `CLAUDE_CODE_USE_BEDROCK` and the like, `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` are kept |
| `CODEX_CONSULT_TELEMETRY` | the operator (tests: `off`) | (wave 28, R17) the telemetry switch: unset or empty, `on`, `1`, `true`, `yes` - on (the default); `off`, `0`, `false`, `no`, `none` - off; any other value counts as off. `-Telemetry on\|off` overrides it for one run ("Telemetry (on by default)") |
| `CODEX_CONSULT_TELEMETRY_URL` | user (an operator setting; tests: a local intake) | (wave 28) the intake's base URL instead of `https://xelth.com/T`; https only - (wave 28b, D4) plain http only for a loopback host AND with `CODEX_CONSULT_TEST_MODE=1` |
| `CODEX_CONSULT_HEALTH` | user (tests: a scratch path, or `none`) | (wave 26b, R20) the machine-wide endpoint health file ("Preflight and endpoint health"); default `<codex home>/codex-consult-health.json`; `none`: no file, read nor written |
| `CODEX_CONSULT_PEAK_<PROVIDER>`, `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` | user | peak windows |
| `CODEX_CONSULT_EXE` | user | codex launcher path |
| `CODEX_CONSULT_AGY_EXE` | user | agy launcher path (the `agy` engine) |
| `CODEX_CONSULT_MUSE_EXE` | user | muse launcher path (the `muse` engine) |
| `CODEX_CONSULT_CLAUDE_EXE` | user | claude launcher path (the `claude` engine, wave 29) |
| `TBH_CREDENTIAL_BACKEND` | the user (Muse Code's own variable) | `file` keeps the Muse sign-in in `~/.config/muse/auth.json`, which the bridge can read; required (wave 23b: without a readable oauth sign-in no muse run is launched, `-SkipPreflight` included); passed to muse unchanged |
| `META_API_KEY`, `MODEL_API_KEY` | nobody, for the bridge | must NOT be set: a muse run is refused while either is (it would bill per token instead of the subscription) |
| `CODEX_CONSULT_NOW`, `CODEX_CONSULT_TEST_SURVIVORS`, `CODEX_CONSULT_TEST_DETACH_GUIDS`, `CODEX_CONSULT_TEST_PANEL_SEED`, `CODEX_CONSULT_TEST_TELEMETRY_ENV`, (wave 28b) `CODEX_CONSULT_TEST_REGISTER_FAIL`, `CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST`, `CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS`, `CODEX_CONSULT_TEST_TELEMETRY_FLUSH_MS`, (wave 28c) `CODEX_CONSULT_TEST_START_UNREADABLE`, (wave 28d) `CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH`, (wave 28e) `CODEX_CONSULT_TEST_CMDLINE_UNREADABLE`, `CODEX_CONSULT_TEST_FOLD_CRASH` | tests only | test hooks; never set them in normal use - (wave 27c, D14) they are honoured ONLY while `CODEX_CONSULT_TEST_MODE=1` is set too (every harness and `run-all.ps1` set it); without it they are ignored and a run warns once: `test hook(s) ignored - CODEX_CONSULT_TEST_MODE=1 is not set: <names>` (`CODEX_CONSULT_TEST_PANEL_SEED`: the routing seed's nonce when `-PanelSeed` is not given; (wave 28; wave 28b) `CODEX_CONSULT_TEST_TELEMETRY_ENV=<path>`: the telemetry sender writes there the NAMES of every variable of its environment; (wave 28b) `CODEX_CONSULT_TEST_REGISTER_FAIL=1`: the registration write of the engine process fails (D19); `CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST=1`: the first endpoint update of a run fails (D13); `..._TELEMETRY_REQUEST_MS` / `..._FLUSH_MS`: the sender's bounds). (wave 28b, D10) A run that finds `CODEX_CONSULT_TEST_MODE=1` says `test mode is ON: test hooks are honoured` on the console and in `warnings[]`; no ENGINE child (a turn, a launcher probe) gets `CODEX_CONSULT_TEST_MODE` or any `CODEX_CONSULT_TEST_*` variable - a panel member and the detached background (the bridge itself) keep them, the telemetry sender gets only the test mode and its own hooks. (wave 28c, D12) Where the line appears: the console of a committed run (after the commit) and its `warnings[]`, a dry run (with the other run warnings, and its preview's `warnings[]`), a -Panel run (the panel's lines, and each member's `warnings[]`), a detached run (its foreground's lines and the background's entry) - NOT on a refused run: a refusal stops before anything starts or is written. (wave 28c) `CODEX_CONSULT_TEST_START_UNREADABLE=<pid>[,<pid>]`: these pids read as a process whose start time cannot be read (D8); `CODEX_CONSULT_TEST_KILL_DENIED=taskkill`: only `taskkill` is denied (`=1` denies the enumeration too); (wave 28e, E19) `CODEX_CONSULT_TEST_CMDLINE_UNREADABLE=<pid>[,<pid>]`: these pids read with a command line that cannot be read ((wave 29, E27) in the machine-wide process scan too); (E20) `CODEX_CONSULT_TEST_FOLD_CRASH=1`: a flush exits (code 87) between the save of `.last` and the deletes of its fold, (E26) `=2`: it exits (code 88) between the deletes and the rewrite of `.last`. (Wave 29) `CODEX_CONSULT_TEST_CHILD_ENV_PASS=<prefix>` (test mode only): lets the environment variables with that prefix through to a claude engine child (the harness's fake reads `FAKE_CLAUDE_*`); never a prefix of ANTHROPIC, CLAUDE or CODEX_CONSULT. |
| `CODEX_CONSULT_SCRIPTS_DIR` | tests only | (0.5.0, T4) the scripts directory `tests/run-all.ps1` and every harness test when `-ScriptsDir` is not given (e.g. an installed copy of the plugin); unset: the checkout's `plugins/codex-consult/scripts` |

---

## How it works

The bridge shells out to the documented `codex exec` CLI and makes no HTTP call to any
provider; a plan's credentials are only ever used by the Codex CLI itself. (0.5.0, wave 28) The
plugin's one HTTP client is the telemetry sender (`codex-telemetry.ps1`), which talks only to the
maintainer's intake, detached from every consultation ("Telemetry (on by default)"). Four invocation
rules are load-bearing; keep them if you change the command:

1. **Exec options precede the subcommand:**
   `codex exec --sandbox read-only --color never --json [-m <model>] -c model_reasoning_effort="<e>" [-c model_provider="<p>"] [-c <CodexConfig>…] -o <file> [--output-schema <schema>] [fork|resume <thread>] -`.
   `codex exec fork --help` has no `--sandbox` or `--color`; placed after `fork` they fail
   with *unexpected argument*.
2. **The prompt travels on stdin (`-`), never as an argument.** On Windows `codex` is an npm
   shim (`codex.cmd`) and `cmd.exe` expands `%VAR%` inside quoted arguments, which would
   silently rewrite a brief that mentions `%APPDATA%`.
3. **The thread id comes from the event stream.** Every run (`new`, `resume`, `fork`) emits
   `{"type":"thread.started","thread_id":"…"}` first, and that id is the RESULTING thread,
   the one to continue later. The fallback is a rollout file under
   `$CODEX_HOME/sessions/<y>/<m>/<d>/` verified by the consultation id ("Reviewer identity
   and lineage").
4. **Two `Start-Process` traps on Windows PowerShell 5.1:** `-PassThru` returns an empty
   `.ExitCode` unless `.Handle` is touched before the child exits, and the redirection
   files stay locked briefly after exit ("the process cannot access the file"). The script
   caches the handle and reads with `FileShare.ReadWrite` plus a short retry.

A launched run that fails still writes its reply file (the stderr tail as its body) and a
ledger entry, so a failure is as inspectable as a success.

---

## Alternatives

| Project | Shape | Trade-off against this plugin |
|---|---|---|
| [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) (official) | Claude Code plugin: `/codex:review`, `/codex:adversarial-review`, `/codex:rescue`, session hooks | review/rescue shaped; resumes only its own latest thread, no chosen thread, no fork; open Windows sandbox issue [#349](https://github.com/openai/codex-plugin-cc/issues/349) (sandbox modes fail, reviews come back empty) |
| [parisbs/codex-subagent-mcp](https://github.com/parisbs/codex-subagent-mcp) | MCP server: `codex_delegate`, `codex_follow_up`, background jobs | `resume` only; no brief/reply file trail |
| [newtro/mcp-codex-bridge](https://github.com/newtro/mcp-codex-bridge) | MCP server: `codex_ask`, `codex_review`, `codex_implement` | no thread continuity |
| [xihuai18/codex-mcp](https://github.com/xihuai18/codex-mcp) | MCP server: `codex_session` with fork, `codex_reply` | has fork, but unmaintained while the Codex app-server protocol moved |
| [j-token/codex-mcp](https://github.com/j-token/codex-mcp) | MCP server over the Codex SDK | resume, no fork; needs Bun |
| [masuP9/agent-dialectics](https://github.com/masuP9/agent-dialectics) | Claude Code plugin: strong-inference / devil's-advocate skills | a fresh thread every time, by design |

`codex mcp-server` was removed in Codex 0.154 and `codex app-server` is an experimental
JSON-RPC surface; a thin wrapper around `codex exec` is the stable surface.

---

## Tested on

| Platform | What ran |
|---|---|
| Windows 11, Windows PowerShell 5.1, Codex CLI 0.155.1 | all twenty harnesses (see "Tests"; last full run 2026-09-30, 0.5.0 wave 28d, the final code: `20 harness(es), 0 failed`; wave 28c: `19 harness(es), 0 failed`; wave 28b on 2026-09-30: `18 harness(es), 1 failed` - `harness-detach` SINGLE, a check the test-mode line of D10 outgrew; fixed and run alone, 51 passed, the full suite not run again -; waves 27c and 28 on 2026-09-29: `17 harness(es), 0 failed`; before, waves 26c-27b: green but `harness-fixes`' two environmental F04-10 cases). Live: the 0.2.0 release review (`.collab/bridge-0.2-2026-09-23/`: framing `new`, acceptance `fork`, re-acceptance `resume`; three HOLDs with 11, 3 and 1 findings, then ACCEPT on 2026-09-24 after four fix waves; 12 findings verified, 2 superseded, 1 accepted limitation) and the 0.3.0 rounds below. The first live call hit the account's usage limit, which exercised the whole failure path (thread id still parsed from `thread.started`, the message lifted from the event stream, reply file and ledger entry written, non-zero exit) |
| PowerShell 7.6 on Windows 11 | all twenty harnesses (last full run 2026-09-30 under 7.6.6, wave 28d, the final code: `20 harness(es), 1 failed` - `harness-fixes26b` GUARD only, environmental: the operator's Codex desktop app rewrote `~/.codex/config.toml` at 20:33 while that harness ran -, the same counts as on 5.1; wave 28c: `19 harness(es), 0 failed`; wave 28b: `18 harness(es), 0 failed`). One pwsh-only defect fixed in 0.2.0: `ConvertFrom-Json` turns ISO-8601 strings into `[datetime]`, which broke the start-time comparison that recognises a live lock holder or codex child; those reads now normalise through a JSON-text helper |
| Linux (WSL Ubuntu 24.04, PowerShell 7.6, ext4), 2026-09-24 | with a bash fake `codex`: dry run, full structured run, lock contention through the advisory `flock` (second consultation and `-Status` refused, `-List` works, lock inode unchanged), timeout with the tree killed and no survivors, recovery of `launching` and `survivors` records through the `ps` scan, `chmod +x` changing the fingerprint, `$HOME/.codex` resolution, atomic `findings.json` replacement. Three Linux-only defects fixed: start times read by .NET can differ by under a second between readers (one-second tolerance off Windows); the holder's lock file could not be read back through a shared `FileStream` (read via `cat` off Windows); the timeout kill stopped children before the root (root first now). Known and left: an atomic replace resets the store's Unix permission bits; dates in messages render in an invariant format |
| macOS | **not exercised**; the Linux run covers the same pwsh code paths |
| 0.3.0 live (`.collab/bridge-0.3-2026-09-24/`) | design review and two acceptance rounds on the `openai` lineage (a `new` thread, then the first `resume` under the provenance rules); GLM-5.3 through `-Provider ZAI` (plain-Markdown reply kept with no verdict); MiMo through `-Provider mimo` with a per-run catalog (first attempt refused by the endpoint, `--output-schema` unsupported, lifted into the ledger; then, `prompt-only`, a bare-JSON HOLD ingested as F09-1..4 while reporting five earlier ids fixed); the first live panel (`-PanelAll`, real roster) found F15-1..4 through GLM-5.3 and MiMo after the weighty member was skipped on a known reset time; with the output contract buried after the schema the z.ai route answered in prose twice, and after the contract-first prompt it returned bare JSON (two cheap reviewers had independently diagnosed that cause). `codex-providers.ps1` on the real config: `openai` (`Logged in using ChatGPT`), `ZAI` and `mimo` (env keys) available. An earlier 0.2.0 smoke test of GLM-5.3 is in `.collab/multi-model-2026-09-23/` |
| Coordinator host: Claude Code | the coordinator of every live run above (the plugin through `/plugin install`, its skills and the SessionStart hook) |
| Coordinator host: Codex CLI 0.155.1 | the operator installed the plugin with the two documented commands; live coordinator runs 2026-09-29 with `codex exec`: the session-start line in the context, the three skills listed (`codex-consult:consult-codex`, `:coordinate`, `:setup-providers`), the operator's `CODEX_CONSULT_COORDINATOR` kept, ledger `coordinator {openai :: gpt-6-astra, host: codex, source: explicit}`, `child_env_scrubbed: [CODEX_CI, CODEX_SESSION_ID, CODEX_THREAD_ID]`. Inside `--sandbox workspace-write` with network access enabled the reviewer child had no connection (timeout after 900 s; the process tree was not killed - wave 27c D16; `pwsh` was the WindowsApps alias the sandbox refused - D18). Outside the sandbox (the operator's decision): one checkpoint consultation, reviewer `mimo :: mimo-v2.6-pro`, usable reply in 502 s, brief prefix `coordinator` |
| Coordinator host: Z Code (desktop 3.14.3, CLI 0.16.9) | install verified (the plugin enabled, its skills and SessionStart hook recognised, both root variables substituted); live coordinator run 2026-09-29 inside the app: one checkpoint consultation, reviewer `byteplus :: deepseek-v4.1-flash`, usable reply in 598 s, brief prefix `zcode`, the run started in a background shell because the host's shell tool stops at 600 s (wave 27c D24); with the code of wave 27b the host was recorded `unknown` and nothing was scrubbed - its shell tool carries twelve `ZCODE_` names, none of the two probed (D20, D21); no session-start line reaches the context of a desktop session (D23) |
| Coordinator host: Kimi Code 0.27.0 | live coordinator run 2026-09-29 (headless `-p`, `--skills-dir <clone>/plugins/codex-consult/skills`, `CODEX_CONSULT_ROOT`, the three `AGENTS.md` lines): one checkpoint consultation from the README and the skills alone - reviewer `mimo :: mimo-v2.6-pro`, usable reply in 143 s, brief prefix `kimi`, ledger `coordinator.source: explicit`, `host: unknown`, `child_env_scrubbed: []` (the host sets no marker). Its remarks went into the skill (the first consultation of a task) and the `AGENTS.md` lines (the operator's `CODEX_CONSULT_COORDINATOR` is kept). Shell tool limit: 300 s in the foreground (wave 27c D24) |
| Coordinator host: Qwen Code 0.15.6 | install verified 2026-09-29: `qwen extensions install https://github.com/xelth-com/claude-codex-consult:codex-consult --consent` put the whole plugin directory, enabled, into `~/.qwen/extensions/codex-consult`; `qwen extensions list` showed the skills and the three agents; `${CLAUDE_PLUGIN_ROOT}` in the skill text was replaced by the install path; `hooks/hooks.json` was copied, no hook listed. Live coordinator run: none (the free Qwen OAuth quota ended on 2026-04-15 - the session had no model access; `/auth` is the operator's step) |
| Coordinator host: OpenCode 1.17.18 | nothing verified on the machine: the skill directories and the name rule are those of its documentation (opencode.ai/docs/skills, read 2026-09-29). Live coordinator run: none (the provider configured on the machine refused the authentication) |
| Coordinator host: Muse Code 1.4.0 | the commands exist (`muse skills install`, `update`, `list`, `import --from claude\|codex`) and the headless mode (`muse exec --prompt-file <file> --workspace <dir>`) answers. Live coordinator run: none (on Windows its shell tool needs the sandbox setup of Muse Code done once with elevated rights - "sandbox users are not ready"); as a reviewer engine see "Engines (wave 23)" |
| claude engine (wave 29) | fakes only so far (`tests/fake-claude.*`, `tests/harness-claude.ps1`); `claude --version`, `claude --help` and `claude auth status` read on Claude Code 2.1.285 (Windows); the probes P1-P7 of the design review run by the coordinator (see "Engines (wave 29)"). The live verification - one checkpoint, a resume, a panel with two claude members beside a codex member, a denied read - is PENDING (the supervisor's). |

A report from a macOS run is the most useful contribution right now.

---

## Troubleshooting

A failed consultation is still a record: read the reply file's header (`Bridge outcome:`,
`Provider failure:`) and the ledger entry's `bridge_outcome` and `provider_failure`, e.g.
`failed: codex exit 1 - You've hit your usage limit. … try again at 12:21 PM.` For
anything not listed, rerun with `-DryRun` and compare the argv.

| Message or symptom | Do this |
|---|---|
| `provider X is not usable: env X_API_KEY not set` | ask the user to set the variable and restart the coordinator's session; check with `codex-providers.ps1 -Provider X` |
| `provider X: availability could not be established (…)` | run `codex login status` by hand; check for a top-level `profile` key or an unusable table (`codex-providers.ps1` names it) |
| `… rejected as unauthenticated at <when> …` | the user rotates or fixes the credential; then pass `-SkipPreflight` once (the 24-hour window cannot tell "fixed" from "still broken") |
| `… usage limit … lasts until <iso>` / `unavailable (usage limit until <iso>)` | wait, or consult another reviewer (`-Provider`, or let the roster walk pick the next entry) |
| `unavailable (usage limit hit <iso>, reset unknown; retry after <iso>)` | (0.5.0) the endpoint hit a limit and named no reset time: it counts as out for 60 minutes after the hit (a later successful run clears it) - for every caller, an explicit `-Provider` run too (`... out for 60 minutes, until <iso>; nothing was started (pass -SkipPreflight to launch anyway)`); wait, or consult another reviewer |
| `unavailable (burst limit (429) hit <iso>, reset unknown; retry after <iso>)` | (wave 24c) a 429 that names no usage window or quota (ModelArk's burst and concurrency limits): out for 10 minutes after the hit, not 60; wait a few minutes or let the roster walk pick the next entry |
| `hint       : context too long for this plan/model - ...` | (0.5.0) the prompt (the brief and what the reviewer read) outgrew the plan's or the model's context window (class `capability`, never `auth` - the endpoint stays available): narrow the brief (fewer or smaller files, a smaller `-Range`, a reading plan) or choose a model with a larger window |
| the listing says `available` but a panel skipped the entry | run `codex-providers.ps1` in the repository the panel ran in: health comes from THAT repository's ledgers (0.5.0: its `endpoint health:` line names them) |
| `failed: timeout after N s (process tree killed)` with `partial    :` / `resume     :` lines | (0.5.0) read the partial reply (what the reviewer produced before the kill), then run the printed `resume` command: the reviewer continues its own thread with what it already read. For the next big review pass `-Range` and leave `-TimeoutSec` to the purpose, or give the brief a reading plan |
| `WARNING: a range of M lines with a T s timeout: …` | (0.5.0) drop the short `-TimeoutSec` (diff-review defaults to 2400 s, acceptance to 3600 s) or add a reading plan to the brief |
| `no effort vocabulary declared for model …` | use a model caps-v1 declares, or pass `-NativeEffort <value>` |
| `endpoint or protocol of provider X changed since thread …` | the table's `base_url`/`wire_api` changed: `-Mode new` |
| `thread <uuid> belongs to lineage …` / `unknown provenance …` | `-Mode new`, or run as that thread's lineage |
| `-Provider needs -Model …` | add `-Model`, or give that provider's roster entry a `model` |
| `the reviewer roster '<path>' …` | fix the file (see "Reviewer roster and panel") or set `CODEX_CONSULT_ROSTER=none` |
| `a previous consultation's codex process (pid N) is still running…` | wait for it or stop it; delete `.consult.pending.json` only when that process is unrelated |
| `Structured reply: INVALID (…)` / a prose reply | check `format_retry` in the ledger; if the repair was not attempted or failed, the prose is kept; re-ask once, explicitly for the JSON object, if you need the findings tracked |
| `codex CLI not found on PATH …` | `-CodexExe <path>` or `CODEX_CONSULT_EXE` |
| `-OffPeakOnly: X is inside its peak window …` | wait, or drop `-OffPeakOnly` if the user accepts the peak tariff |
| `CODEX_CONSULT_COORDINATOR='…' cannot be used: …` | (wave 27) give `<provider> :: <model>` (optionally ` [<engine>]`), a roster position `#<n>` the roster has, or a provider label - or unset the variable |
| `the brief prefix '…' … is a reply prefix` / `must be a lowercase slug` | (wave 27) `-BriefPrefix` / `CODEX_CONSULT_BRIEF_PREFIX` name the coordinator's briefs: a lowercase slug other than `codex`, `agy`, `muse` (the default `claude` is fine for every host) |
| `WARNING: coordinator: <lineage> is the coordinator's own model …` | (wave 27) the seated reviewer is your own model: a second opinion, not an independent one - pick another reviewer (`-Provider`, the roster) when independence matters |
| `the <engine> run is refused before launch: bridge failure: host markers could not be hidden (<name>: <why>)` | (wave 27c, D3) a host marker of the coordinator's session could not be removed from the environment the engine child would inherit; every removed one was put back and nothing was started. Retry; if it persists, start the coordinator session with fewer inherited variables |
| `failed: timeout after N s (kill not confirmed: ...; pid <n> may still run)` / `warning    : kill not confirmed (...)` | (wave 27c, D16) the process tree could not be seen dead (a restricted host - a sandbox that denies process inspection): check the pid (and its children) and stop them by hand; no continuation was attempted. Run consultations outside such a sandbox ("Codex CLI") |
| `WARNING: test hook(s) ignored - CODEX_CONSULT_TEST_MODE=1 is not set: <names>` | (wave 27c, D14) a harness variable leaked into your environment: unset it (it changed nothing) |
| `WARNING: test mode is ON: test hooks are honoured` | (wave 28b, D10) `CODEX_CONSULT_TEST_MODE=1` is set - normal in a harness; outside one it is a leftover of a test shell that lets test hooks change your runs: unset it |
| `WARNING: CODEX_CONSULT_COORDINATOR '#<n>' names no roster position here ...` / `coordinator: <id> (not in the roster - no reviewer can match it)` | (wave 27c, D11, D12) your coordinator value names nobody in THIS repository's roster: nothing is refused, but no self-review warning can be given - name yourself as `<provider> :: <model>` in the roster's spelling |

---

## Roadmap / help wanted

- Shipped: `ROADMAP.md` R1–R6 and `TECH_DEBT.md` T1–T4 in 0.2.0; R7 (providers with reviewer
  lineages, effort mapping, peak windows), R8 (requested checks, as a prompt/template
  convention) and part of R9 (the roster, the panel, the per-reviewer scoreboard and
  usefulness telemetry) in 0.3.0. Per-item status lines: [ROADMAP.md](ROADMAP.md),
  [TECH_DEBT.md](TECH_DEBT.md).
- 0.4.0 (candidate): R10 **engines**, first row `agy` (Google's Antigravity CLI for the
  Gemini models, native structured output), wave 23 the `muse` row (Meta's Muse Code CLI for
  the Muse Code subscription) - see "Engines". Next: the `claude` engine
  (Claude Code headless, `claude -p --json-schema`) as the second row of the same table,
  R11 (a parallel panel) and the rest of R9 (corroboration/contradiction links `-Link`,
  blind baseline isolation across waves, canonical issues, grouped stats).
- Open tech debt: T5 (a credential rotated inside the 24-hour auth window still needs
  `-SkipPreflight` once), T6 (a legacy entry without `retry_after` can be off by a time-zone
  difference), T7 (an agy or muse lineage binds engine + label + model, not the signed-in
  Google or Meta account), T8 (agy's read-only rule is enforced by evidence: gitignored paths, submodules
  and files outside the repository are not seen, and a change cannot be attributed).
- 0.5.0 (candidate): wave 24 (timeouts that never throw the reviewer's work away, one truth
  about availability) and wave 25 - R12, non-blocking consultation (`-Detach`, `-Status`,
  `-Wait`), and T4 (the harnesses take `-ScriptsDir`); waves 26-26c (companions, `-Kick`, the
  stall cut, the machine-wide health); wave 27 - R13 (the host is a parameter: one plugin for
  every host, `CODEX_CONSULT_COORDINATOR`, the child environment without host markers,
  `-Explain`, `-BriefPrefix`) and R19 (the `coordinate` skill, the worker tiers); wave 28 - R17
  (telemetry and complaints to the maintainer's intake, on by default: "Telemetry (on by
  default)").
- Help wanted: runs on macOS (the `-Detach` background there is `/bin/sh -c 'exec nohup ...'`,
  not exercised by the Windows-only harnesses); a bash port; a `UserPromptSubmit` hook injector;
  the reverse direction (a Codex-side tool that consults Claude); an MCP server variant.

---

## Tests

`tests/run-all.ps1` runs the twenty harnesses one at a time against a FAKE `codex` shim (and
a FAKE `agy` for `harness-engines` and `harness-panel`, a FAKE `muse` for `harness-muse`): no
real `codex`, `agy` or `muse`, no quota spent, no real credential read (`harness-muse` gives
every child a scratch home with a fake `auth.json`, a scratch `LOCALAPPDATA` and a PATH
without a muse launcher, and refuses to run when a real muse would still resolve), your own `~/.codex/config.toml` never changed (`harness-0.3`
points `CODEX_HOME` at scratch directories and compares your config's hash before and
after; every harness sets `CODEX_CONSULT_ROSTER` to a scratch file or `none`, and (wave 26b)
`CODEX_CONSULT_HEALTH` to `none` - `harness-fixes26b` to scratch files - so the machine-wide
health file `~/.codex/codex-consult-health.json` is never touched). The fake
codex is a `.cmd` shim, so the suite needs Windows and `git` on PATH. Never run two
harnesses in parallel; the recovery checks would see each other's fake codex.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
pwsh -NoProfile -File tests/run-all.ps1 -Only harness-roster,harness-0.3
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1 -ScriptsDir <an installed plugin>/scripts
```

(0.5.0, T4) `-ScriptsDir <dir>` - else the environment variable `CODEX_CONSULT_SCRIPTS_DIR`, else
the checkout's `plugins/codex-consult/scripts` - names the scripts under test; `run-all.ps1`
passes it to every harness (each takes it too) and names it in its summary line
(`run-all: 18 harness(es), 0 failed; scripts: <dir>`). (Wave 28, wave 27c) Every harness and `run-all.ps1` set
`CODEX_CONSULT_TELEMETRY=off` (the intake pointed at a closed loopback port - only `harness-telemetry` talks to
a local `HttpListener`) and `CODEX_CONSULT_TEST_MODE=1` (the bridge honours its test hooks only then).

(Wave 29) `harness-claude` drives the `claude` engine against a FAKE `claude` (`tests/fake-claude.cmd` + `tests/fake-claude.ps1`, steered by `FAKE_CLAUDE_*`); it is registered in `run-all.ps1` as the twentieth harness. Its sections: UNIT ROSTER DRYRUN ENGINEEXE RUN BILLING PREFLIGHT FAIL TREE RESUME FORK REPAIR PANEL LISTING TOOLSET TIMEOUT STALL HYGIENE ENDPOINT ACCEPT GUARD ((wave 29b) ENDPOINT the endpoint mode, ACCEPT the acceptance decisions E12-E16: a killed turn's init judged, the assistant messages as the model proof, a missing init field, a rejecting rate-limit event beside a successful result, the plan in the machine-wide running rows - 85 checks). GUARD: the harness never starts the real `claude` - a scratch USERPROFILE / HOME / LOCALAPPDATA, `CODEX_CONSULT_CLAUDE_EXE` pinned to the fake, every PATH directory holding a real launcher stripped, and a child without an argv-log line fails the case.

Assertions per harness (Windows PowerShell 5.1, 2026-09-27, 0.5.0 wave 26): `harness-0.3` 229,
`harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 72,
`harness-panel` 54 (0.4.x wave 21, the parallel panel; wave 26: the seat order), `harness-pending`
26, `harness-fixes` 45, `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121 (wave 24:
the timeouts, the continuation, the salvage, `-Range`, the one availability verdict; wave 24b/24c:
the continuation's gates, the main turn's guarded start, the complete resume command, the tree
check by content, the burst 429), `harness-detach` 51 (wave 25: `-Detach`, `-Status`, `-Wait`, the
status file, the log, the budget, a died background, T4; wave 26: the carry-overs),
`harness-companions` 42 (wave 26: size, routing, `-Require`, roles, the scoreboard; wave 26b: the
golden sequences of the length-prefixed seed, from `tests/reference-draw.py`), (wave 26b, 0.5.0,
2026-09-28) `harness-fixes26b` 39 (the wave 26 acceptance's decisions: role-file containment, the
reduced size, the delimiters, the role matching, the reserve, the rating join, UNIQ,
`timeout_sec`, the stall cut, `-Kick`, the salvage of any failed run, `context_tokens`, the
machine-wide health file) and `harness-muse` 74 (wave 26b: the write-disabled tree check);
(2026-09-29, waves 26c, 27 and 27b; Windows PowerShell 5.1 and PowerShell 7.6.6, the same counts)
`harness-fixes26b` 51 (+12: the kick acknowledgement, the health lock and the stored `until`, the
stall cut outside tool calls, a legacy rating's empty fields, the size raised by required
reviewers), `harness-detach` 51 (wave 27b: SINGLE holds its fake reviewer until released) and
`harness-host` 50 (new, wave 27: the root sentence and the wording, the coordinator's identity and
warning, the child environment without host markers, `-Explain`, the hook's pointer, the brief
prefix, the `coordinate` skill, the agent files, the README's hosts; wave 27b: the completed scrub
list, the host hint `zcode`, the Z Code and Kimi Code sections and the documented marker lists,
the idle watchdog); every other harness as above, `harness-fixes` 43 + 2 (the two F04-10 cases
fail while a real `codex.exe` runs on the machine). `harness-0.3`, `harness-roster`,
`harness-format`, `harness-engines`, `harness-muse`, `harness-panel`, `harness-visibility`,
`harness-detach`, `harness-companions`, `harness-fixes26b` and `harness-host` also run under pwsh
(2026-09-29: all fifteen ran under 7.6.6). (2026-09-29, waves 27c and 28 - the final `tests/run-all.ps1` runs on Windows PowerShell 5.1
and PowerShell 7.6.6, the same counts on both, `17 harness(es), 0 failed`) `harness-0.3` 229, `harness-roster` 119,
`harness-format` 37, `harness-engines` 97, `harness-muse` 74, `harness-panel` 54, `harness-pending` 26, `harness-fixes`
45 (the two F04-10 cases passed), `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121, `harness-detach` 51,
`harness-companions` 42, `harness-fixes26b` 51, `harness-host` 52 (+2: the templates grep of D22, the values no longer
refused), `harness-telemetry` 55 (new, wave 28), `harness-fixes27c` 36 (new, wave 27c). (2026-09-29, wave 27d -
documentation only; `harness-host` alone on Windows PowerShell 5.1 and PowerShell 7.6.6) `harness-host` 58 (+6: the waiting
rule's revision 5 in the skill and the README section "Waiting: keep the prompt cache or compact", every number recomputed
from the formula; the Qwen Code, OpenCode and Muse Code sections and rows). (2026-09-30, wave 28b - the runs as they
were, corrected in wave 28c (F43-7): `tests/run-all.ps1` on Windows PowerShell 5.1 ended `18 harness(es), 1 failed` -
`harness-detach` SINGLE counted three foreground lines, the test-mode line is a fourth: the check was updated and
`harness-detach` run ALONE on both hosts, 51 passed; the full suite was not run again on 5.1 -, on 7.6.6
`18 harness(es), 0 failed`; the counts are those of the 7.6.6 suite) `harness-0.3` 229,
`harness-roster` 119, `harness-format` 37, `harness-engines` 97, `harness-muse` 74, `harness-panel` 54, `harness-pending`
26, `harness-fixes` 45, `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 121, `harness-detach` 51,
`harness-companions` 42, `harness-fixes26b` 51, `harness-host` 62 (+4: PATHHINT, HOSTDOCS), `harness-telemetry` 79 (+24:
the vendor table, the deadline and the lock, the sender's environment, the salt, the busy spool, the exact complaint, the
intake's answers, -Forget), `harness-fixes27c` 36, `harness-fixes28b` 20 (new, wave 28b). (2026-09-30, wave 28c - every
new and changed harness first alone on both hosts, then `tests/run-all.ps1` on Windows PowerShell 5.1 and on PowerShell
7.6.6 for the final code, each `19 harness(es), 0 failed`, the same counts on both) as wave 28b, and `harness-host` 65
(+3: TESTLINE, the rule's revision 6), `harness-telemetry` 92 (+13: the closed model list, -Forget's order and question,
the telemetry lock and the forgetting marker, the owner-only takeover and the token, the deadline over the local steps,
the proxy and trust variables, the 1 s append and the retry after the write lock), `harness-fixes28c` 15 (new, wave 28c).
(2026-09-30, wave 28d - `harness-fixes28d`, `harness-telemetry` and `harness-fixes28c` first alone on both hosts, then
`tests/run-all.ps1` for the final code: Windows PowerShell 5.1 `20 harness(es), 0 failed`; PowerShell 7.6.6 `20 harness(es), 1 failed` - `harness-fixes26b` GUARD only,
environmental: the operator's Codex desktop app rewrote `~/.codex/config.toml` at 20:33 while that harness ran)
as wave 28c, and `harness-telemetry` 92 (cases changed, none added: a forgetting marker of a LIVING owner, an ownerless
flush lock held while young, the held lock released by deleting it, `.last`'s two new keys), `harness-fixes28d` 40 (new,
wave 28d). (2026-10-06, R24 - the bridge's half: `harness-telemetry` 103 (+11: RATE, the `rating` event of
`codex-findings.ps1 -Rate`, and its README check) alone on Windows PowerShell 5.1, its UNIT, RATE and DOCS sections
also on PowerShell 7.6.6; `harness-roster` and `harness-companions`, which rate with telemetry off, unchanged. Then
the backfill: `harness-telemetry` 112 (+9: BACKFILL - `codex-telemetry.ps1 -BackfillRatings`, the mark's
`telemetry_sent` - and its README check) on Windows PowerShell 5.1, UNIT, RATE, BACKFILL and DOCS also on PowerShell
7.6.6; `harness-roster` 119, `harness-companions` 42, `harness-panel` 54 unchanged.)
Many cases wait on real timeouts and time a fake
reviewer: on a loaded machine (another heavy application or build, a disk that runs full) the
timing cases of `harness-panel` (RUN, GUARD), `harness-detach` (PANEL) and `harness-visibility`
(CONT) can fail spuriously - re-run that section alone. A full run takes about one and a half to
two hours (2026-09-29). Each harness ends with `<harness>…: N failure(s).`; `run-all.ps1`
prints one summary line per harness, exits `1` when anything failed, and keeps full logs
in `$env:TEMP\codex-consult-tests\run-all-<timestamp>\`. `tests/` is not part of the
installed plugin; `tests/README.md` lists what each harness covers.

---

## Contributing

Keep the scripts dependency-free, ASCII, and dual-shell (5.1 and 7). If you change the
`codex` invocation, re-check the four rules under "How it works". Include the `-DryRun`
output for any argv change, say which shells and platforms you exercised, and paste the
`tests/run-all.ps1` summary lines into the PR.

## License

MIT — see [LICENSE](LICENSE). Author: xelth.com
