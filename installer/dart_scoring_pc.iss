; Dart Scoring PC - Inno Setup Installer
; Datei speichern als: installer\dart_scoring_pc.iss
;
; Wichtig:
; - AppId NIEMALS ändern, sonst erkennt Windows spätere Updates nicht als dieselbe App.
; - MyAppVersion bei jeder neuen Beta erhöhen.
; - Vorher immer: flutter build windows --release

#define MyAppName "Dart Scoring PC"
#define MyAppPublisher "dejojo"
#define MyAppExeName "dart_scoring_pc.exe"

#ifndef MyAppVersion
#define MyAppVersion "1.0.0.2-beta.1"
#endif

[Setup]
AppId={{0E69E0DF-2208-4F0F-90A8-8E8648080C6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Dart Scoring PC
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=DartScoringPC-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "Desktop-Verknüpfung erstellen"; GroupDescription: "Zusätzliche Aufgaben:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Dart Scoring PC deinstallieren"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{#MyAppName} starten"; Flags: nowait postinstall skipifsilent
