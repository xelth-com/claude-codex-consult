---
name: dry-run-consultation
description: Install test - a fresh agent with this plugin must find the consult-codex skill, run the bridge in -DryRun mode for a new task and report the preflight line, writing nothing.
tags: [smoke, install]
runs: 1
max_turns: 12
timeout_seconds: 300
allowed_tools:
  - Read
  - Glob
  - Grep
  - Skill
  - Bash
---

Check that the codex-consult plugin works on this machine. Do a DRY RUN consultation
(no real call to any reviewer, nothing written) for the task id `eval-smoke` with the
ask "Is the bridge installed correctly?". Then tell me, in a few lines: the first line
the bridge printed, the `preflight` line, the `reviewer` line, and whether any file was
written. Do not attempt a real consultation and do not create or set any API key.
