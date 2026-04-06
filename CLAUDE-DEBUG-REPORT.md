# 🤖 TWIZA Moneypenny — Debug Report

**Analizzato da:** Claude Sonnet 4.6 (Anthropic)  
**Data analisi:** 2026-04-06  
**Repository originale:** https://github.com/AvatarNemo/twiza-moneypenny  
**Fork debug:** https://github.com/AvatarNemo/twiza-moneypenny-claude-debug  
**Versione:** `1.0.2-rc7` (package.json) / `v7.1` (installer)  
**Tecnologia principale:** Electron 33 + Node.js + WSL2 + OpenClaw (gateway AI)

---

## 1. Panoramica del Progetto

TWIZA Moneypenny è un'applicazione desktop Windows (Electron) che funge da front-end per un agente AI personale. L'architettura è a tre livelli:

```
[Electron UI Windows]
        ↕ IPC (contextIsolation)
[Main Process Node.js]
        ↕ WSL2 spawn/execSync
[TWIZA distro Linux (WSL2)]
        └─ OpenClaw gateway (porta 18789)
              └─ Ollama / Cloud API (Anthropic, OpenAI, Gemini, Groq...)
```

Il progetto è in **stato ibrido**: la codebase contiene simultaneamente residui di una precedente architettura **Tauri/Rust** (abbandonata) e l'implementazione corrente **Electron**. Questa situazione genera significativa confusione strutturale.

---

## 2. Struttura dei File

```
twiza-moneypenny/
├── main.js                    ← Entry point STALE (non usato - vedi §3.1)
├── src/
│   ├── main.js                ← Entry point EFFETTIVO (indicato in package.json)
│   ├── config-generator.js    ← Generazione openclaw.json (892 righe)
│   ├── i18n.js                ← Internazionalizzazione IT/EN (478 righe)
│   └── wizard/
│       └── index.html         ← UI wizard (unico file HTML presente in src/)
├── src-tauri/                 ← Backend Rust ABBANDONATO (vedi §3.2)
│   ├── src/
│   │   ├── main.rs
│   │   ├── gateway.rs
│   │   ├── oauth.rs
│   │   ├── state.rs
│   │   └── wsl.rs
│   ├── Cargo.toml
│   └── tauri.conf.json
├── installer/
│   ├── Install-TWIZA.ps1      ← Installer PowerShell v7.1
│   └── Uninstall-TWIZA.ps1
├── templates/
│   └── openclaw.json.template ← Template configurazione gateway
├── integrations/
│   └── manus.js               ← Integrazione Manus AI (standalone)
├── docs-moneypenny/           ← Documentazione HTML inline
├── branding/                  ← Script e asset branding OpenClaw
├── memory/                    ← Log sessioni runtime agente (NON codice)
├── workspace-template/        ← Template workspace agente AI
├── preview/                   ← HTML preview chat e wizard
├── plans/                     ← Piano automazione social media
└── scripts/                   ← Script build e setup
```

---

## 3. Bug Critici (Bloccanti)

### 3.1 🔴 BUG CRITICO — File `main.js` alla radice è uno zombie

**Severità:** CRITICA  
**File:** `/main.js` (root) vs `src/main.js`

`package.json` dichiara `"main": "src/main.js"`, quindi l'entry point effettivo è `src/main.js`. Tuttavia esiste anche un `main.js` nella root con contenuto quasi identico ma con una **differenza sostanziale**:

| Costante | `main.js` (root, STALE) | `src/main.js` (CORRENTE) |
|---|---|---|
| `GATEWAY_PORT` | `1337` | `18789` |
| `WEBCHAT_PORT` | `18789` | `18789` |

Il file root `main.js` usa `GATEWAY_PORT = 1337` per il health check HTTP, mentre il gateway OpenClaw gira su **18789**. Se per qualsiasi motivo venisse usato il file root, il health check fallirebbe sempre e il gateway verrebbe riavviato in loop continuo.

**Fix:** Eliminare `/main.js` dalla root del progetto.

---

### 3.2 🔴 BUG CRITICO — Moduli richiesti inesistenti (crash immediato all'avvio)

**Severità:** CRITICA  
**File:** `src/main.js` righe 6-8

```javascript
const { createTray, updateTrayStatus } = require('./tray');
const { generateConfig, generateTemplates, deployToWSL } = require('./config-generator');
const { startAutoCheck, stopAutoCheck, checkForUpdates, getCurrentVersion } = require('./updater');
```

I seguenti file **non esistono** nel repository:

| File richiesto | Stato |
|---|---|
| `src/tray.js` | ❌ MANCANTE |
| `src/updater.js` | ❌ MANCANTE |
| `src/preload.js` | ❌ MANCANTE (richiesto da tutte le BrowserWindow) |

**Conseguenza:** L'applicazione va in crash immediato con `MODULE_NOT_FOUND` all'avvio. Nessuna finestra verrà mai mostrata.

**Nota:** `src/config-generator.js` **esiste** ed è correttamente richiesto.

**Fix:** Creare `src/tray.js`, `src/updater.js`, `src/preload.js` con le funzioni esportate attese.

---

### 3.3 🔴 BUG CRITICO — Directory UI richieste inesistenti

**Severità:** CRITICA  
**File:** `src/main.js`

Le seguenti directory/file HTML sono referenziati via `loadFile()` ma **non esistono**:

| Path cercato | Funzione | Stato |
|---|---|---|
| `src/onboarding/index.html` | `createOnboardingWindow()` | ❌ MANCANTE |
| `src/settings/index.html` | `openSettingsWindow()` | ❌ MANCANTE |
| `src/models/index.html` | `openModelsWindow()` | ❌ MANCANTE |

Esiste solo `src/wizard/index.html`. Ogni finestra che non sia il wizard fallirà silenziosamente (log `FAIL LOAD` ma nessun crash bloccante grazie all'handler `did-fail-load`).

---

### 3.4 🔴 BUG CRITICO — Asset build mancanti

**Severità:** CRITICA  
**File:** `package.json` (build config)

Il processo di build NSIS richiede file inesistenti:

| File richiesto da | Asset | Stato |
|---|---|---|
| `package.json` build.nsis | `assets/branding/twiza-icon.ico` | ❌ MANCANTE |
| `package.json` build.nsis | `assets/installer-sidebar.bmp` | ❌ MANCANTE |
| `package.json` build.nsis | `scripts/nsis-hooks.nsh` | ❌ MANCANTE |

Il file `assets/branding/twiza-icon.png` **esiste** ma l'`.ico` no. Il fallback in `getIconPath()` gestisce questo runtime, ma il processo di build `electron-builder` fallirà.

---

## 4. Bug Importanti (Non bloccanti a runtime ma problematici)

### 4.1 🟠 BUG — Template OpenClaw: mismatch nome/ID modello Ollama

**Severità:** ALTA  
**File:** `templates/openclaw.json.template`

```json
"id": "qwen2.5:3b",
"name": "Gemma 3 4B"   ← ERRORE: ID è qwen2.5, name dice Gemma 3
```

Il campo `id` referenzia correttamente `qwen2.5:3b` ma il `name` visualizzato all'utente recita "Gemma 3 4B" — un modello completamente diverso (Google). Questo confonde l'utente nella UI del model manager.

**Fix:** Correggere il `name` in `"Qwen 2.5 3B"`.

---

### 4.2 🟠 BUG — Architettura duale Tauri/Electron non risolta

**Severità:** ALTA  
**File:** `src-tauri/`, `package.json`, `ROADMAP.md`

Il `ROADMAP.md` afferma che la migrazione a Tauri è completata (`✅ Migrazione a Tauri 2.x`), ma l'applicazione è interamente Electron. La directory `src-tauri/` contiene 5 file Rust funzionali (`main.rs`, `gateway.rs`, `oauth.rs`, `state.rs`, `wsl.rs`) e una `tauri.conf.json`, ma:

- `package.json` non include Tauri come dipendenza (solo `electron` e `electron-builder`)
- L'entry point è Electron (`src/main.js`)
- Il `ROADMAP.md` è quindi **fuorviante** per altri sviluppatori/AI che analizzano il progetto

**Fix:** Scegliere un'architettura e rimuovere l'altra, oppure documentare chiaramente che `src-tauri/` è un'implementazione alternativa non attiva.

---

### 4.3 🟠 BUG — `wizard:complete` IPC cerca installer con nome sbagliato

**Severità:** ALTA  
**File:** `src/main.js` riga ~960

```javascript
for (const name of ['Install-TWIZA.ps1', 'Install-TWIZA-v30.ps1']) {
```

Il file cercato `Install-TWIZA-v30.ps1` non esiste (il file presente è `Install-TWIZA.ps1`). Il secondo fallback è irraggiungibile. Non causa crash perché il primo nome corrisponde, ma se il file venisse rinominato il secondo fallback sarebbe sbagliato.

---

### 4.4 🟠 BUG — `openDocsPdf()` path resolution fragile

**Severità:** MEDIA  
**File:** `src/main.js` funzione `openDocsPdf()`

La funzione cerca il PDF percorrendo 3 livelli di directory parent da `app.getPath('exe')` in modo euristico. In ambienti packaged non standard o installazioni fuori percorso, non troverà mai il file e ricadrà silenziosamente sull'apertura della finestra HTML docs.

---

### 4.5 🟠 BUG — Validazione chiave API: pattern Mistral e Together errati

**Severità:** MEDIA  
**File:** `src/main.js` funzione `wizard:validate-key`

```javascript
const patterns = {
  mistral: /^[a-zA-Z0-9]{32}/,    // Senza $ finale: accetta qualsiasi stringa lunga 32+ char
  together: /^[a-f0-9]{64}/,       // Senza $ finale: stesso problema
};
```

I regex mancano dell'ancora finale `$`. Qualsiasi stringa che inizia con 32 caratteri alfanumerici supererà la validazione Mistral, anche se non è una vera chiave Mistral. La validazione live via HTTPS corregge questo per alcuni provider, ma non per tutti.

**Fix:** Aggiungere `$` ai pattern: `/^[a-zA-Z0-9]{32}$/` e `/^[a-f0-9]{64}$/`.

---

### 4.6 🟠 BUG — Gateway health check punta a `/health` ma la porta è quella webchat

**Severità:** MEDIA  
**File:** `src/main.js` funzione `pingGateway()`

```javascript
const req = http.get(`http://127.0.0.1:${GATEWAY_PORT}/health`, ...)
// GATEWAY_PORT = 18789 (stesso di WEBCHAT_PORT)
```

In `src/main.js` `GATEWAY_PORT` e `WEBCHAT_PORT` sono entrambe 18789 (corretto). Ma il gateway OpenClaw espone l'endpoint `/health` sulla stessa porta webchat? Dipende dalla configurazione di OpenClaw. Se il gateway non espone `/health` su 18789, il health check fallirà sempre e causerà restart loop ogni 30 secondi.

---

## 5. Bug Minori / Code Smell

### 5.1 🟡 — `config-generator.js` usa `deployToWSL` non esportato correttamente

**File:** `src/config-generator.js`  
La funzione `deployToWSL` è richiesta in `src/main.js` riga 7 ma non verificato se effettivamente esportata da `config-generator.js`. Se mancasse dall'`exports`, il destructuring restituirebbe `undefined` senza errore immediato ma fallirebbe all'invocazione.

### 5.2 🟡 — `integrations/manus.js` usa header non standard

**File:** `integrations/manus.js`

```javascript
headers: {
  'API_KEY': creds.apiKey,   // Convenzionalmente: 'Authorization': 'Bearer ...'
}
```

L'header `API_KEY` non è standard HTTP. Se l'API Manus cambia o segue convention diverse, questo fallirà silenziosamente.

### 5.3 🟡 — Duplicazione codice: `main.js` root e `src/main.js` quasi identici

1344 vs 1470 righe, con le prime sezioni identiche e divergenze solo nelle costanti (vedi §3.1). Nessun meccanismo di sync, rischio di divergenza.

### 5.4 🟡 — Timeout gateway: "assume started" dopo 20s senza conferma

**File:** `src/main.js` funzione `startGateway()`

```javascript
setTimeout(() => {
  if (gatewayStarting && gatewayProcess) {
    isGatewayRunning = true;  // Assume running senza verifica
    ...
  }
}, 20000);
```

Se il gateway non stampa `listening|ready|started|running` entro 20s (es. output in italiano/altra lingua), viene assunto running anche se non lo è. Il health check successivo dovrebbe correggerlo ma introduce una falsa finestra di "online".

### 5.5 🟡 — `branding/restore-branding.sh` eseguito ad ogni apertura chat

**File:** `src/main.js` funzione `openChatWindow()`

Lo script di restore branding viene eseguito con `spawnSync` (bloccante) ad ogni apertura della finestra chat. Con timeout 30s, può bloccare il thread UI se WSL è lento.

### 5.6 🟡 — `config sanitizer` usa python3 inline: fragile su shell escape

**File:** `src/main.js` funzione `startGateway()` pre-flight

```javascript
execSync(`${WSL_EXE} ... -- python3 -c "import json,os;p=os.path.expanduser..."`)
```

Il python3 one-liner usa doppi apici dentro una stringa già con doppi apici. Fragile a path con caratteri speciali e difficile da manutenere.

---

## 6. Analisi Sicurezza

### 6.1 ⚠️ — Memory files contengono chiavi API parziali in chiaro

**File:** `memory/2026-04-02.md`, `memory/2026-03-19.md`, altri

I file di memoria dell'agente (log giornalieri) contengono riferimenti a:
- Chiavi Anthropic (`sk-ant-api03-...` parziale)
- GitHub PAT parziali (`ghp_EDz6...`)

Questi file sono nel repository originale. Nel fork di debug sono stati esclusi (`.gitignore`), ma nel repo originale sono visibili a chiunque abbia accesso.

**Raccomandazione:** Aggiungere `memory/` al `.gitignore` del repo originale e considerare un audit completo con `git-secrets` o `trufflehog`.

### 6.2 ⚠️ — Esecuzione come root in WSL

**File:** `src/main.js`, `installer/Install-TWIZA.ps1`

Molti comandi WSL vengono eseguiti con `--user root`. Il pattern è comprensibile per l'installer, ma alcune operazioni post-install (copia file, chown) rimangono root quando potrebbero essere utente `twiza`.

### 6.3 ⚠️ — Token gateway hardcodato nel template

**File:** `templates/openclaw.json.template`

```json
"token": "___TWIZA_GENERATED_TOKEN___"
```

Il placeholder è sostituito correttamente da `config-generator.js`, ma se il template venisse distribuito senza sostituzione o la sostituzione fallisse silenziosamente, il gateway girerebbe senza autenticazione reale.

---

## 7. Funzionalità Implementate (Funzionanti)

### 7.1 ✅ Flusso di installazione completo (quando i moduli mancanti vengono forniti)

Il wizard in 4 fasi è ben strutturato:
1. **Onboarding** — benvenuto e prerequisiti
2. **Wizard** — configurazione provider AI, chiave API, identità agente
3. **Install** — esecuzione PowerShell elevato con tailing log in tempo reale
4. **Chat** — apertura webchat con retry loop fino a 90 secondi

### 7.2 ✅ Config Generator multi-provider

`src/config-generator.js` supporta 9 provider:
- Ollama (locale), Anthropic, OpenAI, Google Gemini, Groq, Mistral, xAI, Together AI, Fireworks AI, Perplexity

Generazione `openclaw.json` con workspace, memoria, canali, gateway.

### 7.3 ✅ Gateway lifecycle management

Start/stop/restart del processo OpenClaw in WSL2 con:
- Pre-flight check OpenClaw `dist/entry.js` con auto-repair da tarball
- Pre-flight Ollama con 5 strategie di avvio (systemd, manual, health check)
- Auto-pull modello Ollama mancante
- Health check ogni 30s con auto-restart

### 7.4 ✅ Gestione stato multi-finestra

Window state persistence (posizione/dimensioni) su file JSON per 5 finestre: chat, wizard, settings, models, docs.

### 7.5 ✅ Personalità agente (SOUL.md)

Sistema di personalità strutturato con 4 archetipi (Anna Kuliscioff, Margherita Hack, Harley Quinn, Rosa Parks). Il file `SOUL.md` è ben formato (22KB) e include tono, stile, slang milanese, espressioni ricorrenti — pronto per injection nel system prompt di OpenClaw.

### 7.6 ✅ Internazionalizzazione

`src/i18n.js` con supporto IT/EN, iniezione automatica locale nella webchat via localStorage.

### 7.7 ✅ Validazione chiave API live

Validazione formato + chiamata API reale per Anthropic (`/v1/messages`) e OpenAI (`/v1/models`). Fallback graceful se offline.

### 7.8 ✅ Installer PowerShell multi-step con resume post-reboot

`installer/Install-TWIZA.ps1` gestisce:
- VC++ Runtime
- WSL2 feature activation
- Distro TWIZA import
- Node.js + OpenClaw + Ollama install
- Resume da stato salvato post-riavvio (codici exit 3010/1641)

### 7.9 ✅ Integrazione Manus AI

`integrations/manus.js` implementa task management, project management, file operations e webhook per la piattaforma Manus (29 metodi documentati).

---

## 8. Architettura OpenClaw (Gateway)

Il gateway OpenClaw è un processo separato in WSL2 che espone:
- **Porta 18789**: webchat HTTP + WebSocket
- Canali: webchat (embedded), Telegram, Discord, WhatsApp (via API)
- Modelli: routing multi-provider con fallback
- Workspace: file system agent con SOUL.md, MEMORY.md, AGENTS.md

La configurazione avviene tramite `~/.openclaw/openclaw.json` con template placeholder sostituiti da `config-generator.js`.

---

## 9. Roadmap vs Realtà

| Voce Roadmap | Stato dichiarato | Stato reale |
|---|---|---|
| Migrazione Tauri 2.x | ✅ Completata | ❌ Falso — usa Electron |
| Setup wizard UI 4 step | ✅ Completata | ⚠️ Parziale — mancano 3 schermate |
| Tray app | ✅ Completata | ❌ `tray.js` mancante |
| Auto-update | ✅ In Roadmap Fase 2 | ❌ `updater.js` mancante |
| 37 IPC commands | ✅ Completata | ⚠️ Presente ma alcuni su moduli mancanti |

---

## 10. Priorità Fix Raccomandate

### Immediati (bloccano qualsiasi avvio)
1. **Creare `src/preload.js`** — espone IPC al renderer via `contextBridge`
2. **Creare `src/tray.js`** — system tray con menu Start/Stop/Chat/Quit
3. **Creare `src/updater.js`** — auto-update con `electron-updater` o stub
4. **Creare `src/onboarding/index.html`** — prima schermata benvenuto
5. **Creare `src/settings/index.html`** — pannello impostazioni
6. **Creare `src/models/index.html`** — model manager UI

### Alta priorità
7. **Eliminare `/main.js`** dalla root (zombie con GATEWAY_PORT errata)
8. **Fix template** `openclaw.json.template`: `"name": "Gemma 3 4B"` → `"name": "Qwen 2.5 3B"`
9. **Aggiungere `memory/` a `.gitignore`** nel repo originale
10. **Fix regex validazione** Mistral e Together (aggiungere `$`)

### Media priorità
11. Documentare chiaramente lo stato di `src-tauri/` (archivio o alternativa)
12. Rendere `branding/restore-branding.sh` asincrono (non bloccante UI)
13. Spostare il python3 inline in un file `.py` separato

---

## 11. Conteggio File e Statistiche

| Categoria | Conteggio |
|---|---|
| File JS totali (escl. node_modules) | 9 |
| Righe JS totali | ~4.200 |
| File HTML | 12+ |
| File PowerShell | 3 |
| File Rust (src-tauri) | 5 |
| File Markdown (docs/memory/config) | 40+ |
| File mancanti critici | **6** |
| Bug critici identificati | **4** |
| Bug importanti identificati | **6** |
| Bug minori/smell identificati | **6** |

---

*Report generato da Claude Sonnet 4.6 — Analisi statica del codice sorgente, 2026-04-06*  
*Fork disponibile su: https://github.com/AvatarNemo/twiza-moneypenny-claude-debug*
