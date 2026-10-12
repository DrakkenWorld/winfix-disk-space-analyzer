[CmdletBinding()]
param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = $env:USERPROFILE,

    [Parameter()]
    [string]$OutputDirectory = (Join-Path $PWD "WinFixReport"),

    [Parameter()]
    [ValidateRange(1, 500)]
    [int]$TopFiles = 25,

    [Parameter()]
    [ValidateRange(1, 200)]
    [int]$TopFolders = 20
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return ("{0:N2} TB" -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0:N0} B" -f $Bytes)
}

function Get-DirectoryUsage {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$FileCollector,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorCollector
    )

    [long]$total = 0
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($Directory)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try {
            $items = Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop
        } catch {
            $ErrorCollector.Add(("{0}: {1}" -f $current, $_.Exception.Message))
            continue
        }

        foreach ($item in $items) {
            try {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                if ($item.PSIsContainer) {
                    $stack.Push($item.FullName)
                } else {
                    $length = [long]$item.Length
                    $total += $length
                    $FileCollector.Add([pscustomobject]@{
                        Name = $item.Name
                        FullName = $item.FullName
                        LengthBytes = $length
                        Size = (Format-Bytes -Bytes $length)
                        LastWriteTime = $item.LastWriteTime
                    })
                }
            } catch {
                $ErrorCollector.Add(("{0}: {1}" -f $item.FullName, $_.Exception.Message))
            }
        }
    }
    return $total
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlPath = Join-Path $resolvedOutput "DiskSpaceReport_$stamp.html"
$filesCsvPath = Join-Path $resolvedOutput "LargestFiles_$stamp.csv"
$foldersCsvPath = Join-Path $resolvedOutput "TopLevelFolders_$stamp.csv"

$files = New-Object 'System.Collections.Generic.List[object]'
$errors = New-Object 'System.Collections.Generic.List[string]'
$folderRows = New-Object 'System.Collections.Generic.List[object]'
$scanStart = Get-Date

Write-Host "WinFix Kit - Disk Space Analyzer" -ForegroundColor Cyan
Write-Host "Scanning: $resolvedPath"
Write-Host "This is a read-only scan. No files will be changed or deleted."
Write-Host ""

try {
    $children = Get-ChildItem -LiteralPath $resolvedPath -Force -ErrorAction Stop
} catch {
    throw "Cannot list the selected path '$resolvedPath': $($_.Exception.Message)"
}

# Files directly inside the selected directory are collected separately.
foreach ($child in $children) {
    try {
        if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($child.PSIsContainer) {
            Write-Progress -Activity "Scanning disk usage" -Status $child.FullName
            $beforeCount = $files.Count
            [long]$folderBytes = Get-DirectoryUsage -Directory $child.FullName -FileCollector $files -ErrorCollector $errors
            $folderRows.Add([pscustomobject]@{
                Folder = $child.FullName
                LengthBytes = $folderBytes
                Size = (Format-Bytes -Bytes $folderBytes)
                FilesFound = ($files.Count - $beforeCount)
            })
        } else {
            [long]$length = $child.Length
            $files.Add([pscustomobject]@{
                Name = $child.Name
                FullName = $child.FullName
                LengthBytes = $length
                Size = (Format-Bytes -Bytes $length)
                LastWriteTime = $child.LastWriteTime
            })
        }
    } catch {
        $errors.Add(("{0}: {1}" -f $child.FullName, $_.Exception.Message))
    }
}
Write-Progress -Activity "Scanning disk usage" -Completed

$scanEnd = Get-Date
$largestFiles = @($files | Sort-Object LengthBytes -Descending | Select-Object -First $TopFiles)
$largestFolders = @($folderRows | Sort-Object LengthBytes -Descending | Select-Object -First $TopFolders)
[long]$totalBytes = 0
foreach ($file in $files) { $totalBytes += [long]$file.LengthBytes }

if ($largestFiles.Count -gt 0) {
    $largestFiles | Select-Object Name, FullName, LengthBytes, Size, LastWriteTime |
        Export-Csv -LiteralPath $filesCsvPath -NoTypeInformation -Encoding UTF8
} else {
    '"Name","FullName","LengthBytes","Size","LastWriteTime"' | Set-Content -LiteralPath $filesCsvPath -Encoding UTF8
}
if ($largestFolders.Count -gt 0) {
    $largestFolders | Select-Object Folder, LengthBytes, Size, FilesFound |
        Export-Csv -LiteralPath $foldersCsvPath -NoTypeInformation -Encoding UTF8
} else {
    '"Folder","LengthBytes","Size","FilesFound"' | Set-Content -LiteralPath $foldersCsvPath -Encoding UTF8
}

$fileRowsHtml = foreach ($file in $largestFiles) {
    "<tr><td>$( [System.Net.WebUtility]::HtmlEncode([string]$file.Name) )</td><td class='path'>$( [System.Net.WebUtility]::HtmlEncode([string]$file.FullName) )</td><td>$( [System.Net.WebUtility]::HtmlEncode([string]$file.Size) )</td><td>$( [System.Net.WebUtility]::HtmlEncode([string]$file.LastWriteTime) )</td></tr>"
}
$folderRowsHtml = foreach ($folder in $largestFolders) {
    "<tr><td class='path'>$( [System.Net.WebUtility]::HtmlEncode([string]$folder.Folder) )</td><td>$( [System.Net.WebUtility]::HtmlEncode([string]$folder.Size) )</td><td>$($folder.FilesFound)</td></tr>"
}
$errorRowsHtml = foreach ($err in ($errors | Select-Object -First 100)) {
    "<li>$( [System.Net.WebUtility]::HtmlEncode([string]$err) )</li>"
}
if (-not $fileRowsHtml) { $fileRowsHtml = "<tr><td colspan='4'>No files found.</td></tr>" }
if (-not $folderRowsHtml) { $folderRowsHtml = "<tr><td colspan='3'>No subfolders found.</td></tr>" }
if (-not $errorRowsHtml) { $errorRowsHtml = "<li>No scan errors were recorded.</li>" }

$duration = $scanEnd - $scanStart
$html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>WinFix Kit - Disk Space Report</title>
<style>
:root{color-scheme:dark;--bg:#0b1020;--panel:#111a2d;--line:#26334d;--text:#f3f6ff;--muted:#a1aec7;--accent:#6be0d2}
*{box-sizing:border-box}body{margin:0;padding:32px;background:var(--bg);color:var(--text);font:15px/1.5 "Segoe UI",Arial,sans-serif}
main{max-width:1200px;margin:auto}h1{font-size:2rem;letter-spacing:-.04em}h2{margin-top:32px}p,.muted{color:var(--muted)}.summary{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}
.card{padding:18px;background:var(--panel);border:1px solid var(--line);border-radius:12px}.value{display:block;font-size:1.35rem;font-weight:700;color:var(--accent);overflow-wrap:anywhere}
table{width:100%;border-collapse:collapse;background:var(--panel);border-radius:10px;overflow:hidden}th,td{text-align:left;padding:10px 12px;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--accent);font-weight:650}tr:last-child td{border-bottom:0}.path{overflow-wrap:anywhere;word-break:break-word}
.notice{padding:14px 16px;border-left:3px solid var(--accent);background:#10232d;color:#d9fff8;border-radius:4px}
details{margin-top:12px;background:var(--panel);border:1px solid var(--line);padding:14px;border-radius:10px}li{margin:6px 0;overflow-wrap:anywhere}
@media(max-width:700px){body{padding:16px}table{font-size:12px}th,td{padding:7px}}
</style></head><body><main>
<h1>WinFix Kit <span style="color:var(--accent)">/</span> Disk Space Analyzer</h1>
<p>Read-only disk usage report generated on $( [System.Net.WebUtility]::HtmlEncode((Get-Date -Format "yyyy-MM-dd HH:mm:ss")) ).</p>
<div class="notice">Safety: this report is generated locally. The tool does not delete, move, or upload files. File paths and names may be sensitive; review before sharing.</div>
<div class="summary" style="margin-top:18px">
<div class="card"><span class="muted">Scanned path</span><span class="value">$( [System.Net.WebUtility]::HtmlEncode($resolvedPath) )</span></div>
<div class="card"><span class="muted">Total file size counted</span><span class="value">$(Format-Bytes -Bytes $totalBytes)</span></div>
<div class="card"><span class="muted">Files found</span><span class="value">$($files.Count)</span></div>
<div class="card"><span class="muted">Scan duration</span><span class="value">$([math]::Round($duration.TotalSeconds,1)) sec</span></div>
<div class="card"><span class="muted">Access / scan errors</span><span class="value">$($errors.Count)</span></div>
</div>
<h2>Largest files (top $TopFiles)</h2>
<table><thead><tr><th>Name</th><th>Full path</th><th>Size</th><th>Last modified</th></tr></thead><tbody>
$($fileRowsHtml -join "`n")
</tbody></table>
<h2>Largest direct subfolders (top $TopFolders)</h2>
<table><thead><tr><th>Folder</th><th>Calculated size</th><th>Files found</th></tr></thead><tbody>
$($folderRowsHtml -join "`n")
</tbody></table>
<details><summary>Scan errors (first 100 of $($errors.Count))</summary><ul>
$($errorRowsHtml -join "`n")
</ul></details>
<p class="muted">Folder totals may be incomplete when Windows denies access. Reparse points are skipped. This report measures file sizes, not the amount of space Windows can safely reclaim.</p>
</main></body></html>
"@
Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8

Write-Host ""
Write-Host "Scan complete." -ForegroundColor Green
Write-Host "HTML report : $htmlPath"
Write-Host "Largest files CSV : $filesCsvPath"
Write-Host "Folders CSV : $foldersCsvPath"
Write-Host "Files counted: $($files.Count) | Errors: $($errors.Count) | Total: $(Format-Bytes -Bytes $totalBytes)"
