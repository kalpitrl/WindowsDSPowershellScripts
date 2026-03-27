# ============================================================
# Install-AmazonDCV.ps1
# Windows Server 2022 | Run as Administrator
# Amazon DCV Server 2025.0-20177
# - Silent MSI install
# - Auto-console session configured for EC2 (Administrator)
# - QUIC frontend enabled (UDP 8443 for better performance)
# - DCV service set to auto-start
# - Windows Firewall rule added for port 8443
# NOTE: On AWS EC2, DCV licensing is automatic — no license file needed
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

Write-Host "📦 Installing Amazon DCV Server 2025.0-20177" -ForegroundColor Green

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
$DCVVersion      = "2025.0"
$DCVBuild        = "20103"
$MSIName         = "nice-dcv-server-x64-Release-$DCVVersion-$DCVBuild.msi"

$TempDir         = "C:\Temp"
$Installer       = "$TempDir\$MSIName"
$InstallLog      = "$TempDir\dcv-install.log"

# Official CloudFront CDN — used by all AWS DCV documentation
# Source page: https://www.amazondcv.com/
$Url             = "https://d1uj6qtbmh3dt5.cloudfront.net/$DCVVersion/Servers/$MSIName"

# Always-latest permalink (useful reference, but NOT used here — pinned version preferred for Image Builder)
# $Url = "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-server-x64-Release.msi"

$DCVInstallDir   = "C:\Program Files\NICE\DCV\Server"
$DCVService      = "dcvserver"
$DCVPort         = 8443

# ------------------------------------------------------------
# Prep temp directory
# ------------------------------------------------------------
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# ------------------------------------------------------------
# Download DCV Server MSI
# ------------------------------------------------------------
Write-Host "`n⬇️  Downloading Amazon DCV Server $DCVVersion-$DCVBuild..." -ForegroundColor Yellow
Write-Host "   URL: $Url" -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $Url -OutFile $Installer -UseBasicParsing
} catch {
    Write-Host "❌ ERROR: Failed to download Amazon DCV installer." -ForegroundColor Red
    Write-Host "   URL tried: $Url" -ForegroundColor Red
    Write-Host "   Check https://www.amazondcv.com/ for the latest version." -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor Red
    exit 1
}
Assert-FileExists $Installer "Amazon DCV MSI"

# ------------------------------------------------------------
# Install Amazon DCV Server (silent)
# ------------------------------------------------------------
Write-Host "`n🧩 Installing Amazon DCV Server..." -ForegroundColor Yellow
Write-Host "   Log: $InstallLog" -ForegroundColor Gray

$proc = Start-Process -FilePath "msiexec.exe" `
    -ArgumentList "/i `"$Installer`" /quiet /norestart /l*v `"$InstallLog`"" `
    -Wait -PassThru

if ($proc.ExitCode -ne 0) {
    Write-Host "❌ ERROR: DCV installer exited with code $($proc.ExitCode)" -ForegroundColor Red
    Write-Host "   Check log at: $InstallLog" -ForegroundColor Red
    exit 1
}
Assert-FileExists "$DCVInstallDir\bin\dcv.exe" "dcv.exe"

# ------------------------------------------------------------
# Post-install registry configuration (EC2-specific)
# These keys configure DCV behaviour at the SYSTEM account level,
# which is how the dcvserver service runs on Windows.
# ------------------------------------------------------------
Write-Host "`n🔧 Configuring DCV registry settings..." -ForegroundColor Yellow

$RegBase = "HKLM:\SOFTWARE\GSettings\com\nicesoftware\dcv"

# Ensure registry paths exist
$RegPaths = @(
    "$RegBase\session-management",
    "$RegBase\session-management\automatic-console-session",
    "$RegBase\connectivity"
)
foreach ($path in $RegPaths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
}

# Auto-create console session owned by Administrator (required for EC2 Image Builder AMIs)
Set-ItemProperty -Path "$RegBase\session-management" `
    -Name "create-session" -Value 1 -Type DWord
Write-Host "  ✔ Auto-session creation enabled." -ForegroundColor Green

Set-ItemProperty -Path "$RegBase\session-management\automatic-console-session" `
    -Name "owner" -Value "Administrator" -Type String
Write-Host "  ✔ Console session owner set to Administrator." -ForegroundColor Green

# Set session storage root
Set-ItemProperty -Path "$RegBase\session-management\automatic-console-session" `
    -Name "storage-root" -Value "C:/Users/Administrator/" -Type String
Write-Host "  ✔ Session storage root set." -ForegroundColor Green

# Enable QUIC frontend (UDP 8443) — better performance than TCP alone
Set-ItemProperty -Path "$RegBase\connectivity" `
    -Name "enable-quic-frontend" -Value 1 -Type DWord
Write-Host "  ✔ QUIC frontend (UDP 8443) enabled." -ForegroundColor Green

# ------------------------------------------------------------
# Windows Firewall — open port 8443 (TCP + UDP)
# ------------------------------------------------------------
Write-Host "`n🔥 Configuring Windows Firewall for port $DCVPort..." -ForegroundColor Yellow

# Remove stale rules first (idempotent)
netsh advfirewall firewall delete rule name="Amazon DCV TCP 8443" 2>$null
netsh advfirewall firewall delete rule name="Amazon DCV UDP 8443" 2>$null

netsh advfirewall firewall add rule `
    name="Amazon DCV TCP 8443" `
    dir=in action=allow protocol=TCP localport=$DCVPort
netsh advfirewall firewall add rule `
    name="Amazon DCV UDP 8443" `
    dir=in action=allow protocol=UDP localport=$DCVPort

Write-Host "  ✔ Firewall rules added for TCP and UDP port $DCVPort." -ForegroundColor Green

# ------------------------------------------------------------
# Set DCV service to auto-start
# ------------------------------------------------------------
Write-Host "`n⚙️  Setting DCV service to auto-start..." -ForegroundColor Yellow
Set-Service -Name $DCVService -StartupType Automatic
Write-Host "  ✔ Service '$DCVService' set to Automatic." -ForegroundColor Green

# Restart service so registry keys take effect immediately
Stop-Service -Name $DCVService -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Service -Name $DCVService
Start-Sleep -Seconds 5   # Give service time to fully start before creating session
Write-Host "  ✔ Service '$DCVService' restarted with new config." -ForegroundColor Green

# ------------------------------------------------------------
# Create console session now (so it's immediately usable)
# ------------------------------------------------------------
Write-Host "`n🖥️  Creating DCV console session..." -ForegroundColor Yellow
$dcvExe = "$DCVInstallDir\bin\dcv.exe"

# Close existing console session if any (idempotent)
& $dcvExe close-session console 2>$null

# Create a new console session owned by Administrator
& $dcvExe create-session `
    --type=console `
    --owner Administrator `
    console

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: Failed to create DCV console session." -ForegroundColor Red
    exit 1
}
Write-Host "  ✔ Console session created (owner: Administrator)." -ForegroundColor Green

# ------------------------------------------------------------
# Scheduled Task — recreate session on every boot
# Ensures session survives reboots when launched from AMI
# ------------------------------------------------------------
Write-Host "`n📅 Registering boot-time session task..." -ForegroundColor Yellow

$TaskName   = "DCVCreateConsoleSession"
$TaskScript = "C:\Windows\System32\dcv-create-session.ps1"

# Write the session-creation script
@"
Start-Sleep -Seconds 15   # Wait for dcvserver service to fully start
`$dcv = 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe'
& `$dcv close-session console 2>`$null
& `$dcv create-session --type=console --owner Administrator console
"@ | Set-Content -Path $TaskScript -Encoding UTF8

# Remove old task if exists (idempotent)
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Register new task — runs as SYSTEM at every boot
$Action   = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-NonInteractive -WindowStyle Hidden -File `"$TaskScript`""
$Trigger  = New-ScheduledTaskTrigger -AtStartup
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$Principal= New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask `
    -TaskName  $TaskName `
    -Action    $Action `
    -Trigger   $Trigger `
    -Settings  $Settings `
    -Principal $Principal `
    -Force | Out-Null

Write-Host "  ✔ Boot task '$TaskName' registered (runs as SYSTEM)." -ForegroundColor Green

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------
Write-Host "`n✅ Verification" -ForegroundColor Green

# Service status
$svc = Get-Service -Name $DCVService
Write-Host "`nDCV service status:" -ForegroundColor Cyan
Write-Host "  Status  : $($svc.Status)"
Write-Host "  Startup : $($svc.StartType)"

if ($svc.Status -ne "Running") {
    Write-Host "❌ ERROR: DCV service is not running!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✔ Service is running." -ForegroundColor Green

# DCV version
Write-Host "`nDCV version:" -ForegroundColor Cyan
& "$DCVInstallDir\bin\dcv.exe" version

# List active sessions
Write-Host "`nDCV sessions:" -ForegroundColor Cyan
& "$DCVInstallDir\bin\dcv.exe" list-sessions

# Firewall rules
Write-Host "`nFirewall rules for port $DCVPort`:" -ForegroundColor Cyan
netsh advfirewall firewall show rule name="Amazon DCV TCP 8443" | Select-String "Enabled|Action|Protocol|LocalPort"
netsh advfirewall firewall show rule name="Amazon DCV UDP 8443" | Select-String "Enabled|Action|Protocol|LocalPort"

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host "`n🎯 SUCCESS" -ForegroundColor Green
Write-Host "• Amazon DCV Server $DCVVersion-$DCVBuild installed"
Write-Host "• Auto-console session configured (owner: Administrator)"
Write-Host "• QUIC frontend enabled (UDP + TCP port $DCVPort)"
Write-Host "• Windows Firewall opened on port $DCVPort (TCP + UDP)"
Write-Host "• Service '$DCVService' running and set to auto-start"
Write-Host ""
Write-Host "ℹ  EC2 NOTES:" -ForegroundColor Cyan
Write-Host "   • Ensure Security Group inbound rule allows TCP+UDP port 8443 from your IP" -ForegroundColor White
Write-Host "   • Licensing is automatic on EC2 — no license file needed" -ForegroundColor White
Write-Host "   • Connect using: https://<instance-ip>:8443 or the DCV Client app" -ForegroundColor White