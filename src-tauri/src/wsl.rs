// TWIZA Moneypenny — WSL2 Interface
// All communication with the WSL backend goes through here.

use std::process::Stdio;
use tokio::process::Command;
// tokio::fs used for log file tailing in run_powershell_script

const WSL_DISTRO: &str = "Ubuntu";
const WSL_USER: &str = "twiza";

/// Check if WSL2 is available and the distro is installed
pub async fn check_wsl_available() -> bool {
    // Use timeout because `wsl --list` can hang on Windows 11 when WSL feature
    // is enabled but no distro is installed (triggers Microsoft Store download).
    let result = tokio::time::timeout(
        std::time::Duration::from_secs(10),
        Command::new("wsl")
            .args(["--list", "--quiet"])
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
    ).await;

    match result {
        Ok(Ok(o)) => {
            let stdout = String::from_utf8_lossy(&o.stdout);
            stdout.lines().any(|line| line.trim().contains(WSL_DISTRO))
        }
        _ => false, // Timeout or error = WSL not available
    }
}

/// Run a command inside WSL and return stdout
pub async fn run_wsl_command(cmd: &str) -> Result<String, String> {
    let output = Command::new("wsl")
        .args(["-d", WSL_DISTRO, "-u", WSL_USER, "--", "bash", "-lc", cmd])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .map_err(|e| format!("Failed to execute WSL command: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        Err(format!(
            "WSL command failed (exit {}): {} {}",
            output.status.code().unwrap_or(-1),
            stderr.trim(),
            stdout.trim()
        ))
    }
}

/// Run a PowerShell script with streaming output via callback.
/// Auto-elevates via UAC if needed (uses a log file for streaming since
/// elevated processes can't pipe stdout back to the non-elevated parent).
pub async fn run_powershell_script<F>(
    script_path: &str,
    skip_ollama: bool,
    config_json: &str,
    on_line: F,
) -> Result<(), String>
where
    F: Fn(String) + Send + 'static,
{
    let temp_dir = std::env::temp_dir();
    let log_path = temp_dir.join("twiza-bootstrap.log");
    let done_path = temp_dir.join("twiza-bootstrap.done");
    let config_path = temp_dir.join("twiza-bootstrap-config.json");

    // Clean up previous run artifacts
    let _ = std::fs::remove_file(&log_path);
    let _ = std::fs::remove_file(&done_path);

    // Write config to a temp file (avoids command-line length limits)
    if !config_json.is_empty() {
        std::fs::write(&config_path, config_json)
            .map_err(|e| format!("Failed to write config file: {}", e))?;
    }

    // Build the inner command that the elevated PowerShell will run
    let mut inner_args = format!(
        "-ExecutionPolicy Bypass -File \"{}\"",
        script_path
    );
    if skip_ollama {
        inner_args.push_str(" -SkipOllama");
    }
    if !config_json.is_empty() {
        inner_args.push_str(&format!(" -ConfigJson (Get-Content '{}' -Raw)", config_path.to_string_lossy()));
    }

    // Create a wrapper script that:
    // 1. Runs the bootstrap with output redirected to a log file
    // 2. Writes a .done marker with the exit code when finished
    let wrapper = format!(
        r#"
$ErrorActionPreference = "Stop"
try {{
    & powershell.exe {inner_args} *>&1 | Tee-Object -FilePath "{log}" -Append
    $code = $LASTEXITCODE
    if ($null -eq $code) {{ $code = 0 }}
}} catch {{
    $_ | Out-File -FilePath "{log}" -Append
    $code = 99
}}
"EXIT:$code" | Out-File -FilePath "{done}" -Encoding utf8
"#,
        inner_args = inner_args,
        log = log_path.to_string_lossy().replace('\\', "\\\\"),
        done = done_path.to_string_lossy().replace('\\', "\\\\"),
    );

    let wrapper_path = temp_dir.join("twiza-bootstrap-wrapper.ps1");
    std::fs::write(&wrapper_path, &wrapper)
        .map_err(|e| format!("Failed to write wrapper script: {}", e))?;

    on_line("Requesting administrator privileges (UAC)...\n".to_string());

    // Launch elevated via Start-Process -Verb RunAs
    let elevate_cmd = format!(
        "Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList '-ExecutionPolicy','Bypass','-File','\"{}\"'",
        wrapper_path.to_string_lossy()
    );

    let elevate_result = Command::new("powershell")
        .args(["-ExecutionPolicy", "Bypass", "-Command", &elevate_cmd])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .map_err(|e| format!("Failed to request elevation: {}", e))?;

    if !elevate_result.status.success() {
        let stderr = String::from_utf8_lossy(&elevate_result.stderr);
        if stderr.contains("canceled") || stderr.contains("cancelled") || stderr.contains("The operation was canceled") {
            return Err("UAC elevation was cancelled by the user.".into());
        }
        return Err(format!("Failed to elevate: {}", stderr.trim()));
    }

    on_line("✓ Elevated. Running bootstrap...\n".to_string());

    // Tail the log file until the .done marker appears
    let mut last_pos: u64 = 0;
    let poll_interval = std::time::Duration::from_millis(500);
    let timeout = std::time::Duration::from_secs(600); // 10 min max
    let start = std::time::Instant::now();

    loop {
        if start.elapsed() > timeout {
            return Err("Bootstrap timed out after 10 minutes".into());
        }

        // Read new content from log file
        if let Ok(content) = tokio::fs::read_to_string(&log_path).await {
            let bytes = content.as_bytes();
            if (bytes.len() as u64) > last_pos {
                let new_content = &content[(last_pos as usize)..];
                for line in new_content.lines() {
                    if !line.is_empty() {
                        on_line(format!("{}\n", line));
                    }
                }
                last_pos = bytes.len() as u64;
            }
        }

        // Check if done
        if let Ok(done_content) = tokio::fs::read_to_string(&done_path).await {
            let done_content = done_content.trim();
            if let Some(code_str) = done_content.strip_prefix("EXIT:") {
                let code: i32 = code_str.trim().parse().unwrap_or(-1);
                // Read any remaining log content
                if let Ok(content) = tokio::fs::read_to_string(&log_path).await {
                    if (content.as_bytes().len() as u64) > last_pos {
                        let new_content = &content[(last_pos as usize)..];
                        for line in new_content.lines() {
                            if !line.is_empty() {
                                on_line(format!("{}\n", line));
                            }
                        }
                    }
                }
                // Cleanup temp files
                let _ = std::fs::remove_file(&log_path);
                let _ = std::fs::remove_file(&done_path);
                let _ = std::fs::remove_file(&wrapper_path);
                let _ = std::fs::remove_file(&config_path);

                if code == 0 {
                    return Ok(());
                } else if code == 2 {
                    return Err("RESTART_REQUIRED".into());
                } else {
                    return Err(format!("Bootstrap script failed with exit code {}", code));
                }
            }
        }

        tokio::time::sleep(poll_interval).await;
    }
}

/// Run a command inside WSL as root and return stdout
pub async fn run_wsl_command_as_root(cmd: &str) -> Result<String, String> {
    let output = Command::new("wsl")
        .args(["-d", WSL_DISTRO, "-u", "root", "--", "bash", "-lc", cmd])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .map_err(|e| format!("Failed to execute WSL command as root: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        Err(format!(
            "WSL root command failed (exit {}): {} {}",
            output.status.code().unwrap_or(-1),
            stderr.trim(),
            stdout.trim()
        ))
    }
}

/// Ensure the 'twiza' user exists in WSL, creating it if needed
pub async fn ensure_twiza_user() -> Result<(), String> {
    run_wsl_command_as_root(
        "id -u twiza 2>/dev/null || (useradd -m -s /bin/bash twiza && echo 'twiza:twiza' | chpasswd && usermod -aG sudo twiza && echo 'twiza ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/twiza)"
    ).await?;
    Ok(())
}

#[allow(dead_code)]
/// Check if a specific user exists in WSL
pub async fn check_user_exists(user: &str) -> bool {
    run_wsl_command(&format!("id {} 2>/dev/null", user))
        .await
        .is_ok()
}

#[allow(dead_code)]
/// Get available disk space in WSL (in GB)
pub async fn get_disk_space_gb() -> Result<f64, String> {
    let output = run_wsl_command("df -BG /home | tail -1 | awk '{print $4}' | tr -d 'G'").await?;
    output.trim().parse::<f64>().map_err(|e| format!("Parse error: {}", e))
}

#[allow(dead_code)]
/// Check if NVIDIA GPU is available in WSL
pub async fn check_gpu_available() -> Result<serde_json::Value, String> {
    let output = run_wsl_command("nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader,nounits 2>/dev/null").await;
    
    match output {
        Ok(o) => {
            let line = o.trim();
            if line.is_empty() {
                return Ok(serde_json::json!({ "available": false }));
            }
            let parts: Vec<&str> = line.split(", ").collect();
            if parts.len() >= 3 {
                Ok(serde_json::json!({
                    "available": true,
                    "name": parts[0],
                    "vram_total_mb": parts[1].trim().parse::<u64>().unwrap_or(0),
                    "vram_free_mb": parts[2].trim().parse::<u64>().unwrap_or(0),
                }))
            } else {
                Ok(serde_json::json!({ "available": true, "name": line }))
            }
        }
        Err(_) => Ok(serde_json::json!({ "available": false })),
    }
}
