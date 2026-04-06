# 🦾 TWIZA Windows Installer Builder

**Sistema unificato per creare installer Windows completi di TWIZA**

## 🎯 OBIETTIVO

Creare un **installer Windows tradizionale** (.exe) che gestisce automaticamente:
- ✅ Installazione applicazione desktop
- ✅ Configurazione WSL2 + Ubuntu  
- ✅ Setup Ollama + OpenClaw
- ✅ Esperienza utente "next, next, install"

## 📁 FILE NECESSARI

### Devi avere questi file:
```
build-twiza-installer.bat          ← Script di build principale
TWIZA-Windows-Installer.nsi        ← Configurazione NSIS
LICENSE.txt                        ← Licenza software
install-twiza-automated.ps1        ← Script PowerShell ottimizzato
```

### File componenti TWIZA (da cartella TWIZA/):
```
Ubuntu-22.04-WSL.appx             ← Pacchetto Ubuntu WSL (1.1GB)
TWIZA-Moneypenny-2.2.1-Setup.exe  ← App desktop Electron
```

## 🚀 COME USARE

### Step 1: Installa NSIS
1. Scarica NSIS da: https://nsis.sourceforge.io/
2. Installa e assicurati che `makensis.exe` sia nel PATH

### Step 2: Prepara i file
```bash
# Posizionati nella directory con tutti i file
cd /path/to/twiza-installer-build

# Verifica che ci siano tutti i componenti:
ls -la *.nsi *.bat *.ps1 *.txt
ls -la TWIZA/Ubuntu-22.04-WSL.appx TWIZA/TWIZA-Moneypenny-2.2.1-Setup.exe
```

### Step 3: Build
```bash
# Esegui il build script
./build-twiza-installer.bat
```

### Step 4: Distribuisci
Il risultato è:
```
TWIZA-Moneypenny-2.2.1-Complete-Installer.exe  (~1.1GB)
```

## ✨ COSA FA L'INSTALLER

### Interfaccia utente:
1. **Welcome** - Schermata di benvenuto SHAKAZAMBA
2. **License** - Accordo licenza + brevetto UIBM  
3. **Components** - Selezione componenti (tutti obbligatori)
4. **Directory** - Cartella installazione
5. **Install** - Barra progresso installazione
6. **Finish** - Opzione per avviare TWIZA

### Processo automatico:
1. **Verifica prerequisiti** (Windows 10 2004+, admin rights)
2. **Installa app desktop** (TWIZA-Moneypenny-2.2.1-Setup.exe)
3. **Abilita WSL2** (se necessario, con prompt riavvio)
4. **Installa Ubuntu** da pacchetto offline
5. **Crea utente `twiza`** in Ubuntu WSL
6. **Installa dependencies** (Node.js, Ollama, OpenClaw)
7. **Configura shortcuts** desktop + start menu
8. **Avvia TWIZA** (opzionale)

## 🔧 PERSONALIZZAZIONE

### Modificare versione:
Edita `TWIZA-Windows-Installer.nsi`:
```nsis
!define PRODUCT_VERSION "2.2.2"  # Cambia qui
```

### Aggiungere componenti:
Aggiungi sezioni nel file .nsi:
```nsis
Section "Nuovo Componente" SEC04
  # Installazione componente aggiuntivo
SectionEnd
```

### Personalizzare grafica:
Sostituisci in `assets/`:
- `twiza-icon.ico` - Icona applicazione
- `twiza-welcome.bmp` - Immagine welcome (164x314 px)

## 🛠️ TROUBLESHOOTING

### NSIS non trovato:
```
ERROR: NSIS not found in PATH
```
**Soluzione:** Installa NSIS e aggiungi al PATH

### File mancanti:
```
ERROR: Required file missing: Ubuntu-22.04-WSL.appx
```
**Soluzione:** Copia i file dalla cartella TWIZA/ corrente

### Build fallita:
```
BUILD FAILED!
```
**Soluzione:** Controlla log NSIS per errori sintassi

### Installer non funziona:
1. Esegui come **Amministratore**
2. Verifica Windows 10 build 19041+
3. Controlla log: `%TEMP%\twiza-install.log`

## 📊 SPECIFICHE TECNICHE

### Output finale:
- **Nome:** TWIZA-Moneypenny-2.2.1-Complete-Installer.exe
- **Dimensione:** ~1.1GB (Ubuntu WSL = 99% del peso)
- **Target:** Windows 10 2004+ / Windows 11
- **Permessi:** Richiede Administrator
- **Dipendenze:** Nessuna (tutto offline)

### Directory installazione:
- **App desktop:** `%LOCALAPPDATA%\Programs\twiza-moneypenny\`
- **Files installer:** `%PROGRAMFILES%\SHAKAZAMBA\TWIZA\`
- **WSL environment:** Ubuntu distribution `twiza` user

### Registry:
- **Uninstall key:** `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\TWIZA Moneypenny`
- **Config:** `HKLM\Software\SHAKAZAMBA\TWIZA`

## 🎯 VANTAGGI INSTALLER WINDOWS

✅ **Esperienza familiare** - Doppio click, next, next, install  
✅ **Tutto incluso** - Zero dipendenze esterne  
✅ **Gestione errori** - Messaggi chiari, log dettagliato  
✅ **Uninstaller** - Rimozione pulita tramite Pannello Controllo  
✅ **Professional** - Dialoghi standard Windows, icone, branding  
✅ **Offline complete** - Funziona senza internet  

## 📞 SUPPORTO

- 🌐 **Website:** https://shakazamba.com
- 📧 **Email:** info@shakazamba.com  
- 💬 **Discord:** OpenClaw Community
- 📚 **Docs:** https://docs.openclaw.ai

---

**SHAKAZAMBA S.r.l. - BREVETTO UIBM N. 102024000025755**  
*Built by Moneypenny 🦾 - Incrocio tra Mara Maionchi e Deadpool*