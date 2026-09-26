---
name: setup-providers
description: Wire reviewers for the codex-consult bridge on a machine - verify the Codex CLI and its login, add a [model_providers.<name>] table for a third-party plan (z.ai GLM, Xiaomi MiMo or any Responses-API provider) with an env_key the user sets, supply per-run model catalogs, wire Gemini through the agy engine (Google's Antigravity CLI, signed in by the user), wire Meta Muse through the muse engine (Muse Code CLI, the subscription signed in by the user with muse login, never an API key), write the reviewer roster with panel weights, and verify with codex-providers.ps1 and a dry run. Use when a provider is missing or unavailable, on a new machine, or when the user asks to add a reviewer.
argument-hint: "[provider name, e.g. ZAI or mimo]"
allowed-tools: Bash(powershell:*), Bash(pwsh:*), Bash(codex:*), Bash(agy models), Bash(muse --version), Read, Write, Edit, Glob, Grep, WebFetch
disable-model-invocation: false
---

# Set up reviewers for codex-consult

This procedure wires one or more reviewers so `codex-consult.ps1` can reach them. A
reviewer goes through `codex exec` (the default engine) or, per roster entry, through
Google's Antigravity CLI `agy` (the `agy` engine, section 3b) or Meta's Muse Code CLI `muse`
(the `muse` engine, section 3f); the bridge itself never makes an HTTP call. Scripts:
`${CLAUDE_PLUGIN_ROOT}/scripts/`. Commands are shown for Windows PowerShell; on macOS/Linux
use `pwsh -NoProfile -File` in place of `powershell -NoProfile -ExecutionPolicy Bypass -File`.
`<codex home>` is `$CODEX_HOME` when set, else `~/.codex`.

## Invariants (never break these)

1. **Keys never go into files, output or chat.** You do not create, print, echo, log,
   commit or paste an API key, and you do not read one back from the environment. The
   user sets it; you only check that it is set, through `codex-providers.ps1`.
2. **One thread = one provider and model.** Never fork or resume a thread under another
   provider or model; the bridge refuses it, and you do not work around it.
3. **Preflight is fail-closed.** A refusal (`provider X is not usable: …`,
   `availability could not be established`) is information, not an obstacle. Never
   pass `-SkipPreflight` to get past a real refusal.
4. **The roster never replaces an available primary.** It orders the reviewers the user
   is willing to use; a fallback reviewer's reply is never presented as the primary's.
5. **Never invent** a base URL, a model name, a region or a peak schedule. Take them from
   the provider's official page or from the user.
6. **Ask before** installing software, editing `config.toml`, downloading a catalog, or
   running a first live consultation (it spends quota).

## 1. Verify the Codex CLI and the login

```
codex --version                 # expect: codex-cli 0.148 or newer (tested: codex-cli 0.155.1)
codex login status              # expect: Logged in using ChatGPT
```

Missing CLI: ask the user to install it (https://github.com/openai/codex). Not logged in:
ask the user to run `codex login` in their own terminal. The built-in `openai` provider
needs no table. Then check the config's top level without printing the file (it may hold
a token):

```powershell
$cfg = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "$HOME/.codex" }) 'config.toml'
Select-String -Path $cfg -Pattern '^\s*(model|model_provider|profile|model_catalog_json)\s*=', '^\s*\['
```

Want: a top-level `model = "…"` (without it, a run with no `-Model` and no roster entry
has an unresolved identity and can only start new threads); no top-level `profile` (it
disables `fork`/`resume` for every run); no top-level `model_catalog_json` (it replaces
Codex's own catalog and degrades unrelated models). Ask the user before changing any of
them.

## 2. Add a provider table

Read the provider's official Codex page (WebFetch is fine) and take `base_url` and
`wire_api` from it:

- z.ai GLM Coding Plan: https://docs.z.ai/devpack/tool/codex (page shows
  `base_url = "https://api.z.ai/api/v1"`, `wire_api = "responses"`)
- Xiaomi MiMo Token Plan: https://mimo.mi.com/docs/en-US/tokenplan/integration/codex-configuration
  (page shows `https://token-plan-cn.xiaomimimo.com/v1`; the user's plan console names
  their region, e.g. `token-plan-ams`; pay-as-you-go `https://api.xiaomimimo.com/v1`)

Both pages put the key into the file as `experimental_bearer_token`. Replace that line with
`env_key`. Shape, appended to `<codex home>/config.toml` after the user agrees:

```toml
[model_providers.ZAI]
name = "Z.ai GLM Coding Plan"
base_url = "https://api.z.ai/api/v1"
env_key = "ZAI_API_KEY"
wire_api = "responses"
```

Conventions:
- The table name is the provider name everywhere (`-Provider ZAI`, roster
  `"provider": "ZAI"`, `CODEX_CONSULT_PEAK_ZAI`); case-sensitive, short, ASCII. The env
  variable is `<NAME>_API_KEY` unless the user already uses another name.
- Plain single-line values only: no arrays, inline tables, multi-line strings, dotted keys
  or sub-tables inside the table (the bridge's scanner then marks the table unusable).
- Always write `wire_api = "responses"` explicitly. Changing `base_url` or `wire_api` later
  starts a new lineage (older threads can no longer be forked); `name`, comments and a
  rotated key never do.
- Only in the user-level `<codex home>/config.toml`: the bridge reads no other Codex
  config, so a table anywhere else is invisible to its identity and preflight.

Then tell the user to set the key themselves and restart Claude Code (a running session
does not see a variable set after it started):

- Windows: `setx ZAI_API_KEY "<key>"` in their own terminal
- macOS/Linux: `export ZAI_API_KEY="<key>"` in `~/.bashrc`, `~/.zshrc` or `~/.profile`

Never ask them to paste the key into the chat.

Models: use one the bridge's caps-v1 table declares for the host (z.ai: `glm-5.3`,
`glm-5.3-flash`, `glm-5.3-flashx`, `glm-5.2`, `glm-5.1`, `glm-5`, `glm-5-turbo`,
`glm-4.7`, `glm-4.6`, `glm-4.5`, `glm-4.5-air`; MiMo: `mimo-v2.6-pro`, `mimo-v2.6-flash`,
`mimo-v2.6-pro-ultraspeed`, `mimo-v2.5-pro`, `mimo-v2.5`). Any other model, or any host
not in caps-v1, needs `-NativeEffort <value>` on every run, which a roster entry cannot
supply.

## 3. Per-run model catalogs (MiMo-style)

Codex has no built-in catalog for MiMo models. With the user's consent, save the catalog
file the MiMo Codex page links to as `<codex home>/model-catalogs.json`, and pass it PER
RUN, never in `config.toml`: a global `model_catalog_json` replaces Codex's own catalog
and was observed to degrade the default `openai` model on an unrelated run ("Model
metadata not found, fallback"). Per run means the roster entry's
`"codex_config": ["model_catalog_json=~/.codex/model-catalogs.json"]`, or
`-CodexConfig model_catalog_json=~/.codex/model-catalogs.json` on one command (the bridge
expands `~/`; Codex on Windows does not). The same rule applies to any provider whose page
suggests a global catalog (z.ai's suggests `~/.codex/models.json`; the z.ai route works
without one).

## 3b. Gemini through the agy engine (Google's Antigravity CLI)

For the Gemini models under a Google AI Pro plan, the reviewer is reached through `agy`, the
official headless client (the plan terms allow only the official clients; no
`GEMINI_API_KEY` mode). It enforces the reply schema natively (`--json-schema`).

1. **Install** (ask the user): `winget install Google.AntigravityCLI`, or the official
   installer (it puts `agy.exe` under `%LOCALAPPDATA%\agy\bin`). Check:
   `(Get-Command agy.exe).Source` -> a path. Not on PATH: the user passes `-EngineExe
   <path>` or sets `CODEX_CONSULT_AGY_EXE`.
2. **Sign in - the USER does it:** they run `agy` once in their own terminal and sign in
   with their Google account (the credentials go to the OS keyring). You never handle a
   login, a token or a keyring entry.
3. **Check:** `agy models` -> exit `0` and lines `<model id><TAB><name>`, e.g.
   `gemini-3.8-flash-high  Gemini 3.8 Flash (High)`. The model id is the FULL id; its last
   part is the reasoning tier (`-high`, `-medium`, `-low`) - the bridge sends no effort for
   agy. Take the model ids from this list; never invent one.
4. **Roster entries** (section 4): `{ "provider": "gemini", "engine": "agy", "model":
   "gemini-3.8-flash-high" }` - `provider` is a free label (the lineage's provider), the
   model is required, `codex_config` and `auth` are refused, one label names one engine
   across the roster. For weighty asks add a second entry with the same label on the pro
   model, `{ "provider": "gemini", "engine": "agy", "model": "gemini-3.1-pro-high",
   "panel": "weighty" }`; a single run picks it with `-Provider gemini -Model
   gemini-3.1-pro-high`.
5. **Cost:** every agy call carries about 13-25k tokens of the CLI's own prompt and tools,
   and a resumed conversation replays itself (the bridge defaults agy to `-Mode new`); a diff
   review on `gemini-3.8-flash-high` reads the tree (observed: 605 s, 1.6M input + 5.9M
   cached tokens). Google AI Pro refreshes the quota every five hours until a weekly limit;
   the CLI cannot show the remaining quota; the bridge records `usage` per run.
6. **Read-only is not enforced by agy** (its `--sandbox` restricts the terminal only): the
   bridge fails an agy run when the working tree (tracked or untracked files) or the collab
   directory (every task's stores and handoffs) changed during it - enforced by evidence for
   tracked and untracked files and the collab directory; not for gitignored paths,
   submodules or files outside the repository. The check cannot tell who changed a file:
   tell the user not to edit the repository or the collab directory, and not to run another
   consultation in that repository, while an agy consultation runs.
7. **Sign-in timing:** `agy models` usually answers in ~2 s but has taken 15 s and more; the
   bridge waits up to 45 s, and skips the call when the repository's ledgers hold a usable
   agy reply from the last 60 minutes (`ok: signed in (usable reply <m> min ago)`).

## 3c. BytePlus ModelArk Coding Plan (a Codex provider)

The international ModelArk Coding Plan (BytePlus, region ap-southeast-1; Lite 10 USD / month)
bundles Dola-Seed (Doubao), GLM, DeepSeek, Kimi and gpt-oss behind one subscription quota
and speaks the Responses API on its Codex base URL, so it is an ordinary provider table:

```toml
[model_providers.byteplus]
name = "BytePlus ModelArk Coding Plan (ap-southeast-1)"
base_url = "https://ark.ap-southeast.bytepluses.com/api/coding/v3"
env_key = "BYTEPLUS_API_KEY"
wire_api = "responses"
```

- The base URL MUST end in `/api/coding/v3`: the plain `/api/v3` is pay-as-you-go billing
  and does not touch the plan quota. The plan's own rule: its key and base URL are for the
  supported coding tools (Codex CLI is one) - other uses may be treated as abuse.
- The user creates the API key in the ModelArk console ("API keys") and sets the variable
  themselves (`setx BYTEPLUS_API_KEY <value>`, then a NEW terminal). You never handle it.
- caps-v1 declares this host: vocabulary `low | medium | high` (`xhigh` -> `high`, mapping
  `ark-v1`), 12 exact model names (`dola-seed-2.0-pro`, `dola-seed-2.0-lite`,
  `dola-seed-2.0-code`, `bytedance-seed-code`, `glm-5.3-flash`, `glm-5.2`, `glm-5.1`,
  `kimi-k2.5`, `gpt-oss-120b`, `deepseek-v4.1-flash`, `deepseek-v4-flash`, `deepseek-v4-pro`),
  schema transport `prompt-only`. Any other model on that host is refused unless
  `-NativeEffort` is passed. The plan's docs enable reasoning with the Codex option
  `model_supports_reasoning_summaries = true`: pass it per entry as `"codex_config":
  ["model_supports_reasoning_summaries=true"]` (some Kimi code models reject it - check the
  first run's ledger).
- Quota (Lite, the docs' estimate on `dola-seed-2.0-lite` in Claude Code): about 1,200
  requests per sliding 5 hours, 9,000 per week, 18,000 per subscription month; Pro five
  times that. One quota for every model and tool. No refunds; the subscription authorises
  the vendor to use inputs and outputs for training.
- Roster entries are ordinary codex entries: `{ "provider": "byteplus", "model": "kimi-k2.5",
  "codex_config": ["model_supports_reasoning_summaries=true"] }`; the same label may carry
  several models (one entry per model), each a lineage of its own.

## 3d. Kimi Code membership (Moonshot; a Codex provider)

A Kimi membership (Plus and above) includes Kimi Code, whose overseas Codex base URL speaks the
Responses API, so K3 is an ordinary provider table:

```toml
[model_providers.kimi]
name = "Kimi Code membership (Moonshot, overseas)"
base_url = "https://api.kimi.ai/coding/v1"
env_key = "KIMI_API_KEY"
wire_api = "responses"
```

- The user creates the key in the Kimi Code Console (it is shown once) and sets
  `KIMI_API_KEY` themselves; the pay-as-you-go API (`https://api.moonshot.ai/v1`, model
  `kimi-k3`, its own key) is a different route and is not declared in caps-v1.
- caps-v1 declares `api.kimi.ai`: vocabulary `low | high | max` (`medium` -> `high`, `xhigh` ->
  `max`, mapping `kimi-v1`), models `k3`, `k3-256k`, `kimi-for-coding`,
  `kimi-for-coding-highspeed` (exact), schema transport `prompt-only`. Which of them the plan
  unlocks depends on the tier: Plus has `k3` and `k3-256k` at a 256K context, Pro adds the 1M
  window and `kimi-for-coding-highspeed`. A model the tier does not unlock fails the run with the
  endpoint's error, classified like any provider failure.
- Quota: a rolling 5-hour window (the new plans have no weekly cap); the numbers are not
  published. The plan's key is for coding tools; Codex CLI is one. Observed: one reviewing
  checkpoint with `k3` at `high` (the reviewer verified six prior findings with read-only tool
  calls) took 198 s and ~515k input tokens (410k cached), because Codex re-sends the context on
  every tool turn - budget the window in tokens, not in calls.
- Roster entry: `{ "provider": "kimi", "model": "k3", "panel": "weighty" }` (or `"always"`).

## 3e. Alibaba Cloud Model Studio Token Plan (Qwen; a Codex provider)

The Token Plan (Personal Edition; the Singapore region only) is a monthly credit subscription
whose Codex base URL speaks the Responses API - Qwen 3.8 is sold by subscription only here:

```toml
[model_providers.alibaba]
name = "Alibaba Cloud Model Studio Token Plan (ap-southeast-1)"
base_url = "https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1"
env_key = "ALIBABA_API_KEY"
wire_api = "responses"
```

- The user subscribes in the Model Studio console (region Singapore, Token Plan, Personal), then
  generates the plan's own key on the "My Subscription" page (`sk-sp-...`, shown in full once)
  and sets `ALIBABA_API_KEY` themselves. Two credentials that do NOT belong here: an AccessKey
  ID/Secret pair (cloud-management credentials for the whole account - never put one into a
  coding tool) and a general Model Studio key `sk-...` (it bills pay-as-you-go even while the
  plan is active). Alibaba's own guide puts the key into `OPENAI_API_KEY`; do not - it would
  hijack the built-in openai reviewer.
- caps-v1 declares `token-plan.ap-southeast-1.maas.aliyuncs.com`: vocabulary
  `low | medium | high | xhigh` (all as is, mapping `alibaba-v1`), 11 exact text models
  (`qwen3.8-max`, `qwen3.8-flash`, `qwen3.7-max`, `qwen3.7-plus`, `qwen3.6-flash`,
  `deepseek-v4.1-flash`, `deepseek-v4-pro`, `deepseek-v4-pro-0813`, `deepseek-v4-flash-0731`,
  `glm-5.3`, `glm-5.2`), schema transport `prompt-only`. The plan's `auto` router is not
  declared (the endpoint picks its target model, so the effort it accepts is unknown).
- Quota: credits per subscription month (Lite 11,500), no 5-hour or weekly windows, 1-2
  concurrent agents on Lite; the qwen3.8 and some DeepSeek models cost less at night, 22:00-08:00
  UTC+8 (16:00-02:00 in Central European summer time). Credits are charged per token, so Codex's
  context-resending tool loop costs more here than on a per-request plan. Observed on one narrow
  checkpoint (daytime rates): qwen3.8-max 158 s, 217k input tokens; deepseek-v4.1-flash 213 s,
  344k - the two together about 1.7% of the Lite month. The same checkpoint on
  deepseek-v4.1-flash through the BytePlus plan: 58 s.
- Terms: the plan is for interactive use in coding tools; automation scripts and
  non-interactive batch calls are prohibited and can get the key banned. A consultation is one
  Codex CLI run on request; keep this plan's members few and weighty.
- Codex logs "Model metadata for `qwen3.8-max` not found. Defaulting to fallback metadata" -
  harmless in the runs so far.
- Roster entry: `{ "provider": "alibaba", "model": "qwen3.8-max", "panel": "weighty" }`.

## 3f. Meta Muse through the muse engine (Muse Code CLI, the subscription)

The Muse Code subscription (the Everyday plan: 10-50 prompts per 5 hours; every muse turn of a
consultation is one prompt) works only through Meta's own CLI signed in by browser. An API
key (`META_API_KEY`, `MODEL_API_KEY`) overrides that sign-in and bills per token - the bridge
therefore REFUSES a muse run while either variable is set, and there is no opt-out.

1. **Install** (ask the user): the official Muse Code installer. On Windows it puts `muse.cmd`
   (a launcher for the versioned binary, which it may update) into
   `%LOCALAPPDATA%\Programs\muse` and adds that directory to the USER Path - a shell (and a
   Claude Code session) started before the install does not see it; the bridge falls back to
   that location by itself. Check without spending a prompt: `muse --version` -> a version
   line (or `Test-Path "$env:LOCALAPPDATA\Programs\muse\muse.cmd"` -> `True`). Elsewhere: the
   user passes `-EngineExe <path>` or sets `CODEX_CONSULT_MUSE_EXE`.
2. **Credential backend - Windows, the USER sets it BEFORE signing in:** the keychain write
   fails there, so the credential must go to a file: the user variable
   `TBH_CREDENTIAL_BACKEND=file` (e.g. `[Environment]::SetEnvironmentVariable('TBH_CREDENTIAL_BACKEND', 'file', 'User')`,
   then a new shell / a restarted Claude Code). Elsewhere the file backend is recommended too:
   the bridge cannot read a keychain, so its preflight would say "sign-in not checkable" and
   refuse the run.
3. **Sign in - the USER does it:** `muse login` in their own terminal shows a device code they
   approve in the browser. The credential then lives in `~/.config/muse/auth.json`. You never
   read, print or copy that file, and never handle a login, a token or a device code.
4. **Never an API key.** Confirm with the user that neither `META_API_KEY` nor `MODEL_API_KEY`
   is set (ask; do not print the environment). If one is, the user removes it - it would bill
   per token, and the bridge refuses every muse run meanwhile (`the muse engine is refused:
   META_API_KEY is set: ...`, also under `-SkipPreflight`).
5. **The model - the USER decides:** caps-v1 declares the two subscription models verified
   live: `muse-spark-1.3-contributor` (the CLI's default; Meta may train on its inputs) and
   `muse-spark-1.3` (the standard one). Ask which one; never pick the contributor variant
   silently. The effort goes as `--reasoning-effort` (`low`, `medium`, `high`, `xhigh` as is,
   mapping `muse-v1`).
6. **Roster entry** (section 4): `{ "provider": "meta", "engine": "muse", "model":
   "muse-spark-1.3" }` - `provider` is a free label, the model is required, `codex_config`
   and `auth` are refused. Every muse entry shares one endpoint (one Meta sign-in): a usage
   limit hit by one blocks them all until its reset.
7. **Check:** `codex-providers.ps1` -> the row `available  meta  <n>  engine muse  muse
   (<launcher>)  ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth)
   muse (2 declared models)  -`. Other verdicts: `unavailable (missing: not signed in: ...)`
   (no file: run `muse login`), `unknown (sign-in not checkable: TBH_CREDENTIAL_BACKEND ...)`
   (step 2 missing), `unavailable (refused: META_API_KEY is set: ...)` (step 4),
   `unavailable (muse CLI not found on PATH)` (step 1).
8. **Read-only:** muse runs with `--disable-write --disable-shell --disable-web-tools
   --approval-mode never`, and the bridge fails a muse run when the working tree or the
   collab directory changed during it (by evidence; gitignored paths, submodules, files
   outside the repository and reads - its `read_file` is not confined to the repository - are
   not covered). Tell the user not to edit the repository or run another consultation there
   while a muse consultation runs.

## 4. Write the roster

`<codex home>/codex-consult-roster.json`, first choice first:

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
    },
    { "provider": "gemini", "engine": "agy", "model": "gemini-3.8-flash-high" },
    { "provider": "gemini", "engine": "agy", "model": "gemini-3.1-pro-high", "panel": "weighty" },
    { "provider": "meta", "engine": "muse", "model": "muse-spark-1.3" }
  ]
}
```

- Allowed keys only: `roster_version` (must be `1`), `reviewers[]` with `provider`
  (required), `model`, `codex_config` (array of `key=value` strings), `auth`, `panel`,
  `engine` (`codex`, the default, `agy` or `muse`), and the optional top-level `parallel`
  (`{"<provider label>": n}`, n >= 1: how many `-Panel` members of that label may run at
  once; the default is one at a time per endpoint). An unknown key, an unknown engine, an
  agy or muse entry without a model or with `codex_config`/`auth`, one label with two engines, a
  duplicate `(provider, model)`, a `parallel` value that is not an integer >= 1 or names a
  label the roster does not use, or invalid JSON refuses EVERY run.
- `"panel": "weighty"` for the expensive reviewer: it joins a `-Panel` run only on
  `framing`, `decision`, `core-contract`, `acceptance` and `stuck` (or `-PanelAll`). The
  default is `"always"`.
- `codex_config` must not set `model`, `model_provider`, `model_reasoning_effort`,
  `profile` or `model_providers.*` (refused).
- Another file: the user sets `CODEX_CONSULT_ROSTER=<path>` (it must exist).
  `CODEX_CONSULT_ROSTER=none` disables the roster.

## 5. Verify

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-providers.ps1"
```

Expect exit `0`, a first line `codex config: <path>`, one row per provider, and for each
wired one `available` with `ok: Logged in using ChatGPT` or `ok: env <NAME> set`, e.g.
`available  ZAI  2  custom  https://api.z.ai/api/v1  ok: env ZAI_API_KEY set  zai (11 declared models)  -`,
then `roster: <path> -> would select <provider> :: <model>`. Other verdicts:
`unavailable (missing: env <NAME> not set)` (not set, or Claude Code not restarted),
`unavailable (usage limit until <iso>)`, `unknown (<reason>)` (login check failed, or the
config cannot be scanned). An agy roster label gets its own row: `available  gemini  4,5
engine agy  agy (<launcher>)  ok: signed in (N models)  agy (tier in the model id)  -`
(this listing makes one `agy models` call - none, and `ok: signed in (usable reply <m> min
ago)`, after a usable agy reply in this repository within the last 60 minutes; with
`-NoNetwork` the row otherwise reads `not checked (launcher present; run
codex-providers.ps1)` / `unknown (sign-in not checked)`, which is what the SessionStart hook
shows); `unavailable (agy CLI not found on PATH)` or
`unavailable (missing: ``agy models``: <sign-in message>)` otherwise. A muse label's row: see
section 3f, step 7 (its sign-in check is local, so it runs with `-NoNetwork` too). Exit `1` means an
unusable roster, or a `CODEX_CONSULT_ROSTER` file that does not exist; the message names
it.
Per provider: `-Provider <name>` (exit `0` available, `2` unavailable, `3` unknown, `1`
no such provider).

Then a dry run inside a git repository, once per reviewer:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult.ps1" -Task setup-check -Prompt "Reply with one sentence." -DryRun -Provider ZAI -Model glm-5.3
```

Expect exit `0`, `DRY RUN - nothing was executed and no file was written.`,
`preflight   : available (ok: env ZAI_API_KEY set)`,
`effort      : high sent (requested high, mapping zai-v1, …)`, and a `transport   :`
line (`output-schema` for openai and z.ai, `prompt-only` for MiMo). For agy:
`-DryRun -Engine agy -Provider gemini -Model gemini-3.8-flash-high` -> `engine      : agy -
Gemini (agy) (from -Engine)`, `preflight   : available (ok: signed in (N models))`,
`effort      : nothing sent (requested high, mapping model-tier, ...)`, `transport   :
native (...)` and a `command     : agy -p= --input-format stream-json --output-format
stream-json --model gemini-3.8-flash-high --json-schema <schema> --print-timeout 0 --sandbox
--disable-slash-commands` line. For muse: `-DryRun -Engine muse -Model muse-spark-1.3` ->
`engine      : muse - Meta Muse (muse) (from -Engine)`, `preflight   : available (ok: signed
in (~/.config/muse/auth.json: providers.meta, mechanism oauth))`, `effort      : high sent
(requested high, mapping muse-v1, ...)`, `transport   : native (...): passed as
--output-schema ...` and a `command     : muse exec --json --prompt-file <temp file>
--output-schema <schema> --model muse-spark-1.3 --reasoning-effort high
--no-foreign-personal-context --disable-web-tools --disable-write --disable-shell
--approval-mode never` line (the dry run runs `muse --version` at most, which spends no
prompt). Only with the user's
consent, run one live `-Purpose chore` consultation to confirm the route end to end
(expect `codex-consult: usable reply - <provider> :: <model>, …`).

## 6. Optional

- **Peak windows:** the user sets `CODEX_CONSULT_PEAK_<PROVIDER>="Mon-Fri 14:00-18:00 +08:00"`
  (days, start-end, fixed offset; schedule from the plan's own page) and optionally
  `CODEX_CONSULT_PEAK_<PROVIDER>_EXCEPT="2026-10-01..2026-10-07"`. A run at peak warns;
  `-OffPeakOnly` refuses at peak and when no schedule is set.
- **`-SchemaTransport output-schema|prompt-only`:** a one-run override of caps-v1's
  declared transport, only when you know the declared one is wrong for that endpoint.
- **`"auth": "none"`** in a roster entry: only for a table with neither `env_key` nor a
  bearer token (e.g. a local endpoint); it has no effect on a table that names an
  `env_key`. Such a host is not in caps-v1, so it also needs `-NativeEffort`.

## 7. Record it

In the project's `state.md` (or its notes file): the providers wired and their models, the
roster path, order and panel weights, the env variable NAMES (never values), any peak
variables, the `codex-providers.ps1` verdict per provider with the date, and what is still
unavailable and why (and what the user was asked to do about it).
