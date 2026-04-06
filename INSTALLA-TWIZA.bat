@echo off
:: ============================================
:: TWIZA MONEYPENNY - Launcher
:: ============================================
:: Lancia direttamente l'app Electron.
:: Il wizard interno gestisce tutta l'installazione.
:: ============================================

cd /d "%~dp0"

if exist "app\TWIZA Moneypenny.exe" (
    start "" "app\TWIZA Moneypenny.exe"
) else (
    echo [ERRORE] TWIZA Moneypenny.exe non trovata in app\
    echo Verifica che la cartella sia completa.
    pause
)
