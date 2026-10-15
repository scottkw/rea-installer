# Roadmap: rea-installer

## Milestones

- ✅ **v1 Installer Hardening** — Phases 1-3 (shipped 2026-10-15)

## Phases

<details>
<summary>✅ v1 Installer Hardening (Phases 1-3) — SHIPPED 2026-10-15</summary>

- [x] Phase 1: Loud Failures, Safe Dry Run, and Regression Tests (5/5 plans) — completed 2026-10-14
- [x] Phase 2: Consistent Java Handling (10/10 plans) — completed 2026-10-14
- [x] Phase 3: macOS Unattended Install and README Sync (2/2 plans) — completed 2026-10-15

Full details: [milestones/v1-ROADMAP.md](milestones/v1-ROADMAP.md)

</details>

## Backlog

### Phase 999.1: Follow-up — Phase 02 deferred UAT follow-up: Test 5 (BACKLOG)

**Goal:** Resolve the UAT checkpoint deferred during Phase 02 verification
**Source phase:** 02
**Deferred at:** 2026-10-14 during /gsd-verify-work 02 session completion
**Follow-ups:**
- [ ] Test 5: Review IN-02: dry runs on a machine without npm die at npm prefix --global (macOS rea-install-macos.sh:308, Windows rea-install-windows.ps1:266); use a placeholder prefix in dry run as Linux does with NPM_PREFIX (deferred 2026-10-14)

### Phase 999.2: Follow-up — Phase 02 deferred review findings: Windows JAVA_HOME path checks (BACKLOG)

**Goal:** Resolve the Windows review findings deferred when Phase 02 closed
**Source phase:** 02
**Deferred at:** 2026-10-14 after quick task 261014-tvi
**Follow-ups:**
- [ ] WR-302: a `JAVA_HOME` on an unavailable drive makes `Join-Path` throw "Cannot find drive" under Stop (rea-install-windows.ps1 `Test-JdkUsable` ~line 88 and the replace rule ~line 205); build the path with `[IO.Path]::Combine` and add a `Q:\` driver case
- [ ] IN-302: `Set-UserEnv` replace message hard-codes "has no java.exe"; pass the reason in or move the wording to the caller
