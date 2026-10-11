# Tests

Planned automated tests use Pester. Initial manual test checklist:

- [ ] Scan a small temporary directory with known file sizes.
- [ ] Confirm HTML and both CSV files are generated.
- [ ] Confirm no files are changed or deleted.
- [ ] Include a folder with an inaccessible child and confirm the report completes with an error count.
- [ ] Confirm reparse points are skipped.
- [ ] Test Windows PowerShell 5.1 and PowerShell 7.
