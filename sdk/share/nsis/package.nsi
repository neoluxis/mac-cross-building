Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel admin
ManifestDPIAware true

!ifdef APP_ICON
  Icon "${APP_ICON}"
!endif

!ifdef BUILD_INSTALLER
  OutFile "${OUTPUT_DIR}/${APP_ID}-${APP_VERSION}-setup.exe"
  InstallDir "$PROGRAMFILES64\${APP_NAME}"
  InstallDirRegKey HKLM "Software\${APP_ID}" "InstallDir"
  Page directory
  Page instfiles
  UninstPage uninstConfirm
  UninstPage instfiles
!else ifdef BUILD_UPDATE
  OutFile "${OUTPUT_DIR}/${APP_ID}-${APP_VERSION}-update.exe"
  SilentInstall silent
  AutoCloseWindow true
!endif

Name "${APP_NAME} ${APP_VERSION}"
VIProductVersion "${PRODUCT_VERSION}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "FileDescription" "${APP_NAME} installer"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "LegalCopyright" "${PUBLISHER}"
VIAddVersionKey "FileVersion" "${APP_VERSION}"

!ifdef BUILD_UPDATE
Function .onInit
  SetRegView 64
  ReadRegStr $INSTDIR HKLM "Software\${APP_ID}" "InstallDir"
  StrCmp $INSTDIR "" update_install_dir_found
    ReadRegStr $INSTDIR HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}" "InstallLocation"
  StrCmp $INSTDIR "" update_install_dir_found
    MessageBox MB_ICONSTOP "${APP_NAME} is not installed."
    Abort
  update_install_dir_found:
FunctionEnd
!endif

Section "Install"
  SetRegView 64
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${SOURCE_DIR}\*"
  WriteRegStr HKLM "Software\${APP_ID}" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}" "UninstallString" "$INSTDIR\uninstall.exe"
  !ifdef BUILD_INSTALLER
    WriteUninstaller "$INSTDIR\uninstall.exe"
    CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${MAIN_EXE}"
  !endif
SectionEnd

!ifdef BUILD_INSTALLER
Section "Uninstall"
  SetRegView 64
  SetShellVarContext current
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"
  DeleteRegKey HKLM "Software\${APP_ID}"
SectionEnd
!endif
