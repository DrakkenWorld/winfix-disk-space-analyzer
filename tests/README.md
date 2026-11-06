# Tests

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Run-Tests.ps1` from the repository root; repeat with `pwsh.exe`. No dependencies, elevation or Pester installation required. A failed assertion terminates with a nonzero process status. Nine integration cases run against isolated temporary fixtures. See [validation evidence](../docs/VALIDATION.md) for exact coverage and observed results.

The suite now has eleven cases, including French reports, console messages, units, validation errors and stable CSV columns. English remains the default.

Native application tests: `dotnet restore desktop/WinFix.Tests/WinFix.Tests.csproj --configfile desktop/NuGet.Config`, then `dotnet run --project desktop/WinFix.Tests/WinFix.Tests.csproj -c Release --no-restore`. Nine Windows integration scenarios are independent of the PowerShell suite and exercise the actual C# engine and report writer. See docs/DESKTOP.md for portable-build instructions.
