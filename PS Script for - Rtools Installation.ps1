# ============================================================
# Install-Rtools45.ps1
# Windows Server 2022 | Run as Administrator
# Rtools45 (build 6768) — required for R 4.5.x
# Installs to C:\rtools45 (CRAN default)
# Adds compiler toolchain + build utils to SYSTEM PATH
# ============================================================

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-FileExists {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        Write-Host "❌ ERROR: $Label not found at: $Path" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✔ $Label found." -ForegroundColor Green
}

function Assert-CommandWorks {
    param([string]$Exe, [string]$Args, [string]$Label)
    try {
        $out = & $Exe $Args.Split(" ") 2>&1
        Write-Host "  ✔ $Label : $($out | Select-Object -First 1)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $Label not working: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host "📦 Installing Rtools45 (build 6768) for R 4.5.x" -ForegroundColor Green

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
$RtoolsVersion   = "6768"
$RtoolsInnerVer  = "6492"   # inner MSYS2 build number

$TempDir         = "C:\Temp"
$InstallerName   = "rtools45-$RtoolsVersion-$RtoolsInnerVer.exe"
$Installer       = "$TempDir\$InstallerName"

# Primary: official CRAN versioned URL (pinned, stable for Image Builder)
# Source page: https://cran.r-project.org/bin/windows/Rtools/rtools45/rtools.html
$Url             = "https://cran.r-project.org/bin/windows/Rtools/rtools45/files/$InstallerName"

# Fallback comment: for always-latest use:
# $Url = "https://github.com/r-hub/rtools45/releases/download/latest/rtools45.exe"

$RtoolsDir       = "C:\rtools45"

# Both PATH entries required by R / R CMD build:
#   1. Compiler toolchain (gcc, g++, gfortran)
#   2. Build utilities   (make, bash, tar, sed)
$PathCompiler    = "$RtoolsDir\x86_64-w64-mingw32.static.posix\bin"
$PathBuildUtils  = "$RtoolsDir\usr\bin"

# R must already be installed for the verify step
$Rscript         = "C:\Program Files\R\R-4.5.3\bin\Rscript.exe"

# ------------------------------------------------------------
# Prep temp directory
# ------------------------------------------------------------
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# ------------------------------------------------------------
# Download Rtools45 installer
# ------------------------------------------------------------
Write-Host "`n⬇️  Downloading Rtools45 build $RtoolsVersion..." -ForegroundColor Yellow
Write-Host "   URL: $Url" -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $Url -OutFile $Installer -UseBasicParsing
} catch {
    Write-Host "❌ ERROR: Failed to download Rtools45 installer." -ForegroundColor Red
    Write-Host "   URL tried: $Url" -ForegroundColor Red
    Write-Host "   Check https://cran.r-project.org/bin/windows/Rtools/rtools45/files/ for the latest filename." -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor Red
    exit 1
}
Assert-FileExists $Installer "Rtools45 installer"

# ------------------------------------------------------------
# Install Rtools45 (silent, default location C:\rtools45)
# ------------------------------------------------------------
Write-Host "`n🧩 Installing Rtools45..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes (~450 MB installer, ~3 GB installed)" -ForegroundColor Gray

$proc = Start-Process -FilePath $Installer `
    -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" `
    -Wait -PassThru

if ($proc.ExitCode -ne 0) {
    Write-Host "❌ ERROR: Rtools45 installer exited with code $($proc.ExitCode)" -ForegroundColor Red
    exit 1
}

# Verify install directory and key binaries exist
Assert-FileExists $RtoolsDir                          "Rtools45 directory"
Assert-FileExists "$PathCompiler\gcc.exe"             "gcc (C compiler)"
Assert-FileExists "$PathCompiler\g++.exe"             "g++ (C++ compiler)"
Assert-FileExists "$PathCompiler\gfortran.exe"        "gfortran (Fortran compiler)"
Assert-FileExists "$PathBuildUtils\make.exe"          "make"
Assert-FileExists "$PathBuildUtils\bash.exe"          "bash"

# ------------------------------------------------------------
# Add Rtools45 to SYSTEM PATH (idempotent)
# ------------------------------------------------------------
Write-Host "`n🔧 Updating SYSTEM PATH..." -ForegroundColor Yellow
$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($MachinePath -notlike "*$PathCompiler*") {
    $MachinePath += ";$PathCompiler"
    Write-Host "  ✔ Added compiler toolchain to PATH." -ForegroundColor Green
} else {
    Write-Host "  ℹ Compiler toolchain already in PATH, skipping." -ForegroundColor Cyan
}

if ($MachinePath -notlike "*$PathBuildUtils*") {
    $MachinePath += ";$PathBuildUtils"
    Write-Host "  ✔ Added build utilities to PATH." -ForegroundColor Green
} else {
    Write-Host "  ℹ Build utilities already in PATH, skipping." -ForegroundColor Cyan
}

[Environment]::SetEnvironmentVariable("Path", $MachinePath, "Machine")

# Also update the current session's PATH so verification works immediately
$env:Path += ";$PathCompiler;$PathBuildUtils"

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------
Write-Host "`n✅ Verification" -ForegroundColor Green

Write-Host "`nCompiler versions:" -ForegroundColor Cyan
Assert-CommandWorks "$PathCompiler\gcc.exe"      "--version" "gcc"
Assert-CommandWorks "$PathCompiler\g++.exe"      "--version" "g++"
Assert-CommandWorks "$PathCompiler\gfortran.exe" "--version" "gfortran"
Assert-CommandWorks "$PathBuildUtils\make.exe"   "--version" "make"

Write-Host "`nR + Rtools integration check:" -ForegroundColor Cyan
if (Test-Path $Rscript) {
    & $Rscript -e "cat('Rtools on PATH:', as.character(pkgbuild::has_rtools()), '\n')" 2>$null
    if ($LASTEXITCODE -ne 0) {
        # pkgbuild may not be installed — fall back to basic check
        & $Rscript -e "cat('R sees Rtools:', nchar(Sys.which('make')) > 0, '\n')"
    }
} else {
    Write-Host "  ℹ Rscript not found at expected path — skipping R integration check." -ForegroundColor Cyan
    Write-Host "    (R must be installed at C:\Program Files\R\R-4.5.3 for this check)" -ForegroundColor Gray
}

Write-Host "`nPATH entries added:" -ForegroundColor Cyan
[Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" |
    Where-Object { $_ -like "*rtools*" } |
    ForEach-Object { Write-Host "  • $_" -ForegroundColor White }

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host "`n🎯 SUCCESS" -ForegroundColor Green
Write-Host "• Rtools45 build $RtoolsVersion installed at $RtoolsDir"
Write-Host "• Compiler toolchain: gcc, g++, gfortran (GCC 14)"
Write-Host "• Build utilities: make, bash, tar, sed"
Write-Host "• SYSTEM PATH updated (open a new shell/session to take effect)"
Write-Host ""
Write-Host "ℹ NOTE: Rtools45 is only needed to install R packages from source." -ForegroundColor Cyan
Write-Host "  Binary packages from CRAN install fine without it." -ForegroundColor Cyan