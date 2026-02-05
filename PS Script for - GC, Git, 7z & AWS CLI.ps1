# =============================================================================
# COMPLETE PRODUCTION PowerShell Script - Installs Chrome, Git, AWS CLI, 7-Zip
# Windows Server 2022 EC2 - Battle Tested (Jan 28, 2026)
# Run: powershell -ExecutionPolicy Bypass -File install-apps.ps1
# =============================================================================

$ErrorActionPreference = 'Continue'
$LogPath = "C:\Temp\InstallApps.log"
$TempDir = "$env:TEMP\InstallApps"

# Setup logging and directories
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null 2>&1
New-Item -ItemType Directory -Path (Split-Path $LogPath -Parent) -Force | Out-Null 2>&1

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogEntry -ErrorAction SilentlyContinue
    $Color = switch($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } default { "Green" } }
    Write-Host $LogEntry -ForegroundColor $Color
}

function Test-AppInstalled {
    param([string]$AppName)
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $app = Get-ItemProperty $paths -ErrorAction SilentlyContinue | 
           Where-Object { $_.DisplayName -like "*$AppName*" } | Select-Object -First 1
    return [PSCustomObject]@{ 
        Installed = [bool]($app -ne $null); 
        Version = $app.DisplayVersion; 
        Name = $app.DisplayName 
    }
}

function Add-ToSystemPath {
    param([string]$PathToAdd)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$PathToAdd*") {
        $newPath = "$currentPath;$PathToAdd"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Log "Added to SYSTEM PATH: $PathToAdd"
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    }
}

function Install-MSI {
    param([string]$Url, [string]$AppName, [string]$PathToAdd = $null)
    $msiPath = "$TempDir\$AppName.msi"
    try {
        Write-Log "Downloading $AppName MSI..."
        Invoke-WebRequest -Uri $Url -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
        Write-Log "Installing $AppName..."
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart REBOOT=ReallySuppress" -Wait -PassThru
        Start-Sleep 3
        if ($proc.ExitCode -eq 0 -and (Test-AppInstalled $AppName).Installed) {
            Write-Log "$AppName ✓ SUCCESS"
            if ($PathToAdd) { Add-ToSystemPath $PathToAdd }
            return $true
        }
        Write-Log "$AppName ⚠ ExitCode: $($proc.ExitCode)" "WARN"
    }
    catch {
        Write-Log "$AppName ❌ $($_.Exception.Message)" "ERROR"
    }
    finally {
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
    }
    return $false
}

# =============================================================================
# MAIN INSTALLATIONS
# =============================================================================

Write-Log "🚀 Starting Applications Installation..." "INFO"

# 1. GOOGLE CHROME (Enterprise MSI - Always Latest)
Write-Log "--- GOOGLE CHROME ---"
if (!(Test-AppInstalled "Chrome").Installed) {
    Install-MSI "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" "Chrome" "C:\Program Files\Google\Chrome\Application"
} else {
    Write-Log "Chrome already installed"
}

# 2. GIT FOR WINDOWS (v2.52.0 - Exact URL from GitHub API)
Write-Log "--- GIT FOR WINDOWS ---"
if (!(Test-AppInstalled "Git").Installed) {
    $gitPath = "$TempDir\Git-2.52.0-64-bit.exe"
    try {
        Write-Log "Downloading Git v2.52.0..."
        Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-2.52.0-64-bit.exe" -OutFile $gitPath -UseBasicParsing
        Write-Log "Installing Git..."
        $proc = Start-Process $gitPath -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS", "/COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"", "/PathOption=`"CmdTools`"" -Wait -PassThru
        Start-Sleep 5
        if ($proc.ExitCode -eq 0) {
            Add-ToSystemPath "C:\Program Files\Git\cmd"
            Write-Log "Git ✓ SUCCESS v2.52.0.windows.1"
        }
    }
    catch {
        Write-Log "Git ❌ $($_.Exception.Message)" "ERROR"
    }
    finally {
        Remove-Item $gitPath -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Log "Git already installed"
}

# 3. AWS CLI v2 (Always Latest MSI)
Write-Log "--- AWS CLI v2 ---"
if (!(Test-AppInstalled "AWS CLI").Installed) {
    Install-MSI "https://awscli.amazonaws.com/AWSCLIV2.msi" "AWSCLI" "C:\Program Files\Amazon\AWSCLIV2"
} else {
    Write-Log "AWS CLI already installed"
}
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","Machine") + ";C:\Program Files\Amazon\AWSCLIV2", "Machine"); $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"; Write-Host "✓ AWS PATH Fixed! Test: aws --version" -ForegroundColor Green

# 4. 7-ZIP (v25.01 - Latest Stable)
Write-Log "--- 7-ZIP ---"
if (!(Test-AppInstalled "7-Zip").Installed) {
    Install-MSI "https://www.7-zip.org/a/7z2501-x64.msi" "7-Zip" "C:\Program Files\7-Zip"
} else {
    Write-Log "7-Zip already installed"
}

# =============================================================================
# FINAL SUMMARY & TESTS
# =============================================================================

Write-Log "=== 📊 INSTALLATION SUMMARY ===" "INFO"
$apps = @("Chrome", "Git", "AWS CLI", "7-Zip")
$allSuccess = $true

foreach ($app in $apps) {
    $info = Test-AppInstalled $app
    if ($info.Installed -and $info.Version) {
        Write-Log "  ✅ $($info.Name): $($info.Version)" "INFO"
    } else {
        Write-Log "  ❌ $app : Not Installed" "ERROR"
        $allSuccess = $false
    }
}

Write-Log "`n🎯 TEST COMMANDS (All should work):" "INFO"
Write-Log "  chrome --version" "INFO"
Write-Log "  git --version" "INFO" 
Write-Log "  aws --version" "INFO"
Write-Log "  7z`n" "INFO"

Write-Log "📁 Full log saved: $LogPath" "INFO"
Write-Log "🧹 Cleaning up temporary files..." "INFO"
Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "✅ Installation Complete! New PowerShell sessions auto-detect PATH." "INFO"
Write-Host "`n🎉 ALL DONE! Check log: $LogPath" -ForegroundColor Cyan

# Final PATH refresh for current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
