# TWIZA Moneypenny — Integrations Catalog

*...more than an agent!*

Total: **70+ integrations** across 14 categories.

---

## 🎭 Identity & Personality
| Integration | Config | Difficulty |
|---|---|---|
| Nome agente | `identity.name` | 🟢 Easy |
| Emoji | `identity.emoji` | 🟢 Easy |
| Immagine profilo | Upload/genera | 🟢 Easy |
| Immagine cover | Upload/genera | 🟢 Easy |
| Personalità (SOUL.md) | Template o custom | 🟢 Easy |
| Voce (ElevenLabs TTS) | API key + voice ID | 🟡 Medium |
| Clonazione voce | Upload sample → ElevenLabs | 🟡 Medium |

## 💬 Messaging
| Integration | Auth Method | Difficulty |
|---|---|---|
| WhatsApp | QR code pairing (Baileys) | 🟡 Medium |
| Telegram | Bot token | 🟢 Easy |
| Discord | Bot token + server ID | 🟢 Easy |
| Signal | Phone + signal-cli linking | 🔴 Hard |
| Viber | Bot token | 🟡 Medium ⚠️ pending commercial approval |
| Slack | OAuth app | 🟡 Medium |
| Google Chat | Service account | 🟡 Medium |
| iMessage | Apple ID (macOS only) | 🔴 Hard |

## 📱 Social Media
| Integration | Auth Method | Difficulty |
|---|---|---|
| Twitter/X | OAuth 1.0a | 🟡 Medium |
| Mastodon | OAuth access token | 🟢 Easy |
| LinkedIn | OAuth 2.0 | 🔴 Hard ✅ |
| Reddit | OAuth script app | 🟡 Medium ⚠️ app creation blocked |
| Bluesky | App password | 🟢 Easy ✅ |
| TikTok | Browser automation (cookies) | 🟡 Medium ✅ |

## 📧 Email
| Integration | Auth Method | Difficulty |
|---|---|---|
| IMAP/SMTP generico | User/pass | 🟡 Medium |
| Gmail API (OAuth2) | OAuth 2.0 | 🟡 Medium ✅ |
| IMAP Multi-Account | User/pass | 🟡 Medium ✅ |
| ProtonMail (Bridge) | Bridge credentials | 🟡 Medium ✅ |
| Outlook/365 | OAuth 2.0 (Microsoft Graph) | 🟡 Medium |
| POP3 | User/pass | 🟡 Medium |

## 📅 Calendar
| Integration | Auth Method | Difficulty |
|---|---|---|
| Google Calendar | Service account / OAuth | 🟡 Medium ✅ |
| CalDAV generico | User/pass | 🟡 Medium |

## 💻 Development
| Integration | Auth Method | Difficulty |
|---|---|---|
| GitHub | Personal Access Token | 🟢 Easy |
| GitLab | Personal Access Token | 🟢 Easy |
| Manus.im | API key (header) | 🟢 Easy ✅ |

## 🎨 Design & Creativity
| Integration | Auth Method | Difficulty |
|---|---|---|
| Figma | Personal Access Token | 🟡 Medium |
| Canva | OAuth 2.0 | 🔴 Hard |
| OpenAI Image Gen | API key | 🟢 Easy |
| Gamma (presentations) | API (TBD) | 🔴 Hard |

## 📊 Productivity & Office
| Integration | Method | Difficulty |
|---|---|---|
| PowerPoint | python-pptx (local) | 🟡 Medium ✅ |
| Word | python-docx (local) | 🟡 Medium ✅ |
| Excel | openpyxl (local) | 🟡 Medium ✅ |
| Notion | API key | 🟢 Easy |
| Google Docs/Sheets | OAuth 2.0 | 🟡 Medium |

## 🌐 Browser Control
| Integration | Method | Difficulty |
|---|---|---|
| Chrome | Playwright / DevTools | 🟡 Medium |
| Brave | Playwright (Chromium) | 🟡 Medium |
| Firefox | Playwright | 🟡 Medium |
| Opera | Playwright (Chromium) | 🟡 Medium |
| OpenClaw Browser Relay | Chrome extension | 🟢 Easy |

## 📁 File System & Cloud Storage
| Integration | Auth Method | Difficulty |
|---|---|---|
| File System locale | WSL mount | 🟢 Easy |
| Dropbox | OAuth 2.0 | 🟡 Medium ✅ |
| OneDrive | OAuth 2.0 (Microsoft) | 🟡 Medium ✅ |
| Google Drive | OAuth 2.0 | 🟡 Medium ✅ |

## 🤖 AI Providers (Cloud)
| Integration | Auth Method | Difficulty |
|---|---|---|
| Anthropic (Claude) | API key | 🟢 Easy |
| OpenAI (GPT, DALL-E, Whisper) | API key | 🟢 Easy |
| Google Gemini | API key (free tier!) | 🟢 Easy ✅ |
| Mistral AI | API key | 🟢 Easy |
| Groq | API key (free tier!) | 🟢 Easy ✅ |
| xAI (Grok) | API key | 🟢 Easy |
| Together AI | API key | 🟢 Easy |
| Fireworks AI | API key | 🟢 Easy |
| Perplexity | API key | 🟢 Easy ✅ |

## 🤖 Local AI Models (Ollama)
| Model | Size (Q4_K_M) | Strength |
|---|---|---|
| Qwen 3 32B | 20 GB | Best overall local |
| Qwen 3 14B | 9.3 GB | Fast generalist |
| DeepSeek R1 14B | 9 GB | Reasoning/math/code |
| Mistral Small 24B | 14 GB | Multilingual EU |
| Gemma 3 27B | ~17 GB | Google, multimodal |
| Gemma 3 9B | ~6 GB | Lightweight Google |
| Phi-4 14B | ~9 GB | Microsoft, reasoning |
| Command R 35B | ~21 GB | RAG/retrieval |

## 📓 Knowledge & Research
| Integration | Auth Method | Difficulty |
|---|---|---|
| Perplexity API | API key | 🟢 Easy |
| Wikipedia API | None | 🟢 Easy |
| Arxiv API | None | 🟢 Easy |
| Web Search (Brave) | API key | 🟢 Easy |
| DeepL Translation | API key | 🟢 Easy |
| OCR (Tesseract) | Local install | 🟡 Medium |

## 🏠 Smart Home & Media
| Integration | Auth Method | Difficulty |
|---|---|---|
| Home Assistant | API token | 🟡 Medium |
| IFTTT | Webhook key | 🟢 Easy |
| Zapier | Webhook/OAuth | 🟡 Medium |
| Spotify | OAuth 2.0 | 🟡 Medium ✅ |
| YouTube API | API key | 🟡 Medium |
| Philips Hue | Bridge API | 🟡 Medium |

## 💰 Finance & Utility
| Integration | Auth Method | Difficulty |
|---|---|---|
| Crypto API (CoinGecko) | None/API key | 🟢 Easy |
| Stock API (Alpha Vantage) | API key | 🟢 Easy |
| Open Banking (PSD2) | Bank OAuth | 🔴 Hard |
| Google Maps/Geocoding | API key | 🟢 Easy |
| Weather | None (wttr.in) | 🟢 Easy |
| QR Code Generator | Local lib | 🟢 Easy |

## 🔄 System
| Integration | Method | Difficulty |
|---|---|---|
| Auto-Update | GitHub Releases + Tauri updater | 🟢 Easy ✅ |
| Browser Control | Playwright / DevTools | 🟡 Medium ✅ |

---

## Wizard Flow

### 🔧 Installation (Required)
1. **Identity** — name, emoji, profile pic, cover
2. **AI Provider** — at least one: Anthropic, OpenAI, Gemini, or local model

### ⚙️ Settings Panel (Post-install, all optional)
Organized in tabs, enable what you need when you need it.

---

## Priority

### P0 — MVP
Identity, AI providers (cloud + local), Webchat, File system

### P1 — Core
WhatsApp, Telegram, Discord, Twitter, Mastodon, Gmail/IMAP, GitHub, ElevenLabs, Ollama

### P2 — Extended
Google Calendar, Outlook, Reddit, LinkedIn, Bluesky, OneDrive, GDrive, Dropbox, Browser, Office suite, Spotify, WordPress, Google Video AI (Veo), Canva, Figma

### P3 — Nice to Have
Figma, Canva, Gamma, Signal, Viber, Slack, Manus.im, Home Assistant, IFTTT, Zapier, TikTok, Voice clone, OCR, Finance, YouTube, Hue

---

## 📊 Current Implementation Status

**Total active modules:** 34
**Credentials configured:** Bluesky, Perplexity, LinkedIn, Spotify, Dropbox, Microsoft (OneDrive/Office), Google Drive (shared OAuth), Groq, Gemini, Canva, Figma, WordPress
**No credentials needed:** Browser Control, Auto-Update
**Already configured:** WhatsApp, Telegram, Discord, Twitter/X, Mastodon, TikTok, Gmail, Google Calendar, IMAP Multi-Account, ProtonMail, GitHub, Voice
**Blocked:** Reddit (app creation restricted), Viber (commercial approval pending)
**Removed:** Outlook Calendar, Instagram
