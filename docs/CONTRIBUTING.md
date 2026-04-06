# Contributing to TWIZA Moneypenny

Thanks for your interest in contributing to TWIZA Moneypenny! This guide covers everything you need to get a development environment running, understand the codebase, and submit great pull requests.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [Development Workflow](#development-workflow)
- [Building Installers](#building-installers)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Key Subsystems](#key-subsystems)

---

## Prerequisites

### Required

| Tool | Version | Purpose |
|------|---------|---------|
| **Rust** | Stable toolchain | Tauri backend (compile to native) |
| **Cargo** | Latest | Rust package manager |
| **Tauri CLI** | 2.x | `cargo install tauri-cli` |
| **Node.js** | 22+ | Frontend tooling (optional) |
| **Git** | 2.30+ | Version control |
| **Windows 10/11** | v2004+ | Host OS |
| **WSL2** | Latest | Linux backend runtime |
| **Ubuntu (WSL)** | 22.04+ | Distro inside WSL |

### Recommended

| Tool | Purpose |
|------|---------|
| **VS Code** | Editor with great Rust/Tauri/WSL support |
| **rust-analyzer** | VS Code extension for Rust |
| **NVIDIA GPU + drivers** | Testing local model features |
| **Ollama** | Testing model management UI |
| **An AI API key** | End-to-end testing (Anthropic/OpenAI/Gemini) |

### Setting Up WSL2

If you don't already have WSL2:

```powershell
# Run in an elevated PowerShell
wsl --install -d Ubuntu
```

Restart if prompted, then set up a user inside Ubuntu. TWIZA expects a `twiza` user, but for development any user works.

### Installing Rust & Tauri CLI

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Tauri CLI
cargo install tauri-cli
```

---

## Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/AvatarNemo/twiza-moneypenny.git
cd twiza-moneypenny

# 2. Run in development mode
cargo tauri dev
```

`cargo tauri dev` compiles the Rust backend and opens the app with DevTools enabled.

### First Run

On first launch, TWIZA opens the Setup Wizard. For development, you can either:

- **Complete the wizard** with a real API key to test the full flow
- **Skip the wizard** by manually creating a settings file:

```bash
# Create the settings file to skip the wizard
mkdir -p "$APPDATA/twiza-moneypenny"
echo '{"firstRunComplete": true, "autoStartGateway": false}' > "$APPDATA/twiza-moneypenny/twiza-settings.json"
```

---

## Project Structure

```
twiza-moneypenny/
├── src-tauri/                      # Tauri/Rust backend
│   ├── src/
│   │   ├── main.rs                 # App lifecycle, 37 IPC commands, window management
│   │   ├── gateway.rs              # OpenClaw gateway process management via WSL
│   │   ├── oauth.rs                # OAuth2 flow handling for integrations
│   │   ├── state.rs                # Application state management
│   │   └── wsl.rs                  # WSL2 command execution and detection
│   ├── icons/                      # App icons (all sizes + tray icon)
│   ├── tauri.conf.json             # Tauri configuration (windows, permissions, bundler)
│   ├── Cargo.toml                  # Rust dependencies
│   └── build.rs                    # Build script
│
├── src/                            # Frontend (HTML/JS, served by Tauri webview)
│   ├── tauri-bridge.js             # IPC bridge — wraps Tauri invoke() calls
│   ├── wizard/
│   │   └── index.html              # 4-step setup wizard (single-page app)
│   ├── settings/
│   │   └── index.html              # Settings panel UI
│   ├── onboarding/
│   │   └── index.html              # First-run experience / welcome screen
│   ├── templates/
│   │   └── gallery.html            # Personality template browser
│   ├── models/
│   │   ├── config.js               # Model provider definitions
│   │   ├── ollama-manager.js       # Ollama control: pull, delete, status, GPU detection
│   │   └── index.html              # Local models management UI
│   ├── integrations/               # 29 integration modules
│   │   ├── manager.js              # Integration lifecycle manager
│   │   ├── whatsapp.js             # WhatsApp via Baileys
│   │   ├── telegram.js             # Telegram Bot API
│   │   ├── discord.js              # Discord bot
│   │   ├── twitter.js              # Twitter/X integration
│   │   ├── mastodon.js             # Mastodon integration
│   │   ├── bluesky.js              # Bluesky integration
│   │   ├── tiktok.js               # TikTok (browser automation)
│   │   ├── github.js               # GitHub integration
│   │   ├── gmail.js                # Gmail OAuth2
│   │   ├── imap-accounts.js        # IMAP multi-account
│   │   ├── google-calendar.js      # Google Calendar
│   │   ├── google-drive.js         # Google Drive
│   │   ├── onedrive.js             # OneDrive/Microsoft
│   │   ├── dropbox.js              # Dropbox
│   │   ├── spotify.js              # Spotify
│   │   ├── linkedin.js             # LinkedIn
│   │   ├── perplexity.js           # Perplexity AI
│   │   ├── groq.js                 # Groq
│   │   ├── gemini.js               # Google Gemini
│   │   ├── voice.js                # ElevenLabs TTS
│   │   ├── office.js               # Office docs (pptx, docx, xlsx)
│   │   ├── browser-control.js      # Browser automation
│   │   ├── gpu-detection.js        # GPU/VRAM detection
│   │   ├── auto-update.js          # Auto-update system
│   │   └── ...                     # reddit, viber, protonmail, email-legacy
│   └── legacy-electron/            # Deprecated Electron code (kept for reference)
│       ├── main.js
│       ├── preload.js
│       ├── tray.js
│       ├── backup.js
│       └── diagnostics.js
│
├── assets/branding/                # Logos, icons
├── workspace-template/             # Default workspace files (SOUL.md, USER.md, etc.)
├── scripts/                        # Bootstrap & install scripts (PowerShell)
├── docs/                           # Documentation
├── package.json                    # Frontend deps (legacy, being phased out)
├── INTEGRATIONS.md                 # Full integration catalog
├── ROADMAP.md                      # Development phases
├── STYLE-GUIDE.md                  # Brand guidelines
└── LICENSE                         # MIT
```

---

## Architecture Overview

TWIZA Moneypenny has three layers:

```
┌─────────────────────────────────────────────────────────┐
│                    TAURI 2.x (Windows)                  │
│                                                         │
│  main.rs ─── App lifecycle, IPC commands, windows       │
│     │                                                   │
│     ├── gateway.rs    Gateway process management        │
│     ├── oauth.rs      OAuth2 flow handler               │
│     ├── state.rs      App state                         │
│     └── wsl.rs        WSL2 command execution            │
│                                                         │
│  Frontend (Tauri Webview — plain HTML/JS):              │
│     ├── wizard/       Setup wizard (renderer)           │
│     ├── settings/     Settings panel (renderer)         │
│     ├── models/       Ollama management (renderer)      │
│                                                         │
│  tauri-bridge.js ─── IPC bridge (invoke() calls)        │
│                                                         │
├────────────── wsl.exe / Command::new() ─────────────────┤
│                                                         │
│                    WSL2 (Ubuntu)                         │
│                                                         │
│  OpenClaw Gateway ─── AI gateway daemon                 │
│     │                                                   │
│     ├── Webchat server (:18789)                         │
│     ├── Channel plugins (WhatsApp, Telegram, Discord)   │
│     ├── Agent logic (memory, tools, personality)        │
│     └── Model routing (cloud APIs or local Ollama)      │
│                                                         │
│  Ollama ─── Local model inference server (optional)     │
│     └── nvidia-smi / CUDA (GPU acceleration)            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

**Tauri ↔ WSL2 communication** happens via Rust's `std::process::Command` to spawn `wsl.exe` processes. The `wsl.rs` module provides helpers for running commands inside WSL.

**The gateway runs as a child process** of the Tauri app. This means:
- When TWIZA quits, the gateway is stopped cleanly
- Gateway stdout/stderr is captured for logging
- Status detection happens by watching stdout for "listening"/"ready" keywords

**Frontend ↔ Backend** communication uses Tauri's IPC system. The frontend calls `window.__TAURI__.invoke('command_name', { args })` through the `tauri-bridge.js` wrapper. All 37 IPC commands are defined as `#[tauri::command]` functions in `main.rs`.

**Ollama management** works through the Tauri IPC bridge — frontend calls `detect_gpu` and other commands that execute via WSL.

### IPC Commands (37 total)

| Category | Commands |
|----------|----------|
| **Setup** | `validate_key`, `complete_setup` |
| **Gateway** | `start_gateway`, `stop_gateway`, `gateway_status` |
| **UI** | `open_chat`, `open_webchat_browser`, `close_window`, `minimize_window`, `quit_app` |
| **Settings** | `get_settings`, `save_settings` |
| **Diagnostics** | `run_diagnostics`, `detect_gpu` |
| **Auth Testing** | `test_bluesky_auth`, `test_perplexity_key`, `test_linkedin_token`, `test_spotify_token`, `test_dropbox_token`, `test_microsoft_token`, `test_google_drive_token`, `test_groq_key`, `test_gemini_key`, `test_discord_token`, `test_telegram_token`, `test_mastodon_token`, `test_elevenlabs_key`, `test_github_token`, `test_reddit_auth` |
| **Email** | `test_imap_connection`, `test_gmail_token`, `test_gcal_token`, `send_imap_email`, `check_imap_inbox` |
| **TikTok** | `test_tiktok_cookies`, `upload_tiktok_video` |
| **OAuth** | `oauth2_flow` |

### Data Flow: User Message → Response

```
User types in Webchat (browser, :18789)
       │
       ▼
OpenClaw Gateway (WSL2)
       │
       ├── Loads agent context (SOUL.md, MEMORY.md, etc.)
       ├── Selects model (cloud API or Ollama)
       ├── Calls AI provider
       │       │
       │       ├── Cloud: HTTPS to Anthropic/OpenAI/Gemini
       │       └── Local: HTTP to Ollama (:11434)
       │
       ▼
Response streamed back to Webchat
```

---

## Development Workflow

### Running in Dev Mode

```bash
cargo tauri dev
```

This compiles the Rust backend and opens the app with:
- DevTools accessible via right-click → Inspect
- Verbose logging to console
- Hot-reload for frontend changes (HTML/CSS/JS)

### Hot Reload

For **frontend changes** (HTML/CSS/JS in wizard, settings, models):
- Changes are picked up automatically by the Tauri webview
- Press `Ctrl+R` in the window to force reload if needed

For **Rust backend changes** (main.rs, gateway.rs, etc.):
1. Stop the dev process (`Ctrl+C`)
2. Run `cargo tauri dev` again (recompiles)

### Debugging

**Rust backend:** Use VS Code with rust-analyzer. Add breakpoints and use the integrated debugger.

**Frontend:** Use the built-in WebView DevTools (right-click → Inspect in any TWIZA window).

**WSL commands:** Test them directly in a WSL terminal:

```bash
wsl -d Ubuntu -u twiza -- bash -lc 'openclaw gateway status'
```

---

## Building Installers

### NSIS Installer (default)

```bash
cargo tauri build
```

This produces the installer at:
```
src-tauri/target/release/bundle/nsis/TWIZA Moneypenny_x.x.x_x64-setup.exe
```

### Build Output

```
src-tauri/target/release/
├── twiza-moneypenny.exe                                    # Raw executable
└── bundle/
    └── nsis/
        └── TWIZA Moneypenny_0.1.0_x64-setup.exe            # NSIS installer
```

### Build Configuration

Build settings are in `src-tauri/tauri.conf.json` under the `bundle` key. Notable options:

- **NSIS** bundler for Windows installer
- **File associations** — `.soul` and `.twiza` files open with TWIZA Moneypenny
- **Icons** — all sizes in `src-tauri/icons/`

---

## Code Style

### Rust (Backend)

- Follow standard Rust conventions (`rustfmt`, `clippy`)
- Use `#[tauri::command]` for all IPC-exposed functions
- Error handling: return `Result<T, String>` from commands
- Keep modules focused: gateway logic in `gateway.rs`, WSL in `wsl.rs`, etc.

### JavaScript (Frontend)

- **ES6+** JavaScript
- **2-space indentation**
- **Single quotes** for strings
- **Semicolons** always
- **Descriptive variable names**

### UI / HTML

- Inline `<style>` and `<script>` within HTML files (no external CSS/JS bundling)
- CSS custom properties (`:root { --var: value }`) for theming
- Follow the [Style Guide](../STYLE-GUIDE.md) for colors, fonts, and component styling
- Use `tauri-bridge.js` for all backend communication

### Commit Messages

Follow conventional-ish commits:

```
feat: add Telegram channel integration
fix: gateway not detecting startup on slow systems
docs: update user guide with backup section
style: align wizard step indicators
refactor: extract WSL command helpers to shared module
```

Keep commits focused — one logical change per commit.

---

## Testing

### Manual Testing Checklist

Before submitting a PR, verify on **Windows 10** or **Windows 11**:

- [ ] Fresh install wizard completes successfully
- [ ] Gateway starts and webchat is accessible
- [ ] Tray icon reflects correct status
- [ ] Settings panel opens and saves changes
- [ ] At least one channel works (webchat at minimum)
- [ ] App stays running in tray when all windows are closed
- [ ] Second instance detection works

### Testing WSL Commands

Most features depend on WSL. Test edge cases:

- What happens if WSL is not installed?
- What if the Ubuntu distro doesn't exist?
- What if Ollama isn't installed (optional feature)?
- What if the network is down?

### Testing the Installer

Build and test the full installer on a clean Windows VM if possible:

```bash
cargo tauri build
# Then run the generated NSIS installer on a fresh system
```

---

## Pull Request Process

### 1. Fork & Branch

```bash
git clone https://github.com/AvatarNemo/twiza-moneypenny.git
git checkout -b feature/my-amazing-feature
```

Branch naming:
- `feature/description` — new features
- `fix/description` — bug fixes
- `docs/description` — documentation only
- `refactor/description` — code restructuring

### 2. Develop

- Follow the [Code Style](#code-style) guidelines
- Update documentation for user-facing changes
- Add yourself to contributors if this is your first PR

### 3. Test

Run through the [manual testing checklist](#manual-testing-checklist) for any UI or behavior changes.

### 4. Submit

```bash
git push origin feature/my-amazing-feature
```

Open a PR on GitHub with:

- **Clear title** describing what changed
- **Description** explaining why and how
- **Screenshots** for UI changes
- **Testing notes** — what you verified

---

## Key Subsystems

### Gateway Process Management (`gateway.rs`)

The Tauri backend manages the OpenClaw gateway as a child process via WSL:

```rust
Command::new("wsl")
    .args(["-d", "Ubuntu", "-u", "twiza", "--",
           "bash", "-lc", "cd ~/.openclaw/workspace && openclaw gateway start --foreground"])
    .spawn()
```

Key behaviors:
- Detects readiness by watching stdout for keywords ("listening", "ready", "started")
- Graceful shutdown: sends `openclaw gateway stop`, then kills after timeout
- Status is tracked via shared `AppState`

### IPC Bridge (`tauri-bridge.js`)

The frontend uses a thin JS wrapper around Tauri's `invoke()`:

```javascript
// Frontend calls
const status = await window.__TAURI__.invoke('gateway_status');
const result = await window.__TAURI__.invoke('test_bluesky_auth', { handle, password });
```

### Ollama Manager (`models/ollama-manager.js`)

Manages local AI models with features:
- **GPU detection** via `detect_gpu` IPC command (runs `nvidia-smi` through WSL)
- **VRAM tier classification** (24GB+, 16GB, 8GB, CPU-only)
- **Model catalog** with curated recommendations
- **Pull/delete/list** models through Ollama CLI in WSL

### Bootstrap Script (`scripts/bootstrap-wsl.ps1`)

PowerShell script that runs during installation:

1. Checks admin privileges
2. Enables WSL2 (may require restart)
3. Installs Ubuntu distro
4. Creates the `twiza` user
5. Installs Node.js (via nvm), OpenClaw, and Ollama inside WSL
6. Copies workspace templates
7. Writes `openclaw.json`

Emits `PROGRESS:<percent>:<message>` lines that the Tauri UI parses for the progress bar.

---

## Questions?

- Open a [Discussion](https://github.com/AvatarNemo/twiza-moneypenny/discussions) for questions
- Open an [Issue](https://github.com/AvatarNemo/twiza-moneypenny/issues) for bugs
- Check the [Roadmap](../ROADMAP.md) to see what's planned

---

*Built with ❤️ by [SHAKAZAMBA](https://shakazamba.com)*
