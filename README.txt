╔══════════════════════════════════════════════════════════╗
║                                                          ║
║           TWIZA MONEYPENNY - Installer v7.0              ║
║          Il tuo agente AI personale per Windows           ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

ISTRUZIONI:

1. Fai doppio click su "INSTALLA-TWIZA.bat"
2. Clicca "Si" quando chiede i permessi amministratore
3. Attendi il completamento (5-15 minuti)
4. Fatto!

COSA INSTALLA:
- WSL2 con Ubuntu 24.04 (ambiente Linux)
- Node.js 22 LTS
- OpenClaw (gateway AI)
- Ollama (motore AI locale)
- Modello base qwen2.5:1.5b
- TWIZA Moneypenny (l'app)

REQUISITI:
- Windows 10 v2004+ o Windows 11
- 8 GB RAM minimo (16 GB consigliati)
- ~3 GB di spazio su disco
- Connessione internet (per Ubuntu e modello AI)

DOPO L'INSTALLAZIONE:
- Icona "TWIZA Moneypenny" sul Desktop
- Avvia e segui il wizard di configurazione
- Servira' almeno una API key (Anthropic, OpenAI, etc.)
- Ollama gira in locale, modelli aggiuntivi scaricabili

STRUTTURA:
├── INSTALLA-TWIZA.bat        ← Lancia l'installer
├── README.txt                ← Questo file
├── installer/
│   └── Install-TWIZA.ps1    ← Script principale
├── components/               ← Componenti offline
│   ├── vc_redist.x64.exe
│   ├── node-v22.x-linux-x64.tar.xz  (opzionale)
│   ├── openclaw-bundle/      (opzionale, altrimenti npm)
│   └── ubuntu-24.04-rootfs.tar  (opzionale)
├── templates/                ← Config e workspace vergini
│   ├── openclaw.json.template
│   ├── bootstrap-wsl.sh
│   └── workspace/            ← SOUL.md, media, branding
└── app/                      ← App Electron TWIZA

PROBLEMI?
- Se serve un riavvio (WSL2), riesegui dopo
- Log in install.log
- Contatta support@shakazamba.com

(c) 2026 TWIZA by SHAKAZAMBA
