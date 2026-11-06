# Validation evidence

## Executed locally on 2026-11-06

Windows 10 build 19045. Nine cases passed, exit code 0, independently under:

- Windows PowerShell 5.1.19041.7802.
- PowerShell 7.6.9.

Cases: parser and both AllowEmptyCollection guards; missing path and invalid limit; empty folder/header-only CSV; nested totals/order/limits/hidden files/source hashes; Unicode/commas/formula protection/HTML escaping/UTF-8 BOM/ISO dates; nested report exclusion and repeated runs; junction loop and junction root; actual fixture ACL denial with exit 2 and one accessible 12-byte file; 5,000 files in 50 folders, exact sum 2,750,000 bytes and zero scan errors.

No timing threshold is asserted. GitHub-hosted test results must be read from Actions; this document does not claim an unobserved CI run passed. Clean Windows 11 manual testing remains unperformed.

## Historical manual evidence supplied by the user

2026-10-12: missing path rejected; denied-access scan continued with 1 accessible file / 12 bytes / 1 error; scale scan found 5,000 files / 2,750,000 bytes / 0 errors in 1.69 seconds (HTML rounded to 1.6 seconds).

The original historical CSV files were not supplied here. Their contents have not been inspected. Current automated tests inspect newly generated CSV files instead.

## Version 1.1.0 localization validation — 2026-11-06

All eleven scenarios passed locally on Windows 10 build 19045 under Windows PowerShell 5.1.19041.7802 and PowerShell 7.6.9. Two added scenarios verify French HTML headings, notices, console, number formatting, stable numeric CSV data and schema, empty results, translated application validation errors and rejection of unsupported languages. Original nine scenarios also passed.

PowerShell source and tests use UTF-8 BOM for Windows PowerShell 5.1 compatibility. Windows-provided exception details are not translated by the application. Publication requires passing the new CI run; local results are not a claim that an unobserved CI run succeeded.

## Version 1.2.0 native application — 2026-11-06

Nine C# engine/export integration scenarios passed locally, including final fixture cleanup, on Windows 10 build 19045 (.NET SDK 10.0.403 / runtime 10.0.14). Coverage: invalid inputs; empty bilingual reports and CSV headers; exact root/nested/hidden counts and limits with source SHA-256 preservation; accents/commas/formula safety/HTML escaping/UTF-8 BOM/ISO dates; nested output exclusion and unique filenames; cancellation during a scan; junction loop/root rejection; actual ACL denial and restored permissions; 5,000 files / 2,750,000 bytes with bounded largest-file metadata.

The self-contained win-x64 single-file publish succeeded without compiler warnings or errors. The EXE was launched on this Windows machine; its French labels, folder field, collapsed advanced options and disabled initial report actions were observed through accessibility. Native screenshot capture failed (FrameArrived timeout/no screenshot targets), so a visual layout inspection and exhaustive interactive button-flow test are not claimed. Clean Windows 11 manual testing and code signing remain unperformed.

The desktop release workflow requires the nine native cases plus the existing eleven PowerShell cases under each edition. Consult the actual Actions run for its result; local evidence does not imply an unobserved CI run passed.
