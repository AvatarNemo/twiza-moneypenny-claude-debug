@echo off
setlocal enabledelayedexpansion

echo ================================================
echo TWIZA COMPLETE WINDOWS INSTALLER DEPLOYMENT
echo SHAKAZAMBA S.r.l. - BREVETTO UIBM N. 102024000025755  
echo ================================================
echo.

REM Check if running from correct location
if not exist "TWIZA-Windows-Installer-Builder.tar.gz" (
    echo ERROR: TWIZA-Windows-Installer-Builder.tar.gz not found
    echo.
    echo Make sure you are running this script from the directory containing:
    echo   - TWIZA-Windows-Installer-Builder.tar.gz
    echo   - This script (DEPLOY-TWIZA-INSTALLER.bat)
    echo.
    pause
    exit /b 1
)

echo Step 1: Extracting installer builder package...

REM Check if tar is available (Windows 10 1903+ has built-in tar)
where tar >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: tar command not found
    echo.
    echo Windows 10 version 1903+ required for built-in tar support
    echo Alternatively, install 7-Zip and extract manually:
    echo   7z x TWIZA-Windows-Installer-Builder.tar.gz
    echo   7z x TWIZA-Windows-Installer-Builder.tar
    echo.
    pause
    exit /b 1
)

REM Extract the builder package
tar -xzf TWIZA-Windows-Installer-Builder.tar.gz

if %errorlevel% neq 0 (
    echo ERROR: Failed to extract installer builder package
    pause
    exit /b 1
)

echo   [OK] Package extracted successfully

echo.
echo Step 2: Checking NSIS installation...

where makensis >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: NSIS not found in PATH
    echo.
    echo To complete the build, you need to install NSIS:
    echo   1. Download from: https://nsis.sourceforge.io/
    echo   2. Install NSIS
    echo   3. Add makensis.exe to your PATH
    echo   4. Run: twiza-installer-build\build-twiza-installer.bat
    echo.
    echo The files are ready in: twiza-installer-build\
    pause
    exit /b 0
) else (
    echo   [OK] NSIS found, proceeding with build...
)

echo.
echo Step 3: Building TWIZA installer...

cd twiza-installer-build
call build-twiza-installer.bat

if %errorlevel% equ 0 (
    echo.
    echo ================================================
    echo DEPLOYMENT SUCCESSFUL!
    echo ================================================
    echo.
    echo The complete Windows installer is ready:
    echo   File: TWIZA-Moneypenny-2.2.1-Complete-Installer.exe
    echo   Size: ~1.1GB (includes Ubuntu WSL offline)
    echo.
    echo This installer provides:
    echo   ✓ Complete Windows experience (next, next, install)
    echo   ✓ Automatic WSL2 + Ubuntu setup
    echo   ✓ Ollama + OpenClaw installation  
    echo   ✓ TWIZA desktop application
    echo   ✓ No manual PowerShell required
    echo.
    echo Ready for distribution to end users!
    echo Support: info@shakazamba.com
    echo.
) else (
    echo.
    echo ================================================
    echo BUILD FAILED!
    echo ================================================
    echo.
    echo Check the error messages above.
    echo The extracted files are in: twiza-installer-build\
    echo You can run the build manually: build-twiza-installer.bat
    echo.
)

echo Build process completed.
pause