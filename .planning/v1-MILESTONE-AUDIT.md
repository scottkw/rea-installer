---
milestone: v1
audited: 2026-10-15T16:00:00Z
status: tech_debt
scores:
  requirements: 19/19
  phases: 3/3
  integration: 11/11
  flows: 5/5
gaps:
  requirements: []
  integration: []
  flows: []
tech_debt:
  - phase: 01-loud-failures-safe-dry-run-and-regression-tests
    items:
      - "8 review rows still `disposition: open` in 01-REVIEW-DISPOSITION.md: WR-03 (DRY checks compare names only), WR-04 (pkg_install swallows a failing pkg_list), WR-06 (pwsh 7 parser only, PS 5.1 syntax not checked), WR-07 (now addressed by Phase 3 MAC-01), IN-01 (dry-run plan differs from real run), IN-02 (CI pin/timeout, moot since CI removed), IN-03 (regression gaps in new checks), IN-04 (uninstall removes ~/.agents without a ledger entry)"
      - "Deferred: WR-01 (unpack moves whole staging folder on layout mismatch), WR-02 (Rizin/Wakaru trust a partial folder), WR-05 (failed package install records none of its pulled-in deps)"
      - "Human items open: confirm the 10 judgment-tier prohibitions; resolve ROADMAP `Mode: mvp` vs non-user-story goal"
      - "01-04-SUMMARY.md has no requirements-completed field (FAIL-03 missing from SUMMARY cross-check)"
  - phase: 02-consistent-java-handling
    items:
      - "16 deferred review findings, incl. WR-05 (Windows uninstall deletes JAVA_HOME even if the user changed it; integration checker re-found this), WR-06 (JDK check accepts a JRE), WR-101/102/104, IN-101..105, IN-201/202"
      - "Backlog 999.1: macOS/Windows dry run without npm dies at `npm prefix --global`"
      - "Backlog 999.2: WR-302 Windows JAVA_HOME on an unavailable drive throws 'Cannot find drive'; IN-302 Set-UserEnv message hard-codes java.exe"
      - "2 truths need real Windows (VERI-02)"
  - phase: 03-macos-unattended-install-and-readme-sync
    items:
      - "8 deferred review findings: WR-02 (partial Homebrew install adopted as user's), WR-03 (kept-without-terminal items lost from ledger), WR-04 (piped curl|bash forces Homebrew NONINTERACTIVE), WR-05 (sudo hint / inherited INTERACTIVE), WR-06 (dry run downloads Homebrew installer), WR-07 (Homebrew uninstall download failure), IN-01, IN-02"
      - "Human items open: 4 flagged test-tier prohibitions; README no-terminal wording backstop; real fresh-Mac run (VERI-01)"
      - "Windows Confirm-Step uses Read-Host with no no-terminal path (integration check)"
nyquist:
  compliant_phases: []
  partial_phases: []
  not_validated_phases: []
  missing_phases: []
  overall: skipped (validate-phase hook not active)
---

# v1 Milestone Audit: rea-installer installer hardening

**Status:** tech_debt. All 19 requirements are satisfied, all 3 phases are verified, and cross-phase wiring is intact. There are no blockers. The open and deferred review items below need a decision before archiving.

## Test runs (this audit)

| Run | Result |
|-----|--------|
| `/bin/bash ./test.sh` (macOS, Bash 3.2), run by the integration checker | 119 passed, 0 failed, 2 skipped |
| `docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" -w /src ubuntu:24.04 bash ./test.sh` | 85 passed, 0 failed, 12 skipped |

## Phases

| Phase | VERIFICATION status | Notes |
|-------|---------------------|-------|
| 01 Loud failures, safe dry run, tests | passed (47/47) | 3 human items open; 8 review rows still `open` |
| 02 Consistent Java handling | passed (54/56) | G-02-1/G-02-3 closed by quick 261014-tvi; WR-302 sent to backlog 999.2; 2 truths need real Windows |
| 03 macOS unattended + README | passed (19/20) | CR-01 closed by quick 261015-d2b; 1 backstop truth left to human review |

## Requirements (3-source cross-reference)

| REQ | Phase | VERIFICATION | SUMMARY frontmatter | REQUIREMENTS.md | Final |
|-----|-------|--------------|---------------------|-----------------|-------|
| FAIL-01 | 1 | satisfied | 01-03 | [x] | satisfied |
| FAIL-02 | 1 | satisfied | 01-03 | [x] | satisfied |
| FAIL-03 | 1 | satisfied (SC3, test.sh FAIL-03 + spot check) | **missing** (01-04 has no field) | [x] | satisfied, checked by hand* |
| DRY-01 | 1 | satisfied | 01-03 | [x] | satisfied |
| DRY-02 | 1 | satisfied | 01-03 | [x] | satisfied |
| UNIN-01 | 1 | satisfied | 01-03 | [x] | satisfied |
| TEST-01 | 1 | satisfied (pwsh 7 parser only, WR-06) | 01-01 | [x] | satisfied |
| TEST-02 | 1 | satisfied | 01-01 | [x] | satisfied |
| TEST-03 | 1 | satisfied | 01-01 | [x] | satisfied |
| TEST-04 | 1 | satisfied (names-only snapshot, WR-03) | 01-02 | [x] | satisfied |
| TEST-05 | 1 | satisfied | 01-02 | [x] | satisfied |
| TEST-06 | 1/2 | satisfied | 01-01, 02-10 | [x] | satisfied |
| JAVA-01 | 2 | satisfied | 02-03/05/07/09 | [x] | satisfied |
| JAVA-02 | 2 | satisfied (normal paths; WR-302 deferred) | 02-01/02/03/04/06/09 | [x] | satisfied |
| JAVA-03 | 2 | satisfied | 02-02/04/06/08 | [x] | satisfied |
| JAVA-04 | 2 | satisfied | 02-02/04/06/08 | [x] | satisfied |
| MAC-01 | 3 | satisfied | 03-01 | [x] | satisfied |
| MAC-02 | 3 | satisfied (CR-01 closed) | 03-01 | [x] | satisfied |
| DOCS-01 | 3 | satisfied | 03-02 | [x] | satisfied |

\* The matrix would rate FAIL-03 "partial". It was checked by hand: 01-VERIFICATION SC3 and the test.sh FAIL-03 check pass in both runs above. Orphaned requirements: none.

## Integration (gsd-integration-checker)

All 11 cross-phase connections are WIRED: the macOS profile block (P2 JAVA_HOME + P3 shellenv, one block on rerun), every ledger kind to its uninstall arm on all three platforms, dry-run guards on P2/P3 additions, UNIN-01 with P3 `confirm` without a terminal, byte-identical `confirm`/`register_agents` in both bash scripts, and README claims spot-checked against the code.

| Flow | Result |
|------|--------|
| Linux fresh install, rerun, uninstall | Complete (static trace + container suite) |
| macOS fresh `--yes` with no Homebrew, new terminal, uninstall | Complete by static trace; real Mac pending (VERI-01) |
| macOS `--no-ghidra` rerun with an existing JDK | Complete |
| Windows install with stale JAVA_HOME, then uninstall | Complete; real Windows pending (VERI-02) |
| Uninstall with broken `rea` and no terminal | Complete (Windows `Confirm-Step` has no no-terminal path) |

Warnings from the checker: they are already deferred (03 WR-06, backlog 999.1, Phase 2 WR-05) or listed under tech debt above.

## Tech debt summary

See frontmatter `tech_debt`. The decision that matters most is Phase 1's **8 rows still `open`** in 01-REVIEW-DISPOSITION.md. Two of them are already moot (WR-07, fixed by MAC-01; IN-02, CI removed). Mark each row fixed, deferred, or accepted before archiving. Real-machine checks remain v2 (VERI-01, VERI-02).
