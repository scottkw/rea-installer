# Phase 2: Consistent Java Handling - Context

**Gathered:** 2026-10-14
**Status:** Ready for planning
**Mode:** `--auto` (every gray area resolved with the recommended option; see 02-DISCUSSION-LOG.md)

<domain>
## Phase Boundary

One JDK rule on Linux, macOS and Windows: reuse an existing `JAVA_HOME` only if its `java` is JDK 21 or newer; otherwise install the script's own JDK 21, point this run's `JAVA_HOME` at it, persist it the platform's way (profile block / user env var) so `uninstall` removes it, and keep it across reruns. Covers JAVA-01..04 (AUDIT HARD-04, HARD-05, HARD-06, HARD-11). No new tools, flags or platforms.

</domain>

<decisions>
## Implementation Decisions

### JDK version check (JAVA-02)
- **D-01:** "Usable" means `"$JAVA_HOME/bin/java" -version` (PowerShell: `& "$env:JAVA_HOME\bin\java.exe" -version`) runs and its first line's quoted version has major ≥ 21. Parse `"1.8.0_x"` as 8, `"17.0.2"` as 17, `"21"` / `"21.0.5"` as 21, `"25-ea"` as 25. Missing or non-executable `java`, or unparseable output, counts as unusable (fail closed). Do not use the `release` file or `/usr/libexec/java_home`.
- **D-02:** One small predicate per script (bash: `jdk_usable DIR` returning status, matching `node_supported`; PowerShell: `Test-JdkUsable([string]$Dir)` returning bool). Duplicated in each script, per the no-shared-code rule. Bash version must stay Bash 3.2 safe in the macOS script.
- **D-03:** Only `JAVA_HOME` is consulted to decide reuse. A JDK found some other way (`java` on PATH, `/usr/libexec/java_home`, Machine-scope env var) is not reused. Keeps the rule identical on all three platforms.

### Too-old or broken JAVA_HOME (JAVA-02)
- **D-04:** If `JAVA_HOME` is set but unusable: `warn "JAVA_HOME points at <dir>, which is not JDK 21 or newer; installing the script's own JDK 21."`, install our JDK, and set this run's `JAVA_HOME` to it. The user's own JDK is never removed or modified.
- **D-05:** Persistence follows each platform's existing mechanism and is removed by `uninstall`: Linux `setting JAVA_HOME` (profile block), macOS `profile_exports` (profile block), Windows `Set-UserEnv` (which warns and leaves an existing *user* variable untouched; the session value is still set so `rea setup` sees JDK 21). — **Reversibility:** reversible — profile block and `env:` ledger entry are already removed by uninstall.

### macOS reuse and reruns (JAVA-03, JAVA-04)
- **D-06:** macOS step 4 (Ghidra) and step 5 (Android) both go through the same reuse-or-install decision; a usable user `JAVA_HOME` writes no `JAVA_HOME` line to the profile block.
- **D-07:** On rerun, if `JAVA_HOME` already equals the script's own path (`$(brew --prefix "$JDK_FORMULA")/libexec/openjdk.jdk/Contents/Home`), re-add it to `profile_exports` even though `install_jdk` is skipped, so the rewritten block keeps it (AUDIT HARD-11 fix). Exactly one profile block after two runs.

### Windows JAVA_HOME after Temurin (JAVA-01)
- **D-08:** After `Install-Winget $JdkId` and `Update-SessionPath`, derive the folder from the `java` now on PATH: `Split-Path (Split-Path (Get-Command java).Source)`, check it with `Test-JdkUsable`, then `Set-UserEnv 'JAVA_HOME' <dir>`. Works whether or not the MSI set a Machine `JAVA_HOME`; drop the current `throw "Temurin installed but JAVA_HOME was not set."` path. If the derived folder is not JDK 21+, throw with that folder in the message.
- **D-09:** `-DryRun` keeps a placeholder (`<Temurin JAVA_HOME>`) for the session value and records nothing, as today.

### Testing
- **D-10:** Extend `test.sh` (no new files): stub `$JAVA_HOME/bin/java` scripts printing version strings to table-test the bash predicate in both scripts (8, 17, 21, 21.0.5, 25-ea, missing, garbage); a macOS check that two sourced profile-block writes with our `JAVA_HOME` leave one block containing `JAVA_HOME`; Windows predicate/derivation covered by the existing pwsh parse plus a pwsh driver check if cheap. Real-Windows confirmation stays deferred to VERI-02.

### Claude's Discretion
- Exact function names and warning wording (sentence case, period, matches existing `warn` style).
- Whether Linux `install_jdk` also tolerates an Adoptium archive whose top folder differs from `release_name` (accepted limitation WR-01); fix only if it falls out naturally from touching `install_jdk`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Findings and fixes
- `.planning/AUDIT.md` — HARD-04, HARD-05, HARD-06, HARD-11: location, problem, fix and acceptance for each; "Out of scope / not checked" notes the unverified Temurin MSI behavior and the macOS `GHIDRA_INSTALL_DIR` question.
- `.planning/REQUIREMENTS.md` — JAVA-01..04, VERI-02 (deferred real-Windows check).
- `.planning/ROADMAP.md` § Phase 2 — success criteria 1-4.

### Prior phase
- `.planning/phases/01-loud-failures-safe-dry-run-and-regression-tests/01-CONTEXT.md` — D-01..D-13 (source guard, PATH stubs, single `test.sh`, CI jobs).
- `.planning/phases/01-loud-failures-safe-dry-run-and-regression-tests/01-REVIEW-DISPOSITION.md` — WR-01 accepted limitation in Linux `unpack` (relevant to `install_jdk`).

### Codebase
- `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/ARCHITECTURE.md` — `run`/`record`/`setting`/`Set-UserEnv` patterns, ledger kinds, Bash 3.2 constraint.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `node_supported` (all three scripts): the model for a version-gate predicate and its `test.sh` table test.
- Linux `setting NAME VALUE`: exports and queues the profile line; `do_install` unsets settings pointing into `$STATE_DIR` at start so the block is rewritten whole.
- macOS `profile_exports+=(...)`; Windows `Set-UserEnv` (skips equal value, warns on a different existing user value, records `env:NAME`).
- `test.sh` stub-on-PATH + temp `HOME` harness from Phase 1.

### Established Patterns
- Linux `install_jdk` (`rea-install-linux.sh:319-336`), macOS `install_jdk` (`rea-install-macos.sh:123-129`) and callers at `:185`, `:192`; Windows `Install-Jdk` (`rea-install-windows.ps1:160-167`), callers at `:196`, `:203`.
- Linux trusts any non-empty `JAVA_HOME` today; macOS step 4 always installs; macOS step 5 and Windows trust any non-empty value.

### Integration Points
- `rea setup` reads `JAVA_HOME` from the environment and copies it into agent registrations, so the session value must be the usable JDK.
- Linux Apktool launcher embeds `$JAVA_HOME` as its fallback (`rea-install-linux.sh:411-412`).

</code_context>

<specifics>
## Specific Ideas

- Research question for the planner/researcher (not a decision): does REA find Ghidra on macOS without `GHIDRA_INSTALL_DIR` when Ghidra comes from Homebrew? Check REA docs; if it needs the variable, record it as a follow-up rather than expanding this phase.

</specifics>

<deferred>
## Deferred Ideas

- Real-Windows confirmation of JAVA-01 — VERI-02 (v2).
- Reusing a JDK 21+ discovered without `JAVA_HOME` (`/usr/libexec/java_home -v 21`, `java` on PATH) — possible later polish; out of scope for the one-rule fix.
- Setting `GHIDRA_INSTALL_DIR` on macOS — only if research shows REA needs it; would be its own follow-up.

</deferred>

---

*Phase: 02-consistent-java-handling*
*Context gathered: 2026-10-14*
