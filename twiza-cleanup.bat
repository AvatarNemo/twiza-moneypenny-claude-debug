@echo off
REM TWIZA Directory Cleanup Script
REM Organizza e pulisce la cartella TWIZA dai file obsoleti

echo ========================================
echo TWIZA Directory Cleanup v1.0
echo SHAKAZAMBA - Sovereign AI Platform
echo ========================================
echo.

set "TWIZA_DIR=C:\Users\chris\Downloads\TWIZA"
cd /d "%TWIZA_DIR%"

echo Current directory contents:
dir /b
echo.

echo Creating backup of important files...
if not exist "backup" mkdir backup

REM Backup dell'installer esistente se presente
if exist "TWIZA-Moneypenny-2.2.1-Setup.exe" (
    echo Backing up existing installer...
    copy "TWIZA-Moneypenny-2.2.1-Setup.exe" "backup\"
)

echo.
echo Cleaning up obsolete files...

REM Remove il file WSL Ubuntu (1.1GB sprecati!)
if exist "Ubuntu-22.04-WSL.appx" (
    echo Removing Ubuntu WSL file ^(1.1GB^)...
    del /q "Ubuntu-22.04-WSL.appx"
)

REM Remove file duplicati/obsoleti
echo Removing duplicate/obsolete files...
del /q "BUILD-SINGLE-EXE.bat" 2>nul
del /q "CREATE-SINGLE-EXE.ps1" 2>nul  
del /q "install-twiza-automated.ps1" 2>nul
del /q "install-twiza-complete.ps1" 2>nul
del /q "README-TWIZA-COMPLETE.md" 2>nul
del /q "DEPLOY-SUMMARY.md" 2>nul
del /q "TWIZA-SelfExtract.sed" 2>nul

echo.
echo ========================================
echo CLEANUP COMPLETE!
echo ========================================
echo.

echo Remaining structure:
dir /b
echo.

echo Key files for TWIZA build:
echo ✅ TWIZA-Installer.nsi   (NSIS installer script)
echo ✅ build.bat            (Windows build)
echo ✅ build.sh             (Linux build) 
echo ✅ app\                 (Application files)
echo ✅ models\              (AI models)
echo ✅ docs\                (Documentation)
echo ✅ resources\           (Installer assets)
echo.

echo Space saved:
for %%F in (backup\Ubuntu-22.04-WSL.appx) do echo Ubuntu WSL: %%~zF bytes
echo.

echo To build TWIZA installer:
echo   1. Replace placeholders in app\ with real binaries
echo   2. Run: build.bat
echo   3. Test the generated TWIZA-Installer.exe
echo.

pause