# TWIZA Moneypenny — User Guide

> ...more than an agent!

---

## Table of Contents

- [What is TWIZA Moneypenny?](#what-is-twiza-moneypenny)
- [System Requirements](#system-requirements)
- [Download & Installation](#download--installation)
- [The Setup Wizard](#the-setup-wizard)
- [Your First Chat](#your-first-chat)
- [Connecting Channels](#connecting-channels)
  - [WhatsApp](#whatsapp)
  - [Telegram](#telegram)
  - [Discord](#discord)
- [Settings](#settings)
- [Local Models with Ollama](#local-models-with-ollama)
- [Backup & Restore](#backup--restore)
- [Diagnostics & Troubleshooting](#diagnostics--troubleshooting)
- [FAQ](#faq)

---

## What is TWIZA Moneypenny?

TWIZA Moneypenny is a **Windows desktop application** that gives you a fully-featured personal AI assistant running on your own machine. It combines:

- **Cloud AI models** (Claude, GPT-4, Gemini, and more) or **local models** via Ollama
- **Multi-channel messaging** — talk to your agent via WhatsApp, Telegram, Discord, or a built-in webchat
- **Persistent memory** — your agent remembers context across conversations
- **A customizable personality** — define your agent's voice, style, and name
- **Privacy-first design** — everything runs locally inside WSL2; API keys never leave your machine

Under the hood, TWIZA Moneypenny is a [Tauri 2.x](https://v2.tauri.app/) desktop app (Rust backend + HTML/JS frontend) that manages an [OpenClaw](https://openclaw.dev) AI gateway running inside Windows Subsystem for Linux (WSL2).

```
┌──────────────────────────────────────────┐
│          Your Windows Desktop            │
│                                          │
│   ┌──────────┐   ┌───────────────────┐   │
│   │  System   │   │   Webchat UI      │   │
│   │  Tray     │   │   (browser)       │   │
│   │  Icon     │   │                   │   │
│   └────┬─────┘   └────────┬──────────┘   │
│        │                   │              │
│        └─────────┬─────────┘              │
│           Tauri IPC (Rust)                │
│                  ▼                        │
│   ┌──────────────────────────────────┐   │
│   │          WSL2 (Ubuntu)           │   │
│   │                                  │   │
│   │   OpenClaw Gateway ──► Channels  │   │
│   │         │             (WhatsApp, │   │
│   │         ▼              Telegram, │   │
│   │   Ollama (optional)    Discord)  │   │
│   │   Local AI models                │   │
│   └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

---

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Windows 10 version 2004+ | Windows 11 |
| **RAM** | 8 GB | 16 GB (32 GB for large local models) |
| **Disk** | 10 GB free | 30 GB+ (with local models) |
| **CPU** | x64 with virtualization enabled | Modern multi-core |
| **GPU** | — | NVIDIA GPU with 8+ GB VRAM (for local models) |
| **Network** | Required for cloud AI providers | — |

### Important Prerequisites

- **Virtualization** must be enabled in your BIOS/UEFI (required for WSL2)
- **Windows features**: WSL2 and Virtual Machine Platform (the installer enables these automatically)
- An **API key** from at least one AI provider (Anthropic, OpenAI, or Google Gemini) — unless you plan to use only local models

---

## Download & Installation

### 1. Download

Go to [**Releases**](https://github.com/AvatarNemo/twiza-moneypenny/releases) and download the latest `TWIZA Moneypenny_x.x.x_x64-setup.exe`.

### 2. Run the Installer

Double-click the downloaded `.exe` file. Windows may show a SmartScreen warning since the app is new — click **"More info" → "Run anyway"**.

The NSIS installer will:

1. Ask where to install (default is fine)
2. Create a desktop shortcut and Start Menu entry
3. Launch TWIZA Moneypenny when finished

> **Note:** The installer requests Administrator privileges because it needs to set up WSL2 and create a Linux user account.

### 3. Complete the Setup Wizard

On first launch, TWIZA opens the **Setup Wizard** — a 4-step guided setup. See the next section for details.

---

## The Setup Wizard

The Setup Wizard runs automatically the first time you open TWIZA Moneypenny. It walks you through four steps:

### Step 1 — Welcome

A quick introduction to TWIZA's features. Just click **"Get Started"** to continue.

### Step 2 — AI Provider

Choose which AI service will power your agent:

| Provider | Model | Notes |
|----------|-------|-------|
| **Anthropic** | Claude Sonnet 4 | Best overall quality |
| **OpenAI** | GPT-4o | Most popular, includes image generation |
| **Google Gemini** | Gemini 2.5 Flash | Free tier available! |

After selecting a provider, paste your **API key** into the field and click **"Validate"**. The wizard checks the key format before continuing.

> **Where do I get an API key?**
> - Anthropic: [console.anthropic.com](https://console.anthropic.com/) → API Keys
> - OpenAI: [platform.openai.com](https://platform.openai.com/) → API Keys
> - Google: [aistudio.google.com](https://aistudio.google.com/) → Get API Key

### Step 3 — Identity

Customize your agent:

- **Name** — Give it a name (e.g., Jarvis, Friday, Atlas)
- **Emoji** — Pick an icon from the grid (🤖, 🧠, ⚡, 🔮, etc.)
- **Profile picture** — Optionally upload an avatar image
- **Personality** — Choose a template:
  - ⚖️ **Balanced** — Friendly, helpful, concise (recommended)
  - 💼 **Professional** — Formal, precise, structured
  - 🎨 **Creative** — Playful, expressive, imaginative
  - ✏️ **Custom** — Write your own personality from scratch

### Step 4 — Install

Review your choices in the summary, then click **"🚀 Install TWIZA Moneypenny"**. The installer will:

1. Enable WSL2 (if not already enabled)
2. Install Ubuntu inside WSL2
3. Install Node.js, OpenClaw, and Ollama inside WSL
4. Copy workspace templates and write your configuration
5. Start the OpenClaw gateway

You'll see a progress bar and a live log. The process takes **2–10 minutes** depending on your internet speed and whether WSL2 is already installed.

> **⚠️ Restart required?** If WSL2 wasn't previously enabled, Windows may need a restart. The installer will tell you — just restart and run TWIZA Moneypenny again to continue.

When installation completes, click **"Done — Open Chat"** to start talking to your agent!

---

## Your First Chat

After setup, you can chat with your agent in three ways:

### Built-in Webchat (easiest)

- **Double-click** the TWIZA tray icon (bottom-right of your taskbar) to open the embedded chat window
- Or open your browser and go to **`http://localhost:18789`**

### System Tray

TWIZA lives in your system tray. Right-click the icon to:

- Open the webchat window
- Open webchat in your browser
- Open settings
- Start/stop the gateway
- Quit the application

### Tray Icon Status

| Icon State | Meaning |
|------------|---------|
| 🟢 Normal | Gateway is running — your agent is online |
| 🟡 Pulsing | Gateway is starting up |
| 🔴 Dimmed | Gateway is offline or encountered an error |

---

## Connecting Channels

TWIZA supports multiple messaging channels so you can talk to your agent wherever you are. All channels are **optional** — the built-in webchat always works.

### WhatsApp

WhatsApp integration uses the Baileys library and connects via QR code pairing — no WhatsApp Business API needed.

**Setup:**

1. Open **Settings** → **Channels** → **WhatsApp**
2. Enable WhatsApp and click **"Pair Device"**
3. A QR code will appear on screen
4. On your phone: open **WhatsApp** → **Settings** → **Linked Devices** → **Link a Device**
5. Scan the QR code with your phone
6. Done! Send a message to yourself (or from another number) to test

**Notes:**
- The pairing persists across restarts — you only need to scan once
- If the connection drops, TWIZA will attempt to reconnect automatically
- WhatsApp may occasionally require re-pairing (you'll get a notification)

### Telegram

Telegram integration uses the Bot API — you'll create a bot via BotFather.

**Setup:**

1. Open Telegram and message **[@BotFather](https://t.me/BotFather)**
2. Send `/newbot` and follow the prompts to create a bot
3. Copy the **bot token** BotFather gives you (looks like `123456789:ABCdefGHI...`)
4. In TWIZA: open **Settings** → **Channels** → **Telegram**
5. Paste the bot token and enable Telegram
6. Restart the gateway
7. Message your bot on Telegram to test!

**Tips:**
- Use `/setdescription` and `/setuserpic` with BotFather to customize your bot's profile
- Set `/setprivacy` to **disabled** if you want your agent to see all messages in groups

### Discord

Discord integration uses a bot account that joins your server.

**Setup:**

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **"New Application"**, give it a name, and create it
3. Go to **Bot** → Click **"Reset Token"** → Copy the token
4. Under **Privileged Gateway Intents**, enable:
   - ✅ Message Content Intent
   - ✅ Server Members Intent (optional)
5. Go to **OAuth2** → **URL Generator**:
   - Scopes: `bot`
   - Bot Permissions: `Send Messages`, `Read Message History`, `Read Messages/View Channels`
6. Copy the generated URL and open it in your browser to invite the bot to your server
7. In TWIZA: open **Settings** → **Channels** → **Discord**
8. Paste the bot token and your server (guild) ID
9. Restart the gateway

**Finding your Server ID:** Enable Developer Mode in Discord (Settings → Advanced → Developer Mode), then right-click your server name → **"Copy Server ID"**.

---

## Settings

Open Settings from the system tray right-click menu, or from the webchat interface.

### Available Settings

| Setting | Description |
|---------|-------------|
| **Auto-start Gateway** | Start the OpenClaw gateway automatically when TWIZA launches |
| **AI Provider** | Change your AI provider or API key |
| **Default Model** | Choose which model to use (e.g., Claude Sonnet, GPT-4o) |
| **Agent Name & Emoji** | Update your agent's identity |
| **Personality** | Edit SOUL.md to change your agent's behavior |
| **Channels** | Enable/disable and configure WhatsApp, Telegram, Discord |
| **Ollama / Local Models** | Manage locally downloaded AI models |
| **Backup** | Configure automatic backups |
| **Diagnostics** | Run system checks, view logs, self-heal |

### Workspace Files

Your agent's personality and memory are stored as plain markdown files in the WSL workspace (`/home/twiza/.openclaw/workspace/`). You can edit these directly:

| File | Purpose |
|------|---------|
| `SOUL.md` | Your agent's personality and behavioral instructions |
| `USER.md` | Information about you (helps the agent personalize responses) |
| `IDENTITY.md` | Agent name and emoji |
| `MEMORY.md` | Long-term curated memory |
| `AGENTS.md` | Agent workspace conventions |
| `TOOLS.md` | Local tool configuration notes |
| `HEARTBEAT.md` | Periodic task checklist |
| `memory/*.md` | Daily session logs |

---

## Local Models with Ollama

TWIZA includes [Ollama](https://ollama.com) for running AI models entirely on your machine — no internet, no API costs, complete privacy.

### How It Works

Ollama runs inside WSL2 alongside OpenClaw. When you download a model, it's stored locally and served via Ollama's inference engine. If you have an NVIDIA GPU, models run on your GPU for fast responses.

### Managing Models

Open **Settings** → **Local Models** to see:

- **Installed models** — models already downloaded
- **Recommended models** — suggestions based on your GPU's VRAM
- **GPU info** — detected GPU, VRAM total/used/free

### Recommended Models by GPU

| GPU VRAM | Recommended Model | Size | Best For |
|----------|-------------------|------|----------|
| **24 GB+** | Qwen 3 32B | 20 GB | Best overall local experience |
| **24 GB+** | Mistral Small 24B | 14 GB | European, multilingual |
| **16 GB** | Qwen 3 14B | 9.3 GB | Sweet spot quality vs. speed |
| **16 GB** | DeepSeek R1 14B | 9 GB | Reasoning, math, code |
| **8 GB** | Qwen 3 8B | 5.2 GB | Compact, surprisingly capable |
| **8 GB** | Gemma 3 9B | 6 GB | Creative writing, concise |
| **No GPU** | Phi-4 3.8B | 2.5 GB | Reasoning on CPU |
| **No GPU** | Qwen 2.5 1.5B | 1 GB | Ultra-lightweight, basic tasks |

### Downloading a Model

1. Open **Settings** → **Local Models**
2. Browse recommended models or enter a model name
3. Click **"Download"** — you'll see a progress bar as the model downloads
4. Once downloaded, set it as your default model or use it as a fallback

### Using Local Models as Default

In your `openclaw.json` configuration, set:

```json
{
  "models": {
    "default": "ollama/qwen3:14b"
  }
}
```

This makes your agent fully offline — no cloud API needed.

### Hybrid Mode

You can use cloud models as your primary and a local model as fallback, or vice versa. This gives you the best of both worlds.

---

## Backup & Restore

TWIZA can back up your agent's workspace — including memory files, personality, and configuration.

### What Gets Backed Up

- `memory/` — all daily session logs
- `SOUL.md`, `USER.md`, `IDENTITY.md`, `MEMORY.md` — personality and memory
- `AGENTS.md`, `TOOLS.md`, `HEARTBEAT.md` — workspace configuration
- `openclaw.json` — gateway configuration

### What Is Excluded

- API keys and credentials (`.key`, `.pem`, `.env` files)
- `node_modules/`, `.git/`

### Creating a Manual Backup

1. Open **Settings** → **Backup**
2. Click **"Create Backup Now"**
3. Choose a location (default: `%APPDATA%/twiza-moneypenny/backups/`)
4. A `.tar.gz` archive is created with a timestamped filename

### Automatic Backups

Enable scheduled backups in Settings:

- **Daily** — backs up every 24 hours
- **Weekly** — backs up every 7 days

TWIZA automatically prunes old backups, keeping the 10 most recent.

### Restoring from Backup

1. Open **Settings** → **Backup** → **"Restore"**
2. Select a `.tar.gz` backup file
3. Confirm — files will be extracted into the workspace (existing files are overwritten)
4. Restart the gateway to apply changes

### Pre-Update Backups

TWIZA automatically creates a backup before applying updates, so you can always roll back.

---

## Diagnostics & Troubleshooting

### Built-in Diagnostics

Open **Settings** → **Diagnostics** to run a full system check. TWIZA checks:

| Check | What It Tests |
|-------|---------------|
| **WSL2** | Is WSL2 installed and the Ubuntu distro available? |
| **Node.js** | Is Node.js installed inside WSL? |
| **OpenClaw** | Is the OpenClaw CLI installed? |
| **Ollama** | Is Ollama installed? (optional) |
| **GPU** | Is an NVIDIA GPU detected with CUDA? (optional) |
| **Gateway** | Is the OpenClaw gateway process running and responding? |
| **Webchat** | Is the webchat port (18789) responding? |
| **Disk Space** | How much space is available? |
| **Network** | Can you reach GitHub, Anthropic, and OpenAI APIs? |

Results are shown as ✅ pass, ⚠️ warning, or ❌ fail. You can copy the full diagnostics text for support.

### Self-Heal

Click **"Self-Heal"** in diagnostics to automatically:

1. Detect if the gateway is down
2. Attempt to restart it
3. Report the result

### Common Issues

#### Gateway won't start

**Symptoms:** Tray icon stays red/offline, webchat doesn't load.

**Fixes:**
1. Run **Diagnostics** to identify the failing component
2. Try **Self-Heal** (Settings → Diagnostics)
3. Manually restart: right-click tray → **Stop Gateway**, then **Start Gateway**
4. Check if WSL is running: open PowerShell and type `wsl --status`
5. If WSL is not running: `wsl --shutdown` then restart TWIZA

#### "Restart Required" during installation

WSL2 requires Windows features that need a reboot. Restart your PC and open TWIZA Moneypenny again — it will pick up where it left off.

#### WhatsApp disconnects frequently

- Make sure your phone has a stable internet connection
- Keep TWIZA running (don't close it)
- If the connection breaks, go to Settings → Channels → WhatsApp and re-pair

#### Slow responses with local models

- Check GPU utilization in the Models panel
- Use a smaller model if your GPU has limited VRAM
- CPU-only inference is significantly slower — consider a cloud provider for complex tasks

#### Port already in use

If something else is using port 18789 (webchat):

```powershell
# Find what's using the port (in PowerShell)
netstat -ano | findstr :18789
```

Stop the conflicting process or change the port in `openclaw.json`.

### Viewing Logs

In **Settings** → **Diagnostics** → **"View Logs"**, you can see the last 100 lines of gateway logs. These are helpful for diagnosing issues.

You can also view logs directly in WSL:

```bash
wsl -d Ubuntu -u twiza -- tail -100 ~/.openclaw/logs/gateway.log
```

---

## FAQ

### Is TWIZA Moneypenny free?

TWIZA Moneypenny itself is free and open-source (MIT license). You'll need API keys from your chosen AI provider, which have their own pricing. Google Gemini and Groq offer free tiers. Using local models via Ollama is completely free.

### Does TWIZA send my data to the cloud?

Only your messages to the AI model are sent to the provider you chose (Anthropic, OpenAI, etc.) — exactly like using their web interfaces. Your workspace files, memory, and conversation history stay on your machine. If you use local models via Ollama, nothing leaves your computer at all.

### Can I use multiple AI providers?

Yes. You can configure additional providers in your `openclaw.json` and switch between them. You can also set a cloud provider as primary and a local model as fallback.

### Can I run TWIZA without an internet connection?

Yes — if you have a local model downloaded via Ollama. The agent will work fully offline using that model. Cloud providers obviously require internet.

### Does TWIZA work on Mac or Linux?

Not currently. TWIZA Moneypenny is designed for Windows with WSL2. The underlying OpenClaw gateway runs on any Linux system, so technically the backend works everywhere — but the desktop app and installer are Windows-only.

### Can I change my AI provider later?

Absolutely. Open Settings, update the provider/API key, and restart the gateway.

### How do I update TWIZA?

TWIZA checks for updates automatically and notifies you when a new version is available. You can also check manually at the [Releases page](https://github.com/AvatarNemo/twiza-moneypenny/releases). A backup is created automatically before each update.

### How much disk space do local models need?

It depends on the model. The smallest (Qwen 2.5 1.5B) needs about 1 GB. The largest recommended model (Qwen 3 32B) needs about 20 GB. You can download and delete models at any time.

### Can I edit my agent's personality?

Yes! Your agent's personality is defined in `SOUL.md`, a plain markdown file. You can edit it through the Settings panel or directly in the WSL filesystem at `/home/twiza/.openclaw/workspace/SOUL.md`.

### Where is my data stored?

| Data | Location |
|------|----------|
| Windows app settings | `%APPDATA%/twiza-moneypenny/` |
| Backups | `%APPDATA%/twiza-moneypenny/backups/` |
| Agent workspace | `\\wsl$\Ubuntu\home\twiza\.openclaw\workspace\` |
| Ollama models | `\\wsl$\Ubuntu\usr\share\ollama\.ollama\models\` |

### How do I completely uninstall TWIZA?

1. Uninstall via Windows Settings → Apps → TWIZA Moneypenny
2. Optionally remove the WSL data: `wsl --unregister Ubuntu` (⚠️ this deletes the entire Ubuntu distro)
3. Delete `%APPDATA%/twiza-moneypenny/` for app settings and backups

---

## Getting Help

- **GitHub Issues:** [github.com/AvatarNemo/twiza-moneypenny/issues](https://github.com/AvatarNemo/twiza-moneypenny/issues)
- **Discussions:** [github.com/AvatarNemo/twiza-moneypenny/discussions](https://github.com/AvatarNemo/twiza-moneypenny/discussions)
- **Diagnostics:** Always include the diagnostics output when reporting bugs (Settings → Diagnostics → Copy)

---

*Built with ❤️ by [SHAKAZAMBA](https://shakazamba.com)*
