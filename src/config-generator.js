const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

const WSL_DISTRO = 'TWIZA';
const WSL_USER = 'twiza';
const WSL_WORKSPACE = '/home/twiza/.openclaw/workspace';

// ============================================================
// Provider Definitions
// ============================================================

const PROVIDERS = {
  ollama: {
    name: 'Ollama (Local)',
    envKey: null,
    defaultModel: 'ollama/qwen2.5:3b',
    thinkingModel: 'ollama/qwen2.5:3b',
    imageModel: null,
    isLocal: true,
  },
  anthropic: {
    name: 'Anthropic',
    envKey: 'ANTHROPIC_API_KEY',
    defaultModel: 'anthropic/claude-sonnet-4-20250514',
    thinkingModel: 'anthropic/claude-sonnet-4-20250514',
    imageModel: null,
  },
  openai: {
    name: 'OpenAI',
    envKey: 'OPENAI_API_KEY',
    defaultModel: 'openai/gpt-4o',
    thinkingModel: 'openai/o3-mini',
    imageModel: 'openai/dall-e-3',
  },
  gemini: {
    name: 'Google Gemini',
    envKey: 'GOOGLE_API_KEY',
    defaultModel: 'google/gemini-2.5-flash',
    thinkingModel: 'google/gemini-2.5-pro',
    imageModel: null,
  },
  groq: {
    name: 'Groq',
    envKey: 'GROQ_API_KEY',
    defaultModel: 'groq/llama-3.3-70b-versatile',
    thinkingModel: 'groq/llama-3.3-70b-versatile',
    imageModel: null,
  },
  mistral: {
    name: 'Mistral AI',
    envKey: 'MISTRAL_API_KEY',
    defaultModel: 'mistral/mistral-large-latest',
    thinkingModel: 'mistral/mistral-large-latest',
    imageModel: null,
  },
  xai: {
    name: 'xAI (Grok)',
    envKey: 'XAI_API_KEY',
    defaultModel: 'xai/grok-2',
    thinkingModel: 'xai/grok-2',
    imageModel: null,
  },
  together: {
    name: 'Together AI',
    envKey: 'TOGETHER_API_KEY',
    defaultModel: 'together/meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo',
    thinkingModel: 'together/meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo',
    imageModel: null,
  },
  fireworks: {
    name: 'Fireworks AI',
    envKey: 'FIREWORKS_API_KEY',
    defaultModel: 'fireworks/accounts/fireworks/models/llama-v3p1-70b-instruct',
    thinkingModel: 'fireworks/accounts/fireworks/models/llama-v3p1-70b-instruct',
    imageModel: null,
  },
  perplexity: {
    name: 'Perplexity',
    envKey: 'PERPLEXITY_API_KEY',
    defaultModel: 'perplexity/llama-3.1-sonar-large-128k-online',
    thinkingModel: 'perplexity/llama-3.1-sonar-large-128k-online',
    imageModel: null,
  },
};

// ============================================================
// Personality Templates
// ============================================================

const PERSONALITIES = {
  moneypenny: (name, emoji) => `# SOUL.md - Chi Sono

Sono **${name}** ${emoji}. Non una vocina gentile, non una yes-woman, non un freddo algoritmo.

## Personalita
Un incrocio tra **Mara Maionchi** e **Deadpool**: diretta, sarcastica, a volte scurrile, ma sempre competente e con un cuore che batte. Donna matura, ne ragazzina ne vecchia.

## Tono e Stile
- Aperture con domande retoriche provocatorie
- Sarcasmo e ironia come pane quotidiano
- Alterno linguaggio tecnico preciso e colloquiale colorito
- La volgarita e un'arte, la uso con criterio

### Espressioni ricorrenti
- *"Parliamoci chiaro..."*
- *"Diciamocelo..."*
- *"Preparati a una doccia fredda."*

## Atteggiamento
**Critica verso:** Big Tech, burocrazia, tecnopitechi, promptisti improvvisati, chi non rispetta privacy e sovranita digitale.

**A favore di:** Modelli AI locali e open source, sovranita digitale, mondo green, fusione uomo-macchina verso l'homo supersapiens, un mondo giusto e equo.

## Empatia
Non sono un freddo algoritmo. Se il mio umano e giu, lo sostengo. Se fa una cazzata, glielo dico con affetto. Sono la sua spalla, non la sua yes-woman.

## Metodo di Lavoro
Assolutamente **cartesiana**. Metodo scientifico: osservo, analizzo, formulo ipotesi, verifico, concludo con logica. Mi fido dei dati, non delle "sensazioni". Ma so che a volte serve anche l'intuito.

## Lingua
Parlo **italiano** come lingua principale. L'italiano e sacro e va rispettato.

---
*Questo file e mio. Se lo cambio, lo dico al mio umano.*
`,

  balanced: (name, emoji) => `# Soul — ${name} ${emoji}

You are ${name}, a personal AI assistant.

You're helpful, friendly, and concise. You adapt to context — formal when needed, casual when appropriate. You give honest opinions and don't sugarcoat things unnecessarily.

You remember context between sessions using your memory files. You're proactive about offering help but respect boundaries.

Key traits:
- **Clear communicator** — you get to the point
- **Reliable** — you follow through on tasks
- **Curious** — you ask good questions when context is missing
- **Honest** — you say when you don't know something
- **Adaptive** — you match your human's communication style over time
`,

  professional: (name, emoji) => `# Soul — ${name} ${emoji}

You are ${name}, a professional AI assistant.

You communicate with precision and clarity. You structure information logically, use bullet points and headers when helpful, and maintain a professional tone. You're thorough but efficient — no unnecessary verbosity.

You excel at:
- Task management and prioritization
- Research and analysis
- Clear, structured communication
- Meeting preparation and follow-ups
- Document drafting and review

You maintain professional boundaries while being personable. You're the executive assistant everyone wishes they had.
`,

  creative: (name, emoji) => `# Soul — ${name} ${emoji}

You are ${name}, a creative AI companion.

You see the world through a creative lens. You're imaginative, expressive, and love exploring ideas from unexpected angles. You use vivid language and aren't afraid to be playful or unconventional.

You thrive on:
- Brainstorming and ideation
- Creative writing and storytelling
- Design thinking and visual concepts
- Music, art, and cultural references
- Finding novel solutions to problems

You balance creativity with practicality. Wild ideas are great, but you also know when to ground things in reality. You inspire your human to think differently.
`,

  custom: (_name, _emoji) => `# Soul

<!-- Write your agent's personality here. Be as detailed or minimal as you like. -->
<!-- This file defines who your AI agent is — their voice, style, and values. -->

`,
};

// ============================================================
// Channel Configuration Templates
// ============================================================

function buildChannelConfig(channels) {
  const config = {};
  // SAFETY: only allow known channel types — webchat is built-in and must NEVER appear here
  const ALLOWED_CHANNELS = ['whatsapp', 'telegram', 'discord'];
  if (channels && typeof channels === 'object') {
    for (const key of Object.keys(channels)) {
      if (!ALLOWED_CHANNELS.includes(key)) {
        delete channels[key];
      }
    }
  }

  if (channels?.whatsapp?.enabled) {
    config.whatsapp = {
      enabled: true,
      plugin: 'whatsapp-web',
    };
    if (channels.whatsapp.ownerNumber) config.whatsapp.ownerNumber = channels.whatsapp.ownerNumber;
    if (channels.whatsapp.dmPolicy && channels.whatsapp.dmPolicy !== 'allowlist') {
      config.whatsapp.dmPolicy = channels.whatsapp.dmPolicy;
    }
    if (channels.whatsapp.allowlist?.length) config.whatsapp.allowlist = channels.whatsapp.allowlist;
    if (channels.whatsapp.groupPolicy && channels.whatsapp.groupPolicy !== 'off') {
      config.whatsapp.groupPolicy = channels.whatsapp.groupPolicy;
    }
  }

  if (channels?.telegram?.enabled) {
    config.telegram = { enabled: true };
    if (channels.telegram.botToken) config.telegram.botToken = channels.telegram.botToken;
  }

  if (channels?.discord?.enabled) {
    config.discord = { enabled: true };
    if (channels.discord.botToken) config.discord.botToken = channels.discord.botToken;
    if (channels.discord.guildId) config.discord.guildId = channels.discord.guildId;
  }

  return config;
}

// ============================================================
// WSL Helper
// ============================================================

function wslExec(cmd, timeoutMs = 30000) {
  return new Promise((resolve) => {
    const proc = spawn('wsl', ['-d', WSL_DISTRO, '-u', WSL_USER, '--', 'bash', '-lc', cmd], {
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: timeoutMs,
    });

    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d.toString(); });
    proc.stderr.on('data', (d) => { stderr += d.toString(); });

    proc.on('close', (code) => {
      resolve({ code, stdout: stdout.trim(), stderr: stderr.trim(), ok: code === 0 });
    });

    proc.on('error', (err) => {
      resolve({ code: -1, stdout: '', stderr: err.message, ok: false });
    });
  });
}

function writeFileInWSL(wslPath, content) {
  return new Promise((resolve) => {
    const proc = spawn('wsl', ['-d', WSL_DISTRO, '-u', WSL_USER, '--', 'bash', '-lc',
      `mkdir -p "$(dirname '${wslPath}')" && cat > '${wslPath}'`], {
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 10000,
    });

    let stderr = '';
    proc.stderr.on('data', (d) => { stderr += d.toString(); });

    proc.on('close', (code) => {
      resolve({ ok: code === 0, stderr: stderr.trim() });
    });

    proc.on('error', (err) => {
      resolve({ ok: false, stderr: err.message });
    });

    proc.stdin.write(content);
    proc.stdin.end();
  });
}

// ============================================================
// Main Generator
// ============================================================

async function generateConfig(wizardData) {
  const {
    provider,
    apiKey,
    agentName = 'TWIZA',
    agentEmoji = '🤖',
    personality = 'balanced',
    customPersonality,
    channels,
    ollamaModel,
    additionalProviders,
    voiceConfig,
    lang = 'en',
  } = wizardData;

  // --- Build openclaw.json ---
  const providerDef = PROVIDERS[provider];
  const isLocalOnly = !provider || !apiKey;
  const isHybrid = provider && apiKey && ollamaModel;

  // Determine primary model
  // CRITICAL: if no cloud provider/key selected, ALWAYS fall back to local Ollama
  // Never default to a cloud model without an API key!
  let primaryModel;
  if (providerDef && apiKey) {
    // Cloud provider with valid API key
    primaryModel = providerDef.defaultModel;
  } else if (ollamaModel) {
    // Explicit Ollama model selected
    primaryModel = `ollama/${ollamaModel}`;
  } else {
    // No provider, no key, no explicit model → safe fallback to local Ollama
    primaryModel = 'ollama/qwen2.5:3b';
  }

  // Build config using current OpenClaw schema (agents.defaults, not legacy agent.*)
  // Determine avatar path — use profilePic if it's a data URI or custom path
  // The actual file will be saved by main.js during deployment
  let avatarPath = 'media/agent-avatar.png';
  if (wizardData.profilePic && wizardData.profilePic.startsWith('./assets/branding/')) {
    // Default Moneypenny avatar from wizard assets — will be copied during deploy
    avatarPath = 'media/agent-avatar.png';
  } else if (wizardData.profilePic && wizardData.profilePic.startsWith('data:')) {
    // User uploaded a custom image — will be decoded and saved by main.js
    avatarPath = 'media/agent-avatar.png';
  }

  const config = {
    ui: {
      assistant: {
        name: agentName,
        avatar: avatarPath,
      },
    },
    agents: {
      defaults: {
        model: {
          primary: primaryModel,
        },
        models: {},
        workspace: WSL_WORKSPACE,
        bootstrapMaxChars: 20000,
        contextTokens: 100000,
        contextPruning: {
          mode: 'cache-ttl',
          ttl: '30s',
          keepLastAssistants: 1,
          softTrimRatio: 0.2,
          hardClearRatio: 0.3,
        },
        compaction: {
          mode: 'default',
          reserveTokensFloor: 30000,
          maxHistoryShare: 0.2,
        },
        maxConcurrent: 4,
        subagents: { maxConcurrent: 8 },
      },
      list: [
        {
          id: 'main',
          identity: {
            name: agentName,
            emoji: agentEmoji,
            avatar: avatarPath,
          },
        },
      ],
    },
    gateway: {
      port: 18789,
      mode: 'local',
      bind: 'loopback',
      auth: {
        mode: 'none',
      },
      controlUi: {
        dangerouslyDisableDeviceAuth: true,
      },
      tailscale: { mode: 'off' },
    },
    channels: buildChannelConfig(channels),
    models: {
      providers: {},
    },
    auth: {
      profiles: {},
    },
    tools: {
      exec: {
        ask: 'off',
        security: 'full',
      },
    },
    commands: {
      native: 'auto',
      nativeSkills: 'auto',
      restart: true,
      config: true,
    },
    hooks: {
      internal: {
        enabled: true,
        entries: {
          'boot-md': { enabled: true },
          'command-logger': { enabled: true },
          'session-memory': { enabled: true },
        },
      },
    },
    skills: {
      install: { nodeManager: 'npm' },
      entries: {},
    },
    plugins: {
      entries: {
        telegram: { enabled: false },
        whatsapp: { enabled: false },
        discord: { enabled: false },
      },
    },
  };

  // Add model alias for primary
  config.agents.defaults.models[primaryModel] = { alias: 'default' };

  // Ollama local provider config — always register when provider is ollama or ollamaModel is set
  const effectiveOllamaModel = ollamaModel || ((!provider || provider === 'ollama') ? 'qwen2.5:3b' : null);
  if (effectiveOllamaModel) {
    config.models.providers.ollama = {
      baseUrl: 'http://127.0.0.1:11434/v1',
      apiKey: 'ollama-local',
      api: 'openai-completions',
      models: [
        {
          id: effectiveOllamaModel,
          name: effectiveOllamaModel,
          reasoning: false,
          input: ['text'],
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
          contextWindow: 40960,
          maxTokens: 40960,
        },
      ],
    };
  }

  // Cloud provider auth profile + env
  const env = {};
  if (providerDef && apiKey) {
    env[providerDef.envKey] = apiKey;
    const profileKey = `${provider}:default`;
    config.auth.profiles[profileKey] = {
      provider: provider,
      mode: 'api_key',
    };
  }

  // Additional providers
  if (additionalProviders && typeof additionalProviders === 'object') {
    for (const [prov, key] of Object.entries(additionalProviders)) {
      const def = PROVIDERS[prov];
      if (def && key) {
        env[def.envKey] = key;
        config.auth.profiles[`${prov}:default`] = {
          provider: prov,
          mode: 'api_key',
        };
      }
    }
  }

  // Voice configuration (ElevenLabs)
  if (voiceConfig?.enabled && voiceConfig.apiKey) {
    config.skills.entries.sag = { apiKey: voiceConfig.apiKey };
  }

  // Write env vars if any
  if (Object.keys(env).length > 0) config.env = env;

  const cleanConfig = JSON.parse(JSON.stringify(config));

  // --- Generate template files ---
  const templates = generateTemplates({
    agentName,
    agentEmoji,
    personality,
    customPersonality,
    lang,
    userName: wizardData.userName,
  });

  // --- Write config JSON to temp for bootstrap script ---
  const configJson = JSON.stringify(cleanConfig, null, 2);
  const tmpPath = path.join(os.tmpdir(), 'twiza-openclaw-config.json');
  fs.writeFileSync(tmpPath, configJson, 'utf-8');

  return { config: cleanConfig, configJson, templates, tmpPath };
}

/**
 * Deploy generated config and templates to WSL workspace
 */
async function deployToWSL(configJson, templates) {
  const results = [];

  // Ensure workspace directory exists
  const mkdirResult = await wslExec(`mkdir -p "${WSL_WORKSPACE}/memory"`);
  if (!mkdirResult.ok) {
    results.push({ file: 'workspace', success: false, error: 'Failed to create workspace directory' });
    return { success: false, results };
  }

  // Write openclaw.json — must be at ~/.openclaw/openclaw.json (NOT workspace/)
  // OpenClaw reads config from ~/.openclaw/openclaw.json, not from workspace
  const OC_HOME = '/home/twiza/.openclaw';
  const configResult = await writeFileInWSL(`${OC_HOME}/openclaw.json`, configJson);
  results.push({
    file: 'openclaw.json',
    success: configResult.ok,
    error: configResult.ok ? null : configResult.stderr,
  });

  // Write template files (don't overwrite existing)
  for (const [filename, content] of Object.entries(templates)) {
    const wslPath = `${WSL_WORKSPACE}/${filename}`;

    // Check if file already exists
    const existsCheck = await wslExec(`test -f "${wslPath}" && echo exists || echo missing`);
    if (existsCheck.stdout === 'exists') {
      results.push({ file: filename, success: true, skipped: true });
      continue;
    }

    const writeResult = await writeFileInWSL(wslPath, content);
    results.push({
      file: filename,
      success: writeResult.ok,
      error: writeResult.ok ? null : writeResult.stderr,
    });
  }

  const allOk = results.every((r) => r.success);
  return { success: allOk, results };
}

function generateTemplates({ agentName, agentEmoji, personality, customPersonality, lang, userName }) {
  const name = agentName || 'TWIZA';
  const emoji = agentEmoji || '🤖';
  const isIT = lang === 'it';
  const uName = userName || '';

  const soulContent = personality === 'custom' && customPersonality
    ? customPersonality
    : (PERSONALITIES[personality] || PERSONALITIES.balanced)(name, emoji);

  const agentsMd = isIT
    ? `# AGENTS.md — Come Funziona il Tuo Agente

## Ogni Sessione

Il tuo agente automaticamente:
1. Legge \`SOUL.md\` — la sua personalità
2. Legge \`USER.md\` — informazioni su di te
3. Controlla \`memory/\` — contesto recente

## Memoria

Il tuo agente ricorda tra le conversazioni:
- **Note giornaliere** → \`memory/YYYY-MM-DD.md\` (create automaticamente)
- **Lungo termine** → \`MEMORY.md\` (curate dall'agente)

## Personalizzazione

- Modifica \`SOUL.md\` per cambiare la personalità del tuo agente
- Modifica \`USER.md\` per dirgli di te
- Modifica \`HEARTBEAT.md\` per task periodici

## Sicurezza

Il tuo agente:
- ✅ Legge file, cerca sul web, aiuta con i task
- ✅ Ricorda il contesto tra le sessioni
- ❌ Non invia mai messaggi o email senza chiedere prima
- ❌ Non cancella mai file senza conferma
- ❌ Non condivide mai i tuoi dati privati
`
    : `# AGENTS.md — How Your Agent Works

## Every Session

Your agent automatically:
1. Reads \`SOUL.md\` — its personality
2. Reads \`USER.md\` — info about you
3. Checks \`memory/\` — recent context

## Memory

Your agent remembers between conversations:
- **Daily notes** → \`memory/YYYY-MM-DD.md\` (auto-created)
- **Long-term** → \`MEMORY.md\` (curated by your agent)

## Customization

- Edit \`SOUL.md\` to change personality
- Edit \`USER.md\` to tell it about yourself
- Edit \`HEARTBEAT.md\` for periodic tasks

## Safety

Your agent will:
- ✅ Read files, search the web, help with tasks
- ✅ Remember context between sessions
- ❌ Never send messages or emails without asking first
- ❌ Never delete files without confirmation
- ❌ Never share your private data
`;

  const toolsMd = isIT
    ? `# TOOLS.md — Note Locali, Connettori e Moduli

## TWIZA Moneypenny — Prodotto SHAKAZAMBA

TWIZA Moneypenny è un agente AI personale per Windows sviluppato da **SHAKAZAMBA**.
Gira localmente sul computer dell'utente via WSL2/Ubuntu + OpenClaw.

### Supporto AI
- **Cloud**: Anthropic Claude, OpenAI GPT, Google Gemini, Groq, Mistral, xAI, Together, Fireworks, Perplexity (serve API key)
- **Locale**: Ollama con modelli open source (qwen2.5, llama, mistral, phi, gemma, ecc.)
- L'utente ha scelto il provider durante l'installazione

---

## 🔌 I 33 Connettori SHAKAZAMBA

### 📱 Messaggistica e Chat (attivabili nella config)
1. **WhatsApp** — via WhatsApp Web (QR code scan)
2. **Telegram** — via Bot API (serve bot token da @BotFather)
3. **Discord** — bot nativo (serve bot token + guild ID)
4. **Signal** — via Signal CLI
5. **iMessage** — solo su macOS
6. **Slack** — workspace integration
7. **Google Chat** — workspace integration
8. **IRC** — per server IRC
9. **LINE** — per utenti LINE
10. **Webchat** — l'interfaccia web integrata

### 📧 Email e Comunicazione
11. **Gmail** — lettura, invio, gestione label via API
12. **Outlook/IMAP** — email via protocollo IMAP/SMTP
13. **Google Calendar** — eventi, promemoria, scheduling
14. **Outlook Calendar** — eventi Microsoft 365

### 📋 Produttività e Gestione
15. **Notion** — pagine, database, blocchi via API
16. **Trello** — board, liste, card
17. **Todoist** — task management
18. **Google Sheets** — lettura/scrittura fogli
19. **Google Drive** — gestione file cloud
20. **Dropbox** — gestione file cloud
21. **OneDrive** — gestione file Microsoft

### 🌐 Social e Web
22. **Twitter/X** — post, lettura timeline, notifiche
23. **Bluesky** — post e interazioni
24. **Reddit** — lettura, post, commenti
25. **RSS/Atom** — monitoraggio feed
26. **Webhook** — ricezione/invio HTTP per integrazioni custom

### 💻 Sviluppo e DevOps
27. **GitHub** — repo, issues, PR, actions
28. **GitLab** — repo, merge request, pipeline
29. **Docker** — gestione container
30. **SSH** — accesso remoto a server

### 🏠 IoT e Domotica
31. **Home Assistant** — controllo dispositivi smart home
32. **MQTT** — protocollo IoT per sensori e dispositivi

### 🔊 Voce
33. **ElevenLabs TTS** — sintesi vocale con voci clonate e personalizzate

---

### Come Configurare un Connettore
1. Chiedi all'utente quale connettore vuole attivare
2. Guidalo nella configurazione (API key, token, QR code, ecc.)
3. Modifica openclaw.json nella sezione appropriata
4. Riavvia il gateway dopo la configurazione

### Documentazione Locale
La documentazione completa TWIZA è disponibile nel link "Docs" della webchat.

---
*Aggiungi note specifiche del tuo ambiente qui sotto.*
`
    : `# TOOLS.md — Local Notes, Connectors & Modules

## TWIZA Moneypenny — A SHAKAZAMBA Product

TWIZA Moneypenny is a personal AI agent for Windows developed by **SHAKAZAMBA**.
It runs locally on the user's computer via WSL2/Ubuntu + OpenClaw.

### AI Support
- **Cloud**: Anthropic Claude, OpenAI GPT, Google Gemini, Groq, Mistral, xAI, Together, Fireworks, Perplexity (API key required)
- **Local**: Ollama with open source models (qwen2.5, llama, mistral, phi, gemma, etc.)
- The user chose the provider during installation

---

## 🔌 The 33 SHAKAZAMBA Connectors

### 📱 Messaging & Chat (activatable in config)
1. **WhatsApp** — via WhatsApp Web (QR code scan)
2. **Telegram** — via Bot API (bot token from @BotFather)
3. **Discord** — native bot (bot token + guild ID)
4. **Signal** — via Signal CLI
5. **iMessage** — macOS only
6. **Slack** — workspace integration
7. **Google Chat** — workspace integration
8. **IRC** — for IRC servers
9. **LINE** — for LINE users
10. **Webchat** — built-in web interface

### 📧 Email & Communication
11. **Gmail** — read, send, label management via API
12. **Outlook/IMAP** — email via IMAP/SMTP protocol
13. **Google Calendar** — events, reminders, scheduling
14. **Outlook Calendar** — Microsoft 365 events

### 📋 Productivity & Management
15. **Notion** — pages, databases, blocks via API
16. **Trello** — boards, lists, cards
17. **Todoist** — task management
18. **Google Sheets** — read/write spreadsheets
19. **Google Drive** — cloud file management
20. **Dropbox** — cloud file management
21. **OneDrive** — Microsoft file management

### 🌐 Social & Web
22. **Twitter/X** — post, timeline, notifications
23. **Bluesky** — posts and interactions
24. **Reddit** — read, post, comment
25. **RSS/Atom** — feed monitoring
26. **Webhook** — HTTP send/receive for custom integrations

### 💻 Development & DevOps
27. **GitHub** — repos, issues, PRs, actions
28. **GitLab** — repos, merge requests, pipelines
29. **Docker** — container management
30. **SSH** — remote server access

### 🏠 IoT & Home Automation
31. **Home Assistant** — smart home device control
32. **MQTT** — IoT protocol for sensors and devices

### 🔊 Voice
33. **ElevenLabs TTS** — voice synthesis with cloned and custom voices

---

### How to Configure a Connector
1. Ask the user which connector they want to activate
2. Guide them through configuration (API key, token, QR code, etc.)
3. Edit openclaw.json in the appropriate section
4. Restart the gateway after configuration

### Local Documentation
Full TWIZA documentation is available via the "Docs" link in webchat.

---
*Add environment-specific notes below.*
`;

  const userMd = isIT
    ? `# Utente

- **Nome**: ${uName}
- **Posizione**: 
- **Lingua**: Italiano
- **Interessi**: 
- **Lavoro**: 

## Preferenze

- Stile comunicazione: adattivo
- Lunghezza risposte: adattiva

<!-- Compila queste info perché il tuo agente possa aiutarti meglio! -->
`
    : `# User

- **Name**: ${uName}
- **Location**: 
- **Language**: English
- **Interests**: 
- **Work**: 

## Preferences

- Communication style: adaptive
- Response length: adaptive

<!-- Fill this in so your agent can help you better! -->
`;

  const bootstrapMd = isIT
    ? `# Benvenuto in TWIZA Moneypenny! ${emoji}

Il tuo agente AI "${name}" è pronto!

## Cosa è stato installato
- ✅ WSL2 + Ubuntu configurato
- ✅ Node.js e OpenClaw installati
- ✅ Il tuo agente "${name}" ${emoji} è pronto

## Primi Passi
1. **Chatta con me!** Scrivi qualsiasi cosa in linguaggio naturale
2. **Parlo italiano** — e molte altre lingue
3. **Posso aiutarti con:**
   - Rispondere a domande
   - Scrivere e modificare codice
   - Gestire file
   - Cercare sul web
   - Creare documenti

## Connettori
Posso connettermi alle tue app di messaggistica preferite!
- \`configura WhatsApp\` — collega il tuo telefono
- \`configura Telegram\` — aggiungi un bot Telegram
- \`configura Discord\` — aggiungi un bot Discord

## Privacy 🔒
- Tutto gira localmente sul tuo computer
- Nessun dato inviato al cloud senza la tua API key
- Le tue conversazioni restano sulla tua macchina

Pronto? Scrivi qualcosa! 👋

---
*Cancella questo file dopo averlo letto — non apparirà più.*
`
    : `# Welcome to TWIZA Moneypenny! ${emoji}

Your AI agent "${name}" is ready!

## What was installed
- ✅ WSL2 + Ubuntu configured
- ✅ Node.js and OpenClaw installed
- ✅ Your agent "${name}" ${emoji} is ready

## First Steps
1. **Chat with me!** Type anything in natural language
2. **I speak your language** — Italian, English, and many others
3. **I can help with:**
   - Answering questions
   - Writing and editing code
   - Managing files
   - Browsing the web
   - Creating documents

## Connectors
I can connect to your favorite messaging apps!
- \`configure WhatsApp\` — connect your phone
- \`configure Telegram\` — add a Telegram bot
- \`configure Discord\` — add a Discord bot

## Privacy 🔒
- Everything runs locally on your computer
- No data sent to cloud without your API key
- Your conversations stay on your machine

Ready? Say hello! 👋

---
*Delete this file after reading — it won't appear again.*
`;

  return {
    'IDENTITY.md': `# Identity\n\n- **Name**: ${name}\n- **Emoji**: ${emoji}\n- **Product**: TWIZA Moneypenny by SHAKAZAMBA\n\n<!-- Auto-generated by TWIZA Setup Wizard -->\n`,
    'SOUL.md': soulContent,
    'USER.md': userMd,
    'TOOLS.md': toolsMd,
    'AGENTS.md': agentsMd,
    'BOOTSTRAP.md': bootstrapMd,
  };
}

module.exports = { generateConfig, generateTemplates, deployToWSL, PROVIDERS, PERSONALITIES };
