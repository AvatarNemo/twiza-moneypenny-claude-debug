# TWIZA Moneypenny Complete Windows Installer
# NSIS Script per installer Windows unificato

!define PRODUCT_NAME "TWIZA Moneypenny"
!define PRODUCT_VERSION "2.2.1"
!define PRODUCT_PUBLISHER "SHAKAZAMBA S.r.l."
!define PRODUCT_WEB_SITE "https://shakazamba.com"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

# Modern UI
!include "MUI2.nsh"
!include "WinVer.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"

# Installer settings
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "TWIZA-Moneypenny-${PRODUCT_VERSION}-Complete-Installer.exe"
InstallDir "$PROGRAMFILES64\SHAKAZAMBA\TWIZA"
InstallDirRegKey HKLM "Software\SHAKAZAMBA\TWIZA" "InstallDir"
RequestExecutionLevel admin
ShowInstDetails show
ShowUnInstDetails show

# Modern UI Configuration
!define MUI_ABORTWARNING
!define MUI_ICON "assets\twiza-icon.ico"
!define MUI_UNICON "assets\twiza-icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\twiza-welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "assets\twiza-welcome.bmp"

# Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\TWIZA-Moneypenny.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Avvia TWIZA Moneypenny ora"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

# Languages
!insertmacro MUI_LANGUAGE "Italian"
!insertmacro MUI_LANGUAGE "English"

# Version Info
VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey /LANG=${LANG_ITALIAN} "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=${LANG_ITALIAN} "Comments" "TWIZA - Piattaforma AI Brevettata by SHAKAZAMBA"
VIAddVersionKey /LANG=${LANG_ITALIAN} "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey /LANG=${LANG_ITALIAN} "LegalTrademarks" "BREVETTO UIBM N. 102024000025755"
VIAddVersionKey /LANG=${LANG_ITALIAN} "FileDescription" "${PRODUCT_NAME} Complete Installer"
VIAddVersionKey /LANG=${LANG_ITALIAN} "FileVersion" "${PRODUCT_VERSION}.0"
VIAddVersionKey /LANG=${LANG_ITALIAN} "ProductVersion" "${PRODUCT_VERSION}.0"

# Installer Sections
Section "TWIZA Core Application" SEC01
  SectionIn RO  ; Required
  SetDetailsPrint textonly
  DetailPrint "Installazione TWIZA Core Application..."
  SetDetailsPrint listonly
  
  SetOutPath "$INSTDIR"
  SetOverwrite ifnewer
  
  # Extract main application
  File "TWIZA-Moneypenny-2.2.1-Setup.exe"
  File "README-COMPLETE-INSTALLER.md"
  
  # Execute the Electron app installer silently
  DetailPrint "Installazione applicazione desktop..."
  ExecWait '"$INSTDIR\TWIZA-Moneypenny-2.2.1-Setup.exe" /S' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "Errore durante l'installazione dell'applicazione desktop. Codice errore: $0"
    Abort
  ${EndIf}
  
  # Create desktop shortcut
  CreateShortCut "$DESKTOP\TWIZA Moneypenny.lnk" "$LOCALAPPDATA\Programs\twiza-moneypenny\TWIZA Moneypenny.exe"
  
  # Create start menu shortcuts
  CreateDirectory "$SMPROGRAMS\SHAKAZAMBA"
  CreateShortCut "$SMPROGRAMS\SHAKAZAMBA\TWIZA Moneypenny.lnk" "$LOCALAPPDATA\Programs\twiza-moneypenny\TWIZA Moneypenny.exe"
  CreateShortCut "$SMPROGRAMS\SHAKAZAMBA\Disinstalla TWIZA.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

Section "WSL2 + Ubuntu Environment" SEC02
  SectionIn RO  ; Required
  SetDetailsPrint textonly
  DetailPrint "Configurazione ambiente WSL2 + Ubuntu..."
  SetDetailsPrint listonly
  
  SetOutPath "$TEMP\twiza-installer"
  SetOverwrite ifnewer
  
  # Extract WSL components
  File "Ubuntu-22.04-WSL.appx"
  File "install-twiza-complete.ps1"
  
  # Check if WSL2 is enabled
  DetailPrint "Verifica WSL2..."
  ExecWait 'powershell.exe -Command "& {if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq \"Disabled\") {exit 1} else {exit 0}}"' $0
  ${If} $0 != 0
    DetailPrint "Abilitazione WSL2... (potrebbe richiedere riavvio)"
    ExecWait 'powershell.exe -Command "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart; Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart"' $1
    ${If} $1 != 0
      MessageBox MB_ICONEXCLAMATION|MB_YESNO "Impossibile abilitare WSL2 automaticamente. Vuoi continuare manualmente?" IDYES cont IDNO abort
      abort:
        Abort
      cont:
    ${Else}
      MessageBox MB_ICONINFORMATION|MB_YESNO "WSL2 abilitato. È necessario riavviare il sistema. Vuoi riavviare ora?" IDYES reboot IDNO noreboot
      reboot:
        Reboot
      noreboot:
    ${EndIf}
  ${EndIf}
  
  # Install Ubuntu WSL
  DetailPrint "Installazione Ubuntu WSL..."
  ExecWait 'powershell.exe -ExecutionPolicy Bypass -File "$TEMP\twiza-installer\install-twiza-complete.ps1"' $2
  ${If} $2 != 0
    MessageBox MB_ICONEXCLAMATION "Installazione WSL completata con avvisi. Codice: $2$\n$\nL'installazione continuerà, ma potresti dover configurare WSL manualmente."
  ${EndIf}
  
  # Cleanup temp files
  Delete "$TEMP\twiza-installer\Ubuntu-22.04-WSL.appx"
  Delete "$TEMP\twiza-installer\install-twiza-complete.ps1"
  RMDir "$TEMP\twiza-installer"
SectionEnd

Section "OpenClaw Framework" SEC03
  SetDetailsPrint textonly
  DetailPrint "Installazione OpenClaw Framework..."
  SetDetailsPrint listonly
  
  # OpenClaw will be installed by the PowerShell script in SEC02
  # This section is mainly for organization and future expansion
  
  DetailPrint "OpenClaw Framework configurato tramite WSL environment"
SectionEnd

# Descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC01} "Applicazione desktop TWIZA Moneypenny (Richiesto)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC02} "Ambiente WSL2 + Ubuntu con Ollama e OpenClaw (Richiesto)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC03} "Framework OpenClaw per gestione AI agents (Incluso in WSL)"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

# Installer Functions
Function .onInit
  # Check Windows version (Windows 10 2004+ or Windows 11)
  ${If} ${AtMostWin10}
    ${AndIf} ${AtMostWinBuild} 19041
      MessageBox MB_ICONSTOP "TWIZA richiede Windows 10 versione 2004 (build 19041) o superiore."
      Abort
  ${EndIf}
  
  # Check if running as administrator
  UserInfo::GetAccountType
  Pop $0
  ${If} $0 != "admin"
    MessageBox MB_ICONSTOP "Questo installer deve essere eseguito come Amministratore.$\n$\nCliccare tasto destro e selezionare 'Esegui come amministratore'."
    Abort
  ${EndIf}
  
  # Check for existing installation
  ReadRegStr $0 HKLM "Software\SHAKAZAMBA\TWIZA" "InstallDir"
  ${If} $0 != ""
    ${AndIf} ${FileExists} "$0\uninstall.exe"
      MessageBox MB_ICONQUESTION|MB_YESNO "TWIZA è già installato in:$\n$0$\n$\nVuoi disinstallare la versione precedente?" IDYES uninst IDNO cont
      uninst:
        ExecWait "$0\uninstall.exe _?=$0"
        ${If} ${FileExists} "$0\uninstall.exe"
          MessageBox MB_ICONSTOP "Disinstallazione annullata dall'utente."
          Abort
        ${EndIf}
      cont:
  ${EndIf}
SectionEnd

# Uninstaller
Section Uninstall
  # Remove desktop shortcuts
  Delete "$DESKTOP\TWIZA Moneypenny.lnk"
  
  # Remove start menu
  Delete "$SMPROGRAMS\SHAKAZAMBA\TWIZA Moneypenny.lnk"
  Delete "$SMPROGRAMS\SHAKAZAMBA\Disinstalla TWIZA.lnk"
  RMDir "$SMPROGRAMS\SHAKAZAMBA"
  
  # Remove application (try to uninstall Electron app)
  ExecWait '"$LOCALAPPDATA\Programs\twiza-moneypenny\Uninstall TWIZA Moneypenny.exe" /S'
  
  # Remove installation directory
  Delete "$INSTDIR\TWIZA-Moneypenny-2.2.1-Setup.exe"
  Delete "$INSTDIR\README-COMPLETE-INSTALLER.md"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  RMDir "$PROGRAMFILES64\SHAKAZAMBA"
  
  # Remove registry keys
  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  DeleteRegKey HKLM "Software\SHAKAZAMBA\TWIZA"
  DeleteRegKey HKLM "Software\SHAKAZAMBA"
  
  # Note: WSL Ubuntu installation is NOT removed automatically
  # The user can remove it manually with: wsl --unregister Ubuntu
  MessageBox MB_ICONINFORMATION "Disinstallazione completata.$\n$\nL'ambiente WSL Ubuntu non è stato rimosso.$\nSe desideri rimuoverlo, esegui: wsl --unregister Ubuntu"
SectionEnd

# Write uninstaller info
Section -Post
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\SHAKAZAMBA\TWIZA" "InstallDir" "$INSTDIR"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\TWIZA-Moneypenny.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoModify" 1
  WriteRegDWORD ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "NoRepair" 1
SectionEnd