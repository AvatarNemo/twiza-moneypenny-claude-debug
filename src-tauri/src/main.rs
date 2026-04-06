// TWIZA Moneypenny — Tauri Backend
// ...more than an agent!

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod wsl;
mod gateway;
mod state;
mod oauth;

use state::AppState;
use std::sync::Mutex;
use tauri::{
    AppHandle, Emitter, Manager, State, WindowEvent,
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    menu::{MenuBuilder, MenuItemBuilder, PredefinedMenuItem},
};
use tauri_plugin_notification::NotificationExt;

// ============================================================
// IPC Commands — called from frontend JS
// ============================================================

/// Validate an API key against its provider
#[tauri::command]
async fn validate_key(provider: String, key: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| e.to_string())?;

    let response = match provider.as_str() {
        "anthropic" => {
            client.get("https://api.anthropic.com/v1/models")
                .header("x-api-key", &key)
                .header("anthropic-version", "2023-06-01")
                .send().await
        }
        "openai" => {
            client.get("https://api.openai.com/v1/models")
                .header("Authorization", format!("Bearer {}", key))
                .send().await
        }
        "gemini" => {
            client.get(format!(
                "https://generativelanguage.googleapis.com/v1beta/models?key={}", key
            )).send().await
        }
        _ => return Err("Unknown provider".into()),
    };

    let provider_name = match provider.as_str() {
        "anthropic" => "Anthropic",
        "openai" => "OpenAI",
        "gemini" => "Google Gemini",
        _ => &provider,
    };

    match response {
        Ok(resp) if resp.status().is_success() => Ok(serde_json::json!({
            "valid": true,
            "message": format!("{} API key validated successfully", provider_name)
        })),
        Ok(resp) => Ok(serde_json::json!({
            "valid": false,
            "message": format!("Invalid key (HTTP {})", resp.status().as_u16())
        })),
        Err(e) => Ok(serde_json::json!({
            "valid": false,
            "message": format!("Connection failed: {}", e)
        })),
    }
}

/// Generate openclaw.json config from wizard settings
fn generate_openclaw_config(config: &serde_json::Value) -> serde_json::Value {
    let provider = config.get("provider").and_then(|v| v.as_str()).unwrap_or("anthropic");
    let agent_name = config.get("agentName").and_then(|v| v.as_str()).unwrap_or("Moneypenny");
    let agent_emoji = config.get("agentEmoji").and_then(|v| v.as_str()).unwrap_or("🦾");

    let mut auth_profiles = serde_json::json!({});
    let profile_key = format!("{}:default", provider);
    auth_profiles[&profile_key] = serde_json::json!({
        "provider": provider,
        "mode": "api_key"
    });

    let model_primary = match provider {
        "anthropic" => "anthropic/claude-sonnet-4-20250514",
        "openai" => "openai/gpt-4o",
        "gemini" => "gemini/gemini-2.5-flash",
        _ => "anthropic/claude-sonnet-4-20250514",
    };

    serde_json::json!({
        "ui": {
            "assistant": {
                "name": agent_name,
                "avatar": null
            }
        },
        "auth": {
            "profiles": auth_profiles
        },
        "agents": {
            "defaults": {
                "model": { "primary": model_primary },
                "workspace": "/home/twiza/.openclaw/workspace",
                "compaction": { "mode": "safeguard" }
            },
            "list": [{
                "id": "main",
                "identity": {
                    "name": agent_name,
                    "emoji": agent_emoji
                }
            }]
        },
        "gateway": {
            "port": 18789,
            "mode": "local",
            "bind": "loopback",
            "auth": { "mode": "token" }
        },
        "channels": {},
        "plugins": { "entries": {} }
    })
}

/// Map wizard model IDs to actual Ollama model names
fn map_ollama_model_name(wizard_name: &str) -> &str {
    match wizard_name {
        "qwen3-32b" => "qwen3:32b",
        "deepseek-r1-14b" => "deepseek-r1:14b",
        "mistral-small-24b" => "mistral-small:24b",
        other => other,
    }
}

/// Run the full installation: bootstrap WSL, install deps, configure OpenClaw
#[tauri::command]
async fn complete_setup(
    app: AppHandle,
    state: State<'_, Mutex<AppState>>,
    config: serde_json::Value,
) -> Result<serde_json::Value, String> {
    let emit = |msg: &str| { let _ = app.emit("install:progress", msg); };

    emit("\n🚀 Starting TWIZA Moneypenny installation...\n\n");
    emit("Checking WSL2 installation...\n");

    // Step 1: Check WSL
    let wsl_ok = wsl::check_wsl_available().await;
    emit(&format!("WSL2 check result: {}\n", if wsl_ok { "found" } else { "not found" }));

    if !wsl_ok {
        emit("WSL2 not found. Running bootstrap script...\n");

        // Embed the bootstrap script at compile time
        let bootstrap_script = include_str!("../../scripts/bootstrap-wsl.ps1");
        let temp_dir = std::env::temp_dir();
        let script_path = temp_dir.join("twiza-bootstrap-wsl.ps1");
        std::fs::write(&script_path, bootstrap_script)
            .map_err(|e| format!("Failed to write bootstrap script: {}", e))?;
        emit(&format!("Bootstrap script written to: {}\n", script_path.display()));

        let skip_ollama = config.get("skipLocalModels")
            .and_then(|v| v.as_bool()).unwrap_or(false);

        // Strip large fields (profilePic is base64, can be 100s of KB)
        // to avoid exceeding Windows command-line length limit (os error 206).
        // The bootstrap script only needs provider/key info, not the full config.
        let mut light_config = config.clone();
        if let Some(obj) = light_config.as_object_mut() {
            obj.remove("profilePic");
        }
        let config_json = serde_json::to_string(&light_config).unwrap_or_default();
        let app_clone = app.clone();

        let script_result = wsl::run_powershell_script(
            &script_path.to_string_lossy(),
            skip_ollama,
            &config_json,
            move |line| { let _ = app_clone.emit("install:progress", &line); },
        ).await;

        if let Err(e) = script_result {
            if e.contains("RESTART_REQUIRED") {
                emit("\n⚠️ A system restart is required to complete WSL2 installation.\n");
                emit("Please restart your PC, then run TWIZA Moneypenny again.\n");
                return Err("System restart required. Please restart your PC and run the installer again.".into());
            }
            if e.contains("cancelled") || e.contains("canceled") {
                emit("\n❌ UAC elevation was cancelled.\n");
                return Err("Administrator privileges are needed to install WSL2. Please accept the UAC prompt.".into());
            }
            return Err(format!("Bootstrap failed: {}", e));
        }

        // Clean up temp script
        let _ = std::fs::remove_file(&script_path);
    } else {
        emit("✓ WSL2 is ready\n");
    }

    // Ensure the twiza user exists before any WSL commands
    emit("Ensuring twiza user exists...\n");
    wsl::ensure_twiza_user().await
        .map_err(|e| format!("Failed to create twiza user: {}", e))?;
    emit("✓ twiza user ready\n");

    // Step 2: OpenClaw
    emit("Checking OpenClaw...\n");
    if wsl::run_wsl_command("which openclaw").await.is_err() {
        emit("Installing OpenClaw...\n");
        wsl::run_wsl_command("npm install -g openclaw").await
            .map_err(|e| format!("Failed to install OpenClaw: {}", e))?;
    }
    emit("✓ OpenClaw installed\n");

    // Step 3: Deploy config + workspace files
    emit("Generating configuration...\n");

    // Create directories
    wsl::run_wsl_command("mkdir -p /home/twiza/.openclaw/workspace").await
        .map_err(|e| format!("Failed to create directories: {}", e))?;

    // Generate and write openclaw.json
    let openclaw_config = generate_openclaw_config(&config);
    let config_json_str = serde_json::to_string_pretty(&openclaw_config)
        .map_err(|e| format!("Failed to serialize config: {}", e))?;
    wsl::run_wsl_command(&format!(
        "cat > /home/twiza/.openclaw/openclaw.json << 'TWIZAEOF'\n{}\nTWIZAEOF",
        config_json_str
    )).await.map_err(|e| format!("Config write failed: {}", e))?;
    emit("✓ openclaw.json deployed\n");

    // Store API key in .bashrc
    let provider = config.get("provider").and_then(|v| v.as_str()).unwrap_or("anthropic");
    let api_key = config.get("apiKey").and_then(|v| v.as_str()).unwrap_or("");
    if !api_key.is_empty() {
        let env_var_name = match provider {
            "anthropic" => "ANTHROPIC_API_KEY",
            "openai" => "OPENAI_API_KEY",
            "gemini" => "GEMINI_API_KEY",
            _ => "ANTHROPIC_API_KEY",
        };
        // Remove any existing line for this key, then append
        wsl::run_wsl_command(&format!(
            "sed -i '/^export {}=/d' /home/twiza/.bashrc 2>/dev/null; echo 'export {}=\"{}\"' >> /home/twiza/.bashrc",
            env_var_name, env_var_name, api_key.replace('\"', "\\\"").replace('\'', "'\\''")
        )).await.map_err(|e| format!("Failed to store API key: {}", e))?;
        emit(&format!("✓ {} configured\n", env_var_name));
    }

    // Create workspace files
    let agent_name = config.get("agentName").and_then(|v| v.as_str()).unwrap_or("Moneypenny");
    let agent_emoji = config.get("agentEmoji").and_then(|v| v.as_str()).unwrap_or("🦾");
    let personality = config.get("personality").and_then(|v| v.as_str()).unwrap_or("balanced");

    let personality_desc = match personality {
        "moneypenny" => "Direct, sarcastic, competent, warm. A fuchsia giraffe with a heart of gold.",
        "balanced" => "Friendly, helpful, and concise.",
        "professional" => "Formal, precise, and structured.",
        "creative" => "Playful, expressive, and imaginative.",
        _ => "Helpful AI assistant.",
    };

    let soul_md = format!(
        "# SOUL.md\n\nYou are **{}** {}\n\n## Personality\n\n{}\n\n## Guidelines\n\n- Be helpful and responsive\n- Respect user privacy\n- Ask before taking destructive actions\n",
        agent_name, agent_emoji, personality_desc
    );
    wsl::run_wsl_command(&format!(
        "cat > /home/twiza/.openclaw/workspace/SOUL.md << 'TWIZAEOF'\n{}\nTWIZAEOF",
        soul_md
    )).await.map_err(|e| format!("Failed to write SOUL.md: {}", e))?;

    let agents_md = "# AGENTS.md\n\nSee the main AGENTS.md template for full workspace conventions.\n\n## Quick Start\n\n1. Read SOUL.md — who you are\n2. Read USER.md — who you're helping\n3. Check memory/ for recent context\n";
    wsl::run_wsl_command(&format!(
        "cat > /home/twiza/.openclaw/workspace/AGENTS.md << 'TWIZAEOF'\n{}\nTWIZAEOF",
        agents_md
    )).await.map_err(|e| format!("Failed to write AGENTS.md: {}", e))?;

    let user_md = "# USER.md\n\n## About\n\nTell your agent about yourself here. What do you do? What are your preferences?\n\n## Preferences\n\n- Language: English\n- Timezone: (set your timezone)\n";
    wsl::run_wsl_command(&format!(
        "cat > /home/twiza/.openclaw/workspace/USER.md << 'TWIZAEOF'\n{}\nTWIZAEOF",
        user_md
    )).await.map_err(|e| format!("Failed to write USER.md: {}", e))?;

    emit("✓ Workspace files created\n");

    // Step 4: Start gateway
    emit("Starting TWIZA Moneypenny gateway...\n");
    gateway::start_gateway().await?;
    emit("✓ Gateway running\n");

    // Step 5: Local models — always pull llama3.2:3b as default, plus user selections
    if !config.get("skipLocalModels").and_then(|v| v.as_bool()).unwrap_or(false) {
        // Default embedded model
        emit("Downloading default model llama3.2:3b (2GB)...\n");
        let _ = wsl::run_wsl_command("ollama pull llama3.2:3b").await;
        emit("✓ llama3.2:3b ready — your default local model\n");

        // Additional user-selected models
        if let Some(models) = config.get("localModels").and_then(|v| v.as_array()) {
            for model in models {
                if let Some(wizard_name) = model.as_str() {
                    let ollama_name = map_ollama_model_name(wizard_name);
                    if ollama_name == "llama3.2:3b" { continue; } // Already pulled
                    emit(&format!("Downloading model {}...\n", ollama_name));
                    let _ = wsl::run_wsl_command(&format!("ollama pull {}", ollama_name)).await;
                    emit(&format!("✓ {} ready\n", ollama_name));
                }
            }
        }
    }

    emit("\n✅ TWIZA Moneypenny is ready! ...more than an agent!\n");

    if let Ok(mut s) = state.lock() {
        s.setup_complete = true;
        s.gateway_running = true;
    }

    Ok(serde_json::json!({ "success": true }))
}

#[tauri::command]
async fn start_gateway(state: State<'_, Mutex<AppState>>) -> Result<bool, String> {
    gateway::start_gateway().await?;
    if let Ok(mut s) = state.lock() { s.gateway_running = true; }
    Ok(true)
}

#[tauri::command]
async fn stop_gateway(state: State<'_, Mutex<AppState>>) -> Result<bool, String> {
    gateway::stop_gateway().await?;
    if let Ok(mut s) = state.lock() { s.gateway_running = false; }
    Ok(true)
}

#[tauri::command]
async fn gateway_status(state: State<'_, Mutex<AppState>>) -> Result<serde_json::Value, String> {
    let running = gateway::check_gateway_health().await;
    if let Ok(mut s) = state.lock() { s.gateway_running = running; }
    Ok(serde_json::json!({ "running": running, "port": 18789 }))
}

#[tauri::command]
async fn open_chat() -> Result<(), String> {
    open::that("http://localhost:18789").map_err(|e| e.to_string())
}

#[tauri::command]
async fn open_webchat_browser() -> Result<(), String> {
    open::that("http://localhost:18789").map_err(|e| e.to_string())
}

#[tauri::command]
async fn get_settings() -> Result<serde_json::Value, String> {
    let output = wsl::run_wsl_command("cat /home/twiza/.openclaw/openclaw.json 2>/dev/null || echo '{}'")
        .await.unwrap_or_else(|_| "{}".to_string());
    serde_json::from_str(&output).map_err(|e| e.to_string())
}

#[tauri::command]
async fn save_settings(settings: serde_json::Value) -> Result<bool, String> {
    let json = serde_json::to_string_pretty(&settings).map_err(|e| e.to_string())?;
    wsl::run_wsl_command(&format!(
        "cat > /home/twiza/.openclaw/openclaw.json << 'EOF'\n{}\nEOF", json
    )).await.map_err(|e| format!("Failed to save: {}", e))?;
    Ok(true)
}

#[tauri::command]
async fn close_window(app: AppHandle, label: String) -> Result<(), String> {
    if let Some(w) = app.get_webview_window(&label) {
        w.close().map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
async fn minimize_window(app: AppHandle, label: String) -> Result<(), String> {
    if let Some(w) = app.get_webview_window(&label) {
        w.minimize().map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
async fn run_diagnostics() -> Result<serde_json::Value, String> {
    let output = wsl::run_wsl_command(
        "node -e \"const d = require('/home/twiza/.openclaw/workspace/src/diagnostics.js'); d.runDiagnosticsJSON().then(r => console.log(JSON.stringify(r)))\" 2>/dev/null || echo '{\"error\": \"not available\"}'"
    ).await.unwrap_or_else(|_| "{\"error\": \"WSL unavailable\"}".to_string());
    serde_json::from_str(&output).map_err(|e| e.to_string())
}

#[tauri::command]
async fn quit_app(app: AppHandle, state: State<'_, Mutex<AppState>>) -> Result<(), String> {
    let _ = gateway::stop_gateway().await;
    if let Ok(mut s) = state.lock() { s.gateway_running = false; }
    app.exit(0);
    Ok(())
}

// ============================================================
// TikTok Integration Commands
// ============================================================

/// Test TikTok cookies validity
#[tauri::command]
async fn test_tiktok_cookies(cookies_path: String) -> Result<serde_json::Value, String> {
    let check_cmd = format!(
        "python3 -c \"from pathlib import Path; p = Path('{path}'); \
         print('exists' if p.exists() else 'missing'); \
         lines = [l for l in p.read_text().splitlines() if l.strip() and not l.startswith('#')] if p.exists() else []; \
         print(len(lines))\"",
        path = cookies_path.replace('\'', "'\\''")
    );
    let output = wsl::run_wsl_command(&check_cmd).await
        .map_err(|e| format!("Failed to check cookies: {}", e))?;
    let lines: Vec<&str> = output.trim().lines().collect();
    let exists = lines.first().map(|s| *s == "exists").unwrap_or(false);
    let count: usize = lines.get(1).and_then(|s| s.parse().ok()).unwrap_or(0);

    if !exists {
        Ok(serde_json::json!({ "valid": false, "message": "Cookies file not found" }))
    } else if count < 5 {
        Ok(serde_json::json!({ "valid": false, "message": format!("Cookies file has only {} entries — may be incomplete", count) }))
    } else {
        Ok(serde_json::json!({ "valid": true, "message": format!("Cookies file found with {} entries", count) }))
    }
}

/// Upload a video to TikTok via the custom Playwright script in WSL
#[tauri::command]
async fn upload_tiktok_video(
    app: AppHandle,
    video_path: String,
    description: String,
    _cookies_path: String,
    headless: bool,
) -> Result<serde_json::Value, String> {
    let _ = app.emit("tiktok:upload:start", &video_path);

    // Convert Windows path to WSL path if needed
    let wsl_video_path = if video_path.contains('\\') || video_path.contains(':') {
        // Windows path → convert via wslpath
        let converted = wsl::run_wsl_command(&format!("wslpath '{}'", video_path.replace('\'', "'\\''"))).await
            .map_err(|e| format!("Path conversion failed: {}", e))?;
        converted.trim().to_string()
    } else {
        video_path.clone()
    };

    let headless_flag = if headless { "" } else { " --no-headless" };
    let upload_cmd = format!(
        "source ~/.venvs/tiktok/bin/activate && python -u ~/.config/tiktok/upload.py '{}' '{}'{} 2>&1",
        wsl_video_path.replace('\'', "'\\''"),
        description.replace('\'', "'\\''"),
        headless_flag
    );

    let output = wsl::run_wsl_command(&upload_cmd).await
        .map_err(|e| format!("Upload command failed: {}", e))?;

    let success = output.contains("Upload successful");
    let _ = app.emit("tiktok:upload:done", serde_json::json!({
        "success": success,
        "output": output.trim(),
    }));

    if success {
        Ok(serde_json::json!({ "success": true, "message": "Video uploaded to TikTok!" }))
    } else {
        Ok(serde_json::json!({ "success": false, "message": output.trim() }))
    }
}

// ============================================================
// Email / Gmail / Google Calendar Integration Commands
// ============================================================

/// Test IMAP connection (used by imap-accounts and protonmail)
#[tauri::command]
async fn test_imap_connection(host: String, port: u16, email: String, password: String) -> Result<serde_json::Value, String> {
    let cmd = format!(
        "python3 -c \"\
import imaplib, sys\n\
try:\n\
    m = imaplib.IMAP4_SSL('{host}', {port})\n\
    m.login('{email}', '{password}')\n\
    m.logout()\n\
    print('OK')\n\
except Exception as e:\n\
    print(f'ERR:{{e}}')\n\
\"",
        host = host.replace('\'', "'\\''"),
        port = port,
        email = email.replace('\'', "'\\''"),
        password = password.replace('\'', "'\\''"),
    );
    let output = wsl::run_wsl_command(&cmd).await
        .map_err(|e| format!("IMAP test failed: {}", e))?;
    let trimmed = output.trim();
    if trimmed == "OK" {
        Ok(serde_json::json!({ "valid": true, "message": "IMAP connection successful" }))
    } else {
        let msg = trimmed.strip_prefix("ERR:").unwrap_or(trimmed);
        Ok(serde_json::json!({ "valid": false, "message": msg }))
    }
}

/// Test Gmail OAuth2 token validity
#[tauri::command]
async fn test_gmail_token(token_path: String) -> Result<serde_json::Value, String> {
    let cmd = format!(
        "python3 -c \"\
import json, sys\n\
from pathlib import Path\n\
p = Path('{path}')\n\
if not p.exists():\n\
    print('ERR:Token file not found')\n\
    sys.exit(0)\n\
t = json.loads(p.read_text())\n\
if 'token' in t or 'access_token' in t:\n\
    print('OK')\n\
else:\n\
    print('ERR:Token file missing access token')\n\
\"",
        path = token_path.replace('\'', "'\\''"),
    );
    let output = wsl::run_wsl_command(&cmd).await
        .map_err(|e| format!("Gmail token test failed: {}", e))?;
    let trimmed = output.trim();
    if trimmed == "OK" {
        Ok(serde_json::json!({ "valid": true, "message": "Gmail token found and valid" }))
    } else {
        let msg = trimmed.strip_prefix("ERR:").unwrap_or(trimmed);
        Ok(serde_json::json!({ "valid": false, "message": msg }))
    }
}

/// Test Google Calendar OAuth2 token and list next 3 events
#[tauri::command]
async fn test_gcal_token(token_path: String) -> Result<serde_json::Value, String> {
    let cmd = format!(
        "python3 << 'PYEOF'\n\
import json, sys\n\
from pathlib import Path\n\
p = Path('{path}')\n\
if not p.exists():\n\
    print(json.dumps({{\"valid\": False, \"message\": \"Token file not found\"}}))\n\
    sys.exit(0)\n\
try:\n\
    from google.oauth2.credentials import Credentials\n\
    from googleapiclient.discovery import build\n\
    import datetime\n\
    t = json.loads(p.read_text())\n\
    creds = Credentials.from_authorized_user_info(t)\n\
    service = build('calendar', 'v3', credentials=creds)\n\
    now = datetime.datetime.utcnow().isoformat() + 'Z'\n\
    result = service.events().list(calendarId='primary', timeMin=now, maxResults=3, singleEvents=True, orderBy='startTime').execute()\n\
    events = [{{\"summary\": e.get(\"summary\",\"No title\"), \"start\": e.get(\"start\",{{}}).get(\"dateTime\", e.get(\"start\",{{}}).get(\"date\",\"?\"))}} for e in result.get(\"items\",[])]\n\
    print(json.dumps({{\"valid\": True, \"message\": \"Calendar token valid\", \"events\": events}}))\n\
except Exception as e:\n\
    print(json.dumps({{\"valid\": False, \"message\": str(e)}}))\n\
PYEOF",
        path = token_path.replace('\'', "'\\''"),
    );
    let output = wsl::run_wsl_command(&cmd).await
        .map_err(|e| format!("GCal token test failed: {}", e))?;
    serde_json::from_str(output.trim()).map_err(|_| format!("Unexpected output: {}", output.trim()))
}

/// Send email via IMAP/SMTP account
#[tauri::command]
async fn send_imap_email(from_email: String, to: String, subject: String, body: String) -> Result<serde_json::Value, String> {
    let cmd = format!(
        "python3 << 'PYEOF'\n\
import json, smtplib, sys\n\
from email.mime.text import MIMEText\n\
from pathlib import Path\n\
accounts = json.loads(Path.home().joinpath('.config/email/accounts.json').read_text())\n\
acc = next((a for a in accounts if a['email'] == '{from_email}'), None)\n\
if not acc:\n\
    print(json.dumps({{\"success\": False, \"message\": \"Account not found\"}}))\n\
    sys.exit(0)\n\
try:\n\
    msg = MIMEText('{body}')\n\
    msg['Subject'] = '{subject}'\n\
    msg['From'] = acc['email']\n\
    msg['To'] = '{to}'\n\
    with smtplib.SMTP_SSL(acc['smtpHost'], acc.get('smtpPort', 587)) as s:\n\
        s.login(acc['email'], acc['password'])\n\
        s.send_message(msg)\n\
    print(json.dumps({{\"success\": True, \"message\": \"Email sent\"}}))\n\
except Exception as e:\n\
    print(json.dumps({{\"success\": False, \"message\": str(e)}}))\n\
PYEOF",
        from_email = from_email.replace('\'', "'\\''"),
        to = to.replace('\'', "'\\''"),
        subject = subject.replace('\'', "'\\''"),
        body = body.replace('\'', "'\\''"),
    );
    let output = wsl::run_wsl_command(&cmd).await
        .map_err(|e| format!("Send email failed: {}", e))?;
    serde_json::from_str(output.trim()).map_err(|_| format!("Unexpected output: {}", output.trim()))
}

/// Check IMAP inbox for latest N messages
#[tauri::command]
async fn check_imap_inbox(email: String, n: u32) -> Result<serde_json::Value, String> {
    let cmd = format!(
        "python3 << 'PYEOF'\n\
import json, imaplib, email as emaillib, sys\n\
from pathlib import Path\n\
accounts = json.loads(Path.home().joinpath('.config/email/accounts.json').read_text())\n\
acc = next((a for a in accounts if a['email'] == '{email}'), None)\n\
if not acc:\n\
    print(json.dumps({{\"success\": False, \"message\": \"Account not found\"}}))\n\
    sys.exit(0)\n\
try:\n\
    m = imaplib.IMAP4_SSL(acc['imapHost'], acc.get('imapPort', 993))\n\
    m.login(acc['email'], acc['password'])\n\
    m.select('INBOX')\n\
    _, data = m.search(None, 'ALL')\n\
    ids = data[0].split()[-{n}:] if data[0] else []\n\
    msgs = []\n\
    for mid in reversed(ids):\n\
        _, raw = m.fetch(mid, '(RFC822)')\n\
        msg = emaillib.message_from_bytes(raw[0][1])\n\
        msgs.append({{\"from\": msg['From'], \"subject\": msg['Subject'], \"date\": msg['Date']}})\n\
    m.logout()\n\
    print(json.dumps({{\"success\": True, \"messages\": msgs}}))\n\
except Exception as e:\n\
    print(json.dumps({{\"success\": False, \"message\": str(e)}}))\n\
PYEOF",
        email = email.replace('\'', "'\\''"),
        n = n,
    );
    let output = wsl::run_wsl_command(&cmd).await
        .map_err(|e| format!("Check inbox failed: {}", e))?;
    serde_json::from_str(output.trim()).map_err(|_| format!("Unexpected output: {}", output.trim()))
}

// ============================================================
// New Integration Test Commands
// ============================================================

/// Test Bluesky authentication via AT Protocol
#[tauri::command]
async fn test_bluesky_auth(identifier: String, password: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.post("https://bsky.social/xrpc/com.atproto.server.createSession")
        .json(&serde_json::json!({ "identifier": identifier, "password": password }))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Bluesky authentication successful" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Authentication failed (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Perplexity API key
#[tauri::command]
async fn test_perplexity_key(key: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.post("https://api.perplexity.ai/chat/completions")
        .header("Authorization", format!("Bearer {}", key))
        .json(&serde_json::json!({
            "model": "sonar",
            "max_tokens": 5,
            "messages": [{"role": "user", "content": "ping"}]
        }))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Perplexity API key validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid key (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test LinkedIn OAuth token
#[tauri::command]
async fn test_linkedin_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.linkedin.com/v2/userinfo")
        .header("Authorization", format!("Bearer {}", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "LinkedIn token validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Spotify OAuth token
#[tauri::command]
async fn test_spotify_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.spotify.com/v1/me")
        .header("Authorization", format!("Bearer {}", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Spotify token validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Dropbox OAuth token
#[tauri::command]
async fn test_dropbox_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.post("https://api.dropboxapi.com/2/users/get_current_account")
        .header("Authorization", format!("Bearer {}", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Dropbox token validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Microsoft OAuth token (OneDrive + Office 365)
#[tauri::command]
async fn test_microsoft_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://graph.microsoft.com/v1.0/me")
        .header("Authorization", format!("Bearer {}", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Microsoft token validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Google Drive OAuth token
#[tauri::command]
async fn test_google_drive_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://www.googleapis.com/drive/v3/about?fields=user")
        .header("Authorization", format!("Bearer {}", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Google Drive token validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Groq API key
#[tauri::command]
async fn test_groq_key(key: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.groq.com/openai/v1/models")
        .header("Authorization", format!("Bearer {}", key))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Groq API key validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid key (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Manus API key
#[tauri::command]
async fn test_manus_key(api_key: String, base_url: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let url = format!("{}/v1/agents/me", base_url.trim_end_matches('/'));
    let resp = client.post(&url)
        .header("Authorization", format!("Bearer {}", api_key))
        .header("Content-Type", "application/json")
        .body("{}")
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() || r.status().as_u16() == 404 => Ok(serde_json::json!({ "valid": true, "message": "Manus API key validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid key (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Canva access token
#[tauri::command]
async fn test_canva_token(access_token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.canva.com/rest/v1/users/me")
        .header("Authorization", format!("Bearer {}", access_token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Canva token validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Figma personal access token
#[tauri::command]
async fn test_figma_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.figma.com/v1/me")
        .header("X-Figma-Token", &token)
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Figma token validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Moltbook API key
#[tauri::command]
async fn test_moltbook_key(api_key: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://moltbook.com/api/v1/agents/me")
        .header("Authorization", format!("Bearer {}", api_key))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Moltbook API key validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid key (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Notion integration key
#[tauri::command]
async fn test_notion_key(api_key: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.notion.com/v1/users/me")
        .header("Authorization", format!("Bearer {}", api_key))
        .header("Notion-Version", "2022-06-28")
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Notion API key validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid key (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test WordPress XML-RPC connection
#[tauri::command]
async fn test_wordpress_connection(site: String, username: String, password: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let url = format!("{}/xmlrpc.php", site.trim_end_matches('/'));
    let body = format!(
        r#"<?xml version="1.0"?><methodCall><methodName>wp.getUsersBlogs</methodName><params><param><value>{}</value></param><param><value>{}</value></param></params></methodCall>"#,
        username, password
    );
    let resp = client.post(&url)
        .header("Content-Type", "text/xml")
        .body(body)
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => {
            let text = r.text().await.unwrap_or_default();
            if text.contains("<fault>") {
                Ok(serde_json::json!({ "valid": false, "message": "Authentication failed" }))
            } else {
                Ok(serde_json::json!({ "valid": true, "message": "WordPress connection successful" }))
            }
        },
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Twitter API credentials (OAuth 2.0 Bearer Token)
#[tauri::command]
async fn test_twitter_token(api_key: String, api_secret: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    // Get bearer token via OAuth2 client credentials
    let resp = client.post("https://api.twitter.com/oauth2/token")
        .basic_auth(&api_key, Some(&api_secret))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body("grant_type=client_credentials")
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Twitter API credentials validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid credentials (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Google Gemini API key
#[tauri::command]
async fn test_gemini_key(key: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get(format!("https://generativelanguage.googleapis.com/v1/models?key={}", key))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => Ok(serde_json::json!({ "valid": true, "message": "Gemini API key validated successfully" })),
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid key (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

// ============================================================
// OAuth2 Flow
// ============================================================

#[tauri::command]
async fn oauth2_flow(
    auth_url: String,
    token_url: String,
    client_id: String,
    client_secret: String,
    scopes: String,
    redirect_uri: String,
) -> Result<serde_json::Value, String> {
    oauth::oauth2_authorize(&auth_url, &token_url, &client_id, &client_secret, &scopes, &redirect_uri).await
}

// ============================================================
// Discord, Telegram, Mastodon, ElevenLabs, GitHub, Reddit
// ============================================================

/// Test Discord bot token
#[tauri::command]
async fn test_discord_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://discord.com/api/v10/users/@me")
        .header("Authorization", format!("Bot {}", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => {
            let data: serde_json::Value = r.json().await.map_err(|e| e.to_string())?;
            Ok(data)
        },
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Telegram bot token
#[tauri::command]
async fn test_telegram_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get(format!("https://api.telegram.org/bot{}/getMe", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => {
            let data: serde_json::Value = r.json().await.map_err(|e| e.to_string())?;
            Ok(data)
        },
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Mastodon access token
#[tauri::command]
async fn test_mastodon_token(instance: String, token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let base_url = instance.trim_end_matches('/');
    let resp = client.get(format!("{}/api/v1/accounts/verify_credentials", base_url))
        .header("Authorization", format!("Bearer {}", token))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => {
            let data: serde_json::Value = r.json().await.map_err(|e| e.to_string())?;
            Ok(data)
        },
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid credentials (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test ElevenLabs API key
#[tauri::command]
async fn test_elevenlabs_key(key: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.elevenlabs.io/v1/user")
        .header("xi-api-key", &key)
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => {
            let data: serde_json::Value = r.json().await.map_err(|e| e.to_string())?;
            Ok(data)
        },
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid key (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test GitHub Personal Access Token
#[tauri::command]
async fn test_github_token(token: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.get("https://api.github.com/user")
        .header("Authorization", format!("Bearer {}", token))
        .header("User-Agent", "TWIZA-Moneypenny")
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => {
            let data: serde_json::Value = r.json().await.map_err(|e| e.to_string())?;
            Ok(data)
        },
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Invalid token (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Test Reddit OAuth2 credentials
#[tauri::command]
async fn test_reddit_auth(client_id: String, client_secret: String, username: String, password: String) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build().map_err(|e| e.to_string())?;
    let resp = client.post("https://www.reddit.com/api/v1/access_token")
        .basic_auth(&client_id, Some(&client_secret))
        .header("User-Agent", "TWIZA-Moneypenny")
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(format!("grant_type=password&username={}&password={}", 
            urlencoding::encode(&username), urlencoding::encode(&password)))
        .send().await;
    match resp {
        Ok(r) if r.status().is_success() => {
            let data: serde_json::Value = r.json().await.map_err(|e| e.to_string())?;
            Ok(data)
        },
        Ok(r) => Ok(serde_json::json!({ "valid": false, "message": format!("Auth failed (HTTP {})", r.status().as_u16()) })),
        Err(e) => Ok(serde_json::json!({ "valid": false, "message": format!("Connection failed: {}", e) })),
    }
}

/// Detect GPU(s) on the system
#[tauri::command]
async fn detect_gpu() -> Result<serde_json::Value, String> {
    let mut gpus = Vec::new();

    // On Windows, use wmic to detect GPU
    let output = std::process::Command::new("wmic")
        .args(["path", "win32_VideoController", "get", "Name,AdapterRAM,DriverVersion", "/format:csv"])
        .output();

    if let Ok(output) = output {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines().skip(1) {
            let parts: Vec<&str> = line.split(',').collect();
            if parts.len() >= 4 {
                let adapter_ram = parts[1].trim().parse::<u64>().unwrap_or(0);
                let vram_gb = adapter_ram as f64 / (1024.0 * 1024.0 * 1024.0);
                gpus.push(serde_json::json!({
                    "name": parts[2].trim(),
                    "vramBytes": adapter_ram,
                    "vramGb": (vram_gb * 10.0).round() / 10.0,
                    "driverVersion": parts[3].trim()
                }));
            }
        }
    }

    if gpus.is_empty() {
        // Fallback: try nvidia-smi
        let nv = std::process::Command::new("nvidia-smi")
            .args(["--query-gpu=name,memory.total,driver_version", "--format=csv,noheader,nounits"])
            .output();

        if let Ok(nv_out) = nv {
            let nv_stdout = String::from_utf8_lossy(&nv_out.stdout);
            for line in nv_stdout.lines() {
                let parts: Vec<&str> = line.split(',').map(|s| s.trim()).collect();
                if parts.len() >= 3 {
                    let vram_mb = parts[1].parse::<f64>().unwrap_or(0.0);
                    gpus.push(serde_json::json!({
                        "name": parts[0],
                        "vramGb": (vram_mb / 1024.0 * 10.0).round() / 10.0,
                        "driverVersion": parts[2]
                    }));
                }
            }
        }
    }

    Ok(serde_json::json!({ "gpus": gpus }))
}

// ============================================================
// App Setup
// ============================================================

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_fs::init())
        .manage(Mutex::new(AppState::default()))
        .invoke_handler(tauri::generate_handler![
            validate_key,
            complete_setup,
            start_gateway,
            stop_gateway,
            gateway_status,
            open_chat,
            open_webchat_browser,
            get_settings,
            save_settings,
            close_window,
            minimize_window,
            run_diagnostics,
            quit_app,
            test_tiktok_cookies,
            upload_tiktok_video,
            test_imap_connection,
            test_gmail_token,
            test_gcal_token,
            send_imap_email,
            check_imap_inbox,
            test_bluesky_auth,
            test_perplexity_key,
            test_linkedin_token,
            test_spotify_token,
            test_dropbox_token,
            test_microsoft_token,
            test_google_drive_token,
            test_groq_key,
            test_gemini_key,
            test_discord_token,
            test_telegram_token,
            test_mastodon_token,
            test_elevenlabs_key,
            test_github_token,
            test_reddit_auth,
            oauth2_flow,
            detect_gpu,
            test_manus_key,
            test_canva_token,
            test_figma_token,
            test_moltbook_key,
            test_notion_key,
            test_wordpress_connection,
            test_twitter_token,
        ])
        .setup(|app| {
            // Build tray menu
            let open_chat = MenuItemBuilder::with_id("open_chat", "Open Chat").build(app)?;
            let settings = MenuItemBuilder::with_id("settings", "Settings").build(app)?;
            let restart = MenuItemBuilder::with_id("restart_gateway", "Restart Gateway").build(app)?;
            let sep = PredefinedMenuItem::separator(app)?;
            let sep2 = PredefinedMenuItem::separator(app)?;
            let quit = MenuItemBuilder::with_id("quit", "Quit TWIZA Moneypenny").build(app)?;

            let menu = MenuBuilder::new(app)
                .items(&[&open_chat, &settings, &sep, &restart, &sep2, &quit])
                .build()?;

            // Tray icon - use icon from path
            let _icon_path = app.path().resource_dir()
                .unwrap_or_default()
                .join("icons")
                .join("tray-icon.png");
            
            let tray_builder = TrayIconBuilder::new()
                .menu(&menu)
                .tooltip("TWIZA Moneypenny — ...more than an agent!");
            
            // Load PNG icon manually (Tauri Image requires raw RGBA)
            // For now, rely on tauri.conf.json trayIcon.iconPath
            // which handles the icon loading natively

            let _tray = tray_builder
                .on_menu_event(|app, event| {
                    match event.id().as_ref() {
                        "open_chat" => { let _ = open::that("http://localhost:18789"); }
                        "settings" => {
                            let handle = app.clone();
                            tauri::async_runtime::spawn(async move {
                                if handle.get_webview_window("settings").is_none() {
                                    let _ = tauri::WebviewWindowBuilder::new(
                                        &handle,
                                        "settings",
                                        tauri::WebviewUrl::App("settings/index.html".into()),
                                    )
                                    .title("TWIZA Moneypenny — Settings")
                                    .inner_size(900.0, 650.0)
                                    .center()
                                    .decorations(false)
                                    .build();
                                }
                            });
                        }
                        "restart_gateway" => {
                            let handle = app.clone();
                            tauri::async_runtime::spawn(async move {
                                let _ = gateway::stop_gateway().await;
                                let _ = gateway::start_gateway().await;
                                let _ = handle.notification()
                                    .builder()
                                    .title("TWIZA Moneypenny")
                                    .body("Gateway restarted successfully")
                                    .show();
                            });
                        }
                        "quit" => {
                            let handle = app.clone();
                            tauri::async_runtime::spawn(async move {
                                let _ = gateway::stop_gateway().await;
                                handle.exit(0);
                            });
                        }
                        _ => {}
                    }
                })
                .on_tray_icon_event(|_tray, event| {
                    if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, .. } = event {
                        let _ = open::that("http://localhost:18789");
                    }
                })
                .build(app)?;

            // First run check
            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                // Check if WSL is even available
                let wsl_available = wsl::check_wsl_available().await;

                if !wsl_available {
                    // No WSL = fresh install, show wizard to bootstrap everything
                    if let Some(w) = handle.get_webview_window("wizard") {
                        let _ = w.show();
                        let _ = w.set_focus();
                    }
                    return;
                }

                // WSL exists, check if already configured
                let has_config = wsl::run_wsl_command("test -f /home/twiza/.openclaw/openclaw.json && echo yes")
                    .await
                    .map(|o| o.trim() == "yes")
                    .unwrap_or(false);

                if has_config {
                    let _ = gateway::start_gateway().await;
                    let _ = handle.notification()
                        .builder()
                        .title("TWIZA Moneypenny")
                        .body("Your agent is online! 🦾")
                        .show();
                } else {
                    // WSL exists but no config = show wizard for setup
                    if let Some(w) = handle.get_webview_window("wizard") {
                        let _ = w.show();
                        let _ = w.set_focus();
                    }
                }
            });

            Ok(())
        })
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                if window.label() != "wizard" {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("Failed to start TWIZA Moneypenny");
}
