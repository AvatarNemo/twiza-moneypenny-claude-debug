#Requires -Version 5.1
<#
.SYNOPSIS
    TWIZA Agent — WSL2 Bootstrap Script
.DESCRIPTION
    Production-ready bootstrap that sets up WSL2 + Ubuntu + Node.js + OpenClaw + Ollama.
    Outputs structured progress messages for the Electron app to parse.
.PARAMETER DistroName
    WSL distro name. Default: Ubuntu
.PARAMETER NodeVersion
    Node.js major version. Default: 22
.PARAMETER ConfigJson
    JSON string with openclaw.json config to deploy.
.PARAMETER TemplateDir
    Path to workspace template directory.
.PARAMETER SkipOllama
    Skip Ollama installation entirely (for cloud-only setups).
.NOTES
    Progress lines prefixed with PROGRESS: are parsed by the Electron installer UI.
    Format: PROGRESS:<percent>:<message>
#>

param(
    [string]$DistroName = "Ubuntu",
    [string]$NodeVersion = "22",
    [string]$ConfigJson = "",
    [string]$TemplateDir = "",
    [switch]$SkipOllama
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================
# Logging & Progress
# ============================================================

function Write-Progress-Step {
    param([int]$Percent, [string]$Message)
    Write-Host "PROGRESS:${Percent}:${Message}"
    Write-Host "  $Message" -ForegroundColor Cyan
}

function Write-Success($msg) {
    Write-Host "  ✅ $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "  ⚠️  $msg" -ForegroundColor Yellow
}

function Write-Fail($msg) {
    Write-Host "  ❌ $msg" -ForegroundColor Red
}

function Write-Detail($msg) {
    Write-Host "     $msg" -ForegroundColor Gray
}

# ============================================================
# Admin Check
# ============================================================

Write-Progress-Step 0 "Checking permissions..."

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Fail "This script requires Administrator privileges."
    Write-Host ""
    Write-Host "Please right-click and 'Run as Administrator', or run from an elevated PowerShell." -ForegroundColor Yellow
    exit 1
}

Write-Success "Running as Administrator"

# ============================================================
# Step 1: Enable WSL2 (5-20%)
# ============================================================

Write-Progress-Step 5 "Checking WSL2..."

function Test-WSLInstalled {
    try {
        $output = & wsl --status 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-DistroInstalled($name) {
    try {
        $distros = (wsl --list --quiet 2>&1) | Out-String
        return $distros -match $name
    } catch {
        return $false
    }
}

if (Test-WSLInstalled) {
    Write-Success "WSL2 is already installed"
} else {
    Write-Progress-Step 8 "Installing WSL2 (this may take a few minutes)..."

    try {
        $wslResult = & wsl --install --no-distribution 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "wsl --install returned exit code $LASTEXITCODE"
        }
        Write-Success "WSL2 installed"
    } catch {
        Write-Detail "wsl --install failed, trying manual feature enablement..."
        try {
            dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "DISM WSL feature failed" }
            dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "DISM VirtualMachinePlatform failed" }
            Write-Success "WSL features enabled via DISM"
        } catch {
            Write-Fail "Failed to enable WSL features: $_"
            Write-Detail "Ensure Windows 10 v2004+ or Windows 11 is installed."
            exit 1
        }

        Write-Warn "A RESTART IS REQUIRED. Please restart your PC and run the installer again."
        Write-Host "PROGRESS:100:RESTART_REQUIRED"
        exit 2
    }
}

# Update WSL kernel
Write-Progress-Step 12 "Updating WSL2 kernel..."
try {
    $null = & wsl --update 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "WSL2 kernel up to date"
    } else {
        Write-Warn "WSL kernel update returned non-zero (non-critical)"
    }
} catch {
    Write-Warn "WSL kernel update failed (non-critical): $_"
}

# Set WSL2 as default
try { & wsl --set-default-version 2 2>&1 | Out-Null } catch {}

# ============================================================
# Step 2: Install Ubuntu (20-35%)
# ============================================================

Write-Progress-Step 20 "Checking Ubuntu distro..."

if (Test-DistroInstalled $DistroName) {
    Write-Success "$DistroName is already installed"
} else {
    Write-Progress-Step 22 "Installing $DistroName (downloading ~500MB)..."

    try {
        & wsl --install -d $DistroName --no-launch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "wsl --install -d $DistroName failed with exit code $LASTEXITCODE"
        }
    } catch {
        Write-Fail "Failed to install $DistroName : $_"
        Write-Detail "Try running: wsl --install -d $DistroName  manually."
        exit 1
    }

    Write-Progress-Step 30 "Initializing $DistroName..."

    try {
        # Create the twiza user non-interactively
        & wsl -d $DistroName -- bash -c @"
            id -u twiza &>/dev/null || {
                useradd -m -s /bin/bash twiza
                echo 'twiza:twiza' | chpasswd
                usermod -aG sudo twiza
                echo 'twiza ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/twiza
            }
"@ 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Warn "User creation may have partially failed (exit code $LASTEXITCODE)"
        } else {
            Write-Success "$DistroName installed and configured"
        }
    } catch {
        Write-Fail "Failed to configure $DistroName : $_"
        exit 1
    }
}

# ============================================================
# Step 3: Install dependencies inside WSL (35-78%)
# ============================================================

Write-Progress-Step 35 "Preparing WSL environment..."

# Build the Ollama section conditionally
$ollamaSection = ""
if (-not $SkipOllama) {
    $ollamaSection = @"

# --- Ollama ---
echo "PROGRESS:65:Installing Ollama..."
if command -v ollama &>/dev/null; then
    echo "  ✅ Ollama already installed (`$(ollama --version 2>/dev/null || echo 'unknown'))"
else
    if curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null; then
        echo "  ✅ Ollama installed"
    else
        echo "  ⚠️  Ollama install failed (non-critical — needed only for local models)"
    fi
fi

# --- Start Ollama service ---
echo "PROGRESS:70:Starting Ollama service..."
if pgrep -x ollama >/dev/null 2>&1; then
    echo "  ✅ Ollama already running"
else
    nohup ollama serve >/dev/null 2>&1 &
    sleep 2
    if pgrep -x ollama >/dev/null 2>&1; then
        echo "  ✅ Ollama service started"
    else
        echo "  ⚠️  Ollama service may not have started (non-critical)"
    fi
fi
"@
} else {
    $ollamaSection = @"

# --- Ollama (SKIPPED) ---
echo "PROGRESS:70:Skipping Ollama (--SkipOllama flag set)..."
echo "  ℹ️  Ollama skipped — using cloud providers only"
"@
}

$wslScript = @"
#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export HOME=/home/twiza
cd `$HOME

# --- APT packages ---
echo "PROGRESS:38:Installing system packages..."
if dpkg -s curl git build-essential ca-certificates &>/dev/null 2>&1; then
    echo "  ✅ System packages already installed"
else
    if sudo apt-get update -qq 2>/dev/null && sudo apt-get install -y -qq curl git build-essential ca-certificates 2>/dev/null; then
        echo "  ✅ System packages installed"
    else
        echo "  ❌ Failed to install system packages"
        exit 1
    fi
fi

# --- nvm + Node.js ---
echo "PROGRESS:45:Installing Node.js..."
export NVM_DIR="`$HOME/.nvm"
if [ -d "`$NVM_DIR" ] && [ -s "`$NVM_DIR/nvm.sh" ]; then
    echo "  ✅ nvm already installed"
else
    if curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash 2>/dev/null; then
        echo "  ✅ nvm installed"
    else
        echo "  ❌ Failed to install nvm"
        exit 1
    fi
fi

[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"

CURRENT_NODE=`$(node --version 2>/dev/null || echo "none")
if [[ "`$CURRENT_NODE" == v${NodeVersion}.* ]]; then
    echo "  ✅ Node.js `$CURRENT_NODE already installed"
else
    if nvm install $NodeVersion 2>/dev/null; then
        nvm alias default $NodeVersion 2>/dev/null
        echo "  ✅ Node.js `$(node --version) installed"
    else
        echo "  ❌ Failed to install Node.js $NodeVersion"
        exit 1
    fi
fi

# --- OpenClaw ---
echo "PROGRESS:55:Installing OpenClaw..."
if command -v openclaw &>/dev/null; then
    echo "  ✅ OpenClaw already installed (`$(openclaw --version 2>/dev/null || echo 'unknown'))"
else
    if npm install -g openclaw 2>/dev/null; then
        echo "  ✅ OpenClaw installed"
    elif npm install -g @anthropic/openclaw 2>/dev/null; then
        echo "  ✅ OpenClaw installed (@anthropic)"
    else
        echo "  ⚠️  OpenClaw package not available yet — will need manual install"
    fi
fi
${ollamaSection}

# --- Workspace ---
echo "PROGRESS:75:Setting up workspace..."
WORKSPACE="`$HOME/.openclaw/workspace"
mkdir -p "`$WORKSPACE/memory"
mkdir -p "`$HOME/.openclaw"

echo "  ✅ Workspace directory ready at `$WORKSPACE"
echo "PROGRESS:78:WSL setup complete"
"@

# Write script to temp file and execute in WSL
$tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "twiza-bootstrap-$(Get-Random).sh")

try {
    # Write with LF line endings
    [System.IO.File]::WriteAllText($tempFile, $wslScript.Replace("`r`n", "`n"))

    # Convert Windows path to WSL path safely
    # wslpath can be flaky with backslashes, so normalize to forward slashes first
    $tempFileForWSL = $tempFile -replace '\\', '/'
    $wslTempPath = $null

    try {
        $wslTempPath = (& wsl -d $DistroName -- wslpath -u "$tempFileForWSL" 2>&1).ToString().Trim()
        if ($LASTEXITCODE -ne 0 -or -not $wslTempPath) {
            throw "wslpath failed"
        }
    } catch {
        # Fallback: manually construct /mnt/c/... path
        Write-Detail "wslpath failed, using fallback path conversion"
        $drive = $tempFile.Substring(0, 1).ToLower()
        $rest = $tempFile.Substring(2) -replace '\\', '/'
        $wslTempPath = "/mnt/$drive$rest"
    }

    & wsl -d $DistroName -u twiza -- bash -e "$wslTempPath" 2>&1 | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Fail "WSL setup script failed with exit code $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Fail "WSL bootstrap error: $_"
    exit 1
} finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

# ============================================================
# Step 4: Copy workspace template (80-85%)
# ============================================================

Write-Progress-Step 80 "Copying workspace template..."

if (-not $TemplateDir -or -not (Test-Path $TemplateDir)) {
    # Try to find template relative to script location
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $TemplateDir = Join-Path (Split-Path -Parent $scriptDir) "workspace-template"
}

if (Test-Path $TemplateDir) {
    $templateFiles = Get-ChildItem -Path $TemplateDir -File -Recurse
    $copied = 0
    $skipped = 0

    foreach ($file in $templateFiles) {
        $relativePath = $file.FullName.Substring($TemplateDir.Length + 1) -replace '\\', '/'
        $wslDest = "/home/twiza/.openclaw/workspace/$relativePath"

        # Don't overwrite existing files
        try {
            & wsl -d $DistroName -u twiza -- test -f "$wslDest" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Detail "Skipping $relativePath (already exists)"
                $skipped++
                continue
            }
        } catch {}

        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction Stop
            if ($content) {
                $wslDir = ($wslDest -replace '/[^/]+$', '')
                & wsl -d $DistroName -u twiza -- mkdir -p "$wslDir" 2>&1 | Out-Null
                $content | & wsl -d $DistroName -u twiza -- bash -c "cat > '$wslDest'" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Detail "📄 $relativePath"
                    $copied++
                } else {
                    Write-Warn "Failed to write $relativePath"
                }
            }
        } catch {
            Write-Warn "Error copying $relativePath : $_"
        }
    }
    Write-Success "Workspace template: $copied copied, $skipped skipped"
} else {
    Write-Warn "Template directory not found at $TemplateDir"
}

# ============================================================
# Step 5: Write openclaw.json config (85-90%)
# ============================================================

Write-Progress-Step 85 "Writing configuration..."

if ($ConfigJson -and $ConfigJson.Length -gt 2) {
    try {
        $ConfigJson | & wsl -d $DistroName -u twiza -- bash -c "cat > /home/twiza/.openclaw/workspace/openclaw.json" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Configuration written"
        } else {
            Write-Fail "Failed to write configuration (exit code $LASTEXITCODE)"
        }
    } catch {
        Write-Fail "Error writing configuration: $_"
    }
} else {
    Write-Detail "No config provided — will use defaults"
}

# ============================================================
# Step 6: Verify installation (90-95%)
# ============================================================

Write-Progress-Step 90 "Verifying installation..."

$verifyScript = @"
#!/bin/bash
export HOME=/home/twiza
export NVM_DIR="`$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"

errors=0

# Check Node
if command -v node &>/dev/null; then
    echo "  ✅ Node.js: `$(node --version)"
else
    echo "  ❌ Node.js: NOT FOUND"
    errors=`$((errors + 1))
fi

# Check OpenClaw
if command -v openclaw &>/dev/null; then
    echo "  ✅ OpenClaw: `$(openclaw --version 2>/dev/null || echo 'installed')"
else
    echo "  ⚠️  OpenClaw: not yet installed (may need manual install)"
fi

# Check workspace
if [ -f "/home/twiza/.openclaw/workspace/openclaw.json" ]; then
    echo "  ✅ Config: openclaw.json present"
else
    echo "  ⚠️  Config: openclaw.json not found"
fi

# Check Ollama (if not skipped)
if command -v ollama &>/dev/null; then
    echo "  ✅ Ollama: `$(ollama --version 2>/dev/null || echo 'installed')"
fi

exit `$errors
"@

$verifyTemp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "twiza-verify-$(Get-Random).sh")
try {
    [System.IO.File]::WriteAllText($verifyTemp, $verifyScript.Replace("`r`n", "`n"))
    $drive = $verifyTemp.Substring(0, 1).ToLower()
    $rest = $verifyTemp.Substring(2) -replace '\\', '/'
    $wslVerifyPath = "/mnt/$drive$rest"

    & wsl -d $DistroName -u twiza -- bash "$wslVerifyPath" 2>&1 | ForEach-Object {
        Write-Host $_.ToString()
    }
} catch {
    Write-Warn "Verification step failed: $_"
} finally {
    Remove-Item $verifyTemp -ErrorAction SilentlyContinue
}

# ============================================================
# Done (100%)
# ============================================================

Write-Host ""
Write-Progress-Step 100 "TWIZA Agent bootstrap complete!"
Write-Host ""
Write-Host "  🎉 Your TWIZA Agent is ready to go!" -ForegroundColor Magenta
Write-Host "     Workspace: /home/twiza/.openclaw/workspace" -ForegroundColor Gray
if ($SkipOllama) {
    Write-Host "     Ollama: skipped (cloud-only mode)" -ForegroundColor Gray
}
Write-Host ""
