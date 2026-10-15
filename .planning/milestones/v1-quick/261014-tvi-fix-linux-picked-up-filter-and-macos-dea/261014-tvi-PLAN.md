---
phase: quick-261014-tvi
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - rea-install-linux.sh
  - rea-install-macos.sh
  - test.sh
autonomous: true
requirements: [JAVA-02, JAVA-04]

estimate:
  tokens: 40000
  raw_tokens: 40000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "When the Linux script's own JDK does not run, the error shows java -version output with no `Picked up` line in either real launcher format (`Picked up ...` or `NOTE: Picked up JDK_JAVA_OPTIONS: ...`), so a proxy password in JDK_JAVA_OPTIONS is never printed (gap 1, CR-01)"
    - "On a macOS `--no-ghidra` rerun where the script's own openjdk@21 no longer runs and nothing else is queued, the old rea-installer block that exported its JAVA_HOME is removed from the shell profile (gap 2, WR-01)"
    - "In that same run, a session JAVA_HOME equal to the script's dead path is unset, so `rea setup` does not copy it into agent registrations"
    - "The warning for a dead owned JDK no longer tells the user to install Ghidra (IN-01)"
    - "The full suite passes on this Mac (Bash 3.2) and in a local ubuntu:24.04 container, and shellcheck is clean"
  artifacts:
    - path: "rea-install-linux.sh"
      provides: "install_jdk error filter that drops both Picked up formats"
      contains: "grep -Ev '^(NOTE: )?Picked up '"
    - path: "rea-install-macos.sh"
      provides: "write_profile that always clears the old block and unsets a dead session JAVA_HOME"
    - path: "test.sh"
      provides: "Real-format Picked up fixture and a Darwin-guarded dead-owned-JDK block test with nothing queued"
  key_links:
    - from: "rea-install-macos.sh write_profile"
      to: "remove_profile_block"
      via: "called on every run, not only when profile_exports is non-empty"
    - from: "rea-install-macos.sh write_profile"
      to: "rea setup (step 9 of do_install)"
      via: "session JAVA_HOME, unset when it equals the dead owned path"
---

<objective>
Close the two remaining Phase 02 verification gaps with the smallest change that fixes each, red test first.

1. Linux: the "JDK does not run" error filter misses the real launcher line `NOTE: Picked up JDK_JAVA_OPTIONS: ...`, so a proxy password can be printed (02-VERIFICATION gap 1, 02-REVIEW CR-01).
2. macOS: on a plain `--no-ghidra` rerun with a dead owned JDK, `write_profile` rewrites the block only when `profile_exports` is non-empty. The dead JAVA_HOME stays exported while the warning says it was "left out", and the session JAVA_HOME still reaches `rea setup` (02-VERIFICATION gap 2, 02-REVIEW WR-01).

Purpose: Core value. A failure must never leak a credential, and a rerun must not leave a dead setting in place while saying it removed it.
Output: Fixed `rea-install-linux.sh` and `rea-install-macos.sh`, and two red-then-green cases in `test.sh`.

Out of scope (user decision): do not touch `rea-install-windows.ps1` (the Join-Path drive issue and IN-02 stay open). Do not start a new review or verify cycle. Do not edit `.planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md`.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@.planning/phases/02-consistent-java-handling/02-VERIFICATION.md

Key facts (already read by the planner, so do not re-derive them):

- `rea-install-linux.sh` `install_jdk`, near line 381, has the die message `the JDK at $STATE_DIR/jdk does not run; java -version printed: $(... 2>&1 | grep -v '^Picked up' | head -3)`. The comment above it cites T-02-02.
- Real JDK formats: `JAVA_TOOL_OPTIONS` and `_JAVA_OPTIONS` print `Picked up NAME: ...`. The java launcher prints `NOTE: Picked up JDK_JAVA_OPTIONS: ...` for JDK_JAVA_OPTIONS.
- `test.sh`, near line 351, is the case "JAVA-02 Linux install_jdk hides Picked up lines when its JDK does not run". Its `mkjdk` fixture currently echoes three `Picked up` lines with no `NOTE: ` prefix, and puts `hunter2` in the JAVA_TOOL_OPTIONS line. Its assertions already require `! grep -qF 'Picked up'` and `! grep -qF hunter2` on `$work/out`.
- `rea-install-macos.sh` `write_profile`, lines ~222-261. Branch a (`[ "$jdk_chosen" = false ] && ! jdk_usable "$ours"`) warns `... does not run; JAVA_HOME is left out of $(profile_file). Rerun without --no-ghidra to reinstall it.` and sets `ours=""`. The final `if ((${#profile_exports[@]} > 0)); then` wraps `log "Adding REA settings to $profile"`, `remove_profile_block "$profile"`, the dry-run print or the append, and `record "profile:$profile"`.
- `remove_profile_block` returns 0 when the file or block is absent, and routes its `sed -i ''` through `run`, so dry-run is honored.
- `test.sh` macOS JDK cases sit after `ours="$work/home/brew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"` (~line 380), with the brew stub `case "$1" in --prefix) echo "$HOME/brew/opt/$2" ;; list) exit 0 ;; *) exit 1 ;; esac` active. A later line `stub brew 'exit 1'` (~507) replaces it, so a new macOS case must go before that line. The WR-03 case "JAVA-04 macOS --no-ghidra rerun leaves out an owned JDK that does not run, with a warning" (~484-497) greps for `'Rerun without --no-ghidra'`. Darwin-only cases use the `if [ "$(uname -s)" = Darwin ]; then ... else skip "$n (macOS only)"; fi` pattern (see the case "JAVA-04 macOS --no-ghidra rerun keeps its own JAVA_HOME owned only through the old block", ~453). Helpers: `fresh_home`, `mkjdk`, `sandbox SCRIPT 'code'` (then read `$rc`; output in `$work/out`), `show`, `ok`, `bad`, `skip`. Profile under the sandbox is `$work/home/.bash_profile` (SHELL=/bin/bash).
- Baselines: `/bin/bash ./test.sh` on this Mac gives `96 passed, 0 failed, 2 skipped`. `./test.sh` in a local docker ubuntu:24.04 container gives `63 passed, 0 failed, 11 skipped`. Testing is local only. There is no GitHub Actions.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Linux Picked up filter matches the real NOTE: launcher line</name>
  <files>test.sh, rea-install-linux.sh</files>
  <behavior>
    - The case "JAVA-02 Linux install_jdk hides Picked up lines when its JDK does not run" runs a stub JDK that prints the real formats on stderr: `Picked up JAVA_TOOL_OPTIONS: -Xmx1g`, `Picked up _JAVA_OPTIONS: -Xmx1g`, `NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttp.proxyPassword=hunter2`, then `Error: Could not create the Java Virtual Machine.` and exit 1.
    - Against the current filter it FAILS, because the NOTE line, and hunter2 with it, reaches the die message.
    - After the fix it PASSES: the error still shows the `Could not create the Java Virtual Machine` line, and neither `Picked up` nor `hunter2` appears in the output.
  </behavior>
  <action>
RED: in `test.sh`, edit only the `mkjdk` fixture of the case named above (~line 351). Use the real formats listed in behavior. The password moves into the `NOTE: Picked up JDK_JAVA_OPTIONS:` line and leaves the other two lines. Keep the assertions and the case name unchanged. Run the suite and confirm this case prints `FAIL:`. Find it by name, because it is not Darwin-guarded and runs on the Mac too. If it does not fail, stop: the fixture does not reproduce CR-01. Commit the red test on its own: `Use the real NOTE: Picked up line in the Linux JDK error test`.

GREEN: in `rea-install-linux.sh` `install_jdk` (~line 381), change only the filter inside the die message's command substitution to `grep -Ev '^(NOTE: )?Picked up '`. Leave the rest of the pipeline as it is: `2>&1`, `| head -3`. Extend the comment above it to say the launcher prefixes the JDK_JAVA_OPTIONS line with `NOTE: `, which is why the prefix is optional. Keep the T-02-02 reference. Rerun and confirm the case PASSES. Commit: `Drop NOTE: Picked up lines from the Linux JDK error`.
  </action>
  <verify>
    <automated>/bin/bash ./test.sh 2>&1 | grep -E 'hides Picked up lines|^[0-9]+ passed'</automated>
  </verify>
  <done>Before the GREEN edit, the named case printed FAIL. After it, the case prints PASS. `grep -cF "grep -Ev '^(NOTE: )?Picked up '" rea-install-linux.sh` prints 1. The test.sh fixture contains `NOTE: Picked up JDK_JAVA_OPTIONS: -Dhttp.proxyPassword=hunter2`.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: macOS dead owned JDK is removed from the profile block and the session on a plain --no-ghidra rerun</name>
  <files>test.sh, rea-install-macos.sh</files>
  <behavior>
    - New Darwin-guarded case `n="JAVA-04 macOS --no-ghidra rerun removes a dead owned JAVA_HOME when nothing else is queued"`. For each mode in `'export JAVA_HOME="$ours"'` and `'unset JAVA_HOME'`: fresh_home; no `mkjdk "$ours"`, so ours is dead; `.bash_profile` holds a user line `# user line`, then `# >>> rea-installer >>>`, `export JAVA_HOME="$ours"`, `# <<< rea-installer <<<`; sandbox runs `$mode; write_profile; printf 'JAVA_HOME=%s\n' "${JAVA_HOME:-}"` with NO `profile_exports+=` (do not queue REA_TEST=1).
    - Expected per mode: rc 0; `$work/out` contains `does not run`; `$work/out` has the exact line `JAVA_HOME=` (session value empty); `.bash_profile` has no `^export JAVA_HOME=` line and no `# >>> rea-installer >>>` line; `# user line` is still present.
    - Against the current code it FAILS: the block is not rewritten when nothing is queued, so the export line stays, and in the export mode the session value stays set.
    - Non-Darwin: `skip "$n (macOS only)"`, because the rewrite uses BSD `sed -i ''`.
  </behavior>
  <action>
RED: add the case described in behavior to `test.sh`, directly after the WR-03 case "JAVA-04 macOS --no-ghidra rerun leaves out an owned JDK that does not run, with a warning", and before the later `stub brew 'exit 1'` line. Follow the existing loop style: `all_ok=true`, a `for mode in ...` loop, `show`, then the profile on failure with `sed 's/^/    /'`, and a final ok or bad. Add a `# shellcheck disable=SC2016  # expanded inside the sandbox` comment where single-quoted `$ours` is used, as nearby cases do. Precede the case with a one-line comment that cites gap 2 and WR-01: nothing else queued is the default plain rerun. Run `/bin/bash ./test.sh` and confirm the new case prints `FAIL:`. If it passes, stop and report: the test does not reproduce the gap. Commit the red test on its own: `Test a macOS rerun that leaves a dead JAVA_HOME in the profile`.

GREEN, in `rea-install-macos.sh` `write_profile`, Bash 3.2 only:
(a) In branch a, after the existing warn line, unset the session JAVA_HOME when it equals ours. Write it as an `if [ "${JAVA_HOME:-}" = "$ours" ]; then unset JAVA_HOME; fi` statement, so set -e semantics stay obvious, and put it before `ours=""`. Rationale for a comment: `rea setup` in step 9 copies the session JAVA_HOME into agent registrations.
(b) Delete the `profile_exports` length condition from around `remove_profile_block`, which is the user's preferred fix that deletes a condition. Compute `profile`, call `remove_profile_block "$profile"` on every run, and keep only the log, the dry-run print or the append, and `record "profile:$profile"` inside `if ((${#profile_exports[@]} > 0))`. The block then always reflects this run: it is rewritten when something is queued and removed when nothing is. Update the write_profile header comment to say this in one line.
(c) IN-01 reword, a one-line script change: replace `Rerun without --no-ghidra to reinstall it.` in the branch a warning with `Reinstall $JDK_FORMULA with Homebrew to repair it.` In the WR-03 case of `test.sh`, change its grep literal `'Rerun without --no-ghidra'` to `'Reinstall openjdk@21 with Homebrew'`. That is the only change to that case.

Do not touch install_jdk, jdk_owned, branches b, c and d, or the Windows script. Rerun the suite: the new case and every existing macOS JDK case must PASS. Commit: `Remove a dead owned JAVA_HOME from the macOS profile and session`.

Known consequence, accepted with the user's preferred fix: a rerun that queues nothing now removes an old block whose lines came from an earlier `--with-extras` run (REA_OBJDUMP_COMMAND, REA_WABT_BIN_DIRECTORY). This matches what already happens whenever JAVA_HOME is queued, since the rewrite drops unqueued lines. Mention it in the SUMMARY. Do not add code to preserve those lines.
  </action>
  <verify>
    <automated>/bin/bash ./test.sh 2>&1 | grep -E 'removes a dead owned JAVA_HOME|leaves out an owned JDK that does not run|^[0-9]+ passed'</automated>
  </verify>
  <done>Before the GREEN edit, the new case printed FAIL. After it, the new case and the WR-03 case print PASS. `grep -c 'Rerun without --no-ghidra' rea-install-macos.sh test.sh` prints 0 for both files. `bash -n` passes under /bin/bash 3.2.</done>
</task>

<task type="auto">
  <name>Task 3: Full local verification on the Mac, in the container and with shellcheck</name>
  <files>test.sh</files>
  <action>
Run only checks; no code change is expected. If something fails, fix it in the task that owns the code and re-commit.
1. On this Mac: `/bin/bash ./test.sh`. Expect `97 passed, 0 failed, 2 skipped`: the baseline was 96/0/2, plus the new Darwin case.
2. In a local container: `docker run --rm -v "$PWD":/src -w /src ubuntu:24.04 ./test.sh`, or the same command used for the 63/0/11 baseline. Expect `63 passed, 0 failed, 12 skipped`: the new case is skipped as macOS only.
3. `shellcheck rea-install-linux.sh rea-install-macos.sh test.sh` exits 0. If shellcheck is missing on the Mac, the container run covers it only when shellcheck is installed there. Otherwise run `docker run --rm -v "$PWD":/mnt koalaman/shellcheck:stable rea-install-linux.sh rea-install-macos.sh test.sh`.
Record all three results verbatim in the SUMMARY. If Docker is not running, say so plainly in the SUMMARY. Do not claim the container result.
  </action>
  <verify>
    <automated>/bin/bash ./test.sh 2>&1 | tail -1 && shellcheck rea-install-linux.sh rea-install-macos.sh test.sh && echo shellcheck-ok</automated>
  </verify>
  <done>Mac: 97 passed, 0 failed, 2 skipped. Container: 63 passed, 0 failed, 12 skipped. shellcheck exits 0 on all three files. `git diff --stat HEAD~4 -- rea-install-windows.ps1 .planning/phases/02-consistent-java-handling/02-REVIEW-DISPOSITION.md` is empty.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| JDK stderr to terminal | `java -version` output includes env-derived `Picked up` lines that may hold proxy credentials |
| Profile block to future shells and rea setup | Values written to the shell profile and the session reach agent registrations |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261014-01 | Information disclosure | rea-install-linux.sh install_jdk die message | high | mitigate | Use the `grep -Ev '^(NOTE: )?Picked up '` filter, tested with the real NOTE: line that carries the secret (Task 1) |
| T-261014-02 | Tampering (integrity of user env) | rea-install-macos.sh write_profile | medium | mitigate | Always clear the old block, and unset a session JAVA_HOME equal to the dead owned path, so `rea setup` never registers a dead JDK (Task 2) |
| T-261014-SC | Tampering | npm/pip/cargo installs | high | accept | No packages installed by this plan |
</threat_model>

<verification>
- Each fix was preceded by a commit whose new or changed test failed against the unfixed code.
- `/bin/bash ./test.sh` on the Mac reports 97 passed, 0 failed, 2 skipped.
- The ubuntu:24.04 container reports 63 passed, 0 failed, 12 skipped.
- shellcheck is clean on rea-install-linux.sh, rea-install-macos.sh and test.sh.
- rea-install-windows.ps1 and 02-REVIEW-DISPOSITION.md are untouched.
</verification>

<success_criteria>
- Gap 1 closed: no `Picked up` line in either real format, and no credential, appears in the Linux JDK error.
- Gap 2 closed: a plain macOS `--no-ghidra` rerun with a dead owned JDK leaves no JAVA_HOME export in the profile and no dead JAVA_HOME in the session.
- IN-01: the warning no longer advises installing Ghidra.
</success_criteria>

<output>
Create `.planning/quick/261014-tvi-fix-linux-picked-up-filter-and-macos-dea/261014-tvi-SUMMARY.md` when done.
</output>
