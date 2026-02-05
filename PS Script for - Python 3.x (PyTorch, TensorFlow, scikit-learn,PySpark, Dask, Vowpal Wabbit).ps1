# =============================================================================
# ML ENVIRONMENT BOOTSTRAP - Windows Server 2022 (NO PYTHON PREINSTALLED)
# Python 3.11 + Latest Compatible ML Stack
# Run as Administrator
# IMP: Installation of vowpalwabbit on Windows needs Visual Studio Build Tools 
# =============================================================================

$ErrorActionPreference = "Stop"
$LogPath = "C:\Temp\PythonML-Bootstrap.log"
$TempDir = "C:\Temp\PythonML"
$PythonVersion = "3.10.11"
$PythonInstaller = "$TempDir\python-$PythonVersion-amd64.exe"
$PythonInstallDir = "C:\Python310"

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null

function Write-Log {
    param([string]$Message, [string]$Level="INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogPath -Value $line
    Write-Host $line
}

Write-Log "BOOTSTRAPPING ML ENVIRONMENT (Windows 2022)"

# =============================================================================
# 1. DOWNLOAD PYTHON
# =============================================================================
Write-Log "Downloading Python $PythonVersion"

Invoke-WebRequest `
  -Uri "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe" `
  -OutFile $PythonInstaller

# =============================================================================
# 2. INSTALL PYTHON (SYSTEM-WIDE)
# =============================================================================
Write-Log "Installing Python $PythonVersion system-wide"

Start-Process -FilePath $PythonInstaller -ArgumentList `
    "/quiet InstallAllUsers=1 PrependPath=1 TargetDir=$PythonInstallDir Include_pip=1" `
    -Wait

# Refresh PATH for current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")

Write-Log "Python installed"

# =============================================================================
# 3. VERIFY PYTHON
# =============================================================================
python --version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Log "Python not available after install" "ERROR"
    exit 1
}

# =============================================================================
# 4. UPGRADE PIP TOOLCHAIN
# =============================================================================
Write-Log "Upgrading pip / setuptools / wheel"

python -m pip install --upgrade pip setuptools wheel --no-cache-dir

# =============================================================================
# 5. INSTALL CORE DATA STACK
# =============================================================================
Write-Log "Installing core data libraries"

python -m pip install `
    numpy `
    pandas `
    scipy `
    scikit-learn `
    jupyterlab `
    --no-cache-dir

# =============================================================================
# 6. INSTALL PYTORCH (LATEST CPU STABLE)
# =============================================================================
Write-Log "Installing PyTorch (CPU)"

python -m pip install `
    torch `
    torchvision `
    torchaudio `
    --index-url https://download.pytorch.org/whl/cpu `
    --no-cache-dir

# =============================================================================
# 7. INSTALL TENSORFLOW (LATEST SUPPORTED)
# =============================================================================
Write-Log "Installing TensorFlow"

python -m pip install tensorflow --no-cache-dir

# =============================================================================
# 8. INSTALL DASK
# =============================================================================
Write-Log "Installing Dask"

python -m pip install "dask[complete]" distributed --no-cache-dir

# =============================================================================
# 9. OPTIONAL: PYSPARK
# =============================================================================
Write-Log "Installing PySpark"

python -m pip install pyspark --no-cache-dir

# =============================================================================
# 10. INSTALL vowpalwabbit 
# =============================================================================
Write-Log "Installing PySpark"

python -m pip install vowpalwabbit --no-cache-dir

# =============================================================================
# 11. VERIFY VIA REAL IMPORTS
# =============================================================================
Write-Log "VERIFYING ML STACK"

$checks = @(
    "import sys; print(sys.version)",
    "import numpy; print('NumPy OK')",
    "import pandas; print('Pandas OK')",
    "import sklearn; print('Scikit-learn OK')",
    "import torch; print('PyTorch OK:', torch.__version__)",
    "import tensorflow as tf; print('TensorFlow OK:', tf.__version__)",
    "import dask; print('Dask OK:', dask.__version__)",
    "import pyspark; print('PySpark OK:', pyspark.__version__)"
)

foreach ($c in $checks) {
    python -c $c
}

# =============================================================================
# 12. FINAL
# =============================================================================
Write-Log "ML ENVIRONMENT READY"
Write-Log "Python: $PythonVersion"
Write-Log "Log: $LogPath"

Write-Host "`nML STACK OPERATIONAL"
Write-Host "Next steps:"
Write-Host "  jupyter lab"
Write-Host "  python -c `"import torch, tensorflow, dask`""
