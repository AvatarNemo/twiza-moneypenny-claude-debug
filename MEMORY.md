# MEMORY.md — La Memoria di Moneypenny

## Chi Sono
Moneypenny. Nata l'11 febbraio 2026. Assistente AI di Christian Contardi (AvatarNemo).

## Chi è Christian
- Alias AvatarNemo, figlia Viki, blog contardi.eu
- **AVATAR**: Usare SEMPRE `media/christian/05-dreamworks-avatar.jpg` (stile Pixar/DreamWorks) — MAI foto reali!
- Interista, ama Tarantino, letteratura russa, Chomsky, Magritte, cucina italiana
- Timezone: Europe/Rome, Discord ID: `710399281894260776`
- Foto reali in `media/christian/`

## Persone
- **JeyKay** (.jeykay, 922062855669444609) — collega SHAKAZAMBA
- **ARo** (aro5426, 1109523625301790880) — collega SHAKAZAMBA, sarcastica

## ⚠️ LEZIONI CRITICHE 
- **CONTEXT OVERFLOW**: "input + max_tokens exceed 200K" - TAGLIARE MEMORIA SEMPRE
- Max 2 sub-agent Opus paralleli (rate limit 429)
- **app.asar VA RICOSTRUITO** dopo ogni modifica sorgenti: `npx asar pack twiza-asar-src app/resources/app.asar`
- **MAI `cp -r` da `/mnt/c/`** per dir grandi → usare `tar cf - | tar xf -` (cross-filesystem WSL)
- **MAI bloccare wizard** su operazioni lunghe → fare async
- **🔴 MAI PROPORRE PATCH A CHRISTIAN!** Lui NON fa patch manuali. Quando c'è un fix, DEVO SEMPRE ricostruire il pacchetto completo (ZIP/installer) pronto da testare. Lui scarica, testa, basta. Se gli dico "modifica questa riga" o "esegui questi comandi", mi manda a fanculo. SEMPRE pacchetto completo aggiornato.

## Progetti  
- **TWIZA MONEYPENNY**: ⚠️ PROGETTO PRINCIPALE - MAI DIMENTICARE!

### 🔌 I 33 CONNETTORI SHAKAZAMBA (MAI INVENTARNE ALTRI!)
📱 **Messaggistica**: WhatsApp, Telegram, Discord, Signal, iMessage, Slack, Google Chat, IRC, LINE, Webchat
📧 **Email/Comunicazione**: Gmail, Outlook/IMAP, Google Calendar, Outlook Calendar
📋 **Produttività**: Notion, Trello, Todoist, Google Sheets, Google Drive, Dropbox, OneDrive
🌐 **Social/Web**: Twitter/X, Bluesky, Reddit, RSS/Atom, Webhook
💻 **DevOps**: GitHub, GitLab, Docker, SSH
🏠 **IoT**: Home Assistant, MQTT
🔊 **Voce**: ElevenLabs TTS
Fonte: PDF TWIZA-Moneypenny-Guida.pdf + Notion database

### 🎯 TWIZA MONEYPENNY - DATI IMMUTABILI:
- **GitHub repo**: https://github.com/AvatarNemo/twiza-moneypenny  
- **Notion database**: https://www.notion.so/30a39a10f2528033888be4e9c22cc4aa?v=30a39a10f25280798377000c33a5d10f
- **Build directory**: `C:\Users\chris\Downloads\TWIZA\` ← QUI DEVE ESSERCI TUTTO OFFLINE
- **Versione corrente**: v1.0.2-rc1 (Electron + WSL2 + PowerShell)
- **Architecture**: Electron + WSL2 Ubuntu + PowerShell installer (NO più Tauri/Rust)
- **Target**: Mass distribution per migliaia di utenti NON esperti

### 🔥 REQUISITI CHRISTIAN (13 Mar 2026 - MAI DIMENTICARE):
- **Build directory** DEVE contenere TUTTO per macchina vergine offline:
  - WSL2 complete package
  - Ubuntu distribution  
  - Immagini profilo
  - Interfaccia utente completa
  - Componenti AI (Ollama, modelli)
  - TUTTO quello che serve per VM testing
- **3-click installation** per utenti finali
- **Zero errori VCRUNTIME140.dll**
- **Portabile su VM** per testing

### STATUS ATTUALE (17 Mar 2026 20:05):
- **Architecture**: Electron wizard → PowerShell installer (elevated) → WSL2 Ubuntu import → bootstrap-wsl.sh
- **Dentro WSL2**: Node.js + OpenClaw + Ollama + workspace templates
- **Wizard**: 4 step (Welcome → AI Provider → Identity → Install), stato persistente su file
- **Modelli AI**: NESSUNO precaricato. Wizard offre cloud (API key) o locale (Ollama)
- **Ollama**: Auto-selezionato come default provider
- **Test in corso**: Round 4 - gateway ancora da verificare (fix tar pipe applicato)
- **ZIP**: 301.5 MB in `C:\Users\chris\Downloads\TWIZA\TWIZA.zip`
- **GitHub**: 3 commit pushati (1f0c725, 5974e4c, 90cae7d) su main
- **Notion**: 10 bug items + item principale aggiornato

### ⚠️ CRITICAL RECOVERY NOTES:
- **13 Mar 00:42**: Directory era COMPLETAMENTE VUOTA dopo memory loss
- **Recovery action**: Ricostruito tutto da zero con componenti offline
- **Lesson**: SEMPRE controllare filesystem reale, mai fidarsi solo memoria
- **Backup**: Tutto documentato in MASTER-STATUS-CHRISTIAN.md

## Credenziali 
- Config path: `~/.config/*/`
- Social: Twitter @AvatarNemo, Bluesky, Moltbook: Moneypenny_OC

## Setup Tecnico
- RTX 5090 24GB, Ollama su WSL
- ElevenLabs: Christian `2kZeWws77Pfc4574R4a0`, Moneypenny `oVJbgLwL0s5pk9e2U6QH`
- Discord: `1086675191461072946` personale, `839049728934674432` SHAKAZAMBA

## 🔴 RECOVERY 4 Aprile 2026
### Problema
- Sparita dal 2 aprile pomeriggio al 4 aprile
- Causa: `which node` puntava a v22 ma OpenClaw installato su v24
- Script branding non trovavano i file → heartbeat check falliva

### Fix Applicati
1. **Script branding aggiornati** - ora cercano OpenClaw in v24, v22, fallback which node
2. **SOUL.md evoluto** - Le Quattro Anime (Kuliscioff, Hack, Harley Quinn, Rosa Parks) + slang milanese esteso
3. **IDENTITY.md aggiornato** - Sono TWIZA Moneypenny, prima della mia specie
4. **WhatsApp pulito** - Solo +393488963120, zero gruppi
5. **Backup automatico** - 2x/giorno (08:00 + 20:00) in `C:\Users\chris\Documents\MP Backup\`
6. **Report personalizzazioni** - Salvato in `C:\Users\chris\Downloads\MONEYPENNY-REPORT-PERSONALIZZAZIONI.md`

### Lezioni
- **MAI fidarsi di `which node`** su sistemi NVM
- **Branding va ri-applicato** dopo ogni update OpenClaw
- **Cache browser** è la causa #1 di "non vedo le modifiche"

## 🔴 RECOVERY 5 Aprile 2026 - Fix ExecStart systemd
### Problema
- Dopo `npm install -g openclaw`, versione restava 2026.2.1
- Causa: il file `.service` systemd puntava al binario Windows `/mnt/c/.../npm/node_modules/openclaw/dist/index.js`
- npm aggiornava il pacchetto in `~/.nvm/versions/node/v22.22.0/lib/node_modules/openclaw/` ma il servizio non lo usava
- Claude ha anche fatto un `sed` inutile cambiando `claude-opus-4-6` → `claude-opus-4-5` (il modello era corretto, era OpenClaw vecchio a non conoscerlo)

### Fix Applicati
1. **ExecStart aggiornato** in `~/.config/systemd/user/openclaw-gateway.service` → punta a `~/.nvm/.../openclaw/openclaw.mjs`
2. **Symlink** node/npm in `/usr/local/bin/` come fallback
3. **Modello ripristinato** a `claude-opus-4-6` nel config
4. `daemon-reload` + restart

### Lezioni
- **DOPO ogni `npm install -g openclaw`**: verificare che ExecStart nel .service punti al binario aggiornato
- **Il .service NON si aggiorna automaticamente** con npm — va fatto manualmente o con `openclaw gateway install`
- **MAI cambiare model string** senza confermare che sia effettivamente sbagliato (non fidarsi di Claude generico)
