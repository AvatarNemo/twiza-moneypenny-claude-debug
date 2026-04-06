// ============================================================
// TWIZA Moneypenny — Model Manager
// Connects to gateway via WebSocket for REAL config read/write
// Ollama model management via direct Ollama API
// ============================================================

const OLLAMA_URL = 'http://localhost:11434';
const GW_WS_URL = (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host;

let installedModels = [];
let pullAbortController = null;

// ---- Gateway WebSocket Client ----
let gwWs = null;
let gwReqId = 0;
let gwPending = {};
let gwConnected = false;
let gwBaseHash = null;
let gwAuthToken = null;
let gwRawConfig = null;
let gwReconnecting = false;
let gwReconnectTimer = null;

function gwSend(method, params) {
    return new Promise(function(resolve, reject) {
        if (!gwWs || gwWs.readyState !== WebSocket.OPEN) {
            reject(new Error('Gateway non connesso'));
            return;
        }
        var id = String(++gwReqId);
        var msg = { type: 'req', id: id, method: method, params: params || {} };
        gwPending[id] = { resolve: resolve, reject: reject };
        gwWs.send(JSON.stringify(msg));
        setTimeout(function() {
            if (gwPending[id]) {
                delete gwPending[id];
                reject(new Error('Timeout'));
            }
        }, 15000);
    });
}

function gwConnect() {
    return new Promise(function(resolve) {
        var statusEl = document.getElementById('gw-status');
        if (statusEl) { statusEl.textContent = '⏳ Connessione...'; statusEl.className = 'status-value'; }

        gwWs = new WebSocket(GW_WS_URL);

        gwWs.onmessage = function(evt) {
            var msg;
            try { msg = JSON.parse(evt.data); } catch(e) { return; }

            if (msg.type === 'event' && msg.event === 'connect.challenge') {
                // Authenticate
                var authObj = {};
                if (gwAuthToken) authObj.token = gwAuthToken;
                gwWs.send(JSON.stringify({
                    type: 'req', id: String(++gwReqId), method: 'connect',
                    params: {
                        minProtocol: 3, maxProtocol: 3,
                        client: { id: 'openclaw-control-ui', version: '1.0', platform: 'web', mode: 'ui' },
                        role: 'operator',
                        scopes: ['operator.read', 'operator.write', 'operator.admin'],
                        auth: authObj,
                        caps: []
                    }
                }));
                gwPending[String(gwReqId)] = {
                    resolve: function(payload) {
                        gwConnected = true;
                        if (statusEl) { statusEl.textContent = '🟢 Connesso'; statusEl.className = 'status-value connected'; }
                        resolve(true);
                    },
                    reject: function(err) {
                        if (statusEl) { statusEl.textContent = '🔴 Auth fallita'; statusEl.className = 'status-value disconnected'; }
                        resolve(false);
                    }
                };
            } else if (msg.type === 'res') {
                var pending = gwPending[msg.id];
                if (pending) {
                    delete gwPending[msg.id];
                    if (msg.ok) pending.resolve(msg.payload);
                    else pending.reject(new Error(msg.error?.message || 'Errore gateway'));
                }
            }
        };

        gwWs.onerror = function() {
            if (statusEl) { statusEl.textContent = '🔴 Errore connessione'; statusEl.className = 'status-value disconnected'; }
            resolve(false);
        };

        gwWs.onclose = function() {
            gwConnected = false;
            if (statusEl) { statusEl.textContent = '🔴 Disconnesso'; statusEl.className = 'status-value disconnected'; }
            // Auto-reconnect after gateway restart
            if (!gwReconnecting) {
                gwReconnecting = true;
                gwAutoReconnect();
            }
        };
    });
}

async function gwAutoReconnect() {
    var maxAttempts = 30;
    var delay = 2000;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        var statusEl = document.getElementById('gw-status');
        if (statusEl) { statusEl.textContent = '⏳ Riconnessione... (' + attempt + ')'; statusEl.className = 'status-value'; }
        await new Promise(function(r) { setTimeout(r, delay); });
        try {
            var ok = await gwConnect();
            if (ok) {
                gwReconnecting = false;
                await gwLoadConfig();
                renderCurrentModel();
                renderProviderCards();
                await refreshModels();
                showToast('🟢 Gateway riconnesso');
                return;
            }
        } catch(e) { /* retry */ }
    }
    gwReconnecting = false;
    showToast('❌ Impossibile riconnettersi al gateway', true);
}

async function gwLoadConfig() {
    try {
        var result = await gwSend('config.get', {});
        gwBaseHash = result.hash;
        var cfg = result.config || result.parsed || null;
        if (!cfg && typeof result.raw === 'string' && result.raw.trim().startsWith('{')) {
            try { cfg = JSON.parse(result.raw); } catch(e) { console.warn('raw parse failed', e); }
        }
        gwRawConfig = cfg || {};
        return gwRawConfig;
    } catch(e) {
        console.error('config.get failed:', e);
        return null;
    }
}

async function gwPatchConfig(patch) {
    if (!gwBaseHash) await gwLoadConfig();
    try {
        showToast('⏳ Salvataggio config... il gateway si riavvia');
        await gwSend('config.patch', { baseHash: gwBaseHash, raw: JSON.stringify(patch) });
        // Gateway restarts after config.patch — the WS will close and auto-reconnect.
        // Give it a moment, then try to reload config (may fail if restart in progress)
        await new Promise(function(r) { setTimeout(r, 1500); });
        try { await gwLoadConfig(); } catch(e) { /* will reconnect */ }
        return true;
    } catch(e) {
        // config.patch may timeout because gateway restarts mid-request
        if (e.message === 'Timeout' || e.message === 'Gateway non connesso') {
            showToast('⏳ Gateway in riavvio... attendi la riconnessione');
            return true; // treat as success, auto-reconnect will handle UI refresh
        }
        console.error('config.patch failed:', e);
        showToast('Errore salvataggio config: ' + e.message, true);
        return false;
    }
}

// ---- Toast ----
function showToast(msg, isError) {
    var t = document.getElementById('toast');
    t.textContent = msg;
    t.className = 'toast visible' + (isError ? ' error' : '');
    setTimeout(function(){ t.className = 'toast'; }, 3500);
}

// ---- Ollama API ----
async function checkOllama() {
    var el = document.getElementById('ollama-status');
    try {
        var r = await fetch(OLLAMA_URL + '/api/tags', { signal: AbortSignal.timeout(3000) });
        if (r.ok) {
            el.textContent = '🟢 Online';
            el.className = 'status-value connected';
            return true;
        }
    } catch(e) {}
    el.textContent = '🔴 Offline';
    el.className = 'status-value disconnected';
    return false;
}

async function refreshModels() {
    var online = await checkOllama();
    var helpBox = document.getElementById('ollama-help');
    if (!online) {
        document.getElementById('installed-models').innerHTML = '<p style="color:var(--red);">Ollama non raggiungibile. Assicurati che sia in esecuzione.</p>';
        if (helpBox) helpBox.style.display = 'block';
        document.getElementById('models-count').textContent = '—';
        document.getElementById('total-size').textContent = '—';
        installedModels = [];
        renderModelDropdown();
        return;
    }
    if (helpBox) helpBox.style.display = 'none';
    try {
        var r = await fetch(OLLAMA_URL + '/api/tags');
        var data = await r.json();
        installedModels = (data.models || []).sort(function(a,b){ return a.name.localeCompare(b.name); });
        document.getElementById('models-count').textContent = installedModels.length;
        var totalBytes = 0;
        for (var i = 0; i < installedModels.length; i++) totalBytes += (installedModels[i].size || 0);
        document.getElementById('total-size').textContent = formatSize(totalBytes);
        renderInstalledModels();
        renderRemoveSelector();
        renderModelDropdown();
    } catch(e) {
        document.getElementById('installed-models').innerHTML = '<p style="color:var(--red);">Errore: ' + e.message + '</p>';
    }
}

function formatSize(bytes) {
    if (!bytes) return '?';
    var gb = bytes / (1024*1024*1024);
    if (gb >= 1) return gb.toFixed(1) + ' GB';
    return (bytes / (1024*1024)).toFixed(0) + ' MB';
}

function renderInstalledModels() {
    var container = document.getElementById('installed-models');
    if (!installedModels.length) {
        container.innerHTML = '<p style="color:var(--dim);">Nessun modello installato.</p>';
        return;
    }
    var primaryModel = '';
    if (gwRawConfig) {
        primaryModel = gwRawConfig?.agents?.defaults?.model?.primary || '';
        if (primaryModel.startsWith('ollama/')) primaryModel = primaryModel.replace('ollama/', '');
    }
    container.innerHTML = installedModels.map(function(m) {
        var isPrimary = m.name === primaryModel;
        return '<div class="model-item">' +
            '<div>' +
            '<span class="model-name">' + m.name + '</span>' +
            (isPrimary ? '<span class="model-tag default">IN USO</span>' : '') +
            '<br><span class="model-size">' + formatSize(m.size) + '</span>' +
            '</div>' +
            '<div>' +
            (!isPrimary ? '<button class="btn btn-outline btn-sm" onclick="setActiveModel(\'' + m.name.replace(/'/g, "\\'") + '\')">✅ Usa</button> ' : '') +
            '<button class="btn btn-outline btn-sm" onclick="showModelInfo(\'' + m.name.replace(/'/g, "\\'") + '\')">ℹ️</button>' +
            '</div></div>';
    }).join('');
}

function renderRemoveSelector() {
    var rem = document.getElementById('remove-selector');
    rem.innerHTML = '<option value="">— Seleziona modello da rimuovere —</option>' +
        installedModels.map(function(m){ return '<option value="' + m.name + '">' + m.name + ' (' + formatSize(m.size) + ')</option>'; }).join('');
}

function renderModelDropdown() {
    var sel = document.getElementById('active-model-select');
    if (!sel) return;
    var currentPrimary = gwRawConfig?.agents?.defaults?.model?.primary || '';
    sel.innerHTML = '';
    var hasAny = false;
    var seenValues = new Set();
    // Add cloud providers if configured
    var profiles = gwRawConfig?.auth?.profiles || {};
    var envVars = gwRawConfig?.env || {};
    var cloudModels = [];
    // Check both auth profiles AND env vars for configured providers
    var CLOUD_MODELS = {
        anthropic: [
            { value: 'anthropic/claude-opus-4-6', label: 'Claude Opus 4.6' },
            { value: 'anthropic/claude-sonnet-4-20250514', label: 'Claude Sonnet 4' },
            { value: 'anthropic/claude-haiku-3.5', label: 'Claude Haiku 3.5' }
        ],
        openai: [
            { value: 'openai/gpt-5.1-codex', label: 'GPT-5.1 Codex' },
            { value: 'openai/gpt-4.1', label: 'GPT-4.1' },
            { value: 'openai/gpt-4.1-mini', label: 'GPT-4.1 Mini' }
        ],
        google: [
            { value: 'gemini/gemini-2.5-flash', label: 'Gemini 2.5 Flash' },
            { value: 'gemini/gemini-2.5-pro', label: 'Gemini 2.5 Pro' }
        ],
        groq: [
            { value: 'groq/llama-3.3-70b-versatile', label: 'Llama 3.3 70B (Groq)' },
            { value: 'groq/meta-llama/llama-4-maverick-17b-128e-instruct', label: 'Llama 4 Maverick 17B (Groq)' }
        ]
    };
    var provCfgs = gwRawConfig?.models?.providers || {};
    PROVIDERS.forEach(function(p) {
        var hasProfile = !!profiles[p.profileKey];
        var hasEnvKey = !!envVars[p.envVar];
        var provCfg = provCfgs[p.id] || {};
        var hasProvApi = !!(provCfg.apiKey || provCfg.auth || provCfg.models);
        if (hasProfile || hasEnvKey || hasProvApi) {
            var models = CLOUD_MODELS[p.id] || [];
            models.forEach(function(m) { cloudModels.push(m); });
        }
    });
    if (cloudModels.length) {
        hasAny = true;
        var optgroup = document.createElement('optgroup');
        optgroup.label = '☁️ Cloud';
        cloudModels.forEach(function(cm) {
            var opt = document.createElement('option');
            opt.value = cm.value;
            opt.textContent = cm.label;
            if (cm.value === currentPrimary) opt.selected = true;
            optgroup.appendChild(opt);
            seenValues.add(cm.value);
        });
        sel.appendChild(optgroup);
    }
    // Add local Ollama models
    if (installedModels.length) {
        hasAny = true;
        var optgroup2 = document.createElement('optgroup');
        optgroup2.label = '💻 Locale (Ollama)';
        installedModels.forEach(function(m) {
            var val = 'ollama/' + m.name;
            var opt = document.createElement('option');
            opt.value = val;
            opt.textContent = m.name + ' (' + formatSize(m.size) + ')';
            if (val === currentPrimary) opt.selected = true;
            optgroup2.appendChild(opt);
            seenValues.add(val);
        });
        sel.appendChild(optgroup2);
    }
    if (!hasAny) {
        var emptyOpt = document.createElement('option');
        emptyOpt.value = '';
        emptyOpt.textContent = 'Nessun modello disponibile';
        sel.appendChild(emptyOpt);
    }
    if (currentPrimary && !seenValues.has(currentPrimary)) {
        var extraOpt = document.createElement('option');
        extraOpt.value = currentPrimary;
        extraOpt.textContent = currentPrimary + ' (config)';
        extraOpt.selected = true;
        sel.appendChild(extraOpt);
    }
}

async function setActiveModel(ollamaName) {
    var model = 'ollama/' + ollamaName;
    var ok = await gwPatchConfig({
        agents: { defaults: { model: { primary: model } } }
    });
    if (ok) {
        showToast('✅ Modello: ' + ollamaName + ' — il gateway si riavvia, attendi...');
        // UI refreshes after auto-reconnect
    }
}

async function setActiveModelFromSelect() {
    var sel = document.getElementById('active-model-select');
    var model = sel.value;
    if (!model) return;
    var ok = await gwPatchConfig({
        agents: { defaults: { model: { primary: model } } }
    });
    if (ok) {
        showToast('✅ Modello: ' + model + ' — ricarica la chat per vederlo');
        // UI refreshes after auto-reconnect
    }
}

function renderCurrentModel() {
    var el = document.getElementById('current-model');
    if (!el || !gwRawConfig) return;
    var primary = gwRawConfig?.agents?.defaults?.model?.primary || 'Nessuno configurato';
    el.textContent = primary;
}

async function showModelInfo(name) {
    try {
        var r = await fetch(OLLAMA_URL + '/api/show', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({name: name})
        });
        var data = await r.json();
        var info = '📋 ' + name + '\n';
        if (data.details) {
            if (data.details.family) info += 'Famiglia: ' + data.details.family + '\n';
            if (data.details.parameter_size) info += 'Parametri: ' + data.details.parameter_size + '\n';
            if (data.details.quantization_level) info += 'Quantizzazione: ' + data.details.quantization_level + '\n';
        }
        if (data.model_info) {
            var ctx = data.model_info['llama.context_length'] || data.model_info['general.context_length'];
            if (ctx) info += 'Contesto: ' + ctx + ' token\n';
        }
        alert(info);
    } catch(e) {
        showToast('Errore info: ' + e.message, true);
    }
}

// ---- Provider API Keys ----

var PROVIDERS = [
    { id: 'openai', name: 'OpenAI', profileKey: 'openai:default', envVar: 'OPENAI_API_KEY', link: 'https://platform.openai.com/api-keys' },
    { id: 'anthropic', name: 'Anthropic', profileKey: 'anthropic:default', envVar: 'ANTHROPIC_API_KEY', link: 'https://console.anthropic.com/settings/keys' },
    { id: 'groq', name: 'Groq', profileKey: 'groq:default', envVar: 'GROQ_API_KEY', link: 'https://console.groq.com/keys' },
    { id: 'google', name: 'Google (Gemini)', profileKey: 'google:default', envVar: 'GOOGLE_API_KEY', link: 'https://aistudio.google.com/apikey' }
];

function renderProviderCards() {
    var container = document.getElementById('provider-cards');
    if (!container) return;
    var profiles = gwRawConfig?.auth?.profiles || {};

    var envVars = gwRawConfig?.env || {};
    var providerConfigs = gwRawConfig?.models?.providers || {};
    container.innerHTML = PROVIDERS.map(function(p) {
        var hasProfile = !!profiles[p.profileKey];
        var hasEnvKey = !!envVars[p.envVar];
        var providerCfg = providerConfigs[p.id] || {};
        var hasProviderApi = !!(providerCfg.apiKey || providerCfg.auth || providerCfg.models);
        var isConfigured = hasProfile || hasEnvKey || hasProviderApi;
        var statusClass = isConfigured ? 'connected' : 'disconnected';
        var statusText = isConfigured ? '🟢 Configurato' : '⚪ Non configurato';
        var maskedKey = '';
        if (isConfigured) {
            var rawKey = envVars[p.envVar] || providerCfg.apiKey || '';
            if (rawKey && rawKey.length > 8) maskedKey = rawKey.substring(0, 6) + '...' + rawKey.substring(rawKey.length - 4);
            else if (rawKey) maskedKey = '••••••';
            else maskedKey = '✓ salvata';
        }
        return '<div class="provider-card">' +
            '<div class="provider-header">' +
            '<strong>' + p.name + '</strong>' +
            '<span class="' + statusClass + '" style="font-size:0.85rem;">' + statusText + '</span>' +
            '</div>' +
            (isConfigured ? '<p style="font-size:0.8rem; color:var(--pink); margin:0.3rem 0;">🔑 ' + maskedKey + '</p>' : '') +
            '<div class="key-input-row">' +
            '<input type="password" id="key-' + p.id + '" placeholder="' + (isConfigured ? 'Nuova key (sostituisce)' : 'API key ' + p.name) + '">' +
            '<button class="btn btn-pink btn-sm" onclick="saveProviderKey(\'' + p.id + '\')">Salva</button>' +
            (isConfigured ? '<button class="btn btn-outline btn-sm" onclick="removeProvider(\'' + p.id + '\')" title="Rimuovi">🗑️</button>' : '') +
            '</div>' +
            '<p style="font-size:0.75rem; margin-top:0.3rem; color:var(--dim);">' +
            '<a href="' + p.link + '" target="_blank" style="color:var(--pink);">Ottieni API key →</a>' +
            '</p></div>';
    }).join('');
}

async function saveProviderKey(providerId) {
    var prov = PROVIDERS.find(function(p){ return p.id === providerId; });
    if (!prov) return;
    var input = document.getElementById('key-' + providerId);
    var key = input.value.trim();
    if (!key) { showToast('Inserisci una API key!', true); return; }

    // OpenClaw schema:
    // auth.profiles.{profileKey} = { provider, mode: "api_key" }
    // env.{ENVVAR} = "the-key-value"
    // No models.providers entry needed for built-in providers (anthropic, openai, google, groq)
    var patch = {
        env: {},
        auth: { profiles: {} }
    };
    patch.env[prov.envVar] = key;
    patch.auth.profiles[prov.profileKey] = {
        provider: providerId,
        mode: 'api_key'
    };

    var ok = await gwPatchConfig(patch);
    if (ok) {
        showToast('✅ ' + prov.name + ' configurato!');
        input.value = '';
        renderProviderCards();
        renderModelDropdown();
    }
}

async function removeProvider(providerId) {
    var prov = PROVIDERS.find(function(p){ return p.id === providerId; });
    if (!prov) return;
    if (!confirm('Rimuovere ' + prov.name + '?')) return;

    // Remove from config by setting to empty/null
    // config.patch merge can't delete keys, but we can overwrite
    // Remove auth profile + env var
    if (!gwBaseHash) await gwLoadConfig();
    try {
        var current = JSON.parse(JSON.stringify(gwRawConfig || {}));
        if (current.auth?.profiles?.[prov.profileKey]) {
            delete current.auth.profiles[prov.profileKey];
        }
        // Remove the env var too
        if (current.env?.[prov.envVar]) {
            delete current.env[prov.envVar];
        }
        // Use config.apply (full overwrite) for deletions
        await gwSend('config.apply', { baseHash: gwBaseHash, raw: JSON.stringify(current) });
        await gwLoadConfig();
        showToast('🗑️ ' + prov.name + ' rimosso');
        renderProviderCards();
        renderModelDropdown();
    } catch(e) {
        showToast('Errore: ' + e.message, true);
    }
}

// ---- Ollama Install/Remove ----
function cancelInstall() {
    if (pullAbortController) {
        pullAbortController.abort();
        pullAbortController = null;
        showToast('⛔ Download annullato');
    }
}

async function installModel() {
    var input = document.getElementById('install-model-name');
    var name = input.value.trim();
    if (!name) { showToast('Inserisci un nome modello!', true); return; }

    var btn = document.getElementById('btn-install');
    var btnCancel = document.getElementById('btn-cancel');
    var output = document.getElementById('install-output');
    pullAbortController = new AbortController();
    btn.disabled = true;
    btn.innerHTML = '⏳ Scaricando...<span class="spinner"></span>';
    if (btnCancel) btnCancel.style.display = 'inline-flex';
    output.className = 'output-box visible';
    output.textContent = 'Avvio download di ' + name + '...\n';

    try {
        var r = await fetch(OLLAMA_URL + '/api/pull', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: name, stream: true }),
            signal: pullAbortController.signal
        });
        var reader = r.body.getReader();
        var decoder = new TextDecoder();
        var lastPercent = '';
        while (true) {
            var chunk = await reader.read();
            if (chunk.done) break;
            var text = decoder.decode(chunk.value);
            var lines = text.split('\n').filter(function(l){ return l.trim(); });
            for (var i = 0; i < lines.length; i++) {
                try {
                    var j = JSON.parse(lines[i]);
                    if (j.status) {
                        if (j.total && j.completed) {
                            var pct = Math.round(j.completed / j.total * 100);
                            var pctStr = pct + '%';
                            if (pctStr !== lastPercent) {
                                output.textContent += j.status + ' ' + pctStr + '\n';
                                lastPercent = pctStr;
                            }
                        } else {
                            output.textContent += j.status + '\n';
                        }
                        output.scrollTop = output.scrollHeight;
                    }
                    if (j.error) {
                        output.textContent += '❌ ERRORE: ' + j.error + '\n';
                        showToast('Errore: ' + j.error, true);
                    }
                } catch(e) {}
            }
        }
        output.textContent += '\n✅ Download completato!\n';
        showToast('✅ ' + name + ' installato!');
        input.value = '';
        await refreshModels();
    } catch(e) {
        if (e.name === 'AbortError') {
            output.textContent += '\n⛔ Download annullato dall\'utente.\n';
        } else {
            output.textContent += '\n❌ Errore: ' + e.message + '\n';
            showToast('Errore download: ' + e.message, true);
        }
    } finally {
        pullAbortController = null;
        btn.disabled = false;
        btn.textContent = '⬇️ Installa';
        if (btnCancel) btnCancel.style.display = 'none';
    }
}

async function removeModel() {
    var sel = document.getElementById('remove-selector');
    var name = sel.value;
    if (!name) { showToast('Seleziona un modello!', true); return; }
    if (!confirm('Rimuovere ' + name + '? Dovrai riscaricare se ti serve di nuovo.')) return;
    try {
        await fetch(OLLAMA_URL + '/api/delete', {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: name })
        });
        showToast('🗑️ ' + name + ' rimosso');
        await refreshModels();
    } catch(e) {
        showToast('Errore: ' + e.message, true);
    }
}

// ---- Init ----
document.addEventListener('DOMContentLoaded', async function() {
    // Get auth token: URL param > control-ui localStorage > null
    var params = new URLSearchParams(location.search);
    gwAuthToken = params.get('token') || null;
    // Try known control-ui localStorage keys for auth token
    if (!gwAuthToken) {
        try {
            var settings = localStorage.getItem('openclaw-settings');
            if (settings) {
                var parsed = JSON.parse(settings);
                gwAuthToken = parsed.gatewayToken || parsed.token || null;
            }
        } catch(e) {}
    }
    if (!gwAuthToken) gwAuthToken = localStorage.getItem('openclaw-gateway-token') || null;

    // Bind buttons
    document.getElementById('btn-refresh').addEventListener('click', refreshModels);
    document.getElementById('btn-install').addEventListener('click', installModel);
    document.getElementById('btn-remove').addEventListener('click', removeModel);
    var modelSelect = document.getElementById('active-model-select');
    if (modelSelect) modelSelect.addEventListener('change', setActiveModelFromSelect);

    // Connect to gateway
    var gwOk = await gwConnect();
    if (gwOk) {
        await gwLoadConfig();
        if (gwRawConfig) {
            console.log('[model-manager] Config loaded. env keys:', Object.keys(gwRawConfig.env || {}));
            console.log('[model-manager] auth.profiles:', Object.keys(gwRawConfig.auth?.profiles || {}));
            console.log('[model-manager] primary model:', gwRawConfig.agents?.defaults?.model?.primary || 'none');
        } else {
            console.warn('[model-manager] gwLoadConfig returned null');
        }
        renderCurrentModel();
        renderProviderCards();
    } else {
        console.warn('[model-manager] Gateway connection failed — provider cards will show defaults');
    }

    // Load Ollama models (also calls renderModelDropdown)
    await refreshModels();
});
