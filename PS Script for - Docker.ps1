# ================================================
# SCRIPT 1: Install Docker Engine (Windows Server)
# ================================================

$ErrorActionPreference = "Stop"

$TempDir = "C:\Installers"
$ScriptPath = "$TempDir\install-docker-ce.ps1"

# Create temp dir
if (!(Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

Write-Host "Downloading Docker install script..."

Invoke-WebRequest `
    -UseBasicParsing `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -OutFile $ScriptPath

Write-Host "Running Docker install script..."

Set-ExecutionPolicy Bypass -Scope Process -Force
& $ScriptPath

# Script will AUTO REBOOT here