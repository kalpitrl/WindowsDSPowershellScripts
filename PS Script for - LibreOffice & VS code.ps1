# =============================================================================
# DEV TOOLS INSTALLER — Windows Server 2022
# Installs: VS Code + LibreOffice 26.2.1
# Run as Administrator
# =============================================================================

$ErrorActionPreference = "Stop"
$DownloadPath = "C:\Temp\DevTools"
$LogPath      = "C:\Temp\DevTools\Logs"

New-Item -ItemType Directory -Force -Path $DownloadPath | Out-Null
New-Item -ItemType Directory -Force -Path $LogPath      | Out-Null

$LogFile = "$LogPath\DevTools.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

Write-Log "========================================================"
Write-Log " DEV TOOLS INSTALLER"
Write-Log " VS Code + LibreOffice 26.2.1"
Write-Log "========================================================"

# ---------------------------------------------------------------------------
# URLs & destinations
# ---------------------------------------------------------------------------
$VSCUrl     = "https://update.code.visualstudio.com/latest/win32-x64-user/stable"
$LibreUrl   = "https://download.documentfoundation.org/libreoffice/stable/26.2.1/win/x86_64/LibreOffice_26.2.1_Win_x86-64.msi"

$VSCInstaller   = "$DownloadPath\VSCodeSetup.exe"
$LibreInstaller = "$DownloadPath\LibreOffice_26.2.1.msi"

# ---------------------------------------------------------------------------
# STEP 1 — Parallel downloads (both files simultaneously)
# ---------------------------------------------------------------------------
Write-Log "--- STEP 1: Parallel Downloads ---"
Write-Log "Downloading VS Code and LibreOffice simultaneously ..."

$downloads = @(
    @{ Label="VS Code";          Url=$VSCUrl;   Dest=$VSCInstaller   },
    @{ Label="LibreOffice 26.2.1"; Url=$LibreUrl; Dest=$LibreInstaller }
)

$jobs = foreach ($d in $downloads) {
    $label = $d.Label
    $url   = $d.Url
    $dest  = $d.Dest
    Start-Job -ScriptBlock {
        param($url, $dest, $label)
        try {
            Start-BitsTransfer -Source $url -Destination $dest
        } catch {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        }
        $sizeMB = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        "$label downloaded — $sizeMB MB"
    } -ArgumentList $url, $dest, $label
}

$jobs | Wait-Job | ForEach-Object {
    $result = Receive-Job -Job $_
    Write-Log $result
    Remove-Job -Job $_
}

Write-Log "All downloads complete."

# ---------------------------------------------------------------------------
# STEP 2 — Install VS Code
# ---------------------------------------------------------------------------
Write-Log "--- STEP 2: Installing VS Code ---"

$vscArgs = "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"

$proc = Start-Process -FilePath $VSCInstaller -ArgumentList $vscArgs -Wait -PassThru
Write-Log "VS Code exit code: $($proc.ExitCode)"

if ($proc.ExitCode -eq 0) {
    Write-Log "VS Code installed OK."
} else {
    Write-Log "VS Code installer returned exit code $($proc.ExitCode)." "WARN"
}

# ---------------------------------------------------------------------------
# STEP 3 — Install LibreOffice 26.2.1
# ---------------------------------------------------------------------------
Write-Log "--- STEP 3: Installing LibreOffice 26.2.1 ---"

$libreArgs = "/i `"$LibreInstaller`" /qn /norestart /log `"$LogPath\LibreOffice.log`""

$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $libreArgs -Wait -PassThru
Write-Log "LibreOffice exit code: $($proc.ExitCode)"

if ($proc.ExitCode -in @(0, 3010)) {
    Write-Log "LibreOffice 26.2.1 installed OK."
} else {
    Write-Log "LibreOffice exit code $($proc.ExitCode) — check $LogPath\LibreOffice.log" "WARN"
}

# ---------------------------------------------------------------------------
# STEP 4 — Add VS Code to system PATH
# ---------------------------------------------------------------------------
Write-Log "--- STEP 4: Updating system PATH ---"

$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$vsCodeBin   = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"

if ($currentPath -notlike "*Microsoft VS Code*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$vsCodeBin", "Machine")
    Write-Log "VS Code bin added to system PATH."
} else {
    Write-Log "VS Code already in system PATH — skipping."
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# ---------------------------------------------------------------------------
# STEP 5 — Verification
# ---------------------------------------------------------------------------
Write-Log "--- STEP 5: Verification ---"

# VS Code
if (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") {
    Write-Log "VS Code      : OK"
} else {
    Write-Log "VS Code      : NOT FOUND" "WARN"
}

# LibreOffice
$soffice = Get-ChildItem "C:\Program Files\LibreOffice\program" -Filter "soffice.exe" -ErrorAction SilentlyContinue
if ($soffice) {
    Write-Log "LibreOffice  : OK ($($soffice.FullName))"
} else {
    Write-Log "LibreOffice  : NOT FOUND" "WARN"
}

# ---------------------------------------------------------------------------
# DONE
# ---------------------------------------------------------------------------
Write-Log "========================================================"
Write-Log " INSTALL COMPLETE"
Write-Log " Log : $LogFile"
Write-Log "========================================================"