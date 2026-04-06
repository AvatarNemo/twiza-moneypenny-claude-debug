// TWIZA Moneypenny — OpenClaw Gateway Management

use crate::wsl;

/// Start the OpenClaw gateway inside WSL
pub async fn start_gateway() -> Result<(), String> {
    // Check if already running
    if check_gateway_health().await {
        return Ok(());
    }

    // Start gateway in background
    wsl::run_wsl_command(
        "nohup openclaw gateway start > /tmp/openclaw-gateway.log 2>&1 &"
    ).await.map_err(|e| format!("Failed to start gateway: {}", e))?;

    // Wait for it to come up (max 15 seconds)
    for i in 0..30 {
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        if check_gateway_health().await {
            return Ok(());
        }
        if i == 10 {
            // After 5 seconds, check if process is still alive
            let alive = wsl::run_wsl_command("pgrep -f 'openclaw gateway' || echo 'dead'")
                .await
                .unwrap_or_else(|_| "dead".to_string());
            if alive.trim() == "dead" {
                // Read logs for error info
                let logs = wsl::run_wsl_command("tail -20 /tmp/openclaw-gateway.log 2>/dev/null")
                    .await
                    .unwrap_or_else(|_| "No logs available".to_string());
                return Err(format!("Gateway process died. Logs:\n{}", logs.trim()));
            }
        }
    }

    Err("Gateway failed to start within 15 seconds".into())
}

/// Stop the OpenClaw gateway
pub async fn stop_gateway() -> Result<(), String> {
    wsl::run_wsl_command("openclaw gateway stop 2>/dev/null; pkill -f 'openclaw gateway' 2>/dev/null; true")
        .await
        .map_err(|e| format!("Failed to stop gateway: {}", e))?;

    // Wait for port to be released
    for _ in 0..10 {
        if !check_gateway_health().await {
            return Ok(());
        }
        tokio::time::sleep(std::time::Duration::from_millis(300)).await;
    }

    Ok(())
}

/// Check if the gateway is responding
pub async fn check_gateway_health() -> bool {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(3))
        .build()
        .unwrap_or_default();

    client.get("http://localhost:18789")
        .send()
        .await
        .map(|r| r.status().is_success() || r.status().as_u16() == 304)
        .unwrap_or(false)
}

#[allow(dead_code)]
/// Restart the gateway (stop + start)
pub async fn restart_gateway() -> Result<(), String> {
    stop_gateway().await?;
    tokio::time::sleep(std::time::Duration::from_secs(1)).await;
    start_gateway().await
}
