# WinFix Disk Space Analyzer 1.1.0 / Analyseur d'espace disque

French is now available in the same standalone script:

```powershell
.\WinFix-DiskSpaceAnalyzer.ps1 -Path "$env:USERPROFILE\Documents" -Language fr
```

- French console messages, application errors, HTML report, dates and size display.
- English remains available with `-Language en` and remains the default.
- Exact bytes, CSV headers, filenames and exit codes remain compatible across languages.
- The ZIP includes README.fr.md and README.md. UTF-8 BOM preserves French accents in Windows PowerShell 5.1.
- Eleven Windows integration scenarios include French reports and errors, alongside the existing read-only, access-denied, junction and 5,000-file tests.

Le français est disponible avec `-Language fr`. Le script, les rapports et les tailles lisibles sont traduits ; les colonnes CSV restent identiques pour la compatibilité. Consultez README.fr.md dans le ZIP pour le guide complet.

Reports measure logical file lengths, not reclaimable disk space. Access errors make totals incomplete. Reports contain names and paths; review before sharing. Native Windows error details retain the OS language.

Local validation on 2026-11-06: all eleven scenarios passed on Windows 10 build 19045 with Windows PowerShell 5.1.19041.7802 and PowerShell 7.6.9. The release workflow requires passing both Windows CI jobs before publication. No clean Windows 11 manual test is claimed.
