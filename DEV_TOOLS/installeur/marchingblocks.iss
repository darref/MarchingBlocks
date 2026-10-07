; L'INSTALLEUR DE MARCHINGBLOCKS — version SITE (DÉCIDÉ par Jordan, 7 octobre 2026 : « un installeur Inno Setup »).
; Il livre l'exe et sa DLL, le contrat et les avis tiers, les raccourcis, les associations de fichiers, et une
; désinstallation propre qui les retire. Steam, lui, livre le dossier tel quel (pas d'installeur).
;
; ⚠ NE SE LANCE PAS SEUL : `DEV_TOOLS/exporter_marchingblocks.sh` le compile avec
;   ISCC.exe /DVersion=0.9.0 /DSource=<dossier site préparé> /DSortie=<dossier de sortie> marchingblocks.iss
; et c'est `preparer_livraison.gd` qui écrit dans <Source> les icônes et `associations.iss` (les clés du registre,
; tirées de `app/associations.gd` : une règle, un endroit).
;
; PROPOSÉ (Claude, 7 octobre 2026) — UNE INSTALLATION PAR UTILISATEUR (PrivilegesRequired=lowest) :
;   • aucune demande d'administrateur (« Voulez-vous autoriser… ») — comme VS Code, Discord ;
;   • le programme va dans %LOCALAPPDATA%\Programs\MarchingBlocks, ses clés dans HKEY_CURRENT_USER — LES MÊMES que
;     celles que l'appli pose elle-même quand elle n'est pas installée (Steam) : la case « File icons » de Project
;     les retire et les remet de la même façon ;
;   • l'appli, installée, ne s'inscrit pas par-dessus (`Associations.installe_par_l_installeur` : unins000.exe).
; ⚠ NON SIGNÉ : Windows SmartScreen avertira (« éditeur inconnu ») tant qu'il n'y a pas de certificat de signature
; de code (OUVERT, charte §0 « la vente »).

#ifndef Version
  #error Version manquante (/DVersion=0.9.0)
#endif
#ifndef Source
  #error Source manquante (/DSource=dossier du site préparé)
#endif
#ifndef Sortie
  #define Sortie "."
#endif

[Setup]
; ⚠ L'AppId NE CHANGE JAMAIS : c'est lui qui fait qu'une version neuve REMPLACE l'ancienne au lieu de s'y ajouter.
AppId={{6B2F3C1E-4D8A-4F0B-9C7E-2A51D3E9B0F4}
AppName=MarchingBlocks
AppVersion={#Version}
AppVerName=MarchingBlocks {#Version}
AppPublisher=SpannerGames
AppCopyright=© 2026 SpannerGames
VersionInfoVersion={#Version}
VersionInfoCompany=SpannerGames
VersionInfoDescription=MarchingBlocks setup
DefaultDirName={autopf}\MarchingBlocks
DefaultGroupName=MarchingBlocks
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile={#Source}\LICENSE.txt
SetupIconFile=..\..\MARQUE\icone.ico
UninstallDisplayIcon={app}\MarchingBlocks.exe
UninstallDisplayName=MarchingBlocks
OutputDir={#Sortie}
OutputBaseFilename=MarchingBlocks-{#Version}-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Les associations changent : l'Explorateur est prévenu (icônes rafraîchies) à l'installation et à la désinstallation.
ChangesAssociations=yes
; L'appli ouverte bloquerait le remplacement de l'exe et de sa DLL : l'installeur propose de la fermer.
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Source}\MarchingBlocks.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Source}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Source}\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Source}\THIRD_PARTY_NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Source}\icones\*.ico"; DestDir: "{app}\icones"; Flags: ignoreversion

[Icons]
Name: "{group}\MarchingBlocks"; Filename: "{app}\MarchingBlocks.exe"
Name: "{group}\{cm:UninstallProgram,MarchingBlocks}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MarchingBlocks"; Filename: "{app}\MarchingBlocks.exe"; Tasks: bureau

#include AddBackslash(Source) + "associations.iss"

[Run]
Filename: "{app}\MarchingBlocks.exe"; Description: "{cm:LaunchProgram,MarchingBlocks}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Les clés du registre partent avec la désinstallation ([Registry], « uninsdelete… ») ; les icônes de {app} aussi.
; Les réglages, la clé de licence et les projets de l'utilisateur RESTENT (Documents\MarchingBlocks, données de l'appli).
; ⚠ PAS LES ICÔNES DES DONNÉES DE L'APPLI ({userappdata}\Godot\app_userdata\MarchingBlocks\icones) : un exe NON
; installé (Steam, un essai) les a peut-être écrites et les désigne encore — essayé le 7 octobre 2026 sur le PC de
; Jordan, la désinstallation les avait emportées sous son exe de développement.
Type: dirifempty; Name: "{app}\icones"
Type: dirifempty; Name: "{app}"
