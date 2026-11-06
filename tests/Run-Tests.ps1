#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '../script/WinFix-DiskSpaceAnalyzer.ps1'
$engine = (Get-Process -Id $PID).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ('WinFixTests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$script:passed = 0
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Host "PASS: $Name"
}
function Scan([string]$Source, [string]$Output, [int]$Expected = 0, [string[]]$Extra = @()) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $log = & $engine -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Path $Source -OutputDirectory $Output @Extra 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    Assert ($code -eq $Expected) "Exit $code expected $Expected. $log"
    if ($Expected -eq 1) { return }
    $html = @(Get-ChildItem -LiteralPath $Output -Filter '*.html' | Sort-Object LastWriteTime -Descending)[0]
    $files = @(Get-ChildItem -LiteralPath $Output -Filter 'LargestFiles_*.csv' | Sort-Object LastWriteTime -Descending)[0]
    $folders = @(Get-ChildItem -LiteralPath $Output -Filter 'TopLevelFolders_*.csv' | Sort-Object LastWriteTime -Descending)[0]
    [pscustomobject]@{ Html = [IO.File]::ReadAllText($html.FullName); Files = @(Import-Csv -LiteralPath $files.FullName); Folders = @(Import-Csv -LiteralPath $folders.FullName); CsvPath = $files.FullName }
}
function Directory([string]$Name) {
    $p = Join-Path $root $Name
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}
function File([string]$Path, [int]$Bytes) { [IO.File]::WriteAllBytes($Path, (New-Object byte[] $Bytes)) }
try {
    Case 'Parser and empty collection regression guards' {
        $tokens = $null; $parseErrors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
        Assert ($parseErrors.Count -eq 0) 'PowerShell syntax'
        $source = [IO.File]::ReadAllText($scriptPath)
        Assert ($source -match '\[AllowEmptyCollection\(\)\].*\$FileCollector') 'FileCollector accepts empty collections'
        Assert ($source -match '\[AllowEmptyCollection\(\)\].*\$ErrorCollector') 'ErrorCollector accepts empty collections'
    }
    Case 'Missing path and invalid limits fail without reports' {
        Scan (Join-Path $root 'missing') (Join-Path $root 'invalid-out') 1
        Assert (-not (Test-Path (Join-Path $root 'invalid-out'))) 'No output for missing path'
        Scan (Directory 'invalid') (Join-Path $root 'invalid-out') 1 @('-TopFiles','0')
    }
    Case 'Empty tree writes HTML and header-only CSV' {
        $r = Scan (Directory 'empty') (Join-Path $root 'empty-out')
        Assert ($r.Files.Count -eq 0 -and $r.Folders.Count -eq 0) 'Empty CSV rows'
        Assert ($r.Html.Contains('No files found.')) 'Empty HTML message'
        Assert (([IO.File]::ReadAllText($r.CsvPath)).Trim() -eq '"Name","FullName","LengthBytes","Size","LastWriteTime"') 'CSV headers'
    }
    Case 'Nested totals, ordering, top limits, hidden files and read-only scan' {
        $d = Directory 'known'; $a = Directory 'known/a'; $b = Directory 'known/b/deep'
        File (Join-Path $d 'root.bin') 7
        File (Join-Path $a 'small.bin') 20
        File (Join-Path $a 'large.bin') 100
        File (Join-Path $b 'middle.bin') 50
        $hidden = Join-Path $d 'hidden.bin'; File $hidden 3
        [IO.File]::SetAttributes($hidden, [IO.FileAttributes]::Hidden)
        $before = @(Get-ChildItem -LiteralPath $d -Recurse -Force -File | Get-FileHash | Select-Object Path,Hash | ConvertTo-Csv -NoTypeInformation)
        $r = Scan $d (Join-Path $root 'known-out') 0 @('-TopFiles','2','-TopFolders','1')
        Assert ($r.Files.Count -eq 2 -and $r.Files[0].LengthBytes -eq '100' -and $r.Files[1].LengthBytes -eq '50') 'Largest file order'
        Assert ($r.Folders.Count -eq 1 -and $r.Folders[0].LengthBytes -eq '120' -and $r.Folders[0].FilesFound -eq '2') 'Recursive folder totals'
        Assert ($r.Html -match '180 B' -and $r.Html -match 'Files found</span><span class="value">5<') 'Full summary independent of limits'
        $after = @(Get-ChildItem -LiteralPath $d -Recurse -Force -File | Get-FileHash | Select-Object Path,Hash | ConvertTo-Csv -NoTypeInformation)
        Assert (($before -join "`n") -eq ($after -join "`n")) 'Source content unchanged'
    }
    Case 'Unicode, CSV quoting, formula protection and HTML escaping' {
        $d = Directory 'encoding'
        $name = ([char]0xE9).ToString() + ',a&b.bin'
        File (Join-Path $d $name) 10
        File (Join-Path $d '=1+1.bin') 5
        $r = Scan $d (Join-Path $root 'encoding-out')
        Assert ($r.Files[0].Name -eq $name) 'Accents and commas round trip'
        Assert ($r.Files[1].Name -eq "'=1+1.bin") 'Spreadsheet formulas neutralized'
        Assert ($r.Html.Contains('a&amp;b.bin')) 'HTML text escaped'
        $bytes = [IO.File]::ReadAllBytes($r.CsvPath)
        Assert ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) 'UTF-8 BOM'
        Assert ($r.Files[0].LastWriteTime -match '^\d{4}-\d{2}-\d{2}T') 'ISO timestamp'
    }
    Case 'Nested report output excluded and repeated scans do not overwrite' {
        $d = Directory 'repeat'; File (Join-Path $d 'data.bin') 11
        $out = Join-Path $d 'nested/reports'
        $null = Scan $d $out
        $r = Scan $d $out
        Assert ($r.Files.Count -eq 1 -and $r.Files[0].LengthBytes -eq '11') 'Reports excluded'
        Assert (@(Get-ChildItem -LiteralPath $out -Filter '*.html').Count -eq 2) 'Distinct output names'
        Scan $d $d 1
    }
    Case 'Junction loop and root junction are skipped or rejected' {
        $d = Directory 'links'; File (Join-Path $d 'only.bin') 13
        $link = Join-Path $d 'loop'
        New-Item -ItemType Junction -Path $link -Target $d | Out-Null
        try {
            $r = Scan $d (Join-Path $root 'links-out')
            Assert ($r.Files.Count -eq 1) 'Junction not traversed'
            Scan $link (Join-Path $root 'root-link-out') 1
        } finally { [IO.Directory]::Delete($link) }
    }
    Case 'Access denied continues with exit 2 and accessible data' {
        $d = Directory 'access'; $restricted = Directory 'access/restricted'
        File (Join-Path $d 'readable.bin') 12
        File (Join-Path $restricted 'blocked.bin') 99
        $acl = Get-Acl -LiteralPath $restricted
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'ListDirectory', 'Deny')
        try {
            $denied = Get-Acl -LiteralPath $restricted
            $denied.AddAccessRule($rule)
            Set-Acl -LiteralPath $restricted -AclObject $denied
            $r = Scan $d (Join-Path $root 'access-out') 2
            Assert ($r.Files.Count -eq 1 -and $r.Files[0].LengthBytes -eq '12') 'Accessible file counted'
            Assert ($r.Html -match 'Access / scan errors</span><span class="value">1<') 'Error reported'
        } finally { Set-Acl -LiteralPath $restricted -AclObject $acl }
    }
    Case 'Scale: 5000 files and exactly 2750000 bytes' {
        $d = Directory 'scale'
        foreach ($i in 1..50) {
            $sub = Directory ('scale/folder{0:D2}' -f $i)
            foreach ($j in 1..100) { File (Join-Path $sub ('file{0:D3}.bin' -f $j)) (($j % 10 + 1) * 100) }
        }
        $r = Scan $d (Join-Path $root 'scale-out') 0 @('-TopFiles','500','-TopFolders','200')
        Assert ($r.Files.Count -eq 500 -and $r.Folders.Count -eq 50) 'Result limits'
        Assert (($r.Folders | Measure-Object LengthBytes -Sum).Sum -eq 2750000) 'Exact byte sum'
        Assert (($r.Folders | Measure-Object FilesFound -Sum).Sum -eq 5000) 'Exact file count'
        Assert ($r.Html -match 'Access / scan errors</span><span class="value">0<') 'No errors'
    }
    Write-Host "All $script:passed cases passed on PowerShell $($PSVersionTable.PSVersion), $([Environment]::OSVersion.VersionString)."
} finally {
    # Only remove this run's GUID-named directory after validating its parent.
    $resolved = [IO.Path]::GetFullPath($root)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -match '^WinFixTests-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
