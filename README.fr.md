# WinFix Kit — Analyseur d’espace disque 1.1.0

[English](README.md) · Français

Repérez les fichiers et dossiers volumineux et générez des rapports HTML et CSV sur votre ordinateur. L’outil analyse les fichiers en lecture seule : il ne les supprime, ne les déplace et ne les téléverse pas.

## Télécharger et utiliser

Téléchargez le script ou le ZIP depuis les [versions stables](https://github.com/DrakkenWorld/winfix-disk-space-analyzer/releases/latest). Le ZIP contient les guides français et anglais. Le script est autonome : aucun module supplémentaire à installer.

Prérequis : Windows avec Windows PowerShell 5.1 ou PowerShell 7. Aucun droit administrateur nécessaire pour vos dossiers personnels. Consultez le code avant de l’exécuter et respectez la politique d’exécution de votre organisation. Si Windows bloque un script téléchargé que vous avez vérifié, vous pouvez utiliser `Unblock-File` sur ce fichier.

```powershell
powershell.exe -NoProfile -File .\WinFix-DiskSpaceAnalyzer.ps1 -Path "$env:USERPROFILE\Documents" -OutputDirectory "$env:USERPROFILE\Desktop\WinFixReport" -Language fr
# Remplacez powershell.exe par pwsh.exe pour PowerShell 7.
```

| Paramètre | Valeur par défaut | Utilisation |
| --- | --- | --- |
| `Path` | Votre profil utilisateur | Dossier existant et accessible à analyser |
| `OutputDirectory` | `WinFixReport` dans le dossier courant | Dossier où écrire les rapports |
| `TopFiles` | 25 | De 1 à 500 fichiers affichés |
| `TopFolders` | 20 | De 1 à 200 sous-dossiers affichés |
| `Language` | `en` | `fr` pour le français, `en` pour l’anglais |

La langue choisie s’applique aux messages de l’outil et au rapport HTML. Les détails d’erreur fournis par Windows conservent la langue du système. Les noms des paramètres restent identiques dans les deux langues.

Choisissez un dossier de destination distinct du dossier analysé. S’il se trouve à l’intérieur de celui-ci, son contenu est exclu du comptage. Chaque exécution produit des noms uniques et conserve les rapports précédents.

## Comprendre les résultats

- `DiskSpaceReport_*.html` : résumé, fichiers et dossiers les plus volumineux et jusqu’à 100 erreurs.
- `LargestFiles_*.csv` : colonnes `Name`, `FullName`, `LengthBytes`, `Size`, `LastWriteTime`.
- `TopLevelFolders_*.csv` : colonnes `Folder`, `LengthBytes`, `Size`, `FilesFound`.

Les colonnes CSV restent en anglais pour permettre leur réutilisation dans vos outils et conserver la compatibilité. `LengthBytes` contient la taille exacte en octets ; `Size` contient une valeur lisible, par exemple `2,00 Ko`. Les unités Ko, Mo, Go et To utilisent des puissances de 1024. Les dates CSV suivent le format ISO 8601 et l’encodage est UTF-8 avec BOM, y compris pour les résultats vides.

Le CSV utilise des virgules comme séparateurs. Importez-le explicitement dans votre tableur si votre configuration française attend des points-virgules. Les cellules textuelles qui pourraient être interprétées comme des formules sont préfixées par une apostrophe. Les noms réels sont conservés dans le rapport HTML, avec un échappement des caractères spéciaux.

Les lignes sont classées par taille numérique décroissante ; l’ordre des ex æquo n’est pas garanti. Les limites d’affichage ne changent pas les totaux du résumé. Les fichiers directement à la racine sont comptabilisés dans le total, mais pas dans une ligne de sous-dossier.

## Limites et confidentialité

L’outil mesure la taille logique des fichiers, pas l’espace occupé sur le disque ni l’espace que vous pouvez supprimer sans risque. Les liens physiques sont comptés par entrée. Les jonctions, liens symboliques et autres points de réanalyse sont ignorés ; un tel point ne peut pas être utilisé comme racine. Certains fichiers à la demande du cloud peuvent donc être exclus.

Un accès refusé ou des fichiers modifiés pendant l’analyse peuvent rendre les totaux incomplets. L’analyse n’est pas un instantané du disque. Les métadonnées sont conservées en mémoire : la consommation augmente avec le nombre de fichiers.

Les rapports révèlent des noms de fichiers, chemins et noms d’utilisateur. Vérifiez leur contenu avant de les partager. Aucun envoi réseau ni télémétrie n’est effectué. Le script écrit uniquement ses rapports et ne modifie ni le contenu ni les permissions des fichiers analysés ; Windows peut mettre à jour des métadonnées d’accès lors de la lecture.

## Automatisation et vérification

Lancez le script dans un processus PowerShell séparé. Codes de sortie : **0**, analyse sans erreur enregistrée ; **1**, erreur fatale ; **2**, rapports générés avec des erreurs d’analyse. Une erreur d’export peut laisser des fichiers partiels.

```powershell
Get-FileHash .\WinFix-DiskSpaceAnalyzer.ps1 -Algorithm SHA256
```

Comparez le résultat au fichier `SHA256SUMS.txt` de la même version. Il s’agit d’une vérification d’intégrité, pas d’une signature du code. Le script n’est pas signé.

Les onze scénarios automatisés se lancent avec `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Run-Tests.ps1`, puis avec `pwsh.exe`. Ils créent leurs propres données temporaires, vérifient les exports et les empreintes des fichiers source, et restaurent les permissions du dossier de test. Voir les [preuves de validation](docs/VALIDATION.md) et [GitHub Actions](https://github.com/DrakkenWorld/winfix-disk-space-analyzer/actions).

[Site en français](https://drakkenworld.github.io/winfix-kit-site/fr/) · [Licence MIT](LICENSE) · [Signalement de sécurité](SECURITY.md)
