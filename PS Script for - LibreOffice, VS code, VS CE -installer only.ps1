# =====================================================
# Dev Tools Installation Script - Windows Server 2022
# FAST VERSION: VS Code + LibreOffice + VS Shell (15min total)
# =====================================================

$ErrorActionPreference = "Stop"
$DownloadPath = "C:\Temp\DevTools"
$LogPath = "$DownloadPath\Logs"

# Create directories
New-Item -ItemType Directory -Force -Path @($DownloadPath, $LogPath) | Out-Null

# URLs
$VSCUrl = "https://update.code.visualstudio.com/latest/win32-x64-user/stable"
$VSUrl = "https://aka.ms/vs/17/release/vs_Community.exe"
$LibreOfficeUrl = "https://download.documentfoundation.org/libreoffice/stable/25.2.7/win/x86_64/LibreOffice_25.2.7_Win_x86-64.msi"

$VSCInstaller = "$DownloadPath\VSCodeUserSetup.exe"
$VSInstaller = "$DownloadPath\vs_Community.exe"
$LibreOfficeInstaller = "$DownloadPath\LibreOffice.msi"

Write-Host "🚀 FAST DEV SETUP STARTING..." -ForegroundColor Green

# -------------------------------
# Download All Installers
# -------------------------------
$names = @("VS Code", "Visual Studio Shell", "LibreOffice")
$urls = @($VSCUrl, $VSUrl, $LibreOfficeUrl)
$files = @($VSCInstaller, $VSInstaller, $LibreOfficeInstaller)

for ($i = 0; $i -lt 3; $i++) {
    Write-Host "📥 Downloading $($names[$i])..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $urls[$i] -OutFile $files[$i] -UseBasicParsing
}

# Validate downloads
if ((Get-Item $LibreOfficeInstaller).Length -lt 100MB -or (Get-Item $VSCInstaller).Length -lt 50MB) {
    Throw "Download validation failed - files too small."
}

# -------------------------------
# Install VS Code (2min ✅)
# -------------------------------
Write-Host "⚡ Installing VS Code..." -ForegroundColor Yellow
Start-Process $VSCInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/MERGETASKS=!runcode" -Wait -NoNewWindow | Out-Null

$VSCPath = "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\Code.exe"
if (Test-Path $VSCPath) {
    Write-Host "✅ VS Code: $VSCPath" -ForegroundColor Green
} else {
    Throw "VS Code install failed."
}

# -------------------------------
# Install Visual Studio SHELL ONLY (10min ✅)
# NO heavy workloads - just core IDE + build tools
# -------------------------------
Write-Host "⚡ Installing Visual Studio SHELL (no workloads)..." -ForegroundColor Yellow

# Kill any existing VS process first
Stop-Process -Name "vs_Community" -Force -ErrorAction SilentlyContinue
Start-Sleep 3

$VSArgs_FAST = @(
    "--quiet",
    "--wait",
    "--norestart",
    "--nocache",
    "--installPath `"C:\Program Files\Microsoft Visual Studio\2022\Community`"",
    "--add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools",  # Compilers only (500MB)
    "--add Microsoft.VisualStudio.Workload.NetCoreBuildTools",        # .NET Core SDK tools
    "--includeRecommended",
    "--log `"$LogPath\VS-Fast.log`""
)

$VSProcess = Start-Process $VSInstaller -ArgumentList $VSArgs_FAST -Wait -NoNewWindow -PassThru
if ($VSProcess.ExitCode -eq 0 -or $VSProcess.ExitCode -eq 3010) {
    Write-Host "✅ Visual Studio Shell: Ready (check devenv.exe)" -ForegroundColor Green
} else {
    Write-Warning "VS Shell exit code: $($VSProcess.ExitCode) - may still work"
}

# -------------------------------
# Install LibreOffice (2min ✅)
# -------------------------------
Write-Host "⚡ Installing LibreOffice..." -ForegroundColor Yellow
Start-Process "msiexec.exe" -ArgumentList "/i `"$LibreOfficeInstaller`" /qn /norestart /log `"$LogPath\LibreOffice.log`"" -Wait -NoNewWindow | Out-Null

# -------------------------------
# FINAL VERIFICATION
# -------------------------------
Write-Host "`n🔍 VERIFICATION..." -ForegroundColor Cyan

# VS Code
if (Test-Path $VSCPath) { Write-Host "✅ VS Code: OK" -ForegroundColor Green } else { Write-Host "❌ VS Code: FAILED" -ForegroundColor Red }

# Visual Studio Shell
$VSPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
if (Test-Path $VSPath) { 
    Write-Host "✅ VS Shell: OK ($VSPath)" -ForegroundColor Green 
    Write-Host "   → Run: & '$VSPath'" -ForegroundColor Cyan
} else { 
    Write-Host "⚠️  VS Shell: Still installing..." -ForegroundColor Yellow 
}

# LibreOffice
$LibreCheck = Get-ChildItem "C:\Program Files*" -Recurse -Filter "soffice*.exe" -ErrorAction SilentlyContinue
if ($LibreCheck) { 
    Write-Host "✅ LibreOffice: OK ($($LibreCheck[0].Directory.FullName))" -ForegroundColor Green
} else { 
    Write-Host "❌ LibreOffice: FAILED" -ForegroundColor Red 
}

# Add VS Code to PATH permanently
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$NewPath = $CurrentPath + ";${env:LOCALAPPDATA}\Programs\Microsoft VS Code\bin"
[Environment]::SetEnvironmentVariable("Path", $NewPath, "Machine")
Write-Host "✅ VS Code added to system PATH" -ForegroundColor Green

Write-Host "`n🎉 FAST SETUP COMPLETE! Total time: ~15 minutes" -ForegroundColor Green
Write-Host "   → VS Code: 'code .'" -ForegroundColor Cyan
Write-Host "   → VS Shell: devenv.exe (if ready)" -ForegroundColor Cyan
Write-Host "   → LibreOffice: soffice.exe" -ForegroundColor Cyan
Write-Host "   → Reboot recommended: Restart-Computer -Force`n" -ForegroundColor Cyan

# Cleanup?
$cleanup = Read-Host "🗑️  Delete temp files? (y/n)"
if ($cleanup -match '^[Yy]') {
    Remove-Item -Path $DownloadPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Cleanup done!" -ForegroundColor Green
}
