# ============================================================
# Install-R-and-RStudio-FINAL.ps1
# Windows Server 2022 | Run as Administrator
# R 4.5.2 + RStudio 2026.01.0-392
# Installs R packages incl. S7
# Adds to SYSTEM PATH (Windows-safe)
# ============================================================

Write-Host "📦 Installing R 4.5.2 and RStudio 2026.01.0-392" -ForegroundColor Green

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
$TempDir = "C:\Temp"
$RInstaller = "$TempDir\R-4.5.2-win.exe"
$RStudioInstaller = "$TempDir\RStudio-2026.01.0-392.exe"

$RUrl = "https://cran.rstudio.com/bin/windows/base/R-4.5.2-win.exe"
$RStudioUrl = "https://download1.rstudio.org/electron/windows/RStudio-2026.01.0-392.exe"

$RBaseDir = "C:\Program Files\R\R-4.5.2"
$RBinDir  = "$RBaseDir\bin"
$RExe     = "$RBinDir\R.exe"
$Rscript  = "$RBinDir\Rscript.exe"

$RStudioDir = "C:\Program Files\RStudio"
$RStudioExe = "$RStudioDir\rstudio.exe"

# ------------------------------------------------------------
# Prep
# ------------------------------------------------------------
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# ------------------------------------------------------------
# Download installers
# ------------------------------------------------------------
Write-Host "⬇️ Downloading R installer..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $RUrl -OutFile $RInstaller -UseBasicParsing

Write-Host "⬇️ Downloading RStudio installer..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $RStudioUrl -OutFile $RStudioInstaller -UseBasicParsing

# ------------------------------------------------------------
# Install R (silent)
# ------------------------------------------------------------
Write-Host "🧩 Installing R 4.5.2..." -ForegroundColor Yellow
Start-Process -FilePath $RInstaller `
    -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" `
    -Wait

# ------------------------------------------------------------
# Install R packages (ABSOLUTE PATH – no PATH dependency)
# ------------------------------------------------------------
Write-Host "📦 Installing R packages (S7, tidyverse, data.table, ggplot2)..." -ForegroundColor Yellow

& $Rscript `
  -e "install.packages(c('S7','tidyverse','data.table','ggplot2'), repos='https://cloud.r-project.org')"

# ------------------------------------------------------------
# Install RStudio (silent)
# ------------------------------------------------------------
Write-Host "🧩 Installing RStudio 2026.01.0-392..." -ForegroundColor Yellow
Start-Process -FilePath $RStudioInstaller `
    -ArgumentList "/S" `
    -Wait

# ------------------------------------------------------------
# Add R & RStudio to SYSTEM PATH (idempotent)
# ------------------------------------------------------------
Write-Host "🔧 Updating SYSTEM PATH..." -ForegroundColor Yellow

$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($MachinePath -notlike "*$RBinDir*") {
    $MachinePath += ";$RBinDir"
}

if ($MachinePath -notlike "*$RStudioDir*") {
    $MachinePath += ";$RStudioDir"
}

[Environment]::SetEnvironmentVariable("Path", $MachinePath, "Machine")

# ------------------------------------------------------------
# Verification (Windows-safe)
# ------------------------------------------------------------
Write-Host "`n✅ Verification" -ForegroundColor Green

Write-Host "`nR version:" -ForegroundColor Cyan
& $RExe --version

Write-Host "`nRStudio version:" -ForegroundColor Cyan
& $RStudioExe --version

Write-Host "`nR package check (S7):" -ForegroundColor Cyan
& $Rscript -e "packageVersion('S7')"

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host "`n🎯 SUCCESS" -ForegroundColor Green
Write-Host "• R 4.5.2 installed"
Write-Host "• RStudio 2026.01.0-392 installed"
Write-Host "• R packages installed: S7, tidyverse, data.table, ggplot2"
Write-Host "• SYSTEM PATH updated (effective in new shells)"
