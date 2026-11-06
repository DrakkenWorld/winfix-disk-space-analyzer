#requires -Version 5.1
# WinFix Kit Disk Space Analyzer 1.2.0
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = $env:USERPROFILE,

    [Parameter()]
    [string]$OutputDirectory = (Join-Path $PWD "WinFixReport"),

    [Parameter()]
    [ValidateRange(1, 500)]
    [int]$TopFiles = 25,

    [Parameter()]
    [ValidateRange(1, 200)]
    [int]$TopFolders = 20,

    [Parameter()]
    [ValidateSet('en', 'fr')]
    [string]$Language = 'en'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"


# Keep the standalone script self-contained. OS exception messages retain the OS language.
$french = @{
    'Invalid scan path: the path cannot be empty.' = 'Chemin invalide : le chemin ne peut pas être vide.'
    'Invalid scan path: directory does not exist or is inaccessible:' = 'Chemin invalide : le dossier est inexistant ou inaccessible :'
    'The scan root must be a filesystem directory, not a reparse point.' = 'Le dossier à analyser doit être un dossier du système de fichiers, et non un point de réanalyse.'
    'OutputDirectory cannot be empty.' = 'Le dossier de destination ne peut pas être vide.'
    'OutputDirectory must differ from the scan root. Use a dedicated report subfolder or an external folder.' = 'Le dossier de destination doit être différent du dossier analysé. Choisissez un sous-dossier réservé aux rapports ou un dossier externe.'
    'Disk Space Analyzer' = 'Analyseur d''espace disque'
    'Scanning:' = 'Analyse de :'
    'This is a read-only scan. No files will be changed or deleted.' = 'Analyse en lecture seule. Aucun fichier analysé ne sera modifié ni supprimé.'
    'Cannot list the selected path' = 'Impossible de parcourir le dossier sélectionné'
    'Scanning disk usage' = 'Analyse de l''espace disque'
    'No files found.' = 'Aucun fichier trouvé.'
    'No subfolders found.' = 'Aucun sous-dossier trouvé.'
    'No scan errors were recorded.' = 'Aucune erreur d''analyse enregistrée.'
    'WinFix Kit - Disk Space Report' = 'WinFix Kit - Rapport d''espace disque'
    'Read-only disk usage report generated on' = 'Rapport d''espace disque en lecture seule généré le'
    'Safety: this report is generated locally. The tool does not delete, move, or upload files. File paths and names may be sensitive; review before sharing.' = 'Ce rapport est généré localement. L''outil ne supprime, ne déplace et ne téléverse aucun fichier. Les noms et chemins peuvent être confidentiels : vérifiez le rapport avant de le partager.'
    'Scanned path' = 'Dossier analysé'
    'Total file size counted' = 'Taille totale des fichiers comptabilisés'
    'Files found' = 'Fichiers trouvés'
    'Scan duration' = 'Durée de l''analyse'
    'Access / scan errors' = 'Erreurs d''accès ou d''analyse'
    'sec' = 's'
    'Largest files' = 'Fichiers les plus volumineux'
    'Name' = 'Nom'
    'Full path' = 'Chemin complet'
    'Size' = 'Taille'
    'Last modified' = 'Dernière modification'
    'Largest direct subfolders' = 'Sous-dossiers directs les plus volumineux'
    'Folder' = 'Dossier'
    'Calculated size' = 'Taille calculée'
    'Scan errors' = 'Erreurs d''analyse'
    'first 100 of' = '100 premières sur'
    'Folder totals may be incomplete when Windows denies access. Reparse points are skipped. This report measures file sizes, not the amount of space Windows can safely reclaim.' = 'Les totaux peuvent être incomplets lorsque Windows refuse l''accès. Les points de réanalyse sont ignorés. Ce rapport mesure la taille logique des fichiers, et non l''espace que Windows peut libérer sans risque.'
    'Scan complete.' = 'Analyse terminée.'
    'HTML report' = 'Rapport HTML'
    'Largest files CSV' = 'CSV des fichiers les plus volumineux'
    'Folders CSV' = 'CSV des dossiers'
    'Files counted' = 'Fichiers comptabilisés'
    'Errors' = 'Erreurs'
    'Total' = 'Total'
    'Scan completed with {0} error(s).' = 'Analyse terminée avec {0} erreur(s).'
    'TB' = 'To'
    'GB' = 'Go'
    'MB' = 'Mo'
    'KB' = 'Ko'
    'B' = 'o'
}
function Get-Text {
    param([string]$Text)
    if ($Language -eq 'fr' -and $french.ContainsKey($Text)) { return $french[$Text] }
    return $Text
}
$culture = [Globalization.CultureInfo]::GetCultureInfo($(if ($Language -eq 'fr') { 'fr-FR' } else { 'en-US' }))

# Validate the scan path explicitly
if ([string]::IsNullOrWhiteSpace($Path)) {
    throw (Get-Text 'Invalid scan path: the path cannot be empty.')
}

if (-not (Test-Path -LiteralPath $Path -PathType Container -ErrorAction SilentlyContinue)) {
    throw "$(Get-Text 'Invalid scan path: directory does not exist or is inaccessible:') '$Path'"
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return [string]::Format($culture, ('{0:N2} ' + (Get-Text 'TB')), ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return [string]::Format($culture, ('{0:N2} ' + (Get-Text 'GB')), ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return [string]::Format($culture, ('{0:N2} ' + (Get-Text 'MB')), ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return [string]::Format($culture, ('{0:N2} ' + (Get-Text 'KB')), ($Bytes / 1KB)) }
    return [string]::Format($culture, ('{0:N0} ' + (Get-Text 'B')), $Bytes)
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
        if ($current.TrimEnd('\') -eq $resolvedOutput.TrimEnd('\')) { continue }
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

$scanItem = Get-Item -LiteralPath $Path -Force
if ($scanItem.PSProvider.Name -ne 'FileSystem' -or ($scanItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw (Get-Text 'The scan root must be a filesystem directory, not a reparse point.')
}
$resolvedPath = $scanItem.FullName
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { throw (Get-Text 'OutputDirectory cannot be empty.') }
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
if ($resolvedOutput.TrimEnd('\') -eq $resolvedPath.TrimEnd('\')) {
    throw (Get-Text 'OutputDirectory must differ from the scan root. Use a dedicated report subfolder or an external folder.')
}
$stamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss-fff") + '_' + [guid]::NewGuid().ToString('N').Substring(0,8)
$htmlPath = Join-Path $resolvedOutput "DiskSpaceReport_$stamp.html"
$filesCsvPath = Join-Path $resolvedOutput "LargestFiles_$stamp.csv"
$foldersCsvPath = Join-Path $resolvedOutput "TopLevelFolders_$stamp.csv"

$files = New-Object 'System.Collections.Generic.List[object]'
$errors = New-Object 'System.Collections.Generic.List[string]'
$folderRows = New-Object 'System.Collections.Generic.List[object]'
$scanStart = Get-Date

Write-Host "WinFix Kit - $(Get-Text 'Disk Space Analyzer')" -ForegroundColor Cyan
Write-Host "$(Get-Text 'Scanning:') $resolvedPath"
Write-Host (Get-Text 'This is a read-only scan. No files will be changed or deleted.')
Write-Host ""

try {
    $children = Get-ChildItem -LiteralPath $resolvedPath -Force -ErrorAction Stop
} catch {
    throw "$(Get-Text 'Cannot list the selected path') '$resolvedPath': $($_.Exception.Message)"
}

# Files directly inside the selected directory are collected separately.
foreach ($child in $children) {
    try {
        if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($child.FullName.TrimEnd('\') -eq $resolvedOutput.TrimEnd('\')) { continue }
        if ($child.PSIsContainer) {
            Write-Progress -Activity (Get-Text 'Scanning disk usage') -Status $child.FullName
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
Write-Progress -Activity (Get-Text 'Scanning disk usage') -Completed

$scanEnd = Get-Date
$largestFiles = @($files | Sort-Object LengthBytes -Descending | Select-Object -First $TopFiles)
$largestFolders = @($folderRows | Sort-Object LengthBytes -Descending | Select-Object -First $TopFolders)
[long]$totalBytes = 0
foreach ($file in $files) { $totalBytes += [long]$file.LengthBytes }

function Export-ReportCsv {
    param([object[]]$Rows, [string[]]$Columns, [string]$Destination)
    $safeRows = foreach ($row in $Rows) {
        $record = [ordered]@{}
        foreach ($column in $Columns) {
            $value = $row.$column
            if ($value -is [datetime]) { $value = $value.ToString('o') }
            # Prevent text fields being interpreted as spreadsheet formulas.
            if ($value -is [string] -and $value -match '^[\s]*[=+@-]|^[\t\r\n]') { $value = "'" + $value }
            $record[$column] = $value
        }
        [pscustomobject]$record
    }
    if (@($safeRows).Count -gt 0) {
        [string[]]$lines = @($safeRows | ConvertTo-Csv -NoTypeInformation)
    } else {
        [string[]]$lines = @(('"' + ($Columns -join '","') + '"'))
    }
    # Explicit BOM keeps accents readable in Excel on both PowerShell editions.
    [IO.File]::WriteAllLines($Destination, $lines, (New-Object System.Text.UTF8Encoding $true))
}
Export-ReportCsv -Rows $largestFiles -Columns Name,FullName,LengthBytes,Size,LastWriteTime -Destination $filesCsvPath
Export-ReportCsv -Rows $largestFolders -Columns Folder,LengthBytes,Size,FilesFound -Destination $foldersCsvPath

$fileRowsHtml = foreach ($file in $largestFiles) {
    "<tr><td>$( [System.Net.WebUtility]::HtmlEncode([string]$file.Name) )</td><td class='path'>$( [System.Net.WebUtility]::HtmlEncode([string]$file.FullName) )</td><td>$( [System.Net.WebUtility]::HtmlEncode([string]$file.Size) )</td><td>$( [System.Net.WebUtility]::HtmlEncode([string]$file.LastWriteTime.ToString($culture)) )</td></tr>"
}
$folderRowsHtml = foreach ($folder in $largestFolders) {
    "<tr><td class='path'>$( [System.Net.WebUtility]::HtmlEncode([string]$folder.Folder) )</td><td>$( [System.Net.WebUtility]::HtmlEncode([string]$folder.Size) )</td><td>$($folder.FilesFound)</td></tr>"
}
$errorRowsHtml = foreach ($err in ($errors | Select-Object -First 100)) {
    "<li>$( [System.Net.WebUtility]::HtmlEncode([string]$err) )</li>"
}
if (-not $fileRowsHtml) { $fileRowsHtml = "<tr><td colspan='4'>$(Get-Text 'No files found.')</td></tr>" }
if (-not $folderRowsHtml) { $folderRowsHtml = "<tr><td colspan='3'>$(Get-Text 'No subfolders found.')</td></tr>" }
if (-not $errorRowsHtml) { $errorRowsHtml = "<li>$(Get-Text 'No scan errors were recorded.')</li>" }

$duration = $scanEnd - $scanStart
$html = @"
<!doctype html>
<html lang="$Language"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(Get-Text 'WinFix Kit - Disk Space Report')</title>
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
<h1>WinFix Kit <span style="color:var(--accent)">/</span> $(Get-Text 'Disk Space Analyzer')</h1>
<p>$(Get-Text 'Read-only disk usage report generated on') $( [System.Net.WebUtility]::HtmlEncode((Get-Date -Format "yyyy-MM-dd HH:mm:ss")) ).</p>
<div class="notice">$(Get-Text 'Safety: this report is generated locally. The tool does not delete, move, or upload files. File paths and names may be sensitive; review before sharing.')</div>
<div class="summary" style="margin-top:18px">
<div class="card"><span class="muted">$(Get-Text 'Scanned path')</span><span class="value">$( [System.Net.WebUtility]::HtmlEncode($resolvedPath) )</span></div>
<div class="card"><span class="muted">$(Get-Text 'Total file size counted')</span><span class="value">$(Format-Bytes -Bytes $totalBytes)</span></div>
<div class="card"><span class="muted">$(Get-Text 'Files found')</span><span class="value">$($files.Count)</span></div>
<div class="card"><span class="muted">$(Get-Text 'Scan duration')</span><span class="value">$([math]::Round($duration.TotalSeconds,1)) $(Get-Text 'sec')</span></div>
<div class="card"><span class="muted">$(Get-Text 'Access / scan errors')</span><span class="value">$($errors.Count)</span></div>
</div>
<h2>$(Get-Text 'Largest files') (top $TopFiles)</h2>
<table><thead><tr><th>$(Get-Text 'Name')</th><th>$(Get-Text 'Full path')</th><th>$(Get-Text 'Size')</th><th>$(Get-Text 'Last modified')</th></tr></thead><tbody>
$($fileRowsHtml -join "`n")
</tbody></table>
<h2>$(Get-Text 'Largest direct subfolders') (top $TopFolders)</h2>
<table><thead><tr><th>$(Get-Text 'Folder')</th><th>$(Get-Text 'Calculated size')</th><th>$(Get-Text 'Files found')</th></tr></thead><tbody>
$($folderRowsHtml -join "`n")
</tbody></table>
<details><summary>$(Get-Text 'Scan errors') ($(Get-Text 'first 100 of') $($errors.Count))</summary><ul>
$($errorRowsHtml -join "`n")
</ul></details>
<p class="muted">$(Get-Text 'Folder totals may be incomplete when Windows denies access. Reparse points are skipped. This report measures file sizes, not the amount of space Windows can safely reclaim.')</p>
</main></body></html>
"@
Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8

Write-Host ""
Write-Host (Get-Text 'Scan complete.') -ForegroundColor Green
Write-Host "$(Get-Text 'HTML report') : $htmlPath"
Write-Host "$(Get-Text 'Largest files CSV') : $filesCsvPath"
Write-Host "$(Get-Text 'Folders CSV') : $foldersCsvPath"
Write-Host "$(Get-Text 'Files counted'): $($files.Count) | $(Get-Text 'Errors'): $($errors.Count) | $(Get-Text 'Total'): $(Format-Bytes -Bytes $totalBytes)"

# Explicit process exit codes for command-line automation:
# 0 = scan completed without recorded scan errors
# 1 = fatal error (PowerShell's terminating-error behavior under -File)
# 2 = reports generated, but one or more scan errors were recorded
if ($errors.Count -gt 0) {
    Write-Host ((Get-Text 'Scan completed with {0} error(s).') -f $errors.Count) -ForegroundColor Yellow
    exit 2
}

exit 0
