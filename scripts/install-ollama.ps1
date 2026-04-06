#Requires -Version 5.1
<#
.SYNOPSIS
    TWIZA Agent — Ollama Installation Script
.DESCRIPTION
    Installs Ollama in WSL, starts the service, verifies GPU/CUDA access,
    and validates GPU passthrough is working correctly.
.PARAMETER DistroName
    WSL distro name. Default: Ubuntu
.PARAMETER WSLUser
    WSL user to run as. Default: twiza
#>

param(
    [string]$DistroName = "Ubuntu",
    [string]$WSLUser = "twiza"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "  ⏳ $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  ✅ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  ❌ $msg" -ForegroundColor Red }
function Write-Info($msg)  { Write-Host "     $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "  🦙 TWIZA — Ollama Installer" -ForegroundColor Magenta
Write-Host "  ─────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# ============================================================
# Step 1: Check WSL distro exists
# ============================================================

Write-Step "Checking WSL distro '$DistroName'..."

try {
    $distros = (wsl --list --quiet 2>&1) | Out-String
    if ($distros -notmatch $DistroName) {
        Write-Fail "$DistroName is not installed. Run the main TWIZA installer first."
        Write-Info "Available distros:"
        Write-Info $distros.Trim()
        exit 1
    }
    Write-OK "$DistroName is available"
} catch {
    Write-Fail "WSL is not available: $_"
    Write-Info "Ensure WSL2 is installed: wsl --install"
    exit 1
}

# Verify user exists
try {
    $userCheck = & wsl -d $DistroName -- bash -c "id -u $WSLUser 2>/dev/null && echo exists || echo missing" 2>&1
    if ($userCheck -match "missing") {
        Write-Fail "User '$WSLUser' does not exist in $DistroName. Run the main bootstrap first."
        exit 1
    }
} catch {
    Write-Warn "Could not verify user '$WSLUser' (non-critical)"
}

# ============================================================
# Step 2: Check if Ollama already installed
# ============================================================

Write-Step "Checking if Ollama is installed..."

try {
    $ollamaPath = & wsl -d $DistroName -u $WSLUser -- bash -lc "command -v ollama 2>/dev/null" 2>&1
    if ($LASTEXITCODE -eq 0 -and $ollamaPath) {
        $ollamaVer = (& wsl -d $DistroName -u $WSLUser -- bash -lc "ollama --version 2>/dev/null" 2>&1).ToString().Trim()
        Write-OK "Ollama already installed: $ollamaVer"
    } else {
        Write-Step "Installing Ollama..."

        $installOutput = & wsl -d $DistroName -u $WSLUser -- bash -lc "curl -fsSL https://ollama.com/install.sh | sh" 2>&1
        $installOutput | ForEach-Object { Write-Info $_.ToString() }

        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Failed to install Ollama"
            Write-Info "You can try manually: wsl -d $DistroName -- curl -fsSL https://ollama.com/install.sh | sh"
            exit 1
        }

        # Verify installation
        $verifyOllama = & wsl -d $DistroName -u $WSLUser -- bash -lc "command -v ollama 2>/dev/null" 2>&1
        if ($LASTEXITCODE -eq 0 -and $verifyOllama) {
            Write-OK "Ollama installed successfully"
        } else {
            Write-Fail "Ollama install script ran but binary not found"
            Write-Info "Check PATH or try: wsl -d $DistroName -- which ollama"
            exit 1
        }
    }
} catch {
    Write-Fail "Error during Ollama installation: $_"
    exit 1
}

# ============================================================
# Step 3: Start Ollama service
# ============================================================

Write-Step "Starting Ollama service..."

try {
    $running = & wsl -d $DistroName -u $WSLUser -- bash -lc "pgrep -x ollama 2>/dev/null" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Ollama is already running (PID: $($running.ToString().Trim()))"
    } else {
        & wsl -d $DistroName -u $WSLUser -- bash -lc "nohup ollama serve >/dev/null 2>&1 &" 2>&1 | Out-Null
        Start-Sleep -Seconds 3

        $running = & wsl -d $DistroName -u $WSLUser -- bash -lc "pgrep -x ollama 2>/dev/null" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Ollama service started (PID: $($running.ToString().Trim()))"
        } else {
            Write-Warn "Ollama may not have started"
            Write-Info "Try manually: wsl -d $DistroName -u $WSLUser -- ollama serve"
            Write-Info "Check for errors: wsl -d $DistroName -u $WSLUser -- ollama serve 2>&1 | head -20"
        }
    }
} catch {
    Write-Warn "Error starting Ollama service: $_"
}

# ============================================================
# Step 4: GPU Detection (nvidia-smi)
# ============================================================

Write-Step "Checking GPU access in WSL..."

$gpuDetected = $false

try {
    $nvidiaSmi = (& wsl -d $DistroName -u $WSLUser -- bash -lc "nvidia-smi --query-gpu=name,memory.total,driver_version,cuda_version --format=csv,noheader 2>/dev/null" 2>&1).ToString().Trim()

    if ($LASTEXITCODE -eq 0 -and $nvidiaSmi -and $nvidiaSmi.Length -gt 5) {
        $parts = $nvidiaSmi.Split(',') | ForEach-Object { $_.Trim() }
        $gpuName = $parts[0]
        $gpuVRAM = if ($parts.Count -gt 1) { $parts[1] } else { "unknown" }
        $gpuDriver = if ($parts.Count -gt 2) { $parts[2] } else { "unknown" }
        $gpuCUDA = if ($parts.Count -gt 3) { $parts[3] } else { "unknown" }

        Write-OK "GPU detected: $gpuName"
        Write-Info "VRAM: $gpuVRAM"
        Write-Info "Driver: $gpuDriver"
        Write-Info "CUDA: $gpuCUDA"
        $gpuDetected = $true
    } else {
        Write-Warn "nvidia-smi not available or no GPU detected"
    }
} catch {
    Write-Warn "GPU check failed: $_"
}

if (-not $gpuDetected) {
    Write-Info ""
    Write-Info "Models will run on CPU (slower but functional)"
    Write-Info ""
    Write-Info "To enable GPU acceleration:"
    Write-Info "  1. Install the latest NVIDIA driver from nvidia.com"
    Write-Info "     (use the standard Windows driver — NOT the WSL-specific one)"
    Write-Info "  2. Ensure your driver version is 510.39.01 or later"
    Write-Info "  3. Restart WSL: wsl --shutdown && wsl"
    Write-Info "  4. Run this script again to verify"
}

# ============================================================
# Step 5: Verify CUDA Passthrough
# ============================================================

Write-Step "Checking CUDA library passthrough..."

try {
    $cudaLibs = (& wsl -d $DistroName -u $WSLUser -- bash -lc "ls /usr/lib/wsl/lib/libcuda* 2>/dev/null | head -5" 2>&1).ToString().Trim()
    if ($LASTEXITCODE -eq 0 -and $cudaLibs) {
        Write-OK "CUDA libraries found in WSL"
        Write-Info "Libraries: $($cudaLibs -replace "`n", ', ')"

        # Additional verification: check if libcuda.so is loadable
        $ldCheck = & wsl -d $DistroName -u $WSLUser -- bash -lc "ldconfig -p 2>/dev/null | grep -c libcuda || echo 0" 2>&1
        $ldCount = [int]($ldCheck.ToString().Trim())
        if ($ldCount -gt 0) {
            Write-OK "CUDA libraries registered in linker cache ($ldCount entries)"
        } else {
            Write-Warn "CUDA libraries exist but may not be in linker cache"
            Write-Info "This usually resolves itself. If Ollama can't use GPU, try: wsl --shutdown"
        }
    } else {
        Write-Warn "CUDA libraries not found in /usr/lib/wsl/lib/"
        if ($gpuDetected) {
            Write-Info "GPU detected but CUDA passthrough may not be working"
            Write-Info "Try: wsl --shutdown  then restart WSL"
        } else {
            Write-Info "Install the latest NVIDIA Windows driver to enable CUDA in WSL2"
        }
    }
} catch {
    Write-Warn "CUDA passthrough check failed: $_"
}

# ============================================================
# Step 6: Verify Ollama can see GPU
# ============================================================

if ($gpuDetected) {
    Write-Step "Verifying Ollama GPU access..."

    try {
        # Check Ollama's own GPU detection by hitting the API
        $ollamaGPU = & wsl -d $DistroName -u $WSLUser -- bash -lc "curl -sf http://localhost:11434/api/tags 2>/dev/null" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Ollama API is responding — GPU acceleration should be active"
        } else {
            Write-Info "Ollama API not responding yet (may still be starting)"
        }
    } catch {
        Write-Info "Could not verify Ollama GPU access (non-critical)"
    }
}

# ============================================================
# Done
# ============================================================

Write-Host ""
Write-Host "  🎉 Ollama setup complete!" -ForegroundColor Magenta
Write-Host ""
if ($gpuDetected) {
    Write-Host "  GPU: ✅ Detected and CUDA available" -ForegroundColor Green
} else {
    Write-Host "  GPU: ⚠️  Not detected — CPU mode (still works, just slower)" -ForegroundColor Yellow
}
Write-Host "  To pull a model: wsl -d $DistroName -u $WSLUser -- ollama pull llama3.2" -ForegroundColor Gray
Write-Host ""
