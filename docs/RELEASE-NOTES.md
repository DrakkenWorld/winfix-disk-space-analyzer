First stable release: read-only Windows disk usage analysis with local HTML and CSV reports.

- Both collectors explicitly accept empty collections (`AllowEmptyCollection`).
- Report directories inside the scan are excluded, report filenames are unique, and reparse points are skipped (including rejection of a reparse-point root).
- CSV exports have stable headers, UTF-8 BOM, ISO 8601 timestamps and protection against spreadsheet formulas in text cells. HTML content is escaped.
- Nine integration scenarios cover exact totals, sorting and limits, empty and missing paths, source preservation, Unicode, nested reports, junctions, denied access and 5,000 files / 2,750,000 bytes.
- The release workflow requires passing Windows PowerShell 5.1 and PowerShell 7 jobs before publishing the script, ZIP and SHA-256 checksums.

Reports measure logical file length, not reclaimable or allocated disk space. Memory usage grows with file count. Access errors make totals incomplete. Reports contain local names and paths; review before sharing.

Local validation on 2026-11-06: all nine scenarios passed on Windows 10 build 19045 under PowerShell 5.1.19041.7802 and 7.6.9. A clean Windows 11 installation has not been manually tested. The earlier user-reported 1.69-second benchmark is historical, not a timing guarantee.
