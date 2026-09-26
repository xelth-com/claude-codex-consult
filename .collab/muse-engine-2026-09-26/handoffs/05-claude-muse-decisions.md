# Engine `muse` - decisions after the design review (round 1)

Reviews: 02 ZAI :: glm-5.3 (F02-1..21), 03 byteplus :: deepseek-v4.1-flash (F03-1..13),
04 byteplus :: dola-seed-2.0-pro (F04-1..7; mostly restates the design's own to-do items).
Panel 0168bb07 ran the three at once: 772 s wall against 1594 s summed. The design in 01 stands
where not overridden here.

D1. Adapter contract (F02-2, F03-2). An engine's Argv receives one turn-options object
    {Model, Mode, Thread, PromptFile, Schema, Effort, NativeEffort, MaxSteps}; every turn - main,
    denial retry, format repair - passes its own prompt file. Muse takes the prompt only through
    `--prompt-file` (no stdin). agy keeps its stdin NDJSON through the same contract.
D2. Secondary turns through the adapter (F02-1, F03-3, F02-15). The denial-retry and
    format-repair turns parse with `$engineSpec.Adapter.Events` / `.Outcome`, never the agy
    functions by name (this fixes the path for every future engine). Muse: denial retry off (its
    tools are disabled by flags - there is nothing to deny); format repair at most once, never
    after a quota, auth or billing failure; each Muse turn is one subscription prompt and the
    ledger records how many the consultation spent.
D3. Launcher (F03-1, F03-4, F02-17). Resolution order for muse: `-EngineExe` (bound to the
    SELECTED non-codex engine, in codex-consult.ps1 and codex-providers.ps1 alike),
    `CODEX_CONSULT_MUSE_EXE`, PATH, then the vendor's install location
    `%LOCALAPPDATA%\Programs\muse\muse.cmd` on Windows (a bridge started before the install does
    not see the new user PATH entry - verified: the directory is on the User PATH but not on the
    running session's). Elsewhere PATH only.
D4. Billing is a launch invariant, not a preflight check (F02-4, F02-5, F03-7, F04-1). A muse run
    is refused when `META_API_KEY` or `MODEL_API_KEY` is set in the bridge's environment
    ("would bill per token instead of the subscription; unset it"); `-SkipPreflight` never
    bypasses it; checked when the entry is selected and again right before Start-Process, in
    panel members too. Subscription only in this wave: no `billing` roster key. The credential's
    `providers.meta.mechanism` value (an enum such as `oauth`, never a secret) goes into
    `reviewer.provider_config.credential_mechanism`; any mechanism other than `oauth` refuses.
D5. Preflight states (F02-6, F03-6, F02-7). With `TBH_CREDENTIAL_BACKEND=file`: `auth.json` parses
    and has `providers.meta` with a mechanism -> ok; file absent -> missing ("run `muse login`");
    otherwise (keychain backend) -> unknown -> refused unless `-SkipPreflight`. The docs say the
    file backend is required on Windows (the keychain write fails there anyway). The parsed object
    is never logged or written anywhere.
D6. MSP invariants (F02-11, F03-8). Every record's `schema_version` must be 1 (anything else:
    malformed stream, "unsupported MSP version N", fail closed). Exactly one session stream id,
    UUID-shaped, across the records; exactly one `run_terminal`; `completed` -> its text. The
    model in `run.model.configured` must equal the requested model, else class capability
    ("model drift: asked X, served Y"). Resume: the session id must equal the requested parent,
    else fail like agy's ExpectThread.
D7. Exits and terminals (F02-12, F03-11). Exit 2 -> capability (usage error, text kept). A failed
    or cancelled terminal whose reason names the step cap -> capability ("max model steps
    reached"). Other failures -> the shared text classifier (quota wording -> quota with
    retry_after when a reset is named). 130/143 -> transport, unless the bridge's own timeout
    killed it (then timeout). Meta's quota wording is unknown yet: record it verbatim.
D8. Version (F02-13, F03-10, F04-5). Read `.muse-version` (and `.muse-release-info.json`) next to
    the resolved launcher, else `muse --version` (free): `reviewer.harness` = `muse-cli <version>`,
    plus `msp_schema_version` in the ledger. An unseen CLI version is recorded, not refused; an
    MSP schema_version other than 1 refuses (D6).
D9. `-MaxModelSteps` (F02-16, F02-21). Optional, no default (the vendor default applies),
    positive integer, muse only (refused with other engines), carried through the dry run, the
    panel spec and the ledger.
D10. caps-v1 (F03-5, F02-20). Vocabulary `muse` (mapping `muse-v1`: low, medium, high, xhigh as
     is) in `$script:EffortVocabularies`; `engine:muse` declares only the live-verified
     `muse-spark-1.3` and `muse-spark-1.3-contributor`, SchemaTransport `native`. A vocabulary
     missing from the table becomes a plan error in Resolve-EffortPlan (loud, never a silent
     empty mapping).
D11. Engine-specific wording (F02-10, F03-9, F03-12). The transport line, the reply source, the
     read-only/sandbox wording and the prompt's read-only tool line come from the engine row. Muse:
     "prompt from a file", "the run_terminal record's text", "--disable-write --disable-shell
     --disable-web-tools", tools named as Muse names them. agy keeps its current wording.
D12. Tree check and its boundary (F02-8, F02-9, F02-19, F04-2). Muse gets the agy snapshot check
     (repository fingerprint + collab root). Documented boundary: gitignored paths, submodules,
     anything outside the repository, and reads (read_file is not confined to the repository) are
     not covered. A detected mutation forces class `permission` even when the run had already
     failed for another reason (that reason stays in the message) - for agy too; test it.
D13. Roster (F02-3). `muse` joins the engine names; roster validation accepts `"engine": "muse"`.
D14. Endpoint identity: one Meta sign-in = one endpoint; every muse entry shares a fingerprint,
     like agy (a quota on one blocks all until its reset).
D15. Fake and tests (F02-18, F03-13, F02-14). `tests/fake-muse.ps1` + `.cmd` emit MSP records
     derived from a sanitized real probe (see the scratch probe named in the brief). Knobs: reply
     text, delay, failed terminal with reason, exits 1/2/130, a file write, hang, two terminals,
     two sessions, wrong model, schema_version 2, a partial last line. Cases: argv spelling
     against the real flags, prompt and schema paths with spaces through the `.cmd` chain, billing
     guard incl. under -SkipPreflight and in a panel member, the three preflight states,
     extraction invariants, failure classes, tree check (and D12's forced class), resume and a
     session mismatch, a format repair served through the adapter, -MaxModelSteps in the panel
     spec, -EngineExe bound to muse, dry-run text.
D16. Docs: README (engine section, tables, the boundary), `setup-providers` 3f (subscription,
     install, `muse login` with `TBH_CREDENTIAL_BACKEND=file`, never an API key, the contributor
     vs standard model choice left to the installing user), CHANGELOG `[0.4.0]` wave 23.

Rejected as not design defects (they restate the design's own items): F04-3, F04-4, F04-6,
F04-7. Superseded: F04-1 by F02-4 (D4), F04-2 by F02-19 (D12), F04-5 by F02-13 (D8).
