# Phase 2: Consistent Java Handling - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-14
**Phase:** 2-consistent-java-handling
**Areas discussed:** Version check method, Too-old JAVA_HOME handling, macOS rerun persistence, Windows JAVA_HOME source, Test coverage
**Mode:** `--auto` (yolo chain after Phase 1 transition); every choice is the recommended option.

---

## Version check method

| Option | Description | Selected |
|--------|-------------|----------|
| `java -version` major ≥ 21 | Run `$JAVA_HOME/bin/java -version`, parse first line; unusable on failure | ✓ |
| `$JAVA_HOME/release` file | Read `JAVA_VERSION=` without running java | |
| Trust any non-empty value | Current behavior | |

**User's choice:** [auto] `java -version` major ≥ 21 (recommended; AUDIT HARD-06 fix)

## Too-old JAVA_HOME handling

| Option | Description | Selected |
|--------|-------------|----------|
| Warn, install own JDK, override for this run + persisted the platform way | User's JDK untouched; uninstall removes ours | ✓ |
| Abort and ask the user to fix JAVA_HOME | Loud but blocks install | |
| Override for this run only, persist nothing | New shells lose JDK 21 | |

**User's choice:** [auto] Warn and install own (recommended)

## macOS rerun persistence

| Option | Description | Selected |
|--------|-------------|----------|
| Re-add JAVA_HOME to profile_exports when it equals our openjdk@21 path | AUDIT HARD-11 fix | ✓ |
| Unset our own settings at start like Linux | Larger change to macOS flow | |

**User's choice:** [auto] Re-add when it's ours (recommended)

## Windows JAVA_HOME source

| Option | Description | Selected |
|--------|-------------|----------|
| Derive from `java` on PATH after Update-SessionPath, persist with Set-UserEnv | Works whether or not the MSI sets it | ✓ |
| Read Machine JAVA_HOME (current) | Fails when MSI's FeatureJavaHome is off | |

**User's choice:** [auto] Derive from PATH (recommended; AUDIT HARD-04 fix)

## Test coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Extend test.sh with stub java version table + macOS block check | Same harness as Phase 1 | ✓ |
| No new tests, code review only | | |

**User's choice:** [auto] Extend test.sh (recommended)

## Claude's Discretion

- Function names, warning wording.
- Whether to address WR-01 inside `install_jdk`.

## Deferred Ideas

- VERI-02 real-Windows check.
- Reusing a JDK found without JAVA_HOME.
- macOS `GHIDRA_INSTALL_DIR` (research question only).
