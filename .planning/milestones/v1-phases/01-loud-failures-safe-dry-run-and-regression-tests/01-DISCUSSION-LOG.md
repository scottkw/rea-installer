# Phase 1: Loud Failures, Safe Dry Run, and Regression Tests - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-14
**Phase:** 01-loud-failures-safe-dry-run-and-regression-tests
**Areas discussed:** How tests reach functions, Partial-extract cleanup, Missing local tools, CI coverage of macOS

---

## How tests reach functions

| Option | Description | Selected |
|--------|-------------|----------|
| Source guard | Wrap main dispatch so tests can source the script and call real functions | ✓ |
| Extract with sed | Copy function bodies out with sed/awk and eval them | |
| Black-box only | Run full scripts with fake commands on PATH | |

| Option | Description | Selected |
|--------|-------------|----------|
| Fake commands on PATH | Stub apt-get/unzip/tar/brew that exit 1, in a temp bin dir | ✓ |
| Override functions | Redefine `run` after sourcing | |
| You decide | Leave to planner | |

| Option | Description | Selected |
|--------|-------------|----------|
| Single ./test.sh | One root file; stubs generated at runtime | ✓ |
| test.sh + tests/ dir | Entry point plus tests/ directory | |

| Option | Description | Selected |
|--------|-------------|----------|
| docker run from test.sh | Same command locally and in CI | ✓ |
| CI job container only | Local runs skip the container check | |

| Option | Description | Selected |
|--------|-------------|----------|
| Separate commit + log | Commit tests first, save failing output to the phase folder | ✓ |
| Commit order only | No log | |
| Note in SUMMARY | Executor records the outcome in the SUMMARY | |

**Notes:** Claude flagged that a naive `BASH_SOURCE` guard breaks `curl | bash`, so the guard must detect sourcing instead.

---

## Partial-extract cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Stage, then rename | Extract to a staging folder, mv on success; survives Ctrl-C | ✓ |
| rm -rf on failure (audit fix) | One line; Ctrl-C still leaves a partial folder | |
| Both | Stage plus cleanup on a caught error | |

| Option | Description | Selected |
|--------|-------------|----------|
| No, stop and rerun | Keep recorded items; rerun continues | ✓ |
| Roll back this run | Undo the run's records on failure | |

| Option | Description | Selected |
|--------|-------------|----------|
| Warn and continue | Optional tools warn; required tools die | ✓ |
| Stop on any failure | Treat requested optional tools as required | |

---

## Missing local tools

| Option | Description | Selected |
|--------|-------------|----------|
| Skip with SKIP line, fail in CI | Local skip; CI=true makes a missing tool a failure | ✓ |
| Always fail | Every tool required | |
| Fast flag | `--fast` skips the container check | |

| Option | Description | Selected |
|--------|-------------|----------|
| PASS/FAIL per check + summary | Run every check, then exit 1 if any failed | ✓ |
| Stop at first failure | set -e style | |

---

## CI coverage of macOS

| Option | Description | Selected |
|--------|-------------|----------|
| ubuntu + macos jobs | macOS job checks the macOS script under /bin/bash 3.2 | ✓ |
| ubuntu only | No Bash 3.2 check | |

| Option | Description | Selected |
|--------|-------------|----------|
| No, functions only | No macOS-script dry run on the runner | ✓ |
| Yes, add it | Dry run on a runner that isn't representative | |

---

## Claude's Discretion

- Source-guard idiom, stub mechanics, staging-folder naming, test.sh internals, workflow file name and action versions.

## Deferred Ideas

- `usage()` under `curl | bash` (`$0` is `bash`) — possible Phase 3 polish.
- Rollback of partial installs — rejected for this milestone.
