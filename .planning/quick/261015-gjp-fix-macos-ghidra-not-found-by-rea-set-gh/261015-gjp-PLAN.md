---
phase: quick-261015-gjp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - rea-install-macos.sh
  - test.sh
  - README.md
  - .planning/STATE.md
autonomous: true
requirements: [GHID-01]

estimate:
  tokens: 45000
  raw_tokens: 45000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "After a macOS install that installs (or finds) Homebrew's ghidra, GHIDRA_INSTALL_DIR is exported in the run before rea setup (step 9), set to \"$(brew --prefix ghidra)/libexec\", so rea setup copies it into agent registrations"
    - "The same run writes exactly one `export GHIDRA_INSTALL_DIR=\"<brew prefix>/opt/ghidra/libexec\"` line inside the marked profile block"
    - "A rerun (ghidraRun on PATH, caller's GHIDRA_INSTALL_DIR equal to the Homebrew path or unset) still writes exactly one GHIDRA_INSTALL_DIR line; the rebuilt block never silently drops it"
    - "A GHIDRA_INSTALL_DIR the user set to another folder is left unchanged in the session and is not written to the block"
    - "--no-ghidra on a machine where the ledger has no brew:ghidra writes no GHIDRA_INSTALL_DIR; a --no-ghidra rerun whose ledger records brew:ghidra keeps the line (same rerun trap as JAVA_HOME, WR-03)"
    - "A dry run that plans `brew install ghidra` prints the GHIDRA_INSTALL_DIR line in the planned block and creates no profile file and no ledger"
    - "A real run where Homebrew's ghidra was installed but its libexec has no ghidraRun stops with an error instead of writing a dead path"
    - "/bin/bash ./test.sh reports 0 failed; shellcheck is clean"
  artifacts:
    - path: rea-install-macos.sh
      provides: "ghidra_home helper, ghidra_brewed flag, ghidra_setting function called from do_install step 4"
    - path: test.sh
      provides: "GHID-01 macOS checks: fresh install, rerun, user value elsewhere, --no-ghidra fresh and ledger rerun, dry run"
    - path: README.md
      provides: "Settings REA reads block shows GHIDRA_INSTALL_DIR and says macOS sets it"
    - path: .planning/STATE.md
      provides: "Stale open Ghidra question removed from Blockers"
  key_links:
    - from: "ghidra_setting"
      to: "write_profile"
      via: "profile_exports+=(\"export GHIDRA_INSTALL_DIR=...\") queued before step 7 write_profile"
      pattern: "GHIDRA_INSTALL_DIR"
    - from: "ghidra_setting"
      to: "register_agents"
      via: "export GHIDRA_INSTALL_DIR in the installer's own process before step 9"
      pattern: "export GHIDRA_INSTALL_DIR"
    - from: "install_ghidra"
      to: "ghidra_setting"
      via: "ghidra_brewed=true set in install_ghidra's install branch, read by ghidra_setting (dry run records nothing, so the ledger alone cannot tell)"
      pattern: "ghidra_brewed"
---

<objective>
Make REA find Homebrew's Ghidra on macOS. `rea-install-macos.sh` installs Homebrew `ghidra` but never sets `GHIDRA_INSTALL_DIR`, the only way REA locates Ghidra (verified in a macOS 27 VM: `rea doctor` reports `GHIDRA_INSTALL_DIR is not set` after a real install, and healthy with `GHIDRA_INSTALL_DIR=/opt/homebrew/opt/ghidra/libexec`). The Linux and Windows scripts already set it.

Purpose: core value. A default macOS install currently leaves REA's free native-analysis engine silently unusable.
Output: `ghidra_home` + `ghidra_setting` in `rea-install-macos.sh`, GHID-01 checks in `test.sh`, README "Settings REA reads" update, stale STATE.md blocker removed.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@rea-install-macos.sh
@test.sh

Key code facts (rea-install-macos.sh, line numbers approximate):
- Globals at lines 27-34; `brew_installed` (line 34) is the precedent for a "this run did X; a dry run records nothing, so the ledger alone cannot tell" flag.
- `jdk_home()` lines 146-164: uses `brew --prefix FORMULA` (prints the opt path even before install), with a dry-run-without-brew fallback to `/opt/homebrew/opt/...` on arm64 or `/usr/local/opt/...` otherwise, and `die` on a failed `brew --prefix` in a real run. Its comment explains callers must use a plain assignment so set -e stops the run on die.
- `install_ghidra()` lines 215-231: "already available" branch when `ghidraRun` is on PATH or `GHIDRA_INSTALL_DIR` is non-empty; otherwise installs the JDK and `brew_install ghidra`.
- `write_profile()` lines 261-310: removes the whole marked block and rewrites it from `profile_exports` on every run, so any setting not re-queued on a rerun is dropped (the JAVA_HOME rerun trap, JAVA-04/WR-03).
- `do_install()` step 4 (line 351-354) calls `install_ghidra` only when `with_ghidra=true`; step 7 `write_profile`; step 9 `register_agents` (rea setup copies the session's GHIDRA_INSTALL_DIR, JAVA_HOME and REA_JADX_MCP_JAR into agent registrations).

Key test facts (test.sh):
- `sandbox SCRIPT CODE` runs CODE in a subshell with the script sourced, HOME=$work/home, PATH=$STUBS first, SHELL=/bin/bash (so the profile is `$work/home/.bash_profile`). Call it as a plain statement and read `$rc` after.
- `stub NAME BODY` writes a stub on the sandbox PATH; `mkjdk DIR BODY` writes a stub JDK; `fresh_home` wipes the temp HOME; `show` prints the last sandbox output.
- `ours="$work/home/brew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"` is set at line ~380 and stays defined.
- The JAVA macOS section stubs `brew` and `ghidraRun` and removes both at line ~562. Any check that rewrites an existing block runs `remove_profile_block` (BSD `sed -i ''`), so it must be Darwin-only with a `skip "... (macOS only)"` elsewhere; checks with no pre-existing block run on every OS.
- Never call `do_install`, `do_uninstall` or `load_brew` in a sandbox: the real brew would come first on PATH.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: End-to-end fresh macOS install exports GHIDRA_INSTALL_DIR and writes it to the profile block</name>
  <files>test.sh, rea-install-macos.sh</files>
  <read_first>rea-install-macos.sh (jdk_home, install_ghidra, write_profile, do_install step 4), test.sh lines 373-573 (macOS JAVA section style, stubs, ours)</read_first>
  <behavior>
    - Fresh real run (dry_run=false), no ghidraRun on PATH, GHIDRA_INSTALL_DIR unset, Homebrew ghidra keg present at the stub prefix: after install_ghidra, ghidra_setting and write_profile, the session prints GHIDRA_INSTALL_DIR equal to the keg's libexec, and `.bash_profile` holds exactly one `export GHIDRA_INSTALL_DIR="<keg>/libexec"` line inside the block.
  </behavior>
  <action>
RED first (GHID-01). In test.sh, add a new section banner `# ---------------------------------------------------------------- GHID-01 macOS GHIDRA_INSTALL_DIR` immediately after the "JAVA-02 macOS dry run without brew plans the default Homebrew JDK path" check (before the MAC-01/02 section). At the top of the section:
- define `gdir="$work/home/brew/opt/ghidra/libexec"` (fresh_home wipes it, so each check recreates it as needed with a helper such as `mkghidra` that does mkdir -p "$gdir" and writes an executable `$gdir/ghidraRun` stub, matching the verified real layout);
- stub brew so `--prefix NAME` echoes `$HOME/brew/opt/NAME`, `list` succeeds for any argument list that does not mention ghidra and, when it mentions ghidra, succeeds only if `$HOME/brew/opt/ghidra/libexec/ghidraRun` is executable (so a present keg reads as "already installed" and an absent one makes brew_install plan `brew install ghidra`), and anything else exits 1. Use `# shellcheck disable=SC2016  # expanded by the stub` like the existing stubs.
Every GHID-01 sandbox begins its code with `PATH="$STUBS:/usr/bin:/bin";` (as the MAC-02 checks do): the sandbox PATH otherwise still contains the host PATH, and a dev Mac with Homebrew ghidra has a real ghidraRun that would push install_ghidra into its already-available branch.
Add the first check, named "GHID-01 macOS fresh install exports GHIDRA_INSTALL_DIR and writes it to the profile block": fresh_home; mkjdk "$ours" with the 21.0.5 version line (install_jdk's real-run check needs a JDK that runs); mkghidra; sandbox the macOS script with `PATH="$STUBS:/usr/bin:/bin"; unset JAVA_HOME GHIDRA_INSTALL_DIR; install_ghidra; ghidra_setting; write_profile; printf "GHIDRA_INSTALL_DIR=%s\n" "$GHIDRA_INSTALL_DIR"` (this takes install_ghidra's install branch, with brew_install reporting the present keg as already installed). Pass when rc is 0, the output has the exact line `GHIDRA_INSTALL_DIR=$gdir`, and `grep -cxF "export GHIDRA_INSTALL_DIR=\"$gdir\"" .bash_profile` is 1. On failure call show and print the profile indented, as the JAVA checks do. Run `/bin/bash ./test.sh` and confirm this check FAILS (ghidra_setting does not exist yet).

GREEN. In rea-install-macos.sh:
1. Globals: add `ghidra_brewed=false` with a trailing comment in the style of `brew_installed`: set when install_ghidra installs Homebrew's ghidra this run; a dry run records nothing, so the ledger alone cannot tell.
2. Add `ghidra_home()` right after `jdk_home()` (do not refactor jdk_home; CLAUDE.md asks for three real examples before abstracting). It prints `<prefix>/libexec` where prefix is `brew --prefix ghidra`. Mirror jdk_home's shape: when brew is on PATH use a plain assignment and `die "could not locate Homebrew's ghidra (brew --prefix failed)."` on failure or an empty result; when brew is absent and dry_run=true, assume `/opt/homebrew/opt/ghidra` on arm64 (`uname -m`) or `/usr/local/opt/ghidra` otherwise (no extra warning: jdk_home already prints the assumed-prefix warning in that run); when brew is absent in a real run, die. One-line rationale comment: Homebrew's ghidra formula keeps ghidraRun and Ghidra/application.properties under the opt path's libexec, which is what REA expects in GHIDRA_INSTALL_DIR.
3. In `install_ghidra()`'s install branch, after `brew_install ghidra`: set `ghidra_brewed=true`; then declare `local dir` on its own line, assign `dir="$(ghidra_home)"` as a plain assignment, and in a real run (`[ "$dry_run" = true ] ||`) require `[ -x "$dir/ghidraRun" ]` or `die "Homebrew ghidra at $dir has no ghidraRun."` (fail loudly rather than write a dead path, mirroring install_jdk's runs-check). Leave the already-available branch unchanged.
4. Add `ghidra_setting()` after `install_ghidra()`. Comment the why: REA finds Ghidra only through GHIDRA_INSTALL_DIR; rea setup in step 9 copies the session value into agent registrations; write_profile rebuilds the block every run, so this runs on every install, reruns included. Logic, in order:
   - return 0 unless with_ghidra is true (Task 2 widens this gate for the ledger case);
   - when ghidra_brewed is false and brew is not on PATH, return 0 (no Homebrew, so no Homebrew ghidra to point at);
   - `local dir` on its own line, then the plain assignment `dir="$(ghidra_home)"`;
   - unless ghidra_brewed is true (a dry run that planned the install), return 0 when `$dir/ghidraRun` is not executable (covers a ghidraRun on PATH from a non-Homebrew Ghidra);
   - return 0 when GHIDRA_INSTALL_DIR is non-empty and differs from dir (the user's own setting: left alone, not written);
   - otherwise `export GHIDRA_INSTALL_DIR="$dir"` and `profile_exports+=("export GHIDRA_INSTALL_DIR=\"$dir\"")`.
   This also covers a user's own pre-existing Homebrew ghidra: setting REA's variable does not modify their tool. Use Bash 3.2 syntax only, quote every expansion, no new `|| true` on required steps.
5. In `do_install()` step 4, call `ghidra_setting` right after the `if [ "$with_ghidra" = true ]; then install_ghidra; fi` block (outside it, so Task 2's ledger case can reach it), before step 5.
Rerun `/bin/bash ./test.sh`; the new check and every existing check must pass.
  </action>
  <verify>
    <automated>bash -o pipefail -c '/bin/bash ./test.sh 2>&1 | grep -E "^FAIL|GHID-01|passed,"'</automated>
  </verify>
  <done>"GHID-01 macOS fresh install exports GHIDRA_INSTALL_DIR and writes it to the profile block" was seen failing before the script change and passes after; test.sh's last line reads "N passed, 0 failed, M skipped"; `shellcheck rea-install-macos.sh test.sh` exits 0.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Rerun, user value, --no-ghidra and dry-run behaviour of GHIDRA_INSTALL_DIR</name>
  <files>test.sh, rea-install-macos.sh</files>
  <read_first>test.sh GHID-01 section from Task 1; rea-install-macos.sh ghidra_setting</read_first>
  <behavior>
    - Rerun (Darwin only): block already holds the GHIDRA_INSTALL_DIR line, ghidraRun stub on PATH, run once with the shell's GHIDRA_INSTALL_DIR equal to gdir and once with it unset: each leaves exactly one BEGIN marker and exactly one GHIDRA_INSTALL_DIR line equal to gdir.
    - User value elsewhere: GHIDRA_INSTALL_DIR="$work/user-ghidra" with the Homebrew keg also present: session value unchanged, no GHIDRA_INSTALL_DIR line in the profile (REA_TEST=1 queued so a block is written).
    - --no-ghidra fresh: with_ghidra=false, keg present, no ledger: no GHIDRA_INSTALL_DIR line (REA_TEST=1 queued).
    - --no-ghidra rerun with ledger `brew:ghidra`, keg present, GHIDRA_INSTALL_DIR unset: exactly one GHIDRA_INSTALL_DIR line equal to gdir.
    - Dry run: no keg, no ghidraRun, GHIDRA_INSTALL_DIR unset, dry_run=true: output shows `  $ brew install ghidra` and the planned block line `    export GHIDRA_INSTALL_DIR="$gdir"`; no `.bash_profile` and no ledger file are created.
  </behavior>
  <action>
In test.sh's GHID-01 section, after Task 1's check, add five checks in the existing style (each starts with fresh_home and sets JAVA_HOME and GHIDRA_INSTALL_DIR explicitly, because the host may export its own; use a `n="..."` name variable, show on failure, `# shellcheck disable=SC2016  # expanded inside the sandbox` above sandbox lines with single-quoted code):
1. "GHID-01 macOS rerun keeps exactly one GHIDRA_INSTALL_DIR line whether or not the shell has it set" — Darwin only (it rewrites an existing block with BSD sed -i ''), else `skip "$n (macOS only)"`. Inside the Darwin branch, `stub ghidraRun 'exit 0'` so install_ghidra takes its already-available branch, as on a real rerun where Homebrew linked ghidraRun into its bin, and `rm -f "$STUBS/ghidraRun"` right after this check's loop: checks 3-5 need no ghidraRun on PATH (check 5's dry run must take the install branch). Loop over the two modes `export GHIDRA_INSTALL_DIR="$gdir"` and `unset GHIDRA_INSTALL_DIR`, like the JAVA-04 mode loops: fresh_home; mkghidra; seed `.bash_profile` with BEGIN marker, the gdir export line, END marker; sandbox `unset JAVA_HOME; <mode>; install_ghidra; ghidra_setting; write_profile`; require rc 0, `grep -cx '# >>> rea-installer >>>'` = 1, `grep -c '^export GHIDRA_INSTALL_DIR='` = 1, and the exact gdir line present.
2. "GHID-01 macOS leaves a user GHIDRA_INSTALL_DIR elsewhere alone and unwritten" — mkghidra (so only the user-value guard can explain the outcome); sandbox `unset JAVA_HOME; export GHIDRA_INSTALL_DIR="$work/user-ghidra"; install_ghidra; ghidra_setting; profile_exports+=("export REA_TEST=1"); write_profile; printf "GHIDRA_INSTALL_DIR=%s\n" "$GHIDRA_INSTALL_DIR"`; require rc 0, output line `GHIDRA_INSTALL_DIR=$work/user-ghidra`, `export REA_TEST=1` in the profile, and zero `^export GHIDRA_INSTALL_DIR=` lines in the profile.
3. "GHID-01 macOS --no-ghidra writes no GHIDRA_INSTALL_DIR for a Ghidra it did not install" — mkghidra; no ledger; sandbox `with_ghidra=false; unset JAVA_HOME GHIDRA_INSTALL_DIR; ghidra_setting; profile_exports+=("export REA_TEST=1"); write_profile`; require rc 0, REA_TEST line present, zero GHIDRA_INSTALL_DIR lines.
4. "GHID-01 macOS --no-ghidra rerun keeps GHIDRA_INSTALL_DIR for the Ghidra its ledger records" — mkghidra; write `brew:ghidra` to `$work/home/.rea-installer/installed`; sandbox `with_ghidra=false; unset JAVA_HOME GHIDRA_INSTALL_DIR; ghidra_setting; write_profile`; require rc 0 and exactly one exact gdir export line. No pre-existing block, so it runs on every OS.
5. "GHID-01 macOS dry run plans the GHIDRA_INSTALL_DIR line and writes nothing" — mkjdk "$ours" (version 21.0.5) but no mkghidra; sandbox `dry_run=true; unset JAVA_HOME GHIDRA_INSTALL_DIR; install_ghidra; ghidra_setting; write_profile`; require rc 0, the exact output line `  $ brew install ghidra`, the exact output line `    export GHIDRA_INSTALL_DIR="$gdir"`, and that neither `$work/home/.bash_profile` nor `$work/home/.rea-installer/installed` exists.
Each sandbox's code starts with `PATH="$STUBS:/usr/bin:/bin";` as in Task 1. At the end of the section remove the section's stubs: `rm -f "$STUBS/brew" "$STUBS/ghidraRun"` (later sections expect neither).

Run `/bin/bash ./test.sh`. Check 4 must FAIL against Task 1's gate (record that in the summary as the red step); checks 1, 2, 3 and 5 guard behaviour Task 1 already implements and may pass at once — if any of them fails, fix ghidra_setting or install_ghidra, not the check.

GREEN for check 4: in `ghidra_setting()`, widen the first gate so it proceeds when with_ghidra is true OR the ledger records the script's own Homebrew ghidra (`grep -qxF brew:ghidra "$STATE_FILE" 2>/dev/null`, the same ledger-ownership style as jdk_owned and write_profile's homebrew check). Update the comment: ownership comes from the ledger, so a --no-ghidra rerun keeps the Ghidra the script installed, the same trap JAVA_HOME hit (WR-03); a user's own Homebrew ghidra is not written under --no-ghidra. Rerun test.sh until all checks pass, then run shellcheck on both files.
  </action>
  <verify>
    <automated>bash -o pipefail -c '/bin/bash ./test.sh 2>&1 | grep -E "^FAIL|GHID-01|passed,"' && shellcheck rea-install-macos.sh test.sh</automated>
  </verify>
  <done>All six GHID-01 checks print PASS on macOS (the rerun check prints SKIP on Linux only); check 4 was seen failing before the gate change; test.sh's last line reads "N passed, 0 failed, M skipped"; shellcheck exits 0 on both files.</done>
</task>

<task type="auto">
  <name>Task 3: README says macOS sets GHIDRA_INSTALL_DIR; remove the answered STATE.md question</name>
  <files>README.md, .planning/STATE.md</files>
  <read_first>README.md lines 105-125 ("Settings REA reads") and line 255 ("Shell profile" limitation); .planning/STATE.md "Blockers/Concerns"</read_first>
  <action>
README.md, section "### Settings REA reads": add `export GHIDRA_INSTALL_DIR="..."` to the example block between the JAVA_HOME and REA_WABT_BIN_DIRECTORY lines. After the existing Homebrew shellenv paragraph, add one sentence-case paragraph: on macOS the block sets `GHIDRA_INSTALL_DIR` to Homebrew's Ghidra (`$(brew --prefix ghidra)/libexec`), because REA finds Ghidra only through that variable, and `rea setup` copies it into each agent's registration; a `GHIDRA_INSTALL_DIR` you already set to another folder is left alone. Keep the existing wording style (short sentences, ends with periods, no emojis). Do not change the component matrix or other sections unless they state that macOS leaves GHIDRA_INSTALL_DIR unset (grep README.md for GHIDRA_INSTALL_DIR and macOS Ghidra wording to confirm; the line-255 limitation already says the Ghidra settings reach agent registrations, which is now true on macOS too, so leave it).

.planning/STATE.md, "### Blockers/Concerns": delete the bullet that starts "Open question carried from v1" (the question whether REA locates Ghidra on macOS when GHIDRA_INSTALL_DIR is unset; answered: it does not; verified 2026-10-15 in a macOS 27 VM, fixed by this task). Leave the other bullet and every other section unchanged. Use Edit (scoped), not Write, for both files.

Commit all task changes per repo convention: a short imperative sentence-case message with no prefix, e.g. "Set GHIDRA_INSTALL_DIR for Homebrew Ghidra on macOS", ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  </action>
  <verify>
    <automated>grep -q 'export GHIDRA_INSTALL_DIR=' README.md && ! grep -q 'does REA find Ghidra on macOS' .planning/STATE.md && echo OK</automated>
  </verify>
  <done>README's Settings REA reads block lists GHIDRA_INSTALL_DIR and the paragraph explains the macOS behaviour and the user-value exception; STATE.md Blockers no longer contains the Ghidra question; changes committed with the repo's commit style.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| caller environment -> installer | GHIDRA_INSTALL_DIR and PATH (ghidraRun) come from the user's shell and may point anywhere |
| installer -> shell profile | the value is written into a file the user's shells source on startup |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-gjp-01 | Tampering | ghidra_setting / write_profile | medium | mitigate | Only the path derived from `brew --prefix ghidra` is ever written, double-quoted inside the marked block; a caller-supplied GHIDRA_INSTALL_DIR is never copied into the profile (GHID-01 user-value check) |
| T-gjp-02 | Denial of service (silent breakage) | rerun via write_profile block rebuild | medium | mitigate | ghidra_setting runs on every install and re-queues the line on reruns and on --no-ghidra reruns whose ledger records brew:ghidra (GHID-01 rerun and ledger checks) |
| T-gjp-03 | Tampering | dry run | low | mitigate | Profile write and ledger stay behind write_profile's and record's dry_run guards; the GHID-01 dry-run check asserts no profile and no ledger file are created |
| T-gjp-04 | Repudiation | uninstall | low | accept | The line lives inside the marked block, which uninstall's remove_profile_block already removes; no new ledger kind is added |
| T-gjp-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs in this plan; Homebrew ghidra was already installed by the script before this change |
</threat_model>

<verification>
- `/bin/bash ./test.sh` on macOS (Bash 3.2): last line "N passed, 0 failed, M skipped", with six GHID-01 PASS lines.
- `shellcheck rea-install-macos.sh test.sh` exits 0.
- `bash -n rea-install-macos.sh` under /bin/bash 3.2 (covered by test.sh TEST-01).
</verification>

<success_criteria>
- A default macOS install exports GHIDRA_INSTALL_DIR before rea setup and writes it once into the profile block; reruns and owned --no-ghidra reruns keep exactly one line.
- A user's own GHIDRA_INSTALL_DIR elsewhere is untouched and unwritten; --no-ghidra without an owned Ghidra writes nothing.
- Dry run plans the line and changes nothing.
- README and STATE.md reflect the fix.
</success_criteria>

<output>
Create `.planning/quick/261015-gjp-fix-macos-ghidra-not-found-by-rea-set-gh/261015-gjp-SUMMARY.md` when done
</output>
