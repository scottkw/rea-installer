# Milestones

## v1 Installer Hardening (Shipped: 2026-10-15)

**Delivered:** The three installers now stop loudly on failure, dry runs change nothing, uninstall survives a broken `rea`, Java is handled by one rule on every platform, and macOS installs unattended, all guarded by a local `test.sh`.

**Phases completed:** 3 phases, 17 plans, 33 tasks
**Timeline:** 2026-10-14 → 2026-10-15 (2 days)
**Git range:** `c403774` (Add REA installers) → `4cf254a`
**Code:** installers + tests 2,436 lines (Bash, PowerShell); +1,514 / -170 across the three scripts, `test.sh` and README
**Requirements:** 19/19 v1 requirements satisfied (see `milestones/v1-REQUIREMENTS.md`)

**Key accomplishments:**
- `test.sh` runs locally (macOS Bash 3.2 and an `ubuntu:24.04` container): syntax, shellcheck, PowerShell parse, sourced-function checks with stub commands, and a no-network dry run that must leave the home folder unchanged. Checks were committed red (`01-RED.log`) before the fixes.
- Failed extracts and package installs stop the install and record nothing; archives unpack through a staging folder on Linux and Windows, so a rerun recovers.
- Linux dry runs are side-effect-free on a fresh machine, and uninstall finishes on all three platforms when `rea uninstall` fails.
- One Java rule on Linux, macOS and Windows: reuse a `JAVA_HOME` that is JDK 21+, otherwise install and record our own, and keep it across reruns by ledger ownership, not the caller's shell.
- macOS installs without a terminal (skips `rea setup` with a warning) and under `--yes` (unattended Homebrew that stops loudly on failure); uninstall prompts without a terminal answer no.
- README Status, Testing and Known limitations match the shipped behaviour, including every accepted deferred finding.

**Closeout:** override_closeout
- Known verification overrides: 1 newly acknowledged, 0 carried forward from a prior close (see STATE.md Deferred Items)
- Phase VERIFICATION reports were stale at close (scripts and README changed after each verifier ran); closed on the 2026-10-15 milestone audit (19/19 requirements, 11/11 integration, 5/5 flows; status tech_debt) by user decision.

**Tech debt carried forward:** see `milestones/v1-MILESTONE-AUDIT.md` (deferred review findings per phase, backlog 999.1 and 999.2, real-machine checks VERI-01/VERI-02).

---
