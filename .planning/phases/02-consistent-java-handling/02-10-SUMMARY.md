---
phase: 02-consistent-java-handling
plan: 10
subsystem: testing
tags: [testing, docs, github-actions, local-testing, uat-gap]
status: complete

requires:
  - phase: 02-consistent-java-handling
    provides: "02-09 test.sh state (96 passed on macOS, 63 passed in ubuntu:24.04) used as the before/after baseline"
provides:
  - "No GitHub Actions workflow; .github removed from the repo (G-02-6)"
  - "test.sh comments describe local runs only; code unchanged"
  - "ROADMAP, REQUIREMENTS, PROJECT and .claude/CLAUDE.md describe verification as /bin/bash ./test.sh on macOS and ./test.sh in a local Linux container"
affects: [DOCS-01, phase-03]

actuals:
  tokens: 3871
  tasks: 2
  commits: 2
plan_head_before: 312cf0bddbf3433c2ed98d439c7249e3cacb5ac8
plan_head_after: 8ec879e890933e692be05f57371d8b86938a741c

tech-stack:
  added: []
  patterns:
    - "A test.sh comment must not begin with the word shellcheck: shellcheck parses '# shellcheck ...' as a directive and fails with SC1073"

key-files:
  created: []
  modified:
    - test.sh
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/PROJECT.md
    - .claude/CLAUDE.md
  deleted:
    - .github/workflows/test.yml

key-decisions:
  - "No GitHub Actions; all testing is local: /bin/bash ./test.sh on macOS (Bash 3.2) and ./test.sh in a local Linux container (G-02-6)"
  - "Completed Phase 1 history keeps its text; the Phase 1 success criterion that named GitHub Actions gets a dated note instead of a rewrite"

patterns-established:
  - "PROJECT.md and .claude/CLAUDE.md Testing constraint lines are byte-identical so GSD regeneration cannot revert CLAUDE.md"

requirements-completed: [TEST-06]

coverage:
  - id: D1
    description: "GitHub Actions workflow deleted, test.sh comments reworded with no code change"
    requirement: "TEST-06"
    verification:
      - kind: other
        ref: "Task 1 <automated> verify in 02-10-PLAN.md (prints 'workflow removed')"
        status: pass
    human_judgment: false
  - id: D2
    description: "Planning docs and CLAUDE.md describe testing as local runs; Phase 1 history keeps a dated note"
    requirement: "TEST-06"
    verification:
      - kind: other
        ref: "Task 2 docs check in 02-10-PLAN.md (prints 'docs ok')"
        status: pass
    human_judgment: false
  - id: D3
    description: "Final local gate passes on macOS Bash 3.2 and in ubuntu:24.04"
    requirement: "TEST-06"
    verification:
      - kind: integration
        ref: "/bin/bash ./test.sh; docker run --rm -v \"$PWD\":/src:ro ubuntu:24.04 bash -c 'cp -r /src /w && cd /w && ./test.sh'"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-10-14
---

# Phase 2 Plan 10: Remove GitHub Actions and Describe Testing as Local Runs Summary

**Deleted `.github/workflows/test.yml`, reworded test.sh comments and the ROADMAP/REQUIREMENTS/PROJECT/CLAUDE.md test wording so verification means `/bin/bash ./test.sh` on macOS and `./test.sh` in a local Linux container; both local runs report 0 failed.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-10-15T02:09:47Z
- **Completed:** 2026-10-15T02:12:29Z
- **Tasks:** 2
- **Files modified:** 6 (1 deleted, 5 edited)

## Accomplishments

- Removed the GitHub Actions workflow. `.github` no longer exists and nothing under it is tracked.
- test.sh comments and one SKIP message ("not on this Mac") describe local runs. No code line, check name or exit path changed, and the macOS pass count is still 96, the same as after 02-09.
- TEST-06 now names the two local commands. MAC-01, DOCS-01 and the Phase 3 goal and criteria no longer mention CI. A new out-of-scope row covers hosted CI.
- The PROJECT.md and .claude/CLAUDE.md Testing lines are byte-identical: "all testing is local ...".
- Phase 1 plan-list lines and phase 1 artifacts are unchanged. The Phase 1 criterion that named GitHub Actions now has a dated note.

## Task Commits

1. **Task 1 (tracer): Delete the GitHub Actions workflow and reword test.sh comments** - `84a334a`
2. **Task 2: Describe testing as local runs in ROADMAP, REQUIREMENTS, PROJECT and CLAUDE.md** - `8ec879e`

## Final Local Gate

```
96 passed, 0 failed, 2 skipped
63 passed, 0 failed, 11 skipped
exit: mac=0 linux=0
```

The first line is macOS `/bin/bash ./test.sh` (Bash 3.2). The two skips are Linux-only checks. The second line is the ubuntu:24.04 container; the Windows cases skip there because the container has no pwsh. No FAIL lines.

## Files Created/Modified

- `.github/workflows/test.yml` - deleted
- `test.sh` - header, need() comment pair, Darwin SKIP text and the JAVA_HOME sandbox comment reworded
- `.planning/ROADMAP.md` - Overview, Phase 1 criterion note, Phase 3 goal and criteria 1 and 3
- `.planning/REQUIREMENTS.md` - TEST-06, MAC-01, DOCS-01 and the Out of Scope rows
- `.planning/PROJECT.md` - Validated item, Active note, Testing constraint and Key Decisions rows
- `.claude/CLAUDE.md` - Testing constraint line, identical to PROJECT.md's

## Decisions Made

None beyond the plan. It carries out user decision G-02-6 as written.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The planned need() comment broke shellcheck**
- **Found during:** Task 1
- **Issue:** The planned wording "# shellcheck and docker may be missing on a Mac; ..." begins with `# shellcheck`. shellcheck reads that as a directive and reports SC1073/SC1072, so `TEST-01 shellcheck test.sh` failed (95 passed, 1 failed).
- **Fix:** Changed the order of the words: "# Docker and shellcheck may be missing on a Mac; the Linux container run covers shellcheck." The meaning is the same.
- **Files modified:** test.sh
- **Verification:** Task 1 verify printed "workflow removed" with 96 passed, 0 failed, 2 skipped.
- **Committed in:** 84a334a

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** A wording change in one comment. No scope change.

## Issues Encountered

None beyond the deviation above.

## User Setup Required

None. No external service needs configuration.

## Next Phase Readiness

This was the last Phase 2 plan, and the final local gate passes on both platforms. Phase 2 is ready for verification. When Phase 3 works on DOCS-01, it should describe the two local commands, not a CI run.

## Self-Check: PASSED

- FOUND: test.sh, .planning/ROADMAP.md, .planning/REQUIREMENTS.md, .planning/PROJECT.md, .claude/CLAUDE.md
- ABSENT as intended: .github/workflows/test.yml
- FOUND commits: 84a334a, 8ec879e (ancestors of HEAD)
