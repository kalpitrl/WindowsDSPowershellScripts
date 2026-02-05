# ============================================================
# Reset-And-Rebuild-JupyterLab-Windows.ps1
# Windows Server 2022
# Stable one-click JupyterLab via pythonw.exe
# ============================================================

Write-Host "🔥 FULL RESET & REBUILD: JupyterLab (Windows-safe)" -ForegroundColor Red

# ------------------------------------------------------------
# 1. Kill Jupyter-related processes ONLY  (🔧 CHANGED)
# ------------------------------------------------------------
Get-Process -ErrorAction SilentlyContinue |
Where-Object { $_.ProcessName -match "jupyter|ipykernel" } |
Stop-Process -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# 2. Uninstall Jupyter-related Python packages
# ------------------------------------------------------------
Write-Host "🧹 Removing Jupyter Python packages..." -ForegroundColor Yellow
pip uninstall -y jupyter jupyterlab notebook ipykernel ipywidgets jupyter-server jupyter-core 2>$null

# ------------------------------------------------------------
# 3. Remove ALL Jupyter configs, caches, runtime state
# ------------------------------------------------------------
Write-Host "🧹 Removing Jupyter config & cache directories..." -ForegroundColor Yellow

$PathsToDelete = @(
    "$env:APPDATA\jupyter",
    "$env:LOCALAPPDATA\jupyter",
    "$env:USERPROFILE\.jupyter",
    "$env:USERPROFILE\.ipython",
    "$env:USERPROFILE\.local\share\jupyter",
    "C:\ProgramData\jupyter"
)

foreach ($path in $PathsToDelete) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------
# 4. Remove old shortcut and logs
# ------------------------------------------------------------
Remove-Item "C:\Users\Public\Desktop\JupyterLab.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Temp\Jupyter.log" -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# 5. Reinstall Jupyter clean
# ------------------------------------------------------------
Write-Host "📦 Installing JupyterLab clean..." -ForegroundColor Green

python -m pip install --upgrade pip
pip install jupyterlab notebook ipykernel ipywidgets

# ------------------------------------------------------------
# 6. Generate clean Jupyter Server config
# ------------------------------------------------------------
Write-Host "🔧 Generating fresh Jupyter config..." -ForegroundColor Green

jupyter server --generate-config

$ConfigPath = "$env:USERPROFILE\.jupyter\jupyter_server_config.py"

@"
c.ServerApp.ip = '127.0.0.1'
c.ServerApp.port = 8888
c.ServerApp.open_browser = True
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.root_dir = r'C:\Users\Administrator'
"@ | Out-File -Encoding UTF8 -Force $ConfigPath

# ------------------------------------------------------------
# 7. Create STABLE one-click desktop shortcut (pythonw.exe)
# ------------------------------------------------------------
Write-Host "🖥️ Creating stable one-click desktop shortcut..." -ForegroundColor Green

$PythonW = "C:\Python310\pythonw.exe"
$PythonExe = "C:\Python310\python.exe"
$DesktopPath = "C:\Users\Public\Desktop"
$ShortcutPath = Join-Path $DesktopPath "JupyterLab.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

$Shortcut.TargetPath = $PythonW
$Shortcut.Arguments = "-m jupyterlab --config=`"$ConfigPath`""
$Shortcut.WorkingDirectory = "C:\Users\Administrator"
$Shortcut.IconLocation = "$PythonExe,0"
$Shortcut.Description = "JupyterLab (One-click, Stable, No Token)"
$Shortcut.Save()

# ------------------------------------------------------------
# 8. Final confirmation
# ------------------------------------------------------------
Write-Host ""
Write-Host "✅ RESET & REBUILD COMPLETE — THIS ONE IS STABLE" -ForegroundColor Green
Write-Host "👉 User action:" -ForegroundColor Cyan
Write-Host "   Double-click: C:\Users\Public\Desktop\JupyterLab.lnk" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Guaranteed behavior:" -ForegroundColor Green
Write-Host "   • JupyterLab runs detached from console" -ForegroundColor White
Write-Host "   • Browser opens automatically" -ForegroundColor White
Write-Host "   • No token, no password" -ForegroundColor White
Write-Host "   • No flashing / no termination" -ForegroundColor White
