#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts/win-x64'))
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $env:NUGET_PACKAGES) { $env:NUGET_PACKAGES = Join-Path $repo '.build/nuget' }
if (-not $env:DOTNET_CLI_HOME) { $env:DOTNET_CLI_HOME = Join-Path $repo '.build/cli' }
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
& dotnet restore (Join-Path $PSScriptRoot 'WinFix.Desktop/WinFix.Desktop.csproj') -r win-x64 -p:SelfContained=true -p:PublishSingleFile=true --configfile (Join-Path $PSScriptRoot 'NuGet.Config')
if ($LASTEXITCODE -ne 0) { throw 'Portable runtime restore failed.' }
$notices = New-Object Text.StringBuilder
foreach ($package in 'microsoft.netcore.app.runtime.win-x64','microsoft.windowsdesktop.app.runtime.win-x64') {
    $packagePath = Join-Path $env:NUGET_PACKAGES $package
    $licenses = @(Get-ChildItem -LiteralPath $packagePath -Recurse -File | Where-Object { $_.Name -match '^(LICENSE(\.TXT)?|THIRD-PARTY-NOTICES\.TXT)$' })
    if ($licenses.Count -eq 0) { throw "Runtime license missing: $package" }
    foreach ($license in $licenses) {
        [void]$notices.AppendLine("--- $package / $($license.Name) ---")
        [void]$notices.AppendLine([IO.File]::ReadAllText($license.FullName))
    }
}
$embedded = Join-Path $repo '.build/runtime-notices.txt'
[IO.Directory]::CreateDirectory((Split-Path $embedded -Parent)) | Out-Null
[IO.File]::WriteAllText($embedded, $notices.ToString(), (New-Object Text.UTF8Encoding $false))
& dotnet publish (Join-Path $PSScriptRoot 'WinFix.Desktop/WinFix.Desktop.csproj') -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true --no-restore -o $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw 'Portable application build failed.' }
$exe = Join-Path $OutputDirectory 'WinFix-DiskSpaceAnalyzer.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Portable EXE missing.' }
[IO.File]::WriteAllText((Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) 'DOTNET-NOTICES.txt'), $notices.ToString(), (New-Object Text.UTF8Encoding $false))
Write-Host "Portable application: $exe"
