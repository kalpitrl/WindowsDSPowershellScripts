# ================================================
# SCRIPT 2: Install Docker Compose (Standalone)
# ================================================

$ErrorActionPreference = "Stop"

$ComposeVersion = "v2.27.0"
$InstallDir = "C:\Program Files\Docker"
$ComposePath = "$InstallDir\docker-compose.exe"

Write-Host "Installing Docker Compose..."

# Ensure directory exists
if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

# Download Compose
Invoke-WebRequest `
    -Uri "https://github.com/docker/compose/releases/download/$ComposeVersion/docker-compose-windows-x86_64.exe" `
    -OutFile $ComposePath

# Add to PATH if not already present
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($currentPath -notlike "*C:\Program Files\Docker*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$currentPath;C:\Program Files\Docker",
        "Machine"
    )
}

Write-Host "Docker Compose installed successfully"

# Validate
docker-compose --version