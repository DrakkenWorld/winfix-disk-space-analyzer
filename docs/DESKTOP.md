# Desktop application / Application Windows

## Français

1. Télécharger l’EXE Windows x64 depuis la release GitHub officielle. Le ZIP facultatif regroupe aussi les guides et licences.
2. Ouvrir l’application par double-clic, sans commande et sans droits administrateur.
3. Choisir un dossier avec **Choisir…**, puis **Analyser**.
4. Consulter les onglets **Fichiers volumineux**, **Sous-dossiers directs** et **Erreurs d’accès**.
5. Utiliser **Ouvrir le rapport HTML** ou **Exporter HTML + CSV** pour enregistrer les rapports localement.

Le compteur affiche les fichiers trouvés et leur taille. La barre indique une activité, pas un pourcentage : le nombre total d’éléments n’est pas connu d’avance. **Annuler** interrompt le parcours dès que l’opération de lecture en cours rend la main. Une lecture lente sur un disque ou partage réseau peut retarder l’annulation. Fermer la fenêtre pendant l’analyse demande aussi l’annulation, puis attend l’arrêt du moteur.

Le français est sélectionné automatiquement sur un système configuré en français ; le menu permet de changer de langue. Les rapports sont générés dans la langue choisie lors de leur ouverture/export. Les en-têtes CSV et tailles exactes en octets restent compatibles avec la version PowerShell ; la colonne `Size` est traduite. Importer le CSV en choisissant la virgule comme séparateur dans un tableur français.

Par défaut les rapports vont dans `Documents/WinFixReports`. Les **Options avancées** permettent de changer ce dossier et les limites (1–500 fichiers, 1–200 dossiers). Le dossier des rapports est exclu s’il se trouve dans le dossier analysé. Il doit être distinct de la racine analysée. Chaque export porte un nom unique ; les rapports précédents ne sont pas écrasés. Changer le dossier à analyser efface les résultats précédents.

Les points de réanalyse, jonctions et liens symboliques sont ignorés. Les totaux représentent la taille logique, pas l’espace disque libérable. Les fichiers à liens physiques sont comptés par entrée. Les accès refusés rendent les totaux incomplets. Les détails d’erreur conservent la langue de Windows. L’interface affiche au plus 1 000 erreurs ; le rapport HTML en affiche 100 avec un total global.

Aucune modification du contenu ni des permissions des fichiers analysés, aucun envoi réseau, aucun nettoyage. Les exports et le cache temporaire .NET sont les seules écritures applicatives. Les rapports contiennent des chemins privés : vérifier avant de partager.

L’exécutable est autonome, non signé et réservé à Windows x64. Aucun test manuel sur une installation Windows 11 propre n’est revendiqué. Le lancement sur Windows 10 et les tests du moteur sont documentés dans VALIDATION.md.

## English

Download the Windows x64 EXE, double-click it, choose a folder and click **Analyze**. No terminal, installer, PowerShell or separate .NET installation required. Switch English/French in the language menu. Advanced options select the report directory and result limits. **Open HTML report** saves and opens the report; **Export HTML + CSV** saves the reports and opens their folder. Cancelling generates no reports. The progress bar indicates activity, not a percentage. Closing during a scan requests cancellation and waits for the current filesystem operation to return.

Scanning never changes source content or permissions and performs no network requests. Reparse points are skipped, hard links count per entry, totals are logical lengths and may be incomplete when access is denied. Reports contain private paths. The unsigned executable includes .NET and may use its native-library extraction cache. Runtime licenses are embedded in About and supplied with the release.

## Build and test (developers)

Requires Windows and .NET SDK 10. There are no third-party NuGet library dependencies. Framework/runtime packs come from the official NuGet source declared in `desktop/NuGet.Config`.

```powershell
dotnet restore desktop/WinFix.Tests/WinFix.Tests.csproj --configfile desktop/NuGet.Config
dotnet run --project desktop/WinFix.Tests/WinFix.Tests.csproj -c Release --no-restore
./desktop/Build-Portable.ps1
```

The build script produces `artifacts/win-x64/WinFix-DiskSpaceAnalyzer.exe` and `DOTNET-NOTICES.txt`. It embeds runtime notices in the executable before publishing. A separately generated PDB is optional developer data and not required by the EXE. CI runs native integration tests and both PowerShell editions before publishing any release. Release assets include the portable EXE, desktop ZIP, PowerShell script and ZIP, runtime notices and SHA-256 checksums.

Future releases must update the bundled runtime through a fresh build; the desktop application does not self-update. Code signing requires the maintainer’s signing identity and is not configured here.
