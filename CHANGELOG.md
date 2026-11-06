# Changelog

## 1.2.0 — 2026-11-06

- Added a native portable Windows x64 application with folder picker, English/French UI, asynchronous scanning, progress, cancellation, results and explicit HTML/CSV exports.
- Added a bounded largest-file collector, nine native integration tests, runtime license embedding and automated desktop build/release assets.
- Retained the standalone PowerShell interface and CSV schemas for automation.
- Desktop executable is unsigned; ARM64/x86 and clean Windows 11 manual testing are not included in this release.

## 1.1.0 — 2026-11-06

- Added `-Language fr` for French console messages, application errors, HTML reports and size formatting; English remains the default.
- Kept CSV schemas, filenames, exact byte totals and exit codes compatible across languages.
- Added a French usage guide, included in the release ZIP, and two integration scenarios covering localization.
- Preserved UTF-8 BOM in PowerShell source so accents render correctly under Windows PowerShell 5.1.

## 1.0.0 — 2026-11-06

- Stable read-only analyzer with local HTML and CSV reports.
- Preserved and regression-tested AllowEmptyCollection on FileCollector and ErrorCollector.
- Excluded dedicated output folder from scans; unique report filenames.
- Rejected reparse-point scan roots and retained traversal skipping.
- Standardized UTF-8 BOM CSV, ISO timestamps and spreadsheet formula protection.
- Added nine dependency-free Windows integration scenarios and dual-edition CI.
- Completed MIT license, usage/limits/export documentation and automated versioned release with SHA-256 checksums.

## Starter

- Initial recursive scan and report implementation.
