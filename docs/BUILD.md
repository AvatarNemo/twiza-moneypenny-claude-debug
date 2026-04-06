# TWIZA Moneypenny — Windows Build Guide

## Prerequisites

### Required Software

1. **Rust** (latest stable)
   ```powershell
   # Install via rustup
   winget install Rustlang.Rustup
   # Or download from https://rustup.rs
   rustup default stable
   ```

2. **Node.js** (v18+ LTS recommended)
   ```powershell
   winget install OpenJS.NodeJS.LTS
   ```

3. **Visual Studio Build Tools 2022**
   - Install "Desktop development with C++" workload
   - Required components: MSVC v143, Windows 10/11 SDK
   ```powershell
   winget install Microsoft.VisualStudio.2022.BuildTools
   ```

4. **Tauri CLI**
   ```bash
   cargo install tauri-cli
   ```

## Build Instructions

### 1. Install dependencies
```bash
npm install
```

### 2. Development mode
```bash
npm run tauri:dev
```
This starts the Tauri dev server with hot-reload for the frontend.

### 3. Production build (NSIS + MSI)
```bash
npm run tauri:build
```
Output: `src-tauri/target/release/bundle/`
- NSIS installer: `bundle/nsis/TWIZA-Moneypenny_0.1.0_x64-setup.exe`
- MSI installer: `bundle/msi/TWIZA-Moneypenny_0.1.0_x64_en-US.msi`

### 4. Build NSIS only
```bash
npm run tauri:build:nsis
```

### 5. Build for specific MSVC target
```bash
npm run tauri:build:msi
```

## Bundle Configuration

The Tauri bundle config in `src-tauri/tauri.conf.json` produces:
- **NSIS** — full installer with install mode selection (per-user or per-machine)
- **MSI** — Windows Installer package for enterprise/GPO deployment

Icons are sourced from `src-tauri/icons/`:
- `32x32.png`, `128x128.png` — app icons
- `icon.ico` — Windows ICO format
- `tray-icon.png` — system tray

## Troubleshooting

### `error: linker 'link.exe' not found`
Install Visual Studio Build Tools with the C++ workload. Ensure MSVC is on your PATH:
```powershell
# Verify
where link.exe
```

### `error[E0463]: can't find crate for std`
Your Rust toolchain may be incomplete. Run:
```bash
rustup target add x86_64-pc-windows-msvc
rustup component add rust-std
```

### `npm run tauri:build` hangs or is very slow
First build compiles all Rust dependencies (~5-10 min). Subsequent builds are incremental.

### WebView2 missing on target machine
Tauri 2 uses WebView2 (preinstalled on Windows 10 21H2+ and Windows 11). For older systems, the NSIS installer can bundle the WebView2 bootstrapper — see [Tauri docs](https://v2.tauri.app/distribute/windows-installer/).

### Icon generation
If you need to regenerate icons from a source PNG:
```bash
cargo tauri icon assets/branding/twiza-icon.png
```

### Build fails with "resource not found"
Ensure the `resources` paths in `tauri.conf.json` exist:
- `../workspace-template/` — agent workspace templates
- `../scripts/` — bootstrap scripts
