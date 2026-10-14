<#
Install or uninstall REA (https://github.com/morluto/rea) and its dependencies on Windows x64.

  .\rea-install-windows.ps1 install   [-NoGhidra] [-WithAndroid] [-WithExtras] [-Yes] [-DryRun]
  .\rea-install-windows.ps1 uninstall [-Yes] [-DryRun]

  -WithAndroid  JADX headless jar, Apktool, adb (APK decompilation, resources, devices)
  -WithExtras   Rizin, GNU objdump (WinLibs toolchain, ~250 MB), WABT (offline native and WASM analysis)

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
    Add-Record "winget:$Id"
    Update-SessionPath
}

# Sets a persistent user environment variable (visible to agents started from anywhere) and this session's copy.
function Set-UserEnv([string]$Name, [string]$Value) {
    $existing = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($existing -eq $Value) { return }
    if ($existing) {
        Warn "$Name is already set for your user to $existing; leaving it as-is."
        return
    }
    Write-Host "  > setx $Name `"$Value`""
    Set-Item "env:$Name" $Value
    if ($DryRun) { return }
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

# Extracts an archive into $ToolsDir with Windows' built-in tar (handles .zip and .tar.gz) and returns the new top-level folder.
function Expand-PinnedArchive([string]$Key, [string]$Folder) {
    $target = Join-Path $ToolsDir $Folder
    if (Test-Path $target) { return $target }
    $archive = Get-PinnedFile $Key
    Invoke-Step tar @('-xf', $archive, '-C', $ToolsDir) | Out-Null  # keep tar output out of the return value
    if (-not $DryRun) { Remove-Item -Force $archive }
    return $target
}

# ---------------------------------------------------------------- install

function Install-Jdk {
    if ($env:JAVA_HOME) { Log "Using JDK at $env:JAVA_HOME"; return }
    Install-Winget $JdkId
    # Temurin's installer sets a machine-wide JAVA_HOME; load it into this session for rea setup.
    $env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    if ($DryRun -and -not $env:JAVA_HOME) { $env:JAVA_HOME = '<Temurin JAVA_HOME>' }
    if (-not $env:JAVA_HOME) { throw "Temurin installed but JAVA_HOME was not set." }
}

function Invoke-Install {
    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'REA on Windows (Ghidra and JADX) supports x64 only.'
    }
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
        } else {
            Install-Jdk
            Set-UserEnv 'GHIDRA_INSTALL_DIR' (Expand-PinnedArchive 'ghidra' 'ghidra_12.1.4_PUBLIC')
        }
    }

    # 3. Android: JADX needs a full JDK; adb is found on PATH; REA runs Apktool through a .bat launcher.
    if ($WithAndroid) {
        Install-Jdk
        Set-UserEnv 'REA_JADX_MCP_JAR' (Get-PinnedFile 'jadx')
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

    Log "Done. Open a new terminal, restart your agent(s), then check health with: $rea doctor"
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
        Invoke-Step $rea @('uninstall', '--purge-data')
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
    default { Get-Content $PSCommandPath -TotalCount 13 | Select-Object -Skip 1 | Write-Host }
}
