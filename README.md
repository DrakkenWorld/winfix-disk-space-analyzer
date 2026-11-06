# WinFix Kit — Disk Space Analyzer 1.1.0

English · [Français](README.fr.md)

[![Windows tests](https://github.com/DrakkenWorld/winfix-disk-space-analyzer/actions/workflows/ci.yml/badge.svg)](https://github.com/DrakkenWorld/winfix-disk-space-analyzer/actions/workflows/ci.yml)

Read-only PowerShell disk usage analysis. Find the largest files and direct subfolders, and generate local HTML and CSV reports. No telemetry, upload, cleanup or deletion of scanned files.

## Download and run

Download the script or ZIP from [Releases](https://github.com/DrakkenWorld/winfix-disk-space-analyzer/releases/latest). Requires Windows PowerShell 5.1 or PowerShell 7 on Windows. Administrator rights are unnecessary for ordinary user folders. Inspect the source before running and follow your organization's execution policy. If Windows blocks a trusted downloaded script, use `Unblock-File` on that file after reviewing it.

```powershell
powershell.exe -NoProfile -File .\WinFix-DiskSpaceAnalyzer.ps1 -Path "$env:USERPROFILE\Documents" -OutputDirectory "$env:USERPROFILE\Desktop\WinFixReport"
# Or use pwsh.exe for PowerShell 7.
```

Reports are written into the output directory. Choose a dedicated subfolder or a location outside the scan root; using the scan root itself as output is rejected. An output subfolder is excluded from the scan, including its old reports. Reports from other locations are ordinary input files.

| Parameter | Default | Values |
| --- | --- | --- |
| `Path` | User profile | Existing accessible filesystem directory |
| `OutputDirectory` | `WinFixReport` under current directory | Writable directory distinct from scan root |
| `TopFiles` | 25 | 1–500 |
| `TopFolders` | 20 | 1–200 |
| `Language` | `en` | `en` or `fr`: console and HTML report language |

For a French report and console, add `-Language fr`. English remains the default for compatibility. Byte counts, CSV headers, filenames and exit codes are identical in both languages; the CSV `Size` display uses English or French formatting (for example `2.00 KB` / `2,00 Ko`). Windows-generated exception details retain the operating system's language.

Use a separate PowerShell process for automation: the script exits with **0** on a complete scan, **1** on a fatal error, or **2** when reports were generated with scan errors. A fatal export error can leave partial output; it never reports a successful scan.

## Reports and export contract

Each run has a timestamp and unique suffix, avoiding overwrite of earlier reports.

- `DiskSpaceReport_*.html`: full count, logical size, elapsed scan time, largest items and first 100 scan errors. Untrusted filenames, paths and error messages are HTML-escaped.
- `LargestFiles_*.csv`: `Name,FullName,LengthBytes,Size,LastWriteTime`.
- `TopLevelFolders_*.csv`: `Folder,LengthBytes,Size,FilesFound`.

CSV uses comma delimiters, quoted fields and UTF-8 with BOM in both PowerShell editions. Empty results still include headers. Timestamps use ISO 8601. Text cells beginning with a spreadsheet formula marker (`=`, `+`, `-`, `@`, including after whitespace) or a tab/newline are prefixed with an apostrophe; this is intentional export protection. HTML retains the actual name. Import CSV as text when processing untrusted data in spreadsheets.

Rows sort by numeric `LengthBytes` descending; ties have no defined order. Limits affect exported rows, not summary totals. Direct-root files count toward the total but not a subfolder row. Each direct subfolder includes all accessible descendants. `Size` is a localized human-readable value; KB/MB/GB/TB denote binary powers of 1024. Use `LengthBytes` for calculations.

## Scope and limitations

- Measures logical file lengths, not allocated space, free space or space safe to reclaim. Hard-linked files are counted per directory entry.
- Skips reparse points, including junctions and symbolic links. A reparse-point scan root is rejected. Cloud placeholders carrying that attribute may be skipped.
- Denied access and files changing during the scan can produce incomplete totals. The root must be listable; otherwise the run fails.
- Keeps file metadata in memory and sorts it: memory grows with file count. This is not a constant-memory whole-drive scanner.
- Writes reports only; it does not modify source content or permissions. Windows may update access metadata when reading. The scan is not a filesystem snapshot.
- Reports contain private names and paths. Review them before sharing.

## Tests and release

No third-party test module is required:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

The eleven integration scenarios create a unique temporary fixture, start the analyzer as a child process, inspect reports and verify source hashes. They include French HTML, console, units, empty results and validation errors. The denied-access test changes only its own fixture ACL and restores it; the junction test removes its own junction before cleanup. No administrator privileges are required.

See [validation evidence](docs/VALIDATION.md). GitHub Actions runs both PowerShell editions on `windows-latest`. After both jobs pass on `main`, it publishes the version in `VERSION` if that release does not already exist, with script, ZIP and `SHA256SUMS.txt`. Published versions are not overwritten. Bump `VERSION`, script version, changelog and release notes together for a future release.

```powershell
Get-FileHash .\WinFix-DiskSpaceAnalyzer.ps1 -Algorithm SHA256
```

Compare with the checksum attached to the same release. This detects corruption; it is not a code signature. The script is unsigned.

[WinFix Kit website](https://drakkenworld.github.io/winfix-kit-site/) · [Security](SECURITY.md) · [MIT license](LICENSE)
