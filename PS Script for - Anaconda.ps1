# ============================================================
# Install-Anaconda.ps1
# Windows Server 2022 | Run as Administrator
# Anaconda 2025.12-2 (conda 25.11.0, Python 3.12)
# - Silent install for All Users
# - Installs to C:\Anaconda3
# - Adds conda, Scripts, and Library\bin to SYSTEM PATH manually
#   (Anaconda disabled auto-PATH for AllUsers installs since 2022.05)
# - conda initialized for PowerShell and CMD
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

Write-Host "Installing Anaconda 2025.12-2" -ForegroundColor Green

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
$AnacondaVersion = "2025.12-2"
$InstallerName   = "Anaconda3-$AnacondaVersion-Windows-x86_64.exe"

$TempDir         = "C:\Temp"
$Installer       = "$TempDir\$InstallerName"
$InstallDir      = "C:\Anaconda3"
$InstallLog      = "$TempDir\anaconda-install.log"

# Official Anaconda archive -- pinned version for reproducible Image Builder builds
# Full archive index: https://repo.anaconda.com/archive/
$Url             = "https://repo.anaconda.com/archive/$InstallerName"

# PATH entries required (AllUsers install disables auto-PATH since 2022.05)
$PathEntries = @(
    $InstallDir,
    "$InstallDir\Scripts",
    "$InstallDir\Library\bin",
    "$InstallDir\Library\mingw-w64\bin",
    "$InstallDir\condabin"
)

# ------------------------------------------------------------
# Prep temp directory
# ------------------------------------------------------------
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# ------------------------------------------------------------
# Download Anaconda installer
# ------------------------------------------------------------
Write-Host "`nDownloading Anaconda $AnacondaVersion (~1.1 GB)..." -ForegroundColor Yellow
Write-Host "  URL: $Url" -ForegroundColor Gray
Write-Host "  This will take a few minutes..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $Url -OutFile $Installer -UseBasicParsing
} catch {
    Write-Host "ERROR: Failed to download Anaconda installer." -ForegroundColor Red
    Write-Host "  URL tried: $Url" -ForegroundColor Red
    Write-Host "  Check https://repo.anaconda.com/archive/ for the latest filename." -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}
Assert-FileExists $Installer "Anaconda installer"

# ------------------------------------------------------------
# Install Anaconda (silent, All Users, C:\Anaconda3)
# ------------------------------------------------------------
Write-Host "`nInstalling Anaconda (this takes 5-10 minutes)..." -ForegroundColor Yellow

$proc = Start-Process -FilePath $Installer -Wait -PassThru -ArgumentList @(
    "/S",
    "/InstallationType=AllUsers",
    "/RegisterPython=1",
    "/AddToPath=0",
    "/D=$InstallDir"
)

if ($proc.ExitCode -ne 0) {
    Write-Host "ERROR: Anaconda installer exited with code $($proc.ExitCode)" -ForegroundColor Red
    exit 1
}

Assert-FileExists "$InstallDir\python.exe"        "python.exe"
Assert-FileExists "$InstallDir\Scripts\conda.exe" "conda.exe"
Assert-FileExists "$InstallDir\Scripts\pip.exe"   "pip.exe"

# ------------------------------------------------------------
# Add Anaconda to SYSTEM PATH (idempotent)
# ------------------------------------------------------------
Write-Host "`nUpdating SYSTEM PATH..." -ForegroundColor Yellow
$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

foreach ($entry in $PathEntries) {
    if ($MachinePath -notlike "*$entry*") {
        $MachinePath += ";$entry"
        Write-Host "  Added: $entry" -ForegroundColor Green
    } else {
        Write-Host "  Already in PATH: $entry" -ForegroundColor Cyan
    }
}

[Environment]::SetEnvironmentVariable("Path", $MachinePath, "Machine")

# Update current session PATH so verification works immediately
$env:Path = ($PathEntries -join ";") + ";" + $env:Path

# ------------------------------------------------------------
# Initialize conda for PowerShell and CMD (all users)
# ------------------------------------------------------------
Write-Host "`nInitializing conda for PowerShell and CMD..." -ForegroundColor Yellow

& "$InstallDir\Scripts\conda.exe" init cmd.exe
& "$InstallDir\Scripts\conda.exe" init powershell

# Disable auto-activation of base env on shell start (best practice for servers)
& "$InstallDir\Scripts\conda.exe" config --system --set auto_activate_base false
Write-Host "  conda initialized. Auto-activate base: disabled." -ForegroundColor Green

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------
Write-Host "`nVerification" -ForegroundColor Green

Write-Host "`nPython version:" -ForegroundColor Cyan
& "$InstallDir\python.exe" --version

Write-Host "`nConda version:" -ForegroundColor Cyan
& "$InstallDir\Scripts\conda.exe" --version

Write-Host "`nConda info:" -ForegroundColor Cyan
& "$InstallDir\Scripts\conda.exe" info

Write-Host "`nPip version:" -ForegroundColor Cyan
& "$InstallDir\Scripts\pip.exe" --version

Write-Host "`nPATH entries added:" -ForegroundColor Cyan
[Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" |
    Where-Object { $_ -like "*Anaconda*" } |
    ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host "`nSUCCESS" -ForegroundColor Green
Write-Host "- Anaconda $AnacondaVersion installed at $InstallDir"
Write-Host "- Python, conda, pip registered system-wide"
Write-Host "- SYSTEM PATH updated with 5 Anaconda entries"
Write-Host "- conda initialized for PowerShell and CMD"
Write-Host "- Auto-activate base: disabled"
Write-Host ""
Write-Host "NOTES:" -ForegroundColor Cyan
Write-Host "  - Open a new shell for PATH changes to take effect" -ForegroundColor White
Write-Host "  - To create an env: conda create -n myenv python=3.12" -ForegroundColor White
Write-Host "  - To activate:      conda activate myenv" -ForegroundColor White