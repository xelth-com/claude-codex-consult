# claude-codex-consult (CCC)

A Claude Code plugin (`codex-consult`, version 0.4.0). This README is written for the AI
coding agent that installs, wires and uses the plugin; humans can follow the same steps.
The bridge itself is host-neutral: the scripts run from any coordinator (a Codex CLI
session, Cursor, a shell), and a reviewer reached through a provider table needs no ChatGPT
plan - only the Claude Code packaging (manifest, hooks, evals, skill paths) is Claude's;
making that packaging a parameter is ROADMAP R13.

## For the agent installing this

- **What it is:** a dependency-free PowerShell bridge that runs `codex exec` for a review (or, per roster entry, another CLI "engine": Google's Antigravity CLI `agy` for the Gemini models, Meta's Muse Code CLI `muse` for the Muse Code subscription - see "Engines"), records the consultation as files (brief, verbatim reply, JSON ledger), and manages reviewer identity, availability, a roster/panel and structured findings.
- **Prerequisites.** Check each with the command; do not assume:
  - [ ] Windows PowerShell 5.1 or PowerShell 7: `powershell -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` or `pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'` → `5.1.…` or `7.…`
  - [ ] git: `git --version` → `git version …`
  - [ ] Codex CLI on PATH: `codex --version` → `codex-cli 0.148` or newer (tested with `codex-cli 0.155.1`)
  - [ ] a reviewer: `codex login status` → `Logged in using ChatGPT`, **or** a `[model_providers.<name>]` table whose `env_key` variable the USER has set. Never create, print or paste an API key.
  - [ ] optional, Gemini through the `agy` engine: `agy models` → lines `<model id><TAB><name>` (the USER installed Google's Antigravity CLI and signed in by running `agy` once; you never handle the login). See "Engines".
  - [ ] optional, Meta Muse through the `muse` engine: the USER installed Muse Code and signed in with `muse login` with the user variable `TBH_CREDENTIAL_BACKEND=file` set first (required on every OS: the bridge launches muse only on an oauth sign-in it can read from `~/.config/muse/auth.json`); `codex-providers.ps1` then shows the roster's muse row with `ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth)`. `META_API_KEY` and `MODEL_API_KEY` must NOT be set (a muse run is refused then: it would bill per token). You never read `auth.json` or handle the login. See "Engines (wave 23)".
- **Install** (at the Claude Code prompt): `/plugin marketplace add xelth-com/claude-codex-consult`, then `/plugin install codex-consult@claude-codex-consult`.
- **Verify:** `codex-providers.ps1` → at least one row `available`; then a `-DryRun` consultation → first line `DRY RUN - nothing was executed and no file was written.` and a line `preflight   : available (…)`. Exact commands: "Setup on a new machine", steps 0 and 9.
- **First consultation:** `/codex-consult:consult-codex <task-id> <question>`, or the command under "Usage".
- **More reviewers** (z.ai GLM, Xiaomi MiMo, any Responses-API provider; Gemini through the `agy` engine; Meta Muse through the `muse` engine): follow the `setup-providers` skill.

---

## Setup on a new machine

Run each step, compare with the expected output, and stop and tell the user at the first
mismatch you cannot fix without them. `<codex home>` is `$CODEX_HOME` when set, else
`~/.codex`. Commands are shown for Windows PowerShell
(`powershell -NoProfile -ExecutionPolicy Bypass -File …`); on macOS/Linux run
`pwsh -NoProfile -File …` with the same arguments.

**0. Locate the scripts.** Inside this plugin's skills, `${CLAUDE_PLUGIN_ROOT}` is the
plugin directory. From a plain shell:

```powershell
$P = (Get-ChildItem "$HOME/.claude/plugins/cache/claude-codex-consult/codex-consult" -Directory |
      Sort-Object { [version]$_.Name } | Select-Object -Last 1).FullName
Test-Path "$P/scripts/codex-consult.ps1"        # expect: True
```

Bash: `P=$(ls -d ~/.claude/plugins/cache/claude-codex-consult/codex-consult/*/ | sort -V | tail -1)`.

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
- Then ask the USER to set the variable in their own terminal and restart Claude Code (a
  running Claude Code does not see a variable set after it started): Windows
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

A `weighty` entry joins a `-Panel` run only on the weighty purposes. `"auth": "none"` is
only for a table with neither `env_key` nor a bearer token (a local endpoint); it does
nothing for a table that names an `env_key`. Every field and rule: "Reviewer roster and
panel". An invalid roster refuses **every** run, dry runs included, so validate it at
once: `codex-providers.ps1` must not exit `1`. To use another file, the user sets
`CODEX_CONSULT_ROSTER=<path>` (the file must exist); `CODEX_CONSULT_ROSTER=none` switches
the roster off.

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
set, or Claude Code was not restarted). Health (the `LAST FAILURE` column, usage limits)
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
| set `<NAME>_API_KEY` (`setx` or the shell profile), then restart Claude Code | set `model_catalog_json` or `profile` at the top level of `config.toml` |
| confirm the plan's region, models and peak schedule | invent a base URL, a model name or a peak schedule |
| agree before the first live consultation | pass `-SkipPreflight` to get past a real refusal; `fork`/`resume` a thread under another provider or model; delete `.consult.lock` |

---

## Components in this plugin

| Component | What it does |
|---|---|
| skill `consult-codex` (`/codex-consult:consult-codex <task-id> <ask>`) | the consultation process: when to consult, reconciling findings, the brief, the one command, verifying and recording findings, rating the consultation, the panel and the council rules |
| skill `setup-providers` (`/codex-consult:setup-providers [provider]`) | wiring reviewers on a machine: Codex login, `[model_providers.*]` tables with `env_key`, per-run catalogs, the `agy` engine (install, the user's sign-in, `agy models`, roster entries), the `muse` engine (install, `muse login` with the file credential backend, never an API key, the contributor vs standard model), the roster, peak windows, verification |
| hook `SessionStart` (`hooks/hooks.json` → `scripts/codex-consult-hook.ps1`) | at every session start (`startup`, `resume`) in a project where the plugin is enabled, adds ONE line to the agent's context (0.5.0, the line `codex-providers.ps1 -Short` prints): what is OUT, per roster entry, with the reset in local time and a rounded relative hint, then the count - `codex-consult: out - openai :: gpt-6-astra (until Sun 20:35, in 2d 10h), gemini :: * (until Sun 21:30, in 2d 11h); 9 of 11 reviewers available`, or `codex-consult: all 11 reviewers available`. Every entry is judged with the roster walk's own verdict (credentials, the launch invariant, the endpoint health of THIS repository's ledgers: an auth failure, a usage limit with a reset ahead, one without a reset for 60 minutes after it was hit); the entries of one endpoint group that share the state collapse to `<label> :: *`; nothing is cut. An agy entry's sign-in is not checked here (no network call): `not checked - gemini :: * (sign-in not checked); 7 of 11 reviewers available, 2 out, 2 not checked` - unless THIS repository's ledgers hold a usable agy reply from the last 60 minutes; a muse entry's local check and billing guard run (`meta :: <model> (refused: META_API_KEY is set)`). Without a roster: the providers (`... (no reviewer roster)`). `codex-consult: codex CLI not found on PATH - follow the setup-providers skill ...` when Codex is missing; `codex-consult: reviewer check failed - <why>` for an unusable roster or config. It runs `codex-providers.ps1 -Short -Json -NoNetwork`: nothing written, exit code always 0, about one second (`codex login status`), timeout 30 s; `pwsh` when present, else `powershell`. Disable it with the plugin (`/plugin disable codex-consult`) — hooks have no per-plugin switch |
| evals `evals/` (`claude plugin eval <plugin dir> --ablation none --allow-tools Bash` — the `--allow-tools Bash` operator grant is REQUIRED for the two cases that run the bridge; they are silently downgraded without it) | the install test: two cases a fresh agent must pass with only this plugin loaded — `dry-run-consultation` (reach the bridge through the `consult-codex` skill, run `-DryRun` for task `eval-smoke`, report the fixed first line, the preflight and reviewer lines, write nothing) and `providers-listing` (use `codex-providers.ps1`, one verdict per provider, no invented verdict). Graders: `tool_used`, `regex` on the trace, `file_exists: false`, an `llm` rubric. A machine with no usable reviewer still passes when reported honestly. The third case `command-plan` (tag `readonly`) needs no shell grant and runs everywhere: the agent must produce the exact dry-run command and the files a real run writes, from the skill, without executing anything. Shell-granted cases need a sandbox backend: Linux/macOS have one; on Windows the eval runner refuses to run a shell tool unconfined (`sandbox required but unavailable`), so there run `--case command-plan` only. Results land in `evals/results/` (ignored by git) |

Per-provider alias skills a user may keep in `~/.claude/skills/` (say, one that maps "ask
GLM" to `-Provider ZAI -Model glm-5.3`) are optional personal conventions, not part of
the plugin; nothing here needs or installs them.

Per-provider alias skills a user may keep in `~/.claude/skills/` (say, one that maps "ask
GLM" to `-Provider ZAI -Model glm-5.3`) are optional personal conventions, not part of
the plugin; nothing here needs or installs them.

---

## Usage

Three steps per consultation: write a brief, run one command, read and record. The
`consult-codex` skill is the procedure; this section and the ones below are the reference.
`$P` is the plugin directory (setup step 0); inside the plugin's skills the same commands
use `${CLAUDE_PLUGIN_ROOT}`. On macOS/Linux replace `powershell -NoProfile
-ExecutionPolicy Bypass -File` with `pwsh -NoProfile -File`.

**1. Write the brief** to `.collab/<task>/handoffs/<NN>-claude-<slug>.md`. `<NN>` is the next
free two-digit prefix; you and the bridge share one sequence, so the directory reads as a
conversation. Start from `templates/brief-framing.md` (framing, decision, stuck) or
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
`.consult.write.lock`, `.consult.pending.json`, a panel member's `.consult.pending-<NN>.json`). A
fabricated example of the layout is in `examples/`.

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
members inherit the resolved value.

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
it), when the run changed files (an engine's tree check), when the killed turn's own stream names
a quota or auth failure, or with `-ContinueSec 0`; muse's billing guard re-reads `auth.json` right
before it (a refusal: `failed: refused before launch: ...`). Never more than one per
consultation. A `-Panel` member continues inside its own process; its kill guard grows by
`-ContinueSec`.

**The partial reply.** When a turn was killed on its timeout - the main turn without a usable
continuation, the continuation, a denial retry, a format repair - the bridge writes
`handoffs/<NN>-<engine>-<slug>.partial.md`: the reply's header, then per turn (`## Turn 1 - the
main turn - killed at 902.3 s of 900 s`, `## Turn 2 - the timeout continuation - ...`) every agent
message and reasoning text of its event stream in order and its tool calls (the command line of a
shell command), then the footer ``killed at <t> s of <T> s; thread <id> - continue with `-Task
<task> -Mode resume -Thread <id> -Purpose <p> -Prompt "finish your review"` ``. The ledger names it
(`partial_reply`), the handoff header too (`Partial reply:`); `bridge_outcome` stays `failed:
timeout after <T> s (process tree killed)` - the run did not produce a usable reply. The summary
prints the file and the exact command:

```
codex-consult: failed: timeout after 900 s (process tree killed) (wall 902.3 s)
continued  : failed: timeout after 900 s (process tree killed) (in 901.0 s) - thread <id>
partial    : <repo>\.collab\my-task\handoffs\05-codex-review.partial.md (killed at 902.3 s of 900 s (the main turn), 901 s of 900 s (the timeout continuation); thread <id> - continue with `...`)
resume     : powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin>\scripts\codex-consult.ps1" -Task my-task -Mode resume -Thread <id> -Purpose diff-review -Prompt "finish your review"
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
is refused before anything starts. A `-Panel` measures it once for all members.

**Rating a failed consultation** (`codex-findings.ps1 -Rate`): rate `no` only when the failure
was the reviewer's (a refusal, an invented finding, prose it could not convert); skip the rating
when the bridge's timeout or a plan limit killed it - resume it instead.

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
  "preflight": "ok: env ZAI_API_KEY set",
  "preflight_warning": "",
  "roster": null,
  "panel": null,
  "parent_thread": "01a0c839-48ba-7182-8d15-fdc13dd17193",
  "thread": "01a0c86e-5193-7d70-a644-63a5c3f224b3",
  "thread_source": "events",
  "thread_candidate": "",
  "mode": "fork",
  "command": "codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort=\"max\" -c model_provider=\"ZAI\" -o <temp> --output-schema <schema> fork 01a0c839-… -",
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
  "base_commit": "4e9cc4f0…",
  "reviewed_revision": "4e9cc4f + uncommitted",
  "tree_sha256": "9c2a…",
  "tree_sha256_after": "9c2a…",
  "tree_changed_during_review": false,
  "changed_files": 3,
  "brief_sha256": "7b31…",
  "brief_sha256_after": "7b31…",
  "brief_changed_during_review": false,
  "fingerprint_note": "collab dir '.collab' excluded (2 entries); ignored files excluded; untracked file modes not recorded; submodules not recursed",
  "artifacts": [],
  "artifacts_changed_during_review": false,
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
| `consult_id` | a fresh guid per run; also the prompt's last line `Consultation id: <guid>` and the key that verifies a rollout-file thread id |
| `reviewer.provider` / `reviewer.provider_source` | the provider that answered; how it was decided: `-Provider`, `config`, `codex default`, `roster`, `-Thread` or `unknown` |
| `reviewer.model` / `reviewer.model_source` | the model that answered (`unknown` when unresolvable); `-Model`, `config`, `roster`, `-Thread` or `unknown` |
| `reviewer.engine` | (0.4.0) the CLI that carried the run: `codex`, `agy` or (wave 23) `muse` (see "Engines"); an entry without it is `codex`. A thread never mixes engines |
| `reviewer.harness` | `codex-cli <version>` (`agy-cli <version>` or `agy-cli (version unknown)` for agy; `muse-cli <version>` for muse, from `.muse-version` next to the launcher, else `muse --version`); audit only, never compared |
| `reviewer.provider_fingerprint` / `reviewer.provider_config` | SHA-256 of the canonical endpoint (`""` when identity is unresolved); `{base_url, wire_api}` of the table (no `wire_api` key when the table has none), or `{builtin: "openai"}`; for the agy engine SHA-256 of `cc-engine-v1\|agy` and `{engine, launcher}`; for the muse engine SHA-256 of `cc-engine-v1\|muse` and `{engine, launcher, credential_mechanism}` (the sign-in's `providers.meta.mechanism`, e.g. `oauth`; `null` when it cannot be read) |
| `reviewer.identity_note` | why identity is unresolved, or how it was derived (e.g. a user-defined `[model_providers.openai]` table); `""` otherwise |
| `lineage` | `<provider> :: <model>`, display only; matching never compares this string |
| `preflight` | `ok: <credential detail>` or `skipped` (`-SkipPreflight`); any other verdict refuses the run |
| `preflight_warning` | a recent usage limit that did not refuse the run, else `""` |
| `roster` | `null` without a roster; else `{path, position, skipped: [{provider, model, engine, reason}], applied: []}`, `applied` naming what the roster entry supplied (`engine`, `model`, `codex_config`) |
| `panel` | `null` outside a panel; else `{id, position, of, members: [{provider, model, state: "run"\|"skipped", reason}], concurrency, limits}` - `concurrency` (0.4.x wave 21) the most members the panel's plan let run at once, `limits` `{"<provider label>": n}` the members of that label's endpoint at a time (see "The panel") |
| `parent_thread` / `thread` | the thread forked or resumed (`""` for `new`); the resulting thread (`""` when not verified) |
| `thread_source` | `events`, `rollout (verified by consultation id)` or `unknown` |
| `thread_candidate` | an unverified rollout uuid (agy: a conversation id the run could not verify - a failed resume's new conversation, the init id of a run without a result) kept for diagnosis only; never a parent |
| `mode` / `command` | `new`, `fork` or `resume`; the full argv as one string (prompt on stdin) |
| `brief` / `prompt_chars` | the brief path (`""` without one); the prompt length |
| `range` | (0.5.0) `null` without `-Range`, else `{spec, files, insertions, deletions, lines}` of `git diff --shortstat <spec>` |
| `reply` / `reply_json` / `events` | handoff paths relative to the task directory (`reply_json` is `""` for plain-text runs) |
| `partial_reply` | (0.5.0) `""`, or `handoffs/<NN>-<engine>-<slug>.partial.md` when a turn was killed on its timeout (the salvage; "Timeouts, the continuation and the partial reply") |
| `model` / `effort` | kept for 0.2 readers and `-Stats`: the resolved model; `effort` equals `effort_sent` |
| `effort_requested` / `effort_sent` / `effort_mapping` / `effort_caps` / `effort_confirmed` | the preset, `-Effort` or `-NativeEffort` value; the value put into argv (`null` for agy: the tier is part of the model id); `openai`, `zai-v1`, `mimo-v1`, `model-tier` (agy), `muse-v1` (muse) or `native`; the capability-table version (`caps-v1`); always `null` (Codex does not report the effort it used) |
| `max_words` / `sandbox` | the resolved word cap; `read-only` or `workspace-write` (agy: `read-only (requested; enforced by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; agy --sandbox restricts the terminal only)`; muse: `read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads)`) |
| `timeout_sec` / `timeout_source` / `continue_sec` | (0.5.0) the main turn's timeout; `purpose` (the purpose's default) or `explicit` (`-TimeoutSec`); the timeout continuation's budget (`0` = off) |
| `extra_config` / `extra_config_source` | the `-CodexConfig` or roster `codex_config` items as sent (expanded); `""` (none), `-CodexConfig` or `roster` |
| `peak` / `peak_schedule` / `peak_source` / `peak_evaluated_at` | `true`, `false` or `null` (no schedule) at launch; the schedule; `env`, `env (CODEX_CONSULT_NOW)` or `none`; when that decisive check ran |
| `structured` / `schema` | whether a valid structured reply was ingested; `consult-reply v1`, or `""` for `-Raw` |
| `schema_transport` / `schema_transport_source` | `output-schema`, `prompt-only` or `native` (agy: `--json-schema`; muse: `--output-schema`); `caps-v1` or `-SchemaTransport` (`""` for plain-text runs) |
| `validation_error` | `""`, or every validation message joined with `; `, plus a format-repair note |
| `format_retry` | `null` (no repair attempted, or off), else `{attempted, reason, succeeded, thread, wall_seconds, usage, drift, original, events, schema_transport}` - `events` (0.4.0) the repair turn's event stream, handoffs-relative, when one is kept (agy: `handoffs/NN-agy-<slug>.repair.events.jsonl`; muse: `handoffs/NN-muse-<slug>.repair.events.jsonl`), else `null` (codex: its repair stream is a temp file); `schema_transport` (wave 23b) the repair turn's transport: codex `prompt-only` (its repair never passes `--output-schema`), an engine the main turn's - `native`, or `prompt-only` with no schema flag and the schema in the repair prompt |
| `denial_retry` | (0.4.0, agy; always `null` for muse, which has no denial retry) `null` (not attempted), else `{attempted, reason, succeeded, thread, wall_seconds, usage, events}`: the one extra turn after a run that produced nothing because a tool was auto-denied (see "Engines"); `events` = that turn's event stream (`handoffs/NN-agy-<slug>.denial-retry.events.jsonl`, `null` when no turn ran) |
| `timeout_continue` | (0.5.0) `null` unless the main turn was killed on its timeout; else `{thread, wall_seconds, outcome, events, usage}` of the ONE continuation turn - `outcome` `usable reply`, `failed: <why>` or `not attempted: <why>` (then `wall_seconds` 0, `events` and `usage` `null`) |
| `base_commit` … `fingerprint_note` | revision binding: see "Binding a review to a revision" |
| `artifacts` / `artifacts_changed_during_review` | `[{path, sha256, sha256_after}]` per `-Artifact`; whether any changed during the run |
| `bridge_outcome` | `usable reply`, (0.5.0) `usable reply (after a timeout continuation)` or `failed: <why>`: only whether the bridge worked |
| `provider_failure` | `null` on success, else `{class, code, message, when, retry_after}` (see "Preflight and endpoint health") |
| `warnings` | (0.4.0) notices of the run - a `-Provider` label that names several roster entries (any engine), agy's denial notice and its `warning:` stderr lines that came with a usable reply; `[]` when none |
| `verdict` / `verdict_reason` | `ACCEPT`, `HOLD`, `REJECT`, `ADVISE`, or `""` (unavailable or invalid); one sentence |
| `findings` / `finding_ids` | severity counts of the new findings; their ids |
| `prior_findings` | the reviewer's reports on earlier ids: `{id, status}` with `fixed`, `still-open`, `not-checked` or `unknown-id` |
| `unchecked_prior_blockers` | open prior blockers the reviewer did not check while answering `ACCEPT` |
| `usage` / `wall_seconds` | token counts from the event stream (agy: `cache_read_tokens` -> `cached_input_tokens`, `thinking_tokens` -> `reasoning_output_tokens`, plus `total_tokens`; muse: `null` - its records carry no usage); wall time |
| `engine_run` | (wave 23) `null` for codex; for an engine `{turns, max_model_steps, msp_schema_version}`: the engine turns started (the main turn, a denial retry, a format repair - each muse turn spends one Muse Code subscription prompt), `-MaxModelSteps` as sent (`null` when not), the MSP `schema_version` of a muse stream (`null` for agy); right after `usage` |
| `finished_at` | (0.4.x wave 21) when the entry was committed (`when` is the reviewer's start). The endpoint health's "newest wins" orders by it (older entries: `when` + `wall_seconds`), ties by `n` - a panel's members finish in any order |
| `commit_wait_ms` | (0.4.x wave 21) how long the commit waited for the write lock because another commit of the task held it (`0`: it was free); the console says `write lock : waited N ms for another commit of this task` when it waited |

`bridge_outcome` and `verdict` are separate on purpose: a delivered `HOLD` is a success of
the bridge. Legacy entries: the pre-0.2.0 field `outcome` (now `bridge_outcome`) is left
as written and only its `thread` is read; entries written before 0.3.0 have no `reviewer`,
`lineage` or later fields, and that absence marks them as unknown provenance (see
"Reviewer identity and lineage"); a pre-wave-7 `lineage` in the slash form
(`ZAI/glm-5.3`) still matches, since matching compares `reviewer.provider` and
`reviewer.model`.

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
  `-Useful`.
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
  `{n, consult_id, lineage, provider, model, purpose, useful, note, when}`, copied from
  that ledger entry so the row survives pruning; rating `n` again replaces it. Rate
  **every** consultation, plain-prose ones included, or the telemetry only counts
  structured reviewers.
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
  is still running…`).
  A dead recorded pid is not proof of a dead tree (it is usually the launcher shim), so
  when every recorded pid is gone, and for a `launching` record, the bridge scans for a
  child of the dead bridge or of a dead recorded pid (Windows keeps an orphan's parent
  id), then for any codex-looking process (named `codex`, or with the launcher path or
  `@openai/codex` on its command line) started at or after the record's `started` time.
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
first, and accepts one only if it contains this run's `Consultation id:` line
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
| availability can be established (a resolved identity; `codex login status` runs and finishes) | `provider ZAI: availability could not be established (…); pass -SkipPreflight to launch anyway, or fix the check` |
| no `auth` failure on this ENDPOINT in the last 24 h (unless a later run there succeeded) | `provider ZAI is not usable: the last run on this endpoint was rejected as unauthenticated at <when> (<message>); if you rotated the credential, pass -SkipPreflight once` |
| no usage limit whose named reset time lies ahead | `provider ZAI is not usable: its usage limit (hit at <when>: <message>) lasts until <iso>; nothing was started (pass -SkipPreflight to launch anyway)` |

A usage limit with NO reset time hit within the last 60 minutes only warns on an explicit
`-Provider` run (console `WARNING:`, ledger `preflight_warning`); a roster walk skips it
(0.5.0: `usage limit hit <iso>, reset unknown; retry after <iso + 60 min>` - out for 60 minutes
after the limit was hit, the failure's own time; a later successful run on the endpoint clears
it), and the providers listing, `-Short` and the SessionStart line say the same. `-SkipPreflight` bypasses every refusal
above (ledger `preflight: "skipped"`; with a roster, the first entry is taken unchecked,
under `-Panel` every entry). Use it only for an endpoint that genuinely needs no
credential and has no roster entry saying so, or once, after the user rotated a
credential inside the 24-hour auth window. `-DryRun` only prints the verdict and never
refuses on it. The credential check sees only what is local (a variable set, a token in the
config, a login); it cannot see live quota. A credential's validity is learned only from a
failed run.

**Failure classes.** A failed run records `provider_failure = {class, code, message
(<= 200 chars), when, retry_after}` (and a `Provider failure:` header line). The class
comes from word-bounded keywords, tried in this order: `permission` (0.4.0: no output
produced/auto-denied/"permission that headless mode" - agy's F11 notice; also forced for
agy's tree-check failure), `capability` (not supported/unsupported/"does not
support"/feature_not_supported/json_schema/INVALID_ARGUMENT/invalid model
selection/"conflicts with --effort"), then a usage limit said in words (usage
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
position or `null`), `roster_selected`, `verdict` and (0.5.0) `health_source`. **`-Short`**
(0.5.0) prints ONE line over EVERY roster entry, each judged with the roster walk's verdict - the
SessionStart hook's line: `codex-consult: out - <provider> :: <model> (until <local time>, in
<rounded hint>), <label> :: * (...); <a> of <n> reviewers available` (the entries of one endpoint
group that share the state collapse to `<label> :: *`; a quota without a reset reads `limit hit
10:31, reset unknown; retry after 11:31, in 52m`; `..., <o> out, <c> not checked` when an entry was
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
| `reviewers[].auth` | optional `"none"`: the endpoint needs no credential, so a table with no `env_key` and no bearer token passes the check. No effect on a table that names an `env_key`, nor on `openai`/`requires_openai_auth` providers (always `codex login status`) |
| `reviewers[].panel` | `"always"` (default) or `"weighty"`: joins a `-Panel` run only on `framing`, `decision`, `core-contract`, `acceptance` and `stuck`, or under `-PanelAll` |
| `reviewers[].engine` | (0.4.0) `"codex"` (default), `"agy"` or (wave 23) `"muse"`: the CLI that carries it (see "Engines"). For `agy` and `muse`: `provider` is a free label, `model` is required, `codex_config` and `auth` are refused; one label names one engine across the roster |
| `parallel` | (0.4.x wave 21) optional top-level object `{"<provider label>": <n>}`: a `-Panel` runs the members of one endpoint one after another; n >= 1 lets n members of that label run at once (see "The panel"). Every key must be a label the roster uses, every value an integer >= 1 |

An unusable roster (an unknown key, `roster_version` other than 1, an empty or non-array
`reviewers`, the same `(provider, model)` twice, anything that does not parse) **refuses
every run, `-DryRun` included, naming the path**; an existing roster is never ignored.

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

**The panel.** `-Panel` sends the same brief to every available roster entry, each as a
complete, independent consultation: its own preflight, recovery record, parent thread (the
newest of its own lineage, or a new one; `-Mode new` starts fresh threads for all; an agy
member starts a new conversation), consultation id, reply file
`handoffs/<NN>-<engine>-<ReplyName>-<provider lowercased>.md` (`codex`, `agy` or `muse`) and
ledger entry (`panel`). A roster may mix engines; `-Panel -Engine agy` runs only the agy
entries. `-MaxModelSteps` travels in the panel spec to the muse members (refused when the
panel has none); a muse member whose billing guard refuses is skipped (`refused: ...`).
Every member sees the findings that were open when the panel started, not a later
member's answer; a later panel on the same task does see this panel's findings (members are
not blind across waves). `-PanelAll` includes `weighty` entries whatever the purpose.
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
- *The panel run owns the task.* It holds `.consult.lock` for the whole panel (its record
  names the panel), so a single run, another panel or `codex-findings.ps1 -Status`/`-Rate` on
  the task is refused until the panel ends. It judges every recovery record of the task
  first, gives every member its consult number n and handoff number NN up front in roster
  order - files and ledger entries keep the roster order whatever finishes first - and writes
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
Concurrency: at once - endpoint groups: openai x1, ZAI x1, mimo x1; -PanelConcurrency 0 (no cap)
  panel member 3 of 3 finished: mimo :: mimo-v2.6-pro - usable reply (231.4 s)
  ...
Panel 1a2b3c4d: 3 of 3 entries ran (wall clock 402.7 s; at once)
  openai :: gpt-5.1      ACCEPT  0 blocker, 0 major, 2 minor  prior: 3 fixed  398.2 s  handoffs/12-codex-acceptance-openai.md
  ...
```

Members run as child bridge processes through the internal `-PanelSpec` parameter; never
pass it yourself. There is no tooling yet for linking corroborating or contradicting
findings across members (ROADMAP R9): compare the replies yourself.

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
bridge therefore compares, before and after every agy turn, the working tree (the git
status manifest: tracked and untracked files), the WHOLE collab directory (every file under
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
artifacts): a change fails the run as class `permission` - `... - muse ran with
--disable-write --disable-shell (the check cannot tell who changed it)`. The boundary is
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

## Usefulness telemetry: codex-scoreboard.ps1

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$P/scripts/codex-scoreboard.ps1" [-Task <task>] [-Json] [-CollabDir <path>]
```

Answers "which reviewer has been useful on which kind of question" across every task of
the repository (or one task with `-Task`), from each `sessions.json` and `findings.json`
(including the `-Rate` marks). It writes nothing, takes no lock, makes no network call and
exits `0`; a store it cannot read is reported and left out. One row per
`(reviewer lineage, purpose)`, a `(total)` row per lineage and a grand `(all) (total)` row;
`unknown provenance` (pre-0.3.0 entries, findings without a ledger entry) sorts last.

| Column | Meaning |
|---|---|
| `REVIEWER` | `<provider> :: <model>`, or `unknown provenance` |
| `PURPOSE` | the `-Purpose`, `(none)`, or `(total)`/`(all) (total)` on summary rows |
| `CONSULTS` / `USABLE` / `PROSE` / `FAILED` | ledger entries; `bridge_outcome` = `usable reply`; usable but not a valid structured reply (`-Raw`, `chore`, invalid JSON); every other outcome |
| `RAISED` | findings raised by these consultations (joined by `source.consult`, as in `-Stats`) |
| `VERIFIED` / `REJECTED` / `WONTFIX` / `SUPERSEDED` / `OPEN` | current status of those findings; `OPEN` = `proposed` + `implemented` |
| `HIT%` | `verified / (verified + rejected)`, rounded; `-` when both are 0 |
| `A/H/R/D` | verdicts ACCEPT / HOLD / REJECT / ADVISE |
| `Y/P/N` | the `-Rate` marks yes / partly / no |
| `MEDIAN_S` | median `wall_seconds`; `-` when none |
| `TOKENS` | uncached input tokens / output tokens |

`-Json` returns the same rows with numeric fields (`hit_rate` and `median_wall_seconds` a
number or `null`) plus `kind`: `purpose`, `lineage` or `total`. Run it before choosing a
panel or a judge for a hard question.

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
| `-Mode new\|fork\|resume` | `fork` when a thread of this run's lineage is known, else `new` (agy, muse: `new`; `resume` with `-Thread`) | `fork` branches, `resume` appends; agy and muse have no `fork` |
| `-Thread <uuid>` | the newest verified thread of this lineage in this task | needs `fork`/`resume`; must belong to this lineage |
| `-Provider <name>` | first available roster entry; without a roster, the config's `model_provider`, else `openai` | case-sensitive table name; needs `-Model` unless its roster entry names one |
| `-Model <name>` | the roster entry's model, else the config's top-level `model` | the resolved model is always passed as `-m`; without `-Provider` it restricts the roster walk |
| `-Effort low\|medium\|high\|xhigh` | the purpose preset (`high` without one) | mapped through the endpoint's caps-v1 vocabulary |
| `-NativeEffort <token>` | — | sent verbatim; excludes `-Effort`; required where caps-v1 declares nothing |
| `-MaxWords <n>` | the purpose preset (`700` without one) | prose only |
| `-Sandbox read-only\|workspace-write` | `read-only` | `danger-full-access` is refused, with no flag to force it |
| `-TimeoutSec <n>` | the purpose's default (0.5.0: 600-3600 s, "Timeouts, the continuation and the partial reply") | the main turn's process TREE is killed past it; ledger `timeout_sec`, `timeout_source` |
| `-ContinueSec <n>` | the smaller of the timeout and 900 s | (0.5.0) the budget of the ONE continuation turn on the killed turn's thread; `0` = off; ledger `continue_sec`, `timeout_continue` |
| `-Range <from>..<to>` | — | (0.5.0) diff-review and acceptance only: `git diff --shortstat` once - the size in the prompt and the ledger (`range`), a warning above 1500 lines with a timeout below 2400 s; an unknown range is refused |
| `-ReplyName <slug>` | `reply` | names `handoffs/<NN>-codex-<slug>.*` (`<NN>-agy-<slug>.*`, `<NN>-muse-<slug>.*` for the engines) |
| `-Artifact <path>[,<path>…]` | — | one comma-separated string; hashes built artifacts into the ledger; a missing path refuses the run |
| `-Raw` | off | 0.1-style plain-text reply: no schema, no findings, no format repair |
| `-FormatRetry 0\|1` | `1` | one recorded repair turn for a substantive prose reply; any other value refuses |
| `-SchemaTransport output-schema\|prompt-only\|native` | caps-v1's declared transport | one run only; not with `-Raw`; `native` (agy's `--json-schema`, muse's `--output-schema`) only for agy and muse, `output-schema` only for codex |
| `-CodexConfig key=value[,…]` | — (roster `codex_config` when empty) | one comma-separated string; refused keys: "Per-run Codex overrides (-CodexConfig)" |
| `-OffPeakOnly` | off | refuses at peak and when no schedule is set |
| `-SkipPreflight` | off | bypasses every preflight refusal; ledger `preflight: "skipped"` |
| `-Panel` / `-PanelAll` | off | every available roster entry, in parallel across endpoints (one after another within one); needs a roster; not with `-Provider`/`-Thread`/`-Mode resume` |
| `-PanelConcurrency <n>` | `0` | `-Panel` only: at most n members at a time on top of the per-endpoint plan; `0` no cap, `1` strictly one after another |
| `-CollabDir <path>` | `.collab` | relative to the git repo root |
| `-CodexExe <path>` | the launcher on PATH | env override `CODEX_CONSULT_EXE` |
| `-Engine codex\|agy\|muse` | the roster entry's engine (the thread's with `-Thread`), else `codex` | "Engines"; with a roster and no `-Provider`/`-Thread` it restricts the walk (and `-Panel`) to that engine |
| `-EngineExe <path>` | the engine's launcher on PATH (muse: then `%LOCALAPPDATA%\Programs\muse\muse.cmd`) | the launcher of the SELECTED engine other than codex: `-Engine`'s, else the `-Provider`'s roster entry's, else the only such engine of the roster (several: refused - pass `-Engine`); env overrides `CODEX_CONSULT_AGY_EXE`, `CODEX_CONSULT_MUSE_EXE` |
| `-MaxModelSteps <n>` | not sent (the CLI's default) | muse only (wave 23): `--max-model-steps <n>`; refused with another engine; passed to a panel's muse members; ledger `engine_run.max_model_steps` |
| `-DenialRetry 0\|1` | `1` | agy: one more turn on the same conversation after a run that produced nothing because a tool was auto-denied; ledger `denial_retry` (muse has none) |
| `-DryRun` | off | prints the plan (argv, prompt, paths, preflight, roster pick, ledger entry); calls nothing, writes nothing |

Environment variables:

| Variable | Set by | Effect |
|---|---|---|
| `CODEX_HOME` | user | Codex home: `config.toml`, `sessions/` (rollout files), the default roster; default `~/.codex` |
| a table's `env_key` (e.g. `ZAI_API_KEY`) | the user only | the provider credential; the bridge only checks that it is set |
| `OPENAI_BASE_URL` | user | folded into the built-in `openai` identity (drift when it changes) |
| `CODEX_CONSULT_ROSTER` | user | roster file path (must exist), or `none` |
| `CODEX_CONSULT_PEAK_<PROVIDER>`, `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT` | user | peak windows |
| `CODEX_CONSULT_EXE` | user | codex launcher path |
| `CODEX_CONSULT_AGY_EXE` | user | agy launcher path (the `agy` engine) |
| `CODEX_CONSULT_MUSE_EXE` | user | muse launcher path (the `muse` engine) |
| `TBH_CREDENTIAL_BACKEND` | the user (Muse Code's own variable) | `file` keeps the Muse sign-in in `~/.config/muse/auth.json`, which the bridge can read; required (wave 23b: without a readable oauth sign-in no muse run is launched, `-SkipPreflight` included); passed to muse unchanged |
| `META_API_KEY`, `MODEL_API_KEY` | nobody, for the bridge | must NOT be set: a muse run is refused while either is (it would bill per token instead of the subscription) |
| `CODEX_CONSULT_NOW`, `CODEX_CONSULT_TEST_SURVIVORS` | tests only | test hooks; never set them in normal use |

---

## How it works

The bridge shells out to the documented `codex exec` CLI and makes no HTTP call to any
provider; a plan's credentials are only ever used by the Codex CLI itself. Four invocation
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
| Windows 11, Windows PowerShell 5.1, Codex CLI 0.155.1 | all seven harnesses (see "Tests"; last full run 2026-09-25, all green). Live: the 0.2.0 release review (`.collab/bridge-0.2-2026-09-23/`: framing `new`, acceptance `fork`, re-acceptance `resume`; three HOLDs with 11, 3 and 1 findings, then ACCEPT on 2026-09-24 after four fix waves; 12 findings verified, 2 superseded, 1 accepted limitation) and the 0.3.0 rounds below. The first live call hit the account's usage limit, which exercised the whole failure path (thread id still parsed from `thread.started`, the message lifted from the event stream, reply file and ledger entry written, non-zero exit) |
| PowerShell 7.6 on Windows 11 | `harness-0.3`, `harness-roster`, `harness-format` green. One pwsh-only defect fixed in 0.2.0: `ConvertFrom-Json` turns ISO-8601 strings into `[datetime]`, which broke the start-time comparison that recognises a live lock holder or codex child; those reads now normalise through a JSON-text helper |
| Linux (WSL Ubuntu 24.04, PowerShell 7.6, ext4), 2026-09-24 | with a bash fake `codex`: dry run, full structured run, lock contention through the advisory `flock` (second consultation and `-Status` refused, `-List` works, lock inode unchanged), timeout with the tree killed and no survivors, recovery of `launching` and `survivors` records through the `ps` scan, `chmod +x` changing the fingerprint, `$HOME/.codex` resolution, atomic `findings.json` replacement. Three Linux-only defects fixed: start times read by .NET can differ by under a second between readers (one-second tolerance off Windows); the holder's lock file could not be read back through a shared `FileStream` (read via `cat` off Windows); the timeout kill stopped children before the root (root first now). Known and left: an atomic replace resets the store's Unix permission bits; dates in messages render in an invariant format |
| macOS | **not exercised**; the Linux run covers the same pwsh code paths |
| 0.3.0 live (`.collab/bridge-0.3-2026-09-24/`) | design review and two acceptance rounds on the `openai` lineage (a `new` thread, then the first `resume` under the provenance rules); GLM-5.3 through `-Provider ZAI` (plain-Markdown reply kept with no verdict); MiMo through `-Provider mimo` with a per-run catalog (first attempt refused by the endpoint, `--output-schema` unsupported, lifted into the ledger; then, `prompt-only`, a bare-JSON HOLD ingested as F09-1..4 while reporting five earlier ids fixed); the first live panel (`-PanelAll`, real roster) found F15-1..4 through GLM-5.3 and MiMo after the weighty member was skipped on a known reset time; with the output contract buried after the schema the z.ai route answered in prose twice, and after the contract-first prompt it returned bare JSON (two cheap reviewers had independently diagnosed that cause). `codex-providers.ps1` on the real config: `openai` (`Logged in using ChatGPT`), `ZAI` and `mimo` (env keys) available. An earlier 0.2.0 smoke test of GLM-5.3 is in `.collab/multi-model-2026-09-23/` |

A report from a macOS run is the most useful contribution right now.

---

## Troubleshooting

A failed consultation is still a record: read the reply file's header (`Bridge outcome:`,
`Provider failure:`) and the ledger entry's `bridge_outcome` and `provider_failure`, e.g.
`failed: codex exit 1 - You've hit your usage limit. … try again at 12:21 PM.` For
anything not listed, rerun with `-DryRun` and compare the argv.

| Message or symptom | Do this |
|---|---|
| `provider X is not usable: env X_API_KEY not set` | ask the user to set the variable and restart Claude Code; check with `codex-providers.ps1 -Provider X` |
| `provider X: availability could not be established (…)` | run `codex login status` by hand; check for a top-level `profile` key or an unusable table (`codex-providers.ps1` names it) |
| `… rejected as unauthenticated at <when> …` | the user rotates or fixes the credential; then pass `-SkipPreflight` once (the 24-hour window cannot tell "fixed" from "still broken") |
| `… usage limit … lasts until <iso>` / `unavailable (usage limit until <iso>)` | wait, or consult another reviewer (`-Provider`, or let the roster walk pick the next entry) |
| `unavailable (usage limit hit <iso>, reset unknown; retry after <iso>)` | (0.5.0) the endpoint hit a limit and named no reset time: it counts as out for 60 minutes after the hit (a later successful run clears it); wait, or consult another reviewer |
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
- Help wanted: runs on macOS; a bash port; a `UserPromptSubmit` hook injector; the reverse
  direction (a Codex-side tool that consults Claude); an MCP server variant with
  background jobs.

---

## Tests

`tests/run-all.ps1` runs the eleven harnesses one at a time against a FAKE `codex` shim (and
a FAKE `agy` for `harness-engines` and `harness-panel`, a FAKE `muse` for `harness-muse`): no
real `codex`, `agy` or `muse`, no quota spent, no real credential read (`harness-muse` gives
every child a scratch home with a fake `auth.json`, a scratch `LOCALAPPDATA` and a PATH
without a muse launcher, and refuses to run when a real muse would still resolve), your own `~/.codex/config.toml` never changed (`harness-0.3`
points `CODEX_HOME` at scratch directories and compares your config's hash before and
after; every harness sets `CODEX_CONSULT_ROSTER` to a scratch file or `none`). The fake
codex is a `.cmd` shim, so the suite needs Windows and `git` on PATH. Never run two
harnesses in parallel; the recovery checks would see each other's fake codex.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
pwsh -NoProfile -File tests/run-all.ps1 -Only harness-roster,harness-0.3
```

Assertions per harness (Windows PowerShell 5.1, 2026-09-26, 0.5.0 wave 24): `harness-0.3` 227,
`harness-roster` 117, `harness-format` 37, `harness-engines` 97, `harness-muse` 72,
`harness-panel` 53 (0.4.x wave 21, the parallel panel), `harness-pending` 26, `harness-fixes`
45, `harness-lock2` 11, `harness-3b` 12, `harness-visibility` 76 (wave 24: the timeouts, the
continuation, the salvage, `-Range`, the one availability verdict). `harness-0.3`,
`harness-roster`, `harness-format`, `harness-engines`, `harness-muse`, `harness-panel` and
`harness-visibility` also run under pwsh. A full run takes about forty-five minutes. Each harness ends with `<harness>…: N failure(s).`; `run-all.ps1`
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
