@echo off
setlocal enabledelayedexpansion

echo =====================================
echo TWIZA Complete Windows Installer Build
echo SHAKAZAMBA S.r.l. - BREVETTO UIBM N. 102024000025755
echo =====================================
echo.

REM Check if NSIS is available
where makensis >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: NSIS not found in PATH
    echo Please install NSIS from: https://nsis.sourceforge.io/
    echo Make sure makensis.exe is in your PATH
    pause
    exit /b 1
)

REM Check required files
echo Checking required files...

set "REQUIRED_FILES=TWIZA-Windows-Installer.nsi LICENSE.txt install-twiza-automated.ps1"

for %%f in (%REQUIRED_FILES%) do (
    if not exist "%%f" (
        echo ERROR: Required file missing: %%f
        exit /b 1
    )
    echo   [OK] %%f
)

REM Check for Ubuntu WSL and main installer in current directory or TWIZA subfolder
echo.
echo Checking for TWIZA components...

set "UBUNTU_FILE=Ubuntu-22.04-WSL.appx"
set "SETUP_FILE=TWIZA-Moneypenny-2.2.1-Setup.exe"

REM Check current directory first
if exist "%UBUNTU_FILE%" (
    echo   [OK] %UBUNTU_FILE% found in current directory
    set "UBUNTU_PATH=%UBUNTU_FILE%"
) else if exist "TWIZA\%UBUNTU_FILE%" (
    echo   [OK] %UBUNTU_FILE% found in TWIZA subfolder
    copy "TWIZA\%UBUNTU_FILE%" . >nul
    set "UBUNTU_PATH=%UBUNTU_FILE%"
) else (
    echo   [ERROR] %UBUNTU_FILE% not found
    echo   Please place Ubuntu WSL file in current directory or TWIZA subfolder
    pause
    exit /b 1
)

if exist "%SETUP_FILE%" (
    echo   [OK] %SETUP_FILE% found in current directory
    set "SETUP_PATH=%SETUP_FILE%"
) else if exist "TWIZA\%SETUP_FILE%" (
    echo   [OK] %SETUP_FILE% found in TWIZA subfolder
    copy "TWIZA\%SETUP_FILE%" . >nul
    set "SETUP_PATH=%SETUP_FILE%"
) else (
    echo   [ERROR] %SETUP_FILE% not found
    echo   Please place TWIZA Setup file in current directory or TWIZA subfolder
    pause
    exit /b 1
)

REM Create assets directory with placeholder files if missing
if not exist "assets\" mkdir assets

if not exist "assets\twiza-icon.ico" (
    echo Creating placeholder icon...
    REM Create a simple .ico file (this is very basic, replace with real icon)
    echo. > "assets\twiza-icon.ico"
)

if not exist "assets\twiza-welcome.bmp" (
    echo Creating placeholder welcome image...
    REM Create a simple .bmp file (this is very basic, replace with real image)
    echo. > "assets\twiza-welcome.bmp"
)

REM Copy the optimized PowerShell script for inclusion
copy "install-twiza-automated.ps1" "install-twiza-complete.ps1" >nul

echo.
echo Building installer with NSIS...
echo.

REM Build the installer
makensis "TWIZA-Windows-Installer.nsi"

if %errorlevel% equ 0 (
    echo.
    echo =====================================
    echo BUILD SUCCESSFUL!
    echo =====================================
    echo.
    echo Output: TWIZA-Moneypenny-2.2.1-Complete-Installer.exe
    echo Size: 
    for %%i in ("TWIZA-Moneypenny-2.2.1-Complete-Installer.exe") do echo   %%~zi bytes ^(~%%~zi KB^)
    echo.
    echo Installer includes:
    echo   - TWIZA Desktop Application
    echo   - Ubuntu WSL 22.04 ^(1.1GB^)
    echo   - Automated setup scripts
    echo   - OpenClaw + Ollama installation
    echo.
    echo Ready for distribution!
    echo Support: info@shakazamba.com
    echo Website: shakazamba.com
    echo.
) else (
    echo.
    echo =====================================
    echo BUILD FAILED!
    echo =====================================
    echo.
    echo Check the NSIS output above for errors.
    echo Common issues:
    echo   - Missing or corrupted source files
    echo   - Insufficient permissions
    echo   - NSIS syntax errors
    echo.
    pause
    exit /b 1
)

REM Cleanup temporary files
del "install-twiza-complete.ps1" 2>nul

echo.
echo Build process completed.
pause