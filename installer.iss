; Скрипт для Inno Setup
[Setup]
AppName=SysAdm Notes
AppVersion=1.0.0
AppPublisher=arni30rus
DefaultDirName={autopf}\SysAdm Notes
DefaultGroupName=SysAdm Notes
UninstallDisplayIcon={app}\sysadmin_notes.exe
OutputDir=installer_output
OutputBaseFilename=SysAdmNotes_Setup_v1.0.0
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=assets\logo.ico

[Files]
; Берем все файлы из папки Release
Source: "D:\projects\sysadmin_notes\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Создаем ярлыки в меню Пуск и на Рабочем столе
Name: "{group}\SysAdm Notes"; Filename: "{app}\sysadmin_notes.exe"
Name: "{commondesktop}\SysAdm Notes"; Filename: "{app}\sysadmin_notes.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать значок на Рабочем столе"; GroupDescription: "Дополнительные значки:"

[Run]
; Предлагаем запустить приложение после установки
Filename: "{app}\sysadmin_notes.exe"; Description: "Запустить SysAdm Notes"; Flags: nowait postinstall skipifsilent