# ============================================================
# TWIZA MONEYPENNY - Uninstaller v1.0
# Rimuove COMPLETAMENTE TWIZA dal sistema
# ============================================================

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "TWIZA Moneypenny - Disinstallazione"

# --- Config ---
$distroName  = "TWIZA"
$installDir  = Join-Path $env:LOCALAPPDATA "TWIZA Moneypenny"
$wslDir      = "C:\TWIZA-WSL"
$appDataDir  = Join-Path $env:APPDATA "TWIZA"
$uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\TWIZAMoneypenny"

# --- Helpers ---
function Write-Step {
    param([string]$Text)
    Write-Host "  → $Text" -ForegroundColor Cyan
}
function Write-OK {
    param([string]$Text)
    Write-Host "    [OK] $Text" -ForegroundColor Green
}
function Write-Skip {
    param([string]$Text)
    Write-Host "    [SKIP] $Text" -ForegroundColor DarkGray
}
function Write-Warn {
    param([string]$Text)
    Write-Host "    [!] $Text" -ForegroundColor Yellow
}

# --- Admin check ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  Richiesti privilegi di amministratore." -ForegroundColor Yellow
    Write-Host "  Rilancio con elevazione..." -ForegroundColor Yellow
    # Launch elevated window — use -NoExit to keep it open even on errors
    Start-Process powershell -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    # Close the non-elevated window immediately
    exit
}

# ============================================================
# Conferma
# ============================================================
Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Red
Write-Host "       DISINSTALLAZIONE TWIZA MONEYPENNY                     " -ForegroundColor Red
Write-Host "  ==========================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  Verranno rimossi:" -ForegroundColor White
Write-Host "    • App Electron ($installDir)" -ForegroundColor Gray
Write-Host "    • Distro WSL2 '$distroName' (con tutti i dati interni)" -ForegroundColor Gray
Write-Host "    • Directory WSL ($wslDir)" -ForegroundColor Gray
Write-Host "    • Dati configurazione ($appDataDir)" -ForegroundColor Gray
Write-Host "    • Collegamenti Desktop, Start Menu, Startup" -ForegroundColor Gray
Write-Host "    • Registrazione Windows (App e funzionalita)" -ForegroundColor Gray
Write-Host ""
Write-Host "  ATTENZIONE: Questa operazione e IRREVERSIBILE!" -ForegroundColor Yellow
Write-Host "  Tutti i dati dell'agente (memoria, conversazioni) saranno persi." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "  Digitare 'DISINSTALLA' per confermare"
if ($confirm -ne "DISINSTALLA") {
    Write-Host ""
    Write-Host "  Disinstallazione annullata." -ForegroundColor Green
    Read-Host "  Premi INVIO per chiudere"
    exit
}

Write-Host ""

# ============================================================
# 1. Chiudi processi TWIZA attivi
# ============================================================
Write-Step "Chiusura processi TWIZA..."

$killed = $false
# Kill TWIZA processes AND ALL Electron processes (unpackaged builds show as "Electron")
# Also kill any electron.exe that might be holding WSL handles
Get-Process -Name "Electron" -ErrorAction SilentlyContinue | ForEach-Object {
    try { $_.Kill(); $killed = $true; Write-OK "Electron terminato: PID $($_.Id)" } catch {}
}
Get-Process | Where-Object {
    $_.ProcessName -like "*TWIZA*" -or
    $_.MainWindowTitle -like "*TWIZA*" -or
    $_.ProcessName -like "*Moneypenny*"
} | ForEach-Object {
    try {
        $_.Kill()
        $killed = $true
        Write-OK "Processo terminato: $($_.ProcessName) (PID $($_.Id))"
    } catch {}
}

# Also stop gateway in WSL if running
try {
    $wslCheck = wsl -l -q 2>$null | Where-Object { $_ -replace "`0","" | Select-String -Pattern "^$distroName$" -Quiet }
    if ($wslCheck) {
        wsl -d $distroName --user twiza -- bash -c "pkill -f 'openclaw gateway' 2>/dev/null; pkill -f 'ollama serve' 2>/dev/null" 2>$null
        Write-OK "Gateway e Ollama fermati"
    }
} catch {}

if (-not $killed) { Write-OK "Nessun processo attivo" }

Start-Sleep -Seconds 1

# ============================================================
# 2. Rimuovi distro WSL2
# ============================================================
Write-Step "Rimozione distro WSL2 '$distroName'..."

try {
    # wsl -l -q outputs UTF-16 with null bytes — clean them
    $rawOutput = wsl -l -q 2>$null
    $distros = ($rawOutput | Out-String) -replace "`0","" -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $distroName }
    if ($distros) {
        $result = wsl --unregister $distroName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Distro '$distroName' rimossa"
        } else {
            Write-Warn "wsl --unregister ha restituito codice $LASTEXITCODE : $result"
        }
    } else {
        Write-Skip "Distro '$distroName' non trovata (elenco: $($rawOutput | Out-String))"
    }
} catch {
    Write-Warn "Errore rimozione distro: $($_.Exception.Message)"
}

# ============================================================
# 3. Rimuovi directory WSL
# ============================================================
Write-Step "Rimozione directory WSL ($wslDir)..."

if (Test-Path $wslDir) {
    try {
        Remove-Item -Path $wslDir -Recurse -Force
        Write-OK "Directory $wslDir rimossa"
    } catch {
        Write-Warn "Impossibile rimuovere $wslDir : $($_.Exception.Message)"
    }
} else {
    Write-Skip "Directory $wslDir non presente"
}

# ============================================================
# 4. Rimuovi app Electron
# ============================================================
Write-Step "Rimozione app ($installDir)..."

if (Test-Path $installDir) {
    try {
        Remove-Item -Path $installDir -Recurse -Force
        Write-OK "App rimossa"
    } catch {
        Write-Warn "Impossibile rimuovere app: $($_.Exception.Message)"
        Write-Warn "Prova a chiudere tutti i processi TWIZA e riprova"
    }
} else {
    Write-Skip "Directory app non presente"
}

# ============================================================
# 5. Rimuovi dati configurazione
# ============================================================
Write-Step "Rimozione dati configurazione..."

# AppData\Roaming\TWIZA (saved-config.json etc.)
if (Test-Path $appDataDir) {
    try {
        Remove-Item -Path $appDataDir -Recurse -Force
        Write-OK "Configurazione rimossa ($appDataDir)"
    } catch {
        Write-Warn "Errore: $($_.Exception.Message)"
    }
} else {
    Write-Skip "Directory configurazione non presente"
}

# Electron userData (AppData\Roaming\TWIZA Moneypenny)
$electronDataDir = Join-Path $env:APPDATA "TWIZA Moneypenny"
if (Test-Path $electronDataDir) {
    try {
        Remove-Item -Path $electronDataDir -Recurse -Force
        Write-OK "Dati Electron rimossi ($electronDataDir)"
    } catch {
        Write-Warn "Errore: $($_.Exception.Message)"
    }
}

# LocalAppData cache (Electron)
$electronCacheDir = Join-Path $env:LOCALAPPDATA "TWIZA Moneypenny"
if (Test-Path $electronCacheDir -and $electronCacheDir -ne $installDir) {
    try {
        Remove-Item -Path $electronCacheDir -Recurse -Force
        Write-OK "Cache Electron rimossa"
    } catch {}
}

# ============================================================
# 6. Rimuovi collegamenti
# ============================================================
Write-Step "Rimozione collegamenti..."

# Desktop
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$desktopLink = Join-Path $desktopPath "TWIZA Moneypenny.lnk"
if (Test-Path $desktopLink) {
    Remove-Item -Path $desktopLink -Force
    Write-OK "Collegamento Desktop rimosso"
} else { Write-Skip "Collegamento Desktop non presente" }

# Start Menu
$smDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\TWIZA"
if (Test-Path $smDir) {
    Remove-Item -Path $smDir -Recurse -Force
    Write-OK "Collegamento Start Menu rimosso"
} else { Write-Skip "Collegamento Start Menu non presente" }

# Startup (auto-start)
$startupFolder = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$startupLink = Join-Path $startupFolder "TWIZA Moneypenny Service.lnk"
if (Test-Path $startupLink) {
    Remove-Item -Path $startupLink -Force
    Write-OK "Collegamento avvio automatico rimosso"
} else { Write-Skip "Collegamento avvio automatico non presente" }

# ============================================================
# 7. Rimuovi registrazione Windows
# ============================================================
Write-Step "Rimozione registrazione Windows..."

if (Test-Path $uninstallKey) {
    try {
        Remove-Item -Path $uninstallKey -Recurse -Force
        Write-OK "Chiave registro rimossa"
    } catch {
        Write-Warn "Errore registro: $($_.Exception.Message)"
    }
} else {
    Write-Skip "Chiave registro non presente"
}

# Cleanup RunOnce if leftover
try {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "TWIZA_Resume" -ErrorAction SilentlyContinue
} catch {}

# ============================================================
# VERIFICA FINALE
# ============================================================
Write-Step "Verifica rimozione..."

$issues = @()

# Check WSL distro
$wslCheck = wsl -l -q 2>$null
$wslCheckStr = ($wslCheck | Out-String) -replace "`0",""
if ($wslCheckStr -match $distroName) {
    $issues += "Distro WSL '$distroName' ancora presente"
}

# Check registry
if (Test-Path $uninstallKey) {
    $issues += "Chiave registro ancora presente"
}

# Check install dir
if (Test-Path $installDir) {
    $issues += "Directory app ancora presente: $installDir"
}

if ($issues.Count -gt 0) {
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Yellow
    Write-Host "       DISINSTALLAZIONE PARZIALE                              " -ForegroundColor Yellow
    Write-Host "  ==========================================================" -ForegroundColor Yellow
    Write-Host ""
    foreach ($issue in $issues) {
        Write-Warn $issue
    }
    Write-Host ""
    Write-Host "  Prova a riavviare il PC e rieseguire la disinstallazione." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "  ==========================================================" -ForegroundColor Green
    Write-Host "       DISINSTALLAZIONE COMPLETATA                           " -ForegroundColor Green
    Write-Host "  ==========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  TWIZA Moneypenny e stata rimossa completamente dal sistema." -ForegroundColor White
}
Write-Host ""
Write-Host "  Nota: WSL2 stesso NON e stato rimosso (potrebbe essere" -ForegroundColor Gray
Write-Host "  usato da altre applicazioni). Per rimuoverlo:" -ForegroundColor Gray
Write-Host "    wsl --uninstall" -ForegroundColor DarkGray
Write-Host ""

Read-Host "  Premi INVIO per chiudere"
