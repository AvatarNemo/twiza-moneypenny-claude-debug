// ---- Configuration ----
const OLLAMA_URL = 'http://localhost:11434';
let installedModels = [];
let activeModel = '';

// ---- Toast ----
function showToast(msg, isError) {
    var t = document.getElementById('toast');
    t.textContent = msg;
    t.className = 'toast visible' + (isError ? ' error' : '');
    setTimeout(function(){ t.className = 'toast'; }, 3000);
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
    if (!online) {
        document.getElementById('installed-models').innerHTML = '<p style="color:var(--red);">Ollama non raggiungibile. Assicurati che sia in esecuzione.</p>';
        return;
    }
    try {
        var r = await fetch(OLLAMA_URL + '/api/tags');
        var data = await r.json();
        installedModels = (data.models || []).sort(function(a,b){ return a.name.localeCompare(b.name); });
        document.getElementById('models-count').textContent = installedModels.length;
        renderInstalledModels();
        renderSelectors();
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
        container.innerHTML = '<p style="color:var(--dim);">Nessun modello installato. Installa il tuo primo modello qui sotto!</p>';
        return;
    }
    container.innerHTML = installedModels.map(function(m) {
        var isDefault = m.name === 'gemma3:4b';
        var isActive = m.name === activeModel;
        return '<div class="model-item ' + (isActive ? 'active' : '') + '">' +
            '<div>' +
            '<span class="model-name">' + m.name + '</span>' +
            (isDefault ? '<span class="model-tag default">DEFAULT</span>' : '') +
            (isActive ? '<span class="model-tag" style="border-color:var(--green);color:var(--green);">ATTIVO</span>' : '') +
            '<br><span class="model-size">' + formatSize(m.size) + '</span>' +
            '</div>' +
            '<button class="btn btn-outline btn-sm" data-quick-apply="' + m.name + '"' + (isActive ? ' disabled' : '') + '>' +
            (isActive ? '✅ In uso' : '▶️ Usa') +
            '</button></div>';
    }).join('');
}

function renderSelectors() {
    var sel = document.getElementById('model-selector');
    var rem = document.getElementById('remove-selector');
    sel.innerHTML = '<option value="">— Seleziona modello —</option>' +
        installedModels.map(function(m){ return '<option value="' + m.name + '"' + (m.name === activeModel ? ' selected' : '') + '>' + m.name + ' (' + formatSize(m.size) + ')</option>'; }).join('');
    rem.innerHTML = '<option value="">— Seleziona modello da rimuovere —</option>' +
        installedModels.map(function(m){ return '<option value="' + m.name + '">' + m.name + ' (' + formatSize(m.size) + ')</option>'; }).join('');
}

function quickApply(name) {
    activeModel = name;
    document.getElementById('active-model').textContent = name;
    renderInstalledModels();
    renderSelectors();
    showToast('✅ Modello attivo: ' + name);
}

function applyModel() {
    var sel = document.getElementById('model-selector');
    if (sel.value) quickApply(sel.value);
}

async function installModel() {
    var input = document.getElementById('install-model-name');
    var name = input.value.trim();
    if (!name) { showToast('Inserisci un nome modello!', true); return; }

    var btn = document.getElementById('btn-install');
    var output = document.getElementById('install-output');
    btn.disabled = true;
    btn.innerHTML = '⏳ Scaricando...<span class="spinner"></span>';
    output.className = 'output-box visible';
    output.textContent = 'Avvio download di ' + name + '...\n';

    try {
        var r = await fetch(OLLAMA_URL + '/api/pull', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: name, stream: true })
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
        output.textContent += '\n❌ Errore: ' + e.message + '\n';
        showToast('Errore download: ' + e.message, true);
    } finally {
        btn.disabled = false;
        btn.textContent = '⬇️ Installa';
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

// ---- Provider Key Management ----
var PROVIDERS = {
    anthropic: { prefix: 'sk-ant-', configKey: 'ANTHROPIC_API_KEY' },
    openai: { prefix: 'sk-', configKey: 'OPENAI_API_KEY' },
    gemini: { prefix: 'AIzaSy', configKey: 'GEMINI_API_KEY' },
    groq: { prefix: 'gsk_', configKey: 'GROQ_API_KEY' },
    perplexity: { prefix: 'pplx-', configKey: 'PERPLEXITY_API_KEY' },
    elevenlabs: { prefix: '', configKey: 'ELEVENLABS_API_KEY' }
};

function checkProviders() {
    for (var name in PROVIDERS) {
        var dot = document.getElementById('dot-' + name);
        var status = document.getElementById('status-' + name);
        if (dot && status) {
            dot.className = 'dot dot-gray';
            status.textContent = 'Inserisci la API key per configurare';
        }
    }
}

function saveKey(provider) {
    var input = document.getElementById('key-' + provider);
    var key = input.value.trim();
    if (!key) { showToast('Inserisci una API key!', true); return; }
    var dot = document.getElementById('dot-' + provider);
    var status = document.getElementById('status-' + provider);
    localStorage.setItem('moneypenny-key-' + provider, key);
    dot.className = 'dot dot-green';
    status.textContent = '✅ Key salvata (locale)';
    input.value = '';
    input.placeholder = '••••••••' + key.slice(-4);
    showToast('✅ API key ' + provider.charAt(0).toUpperCase() + provider.slice(1) + ' salvata!');
}

function loadSavedKeys() {
    for (var name in PROVIDERS) {
        var saved = localStorage.getItem('moneypenny-key-' + name);
        if (saved) {
            var dot = document.getElementById('dot-' + name);
            var status = document.getElementById('status-' + name);
            var input = document.getElementById('key-' + name);
            if (dot) dot.className = 'dot dot-green';
            if (status) status.textContent = '✅ Key configurata';
            if (input) input.placeholder = '••••••••' + saved.slice(-4);
        }
    }
}

// ---- Init & Event Binding ----
document.addEventListener('DOMContentLoaded', async function() {
    // Bind buttons
    document.getElementById('btn-apply-model').addEventListener('click', applyModel);
    document.getElementById('btn-refresh').addEventListener('click', refreshModels);
    document.getElementById('btn-install').addEventListener('click', installModel);
    document.getElementById('btn-remove').addEventListener('click', removeModel);

    // Bind save-key buttons via data attribute
    var saveButtons = document.querySelectorAll('[data-save-key]');
    for (var i = 0; i < saveButtons.length; i++) {
        (function(btn) {
            btn.addEventListener('click', function() { saveKey(btn.getAttribute('data-save-key')); });
        })(saveButtons[i]);
    }

    // Event delegation for quick-apply buttons (dynamically rendered)
    document.getElementById('installed-models').addEventListener('click', function(e) {
        var btn = e.target.closest('[data-quick-apply]');
        if (btn && !btn.disabled) quickApply(btn.getAttribute('data-quick-apply'));
    });

    checkProviders();
    loadSavedKeys();
    await refreshModels();
});
