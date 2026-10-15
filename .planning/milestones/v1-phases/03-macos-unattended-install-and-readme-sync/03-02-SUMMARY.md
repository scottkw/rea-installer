---
phase: 03-macos-unattended-install-and-readme-sync
plan: 02
subsystem: docs
tags: [readme, testing, known-limitations, macos, windows, linux]
status: complete

requires:
  - phase: 03-macos-unattended-install-and-readme-sync
    provides: "03-01: register_agents/confirm no-terminal behavior, install_homebrew under --yes, test.sh MAC-01/02 checks"
provides:
  - "README Testing: `### Running the tests` with the two local commands, coverage, output format and the SKIP/CI=true rule"
  - "README Status: macOS and Windows `Dry runs and test.sh only`; Linux `Tested end to end before the current round of fixes`"
  - "README Options, Uninstalling and How the scripts were engineered describe the milestone's behavior"
  - "README Known limitations: 7 new bullets (16 top-level bullets total); callout adds the unattended macOS install"
affects: [milestone audit, /gsd-verify-work 3]

actuals:
  tokens: 4000
  tasks: 3
  commits: 3
plan_head_before: af3f66ac87d85c3a53bf8797fa0e7bc36c659c05
plan_head_after: 7eb5063a187ff4392d902da8d3e286843a2f09ac

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - README.md

key-decisions:
  - "The SKIP rule sentence says a missing docker or shellcheck on a Mac always SKIPs, even with CI=true, because need() in test.sh hard-codes that; the plan's wording would have implied CI=true turns them into FAILs on a Mac"
  - "The OS-specific sentence says the two runs report different PASS and SKIP counts, because some Darwin/Linux-only blocks are skipped silently rather than printing SKIP"

requirements-completed: [DOCS-01]

coverage:
  - id: D1
    description: "README Testing documents running test.sh locally; both documented commands report 0 failed"
    requirement: "DOCS-01"
    verification:
      - kind: other
        ref: "Task 1 verify: /bin/bash ./test.sh and the documented ubuntu:24.04 docker run, plus heading/command greps"
        status: pass
    human_judgment: false
  - id: D2
    description: "Status, Options, Uninstalling and How the scripts were engineered describe the milestone's behavior; macOS and Windows stay unverified"
    requirement: "DOCS-01"
    verification:
      - kind: other
        ref: "Task 2 verify loop (prints 'behavior sections ok'); GHIDRA_INSTALL_DIR and changelog counts 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Known limitations and the callout list every accepted gap; phase gate passes in all three runs"
    requirement: "DOCS-01"
    verification:
      - kind: other
        ref: "Task 3 verify loop (prints 'limitations ok', with grep -- fix); phase gate default/bash32/ubuntu all exit 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "Prose reads clearly to a user deciding whether to run an unverified script"
    requirement: "DOCS-01"
    human_judgment: true
    rationale: "Readability and tone are not machine-checkable; the greps only prove the required phrases exist."

duration: 4 min
completed: 2026-10-15
---

# Phase 3 Plan 2: README Sync Summary

**The README now documents how to run `test.sh` locally (a Mac and an `ubuntu:24.04` container, no hosted CI). It also covers every behavior change from this milestone: no-terminal `rea setup` skip, uninstall prompts answered no, Homebrew under `--yes`, staged extraction, JDK 21+ reuse, and failed installs that stop and record nothing. Seven new Known limitations bullets were added. macOS and Windows are still marked "Dry runs and `test.sh` only".**

## Performance

- Duration: about 4 min (2026-10-15T13:46:28Z to 13:50:32Z)
- Tasks: 3
- Files modified: 1 (README.md, +55/-13)

## Task Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 (tracer) Running the tests | d403000 | Document running test.sh locally |
| 2 Behavior sections | eebb7ff | Describe the milestone's fixes in the README |
| 3 Known limitations and phase gate | 7eb5063 | List the milestone's known limitations in the README |

## Documented-command count lines (Task 1)

- `/bin/bash ./test.sh`: `114 passed, 0 failed, 2 skipped`
- `docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh`: `80 passed, 0 failed, 12 skipped`

The tracer gate re-ran the `<verify>` block and it passed before Tasks 2 and 3 started.

## Phase gate (Task 3)

- `./test.sh` (default shell): `114 passed, 0 failed, 2 skipped`
- `/bin/bash ./test.sh` (Bash 3.2): `114 passed, 0 failed, 2 skipped`
- `ubuntu:24.04` container: `80 passed, 0 failed, 12 skipped`
- `exit: default=0 bash32=0 ubuntu=0`, no `FAIL:` lines.

## Task 1 checks

| README sentence | Checked against |
|---|---|
| macOS row: `test.sh` loads functions in a sandboxed home with stubs and checks... | test.sh `sandbox()`, sections TEST-02, TEST-03, JAVA-02/03/04 macOS, FAIL-03, UNIN-01, MAC-01/02 |
| Windows row: `test.sh` dot-sources the script with a stubbed `winget`... | test.sh Windows (pwsh) driver: FAIL-01 Windows, UNIN-01 Windows, JAVA-01/02 Windows Install-Jdk reports |
| Coverage bullets | test.sh TEST-01 lint and parse (shellcheck on both scripts and test.sh, pwsh ParseFile), DRY-01/02 (`--network none`, `find ~` before/after) |
| Output format, exit 1 on failure | test.sh header, `ok/bad/skip`, final `printf` and `[ "$fail" -eq 0 ]` |
| SKIP rule and CI=true | test.sh `need()`: `docker info` (stopped daemon = missing), Darwin:docker/shellcheck always SKIP, otherwise CI=true -> `bad` |

## Task 2 per-sentence code checks

| README sentence | Checked against |
|---|---|
| Status rows (macOS/Windows "Dry runs and `test.sh` only", Linux "before the current round of fixes") | research README Edit Map (7 Linux commits after the container runs); test.sh DRY-01/02 |
| `--yes` on macOS installs Homebrew without waiting for Return, sudo password once when a terminal exists | rea-install-macos.sh `install_homebrew` (`have_tty` -> `run sudo -v`, `env NONINTERACTIVE=1`) |
| No terminal and no `--yes`: macOS and Linux skip `rea setup` with a warning, uninstall prompts answered no | both scripts `register_agents` (warn branch), `confirm` (`have_tty` false -> warn, return 1) |
| Uninstall step 1 warns and carries on (all three platforms) | macOS/Linux `do_uninstall` step 1 `run ... || warn`; Windows `Invoke-Uninstall` try/catch `Warn` |
| Uninstall step 5 keeps items and warns without a terminal unless `--yes` | `confirm` (`assume_yes` returns 0 first; else warns `leaving ITEM in place.`) |
| JDK 21 or newer in `JAVA_HOME`, older one left alone | macOS/Linux `install_jdk` + `jdk_usable`; Windows `Install-Jdk` + `Test-JdkUsable` |
| macOS Ghidra records Homebrew's `openjdk@21` | rea-install-macos.sh `install_ghidra` (`brew_install "$JDK_FORMULA"` when JAVA_HOME is not ours) |
| Staging folder on Linux and Windows | rea-install-linux.sh `unpack`; rea-install-windows.ps1 `Expand-PinnedArchive` |
| macOS keeps its own `JAVA_HOME` in the single block, never copies a user JDK 21+ | rea-install-macos.sh `write_profile` (`jdk_chosen`/`jdk_owned` gating, `remove_profile_block` each run) |
| Linux replaces its own `~/.rea-installer/jdk` if it no longer runs | rea-install-linux.sh `install_jdk` (`! jdk_usable "$STATE_DIR/jdk"` -> `rm -rf`, refetch) |
| Windows user `JAVA_HOME` from `java` on `PATH`, replaced only when no `java.exe` | rea-install-windows.ps1 `Install-Jdk` (`Get-Command java`, `$gone`/`$replace`), `Set-UserEnv -Replace` |
| Failed required package / brew install stops and is not recorded | rea-install-linux.sh `pkg_install ... || die` (step 1), `pkg_install` returns before `record`; macOS `brew_install` returns 1 before `record` under errexit |
| `--yes` Homebrew failure stops with sudo hint, records nothing | rea-install-macos.sh `install_homebrew` (`|| die "$hint"` before `record "homebrew"`) |
| Dry run only prints; container check confirms home unchanged | `run`/`record` dry-run guards; test.sh DRY-01/02 |

## Task 3 per-bullet code checks

| Bullet | Checked against | Wording adjusted? |
|---|---|---|
| Callout: unattended macOS install | 03-01-SUMMARY D4 (real-Mac NONINTERACTIVE behavior unverified, VERI-01) | Added "including Homebrew's own installer running non-interactively" |
| Callout: `JAVA_HOME` the script derives from Temurin | rea-install-windows.ps1 `Install-Jdk` (derived from `java` on PATH, not the MSI) | No |
| Unattended macOS install | macOS `do_install` step 1 (`die "finish the Command Line Tools installer dialog..."`), `install_homebrew` (sudo -v only with a terminal), `register_agents`, `confirm` | No (split into sentences) |
| Dry run without Node.js | macOS step 8 `rea_bin="$(npm prefix --global)/bin/rea"`, step 3 `PATH="$(brew --prefix)/bin:$PATH"`; Windows `Join-Path (npm prefix --global) 'rea.cmd'` | No |
| Linux pinned-download layout | rea-install-linux.sh `unpack` (`src="$staging"` moved whole when `$staging/$2` is missing); `install_jdk` inner-folder handling | No |
| Linux Rizin and Wakaru folders | `unpack` returns `$target` when the folder exists; `rizin-0.9.1`, `wakaru-1.14.0` call sites | No |
| Partial package installs | Linux `pkg_install` (`|| return 1` before `record`); macOS `brew_install` (`return 1` before `record`) | No |
| Windows `JAVA_HOME` | `Install-Jdk` (`$replace` false when java.exe exists, session set first), `Set-UserEnv` (warns and returns for an existing value), `Invoke-Uninstall` `env:` arm deletes by name | No |
| JDK check | `jdk_usable` / `Test-JdkUsable` read `java -version` only (02 disposition WR-06) | No |

## Deviations from Plan

**1. [Rule 3 - Blocking] Task 3 verify loop needed `grep -qF --`**
- Found during: Task 3 verify.
- Issue: patterns such as `- **Unattended macOS install:**` start with `-`, so `grep -qF "$s"` reads them as options (this shell's grep is ugrep; GNU and BSD grep behave the same way). The loop printed `missing: - **Unattended macOS install:**` even though the text is present.
- Fix: re-ran the same loop with `grep -qF -- "$s"`. It prints `limitations ok`. No README change.
- Commit: none (verify command only).

**2. [Rule 1 - Accuracy] SKIP-rule and SKIP-count wording matched to test.sh**
- Found during: Task 1.
- Issue: the plan's sentence order suggested `CI=true` turns every missing tool into a FAIL. `need()` always SKIPs a missing docker or shellcheck on Darwin. Also, some OS-specific blocks don't print SKIP, so the two runs differ in PASS counts as well.
- Fix: "On a Mac, a missing `docker` or `shellcheck` is expected and always SKIPs. Otherwise, with `CI=true` set, a missing tool is a FAIL instead." and "different PASS and SKIP counts". The required phrase `CI=true` is present.
- Commit: d403000.

**Total deviations:** 2 (1 verify-command fix, 1 wording accuracy fix). **Impact:** none on scope; the README matches the code more closely.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None. T-03-08 and T-03-10 are mitigated: Status keeps "no real install has been run yet" and "never run on real Windows", the Linux row says its full runs came before the current round of fixes, the callout lists the unattended macOS install, and `GitHub Actions` appears 0 times. T-03-09 is accepted: the text states the passwordless-sudo requirement factually and recommends `sudo -v` or installing Homebrew first.

## Next Phase Readiness

Phase complete, ready for `/gsd-verify-work 3`. Still open: VERI-01 (a real-Mac check of Homebrew's non-interactive install, and whether REA finds Homebrew's Ghidra without the Ghidra install-folder setting). The README deliberately doesn't state it.

## Self-Check: PASSED

- README.md exists and is modified in d403000, eebb7ff, 7eb5063 (all ancestors of HEAD).
- Acceptance: `### Running the tests` appears once (line 203), before the callout; `GitHub Actions` 0; `GHIDRA_INSTALL_DIR` 0; changelog/what's new 0; `Temurin setting` 0; Known limitations top-level bullets 16; Uninstalling steps 1-6 in order.
