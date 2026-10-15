<#
Install or uninstall REA (https://github.com/morluto/rea) and its dependencies on Windows x64 or ARM64.

  .\rea-install-windows.ps1 install   [-NoGhidra] [-WithAndroid] [-WithExtras] [-Yes] [-DryRun]
  .\rea-install-windows.ps1 uninstall [-Yes] [-DryRun]

  -WithAndroid  JADX headless jar, Apktool, adb (APK decompilation, resources, devices)
  -WithExtras   Rizin, GNU objdump (WinLibs toolchain, ~250 MB), WABT (offline native and WASM analysis)

On ARM64, Ghidra and JADX are skipped: REA's Windows support for them is x64-only.

If scripts are blocked, run:  powershell -ExecutionPolicy Bypass -File .\rea-install-windows.ps1 install

Everything this script adds is recorded in ~\.rea-installer\installed, so uninstall removes
only what it installed and leaves pre-existing tools (Node, JDKs) alone.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('install', 'uninstall')][string]$Command,
    [switch]$NoGhidra,
    [switch]$WithAndroid,
    [switch]$WithExtras,
    [switch]$Yes,
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Invoke-WebRequest is very slow with the progress bar

$StateDir = Join-Path $HOME '.rea-installer'
$StateFile = Join-Path $StateDir 'installed'
$ToolsDir = Join-Path $StateDir 'tools'
$Package = 'rea-agents'
$JdkId = 'EclipseAdoptium.Temurin.21.JDK'
# Set once a dry run has planned the JDK, so the session JAVA_HOME is never used as a marker (WR-03).
$JdkPlanned = $false

# Not in winget; pinned to the GitHub release digests. JADX is pinned by REA (docs/android-analysis.md).
$Downloads = @{
    ghidra  = @{ Url = 'https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip'
                 Sha = 'ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db' }
    jadx    = @{ Url = 'https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar'
                 Sha = '6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75' }
    apktool = @{ Url = 'https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar'
                 Sha = 'dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423' }
    wabt    = @{ Url = 'https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42-windows-x64.tar.gz'
                 Sha = '62f1eb2b51aa57cf0f0b8ba333bf2c72a049930aa9c5de01dcad271c4fe48c88' }
}

function Log([string]$Message) { Write-Host "==> $Message" }
function Warn([string]$Message) { Write-Warning $Message }

function Invoke-Step([string]$File, [string[]]$ArgList = @()) {
    Write-Host "  > $File $($ArgList -join ' ')"
    if ($DryRun) { return }
    & $File @ArgList
    if ($LASTEXITCODE -ne 0) { throw "$File $($ArgList -join ' ') failed with exit code $LASTEXITCODE" }
}

function Add-Record([string]$Line) {
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force $StateDir | Out-Null
    if (-not (Test-Path $StateFile) -or -not (Get-Content $StateFile | Where-Object { $_ -eq $Line })) {
        Add-Content -Path $StateFile -Value $Line
    }
}

function Confirm-Step([string]$Question) {
    if ($Yes) { return $true }
    return (Read-Host "$Question [y/N]") -match '^[Yy]'
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# REA requires Node.js 22.x (>=22.19), 24.x (>=24.11), or 26+; SQLite analysis needs 24.15+.
function Test-NodeSupported {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return $false }
    $v = [version]((node -p 'process.versions.node') -replace '[^0-9.].*$', '')
    return ($v.Major -eq 22 -and $v.Minor -ge 19) -or ($v.Major -eq 24 -and $v.Minor -ge 15) -or $v.Major -ge 26
}

# Ghidra 12 and REA need JDK 21+. Reads `java -version` (stderr); a JAVA_TOOL_OPTIONS "Picked up" line may come first.
function Test-JdkUsable([string]$Dir) {
    if (-not $Dir) { return $false }
    $java = Join-Path (Join-Path $Dir 'bin') 'java.exe'
    if (-not (Test-Path -LiteralPath $java -PathType Leaf)) { return $false }
    # Windows PowerShell 5.1 turns redirected native stderr into errors that 'Stop' would make terminating.
    $ErrorActionPreference = 'Continue'
    $out = (& $java -version 2>&1 | ForEach-Object { "$_" }) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'version "(\d+)(?:\.(\d+))?') { return $false }
    $major = [int]$Matches[1]
    if ($major -eq 1 -and $Matches[2]) { $major = [int]$Matches[2] }  # "1.8.0_402" -> 8
    return $major -ge 21
}

function Test-WingetInstalled([string]$Id) {
    winget list --id $Id --exact --accept-source-agreements *> $null
    return $LASTEXITCODE -eq 0
}

function Install-Winget([string]$Id) {
    if (Test-WingetInstalled $Id) {
        Log "$Id already installed (left as-is)"
        return
    }
    Invoke-Step winget @('install', '--id', $Id, '--exact', '--silent',
                         '--accept-package-agreements', '--accept-source-agreements')
    if ($DryRun) { return }
    Add-Record "winget:$Id"
    Update-SessionPath
}

# One place reads persistent user variables, so test.sh can stand in for the User scope that Unix pwsh lacks.
function Get-UserEnv([string]$Name) {
    return [Environment]::GetEnvironmentVariable($Name, 'User')
}

# Sets a persistent user environment variable (visible to agents started from anywhere) and this session's copy.
# Callers pass -Replace only when the saved value has no java.exe.
function Set-UserEnv([string]$Name, [string]$Value, [switch]$Replace) {
    $existing = Get-UserEnv $Name
    if ($existing -eq $Value) { return }
    if ($existing -and -not $Replace) {
        Warn "$Name is already set for your user to $existing; leaving it as-is."
        return
    }
    if ($existing) { Log "Replacing $Name for your user (was $existing, which has no java.exe)." }
    Write-Host "  > setx $Name `"$Value`""
    if ($DryRun) { return }
    Set-Item "env:$Name" $Value
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Add-Record "env:$Name"
}

# Downloads a pinned file into $ToolsDir and returns its path; refuses it on a checksum mismatch.
function Get-PinnedFile([string]$Key) {
    $d = $Downloads[$Key]
    $path = Join-Path $ToolsDir (Split-Path $d.Url -Leaf)
    if (Test-Path $path) { return $path }
    Log "Downloading $(Split-Path $d.Url -Leaf)"
    Write-Host "  > Invoke-WebRequest $($d.Url)"
    if ($DryRun) { return $path }
    New-Item -ItemType Directory -Force $ToolsDir | Out-Null
    Invoke-WebRequest -Uri $d.Url -OutFile "$path.part" -UseBasicParsing
    if ((Get-FileHash -Algorithm SHA256 "$path.part").Hash.ToLowerInvariant() -ne $d.Sha) {
        Remove-Item -Force "$path.part"
        throw "Checksum mismatch for $(Split-Path $d.Url -Leaf); refusing to use it."
    }
    Move-Item -Force "$path.part" $path
    return $path
}

# Extracts an archive with Windows' built-in tar (handles .zip and .tar.gz) into a staging folder and renames it
# only on success, so a failed or interrupted extract never leaves a $Folder a rerun would trust. Returns $ToolsDir\$Folder.
function Expand-PinnedArchive([string]$Key, [string]$Folder) {
    $target = Join-Path $ToolsDir $Folder
    if (Test-Path $target) { return $target }
    $archive = Get-PinnedFile $Key
    $staging = Join-Path $ToolsDir ".staging-$Folder"
    if ($DryRun) {
        Write-Host "  > tar -xf $archive -C $staging"
        return $target
    }
    if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
    New-Item -ItemType Directory -Force $staging | Out-Null
    try {
        Invoke-Step tar @('-xf', $archive, '-C', $staging) | Out-Null  # keep tar output out of the return value
        Move-Item (Join-Path $staging $Folder) $target
    } catch {
        # The verified archive is kept so a rerun reuses it.
        Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue
        throw "Could not unpack $(Split-Path $archive -Leaf): $_"
    }
    Remove-Item -Recurse -Force $staging
    Remove-Item -Force $archive
    return $target
}

# ---------------------------------------------------------------- install

# Reuses a JAVA_HOME that is JDK 21+; otherwise installs Temurin 21 and points this session and the user at it.
function Install-Jdk {
    if ($script:JdkPlanned) { return }
    if (Test-JdkUsable $env:JAVA_HOME) { Log "Using JDK at $env:JAVA_HOME"; return }
    if ($env:JAVA_HOME) {
        Warn "JAVA_HOME points at $env:JAVA_HOME, which is not JDK 21 or newer; installing the script's own JDK 21."
    }
    Install-Winget $JdkId
    if ($DryRun) { $script:JdkPlanned = $true; return }
    # Install-Winget skips the PATH refresh when Temurin was already installed.
    Update-SessionPath
    # Derived from PATH, not the MSI's Machine JAVA_HOME, so it works whether or not the MSI set one.
    $javaCmd = Get-Command java -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $javaCmd) { throw 'Temurin installed but java is not on PATH.' }
    $dir = Split-Path (Split-Path $javaCmd.Source)
    if (-not (Test-JdkUsable $dir)) { throw "Temurin installed but the java on PATH is in $dir, which is not JDK 21 or newer." }
    # A Temurin upgrade removes the versioned folder the script saved (CR-01), and the MSI can leave it behind without
    # java.exe (WR-02), so a user value is replaced only when the ledger says the script set it and the saved folder
    # has no bin\java.exe; a value that holds a JDK is kept, even if the user changed it (WR-01, D-05).
    # Set-UserEnv leaves any other user value without touching the session, so the session is set first.
    $userJava = Get-UserEnv 'JAVA_HOME'
    $gone = $userJava -and -not (Test-Path -LiteralPath (Join-Path (Join-Path $userJava 'bin') 'java.exe') -PathType Leaf)
    $replace = $gone -and (Test-Path $StateFile) -and (@(Get-Content $StateFile) -contains 'env:JAVA_HOME')
    $env:JAVA_HOME = $dir
    Set-UserEnv 'JAVA_HOME' $dir -Replace:$replace
}

function Invoke-Install {
    # The machine's architecture, not this process's: PowerShell may itself run under x64 emulation on ARM64.
    $hostArch = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
    if ($hostArch -notin @('AMD64', 'ARM64')) { throw "REA needs 64-bit Windows (x64 or ARM64); this is $hostArch." }
    # REA's Windows native controls, which Ghidra and JADX require, ship for x64 only.
    $isArm64 = $hostArch -eq 'ARM64'
    if ($isArm64) { Warn 'Windows on ARM64: Ghidra and JADX are skipped because REA supports them on Windows x64 only.' }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is required. Install "App Installer" from the Microsoft Store, then rerun.'
    }

    # 1. Node.js + npm
    if (Test-NodeSupported) {
        Log "Using Node.js $(node --version) at $((Get-Command node).Source)"
    } else {
        if (Get-Command node -ErrorAction SilentlyContinue) { Warn "Node.js $(node --version) is unsupported; installing Node.js LTS." }
        Install-Winget 'OpenJS.NodeJS.LTS'
        if (-not $DryRun -and -not (Test-NodeSupported)) { throw 'Node.js LTS installed but is still unsupported or not on PATH.' }
    }

    # 2. Ghidra (free native-analysis engine) + its JDK
    if (-not $NoGhidra) {
        if ($env:GHIDRA_INSTALL_DIR) {
            Log "Ghidra already configured at $env:GHIDRA_INSTALL_DIR (left as-is)"
        } elseif ($isArm64) {
            Log 'Skipping Ghidra (x64 only)'
        } else {
            Install-Jdk
            Set-UserEnv 'GHIDRA_INSTALL_DIR' (Expand-PinnedArchive 'ghidra' 'ghidra_12.1.4_PUBLIC')
        }
    }

    # 3. Android: JADX and Apktool need a JDK; adb is found on PATH; REA runs Apktool through a .bat launcher.
    if ($WithAndroid) {
        Install-Jdk
        if ($isArm64) { Log 'Skipping JADX (x64 only)' }
        else { Set-UserEnv 'REA_JADX_MCP_JAR' (Get-PinnedFile 'jadx') }
        $jar = Get-PinnedFile 'apktool'
        $launcher = Join-Path $ToolsDir 'apktool.bat'
        Write-Host "  > write $launcher"
        if (-not $DryRun) { Set-Content -Path $launcher -Encoding Ascii -Value "@java -jar `"$jar`" %*" }
        Set-UserEnv 'REA_APKTOOL_COMMAND' $launcher
        Install-Winget 'Google.PlatformTools'
    }

    # 4. Offline tools: Rizin and WinLibs' objdump are found on PATH.
    if ($WithExtras) {
        Install-Winget 'Rizin.Rizin'
        Install-Winget 'BrechtSanders.WinLibs.POSIX.UCRT'
        Set-UserEnv 'REA_WABT_BIN_DIRECTORY' (Join-Path (Expand-PinnedArchive 'wabt' 'wabt-1.0.42') 'bin')
    }

    # 5. REA CLI
    Log "Installing $Package"
    Invoke-Step npm @('install', '--global', "$Package@latest")
    $rea = Join-Path (npm prefix --global) 'rea.cmd'
    if (-not $DryRun -and -not (Test-Path $rea)) { throw "npm finished but $rea is missing." }

    # 6. Agent registration (Hopper is not available on Windows)
    Log 'Running rea setup'
    if ($Yes) { Invoke-Step $rea @('setup', '--yes', '--all-detected') }
    else { Invoke-Step $rea @('setup') }
    if (-not $DryRun) {
        # setup succeeds even when no agent was ticked, so ask doctor whether any registration landed.
        # doctor exits non-zero for unrelated health problems; only its output matters here.
        $regs = & $rea doctor --format json --filter-output identity.registrations | Out-String
        if ($regs -notmatch '"state":"aligned"') {
            Warn "no agent is registered with REA; run '$rea setup' and press Space to select your agent(s) before Enter."
        }
    }

    Log "Done. Open a new terminal, restart your agent(s), then check health with: $rea doctor"
    if ($isArm64) { Log "On ARM64, 'rea doctor' reports the host as unsupported: REA's Windows support targets x64." }
}

# ---------------------------------------------------------------- uninstall

function Invoke-Uninstall {
    $state = @()
    if (Test-Path $StateFile) { $state = @(Get-Content $StateFile) }

    # 1. Agent registrations, skills and ~\.rea cache/state (needs the CLI, so first).
    $rea = $null
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $candidate = Join-Path (npm prefix --global) 'rea.cmd'
        if (Test-Path $candidate) { $rea = $candidate }
    }
    $onPath = Get-Command rea -ErrorAction SilentlyContinue
    if (-not $rea -and $onPath) { $rea = $onPath.Source }
    if ($rea) {
        Log 'Removing REA agent registrations, skills and data'
        try {
            Invoke-Step $rea @('uninstall', '--purge-data')
        } catch {
            Warn "rea uninstall failed; remove agent registrations by hand. ($_)"
        }
    } else {
        Warn 'rea CLI not found; skipping agent deregistration.'
    }

    # 2. REA CLI
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm ls --global $Package *> $null
        if ($LASTEXITCODE -eq 0) {
            Log "Removing $Package"
            Invoke-Step npm @('uninstall', '--global', $Package)
        }
    }

    # 3. Everything else we recorded, newest first (Node last).
    [array]::Reverse($state)
    foreach ($line in $state) {
        $kind, $name = $line -split ':', 2
        switch ($kind) {
            'env' {
                Log "Removing user environment variable $name"
                Write-Host "  > setx $name (delete)"
                if (-not $DryRun) { [Environment]::SetEnvironmentVariable($name, $null, 'User') }
            }
            'winget' {
                if (Test-WingetInstalled $name) {
                    Log "Removing $name"
                    Invoke-Step winget @('uninstall', '--id', $name, '--exact', '--silent', '--accept-source-agreements')
                }
            }
        }
    }

    # Also removes the downloaded Ghidra, JADX, Apktool and WABT under tools\.
    if (-not $DryRun -and (Test-Path $StateDir)) { Remove-Item -Recurse -Force $StateDir }
    Log 'REA uninstalled.'
}

# ---------------------------------------------------------------- main

switch ($Command) {
    'install' { Invoke-Install }
    'uninstall' { Invoke-Uninstall }
    default { Get-Content $PSCommandPath -TotalCount 15 | Select-Object -Skip 1 | Write-Host }
}
