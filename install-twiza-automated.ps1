# TWIZA Automated Installation Script
# Optimized for Windows Installer execution
# Copyright (c) 2026 SHAKAZAMBA S.r.l.

param(
    [switch]$Silent = $false,
    [string]$LogPath = "$env:TEMP\twiza-install.log"
)

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

Write-Log "=== TWIZA AUTOMATED INSTALLATION STARTED ==="
Write-Log "BREVETTO UIBM N. 102024000025755 - SHAKAZAMBA S.r.l."

try {
    # Check if running as administrator
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        throw "Script must run as Administrator"
    }
    
    Write-Log "Administrator privileges confirmed"
    
    # Check Windows version
    $winVersion = [System.Environment]::OSVersion.Version
    if ($winVersion.Build -lt 19041) {
        throw "Windows 10 build 19041+ required. Current build: $($winVersion.Build)"
    }
    
    Write-Log "Windows version check passed: Build $($winVersion.Build)"
    
    # Enable WSL features if needed
    Write-Log "Checking WSL2 features..."
    
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
    
    $needRestart = $false
    
    if ($wslFeature.State -eq "Disabled") {
        Write-Log "Enabling WSL feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -WarningAction SilentlyContinue
        $needRestart = $true
    }
    
    if ($vmFeature.State -eq "Disabled") {
        Write-Log "Enabling Virtual Machine Platform..."
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -WarningAction SilentlyContinue
        $needRestart = $true
    }
    
    if ($needRestart) {
        Write-Log "WSL features enabled. System restart will be required." "WARNING"
        # Don't auto-restart from installer, let user decide
    }
    
    # Set WSL default version to 2
    Write-Log "Setting WSL default version to 2..."
    & wsl --set-default-version 2 2>$null
    
    # Install Ubuntu if Ubuntu-22.04-WSL.appx exists
    $ubuntuPath = Join-Path $PSScriptRoot "Ubuntu-22.04-WSL.appx"
    if (Test-Path $ubuntuPath) {
        Write-Log "Installing Ubuntu WSL from: $ubuntuPath"
        
        # Check if Ubuntu is already installed
        $existingDistros = & wsl --list --quiet 2>$null
        if ($existingDistros -contains "Ubuntu") {
            Write-Log "Ubuntu WSL already installed, skipping..."
        } else {
            try {
                Add-AppxPackage -Path $ubuntuPath -ErrorAction Stop
                Write-Log "Ubuntu WSL package installed successfully"
                
                # Initialize Ubuntu (this might take time)
                Write-Log "Initializing Ubuntu... (this may take several minutes)"
                $process = Start-Process -FilePath "ubuntu.exe" -ArgumentList "install --root" -NoNewWindow -PassThru -Wait
                
                if ($process.ExitCode -eq 0) {
                    Write-Log "Ubuntu initialization completed"
                } else {
                    Write-Log "Ubuntu initialization completed with warnings (Exit code: $($process.ExitCode))" "WARNING"
                }
                
            } catch {
                Write-Log "Error installing Ubuntu WSL: $($_.Exception.Message)" "ERROR"
                Write-Log "Ubuntu installation failed, but continuing with rest of setup..." "WARNING"
            }
        }
    } else {
        Write-Log "Ubuntu-22.04-WSL.appx not found, skipping Ubuntu installation" "WARNING"
    }
    
    # Create TWIZA user in WSL if Ubuntu is available
    Write-Log "Checking WSL Ubuntu availability..."
    $wslTest = & wsl -d Ubuntu -e echo "test" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Ubuntu WSL is available, setting up TWIZA user..."
        
        # Create twiza user
        & wsl -d Ubuntu -e sudo useradd -m -s /bin/bash twiza 2>$null
        & wsl -d Ubuntu -e sudo usermod -aG sudo twiza 2>$null
        & wsl -d Ubuntu -e sudo passwd -d twiza 2>$null  # No password required
        
        Write-Log "TWIZA user created in Ubuntu WSL"
        
        # Install basic dependencies
        Write-Log "Installing dependencies..."
        & wsl -d Ubuntu -u twiza -e sudo apt-get update -y 2>$null
        & wsl -d Ubuntu -u twiza -e sudo apt-get install -y curl wget git 2>$null
        
        # Install Node.js 20 LTS
        Write-Log "Installing Node.js 20 LTS..."
        & wsl -d Ubuntu -u twiza -e bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -" 2>$null
        & wsl -d Ubuntu -u twiza -e sudo apt-get install -y nodejs 2>$null
        
        # Install Ollama
        Write-Log "Installing Ollama..."
        & wsl -d Ubuntu -u twiza -e bash -c "curl -fsSL https://ollama.ai/install.sh | sh" 2>$null
        
        # Install OpenClaw
        Write-Log "Installing OpenClaw..."
        & wsl -d Ubuntu -u twiza -e npm install -g openclaw 2>$null
        
        # Start Ollama service
        Write-Log "Starting Ollama service..."
        & wsl -d Ubuntu -u twiza -e bash -c "nohup ollama serve > ~/.ollama.log 2>&1 &" 2>$null
        
        Write-Log "WSL environment setup completed"
        
    } else {
        Write-Log "Ubuntu WSL not available, skipping user setup" "WARNING"
    }
    
    Write-Log "=== TWIZA INSTALLATION COMPLETED SUCCESSFULLY ==="
    Write-Log "Next steps:"
    Write-Log "1. Launch TWIZA Moneypenny desktop application"
    Write-Log "2. Download AI models: wsl -d Ubuntu -u twiza -- ollama pull qwen2.5:1.5b"
    Write-Log "3. Visit shakazamba.com for documentation and support"
    
    exit 0

} catch {
    Write-Log "INSTALLATION FAILED: $($_.Exception.Message)" "ERROR"
    Write-Log "Check log file: $LogPath" "ERROR"
    Write-Log "Support: info@shakazamba.com" "ERROR"
    exit 1
}