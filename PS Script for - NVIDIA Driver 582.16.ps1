# =============================================================================
# SCRIPT 1 OF 2 — NVIDIA DATA CENTER DRIVER INSTALLATION
# Target: Windows Server 2022 | Tesla T4 (g4dn)
# Driver: 582.16 (Data Center / Tesla / DCH)
# Run as Administrator
#
# ⚠️  THIS SCRIPT WILL REBOOT THE MACHINE AT THE END.
# =============================================================================

$ErrorActionPreference = "Stop"
$LogPath  = "C:\Temp\GPU-Bootstrap.log"
$TempDir  = "C:\Temp\GPU-Install"

$DriverUrl       = "https://us.download.nvidia.com/tesla/582.16/582.16-data-center-tesla-desktop-winserver-2022-2025-dch-international.exe"
$DriverInstaller = "$TempDir\nvidia-driver-582.16.exe"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogPath -Value $line
    Write-Host $line
}

# ---------------------------------------------------------------------------
# Sanity-check: confirm we are on a GPU-capable instance
# (skips the check if nvidia-smi is not yet present — expected on fresh box)
# ---------------------------------------------------------------------------
Write-Log "========================================================"
Write-Log " GPU STACK BOOTSTRAP  —  SCRIPT 1 / 2"
Write-Log " NVIDIA Driver 582.16 Install"
Write-Log "========================================================"
Write-Log "Log file: $LogPath"

# ---------------------------------------------------------------------------
# STEP 1 — Download NVIDIA Data Center Driver 582.16
# ---------------------------------------------------------------------------
Write-Log "Downloading NVIDIA Data Center Driver 582.16 ..."
Write-Log "Source: $DriverUrl"

try {
    # Use BITS for large binary downloads — more reliable than Invoke-WebRequest on WS2022
    Start-BitsTransfer -Source $DriverUrl -Destination $DriverInstaller
    Write-Log "Download complete: $DriverInstaller"
} catch {
    Write-Log "BITS transfer failed, falling back to Invoke-WebRequest ..." "WARN"
    Invoke-WebRequest -Uri $DriverUrl -OutFile $DriverInstaller -UseBasicParsing
    Write-Log "Download complete (fallback): $DriverInstaller"
}

# Verify the file exists and has non-zero size
$fileSize = (Get-Item $DriverInstaller).Length
Write-Log "Downloaded file size: $([math]::Round($fileSize / 1MB, 1)) MB"
if ($fileSize -lt 100MB) {
    Write-Log "Downloaded file is suspiciously small. Check the URL or network access." "ERROR"
    exit 1
}

# ---------------------------------------------------------------------------
# STEP 2 — Silent Install (Clean Install)
# ---------------------------------------------------------------------------
# Flags:
#   -s          Silent mode
#   -clean      Performs a clean installation (wipes any old driver state)
#   -noreboot   Suppresses the installer's own reboot so we control timing
# ---------------------------------------------------------------------------
Write-Log "Installing NVIDIA Driver 582.16 (clean, silent) ..."
Write-Log "This may take 3-7 minutes — please wait ..."

$installArgs = "-s -clean -noreboot"

$proc = Start-Process `
    -FilePath $DriverInstaller `
    -ArgumentList $installArgs `
    -Wait `
    -PassThru

Write-Log "Installer exit code: $($proc.ExitCode)"

# Common exit codes:
#  0  = success
#  1  = already up to date (non-fatal)
# -1  = general failure
if ($proc.ExitCode -notin @(0, 1)) {
    Write-Log "Driver installer returned unexpected exit code: $($proc.ExitCode)" "ERROR"
    Write-Log "Check C:\NVIDIA\DisplayDriver\ logs for details." "ERROR"
    exit 1
}

Write-Log "NVIDIA Driver 582.16 installed successfully."

# ---------------------------------------------------------------------------
# STEP 3 — Quick Verify (nvidia-smi may not be on PATH yet; use full path)
# ---------------------------------------------------------------------------
$nvidiaSmiPath = "C:\Windows\System32\nvidia-smi.exe"
if (Test-Path $nvidiaSmiPath) {
    Write-Log "Running nvidia-smi pre-reboot check ..."
    & $nvidiaSmiPath | ForEach-Object { Write-Log $_ }
} else {
    Write-Log "nvidia-smi not yet on PATH (normal before first reboot) — skipping pre-reboot verify." "WARN"
}

# ---------------------------------------------------------------------------
# STEP 4 — Mark completion so Script 2 can detect it
# ---------------------------------------------------------------------------
$markerFile = "C:\Temp\GPU-Install\driver_installed.flag"
Set-Content -Path $markerFile -Value "NVIDIA Driver 582.16 installed on $(Get-Date)"
Write-Log "Marker file written: $markerFile"

# ---------------------------------------------------------------------------
# STEP 5 — Reboot (60-second countdown)
# ---------------------------------------------------------------------------
Write-Log "========================================================"
Write-Log " DRIVER INSTALL COMPLETE"
Write-Log " *** REBOOTING IN 60 SECONDS ***"
Write-Log " After reboot, run: 02_Install_CUDA_and_ML_Stack.ps1"
Write-Log "========================================================"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "  NVIDIA Driver 582.16 installed.                           " -ForegroundColor Yellow
Write-Host "  Machine will REBOOT in 60 seconds.                        " -ForegroundColor Yellow
Write-Host "  After reboot, run: 02_Install_CUDA_and_ML_Stack.ps1       " -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""

# Give time to read / cancel (Ctrl+C cancels the countdown, not the shutdown)
for ($i = 60; $i -ge 1; $i--) {
    Write-Host "Rebooting in $i seconds ... (Ctrl+C then 'shutdown /a' to abort)" -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}

shutdown /r /t 0 /c "NVIDIA Driver 582.16 installed - rebooting to activate driver"