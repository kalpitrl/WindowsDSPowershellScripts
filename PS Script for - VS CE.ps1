# ================================================
# Visual Studio 2022 Community - FIXED INSTALL
# ================================================

$ErrorActionPreference = "Stop"

$TempDir = "C:\Installers"
$Installer = "$TempDir\vs_community.exe"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (!(Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

Write-Host "Downloading VS installer..."

Invoke-WebRequest `
    -Uri "https://aka.ms/vs/17/release/vs_Community.exe" `
    -OutFile $Installer

Write-Host "Installing Visual Studio..."

$arguments = @(
    "--passive",
    "--wait",
    "--norestart",

    "--installPath `"C:\Program Files\Microsoft Visual Studio\2022\Community`"",

    # ✅ VALID workloads (tested)
    "--add Microsoft.VisualStudio.Workload.ManagedDesktop",
    "--add Microsoft.VisualStudio.Workload.NetWeb",

    "--includeRecommended"
)

$process = Start-Process -FilePath $Installer -ArgumentList $arguments -Wait -PassThru

Write-Host "Exit Code: $($process.ExitCode)"

if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
    Write-Host "SUCCESS: VS Installed"
} else {
    Write-Host "FAILED: Exit Code $($process.ExitCode)"
    exit 1
}