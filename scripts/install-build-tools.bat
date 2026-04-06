@echo off
echo ============================================
echo  TWIZA Moneypenny - Build Environment Setup
echo  Run as Administrator!
echo ============================================
echo.

:: Check admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

:: Step 1: VS Build Tools
echo [1/3] Installing Visual Studio Build Tools (MSVC + Windows SDK)...
echo       This may take 5-10 minutes...
winget install Microsoft.VisualStudio.2022.BuildTools --silent --accept-package-agreements --accept-source-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
if %errorLevel% neq 0 (
    echo WARNING: Build Tools may already be installed or needs manual install
    echo Visit: https://visualstudio.microsoft.com/visual-cpp-build-tools/
)

:: Step 2: Tauri CLI
echo.
echo [2/3] Installing Tauri CLI...
set PATH=%USERPROFILE%\.cargo\bin;%PATH%
cargo install tauri-cli
if %errorLevel% neq 0 (
    echo ERROR: Failed to install Tauri CLI
    pause
    exit /b 1
)

:: Step 3: Build
echo.
echo [3/3] Building TWIZA Moneypenny...
cd /d "%~dp0.."
cargo tauri build
if %errorLevel% neq 0 (
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo ============================================
echo  BUILD SUCCESSFUL!
echo  Check: src-tauri\target\release\bundle\nsis\
echo ============================================
dir /b src-tauri\target\release\bundle\nsis\*.exe 2>nul
pause
