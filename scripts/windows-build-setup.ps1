# TWIZA Moneypenny — Windows Build Environment Setup
# Run this from PowerShell (elevated/admin) on Windows
# It installs: Visual Studio Build Tools, Rust, then builds the app

$ErrorActionPreference = "Stop"

Write-Host "🦒 TWIZA Moneypenny — Windows Build Setup" -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta

# ── Step 1: Check/install winget ──
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "❌ winget not found. Please install App Installer from Microsoft Store." -ForegroundColor Red
    exit 1
}

# ── Step 2: Visual Studio Build Tools (MSVC + Windows SDK) ──
$clPath = Get-ChildItem "C:\Program Files (x86)\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $clPath) {
    Write-Host "`n📦 Installing Visual Studio Build Tools (MSVC + Windows SDK)..." -ForegroundColor Yellow
    Write-Host "   This may take 5-10 minutes..." -ForegroundColor Gray
    winget install Microsoft.VisualStudio.2022.BuildTools --silent --accept-package-agreements --accept-source-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build Tools installation failed. Try installing manually:" -ForegroundColor Red
        Write-Host "   https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor Cyan
        exit 1
    }
    Write-Host "✅ Visual Studio Build Tools installed" -ForegroundColor Green
} else {
    Write-Host "✅ MSVC already installed: $($clPath.FullName)" -ForegroundColor Green
}

# ── Step 3: Rust ──
if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    Write-Host "`n📦 Installing Rust..." -ForegroundColor Yellow
    # Download and run rustup-init silently
    $rustupUrl = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
    $rustupPath = "$env:TEMP\rustup-init.exe"
    Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath -UseBasicParsing
    & $rustupPath -y --default-toolchain stable-x86_64-pc-windows-msvc
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Rust installation failed" -ForegroundColor Red
        exit 1
    }
    # Refresh PATH
    $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
    Write-Host "✅ Rust installed: $(rustc --version)" -ForegroundColor Green
} else {
    Write-Host "✅ Rust already installed: $(rustc --version)" -ForegroundColor Green
}

# ── Step 4: Tauri CLI ──
if (-not (Get-Command cargo-tauri -ErrorAction SilentlyContinue)) {
    Write-Host "`n📦 Installing Tauri CLI..." -ForegroundColor Yellow
    cargo install tauri-cli
    Write-Host "✅ Tauri CLI installed" -ForegroundColor Green
} else {
    Write-Host "✅ Tauri CLI already installed" -ForegroundColor Green
}

# ── Step 5: Build ──
$projectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Write-Host "`n🏗️  Building TWIZA Moneypenny..." -ForegroundColor Yellow
Write-Host "   Project: $projectDir" -ForegroundColor Gray

Push-Location $projectDir
try {
    cargo tauri build 2>&1 | Tee-Object -Variable buildOutput
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed!" -ForegroundColor Red
        exit 1
    }
    
    # Find the installer
    $installer = Get-ChildItem "src-tauri\target\release\bundle\nsis\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installer) {
        $sizeMB = [math]::Round($installer.Length / 1MB, 1)
        Write-Host "`n✅ BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host "   Installer: $($installer.FullName)" -ForegroundColor Cyan
        Write-Host "   Size: ${sizeMB} MB" -ForegroundColor Cyan
        Write-Host "`n🦒 TWIZA Moneypenny — ...more than an agent!" -ForegroundColor Magenta
    } else {
        Write-Host "✅ Build completed but installer not found in expected location" -ForegroundColor Yellow
        Write-Host "   Check: src-tauri\target\release\bundle\" -ForegroundColor Gray
    }
} finally {
    Pop-Location
}
