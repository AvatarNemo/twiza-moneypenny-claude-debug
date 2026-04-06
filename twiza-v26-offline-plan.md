# TWIZA v26 - FULL OFFLINE BUILD PLAN

## 🔥 PROBLEMA v25: WSL2 si inchioda perché cerca internet

## ✅ SOLUZIONE v26: BUNDLE TUTTO OFFLINE

### COMPONENTI DA BUNDLARE:
1. **WSL2 Kernel Linux** 
   - `wsl_update_x64.msi` (Microsoft official)
   - Ubuntu 22.04 `.appx` file
   - Pre-download e bundle nel setup

2. **Node.js**
   - `node-v20.x.x-x64.msi` 
   - Bundle completo, no online install

3. **Ollama Windows**
   - `ollama-windows-amd64.exe`
   - Modelli AI pre-scaricati (almeno gemini/qwen piccoli)

4. **OpenClaw**
   - Binari pre-compilati
   - Dependencies bundled

### INSTALLER STRUCTURE v26:
```
TWIZA Moneypenny_v26_setup.exe
├── install-wizard/ (Tauri frontend)
├── offline-components/
│   ├── wsl_update_x64.msi
│   ├── ubuntu-2204.appx
│   ├── node-v20.15.1-x64.msi  
│   ├── ollama-windows-amd64.exe
│   ├── models/ (gemini-2b, qwen-1.5b)
│   └── openclaw-binaries/
└── install-scripts/ (PowerShell automation)
```

### PROCESSO INSTALL v26:
1. **Check requisiti** (Windows 10+, admin rights)
2. **Install WSL2 OFFLINE** (bundle locale)
3. **Install Node.js OFFLINE** (bundle locale) 
4. **Install Ollama OFFLINE** (bundle locale)
5. **Setup OpenClaw** (binari pre-compilati)
6. **Deploy config** (user settings)

### SIZE ESTIMATE:
- WSL2 components: ~500MB
- Node.js: ~30MB
- Ollama + models: ~2-3GB  
- **Total:** ~4GB setup (acceptable)

## 🎯 NEXT ACTIONS:
1. Download tutti i componenti offline
2. Modificare installer Tauri per bundle management
3. PowerShell scripts per silent installs
4. Test completo su VM pulita

**DIO MERDA SPELACCHIATA!** Questa volta funziona OFFLINE o non funziona per niente!