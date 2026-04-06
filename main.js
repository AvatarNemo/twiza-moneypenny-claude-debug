const { app, BrowserWindow, ipcMain, Notification, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn, execSync } = require('child_process');
const http = require('http');
const { createTray, updateTrayStatus } = require('./tray');
const { generateConfig, generateTemplates, deployToWSL } = require('./config-generator');
const { startAutoCheck, stopAutoCheck, checkForUpdates, getCurrentVersion } = require('./updater');

// ============================================================
// App Identity — show "TWIZA Moneypenny" in Task Manager, not "Electron"
// ============================================================
app.setName('TWIZA Moneypenny');

// ============================================================
// Single Instance Lock
// ============================================================

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
  process.exit(0);
}

// ============================================================
// State
// ============================================================

let onboardingWindow = null;
let wizardWindow = null;
let chatWindow = null;
let settingsWindow = null;
let docsWindow = null;
let gatewayProcess = null;
let isGatewayRunning = false;
let gatewayStarting = false;
let healthCheckTimer = null;
let isQuitting = false;

const WEBCHAT_PORT = 18789;
const WSL_EXE = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'wsl.exe');
const PS_EXE = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
const GATEWAY_PORT = 1337;
const WSL_DISTRO = 'TWIZA';
const WSL_USER = 'twiza';
const HEALTH_CHECK_INTERVAL = 30000;
const GATEWAY_STOP_TIMEOUT = 10000;
const OPENCLAW_CONFIG_PATH = '/home/twiza/.openclaw/openclaw.json';

// ============================================================
// Window state persistence
// ============================================================

const stateFile = path.join(app.getPath('userData'), 'window-state.json');

function loadWindowState(name, defaults) {
  try {
    const all = JSON.parse(fs.readFileSync(stateFile, 'utf-8'));
    return { ...defaults, ...(all[name] || {}) };
  } catch {
    return defaults;
  }
}

function saveWindowState(name, state) {
  let all = {};
  try { all = JSON.parse(fs.readFileSync(stateFile, 'utf-8')); } catch {}
  all[name] = state;
  try { fs.writeFileSync(stateFile, JSON.stringify(all, null, 2)); } catch {}
}

// ============================================================
// Settings persistence
// ============================================================

const settingsFile = path.join(app.getPath('userData'), 'twiza-settings.json');

function loadSettings() {
  try {
    return JSON.parse(fs.readFileSync(settingsFile, 'utf-8'));
  } catch {
    return { autoStartGateway: false, firstRunComplete: false, autoUpdate: false };
  }
}

function saveSettings(s) {
  try { fs.writeFileSync(settingsFile, JSON.stringify(s, null, 2)); } catch {}
}

// ============================================================
// WSL Detection
// ============================================================

function isWslAvailable() {
  // wsl --status is unreliable (returns error even when WSL works)
  // Instead, try to actually run something in WSL
  try {
    execSync(WSL_EXE + ' --list --quiet', { stdio: 'pipe', timeout: 10000 });
    return true;
  } catch {
    // Even wsl --list can fail if no distros installed yet
    // Check if the wsl.exe binary exists at all
    try {
      execSync('where wsl.exe', { stdio: 'pipe', timeout: 5000 });
      return true; // WSL binary exists, just no distros yet
    } catch {
      return false;
    }
  }
}

function isWslDistroInstalled() {
  try {
    const output = execSync(WSL_EXE + ' -l -q', { stdio: 'pipe', timeout: 10000 }).toString();
    // wsl -l outputs UTF-16LE — clean it
    const clean = output.replace(/\0/g, '').trim();
    return clean.split(/\r?\n/).some(line => line.trim() === WSL_DISTRO);
  } catch {
    return false;
  }
}

function configExistsInWsl() {
  try {
    execSync(`${WSL_EXE} -d ${WSL_DISTRO} -u ${WSL_USER} -- test -f ${OPENCLAW_CONFIG_PATH}`, {
      stdio: 'pipe',
      timeout: 10000,
    });
    return true;
  } catch {
    return false;
  }
}

function showWslMissingDialog() {
  dialog.showMessageBoxSync({
    type: 'error',
    title: 'WSL2 Required',
    message: 'Windows Subsystem for Linux (WSL2) is not available.',
    detail:
      'TWIZA requires WSL2 to run the AI gateway.\n\n' +
      'To install WSL2:\n' +
      '1. Open PowerShell as Administrator\n' +
      '2. Run: wsl --install\n' +
      '3. Restart your computer\n' +
      '4. Launch TWIZA again\n\n' +
      'For more info: https://learn.microsoft.com/en-us/windows/wsl/install',
    buttons: ['OK'],
  });
}

// ============================================================
// Utility
// ============================================================

function getIconPath() {
  // Use .ico on Windows for best taskbar/window icon support
  const icoPath = path.join(__dirname, '..', 'assets', 'branding', 'twiza-icon.ico');
  if (fs.existsSync(icoPath)) return icoPath;
  // Fallback to PNG (must be actual PNG, not renamed JPEG!)
  return path.join(__dirname, '..', 'assets', 'branding', 'twiza-icon.png');
}

function showNotification(title, body) {
  try {
    if (Notification.isSupported()) {
      new Notification({ title, body, icon: getIconPath() }).show();
    }
  } catch {}
}

// ============================================================
// Windows
// ============================================================

function createOnboardingWindow() {
  if (onboardingWindow) { onboardingWindow.focus(); return; }

  onboardingWindow = new BrowserWindow({
    width: 860,
    height: 640,
    resizable: false,
    frame: false,
    backgroundColor: '#010205',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: getIconPath(),
    show: false,
  });

  const htmlPath = path.join(__dirname, 'onboarding', 'index.html');
  console.log('[onboarding] Loading:', htmlPath, 'exists:', fs.existsSync(htmlPath));

  onboardingWindow.webContents.on('did-fail-load', (_e, code, desc) => {
    console.error('[onboarding] FAIL LOAD:', code, desc);
  });
  onboardingWindow.webContents.on('console-message', (_e, _level, msg) => {
    console.log('[onboarding:console]', msg);
  });

  onboardingWindow.loadFile(htmlPath);
  onboardingWindow.once('ready-to-show', () => {
    onboardingWindow.show();
  });
  // Safety: show window after 3s even if ready-to-show didn't fire
  setTimeout(() => {
    if (onboardingWindow && !onboardingWindow.isDestroyed() && !onboardingWindow.isVisible()) {
      console.log('[onboarding] Force-showing after timeout');
      onboardingWindow.show();
    }
  }, 3000);
  onboardingWindow.on('closed', () => { onboardingWindow = null; });
}

function createWizardWindow() {
  if (wizardWindow) { wizardWindow.focus(); return; }

  const state = loadWindowState('wizard', { width: 1100, height: 780 });
  wizardWindow = new BrowserWindow({
    ...state,
    minWidth: 1000,
    minHeight: 700,
    resizable: false,
    frame: false,
    transparent: false,
    backgroundColor: '#010205',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: getIconPath(),
    show: false,
  });

  const wizardHtml = path.join(__dirname, 'wizard', 'index.html');
  console.log('[wizard] Loading:', wizardHtml, 'exists:', fs.existsSync(wizardHtml));
  wizardWindow.loadFile(wizardHtml);
  wizardWindow.webContents.on('did-fail-load', (_e, code, desc) => {
    console.error('[wizard] FAIL LOAD:', code, desc);
  });
  wizardWindow.once('ready-to-show', () => wizardWindow.show());
  // Safety: show after 3s even if ready-to-show didn't fire
  setTimeout(() => {
    if (wizardWindow && !wizardWindow.isDestroyed() && !wizardWindow.isVisible()) {
      console.log('[wizard] Force-showing after timeout');
      wizardWindow.show();
    }
  }, 3000);
  wizardWindow.on('closed', () => { wizardWindow = null; });
}

function openChatWindow() {
  if (chatWindow) { chatWindow.focus(); return; }

  const state = loadWindowState('chat', { width: 1100, height: 750 });
  chatWindow = new BrowserWindow({
    ...state,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#010205',
    minWidth: 480,
    minHeight: 400,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: getIconPath(),
    show: false,
  });

  // Show a loading splash while waiting for gateway webchat
  const splashHtml = `data:text/html;charset=utf-8,
    <html><head><style>
      body { margin:0; background:#010205; display:flex; align-items:center; justify-content:center; height:100vh; font-family:system-ui; color:#888; }
      .loader { text-align:center; }
      .spinner { width:40px; height:40px; border:3px solid #333; border-top:3px solid #B4009E; border-radius:50%; animation:spin 1s linear infinite; margin:0 auto 16px; }
      @keyframes spin { to { transform:rotate(360deg); } }
      p { font-size:14px; }
    </style></head><body><div class="loader"><div class="spinner"></div><p>Starting Moneypenny...</p></div></body></html>`;

  chatWindow.loadURL(splashHtml);
  chatWindow.once('ready-to-show', () => chatWindow.show());

  // Retry loading webchat until it responds
  let attempts = 0;
  const maxAttempts = 90; // 90 seconds max — gateway + Ollama can take a while on first boot
  const tryLoadWebchat = () => {
    attempts++;
    const testReq = http.get(`http://127.0.0.1:${WEBCHAT_PORT}`, (res) => {
      res.resume();
      if (res.statusCode < 400 && chatWindow && !chatWindow.isDestroyed()) {
        // Build webchat URL with locale from saved wizard state
        let chatUrl = `http://127.0.0.1:${WEBCHAT_PORT}/chat?session=main`;
        try {
          const wizState = JSON.parse(fs.readFileSync(
            path.join(app.getPath('userData'), 'wizard-state.json'), 'utf-8'));
          const wizLang = wizState.lang || wizState.language;
          if (wizLang && wizLang !== 'en') {
            chatUrl += `&locale=${encodeURIComponent(wizLang)}`;
          }
        } catch {}
        
        // Auto-restore branding (in case OpenClaw was updated)
        try {
          const wslWorkspacePath = '/home/twiza/.openclaw/workspace';
          const brandingScript = path.posix.join(wslWorkspacePath, 'branding', 'restore-branding.sh');
          const checkResult = require('child_process').spawnSync('wsl', ['-d', 'TWIZA', '--', 'bash', brandingScript], { timeout: 30000 });
          if (checkResult.status !== 0) {
            console.log('[Branding] Restore script failed or not found, skipping');
          } else {
            console.log('[Branding] Restore completed');
          }
        } catch (e) {
          console.log('[Branding] Error:', e.message);
        }
        
        chatWindow.loadURL(chatUrl);
        // Hide layout toggle, inject locale, and inject custom CSS after page loads
        chatWindow.webContents.on('did-finish-load', () => {
          chatWindow.webContents.insertCSS(`
            /* Hide layout/view switcher button */
            [title*="layout" i], [title*="Layout" i], [aria-label*="layout" i],
            button[title*="view" i]:has(svg) { display: none !important; }
          `).catch(() => {});
          // Force locale into localStorage if wizard chose a non-English language
          try {
            const wizState2 = JSON.parse(fs.readFileSync(
              path.join(app.getPath('userData'), 'wizard-state.json'), 'utf-8'));
            const forceLang = wizState2.lang || wizState2.language;
            if (forceLang && forceLang !== 'en') {
              chatWindow.webContents.executeJavaScript(
                `if(!localStorage.getItem('openclaw.i18n.locale')){` +
                `localStorage.setItem('openclaw.i18n.locale','${forceLang}');` +
                `location.reload();}`
              ).catch(() => {});
            }
          } catch {}
        });
      }
    });
    testReq.on('error', () => {
      if (attempts < maxAttempts && chatWindow && !chatWindow.isDestroyed()) {
        setTimeout(tryLoadWebchat, 1000);
      } else if (chatWindow && !chatWindow.isDestroyed()) {
        // Show error page after all retries failed
        const errorHtml = `data:text/html;charset=utf-8,
          <html><head><style>
            body { margin:0; background:#010205; display:flex; align-items:center; justify-content:center; height:100vh; font-family:system-ui; color:#ccc; }
            .box { text-align:center; max-width:500px; padding:40px; }
            h2 { color:#B4009E; margin-bottom:16px; }
            p { font-size:14px; line-height:1.6; color:#888; }
            button { margin-top:20px; padding:10px 24px; background:#B4009E; color:white; border:none; border-radius:6px; cursor:pointer; font-size:14px; }
            button:hover { background:#9a0086; }
          </style></head><body><div class="box">
            <h2>Gateway non raggiungibile</h2>
            <p>Moneypenny non riesce ad avviarsi. Potrebbe essere necessario completare l'installazione.</p>
            <p style="color:#666;font-size:12px;">Porta: ${WEBCHAT_PORT} | Tentativi: ${attempts}</p>
            <button onclick="location.reload()">Riprova</button>
          </div></body></html>`;
        chatWindow.loadURL(errorHtml);
      }
    });
    testReq.setTimeout(2000, () => testReq.destroy());
  };

  // Start trying after a short delay
  setTimeout(tryLoadWebchat, 2000);

  chatWindow.on('close', () => {
    const bounds = chatWindow.getBounds();
    saveWindowState('chat', bounds);
  });
  chatWindow.on('closed', () => { chatWindow = null; });
}

function openSettingsWindow() {
  if (settingsWindow) { settingsWindow.focus(); return; }

  const state = loadWindowState('settings', { width: 960, height: 700 });
  settingsWindow = new BrowserWindow({
    ...state,
    frame: false,
    backgroundColor: '#010205',
    minWidth: 600,
    minHeight: 400,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: getIconPath(),
    show: false,
  });

  settingsWindow.loadFile(path.join(__dirname, 'settings', 'index.html'));
  settingsWindow.once('ready-to-show', () => settingsWindow.show());
  settingsWindow.on('close', () => {
    const bounds = settingsWindow.getBounds();
    saveWindowState('settings', bounds);
  });
  settingsWindow.on('closed', () => { settingsWindow = null; });
}

let modelsWindow = null;
function openModelsWindow() {
  if (modelsWindow) { modelsWindow.focus(); return; }
  const state = loadWindowState('models', { width: 960, height: 700 });
  modelsWindow = new BrowserWindow({
    ...state,
    frame: false,
    backgroundColor: '#010205',
    minWidth: 600,
    minHeight: 400,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: getIconPath(),
    show: false,
  });
  modelsWindow.loadFile(path.join(__dirname, 'models', 'index.html'));
  modelsWindow.once('ready-to-show', () => modelsWindow.show());
  modelsWindow.on('close', () => {
    const bounds = modelsWindow.getBounds();
    saveWindowState('models', bounds);
  });
  modelsWindow.on('closed', () => { modelsWindow = null; });
}

function openDocsWindow() {
  if (docsWindow) { docsWindow.focus(); return; }

  const state = loadWindowState('docs', { width: 1000, height: 700 });
  docsWindow = new BrowserWindow({
    ...state,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#0a0a0a',
    minWidth: 800,
    minHeight: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: getIconPath(),
    show: false,
  });

  docsWindow.loadFile(path.join(__dirname, '..', 'docs-moneypenny', 'index.html'));
  docsWindow.once('ready-to-show', () => docsWindow.show());
  docsWindow.on('close', () => {
    const bounds = docsWindow.getBounds();
    saveWindowState('docs', bounds);
  });
  docsWindow.on('closed', () => { docsWindow = null; });
}

function openDocsPdf() {
  // Open the local PDF guide with the system default PDF viewer
  const { shell } = require('electron');
  // Look for the PDF in the docs/ directory relative to the app
  let docsDir;
  if (process.resourcesPath) {
    docsDir = path.join(path.dirname(path.dirname(process.resourcesPath)), 'docs');
  }
  if (!docsDir || !fs.existsSync(docsDir)) {
    let searchDir = path.dirname(app.getPath('exe'));
    for (let i = 0; i < 3; i++) {
      const candidate = path.join(searchDir, 'docs');
      if (fs.existsSync(candidate)) { docsDir = candidate; break; }
      searchDir = path.dirname(searchDir);
    }
  }
  const pdfPath = docsDir ? path.join(docsDir, 'TWIZA-Moneypenny-Guida.pdf') : null;
  if (pdfPath && fs.existsSync(pdfPath)) {
    shell.openPath(pdfPath);
  } else {
    // Fallback: open HTML docs window
    openDocsWindow();
  }
}

// ============================================================
// Gateway Process Management
// ============================================================

function repairOpenClawIfNeeded() {
  // Check if dist/entry.js exists in WSL; if not, re-copy from bundle
  try {
    const check = execSync(`${WSL_EXE} -d ${WSL_DISTRO} -u root -- test -f /usr/local/lib/node_modules/openclaw/dist/entry.js && echo ok || echo missing`, { timeout: 10000 }).toString().trim();
    if (check !== 'missing') return;

    console.log('[gateway] dist/entry.js missing — attempting repair...');

    // Strategy 1: Find openclaw-full.tar.gz (pre-built, most reliable)
    const settings = loadSettings();
    const searchPaths = [
      settings.installSourceDir,  // Saved during install
      path.join(path.dirname(path.dirname(process.resourcesPath || '')), 'components'),
      path.join(path.dirname(app.getPath('exe')), '..', 'components'),
      path.join(path.dirname(app.getPath('exe')), 'components'),
    ].filter(Boolean);

    let tgzFile = null;
    for (const sp of searchPaths) {
      const candidate = path.join(sp, 'openclaw-full.tar.gz');
      try { if (fs.existsSync(candidate)) { tgzFile = candidate; break; } } catch {}
    }

    if (tgzFile) {
      console.log('[gateway] Found tarball:', tgzFile);
      const wslPath = tgzFile.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, d) => '/mnt/' + d.toLowerCase());
      // Copy tarball to /tmp (single file = reliable cross-fs), then extract
      execSync(`${WSL_EXE} -d ${WSL_DISTRO} -u root -- bash -c "cat '${wslPath}' > /tmp/oc-repair.tar.gz && rm -rf /usr/local/lib/node_modules/openclaw && tar xzf /tmp/oc-repair.tar.gz -C /usr/local/lib/node_modules && rm /tmp/oc-repair.tar.gz && chmod +x /usr/local/lib/node_modules/openclaw/openclaw.mjs && ln -sf /usr/local/lib/node_modules/openclaw/openclaw.mjs /usr/local/bin/openclaw && chmod +x /usr/local/bin/openclaw && sync"`, { timeout: 120000 });
      console.log('[gateway] OpenClaw repaired from tarball');
      return;
    }

    // Strategy 2: Find dist tarball only
    let distTgz = null;
    for (const sp of searchPaths) {
      const candidate = path.join(sp, 'openclaw-dist.tar.gz');
      try { if (fs.existsSync(candidate)) { distTgz = candidate; break; } } catch {}
    }

    if (distTgz) {
      console.log('[gateway] Found dist tarball:', distTgz);
      const wslPath = distTgz.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, d) => '/mnt/' + d.toLowerCase());
      execSync(`${WSL_EXE} -d ${WSL_DISTRO} -u root -- bash -c "cat '${wslPath}' > /tmp/oc-dist.tar.gz && tar xzf /tmp/oc-dist.tar.gz -C /usr/local/lib/node_modules/openclaw && rm /tmp/oc-dist.tar.gz && sync"`, { timeout: 60000 });
      console.log('[gateway] dist/ repaired from dist tarball');
      return;
    }

    // Strategy 3: npm install as last resort (requires internet)
    console.error('[gateway] No tarball found — trying npm install...');
    try {
      execSync(`${WSL_EXE} -d ${WSL_DISTRO} -u root -- bash -c "npm install -g openclaw 2>&1 | tail -5"`, { timeout: 120000 });
      console.log('[gateway] OpenClaw installed via npm');
    } catch (npmErr) {
      console.error('[gateway] All repair methods failed:', npmErr.message);
    }
  } catch (e) {
    console.error('[gateway] Repair check failed:', e.message);
  }
}

async function startGateway() {
  if (gatewayProcess || gatewayStarting) return Promise.resolve(false);
  gatewayStarting = true;
  updateTrayStatus('starting');

  // Pre-flight: ensure OpenClaw dist/entry.js exists
  try { repairOpenClawIfNeeded(); } catch (e) { console.error('[gateway] repair error:', e.message); }

  // Pre-flight: ensure Ollama is running and healthy (may not have systemd service after reboot)
  try {
    const ollamaStartScript = `
      # Ensure Ollama environment is set
      export OLLAMA_HOST=127.0.0.1:11434
      export OLLAMA_MODELS=\${HOME}/.ollama/models
      # Try to start via systemd first, then fallback to manual
      if ! pgrep -x ollama > /dev/null 2>&1; then
        if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
          sudo systemctl start ollama 2>/dev/null && echo "OLLAMA_STARTED_SYSTEMD" || true
        fi
        # If systemd didn't start it, start manually
        if ! pgrep -x ollama > /dev/null 2>&1; then
          OLLAMA_HOST=127.0.0.1:11434 OLLAMA_MODELS=\${HOME}/.ollama/models nohup ollama serve > /tmp/ollama.log 2>&1 &
          echo "OLLAMA_STARTED_MANUAL"
        fi
      else
        echo "OLLAMA_ALREADY_RUNNING"
      fi
      # Wait up to 15 seconds for Ollama to be ready
      for i in $(seq 1 15); do
        if curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
          echo "OLLAMA_READY"
          exit 0
        fi
        sleep 1
      done
      echo "OLLAMA_TIMEOUT"
      exit 1
    `;
    await new Promise((resolve) => {
      const ollamaCheck = spawn(WSL_EXE, [
        '-d', WSL_DISTRO, '-u', WSL_USER, '--',
        'bash', '-lc', ollamaStartScript
      ], { stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true, timeout: 20000 });
      let out = '';
      ollamaCheck.stdout.on('data', (d) => { out += d.toString(); });
      ollamaCheck.on('close', () => {
        console.log('[gateway] ollama pre-flight:', out.trim());
        resolve();
      });
      ollamaCheck.on('error', () => resolve());
    });
  } catch (e) { console.error('[gateway] ollama pre-start error:', e.message); }

  return new Promise((resolve) => {
    try {
      gatewayProcess = spawn(WSL_EXE, [
        '-d', WSL_DISTRO, '-u', WSL_USER, '--',
        'bash', '-lc', 'openclaw gateway'
      ], {
        stdio: ['ignore', 'pipe', 'pipe'],
        windowsHide: true,
      });

      let resolved = false;
      const finish = (success) => {
        if (resolved) return;
        resolved = true;
        resolve(success);
      };

      gatewayProcess.stdout.on('data', (d) => {
        const text = d.toString();
        console.log('[gateway:out]', text.trimEnd());

        if (!isGatewayRunning && /listening|ready|started|running/i.test(text)) {
          isGatewayRunning = true;
          gatewayStarting = false;
          updateTrayStatus('online');
          showNotification('TWIZA Agent', '🟢 Gateway is online');
          startHealthCheck();
          finish(true);
        }
      });

      gatewayProcess.stderr.on('data', (d) => {
        const text = d.toString();
        console.error('[gateway:err]', text.trimEnd());
        // Some tools log to stderr normally — don't treat as fatal
      });

      gatewayProcess.on('error', (err) => {
        console.error('[gateway] spawn error:', err.message);
        gatewayProcess = null;
        isGatewayRunning = false;
        gatewayStarting = false;
        updateTrayStatus('error');
        showNotification('TWIZA Agent', '❌ Failed to start gateway');
        finish(false);
      });

      gatewayProcess.on('close', (code) => {
        console.log(`[gateway] exited with code ${code}`);
        gatewayProcess = null;
        const wasRunning = isGatewayRunning;
        isGatewayRunning = false;
        gatewayStarting = false;
        updateTrayStatus('offline');
        stopHealthCheck();
        if (wasRunning && !isQuitting) {
          showNotification('TWIZA Agent', '🔴 Gateway stopped unexpectedly');
        }
        finish(false);
      });

      // Timeout: if not detected as running after 20s, assume it started (some builds don't print "ready")
      setTimeout(() => {
        if (gatewayStarting && gatewayProcess) {
          isGatewayRunning = true;
          gatewayStarting = false;
          updateTrayStatus('online');
          startHealthCheck();
          finish(true);
        }
      }, 20000);

    } catch (err) {
      console.error('[gateway] failed to start:', err);
      gatewayStarting = false;
      updateTrayStatus('error');
      resolve(false);
    }
  });
}

function stopGateway() {
  return new Promise((resolve) => {
    if (!gatewayProcess) {
      isGatewayRunning = false;
      gatewayStarting = false;
      updateTrayStatus('offline');
      stopHealthCheck();
      resolve(true);
      return;
    }

    stopHealthCheck();
    const proc = gatewayProcess;

    // Send graceful stop command via WSL
    try {
      const stopProc = spawn(WSL_EXE, [
        '-d', WSL_DISTRO, '-u', WSL_USER, '--',
        'bash', '-lc', 'pkill -f "node.*openclaw.*gateway" || openclaw gateway stop 2>/dev/null || true'
      ], { stdio: 'ignore', windowsHide: true });
      stopProc.on('error', () => {});
    } catch {}

    // Also try SIGTERM on the local process
    try { proc.kill('SIGTERM'); } catch {}

    let resolved = false;
    const done = () => {
      if (resolved) return;
      resolved = true;
      gatewayProcess = null;
      isGatewayRunning = false;
      gatewayStarting = false;
      updateTrayStatus('offline');
      resolve(true);
    };

    proc.on('close', done);

    // Force kill after GATEWAY_STOP_TIMEOUT
    setTimeout(() => {
      if (!resolved) {
        try { proc.kill('SIGKILL'); } catch {}
        // Last resort: kill via WSL
        try {
          spawn(WSL_EXE, [
            '-d', WSL_DISTRO, '-u', WSL_USER, '--',
            'bash', '-lc', 'pkill -f "openclaw gateway" || true'
          ], { stdio: 'ignore', windowsHide: true });
        } catch {}
        done();
      }
    }, GATEWAY_STOP_TIMEOUT);
  });
}

async function restartGateway() {
  await stopGateway();
  await new Promise(r => setTimeout(r, 1000));
  return startGateway();
}

function getGatewayStatus() {
  if (isGatewayRunning) return 'online';
  if (gatewayStarting) return 'starting';
  return 'offline';
}

// ============================================================
// Health Check
// ============================================================

function pingGateway() {
  return new Promise((resolve) => {
    const req = http.get(`http://127.0.0.1:${GATEWAY_PORT}/health`, { timeout: 5000 }, (res) => {
      resolve(res.statusCode >= 200 && res.statusCode < 500);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
  });
}

function startHealthCheck() {
  stopHealthCheck();
  healthCheckTimer = setInterval(async () => {
    if (!isGatewayRunning || isQuitting) return;

    const alive = await pingGateway();
    if (!alive && isGatewayRunning) {
      console.log('[health] Gateway not responding, attempting restart...');
      isGatewayRunning = false;
      gatewayProcess = null;
      updateTrayStatus('error');
      showNotification('TWIZA Agent', '⚠️ Gateway unresponsive — restarting...');
      await restartGateway();
    }
  }, HEALTH_CHECK_INTERVAL);
}

function stopHealthCheck() {
  if (healthCheckTimer) {
    clearInterval(healthCheckTimer);
    healthCheckTimer = null;
  }
}

// ============================================================
// IPC Handlers
// ============================================================

// Onboarding
ipcMain.handle('onboarding:complete', () => {
  if (onboardingWindow) {
    onboardingWindow.close();
    onboardingWindow = null;
  }
  createWizardWindow();
  return true;
});

// Wizard
ipcMain.handle('wizard:complete', async (_event, config) => {
  try {
    const os = require('os');
    const sendProgress = (msg) => {
      wizardWindow?.webContents.send('install:progress', msg + '\n');
    };

    // --- Phase 1: Save config for restore after reboot ---
    sendProgress('Starting TWIZA Moneypenny installation...\n');
    sendProgress('Saving your configuration...');
    const savedConfigDir = path.join(app.getPath('appData'), 'TWIZA');
    if (!fs.existsSync(savedConfigDir)) fs.mkdirSync(savedConfigDir, { recursive: true });
    const savedConfigPath = path.join(savedConfigDir, 'saved-config.json');
    fs.writeFileSync(savedConfigPath, JSON.stringify(config, null, 2), 'utf-8');
    sendProgress('INFO: Your settings have been saved and will be restored automatically');
    sendProgress('  Config verified saved: ' + savedConfigPath + '\n');

    // --- Phase 2: Run the PowerShell installer ---
    sendProgress('Checking WSL2 installation...');

    // Find the installer script — look relative to the app
    let installerDir;
    if (process.resourcesPath) {
      // Packaged app: installer is in ../../installer/ relative to resources
      installerDir = path.join(path.dirname(path.dirname(process.resourcesPath)), 'installer');
    }
    if (!installerDir || !fs.existsSync(installerDir)) {
      // Fallback: look in app parent directories
      let searchDir = path.dirname(app.getPath('exe'));
      for (let i = 0; i < 3; i++) {
        const candidate = path.join(searchDir, 'installer');
        if (fs.existsSync(candidate)) { installerDir = candidate; break; }
        searchDir = path.dirname(searchDir);
      }
    }

    // Try multiple installer names
    let installerScript = null;
    if (installerDir) {
      for (const name of ['Install-TWIZA.ps1', 'Install-TWIZA-v30.ps1']) {
        const candidate = path.join(installerDir, name);
        if (fs.existsSync(candidate)) { installerScript = candidate; break; }
      }
    }

    if (!installerScript || !fs.existsSync(installerScript)) {
      // No installer script found — check if WSL + distro already exist
      sendProgress('Installer script not found, checking existing WSL setup...');
      if (isWslDistroInstalled()) {
        sendProgress('  WSL2 + TWIZA distro already installed. Proceeding with config only.\n');
        // Skip to Phase 3 (deploy config)
      } else {
        sendProgress('\n[FAIL] Cannot find Install-TWIZA-v30.ps1');
        sendProgress('Searched: ' + (installerDir || 'no installer directory found'));
        sendProgress('\nPlease run the TWIZA installer (INSTALLA-TWIZA.bat) first,');
        sendProgress('then re-open TWIZA Moneypenny to complete setup.');
        return { success: false, error: 'Installer script not found. Run INSTALLA-TWIZA.bat first.' };
      }
    } else if (!isWslDistroInstalled()) {
      // Need to run the full installer (elevated)
      sendProgress('WSL2 check result: ' + (isWslAvailable() ? 'available' : 'not found'));
      sendProgress('WSL not found. Running bootstrap script...');

      // Set up log file for tailing (PS1 runs elevated = separate process)
      const logFile = path.join(os.tmpdir(), 'twiza-install.log');
      const markerFile = path.join(os.tmpdir(), 'twiza-install-done.txt');
      fs.writeFileSync(logFile, '', 'utf-8');
      try { fs.unlinkSync(markerFile); } catch {}

      // Find the base dir (parent of installer/)
      const baseDir = path.dirname(installerDir);

      // Create a wrapper script that:
      // 1. Redirects ALL output to a log file (transcript + tee)
      // 2. Runs the actual installer (which uses $MyInvocation for paths)
      // 3. Writes exit code to marker file
      // The wrapper copies the installer to TEMP so $MyInvocation resolves correctly
      const wrapperScript = path.join(os.tmpdir(), 'twiza-bootstrap-wsl.ps1');
      const tempInstallerDir = path.join(os.tmpdir(), 'twiza-installer');
      
      // Copy installer + entire base structure reference
      const wrapperContent = [
        '$ErrorActionPreference = "Continue"',
        '$logFile = "' + logFile.replace(/\\/g, '\\\\') + '"',
        '$markerFile = "' + markerFile.replace(/\\/g, '\\\\') + '"',
        '',
        '# Redirect all output to log file for tailing by Electron',
        'Start-Transcript -Path $logFile -Force | Out-Null',
        '',
        '# Tell installer it is running non-interactively (from Electron wizard)',
        '# This prevents Read-Host prompts and Restart-Computer, uses exit codes instead',
        '$env:TWIZA_NONINTERACTIVE = "1"',
        '',
        '# Set paths that the installer expects',
        '$scriptDir = "' + installerDir.replace(/\\/g, '\\\\') + '"',
        '$env:TWIZA_BASE_DIR = "' + baseDir.replace(/\\/g, '\\\\') + '"',
        '',
        'try {',
        '  # Run the installer directly — it reads paths from $MyInvocation',
        '  & "' + installerScript.replace(/\\/g, '\\\\') + '"',
        '  $exitCode = $LASTEXITCODE',
        '  if ($null -eq $exitCode) { $exitCode = 0 }',
        '} catch {',
        '  Write-Host "[ERRORE] $($_.Exception.Message)"',
        '  $exitCode = 1',
        '}',
        '',
        'Stop-Transcript | Out-Null',
        'Set-Content -Path $markerFile -Value $exitCode -Encoding UTF8',
      ].join('\r\n');
      fs.writeFileSync(wrapperScript, wrapperContent, 'utf-8');

      sendProgress('Bootstrap script written to: ' + wrapperScript);
      sendProgress('Running bootstrap (requesting elevation)...');

      // Launch elevated + HIDDEN — only UAC prompt is visible, not the PS window
      const elevateCmd = `Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File','${wrapperScript.replace(/'/g, "''")}' -Verb RunAs -WindowStyle Hidden`;
      try {
        // Use absolute path — powershell.exe may not be in PATH when launched from Electron
        // PS_EXE defined at top
        execSync(`"${PS_EXE}" -Command "${elevateCmd}"`, { timeout: 30000, windowsHide: true });
      } catch (elevErr) {
        sendProgress('[FAIL] Could not elevate: ' + elevErr.message);
        return { success: false, error: 'UAC elevation denied or failed' };
      }

      sendProgress('Bootstrap launched. Monitoring progress...\n');

      // Tail the log file until marker appears
      let lastSize = 0;
      const installResult = await new Promise((resolve) => {
        const tailInterval = setInterval(() => {
          try {
            // Read new log content
            const stat = fs.statSync(logFile);
            if (stat.size > lastSize) {
              const fd = fs.openSync(logFile, 'r');
              const buf = Buffer.alloc(stat.size - lastSize);
              fs.readSync(fd, buf, 0, buf.length, lastSize);
              fs.closeSync(fd);
              const newText = buf.toString('utf-8');
              lastSize = stat.size;
              // Send each line to wizard
              newText.split('\n').forEach(line => {
                if (line.trim()) sendProgress(line.trimEnd());
              });
            }
          } catch {}

          // Check for completion marker
          try {
            if (fs.existsSync(markerFile)) {
              const code = parseInt(fs.readFileSync(markerFile, 'utf-8').trim(), 10) || 0;
              clearInterval(tailInterval);
              resolve({ code });
            }
          } catch {}
        }, 500);

        // Safety timeout: 10 minutes
        setTimeout(() => {
          clearInterval(tailInterval);
          resolve({ code: -99 });
        }, 600000);
      });

      if (installResult.code === 3010 || installResult.code === 1641) {
        sendProgress('\nConfiguration saved successfully (survives reboot).\n');
        sendProgress('[!!] A system restart is required to complete WSL2 installation.');
        sendProgress('Please restart your PC, then run TWIZA Moneypenny again.');
        sendProgress('Your settings (API key, name, etc.) have been saved and will be restored.\n');
        const settings = loadSettings();
        settings.pendingSetup = true;
        settings.savedConfigPath = savedConfigPath;
        saveSettings(settings);
        return { success: false, error: 'RESTART_REQUIRED' };
      } else if (installResult.code !== 0) {
        sendProgress('\n[FAIL] Installer exited with code ' + installResult.code);
        return { success: false, error: 'Installer failed (code ' + installResult.code + ')' };
      }

      sendProgress('\n  Installation completed successfully.\n');
    } else {
      sendProgress('  WSL2 + TWIZA distro already present. Skipping installer.\n');
    }

    // --- Phase 3: Generate and deploy config to WSL ---
    sendProgress('Deploying agent configuration...');
    try {
      // Map wizard localModels to ollamaModel for config-generator
      // If Ollama is provider and no ollamaModel explicitly set, use the bundled default
      if (config.provider === 'ollama' && !config.ollamaModel) {
        config.ollamaModel = 'gemma3:4b';
      }
      // Also register Ollama provider when localModels are selected alongside cloud
      if (config.localModels && config.localModels.length > 0 && !config.ollamaModel) {
        config.ollamaModel = 'gemma3:4b';
      }
      const result = await generateConfig(config);
      const configJsonStr = typeof result.configJson === 'string' ? result.configJson : JSON.stringify(result.config, null, 2);
      sendProgress('  Config generated for provider: ' + (config.provider || 'ollama'));

      // Write config to WSL
      const tmpFile = path.join(os.tmpdir(), 'twiza-openclaw-config.json');
      fs.writeFileSync(tmpFile, configJsonStr, 'utf-8');
      const wslTmp = tmpFile.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, d) => '/mnt/' + d.toLowerCase());
      execSync(`${WSL_EXE} -d TWIZA --user root -- bash -c "mkdir -p /home/twiza/.openclaw/workspace/memory && cp '${wslTmp}' /home/twiza/.openclaw/openclaw.json && chown -R twiza:twiza /home/twiza/.openclaw"`, { timeout: 15000 });
      sendProgress('  [OK] openclaw.json deployed');

      // Write templates
      const templates = result.templates || {};
      for (const [filename, content] of Object.entries(templates)) {
        try {
          const check = execSync(`${WSL_EXE} -d TWIZA --user twiza -- test -f "/home/twiza/.openclaw/workspace/${filename}" && echo exists || echo missing`, { timeout: 5000 }).toString().trim();
          if (check === 'exists') { sendProgress('  [SKIP] ' + filename); continue; }
        } catch { /* proceed */ }
        const tf = path.join(os.tmpdir(), 'twiza-tmpl-' + filename.replace(/[/\\]/g, '-'));
        fs.writeFileSync(tf, content, 'utf-8');
        const wt = tf.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, d) => '/mnt/' + d.toLowerCase());
        execSync(`${WSL_EXE} -d TWIZA --user root -- bash -c "cp '${wt}' '/home/twiza/.openclaw/workspace/${filename}'"`, { timeout: 10000 });
        sendProgress('  [OK] ' + filename);
      }
      execSync(`${WSL_EXE} -d TWIZA --user root -- chown -R twiza:twiza /home/twiza/.openclaw`, { timeout: 10000 });
    } catch (deployErr) {
      sendProgress('  [WARN] Deploy: ' + deployErr.message);
    }

    // --- Phase 4: Mark complete + return success immediately ---
    // Gateway will be started by the "Avvia Moneypenny" button in the wizard
    // Do NOT block here — gateway start can take 20s+ and delays showing the button
    const settings = loadSettings();
    settings.firstRunComplete = true;
    settings.autoStartGateway = true;
    // Save the install source dir for future repairs (find components/ relative to the running exe)
    const exeDir = path.dirname(app.getPath('exe'));
    for (const candidate of [path.join(exeDir, '..', 'components'), path.join(exeDir, 'components'), path.join(exeDir, '..', '..', 'components')]) {
      try { if (fs.existsSync(candidate)) { settings.installSourceDir = path.resolve(candidate); break; } } catch {}
    }
    settings.pendingSetup = false;
    saveSettings(settings);

    sendProgress('\n[OK] Installation complete! Your agent is ready.');
    sendProgress('Click the button below to start Moneypenny.\n');
    return { success: true };
  } catch (err) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('wizard:validate-key', async (_event, { provider, key }) => {
  // Format validation
  const patterns = {
    anthropic: /^sk-ant-/,
    openai: /^sk-/,
    gemini: /^AI/,
    groq: /^gsk_/,
    mistral: /^[a-zA-Z0-9]{32}/,
    xai: /^xai-/,
    together: /^[a-f0-9]{64}/,
    fireworks: /^fw_/,
    perplexity: /^pplx-/,
  };

  const formatOk = patterns[provider]?.test(key) || key.length > 20;
  if (!formatOk) {
    return { valid: false, message: "Key format doesn't match expected pattern for " + provider };
  }

  // Live validation — try a minimal API call
  try {
    const testResult = await validateKeyLive(provider, key);
    return testResult;
  } catch {
    // If live check fails, fall back to format-only
    return { valid: true, message: 'Key format looks good (could not verify online)' };
  }
});

async function validateKeyLive(provider, key) {
  const https = require('https');
  const endpoints = {
    anthropic: {
      hostname: 'api.anthropic.com',
      path: '/v1/messages',
      method: 'POST',
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model: 'claude-3-haiku-20240307', max_tokens: 1, messages: [{ role: 'user', content: 'hi' }] }),
    },
    openai: {
      hostname: 'api.openai.com',
      path: '/v1/models',
      method: 'GET',
      headers: { 'Authorization': `Bearer ${key}` },
    },
  };

  const ep = endpoints[provider];
  if (!ep) return { valid: true, message: 'Key format looks good!' };

  return new Promise((resolve) => {
    const req = https.request(ep, (res) => {
      if (res.statusCode === 401 || res.statusCode === 403) {
        resolve({ valid: false, message: 'Invalid API key — authentication failed' });
      } else {
        resolve({ valid: true, message: 'API key verified ✓' });
      }
      res.resume();
    });
    req.on('error', () => resolve({ valid: true, message: 'Key format looks good (could not verify online)' }));
    req.setTimeout(8000, () => { req.destroy(); resolve({ valid: true, message: 'Key format looks good (timeout verifying)' }); });
    if (ep.body) req.write(ep.body);
    req.end();
  });
}

// Gateway
ipcMain.handle('gateway:start', async () => { await startGateway(); return true; });
ipcMain.handle('gateway:stop', async () => { await stopGateway(); return true; });
ipcMain.handle('gateway:restart', async () => { await restartGateway(); return true; });
ipcMain.handle('gateway:status', () => getGatewayStatus());

// App
ipcMain.handle('app:open-external', (_event, url) => {
  shell.openExternal(url);
  return true;
});
ipcMain.handle('app:open-chat', () => { openChatWindow(); return true; });
ipcMain.handle('app:open-webchat-browser', () => {
  shell.openExternal(`http://127.0.0.1:${WEBCHAT_PORT}`);
  return true;
});
ipcMain.handle('app:open-settings', () => { openSettingsWindow(); return true; });
ipcMain.handle('app:open-docs', () => { openDocsWindow(); return true; });
ipcMain.handle('app:open-docs-pdf', () => { openDocsPdf(); return true; });
ipcMain.handle('app:get-settings', () => loadSettings());
ipcMain.handle('app:save-settings', (_event, settings) => { saveSettings(settings); return true; });
ipcMain.handle('app:get-version', () => getCurrentVersion());

// Window controls
ipcMain.handle('window:close', (event) => {
  const win = BrowserWindow.fromWebContents(event.sender);
  win?.close();
});
ipcMain.handle('window:minimize', (event) => {
  const win = BrowserWindow.fromWebContents(event.sender);
  win?.minimize();
});
ipcMain.handle('window:maximize', (event) => {
  const win = BrowserWindow.fromWebContents(event.sender);
  if (win) {
    win.isMaximized() ? win.unmaximize() : win.maximize();
  }
});

// Quit
ipcMain.handle('app:quit', () => {
  isQuitting = true;
  stopGateway();
  app.quit();
});

// ============================================================
// Wizard state persistence (file-based, survives reboot/reinstall)
// ============================================================
const WIZARD_STATE_FILE = path.join(app.getPath('appData'), 'TWIZA', 'wizard-state.json');

ipcMain.handle('wizard:save-state', (_event, stateObj) => {
  try {
    const dir = path.dirname(WIZARD_STATE_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(WIZARD_STATE_FILE, JSON.stringify(stateObj, null, 2), 'utf-8');
    return true;
  } catch (e) {
    console.error('[wizard] Failed to save state:', e.message);
    return false;
  }
});

ipcMain.handle('wizard:load-state', () => {
  try {
    if (fs.existsSync(WIZARD_STATE_FILE)) {
      return JSON.parse(fs.readFileSync(WIZARD_STATE_FILE, 'utf-8'));
    }
  } catch (e) {
    console.error('[wizard] Failed to load state:', e.message);
  }
  return null;
});

ipcMain.handle('wizard:clear-state', () => {
  try { fs.unlinkSync(WIZARD_STATE_FILE); } catch {}
  return true;
});

// System reboot (called from wizard renderer via IPC)
ipcMain.handle('system:reboot', () => {
  try {
    execSync('shutdown /r /t 5 /c "TWIZA Moneypenny - riavvio per attivazione WSL2"', { windowsHide: true });
    return true;
  } catch (e) {
    console.error('[system:reboot] Failed:', e.message);
    return false;
  }
});

// Updater
ipcMain.handle('app:check-updates', () => checkForUpdates());

// ============================================================
// App Lifecycle
// ============================================================

app.on('second-instance', () => {
  if (onboardingWindow) {
    if (onboardingWindow.isMinimized()) onboardingWindow.restore();
    onboardingWindow.focus();
  } else if (wizardWindow) {
    if (wizardWindow.isMinimized()) wizardWindow.restore();
    wizardWindow.focus();
  } else if (chatWindow) {
    if (chatWindow.isMinimized()) chatWindow.restore();
    chatWindow.focus();
  } else {
    openChatWindow();
  }
});

app.whenReady().then(async () => {
  // Create tray (always — even if WSL isn't ready yet)
  createTray({
    startGateway,
    stopGateway,
    restartGateway,
    openChatWindow,
    openSettingsWindow,
    openModelsWindow,
    openDocsWindow,
    openDocsPdf,
    openWebchatBrowser: () => shell.openExternal(`http://127.0.0.1:${WEBCHAT_PORT}`),
    isGatewayRunning: () => isGatewayRunning,
    getStatus: getGatewayStatus,
    checkForUpdates,
    getVersion: getCurrentVersion,
  });

  const settings = loadSettings();
  console.log('[app] Settings:', JSON.stringify({ pendingSetup: settings.pendingSetup, firstRunComplete: settings.firstRunComplete, autoStartGateway: settings.autoStartGateway }));
  console.log('[app] WSL distro installed:', isWslDistroInstalled());

  if (settings.pendingSetup) {
    // Post-reboot: WSL2 was just installed, resume setup with saved config
    console.log('[app] Resuming pending setup after reboot...');
    createWizardWindow();
    // The wizard will auto-detect WSL is now available and re-run install
  } else if (!settings.firstRunComplete) {
    // First run: check if WSL + distro + config already exist (installed by BAT/PS1)
    if (isWslDistroInstalled()) {
      // Distro exists — check for config
      let hasConfig = false;
      try { hasConfig = configExistsInWsl(); } catch {}
      
      if (hasConfig) {
        // Fully installed by BAT — skip to chat
        console.log('[app] Detected existing TWIZA installation, skipping onboarding');
        settings.firstRunComplete = true;
        settings.autoStartGateway = true;
        saveSettings(settings);
        startGateway();
        openChatWindow();
      } else {
        // Distro exists but no config — go to wizard (skip onboarding)
        console.log('[app] TWIZA distro found but no config — opening wizard');
        createWizardWindow();
      }
    } else {
      // No distro at all — true first run, show onboarding
      // The onboarding/wizard will handle WSL installation
      createOnboardingWindow();
    }
  } else {
    // Returning user — but verify installation is actually complete
    let configOk = false;
    try { configOk = isWslDistroInstalled() && configExistsInWsl(); } catch {}
    
    if (!configOk) {
      // firstRunComplete was set but installation is broken — reset and redo wizard
      console.log('[app] firstRunComplete=true but config missing! Resetting to wizard.');
      settings.firstRunComplete = false;
      settings.pendingSetup = false;
      saveSettings(settings);
      if (isWslDistroInstalled()) {
        createWizardWindow();
      } else {
        createOnboardingWindow();
      }
    } else {
      // Everything looks good — start gateway and open chat
      if (settings.autoStartGateway) {
        startGateway();
      }
      openChatWindow();
    }
  }

  // Start auto-update check (every 4 hours) — only if explicitly enabled
  try {
    const updateSettings = loadSettings();
    if (updateSettings.autoUpdate === true) {
      startAutoCheck();
    }
  } catch (err) {
    console.error('[updater] Failed to start auto-check:', err.message);
  }
});

app.on('window-all-closed', () => {
  // If gateway is running, keep alive in tray (user can access via tray icon).
  // Otherwise (e.g. wizard closed before install, or after "Avvia Moneypenny"
  // opened the browser), quit cleanly to avoid zombie Electron processes.
  if (!isGatewayRunning && !gatewayStarting) {
    console.log('[app] All windows closed, no gateway running — quitting.');
    isQuitting = true;
    app.quit();
  } else {
    console.log('[app] All windows closed but gateway is running — staying in tray.');
  }
});

app.on('before-quit', async () => {
  isQuitting = true;
  stopHealthCheck();
  stopAutoCheck();
  await stopGateway();
});

module.exports = { openChatWindow, openSettingsWindow, openDocsWindow, openDocsPdf, startGateway, stopGateway, restartGateway };
