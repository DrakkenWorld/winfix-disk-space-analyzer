# WinFix Kit — Disk Space Analyzer

A read-only PowerShell utility that scans a chosen directory, reports the largest files and folders, and exports local HTML and CSV reports.

> **Safety:** This script does not delete, move, or modify scanned files. Reports may contain private file paths and names; review them before sharing.

## Requirements

- Windows 10 or Windows 11.
- Windows PowerShell 5.1 or PowerShell 7.
- Read access to the folders you want to scan. Administrator rights are not required for ordinary user folders.

## Quick start

Download `script/WinFix-DiskSpaceAnalyzer.ps1` from this repository, open PowerShell, then run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\WinFix-DiskSpaceAnalyzer.ps1 -Path "$env:USERPROFILE" -OutputDirectory "$env:USERPROFILE\Desktop\WinFixReport"
```

The execution policy change applies only to the current PowerShell process. You can also invoke the script without changing policy according to your organization's policy.

To scan another folder:

```powershell
.\WinFix-DiskSpaceAnalyzer.ps1 -Path "D:\Data" -OutputDirectory "C:\Temp\WinFixReport"
```

Optional result limits:

```powershell
.\WinFix-DiskSpaceAnalyzer.ps1 -Path "C:\Users" -TopFiles 50 -TopFolders 30
```

## Output

The output directory receives:
- `DiskSpaceReport_YYYY-MM-DD_HH-mm-ss.html` — readable summary and largest files.
- `LargestFiles_YYYY-MM-DD_HH-mm-ss.csv` — file path and size in bytes.
- `TopLevelFolders_YYYY-MM-DD_HH-mm-ss.csv` — estimated sizes for direct subfolders.

The script skips inaccessible paths and records scan errors in the HTML report. Folder sizes are calculated by walking each direct child folder recursively, so scanning large drives can take a while.

## Limitations

- Reparse points (including junctions and symbolic links) are skipped to reduce the risk of loops.
- Files that cannot be read are skipped and counted as errors.
- Folder totals can be incomplete if access is denied.
- The tool reports storage usage; it does not determine whether files are safe to delete.
- No telemetry or network upload is performed.

## Verify the script

Review the PowerShell source before running it. After downloading, you can calculate its SHA-256 hash:

```powershell
Get-FileHash .\WinFix-DiskSpaceAnalyzer.ps1 -Algorithm SHA256
```

## Roadmap

- [ ] Add Pester tests.
- [ ] Test on clean Windows 10 and Windows 11 environments.
- [ ] Publish a versioned GitHub Release and SHA-256 checksum.
- [ ] Add representative screenshots from a test run.

## License

MIT. See `LICENSE`.
