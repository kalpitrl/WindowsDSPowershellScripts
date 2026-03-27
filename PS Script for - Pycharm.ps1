# ============================================================
# Install-PyCharm.ps1
# Windows Server 2022 | Run as Administrator
# PyCharm Community Edition 2025.3.3 (build 253.31033.139)
# - Silent install, all users
# - Adds launcher dir to SYSTEM PATH
# - Associates .py files with PyCharm
# NOTE: JetBrains unified PyCharm in 2025. This installer starts
#       a 30-day Pro trial, then auto-reverts to free community
#       features. No license or action required.
# ============================================================

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-FileExists {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        Write-Host "ERROR: $Label not found at: $Path" -ForegroundColor Red
        exit 1
    }
    Write-Host "  OK: $Label found." -ForegroundColor Green
}

Write-Host "Installing PyCharm Community Edition 2025.3.3" -ForegroundColor Green

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
$PyCharmVersion  = "2025.3.3"
$InstallerName   = "pycharm-$PyCharmVersion.exe"

$TempDir         = "C:\Temp"
$Installer       = "$TempDir\$InstallerName"
$SilentConfig    = "$TempDir\pycharm-silent.config"
$InstallLog      = "$TempDir\pycharm-install.log"

# Official JetBrains download URL -- pinned version for Image Builder
$Url             = "https://download.jetbrains.com/python/$InstallerName"

# PyCharm installs to a versioned subdirectory under JetBrains
$InstallDir      = "C:\Program Files\JetBrains\PyCharm $PyCharmVersion"
$LauncherDir     = "$InstallDir\bin"
$PyCharmExe      = "$LauncherDir\pycharm64.exe"

# ------------------------------------------------------------
# Prep temp directory
# ------------------------------------------------------------
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# ------------------------------------------------------------
# Write silent config file
# JetBrains installers support a config file for unattended installs.
# This gives us fine-grained control over install options.
# ------------------------------------------------------------
Write-Host "`nWriting silent install config..." -ForegroundColor Yellow

@"
; PyCharm silent install config
; https://www.jetbrains.com/help/pycharm/installation-guide.html

[Settings]
; Installation directory
INSTALL_DIR=C:\Program Files\JetBrains\PyCharm $PyCharmVersion

; Install for all users
mode=admin

; Create desktop shortcut
CREATE_DESKTOP_ENTRY=1

; Add launcher bin dir to system PATH
UPDATE_PATH=1

; Associate .py files with PyCharm
ASSOCIATE_PY=1

; Add 'Open Folder as Project' to context menu
ADD_OPEN_DIR_ACTION=1

; Do NOT launch PyCharm after install (headless server)
RUN_AFTER_INSTALL=0
"@ | Set-Content -Path $SilentConfig -Encoding UTF8

Assert-FileExists $SilentConfig "Silent config"

# ------------------------------------------------------------
# Download PyCharm installer
# ------------------------------------------------------------
Write-Host "`nDownloading PyCharm $PyCharmVersion (~800 MB)..." -ForegroundColor Yellow
Write-Host "  URL: $Url" -ForegroundColor Gray
Write-Host "  This will take a few minutes..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $Url -OutFile $Installer -UseBasicParsing
} catch {
    Write-Host "ERROR: Failed to download PyCharm installer." -ForegroundColor Red
    Write-Host "  URL tried: $Url" -ForegroundColor Red
    Write-Host "  Check https://www.jetbrains.com/pycharm/download/other/ for the latest version." -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}
Assert-FileExists $Installer "PyCharm installer"

# ------------------------------------------------------------
# Install PyCharm (silent)
# ------------------------------------------------------------
Write-Host "`nInstalling PyCharm (this takes 3-5 minutes)..." -ForegroundColor Yellow

$proc = Start-Process -FilePath $Installer -Wait -PassThru `
    -ArgumentList "/S /CONFIG=`"$SilentConfig`" /LOG=`"$InstallLog`""

if ($proc.ExitCode -ne 0) {
    Write-Host "ERROR: PyCharm installer exited with code $($proc.ExitCode)" -ForegroundColor Red
    Write-Host "  Check log at: $InstallLog" -ForegroundColor Red
    exit 1
}

Assert-FileExists $PyCharmExe "pycharm64.exe"

# ------------------------------------------------------------
# Add PyCharm launcher dir to SYSTEM PATH (idempotent)
# Allows running 'pycharm64' from any shell
# ------------------------------------------------------------
Write-Host "`nUpdating SYSTEM PATH..." -ForegroundColor Yellow
$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($MachinePath -notlike "*$LauncherDir*") {
    $MachinePath += ";$LauncherDir"
    [Environment]::SetEnvironmentVariable("Path", $MachinePath, "Machine")
    Write-Host "  Added: $LauncherDir" -ForegroundColor Green
} else {
    Write-Host "  Already in PATH: $LauncherDir" -ForegroundColor Cyan
}

# Update current session
$env:Path += ";$LauncherDir"

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------
Write-Host "`nVerification" -ForegroundColor Green

Assert-FileExists $PyCharmExe                              "pycharm64.exe"
Assert-FileExists "$LauncherDir\pycharm.bat"               "pycharm.bat"
Assert-FileExists "$InstallDir\plugins"                    "plugins directory"
Assert-FileExists "$InstallDir\jbr"                        "bundled JBR (Java Runtime)"

Write-Host "`nPyCharm version info:" -ForegroundColor Cyan
$productInfo = "$InstallDir\product-info.json"
if (Test-Path $productInfo) {
    $info = Get-Content $productInfo | ConvertFrom-Json
    Write-Host "  Name    : $($info.name)"
    Write-Host "  Version : $($info.version)"
    Write-Host "  Build   : $($info.buildNumber)"
} else {
    Write-Host "  product-info.json not found -- install may be incomplete" -ForegroundColor Yellow
}

Write-Host "`nPATH entry:" -ForegroundColor Cyan
[Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" |
    Where-Object { $_ -like "*PyCharm*" } |
    ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host "`nSUCCESS" -ForegroundColor Green
Write-Host "- PyCharm $PyCharmVersion installed at $InstallDir"
Write-Host "- Desktop shortcut created"
Write-Host "- .py files associated with PyCharm"
Write-Host "- Launcher dir added to SYSTEM PATH"
Write-Host "- Bundled Java runtime (JBR 21) included -- no JDK needed"
Write-Host ""
Write-Host "NOTES:" -ForegroundColor Cyan
Write-Host "  - PyCharm is now unified. A 30-day Pro trial starts automatically." -ForegroundColor White
Write-Host "  - After 30 days it auto-reverts to free Community features." -ForegroundColor White
Write-Host "  - No license purchase or action required for Community use." -ForegroundColor White
Write-Host "  - To launch from shell: pycharm64 (after opening a new shell)" -ForegroundColor White