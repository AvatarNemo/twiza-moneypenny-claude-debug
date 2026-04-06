# TWIZA Moneypenny — Roadmap

## Fase 1: MVP — "Funziona sul mio PC" ✅ COMPLETATA

Obiettivo: installer funzionante che installa tutto e apre la webchat.

### Risultati
1. ✅ **Migrazione a Tauri 2.x** — da Electron a Rust backend con 37 IPC commands
2. ✅ **Script bootstrap WSL** — PowerShell che installa WSL2, Ubuntu, Node.js, OpenClaw, Ollama
3. ✅ **Setup wizard UI** — 4 step: Welcome, API Key, Identity, Install
4. ✅ **Tray app** — icona system tray con Start/Stop gateway, webchat, status
5. ✅ **Config generator** — genera `openclaw.json` dal wizard
6. ✅ **Installer NSIS** — impacchettato via `cargo tauri build`
7. ✅ **29 moduli integrazione** — messaging, social, email, dev, AI, storage, office
8. ✅ **37 IPC commands** — auth testing, gateway control, OAuth2 flow, GPU detection

### Definition of Done ✅
Un utente scarica il .exe, lo installa, inserisce una API key Anthropic,
e in 10 minuti sta chattando con il suo AI agent.

---

## Fase 2: Polish & Extended Integrations — 🚧 IN PROGRESS

Obiettivo: completare le integrazioni rimanenti, migliorare UX, stabilità.

### Task
- [x] **Windows build pipeline** — NSIS + MSI via `cargo tauri build`, docs/BUILD.md
- [x] **Complete IPC bridge** — all integration test commands (44 total) with Tauri bridge
- [ ] Webchat embedded nel Tauri webview
- [ ] Sistema auto-update via Tauri updater
- [ ] Miglioramenti UI settings panel
- [ ] Test su Windows 10 e 11 (multiple configs)
- [ ] Documentazione utente completa

---

## Fase 3: Public Release — 📋 PLANNED

Obiettivo: release pubblica, onboarding fluido, community.

### Task
- [ ] Landing page twiza.dev
- [ ] Video tutorial di setup
- [ ] Template gallery ampliata
- [ ] Telemetria opt-in (crash reports)
- [ ] Code signing certificato
- [ ] Microsoft Store submission
- [ ] Community Discord/forum
