/**
 * TWIZA Moneypenny — Internationalization (i18n) Module
 * Supports: English (en), Italian (it)
 */
const I18N = (() => {
  // Don't auto-detect from navigator — let the lang-overlay be the first choice
  let currentLang = localStorage.getItem('twiza-lang') || 'en';

  const translations = {
    en: {
      // ===== WIZARD =====
      'wizard.title': 'TWIZA Moneypenny — Setup',
      'wizard.step.welcome': 'Welcome',
      'wizard.step.provider': 'AI Provider',
      'wizard.step.identity': 'Identity',
      'wizard.step.install': 'Install',

      // Welcome page
      'welcome.title.pre': 'Welcome to ',
      'welcome.title.brand': 'TWIZA Moneypenny',
      'welcome.payoff': '...more than an agent!',
      'welcome.subtitle': 'Your personal AI agent for Windows — private, powerful, and completely yours.',
      'welcome.feature.ai': 'Personal AI with memory & personality',
      'welcome.feature.local': '100% local — your data stays yours',
      'welcome.feature.chat': 'Chat via web, WhatsApp, Telegram, Discord',
      'welcome.feature.models': 'Cloud or local AI models — your choice',
      'welcome.btn.start': 'Get Started →',

      // AI Provider page
      'provider.title.pre': 'Choose your ',
      'provider.title.accent': 'AI Provider',
      'provider.subtitle': 'Select a cloud AI provider and enter your API key. You can change this later.',
      'provider.cloud.label': 'Cloud Providers',
      'provider.anthropic.desc': 'Claude — Best overall',
      'provider.openai.desc': 'GPT-4o — Most popular',
      'provider.gemini.desc': 'Google Gemini',
      'provider.gemini.sub': 'Free tier available!',
      'provider.ollama.desc': '100% offline, no API key needed',
      'provider.apikey.label': 'API Key',
      'provider.btn.validate': '✓ Validate',
      'provider.local.title': 'Local Models',
      'provider.local.badge': '● Optional — downloaded after install',
      'provider.local.included': '✅ Base model included: qwen2.5:3b (Qwen 2.5, works offline)',
      'provider.local.qwen.desc': 'Strong reasoning, multilingual',
      'provider.local.deepseek.desc': 'Deep reasoning, code-savvy',
      'provider.local.mistral.desc': 'Fast, multilingual, efficient',
      'provider.local.info': 'A lightweight AI model is already included and works offline. The models below are optional upgrades — they require NVIDIA GPU 8GB+ and will be downloaded after installation.',
      'provider.local.skip': 'Skip additional models',
      'btn.back': '← Back',
      'btn.next': 'Next →',

      // Identity page
      'identity.title.pre': 'Create your ',
      'identity.title.accent': 'Agent',
      'identity.subtitle': 'Give your AI assistant a name, look, and personality.',
      'identity.pic.label': 'Profile Picture',
      'identity.name.label': 'Agent Name',
      'identity.name.placeholder': 'e.g. Jarvis, Friday, Atlas...',
      'identity.emoji.label': 'Emoji',
      'identity.personality.label': 'Personality',
      'identity.p.balanced.name': '⚖️ Balanced',
      'identity.p.balanced.desc': 'Friendly, helpful, concise. Good default for most people.',
      'identity.p.professional.name': '💼 Professional',
      'identity.p.professional.desc': 'Formal, precise, structured. Great for work tasks.',
      'identity.p.creative.name': '🎨 Creative',
      'identity.p.creative.desc': 'Playful, expressive, imaginative. For creative work & fun.',
      'identity.p.custom.name': '✏️ Custom',
      'identity.p.custom.desc': 'Write your own personality from scratch.',
      'identity.p.custom.placeholder': 'Describe your agent personality here...',

      // Install page
      'install.title.pre': 'Ready to ',
      'install.title.accent': 'Install',
      'install.subtitle': 'Review your setup and hit install. This will configure WSL2, install dependencies, and set up your agent.',
      'install.btn': '🚀 Install TWIZA Moneypenny',
      'install.btn.installing': '⏳ Installing...',
      'install.btn.done': '✅ Done — Open Chat',
      'install.btn.retry': '🔄 Retry',
      'install.btn.launch': '🚀 Start Moneypenny',
      'install.btn.starting': '⏳ Starting gateway...',
      'install.btn.almostready': '⏳ Almost ready...',
      'install.btn.reboot': '🔄 Restart PC now',
      'install.reboot.confirm': 'The PC will restart to activate WSL2.\nSave everything before proceeding!\n\nRestart now?',
      'install.reboot.needed': '[!!] A system restart is required to complete WSL2 installation.',
      'install.reboot.saved': '✅ Your settings have been saved and will be restored automatically.',
      'install.reboot.instructions': 'After restarting, re-open TWIZA Moneypenny and the installation will resume where it left off.',
      'install.welcomeback': '✅ Welcome back! Resuming where we left off.',
      'install.progress.init': 'Initializing...',
      'install.progress.done': '\n\n✅ Installation complete! Your agent is ready.',
      'install.progress.error': '\n\n❌ Error: ',
      'install.summary.name': 'Agent Name',
      'install.summary.provider': 'AI Provider',
      'install.summary.apikey': 'API Key',
      'install.summary.local': 'Local Models',
      'install.summary.personality': 'Personality',
      'install.summary.components': 'Components',
      'install.summary.local.skipped': 'Skipped',
      'install.summary.local.none': 'None selected',

      // ===== SETTINGS =====
      'settings.title': 'TWIZA Settings',
      'settings.sidebar.overview': 'Overview',
      'settings.sidebar.all': 'All Integrations',
      'settings.sidebar.ai': 'AI',
      'settings.sidebar.providers': 'AI Providers',
      'settings.sidebar.models': 'Models',
      'settings.sidebar.channels': 'Channels',
      'settings.sidebar.messaging': 'Messaging',
      'settings.sidebar.social': 'Social',
      'settings.sidebar.email': 'Email',
      'settings.sidebar.tools': 'Tools',
      'settings.sidebar.calendar': 'Calendar',
      'settings.sidebar.dev': 'Development',
      'settings.sidebar.cloud': 'Cloud',
      'settings.sidebar.media': 'Media',
      'settings.sidebar.system': 'System',
      'settings.sidebar.language': 'Language',
      'settings.all.title': 'All Integrations',
      'settings.all.desc': '27 integration modules — configure, enable, and test connections.',
      'settings.btn.testall': '🧪 Test All',
      'settings.providers.title': 'AI Providers',
      'settings.providers.desc': 'Configure cloud AI providers. Add your API keys to enable each provider.',
      'settings.messaging.title': 'Messaging',
      'settings.messaging.desc': 'Connect messaging platforms so your agent can chat across channels.',
      'settings.social.title': 'Social Media',
      'settings.social.desc': 'Connect social platforms for monitoring and posting.',
      'settings.email.title': 'Email',
      'settings.email.desc': 'Let your agent read and send emails.',
      'settings.calendar.title': 'Calendar',
      'settings.calendar.desc': 'Connect calendars for scheduling and reminders.',
      'settings.dev.title': 'Development',
      'settings.dev.desc': 'Developer tools and integrations.',
      'settings.cloud.title': 'Cloud Storage',
      'settings.cloud.desc': 'Connect cloud storage for file access.',
      'settings.media.title': 'Media',
      'settings.media.desc': 'Media playback and voice capabilities.',
      'settings.system.title': 'System',
      'settings.system.desc': 'System-level integrations and utilities.',
      'settings.lang.title': 'Language',
      'settings.lang.desc': 'Choose your preferred language for the TWIZA interface.',
      'settings.lang.current': 'Current language',
      'settings.lang.en': 'English',
      'settings.lang.it': 'Italiano',
      'settings.configured': 'Configured',
      'settings.notconfigured': 'Not configured',
      'settings.btn.configure': '⚙️ Configure',
      'settings.btn.test': '🧪 Test',
      'settings.btn.save': '💾 Save',
      'settings.btn.cancel': 'Cancel',
      'settings.modal.title': 'Configure Integration',

      // ===== ONBOARDING =====
      'onboarding.slide1.title': 'Welcome to TWIZA Moneypenny',
      'onboarding.slide1.payoff': '...more than an agent!',
      'onboarding.slide1.text': 'Your personal AI agent for Windows — private, powerful, and completely yours.',
      'onboarding.slide2.title': 'What Can Your Agent Do?',
      'onboarding.slide2.f1.name': 'Multi-Channel Chat',
      'onboarding.slide2.f1.desc': 'WhatsApp, Telegram, Discord and more — all in one',
      'onboarding.slide2.f2.name': 'Persistent Memory',
      'onboarding.slide2.f2.desc': 'Remembers context across sessions',
      'onboarding.slide2.f3.name': 'Privacy First',
      'onboarding.slide2.f3.desc': 'Everything runs on your machine',
      'onboarding.slide2.f4.name': 'Custom Personality',
      'onboarding.slide2.f4.desc': 'Make it unique with your own instructions',
      'onboarding.slide3.title': 'How It Works',
      'onboarding.slide3.text': 'TWIZA runs OpenClaw inside WSL2 — a full AI backend on your Windows machine. Cloud models for power, local models for privacy. You choose.',
      'onboarding.slide3.tip': '💡 The setup wizard handles everything automatically. No terminal required!',
      'onboarding.slide4.title': 'Connect Everything',
      'onboarding.slide4.text': 'Chat via WhatsApp, Telegram, and more. Manage GitHub, email, files — all through your personal agent.',
      'onboarding.slide4.files': 'Your Files',
      'onboarding.slide5.title': 'Ready to Begin?',
      'onboarding.slide5.text': 'The setup wizard will guide you through configuring your API keys, choosing a personality, and connecting your channels.',
      'onboarding.slide5.time': 'It takes about 5 minutes. Let\'s go!',
      'onboarding.btn.back': 'Back',
      'onboarding.btn.next': 'Next',
      'onboarding.btn.start': 'Get Started 🚀',
      'onboarding.link.docs': '📖 Documentation',
      'onboarding.link.community': '💬 Community',
      'onboarding.link.website': '🌐 Website',

      // ===== MODELS =====
      'models.title': 'Model Wizard',
      'models.desc': 'Manage local AI models and cloud providers. Download models, monitor GPU, and set defaults.',
      'models.gpu.detecting': 'Detecting GPU...',
      'models.gpu.noGpu': 'No NVIDIA GPU Detected',
      'models.gpu.noGpu.detail': 'Models will run on CPU (slower but works!)',
      'models.gpu.checking': 'Checking...',
      'models.gpu.cpuOnly': 'CPU Only',
      'models.section.recommended': '🌟 Recommended for Your Hardware',
      'models.section.local': '🦙 Local Models (Ollama)',
      'models.section.cloud': '☁️ Cloud Providers',
      'models.btn.download': '⬇️ Download',
      'models.btn.delete': '🗑️ Delete',
      'models.btn.setDefault': '☆ Set Default',
      'models.btn.default': '★ Default',
      'models.badge.running': '⚡ Running',
      'models.badge.installed': '✓ Installed',
      'models.badge.recommended': '★ Recommended',
      'models.scanning': 'Scanning hardware...',
      'models.loading': 'Loading models...',
      'models.noRec': 'No recommendations available.',
      'models.preparing': 'Preparing...',
      'models.confirmDelete': 'Delete {model}? This cannot be undone.',

      // ===== GALLERY =====
      'gallery.title': '🎭 Choose a Personality',
      'gallery.subtitle': 'Pick a template for your Moneypenny\'s SOUL.md — or import your own',
      'gallery.payoff': '...more than an agent!',
      'gallery.btn.apply': 'Apply Selected Template',
      'gallery.import.text': 'Drop a custom SOUL.md here or click to import',
      'gallery.preview': 'Preview conversation ▾',
    },

    it: {
      // ===== WIZARD =====
      'wizard.title': 'TWIZA Moneypenny — Configurazione',
      'wizard.step.welcome': 'Benvenuto',
      'wizard.step.provider': 'Provider AI',
      'wizard.step.identity': 'Identità',
      'wizard.step.install': 'Installa',

      // Welcome page
      'welcome.title.pre': 'Benvenuto in ',
      'welcome.title.brand': 'TWIZA Moneypenny',
      'welcome.payoff': '...più di un agente!',
      'welcome.subtitle': 'Il tuo agente AI personale per Windows — privato, potente e completamente tuo.',
      'welcome.feature.ai': 'AI personale con memoria e personalità',
      'welcome.feature.local': '100% locale — i tuoi dati restano tuoi',
      'welcome.feature.chat': 'Chatta via web, WhatsApp, Telegram, Discord',
      'welcome.feature.models': 'Modelli AI cloud o locali — scegli tu',
      'welcome.btn.start': 'Iniziamo →',

      // AI Provider page
      'provider.title.pre': 'Scegli il tuo ',
      'provider.title.accent': 'Provider AI',
      'provider.subtitle': 'Seleziona un provider AI cloud e inserisci la tua API key. Potrai cambiarla in seguito.',
      'provider.cloud.label': 'Provider Cloud',
      'provider.anthropic.desc': 'Claude — Il migliore in assoluto',
      'provider.openai.desc': 'GPT-4o — Il più popolare',
      'provider.gemini.desc': 'Google Gemini',
      'provider.gemini.sub': 'Piano gratuito disponibile!',
      'provider.ollama.desc': '100% offline, nessuna API key',
      'provider.apikey.label': 'Chiave API',
      'provider.btn.validate': '✓ Verifica',
      'provider.local.title': 'Modelli Locali',
      'provider.local.badge': '● Opzionali — scaricati dopo l\'installazione',
      'provider.local.included': '✅ Modello base incluso: qwen2.5:3b (Qwen 2.5, funziona offline)',
      'provider.local.qwen.desc': 'Ragionamento avanzato, multilingue',
      'provider.local.deepseek.desc': 'Ragionamento profondo, esperto di codice',
      'provider.local.mistral.desc': 'Veloce, multilingue, efficiente',
      'provider.local.info': 'Un modello AI leggero è già incluso e funziona offline. I modelli qui sotto sono upgrade opzionali — richiedono GPU NVIDIA 8GB+ e vengono scaricati dopo l\'installazione.',
      'provider.local.skip': 'Salta modelli aggiuntivi',
      'btn.back': '← Indietro',
      'btn.next': 'Avanti →',

      // Identity page
      'identity.title.pre': 'Crea il tuo ',
      'identity.title.accent': 'Agent',
      'identity.subtitle': 'Dai al tuo assistente AI un nome, un aspetto e una personalità.',
      'identity.pic.label': 'Foto Profilo',
      'identity.name.label': 'Nome Agente',
      'identity.name.placeholder': 'es. Jarvis, Friday, Atlas...',
      'identity.emoji.label': 'Emoji',
      'identity.personality.label': 'Personalità',
      'identity.p.balanced.name': '⚖️ Equilibrato',
      'identity.p.balanced.desc': 'Amichevole, utile, conciso. Perfetto per la maggior parte delle persone.',
      'identity.p.professional.name': '💼 Professionale',
      'identity.p.professional.desc': 'Formale, preciso, strutturato. Ideale per il lavoro.',
      'identity.p.creative.name': '🎨 Creativo',
      'identity.p.creative.desc': 'Giocoso, espressivo, fantasioso. Per lavori creativi e divertimento.',
      'identity.p.custom.name': '✏️ Personalizzato',
      'identity.p.custom.desc': 'Scrivi la tua personalità da zero.',
      'identity.p.custom.placeholder': 'Descrivi la personalità del tuo agente qui...',

      // Install page
      'install.title.pre': 'Pronto per ',
      'install.title.accent': 'Installare',
      'install.subtitle': 'Rivedi la configurazione e avvia l\'installazione. Verrà configurato WSL2, installate le dipendenze e preparato il tuo agente.',
      'install.btn': '🚀 Installa TWIZA Moneypenny',
      'install.btn.installing': '⏳ Installazione...',
      'install.btn.done': '✅ Fatto — Apri Chat',
      'install.btn.retry': '🔄 Riprova',
      'install.btn.launch': '🚀 Avvia Moneypenny',
      'install.btn.starting': '⏳ Avvio gateway in corso...',
      'install.btn.almostready': '⏳ Quasi pronto...',
      'install.btn.reboot': '🔄 Riavvia il PC ora',
      'install.reboot.confirm': 'Il PC verrà riavviato per attivare WSL2.\nSalva tutto prima di procedere!\n\nRiavviare ora?',
      'install.reboot.needed': '[!!] Riavvio necessario per completare installazione WSL2.',
      'install.reboot.saved': '✅ Le tue impostazioni sono state salvate e verranno ripristinate automaticamente.',
      'install.reboot.instructions': 'Dopo il riavvio, riapri TWIZA Moneypenny e l\'installazione ripartirà da dove si era interrotta.',
      'install.welcomeback': '✅ Bentornato! Riprendiamo da dove eravamo rimasti.',
      'install.progress.init': 'Inizializzazione...',
      'install.progress.done': '\n\n✅ Installazione completata! Il tuo agente è pronto.',
      'install.progress.error': '\n\n❌ Errore: ',
      'install.summary.name': 'Nome Agente',
      'install.summary.provider': 'Provider AI',
      'install.summary.apikey': 'Chiave API',
      'install.summary.local': 'Modelli Locali',
      'install.summary.personality': 'Personalità',
      'install.summary.components': 'Componenti',
      'install.summary.local.skipped': 'Saltati',
      'install.summary.local.none': 'Nessuno selezionato',

      // ===== SETTINGS =====
      'settings.title': 'Impostazioni TWIZA',
      'settings.sidebar.overview': 'Panoramica',
      'settings.sidebar.all': 'Tutte le Integrazioni',
      'settings.sidebar.ai': 'AI',
      'settings.sidebar.providers': 'Provider AI',
      'settings.sidebar.models': 'Modelli',
      'settings.sidebar.channels': 'Canali',
      'settings.sidebar.messaging': 'Messaggistica',
      'settings.sidebar.social': 'Social',
      'settings.sidebar.email': 'Email',
      'settings.sidebar.tools': 'Strumenti',
      'settings.sidebar.calendar': 'Calendario',
      'settings.sidebar.dev': 'Sviluppo',
      'settings.sidebar.cloud': 'Cloud',
      'settings.sidebar.media': 'Media',
      'settings.sidebar.system': 'Sistema',
      'settings.sidebar.language': 'Lingua',
      'settings.all.title': 'Tutte le Integrazioni',
      'settings.all.desc': '27 moduli di integrazione — configura, abilita e testa le connessioni.',
      'settings.btn.testall': '🧪 Testa Tutto',
      'settings.providers.title': 'Provider AI',
      'settings.providers.desc': 'Configura i provider AI cloud. Aggiungi le tue chiavi API per abilitare ogni provider.',
      'settings.messaging.title': 'Messaggistica',
      'settings.messaging.desc': 'Collega piattaforme di messaggistica per far chattare il tuo agente su più canali.',
      'settings.social.title': 'Social Media',
      'settings.social.desc': 'Collega piattaforme social per monitoraggio e pubblicazione.',
      'settings.email.title': 'Email',
      'settings.email.desc': 'Permetti al tuo agente di leggere e inviare email.',
      'settings.calendar.title': 'Calendario',
      'settings.calendar.desc': 'Collega calendari per pianificazione e promemoria.',
      'settings.dev.title': 'Sviluppo',
      'settings.dev.desc': 'Strumenti e integrazioni per sviluppatori.',
      'settings.cloud.title': 'Archiviazione Cloud',
      'settings.cloud.desc': 'Collega lo storage cloud per l\'accesso ai file.',
      'settings.media.title': 'Media',
      'settings.media.desc': 'Riproduzione multimediale e funzionalità vocali.',
      'settings.system.title': 'Sistema',
      'settings.system.desc': 'Integrazioni e utilità di sistema.',
      'settings.lang.title': 'Lingua',
      'settings.lang.desc': 'Scegli la lingua preferita per l\'interfaccia TWIZA.',
      'settings.lang.current': 'Lingua attuale',
      'settings.lang.en': 'English',
      'settings.lang.it': 'Italiano',
      'settings.configured': 'Configurato',
      'settings.notconfigured': 'Non configurato',
      'settings.btn.configure': '⚙️ Configura',
      'settings.btn.test': '🧪 Testa',
      'settings.btn.save': '💾 Salva',
      'settings.btn.cancel': 'Annulla',
      'settings.modal.title': 'Configura Integrazione',

      // ===== ONBOARDING =====
      'onboarding.slide1.title': 'Benvenuto in TWIZA Moneypenny',
      'onboarding.slide1.payoff': '...più di un agente!',
      'onboarding.slide1.text': 'Il tuo agente AI personale per Windows — privato, potente e completamente tuo.',
      'onboarding.slide2.title': 'Cosa Può Fare il Tuo Agente?',
      'onboarding.slide2.f1.name': 'Chat Multi-Canale',
      'onboarding.slide2.f1.desc': 'WhatsApp, Telegram, Discord e tanto altro — tutto in uno',
      'onboarding.slide2.f2.name': 'Memoria Persistente',
      'onboarding.slide2.f2.desc': 'Ricorda il contesto tra le sessioni',
      'onboarding.slide2.f3.name': 'Privacy al Primo Posto',
      'onboarding.slide2.f3.desc': 'Tutto gira sulla tua macchina',
      'onboarding.slide2.f4.name': 'Personalità Personalizzabile',
      'onboarding.slide2.f4.desc': 'Rendilo unico con le tue istruzioni',
      'onboarding.slide3.title': 'Come Funziona',
      'onboarding.slide3.text': 'TWIZA esegue OpenClaw dentro WSL2 — un backend AI completo sulla tua macchina Windows. Modelli cloud per la potenza, modelli locali per la privacy. Scegli tu.',
      'onboarding.slide3.tip': '💡 La procedura guidata gestisce tutto automaticamente. Nessun terminale richiesto!',
      'onboarding.slide4.title': 'Collega Tutto',
      'onboarding.slide4.text': 'Chatta via WhatsApp, Telegram e tanto altro. Gestisci GitHub, email, file — tutto attraverso il tuo agente personale.',
      'onboarding.slide4.files': 'I tuoi File',
      'onboarding.slide5.title': 'Pronto per Iniziare?',
      'onboarding.slide5.text': 'La procedura guidata ti guiderà nella configurazione delle chiavi API, nella scelta della personalità e nel collegamento dei canali.',
      'onboarding.slide5.time': 'Ci vogliono circa 5 minuti. Partiamo!',
      'onboarding.btn.back': 'Indietro',
      'onboarding.btn.next': 'Avanti',
      'onboarding.btn.start': 'Iniziamo 🚀',
      'onboarding.link.docs': '📖 Documentazione',
      'onboarding.link.community': '💬 Community',
      'onboarding.link.website': '🌐 Sito Web',

      // ===== MODELS =====
      'models.title': 'Gestione Modelli',
      'models.desc': 'Gestisci i modelli AI locali e i provider cloud. Scarica modelli, monitora la GPU e imposta quelli predefiniti.',
      'models.gpu.detecting': 'Rilevamento GPU...',
      'models.gpu.noGpu': 'Nessuna GPU NVIDIA Rilevata',
      'models.gpu.noGpu.detail': 'I modelli gireranno su CPU (più lento ma funziona!)',
      'models.gpu.checking': 'Verifica...',
      'models.gpu.cpuOnly': 'Solo CPU',
      'models.section.recommended': '🌟 Consigliati per il Tuo Hardware',
      'models.section.local': '🦙 Modelli Locali (Ollama)',
      'models.section.cloud': '☁️ Provider Cloud',
      'models.btn.download': '⬇️ Scarica',
      'models.btn.delete': '🗑️ Elimina',
      'models.btn.setDefault': '☆ Imposta Predefinito',
      'models.btn.default': '★ Predefinito',
      'models.badge.running': '⚡ In Esecuzione',
      'models.badge.installed': '✓ Installato',
      'models.badge.recommended': '★ Consigliato',
      'models.scanning': 'Analisi hardware...',
      'models.loading': 'Caricamento modelli...',
      'models.noRec': 'Nessun consiglio disponibile.',
      'models.preparing': 'Preparazione...',
      'models.confirmDelete': 'Eliminare {model}? Non si può annullare.',

      // ===== GALLERY =====
      'gallery.title': '🎭 Scegli una Personalità',
      'gallery.subtitle': 'Scegli un template per il SOUL.md del tuo Moneypenny — o importa il tuo',
      'gallery.payoff': '...più di un agente!',
      'gallery.btn.apply': 'Applica Template Selezionato',
      'gallery.import.text': 'Trascina un SOUL.md personalizzato qui o clicca per importare',
      'gallery.preview': 'Anteprima conversazione ▾',
    }
  };

  function t(key, params) {
    let str = translations[currentLang]?.[key] || translations['en']?.[key] || key;
    if (params) {
      Object.entries(params).forEach(([k, v]) => {
        str = str.replace(`{${k}}`, v);
      });
    }
    return str;
  }

  function setLang(lang) {
    if (!translations[lang]) return;
    currentLang = lang;
    localStorage.setItem('twiza-lang', lang);
    document.documentElement.lang = lang;

    // Update all elements with data-i18n attribute
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      const attr = el.getAttribute('data-i18n-attr');
      if (attr === 'placeholder') {
        el.placeholder = t(key);
      } else if (attr === 'title') {
        el.title = t(key);
      } else {
        el.textContent = t(key);
      }
    });

    // Update elements with data-i18n-html (preserve inner HTML structure)
    document.querySelectorAll('[data-i18n-html]').forEach(el => {
      const key = el.getAttribute('data-i18n-html');
      el.innerHTML = t(key);
    });

    // Update language toggle UI
    document.querySelectorAll('.lang-toggle-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.lang === currentLang);
    });

    // Dispatch event for custom handlers
    window.dispatchEvent(new CustomEvent('langchange', { detail: { lang: currentLang } }));
  }

  function getLang() { return currentLang; }

  function init() {
    // Apply translations on load
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => setLang(currentLang));
    } else {
      setLang(currentLang);
    }
  }

  // Auto-init
  init();

  return { t, setLang, getLang, translations };
})();
