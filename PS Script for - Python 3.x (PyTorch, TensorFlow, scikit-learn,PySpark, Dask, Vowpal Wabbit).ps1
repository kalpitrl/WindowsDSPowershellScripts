# =============================================================================
# GPU + PYTHON ML STACK (ALIGNED WITH JUPYTER RESET SCRIPT)
# =============================================================================

$ErrorActionPreference = "Stop"

$TempDir = "C:\Temp\GPU-Setup"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

Write-Host "===== GPU + ML STACK SETUP =====" -ForegroundColor Cyan

# =============================================================================
# 1. CUDA 12.4 (NO DRIVER)
# =============================================================================

$cudaUrl = "https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda_12.4.0_551.61_windows.exe"
$cudaInstaller = "$TempDir\cuda.exe"

Start-BitsTransfer -Source $cudaUrl -Destination $cudaInstaller

Start-Process -FilePath $cudaInstaller `
    -ArgumentList "-s nvcc_12.4 cudart_12.4" `
    -Wait

$cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4"

[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path","Machine") + ";$cudaPath\bin",
    "Machine"
)

# =============================================================================
# 2. PYTHON (MATCHES YOUR JUPYTER SCRIPT)
# =============================================================================

$pyVersion = "3.10.11"
$pyInstaller = "$TempDir\python.exe"

Invoke-WebRequest `
  -Uri "https://www.python.org/ftp/python/$pyVersion/python-$pyVersion-amd64.exe" `
  -OutFile $pyInstaller

Start-Process $pyInstaller `
  -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 TargetDir=C:\Python310 Include_pip=1" `
  -Wait

$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine")

# =============================================================================
# 3. PIP BASELINE
# =============================================================================

python -m pip install --upgrade pip setuptools wheel --no-cache-dir

# =============================================================================
# 4. CORE ML STACK
# =============================================================================

python -m pip install `
    numpy pandas scipy scikit-learn `
    dask[complete] distributed `
    pyspark vowpalwabbit `
    --no-cache-dir

# =============================================================================
# 5. PYTORCH GPU
# =============================================================================

python -m pip install `
    torch torchvision torchaudio `
    --index-url https://download.pytorch.org/whl/cu121 `
    --no-cache-dir

# =============================================================================
# 6. cuDNN (PINNED SAFE VERSION)
# =============================================================================

python -m pip install nvidia-cudnn-cu12==8.9.7.29 --no-cache-dir

# =============================================================================
# 7. TENSORFLOW (CPU ONLY ON WINDOWS)
# =============================================================================

python -m pip install tensorflow --no-cache-dir

# =============================================================================
# 8. QUICK GPU VALIDATION
# =============================================================================

python -c "import torch; print('CUDA:', torch.cuda.is_available())"

Write-Host "===== ML STACK READY =====" -ForegroundColor Green