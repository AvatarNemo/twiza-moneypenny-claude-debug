# TWIZA v26 - Installer Modifications Plan

## 🔥 MODIFICHE TAURI INSTALLER

### 1. BUNDLE OFFLINE COMPONENTS
```
src-tauri/
├── resources/
│   ├── offline-installer/
│   │   ├── wsl_update_x64.msi (17MB)
│   │   ├── ubuntu-2204.appx (1GB)
│   │   ├── node-v20.15.1-x64.msi (26MB)
│   │   ├── OllamaSetup.exe (?)
│   │   └── models/
│   │       ├── gemini-2b.gguf
│   │       └── qwen-1.5b.gguf
│   └── install-scripts/
│       ├── install-wsl2.ps1
│       ├── install-node.ps1
│       ├── install-ollama.ps1
│       └── setup-openclaw.ps1
```

### 2. RUST BACKEND MODIFICATIONS
```rust
// src-tauri/src/installer.rs
pub struct OfflineInstaller {
    pub components_path: PathBuf,
    pub temp_dir: PathBuf,
}

impl OfflineInstaller {
    pub fn extract_components(&self) -> Result<()> {
        // Estrai da bundle embedded
    }
    
    pub fn install_wsl2_silent(&self) -> Result<()> {
        // PowerShell silent install
    }
    
    pub fn install_node_silent(&self) -> Result<()> {
        // MSI silent install
    }
}
```

### 3. FRONTEND WIZARD UPDATES
```javascript
// src/lib/installer.js
export class TWIZAInstaller {
    async installOfflineComponents(progressCallback) {
        const steps = [
            { name: 'WSL2', handler: this.installWSL2 },
            { name: 'Node.js', handler: this.installNode },
            { name: 'Ollama', handler: this.installOllama },
            { name: 'OpenClaw', handler: this.setupOpenClaw }
        ];
        
        for (let i = 0; i < steps.length; i++) {
            progressCallback((i / steps.length) * 100);
            await steps[i].handler();
        }
    }
}
```

### 4. POWERSHELL SILENT INSTALLS
```powershell
# install-wsl2.ps1
$WSLInstaller = "wsl_update_x64.msi"
Start-Process msiexec.exe -ArgumentList "/i $WSLInstaller /quiet /norestart" -Wait

# Abilita WSL feature
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Install Ubuntu appx
Add-AppxPackage -Path "ubuntu-2204.appx"
```

## 🎯 IMPLEMENTAZIONE PRIORITY:
1. **Setup bundle structure** nel progetto Tauri
2. **Modify Cargo.toml** per includere resources
3. **Update installer backend** per offline mode
4. **Test su VM pulita** (SEMPRE!)

**DIO BESTIA INFILZATA!** Installer che funziona OFFLINE o morte!