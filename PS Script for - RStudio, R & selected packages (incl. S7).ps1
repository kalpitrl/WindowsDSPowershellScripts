# ============================================================
# Install-R-and-RStudio-FIXED.ps1
# Windows Server 2022 | Run as Administrator
# R 4.5.3 + RStudio 2026.01.1+403
# Installs R packages incl. S7
# Adds to SYSTEM PATH (Windows-safe)
# ============================================================

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"   # Abort on any error

function Assert-FileExists {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        Write-Host "❌ ERROR: $Label not found at: $Path" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✔ $Label found." -ForegroundColor Green
}

Write-Host "📦 Installing R 4.5.3 and RStudio 2026.01.1+403" -ForegroundColor Green

# ------------------------------------------------------------
# Variables — update version strings here when upgrading
# ------------------------------------------------------------
$RVersion        = "4.5.3"
$RStudioVersion  = "2026.01.1-403"   # hyphen for filename; + is used in UI only

$TempDir         = "C:\Temp"
$RInstaller      = "$TempDir\R-$RVersion-win.exe"
$RStudioInstaller= "$TempDir\RStudio-$RStudioVersion.exe"

# FIX: R 4.5.3 is the current release; use /base/ for latest,
#      or /base/old/<version>/ for a specific older release.
$RUrl            = "https://cran.rstudio.com/bin/windows/base/R-$RVersion-win.exe"
$RStudioUrl      = "https://download1.rstudio.org/electron/windows/RStudio-$RStudioVersion.exe"

$RBaseDir        = "C:\Program Files\R\R-$RVersion"
$RBinDir         = "$RBaseDir\bin"
$RExe            = "$RBinDir\R.exe"
$Rscript         = "$RBinDir\Rscript.exe"

$RStudioDir      = "C:\Program Files\RStudio"
$RStudioExe      = "$RStudioDir\rstudio.exe"

# ------------------------------------------------------------
# Prep temp directory
# ------------------------------------------------------------
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# ------------------------------------------------------------
# Download R installer
# ------------------------------------------------------------
Write-Host "`n⬇️  Downloading R $RVersion installer..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $RUrl -OutFile $RInstaller -UseBasicParsing
} catch {
    Write-Host "❌ ERROR: Failed to download R installer." -ForegroundColor Red
    Write-Host "   URL tried: $RUrl" -ForegroundColor Red
    Write-Host "   Check https://cran.r-project.org/bin/windows/base/ for the current filename." -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor Red
    exit 1
}
Assert-FileExists $RInstaller "R installer"

# ------------------------------------------------------------
# Download RStudio installer
# ------------------------------------------------------------
Write-Host "`n⬇️  Downloading RStudio installer..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $RStudioUrl -OutFile $RStudioInstaller -UseBasicParsing
} catch {
    Write-Host "❌ ERROR: Failed to download RStudio installer." -ForegroundColor Red
    Write-Host "   URL tried: $RStudioUrl" -ForegroundColor Red
    Write-Host "   Check https://posit.co/download/rstudio-desktop/ for the current version." -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor Red
    exit 1
}
Assert-FileExists $RStudioInstaller "RStudio installer"

# ------------------------------------------------------------
# Install R (silent)
# ------------------------------------------------------------
Write-Host "`n🧩 Installing R $RVersion..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $RInstaller `
    -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" `
    -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Host "❌ ERROR: R installer exited with code $($proc.ExitCode)" -ForegroundColor Red
    exit 1
}
Assert-FileExists $RExe "R.exe"
Assert-FileExists $Rscript "Rscript.exe"

# ------------------------------------------------------------
# Install R packages (ABSOLUTE PATH – no PATH dependency)
# ------------------------------------------------------------
Write-Host "`n📦 Installing R packages (S7, tidyverse, data.table, ggplot2)..." -ForegroundColor Yellow
& $Rscript -e "install.packages(c('S7','tidyverse','data.table','ggplot2'), repos='https://cloud.r-project.org')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: R package installation failed (exit code $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------
# Install RStudio (silent)
# ------------------------------------------------------------
Write-Host "`n🧩 Installing RStudio $RStudioVersion..." -ForegroundColor Yellow
$proc2 = Start-Process -FilePath $RStudioInstaller `
    -ArgumentList "/S" `
    -Wait -PassThru
if ($proc2.ExitCode -ne 0) {
    Write-Host "❌ ERROR: RStudio installer exited with code $($proc2.ExitCode)" -ForegroundColor Red
    exit 1
}
Assert-FileExists $RStudioExe "rstudio.exe"

# ------------------------------------------------------------
# Add R & RStudio to SYSTEM PATH (idempotent)
# ------------------------------------------------------------
Write-Host "`n🔧 Updating SYSTEM PATH..." -ForegroundColor Yellow
$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($MachinePath -notlike "*$RBinDir*") {
    $MachinePath += ";$RBinDir"
    Write-Host "  ✔ Added R bin to PATH." -ForegroundColor Green
} else {
    Write-Host "  ℹ R bin already in PATH, skipping." -ForegroundColor Cyan
}

if ($MachinePath -notlike "*$RStudioDir*") {
    $MachinePath += ";$RStudioDir"
    Write-Host "  ✔ Added RStudio to PATH." -ForegroundColor Green
} else {
    Write-Host "  ℹ RStudio already in PATH, skipping." -ForegroundColor Cyan
}

[Environment]::SetEnvironmentVariable("Path", $MachinePath, "Machine")

# ------------------------------------------------------------
# Verification (ABSOLUTE PATH – works before PATH refresh)
# ------------------------------------------------------------
Write-Host "`n✅ Verification" -ForegroundColor Green

Write-Host "`nR version:" -ForegroundColor Cyan
& $RExe --version

Write-Host "`nRStudio version:" -ForegroundColor Cyan
& $RStudioExe --version

Write-Host "`nR package check (S7):" -ForegroundColor Cyan
& $Rscript -e "cat('S7 version:', as.character(packageVersion('S7')), '\n')"

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host "`n🎯 SUCCESS" -ForegroundColor Green
Write-Host "• R $RVersion installed at $RBaseDir"
Write-Host "• RStudio $RStudioVersion installed at $RStudioDir"
Write-Host "• R packages installed: S7, tidyverse, data.table, ggplot2"
Write-Host "• SYSTEM PATH updated (open a new shell/session to take effect)"