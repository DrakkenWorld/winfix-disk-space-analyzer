# WinFix Disk Space Analyzer 1.2.0

## Application Windows / Windows application

Double-cliquez sur **WinFix-DiskSpaceAnalyzer-Windows-x64.exe**, choisissez un dossier et cliquez sur **Analyser**. Aucune commande, installation de PowerShell ou installation de .NET nécessaire. Interface français/anglais, progression, annulation, résultats et export HTML/CSV. Les options avancées restent repliées par défaut.

Download the standalone Windows x64 EXE and open it. Choose a folder and click **Analyze**. English/French UI, live progress, cancellation, results and explicit HTML/CSV export. No installer, terminal or separately installed runtime required.

- Native C# engine keeps only the requested largest-file metadata and reports inaccessible folders without aborting the rest of the scan.
- Reparse points are skipped, dedicated report output is excluded and existing reports are not overwritten.
- Reports remain local, use HTML escaping and spreadsheet-safe UTF-8 BOM CSV with compatible headers.
- About contains the app and bundled-runtime licenses; runtime notices are also attached to the release.
- The PowerShell script and its ZIP remain available for automation.

## Downloads

- `WinFix-DiskSpaceAnalyzer-Windows-x64.exe`: portable application (about 111 MiB; .NET included).
- `WinFix-DiskSpaceAnalyzer-Windows-x64-v1.2.0.zip`: app, guides and notices.
- `WinFix-DiskSpaceAnalyzer.ps1` / `WinFix-DiskSpaceAnalyzer-v1.2.0.zip`: command-line alternative.
- `SHA256SUMS.txt`: checksums for the downloadable assets.

The EXE is unsigned. Windows may display an unknown-publisher or reputation warning. This release targets Windows 10/11 x64; no ARM64 or x86 binary is provided. Code signing is not configured. The .NET bundle may extract native libraries into its per-user temporary cache.

Validation: nine native engine/report cases passed locally on Windows 10 build 19045, covering source preservation, exact counts/sizes, CSV/HTML protection, French/English, output exclusion, cancellation, junction loops, actual ACL denial and 5,000 files / 2,750,000 bytes. The portable EXE was launched and its French interface inspected through accessibility. Native screenshot capture was unavailable; no exhaustive manual GUI or clean Windows 11 validation is claimed. CI additionally requires both PowerShell test jobs and a successful native build/test job before this release is published.

Read-only analysis measures logical file lengths, not space safe to reclaim. Access errors make totals incomplete. Reports contain private filenames and paths; review before sharing.
