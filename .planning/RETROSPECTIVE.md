# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1 — Installer Hardening

**Shipped:** 2026-10-15
**Phases:** 3 | **Plans:** 17 | **Sessions:** not tracked

### What Was Built
- A local `test.sh` (macOS Bash 3.2 + `ubuntu:24.04` container) that sources the real installers with stub commands; 119 / 85 checks passing at close.
- Loud failures: failed extracts and package installs stop and record nothing; staged extraction lets a rerun recover.
- Side-effect-free Linux dry runs; uninstall that survives a broken `rea`.
- One JDK 21+ rule on Linux, macOS and Windows, with `JAVA_HOME` kept across reruns by ledger ownership.
- Unattended macOS install (no terminal, `--yes`, Homebrew) and a README that matches the shipped behaviour.

### What Worked
- Writing each regression check red before the fix (`01-RED.log`) proved the checks could fail and caught weak ones.
- A `return 0` source guard let `test.sh` load the real scripts' functions instead of copies.
- Recording every review finding's disposition (fixed / deferred-accepted) kept deferred work visible all the way into the README's Known limitations.

### What Was Inefficient
- Phase 2 (Java) took 10 plans: rerun behaviour across three platforms kept surfacing new edge cases through review → gap → re-review cycles.
- GitHub Actions was built in Phase 1 and removed in Phase 2 by user decision.
- Phase VERIFICATION reports went stale as later phases touched the same scripts, so the close relied on the milestone audit instead.

### Patterns Established
- Ownership comes from the ledger or the script's own profile block, never from the caller's shell environment.
- Internal seams (`TTY_PATH`, `STUB_TAR`) are constants or test-only switches, never read from the user's environment.
- Every accepted finding gets a README Known limitations bullet before the milestone closes.

### Key Lessons
1. Rerun and "already present" paths need as much design as the fresh install; plan them up front per platform.
2. A check's name must not claim more than it proves (03 WR-04's NONINTERACTIVE check).
3. Real-machine runs (VERI-01/02) are the biggest remaining risk; static traces and stubs cannot cover installer prompts or MSI behaviour.

### Cost Observations
- Model mix: not tracked
- Sessions: not tracked
- Notable: 17 plans in 2 days; most plans ran in 2–8 minutes.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1 | — | 3 | Red-first regression checks; local-only testing |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1 | 119 (macOS) / 85 (Linux) checks | not measured | 1 (`test.sh`) |

### Top Lessons (Verified Across Milestones)

1. (Needs a second milestone to confirm.)
