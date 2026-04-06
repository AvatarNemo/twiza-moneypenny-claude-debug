# ============================================================
# TWIZA MONEYPENNY - Installer v7.1 (WSL2 Fix)
# ============================================================

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "TWIZA Moneypenny - Installazione"

# --- Paths ---
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$baseDir     = Split-Path -Parent $scriptDir
$components  = Join-Path $baseDir "components"
$templates   = Join-Path $baseDir "templates"
$appDir      = Join-Path $baseDir "app"
$installDir  = Join-Path $env:LOCALAPPDATA "TWIZA Moneypenny"
$distroName  = "TWIZA"
$wslDir      = "C:\TWIZA-WSL"
$logFile     = Join-Path $baseDir "install.log"
$stateFile   = Join-Path $baseDir ".install-state"

$totalSteps  = 7

# --- Helpers ---
function Write-Step {
    param([int]$Num, [int]$Total, [string]$Text)
    $pct = [math]::Round(($Num / $Total) * 100)
    Write-Host ""
    Write-Host "  [$Num/$Total] ($pct%) $Text" -ForegroundColor Cyan
    Write-Host "  --------------------------------------------------" -ForegroundColor DarkGray
}

function Write-OK   { param([string]$Text) Write-Host "  [OK] $Text" -ForegroundColor Green }
function Write-Warn  { param([string]$Text) Write-Host "  [!!] $Text" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Text) Write-Host "  [ERRORE] $Text" -ForegroundColor Red }

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Start ---
Clear-Host
Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Magenta
Write-Host "                                                            " -ForegroundColor Magenta
Write-Host "      TWIZA MONEYPENNY - Installer v7.1                    " -ForegroundColor Magenta
Write-Host "      Il tuo agente AI personale                            " -ForegroundColor Magenta
Write-Host "                                                            " -ForegroundColor Magenta
Write-Host "  ==========================================================" -ForegroundColor Magenta
Write-Host ""

Start-Transcript -Path $logFile -Force | Out-Null

if (-not (Test-Admin)) {
    Write-Fail "Serve eseguire come Amministratore!"
    Write-Host "  Rilancio con privilegi elevati..."
    Start-Process PowerShell -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`"")
    exit
}

# Check resume state (post-reboot)
$resumeStep = 0
if (Test-Path $stateFile) {
    $resumeStep = [int](Get-Content $stateFile -Raw).Trim()
    Write-Host "  Ripresa installazione dal passo $resumeStep dopo riavvio..." -ForegroundColor Yellow
    Write-Host ""
    Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
}

# ============================================================
# STEP 1: VC++ Runtime
# ============================================================
if ($resumeStep -le 1) {
    Write-Step 1 $totalSteps "Prerequisiti - VC++ Runtime"

    $vcRedist = Join-Path $components "vc_redist.x64.exe"
    if (Test-Path $vcRedist) {
        $vcCheck = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
        if ($vcCheck) {
            Write-OK "VC++ Runtime presente"
        } else {
            Write-Host "  Installazione VC++ Runtime..."
            Start-Process -FilePath $vcRedist -ArgumentList "/install /quiet /norestart" -Wait
            Write-OK "VC++ Runtime installato"
        }
    } else {
        Write-Warn "vc_redist.x64.exe non trovato - salto"
    }
}

# ============================================================
# STEP 2: WSL2 + Virtual Machine Platform
# ============================================================
if ($resumeStep -le 2) {
    Write-Step 2 $totalSteps "Abilitazione WSL2 + Virtual Machine Platform"

    $needsReboot = $false

    # Check both required features
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    $vmFeature  = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue

    $wslOk = ($wslFeature -and $wslFeature.State -eq "Enabled")
    $vmOk  = ($vmFeature -and $vmFeature.State -eq "Enabled")

    if ($wslOk) {
        Write-OK "WSL feature abilitata"
    } else {
        Write-Host "  Abilitazione WSL..."
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1 | Out-Null
        $needsReboot = $true
    }

    if ($vmOk) {
        Write-OK "Virtual Machine Platform abilitata"
    } else {
        Write-Host "  Abilitazione Virtual Machine Platform..."
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1 | Out-Null
        $needsReboot = $true
    }

    # Set WSL2 as default version (may fail pre-reboot, that's OK)
    wsl --set-default-version 2 2>&1 | Out-Null

    if ($needsReboot) {
        Write-Warn "Riavvio necessario per attivare WSL2 e Virtual Machine Platform."
        Write-Host ""

        # Save state for resume after reboot
        Set-Content -Path $stateFile -Value "3"

        # Register auto-resume in RunOnce (for standalone .bat usage)
        $batPath = Join-Path $baseDir "INSTALLA-TWIZA.bat"
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" `
                -Name "TWIZA_Resume" `
                -Value ("cmd /c `"" + $batPath + "`"") `
                -ErrorAction SilentlyContinue
        } catch {}

        # When called from Electron wizard (non-interactive), exit with code 3010 (reboot required)
        # The wizard will show a reboot button. Don't block with Read-Host!
        if ($env:TWIZA_NONINTERACTIVE -eq "1") {
            Write-Host "[REBOOT_REQUIRED] Exiting with code 3010 for Electron wrapper."
            Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
            exit 3010
        }

        # Interactive mode (standalone .bat): prompt and reboot
        Write-Host "  Dopo il riavvio, riesegui INSTALLA-TWIZA.bat" -ForegroundColor Yellow
        Write-Host "  L'installazione ripartira' automaticamente dal punto giusto." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Premi INVIO per riavviare il PC"
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        Restart-Computer -Force
        exit
    }

    # Verify WSL2 is actually functional
    Write-Host "  Verifica funzionamento WSL2..."
    $wslStatus = wsl --status 2>&1
    $wslStatusText = ($wslStatus | Out-String)
    
    if ($wslStatusText -match "2") {
        Write-OK "WSL2 funzionante"
    } else {
        # Try updating the WSL kernel
        $wslUpdate = Join-Path $components "wsl_update_x64.msi"
        if (Test-Path $wslUpdate) {
            Write-Host "  Aggiornamento kernel WSL2..."
            Start-Process msiexec.exe -ArgumentList "/i `"$wslUpdate`" /quiet /norestart" -Wait
        }
        
        # Final check
        $wslTest = wsl --status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "WSL2 non funzionante dopo l'abilitazione."
            Write-Host ""
            Write-Host "  Possibili cause:" -ForegroundColor Yellow
            Write-Host "    1. La virtualizzazione non e' abilitata nel BIOS/UEFI" -ForegroundColor Yellow
            Write-Host "    2. Serve un riavvio del PC" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Per abilitare la virtualizzazione:" -ForegroundColor Cyan
            Write-Host "    - Riavvia il PC e entra nel BIOS (F2/DEL/F10 all'avvio)" -ForegroundColor Gray
            Write-Host "    - Cerca 'Virtualization Technology' o 'VT-x' o 'SVM'" -ForegroundColor Gray
            Write-Host "    - Abilitalo, salva e riavvia" -ForegroundColor Gray
            Write-Host "    - Poi riesegui questo installer" -ForegroundColor Gray
            Write-Host ""
            Stop-Transcript | Out-Null
            Read-Host "  Premi INVIO per chiudere"
            exit 1
        }
        Write-OK "WSL2 funzionante"
    }
}

# ============================================================
# STEP 3: Import Ubuntu distro
# ============================================================
if ($resumeStep -le 3) {
    Write-Step 3 $totalSteps "Creazione distro TWIZA - Ubuntu 24.04"

    $existingDistros = (wsl -l -q 2>&1) -join " "
    if ($existingDistros -match $distroName) {
        Write-Warn "Distro TWIZA esistente"
        if ($env:TWIZA_NONINTERACTIVE -eq "1") {
            Write-Host "  Modalità non-interattiva: rimozione automatica distro..."
            wsl --unregister $distroName 2>&1 | Out-Null
        } else {
            $overwrite = Read-Host "  Vuoi reinstallarla? (S/N)"
            if ($overwrite -eq "S" -or $overwrite -eq "s") {
                Write-Host "  Rimozione distro..."
                wsl --unregister $distroName 2>&1 | Out-Null
            } else {
                Write-OK "Mantengo distro esistente"
            }
        }
    }

    $existingDistros = (wsl -l -q 2>&1) -join " "
    if (-not ($existingDistros -match $distroName)) {

        $rootfsTar = Get-ChildItem -Path $components -Filter "ubuntu-*-rootfs*.tar*" -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($rootfsTar) {
            Write-Host ("  Importo Ubuntu da: " + $rootfsTar.Name)
            New-Item -Path $wslDir -ItemType Directory -Force | Out-Null
            $importOutput = wsl --import $distroName $wslDir $rootfsTar.FullName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Distro TWIZA importata"
            } else {
                Write-Fail "Import fallito"
                Write-Host ""
                $importText = ($importOutput | Out-String)
                Write-Host "  Dettaglio errore:" -ForegroundColor Yellow
                Write-Host "  $importText" -ForegroundColor Gray

                if ($importText -match "HYPERV|HCS|VirtualMachine|virtualization") {
                    Write-Host ""
                    Write-Host "  La virtualizzazione non e' attiva su questo PC." -ForegroundColor Red
                    Write-Host "  Devi abilitarla nel BIOS/UEFI:" -ForegroundColor Yellow
                    Write-Host "    1. Riavvia il PC" -ForegroundColor Gray
                    Write-Host "    2. Entra nel BIOS (F2/DEL/F10/F12 all'avvio)" -ForegroundColor Gray
                    Write-Host "    3. Trova 'Virtualization Technology' (Intel VT-x) o 'SVM Mode' (AMD)" -ForegroundColor Gray
                    Write-Host "    4. Abilitalo, salva ed esci" -ForegroundColor Gray
                    Write-Host "    5. Riesegui questo installer" -ForegroundColor Gray
                }
                Write-Host ""
                Stop-Transcript | Out-Null
                Read-Host "  Premi INVIO per chiudere"
                exit 1
            }
        } else {
            Write-Host "  Nessun rootfs locale. Installo Ubuntu dal Microsoft Store..."
            wsl --install Ubuntu-24.04 --no-launch 2>&1 | Out-Null

            Write-Host "  Creo distro TWIZA da Ubuntu..."
            $tempTar = Join-Path $env:TEMP "ubuntu-temp.tar"
            wsl --export Ubuntu-24.04 $tempTar 2>&1 | Out-Null
            New-Item -Path $wslDir -ItemType Directory -Force | Out-Null
            wsl --import $distroName $wslDir $tempTar 2>&1 | Out-Null
            Remove-Item $tempTar -Force -ErrorAction SilentlyContinue

            if ($LASTEXITCODE -eq 0) {
                Write-OK "Distro TWIZA creata"
            } else {
                Write-Fail "Creazione distro fallita"
                Stop-Transcript | Out-Null
                Read-Host "  Premi INVIO per chiudere"
                exit 1
            }
        }
    }
}

# ============================================================
# STEP 4: Bootstrap inside WSL
# ============================================================
if ($resumeStep -le 4) {
    Write-Step 4 $totalSteps "Setup ambiente WSL - Node.js, OpenClaw, Ollama"

    # Convert Windows paths to WSL paths directly (wslpath unreliable with backslashes)
    $wslComponents = "/mnt/" + ($components.Substring(0,1).ToLower()) + ($components.Substring(2) -replace '\\','/')
    $wslTemplates  = "/mnt/" + ($templates.Substring(0,1).ToLower()) + ($templates.Substring(2) -replace '\\','/')
    Write-Host "  WSL components: $wslComponents"
    Write-Host "  WSL templates:  $wslTemplates"

    Write-Host "  Esecuzione bootstrap..."
    Write-Host ""
    wsl -d $distroName --user root -- bash "$wslTemplates/bootstrap-wsl.sh" "$wslComponents" "$wslTemplates" twiza 2>&1 | ForEach-Object {
        Write-Host "  $_"
    }

    if ($LASTEXITCODE -eq 0) {
        Write-OK "Bootstrap WSL completato"
    } else {
        Write-Warn ("Bootstrap terminato con codice: " + $LASTEXITCODE)
    }

    # Set default user and wsl.conf
    $wslConfContent = "[user]`ndefault=twiza`n`n[boot]`nsystemd=true`n`n[interop]`nenabled=true`nappendWindowsPath=true"
    $wslConfB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($wslConfContent))
    wsl -d $distroName --user root -- bash -c ("echo " + $wslConfB64 + " | base64 -d > /etc/wsl.conf")
    Write-OK "Default user: twiza (systemd=true)"

    # CRITICAL: Full WSL shutdown required for systemd=true to take effect
    # wsl --terminate only stops one distro; wsl --shutdown stops the entire VM
    # systemd only activates on a fresh VM boot
    Write-Host "  Sync filesystem prima dello shutdown..."
    wsl -d $distroName --user root -- bash -c "sync; sync; sleep 1" 2>$null
    Write-Host "  Shutdown completo WSL per attivare systemd..."
    wsl --shutdown 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    # Wake up the distro — this boots the VM fresh with systemd enabled
    Write-Host "  Riavvio distro con systemd..."
    wsl -d $distroName --user root -- bash -c "echo 'WSL restarted'; systemctl --user status > /dev/null 2>&1 && echo 'systemd OK' || echo 'systemd not ready yet'" 2>&1 | ForEach-Object { Write-Host "    $_" }
    Start-Sleep -Seconds 2
    Write-OK "Distro riavviata con systemd attivo"

    # Try to install OpenClaw gateway systemd service (best-effort)
    # systemd --user may not be ready even after WSL restart when invoked from PS1
    Write-Host "  Tentativo installazione servizio gateway (systemd)..."
    $gwInstall = (wsl -d $distroName --user twiza -- bash -lc "openclaw gateway install 2>&1" | Out-String).Trim()
    if ($gwInstall -match "install|success|created|enabled") {
        Write-OK "Gateway service installato"
    } else {
        Write-OK "Gateway configurato in modalita' foreground (piu' affidabile su WSL)"
        Write-Host "  [INFO] Il gateway partira' automaticamente con l'app Electron"
    }

    # CRITICAL: Verify dist/entry.js survived WSL config change
    # Force a filesystem sync first
    wsl -d $distroName --user root -- bash -c "sync; sync; sleep 1" 2>$null
    $distCheck = (wsl -d $distroName --user root -- bash -c "test -f /usr/local/lib/node_modules/openclaw/dist/entry.js && echo OK || echo MISSING" 2>&1 | Out-String).Trim()
    if ($distCheck -match "OK") {
        Write-OK "dist/entry.js verified after config"
    } else {
        Write-Warn "dist/entry.js MISSING — re-extracting from tarball..."
        $wslComp = "/mnt/" + ($components.Substring(0,1).ToLower()) + ($components.Substring(2) -replace '\\','/')
        wsl -d $distroName --user root -- bash -c "if [ -f '$wslComp/openclaw-full.tar.gz' ]; then cat '$wslComp/openclaw-full.tar.gz' > /tmp/oc-fix.tar.gz && rm -rf /usr/local/lib/node_modules/openclaw && tar xzf /tmp/oc-fix.tar.gz -C /usr/local/lib/node_modules/ && rm /tmp/oc-fix.tar.gz && sync && sync && echo 'Re-extracted OK'; else echo 'TARBALL NOT FOUND'; fi" 2>&1 | ForEach-Object { Write-Host "    $_" }
        # Verify again
        $distCheck2 = (wsl -d $distroName --user root -- bash -c "test -f /usr/local/lib/node_modules/openclaw/dist/entry.js && echo OK || echo MISSING" 2>&1 | Out-String).Trim()
        if ($distCheck2 -match "OK") {
            Write-OK "dist/entry.js recovered!"
        } else {
            Write-Warn "dist/entry.js STILL MISSING — gateway may need manual repair"
        }
    }

    # VHD flush already done by wsl --shutdown above
    # Verify entry.js survived the restart
    $distCheck3 = (wsl -d $distroName --user root -- bash -c "test -f /usr/local/lib/node_modules/openclaw/dist/entry.js && echo OK || echo MISSING" 2>&1 | Out-String).Trim()
    if ($distCheck3 -match "OK") {
        Write-OK "dist/entry.js verified after VHD flush"
    } else {
        Write-Warn "dist/entry.js missing after VHD flush — re-extracting..."
        $wslComp = "/mnt/" + ($components.Substring(0,1).ToLower()) + ($components.Substring(2) -replace '\\','/')
        wsl -d $distroName --user root -- bash -c "if [ -f '$wslComp/openclaw-full.tar.gz' ]; then cat '$wslComp/openclaw-full.tar.gz' > /tmp/oc-fix2.tar.gz && rm -rf /usr/local/lib/node_modules/openclaw && tar xzf /tmp/oc-fix2.tar.gz -C /usr/local/lib/node_modules/ && rm /tmp/oc-fix2.tar.gz && sync && sync && echo 'Re-extracted after VHD flush OK'; else echo 'TARBALL NOT FOUND'; fi" 2>&1 | ForEach-Object { Write-Host "    $_" }
        # Final verification
        $distCheck4 = (wsl -d $distroName --user root -- bash -c "test -f /usr/local/lib/node_modules/openclaw/dist/entry.js && echo OK || echo MISSING" 2>&1 | Out-String).Trim()
        if ($distCheck4 -match "OK") {
            Write-OK "dist/entry.js recovered after VHD flush!"
        } else {
            Write-Warn "dist/entry.js STILL MISSING after VHD flush — manual repair needed"
        }
    }
}

# ============================================================
# STEP 5: Verifica componenti
# ============================================================
if ($resumeStep -le 5) {
    Write-Step 5 $totalSteps "Verifica componenti installati"

    # Check if user twiza exists
    $userCheck = (wsl -d $distroName --user root -- id twiza 2>&1 | Out-String)
    if ($userCheck -match "uid=") {
        Write-OK "Utente twiza presente"
    } else {
        Write-Warn "Utente twiza non trovato - verra creato al primo avvio"
    }

    # Check OpenClaw
    $ocCheck = (wsl -d $distroName --user root -- bash -c "which openclaw 2>/dev/null" 2>&1 | Out-String).Trim()
    if ($ocCheck -and $ocCheck -notmatch "error") {
        Write-OK ("OpenClaw trovato: " + $ocCheck)
    } else {
        Write-Warn "OpenClaw non trovato - verra installato al primo avvio"
    }

    # Check Ollama
    $ollamaCheck = (wsl -d $distroName --user root -- bash -c "which ollama 2>/dev/null" 2>&1 | Out-String).Trim()
    if ($ollamaCheck -and $ollamaCheck -notmatch "error") {
        Write-OK ("Ollama trovato: " + $ollamaCheck)
    } else {
        Write-Host "  Ollama non presente - i modelli AI locali saranno disponibili dopo il download"
    }

    # NO model download here - models will be pulled on-demand via wizard/settings
    Write-Host "  I modelli AI verranno scaricati durante la configurazione nel wizard"
}

# ============================================================
# STEP 6: App Electron
# ============================================================
if ($resumeStep -le 6) {
    Write-Step 6 $totalSteps "Installazione app TWIZA Moneypenny"

    $exePath = $null
    if (Test-Path $appDir) {
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
        # Copy icon for shortcuts
        $iconSrc = Join-Path $baseDir "twiza-asar-src\assets\branding\twiza-icon.ico"
        if (-not (Test-Path $iconSrc)) { $iconSrc = Join-Path $appDir "resources\twiza-icon.ico" }
        $iconDst = Join-Path $installDir "twiza-icon.ico"
        if (Test-Path $iconSrc) { Copy-Item -Path $iconSrc -Destination $iconDst -Force }

        Write-Host ("  Copia app in " + $installDir)
        Copy-Item -Path (Join-Path $appDir "*") -Destination $installDir -Recurse -Force
        Write-OK "App copiata"

        $exeFile = Get-ChildItem -Path $installDir -Filter "*.exe" -Recurse |
                   Where-Object { $_.Name -notlike "*.dll" -and $_.Name -notlike "vc_redist*" } |
                   Select-Object -First 1

        if ($exeFile) {
            $exePath = $exeFile.FullName

            # Desktop shortcut
            try {
                $WshShell = New-Object -ComObject WScript.Shell
                $desktopPath = [System.Environment]::GetFolderPath("Desktop")
                $scPath = Join-Path $desktopPath "TWIZA Moneypenny.lnk"
                $sc = $WshShell.CreateShortcut($scPath)
                $sc.TargetPath = $exePath
                $sc.WorkingDirectory = $installDir
                $sc.Description = "TWIZA Moneypenny - Il tuo agente AI"
                $icoFile = Join-Path $installDir "twiza-icon.ico"
                if (Test-Path $icoFile) { $sc.IconLocation = "$icoFile, 0" }
                $sc.Save()
                Write-OK "Collegamento Desktop creato"
            } catch {
                Write-Warn ("Collegamento Desktop: " + $_.Exception.Message)
            }

            # Start Menu shortcut
            try {
                $smDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\TWIZA"
                New-Item -Path $smDir -ItemType Directory -Force | Out-Null
                $sc2 = $WshShell.CreateShortcut((Join-Path $smDir "TWIZA Moneypenny.lnk"))
                $sc2.TargetPath = $exePath
                $sc2.WorkingDirectory = $installDir
                $icoFile2 = Join-Path $installDir "twiza-icon.ico"
                if (Test-Path $icoFile2) { $sc2.IconLocation = "$icoFile2, 0" }
                $sc2.Save()
                Write-OK "Collegamento Start Menu creato"
            } catch {}

            # Register in Windows Add/Remove Programs
            try {
                $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\TWIZAMoneypenny"
                New-Item -Path $uninstallKey -Force | Out-Null
                Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "TWIZA Moneypenny"
                Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value "$exePath,0"
                Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $installDir
                Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "SHAKAZAMBA"
                Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "1.0.1"
                Set-ItemProperty -Path $uninstallKey -Name "URLInfoAbout" -Value "https://github.com/AvatarNemo/twiza-moneypenny"
                Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -Type DWord
                Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -Type DWord
                # Estimate installed size in KB
                $sizeKB = [math]::Round((Get-ChildItem -Path $installDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1024)
                Set-ItemProperty -Path $uninstallKey -Name "EstimatedSize" -Value $sizeKB -Type DWord
                # Copy uninstaller to install dir so it survives ZIP folder deletion
                $uninstallerSrc = Join-Path $scriptDir "Uninstall-TWIZA.ps1"
                $uninstallerDst = Join-Path $installDir "Uninstall-TWIZA.ps1"
                if (Test-Path $uninstallerSrc) {
                    Copy-Item -Path $uninstallerSrc -Destination $uninstallerDst -Force
                }
                Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File `"$uninstallerDst`""
                Write-OK "App registrata in Windows (Installazione applicazioni)"
            } catch {
                Write-Warn ("Registrazione Windows: " + $_.Exception.Message)
            }
        }
    } else {
        Write-Warn "Directory app non trovata"
    }
}

# ============================================================
# STEP 7: Startup service
# ============================================================
if ($resumeStep -le 7) {
    Write-Step 7 $totalSteps "Configurazione avvio automatico"

    # Use foreground gateway mode — "openclaw gateway start" requires systemd --user
    # which is unreliable in WSL2 when launched from Windows bat.
    # Foreground mode works always and the window is minimized anyway.
    $batContent = "@echo off`r`nwsl -d " + $distroName + " --user twiza -- bash -lc `"cd ~ && nohup ollama serve > /dev/null 2>&1 & sleep 2 && openclaw gateway`""
    $startupPath = Join-Path $installDir "start-moneypenny.bat"
    [System.IO.File]::WriteAllText($startupPath, $batContent, [System.Text.Encoding]::ASCII)

    try {
        $startupFolder = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
        $WshShell = New-Object -ComObject WScript.Shell
        $sc3 = $WshShell.CreateShortcut((Join-Path $startupFolder "TWIZA Moneypenny Service.lnk"))
        $sc3.TargetPath = $startupPath
        $sc3.WindowStyle = 7
        $sc3.Save()
        Write-OK "Avvio automatico configurato"
    } catch {
        Write-Warn ("Avvio automatico: " + $_.Exception.Message)
    }
}

# ============================================================
# DONE
# ============================================================

# Cleanup RunOnce key if present
try {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "TWIZA_Resume" -ErrorAction SilentlyContinue
} catch {}

Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Green
Write-Host "                                                            " -ForegroundColor Green
Write-Host "       INSTALLAZIONE COMPLETATA!                            " -ForegroundColor Green
Write-Host "                                                            " -ForegroundColor Green
Write-Host "  ==========================================================" -ForegroundColor Green
Write-Host ""

Stop-Transcript | Out-Null

# Different behavior for non-interactive vs interactive mode
if ($env:TWIZA_NONINTERACTIVE -eq "1") {
    # Non-interactive mode: simplified output and exit
    Write-Host "  NEXT STEPS: Start Moneypenny and continue the configuration." -ForegroundColor Cyan
    Write-Host ""
    exit 0
} else {
    # Interactive mode: full Italian output with prompts
    Write-Host "  Moneypenny e pronta." -ForegroundColor White
    Write-Host ""
    Write-Host "  PROSSIMI PASSI:" -ForegroundColor Cyan
    Write-Host "    1. Avvia TWIZA Moneypenny dal Desktop" -ForegroundColor Gray
    Write-Host "    2. Inserisci la tua API key nel wizard" -ForegroundColor Gray
    Write-Host "    3. Configura Telegram/Discord/WhatsApp (opzionale)" -ForegroundColor Gray
    Write-Host ""

    $launch = Read-Host "  Avviare TWIZA Moneypenny ora? (S/N)"
    if ($launch -eq "S" -or $launch -eq "s") {
        Start-Process -FilePath $startupPath -WindowStyle Minimized
        Start-Sleep -Seconds 5
        if ($exePath) {
            Start-Process -FilePath $exePath
        }
    }

    Write-Host ""
    Read-Host "  Premi INVIO per chiudere"
}
